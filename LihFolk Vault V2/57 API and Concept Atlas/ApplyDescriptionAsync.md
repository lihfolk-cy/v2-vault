---
tags: [atlas, api, type/atlas, area/avatars, area/gameplay, api/ApplyDescriptionAsync]
---
# ApplyDescriptionAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ApplyDescriptionAsync` yields while it loads meshes and textures.
> - Use Animator:LoadAnimation and ApplyDescriptionAsync.
> - The character can die mid-apply. `ApplyDescriptionAsync` yields.
> - `ApplyDescriptionAsync` diffs against a cache.
>
> Cost: TL;DR ~100 tok · whole note ~340 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ApplyDescriptionAsync` yields while it loads meshes and textures. (from [[AvatarEditorService and In-Game Avatar Editors]])

API snapshot: member of `Humanoid` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Use Animator:LoadAnimation and ApplyDescriptionAsync. ([[Humanoid - Engine Reference Card]])
- The character can die mid-apply. `ApplyDescriptionAsync` yields. ([[HumanoidDescription and Outfit Systems]])
- `ApplyDescriptionAsync` diffs against a cache. If any other script changed the character, use `ApplyDescriptionResetAsync`. ([[Avatars and UGC Start Here]])

## Mentioned in

9 notes in 6 sections. The 9 most relevant are linked:

### 09 Gameplay Systems
[[Character Select and Class Systems with Different Rigs]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 37 Avatars and UGC
[[AvatarEditorService and In-Game Avatar Editors]] · [[Avatars and UGC Start Here]] · [[Bundles Animation Packs and Emotes for Sale]] · [[HumanoidDescription and Outfit Systems]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]]

### 62 Engine Reference Cards
[[Humanoid - Engine Reference Card]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
