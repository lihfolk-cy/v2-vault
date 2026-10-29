---
tags: [atlas, api, type/atlas, area/vfx, area/production, api/SoundGroup]
---
# SoundGroup

<!-- tldr:start -->
> [!tldr] TL;DR
> - `SoundGroup.Volume` accepts 0 to 10 (Roblox docs); keep your mapped maximum at the authored level (usually 1) so 100% means...
> - Music slider leaves some music audible: Track has no `SoundGroup` -> Assign groups at creation; audit script.
> - Every sound, including runtime ones, has a `SoundGroup`.
> - Avoid: Warning sounds on the music bus -> put warnings on their own SoundGroup that the music slider cannot mute.
>
> Cost: TL;DR ~150 tok · whole note ~450 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`SoundGroup.Volume` accepts 0 to 10 (Roblox docs); keep your mapped maximum at the authored level (usually 1) so 100% means "as mixed". (from [[Audio Mixer Settings with SoundGroups]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Music slider leaves some music audible: Track has no `SoundGroup` -> Assign groups at creation; audit script. ([[Audio Mixer Settings with SoundGroups]])
- Every sound, including runtime ones, has a `SoundGroup`. ([[Audio Mixer Settings with SoundGroups]])
- Avoid: Warning sounds on the music bus -> put warnings on their own SoundGroup that the music slider cannot mute. ([[Teardown - Pressure]])

## Mentioned in

16 notes in 10 sections. The 16 most relevant are linked:

### 07 Lighting VFX and Audio
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Combat Sound Design and Feedback]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Sound Fundamentals]] · [[Spatial Audio and Mixing]] · [[The Audio API - Players Emitters Wires and Effects]]

### 13 Production and Case Studies
[[Asset Pipelines]]

### 17 Pipelines
[[Audio Pipeline]]

### 42 Accessibility and Inclusive Design
[[Captions and Audio Accessibility]]

### 46 Resource Library
[[Official Docs - Audio]]

### 56 Field Notes
[[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]]

### 58 Player QoL and Game Tweaks
[[Audio Mixer Settings with SoundGroups]] · [[Top 25 QoL Wins by Effort]]

### 60 High-Craft Game Teardowns
[[Teardown - Pressure]]

### 62 Engine Reference Cards
[[SoundService - Engine Reference Card]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
