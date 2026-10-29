---
tags: [economy, trading, market-design, memorystore, pricing, scams, policy, luau, design]
---
# Player-Driven Trading Economies

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Power items tradeable -> Bind progression items
> - Avoid: Last-trade price shown -> Robust median over distinct pairs
> - Avoid: No trade cooldown -> Cooldown on newly acquired items
> - Decided which items should have a market price; progression items bound.
> - Trade cooldown on new acquisitions; requirements and receive caps for new accounts.
> - Format chosen from the ladder; premium currency never tradeable.
>
> Cost: TL;DR ~150 tok · whole note ~5.7k tok. Read more: ## 7. Real-money trading, scams and moderation load · ## 8. A cross-server listing board with MemoryStore · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Trading Systems Without Duplication]] makes a trade correct: server-owned offers, a commit protocol across two profiles, recovery, policy gates. [[Economy Exploits - Dupes Races and Purchase Abuse]] covers the attacks. This note is about the **market** that trading creates once it works: how items become money, how prices form and how to show them without being manipulated, which trade formats to support, fees and taxes as sinks, controlling item supply when every copy lives forever, real-money trading and scams, and a cross-server listing board built on MemoryStore.

The central idea: once players can trade, **you no longer set the value of items. Players do.** Your levers become supply, friction and information.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**. Luau is strict, reviewed by reading, not run.

---

## 1. What trading does to an economy

Without trading, an item's value is personal: what it does for the player who owns it. With trading, every item also has an **exchange value**, and three things change at once.

1. **Rare items become a store of value.** Players hold them not to use but because they will be worth something later. Hoarding takes items out of use and makes supply look smaller than it is.
2. **A money-like item emerges.** Barter between dozens of item types is awkward, so players settle on one widely held, fungible item as the unit ("worth 3 Frost Blades"). You did not design that currency, but its supply now matters as much as your coins.
3. **Time and money convert into each other through other players.** A player with hours trades rare drops to a player with Robux-bought items. That is the healthy version. The unhealthy version is real-money trading outside the game (section 7).

Before enabling trading, answer: **which of my items do I want to have a market price?** Items that define power progression usually should not, because the market will price them far above what a new player can reach. Cosmetics, collectibles and limited event items are good market goods: their value is social, and a high price does not lock anyone out of content.

### Tradeable, bound and soul-bound

| Binding | Rule | Use for |
|---|---|---|
| Tradeable | Freely tradeable | Collectibles, cosmetics, materials meant as trade goods |
| Bound on use | Tradeable until equipped or upgraded once | Gear that should circulate before commitment |
| Account-bound | Never tradeable | Progression power, quest rewards, starter items |
| Tradeable after cooldown | Tradeable N days after acquisition | New drops, purchased items, anything dupe-sensitive |

Binding is the strongest supply lever you have, and the only one you can safely tighten for **new** items. Making an existing tradeable item bound later confiscates market value from holders; announce it well in advance or apply it only to newly acquired copies.

**The trade cooldown is underrated.** A rule that a newly acquired item cannot be traded for, say, 3 to 7 days (rule of thumb) costs honest players almost nothing, but it delays every dupe, stolen-account sweep and real-money sale by that much, which gives your detection (section 8) time to act before copies spread.

---

## 2. Trade formats

| Format | How | Liquidity | Risk |
|---|---|---|---|
| Direct barter, same server | Both online, item-for-item window | Low: only who is in your server | Lowest; correct protocol in the existing note |
| Trading hub servers | A dedicated place or server type where traders gather | Medium | Same as direct; needs matchmaking ([[Server Browsers and Server Lists]]) |
| Listing board (cross-server) | Post "I offer X, want Y"; others accept asynchronously | High | Needs escrow and a mailbox |
| Fixed-price market | List an item for soft currency; anyone buys | Highest | A real exchange: price manipulation, bots, tax design |
| Auctions | Bids over time | High | Sniping, shill bidding; rarely worth it on Roblox |

Rule of thumb ladder: start with same-server barter. Add a hub place when players complain they cannot find partners. Add a listing board only when you have the tooling to watch it. A soft-currency market is a big step: it turns items into coins and coins into items, which merges the item economy and the coin economy into one ([[Currency Architecture - Soft Hard and Event Currencies]]). Every coin faucet then inflates item prices, and every item supply change moves coin value.

**Premium currency never trades**, in any format, for the reasons in [[Trading Systems Without Duplication]] section 2.

---

## 3. Price discovery: showing value without being manipulated

Players will build value lists on community sites whatever you do. Those lists are slow, sometimes run by people who hold the items they price, and they are a common tool for scams ("the list says this is worth more"). An in-game price signal is better, but only if it resists manipulation.

### Derive prices from completed trades, robustly

For barter, price each trade in the money-like unit (or in your own reference value per item), then publish a statistic of recent trades. The choice of statistic is the whole game:

| Statistic | Manipulation resistance | Notes |
|---|---|---|
| Last trade price | None | One fake trade between alts sets the price |
| Mean of last N | Low | One extreme trade moves it far |
| Median of last N | Medium | Needs half of N fake trades to move |
| Trimmed median over distinct counterparties | High | Count at most one trade per pair of accounts |
| Volume-weighted with account age filter | High | Ignore trades involving accounts younger than X days |

Rule of thumb: median of the last 20 to 50 trades, at most one per distinct pair of accounts, excluding accounts below a playtime threshold, and show "not enough data" below about 10 qualifying trades. Show the number of trades the price is based on. A price with "based on 4 trades" teaches players to treat it with care.

**Wash trading** (trading an item back and forth between two of your own accounts at an inflated price) is exactly what the distinct-pair and account-age filters defeat. Without them, any in-game price display becomes an instrument for pumping items before selling them to new players.

### Fairness warnings instead of value meters

[[Trading Systems Without Duplication]] warns against fake "fair trade" meters. A better tool is a **lopsided trade warning**: when the robust price estimate of one side is less than a fraction (for example a third) of the other, show "This trade gives away much more value than it receives" and require a second confirmation. It protects new players without the game claiming to know exact values.

---

## 4. Fees and taxes: sinks that shape behaviour

A trade by itself creates nothing and destroys nothing, so trading does not add sinks unless you add them. Fees are the natural place.

| Fee | Charged | Effect |
|---|---|---|
| Listing fee | When posting, refundable or not | Reduces spam listings and price-probing |
| Sales tax | Percentage of the sale price, fixed-price markets | Main sink; reduces flipping |
| Flat trade fee | Coins per barter trade | Sink scaled to activity; hurts small trades most |
| Item burn | A small consumable destroyed per trade (a "trade ticket") | Ties trading volume to a craftable or droppable sink |

**Worked example (rule of thumb arithmetic).** A fixed-price market moves 2 million coins of items per day at 5% sales tax: 100,000 coins destroyed daily. If the whole game's coin faucets are 20 million per day, the market tax removes 0.5% of daily inflation. That is real but small. The tax's bigger effect is behavioural: a flipper buying at 100 and selling at 104 loses money at 5% tax, so short-term arbitrage disappears and prices move less.

Taxes have limits:

- Above about 10 to 15% (rule of thumb), players move trades off the market into barter or out of the game, and you lose both the sink and the price information.
- A tax in coins on a barter trade of rare items is either negligible (flat fee) or punitive (percentage of a value you have to estimate). Prefer a flat fee or a trade ticket for barter.
- Fees must not apply to items the player bought for Robux in a way that feels like taking a cut of their purchase. Keep fees on the soft-currency side.

---

## 5. Supply: every copy lives forever

In a non-trading game, a rare item that a player stops using is effectively gone. In a trading game it goes back on the market. **Supply of a tradeable item only grows unless something destroys copies.**

Arithmetic (rule of thumb): if 200 copies of an item enter the game per day ([[Drop Tables Rarity and Pity Systems]] section 2 shows how to compute that from tables) and nothing destroys them, after 90 days there are 18,000. If the number of active players wanting it is stable, its price falls roughly in proportion. Players experience this as "my legendary is worthless now" and as betrayal when it follows a luck event.

Supply tools, in order of how well they are received:

1. **Consumption that players want.** Fusion, upgrading, crafting into a better item. Each consumes copies. [[Economy Inflation Sinks and Faucets Math]] section 5 shows a fusion ladder that consumes 243 base copies per max-star item.
2. **New top tiers rather than more of the old.** Add a new item at the top instead of raising luck on old items.
3. **Limited editions with fixed supply.** An event item that can only drop during the event has a known final supply. Publish the count; scarcity is credible only if it is visible.
4. **Seasonal binding.** Items earned in a season become untradeable after it ends. Effective, but only for new items announced that way from the start.
5. **Direct removal.** Only for duplicates and exploits ([[Trading Systems Without Duplication]] section 8).

**Luck events are supply events.** A weekend at 2x luck doubles the inflow of every rare item for two days. In a trading economy, that is a measurable price drop on every rare a week later. Model it before you schedule it ([[Economy Telemetry and Balancing Live]]).

---

## 6. Market power, cornering and bots

Small Roblox markets are thin. A few wealthy players can hold a large share of a rare item and set its price.

- **Cornering.** One account (or a group) buys most copies of a limited item and relists at many times the price. Mitigation: per-account holding caps on limited items (enforced at trade time), or simply enough supply that cornering is uneconomic.
- **Bot listings.** Scripts that post and undercut listings every second. Mitigation: listing fees, per-account listing caps, and server-side rate limits on every market remote ([[Rate Limiting and Abuse Prevention]]).
- **Sniping.** Bots that buy any listing below a threshold within milliseconds. A short randomised delay before a new listing becomes purchasable ("listings appear within 30 seconds") removes the speed advantage.
- **Information asymmetry.** Experienced traders exploit new players' ignorance. Lopsided-trade warnings (section 3) and trade requirements for new accounts are the main tools.

None of these are worth heavy engineering in a small game. They become important when the market is a major reason people play.

---

## 7. Real-money trading, scams and moderation load

**Real-money trading** (selling items or accounts for money outside Roblox) is against the Roblox Terms of Use and attracts account theft, chargebacks and scams. You cannot stop it entirely, but your design can make it less profitable:

- **Trade cooldowns** on newly acquired items (section 1) slow item sales.
- **Requirements before trading unlocks** (playtime, progress) raise the cost of mule accounts. Measured in the reference project: 500 rolls and 2 rebirths after one tuning pass.
- **Receive caps for young accounts**, so one main cannot absorb hundreds of items from fresh accounts per day.
- **Make the most valuable items account-bound.** If the top tier cannot be traded, there is nothing big to sell.

**Scams** generate more support load than any exploit: fake "trust trades", impersonation ("I am the developer, give me your item to verify it"), off-platform payment promises, and swapped items at confirm time (handled by the version counter in the existing note). Clear UI rules and an in-game trade history are your evidence when support asks what happened. All chat in trading flows goes through `TextChatService` filtering like any other text ([[Age Checks and Safety Features]], [[Player Reports and In-Game Moderation]]).

**Rule of thumb:** budget moderation and support time before you launch trading. A trading game with no one answering scam reports loses trust faster than one without trading.

### Policy gates (Roblox docs, as of October 2026)

- `PolicyService:GetPolicyInfoForPlayerAsync` returns `IsPaidItemTradingAllowed`. The paid random items page states that when it is true, the user can trade virtual items purchased with in-experience currency or Robux, and that for ineligible users you must not let them trade the outcome of a paid random item. The PolicyService reference page itself does not list this key; treat a missing value as "not allowed".
- `MarketplaceService:GetUsersPriceLevelsAsync` returns price levels for a list of users. The regional pricing guide suggests trading paid items only between users at the same price level and gifting only from a higher or equal level to a lower one, to block regional price arbitrage.

Both gates need item **provenance** (was this bought, bought with paid currency, or earned free), recorded at grant time ([[Currency Architecture - Soft Hard and Event Currencies]] section 3).

---

## 8. A cross-server listing board with MemoryStore

A listing board lets players post offers that anyone in any server can accept. It needs three parts: a shared, short-lived index of listings (MemoryStore), escrow so a listed item cannot also be used or traded elsewhere, and a mailbox to deliver results to players who may be offline or in another server.

Relevant MemoryStore facts (Roblox docs, as of October 2026, memory stores guide): memory quota of 64 KB plus 1.2 KB per user, request units of 1,000 plus 120 per concurrent user per minute (both per experience), values up to 32 KB, expirations up to 3,888,000 seconds (45 days), and a sorted map or queue holds up to 1,000,000 items and 100 MB. A single partition starts throttling around 30,000 request units per minute. `MemoryStoreSortedMap:UpdateAsync(key, transform, expiration)` retries until it succeeds, the transform returns `nil`, or retries run out; the transform receives the current value and sort key and returns a new value and sort key ([[MemoryStore Service]]).

Design:

- **One sorted map per item type** (`Listings_<itemId>`), sort key = asking price, so `GetRangeAsync(Enum.SortDirection.Ascending, 20)` returns the cheapest listings. Splitting by item keeps each map small and spreads load across partitions.
- **Escrow first.** Before the listing exists, the seller's server moves the item out of the inventory into an `Escrow` record in the seller's own profile (same session-locked profile, no cross-player write). If the listing fails, the item goes back.
- **Claim atomically.** A buyer's server claims a listing with `UpdateAsync`: if the value is unclaimed, set `claimedBy` and return it; otherwise return `nil` (abort). Exactly one buyer can win.
- **Settle through a decision record.** The claiming server writes a DataStore decision record (`Sale/<listingId>`) with a single `UpdateAsync`, charges the buyer, and both sides are settled by mailbox on their next load or immediately if online, exactly like the commit protocol in [[Trading Systems Without Duplication]] section 5. MemoryStore is the index, never the source of truth: if it is lost or expires, escrow records in profiles still know what is listed.

```lua
--!strict
-- ServerScriptService/Market/Listings.lua (index only; escrow and settlement live elsewhere)
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")

export type Listing = {
	id: string,
	seller: number,
	itemUid: string,
	price: number,
	claimedBy: number?,
}

local LISTING_TTL = 3 * 24 * 3600 -- 3 days; escrow returns the item on expiry

local Listings = {}

local function map(itemId: string): MemoryStoreSortedMap
	return MemoryStoreService:GetSortedMap("Listings_" .. itemId)
end

-- Call only after the item is in the seller's escrow.
function Listings.post(itemId: string, seller: number, itemUid: string, price: number): (boolean, string?)
	local listing: Listing = {
		id = HttpService:GenerateGUID(false),
		seller = seller,
		itemUid = itemUid,
		price = price,
	}
	local ok, err = pcall(function()
		map(itemId):SetAsync(listing.id, listing, LISTING_TTL, price)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, listing.id
end

function Listings.cheapest(itemId: string, count: number): { Listing }
	local ok, entries = pcall(function()
		return map(itemId):GetRangeAsync(Enum.SortDirection.Ascending, count)
	end)
	local out: { Listing } = {}
	if ok then
		for _, entry in entries do
			local l = entry.value :: Listing
			if l.claimedBy == nil then
				table.insert(out, l)
			end
		end
	end
	return out
end

-- Atomically claim a listing for `buyer` at the price they saw. Returns the claimed listing or nil.
function Listings.claim(itemId: string, listingId: string, buyer: number, seenPrice: number): Listing?
	local ok, result = pcall(function()
		return map(itemId):UpdateAsync(listingId, function(current: Listing?, sortKey: any)
			if current == nil or current.claimedBy ~= nil then
				return nil -- gone or already claimed: abort, write nothing
			end
			if current.seller == buyer or current.price ~= seenPrice then
				return nil -- self-buy or price changed since the buyer looked
			end
			current.claimedBy = buyer
			return current, sortKey
		end, LISTING_TTL)
	end)
	-- Trust only what was committed: the returned value, and only if it names this buyer.
	local committed = if ok then result :: Listing? else nil
	if committed and committed.claimedBy == buyer then
		return committed
	end
	return nil
end

return Listings
```

Important details:

- **Read the result from the return value, not from a variable set inside the transform.** The transform can run more than once under contention. A local set in a first run survives a later run that aborts because someone else won, and two buyers would both think they bought the item. The value `UpdateAsync` returns is what was committed (or `nil` if the transform aborted); checking `claimedBy == buyer` on it is the safe test. Never do side effects (charging coins, granting items) inside a transform.
- **Claimed listings stay in the map** until settlement removes them, so `cheapest` filters them out. A claimed listing whose settlement never completes is resolved by the decision record, not by MemoryStore.
- **Price must be what the buyer saw.** The `seenPrice` check prevents a seller from raising the price between the buyer's view and click.
- **Rate limit** posts and claims per player on the server, and cap active listings per player (rule of thumb 5 to 20), both for abuse and for MemoryStore quota.
- **Unverified:** the maximum `count` for one `GetRangeAsync` call is not stated on the sorted map guide page checked for this note; keep pages small (20 to 50) and check the reference before relying on a larger number.

---

## 9. When not to have a player market

- **Progression-driven games where items are power.** A market makes the best gear purchasable by whoever has the most of something else, which is usually Robux.
- **Small teams without moderation capacity.** Scams and RMT need humans.
- **Young audiences** where the social pressure of trading is a safety concern; gifting from the shop may be enough ([[Social Design and Multiplayer Play]]).
- **Before your item supply is modelled.** Launching a market on an economy whose supply you have not computed means the market will compute it for you, publicly.

---

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Power items tradeable | New players buy endgame gear; progression collapses | Bind progression items |
| Last-trade price shown | Prices jump after a single odd trade | Robust median over distinct pairs |
| No trade cooldown | Dupes and stolen items spread within hours | Cooldown on newly acquired items |
| No sinks for tradeable items | Rare prices fall steadily | Fusion, crafting, new top tiers |
| Luck events without supply modelling | Market crash a week after the event | Model inflow before scheduling |
| Very high market tax | Trades move to barter or off-platform | Keep under about 10 to 15% |
| MemoryStore as source of truth | Items lost when listings expire | Escrow in profiles, decision records |
| Side effects inside `UpdateAsync` transforms | Double charges under contention | Transforms compute; callers act |
| No moderation plan | Scam reports pile up unanswered | Budget support before launch |

## Checklist

- [ ] Decided which items should have a market price; progression items bound.
- [ ] Trade cooldown on new acquisitions; requirements and receive caps for new accounts.
- [ ] Format chosen from the ladder; premium currency never tradeable.
- [ ] Prices shown as robust medians with trade counts; lopsided-trade warnings.
- [ ] Fees designed as sinks below the escape threshold.
- [ ] Item supply per day modelled; copy sinks in place; luck events modelled.
- [ ] Policy and price-level gates with provenance recorded at grant time.
- [ ] Cross-server listings: escrow, atomic claim, decision record, mailbox.
- [ ] Moderation and support capacity planned for scams.

## See also
[[Economy Design Start Here]] · [[Currency Architecture - Soft Hard and Event Currencies]] · [[Drop Tables Rarity and Pity Systems]] · [[Economy Telemetry and Balancing Live]] · [[Simulating an Economy Before Launch]] · [[Trading Systems Without Duplication]] · [[Economy Exploits - Dupes Races and Purchase Abuse]] · [[Economy Inflation Sinks and Faucets Math]] · [[MemoryStore Service]] · [[Pricing and Store Design]] · [[Roblox Policies Ratings and Compliance]] · [[Social Design and Multiplayer Play]]

## Connected notes
<!-- auto-links:start -->
[[Faucets and Sinks]] · [[UGC Pricing Limiteds and Marketplace Rules]] · [[Economies and Currencies]] · [[Commerce and Physical Goods]] · [[Expected Value]] · [[Progression Levels and Unlocks]]
<!-- auto-links:end -->
