---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/AnimationConstraint]
---
# AnimationConstraint

<!-- tldr:start -->
> [!tldr] TL;DR
> - `AnimationConstraint` is the joint that replaces `Motor6D` on R15 player characters under the Avatar Joint Upgrade (AJU).
> - Every joint lookup accepts AnimationConstraint and Motor6D.
> - Avoid: `IsA("Motor6D")` only -> Accept AnimationConstraint.
> - Avoid: Code looks for Motor6D only -> Accept AnimationConstraint too.
>
> Cost: TL;DR ~120 tok · whole note ~720 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`AnimationConstraint` is the joint that replaces `Motor6D` on R15 player characters under the Avatar Joint Upgrade (AJU). (from [[AnimationConstraint and Physically Simulated Characters]])

AnimationConstraint: The joint type for R15 characters under the Avatar Joint Upgrade; animated through its `Transform` like a Motor6D. (from [[Animation Glossary]])

API snapshot: class, inherits `Constraint` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Every joint lookup accepts AnimationConstraint and Motor6D. ([[AnimationConstraint and Physically Simulated Characters]])
- Avoid: `IsA("Motor6D")` only -> Accept AnimationConstraint. ([[Rigs and Joints]])
- Avoid: Code looks for Motor6D only -> Accept AnimationConstraint too. ([[R15 Rig Anatomy and Attachments]])
- Works on an R6/old rig, does nothing on new avatars: code searches for `Motor6D` -> accept `AnimationConstraint` too. ([[Procedural Animation]])
- Joint lookup accepts `Motor6D`, `AnimationConstraint` and `Bone`. ([[Procedural Animation]])

## Mentioned in

48 notes in 5 sections. The 25 most relevant are linked:

### 08 Animation
[[Animation Editor Workflow]] · [[Animation Glossary]] · [[Animation Objects]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Animator Deep Dive]] · [[Debugging Animation Problems]] · [[Engine Gotchas]] · [[Idle Breathing and Secondary Motion]] · [[Look-At Aim and Head Tracking]] · [[Motor6D Math and CFrame Composition]] · [[Open Questions]] · [[Procedural Animation]] · [[R15 Rig Anatomy and Attachments]] · [[Ragdolls and Physics-Based Animation]] · [[Rigs and Joints]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - IK]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Procedural Motion]] · [[Snippets - Ragdoll]] · [[Studio Tooling Architecture]] · [[Testing Animations in Studio]] · [[Two-Bone IK Math]]

### 09 Gameplay Systems
[[Characters and Humanoids]]

### 17 Pipelines
[[Character and Creature Pipeline]]

Also mentioned in (not linked): 00 Start Here · Accessories and Armor That Follow Animation · Animation Data from Blender to Roblox · Animation Editor Advanced · Animation LOD · Animation Start Here · Bones and Skinned Meshes · Custom Characters and StarterCharacter · Foot Placement and Ground IK · How the Animator Really Behaves · IKControl Reference · Inverse Kinematics · Lua Keyframe Player · Moon Animator and Third-Party Tools · Multi-Bone IK - FABRIK and CCD · Organic and Creature Modeling · Physics Assemblies and Constraints · Pipeline - Arm IK Baking and QA · Procedural Gait and Footstep Planning · Replication and Ownership · Rigging in Blender · Springs Damping and Smoothing · Troubleshooting Table

<!-- atlas:generated -->
