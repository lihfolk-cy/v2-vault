---
tags: [economy, telemetry, analytics, analyticsservice, configservice, experiments, live-ops, balancing, luau]
---
# Economy Telemetry and Balancing Live

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Logging before commit -> Log in the wallet after mutation
> - Avoid: SKU renamed -> Stable SKU strings
> - Avoid: Whole-population medians -> Segment by progress cohort
> - All economy events logged from the wallet, after commit, with stable names.
> - Custom fields used for progress band, config version and variant.
> - Hours held, velocity and time to afford tracked per progress cohort.
>
> Cost: TL;DR ~140 tok · whole note ~4.9k tok. Read more: ## 3. Your own aggregates without wrecking data store budgets · ## 5. The balancing loop · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Analytics and Funnels]] explains the built-in dashboards and the `AnalyticsService` API. [[Economy Inflation Sinks and Faucets Math]] names three inflation metrics (hours of income held, sink to faucet ratio, observed time to afford). [[A-B Testing and Experiments on Roblox]] covers configs, experiments and sample sizes. This note joins them into an operating practice for a live economy: what to measure beyond the built-in charts, how to aggregate your own numbers without blowing data store budgets, how to read economy metrics without being fooled by who is still playing, how to alert on anomalies, and how to run a balance change from hypothesis to rollback.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**. Luau is strict, reviewed by reading, not run.

---

## 1. Two layers of telemetry

| Layer | Tool | Strength | Limits |
|---|---|---|---|
| Built-in economy events | `AnalyticsService:LogEconomyEvent` | Free dashboards, sources and sinks by transaction type and SKU, no infrastructure | Up to five currencies in the dashboard; up to three custom fields for filtering; server-only, published experiences only (Roblox docs, as of October 2026) |
| Your own aggregates | Per-server counters flushed to a data store, or to your own backend through `HttpService` | Any metric you can define: per-cohort distributions, item supply, pity hits, variant splits | You build and pay for it; privacy and retention are your responsibility |

Use the first for everything it can answer. Build the second only for questions it cannot: distributions (not just totals), per-cohort views, item supply, and anything that needs joining with your own config versions. Most small games never need the second layer; most games with a trading market or a large RNG pool do.

### What the built-in layer needs from you

The signature (Roblox docs, as of October 2026) is `LogEconomyEvent(player, flowType, currencyType, amount, endingBalance, transactionType, itemSku?, customFields?)`. Practices that make the dashboard useful:

- **Log after the change is applied**, with the balance after the change. Logging before commit, or logging a failed spend, produces sinks that never happened.
- **Log from one place.** The wallet module ([[Currency Architecture - Soft Hard and Event Currencies]] section 5) is the only code that calls it. Two call sites for one transaction double-count.
- **Keep transaction types and SKUs stable.** Renaming a SKU splits its history in two. Treat SKU strings like data store keys: decided once, documented, never reused for a different thing.
- **Use the custom fields for the dimensions you will filter by.** Good candidates: progress band ("zone_4"), config version ("econ_v12"), experiment variant. Values are strings; keep their cardinality low ([[Analytics and Funnels]] lists the combination limit).
- **Amounts are positive**, flow type carries the direction (the guide notes that charts show sinks as negative automatically).

---

## 2. The metrics that actually catch problems

Totals hide most economy problems. The useful metrics are **distributions within progress cohorts** and **flows broken down by source**.

| Metric | Definition | What it catches |
|---|---|---|
| Net flow by source | Sum of sources minus sinks per transaction type per day | A faucet left on; a sink that stopped firing |
| Hours of income held, by zone | `balance / income per hour`, p10, p50, p90, grouped by zone or level band | Surplus with nothing to buy (rises) or a wall (falls to near zero while churn rises) |
| Velocity | Coins spent per day / average coins held | Hoarding (falls) before balances look alarming |
| Observed time to afford | Time from unlocking a gate to buying it, p50 and p90 | Pricing drift against the model |
| Wealth concentration | Gini of balances within a cohort (0 equal, 1 one player holds everything) | A few accounts accumulating abnormally (exploit, dupes) |
| Item supply | New copies of each rare item per day | Dupes; luck events; drop table mistakes |
| Price index | Robust prices of a fixed basket of tradeable items, relative to a base week | Item inflation in trading games |
| Payer progress gap | Median zone of payers / non-payers at equal playtime | Multipliers drifting past the declared gap |

### Why "within a cohort" matters

The median balance of all active players is almost meaningless in a progression game, because it depends on who is playing. If many new players join after a featured placement, the median balance falls; if they churn a week later, it rises. Neither is inflation. Always group by progress band (zone, level, rebirth count) or by join-week cohort, and compare like with like.

This is **Simpson's paradox** in practice: every cohort's hours-held can be falling (healthy) while the overall median rises, because the mix shifted toward late-game players. [[Probability and Statistics for Designers]] section 6 shows the general case; for economies the fix is always the same: segment first, then aggregate.

### Survivorship

Players who hit a wall and quit stop producing data. If zone 6 is badly overpriced, the players you see in zone 6 a week later are the ones who got through it, and their observed time to afford looks fine. Pair every time-to-afford metric with a **funnel**: of players who unlocked zone 6, what share bought its gate within 3 days? A falling conversion with a flat time-to-afford is the signature of a wall ([[Analytics and Funnels]] section 5).

---

## 3. Your own aggregates without wrecking data store budgets

When you need distributions or item supply, aggregate in memory on each server and flush periodically. Do not write one data store entry per transaction.

Budget arithmetic (Roblox docs, as of October 2026, data store limits): standard writes per server are 60 + 40 x players per minute, values are up to 4,194,304 characters, and each key has a write-volume limit that applies across all servers. A 20-player server has 860 writes per minute, but most of those belong to player saves. Rule of thumb: telemetry should use under 5% of the write budget. One flush every 5 minutes per server is negligible.

The hot-key problem: if every server in a 300-server experience updates the same key `econ/2026-10-27` every five minutes, that key sees a write about once a second, every one an `UpdateAsync` that conflicts with others. Shard it: each server picks one of N shard keys by `JobId` hash, and the offline reader sums the shards.

```lua
--!strict
-- ServerScriptService/Economy/EconomyTelemetry.lua
-- Aggregates per server, flushes to sharded daily keys. Read offline via Open Cloud.
local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("EconTelemetry_v1")
local SHARDS = 16
local FLUSH_SECONDS = 300

type Counters = {
	flows: { [string]: number },      -- "Coins|Source|Gameplay" -> total
	supply: { [string]: number },     -- itemId -> new copies
	heldByZone: { [string]: { number } }, -- zone -> samples of hours held (bounded)
}

local MAX_SAMPLES_PER_ZONE = 200

local function fresh(): Counters
	return { flows = {}, supply = {}, heldByZone = {} }
end

local current = fresh()

local EconomyTelemetry = {}

function EconomyTelemetry.flow(currency: string, flow: "Source" | "Sink", txType: string, amount: number)
	local key = `{currency}|{flow}|{txType}`
	current.flows[key] = (current.flows[key] or 0) + amount
end

function EconomyTelemetry.itemMinted(itemId: string, count: number)
	current.supply[itemId] = (current.supply[itemId] or 0) + count
end

-- Call at save time with the player's balance and current income per hour.
function EconomyTelemetry.sampleHeld(zone: number, balance: number, incomePerHour: number)
	if incomePerHour <= 0 then
		return
	end
	local list = current.heldByZone[tostring(zone)]
	if not list then
		list = {}
		current.heldByZone[tostring(zone)] = list
	end
	if #list < MAX_SAMPLES_PER_ZONE then
		table.insert(list, balance / incomePerHour)
	end
end

local function shardKey(): string
	local day = os.date("!%Y-%m-%d") :: string
	local h = 0
	for i = 1, #game.JobId do
		h = (h * 31 + string.byte(game.JobId, i)) % SHARDS
	end
	return `{day}/{h}`
end

local function merge(into: Counters, from: Counters)
	for k, v in from.flows do
		into.flows[k] = (into.flows[k] or 0) + v
	end
	for k, v in from.supply do
		into.supply[k] = (into.supply[k] or 0) + v
	end
	for zone, samples in from.heldByZone do
		local list = into.heldByZone[zone] or {}
		for _, s in samples do
			if #list >= MAX_SAMPLES_PER_ZONE * 4 then
				break -- keep each shard bounded; this is a sample, not a census
			end
			table.insert(list, s)
		end
		into.heldByZone[zone] = list
	end
end

function EconomyTelemetry.flush()
	local batch = current
	current = fresh() -- new events go to a new batch while this one is written
	local ok = pcall(function()
		store:UpdateAsync(shardKey(), function(old: Counters?): Counters
			local base = old or fresh()
			merge(base, batch)
			return base
		end)
	end)
	if not ok then
		merge(current, batch) -- try again next flush; telemetry may be late, not lost
	end
end

task.spawn(function()
	while true do
		task.wait(FLUSH_SECONDS)
		EconomyTelemetry.flush()
	end
end)

game:BindToClose(function()
	EconomyTelemetry.flush()
end)

return EconomyTelemetry
```

Notes:

- **Swap the batch before yielding.** `flush` replaces `current` before `UpdateAsync` yields, so events during the write are not lost or double counted. If the write fails, the batch is merged back.
- **`UpdateAsync` transforms can run more than once**; `merge(base, batch)` into the freshly read `base` is safe to repeat because `base` is new on each run.
- **`BindToClose` competes with player saves** for the shutdown window ([[Saving Correctly - Autosave and BindToClose]]). Telemetry is the first thing to drop if time is short; never let it delay a profile save.
- **Samples, not censuses.** `heldByZone` keeps a bounded sample per shard. With 16 shards that is still thousands of samples per zone per day, plenty for medians and percentiles.
- **No personal data.** Aggregates contain no user ids, so they are outside your erasure obligations. If you add per-player records, they fall under [[Player Privacy and Data Deletion]].
- **Reading** is an offline job: list the day's shard keys through Open Cloud, sum them, compute percentiles, write a report ([[Open Cloud APIs]]).

---

## 4. Alerts: comparing against the right baseline

An alert that fires every weekend because weekends are busier is ignored by Wednesday. Compare each day to the **same weekday over the last four weeks**, and use a robust spread:

```
robust z = (today - median of baseline) / (1.4826 * MAD of baseline)
```

where MAD is the median absolute deviation. With four or more baseline points this tolerates one odd week (an event, an outage) without the threshold collapsing. Rule of thumb thresholds: investigate at `|z| > 3`, page someone at `|z| > 5` for faucets of premium currency and supply of top-tier items.

```lua
--!strict
local function median(xs: { number }): number
	local s = table.clone(xs)
	table.sort(s)
	local n = #s
	return if n % 2 == 1 then s[(n + 1) // 2] else (s[n // 2] + s[n // 2 + 1]) / 2
end

local function robustZ(today: number, baseline: { number }): number
	local m = median(baseline)
	local deviations = table.create(#baseline, 0)
	for i, x in baseline do
		deviations[i] = math.abs(x - m)
	end
	local mad = median(deviations)
	if mad == 0 then
		return if today == m then 0 else math.huge
	end
	return (today - m) / (1.4826 * mad)
end
```

Alerts worth having on day one:

| Alert | Signal |
|---|---|
| Premium faucet spike | Free premium granted per DAU, `z > 3` |
| Rare supply spike | New copies of any top-tier item per DAU, `z > 3` |
| Concentration jump | Top 0.1% of accounts' share of a currency doubles day over day |
| Sink collapse | A sink's daily total falls by more than half (a shop broke, a remote errors) |
| Wall forming | Gate conversion within 3 days falls in one zone only |

Normalise by DAU (or rolls, or kills) before comparing; a featured slot doubles every absolute total.

**Measured in the reference project:** a premium daily bonus from a pass, small per day, added up to roughly 750 premium units per month per holder, and players reported that premium currency "didn't do much" before sinks were added. Both the free share of premium and the premium sink total are exactly the metrics that would have shown it in the first week ([[Economy Inflation Sinks and Faucets Math]] section 6).

---

## 5. The balancing loop

A live balance change is an experiment on your whole player base whether you call it one or not. A loop that keeps it safe:

1. **State the hypothesis with a number.** "Zone 6 gate p50 time to afford is 41 minutes against a 20-minute target; lowering the gate by 40% should bring it to about 25 and raise 3-day gate conversion from 52% to over 65%."
2. **Check it in the simulation** ([[Simulating an Economy Before Launch]]) with the live config. If the simulation does not reproduce today's observed numbers, fix the simulation first.
3. **Change config, not code.** Prices, rates and multipliers in experience configs can change without publishing a new version. `ConfigService:GetConfigAsync()` returns a global snapshot; `ConfigSnapshot:Refresh()` loads newer values and `UpdateAvailable` signals that they exist; publishing typically reaches servers in 15 seconds to a minute, or gradually over 15 minutes (Roblox docs, as of October 2026). Wrap reads with defaults as in [[Global State and Live Config]].
4. **Roll out in stages** if the change is risky ([[Feature Flags and Staged Rollouts]]).
5. **Measure the metric you named**, segmented by cohort, for long enough to cover a weekly cycle.
6. **Keep or roll back**, and write down which and why ([[Patch Notes and Player Communication]] for what players hear).

### Experiments on economy values

Roblox experiments assign players to a control and up to two variants of a config value for 14 to 60 days, read through `ConfigService:GetConfigForPlayerAsync(player)`; the first `GetValue` call enrolls the player for that key, and games under about 1,000 DAU may struggle to get useful results (Roblox docs, as of October 2026). The built-in experiment metrics are retention, playtime, session time, ARPU, ARPPU and payer conversion. Two economy-specific cautions:

- **The built-in metrics do not include economy health.** Put the variant name in a custom field on your economy events so you can compare net flows, hours held and gate conversion per variant yourself.
- **Variants leak through trading and shared servers.** If players can trade, a variant with cheaper rolls produces more items that flow into the control group's market. Server-wide effects (a luck boost visible to everyone in the server) mix variants in the same server. Do not A/B test supply or prices of tradeable goods, or global multipliers; test them with a staged rollout and a before-and-after comparison instead, and accept that it is weaker evidence.

**Pricing experiments and fairness.** Showing different prices for the same Robux product to different players is a trust risk even where it is permitted; [[A-B Testing and Experiments on Roblox]] section 7 covers the policy and ethics. Soft-currency balance values are the safer target.

---

## 6. Reading a change after it ships

Patterns and what they usually mean (rule of thumb):

| After a change, you see | Likely meaning |
|---|---|
| Targeted metric moved as predicted, nothing else did | Done; record it |
| Targeted metric moved, churn rose in a different zone | Players now arrive at the next wall faster; check that zone's time to afford |
| Hours held rose across all zones | A faucet grew or a sink weakened more than you meant |
| Velocity fell while balances rose | Players are saving for something; check if a new item is coming or if the shop lost appeal |
| Rare price index fell a week after a luck event | Supply shock; expected, but decide whether to add a sink |
| Metric moved for one platform only | UI problem on that platform, not economy ([[Responsive UI for Phone Tablet Console and PC]]) |

Wait for a full week before judging any change that touches retention. Many economy changes look good on day one (players enjoy the windfall) and bad by day seven (they finished the content).

---

## 7. When not to build custom telemetry

- **Under a few hundred DAU.** Distributions are noise; watch individual players' journeys in playtests and logs instead ([[Multi-Client and Device Playtesting Protocols]]).
- **When the built-in dashboard answers the question.** Net flows by transaction type and SKU cover most early questions.
- **Before you have decided what action a metric would trigger.** A metric with no decision attached is a dashboard nobody reads.

---

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Logging before commit | Sinks larger than possible; balances that do not reconcile | Log in the wallet after mutation |
| SKU renamed | A product's history splits in two | Stable SKU strings |
| Whole-population medians | "Inflation" that tracks marketing pushes | Segment by progress cohort |
| Ignoring survivorship | Time to afford looks fine while churn rises | Pair with gate conversion funnels |
| One telemetry key for all servers | Throttling errors and lost flushes | Shard by server hash |
| Telemetry delaying shutdown saves | Data loss on shutdowns | Flush after saves; drop if late |
| Absolute thresholds | Alerts every weekend | Same-weekday baseline, robust z, per-DAU |
| A/B testing tradeable supply | Variants contaminate each other's market | Staged rollout instead |
| Judging on day one | Reverting good changes or keeping bad ones | Wait a weekly cycle |

## Checklist

- [ ] All economy events logged from the wallet, after commit, with stable names.
- [ ] Custom fields used for progress band, config version and variant.
- [ ] Hours held, velocity and time to afford tracked per progress cohort.
- [ ] Gate conversion funnels alongside time-to-afford.
- [ ] Item supply per day tracked for top tiers.
- [ ] Own aggregates sharded, bounded, flushed every few minutes, no personal data.
- [ ] Alerts on premium faucets, rare supply, concentration and sink collapse, normalised per DAU.
- [ ] Balance changes go through hypothesis, simulation, config, staged rollout, measurement.
- [ ] No experiments on tradeable supply or global multipliers.

## See also
[[Economy Design Start Here]] · [[Currency Architecture - Soft Hard and Event Currencies]] · [[Pricing Curves and Upgrade Costs]] · [[Drop Tables Rarity and Pity Systems]] · [[Player-Driven Trading Economies]] · [[Simulating an Economy Before Launch]] · [[Analytics and Funnels]] · [[Economy Inflation Sinks and Faucets Math]] · [[A-B Testing and Experiments on Roblox]] · [[Global State and Live Config]] · [[Feature Flags and Staged Rollouts]] · [[Crash and Error Telemetry]]

## Connected notes
<!-- auto-links:start -->
[[Economies and Currencies]] · [[Faucets and Sinks]] · [[Balancing with Spreadsheets and Data]] · [[Telemetry Events]] · [[Robux Price Points and Offer Design]] · [[Links - Analytics]]
<!-- auto-links:end -->
