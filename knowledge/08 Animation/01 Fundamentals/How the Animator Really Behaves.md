---
tags: [fundamentals, animator, measured, advanced]
---
# How the Animator Really Behaves (measured)

<!-- tldr:start -->
> [!tldr] TL;DR
> - Per joint, only Poses with `Weight > 0` are keys.
> - The top-level Pose of each Keyframe (HumanoidRootPart on characters, the `Root` bone on bone rigs) is never applied.
> - Keys bind by name to joints (Part1 name, or Bone name).
> - CurveAnimation playback against `RotationCurve` / `FloatCurve` sampling.
>
> Cost: TL;DR ~120 tok · whole note ~2.9k tok. Read more: ## How the measurements were made · ## 3. Rotation interpolation
<!-- tldr:end -->

The official docs describe what the Animator's API does, not how it computes a pose. This note collects what one production project **measured** by playing clips on the real Animator (`Animator:StepAnimations` in Edit mode, reading every joint's `Transform`) and fitting models until a Lua re-implementation matched it. That re-implementation then ran the game's entire animation runtime, so these rules were tested on hundreds of shipped clips, not toy cases.

Use this note when you build anything that predicts or reproduces playback: offline samplers, IK bakers, key thinners, QA tools, Lua players, or server-side hit timing from poses. Everything here is labelled measured unless stated. Things that remain unresolved are in [[Open Questions]].

## How the measurements were made

1. Build or load a clip (KeyframeSequence) and register it in Studio, or use a published id.
2. Load it on a cloned, anchored test rig's Animator at `Action4`, `Looped = false`, wait for `Length > 0`.
3. `Play(0)`, then `StepAnimations(1/60)` repeatedly, reading every joint's `Transform` after each step (rotation and offset).
4. Sample the same clip offline with a candidate model at the same times.
5. Compare: max angle between the two rotations per joint, and offset distance. Iterate on the model.

Tolerances that defined "match": 0.03 deg median and within 0.25 deg for clean clips. Results at the end of this note.

Caveats on the method: Edit mode, test dummies built from attachments (the live game used AnimationConstraint joints), and `Workspace.Retargeting` at whatever the place had at the time. Retargeting adapts joint transforms to body proportions, so on unusual avatars live playback may not match these numbers exactly.

## 1. Which poses are keys
- Per joint, only Poses with `Weight > 0` are keys. Weight-0 Poses are placeholders and are skipped entirely when finding a joint's neighbouring keys.
- The **top-level Pose** of each Keyframe (HumanoidRootPart on characters, the `Root` bone on bone rigs) is **never applied**. Only poses under it animate.
- Keys bind by name to joints (Part1 name, or Bone name). Missing joints are ignored silently.

## 2. Easing
- A segment uses the easing of its **first** key.
- Shapes (u = 0..1): `CubicV2` In `u^3`, Out `1-(1-u)^3`, InOut piecewise cubic; legacy `Cubic` **reversed** (In plays as Out and vice versa, InOut unchanged); `Elastic` Penner with period 0.3 (InOut 0.45), **not** reversed; `Bounce` standard, **not** reversed, `BounceInOut` uses BounceIn's shape on both halves; `Constant` In jumps immediately, Out holds, InOut jumps at the midpoint.
- Offsets lerp linearly with the eased alpha.

## 3. Rotation interpolation
- **Quaternion nlerp** (shortest way, normalised linear blend of quaternions) when **all of the sequence's keyframes are evenly spaced** (marker-only keyframes included) **and every key is Linear**. Joint count, rig type and key count do not matter.
- **Otherwise a linear blend of rotation vectors**: each key as `axis * angle` relative to rest; of the two representations of each key (`v` and `v - 2*pi*axis`), the pair closest together is lerped.
- An eased segment blends rotation vectors even in an evenly spaced sequence.
- After the last key, an nlerp-mode joint holds the key as stored; a rotation-vector joint holds the paired vector it used for the last segment. A rotation-vector joint ending on a key of **exactly 180 degrees** holds it as `-axis * pi` (the other way round). That only matters when a weight below 1 scales the held rotation.

Two sources in the project phrased the nlerp condition differently: one said "when a joint's own keys are evenly spaced", the later and more specific measurement said "when the whole sequence's keyframes are evenly spaced and all keys are Linear". The second is what the runtime used; both agree that unevenly keyed clips use rotation vectors.

### The model in Luau
```lua
--!strict
local TWO_PI = 2 * math.pi

local function logR(cf: CFrame): Vector3 -- rotation vector of a CFrame
	local axis, angle = cf:ToAxisAngle()
	if angle ~= angle then return Vector3.zero end
	return axis * angle
end

local function flipR(v: Vector3): Vector3 -- the same rotation the other way round
	local a = v.Magnitude
	if a < 1e-12 then return v end
	return -(v / a) * (TWO_PI - a)
end

-- Of each key's two representations, pick the pair closest together.
local function pairOf(a: Vector3, b: Vector3): (Vector3, Vector3)
	local fa, fb = flipR(a), flipR(b)
	local best, pa, pb = (a - b).Magnitude, a, b
	local d = (fa - b).Magnitude
	if d < best - 1e-5 then best, pa, pb = d, fa, b end
	d = (a - fb).Magnitude
	if d < best - 1e-5 then best, pa, pb = d, a, fb end
	d = (fa - fb).Magnitude
	if d < best - 1e-5 then pa, pb = fa, fb end
	return pa, pb
end

-- Rotation-vector interpolation between two key rotations at eased alpha a.
local function rotvecLerp(r0: CFrame, r1: CFrame, a: number): CFrame
	local va, vb = pairOf(logR(r0), logR(r1))
	local v = va:Lerp(vb, a)
	local m = v.Magnitude
	if m < 1e-12 then return CFrame.identity end
	return CFrame.fromAxisAngle(v / m, m)
end
```

### How big the difference is
| Comparison | Max error |
|---|---|
| Rotation-vector model vs Animator, 15 fresh clips | 0.24 deg |
| Slerp model vs Animator, same clips | up to 178 deg (a shoulder; others at 146, 154, 175) |
| Off-hand shoulder going overhead, slerp vs Animator | 9 to 12 deg mid-segment |
| Rotation-vector model vs Animator, every combat clip (several hundred) | median 0.03 deg, 99th percentile 2 to 4 deg (the tail is segments near 180 deg) |

## 4. Exactly 180 degrees
When neighbouring keys are 180 degrees apart, both directions are equally short and the Animator "coin-flips" the path. In a 348-clip enemy parity run, the only failures were clips with exact-180 keys (347/348 within 0.04 deg). Avoid them in authored clips and in tool output: nudge to 179 degrees or add a mid key.

## 5. Fades, ends and time
- `Play` restarts at time 0.
- Fades are linear in weight.
- `Stop(fade)`: the track's time **keeps running** during the fade-out.
- A non-looped track reaching its end **holds its last pose** and fades out over **0.3 s**, regardless of the fade it was started with. On a bare rig joints then return to rest; in game, to whatever plays underneath (usually idle).
- Track time is **float32**: `t = f32(t + f32(dt * speed))`. Matching this matters if you want to end a clip on the same frame as the Animator.

## 6. Layer weights
- Weight is handed out from the **highest priority down**, starting with 1 remaining.
- A priority whose weights `S` fit in what is left keeps them; otherwise each track gets `w * rem / min(S, 1)` and nothing is left below.
- All contributions form one weighted quaternion sum per joint.
- If the total is below 1 (and nothing else writes the joint), the result's rotation vector and offset are scaled by the total: the joint moves toward rest.
- Offsets use the same distribution with each track's weight capped at 1.
- `Core` ranks lowest despite its enum value 1000.

Details and worked examples: [[Playback, Priorities and Blending]].

## 7. Scale
- Clip **translation offsets** are multiplied by `Model:GetScale()` (applied to joints that actually have offsets; the Lua model applied it to every animated offset). The docs confirm the factor is applied to joint offsets of animations played under a scaled model.
- Characters scaled through **Humanoid body scale values** report `GetScale() == 1`, so their clip offsets are applied literally. A clip for a body-scaled 1.6x avatar must store its root offsets already multiplied by 1.6, or crouches leave the feet hovering. See [[Scale and Animation]].

## 8. Edit mode and tooling behaviour
- `StepAnimations` needs `dt > 0`, a loaded clip (`Length > 0`) and is plugin/command-bar only.
- Edit has no physics; `Transform` writes do not move parts. Read `Transform`s and compute part CFrames by FK.
- ViewportFrame rigs cannot be stepped in Edit.
- A KeyframeSequenceProvider-registered clip that has not loaded plays nothing; one QA run reported a 117 degree "error" that was just a fresh, unloaded clip.
- `Players:CreateHumanoidModelFromDescription` in Edit returned a rig without Motor6Ds; build test rigs from rig attachments.

## 9. Frame placement
The Animator evaluates after `RunService.PreAnimation` and before `PreSimulation`; the resulting `Transform`s are applied to parts in a batched job just before physics (docs). A Lua player that wants to layer on top of the real Animator therefore steps in `PreSimulation`, treats any joint whose `Transform` differs from its own last write (`FuzzyEq` 1e-4) as freshly written by the Animator this frame, and uses that as the base under its own tracks. See [[Frame Order and RunService Timing]].

## Parity results of the full re-implementation

| Test | Result |
|---|---|
| 10 R15 clips | within 0.084 deg |
| 60 enemy clips (20 kits, baked) | within 0.056 deg / 0.002 studs, except exact-180 clips |
| 5-track blend | 0.04 deg |
| Markers | 319 / 319 fired at the right times |
| Weapon rig clips after baking to buffers | within 0.04 deg; end-to-end on real rigs 0.049 to 0.056 deg |
| Enemy clips after the import axis fix | 347 / 348 within 0.04 deg |
| Cost | about 22 microseconds per 25-bone rig per frame (39 to 60 on the largest boss) |

The Lua player also distance-LODs: every frame within 60 studs of the camera, every 2nd frame to 150, every 4th to 300, beyond that only time advances (so markers still fire on schedule). See [[Lua Keyframe Player]] and [[Animation LOD]].

## What this means for your own tools

- **One interpolation switch.** Every offline tool (sampler, key fitter, thinner, flip guard, QA model) should dispatch through one function with two modes, rotation vectors (default) and slerp/nlerp. One project exposed it as an environment variable, a setter and a command-line flag so every tool stayed consistent.
- **Verify against the real Animator, not your model.** A model can be self-consistent and wrong. Keep a "play" mode in QA that steps the real Animator and reports the model-vs-Animator gap (one project reported 0.2 to 0.24 deg on healthy clips and treated anything over 3 deg, or 5 on near-180 segments, as a failure).
- **Model the end-of-clip fade.** QA that scores the last frame must know the idle takes over over 0.3 s.
- **Do not trust names.** Pose name typos and missing joints produce no errors; check every Pose binds to a joint.

## Things not measured (treat as unknown)

- CurveAnimation playback against `RotationCurve` / `FloatCurve` sampling.
- Whether the even-spacing test has a tolerance and what it is.
- Exact behaviour with `Workspace.Retargeting` enabled on non-standard proportions.
- Animation graph clips.
- Whether any of this changes under `Workspace.UseFixedSimulation`.

## See also
[[Keyframes, Easing and Interpolation]] · [[Playback, Priorities and Blending]] · [[Animator Deep Dive]] · [[Lua Keyframe Player]] · [[Lua Keyframe Player Internals]] · [[Testing Animations in Studio]] · [[Open Questions]] · [[Engine Gotchas]]

## Connected notes
<!-- auto-links:start -->
[[Authoring Clips in Code]] · [[Weapon Rig Player]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Building and Sampling Clips]] · [[AI Animation and Motion from Video]] · [[Rotations Angles and Quaternions]] · [[Animation Start Here]]
<!-- auto-links:end -->
