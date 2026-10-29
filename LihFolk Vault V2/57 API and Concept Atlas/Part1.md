---
tags: [atlas, api, type/atlas, area/animation, area/ai, api/Part1]
---
# Part1

<!-- tldr:start -->
> [!tldr] TL;DR
> - C0 / C1: A Motor6D's rest offsets in Part0 and Part1 space.
> - Avoid: Pose named after the joint (`RightShoulder`) -> Name after Part1 (`RightUpperArm`) (Rigs and Joints)
> - Every Pose name matches a Part1 (or Bone) name on the target rig.
> - Avoid: Clips on a weapon with no Motor6Ds -> Build hinges; check every keyed Part1 has a joint.
>
> Cost: TL;DR ~130 tok · whole note ~670 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

C0 / C1: A Motor6D's rest offsets in Part0 and Part1 space. (from [[Animation Glossary]])

API snapshot: member of `AnimationConstraint`, `JointInstance`, `NoCollisionConstraint`, `WeldConstraint` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Pose named after the joint (`RightShoulder`) -> Name after Part1 (`RightUpperArm`) ([[Rigs and Joints]])
- Every Pose name matches a Part1 (or Bone) name on the target rig. ([[KeyframeSequence Keyframe and Pose Reference]])
- Avoid: Clips on a weapon with no Motor6Ds -> Build hinges; check every keyed Part1 has a joint. ([[Custom Rigs - Weapons and Props]])
- Joints are matched by name. A Pose (or curve folder) binds to the joint whose `Part1` has that name (for Bones, the bone's name). ([[Animator Deep Dive]])
- Keys bind by name to joints (Part1 name, or Bone name). ([[How the Animator Really Behaves]])

## Mentioned in

45 notes in 4 sections. The 25 most relevant are linked:

### 08 Animation
[[Accessories and Armor That Follow Animation]] · [[Animation Editor Workflow]] · [[Animation Glossary]] · [[Animation Objects]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Animator Deep Dive]] · [[Authoring Clips in Code]] · [[Bones and Skinned Meshes]] · [[Custom Rigs - Weapons and Props]] · [[Debugging Animation Problems]] · [[Engine Gotchas]] · [[Inverse Kinematics]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Motor6D Math and CFrame Composition]] · [[Procedural Animation]] · [[R15 Rig Anatomy and Attachments]] · [[Ragdolls and Physics-Based Animation]] · [[Rigs and Joints]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - Ragdoll]] · [[Testing Animations in Studio]] · [[Weapon Design Rig Builder]] · [[Weapon Rig Player]]

### 15 AI Tools
[[AI Pitfalls - Physics and Animation]]

### 56 Field Notes
[[Held Weapons on Motor6D - Locking the Grip During Attacks]]

Also mentioned in (not linked): Animation Data from Blender to Roblox · Blender Armature and Bone Roll Conventions · Clip Buffer Format · CurveAnimation and Curve Channels · Explorer Properties and Selection · How the Animator Really Behaves · IKControl Reference · Importing Models and Rigs · Lua Keyframe Player · Lua Keyframe Player Internals · Multi-Bone IK - FABRIK and CCD · Retargeting Animations Between Rigs · Rigging in Blender · Snippets - IK · Snippets - Lua Keyframe Player Core · Snippets - Procedural Motion · Troubleshooting Table · Two-Bone IK Math · Weapon Swing Design · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
