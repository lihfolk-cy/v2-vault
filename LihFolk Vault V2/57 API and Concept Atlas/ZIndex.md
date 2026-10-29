---
tags: [atlas, api, type/atlas, area/ui, area/vfx, api/ZIndex]
---
# ZIndex

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ZIndex` never crosses `ScreenGui` boundaries: a `ZIndex = 10000` frame in a `DisplayOrder = 0` gui still draws under...
> - Avoid: Using `ZIndex` to put one screen above another.
> - Avoid: Raising `ZIndex` on a child when its ancestor is the problem.
> - ZIndex convention written down with gaps.
>
> Cost: TL;DR ~120 tok · whole note ~420 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ZIndex` never crosses `ScreenGui` boundaries: a `ZIndex = 10000` frame in a `DisplayOrder = 0` gui still draws under everything in a `DisplayOrder = 1` gui. (from [[ScreenGui Fundamentals]])

API snapshot: member of `Decal`, `GuiObject`, `HandleAdornment`, `ParticleEmitter2D` and 3 more (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Using `ZIndex` to put one screen above another. ([[ScreenGui Fundamentals]])
- Avoid: Raising `ZIndex` on a child when its ancestor is the problem. ([[Debugging UI Layout and Input]])
- ZIndex convention written down with gaps. ([[Tiling Trim Sheets and Decal Tricks]])
- Layers are Frames. With `ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling`, children draw above their parent and siblings are ordered by `ZIndex`. ([[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]])

## Mentioned in

9 notes in 9 sections. The 9 most relevant are linked:

### 05 UI and UX
[[ScreenGui Fundamentals]]

### 07 Lighting VFX and Audio
[[Highlights and Selection Effects]]

### 09 Gameplay Systems
[[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]]

### 21 LihFolk UI Design System
[[LihFolk UI Spec]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 44 Materials and Surfaces
[[Tiling Trim Sheets and Decal Tricks]]

### 46 Resource Library
[[Links - Containers]]

### 51 2D Game Development
[[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]

### 56 Field Notes
[[Shared Close Buttons and Headers Across Many Screens]]

<!-- atlas:generated -->
