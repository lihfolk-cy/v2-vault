---
tags: [data, monetization, processreceipt, idempotency, purchases, receipts]
---
# Purchase Data and Receipts

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Returning `PurchaseGranted` before saving (Paid items lost on crash or failed save)
> - Avoid: Granting without checking `PurchaseId` (Double grants on retries and concurrent servers)
> - Avoid: Grant and id saved in different writes or keys (A crash keeps one without the other)
> - Exactly one `ProcessReceipt`, covering every product id.
> - Waits for the profile; refuses when it cannot save.
> - Grant and `PurchaseId` recorded together, synchronously, in the same key.
>
> Cost: TL;DR ~160 tok · whole note ~4.1k tok. Read more: ## The handler · ## Two-layer design for gifts (production lesson) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A developer product purchase is the one write in your game where a bug costs a player real money or costs you a refund dispute. The rules come from two places: the exact guarantees `MarketplaceService.ProcessReceipt` gives (and does not give), and the data store's failure modes. This note covers both, then gives a complete idempotent receipt handler built on a session-locked profile, the extra ledger needed for gifting, and the production lessons from one game that sold boosts, bundles, gifts and one-time packs. The monetization side (pricing, product design) lives in [[Developer Products and ProcessReceipt]] and [[Monetization Overview]]; this note is about getting the data right.

Prerequisites: [[Session Locking and Profile Libraries]], [[Saving Correctly - Autosave and BindToClose]].

## What ProcessReceipt guarantees (Roblox reference, October 2026)

- You set `MarketplaceService.ProcessReceipt` **once**, in one server `Script`, and it handles every product.
- It is called for **unresolved** purchases when a purchase completes, when a successful purchase prompt appears, and **when the user joins a server**.
- A purchase is **resolved** only when your callback returns `Enum.ProductPurchaseDecision.PurchaseGranted` **and** Roblox records that on its backend.
- **No time-based retry.** If you return `NotProcessedYet` (or error), the callback runs again only when the user starts another product purchase or rejoins any server of the experience.
- **No timeout.** The callback may yield as long as the server runs; a late result is still accepted.
- The user must be **in the server** for the callback to be invoked. They do not have to still be there when it returns.
- The callback for one purchase **can run on two servers at the same time**, if the user joins a second server before the first returns.
- Even after you return `PurchaseGranted`, recording can fail, and the purchase stays unresolved: **you will see the same `PurchaseId` again** later.
- Multiple pending purchases arrive in a non-deterministic order.
- Unresolved purchases are **not** removed or refunded when escrow expires.
- If you never set a callback, receipts are auto-acknowledged and cannot be recovered.

The `receiptInfo` table: `PurchaseId` (unique per purchase), `PlayerId`, `ProductId`, `PlaceIdWherePurchased`, `CurrencySpent`, `CurrencyType` (always Robux), and `ProductPurchaseChannel` (`InExperience`, `ExperienceDetailsPage`, `AdReward`, `CommerceProduct`).

Two consequences drive everything below:

1. **Grants must be idempotent by `PurchaseId`.** The same purchase can arrive twice (concurrently, or after a lost acknowledgment).
2. **Return `PurchaseGranted` only after the grant is durable.** If you grant in memory, return granted, and then the save fails, the player paid for something that vanishes at the next crash.

## Roblox's definition of "handled"

Roblox's player-data guide defines a handled purchase as: not previously handled, reflected in the current session, and **saved to a data store**. Its required order:

1. Verify the `PurchaseId` is not already recorded as handled.
2. Award the purchase in the in-memory player data.
3. Record the `PurchaseId` in the same in-memory data.
4. Save that data to the data store.
5. Return `PurchaseGranted` if the save succeeded, `NotProcessedYet` if not.

And the subtle case: if the id is recorded **in memory but not yet saved**, do not grant again; just try the save again and answer accordingly. Session locking is what makes this sound: with one owner per profile, the in-memory receipt list is the newest one that exists, so checking it is enough.

## The handler

```lua
--!strict
-- ServerScriptService/Monetization/ReceiptHandler (Script): the ONLY ProcessReceipt in the game
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Profiles = require(ServerScriptService.Data.Profiles)
local ProfileManager = require(ServerScriptService.Data.ProfileManager)

local MAX_RECEIPTS = 100 -- newest PurchaseIds kept in the profile

type Grant = (data: { [string]: any }) -> boolean -- must not yield; returns false if it cannot apply

-- Product id -> grant. Prices and ids live in config; these numbers are placeholders.
local GRANTS: { [number]: Grant } = {
	[0000000001] = function(data)
		data.Gems = (tonumber(data.Gems) or 0) + 500
		return true
	end,
	[0000000002] = function(data)
		-- once-per-player starter pack: refuse a second grant (the shop should never prompt it)
		data.Once = data.Once or {}
		if data.Once.StarterPack then
			return false
		end
		data.Once.StarterPack = true
		data.Coins = (tonumber(data.Coins) or 0) + 10000
		return true
	end,
}

local function hasReceipt(data: { [string]: any }, purchaseId: string): boolean
	local list = data.Receipts
	if type(list) ~= "table" then
		return false
	end
	for _, id in list do
		if id == purchaseId then
			return true
		end
	end
	return false
end

local function recordReceipt(data: { [string]: any }, purchaseId: string)
	local list = if type(data.Receipts) == "table" then data.Receipts else {}
	table.insert(list, purchaseId)
	while #list > MAX_RECEIPTS do
		table.remove(list, 1)
	end
	data.Receipts = list
end

local function saveNow(player: Player): boolean
	local profile = Profiles._get(player)
	if not profile or profile.State ~= "active" then
		return false
	end
	for _ = 1, 3 do
		local result = ProfileManager.save(profile, false)
		if result == "saved" then
			return true
		elseif result == "lost" then
			return false
		end
		task.wait(1 + math.random())
	end
	return false
end

MarketplaceService.ProcessReceipt = function(receipt): Enum.ProductPurchaseDecision
	local WAIT = Enum.ProductPurchaseDecision.NotProcessedYet
	local purchaseId = receipt.PurchaseId
	local grant = GRANTS[receipt.ProductId]
	if type(purchaseId) ~= "string" or not grant then
		warn(`[Receipts] unknown product {receipt.ProductId}`)
		return WAIT -- never acknowledge what we cannot deliver
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return WAIT
	end
	-- The player may have just joined: wait for their profile (it can also fail or lock).
	local status = Profiles.waitReady(player, 60)
	if status ~= "ready" or not Profiles.canMutate(player) then
		return WAIT
	end

	local applied = false
	local refused = false
	Profiles.mutate(player, function(data)
		if hasReceipt(data, purchaseId) then
			return -- already granted in this profile (saved or not): do not grant again
		end
		-- no yields between the grant and the record: a save snapshot sees both or neither
		if not grant(data) then
			refused = true
			return
		end
		recordReceipt(data, purchaseId)
		applied = true
	end)
	if refused then
		warn(`[Receipts] grant refused for {purchaseId}`)
		return WAIT -- leave it unresolved; support can resolve it (see "refused grants" below)
	end

	-- Granted now or earlier: acknowledge only once the profile with this id is saved.
	if saveNow(player) then
		if applied then
			-- side effects that must happen once: analytics, announcements, spend boards
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return WAIT
end
```

Why each step is the way it is:

- **`waitReady` first.** A purchase from the Store tab (`ExperienceDetailsPage`) or a pending one arrives the moment the player joins, before their profile loads. Granting into nothing is impossible; answering `NotProcessedYet` immediately means it only comes back on the next purchase or rejoin. Waiting is allowed (no timeout) and is what Roblox's sample does, while also giving up if the player leaves.
- **Refuse if the profile cannot save** (`lost`, failed load, locked). Granting into a session that will never be written takes the money and gives nothing.
- **Grant and record inside one non-yielding mutation.** The save takes a deep-copy snapshot of the profile; because the grant and the receipt id are added in the same synchronous step, every snapshot contains either both or neither.
- **Already recorded but unsaved**: we skip the grant and just save. That matches Roblox's "recorded but not reflected in the data store: return NotProcessedYet until it is".
- **Concurrent servers**: session locking means only one server holds an active profile. The other's `waitReady` fails (`locked`) and it answers `NotProcessedYet`; the purchase is resolved by the owner.
- **Bounded receipt list.** Roblox only re-delivers unresolved purchases; once one is resolved it does not come back, so a recent window suffices. The reference project kept the newest 100 ids per profile.
- **One-off side effects after the durable save**, gated by `applied`: a retried receipt must not re-announce or re-count spend.

## Two-layer design for gifts (production lesson)

Gifting breaks the simple model: the **buyer** triggers the receipt, but the **recipient's** profile gets the grant, and the recipient may leave before it lands. One production game handled this with a second store, a **receipt ledger** keyed by `PurchaseId`, failing closed everywhere ("anything uncertain answers NotProcessedYet, and Roblox retries the receipt later instead of us guessing"):

1. **Claim the purchase id** in the ledger with `UpdateAsync` before any grant. The record stores who it pays (`R = recipientUserId`), the product key and a timestamp. If a record already exists, read it instead: a retry must pay the **same** person.
2. If the record says `Done`, return `PurchaseGranted` immediately.
3. If the recipient is in the server, call the grant hook, which writes grant + purchase id into the **recipient's** profile and answers true only after that save.
4. If the recipient has left: check whether their **saved** profile already contains the purchase id (a fresh read). If yes, mark done and acknowledge. If not, give them a grace period (the buyer sees "your gift is waiting for its player to join your server"), and after it **re-point** the ledger record to the buyer (only if it still points at the recipient and is not done) before granting to the buyer, so a later retry cannot pay both.
5. After the grant is saved, mark the ledger record `Done` (best effort: if that write fails, the retry finds the id in the profile).
6. The gift target chosen in the purchase prompt was also saved in a small **intent store** (buyer id to product to recipient), because the receipt can arrive on a different server than the one where the player chose the recipient.

The general lesson: when a purchase can touch more than one profile, the profile receipt list is not enough, because no single session lock covers both. A ledger keyed by `PurchaseId` and claimed atomically is the coordination point.

Other lessons from the same project:

- **Every paid thing must be in the profile.** A paid boost that lived only in player attributes was lost on leave; it was moved into the profile.
- **Once-per-player products** were recorded in a profile `Once` table, and the shop refused to prompt a second time (asking the profile owner `ownsOnce`, which answered `nil`, "can't tell", while the profile was loading, so the shop refused then too).
- **Products whose grant could not be paid** (a placeholder id of 0, or a grant type the profile code did not support) were never prompted: "it must never take Robux for nothing".
- **Spend tracking** for a Robux leaderboard fired exactly once, when the ledger record flipped to `Done` for the first time.
- Account resets renamed progress stores but **kept the receipts and intent stores**, so idempotency survived the reset ([[Data Schema Design and Migrations]]).

## Refused and stuck grants

What if `grant` cannot apply (inventory full, one-time pack already owned because of a client-side race)? Options:

| Policy | Effect |
|---|---|
| Return `NotProcessedYet` (above) | Robux stays in escrow; the purchase comes back on rejoin. Unresolved purchases are not refunded automatically when escrow ends, so you must resolve it eventually |
| Grant an equivalent (currency of the same value) | Resolves cleanly; communicate it |
| Make the grant always succeed (overflow storage, mailbox) | Best: design products so a valid purchase can always be delivered |

Prevent the race at prompt time: validate on the server before calling `PromptProductPurchase`, and re-validate in the grant.

## Game passes and subscriptions are different

Game passes are owned permanently by the user, not delivered by receipts. Check `MarketplaceService:UserOwnsGamePassAsync(userId, passId)` on join (cache the result; it can fail, so retry and treat failure as "unknown", not "not owned"), and react to `PromptGamePassPurchaseFinished` for in-session purchases. Do **not** store pass ownership as the source of truth in your data store; store only derived state (for example, a one-time bonus already given). The reference project stored bundle passes it granted itself (passes sold as developer products) in a profile `OwnedPasses` table, which is a different thing: those are products. Note its test-key rule as well: Studio test profiles ignore owned passes so a fresh-profile test is really fresh. Subscriptions have their own APIs ([[Subscriptions and Premium Payouts]]).

## Refunds

Roblox can send a **Transaction Refunded** webhook (developer products, passes, private servers, paid access; not subscriptions) to an endpoint you configure on the Creator Dashboard ([[Open Cloud APIs]]). What you do with it is policy: many games log it and, for abuse patterns, claw back the currency through a support tool, never by silently deleting items mid-session. Any clawback is a profile write and must go through the session-locked path (or Open Cloud when the player is offline and no lease is live).

## Testing

- In Studio, product prompts complete as test purchases; `ProcessReceipt` runs. Use a test profile key ([[Session Locking and Profile Libraries]]).
- Force the failure paths: make `saveNow` return false and confirm the handler answers `NotProcessedYet` and the next trigger (another purchase, rejoin) resolves it without a double grant.
- Simulate a duplicate: call the handler twice with the same fake receipt and assert one grant.
- Simulate "recorded but unsaved": grant, block the save, unblock, call again.

## Common mistakes

| Mistake | Result |
|---|---|
| Returning `PurchaseGranted` before saving | Paid items lost on crash or failed save |
| Granting without checking `PurchaseId` | Double grants on retries and concurrent servers |
| Grant and id saved in different writes or keys | A crash keeps one without the other |
| Answering `NotProcessedYet` instantly when the profile is still loading | Store-tab purchases stay stuck until the next rejoin |
| Granting into a profile that failed to load | Robux taken, nothing persists |
| Multiple scripts setting `ProcessReceipt` | Only the last assignment is used; products handled elsewhere never grant |
| Side effects (announce, analytics) before the durable save | Repeated on every retry |
| Trusting the client about what was bought | Exploitable; the receipt is the only truth |

## Checklist

- [ ] Exactly one `ProcessReceipt`, covering every product id.
- [ ] Waits for the profile; refuses when it cannot save.
- [ ] Grant and `PurchaseId` recorded together, synchronously, in the same key.
- [ ] `PurchaseGranted` only after a confirmed save.
- [ ] Receipt list bounded; kept across resets.
- [ ] Gifts and cross-profile grants use a ledger claimed with `UpdateAsync`.
- [ ] One-off side effects run once.
- [ ] Unknown or undeliverable products are never prompted.

## See also
[[Developer Products and ProcessReceipt]] · [[Game Passes]] · [[Session Locking and Profile Libraries]] · [[Saving Correctly - Autosave and BindToClose]] · [[Data Loss Prevention and Recovery]] · [[Economies and Currencies]] · [[Server Authority and Validation]] · [[Pricing and Store Design]]

## Connected notes
<!-- auto-links:start -->
[[Shop with Game Passes and Developer Products End to End]] · [[Idempotency]] · [[Refunds Chargebacks and Purchase Support]] · [[Skill - Roblox DataStore Safety]] · [[Skill - Roblox Monetization Compliance]] · [[Links - Developer products]]
<!-- auto-links:end -->
