---
tags: [atlas, api, type/atlas, area/ai, area/platform, api/GetProductInfo]
---
# GetProductInfo

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetProductInfo` is now marked deprecated on the reference page in favour of `GetProductInfoAsync` (Docs, Oct 2026).
> - Avoid: Writing `GetProductInfo`, `LoadCharacter` or `AwardBadge` in new code.
> - `grep -nE ":(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ApplyDescription|ReserveServer|Re...
> - Avoid: Pre-2026 names (`AwardBadge`, `GetProductInfo`, `LoadCharacter`, `ReserveServerAsync`, `TeleportPartyAsync`...
>
> Cost: TL;DR ~150 tok · whole note ~400 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetProductInfo` is now marked deprecated on the reference page in favour of `GetProductInfoAsync` (Docs, Oct 2026). (from [[Game Passes]])

API snapshot: member of `MarketplaceService`; flagged deprecated (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Writing `GetProductInfo`, `LoadCharacter` or `AwardBadge` in new code. ([[Engine and API Changes 2025-2026]])
- `grep -nE ":(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ApplyDescription|ReserveServer|Re... ([[Engine and API Changes 2025-2026]])
- Avoid: Pre-2026 names (`AwardBadge`, `GetProductInfo`, `LoadCharacter`, `ReserveServerAsync`, `TeleportPartyAsync`... ([[AI Pitfalls - Stale APIs and Luau]])

## Mentioned in

12 notes in 7 sections. The 12 most relevant are linked:

### 02 Luau Scripting
[[Error Handling and Retries]]

### 11 Monetization Publishing and Live Ops
[[Game Passes]] · [[Pricing and Store Design]]

### 15 AI Tools
[[AI Pitfalls - Data and Monetization]] · [[AI Pitfalls - Stale APIs and Luau]] · [[What AI Models Get Wrong in Roblox]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Engine and API Changes 2025-2026]] · [[Roblox Changes 2025-2026]]

### 56 Field Notes
[[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]]

### 62 Engine Reference Cards
[[MarketplaceService - Engine Reference Card]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
