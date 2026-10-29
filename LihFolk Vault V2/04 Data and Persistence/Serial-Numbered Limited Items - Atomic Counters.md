---
tags: [data, datastores, limited-items, serials, atomic, updateasync, idempotency, economy, dupes, type/guide, area/data, level/advanced, api/DataStoreService, api/MemoryStoreService]
---
# Serial-Numbered Limited Items - Atomic Counters

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `GetAsync` then `SetAsync` for the counter -> `UpdateAsync` transform
> - Avoid: MemoryStore as the counter -> DataStore authority; MemoryStore mirror only
> - Avoid: No idempotency id -> `PurchaseId` or deterministic mint id
> - Counter in a DataStore key updated only with `UpdateAsync`; supply enforced inside the transform.
> - Every mint has a stable idempotency id; recent ids stored with the counter.
> - Serial record per serial with owner and history; inventory agrees.
>
> Cost: TL;DR ~160 tok · whole note ~2.2k tok. Read more: ## 3. Minting with idempotency · ## 4. After the serial: write the record, then the inventory · ## Common mistakes · ## Checklist
<!-- tldr:end -->

"Only 500 exist, and yours is #37" is one of the strongest value signals in Roblox economies. It is also a distributed systems problem: dozens of servers may sell or award the same limited item at the same moment, servers crash between steps, purchases retry, and trades move items between players. A correct implementation guarantees that **no serial is issued twice, supply is never exceeded, and every issued serial has exactly one owner**, and it can prove it later. This note covers the counter, minting with idempotency, ownership records, transfers and audits. It is about in-experience items stored in your DataStores, not Roblox UGC limiteds, whose serials are managed by the marketplace ([[UGC Pricing Limiteds and Marketplace Rules]]).

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. Why the counter must be a DataStore key

- `DataStore:UpdateAsync(key, transform)` reads and writes one key atomically with retries on conflict: if two servers update the same key concurrently, one transform re-runs on the new value (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync). That is exactly what a counter needs.
- `IncrementAsync` is also atomic, but it cannot enforce a supply cap or attach metadata in the same step.
- **MemoryStore is not the authority**: it is fast and has atomic operations, but it is not durable storage and entries expire ([[MemoryStore Service]]). Use it for a live "remaining" display, never to decide serials.

## 2. Data layout

| Store / key | Value | Purpose |
|---|---|---|
| `Limited` / `counter:<itemId>` | `{ issued = n, supply = S, mints = { [mintId] = serial } (recent window) }` | Atomic issuing, idempotency |
| `Limited` / `serial:<itemId>:<n>` | `{ owner = userId, mintedAt, mintId, history = {...} }` | Provenance record per serial |
| Player profile | `inventory.limiteds = { { item = id, serial = n } }` | What the player holds |

The serial record is the **ownership source of truth** for that serial; the player's profile is a cache that must agree with it. Audits compare the two.

## 3. Minting with idempotency

Every mint has a `mintId` that is stable across retries: for a Robux purchase, the `PurchaseId` from the receipt ([[Purchase Data and Receipts]]); for an in-game reward, a deterministic id such as `quest:<userId>:<questId>`. The counter transform checks the id first:

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("Limited")

type Counter = { issued: number, supply: number, mints: { [string]: number } }

local MINT_WINDOW = 200 -- keep recent mint ids for idempotency

local function claimSerial(itemId: string, mintId: string): (number?, string?)
	local serial: number? = nil
	local ok, err = pcall(function()
		store:UpdateAsync("counter:" .. itemId, function(old: Counter?): Counter?
			if not old then return nil end -- item must be created by a release script
			local existing = old.mints[mintId]
			if existing then
				serial = existing -- retry of a mint that already succeeded
				return nil -- no write needed
			end
			if old.issued >= old.supply then
				serial = nil
				return nil -- sold out: cancel the write
			end
			old.issued += 1
			old.mints[mintId] = old.issued
			-- trim the idempotency window (keeps the key small)
			local count = 0
			for _ in old.mints do count += 1 end
			if count > MINT_WINDOW then
				local lowest, lowestId = math.huge, nil
				for id, s in old.mints do
					if s < lowest then lowest, lowestId = s, id end
				end
				if lowestId then old.mints[lowestId] = nil end
			end
			serial = old.issued
			return old
		end)
	end)
	if not ok then return nil, tostring(err) end
	if not serial then return nil, "SoldOut" end
	return serial, nil
end
```

Important details:
- The transform can run **more than once**; set `serial` from the final run (it is, because the variable is overwritten each run). Do not cause side effects inside the transform (**Roblox docs**, UpdateAsync page).
- Returning `nil` cancels the write: used for sold-out and already-minted cases.
- A hot counter key has per-key write limits. For drops with heavy concurrency, queue mint requests per server and process sequentially, or shard supply across several counters (`counter:<item>:<shard>`, each with a slice of serial numbers) ([[DataStore Fundamentals]]).

## 4. After the serial: write the record, then the inventory

Order (each step idempotent):
1. `claimSerial` returns `n`.
2. `UpdateAsync("serial:<item>:<n>")`: create `{ owner, mintId, mintedAt }` if absent; if present with the same `mintId`, it is a retry, keep it; if present with a **different** mintId, that is a bug: alert and stop.
3. Add `{ item, serial = n }` to the player's session-locked profile and save ([[Session Locking and Profile Libraries]]).
4. For Robux purchases, return `PurchaseGranted` only after step 3 is saved, so a crash before that makes Roblox retry the receipt with the same `PurchaseId`, which flows through the same idempotent steps.

A crash between steps 1 and 3 leaves a serial claimed but not yet in inventory; the retry completes it. Without a retry (an in-game reward where the server died), a periodic **reconciliation job** finds serial records whose owner's profile lacks the item and repairs it.

## 5. Transfers and trades

- Trades move a serial between profiles **and** update the serial record's owner and history in the same trade transaction flow ([[Trading Systems Without Duplication]]).
- The serial record update uses `UpdateAsync` with a precondition: `old.owner == fromUserId`. If not, abort the trade; someone is attempting a dupe or the data is stale.
- Burning (crafting, deleting) marks the record `burned = true` and keeps it, so serials are never reissued and total supply history stays honest.

## 6. Display and audits

- Show "#37 / 500" from the inventory entry; show "remaining" from a cached counter read (or a MemoryStore mirror updated after each mint), refreshed every few seconds.
- **Audit job** (offline, via Open Cloud or a dev command, [[Open Cloud APIs]]): for each item, iterate serial records 1..issued, check exactly one owner per serial, no gaps (gaps mean a claimed but unrecorded serial), and that each owner's profile contains it. Log mismatches; never auto-delete.
- Keep the release script (creating `counter:<item>` with `supply`) separate from gameplay code and admin-only ([[Admin Commands Done Safely - Permissions and Audit Logs]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| `GetAsync` then `SetAsync` for the counter | Duplicate serials under load | `UpdateAsync` transform |
| MemoryStore as the counter | Lost or repeated serials after expiry | DataStore authority; MemoryStore mirror only |
| No idempotency id | Receipt retries mint twice | `PurchaseId` or deterministic mint id |
| Side effects inside the transform | Double grants on transform re-run | Pure transform; act after it returns |
| Inventory written before the serial record | Orphan items with no provenance | Counter, record, inventory, then grant |
| Reissuing burned serials | Supply count lies | Mark burned, never reuse |

## Checklist
- [ ] Counter in a DataStore key updated only with `UpdateAsync`; supply enforced inside the transform.
- [ ] Every mint has a stable idempotency id; recent ids stored with the counter.
- [ ] Serial record per serial with owner and history; inventory agrees.
- [ ] Receipts granted only after the profile is saved.
- [ ] Trades check the record's current owner; burns never free serials.
- [ ] Reconciliation and audit jobs exist and are run after each drop.

## See also
[[Trading Systems Without Duplication]] · [[Purchase Data and Receipts]] · [[Economy Exploits - Dupes Races and Purchase Abuse]] · [[DataStore Fundamentals]] · [[Session Locking and Profile Libraries]] · [[Limited-Time Offers - Design and Ethics]]

## Connected notes
<!-- auto-links:start -->
[[Data Loss Prevention and Recovery]] · [[MemoryStore Service]] · [[LihFolk Systems - Data and Purchase Guarantees]] · Rarity Ladders and Drop Pacing Math
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Idempotency]] · [[AI Pitfalls - Data and Monetization]] · [[OrderedDataStores and Leaderboards]] · [[Global State and Live Config]] · [[Data Schema Design and Migrations]] · [[Saving Correctly - Autosave and BindToClose]] · [[Schema Migrations - Worked Case Studies]] · [[Player Privacy and Data Deletion]]
<!-- related:end -->
