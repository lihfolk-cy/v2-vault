---
tags: [economy, rng, drops, loot-tables, rarity, pity, probability, luau, design]
---
# Drop Tables Rarity and Pity Systems

The vault already covers the basics of random rewards from several sides. [[RNG Drops and Luck Systems]] has the weighted pick, luck multipliers, a soft pity ramp and the list of protection systems. [[Rarity Ladders and Drop Pacing Math]] turns odds into hours and covers hard pity's effect on the mean. [[Paid Random Items and Odds Disclosure in Practice]] flattens tiered rolls for disclosure and gives the hard-pity effective rate. [[Probability and Statistics for Designers]] covers streaks, pseudo-random distribution and testing rates.

This note is about **structure**: drop tables as composable data rather than code, computing expected drops through nested tables, sampling large tables in constant time, the exact effective rate of any soft pity ramp, what happens when two pity counters fire on the same roll, featured-item guarantees, duplicate protection and what it does to collection time, and how to version tables so a live change is auditable.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**. Numbers in the worked examples were computed with a short script. Luau is strict, reviewed by reading, not run.

---

## 1. Drop tables are data

In most early Roblox projects a drop is an `if math.random() < 0.05 then` inside an enemy script. That works for one enemy. By the twentieth it means odds are scattered across scripts, nobody can answer "what does a zone 4 boss drop on average", disclosure cannot be generated, and a balance pass is a code change in twenty places.

A drop table is a data structure the designer can read, the server evaluates, the disclosure UI flattens and the simulation imports. A small set of entry kinds covers almost every game:

| Construct | Meaning | Example |
|---|---|---|
| **Always** | Every entry drops | Boss always drops 1 to 3 materials |
| **Independent chances** | Each entry rolls its own chance | 25% rare material, 5% fragment, both possible |
| **Pick one by weight** | Exactly one entry, `picks` times | One weapon from a weighted list |
| **Nothing** | A weighted "no drop" | 70% of pick results are nothing |
| **Sub-table** | An entry that evaluates another table | "Rare pool" shared by several enemies |

The nesting is what makes this scale: ten enemies share one "zone 4 rare pool" table, so a change to that pool changes all ten consistently.

```lua
--!strict
-- ReplicatedStorage/Shared/DropTables.lua: data only. Server evaluates; UI and tests read it.
export type Entry =
	{ kind: "item", id: string, weight: number, min: number?, max: number? }
	| { kind: "table", ref: string, weight: number }
	| { kind: "nothing", weight: number }

export type Chance = { entry: Entry, chance: number }

export type DropTable = {
	id: string,
	version: number,
	always: { Entry }?,
	independent: { Chance }?,
	pick: { Entry }?,
	picks: number?,
}

local Tables: { [string]: DropTable } = {
	Zone4RarePool = {
		id = "Zone4RarePool",
		version = 3,
		pick = {
			{ kind = "item", id = "EmberBlade", weight = 60 },
			{ kind = "item", id = "FrostBlade", weight = 30 },
			{ kind = "item", id = "VoidBlade", weight = 10 },
		},
		picks = 1,
	},
	Zone4Boss = {
		id = "Zone4Boss",
		version = 7,
		always = { { kind = "item", id = "IronOre", weight = 1, min = 1, max = 3 } },
		independent = {
			{ entry = { kind = "item", id = "MagmaCore", weight = 1 }, chance = 0.25 },
			{ entry = { kind = "table", ref = "Zone4RarePool", weight = 1 }, chance = 0.05 },
		},
	},
}

return Tables
```

Weights in `pick` lists are relative and need not sum to anything. Chances in `independent` lists are absolute probabilities. Mixing the two in one list is the most common data bug; keeping them in separate fields makes the mistake impossible.

### Evaluating a table

```lua
--!strict
-- ServerScriptService/Loot/DropEval.lua
local Tables = require(game:GetService("ReplicatedStorage").Shared.DropTables)
type Entry = Tables.Entry
type DropTable = Tables.DropTable

local MAX_DEPTH = 4 -- guards against a table that references itself

local DropEval = {}

local function pickWeighted(list: { Entry }, rng: Random): Entry
	local total = 0
	for _, e in list do
		total += e.weight
	end
	local r = rng:NextNumber() * total
	for _, e in list do
		r -= e.weight
		if r < 0 then
			return e
		end
	end
	return list[#list] -- floating point fallback
end

local function resolve(e: Entry, rng: Random, out: { [string]: number }, depth: number)
	if e.kind == "item" then
		local lo = e.min or 1
		local hi = e.max or lo
		out[e.id] = (out[e.id] or 0) + rng:NextInteger(lo, hi)
	elseif e.kind == "table" then
		DropEval.roll(e.ref, rng, out, depth + 1)
	end
	-- "nothing" adds nothing
end

function DropEval.roll(tableId: string, rng: Random, out: { [string]: number }?, depth: number?): { [string]: number }
	local result = out or {}
	local d = depth or 0
	assert(d <= MAX_DEPTH, `drop table nesting too deep at {tableId}`)
	local t = assert(Tables[tableId], `unknown drop table {tableId}`)
	for _, e in t.always or {} do
		resolve(e, rng, result, d)
	end
	for _, c in t.independent or {} do
		if rng:NextNumber() < c.chance then
			resolve(c.entry, rng, result, d)
		end
	end
	if t.pick then
		for _ = 1, t.picks or 1 do
			resolve(pickWeighted(t.pick, rng), rng, result, d)
		end
	end
	return result
end

return DropEval
```

Who receives the result (last hitter, top damage, everyone who contributed) is a separate decision covered in [[RNG Drops and Luck Systems]] section 5. Keep it out of the table format.

---

## 2. Expected drops through nested tables

Because tables are data, you can compute the **expected count of every item per evaluation** exactly, without rolling. This is the number you need for supply modelling ([[Economy Inflation Sinks and Faucets Math]] section 5), for "average drops per boss" in a design review, and for checking that a balance change did what you meant.

```lua
--!strict
-- Expected count of each item from one evaluation of `tableId`.
local function expected(tableId: string, scale: number, out: { [string]: number }, depth: number)
	assert(depth <= 4, "too deep")
	local t = Tables[tableId]
	local function add(e: Entry, p: number)
		if e.kind == "item" then
			local lo = e.min or 1
			local hi = e.max or lo
			out[e.id] = (out[e.id] or 0) + p * (lo + hi) / 2
		elseif e.kind == "table" then
			expected(e.ref, p, out, depth + 1)
		end
	end
	for _, e in t.always or {} do
		add(e, scale)
	end
	for _, c in t.independent or {} do
		add(c.entry, scale * c.chance)
	end
	if t.pick then
		local total = 0
		for _, e in t.pick do
			total += e.weight
		end
		for _, e in t.pick do
			add(e, scale * (t.picks or 1) * e.weight / total)
		end
	end
end
```

**Worked example** for the `Zone4Boss` table above: IronOre 2.0 per kill (always, 1 to 3), MagmaCore 0.25, and the rare pool fires 5% of the time, so EmberBlade 0.03, FrostBlade 0.015, VoidBlade 0.005. VoidBlade is "1 in 200 boss kills". If the boss is killed 40,000 times a day across all servers, 200 VoidBlades enter the game daily. That is the number to put next to its trade value before launch ([[Player-Driven Trading Economies]]).

Run this function in a unit test for every table on every config change and diff the result against the previous version. A change that moves an item's expected supply by more than you intended shows up before release, not in the market a week later ([[Automated Testing with TestEZ and Jest-Lua]]).

---

## 3. Sampling large tables in constant time

The linear `pickWeighted` above walks the list. For a 10-entry table that costs nothing. It becomes worth replacing only when both are true:

- the table is large (hundreds to thousands of entries, for example every item in a big RNG game in one pool), and
- you roll it very often (auto-roll at several rolls per second per player, times a full server, or offline batch simulation of millions of rolls).

Rule of thumb: below about 100 entries, or below a few thousand rolls per second per server, the linear walk is fine and simpler to read. Profile before changing ([[Script Performance]]).

The **alias method** (Vose's version) precomputes two arrays in O(n) and then samples in O(1): pick a column uniformly, then flip a biased coin between the column's own entry and its alias.

```lua
--!strict
export type Alias = { prob: { number }, alias: { number }, n: number }

-- weights: positive numbers. Returns tables for O(1) sampling of an index 1..n.
local function buildAlias(weights: { number }): Alias
	local n = #weights
	local total = 0
	for _, w in weights do
		total += w
	end
	local scaled = table.create(n, 0)
	local small, large = {}, {}
	for i, w in weights do
		scaled[i] = w * n / total
		table.insert(if scaled[i] < 1 then small else large, i)
	end
	local prob, alias = table.create(n, 0), table.create(n, 0)
	while #small > 0 and #large > 0 do
		local s = table.remove(small) :: number
		local l = table.remove(large) :: number
		prob[s] = scaled[s]
		alias[s] = l
		scaled[l] = (scaled[l] + scaled[s]) - 1
		table.insert(if scaled[l] < 1 then small else large, l)
	end
	-- Leftovers are 1 up to floating point error.
	for _, i in large do
		prob[i] = 1
	end
	for _, i in small do
		prob[i] = 1
	end
	return { prob = prob, alias = alias, n = n }
end

local function sampleAlias(a: Alias, rng: Random): number
	local i = rng:NextInteger(1, a.n)
	return if rng:NextNumber() < a.prob[i] then i else a.alias[i]
end
```

Trade-offs to know:

- **Rebuild on every weight change.** Luck multipliers that change weights per player mean one alias table per luck level. With a handful of discrete luck levels, cache them; with continuous luck, the linear walk (or tiered rolls: pick the tier, then the item) is simpler.
- **Tiered rolls are often enough.** Rolling the rarity tier first (5 to 10 entries) and then the item within the tier (uniform or small weighted list) is two short walks. Most games never need alias tables.
- **Disclosure does not care** how you sample, only what the resulting probabilities are. Test the sampler statistically against the flattened odds ([[Paid Random Items and Odds Disclosure in Practice]] section 10).

---

## 4. The exact effective rate of any pity ramp

The hard pity formula in the existing notes covers a flat chance with a guarantee at `K`. Real systems usually ramp: a flat chance for a while, then a rising chance, then a guarantee. The ramp shape changes the effective rate, the median and the 90th percentile, and you can compute all of them exactly with a survival sum.

Let `c(k)` be the chance of the top result on roll `k` since the last one (with `c(K) = 1`). The chance of still waiting after `k` rolls is `S(k) = product of (1 - c(j))` for `j = 1..k`. Then:

```
expected rolls per hit   E = sum over k = 0..K-1 of S(k)     (S(0) = 1)
effective rate           = 1 / E
P(hit exactly on roll k) = S(k - 1) * c(k)
```

**Worked example (computed).** Base chance 0.6% per roll. From roll 74 the chance rises by 6 percentage points per roll; roll 90 is guaranteed.

| System | Expected rolls | Effective rate | Median wait | 90th percentile |
|---|---|---|---|---|
| No pity | 167 | 0.60% | 116 | 383 |
| Hard pity at 90 only | 69.7 | 1.43% | 90 | 90 |
| Soft ramp from 74, hard at 90 | 62.3 | 1.61% | 76 | 80 |

Things this table shows that designers tend to miss:

- **With hard pity only, the median player hits the guarantee.** About 59% of players reach roll 90 without a natural hit, so most players experience the item as "a guarantee at 90", not "a 0.6% chance". If you want the base rate to feel like a chance, the guarantee must be further out than the median natural wait.
- **The soft ramp concentrates outcomes.** About 36% of hits happen in rolls 1 to 73 at the base rate; almost all the rest land between 74 and 80. Players learn that "pity starts at 74", and community guides will say so within days. Hidden soft pity is not hidden for long.
- **The disclosed effective rate changes a lot with the ramp shape**, even with the same base chance and the same hard cap. Disclose the rule and the effective rate, computed from the actual ramp ([[Paid Random Items and Odds Disclosure in Practice]] section 5).

```lua
--!strict
-- Effective statistics for a pity ramp. chanceAt(k) returns the chance on roll k (1-based).
local function pityStats(chanceAt: (number) -> number, hardCap: number): (number, number, number)
	local survive, expectedRolls = 1, 0
	local median, p90 = -1, -1
	local cumulative = 0
	for k = 1, hardCap do
		expectedRolls += survive
		local c = if k >= hardCap then 1 else chanceAt(k)
		local hitHere = survive * c
		cumulative += hitHere
		if median < 0 and cumulative >= 0.5 then
			median = k
		end
		if p90 < 0 and cumulative >= 0.9 then
			p90 = k
		end
		survive *= 1 - c
	end
	return expectedRolls, median, p90
end

local E, med, p90 = pityStats(function(k: number): number
	if k < 74 then
		return 0.006
	end
	return math.min(1, 0.006 + 0.06 * (k - 73))
end, 90)
print(string.format("E=%.1f rate=%.2f%% median=%d p90=%d", E, 100 / E, med, p90))
```

Put this in the same test suite as the expected-drops check, so a change to the ramp prints new disclosed numbers automatically.

---

## 5. Several pity counters at once

Games often run pity per tier: an Epic guaranteed every 10 rolls and a Legendary guaranteed at 90. Rules you must write down, because each one changes the real odds:

1. **Does a higher tier satisfy a lower tier's pity?** Usually yes: a Legendary on roll 7 resets the Epic counter too. If not, the next roll after a Legendary might be a forced Epic, which players notice as "it always gives an Epic after a Legendary".
2. **What if both guarantees fall on the same roll?** Give the higher tier and decide what happens to the lower one: discard it (simplest), or carry it to the next roll (generous, and it changes the Epic rate slightly).
3. **Does a forced result count toward other counters?** A forced Epic should still advance the Legendary counter; otherwise the Legendary pity becomes longer than disclosed.
4. **What does a multi-roll pack do?** Ten rolls at once must evaluate the counters roll by roll in order, not "roll ten, then fix up". Batch evaluation with a single counter check is the most common pity bug in pack purchases.

The only reliable way to disclose the resulting rates is to compute them from the same code that rolls, by simulation over millions of rolls in a test, since the interactions make closed forms awkward.

---

## 6. Featured-item guarantees

Event pools often have a featured item at the top tier and a "50/50" rule: when you hit the top tier, there is a 50% chance it is the featured item; if you lose, your next top-tier hit is guaranteed featured.

Expected top-tier hits per featured item: `0.5 * 1 + 0.5 * 2 = 1.5`. With the soft-ramp example above (62.3 rolls per top-tier hit), that is about **93 rolls per featured item** on average, and the worst case is two full pity cycles, **180 rolls**. Both numbers belong in the disclosure, and the "guaranteed next time" state is a saved counter like any other pity ([[Data Schema Design and Migrations]]).

Design questions this raises:

- **Does the guarantee carry over to the next event?** If players "lost the 50/50" at the end of an event, carrying the guarantee is generous and builds trust; dropping it is a hidden loss and a support issue.
- **Does pity carry across pools?** A shared pity counter across all event pools makes switching pools free. A per-pool counter locks players into one pool. Either is legitimate; changing it mid-event is not.

---

## 7. Duplicate protection and collection time

Duplicate protection ("you cannot roll an item you already own until you own the whole set") changes collection maths dramatically.

For a tier with `n` equally likely items, collecting all of them without protection takes on average `n * H(n)` rolls of that tier, where `H(n) = 1 + 1/2 + ... + 1/n` (the coupon collector problem, [[Rarity Ladders and Drop Pacing Math]] section 6). With protection it takes exactly `n`.

| Items in tier | Without protection | With protection | Ratio |
|---|---|---|---|
| 5 | 11.4 | 5 | 2.3x |
| 20 | 72.0 | 20 | 3.6x |
| 50 | 225 | 50 | 4.5x |

Consequences:

- **It is a large buff to collection pace.** Turning it on for a 20-item tier makes completion more than three times faster. Treat it as a pacing change, not a quality-of-life tweak.
- **It removes duplicates as a resource.** If duplicates feed fusion, salvage or trade, protection starves those systems. Many games apply protection only to the top tier and let lower tiers duplicate.
- **It is a probability modifier.** Per-item odds now depend on what the player owns. If the pool is a paid random item, the displayed per-item odds must reflect the player's own collection ([[Paid Random Items and Odds Disclosure in Practice]] section 6 covers once-per-user outcomes).
- **It interacts with trading.** A player can trade away an item to "re-enable" it in their pool. Usually harmless, but if the pool is paid, check that the protection cannot be gamed into better odds for specific items.

---

## 8. Seeds, logs and versions

Drop tables change over a game's life. When a player reports "I got nothing from 500 boss kills", support needs to know which table version applied and whether the rolls were plausible.

- **Version every table** (the `version` field above) and log `tableId@version` with each notable drop, or at least with each boss kill batch. A later change that silently altered a shared pool is then visible in the logs.
- **Server-side randomness only.** All rolls happen on the server with `Random` objects the client cannot observe ([[RNG Drops and Luck Systems]] section 1). Never send seeds or the next result to the client, even for "pre-rolling the reveal animation".
- **Replayable rolls (optional).** Some teams give each player a server-generated seed stored in the profile plus a roll counter, so a sequence can be replayed for audits. This only helps if the seed never leaves the server; and the generator must be cheap to position (re-seeding per roll from seed and counter, not advancing a generator thousands of steps on load). Rule of thumb: worth it for paid pools, overkill for enemy drops.
- **Aggregate counters.** Count rolls and top-tier hits per pool per day. Observed rate against computed effective rate is a free statistical check, using the binomial test from [[Probability and Statistics for Designers]] section 5.

**Measured in the reference project:** boss drops were designed as "always one material, plus a rarer material at 25% (35% on a later boss)", and mini-bosses dropped fragments toward zone-themed weapons with a guaranteed material bundle. Guaranteed materials plus a chance-based rare is the "always plus independent" shape from section 1, and it keeps every kill feeling worth something.

---

## 9. When not to build all this

- **Small games with a few drops.** Three enemies with one rare each do not need nested tables, alias sampling or replayable seeds. A single table module with expected values in a test is enough.
- **Non-paid, low-stakes drops.** Pity on a common crafting material is noise; use fragments or deterministic rewards.
- **When a deterministic reward would do.** If you find yourself adding pity, duplicate protection and a featured guarantee to a pool, ask whether a fixed reward track would deliver the same pacing more honestly ([[Ethical Design and Player Trust]]).

---

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Odds scattered in enemy scripts | Nobody can answer "average drops per boss" | Drop tables as data |
| Weights and chances mixed in one list | Items far more common than intended | Separate `pick` and `independent` fields |
| Self-referencing sub-tables | Server error or stack overflow on a kill | Depth guard; config validation |
| Effective rate computed for hard pity but the game ramps | Disclosed rate does not match observed | Survival-sum calculation from the real ramp |
| Pack rolls evaluated in a batch | Pity guarantees skipped in ten-packs | Evaluate counters roll by roll |
| Lower-tier pity forced right after a higher hit | "Always an Epic after a Legendary" reports | Higher tier resets lower counters |
| Duplicate protection added as a small tweak | Collections complete far faster than planned | Treat as a pacing change; model it |
| Shared pool changed without versioning | Several enemies' drops change unnoticed | Versioned tables, logged with drops |
| Alias tables everywhere | Complex code, no measurable gain | Linear walk or tiered rolls until profiled |

## Checklist

- [ ] Every drop in the game comes from a named, versioned table.
- [ ] Expected drops per evaluation computed in tests and diffed on every change.
- [ ] Weighted picks and independent chances kept in separate fields; nesting depth guarded.
- [ ] Pity ramps analysed with the survival sum: expected, median, 90th percentile.
- [ ] Multi-counter rules written down; packs evaluated roll by roll.
- [ ] Featured guarantee and carry-over rules decided and saved per player.
- [ ] Duplicate protection modelled as a pacing change; disclosure updated if paid.
- [ ] Observed rates compared to computed rates per pool per day.

## See also
[[Economy Design Start Here]] · [[Currency Architecture - Soft Hard and Event Currencies]] · [[Player-Driven Trading Economies]] · [[Economy Telemetry and Balancing Live]] · [[Simulating an Economy Before Launch]] · [[RNG Drops and Luck Systems]] · [[Rarity Ladders and Drop Pacing Math]] · [[Probability and Statistics for Designers]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Genre Playbook - RNG and Collection Games]] · [[Pet Hatching and Following End to End]]

## Connected notes
<!-- auto-links:start -->
[[Pity Timer]] · [[Expected Value]] · [[Balancing with Spreadsheets and Data]] · [[Variance]] · [[Procedural Loot and Item Generation]] · [[Roblox Policies Ratings and Compliance]]
<!-- auto-links:end -->
