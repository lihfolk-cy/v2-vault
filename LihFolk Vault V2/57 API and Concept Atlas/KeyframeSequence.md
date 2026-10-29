---
tags: [atlas, api, type/atlas, area/animation, area/scripting, api/KeyframeSequence]
---
# KeyframeSequence

<!-- tldr:start -->
> [!tldr] TL;DR
> - `KeyframeSequence` is the classic clip format: what the Animation Editor saves, what the 3D importer writes, what most...
> - Avoid: Uploading a KeyframeSequence -> Convert first.
> - Runtime-built clips cannot be published at runtime.
> - A clip keyed on every channel at every frame can be larger as curves than as a KeyframeSequence.
>
> Cost: TL;DR ~120 tok · whole note ~850 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`KeyframeSequence` is the classic clip format: what the Animation Editor saves, what the 3D importer writes, what most code-built clips use, and what gets uploaded when you publish. (from [[KeyframeSequence Keyframe and Pose Reference]])

A KeyframeSequence is a tree: one Keyframe per time, one Pose per joint per keyframe (plus placeholder Poses for the hierarchy), plus markers. (from [[Baked Clip Stubs and Archiving]])

API snapshot: class, inherits `AnimationClip` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Uploading a KeyframeSequence -> Convert first. ([[Bundles Animation Packs and Emotes for Sale]])
- Runtime-built clips cannot be published at runtime. A `KeyframeSequence` built in a live server cannot become an asset id. ([[Snippets - Building and Sampling Clips]])
- A clip keyed on every channel at every frame can be larger as curves than as a KeyframeSequence. ([[CurveAnimation and Curve Channels]])
- Publish the clip, or play the `KeyframeSequence` data with your own player. ([[Authoring Clips in Code]])

## Mentioned in

63 notes in 7 sections. The 25 most relevant are linked:

### 08 Animation
[[Ability Kits Architecture]] · [[Animation Data from Blender to Roblox]] · [[Animation Editor Advanced]] · [[Animation Editor Workflow]] · [[Animation Glossary]] · [[Animation Objects]] · [[Authoring Clips in Code]] · [[Baked Clip Stubs and Archiving]] · [[Clip Archive Server]] · [[CurveAnimation and Curve Channels]] · [[Custom Rigs - Weapons and Props]] · [[Debugging Animation Problems]] · [[Enemy Import Axis Fix]] · [[Engine Gotchas]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Lua Keyframe Player]] · [[Markers and Events]] · [[Moon Animator and Third-Party Tools]] · [[Publishing Animations]] · [[Retargeting Animations Between Rigs]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - Lua Keyframe Player Core]] · [[Testing Animations in Studio]] · [[Weapon Design Rig Builder]]

### 15 AI Tools
[[AI Animation and Motion from Video]]

Also mentioned in (not linked): 00 Start Here · Animation Start Here · AnimationTrack Reference · Blender Armature and Bone Roll Conventions · Buffers and Binary Data · Bundles Animation Packs and Emotes for Sale · Case Study - Abilities That Only Worked in Studio · Case Study - Cutting a Million Instances · Clip Buffer Format · Creature Rig Conventions · Custom Locomotion Controller Design · Developer Console and Stats · Equip Draw and Flourish Systems · Glossary · Ground Fitting Pipeline · How the Animator Really Behaves · Importing Models and Rigs · Inverse Kinematics · Keyframes, Easing and Interpolation · LihFolk R15 Keyframe Pipeline · Locomotion Systems · Lua Keyframe Player Internals · Open Questions · Performance and Memory · Pipeline - Arm IK Baking and QA · Pipeline - Importing Animated Enemies · Pipeline - New Animated Weapon · R15 Rig Anatomy and Attachments · R15 Run Cycle Key Poses · Rigging in Blender · Rigs and Joints · Snippets - Playing Animations · Spec-Driven Move Authoring · Studio Plugins and Local HTTP Bridges · Studio Tooling Architecture · Troubleshooting Table · Weapon Rig Player · Weight Painting and Skinning for Roblox

<!-- atlas:generated -->
