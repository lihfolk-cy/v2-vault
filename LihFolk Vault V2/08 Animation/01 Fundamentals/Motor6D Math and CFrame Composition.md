---
tags: [fundamentals, math, cframe, motor6d, fk, type/guide, area/animation, level/beginner, api/Part1, area/math, api/Part0, api/Motor6D]
---
# Motor6D Math and CFrame Composition

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Server `C0` writes for aiming. Symptom: high network traffic and laggy aim seen by others.
> - Avoid: Assuming R15 axes on R6 or imported rigs.
> - Avoid: World-space joint math in huge maps. Symptom: limb jitter far from the origin.
>
> Cost: TL;DR ~100 tok · whole note ~4.7k tok. Read more: ## Forward kinematics for a whole rig · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

Every animation system, procedural layer, IK solver and offline tool in Roblox comes down to one equation per joint. If you can read and invert it in your head, you can write look-at code, IK, ragdoll hand-offs, retargeting and QA tools; if you cannot, you will multiply in the wrong order and get limbs that rotate about the wrong pivot or in the wrong space. This note derives the equation for all three joint types, shows how to solve it for what you want, and lists the composition rules and numeric traps.

## The joint equation

### Motor6D
```
Part1.CFrame = Part0.CFrame * C0 * Transform * C1:Inverse()
```
Read it right to left as "where is Part1":
- `C1:Inverse()` takes you from the joint frame to Part1's own frame (C1 is the joint's frame expressed in Part1's space).
- `Transform` is the animated rotation and offset, applied **in the joint frame**, about the joint's origin (the pivot).
- `C0` places the joint frame in Part0's space.
- `Part0.CFrame` places all of it in the world.

With `Transform = identity` the rig is in its **rest pose** (the bind pose the C0/C1 values describe). An animation Pose's CFrame **is** the Transform: identity in a Pose means "rest", not "zero rotation in world space".

### AnimationConstraint
Same equation with attachments instead of C0/C1:
```
Part1.CFrame = Part0.CFrame * Attachment0.CFrame * Transform * Attachment1.CFrame:Inverse()
-- Part0 = Attachment0.Parent, Part1 = Attachment1.Parent
```
The docs describe the deprecated read-only `C0/C1/Part0/Part1` on [[AnimationConstraint]] as aliases of exactly these. With `IsKinematic = true` the parts follow this exactly; with `false` they are pulled toward it by forces (see [[AnimationConstraint and Physically Simulated Characters]]).

### Bone
```
bone.TransformedWorldCFrame = parentFrame * bone.CFrame * bone.Transform
-- parentFrame = the parent Bone's TransformedWorldCFrame, or the parent part's CFrame for a top bone
-- bone.TransformedCFrame = bone.CFrame * bone.Transform (local, hidden property)
```
A Bone is an Attachment: its `CFrame` is the rest pose relative to the parent, `Transform` is the animated offset on top. There is no C1: the bone's own frame is the joint frame. `WorldCFrame` (inherited from Attachment) returns the **un-animated** rest position; use `TransformedWorldCFrame` for where the bone is now.

## Forward kinematics for a whole rig

Process joints parent-first. This is the formula every tool in one production pipeline used, written for both Motor6D and AnimationConstraint:

```lua
--!strict
type Joint = { part0: BasePart, part1: BasePart, a0: CFrame, a1: CFrame } -- a0/a1 = C0/C1 or attachment CFrames

-- Computes world CFrames for every part from per-joint Transforms (by Part1 name).
-- 'joints' must be ordered parents first. 'root' is the HumanoidRootPart CFrame.
local function fk(joints: {Joint}, transforms: {[string]: CFrame}, rootPart: BasePart, root: CFrame): {[BasePart]: CFrame}
	local world: {[BasePart]: CFrame} = { [rootPart] = root }
	for _, j in joints do
		local parentCF = world[j.part0]
		if parentCF then
			local t = transforms[j.part1.Name] or CFrame.identity
			world[j.part1] = parentCF * j.a0 * t * j.a1:Inverse()
		end
	end
	return world
end

-- Builds the ordered joint list from a model (Motor6D or AnimationConstraint).
local function jointList(model: Model): {Joint}
	local list: {Joint} = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			table.insert(list, { part0 = d.Part0, part1 = d.Part1, a0 = d.C0, a1 = d.C1 })
		elseif d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			local p0, p1 = d.Attachment0.Parent, d.Attachment1.Parent
			if p0 and p0:IsA("BasePart") and p1 and p1:IsA("BasePart") then
				table.insert(list, { part0 = p0, part1 = p1, a0 = d.Attachment0.CFrame, a1 = d.Attachment1.CFrame })
			end
		end
	end
	-- Sort parents first by depth from the root (count hops through part0 links).
	local parentOf: {[BasePart]: BasePart} = {}
	for _, j in list do parentOf[j.part1] = j.part0 end
	local function depth(p: BasePart): number
		local n, cur = 0, parentOf[p]
		while cur do n += 1; cur = parentOf[cur] end
		return n
	end
	table.sort(list, function(a, b) return depth(a.part1) < depth(b.part1) end)
	return list
end
```

Uses: Edit-mode previews (pose anchored copies with these CFrames, because Edit has no physics to apply `Transform`), offline QA (blade-through-body checks, foot clearance), filmstrips, and predicting where a hand will be at a marker time on the server without any physics.

## Solving the equation for what you want

### "I want Part1 at this world CFrame"
```
Transform = (Part0.CFrame * C0):Inverse() * desiredPart1 * C1
```
This is the core of IK write-back and of "snap this hand to this handle". If the result has translation on a joint that should only rotate (an elbow), your target was not reachable by rotation alone: take only the rotation (`t.Rotation`) and accept the miss, or solve properly with IK (see [[Two-Bone IK Math]]).

### "I want Part1 to point its -Z at a target, about the joint pivot"
```lua
-- Rest-relative look: the joint frame with no animation is P0 * C0.
local function aimTransform(part0CF: CFrame, c0: CFrame, target: Vector3): CFrame
	local jointWorld = part0CF * c0
	local dir = jointWorld:PointToObjectSpace(target) -- target in the joint's own frame
	if dir.Magnitude < 1e-6 then return CFrame.identity end
	dir = dir.Unit
	local yaw = math.atan2(-dir.X, -dir.Z) -- forward is -Z: +yaw turns toward -X (left)
	local pitch = math.asin(math.clamp(dir.Y, -1, 1)) -- +pitch about X looks up
	return CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end
```
This replaces the animation on that joint. To **layer** a look on top of an animated head, measure the target in the animated joint frame and append (see the next section). Clamp yaw and pitch: for a neck, about 70 degrees yaw and 40 pitch reads natural (rule of thumb); beyond that, turn the waist too. More in [[Look-At Aim and Head Tracking]].

### "I want to rotate Part1 by a world-space rotation R, about the joint pivot, on top of the animation"
The world rotation must be expressed in the joint frame (a conjugation):
```
J      = Part0.CFrame * C0 * Transform          -- animated joint frame in world
localR = J.Rotation:Inverse() * R * J.Rotation   -- R expressed in the joint frame
Transform' = Transform * localR
```
Using `R` directly in `Transform * R` rotates about the **joint's local axes**, which only matches world axes when the joint frame happens to be aligned with the world.

## Composition order: what `a * b` means

`A * B` applies B **in A's frame**. In joint terms:

| Write | Meaning | Use for |
|---|---|---|
| `Transform * extra` | `extra` happens in the joint's own frame **after** the animated rotation (child side) | Additive tweaks that should follow the animated limb: wrist roll, recoil kick along the arm, a breathing scale on top of a pose |
| `extra * Transform` | `extra` happens in the joint frame **before** the animation (parent side); the animated pose is rotated as a whole | Re-aiming a whole animated limb: tilting the whole swing up toward a target, lean on a spine joint |
| `C0 * extra` (changing C0) | Moves the rest pose; the animation then plays relative to the new rest | Permanent re-posing (grip offsets, a custom character's T-pose fix). Not per-frame animation |

Rule of thumb: procedural layers in `PreSimulation` almost always want `Transform * extra` (local, follows the animation) for joint-level effects and `extra * Transform` for re-aiming. Write it down per system; mixing the two in one codebase is a classic source of "it works when facing north" bugs.

## Euler angles: the conventions that matter

| Constructor | Order applied | Matrix |
|---|---|---|
| `CFrame.Angles(rx, ry, rz)` = `CFrame.fromEulerAnglesXYZ` | Z first, then Y, then X (about fixed axes), i.e. R = Rx * Ry * Rz | Common in clip tools |
| `CFrame.fromOrientation(rx, ry, rz)` = `fromEulerAnglesYXZ` | R = Ry * Rx * Rz | What `Orientation` in the Properties panel uses |
| `cf:ToEulerAnglesXYZ()` / `ToOrientation()` | Inverses of the above | Extracting angles is ambiguous near 90 degrees on the middle axis (gimbal lock) |

Pose tables in code-built clips are usually `{rx, ry, rz [, px, py, pz]}` turned into `CFrame.new(px, py, pz) * CFrame.Angles(rx, ry, rz)`. Note the translation is applied in the joint frame **before** rotation in that expression, i.e. the offset is not rotated by the joint's own rotation; that matches how the Animator lerps offsets independently of rotation.

**Axis meaning on R15** (rest frames aligned with the parts): +X right, +Y up, -Z forward. A positive X rotation turns -Z toward +Y (and +Y toward +Z), so on most R15 joints `rx > 0` tips an upward part (torso, head) back and swings a hanging part (arm, leg) forward. `ry > 0` turns the child toward the character's left (-Z toward -X). `rz > 0` rolls it counter-clockwise seen from behind (+X toward +Y). One team's body-angle convention, matching this: "rx > 0 leans back / chin up; ry > 0 turns left". Verify on your rig before trusting signs: a custom rig with rotated attachments changes every sign.

## Rotation vectors, axis-angle and angles between poses

The Animator's own interpolation works on rotation vectors (axis times angle), so tools need these helpers:

```lua
--!strict
-- Rotation vector (axis * angle, radians) of a CFrame's rotation. Identity -> zero vector.
local function logR(cf: CFrame): Vector3
	local axis, angle = cf:ToAxisAngle()
	if angle ~= angle or angle < 1e-12 then return Vector3.zero end -- NaN guard for identity
	return axis * angle
end

-- Inverse: rotation vector -> CFrame
local function expR(v: Vector3): CFrame
	local a = v.Magnitude
	if a < 1e-12 then return CFrame.identity end
	return CFrame.fromAxisAngle(v / a, a)
end

-- Smallest angle between two rotations, in radians (0..pi)
local function angleBetween(a: CFrame, b: CFrame): number
	local _, x = (a:Inverse() * b):ToAxisAngle()
	x = math.abs(x)
	if x > math.pi then x = 2 * math.pi - x end
	return x
end
```

Every rotation has two rotation vectors: `v` and `v - 2*pi*axis` (the same rotation the other way round). Blending picks the pair closest together; at exactly 180 degrees both are equally close, which is why exact-180 keys are ambiguous (see [[How the Animator Really Behaves]]).

## Mirroring a pose left to right

For a rig whose left and right joint frames are mirror images across the character's YZ plane (true for the standard R15 rig attachments), the mirrored Transform for the opposite joint is:

```lua
-- Mirror a joint Transform across the character's YZ plane (left <-> right).
local function mirror(t: CFrame): CFrame
	local axis, angle = t:ToAxisAngle()
	if angle ~= angle or math.abs(angle) < 1e-9 then
		return CFrame.new(-t.X, t.Y, t.Z) -- no rotation: only the offset mirrors
	end
	local s = math.sin(angle / 2)
	local qx, qy, qz, qw = axis.X * s, axis.Y * s, axis.Z * s, math.cos(angle / 2)
	-- Reflection across the YZ plane: position x -> -x; quaternion (qx, qy, qz, qw) -> (qx, -qy, -qz, qw)
	return CFrame.new(-t.X, t.Y, t.Z, qx, -qy, -qz, qw)
end
```
Apply it to `RightUpperArm`'s Transform to get `LeftUpperArm`'s. If your rig's frames are not mirror images (imported custom rigs often are not), compute the mirror in world space instead and convert back with the solve formula above.

## Numeric traps

- **Re-orthonormalisation.** A `Transform` you write reads back slightly different (re-orthonormalised). Never compare with `==`; use `FuzzyEq(other, 1e-4)`. One Lua player used exactly that tolerance to detect "someone else wrote this joint this frame".
- **Accumulating errors.** `t = t * smallDelta` every frame for minutes drifts off orthonormal and can shear. Rebuild from angles or call `CFrame.fromMatrix`/`Orthonormalize()` periodically, or better, never accumulate: recompute from the source each frame.
- **Reading part CFrames in PreSimulation.** The Animator has written this frame's `Transform`s, but per the docs they are applied to parts in a batched job **after** PreSimulation, just before physics. So `Part.CFrame` read in PreSimulation is last frame's pose. For a look-at that is a harmless one-frame lag; for an IK foot lock it can cause a visible one-frame slip. Compute the chain yourself with FK from the root if you need this frame's values.
- **Scale.** Translations in `Transform` are in studs of the rig as built. On a model scaled with `Model:ScaleTo` the Animator scales clip offsets by `GetScale()`; your own procedural offsets are not scaled for you. See [[Scale and Animation]].
- **Translation on rotation-only joints.** A tiny translation in an elbow Transform (from a [[slerp]] of CFrames with different positions, or float noise) shows as a gap at the joint at high scale. Strip it: `t.Rotation`.

## Worked example: hand to a ledge with layering

A climbing system wants the right hand on a ledge point while the climb clip plays. Steps, all in PreSimulation after the Animator:
1. FK from the HumanoidRootPart with the animated Transforms to get the shoulder's world frame this frame (not `Part.CFrame`, which is last frame).
2. Two-bone IK in that shoulder frame to get the upper-arm and forearm world rotations.
3. Convert each to a Transform with `Transform = (parentWorld * C0):Inverse() * childWorld * C1`, keeping rotation only.
4. Blend with the animated Transform by an IK weight (rotation-vector lerp or `Lerp` for small differences) so the hand eases onto the ledge over about 0.15 s.
5. Write the Transforms. They are gone next frame, so repeat every frame while climbing.

## See also
[[Rigs and Joints]] · [[Bones and Skinned Meshes]] · [[Frame Order and RunService Timing]] · [[Two-Bone IK Math]] · [[Look-At Aim and Head Tracking]] · [[Snippets - Procedural Motion]] · [[How the Animator Really Behaves]]

## Nuances and edge cases

1. **What replicates and what does not.** `C0` and `C1` are properties; a server write replicates to every client (on Motor6Ds; on AnimationConstraints they are read-only aliases). `Transform` written from a script does not replicate. That makes `C0` tempting for "everyone should see this aim", but per-frame server `C0` writes cost bandwidth per joint per player and arrive late. Replicate the input (an aim angle) and let each client compute `Transform`.
2. **R6 vs R15.** R6 has six parts and joints named differently (`Right Shoulder` under the Torso, with a space). R6 shoulder rest frames are rotated compared with R15, so the axis table above (+X right, +Y up, -Z forward) does not hold for R6 joints. Code that supports both should look up joints by role, not name, and test axis conventions on each.
3. **Custom rigs from Blender.** Imported rigs may have joint rest frames that are not aligned with the parts (bone roll, export axis). "Positive X tips the head back" is only true when rest frames are part-aligned. Inspect `C0` on each imported joint before writing procedural code against it.
4. **Cost at scale.** One CFrame multiply is cheap, but a full-rig FK pass every frame for 50 characters is roughly 50 times 15 joints times several multiplies, plus allocation of new CFrame values. With native code generation enabled (`--!native`), tight math like this runs noticeably faster (Roblox docs describe native codegen as a performance option for compute-heavy scripts; measure your own case). Skip FK on rigs that do not need it this frame.
5. **Float precision far from the origin.** CFrames are 32-bit floats. At positions tens of thousands of studs from the origin, world positions lose sub-millimetre precision and joint math done in world space jitters. Do joint math in local or root space and convert to world once at the end; this matters in very large open worlds.
6. **Mirroring and handedness.** Mirroring a pose flips handedness; done wrong it produces a reflection matrix that is not a valid rotation, and CFrame silently re-orthonormalises it into something else. Always mirror by negating the right components of the rotation (as described above), never by negating a whole axis of the matrix.
7. **Interpolating CFrames with large rotations.** `CFrame:Lerp` interpolates rotation along the shortest arc. For a 270 degree spin it goes the short way, 90 degrees backwards. Split large rotations into steps or use angles directly.

## Common mistakes

1. **Server `C0` writes for aiming.** Symptom: high network traffic and laggy aim seen by others. Fix: replicate aim input; clients write `Transform`.
2. **Assuming R15 axes on R6 or imported rigs.** Symptom: head look-at tilts sideways on one rig type. Fix: verify axes per rig type, store per-joint axis corrections.
3. **World-space joint math in huge maps.** Symptom: limb jitter far from the origin. Fix: compute in root space.
4. **Comparing CFrames with `==`.** Symptom: "has it changed" checks always true. Fix: `FuzzyEq` with a tolerance.
5. **Lerping a spin.** Symptom: wheels or blades reverse direction at high speed. Fix: interpolate angles, not CFrames.
6. **Mixing composition orders in one system.** Symptom: an effect that works on one limb is mirrored or inverted on another. Fix: document per system whether it pre or post multiplies.

## Related decisions

- [[Math Vectors and CFrames]]: the general CFrame primer this note assumes.
- [[Rotations Angles and Quaternions]]: Euler order, [[quaternions]] and why lerping spins fails.
- [[Dot and Cross Products in Gameplay]]: building aim and look rotations from vectors.
- [[Luau Performance and Native Codegen]]: speeding up heavy per-frame CFrame maths.
- [[Replication Rules]]: why `C0` replicates and `Transform` does not.
- [[Modeling Characters for R15 and Custom Rigs]]: where rest frames and joint axes come from.
- [[Infinite and Streamed Worlds]]: precision issues far from the origin.
- [[Cookbook - Math CFrame and Vectors]]: short recipes for common CFrame tasks.

## Connected notes
<!-- auto-links:start -->
[[Blender Armature and Bone Roll Conventions]] · [[Retargeting Animations Between Rigs]] · [[Enemy Import Axis Fix]] · [[Animation Data from Blender to Roblox]] · [[Voxel Characters - Proportions Joints and Rigging]] · Game Math Start Here · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Procedural Animation]] · [[Inverse Kinematics]] · [[Animator Deep Dive]] · [[AI Pitfalls - Physics and Animation]] · [[Snippets - Building and Sampling Clips]] · [[R15 Rig Anatomy and Attachments]] · [[Animation Glossary]] · [[Snippets - IK]] · [[Rigging in Blender]]
<!-- related:end -->
