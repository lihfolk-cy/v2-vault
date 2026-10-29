---
tags: [modeling, blender, workflow, modifiers, export, python]
---
# Blender Workflow for Roblox Creators

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Mixing FBX scale methods -> One method: FBX Unit Scale, or use GLB
> - Avoid: Front modelled toward +Y -> Front toward -Y
> - Avoid: Mirror without Clipping -> Clipping + Merge on
> - Units set (None, or Metric with 1 m = 1 stud) and never changed mid-project.
> - Character proxy and 1-stud grid in the scene.
> - Front toward -Y; origin placed per asset type.
>
> Read more (22 KB note): ## 1. Scene setup once, saved as your startup file · ## 3. Modifiers: non-destructive modelling · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Blender is the default modelling tool for Roblox creators: free, scriptable, and the one Roblox's own guides are written for. This note is a working setup and a modifier-by-modifier guide for building game meshes that arrive in Studio at the right size, facing the right way, with the right pivots and shading. It goes deeper than the overview in [[Modeling in Blender for Roblox]], and it stops at the mesh: unwrapping, texturing and export validation have their own notes ([[UV Unwrapping]], [[Texturing and PBR Baking]], [[Exporting and Validating Models for Roblox]]). Rigging is in the Animation section ([[Rigging in Blender]]).

Blender facts below were checked against the Blender manual (a recent 4.x/5.x edition); Roblox facts against the Creator Hub, as of October 2026. Menu locations move between Blender versions; operator names are more stable, so the Python is given too.

---

## 1. Scene setup once, saved as your startup file

### Units: 1 Blender unit = 1 stud

Roblox's Blender guide says to set *Scene Properties > Units > Unit System* to **None** and *Rotation* to **Degrees** (Docs), so a Blender unit is simply a unit and you think in studs. The reference project instead left Metric on and treated 1 metre as 1 stud; both work as long as you export correctly, because:

- **GLB/glTF** is metres by spec, and Studio's importer with *Scale Unit = Stud* brings 1 unit in as 1 stud. Roblox's guide notes glTF needs no extra scaling configuration (Docs).
- **FBX** is centimetre-based. Roblox's recommended Blender setting is *Transform > Apply Scalings = FBX Unit Scale*, every other scale at 1.0 (Docs). Alternatives in the same guide (export *Scale 0.01*, or scene *Unit Scale 0.01*) work but cause other problems, so do not mix methods.

Never change *Unit Scale* to "fix" a size problem mid-project. It changes how modifiers with distances (Bevel width, Weld distance, Solidify thickness) are interpreted and breaks older files.

### Axes

Blender is Z-up; Roblox is Y-up. Exporters convert this for you:

- GLB: *+Y Up* on (default). The glTF front is +Z, and Studio then turns a GLB 180 degrees about Y (measured in the reference project), so a model whose front faces **Blender -Y** lands facing **Roblox -Z**, which is a part's `LookVector`. Use -Y as "front" in Blender and you never have to rotate in Studio. Details: [[Enemy Import Axis Fix]].
- FBX: Roblox's guide sets *Forward: Z Forward*, *Up: Y Up* on export and *World Forward: Front*, *World Up: Top* on import (Docs). Test the result with a marked front (an arrow mesh) once, and keep the settings in an export preset.

### A startup scene that pays for itself

Save (*File > Defaults > Save Startup File*) a scene containing:

- A **character proxy** in its own collection, disabled for export: the R15 blocky rig at your game's scale (5.2 studs as stored, about 5.5 in game; the reference project used 1.6x, about 9 studs). See [[R15 Rig Anatomy and Attachments]] for the part sizes.
- A **1-stud grid** and snapping set to *Increment* with *Absolute Grid Snap* on (the manual: snaps "to the viewport grid instead of moving by increments of the grid cell size"). Essential for [[Modular Environment Kits]].
- Statistics overlay on (*Overlays > Statistics*) so the triangle count is always visible.
- *Face Orientation* overlay one click away: blue = front, red = back. Red visible from outside means flipped normals.
- Viewport clip start/end suited to studs (0.01 to 10,000) so big hub pieces do not clip.

```python
# Blender: one-time scene setup for Roblox work (run in the Scripting tab).
import bpy, math

scene = bpy.context.scene
scene.unit_settings.system = 'NONE'          # Roblox guide: Unit System None, 1 unit = 1 stud
scene.unit_settings.system_rotation = 'DEGREES'

ts = scene.tool_settings
ts.use_snap = False                          # toggle with Shift+Tab when needed
ts.snap_elements = {'INCREMENT'}
ts.use_snap_grid_absolute = True             # Absolute Increment Snap (snap to the grid itself)

for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        space = area.spaces.active
        space.overlay.show_stats = True
        space.clip_start, space.clip_end = 0.01, 10000
```

---

## 2. The modelling toolkit you will use daily

| Key | Tool | What it is for in game work |
|---|---|---|
| Tab | Edit / Object mode | |
| 1 / 2 / 3 (edit mode) | Vertex / edge / face select | |
| G, R, S (+ X/Y/Z, + Shift+axis to exclude) | Move, rotate, scale | Type numbers for exact studs |
| E | Extrude | Most forms start here |
| I | Inset faces | Panels, rims, sockets |
| Ctrl+R | Loop cut | Support loops, deformation loops |
| Ctrl+B / Ctrl+Shift+B | Bevel edges / vertices | Chamfers |
| K | Knife | Cutting custom edges, fixing n-gons |
| F | Fill / make face | Closing holes |
| M | Merge (at centre, by distance) | Cleaning duplicates |
| Alt+click | Select loop | Edge flow work |
| Ctrl+A (object) | Apply transforms | Always before export |
| Shift+S | Snap menu (cursor to selected, selection to cursor) | Setting origins |
| Ctrl+Shift+Alt+C | Set Origin menu (newer versions also under *Object > Set Origin*) | Pivots |
| Shift+D / Alt+D | Duplicate / linked duplicate | Linked duplicates share one mesh: edit one, all change |
| H / Alt+H | Hide / reveal | |
| / (numpad) | Local view | Focus on one piece |

Two habits from production:

- **Type numbers.** `G Z 0.5 Enter` moves exactly half a stud. Kit pieces that are "about right" do not tile.
- **Use linked duplicates (Alt+D) for repeated parts** while modelling (bolts, lamps, pillars). Edit one, all update. Make them single-user only when you need to.

---

## 3. Modifiers: non-destructive modelling

Modifiers let you keep the simple "cage" editable while Blender generates the final shape. The rule is to keep them live as long as possible and apply them in a controlled order right before optimisation.

### Mirror

Models one half, generates the other. From the manual:

- **Axis**: the axis perpendicular to the mirror plane (X mirrors left/right on a character facing -Y).
- **Bisect**: if geometry crosses the plane, cut it and keep one side.
- **Clipping**: vertices cannot cross the mirror plane in Edit mode, and vertices that reach it within *Merge Distance* snap to it. Turn this on for every symmetric model, or you will get a seam or overlapping faces down the middle.
- **Merge** + **Merge Distance**: welds the centre line.
- **Mirror Object**: mirror around an empty instead of the object's own origin (useful when the origin is not at the centre).

Mirror needs the object's origin on the symmetry plane (or a Mirror Object). A character mirrored around an origin at its foot will mirror into the wrong place.

**Gotcha:** asymmetric details (a scar, one pauldron) go on a separate object or are added after applying Mirror. Applying it early "to add one asymmetric thing" loses the half-model workflow for everything else.

### Array

Repeats geometry: fences, chains, stair steps, ladder rungs, spiral columns.

- **Relative offset**: 1.0 = one object width apart (gapless tiling).
- **Constant offset**: an exact distance in units; use this for grid-snapped kit pieces.
- **Object offset**: the transform of an empty is applied per copy, so rotating the empty makes spirals and circular arrays (a ring of 8 lamps: empty rotated 45 degrees, count 8).
- **Merge**: welds touching ends, so an arrayed rail becomes one continuous mesh.
- **Fit type**: Fixed count, Fit length, or Fit curve. Pair with a **Curve modifier** for rails, cables or chains that follow a path.

Arrays multiply triangles silently. A 600-triangle chain link arrayed 40 times is 24,000 triangles and over the per-mesh limit.

### Boolean

Cuts or joins shapes: window holes, sockets, vents, engraved symbols. Operations: Intersect, Union, Difference. Solvers (manual):

| Solver | Behaviour | Use |
|---|---|---|
| **Exact** | Best results, full support for overlapping geometry, much slower | Default for final cuts |
| **Float** | Fast, but does not support overlapping geometry | Quick blockouts |
| **Manifold** (newer versions) | Usually fastest, only works on manifold meshes | Clean closed cutters on clean closed bases |

Booleans make **n-gons and long thin triangles** around the cut. That is fine for a static prop that will be triangulated and flat-shaded, and bad for anything subdivided or deformed. Clean up after applying: add loops to route edges away from the cut, dissolve stray vertices, and check shading. See [[Hard-Surface Modeling]] for the full boolean workflow, including keeping cutters as hidden objects so the cut stays editable.

### Bevel

Rounds or chamfers edges. The single most important modifier for hard-surface work. Key options (manual):

- **Width** and **Width Type** (Offset, Width, Depth, Percent, Absolute).
- **Segments**: 1 = chamfer, 2-3 = rounded.
- **Limit Method**: *None* (every edge), *Angle* (only edges sharper than the threshold: "intended to allow you to bevel only the sharp edges of an object without affecting its smooth surfaces"), *Weight* (only edges with bevel weight), *Vertex Group*.
- **Harden Normals**: adjusts the bevel's normals so flat faces stay flat and the bevel shades smoothly into them. Needs custom normals; Blender creates the attribute if missing.
- **Clamp Overlap**: stops bevels passing through each other on small parts.

Bevel width must be in real studs on an object with scale 1. On an unapplied 3x scale object, a 0.05 bevel is 0.15 studs on one axis and 0.05 on another.

### Subdivision Surface

Smooths a low cage into a high-poly surface (Catmull-Clark) or simply splits faces (*Simple*). In game work it is used for:

- **High-poly sources for baking** (level 2-3), which never ship. See [[Normal Maps and Detail Baking]].
- **Organic low-poly at level 1**, applied, then cleaned. A 500-face cage becomes 2,000 faces (4,000 triangles): every level multiplies faces by four.
- **Never left live at a high level on a game asset.** Level 3 on a 2,000-face cage is 128,000 faces.

Support loops (extra edges near corners) control how sharp a subdivided corner stays. That technique is in [[Hard-Surface Modeling]].

### Solidify

Gives thickness to a surface: capes, leaves, armour plates, banners. Roblox asks for no zero-thickness geometry (Docs), so a cape is a plane + Solidify, not a plane. *Offset* -1/0/1 picks which side grows; *Even Thickness* keeps corners even. Solidify with *Flip Normals* and a black back-face-culled material is also the **inverted hull outline** used in some voxel and toon styles (see [[Voxel and Blocky Modeling]]): it doubles the triangle count.

### Shrinkwrap

Projects one mesh onto another. Used to fit armour to bodies, decals to curved surfaces, and retopology onto sculpts. See [[Retopology and Decimation]].

### Decimate

Reduces triangles. *Collapse* ratio is "the ratio of faces to keep" computed on triangles; *Un-Subdivide* reverses grid subdivision; *Planar* dissolves near-flat regions (manual). Full guide in [[Retopology and Decimation]].

### Smooth by Angle and Weighted Normal

- **Smooth by Angle** (Blender 4.1 and later, replacing the old mesh "Auto Smooth" setting) marks edges sharp above an angle. *Object > Shade Auto Smooth* adds it. The Python operator is `bpy.ops.object.shade_auto_smooth(angle=...)` (default 30 degrees).
- **Weighted Normal** makes custom normals weighted by face area (or angle), so big flat faces stay flat and small bevels absorb the shading. Pair it with Bevel's *Harden Normals* or *Face Strength*. The standard low-poly hard-surface shading recipe.

### Triangulate

Converts quads and n-gons to triangles: *Quad Method* (Beauty, Fixed, Fixed Alternate, Shortest Diagonal, Longest Diagonal), *N-gon Method* (Beauty, Clip), *Minimum Vertices* (manual). Every face is triangulated on export anyway; triangulating yourself means the split is the one you saw while baking normal maps, so the bake matches. Put it last in the stack, after Weighted Normal is applied, or recheck shading after.

### A stack order that works

```
Mirror           (symmetry first, on the cage)
Array / Curve    (repetition)
Boolean          (cuts, cutters hidden)
Bevel            (limit by angle or weight, harden normals)
Subdivision      (only for high poly or level-1 organics)
Solidify         (thin surfaces)
Smooth by Angle  (or Weighted Normal)
Triangulate      (last, optional)
```

Changing order changes results: Bevel after Subdivision bevels thousands of edges; Mirror after Bevel leaves a bevelled seam down the middle.

---

## 4. Applying everything and checking

When the asset is ready to optimise, collapse it to a plain mesh:

1. Duplicate the object (keep the live version in a hidden "Source" collection: you will want it back).
2. On the duplicate, apply modifiers top to bottom (*Ctrl+A* over each modifier, or *Object > Convert > Mesh*, which applies the whole visible stack).
3. Apply rotation and scale (*Object > Apply > Rotation & Scale*).
4. *Mesh > Clean Up > Merge by Distance* (removes duplicate vertices from mirrors and arrays), then *Mesh > Normals > Recalculate Outside*.
5. Check the triangle count, face orientation and shading.

```python
# Blender: collapse selected objects to export-ready meshes, report triangles.
import bpy, bmesh

def bake_down(obj):
    """Apply all modifiers and rotation/scale; return triangle count."""
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')                       # applies the visible modifier stack
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)   # merge by distance
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)           # recalc outside
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return tris

report = {}
for obj in [o for o in bpy.context.selected_objects if o.type == 'MESH']:
    report[obj.name] = bake_down(obj)
print(report, "over 20k:", [n for n, t in report.items() if t > 20000])
```

`object.convert` uses the evaluated (modified) mesh, so it is a one-line "apply all". It also discards custom normals created by the stack in some versions; if your shading relies on Weighted Normal, check shading after converting, or apply the modifiers individually instead.

---

## 5. Origins and pivots

Set them deliberately; they become Roblox pivots (see [[Modeling Fundamentals for Games]] for the per-asset table).

- *Object > Set Origin > Origin to 3D Cursor*: snap the cursor first (*Shift+S > Cursor to Selected* on a hinge edge, or type the cursor location in the N panel).
- *Origin to Geometry* centres on the median or bounds.
- *Origin to Center of Mass (Volume)* needs manifold geometry with consistent normals (API docs), a free manifold test.

```python
# Put the origin at the bottom centre of the object's bounding box (ground props, kit pieces).
import bpy
from mathutils import Vector

def origin_to_bottom_center(obj):
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    minz = min(c.z for c in corners)
    cx = (min(c.x for c in corners) + max(c.x for c in corners)) / 2
    cy = (min(c.y for c in corners) + max(c.y for c in corners)) / 2
    scene = bpy.context.scene
    old = scene.cursor.location.copy()
    scene.cursor.location = (cx, cy, minz)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    scene.cursor.location = old

for o in bpy.context.selected_objects:
    origin_to_bottom_center(o)
```

On import, keep *Use Imported Pivot* on so each MeshPart's pivot is its Blender origin (Docs).

---

## 6. Organising a file for export

- **One collection per export unit** (one prop, one kit, one creature). Export with *Include > Selected Objects* (FBX: *Limit to Selected Objects*, which Roblox's guide asks for).
- **Names become Instance names.** Name objects the way your scripts will look them up (`Lid`, `Base`, `Hinge_Att`). Avoid dots: the reference project re-uploaded meshes "under dot-free names" after dotted names caused trouble in its tooling.
- **Reserved suffixes**: the importer turns objects named with `_Att` into Attachments, `_OuterCage` / `_InnerCage` into cage objects (Docs). Do not name a normal mesh `Grip_Att` unless you want an Attachment.
- **Keep a "Source" collection** of live-modifier originals, excluded from export.
- **Materials**: one per mesh where possible. Material names do not matter to Roblox; textures do (see [[Texturing and PBR Baking]]).

---

## 7. Export: the short version

Full settings and the reasons are in [[Exporting FBX vs GLB]] and [[Exporting and Validating Models for Roblox]]. The short form:

| | GLB (static props, kits, part-rigs) | FBX (avatar items, Roblox-documented route) |
|---|---|---|
| Include | Selected Objects | Limit to Selected Objects |
| Transform | +Y Up | Apply Scalings: FBX Unit Scale; Forward Z, Up Y |
| Modifiers | Apply them yourself first | Apply them yourself first |
| Armature | (if any) one per file | Add Leaf Bones **off** |
| Textures | Packed | Path Mode Copy + Embed Textures |
| Animation | Off unless exporting clips | Bake Animation off unless exporting clips |

```python
# Export the selected objects as GLB for Studio's 3D Importer.
import bpy
bpy.ops.export_scene.gltf(
    filepath="//export/Crate.glb", export_format='GLB',
    use_selection=True, export_yup=True, export_apply=True,   # apply modifiers at export
    export_animations=False,
)
```

```python
# FBX with Roblox's documented settings.
import bpy
bpy.ops.export_scene.fbx(
    filepath="//export/Crate.fbx", use_selection=True,
    apply_scale_options='FBX_SCALE_UNITS',                     # "FBX Unit Scale"
    axis_forward='Z', axis_up='Y',
    add_leaf_bones=False, bake_anim=False,
    path_mode='COPY', embed_textures=True,
)
```

(`//` is a path relative to the saved .blend file.) In Studio: *Scale Unit Stud*, World Forward Front, World Up Top; *Insert Using Scene Position* if you want Blender placement preserved.

### Uploading straight from Blender

Roblox publishes an official Blender add-on (a reference implementation of Open Cloud) that uploads selected meshes or collections as **packages**; re-uploading updates the same package and its id is stored in the object's custom properties (Docs, the add-on's repository; needs Blender 3.2+). The reference project used this route for hub kits (one 149-mesh hub package) and learned:

- The add-on's login token can be revoked silently: it still reports logged in, uploads fail with "Token has been revoked". Log out and in.
- Do not block Blender's main thread (for example `time.sleep` in a script) while an upload runs: it stalls the add-on's async loop.
- After inserting uploaded meshes, check pivots: the project had to clear pivot offsets the uploader wrote, or parts came in rotated.

Automation of uploads is covered in [[Asset Upload Automation with Open Cloud]] and [[Blender Automation with Python]].

---

## 8. Running Blender headless

For batch work (export 80 kit pieces, render 150 icons), run Blender without a UI:

```
blender -b MyKit.blend -P export_all.py -- --out D:/exports
```

`-b` is background mode, `-P` runs a script, arguments after `--` reach the script through `sys.argv`. The reference project built most of its creatures, hub pieces, armour and weapons this way: each asset was a Python file that generated geometry procedurally, so a design change was a parameter change and a re-run, not an hour of clicking. That approach is described in [[Blender Automation with Python]].

Windows gotcha (Measured): Blender and other native programs failed to open files whose full path was over 260 characters. Keep project paths short (`D:\art\kit\`), especially for temp folders.

---

## Common mistakes

| Mistake | Symptom in Studio | Fix |
|---|---|---|
| Mixing FBX scale methods | Model 100x too big or small | One method: FBX Unit Scale, or use GLB |
| Front modelled toward +Y | Model faces backwards after GLB import | Front toward -Y |
| Mirror without Clipping | Seam or overlap down the centre | Clipping + Merge on |
| Bevel on unapplied scale | Uneven bevel widths | Apply scale first |
| Subdivision left live at level 2+ | Triangle count explodes on export (export applies it) | Apply level 1 or remove |
| Array left uncapped | Over 20,000 triangles | Count copies x triangles per copy |
| Boolean on a subdivided or deforming mesh | Pinches, shading streaks | Booleans on static, flat-shaded or bevelled parts; clean loops |
| Dotted or duplicate object names | Wrong parts found by scripts | Clean unique names |
| Applying modifiers with no backup | Cannot change the design | Keep a Source collection |
| Forgetting Face Orientation check | Holes in Studio | Overlay on, Recalculate Outside |

## Checklist

- [ ] Units set (None, or Metric with 1 m = 1 stud) and never changed mid-project.
- [ ] Character proxy and 1-stud grid in the scene.
- [ ] Front toward -Y; origin placed per asset type.
- [ ] Modifier stack in a sane order; Mirror clipping on.
- [ ] Live originals kept in a Source collection.
- [ ] Applied: modifiers, rotation, scale; merged by distance; normals outside.
- [ ] Triangle count per mesh under 20,000 and within budget.
- [ ] Names clean; reserved suffixes only where intended.
- [ ] Exported with one consistent preset; checked in Studio once with a marked front.

## See also

[[Modeling Fundamentals for Games]] · [[Hard-Surface Modeling]] · [[Topology and Edge Flow]] · [[Retopology and Decimation]] · [[Exporting FBX vs GLB]] · [[3D Importer Settings Reference]] · [[Enemy Import Axis Fix]] · [[Exporting and Validating Models for Roblox]] · [[Blender Automation with Python]] · [[Blender MCP]] · [[Asset Pipelines]]

## Connected notes
<!-- auto-links:start -->
[[Clean Stylised Shading - Weighted and Custom Normals]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · [[AI 3D Model Generation Outside Roblox]] · [[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Skill - Roblox Asset Import]]
<!-- auto-links:end -->
