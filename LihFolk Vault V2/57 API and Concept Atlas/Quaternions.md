---
tags: [atlas, concept, type/atlas, area/animation, area/math]
---
# Quaternions

<!-- tldr:start -->
> [!tldr] TL;DR
> - Quaternions keep the motion identical and avoid gimbal problems on shoulders and hips that rotate on several axes at once.
> - Rotations are stored as rotation vectors (`axis * angle`, from `CFrame:ToAxisAngle()`), not quaternions or CFrames, because...
> - Quaternion to matrix: `CFrame.new(x, y, z, qX, qY, qZ, qW)` (Roblox docs (as of October 2026)).
> - Quaternions: the conversion preserves the motion exactly.
>
> Cost: TL;DR ~140 tok · whole note ~690 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Quaternions keep the motion identical and avoid gimbal problems on shoulders and hips that rotate on several axes at once. (from [[Animation Editor Advanced]])

## Key facts

- Rotations are stored as rotation vectors (`axis * angle`, from `CFrame:ToAxisAngle()`), not quaternions or CFrames, because... ([[Lua Keyframe Player Internals]])
- Quaternion to matrix: `CFrame.new(x, y, z, qX, qY, qZ, qW)` (Roblox docs (as of October 2026)). ([[Rotations Angles and Quaternions]])
- Quaternions: the conversion preserves the motion exactly. ([[Animation Editor Advanced]])
- Flag 1 (nlerp mode) records which interpolation the source clip used (quaternion nlerp for evenly spaced Linear sequences, rotation-vector blend otherwise, see Lua Keyframe Player Internals). ([[Clip Buffer Format]])

## Mentioned in

47 notes in 6 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Buffers and Binary Data]]

### 08 Animation
[[Animation Capture and Mocap]] · [[Animation Data from Blender to Roblox]] · [[Animation Editor Advanced]] · [[Animation Glossary]] · [[Authoring Clips in Code]] · [[Blender Armature and Bone Roll Conventions]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Clip Buffer Format]] · [[Engine Gotchas]] · [[How the Animator Really Behaves]] · [[Keyframes, Easing and Interpolation]] · [[Lua Keyframe Player Internals]] · [[Motor6D Math and CFrame Composition]] · [[Performance and Memory]] · [[Pipeline - New Animated Weapon]] · [[Playback, Priorities and Blending]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - Lua Keyframe Player Core]] · [[Weapon Design Rig Builder]] · [[Weapon Rig Player]] · [[Weight Painting and Skinning for Roblox]]

### 40 Game Math
[[Interpolation Easing and Curves Math]] · [[Rotations Angles and Quaternions]]

### 56 Field Notes
[[Animation Data Hygiene - Euler Wrap Joint Holes and Easing]]

Also mentioned in (not linked): 00 Start Here · Arm Baker Internals · Arm QA Metrics Reference · Arm Twist and Grip Roll - Lessons from Baked Sword Clips · Baked Clip Stubs and Archiving · Cookbook - Math CFrame and Vectors · CurveAnimation and Curve Channels · Curves in Luau - Paths Beams and Motion · Dot and Cross Products in Gameplay · Elbow Poles Swivel and Joint Limits · Enemy and NPC Animation · Equip Draw and Flourish Systems · Game Math Start Here · Importing Models and Rigs · KeyframeSequence Keyframe and Pose Reference · Lua Keyframe Player · Math Vectors and CFrames · Moon Animator and Third-Party Tools · Open Questions · R15 Run Cycle Key Poses · Snippets - Procedural Motion · Spin and Whole-Body Rotation Moves

<!-- atlas:generated -->
