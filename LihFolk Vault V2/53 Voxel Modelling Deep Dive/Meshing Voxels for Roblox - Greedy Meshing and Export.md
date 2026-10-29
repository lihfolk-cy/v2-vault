---
tags: [modeling, voxel, meshing, greedy-meshing, blender, python, export, glb, triangles, collision, lod, type/guide]
---
# Meshing Voxels for Roblox - Greedy Meshing and Export

<!-- tldr:start -->
> [!tldr] TL;DR
> - Thousands of triangles on a simple prop: Culled faces only, no merging -> Greedy meshing
> - Sparkling dots along seams at a distance: T-junctions from greedy merging -> Watertight greedy mode, split long edges, or cap rectangle size
> - Voxel edges look rounded and dark: Smooth shading or smoothed normals exported -> Shade Flat; export normals; no smoothing modifier
> - Greedy meshing on everything shipped; triangle counts checked in Blender.
> - Faces merge only when colour, material and baked values match.
> - T-junction strategy chosen for large or grazing-angle meshes.
>
> Cost: TL;DR ~190 tok · whole note ~4.8k tok. Read more: ## 3. A greedy mesher in Blender Python · ## 7. In Studio: collision and render fidelity · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A voxel model is data: a set of filled cells, each with a colour. Before Roblox can draw it, that data has to become a mesh, and the way you build the mesh decides the triangle count, the number of MeshParts, whether textures tile, whether cracks appear between faces, and how the model collides. [[Voxel and Blocky Modeling]] shows a Blender script that emits only exposed faces, one mesh per colour. This note takes the next steps: greedy meshing (merging coplanar faces into big rectangles), the T-junction problem it creates, how to keep tiling stud textures working on merged faces, the export settings that keep voxels flat-shaded, and the Roblox-side settings (collision fidelity, render fidelity) that quietly change how voxel meshes look and behave.

## 1. Four levels of meshing

Take a solid block of 32 x 32 x 32 cells, the worst-case "chunk".

| Method | What it emits | Triangles for a solid 32-cube | Triangles for a 32-cube terrain chunk with a bumpy top (rough) |
|---|---|---|---|
| **One cube per cell** | 12 triangles per cell | 393,216 | Hundreds of thousands |
| **Culled faces** | Only faces with an empty neighbour, 2 triangles per face | 12,288 | 3,000 to 6,000 |
| **Greedy meshing** | Coplanar, same-colour exposed faces merged into rectangles | 12 | 500 to 1,500 |
| **Greedy plus watertight** | Greedy rectangles split so no vertex sits in the middle of another face's edge | A little more than greedy | 700 to 2,000 |

The rough figures for the bumpy chunk are rule-of-thumb estimates; actual counts depend on how many colours and height steps the top has. The solid-cube numbers are exact arithmetic.

The Roblox limit that matters: **an individual mesh cannot exceed 20,000 triangles** (Roblox docs, modelling specifications, as of October 2026). Culled meshing of a detailed character often lands at 5,000 to 15,000 triangles; greedy meshing typically cuts that by a factor of 3 to 10 (rule of thumb), because large flat areas of one colour collapse to a few rectangles. Greedy meshing is the default for anything shipped.

## 2. How greedy meshing works

Greedy meshing processes the model one slice at a time, one axis and one facing direction at a time.

1. **Pick an axis and a direction**, for example the +Y (up-facing) faces.
2. **For each slice** (each Y layer), build a 2D mask: at each (x, z), store the colour of the cell if it is filled and the cell above it is empty, otherwise nothing. That mask is every up-facing visible face on that layer.
3. **Sweep the mask.** At the first unused filled entry, extend a rectangle along x while the colour matches, then extend that whole row along z while every entry in the next row matches. Emit the rectangle as one quad, mark its entries used, continue.
4. **Repeat** for all six directions.

The result is not the minimum possible number of rectangles (that problem is harder), but it is close and runs in linear time. Two rules are easy to get wrong:

- **A face is hidden by any neighbour**, whatever its colour, for solid models. Faces between two filled cells of different colours are interior and never seen.
- **Only merge faces that are identical in everything that will be stored per vertex**: colour, material, and any baked lighting. If you bake per-vertex ambient occlusion ([[Voxel Shading - Baked AO Edges and Lighting]]), faces whose corners have different AO values must not merge, which reduces the savings considerably.

## 3. A greedy mesher in Blender Python

This script takes a dictionary of cells and builds one Blender object per colour, using greedy rectangles. It is written for clarity, not speed; it handles models of a few hundred thousand cells in seconds to a minute.

```python
# Greedy voxel mesher for Blender. cells: {(x, y, z): "ColourName"}; 1 Blender unit = 1 stud.
import bpy, bmesh
from collections import defaultdict

def greedy_mesh(cells, cell_size=0.25, name="Vox"):
    if not cells:
        return []
    xs, ys, zs = zip(*cells.keys())
    lo = (min(xs), min(ys), min(zs))
    hi = (max(xs), max(ys), max(zs))
    quads = defaultdict(list)                     # colour -> list of 4-corner tuples

    for d in range(3):                            # axis the face points along
        u, v = (d + 1) % 3, (d + 2) % 3           # e_u x e_v = +e_d
        for side in (1, -1):
            for s in range(lo[d], hi[d] + 1):
                # 1) mask of visible faces on this slice
                mask = {}
                for i in range(lo[u], hi[u] + 1):
                    for j in range(lo[v], hi[v] + 1):
                        p = [0, 0, 0]; p[d], p[u], p[v] = s, i, j
                        col = cells.get(tuple(p))
                        if col is None:
                            continue
                        n = list(p); n[d] += side
                        if tuple(n) not in cells:     # neighbour empty: face visible
                            mask[(i, j)] = col
                # 2) sweep: grow rectangles of equal colour
                used = set()
                for j in range(lo[v], hi[v] + 1):
                    for i in range(lo[u], hi[u] + 1):
                        col = mask.get((i, j))
                        if col is None or (i, j) in used:
                            continue
                        w = 1
                        while mask.get((i + w, j)) == col and (i + w, j) not in used:
                            w += 1
                        h = 1
                        while all(mask.get((i + k, j + h)) == col and (i + k, j + h) not in used
                                  for k in range(w)):
                            h += 1
                        for k in range(w):
                            for m in range(h):
                                used.add((i + k, j + m))
                        plane = s + 1 if side > 0 else s
                        corners = []
                        for du, dv in ((0, 0), (w, 0), (w, h), (0, h)):
                            c = [0, 0, 0]; c[d], c[u], c[v] = plane, i + du, j + dv
                            corners.append(tuple(c))
                        if side < 0:
                            corners.reverse()             # keep the normal pointing outward
                        quads[col].append(corners)

    objs = []
    for col, qs in quads.items():
        bm = bmesh.new()
        cache = {}
        def vert(c):
            if c not in cache:
                cache[c] = bm.verts.new((c[0] * cell_size, c[1] * cell_size, c[2] * cell_size))
            return cache[c]
        for q in qs:
            bm.faces.new([vert(c) for c in q])
        mesh = bpy.data.meshes.new(f"{name}_{col}")
        bm.to_mesh(mesh); bm.free()
        for poly in mesh.polygons:
            poly.use_smooth = False                     # flat shading for every face
        obj = bpy.data.objects.new(f"{name}_{col}", mesh)
        bpy.context.collection.objects.link(obj)
        objs.append(obj)
    return objs
```

Notes:

- **The axis convention.** With u and v chosen cyclically after d, the corner order (0,0), (w,0), (w,h), (0,h) winds counter-clockwise seen from +d, so the normal points along +d; reversing it flips the normal for -d faces. This is the same convention as the culled mesher in [[Voxel and Blocky Modeling]].
- **Blender is Z-up.** Build the model with Z as height. The glTF exporter's +Y Up option (on by default) converts to Roblox's Y-up (see [[Exporting FBX vs GLB]]).
- **One object per colour** gives you one MeshPart per colour in Studio, coloured with `Color`. For a palette-texture route instead, emit every colour into one bmesh and give each face UVs at its swatch centre.

## 4. T-junctions and why merged faces can sparkle

Greedy meshing creates **T-junctions**: places where a vertex of one rectangle lies in the middle of an edge of a neighbouring rectangle, without being part of that edge. Mathematically the surfaces meet; in floating point the GPU rasterises the long edge and the two short edges with slightly different rounding, and single pixels along the seam can show the background. You see it as sparkling dots of sky or of the colour behind, strongest at grazing angles and at long distances.

The modelling specifications also ask that meshes be watertight, with no holes (Roblox docs). A T-junction mesh is closed in intent but not topologically watertight. Whether this ever causes an import problem in practice was not confirmed here; the visual sparkle is the real-world symptom.

Ways to deal with it, cheapest first:

1. **Ignore it on small or close objects.** At character scale with 0.25-stud cells the sparkles are rare and tiny.
2. **Put a backing colour behind seams.** Because interior faces are culled, the "behind" of a seam is the sky. A model with a dark interior shell (a culled but not merged inner layer) hides sparkles at a small triangle cost; usually not worth it.
3. **Watertight greedy meshing.** The Blender "[[MagicaVoxel]] VOX format" importer extension offers a watertight variant of its greedy mode that removes T-junctions (tool docs). In your own script, after merging, insert the T-junction vertices into the long edges (split each long edge at every vertex that lies on it), then triangulate.
4. **Do not merge across large distances** on terrain-like chunks: cap rectangle width at, say, 16 cells. This bounds the edge length and the error.

## 5. Keeping tiling stud textures on merged faces

The existing voxel notes say that a per-cell stud texture needs one quad per cell, which forbids merging. That is only true if the UVs of each face run from 0 to 1. **If instead the UVs are set to the face's position in cells**, a merged rectangle 6 cells wide has UVs from 0 to 6, and a tiling stud texture repeats six times across it, exactly as if there were six separate faces.

In the mesher above, that means setting each corner's UV from its (u, v) cell coordinates:

```python
# After building a face from corners c0..c3 that lie in plane d with in-plane axes u, v:
uv_layer = bm.loops.layers.uv.verify()
for loop, c in zip(face.loops, corners):
    loop[uv_layer].uv = (c[u], c[v])      # 1 UV unit = 1 cell, so the texture tiles per cell
```

Two cautions:

- **UV wrapping.** This relies on the texture repeating when UVs go outside 0 to 1. Standard GPU sampling repeats, and tiling UVs are common in Roblox meshes, but the Roblox docs pages checked here do not state the wrap mode for MeshPart or SurfaceAppearance textures; test one mesh before converting a library (unverified).
- **Palette textures cannot tile.** A palette swatch occupies one small region of the image, so a merged face with UVs from 0 to 6 would sample the whole palette. Tiling UVs need the per-colour mesh route (colour from `Color`, texture is a white stud tile).

## 6. Export settings that keep voxels crisp

Blocky models must stay **flat shaded**: every face has its own normal. If smoothing creeps in, voxel edges glow and darken as if the cubes were rounded.

- **In Blender**, the mesher sets `use_smooth = False` on every face. If you edit the mesh later, check with Face, Shade Flat. Since Blender 4.1, "Auto Smooth" became a modifier node group (Smooth by Angle); voxels need neither.
- **Flat shading duplicates vertices** at every hard edge in exported formats, because each face needs its own normal. A cube has 8 positions but 24 exported vertices. That is normal and expected.
- **glTF/GLB export**: Mesh, Apply Modifiers on, Normals on, UVs on if you use them, Vertex Color only if you use them (the option name changed across Blender 4.x; check yours, see [[Trim Sheets Atlases and Vertex Colors]]). Format GLB, +Y Up.
- **Do not run Merge by Distance across colour objects** before splitting; within one colour object it is harmless and the mesher's vertex cache already shares positions.
- **Do not triangulate in a way that changes the look** if you bake per-vertex AO: the diagonal choice matters ([[Voxel Shading - Baked AO Edges and Lighting]]). Otherwise let the exporter triangulate.

## 7. In Studio: collision and render fidelity

Two MeshPart settings change voxel meshes in ways artists rarely expect.

**CollisionFidelity.** It "determines the level of detail the part's physics will adhere to its mesh" (Roblox docs). For voxel meshes:

| Setting | Use on voxel meshes |
|---|---|
| `Box` | Floor tiles, crates, any piece whose bounding box is its shape. Cheapest |
| `Hull` | Rounded props, characters' non-limb parts |
| `Default` | Most other props |
| `PreciseConvexDecomposition` | Rarely. A staircase-like voxel surface decomposes into many convex pieces and costs memory and physics time |

Better still for walkable voxel terrain made of meshes: set the visual mesh to `CanCollide = false` and add a few invisible box Parts as colliders, stepped every 1 to 2 studs, which also makes characters walk smoothly over small voxel steps that would otherwise catch their feet (see [[Collision and Physics Geometry]]).

**RenderFidelity.** The default `Automatic` picks a detail level by camera distance: the highest under 250 studs, a medium level from 250 to 500, and the lowest beyond 500 (Roblox docs, as of October 2026). The engine generates the lower levels by simplifying your mesh. On smooth meshes that is invisible; on a voxel silhouette, simplification can bevel corners and bridge gaps between cells, so a distant blocky tower can look subtly melted. Whether the effect is visible depends on the mesh and was not measured here. Rules of thumb: leave `Automatic` for small props (by 250 studs they are a few pixels anyway); set `Precise` on large landmark voxel meshes whose silhouette is the point, and measure the cost; or ship your own coarser LOD at double the cell size and swap it by distance ([[Level of Detail and Model Streaming]]).

**Draw calls and instances.** One mesh per colour means one MeshPart per colour group. A 6-colour character is 6 MeshParts; a 20-colour building is 20. Identical MeshParts (same mesh, same material and texture) share asset memory, and Roblox can batch instances of identical meshes (see [[Art Budgets - Triangles Draw Calls Memory]]), so reusing the same per-colour pieces across many copies is far cheaper than many unique merged meshes.

## 8. Worked example: from MagicaVoxel to a GLB in Studio

A 0.25-stud-cell lantern post, 8 x 8 x 40 cells (2 x 2 x 10 studs), four colours plus a glowing core.

1. **Save .vox** from MagicaVoxel with the glow voxels in their own palette slot.
2. **Import in Blender** with the MagicaVoxel importer extension: meshing Greedy (watertight on, because the post is a landmark seen at grazing angles), material mode "Material Per Color", voxel size 0.25.
3. **Check counts.** Statistics overlay: about 300 to 600 triangles across all objects (rule of thumb for this shape). If it says several thousand, the meshing mode was not greedy.
4. **Separate by material** (Edit mode, Mesh, Separate, By Material) so each colour is one object, or keep one object if you will colour with a palette texture.
5. **Set the origin** at the bottom centre (even footprint, so the centre is on a cell edge; see [[Voxel Scale Grids and Stud Alignment]]). Apply all transforms.
6. **Export GLB** with the settings in section 6.
7. **Import into Studio** with Scale Unit Studs. Set `Color` per MeshPart if the materials did not come across as you want; give the glow piece `Material = Neon` and `CastShadow = false`.
8. **Collision**: the post's base gets one invisible 2 x 10 x 2 collider Part; every visual MeshPart `CanCollide = false`, `CanQuery = false` unless you need raycasts on it.
9. **Look at it from 300 studs** with `RenderFidelity = Automatic`, then `Precise`. Keep `Automatic` unless the silhouette visibly degrades.

## 9. When not to mesh

- **Destructible or player-edited voxels** need per-cell changes at runtime. Remeshing a whole chunk on every edit is expensive in Luau; Parts per merged run (rebuilt locally) or Roblox Terrain may be simpler. See [[Procedural World Generation]].
- **Very small counts.** A 20-cell sign is 20 Parts at most; meshing it saves little and adds an upload.
- **Rapid art iteration in Studio.** Build with Parts while the design is moving, mesh when it is locked.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Thousands of triangles on a simple prop | Culled faces only, no merging | Greedy meshing |
| Sparkling dots along seams at a distance | T-junctions from greedy merging | Watertight greedy mode, split long edges, or cap rectangle size |
| Voxel edges look rounded and dark | Smooth shading or smoothed normals exported | Shade Flat; export normals; no smoothing modifier |
| Stud texture stretched across merged faces | UVs 0 to 1 per face | UVs in cell units on the per-colour route |
| Palette colours wrong on merged faces | Tiling UVs with a palette texture | Palette route needs one swatch UV per face; tile only with per-colour meshes |
| Characters snag on voxel steps | Precise mesh collision on stepped surfaces | Invisible box colliders, visual mesh non-colliding |
| Distant voxel landmark looks melted | Automatic render fidelity simplified the mesh | `Precise` on that mesh, or a hand-made coarse LOD |
| Import fails or splits a big chunk | Mesh over 20,000 triangles | Split into chunks or merge more aggressively |

## Checklist

- [ ] Greedy meshing on everything shipped; triangle counts checked in Blender.
- [ ] Faces merge only when colour, material and baked values match.
- [ ] T-junction strategy chosen for large or grazing-angle meshes.
- [ ] Stud textures use cell-unit UVs on per-colour meshes; wrap mode tested once.
- [ ] Flat shading confirmed; GLB exported with normals, +Y Up, applied transforms.
- [ ] CollisionFidelity set per piece; walkable voxel surfaces use simple colliders.
- [ ] Landmarks checked at 300 studs for render-fidelity degradation.
- [ ] Every mesh under 20,000 triangles.

## Related

[[Voxel and Blocky Modeling]] · [[Voxel Art - Studs Outlines and Style Kits]] · [[Exporting and Validating Models for Roblox]] · [[Exporting FBX vs GLB]] · [[Collision and Physics Geometry]] · [[Level of Detail and Model Streaming]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Mesh Optimization for Mobile]] · [[Blender Automation with Python]] · [[Voxel Scale Grids and Stud Alignment]] · [[Voxel Shading - Baked AO Edges and Lighting]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Modelling Start Here]] · [[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Voxel Props Environments and Modular Tiles]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · Parts Unions and MeshParts · Modeling Fundamentals for Games
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Modeling Fundamentals for Games]] · [[Parts Unions and MeshParts]] · [[Modeling in Blender for Roblox]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · [[Voxel Palettes - Ramps Hue Shifting and Limits]] · [[Voxel Characters - Proportions Joints and Rigging]]
<!-- related:end -->
