---
tags: [atlas, api, type/atlas, area/monetization, area/platform, api/GetUserSubscriptionStatusAsync]
---
# GetUserSubscriptionStatusAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetUserSubscriptionStatusAsync` gives two booleans, `IsSubscribed` and `IsRenewing`.
> - `MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId)`: server-only; returns a dictionary with...
> - `GetUserSubscriptionStatusAsync` keeps returning `IsSubscribed = true` and `IsRenewing = true`, so the player keeps their...
>
> Cost: TL;DR ~120 tok · whole note ~280 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetUserSubscriptionStatusAsync` gives two booleans, `IsSubscribed` and `IsRenewing`. (from [[Subscriptions and Recurring Revenue]])

API snapshot: member of `MarketplaceService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId)`: server-only; returns a dictionary with `IsSubscribed` and `IsRenewing`. ([[Subscriptions and Premium Payouts]])
- `GetUserSubscriptionStatusAsync` keeps returning `IsSubscribed = true` and `IsRenewing = true`, so the player keeps their experience. ([[Subscriptions and Recurring Revenue]])

## Mentioned in

3 notes in 3 sections. The 3 most relevant are linked:

### 11 Monetization Publishing and Live Ops
[[Subscriptions and Premium Payouts]]

### 49 Roblox Platform Features
[[Subscriptions and Recurring Revenue]]

### 62 Engine Reference Cards
[[MarketplaceService - Engine Reference Card]]

<!-- atlas:generated -->
