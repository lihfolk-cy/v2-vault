---
tags: [atlas, concept, type/atlas, area/2d, area/scripting]
---
# Fixed Timestep

<!-- tldr:start -->
> [!tldr] TL;DR
> - A fixed timestep means the simulation always advances by the same `dt` (for example 1/60 s), as many times as needed to catch...
> - Fixed timestep with accumulator, frame clamp, max steps per frame, and interpolation alpha.
> - Use a fixed timestep. Stepping a simulation with the frame's `dt` gives different results at 30 and 60 fps.
> - Your own fixed-timestep loop gives you that; the physics engine does not.
>
> Cost: TL;DR ~140 tok · whole note ~350 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A fixed timestep means the simulation always advances by the same `dt` (for example 1/60 s), as many times as needed to catch up with real time. (from [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]])

## Key facts

- Fixed timestep with accumulator, frame clamp, max steps per frame, and interpolation alpha. ([[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]])
- Use a fixed timestep. Stepping a simulation with the frame's `dt` gives different results at 30 and 60 fps. ([[Deterministic Simulation]])
- Your own fixed-timestep loop gives you that; the physics engine does not. ([[Choosing GUI 2D or Locked-Camera 2.5D]])
- Kinematic ship. Anchor the ship and move it by `PivotTo` on a fixed timestep on the server, with clients smoothing. ([[Boats Buoyancy and Water]])

## Mentioned in

7 notes in 4 sections. The 7 most relevant are linked:

### 25 Physics and Vehicles
[[Boats Buoyancy and Water]]

### 35 Advanced Luau
[[Advanced Luau Start Here]] · [[Custom Schedulers and Coroutine Patterns]]

### 51 2D Game Development
[[2D Game Development Start Here]] · [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] · [[Choosing GUI 2D or Locked-Camera 2.5D]]

### 52 Core Concepts
[[Deterministic Simulation]]

<!-- atlas:generated -->
