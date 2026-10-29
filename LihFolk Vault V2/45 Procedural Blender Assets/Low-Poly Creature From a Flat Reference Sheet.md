---
tags: [blender, python, bmesh, creature, quadruped, low-poly, palette, rigging, skinning, animation, type/reference, area/modeling]
---
# Low-Poly Creature From a Flat Reference Sheet

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Colouring by face index range after a join.
> - Avoid: Linear texture interpolation on a palette.
> - Avoid: Degenerate UVs. Symptom: importer warnings or broken tangents.
>
> Cost: TL;DR ~80 tok · whole note ~4.1k tok. Read more: ## Flat colour from a palette atlas · ## Rig and skinning · ## Common mistakes
<!-- tldr:end -->

![[p45_wolf_side.png]]

A grey wolf built entirely from one Python script run in background Blender, starting from a flat three-view sheet (side, front, back) drawn in a cel-shaded style. The result is one carved, faceted mesh of about 5,000 triangles, coloured flat per face from an 11-colour palette atlas, on a quadruped rig with a 24-frame walk cycle, exported as GLB. The script is `scripts/build_wolf_v3.py`; it is the third full attempt, and the two failures before it taught most of what is in this note.

All numbers are measured in this build (Blender 5.2, October 2026) unless marked rule of thumb.

## What the pipeline does

1. **Trace the body from the side view as lofted cross-sections.** Each section is a superellipse ring whose top, bottom and width come from a table of points read off the sheet.
2. **Add legs and tail as tubes, tufts and ears as cones.** Everything overlaps freely; nothing is welded by hand.
3. **Fuse with a voxel remesh, then smooth.** One watertight mass, no seams where parts meet.
4. **Decimate to about 5k triangles with symmetry on.** Even triangle spread, mirrored left and right.
5. **Carve.** Triangulate, dissolve near-flat neighbours into larger facets with a 5 degree limit, triangulate again. This is what turns a smooth blob into faceted low-poly.
6. **Colour per face from a palette atlas.** Colour regions are tilted ellipsoids in the design frame; a majority filter removes sliver faces; UVs land inside a swatch.
7. **Map the design frame to studs facing -Y,** per [[Creature Rig Conventions]].
8. **Rig, skin with 2 influences, animate a rotations-only walk, export GLB.**

## The design frame and the one mapping function

The whole model is authored in "design units" where +X is forward, +Y is the creature's left, and the head top sits near 1.4. That is the frame the reference sheet is drawn in, so tables of numbers can be read straight off the side view. A single function maps it to Roblox conventions at the very end (1 unit = 1 stud, facing -Y, head top about 8 studs):

```python
S = 5.6                                   # design units -> studs
def T(p): x, y, z = p; return Vector((S * y, -S * x, S * z))
```

Bones are defined in design units too and pass through the same `T`. Keeping one mapping function, applied once, is what stops the classic "the mesh faces -Y but the rig faces +X" mismatch.

## Lofted cross-sections traced from the side view

A ring is a superellipse: exponent 2 is an ellipse, higher values push toward a rounded box. The body uses 2.0; paws use 2.2 so they read as flat-bottomed pads.

```python
def ring(c, u, v, a, b, n=24, e=2.0):
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n; ct, st = math.cos(t), math.sin(t)
        out.append(c + u * (a * math.copysign(abs(ct) ** (2 / e), ct))
                     + v * (b * math.copysign(abs(st) ** (2 / e), st)))
    return out
```

The torso is a table of `(x, top, bottom, half_width)` rows read off the side view at nine stations from rump to chest. `along_x` interpolates the table every 0.015 design units with a softened smoothstep (half linear, half smoothstep) and lofts the rings, capping both ends with a fan:

```python
along_x(bm, [(-0.64, 0.80, 0.62, 0.09), (-0.45, 0.87, 0.50, 0.17),
             (0.10, 0.95, 0.46, 0.195), (0.38, 1.03, 0.68, 0.09)])
```

The head is a second table, the neck a tube. Legs are tubes through four or five points with a radius per point and a flattening factor (0.8 to 0.85) so they are slightly oval, not round. Ears, cheek tufts, elbow tufts, a chest ruff and tail fluff are eight-sided cones with a short collar ring so they blend into the body after the remesh.

## Fuse, smooth, decimate

```python
for kind, kw in (("REMESH", dict(mode="VOXEL", voxel_size=0.009)),
                 ("SMOOTH", dict(factor=0.6, iterations=8))):
    md = tmp.modifiers.new(kind, kind)
    for k, v in kw.items(): setattr(md, k, v)
dense = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
md = tmp.modifiers.new("DEC", "DECIMATE"); md.ratio = 2600 / len(dense.polygons)
md.use_symmetry = True; md.symmetry_axis = "Y"
```

- **Voxel size 0.009 design units** is about 0.05 studs. Coarser voxels melt the ankles and ear tips into stubs; finer ones only cost time, since the decimate throws the detail away.
- **Smooth after remesh** removes voxel stair-stepping before decimation, otherwise the decimator spends triangles preserving noise.
- **Decimate ratio from a target, not a constant.** Dividing a target face count by the dense count gives a stable output size whatever the voxel size. The target of 2,600 collapse faces lands at roughly 5k triangles.
- **Symmetry on the design-frame Y axis**, because the mesh is still in the design frame at this point.

## Carving the facets

```python
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(5), verts=bm.verts[:], edges=bm.edges[:])
bmesh.ops.triangulate(bm, faces=bm.faces[:])
```

The decimated mesh has evenly sized triangles that shade like a smooth blob. Dissolving with a 5 degree limit merges neighbours that are nearly coplanar into larger flat polygons, so the flat areas (flank, skull) become big planes and the curved areas (muzzle, joints) keep small facets. The final triangulate makes the export deterministic. The result reads as hand-carved low-poly; see [[Faceted Low-Poly - Flat Normals and Facet Size]] for why facet size should vary with curvature. Every polygon gets `use_smooth = False`.

## Flat colour from a palette atlas

### Regions as tilted ellipsoids

The sheet's colour areas (pale belly, darker saddle, light muzzle, dark tail tip) are described as ellipsoids in the design frame with a tilt about the lateral axis. A face takes the colour of the last ellipsoid containing its centre; anything near the ground becomes the paw colour.

```python
def blob(p, c, r, tilt=0.0):
    d = p - Vector(c); a = math.radians(tilt)
    x = d.x * math.cos(a) + d.z * math.sin(a); z = -d.x * math.sin(a) + d.z * math.cos(a)
    return (x / r[0]) ** 2 + (d.y / r[1]) ** 2 + (z / r[2]) ** 2 < 1
```

Order matters: later regions paint over earlier ones, so broad areas come first and small accents last. The lateral radius is set wide (0.9) so each region wraps the whole body width, which is how flat-art markings behave.

### The majority filter

A face-centre test on a faceted mesh produces sliver faces: one triangle of belly colour poking into the flank. Two passes of a neighbour vote remove them:

```python
for _ in range(2):
    new = {}
    for f in bm.faces:
        nb = [g[pal_layer] for e in f.edges for g in e.link_faces if g is not f]
        if nb and f[pal_layer] not in nb: new[f] = max(set(nb), key=nb.count)
    for f, c in new.items(): f[pal_layer] = c
```

A face only changes when none of its edge neighbours share its colour, so real region borders are untouched. Writes are collected and applied after the scan, so a pass does not chase its own changes.

### UVs as tiny triangles inside each swatch

The palette is a 176 by 4 pixel image: 16 pixels per swatch, 11 swatches. Every face's loops are placed in a small, non-degenerate triangle in the middle of its swatch:

```python
u = (f[pal_layer] + 0.5) / len(PAL); du = 0.2 / len(PAL)
for k, l in enumerate(f.loops):
    l[uv].uv = (u + du * (-1, 1, 0, 0)[k % 4], (0.4, 0.4, 0.6, 0.5)[k % 4])
```

Collapsing all loops to one point also samples the right colour, but zero-area UV triangles trip up tangent generation, some importers and any later lightmap or bake step. A tiny real triangle costs nothing. The image texture uses **Closest** interpolation so a swatch never blends with its neighbour at a distance or on mip levels. This is the same approach as [[The Gradient Palette Texture Workflow]] with flat swatches instead of gradients; [[Flat Colour vs Gradient Atlas vs Vertex Colour]] compares the options.

### Small details as separate meshes

Small features (the nose, inner ears and the face markings) are built as their own little bmesh shapes and joined into the same palette mesh with a fixed colour. They are not carved, so they stay crisp. The join uses a helper that tags the existing faces first; the reason is the bmesh gotcha below.

```python
def add_detail(build, col):
    b2 = bmesh.new(); build(b2); tmpm = bpy.data.meshes.new("d"); b2.to_mesh(tmpm); b2.free()
    for f in bm.faces: f.tag = True        # mark what was already there
    bm.from_mesh(tmpm)
    for f in bm.faces:
        if not f.tag: f[pal_layer] = col
```

**The bmesh slot trap.** After `dissolve_limit` or any delete, the bmesh has freed face slots. `bm.from_mesh()` appends new faces into those slots, so `bm.faces[n0:]` (where `n0` was the count before the join) is not the set of new faces. Colouring by index range silently recolours random body faces and leaves part of the detail uncoloured. Tag the old faces, then colour the untagged ones.

## Rig and skinning

The rig follows [[Creature Rig Conventions]]: `Root` on the ground at the origin, then `Hips`, `Spine`, `Chest`, `Neck`, `Head`, and per side `UpperArm`, `LowerArm`, `FrontPaw`, `Thigh`, `Shin`, `Hock`, `HindPaw`, `Ear`, plus three tail bones. Each bone also gets a **reach**: roughly the radius of the flesh it should own (0.21 for the hips, 0.06 for a lower leg, in design units).

### Reach-normalised distance skinning

Automatic weights failed on the fused mesh (see lessons). The replacement is simple and predictable:

```python
cand = []
for n, (a, b) in SEG.items():
    if n == "Root": continue
    if n.endswith("L") and side < -0.03: continue      # keep left bones off the right side
    if n.endswith("R") and side > 0.03: continue
    cand.append((seg_d(p, a, b) / (REACH[n] * S), n))
cand.sort(); (d1, n1), (d2, n2) = cand[0], cand[1]
if d2 > d1 * 1.6: groups[n1].add([v.index], 1.0, "REPLACE")
else:
    w1, w2 = 1 / max(d1, 1e-4) ** 4, 1 / max(d2, 1e-4) ** 4
    groups[n1].add([v.index], w1 / (w1 + w2), "REPLACE")
    groups[n2].add([v.index], w2 / (w1 + w2), "REPLACE")
```

- **Distance divided by reach** stops a thin leg bone from stealing torso vertices just because its segment is geometrically close: the torso bone's large reach makes its normalised distance smaller.
- **Two influences maximum,** blended only when the runner-up is within 1.6 times the winner, with inverse fourth-power weights so the blend zone is short. Roblox allows up to four influences ([[Weight Painting and Skinning for Roblox]]), but two gives cleaner joints on a faceted mesh.
- **Side separation** at a small dead band around the centre line, so the left front leg never pulls the right one. The dead band matters for the chest and belly where legs nearly touch.

## Walk cycle: rotations only

24 frames at 24 fps, treadmill style (the `Root` never moves; the game moves the model). A helper turns a world axis into the bone's local axis so every key reads in plain terms ("swing about the lateral axis"):

```python
def rot(name, axis_world, deg):
    ax = rig.data.bones[name].matrix_local.to_3x3().inverted() @ axis_world
    rig.pose.bones[name].rotation_quaternion = Quaternion(ax.normalized(), math.radians(deg))
```

![[p45_wolf_walk.png]]

- **Phase offsets** per leg: hind left 0, front left 0.25, hind right 0.5, front right 0.75. That is the four-beat lateral sequence real quadrupeds use at a walk.
- **Upper bones swing sinusoidally** (about plus or minus 20 degrees); **lower bones only fold**, using `max(0, sin(...))` with a phase lead, so knees bend during the swing and lock straight during the stance.
- **Body secondary motion:** hips and chest counter-roll 3 degrees, neck yaws 2 degrees, head nods at twice the stride frequency, ears flick 4 degrees.
- **Tail wave:** three bones, 7 degrees each, each lagging the previous by 0.6 radians.
- **Rotations only** means the clip retargets to any rig with the same bone names and rest pose, and no bone translation fights the game's root motion. See [[Animating Creatures and Monsters]].

Export is GLB with `export_yup=True` and animations on. [[Exporting FBX vs GLB]] covers the choice.

## Lessons from the failed attempts

| Attempt | What went wrong | Rule that fixed it |
|---|---|---|
| One skin-modifier skeleton for the whole body | Where several branches met (shoulders, hips, neck base) the skin modifier pinched the surface into creases and thin waists | Build parts separately (lofts, tubes, cones) and let a voxel remesh fuse them |
| Per-face colour on the dense smooth mesh | Colour borders followed the tiny triangles of the dense mesh and came out as stair-stepped, jagged edges | Carve first, colour after: big facets give clean straight borders, then the majority filter |
| Region colours fed as hex values straight into shader inputs | Hex values are sRGB; the shader inputs are linear. The wolf rendered washed out and pale | Either convert with roughly `(c / 255) ** 2.2` or, as here, put the hex colours in an image texture marked sRGB so Blender converts them |
| Automatic weights on the fused mesh | Bleeding between legs and torso, weights on the wrong side | Reach-normalised distance skinning with side separation |

## Nuances and edge cases

1. **The sheet is flat art, not a blueprint.** Front, side and back views of a stylised sheet rarely agree exactly. Trace the side view for lengths and heights and use the front view only for widths; when they conflict, trust the side view, which carries the silhouette players see most.
2. **The remesh erases thin features below about two voxels.** Ear tips, tail tips and claws either need a slightly exaggerated radius or must be added later as separate detail meshes.
3. **The colour regions are tested in the design frame,** before the stud mapping, so the ellipsoid numbers match the sheet. Moving the mapping earlier would break every region silently.
4. **Two influences is a trade.** It keeps joints crisp on faceted art, but a long neck or tail will crease more than with three or four. Add a third influence only where it is visibly needed.
5. **Treadmill clips need the game to move the model** at the speed the feet imply, or the paws skate. Measure stride length once and set walk speed from it.

## Common mistakes

1. **Colouring by face index range after a join.** Symptom: random body triangles in the nose colour. Fix: tag old faces, colour untagged ones.
2. **Linear texture interpolation on a palette.** Symptom: faint coloured fringes along facet borders at a distance. Fix: Closest.
3. **Degenerate UVs.** Symptom: importer warnings or broken tangents. Fix: a tiny real triangle inside the swatch.
4. **Mapping the mesh but not the bones.** Symptom: the rig faces sideways or sits at the wrong scale. Fix: one mapping function for both.

## Related decisions

- [[Matching a Concept Sheet - Boss Creature Case Study]]: the same "compare every render to the sheet" loop on a different creature.
- [[Organic and Creature Modeling]] and [[Low-Poly and Stylized Modeling]]: the modelling foundations this build follows.
- [[Skeleton Library]]: the vault's Quadruped_Wolf rig as a ready-made alternative to building bones in code.
- [[Bones and Skinned Meshes]]: how the exported rig behaves once imported.
- [[Retopology and Decimation]]: other ways to reach a triangle budget.
- [[Triangle Budget]]: whether 5k triangles fits the creature's role and count on screen.
- [[Blender 5 Python Gotchas for Headless Builds]]: the bmesh slot trap and other API traps.

## Connected notes
<!-- auto-links:start -->
[[Procedural Blender Assets Start Here]] · [[Concept Sheets]] · Topology and Edge Flow · Untextured Stylised Modelling Start Here · Skinning Weights · Meshing Voxels for Roblox - Greedy Meshing and Export
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Procedural Creatures - Fused Shells, Quad Cages and Faceting]] · [[Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs]] · [[Stylised Shop Stand Worked Example]] · [[Chibi Character Rules in Practice]] · [[Low-Poly Tree Set Worked Example]] · [[Dash VFX Presentation on an R15 Rig]] · [[Stylised Log Cabin Worked Example]] · [[Stylised Weapons From a Concept]]
<!-- related:end -->
