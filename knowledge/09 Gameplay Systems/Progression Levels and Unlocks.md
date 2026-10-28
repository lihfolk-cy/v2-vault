---
tags: [gameplay, progression, levels, xp, skill-tree, rebirth, crafting, forge]
---
# Progression Levels and Unlocks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Saving level instead of total XP -> Save totals
> - Avoid: Prices as absolute numbers -> Minutes-of-income model
> - Avoid: Incremental skill effects -> Recompute from owned nodes
> - Each axis has a near goal and a far goal at every stage.
> - Costs derived from a documented income model and checked with analytics.
> - All unlocks enforced on the server from saved state.
>
> Cost: TL;DR ~140 tok · whole note ~3.6k tok. Read more: ## 5. Skill trees · ## 6. Item upgrade systems · ## 9. Common mistakes · ## Checklist
<!-- tldr:end -->

Progression is the set of numbers that go up and the things they unlock. Most Roblox games stack several progression axes: player level, gear power, zones unlocked, a skill tree, upgrade levels on items, a prestige reset ("rebirth"), and a collection index. Each axis needs a cost curve, a reward curve, a reason to exist and a clear interaction with the others. This note covers the implementation side: curves and formulas, unlock checks, skill trees, item upgrade systems (forge, fusion, crafting, salvage), rebirth, and how one production game priced all of it in "minutes of income".

Design theory: [[Progression and Pacing Design]], [[Balancing with Spreadsheets and Data]]. Currency side: [[Economies and Currencies]]. Random rewards: [[RNG Drops and Luck Systems]].

Source labels: **Docs**, **Measured** (the reference project), **Rule of thumb**.

---

## 1. Progression axes and what they are for

| Axis | Player feels | Typical unlocks | Reference project |
|---|---|---|---|
| Gear power | "My weapon is stronger" | Damage, new ability kits | Weapon rarity tiers, stats follow odds |
| Zones / gates | "I can go further" | New enemies, materials, drops | 10 zones per realm behind gates |
| Player level / XP | "I'm making progress every minute" | Cosmetics, slots, small stats | XP from kills, a level bar on the profile |
| Skill tree | "I choose how I grow" | Luck, speed, cooldowns, ability levels | A hex board of nodes bought with currency |
| Item upgrades | "I invest in my favourite" | Forge levels, fusion stars | Forge 0 to 3, stars 0 to 5 |
| Rebirth | "I start over stronger" | Permanent multipliers | Rebirth resets cash and gates for a multiplier |
| Collection | "I want them all" | Index rewards, badges | Weapon and enemy index |

Rule of thumb: every axis should either **unlock something new** or **make the core loop faster**, and at least one axis should always be close to its next step (a goal within 1 to 5 minutes) while another is far away (a goal measured in hours).

---

## 2. Curves

### XP per level
Common shapes:

| Curve | Formula (XP to reach the next level) | Feel |
|---|---|---|
| Linear | `a * L` | Levels slow down gently |
| Polynomial | `a * L^p` (p 1.5 to 2.5) | Standard RPG feel |
| Exponential | `a * r^L` (r 1.05 to 1.2) | Steep; pairs with exponential income |

```lua
--!strict
local A, P = 100, 1.8

local function xpToNext(level: number): number
	return math.floor(A * level ^ P)
end

-- Convert total XP into (level, xp into level). Loop is fine for levels in the hundreds.
local function levelFromTotal(total: number): (number, number)
	local level = 1
	local need = xpToNext(level)
	while total >= need do
		total -= need
		level += 1
		need = xpToNext(level)
	end
	return level, total
end
```

Store **total XP** in the save, not the level: changing the curve later recomputes levels from the same totals instead of corrupting them ([[Data Schema Design and Migrations]]).

### Enemy level bands
Tie enemy levels to zones so players can read difficulty: the reference project used `(zone - 1) * 10 + 1` as the start of each zone's band, with rare spawns at the zone's top level + 3.

### Exponential economies
Simulator-style games use exponential costs and incomes (gate prices from thousands to hundreds of millions). Two consequences:
- Use number formatting with suffixes (K, M, B, T) and keep values as doubles; Luau numbers are exact integers up to 2^53, which covers 9 quadrillion, but above that precision drops ([[Luau Language Essentials]]).
- Price everything by **time**, not by absolute numbers (section 3).

---

## 3. Pricing by minutes of income

The most useful pricing technique in an exponential game: decide how many **minutes of play** an unlock should cost at the point it becomes available, then derive the price from the income model at that point.

**Measured.** The reference project re-priced its whole upgrade board this way after a balance pass. The income model assumed a player at zone 1 earns about 1.5K to 3K per minute, at zone 9 about 12M per minute, at the zone 10 boss about 40M, with no VIP. First-ring upgrades cost about 1 to 2 minutes of income at the zone that unlocks them; capstones 1 to 2 hours. The roll luck and roll speed upgrade curves were re-priced on the same model.

```lua
--!strict
-- Income model per zone (currency per minute), from playtests or a spreadsheet.
local INCOME_PER_MIN: { [number]: number } = {
	[1] = 2_000, [2] = 6_000, [3] = 20_000, [4] = 70_000, [5] = 250_000,
	[6] = 800_000, [7] = 2_500_000, [8] = 6_000_000, [9] = 12_000_000, [10] = 40_000_000,
}

local function priceFor(unlockZone: number, minutes: number): number
	local income = INCOME_PER_MIN[unlockZone] or INCOME_PER_MIN[1]
	local raw = income * minutes
	-- Round to 2 significant figures so prices look designed.
	local mag = 10 ^ math.max(0, math.floor(math.log10(raw)) - 1)
	return math.floor(raw / mag + 0.5) * mag
end
```

Then check the model against reality with analytics: median time to afford each gate ([[Analytics and Funnels]]). When reality drifts, change the model and re-run the prices, rather than tweaking items one by one.

---

## 4. Unlock checks are server checks

Every unlock (gate, node, item tier, zone travel, feature) is a server decision based on saved state:

```lua
--!strict
export type Requirement =
	{ kind: "gate", index: number }
	| { kind: "level", min: number }
	| { kind: "rebirths", min: number }
	| { kind: "node", id: string }
	| { kind: "bossKill", id: string }

local function meets(profile: any, req: Requirement): boolean
	if req.kind == "gate" then
		return (profile.GatesUnlocked or 0) >= req.index
	elseif req.kind == "level" then
		return (profile.Level or 1) >= req.min
	elseif req.kind == "rebirths" then
		return (profile.Rebirths or 0) >= req.min
	elseif req.kind == "node" then
		return profile.SkillNodes ~= nil and profile.SkillNodes[req.id] == true
	else
		return profile.BossKills ~= nil and (profile.BossKills[req.id] or 0) > 0
	end
end
```

Mirror the state to the client (attributes or an owner-only channel) for UI, but the client copy is display only. Feature gating has nuances: the reference project's ultimate abilities exist only on Epic-and-above weapons, enforced by the server's ability guard, not just hidden in UI.

---

## 5. Skill trees

A skill tree is a graph of nodes with costs and prerequisites. Implementation checklist:

```lua
--!strict
export type Node = {
	id: string,
	cost: number,
	currency: string,
	requires: { string }, -- any-of or all-of; here all-of
	effects: { [string]: number }, -- e.g. { LuckMult = 0.05 }
}

local function canBuy(profile: any, node: Node, balance: number): (boolean, string?)
	local owned = profile.SkillNodes or {}
	if owned[node.id] then return false, "owned" end
	for _, req in node.requires do
		if not owned[req] then return false, "locked" end
	end
	if balance < node.cost then return false, "funds" end
	return true
end

-- Effects are always recomputed from owned nodes, never accumulated incrementally.
local function totals(nodes: { [string]: Node }, owned: { [string]: boolean }): { [string]: number }
	local out: { [string]: number } = {}
	for id in owned do
		local n = nodes[id]
		if n then
			for k, v in n.effects do
				out[k] = (out[k] or 0) + v
			end
		end
	end
	return out
end
```

Key rule: **derive effects from the owned set** every time it changes. Incremental bookkeeping ("add 5% luck when bought") drifts after refunds, migrations and node edits.

**Measured** from the reference project's hex board:
- An ability arm of 12 nodes: "Quick Recharge I to IV" (cooldowns down 33% total), "Ability Mastery I to IV" (+1 level to every support ability each), "Ability Power I to IV" (+70% ability hit damage over the branch). The server publishes the totals as attributes for kit code to read.
- A navigation rewrite was needed on phones: zoom and pan mixed screen pixels with GUI units, giving wrong zoom focus and a 0.47x drag speed. Treat a big tree as a map with proper pan and zoom maths, tested on phone screens ([[Responsive UI for Phone Tablet Console and PC]]).
- Admin and test accounts had their skills reset separately from real players; keep test resets out of real save paths.

### Respec
Allow a respec (free once, then priced) when you change the tree. Without it, every rebalance strands players with nodes they would not buy now.

---

## 6. Item upgrade systems

### Forge (level up an item)
**Measured.** Forge levels 1 to 3 give +15/30/50% damage and +10/20/30% health. Cost: a primary material matching the item's rarity tier (levels 2 and 3 add the next tier's material) and cash scaled by rarity and by `odds^0.15` (capped at 2.5x). Cash for +1 rose by tier (300; 1K; 3.5K; 12K; 120K; 2.5M; 40M; 400M; 3B), with +2 at 5x and +3 at 13.3x the +1 price. The forge table was re-pegged once gates were rebalanced: an Epic +1 dropped from 150K to about 12 to 15K. **Every upgrade cost must be re-checked when the income curve moves.**

### Fusion (merge duplicates)
**Measured.** Three copies of the same item at the same star level fuse into one star higher (1 to 5 stars), +10% power and income per star; the fused item keeps its unique id and the best forge level of the three. Base copies needed: 3 / 9 / 27 / 81 / 243. Fusion turns duplicate drops (normally disappointing) into progress.

### Crafting up (tier conversion)
**Measured.** Five unstarred items of one rarity craft into one random item of the next rarity, chosen by `1/odds` weight within that tier, refused above the current realm's rarity cap. Auto-pick never takes forged, marked or last copies.

### Salvage (break down)
Salvage converts unwanted items into materials by rarity, with protection rules ([[Tools and Inventory Systems]] section 3). Auto-salvage per rarity (off by default) turns low-rarity rolls into materials at roll time, but never during the tutorial.

These four systems form a loop: drops feed fusion and salvage, salvage feeds the forge, crafting converts surplus into a chance at better tiers. Every item has a use, which is the answer to the player question "what do I do with the swords I don't use?" (the literal request that led to the reference project's fusion system).

---

## 7. Rebirth (prestige)

Rebirth resets part of progress in exchange for a permanent bonus. Design decisions:

| Decision | Options | Reference project |
|---|---|---|
| What resets | Currency, zones, levels, items | Cash and gates |
| What stays | Items, cosmetics, premium currency, the bonus | Items, gems, the furthest built world's first gate |
| The bonus | Income multiplier, luck, new content | Income multiplier |
| Requirement | Currency threshold, zone reached | A cash requirement shown on a progress bar |
| Frequency | Every 30 to 120 min early on | |

Implementation rules:
- **One transaction.** Check requirement, reset, apply bonus, increment the rebirth count, save, all on the server without yielding in between.
- **Do not strand the player.** If rebirth resets zone access, move the player to a valid zone and keep any access needed to reach content they already unlocked by other means (the reference project keeps the first gate of the furthest built world).
- **Show NOW vs AFTER** clearly (income, cash, zones), including what will be lost, in red.
- **Celebrate it.** A big moment (charge-up, burst, sound, title) makes the reset feel like a reward rather than a loss ([[Game Feel and Juice]]).
- **Leaderboard** by rebirths gives long-term players a public goal ([[OrderedDataStores and Leaderboards]]).
- **Use rebirth as a requirement** elsewhere: trading required 2 rebirths in the reference project, which filters fresh alt accounts.

---

## 8. Stats that follow rarity

**Measured.** The reference project's rule "in a tier, rarer is better; stats follow odds" fitted each weapon's power, income and health on a log curve against its roll odds, and re-banded power per tier so tiers never overlap (from 12 for the lowest tier to 226K for the highest). A later difficulty pass scaled enemy health by 1.8, enemy damage by 1.35, cash by 0.55 and XP by 0.6, and wiped player data because the old saves no longer fitted. Lessons:
- Derive stats from one formula so the whole catalogue moves together.
- Never hand-edit a single item's stats out of line with the curve; players notice and the next re-fit undoes it.
- Big rebalances may require a data reset; announce it, keep the old stores untouched so you can roll back, and keep purchase receipts ([[Data Loss Prevention and Recovery]]).

---

## 9. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Saving level instead of total XP | Curve changes corrupt saves | Save totals |
| Prices as absolute numbers | Rebalance breaks everything | Minutes-of-income model |
| Incremental skill effects | Drifting stats after edits | Recompute from owned nodes |
| No respec after tree changes | Angry veterans | Free respec on change |
| Duplicates with no use | Rolls feel wasted | Fusion, salvage, crafting |
| Rebirth strands players | Stuck in a locked zone | Keep access, move them safely |
| Hand-tuned single items | Inconsistent catalogue | Stats from one formula |

## Checklist
- [ ] Each axis has a near goal and a far goal at every stage.
- [ ] Costs derived from a documented income model and checked with analytics.
- [ ] All unlocks enforced on the server from saved state.
- [ ] Skill effects recomputed from the owned set; respec exists.
- [ ] Every item has a use (equip, fuse, salvage, craft).
- [ ] Rebirth is one non-yielding transaction with clear NOW/AFTER UI.

## See also
[[Economies and Currencies]] · [[RNG Drops and Luck Systems]] · [[Quests and Objectives]] · [[Progression and Pacing Design]] · [[Balancing with Spreadsheets and Data]] · [[Genre Playbook - Simulators]] · [[Tools and Inventory Systems]] · [[OrderedDataStores and Leaderboards]]

## Connected notes
<!-- auto-links:start -->
[[Economy Inflation Sinks and Faucets Math]] · [[Pricing Curves and Upgrade Costs]] · [[Power Curve]] · [[Simulator and RNG Genre Teardown]] · [[Genre Playbook - RNG and Collection Games]] · [[Rebirth and Prestige System End to End]]
<!-- auto-links:end -->
