---
tags: [economy, inflation, sinks, faucets, balancing, live-ops, math, luau, type/guide, area/monetization, level/intermediate, area/economy]
---
# Economy Inflation Sinks and Faucets Math

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Prices tuned one by one -> Derive all prices from one income model
> - Avoid: `p < g` -> Raise `p` for new content
> - Avoid: Unbounded multiplicative stacking -> Additive buckets, declared max gap
> - Target time-to-afford bands written down per purchase type.
> - Income and price growth per zone known; `p / g` checked.
> - Maximum payer gap declared; all multipliers stack by a defined rule.
>
> Cost: TL;DR ~140 tok · whole note ~4.6k tok. Read more: ## 1. The one number that matters: time to afford · ## 4. Measuring inflation instead of guessing · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Economies and Currencies]] explains what faucets and sinks are and how to write transactions safely. This note is the arithmetic underneath: how to model time-to-afford across an exponential progression, how multipliers stack into a payer gap, how to tell real inflation from healthy growth, how item supply works in RNG games, and how to simulate a live change before you ship it. Every formula comes with a worked example and the failure it predicts.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**. The maths is standard; the target numbers are rules of thumb unless labelled.

---

## 1. The one number that matters: time to afford

Players do not feel prices or incomes. They feel **how long until the next thing they want**. Define for each purchase:

```
T = P / I
```

where `P` is the price and `I` is the player's income per minute **at the point where that purchase becomes relevant**. Everything else in this note is a way of keeping `T` inside a band you chose on purpose.

Rule of thumb bands for a session-based Roblox game:

| Purchase type | Target `T` (active play) |
|---|---|
| Small upgrade, consumable | 1 to 3 minutes |
| Meaningful upgrade (skill node, forge level) | 5 to 15 minutes |
| Zone gate, big unlock | 15 to 45 minutes |
| Prestige or rebirth | 1 to 3 sessions |

The point of the table is not the numbers but that you have one. An economy without target times drifts, because every individual price change looks reasonable.

### Exponential progressions

Simulators and RNG games grow both income and prices geometrically. Let zone `k` have income `I_k = I_0 · g^k` and gate price `P_k = P_0 · p^k`. Then:

```
T_k = (P_0 / I_0) · (p / g)^k = T_0 · r^k,   where r = p / g
```

Only the ratio `r` matters.

**Worked example.** `I_0 = 2,000` per minute, `P_0 = 20,000`, so `T_0 = 10` minutes.

| Growth | `r` | `T` at zone 9 |
|---|---|---|
| `g = 3`, `p = 3.3` | 1.1 | 10 · 1.1^9 ≈ 23.6 min |
| `g = 3`, `p = 3.0` | 1.0 | 10 min |
| `g = 3`, `p = 2.7` | 0.9 | 10 · 0.9^9 ≈ 3.9 min |

A 10% difference in price growth per zone turns a game that slows down pleasantly into one where the late game is a blur. This is the most common hidden inflation: no single gate looks wrong, but the late zones are far too cheap relative to income there.

**Measured in the reference project.** Gate prices ran from 2.5K at the first gate to hundreds of millions at the tenth, with income from roughly 2K per minute in zone 1 to about 40M per minute at the final boss ([[Progression Levels and Unlocks]]). Income growth of 20,000x across the run means any price curve that does not track it collapses. After a difficulty pass (cash x0.55, higher gate prices) the team found the forge was still priced against the old income model: an upgrade that should have cost about 12 to 15K cost 150K. A system priced by hand instead of from the income model is the usual culprit.

### Carry-over and farming

`T_k` assumes the player arrives with zero balance. In practice they arrive with whatever they earned while finishing the previous zone. If players can farm zone `k` indefinitely, they arrive at `k+1` with enough for several gates and skip content. Two fixes:

- **Income that falls off in old zones.** Enemy rewards scale with the zone, and the best farming spot is always the newest unlocked one.
- **Rewards scaled to the next price.** The reference project's quests pay a share of the next gate's price (measured), so a quest is worth the same fraction of progress anywhere.

---

## 2. Multiplier stacking and the payer gap

Income multipliers come from passes, potions, traits, rebirths, events and friends bonuses. How they combine decides how far ahead a payer is.

| Stacking rule | Formula | Example: VIP 2x, potion 1.5x, trait +20% |
|---|---|---|
| Multiplicative | `m = Π m_i` | 2 · 1.5 · 1.2 = 3.6x |
| Additive bonuses | `m = 1 + Σ (m_i - 1)` | 1 + 1 + 0.5 + 0.2 = 2.7x |
| Additive within a category, multiplicative across | `m = Π_c (1 + Σ bonus in c)` | depends on grouping |

A free player with only the trait runs at 1.2x. With multiplicative stacking a fully boosted payer reaches 3.6x, so their `T` is one third of the free player's. With additive stacking the payer is at 2.7x, 2.25 times the free player.

Rules of thumb:

- **Decide the maximum gap on purpose.** Write it down: "a payer with every permanent pass progresses at most 3x faster than a free player at equal effort". Then check every new multiplier against it.
- **Multiplicative stacking explodes when the number of sources grows.** Five 1.5x sources multiply to 7.6x. Additive stacking within categories (all potions in one bucket, all passes in another) keeps the ceiling predictable.
- **Apply multipliers in one function** and show the breakdown in one tooltip ([[Economies and Currencies]]). The reference project's VIP pass description once said 1.5x while the code gave 2x (measured); a single source of truth prevents that.
- **Social multipliers are cheap goodwill.** A small "playing with friends" bonus raises income without widening the payer gap ([[Social Design and Multiplayer Play]]).

---

## 3. Rebirth and prestige: the biggest sink

A rebirth destroys a player's whole balance (and often their gates) in exchange for a permanent multiplier. It is the most powerful sink you have, and it obeys simple arithmetic.

Let the total currency needed to reach the rebirth point be `C`, and the rebirth multiplier after `n` rebirths be `M(n)`. Time for run `n` is roughly `C / (I · M(n))`.

**Worked example** with an additive `M(n) = 1 + 0.5n`:

| Rebirth `n` | `M(n)` | Run time vs first run | Saving vs previous run |
|---|---|---|---|
| 0 | 1.0 | 100% | |
| 1 | 1.5 | 67% | 33% |
| 2 | 2.0 | 50% | 25% |
| 5 | 3.5 | 29% | 14% |
| 10 | 6.0 | 17% | 8% |

Diminishing returns: by the tenth rebirth each new one saves only 8%. Two consequences:

- **If the rebirth cost `C` is constant**, runs get shorter and shorter until rebirthing is a few minutes of play. Scale `C` with `n` (for example `C(n) = C_0 · 1.25^n`) so run time stays in your target band.
- **If the multiplier is multiplicative** (`M(n) = 1.5^n`), run time halves every 1.7 rebirths and any constant cost collapses quickly. Then `C(n)` must grow at the same rate, which makes the multiplier cosmetic. Prefer additive multipliers with escalating costs, and give rebirths a second reward (a slot, an ability, a cosmetic) so the decision is not purely numeric.

---

## 4. Measuring inflation instead of guessing

"Players have a lot of money" is not inflation in an exponential game; it is the design. Inflation is **purchasing power falling**: balances growing faster than the prices of the things players want.

Three metrics, all computable from `AnalyticsService:LogEconomyEvent` data (Roblox docs, as of October 2026: per experience at most 5 currency types, 20 transaction types and 100 item SKUs, so plan names before you log; see [[Analytics and Funnels]]):

1. **Hours of income held** `H = balance / income per hour`, per player at save time. If median `H` for mid-game players rises week over week, they are not finding things to buy. Rule of thumb: a healthy mid-game `H` is under 1 to 2 hours. A late-game `H` of 20+ means you have no top-end sink.
2. **Sink to faucet ratio** `S / F` per currency per day, aggregate. In a closed soft-currency economy with a fixed population it should hover near 1 once players settle. In a growing exponential game it will sit below 1 (balances rise with progress), so watch the trend, not the level: a ratio falling over several weeks while content is unchanged means sinks are losing.
3. **Time to afford, observed.** Median and 90th percentile time from unlocking a zone to buying its gate, from funnel events. Compare to your `T_k` model. If observed `T` at zone 7 is a quarter of the model, something is feeding currency you did not model (a code, an event, an exploit).

### Spotting a faucet you did not model

A sudden drop in observed `T` everywhere, without a release, points to a code or an event left on. A drop in one zone points to a farm spot. A drop concentrated in a few accounts points to an exploit or a duplication bug ([[Trading Systems Without Duplication]]). Break faucet totals down by transaction type (`Gameplay`, `TimedReward`, `Onboarding`, `IAP`, `Shop`, `ContextualPurchase` are the docs' enum members) and by item SKU: the outlier source is usually obvious once separated.

---

## 5. Item economies: supply, luck and copy sinks

In RNG and collection games the main "currency" is items. Their supply follows directly from rolls and odds.

```
copies of item i per day = rolls per day · p_i · L_i
```

where `p_i` is the base chance and `L_i` the average luck multiplier applied to it. If the player base makes 50 million rolls a day and an item has a 1 in 1,000,000 chance at average luck 2x, about 100 copies enter the game daily. In a month that is 3,000. If players can trade, its market value falls accordingly unless something consumes copies.

**Copy sinks.** Fusion, crafting and salvage destroy copies. Measured in the reference project: fusing three identical items gives +1 star, up to five stars, so a max-star item consumes 3, 9, 27, 81 and finally 243 base copies; crafting turns five items of one rarity into one random item of the next. Arithmetic for a 1 in 10,000 item: a max-star copy needs 243 copies, about 2.43 million rolls at base luck. That is a sink that scales with supply and gives a reason to keep rolling for items you already own.

**Luck inflation.** Every luck source (passes, server boosts, events, potions) raises `L`. Raising average luck from 2x to 4x doubles the supply of every rare item at once, which makes older rare items less special and devalues what payers already own. Rules of thumb:

- Cap total luck ([[RNG Drops and Luck Systems]]); show the cap.
- Add new top tiers instead of inflating luck for existing ones.
- Treat a permanent luck increase like printing money: model the supply change before you ship.

**Paid luck is policy-sensitive.** Luck sold for Robux or paid currency is a probability modifier under the paid random items rules: its effect must be explained numerically before purchase and displayed odds must update while it is active ([[Paid Random Items and Odds Disclosure in Practice]]).

---

## 6. Premium currency: the anchor

A premium currency sold for Robux needs a fixed internal value, for example "1 gem is worth about 1 Robux". Every gem price and every free gem reward is then a Robux-equivalent decision.

**Worked example.** A 100-gem pack at 99 Robux sets the anchor at about 1 Robux per gem. A daily VIP bonus of 25 gems (measured in the reference project) gives a VIP holder roughly 750 gems a month for free, about 750 Robux of anchor value, every month, from a pass bought once. That is a design decision worth making consciously: it may be exactly right as a retention hook, or it may make gem packs pointless for your most engaged payers.

Metric: **free share of premium currency** = free gems granted / all gems granted. If it climbs above about half (rule of thumb) the store sells less every month; if it is near zero, free players never learn what gems are for. The reference project added gem sinks (a gem shop, gem-priced forge materials, a gem-priced server boost) before pushing gem packs, because players reported that gems "don't do much" (measured). A premium currency without sinks is not worth selling ([[Robux Price Points and Offer Design]]).

**Never sell premium currency through rewarded ads.** Roblox's rewarded video rules forbid inflationary currency as a reward (Roblox docs, as of October 2026; see [[Ads and Rewarded Video]]).

---

## 7. Simulate before you ship

Spreadsheets model the average player. A tiny simulation catches what averages hide: skewed session lengths, payer gaps, and what happens to someone who plays three times as long. This runs in the Studio command bar with no game state.

```lua
--!strict
-- Economy sim: minutes to reach each gate for players with different multipliers.
local I0, g = 2000, 3.0      -- income per minute at zone 0, growth per zone
local P0, p = 20000, 3.1     -- gate price at zone 0, growth per zone
local ZONES = 10

local function simulate(mult: number, rng: Random): { number }
	local cash, zone, minute = 0, 0, 0
	local reachedAt = table.create(ZONES, 0)
	while zone < ZONES and minute < 100000 do
		-- each minute of play: income at current zone, with +/-20% noise for kill luck
		local income = I0 * g ^ zone * mult * (0.8 + 0.4 * rng:NextNumber())
		cash += income
		minute += 1
		local price = P0 * p ^ zone
		if cash >= price then
			cash -= price
			zone += 1
			reachedAt[zone] = minute
		end
	end
	return reachedAt
end

local rng = Random.new(42)
for _, profile in { { "free", 1.0 }, { "vip", 2.0 }, { "whale", 3.6 } } do
	local times = simulate(profile[2] :: number, rng)
	print(profile[1], table.concat(times, ", "))
end
```

What to look for in the output:

- **The ratio between columns** is your payer gap in practice (it should match section 2).
- **The gaps between gates.** If they shrink zone after zone, `p < g`: late content will be skipped.
- **The total.** If a free player finishes all ten zones in a few hours, your content lasts a few hours, no matter how many zones you made.

Extend it with your real tables (load them from the same config module the game uses, [[Data and Config Pipeline - Spreadsheets to Game]]) and you have a regression test: run it in CI and fail the build when a config change moves total completion time by more than, say, 20%.

---

## 8. Fixing a live inflated economy

Options, from least to most disruptive:

| Fix | Effect | Risk |
|---|---|---|
| Add a top-end repeatable sink (consumables, cosmetic tiers, prestige) | Absorbs surplus going forward | Low; does not fix existing balances |
| Raise prices of new content only | Restores `T` for new zones | Old zones stay cheap; fine if they are behind players |
| Scale faucets down | Slows future inflation | Players notice nerfs; announce them |
| Revalue balances (migration) | Fixes existing surplus | Feels like confiscation; never touch paid value ([[Schema Migrations - Worked Case Studies]]) |
| Reset progress | Clean slate | Trust cost; keep purchases ([[Data Schema Design and Migrations]]) |

**Measured in the reference project:** the team chose a reset early in the game's life when a difficulty pass changed income by large factors, renaming stores so it could be reverted and keeping receipts and settings. Later re-pricings (upgrade board, forge) were done against the new gate ladder without touching balances.

The general lesson: fix the model, then derive every price from it again. Patching the one price players complain about leaves the rest of the system on the old model.

---

## 9. When not to do all this

- **Short-session or round-based games** (obbies, party games) where currency only buys cosmetics: a flat price list and a weekly shop rotation is enough. Inflation math matters when currency buys progress.
- **Pre-launch with no data.** Model, simulate, ship, then measure. Do not tune the 90th percentile before you have one.
- **Tiny populations.** Aggregate ratios are noise below a few hundred daily players; look at individual journeys instead.

---

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Prices tuned one by one | Late zones blur past; one system wildly off | Derive all prices from one income model |
| `p < g` | Observed time to afford shrinks with zone | Raise `p` for new content |
| Unbounded multiplicative stacking | Payers finish in a fraction of free time | Additive buckets, declared max gap |
| Constant rebirth cost | Rebirth runs of a few minutes | Scale cost with rebirth count |
| Permanent luck increases | Rare items flood the market | Cap luck, add tiers instead |
| Generous free premium currency | Gem pack sales fall month over month | Track free share |
| Measuring balances, not purchasing power | False alarms in exponential games | Hours of income held |
| Fixed rewards in an exponential game | Late quests worthless | Scale to next price |

## Checklist

- [ ] Target time-to-afford bands written down per purchase type.
- [ ] Income and price growth per zone known; `p / g` checked.
- [ ] Maximum payer gap declared; all multipliers stack by a defined rule.
- [ ] Rebirth cost scales with rebirth count.
- [ ] Hours of income held, sink/faucet trend and observed `T` on a dashboard.
- [ ] Item supply per day modelled for every top-tier item; copy sinks exist.
- [ ] Premium currency anchor value fixed; free share tracked.
- [ ] Simulation runs against real config in CI.
- [ ] Live fixes chosen from the least disruptive option that works; paid value never reduced.

## See also
[[Economies and Currencies]] · [[Progression Levels and Unlocks]] · [[Balancing with Spreadsheets and Data]] · [[RNG Drops and Luck Systems]] · [[Analytics and Funnels]] · [[Genre Playbook - Simulators]] · [[Genre Playbook - RNG and Collection Games]] · [[Robux Price Points and Offer Design]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Trading Systems Without Duplication]] · [[Schema Migrations - Worked Case Studies]] · [[Live Ops Events and Updates]]

## Connected notes
<!-- auto-links:start -->
[[Faucets and Sinks]] · Simulating an Economy Before Launch · Currency Architecture - Soft Hard and Event Currencies · Economy Telemetry and Balancing Live · Pricing Curves and Upgrade Costs · Economy Design Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Pricing Curves and Upgrade Costs]] · [[Simulating an Economy Before Launch]] · [[Monetization Overview]] · [[Pricing and Store Design]] · [[Roblox Policies Ratings and Compliance]] · [[Game Passes]] · [[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]] · [[Refunds Chargebacks and Purchase Support]] · [[Discovery and the Algorithm]]
<!-- related:end -->
