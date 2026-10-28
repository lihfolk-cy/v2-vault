---
tags: [modeling, voxel, characters, proportions, rigging, motor6d, r15, joints, animation, blender, luau]
---
# Voxel Characters - Proportions Joints and Rigging

<!-- tldr:start -->
> [!tldr] TL;DR
> - Visible slit opens at the shoulder when the arm raises: Rigid blocks with no joint shape -> Sleeve or cap joint; or accept a styled gap joint
> - Forearm pokes through the upper arm: Elbow bent past what rigid blocks allow -> Cap joint, shorter lower arm, or keep elbows under about 100...
> - Left and right arms swing differently: Pivots placed by eye, not mirrored numerically -> Mirror pivot coordinates exactly
> - Proportion type chosen (chibi, toy, heroic, classic) and silhouette tested at 40 pixels.
> - Face at least 6, ideally 8 or more cells across; limbs 2 or more cells thick.
> - Joint shape chosen per joint; rotation limits noted for animators.
>
> Read more (18 KB note): ## 2. Joint shapes that hide the gap · ## 5. Getting joints from Blender to Studio · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A voxel character has to solve a problem that smooth characters do not: cubes do not bend. Every joint is a place where two blocks rotate against each other, and every rotation either opens a gap, pushes one block through another, or does both. Good voxel characters are designed around their joints from the first cell. They also have to choose a rigging route early, because Roblox offers three (a part rig with Motor6Ds, the 15-part R15 layout, or a single skinned mesh with bones) and each one suits voxels differently. [[Voxel and Blocky Modeling]] lists archetype proportions for enemies and companions; [[Modeling Characters for R15 and Custom Rigs]] and [[Rigging in Blender]] cover rigging in general. This note joins them for blocky characters specifically: head-to-body ratios that read at Roblox distances, joint shapes that hide gaps, where to put pivots on a grid, which rig route to pick, and a worked example built to R15 so the default animations work.

## 1. Proportions that read at Roblox distances

Blocky characters are almost always stylised, and the head is the most important feature. From [[Voxel Scale Grids and Stud Alignment]], at a typical third-person distance of 15 to 25 studs on a phone, a 5-stud character is roughly 100 to 170 pixels tall. The face has to work at a quarter of that.

| Type | Heads tall | Head share of height | Typical use (rule of thumb) |
|---|---|---|---|
| Chibi | 2 to 2.5 | 40 to 50 percent | Pets, mascots, cute NPCs, collectible figures |
| Toy | 3 to 4 | 25 to 33 percent | Player-like characters, shopkeepers, most enemies |
| Heroic blocky | 5 to 6 | 17 to 20 percent | Knights, bosses, anything that should feel heavy |
| Classic blocky avatar | Head about 1/5 of height, wide square torso | 20 percent | The look that reads as "Roblox" to players |

Public reference points: Minecraft's player model is about 4 heads tall with an 8-pixel cube head on a 32-pixel body; Crossy Road's characters are roughly 2 heads tall. Both are deliberate: the larger the head share, the cuter and more readable at small sizes, and the less the body can act.

Practical proportion rules for voxel characters (rules of thumb):

- **Faces need at least 6 cells across** for two eyes, a gap and a mouth; 8 to 10 is comfortable. At 0.25-stud cells an 8-cell face is 2 studs wide, which fits a toy-proportioned 5-stud character.
- **Limbs at least 2 cells thick**, preferably 3 or 4. A 1-cell limb has no room for a joint shape and disappears at a distance.
- **Use even widths for limbs that rotate around their centre line** so the pivot falls on a cell edge (section 3), or odd widths with pivots on cell centres. Mixing on one character makes pivots inconsistent.
- **Hands and feet one or two cells bigger than realism** suggests: they carry most of the animation readability.
- **The silhouette test**: fill the character black at 40 pixels tall and check you can still tell what it is and which way it faces.

## 2. Joint shapes that hide the gap

When a block rotates around a pivot at its end, its corners swing out of the space they occupied and the face that touched its neighbour tilts away. Two artefacts follow: a **gap** opens on the outside of the bend, and the inside corner **intersects** the neighbouring block. On smooth characters, skinning blends the mesh to hide this. On rigid voxel parts nothing hides it unless the geometry does.

Four joint designs, from simplest:

| Joint | How | Hides | Costs |
|---|---|---|---|
| **Gap joint** | Leave a one-cell gap between parts; the pivot sits in the gap | Intersection (nothing collides for small angles) | The gap is visible; reads as a toy or puppet, which is often the style |
| **Overlap joint** | Extend the child part one or two cells into the parent | Gaps at moderate angles | Intersection shows at large angles; keep the overlap inside the parent's silhouette |
| **Ball or cap joint** | A small cube (or stepped sphere) centred on the pivot, slightly wider than both limbs | Gaps and intersections from every angle, because the cap occupies the same space whatever the rotation | A few extra cells; slightly bulky look |
| **Sleeve joint** | The parent part is wider and hollow at the joint, like a cuff, and the child rotates inside it | Everything up to the sleeve's depth | The parent must be bigger; works for shoulders, hips and necks |

**Rule of thumb**: sleeve joints at the shoulders and hips (the torso is big anyway), cap joints at elbows and knees if the character has them, and gap joints on chibi characters where the limb is a single block. Many good blocky characters have no elbows or knees at all: each limb is one block that rotates at the shoulder or hip, as with the classic blocky avatar. That is a choice, not laziness; it halves the joint problems and suits the toy look.

**Rotation limits matter more for voxels.** A rigid voxel forearm cannot bend past about 90 degrees before the inner corner intersects the upper arm badly. Animators working on blocky rigs should keep elbows and knees under about 90 to 110 degrees and design poses around that (rule of thumb). See [[Elbow Poles Swivel and Joint Limits]].

## 3. Pivots on the grid

Pivot placement decides whether a joint rotates cleanly.

- **The pivot belongs at the centre of the joint volume**, not at the edge of a block. For a blocky arm hanging beside the torso, that is on the arm's centre line, about half the arm's width below the top of the arm, so the top of the arm swings in a circle that stays inside the shoulder volume.
- **On even-width limbs** (2 or 4 cells), the centre line falls on a cell edge, so the pivot sits on a grid line. On odd widths (3 cells), it falls on a cell centre, half a cell off the grid. Both rotate correctly; the problem is only mixing them, because a script or animation tool that snaps pivots to the grid will move the odd ones by half a cell.
- **Cap joints are centred on the pivot.** Build the cap symmetrically around the pivot point: a 4-cell cap around an even-width pivot, a 3-cell cap around an odd one.
- **Pivots must match exactly between left and right.** Mirror the model in your voxel tool and mirror the pivots numerically in Blender (negate one coordinate) rather than placing them by eye.

In Blender, for a rigid part rig, each limb object's origin is its pivot: snap the 3D cursor to the pivot coordinate (type it in the sidebar, as a multiple of the cell size) and use Object, Set Origin, Origin to 3D Cursor.

## 4. Choosing a rig route

| Route | What it is | Good for voxels because | Bad for voxels because |
|---|---|---|---|
| **Part rig with Motor6Ds** | Each limb is its own MeshPart; Motor6D joints connect them; animated with the Animation Editor | Rigid blocks are exactly what voxels are; no skinning artefacts; per-part `Color` recolouring | More instances (one MeshPart per limb per colour group, unless you use a palette texture per limb) |
| **R15 layout** | The same, but with R15's 15 part names and joints | Default Roblox animations, emotes and the Animate script work (see [[R15 Rig Anatomy and Attachments]]) | Fixed part list; you must model hands, lower arms and so on even if the style wants one-block limbs (they can be tiny or hidden inside the upper part) |
| **Skinned mesh with bones** | One mesh; each vertex weighted to bones | One mesh, fewer instances | Smooth weights bend cubes into lozenges, which breaks the voxel look. Usable only with rigid weights (each vertex 100 percent on one bone) |

**Rigid skinning** is the useful middle ground for large blocky creatures with many parts: build the creature as one mesh, but assign every vertex of each limb 100 percent to that limb's bone. The mesh then moves like a part rig (no bending), as one MeshPart. Roblox allows at most 4 bone influences per vertex (Roblox docs), and rigid weighting uses exactly one. The cost is that you lose per-limb `Color` recolouring and the joint gaps behave exactly like a part rig's, so the joint shapes from section 2 still apply. See [[Bones and Skinned Meshes]] and [[Weight Painting and Skinning for Roblox]].

**Rule of thumb**: player-like voxel characters that should use default animations: R15 layout. Enemies and creatures with their own animations: part rig, or rigid-skinned mesh if they have more than about 15 parts. Pets that only bob and spin: no rig at all, just a single model tweened as a whole.

## 5. Getting joints from Blender to Studio

Two ways to end up with Motor6Ds:

1. **Build joints in Studio from a manifest.** Export the limbs as separate MeshParts (one GLB with a Model), then create the Motor6Ds with a script that knows each joint's pivot. You control `C0` and `C1` exactly. This is the reliable path and the one [[Custom Rigs - Weapons and Props]] recommends.
2. **Let the importer create them.** Community reports on the 3D Importer say that when a mesh object has the same name as a bone in its armature, the importer turns that bone into a Motor6D joining a part, and that rest rotations on such joints are reset to zero (community-reported; not in the official importer page; see [[3D Importer Settings Reference]]). For voxel rigs with axis-aligned rest poses this is usually harmless, but test one character before relying on it.

The manifest approach in Luau:

```lua
--!strict
-- Build Motor6D joints for a rigid voxel character from a pivot table.
-- Each entry: child part, parent part, and the joint pivot in the model's rest space (studs).
type Joint = { name: string, part0: string, part1: string, pivot: Vector3 }

local function buildJoints(model: Model, joints: { Joint })
	for _, j in joints do
		local p0 = model:FindFirstChild(j.part0) :: BasePart?
		local p1 = model:FindFirstChild(j.part1) :: BasePart?
		assert(p0 and p1, `missing part for joint {j.name}`)
		local old = p1:FindFirstChild(j.name)
		if old then old:Destroy() end
		-- The joint frame sits at the pivot, aligned to the model's axes.
		local pivotWorld = model:GetPivot() * CFrame.new(j.pivot)
		local m = Instance.new("Motor6D")
		m.Name = j.name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = p0.CFrame:ToObjectSpace(pivotWorld)
		m.C1 = p1.CFrame:ToObjectSpace(pivotWorld)
		m.Parent = p1   -- R15 convention: the joint lives in the child part
	end
end

-- Example pivots for a 0.25-stud voxel character whose model pivot is at the feet, centred.
-- Legs 6 cells tall (0 to 1.5 studs), torso 8 wide x 6 tall (1.5 to 3.0), head 8 tall (3.0 to 5.0),
-- arms and legs 4 cells wide. Arms hang beside the torso, so their centre lines are at x = +-1.5.
local joints: { Joint } = {
	{ name = "Neck", part0 = "Torso", part1 = "Head", pivot = Vector3.new(0, 3.0, 0) },
	{ name = "LeftShoulder", part0 = "Torso", part1 = "LeftArm", pivot = Vector3.new(-1.5, 2.5, 0) },
	{ name = "RightShoulder", part0 = "Torso", part1 = "RightArm", pivot = Vector3.new(1.5, 2.5, 0) },
	{ name = "LeftHip", part0 = "Torso", part1 = "LeftLeg", pivot = Vector3.new(-0.5, 1.5, 0) },
	{ name = "RightHip", part0 = "Torso", part1 = "RightLeg", pivot = Vector3.new(0.5, 1.5, 0) },
}

return { buildJoints = buildJoints, exampleJoints = joints }
```

Run it with the model in its rest pose, every part anchored, then unanchor all but the root before animating. The pivots in the example are whole multiples of 0.25 studs, on grid lines, because the limbs are even-width. If your model's pivot is not at the feet, set it there first (`Model.WorldPivot`) or the pivot table will be offset. [[Motor6D Math and CFrame Composition]] explains why C0 and C1 are both computed from the same world pivot.

## 6. Animating blocky characters

- **Stepped animation suits voxels.** Many blocky games animate on a low frame rate feel, holding poses for several frames. The Animation Editor supports a Constant easing style per keyframe, which holds a pose until the next key: key every 2 to 4 frames at 30 or 60 fps with Constant easing for a stop-motion look (rule of thumb).
- **Big poses, few joints.** With no elbows or knees, all expression comes from shoulder, hip and neck rotation plus whole-body squash. Bob the root 1 to 2 cells on each step; tilt the head 10 to 15 degrees; swing limbs 30 to 45 degrees in a walk.
- **Keep rotations around grid-aligned axes** for the rest pose so every clip starts clean.
- **Squash and stretch** cannot bend cubes, but you can scale a whole part from its pivot through a script or by animating scale on rigs that support it; most blocky games fake it with root bob and a quick head scale instead. See [[Squash Stretch and Anticipation in UI and Characters]].

## 7. Worked example: an R15-compatible voxel character

Goal: a toy-proportioned blocky character, 5 studs tall, 0.25-stud cells (20 cells tall), that uses the default R15 animations.

1. **Block out the proportions** in MagicaVoxel: head 8 x 8 x 8 cells (2 studs, 40 percent of height, chibi-to-toy), torso 8 wide x 6 tall x 4 deep, legs 4 x 6 x 4 each, arms 3 x 6 x 3 each. Arms are odd-width; decide now that arm pivots sit on cell centres and leg pivots on cell edges, and record both.
2. **Split into R15 parts.** R15 needs Head, UpperTorso, LowerTorso, and Upper, Lower and Hand parts for each arm and leg. Split the 6-cell torso into a 4-cell UpperTorso and 2-cell LowerTorso; split each limb 3 / 2 / 1 cells into upper, lower and hand or foot. The default animations bend elbows and knees, so give those joints cap shapes one cell wider than the limb, or accept small gaps.
3. **Make each part a separate model** in the voxel scene so each exports as its own object.
4. **Import into Blender** (greedy meshing, material per colour or palette texture), scale by 0.25, apply transforms.
5. **Name objects exactly** with the R15 part names, set each object's origin to its own centre, and place the joint pivots where R15 expects them: the Neck between Head and UpperTorso, Waist between UpperTorso and LowerTorso, Shoulders, Elbows, Wrists, Hips, Knees and Ankles at each boundary (see [[R15 Rig Anatomy and Attachments]] for the full joint and attachment list).
6. **Export GLB** and import into Studio. Build the joints with the manifest script (extended to all R15 joints), or use Studio's rig tools with your parts.
7. **Add a HumanoidRootPart** (2 x 2 x 1 studs is the R15 convention), a Humanoid, and compute `HipHeight` from the model at rest ([[Custom Characters and StarterCharacter]]).
8. **Test the default animations**: walk, run, jump, climb, idle. Watch the elbows and knees: if the lower arm pokes through the upper arm on the run cycle, widen the cap or shorten the lower part by one cell.
9. **Test at 20 studs on a phone**: the face should still read, and the limbs should not flicker.

## 8. When not to build a voxel character this way

- **Layered clothing and avatar accessories** expect R15 body shapes and cages ([[Layered Clothing Cages and Animation]]). A voxel character that must wear marketplace clothing is a different project.
- **Highly expressive faces** with many expressions are easier as decal or texture faces swapped by script than as voxel geometry.
- **Characters that must look smooth when bending** (cloth, tails, tentacles) are better as skinned meshes with smooth weights, styled blocky only in silhouette.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Visible slit opens at the shoulder when the arm raises | Rigid blocks with no joint shape | Sleeve or cap joint; or accept a styled gap joint |
| Forearm pokes through the upper arm | Elbow bent past what rigid blocks allow | Cap joint, shorter lower arm, or keep elbows under about 100 degrees in clips |
| Left and right arms swing differently | Pivots placed by eye, not mirrored numerically | Mirror pivot coordinates exactly |
| Arms shift half a cell when pivots are snapped | Odd-width limbs with pivots on cell centres, snapped to grid lines | Even widths, or a written rule per limb |
| Cubes bend into lozenges | Smooth skin weights on a voxel mesh | Rigid weights (100 percent per bone) or a part rig |
| Default animations look broken | Wrong part names or joint positions for R15 | Exact R15 names and joint placement; test walk and climb |
| Character floats or sinks | `HipHeight` not computed for the new proportions | Measure from the rest pose |
| Face unreadable at gameplay distance | Head under 6 cells across | Bigger head share or smaller cells on the head only if the style allows |

## Checklist

- [ ] Proportion type chosen (chibi, toy, heroic, classic) and silhouette tested at 40 pixels.
- [ ] Face at least 6, ideally 8 or more cells across; limbs 2 or more cells thick.
- [ ] Joint shape chosen per joint; rotation limits noted for animators.
- [ ] Pivot rule for odd and even widths written down; left and right mirrored numerically.
- [ ] Rig route chosen: R15 layout, part rig, rigid-skinned mesh, or none.
- [ ] Joints built from a manifest with exact C0 and C1, or importer behaviour tested on one character.
- [ ] HumanoidRootPart, Humanoid and HipHeight set for playable characters.
- [ ] Default or custom clips checked for intersections at the extremes of motion.

## Related

[[Voxel and Blocky Modeling]] · [[Modeling Characters for R15 and Custom Rigs]] · [[R15 Rig Anatomy and Attachments]] · [[Rigging in Blender]] · [[Bones and Skinned Meshes]] · [[Weight Painting and Skinning for Roblox]] · [[Custom Rigs - Weapons and Props]] · [[Custom Characters and StarterCharacter]] · [[Elbow Poles Swivel and Joint Limits]] · [[Motor6D Math and CFrame Composition]] · [[Chibi Character Rules in Practice]] · [[Voxel Scale Grids and Stud Alignment]]

## Connected notes
<!-- auto-links:start -->
[[Skinning Weights]] · [[Organic and Creature Modeling]] · [[Voxel Modelling Start Here]] · [[Posing and Silhouettes]] · [[Rigs and Joints]] · [[Two-Bone IK Math]]
<!-- auto-links:end -->
