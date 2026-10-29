---
tags: [atlas, api, type/atlas, area/animation, area/studio, api/StepAnimations]
---
# StepAnimations

<!-- tldr:start -->
> [!tldr] TL;DR
> - `StepAnimations` is the only way to run the real Animator without pressing Play, so every serious offline animation tool uses it.
> - Measured in Edit against `Animator:StepAnimations` (details and numbers in How the Animator Really Behaves and Lua Keyframe...
> - A/B against `Animator:StepAnimations` on a few clips: uneven and evenly keyed, Linear and eased, big turns far from rest, two...
> - One of the same project's tool snippets calls `StepAnimations(0)` right after `Play(0)`, which contradicts that rule; the...
>
> Cost: TL;DR ~170 tok · whole note ~610 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`StepAnimations` is the only way to run the real Animator without pressing Play, so every serious offline animation tool uses it. (from [[Animator Deep Dive]])

API snapshot: member of `Animator` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Measured in Edit against `Animator:StepAnimations` (details and numbers in How the Animator Really Behaves and Lua Keyframe... ([[Lua Keyframe Player]])
- A/B against `Animator:StepAnimations` on a few clips: uneven and evenly keyed, Linear and eased, big turns far from rest, two... ([[Snippets - Lua Keyframe Player Core]])
- One of the same project's tool snippets calls `StepAnimations(0)` right after `Play(0)`, which contradicts that rule; the sources do not say whether a zero step applies the first pose. ([[Animator Deep Dive]])
- Step it with `Animator:StepAnimations(1/60)` in Edit and record `Transform`s (harness in Testing Animations in Studio). ([[Open Questions]])

## Mentioned in

33 notes in 4 sections. The 25 most relevant are linked:

### 08 Animation
[[Animation Data from Blender to Roblox]] · [[Animation Editor Advanced]] · [[Animation Quality Standard]] · [[Animator Deep Dive]] · [[Authoring Clips in Code]] · [[Case Study - Abilities That Only Worked in Studio]] · [[CurveAnimation and Curve Channels]] · [[Custom Characters and StarterCharacter]] · [[Debugging Animation Problems]] · [[Engine Gotchas]] · [[Frame Order and RunService Timing]] · [[How the Animator Really Behaves]] · [[IKControl Reference]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Keyframes, Easing and Interpolation]] · [[Lua Keyframe Player]] · [[Lua Keyframe Player Internals]] · [[Open Questions]] · [[Procedural Animation]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - Lua Keyframe Player Core]] · [[Studio Tooling Architecture]] · [[Testing Animations in Studio]] · [[Troubleshooting Table]]

### 15 AI Tools
[[AI Pitfalls - Physics and Animation]]

Also mentioned in (not linked): Moon Animator and Third-Party Tools · Pipeline - Arm IK Baking and QA · Playback, Priorities and Blending · Retargeting Animations Between Rigs · Testing Modes - Play Run and Multi-Client · Testing Strategies and Frameworks · Weapon Rig Player · Weight Painting and Skinning for Roblox

<!-- atlas:generated -->
