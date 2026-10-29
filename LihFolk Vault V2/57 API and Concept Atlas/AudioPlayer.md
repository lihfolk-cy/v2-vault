---
tags: [atlas, api, type/atlas, area/vfx, area/platform, api/AudioPlayer]
---
# AudioPlayer

<!-- tldr:start -->
> [!tldr] TL;DR
> - Audio API: The newer audio graph: AudioPlayer, AudioEmitter, AudioListener, Wire, effects.
> - Avoid: `AudioPlayer.AssetId` in new code.
> - Every `AudioPlayer` wired to an `AudioEmitter` or `AudioDeviceOutput`, and listeners placed deliberately.
> - Start all stems together with `AudioPlayer:Play(atTime)` on `SoundService:GetMixerTime()`, so they are sample-aligned (Docs).
>
> Cost: TL;DR ~130 tok · whole note ~490 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Audio API: The newer audio graph: AudioPlayer, AudioEmitter, AudioListener, Wire, effects. (from [[Glossary]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: `AudioPlayer.AssetId` in new code. ([[SoundService - Engine Reference Card]])
- Every `AudioPlayer` wired to an `AudioEmitter` or `AudioDeviceOutput`, and listeners placed deliberately. ([[SoundService - Engine Reference Card]])
- Start all stems together with `AudioPlayer:Play(atTime)` on `SoundService:GetMixerTime()`, so they are sample-aligned (Docs). ([[Music and Adaptive Audio]])
- Pre-create a pool of N emitter rigs (an `Attachment` on an anchored, non-colliding, non-querying helper part, with an `AudioEmitter` and an `AudioPlayer` wired to it; or a `Sound` parented to the attachment). ([[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]])

## Mentioned in

15 notes in 7 sections. The 15 most relevant are linked:

### 07 Lighting VFX and Audio
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Combat Sound Design and Feedback]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Music and Adaptive Audio]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Sound Design for Games]] · [[Sound Fundamentals]] · [[The Audio API - Players Emitters Wires and Effects]]

### 17 Pipelines
[[Audio Pipeline]]

### 36 Narrative and Worldbuilding
[[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]]

### 46 Resource Library
[[Official Docs - Audio]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 62 Engine Reference Cards
[[SoundService - Engine Reference Card]]

### Root notes
[[Glossary]]

<!-- atlas:generated -->
