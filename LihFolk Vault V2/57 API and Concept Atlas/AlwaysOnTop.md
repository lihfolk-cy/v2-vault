---
tags: [atlas, api, type/atlas, area/ui, area/vfx, api/AlwaysOnTop]
---
# AlwaysOnTop

<!-- tldr:start -->
> [!tldr] TL;DR
> - AlwaysOnTop is information. A Highlight that shows enemies through walls is a gameplay feature (a wallhack) if the player...
> - Avoid: Enemy tags with `AlwaysOnTop` -> LOS check or no enemy tags.
> - `Occluded` by default; `AlwaysOnTop` only when seeing through walls is intended.
> - `AlwaysOnTop`: draw over 3D geometry (visible through walls).
>
> Cost: TL;DR ~130 tok · whole note ~460 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

AlwaysOnTop is information. A Highlight that shows enemies through walls is a gameplay feature (a wallhack) if the player should not know that. (from [[Highlights and Selection Effects]])

API snapshot: member of `BillboardGui`, `HandleAdornment`, `SurfaceGui` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Enemy tags with `AlwaysOnTop` -> LOS check or no enemy tags. ([[Nametags and Overhead Bars - Cost and Visibility Rules]])
- `Occluded` by default; `AlwaysOnTop` only when seeing through walls is intended. ([[Highlights and Selection Effects]])
- `AlwaysOnTop`: draw over 3D geometry (visible through walls). ([[World-Space UI - BillboardGui and SurfaceGui]])
- Stack heights: lift each layer about 0.012 studs above the last so nothing z-fights; `AlwaysOnTop` stays false so walls hide telegraphs behind them. ([[AoE Telegraphs - Readable Ground Warnings]])

## Mentioned in

11 notes in 8 sections. The 11 most relevant are linked:

### 01 Studio and Workflow
[[Studio Assistant and AI Tools]]

### 05 UI and UX
[[Nametags and Overhead Bars - Cost and Visibility Rules]] · [[Off-Screen Objective Markers and Waypoint Arrows]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 07 Lighting VFX and Audio
[[AoE Telegraphs - Readable Ground Warnings]] · [[Highlights and Selection Effects]]

### 09 Gameplay Systems
[[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]]

### 13 Production and Case Studies
[[Working with AI Assistants in Studio]]

### 16 MCP and Agents
[[Roblox Studio MCP Server]]

### 49 Roblox Platform Features
[[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 62 Engine Reference Cards
[[BillboardGui - Engine Reference Card]]

<!-- atlas:generated -->
