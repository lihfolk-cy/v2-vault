---
tags: [atlas, api, type/atlas, area/scripting, area/animation, api/Destroying]
---
# Destroying

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Destroying` is the hook for "this instance is going away"; use it.
> - Every system with connections has a cleanup owner and uses `Destroying`/`PlayerRemoving`.
> - `Destroying` event: fires before destruction (under Deferred events, the handler runs after; see Events Signals and Connections).
> - `Destroy` is idempotent. It can be called twice (from `Destroying` and from your own cleanup) without erroring.
>
> Cost: TL;DR ~140 tok · whole note ~470 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Destroying` is the hook for "this instance is going away"; use it. (from [[Memory Budgets and Leaks]])

API snapshot: member of `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Every system with connections has a cleanup owner and uses `Destroying`/`PlayerRemoving`. ([[Memory Budgets and Leaks]])
- `Destroying` event: fires before destruction (under Deferred events, the handler runs after; see Events Signals and Connections). ([[Instances Attributes and Tags]])
- `Destroy` is idempotent. It can be called twice (from `Destroying` and from your own cleanup) without erroring. ([[Metatables and OOP - When and When Not]])
- Keep per-character state in a table keyed by the character and clear it on `AncestryChanged`/`Destroying`. ([[Characters and Humanoids]])

## Mentioned in

17 notes in 7 sections. The 17 most relevant are linked:

### 02 Luau Scripting
[[Events Signals and Connections]] · [[Instances Attributes and Tags]] · [[Luau Performance Patterns with Benchmarks]] · [[Metatables and OOP - When and When Not]] · [[Tables Metatables and OOP]]

### 03 Architecture and Networking
[[Entity Component Systems]] · [[Replication Rules]]

### 08 Animation
[[Performance and Memory]] · [[Snippets - Animation Controller Module]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Playing Animations]]

### 09 Gameplay Systems
[[Characters and Humanoids]] · [[Squad AI - Attack Tokens, Flanking and Attacker Limits]]

### 12 Performance Testing and Debugging
[[Client Zone Culling for Interiors and Cities]] · [[Memory Budgets and Leaks]]

### 23 Debugging Deep Dives
[[Debugging Live Servers]]

### 35 Advanced Luau
[[Luau Garbage Collection and the Memory Model]]

<!-- atlas:generated -->
