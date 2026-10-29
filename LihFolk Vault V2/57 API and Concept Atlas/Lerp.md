---
tags: [atlas, concept, type/atlas, area/animation, area/vfx]
---
# Lerp

<!-- tldr:start -->
> [!tldr] TL;DR
> - Lerp is not always the shortest rotation you expect.
> - Every tunable curve is `invLerp, clamp, shape, lerp`, with its shape named in config.
> - Smoothing feels faster on high-refresh monitors: `lerp` by a constant per frame -> `1 - exp(-k dt)` (Springs Damping and...
> - Avoid: Constant-fraction lerp magnet. Feels sticky at the end.
>
> Cost: TL;DR ~120 tok · whole note ~780 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Lerp is not always the shortest rotation you expect. `CFrame:Lerp` interpolates rotation along the shortest arc, which is usually right, but for a rotation of almost exactly 180 degrees the "shortest" direction is ambiguous and can flip between frames. (from [[Math Vectors and CFrames]])

## Key facts

- Every tunable curve is `invLerp, clamp, shape, lerp`, with its shape named in config. ([[Interpolation Easing and Curves Math]])
- Smoothing feels faster on high-refresh monitors: `lerp` by a constant per frame -> `1 - exp(-k dt)` ([[Springs Damping and Smoothing]])
- Avoid: Constant-fraction lerp magnet. Feels sticky at the end. ([[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]])
- Avoid: Host lerped to the camera -> Snap to camera each frame. ([[Rain - Camera-Local Particles, Splashes and Wet Surfaces]])
- One-frame forearm spin mid-swing: Euler lerp across the 180-degree boundary -> Wrapped delta, or convert to CFrame and `Lerp` ([[Animation Data Hygiene - Euler Wrap Joint Holes and Easing]])

## Mentioned in

35 notes in 15 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Math Vectors and CFrames]]

### 03 Architecture and Networking
[[Snapshot Interpolation for Custom Replication]]

### 06 World Building and Art
[[Grid Placement and Player Building Systems]]

### 07 Lighting VFX and Audio
[[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Weather System Architecture - State Machine, Transitions and Replication]]

### 08 Animation
[[Authoring Clips in Code]] · [[Cameras and Cutscenes]] · [[CurveAnimation and Curve Channels]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[How the Animator Really Behaves]] · [[Keyframes, Easing and Interpolation]] · [[Lua Keyframe Player]] · [[Lua Keyframe Player Internals]] · [[Motor6D Math and CFrame Composition]] · [[Springs Damping and Smoothing]] · [[Weapon Rig Player]]

### 09 Gameplay Systems
[[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]]

### 14 3D Modeling
[[Bezier Curves and Splines for Modellers]]

### 29 Luau Cookbook
[[Cookbook - Math CFrame and Vectors]]

### 40 Game Math
[[Interpolation Easing and Curves Math]] · [[Rotations Angles and Quaternions]]

### 51 2D Game Development
[[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]

### 56 Field Notes
[[Animation Data Hygiene - Euler Wrap Joint Holes and Easing]]

Also mentioned in (not linked): Off-Screen Objective Markers and Waypoint Arrows · Performance and Memory · Pet Hatching and Following End to End · Principles of Animation for Games · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Snippets - Building and Sampling Clips · Snippets - Lua Keyframe Player Core · Stylized Lighting Recipes · Terrain Materials and Painting · Weather Performance Budgets and Quality Tiers

<!-- atlas:generated -->
