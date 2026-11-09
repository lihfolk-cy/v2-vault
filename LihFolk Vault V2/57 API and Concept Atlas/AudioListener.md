---
tags: [atlas, api, type/atlas, area/vfx, area/ui, api/AudioListener]
---
# AudioListener

<!-- tldr:start -->
> [!tldr] TL;DR
> - `AudioListener` is the bridge from 3D back to a stream: it picks up emitters in the world and produces a stream you wire to an...
> - Avoid: Soundtrack wired to an emitter with no listener -> Set up an `AudioListener` (Audio API) (Video in Experiences...
> - The Audio API ignores `SoundService:SetListener`; place an `AudioListener` (for example on the camera) instead.
>
> Cost: TL;DR ~130 tok · whole note ~330 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`AudioListener` is the bridge from 3D back to a stream: it picks up emitters in the world and produces a stream you wire to an output. (from [[The Audio API - Players Emitters Wires and Effects]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Soundtrack wired to an emitter with no listener -> Set up an `AudioListener` (Audio API) ([[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]])
- The Audio API ignores `SoundService:SetListener`; place an `AudioListener` (for example on the camera) instead. ([[SoundService - Engine Reference Card]])

## Mentioned in

8 notes in 7 sections. The 8 most relevant are linked:

### 05 UI and UX
[[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]]

### 07 Lighting VFX and Audio
[[Sound Fundamentals]] · [[The Audio API - Players Emitters Wires and Effects]]

### 15 AI Tools
[[AI Audio - Voice Music and SFX]]

### 46 Resource Library
[[Official Docs - Audio]]

### 51 2D Game Development
[[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 62 Engine Reference Cards
[[SoundService - Engine Reference Card]]

### Root notes
[[Glossary]]

<!-- atlas:generated -->
