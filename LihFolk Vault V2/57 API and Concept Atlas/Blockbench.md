---
tags: [atlas, concept, type/atlas, area/modeling]
---
# Blockbench

<!-- tldr:start -->
> [!tldr] TL;DR
> - Blockbench builds models from boxes, each with six UV-mapped faces, and paints a pixel texture onto them.
> - Blockbench pixel art looks blurry in game: Bilinear filtering on `TextureID` -> SurfaceAppearance ColorMap with `ResampleMode...
> - Avoid: Blockbench ASCII FBX into Blender -> Use glTF/GLB or OBJ.
> - Other Modeling Tools - Maya Max ZBrush MagicaVoxel: what MagicaVoxel and Blockbench are, and the unit traps of each tool.
>
> Cost: TL;DR ~150 tok · whole note ~360 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Blockbench builds models from boxes, each with six UV-mapped faces, and paints a pixel texture onto them. (from [[MagicaVoxel Goxel and Blockbench Workflows Compared]])

## Key facts

- Blockbench pixel art looks blurry in game: Bilinear filtering on `TextureID` -> SurfaceAppearance ColorMap with `ResampleMode = Pixelated` ([[MagicaVoxel Goxel and Blockbench Workflows Compared]])
- Avoid: Blockbench ASCII FBX into Blender -> Use glTF/GLB or OBJ. ([[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]])
- Other Modeling Tools - Maya Max ZBrush MagicaVoxel: what MagicaVoxel and Blockbench are, and the unit traps of each tool. ([[Voxel Modelling Start Here]])
- Export the palette as a MagicaVoxel palette image and as a Luau role table; load it in every tool (MagicaVoxel Goxel and Blockbench Workflows Compared). ([[Voxel Palettes - Ramps Hue Shifting and Limits]])

## Mentioned in

7 notes in 3 sections. The 7 most relevant are linked:

### 14 3D Modeling
[[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Voxel Modelling Start Here]] · [[Voxel Palettes - Ramps Hue Shifting and Limits]] · [[Voxel Scale Grids and Stud Alignment]]

### Root notes
[[00 Start Here]] · [[Open Questions - Whole Vault]]

<!-- atlas:generated -->
