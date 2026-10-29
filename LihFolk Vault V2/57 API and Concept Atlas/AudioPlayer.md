---
tags: [atlas, api, type/atlas, area/vfx, area/pipelines, api/AudioPlayer]
---
# AudioPlayer

<!-- tldr:start -->
> [!tldr] TL;DR
> - Audio API: The newer audio graph: AudioPlayer, AudioEmitter, AudioListener, Wire, effects.
> - Start all stems together with `AudioPlayer:Play(atTime)` on `SoundService:GetMixerTime()`, so they are sample-aligned (Docs).
> - Pre-create a pool of N emitter rigs (an `Attachment` on an anchored, non-colliding, non-querying helper part, with an...
> - With the newer Audio API you would pool `AudioPlayer` plus `AudioEmitter` pairs instead; the stealing logic is the same.
>
> Cost: TL;DR ~160 tok · whole note ~470 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Audio API: The newer audio graph: AudioPlayer, AudioEmitter, AudioListener, Wire, effects. (from [[Glossary]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Start all stems together with `AudioPlayer:Play(atTime)` on `SoundService:GetMixerTime()`, so they are sample-aligned (Docs). ([[Music and Adaptive Audio]])
- Pre-create a pool of N emitter rigs (an `Attachment` on an anchored, non-colliding, non-querying helper part, with an `AudioEmitter` and an `AudioPlayer` wired to it; or a `Sound` parented to the attachment). ([[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]])
- With the newer Audio API you would pool `AudioPlayer` plus `AudioEmitter` pairs instead; the stealing logic is the same. ([[Combat Sound Design and Feedback]])
- A non-positional loop (`Sound` under `SoundService` or a local `AudioPlayer` wired to the listener) with volume tied to intensity. ([[Rain - Camera-Local Particles, Splashes and Wet Surfaces]])

## Mentioned in

12 notes in 5 sections. The 12 most relevant are linked:

### 07 Lighting VFX and Audio
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Combat Sound Design and Feedback]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Music and Adaptive Audio]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Sound Design for Games]] · [[Sound Fundamentals]] · [[The Audio API - Players Emitters Wires and Effects]]

### 17 Pipelines
[[Audio Pipeline]]

### 36 Narrative and Worldbuilding
[[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]]

### 46 Resource Library
[[Links - Sounds and the Audio API]]

### Root notes
[[Glossary]]

<!-- atlas:generated -->
