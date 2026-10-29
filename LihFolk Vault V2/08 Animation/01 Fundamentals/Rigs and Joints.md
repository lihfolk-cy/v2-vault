---
tags: [fundamentals, rigging, motor6d, joints, type/guide, area/animation, level/beginner, api/Motor6D, api/AnimationConstraint, api/Part1]
---
# Rigs and Joints

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Pose named after the joint (`RightShoulder`) -> Name after Part1 (`RightUpperArm`)
> - Avoid: `IsA("Motor6D")` only -> Accept AnimationConstraint
> - Avoid: Animating `C0` every frame -> Write `Transform` in PreSimulation
>
> Cost: TL;DR ~100 tok · whole note ~4.2k tok. Read more: ## The three animatable joints · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

An animation never moves parts directly. It writes a local offset into **joints**, and the joints position the parts. So the first question about any rig is: what kind of joints does it have, what are they named, and which part is the parent of which? Get that wrong and clips play silently with nothing moving, or move the wrong limb, or work on your test dummy and break on players.

This note covers the three joint types, the R6 and R15 joint tables, how the Animator matches clip data to joints, non-character rigs, and the traps around building rigs in Edit mode. The maths of how a joint positions its part is in [[Motor6D Math and CFrame Composition]].

## The three animatable joints

| Joint | Class hierarchy | Used by | Rest pose defined by | Animated through |
|---|---|---|---|---|
| `Motor6D` | JointInstance > Motor > Motor6D | Classic R6/R15, part rigs, weapon hinges, doors, vehicles | `C0` (in Part0's space) and `C1` (in Part1's space) | `Transform` (hidden, not replicated) |
| `AnimationConstraint` | Constraint > [[AnimationConstraint]] | R15 avatars with Avatar Joint Upgrade (default for new experiences); physically simulated characters | `Attachment0.CFrame` and `Attachment1.CFrame` | `Transform` |
| `Bone` | Attachment > Bone | Skinned meshes | the Bone's own `CFrame` relative to its parent | `Transform` (not replicated) |

Other joints (`Weld`, `WeldConstraint`, `RigidConstraint`, `BallSocketConstraint`, `HingeConstraint`) are **not** animated by the Animator. A part attached by a Weld follows its parent rigidly; a part on a hinge constraint is moved by physics.

### The practical consequence: accept both Motor6D and AnimationConstraint
Since the Avatar Joint Upgrade rollout, R15 player characters spawn with `AnimationConstraint` joints instead of `Motor6D`s when `StarterPlayer.AvatarJointUpgrade` is enabled, and that is the default for new experiences. One production game found its live character rigs used AnimationConstraints while years of code (and every tutorial) assumed Motor6Ds. `IsA("Motor6D")` returns false for an AnimationConstraint, so every procedural system (head look, IK, recoil, ragdoll) silently did nothing on new avatars until fixed.

```lua
--!strict
-- Find the joint that moves a given part, whichever joint type the rig uses.
-- Returns the joint and a function that reads its rest frame in the parent part's space.
local function jointFor(part: BasePart): Instance?
	-- AnimationConstraint: lives anywhere in the character; match by Attachment1's parent
	local model = part:FindFirstAncestorWhichIsA("Model")
	if model then
		for _, d in model:GetDescendants() do
			if d:IsA("AnimationConstraint") and d.Attachment1 and d.Attachment1.Parent == part then
				return d
			end
		end
	end
	-- Motor6D: R15 parents it inside Part1, R6 inside Torso/HumanoidRootPart; match by Part1
	if model then
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and d.Part1 == part then
				return d
			end
		end
	end
	return nil
end
```

Cache the result: scanning descendants every frame is expensive. The docs recommend `FindFirstChildWhichIsA("AnimationConstraint")` first, falling back to Motor6D.

## R15 joint table

R15 Motor6Ds sit inside their **Part1** (the child part). With AnimationConstraints, the same pairs are connected through the matching `*RigAttachment` on each part.

| Joint name | Part0 (parent) | Part1 (child) = Pose name | Rig attachment pair |
|---|---|---|---|
| `Root` | HumanoidRootPart | LowerTorso | RootRigAttachment |
| `Waist` | LowerTorso | UpperTorso | WaistRigAttachment |
| `Neck` | UpperTorso | Head | NeckRigAttachment |
| `RightShoulder` / `LeftShoulder` | UpperTorso | RightUpperArm / LeftUpperArm | RightShoulderRigAttachment / Left... |
| `RightElbow` / `LeftElbow` | *UpperArm | *LowerArm | *ElbowRigAttachment |
| `RightWrist` / `LeftWrist` | *LowerArm | *Hand | *WristRigAttachment |
| `RightHip` / `LeftHip` | LowerTorso | RightUpperLeg / LeftUpperLeg | *HipRigAttachment |
| `RightKnee` / `LeftKnee` | *UpperLeg | *LowerLeg | *KneeRigAttachment |
| `RightAnkle` / `LeftAnkle` | *LowerLeg | *Foot | *AnkleRigAttachment |

15 body parts plus HumanoidRootPart: a full R15 keyframe is 16 Poses (the HumanoidRootPart one being the ignored top-level placeholder). `RightGripAttachment` in `RightHand` is where tools attach.

## R6 joint table

| Joint name (note the spaces) | Part0 | Part1 = Pose name | Lives in |
|---|---|---|---|
| `RootJoint` | HumanoidRootPart | Torso | HumanoidRootPart |
| `Neck` | Torso | Head | Torso |
| `Right Shoulder` / `Left Shoulder` | Torso | Right Arm / Left Arm | Torso |
| `Right Hip` / `Left Hip` | Torso | Right Leg / Left Leg | Torso |

R6 has no elbows, knees, wrists or ankles: one rigid part per limb. Its C0/C1 frames are also oriented differently from R15 (the R6 shoulder and hip frames are rotated so a positive rotation about their local axis swings the limb), which is one reason R6 clip data cannot be reused on R15 even after renaming.

| | R6 | R15 |
|---|---|---|
| Parts | 6 | 15 |
| Bends | none | elbows, knees, wrists, ankles, waist |
| IK | trivial (single bone) | two-bone IK per limb |
| Good for | retro combat, strong silhouettes, cheap NPCs | believable arms, weapons, IK, layered clothing |
| Clip reuse | R6 clips only | R15 clips only (any R15 proportions) |

## How the Animator matches a clip to joints

| Clip data | Binds to |
|---|---|
| KeyframeSequence `Pose` named X under parent Pose P | The joint whose Part1 is named X (and whose Part0 is P's part). For bones: the Bone named X. |
| [[CurveAnimation]] `Folder` named X | Same rule, folder nesting mirrors the joint tree. |
| `Motor6D.ChildName` / `ParentName` | Read-only mirrors of Part1.Name / Part0.Name; the docs state the animation system matches joints by these names. |

Consequences:
- **Renaming a part breaks every clip that animates it.** A part called `Blade` renamed to `Blade2` makes the Blade keys inert.
- **Duplicate part names are ambiguous.** Two parts called `Ring` under different parents may bind wrongly or not at all. Give every animated part a unique name. One weapon pipeline keyed its motors by `Part0.Name + "\0" + Part1.Name` in its own Lua player to survive this, but the real Animator does not.
- **Keys for missing joints are silently ignored.** That cuts both ways: a clip can carry extra joints for a richer rig, and a typo is never reported.
- **A joint with no Motor6D is never animated.** One team's weapon rule ("legendary weapons are animated") failed for a model that had an AnimationController and clips but its moving parts were welded, not motored: the clips played, nothing moved.

## Non-character rigs

### Weapon and prop hinge rigs
- A root part (`Handle`), one `Motor6D` per moving piece named after the piece, everything else welded to its nearest moving piece.
- `AnimationController` + `Animator` inside the model.
- Moving pieces unanchored, `Massless = true`, `CanCollide/CanTouch/CanQuery = false`, so a held weapon does not change the character's physics.
- Chained hinges (a chain whip, a flexible blade of segments) put each Motor6D's Part0 on the previous segment. One flexible sword used 4 ribbons of 5 chained segments.
- See [[Custom Rigs - Weapons and Props]] and [[Weapon Design Rig Builder]].

### Creatures and bosses
- Either part-based (Motor6Ds between rigid parts, cheap, faceted look) or skinned (Bones, smooth deformation). See [[Bones and Skinned Meshes]] and [[Creature Rig Conventions]].
- Root: an invisible, non-colliding `HumanoidRootPart` box, with the skeleton's root under it. Remember the top-level pose is ignored, so a root bone's motion must be keyed one level down or on the HumanoidRootPart's child.

### Things that need no rig
Floating pets, spinning pickups, bobbing platforms, doors on a single hinge: an anchored model moved with `PivotTo`, `TweenService` or `BulkMoveTo` is cheaper and simpler than a rig plus clips. See [[Tween and CFrame Animation of Objects]].

## Tools and the grip joint

When a `Tool` is equipped, Roblox welds its `Handle` to the right hand with a Weld called `RightGrip` (R15: in `RightHand`, using `RightGripAttachment` and `Tool.Grip`; R6: in `Right Arm`). Because it is a Weld, clips cannot animate the handle relative to the hand. Two production approaches:

| Approach | How | Trade-off |
|---|---|---|
| Drive the grip weld's `C0` procedurally | Spin, toss and catch a held blade by writing `RightGrip.C0` every frame on every client from shared data | No clips needed for blade tricks; each client computes it; snaps back on cancel |
| Replace the weld with a Motor6D | Destroy `RightGrip`; add a Motor6D `RightHand -> Handle` with `C0 = RightGripAttachment.CFrame`, `C1 = Tool.Grip` | Clips can key the Handle like any limb (Pose "Handle" under "RightHand"); you own equip/unequip lifecycle |

The second was the final choice in one sword game ("SwordMotor"), because it lets authored attacks include wrist-independent blade rolls.

## Edit-mode traps (measured)

- `Players:CreateHumanoidModelFromDescription` (deprecated; use the Async version) in Edit returned an R15 rig with **no Motor6Ds** in one project, and `Humanoid:BuildRigFromAttachments()` failed quietly on it. Build test-dummy joints yourself from the `RigAttachment` pairs: for each pair, `Motor6D.Part0 = parent part`, `Part1 = child part`, `C0 = parentAttachment.CFrame`, `C1 = childAttachment.CFrame`.
- Edit mode has **no physics step**, so writing `Transform` does not move parts. For still previews, compute part CFrames from the joint chain yourself or pose anchored copies.
- Imported R6 models sometimes come without some Motor6Ds (missing shoulders). Check every expected joint before animating.
- `require` caches modules in Edit; test edited rig modules through a clone-require or fresh `loadstring` of the source, or you will test stale code.

## Checking a rig before animating it

```lua
--!strict
local R15_PARTS = {
	"LowerTorso", "UpperTorso", "Head",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
}

-- Prints every R15 part that has no joint driving it (Motor6D or AnimationConstraint).
local function auditR15(model: Model)
	local driven: {[string]: string} = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 then
			driven[d.Part1.Name] = "Motor6D " .. d.Name
		elseif d:IsA("AnimationConstraint") and d.Attachment1 and d.Attachment1.Parent then
			driven[(d.Attachment1.Parent :: Instance).Name] = "AnimationConstraint " .. d.Name
		end
	end
	for _, name in R15_PARTS do
		print(name, driven[name] or "NOT DRIVEN")
	end
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	print("Animator:", animator and animator:GetFullName() or "MISSING")
end
```

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Pose named after the joint (`RightShoulder`) | Nothing moves | Name after Part1 (`RightUpperArm`) |
| `IsA("Motor6D")` only | Procedural code dead on new avatars | Accept AnimationConstraint |
| Animating `C0` every frame | Rest pose drifts; replicates heavily if done on the server; fights retargeting | Write `Transform` in PreSimulation |
| Two parts with the same name | Wrong part moves | Unique names |
| Moving parts welded instead of motored | Clip plays, nothing moves | Motor6D per moving part |
| R6 clip on R15 | Nothing moves | Separate clip per rig type |
| Anchored moving parts | Joint cannot move them | Unanchor all but the root |

## See also
[[Motor6D Math and CFrame Composition]] · [[Bones and Skinned Meshes]] · [[AnimationConstraint and Physically Simulated Characters]] · [[R15 Rig Anatomy and Attachments]] · [[Custom Rigs - Weapons and Props]] · [[Rigging in Blender]] · [[Importing Models and Rigs]] · [[Animation Objects]]

## Nuances and edge cases

1. **R6 or R15 is a game design decision.** The experience's avatar settings decide the rig type for players. R6 has six parts and simpler, more stylised motion; R15 supports layered clothing, dynamic heads, IK and most modern catalog content. Combat games sometimes pick R6 for readability and a classic feel, at the cost of catalog animation packs, emotes and newer avatar features. Switching later means re-authoring every clip, so decide before the animation library grows.
2. **Who creates the joint matters.** Joints created on the server replicate; joints created by a LocalScript exist only on that client. A weapon motored to the hand by a client script will animate for the owner and be loose or missing for everyone else. Create joints for anything others must see on the server (or through a `Tool`'s grip, which the engine handles), and keep client-only joints for client-only visuals such as first-person viewmodels.
3. **Streaming and rig assembly.** With StreamingEnabled, a model's parts can arrive over several frames. Code that finds joints right after a character or NPC appears can see a partial rig. Use `WaitForChild` with timeouts on the specific parts, or mark rigs as atomic models (`ModelStreamingMode = Atomic`, Roblox docs (as of October 2026)) so they stream in whole.
4. **Massless and assembly physics.** Every part motored into a character joins its assembly and adds mass unless `Massless` is set. A heavy weapon rig with many parts changes how the character moves, jumps and gets knocked back. Set props and weapon parts to `Massless = true`, and keep collision off on decorative parts to avoid tripping on your own sword.
5. **Joint count and cost.** Each animated joint is evaluated per frame per visible rig. A weapon with 20 hinged parts on every player in a 50-player server is 1,000 extra joint evaluations per client per frame. Fine on desktop, noticeable on phones. Weld parts that never move relative to each other, and motor only the parts that animate.
6. **Root part ownership.** The root part (HumanoidRootPart or a creature's root) decides the assembly's network owner. Anchoring or re-parenting the root changes ownership for the whole rig. Moving the root on the server for a player's character, other than teleports, fights the owner's physics.
7. **Renaming parts breaks clips silently.** Clips match by Part1 name. A modeller renaming `Blade` to `BladeMesh` in a re-export makes the clip play with no motion on that part and no error. Lock names with a check in the import pipeline.

## Common mistakes in production

1. **Client-created weapon joints.** Symptom: other players see weapons floating or at the feet. Fix: create joints on the server or use Tool grips.
2. **Partial rigs under streaming.** Symptom: procedural code errors or animates half a rig on join. Fix: atomic streaming for rigs, or wait for required parts.
3. **Weapon parts with mass.** Symptom: players with big weapons jump lower and get knocked further. Fix: `Massless = true` on weapon parts.
4. **Everything motored.** Symptom: rigs with dozens of static joints cost frame time. Fix: weld static parts.
5. **Switching R6 and R15 late.** Symptom: months of clips unusable. Fix: decide the rig type before building the animation library.

## Related decisions

- [[Characters and Humanoids]]: the Humanoid that owns most character rigs.
- [[Tools and Inventory Systems]]: Tool grips as the engine-managed alternative to custom hand joints.
- [[Instance Streaming]]: atomic streaming for rigs that must arrive whole.
- [[Physics Assemblies and Constraints]]: how motored parts join assemblies and add mass.
- [[Network Ownership]]: how the root part decides who simulates the rig.
- [[Modeling Weapons and Props]]: building weapon models with stable part names and few moving parts.
- [[Modeling Characters for R15 and Custom Rigs]]: rig structure from the modelling side.
- [[Places Universes and Experience Settings]]: where the R6 or R15 choice is made.
- [[Exporting and Validating Models for Roblox]]: name and structure checks at import.

## Connected notes
<!-- auto-links:start -->
[[Accessories and Armor That Follow Animation]] · [[Voxel Characters - Proportions Joints and Rigging]] · Skeleton Library · [[Animation Editor Workflow]] · Character and Creature Pipeline · Skinning Weights · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Skeleton Library]] · [[Retargeting Animations Between Rigs]] · [[AI Pitfalls - Physics and Animation]] · [[Animator Deep Dive]] · [[Procedural Animation]] · [[Snippets - Ragdoll]] · [[Blender Armature and Bone Roll Conventions]] · [[Custom Characters and StarterCharacter]] · [[Ragdolls and Physics-Based Animation]] · [[Snippets - Procedural Motion]]
<!-- related:end -->
