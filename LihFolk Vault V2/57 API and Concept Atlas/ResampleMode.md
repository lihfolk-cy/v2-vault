---
tags: [atlas, api, type/atlas, area/2d, area/ui, api/ResampleMode]
---
# ResampleMode

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ResampleMode` has `Default` (bilinear filtering) and `Pixelated` (nearest-neighbour, "keeps sharp pixel edges") per the docs.
> - Blockbench pixel art looks blurry in game: Bilinear filtering on `TextureID` -> SurfaceAppearance ColorMap with `ResampleMode...
> - Sprite soft everywhere: `ResampleMode` left at Default -> Property on the ImageLabel itself, not a parent.
> - `ResampleMode` (`Enum.ResamplerMode`, items `Default` and `Pixelated`): by default "the image smooths out texturing when...
>
> Cost: TL;DR ~160 tok · whole note ~520 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ResampleMode` has `Default` (bilinear filtering) and `Pixelated` (nearest-neighbour, "keeps sharp pixel edges") per the docs. (from [[SurfaceAppearance PBR Workflow]])

API snapshot: member of `Decal`, `ImageButton`, `ImageLabel`, `SurfaceAppearance` and 1 more (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Blockbench pixel art looks blurry in game: Bilinear filtering on `TextureID` -> SurfaceAppearance ColorMap with `ResampleMode = Pixelated` ([[MagicaVoxel Goxel and Blockbench Workflows Compared]])
- Sprite soft everywhere: `ResampleMode` left at Default -> Property on the ImageLabel itself, not a parent. ([[Pixel Art Pipeline - Aseprite to Roblox Without Blur]])
- `ResampleMode` (`Enum.ResamplerMode`, items `Default` and `Pixelated`): by default "the image smooths out texturing when displayed on the screen larger or smaller than its size in texture memory. ([[Sprite Sheets and Frame Animation with ImageRectOffset]])
- `SurfaceAppearance` with ColorMap = the palette: allows `Color` tinting (TintMask) or base-colour reveal (Overlay with alpha), and exposes `ResampleMode`. ([[The Gradient Palette Texture Workflow]])

## Mentioned in

11 notes in 7 sections. The 11 most relevant are linked:

### 05 UI and UX
[[Minimap and World Map UI - Projection, Rotation and Fog of War]]

### 14 3D Modeling
[[Texturing and PBR Baking]]

### 44 Materials and Surfaces
[[SurfaceAppearance PBR Workflow]]

### 51 2D Game Development
[[2D Game Development Start Here]] · [[Choosing GUI 2D or Locked-Camera 2.5D]] · [[EditableImage for Pixel Buffers and Procedural 2D]] · [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] · [[Sprite Sheets and Frame Animation with ImageRectOffset]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]]

### 54 Untextured Stylised Modelling
[[The Gradient Palette Texture Workflow]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
