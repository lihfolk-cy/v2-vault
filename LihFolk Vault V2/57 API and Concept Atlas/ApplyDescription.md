---
tags: [atlas, api, type/atlas, area/ai, area/gameplay, api/ApplyDescription]
---
# ApplyDescription

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ApplyDescription` is a yielding server call that can fail (asset loading); wrap it in `pcall`, and apply only to a fully...
> - `grep -nE ":(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ApplyDescription|ReserveServer)\(...
> - Wrong: `GetProductInfo`, `PlayerOwnsAsset`, `AwardBadge`, `LoadCharacter`, `IsInGroup`, `GetRankInGroup`, `ApplyDescription`...
>
> Cost: TL;DR ~140 tok · whole note ~360 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ApplyDescription` is a yielding server call that can fail (asset loading); wrap it in `pcall`, and apply only to a fully loaded character (after `CharacterAppearanceLoaded` if you mix with the player's own avatar). (from [[Character Select and Class Systems with Different Rigs]])

API snapshot: member of `Humanoid`; flagged deprecated (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `grep -nE ":(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ApplyDescription|ReserveServer)\(... ([[Engine and API Changes 2025-2026]])
- Wrong: `GetProductInfo`, `PlayerOwnsAsset`, `AwardBadge`, `LoadCharacter`, `IsInGroup`, `GetRankInGroup`, `ApplyDescription`, `ReserveServer`, `CreateHumanoidModelFromDescription`. ([[AI Pitfalls - Stale APIs and Luau]])

## Mentioned in

7 notes in 6 sections. The 7 most relevant are linked:

### 09 Gameplay Systems
[[Character Select and Class Systems with Different Rigs]]

### 15 AI Tools
[[AI Pitfalls - Stale APIs and Luau]] · [[What AI Models Get Wrong in Roblox]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 37 Avatars and UGC
[[HumanoidDescription and Outfit Systems]]

### 49 Roblox Platform Features
[[Engine and API Changes 2025-2026]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
