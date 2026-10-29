---
tags: [atlas, api, type/atlas, area/materials, area/world, api/MaterialService]
---
# MaterialService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `MaterialService` contents replicate like other services' contents (rule of thumb; confirm in your place by checking a...
> - Avoid: Variant parked outside `MaterialService` -> Keep live variants under `MaterialService`, themes elsewhere.
> - MaterialVariants live in MaterialService with a stable naming convention.
> - Shared everything. Trim sheets for kits, a material library of 15 to 30 variants for the whole game, templates for every...
>
> Cost: TL;DR ~150 tok · whole note ~540 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`MaterialService` contents replicate like other services' contents (rule of thumb; confirm in your place by checking a client's Explorer during a test). (from [[MaterialService and Custom Materials]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Variant parked outside `MaterialService` -> Keep live variants under `MaterialService`, themes elsewhere. ([[MaterialService and Custom Materials]])
- MaterialVariants live in MaterialService with a stable naming convention. ([[Materials MaterialVariants and SurfaceAppearance]])
- Shared everything. Trim sheets for kits, a material library of 15 to 30 variants for the whole game, templates for every SurfaceAppearance (MaterialService and Custom Materials, SurfaceAppearance PBR Workflow). ([[Stylised vs Realistic Material Pipelines]])
- Walkable surfaces that must be precise. Obby platforms, race tracks and tower defense lanes need exact collision edges; use parts and paint them with MaterialVariants (MaterialService and Custom Materials). ([[Terrain Materials and Painting]])

## Mentioned in

16 notes in 7 sections. The 16 most relevant are linked:

### 06 World Building and Art
[[Materials MaterialVariants and SurfaceAppearance]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Terrain Tools and Terrain API]]

### 07 Lighting VFX and Audio
[[Rain - Camera-Local Particles, Splashes and Wet Surfaces]]

### 15 AI Tools
[[AI Material and Texture Generation]]

### 44 Materials and Surfaces
[[MaterialService and Custom Materials]] · [[Materials and Surfaces Start Here]] · [[Procedural Materials and Skies - Lessons]] · [[Stylised vs Realistic Material Pipelines]] · [[SurfaceAppearance PBR Workflow]] · [[Terrain Materials and Painting]] · [[Tiling Trim Sheets and Decal Tricks]]

### 46 Resource Library
[[Official Docs - Building and World]]

### 52 Core Concepts
[[Texel Density]]

### Root notes
[[00 Start Here]] · [[Open Questions - Whole Vault]]

<!-- atlas:generated -->
