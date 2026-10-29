---
tags: [data, trading, duplication, transactions, security, economy, luau, type/guide, area/data, level/intermediate, api/UpdateAsync, area/security]
---
# Trading Systems Without Duplication

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Client sends the offer list at confirm -> Server-owned offers, intents only
> - Avoid: No version counter -> Version on every edit; ready and confirm carry it
> - Avoid: Trade lock not checked by fusion or sell -> One inventory consume function checks the lock
> - Scope chosen; premium currency not tradeable.
> - Server-owned offers; edits bump a version; ready and confirm carry it.
> - Countdown before confirm; any edit cancels it.
>
> Cost: TL;DR ~150 tok · whole note ~5.3k tok. Read more: ## 3. The state machine and the server-owned offer · ## 5. Committing across two profiles · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Player-to-player trading is the feature most likely to destroy an economy. A single duplication bug turns your rarest item into the most common one in a weekend, and every trade after that spreads the copies. The cause is almost never exotic: a trade changes **two** player profiles, Roblox data stores have no multi-key transaction, and the gap between "player A saved" and "player B saved" is where items are born or lost.

This note builds a same-server trade system that is correct under crashes, disconnects, exploit clients and rolling updates. It covers the state machine, the commit protocol (a small write-ahead journal with a single decision record), anti-scam UI rules, policy gates, and how to find duplicates that already exist.

Prerequisites: [[Session Locking and Profile Libraries]], [[Server Authority and Validation]], [[DataStore Fundamentals]].

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. Where duplicates actually come from

| Cause | Mechanism | Prevention (section) |
|---|---|---|
| Yield between check and mutation | Two requests both see the item, both move it | Plan, then apply without yielding (4) |
| Client-authored offer contents | Exploit sends an item it does not own or a changed list at confirm time | Server owns the offer; version counter (3) |
| Item referenced by array index | Removing one item shifts indices; the wrong item moves | Stable Uids ([[Data Schema Design and Migrations]]) |
| Item used elsewhere during the trade | Sold, fused, salvaged or equipped-and-consumed while offered | Trade lock flag checked by every consumer (3) |
| Partial save after commit | A saved, B not: B's items now exist in both profiles | Journal plus decision record (5) |
| No session lock | Player rejoins another server that loads a stale profile and saves over the traded state | Session-locked profiles, required |
| Cross-server trades | Two servers each own one side; no shared lock | Do not, or use a mailbox (7) |
| Rollback of a release | Old code rebuilds items from a template, losing fields such as `TradedAt` | Preserve unknown fields ([[Schema Migrations - Worked Case Studies]]) |

The first four are logic bugs and are fully preventable. The fifth is a distributed systems problem; it is rare (it needs a server crash or shutdown in a window of a second or two), but at scale rare happens daily, and exploiters actively try to cause it by crashing their own client or the server at the right moment.

---

## 2. Decide the scope first

Every extra capability multiplies the bug surface. Rule of thumb ladder, from safest to riskiest:

1. **No trading.** Gifting from the shop only (Robux purchases for another player). Many games never need more.
2. **Same-server, both online, item-for-item.** This note's design.
3. **Same-server, items plus soft currency.** Adds balance checks; still fine.
4. **Asynchronous offers / mailboxes** (send to an offline player). Needs an escrow store and the full journal.
5. **Cross-server marketplace with listings and bids.** A real exchange. Needs MemoryStore or an external service, rate limits, price history, fraud tooling. Only with a team that can run it.

**Premium currency should not be tradeable** in almost every game. It turns your game into a Robux-to-item exchange, invites real-money trading of accounts and items (against the Roblox Terms of Use, and a scam magnet), and it bypasses regional pricing (see section 6).

**Measured in the reference project:** trading was same-server, item-for-item, gated behind requirements (500 rolls and 2 rebirths after one tuning pass), with a rules page shown in the trade lobby. Rolled items and purchased exclusives were tradeable; owner-only test items were refused by the trade service.

---

## 3. The state machine and the server-owned offer

The client never sends "my offer is these items". It sends small intents ("add Uid X", "remove Uid X", "ready", "confirm"), and the server keeps the offer.

```
Invited -> Open -> (both Ready) -> Countdown -> (both Confirm) -> Committing -> Done
   any state before Committing -> Cancelled (leave, decline, timeout, edit after ready)
```

Rules that matter:

- **Any change resets readiness.** Every edit increments `Version`. "Ready" and "Confirm" carry the version the client saw; a mismatch is refused. This kills the classic scam where an item is swapped out a frame before the other player clicks confirm.
- **Countdown between ready and confirm.** Rule of thumb: 3 to 5 seconds, during which the confirm button is disabled and the UI shows the final contents. Any edit cancels it.
- **Trade lock on offered items.** When a Uid is added to an offer, set a flag the rest of the game respects. The reference project used a `TradeBusy` flag that its fusion, salvage and auto-salvage code refused to consume (measured). Do not rely on remembering to check: route every "consume item" path through one inventory function that checks the lock.
- **One trade per player.** A player in a trade cannot accept another invite.
- **Timeouts.** Cancel idle trades after a few minutes; cancel on `PlayerRemoving` of either side before commit.

```lua
--!strict
export type Side = { UserId: number, Uids: { string }, Ready: boolean, Confirmed: boolean }
export type Trade = {
	Id: string,
	A: Side,
	B: Side,
	Version: number,
	State: "Open" | "Countdown" | "Committing" | "Done" | "Cancelled",
	CountdownEnds: number?,
}

local MAX_ITEMS_PER_SIDE = 8

-- Called from the remote handler after rate limiting and type checks.
local function addItem(trade: Trade, side: Side, profile: any, uid: string): (boolean, string?)
	if trade.State ~= "Open" and trade.State ~= "Countdown" then
		return false, "locked"
	end
	if #side.Uids >= MAX_ITEMS_PER_SIDE then
		return false, "full"
	end
	local item = Inventory.find(profile, uid) -- O(1) lookup by Uid
	if not item then
		return false, "not owned"
	end
	if not Inventory.isTradeable(profile, item) then -- equipped, locked, bound, dev-only, paid policy
		return false, "untradeable"
	end
	if item.TradeBusy then
		return false, "busy"
	end
	item.TradeBusy = trade.Id
	table.insert(side.Uids, uid)
	-- Any edit invalidates both sides' readiness and any running countdown.
	trade.Version += 1
	trade.A.Ready, trade.B.Ready = false, false
	trade.A.Confirmed, trade.B.Confirmed = false, false
	trade.State = "Open"
	trade.CountdownEnds = nil
	return true
end
```

`TradeBusy` holds the trade id rather than `true` so a crash-recovered profile can clear stale locks: on load, any `TradeBusy` whose trade is not in progress on this server is cleared.

---

## 4. Plan, then apply, without yielding

At commit the server re-validates everything from the profiles (not from the offer), builds a plan, and applies it in one non-yielding block. Validation and mutation must not be separated by any `task.wait`, data store call, or remote invoke: Luau is single-threaded per server only between yields ([[Task Library Coroutines and Yielding]]).

```lua
--!strict
type Plan = { fromA: { any }, fromB: { any } }

local function buildPlan(trade: Trade, pa: any, pb: any): Plan?
	local plan: Plan = { fromA = {}, fromB = {} }
	for _, uid in trade.A.Uids do
		local it = Inventory.find(pa, uid)
		if not it or it.TradeBusy ~= trade.Id then return nil end
		table.insert(plan.fromA, it)
	end
	for _, uid in trade.B.Uids do
		local it = Inventory.find(pb, uid)
		if not it or it.TradeBusy ~= trade.Id then return nil end
		table.insert(plan.fromB, it)
	end
	-- Capacity after the swap, not before.
	if Inventory.count(pa) - #plan.fromA + #plan.fromB > Inventory.cap(pa) then return nil end
	if Inventory.count(pb) - #plan.fromB + #plan.fromA > Inventory.cap(pb) then return nil end
	return plan
end

local function applyPlan(trade: Trade, pa: any, pb: any, plan: Plan)
	-- No yields in here.
	for _, it in plan.fromA do
		Inventory.remove(pa, it.Uid)
	end
	for _, it in plan.fromB do
		Inventory.remove(pb, it.Uid)
	end
	for _, it in plan.fromA do
		it.TradeBusy = nil
		it.TradedAt = os.time()
		Inventory.insert(pb, it) -- same Uid moves with the item
	end
	for _, it in plan.fromB do
		it.TradeBusy = nil
		it.TradedAt = os.time()
		Inventory.insert(pa, it)
	end
	Recent.push(pa, "Trades", trade.Id, 50) -- bounded list of applied trade ids
	Recent.push(pb, "Trades", trade.Id, 50)
end
```

Keeping the **same Uid** when an item changes owner is deliberate: it makes cross-profile duplicates detectable (section 8). If you mint a new Uid on transfer you lose that.

---

## 5. Committing across two profiles

Both profiles are session-locked by this server (both players are here). After `applyPlan`, both must be saved. The question is what happens if only one save lands.

| Saved | Effect without protection |
|---|---|
| Neither | Trade never happened. Fine |
| Both | Fine |
| A only | A lost its items and has B's; B still has its own items: **B's items now exist twice** |
| B only | Mirror image: A's items duplicated |

Saving immediately (not waiting for autosave) shrinks the window but does not close it. A server shutdown, a crash, or a data store throttle between the two writes reopens it. The fix is a **decision record**: one data store key per trade, written with a single `UpdateAsync`, that says "this trade is committed". A single-key write is atomic, so there is exactly one moment at which the trade becomes real, and both profiles can be repaired towards it.

The protocol:

1. **Hint.** Add the trade id to a small `PendingTrades` list in **both** profiles, then save both. If either save fails, cancel the trade (nothing has moved yet; clearing the hints later is harmless).
2. **Decide.** `UpdateAsync` on `TradeLog/<tradeId>`: if absent, write `{ S = "C", A = userIdA, B = userIdB, fromA = {...items}, fromB = {...items}, t = os.time() }`. This record contains full item records, so it can rebuild either side.
3. **Apply** the plan in memory (section 4) and save both profiles immediately.
4. **Close.** Remove the trade id from both `PendingTrades`, set the record to `S = "D"` (best effort).

Recovery runs on every profile load:

```lua
--!strict
-- After the profile is loaded and migrated, before gameplay sees it.
local TradeLog = game:GetService("DataStoreService"):GetDataStore("TradeLog_v1")

local function recoverTrades(userId: number, profile: any): boolean
	local pending: { string } = profile.PendingTrades or {}
	local remaining = {}
	for _, tradeId in pending do
		if Recent.has(profile, "Trades", tradeId) then
			continue -- already applied here; the hint is stale
		end
		local ok, rec = pcall(TradeLog.GetAsync, TradeLog, tradeId)
		if not ok then
			table.insert(remaining, tradeId) -- unknown: keep the hint and keep the items locked
			continue
		end
		if rec == nil then
			Inventory.clearTradeLocks(profile, tradeId) -- never decided: the trade did not happen
			continue
		end
		-- Committed: roll this side forward (idempotent, keyed by Uid and tradeId).
		local give = if rec.A == userId then rec.fromA else rec.fromB
		local get = if rec.A == userId then rec.fromB else rec.fromA
		for _, it in give do
			Inventory.remove(profile, it.Uid) -- no-op if already gone
		end
		for _, it in get do
			if not Inventory.find(profile, it.Uid) then
				local copy = table.clone(it)
				copy.TradeBusy = nil
				Inventory.insert(profile, copy)
			end
		end
		Recent.push(profile, "Trades", tradeId, 50)
	end
	profile.PendingTrades = remaining
	return #remaining == 0
end
```

Why each step exists:

- **Hints before the decision.** A profile that crashed before saving the swap does not know it was in a trade unless something in its own data says so. The hint is that something. Hints are written while nothing has moved, so a failed hint write just cancels the trade.
- **The decision record is the only truth.** Neither profile decides; the record does. "Record absent" means the trade never committed, even if one profile somehow saved a swap (it cannot, because step 3 runs only after step 2 succeeded).
- **Roll forward, never back.** Once committed, recovery always completes the trade. Rolling back would need to know whether the other side already used the items.
- **Unknown stays locked.** If the log read fails, keep the items trade-locked and retry on the next load. Never guess.

**Cost** (rule of thumb arithmetic): two hint saves, one decision write, two profile saves, one close write, plus one log read per hinted trade on load. About six writes per trade. Against the per-server write budgets in [[DataStore Fundamentals]] that is fine for normal trade rates; a server where dozens of trades complete per minute should batch the close step into the next autosave.

**Throttling and the 4 second cache.** `GetAsync` can serve a cached value for a few seconds. Recovery normally runs on a different server minutes later, so the cache rarely matters, but if you build a "retry immediately" path, read the record with `UpdateAsync` (returning `nil` to avoid writing) instead of `GetAsync`.

**Retention.** Trade log records are cross-player personal data. Give them a TTL-like cleanup (delete records marked done after a few weeks, by an offline job) and cover them in your erasure handling ([[Player Privacy and Data Deletion]]).

---

## 6. Gates: policy, price levels and alt accounts

Three independent gates must all pass before an item can be offered.

**Paid item trading policy.** `PolicyService:GetPolicyInfoForPlayerAsync` returns `IsPaidItemTradingAllowed`; when false you must not let that user trade the outcome of a paid random item or other paid items (Roblox docs, as of October 2026). The PolicyService reference page itself lists fewer keys than the paid random items page; treat a missing key as "not allowed". Implementation: [[Roblox Policies Ratings and Compliance]]. This means **every item needs a provenance flag**: was it bought, rolled with paid currency, or earned free? Add `Paid = true` at grant time. You cannot reconstruct this later.

**Price levels.** Regional pricing creates arbitrage: buy cheaply in one region, trade to a player who would pay full price. Roblox docs give `MarketplaceService:GetUsersPriceLevelsAsync` and suggest allowing a trade of paid items only when both players' price levels match, and a gift only when the sender's level is greater than or equal to the recipient's (Roblox docs, as of October 2026). Implementing the check is a prerequisite for opting developer products into regional pricing. Code: [[Pricing and Store Design]].

**Alt-account farming.** Exploiters run many accounts to farm free rolls and funnel items to one main. Requirements before trading unlocks (measured in the reference project: 500 rolls and 2 rebirths) raise the cost of each mule. Rule of thumb additions: account age or playtime minimum, a daily cap on items received from accounts younger than N days, and logging of "many accounts trade to one receiver" patterns.

| Gate | Fails closed when unknown? |
|---|---|
| Paid item trading policy | Yes: unknown = not allowed |
| Price level match | Yes, for paid items |
| Requirements | Yes |
| Item provenance missing (old data) | Treat as paid until migrated |

---

## 7. Disconnects, teleports, shutdowns, and cross-server

- **Leave before commit**: cancel, clear locks, tell the other player.
- **Leave during commit**: the commit continues. Profiles stay in memory until saved; your profile module must not release a profile while a trade commit holds it. Make the release path wait for an in-progress commit (with a timeout that leaves the hints in place for recovery).
- **Teleport**: refuse teleports while in a trade, or cancel the trade first ([[Teleporting and Multi-Place Games]]).
- **Server shutdown**: `BindToClose` should cancel open trades and let committing ones finish within the shutdown budget ([[Saving Correctly - Autosave and BindToClose]]). Anything not finished is recovered by hints.
- **Cross-server**: two servers each hold one profile's lease; neither can mutate the other. If you need it, make it asynchronous: the giver's server moves items into an escrow record (single key, atomic), and the receiver's server claims from escrow on load. That is a mailbox, not a trade, and the UI should say so.

---

## 8. Finding duplicates that already exist

Even with all of the above, run detection. Bugs you have not found yet exist.

- **Uid uniqueness across profiles.** Because Uids move with items, a Uid present in two profiles is a duplicate (or a support re-grant that reused a Uid: make your admin tool always mint fresh ones). An offline job over exported profiles ([[Open Cloud APIs]]) builds `Uid -> owners` and reports collisions.
- **Supply curves.** Count copies of each rare item per day. Supply of an item that can only be rolled should track rolls times odds ([[Economy Inflation Sinks and Faucets Math]]). A step change with no matching change in rolls is a dupe.
- **Trade graph anomalies.** One receiver with many young senders; the same item bouncing between two accounts many times.

What to do when you find copies is policy: removing a duplicated item from the player who traded for it in good faith punishes the wrong person. A common approach is to remove copies from the accounts that created them, mark the rest untradeable, and compensate innocent receivers. Document it in [[Refunds Chargebacks and Purchase Support]].

---

## 9. UI rules that prevent scams

Scams are not duplication, but they generate more support tickets than dupes do.

- Both offers visible at all times, with rarity and key stats; never truncate the other side's list.
- Highlight what changed since the last ready (a brief flash on the changed tile).
- Show a value hint only if you have a trustworthy one; a fake "fair trade" meter is worse than none.
- Confirm button disabled during the countdown, labelled with the seconds left.
- After the trade, a receipt toast listing what moved, and a trade history page (last 20 trades) the player can show support.
- Chat during trades goes through `TextChatService` like any other text ([[Age Checks and Safety Features]]).

---

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Client sends the offer list at confirm | Items appear that the player never owned | Server-owned offers, intents only |
| No version counter | "They swapped the item at the last second" tickets | Version on every edit; ready and confirm carry it |
| Trade lock not checked by fusion or sell | Item consumed while offered, then also delivered | One inventory consume function checks the lock |
| Save both profiles "soon" via autosave | Rare dupes after server crashes | Hints, decision record, immediate saves |
| New Uid minted on transfer | Cannot detect cross-profile copies | Keep Uids |
| Treat unknown policy as allowed | Compliance failure | Fail closed |
| Premium currency tradeable | Real-money trading, regional arbitrage | Do not |
| Cross-server "trades" with two leases | Unfixable dupes | Mailbox with escrow |

## Checklist

- [ ] Scope chosen; premium currency not tradeable.
- [ ] Server-owned offers; edits bump a version; ready and confirm carry it.
- [ ] Countdown before confirm; any edit cancels it.
- [ ] Trade lock set on offer, respected by every consumer, cleared on recovery.
- [ ] Re-validate from profiles and apply in one non-yielding block.
- [ ] Hint, decide, apply, close; recovery on every load; unknown stays locked.
- [ ] Uids preserved across owners; admin tools mint fresh Uids.
- [ ] Policy, price level and requirement gates, all failing closed.
- [ ] Provenance (`Paid`) recorded at grant time.
- [ ] Trade history visible to the player; logs bounded and covered by erasure.
- [ ] Offline duplicate scan and supply-curve alert.

## See also
[[Session Locking and Profile Libraries]] · [[Server Authority and Validation]] · [[Exploits and Anti-Cheat]] · [[Rate Limiting and Abuse Prevention]] · [[Tools and Inventory Systems]] · [[Economies and Currencies]] · [[Roblox Policies Ratings and Compliance]] · [[Pricing and Store Design]] · [[Schema Migrations - Worked Case Studies]] · [[Economy Inflation Sinks and Faucets Math]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Social Design and Multiplayer Play]]

## Connected notes
<!-- auto-links:start -->
[[Player-Driven Trading Economies]] · Economy Exploits - Dupes Races and Purchase Abuse · Economy Design Start Here · Skill - Roblox DataStore Safety · Session Lock · Developer Products and ProcessReceipt
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Economy Exploits - Dupes Races and Purchase Abuse]] · [[Serial-Numbered Limited Items - Atomic Counters]] · [[Purchase Data and Receipts]] · [[Developer Products and ProcessReceipt]] · [[Data Loss Prevention and Recovery]] · [[Global State and Live Config]] · [[OrderedDataStores and Leaderboards]]
<!-- related:end -->
