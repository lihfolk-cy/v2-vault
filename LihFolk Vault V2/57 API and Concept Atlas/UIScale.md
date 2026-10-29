---
tags: [atlas, api, type/atlas, area/ui, area/2d, api/UIScale]
---
# UIScale

<!-- tldr:start -->
> [!tldr] TL;DR
> - `UIScale` scales offsets and scale-sized children together, but it does not move an anchored element away from screen edges.
> - Avoid: One global `UIScale` with no lower clamp, making phone text unreadable.
> - Avoid: Two `UIScale`s on the same object (device scale and pop scale fighting).
> - One `UIScale` controller combines device base and player preference, clamped to fit.
>
> Cost: TL;DR ~140 tok · whole note ~750 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`UIScale` scales offsets and scale-sized children together, but it does not move an anchored element away from screen edges. (from [[UI Scale HUD Hide and Compact Mode]])

API snapshot: class, inherits `UIComponent` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: One global `UIScale` with no lower clamp, making phone text unreadable. ([[Layout - Scale Offset and Constraints]])
- Avoid: Two `UIScale`s on the same object (device scale and pop scale fighting). ([[Layout - Scale Offset and Constraints]])
- One `UIScale` controller combines device base and player preference, clamped to fit. ([[Readable Text and UI Scale]])
- List jiggles during a pop: Tweening `Size` in a layout -> `UIScale` ([[UI and GUI Animation]])
- Uneven pixel columns, wobble while walking: Non-integer scale or Scale-based sizing -> Every size is `fromOffset(w * scale, ...)`, no UIScale above. ([[Pixel Art Pipeline - Aseprite to Roblox Without Blur]])

## Mentioned in

38 notes in 15 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Accessibility]] · [[HUD Design]] · [[Layout - Scale Offset and Constraints]] · [[Responsive UI for Phone Tablet Console and PC]] · [[ScreenGui Fundamentals]] · [[Text Fonts and Rich Text]] · [[UI Design Systems]] · [[UI Layout Objects - Lists Grids and Pages]] · [[UI Motion Language and Timing]]

### 07 Lighting VFX and Audio
[[Game Feel and Juice]]

### 08 Animation
[[Reference - Purple Anime Settings UI (Claude + Figma)]] · [[UI and GUI Animation]]

### 13 Production and Case Studies
[[Case Study - Phone UI Overhaul]]

### 15 AI Tools
[[AI Pitfalls - UI and Input]]

### 21 LihFolk UI Design System
[[LihFolk UI Spec]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 29 Luau Cookbook
[[Cookbook - UI]]

### 42 Accessibility and Inclusive Design
[[Readable Text and UI Scale]]

### 47 Game Feel and Juice
[[Juice on a Budget - Mobile and Low-End]] · [[Squash Stretch and Anticipation in UI and Characters]]

### 51 2D Game Development
[[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] · [[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]

### 56 Field Notes
[[UIStroke on Text - Glyph Counters and the Stroke Ratio]]

### 58 Player QoL and Game Tweaks
[[UI Scale HUD Hide and Compact Mode]]

Also mentioned in (not linked): Accessibility Start Here · Debugging Start Here · Game Feel Start Here · Gamepad and Console UX · Links - Scale vs offset and responsive design · Luau Cookbook Start Here · Nametags and Overhead Bars - Cost and Visibility Rules · Safe Areas and Insets · Skill - Roblox UI Builder · Sprite Sheets and Frame Animation with ImageRectOffset · Tilemaps Cameras and Parallax for 2D Levels · UI Style Directions - A Visual Vocabulary for Briefs · Virtualized Lists and Large Inventories

<!-- atlas:generated -->
