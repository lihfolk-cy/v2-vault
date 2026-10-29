---
tags: [atlas, api, type/atlas, area/monetization, area/ai, api/GetProductInfoAsync]
---
# GetProductInfoAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetProductInfoAsync` is the current name; `GetProductInfo` is deprecated (Docs, Oct 2026).
> - Avoid: No asset-type check -> `GetProductInfoAsync` allow-list.
> - Every price on screen comes from `GetProductInfoAsync` (Dynamic Price Check passes) (Pricing and Store Design)
> - Prices shown via `GetProductInfoAsync`. (Discovery and Monetization Changes 2025-2026)
>
> Cost: TL;DR ~130 tok · whole note ~580 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetProductInfoAsync` is the current name; `GetProductInfo` is deprecated (Docs, Oct 2026). (from [[Pricing and Store Design]])

`GetProductInfoAsync` is the current name of the product-info call; `GetProductInfo` is deprecated (Roblox docs, see Pricing and Store Design). (from [[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]])

API snapshot: member of `MarketplaceService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: No asset-type check -> `GetProductInfoAsync` allow-list. ([[AvatarEditorService and In-Game Avatar Editors]])
- Every price on screen comes from `GetProductInfoAsync` (Dynamic Price Check passes) ([[Pricing and Store Design]])
- Prices shown via `GetProductInfoAsync`. ([[Discovery and Monetization Changes 2025-2026]])
- A "chime" sounds like a weapon: Id reused by name, never checked -> Audit ids with `GetProductInfoAsync`, use role keys. ([[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]])
- Avoid: Yielding (a `task.wait`, a data store call, `GetProductInfoAsync`) between "check the player owns it" and "remove it". ([[Saved Inventory End to End]])

## Mentioned in

18 notes in 9 sections. The 18 most relevant are linked:

### 11 Monetization Publishing and Live Ops
[[Developer Products and ProcessReceipt]] · [[Game Passes]] · [[Monetization Overview]] · [[Pricing and Store Design]] · [[Subscriptions and Premium Payouts]]

### 15 AI Tools
[[AI Pitfalls - Data and Monetization]] · [[What AI Models Get Wrong in Roblox]]

### 24 Worked Builds
[[LihFolk Systems Library]] · [[Saved Inventory End to End]]

### 37 Avatars and UGC
[[AvatarEditorService and In-Game Avatar Editors]] · [[Avatars and UGC Start Here]]

### 38 Live Ops Deep Dive
[[Limited-Time Offers - Design and Ethics]]

### 39 Studio Plugins and Tooling
[[Publishing Selling and Updating Plugins]]

### 49 Roblox Platform Features
[[Discovery and Monetization Changes 2025-2026]] · [[Engine and API Changes 2025-2026]]

### 56 Field Notes
[[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]]

### Root notes
[[Open Questions - Whole Vault]] · [[Skill - Roblox Monetization Compliance]]

<!-- atlas:generated -->
