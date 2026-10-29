---
tags: [atlas, api, type/atlas, area/animation, area/ai, api/Part0]
---
# Part0

<!-- tldr:start -->
> [!tldr] TL;DR
> - C0 / C1: A Motor6D's rest offsets in Part0 and Part1 space.
> - Avoid: Root pose not named after Part0 -> name the weight-0 root pose `Handle` (the motors' Part0) (Weapon Rig Player)
> - `C0` places the joint frame in Part0's space.
> - One weapon pipeline keyed its motors by `Part0.Name + "\0" + Part1.Name` in its own Lua player to survive this, but the real...
>
> Cost: TL;DR ~130 tok · whole note ~580 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

C0 / C1: A Motor6D's rest offsets in Part0 and Part1 space. (from [[Animation Glossary]])

API snapshot: member of `AnimationConstraint`, `JointInstance`, `NoCollisionConstraint`, `WeldConstraint` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Root pose not named after Part0 -> name the weight-0 root pose `Handle` (the motors' Part0) ([[Weapon Rig Player]])
- `C0` places the joint frame in Part0's space. ([[Motor6D Math and CFrame Composition]])
- One weapon pipeline keyed its motors by `Part0.Name + "\0" + Part1.Name` in its own Lua player to survive this, but the real Animator does not. ([[Rigs and Joints]])
- Reading `Part0.CFrame` from the scene for FK in `PreSimulation` (last frame's value). ([[Snippets - Building and Sampling Clips]])

## Mentioned in

36 notes in 3 sections. The 25 most relevant are linked:

### 08 Animation
[[Accessories and Armor That Follow Animation]] · [[Animation Data from Blender to Roblox]] · [[Animation Editor Workflow]] · [[Animation Glossary]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Baked Clip Stubs and Archiving]] · [[Clip Buffer Format]] · [[Custom Rigs - Weapons and Props]] · [[Debugging Animation Problems]] · [[Inverse Kinematics]] · [[Motor6D Math and CFrame Composition]] · [[Procedural Animation]] · [[R15 Rig Anatomy and Attachments]] · [[Ragdolls and Physics-Based Animation]] · [[Rigs and Joints]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - IK]] · [[Snippets - Procedural Motion]] · [[Snippets - Ragdoll]] · [[Testing Animations in Studio]] · [[Two-Bone IK Math]] · [[Weapon Design Rig Builder]] · [[Weapon Rig Player]]

### 15 AI Tools
[[AI Pitfalls - Physics and Animation]]

### 56 Field Notes
[[Held Weapons on Motor6D - Locking the Grip During Attacks]]

Also mentioned in (not linked): Blender Armature and Bone Roll Conventions · Bones and Skinned Meshes · Engine Gotchas · Ground Fitting Pipeline · IKControl Reference · KeyframeSequence Keyframe and Pose Reference · Look-At Aim and Head Tracking · Lua Keyframe Player Internals · Retargeting Animations Between Rigs · Weapon Swing Design · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
