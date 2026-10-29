---
tags: [atlas, api, type/atlas, area/animation, area/physics, api/PreSimulation]
---
# PreSimulation

<!-- tldr:start -->
> [!tldr] TL;DR
> - `PreSimulation` runs before physics each frame, which is where control inputs belong.
> - Avoid: Procedural `Transform` write in `PreRender` / `RenderStepped` -> PreSimulation.
> - Avoid: Writing in `Heartbeat` -> PreSimulation.
> - Procedural head turn does nothing on a character: write happens in `PreRender` or `Heartbeat` -> move it to `PreSimulation`...
>
> Cost: TL;DR ~130 tok · whole note ~810 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`PreSimulation` runs before physics each frame, which is where control inputs belong. (from [[Cars with Constraints - Suspension Steering and Drive]])

API snapshot: member of `RunService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Procedural `Transform` write in `PreRender` / `RenderStepped` -> PreSimulation. ([[Frame Order and RunService Timing]])
- Avoid: Writing in `Heartbeat` -> PreSimulation. ([[Frame Order and RunService Timing]])
- Procedural head turn does nothing on a character: write happens in `PreRender` or `Heartbeat` -> move it to `PreSimulation` ([[Procedural Animation]])
- Writes to animated joints happen in `PreSimulation`. ([[Procedural Animation]])
- No per-frame C0 writes on characters; procedural layers write `Transform` in `PreSimulation` and skip throttled frames. ([[AnimationConstraint and Physically Simulated Characters]])

## Mentioned in

54 notes in 11 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Testing Modes - Play Run and Multi-Client]]

### 02 Luau Scripting
[[Task Library Coroutines and Yielding]]

### 08 Animation
[[AnimationConstraint and Physically Simulated Characters]] · [[Animator Deep Dive]] · [[Bones and Skinned Meshes]] · [[Debugging Animation Problems]] · [[Engine Gotchas]] · [[Frame Order and RunService Timing]] · [[How the Animator Really Behaves]] · [[Idle Breathing and Secondary Motion]] · [[Inverse Kinematics]] · [[Look-At Aim and Head Tracking]] · [[Motor6D Math and CFrame Composition]] · [[Open Questions]] · [[Performance and Memory]] · [[Procedural Animation]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - IK]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Procedural Motion]] · [[Troubleshooting Table]] · [[Two-Bone IK Math]]

### 12 Performance Testing and Debugging
[[Script Performance]]

### 25 Physics and Vehicles
[[Boats Buoyancy and Water]] · [[Cars with Constraints - Suspension Steering and Drive]]

Also mentioned in (not linked): 2D Game Development Start Here · AI Code Assistants for Luau · AI Pitfalls - Physics and Animation · Animation Objects · Custom Rigs - Weapons and Props · Custom Schedulers and Coroutine Patterns · Events Signals and Connections · Feedback Timing - Sound Visual and Haptic Sync · Foot Placement and Ground IK · Held Weapons on Motor6D - Locking the Grip During Attacks · IKControl Reference · Lua Keyframe Player · Lua Keyframe Player Internals · MicroProfiler Guide · Mover Constraints and Physics Controllers · Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run · Playback, Priorities and Blending · Procedural Death Knockdown and Hit Reactions · Procedural Weapon Motion · Prompting and Verifying AI Output · Ragdolls and Physics-Based Animation · Replication and Ownership · Rigs and Joints · Ropes Chains and Soft Bodies · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Snippets - Animation Controller Module · Snippets - Ragdoll · Standing on Moving Vehicles and Platforms - Keeping Players Glued · Weapon Rig Player

<!-- atlas:generated -->
