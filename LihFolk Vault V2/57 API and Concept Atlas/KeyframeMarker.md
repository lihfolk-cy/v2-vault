---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/KeyframeMarker]
---
# KeyframeMarker

<!-- tldr:start -->
> [!tldr] TL;DR
> - KeyframeMarker: A named event inside a clip, fired by `GetMarkerReachedSignal`.
> - A marker is a `KeyframeMarker` (Name = event name, `Value` = a parameter string) added with `Keyframe:AddMarker(m)` (Roblox docs).
> - Create `KeyframeMarker`s from the exported marker JSON.
> - Markers. `marker(frame, name, value)` becomes real `KeyframeMarker`s (`Hit`, `ComboWindow`, `TrailOn`, `TrailOff`, `Footstep`).
>
> Cost: TL;DR ~140 tok · whole note ~470 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

KeyframeMarker: A named event inside a clip, fired by `GetMarkerReachedSignal`. (from [[Animation Glossary]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- A marker is a `KeyframeMarker` (Name = event name, `Value` = a parameter string) added with `Keyframe:AddMarker(m)` (Roblox docs). ([[Authoring Clips in Code]])
- Create `KeyframeMarker`s from the exported marker JSON. ([[Importing Models and Rigs]])
- Markers. `marker(frame, name, value)` becomes real `KeyframeMarker`s (`Hit`, `ComboWindow`, `TrailOn`, `TrailOff`, `Footstep`). ([[LihFolk R15 Keyframe Pipeline]])
- Instances (load time and memory): every `Keyframe`, `Pose` and `KeyframeMarker` is an Instance. ([[Performance and Memory]])

## Mentioned in

24 notes in 2 sections. The 24 most relevant are linked:

### 08 Animation
[[3D Importer Settings Reference]] · [[Animation Data from Blender to Roblox]] · [[Animation Editor Advanced]] · [[Animation Glossary]] · [[Animation Objects]] · [[AnimationTrack Reference]] · [[Authoring Clips in Code]] · [[Combat Animation Craft]] · [[CurveAnimation and Curve Channels]] · [[Custom Rigs - Weapons and Props]] · [[Engine Gotchas]] · [[Importing Models and Rigs]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[LihFolk R15 Keyframe Pipeline]] · [[Markers and Events]] · [[Performance and Memory]] · [[Pipeline - Importing Animated Enemies]] · [[Pipeline - New Animated Weapon]] · [[Replication and Ownership]] · [[Rigging in Blender]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - Lua Keyframe Player Core]] · [[Spec-Driven Move Authoring]]

### 09 Gameplay Systems
[[Hitboxes and Hit Detection]]

<!-- atlas:generated -->
