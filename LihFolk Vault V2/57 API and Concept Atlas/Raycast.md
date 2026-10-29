---
tags: [atlas, api, type/atlas, area/gameplay, area/physics, api/Raycast]
---
# Raycast

<!-- tldr:start -->
> [!tldr] TL;DR
> - Raycast car: root friction 0, rounded collider, chosen mass, massless visuals.
> - Avoid: Constraint wheels for a 200 studs/s racer -> Raycast.
> - Avoid: Raycast car root with default friction -> Friction 0 on the root collider.
> - Assist locks through walls: No line-of-sight check -> Raycast before assisting.
>
> Cost: TL;DR ~120 tok · whole note ~860 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Raycast car: root friction 0, rounded collider, chosen mass, massless visuals. (from [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]])

API snapshot: member of `WorldRoot` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Constraint wheels for a 200 studs/s racer -> Raycast. ([[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]])
- Avoid: Raycast car root with default friction -> Friction 0 on the root collider. ([[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]])
- Assist locks through walls: No line-of-sight check -> Raycast before assisting. ([[Aim Assist and Generous Hitboxes]])

## Mentioned in

49 notes in 20 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Parallel Luau and Actors]]

### 03 Architecture and Networking
[[Entity Component Systems]]

### 06 World Building and Art
[[Collision and Physics Geometry]]

### 07 Lighting VFX and Audio
[[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]]

### 08 Animation
[[Cinematic Ultimates]] · [[Snippets - IK]]

### 09 Gameplay Systems
[[Camera Systems]] · [[Custom Character Controllers]] · [[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]]

### 15 AI Tools
[[AI Pitfalls - Stale APIs and Luau]]

### 16 MCP and Agents
[[MCP Workflows for Building Worlds]]

### 17 Pipelines
[[Environment and Level Pipeline]]

### 22 Anti-Exploit and Security
[[Detecting Movement Exploits - Speed Fly Noclip Teleport]]

### 24 Worked Builds
[[Weekend Build - Arena Shooter with Server-Checked Hits]]

### 25 Physics and Vehicles
[[Boats Buoyancy and Water]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Centre of Mass, Anti-Flip and Self-Righting]] · [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Projectiles and Ballistics]]

### 43 Genre Systems End to End
[[Tower Defense Waves and Placement End to End]]

### 58 Player QoL and Game Tweaks
[[Aim Assist and Generous Hitboxes]]

Also mentioned in (not linked): Foliage Props and Scatter · Foot Placement and Ground IK · Genre Playbook - Shooters FPS and TPS · Grid Placement and Player Building Systems · Horror Monster Chase AI End to End · House Construction Method - Modular Kit Workflow · Intersection and Collision Math · Level Design for Roblox · Melee Combat System End to End · MicroProfiler Guide · Modular Environment Kits · Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run · Pathfinding Edge Cases and Fallbacks · Pet Hatching and Following End to End · Physics Performance · Police Chases and Wanted Levels · Prompting and Verifying AI Output · Selection Editing and Bulk Tools · Spawn Points Safe Zones and Respawn Flow · Standing on Moving Vehicles and Platforms - Keeping Players Glued · Terrain Tools and Terrain API · Undo and ChangeHistoryService Done Right · Vehicle Ownership and Anti-Exploit - Server-Checked Driving · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
