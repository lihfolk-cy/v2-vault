---
tags: [atlas, api, type/atlas, area/animation, area/modeling, api/CurveAnimation]
---
# CurveAnimation

<!-- tldr:start -->
> [!tldr] TL;DR
> - `CurveAnimation` is Roblox's second clip format.
> - Emote: under 10 s, root near origin, no frame pops, CurveAnimation, standard R15.
> - CurveAnimation playback against `RotationCurve` / `FloatCurve` sampling.
> - Publishing is the same; tooling is not. Once published, a CurveAnimation plays like any other animation asset through the...
>
> Cost: TL;DR ~130 tok · whole note ~480 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`CurveAnimation` is Roblox's second clip format. (from [[CurveAnimation and Curve Channels]])

CurveAnimation: The curve-based clip format (per-channel curves). (from [[Animation Glossary]])

API snapshot: class, inherits `AnimationClip` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Emote: under 10 s, root near origin, no frame pops, CurveAnimation, standard R15. ([[Bundles Animation Packs and Emotes for Sale]])
- CurveAnimation playback against `RotationCurve` / `FloatCurve` sampling. ([[How the Animator Really Behaves]])
- Publishing is the same; tooling is not. Once published, a CurveAnimation plays like any other animation asset through the Animator, with the same permission rules and replication. ([[CurveAnimation and Curve Channels]])
- A `KeyframeSequence` / `CurveAnimation` in your place, which you then publish (Publishing Animations). ([[Moon Animator and Third-Party Tools]])

## Mentioned in

19 notes in 5 sections. The 19 most relevant are linked:

### 08 Animation
[[Animation Editor Advanced]] · [[Animation Editor Workflow]] · [[Animation Glossary]] · [[Animation Objects]] · [[Animation Start Here]] · [[CurveAnimation and Curve Channels]] · [[How the Animator Really Behaves]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Markers and Events]] · [[Moon Animator and Third-Party Tools]] · [[Open Questions]] · [[Pipeline - Importing Animated Enemies]] · [[Rigs and Joints]] · [[Snippets - Building and Sampling Clips]] · [[Timing Spacing and Frame Charts]]

### 14 3D Modeling
[[Bezier Curves and Splines for Modellers]]

### 37 Avatars and UGC
[[Bundles Animation Packs and Emotes for Sale]]

### 46 Resource Library
[[Links - Animation creation]]

### Root notes
[[00 Start Here]]

<!-- atlas:generated -->
