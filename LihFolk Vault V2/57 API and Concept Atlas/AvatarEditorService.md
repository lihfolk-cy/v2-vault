---
tags: [atlas, api, type/atlas, area/avatars, area/platform, api/AvatarEditorService]
---
# AvatarEditorService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `AvatarEditorService` (AES) is a client-facing bridge to the player's Roblox account: their inventory, outfits, favourites...
> - Platform outfits are separate. `AvatarEditorService:GetOutfitsAsync` lists the player's Roblox outfits (needs their permission...
> - When an avatar item sells inside a game (through the Avatar Inspect Menu, `AvatarEditorService` or `MarketplaceService`), the...
> - AvatarEditorService and In-Game Avatar Editors.
>
> Cost: TL;DR ~150 tok · whole note ~420 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`AvatarEditorService` (AES) is a client-facing bridge to the player's Roblox account: their inventory, outfits, favourites, and the catalog. (from [[AvatarEditorService and In-Game Avatar Editors]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Platform outfits are separate. `AvatarEditorService:GetOutfitsAsync` lists the player's Roblox outfits (needs their permission flow); `Players:GetHumanoidDescriptionFromOutfitIdAsync` loads one. ([[HumanoidDescription and Outfit Systems]])
- When an avatar item sells inside a game (through the Avatar Inspect Menu, `AvatarEditorService` or `MarketplaceService`), the item creator gets 30% and the game owner gets 40%. ([[Commerce and Physical Goods]])
- AvatarEditorService and In-Game Avatar Editors. ([[00 Start Here]])
- Pair with Genre Playbook - Roleplay and Social Hangouts, Trading Systems Without Duplication and AvatarEditorService and In-Game Avatar Editors. ([[Platform Features Start Here]])

## Mentioned in

9 notes in 3 sections. The 9 most relevant are linked:

### 37 Avatars and UGC
[[AvatarEditorService and In-Game Avatar Editors]] · [[Avatars and UGC Start Here]] · [[HumanoidDescription and Outfit Systems]] · [[UGC Pricing Limiteds and Marketplace Rules]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]] · [[Commerce and Physical Goods]] · [[Platform Features Start Here]]

### Root notes
[[00 Start Here]] · [[Open Questions - Whole Vault]]

<!-- atlas:generated -->
