---
tags: [atlas, api, type/atlas, area/gameplay, area/animation, api/MaxVelocity]
---
# MaxVelocity

<!-- tldr:start -->
> [!tldr] TL;DR
> - `MaxVelocity` is a walk speed. For an NPC, OneAttachment mode with `MaxVelocity = walkSpeed` and a high `MaxForce` gives you...
> - `AlignPosition`: `RigidityEnabled` true ignores `MaxForce`, `MaxVelocity` and `Responsiveness` and aligns "as quickly as...
> - Avoid: `Stop(0)` on rigs whose Motor6D `MaxVelocity` is 0.
> - Non-Humanoid NPCs. Movers (`AlignPosition` with `MaxVelocity` as speed) can follow waypoints exactly like `MoveTo`: set the...
>
> Cost: TL;DR ~150 tok · whole note ~420 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`MaxVelocity` is a walk speed. For an NPC, OneAttachment mode with `MaxVelocity = walkSpeed` and a high `MaxForce` gives you "go to this point at this speed" with physics doing the integration. (from [[Mover Constraints and Physics Controllers]])

API snapshot: member of `AlignPosition`, `Motor`, `VelocityMotor` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `AlignPosition`: `RigidityEnabled` true ignores `MaxForce`, `MaxVelocity` and `Responsiveness` and aligns "as quickly as possible" (Docs). ([[Mover Constraints and Physics Controllers]])
- Avoid: `Stop(0)` on rigs whose Motor6D `MaxVelocity` is 0. ([[Animator - Engine Reference Card]])
- Non-Humanoid NPCs. Movers (`AlignPosition` with `MaxVelocity` as speed) can follow waypoints exactly like `MoveTo`: set the goal to the next waypoint, advance when within a couple of studs. ([[Pathfinding]])
- The reference project's dry-run harnesses simulated a "kinematic mover": move the root to its `AlignPosition` goal at `MaxVelocity` per step. ([[Physics Assemblies and Constraints]])

## Mentioned in

7 notes in 5 sections. The 7 most relevant are linked:

### 08 Animation
[[AnimationTrack Reference]]

### 09 Gameplay Systems
[[Mover Constraints and Physics Controllers]] · [[Pathfinding]] · [[Physics Assemblies and Constraints]]

### 23 Debugging Deep Dives
[[Debugging Physics and Network Ownership]]

### 25 Physics and Vehicles
[[Standing on Moving Vehicles and Platforms - Keeping Players Glued]]

### 62 Engine Reference Cards
[[Animator - Engine Reference Card]]

<!-- atlas:generated -->
