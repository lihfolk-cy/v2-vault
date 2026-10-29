---
tags: [atlas, api, type/atlas, area/ai, area/monetization, api/GetProductInfo]
---
# GetProductInfo

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetProductInfo` is now marked deprecated on the reference page in favour of `GetProductInfoAsync` (Docs, Oct 2026).
> - Avoid: Writing `GetProductInfo`, `LoadCharacter` or `AwardBadge` in new code.
> - `grep -nE ":(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ApplyDescription|ReserveServer)\(...
> - Wrong: `GetProductInfo`, `PlayerOwnsAsset`, `AwardBadge`, `LoadCharacter`, `IsInGroup`, `GetRankInGroup`, `ApplyDescription`...
>
> Cost: TL;DR ~160 tok · whole note ~420 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetProductInfo` is now marked deprecated on the reference page in favour of `GetProductInfoAsync` (Docs, Oct 2026). (from [[Game Passes]])

API snapshot: member of `MarketplaceService`; flagged deprecated (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Writing `GetProductInfo`, `LoadCharacter` or `AwardBadge` in new code. ([[Engine and API Changes 2025-2026]])
- `grep -nE ":(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ApplyDescription|ReserveServer)\(... ([[Engine and API Changes 2025-2026]])
- Wrong: `GetProductInfo`, `PlayerOwnsAsset`, `AwardBadge`, `LoadCharacter`, `IsInGroup`, `GetRankInGroup`, `ApplyDescription`, `ReserveServer`, `CreateHumanoidModelFromDescription`. ([[AI Pitfalls - Stale APIs and Luau]])
- `GetProductInfo`, `LoadCharacter`, `AwardBadge`, `IsInGroup`, `ReserveServer` and 41 others have `Async` names. ([[Roblox Changes 2025-2026]])

## Mentioned in

10 notes in 6 sections. The 10 most relevant are linked:

### 02 Luau Scripting
[[Error Handling and Retries]]

### 11 Monetization Publishing and Live Ops
[[Game Passes]] · [[Pricing and Store Design]]

### 15 AI Tools
[[AI Pitfalls - Data and Monetization]] · [[AI Pitfalls - Stale APIs and Luau]] · [[What AI Models Get Wrong in Roblox]]

### 49 Roblox Platform Features
[[Engine and API Changes 2025-2026]] · [[Roblox Changes 2025-2026]]

### 56 Field Notes
[[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
