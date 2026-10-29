---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/IKControl]
---
# IKControl

<!-- tldr:start -->
> [!tldr] TL;DR
> - `IKControl` is Roblox's built-in runtime IK component.
> - Avoid: Confusing IKControl with a baked IK clip.
> - The constraint and the IKControl share the same parent Model.
> - The engine's `IKControl`: declarative, solved by the engine, smoothing built in.
>
> Cost: TL;DR ~100 tok · whole note ~420 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`IKControl` is Roblox's built-in runtime IK component. (from [[IKControl Reference]])

IKControl: Roblox's built-in runtime IK component. (from [[Animation Glossary]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Confusing IKControl with a baked IK clip. ([[Animation Glossary]])
- The constraint and the IKControl share the same parent Model. ([[IKControl Reference]])
- The engine's `IKControl`: declarative, solved by the engine, smoothing built in. ([[Snippets - IK]])
- Engine IKControl was not used. The tools report says so explicitly: the clips were baked and the runtime did not need it. ([[Inverse Kinematics]])

## Mentioned in

21 notes in 4 sections. The 21 most relevant are linked:

### 08 Animation
[[Animation Editor Advanced]] · [[Animation Glossary]] · [[Animation Objects]] · [[Animation Start Here]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Foot Placement and Ground IK]] · [[IKControl Reference]] · [[Inverse Kinematics]] · [[Look-At Aim and Head Tracking]] · [[Lua Keyframe Player]] · [[Multi-Bone IK - FABRIK and CCD]] · [[Open Questions]] · [[Procedural Animation]] · [[Retargeting Animations Between Rigs]] · [[Snippets - IK]] · [[Snippets - Procedural Motion]] · [[Springs Damping and Smoothing]] · [[Troubleshooting Table]]

### 09 Gameplay Systems
[[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]]

### 46 Resource Library
[[Links - Inverse kinematics]]

### Root notes
[[00 Start Here]]

<!-- atlas:generated -->
