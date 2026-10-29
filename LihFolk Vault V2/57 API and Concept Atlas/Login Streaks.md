---
tags: [atlas, concept, type/atlas, area/vfx, area/design]
---
# Login Streaks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Streaks need "claimed yesterday" logic: `dayIndex(now) == lastClaimDay + 1` continues a streak, anything larger breaks it.
> - Near and far layers; streaks use `VelocityParallel` and `Squash`.
> - Streaks are more common than people think.
> - Avoid: Waterfall as one flat card -> Stepped sheet + streak beams + foam + mist.
>
> Cost: TL;DR ~120 tok · whole note ~1.0k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Streaks need "claimed yesterday" logic: `dayIndex(now) == lastClaimDay + 1` continues a streak, anything larger breaks it. (from [[Cookbook - Tables Strings and Time]])

## Key facts

- Near and far layers; streaks use `VelocityParallel` and `Squash`. ([[Rain - Camera-Local Particles, Splashes and Wet Surfaces]])
- Streaks are more common than people think. ([[Variance]])
- Avoid: Waterfall as one flat card -> Stepped sheet + streak beams + foam + mist. ([[Water Sky and Atmosphere Art]])
- Waterfalls: sheet mesh, streak beams, foam, mist, distance sleep. ([[Water Sky and Atmosphere Art]])
- Streak across the body when a trail enables: Trail not cleared -> `Trail:Clear()` before enabling. ([[VFX Timing with Animation]])

## Mentioned in

65 notes in 26 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Water Sky and Atmosphere Art]]

### 07 Lighting VFX and Audio
[[Beams and Trails]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Escalation and Grandeur Without Clutter]] · [[Game Feel and Juice]] · [[Particle Emitters In Depth]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Slash VFX Recipes - Crescent and Ring]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]]

### 08 Animation
[[VFX Timing with Animation]]

### 09 Gameplay Systems
[[Chase Cameras and Speed Effects for Vehicles]]

### 10 Game Design and Genres
[[Ethical Design and Player Trust]] · [[Genre Playbook - Battlegrounds and Arena Fighters]] · [[Retention and Return Hooks]]

### 12 Performance Testing and Debugging
[[Testing Time-Based Features with a Controllable Clock]]

### 14 3D Modeling
[[Topology and Edge Flow]]

### 21 LihFolk UI Design System
[[Glossy Icon Style - Owner Reference]]

### 24 Worked Builds
[[Daily Rewards System End to End]]

### 29 Luau Cookbook
[[Cookbook - Tables Strings and Time]]

### 32 Case Studies of Top Roblox Games
[[Case Study - Rivals]]

### 40 Game Math
[[Probability and Statistics for Designers]]

### 45 Procedural Blender Assets
[[Dash VFX Presentation on an R15 Rig]] · [[Mesh VFX Packs Built in Blender]]

### 52 Core Concepts
[[Variance]]

### 54 Untextured Stylised Modelling
[[Flat Colour vs Gradient Atlas vs Vertex Colour]]

Also mentioned in (not linked): A 2D Engine in a ScreenGui - Game Loop Entities and Rendering · Bevels Chamfers and Edge Highlights Without Textures · Blender 5 Python Gotchas for Headless Builds · Blender Workflow for Roblox Creators · Case Study - Blox Fruits · Case Study - Brookhaven RP · Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop · Core Loops and Session Design · Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations · Difficulty Options and Cognitive Load · Discovery and the Algorithm · Dramatic Showcase Renders in Eevee · Drop Tables Rarity and Pity Systems · Environment and Level Pipeline · Equip Draw and Flourish Systems · Experience Notifications and Return Prompts · Game Math Start Here · Genre Playbook - Tower Defense · Hard-Surface Modeling · Kill Credit, Assists, Kill Feed and Death Recaps · Launch Strategy - The First Two Weeks · LihFolk Systems Library · Live Ops Events and Updates · Menu Archetypes - Shop Settings Codes Rewards · Modeling in Blender for Roblox · Module Design and Dependency Injection · Pet Hatching and Following End to End · Pity Timer · Procedural Creatures - Fused Shells, Quad Cages and Faceting · RNG Drops and Luck Systems · Simulator and RNG Genre Teardown · Subscriptions and Premium Payouts · Teardown - Funky Friday · Textures Decals and Texture Memory · Trim Sheets Atlases and Vertex Colors · VFX Design Playbook · VFX Previews in Blender for Roblox - Colour and Framing · VFX Readability and Value - Lessons from Blind Reviews · Weather Performance Budgets and Quality Tiers · Worked Builds Start Here

<!-- atlas:generated -->
