---
tags: [atlas, api, type/atlas, area/animation, area/vfx, api/Camera]
---
# Camera

<!-- tldr:start -->
> [!tldr] TL;DR
> - Camera is `Scriptable`, re-asserted after respawn, updated at `RenderPriority.Camera`, and sets `Focus`.
> - Avoid: Shake written into `CFrame` without removal -> Apply at Camera+1, remove at Camera-1.
> - Camera code only on the client; bound at the right RenderStep priority.
> - Avoid: Writing `Camera.CFrame` additively without removing it (camera drifts).
>
> Cost: TL;DR ~130 tok · whole note ~760 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Camera is `Scriptable`, re-asserted after respawn, updated at `RenderPriority.Camera`, and sets `Focus`. (from [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]])

API snapshot: class, inherits `PVInstance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Shake written into `CFrame` without removal -> Apply at Camera+1, remove at Camera-1. ([[Camera Systems]])
- Camera code only on the client; bound at the right RenderStep priority. ([[Camera Systems]])
- Avoid: Writing `Camera.CFrame` additively without removing it (camera drifts). ([[Snippets - Camera Shake and FX]])
- Effect never visible: Step bound before or at `Camera` priority -> Bind at `Camera.Value + 1` ([[Layering Camera Feedback on the Default Camera]])
- Camera keeps clipping indoors: Real-world ceiling heights -> 2 to 3 avatar heights indoors. ([[Modelling to the Roblox Camera and Player Scale]])

## Mentioned in

34 notes in 17 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Off-Screen Objective Markers and Waypoint Arrows]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Game Feel and Juice]] · [[The Audio API - Players Emitters Wires and Effects]]

### 08 Animation
[[Animation LOD]] · [[Camera Shake and Camera FX]] · [[Cameras and Cutscenes]] · [[Engine Gotchas]] · [[Frame Order and RunService Timing]] · [[Snippets - Camera Shake and FX]]

### 09 Gameplay Systems
[[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]] · [[Camera Systems]] · [[Chase Cameras and Speed Effects for Vehicles]] · [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]]

### 42 Accessibility and Inclusive Design
[[Motion Sensitivity and Camera Comfort]]

### 47 Game Feel and Juice
[[Hit-Stop and Screen Shake Tuning by Numbers]]

### 49 Roblox Platform Features
[[Photo Mode and In-Game Screenshots with CaptureService]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 54 Untextured Stylised Modelling
[[Faceted Low-Poly - Flat Normals and Facet Size]]

### 55 Modelling Nuance and Readability
[[Modelling to the Roblox Camera and Player Scale]]

### 56 Field Notes
[[Layering Camera Feedback on the Default Camera]] · [[Springs That Survive Long Frames - dt Clamps and NaN Guards]]

### 58 Player QoL and Game Tweaks
[[Aim Assist and Generous Hitboxes]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]]

Also mentioned in (not linked): Intersection and Collision Math · Responsive UI for Phone Tablet Console and PC · Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur · Script Performance · Terrain Deep Dive - Materials Water and Performance · Testing Animations in Studio · Thumbnails Icons and Store Page · Voxel Scale Grids and Stud Alignment · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
