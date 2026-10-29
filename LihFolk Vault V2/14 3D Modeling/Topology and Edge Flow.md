---
tags: [modeling, topology, edge-flow, deformation, rigging-prep, blender, type/guide, area/modeling, level/intermediate, area/animation]
---
# Topology and Edge Flow

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Obsessing over topology on static props -> Shading and triangle count are what matter there
> - Avoid: Even density everywhere -> Dense at bends, sparse on flats
> - Avoid: Poles on joints and face corners -> Move poles to flat, rigid areas
> - Purpose decided: static, rigid segmented, or skinned.
> - Skinned: 3+ loops at hinges, 5+ at shoulders and hips, rings around eyes and mouth.
> - Poles on flat, rigid areas.
>
> Cost: TL;DR ~150 tok · whole note ~3.5k tok. Read more: ## 3. Loops for deformation: joint by joint · ## 6. Blender tools for topology work · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Topology is how the faces of a mesh are connected: which vertices share edges, where the loops run, where triangles and poles sit. Two meshes with the same silhouette can behave completely differently: one bends cleanly at the elbow and shades smoothly, the other collapses into a crease and shows streaks. Edge flow is the direction those loops travel across the surface, and for anything that deforms it should follow the way the surface moves.

This note explains when topology matters (and when it does not, which is more often than tutorials admit for Roblox), the rules for quads, triangles and poles, loop layouts for each kind of joint on a Roblox character or creature, face topology, and Blender tools and scripts to find and fix problems.

---

## 1. When topology matters, and when it does not

| Mesh | Does topology matter? | What matters |
|---|---|---|
| Static prop, flat-shaded or [[weighted normals]] | Little | Shading (no long thin triangles on smooth areas), triangle count, clean silhouette |
| Static prop that will be subdivided for a high-poly bake | Yes | All quads, support loops, no poles on curved areas |
| Rigid segmented character or creature (one MeshPart per body part) | Little inside each piece | Each piece closed; good cuts at joints |
| Skinned character, creature, tail, cloth | **A lot** | Loops at joints, even density where it bends, poles away from bends |
| Mesh that will be decimated for LOD | Some | Even density decimates gracefully |
| Mesh to be UV-unwrapped with seams along loops | Some | Clean loops make clean seams |

Roblox's own guidance is "use quads where possible, avoid n-gons" (Docs), and every mesh is triangulated on import anyway. So the reasons to care are **deformation**, **shading** and **your own editing speed**, not the engine.

---

## 2. Quads, triangles, n-gons and poles

### Quads

Four-sided faces form **loops**: you can select a ring of edges all the way round a limb with Alt+click, slide it, cut a new one (Ctrl+R). Loops are the unit of deformation and of control. Subdivision surfaces assume quads.

### Triangles

- Fine on flat areas and in the final export (everything becomes triangles).
- Fine as a **termination**: a triangle that ends a loop where density changes.
- Bad in **areas that bend or subdivide**: triangles break loops, and subdivision makes small pinches at them.
- **Long thin triangles** (slivers) cause shading streaks with smooth shading and precision problems in normal map bakes. Avoid aspect ratios worse than about 1:8 on curved surfaces (rule of thumb).

### N-gons

Faces with five or more sides. Acceptable on a flat, non-deforming, non-subdivided face (a big flat panel) because the triangulation of a flat face cannot affect shading. Problems elsewhere: unpredictable triangulation on curved surfaces, broken loops, bad subdivision. Before export, either triangulate yourself or check with *Select > Select All by Trait > Faces by Sides* (more than 4).

### Poles

A pole is a vertex where the number of edges is not 4.

- **3-pole (N-pole)**: three edges; appears where a loop turns a corner (the corner of a cube).
- **5-pole (E-pole)**: five edges; appears where loops branch or density changes.
- **6+ poles**: usually a sign of a fan or a boolean; avoid.

Poles are unavoidable on closed shapes (a cube has eight 3-poles). The rule is **where** to put them: on flat areas, inside features that do not bend (the middle of a cheek, the back of the hand, the top of the skull), never on a joint crease, the corner of a mouth or eyelid, or the centre of a shoulder.

### Density

Polygons should be **dense where the shape curves or bends** and **sparse where it is flat and rigid**. A knee needs loops; the flat of a shin does not. Even density everywhere wastes triangles; too sparse at bends gives creases.

---

## 3. Loops for deformation: joint by joint

These layouts assume a skinned mesh driven by bones, as in [[Bones and Skinned Meshes]] and [[Weight Painting and Skinning for Roblox]]. Roblox allows at most 4 bone influences per vertex (Docs), which is plenty if the loops are right.

### Hinge joints: elbow, knee, finger knuckles

- **Minimum three loops** across the joint: one at the pivot, one just above, one just below. With fewer, the joint folds like paper and loses volume.
- **Wedge on the inside**: bring the inner loops closer together than the outer ones, so the inside of the bend has less geometry to crush and the outside more to stretch. On a knee, the back of the knee loops converge; the kneecap has more.
- For stylised low-poly characters, three loops is still the minimum; you save triangles elsewhere.

### Ball joints: shoulder, hip

The shoulder moves in every direction and is the hardest area on a character.

- **Loops around the shoulder** in a ring that follows the deltoid, not straight vertical cuts. Five or more loops between the armpit and the top of the shoulder.
- The **armpit** needs enough edges to stretch when the arm rises: model in an A-pose (arms about 45 degrees down) so the armpit is neither crushed nor overstretched in common poses.
- **Hip loops** run diagonally from the crotch up over the hip bone, so the leg can lift forward without the front of the hip collapsing.

### Twisting joints: forearm, neck, spine

- A twist spread over one loop gives the "candy wrapper" collapse: the mesh pinches to a point.
- Spread twist over **several loops along the limb**, and in rigs distribute it with twist bones or with weights blended along the forearm. Roblox's advanced R15 body specification allows extra optional bones; standard R15 parts do not twist within a part. See [[Elbow Poles Swivel and Joint Limits]].

### Spine and belly

- Horizontal loops around the torso, evenly spaced, so bending forward compresses evenly.
- Extra loops at the waist if the character crouches or twists a lot.

### Necks

- Several horizontal loops; the neck rotates and bends. Poles kept on the back of the head or under the jaw, not on the throat.

### For Roblox R15 bodies specifically

Standard R15 bodies are **15 separate meshes** (`<Part>_Geo`), each skinned to its own bones, limbs capped to be watertight when separated (Docs, see [[R15 Rig Anatomy and Attachments]]). That changes the topology job:

- Each part ends in a **closed cap** at the joint. Give the cap a clean grid or a ring of quads with a small centre fan, not a single n-gon.
- The **border loops** of neighbouring parts should match in vertex count and position where possible, so the joint looks continuous at rest.
- Deformation happens mostly at the cut (the parts rotate relative to each other) plus skinning within each part, so loops near each end of a part matter most.

---

## 4. Face topology

Faces deform the most and are read the closest. Standard layout:

- **Eye rings**: concentric loops around each eye socket (at least 2-3 rings), so lids can close and the eye can squint.
- **Mouth rings**: concentric loops around the mouth, so it can open, smile and pucker.
- **Nasolabial loop**: a loop from the side of the nose down around the mouth corner, which forms the smile fold.
- **Poles** placed between the eye and mouth rings, on the cheek, where they do the least harm.
- The **mouth line** (between the lips or jaw plates) should be a clean edge loop so the jaw can open without tearing.

For stylised or blocky faces this reduces to: one ring around each eye, one around the mouth, a clean mouth line. For [[FACS]]-driven dynamic heads, follow Roblox's head specification and the facial topology guidance in [[Facial Animation and Dynamic Heads]].

---

## 5. Topology for shading and baking

Even static meshes need some topology discipline:

- **Support loops** keep corners sharp on subdivided high polys ([[Hard-Surface Modeling]]).
- **No slivers on curved smooth surfaces**: route edges after booleans.
- **Triangulate before baking** and export the same triangulation, so the baked normal map's tangent space matches the engine's ([[Normal Maps and Detail Baking]]).
- **Hard edges on UV seams**: see [[Modeling Fundamentals for Games]].
- **Even quads on cylinders**: lengthwise segments roughly square to the circumference segments, or texture details stretch.

---

## 6. Blender tools for topology work

| Tool | Where / key | Use |
|---|---|---|
| Loop cut and slide | Ctrl+R | Add loops at joints |
| Edge slide | G G | Move a loop along the surface without changing shape |
| Select loop / ring | Alt+click / Ctrl+Alt+click | Check that loops run where you think |
| Dissolve edges / vertices | X > Dissolve | Remove loops without leaving holes |
| Knife | K | Route edges, fix n-gons |
| Rotate edge | Edge menu > Rotate Edge CW/CCW | Flip a quad's diagonal; fix a triangle pair |
| Triangles to quads | Alt+J | Clean up imported or decimated meshes |
| Grid Fill | Face menu | Fill a hole (a limb cap) with a quad grid |
| Bridge Edge Loops | Edge menu | Join two loops (attach a limb) |
| Poke / Inset / Extrude | | Building caps and features |
| Faces by Sides | Select > Select All by Trait | Find n-gons and triangles |
| Non Manifold | Select > Select All by Trait | Find holes and bad edges |
| Mesh Analysis overlay | Overlays (edit mode) | Visualise distortion, sharpness, intersections |
| Retopology overlay | Overlays | See a new mesh over a sculpt (see [[Retopology and Decimation]]) |

### A topology report script

```python
# Blender: topology report for the active mesh (run in Object mode).
import bpy, bmesh

obj = bpy.context.active_object
bm = bmesh.new()
bm.from_mesh(obj.data)

tris  = [f for f in bm.faces if len(f.verts) == 3]
quads = [f for f in bm.faces if len(f.verts) == 4]
ngons = [f for f in bm.faces if len(f.verts) > 4]
poles = {}
for v in bm.verts:
    n = len(v.link_edges)
    if n != 4 and not v.is_boundary:
        poles[n] = poles.get(n, 0) + 1
non_manifold = [e for e in bm.edges if not e.is_manifold]
slivers = []
for f in bm.faces:
    lengths = [e.calc_length() for e in f.edges]
    if min(lengths) > 0 and max(lengths) / min(lengths) > 8:
        slivers.append(f.index)

report = {
    "faces": len(bm.faces), "triangles_after_export": sum(len(f.verts) - 2 for f in bm.faces),
    "tris": len(tris), "quads": len(quads), "ngons": len(ngons),
    "poles_by_valence": poles, "non_manifold_edges": len(non_manifold),
    "sliver_faces_over_1_to_8": len(slivers),
}
bm.free()
print(report)
```

High n-gon or sliver counts on a deforming mesh, 6+ poles anywhere, or any non-manifold edges (holes, which Roblox's "watertight" rule forbids) are things to fix before rigging.

---

## 7. Diagnosing deformation problems

Pose the mesh before committing to topology: rig a quick armature (or use Roblox's R15 test rig in Blender) and rotate each joint to its extremes.

| What you see when posed | Cause | Fix |
|---|---|---|
| Elbow or knee folds flat, loses volume | Fewer than 3 loops; loops evenly spaced | Add loops; wedge inner ones closer |
| Shoulder collapses when arm rises | Vertical loops; arms modelled down | Ring loops around the deltoid; remodel in A-pose |
| Forearm twists to a point | Twist on one loop | Spread twist across loops and weights |
| Dent or bump on a joint | Pole on the crease | Move the pole onto a flat area |
| Streaks across a smooth surface | Slivers or n-gons | Route edges; quads |
| Mouth tears when jaw opens | No clean mouth line | Edge loop along the lips |
| Visible gap between R15 parts at rest | Border loops do not match | Match vertex counts and positions at cuts |

Many "rigging bugs" are topology bugs. Before blaming weights in [[Weight Painting and Skinning for Roblox]], check the loops.

---

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Obsessing over topology on static props | Hours wasted | Shading and triangle count are what matter there |
| Even density everywhere | Wasted triangles, still weak at joints | Dense at bends, sparse on flats |
| Poles on joints and face corners | Dents and pinches | Move poles to flat, rigid areas |
| N-gons on curved surfaces | Unpredictable triangulation, shading errors | Quads, or triangulate deliberately |
| Booleans on deforming meshes | Pinching, streaks | Model features into the loops |
| No posing test before UVs | Topology redone after UVs | Pose test first |

## Checklist

- [ ] Purpose decided: static, rigid segmented, or skinned.
- [ ] Skinned: 3+ loops at hinges, 5+ at shoulders and hips, rings around eyes and mouth.
- [ ] Poles on flat, rigid areas.
- [ ] No n-gons on curved or deforming areas; no slivers on smooth surfaces.
- [ ] No non-manifold edges (watertight).
- [ ] Posed to extremes in Blender before UVs and weights.

## See also

[[Organic and Creature Modeling]] · [[Retopology and Decimation]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Rigging in Blender]] · [[Weight Painting and Skinning for Roblox]] · [[Bones and Skinned Meshes]] · [[Hard-Surface Modeling]] · [[UV Unwrapping]] · [[Normal Maps and Detail Baking]]

## Connected notes
<!-- auto-links:start -->
[[Skinning Weights]] · [[Blender Workflow for Roblox Creators]] · Voxel Characters - Proportions Joints and Rigging · Links - Topology · Faceted Low-Poly - Flat Normals and Facet Size · Two-Bone IK Math
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Voxel Characters - Proportions Joints and Rigging]] · [[Procedural Creatures - Fused Shells, Quad Cages and Faceting]] · [[Curve-Based Modelling in Blender for Roblox]] · [[UGC Avatar Items and Accessories]] · [[Mesh Gates for Generated Models - Symmetry, Seating and Caps]] · [[Exporting and Validating Models for Roblox]] · [[Low-Poly and Stylized Modeling]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Modeling Weapons and Props]]
<!-- related:end -->
