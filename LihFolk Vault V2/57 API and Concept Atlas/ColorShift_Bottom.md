---
tags: [atlas, api, type/atlas, area/vfx, area/modeling, api/ColorShift_Bottom]
---
# ColorShift_Bottom

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ColorShift_Bottom` can add a ground bounce colour (a green tint in a meadow, an orange one in a desert) to downward faces...
> - Faces facing away from the sun also pick up `ColorShift_Bottom`.
> - Sun-facing faces get `Brightness`-scaled direct light tinted by `ColorShift_Top`; shadowed faces get `Ambient` or...
>
> Cost: TL;DR ~120 tok · whole note ~290 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ColorShift_Bottom` can add a ground bounce colour (a green tint in a meadow, an orange one in a desert) to downward faces, depending on sun position. (from [[Lighting Untextured Art in Roblox]])

API snapshot: member of `Lighting` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Faces facing away from the sun also pick up `ColorShift_Bottom`. ([[Lighting Untextured Art in Roblox]])
- Sun-facing faces get `Brightness`-scaled direct light tinted by `ColorShift_Top`; shadowed faces get `Ambient` or `OutdoorAmbient` (and `ColorShift_Bottom`); see Lighting Technologies and Settings. ([[Colour Scripts and Value Structure for Untextured Art]])

## Mentioned in

5 notes in 2 sections. The 5 most relevant are linked:

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Lighting Technologies and Settings]] · [[Stylized Lighting Recipes]]

### 54 Untextured Stylised Modelling
[[Colour Scripts and Value Structure for Untextured Art]] · [[Lighting Untextured Art in Roblox]]

<!-- atlas:generated -->
