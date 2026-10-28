---
tags: [monetization, pricing, offers, robux, store, experiments, luau]
---
# Robux Price Points and Offer Design

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Hard-coded prices in UI -> Live lookups (Pricing and Store Design)
> - Avoid: Ladder with a worse-value rung -> Monotone value assert at boot
> - Avoid: Bonus labels typed by hand -> Compute from grant table
> - Every category has 3 to 5 rungs with rising value per Robux.
> - Bonus labels computed; ladder validated at boot.
> - Impulse rung under 100 exists.
>
> Cost: TL;DR ~130 tok · whole note ~4.6k tok. Read more: ## 2. Building a ladder with real value math · ## 5. An offer engine on the server · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Pricing and Store Design]] covers the platform mechanics (managed pricing, showing live prices, store layout). This note goes one level deeper into two questions that decide most of a game's revenue: **which numbers** to put on products, and **which offer** to show **which player** at **which moment**. It includes the arithmetic for value ladders and net revenue, a server-side offer engine in Luau, how to run experiments without fooling yourself, and where offer design turns into a trust problem.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**. Roblox publishes no recommended price points; everything about "good" prices here is rule of thumb.

---

## 1. What the player is actually spending

A Roblox player does not pay cash at your prompt. They spend from a Robux balance that they (or a parent) filled earlier, usually with a fixed Robux bundle or a gift card. Three consequences shape pricing:

- **Balances are lumpy.** A player who just bought a bundle has a balance near one of the bundle sizes. A price slightly under a common bundle size fits in one purchase; a price slightly over forces a second bundle purchase, which is a much bigger decision. Check the current bundle sizes on the Robux purchase page for the platforms your players use. They have differed between web and mobile app stores and have changed over time; this vault does not list them (unverified, as of October 2026).
- **Leftovers matter.** After a 399 purchase from a fresh bundle, the leftover is what the next impulse product competes for. An impulse rung under 100 (the reference project used 75, 79 and 99) catches leftovers.
- **Many payers are children spending gifted Robux.** The balance is finite and the decision is "what is the best thing I can get with what I have". Clear value per Robux and honest descriptions beat pressure, and pressure aimed at children is an ethics and policy problem ([[Ethical Design and Player Trust]]).

### What you receive

For passes and developer products sold in your experience, plan on **70% of the listed price**: a 100 Robux item earns 70 Robux, and it stays 70 even when a Roblox Plus subscriber pays a discounted 90 or 80, because Roblox covers the discount (Roblox docs, as of October 2026). Regional pricing can lower what the player pays to between 30% and 100% of your default (Roblox docs), and then your share is of the lower price. Your config price is an upper bound, not your revenue: use the Robux amount in the receipt for revenue analytics ([[Developer Products and ProcessReceipt]]).

```
net Robux per sale ≈ 0.70 · listed price · regional factor     (regional factor 0.3 to 1.0)
```

**Worked example.** A 499 product sold 1,000 times in a month to a mix where 70% pay full price and 30% pay at a 0.6 regional factor: `0.70 · 499 · (0.7 · 1.0 + 0.3 · 0.6) · 1000 ≈ 307,000` Robux, not the 349,300 you get from `0.7 · 499 · 1000`. Hold periods also delay availability; see [[Monetization Overview]].

---

## 2. Building a ladder with real value math

A product category (gem packs, boost bundles, luck potions) should be a ladder of three to five rungs where **value per Robux rises with size**, and where every rung has a reason to exist.

Define the baseline as the smallest rung. For each rung `i` with amount `A_i` at price `P_i`:

```
value per Robux   v_i = A_i / P_i
bonus %           b_i = (v_i / v_1 - 1) · 100
```

**Worked example: gem packs.**

| Rung | Gems | Price | Gems per Robux | Bonus vs smallest |
|---|---|---|---|---|
| Small | 100 | 99 | 1.01 | 0% |
| Medium | 600 | 449 | 1.34 | +32% |
| Large | 1,300 | 899 | 1.45 | +43% |
| Huge | 3,000 | 1,999 | 1.50 | +49% |

Check the ladder with three tests (rule of thumb):

1. **Monotone value.** `v_i` strictly rises. A rung with worse value than the one below it is a trap, and players notice.
2. **Diminishing marginal bonus.** The jump in bonus should shrink as price rises, or the top rung makes every other rung look foolish and you lose the mid-tier buyers who would never spend 1,999.
3. **Labels computed, not typed.** The "+49%" label must come from the same numbers the grant uses. A typed label drifts the first time someone changes an amount (measured in the reference project: a pass description that said 1.5x while code gave 2x).

```lua
--!strict
-- ReplicatedStorage/Offers/Ladder (ModuleScript): labels derived from the grant table.
export type Rung = { Key: string, Amount: number, Price: number }

local Ladder = {}

function Ladder.Bonuses(rungs: { Rung }): { [string]: number }
	assert(#rungs > 0, "empty ladder")
	local base = rungs[1].Amount / rungs[1].Price
	local out: { [string]: number } = {}
	local prev = 0
	for i, r in rungs do
		local v = r.Amount / r.Price
		assert(i == 1 or v > prev, `rung {r.Key} has worse value than the rung below`)
		prev = v
		out[r.Key] = math.floor((v / base - 1) * 100 + 0.5)
	end
	return out
end

return Ladder
```

Run `Ladder.Bonuses` at boot on the server too: the `assert` turns a mispriced ladder into a Studio error instead of a support problem.

**Regional pricing caveat.** Labels computed from your config prices are correct in ratios only while all rungs get the same regional factor. Roblox applies managed prices per product, so in some regions the ratios may shift. Showing the bonus in units of the item ("+500 gems free") instead of a percentage avoids claiming a value ratio you cannot guarantee for every player.

---

## 3. Choosing the numbers

Rules of thumb, from simulator and RNG games including the reference project's shop (75, 79, 99, 199, 299, 399, 499, 599, 799, 999, 1,499):

| Rung | Range | Job |
|---|---|---|
| Impulse | under 100 | First purchase, leftovers, consumables |
| Core | 150 to 600 | Permanent passes, main bundles |
| Premium | 700 to 1,500 | Direct-sale exclusives, big bundles, gifts |
| Whale | 2,000+ | Only if repeatable value exists (currency, consumables) |

- **Ending in 9** is the platform convention. It costs nothing, and a round number looks out of place in a shop where everything else ends in 9. It does not create value by itself.
- **Leave room between rungs.** If two products cost 399 and 449, the cheaper one is chosen almost every time unless the extra is obvious.
- **Price permanent multipliers by lifetime value.** A 2x income pass is worth more to a player who will play 50 hours than a consumable. The same Robux on a permanent pass should buy something structurally better than a one-hour boost.
- **Do not price whale rungs into one-time items.** A 4,999 one-time pass converts a handful of people once. A 1,999 currency pack converts the same people repeatedly.

**Price optimization.** Games with roughly 60,000 or more transactions in 30 days can let Roblox test prices on passes and developer products and recommend new defaults; tests take about three weeks, rerun at least every 90 days, and you cannot change a tested product's price during a test (Roblox docs, as of October 2026; details in [[Pricing and Store Design]]). If you qualify, use it for the numbers and spend your own effort on offer content and timing, which Roblox does not test for you.

---

## 4. Offer types and what each one is for

| Offer | Shown to | Purpose | Main risk |
|---|---|---|---|
| Starter pack | Non-payers after a win | Convert a first-time payer | Shown too early, before value is understood |
| First-purchase bonus | Non-payers | Double the first currency pack | Players wait for it instead of buying |
| Contextual offer | A player at a moment of need (out of potions, near-miss roll, lost a boss fight) | Highest conversion | Easiest to abuse; feels predatory if frequent |
| Limited-time rotation | Everyone | Urgency with real scarcity | Fake timers destroy trust |
| Bundle | Payers | Raise spend per transaction | Bundles containing random items are paid random items |
| Upsell after purchase | A player who just bought | Next rung up | Annoying if immediate and repeated |
| Comeback offer | Lapsed players returning | Re-engage | Teaches players to lapse |
| Subscription | Regular players | Recurring value | Needs a daily loop to attach to ([[Subscriptions and Premium Payouts]]) |

Two rules apply to all of them:

- **The value must be real and computed.** "Was 999, now 499" is only honest if the item really sold at 999 and the bundle really contains 999 worth at your anchor values ([[Economy Inflation Sinks and Faucets Math]]).
- **Random contents are policy-bound.** A bundle with a random item, a guaranteed-minimum roll, or a luck boost must show odds or numerical effects before purchase ([[Paid Random Items and Odds Disclosure in Practice]]). The reference project's "next roll Legendary or better" product (499) is a paid random item, while its direct-sale weapons (799, 999) are not.

---

## 5. An offer engine on the server

Hard-coded "show the starter pack after the tutorial" logic spreads into ten scripts and becomes impossible to reason about. A small engine keeps every unprompted offer behind one gate: who is eligible, how often, which wins.

```lua
--!strict
-- ServerScriptService/Offers/OfferEngine (ModuleScript)
export type Ctx = {
	profile: any,         -- the player's loaded profile
	moment: string,       -- "TutorialDone" | "NearMiss" | "BossLost" | "ShopOpen" | ...
	now: number,
	sessionOffers: number, -- unprompted offers shown this session
	lastOfferAt: number,
}

export type Offer = {
	Key: string,           -- stable product key, never the numeric id
	Moments: { [string]: boolean },
	Priority: number,      -- higher wins
	MaxPerPlayer: number?, -- lifetime cap (one-time packs)
	CooldownSec: number,   -- per player, per offer
	Eligible: (Ctx) -> boolean,
}

local GLOBAL_GAP_SEC = 8           -- measured in the reference project: no pop-up within 8 s of another
local MAX_UNPROMPTED_NONPAYER = 1  -- rule of thumb: first session, non-payers

local Offers: { Offer } = {
	{
		Key = "StarterPack",
		Moments = { TutorialDone = true, BossWon = true },
		Priority = 100,
		MaxPerPlayer = 1,
		CooldownSec = 6 * 3600,
		Eligible = function(c) return (c.profile.Spent or 0) == 0 end,
	},
	{
		Key = "LuckBoost15",
		Moments = { NearMiss = true },
		Priority = 50,
		CooldownSec = 1800,
		Eligible = function(c) return (c.profile.Rolls or 0) >= 50 end,
	},
}

local OfferEngine = {}

function OfferEngine.Pick(c: Ctx): Offer?
	if c.now - c.lastOfferAt < GLOBAL_GAP_SEC then
		return nil
	end
	local isPayer = (c.profile.Spent or 0) > 0
	if not isPayer and c.sessionOffers >= MAX_UNPROMPTED_NONPAYER then
		return nil
	end
	local seen = c.profile.OfferSeen or {}  -- [key] = { n = count, t = lastShown }
	local best: Offer? = nil
	for _, o in Offers do
		if not o.Moments[c.moment] then continue end
		local s = seen[o.Key]
		local bought = (c.profile.Bought or {})[o.Key] or 0 -- purchase count per key
		if o.MaxPerPlayer and bought >= o.MaxPerPlayer then continue end
		if s and c.now - s.t < o.CooldownSec then continue end
		if not o.Eligible(c) then continue end
		if best == nil or o.Priority > best.Priority then
			best = o
		end
	end
	return best
end

return OfferEngine
```

How it is used: gameplay code fires a moment ("NearMiss") to the offer service; the service asks the engine, records `OfferSeen` in the profile, and tells the client to show the card. The client never decides to show an offer on its own, and the purchase prompt is still validated on the server before `PromptProductPurchase` ([[Developer Products and ProcessReceipt]]).

The global gate also needs blocking states the server knows about: never during onboarding, combat, a roll animation, a cutscene or with another panel open (the reference project's pop-up rules, measured; see [[Pricing and Store Design]]). Add a `Blocked(player)` check before `Pick`.

**Personalisation from Roblox.** `MarketplaceService:RankProductsAsync` ranks product ids you supply for a player (strict rate limit: call once at join), and `RecommendTopProductsAsync` returns up to 50 items only if the game had a purchase in the last 28 days (Roblox docs, as of October 2026). Use ranking to order the shop's featured row; keep moment-based offers in your engine, because Roblox does not know about your moments.

---

## 6. Timing: the moment beats the price

The same product converts very differently depending on when it appears. Rules of thumb:

- **After a success, not after a failure,** for permanent purchases. A starter pack after the first boss win says "this is fun, get more of it". After a death it says "pay to stop losing".
- **After a failure, only for small, clearly helpful consumables,** and dismissible with one tap. "Revive for 25" after a boss loss can be fine; a 999 bundle there is not.
- **Near-miss rolls** are the strongest moment in RNG games and the most ethically loaded. Showing a luck boost after a near miss is common; make sure the card states the exact effect and duration ("x2 luck for 15 minutes, this server") and that the player has not just seen another offer.
- **Never in the first minutes.** Before players understand what a currency buys, a currency offer is noise. The reference project's welcome code gave a small gem amount early so players learned what gems were for before being asked to buy them (measured).

---

## 7. Experiments without fooling yourself

Revenue is noisy. A handful of large purchases moves a day's numbers more than any design change. Rules of thumb:

- **Measure per player, not per day.** Conversion = payers / players exposed; revenue per daily active user; ARPPU (average revenue per paying user). Compare cohorts that started in the same period.
- **Assign cohorts deterministically.** Hash the user id so a player always sees the same variant across servers and sessions.

```lua
--!strict
-- Stable 0..99 bucket per user and experiment name.
local function bucket(userId: number, experiment: string): number
	local h = 0
	for i = 1, #experiment do
		h = (h * 31 + string.byte(experiment, i)) % 2147483647
	end
	h = (h * 31 + userId) % 2147483647
	return h % 100
end
-- Variant B for buckets 0..49:
-- local variant = if bucket(player.UserId, "starter_after_boss") < 50 then "B" else "A"
```

- **Test content and timing, not prices.** Roblox's price optimization exists for prices. Showing different players different prices for the same thing through your own duplicate products is a fairness and trust risk, and whether it is acceptable under current policy is not something this vault could confirm (unverified, as of October 2026). Testing *when* the starter pack appears, or *what* is in a bundle at the same price, carries no such risk.
- **Run long enough.** Rule of thumb: at least a full week (weekday and weekend behaviour differ) and until each variant has at least a few hundred exposed payers-to-be; with fewer, treat results as hints.
- **Watch the guardrails,** not only revenue: first-play bounce, D1 retention, session length. Roblox's discovery ranking uses retention and playtime as well as spend signals ([[Discovery and the Algorithm]]). An offer that lifts revenue and drops D1 retention costs you distribution.
- **Cannibalisation.** A new 299 bundle that "makes 10,000 Robux a week" may have taken 9,000 from the 399 pass. Compare total revenue per user, not the product's own line.

Log each impression and outcome with `AnalyticsService` so funnels can show impression, click, prompt, purchase ([[Analytics and Funnels]]).

---

## 8. When not to

- **PvP games with direct power purchases.** Selling raw damage in competitive modes damages retention among the free majority that payers need to play against. Sell convenience, cosmetics and progression speed instead, or separate matchmaking.
- **Before the loop works.** If D1 retention is poor, offers are rearranging the deck chairs ([[Retention and Return Hooks]]).
- **Comeback discounts for a game with a short-term audience.** They teach players to leave and wait.
- **Countdown timers on things that never end.** If the "limited" offer returns every week unchanged, players learn the timer is fake, and every real timer loses power.

---

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Hard-coded prices in UI | Dynamic Price Check flags mismatches | Live lookups ([[Pricing and Store Design]]) |
| Ladder with a worse-value rung | Near-zero sales of one rung | Monotone value assert at boot |
| Bonus labels typed by hand | Support tickets quoting wrong numbers | Compute from grant table |
| Offers decided in many client scripts | Players see two pop-ups at once | One server engine, global gap |
| Revenue computed from config prices | Analytics disagree with payouts | Use receipt amounts |
| Testing prices by duplicate products | Players compare and feel cheated | Use price optimization; test content |
| Judging a test on two days of revenue | Results flip next week | Per-player metrics, a week minimum |
| Random items inside a bundle without odds | Policy exposure | Disclose or remove |

## Checklist

- [ ] Every category has 3 to 5 rungs with rising value per Robux.
- [ ] Bonus labels computed; ladder validated at boot.
- [ ] Impulse rung under 100 exists.
- [ ] Revenue projections use 70% share and regional factors.
- [ ] One server-side offer engine with moments, cooldowns, caps and a global gap.
- [ ] Permanent offers after successes; consumables only, and dismissible, after failures.
- [ ] Experiments use stable user buckets, run a week or more, watch retention guardrails.
- [ ] Bundles with random contents carry full odds.
- [ ] Every timer is real.

## See also
[[Pricing and Store Design]] · [[Monetization Overview]] · [[Developer Products and ProcessReceipt]] · [[Game Passes]] · [[Subscriptions and Premium Payouts]] · [[Analytics and Funnels]] · [[Economy Inflation Sinks and Faucets Math]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Ethical Design and Player Trust]] · [[Menu Archetypes - Shop Settings Codes Rewards]] · [[Discovery and the Algorithm]]

## Connected notes
<!-- auto-links:start -->
[[Limited-Time Offers - Design and Ethics]] · [[Skill - Roblox Monetization Compliance]] · [[Currency Architecture - Soft Hard and Event Currencies]] · [[Economies and Currencies]] · [[Shop with Game Passes and Developer Products End to End]] · [[Economy Design Start Here]]
<!-- auto-links:end -->
