---
tags: [atlas, api, type/atlas, area/ui, area/vfx, api/VideoPlayer]
---
# VideoPlayer

<!-- tldr:start -->
> [!tldr] TL;DR
> - `VideoPlayer` is "an instance for playing video assets." It has one output pin, `Output`.
> - Avoid: No `Wire` from `VideoPlayer` to a `VideoDisplay` -> Wire `SourceInstance` = player, `TargetInstance` = display.
> - Right object chosen: `VideoFrame` for flat UI, `VideoPlayer` + `VideoDisplay` for world screens with sound.
> - Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame.
>
> Cost: TL;DR ~140 tok · whole note ~310 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`VideoPlayer` is "an instance for playing video assets." It has one output pin, `Output`. (from [[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: No `Wire` from `VideoPlayer` to a `VideoDisplay` -> Wire `SourceInstance` = player, `TargetInstance` = display. ([[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]])
- Right object chosen: `VideoFrame` for flat UI, `VideoPlayer` + `VideoDisplay` for world screens with sound. ([[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]])
- Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame. ([[00 Start Here]])

## Mentioned in

5 notes in 3 sections. The 5 most relevant are linked:

### 05 UI and UX
[[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 07 Lighting VFX and Audio
[[The Audio API - Players Emitters Wires and Effects]]

### Root notes
[[00 Start Here]] · [[Open Questions - Whole Vault]]

<!-- atlas:generated -->
