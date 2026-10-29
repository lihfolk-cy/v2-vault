---
tags: [atlas, api, type/atlas, area/vfx, area/ui, api/FaceCamera]
---
# FaceCamera

<!-- tldr:start -->
> [!tldr] TL;DR
> - `FaceCamera = true` sidesteps most width-orientation problems for VFX ribbons, so it is the usual starting point for slash...
> - Taper it: wide `Width0`, `Width1 = 0`, `FaceCamera = true`, enough `Segments` for a smooth curve, `LightEmission = 1`.
> - Beam chains share one attachment per point; `FaceCamera` on for lines and cables.
>
> Cost: TL;DR ~120 tok · whole note ~280 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`FaceCamera = true` sidesteps most width-orientation problems for VFX ribbons, so it is the usual starting point for slash arcs (Rule of thumb). (from [[Beams and Trails]])

API snapshot: member of `Beam`, `Trail` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Taper it: wide `Width0`, `Width1 = 0`, `FaceCamera = true`, enough `Segments` for a smooth curve, `LightEmission = 1`. ([[Beams and Trails]])
- Beam chains share one attachment per point; `FaceCamera` on for lines and cables. ([[Curves in Luau - Paths Beams and Motion]])

## Mentioned in

6 notes in 3 sections. The 6 most relevant are linked:

### 05 UI and UX
[[Tutorial Step Design Patterns - Teach by Doing]]

### 07 Lighting VFX and Audio
[[Beams and Trails]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Projectile VFX - Muzzle, Travel and Impact]] · [[Slash VFX Recipes - Crescent and Ring]]

### 40 Game Math
[[Curves in Luau - Paths Beams and Motion]]

<!-- atlas:generated -->
