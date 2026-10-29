---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/Motor6D]
---
# Motor6D

<!-- tldr:start -->
> [!tldr] TL;DR
> - Motor6D: A joint between two parts: `Part1 = Part0 * C0 * Transform * C1:Inverse()`.
> - Avoid: `IsA("Motor6D")` only -> Accept AnimationConstraint.
> - Every moving piece has a Motor6D named after it; static pieces welded.
> - Every joint lookup accepts AnimationConstraint and Motor6D.
>
> Cost: TL;DR ~110 tok · whole note ~1.1k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Motor6D: A joint between two parts: `Part1 = Part0 * C0 * Transform * C1:Inverse()`. (from [[Animation Glossary]])

API snapshot: class, inherits `Motor` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: `IsA("Motor6D")` only -> Accept AnimationConstraint. ([[Rigs and Joints]])
- Every moving piece has a Motor6D named after it; static pieces welded. ([[Custom Rigs - Weapons and Props]])
- Every joint lookup accepts AnimationConstraint and Motor6D. ([[AnimationConstraint and Physically Simulated Characters]])
- Avoid: Code looks for Motor6D only -> Accept AnimationConstraint too. ([[R15 Rig Anatomy and Attachments]])
- One Motor6D per hinge with C0 and C1 describing the same world frame. ([[Weapon Design Rig Builder]])

## Mentioned in

98 notes in 18 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Math Vectors and CFrames]]

### 08 Animation
[[3D Importer Settings Reference]] · [[Animation Editor Workflow]] · [[Animation Glossary]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Bones and Skinned Meshes]] · [[Custom Rigs - Weapons and Props]] · [[Debugging Animation Problems]] · [[Engine Gotchas]] · [[IKControl Reference]] · [[Idle Breathing and Secondary Motion]] · [[Motor6D Math and CFrame Composition]] · [[Pipeline - New Animated Weapon]] · [[Procedural Animation]] · [[R15 Rig Anatomy and Attachments]] · [[Rigging in Blender]] · [[Rigs and Joints]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - Procedural Motion]] · [[Snippets - Ragdoll]] · [[Weapon Design Rig Builder]] · [[Weapon and Combat Animation]]

### 15 AI Tools
[[AI Pitfalls - Physics and Animation]]

### 53 Voxel Modelling Deep Dive
[[Voxel Characters - Proportions Joints and Rigging]]

### 56 Field Notes
[[Held Weapons on Motor6D - Locking the Grip During Attacks]]

Also mentioned in (not linked): 00 Start Here · AI Code Assistants for Luau · Accessories and Armor That Follow Animation · Animation Data Hygiene - Euler Wrap Joint Holes and Easing · Animation Data from Blender to Roblox · Animation Editor Advanced · Animation Objects · Animation Start Here · Animator - Engine Reference Card · Animator Deep Dive · Arm Baker Internals · Arm Twist and Grip Roll - Lessons from Baked Sword Clips · Authoring Clips in Code · Blender Armature and Bone Roll Conventions · Boss Animation and Phases · Case Study - Abilities That Only Worked in Studio · Character and Creature Pipeline · Characters and Humanoids · Cookbook - Math CFrame and Vectors · Creature Rig Conventions · CurveAnimation and Curve Channels · Custom Characters and StarterCharacter · Custom Locomotion Controller Design · Emotes and Social Animation · Enemy Import Axis Fix · Enemy and NPC Animation · Facial Animation and Dynamic Heads · Field Notes Start Here · First-Person Viewmodels - Arms Rig, Sway and Camera Binding · Foot Placement and Ground IK · Frame Order and RunService Timing · Game Math Start Here · Human Swing Biomechanics · Importing Models and Rigs · LihFolk R15 Keyframe Pipeline · Look-At Aim and Head Tracking · Lua Keyframe Player · Modeling Characters for R15 and Custom Rigs · Modeling Weapons and Props · Moon Animator and Third-Party Tools · Mounts and Rideable Creatures · Multi-Bone IK - FABRIK and CCD · Multi-Seat Vehicles - Driver, Passenger and Gunner Roles · Official Docs - Characters and Animation · Open Questions · Organic and Creature Modeling · Physics Assemblies and Constraints · Physics Performance · Pipeline - Importing Animated Enemies · Procedural Gait and Footstep Planning · Procedural Weapon Motion · R15 Run Cycle Key Poses · Ragdolls and Physics-Based Animation · Replication and Ownership · Retargeting Animations Between Rigs · Rotations Angles and Quaternions · Skeleton Library · Snippets - IK · Snippets - Lua Keyframe Player Core · Spin and Whole-Body Rotation Moves · Springs That Survive Long Frames - dt Clamps and NaN Guards · Squash Stretch and Anticipation in UI and Characters · Studio Tooling Architecture · Testing Animations in Studio · Testing Modes - Play Run and Multi-Client · Tools and Inventory Systems · Troubleshooting Table · Tween and CFrame Animation of Objects · Two-Bone IK Math · Voxel Chibi Heroes - Class Roster and Rarity Ladder · Weapon Rig Player · Weapon Swing Design · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
