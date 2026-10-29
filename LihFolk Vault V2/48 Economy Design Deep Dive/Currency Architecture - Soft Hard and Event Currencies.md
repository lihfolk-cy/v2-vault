---
tags: [economy, currency, soft-currency, premium-currency, event-currency, wallet, analytics, luau, design]
---
# Currency Architecture - Soft Hard and Event Currencies

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Two currencies with the same sources and sinks -> Merge; convert old balances once
> - Avoid: Fixed-price cosmetics in an exponential currency -> Move them to a flat currency
> - Avoid: Pack sizes not on the price unit -> Common price unit; re-size packs
> - Every currency has one job, one distinct faucet and one distinct sink.
> - Scale decided (flat or exponential); fixed-price content lives in a flat currency.
> - Premium anchor fixed; every price and pack a multiple of a common unit.
>
> Cost: TL;DR ~170 tok · whole note ~5.8k tok. Read more: ## 3. Premium currency: the decisions that are hard to undo · ## 5. A wallet module with buckets, idempotency and analytics · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Economies and Currencies]] lists the kinds of currency a Roblox game can have and how to write a safe server transaction. [[Economy Inflation Sinks and Faucets Math]] gives the arithmetic of faucets, sinks and the premium currency anchor. [[Big Numbers Precision and Formatting]] covers doubles, integer limits and number formatting. This note sits between them and answers the architecture questions: how many currencies, what each one is for, how they convert, how an event currency is born and dies, how a wallet stores paid and free units separately, and how the whole set maps onto analytics before you log your first event.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**. Code is strict Luau, reviewed by reading, not run.

---

## 1. One currency per job

The most common architecture mistake is not a bad price. It is a currency that has no job of its own. Every currency should answer one question that no other currency answers. If two currencies buy the same things from the same sources, they are one currency with two icons, and the player has to learn both.

| Job | Typical name | Sources | Sinks | Tradeable? |
|---|---|---|---|---|
| Moment-to-moment progress | Coins, cash | Kills, drops, idle income | Gates, upgrades, rolls | No |
| Paid shortcut and premium goods | Gems, crystals | Robux packs, small free trickle | Premium shop, boosts, cosmetics | Never |
| Time-limited participation | Event tokens | Event activities only | Event shop only | No |
| Long-term status | Prestige points, rebirth tokens | Rebirths, seasons | Permanent perks | No |
| Crafting inputs | Materials, shards | Bosses, salvage | Forge, fusion | Sometimes |
| Social value | Tradeable items acting as money | Players | Players | Yes, by design |

The test for a proposed new currency is three questions:

1. **What does it buy that nothing else buys?** If the answer is "the same shop, but a different tab", fold it into an existing currency.
2. **Where does it come from that nothing else pays out?** A currency with the same faucet as coins is coins with a conversion step.
3. **What happens to it when the player stops caring?** If the honest answer is "it piles up", you are designing a future inflation problem ([[Economy Inflation Sinks and Faucets Math]]).

### What each extra currency costs

Each currency is not free even if it is a single number in the profile:

- **HUD space.** On a phone, two currency counters fit comfortably in the top bar; three is crowded; four needs a collapsible wallet ([[HUD Design]], rule of thumb).
- **Analytics slots.** The economy dashboard supports up to five currencies (Roblox docs, as of October 2026, economy events guide). Six currencies means one of them is invisible in the built-in charts, or two of them share a name and become unreadable. Count your analytics slots before you count your shop tabs.
- **Player attention.** Younger players in particular read "you need 3 more shards" as a wall, not a goal. Every currency is one more thing that can be the reason they quit.
- **Support load.** Every currency needs a refund path, a grant tool, a log and a migration story ([[Refunds Chargebacks and Purchase Support]]).

Rule of thumb: a session-based Roblox game rarely needs more than one soft currency, one premium currency and one event currency at a time. Materials are better modelled as **items with a count** in the inventory than as currencies, because they then reuse the inventory UI, stacking, provenance and trade rules you already have ([[Saved Inventory End to End]]).

---

## 2. Soft currency: design the scale, not just the price

A soft currency needs a **scale decision** before any price exists:

- **Flat scale.** Prices from tens to a few thousands. Easy to read, easy to compare, good for cosmetic-driven and round-based games. Inflation shows up quickly because every number is small and visible.
- **Exponential scale.** Prices from hundreds to quadrillions, suffix formatting, income growing per zone. The genre language of simulators ([[Genre Playbook - Simulators]]). It hides inflation (a 30% overpay at 4.2T is invisible) and it needs the big-number care in [[Big Numbers Precision and Formatting]].

The trap is drifting from one to the other. A game starts flat, adds a rebirth multiplier, then a pet multiplier, and two months later players hold 9.8M of a currency whose shop still has a 250-coin sword. Either commit to exponential growth and price everything from an income model, or cap multipliers so the flat scale survives.

**Nuance: an exponential soft currency cannot carry fixed-price content.** Anything priced in coins at a fixed number becomes free a few zones later. Fixed-price content (cosmetics, social items, emotes) belongs in a currency that does not scale: premium, event tokens, or a separate "style" currency with a flat faucet. This is the one good reason to add a second soft currency.

---

## 3. Premium currency: the decisions that are hard to undo

On Roblox you can sell everything directly for Robux with developer products and passes ([[Developer Products and ProcessReceipt]], [[Game Passes]]). A premium currency is optional, and a growing number of games skip it. The trade-off:

| Direct Robux pricing | Premium currency in between |
|---|---|
| The player sees the real price on every item | One extra step hides the real price |
| One developer product per price point | A handful of packs cover any number of shop items |
| No stranded balances | Leftover gems after a purchase |
| No free premium trickle to balance | You can reward play with small amounts of premium value |
| Simple paid random items disclosure | Items bought with purchased currency are still paid items for policy purposes ([[Paid Random Items and Odds Disclosure in Practice]]) |

If you do use one, three decisions are close to permanent.

### The anchor

Pick a fixed value ("1 gem is worth about 1 Robux") and derive every pack, price and free reward from it ([[Economy Inflation Sinks and Faucets Math]] section 6). Changing the anchor later means repricing the whole shop and confusing everyone who bought at the old rate.

### Pack sizes against prices: the stranded balance problem

Players resent leftover premium currency they cannot spend, and they are right to: they paid for it. Design pack sizes and prices together.

**Worked example (rule of thumb arithmetic).** Packs of 100, 550 and 1,200 gems; shop items at 80, 400 and 1,000 gems.

- Buy 100, spend 80: 20 stranded.
- Buy 550, spend 400: 150 stranded, not enough for anything except one 80 item, leaving 70.
- Buy 1,200, spend 1,000: 200 stranded.

Change the item prices to 50, 250 and 600 (multiples of 50 that divide the pack sizes reasonably) and every pack can be emptied exactly by some combination: 100 = 2 x 50, 550 = 250 + 6 x 50, 1,200 = 2 x 600. Rule: make every item price a multiple of a common unit, and make each pack size a multiple of the same unit. Bonus gems on bigger packs ("+10%") should also keep the totals on the unit.

### Paid and free units are not the same money

A premium currency that is both sold and given away holds two kinds of value. Store them separately (`GemsPaid`, `GemsFree`) from day one, even if the UI shows one number. You need the split for:

- **Refund and chargeback handling.** You can only reverse what you can identify ([[Refunds Chargebacks and Purchase Support]]).
- **Provenance of what was bought.** An item bought with paid gems is a paid item for trading and paid random item rules ([[Trading Systems Without Duplication]] section 6). An item bought with a mix is, conservatively, paid.
- **Your own metrics.** "Free share of premium currency" is only measurable if the two are separate.

**Spend order** (which bucket is used first) must be a written, consistent rule. Spending free units first keeps the paid balance, the value that can be refunded, intact longest. Spending paid units first marks more items as paid. Neither is wrong, but choosing an order specifically to reduce how many items count as "paid" is the kind of decision to check against the current policy pages rather than assume (unverified: Roblox docs, as of October 2026, do not state a spend-order rule).

---

## 4. Event currency: a lifecycle, not a number

An event currency exists to make a time-limited event feel separate from the main grind ([[Live Ops Events and Updates]], [[Event Calendars and Content Planning]]). Its whole value is that it ends. That means you need rules for every phase.

```
Announce -> Earn window -> Spend-only grace -> Expire or convert -> Archive
```

| Phase | Rule of thumb | Why |
|---|---|---|
| Earn window | The event length, usually 1 to 3 weeks | Long enough for a weekly player to finish |
| Spend-only grace | 3 to 7 days after earning stops | Players who were away on the last weekend can still spend |
| Expire or convert | Convert leftovers at a poor but non-zero rate, or expire with clear warning | Expiry without warning is the top complaint after any event |
| Archive | Remove the shop, keep the ledger | Support needs to answer "where did my tokens go" |

### One token or one token per event?

- **One shared "event token" that resets each event.** Simple UI, one analytics slot. But the reset is a confiscation every time, and players who could not finish one event lose tokens they earned.
- **A token per event, keyed by event id.** The wallet stores `Event[eventId]`. Old balances never collide with new ones, conversion can happen lazily on the next login after the event ends, and a returning player is not punished for missing the expiry day. Analytics should still log them under one currency name ("EventTokens") with the event id in a custom field, so you do not burn a currency slot per event.

The second is almost always better. Lazy conversion on load mirrors the season rollover pattern in [[Economy Resets and Seasonal Wipes]]: no batch job, no race with live servers, and the conversion runs exactly once per profile.

### Never sell an expiring currency

If event tokens can be bought for Robux (directly, or through gem packs), expiry destroys paid value. Rule of thumb: **paid currency never expires**. If you want a paid event track, sell the track (a pass or a product that unlocks rewards, [[Battle Pass and Season Design]]), not the currency. Token boosters sold for Robux are fine only if the tokens they produce are spent within the event and leftovers convert, never vanish.

### Conversion rates that do not break the main economy

Leftover tokens converted to soft currency are a faucet. Bound it:

- Convert at a rate that values a token at a fraction (rule of thumb 10 to 25%) of what it bought in the event shop, so spending in the event is always better.
- Cap the conversion per event, for example at the value of one gate at the player's current zone.
- Convert into the currency that hurts least: premium conversion is dangerous (it inflates your anchor), soft conversion scaled to the player's progress is safe.

---

## 5. A wallet module with buckets, idempotency and analytics

The wallet is the one place currency changes. Every grant and spend goes through it so that buckets, logging and limits are consistent ([[Server Authority and Validation]]). The sketch below assumes a session-locked profile table ([[Session Locking and Profile Libraries]]) and uses the `AnalyticsService:LogEconomyEvent` signature from the API reference: `(player, flowType, currencyType, amount, endingBalance, transactionType, itemSku?, customFields?)` (Roblox docs, as of October 2026). Events are only recorded from servers in published experiences; they are not recorded from clients or Studio test sessions.

```lua
--!strict
-- ServerScriptService/Economy/Wallet.lua
local AnalyticsService = game:GetService("AnalyticsService")

export type WalletData = {
	Coins: number,
	GemsPaid: number,
	GemsFree: number,
	Event: { [string]: number }, -- eventId -> tokens
	Applied: { string },         -- recent idempotency keys, newest last
}

export type Currency = "Coins" | "Gems" | "EventTokens"

local MAX_APPLIED = 64
local MAX_COINS = 2 ^ 53 -- exact integer limit of a double; see Big Numbers note

local Wallet = {}

local function wasApplied(w: WalletData, key: string): boolean
	return table.find(w.Applied, key) ~= nil
end

local function markApplied(w: WalletData, key: string)
	table.insert(w.Applied, key)
	if #w.Applied > MAX_APPLIED then
		table.remove(w.Applied, 1)
	end
end

local function balanceOf(w: WalletData, currency: Currency, eventId: string?): number
	if currency == "Coins" then
		return w.Coins
	elseif currency == "Gems" then
		return w.GemsPaid + w.GemsFree
	else
		return w.Event[eventId :: string] or 0
	end
end

local function log(
	player: Player,
	flow: Enum.AnalyticsEconomyFlowType,
	currency: Currency,
	amount: number,
	ending: number,
	transactionType: string,
	sku: string?,
	eventId: string?
)
	-- Analytics must never break a transaction: wrap it.
	local fields = if eventId then { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = eventId } else nil
	pcall(AnalyticsService.LogEconomyEvent, AnalyticsService, player, flow, currency, amount, ending, transactionType, sku, fields)
end

-- Grant. `paid` only matters for Gems. Returns false if this key was already applied.
function Wallet.grant(
	player: Player,
	w: WalletData,
	currency: Currency,
	amount: number,
	transactionType: string,
	key: string,
	opts: { paid: boolean?, sku: string?, eventId: string? }?
): boolean
	assert(amount > 0 and amount == math.floor(amount), "integer amounts only")
	if wasApplied(w, key) then
		return false
	end
	local o = opts or {}
	if currency == "Coins" then
		w.Coins = math.min(w.Coins + amount, MAX_COINS)
	elseif currency == "Gems" then
		if o.paid then
			w.GemsPaid += amount
		else
			w.GemsFree += amount
		end
	else
		local id = assert(o.eventId, "event grants need an eventId")
		w.Event[id] = (w.Event[id] or 0) + amount
	end
	markApplied(w, key)
	log(player, Enum.AnalyticsEconomyFlowType.Source, currency, amount, balanceOf(w, currency, o.eventId), transactionType, o.sku, o.eventId)
	return true
end

-- Spend. Returns ok and, for Gems, how many paid units were consumed (for item provenance).
function Wallet.spend(
	player: Player,
	w: WalletData,
	currency: Currency,
	amount: number,
	transactionType: string,
	key: string,
	opts: { sku: string?, eventId: string? }?
): (boolean, number)
	assert(amount > 0 and amount == math.floor(amount), "integer amounts only")
	if wasApplied(w, key) then
		return false, 0
	end
	local o = opts or {}
	if balanceOf(w, currency, o.eventId) < amount then
		return false, 0
	end
	local paidUsed = 0
	if currency == "Coins" then
		w.Coins -= amount
	elseif currency == "Gems" then
		-- Written rule: free units first. Change it here and only here.
		local fromFree = math.min(w.GemsFree, amount)
		w.GemsFree -= fromFree
		paidUsed = amount - fromFree
		w.GemsPaid -= paidUsed
	else
		local id = o.eventId :: string
		w.Event[id] -= amount
	end
	markApplied(w, key)
	log(player, Enum.AnalyticsEconomyFlowType.Sink, currency, amount, balanceOf(w, currency, o.eventId), transactionType, o.sku, o.eventId)
	return true, paidUsed
end

return Wallet
```

Notes on the design:

- **No yields inside `grant` or `spend`.** The analytics call is fire-and-forget; it does not yield the transaction. Validation and mutation happen in one block ([[Economy Exploits - Dupes Races and Purchase Abuse]]).
- **Idempotency keys** come from the caller: a receipt id for purchases, `quest:<id>` for quest rewards, `trade:<id>:<side>` for trades. Replaying the same key is a no-op, which is what makes retries and recovery safe ([[Purchase Data and Receipts]]).
- **Transaction type strings.** Use `Enum.AnalyticsEconomyTransactionType.Shop.Name` and friends for the six built-in types (IAP, TimedReward, Onboarding, Shop, Gameplay, ContextualPurchase per the docs) and only add custom types when the default ones cannot separate two flows you need to tell apart.
- **Custom field key.** The economy events guide allows up to three custom fields for dashboard filtering, keyed `CustomField01` to `CustomField03` with string values ([[Analytics and Funnels]] lists the key enum and the combination limit). Putting the event id there keeps every event under one currency name.
- **The `paidUsed` return** is what the shop records as provenance on the item it grants.

---

## 6. Conversions and the arbitrage loop

As soon as currencies convert into each other, you can accidentally print money. The classic loop: coins buy materials, materials salvage into gems, gems buy a coin booster that earns more coins than the materials cost. Each step looked fair in its own spreadsheet tab.

The check is mechanical. Write every conversion as an edge `from -> to` with a rate (units of `to` per unit of `from`, at best-case luck and multipliers). A loop is profitable if the product of rates around it is greater than 1. With a handful of currencies, a Floyd-Warshall pass on "best product" finds every such loop.

```lua
--!strict
-- Run in the command bar or a test. Rates are best-case: max luck, max multipliers.
type Edge = { from: string, to: string, rate: number }

local function findArbitrage(names: { string }, edges: { Edge }): { string }
	local best: { [string]: { [string]: number } } = {}
	for _, a in names do
		best[a] = {}
		for _, b in names do
			best[a][b] = if a == b then 1 else 0
		end
	end
	for _, e in edges do
		best[e.from][e.to] = math.max(best[e.from][e.to], e.rate)
	end
	for _, k in names do
		for _, i in names do
			for _, j in names do
				local via = best[i][k] * best[k][j]
				if via > best[i][j] then
					best[i][j] = via
				end
			end
		end
	end
	local bad = {}
	for _, a in names do
		if best[a][a] > 1 + 1e-9 then
			table.insert(bad, `{a} grows by x{string.format("%.3f", best[a][a])} around a loop`)
		end
	end
	return bad
end

print(findArbitrage({ "Coins", "Shards", "Gems" }, {
	{ from = "Coins", to = "Shards", rate = 1 / 500 },  -- shop: 500 coins per shard
	{ from = "Shards", to = "Gems", rate = 2 },         -- salvage: 1 shard -> 2 gems
	{ from = "Gems", to = "Coins", rate = 300 },        -- booster value per gem, best case
}))
-- 1/500 * 2 * 300 = 1.2: the loop prints 20% per cycle.
```

Two subtleties:

- **Rate is not price.** A booster that "costs 10 gems" is a conversion into coins at whatever the booster earns over its duration at the player's best income. Late in the game that rate is enormous, which is why boosters priced in a fixed premium amount quietly become the best coin faucet. Price boosters as a share of the player's income or give them a fixed-duration effect whose value you can bound.
- **Rounding direction.** Integer conversions must round in the house's favour on every transaction (floor what the player receives, ceil what they pay), and need a minimum amount. A converter that rounds 0.6 tokens up to 1 can be farmed by converting one coin at a time, and exploiters will script exactly that ([[Rate Limiting and Abuse Prevention]]).

**Rule of thumb:** allow conversion in one direction only, from scarcer to commoner (premium to soft, event leftovers to soft), never from commoner to scarcer. One-way conversion cannot loop.

---

## 7. Presenting several currencies

- **Show the currency that matters here.** The HUD shows coins; the premium shop shows gems at the top; the event hub shows tokens. Contextual counters beat a permanent row of five ([[Menu Archetypes - Shop Settings Codes Rewards]]).
- **Distinct icon and colour per currency**, consistent everywhere, including prices on buttons. Never show a bare number on a price button.
- **Show where a currency comes from** when the player cannot afford something: "Earn tokens from event bosses" beats a greyed-out button.
- **Animate gains toward the counter** so players learn which counter a reward belongs to ([[Game Feel and Juice]]).
- **Warn before expiry.** Three days and one day before event currency expires, show a banner with the balance and what it converts to.

---

## When not to add a currency

- **To make a price look smaller.** A currency invented to hide that an item costs 2,000 Robux is a trust problem ([[Ethical Design and Player Trust]]).
- **To gate one feature.** One feature gate is a level or quest requirement, not a currency.
- **Because a reference game has five.** Popular games accumulate currencies over years of events; copying the end state skips the reasons each one exists.

---

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Two currencies with the same sources and sinks | Players ask what the difference is | Merge; convert old balances once |
| Fixed-price cosmetics in an exponential currency | Cosmetics become free mid-game | Move them to a flat currency |
| Pack sizes not on the price unit | Complaints about leftover gems | Common price unit; re-size packs |
| Paid and free premium mixed in one number | Cannot process a refund or a provenance check | Separate buckets from day one |
| Event tokens expire silently | Support spike after every event | Grace period, warnings, conversion |
| Paid currency that expires | Trust and complaint risk | Paid value never expires |
| Two-way conversions | Coin balances jump for a few accounts | One-way only; loop check |
| Rounding up on conversion | Scripts converting 1 unit at a time | Floor gains, ceil costs, minimum size |
| More currencies than analytics slots | Missing currency in the dashboard | Plan names against the five-currency limit |

## Checklist

- [ ] Every currency has one job, one distinct faucet and one distinct sink.
- [ ] Scale decided (flat or exponential); fixed-price content lives in a flat currency.
- [ ] Premium anchor fixed; every price and pack a multiple of a common unit.
- [ ] Paid and free premium stored separately; spend order written down.
- [ ] Event currency keyed by event id, with grace period, warnings and bounded conversion.
- [ ] No paid currency can expire.
- [ ] All changes go through one wallet with idempotency keys and integer amounts.
- [ ] Conversions one-way; arbitrage loop check run on best-case rates.
- [ ] Currency names, transaction types and SKUs planned against analytics limits.

## See also
[[Economy Design Start Here]] · [[Pricing Curves and Upgrade Costs]] · [[Drop Tables Rarity and Pity Systems]] · [[Player-Driven Trading Economies]] · [[Economy Telemetry and Balancing Live]] · [[Simulating an Economy Before Launch]] · [[Economies and Currencies]] · [[Economy Inflation Sinks and Faucets Math]] · [[Big Numbers Precision and Formatting]] · [[Robux Price Points and Offer Design]] · [[Economy Resets and Seasonal Wipes]] · [[Analytics and Funnels]]

## Connected notes
<!-- auto-links:start -->
[[Faucets and Sinks]] · [[Pricing and Store Design]] · [[Monetization Overview]] · [[Expected Value]] · [[Shop with Game Passes and Developer Products End to End]] · [[Rebirth and Prestige System End to End]]
<!-- auto-links:end -->
