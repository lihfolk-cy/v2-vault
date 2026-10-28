---
tags: [game-design, genre, simulator, multipliers, pets, rebirth]
---
# Genre Playbook - Simulators

<!-- tldr:start -->
> [!tldr] TL;DR
> - Players stop at zone 3 to 5: Zone price outruns income; no new reason to push -> Re-price in minutes of income; add a visible reward per zone
> - Late-game numbers meaningless: Uncapped multiplicative stacking -> Category caps; rebalance
> - Inventory clutter on phones: No duplicate handling -> Fuse, salvage, auto-delete options
> - Core verb feels good with no rewards attached.
> - Collect/sell rhythm measured: seconds to fill, walk share of the cycle.
> - Multipliers stacked by category with caps; breakdown visible to players.
>
> Cost: TL;DR ~170 tok · whole note ~3.4k tok. Read more: ## 4. Multiplier stacking · ## 6. Pets and eggs · ## 10. Failure modes · ## 11. Checklist
<!-- tldr:end -->

"Simulator" on Roblox does not mean a realistic simulation. It means a **collect, sell, upgrade, expand, rebirth** game: swing a tool (or click, mine, lift, catch, dig), fill a capacity, cash it in, buy a better tool and a bigger bag, open the next area, hatch pets that multiply everything, and eventually reset for a permanent multiplier. The docs list Simulator among Roblox's common genres (Docs, "Design for Roblox"). This playbook explains why the formula works for this audience, the anatomy of a simulator, the multiplier maths that holds it together, and how to stand out in the most crowded genre on the platform.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production RNG combat game with simulator structure, anonymised), **Rule of thumb**.

---

## 1. Why simulators work on Roblox

| Audience trait | How the simulator formula fits |
|---|---|
| Mostly mobile | One-thumb verb (tap or hold); auto-modes |
| Young | No failure states; numbers always go up; bright feedback |
| Short sessions | Every 30 seconds produces a sale; every few minutes an upgrade |
| Social | Pets, titles and big numbers are visible status; shared hub |
| Discovery rewards play days | Eggs, quests, gifts and rebirths give daily reasons to return |
| Players follow creators | Rare pet hatches and huge numbers make good clips |

The weaknesses come from the same places: the verb is shallow, so the game relies entirely on progression and collection for depth, and there are thousands of competitors with the same structure. A simulator wins on **feel, theme, pacing and content cadence**, not on mechanics.

---

## 2. Anatomy of a simulator

| Part | Role | Typical form |
|---|---|---|
| Core verb | Produces the primary resource | Swing, click, mine, lift, catch |
| Capacity | Limits a run; creates the sell trip | Backpack, storage, stamina |
| Sell point | Converts resource to currency | Pad in the hub or each zone |
| Tool upgrades | Raise resource per action | A ladder of tools, exponential prices |
| Capacity upgrades | Longer runs | Bags, tanks |
| Zones | New resources worth more; gated by price or requirement | 10 to 30 zones, themes per zone |
| Pets (or companions) | Multipliers, collection, status | Eggs per zone with rarity tiers |
| Rebirth | Long loop: reset for permanent multiplier | Requirement doubles or more per rebirth |
| Boosts | Short multipliers | Potions, server boosts, events |
| Quests and timers | Return hooks | Dailies, free gifts, spin wheels |
| Codes | Community and creator hook | Rewards for codes shared on social channels |

The reference project is a hybrid: its "verb" is fighting enemies with weapons you roll, but its outer structure is pure simulator (gates bought with cash, zone ladder, upgrade board, rebirths, offline vault, potions, free gifts, server luck boosts). Most of its pacing lessons apply directly.

---

## 3. The collect and sell cycle

The capacity limit is what makes a simulator a loop rather than a counter. A run is:

```
run time = capacity / collect rate + walk time to the sell point (both ways)
income per minute = (capacity * value per unit) / run time  (in minutes)
```

Design levers:
- **Walk time** is a cost. Early, a short walk teaches the cycle. Later, it becomes friction; that is why "auto-sell" and "teleport to sell" are classic passes. Rule of thumb: keep walking under about a quarter of the cycle, or add sell pads in every zone.
- **Capacity versus collect rate.** If capacity upgrades lag far behind tool upgrades, players fill the bag in seconds and spend most of their time walking. If they lead far ahead, the bag never fills and the cycle disappears. Keep the "seconds to fill" in a band (for example 20 to 60 s; rule of thumb) across the ladder.
- **Value per unit** rises by zone. That is what makes a new zone worth its price.

Many modern simulators drop the sell trip entirely (resources go straight into currency). That removes friction but also removes the rhythm and the most natural pass. Decide deliberately.

---

## 4. Multiplier stacking

Simulators are built on multipliers: tool, pets, rebirths, passes, potions, events, friends, group membership. How you **combine** them decides whether the economy is tunable.

| Stacking | Formula | Effect |
|---|---|---|
| All additive | 1 + a + b + c | Easy to control; each new multiplier feels weaker as the total grows |
| All multiplicative | (1 + a)(1 + b)(1 + c) | Each multiplier feels strong; totals explode; hard to balance |
| Additive within a category, multiplicative between categories | (1 + sum of pets)(1 + sum of boosts)(rebirth multiplier)(pass multiplier) | The usual compromise (rule of thumb) |

The category approach lets you reason about each category's cap separately: "pets can give at most x40 at zone 20, rebirths at most x16, passes x2, boosts x3", so the worst case is x3,840, and you can price zones against it.

```lua
--!strict
-- ReplicatedStorage/Multipliers (ModuleScript)
-- Additive inside a category, multiplicative between categories.
export type Sources = { [string]: { [string]: number } } -- category -> source -> bonus (0.5 = +50%)

local Multipliers = {}

-- Caps per category (example values): the max total bonus the category may add.
Multipliers.Caps = {
	Pets = 39,    -- up to x40
	Boosts = 2,   -- up to x3
	Friends = 0.3,
}

function Multipliers.total(sources: Sources, rebirthMult: number, passMult: number): number
	local product = rebirthMult * passMult
	for category, list in sources do
		local sum = 0
		for _, bonus in list do
			sum += bonus
		end
		local cap = Multipliers.Caps[category]
		if cap then
			sum = math.min(sum, cap)
		end
		product *= (1 + sum)
	end
	return product
end

return Multipliers
```

Compute the total on the server, publish it as an attribute for the HUD, and show players **where their multiplier comes from** (a breakdown panel). Players love seeing x1,240 broken into its parts; it also makes every new source feel concrete.

### Luck is a multiplier too
In RNG-flavoured simulators luck is stacked the same way. The reference project's luck sources included a pass, friends in the server, potions, rare weather, a server-wide luck product and a permanent bundle bonus, all combined into one "standing luck" value shown top-left (for example "1.00x"). The display matters: players should never wonder whether a boost is active. See [[Genre Playbook - RNG and Collection Games]].

---

## 5. Zones and gates

- **Price gates** with exponential prices are the default. The reference project's region 1 ran ten gates from $2.5K at x3 per gate to about $49M; region 2 opened through a free portal after the region boss and then ran $2.5B at x2.2 per gate to about $1.4T. See [[Progression and Pacing Design]].
- Each zone must bring **something new**: a resource worth more, a new pet egg, a new enemy, a new look. A zone that is only "the same thing, bigger number" is a treadmill.
- Show the **next zone's price and reward** on the gate itself. A gate that says "$114K: Frost Peaks, 2x coins, Frost Egg" sells itself.
- Fast travel between unlocked zones is expected. Players should never walk through ten zones to reach their own.

---

## 6. Pets and eggs

Pets are a simulator's collection layer and usually its main multiplier.

| Element | Design notes |
|---|---|
| Eggs per zone | Each zone's egg has its own pool; later eggs have better pets |
| Rarity tiers | 5 to 9 tiers; rarer pets give bigger multipliers |
| Equip slots | 3 to 6 at start; more slots are a common pass or upgrade |
| Fusing / crafting | Combine duplicates into a stronger version (reduces inventory clutter, adds a sink) |
| Index | A collection screen with completion rewards |
| Display | Pets follow the player; rare ones have effects |

Two rules that are not optional:
- **Eggs bought with Robux, or with a currency that Robux can buy, are paid random items.** All outcomes and their odds must be shown as percentages summing to 100% before purchase, luck boosts sold for Robux are "probability modifiers" that must be explained numerically, and players flagged by `PolicyService` (`ArePaidRandomItemsRestricted`) need an alternative (Docs, "Paid random items"). An egg bought only with soft currency earned in play is not a paid random item, but if that soft currency can also be bought with Robux, it is.
- Pet multipliers must be included in the multiplier caps above, or the late game explodes.

### Duplicates
Simulators generate thousands of low-value items. Give them a purpose: fuse into stronger versions, salvage into crafting materials (the reference project's salvage-then-forge loop), or auto-delete by rarity (an option players control). An inventory full of junk on a phone is a UX failure. The reference project's designer asked "what should players do with the swords they don't use", and the answer was fusion stars, tier-up crafting and auto-salvage.

---

## 7. Rebirths

The rebirth is the simulator's long loop. Core rules (detailed maths in [[Progression and Pacing Design]]):
- Rebirth requirement grows geometrically; the multiplier should grow geometrically too, slightly slower, so each rebirth takes a little longer.
- Show **now versus after** before confirming: the reference project's rebirth panel listed income multiplier, cash (with a red "RESETS" tag) and zones.
- Keep pets, the index and cosmetics. Reset currency and most gates.
- Make it a moment: the reference project plays a server-visible effect with a sound on every rebirth.
- Consider **rebirth tokens** or a rebirth shop so rebirths buy choices, not only a number.

---

## 8. Monetisation patterns (and their limits)

Common simulator products (prices vary widely; these are the reference project's examples):

| Product type | Reference project example | Notes |
|---|---|---|
| Multiplier pass | VIP 399 R$ (x2 cash, x1.5 XP, x1.1 luck, +25 daily gems, x1.5 backpack cap) | The most common pass |
| Speed pass | Fast Roll 299 R$ | Removes friction from the core verb |
| Extra action | Double Roll 599 R$ | Two results per action |
| Luck pass or product | Lucky Rolls 75 R$, Server Luck Boost 99 R$ | Probability modifier: must be explained numerically |
| Currency pack | More Cash 79 R$, gem packs | Price in "minutes saved" in your sheet |
| Bundle | 1,499 R$ (a top-tier item, permanent 2x luck, 500 gems) | High value anchor |

See [[Game Passes]], [[Developer Products and ProcessReceipt]] and [[Pricing and Store Design]]. Simulators are also where the most aggressive monetisation patterns appear (fake timers, pop-ups on every join, "only 1 left"). Do not use them; see [[Ethical Design and Player Trust]].

---

## 9. Standing out

Every simulator has the same parts, so differentiation comes from:

| Lever | Example |
|---|---|
| A verb with real feel | Satisfying impacts, sounds, screen shake (see [[Game Feel and Juice]]) |
| A second verb | Combat, building, fishing, racing on top of the collect loop |
| Theme and humour | Strong, readable identity in the icon and first 30 seconds |
| A twist on collection | Pets that evolve, items with stories, mutations |
| Social events | Server-wide bosses, races, raids |
| Content cadence | New zone or egg every 2 to 4 weeks (docs cadence guidance) |

The reference project's twist was replacing the click verb with **real-time sword combat** and replacing pets with **rolled weapons that each have their own animated ability kit**. That raised production cost enormously (dozens of ability kits) but made every rare pull feel different, not just bigger.

---

## 10. Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Players stop at zone 3 to 5 | Zone price outruns income; no new reason to push | Re-price in minutes of income; add a visible reward per zone |
| Late-game numbers meaningless | Uncapped multiplicative stacking | Category caps; rebalance |
| Inventory clutter on phones | No duplicate handling | Fuse, salvage, auto-delete options |
| Servers look dead | Everyone in different zones or AFK | Hub activities, server events, fewer zones per region |
| Revenue but falling D7 | Long loop is only rebirths | Story goals, collections, events |
| Complaints about eggs | Odds unclear or misleading | Percent odds, pity, honest animations |

## 11. Checklist

- [ ] Core verb feels good with no rewards attached.
- [ ] Collect/sell rhythm measured: seconds to fill, walk share of the cycle.
- [ ] Multipliers stacked by category with caps; breakdown visible to players.
- [ ] Each zone adds a new resource, egg or enemy, not just a bigger number.
- [ ] Paid eggs and luck products disclose percentage odds; policy-restricted players handled.
- [ ] Duplicates have a use.
- [ ] Rebirth shows now-vs-after and keeps collections.
- [ ] A differentiating twist that shows in the first minute.

## See also
- [[Core Loops and Session Design]], [[Progression and Pacing Design]], [[Balancing with Spreadsheets and Data]]
- [[Genre Playbook - Tycoons]], [[Genre Playbook - RNG and Collection Games]], [[Genre Playbook - Combat and RPG]]
- [[Economies and Currencies]], [[RNG Drops and Luck Systems]], [[Progression Levels and Unlocks]]
- [[Monetization Overview]], [[Pricing and Store Design]], [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Simulator and RNG Genre Teardown]] · [[Economy Inflation Sinks and Faucets Math]] · [[Pet Hatching and Following End to End]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Case Study - Pet Simulator 99]] · [[Power Curve]]
<!-- auto-links:end -->
