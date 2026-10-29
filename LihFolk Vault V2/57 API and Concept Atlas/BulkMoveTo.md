---
tags: [atlas, api, type/atlas, area/animation, area/performance, api/BulkMoveTo]
---
# BulkMoveTo

<!-- tldr:start -->
> [!tldr] TL;DR
> - `BulkMoveTo` is worth it from tens of parts upward (Docs: use it when movement is a confirmed bottleneck).
> - `BulkMoveTo(partList, cframeList, eventMode)` moves parts by index; both arrays must be the same length.
> - Foliage sway: leaves near the camera swayed at 30 Hz using `BulkMoveTo`; far leaves did not move.
> - BulkMoveTo and streaming. One loop moving 500 pickups with `workspace:BulkMoveTo` is cheap, but with StreamingEnabled some of...
>
> Cost: TL;DR ~150 tok · whole note ~510 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`BulkMoveTo` is worth it from tens of parts upward (Docs: use it when movement is a confirmed bottleneck). (from [[Snippets - Procedural Motion]])

API snapshot: member of `WorldRoot` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `BulkMoveTo(partList, cframeList, eventMode)` moves parts by index; both arrays must be the same length. ([[Tween and CFrame Animation of Objects]])
- Foliage sway: leaves near the camera swayed at 30 Hz using `BulkMoveTo`; far leaves did not move. ([[Physics Performance]])
- BulkMoveTo and streaming. One loop moving 500 pickups with `workspace:BulkMoveTo` is cheap, but with StreamingEnabled some of those parts may be streamed out on a given client. ([[Snippets - Procedural Motion]])
- Ambient flocks client-side with BulkMoveTo and caps per quality level. ([[Wildlife and Ambient Creature AI - Passive, Neutral and Hostile]])

## Mentioned in

18 notes in 9 sections. The 18 most relevant are linked:

### 02 Luau Scripting
[[Luau Performance Patterns with Benchmarks]] · [[Luau Performance and Native Codegen]]

### 03 Architecture and Networking
[[Snapshot Interpolation for Custom Replication]]

### 07 Lighting VFX and Audio
[[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]]

### 08 Animation
[[Animation LOD]] · [[Flight Flocks and Path Animation]] · [[Performance and Memory]] · [[Procedural Animation]] · [[Rigs and Joints]] · [[Snippets - Procedural Motion]] · [[Tween and CFrame Animation of Objects]]

### 09 Gameplay Systems
[[Wildlife and Ambient Creature AI - Passive, Neutral and Hostile]]

### 12 Performance Testing and Debugging
[[Network Performance]] · [[Performance Fundamentals]] · [[Physics Performance]]

### 24 Worked Builds
[[Pet Hatching and Following End to End]]

### 25 Physics and Vehicles
[[Projectiles and Ballistics]]

### 52 Core Concepts
[[Object Pooling]]

<!-- atlas:generated -->
