---
tags: [procedural, ik, arms, legs, math, hub]
---
# Inverse Kinematics

Forward kinematics (FK) answers "given these joint angles, where is the hand?" Inverse kinematics answers the reverse: "where must the shoulder, elbow and wrist turn so the hand lands *here*, facing *that way*?" FK has exactly one answer. IK usually has infinitely many (an arm can reach the same point with the elbow up, down or out), sometimes none (the target is out of reach), and picking the *right* one is where all the craft lives.

This note is the map of the IK topic. The maths and code live in the linked notes.

## The three solver families

| Family | How it works | Strengths | Weaknesses | Note |
|---|---|---|---|---|
| **Analytic** (closed form) | geometry: law of cosines plus a bend plane | exact, constant time, no iteration, deterministic | only for specific chains (2 bones, or 2 bones + a fixed end) | [[Two-Bone IK Math]] |
| **Iterative heuristic** (FABRIK, CCD) | repeat a simple local fix until the end reaches the target | any number of joints, cheap per iteration, easy limits | approximate, can jitter, results depend on start pose and iteration count | [[Multi-Bone IK - FABRIK and CCD]] |
| **Optimisation** (coordinate descent, grid search, gradient) | minimise a cost (reach error + comfort + collisions + continuity) | anything you can score: blade direction, clearance, style | slow, local minima, needs tuning | [[Elbow Poles Swivel and Joint Limits]] |

Plus the engine's own component, `IKControl`, which hides the solver behind properties: [[IKControl Reference]].

Rule of thumb: **use analytic IK for limbs, FABRIK/CCD for long chains, optimisation offline, and IKControl when its constraints and smoothing are enough and you want zero maths.**

## Runtime IK vs baked IK

| | Runtime IK | Baked IK |
|---|---|---|
| Reacts to the world (slopes, moving handles, aim) | yes | no |
| Cost | every frame, every rig | once, offline |
| Can afford search and clearance checks | barely | yes, minutes per clip |
| Output | joint Transforms this frame | a KeyframeSequence (or buffer) |
| Risk | jitter, pops when targets jump | the stored clip must survive the Animator's own interpolation |

The reference project (one live action game) used both, by purpose:

- **Arms holding blades were baked.** An offline solver (nicknamed posebaker) re-solved the six arm joints of several hundred attack clips. Per 60 Hz frame it tried 24 hand rolls x 36 elbow swivels, solved each candidate exactly with analytic two-bone IK on the slanted R15 bones, scored comfort, clearance and blade fidelity, then picked the smoothest path through the whole clip with Viterbi. One move took 40 s to 3 min; the full library took 8-12 CPU hours. No runtime could afford that, and nothing about it needed to react.
- **Legs were analytic at runtime** in its procedural gait and foot-plant layer, and analytic in the offline baker too ("legs use analytic IK on the 1.6x game rig, so planted feet stay put, ankle within about 0.04 studs of the authored spot").
- **Engine IKControl was not used.** The tools report says so explicitly: the clips were baked and the runtime did not need it.

## What makes IK look right (the short version)

These come from baking a few hundred clips and scoring them. Each has a dedicated section elsewhere.

1. **Pick the elbow and knee direction on purpose.** A pole (or swivel angle) chosen per motion type: down-out by default, out-forward overhead, down-forward across the body, down for two-handed. The wrong pole gives chicken wings and elbows through the ribs. See [[Elbow Poles Swivel and Joint Limits]].
2. **Never let the hinge invert.** Elbows and knees are hinges: solve the bend as a single rotation about the hinge axis, clamped to a range (the reference project used 0.06 to 2.55 rad, about 3 to 146 degrees). A general 3-DOF solve will happily bend an elbow sideways. See [[Two-Bone IK Math]].
3. **Respect the wrist.** A wrist can flex about 70, deviate about 30 and twist about 85 degrees comfortably (the project's bake clamps). "A wrist cannot aim a blade": lining the blade up with the forearm needs about 90 degrees of deviation, so the *arm* must aim it.
4. **Continuity beats the per-frame optimum.** A solver that picks the best pose each frame independently flickers between equally good solutions. Choose the sequence with the least total change (Viterbi / dynamic programming), or at least start each frame from the previous one.
5. **Clamp, then re-check.** After clamping joints to limits, the end effector misses. Measure the miss and decide whether that is acceptable (the project accepted "IK hand misses up to about 1.3 studs in a few poses").
6. **Check against the real Animator.** A baked clip plays through Roblox's interpolation, not yours. The project measured the Animator blending rotation vectors (not slerp) between uneven keys; a slerp model was up to 178 degrees off on big turns. Every bake was played on the real Animator and accepted under about 3 degrees. See [[How the Animator Really Behaves]].

## Choosing what to solve

IK is a tool for constraints. Before writing a solver, write down the constraint in words:

| Constraint | Solver | Notes |
|---|---|---|
| "Hand on this handle, palm facing it" | two-bone + wrist | Transform-type target |
| "Both hands on the hilt" | two-bone per arm, second hand relative to the blade | the project placed the left hand 1.15 studs below the right along the blade, rolled 180 degrees |
| "Feet on the ground, hips follow" | two-bone per leg + pelvis drop | [[Foot Placement and Ground IK]] |
| "Head looks at the target" | not IK: an aim rotation, clamped and distributed | [[Look-At Aim and Head Tracking]] |
| "Tail curls toward the bait" | FABRIK or CCD | [[Multi-Bone IK - FABRIK and CCD]] |
| "Spine bends so the gun points at the target" | aim distribution over 2-3 joints | [[Look-At Aim and Head Tracking]] |
| "Body leans into a turn" | not IK: a rotation from acceleration | [[Procedural Gait and Footstep Planning]] |

Many "IK problems" are really aim problems. Aim is cheaper, more stable and easier to clamp.

## Coordinate frames (where most IK bugs are)

Every IK solve has three spaces in play:

- **World** (or the HumanoidRootPart's space): where targets come from.
- **The chain root's parent joint frame**, `Part0.CFrame * C0` for the first joint: where the solve happens.
- **Each joint's local frame**: where the answer must be written, as `Transform`.

The conversion back is always the same identity. For a joint with frames `C0` (in Part0) and `C1` (in Part1):

```
Part1.CFrame = Part0.CFrame * C0 * Transform * C1:Inverse()
=> Transform = (Part0.CFrame * C0):Inverse() * desiredPart1CFrame * C1
```

For an `AnimationConstraint`, use the two attachments' CFrames in place of `C0` and `C1`. If you solve in world space, convert at the end with that formula, joint by joint, parents first, using *your solved* parent frame, not the part's current CFrame (which is last frame's pose during `PreSimulation`; see [[Procedural Animation]]).

## One frame of runtime IK, in order

Most runtime IK bugs are ordering bugs. A full-body frame that works:

1. **The Animator steps** (engine). Every joint now holds this frame's clip pose.
2. **`PreSimulation`: FK the animated pose** from the root, through the joint Transforms you are about to modify. Do not read part CFrames (they are last frame's).
3. **Root and pelvis adjustments** first (pelvis drop for ground IK, lean, root recoil), because every limb hangs from them.
4. **Spine and aim** next (waist and chest look-at or aim offset), because the shoulders hang from them.
5. **Limbs** last: legs to their ground targets, arms to their handles, each solved from the *adjusted* parent frames of steps 3-4.
6. **Wrist and ankle** rotation with limits.
7. **Write** every Transform, each blended over the animated value by its layer weight.

`IKControl.Priority` encodes the same idea for engine IK: higher priorities resolve later, so give the spine control a lower priority than the hand control that depends on it.

## Seeing what the solver sees

IK is impossible to debug from the final pose alone. Draw the intermediate geometry: the target, the pole or swivel reference, the solved elbow, the reach sphere.

```lua
--!strict
-- Throwaway debug markers: a small neon ball per named point, reused every frame.
local markers: { [string]: Part } = {}
local function mark(name: string, pos: Vector3, color: Color3)
	local p = markers[name]
	if not p then
		p = Instance.new("Part")
		p.Name = "IKDebug_" .. name
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * 0.3
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.Neon
		p.Parent = workspace
		markers[name] = p
	end
	p.Color = color
	p.CFrame = CFrame.new(pos)
end
-- mark("target", target, Color3.new(1, 0, 0)); mark("pole", pole, Color3.new(0, 0, 1)); mark("elbow", elbow, Color3.new(0, 1, 0))
```

What to look for: the target jumping (a bad input, not a bad solver), the pole passing near the shoulder-target line (expect a flip), the target outside the reach sphere (expect a straight, jittering limb), and the solved elbow on the wrong side of the body (wrong pole or swivel reference). For offline bakes, the reference project rendered **filmstrips** (a row of poses at fixed times with the real held blade) and scored every clip with automatic metrics (arms in the body, pops, wrist range, blade through the body), because a few hundred clips cannot be checked by eye. See [[Arm QA Metrics Reference]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Elbow snaps from down to up between frames | pole direction nearly parallel to the shoulder-target line | fall back to a secondary pole, or blend poles by angle |
| Arm fully straight then "pops" | target beyond reach; `acos` of a value > 1 | clamp the distance to `[abs(a-b)+e, a+b-e]` |
| Hand is exactly on target but the arm looks broken | elbow solved as a ball joint | solve the elbow as a hinge about its own axis |
| IK arm flickers on a stationary target | per-frame greedy choice among equal solutions | continuity cost, previous-frame seed, smoothing |
| Correct in your preview, off in game | you sampled with slerp; the Animator blends rotation vectors | verify on the real Animator |
| Right in Studio, wrong on bigger avatars | bone lengths cached at spawn; body scale lands later | re-read lengths periodically (the project re-read leg geometry every second) |
| Feet IK fights the clip | IK applied before the Animator, or both write the same joint | write after the Animator, with a weight |

## Where to go next

- The engine component: [[IKControl Reference]]
- Derivations and code: [[Two-Bone IK Math]], [[Multi-Bone IK - FABRIK and CCD]]
- Human-looking arms: [[Elbow Poles Swivel and Joint Limits]]
- Ground contact: [[Foot Placement and Ground IK]], [[Procedural Gait and Footstep Planning]]
- Production pipeline: [[Pipeline - Arm IK Baking and QA]], [[Arm Baker Internals]], [[Arm QA Metrics Reference]]
- Copy-paste: [[Snippets - IK]]
- Hub: [[Procedural Animation]]

## Connected notes
<!-- auto-links:start -->
[[Animation Glossary]] · [[Animation Quality Standard]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Links - Inverse kinematics]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[AI Animation and Motion from Video]] · [[Animation Start Here]]
<!-- auto-links:end -->
