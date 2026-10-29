---
tags: [procedural, ik, ikcontrol, reference, api, type/reference, area/animation, level/advanced, api/IKControl, area/procedural, api/SmoothTime, api/Motor6D]
---
# IKControl Reference

<!-- tldr:start -->
> [!tldr] TL;DR
> - Nothing happens: one of Type / EndEffector / Target / ChainRoot unset, or not under... -> check `GetChainCount() > 0`
> - Whole character slides or tilts: `ChainRoot` set to the HumanoidRootPart or LowerTorso -> start the chain at the limb
> - Limb pops on start and stop: toggling `Enabled` -> fade `Weight`
>
> Cost: TL;DR ~120 tok · whole note ~3.9k tok. Read more: ## Properties · ## Recipes · ## Common mistakes
<!-- tldr:end -->

`IKControl` is Roblox's built-in runtime IK component. You point it at a chain (`ChainRoot` to `EndEffector`) and a `Target`, and the engine poses the chain every frame on top of the animation. No maths on your side. This note lists every member as the official API reference documents it (checked against create.roblox.com), explains how it interacts with the Animator, and gives recipes, limits and the cases where you should write your own solver instead.

Where the docs are silent, this note says "undocumented" or "unverified" rather than guessing.

## Where it lives

- It must be a **child of a `Humanoid` or `AnimationController` that has an `Animator`** (API reference).
- It needs four properties set to do anything: `Type`, `EndEffector`, `Target`, `ChainRoot`.
- It **overrides the animation for all the parts between `ChainRoot` and `EndEffector`** (API reference wording). Everything outside the chain keeps animating normally.

## Properties

| Property | Type | Default | What it does (from the API reference) | Notes |
|---|---|---|---|---|
| `Enabled` | boolean | `true` | Turns the control on or off. | The way to *stop* it. |
| `Type` | `Enum.IKControlType` | not stated | Behaviour: Transform, Position, Rotation or LookAt. | See the enum table below. |
| `ChainRoot` | Instance | not stated | The first part of the chain the control may move. `LeftUpperArm` with `EndEffector = LeftHand` moves three parts. | Docs warn: do not use the character's actual root; it gives unrealistic results. |
| `EndEffector` | Instance | not stated | The last part, the one that moves toward the Target. May be a BasePart with a Motor6D child, a Motor6D, a Bone, or an Attachment. | An Attachment lets you pick a point on the part (a palm, a sole). |
| `Target` | Instance | not stated | Any instance with a world position; it represents a CFrame the EndEffector should reach. Re-read every frame, so a moving target is followed. | An Attachment parented to the thing you want to touch is the usual choice. |
| `Offset` | CFrame | identity | An extra CFrame applied on top of the Target. The docs suggest it for animating effects such as typing. | Animate small motions here instead of moving the target object. |
| `EndEffectorOffset` | CFrame | identity | An extra CFrame in the EndEffector's local space. For LookAt it also changes which axis points at the Target. | Use it to say "this point and this axis of the hand". |
| `Pole` | Instance | `nil` | Optional instance (BasePart, Attachment, Bone, Motor6D, anything with a world position) the intermediate parts bend toward. With `nil`, the solver bends elbows and knees automatically for arm and leg chains. | The docs do not say whether it defines a bend plane; treat it as "the elbow points toward this". |
| `Priority` | number | `0` | Solve order when several controls are active. Higher values are resolved later and can override others. | Use it to make a hand solve after the spine solve that moves its shoulder. |
| `SmoothTime` | number (seconds) | `0.05` | Approximate time for the EndEffector to reach the Target, using a critically damped spring. `0` disables smoothing. | Raise it for lazy tracking (heads), `0` for contact (a hand on a moving handle). |
| `Weight` | number | `1` | Blends the control's effect from 0 (none) to 1 (full). Clamped to [0, 1]. **Setting 0 does not disable it**: use `Enabled`. | The fade knob. The interpolation method is not documented. |

## `Enum.IKControlType`

| Item | Value | Behaviour (API reference) | Typical use |
|---|---|---|---|
| `Transform` | 0 | Full position and rotation: the EndEffector matches the Target's CFrame. | hand gripping a handle with the palm oriented |
| `Position` | 1 | Position only; the EndEffector's rotation is left to the chain. | reaching, foot contact where the ankle is handled separately |
| `Rotation` | 2 | Aligns the EndEffector's rotation to the Target's rotation. | orienting a hand or foot without moving it |
| `LookAt` | 3 | Moves and orients the chain so an axis of the EndEffector (by default its forward axis) points at the Target. | heads, eyes, turrets, a torch beam |

"Forward" is not defined further in the docs. On R15 parts, forward is `-Z` (LookVector). If your EndEffector's forward is a different axis, rotate it with `EndEffectorOffset`.

## Methods

| Method | Returns | What it does |
|---|---|---|
| `GetChainCount()` | number | Segments between ChainRoot and EndEffector; `0` if the chain is invalid. Valid node indices are 1 to count + 1. |
| `GetChainLength()` | number | Total world-space length of the chain in studs: its maximum reach. `0` if invalid. |
| `GetNodeLocalCFrame(index)` | CFrame | A node's CFrame relative to its parent, from the most recent solve. Identity if out of range or unsolved. |
| `GetNodeWorldCFrame(index)` | CFrame | A node's world CFrame from the most recent solve. |
| `GetRawFinalTarget()` | CFrame | The world target after `Weight`, `Offset` and `EndEffectorOffset`, before smoothing. |
| `GetSmoothedFinalTarget()` | CFrame | The target after `SmoothTime` smoothing; equals the raw target when `SmoothTime` is 0. |

No events are listed. Every member is tagged with the Animation capability in the reference.

Practical uses of the methods:

- `GetChainCount() == 0` is your validity check. Run it after setting up; a typo in a part name gives a silent no-op otherwise.
- `GetChainLength()` lets you keep targets inside reach. Clamping the target to about 98% of the length keeps the chain from snapping fully straight (straight chains have no defined bend direction and pop).
- `GetNodeWorldCFrame(i)` lets you draw the solved chain for debugging, or read the solved elbow to place an effect.

## How it combines with animation

- **Override, not additive.** For the parts in the chain, the solved pose replaces the clip's pose, weighted by `Weight`. Outside the chain the clip plays untouched.
- **`Weight` is the blend.** Fade it in and out (tween it, or drive it with a spring) instead of flipping `Enabled`, or the limb pops.
- **`Priority` orders multiple controls.** Example: a spine LookAt (priority 0) then a hand Transform (priority 1). The hand solves after the spine has moved its shoulder.
- **When in the frame it solves is undocumented.** Do not assume that reading `Motor6D.Transform` in `PreSimulation` shows the IK result, or that writing `Transform` on a chain joint survives it. If you need your own layer on the same joints, pick one owner per joint.

## Constraints: making elbows and wrists behave

The official IK guide adds physics constraints to keep the solve natural. Its requirements:

- The constraint's `Attachment0`/`Attachment1` attach to the same parts as the joint's `Part0`/`Part1`.
- The relative positions of the attachments equal the joint's `C0`/`C1` positions.
- The constraint and the [[IKControl]] share the same parent Model.

Its examples, for the left arm:

| Joint | Constraint | Setup from the guide |
|---|---|---|
| Elbow | `HingeConstraint` named `LeftElbowConstraint` under `LeftLowerArm` | `Attachment0` under `LeftUpperArm` at the `LeftElbowRigAttachment`, rotated so its PrimaryAxis is the elbow's rotation axis; `Attachment1` under `LeftLowerArm` at its elbow attachment with the same orientation. A red arrow in the visualisation means the orientation violates the hinge. |
| Wrist | `BallSocketConstraint` named `LeftWristConstraint` under `LeftHand` | `Attachment0` under `LeftLowerArm` at the wrist, PrimaryAxis toward the fingertips; `Attachment1` under `LeftHand` with the same orientation; `LimitsEnabled = true`, `UpperAngle = 80` ("approximately how much the wrist should be able to bend"). Rotate `Attachment0` to aim the cone; the green cone shows the range. |

The guide notes that even with the elbow constraint, IKControl can still produce unrealistic wrists, which is why the wrist constraint exists. `BallSocketConstraint` also has `TwistLimitsEnabled`, `TwistLowerAngle` and `TwistUpperAngle` (twist measured between the two attachments' Y axes) if you need to limit forearm roll; the IK guide does not use them.

Compare with the reference project's numbers for a comfortable wrist: flex 70, deviation 30, twist 85 degrees (its offline bake clamps), flagged by QA at 75 / 40 / 95. A single 80-degree cone treats flex and deviation as equal, which real wrists are not (deviation is much smaller). See [[Elbow Poles Swivel and Joint Limits]].

## Recipes

### Off-hand on a two-handed hilt

```lua
--!strict
-- Left hand grips the weapon handle wherever the right-hand clip puts it.
local function attachOffHand(character: Model, handle: BasePart): IKControl
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local grip = Instance.new("Attachment")
	grip.Name = "OffHandGrip"
	-- 1.15 studs down the hilt from the main grip, rolled 180 degrees about the blade (a two-handed grip)
	grip.CFrame = CFrame.new(0, 0, 1.15) * CFrame.Angles(0, 0, math.pi)
	grip.Parent = handle

	local ik = Instance.new("IKControl")
	ik.Name = "OffHandIK"
	ik.Type = Enum.IKControlType.Transform
	ik.ChainRoot = character:WaitForChild("LeftUpperArm")
	ik.EndEffector = character:WaitForChild("LeftHand")
	ik.Target = grip
	ik.SmoothTime = 0          -- contact: no lag behind the handle
	ik.Weight = 0              -- fade in when a two-handed move starts
	ik.Parent = humanoid
	if ik:GetChainCount() == 0 then
		warn("OffHandIK: invalid chain")
	end
	return ik
end
```

The 1.15-stud gap and the 180-degree roll are the reference project's two-handed grip values for its 1.6x-scale characters; measure your own weapon. The handle's axis convention (blade along `-Z` of the hand in that project) decides which axis the offset runs along.

### Fading weight without pops

```lua
local TweenService = game:GetService("TweenService")
local function fadeIK(ik: IKControl, to: number, time: number)
	-- Weight is a number property, so TweenService can drive it
	TweenService:Create(ik, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Weight = to }):Play()
end
-- fadeIK(ik, 1, 0.12) when the grip starts; fadeIK(ik, 0, 0.15) before it ends
```

### Feet on uneven ground

One IKControl per leg: `ChainRoot = LeftUpperLeg`, `EndEffector = LeftFoot` (or an Attachment at the sole), `Type = Position` (or `Transform` to also align the foot to the slope), `Target` = an Attachment you move each frame to the raycast hit under the foot, `Pole` = an Attachment in front of the knee. You still have to lower the pelvis yourself when one foot is in a hole, because the chain cannot stretch. See [[Foot Placement and Ground IK]].

### Head look-at

`Type = LookAt`, `EndEffector = Head`, `ChainRoot` = `Head` for the neck alone or a torso part to spread the turn (test both; spreading is not documented behaviour), `SmoothTime` 0.1 to 0.2 for a natural lag. LookAt has no angle limits of its own: clamp the target position yourself (keep it inside a cone in front of the torso) or the head turns 180 degrees. See [[Look-At Aim and Head Tracking]].

## Performance and replication (undocumented)

The API reference and the IK guide say nothing about solve cost or replication. Rules of thumb that hold for any per-frame solver:

- Disable (`Enabled = false`) controls on rigs far from the camera or off-screen; `Weight = 0` is documented as *not* disabling it, so assume it still costs.
- Fewer, shorter chains are cheaper. Do not put a whole-body chain where two arm chains will do.
- An IKControl is an ordinary instance: created on the server, it replicates like any other. How its solve behaves on other clients for a client-owned character is not documented. The safe pattern is the same as for all procedural motion: replicate the *inputs* (which target, which weight) and create or drive the controls on each client.

## Known issues and unknowns

- A community bug report on the DevForum describes IKControl jitter on spawn when the default Animate script or its animation ids are replaced, worse with constraints. It was marked a duplicate. Treat as a known risk with custom animators; test your spawn.
- Compatibility with `AnimationConstraint` joints (Avatar Joint Upgrade rigs) is not addressed in the IKControl docs. The `EndEffector` description mentions Motor6D and Bone. Test on your actual avatar type before committing.
- Whether IKControl solves in Edit mode, and so whether it can be baked with `Animator:StepAnimations`, is undocumented.

## When to write your own solver instead

| Need | Why IKControl falls short | Use |
|---|---|---|
| Elbow must stay an exact hinge with a chosen swivel per motion type | `Pole` is one point; no per-frame swivel search | [[Two-Bone IK Math]], [[Elbow Poles Swivel and Joint Limits]] |
| Continuity across a whole clip (no flips) | solves frame by frame | Viterbi over candidates (offline) |
| A blade *direction* matters as much as the grip point | Transform type matches one CFrame; no trade-off between direction and reach | cost-based solve |
| Offline baking into clips | solve timing and Edit behaviour undocumented | your own FK/IK in Lua or Python |
| Tail, tentacle or spine with per-joint limits and wave motion | arbitrary chains are possible, but limits need constraints per joint | [[Multi-Bone IK - FABRIK and CCD]] |
| You need the solved angles as data (for QA, replication, sound) | only `GetNode*CFrame` after the fact | your own solver |

The reference project chose its own solvers for all of these reasons. For a door handle, a ledge grab, a steering wheel, a head that glances at players, IKControl is the fastest correct answer.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Nothing happens | one of Type / EndEffector / Target / ChainRoot unset, or not under a Humanoid/AnimationController with an Animator | check `GetChainCount() > 0` |
| Whole character slides or tilts | `ChainRoot` set to the HumanoidRootPart or LowerTorso | start the chain at the limb |
| Limb pops on start and stop | toggling `Enabled` | fade `Weight` |
| Control still costs time at weight 0 | `Weight = 0` does not disable | set `Enabled = false` when idle |
| Head twists all the way round | LookAt has no limits | clamp the target into a cone |
| Elbow bends backwards or the wrist folds | no constraints | add the hinge and wrist constraints from the guide |
| Hand lags behind a fast-moving handle | default `SmoothTime` 0.05 | set `SmoothTime = 0` for contact |
| Arm snaps straight and jitters | target beyond `GetChainLength()` | clamp the target to about 0.98 of the length |

Related: [[Inverse Kinematics]], [[Two-Bone IK Math]], [[Foot Placement and Ground IK]], [[Look-At Aim and Head Tracking]], [[Snippets - IK]], [[Open Questions]].

## Connected notes
<!-- auto-links:start -->
[[Troubleshooting Table]] · [[Arm Baker Internals]] · [[Animation Quality Standard]] · [[Animation Glossary]] · [[Official Docs - Characters and Animation]] · Voxel Characters - Proportions Joints and Rigging · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Ragdolls and Physics-Based Animation]] · [[Procedural Animation]] · [[R15 Rig Anatomy and Attachments]] · [[Retargeting Animations Between Rigs]] · [[Rigs and Joints]] · [[Motor6D Math and CFrame Composition]] · [[R15 Run Cycle Key Poses]] · [[Arm QA Metrics Reference]]
<!-- related:end -->
