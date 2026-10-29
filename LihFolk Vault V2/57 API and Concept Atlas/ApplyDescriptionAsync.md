---
tags: [atlas, api, type/atlas, area/avatars, area/scripting, api/ApplyDescriptionAsync]
---
# ApplyDescriptionAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ApplyDescriptionAsync` yields while it loads meshes and textures.
> - The character can die mid-apply. `ApplyDescriptionAsync` yields.
> - `ApplyDescriptionAsync` diffs against a cache.
>
> Cost: TL;DR ~90 tok · whole note ~260 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ApplyDescriptionAsync` yields while it loads meshes and textures. (from [[AvatarEditorService and In-Game Avatar Editors]])

API snapshot: member of `Humanoid` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- The character can die mid-apply. `ApplyDescriptionAsync` yields. ([[HumanoidDescription and Outfit Systems]])
- `ApplyDescriptionAsync` diffs against a cache. If any other script changed the character, use `ApplyDescriptionResetAsync`. ([[Avatars and UGC Start Here]])

## Mentioned in

6 notes in 3 sections. The 6 most relevant are linked:

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 37 Avatars and UGC
[[AvatarEditorService and In-Game Avatar Editors]] · [[Avatars and UGC Start Here]] · [[Bundles Animation Packs and Emotes for Sale]] · [[HumanoidDescription and Outfit Systems]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
