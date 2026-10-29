---
tags: [atlas, api, type/atlas, area/animation, area/ui, api/ViewportFrame]
---
# ViewportFrame

<!-- tldr:start -->
> [!tldr] TL;DR
> - A ViewportFrame per inventory slot is a common performance mistake: 60 slots means 60 extra scene renders.
> - Animated rigs need a `WorldModel` inside the `ViewportFrame`, which costs more.
> - ViewportFrame rendering. Render the viewmodel in a full-screen `ViewportFrame` with its own camera; it can never clip.
> - Icons, not ViewportFrames, in cells. A ViewportFrame per cell renders a 3D scene per cell.
>
> Cost: TL;DR ~140 tok · whole note ~630 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A ViewportFrame per inventory slot is a common performance mistake: 60 slots means 60 extra scene renders. (from [[Icon and Thumbnail Rendering Pipeline]])

API snapshot: class, inherits `GuiObject` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Animated rigs need a `WorldModel` inside the `ViewportFrame`, which costs more. ([[World-Space UI - BillboardGui and SurfaceGui]])
- ViewportFrame rendering. Render the viewmodel in a full-screen `ViewportFrame` with its own camera; it can never clip. ([[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]])
- Icons, not ViewportFrames, in cells. A ViewportFrame per cell renders a 3D scene per cell. ([[Virtualized Lists and Large Inventories]])
- A rig in a `ViewportFrame` needs a `WorldModel` inside the viewport to animate. ([[Animator Deep Dive]])

## Mentioned in

26 notes in 11 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Menu Archetypes - Shop Settings Codes Rewards]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[Virtualized Lists and Large Inventories]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]]

### 08 Animation
[[Accessories and Armor That Follow Animation]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Animator Deep Dive]] · [[Engine Gotchas]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[How the Animator Really Behaves]] · [[Lua Keyframe Player]] · [[Testing Animations in Studio]] · [[UI and GUI Animation]]

### 09 Gameplay Systems
[[Character Select and Class Systems with Different Rigs]]

### 12 Performance Testing and Debugging
[[Testing Strategies and Frameworks]]

### 13 Production and Case Studies
[[Documentation and Knowledge Bases]] · [[Lessons Learned Index]] · [[Post-Mortem - Building a Melee Action Game]]

### 14 3D Modeling
[[Hand-Painted and Stylized Texturing]]

### 17 Pipelines
[[Icon and Thumbnail Rendering Pipeline]]

### 25 Physics and Vehicles
[[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]]

### 37 Avatars and UGC
[[AvatarEditorService and In-Game Avatar Editors]] · [[HumanoidDescription and Outfit Systems]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]]

Also mentioned in (not linked): Working with AI Assistants in Studio

<!-- atlas:generated -->
