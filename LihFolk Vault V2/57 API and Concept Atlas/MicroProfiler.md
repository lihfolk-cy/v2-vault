---
tags: [atlas, concept, type/atlas, area/performance, area/animation]
---
# MicroProfiler

<!-- tldr:start -->
> [!tldr] TL;DR
> - MicroProfiler (Ctrl+F6 in Play) shows the animation step and your `PreSimulation` handlers.
> - Hot spot found in the MicroProfiler before touching code.
> - Hot spots identified in the MicroProfiler/Script Profiler before optimizing.
> - Record a server dump (Developer Console, MicroProfiler, Server, 60 frames).
>
> Cost: TL;DR ~120 tok · whole note ~1.0k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

MicroProfiler (Ctrl+F6 in Play) shows the animation step and your `PreSimulation` handlers. (from [[Debugging Animation Problems]])

## Key facts

- Hot spot found in the MicroProfiler before touching code. ([[Luau Performance Patterns with Benchmarks]])
- Hot spots identified in the MicroProfiler/Script Profiler before optimizing. ([[Luau Performance and Native Codegen]])
- Record a server dump (Developer Console, MicroProfiler, Server, 60 frames). ([[MicroProfiler Guide]])
- garbage collection after a lot of short-lived allocation (the `GC` label in the MicroProfiler),. ([[Performance Fundamentals]])

## Mentioned in

76 notes in 27 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Luau Performance Patterns with Benchmarks]] · [[Luau Performance and Native Codegen]] · [[Parallel Luau and Actors]]

### 03 Architecture and Networking
[[Frameworks - Knit Matter and Others]]

### 06 World Building and Art
[[Art Budgets - Triangles Draw Calls Memory]]

### 08 Animation
[[Debugging Animation Problems]] · [[Frame Order and RunService Timing]]

### 10 Game Design and Genres
[[Genre Playbook - Tower Defense]]

### 12 Performance Testing and Debugging
[[Client Zone Culling for Interiors and Cities]] · [[Developer Console and Stats]] · [[MicroProfiler Guide]] · [[Network Bandwidth Budgets and Measuring Them]] · [[Performance Fundamentals]] · [[Rendering Performance]] · [[Script Performance]] · [[Weather Performance Budgets and Quality Tiers]]

### 23 Debugging Deep Dives
[[Debugging Live Servers]]

### 25 Physics and Vehicles
[[Destruction and Fracture]]

### 28 Business and Careers
[[Building a Portfolio as a Roblox Developer]]

### 34 Procedural Generation
[[Infinite and Streamed Worlds]]

### 35 Advanced Luau
[[Luau Garbage Collection and the Memory Model]]

### 46 Resource Library
[[Official Docs - Performance]]

### 51 2D Game Development
[[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] · [[EditableImage for Pixel Buffers and Procedural 2D]]

### 52 Core Concepts
[[Frame Budget]]

Also mentioned in (not linked): 00 Start Here · 2D Game Development Start Here · AI Skills Start Here · AvatarEditorService and In-Game Avatar Editors · Behaviour Trees Utility AI and State Machines for NPCs · Choosing GUI 2D or Locked-Camera 2.5D · Debugging Start Here · Genre Playbook - Zombie and Wave Survival Co-op · Glossary · Horror Monster Chase AI End to End · Hunting Memory Leaks Step by Step · Juice on a Budget - Mobile and Low-End · Layered Clothing Cages and Animation · Light Sources and Shadows · Lighting Technologies and Settings · Load and Soak Testing Servers - Long Sessions and Many Clients · Materials MaterialVariants and SurfaceAppearance · Math Vectors and CFrames · Melee Combat System End to End · Memory Budgets and Leaks · Mesh Optimization for Mobile · Mobile and Low-End Optimization · NPC AI and Behaviour · Nametags and Overhead Bars - Cost and Visibility Rules · Network Performance · Notification and Toast Systems · Open Questions - Whole Vault · Pet Hatching and Following End to End · Physics Performance · Physics and Vehicles Start Here · Rain - Camera-Local Particles, Splashes and Wet Surfaces · Reading Luau Errors and Stack Traces · Ropes Chains and Soft Bodies · Skill - Roblox Performance Audit · Snippets - Camera Shake and FX · Snippets - Lua Keyframe Player Core · Snippets - Procedural Motion · Spawn Director - Credit Budgets and Player-Count Scaling · Springs That Survive Long Frames - dt Clamps and NaN Guards · Studio Assistant and AI Tools · Studio Interface Tour · SurfaceAppearance PBR Workflow · Terrain Deep Dive - Materials Water and Performance · Testing Your Own Remotes - Fuzzing and Abuse Tests · Textures Decals and Texture Memory · Tower Defense Waves and Placement End to End · Troubleshooting Table · Tycoon Plots and Droppers End to End · UI Motion Language and Timing · VFX Performance Budgets and Culling · Virtualized Lists and Large Inventories

<!-- atlas:generated -->
