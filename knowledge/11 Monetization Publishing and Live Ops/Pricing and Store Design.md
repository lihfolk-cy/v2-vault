---
tags: [monetization, pricing, managed-pricing, regional-pricing, shop, store-design, luau]
---
# Pricing and Store Design

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Hard-coded prices (wrong for regional, test and Plus players).
> - Avoid: A "70% off!" label that is not computed from real prices.
> - Avoid: Selling currency with nothing worth buying.
> - Every price on screen comes from `GetProductInfoAsync` (Dynamic Price Check passes)
> - Price-level gate on gifts and trades of paid items
> - Ladder of 3 to 5 rungs per category; value per Robux increases with size
>
> Read more (16 KB note): ## 1. The price a player sees is not your price · ## 3. Setting prices · ## 6. Common mistakes · ## 7. Checklist
<!-- tldr:end -->

How to price Roblox products, how Roblox now changes your prices for you (managed pricing: regional pricing plus price optimization), how to display prices so they are correct for every player, and how to lay out a store that converts without tricking anyone. Platform facts verified against the Creator Hub "Managed pricing", "Regional pricing", "Price optimization" and "Roblox Plus" pages **as of October 2026**. Design advice is rule of thumb unless marked, with examples from the reference project's shop history.

---

## 1. The price a player sees is not your price

In 2026 four things can make the displayed price differ from the number in your config:

| Mechanism | Effect | Applies to |
|---|---|---|
| **Regional pricing** | Lowers the price by region, never above your default, never more than 70% below it (100 default -> 30 to 100) | Passes (on by default), developer products (opt-in), Robux subscriptions (always on), avatar items (Docs) |
| **Price optimization** | Tests different prices on subsets of users, then recommends new defaults | Passes and developer products; games with roughly 60,000+ transactions in 30 days (Docs) |
| **Roblox Plus discount** | Subscribers pay 10% or 20% less; Roblox pays the difference to you | Products, passes, subscriptions, paid access, avatar items (Docs) |
| **Your own sales** | Sale prices set on the dashboard | Whatever you put on sale |

Docs are blunt about the consequence: a hard-coded price in your UI does not update, so users are **charged the correct regional price while your UI shows the wrong number** (Docs, regional pricing). A **Dynamic Price Check** tool tests up to five accounts with a pinned Robux price or a pinned economic location to find hard-coded prices (Docs).

**Reference project.** Every product and pass carried a `Robux` field in config (Double Roll 599, VIP 399, Jackpot Roll 499, and so on), and shop cards were built from it. That was fine before managed pricing. Today it is a bug: any regionally priced or Plus player sees a higher number than they pay, which also depresses conversion in exactly the regions where you lowered prices to increase it. Keep the config number only as a fallback when the live lookup fails.

### Economic location
Roblox decides a user's pricing region from signals such as VPN use, billing history and account history, not only account country; if it cannot decide, the user sees the default global price (Docs).

### Regional pricing and trading
Price differences create arbitrage: buy cheap in one region, gift or trade to a player in another. Docs provide `MarketplaceService:GetUsersPriceLevelsAsync(userIds)` returning `PriceLevelInfo` entries with `UserId` and `PriceLevel`. `PriceLevel` is **1 to 1000**, roughly the percentage of full price (in tenths) the user pays; 1000 is the full global price (Docs). The docs' examples:
- allow a **gift** only when the sender's level is greater than or equal to the recipient's;
- allow a **trade** only when both levels match.

Docs: call it at join and do not cache it past the session, because levels change. Implementing this is a **prerequisite for opting developer products into regional pricing** (Docs).

```lua
--!strict
-- Server: fetch price levels for players as they join; gate gifts and trades.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local levelOf: { [number]: number } = {}

Players.PlayerAdded:Connect(function(player)
	local ok, infos = pcall(function()
		return MarketplaceService:GetUsersPriceLevelsAsync({ player.UserId })
	end)
	if ok then
		for _, info in infos do
			levelOf[info.UserId] = info.PriceLevel
		end
	end
end)
Players.PlayerRemoving:Connect(function(player)
	levelOf[player.UserId] = nil
end)

local PriceLevels = {}

-- Unknown level = treat as not allowed for paid items (fail closed).
function PriceLevels.CanGift(senderId: number, recipientId: number): boolean
	local s, r = levelOf[senderId], levelOf[recipientId]
	return s ~= nil and r ~= nil and s >= r
end

function PriceLevels.CanTrade(aId: number, bId: number): boolean
	local a, b = levelOf[aId], levelOf[bId]
	return a ~= nil and b ~= nil and a == b
end

return PriceLevels
```

Apply these only to items bought with Robux (or paid currency). Free-earned items need no gate. If your game also restricts paid item trading by policy, combine with `IsPaidItemTradingAllowed` ([[Roblox Policies Ratings and Compliance]]).

### Price optimization (Docs, Oct 2026)
- Eligibility "in most cases": at least 60,000 transactions in the previous 30 days. Subscriptions are not eligible.
- You select which products and passes to include (Docs recommend all). Users are split into test groups; per the glossary, 98% see tested prices and 2% the original.
- About **3 weeks** to finish (you get an email), then a price review period (four weeks per the glossary). Tests rerun automatically at least every **90 days**.
- Prices apply only if they produce positive incremental revenue; you click Review & Apply.
- You cannot change prices of products in an active test; stopping a test reverts prices.
- `receiptInfo` reports the exact Robux the player paid during tests (Docs, developer products), so revenue analytics must use it, not config prices.

---

## 2. Showing the right price

Prices must be read on the **client** so each player sees their personalised price (Docs, developer products and price optimization). Cache per session and fall back gracefully.

```lua
--!strict
-- ReplicatedStorage/PriceCache (ModuleScript, used by LocalScripts)
local MarketplaceService = game:GetService("MarketplaceService")

export type Price = { Robux: number?, ForSale: boolean }

local cache: { [string]: Price } = {}
local pending: { [string]: { thread } } = {}

local PriceCache = {}

-- infoType: Enum.InfoType.Product for developer products, Enum.InfoType.GamePass for passes.
function PriceCache.Get(id: number, infoType: Enum.InfoType): Price
	local key = `{infoType.Name}:{id}`
	local hit = cache[key]
	if hit then
		return hit
	end
	local waiting = pending[key]
	if waiting then -- another card is already fetching this id: wait for it
		table.insert(waiting, coroutine.running())
		return coroutine.yield()
	end
	pending[key] = {}
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(id, infoType)
	end)
	local price: Price
	if ok then
		price = { Robux = info.PriceInRobux, ForSale = info.IsForSale ~= false }
	else
		price = { Robux = nil, ForSale = true } -- unknown: let the prompt show the real price
	end
	if ok then
		cache[key] = price -- only cache successes
	end
	local waiters = pending[key]
	pending[key] = nil
	for _, co in waiters do
		task.spawn(co, price)
	end
	return price
end

function PriceCache.Label(price: Price): string
	if price.Robux then
		return `R$ {price.Robux}`
	end
	return "BUY" -- never show a guessed number
end

return PriceCache
```

Why: one cached lookup per id per session; concurrent cards share one request; failures are not cached and do not show a stale number. The Roblox purchase prompt always shows the true price, so "BUY" is an honest fallback. `GetProductInfoAsync` is the current name; `GetProductInfo` is deprecated (Docs, Oct 2026). For long sessions, refresh when the shop reopens after a long gap; managed prices update periodically (Docs).

`GetProductInfoAsync` also returns discount information in some samples (`PriceDiscountDetails`, `UserBasePriceInRobux`) that you can use to show a strike-through. Use them only if present.

---

## 3. Setting prices

Roblox does not publish recommended price points. These are rules of thumb from simulator and RNG games, including the reference project.

### A ladder, not a list
Players compare. Give every category three to five rungs with clearly increasing value per Robux:

| Rung | Purpose | Example from the reference project |
|---|---|---|
| Impulse (under 100) | Converts first-time payers | Lucky Rolls pass 75; More Cash 79; Server Luck 99 |
| Core (200 to 600) | The main decision | Super Potions 199, Fast Roll 299, VIP 399, Jackpot Roll 499, Double Roll 599 |
| Premium (800 to 1,500) | Whales and gifts | Direct-sale weapon 799, exclusive weapon 999, big bundle 1,499 |

### Currency packs
The reference project sold four gem packs (small, medium, large, huge). Patterns:
- **Value per Robux rises with size** (the "bonus %" label). It must be true and computed from the real amounts.
- **A reason to buy each size.** If the largest pack is the obvious deal, the middle ones are noise.
- **Gems need sinks first.** The team's own observation was "gems don't do much", so they added a gem shop (8 cards), gem-priced forge materials (4 to 1,000 gems by rarity) and a gem-priced server luck boost (1,200 gems) before pushing gem packs. A currency pack sells only when the currency buys something wanted. See [[Economies and Currencies]].

### The starter pack
A one-time-per-player bundle that is clearly the best value in the store. Its job is converting a non-payer into a payer, after which every other product is easier.
- Enforce once-per-player at prompt time (a profile flag), and hide the card once bought.
- Show it when the player has had a good experience, not on join: after the tutorial, after the first boss, after a near-miss roll.
- The reference project put it in the shop, on a lobby billboard, and alongside server luck as an in-world prompt.

### Boosts and "server luck"
Timed and server-wide boosts sell well in RNG games because the buyer gets social visibility (the reference game announced each purchase in the roll feed) and other players see the effect. Copy rules: say the multiplier, the duration and the scope ("this server only"), show remaining time on the card ("ACTIVE 12:31"), and stack by extending duration.

### Direct sale versus random
Selling a specific item outright ("Get the weapon instantly", 799) is simple and needs no odds disclosure. Selling a guaranteed-minimum random roll ("next roll Legendary or better", 499) is a paid random item: you must show every possible outcome with numerical odds summing to 100% before purchase ([[Roblox Policies Ratings and Compliance]]).

### Exclusives and rotation
The reference project added an EXCLUSIVE tier: items never rolled or dropped, only bought, rotating weekly with a countdown on the card. Rotation creates urgency without fake scarcity, as long as the timer is real. Two cautions:
- **Refuse off-rotation items at prompt time, never in `ProcessReceipt`** (see [[Developer Products and ProcessReceipt]]).
- **Tradeable exclusives plus regional pricing need the price-level gate** from section 1.

---

## 4. Store layout

### Structure
The reference shop evolved into sections stacked in one scroll: a featured row (starter pack, current exclusive, a limited deal), passes, gem packs, boosts, and a gem shop. Lessons:
- **Featured first, and personalised.** New players see the starter pack; returning payers see the exclusive. `RankProductsAsync` can order products per player (strict rate limit, call once at join) (Docs).
- **The "starter shop" view.** For players who have never bought anything, open the shop on a short page (starter pack, one cheap pass, one gem pack) instead of the full catalogue. Long lists paralyse first-time buyers. Track it as its own funnel step ([[Analytics and Funnels]]).
- **Each card answers three questions:** what is it (art + name), what does it do (one line, numbers), what does it cost (live price).
- **States:** BUY, OWNED (passes, one-time packs), ACTIVE mm:ss (boosts), COMING SOON (product id not created yet; the reference shop showed a dimmed button and "Coming soon!"), UNAVAILABLE (lookup says not for sale).
- **Phone first.** Many players are on phones. The reference project's shop needed a dedicated phone layout with 54 px minimum tap targets. See [[Responsive UI for Phone Tablet Console and PC]].

### Entry points
- A HUD shop button (always present, never pulsing forever).
- Contextual offers at the moment of need: "out of potions? 3 for 49", a near-miss on a rare roll followed by a luck boost card. Contextual is the strongest converter and the easiest to abuse; keep it optional and dismissible.
- In-world: a shop station with an NPC, billboards for server luck and the starter pack (the reference project used both).

### Pop-up discipline
Unprompted offers must go through one gate. The reference project's rule (one module every pop-up asks):
- never during onboarding, or over the tutorial-complete moment;
- never while a panel is open, during a roll animation, cutscene, death screen or combat;
- never within 8 seconds of another pop-up.

Rule of thumb on top: at most one unprompted offer per session for non-payers in their first session.

### Free channels in the same UI
Codes, daily rewards, group rewards and "like the game" reminders belong near the store. They are part of the value exchange: the reference project's welcome code (cash plus 25 gems) put players into the gem economy before asking them to buy gems. See [[Menu Archetypes - Shop Settings Codes Rewards]].

---

## 5. Product reconfiguration

Products change: prices, contents, ids. Rules:
- **Keys are forever.** Code, receipts, "bought" flags and analytics refer to a stable key ("StarterPack"). The dashboard id can change behind it.
- **Changing contents.** Announce it. Players who bought the old contents keep them. The reference project re-pointed a 799 weapon product to a different item after a rarity re-tier and kept the key.
- **Removing a product.** Take it off sale first, keep its grant code for pending receipts, then remove the card. The reference project deleted a pack's card but kept its config entry for this reason.
- **Changing prices.** Not while a price test runs (Docs). For subscriptions, Robux prices change at most every 60 days with 30 days' notice (Docs).
- **Description drift.** Keep descriptions generated from the same numbers the code uses. The reference VIP description once said "1.5x Cash" while the perk table gave 2x.

---

## 6. Common mistakes
- Hard-coded prices (wrong for regional, test and Plus players).
- A "70% off!" label that is not computed from real prices.
- Selling currency with nothing worth buying.
- A starter pack shown on join, before the player knows what anything is.
- Shop opens with 40 cards for a first-time player.
- Gifting or trading paid items across price levels with no gate.
- Changing a product's contents silently.

## 7. Checklist
- [ ] Every price on screen comes from `GetProductInfoAsync` (Dynamic Price Check passes)
- [ ] Price-level gate on gifts and trades of paid items
- [ ] Ladder of 3 to 5 rungs per category; value per Robux increases with size
- [ ] Starter pack: once per player, shown after a win, hidden when owned
- [ ] Card states: BUY / OWNED / ACTIVE / COMING SOON / UNAVAILABLE
- [ ] All unprompted offers go through one pop-up gate
- [ ] Random products show full odds; luck boosts show numbers
- [ ] Product keys stable; retired products keep grant code

## See also
[[Monetization Overview]] · [[Game Passes]] · [[Developer Products and ProcessReceipt]] · [[Subscriptions and Premium Payouts]] · [[Menu Archetypes - Shop Settings Codes Rewards]] · [[UI Design Systems]] · [[Economies and Currencies]] · [[Balancing with Spreadsheets and Data]] · [[Ethical Design and Player Trust]] · [[UI and GUI Animation]]

## Connected notes
<!-- auto-links:start -->
[[Robux Price Points and Offer Design]] · [[Skill - Roblox Monetization Compliance]] · [[Limited-Time Offers - Design and Ethics]] · [[Shop with Game Passes and Developer Products End to End]] · [[Genre Playbook - Simulators]] · [[Currency Architecture - Soft Hard and Event Currencies]]
<!-- auto-links:end -->
