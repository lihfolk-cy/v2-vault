---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/CreateHumanoidModelFromDescriptionAsync]
---
# CreateHumanoidModelFromDescriptionAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `CreateHumanoidModelFromDescriptionAsync` builds a whole character Model, which is a web-backed, yielding operation.
> - `Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)` builds test dummies in Edit.
> - `Players:CreateHumanoidModelFromDescriptionAsync` in Edit returned a rig without Motor6Ds; build test rigs from rig attachments.
>
> Cost: TL;DR ~130 tok · whole note ~350 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`CreateHumanoidModelFromDescriptionAsync` builds a whole character Model, which is a web-backed, yielding operation. (from [[HumanoidDescription and Outfit Systems]])

API snapshot: member of `Players` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)` builds test dummies in Edit. ([[Custom Characters and StarterCharacter]])
- `Players:CreateHumanoidModelFromDescriptionAsync` in Edit returned a rig without Motor6Ds; build test rigs from rig attachments. ([[How the Animator Really Behaves]])

## Mentioned in

11 notes in 5 sections. The 11 most relevant are linked:

### 08 Animation
[[Animation Editor Workflow]] · [[Animator Deep Dive]] · [[Custom Characters and StarterCharacter]] · [[Engine Gotchas]] · [[How the Animator Really Behaves]] · [[R15 Rig Anatomy and Attachments]] · [[Testing Animations in Studio]]

### 09 Gameplay Systems
[[Characters and Humanoids]]

### 37 Avatars and UGC
[[HumanoidDescription and Outfit Systems]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]]

### 62 Engine Reference Cards
[[Players - Engine Reference Card]]

<!-- atlas:generated -->
