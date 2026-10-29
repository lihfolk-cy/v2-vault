---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/BindToRenderStep]
---
# BindToRenderStep

<!-- tldr:start -->
> [!tldr] TL;DR
> - `BindToRenderStep` takes a name, an integer priority and a function receiving `dt` (Roblox docs).
> - Avoid: heavy work inside PreRender or BindToRenderStep.
> - Put every camera writer on `BindToRenderStep` with an explicit priority and document the order in one place.
> - Camera work belongs in `PreRender`/`BindToRenderStep`.
>
> Cost: TL;DR ~120 tok · whole note ~470 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`BindToRenderStep` takes a name, an integer priority and a function receiving `dt` (Roblox docs). (from [[Layering Camera Feedback on the Default Camera]])

API snapshot: member of `RunService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: heavy work inside PreRender or BindToRenderStep. ([[RunService - Engine Reference Card]])
- Put every camera writer on `BindToRenderStep` with an explicit priority and document the order in one place. ([[Snippets - Camera Shake and FX]])
- Camera work belongs in `PreRender`/`BindToRenderStep`. ([[Debugging Animation Problems]])

## Mentioned in

19 notes in 8 sections. The 19 most relevant are linked:

### 05 UI and UX
[[Off-Screen Objective Markers and Waypoint Arrows]]

### 08 Animation
[[Cameras and Cutscenes]] · [[Debugging Animation Problems]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[Frame Order and RunService Timing]] · [[Locomotion Systems]] · [[Procedural Animation]] · [[Procedural Gait and Footstep Planning]] · [[Snippets - Camera Shake and FX]]

### 09 Gameplay Systems
[[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]] · [[Camera Systems]] · [[Chase Cameras and Speed Effects for Vehicles]] · [[Mover Constraints and Physics Controllers]]

### 12 Performance Testing and Debugging
[[MicroProfiler Guide]] · [[Script Performance]]

### 51 2D Game Development
[[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 56 Field Notes
[[Layering Camera Feedback on the Default Camera]]

### 58 Player QoL and Game Tweaks
[[Camera Settings - FOV Shake Sensitivity and Shift-Lock]]

### 62 Engine Reference Cards
[[RunService - Engine Reference Card]]

<!-- atlas:generated -->
