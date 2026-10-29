---
tags: [retargeting, rigging, math, keyframesequence, clips]
---
# Retargeting Animations Between Rigs

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Copying clips between rigs with different roll -> Conjugate by the frame difference
> - Avoid: Delta retarget across different rest poses -> Absolute retarget, or pose-match the rests
> - Avoid: Root translation unscaled -> Scale by height or hip-height ratio
>
> Cost: TL;DR ~110 tok · whole note ~3.5k tok. Read more: ## 3. Different joint frames: conjugation · ## 5. Proportions: translations, contacts and speed · ## Common mistakes
<!-- tldr:end -->

Retargeting is making a clip authored on one rig play correctly on another. In Roblox the engine does the easy part automatically (it matches joints by name), which hides the hard parts: different joint frames, different rest poses, different proportions, different hierarchies. This note explains what a clip actually stores, which differences break it, the maths to fix each, and the practical routes one production game used (shared family clips, root-translation rescaling, offline arm re-solving).

## 1. What a clip stores, and how the Animator matches it

- A KeyframeSequence stores, per keyframe, a tree of `Pose` objects named after the **child** of each joint (the Motor6D's `Part1`, or the Bone's name). Each `Pose.CFrame` is that joint's `Transform`: an offset **relative to the joint's rest frame**.
- At playback the Animator walks the rig's joints and looks up a pose with the matching name in the matching place in the tree. Keys for joints the rig does not have are **inert**; joints no clip keys stay at rest (or show lower-priority tracks). The reference project relied on both: its weapon rig player matched the same way, and a family clip played on members missing some optional bones.
- The top-level pose (the root part, or a Root bone at the top) is never applied (measured), so root motion lives on the first child.

Consequence: a clip "transfers" whenever names line up. Whether it **looks right** depends on whether the same `Transform` means the same motion on both rigs.

## 2. The four kinds of rig difference

| Difference | Example | Does a raw copy work? | Fix |
|---|---|---|---|
| Proportions only (same names, same joint frames, same rest) | R15 blocky body vs Rthro body; family members of different heights | Rotations: yes. Translations: wrong size. Contacts: drift | Scale translations; IK or re-solve for contacts |
| Joint frame orientation (roll) | Same skeleton exported with different bone roll; a Motor6D rig vs a Bone rig of the same creature | No: rotations happen about different axes | Conjugate each joint's rotation (section 3) |
| Rest pose | A-pose rig playing T-pose clips | Partly: motion is offset by the rest difference | Absolute retarget (section 4) |
| Names or hierarchy | Mocap or third-party skeleton to R15 | No: nothing matches | Name map; collapse or split chains (section 6) |

A fifth difference, topology (biped clip on a quadruped), is not retargeting. Re-author, or drive the target procedurally.

## 3. Different joint frames: conjugation

If a target joint's frame is the source joint's frame rotated by `R` (expressed in the source joint frame) and both rigs share the same rest pose, the same physical motion is:

```
T_target = R^-1 * T_source * R
```

This rotates the "axis" of the source rotation into the target frame while keeping the angle. Translations in the pose transform the same way: `p_target = R^-1 * p_source`.

Where you meet it:

- **R15 to R15** of any body type: all RigAttachments have zero rotation (measured), so `R` is the identity and clips copy as they are. That is the main reason R15 clips are universal.
- **Rigs built with world- or body-aligned joint frames** (the reference project's weapon, pet and boss rigs): `R` is the identity between any two of them.
- **Bone rigs exported with a different roll convention**: `R` is the roll difference per bone.
- **The project's importer axis fix** is a conjugation of the same family: imported enemy clips had been written as `Rest^-1 * (C * A * C)` with `C` a 180 degree turn about Y, and the correction for non-root joints was `P' = Rest^-1 * C * Rest * P * C`, with `P' = P * C` for the root. The transform is its own inverse. See [[Enemy Import Axis Fix]].

A Luau helper that conjugates and renames poses in a copy of a clip:

```lua
--!strict
type JointMap = { [string]: { name: string?, R: CFrame? } }   -- source pose name -> target name, frame change

local function retargetFrames(src: KeyframeSequence, map: JointMap, rootPose: string, posScale: number): KeyframeSequence
	local out = src:Clone()
	for _, d in out:GetDescendants() do
		if d:IsA("Pose") then
			local m = map[d.Name]
			local R = (m and m.R) or CFrame.identity
			local cf = d.CFrame
			local rot = R:Inverse() * (cf - cf.Position) * R      -- T' = R^-1 T R (rotation part)
			local p = R:VectorToObjectSpace(cf.Position)           -- p' = R^-1 p
			if d.Name == rootPose then
				p *= posScale                                      -- root travel scales with size
			end
			d.CFrame = CFrame.new(p) * rot
			if m and m.name then
				d.Name = m.name
			end
		end
	end
	return out
end
```

This handles renames and frame changes for one-to-one joint maps. It does not collapse or split chains (section 6), and it keeps easing and markers untouched.

## 4. Different rest poses: delta versus absolute

Two philosophies:

| Mode | Keeps | Result when rest poses differ |
|---|---|---|
| **Delta** (conjugation only) | Each joint's motion relative to its own rest | Rest difference carried into every frame: an A-pose rig playing T-pose clips holds its arms 40 degrees lower than authored |
| **Absolute** | Each part's orientation relative to its parent | Poses match the source visually; requires that the parts' own axes mean the same on both rigs |

Absolute retarget for Motor6D-style joints, from `Part1 = Part0 * C0 * T * C1^-1`. Requiring the child's orientation relative to the parent to match:

```
C0t * Tt * C1t^-1 = C0s * Ts * C1s^-1
Tt = C0t^-1 * C0s * Ts * C1s^-1 * C1t        (rotation parts)
```

For Bones (`child world = parent world * Bone.CFrame * Transform`), let `Rp` and `Rc` be the frame differences of the parent and child bones (target frame = source frame times `R`, measured in a shared pose). Then:

```
Tt = Bt^-1 * Rp^-1 * Bs * Ts * Rc
```

where `Bs` and `Bt` are the rest `Bone.CFrame`s. When the rests agree (`Bt = Rp^-1 * Bs * Rc`) this reduces to the conjugation `Rc^-1 * Ts * Rc` of section 3; when they differ, the extra terms carry the rest correction.

The practical route that avoids per-joint algebra: **pose the target into the source's rest pose once** (in Blender or by code), record each joint's offset from its own rest in that pose, and pre-multiply it into every frame. That is what "match rest pose" buttons in DCC retargeters do.

When to choose which:

- Delta for **families authored together** (same rest by construction) and for **additive-style** layers (a recoil, a breathing layer) that should add to whatever the rig is doing.
- Absolute for **imported clips from other sources** (mocap, store packs) and whenever rest poses differ.

The 2026 Roblox clip importer exposes a "Rest Pose Source" choice ("Imported Rig", "Imported Rig (Zeroed Rotations)", "Animation Editor Rig"), which is this same decision made at import time. See [[3D Importer Settings Reference]].

## 5. Proportions: translations, contacts and speed

Rotations transfer between proportions; positions do not.

### Root translation

The reference project's family clips stored rotations only, plus root/hip translation authored at the family's reference height, and an offline Blender step re-baked root translation per enemy: `translation x (enemyHeight / referenceHeight)`. For locomotion, scaling by **hip height** (leg length) rather than total height keeps the bob and stride consistent with the legs; for jumps and lunges, total height is fine (rule of thumb).

Know how the target is scaled:

| Scaling method | Animator behaviour (measured) | Retarget implication |
|---|---|---|
| `Model:ScaleTo(k)` | Root translations multiplied by `Model:GetScale()` | Author at scale 1; the engine scales |
| Humanoid body scale values | Root translations applied literally | Bake translations at game scale (the project's 1.6x players needed root offsets x 1.6, or crouches hovered) |

### Non-root translations

Avoid them on limbs. The reference project wrote arm poses rotation-only because any translation over 0.05 studs on an arm joint "reads as a detached shoulder". If a source clip has limb translations (common in mocap), drop them or convert them into rotations of the parent.

### Contacts

Rotation-only transfer preserves angles, not positions. On a target with longer arms, two hands on one hilt separate; on shorter legs, planted feet slide. Fixes, from cheapest:

1. Accept small errors (silhouette matters more than exact contact at game distance).
2. **Runtime IK** to pin hands or feet ([[IKControl Reference]], [[Foot Placement and Ground IK]]).
3. **Offline re-solve per proportion**: the reference project's arm baker kept every body, leg and timing key and re-solved only the six arm joints for the 1.6x game rig, so hands met the hilt and blades cleared the body on the real proportions ([[Pipeline - Arm IK Baking and QA]]).

### Playback speed

A bigger creature should take longer strides at a lower rate. The project slowed scaled enemies' walk clips to `0.85 / sqrt(scale)` (pendulum scaling). For players, locomotion clips carried a `GroundSpeed` and the playback rate was `speed / GroundSpeed`, so stride matched velocity. Measured: when definitions' move speeds were 2-4 times faster than authored strides, forcing the rate up "would play frantic"; fix strides at the source instead. See [[Locomotion Systems]].

## 6. Different names and hierarchies

### Name maps

Write an explicit table; never guess by substring. A typical third-party humanoid (for example a Mixamo-style skeleton) to R15:

| Source | R15 target | Notes |
|---|---|---|
| Hips | LowerTorso | Root translation goes here |
| Spine, Spine1, Spine2 | UpperTorso | **Collapse**: compose the three rotations |
| Neck, Head | Head | Collapse; the neck pivot is lower than R15's Neck pivot, so expect a slight head shift |
| LeftShoulder (clavicle) | folded into LeftUpperArm | R15 has no clavicle; compose |
| LeftArm, LeftForeArm, LeftHand | LeftUpperArm, LeftLowerArm, LeftHand | |
| LeftUpLeg, LeftLeg, LeftFoot (+ ToeBase) | LeftUpperLeg, LeftLowerLeg, LeftFoot | Toe folded into foot |
| Finger chains | (none) or advanced R15 digit bones | Dropped on standard R15 |

### Collapsing a chain

When several source joints map to one target joint, the target rotation is the **product** of the source rotations in parent-to-child order, expressed in the target joint frame. It is exact only if the collapsed joints' pivots coincide; otherwise the child segment shifts slightly (visible as a head bob change when collapsing neck plus head).

### Splitting a chain

When one source joint maps to several target joints (R15 `UpperTorso` onto a three-bone spine), distribute the rotation: each bone takes a fraction of the angle about the same axis (for example 0.4 / 0.35 / 0.25 from the bottom up; rule of thumb). Equal thirds look stiff; bottom-heavy distribution reads as a natural spine bend.

### Extra target joints

Tails, capes, ears and extra spine bones on the target receive nothing. Drive them with secondary motion in code ([[Idle Breathing and Secondary Motion]]) or author a layer for them.

## 7. Where to retarget: Blender or Studio?

| In Blender (offline) | In Studio (Luau, on KeyframeSequences) |
|---|---|
| Full rig evaluation, constraints, IK to fix contacts | Fast for renames, conjugations and root scaling |
| Bake once per target, export data | Runs on existing clips without a round trip |
| The project's family root re-bake ran here | Good for fixing imported clips in place |

Either way, **keep the source clip** and generate targets from it. The reference project kept before-dumps of every clip (JSON on disk) so any bake could be rolled back.

## 8. Verify

1. Play source and target side by side at the same time (two rigs, one script stepping both; in Edit use `Animator:StepAnimations`).
2. Compare silhouettes at key poses and marker frames (hits must still line up).
3. Check contacts (hands on weapons, feet on the ground) and root travel distance.
4. Check the end pose matches the target's idle (the project's QA required the last frame within 75 degrees of idle per arm joint and the first within 90, because the idle takes over the instant a one-shot ends).

## Common mistakes

| Mistake | On screen | Fix |
|---|---|---|
| Copying clips between rigs with different roll | Limbs swing sideways or twist | Conjugate by the frame difference |
| Delta retarget across different rest poses | Arms permanently too low or too high | Absolute retarget, or pose-match the rests |
| Root translation unscaled | Small creature leaps across the room; big one shuffles | Scale by height or hip-height ratio |
| Limb translations from mocap kept | Shoulders detach, elbows stretch | Rotation-only for limbs |
| Substring name matching | `LeftArm` matches `LeftArmTwist` | Explicit map |
| Collapsed spine without composing rotations | Torso bends at a third of the source angle | Multiply the chain's rotations |
| Ignoring the scaling method | Crouch depth wrong only on players | Know GetScale vs body-scale behaviour |

## See also

[[Rigs and Joints]] · [[Motor6D Math and CFrame Composition]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Blender Armature and Bone Roll Conventions]] · [[Creature Rig Conventions]] · [[Enemy Import Axis Fix]] · [[Scale and Animation]] · [[Animation Data from Blender to Roblox]] · [[Animation Capture and Mocap]] · [[Pipeline - Arm IK Baking and QA]]

## Connected notes
<!-- auto-links:start -->
[[R15 Rig Anatomy and Attachments]] · [[Rigging in Blender]] · [[Bones and Skinned Meshes]] · [[AI Animation and Motion from Video]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Animation Start Here]]
<!-- auto-links:end -->
