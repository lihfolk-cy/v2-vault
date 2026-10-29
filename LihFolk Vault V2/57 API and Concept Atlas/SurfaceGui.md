---
tags: [atlas, api, type/atlas, area/ui, area/gameplay, api/SurfaceGui]
---
# SurfaceGui

<!-- tldr:start -->
> [!tldr] TL;DR
> - SurfaceGui canvas size is texture memory: compute `face size x PixelsPerStud` before shipping.
> - Per-player content (a terminal showing your own stats): keep the `SurfaceGui` in `PlayerGui` (or created by a LocalScript...
> - SurfaceGui with a Pixelated ImageLabel. A SurfaceGui on a part renders GUI objects on the surface, and ImageLabel keeps its...
> - The 2D game lives inside a 3D game. A minigame on an arcade cabinet (a `SurfaceGui` on a part), a lockpicking bar, a fishing...
>
> Cost: TL;DR ~160 tok · whole note ~710 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

SurfaceGui canvas size is texture memory: compute `face size x PixelsPerStud` before shipping. (from [[World-Space UI - BillboardGui and SurfaceGui]])

API snapshot: class, inherits `SurfaceGuiBase` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Per-player content (a terminal showing your own stats): keep the `SurfaceGui` in `PlayerGui` (or created by a LocalScript there) and set its `Adornee` to the part. ([[World-Space UI - BillboardGui and SurfaceGui]])
- SurfaceGui with a Pixelated ImageLabel. A SurfaceGui on a part renders GUI objects on the surface, and ImageLabel keeps its `ResampleMode`. ([[Pixel Art Pipeline - Aseprite to Roblox Without Blur]])
- The 2D game lives inside a 3D game. A minigame on an arcade cabinet (a `SurfaceGui` on a part), a lockpicking bar, a fishing reel, a phone app inside the game. ([[Choosing GUI 2D or Locked-Camera 2.5D]])
- `SurfaceGui` signs depend on `PixelsPerStud` and viewing angle. ([[Readable Text and UI Scale]])

## Mentioned in

30 notes in 20 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Packages and Asset Reuse]]

### 04 Data and Persistence
[[OrderedDataStores and Leaderboards]]

### 05 UI and UX
[[Nametags and Overhead Bars - Cost and Visibility Rules]] · [[Off-Screen Objective Markers and Waypoint Arrows]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 06 World Building and Art
[[Textures Decals and Texture Memory]]

### 07 Lighting VFX and Audio
[[Highlights and Selection Effects]]

### 09 Gameplay Systems
[[Downed, Revive and Bleed-Out States]] · [[Quests and Objectives]]

### 12 Performance Testing and Debugging
[[Client Zone Culling for Interiors and Cities]]

### 15 AI Tools
[[AI Pitfalls - UI and Input]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 24 Worked Builds
[[Global Leaderboards End to End]]

### 33 Level Design
[[Lobby and Hub Design]] · [[Playtest Heatmaps - Position and Death Maps]]

### 36 Narrative and Worldbuilding
[[Lore Delivery Without Walls of Text]] · [[Quest Writing and Hooks]]

### 40 Game Math
[[Curves in Luau - Paths Beams and Motion]]

### 42 Accessibility and Inclusive Design
[[Readable Text and UI Scale]]

### 46 Resource Library
[[Links - Containers]]

### 49 Roblox Platform Features
[[Console and VR Release Checklists]] · [[Policy and Age Rules 2026]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]

### 52 Core Concepts
[[Accessibility Contrast]]

Also mentioned in (not linked): 00 Start Here · Replication Boundary · ScreenGui Fundamentals · Text Fonts and Rich Text · Tycoon Plots and Droppers End to End

<!-- atlas:generated -->
