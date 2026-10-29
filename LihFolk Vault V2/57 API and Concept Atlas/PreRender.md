---
tags: [atlas, api, type/atlas, area/animation, area/2d, api/PreRender]
---
# PreRender

<!-- tldr:start -->
> [!tldr] TL;DR
> - `PreRender` runs before the frame is drawn, which is where visual-only simulation belongs.
> - Avoid: Procedural `Transform` write in `PreRender` / `RenderStepped` -> PreSimulation.
> - Procedural head turn does nothing on a character: write happens in `PreRender` or `Heartbeat` -> move it to `PreSimulation`...
> - Avoid: Heavy work in `PreRender`/`RenderStepped`.
>
> Cost: TL;DR ~130 tok · whole note ~610 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`PreRender` runs before the frame is drawn, which is where visual-only simulation belongs. (from [[Ropes Chains and Soft Bodies]])

API snapshot: member of `RunService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Procedural `Transform` write in `PreRender` / `RenderStepped` -> PreSimulation. ([[Frame Order and RunService Timing]])
- Procedural head turn does nothing on a character: write happens in `PreRender` or `Heartbeat` -> move it to `PreSimulation` ([[Procedural Animation]])
- Avoid: Heavy work in `PreRender`/`RenderStepped`. ([[Script Performance]])
- Avoid: Writing joints in `PreRender`/`Heartbeat` (overwritten by the next animation step). ([[Snippets - Procedural Motion]])

## Mentioned in

30 notes in 13 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Events Signals and Connections]]

### 07 Lighting VFX and Audio
[[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]] · [[Particle Emitters In Depth]]

### 08 Animation
[[Animator Deep Dive]] · [[Debugging Animation Problems]] · [[Engine Gotchas]] · [[Frame Order and RunService Timing]] · [[Performance and Memory]] · [[Procedural Animation]] · [[Procedural Death Knockdown and Hit Reactions]] · [[Replication and Ownership]] · [[Snippets - Procedural Motion]]

### 12 Performance Testing and Debugging
[[MicroProfiler Guide]] · [[Performance Fundamentals]] · [[Script Performance]]

### 15 AI Tools
[[AI Code Assistants for Luau]]

### 24 Worked Builds
[[Pet Hatching and Following End to End]]

### 25 Physics and Vehicles
[[Ropes Chains and Soft Bodies]]

### 29 Luau Cookbook
[[Cookbook - Math CFrame and Vectors]]

### 35 Advanced Luau
[[Custom Schedulers and Coroutine Patterns]]

### 47 Game Feel and Juice
[[Feedback Timing - Sound Visual and Haptic Sync]] · [[Hit-Stop and Screen Shake Tuning by Numbers]]

### 51 2D Game Development
[[2D Multiplayer - Server Authority and Replicating GUI Worlds]] · [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]

### 56 Field Notes
[[Layering Camera Feedback on the Default Camera]]

Also mentioned in (not linked): 2D Game Development Start Here · Task Library Coroutines and Yielding · Testing Modes - Play Run and Multi-Client · Tilemaps Cameras and Parallax for 2D Levels · Troubleshooting Table

<!-- atlas:generated -->
