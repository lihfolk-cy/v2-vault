---
tags: [atlas, concept, type/atlas, area/scripting, area/procedural]
---
# Parallel Luau

<!-- tldr:start -->
> [!tldr] TL;DR
> - Parallel Luau lets scripts placed under `Actor` instances run parts of their work simultaneously on several CPU cores.
> - Reaching for Parallel Luau or `--!native` before fixing what runs and how often.
> - Parallel Luau and Actors, Physics Performance, Network Performance.
> - Parallel Luau: systems over independent data can run in parallel with Actors, but writes to the DataModel must be...
>
> Cost: TL;DR ~140 tok · whole note ~720 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Parallel Luau lets scripts placed under `Actor` instances run parts of their work simultaneously on several CPU cores. (from [[Parallel Luau and Actors]])

Parallel Luau runs code on worker threads inside Actors. (from [[Script Performance]])

## Key facts

- Reaching for Parallel Luau or `--!native` before fixing what runs and how often. ([[Script Performance]])
- Parallel Luau and Actors, Physics Performance, Network Performance. ([[Infinite and Streamed Worlds]])
- Parallel Luau: systems over independent data can run in parallel with Actors, but writes to the DataModel must be synchronised; see Parallel Luau and Actors. ([[Entity Component Systems]])
- Parallel Luau can compute noise and voxel arrays in Actors, with the `WriteVoxels` call made back in serial (`task.synchronize()`), since writing to the DataModel requires the serial phase. ([[Procedural World Generation]])

## Mentioned in

37 notes in 15 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Events Signals and Connections]] · [[Luau Performance and Native Codegen]] · [[Module Scripts and Requiring]] · [[Parallel Luau and Actors]] · [[Task Library Coroutines and Yielding]]

### 03 Architecture and Networking
[[Entity Component Systems]]

### 06 World Building and Art
[[Procedural World Generation]]

### 08 Animation
[[Snippets - Lua Keyframe Player Core]] · [[Tween and CFrame Animation of Objects]]

### 09 Gameplay Systems
[[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Raycasts Shapecasts and Spatial Queries]]

### 12 Performance Testing and Debugging
[[MicroProfiler Guide]] · [[Script Performance]]

### 23 Debugging Deep Dives
[[Debugging Race Conditions and Yield Order]]

### 25 Physics and Vehicles
[[Projectiles and Ballistics]]

### 34 Procedural Generation
[[Infinite and Streamed Worlds]] · [[Noise Functions and Terrain Generation]] · [[Wave Function Collapse on Roblox]]

### 35 Advanced Luau
[[Building a Signal Library]] · [[Custom Schedulers and Coroutine Patterns]] · [[Luau Garbage Collection and the Memory Model]]

### 40 Game Math
[[Intersection and Collision Math]]

### 44 Materials and Surfaces
[[Terrain Materials and Painting]]

### 51 2D Game Development
[[2D Multiplayer - Server Authority and Replicating GUI Worlds]]

### 52 Core Concepts
[[Frame Budget]]

Also mentioned in (not linked): 00 Start Here · Advanced Luau Start Here · Frame Order and RunService Timing · Game Math Start Here · Glossary · Luau Performance Patterns with Benchmarks · Performance Fundamentals · Procedural Generation Start Here · Reading Luau Errors and Stack Traces · Script Types and Run Context · Serialization Formats for Saves and Networking · Terrain Deep Dive - Materials Water and Performance

<!-- atlas:generated -->
