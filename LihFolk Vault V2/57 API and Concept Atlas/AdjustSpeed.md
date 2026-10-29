---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/AdjustSpeed]
---
# AdjustSpeed

<!-- tldr:start -->
> [!tldr] TL;DR
> - API snapshot: member of `AnimationTrack` (`_tools/roblox_api.json`, docs build of 2026-10-27).
> - Avoid: `AdjustSpeed` every frame on a replicated character (network noise).
> - Walk at native speed with an AdjustSpeed plan; 16 studs/s = run.
> - AnimationTrack-compatible tracks. Tracks expose `Play(fade, weight, speed)`, `Stop(fade)`, `AdjustSpeed`...
>
> Cost: TL;DR ~130 tok · whole note ~560 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`AdjustSpeed` is skipped when the change is under 0.01, which matters if you replicate rate changes yourself (below). (from [[Custom Locomotion Controller Design]])

API snapshot: member of `AnimationTrack` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: `AdjustSpeed` every frame on a replicated character (network noise). ([[Snippets - Animation Controller Module]])
- Walk at native speed with an AdjustSpeed plan; 16 studs/s = run. ([[Locomotion Readability - Lessons from Blind Panels]])
- AnimationTrack-compatible tracks. Tracks expose `Play(fade, weight, speed)`, `Stop(fade)`, `AdjustSpeed`... ([[Lua Keyframe Player]])
- `Play(_, _, speed)` or `AdjustSpeed(s)`: duration becomes `Length / speed`. ([[Playback, Priorities and Blending]])

## Mentioned in

30 notes in 6 sections. The 25 most relevant are linked:

### 08 Animation
[[Animation Editor Advanced]] · [[Animation Objects]] · [[Animation Review Checklist]] · [[AnimationTrack Reference]] · [[Combat Animation Craft]] · [[Custom Locomotion Controller Design]] · [[Enemy Animation State Protocol]] · [[Engine Gotchas]] · [[Hit Reactions Stagger and Hit-Stop]] · [[Locomotion Readability - Lessons from Blind Panels]] · [[Locomotion Systems]] · [[Locomotion and Melee Reference Numbers]] · [[Lua Keyframe Player]] · [[Markers and Events]] · [[Mounts and Rideable Creatures]] · [[Playback, Priorities and Blending]] · [[R15 Run Cycle Key Poses]] · [[Snippets - Animation Controller Module]] · [[Snippets - Enemy Client Animator]] · [[Snippets - Playing Animations]] · [[Timing Spacing and Frame Charts]]

### 09 Gameplay Systems
[[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]]

### 49 Roblox Platform Features
[[Photo Mode and In-Game Screenshots with CaptureService]]

### 52 Core Concepts
[[Hit-Stop]]

### 56 Field Notes
[[Held Weapons on Motor6D - Locking the Grip During Attacks]]

Also mentioned in (not linked): Links - Animation playback · Replication and Ownership · Snippets - Lua Keyframe Player Core · Troubleshooting Table · Weapon Rig Player

<!-- atlas:generated -->
