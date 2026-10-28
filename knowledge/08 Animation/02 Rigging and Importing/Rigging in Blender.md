---
tags: [rigging, blender, import, workflow, hub]
---
# Rigging in Blender (for Roblox)

This is the hub note for building rigs in Blender that survive the trip into Roblox and animate correctly once they get there. It covers the decisions you make before the first bone exists, the scene setup that makes every later step predictable, and the rules that one live action game (the "reference project") learned by shipping about 20 creature rigs, 150+ weapon rigs, pets, bosses and an armour kit through this pipeline. The detail lives in the linked notes; this one tells you which decision to make when, and why.

> Sources: "Roblox docs" means the Creator Hub (modeling specifications, Blender guide, avatar specifications). "Measured" or "project" means numbers recorded in the reference project. "Rule of thumb" means experience that is not a hard limit.

## 1. The three questions to answer before you add a bone

### 1.1 Who animates it, and with what joint type?

Roblox animates exactly three kinds of joint (see [[Rigs and Joints]]):

| Roblox joint | What it moves | How it gets there from Blender |
|---|---|---|
| `Motor6D` | A whole rigid part (MeshPart) relative to another part | Separate mesh objects, either named after bones or rebuilt as joints by a script after import |
| `Bone` | Vertices of a skinned MeshPart (and anything attached to the Bone, since a Bone is an Attachment) | One mesh with an Armature modifier and vertex groups (weights) |
| `AnimationConstraint` | A rigid part, like Motor6D, but a constraint that can also be physically simulated | Not produced by the importer for custom rigs; player avatars use it (see [[AnimationConstraint and Physically Simulated Characters]]) |

A KeyframeSequence names joints by the **child** (Part1 or Bone) name, so the same clip can drive a Motor6D rig and a Bone rig as long as the names and hierarchy match. The reference project relied on this: a rigid construct enemy shipped as a Motor6D part rig with the same bone names as its skinned family, and the family's shared clips played on both.

### 1.2 Part-based or skinned?

| | Part-based (rigid pieces) | Skinned (one deforming mesh) |
|---|---|---|
| Look | Blocky, voxel, mech, armour, weapons, robots | Organic, cloth, tails, faces, anything that bends smoothly |
| Blender setup | Separate objects, each parented (Bone parent) or just named | One mesh, Armature modifier, weight paint |
| Roblox result | MeshParts joined by Motor6Ds | One MeshPart deformed by Bones |
| Joint seams | Visible gaps or overlaps at elbows unless designed for (caps, ball joints, overlap sleeves) | Smooth, but can collapse (candy-wrapper twist, elbow pinch) |
| Debugging | Easy: every part is selectable, joints are inspectable in Studio | Harder: weights are only visible in Blender |
| Retargeting | Robust: rotate parts about pivots | Fine if names and rest frames match; weights do not care |
| Physics hooks | Every part can collide, carry attachments, hold welds | Only the single MeshPart has a collision box; attach things to Bones |
| Cost | Many parts (each a draw and a physics body) | One part, GPU skinning, limited bones per vertex |
| Reskin | Swap meshes, keep pivots | Re-weight every new mesh |

Choose part-based by default for anything hard-surface. The reference project rebuilt a whole 49-model blocky roster with zero clip edits because bones and pivots stayed identical while the meshes changed (see [[Creature Rig Conventions]]). Choose skinned when silhouette continuity matters more than debuggability: tails, wings with membranes, faces, cloth.

A hybrid is normal and often best: a skinned body plus rigid props (weapons, shields, armour plates, a lantern) attached to bones with `RigidConstraint` (Bones are Attachments, so `RigidConstraint.Attachment0` can be a Bone).

### 1.3 Does it need a Humanoid?

- **Player characters, or NPCs that use `Humanoid:MoveTo` and pathfinding:** Humanoid plus Animator, and follow the R15 conventions if you want the default Animate script, emotes and layered clothing to work. See [[R15 Rig Anatomy and Attachments]] and [[Custom Characters and StarterCharacter]].
- **Everything else** (creatures moved by your own server code, weapons, props, pets, bosses): `AnimationController` plus `Animator`, no Humanoid. Cheaper, and nothing fights your root motion. The reference project's whole enemy roster used AnimationController, with the server moving an invisible `HumanoidRootPart` box.

## 2. Scene setup that removes 80% of import bugs

| Setting | Value | Why |
|---|---|---|
| Unit system | None (Roblox docs) or Metric with scale 1, but **model 1 Blender unit = 1 stud** | Every number you read in Blender is then a stud number. Project convention. |
| Rotation units | Degrees | Matches Studio and every clip table you will write |
| Character facing | **-Y** (the character looks out of the Front view at you) | With glTF export (+Y up) and the importer's measured 180 degree turn, -Y lands on Roblox's `LookVector` (-Z). See [[Blender Armature and Bone Roll Conventions]]. |
| Up | +Z in Blender | Converted to +Y on export |
| Author height | Final in-game stud height | Avoids scale objects in the hierarchy, and root translations in clips are then already in studs |
| A player reference | A proxy of the player at game scale next to your model | The project's players are 1.6x scale, about 9 studs tall; a default R15 is about 5.2 studs (measured). Size bosses and doorways against it. |
| Frame rate | 30 fps | The Roblox Animation Editor works at 30 fps; clip tables in the project are seconds at 30 fps |

The Roblox Blender guide also documents FBX-specific scale settings (FBX unit scale, or a 0.01 export scale); glTF needs none of them. The full comparison is in [[Exporting FBX vs GLB]].

## 3. Building the armature

The full conventions are in [[Blender Armature and Bone Roll Conventions]]. The short version:

1. **Root bone at the origin**, on the ground under the centre of mass. Name it `Root` (creatures, props) or match the Roblox root you will build (`HumanoidRootPart` lives outside the armature for R15-style rigs; the R15 avatar spec uses `Root > HumanoidRootNode > LowerTorso`).
2. **The root carries no weights** (Roblox docs: "don't apply influences to the root"), and never put the motion you care about only on it. The top-level pose of a Roblox keyframe is never applied (measured). Put hip lift and travel on the first child (`LowerTorso`, `Hips`, `Body`).
3. **One deform bone per moving piece**, with a clean local axis for anything that spins (a turbine bone whose local Y is the spin axis, so a single channel animates it).
4. **Consistent roll.** The project rule: every bone's local X points to the creature's right, so a positive X rotation lifts a limb forward and pitches a spine back, on every rig. This matches R15, whose joint frames are aligned with the body (measured: every R15 RigAttachment has zero rotation, so a positive X rotation lifts an arm forward).
5. **Names for code.** ASCII, unique, no `.001` suffixes, side suffix `L` / `R` (or the R15 `Left` / `Right` prefixes for R15-compatible rigs). Code and clips find joints by name.
6. **Shallow hierarchy where you can.** Each level adds a CFrame multiply per frame in Lua players and makes FK error accumulate; deep chains (tails of 12 bones) are fine when they are the point, wasteful when they are not.
7. **Rest pose** that your clips assume. Bipeds: the project used an A-pose (arms 40 degrees down) for creatures; the Roblox avatar spec accepts I, A or T pose for bodies. Whatever you pick, freeze it once: clips are stored as offsets from rest.

### Control rigs versus deform rigs

Blender's power (IK constraints, drivers, Rigify, custom shapes) does not exist in Roblox. Roblox only receives the deform bones' transforms per frame. Keep two layers:

- **Deform skeleton:** the bones that are exported, with Roblox-friendly names and hierarchy.
- **Control rig:** IK targets, pole bones, mechanism bones. They drive the deform skeleton through constraints and are **never exported** (glTF: "Export Deformation Bones only"; FBX: "Only Deform Bones"). Mark them non-deform (`use_deform = False`).

Rigify output is a control rig with a deform layer (DEF- bones) whose names and parenting are not a clean game skeleton. Rule of thumb: either retarget Rigify's DEF bones onto a clean skeleton with Copy Transforms constraints and bake, or build the deform skeleton yourself and drive it.

Whatever drives the bones, **bake to keyframes on export** (FBX "Bake Animation"; glTF "Always Sample Animations"). Roblox will never evaluate a Blender constraint.

## 4. Meshes: skin, parent, or rebuild?

| Method in Blender | What the importer produces | Use for |
|---|---|---|
| Armature modifier + vertex groups | Skinned MeshPart + Bones | Organic bodies, cloth, faces |
| Object parented to a bone (Bone parent), no weights | Usually a separate MeshPart; behaviour depends on importer and rig type (verify on a test import) | Rigid pieces when you want the importer to keep the bone |
| Mesh weighted 100% to one bone ("rigid skinning") | Skinned MeshPart where each vertex follows one bone | Cheap rigid sections inside one mesh (swarm units in the project used 1 bone per vertex) |
| Separate named objects, no armature at all | Separate MeshParts, no joints | Part rigs you will **rebuild in Studio by script** from a manifest |

The last row is the most robust pipeline the reference project found for weapons and props: export plain named parts, write a JSON manifest of hinge positions and parents, then build the Motor6Ds in Studio with code. Nothing about joint frames is left to the importer. See [[Custom Rigs - Weapons and Props]] and [[Importing Models and Rigs]].

A community-reported importer behaviour worth knowing: when an FBX mesh object has the same name as a bone it is bound to, the importer may turn that bone into a Motor6D-driven part instead of a Bone. That is how R15-style part rigs import, and also a trap when you did not mean it. Name meshes `<Part>_Geo` (the avatar convention) or otherwise differently from bones unless you want that behaviour.

Weights, influence limits and corrective tricks are in [[Weight Painting and Skinning for Roblox]].

## 5. Animation inside Blender

- **One Action per clip,** named exactly as the game references it (`Idle`, `Walk`, `Attack1`, `Death`). Mark the actions with fake users so they survive saving.
- **Markers:** use the Action's pose markers (Dope Sheet > Action Editor > Markers > "Show Pose Markers") for `Hit`, `Tele`, `Step`, `TrailOn`. Neither exporter writes them in a form Roblox turns into `KeyframeMarker`s, so export marker times yourself (a JSON or Lua table) and re-create them in Studio. The project's exporter wrote `<Name>_clips.json` and `<Name>_Clips.lua` with `{dur, loop, marks}` per clip.
- **Partial clips** (an "Inflate" layer, a rotor spin) need care: the glTF exporter samples every bone of the armature in every animation, which keys the whole body and pins it when the clip is layered in Roblox. The project post-processed the GLB to drop the other bones' channels. See [[Animation Data from Blender to Roblox]].
- **Ground contact:** keep feet on Z = 0 at rest, and check every clip's lowest point. Clips where feet dip below the floor need a ground-fit pass (see [[Ground Fitting Pipeline]]).
- **Root motion:** keep it on the first child of `Root`. Turn clips that the server rotates should have their root yaw stripped (the project did this to every `Turn*` enemy clip).
- **Things that spin forever** (orbiting stones, lanterns, hems, rotors) are cheaper and loop more cleanly when stripped from clips and spun client-side in code. The project did this for a 42-bone boss.

## 6. Export, import, prepare

| Step | Note |
|---|---|
| Export format | glTF/GLB for part rigs and static kits; FBX when you need Roblox's documented skinned-avatar path or Animation Editor FBX import. See [[Exporting FBX vs GLB]]. |
| Import | Studio 3D Importer, settings in [[3D Importer Settings Reference]]. The importer cannot be driven from a plugin for a local file; someone clicks through it (or you upload from Blender with an Open Cloud add-on, then insert by asset id). |
| Prepare | One idempotent Studio function that adds the root part, joints, Animator, markers, attributes and moves things into storage. See [[Importing Models and Rigs]]. |
| Clips | Either let the importer bring animations (they land in `ServerStorage.RBX_ANIMSAVES`) or export per-bone transforms yourself and build KeyframeSequences. See [[Animation Data from Blender to Roblox]]. |

## 7. Headless Blender as a build tool

The reference project generated most rigs, meshes, weights and clips from Python run in background Blender (`blender -b --factory-startup -P build.py -- --export`). Why this pays off:

- A rig family becomes a function: `build_rig(name, bones)` with `(name, parent, head, tail)` tuples, roll computed by a rule, deform flags set by name.
- Clips become data: `{frame: {bone: {r = (x, y, z), l = (x, y, z)}}}` tables, so retiming is a one-line change and a family's shared clips can be regenerated for every member.
- Exports are deterministic: the same script produces the same GLB, and the marker table is written next to it.
- Checks are automatic: lowest point per clip, bone count, influence count, texel density, triangle budget.

Practical gotchas measured in the project:

- Some native tools, Blender included, fail on very long Windows paths. Build in short folders.
- Opening another `.blend` in an interactive session that holds a logged-in upload add-on can log the add-on out; append objects with `bpy.data.libraries.load` instead of opening files.
- Keep each background job single-threaded when several run at once (the project capped heavy Python jobs at 1 thread each after a machine stall).

## Checklist before export

- [ ] All transforms applied on meshes and armature (scale 1, rotation 0). Roblox docs: freeze transforms, root at 0, 0, 0.
- [ ] Character faces -Y, feet on Z = 0, final stud height.
- [ ] Root bone at origin, no weights on it, motion on its first child.
- [ ] Bone names unique, ASCII, match the Roblox part or clip names; no `.001`.
- [ ] Roll convention applied to every bone (recalculate after any edit mode change).
- [ ] Control bones marked non-deform; export deform bones only.
- [ ] Max 4 influences per vertex, normalised, no zero-weight vertices.
- [ ] Each mesh under the triangle limit (Roblox docs: 20,000 per mesh; avatar parts have their own budgets).
- [ ] One Action per clip, fake user on, markers placed, marker table exported.
- [ ] A test export imported into a scratch place before the real batch.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Unapplied object scale | Tiny or giant import, or animation translations off by the scale factor | Ctrl+A > All Transforms on mesh and armature; re-export |
| Root motion on the root bone | Creature never leaves its spot, or clip plays in place | Move translation to the first child bone |
| Inconsistent bone roll | One arm lifts forward, the other twists; shared clips break on some members | Recalculate roll with one rule for the whole rig; never hand-roll single bones |
| Exporting IK/control bones | Extra bones in Roblox, wrong hierarchy, huge clips | Deform-only export |
| Unbaked constraints | Animation looks right in Blender, limbs frozen in Roblox | Bake on export or sample yourself |
| Mesh named like its bone | Part turns into a Motor6D piece, skinning lost | Rename meshes `<Name>_Geo` |
| Clip authored at a different height than the model | Feet hover or sink | Author at final height, or scale root translation by the height ratio |

## See also

[[Blender Armature and Bone Roll Conventions]] · [[Weight Painting and Skinning for Roblox]] · [[Exporting FBX vs GLB]] · [[Importing Models and Rigs]] · [[3D Importer Settings Reference]] · [[Custom Rigs - Weapons and Props]] · [[Creature Rig Conventions]] · [[R15 Rig Anatomy and Attachments]] · [[Animation Data from Blender to Roblox]] · [[Retargeting Animations Between Rigs]] · [[Bones and Skinned Meshes]] · [[Pipeline - Importing Animated Enemies]]

## Connected notes
<!-- auto-links:start -->
[[Modeling Characters for R15 and Custom Rigs]] · [[Skinning Weights]] · [[Skeleton Library]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Character and Creature Pipeline]] · [[Links - Importing into Studio]] · [[Animation Start Here]]
<!-- auto-links:end -->
