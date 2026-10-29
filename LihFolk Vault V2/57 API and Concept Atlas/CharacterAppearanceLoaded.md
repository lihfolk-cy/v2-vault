---
tags: [atlas, api, type/atlas, area/avatars, area/animation, api/CharacterAppearanceLoaded]
---
# CharacterAppearanceLoaded

<!-- tldr:start -->
> [!tldr] TL;DR
> - `CharacterAppearanceLoaded` fires after the avatar's own animation package has been applied, so your ids are not overwritten...
> - Avoid: Setting ids before `CharacterAppearanceLoaded` -> Set after appearance loads.
> - Applies happen after `CharacterAppearanceLoaded` or via spawn-with.
> - Measure on spawn after `CharacterAppearanceLoaded`, cache the result, and re-measure when the description changes.
>
> Cost: TL;DR ~140 tok · whole note ~370 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`CharacterAppearanceLoaded` fires after the avatar's own animation package has been applied, so your ids are not overwritten by it. (from [[Snippets - Playing Animations]])

API snapshot: member of `Player` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Setting ids before `CharacterAppearanceLoaded` -> Set after appearance loads. ([[The Default Animate Script]])
- Applies happen after `CharacterAppearanceLoaded` or via spawn-with. ([[HumanoidDescription and Outfit Systems]])
- Measure on spawn after `CharacterAppearanceLoaded`, cache the result, and re-measure when the description changes. ([[Avatar Body Types and Scale in Gameplay]])
- Capture the base once. `CharacterAppearanceLoaded` fires on every respawn; capturing on every spawn after a try-on would make the try-on the new "real" look. ([[AvatarEditorService and In-Game Avatar Editors]])

## Mentioned in

6 notes in 3 sections. The 6 most relevant are linked:

### 08 Animation
[[Snippets - Playing Animations]] · [[The Default Animate Script]]

### 09 Gameplay Systems
[[Character Select and Class Systems with Different Rigs]]

### 37 Avatars and UGC
[[Avatar Body Types and Scale in Gameplay]] · [[AvatarEditorService and In-Game Avatar Editors]] · [[HumanoidDescription and Outfit Systems]]

<!-- atlas:generated -->
