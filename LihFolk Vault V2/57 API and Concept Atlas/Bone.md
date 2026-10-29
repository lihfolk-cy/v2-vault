---
tags: [atlas, api, type/atlas, area/animation, area/physics, api/Bone]
---
# Bone

<!-- tldr:start -->
> [!tldr] TL;DR
> - A Bone is an Attachment: its `CFrame` is the rest pose relative to the parent, `Transform` is the animated offset on top.
> - Avoid: Using `Bone.WorldCFrame` for animated position -> `TransformedWorldCFrame` (Bones and Skinned Meshes)
> - Joint lookup accepts `Motor6D`, `AnimationConstraint` and `Bone`.
> - Roblox supports skinned meshes driven by `Bone` instances, used for creatures, custom characters, layered clothing and soft props.
>
> Cost: TL;DR ~150 tok · whole note ~510 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A Bone is an Attachment: its `CFrame` is the rest pose relative to the parent, `Transform` is the animated offset on top. (from [[Motor6D Math and CFrame Composition]])

Bone roll: Rotation of a Blender bone about its own axis; decides which way "pitch" bends a limb. (from [[Animation Glossary]])

API snapshot: class, inherits `Attachment` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Using `Bone.WorldCFrame` for animated position -> `TransformedWorldCFrame` ([[Bones and Skinned Meshes]])
- Joint lookup accepts `Motor6D`, `AnimationConstraint` and `Bone`. ([[Procedural Animation]])
- Roblox supports skinned meshes driven by `Bone` instances, used for creatures, custom characters, layered clothing and soft props. ([[Skinning Weights]])

## Mentioned in

28 notes in 4 sections. The 25 most relevant are linked:

### 08 Animation
[[Accessories and Armor That Follow Animation]] · [[Animation Data from Blender to Roblox]] · [[Animation Editor Workflow]] · [[Animation Glossary]] · [[Animation Objects]] · [[Animator Deep Dive]] · [[Blender Armature and Bone Roll Conventions]] · [[Bones and Skinned Meshes]] · [[Creature Rig Conventions]] · [[CurveAnimation and Curve Channels]] · [[Debugging Animation Problems]] · [[Enemy Import Axis Fix]] · [[Enemy and NPC Animation]] · [[Engine Gotchas]] · [[Foot Placement and Ground IK]] · [[Frame Order and RunService Timing]] · [[Motor6D Math and CFrame Composition]] · [[Pipeline - Importing Animated Enemies]] · [[Procedural Animation]] · [[Replication and Ownership]] · [[Retargeting Animations Between Rigs]] · [[Rigging in Blender]] · [[Snippets - Lua Keyframe Player Core]] · [[Weight Painting and Skinning for Roblox]]

### 25 Physics and Vehicles
[[Ropes Chains and Soft Bodies]]

Also mentioned in (not linked): Rigs and Joints · Skinning Weights · Squash Stretch and Anticipation in UI and Characters

<!-- atlas:generated -->
