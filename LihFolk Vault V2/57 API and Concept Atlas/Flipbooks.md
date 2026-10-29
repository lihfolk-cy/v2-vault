---
tags: [atlas, concept, type/atlas, area/vfx, area/modeling]
---
# Flipbooks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Flipbooks are 1024 x 1024 frames with a 2x2, 4x4 or 8x8 grid, one clipped frame per cell, in play order.
> - Avoid: Flipbook sheets that are not 1024 x 1024, or exported with trim on.
> - The editor's incompatibility message reads "Particle texture must be 1024 by 1024 to use flipbooks" (API dump), while the...
> - The reference VFX used 4 x 4 greyscale flipbooks tinted per element.
>
> Cost: TL;DR ~140 tok · whole note ~480 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Flipbooks are 1024 x 1024 frames with a 2x2, 4x4 or 8x8 grid, one clipped frame per cell, in play order. (from [[Designing VFX Textures and Flipbooks in Figma]])

## Key facts

- Avoid: Flipbook sheets that are not 1024 x 1024, or exported with trim on. ([[Designing VFX Textures and Flipbooks in Figma]])
- The editor's incompatibility message reads "Particle texture must be 1024 by 1024 to use flipbooks" (API dump), while the reference page says the size must be an exact multiple of the layout. ([[Particle Emitters In Depth]])
- The reference VFX used 4 x 4 greyscale flipbooks tinted per element. ([[UI and GUI Animation]])

## Mentioned in

19 notes in 9 sections. The 19 most relevant are linked:

### 07 Lighting VFX and Audio
[[Designing VFX Textures and Flipbooks in Figma]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Particle Emitters In Depth]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Slash VFX Recipes - Crescent and Ring]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[VFX Design Playbook]]

### 08 Animation
[[Facial Animation and Dynamic Heads]] · [[UI and GUI Animation]]

### 09 Gameplay Systems
[[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]]

### 12 Performance Testing and Debugging
[[Weather Performance Budgets and Quality Tiers]]

### 14 3D Modeling
[[Hand-Painted and Stylized Texturing]] · [[Substance Painter and Texturing Tools]] · [[Texturing and PBR Baking]] · [[Trim Sheets Atlases and Vertex Colors]]

### 47 Game Feel and Juice
[[Juice on a Budget - Mobile and Low-End]]

### 51 2D Game Development
[[Sprite Sheets and Frame Animation with ImageRectOffset]]

### 62 Engine Reference Cards
[[ParticleEmitter - Engine Reference Card]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
