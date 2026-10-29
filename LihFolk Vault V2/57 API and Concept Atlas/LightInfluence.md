---
tags: [atlas, api, type/atlas, area/vfx, area/ui, api/LightInfluence]
---
# LightInfluence

<!-- tldr:start -->
> [!tldr] TL;DR
> - `LightInfluence` set explicitly on every VFX emitter (usually 0).
> - Effect dark in caves, grey in shade: `LightInfluence` 1 (Studio insert default) -> Set 0 explicitly.
> - Emitter built in code looks different from the Studio template: Different `LightInfluence` defaults between insert paths ->...
> - VFX ribbons at LightInfluence 0 with appropriate LightEmission.
>
> Cost: TL;DR ~130 tok · whole note ~330 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`LightInfluence` set explicitly on every VFX emitter (usually 0). (from [[Particle Emitters In Depth]])

API snapshot: member of `Beam`, `BillboardGui`, `ParticleEmitter`, `SurfaceGui` and 1 more (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Effect dark in caves, grey in shade: `LightInfluence` 1 (Studio insert default) -> Set 0 explicitly. ([[Particle Emitters In Depth]])
- Emitter built in code looks different from the Studio template: Different `LightInfluence` defaults between insert paths -> Set every property explicitly in code or... ([[Particle Emitters In Depth]])
- VFX ribbons at LightInfluence 0 with appropriate LightEmission. ([[Beams and Trails]])

## Mentioned in

8 notes in 3 sections. The 8 most relevant are linked:

### 05 UI and UX
[[Nametags and Overhead Bars - Cost and Visibility Rules]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Beams and Trails]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Particle Emitters In Depth]] · [[Stylized Lighting Recipes]]

### 24 Worked Builds
[[Global Leaderboards End to End]]

<!-- atlas:generated -->
