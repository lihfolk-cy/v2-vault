---
tags: [atlas, api, type/atlas, area/ui, area/studio, api/AlwaysOnTop]
---
# AlwaysOnTop

<!-- tldr:start -->
> [!tldr] TL;DR
> - AlwaysOnTop is information. A Highlight that shows enemies through walls is a gameplay feature (a wallhack) if the player...
> - `Occluded` by default; `AlwaysOnTop` only when seeing through walls is intended.
> - `AlwaysOnTop`: draw over 3D geometry (visible through walls).
> - AlwaysOnTop BillboardGuis are not drawn (health bars, name tags).
>
> Cost: TL;DR ~130 tok · whole note ~390 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

AlwaysOnTop is information. A Highlight that shows enemies through walls is a gameplay feature (a wallhack) if the player should not know that. (from [[Highlights and Selection Effects]])

API snapshot: member of `BillboardGui`, `HandleAdornment`, `SurfaceGui` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `Occluded` by default; `AlwaysOnTop` only when seeing through walls is intended. ([[Highlights and Selection Effects]])
- `AlwaysOnTop`: draw over 3D geometry (visible through walls). ([[World-Space UI - BillboardGui and SurfaceGui]])
- AlwaysOnTop BillboardGuis are not drawn (health bars, name tags). ([[Roblox Studio MCP Server]])
- Viewport captures can come back black when Studio is not the focused window, and may not draw `AlwaysOnTop` BillboardGuis. ([[Studio Assistant and AI Tools]])

## Mentioned in

8 notes in 6 sections. The 8 most relevant are linked:

### 01 Studio and Workflow
[[Studio Assistant and AI Tools]]

### 05 UI and UX
[[Nametags and Overhead Bars - Cost and Visibility Rules]] · [[Off-Screen Objective Markers and Waypoint Arrows]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 07 Lighting VFX and Audio
[[Highlights and Selection Effects]]

### 09 Gameplay Systems
[[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]]

### 13 Production and Case Studies
[[Working with AI Assistants in Studio]]

### 16 MCP and Agents
[[Roblox Studio MCP Server]]

<!-- atlas:generated -->
