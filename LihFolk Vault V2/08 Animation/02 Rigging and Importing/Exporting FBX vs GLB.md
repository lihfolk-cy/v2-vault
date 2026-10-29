---
tags: [export, blender, fbx, gltf, glb, import, type/guide, area/animation, level/intermediate, area/modeling]
---
# Exporting FBX vs GLB

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Leaf bones left on (FBX) -> Add Leaf Bones off
> - Avoid: Optimize Animation Size on (glTF) -> Turn it off, or key all bones explicitly
> - Avoid: Simplify left at default (FBX) -> Simplify 0
> - Transforms applied (scale 1, rotation 0) on armature and meshes; root at the origin.
> - Faces -Y, final stud height, feet on Z = 0.
> - Weights limited to 4 and normalised; no zero-weight vertices.
>
> Cost: TL;DR ~140 tok · whole note ~3.7k tok. Read more: ## 3. GLB export: settings and the reasons for them · ## 4. FBX export: settings and the reasons for them · ## 7. Pre-export checklist · ## Common mistakes
<!-- tldr:end -->

Studio's 3D Importer reads `.fbx`, `.gltf` / `.glb` and `.obj` (Roblox docs). FBX and glTF both carry multiple meshes, PBR textures, cage meshes, rigs, avatar components, animation data and vertex colours. So the choice is not "which one works" but "which one fails in ways you can control". This note compares them as they behave on the Blender to Roblox route, lists the export settings that matter and why, and records what one production game measured.

## 1. Quick decision

| You are exporting | Prefer | Why |
|---|---|---|
| Static props, level kits, weapon parts you will rig in Studio by script | **GLB** | One file, no unit-scale dance, positions and names come through cleanly |
| Part-based creature or prop rigs with clips | **GLB** (the reference project's route for about 20 enemy rigs and a 42-bone boss) | Every Action exports as a named animation; deterministic from a script |
| Avatar bodies, layered clothing, dynamic heads for the Marketplace | **FBX** (the format Roblox's avatar docs are written for) | Roblox's documented settings, Avatar Setup and validation assume it; dynamic head frame mapping uses FBX custom properties |
| A single clip for the Animation Editor's file import | FBX (or whatever the current clip importer accepts; check its file dialog) | Historically the editor's import path; one take per file |
| Uploading straight from Blender with an Open Cloud add-on | Whatever the add-on writes (FBX in the reference project) | The add-on handles the format; you handle pivots after insert |

## 2. Side by side

| Topic | FBX from Blender | GLB from Blender |
|---|---|---|
| Units | Blender writes FBX in centimetres; scaling must be managed (Roblox docs: "Apply Scalings: FBX Unit Scale") | glTF is metres by spec; with 1 Blender unit = 1 stud and importer Scale Unit "Stud", sizes match. Roblox docs: glTF "does not need these extra scaling settings" |
| Axes | Exporter converts with Forward/Up settings; Roblox's Blender guide says export "Forward: Z Forward, Up: Y Up" and import with World Forward "Front", World Up "Top" | "+Y Up" on; glTF front is +Z; Studio then turns the model 180 degrees about Y (measured), so a Blender -Y front lands on Roblox -Z |
| Bone orientation | Primary/Secondary Bone Axis options (defaults Y / X) can re-orient bone frames | Bones keep Blender frames (Y along the bone) |
| Leaf bones | "Add Leaf Bones" on by default: adds `_end` bones. **Turn it off** (Roblox docs) | No leaf bones |
| Several clips | "All Actions" or "NLA Strips" write several takes; Roblox docs say only one animation track per exported mesh or model, export each separately | Every Action (stashed or active) exports as a named glTF animation |
| Clip sampling | "Bake Animation" samples, with a lossy "Simplify" setting | "Always Sample Animations", sampling rate in frames; optional size optimiser |
| Custom properties | "Custom Properties" include option; required for dynamic head frame mapping | Written as glTF `extras`; not documented as used by the Roblox importer |
| Vertex colours | Exported with the mesh | Exported **only if** "Use Vertex Color" allows it (default "Material" = only when used in the material node tree) |
| Materials | Textures embedded with Path Mode "Copy" + "Embed Textures" (Roblox docs) | Packed in the GLB; flat base-colour factors did not survive import in the reference project |
| Debuggability | Binary, opaque | JSON chunk is readable; the project parsed GLBs in Python (node bounds, animation channels) and even edited them in place |

## 3. GLB export: settings and the reasons for them

The reference project exported every creature with the same keyword set from background Blender. Translated to UI names:

| Setting | Value | Reason |
|---|---|---|
| Format | glTF Binary (.glb) | One self-contained file |
| Include > Selected Objects | on | Export exactly the rig and its meshes; nothing else in the scene leaks in |
| Transform > +Y Up | on | glTF convention; the importer expects it |
| Mesh > Apply Modifiers | off, apply them yourself first | Deterministic geometry; the Armature modifier must not be "applied" |
| Vertex Color | "Active" (or make the material use it) | Default "Material" silently drops vertex colours not wired into the material |
| Materials | Export | Textures come along |
| Armature > Use Rest Position | on (default) | Rest pose is the bind pose, not whatever frame the timeline sits on |
| Armature > Export Deformation Bones Only | on if you have control bones; off if every bone deforms or is a socket | Keeps IK and mechanism bones out of Roblox |
| Skinning > Bone influences | 4; Include All Bone Influences **off** | Roblox's limit; but limit in Blender first so preview matches |
| Shape Keys | off for bodies | Not used by Roblox bodies (heads use bones plus [[FACS]] frames) |
| Animation mode | Actions | One glTF animation per Action |
| Export all Armature Actions | on | All clips of the single armature, even ones not on the NLA |
| Reset pose bones between actions | **on** | Without it, a bone not keyed in clip B keeps clip A's last pose in the export |
| Always Sample Animations | on, sampling rate 1 frame | Bakes constraints, drivers, IK and [[Bezier Curves\|Bezier]] handles into plain keys |
| Optimize Animation Size | **off** | When on, channels whose keys are all identical can be removed, so a bone that holds still in a clip becomes un-keyed. In Roblox an un-keyed joint lets lower-priority tracks (or rest) show through, which is a different result |
| Set all glTF Animation starting at 0 | on | Clips start at time 0 in Roblox |
| One armature per file | yes | Project rule; multi-armature exports confuse the "all actions" mode and the importer's rig detection |

A ready-made call, as the project used it (the keyword names drift across Blender versions; the project's exporter dropped unknown keywords and retried):

```python
import bpy
rig = bpy.data.objects["Boss_Rig"]          # the armature; select it and its meshes first
kw = dict(
    filepath="Boss.glb", export_format='GLB', use_selection=True,
    export_yup=True, export_apply=False,
    export_materials='EXPORT', export_image_format='AUTO',
    export_skins=True, export_all_influences=False,
    export_animations=True, export_animation_mode='ACTIONS',
    export_anim_single_armature=True, export_reset_pose_bones=True,
    export_force_sampling=True, export_frame_step=1,
    export_optimize_animation_size=False, export_anim_slide_to_zero=True,
    export_def_bones=False, export_morph=False,
)
rig.animation_data.action = None            # export from rest, not from the last edited clip
for pb in rig.pose.bones:
    pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
bpy.ops.export_scene.gltf(**kw)
```

### The partial-clip problem (GLB)

The glTF exporter writes a channel for **every bone** in every animation (with sampling on). That is right for full-body clips and wrong for layers: an "Inflate" clip that should only move the belly, or a rotor spin that should only turn a rotor, will key every other bone at its rest pose too. Played over locomotion at a higher priority, it **pins the body**.

The project fixed this after export: actions carried a custom property listing the bones they own, and a small Python step opened the GLB, removed the other channels (and their samplers) from those animations, and rewrote the JSON chunk in place. The binary data stays; only references change. If you do not want to post-process, author layer clips on a separate armature or build them in Studio from exported data with only the joints you want (see [[Animation Data from Blender to Roblox]]).

## 4. FBX export: settings and the reasons for them

Roblox's documented Blender FBX steps, with the reasoning:

| Setting | Value | Reason |
|---|---|---|
| Path Mode | Copy, with Embed Textures on | Textures travel inside the file |
| Transform > Apply Scalings | FBX Unit Scale | Roblox docs' recommended scale handling. Alternatives in the docs: Transform Scale 0.01, or scene Unit Scale 0.01 (which the docs warn can cause camera and modifier problems) |
| Forward / Up | Z Forward, Y Up (Roblox Blender guide) | Matches the importer's World Forward "Front" / World Up "Top" |
| Armature > Add Leaf Bones | **off** | Otherwise every chain gets an extra `_end` bone in Roblox |
| Armature > Only Deform Bones | on when you have control bones | Same reason as glTF |
| Bake Animation | off unless exporting animation (Roblox docs) | Static exports stay small |
| Bake Animation > Simplify | **0** when exporting clips you care about | The default simplifies curves (lossy); fast motion, contact frames and snaps can be smoothed away |
| Key All Bones | on | Every bone gets keys, so a still bone stays still instead of being un-keyed |
| NLA Strips / All Actions | off for a single clip (Roblox's dynamic-head guide says to uncheck them, and Force Start/End Keying) | One take per file is what the documented path expects |
| Custom Properties | on for dynamic heads | The head's `Frame0..N` and `RootFaceJoint` mappings are custom properties |

Two FBX-only pitfalls:

- **The 100x scale family.** A model 100 times too big or too small after import is always the unit chain (Blender scene units, FBX unit scale, the importer's Scale Unit). Fix it at export with Apply Scalings, never by scaling the model in Studio: scaling in Studio scales parts but clip translations stay in the old units, so root motion and offsets come out wrong.
- **Bone axis options.** Changing Primary/Secondary Bone Axis away from the defaults changes every bone frame in the file, which changes what every rotation key means. Leave them at the defaults unless a target tool requires otherwise, and never change them mid-project.

## 5. Measured behaviour on the Studio side (reference project)

| Observation | Route | Consequence |
|---|---|---|
| Model turned 180 degrees about Y on import | GLB | Author facing -Y; no yaw fix needed. See [[Blender Armature and Bone Roll Conventions]] |
| Imported clips played the whole body turned 180 degrees from the root | GLB with animations | Every imported clip needs a data fix. See [[Enemy Import Axis Fix]] |
| One boss's root forward/back travel mirrored | GLB with animations | Fixed by flipping the LowerTorso pose's Z; check root motion after every import |
| Flat material base colours lost | GLB | Re-apply colours from a manifest, or use textures or vertex colours |
| Every GLB lands as a top-level Workspace model named `Scene` | GLB | Find imports by content, never `FindFirstChild("Scene")` |
| Kit meshes arrive named `<Name>__exp` | GLB | Rename in the prepare step |
| Clips land in `ServerStorage.RBX_ANIMSAVES`, under a folder named after the model (`Scene`) | GLB with animations | Rename and move them to your clip folders |
| Axis drift 0.000 on 156 armour meshes, no yaw fix | FBX via upload add-on | The add-on route preserved axes |
| Uploaded MeshParts arrived with a rotated `PivotOffset` | FBX via upload add-on | Set `PivotOffset = CFrame.new()` on each before `GetBoundingBox`, `ScaleTo` or `PivotTo` |

## 6. One animation per file, or many?

The Roblox modeling specification says "only one animation track can be exported per mesh or model. Export each animation separately." The reference project nevertheless exported creature GLBs with every Action as a named animation (23 clips for one boss) and found the clips under `RBX_ANIMSAVES` after import. And in 2026 Roblox announced an animation import dialog with an "Animation Track Selection" option to choose which track of a file to bring into the editor. Both statements can be true: the 3D Importer may bring several animations from a glTF, while the documented avatar path and the editor import one take at a time. Test with your Studio version; record the result in [[Open Questions]] if it differs.

If you build clips from your own exported data instead (recommended for anything that needs markers, thinning or exact easing), the question disappears.

## 7. Pre-export checklist

- [ ] Transforms applied (scale 1, rotation 0) on armature and meshes; root at the origin.
- [ ] Faces -Y, final stud height, feet on Z = 0.
- [ ] Weights limited to 4 and normalised; no zero-weight vertices.
- [ ] Control bones non-deform; deform-only export when they exist.
- [ ] glTF: +Y Up, Always Sample, Reset pose bones on, Optimize Animation Size off, vertex colour mode chosen deliberately.
- [ ] FBX: Apply Scalings FBX Unit Scale, Add Leaf Bones off, Simplify 0 for clips, Key All Bones on, Custom Properties on for heads.
- [ ] Partial clips handled (stripped channels or built separately).
- [ ] Marker table exported next to the file.
- [ ] A calibration clip passes once per route ([[Blender Armature and Bone Roll Conventions]] section 8).

## Common mistakes

| Mistake | On screen | Fix |
|---|---|---|
| Leaf bones left on (FBX) | Extra `_end` bones; clip joint counts off; bone-count budgets blown | Add Leaf Bones off |
| Optimize Animation Size on (glTF) | A still limb in one clip is overridden by another track in game | Turn it off, or key all bones explicitly |
| Simplify left at default (FBX) | Snappy hits feel soft; contact frames drift | Simplify 0 |
| Exporting while a clip is active | Rest pose in Roblox is a frame of that clip | Clear the active action and reset pose bones before export |
| Vertex colours not wired to material (glTF) | Model imports grey | "Use Vertex Color: Active" or wire them in |
| Scaling the import in Studio to fix units | Root motion and offsets wrong after scaling | Fix scale at export |

## See also

[[Rigging in Blender]] · [[Importing Models and Rigs]] · [[3D Importer Settings Reference]] · [[Animation Data from Blender to Roblox]] · [[Enemy Import Axis Fix]] · [[Pipeline - Importing Animated Enemies]] · [[Weight Painting and Skinning for Roblox]] · [[Open Questions]]

## Connected notes
<!-- auto-links:start -->
[[Exporting and Validating Models for Roblox]] · [[Moon Animator and Third-Party Tools]] · Skill - Roblox Asset Import · [[Facial Animation and Dynamic Heads]] · Other Modeling Tools - Maya Max ZBrush MagicaVoxel · Modeling in Blender for Roblox · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[AI Pitfalls - Assets and Import]] · [[Bones and Skinned Meshes]] · [[Creature Rig Conventions]] · [[Blender Workflow for Roblox Creators]] · [[Retargeting Animations Between Rigs]] · [[Layered Clothing Cages and Animation]] · [[Weapon Design Rig Builder]] · [[Animation Editor Advanced]] · [[LihFolk R15 Keyframe Pipeline]] · [[Custom Characters and StarterCharacter]]
<!-- related:end -->
