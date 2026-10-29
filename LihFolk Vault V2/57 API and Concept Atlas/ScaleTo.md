---
tags: [atlas, api, type/atlas, area/animation, area/world, api/ScaleTo]
---
# ScaleTo

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ScaleTo` scales the model around its pivot; with the pivot at the trunk base, grounding stays correct.
> - Know whether your characters are body-scaled or `ScaleTo`-scaled; author translations to match.
> - Test. A `ScaleTo(2)` rig with translation keys on the root child and on a limb.
> - Assuming `ScaleTo` works on upgraded characters.
>
> Cost: TL;DR ~130 tok · whole note ~530 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ScaleTo` scales the model around its pivot; with the pivot at the trunk base, grounding stays correct. (from [[Foliage Props and Scatter]])

API snapshot: member of `Model` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Know whether your characters are body-scaled or `ScaleTo`-scaled; author translations to match. ([[Scale and Animation]])
- Test. A `ScaleTo(2)` rig with translation keys on the root child and on a limb. ([[Open Questions]])
- Assuming `ScaleTo` works on upgraded characters. Symptom: scaled characters with detached or misplaced limbs. ([[AnimationConstraint and Physically Simulated Characters]])
- Body scale values versus model scale. If you scale players with `Model:ScaleTo`, `Model:GetScale()` reports it; body scale values do not. ([[Avatar Body Types and Scale in Gameplay]])

## Mentioned in

24 notes in 6 sections. The 24 most relevant are linked:

### 06 World Building and Art
[[Foliage Props and Scatter]] · [[Modeling in Blender for Roblox]]

### 08 Animation
[[Animation Editor Advanced]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Custom Characters and StarterCharacter]] · [[Enemy and NPC Animation]] · [[Engine Gotchas]] · [[Exporting FBX vs GLB]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[Importing Models and Rigs]] · [[Motor6D Math and CFrame Composition]] · [[Open Questions]] · [[Retargeting Animations Between Rigs]] · [[Scale and Animation]] · [[Snippets - Procedural Motion]] · [[Spec-Driven Move Authoring]] · [[Testing Animations in Studio]] · [[Troubleshooting Table]]

### 14 3D Modeling
[[Exporting and Validating Models for Roblox]]

### 15 AI Tools
[[AI Pitfalls - Assets and Import]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]]

### 37 Avatars and UGC
[[Avatar Body Types and Scale in Gameplay]] · [[HumanoidDescription and Outfit Systems]]

### 47 Game Feel and Juice
[[Squash Stretch and Anticipation in UI and Characters]]

<!-- atlas:generated -->
