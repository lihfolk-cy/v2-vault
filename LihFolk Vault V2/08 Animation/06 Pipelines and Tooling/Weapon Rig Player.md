---
tags: [pipeline, runtime, weapons, motor6d, keyframesequence, type/guide, area/animation, level/intermediate, api/Animator, area/gameplay, api/Part0, api/TweenService]
---
# Weapon Rig Player

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Root pose not named after Part0 -> name the weight-0 root pose `Handle` (the motors' Part0)
> - Avoid: Chained hinge pose not nested -> nest poses like the joint tree
> - Avoid: FX module spins a motor that a clip also keys -> one owner per motor: clip or code
>
> Cost: TL;DR ~110 tok · whole note ~3.3k tok. Read more: ## Usage · ## Clip parsing and the interpolation rule · ## Common mistakes
<!-- tldr:end -->

A small Lua module ("PoseDriver") that plays a weapon rig's KeyframeSequences by writing `Motor6D.Transform` every frame, built in one production game so that halos, crowns, jaws, folding blades and spinning discs on held weapons animate in **live servers**, not just in Studio. It predates the general player ([[Lua Keyframe Player]]) and shares its measured Animator model, with a few deliberate differences. Rig structure: [[Weapon Design Rig Builder]].

## Why it exists

The weapons' effect modules originally registered their clips with `KeyframeSequenceProvider:RegisterKeyframeSequence` and played them on the rig's Animator. Those temporary ids loaded in Studio; in the published game the halos, crowns, jaws and discs stood still, and older weapons whose specials were driven by keyframe markers never fired them. Nothing errored. PoseDriver reads the clip's Poses itself, so the same motion plays everywhere. Full story: [[Case Study - Abilities That Only Worked in Studio]].

**A published id still wins.** If the rig has a non-empty `<Clip>Id` attribute (`IdleId`, `SpecialId`, or a kit's per-clip id), that clip plays through the rig's real Animator instead. Rule: **publish all of a rig's clips together, or none.** With some clips on the Animator and some on PoseDriver, two writers drive the same motors and the result depends on frame order.

## Usage

```lua
local PoseDriver = require(ReplicatedStorage.WeaponFX.PoseDriver)

-- root: the weapon Model (Motor6D joints + an Animations folder of KeyframeSequences)
local idle = PoseDriver.Load(weapon, "Idle")                         -- by name in weapon.Animations
local special = PoseDriver.Load(weapon, "Special", { looped = false, priority = Enum.AnimationPriority.Action })
idle:Play()                                                          -- fade 0.1 by default
special:GetMarkerReachedSignal("Burst"):Connect(function(value) spawnBurst(value) end)

local function onSpecial()
	special:Play(0.15)                                               -- restarts from 0 if already playing
	special.Stopped:Once(function() idle:AdjustWeight(1, 0.2) end)
end
```

`Load(root, clip, opts)` accepts a KeyframeSequence or a name in `root.Animations`. Options: `name` (for the `<name>Id` attribute lookup), `looped`, `priority`. Defaults come from the sequence (Loop, Priority), like `Animator:LoadAnimation`. It returns `nil` if the clip cannot be found, and warns (once) if parsing fails.

The track mirrors the AnimationTrack members effect modules use: `Play(fade = 0.1, weight = 1, speed = 1)`, `Stop(fade = 0.1)`, `AdjustSpeed`, `AdjustWeight(weight, fade)`, `GetMarkerReachedSignal(name)`, `GetTimeOfKeyframe(name)`, `Destroy`; fields `Looped`, `Priority`, `Speed`, `Length`, `TimePosition`, `IsPlaying`, `WeightCurrent`, `WeightTarget`, `Name`; signals `Stopped`, `Ended`, `DidLoop`, `KeyframeReached` (with `Connect`, `Once`, `Wait`).

## Joint binding: Part0 and Part1 names

Each Pose is bound to a motor by the key `parentPoseName .. "\0" .. poseName`, compared against `Part0.Name .. "\0" .. Part1.Name` of every Motor6D under the rig. Consequences:

- The weight-0 root Pose of a weapon clip must be named after the motors' `Part0` (the `Handle`), and each hinge Pose after its moving part. That is why the builders name the root pose `Handle`.
- **Chained hinges** (a segment driven by the previous segment) bind only if their Pose is nested under the parent hinge's Pose, because their Part0 is that segment.
- Two motors driving identically named parts from different parents are told apart, which a name-only binding cannot do.
- A pose with no matching motor is silently ignored, the same as the Animator. Clips can carry keys for parts that were never jointed; nothing moves and nothing complains.

## Clip parsing and the interpolation rule

Parsing walks every keyframe's poses (weighted poses are keys; weight-0 poses are placeholders), records per joint the times, rotation vectors, positions and easing, and collects events (named keyframes and markers). Then, **per joint**:

- if the joint's own keys are **evenly spaced** (all gaps equal within 1 ms): segments interpolate as [[Quaternions|quaternion]] **nlerp**, the second key negated when needed to go the short way;
- otherwise: a **linear blend of rotation vectors**, using the pair of representations (`v` or `-(v/|v|) * (2pi - |v|)`) that lie closest together, the plain pair on a near tie.

This was measured on all 80 animated weapon rigs of the reference game: every segment matched exactly one of the two models, consistently per clip, and the player reproduced `Animator:StepAnimations` within **0.001 rad** on every joint through idle, a special's fade-in, the special and its fade-out. The exceptions were frame-to-frame coin flips the Animator itself makes on exact 180 deg blends.

The general player decides the mode for the whole sequence instead (all keyframes evenly spaced and all keys Linear). Weapon clips are generated with uniform Linear keys or thinned per joint, so both rules agree on them; on arbitrary clips they can differ. See [[Lua Keyframe Player Internals]] and [[Open Questions]].

### Easing

| Pose style | PoseDriver reading |
|---|---|
| Linear | linear |
| Constant (any direction) | **steps to the next pose once past this one** |
| CubicV2 | TweenService Cubic, same direction |
| legacy Cubic, Elastic, Bounce | TweenService style with the direction **reversed** (In plays as Out) |

The curve itself comes from `TweenService:GetValue(alpha, style, direction)`. A segment eases by its first pose's style.

Two differences from the general player, both unresolved in the sources: the general player gives Constant three behaviours by direction (In jumps at once, Out holds, InOut jumps at the midpoint) and treats Elastic / Bounce as not reversed. Weapon clips in the pipeline use neither, so it never mattered in production. If you author weapon clips by hand, avoid Constant, Elastic and Bounce, or test them against the Animator.

## Sampling

For time `t` on a joint: before the first key, the first key; after the last, the last; otherwise binary search for the segment, ease, then nlerp or rotation-vector lerp, and lerp the position. Positions on joints that move are multiplied by the rig's `Model:GetScale()`, so a scaled-up display copy of a weapon animates proportionally.

## Mixing tracks

Per joint, tracks are applied from lowest priority (then oldest play) to highest:

- **The lowest track** that keys the joint is scaled from rest by its weight: rotation vector x w, position x w. At weight 1 it is exactly the sample.
- **Every track above** is mixed in by its weight with a shortest-way quaternion nlerp: `normalise(q_below * (1 - w) + q_this * w)` (sign flipped for the short way); positions lerp by w.
- **A joint no playing track keys returns to identity** (rest) the next frame.

Writes are skipped when the CFrame is unchanged from the last write, which saves property-change traffic on idle rigs.

This is simpler than the general player's priority-normalised mixer (no hand-out of remaining weight per priority level). It matches the Animator for the cases weapons use: one idle, one special fading over it.

## Time, fades and events

- Weights move linearly at `|target - current| / fade`.
- Looped tracks wrap and fire `DidLoop`; events are fired across the wrap.
- **A one-shot reaching its end** fires its remaining events, holds its last pose, fires `Stopped`, and fades out over **0.3 s** (measured); `Ended` fires when the weight reaches 0.
- `Stop(fade)` fades out from the current pose (time stops advancing; the general player keeps time running during a stop fade, measured on character clips).
- Events between the previous and current time fire on `KeyframeReached` (named keyframes) or the marker's signal, immediately during the step, each handler in `task.spawn`.

## Update loop and distance budget

One connection, on `PreSimulation` while the game runs (the Animator applies poses before physics; so does this), or `Heartbeat` in Edit where nothing simulates.

| Rig | Update |
|---|---|
| the local player's own weapon | every frame |
| within 40 studs of the camera | every frame |
| within 120 | every 3rd frame |
| within 300 | every 10th frame |
| beyond 300 | every 30th frame |
| not in Workspace | never |

The rate is re-evaluated every 15 frames, and each rig gets a random phase (0-29) so rigs on the same rate spread across frames. `dt` is the real elapsed time since the rig's last update (clamped to 1 s), so slow-updating rigs stay in time, just coarser. A rig whose step errors is dropped from the loop with a single warning.

The numbers are tighter than the general player's (60 / 150 / 300 studs) because weapons are small: at 120 studs a 9-stud weapon is a few pixels, and a 10 Hz update is invisible.

## Caching: every held weapon is a clone

Each player's held weapon is a clone of the stored rig, so a naive cache per KeyframeSequence instance would re-parse the same clip for every player. Clips are cached twice:

- per instance (a weak-keyed table), and
- **by content**: `FXModule attribute | clip name | keyframe count | last keyframe time`. All clones of a weapon share one parsed clip.

## Baked stubs

Weapon-part clips were later baked to Pose-less stubs to cut instances in replicated storage ([[Baked Clip Stubs and Archiving]]). PoseDriver reads a stub's `KSB` attribute by decoding it with the general player's buffer decoder ([[Clip Buffer Format]]), then maps the general easing codes back to its own reading:

| Code | PoseDriver easing |
|---|---|
| 0 | linear |
| 1, 2, 3 (Constant In / Out / InOut) | step to the next pose |
| 4 / 5 / 6 | TweenService Cubic In / Out / InOut |
| 7 / 8 / 9 | TweenService Elastic Out / In / InOut |
| 10 / 11 / 12 | TweenService Bounce Out / In / InOut |

The baker writes the buffer **from PoseDriver's own reading of the original**: joints keyed `Part0 \0 Part1`, each joint's own nlerp / rotation-vector choice stored in the buffer's per-joint flag, its easing as codes. So a stub plays exactly as the original did under PoseDriver, whatever the Animator would have done. Verified: 368 stubs within 0.04 deg of their originals, end to end on real rigs worst 0.049-0.056 deg. One kit's four clips stayed unbaked (0.28-0.31 deg from position quantisation on big moves).

## Studio test hooks

`Motor6D.Transform` written from a script does not move parts in Edit mode by itself, because nothing steps joints there. Test like this:

```lua
PoseDriver.SetManual(rig, true)                 -- take the rig off the shared loop
local tr = PoseDriver.Load(rig, "Idle")
tr:Play(0)
PoseDriver.Step(rig, 0)                         -- apply frame 0
PoseDriver.Step(rig, 1 / 30)                    -- advance 1/30 s and apply
```

`PoseDriver.Rig(root)` exposes the internal rig state, and the parse and sample functions are exported for tools (the stub baker uses them). A switch `USE_ANIMATOR_IN_STUDIO = true` makes Studio play through the Animator with registered ids instead, for A/B comparison.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Root pose not named after Part0 | nothing moves | name the weight-0 root pose `Handle` (the motors' Part0) |
| Chained hinge pose not nested | that segment never moves | nest poses like the joint tree |
| FX module spins a motor that a clip also keys | the spin flickers or wins/loses by frame | one owner per motor: clip or code |
| Some clips published, some not | jitter, joints snapping between two poses | publish all or none |
| Keys exactly 180 deg apart | the part spins the "wrong" way sometimes | keys well under 180 deg apart |
| Testing in Edit without `Step` | "the rig doesn't animate" | `SetManual` + `Step` |
| Requiring the module from the command bar after editing it | old behaviour | clone-require ([[Studio Tooling Architecture]]) |

## See also

[[Weapon Design Rig Builder]], [[Pipeline - New Animated Weapon]], [[Lua Keyframe Player]], [[Lua Keyframe Player Internals]], [[Custom Rigs - Weapons and Props]], [[Procedural Weapon Motion]], [[Baked Clip Stubs and Archiving]], [[How the Animator Really Behaves]]

## Connected notes
<!-- auto-links:start -->
[[KeyframeSequence Keyframe and Pose Reference]] · [[Keyframes, Easing and Interpolation]] · [[Snippets - Lua Keyframe Player Core]] · [[Authoring Clips in Code]] · [[Easing]] · Interpolation Easing and Curves Math · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Animation Data from Blender to Roblox]] · [[Snippets - Building and Sampling Clips]] · [[Engine Gotchas]] · [[Animation Glossary]] · [[AnimationTrack Reference]] · [[Animation Editor Workflow]] · [[Animation Editor Advanced]] · [[Publishing Animations]]
<!-- related:end -->
