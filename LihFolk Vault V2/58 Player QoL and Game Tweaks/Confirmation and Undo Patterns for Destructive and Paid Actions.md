---
tags: [qol, confirmation, undo, bulk-sell, destructive-actions, purchases, dark-patterns, server-authority, type/guide, area/ui, area/monetization, level/intermediate, api/MarketplaceService]
---
# Confirmation and Undo Patterns for Destructive and Paid Actions

<!-- tldr:start -->
> [!tldr] TL;DR
> - Players confirm without reading: Confirms on everything -> Tiered friction; undo for cheap actions
> - "Sell, buy, undo" dupes coins: Undo ignores spent proceeds -> Refuse undo when balance is short
> - Undo restores wrong stats: Restores by item type -> Keep exact records for the window
> - Each destructive action assigned a tier.
> - Confirms state numbers, show the most valuable loss, use verbs.
> - Server undo window for sells; latest only; refused if proceeds spent.
>
> Cost: TL;DR ~160 tok · whole note ~2.0k tok. Read more: ## 1. Friction by damage · ## 3. Server-side undo window for sells · ## Common mistakes · ## Checklist
<!-- tldr:end -->

"I sold my best pet by accident" is a support ticket you can design away. Destructive actions (sell, delete, fuse, rebirth, reset) and spending actions need friction proportional to the damage, and where possible an undo. But confirmations on everything train players to click through, so they stop working. This note gives a tiered model, a server-side undo window for sells, bulk-sell rules and what Roblox's own purchase prompt already covers. Inventory locks are in [[Inventory QoL - Sort Filter Search Stack and Lock]]; purchase handling in [[Developer Products and ProcessReceipt]].

Sources: **Roblox docs** for `MarketplaceService` prompts (https://create.roblox.com/docs/reference/engine/classes/MarketplaceService); the Roblox purchase modal is shown by the platform for every Robux purchase. Tiering is **Rule of thumb**.

## 1. Friction by damage

| Tier | Example | Pattern |
|---|---|---|
| 0: trivial, reversible | Equip, sort, toggle | No confirm |
| 1: cheap, reversible | Sell a common item | No confirm; **undo toast** for a few seconds |
| 2: valuable or bulk | Sell 40 items, sell an epic, spend 50% of currency | Confirm dialog showing exactly what goes |
| 3: irreversible and large | Rebirth, delete a save slot, release a mythic | Confirm with summary **and** a deliberate gesture (hold 1.5 s or type the item name) |
| Robux purchase | Any developer product or pass | Roblox's purchase prompt is the confirm; do not add a second |

Undo beats confirm when possible: it keeps flow fast and fixes the mistake after it happens, which is when players notice it.

## 2. Confirm dialogs that people read

- **State the consequence with numbers**: "Sell 37 items for 12,400 coins? 2 Epic, 35 Common. Locked items are kept."
- **Show the most valuable thing being lost**, with its icon.
- **Verb on the button**, not "OK": "Sell 37", "Rebirth".
- **Default focus on Cancel** for tier 3 (gamepad players press A by habit).
- **Different screen position** from the previous button, so a double-tap cannot confirm.
- **No confirm spam**: if a player confirms the same tier-2 action three times in a row, offer "Don't ask again this session" for that action only.

## 3. Server-side undo window for sells

Undo must be real: the server keeps the sold items for a short window and can restore them exactly, including unique stats.

```lua
--!strict
-- ServerScriptService/SellService (excerpt)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(script.Parent.PlayerData)
local Pricing = require(script.Parent.Pricing)

local sellRemote = ReplicatedStorage.Remotes.SellItems :: RemoteFunction
local undoRemote = ReplicatedStorage.Remotes.UndoSell :: RemoteFunction

local UNDO_WINDOW = 8
type Pending = { items: { [string]: any }, coins: number, at: number, token: string }
local pending: { [Player]: Pending } = {}

sellRemote.OnServerInvoke = function(player: Player, uids: any): (boolean, string?)
	if typeof(uids) ~= "table" or #uids == 0 or #uids > 200 then return false, nil end
	local data = PlayerData.get(player)
	if data == nil then return false, nil end
	local removed: { [string]: any } = {}
	local coins = 0
	for _, uid in uids do
		local item = typeof(uid) == "string" and data.items[uid]
		if item and not item.locked and not item.equipped and removed[uid] == nil then
			removed[uid] = item
			coins += Pricing.sellValue(item)
		end
	end
	if next(removed) == nil then return false, nil end
	for uid in removed do data.items[uid] = nil end
	data.coins += coins
	local token = game:GetService("HttpService"):GenerateGUID(false)
	pending[player] = { items = removed, coins = coins, at = os.clock(), token = token }
	return true, token
end

undoRemote.OnServerInvoke = function(player: Player, token: any): boolean
	local p = pending[player]
	if p == nil or p.token ~= token or os.clock() - p.at > UNDO_WINDOW then return false end
	local data = PlayerData.get(player)
	if data == nil or data.coins < p.coins then return false end -- already spent the proceeds
	data.coins -= p.coins
	for uid, item in p.items do data.items[uid] = item end
	pending[player] = nil
	return true
end

game:GetService("Players").PlayerRemoving:Connect(function(player) pending[player] = nil end)
```

Design choices that matter:
- **Only the latest sell is undoable**, and only within the window. Older undo stacks create dupe risks.
- **Refuse undo if the proceeds were spent.** Otherwise "sell, buy, undo" duplicates value. This is the key anti-dupe rule ([[Economy Exploits - Dupes Races and Purchase Abuse]]).
- **The save does not wait for the window**: the sell is committed immediately; undo is a new, reversing transaction. A crash during the window simply means no undo, never a dupe.
- **Undo is not available for trades**, since another player now owns the item.

A "buyback" shop tab (sold items purchasable back at the sale price for the session) is a gentler alternative for RPG-style games.

## 4. Bulk sell rules

- **Never include locked or equipped items**, and say so in the dialog.
- **Preview list** of what will be sold, grouped by rarity, before confirming.
- **Rarity ceiling**: bulk "sell all" defaults to common and uncommon; higher rarities need explicit selection.
- **Cap per request** (200 above) to bound server work; the UI splits larger batches.

## 5. Paid actions

- Roblox shows its own purchase modal for every Robux transaction (**Roblox docs**); adding your own "Are you sure?" before it doubles friction and is unnecessary.
- **In-game currency spends** follow the tier table: big spends get a confirm with the before/after balance.
- **No disguised spends**: a button that spends premium currency must look different from one that spends soft currency, and show the price on the button.
- **No pressure tactics** in confirms (countdown timers, "only 1 left" when false). See [[Policy and Age Rules 2026]] and [[Paid Random Items and Odds Disclosure in Practice]].
- **Rebirth/prestige**: list exactly what resets and what is kept ([[Rebirth and Prestige System End to End]]).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Players confirm without reading | Confirms on everything | Tiered friction; undo for cheap actions |
| "Sell, buy, undo" dupes coins | Undo ignores spent proceeds | Refuse undo when balance is short |
| Undo restores wrong stats | Restores by item type | Keep exact records for the window |
| Best pet sold in bulk | Bulk includes rares | Rarity ceiling and locks |
| Double-tap confirms | Confirm button where the trigger was | Move the confirm; Cancel default for tier 3 |
| Double confirm on Robux | Custom dialog before Roblox prompt | Rely on the platform prompt |

## Checklist

- [ ] Each destructive action assigned a tier.
- [ ] Confirms state numbers, show the most valuable loss, use verbs.
- [ ] Server undo window for sells; latest only; refused if proceeds spent.
- [ ] Bulk sell excludes locked, equipped and rares by default; capped.
- [ ] No extra confirm before Roblox purchase prompts; no pressure tactics.

## See also

- [[Inventory QoL - Sort Filter Search Stack and Lock]]
- [[Developer Products and ProcessReceipt]]
- [[Refunds Chargebacks and Purchase Support]]
- [[Purchase Receipts and Purchase History in UI]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Economy Exploits - Dupes Races and Purchase Abuse]] · Trading Systems Without Duplication · Server Authority and Validation
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[Feedback - Autosave Indicator Ping Display and Error Toasts]] · [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]] · [[Quick Respawn and Spawn Protection]] · [[Notification Queues and Limits]] · [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]] · [[Loading Screen Skip and First-Session Goals]]
<!-- related:end -->
