---
tags: [game-design, progression, pacing, curves, rebirth, prestige, math]
---
# Progression and Pacing Design

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Matching cost and reward multipliers exactly -> Let T rise slowly, then drop at milestones
> - Avoid: Tuning curves only in the first 10 steps -> Check the end of every ladder; anchor and solve for the base
> - Avoid: Linear rebirth multiplier against exponential rebirth cost -> Geometric multiplier slightly below the cost growth
> - T(n) plotted for the whole ladder, sawtooth confirmed.
> - Each curve anchored to a design target and solved, not guessed.
> - Rebirth time per rebirth rises gently, with new multiplier sources planned.
>
> Cost: TL;DR ~180 tok · whole note ~5.0k tok. Read more: ## 3. A worked zone ladder (reference project) · ## 5. Rebirth and prestige maths · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

Progression is the shape of a player's growth over time; pacing is how that growth **feels** minute by minute. On Roblox the standard tools are exponential cost curves, zone or gate ladders, power numbers, and a reset loop (rebirth or prestige) that turns the late game into a faster replay of the early game. This note gives the maths, the reasons each curve behaves as it does, the production numbers from one game's zone ladder, and the traps (compounding sensitivity, number overflow, rebirths that get slower forever).

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production RNG combat game, anonymised), **Rule of thumb**.

---

## 1. What you are actually designing

Progression has three quantities, and pacing is the ratio between them:

| Quantity | Symbol | Example |
|---|---|---|
| Cost of the next step | C(n) | Price of gate n, XP for level n, power needed for stage n |
| Income or power growth | I(n) | Cash per minute at zone n, damage of the best weapon you can get there |
| Time per step | T(n) = C(n) / I(n) | Minutes to afford gate n |

Players never feel C or I directly. They feel **T**. A designer who makes every cost "x3" and every reward "x3" has made a flat T: the numbers race upward but each step takes the same time, which reads as a treadmill once the player notices. Most good curves make T **rise slowly** over a region, then **drop** at a milestone (new region, rebirth, new weapon tier), giving a sawtooth.

```
T(n)
 |        /|        /|
 |      /  |      /  |      /
 |    /    |    /    |    /
 |  /      |  /      |  /
 |/        |/        |/
 +-----------------------------> n
   region 1  region 2  region 3   (drop = new income source / rebirth)
```

---

## 2. Curve families

| Curve | Formula | Feels like | Use for |
|---|---|---|---|
| Linear | C = a + b n | Fair, quickly boring | Small counts (quest goals, kills per stage) |
| Polynomial | C = a n^k (k 1.5 to 3) | Gently steepening | Level XP, skill costs |
| Exponential | C = a r^n | Numbers explode; time depends on income curve | Simulator prices, gates, upgrades |
| Exponential with steps | C = a r^n, plus jumps at region borders | Sawtooth pacing | Zone ladders with portals |
| Logistic / capped | C saturates | Diminishing returns | Stat caps, luck caps |

### Why exponentials dominate Roblox simulators
Simulators reward **multiplicative** upgrades (x2 pets, x1.5 tools, rebirth multipliers). Multiplicative income grows exponentially, so costs must too, or the player outruns the content in an evening. Exponentials also produce the giant numbers (millions, trillions, "Qa") that this audience enjoys reading out. The cost is balance fragility: small changes to the base compound into huge differences (section 4).

### The geometric sum (buy-N and "buy max")
If item n costs `a r^n`, buying k items starting at index n costs

```
S = a r^n (r^k - 1) / (r - 1)
```

and the most items affordable with money M is

```
k = floor( log( M (r - 1) / (a r^n) + 1 ) / log(r) )
```

Use these instead of a loop for "BUY MAX" buttons, and compute them on the server.

---

## 3. A worked zone ladder (reference project)

The reference project replaced "worlds" with one ladder of numbered zones, ten per region, a boss every tenth zone, a mini-boss at every fifth, and one zone number driving gate prices, enemy levels, materials, quests and the roll rarity cap.

### Proposal versus decision

| Version | Gate price rule | Result |
|---|---|---|
| Old world 1 | about x8 per zone | $900M by gate 7: too steep to stretch over 30 zones |
| Proposal | `P(z) = 2500 * 2.6^(z - 2)` | z10 $5.2M, z20 $72B, z30 $105T, z60 about 1e25 |
| Decision | "Flat-ish inside a region, a big jump at each region portal" | see below |

Implemented (phase 1):
- Region 1: ten gates from **$2.5K, x3 per gate, to about $49M** (2,500 x 3^9 = 49.2M).
- Region 2's first zone is a **free portal** unlocked by killing the region boss.
- Region 2: **$2.5B, x2.2 per gate, to about $1.4T** at zone 20 (2.5B x 2.2^8 = 1.37T).

Why the designer preferred that shape: the in-region multiplier sets the minute-to-minute pace, and the cross-region jump (about 50x from $49M to $2.5B) is paid for by the **new income source** a region brings (better enemies, a higher roll rarity cap, new materials). The boss kill, not the cash, is the region gate.

Other ladder rules from the same plan:
- Enemy level band `L(z) = round(3.8 z)`, +4 across the zone, boss at band end + 4.
- Material tier `tier(z) = clamp(1 + floor((z - 1) * 8 / 50), 1, 9)` plus a small chance of the next tier.
- Roll rarity cap `capRank(z) = 5 + region(z) - 1` (Legendary in region 1, Mythic in region 2, and so on), set by the **furthest zone unlocked**, so buying the portal gate is what raises the cap.
- Variant enemies in a region's second half: +15% size, +30% health, +15% damage, one extra trait.
- Elite spawns: 1 in 8 in later zones, x2.5 health, an aura and an extra drop roll.

### Time targets from the revamp plan
The project's revamp plan set **time** targets, not price targets, and derived prices from them:
- each zone should take about **8 to 12 minutes** for an average player;
- a starter weapon kills a zone-1 regular in about **3 hits**;
- enemy health about **+55% per zone**, coins per kill about **x1.6 per zone**, with players expected to "outscale through rolls";
- mini-boss about 25x a regular's health, world boss about 150x.

Notice the mismatch built into those numbers: health grows 1.55x per zone but coins only 1.6x, so the **kill rate** must also grow (better weapons) or the time per zone climbs. That is intended: the roll and forge loops are what keep T flat.

### Pricing in minutes of income
When the project re-priced its upgrade board, every cost was set as **minutes of income at the zone where it unlocks**: first-ring upgrades about 1 to 2 minutes, capstones about 1 to 2 hours. The income model behind it (no VIP, no rebirths) ran from about $1.5K to $3K per minute in zone 1 to about $12M per minute in zone 9 and about $40M at the zone-10 boss.

This is the single most useful pricing habit in this note. Prices written as "minutes at zone z" stay meaningful when you retune income later, and they translate directly into pacing. See [[Balancing with Spreadsheets and Data]].

---

## 4. Compounding sensitivity

Small changes to an exponential base are not small.

The project's stage-based plan used a **Recommended Power** per stage `P(n) = 20 * 1.16^(n - 1)`, with mini-boss stages at x1.6. An earlier draft used 1.17. At stage 50:

| Base | P(50) | Mini-boss x1.6 |
|---|---|---|
| 1.16 | 20 x 1.16^49 = about 28,800 | about 46,100 |
| 1.17 | 20 x 1.17^49 = about 43,900 | about 70,200 |

One percentage point in the base raised the stage-50 requirement by about **52%**, which "put the stage-50 boss past any rollable blade". The general rule: the ratio between two bases after n steps is `(r1 / r2)^n`. Over 50 steps, 1.17/1.16 compounds to about 1.52; over 100 steps, to about 2.3.

Practical consequences:
- Always check the **end** of a curve, not just the first ten steps.
- Pin the curve to an **anchor**: "the best weapon a player can roll in region 1 must clear stage 50 with one forge level to spare", then solve for the base.
- Tune one base at a time, with a spreadsheet that shows the whole ladder.

Solving for a base that hits an anchor:

```
r = (P_end / P_start) ^ (1 / (n_end - n_start))
```

If stage 1 needs 20 power and stage 50 must need at most 30,000, r = (30000 / 20)^(1/49) = 1500^(1/49) = about 1.161.

---

## 5. Rebirth and prestige maths

A **rebirth** (prestige, ascension) resets short-term progress (cash, gates, sometimes upgrades) in exchange for a **permanent multiplier** and often a rebirth currency. It is the standard long loop on Roblox because it reuses existing content and gives the late game a "go fast" feeling.

### The basic model
Let the rebirth cost (cash you must hold, or a zone you must reach) be `R(k) = R0 g^k` for rebirth k, and the permanent income multiplier after k rebirths be `m(k)`.

Time to reach rebirth k+1, if base income is roughly constant across the early ladder, is about

```
T(k) ~ R(k + 1) / (I_base * m(k))
```

| Multiplier rule | m(k) | T(k) behaviour if g = 2 |
|---|---|---|
| Linear | 1 + 0.5 k | T grows almost as 2^k: each rebirth takes much longer |
| Geometric, slower than cost | 1.5^k | T grows as (2 / 1.5)^k = 1.33^k: gently longer |
| Geometric, equal to cost | 2^k | T flat: rebirths become a fixed-length loop |
| Geometric, faster than cost | 2.5^k | T shrinks: runaway; the reset becomes trivial |

Most designers want T to **rise slowly** (the 1.5^k row): each rebirth a bit longer, with new content or a new multiplier source (rebirth shop, pets, gear) making up the difference. A linear multiplier against an exponential cost is the most common mistake: rebirth 3 takes 20 minutes, rebirth 10 takes 15 hours, and players stop.

### Prestige currency from lifetime earnings
Idle games often pay a prestige currency proportional to a root of lifetime earnings, for example `currency = floor(sqrt(lifetimeCash / C0))`. The root means that doubling your earnings before resetting gives only about 1.41x more prestige, which discourages over-grinding a single run and makes "reset early, reset often" a real strategy. Rule of thumb, not a Roblox convention.

### What a rebirth should keep
| Keep | Reset | Why |
|---|---|---|
| Rebirth count and multiplier | Soft currency | Core of the trade |
| Collection/index, cosmetics, weapons | Gate unlocks (most of them) | Losing your collection feels like theft |
| Fast travel to the start of the furthest region | Upgrades bought with soft currency (optional) | Avoids replaying content the player has outgrown |
| Quest and achievement progress | | |

The reference project's rebirth kept the first gate of the furthest region the player had built up to, reset cash to zero, and showed a **now versus after** comparison (income multiplier, cash, zones) with a "RESETS" tag on the cash line, so nobody rebirths without understanding the cost. A rebirth also plays a large celebratory effect visible to the whole server (gold rings, a light pillar, a burst), which turns a reset into a status moment.

### Rebirths as gates
The project also made some gates require a number of rebirths (and made rebirths a requirement for trading). That ties the long loop into the short loop: a player stuck at a gate is shown "Rebirth now" as the next goal, with the hand on the rebirth button. Use this carefully: if the rebirth requirement arrives before the player understands rebirths, it reads as a wall.

### Story goals beyond rebirths
Rebirth alone is a number. The project's later design gave the long loop **direction** with a goal chain that runs through rebirths and continues past them: rebirth when a gate asks for it, open the gate, beat the region boss, enter the next realm, and so on to the final boss, each with a small reward and a trail. Rebirth then sits inside a story of places and bosses rather than being the whole long loop. See [[First-Time User Experience and Onboarding]] for the goal chain.

---

## 6. Gating content by rarity and power

Two gating styles appear across Roblox genres:

| Style | Gate condition | Pro | Con |
|---|---|---|---|
| Price gate | Pay currency to open | Always reachable by grinding | Can feel like a tax |
| Power gate | Recommended power / level check | Clear skill-and-gear target | Hard stop if power cannot be raised |
| Boss gate | Defeat a boss | Big memorable milestone | The funnel cliff (82% drop at the boss step in the reference project's tutorial funnel) |
| Rebirth gate | N rebirths | Ties long loop to short | Confusing if unexplained |
| Time gate | Wait N hours | Paces whales and grinders equally | Feels artificial; invites skip purchases |

The reference project combined price gates inside a region with a boss gate at the region border, and capped the rarity a player can **roll** by the furthest zone reached (rolls bought with Robux were not capped). Capping by progress keeps a lucky early roll from trivialising the whole game, and gives every region a visible new prize tier.

Every hard gate needs: a number the player can compare against (price, power), a way to raise that number by more than one route, and a cheap retry. See [[Core Loops and Session Design]].

---

## 7. Displaying huge numbers

Exponential games pass 1e15 quickly. Luau numbers are IEEE doubles: exact integers up to 2^53 (about 9.007e15), approximate after that, and finite up to about 1.8e308. That is plenty for display and multiplication, but **exact integer comparisons beyond 2^53 are unreliable**, and currency stored as a double above that loses its last digits. Rules:
- Compare with a small tolerance or in log space above about 1e15.
- Never use huge doubles as DataStore keys or table keys.
- Store and display with a suffix table that runs past T.

```lua
--!strict
-- Short number formatting: 1234 -> "1.23K", 4.2e15 -> "4.20Qa"
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function short(n: number): string
	if n ~= n then return "0" end -- NaN guard
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local tier = math.floor(math.log10(n) / 3)
	if tier >= #SUFFIXES then
		return sign .. string.format("%.2e", n) -- beyond the table: scientific
	end
	local scaled = n / 10 ^ (tier * 3)
	-- 3 significant figures: 1.23K, 12.3K, 123K
	local fmt = if scaled < 10 then "%.2f" elseif scaled < 100 then "%.1f" else "%.0f"
	local text = string.format(fmt, scaled)
	-- Rounding can produce "1000K"; bump to the next suffix.
	if tonumber(text) and (tonumber(text) :: number) >= 1000 and tier + 1 < #SUFFIXES then
		return sign .. "1.00" .. SUFFIXES[tier + 2]
	end
	return sign .. text .. SUFFIXES[tier + 1]
end

return short
```

The reference project's progress bars use exactly this "3 significant figures" style ("4.62K / 7.40K").

---

## 8. Pacing the minute-to-minute feel

Numbers set the long rhythm; pacing tools set the short one.

| Tool | Effect |
|---|---|
| Sawtooth difficulty | Each zone starts easy relative to the last zone's end, then ramps |
| Mini-boss every 5, boss every 10 | Predictable peaks the player can anticipate |
| First-clear bonus, half pay on replay | Pushes forward without forbidding farming (the stage plan paid 50% on replays) |
| Reward ~1.2x per stage clear | Small, steady growth (stage plan) |
| A new enemy or mechanic every zone | Novelty prevents the treadmill feeling ("1-2 enemies that are new every time" was the designer's brief) |
| Catch-up mechanics | Friend boosts, server luck events, comeback quests keep late joiners in the group |
| Rest areas | Hubs, shops, crafting between fights; tension then release |

### Too fast versus too slow
| Symptom | Diagnosis |
|---|---|
| Players finish the content in one or two sessions | Early curve too generous, long loop missing |
| Players stall at one gate and leave | T spikes at that step; check income source or add an alternative route |
| Players skip whole zones | Reward per zone too flat relative to the next zone |
| Players farm zone 1 forever | Replay pay too high or later zones too risky |

The reference project hit "too fast" at the very start and responded by slowing the first few minutes (Commons only for a new player's first 60 to 240 seconds of play) instead of making enemies harder. It hit "too slow" at bosses and responded with open, resettable boss fights and a visible power number. Measure progression with `AnalyticsService:LogProgressionEvent` and its Start/Complete/Fail variants, and watch the time-per-step distribution, not just the average. See [[Analytics and Funnels]].

---

## 9. Code: one module for the curves

Keep every curve in one shared, pure module so client previews and server checks agree.

```lua
--!strict
-- ReplicatedStorage/Curves (ModuleScript). Pure functions: safe to require anywhere.
local Curves = {}

export type Region = { firstZone: number, lastZone: number, firstPrice: number, growth: number }

-- Region 1: $2.5K x3; region 2: portal free, then $2.5B x2.2 (reference project values).
Curves.Regions = {
	{ firstZone = 1,  lastZone = 10, firstPrice = 2_500,         growth = 3.0 },
	{ firstZone = 11, lastZone = 20, firstPrice = 2_500_000_000, growth = 2.2 },
} :: { Region }

function Curves.regionOf(zone: number): (Region?, number)
	for i, r in Curves.Regions do
		if zone >= r.firstZone and zone <= r.lastZone then
			return r, i
		end
	end
	return nil, 0
end

-- Price to open `zone`. The first zone of every region after the first is a free portal.
function Curves.gatePrice(zone: number): number
	local r, index = Curves.regionOf(zone)
	if not r then return math.huge end
	if index > 1 and zone == r.firstZone then return 0 end
	local start = if index > 1 then r.firstZone + 1 else r.firstZone
	return r.firstPrice * r.growth ^ (zone - start)
end

-- Recommended power per stage, mini-boss stages x1.6.
function Curves.recommendedPower(stage: number): number
	local p = 20 * 1.16 ^ (stage - 1)
	return if stage % 10 == 0 then p * 1.6 else p
end

-- Minutes of income a price represents (for tuning sheets and tooltips).
function Curves.minutesOf(price: number, incomePerMinute: number): number
	return price / math.max(incomePerMinute, 1e-9)
end

-- Most items affordable when item i costs a * r^i, starting from index n.
function Curves.maxAffordable(money: number, a: number, r: number, n: number): number
	local first = a * r ^ n
	if money < first then return 0 end
	return math.floor(math.log(money * (r - 1) / first + 1) / math.log(r))
end

return Curves
```

Check: `gatePrice(1)` = 2,500; `gatePrice(10)` = 2,500 x 3^9 = about 49.2M; `gatePrice(11)` = 0; `gatePrice(12)` = 2.5B; `gatePrice(20)` = 2.5B x 2.2^8 = about 1.37T.

The server must still validate every purchase against these numbers; see [[Server Authority and Validation]].

---

## 10. Common mistakes

| Mistake | Better |
|---|---|
| Matching cost and reward multipliers exactly | Let T rise slowly, then drop at milestones |
| Tuning curves only in the first 10 steps | Check the end of every ladder; anchor and solve for the base |
| Linear rebirth multiplier against exponential rebirth cost | Geometric multiplier slightly below the cost growth |
| Rebirth resets collections | Keep collections, cosmetics, quests |
| Hard boss gate with no alternative | Open fights, power number, second route |
| Prices as raw numbers in scattered scripts | One curves module; prices as "minutes of income" in the sheet |
| Comparing currencies above 2^53 exactly | Tolerance or log space; suffix display |

## 11. Checklist

- [ ] T(n) plotted for the whole ladder, sawtooth confirmed.
- [ ] Each curve anchored to a design target and solved, not guessed.
- [ ] Rebirth time per rebirth rises gently, with new multiplier sources planned.
- [ ] Rebirth keeps collections and shows now-vs-after before confirming.
- [ ] Every gate has a number, two routes and a cheap retry.
- [ ] Suffix table reaches past your largest value; huge numbers never used as keys.
- [ ] One shared curves module; server validates.
- [ ] Progression events logged and time-per-step distributions reviewed.

## See also
- [[Balancing with Spreadsheets and Data]], [[Core Loops and Session Design]], [[Retention and Return Hooks]]
- [[Progression Levels and Unlocks]], [[Economies and Currencies]], [[RNG Drops and Luck Systems]]
- [[Genre Playbook - Simulators]], [[Genre Playbook - RNG and Collection Games]], [[Genre Playbook - Combat and RPG]]
- [[Analytics and Funnels]], [[Math Vectors and CFrames]]

## Connected notes
<!-- auto-links:start -->
[[Power Curve]] · [[Rebirth and Prestige System End to End]] · [[Simulator and RNG Genre Teardown]] · [[Pricing Curves and Upgrade Costs]] · [[Economy Inflation Sinks and Faucets Math]] · [[Simulating an Economy Before Launch]]
<!-- auto-links:end -->
