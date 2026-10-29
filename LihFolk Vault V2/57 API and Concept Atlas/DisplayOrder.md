---
tags: [atlas, api, type/atlas, area/ui, area/debugging, api/DisplayOrder]
---
# DisplayOrder

<!-- tldr:start -->
> [!tldr] TL;DR
> - `DisplayOrder` is an integer; higher draws on top of lower (Docs).
> - A written `DisplayOrder` band plan; tutorial layers on top.
> - DisplayOrder bands written down and assigned to every ScreenGui.
> - Screens as components registered with a presenter that enforces one-open-at-a-time and the band plan of `DisplayOrder`s...
>
> Cost: TL;DR ~120 tok · whole note ~360 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`DisplayOrder` is an integer; higher draws on top of lower (Docs). (from [[ScreenGui Fundamentals]])

API snapshot: member of `ScreenGui` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- A written `DisplayOrder` band plan; tutorial layers on top. ([[ScreenGui Fundamentals]])
- DisplayOrder bands written down and assigned to every ScreenGui. ([[Debugging UI Layout and Input]])
- Screens as components registered with a presenter that enforces one-open-at-a-time and the band plan of `DisplayOrder`s (ScreenGui Fundamentals). ([[Declarative UI - React-Lua and Fusion]])
- On `DragStart`, create a ghost (a copy of the icon) in a top-level `ScreenGui` with high `DisplayOrder`, and dim the source slot. ([[Drag-and-Drop Inventories and Sliders with UIDragDetector]])

## Mentioned in

9 notes in 5 sections. The 9 most relevant are linked:

### 05 UI and UX
[[Declarative UI - React-Lua and Fusion]] · [[Drag-and-Drop Inventories and Sliders with UIDragDetector]] · [[HUD Design]] · [[Safe Areas and Insets]] · [[ScreenGui Fundamentals]]

### 21 LihFolk UI Design System
[[LihFolk UI Spec]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 58 Player QoL and Game Tweaks
[[Colourblind Palettes Text Size and Tooltips]]

### Root notes
[[Skill - Roblox UI Builder]]

<!-- atlas:generated -->
