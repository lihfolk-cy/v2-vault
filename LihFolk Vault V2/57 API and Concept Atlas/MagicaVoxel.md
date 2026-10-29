---
tags: [atlas, concept, type/atlas, area/modeling]
---
# MagicaVoxel

<!-- tldr:start -->
> [!tldr] TL;DR
> - MagicaVoxel is the fastest tool for hand-built voxel art: box, voxel, face and line brushes, mirror modes, a pattern brush...
> - MagicaVoxel glow voxels are dull in Studio: Emit material does not export -> Separate the glow colour group; give it Neon or...
> - Export OBJ. MagicaVoxel's OBJ export uses the palette texture with each face's UVs pointing at its colour: a palette atlas...
> - Watertight greedy meshing. The Blender "MagicaVoxel VOX format" importer extension offers a watertight variant of its greedy...
>
> Cost: TL;DR ~170 tok · whole note ~520 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

MagicaVoxel is the fastest tool for hand-built voxel art: box, voxel, face and line brushes, mirror modes, a pattern brush, and a renderer good enough for icons and store thumbnails. (from [[MagicaVoxel Goxel and Blockbench Workflows Compared]])

## Key facts

- MagicaVoxel glow voxels are dull in Studio: Emit material does not export -> Separate the glow colour group; give it Neon or an emissive... ([[MagicaVoxel Goxel and Blockbench Workflows Compared]])
- Export OBJ. MagicaVoxel's OBJ export uses the palette texture with each face's UVs pointing at its colour: a palette atlas, exactly the cheap colouring method from Low-Poly and Stylized Modeling. ([[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]])
- Watertight greedy meshing. The Blender "MagicaVoxel VOX format" importer extension offers a watertight variant of its greedy mode that removes T-junctions (tool docs). ([[Meshing Voxels for Roblox - Greedy Meshing and Export]])
- MagicaVoxel writes one voxel as one unit in its OBJ export (tool docs and community documentation; see Other Modeling Tools - Maya Max ZBrush MagicaVoxel). ([[Voxel Scale Grids and Stud Alignment]])

## Mentioned in

14 notes in 4 sections. The 14 most relevant are linked:

### 14 3D Modeling
[[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Retopology and Decimation]] · [[Substance Painter and Texturing Tools]] · [[Voxel and Blocky Modeling]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Voxel Modelling Start Here]] · [[Voxel Palettes - Ramps Hue Shifting and Limits]] · [[Voxel Props Environments and Modular Tiles]] · [[Voxel Scale Grids and Stud Alignment]]

### 54 Untextured Stylised Modelling
[[Keeping a Mixed Asset Library Consistent]]

### Root notes
[[00 Start Here]] · [[Open Questions - Whole Vault]]

<!-- atlas:generated -->
