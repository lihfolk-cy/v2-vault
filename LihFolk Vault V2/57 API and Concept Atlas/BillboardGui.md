---
tags: [atlas, api, type/atlas, area/ui, area/gameplay, api/BillboardGui]
---
# BillboardGui

<!-- tldr:start -->
> [!tldr] TL;DR
> - `BillboardGui.Active` controls whether descendants receive input (Docs).
> - Avoid: `VideoFrame` not inside a ScreenGui, SurfaceGui or BillboardGui -> Parent it to a GUI container.
> - `BillboardGui.MaxDistance` inf by default; `SurfaceGui.MaxDistance` 1000 studs per the docs.
> - Billboards at the hit position (pooled `BillboardGui`s with Offset size, tweened upward via `StudsOffsetWorldSpace` and faded).
>
> Cost: TL;DR ~140 tok · whole note ~710 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`BillboardGui.Active` controls whether descendants receive input (Docs). (from [[World-Space UI - BillboardGui and SurfaceGui]])

API snapshot: class, inherits `LayerCollector` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: `VideoFrame` not inside a ScreenGui, SurfaceGui or BillboardGui -> Parent it to a GUI container. ([[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]])
- `BillboardGui.MaxDistance` inf by default; `SurfaceGui.MaxDistance` 1000 studs per the docs. ([[BillboardGui - Engine Reference Card]])
- Billboards at the hit position (pooled `BillboardGui`s with Offset size, tweened upward via `StudsOffsetWorldSpace` and faded). ([[World-Space UI - BillboardGui and SurfaceGui]])
- World-Space UI - BillboardGui and SurfaceGui: labels over any background. ([[Accessibility Contrast]])

## Mentioned in

32 notes in 17 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Packages and Asset Reuse]]

### 04 Data and Persistence
[[OrderedDataStores and Leaderboards]]

### 05 UI and UX
[[Nametags and Overhead Bars - Cost and Visibility Rules]] · [[Off-Screen Objective Markers and Waypoint Arrows]] · [[ScreenGui Fundamentals]] · [[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 07 Lighting VFX and Audio
[[Highlights and Selection Effects]]

### 09 Gameplay Systems
[[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Downed, Revive and Bleed-Out States]] · [[Quests and Objectives]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 24 Worked Builds
[[Global Leaderboards End to End]] · [[Melee Combat System End to End]] · [[Pet Hatching and Following End to End]]

### 36 Narrative and Worldbuilding
[[Lore Delivery Without Walls of Text]] · [[Quest Writing and Hooks]]

### 42 Accessibility and Inclusive Design
[[Readable Text and UI Scale]]

### 46 Resource Library
[[Official Docs - UI]]

### 49 Roblox Platform Features
[[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 51 2D Game Development
[[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]

### 52 Core Concepts
[[Accessibility Contrast]] · [[Replication Boundary]]

### 58 Player QoL and Game Tweaks
[[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]]

### 62 Engine Reference Cards
[[BillboardGui - Engine Reference Card]]

Also mentioned in (not linked): 00 Start Here · Engine Reference Cards Start Here · ScrollingFrame - Engine Reference Card · Text Fonts and Rich Text · Textures Decals and Texture Memory · Tutorial Step Design Patterns - Teach by Doing · Visual AI Debugging - State Labels, Path Lines and Perception Gizmos

<!-- atlas:generated -->
