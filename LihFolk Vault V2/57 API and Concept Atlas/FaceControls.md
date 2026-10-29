---
tags: [atlas, api, type/atlas, area/animation, api/FaceControls]
---
# FaceControls

<!-- tldr:start -->
> [!tldr] TL;DR
> - Dynamic head: A skinned head driven by FACS controls through FaceControls.
> - On import Studio creates a `FaceControls` instance on the head.
> - Facial channels: a `Folder` named after an existing `FaceControls` instance holds one `FloatCurve` per animated property...
> - `FaceControls`: about 50 numeric FACS properties on dynamic heads, animated through FloatCurves or NumberPoses (see Facial...
>
> Cost: TL;DR ~140 tok · whole note ~290 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Dynamic head: A skinned head driven by FACS controls through FaceControls. (from [[Animation Glossary]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- On import Studio creates a `FaceControls` instance on the head. ([[Facial Animation and Dynamic Heads]])
- Facial channels: a `Folder` named after an existing `FaceControls` instance holds one `FloatCurve` per animated property (`JawDrop`, `LeftEyeClosed` and so on). ([[CurveAnimation and Curve Channels]])
- `FaceControls`: about 50 numeric FACS properties on dynamic heads, animated through FloatCurves or NumberPoses (see Facial Animation and Dynamic Heads). ([[Animation Objects]])

## Mentioned in

6 notes in 2 sections. The 6 most relevant are linked:

### 08 Animation
[[Animation Glossary]] · [[Animation Objects]] · [[CurveAnimation and Curve Channels]] · [[Facial Animation and Dynamic Heads]] · [[KeyframeSequence Keyframe and Pose Reference]]

### 46 Resource Library
[[Links - Animation creation]]

<!-- atlas:generated -->
