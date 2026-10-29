---
cssclasses: [vault-hub]
tags: [modeling, voxel, hub, start-here, blocky, magicavoxel, roblox, type/hub, area/modeling, level/beginner]
---
# Voxel Modelling Start Here

This section is a deep dive into blocky and voxel art for Roblox: the numbers, pipelines and failure modes behind models built from cubes on one grid. It assumes you already know what a good voxel style looks like and why it suits Roblox. That ground is covered by three older notes; read them first:

1. [[Voxel and Blocky Modeling]]: voxel grammar (one grid, three tones, one glow colour), three studied styles, and Part and Blender builders.
2. [[Voxel Art - Studs Outlines and Style Kits]]: studs, outlines, greedy Part merging and style kits.
3. [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]]: what [[MagicaVoxel]] and [[Blockbench]] are, and the unit traps of each tool.

Also useful beforehand: [[Low-Poly and Stylized Modeling]] and [[Trim Sheets Atlases and Vertex Colors]] for colouring without unique textures, [[Art Budgets - Triangles Draw Calls Memory]] for budgets, and [[Lighting Technologies and Settings]] for the lighting styles your art will be judged under.

The notes here go a level deeper. Roblox facts are checked against the Creator Hub (as of October 2026) and labelled where they could not be confirmed; tool facts come from each tool's own documentation; everything else is marked as a rule of thumb.

## The notes

| Note | Read it when |
|---|---|
| [[Voxel Scale Grids and Stud Alignment]] | You are choosing a cell size, seeing cracks between tiles, fighting half-stud offsets, or importing at the wrong scale |
| [[MagicaVoxel Goxel and Blockbench Workflows Compared]] | You are choosing a tool, mixing tools in one game, or your blocky textures look blurry or shift colour at a distance |
| [[Voxel Palettes - Ramps Hue Shifting and Limits]] | Your voxel art looks dull or muddy, colours block merging, or you want cheap recolours per zone |
| [[Meshing Voxels for Roblox - Greedy Meshing and Export]] | Triangle counts are too high, seams sparkle, studs stretch, or characters snag on voxel steps |
| [[Voxel Characters - Proportions Joints and Rigging]] | You are building a blocky character, joints gap or intersect, or you want default R15 animations on voxel art |
| [[Voxel Shading - Baked AO Edges and Lighting]] | Models look flat, especially on phones, or you want block-game corner shading |
| [[Voxel Props Environments and Modular Tiles]] | You are building a world from tiles, need autotiling, or a tiled world is too heavy for phones |

## A suggested path

1. **Grid first.** Pick cell sizes per asset class from the pixels-per-cell table and lock them: [[Voxel Scale Grids and Stud Alignment]].
2. **Palette second.** Build the game palette and zone ramps before modelling anything: [[Voxel Palettes - Ramps Hue Shifting and Limits]].
3. **Tool and colour route.** Choose how colour reaches the mesh (palette texture, per-colour meshes, vertex colours or painted textures), then the tool: [[MagicaVoxel Goxel and Blockbench Workflows Compared]].
4. **Meshing and export.** Greedy meshing, flat shading, collision and render fidelity: [[Meshing Voxels for Roblox - Greedy Meshing and Export]].
5. **Shading.** Decide per asset between vertex AO, texture AO and none, and set the lighting: [[Voxel Shading - Baked AO Edges and Lighting]].
6. **Then build**: characters with [[Voxel Characters - Proportions Joints and Rigging]], the world with [[Voxel Props Environments and Modular Tiles]].

## Rules that run through the section

1. **Binary-fraction cells.** 1, 0.5, 0.25 and 0.125 studs; every grain in the game divides the largest.
2. **Exact colours.** Palettes built from integer RGB; quantise before every merge or meshing pass.
3. **Merge everything that matches, and nothing that does not.** Greedy meshing joins faces only when colour, material and baked values agree.
4. **Bake what must survive phones.** Palette steps and AO survive every quality level; engine shadows do not.
5. **Joints are designed, not discovered.** Choose the joint shape and rig route before building the character.
6. **Tiles are contracts.** Edge profiles, pivots and orientations are written down before the first tile is built.

## Things this section could not confirm

These are flagged in the notes and worth testing in your own Studio before you build a pipeline on them:

- Whether `SurfaceAppearance.ResampleMode = Pixelated` also avoids mipmap blending at a distance (the docs describe nearest-neighbour filtering when scaled, but not mip behaviour).
- The UV wrap mode for MeshPart and SurfaceAppearance textures, which tiling stud UVs depend on.
- How visibly `RenderFidelity = Automatic` simplifies voxel silhouettes at 250 and 500 studs.
- Vertex colours on MeshParts: the importer documents support in FBX and glTF, and community tests show they multiply with `Color`, but the MeshPart reference page does not mention them.
- MagicaVoxel's per-model size limit (256 per axis in community documentation) and how its own OBJ exporter merges faces, because the developer's site did not render readable text when checked.
- Blockbench's unit-to-metre mapping in its glTF output.

## Related notes elsewhere

- Modelling: [[Modeling Fundamentals for Games]], [[Topology and Edge Flow]], [[Modular Environment Kits]], [[Modeling Characters for R15 and Custom Rigs]], [[Mesh Optimization for Mobile]].
- Import and export: [[Exporting and Validating Models for Roblox]], [[3D Importer Settings Reference]], [[Exporting FBX vs GLB]].
- Rigging and animation: [[R15 Rig Anatomy and Attachments]], [[Rigging in Blender]], [[Custom Rigs - Weapons and Props]].
- World: [[Environment Art Styles]], [[Zone and Biome Art Direction]], [[Terrain Tools and Terrain API]], [[Grid Placement and Player Building Systems]], [[Foliage Props and Scatter]].
- Materials and lighting: [[Materials and Surfaces Start Here]], [[Baking Lighting and Detail into Textures]], [[Stylized Lighting Recipes]].
- Automation: [[Procedural Blender Assets Start Here]], [[Blender Automation with Python]].

## Connected notes
<!-- auto-links:start -->
[[Untextured Stylised Modelling Start Here]] · Modelling Nuance Start Here · Modeling in Blender for Roblox · Flat Colour vs Gradient Atlas vs Vertex Colour · Bevels Chamfers and Edge Highlights Without Textures · Skill - Roblox Asset Import
<!-- auto-links:end -->
