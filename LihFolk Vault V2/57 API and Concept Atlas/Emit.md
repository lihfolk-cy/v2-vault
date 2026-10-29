---
tags: [atlas, api, type/atlas, area/vfx, area/performance, api/Emit]
---
# Emit

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Emit` defaults to 16 particles when called with no count.
> - Bursts via `Emit` with your own quality scaling; streams capped.
> - Bursts via `Emit`, sustained effects via `Rate`; budgets stay under 400/s per emitter.
> - One shared animation loop with phase offsets; glint via occasional `Emit`.
>
> Cost: TL;DR ~110 tok · whole note ~630 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Emit` defaults to 16 particles when called with no count. (from [[ParticleEmitter - Engine Reference Card]])

API snapshot: member of `ParticleEmitter`, `ParticleEmitter2D` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Bursts via `Emit` with your own quality scaling; streams capped. ([[Particle Emitters In Depth]])
- Bursts via `Emit`, sustained effects via `Rate`; budgets stay under 400/s per emitter. ([[ParticleEmitter - Engine Reference Card]])
- One shared animation loop with phase offsets; glint via occasional `Emit`. ([[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]])
- Low mode still stutters in fights: Ability VFX emit fixed counts -> Route every `Emit` through the scale helper. ([[Graphics and Performance Toggles for Low-End Devices]])

## Mentioned in

26 notes in 13 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Testing Modes - Play Run and Multi-Client]]

### 07 Lighting VFX and Audio
[[Auras, Shields and Status Effects]] · [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]] · [[Designing VFX Textures and Flipbooks in Figma]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[Particle Emitters In Depth]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Slash VFX Recipes - Crescent and Ring]] · [[VFX Performance Budgets and Culling]]

### 08 Animation
[[Testing Animations in Studio]] · [[VFX Timing with Animation]]

### 12 Performance Testing and Debugging
[[Memory Budgets and Leaks]] · [[Performance Fundamentals]] · [[Rendering Performance]] · [[Testing Strategies and Frameworks]]

### 14 3D Modeling
[[Texturing and PBR Baking]]

### 15 AI Tools
[[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]]

### 16 MCP and Agents
[[MCP Workflows for Scripting and Debugging]] · [[Roblox Studio MCP Server]]

### 17 Pipelines
[[Icon and Thumbnail Rendering Pipeline]]

### 47 Game Feel and Juice
[[Juice on a Budget - Mobile and Low-End]]

### 58 Player QoL and Game Tweaks
[[Graphics and Performance Toggles for Low-End Devices]]

### 61 Thumbnails and CTR
[[Making Thumbnails in Studio and Blender - Capture, Lighting and Posing]]

### 62 Engine Reference Cards
[[ParticleEmitter - Engine Reference Card]]

Also mentioned in (not linked): Working with AI Assistants in Studio

<!-- atlas:generated -->
