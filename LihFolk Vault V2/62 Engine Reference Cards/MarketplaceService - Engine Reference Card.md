---
tags: [reference, engine, marketplaceservice, api/MarketplaceService, type/reference, area/scripting, level/intermediate, api/ProcessReceipt, api/GetProductInfoAsync, api/Player]
---

# MarketplaceService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: granting developer products from `PromptProductPurchaseFinished`.
> - Avoid: setting `ProcessReceipt` in more than one script.
> - Avoid: leaving `ProcessReceipt` unset while selling products.
> - One receipt path: `ProcessReceipt` or `BindReceiptHandler`, keyed by `PurchaseId` for idempotent grants.
> - Persist the grant (UpdateAsync) before returning Processed / PurchaseGranted.
> - Every `...Async` call wrapped in `pcall`.
>
> Cost: TL;DR ~150 tok · whole note ~1.8k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The service behind every in-experience sale: prompts, ownership checks, product info and receipt handling. Pair it with [[Developer Products and ProcessReceipt]], [[Game Passes]] and [[Purchase Data and Receipts]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| ProcessReceipt | callback | `(receiptInfo: Dictionary) -> Enum.ProductPurchaseDecision` | none | Set once, in one server Script | callback may yield |
| BindReceiptHandler | method | `(transactionType: Enum.ReceiptType, handler: function, filter: {number}?) -> RBXScriptConnection` | filter omitted = catch-all | Server; handler returns `Enum.ReceiptDecision` | no |
| PromptProductPurchase | method | `(player, productId: int64, equipIfPurchased = true, currencyType = Default)` | see signature | Prompts a developer product of the current game | no |
| PromptGamePassPurchase | method | `(player, gamePassId: int64)` | - | Only passes belonging to the current game | no |
| PromptPurchase | method | `(player, assetId: int64, equipIfPurchased = true, currencyType = Default)` | see signature | Server script required for "Experience By Place ID (API Only)" items | no |
| PromptBundlePurchase | method | `(player, bundleId: int64)` | - | Avatar bundles | no |
| PromptBulkPurchase | method | `(player, lineItems: {any}, options: Dictionary)` | - | Server scripts only; avatar items only | no |
| PromptSubscriptionPurchase | method | `(user: Player, subscriptionId: string)` | - | Experience subscriptions | no |
| PromptRobloxSubscriptionPurchase | method | `(user: Player)` | - | Replaces deprecated PromptPremiumPurchase | no |
| PromptRobuxTransferAsync | method | `(sender: Player, receiverUserId: int64, amount: int64) -> string` | - | Server-only (RunContext Server) | yes |
| OpenShop | method | `(player: Player)` | - | Opens the auto-generated in-game Shop overlay | no |
| UserOwnsGamePassAsync | method | `(userId: number, gamePassId: int64) -> boolean` | - | Client and server; cached | yes |
| PlayerOwnsAssetAsync | method | `(player, assetId: int64) -> boolean` | - | Wrap in pcall; not for passes | yes |
| PlayerOwnsBundleAsync | method | `(player: Player, bundleId: int64) -> boolean` | - | Wrap in pcall | yes |
| GetProductInfoAsync | method | `(assetId: int64, infoType: Enum.InfoType = Asset) -> Dictionary` | infoType = Asset | Throws if the ID does not exist | yes |
| GetDeveloperProductsAsync | method | `() -> Pages` | - | All developer products of this experience | yes |
| [[GetUserSubscriptionStatusAsync]] | method | `(user: Player, subscriptionId: string) -> Dictionary` | - | Returns IsSubscribed, IsRenewing | yes |
| GetSubscriptionProductInfoAsync | method | `(subscriptionId: string) -> Dictionary` | - | Client RunContext only (localized price) | yes |
| GetUsersPriceLevelsAsync | method | `(userIds: {number}) -> {PriceLevelInfo}` | - | Regional price levels | yes |
| RankProductsAsync / RecommendTopProductsAsync | method | `(ids) / (infoTypes) -> {RankedItem}` | - | Personalised ordering | yes |
| PromptProductPurchaseFinished | event | `(userId: int64, productId: int64, isPurchased: boolean)` | - | UI signal only, never grant from it | - |
| PromptGamePassPurchaseFinished | event | `(player, gamePassId: int64, wasPurchased: boolean)` | - | Refreshes the ownership cache | - |

Superseded names: `GetProductInfo` -> `GetProductInfoAsync`, `PlayerOwnsAsset` -> `PlayerOwnsAssetAsync`, `PlayerOwnsBundle` -> `PlayerOwnsBundleAsync`, `PromptPremiumPurchase` -> `PromptRobloxSubscriptionPurchase`.

## Limits and defaults

- `PromptBulkPurchase`: up to 20 items per prompt.
- `RankProductsAsync`: client-side throttle of 10 requests per minute; wait 60 s after hitting it.
- `RecommendTopProductsAsync`: returns up to 50 items; throttle of 5 requests per minute, then wait 60 s.
- `ProcessReceipt` has no timeout: a yielded callback's result is still accepted while the server runs, and there is no time-based retry.
- `UserOwnsGamePassAsync` results are cached; an out-of-experience purchase can take several minutes to show, while a fresh join after purchase always returns true.
- `GetProductInfoAsync` and `UserOwnsGamePassAsync` support transparent batching when spawned concurrently with `task.spawn`.

## Replication and authority

- Receipts are server business: `ProcessReceipt` is set once in one server Script, and `BindReceiptHandler` handlers take precedence over it, falling through to `ProcessReceipt` when no handler matches, so you can migrate incrementally.
- A receipt only fires while the buyer is on a server; unresolved receipts are redelivered on the next purchase or the next join, and the same receipt can briefly run on two servers.
- `PromptRobuxTransferAsync` and `PromptBulkPurchase` are server-only; `GetSubscriptionProductInfoAsync` is client-only.
- Prompt-finished events are client-originated signals; confirm ownership with the `...OwnsAsync` methods.

## Common mistakes

- Avoid: granting developer products from `PromptProductPurchaseFinished`. Symptom: free items for anyone who closes the prompt, and missed grants for Store-tab purchases.
- Avoid: setting `ProcessReceipt` in more than one script. Symptom: only the last assignment runs and other products never grant.
- Avoid: leaving `ProcessReceipt` unset while selling products. Symptom: receipts are auto-acknowledged and cannot be recovered.
- Avoid: returning `PurchaseGranted` before the save succeeds. Symptom: players lose purchases after a DataStore failure; return `NotProcessedYet` instead.
- Avoid: calling `PlayerOwnsAssetAsync` for passes. Symptom: wrong answers, because passes use their own ID system.
- Avoid: trusting a Studio test of a foreign product ID. Symptom: the mocked prompt succeeds in Studio but fails live.

## Checklist

- One receipt path: `ProcessReceipt` or `BindReceiptHandler`, keyed by `PurchaseId` for idempotent grants.
- Persist the grant (UpdateAsync) before returning Processed / PurchaseGranted.
- Every `...Async` call wrapped in `pcall`.
- Gate perks on `UserOwnsGamePassAsync` at join and on `PromptGamePassPurchaseFinished`.
- Use only the Async names and `PromptRobloxSubscriptionPurchase`.

Source: https://create.roblox.com/docs/reference/engine/classes/MarketplaceService - verified 2026-10-29

<!-- related:start -->
## Related
[[AI Pitfalls - Data and Monetization]] · [[Shop with Game Passes and Developer Products End to End]] · [[BadgeService - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]] · [[MessagingService - Engine Reference Card]] · [[MemoryStoreService - Engine Reference Card]] · [[Players - Engine Reference Card]] · [[TeleportService - Engine Reference Card]] · [[RunService - Engine Reference Card]]
<!-- related:end -->
