---
tags: [atlas, api, type/atlas, area/vfx, area/physics, api/Beam]
---
# Beam

<!-- tldr:start -->
> [!tldr] TL;DR
> - A Beam draws a cubic Bezier between its two attachments: P1 is `CurveSize0` studs along `Attachment0`'s right (X) axis, P2 is...
> - Beam missing: One attachment missing, same attachment twice, or not in Workspace -> Two distinct attachments in Workspace.
> - Beam chains share one attachment per point; `FaceCamera` on for lines and cables.
> - Sheet or arc: a `Beam` with a scrolling texture (`TextureSpeed`) curved via `CurveSize0/1`, or a swept mesh.
>
> Cost: TL;DR ~150 tok · whole note ~600 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A Beam draws a cubic Bezier between its two attachments: P1 is `CurveSize0` studs along `Attachment0`'s right (X) axis, P2 is `CurveSize1` studs back along `Attachment1`'s right axis (Roblox docs; details in Beams and Trails). (from [[Curves in Luau - Paths Beams and Motion]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Beam missing: One attachment missing, same attachment twice, or not in Workspace -> Two distinct attachments in Workspace. ([[Beams and Trails]])
- Beam chains share one attachment per point; `FaceCamera` on for lines and cables. ([[Curves in Luau - Paths Beams and Motion]])
- Sheet or arc: a `Beam` with a scrolling texture (`TextureSpeed`) curved via `CurveSize0/1`, or a swept mesh. ([[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]])
- Hairline streaks need low Beam brightness. Bloom fattens bright thin Beams into bars; keep `Brightness` low and let `LightEmission` and the texture do the work (Measured, void impact). ([[VFX Readability and Value - Lessons from Blind Reviews]])

## Mentioned in

19 notes in 10 sections. The 19 most relevant are linked:

### 06 World Building and Art
[[Roads, Rivers and Paths Carved Along Curves in Terrain]]

### 07 Lighting VFX and Audio
[[Beams and Trails]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Light Sources and Shadows]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Slash VFX Recipes - Crescent and Ring]] · [[VFX Design Playbook]] · [[VFX Performance Budgets and Culling]] · [[VFX Previews in Blender for Roblox - Colour and Framing]] · [[VFX Readability and Value - Lessons from Blind Reviews]]

### 08 Animation
[[Debugging Animation Problems]]

### 14 3D Modeling
[[Bezier Curves and Splines for Modellers]]

### 24 Worked Builds
[[Quest Chain System End to End]]

### 25 Physics and Vehicles
[[Projectiles and Ballistics]] · [[Ropes Chains and Soft Bodies]]

### 40 Game Math
[[Curves in Luau - Paths Beams and Motion]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]]

### 45 Procedural Blender Assets
[[Dash VFX Presentation on an R15 Rig]]

### 46 Resource Library
[[Links - Beams and trails]]

<!-- atlas:generated -->
