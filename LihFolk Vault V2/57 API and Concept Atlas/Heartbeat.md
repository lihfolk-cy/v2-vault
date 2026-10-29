---
tags: [atlas, api, type/atlas, area/animation, area/performance, api/Heartbeat]
---
# Heartbeat

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Heartbeat` runs in Edit in Studio, which is why this works without a running game (rule of thumb, widely relied on by plugins).
> - Avoid: Writing in `Heartbeat` -> PreSimulation.
> - Procedural head turn does nothing on a character: write happens in `PreRender` or `Heartbeat` -> move it to `PreSimulation`...
> - Camera judders while running: Camera updated in `Heartbeat` or with frame dependent lerp -> Bind at `RenderPriority.Camera`...
>
> Cost: TL;DR ~150 tok · whole note ~810 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Heartbeat` runs in Edit in Studio, which is why this works without a running game (rule of thumb, widely relied on by plugins). (from [[Plugin UI with DockWidgets]])

API snapshot: member of `RunService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Writing in `Heartbeat` -> PreSimulation. ([[Frame Order and RunService Timing]])
- Procedural head turn does nothing on a character: write happens in `PreRender` or `Heartbeat` -> move it to `PreSimulation` ([[Procedural Animation]])
- Camera judders while running: Camera updated in `Heartbeat` or with frame dependent lerp -> Bind at `RenderPriority.Camera`, use `1 - exp(-k * dt)` ([[Side-Scroller in 3D - Locking Camera and Movement to a Plane]])
- Avoid: Writing joints in `PreRender`/`Heartbeat` (overwritten by the next animation step). ([[Snippets - Procedural Motion]])
- Server loop on `Heartbeat` with accumulator; one input per player per tick; queue capped. ([[2D Multiplayer - Server Authority and Replicating GUI Worlds]])

## Mentioned in

44 notes in 20 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Testing Modes - Play Run and Multi-Client]]

### 02 Luau Scripting
[[CollectionService Patterns]] · [[Events Signals and Connections]] · [[Math Vectors and CFrames]] · [[Task Library Coroutines and Yielding]]

### 03 Architecture and Networking
[[Entity Component Systems]]

### 08 Animation
[[Animator Deep Dive]] · [[Custom Locomotion Controller Design]] · [[Debugging Animation Problems]] · [[Engine Gotchas]] · [[Frame Order and RunService Timing]] · [[Procedural Animation]] · [[Snippets - Procedural Motion]]

### 10 Game Design and Genres
[[Genre Playbook - Tower Defense]]

### 12 Performance Testing and Debugging
[[Debugger Breakpoints and Logging]] · [[Script Performance]]

### 15 AI Tools
[[AI Code Assistants for Luau]] · [[AI Pitfalls - Physics and Animation]]

### 22 Anti-Exploit and Security
[[Detecting Combat Exploits - Reach Rate and Aim]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 35 Advanced Luau
[[Custom Schedulers and Coroutine Patterns]]

### 40 Game Math
[[Curves in Luau - Paths Beams and Motion]]

### 47 Game Feel and Juice
[[Feedback Timing - Sound Visual and Haptic Sync]]

### 51 2D Game Development
[[2D Multiplayer - Server Authority and Replicating GUI Worlds]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

Also mentioned in (not linked): 2D Game Development Start Here · Hitboxes and Hit Detection · Hunting Memory Leaks Step by Step · Infinite and Streamed Worlds · Interpolation Easing and Curves Math · Luau Garbage Collection and the Memory Model · Memory Budgets and Leaks · MicroProfiler Guide · Off-Screen Objective Markers and Waypoint Arrows · Performance Fundamentals · Plugin UI with DockWidgets · Procedural World Generation · Reading Luau Errors and Stack Traces · Retention and Return Hooks · Snippets - Camera Shake and FX · Tower Defense Waves and Placement End to End · Troubleshooting Table · Tween and CFrame Animation of Objects · Weapon Rig Player

<!-- atlas:generated -->
