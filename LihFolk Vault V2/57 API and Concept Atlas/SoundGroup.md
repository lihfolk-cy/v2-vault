---
tags: [atlas, api, type/atlas, area/vfx, area/production, api/SoundGroup]
---
# SoundGroup

<!-- tldr:start -->
> [!tldr] TL;DR
> - `SoundGroup.Volume` accepts 0 to 10 (Roblox docs); keep your mapped maximum at the authored level (usually 1) so 100% means...
> - Music slider leaves some music audible: Track has no `SoundGroup` -> Assign groups at creation; audit script.
> - Every sound, including runtime ones, has a `SoundGroup`.
> - `SoundGroup.Volume` (default 0.5, range 0 to 10) multiplies its members' volume: a 0.5 sound in a 0.5 group plays at 0.25.
>
> Cost: TL;DR ~150 tok · whole note ~460 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`SoundGroup.Volume` accepts 0 to 10 (Roblox docs); keep your mapped maximum at the authored level (usually 1) so 100% means "as mixed". (from [[Audio Mixer Settings with SoundGroups]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Music slider leaves some music audible: Track has no `SoundGroup` -> Assign groups at creation; audit script. ([[Audio Mixer Settings with SoundGroups]])
- Every sound, including runtime ones, has a `SoundGroup`. ([[Audio Mixer Settings with SoundGroups]])
- `SoundGroup.Volume` (default 0.5, range 0 to 10) multiplies its members' volume: a 0.5 sound in a 0.5 group plays at 0.25. ([[Sound Fundamentals]])
- Buses. Weapon sounds, enemy sounds and UI sounds each go through their own `SoundGroup` so settings sliders work per category. ([[Asset Pipelines]])

## Mentioned in

14 notes in 8 sections. The 14 most relevant are linked:

### 07 Lighting VFX and Audio
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Combat Sound Design and Feedback]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Sound Fundamentals]] · [[Spatial Audio and Mixing]] · [[The Audio API - Players Emitters Wires and Effects]]

### 13 Production and Case Studies
[[Asset Pipelines]]

### 17 Pipelines
[[Audio Pipeline]]

### 42 Accessibility and Inclusive Design
[[Captions and Audio Accessibility]]

### 46 Resource Library
[[Links - Sounds and the Audio API]]

### 56 Field Notes
[[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]]

### 58 Player QoL and Game Tweaks
[[Audio Mixer Settings with SoundGroups]] · [[Top 25 QoL Wins by Effort]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
