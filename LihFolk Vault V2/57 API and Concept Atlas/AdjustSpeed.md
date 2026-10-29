---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/AdjustSpeed]
---
# AdjustSpeed

<!-- tldr:start -->
> [!tldr] TL;DR
> - `AnimationTrack:AdjustSpeed(speed)` sets the playback rate at once (no ramp): positive plays forward, negative backward, 0...
> - Avoid: `AdjustSpeed` every frame on a replicated character (network noise).
> - Walk at native speed with an AdjustSpeed plan; 16 studs/s = run.
> - AnimationTrack-compatible tracks. Tracks expose `Play(fade, weight, speed)`, `Stop(fade)`, `AdjustSpeed`...
>
> Cost: TL;DR ~140 tok · whole note ~590 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`AnimationTrack:AdjustSpeed(speed)` sets the playback rate at once (no ramp): positive plays forward, negative backward, 0 pauses (from [[AnimationTrack Reference]]).

API snapshot: member of `AnimationTrack` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: `AdjustSpeed` every frame on a replicated character (network noise). ([[Snippets - Animation Controller Module]])
- Walk at native speed with an AdjustSpeed plan; 16 studs/s = run. ([[Locomotion Readability - Lessons from Blind Panels]])
- AnimationTrack-compatible tracks. Tracks expose `Play(fade, weight, speed)`, `Stop(fade)`, `AdjustSpeed`... ([[Lua Keyframe Player]])
- `Play(_, _, speed)` or `AdjustSpeed(s)`: duration becomes `Length / speed`. ([[Playback, Priorities and Blending]])

## Mentioned in

32 notes in 8 sections. The 25 most relevant are linked:

### 08 Animation
[[Animation Editor Advanced]] · [[Animation Objects]] · [[Animation Review Checklist]] · [[AnimationTrack Reference]] · [[Combat Animation Craft]] · [[Custom Locomotion Controller Design]] · [[Enemy Animation State Protocol]] · [[Engine Gotchas]] · [[Hit Reactions Stagger and Hit-Stop]] · [[Locomotion Readability - Lessons from Blind Panels]] · [[Locomotion Systems]] · [[Locomotion and Melee Reference Numbers]] · [[Lua Keyframe Player]] · [[Markers and Events]] · [[Mounts and Rideable Creatures]] · [[Playback, Priorities and Blending]] · [[R15 Run Cycle Key Poses]] · [[Snippets - Animation Controller Module]] · [[Snippets - Enemy Client Animator]] · [[Snippets - Playing Animations]] · [[Timing Spacing and Frame Charts]]

### 52 Core Concepts
[[Hit-Stop]]

### 56 Field Notes
[[Held Weapons on Motor6D - Locking the Grip During Attacks]]

### 61 Thumbnails and CTR
[[Making Thumbnails in Studio and Blender - Capture, Lighting and Posing]]

### 62 Engine Reference Cards
[[Animator - Engine Reference Card]]

Also mentioned in (not linked): Official Docs - Characters and Animation · Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run · Photo Mode and In-Game Screenshots with CaptureService · Replication and Ownership · Snippets - Lua Keyframe Player Core · Troubleshooting Table · Weapon Rig Player

<!-- atlas:generated -->
