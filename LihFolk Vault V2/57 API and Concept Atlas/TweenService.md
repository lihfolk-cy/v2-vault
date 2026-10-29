---
tags: [atlas, api, type/atlas, area/animation, area/ui, api/TweenService]
---
# TweenService

<!-- tldr:start -->
> [!tldr] TL;DR
> - TweenService has no spring easing, and tweens are bad at interruptible motion (a hover that starts while the previous un-hover...
> - Engine easing is sampled with `TweenService:GetValue` before you rely on its exact shape.
> - `TweenService` makes tweens one line, so most Roblox UI uses them for everything.
> - `CubicV2`: code `4 + direction` (In 0, Out 1, InOut 2): TweenService directions.
>
> Cost: TL;DR ~140 tok · whole note ~910 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

TweenService has no spring easing, and tweens are bad at interruptible motion (a hover that starts while the previous un-hover is still tweening restarts from a fixed curve). (from [[UI and GUI Animation]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Engine easing is sampled with `TweenService:GetValue` before you rely on its exact shape. ([[Interpolation Easing and Curves Math]])
- `TweenService` makes tweens one line, so most Roblox UI uses them for everything. ([[Tween vs Spring]])
- `CubicV2`: code `4 + direction` (In 0, Out 1, InOut 2): TweenService directions. ([[Lua Keyframe Player Internals]])
- Avoid: A tool writes legacy `Cubic` with TweenService meanings -> rewrite to CubicV2 (keep the intended direction) ([[Moon Animator and Third-Party Tools]])

## Mentioned in

64 notes in 22 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Accessibility]] · [[Gamepad and Console UX]] · [[ScreenGui Fundamentals]] · [[UI Motion Language and Timing]]

### 06 World Building and Art
[[Zone and Biome Art Direction]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Game Feel and Juice]] · [[Music and Adaptive Audio]]

### 08 Animation
[[IKControl Reference]] · [[Snippets - Camera Shake and FX]] · [[Snippets - IK]] · [[Snippets - Procedural Motion]] · [[Tween and CFrame Animation of Objects]] · [[UI and GUI Animation]] · [[Weapon Rig Player]]

### 09 Gameplay Systems
[[Camera Systems]] · [[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]]

### 24 Worked Builds
[[Melee Combat System End to End]]

### 29 Luau Cookbook
[[Cookbook - UI]]

### 40 Game Math
[[Interpolation Easing and Curves Math]]

### 46 Resource Library
[[Official Docs - UI]]

### 52 Core Concepts
[[Easing]]

### 56 Field Notes
[[Centre-Screen Announcements That Stay Centred]]

### 58 Player QoL and Game Tweaks
[[Audio Mixer Settings with SoundGroups]]

### 62 Engine Reference Cards
[[TweenService - Engine Reference Card]]

Also mentioned in (not linked): AI Pitfalls - Stale APIs and Luau · Animation Editor Workflow · Authoring Clips in Code · Beams and Trails · Camera - Engine Reference Card · Camera Obstruction Handling - Occlusion Modes, Fades and Collision · CollectionService Patterns · Curves in Luau - Paths Beams and Motion · Declarative UI - React-Lua and Fusion · Engine Gotchas · Engine Reference Cards Start Here · Genre Playbook - Obbies and Platformers · Highlights and Selection Effects · Horror Monster Chase AI End to End · Keyframes, Easing and Interpolation · Light Sources and Shadows · Lua Keyframe Player · Lua Keyframe Player Internals · Mesh VFX Packs Built in Blender · MicroProfiler Guide · Moon Animator and Third-Party Tools · Network Performance · Open Questions · Open Questions - Whole Vault · Pet Hatching and Following End to End · Prompting and Verifying AI Output · Replication and Ownership · Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars · Rigs and Joints · Snippets - Building and Sampling Clips · Springs Damping and Smoothing · Standing on Moving Vehicles and Platforms - Keeping Players Glued · Stylized Lighting Recipes · Terrain Deep Dive - Materials Water and Performance · Terrain Materials and Painting · Timing Spacing and Frame Charts · Tween vs Spring · UI Layout Objects - Lists Grids and Pages · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
