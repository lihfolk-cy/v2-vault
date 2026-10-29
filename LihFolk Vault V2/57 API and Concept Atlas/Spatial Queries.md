---
tags: [atlas, concept, type/atlas, area/gameplay, area/physics]
---
# Spatial Queries

<!-- tldr:start -->
> [!tldr] TL;DR
> - Spatial queries run on whichever side calls them and see only what that side has loaded.
> - Player-chosen actions use `ProximityPrompt`; walk-into actions use `Touched`; areas use point tests or spatial queries.
> - Use spatial queries (GetPartsInPart) for precise overlap checks.
> - See Raycasts Shapecasts and Spatial Queries.
>
> Cost: TL;DR ~120 tok · whole note ~1.0k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Spatial queries run on whichever side calls them and see only what that side has loaded. (from [[Workspace - Engine Reference Card]])

## Key facts

- Player-chosen actions use `ProximityPrompt`; walk-into actions use `Touched`; areas use point tests or spatial queries. ([[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]])
- Use spatial queries (GetPartsInPart) for precise overlap checks. ([[BasePart - Engine Reference Card]])
- See Raycasts Shapecasts and Spatial Queries. ([[AI Pitfalls - Physics and Animation]])
- Physics Assemblies and Constraints, Physics Performance, Raycasts Shapecasts and Spatial Queries. ([[Collision and Physics Geometry]])

## Mentioned in

69 notes in 26 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Luau Performance Patterns with Benchmarks]] · [[Parallel Luau and Actors]]

### 05 UI and UX
[[Off-Screen Objective Markers and Waypoint Arrows]]

### 06 World Building and Art
[[Collision and Physics Geometry]] · [[Grid Placement and Player Building Systems]]

### 09 Gameplay Systems
[[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]] · [[Characters and Humanoids]] · [[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]] · [[Hitboxes and Hit Detection]] · [[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Physics Assemblies and Constraints]] · [[Raycasts Shapecasts and Spatial Queries]]

### 10 Game Design and Genres
[[Genre Playbook - Battlegrounds and Arena Fighters]]

### 12 Performance Testing and Debugging
[[Physics Performance]]

### 15 AI Tools
[[AI Pitfalls - Physics and Animation]]

### 23 Debugging Deep Dives
[[Debugging Physics and Network Ownership]]

### 25 Physics and Vehicles
[[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Projectiles and Ballistics]]

### 29 Luau Cookbook
[[Cookbook - Math CFrame and Vectors]]

### 37 Avatars and UGC
[[Avatar Body Types and Scale in Gameplay]]

### 40 Game Math
[[Dot and Cross Products in Gameplay]] · [[Intersection and Collision Math]]

### 46 Resource Library
[[Official Docs - Physics]]

### 62 Engine Reference Cards
[[BasePart - Engine Reference Card]]

Also mentioned in (not linked): 00 Start Here · AI Pitfalls - Networking and Security · AI Pitfalls - Stale APIs and Luau · Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools · Asset Pipelines · Behaviour Trees Utility AI and State Machines for NPCs · Camera Systems · Cars with Constraints - Suspension Steering and Drive · Centre of Mass, Anti-Flip and Self-Righting · Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits · CollectionService Patterns · Cookbook - Players and Characters · Detecting Combat Exploits - Reach Rate and Aim · Detecting Movement Exploits - Speed Fly Noclip Teleport · Engine Limits, Quotas and Defaults - Cheat Sheet · Explosions - Radius Damage, Falloff and Cover Checks · Foliage Props and Scatter · Game Math Start Here · Genre Playbook - Horror and Story · Genre Playbook - Shooters FPS and TPS · Glossary · Horror Monster Chase AI End to End · Impact Decals and Material-Aware Hit Sparks · Kill Planes, Map Boundaries and Out-of-Bounds Recovery · Level Design Start Here · Level of Detail and Model Streaming · Lobby and Hub Design · Math Vectors and CFrames · NPC AI and Behaviour · Network Ownership · Obby and Platforming Level Design · Open Questions - Whole Vault · Physics and Vehicles Start Here · Police Chases and Wanted Levels · Rain - Camera-Local Particles, Splashes and Wet Surfaces · Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking · Selection Editing and Bulk Tools · Snippets - IK · Teardown - Anime Vanguards · Teardown - Phantom Forces · Terrain Tools and Terrain API · Weekend Build - Arena Shooter with Server-Checked Hits · Workspace - Engine Reference Card · Zone Detection - Area Enter and Exit for Music, Lighting and Ambience

<!-- atlas:generated -->
