---
tags: [atlas, api, type/atlas, area/avatars, area/animation, api/CharacterAppearanceLoaded]
---
# CharacterAppearanceLoaded

<!-- tldr:start -->
> [!tldr] TL;DR
> - CharacterAppearanceLoaded fires only on the server.
> - Avoid: Setting ids before `CharacterAppearanceLoaded` -> Set after appearance loads.
> - Applies happen after `CharacterAppearanceLoaded` or via spawn-with.
> - Measure on spawn after `CharacterAppearanceLoaded`, cache the result, and re-measure when the description changes.
>
> Cost: TL;DR ~120 tok · whole note ~310 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

CharacterAppearanceLoaded fires only on the server. (from [[Player - Engine Reference Card]])

API snapshot: member of `Player` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Setting ids before `CharacterAppearanceLoaded` -> Set after appearance loads. ([[The Default Animate Script]])
- Applies happen after `CharacterAppearanceLoaded` or via spawn-with. ([[HumanoidDescription and Outfit Systems]])
- Measure on spawn after `CharacterAppearanceLoaded`, cache the result, and re-measure when the description changes. ([[Avatar Body Types and Scale in Gameplay]])

## Mentioned in

7 notes in 4 sections. The 7 most relevant are linked:

### 08 Animation
[[Snippets - Playing Animations]] · [[The Default Animate Script]]

### 09 Gameplay Systems
[[Character Select and Class Systems with Different Rigs]]

### 37 Avatars and UGC
[[Avatar Body Types and Scale in Gameplay]] · [[AvatarEditorService and In-Game Avatar Editors]] · [[HumanoidDescription and Outfit Systems]]

### 62 Engine Reference Cards
[[Player - Engine Reference Card]]

<!-- atlas:generated -->
