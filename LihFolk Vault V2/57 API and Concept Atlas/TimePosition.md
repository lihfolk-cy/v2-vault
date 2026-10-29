---
tags: [atlas, api, type/atlas, area/animation, area/vfx, api/TimePosition]
---
# TimePosition

<!-- tldr:start -->
> [!tldr] TL;DR
> - `TimePosition` is clamped to `Length - 0.05` so a late join never lands exactly on the end (which would end the clip...
> - Avoid: Setting `TimePosition` before `Play` -> Play first.
> - Late joiners see attacks restart: No offset -> `TimePosition = offset * speed` (Enemy Animation State Protocol)
> - Track state: `TimePosition`, `Speed`, `Length`, `Looped`, `Priority` (and a numeric rank), `IsPlaying`, `WeightCurrent`...
>
> Cost: TL;DR ~150 tok · whole note ~480 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`TimePosition` is clamped to `Length - 0.05` so a late join never lands exactly on the end (which would end the clip immediately and fade it out). (from [[Enemy Animation State Protocol]])

API snapshot: member of `AnimationPlayer`, `AnimationTrack`, `AudioPlayer`, `AudioTextToSpeech` and 3 more (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Setting `TimePosition` before `Play` -> Play first. ([[AnimationTrack Reference]])
- Late joiners see attacks restart: No offset -> `TimePosition = offset * speed` ([[Enemy Animation State Protocol]])
- Track state: `TimePosition`, `Speed`, `Length`, `Looped`, `Priority` (and a numeric rank), `IsPlaying`, `WeightCurrent`... ([[Lua Keyframe Player Internals]])

## Mentioned in

25 notes in 3 sections. The 25 most relevant are linked:

### 07 Lighting VFX and Audio
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Music and Adaptive Audio]] · [[Sound Fundamentals]] · [[The Audio API - Players Emitters Wires and Effects]]

### 08 Animation
[[Animation Objects]] · [[AnimationTrack Reference]] · [[Combat Combo Systems]] · [[Custom Locomotion Controller Design]] · [[Debugging Animation Problems]] · [[Emotes and Social Animation]] · [[Enemy Animation State Protocol]] · [[Engine Gotchas]] · [[Frame Order and RunService Timing]] · [[Locomotion Systems]] · [[Lua Keyframe Player]] · [[Lua Keyframe Player Internals]] · [[Markers and Events]] · [[Mounts and Rideable Creatures]] · [[Procedural Gait and Footstep Planning]] · [[Replication and Ownership]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Playing Animations]] · [[Troubleshooting Table]] · [[Weapon Rig Player]]

### 15 AI Tools
[[AI Audio - Voice Music and SFX]]

<!-- atlas:generated -->
