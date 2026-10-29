---
tags: [atlas, api, type/atlas, area/vfx, area/modeling, api/Lighting]
---
# Lighting

<!-- tldr:start -->
> [!tldr] TL;DR
> - Lighting is global state, and Edit-mode previews leak.
> - Fog settings do nothing: An `Atmosphere` is in `Lighting` (fog properties are hidden and... -> Use `Atmosphere.Density`/`Haze`...
> - Avoid: Server tweens `Lighting` -> Server writes attributes, client interpolates.
> - Avoid: Effects parented to `Lighting` in a game that also uses lighting zones.
>
> Cost: TL;DR ~130 tok · whole note ~840 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Lighting is global state, and Edit-mode previews leak. (from [[Lighting Technologies and Settings]])

Lighting is relative: your materials, colours and camera change the result, so treat each recipe as the first draft you then tune by eye on a phone and a PC. (from [[Stylized Lighting Recipes]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Fog settings do nothing: An `Atmosphere` is in `Lighting` (fog properties are hidden and... -> Use `Atmosphere.Density`/`Haze` instead, or remove the Atmosphere. ([[Lighting Technologies and Settings]])
- Avoid: Server tweens `Lighting` -> Server writes attributes, client interpolates. ([[Weather System Architecture - State Machine, Transitions and Replication]])
- Avoid: Effects parented to `Lighting` in a game that also uses lighting zones. ([[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]])

## Mentioned in

39 notes in 21 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Client-Server Model]]

### 06 World Building and Art
[[Water Sky and Atmosphere Art]] · [[Zone and Biome Art Direction]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Light Sources and Shadows]] · [[Lighting Mood and Time of Day]] · [[Lighting Technologies and Settings]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Stylized Lighting Recipes]] · [[Weather System Architecture - State Machine, Transitions and Replication]]

### 08 Animation
[[Snippets - Camera Shake and FX]]

### 09 Gameplay Systems
[[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]

### 13 Production and Case Studies
[[Case Study - Instance Cleanup and Place Size]]

### 14 3D Modeling
[[Texturing and PBR Baking]]

### 15 AI Tools
[[Obsidian Vaults for AI Agents - Structure, Graph and Theming]]

### 33 Level Design
[[Instanced Interiors - Pooled House and Room Copies for Many Players]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]]

### 44 Materials and Surfaces
[[Baking Lighting and Detail into Textures]] · [[SurfaceAppearance PBR Workflow]]

### 50 Team Collaboration and Project Management
[[Packages and Shared Assets Across Places]]

### 54 Untextured Stylised Modelling
[[Colour Scripts and Value Structure for Untextured Art]] · [[Lighting Untextured Art in Roblox]]

### 55 Modelling Nuance and Readability
[[Bevels Chamfers and Edge Highlights Without Textures]] · [[Critiquing a Model - Paintovers and Iteration]]

### 58 Player QoL and Game Tweaks
[[Graphics and Performance Toggles for Low-End Devices]]

Also mentioned in (not linked): Creator Store and Toolbox Safety · Glossary · Hand-Painted and Stylized Texturing · Low-Poly and Stylized Modeling · MaterialService and Custom Materials · Normal Maps and Detail Baking · Open Questions - Whole Vault · Photo Mode and In-Game Screenshots with CaptureService · Pixel Art Pipeline - Aseprite to Roblox Without Blur · Reserved and Private Servers in Practice · Safe Changes in a Shared Place · Studio Interface Tour · Substance Painter and Texturing Tools · Weather Performance Budgets and Quality Tiers

<!-- atlas:generated -->
