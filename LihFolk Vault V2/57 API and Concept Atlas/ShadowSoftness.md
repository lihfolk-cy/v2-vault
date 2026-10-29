---
tags: [atlas, api, type/atlas, area/materials, area/vfx, api/ShadowSoftness]
---
# ShadowSoftness

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ShadowSoftness` only applies with ShadowMap or Future and when "the device can render shadow maps".
> - `ShadowSoftness` only applies with `LightingStyle = Realistic` (Roblox docs, as of October 2026).
> - Lighting quality varies by device. `ShadowSoftness` only works with ShadowMap or Future technology on devices that can render...
>
> Cost: TL;DR ~120 tok · whole note ~290 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ShadowSoftness` only applies with ShadowMap or Future and when "the device can render shadow maps". (from [[Baking Lighting and Detail into Textures]])

API snapshot: member of `Lighting` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `ShadowSoftness` only applies with `LightingStyle = Realistic` (Roblox docs, as of October 2026). ([[Lighting Untextured Art in Roblox]])
- Lighting quality varies by device. `ShadowSoftness` only works with ShadowMap or Future technology on devices that can render shadow maps, and quality scales down on weaker hardware (Roblox docs). ([[Stylised vs Realistic Material Pipelines]])

## Mentioned in

5 notes in 4 sections. The 5 most relevant are linked:

### 07 Lighting VFX and Audio
[[Lighting Technologies and Settings]]

### 44 Materials and Surfaces
[[Baking Lighting and Detail into Textures]] · [[Stylised vs Realistic Material Pipelines]]

### 54 Untextured Stylised Modelling
[[Lighting Untextured Art in Roblox]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
