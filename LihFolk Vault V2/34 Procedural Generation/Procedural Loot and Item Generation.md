---
tags: [procedural, generation, loot, items, affixes, economy, rng, datastores, luau, type/guide, area/procedural, level/intermediate]
---
# Procedural Loot and Item Generation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Storing seeds instead of values -> Store rolled values plus data version
> - Avoid: No affix groups -> Mutual exclusion groups
> - Avoid: Independent rolls with wide ranges -> Power budgets or narrower ranges
> - Light generation considered first (base plus quality).
> - Affix defs with tags, groups, ilvl gates, quantised ranges.
> - Generator is pure; simulated at scale; perfect-roll odds converted to hours.
>
> Cost: TL;DR ~150 tok · whole note ~4.6k tok. Read more: ## The generator · ## Storing generated items · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[RNG Drops and Luck Systems]] covers **whether** something drops: weighted tables, luck, pity, odds disclosure. [[Rarity Ladders and Drop Pacing Math]] covers how rare each tier should be. This note covers what happens after the roll says "a rare sword dropped": generating **the item itself**. Stat ranges, affixes, item level, power budgets, names, how to store generated items so a balance patch does not rewrite every inventory, how to keep them dupe-proof, and the economy consequences of near-infinite item variety. It is for action RPGs, looters, roguelikes and any game where two items of the same name can differ.

## Fixed items versus generated items

| | Fixed catalogue | Generated items |
|---|---|---|
| Example | "Flame Sword" always 40 damage | "Flame Sword of Haste": 37 to 44 damage, +6% attack speed |
| Storage | An id | An id plus rolled values |
| Balance patch | Change one number | Decide what happens to millions of existing rolls |
| Trading | Simple: equal ids are equal | Every item needs inspection; prices spread |
| Chase | Collect them all | Find the perfect roll |
| Longevity | Ends when the catalogue is complete | Very long tail |

Generated items add a second dimension of chase on top of rarity: even after finding the right base item, players keep playing for a better roll. That is powerful for retention and expensive in complexity. Many Roblox games get most of the benefit with **light generation**: a fixed catalogue plus one rolled "quality" percentage. Start there and add affixes only if your loop needs it.

## Anatomy of a generated item

A typical structure, borrowed from action RPG conventions:

- **Base**: the catalogue entry (`IronSword`): type, model, base stat ranges, required level.
- **Item level (ilvl)**: where it dropped (zone tier, enemy level). Gates which affixes and ranges are available.
- **Rarity**: decides how many affixes and their tier caps. Rolled first, from your drop table.
- **Implicit stats**: rolled within the base's ranges, scaled by ilvl.
- **Affixes**: extra modifiers drawn from pools (prefixes and suffixes), each with its own rolled value.
- **Unique id**: a GUID so this exact item can be tracked, traded and audited.

### Affix pools with tags and groups

Each affix definition carries:

```lua
--!strict
export type AffixDef = {
	id: string,          -- stable forever: "pre_dmg_flat"
	slot: "prefix" | "suffix",
	group: string,       -- mutual exclusion: two "flatDamage" affixes cannot coexist
	tags: { string },    -- which bases can roll it: { "weapon", "melee" }
	minIlvl: number,     -- not available below this item level
	weight: number,      -- relative chance among eligible affixes
	stat: string,        -- what it modifies: "damageFlat"
	min: number, max: number, -- roll range at minIlvl
	perIlvl: number,     -- range growth per item level above minIlvl
	step: number,        -- quantisation: 1 for flat, 0.01 for percents
	name: string,        -- "Sharp", "of Haste"
}
```

The **group** field is the important nuance. Without it, a weapon can roll "+12 damage" and "+9 damage" as two prefixes, which reads as a bug and doubles the power ceiling. With groups, eligible affixes are filtered by tag and ilvl, then by "group not already taken".

**Tiers** are a common extension: the same group has several defs (`pre_dmg_flat_t1` at ilvl 1, `t2` at ilvl 20, `t3` at ilvl 40) with rising ranges and falling weights. High-ilvl items can still roll low tiers, which keeps perfect items rare without new rarity colours.

## The generator

Item generation is a pure function: catalogue data, ilvl, rarity and a `Random` in, an item table out. That makes it testable and lets you simulate millions of drops offline.

```lua
--!strict
local HttpService = game:GetService("HttpService")

export type BaseDef = { id: string, tags: { string }, implicit: { [string]: { number } } }
export type Item = {
	uid: string, base: string, ilvl: number, rarity: number,
	stats: { [string]: number }, affixes: { { id: string, value: number } },
	v: number, -- generator data version at roll time
}

local AFFIX_COUNT = { -- [rarity] = {prefixMax, suffixMax, totalMin, totalMax}
	[1] = { 0, 0, 0, 0 },  -- common
	[2] = { 1, 1, 1, 2 },  -- uncommon
	[3] = { 2, 2, 3, 4 },  -- rare
	[4] = { 3, 3, 5, 6 },  -- epic
}

local DATA_VERSION = 3

local function quantise(x: number, step: number): number
	return math.floor(x / step + 0.5) * step
end

local function hasAnyTag(def: { tags: { string } }, tags: { string }): boolean
	for _, a in def.tags do
		for _, b in tags do
			if a == b then return true end
		end
	end
	return false
end

local function generate(base: BaseDef, ilvl: number, rarity: number, affixDefs: { any }, rng: Random): Item
	local stats: { [string]: number } = {}
	-- implicits scale gently with ilvl: +1% per level above 1
	local scale = 1 + (ilvl - 1) * 0.01
	local implicitKeys = {}
	for k in base.implicit do table.insert(implicitKeys, k) end
	table.sort(implicitKeys) -- deterministic draw order (see the Seeds note)
	for _, k in implicitKeys do
		local r = base.implicit[k]
		stats[k] = quantise(rng:NextNumber(r[1], r[2]) * scale, 1)
	end

	local caps = AFFIX_COUNT[rarity]
	local total = if caps[4] > 0 then rng:NextInteger(caps[3], caps[4]) else 0
	local takenGroups: { [string]: boolean } = {}
	local counts = { prefix = 0, suffix = 0 }
	local affixes = {}

	for _ = 1, total do
		-- eligible: tag match, ilvl, group free, slot not full
		local pool, weightSum = {}, 0
		for _, a in affixDefs do
			local slotMax = if a.slot == "prefix" then caps[1] else caps[2]
			if a.minIlvl <= ilvl and not takenGroups[a.group] and counts[a.slot] < slotMax
				and hasAnyTag(a, base.tags) then
				table.insert(pool, a)
				weightSum += a.weight
			end
		end
		if #pool == 0 then break end -- nothing fits: fewer affixes, never a crash
		local roll = rng:NextNumber() * weightSum
		local chosen = pool[#pool]
		for _, a in pool do
			roll -= a.weight
			if roll <= 0 then chosen = a break end
		end
		local grow = (ilvl - chosen.minIlvl) * chosen.perIlvl
		local value = quantise(rng:NextNumber(chosen.min, chosen.max + grow), chosen.step)
		takenGroups[chosen.group] = true
		counts[chosen.slot] += 1
		table.insert(affixes, { id = chosen.id, value = value })
		stats[chosen.stat] = (stats[chosen.stat] or 0) + value
	end

	return {
		uid = HttpService:GenerateGUID(false),
		base = base.id, ilvl = ilvl, rarity = rarity,
		stats = stats, affixes = affixes, v = DATA_VERSION,
	}
end

return { generate = generate, DATA_VERSION = DATA_VERSION }
```

`affixDefs` must be an **array in a fixed order** (a config module), not a dictionary, so the weighted pick is reproducible for a given `Random`. The GUID is not part of the deterministic output; tests should compare everything except `uid`.

## Power budgets: generation that balances itself

Independent affix rolls have a problem: a lucky item rolls the top of every range, and its power is far above an average item of the same rarity. Players feel the spread as "my epic is worse than his rare".

A **power budget** fixes the spread. Assign each stat a cost per point (from your balance sheet: 1 damage = 1 point, 1% attack speed = 1.5 points, and so on). Each rarity at each ilvl gets a budget, for example `budget = 20 * rarityMult * (1 + ilvl * 0.05)`. The generator spends the budget across affixes instead of rolling each independently:

1. Pick affixes as above (which ones, not their values).
2. Split the budget among them with random weights (for example, each gets a share drawn from 0.6 to 1.4, then normalised).
3. Convert each share to a value with the stat's cost, then clamp to the affix's range.

Result: items of the same rarity and ilvl have roughly equal total power, with different shapes. The chase shifts from "find the lucky roll" to "find the roll that fits my build", which is healthier for trading and fairness. The cost is that "perfect" items no longer exist in the same way; some games keep a small random **quality** multiplier (0.95 to 1.05) on top to preserve a mild chase.

Use your balance spreadsheet as the source of costs ([[Balancing with Spreadsheets and Data]]) and export it into the config module ([[Data and Config Pipeline - Spreadsheets to Game]]).

## How rare is a perfect item? Do the maths

Designers often ask for "a god roll should be very rare" without computing it. With independent uniform rolls quantised to steps:

- An affix with a range of 10 to 20 in steps of 1 has 11 values; top roll probability 1/11.
- A rare item needs a specific 4 affixes out of an eligible pool: if each pick is weighted, the probability of a specific set is the product of conditional picks (it changes as groups fill).
- Getting the right set **and** top rolls on all four: (set probability) x (1/11)^4, about 1 in 14,600 times the set probability.

Run a simulation instead of trusting intuition. Because `generate` is pure, a million items take seconds in Studio's command bar:

```lua
-- Offline: how often does a rare ilvl-40 sword have both damage groups at 90%+ of max?
local rng = Random.new(1)
local hits = 0
for i = 1, 1000000 do
	local item = Gen.generate(SWORD, 40, 3, AFFIXES, rng)
	if isNearPerfect(item) then hits += 1 end
end
print(("1 in %.0f"):format(1000000 / math.max(hits, 1)))
```

Then convert to hours with drop rates and the pacing method in [[Rarity Ladders and Drop Pacing Math]]. A "very rare" item that takes 3 years of play to find is a design bug, not a chase.

## Names

Generated names are where players actually meet the system. Rules that work:

- **Template by rarity.** Common: base name. Uncommon: "Prefix Base" or "Base of Suffix". Rare and above: a generated two-part name ("Grim Bite") with the affix list shown below it.
- **Name from the strongest affix**, not the first rolled, so the name tells the truth.
- **Word lists per theme**, chosen by a hash of the item uid so the name is stable without storing it. If you store the name instead, you can never fix a bad word list.
- **Filter.** Generated names combine words; two innocent words can make an unfortunate phrase. Review word lists in pairs, keep them short and themed, and never build names from player input without `TextService` filtering. See [[Text Chat Customization with TextChatService]] for filtering context.
- **Localise** word lists and templates, not assembled strings ([[Localization]]).

## Storing generated items

This is the part that bites months later.

### Store values, not seeds

It is tempting to store `{base, ilvl, rarity, seed}` and regenerate stats on load: tiny saves, and stats look "compressed". Do not, for anything players keep:

- **Any change to affix tables changes every item.** Add one affix to the pool, and every stored seed now rolls a different item. Players log in to find their god roll turned into junk.
- **Even reordering the config array** changes results.
- **Engine changes** to `Random` would do the same (unverified risk; see [[Seeds Determinism and Reproducible Worlds]]).

Store the **rolled results**: affix ids and values. Seeds are fine for items that are never saved (a run-only roguelike item) or for preview ("this chest will contain...").

### Compact encoding

A generated item as JSON can easily be 300 bytes. A 500-item inventory is 150 KB, which is large for a profile ([[Data Schema Design and Migrations]] suggests keeping profiles well under 100 KB as a rule of thumb). Compress:

- Short keys: `{b="IronSword", l=40, r=3, a={{"pre_dmg_flat",14},{"suf_as",6}}}`.
- Affix ids as small integers from a **stable, append-only** registry: never renumber, never reuse an id.
- Quantised values as integers (store 6 for 0.06 with a known step).
- For very large inventories, pack into a `buffer` and base64 it ([[Buffers and Binary Data]]).

Cap the inventory and stash sizes; generated items multiply fast because players hoard "maybe useful" rolls ([[Saved Inventory End to End]]).

### Patching balance on existing items

When an affix is too strong, you have three honest options:

| Option | What happens | When |
|---|---|---|
| Change future rolls only | Old items keep their values; new ones roll the new range | Small nerfs; respects players |
| Rescale stored values on load | Migration multiplies old values into the new range, keeping the percentile | Large nerfs; keeps relative rank |
| Legacy flag | Old items marked "legacy" and possibly excluded from some modes | Broken items you cannot leave in competitive play |

Rescaling by percentile is usually fairest: a roll at the 90th percentile of the old range becomes the 90th percentile of the new one. That requires knowing the old range, which is why the item stores `v` (data version) and your config keeps old range tables for migration. See [[Schema Migrations - Worked Case Studies]].

## Server authority and duplication

- **Generate only on the server.** The client receives the finished item to display. Never accept item stats from a remote.
- **Use a non-replicated generator.** If the item's `Random` is derived from a seed the client knows, the client can predict rolls. Use `Random.new()` (engine entropy) for rolls, as in [[RNG Drops and Luck Systems]].
- **Unique ids make dupes visible.** Two items with the same `uid` in different inventories is proof of a duplication bug. Check for duplicate uids on load and in trades; log and quarantine. See [[Trading Systems Without Duplication]] and [[Economy Exploits - Dupes Races and Purchase Abuse]].
- **Validate on load.** An item with an affix id not in the registry, a value outside the widest range ever shipped, or two affixes in the same group is corrupted or forged. Flag it rather than silently deleting; false positives happen after your own migrations.

## Economy effects of variety

Generated items change how an economy behaves ([[Economy Inflation Sinks and Faucets Math]]):

- **Prices spread.** Traders must inspect rolls; casual players get scammed more. A clear item tooltip with roll percentiles ("Damage 14, 80% of range") reduces this.
- **Junk floods inventories.** Most drops are worse than what the player wears. Give junk a purpose: auto-salvage into crafting currency, with a rarity filter the player controls.
- **Rerolling is a sink.** Crafting that rerolls one affix's value, or swaps one affix, is an excellent [[Faucets and Sinks|currency sink]] and a reason to keep a "nearly perfect" item. Price rerolls so expected cost to perfect an item is high but bounded.
- **Rerolls with Robux** are paid randomness: the same disclosure and policy rules apply as for crates. See [[Paid Random Items and Odds Disclosure in Practice]] and [[Roblox Policies Ratings and Compliance]].
- **Power creep via ilvl.** If new zones raise ilvl, old gear becomes salvage automatically. That is intended, but tell players, or rare items feel worthless overnight.

## Testing

- **Distribution tests.** Simulate a million items per rarity and assert affix frequency matches weights within tolerance, and no item breaks group or slot rules.
- **Budget tests.** For budgeted generation, assert total power per rarity per ilvl stays within a band.
- **Round-trip tests.** Encode, decode, compare (excluding nothing). Then decode every fixture from old versions and assert migrations produce valid items.
- **Fuzz validation.** Feed random corrupted items to the validator ([[Testing Your Own Remotes - Fuzzing and Abuse Tests]] shows the mindset).

## When not to generate items

- **Collection games** where the appeal is completing a set: fixed items read better ([[Genre Playbook - RNG and Collection Games]]).
- **Competitive PvP** where stat variance feels unfair: use fixed stats, generate cosmetics only.
- **Small teams without tooling**: generated items need tooltips, comparison UI, salvage, filters and migrations. Budget for all of it or keep generation light.

## Common mistakes

| Mistake | How it shows | Fix |
|---|---|---|
| Storing seeds instead of values | Items change after a patch | Store rolled values plus data version |
| No affix groups | Duplicate stat affixes, runaway power | Mutual exclusion groups |
| Independent rolls with wide ranges | Rare beats epic often | Power budgets or narrower ranges |
| Dictionary-order affix pools | Unreproducible test results | Arrays in a config module |
| Renumbering affix ids | Old saves decode into wrong affixes | Append-only registry |
| Client-predictable roll seeds | Exploiters pick only good drops | Server entropy for rolls |
| No uid | Dupes invisible | GUID per item, checked on load and trade |
| Unbounded inventories | Profile size and save throttling | Caps, salvage, filters |

## Checklist

- [ ] Light generation considered first (base plus quality).
- [ ] Affix defs with tags, groups, ilvl gates, quantised ranges.
- [ ] Generator is pure; simulated at scale; perfect-roll odds converted to hours.
- [ ] Names template-based, filtered word lists, localisable.
- [ ] Saves store values, compact keys, stable ids, data version.
- [ ] Balance patch policy decided before launch.
- [ ] Server-only generation with fresh entropy; uids checked.
- [ ] Salvage, filters and sinks exist for junk.

## See also

- [[Procedural Generation Start Here]], [[RNG Drops and Luck Systems]], [[Rarity Ladders and Drop Pacing Math]]
- [[Saved Inventory End to End]], [[Tools and Inventory Systems]], [[Virtualized Lists and Large Inventories]]
- [[Economies and Currencies]], [[Status Effects Buffs and Stacking Rules]], [[Combat Systems Architecture]]
- [[Seeds Determinism and Reproducible Worlds]], [[Dungeon and Room Generation]]

## Connected notes
<!-- auto-links:start -->
[[Drop Tables Rarity and Pity Systems]] · Expected Value · Pity Timer · Variance · Progression Levels and Unlocks · Deterministic Simulation
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Expected Value]] · [[Pity Timer]] · [[Probability and Statistics for Designers]] · [[Wave Function Collapse on Roblox]] · [[Infinite and Streamed Worlds]] · [[Noise Functions and Terrain Generation]]
<!-- related:end -->
