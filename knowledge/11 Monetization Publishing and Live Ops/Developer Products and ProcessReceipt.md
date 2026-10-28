---
tags: [monetization, developer-products, processreceipt, datastore, idempotency, luau]
---
# Developer Products and ProcessReceipt

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Granting in `PromptProductPurchaseFinished` -> Grant in `ProcessReceipt` only
> - Avoid: Returning `PurchaseGranted` before saving -> Save, then acknowledge
> - Avoid: Receipt marker in a different store than the grant -> Same document
> - Exactly one `ProcessReceipt` assignment in the codebase (grep it)
> - Every configured product has a grant; startup assert
> - Grant and receipt marker in the same saved document
>
> Cost: TL;DR ~150 tok · whole note ~5.8k tok. Read more: ## 2. The receipt contract · ## 3. A correct implementation · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Developer products are repeatable purchases: currency packs, boosts, revives, bundles, starter packs. Every one of them is delivered through a single server callback, `MarketplaceService.ProcessReceipt`. Getting that callback right is the most important piece of monetization code in a Roblox game, because mistakes cost real money: players charged with nothing granted, or items granted twice.

This note covers the receipt contract, a correct idempotent data-store-backed implementation, the failure modes that break the obvious implementations, and product design. Verified against the Developer Products guide and the `MarketplaceService` reference **as of October 2026**. The storage side (receipt logs, auditing, recovery) is covered in [[Purchase Data and Receipts]].

---

## 1. Products, mechanically

- Created per experience: Creations, game, Monetization, Developer Products, Create developer product (Docs). Requires a published game, an icon (at most 512x512, `.jpg`/`.png`/`.bmp`, keep detail inside the circle), name, description, shop category and price (Docs).
- **Price range: 1 to 1,000,000,000 Robux** (Docs).
- Copy the id from the product list: hover the thumbnail, the three-dot menu, Copy Asset ID (Docs).
- **Listed products** can appear on the Roblox home page, in search and on the post-purchase page. To list a product you must implement `ProcessReceipt` correctly; Roblox monitors receipt handling and flagged products stop appearing outside the game until fixed, although they stay purchasable in-game (Docs). A sloppy receipt handler now costs you distribution.
- **Roblox keeps no per-user purchase history for you** (Docs). If support asks "did this player buy the starter pack?", only your own log can answer.
- **Regional pricing** is opt-in for developer products, and the opt-in requires implementing `GetUsersPriceLevelsAsync` checks for gifts and trades (Docs). See [[Pricing and Store Design]].
- **Cross-game product sales** are disabled from May 30, 2026 (Docs).
- **Personalisation APIs:** `RankProductsAsync` ranks product ids you supply (strict rate limit: load once at join), `RecommendTopProductsAsync` returns up to 50 items but only if the game had at least one purchase in the last 28 days (Docs).

---

## 2. The receipt contract

When a player buys a product, Roblox creates a receipt and calls your `ProcessReceipt` callback on a server the player is in. What the docs state (Oct 2026):

- Signature: `ProcessReceipt(receiptInfo): Enum.ProductPurchaseDecision`.
- Return `Enum.ProductPurchaseDecision.PurchaseGranted` **only after** the items are granted. Otherwise return `NotProcessedYet` (Docs).
- `NotProcessedYet` means the receipt is redelivered later; the Docs sample says "tries again next time the user joins the game".
- **Only one server script can set the callback** (Docs). A second assignment silently replaces the first: two systems that each set `ProcessReceipt` means one of them never receives receipts.
- `receiptInfo` fields used in the official samples: `PurchaseId`, `PlayerId`, `ProductId`, `CurrencySpent`, `CurrencyType`. Docs: it includes the exact Robux amount paid, even during price tests. Other fields (such as `PlaceIdWherePurchased`) appear in older docs; this vault does not rely on them.
- **Do not use `PromptProductPurchaseFinished` to grant.** It firing does not confirm a purchase (Docs). It is fine for UI (closing a spinner).
- Docs on what is not documented: there is no published retry schedule and no published deadline after which an unprocessed purchase is refunded. Community material often mentions automatic refunds after a few days; treat that as **unverified** and design as if an unprocessed receipt simply waits for the player's next visit.

### The three properties a handler must have

1. **Idempotent.** The same `PurchaseId` can arrive more than once: a retry after you returned `NotProcessedYet`, a retry because the server crashed after granting but before Roblox recorded your `PurchaseGranted`, or a second call while the first is still yielding. Granting must happen at most once per `PurchaseId`.
2. **Durable before acknowledging.** Return `PurchaseGranted` only once the grant *and* the record of the receipt are saved. If you acknowledge first and the save fails, the player paid for nothing and Roblox will never resend.
3. **Atomic grant and record.** The grant and the "this PurchaseId is done" marker must be saved together. If they live in different stores, a crash between the two writes either loses the grant (marker saved, grant not) or duplicates it (grant saved, marker not).

The third property is the one most implementations miss, including the classic pattern of a separate "purchase history" store.

### Why the classic separate-store pattern is fragile

The long-standing sample (still on the reference page, Oct 2026) uses a dedicated data store keyed by `PurchaseId`, calls `UpdateAsync` on it, and runs the grant inside the callback. It is a big improvement over no idempotency, and the docs warn that grant handlers "must never yield" because they run inside `UpdateAsync`. But the grant in the sample changes in-memory state (leaderstats, health). The player's real save is written later by the autosave. A server crash between "receipt marked granted" and "profile autosaved" loses the purchase permanently, and Roblox never retries because you said `PurchaseGranted`.

**Reference project.** It used exactly this shape: a separate receipts store (`PurchaseReceipts_v1`) next to the player store. A second, subtler consequence showed up: when the team wiped player data (bumping the player store version several times during development) they kept the receipts store. Any receipt processed before a wipe was "done" forever, so a pre-wipe purchase could not be replayed into the new profile. In a live game that would need a manual re-grant from the purchase log.

The robust fix: **store processed `PurchaseId`s inside the player's own profile document**, the same document the grant changes. One save covers both.

---

## 3. A correct implementation

Assumptions: you have a session-locked player data module (see [[Session Locking and Profile Libraries]]) exposing:
- `PlayerData.GetProfileAsync(player, timeout): Profile?` yields until the profile is loaded (or the timeout passes) and returns `nil` if the player left or loading failed.
- `PlayerData.SaveNowAsync(player): boolean` writes the profile immediately and returns whether it succeeded.
- `PlayerData.Peek(player): ProfileData?` returns the loaded data without yielding (used only for analytics).

The profile's data includes a receipt table. All product grants are pure, non-yielding functions of the profile data.

```lua
--!strict
-- ServerScriptService/Services/ReceiptService (Script). The ONLY place that sets ProcessReceipt.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService.Services.PlayerData)
local Products = require(ServerScriptService.Config.Products) -- { [key]: { Id: number, Grant: GrantSpec } }

type ProfileData = {
	Gems: number,
	Cash: number,
	Flags: { [string]: boolean },
	Receipts: { [string]: number }, -- PurchaseId -> os.time() granted
	ReceiptOrder: { string }, -- oldest first, for trimming
	PurchaseLog: { { Key: string, Robux: number, At: number } },
}

type Grant = (data: ProfileData, player: Player) -> boolean -- must NOT yield; false = cannot grant

local MAX_RECEIPTS = 200 -- keep the newest N PurchaseIds; size budget, see section 5
local PROFILE_WAIT = 15 -- seconds to wait for a joining player's profile

-- One grant function per product KEY. Keys are stable; ids can change.
local GRANTS: { [string]: Grant } = {
	GemsSmall = function(data)
		data.Gems += 500
		return true
	end,
	StarterPack = function(data)
		if data.Flags.StarterPack then
			return true -- already owned: treat a duplicate buy as granted (see section 4)
		end
		data.Flags.StarterPack = true
		data.Gems += 1000
		data.Cash += 25000
		return true
	end,
}

-- Map product id -> key, and fail loudly at startup if any product lacks a grant.
local keyById: { [number]: string } = {}
for key, spec in Products do
	if spec.Id ~= 0 then
		assert(GRANTS[key], `[Receipts] product {key} has no grant function`)
		keyById[spec.Id] = key
	end
end

local inFlight: { [string]: boolean } = {}

local function trimReceipts(data: ProfileData)
	while #data.ReceiptOrder > MAX_RECEIPTS do
		local oldest = table.remove(data.ReceiptOrder, 1)
		if oldest then
			data.Receipts[oldest] = nil
		end
	end
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local purchaseId = tostring(receiptInfo.PurchaseId)
	local productId = receiptInfo.ProductId :: number
	local key = keyById[productId]
	if not key then
		-- Unknown product (removed from config, wrong experience). Never acknowledge:
		-- it stays pending until a build that knows it is live.
		warn(`[Receipts] unknown product {productId} ({purchaseId})`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- redelivered when they rejoin
	end

	if inFlight[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- same receipt already being handled
	end
	inFlight[purchaseId] = true

	local decision = Enum.ProductPurchaseDecision.NotProcessedYet
	local ok, err = pcall(function()
		local profile = PlayerData.GetProfileAsync(player, PROFILE_WAIT)
		if not profile then
			return
		end
		local data = profile.Data :: ProfileData

		if data.Receipts[purchaseId] then
			-- Granted earlier (maybe saved, maybe only in memory). If this server
			-- holds the profile, make sure it is saved before acknowledging.
			if PlayerData.SaveNowAsync(player) then
				decision = Enum.ProductPurchaseDecision.PurchaseGranted
			end
			return
		end

		-- Grant + mark in the SAME document, with no yield in between.
		if not GRANTS[key](data, player) then
			return
		end
		data.Receipts[purchaseId] = os.time()
		table.insert(data.ReceiptOrder, purchaseId)
		table.insert(data.PurchaseLog, { Key = key, Robux = receiptInfo.CurrencySpent or 0, At = os.time() })
		trimReceipts(data)

		-- Acknowledge only after a successful save. If the save fails, the grant
		-- stays in memory with its marker; the retry finds the marker and saves again.
		if PlayerData.SaveNowAsync(player) then
			decision = Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end)
	inFlight[purchaseId] = nil

	if not ok then
		warn(`[Receipts] error on {purchaseId}: {err}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local gemsGranted = (Products[key] :: any).GemsForAnalytics :: number? -- config field, optional
	if decision == Enum.ProductPurchaseDecision.PurchaseGranted and gemsGranted and gemsGranted > 0 then
		-- Analytics after the fact; never let logging affect the decision.
		pcall(function()
			local data = PlayerData.Peek(player)
			AnalyticsService:LogEconomyEvent(
				player,
				Enum.AnalyticsEconomyFlowType.Source,
				"Gems",
				gemsGranted, -- amounts are always positive (Docs)
				if data then data.Gems else 0, -- ending balance
				Enum.AnalyticsEconomyTransactionType.IAP.Name,
				key -- item SKU
			)
		end)
	end
	return decision
end

MarketplaceService.ProcessReceipt = processReceipt
```

Why each piece is there:
- **`keyById` plus the startup `assert`** catches the reference project's real bug class: a product configured on the dashboard whose grant type the server did not support. In that game a luck-charm product charged players while the grant was silently skipped because its grant key was missing from a whitelist. A crash at boot in Studio is far cheaper than refunds.
- **Unknown product returns `NotProcessedYet`.** If you retire a product from config while receipts are still pending, you want them to wait, not vanish. Keep retired products' grants in code (the reference project deleted a pack's shop card but deliberately left its config entry).
- **Player missing returns `NotProcessedYet`.** The callback can be called on a server the player has just left.
- **`inFlight`** blocks a second concurrent call for the same `PurchaseId` from granting while the first is yielding on a save. Rule of thumb: the engine may call `ProcessReceipt` again for a pending receipt; this guard makes that harmless within a server. Across servers, the session lock guarantees only one server holds the profile.
- **Marker check before grant**, inside the same profile, is the idempotency.
- **No yield between grant and marker.** Grant functions must be pure and synchronous. Do not call `DataStore`, `MarketplaceService` or `task.wait` inside one.
- **Save, then acknowledge.** `SaveNowAsync` must return `false` on failure, never throw away the error.
- **Analytics after the decision**, wrapped in `pcall`. Use a real amount and balance; see [[Analytics and Funnels]].

### Without a session-locked profile

If your game has no profile caching (rare; small games that read and write data stores per action), you can do the grant and marker in one `UpdateAsync` on the player's key:

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerData_v1")

-- Returns true when the receipt is durably recorded (granted now or before).
local function grantAtomically(userId: number, purchaseId: string, grant: (data: any) -> ()): boolean
	local ok, err = pcall(function()
		store:UpdateAsync(`Player_{userId}`, function(data)
			data = data or { Gems = 0, Receipts = {} }
			if data.Receipts[purchaseId] then
				return nil -- already granted: cancel the write, nothing to change
			end
			grant(data) -- must not yield: we are inside UpdateAsync
			data.Receipts[purchaseId] = os.time()
			return data
		end)
	end)
	if not ok then
		warn(err)
	end
	return ok
end
```

Returning `nil` from the transform cancels the write; `UpdateAsync` still succeeds, which is what we want for "already granted". This is only safe if **nothing else overwrites that key from a stale in-memory copy**. If any part of the game caches the profile and later saves it with `SetAsync` or a blind `UpdateAsync`, the cached save will erase this grant. Mixing the two models is the bug; pick one. See [[DataStore Fundamentals]].

### `BindReceiptHandler` (new, partly documented)

The reference lists a newer `MarketplaceService:BindReceiptHandler(transactionType: Enum.ReceiptType, handler, filter?)` that returns an `RBXScriptConnection`, with handlers returning `Enum.ReceiptDecision.Processed` or `NotProcessedYet` (Docs, Oct 2026). `Enum.ReceiptType` has `DeveloperProduct`, `RobuxTransferSender` and `RobuxTransferReceiver`. The Robux transfers guide uses it for transfer receipts. Its sample also recommends `UpdateAsync` to prevent double grants. As of October 2026 the Developer Products guide still teaches `ProcessReceipt`, and the docs do not say whether `ProcessReceipt` and a `DeveloperProduct` handler can coexist. Recommendation: keep developer products on `ProcessReceipt` and use `BindReceiptHandler` for Robux transfer receipts until the guide says otherwise. **Unverified:** coexistence behaviour.

---

## 4. Product rules that live in the receipt handler

**Refuse at prompt time, never at receipt time.** By the time `ProcessReceipt` runs, the player has paid. If a product is off-sale (an off-week exclusive, a starter pack the player already owns), stop the prompt from opening on the server side of your shop remote. The reference project's weekly exclusive rotation refused off-week products inside the server shop service; if any of those refusals happens inside the receipt path, the result is a paid, never-granted receipt that comes back on every join. When a receipt arrives for something you would have refused, grant it anyway (or grant an equivalent) and fix the prompt path.

**One-per-player products** (starter packs, first-purchase bonuses): developer products cannot be limited by Roblox. Enforce it at prompt time with a profile flag, and make the grant idempotent on the flag as in the example (`StarterPack` returns `true` without regranting). Decide what a rare duplicate buy should do: grant a compensation (for example the gem value) rather than nothing.

**Server-wide products** (server luck, global events): the buyer pays, everyone benefits. The grant writes server state (attributes on `workspace`, a MemoryStore entry for cross-server events). Record the receipt in the *buyer's* profile; the server effect is not durable, so if the server shuts down a minute later the buyer lost most of it. Rule of thumb: extend rather than restart the timer on stacking purchases, show the remaining time on the shop card, and make the copy say "this server". The reference project had to reword its server-luck description and card to say exactly that.

**Gift products** grant to another user. Record the receipt in the buyer's profile and the gift in the recipient's (or a gift-intents store applied when they join). With regional pricing, gate gifts with `GetUsersPriceLevelsAsync` (sender's level greater than or equal to recipient's) (Docs).

**Rewarded video rewards** are developer products too: the ad system calls `ProcessReceipt` for the reward product when the ad finishes (Docs). Your handler must accept them like any purchase. See [[Ads and Rewarded Video]].

**Random rewards** (eggs, crates, mystery packs) bought directly or through paid currency are paid random items: disclose odds before purchase, check `ArePaidRandomItemsRestricted`, and have a compliant path for restricted players. See [[Roblox Policies Ratings and Compliance]].

---

## 5. Sizing and data hygiene

- **Receipt table size.** Each `PurchaseId` string costs a few dozen bytes. 200 entries is a few KB of a 4 MB data store value limit; trimming keeps heavy spenders' profiles bounded. The risk of trimming: a receipt older than the newest 200 being redelivered. That only happens if a receipt stays pending across 200 newer purchases, which in practice means never. (Rule of thumb; choose N from your data.)
- **Purchase log.** Keep a compact per-player log (product key, Robux spent, time) separate from receipts, never trimmed below what support needs. It is what lets you answer tickets and replay grants after a data loss. See [[Purchase Data and Receipts]] and [[Data Loss Prevention and Recovery]].
- **Data wipes.** If you reset player data, either keep processed-receipt markers with the new profile, or (better) re-grant purchases from the log. A wipe that drops purchases is a support disaster.
- **Product reconfiguration.** Keep product keys stable forever. Change a product's id (new product) or contents only with care: receipts in flight are matched to the *current* grant function. The reference project kept a weapon product's key when its grant moved to a different item after a rarity re-tier; players who had bought it before kept what they had, buyers after got the new item. Announce such changes in the update log.

---

## 6. Prompting and the shop remote

The client asks; the server decides whether the prompt may open.

```lua
--!strict
-- Server: the only path from the shop UI to a product prompt.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuyProduct = ReplicatedStorage.Remotes.BuyProduct :: RemoteEvent
local lastPrompt: { [Player]: number } = {}

BuyProduct.OnServerEvent:Connect(function(player: Player, key: unknown)
	if typeof(key) ~= "string" then
		return
	end
	local spec = Products[key]
	if not spec or spec.Id == 0 then
		return -- not for sale yet
	end
	local now = os.clock()
	if (lastPrompt[player] or 0) > now - 1 then
		return -- one prompt per second is plenty
	end
	lastPrompt[player] = now
	if not ShopRules.CanPrompt(player, key) then -- owned starter pack, off-week item, tutorial
		return
	end
	MarketplaceService:PromptProductPurchase(player, spec.Id)
end)
```

`Products`, `ShopRules` and cleanup of `lastPrompt` on `PlayerRemoving` are left to your project. Validate everything; see [[RemoteEvents RemoteFunctions and Unreliable Remotes]] and [[Rate Limiting and Abuse Prevention]].

---

## 7. Testing

- **Studio test purchases** do not charge Robux. The prompt shows a test dialog and `ProcessReceipt` runs normally, so the full grant path is testable.
- Test: buy, then kill the server before the save completes (simulate by making `SaveNowAsync` return false); rejoin and check the purchase is granted exactly once.
- Test: two buys of the same product in quick succession.
- Test: buy, leave immediately.
- Test: product with no grant (should fail at startup).
- Use a test-profile key for QA accounts so test purchases do not pollute real data. See [[Testing Strategies and Frameworks]].

---

## 8. Common mistakes

| Mistake | What it looks like | Fix |
|---|---|---|
| Granting in `PromptProductPurchaseFinished` | Free items for anyone who cancels at the right time; missing grants | Grant in `ProcessReceipt` only |
| Returning `PurchaseGranted` before saving | Rare "paid, nothing" tickets after server crashes | Save, then acknowledge |
| Receipt marker in a different store than the grant | Lost or doubled grants on crash | Same document |
| Two scripts set `ProcessReceipt` | One system's products never grant | One owner script, dispatch by key |
| Yielding inside a grant in `UpdateAsync` | Errors, retries, duplicates | Pure grant functions |
| Refusing at receipt time | Paid receipts that never clear | Refuse at prompt time |
| Hard-coded prices | Wrong price for regional, test and Plus users | `GetProductInfoAsync` |
| No purchase log | Cannot answer support, cannot recover | Keep one |

## 9. Checklist

- [ ] Exactly one `ProcessReceipt` assignment in the codebase (grep it)
- [ ] Every configured product has a grant; startup assert
- [ ] Grant and receipt marker in the same saved document
- [ ] `PurchaseGranted` only after a successful save
- [ ] Unknown product / missing player returns `NotProcessedYet`
- [ ] One-per-player rules enforced at prompt time
- [ ] Retired products keep their grant code
- [ ] Purchase log kept; data-wipe plan re-grants purchases
- [ ] Economy events logged after grant

## See also
[[Purchase Data and Receipts]] · [[Session Locking and Profile Libraries]] · [[Saving Correctly - Autosave and BindToClose]] · [[Game Passes]] · [[Pricing and Store Design]] · [[Ads and Rewarded Video]] · [[Server Authority and Validation]] · [[Monetization Overview]]

## Connected notes
<!-- auto-links:start -->
[[Shop with Game Passes and Developer Products End to End]] · [[Idempotency]] · [[Refunds Chargebacks and Purchase Support]] · [[Skill - Roblox Monetization Compliance]] · [[Links - Developer products]] · [[Economy Exploits - Dupes Races and Purchase Abuse]]
<!-- auto-links:end -->
