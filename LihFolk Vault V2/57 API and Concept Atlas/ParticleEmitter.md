---
tags: [atlas, api, type/atlas, area/vfx, area/animation, api/ParticleEmitter]
---
# ParticleEmitter

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ParticleEmitter` is the workhorse of Roblox VFX: sparks, smoke, slash cards, ground rings, flashes, rain, auras and magic...
> - `ParticleEmitter:Emit(count)` spawns a burst immediately (Roblox docs).
> - No particles. `ParticleEmitter` needs a 3D parent.
> - Glint, not glow. A periodic star sparkle (one `ParticleEmitter:Emit(1)` every 1.5 to 3 s, random per item) reads better and...
>
> Cost: TL;DR ~140 tok · whole note ~680 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ParticleEmitter` is the workhorse of Roblox VFX: sparks, smoke, slash cards, ground rings, flashes, rain, auras and magic dust are all camera-facing (or velocity-aligned) textured quads with a few curves. (from [[Particle Emitters In Depth]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `ParticleEmitter:Emit(count)` spawns a burst immediately (Roblox docs). ([[Rain - Camera-Local Particles, Splashes and Wet Surfaces]])
- No particles. `ParticleEmitter` needs a 3D parent. ([[Choosing GUI 2D or Locked-Camera 2.5D]])
- Glint, not glow. A periodic star sparkle (one `ParticleEmitter:Emit(1)` every 1.5 to 3 s, random per item) reads better and costs less than a constant emitter on every coin. ([[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]])
- Retuning ParticleEmitter properties every frame. ([[Rendering Performance]])

## Mentioned in

28 notes in 14 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Foliage Props and Scatter]]

### 07 Lighting VFX and Audio
[[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Light Sources and Shadows]] · [[Particle Emitters In Depth]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Slash VFX Recipes - Crescent and Ring]] · [[VFX Design Playbook]] · [[VFX Performance Budgets and Culling]] · [[VFX Previews in Blender for Roblox - Colour and Framing]]

### 08 Animation
[[Engine Gotchas]] · [[Scale and Animation]] · [[UI and GUI Animation]] · [[VFX Timing with Animation]]

### 09 Gameplay Systems
[[Chase Cameras and Speed Effects for Vehicles]]

### 12 Performance Testing and Debugging
[[Client Zone Culling for Interiors and Cities]] · [[Rendering Performance]]

### 13 Production and Case Studies
[[Planning and Scoping a Roblox Game]]

### 14 3D Modeling
[[Trim Sheets Atlases and Vertex Colors]]

### 15 AI Tools
[[AI Pitfalls - Assets and Import]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]]

### 47 Game Feel and Juice
[[Juice on a Budget - Mobile and Low-End]]

### 49 Roblox Platform Features
[[Photo Mode and In-Game Screenshots with CaptureService]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]]

### 58 Player QoL and Game Tweaks
[[Graphics and Performance Toggles for Low-End Devices]]

Also mentioned in (not linked): Links - Particle emitters · Voxel Art - Studs Outlines and Style Kits · Voxel and Blocky Modeling

<!-- atlas:generated -->
