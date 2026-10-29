---
tags: [atlas, api, type/atlas, area/ui, area/gameplay, api/ScrollingFrame]
---
# ScrollingFrame

<!-- tldr:start -->
> [!tldr] TL;DR
> - A `ScrollingFrame` always clips its contents; with `AutomaticCanvasSize` set, the canvas (not the frame) grows to fit its...
> - Built-in input can fight your input. Touch swiping a page also scrolls a `ScrollingFrame` inside it; the mouse wheel pages...
> - A header that never scrolls plus a `ScrollingFrame` that fills the rest: `Size = UDim2.new(1, 0, 1, -headerHeight)`.
> - For long lists, auto-scroll the `ScrollingFrame` when the ghost is near the top or bottom edge (a few pixels per frame scaled...
>
> Cost: TL;DR ~170 tok · whole note ~530 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A `ScrollingFrame` always clips its contents; with `AutomaticCanvasSize` set, the canvas (not the frame) grows to fit its children (from [[Shared Close Buttons and Headers Across Many Screens]] and [[Layout - Scale Offset and Constraints]]).

API snapshot: class, inherits `GuiObject` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Built-in input can fight your input. Touch swiping a page also scrolls a `ScrollingFrame` inside it; the mouse wheel pages when the player meant to scroll a list. ([[UI Layout Objects - Lists Grids and Pages]])
- A header that never scrolls plus a `ScrollingFrame` that fills the rest: `Size = UDim2.new(1, 0, 1, -headerHeight)`. ([[Plugin UI with DockWidgets]])
- For long lists, auto-scroll the `ScrollingFrame` when the ghost is near the top or bottom edge (a few pixels per frame scaled by distance into the edge zone). ([[Drag-and-Drop Inventories and Sliders with UIDragDetector]])
- `ScrollingFrame` uses `AutomaticCanvasSize` instead, which resizes the canvas, not the frame. ([[Layout - Scale Offset and Constraints]])

## Mentioned in

15 notes in 8 sections. The 15 most relevant are linked:

### 05 UI and UX
[[Drag-and-Drop Inventories and Sliders with UIDragDetector]] · [[Layout - Scale Offset and Constraints]] · [[UI Layout Objects - Lists Grids and Pages]] · [[Virtualized Lists and Large Inventories]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 24 Worked Builds
[[Global Leaderboards End to End]] · [[Pet Hatching and Following End to End]] · [[Saved Inventory End to End]] · [[Shop with Game Passes and Developer Products End to End]]

### 29 Luau Cookbook
[[Cookbook - UI]]

### 39 Studio Plugins and Tooling
[[Building a Studio Plugin End to End]] · [[Plugin UI with DockWidgets]]

### 42 Accessibility and Inclusive Design
[[Readable Text and UI Scale]]

### 46 Resource Library
[[Links - UI elements]]

### 56 Field Notes
[[Shared Close Buttons and Headers Across Many Screens]]

<!-- atlas:generated -->
