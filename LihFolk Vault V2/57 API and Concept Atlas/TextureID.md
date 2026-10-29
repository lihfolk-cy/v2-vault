---
tags: [atlas, api, type/atlas, area/modeling, area/world, api/TextureID]
---
# TextureID

<!-- tldr:start -->
> [!tldr] TL;DR
> - `TextureID` can change at runtime. `SurfaceAppearance` maps cannot (see Materials MaterialVariants and SurfaceAppearance).
> - TextureID wins over Material. A MeshPart with a TextureID ignores Material changes until the TextureID is cleared (measured).
> - Blockbench pixel art looks blurry in game: Bilinear filtering on `TextureID` -> SurfaceAppearance ColorMap with `ResampleMode...
> - MeshParts with a palette `TextureID` ignore Material changes until the TextureID is cleared.
>
> Cost: TL;DR ~160 tok · whole note ~590 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`TextureID` can change at runtime. `SurfaceAppearance` maps cannot (see Materials MaterialVariants and SurfaceAppearance). (from [[Parts Unions and MeshParts]])

API snapshot: member of `MeshPart` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- TextureID wins over Material. A MeshPart with a TextureID ignores Material changes until the TextureID is cleared (measured). ([[Materials MaterialVariants and SurfaceAppearance]])
- Blockbench pixel art looks blurry in game: Bilinear filtering on `TextureID` -> SurfaceAppearance ColorMap with `ResampleMode = Pixelated` ([[MagicaVoxel Goxel and Blockbench Workflows Compared]])
- MeshParts with a palette `TextureID` ignore Material changes until the TextureID is cleared. ([[AI Material and Texture Generation]])

## Mentioned in

27 notes in 10 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Art Budgets - Triangles Draw Calls Memory]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Modeling in Blender for Roblox]] · [[Parts Unions and MeshParts]] · [[Textures Decals and Texture Memory]]

### 08 Animation
[[Facial Animation and Dynamic Heads]] · [[Layered Clothing Cages and Animation]] · [[Weapon Design Rig Builder]]

### 12 Performance Testing and Debugging
[[Rendering Performance]]

### 13 Production and Case Studies
[[Asset Pipelines]]

### 14 3D Modeling
[[Low-Poly and Stylized Modeling]] · [[Mesh Optimization for Mobile]] · [[Modeling Fundamentals for Games]] · [[Modular Environment Kits]] · [[Texturing and PBR Baking]] · [[Trim Sheets Atlases and Vertex Colors]] · [[UV Unwrapping]]

### 15 AI Tools
[[AI Material and Texture Generation]] · [[AI Pitfalls - Assets and Import]]

### 17 Pipelines
[[Art Pipeline - Concept to In-Game Asset]] · [[Character and Creature Pipeline]]

### 44 Materials and Surfaces
[[SurfaceAppearance PBR Workflow]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]]

### 54 Untextured Stylised Modelling
[[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[The Gradient Palette Texture Workflow]]

Also mentioned in (not linked): Materials and Surfaces Start Here · Untextured Stylised Modelling Start Here

<!-- atlas:generated -->
