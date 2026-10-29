---
tags: [atlas, concept, type/atlas, area/vfx, area/community]
---
# Audio API

<!-- tldr:start -->
> [!tldr] TL;DR
> - Audio API: The newer audio graph: AudioPlayer, AudioEmitter, AudioListener, Wire, effects.
> - With voice chat on the audio API (`VoiceChatService.UseAudioApi`), voices are just more streams: wire them through emitters on...
> - Audio API: route each category's wires through its own fader on a bus, and set that fader's volume from the setting.
> - With the newer Audio API you would pool `AudioPlayer` plus `AudioEmitter` pairs instead; the stealing logic is the same.
>
> Cost: TL;DR ~160 tok · whole note ~630 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Audio API: The newer audio graph: AudioPlayer, AudioEmitter, AudioListener, Wire, effects. (from [[Glossary]])

## Key facts

- With voice chat on the audio API (`VoiceChatService.UseAudioApi`), voices are just more streams: wire them through emitters on the character, add effects (radio EQ, cave reverb), or analyse them. ([[The Audio API - Players Emitters Wires and Effects]])
- Audio API: route each category's wires through its own fader on a bus, and set that fader's volume from the setting. ([[Captions and Audio Accessibility]])
- With the newer Audio API you would pool `AudioPlayer` plus `AudioEmitter` pairs instead; the stealing logic is the same. ([[Combat Sound Design and Feedback]])
- New work considers the audio API (see the next note). ([[Sound Fundamentals]])

## Mentioned in

26 notes in 13 sections. The 25 most relevant are linked:

### 07 Lighting VFX and Audio
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Combat Sound Design and Feedback]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Music and Adaptive Audio]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Sound Design for Games]] · [[Sound Fundamentals]] · [[Spatial Audio and Mixing]] · [[The Audio API - Players Emitters Wires and Effects]]

### 09 Gameplay Systems
[[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]

### 11 Monetization Publishing and Live Ops
[[Age Checks and Safety Features]]

### 15 AI Tools
[[AI Audio - Voice Music and SFX]]

### 17 Pipelines
[[Audio Pipeline]]

### 26 Community and Moderation
[[Voice Chat and Safety Features]]

### 42 Accessibility and Inclusive Design
[[Captions and Audio Accessibility]]

### 46 Resource Library
[[Official Docs - Audio]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]]

### 51 2D Game Development
[[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 58 Player QoL and Game Tweaks
[[Audio Mixer Settings with SoundGroups]]

### 62 Engine Reference Cards
[[SoundService - Engine Reference Card]]

### Root notes
[[00 Start Here]] · [[Glossary]] · [[Open Questions - Whole Vault]]

Also mentioned in (not linked): Community and Moderation Start Here

<!-- atlas:generated -->
