---
tags: [ai-pitfalls, datastore, persistence, session-locking, processreceipt, monetization, paid-random-items, pricing, roblox-plus, type/guide, area/ai, level/intermediate]
verified: 2026-10-28
---
# AI Pitfalls - Data and Monetization

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Defaults written over real data after a failed load.
> - Avoid: `UpdateAsync` callbacks that yield or fire events.
> - Avoid: Saving on every coin change instead of a dirty flag plus interval.
> - All read-modify-write paths use `UpdateAsync` or a session-locked profile.
> - Failed load blocks saving.
> - `ProcessReceipt` is single, idempotent on `PurchaseId`, and saves before `PurchaseGranted`.
>
> Cost: TL;DR ~140 tok · whole note ~1.9k tok. Read more: ## 1. `GetAsync` then `SetAsync` on the same key · ## 6. Granting developer products in the wrong place · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Data and purchase bugs cost real money and player trust, and generated code gets them wrong in a few predictable ways: single-server thinking, the wrong purchase hook, and rules from before 2025. Hub: [[What AI Models Get Wrong in Roblox]]. Current limits: [[Data and Cloud Changes 2025-2026]].

## 1. `GetAsync` then `SetAsync` on the same key

- **Wrong:** read, modify, `SetAsync`. Two servers (or a fast rejoin) interleave and one write is lost.
- **Right:** `UpdateAsync` for read-modify-write. The transform **may run more than once**, must not yield, must not have side effects, and returns `nil` to cancel.

```lua
local ok, err = pcall(store.UpdateAsync, store, "u_" .. userId, function(old)
	old = old or { coins = 0, v = 1 }
	if old.coins < cost then return nil end -- cancel, no write
	old.coins -= cost
	return old
end)
```

- For whole player profiles, use a **session lock** ([[ProfileStore]]-style) so only one server owns the profile at a time. Without it, trading and rejoin dupes appear. See [[Session Locking and Profile Libraries]].
- **Detect:** `GetAsync` and `SetAsync` on the same key in one function.

## 2. Retry handling: none, or forever

- **Wrong:** a bare call with no `pcall`, or `repeat ... until ok` with no cap or backoff.
- **Right:** `pcall`, bounded retries with exponential backoff and jitter, and a clear "data failed to load" state that **blocks saving** so a failed load never overwrites good data with defaults. See [[Data Loss Prevention and Recovery]].

## 3. Pre-2025 limits and the read cache

- **Wrong:** "60 + 10 per player per server", "one write per key every 6 seconds".
- **Right (Roblox docs, October 2026):** budgets are per experience and shared with Open Cloud: reads 300 + CCU x 40 per minute, writes 300 + CCU x 20; per-key write throughput 4 MB per minute; value up to 4,194,304 characters; storage 500 MB + 1 MB per lifetime player.
- **Measured:** a `GetAsync` within about 4 s of a previous read returns the cached value; pass `DataStoreGetOptions` with `UseCache = false` when you need a fresh read (see [[DataStore Fundamentals]]).

## 4. Values that do not serialise

- **Wrong:** saving `Vector3`, `CFrame`, `Color3`, `Instance`s, `EnumItem`s, tables with mixed or sparse keys, `NaN`, or invalid UTF-8.
- **Why:** the model treats DataStore like a Lua table store.
- **Right:** convert to plain JSON-shaped data (`{x, y, z}` arrays, enum names as strings, string keys for maps). Version the schema (`v = 2`) and migrate on load. See [[Data Schema Design and Migrations]].

## 5. Keys and shutdown

- Key by `UserId`, never by `Name` (names change).
- `game:BindToClose` gets about 30 seconds: save all players **in parallel**, not one after another, and skip players whose data never loaded.
- In Studio, DataStores need "Enable Studio Access to API Services"; with it on, Studio writes to live data. Use a separate test place or a key prefix.

## 6. Granting developer products in the wrong place

- **Wrong:** granting in `PromptProductPurchaseFinished` (fires on the client's prompt closing; can be spoofed or missed), or a `ProcessReceipt` that grants every time it is called.
- **Right:** exactly one `MarketplaceService.ProcessReceipt` callback per server (assigning it again replaces the first). Grant **once per `PurchaseId`**, persist that the purchase was granted, then return `PurchaseGranted`. Return `NotProcessedYet` if the player is absent or the save failed; Roblox retries.

```lua
MarketplaceService.ProcessReceipt = function(r)
	local player = Players:GetPlayerByUserId(r.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local ok = Profiles.grantOnce(player, r.PurchaseId, function(data) -- records PurchaseId in the same save
		Products[r.ProductId](data)
	end)
	return if ok then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end
```

- **Detect:** `rg -n "PromptProductPurchaseFinished|PromptPurchaseFinished"` near grant code; `ProcessReceipt` without `PurchaseId`. See [[Developer Products and ProcessReceipt]] and [[Purchase Data and Receipts]].

## 7. Game pass checks

- **Wrong:** calling `UserOwnsGamePassAsync` on every action (yields, can fail), or never re-checking after an in-game purchase.
- **Right:** check once on join with `pcall`, cache, and on `PromptGamePassPurchaseFinished(player, passId, purchased)` re-verify with `UserOwnsGamePassAsync` before granting in-session.

## 8. Paid random items without numerical odds

- **Wrong:** eggs, crates or spins labelled only with rarity names; luck passes described as "x2 luck".
- **Right (Roblox docs, clarified May 26, 2026):** every outcome with numeric odds summing to 100% before purchase, including indirect purchases (keys, tickets) and odds modifiers, with displayed odds updated while a boost is active; honour `ArePaidRandomItemsRestricted`. Generate the displayed odds from the same table the roll uses (**Measured** practice). See [[Policy and Age Rules 2026]].

## 9. Money rules from before 2025

| Model writes | Current (see [[Discovery and Monetization Changes 2025-2026]]) |
|---|---|
| Hard-coded `"R$ 99"` labels | `GetProductInfoAsync`; passes have regional prices by default since March 30, 2026, and Plus members see discounts |
| Perks for `MembershipType.Premium` and "Premium Payouts" | Premium closed to new subscribers April 30, 2026; Premium Payouts replaced by [[Creator Rewards]] July 24, 2025; offer Plus with `PromptRobloxSubscriptionPurchase` |
| DevEx $0.0035 per Robux | $0.0038 standard (Sept 5, 2025); $0.0054 on US 18+ spend in eligible games (June 8, 2026) |
| `GetProductInfo` | `GetProductInfoAsync` (January 2026 rename) |

## 10. MemoryStore as storage

- **Wrong:** using MemoryStore for anything that must survive; items expire (maximum 45 days) and memory quota is per experience.
- **Right:** MemoryStore for matchmaking, queues, cross-server locks and short-lived leaderboards; DataStore for anything durable. See [[MemoryStore Service]].

## Common mistakes

- Defaults written over real data after a failed load.
- `UpdateAsync` callbacks that yield or fire events.
- Saving on every coin change instead of a dirty flag plus interval.
- A receipt handler that grants before saving.
- Odds text written by hand separately from the roll table.

## Checklist

- [ ] All read-modify-write paths use `UpdateAsync` or a session-locked profile.
- [ ] Failed load blocks saving.
- [ ] `ProcessReceipt` is single, idempotent on `PurchaseId`, and saves before `PurchaseGranted`.
- [ ] Prices displayed from `GetProductInfoAsync`.
- [ ] Paid random items show numeric odds generated from the roll config.
- [ ] Shutdown saves run in parallel within 30 s.

## See also

- [[What AI Models Get Wrong in Roblox]]
- [[Data and Cloud Changes 2025-2026]]
- [[DataStore Fundamentals]]
- [[Saving Correctly - Autosave and BindToClose]]
- [[Economy Exploits - Dupes Races and Purchase Abuse]]
- [[Trading Systems Without Duplication]]
- [[Paid Random Items and Odds Disclosure in Practice]]

<!-- related:start -->
## Related
[[Cookbook - Data and Saving]] · [[LihFolk Systems - Data and Purchase Guarantees]] · [[Shop with Game Passes and Developer Products End to End]] · [[Session Lock]] · [[Idempotency]] · [[AI Pitfalls - Stale APIs and Luau]]
<!-- related:end -->
