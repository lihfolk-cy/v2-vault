---
tags: [atlas, api, type/atlas, area/modeling, area/world, api/WorldPivot]
---
# WorldPivot

<!-- tldr:start -->
> [!tldr] TL;DR
> - WorldPivot is tagged Not Replicated; the pivot follows the PrimaryPart when one exists.
> - Set PrimaryPart (or WorldPivot) deliberately for every movable model.
> - With a PrimaryPart, `WorldPivot` writes are ignored.
> - PrimaryPart owns the pivot. On models with a PrimaryPart, set `PrimaryPart.PivotOffset`; the project found `WorldPivot` writes...
>
> Cost: TL;DR ~130 tok · whole note ~380 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

WorldPivot is tagged Not Replicated; the pivot follows the PrimaryPart when one exists. (from [[Model - Engine Reference Card]])

API snapshot: member of `Model` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Set PrimaryPart (or WorldPivot) deliberately for every movable model. ([[Model - Engine Reference Card]])
- With a PrimaryPart, `WorldPivot` writes are ignored. A tree library's models had pivots 12 to 23 studs above the trunk bottom; setting `Model.WorldPivot` did nothing because the PrimaryPart owned the pivot. ([[Exporting and Validating Models for Roblox]])
- PrimaryPart owns the pivot. On models with a PrimaryPart, set `PrimaryPart.PivotOffset`; the project found `WorldPivot` writes were ignored on such models. ([[Modular Environment Kits]])
- For models whose `PrimaryPart` owns the pivot, writes to `WorldPivot` are ignored; set `PrimaryPart.PivotOffset` instead. ([[MCP Workflows for Building Worlds]])

## Mentioned in

7 notes in 4 sections. The 7 most relevant are linked:

### 06 World Building and Art
[[Grid Placement and Player Building Systems]] · [[Parts Unions and MeshParts]]

### 14 3D Modeling
[[Exporting and Validating Models for Roblox]] · [[Modeling Fundamentals for Games]] · [[Modular Environment Kits]]

### 16 MCP and Agents
[[MCP Workflows for Building Worlds]]

### 62 Engine Reference Cards
[[Model - Engine Reference Card]]

<!-- atlas:generated -->
