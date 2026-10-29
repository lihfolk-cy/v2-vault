---
tags: [qol, purchases, receipts, processreceipt, purchase-history, developer-products, game-passes, support, trust, type/guide, area/monetization, level/intermediate, api/MarketplaceService, api/ProcessReceipt]
---
# Purchase Receipts and Purchase History in UI

<!-- tldr:start -->
> [!tldr] TL;DR
> - "I paid and got nothing" tickets: No feedback until grant -> Processing state, then receipt
> - Item granted from the client event: Using `PromptProductPurchaseFinished` -> Grant only in `ProcessReceipt`
> - Paid item lost on crash: Acknowledged before save -> Save, then `PurchaseGranted`
> - Processing, granted and delayed UI states.
> - Grant and save in `ProcessReceipt`, then notify the client.
> - Receipt shows what, where, and a use button; no upsell.
>
> Cost: TL;DR ~160 tok · whole note ~2.1k tok. Read more: ## 1. Two signals, only one means "granted" · ## 2. Server: grant, record, then notify · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A player who spends Robux and sees nothing happen assumes they were scammed, files a support ticket, or asks a parent to dispute the charge. A clear in-game receipt after the grant, and a purchase history they can check later, prevents most of that. This note covers the receipt moment, the timing gotchas between Roblox's prompt and your grant, a capped history in the profile, and what to show when something is delayed. The grant itself (idempotent `ProcessReceipt`) is in [[Developer Products and ProcessReceipt]] and [[Purchase Data and Receipts]]; support flows in [[Refunds Chargebacks and Purchase Support]].

Sources: **Roblox docs** for `MarketplaceService.ProcessReceipt` and `PromptProductPurchaseFinished` (https://create.roblox.com/docs/reference/engine/classes/MarketplaceService) and the developer products guide (https://create.roblox.com/docs/production/monetization/developer-products). UX is **Rule of thumb**.

## 1. Two signals, only one means "granted"

- `PromptProductPurchaseFinished` (and the game pass equivalent) tells the client the prompt closed and whether the player bought. **It does not mean your game granted anything** (**Roblox docs** warn against using it to grant).
- `ProcessReceipt` on the server is where you grant, save, and return `PurchaseGranted`. That is the only moment you can honestly say "You got it".

So the UI has three states:

| State | Trigger | UI |
|---|---|---|
| Processing | Client prompt finished with purchased = true | "Processing your purchase…" spinner on the item |
| Granted | Server fires a receipt event after granting and saving | Receipt panel with what was received |
| Delayed | No grant within about 15 s | "Your purchase is being processed. It will arrive automatically, even if you rejoin." |

The delayed message is true because Roblox re-sends unacknowledged receipts (`ProcessReceipt` is called again later, including in another server) until you return `PurchaseGranted` (**Roblox docs**). Do not tell players to buy again.

## 2. Server: grant, record, then notify

```lua
--!strict
-- ServerScriptService/Purchases (excerpt)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(script.Parent.PlayerData)
local Products = require(script.Parent.Products) -- productId -> { name, grant(player, data) -> summary }

local receiptRemote = ReplicatedStorage.Remotes.PurchaseReceipt :: RemoteEvent
local HISTORY_MAX = 50

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if player == nil then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local data = PlayerData.get(player)
	if data == nil then return Enum.ProductPurchaseDecision.NotProcessedYet end

	if data.receipts[info.PurchaseId] == nil then
		local product = Products[info.ProductId]
		if product == nil then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local summary = product.grant(player, data) -- e.g. "500 Gems"
		data.receipts[info.PurchaseId] = true
		table.insert(data.history, 1, {
			id = info.PurchaseId, product = info.ProductId, name = product.name,
			summary = summary, robux = info.CurrencySpent, t = os.time(),
		})
		while #data.history > HISTORY_MAX do table.remove(data.history) end
		local saved = PlayerData.saveNow(player) -- must persist before acknowledging
		if not saved then return Enum.ProductPurchaseDecision.NotProcessedYet end
		receiptRemote:FireClient(player, data.history[1])
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

Notes:
- The `receipts` set (purchase id → true) is the idempotency guard. It grows forever if never pruned; keep a capped set of recent ids plus a high-water timestamp, as [[Purchase Data and Receipts]] describes, rather than storing every id ever.
- **Save before acknowledging.** Returning `PurchaseGranted` before the grant is persisted risks losing a paid item on a crash ([[LihFolk Systems - Data and Purchase Guarantees]]).
- `history` is separate from `receipts`: one is for the player to read, the other for correctness.

## 3. The receipt panel

What a good receipt shows (**Rule of thumb**):
- **What they got**, with icons and amounts ("500 Gems", "VIP pass: 2x coins, VIP chat tag").
- **Where it went** ("Added to your inventory", "Now active: ends in 30:00").
- **A button to use it** ("Equip now", "Open inventory").
- **No immediate upsell** in the same panel. A second offer seconds after purchase feels pushy; policy aside, it hurts trust ([[Policy and Age Rules 2026]]).

Game passes: the receipt appears once, the first time ownership is detected after purchase (`PromptGamePassPurchaseFinished` plus a server ownership check with `UserOwnsGamePassAsync`). Passes do not go through `ProcessReceipt`.

## 4. Purchase history page

Under Settings or Shop → "Purchase history":
- Date, item, what was granted, Robux spent.
- **"Didn't receive something?"** with steps: rejoin, wait, then contact support with the shown purchase id. Showing the id saves support time ([[Refunds Chargebacks and Purchase Support]]).
- Timed products: show remaining time and whether the timer runs offline.
- Do not show other players' purchases, and do not show the player's Robux balance (you cannot read it reliably and it is not your business).

## 5. Edge cases

- **Player left before the grant**: `ProcessReceipt` returns `NotProcessedYet`; Roblox retries later, possibly in another server. On join, if history has entries the player has not seen, show "While you were away: purchase delivered".
- **Gift purchases** (buying for another player): the receipt goes to the buyer; the recipient gets a separate "X sent you a gift" notice. Validate recipient presence before prompting.
- **Duplicate prompts**: disable the buy button while a prompt is open; `MarketplaceService` already shows a modal but rapid taps can queue confusion.
- **Studio test purchases**: are simulated and free; label your receipt "Test purchase" in Studio so testers do not mistake behaviour.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| "I paid and got nothing" tickets | No feedback until grant | Processing state, then receipt |
| Item granted from the client event | Using `PromptProductPurchaseFinished` | Grant only in `ProcessReceipt` |
| Paid item lost on crash | Acknowledged before save | Save, then `PurchaseGranted` |
| Players buy twice | Told "failed" when delayed | "Delayed, will arrive" message |
| Receipt set grows unbounded | Every id stored forever | Capped recent ids |
| Upsell in receipt | Aggressive monetisation | Receipt only; offers elsewhere |

## Checklist

- [ ] Processing, granted and delayed UI states.
- [ ] Grant and save in `ProcessReceipt`, then notify the client.
- [ ] Receipt shows what, where, and a use button; no upsell.
- [ ] Capped purchase history with purchase ids and a help path.
- [ ] Offline deliveries announced on next join.

## See also

- [[Developer Products and ProcessReceipt]]
- [[Shop with Game Passes and Developer Products End to End]]
- [[Monetization Overview]]
- [[Confirmation and Undo Patterns for Destructive and Paid Actions]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Purchase Data and Receipts]] · Refunds Chargebacks and Purchase Support · [[Feedback - Autosave Indicator Ping Display and Error Toasts]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Idempotency]] · [[AI Pitfalls - Data and Monetization]] · [[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[AFK Detection Idle Kicks and AFK Reward Rules]] · [[Joining Friends Parties and Private Servers]] · [[Skippable Tutorials and Replayable Tips]] · [[Loading Screen Skip and First-Session Goals]] · [[Inventory QoL - Sort Filter Search Stack and Lock]] · [[Block and Mute Respecting Platform Rules]]
<!-- related:end -->
