---
tags: [game-feel, juice, hit-stop, camera-shake, tuning, combat, numbers, luau]
---
# Hit-Stop and Screen Shake Tuning by Numbers

<!-- tldr:start -->
> [!tldr] TL;DR
> - Light hits feel inconsistent on phones: 50 ms stops are 1 or 2 frames at 30 fps -> Raise important stops to 66 ms or more, or accept and rely on...
> - Fast weapons feel laggy: Unbudgeted stops add up in flurries -> Rolling window budget with reserve for finishers
> - Shake turns to jitter on phones: Noise frequency above Nyquist at low fps -> Cap at 0.4 x smoothed fps
> - Every hit has one strength value; stop, trauma and kick derive from it.
> - Light tier produces no stop and no shake.
> - One hit-stop per swing; trauma scales with log of target count.
>
> Read more (20 KB note): ## 4. What a shake looks like depends on FOV, not resolution · ## 7. A tuning module · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Hit Reactions Stagger and Hit-Stop]] explains how to build a hit-stop that does not desync from clock-timed effects, and [[Camera Shake and Camera FX]] gives a trauma shake with envelopes and caps. This note assumes both and answers the next question: **what numbers do you actually type in, and how do you know they are right?** It covers frame math at the frame rates Roblox players really run, a strength ladder that ties stop length and trauma to one value, budgets that stop flurries from grinding to a halt, how field of view and screen size change what a shake looks like, the aliasing trap on 30 fps phones, and a tuning workflow you can repeat.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project** (one live action game), **rule of thumb**.

---

## 1. Think in frames, budget in seconds

Players perceive hit-stop as "the action caught for a moment". What they actually see is a number of rendered frames in which the pose barely changes. That number depends on the frame rate, and Roblox clients run at very different ones:

| Device class (rule of thumb) | Typical frame rate | One frame lasts |
|---|---|---|
| Old or hot phone | 25 to 30 fps | 33 to 40 ms |
| Mid phone, console, laptop | 50 to 60 fps | 17 to 20 ms |
| Gaming PC with a raised frame cap | 120 to 240 fps | 4 to 8 ms |

A 50 ms stop is three frames at 60 fps and **one or two** frames at 30 fps, depending on where the stop starts relative to the frame boundary. That is the first nuance: on a slow device the same stop length alternates between one and two frames from hit to hit, which reads as inconsistency rather than weight. Two practical consequences:

- **Below 2 frames at 30 fps (about 66 ms), short stops are unreliable on phones.** If a beat matters, either give it at least 66 ms or accept that weak devices will see it only half the time. The reference project's catch-up stop runs from 50 ms (strength 0.45) to about 89 ms (strength 1.3): the light end is below the phone threshold and the heavy end above it. That is acceptable because light stops are seasoning, but do not lean on a 50 ms stop to communicate anything important.
- **Effects that must be exactly N frames (impact frames, white flashes) should count rendered frames, not seconds.** Connect to `RunService.PreRender` and remove the flash after the second callback, not after `task.wait(1/30)`. On a 240 fps PC a 1/30 s flash is eight frames of strobe; counting frames keeps it one or two at every rate.

The catch-up technique (slow to 0.12x, then run at 1.88x for the same length) is frame-rate independent because it changes playback speed, not frame counts. Keep it for the body, and use frame counting only for full-screen effects.

---

## 2. One strength value drives everything

The strongest tuning decision is to stop tuning each effect separately. Give every hit a single **strength** number (the reference project used beat strengths from about 0.3 to 1.3, set per animation marker; see [[Ability Kits Architecture]]) and derive every layer from it. Then a designer moves one slider per move, and all layers stay proportional.

A ladder that extends the reference formula `stop = 0.03 + 0.045 x strength` (measured in the reference project) to shake and kick:

| Tier | Strength | Hit-stop (attacker) | Trauma added | Directional kick | Shake felt (trauma squared) |
|---|---|---|---|---|---|
| Light | 0.30 | none | 0 | none | 0 |
| Medium | 0.45 | 50 ms | 0.12 | 0.25% of screen height | 0.014 |
| Heavy | 0.80 | 66 ms | 0.25 | 0.5% | 0.063 |
| Finisher | 1.00 | 75 ms | 0.35 | 0.8% | 0.12 |
| Ultimate | 1.30 | 89 ms | 0.60 | 1.2% | 0.36 |

Hit-stop values are the reference formula; trauma and kick values are a rule-of-thumb starting point. Read the last column carefully: because shake is trauma squared, a Medium hit produces almost nothing (0.014 of the maximum), and that is intended. Stacking three Medium hits in quick succession brings trauma to about 0.36 (minus decay) and shake to about 0.13, which is a finisher's worth. **The squaring means small hits only matter in aggregate**, so a flurry builds naturally without each hit needing its own shake.

Why Light hits get nothing: the [[Game Feel and Juice]] rule "only big moments get shake" is easier to keep when the bottom tier is zero by construction. A glint and a sound are enough for a light cut.

### Diminishing returns for multi-target hits

A sweep that hits eight enemies should not stop eight times, and should not add eight lots of trauma. Rules that hold up (rule of thumb):

- **One hit-stop per swing**, keyed by a swing id. The first target to register triggers it; the rest are ignored.
- **Trauma grows with the logarithm of the target count**: `trauma x (1 + 0.35 x log2(count))`. One target gives 1x, two give 1.35x, four give 1.7x, eight give 2.05x. Big crowds feel bigger without becoming a seizure.
- **Strength is the maximum across targets**, not the sum. A crit on one enemy in a crowd still gets the crit's stop.

---

## 3. Budgets: the flurry problem

A fast weapon with five Medium hits in 0.8 s would, without limits, spend 250 ms of that 0.8 s in hit-stop. The move feels sticky, as if the game is lagging, and inputs buffered during the stops come out late (see [[Input Responsiveness Buffering and Coyote Time]]).

Budgets solve it:

| Budget | Value (rule of thumb) | What happens when exceeded |
|---|---|---|
| Hit-stop time per rolling 0.6 s window | 140 ms | Further stops in the window are skipped |
| Hit-stop share of a move's duration | under 15% | Lower the move's beat strengths in data |
| Trauma ceiling from one source per second | 0.6 | Extra trauma from that source is dropped |
| Time with visible shake (shake > 0.05) | under 10% of combat seconds | Tune trauma down, or decay faster |

The first is a runtime guard, the second a data review you run over all moves, the third keeps one long ability from monopolising shake, and the fourth is a playtest measurement (log shake each frame and count). The "10% of combat seconds" figure is a rule of thumb; teams that ship more shake usually also ship a strong reduced-motion setting and accept the trade.

The order in which hits consume the budget matters. Spend it on **the last hit of a combo first**: if a combo's finisher would be skipped because three earlier light-medium hits used the window, the combo feels like it fizzles. Tag finishers as `reserve = true` so earlier hits leave room for them (implementation below).

---

## 4. What a shake looks like depends on FOV, not resolution

Trauma shake rotates the camera by a few degrees. How far that moves the image **on screen** depends on the camera's vertical field of view (`Camera.FieldOfView` is vertical, in degrees, per Roblox docs as of October 2026).

The screen-space displacement for a small rotation `a` near the centre of the screen, as a fraction of screen height, is:

```
fraction = tan(a) / (2 x tan(FOV / 2))
```

So:

| FOV | 1 degree of rotation moves the image by | On a 1080 px tall screen |
|---|---|---|
| 40 (zoomed aim) | 2.4% of height | 26 px |
| 70 (Roblox default) | 1.25% of height | 13.5 px |
| 90 (sprint or wide) | 0.87% of height | 9.4 px |

Two consequences most shake systems miss:

- **Resolution does not matter**, because the fraction is independent of pixel count. A phone and a 4K monitor see the same proportion of movement. Specify shake as a fraction of screen height and you never need per-device tuning for size.
- **FOV matters a lot.** A shake tuned at FOV 70 is almost twice as violent while zoomed to FOV 40. Games with aim-down-sights or zoom must scale rotational shake by `tan(FOV / 2) / tan(35 degrees)`. If your [[Camera Shake and Camera FX]] envelopes push FOV up on dashes, the shake during a dash is correspondingly weaker, which is usually fine.

Translational shake (camera-space offset in studs) behaves differently: its on-screen size depends on distance to what you are looking at. A 0.3 stud offset is huge on a close-up shoulder camera and invisible on a top-down camera 60 studs up. **Use rotation for impacts and translation only for "the ground moved" effects** (landings, explosions under the player), where parallax between near and far objects is the point.

### Phones and the 30 fps aliasing trap

The reference trauma shake samples smooth noise at 16 Hz. At 60 fps that is about four samples per noise cycle, which reads as a smooth judder. At 30 fps it is under two samples per cycle, at or past the Nyquist limit (half the frame rate, 15 Hz). The result looks like random teleporting, the exact thing smooth noise was supposed to avoid.

Rule of thumb: **cap the noise frequency at 0.4 x the current frame rate**. At 30 fps that is 12 Hz; at 60 fps, 24 Hz (so the 16 Hz design value is untouched). Measure the frame rate as a smoothed average over the last half second, not the instantaneous `dt`, or a single hitch will change the shake character mid-effect.

---

## 5. Distance falloff curves

Onlookers and nearby explosions need falloff. The reference project's ultimates gave onlookers 0.3x trauma, full at 30 studs and zero at 150 (measured in the reference project). The curve between those radii is a choice:

| Curve | Formula (u = 0 at near, 1 at far) | Feel |
|---|---|---|
| Linear | `1 - u` | Simple; mid-range shakes feel a bit strong |
| Smoothstep | `1 - u x u x (3 - 2u)` | Plateau near, gentle tail; good default |
| Quadratic | `(1 - u)^2` | Drops fast; only nearby events register |
| Inverse square (physical) | `near^2 / d^2` | Realistic but punishes far events too hard; rarely what you want |

Because trauma is squared again for display, linear falloff on trauma becomes quadratic on visible shake. Most teams find smoothstep on trauma gives the right "I felt that from over there" without mid-range noise.

---

## 6. Directional kick versus noise

Noise says "something heavy happened". A **directional kick** says "it happened over there". A kick is a single, short rotation away from the impact direction (or along the attack direction for your own hits), with a fast return. Numbers that work (rule of thumb):

- Rise in 1 frame (no tween; set it), return over 0.10 to 0.18 s with an ease-out.
- Size from the tier table (0.25% to 1.2% of screen height), converted to degrees with the FOV formula.
- Fire the kick **on the hit frame**, and the noise **when the hit-stop releases** (the ordering rule from [[Camera Shake and Camera FX]]: shaking during a freeze hides the freeze).

The kick is also the best choice for reduced-motion players who still want some confirmation, at 0.25x size: a single small displacement carries direction without the oscillation that causes discomfort ([[Motion Sensitivity and Camera Comfort]]).

---

## 7. A tuning module

One module holds the ladder, applies the budgets and converts screen fractions to degrees. Everything that triggers hit feel calls `HitFeel.request` and receives the numbers to apply; it does not apply them itself, so it plugs into whatever hit-stop and camera modules you already have.

```lua
--!strict
-- HitFeel: one strength value in, budgeted hit-stop / trauma / kick numbers out.
local Workspace = game:GetService("Workspace")

local HitFeel = {}

export type Request = {
	strength: number,      -- beat strength, about 0.3 to 1.3
	swingId: number,       -- same id for every target hit by one swing
	targetCount: number,   -- targets hit by this swing so far (1 for the first)
	reserve: boolean?,     -- true for finishers: earlier hits leave room for these
	fromOnlooker: boolean?, -- true when the hit belongs to someone else
	distance: number?,     -- studs from the camera, used for onlooker falloff
}

export type Result = {
	stopSeconds: number,   -- 0 means no hit-stop
	trauma: number,        -- add to the shake system
	kickDegrees: number,   -- one-off rotation away from the hit
}

-- Tunables. Hit-stop formula is from the reference project; the rest is a starting point.
local MIN_STOP_STRENGTH = 0.45
local WINDOW = 0.6           -- seconds
local WINDOW_BUDGET = 0.14   -- seconds of hit-stop per window
local RESERVE = 0.06         -- budget kept free for reserve hits
local ONLOOKER_SCALE = 0.3
local NEAR, FAR = 30, 150

local recentStops: { { t: number, d: number } } = {}
local stoppedSwings: { [number]: boolean } = {}
local lastSwingCleanup = os.clock()

local function stopSeconds(strength: number): number
	if strength < MIN_STOP_STRENGTH then
		return 0
	end
	return 0.03 + 0.045 * strength
end

local function traumaFor(strength: number): number
	-- piecewise-linear through the tier table: 0.3 -> 0, 0.45 -> 0.12, 1.0 -> 0.35, 1.3 -> 0.6
	if strength <= 0.3 then
		return 0
	elseif strength <= 0.45 then
		return (strength - 0.3) / 0.15 * 0.12
	elseif strength <= 1.0 then
		return 0.12 + (strength - 0.45) / 0.55 * 0.23
	end
	return 0.35 + math.min(strength - 1.0, 0.3) / 0.3 * 0.25
end

local function kickFraction(strength: number): number
	-- fraction of screen height: 0.25% at Medium up to 1.2% at Ultimate
	if strength < MIN_STOP_STRENGTH then
		return 0
	end
	local u = math.clamp((strength - 0.45) / 0.85, 0, 1)
	return 0.0025 + u * (0.012 - 0.0025)
end

-- Converts a fraction of screen height into degrees of camera rotation at the current FOV.
function HitFeel.fractionToDegrees(fraction: number): number
	local camera = Workspace.CurrentCamera
	local fov = if camera then camera.FieldOfView else 70
	local halfTan = math.tan(math.rad(fov) / 2)
	return math.deg(math.atan(fraction * 2 * halfTan))
end

local function usedBudget(now: number): number
	local used = 0
	for i = #recentStops, 1, -1 do
		local s = recentStops[i]
		if now - s.t > WINDOW then
			table.remove(recentStops, i)
		else
			used += s.d
		end
	end
	return used
end

local function smoothFalloff(distance: number): number
	local u = math.clamp((distance - NEAR) / (FAR - NEAR), 0, 1)
	return 1 - u * u * (3 - 2 * u)
end

function HitFeel.request(r: Request): Result
	local now = os.clock()
	if now - lastSwingCleanup > 5 then
		table.clear(stoppedSwings) -- swing ids are short-lived; drop old ones
		lastSwingCleanup = now
	end

	local count = math.max(1, r.targetCount)
	local crowd = 1 + 0.35 * math.log(count, 2)
	local trauma = traumaFor(r.strength) * crowd

	if r.fromOnlooker then
		-- Someone else's hit: mild shake only, never hit-stop or kick on our screen.
		local falloff = smoothFalloff(r.distance or FAR)
		return { stopSeconds = 0, trauma = trauma * ONLOOKER_SCALE * falloff, kickDegrees = 0 }
	end

	local stop = stopSeconds(r.strength)
	if stop > 0 then
		if stoppedSwings[r.swingId] then
			stop = 0 -- one stop per swing, however many targets
		else
			local used = usedBudget(now)
			local limit = if r.reserve then WINDOW_BUDGET else WINDOW_BUDGET - RESERVE
			if used + stop > limit then
				stop = 0
			else
				stoppedSwings[r.swingId] = true
				table.insert(recentStops, { t = now, d = stop })
			end
		end
	end

	local kick = if r.targetCount <= 1 then HitFeel.fractionToDegrees(kickFraction(r.strength)) else 0
	return { stopSeconds = stop, trauma = math.min(trauma, 1), kickDegrees = kick }
end

-- Smoothed frame rate, used to cap shake noise frequency (0.4 x fps).
local fpsAverage = 60
function HitFeel.noteFrame(dt: number)
	if dt > 0 then
		fpsAverage += (1 / dt - fpsAverage) * math.min(1, dt * 2) -- about half a second of smoothing
	end
end

function HitFeel.maxNoiseHz(designHz: number): number
	return math.min(designHz, 0.4 * fpsAverage)
end

return HitFeel
```

Call `HitFeel.noteFrame(dt)` from the same `PreRender` callback that steps your camera effects, and pass `HitFeel.maxNoiseHz(16)` as the noise frequency each frame. Note what the reserve logic does: ordinary hits may use only 80 ms of the 140 ms window, so one Medium (50 ms) or one Heavy (66 ms) stop fits per 0.6 s, and a finisher (75 ms) still fits after either. That is deliberately strict; loosen it if your combos are slow, and recheck the arithmetic whenever you change the ladder, because a non-reserve limit below your smallest stop silently disables hit-stop for every ordinary hit.

---

## 8. A tuning workflow that converges

Tuning by feel alone drifts: after an hour, every developer's tolerance for shake is higher than a new player's. A repeatable process (rule of thumb, adapted from common action-game practice):

1. **Expose the knobs live.** Read the ladder from attributes on a folder (for example `HitFeelTuning`) so you can change values during a Play session without restarting. Copy final values back into the module; never ship attribute-driven tuning that the client can be tricked into changing for other players (it is local-only presentation, so the risk is low, but keep the source of truth in code).
2. **Tune with sound on and off.** Sound carries about half of the perceived impact ([[Combat Sound Design and Feedback]]). A hit that feels right only with sound is under-tuned visually for players on mute, which on phones is many of them.
3. **Tune on the worst device first.** A 30 fps phone shows the frame-quantisation and aliasing problems; a PC hides them.
4. **Record and step through frames.** Screen-record at the device's native rate and step frame by frame. Check: the stop starts on the contact frame, the flash is one or two frames, the kick is on the hit frame, the noise starts after the stop.
5. **Blind A/B with a fresh player.** Give two builds (current and 30% less shake) to someone who has not played. New players almost always prefer less shake than developers.
6. **Measure the shake share.** Log `trauma^2 > 0.05` per frame during a five-minute combat session. Over 10% is a warning; over 20% is a problem.
7. **Check the extremes.** Eight targets at once, three players using ultimates near you, a full-strength flurry at 30 fps, reduced motion on, zoomed FOV. Every extreme should stay inside the caps.

---

## 9. When not to use hit-stop or shake

- **Rapid-fire ranged weapons.** At ten shots per second, any stop per shot is a stutter. Use per-shot recoil (a kick that recovers) and save stops for kills.
- **Other players' attacks on your screen.** Never stop their animation for you, and keep their trauma at a fraction; covered above and in [[Hit Reactions Stagger and Hit-Stop]].
- **Hits you take, in most designs.** Getting hit should be readable through flinch, flash and sound. A hit-stop on the victim takes control at the worst moment. Some fighting games do pause both sides; on Roblox, with latency on the victim's damage event, a victim-side freeze arrives late and feels like lag.
- **Menus and economy actions.** A shake on "Purchase" is a strong signal; save it for rewards (see [[Reward Moments and Celebrations]]).
- **Under reduced motion.** No stop, no noise; at most a small kick, as discussed.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Light hits feel inconsistent on phones | 50 ms stops are 1 or 2 frames at 30 fps | Raise important stops to 66 ms or more, or accept and rely on other layers |
| Fast weapons feel laggy | Unbudgeted stops add up in flurries | Rolling window budget with reserve for finishers |
| Shake turns to jitter on phones | Noise frequency above Nyquist at low fps | Cap at 0.4 x smoothed fps |
| Zoomed aim shake is violent | Rotational shake tuned at default FOV | Scale by `tan(FOV/2) / tan(35 deg)` |
| Sweeps over crowds are blinding | Trauma summed per target | Log scaling, one stop per swing |
| Impact flash is a strobe on 240 fps PCs | Flash timed in seconds | Count rendered frames |
| Developers love it, new players feel sick | Tuned by habituated testers | Blind A/B with fresh players, measure shake share |

## Checklist

- [ ] Every hit has one strength value; stop, trauma and kick derive from it.
- [ ] Light tier produces no stop and no shake.
- [ ] One hit-stop per swing; trauma scales with log of target count.
- [ ] Rolling hit-stop budget, with room reserved for finishers.
- [ ] Shake specified as screen fraction, converted with FOV.
- [ ] Noise frequency capped by the smoothed frame rate.
- [ ] Onlooker trauma scaled and faded with a smoothstep falloff.
- [ ] Kick on the hit frame, noise after the stop releases.
- [ ] Tuned on a 30 fps phone, with and without sound, and checked by a fresh player.
- [ ] Reduced motion: no stop, no noise, small kick at most.

## Connected notes
<!-- auto-links:start -->
[[Snippets - Camera Shake and FX]] · [[Game Feel Start Here]] · [[Hit-Stop]] · [[Cinematic Ultimates]] · [[Combat Combo Systems]] · [[Combat Animation Craft]]
<!-- auto-links:end -->
