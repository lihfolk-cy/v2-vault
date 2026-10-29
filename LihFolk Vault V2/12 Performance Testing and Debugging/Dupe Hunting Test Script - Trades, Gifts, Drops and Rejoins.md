---
tags: [testing, qa, dupes, trading, economy, datastore, security, type/guide, area/testing, area/security, level/advanced, area/performance]
---
# Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Auditing memory only, not the saved data read back after the attack.
> - Avoid: Testing trades with one client and a dummy, so no real race ever happens.
> - Avoid: Running attack scripts in the live universe.
> - Conservation audit module covers every inventory and currency.
> - Each attack in section 2 run with two or more clients.
> - Each attack rerun with slow and failing store knobs.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## 1. The invariant you are testing · ## 2. Attack paths · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Economy Exploits - Dupes Races and Purchase Abuse]] explains how duplication happens and how to design against it. This note is the attack side: a repeatable script your team runs before every release that touches items, so a dupe is found by you in a test place rather than by a YouTuber in your live game. It combines a server-side **conservation audit** (item counts must balance) with a list of **scripted attack paths** run in Studio Server & Clients and on a private live server.

Labels: **Rule of thumb** unless stated. Never run attack scripts against the live production universe; use a test universe with its own DataStores.

---

## 1. The invariant you are testing

Every economic action must conserve value except where the design says it creates or destroys it. For non-fungible items with GUIDs ([[Trading Systems Without Duplication]]) the invariant is sharp:

- **No GUID exists in two inventories at once**, in memory or in saved data.
- **The total count of each fungible currency** changes only by logged sources (rewards, purchases) and sinks (shop, fees).

So the test harness needs one thing from your game: a way to enumerate every inventory, loaded and saved, and count. Build it as a server-only module that only exists in test builds or is gated ([[Gated Tester Commands and Debug Panels]]).

```lua
--!strict
-- ServerScriptService/QA/ConservationAudit (test builds only)
-- Assumes inventories are { [guid]: itemData } and currency is a number per profile.
local Audit = {}

export type Snapshot = { owners: { [string]: string }, dupes: { string }, currency: number }

function Audit.snapshot(profiles: { [string]: any }): Snapshot
	local owners: { [string]: string } = {}
	local dupes: { string } = {}
	local currency = 0
	for ownerKey, data in profiles do
		currency += tonumber(data.Coins) or 0
		for guid in data.Items or {} do
			local prev = owners[guid]
			if prev then
				table.insert(dupes, ("%s in %s and %s"):format(guid, prev, ownerKey))
			else
				owners[guid] = ownerKey
			end
		end
	end
	return { owners = owners, dupes = dupes, currency = currency }
end

-- Compare before/after an attack. expectedDelta is what the design allows (usually 0).
function Audit.check(before: Snapshot, after: Snapshot, expectedDelta: number): { string }
	local problems = table.clone(after.dupes)
	local delta = after.currency - before.currency
	if delta ~= expectedDelta then
		table.insert(problems, ("currency delta %d, expected %d"):format(delta, expectedDelta))
	end
	for guid in before.owners do
		if after.owners[guid] == nil then
			table.insert(problems, "item vanished: " .. guid) -- loss is a bug too
		end
	end
	return problems
end

return Audit
```

Feed `snapshot` with both the in-memory profiles of players in the server and the **saved** records read back from the test DataStore after the attack. A dupe that only exists in saved data (the classic rejoin dupe) is invisible to a memory-only audit.

---

## 2. Attack paths

Run each with at least two clients. For each: snapshot, attack, wait for saves, read saved data back, check.

### 2.1 Trades

| Attack | How to drive it |
|---|---|
| Accept spam | Client fires accept 50 times in one frame (`for i = 1, 50 do remote:FireServer(...) end` in a test LocalScript) |
| Change offer after accept | Add or remove an item between the other player's accept and the final confirm |
| Offer the same GUID in two trades | Open trades with two partners, offer one item to both, accept both together |
| Leave mid-trade | One client calls `LeaveTest()` (StudioTestService, Studio only) or kicks itself right after confirm |
| Trade then equip or sell | Sell or delete the offered item while the trade is pending |
| Trade during save | Trigger a manual save on both profiles while the commit runs |

### 2.2 Gifts and mail

- Gift to a player who is offline, then the gifter rejoins a different server and gifts again before the first gift is claimed.
- Claim a gift from two servers at once (two clients of the same test account are not possible, so simulate with two server scripts calling the claim function on the same key).
- Gift a currency amount that is negative, NaN, a huge number or a string ([[Server Authority and Validation]]).

### 2.3 World drops

- Two players touch a dropped item in the same frame.
- Drop an item and leave the server immediately; rejoin and check the inventory.
- Drop, then the server shuts down (`BindToClose` path) before anyone picks it up: the item should either return to the owner or be destroyed by design, never both kept and on the floor.

### 2.4 Rejoins and server hops

The highest-value tests, because they target session locking ([[Session Locking and Profile Libraries]]):

1. Give an item away (trade, gift, sell) and leave within one second.
2. Rejoin into a **different** server immediately.
3. Check whether the old server's save of the pre-trade state overwrote the new one.

Repeat with a forced server shutdown instead of a leave. Without a working session lock, this is where items double.

### 2.5 Purchases

- Fire `ProcessReceipt` twice for the same `PurchaseId` (call your handler directly in a test with a fake receipt table).
- Return `NotProcessedYet` on the first try (inject a save failure) and confirm the retry grants once ([[Purchase Data and Receipts]]).

---

## 3. Injecting failure

Most dupes need a failure at the wrong moment. If your data layer uses a store interface ([[Automated Testing with TestEZ and Jest-Lua]] shows a `FakeStore`), add switches:

```lua
-- FakeStore failure knobs used by dupe tests
store.failNextUpdate = true      -- next update throws, like a throttled request
store.delayUpdate = 3            -- seconds of artificial latency on update (test place only)
```

Then rerun every attack in section 2 with each knob on. A trade that is safe with a fast store and dupes with a slow one has a yield between validation and write.

---

## 4. Running it

- **Where:** a test universe with its own DataStores, Studio API access enabled for that universe only.
- **When:** every release that touches inventory, trading, gifting, drops, purchases or the save path.
- **How long:** about an hour for two testers with the harness (Rule of thumb).
- **Output:** a short report: attack, result, audit output. Any non-empty `check` result blocks the release.

Keep audit logs in production too ([[Logging Bans and Appeals]]): when a dupe slips through, logs are how you find and repair it.

---

## Common mistakes

- Auditing memory only, not the saved data read back after the attack.
- Testing trades with one client and a dummy, so no real race ever happens.
- Running attack scripts in the live universe.
- Testing only success paths; dupes live in failure and latency.
- Ignoring item loss. A vanished item is the same bug class as a duplicated one.
- Fixing a dupe and not adding its attack to this script.

## Checklist

- [ ] Conservation audit module covers every inventory and currency.
- [ ] Each attack in section 2 run with two or more clients.
- [ ] Each attack rerun with slow and failing store knobs.
- [ ] Saved data read back and audited after rejoin and shutdown attacks.
- [ ] Duplicate `PurchaseId` and retry paths tested.
- [ ] Results recorded; any dupe or loss blocks the release.

## See also

- [[Economy Exploits - Dupes Races and Purchase Abuse]], [[Trading Systems Without Duplication]]
- [[Session Locking and Profile Libraries]], [[Data Loss Prevention and Recovery]]
- [[Genre QA Passes - Test Checklists per Game Type]], [[UI Automation with VirtualInput and StudioTestService]]

## Connected notes

[[Player-Driven Trading Economies]] · Saving Correctly - Autosave and BindToClose · Logging Bans and Appeals · Server Authority and Validation

<!-- related:start -->
## Related
[[Save Migration Tests - Fixture Saves and Golden Files]] · [[Load and Soak Testing Servers - Long Sessions and Many Clients]] · [[Automated Luau Checks - LihFolk Hook and Audit]] · [[Testing Time-Based Features with a Controllable Clock]] · [[Multi-Client and Live Testing]] · [[In-Game Bug Report Button with Automatic Context]] · [[QA Checklists Before Release]] · [[Testing Strategies and Frameworks]]
<!-- related:end -->
