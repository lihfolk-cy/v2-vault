---
tags: [modeling, voxel, shading, ambient-occlusion, vertex-colors, lighting, bevels, blender, python, mobile, type/guide, area/modeling]
---
# Voxel Shading - Baked AO Edges and Lighting

<!-- tldr:start -->
> [!tldr] TL;DR
> - Diamond-shaped dark patches on faces: Wrong triangulation diagonal for the AO values -> Split along the diagonal joining the darker pair; triangulate yourself
> - Inside corners only partly dark: Missing the "both sides filled" rule -> AO level 0 when both side cells are filled
> - Baked AO blotchy on big faces: AO baked to vertex colours on greedy rectangles -> Texture AO for greedy meshes, or per-cell quads near occluders
> - Decided per asset: vertex AO, texture AO, or none.
> - AO computed with the both-sides rule and triangulated along the correct diagonal.
> - Merging limited to faces with matching AO, or AO moved to a texture.
>
> Cost: TL;DR ~200 tok · whole note ~4.8k tok. Read more: ## 2. Per-corner voxel ambient occlusion · ## 3. Baking voxel AO into vertex colours in Blender · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A voxel model with flat colours and no shading looks like a diagram. What makes good voxel art look solid is shading at the scale of the cells: darker corners where cubes meet, a soft gradient down into crevices, a lighter rim on outside edges, and lighting that separates the top, sides and underside. Some of that the engine provides, much of it it does not, and on low-end phones it provides even less. This note covers the three tools you control: **baked ambient occlusion** per voxel corner (the classic "smooth lighting" of block games), **edge treatments** (bevels, rim colour, normal-mapped bevels), and **lighting setup** in Roblox for blocky art, including what each lighting style does to small voxels. It builds on the shading section of [[Voxel and Blocky Modeling]] (three tones per material) and on [[Baking Lighting and Detail into Textures]], which covers baking into textures in general.

## 1. What the engine gives you and what it does not

Roblox's renderer gives you sun or moon light with shadows, ambient light (`Ambient`, `OutdoorAmbient`), environment lighting from the sky (`EnvironmentDiffuseScale`, `EnvironmentSpecularScale`), local lights, and post effects (Roblox docs, as of October 2026). It does not give you:

- **An ambient occlusion map slot.** SurfaceAppearance has colour, normal, roughness, metalness and an emissive mask; no AO (see [[Baking Lighting and Detail into Textures]]).
- **Screen-space ambient occlusion you can rely on** across devices; none is exposed as a property in the Lighting reference checked for this note.
- **Fine shadows on small voxels under coarse lighting.** The voxel-style lighting path computes light and shadow in a grid of 4 x 4 x 4 stud cells (Roblox docs, `GlobalShadows`; see [[Lighting Technologies and Settings]]). A 0.25-stud notch in a wall is 1/16 of that cell; it cannot shadow itself. Shadow-map lighting gives crisp sun shadows, but only from the sun, and lower graphics quality levels reduce shadow detail.

So for voxel art, **contact shading at the cell scale is your job**. It has to be baked, either into vertex colours or into a texture, and baked shading survives every device and quality level.

## 2. Per-corner voxel ambient occlusion

The standard technique in block games (described in detail in Mikola Lysenko's widely cited 0fps article on voxel ambient occlusion) computes a darkness value for each corner of each visible face from the three cells that touch that corner in the layer in front of the face.

For a face, look at the layer of cells it faces into. At each of the face's four corners, three cells of that layer touch the corner: two **side** cells (along each edge) and one **corner** cell (diagonal). Then:

- If both side cells are filled, the corner is fully occluded: AO level 0.
- Otherwise, AO level = 3 minus the number of filled cells among side 1, side 2 and corner.

Four levels, 0 (darkest) to 3 (open). Map them to brightness multipliers, for example 0.55, 0.70, 0.85, 1.00 (rule of thumb; a range from about 0.5 to 1.0 reads well on stylised art). The GPU interpolates the four corner values across the face, giving a smooth darkening into every inside corner and crevice.

The "both sides filled means 0" rule matters: without it, a corner where two walls meet would only be 2/3 dark even though no light can reach it.

### The diagonal problem

Each quad is drawn as two triangles. Interpolation runs across the shared diagonal, so the same four corner values look different depending on which diagonal you pick: one choice gives a smooth gradient, the other a visible crease or an odd diamond of darkness. The fix from the same article: if the sum of the AO values on one diagonal's corners is greater than the other's, split along the other diagonal. That is, split along the diagonal joining the darker pair. You must therefore **triangulate the quads yourself** when baking AO, rather than leaving it to the exporter, which picks diagonals without knowing about AO.

### AO versus greedy meshing

Greedy meshing ([[Meshing Voxels for Roblox - Greedy Meshing and Export]]) merges faces of the same colour. With per-corner AO, two faces can only merge if every corner value along the merge matches, so AO dramatically reduces how much merging happens. Expect a greedy mesh with AO to be two to five times the triangle count of the same mesh without AO (rule of thumb). Options:

- **Accept it** on characters and props, which are small.
- **Bake AO into a texture instead** (section 4) on big environment pieces, and keep the geometry greedy.
- **Merge only fully open faces** (all corners at level 3), which are usually the majority on large flat areas: you keep most of the greedy savings and lose nothing visually.

## 3. Baking voxel AO into vertex colours in Blender

This script meshes cells with one quad per visible face, computes per-corner AO, triangulates along the right diagonal, and writes the result into a face-corner colour attribute: palette colour multiplied by the AO brightness. On Roblox, vertex colours multiply with the MeshPart's `Color`, so set `Color` to white to see them exactly (community-reported and measured in the vault; see [[Trim Sheets Atlases and Vertex Colors]]). The importer reads vertex colours from FBX and glTF (Roblox docs).

```python
# Voxel mesh with baked per-corner AO in vertex colours (Blender). 1 Blender unit = 1 stud.
import bpy

AO_LEVELS = (0.55, 0.70, 0.85, 1.00)        # brightness for AO level 0..3

def bake_voxel_ao(cells, palette, cell_size=0.25, name="VoxAO"):
    """cells: {(x, y, z): palette_key}; palette: {key: (r, g, b)} in 0..1 sRGB."""
    def filled(p):
        return p in cells

    verts, faces, colours = [], [], []
    for (x, y, z), key in cells.items():
        base_col = palette[key]
        for d in range(3):
            u, v = (d + 1) % 3, (d + 2) % 3            # e_u x e_v = +e_d
            for side in (1, -1):
                n = [x, y, z]; n[d] += side
                if filled(tuple(n)):
                    continue                            # hidden face
                plane = [x, y, z]
                if side > 0:
                    plane[d] += 1
                corners, ao = [], []
                for du, dv in ((0, 0), (1, 0), (1, 1), (0, 1)):
                    c = list(plane); c[u] += du; c[v] += dv
                    corners.append(tuple(c))
                    su = 1 if du else -1                # step toward this corner in u
                    sv = 1 if dv else -1                # and in v
                    s1 = list(n); s1[u] += su
                    s2 = list(n); s2[v] += sv
                    cc = list(n); cc[u] += su; cc[v] += sv
                    a, b, k = filled(tuple(s1)), filled(tuple(s2)), filled(tuple(cc))
                    ao.append(0 if (a and b) else 3 - (a + b + k))
                if side < 0:                            # flip winding for -d faces
                    corners.reverse(); ao.reverse()
                i0 = len(verts)
                verts.extend((c[0] * cell_size, c[1] * cell_size, c[2] * cell_size) for c in corners)
                # Split along the diagonal joining the darker pair of corners.
                if ao[0] + ao[2] > ao[1] + ao[3]:
                    tris = ((1, 2, 3), (1, 3, 0))      # diagonal 1-3
                else:
                    tris = ((0, 1, 2), (0, 2, 3))      # diagonal 0-2
                for t in tris:
                    faces.append(tuple(i0 + i for i in t))
                    colours.append([tuple(ch * AO_LEVELS[ao[i]] for ch in base_col) for i in t])

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    attr = mesh.color_attributes.new(name="Col", type='BYTE_COLOR', domain='CORNER')
    for poly, cols in zip(mesh.polygons, colours):
        poly.use_smooth = False
        for k in range(3):
            r, g, b = cols[k]
            attr.data[poly.loop_start + k].color_srgb = (r, g, b, 1.0)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj
```

Notes:

- **sRGB versus linear.** Palette colours are written with `color_srgb`, so a palette value of (0.5, 0.5, 0.5) is stored as the sRGB grey you picked. Writing the same numbers to `.color` instead treats them as linear and they come out much lighter. Exporters and Roblox's colour-space handling of vertex colours have changed between versions; test one mesh end to end and compare against a Part of the same `Color3` (see [[Trim Sheets Atlases and Vertex Colors]]).
- **Vertices are not shared** between faces here, because each corner carries its own AO and normal. The glTF exporter would duplicate them anyway for flat shading.
- **Only the front layer counts.** The three tested cells are all in the layer the face looks into. That is correct for contact shading; for deeper occlusion (a long dark tunnel) you need a second pass or a raytraced bake.
- **AO multiplies the palette colour.** If your palette already has a dark shadow step for undersides ([[Voxel Palettes - Ramps Hue Shifting and Limits]]), AO stacks on it; reduce the AO range (for example 0.7 to 1.0) so undersides in corners do not go black.

## 4. Baking AO into a texture instead

For large environment meshes where you want greedy geometry, bake AO into a texture with Cycles. The Blender manual's Render Baking settings include an Ambient Occlusion bake type, which ignores scene lights and uses the World settings, and two output targets: Image Textures (the active Image Texture node) or Active Color Attribute (Blender manual).

1. Give the mesh a UV layout with each face's island in its own space (Smart UV Project with a small island margin works for blocky meshes).
2. Add an Image Texture node with a new image, select it as active.
3. Bake type Ambient Occlusion, margin 4 to 8 pixels (the manual explains that margins prevent seams from filtering and mipmapping), output Image Textures.
4. Multiply the AO image into the colour or palette texture, or use it as a separate overlay.

Do not bake AO to the **Active Color Attribute** on a greedy mesh: vertex colours only store values at vertices, so a merged 10-cell rectangle has four AO samples for its whole area and the bake comes out blotchy. Vertex-colour AO needs one quad per cell near occluders, which the script in section 3 provides.

Texture AO costs memory: a 512 AO texture per building is a quarter of the pixels of a 1024 map (see [[Textures Decals and Texture Memory]]). For tiled environments, prefer baking AO into the **tile pieces** themselves, so one baked tile is reused hundreds of times ([[Voxel Props Environments and Modular Tiles]]).

## 5. Edges: bevels, rim colour and fake bevels

Real cubes in real light catch a thin highlight along every edge. Pure voxel cubes have razor edges and no highlight, which is part of their look but can feel harsh. Three ways to soften edges, cheapest first:

| Method | How | Cost | When |
|---|---|---|---|
| **Rim colour in the palette** | Paint the outermost cells of top edges one step lighter (a "lit edge" step) | Free | Toy style; very readable on phones |
| **Normal-mapped bevel** | A tiling normal map that bends normals near each cell's edges, on cell-unit UVs | One small texture shared by everything; needs per-colour meshes with tiling UVs | When you want a soft studio-lit look without triangles |
| **Real bevel geometry** | Blender Bevel modifier, small width, 1 segment | Each cube edge gets an extra face: roughly 2 to 3 times the triangles | Hero props and renders only |

**Real bevel numbers** (rule of thumb): width 5 to 10 percent of the cell (0.0125 to 0.025 studs at 0.25-stud cells), 1 segment, Limit Method Angle at 30 degrees so only true corners bevel. Below about 5 percent the bevel is sub-pixel at gameplay distance and you paid triangles for nothing; above about 15 percent the model stops reading as voxels. Bevel after greedy meshing, not before, and only on objects whose silhouette is seen close.

**Normal-mapped bevel**: make a 64 or 128 pixel tile whose normals tilt outward in a band about 6 to 10 percent wide around the border, flat in the middle. Apply it in a SurfaceAppearance NormalMap (OpenGL format, tangent space, per the Roblox texture specifications) with ColorMap white so the MeshPart's `Color` tints the surface. It depends on cell-unit tiling UVs; see the wrap-mode caution in [[Meshing Voxels for Roblox - Greedy Meshing and Export]].

**Outlines** are covered in [[Voxel Art - Studs Outlines and Style Kits]].

## 6. Lighting voxel art in Roblox

Lighting choices that suit blocky models (rules of thumb, tested across many stylised Roblox games):

- **Lighting style.** `LightingStyle` (`Realistic` or `Soft`) and `PrioritizeLightingQuality` replaced the old `Technology` setting (Roblox docs, as of October 2026; see [[Lighting Technologies and Settings]]). `Soft` gives the flat, retro look many block games want; `Realistic` gives crisper shadows and stronger contrast. Under `Soft`, the engine separates planes less, so your palette's three tones and baked AO carry the form.
- **Sun angle.** A sun 35 to 55 degrees above the horizon and not aligned with the world grid (rotate it 20 to 30 degrees off the axes) lights top, front and side faces at three different strengths. A sun straight overhead or aligned with an axis makes two side faces identical.
- **Ambient.** Voxel art usually wants more ambient than realistic scenes, because undersides are big flat planes that look like black holes otherwise. Raise `OutdoorAmbient` until undersides sit around the palette's shadow step, then stop.
- **Shadow softness.** Sharp shadows read better on blocky shapes than very soft ones, which smear across the stepped forms. If shadows look mushy on small voxels, that is usually the coarse lighting path, not the setting.
- **Neon and bloom.** Neon cells should not cast shadows (`CastShadow = false`), and bloom should be tuned so only Neon blooms ([[Voxel and Blocky Modeling]] gives values).
- **Materials.** SmoothPlastic for flat voxel faces. Plastic and other built-in materials add their own surface texture in some lighting modes, which fights the flat look; test both.

### Phone versus PC

Low graphics quality levels drop shadow detail and some post-processing. Everything baked (palette steps, AO, rim colour) survives; everything engine-side may not. Judge voxel art at the lowest Editor Quality Level and on a real phone before signing off. A model that only reads because of PC shadows is not finished.

## 7. Worked example: shading a voxel house

A 0.5-stud-cell cottage, 24 x 20 x 24 cells, five colours.

1. **Palette with three steps per material**, lit edge step on the roof ridge cells and window frames.
2. **Mesh the walls and roof greedy, without AO**, as per-colour meshes: they are large and flat.
3. **Bake AO into a 256 texture** for the roof (overhangs, ridge) with Cycles, since the roof is greedy geometry. Multiply it into a white ColorMap so `Color` still tints.
4. **Small detail pieces** (window boxes, chimney, door frame) as separate small meshes with vertex AO from the script in section 3.
5. **Sun 45 degrees up, rotated 25 degrees off the grid**; raise OutdoorAmbient until the shaded wall reads as the shadow step.
6. **Check at the lowest quality level on a phone** at 30 and 80 studs: the corners under the eaves should still be darker; the window frames should still catch their lit edge.

## 8. When not to bake shading

- **Objects that rotate freely** (spinning pickups, tumbling debris): AO from contact with the floor is wrong once they turn over; keep only self-occlusion, which rotates with them.
- **[[Modular Kits|Modular pieces]] that will be placed against unknown neighbours**: AO baked on a wall's base assumes a floor; if the piece is also used floating, it looks dirty. Bake only self-occlusion into kit pieces, or make two variants.
- **Day-night cycles with dramatic light**: strong baked AO stays dark at noon and at midnight alike; keep it moderate.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Diamond-shaped dark patches on faces | Wrong triangulation diagonal for the AO values | Split along the diagonal joining the darker pair; triangulate yourself |
| Inside corners only partly dark | Missing the "both sides filled" rule | AO level 0 when both side cells are filled |
| Baked AO blotchy on big faces | AO baked to vertex colours on greedy rectangles | Texture AO for greedy meshes, or per-cell quads near occluders |
| Vertex-colour model looks washed out or too dark | sRGB and linear mixed up somewhere in the chain | Write with `color_srgb`; compare one mesh against a Part of the same colour |
| Undersides go black in corners | AO stacked on an already dark shadow step | Narrow the AO range (0.7 to 1.0) |
| Model looks great on PC, flat on phone | Form relied on engine shadows | Bake AO and keep three-tone palettes; test at the lowest quality |
| Bevels invisible but triangles tripled | Bevel width under about 5 percent of a cell | Rim colour or normal-mapped bevel; real bevels only on hero pieces |

## Checklist

- [ ] Decided per asset: vertex AO, texture AO, or none.
- [ ] AO computed with the both-sides rule and triangulated along the correct diagonal.
- [ ] Merging limited to faces with matching AO, or AO moved to a texture.
- [ ] Colour space checked once end to end; MeshPart `Color` white for vertex colours.
- [ ] Edge treatment chosen (rim colour, normal bevel, real bevel) with numbers within the ranges above.
- [ ] Sun off-axis at 35 to 55 degrees; ambient tuned to the palette's shadow step.
- [ ] Neon pieces with `CastShadow = false`.
- [ ] Reviewed at the lowest Editor Quality Level and on a phone.

## Related

[[Voxel and Blocky Modeling]] · [[Baking Lighting and Detail into Textures]] · [[Lighting Technologies and Settings]] · [[Light Sources and Shadows]] · [[Stylized Lighting Recipes]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Normal Maps and Detail Baking]] · [[Mobile and Low-End Optimization]] · [[Voxel Palettes - Ramps Hue Shifting and Limits]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]] · [[Voxel Props Environments and Modular Tiles]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Modelling Start Here]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · Lighting Untextured Art in Roblox · [[MagicaVoxel Goxel and Blockbench Workflows Compared]] · Untextured Stylised Modelling Start Here · Hand-Painted and Stylized Texturing
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Lighting Untextured Art in Roblox]] · [[Hand-Painted and Stylized Texturing]] · [[The Gradient Palette Texture Workflow]] · [[Voxel Scale Grids and Stud Alignment]] · [[Voxel Chibi Heroes - Class Roster and Rarity Ladder]] · [[Voxel Characters - Proportions Joints and Rigging]]
<!-- related:end -->
