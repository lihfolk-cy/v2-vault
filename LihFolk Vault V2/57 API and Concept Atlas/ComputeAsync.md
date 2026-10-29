---
tags: [atlas, api, type/atlas, area/gameplay, area/world, api/ComputeAsync]
---
# ComputeAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ComputeAsync` is not free: it yields while the engine searches, and many agents recomputing every frame will queue.
> - `ComputeAsync` yields and can error; wrap it in `pcall`.
> - MicroProfiler with 8 players: the think loop is a small, steady cost; no `ComputeAsync` spikes every frame.
> - No yielding in brains. `task.wait`, `ComputeAsync` and any `Async` call inside a brain tick stall it.
>
> Cost: TL;DR ~140 tok · whole note ~350 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ComputeAsync` is not free: it yields while the engine searches, and many agents recomputing every frame will queue. (from [[Pathfinding]])

API snapshot: member of `Path` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `ComputeAsync` yields and can error; wrap it in `pcall`. ([[Pathfinding]])
- MicroProfiler with 8 players: the think loop is a small, steady cost; no `ComputeAsync` spikes every frame. ([[Horror Monster Chase AI End to End]])
- No yielding in brains. `task.wait`, `ComputeAsync` and any `Async` call inside a brain tick stall it. ([[Behaviour Trees Utility AI and State Machines for NPCs]])
- Pathfinding: `Humanoid:MoveTo` 8-second timeout; when `ComputeAsync` returns ClosestNoPath; navmesh rebuild delay after geometry changes. ([[Open Questions - Whole Vault]])

## Mentioned in

6 notes in 4 sections. The 6 most relevant are linked:

### 09 Gameplay Systems
[[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Pathfinding]] · [[Pathfinding Edge Cases and Fallbacks]]

### 33 Level Design
[[Objective Mode Maps - Capture the Flag, King of the Hill and Control Points]]

### 43 Genre Systems End to End
[[Horror Monster Chase AI End to End]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
