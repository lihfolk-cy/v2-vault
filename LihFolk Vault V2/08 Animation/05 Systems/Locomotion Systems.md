---
tags: [systems, locomotion, animate-script, gait, carry-layer, type/guide, area/animation, level/intermediate, api/Humanoid, api/Animator]
---
# Locomotion Systems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Feet skate at top speed: Rate clamp below `speed / GroundSpeed` -> Author a gait for that speed, or widen the band check above
> - Legs scissor on walk to run: Gaits start at time 0, or authored with different lead foot -> Phase-preserving swap, one foot-order convention
> - Stumble on every bunny-hop: Land plays while moving -> Land only standing
> - Each gait's authored GroundSpeed stored as data, read by the controller.
> - The most common movement speed has a clip authored at that speed.
> - For every gait, `[threshold_low, threshold_high]` is inside `[clamp_min, clamp_max] * GroundSpeed`.
>
> Cost: TL;DR ~190 tok · whole note ~5.2k tok. Read more: ## The universal set (one locomotion for everyone) · ## Gaits that cannot slide · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Locomotion is the animation the player sees most: every second they are not attacking, they are idling, walking, running, jumping or landing. It is also where small errors are most visible, because the eye locks onto feet. A swing that is 10% too fast is invisible; feet that skate 10% of their speed read as "cheap" instantly. This note covers how locomotion is built on Roblox, from the stock `Animate` script to a universal custom set with measured numbers from one live action game (the reference project). The design of the controller module itself is in [[Custom Locomotion Controller Design]].

## The three ways to own locomotion

Every player character gets a LocalScript named `Animate` (see [[The Default Animate Script]]). It holds `StringValue`s such as `idle`, `walk`, `run`, `jump`, `fall`, `climb`, `swim` and `toolnone`, each with `Animation` children, and it drives them from `Humanoid` events (`Running`, `Jumping`, `FreeFalling`, `Climbing`, `Swimming` and state changes).

| Approach | What you do | Good for | Costs |
|---|---|---|---|
| Swap ids | On `CharacterAdded`, set e.g. `Animate.walk.WalkAnim.AnimationId`, then stop playing tracks so the new ids load | Reskinning the default feel | You inherit Animate's speed logic, thresholds and blend times |
| Fork | Copy `Animate` into `StarterPlayer.StarterCharacterScripts` and edit it | Small logic changes | You now maintain a long script that Roblox may change upstream |
| Replace (fully or partly) | Run your own state machine from `Humanoid.StateChanged`, velocity and `FloorMaterial`; leave Animate running for the states you don't handle | Games with weapons, abilities and custom feel | You own every edge case |

The reference project used the third option but kept `Animate` alive underneath. That decision matters more than it looks, see "Hand back to Animate" below.

### Why "replace partly" beats "replace fully"

`Animate` handles climbing, swimming, sitting and a dozen odd Humanoid states that most combat games never author clips for. If you delete it, a player who touches a `TrussPart` or sits in a `Seat` gets a T-pose. If you keep it and play your clips at a higher priority, your clips win whenever they play, and Animate quietly covers everything else. The cost is that Animate's own tracks are still running at low weight, including its tool-hold, which you must deal with explicitly (see "The tool-hold trap").

## The universal set (one locomotion for everyone)

The reference project went through per-weapon locomotion (a katana walk, a heavy-weapon run, premium per-blade idle/walk/run) and then deliberately threw it away. The final rule, set by the game's owner, was: **one locomotion for everyone, armed or not. A held weapon only adds its class Carry layer.** The reasons are worth repeating because most teams learn them the hard way:

- Each extra gait set multiplies the foot-slide, transition and phase-sync work by the number of sets.
- Gait sets per weapon mean swapping locomotion on equip, which pops unless both sets share stride phase and timing.
- Players cannot tell a "katana walk" from a "sword walk" at gameplay camera distance, but they can see the arm and blade. So spend the budget on the arm (the Carry layer).

### The clip table

| Clip | GroundSpeed (studs/s) | Notes |
|---|---|---|
| Idle | none | 4 s loop. Variants IdleLook, IdleShift |
| Walk | 11 | Double support phase (both feet down briefly) |
| Jog | 22 | Equal to the game's base walk speed, so the most common speed plays at exactly 1x |
| Run | 64 | The sprint |
| Jump, Fall (loop), Land | none | Air states |

All numbers are measured in one production game at 1.6x character scale (characters about 9 studs tall). `GroundSpeed` is stored as an attribute on each clip's KeyframeSequence, so the controller reads it instead of hard-coding it (with 11 / 22 / 64 as the fallback).

### Why the base speed got its own clip

The single most important tuning choice is to author one gait at exactly the speed players spend most time at. Rate scaling (`AdjustSpeed`) is invisible near 1x and increasingly visible away from it: at 0.6x a jog looks like moonwalking in syrup, at 1.8x it looks like a cartoon. Put the authored speed where the players are.

## Gaits that cannot slide

Foot slide is the mismatch between how fast the planted foot moves backward relative to the root and how fast the root moves forward over the ground. If the planted foot moves back at exactly the ground speed, the foot is stationary in world space. The universal set was built procedurally so that **each foot's ground contact moves back at exactly `GroundSpeed`** through a heel, flat, toe rock (no slide by construction), then baked to clips.

Measured slip with the real Animator (project measurement):

| Gait | Slip at authored speed |
|---|---|
| Walk at 11 | at most 1.8 studs/s |
| Jog at 22 | under 1 stud/s |
| Run at 64 | under 1 stud/s |

The walk is worst because heel strike and toe-off are longer fractions of a slow cycle, and the rotation-vector interpolation between keys (see [[How the Animator Really Behaves]]) bends the foot path slightly between baked samples. 1.8 studs/s at 11 is about 16%, still within what reads as planted at gameplay distance.

### Rate scaling keeps the feet planted, until it clamps

Playback rate is `speed / GroundSpeed`. If the character moves at 16.5 studs/s on the walk (GroundSpeed 11), the clip plays at 1.5x and the planted foot moves back at 16.5: still no slide. Slide only returns when the rate **clamps**. The universal controller clamps per gait:

| Gait | Chosen when | Rate clamp | Ground speed range with no slide |
|---|---|---|---|
| Walk | 1 <= speed < 16 | 0.4 to 1.7 | 4.4 to 18.7 |
| Jog | 16 <= speed < 38 | 0.6 to 1.8 | 13.2 to 39.6 |
| Run | speed >= 38 | 0.55 to 1.45 | 35.2 to 92.8 |

Read the last column against the thresholds. The upper edges have margin everywhere (walk to 18.7 against a switch at 16, jog to 39.6 against 38, run to 92.8 against the 64 sprint). The one gap is the bottom of the walk: between 1 and 4.4 studs/s the walk is clamped at 0.4x, so the feet move faster than the body (an "overstep" slide, the opposite of skating). In practice speed only passes through that band during the first and last frames of acceleration, so nobody sees it. If your game has a slow sneak, it needs its own clip.

That comparison is the test to run on your own table: if a gait's band extends past `clamp_max * GroundSpeed` (or below `clamp_min * GroundSpeed`), the feet slide in that part of the band.

**Case study: the run that slid at sprint.** The set that shipped before the universal set ran at `clamp(speed / 26, 0.7, 1.5)` above `BaseWalkSpeed + 6`, with walk at `clamp(speed / 16, 0.6, 1.8)`. At the sprint speed of about 64, the run wanted 2.46x and got 1.5x. If its true ground speed was near its divisor of 26 (arithmetic, not measured), the feet covered 39 studs/s while the body covered 64: 25 studs/s of slide, about 40%. It was a known issue for weeks. The two fixes are "author a sprint clip" (what the universal set did with Run at 64) or "raise the cap" (which turns the run into a cartoon). Prefer the clip.

### Scale breaks authored strides

On the 1.6x character, an earlier authored-clip version scaled strides by character scale, giving strides of 9.6 / 15.2 / 22.4 studs while the legs only planted about 5 to 8 studs per cycle. Feet slid 50 to 95% by design. Lesson: if your character is scaled through Humanoid body scales, the Animator does not scale clip root offsets for you, and stride lengths authored at scale 1 are wrong. See [[Scale and Animation]].

## Phase-preserving gait swaps

When the speed crosses 16 or 38, the controller swaps Walk for Jog or Jog for Run. If the new clip starts at time 0, the feet jump: the old clip had the left foot forward, the new one starts with the right foot planted. The fix is to start the new clip **at the same normalised phase**:

```lua
-- prev and nextTrack are AnimationTracks of two gait clips authored with the same
-- foot order (left contact at phase 0 in both). Copy the stride phase across.
local function swapGait(prev: AnimationTrack?, nextTrack: AnimationTrack, fade: number, rate: number)
	local phase: number? = nil
	if prev and prev.IsPlaying and prev.Length > 0 then
		phase = prev.TimePosition / prev.Length -- 0..1 through the stride
	end
	nextTrack:Play(fade, 1, rate)
	if phase and nextTrack.Length > 0 then
		-- Set after Play: Play() restarts at 0, so a TimePosition set before it is lost.
		nextTrack.TimePosition = phase * nextTrack.Length
	end
	if prev and prev ~= nextTrack then
		prev:Stop(fade)
	end
end
```

This only works if all gaits share an authoring convention: same foot leads at phase 0, one full stride (two steps) per loop. Check that before trusting phase sync; a walk authored "right foot first" will cross-fade into a run with legs scissoring through each other for the length of the fade.

During the fade both clips play. With matching phase, the two poses are close, so the blend is a mild average instead of a mush. The fade length matters less than the phase match; the reference project uses 0.15 s between gaits.

## The air states

Jump, Fall and Land look simple and cause most locomotion bugs. The universal controller's rules (project values):

- **Jump** plays for up to 0.42 s after `Humanoid.Jumping`, and only while vertical velocity is above -4 studs/s (so walking off a ledge goes straight to Fall).
- **Fall** loops whenever `Humanoid.FloorMaterial == Enum.Material.Air` and Jump does not apply.
- **Land** plays only when the character has been airborne more than 0.3 s, landed less than 0.5 s ago, **and is standing (horizontal speed under 6)**. On the move, the stride simply carries on.

That last rule is the nuance: a land clip played while running stops the legs for a quarter second and reads as a stumble. Players who bunny-hop see it every jump. Only land standing.

### Fades used by the reference controller

| From / to | Fade (s) | Why |
|---|---|---|
| Anything to Jump or Land | 0.08 | Take-off and impact must be crisp |
| Land to anything | 0.25 | Let the recovery breathe |
| Gait to gait | 0.15 | Phase-matched, short is fine |
| Anything to Fall | 0.2 | Fall is a soft state |
| Into or out of idle variants | 0.4 | Idle variants are slow, a quick fade looks like a twitch |
| Default | 0.2 | |

Fades are linear in the Animator (measured, see [[Playback, Priorities and Blending]]), so a 0.08 s fade at 60 fps is about 5 frames.

## Hand back to Animate

The universal controller returns "nothing" for these Humanoid states and lets the default `Animate` play its own clips:

- `Climbing`, `Swimming`, `Seated`, `Ragdoll`, `FallingDown`, `PlatformStanding`

It also returns nothing when the character is dead, dashing (a `Dashing` attribute), or downed. When the controller stops its tracks, the only things left playing are Animate's, which is exactly the desired fallback. This is why the custom clips play at priority **Movement**: above Animate's Core-priority locomotion and its tool-hold, below everything else (attacks, flourishes, abilities). See [[Humanoid States and Animation]].

## The tool-hold trap

When a character holds a `Tool`, Animate plays `ToolNoneAnim`: the right arm held straight out at shoulder height. It runs at Idle priority, above Animate's walk and run. If your weapon is held in a custom grip, or rests off the hand, that straight arm fights your Carry layer and your idle.

The reference project finds Animate's playing track by name (`ToolNoneAnim`) or by the stock asset id, and fades its weight to **0.001** over 0.15 s whenever the blade is not really "held". Why 0.001 and not stopping it? Animate restarts its tool animation on its own events; a stopped track comes back on the next equip or state change, while a track left playing at near-zero weight stays put. 0.001 is invisible and stable.

## Carry layers

A Carry layer is a clip that keys **only the right arm** (shoulder, elbow, wrist) holding the weapon in its class pose. It plays over whatever gait is running, so one locomotion set serves every weapon class.

Rules that held up in production:

- **Carry pose = the swings' end pose.** Every swing in the combo ends on the class rest (idle plus carry). When the swing finishes and the carry takes the arm back, nothing turns. If the carry pose differs from the swing end pose by a forearm twist, the hand-off shows a visible wrist roll every single swing.
- **The carry steps aside** while swinging (and blends back in over the swing's last 0.22 s), guarding, dashing, during an equip flourish, while the root is anchored, during a premium idle, and when the class has its own standing idle (a staff idle replaces carry when standing still).
- **Priority.** The project notes say the carry must be at **Action**, because an Action2 carry cancels the equip flourishes (which cancel on any Action2+ track) and "reads as an attack" to other controllers that watch for Action2+ tracks. However, a later locomotion core's own code comment describes the carry as "right-arm layer, Action2". These two sources disagree; the safe rule is Action, and the disagreement is listed in [[Open Questions]].

The general lesson: **priority is not just a blending order, it is a signal.** Other systems (flourish cancel, ability detection, juice) read track priority to infer intent. Pick priorities by what other code will conclude from them, not only by what wins the blend.

## Idle fidgets

A 4 s idle loop seen for 60 s is noticed. A fidget system adds variants:

- First fidget after **10 s** standing still, then every **16 to 26 s** (random).
- Pool: IdleLook (look around), IdleShift (weight shift), IdleFidget (a face wipe and head shake), **never the same twice running**.
- IdleLook and IdleShift replace the idle as the chosen loco clip for their length minus 0.35 s; the fidget is a one-shot layered on top with a 0.35 s fade.
- Any movement, swing or stance change cuts the fidget (stopped over 0.25 s) and resets the timer. If the timer had already fallen under 10 s, it is pushed back to 10.
- Fidgets only play over the plain idle, never over a two-handed class idle (the face wipe needs a free hand).

The "never twice running" rule matters more than the randomness. With three variants and pure random, the same variant repeats a third of the time, and repetition is what the eye catches.

## Unheld weapons

Some premium weapons float behind the player instead of sitting in the hand. For locomotion they are "no weapon":

- A character attribute `BladeUnheld` (set by the owning client) makes the chooser treat the player as unarmed.
- Carry layers turn off.
- Animate's `ToolNoneAnim` is faded to 0.001 (the arm would otherwise reach for a weapon that is not there).

## Dash steering

A dash is usually a `LinearVelocity` (or an impulse) on the root for 0.2 to 0.4 s. From a standstill there is a bug that is easy to miss: the Humanoid controller sees no move input, so it **brakes** against your velocity. The dash fires, then dies in a few frames.

The fix used in the reference project: for the dash length, bind a RenderStep **after** the default control script and call `Humanoid:Move(direction)` every frame, so the Humanoid believes the player is pushing in the dash direction.

```lua
local RunService = game:GetService("RunService")

-- Call when the dash starts. dir is a world-space flat unit vector.
local function steerDash(hum: Humanoid, dir: Vector3, duration: number)
	local name = "DashSteer"
	local t0 = os.clock()
	-- Enum.RenderPriority.Input is where the PlayerModule reads input; +1 runs after it,
	-- so our Move() call overwrites its "no input" Move() for this frame.
	RunService:BindToRenderStep(name, Enum.RenderPriority.Input.Value + 1, function()
		if os.clock() - t0 > duration or hum.Health <= 0 then
			RunService:UnbindFromRenderStep(name)
			return
		end
		hum:Move(dir, false) -- false: dir is world space, not camera relative
	end)
end
```

The dash lean clip (0.3 s) was tuned with two extra keys: one at 0.045 s putting the upper body 45% further into the lean (a sharper launch), and a settle at 0.255 s overshooting 18% past upright. Total duration unchanged. Small overshoots on settle are the cheapest way to make a short clip feel physical. Camera effects on dash are in [[Camera Shake and Camera FX]].

## Fully procedural and hybrid gaits

The reference project also built two non-clip gaits, documented here for their numbers:

- **Procedural gait:** cadence `clamp(1.45 + 0.0105 * v, 1.55, 2.75)` steps per second, stance length = sweep / speed, 3D two-leg IK on the joints' own attachments, a bent-knee hip drop, bob, the free arm carried forward, a 7 to 9 degree forward lean. Slide about 0 from 12 to 120 studs/s (an earlier version slid about 90% of speed).
- **FootPlant layer (legs only):** follows the authored foot path (a 64-sample track of lift, arc, pitch, touchdown phase) but latches the planted foot per step, lifts the heel by toe-pivot when the hips ride high, caps cadence at 3 steps/s (faster = longer stride plus air) and stretches swing time. Slide 0.00 to 0.01 at 9.6 to 120 studs/s. It ended up switched off: the baked universal set was already good enough, and a layer that edits legs every frame is one more thing to debug.

See [[Procedural Gait and Footstep Planning]] and [[Foot Placement and Ground IK]].

R15 proportions note: R15 legs are short (hip about 3.5 studs above ground at 1.6x scale). A jog or run with short legs needs a **flight phase** (both feet off the ground) to cover ground at speed; a walk needs a **double support** phase. Authoring a run with no flight phase forces either huge strides or a cadence that looks like pedalling.

## Enemy locomotion (summary)

Enemies choose idle / walk / run by root speed, with the clip rate matched to speed and clamped (0.7 to 1.6 in one enemy client). For scaled-up enemies the walk may slow to about `0.85 / sqrt(scale)` (bigger creatures move with longer, slower cycles). A per-zone gait speed sync was tried and dropped: authored strides were 2 to 4x shorter than the AI's move speeds, so matching rates would play "frantic". Lengthen strides or lower move speeds instead. Details in [[Enemy and NPC Animation]] and [[Enemy Animation State Protocol]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Feet skate at top speed | Rate clamp below `speed / GroundSpeed` | Author a gait for that speed, or widen the band check above |
| Legs scissor on walk to run | Gaits start at time 0, or authored with different lead foot | Phase-preserving swap, one foot-order convention |
| Stumble on every bunny-hop | Land plays while moving | Land only standing |
| Arm sticks straight out | Animate's `ToolNoneAnim` | Fade it to 0.001 |
| T-pose on ladders or seats | Animate deleted | Keep Animate, hand those states back |
| Dash dies from standstill | Humanoid brakes with no input | `Humanoid:Move` after input each frame |
| Forearm rolls after each swing | Carry pose differs from swing end pose | Make them identical |
| Flourish cancelled by locomotion | Carry layer at Action2 | Carry at Action |

## Checklist

- [ ] Each gait's authored GroundSpeed stored as data, read by the controller.
- [ ] The most common movement speed has a clip authored at that speed.
- [ ] For every gait, `[threshold_low, threshold_high]` is inside `[clamp_min, clamp_max] * GroundSpeed`.
- [ ] All gaits share foot order and one stride per loop; swaps keep phase.
- [ ] Land plays only standing, after a real fall.
- [ ] Animate kept for climb, swim, seat, ragdoll, platform stand.
- [ ] Tool-hold faded when you own the arm.
- [ ] Carry pose equals swing end pose; carry steps aside for swings, guard, dash, flourish.
- [ ] Idle variants never repeat back to back.

See also: [[Custom Locomotion Controller Design]], [[The Default Animate Script]], [[Playback, Priorities and Blending]], [[Weapon and Combat Animation]], [[Combat Combo Systems]], [[Procedural Gait and Footstep Planning]], [[Snippets - Animation Controller Module]].

## Connected notes
<!-- auto-links:start -->
[[Troubleshooting Table]] · [[Idle Breathing and Secondary Motion]] · [[Timing Spacing and Frame Charts]] · [[Animation Glossary]] · [[Custom Character Controllers]] · Official Docs - Characters and Animation · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[R15 Run Cycle Key Poses]] · [[Locomotion and Melee Reference Numbers]] · [[Mounts and Rideable Creatures]] · [[Emotes and Social Animation]] · [[Equip Draw and Flourish Systems]] · [[Locomotion Readability - Lessons from Blind Panels]] · [[Hit Reactions Stagger and Hit-Stop]] · [[Stance and Charge Moves]]
<!-- related:end -->
