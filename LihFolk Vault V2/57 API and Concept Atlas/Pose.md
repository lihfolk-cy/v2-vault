---
tags: [atlas, api, type/atlas, area/animation, area/ai, api/Pose]
---
# Pose

<!-- tldr:start -->
> [!tldr] TL;DR
> - A Pose's `CFrame` is the joint's Transform at that time (relative to the joint's rest, which is `C0`/`C1` or the constraint's...
> - Every Pose name matches a Part1 (or Bone) name on the target rig.
> - Avoid: Pose named after the joint (`RightShoulder`) -> Name after Part1 (`RightUpperArm`) (Rigs and Joints)
> - Pose instance counts explode quietly. A 2 second clip sampled at 30 keys per second over 25 joints is 60 keyframes times 25...
>
> Cost: TL;DR ~150 tok · whole note ~490 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A Pose's `CFrame` is the joint's Transform at that time (relative to the joint's rest, which is `C0`/`C1` or the constraint's attachments). (from [[Authoring Clips in Code]])

API snapshot: class, inherits `PoseBase` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Every Pose name matches a Part1 (or Bone) name on the target rig. ([[KeyframeSequence Keyframe and Pose Reference]])
- Avoid: Pose named after the joint (`RightShoulder`) -> Name after Part1 (`RightUpperArm`) ([[Rigs and Joints]])
- Pose instance counts explode quietly. A 2 second clip sampled at 30 keys per second over 25 joints is 60 keyframes times 25 poses, about 1,500 `Pose` instances. ([[Snippets - Building and Sampling Clips]])
- Pose names are Part1 names (for Motor6D rigs) or bone names. ([[Authoring Clips in Code]])

## Mentioned in

24 notes in 3 sections. The 24 most relevant are linked:

### 08 Animation
[[Animation Data from Blender to Roblox]] · [[Animation Editor Advanced]] · [[Animation Editor Workflow]] · [[Animation Objects]] · [[Authoring Clips in Code]] · [[Baked Clip Stubs and Archiving]] · [[Blender Armature and Bone Roll Conventions]] · [[Case Study - Cutting a Million Instances]] · [[Clip Buffer Format]] · [[Custom Rigs - Weapons and Props]] · [[Debugging Animation Problems]] · [[Enemy Import Axis Fix]] · [[Engine Gotchas]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Lua Keyframe Player Internals]] · [[Performance and Memory]] · [[Retargeting Animations Between Rigs]] · [[Rigs and Joints]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - Lua Keyframe Player Core]] · [[Testing Animations in Studio]] · [[Weapon Design Rig Builder]]

### 15 AI Tools
[[AI Animation and Motion from Video]]

### 51 2D Game Development
[[2D Multiplayer - Server Authority and Replicating GUI Worlds]]

<!-- atlas:generated -->
