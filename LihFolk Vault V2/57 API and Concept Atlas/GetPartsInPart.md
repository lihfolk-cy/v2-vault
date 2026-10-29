---
tags: [atlas, api, type/atlas, area/gameplay, area/world, api/GetPartsInPart]
---
# GetPartsInPart

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetPartsInPart` uses the part's actual geometry (within its collision fidelity) and gives far fewer false positives.
> - Avoid: Bounds query on big meshes -> `GetPartsInPart` for exactness.
> - For zones, use spatial queries on a timer (`GetPartsInPart`, `GetPartBoundsInBox`) or region checks on the server (Raycasts...
> - Props grounded with terrain-only raycasts; overlaps tested with GetPartsInPart.
>
> Cost: TL;DR ~140 tok · whole note ~460 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetPartsInPart` uses the part's actual geometry (within its collision fidelity) and gives far fewer false positives. (from [[MCP Workflows for Building Worlds]])

`GetPartsInPart` does a full geometric check and is slower. (from [[Raycasts Shapecasts and Spatial Queries]]; Roblox docs)

API snapshot: member of `WorldRoot` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Bounds query on big meshes -> `GetPartsInPart` for exactness. ([[Raycasts Shapecasts and Spatial Queries]])
- For zones, use spatial queries on a timer (`GetPartsInPart`, `GetPartBoundsInBox`) or region checks on the server (Raycasts Shapecasts and Spatial Queries). ([[Debugging Physics and Network Ownership]])
- Props grounded with terrain-only raycasts; overlaps tested with GetPartsInPart. ([[Terrain Tools and Terrain API]])
- Confirm with a raycast or `GetPartsInPart` for precise geometry. ([[AI Pitfalls - Physics and Animation]])

## Mentioned in

12 notes in 8 sections. The 12 most relevant are linked:

### 06 World Building and Art
[[Foliage Props and Scatter]] · [[Terrain Tools and Terrain API]]

### 09 Gameplay Systems
[[Characters and Humanoids]] · [[Hitboxes and Hit Detection]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]

### 15 AI Tools
[[AI Pitfalls - Physics and Animation]]

### 16 MCP and Agents
[[MCP Workflows for Building Worlds]]

### 23 Debugging Deep Dives
[[Debugging Physics and Network Ownership]]

### 24 Worked Builds
[[Weekend Build - Roleplay Town with Jobs and Paychecks]]

### 33 Level Design
[[Teaching Through Level Design]]

### 40 Game Math
[[Intersection and Collision Math]]

<!-- atlas:generated -->
