---
tags: [atlas, api, type/atlas, area/ai, area/avatars, api/PromptPurchaseFinished]
---
# PromptPurchaseFinished

<!-- tldr:start -->
> [!tldr] TL;DR
> - `PromptPurchaseFinished` does not fire for developer product or pass prompts (docs), so it is only the right event for asset...
> - Detect: `rg -n "PromptProductPurchaseFinished|PromptPurchaseFinished"` near grant code; `ProcessReceipt` without `PurchaseId`.
> - Listen for `PromptPurchaseFinished` but re-check ownership server-side before granting anything game-side; the finished event...
>
> Cost: TL;DR ~140 tok · whole note ~280 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`PromptPurchaseFinished` does not fire for developer product or pass prompts (docs), so it is only the right event for asset purchases like these. (from [[UGC Pricing Limiteds and Marketplace Rules]])

API snapshot: member of `MarketplaceService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Detect: `rg -n "PromptProductPurchaseFinished|PromptPurchaseFinished"` near grant code; `ProcessReceipt` without `PurchaseId`. ([[AI Pitfalls - Data and Monetization]])
- Listen for `PromptPurchaseFinished` but re-check ownership server-side before granting anything game-side; the finished event is not a receipt. ([[AvatarEditorService and In-Game Avatar Editors]])

## Mentioned in

4 notes in 2 sections. The 4 most relevant are linked:

### 15 AI Tools
[[AI Pitfalls - Data and Monetization]] · [[What AI Models Get Wrong in Roblox]]

### 37 Avatars and UGC
[[AvatarEditorService and In-Game Avatar Editors]] · [[UGC Pricing Limiteds and Marketplace Rules]]

<!-- atlas:generated -->
