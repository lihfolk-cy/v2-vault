---
tags: [pipeline, import, gltf, math, cframe, enemies, debugging, type/guide, area/animation, level/intermediate, api/Animator, area/gameplay]
---
# Enemy Import Axis Fix

<!-- tldr:start -->
> [!tldr] TL;DR
> - body faces backwards but hits land in front
> - body faces backwards and hits land behind
> - root never rises, leaps happen in place
> - forward travel mirrored on one rig
> - one limb occasionally swings the long way
>
> Cost: TL;DR ~100 tok · whole note ~3.6k tok. Read more: ## The code · ## How it was proven · ## Symptoms checklist
<!-- tldr:end -->

A whole roster of imported creatures "attacked from behind": their bodies played turned 180 deg away from the HumanoidRootPart, and all root motion (spawn rises, intro drops, leaps) was missing. Server logic was right (it used the root's LookVector), so enemies dealt damage in front of them while visibly facing away. This note derives the fix from first principles, shows the code, explains how it was proven, and generalises the method so you can debug the next importer convention yourself. Context: [[Pipeline - Importing Animated Enemies]].

> **Scope.** The convention below is a model of what Studio's 3D importer wrote for skinned GLB rigs in one production game (autumn 2026), reconstructed from the data and proven against the source files (343 of 348 clips matched it). Importers change. Treat the method as the durable part and re-verify the convention on your own imports.

## Notation

| Symbol | Meaning |
|---|---|
| `C` | the axis conversion: a rotation of 180 deg about Y, `CFrame.Angles(0, math.pi, 0)`. It is its own inverse: `C * C = I`, so `C^-1 = C`. |
| `R_g` | a bone's rest local transform in the glTF file (relative to its parent bone) |
| `A` | a bone's animated local transform in the glTF file at some time (relative to its parent bone) |
| `Rest` | the Roblox `Bone.CFrame` the importer created (rest, relative to the parent) |
| `P` | a Pose CFrame in the imported KeyframeSequence. When played, it becomes `Bone.Transform`. |

Roblox composes a bone as `world = parentWorld * Bone.CFrame * Bone.Transform`, so the bone's effective local transform while animating is `Rest * P`. (See [[Bones and Skinned Meshes]] and [[Motor6D Math and CFrame Composition]].)

## What the importer did

Three observations, each measured:

1. **The rest hierarchy was converted only at the top.** The `Root` bone (parented to a part) received the axis conversion; every bone below it kept its glTF rest local unchanged: for a non-root bone, `Rest = R_g`; for the root bone, `Rest = C * R_g`. That alone is a correct conversion of the bind pose: turning the root turns the entire subtree, so the model faces the right way at rest (glTF +Z forward becomes Roblox -Z, the LookVector).
2. **Every pose was written as if every bone had been converted:** `P = Rest^-1 * (C * A * C)`. The animated local `A` was conjugated by `C` for every bone, not just the root.
3. **The root's pose was written at the keyframe's top level.** The Animator never applies a keyframe's top-level pose (it is treated as the rig root), so the Root bone's animation, which is where root motion lives, never played.

Observation 2 is inconsistent with observation 1 for every bone below the root, which is the bug.

## Why conjugating by C turns the body around

Conjugation by a 180 deg turn about Y keeps the Y components of a transform and negates its X and Z components (for the translation; the rotation is turned likewise). A spine bone whose local offset and lean point slightly forward (-Z in its parent) ends up pointing slightly backward; a neck tilted forward tilts backward; a jaw opening forward opens backward. Applied to every bone in the chain, the whole posed body is mirrored front to back relative to a root that itself never moves. Visually that reads as "the creature is turned 180 deg", which is why everyone described it that way, even though it is a per-bone conjugation, not one global turn.

Measured against the source GLBs, the error this caused was a mean joint position error of **2-19 studs** per rig.

## Deriving the correct pose for a non-root bone

Below the root, the Roblox hierarchy is the glTF hierarchy unchanged (observation 1). So the correct local transform while animating is just the glTF one:

```
Rest * P_correct = A          =>   P_correct = Rest^-1 * A
```

The importer gave us `P`, not `A`. Invert its formula:

```
P = Rest^-1 * C * A * C
Rest * P = C * A * C
C * Rest * P * C = C * C * A * C * C = A          (C * C = I)
```

Substitute:

```
P_correct = Rest^-1 * C * Rest * P * C
```

That is the non-root fix. Every term is available in the place: `Rest` is the Bone's `CFrame`, `P` is the Pose's `CFrame`.

## Deriving the correct pose for the root bone

For the root, the converted rest is `Rest = C * R_g`, and the correct animated local in Roblox space is the converted glTF animation, `C * A`:

```
Rest * P_correct = C * A
P_correct = Rest^-1 * C * A = (C * R_g)^-1 * C * A = R_g^-1 * C^-1 * C * A = R_g^-1 * A
```

What the importer wrote:

```
P = Rest^-1 * C * A * C = R_g^-1 * C * C * A * C = R_g^-1 * A * C
```

So `P = P_correct * C`, and therefore:

```
P_correct = P * C^-1 = P * C
```

That is the root fix: one right-multiplication.

## The transform is its own inverse

Apply the non-root fix twice:

```
f(f(P)) = Rest^-1 C Rest (Rest^-1 C Rest P C) C
        = Rest^-1 C C Rest P C C
        = Rest^-1 Rest P
        = P
```

and for the root, `(P * C) * C = P`. So "undo" is "apply again". The tool exposes an `Undo` option that re-applies the transform to every clip marked fixed and clears the marks. This property is also a cheap self-test: fixing twice must return the original data bit for bit (up to float rounding).

## Fixing the root pose path

Even with correct numbers, a Root pose sitting at the keyframe's top level is never applied. The fix moves every top-level pose under a **weight-0 pose named after the part that holds the Root bone**:

```
Keyframe
└── <RootPart>   (Pose, Weight 0: a placeholder that names the path)
    └── Root     (Pose: now applied)
        └── Hips ...
```

Measured detail: the pose path must follow the instance path. The Animator applied the Root pose under `<the part holding the Root bone>`, not under a pose named `HumanoidRootPart`. A related normalisation re-paths every pose under the chain of its bone's ancestors (`<part> > Root > ... > parent bone`, missing links as weight-0 poses), because the Animator skipped poses whose path did not follow the bones (prop layers authored elsewhere). A Lua keyframe player that matches by name alone does not care, but the real Animator does.

## Detecting which clips need it

Not every clip on a rig was in the importer's convention: prop layers or clips made by other tools were already right. Fixing those would break them. Per clip, using the first keyframe:

1. **If it has a Root pose:** apply the root fix hypothetically. If the fixed Root pose is **closer to identity** (smaller rotation angle) than the original, the clip is in the imported convention: fix it. An imported Root pose carries a stray 180 deg turn (`P = P_correct * C`), and at the start of most clips the root is near rest.
2. **Otherwise:** sum the rotation angles of all weighted poses as they are, and as they would be after the non-root fix. If fixing reduces the sum by more than 5 deg, fix; else only wrap (re-path).
3. Mark the clip with an attribute (`AxisFix = "fixed"` or `"wrapped"`). A clip with the mark is skipped on reruns, which makes the tool idempotent.

## The code

```lua
local AXIS_C = CFrame.Angles(0, math.pi, 0)

local function angleOf(cf: CFrame): number         -- rotation angle in degrees, 0..180
	local _, a = cf:ToAxisAngle()
	a = math.abs(a)
	if a ~= a then return 0 end                      -- NaN guard for identity
	if a > math.pi then a = 2 * math.pi - a end
	return math.deg(a)
end

-- rest[boneName] = { cf = Bone.CFrame, root = (Bone.Parent is a BasePart) }
local function fixPose(p: Pose, r)
	if r.root then
		p.CFrame = p.CFrame * AXIS_C                                    -- root:     P' = P * C
	else
		p.CFrame = r.cf:Inverse() * AXIS_C * r.cf * p.CFrame * AXIS_C    -- non-root: P' = Rest^-1 C Rest P C
	end
end

local function fixClip(ks: KeyframeSequence, rest, holderName: string)
	if ks:GetAttribute("AxisFix") then return "skipped" end
	local kfs = ks:GetKeyframes()
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	local first = kfs[1]
	-- decide: imported convention or already right?
	local verdict = "wrapped"
	local rootPose
	for name, r in rest do
		if r.root and first then rootPose = first:FindFirstChild(name, true) end
		if rootPose then break end
	end
	if rootPose then
		if angleOf(rootPose.CFrame * AXIS_C) < angleOf(rootPose.CFrame) then verdict = "fixed" end
	elseif first then
		local before, after = 0, 0
		for _, p in first:GetDescendants() do
			local r = p:IsA("Pose") and p.Weight > 0 and rest[p.Name]
			if r then
				before += angleOf(p.CFrame)
				after += angleOf(r.cf:Inverse() * AXIS_C * r.cf * p.CFrame * AXIS_C)
			end
		end
		if after < before - 5 then verdict = "fixed" end
	end
	if verdict == "fixed" then
		for _, kf in kfs do
			for _, p in kf:GetDescendants() do
				local r = p:IsA("Pose") and rest[p.Name]
				if r then fixPose(p, r) end
			end
		end
	end
	-- wrap: top-level poses go under a weight-0 pose named after the part holding the Root bone
	for _, kf in kfs do
		local holder = kf:FindFirstChild(holderName)
		for _, p in kf:GetChildren() do
			if p:IsA("Pose") and p.Name ~= holderName then
				if not holder then
					holder = Instance.new("Pose")
					holder.Name = holderName
					holder.Weight = 0
					holder.Parent = kf
				end
				p.Parent = holder
			end
		end
	end
	ks:SetAttribute("AxisFix", verdict)
	return verdict
end
```

Edit only the clip sources, never a baked stub (it has no Poses). If clips are baked to stubs ([[Baked Clip Stubs and Archiving]]), restore the originals first, fix, then rebake.

## Turn clips: strip the root yaw

Bosses turn through the server: an `AlignOrientation` rotates the root at a set rate while a `Turn` clip plays. If the clip's Root bone also yaws, the body turns twice. After the axis fix, every `Turn*` clip has the yaw removed from its Root poses, keeping lift and tilt:

```lua
for _, kf in ks:GetKeyframes() do
	local p = kf:FindFirstChild("Root", true)
	if p and p:IsA("Pose") then
		local lv = p.CFrame.LookVector
		local yaw = math.atan2(-lv.X, -lv.Z)                 -- heading of the pose about Y
		p.CFrame = CFrame.Angles(0, -yaw, 0) * p.CFrame       -- remove it in the parent frame
	end
end
ks:SetAttribute("RootYawStripped", true)
```

General lesson: **decide who owns each degree of freedom.** If gameplay code owns facing, clips must not author it.

## How it was proven

Debugging by eye ("does it look turned?") cannot distinguish "turned 180" from "mirrored per bone", and would not catch the missing root motion. The proof was numeric:

1. **Ground truth from the source.** A script parsed each GLB directly (glTF JSON + binary buffers: node hierarchy, rest transforms, animation samplers and channels), evaluated every clip at fixed times, and computed world joint positions in glTF space.
2. **Convert the ground truth** to Roblox space with the known axis mapping (glTF x, z -> Roblox -x, -z) and the import placement.
3. **Studio side:** pose the imported rig from the KeyframeSequence at the same times (FK through `Bone.CFrame * Pose.CFrame`) and dump world joint positions.
4. **Compare** per joint, per clip. Before the fix: mean joint error 2-19 studs per rig. Under the hypothesis `P = Rest^-1 C A C`: 343 of 348 clips matched. After the fix: **0.01-0.08 studs** on all 20 kits.
5. **Animator parity:** the fixed clips played through the real Animator and through the Lua player agreed on **347 of 348** clips within 0.04 deg. The one exception had a key at exactly 180 deg, where the Animator's own direction is ambiguous.

After the fix, root motion played (spawn rises, intro drops, a boss leap), and every new import goes through the fix automatically as part of storing the enemy.

## A general method for the next importer convention

1. **Name the spaces.** Source file space, importer output space, runtime space. Write down what you know is converted (positions? rest? animation?) and where.
2. **Hypothesise the importer's formula** as a product of known matrices (`C`, `Rest`, `A`). Typical suspects: conjugation by an axis change, a missing conversion on the root, a handedness flip (a reflection, which is not a rotation and needs different handling), a per-bone rest re-basing.
3. **Solve for the correct pose** algebraically, as above. Keep every step reversible; if the fix is not invertible you have probably lost information and need the source.
4. **Prove it against ground truth** from the source file, per joint, in studs. Rotations alone can hide translation errors.
5. **Make it idempotent and reversible:** mark processed clips, provide undo, never fix twice.
6. **Look for the edge cases:** exactly 180 deg keys, clips made by other tools, root poses at the wrong level, prop layers.

## Symptoms checklist

| On screen | Likely cause |
|---|---|
| body faces backwards but hits land in front | per-bone conjugation (this note) |
| body faces backwards and hits land behind | root / model yaw wrong (the yaw fix on prepare should be 0 for -Y authored models) |
| root never rises, leaps happen in place | root pose at the keyframe top level, never applied |
| forward travel mirrored on one rig | a different convention on that rig (one boss needed its LowerTorso pose Z flipped) |
| one limb occasionally swings the long way | a key at exactly 180 deg |

## See also

[[Pipeline - Importing Animated Enemies]], [[Importing Models and Rigs]], [[3D Importer Settings Reference]], [[Bones and Skinned Meshes]], [[Motor6D Math and CFrame Composition]], [[Animation Data from Blender to Roblox]], [[Debugging Animation Problems]], [[How the Animator Really Behaves]]

## Connected notes
<!-- auto-links:start -->
[[Blender Armature and Bone Roll Conventions]] · [[Retargeting Animations Between Rigs]] · [[Rigging in Blender]] · [[Exporting FBX vs GLB]] · [[Skeleton Library]] · Official Docs - Asset Creation · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Weapon Design Rig Builder]] · [[Weapon Rig Player]] · [[Lua Keyframe Player]] · [[Creature Rig Conventions]] · [[Moon Animator and Third-Party Tools]] · [[Authoring Clips in Code]] · [[Ground Fitting Pipeline]] · [[Pipeline - Arm IK Baking and QA]]
<!-- related:end -->
