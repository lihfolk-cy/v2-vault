---
tags: [atlas, api, type/atlas, area/animation, area/ai, api/AnimationPriority]
---
# AnimationPriority

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Enum.AnimationPriority` has Core, Idle, Movement, Action, Action2, Action3 and Action4.
> - Wrong: everything at `Action`; leaving the uploaded clip's priority at `Core`; sorting priorities by...
> - Load a looped riding pose on the rider's Animator with `Priority = Enum.AnimationPriority.Action` (or Action2 to Action4 if...
>
> Cost: TL;DR ~120 tok · whole note ~490 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Enum.AnimationPriority` has Core, Idle, Movement, Action, Action2, Action3 and Action4. (from [[Engine Gotchas]])

API snapshot: enum `Enum.AnimationPriority` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Wrong: everything at `Action`; leaving the uploaded clip's priority at `Core`; sorting priorities by `Enum.AnimationPriority.X.Value`; expecting two tracks at weight 1 to each show fully. ([[AI Pitfalls - Physics and Animation]])
- Load a looped riding pose on the rider's Animator with `Priority = Enum.AnimationPriority.Action` (or Action2 to Action4 if your combat uses Action), played from the rider's client so it replicates. ([[Mounts and Rideable Creatures]])

## Mentioned in

28 notes in 2 sections. The 25 most relevant are linked:

### 08 Animation
[[Ability Kits Architecture]] · [[Animation Data from Blender to Roblox]] · [[Animation Objects]] · [[AnimationTrack Reference]] · [[Animator Deep Dive]] · [[Authoring Clips in Code]] · [[Clip Buffer Format]] · [[Combat Animation Craft]] · [[Combat Combo Systems]] · [[Custom Locomotion Controller Design]] · [[Emotes and Social Animation]] · [[Engine Gotchas]] · [[Idle Breathing and Secondary Motion]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Mounts and Rideable Creatures]] · [[Playback, Priorities and Blending]] · [[Snippets - Animation Controller Module]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - Camera Shake and FX]] · [[Snippets - Enemy Client Animator]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Playing Animations]] · [[Stance and Charge Moves]] · [[Weapon Design Rig Builder]]

### 15 AI Tools
[[AI Pitfalls - Physics and Animation]]

Also mentioned in (not linked): Studio Tooling Architecture · Testing Animations in Studio · Weapon Rig Player

<!-- atlas:generated -->
