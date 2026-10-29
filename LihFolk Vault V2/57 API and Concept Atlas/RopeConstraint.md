---
tags: [atlas, api, type/atlas, area/physics, area/animation, api/RopeConstraint]
---
# RopeConstraint

<!-- tldr:start -->
> [!tldr] TL;DR
> - RopeConstraint uses: restitution chosen, winch force above weight, explicit ownership.
> - Avoid: Expecting RopeConstraint to collide or wrap -> Accept it, or visual verlet with collision.
> - `HingeConstraint`, `RopeConstraint` and friends work as normal; in GUI 2D each of these is a mini physics project.
>
> Cost: TL;DR ~120 tok · whole note ~270 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

RopeConstraint uses: restitution chosen, winch force above weight, explicit ownership. (from [[Ropes Chains and Soft Bodies]])

API snapshot: class, inherits `Constraint` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Expecting RopeConstraint to collide or wrap -> Accept it, or visual verlet with collision. ([[Ropes Chains and Soft Bodies]])
- `HingeConstraint`, `RopeConstraint` and friends work as normal; in GUI 2D each of these is a mini physics project. ([[Choosing GUI 2D or Locked-Camera 2.5D]])

## Mentioned in

6 notes in 5 sections. The 6 most relevant are linked:

### 08 Animation
[[Scale and Animation]]

### 09 Gameplay Systems
[[Physics Assemblies and Constraints]]

### 25 Physics and Vehicles
[[Physics and Vehicles Start Here]] · [[Ropes Chains and Soft Bodies]]

### 46 Resource Library
[[Links - Constraints]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]]

<!-- atlas:generated -->
