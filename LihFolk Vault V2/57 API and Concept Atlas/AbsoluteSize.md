---
tags: [atlas, api, type/atlas, area/ui, area/2d, api/AbsoluteSize]
---
# AbsoluteSize

<!-- tldr:start -->
> [!tldr] TL;DR
> - `AbsoluteSize` and `AbsolutePosition` (on `GuiBase2d`) are the engine's final answer in screen pixels.
> - Reading `AbsoluteSize` in the same frame as setting `Size`.
> - `TextBounds` already includes `UIScale` and the preferred text size, because it is measured in rendered pixels (the...
>
> Cost: TL;DR ~110 tok · whole note ~380 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`AbsoluteSize` and `AbsolutePosition` (on `GuiBase2d`) are the engine's final answer in screen pixels. (from [[Layout - Scale Offset and Constraints]])

API snapshot: member of `ChannelTabsConfiguration`, `ChatInputBarConfiguration`, `ChatWindowConfiguration`, `GuiBase2d` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Reading `AbsoluteSize` in the same frame as setting `Size`. ([[Layout - Scale Offset and Constraints]])
- `TextBounds` already includes `UIScale` and the preferred text size, because it is measured in rendered pixels (the `AbsoluteSize` space). ([[Readable Text and UI Scale]])

## Mentioned in

13 notes in 7 sections. The 13 most relevant are linked:

### 05 UI and UX
[[Declarative UI - React-Lua and Fusion]] · [[HUD Design]] · [[Layout - Scale Offset and Constraints]] · [[Safe Areas and Insets]] · [[UI Design Systems]] · [[UI Layout Objects - Lists Grids and Pages]]

### 13 Production and Case Studies
[[Case Study - Phone UI Overhaul]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 40 Game Math
[[Intersection and Collision Math]]

### 42 Accessibility and Inclusive Design
[[Readable Text and UI Scale]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]

### 56 Field Notes
[[Shared Close Buttons and Headers Across Many Screens]]

<!-- atlas:generated -->
