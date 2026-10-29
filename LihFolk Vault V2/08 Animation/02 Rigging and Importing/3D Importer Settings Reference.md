---
tags: [import, studio, reference, 3d-importer, type/reference, area/animation, level/intermediate, api/Motor6D, area/studio]
---
# 3D Importer Settings Reference

<!-- tldr:start -->
> [!tldr] TL;DR
> - Meshes should meet the modeling specifications first (20,000 triangles per mesh, watertight, frozen transforms; see Rigging in...
> - Dimensions and polycount shown under File Geometry are read-only information.
> - The importer page above does not list animation options.
> - When a mesh object has the same name as a bone in the connected armature, the importer turns that bone into a Motor6D joining...
>
> Cost: TL;DR ~140 tok · whole note ~3.1k tok. Read more: ## 2. File General · ## 6. Animation import options
<!-- tldr:end -->

Every option of Studio's 3D Importer (File > Import 3D), what it really does to an animated asset, and what to pick for each kind of import. Option names and defaults are from the Roblox Creator Hub importer page (checked October 2026). Behaviour notes marked "measured" come from one production game; anything from community threads is marked as such. Studio changes this dialog often: when a name here does not match your Studio, trust your Studio and update this note.

For the process around the dialog (finding the import, the prepare step, uploads), see [[Importing Models and Rigs]].

## 1. Supported files

| Kind | Formats (Roblox docs) |
|---|---|
| Mesh | `.fbx`, `.obj`, `.gltf` / `.glb`. FBX and glTF support multiple meshes, PBR textures, cage meshes, rigs, avatar components, animation data and vertex colours |
| Image | `.png`, `.jpg`, `.gif`, `.tga`, `.bmp` |
| Audio | `.ogg`, `.mp3`, `.flac`, `.wav` |
| Video | `.mp4`, `.mov` (if requirements are met) |

Meshes should meet the modeling specifications first (20,000 triangles per mesh, watertight, frozen transforms; see [[Rigging in Blender]]).

## 2. File General

| Option | Default | What it does | Animation-relevant advice |
|---|---|---|---|
| Name | file name | Name of the imported asset | Set it here; otherwise GLBs arrive as a model named `Scene` (measured), and two imports at once give two `Scene` models |
| Import Only As Model | on | Imports a multi-child file as one Model asset; off imports each descendant as its own asset | Keep on for rigs: joints and hierarchy live in one Model |
| Upload to Roblox | on | Uploads the model to your inventory (Toolbox / Asset Manager) | **Turn off while iterating.** Every test import otherwise creates assets you never use |
| Import as Package | off | Makes the asset an auto-updating package | Useful for kits installed into several places (the project shipped armour and level kits as packages and installed them by script) |
| Creator | you | User or group that owns uploads | Pick the group that owns the experience, or the assets will not be usable by it (see [[Animation Asset Permissions and Groups]]) |
| Add to Workspace | on | Inserts into Workspace; for saved or published games also grants the game permission to use the asset | Keep on |
| Insert Using Scene Position | off | Places the model at its file position instead of at the camera | On when you modelled pieces in place (level art, a kit aligned to the origin) |
| Keep Zero Influence Bones | off | Keeps bones that influence no vertices; off removes them | **On** when socket bones carry props via `RigidConstraint`, or when family rigs keep unweighted bones for clip sharing |
| Set Pivot to Scene Origin | on | Sets the whole model's pivot to the file origin | Keep on for rigs: the pivot then sits at the root bone (on the ground under the centre of mass if you followed the conventions) |
| Anchored | off | Anchors all imported MeshParts; does not apply to rigged meshes or avatars | Off for anything you will animate; anchor only a root part later, and only for static displays |
| Uses Cage | on if cages detected | Converts `_InnerCage` / `_OuterCage` meshes into `WrapLayer` / `WrapTarget` objects; off imports cages as ordinary meshes | On for bodies and layered clothing; see [[Layered Clothing Cages and Animation]] |

## 3. Rig General (rigged meshes)

| Option | Default | What it does | Advice |
|---|---|---|---|
| Rig Type | auto-selected | R15, Custom, or No Rig | **R15** only for rigs that follow the R15 names and hierarchy (bodies, R15-compatible NPCs). **Custom** for creatures and any other skeleton. **No Rig** for part rigs you will joint in Studio by script (the project imported weapon GLBs with "Rig none") |
| Validate UGC Body | n/a | Opens the import in Avatar Setup for testing and upload | Marketplace bodies only |
| Rig Scale | Default | Only for R15: Default, Rthro, Rthro Narrow (body type scaling). The avatar spec maps Rthro = Normal, Rthro Narrow = Slender, Default = Classic | Match the proportions the body was built for, or scaling values will distort it |

## 4. File Transform and Geometry

| Option | Default | What it does | Advice |
|---|---|---|---|
| World Forward | Front | Which file axis is the model's front | Leave at Front for Blender exports done per the docs; change it only to fix a known-wrong file, and write the fix down |
| World Up | Top | Which file axis is up | Leave at Top |
| Scale Unit | Studs | The unit the file was modelled in | **Studs** when you modelled 1 Blender unit = 1 stud (the project convention). A metre-modelled file needs the matching unit or it imports about 3.6x off (1 stud = 0.28 m per Roblox) |
| Merge Meshes | off | Merges all MeshParts into one instead of a Model | **Off** for every rig and kit: names, pivots and per-part joints are lost when merged. On only for a static prop you want as a single part |
| Invert Negative Faces | off | Flips faces with negative orientation | For files with mirrored (negative scale) objects that show inside-out |

Dimensions and polycount shown under File Geometry are read-only information. Check the dimensions: a 5-stud character showing 500 is a unit problem to fix at export, not in Studio ([[Exporting FBX vs GLB]]).

## 5. Per-object settings (select a child in the hierarchy panel)

| Option | Default | What it does | Advice |
|---|---|---|---|
| Name | object name | Renames that child | Rename here if a name collides with a bone (see the Motor6D note below) |
| Anchored | off | Anchors that child | Rarely; anchoring an animated piece freezes it |
| Use Imported Pivot | on | Uses the child's own pivot from the file | On: Blender object origins become MeshPart pivots, which part rigs need for hinge placement |
| Make Double Sided | off | Renders both sides (costs performance) | Wing membranes and cloth cards modelled as single sheets |
| Ignore Vertex Colors | off | Drops that child's vertex colours | Leave off if you colour with vertex colours |

## 6. Animation import options

The importer page above does not list animation options. What is known from other official sources:

| Source | What it says |
|---|---|
| Dynamic head guide (Roblox docs) | Set **Animation Offset** to 0 when importing a head, so frame 0 (the neutral pose) is included |
| Roblox announcement, August 2026 | Animations attached to models imported through the importer are now **saved automatically to AnimSaves** |
| Same announcement: the clip import dialog (Animation Editor, "From File") | **Rig Scale** (match the import to your stud scale or scale the animation), **Rest Pose Source** (which track gives the rest pose; options "Imported Rig", "Imported Rig (Zeroed Rotations)", "Animation Editor Rig"; previously always the first frame of the first track), **Rig Type** (R15 or Custom), **Animation Track Selection** (which track of the file to import) |
| Community thread on that announcement | A Roblox staff reply mentioned an "Animation General" section in the 3D Importer with a "Default with rotations" option that preserves global bone rotations. Not in the importer docs; verify in your Studio |

Measured in the reference project (before the announcement): clips from animated GLBs landed in `ServerStorage.RBX_ANIMSAVES.<model name>` (the model name being `Scene` by default), as KeyframeSequences with the root pose at the keyframe's top level. Their data needed an axis fix before they played facing the right way: see [[Enemy Import Axis Fix]].

"Rest Pose Source" matters more than it looks. A clip's poses are offsets from rest. If the importer takes rest from "the first frame of the first track" and that frame is not the bind pose (a clip that starts mid-attack), every imported clip is offset by that frame. Export clips that start from rest, or choose the imported rig's own rest explicitly.

## 7. The Motor6D-from-name behaviour (community-reported)

Community posts on the 2026 import thread report:

- When a mesh object has the same name as a bone in the connected armature, the importer turns that bone into a **Motor6D** joining a part, instead of a Bone. That is the mechanism behind R15-style part rigs (mesh `LeftUpperArm` on bone `LeftUpperArm`).
- Motor6Ds created this way have their **rest rotations reset to zero**, which breaks clips authored on a rig whose rest frames were not axis-aligned.
- `<Name>_Geo` mesh naming links meshes to bones for R15 characters but not for custom rigs.

None of this is in the official importer page. Practical rule: if you want Bones, name meshes differently from bones (`Body_Geo`); if you want a part rig, build the joints yourself in Studio from a manifest, where you control C0 and C1 (see [[Custom Rigs - Weapons and Props]]).

## 8. Presets and the queue

- Built-in presets: **Studio Default** and **Last Imported**. The `...` menu can Reset all, Save selection, Save as new, Set as default, Rename and Delete.
- Save one preset per asset kind (below), so a batch of 20 creatures is imported identically.
- The import queue takes several files; right-click "Apply settings to all" copies one item's settings to the batch. Items are checked by default when importable.
- After import, right-click offers **Copy asset ID** (when uploaded) and **Find in Workspace**.
- Warnings (orange) and errors (red) attach to hierarchy items; expand the tree to find which child is affected.

## 9. Recommended presets

| Preset | Part rig (script-built joints) | Skinned creature with clips | R15 body / NPC | Static level kit | Avatar body for Marketplace |
|---|---|---|---|---|---|
| Upload to Roblox | off while testing | off while testing | off while testing | on (if inserting by id later) | on |
| Import Only As Model | on | on | on | on | on |
| Rig Type | No Rig | Custom | R15 | No Rig | R15 |
| Rig Scale | n/a | n/a | match the body | n/a | match the body |
| Scale Unit | Studs | Studs | Studs | Studs | Studs |
| Merge Meshes | off | off | off | off | off |
| Keep Zero Influence Bones | n/a | **on** if sockets or family bones | off | n/a | off |
| Set Pivot to Scene Origin | on | on | on | on or off (per piece) | on |
| Insert Using Scene Position | off | off | off | on | off |
| Anchored | off (anchor the root in the prepare step if static) | off | off | on | off |
| Uses Cage | n/a | n/a | on | n/a | on |
| Validate UGC Body | off | off | off | off | on |

## 10. What the importer will not do for you

- It does not create a `HumanoidRootPart` for Custom rigs, an `AnimationController`, or an `Animator`. The prepare step does ([[Importing Models and Rigs]]).
- It does not create `KeyframeMarker`s from your Blender markers. Export marker times and add them in Studio.
- It cannot be triggered by a plugin or script for a local file (the reference project's tools could not import local files; a person clicks Import, or an Open Cloud add-on uploads from Blender and code inserts by id).
- It does not publish animation clips as Animation assets. Imported clips are local KeyframeSequences until someone publishes them ([[Publishing Animations]]).

## See also

[[Importing Models and Rigs]] · [[Exporting FBX vs GLB]] · [[Rigging in Blender]] · [[Enemy Import Axis Fix]] · [[Layered Clothing Cages and Animation]] · [[Facial Animation and Dynamic Heads]] · [[Custom Rigs - Weapons and Props]] · [[Animation Editor Workflow]]

## Connected notes
<!-- auto-links:start -->
[[Modeling Characters for R15 and Custom Rigs]] · Exporting and Validating Models for Roblox · [[Pipeline - Importing Animated Enemies]] · Official Docs - Asset Creation · Skeleton Library · Skill - Roblox Asset Import · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Animation Data from Blender to Roblox]] · [[Blender Armature and Bone Roll Conventions]] · [[Weight Painting and Skinning for Roblox]] · [[Exporting and Validating Models for Roblox]] · [[Bones and Skinned Meshes]] · [[Skeleton Library]] · [[Custom Characters and StarterCharacter]] · [[Creature Rig Conventions]] · [[R15 Rig Anatomy and Attachments]] · [[Accessories and Armor That Follow Animation]]
<!-- related:end -->
