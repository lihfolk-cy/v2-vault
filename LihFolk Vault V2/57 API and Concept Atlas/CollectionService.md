---
tags: [atlas, api, type/atlas, area/world, area/scripting, api/CollectionService]
---
# CollectionService

<!-- tldr:start -->
> [!tldr] TL;DR
> - CollectionService: Tags on Instances, used to attach behaviour to groups.
> - Prefer `CollectionService` tag signals or attributes that react when instances stream in.
> - The enemy grounding code accepted parts carrying a CollectionService tag (`EnemyFloor`) as valid ground: plaza pavements...
> - CollectionService Patterns, Raycasts Shapecasts and Spatial Queries, Tween and CFrame Animation of Objects.
>
> Cost: TL;DR ~140 tok · whole note ~1.0k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

CollectionService: Tags on Instances, used to attach behaviour to groups. (from [[Glossary]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Prefer `CollectionService` tag signals or attributes that react when instances stream in. ([[Streaming Radius]])
- The enemy grounding code accepted parts carrying a CollectionService tag (`EnemyFloor`) as valid ground: plaza pavements, medallions and arena dais stones. ([[Collision and Physics Geometry]])
- CollectionService Patterns, Raycasts Shapecasts and Spatial Queries, Tween and CFrame Animation of Objects. ([[Foliage Props and Scatter]])
- Tags section: add or remove CollectionService tags. ([[Explorer Properties and Selection]])

## Mentioned in

71 notes in 26 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Explorer Properties and Selection]]

### 02 Luau Scripting
[[CollectionService Patterns]] · [[Instances Attributes and Tags]]

### 03 Architecture and Networking
[[Entity Component Systems]] · [[Instance Streaming]]

### 05 UI and UX
[[Accessibility]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 06 World Building and Art
[[Collision and Physics Geometry]] · [[Foliage Props and Scatter]] · [[Level of Detail and Model Streaming]]

### 07 Lighting VFX and Audio
[[Light Sources and Shadows]]

### 08 Animation
[[Snippets - Enemy Client Animator]]

### 09 Gameplay Systems
[[Raycasts Shapecasts and Spatial Queries]]

### 23 Debugging Deep Dives
[[Debugging Client-Server Desync]] · [[Debugging Physics and Network Ownership]]

### 25 Physics and Vehicles
[[Cars with Constraints - Suspension Steering and Drive]] · [[Destruction and Fracture]] · [[Vehicle Damage, Repair and Wreck States]]

### 33 Level Design
[[Spawn Points Safe Zones and Respawn Flow]] · [[Teaching Through Level Design]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 43 Genre Systems End to End
[[Obby Checkpoints and Stage Saves End to End]]

### 46 Resource Library
[[Links - Services]]

### 52 Core Concepts
[[Streaming Radius]]

### 58 Player QoL and Game Tweaks
[[UI Scale HUD Hide and Compact Mode]]

Also mentioned in (not linked): 00 Start Here · AI Pitfalls - Networking and Security · Aim Assist and Generous Hitboxes · Baked Clip Stubs and Archiving · Boats Buoyancy and Water · Camera Obstruction Handling - Occlusion Modes, Fades and Collision · Client Zone Culling for Interiors and Cities · Debugging Race Conditions and Yield Order · Detecting Movement Exploits - Speed Fly Noclip Teleport · Events Signals and Connections · Explosions - Radius Damage, Falloff and Cover Checks · Frameworks - Knit Matter and Others · Genre Playbook - Obbies and Platformers · Genre Playbook - Roleplay and Social Hangouts · Global Leaderboards End to End · Glossary · Graphics and Performance Toggles for Low-End Devices · Ground Fitting Pipeline · Horror Monster Chase AI End to End · Hunting Memory Leaks Step by Step · Level Design for Roblox · Lore Delivery Without Walls of Text · Luau Garbage Collection and the Memory Model · Obby and Platforming Level Design · Packages and Asset Reuse · Project Structure and Bootstrapping · Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking · Replication Rules · ScreenGui Fundamentals · Script Performance · Script Types and Run Context · Selection Editing and Bulk Tools · Shared Close Buttons and Headers Across Many Screens · Snippets - Procedural Motion · Spawn Director - Credit Budgets and Player-Count Scaling · StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs · Studio Assistant and AI Tools · Studio Interface Tour · Tables Metatables and OOP · Textures Decals and Texture Memory · Tower Defense Waves and Placement End to End · UI Design Systems · Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver · Weekend Build - Survival Gather, Craft and Place · Working with Content Creators · Zone and Biome Art Direction

<!-- atlas:generated -->
