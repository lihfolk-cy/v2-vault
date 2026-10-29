---
tags: [qol, inventory, sort, filter, search, stacking, lock, favourite, server-authority, ui, type/guide, area/ui, area/gameplay, level/intermediate, api/RemoteEvent]
---
# Inventory QoL - Sort Filter Search Stack and Lock

<!-- tldr:start -->
> [!tldr] TL;DR
> - Items jump around on refresh: Comparator without tiebreak -> Unique id tiebreak
> - Search crashes on "[": Pattern search -> Plain `string.find`
> - Scroll resets after each sell: List rebuilt from scratch -> Preserve canvas position
> - Sort with stable tiebreak; filter chips; plain-text debounced search.
> - Scroll position preserved across changes.
> - Stackables stored as counts; uniques grouped.
>
> Cost: TL;DR ~140 tok · whole note ~2.0k tok. Read more: ## 2. Sorting and filtering without lag · ## 4. Lock and favourite · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Inventories grow. A player with 300 pets, 80 swords or 2,000 materials spends more time scrolling than playing unless the inventory has sort, filter, search, stacking and locks. This note covers which controls to offer, where each runs (client for viewing, server for anything that changes data), and how locking protects players from their own bulk actions. Rendering large lists is in [[Virtualized Lists and Large Inventories]]; the saved data model in [[Saved Inventory End to End]]; bulk sell and undo in [[Confirmation and Undo Patterns for Destructive and Paid Actions]].

Sources: **Rule of thumb** from shipped simulators and RPGs; Roblox APIs used are standard remotes and GUI (https://create.roblox.com/docs/reference/engine/classes/RemoteEvent).

## 1. The controls players expect

| Control | Where it runs | Saved? |
|---|---|---|
| Sort (rarity, power, newest, name, count) | Client | Sort choice saved as a setting |
| Filter (type, rarity, equipped, locked, tradable) | Client | Last filter optionally saved |
| Search by name | Client | No |
| Stack identical items | Server data model | Yes, it is the data shape |
| Lock / favourite | Server | Yes, per item |
| Equip best | Server (computes and applies) | Result saved |
| Bulk select | Client UI, server executes | Action result only |

Viewing is client-only and needs no remotes: the client already has a replicated copy of the inventory for display. Anything that changes ownership, equipment or locks goes through the server.

## 2. Sorting and filtering without lag

```lua
--!strict
export type Item = { id: string, kind: string, name: string, rarity: number, power: number, acquired: number, locked: boolean, count: number }

local SORTS: { [string]: (Item, Item) -> boolean } = {
	rarity = function(a, b)
		if a.rarity ~= b.rarity then return a.rarity > b.rarity end
		if a.power ~= b.power then return a.power > b.power end
		return a.id < b.id -- stable tiebreak so the order never jumps
	end,
	power = function(a, b)
		if a.power ~= b.power then return a.power > b.power end
		return a.id < b.id
	end,
	newest = function(a, b)
		if a.acquired ~= b.acquired then return a.acquired > b.acquired end
		return a.id < b.id
	end,
}

local function view(items: { Item }, sortKey: string, kind: string?, query: string?): { Item }
	local q = if query and #query > 0 then string.lower(query) else nil
	local out = table.create(#items)
	for _, item in items do
		if kind and item.kind ~= kind then continue end
		if q and not string.find(string.lower(item.name), q, 1, true) then continue end
		table.insert(out, item)
	end
	table.sort(out, SORTS[sortKey] or SORTS.rarity)
	return out
end
```

Points:
- **Always include a unique tiebreak** in comparators. Without one, `table.sort` can reorder equal items every refresh, and the item under the player's finger jumps. Also, an inconsistent comparator can error ("invalid order function for sorting").
- **Plain-text search**: pass `true` as the fourth argument to `string.find` so `[` or `%` typed by a player is not treated as a pattern.
- **Debounce search** input by about 0.15 s; re-filtering 2,000 items per keystroke on a phone is noticeable.
- **Keep the scroll position** when sorting or after selling an item; resetting to the top is a top inventory complaint.
- Locale: `string.lower` handles ASCII; names in other scripts may need different handling.

## 3. Auto-stack

Stack identical items into one entry with a count: materials, consumables, duplicate pets with no unique stats. Decide stackability per item kind in data, not in UI. Items with unique rolls (random stats, enchantments, serials) do not stack; show them grouped by base type with a collapsible header instead.

Server shape: `{ [itemKey] = count }` for stackables and `{ [uid] = itemRecord }` for uniques. This also makes saves smaller and trading simpler ([[Trading Systems Without Duplication]]).

## 4. Lock and favourite

Locked items cannot be sold, traded, deleted, fused or used as upgrade fodder by any bulk action. This is the single most valuable safety feature in an inventory (**Rule of thumb**).

```lua
--!strict
-- Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(script.Parent.PlayerData)
local lockRemote = ReplicatedStorage.Remotes.SetItemLocked :: RemoteEvent

lockRemote.OnServerEvent:Connect(function(player: Player, uid: any, locked: any)
	if typeof(uid) ~= "string" or #uid > 40 or typeof(locked) ~= "boolean" then return end
	local data = PlayerData.get(player)
	local item = data and data.items[uid]
	if item == nil then return end
	item.locked = locked
end)

-- Every destructive server path calls this.
local function isProtected(item: { locked: boolean?, equipped: boolean? }): boolean
	return item.locked == true or item.equipped == true
end
```

Rules:
- **Enforced on the server** in every destructive path (sell, trade offer, fuse, delete). A UI-only lock protects nothing when a second menu forgets to check.
- **Auto-lock** items above a rarity threshold on acquisition, with a setting to turn it off.
- **Equipped items behave as locked.**
- Lock icon visible in every list, including trade and fuse screens.

## 5. Equip best and quick actions

"Equip best" computes the best loadout on the server from server-known stats and applies it. The client can preview the result, but never sends the list of items to equip as authority beyond a request. Other quick actions: "Unequip all", "Sell all duplicates (except locked)", "Collapse groups".

## 6. Device notes

- Phones: large grid cells, filter chips instead of dropdowns, search field that does not cover the grid when the on-screen keyboard appears.
- Gamepad: bumpers switch tabs, a button toggles lock on the selected item, sort cycles with a face button. Selection must survive re-sorting.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Items jump around on refresh | Comparator without tiebreak | Unique id tiebreak |
| Search crashes on "[" | Pattern search | Plain `string.find` |
| Scroll resets after each sell | List rebuilt from scratch | Preserve canvas position |
| Locked item sold via another menu | Lock checked only in one UI | Server check in every destructive path |
| Inventory save too large | Stackables stored as unique records | Counts for stackables |
| Phone stutters while typing | Filter per keystroke | Debounce, virtualised list |

## Checklist

- [ ] Sort with stable tiebreak; filter chips; plain-text debounced search.
- [ ] Scroll position preserved across changes.
- [ ] Stackables stored as counts; uniques grouped.
- [ ] Lock and favourite saved, enforced server-side everywhere, auto-lock rares.
- [ ] Equip best computed on the server.
- [ ] Gamepad and phone layouts tested with hundreds of items.

## See also

- [[Virtualized Lists and Large Inventories]]
- [[Saved Inventory End to End]]
- [[Tools and Inventory Systems]]
- [[Economy Exploits - Dupes Races and Purchase Abuse]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Confirmation and Undo Patterns for Destructive and Paid Actions]] · [[Trading Systems Without Duplication]] · [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Top 25 QoL Wins by Effort]] · [[QoL Audit Checklist]] · [[Settings Menu Essentials and Persistence]] · [[Quick Respawn and Spawn Protection]] · [[Feedback - Autosave Indicator Ping Display and Error Toasts]] · [[Mobile Button Layout Editor]] · [[Notification Queues and Limits]] · [[Purchase Receipts and Purchase History in UI]]
<!-- related:end -->
