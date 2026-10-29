---
tags: [atlas, concept, type/atlas, area/procedural, area/animation]
---
# Random Seeds

<!-- tldr:start -->
> [!tldr] TL;DR
> - A seed means nothing without the code and data that interpret it.
> - Avoid: Linear sub-seed formula -> Hash-combine coordinates.
> - `Random` streams are bounded to one job and seeded from a hash.
> - Avoid: `math.random` in generators -> `Random.new(seed)` per purpose.
>
> Cost: TL;DR ~110 tok · whole note ~1.1k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A seed means nothing without the code and data that interpret it. (from [[Seeds Determinism and Reproducible Worlds]])

Seeds are fine for items that are never saved (a run-only roguelike item) or for preview ("this chest will contain..."). (from [[Procedural Loot and Item Generation]])

## Key facts

- Avoid: Linear sub-seed formula -> Hash-combine coordinates. ([[Seeds Determinism and Reproducible Worlds]])
- `Random` streams are bounded to one job and seeded from a hash. ([[Seeds Determinism and Reproducible Worlds]])
- Avoid: `math.random` in generators -> `Random.new(seed)` per purpose. ([[Procedural World Generation]])
- Avoid: Noise sampled at integer coordinates -> Scale by non-integer frequency, offset by seed. ([[Procedural World Generation]])
- Determinism lets you send *seeds and inputs* instead of *state*: generate a whole dungeon on every client from one number... ([[Deterministic Simulation]])

## Mentioned in

73 notes in 31 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Math Vectors and CFrames]]

### 06 World Building and Art
[[Foliage Props and Scatter]] · [[Procedural World Generation]]

### 07 Lighting VFX and Audio
[[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Weather System Architecture - State Machine, Transitions and Replication]]

### 08 Animation
[[Spec-Driven Move Authoring]]

### 12 Performance Testing and Debugging
[[Automated Testing with TestEZ and Jest-Lua]]

### 22 Anti-Exploit and Security
[[Testing Your Own Remotes - Fuzzing and Abuse Tests]]

### 23 Debugging Deep Dives
[[The Debugging Method - Reproduce Isolate Bisect]]

### 25 Physics and Vehicles
[[Projectiles and Ballistics]]

### 32 Case Studies of Top Roblox Games
[[Case Study - Grow a Garden]]

### 34 Procedural Generation
[[Dungeon and Room Generation]] · [[Infinite and Streamed Worlds]] · [[Noise Functions and Terrain Generation]] · [[Procedural Generation Start Here]] · [[Procedural Loot and Item Generation]] · [[Seeds Determinism and Reproducible Worlds]] · [[Wave Function Collapse on Roblox]]

### 45 Procedural Blender Assets
[[Low-Poly Tree Set Worked Example]] · [[Stylised Shop Stand Worked Example]]

### 48 Economy Design Deep Dive
[[Drop Tables Rarity and Pity Systems]] · [[Simulating an Economy Before Launch]]

### 51 2D Game Development
[[2D Multiplayer - Server Authority and Replicating GUI Worlds]]

### 52 Core Concepts
[[Deterministic Simulation]]

### 53 Voxel Modelling Deep Dive
[[Voxel Props Environments and Modular Tiles]]

Also mentioned in (not linked): 00 Start Here · 2D Game Development Start Here · Blender 5 Python Gotchas for Headless Builds · Blender Automation with Python · Case Study - Adopt Me · Case Study - Doors · Client Prediction and Reconciliation for Combat · Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop · Cookbook - Math CFrame and Vectors · Cookbook - Tables Strings and Time · Dash VFX Presentation on an R15 Rig · Debugging Start Here · Dramatic Showcase Renders in Eevee · Economy Design Start Here · EditableImage for Pixel Buffers and Procedural 2D · Faceted Low-Poly - Flat Normals and Facet Size · First-Time User Experience and Onboarding · Flight Flocks and Path Animation · Genre Playbook - RNG and Collection Games · Genre Playbook - Shooters FPS and TPS · Genre Playbook - Social Deduction and Murder Mystery · Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers · House Construction Method - Modular Kit Workflow · Ice Ball Cast to Explosion - Approved Recipe · Icon and Thumbnail Rendering Pipeline · In-Game AI - LLM NPCs and Text Generation · Interest Management and Per-Player Replication · Inverse Kinematics · Localization · Modular Environment Kits · Module Design and Dependency Injection · Obby and Platforming Level Design · Open Questions - Whole Vault · Parties and Group Teleports · Pet Hatching and Following End to End · Physics and Vehicles Start Here · Pipeline - New Animated Weapon · Probability and Statistics for Designers · Procedural Animation · RNG Drops and Luck Systems · Retopology and Decimation · Skill - Roblox Debugging · Snippets - Camera Shake and FX · Stylised Log Cabin Worked Example · Template Reskin Checklist - One Codebase, New Game · Testing Strategies and Frameworks · Variance · Voxel and Blocky Modeling

<!-- atlas:generated -->
