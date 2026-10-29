---
tags: [atlas, api, type/atlas, area/vfx, area/world, api/Atmosphere]
---
# Atmosphere

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Atmosphere` (in Lighting) controls air: `Density`, `Offset`, `Color`, `Decay`, `Glare`, `Haze`.
> - Fog stopped working: An `Atmosphere` was added -> Use Atmosphere density and haze.
> - Atmosphere or fog, not both. (Atmosphere Sky Clouds and Post-Processing)
> - Avoid: Storm sold only by particles -> Push Atmosphere, clouds and grade first.
>
> Cost: TL;DR ~130 tok · whole note ~990 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Atmosphere` (in Lighting) controls air: `Density`, `Offset`, `Color`, `Decay`, `Glare`, `Haze`. (from [[Water Sky and Atmosphere Art]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Fog stopped working: An `Atmosphere` was added -> Use Atmosphere density and haze. ([[Atmosphere Sky Clouds and Post-Processing]])
- Atmosphere or fog, not both. ([[Atmosphere Sky Clouds and Post-Processing]])
- Avoid: Storm sold only by particles -> Push Atmosphere, clouds and grade first. ([[Snow, Sandstorm, Blizzard and Ash Recipes]])
- Each storm has Atmosphere, clouds, wind, grade, particles and sound in one look table. ([[Snow, Sandstorm, Blizzard and Ash Recipes]])
- Fog settings do nothing: An `Atmosphere` is in `Lighting` (fog properties are hidden and... -> Use `Atmosphere.Density`/`Haze` instead, or remove the Atmosphere. ([[Lighting Technologies and Settings]])

## Mentioned in

55 notes in 26 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Environment Art Styles]] · [[Level of Detail and Model Streaming]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Terrain Tools and Terrain API]] · [[Water Sky and Atmosphere Art]] · [[Zone and Biome Art Direction]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Lighting Mood and Time of Day]] · [[Lighting Technologies and Settings]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Stylized Lighting Recipes]] · [[Weather System Architecture - State Machine, Transitions and Replication]]

### 09 Gameplay Systems
[[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]

### 10 Game Design and Genres
[[Genre Playbook - Horror and Story]] · [[Genre Playbook - Naval and Open-Sea Adventure]]

### 16 MCP and Agents
[[MCP Workflows for Building Worlds]]

### 17 Pipelines
[[Environment and Level Pipeline]]

### 33 Level Design
[[Level Design Principles - Flow Sightlines and Landmarks]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]]

### 44 Materials and Surfaces
[[Procedural Materials and Skies - Lessons]]

### 45 Procedural Blender Assets
[[Dramatic Showcase Renders in Eevee]]

### 46 Resource Library
[[Links - Lighting]]

### 49 Roblox Platform Features
[[Photo Mode and In-Game Screenshots with CaptureService]]

### 54 Untextured Stylised Modelling
[[Colour Scripts and Value Structure for Untextured Art]]

Also mentioned in (not linked): 00 Start Here · Accessibility Contrast · Accessibility Start Here · Agent Review Loops and Guardrails in Practice · Batch Processing Tools in Studio · Boats Buoyancy and Water · Critiquing a Model - Paintovers and Iteration · Game Trailers and Clean Footage - Capture, Freecam and Editing · Hand-Painted and Stylized Texturing · Instance Streaming · Instanced Interiors - Pooled House and Room Copies for Many Players · Lighting Untextured Art in Roblox · Low-Poly and Stylized Modeling · Materials and Surfaces Start Here · Music and Adaptive Audio · Noise Functions and Terrain Generation · Packages and Shared Assets Across Places · Procedural Generation Start Here · Rain - Camera-Local Particles, Splashes and Wet Surfaces · Reference - Purple Anime Settings UI (Claude + Figma) · Roads, Rivers and Paths Carved Along Curves in Terrain · Safety Rules for AI Agents in Studio · Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur · Studio Interface Tour · Testing Modes - Play Run and Multi-Client · Textures Decals and Texture Memory · Texturing and PBR Baking · Voxel Palettes - Ramps Hue Shifting and Limits · Weather Performance Budgets and Quality Tiers · Weather That Changes Gameplay - Grip, Visibility and Hearing

<!-- atlas:generated -->
