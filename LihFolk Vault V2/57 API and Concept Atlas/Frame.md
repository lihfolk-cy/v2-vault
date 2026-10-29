---
tags: [atlas, api, type/atlas, area/ui, area/gameplay, api/Frame]
---
# Frame

<!-- tldr:start -->
> [!tldr] TL;DR
> - Frame time units. Store durations in seconds in the data and keep them per frame.
> - Frame data imported from the art tool, converted to a committed Luau module, validated (no zero sizes).
> - Avoid: A modal backdrop made of a plain `Frame`: clicks pass straight through to the world.
> - Frame-rate independence has two halves. The existing note covers `1 - exp(-k * dt)`.
>
> Cost: TL;DR ~130 tok · whole note ~710 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Frame time units. Store durations in seconds in the data and keep them per frame. (from [[Sprite Sheets and Frame Animation with ImageRectOffset]])

API snapshot: class, inherits `GuiObject` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Frame data imported from the art tool, converted to a committed Luau module, validated (no zero sizes). ([[Sprite Sheets and Frame Animation with ImageRectOffset]])
- Avoid: A modal backdrop made of a plain `Frame`: clicks pass straight through to the world. ([[ScreenGui Fundamentals]])
- Frame-rate independence has two halves. The existing note covers `1 - exp(-k * dt)`. ([[Math Vectors and CFrames]])
- Sprite Sheets and Frame Animation with ImageRectOffset. ([[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]])

## Mentioned in

37 notes in 15 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Math Vectors and CFrames]]

### 05 UI and UX
[[ScreenGui Fundamentals]] · [[UI Design Systems]] · [[UI Layout Objects - Lists Grids and Pages]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 07 Lighting VFX and Audio
[[Game Feel and Juice]]

### 08 Animation
[[Camera Shake and Camera FX]] · [[Snippets - Camera Shake and FX]]

### 09 Gameplay Systems
[[Chase Cameras and Speed Effects for Vehicles]]

### 12 Performance Testing and Debugging
[[Memory Budgets and Leaks]]

### 24 Worked Builds
[[Codes Redemption System End to End]] · [[Daily Rewards System End to End]] · [[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]] · [[Rebirth and Prestige System End to End]] · [[Round-Based Minigame Loop End to End]] · [[Shop with Game Passes and Developer Products End to End]]

### 29 Luau Cookbook
[[Cookbook - UI]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 42 Accessibility and Inclusive Design
[[Captions and Audio Accessibility]]

### 51 2D Game Development
[[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] · [[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] · [[Sprite Sheets and Frame Animation with ImageRectOffset]] · [[Tilemaps Cameras and Parallax for 2D Levels]]

Also mentioned in (not linked): Drag-and-Drop Inventories and Sliders with UIDragDetector · Game Passes · Gamepad and Console UX · Juice on a Budget - Mobile and Low-End · Nametags and Overhead Bars - Cost and Visibility Rules · Notification and Toast Systems · Off-Screen Objective Markers and Waypoint Arrows · Plugin UI with DockWidgets · Procedural World Generation · Reference - Purple Anime Settings UI (Claude + Figma) · Safe Areas and Insets · Saved Inventory End to End

<!-- atlas:generated -->
