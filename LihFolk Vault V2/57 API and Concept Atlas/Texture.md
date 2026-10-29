---
tags: [atlas, api, type/atlas, area/world, area/vfx, api/Texture]
---
# Texture

<!-- tldr:start -->
> [!tldr] TL;DR
> - Texture memory checked in the Developer Console on a phone.
> - Solid coloured slab instead of the texture: Texture not loaded (or invalid id) -> Preload; new uploads need about a minute.
> - Inserting the decal in Studio and reading its `Texture`, or the asset's image id in the Creator Dashboard, gives the right number.
> - Texture sizes justified; trim sheets shared.
>
> Cost: TL;DR ~130 tok · whole note ~420 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Texture memory checked in the Developer Console on a phone. (from [[Textures Decals and Texture Memory]])

API snapshot: class, inherits `Decal` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Solid coloured slab instead of the texture: Texture not loaded (or invalid id) -> Preload; new uploads need about a minute. ([[Beams and Trails]])
- Inserting the decal in Studio and reading its `Texture`, or the asset's image id in the Creator Dashboard, gives the right number. ([[AI Pitfalls - Assets and Import]])
- Texture sizes justified; trim sheets shared. ([[Art Budgets - Triangles Draw Calls Memory]])

## Mentioned in

15 notes in 8 sections. The 15 most relevant are linked:

### 06 World Building and Art
[[Art Budgets - Triangles Draw Calls Memory]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Roads, Rivers and Paths Carved Along Curves in Terrain]] · [[Textures Decals and Texture Memory]] · [[Voxel Art - Studs Outlines and Style Kits]] · [[Water Sky and Atmosphere Art]]

### 07 Lighting VFX and Audio
[[Beams and Trails]] · [[Particle Emitters In Depth]]

### 13 Production and Case Studies
[[Template Reskin Checklist - One Codebase, New Game]]

### 14 3D Modeling
[[UV Unwrapping]]

### 15 AI Tools
[[AI Pitfalls - Assets and Import]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]]

### 44 Materials and Surfaces
[[Tiling Trim Sheets and Decal Tricks]]

### 51 2D Game Development
[[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] · [[Tilemaps Cameras and Parallax for 2D Levels]]

<!-- atlas:generated -->
