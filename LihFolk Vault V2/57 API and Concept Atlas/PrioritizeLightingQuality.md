---
tags: [atlas, api, type/atlas, area/materials, area/modeling, api/PrioritizeLightingQuality]
---
# PrioritizeLightingQuality

<!-- tldr:start -->
> [!tldr] TL;DR
> - `PrioritizeLightingQuality` decides whether, as rendering quality reduces, advanced shadows are kept at the cost of view distance.
> - `LightingStyle` and `PrioritizeLightingQuality` chosen deliberately, not inherited from a template.
> - Lighting is chosen per place, not per object.
> - Low graphics levels. On lower quality levels shadows and some lighting detail are reduced (rule of thumb; Roblox describes the...
>
> Cost: TL;DR ~140 tok · whole note ~460 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`PrioritizeLightingQuality` decides whether, as rendering quality reduces, advanced shadows are kept at the cost of view distance. (from [[Lighting Untextured Art in Roblox]])

API snapshot: member of `Lighting` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `LightingStyle` and `PrioritizeLightingQuality` chosen deliberately, not inherited from a template. ([[Lighting Technologies and Settings]])
- Lighting is chosen per place, not per object. `Lighting.Technology` is deprecated and superseded by `LightingStyle` (`Realistic` or `Soft`) plus `PrioritizeLightingQuality`. ([[Baking Lighting and Detail into Textures]])
- Low graphics levels. On lower quality levels shadows and some lighting detail are reduced (rule of thumb; Roblox describes the trade in the `PrioritizeLightingQuality` property but does not list per-level features). ([[Flat Colour vs Gradient Atlas vs Vertex Colour]])
- Lighting style. `LightingStyle` (`Realistic` or `Soft`) and `PrioritizeLightingQuality` replaced the old `Technology` setting (Roblox docs, as of October 2026; see Lighting Technologies and Settings). ([[Voxel Shading - Baked AO Edges and Lighting]])

## Mentioned in

7 notes in 5 sections. The 7 most relevant are linked:

### 07 Lighting VFX and Audio
[[Lighting Technologies and Settings]]

### 44 Materials and Surfaces
[[Baking Lighting and Detail into Textures]] · [[SurfaceAppearance PBR Workflow]]

### 53 Voxel Modelling Deep Dive
[[Voxel Shading - Baked AO Edges and Lighting]]

### 54 Untextured Stylised Modelling
[[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Lighting Untextured Art in Roblox]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
