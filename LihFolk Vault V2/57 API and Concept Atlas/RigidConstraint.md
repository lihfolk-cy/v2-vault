---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/RigidConstraint]
---
# RigidConstraint

<!-- tldr:start -->
> [!tldr] TL;DR
> - `RigidConstraint` can be set to break when a force or torque threshold is exceeded (check its reference page for the current...
> - Socket on a skinned rig: `RigidConstraint` to a Bone.
> - Rigid props attach with `RigidConstraint` to a bone.
> - `WeldConstraint`, `Weld`, `RigidConstraint`, `Motor6D` and other `JointInstance`s join parts into one assembly.
>
> Cost: TL;DR ~130 tok · whole note ~460 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`RigidConstraint` can be set to break when a force or torque threshold is exceeded (check its reference page for the current property names). (from [[Physics Assemblies and Constraints]])

`RigidConstraint` has hidden properties named `DestructionEnabled`, `DestructionForce` and `DestructionTorque` in the API dump, but this note could not find official documentation of their behaviour as of October 2026. (from [[Destruction and Fracture]])

API snapshot: class, inherits `Constraint` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Socket on a skinned rig: `RigidConstraint` to a Bone. ([[Accessories and Armor That Follow Animation]])
- Rigid props attach with `RigidConstraint` to a bone. ([[Bones and Skinned Meshes]])
- `WeldConstraint`, `Weld`, `RigidConstraint`, `Motor6D` and other `JointInstance`s join parts into one assembly. ([[Physics Assemblies and Constraints]])
- For Bone sockets use `RigidConstraint` (attachment based). ([[Weight Painting and Skinning for Roblox]])

## Mentioned in

13 notes in 5 sections. The 13 most relevant are linked:

### 08 Animation
[[3D Importer Settings Reference]] · [[Accessories and Armor That Follow Animation]] · [[Bones and Skinned Meshes]] · [[Creature Rig Conventions]] · [[Pipeline - Importing Animated Enemies]] · [[Rigging in Blender]] · [[Rigs and Joints]] · [[Weight Painting and Skinning for Roblox]]

### 09 Gameplay Systems
[[Grabs, Carries and Throws - Moving Players Safely]] · [[Physics Assemblies and Constraints]]

### 25 Physics and Vehicles
[[Destruction and Fracture]]

### 46 Resource Library
[[Official Docs - Physics]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
