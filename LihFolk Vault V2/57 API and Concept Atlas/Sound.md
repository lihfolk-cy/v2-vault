---
tags: [atlas, api, type/atlas, area/vfx, area/world, api/Sound]
---
# Sound

<!-- tldr:start -->
> [!tldr] TL;DR
> - Sound is the fastest channel to the player and works off-screen.
> - Sound silent in the live game only: Experience lacks permission to the asset -> Upload under the experience owner; test live.
> - Avoid: reading `Sound.TimeLength` right after setting `SoundId`.
> - Hits feel floaty with good assets: Sound files have 30 to 80 ms lead-ins -> Measure onset and peak; schedule early or trim.
>
> Cost: TL;DR ~140 tok · whole note ~790 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Sound is the fastest channel to the player and works off-screen. (from [[Sound Design for Games]])

Sound does not freeze. Animation freezes; the impact transient and its tail run in real time. (from [[Combat Sound Design and Feedback]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Sound silent in the live game only: Experience lacks permission to the asset -> Upload under the experience owner; test live. ([[Sound Fundamentals]])
- Avoid: reading `Sound.TimeLength` right after setting `SoundId`. ([[SoundService - Engine Reference Card]])
- Hits feel floaty with good assets: Sound files have 30 to 80 ms lead-ins -> Measure onset and peak; schedule early or trim. ([[Feedback Timing - Sound Visual and Haptic Sync]])
- First hit of the session is silent or late: Sound not loaded -> Preload combat sounds; pool instances. ([[Feedback Timing - Sound Visual and Haptic Sync]])
- Hits feel late: Sound started on the beat, peak later -> Start at beat minus peak. ([[Sound Design for Games]])

## Mentioned in

31 notes in 18 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Zone and Biome Art Direction]]

### 07 Lighting VFX and Audio
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Combat Sound Design and Feedback]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Sound Design for Games]] · [[Sound Fundamentals]] · [[Spatial Audio and Mixing]] · [[The Audio API - Players Emitters Wires and Effects]]

### 08 Animation
[[VFX Timing with Animation]]

### 12 Performance Testing and Debugging
[[Memory Budgets and Leaks]]

### 17 Pipelines
[[Audio Pipeline]]

### 24 Worked Builds
[[Melee Combat System End to End]]

### 25 Physics and Vehicles
[[Engine, Gearbox and Torque Curve Model for Arcade Cars]]

### 42 Accessibility and Inclusive Design
[[Captions and Audio Accessibility]]

### 47 Game Feel and Juice
[[Feedback Timing - Sound Visual and Haptic Sync]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 56 Field Notes
[[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]] · [[ipairs Stops at the First nil - Cleanup Tables That Leak]]

### 58 Player QoL and Game Tweaks
[[Audio Mixer Settings with SoundGroups]]

### 60 High-Craft Game Teardowns
[[Teardown - Funky Friday]]

### 62 Engine Reference Cards
[[SoundService - Engine Reference Card]]

Also mentioned in (not linked): Horror Monster Chase AI End to End · Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes · Open Questions - Whole Vault · Scale and Animation · Terrain Deep Dive - Materials Water and Performance · Zone Detection - Area Enter and Exit for Music, Lighting and Ambience

<!-- atlas:generated -->
