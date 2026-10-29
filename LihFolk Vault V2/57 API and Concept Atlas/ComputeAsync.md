---
tags: [atlas, api, type/atlas, area/gameplay, area/world, api/ComputeAsync]
---
# ComputeAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ComputeAsync` is not free: it yields while the engine searches, and many agents recomputing every frame will queue.
> - Avoid: computing a path without pcall. Symptom: a thrown error stops the NPC script; wrap `ComputeAsync` and check `Status`.
> - `ComputeAsync` yields and can error; wrap it in `pcall`.
> - MicroProfiler with 8 players: the think loop is a small, steady cost; no `ComputeAsync` spikes every frame.
>
> Cost: TL;DR ~140 tok · whole note ~370 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ComputeAsync` is not free: it yields while the engine searches, and many agents recomputing every frame will queue. (from [[Pathfinding]])

API snapshot: member of `Path` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: computing a path without pcall. Symptom: a thrown error stops the NPC script; wrap `ComputeAsync` and check `Status`. ([[PathfindingService - Engine Reference Card]])
- `ComputeAsync` yields and can error; wrap it in `pcall`. ([[Pathfinding]])
- MicroProfiler with 8 players: the think loop is a small, steady cost; no `ComputeAsync` spikes every frame. ([[Horror Monster Chase AI End to End]])
- No yielding in brains. `task.wait`, `ComputeAsync` and any `Async` call inside a brain tick stall it. ([[Behaviour Trees Utility AI and State Machines for NPCs]])

## Mentioned in

7 notes in 5 sections. The 7 most relevant are linked:

### 09 Gameplay Systems
[[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Pathfinding]] · [[Pathfinding Edge Cases and Fallbacks]]

### 33 Level Design
[[Objective Mode Maps - Capture the Flag, King of the Hill and Control Points]]

### 43 Genre Systems End to End
[[Horror Monster Chase AI End to End]]

### 62 Engine Reference Cards
[[PathfindingService - Engine Reference Card]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
