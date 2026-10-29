---
tags: [atlas, api, type/atlas, area/vfx, area/modeling, api/ColorCorrectionEffect]
---
# ColorCorrectionEffect

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ColorCorrectionEffect` is still useful for testing: docs state `Saturation` reaches full desaturation at -1, which gives a...
> - Avoid: Several scripts tweening the same `ColorCorrectionEffect`.
> - Greyscale pass in Studio. Insert a `ColorCorrectionEffect` under `Lighting` with `Saturation = -1` and play a session.
> - `ColorCorrectionEffect` shifts everything at the end.
>
> Cost: TL;DR ~130 tok · whole note ~640 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ColorCorrectionEffect` is still useful for testing: docs state `Saturation` reaches full desaturation at -1, which gives a quick greyscale view of the real scene in Studio. (from [[Colour-Blind Safe Design]])

API snapshot: class, inherits `PostEffect` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Several scripts tweening the same `ColorCorrectionEffect`. ([[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]])
- Greyscale pass in Studio. Insert a `ColorCorrectionEffect` under `Lighting` with `Saturation = -1` and play a session. ([[Colour-Blind Safe Design]])
- `ColorCorrectionEffect` shifts everything at the end. ([[Colour Scripts and Value Structure for Untextured Art]])
- Greyscale check. Desaturate a screenshot (or set a temporary `ColorCorrectionEffect` with `Saturation = -1`). ([[Voxel Palettes - Ramps Hue Shifting and Limits]])

## Mentioned in

21 notes in 12 sections. The 21 most relevant are linked:

### 06 World Building and Art
[[Zone and Biome Art Direction]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Stylized Lighting Recipes]]

### 08 Animation
[[Camera Shake and Camera FX]] · [[Snippets - Camera Shake and FX]]

### 09 Gameplay Systems
[[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]

### 33 Level Design
[[Instanced Interiors - Pooled House and Room Copies for Many Players]]

### 42 Accessibility and Inclusive Design
[[Accessibility Start Here]] · [[Colour-Blind Safe Design]]

### 47 Game Feel and Juice
[[Juice on a Budget - Mobile and Low-End]]

### 49 Roblox Platform Features
[[Photo Mode and In-Game Screenshots with CaptureService]]

### 53 Voxel Modelling Deep Dive
[[Voxel Palettes - Ramps Hue Shifting and Limits]]

### 54 Untextured Stylised Modelling
[[Colour Scripts and Value Structure for Untextured Art]] · [[Lighting Untextured Art in Roblox]] · [[Untextured Stylised Modelling Start Here]]

### 55 Modelling Nuance and Readability
[[Critiquing a Model - Paintovers and Iteration]]

### 58 Player QoL and Game Tweaks
[[Graphics and Performance Toggles for Low-End Devices]]

<!-- atlas:generated -->
