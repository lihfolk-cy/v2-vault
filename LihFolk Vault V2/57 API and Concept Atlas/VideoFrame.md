---
tags: [atlas, api, type/atlas, area/ui, area/vfx, api/VideoFrame]
---
# VideoFrame

<!-- tldr:start -->
> [!tldr] TL;DR
> - `VideoFrame` is a single GUI object that plays a video.
> - Avoid: `VideoFrame` not inside a ScreenGui, SurfaceGui or BillboardGui -> Parent it to a GUI container.
> - Right object chosen: `VideoFrame` for flat UI, `VideoPlayer` + `VideoDisplay` for world screens with sound.
> - Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame.
>
> Cost: TL;DR ~130 tok · whole note ~300 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`VideoFrame` is a single GUI object that plays a video. (from [[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]])

API snapshot: class, inherits `GuiObject` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: `VideoFrame` not inside a ScreenGui, SurfaceGui or BillboardGui -> Parent it to a GUI container. ([[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]])
- Right object chosen: `VideoFrame` for flat UI, `VideoPlayer` + `VideoDisplay` for world screens with sound. ([[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]])
- Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame. ([[00 Start Here]])

## Mentioned in

6 notes in 3 sections. The 6 most relevant are linked:

### 05 UI and UX
[[Safe Areas and Insets]] · [[Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 07 Lighting VFX and Audio
[[The Audio API - Players Emitters Wires and Effects]]

### Root notes
[[00 Start Here]] · [[Open Questions - Whole Vault]]

<!-- atlas:generated -->
