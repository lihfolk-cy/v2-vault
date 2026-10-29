---
tags: [atlas, api, type/atlas, area/animation, area/platform, api/AnimationTrack]
---
# AnimationTrack

<!-- tldr:start -->
> [!tldr] TL;DR
> - AnimationTrack: One loaded clip on one Animator.
> - AnimationTrack-compatible tracks. Tracks expose `Play(fade, weight, speed)`, `Stop(fade)`, `AdjustSpeed`...
> - The engine warns once one Animator passes 256 loaded tracks ("AnimationTrack limit of 256 tracks for one animator exceeded...
> - The engine warns once an Animator holds 256 tracks ("AnimationTrack limit of 256 tracks for one animator exceeded"); new...
>
> Cost: TL;DR ~140 tok · whole note ~740 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

AnimationTrack: One loaded clip on one Animator. (from [[Animation Glossary]])

API snapshot: class, inherits `Instance`, not creatable with `Instance.new` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- AnimationTrack-compatible tracks. Tracks expose `Play(fade, weight, speed)`, `Stop(fade)`, `AdjustSpeed`... ([[Lua Keyframe Player]])
- The engine warns once one Animator passes 256 loaded tracks ("AnimationTrack limit of 256 tracks for one animator exceeded, new animations will not be played"). ([[Animation Objects]])
- The engine warns once an Animator holds 256 tracks ("AnimationTrack limit of 256 tracks for one animator exceeded"); new animations stop playing past it. ([[Engine Gotchas]])
- Weight vs WeightCurrent vs WeightTarget. Roblox docs (as of October 2026) list `WeightCurrent` and `WeightTarget` on `AnimationTrack` as not replicated, and `WeightTarget` as read only. ([[Animation Glossary]])

## Mentioned in

46 notes in 11 sections. The 25 most relevant are linked:

### 07 Lighting VFX and Audio
[[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]]

### 08 Animation
[[Ability Kits Architecture]] · [[Animation Editor Advanced]] · [[Animation Glossary]] · [[Animation Objects]] · [[AnimationTrack Reference]] · [[Animator Deep Dive]] · [[Authoring Clips in Code]] · [[Combat Animation Craft]] · [[Custom Locomotion Controller Design]] · [[Emotes and Social Animation]] · [[Engine Gotchas]] · [[Hit Reactions Stagger and Hit-Stop]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Locomotion Systems]] · [[Lua Keyframe Player]] · [[Markers and Events]] · [[Mounts and Rideable Creatures]] · [[Publishing Animations]] · [[Snippets - Animation Controller Module]] · [[Snippets - Enemy Client Animator]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Playing Animations]]

### 12 Performance Testing and Debugging
[[Hunting Memory Leaks Step by Step]]

### 49 Roblox Platform Features
[[Server Authority and Input Migration 2026]]

Also mentioned in (not linked): 00 Start Here · AI Pitfalls - Physics and Animation · Animation Editor Workflow · Animation Start Here · Case Study - Abilities That Only Worked in Studio · Combat Combo Systems · CurveAnimation and Curve Channels · Debugging Animation Problems · Held Weapons on Motor6D - Locking the Grip During Attacks · Hit-Stop · Idle Breathing and Secondary Motion · Keyframes, Easing and Interpolation · Links - Animation playback · Melee Combat System End to End · Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes · Open Questions · Photo Mode and In-Game Screenshots with CaptureService · Playback, Priorities and Blending · Stance and Charge Moves · Timing Spacing and Frame Charts · Weapon Rig Player

<!-- atlas:generated -->
