---
tags: [game-design, balancing, spreadsheets, economy, simulation, analytics]
---
# Balancing with Spreadsheets and Data

Balancing is turning design intent ("zone 5 should take about ten minutes", "a Mythic should feel twice as strong as a Legendary") into numbers, then checking those numbers against what real players do. The spreadsheet is where intent becomes numbers; simulation checks the randomness; live analytics checks the players. This note shows how to lay out a balance sheet for a Roblox game, the formulas that matter (curves, time per step, expected value, odds, power fits), how to simulate RNG in Luau, and how to close the loop with live data.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production RNG combat game, anonymised), **Rule of thumb**.

---

## 1. Why a sheet, not scattered constants

Balance numbers in scripts drift: someone edits a gate price in one place, a quest reward formula in another, and the relationship between them (the thing that actually matters) is lost. A sheet keeps:
- **inputs** in one place (base prices, growth rates, drop chances);
- **derived** values computed from inputs, never typed by hand;
- **outputs** that express intent in human terms: minutes per zone, rolls to the next tier, hits to kill.

The sheet then exports to a config module (by hand, a CSV, or a script). The game reads only that module. See [[Global State and Live Config]] for serving it live.

### Recommended tabs

| Tab | Rows | Key columns |
|---|---|---|
| Inputs | One per constant | name, value, unit, note, last changed |
| Ladder | One per zone/stage | price, enemy HP, enemy damage, cash per kill, kills per minute, income per minute, minutes to afford next, cumulative hours |
| Items | One per item | rarity, odds (1 in N), probability, power, income, health, power per log-odds |
| Rarity | One per tier | odds range, expected rolls, expected minutes, cap zone |
| Sources and sinks | One per flow | currency, per-hour rate at zone z, share of total |
| Monetisation | One per product | price, what it changes, effect in "minutes saved" |
| Scenarios | One per player type | casual, average, grinder, payer: rolls/min, kills/min, multipliers |

Version the sheet (date in the file name, or the sheet's own history) and write down **why** each number changed. The reference project marked one pass as final ("never run the regrade tooling over it without the owner's OK") after an automated re-run nearly overwrote hand-tuned difficulty. Freeze tuned passes explicitly.

---

## 2. Ladder formulas

Assume column A holds the zone number starting at row 5, and Inputs holds named values. Formulas below are written in spreadsheet syntax (Google Sheets and Excel both accept them).

| Column | Meaning | Formula (row 5) |
|---|---|---|
| A | Zone z | 1, 2, 3, ... |
| B | Gate price | `=GatePrice0 * GateGrowth ^ (A5 - 1)` |
| C | Enemy HP | `=HP0 * HPGrowth ^ (A5 - 1)` |
| D | Player DPS at this zone | from the Items/Scenario tabs (expected best weapon reachable) |
| E | Seconds to kill | `=C5 / D5` |
| F | Kills per minute | `=60 / (E5 + TravelSeconds)` |
| G | Cash per kill | `=Cash0 * CashGrowth ^ (A5 - 1)` |
| H | Income per minute | `=F5 * G5 * IncomeMult` |
| I | Minutes to afford next gate | `=B6 / H5` |
| J | Cumulative hours | `=J4 + I5 / 60` |

The output that matters is column I. Plot it. You want the sawtooth described in [[Progression and Pacing Design]]: gently rising inside a region, a drop at each new income source.

### Pricing everything in minutes
Once you have income per minute (H), price other things as minutes at the zone where they unlock:

```
Price = MinutesTarget * H(unlockZone)
```

The reference project re-priced its whole upgrade board this way: first-ring upgrades about 1 to 2 minutes of income, capstones about 1 to 2 hours, from an income model of roughly $1.5K to $3K per minute in zone 1 up to about $12M per minute in zone 9 and $40M at the zone-10 boss. When income is retuned later, the prices follow automatically.

### Sanity rows
Add rows that flag problems automatically:
- `=IF(I5 > 3 * I4, "SPIKE", "")`: a step that suddenly takes three times longer.
- `=IF(E5 < 0.5, "ONE-SHOT", "")`: enemies dying faster than their hit reaction plays.
- `=IF(J5 > TargetHours, "TOO LONG", "")`.

---

## 3. Expected value

Roblox's own economy guide uses expected value (EV) as the core tool for estimating the impact of any random reward (Docs, "Balance virtual economies"):

```
EV = sum over outcomes of (value * probability)
```

Its worked example: a fishing game with catfish (70%, 10G), trout (20%, 20G) and salmon (10%, 30G) gives 7 + 4 + 3 = **14G per cast**, so 1,000 casts a day produce 14,000G. A 24-hour event that added a Golden Salmon (0.1%, 1,000G) without estimating it flooded the economy: spending rose, store purchases stayed flat, and revenue fell after the event. With the event fish, EV rises by about 0.001 x 1,000 = 1G per cast (about +7%) **before** counting the extra fishing the event causes, which was the real problem.

The docs' recommendations: compute EV for every probability-based reward before launch, plan a sink for every new source, and give events their own currency and shop so the main economy is protected.

In a sheet:

| Outcome | Probability | Value | EV term |
|---|---|---|---|
| Catfish | 0.70 | 10 | `=B2*C2` |
| Trout | 0.20 | 20 | `=B3*C3` |
| Salmon | 0.10 | 30 | `=B4*C4` |
| **Total** | `=SUM(B2:B4)` (must be 1) | | `=SUMPRODUCT(B2:B4, C2:C4)` |

Always include the probability check column. A table whose probabilities do not sum to 1 is the most common bug in reward tables, and for paid random items it is also a policy issue: displayed percentages must sum to exactly 100% (Docs, "Paid random items").

---

## 4. Odds and rarity maths

RNG games describe rarity as "1 in N". Convert carefully:

| Quantity | Formula | Example (1 in 1,000) |
|---|---|---|
| Probability per roll | p = 1 / N | 0.001 = 0.1% |
| Expected rolls to get one | 1 / p = N | 1,000 |
| Chance of at least one in k rolls | 1 - (1 - p)^k | k = 1,000: 63.2% |
| Rolls for a 50% chance | ln(0.5) / ln(1 - p) | about 693 |
| Rolls for a 90% chance | ln(0.1) / ln(1 - p) | about 2,302 |
| Rolls for a 99% chance | ln(0.01) / ln(1 - p) | about 4,603 |

The "63% after N rolls" fact surprises players and designers alike: at the advertised odds, **more than a third of players have not hit after N rolls**, and 1 in 100 players needs about 4.6 N. That long tail is where frustration (and complaints) live. Pity systems exist to cut it; see [[Genre Playbook - RNG and Collection Games]].

### Tier probability
If tiers are a set of items each with its own 1 in N, the chance of rolling **anything in a tier** is the sum of its items' probabilities (for a table where probabilities are independent shares of one roll). Expected rolls to reach "tier T or better" is `1 / sum of p for all items in T and above`.

### Expected minutes per tier
```
minutes to tier = (1 / P(tier or better)) / (rolls per minute * luck factor)
```
where the luck factor depends on how luck is implemented. Write that formula down **for your implementation**; luck is not always a simple divisor of N. See section 6 of [[Genre Playbook - RNG and Collection Games]].

### The reference project's rarity ladder
A long ladder: the familiar Common to Legendary tiers, then several more above them, starting with Mythic. After its re-tier, rarer items in the upper tiers spanned roughly:

| Tier | Odds range (1 in N) |
|---|---|
| Epic | 2K to 3.6K |
| Legendary | about 6.9K to 1.2M |
| Mythic | 2M to 50M |
| the tier above Mythic | 65M to 200M |
| Divine | 300M to 780M |
| Eternal | 1.2B to 5B |

Odds that large are only reachable with luck multipliers, auto-rolling and very many rolls; that is the genre's design, and it is why disclosure and honesty matter so much (see [[Ethical Design and Player Trust]]).

---

## 5. Fitting stats to odds

"Rarer must be better" is a rule players enforce loudly. The cleanest way to guarantee it is a **fitted curve** from odds to stats, then small per-item deviations.

The reference project's rule: inside a tier, rarer is better, and "stats follow odds": every item keeps its ratio to a fitted Power, Income and Health curve. A power law is a good default because odds span many orders of magnitude:

```
Power = a * N^b    (N = the "1 in N" odds)
ln(Power) = ln(a) + b ln(N)
```

In a sheet, with odds in B and current power in C:
- slope b: `=SLOPE(LN(C2:C100), LN(B2:B100))`
- intercept ln(a): `=INTERCEPT(LN(C2:C100), LN(B2:B100))`
- fitted power: `=EXP(Intercept) * B2 ^ Slope`
- ratio to curve: `=C2 / FittedPower`

Then review the ratio column: anything well above 1 is overtuned for its rarity; anything below 1 is a trap item. Retuning to the curve while keeping each item's ratio preserves its "character" (a glass cannon stays a glass cannon).

What b means: with b = 0.25, an item 10,000 times rarer is 10,000^0.25 = 10x stronger. Choose b by asking "how much stronger should a 1 in 1M item feel than a 1 in 1K item?" and solving.

### Mixed scores for re-tiering
When the project re-tiered its top items, it ranked items within a tier by **half a measured quality score and half the earlier odds order**. The quality score weighted rig complexity (parts and animated joints, 0.4), the ability kit (own moves, clip seconds, 0.4) and effects size (0.2). The rule for the tier itself was qualitative: every Legendary or higher item must be animated; static models dropped to Epic. Kit size scaled by tier (Legendary 2 moves, Mythic 2 to 3, Celestial 3, Divine 4, Eternal 5).

The lesson: when "better" includes presentation, score presentation explicitly. Otherwise a 1 in 300M item can look worse than a 1 in 5M one, and players notice.

---

## 6. Sources and sinks

For each currency, list every source and sink with a **per-hour** rate for a representative player at a few zones.

| Flow | Type | Zone 3 /h | Zone 9 /h | Notes |
|---|---|---|---|---|
| Enemy kills | Source | | | |
| Quests | Source | | | share of next gate price |
| Daily / free gifts | Source | | | capped per day |
| Offline vault | Source | | | 15% of active rate, capped |
| Gates | Sink | | | |
| Upgrades | Sink | | | |
| Forge | Sink | | | plus materials |
| Rebirth | Sink (reset) | | | wipes balance |

Checks:
- **Share of income from non-play sources.** If quests, gifts and offline earnings exceed about a third of income, the core loop is no longer what pays (rule of thumb).
- **Balance growth.** If the median player's balance grows faster than prices, add sinks or slow sources.
- **Event deltas.** Model every event as a temporary change in the table, as the docs' fishing example warns.

Log the real flows with `AnalyticsService:LogEconomyEvent` (source/sink, currency, amount, ending balance, transaction type such as `Gameplay`, `Shop`, `TimedReward`, `Onboarding`, `IAP`, `ContextualPurchase`) and compare them with this tab. See [[Economies and Currencies]] and [[Analytics and Funnels]].

---

## 7. Simulate the randomness

A sheet handles averages. Randomness needs a distribution: what does the **unlucky** 10% of players experience? Write a small Monte Carlo simulation in Luau and run it in Studio (command bar or a test script). It uses the same tables as the game.

```lua
--!strict
-- Monte Carlo: rolls needed to get tier >= target, for many simulated players.
-- Paste into the command bar (or a test runner) with your real odds table.
type Item = { id: string, tierRank: number, odds: number } -- odds = N in "1 in N"

local ITEMS: { Item } = {
	{ id = "common",    tierRank = 1, odds = 2 },
	{ id = "rare",      tierRank = 3, odds = 25 },
	{ id = "epic",      tierRank = 4, odds = 2_000 },
	{ id = "legendary", tierRank = 5, odds = 50_000 },
}

-- Normalised weighted table: weight = 1/N, then shares sum to 1.
local function buildTable(items: { Item }, luck: number): ({ number }, number)
	local cum: { number } = {}
	local total = 0
	for i, it in items do
		local w = 1 / it.odds
		if it.tierRank >= 3 then
			w *= luck -- luck boosts Rare and above in this example
		end
		total += w
		cum[i] = total
	end
	return cum, total
end

local function rollOnce(rng: Random, cum: { number }, total: number): number
	local x = rng:NextNumber() * total
	for i, c in cum do
		if x < c then return i end
	end
	return #cum
end

local function simulate(players: number, targetRank: number, luck: number, cap: number): { number }
	local rng = Random.new(12345)
	local cum, total = buildTable(ITEMS, luck)
	local results: { number } = table.create(players, cap)
	for p = 1, players do
		for n = 1, cap do
			if ITEMS[rollOnce(rng, cum, total)].tierRank >= targetRank then
				results[p] = n
				break
			end
		end
	end
	table.sort(results)
	return results
end

local r = simulate(5_000, 4, 1, 100_000)
local function pct(q: number): number
	return r[math.max(1, math.floor(#r * q))]
end
print(("Epic+: median %d rolls, p90 %d, p99 %d"):format(pct(0.5), pct(0.9), pct(0.99)))
```

Use the percentiles, not the mean, when deciding pity thresholds, quest targets and "you should have a Legendary by now" assumptions in the ladder. Keep the simulation small enough to run in a few seconds; 5,000 players times a few thousand rolls is fine in the command bar.

---

## 8. From sheet to live data

The sheet is a hypothesis. Live data tests it.

| Question | Data |
|---|---|
| Does zone 5 really take 10 minutes? | `LogProgressionStartEvent` / `LogProgressionCompleteEvent` per zone; look at the time distribution |
| Where do players stall? | Funnel steps (`LogFunnelStepEvent`), plus the progression fail events |
| Is the economy inflating? | `LogEconomyEvent` sources and sinks; ending balances over time |
| Which price is right? | Experiments (A/B tests) on the value; the docs recommend Experiments for price points and onboarding values |
| Can we fix it without a release? | Live config ("Configs" in the docs' wording, or your own config store); see [[Global State and Live Config]] |

Two rules:
1. **Change one thing at a time** and note the date. Overlapping changes make every chart ambiguous.
2. **Compare cohorts, not totals.** A weekend influx changes totals; per-player averages and percentiles are stable. Discovery itself uses per-user averages (Docs, "Discovery").

---

## 9. Testing balance in code

Balance bugs are cheap to catch with assertions on the config module, run in Studio before publish:

```lua
--!strict
-- Balance assertions: run before every publish (see the testing notes).
local Curves = require(game:GetService("ReplicatedStorage"):WaitForChild("Curves"))

local function check(cond: boolean, msg: string)
	if not cond then warn("BALANCE: " .. msg) end
end

-- Prices rise inside each region, and the region portals are free.
for zone = 2, 20 do
	local prev, cur = Curves.gatePrice(zone - 1), Curves.gatePrice(zone)
	if cur ~= 0 then
		check(cur > prev, ("gate %d not above gate %d"):format(zone, zone - 1))
	end
end

-- Anchor: stage 50 must stay reachable (design target <= 50,000 power with the mini-boss bonus).
check(Curves.recommendedPower(50) <= 50_000, "stage 50 power above the anchor")
```

Add similar checks for item tables (probabilities sum to 1, rarer items have higher fitted power, no item above its tier's cap). See [[Testing Strategies and Frameworks]].

---

## 10. Common mistakes

| Mistake | Better |
|---|---|
| Typing derived numbers by hand | Formulas from inputs; only inputs are typed |
| Balancing on averages for random rewards | Percentiles from simulation |
| Tables whose probabilities do not sum to 1 | A check column; for paid items, displayed % must total 100% |
| Tuning many values in one release | One change per release, dated |
| Events modelled as "a bit more reward" | Model the extra activity the event causes (Docs' fishing example) |
| Stats unrelated to rarity | Fitted curve plus per-item ratio |
| Re-running automated balance passes over hand-tuned data | Freeze tuned passes; require sign-off |
| Ignoring non-play income | Track its share of total income |

## 11. Checklist

- [ ] One sheet with Inputs, Ladder, Items, Rarity, Sources and Sinks, Scenarios.
- [ ] Minutes-per-step plotted; spikes flagged automatically.
- [ ] Prices expressed as minutes of income at the unlocking zone.
- [ ] EV computed for every random reward and event.
- [ ] Odds converted to "chance after k rolls" and percentiles checked.
- [ ] Stats fitted to odds; outliers reviewed.
- [ ] Monte Carlo run for every RNG gate or pity threshold.
- [ ] Live progression and economy events logged; one change per release.
- [ ] Balance assertions run before publish.

## See also
- [[Progression and Pacing Design]], [[Core Loops and Session Design]], [[Genre Playbook - RNG and Collection Games]]
- [[Economies and Currencies]], [[RNG Drops and Luck Systems]], [[Progression Levels and Unlocks]]
- [[Analytics and Funnels]], [[Global State and Live Config]], [[Testing Strategies and Frameworks]]
- [[Pricing and Store Design]], [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Rarity Ladders and Drop Pacing Math]] · [[Expected Value]] · [[Drop Tables Rarity and Pity Systems]] · [[Economy Inflation Sinks and Faucets Math]] · [[Economy Design Start Here]] · [[Simulating an Economy Before Launch]]
<!-- auto-links:end -->
