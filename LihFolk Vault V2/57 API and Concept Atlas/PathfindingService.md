---
tags: [atlas, api, type/atlas, area/gameplay, area/world, api/PathfindingService]
---
# PathfindingService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `PathfindingService:FindPathAsync(start, finish)` is the one-call form; it returns a Path whose status may be `NoPath` (Docs).
> - If you keep `Humanoid`s, disable unneeded states, avoid per-zombie `PathfindingService` every frame, and share flow fields or...
> - Navigation. `PathfindingService` handles terrain, but caves with ceilings close to agent height and steep tunnels create...
> - PathfindingService - Engine Reference Card.
>
> Cost: TL;DR ~150 tok · whole note ~430 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`PathfindingService:FindPathAsync(start, finish)` is the one-call form; it returns a Path whose status may be `NoPath` (Docs). (from [[Pathfinding]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- If you keep `Humanoid`s, disable unneeded states, avoid per-zombie `PathfindingService` every frame, and share flow fields or waypoint graphs across enemies (Pathfinding Edge Cases and Fallbacks). ([[Genre Playbook - Zombie and Wave Survival Co-op]])
- Navigation. `PathfindingService` handles terrain, but caves with ceilings close to agent height and steep tunnels create unreachable spots. ([[Noise Functions and Terrain Generation]])
- PathfindingService - Engine Reference Card. ([[Engine Reference Cards Start Here]])

## Mentioned in

12 notes in 7 sections. The 12 most relevant are linked:

### 09 Gameplay Systems
[[NPC AI and Behaviour]] · [[Pathfinding]] · [[Pathfinding Edge Cases and Fallbacks]]

### 10 Game Design and Genres
[[Genre Playbook - Zombie and Wave Survival Co-op]]

### 33 Level Design
[[Combat Arena and Encounter Layout]] · [[Objective Mode Maps - Capture the Flag, King of the Hill and Control Points]]

### 34 Procedural Generation
[[Dungeon and Room Generation]] · [[Noise Functions and Terrain Generation]]

### 43 Genre Systems End to End
[[Horror Monster Chase AI End to End]]

### 46 Resource Library
[[Official Docs - Game Systems]]

### 62 Engine Reference Cards
[[Engine Reference Cards Start Here]] · [[PathfindingService - Engine Reference Card]]

<!-- atlas:generated -->
