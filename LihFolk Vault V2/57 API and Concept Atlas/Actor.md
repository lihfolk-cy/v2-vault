---
tags: [atlas, api, type/atlas, area/scripting, area/procedural, api/Actor]
---
# Actor

<!-- tldr:start -->
> [!tldr] TL;DR
> - Actor messages are not RemoteEvents: they never cross the network.
> - No speed-up: All scripts in one Actor, or no `desynchronize` -> Many Actors; `ConnectParallel` (Parallel Luau and Actors)
> - Registry empty inside workers: Per-Actor module copies -> DataModel lookups, SharedTable, or messages.
> - Scripts under an `Actor` can run in parallel phases (Parallel Luau and Actors).
>
> Cost: TL;DR ~140 tok · whole note ~250 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Actor messages are not RemoteEvents: they never cross the network. (from [[Parallel Luau and Actors]])

API snapshot: class, inherits `Model` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- No speed-up: All scripts in one Actor, or no `desynchronize` -> Many Actors; `ConnectParallel` ([[Parallel Luau and Actors]])
- Registry empty inside workers: Per-Actor module copies -> DataModel lookups, SharedTable, or messages. ([[Parallel Luau and Actors]])
- Scripts under an `Actor` can run in parallel phases (Parallel Luau and Actors). ([[Script Types and Run Context]])

## Mentioned in

5 notes in 2 sections. The 5 most relevant are linked:

### 02 Luau Scripting
[[Events Signals and Connections]] · [[Parallel Luau and Actors]] · [[Script Types and Run Context]] · [[Tables Metatables and OOP]]

### 34 Procedural Generation
[[Infinite and Streamed Worlds]]

<!-- atlas:generated -->
