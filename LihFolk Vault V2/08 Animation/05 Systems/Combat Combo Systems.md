---
tags: [systems, combat, combo, input, networking, timing, type/guide, area/animation, level/intermediate, area/networking]
---
# Combat Combo Systems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Clicks get "eaten": Early presses dropped -> One-press buffer of 0.1 to 0.2 s
> - Two swings blur together: Fading the new swing over a still-playing old one -> Stop the old (0.06), start the new from the link pose (0.04)
> - Snap when the player stops clicking: End pose not the class rest -> Re-key the last frame to the rest
> - Hit times stored per step (from markers), divided by playback speed.
> - Min gap per class; later-hit rule applied.
> - One-press buffer; combo window resets the step.
>
> Cost: TL;DR ~170 tok · whole note ~4.4k tok. Read more: ## Server-authoritative hits · ## A buffered combo controller · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A click combo is the most-played animation system in any melee game. It is three or four short clips, a counter and a timer, and it is surprisingly easy to make feel bad: dropped inputs, swings that blend into mush, hits that land before or after the blade arrives, server damage that disagrees with what the player saw. This note covers the design: chain structure, [[input buffering]], combo windows, pose continuity, and server-authoritative hit timing with latency. Numbers are from one live action game (the reference project) unless marked otherwise. Swing craft (how to pose and time a single swing) is in [[Weapon Swing Design]] and [[Combat Animation Craft]].

## Anatomy of a chain

| Concept | Definition | Reference value |
|---|---|---|
| Step | Index into the chain (1..N), advances on each accepted press | N = 3 or 4 |
| Hit time | Seconds from clip start to the `Hit` marker | see table below |
| Link pose | Pose the clip holds where the next swing may start | authored per clip |
| End pose | Pose at the clip's last frame | the class rest (idle plus carry) |
| Min gap | Minimum time between accepted presses | 0.42 to 0.7 s per class |
| Combo window | Time after the last press during which the next press continues the chain | 1.1 s (single-clip sword), 0.9 s (per-clip chains) |

### Measured chain timings

| Class | Hit times per step (s) | Min gap (s) |
|---|---|---|
| Sword | 0.20 / 0.20 / 0.217 / 0.367 (lunging finisher) | 0.42 |
| Katana | 0.217 / 0.217 / 0.20 / 0.383 | 0.42 |
| Heavy (older set) | 0.42 / 0.38 / 0.74 | 0.7 |
| Scythe (older set) | 0.42 / 0.38 / 0.54 | 0.6 |
| Staff | 0.40 / 0.38 / 0.62 | 0.6 |

A later rework replaced the sword set with three horizontal slices (right to left, a left to right backhand, a high to low right to left) plus a 360 spin finisher: durations 0.42 / 0.42 / 0.47 / 0.62 s, hits 0.20 / 0.20 / 0.23 / 0.30. All of it used one arm shape (arm forward, blade in line) with the sweep produced by waist twist plus shoulder yaw, and it was checked at 60 fps for zero body clipping. Using one arm shape is what lets four swings chain in any order without the elbow flipping between them.

Two patterns jump out of the table:
- **Light weapons hit at about 0.2 s.** That is 6 frames at 30 fps from click to contact, inside what players read as "immediate" (rule of thumb: under about 0.25 s).
- **Finishers hit late** (0.30 to 0.38 s light, 0.54 to 0.74 heavy). The extra anticipation is what sells the finisher, and it creates a server pacing problem solved below.

## The press pipeline

Every press goes through the same gates, in this order:

1. **Blocked states.** No swing while dashing, downed, in a cutscene (`CutsceneLock`), guarding (`GuardingLocal`), while an ability carries the body, or while the equip flourish or draw plays (the reference project called this EQUIP-LOCK). These are the ownership attributes from [[Custom Locomotion Controller Design]].
2. **Rate gate.** `cooldown = max(SwingCooldown, class minGap)`, where `SwingCooldown` is a player attribute (default 0.55 s in the reference project) so buffs can change it. If `now < nextAllowed`, the press is **dropped**.
3. **Chain bookkeeping.** If more time than the combo window has passed since the last swing, reset the step to 0. Advance the step.
4. **Facing.** Turn the root to face the nearest enemy within 26 studs (flat distance), so the clip, the slash VFX and the hit all point at the target.
5. **Play.** Pick the clip (upper-body copy when moving, except lunges), stop the previous swing, play the new one.
6. **Schedule the hit** at the clip's hit time, divided by playback speed.

### Input buffering (what the reference project did not do)

Step 2 drops early presses. With a 0.42 s min gap and a player clicking at their natural rhythm, presses that come 50 ms early are lost, and the player feels the game "eating" clicks. The standard fix (rule of thumb, used widely in action games) is an **input buffer**: remember a press that arrives during the cooldown and fire it the moment the gate opens, if it arrived no earlier than a buffer window before that moment.

Choosing the window:

| Buffer | Feel |
|---|---|
| 0 | Precise but punishing; mashing works better than rhythm |
| 0.1 to 0.2 s | Forgiving, still "my input" (rule of thumb sweet spot) |
| over 0.3 s | The game plays itself; a nervous double click commits two swings |

Only buffer **one** press. Queuing several turns a mash into a long uncancellable string.

## Pose continuity

The combo looks fluid only if consecutive clips agree about the pose at the moment they meet.

- **Start on the link pose.** Every swing starts on the pose the previous swing holds at its link. Then the chained transition can use a near-zero fade (0.04 s in the reference project) and the body flows from one cut into the next instead of blending two swings.
- **End on the class rest.** Every swing's last frame is the class rest (idle plus carry). When the player stops clicking, the clip ends and the idle takes over with nothing to fix up. The carry layer's pose equals this end pose for the same reason (see [[Locomotion Systems]]).
- **Tolerances.** The idle takes over the instant a non-looped track ends, so the pipeline rule was: the clip's last frame within **75 degrees** of the idle per joint, its first within **90 degrees** (project standard). Larger gaps show as a visible snap.
- **A quick click cuts the previous swing short.** On a chained press, every other swing in the chain is stopped with a 0.06 s fade and the new one plays with 0.04 s; a fresh (non-chained) press fades in over 0.1 s.

### One long clip with segments, or one clip per swing?

The older sword set was a single 2.8 s clip holding four cuts (cut times measured at 0.4 / 0.9 / 1.7 / 2.25 s). Each click jumped to a segment (`TimePosition = seg.from`), played it at 1.25x, and stopped it at `seg.to` with a 0.15 s fade.

| | Single clip, segments | One clip per swing |
|---|---|---|
| Authoring | One continuous performance, natural links | Links must be matched by hand |
| Markers | Must be read per segment; marker events fire for every segment you scrub through | One `Hit` marker per clip |
| Upper-body copies | One copy | One per swing |
| Cancelling | Must stop the track at `seg.to` yourself | Clip ends by itself |
| Server timing | Hit = seg.hit - seg.from, divided by speed | Hit = marker time |

The segment approach is a good way to reuse a mocap or long authored combo, but every later system (markers, juice, server timing) gets simpler with one clip per swing. The reference project moved to one clip per swing.

## Server-authoritative hits

The server must decide damage; the client decides presentation. The two must agree on **when** the hit happens, or the enemy flinches visibly before or after the blade arrives.

### Basic swings: the client reports at the hit

In the reference project the client fires the swing remote at the scheduled hit time (`task.delay(hitDelay, ...)`), not at the click. The server then:
- validates pacing (a guard module banks one interval per swing),
- checks distance: flat distance within `PLAYER_REACH` (13, later raised to 17) plus 6 for bosses plus the enemy's radius, any facing,
- applies damage.

**The later-hit pacing rule.** The server banks one cooldown per swing, measured between the hit reports it receives. Take the sword: the finisher hits at 0.367 s, the first swing of the next chain at 0.20 s, min gap 0.42. Click the finisher at time 0 and the next swing at 0.42: the hits arrive at 0.367 and 0.62, only 0.253 s apart, so the server rejects the second one. The fix: **after a swing whose hit is later than the next swing's, delay the next allowed press by the difference** (`(step.hit - next.hit) / speed`). Two hits then never reach the server closer than one cooldown.

### Abilities: the marker minus 0.06 s rule

Ability kits use a different contract:

1. The client starts the body clip at Action4.
2. **0.06 s later** it fires the cast to the server with the aim and the claimed cast-start CFrame.
3. The server schedules each hit at `t` seconds after receiving the cast, where `t = clip marker time - 0.06` (plus flight time for thrown cuts).

On the client's clock, the server's hit therefore happens at `0.06 + one-way latency + (marker - 0.06) = marker + one-way latency`. The 0.06 s cancels exactly, and the server's damage lags the client's visual hit by one network trip, which is the minimum possible without client authority. The cinematic system documents the same constant as `CLIENT_LEAD = 0.06`.

Why send the cast 0.06 s late at all? It gives the client a few frames to apply local facing and aim assist and to compute the claimed start position from the settled root, and it means the server's `t` values can be authored straight from marker times with one fixed subtraction. The cost is a hard dependency: **the pipeline only works if markers survive every bake and re-export.** Every tool in the reference pipeline preserves markers and the keyframes that carry them; a baker that drops a marker silently breaks the damage timing of that move.

### Where hits are centred

Kit hit shapes are measured from the flattened **cast start** CFrame, not the moving body. A move that travels must list its hits along its planned path, and the client must follow that path. The server only trusts the client's claimed start if:
- it is for the same move,
- it is under 1 s old,
- the root is within N studs of it when the cast arrives (N = 40 for most kits, 20 for older kits, 60 for one long-range kit).

Otherwise it re-centres on the current root. Note the interaction: the cast arrives about 0.06 s plus latency after the clip starts; if a fast dash has already carried the body past N, every hit re-centres on the moving root. Raise N when you make movement faster.

### Latency handling options

| Approach | What players see | Risk |
|---|---|---|
| Server times from receipt (reference project) | Enemy reaction about one round trip after the visual hit; usually invisible under 100 ms ping | High-ping players see late reactions |
| Server rewinds targets to the client's time (lag compensation) | Hits match what the attacker saw | Defenders get hit "behind cover"; more code |
| Client claims hits, server validates (range, rate, line of sight) | Instant | Exploitable if validation is weak |

For PvE melee, the first is the right default. Hide the remaining delay with **client-side presentation on the marker**: hit spark, sound crack and a small local hit-stop play at the marker on the attacker's screen, and the enemy's own flinch arrives with the replicated damage. See [[Hit Reactions Stagger and Hit-Stop]] and [[VFX Timing with Animation]].

## Moving while attacking

Stopping the player for every swing feels sticky; letting them run at full speed makes swings look pasted on. The reference project scales the current target speed (walk or sprint) while attacking; the factor went from 0.55 to 0.6 to 0.9 over tuning passes, ending near full speed because the game is about mobility. When moving, the swing plays its **upper-body copy** (hips and legs at weight 0) so the legs keep running; lunging finishers keep the full-body clip because their footwork is the point.

Small forward steps on every light swing (for example 24 studs/s for 0.07 s) add up and feel slippery. Keep lunges for finishers and heavy attacks.

## Finishers

The last step gets extras, and only the last step: a 0.2 trauma screen shake, three shadow afterimages starting 0.06 s before the hit (0.035 s apart, 0.45 alpha, 0.22 s life). An earlier version put afterimages on every cut; the dark ghosts read as stray slashes, so they were cut back to the finisher.

## A buffered combo controller

```lua
--!strict
local Players = game:GetService("Players")

export type Step = { anim: Animation, hit: number, lunge: boolean? }
export type Chain = { steps: { Step }, minGap: number, window: number, speed: number }

local BUFFER = 0.15 -- s: a press this early is remembered (rule of thumb)

local Combo = {}
Combo.__index = Combo

function Combo.new(animator: Animator, chain: Chain, onHit: (step: number) -> ())
	local self = setmetatable({
		animator = animator, chain = chain, onHit = onHit,
		tracks = {} :: { AnimationTrack },
		step = 0, lastPress = -math.huge, nextAllowed = 0,
		buffered = nil :: number?, -- os.clock() of a remembered press
		token = 0,
	}, Combo)
	for i, s in chain.steps do
		local t = animator:LoadAnimation(s.anim)
		t.Priority = Enum.AnimationPriority.Action
		t.Looped = false
		self.tracks[i] = t
	end
	return self
end

function Combo:blocked(): boolean
	local char = Players.LocalPlayer.Character
	if not char then return true end
	return char:GetAttribute("Dashing") == true or char:GetAttribute("GuardingLocal") == true
		or char:GetAttribute("FlourishLocal") == true or Players.LocalPlayer:GetAttribute("CutsceneLock") ~= nil
end

function Combo:press()
	if self:blocked() then return end
	local now = os.clock()
	if now < self.nextAllowed then
		if self.nextAllowed - now <= BUFFER then
			self.buffered = now
			local wait = self.nextAllowed - now
			task.delay(wait, function()
				-- fire only if nothing else consumed or cancelled the buffer meanwhile
				if self.buffered and not self:blocked() then
					self.buffered = nil
					self:fire(os.clock())
				end
			end)
		end
		return -- too early and outside the buffer: dropped
	end
	self:fire(now)
end

function Combo:fire(now: number)
	local chain = self.chain
	if now - self.lastPress > chain.window then self.step = 0 end
	self.lastPress = now
	self.step = self.step % #chain.steps + 1
	local i = self.step
	local s = chain.steps[i]
	local t = self.tracks[i]
	-- Cut any other swing short; a chained press starts from the link pose with a tiny fade.
	local chained = false
	for j, other in self.tracks do
		if j ~= i and other.IsPlaying then other:Stop(0.06); chained = true end
	end
	t:Play(chained and 0.04 or 0.1, 1, chain.speed)
	-- Pacing: one gap per swing, plus the later-hit rule so server-side hits stay >= minGap apart.
	local gap = chain.minGap
	local nxt = chain.steps[i % #chain.steps + 1]
	if s.hit > nxt.hit then gap += (s.hit - nxt.hit) / chain.speed end
	self.nextAllowed = now + gap
	self.token += 1
	local token = self.token
	task.delay(s.hit / chain.speed, function()
		if self.token == token and t.IsPlaying then self.onHit(i) end
	end)
end

function Combo:cancel()
	self.buffered = nil
	self.token += 1 -- pending hit callbacks see a stale token and do nothing
	for _, t in self.tracks do if t.IsPlaying then t:Stop(0.1) end end
end

return Combo
```

Why the hit is a `task.delay` and not a `GetMarkerReachedSignal("Hit")` connection: both work, but the marker signal will not fire if the track is stopped a frame early by a cancel, and the delay gives you one place to apply the speed division and the token check. If you use markers (preferred when clips are retimed often), connect once per track at load time and check the token in the handler. See [[Markers and Events]].

`onHit` is where the client fires the swing remote, plays the slash VFX, and triggers local hit-stop. The server repeats its own range and pacing checks; never trust the step number the client sends.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Clicks get "eaten" | Early presses dropped | One-press buffer of 0.1 to 0.2 s |
| Two swings blur together | Fading the new swing over a still-playing old one | Stop the old (0.06), start the new from the link pose (0.04) |
| Snap when the player stops clicking | End pose not the class rest | Re-key the last frame to the rest |
| Finisher then next hit rejected by server | Later hit compresses the gap | Delay next press by the hit difference |
| Damage before the blade arrives | Hit at click time, or marker lost in a bake | Hit at the marker; verify markers after every bake |
| Hits land behind a dashing caster | Hits centred on cast start while the body moved past acceptance range | Raise N, or list hits along the path |
| Double damage or double VFX | Upper-body copy and full clip both fire markers | Mark copies and skip them in listeners |

## Checklist

- [ ] Hit times stored per step (from markers), divided by playback speed.
- [ ] Min gap per class; later-hit rule applied.
- [ ] One-press buffer; combo window resets the step.
- [ ] Every swing starts on the previous link pose and ends on the class rest.
- [ ] Chained fade about 0.04, previous stop about 0.06, fresh fade about 0.1.
- [ ] Server validates range and pacing independently.
- [ ] Ability hits use `marker - 0.06` against a cast sent 0.06 s after clip start; markers verified after bakes.

See also: [[Weapon and Combat Animation]], [[Ability Kits Architecture]], [[Hit Reactions Stagger and Hit-Stop]], [[Markers and Events]], [[Replication and Ownership]], [[Weapon Swing Design]].

## Connected notes
<!-- auto-links:start -->
[[Hitboxes and Hit Detection]] · Melee Combat System End to End · Input Buffering · [[Snippets - Playing Animations]] · Input Responsiveness Buffering and Coyote Time · Detecting Combat Exploits - Reach Rate and Aim · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Timing Spacing and Frame Charts]] · [[Enemy Animation State Protocol]] · [[Playback, Priorities and Blending]] · [[Stance and Charge Moves]] · [[Cinematic Ultimates]] · [[Equip Draw and Flourish Systems]] · [[Locomotion and Melee Reference Numbers]] · [[Boss Animation and Phases]]
<!-- related:end -->
