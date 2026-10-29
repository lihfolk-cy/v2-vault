---
tags: [atlas, concept, type/atlas, area/animation, area/math]
---
# Slerp

<!-- tldr:start -->
> [!tldr] TL;DR
> - Slerp moves at constant angular speed along the shortest arc.
> - An off-hand shoulder swinging overhead differed by 9 to 12 degrees from slerp mid-segment.
> - Measured to 0.24 degrees on 15 clips where slerp was up to 178 degrees off; an offline model matched every baked clip (several...
> - Behaviour can differ from KeyframeSequence.
>
> Cost: TL;DR ~120 tok · whole note ~400 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Slerp moves at constant angular speed along the shortest arc. (from [[Rotations Angles and Quaternions]])

## Key facts

- An off-hand shoulder swinging overhead differed by 9 to 12 degrees from slerp mid-segment. ([[Keyframes, Easing and Interpolation]])
- Measured to 0.24 degrees on 15 clips where slerp was up to 178 degrees off; an offline model matched every baked clip (several hundred) (median 0.03 degrees, 99th percentile 2 to 4). ([[Open Questions]])
- Behaviour can differ from KeyframeSequence. The documented slerp for linear RotationCurve keys differs from the measured rotation-vector blend of uneven KeyframeSequences. ([[CurveAnimation and Curve Channels]])

## Mentioned in

19 notes in 3 sections. The 19 most relevant are linked:

### 08 Animation
[[Animation Data from Blender to Roblox]] · [[Animation Editor Advanced]] · [[Animator Deep Dive]] · [[Authoring Clips in Code]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[CurveAnimation and Curve Channels]] · [[Debugging Animation Problems]] · [[Elbow Poles Swivel and Joint Limits]] · [[Engine Gotchas]] · [[How the Animator Really Behaves]] · [[Inverse Kinematics]] · [[Keyframes, Easing and Interpolation]] · [[Motor6D Math and CFrame Composition]] · [[Open Questions]] · [[Snippets - Building and Sampling Clips]] · [[Troubleshooting Table]]

### 15 AI Tools
[[AI Animation and Motion from Video]]

### 40 Game Math
[[Game Math Start Here]] · [[Rotations Angles and Quaternions]]

<!-- atlas:generated -->
