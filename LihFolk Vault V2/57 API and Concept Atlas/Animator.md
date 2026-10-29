---
tags: [atlas, api, type/atlas, area/animation, area/ai, api/Animator]
---
# Animator

<!-- tldr:start -->
> [!tldr] TL;DR
> - Animator: Plays tracks on a rig, mixes them and writes joint transforms.
> - Avoid: `Humanoid:LoadAnimation` in new code -> `humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(anim)` (Animation...
> - Avoid: Creating an Animator on the client for a character -> Use the server-created Animator.
> - It is not free. You take on correctness (every Animator behaviour you rely on must be re-implemented and tested), CPU cost...
>
> Cost: TL;DR ~150 tok · whole note ~1.5k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Animator: Plays tracks on a rig, mixes them and writes joint transforms. (from [[Animation Glossary]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: `Humanoid:LoadAnimation` in new code -> `humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(anim)` ([[Animation Objects]])
- Avoid: Creating an Animator on the client for a character -> Use the server-created Animator. ([[Animation Objects]])
- It is not free. You take on correctness (every Animator behaviour you rely on must be re-implemented and tested), CPU cost... ([[Lua Keyframe Player]])
- Measured in Edit against `Animator:StepAnimations` (details and numbers in How the Animator Really Behaves and Lua Keyframe... ([[Lua Keyframe Player]])
- Lua models A/B'd against the Animator on originals, not stubs. ([[Testing Animations in Studio]])

## Mentioned in

146 notes in 23 sections. The 25 most relevant are linked:

### 08 Animation
[[Animation Glossary]] · [[Animation Objects]] · [[AnimationTrack Reference]] · [[Animator Deep Dive]] · [[Authoring Clips in Code]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Debugging Animation Problems]] · [[Engine Gotchas]] · [[Frame Order and RunService Timing]] · [[How the Animator Really Behaves]] · [[Idle Breathing and Secondary Motion]] · [[Lua Keyframe Player]] · [[Moon Animator and Third-Party Tools]] · [[Open Questions]] · [[Pipeline - Arm IK Baking and QA]] · [[Procedural Animation]] · [[Replication and Ownership]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - Enemy Client Animator]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Playing Animations]] · [[Studio Tooling Architecture]] · [[Testing Animations in Studio]] · [[Weapon Rig Player]]

### 15 AI Tools
[[AI Pitfalls - Physics and Animation]]

Also mentioned in (not linked): 00 Start Here · 3D Importer Settings Reference · AI Animation and Motion from Video · AI Code Assistants for Luau · AI Pitfalls - Stale APIs and Luau · AI in Roblox Development Overview · Ability Kits Architecture · Accessories and Armor That Follow Animation · Animating Creatures and Monsters · Animation Asset Permissions and Groups · Animation Data from Blender to Roblox · Animation Editor Advanced · Animation Editor Workflow · Animation LOD · Animation Quality Standard · Animation Review Checklist · Animation Start Here · AnimationConstraint and Physically Simulated Characters · Arm Baker Internals · Arm QA Metrics Reference · Baked Clip Stubs and Archiving · Blender Armature and Bone Roll Conventions · Bones and Skinned Meshes · Boss Animation and Phases · Case Study - Abilities That Only Worked in Studio · Character Select and Class Systems with Different Rigs · Character and Creature Pipeline · Characters and Humanoids · Client Prediction and Reconciliation for Combat · Client-Server Model · Clip Buffer Format · Combat Animation Craft · Combat Combo Systems · Cookbook - Players and Characters · Creature Rig Conventions · CurveAnimation and Curve Channels · Custom Character Sounds - Replacing Default Footstep and Jump Sounds · Custom Characters and StarterCharacter · Custom Locomotion Controller Design · Custom Rigs - Weapons and Props · Documentation and Onboarding New Developers · Emotes and Social Animation · Enemy Animation State Protocol · Enemy Import Axis Fix · Enemy and NPC Animation · Entity Component Systems · Equip Draw and Flourish Systems · Facial Animation and Dynamic Heads · First-Person Viewmodels - Arms Rig, Sway and Camera Binding · Foot Placement and Ground IK · Free Mocap and Mixamo Licensing for Roblox · Game Math Start Here · Genre Playbook - Tower Defense · Glossary · Ground Fitting Pipeline · Held Weapons on Motor6D - Locking the Grip During Attacks · Horror Monster Chase AI End to End · How Exploits Work - The Client Boundary · Hunting Memory Leaks Step by Step · IKControl Reference · Importing Models and Rigs · Interpolation Easing and Curves Math · Inverse Kinematics · KeyframeSequence Keyframe and Pose Reference · Keyframes, Easing and Interpolation · Links - Animation creation · Links - Animation playback · Locomotion Systems · Lua Keyframe Player Internals · Markers and Events · Melee Combat System End to End · Memory Budgets and Leaks · Motor6D Math and CFrame Composition · Mounts and Rideable Creatures · Open Questions - Whole Vault · Organic and Creature Modeling · Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run · Performance and Memory · Physics Assemblies and Constraints · Physics Performance · Pipeline - Importing Animated Enemies · Pipeline - New Animated Weapon · Playback, Priorities and Blending · Plugins - Using and Writing · Posing and Silhouettes · Principles of Animation for Games · Procedural Death Knockdown and Hit Reactions · Procedural Weapon Motion · Prompting and Verifying AI Output · Publishing Animations · R15 Rig Anatomy and Attachments · Ragdolls and Physics-Based Animation · Replication Boundary · Replication Rules · Retargeting Animations Between Rigs · Rigging in Blender · Rigs and Joints · Rotations Angles and Quaternions · Scale and Animation · Script Performance · Server Authority and Input Migration 2026 · Skeleton Library · Snippets - Animation Controller Module · Snippets - IK · Snippets - Procedural Motion · Snippets - Ragdoll · Spec-Driven Move Authoring · Stance and Charge Moves · Studio Plugins and Local HTTP Bridges · Testing Modes - Play Run and Multi-Client · Testing Strategies and Frameworks · The Default Animate Script · Timing Spacing and Frame Charts · Troubleshooting Table · VFX Timing with Animation · Weapon Design Rig Builder · Weapon Swing Design · Weapon and Combat Animation · Weight Painting and Skinning for Roblox · What AI Models Get Wrong in Roblox · Wildlife and Ambient Creature AI - Passive, Neutral and Hostile

<!-- atlas:generated -->
