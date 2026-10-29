---
tags: [atlas, api, type/atlas, area/vfx, area/ai, api/AudioEmitter]
---
# AudioEmitter

<!-- tldr:start -->
> [!tldr] TL;DR
> - Audio API: The newer audio graph: AudioPlayer, AudioEmitter, AudioListener, Wire, effects.
> - Pre-create a pool of N emitter rigs (an `Attachment` on an anchored, non-colliding, non-querying helper part, with an...
> - With the newer Audio API you would pool `AudioPlayer` plus `AudioEmitter` pairs instead; the stealing logic is the same.
>
> Cost: TL;DR ~130 tok · whole note ~330 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Audio API: The newer audio graph: AudioPlayer, AudioEmitter, AudioListener, Wire, effects. (from [[Glossary]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Pre-create a pool of N emitter rigs (an `Attachment` on an anchored, non-colliding, non-querying helper part, with an `AudioEmitter` and an `AudioPlayer` wired to it; or a `Sound` parented to the attachment). ([[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]])
- With the newer Audio API you would pool `AudioPlayer` plus `AudioEmitter` pairs instead; the stealing logic is the same. ([[Combat Sound Design and Feedback]])

## Mentioned in

9 notes in 4 sections. The 9 most relevant are linked:

### 07 Lighting VFX and Audio
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Combat Sound Design and Feedback]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Sound Fundamentals]] · [[Spatial Audio and Mixing]] · [[The Audio API - Players Emitters Wires and Effects]]

### 15 AI Tools
[[AI Audio - Voice Music and SFX]]

### 46 Resource Library
[[Links - Sounds and the Audio API]]

### Root notes
[[Glossary]]

<!-- atlas:generated -->
