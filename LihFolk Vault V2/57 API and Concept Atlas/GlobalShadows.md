---
tags: [atlas, api, type/atlas, area/vfx, area/modeling, api/GlobalShadows]
---
# GlobalShadows

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GlobalShadows = false` is a valid look for some stylised games and removes a class of problems (indoor darkness on badly...
> - Indoors is as bright as outdoors: `GlobalShadows` off, or `Ambient` channels above `OutdoorAmbient` -> Turn shadows on; keep...
> - `GlobalShadows` on unless the art style needs it off; interiors sealed and thick enough.
> - The no-shadow test. Set graphics quality to 1 to 3 in Studio's Editor Quality Level (or set `GlobalShadows` false briefly).
>
> Cost: TL;DR ~160 tok · whole note ~380 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GlobalShadows = false` is a valid look for some stylised games and removes a class of problems (indoor darkness on badly sealed buildings), but you lose the indoor/outdoor split. (from [[Lighting Technologies and Settings]])

API snapshot: member of `Lighting` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Indoors is as bright as outdoors: `GlobalShadows` off, or `Ambient` channels above `OutdoorAmbient` -> Turn shadows on; keep `Ambient` at or below `OutdoorAmbient` per... ([[Lighting Technologies and Settings]])
- `GlobalShadows` on unless the art style needs it off; interiors sealed and thick enough. ([[Lighting Technologies and Settings]])
- The no-shadow test. Set graphics quality to 1 to 3 in Studio's Editor Quality Level (or set `GlobalShadows` false briefly). ([[Stylized Lighting Recipes]])
- Blocked where `GlobalShadows` casts a shadow. ([[Lighting Untextured Art in Roblox]])

## Mentioned in

6 notes in 4 sections. The 6 most relevant are linked:

### 07 Lighting VFX and Audio
[[Lighting Technologies and Settings]] · [[Stylized Lighting Recipes]]

### 44 Materials and Surfaces
[[Baking Lighting and Detail into Textures]]

### 53 Voxel Modelling Deep Dive
[[Voxel Scale Grids and Stud Alignment]] · [[Voxel Shading - Baked AO Edges and Lighting]]

### 54 Untextured Stylised Modelling
[[Lighting Untextured Art in Roblox]]

<!-- atlas:generated -->
