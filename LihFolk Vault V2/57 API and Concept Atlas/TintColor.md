---
tags: [atlas, api, type/atlas, area/vfx, area/world, api/TintColor]
---
# TintColor

<!-- tldr:start -->
> [!tldr] TL;DR
> - `TintColor` is multiplicative per channel and `Saturation` changes intensity, so neither can move red information into the...
> - `ColorCorrectionEffect` owned by the weather renderer: push `Brightness` up (e.g. +0.3 to +0.5) and slightly cool `TintColor`...
> - `ColorCorrectionEffect` (`Brightness`, `Contrast`, `Saturation`, `TintColor`) and `BlurEffect` (`Size`) under `Lighting` or...
>
> Cost: TL;DR ~140 tok · whole note ~350 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`TintColor` is multiplicative per channel and `Saturation` changes intensity, so neither can move red information into the blue-yellow axis, which is what a correction filter needs. (from [[Colour-Blind Safe Design]])

API snapshot: member of `ColorCorrectionEffect` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `ColorCorrectionEffect` owned by the weather renderer: push `Brightness` up (e.g. +0.3 to +0.5) and slightly cool `TintColor`, then decay over 0.15-0.3 s. ([[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]])
- `ColorCorrectionEffect` (`Brightness`, `Contrast`, `Saturation`, `TintColor`) and `BlurEffect` (`Size`) under `Lighting` or the `Camera` apply to the whole 3D view (Roblox docs). ([[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]])

## Mentioned in

6 notes in 3 sections. The 6 most relevant are linked:

### 06 World Building and Art
[[Zone and Biome Art Direction]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Stylized Lighting Recipes]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]]

<!-- atlas:generated -->
