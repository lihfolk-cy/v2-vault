---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/FieldOfView]
---
# FieldOfView

<!-- tldr:start -->
> [!tldr] TL;DR
> - `FieldOfView` is the vertical FOV in degrees, clamped 1 to 120, default 70 (Docs).
> - View zooms out forever: `FieldOfView +=` every frame -> Track and replace your contribution.
> - FOV resets after sprinting: Sprint writes `FieldOfView` directly -> One FOV owner with named kicks.
> - Effects fight sprint FOV: Two writers of FieldOfView -> One owner adds the stack's delta.
>
> Cost: TL;DR ~130 tok · whole note ~480 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`FieldOfView` is the vertical FOV in degrees, clamped 1 to 120, default 70 (Docs). (from [[Camera Systems]])

`FieldOfView` is clamped by the engine to 1 to 120 degrees (Roblox docs); clamp yourself so your bookkeeping matches what was stored. (from [[Layering Camera Feedback on the Default Camera]])

API snapshot: member of `Camera`, `RenderingTest` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- View zooms out forever: `FieldOfView +=` every frame -> Track and replace your contribution. ([[Layering Camera Feedback on the Default Camera]])
- FOV resets after sprinting: Sprint writes `FieldOfView` directly -> One FOV owner with named kicks. ([[Camera Settings - FOV Shake Sensitivity and Shift-Lock]])
- Effects fight sprint FOV: Two writers of FieldOfView -> One owner adds the stack's delta. ([[Camera Shake and Camera FX]])

## Mentioned in

13 notes in 9 sections. The 13 most relevant are linked:

### 05 UI and UX
[[Minimap and World Map UI - Projection, Rotation and Fog of War]]

### 08 Animation
[[Camera Shake and Camera FX]] · [[Cameras and Cutscenes]] · [[Snippets - Camera Shake and FX]]

### 09 Gameplay Systems
[[Camera Systems]] · [[Chase Cameras and Speed Effects for Vehicles]]

### 33 Level Design
[[Level Design Principles - Flow Sightlines and Landmarks]]

### 49 Roblox Platform Features
[[Server Authority and Input Migration 2026]]

### 51 2D Game Development
[[2D Game Development Start Here]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 55 Modelling Nuance and Readability
[[Modelling to the Roblox Camera and Player Scale]]

### 56 Field Notes
[[Layering Camera Feedback on the Default Camera]]

### 58 Player QoL and Game Tweaks
[[Camera Settings - FOV Shake Sensitivity and Shift-Lock]]

<!-- atlas:generated -->
