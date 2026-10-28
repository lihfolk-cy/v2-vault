---
tags: [economy, pricing, upgrades, curves, progression, math, balancing, luau]
---
# Pricing Curves and Upgrade Costs

[[Economy Inflation Sinks and Faucets Math]] prices zone gates from an income model and checks the ratio of price growth to income growth. [[Progression and Pacing Design]] and [[Balancing with Spreadsheets and Data]] set the pacing targets. This note goes one level down, to the **per-level upgrade track**: the "level 37 of 100, next level costs 4.2K" button that most Roblox games have several of. It covers which curve family to use and what each one does to the player over time, the payback period that decides when players stop buying, how several tracks compete for the same coins, buy-max arithmetic, rounding prices to readable numbers without breaking the curve, refunds and respecs, and how to put all of this on the server.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**. The maths is standard. Code is strict Luau, reviewed by reading, not run; the numeric tables were computed with a short script.

---

## 1. Price is only half of a curve

An upgrade track has two curves: **cost of level L** and **benefit of level L**. Players do not respond to either one alone. They respond to how much benefit a coin buys, and for income upgrades, to how quickly the upgrade pays for itself. Designers who tune only the cost curve end up with tracks that are either ignored or bought to infinity.

Write each track down as a pair:

```
cost(L)    = price of going from level L to L + 1
benefit(L) = what level L + 1 adds over level L
```

and decide which of three kinds of benefit it gives, because the right cost curve depends on it:

| Benefit kind | Example | What the player compares |
|---|---|---|
| Income | +4% coins per level | Payback time |
| Power | +2% damage per level | Time saved on the content in front of them |
| Convenience | +1 inventory slot, +1 auto-roll speed | A feeling, not a number |

---

## 2. Curve families and what they do

| Family | `cost(L)` | Feels like | Typical use |
|---|---|---|---|
| Linear | `a + b L` | Steady; cheap late | Short tracks (10 levels), convenience |
| Polynomial | `a (L + 1)^k`, k 1.5 to 3 | Gentle start, firm late | Power tracks in games without exponential income |
| Exponential | `a r^L`, r 1.07 to 1.25 | Each level a fixed % pricier | Idle and simulator tracks with exponential income |
| Exponential with polynomial | `a r^L (L + 1)^k` | Exponential, steeper early | Long tracks where the first levels must not be trivial |
| Piecewise | Different curve per band, joined | Explicit "tiers" of a track | Tracks with milestones (every 25 levels a bonus) |
| Soft cap | Exponential, then a much larger `r` after `L_cap` | A wall | Stopping a track without a hard max |

The **ratio between consecutive costs** is what players feel, not the absolute number. For an exponential curve it is constant (`r`); for a polynomial it shrinks toward 1 (`((L + 2) / (L + 1))^k`), so late levels of a polynomial track feel cheaper and cheaper relative to the previous one even though they cost more. That is fine for a capped 20-level track and wrong for an uncapped one.

**Rule of thumb for r on exponential tracks:** 1.07 to 1.10 for tracks the player should buy dozens of levels on in a session, 1.12 to 1.18 for tracks bought a few levels per session, 1.2 and up only near a cap.

---

## 3. Payback: the number that decides when players stop

For an income upgrade, the payback period is the time the new level needs to earn back its own price:

```
payback(L) = cost(L) / extra income per minute from level L + 1
```

Players do not compute it, but they feel it: an upgrade that pays back in two minutes is "obviously worth it", one that pays back in two hours is "not worth it right now". They stop buying around the point where payback exceeds the time they expect to keep playing in this zone.

### Additive bonus with exponential cost: a natural cap

Take a track giving `+4%` of base income per level (additive), base income `I = 100` per minute, so each level adds `4` coins per minute. Cost `150 * 1.15^L`.

| Level L | Cost | Payback (minutes) |
|---|---|---|
| 0 | 150 | 37.5 |
| 5 | 302 | 75 |
| 10 | 607 | 152 |
| 20 | 2,455 | 614 |

If players stop when payback exceeds 60 minutes, they stop at `L* = ln(60 * 4 / 150) / ln(1.15) ≈ 3.4`, so after level 3 or 4. That number is the **real** length of the track, whatever its max level says. Two consequences:

- **The cap is set by `r` and the zone's income, not by `maxLevel`.** If income in the next zone is 2.6 times higher and costs scale with the zone too, the same track resets its natural cap every zone. If costs do not scale with the zone, every new zone pushes `L*` up by `ln(2.6) / ln(1.15) ≈ 6.8` levels.
- **Additive bonuses decay in relative value.** Level 20 adds 4 coins on a base that is already `1 + 0.8 = 1.8` times bigger, so its relative gain is 2.2%, not 4%. The player feels the gain shrink while the price grows. That double squeeze is the usual reason a track feels "dead" after level 10.

### Multiplicative bonus: no natural cap

Now make each level multiply income by `1.04`. The benefit of level `L` grows with income itself, so payback is:

```
payback(L) = a r^L / (I * 1.04^L * 0.04) = (a / (0.04 I)) * (r / 1.04)^L
```

With `r = 1.15`, payback grows by `1.15 / 1.04 ≈ 1.106` per level, much slower than the additive track. With `r = 1.04`, payback is constant forever and the track is bought to infinity: every coin goes into it, income explodes, and every other price in the game is now too cheap.

**Rule:** a multiplicative income upgrade needs `r` comfortably above its own multiplier, and its effect must be counted in the payer gap and stacking rules from [[Economy Inflation Sinks and Faucets Math]] section 2. Multiplicative tracks are the single most common source of runaway income in simulator updates.

---

## 4. Power upgrades: price against the content

A damage track has no payback. Its value is **time saved on the content in front of the player**. If enemies in zone `k` have `HP_k` and the player deals `D(L)` per second, kill time is `HP_k / D(L)`. A level that adds 2% damage saves about 2% of fight time, which converts to income through kills per minute.

So a power track **is** an income track one step removed, and it should be priced in the same unit: minutes of income. The common bug is pricing damage upgrades from a separate spreadsheet tab with its own curve, then discovering that the damage track pays back three times faster than the coin track and nobody buys coin upgrades (or the reverse).

**Worked example (rule of thumb arithmetic).** In zone 4 income is 2,000 per minute and is limited by kill speed. Track A: +4% coins per level, cost `600 * 1.15^L`. Track B: +4% damage per level, cost `600 * 1.15^L`. If kill speed fully limits income, +4% damage gives roughly +4% kills and so +4% coins. The tracks are equivalent and players will alternate. If half of the income comes from a source not limited by kills (idle income, quests), track B is worth half as much and should cost about half, or give +8%.

The test is to simulate both purchase orders ([[Simulating an Economy Before Launch]]) and check that the cheapest path through the content uses a mix of tracks, not one.

---

## 5. Several tracks competing for the same coins

Players (and every guide on the internet about your game) converge on the **greedy path**: always buy the upgrade with the best benefit per coin right now. Your intended path does not matter; the greedy path does.

Procedure:

1. Express every track's benefit in one unit (percent income, or minutes saved per hour).
2. At each step, compute `benefit / cost` for the next level of every track.
3. Buy the best one, repeat for a play session's worth of income.
4. Look at the resulting levels.

If one track ends at level 40 and the others at 2, the others are decoration. Fix by bringing their benefit per coin into the same range, not by adding a requirement ("track B needs track A level 10"), which players experience as a chore.

**Interleaving by design.** If you want players to alternate, give the tracks the same `r` and costs offset so their benefit per coin lines up. If you want a "main" track and "side" tracks, give side tracks a lower `r` and lower caps so they are cheap fillers between main levels.

**Measured in the reference project:** an upgrade board and a forge were each priced by hand. After a difficulty pass that cut cash income, the forge was found to be priced against the old income model, with an upgrade that should have cost roughly 12 to 15K costing 150K. Repricing every track from one income model, rather than fixing the complained-about price, was the fix ([[Economy Inflation Sinks and Faucets Math]] section 1 tells the same story from the gate side).

---

## 6. Buy-max and bulk purchases

"Buy x10" and "Buy max" buttons are expected in simulators. They must be computed on the server from the request "buy max on track X", never from a count the client sends ([[Server Authority and Validation]]).

### Closed form for unrounded exponential costs

For `cost(L) = a r^L`, buying `n` levels from level `L0` costs a geometric sum:

```
total(L0, n) = a r^L0 (r^n - 1) / (r - 1)
```

The largest affordable `n` with `M` coins is:

```
n = floor( ln(1 + M (r - 1) / (a r^L0)) / ln r )
```

**Worked example.** `a = 100`, `r = 1.15`, `L0 = 10`, `M = 50,000`: `n = 21`, costing about 48,065; a 22nd level would make it 55,680.

Floating point can push `n` one off at the boundary, so check `total(n) <= M` and `total(n + 1) > M` and adjust by one. At very large `L` the term `r^L0` overflows doubles (around `1.15^5000`); tracks that long need the mantissa-exponent numbers from [[Big Numbers Precision and Formatting]].

### Prefix sums for rounded or hand-edited costs

As soon as prices are rounded (section 7) or edited by hand, the closed form is wrong by a few percent per level, and the error accumulates over a bulk purchase. Then precompute cumulative costs once and binary search:

```lua
--!strict
-- ReplicatedStorage/Shared/UpgradeTrack.lua (pure functions, usable by server and UI)
export type Track = {
	costs: { number },      -- costs[i] = price of going from level i-1 to level i
	cumulative: { number }, -- cumulative[i] = total price of levels 1..i
}

local UpgradeTrack = {}

function UpgradeTrack.new(costs: { number }): Track
	local cumulative = table.create(#costs, 0)
	local sum = 0
	for i, c in costs do
		assert(c > 0 and c == math.floor(c), "integer costs only")
		sum += c
		cumulative[i] = sum
	end
	return { costs = costs, cumulative = cumulative }
end

-- Total price of going from `level` to `level + n`.
function UpgradeTrack.costOf(t: Track, level: number, n: number): number
	if n <= 0 then
		return 0
	end
	local before = if level > 0 then t.cumulative[level] else 0
	return t.cumulative[level + n] - before
end

-- Largest n affordable with `money`, capped at the track's max level. O(log levels).
function UpgradeTrack.buyMax(t: Track, level: number, money: number): (number, number)
	local maxN = #t.costs - level
	local lo, hi = 0, maxN
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if UpgradeTrack.costOf(t, level, mid) <= money then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo, UpgradeTrack.costOf(t, level, lo)
end

return UpgradeTrack
```

The server handler then does: validate the track id, read the level and balance from the profile, call `buyMax`, spend through the wallet ([[Currency Architecture - Soft Hard and Event Currencies]]), set the level, all in one non-yielding block. Bulk purchases are also the obvious place for a race ("click Buy max twice in one frame"), which is why the level and balance must be read and written together without a yield between them ([[Economy Exploits - Dupes Races and Purchase Abuse]]).

**Display nuance.** "Buy max (21 levels, 48.1K)" is better than "Buy max": players who see the count decide faster, and the number on the button is what the server will charge, computed by the same shared module.

---

## 7. Rounding to readable numbers without breaking the curve

Raw curves produce prices like 1,076.1. Players read rounded prices more easily, and designers like them. Rounding has two traps.

### Trap 1: coarse "nice" steps steepen the curve

A popular approach rounds to the nearest value in a "nice" series (1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, times a power of ten) and forces each level to be strictly more expensive than the last. With `r = 1.15`, those nice steps are wider than `r` (the series jumps 1.2x to 1.33x per step), so the "strictly increasing" rule pushes every level to the next step. Computed for `cost(L) = 100 * 1.15^L`:

| Level | Raw | Nice series, forced increase | Two significant figures |
|---|---|---|---|
| 0 | 100 | 100 | 100 |
| 5 | 201 | 300 | 200 |
| 10 | 405 | 1,000 | 400 |
| 15 | 814 | 3,000 | 810 |
| 20 | 1,637 | 10,000 | 1,600 |

The nice-series track costs six times the intended price by level 20, and its effective `r` is about 1.26, not 1.15. Nobody intended that; it fell out of a formatting decision.

**Rule:** the rounding step must be finer than the curve's ratio. Two significant figures gives steps of 1% to 10% and stays within about 5% of the raw curve at every level, which is fine for `r` of 1.10 and above. For `r` below about 1.08, use three significant figures or round only the display, not the stored price.

### Trap 2: rounding that is not monotonic

Rounding each price independently can produce a level that costs the same as, or less than, the previous one at the boundaries between powers of ten (999.6 rounds to 1,000, 1,040 rounds to 1,000). Players notice, and buy-max code that assumes strictly increasing costs can misbehave. Always run a monotonic pass after rounding: if a level is not more expensive than the one before, bump it by one rounding unit.

```lua
--!strict
-- Round a raw curve to `sig` significant figures, keeping it strictly increasing.
local function roundCurve(raw: { number }, sig: number): { number }
	local out = table.create(#raw, 0)
	local prev = 0
	for i, x in raw do
		local exponent = math.floor(math.log10(x)) - (sig - 1)
		local unit = 10 ^ math.max(exponent, 0) -- never round below 1 coin
		local v = math.floor(x / unit + 0.5) * unit
		if v <= prev then
			v = prev + unit
		end
		out[i] = v
		prev = v
	end
	return out
end
```

Store the rounded prices in the config ([[Data and Config Pipeline - Spreadsheets to Game]]) rather than rounding at runtime, so the server, the UI and the simulation all use identical numbers.

---

## 8. Track length, caps and milestones

- **Hard cap (maxLevel).** Clear and honest. Players like a visible finish ("MAX"). Use for convenience tracks and anything that would break the game if unbounded (walk speed, cooldown reduction).
- **Soft cap.** The curve steepens sharply past a level. Use when you want whales and grinders to have something to spend on without a ceiling. Disclose the steepening in the UI ("costs rise faster after level 50") or players feel cheated when the price triples.
- **Milestones.** A bonus every N levels (every 25th level doubles the effect) makes long tracks feel like a sequence of short goals. They also create price cliffs in players' perception, so put a visible "next milestone in 7 levels" next to the price.

**Cooldown and speed tracks need caps from physics, not economy.** A cooldown that reaches zero, an attack speed beyond what the server can validate, or walk speed beyond what streaming and anti-cheat tolerate ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]) are bugs regardless of price. Set the cap from the system's limits first, then fit the price curve to it.

---

## 9. Refunds, respecs and resets

- **Full refunds** make tracks free experiments. Good for skill trees with real choices; bad for income tracks (refund, rebuy elsewhere, repeat to probe for loops).
- **Partial refunds** (rule of thumb 50 to 80%) keep respec meaningful while letting players fix a bad decision. They are a sink: count them.
- **Respec items** (a paid or rare consumable) move the decision into the premium shop; be careful, selling the fix for a confusing system is a trust problem ([[Ethical Design and Player Trust]]).
- **Rebirth resets.** If a rebirth resets upgrade tracks, the next run's track prices need to account for the rebirth multiplier, or the tracks are maxed in the first minutes of every run ([[Rebirth and Prestige System End to End]]). Price tracks from the run's income, including the multiplier.

---

## 10. When not to use a curve at all

- **Short games and cosmetic economies.** Five fixed prices in a table are easier to read and tune than a formula.
- **Upgrades that change how the game plays** (a new ability, a second weapon slot). They are content, priced as gates, not levels on a track.
- **When you cannot explain the benefit in one line.** A track whose benefit is "complicated" will be bought or ignored by guide consensus, not by your curve.

---

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Cost curve tuned without the benefit curve | One track maxed, others untouched | Compare benefit per coin on the greedy path |
| Multiplicative income upgrade with low `r` | Income explodes after an update | `r` well above the per-level multiplier; count it in stacking |
| Polynomial cost on an uncapped track | Late levels feel trivially cheap | Exponential cost or a cap |
| Damage and coin tracks priced separately | Players skip one track entirely | Price both in minutes of income |
| Coarse nice-number rounding | Track far steeper than designed | Two or three significant figures |
| Independent rounding | Two levels at the same price | Monotonic pass |
| Buy-max computed on the client | Levels bought below cost by exploiters | Server computes `n` from the request |
| Closed-form buy-max on rounded prices | Charged amount differs from the button | Prefix sums and binary search |
| Track not rescaled per zone | Players max tracks in new zones in seconds | Costs scale with zone income |

## Checklist

- [ ] Every track has a cost curve and a benefit curve, both written down.
- [ ] Payback time per level computed; natural cap `L*` known per zone.
- [ ] Multiplicative tracks checked against stacking rules and payer gap.
- [ ] All tracks expressed in one value unit; greedy path simulated.
- [ ] Rounding finer than `r`; monotonic pass applied; rounded prices stored in config.
- [ ] Buy-max computed on the server with prefix sums; button shows count and total.
- [ ] Speed and cooldown caps set from system limits before pricing.
- [ ] Refund and respec rules counted as sinks.

## See also
[[Economy Design Start Here]] · [[Currency Architecture - Soft Hard and Event Currencies]] · [[Simulating an Economy Before Launch]] · [[Economy Telemetry and Balancing Live]] · [[Economy Inflation Sinks and Faucets Math]] · [[Progression and Pacing Design]] · [[Progression Levels and Unlocks]] · [[Balancing with Spreadsheets and Data]] · [[Big Numbers Precision and Formatting]] · [[Interpolation Easing and Curves Math]] · [[Rebirth and Prestige System End to End]] · [[Genre Playbook - Simulators]]

## Connected notes
<!-- auto-links:start -->
[[Power Curve]] · [[Faucets and Sinks]] · [[Economies and Currencies]] · [[Simulator and RNG Genre Teardown]] · [[Genre Playbook - Tycoons]] · [[Expected Value]]
<!-- auto-links:end -->
