---
tags: [rigging, r15, humanoid, attachments, reference]
---
# R15 Rig Anatomy and Attachments

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Code looks for Motor6D only -> Accept AnimationConstraint too
> - Avoid: IK uses part centres or vertical arm length -> Use RigAttachment positions (slanted upper arm)
> - Avoid: Root motion keyed on HumanoidRootPart -> Key LowerTorso
>
> Read more (15 KB note): ## 2. The joints · ## 3. Accessory and grip attachments · ## Common mistakes
<!-- tldr:end -->

The R15 rig is the contract that the default Animate script, emotes, layered clothing, accessories, the Animation Editor and most community tooling assume. Knowing its exact parts, joints and attachment offsets lets you build IK that hits the real pivots, write procedural code that works on any body, import custom bodies that animate, and diagnose "why is my arm offset" problems in minutes.

All positions below were **measured in Studio (October 2026)** on a rig made by `Players:CreateHumanoidModelFromDescriptionAsync` from a default `HumanoidDescription` (blocky body, default scales). Other bodies (Rthro, custom bundles) have different sizes and offsets but the same names, hierarchy and conventions.

## 1. The parts

15 body parts plus the `HumanoidRootPart`. Positions are part centres relative to the HumanoidRootPart (studs; +X right, +Y up, -Z forward).

| Part | Size (X, Y, Z) | Centre |
|---|---|---|
| HumanoidRootPart | 2.000, 2.000, 1.000 | 0, 0, 0 |
| Head | 1.159, 1.182, 1.161 | 0, 1.586, 0 |
| UpperTorso | 1.943, 1.698, 1.004 | 0, 0.200, 0 |
| LowerTorso | 1.991, 0.401, 1.004 | 0, -0.800, 0 |
| Left/RightUpperArm | 1.001, 1.242, 1.002 | -/+1.500, 0.369, 0 |
| Left/RightLowerArm | 1.001, 1.118, 1.002 | -/+1.500, -0.224, 0 |
| Left/RightHand | 0.984, 0.316, 1.028 | -/+1.500, -0.850, 0 |
| Left/RightUpperLeg | 0.993, 1.363, 0.973 | -/+0.500, -1.421, 0 |
| Left/RightLowerLeg | 0.993, 1.301, 0.973 | -/+0.500, -2.201, 0 |
| Left/RightFoot | 1.009, 0.312, 1.001 | -/+0.500, -2.850, 0 |

Derived: the head top is about 2.18 studs above the HumanoidRootPart centre and the soles about 3.01 below, so the default character is roughly **5.2 studs** tall. `Humanoid.HipHeight` was 2.19. (The reference project's players were scaled 1.6x through body scales, about 9 studs tall, which made its hip about 3.5 studs above ground: 2.19 x 1.6.)

Every body part carries an `OriginalSize` Vector3Value (the unscaled size), used by the scaling system.

## 2. The joints

15 joints. Each lives **inside its child part** (Part1) and is named for the anatomical joint. The joint frame is defined by a pair of identically named `*RigAttachment`s, one in each part. Offsets are attachment positions in that part's space; **every RigAttachment has zero rotation** (measured).

| Joint | Parent part (Part0) | RigAttachment | Offset in Part0 | Offset in Part1 |
|---|---|---|---|---|
| Root | HumanoidRootPart | RootRigAttachment | 0, -1.000, 0 | LowerTorso: 0, -0.200, 0 |
| Waist | LowerTorso | WaistRigAttachment | 0, 0.200, 0 | UpperTorso: 0, -0.849, 0 |
| Neck | UpperTorso | NeckRigAttachment | 0, 0.849, 0 | Head: 0, -0.576, 0 |
| LeftShoulder | UpperTorso | LeftShoulderRigAttachment | -0.972, 0.598, 0 | LeftUpperArm: 0.501, 0.419, 0 |
| RightShoulder | UpperTorso | RightShoulderRigAttachment | 0.972, 0.598, 0 | RightUpperArm: -0.501, 0.419, 0 |
| LeftElbow | LeftUpperArm | LeftElbowRigAttachment | 0, -0.355, 0 | LeftLowerArm: 0, 0.275, 0 |
| RightElbow | RightUpperArm | RightElbowRigAttachment | 0, -0.355, 0 | RightLowerArm: 0, 0.275, 0 |
| LeftWrist | LeftLowerArm | LeftWristRigAttachment | 0, -0.532, 0 | LeftHand: 0, 0.132, 0 |
| RightWrist | RightLowerArm | RightWristRigAttachment | 0, -0.532, 0 | RightHand: 0, 0.132, 0 |
| LeftHip | LowerTorso | LeftHipRigAttachment | -0.500, -0.200, 0 | LeftUpperLeg: 0, 0.471, 0 |
| RightHip | LowerTorso | RightHipRigAttachment | 0.500, -0.200, 0 | RightUpperLeg: 0, 0.471, 0 |
| LeftKnee | LeftUpperLeg | LeftKneeRigAttachment | 0, -0.449, 0 | LeftLowerLeg: 0, 0.413, 0 |
| RightKnee | RightUpperLeg | RightKneeRigAttachment | 0, -0.449, 0 | RightLowerLeg: 0, 0.413, 0 |
| LeftAnkle | LeftLowerLeg | LeftAnkleRigAttachment | 0, -0.596, 0 | LeftFoot: 0, 0.106, 0 |
| RightAnkle | RightLowerLeg | RightAnkleRigAttachment | 0, -0.596, 0 | RightFoot: 0, 0.106, 0 |

### What these numbers mean for animation

- **Joint names are not pose names.** A KeyframeSequence names Poses after the **part** (`RightUpperArm`), and nests them like the parts: `HumanoidRootPart > LowerTorso > UpperTorso > RightUpperArm > RightLowerArm > RightHand`. See [[KeyframeSequence Keyframe and Pose Reference]].
- **The shoulder pivot is at the inner top edge of the upper arm**, 0.501 studs in from the arm's centre line. The "bone" from shoulder pivot to elbow pivot is therefore slanted: length `sqrt(0.501^2 + 0.774^2) = 0.922` studs, not the vertical 0.774. Elbow to wrist is 0.807. The reference project's IK used exactly these slanted bones (1.48 and 1.29 studs at 1.6x scale) and noted that ignoring the slant misplaces the hand by tenths of a stud. See [[Two-Bone IK Math]].
- Hip to knee is 0.920, knee to ankle 1.009, ankle to sole about 0.26. Legs are short relative to typical game characters: at walking speeds the project found Jog and Run need flight phases and Walk keeps double support.
- **Zero-rotation RigAttachments** make every joint frame aligned with the body at rest: X right, Y up, Z back. So `CFrame.Angles(rx, 0, 0)` on the RightShoulder raises the arm forward for positive `rx`, and a positive `rx` on the Waist leans the torso back. The project's convention: "rx > 0 leans back, chin up; ry > 0 turns left". See [[Blender Armature and Bone Roll Conventions]].
- The **Root** joint's top-level Pose (the HumanoidRootPart pose) is never applied by the Animator (measured). Root motion goes on `LowerTorso`.

### Motor6D or AnimationConstraint?

The rig generated in Studio in October 2026 had **15 `AnimationConstraint` joints and no Motor6Ds**. Roblox's reference describes AnimationConstraint as the default joint type for R15 avatar rigs when the Avatar Joint Upgrade is enabled (the default for new experiences), while Motor6D remains supported. The reference project's live characters used AnimationConstraints too. Consequences:

- Code that does `part:FindFirstChildOfClass("Motor6D")` finds nothing on modern characters. Accept both: `FindFirstChildWhichIsA("AnimationConstraint")`, falling back to Motor6D.
- An AnimationConstraint's frame comes from `Attachment0` / `Attachment1` (the RigAttachments), not `C0` / `C1` properties. The Animator writes its `Transform` just like a Motor6D's.
- `Humanoid:BuildRigFromAttachments()` builds joints from matching RigAttachment pairs. The project found that an Edit-mode rig "without Motor6Ds" (it had AnimationConstraints) made code that expected Motor6Ds fail quietly; posing from the RigAttachment pairs directly worked on both.

See [[AnimationConstraint and Physically Simulated Characters]] and [[Rigs and Joints]].

### FK from attachments (works for both joint types)

```lua
--!strict
-- World CFrame of every body part from a pose table, using RigAttachment pairs.
-- pose[partName] = CFrame (the joint Transform), missing = identity.
type Joint = { parent: BasePart, child: BasePart, a0: Attachment, a1: Attachment }

local function jointsOf(character: Model): { Joint }
	local list: { Joint } = {}
	for _, part in character:GetChildren() do
		if not part:IsA("BasePart") then continue end
		local c = part:FindFirstChildWhichIsA("AnimationConstraint")
		local m = part:FindFirstChildWhichIsA("Motor6D")
		if c and c.Attachment0 and c.Attachment1 then
			local a0, a1 = c.Attachment0 :: Attachment, c.Attachment1 :: Attachment
			table.insert(list, { parent = a0.Parent :: BasePart, child = a1.Parent :: BasePart, a0 = a0, a1 = a1 })
		elseif m and m.Part0 and m.Part1 then
			-- Motor6D: build equivalent attachments from C0/C1 (not parented, maths only)
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.CFrame, a1.CFrame = m.C0, m.C1
			table.insert(list, { parent = m.Part0, child = m.Part1, a0 = a0, a1 = a1 })
		end
	end
	return list
end

local function fk(root: BasePart, joints: { Joint }, pose: { [string]: CFrame }): { [BasePart]: CFrame }
	local cf: { [BasePart]: CFrame } = { [root] = root.CFrame }
	local pending = table.clone(joints)
	while #pending > 0 do                         -- parents before children
		local progressed = false
		for i = #pending, 1, -1 do
			local j = pending[i]
			local parentCF = cf[j.parent]
			if parentCF then
				local t = pose[j.child.Name] or CFrame.identity
				cf[j.child] = parentCF * j.a0.CFrame * t * j.a1.CFrame:Inverse()
				table.remove(pending, i)
				progressed = true
			end
		end
		if not progressed then break end          -- disconnected part: stop
	end
	return cf
end
```

This is the formula the project's QA and authoring tools used everywhere: `Part1 = Part0 * att0.CFrame * Transform * att1.CFrame^-1` (for a Motor6D, `Part0 * C0 * Transform * C1^-1`). See [[Motor6D Math and CFrame Composition]].

## 3. Accessory and grip attachments

Attachments without "Rig" in the name are sockets for accessories, tools and effects (measured offsets, part space):

| Part | Attachment | Offset | Notes |
|---|---|---|---|
| HumanoidRootPart | RootAttachment | 0, 0, 0 | |
| Head | HatAttachment, HairAttachment | 0, 0.590, 0 | top of head |
| Head | FaceFrontAttachment | 0, 0, -0.581 | front of face |
| Head | FaceCenterAttachment | 0, -0.094, 0 | |
| UpperTorso | NeckAttachment | 0, 0.849, 0 | same point as NeckRigAttachment |
| UpperTorso | BodyFrontAttachment / BodyBackAttachment | 0, -0.212, -/+0.502 | chest front and back |
| UpperTorso | LeftCollarAttachment / RightCollarAttachment | -/+0.972, 0.849, 0 | |
| LowerTorso | WaistFrontAttachment / WaistBackAttachment | 0, -0.200, -/+0.500 | belts, skirts |
| LowerTorso | WaistCenterAttachment | 0, -0.200, 0 | |
| Left/RightUpperArm | Left/RightShoulderAttachment | 0, 0.621, 0 | top of the arm (pauldrons) |
| Left/RightHand | Left/RightGripAttachment | 0, -0.158, 0, **rotated -90 degrees about X** | tools: the turn points its LookVector down the hand's -Y (along the arm), so a tool held in the default arm-out pose points forward |
| Left/RightFoot | Left/RightFootAttachment | -/+0.018, -0.160, -0.050 | |

`RightGripAttachment` is what the Tool system's `RightGrip` weld uses as `C0` (with `Tool.Grip` as `C1`). Its rotation is the only non-zero one on the default rig. Grip-relative conventions (blade along hand -Z) are in [[Custom Rigs - Weapons and Props]].

Accessories attach by matching names: an accessory's Handle containing `HatAttachment` is welded to the head's `HatAttachment`. Layered clothing uses the same names to position, then cages to fit. See [[Accessories and Armor That Follow Animation]] and [[Layered Clothing Cages and Animation]].

## 4. Scale values

The Humanoid holds NumberValues that rescale the body: `BodyHeightScale`, `BodyWidthScale`, `BodyDepthScale`, `HeadScale`, `BodyProportionScale`, `BodyTypeScale` (measured defaults from a default description: 1, 1, 1, 1, 1 and 0.3). They resize parts and move attachments; they do **not** change `Model:GetScale()`.

That distinction matters for clips. The reference project measured that the Animator scales clip **root translations** by `Model:GetScale()` but applies them literally on body-scaled characters (GetScale = 1). Its 1.6x players were scaled through body scales, so clips had to store root offsets already multiplied by 1.6, or crouches left the feet hovering. Rotations are unaffected by either method. See [[Scale and Animation]].

## 5. The avatar body specification (for imported bodies)

Roblox's character body specification (Creator Hub) for custom R15 bodies:

- **15 mesh objects** named `<Part>_Geo` (`UpperTorso_Geo`, `LeftHand_Geo`, `Head_Geo`, ...), limbs capped to be watertight when separated.
- Skeleton: `Root > HumanoidRootNode > LowerTorso > UpperTorso > Head`, arms under UpperTorso, legs under LowerTorso. LowerTorso and Root at 0, 0, 0. Only the upper arms may carry rotation (to achieve an A or T rest pose).
- **Facing +Z, up +Y** in the exported file; freeze transforms; I, A or T pose.
- Attachments come from meshes with an `_Att` suffix (`Hat_Att`, `Neck_Att`, `RightGrip_Att`, `Root_Att` at 0, 0, 0, ...), for caged bodies; grips oriented perpendicular to the lower arm bone (90, 0, 0 in I-pose).
- Skinning: at most 4 influences, no root influences, symmetric.
- **Advanced R15:** up to 37 optional extra bones (for example `UpperTorso > Spine > Chest > Head > HeadBase`, clavicles `Chest > RightClavicle > RightUpperArm`, and finger and toe chains). Add a `HumanoidRigDescription` after import (required for Marketplace sale and proper animation) and a `DigitsRigDescription` per hand with optional bones. Bones are detected by exact name.
- Triangle budgets: head 4,000; torso 1,750; each limb 1,248; 10,742 total.
- Bounding boxes per part and total (total between 1.0 x 4.0 x 0.5 and 8.0 x 10.0 x 4.0 studs).
- Body scale standards: Normal, Slender, Classic (importer Rig Scale: Rthro, Rthro Narrow, Default).

Clips authored on the blocky rig play on these bodies because joint names and frame conventions are shared; proportions change where hands and feet land. That is why contact-heavy animation (hands on a hilt, feet planted) benefits from runtime IK or per-proportion baking. See [[Retargeting Animations Between Rigs]].

## 6. Validation snippet

```lua
--!strict
local R15_PARTS = {
	"HumanoidRootPart", "Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local function checkR15(character: Model): { string }
	local problems = {}
	for _, name in R15_PARTS do
		local part = character:FindFirstChild(name)
		if not part then
			table.insert(problems, "missing part " .. name)
		elseif name ~= "HumanoidRootPart" then
			local joint = part:FindFirstChildWhichIsA("AnimationConstraint") or part:FindFirstChildWhichIsA("Motor6D")
			if not joint then
				table.insert(problems, "no joint in " .. name)
			end
		end
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		table.insert(problems, "no Humanoid")
	elseif hum.RigType ~= Enum.HumanoidRigType.R15 then
		table.insert(problems, "RigType is not R15")
	elseif not hum:FindFirstChildOfClass("Animator") then
		table.insert(problems, "no Animator under Humanoid")
	end
	return problems
end
```

## Common mistakes

| Mistake | On screen | Fix |
|---|---|---|
| Code looks for Motor6D only | Procedural head turn, IK or ragdoll does nothing on modern characters | Accept AnimationConstraint too |
| IK uses part centres or vertical arm length | Hands miss targets by tenths of a stud; elbows bend wrong | Use RigAttachment positions (slanted upper arm) |
| Root motion keyed on HumanoidRootPart | Lunge or hop does nothing | Key LowerTorso |
| Crouch authored at scale 1 on 1.6x body-scaled players | Feet hover | Store root offsets at game scale |
| Custom body with renamed parts | Default Animate, emotes and accessories break | Keep R15 names; extra bones only per the advanced spec |
| Adding a Neck bone between UpperTorso and Head | R15 clips no longer drive the head | Keep Head directly under UpperTorso for R15 compatibility |

## See also

[[Rigs and Joints]] · [[Motor6D Math and CFrame Composition]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Custom Characters and StarterCharacter]] · [[Scale and Animation]] · [[Two-Bone IK Math]] · [[Accessories and Armor That Follow Animation]] · [[Facial Animation and Dynamic Heads]] · [[The Default Animate Script]]

## Connected notes
<!-- auto-links:start -->
[[Modeling Characters for R15 and Custom Rigs]] · [[UGC Avatar Items and Accessories]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Rigging in Blender]] · [[Avatar Body Types and Scale in Gameplay]] · [[Skeleton Library]] · [[Animation Start Here]]
<!-- auto-links:end -->
