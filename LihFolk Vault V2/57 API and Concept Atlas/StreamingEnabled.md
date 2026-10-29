---
tags: [atlas, api, type/atlas, area/animation, area/physics, api/StreamingEnabled]
---
# StreamingEnabled

<!-- tldr:start -->
> [!tldr] TL;DR
> - StreamingEnabled does not stream ReplicatedStorage.
> - `AuthorityMode = Server` forces StreamingEnabled, NextGenerationReplication, IAS scripts, UseFixedSimulation, Deferred signals.
> - StreamingEnabled is mandatory at this size.
> - Turning it on forces StreamingEnabled, deferred signals and fixed-step simulation.
>
> Cost: TL;DR ~120 tok · whole note ~900 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

StreamingEnabled does not stream ReplicatedStorage. Streaming covers Workspace. (from [[Case Study - Cutting a Million Instances]])

API snapshot: member of `Workspace` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `AuthorityMode = Server` forces StreamingEnabled, NextGenerationReplication, IAS scripts, UseFixedSimulation, Deferred signals. ([[Server Authority and Input Migration 2026]])
- StreamingEnabled is mandatory at this size. ([[Genre Playbook - Open-World City and Crime Roleplay]])
- Turning it on forces StreamingEnabled, deferred signals and fixed-step simulation. ([[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]])
- Tested with StreamingEnabled on, on a phone, and with a vehicle crossing borders fast. ([[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]])

## Mentioned in

43 notes in 20 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[External Tooling - Rojo Wally Selene StyLua]]

### 03 Architecture and Networking
[[Client Prediction and Reconciliation for Combat]] · [[Instance Streaming]] · [[Interest Management and Per-Player Replication]]

### 06 World Building and Art
[[Grid Placement and Player Building Systems]]

### 08 Animation
[[Case Study - Cutting a Million Instances]]

### 09 Gameplay Systems
[[Map Voting and Rotation for Round Games]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]

### 10 Game Design and Genres
[[Genre Playbook - Battle Royale]] · [[Genre Playbook - Naval and Open-Sea Adventure]] · [[Genre Playbook - Open-World City and Crime Roleplay]]

### 12 Performance Testing and Debugging
[[Client Zone Culling for Interiors and Cities]] · [[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]]

### 13 Production and Case Studies
[[Case Study - Fast Join and Deferred Loading]]

### 15 AI Tools
[[AI Pitfalls - Networking and Security]]

### 22 Anti-Exploit and Security
[[How Exploits Work - The Client Boundary]]

### 23 Debugging Deep Dives
[[Debugging Client-Server Desync]]

### 25 Physics and Vehicles
[[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]]

### 46 Resource Library
[[Official Docs - Building and World]]

### 49 Roblox Platform Features
[[Engine Limits, Quotas and Defaults - Cheat Sheet]] · [[Server Authority and Input Migration 2026]]

### 58 Player QoL and Game Tweaks
[[Graphics and Performance Toggles for Low-End Devices]]

### 62 Engine Reference Cards
[[Workspace - Engine Reference Card]]

Also mentioned in (not linked): Photo Mode and In-Game Screenshots with CaptureService · Quest Chain System End to End · Racing AI on a Racing Line - Spline Following and Rubber-Banding · Replication Boundary · Rigs and Joints · Roblox Changes 2025-2026 · Round-Based Minigame Loop End to End · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Snippets - Procedural Motion · Snippets - Ragdoll · Streaming Radius · Teardown - Apocalypse Rising 2 · Teardown - Driving Empire · Terrain Deep Dive - Materials Water and Performance · Testing Modes - Play Run and Multi-Client · The Debugging Method - Reproduce Isolate Bisect · What AI Models Get Wrong in Roblox · What Craft Looks Like on Roblox - Lessons from Top Studios

<!-- atlas:generated -->
