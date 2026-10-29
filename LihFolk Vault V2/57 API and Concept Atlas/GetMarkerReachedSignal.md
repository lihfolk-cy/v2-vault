---
tags: [atlas, api, type/atlas, area/animation, area/vfx, api/GetMarkerReachedSignal]
---
# GetMarkerReachedSignal

<!-- tldr:start -->
> [!tldr] TL;DR
> - KeyframeMarker: A named event inside a clip, fired by `GetMarkerReachedSignal`.
> - `AnimationTrack.KeyframeReached` -> `AnimationTrack:GetMarkerReachedSignal(name)`.
> - Connecting `GetMarkerReachedSignal` on every play without disconnecting.
> - Load it on `Humanoid.Animator`, set priority from the JSON, and connect markers with `track:GetMarkerReachedSignal("Hit")` for...
>
> Cost: TL;DR ~130 tok · whole note ~520 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

KeyframeMarker: A named event inside a clip, fired by `GetMarkerReachedSignal`. (from [[Animation Glossary]])

API snapshot: member of `AnimationTrack` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `AnimationTrack.KeyframeReached` -> `AnimationTrack:GetMarkerReachedSignal(name)`. ([[Animator - Engine Reference Card]])
- Connecting `GetMarkerReachedSignal` on every play without disconnecting. ([[Snippets - Playing Animations]])
- Load it on `Humanoid.Animator`, set priority from the JSON, and connect markers with `track:GetMarkerReachedSignal("Hit")` for hitboxes and VFX. ([[LihFolk R15 Keyframe Pipeline]])
- Perfect-timing bonus: read the animation marker for the window with `AnimationTrack:GetMarkerReachedSignal`, validate on the server. ([[Teardown - Jujutsu Shenanigans]])

## Mentioned in

27 notes in 4 sections. The 25 most relevant are linked:

### 07 Lighting VFX and Audio
[[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]]

### 08 Animation
[[Animation Editor Advanced]] · [[Animation Glossary]] · [[Animation Objects]] · [[AnimationTrack Reference]] · [[Authoring Clips in Code]] · [[Combat Animation Craft]] · [[Combat Combo Systems]] · [[CurveAnimation and Curve Channels]] · [[Enemy Animation State Protocol]] · [[Engine Gotchas]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[LihFolk R15 Keyframe Pipeline]] · [[Lua Keyframe Player]] · [[Lua Keyframe Player Internals]] · [[Markers and Events]] · [[Open Questions]] · [[Performance and Memory]] · [[Snippets - Enemy Client Animator]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Playing Animations]] · [[Stance and Charge Moves]] · [[Weapon Rig Player]]

### 60 High-Craft Game Teardowns
[[Teardown - Jujutsu Shenanigans]]

### 62 Engine Reference Cards
[[Animator - Engine Reference Card]]

Also mentioned in (not linked): Troubleshooting Table · VFX Timing with Animation

<!-- atlas:generated -->
