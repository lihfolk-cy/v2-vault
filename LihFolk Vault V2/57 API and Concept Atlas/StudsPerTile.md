---
tags: [atlas, api, type/atlas, area/materials, area/world, api/StudsPerTile]
---
# StudsPerTile

<!-- tldr:start -->
> [!tldr] TL;DR
> - StudsPerTile set from density or real-world size, checked next to an avatar.
> - Put the image on a large flat part with `StudsPerTile` small enough to show sixteen repeats, and look from a distance and at a...
> - Scale up. Raise `StudsPerTile` 1.5 to 2 times so features are big enough to read at avatar scale on a phone.
> - For repeating surfaces in Roblox, use built-in materials or `MaterialVariant` (which tile in world space by `StudsPerTile`)...
>
> Cost: TL;DR ~150 tok · whole note ~400 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

StudsPerTile set from density or real-world size, checked next to an avatar. (from [[MaterialService and Custom Materials]])

API snapshot: member of `MaterialVariant`, `TerrainDetail` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Put the image on a large flat part with `StudsPerTile` small enough to show sixteen repeats, and look from a distance and at a low angle. ([[Tiling Trim Sheets and Decal Tricks]])
- Scale up. Raise `StudsPerTile` 1.5 to 2 times so features are big enough to read at avatar scale on a phone. ([[Stylised vs Realistic Material Pipelines]])
- For repeating surfaces in Roblox, use built-in materials or `MaterialVariant` (which tile in world space by `StudsPerTile`), or a `Texture` object on a part face, or bake the repetition into the image. ([[UV Unwrapping]])

## Mentioned in

11 notes in 5 sections. The 11 most relevant are linked:

### 06 World Building and Art
[[Materials MaterialVariants and SurfaceAppearance]] · [[Textures Decals and Texture Memory]] · [[Voxel Art - Studs Outlines and Style Kits]]

### 14 3D Modeling
[[UV Unwrapping]]

### 15 AI Tools
[[AI Material and Texture Generation]]

### 44 Materials and Surfaces
[[MaterialService and Custom Materials]] · [[Materials and Surfaces Start Here]] · [[Stylised vs Realistic Material Pipelines]] · [[Terrain Materials and Painting]] · [[Tiling Trim Sheets and Decal Tricks]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
