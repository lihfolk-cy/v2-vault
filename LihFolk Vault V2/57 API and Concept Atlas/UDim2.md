---
tags: [atlas, api, type/atlas, area/ui, area/gameplay, api/UDim2]
---
# UDim2

<!-- tldr:start -->
> [!tldr] TL;DR
> - `UDim2.fromScale(x, y)` and `UDim2.fromOffset(x, y)` are the readable shortcuts.
> - Scale is studs. `UDim2.fromScale(4, 1)` is 4 studs wide and 1 stud tall in the world: it gets smaller on screen as the camera...
> - `CellSize` (`UDim2`) and `CellPadding` (`UDim2`).
> - Turn on a temporary debug frame in each gui with `Size = UDim2.fromScale(1, 1)` and a bright translucent fill: you see exactly...
>
> Cost: TL;DR ~140 tok · whole note ~1.0k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`UDim2.fromScale(x, y)` and `UDim2.fromOffset(x, y)` are the readable shortcuts. (from [[Layout - Scale Offset and Constraints]])

API snapshot: Luau data type (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Scale is studs. `UDim2.fromScale(4, 1)` is 4 studs wide and 1 stud tall in the world: it gets smaller on screen as the camera moves away, like a real sign. ([[World-Space UI - BillboardGui and SurfaceGui]])
- `CellSize` (`UDim2`) and `CellPadding` (`UDim2`). ([[UI Layout Objects - Lists Grids and Pages]])
- Turn on a temporary debug frame in each gui with `Size = UDim2.fromScale(1, 1)` and a bright translucent fill: you see exactly what area that gui thinks it owns. ([[Safe Areas and Insets]])
- Offset for heights, scale for widths. Rows are a fixed pixel height (24 to 28 is Studio-like); widths are `UDim2.new(1, -padding, 0, height)`. ([[Plugin UI with DockWidgets]])

## Mentioned in

65 notes in 25 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Declarative UI - React-Lua and Fusion]] · [[Drag-and-Drop Inventories and Sliders with UIDragDetector]] · [[Layout - Scale Offset and Constraints]] · [[Safe Areas and Insets]] · [[UI Layout Objects - Lists Grids and Pages]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 07 Lighting VFX and Audio
[[Game Feel and Juice]]

### 08 Animation
[[Snippets - Camera Shake and FX]]

### 13 Production and Case Studies
[[Case Study - Phone UI Overhaul]]

### 24 Worked Builds
[[Codes Redemption System End to End]] · [[Daily Rewards System End to End]] · [[Pet Hatching and Following End to End]] · [[Saved Inventory End to End]] · [[Shop with Game Passes and Developer Products End to End]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 39 Studio Plugins and Tooling
[[Building a Studio Plugin End to End]] · [[Plugin UI with DockWidgets]]

### 43 Genre Systems End to End
[[Obby Checkpoints and Stage Saves End to End]] · [[Tycoon Plots and Droppers End to End]]

### 51 2D Game Development
[[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] · [[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] · [[Tilemaps Cameras and Parallax for 2D Levels]]

### 56 Field Notes
[[Centre-Screen Announcements That Stay Centred]] · [[Shared Close Buttons and Headers Across Many Screens]]

Also mentioned in (not linked): AI Pitfalls - UI and Input · Big Numbers Precision and Formatting · Camera Shake and Camera FX · Captions and Audio Accessibility · Curves in Luau - Paths Beams and Motion · Data Schema Design and Migrations · Debugging UI Layout and Input · Developer Console and Stats · Easing · EditableImage for Pixel Buffers and Procedural 2D · Explorer Properties and Selection · Game Icon Design - Readable at Small Sizes · Global Leaderboards End to End · HUD Design · Horror Monster Chase AI End to End · Input - UserInputService and ContextActionService · Instances Attributes and Tags · Juice on a Budget - Mobile and Low-End · Melee Combat System End to End · Memory Budgets and Leaks · Metatables and OOP - When and When Not · Minimap and World Map UI - Projection, Rotation and Fog of War · Mobile Button Layout Editor · Off-Screen Objective Markers and Waypoint Arrows · Pipeline Design Principles · Plugins - Using and Writing · Race HUD - Position, Laps, Splits, Speedometer and Minimap · Racing Laps and Checkpoints End to End · Readable Text and UI Scale · Replication Rules · Safe Changes in a Shared Place · ScreenGui Fundamentals · Sprite Sheets and Frame Animation with ImageRectOffset · Squash Stretch and Anticipation in UI and Characters · Testing Your Own Remotes - Fuzzing and Abuse Tests · Tween and CFrame Animation of Objects · UI Design Systems · UI Motion Language and Timing · UI and GUI Animation · Virtualized Lists and Large Inventories

<!-- atlas:generated -->
