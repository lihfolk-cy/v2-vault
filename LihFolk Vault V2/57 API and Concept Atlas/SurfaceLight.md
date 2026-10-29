---
tags: [atlas, api, type/atlas, area/world, area/vfx, api/SurfaceLight]
---
# SurfaceLight

<!-- tldr:start -->
> [!tldr] TL;DR
> - SurfaceLight needs a `BasePart` face. (from Light Sources and Shadows)
> - Give the glow module Neon, and add real lights (a SurfaceLight per window, or one PointLight inside) if the light should spill...
> - Local lights: PointLight, SpotLight and SurfaceLight.
> - In Roblox, emission does not light the world: give the glow module Neon, and add real lights, a SurfaceLight per window or one...
>
> Cost: TL;DR ~140 tok · whole note ~340 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

SurfaceLight needs a `BasePart` face. (from [[Light Sources and Shadows]])

API snapshot: class, inherits `Light` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Give the glow module Neon, and add real lights (a SurfaceLight per window, or one PointLight inside) if the light should spill onto snow or ground. ([[House Construction Method - Modular Kit Workflow]])
- Local lights: PointLight, SpotLight and SurfaceLight. ([[Lighting Untextured Art in Roblox]])
- In Roblox, emission does not light the world: give the glow module Neon, and add real lights, a SurfaceLight per window or one PointLight inside, if the snow in front should glow (Lighting Technologies and Settings). ([[Stylised Log Cabin Worked Example]])

## Mentioned in

6 notes in 6 sections. The 6 most relevant are linked:

### 06 World Building and Art
[[House Construction Method - Modular Kit Workflow]]

### 07 Lighting VFX and Audio
[[Light Sources and Shadows]]

### 13 Production and Case Studies
[[Planning and Scoping a Roblox Game]]

### 45 Procedural Blender Assets
[[Stylised Log Cabin Worked Example]]

### 46 Resource Library
[[Links - Lighting]]

### 54 Untextured Stylised Modelling
[[Lighting Untextured Art in Roblox]]

<!-- atlas:generated -->
