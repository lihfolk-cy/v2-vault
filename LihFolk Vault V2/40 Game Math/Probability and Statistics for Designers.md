---
tags: [math, game-math, probability, statistics, rng, balancing, analytics, design, luau, type/guide, area/math, level/intermediate]
---
# Probability and Statistics for Designers

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Treating 1 in N as "within N tries" -> Plan with the 90th and 99th percentile tries; add pity
> - Avoid: Additive stacking without a cap -> Cap and show the cap, or switch to independent stacking
> - Avoid: "+20%" meaning relative -> Word as x1.2 or show final values
> - Every chance in config has its "90 percent of players by try N" number written next to it.
> - Stacking model (additive, independent, relative) is chosen per stat and stated in the UI.
> - Builds with breakpoints are compared by simulation, not by expected value.
>
> Cost: TL;DR ~180 tok · whole note ~4.9k tok. Read more: ## 3. Expected value is half the story · ## 4. Streaks at population scale · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Designers set chances and read numbers every day, and both jobs go wrong in predictable ways. A "1 percent chance" is not "once in 100 tries" for the player who is on try 300. A crit build that looks twice as strong on paper is 15 percent stronger in practice. A drop-rate bug that halves a legendary's odds is invisible in a day of test rolls. A dashboard average says a change helped when it hurt most players. This note gives the small set of tools that prevent those mistakes, each tied to a gameplay decision.

What is already covered elsewhere: weighted picks, luck multipliers and pity systems in [[RNG Drops and Luck Systems]]; mean, median and p90 time-to-drop, geometric rarity ladders, collection completion and luck inflation in [[Rarity Ladders and Drop Pacing Math]]; random number generators and seeding in [[Math Vectors and CFrames]]. This note does not repeat them. It covers chance stacking, expected value with variance, streaks at population scale, controlled randomness (pseudo-random distribution and shuffle bags), testing that your rates are right, and reading analytics without fooling yourself.

---

## 1. "At least once" and why players feel cheated

The chance of at least one success in `n` independent tries at probability `p` is

`P(at least one) = 1 - (1 - p)^n`

At 1 percent per try:

| Tries | Chance of at least one | Players (of 100,000) still without it |
|---|---|---|
| 50 | 39.5% | 60,500 |
| 100 | 63.4% | 36,600 |
| 200 | 86.6% | 13,400 |
| 300 | 95.1% | 4,900 |
| 460 | 99.0% | 1,000 |
| 690 | 99.9% | 100 |

Two design truths fall out of this table. First, "1 in 100" leaves more than a third of players empty-handed at 100 tries; many of them believe the game is rigged. Second, the unlucky tail is long and populated: in a game with 100,000 players chasing that item, a thousand of them are still without it after 460 tries. Those players write the reviews.

The inverse question, "how many tries until X percent of players have it?", is `n = ln(1 - X) / ln(1 - p)`. For `p = 0.01` and `X = 0.9`, `n = 229`. That is the number to compare with how many tries a player makes per session; it tells you how many sessions your unlucky tenth of players will grind. If that number is too high, the fix is a cap (pity) or reduced variance (section 4), not a higher base rate, because raising the rate also speeds up the lucky majority who were fine.

---

## 2. Stacking chances: additive, multiplicative, independent

A player has three sources of crit chance: 10 percent base, +15 percent from a ring, +20 percent from a buff. There are three ways to combine them, and they diverge fast.

| Model | Formula | Result for 10, 15, 20 | Can reach 100%? |
|---|---|---|---|
| Additive | `sum(p_i)` | 45% | Yes, and beyond (cap needed) |
| Independent rolls | `1 - product(1 - p_i)` | 1 - 0.9 * 0.85 * 0.8 = 38.8% | Never |
| Multiplicative bonus | `base * product(1 + b_i)` | 0.1 * 1.15 * 1.2 = 13.8% (if bonuses are relative) | Only with huge bonuses |

**Additive** is easy to explain and to show in UI ("Crit: 45%"), but it hits 100 percent and then wastes every further point. Add a cap, and show the cap in the UI so players stop investing.

**Independent rolls** ("each source gets its own chance") have diminishing returns built in: each new source only applies to the cases the others missed. It never reaches certainty, which suits dodge and block, where 100 percent would break combat. The cost: it is hard for players to predict, so show the combined number.

**Relative bonuses** ("+20% crit chance" meaning 20 percent more of your chance) are easy to misread. Players read "+20%" as additive 20 points. If you use relative bonuses, word them as "x1.2 crit chance" or show the final number. Mismatched wording is one of the most common sources of "this item does nothing" bug reports.

The same three models apply to luck multipliers, drop bonuses and damage reduction. For damage reduction, independent stacking (`1 - product(1 - r_i)`) is the standard way to stop players from reaching invulnerability ([[Status Effects Buffs and Stacking Rules]], [[Combat Systems Architecture]]).

---

## 3. Expected value is half the story

**Expected value** is the average outcome per try. For a crit system:

`E[damage per hit] = base * (1 + p * (m - 1))`

where `p` is crit chance and `m` the crit multiplier. With `p = 0.25` and `m = 2`, expected damage is 1.25 times base. Doubling crit damage to `m = 3` gives 1.5 times; doubling crit chance to `p = 0.5` also gives 1.5 times. On average the two upgrades are equal. In play they are not, because of **variance**.

The variance of a single hit is `base^2 * p * (1 - p) * (m - 1)^2`. The `p = 0.5, m = 2` build has variance `0.25 * base^2`; the `p = 0.25, m = 3` build has `0.75 * base^2`, three times as much. The second build kills some enemies in fewer hits and some in more. Whether that is good depends on breakpoints:

**Breakpoints beat averages.** If an enemy has 300 health and base damage is 100, the question players feel is "how many hits does it take?", not "what is my average damage?". Work it out for both builds:

| Hits to kill (300 HP, base 100) | Build A: 50% crit, x2 | Build B: 25% crit, x3 |
|---|---|---|
| 1 | 0% | 25% (one crit is exactly 300) |
| 2 | 75% (any crit in two hits) | 18.75% (normal, then crit) |
| 3 | 25% | 56.25% |
| Average hits | 2.25 | 2.31 |

Same expected damage, nearly the same average hit count, completely different feel. Build B one-shots a quarter of the time and is slower than A most of the time. Raise enemy health to 301 and B's one-shots vanish: a one-point change in a config file flips the best build. That is the point: for anything with breakpoints (health thresholds, one-shot boss mechanics, kill-before-escape windows), tabulate small cases and simulate larger ones rather than reasoning from averages. A Monte Carlo of a few hundred thousand fights runs in well under a second in Luau (rule of thumb) and answers the real question:

```lua
--!strict
-- Distribution of hits needed to kill, for a crit build. Returns {hits -> fraction}.
local function hitsToKill(health: number, base: number, critChance: number, critMult: number, trials: number, seed: number): { [number]: number }
	local rng = Random.new(seed)
	local counts: { [number]: number } = {}
	for _ = 1, trials do
		local hp, hits = health, 0
		while hp > 0 do
			hits += 1
			local dmg = if rng:NextNumber() < critChance then base * critMult else base
			hp -= dmg
		end
		counts[hits] = (counts[hits] or 0) + 1
	end
	for k, v in counts do
		counts[k] = v / trials
	end
	return counts
end

-- print(hitsToKill(300, 100, 0.5, 2, 200000, 1))
-- print(hitsToKill(300, 100, 0.25, 3, 200000, 1))
```

The simulator reproduces the table above and scales to cases you cannot tabulate by hand (damage ranges, armour, regeneration). Shapes like these are what players feel. Put the simulator in a Studio command bar session, not in the game ([[Command Bar and Studio Scripting]]).

**Variance also shapes perceived fairness in PvP.** High-variance damage feels exciting when you win and robbed when you lose. Competitive modes usually cut variance (lower crit chance, lower multiplier, or no crits); casual and PvE modes can afford more. This is a design choice; make it explicitly.

---

## 4. Streaks at population scale

Players notice streaks: five misses at 80 percent hit chance, three legendaries in a row. The chance of a specific streak for one player is small; the chance that someone, somewhere, gets it today is close to certain.

- Five misses in a row at 80 percent hit chance: `0.2^5 = 0.032%`, about 1 in 3,125 per five-swing window. A popular combat game sees hundreds of millions of swings a day. Thousands of players get that streak daily, and some post clips.
- A 1-in-a-million event with 10 million rolls a day happens about 10 times a day, and the probability of zero occurrences in a day is about `e^-10`, effectively never.

This is why a game needs **controlled randomness** wherever a streak would feel broken, and why "it is just bad luck" is not a support answer. Two standard tools:

### Pseudo-random distribution (PRD)

Instead of a fixed chance `p`, each try has chance `C * k`, where `k` counts tries since the last success. After a success, `k` resets to 1. With the right `C`, the long-run rate equals the nominal `p`, but streaks of misses become impossible past `ceil(1 / C)` tries and runs of successes become rare. The constant `C` is smaller than `p` and must be solved numerically:

```lua
--!strict
-- Long-run success rate of a PRD with increment c.
local function prdRate(c: number): number
	local expected = 0       -- expected tries until success
	local pNotYet = 1        -- probability no success so far
	local k = 1
	while pNotYet > 1e-12 do
		local pk = math.min(1, c * k)
		expected += k * pNotYet * pk
		pNotYet *= (1 - pk)
		k += 1
	end
	return 1 / expected
end

-- Find c so that the long-run rate equals p (bisection; rate increases with c).
local function prdConstant(p: number): number
	local lo, hi = 0, p
	for _ = 1, 60 do
		local mid = (lo + hi) / 2
		if prdRate(mid) < p then
			lo = mid
		else
			hi = mid
		end
	end
	return (lo + hi) / 2
end

-- prdConstant(0.25) is roughly 0.085: first try 8.5%, then 17%, 25.5%, ...
-- A miss streak can never exceed ceil(1 / c) - 1 tries.
```

Precompute constants for the chances you use and keep them in config. The PRD state (`k`) belongs to one player and one effect, lives on the server, and should usually reset on death or zone change so it cannot be "charged" by idling on weak enemies. Do not use PRD for anything disclosed as a fixed chance in a paid context: the per-try chance is no longer the disclosed number ([[Paid Random Items and Odds Disclosure in Practice]]).

### Shuffle bags

For small discrete outcome sets (which of five daily quests appears, which weapon a chest gives from a short list, which enemy type spawns next), put the outcomes in a bag in their target proportions, shuffle, and draw without replacement. Refill when empty. Over each bag the proportions are exact; streaks are bounded by the bag's size.

```lua
--!strict
-- Returns a draw function. items must be non-empty.
local function newShuffleBag<T>(items: { T }, rng: Random): () -> T
	local pool: { T } = {}
	return function(): T
		if #pool == 0 then
			pool = table.clone(items)
			rng:Shuffle(pool)
		end
		return table.remove(pool) :: T
	end
end

-- local nextSpawn = newShuffleBag({ "Grunt", "Grunt", "Grunt", "Archer" }, Random.new())
-- print(nextSpawn())
```

`Random:Shuffle` shuffles an array in place (Roblox docs (as of October 2026)). A bag of `{A, A, A, B}` guarantees one B per four draws. Larger bags feel more random; smaller bags feel more fair. A known artefact: at a bag boundary, B can come up twice in a row (last of one bag, first of the next). If that matters, reshuffle when the first draw of a new bag repeats the last draw of the old one, accepting a tiny bias.

**When not to control randomness:** for rare, celebrated drops that players expect to be pure luck (the 1-in-10,000 shiny), PRD or bags change the story; pity counters that are visible are more honest ([[RNG Drops and Luck Systems]]).

---

## 5. Is my drop rate actually right?

Configuration bugs in drop tables are common: a weight typed as `5` instead of `0.5`, a luck multiplier applied twice, a filter that removes a rarity tier for some players. You cannot see these by watching a handful of rolls. You need enough samples and an interval.

**Sample size.** To measure a rate `p` to within a relative error `r` with 95 percent confidence, you need roughly

`n = 3.84 * (1 - p) / (p * r^2)`

To confirm a 1-in-1,000 drop is within 10 percent of its target, `n = 3.84 * 0.999 / (0.001 * 0.01)`, about **384,000 rolls**. To within 25 percent, about 61,000. A playtest of a few hundred rolls tells you nothing about rare tiers: you will see zero or one, and both are consistent with rates from far too low to far too high. Measure rare rates with a server-side simulation of the real roll function (same code path, same config, many iterations) and with live analytics events, never by eye.

**An interval that behaves at small counts.** The textbook interval `p +/- 1.96 * sqrt(p(1-p)/n)` fails for rare events: with zero successes it claims a width of zero. Use the Wilson interval:

```lua
--!strict
-- 95% Wilson score interval for k successes in n trials.
local function wilson(k: number, n: number): (number, number)
	if n == 0 then
		return 0, 1
	end
	local z = 1.96
	local phat = k / n
	local denom = 1 + z * z / n
	local centre = (phat + z * z / (2 * n)) / denom
	local half = z * math.sqrt(phat * (1 - phat) / n + z * z / (4 * n * n)) / denom
	return math.max(0, centre - half), math.min(1, centre + half)
end

-- 3 legendaries in 2,000 rolls: wilson(3, 2000) is about (0.0005, 0.0044).
-- A configured 1/1000 (0.001) is inside: consistent. A configured 1/100 is not: investigate.
```

The decision rule for QA: if the configured rate is outside the interval, the drop table or the code path is wrong. If it is inside, you have not proved it right, only failed to prove it wrong; collect more if the item matters.

**Zero successes.** With zero hits in `n` tries, a quick 95 percent upper bound for the true rate is about `3 / n` (the "rule of three"). Zero legendaries in 3,000 rolls means the rate is probably below 1 in 1,000, not that it is zero.

**Testing randomness with fixed seeds.** Unit tests that roll real randomness and assert on the result are flaky by design. Seed a `Random` in tests and assert on exact sequences for logic, and run large-sample statistical checks as separate, slower jobs with intervals ([[Automated Testing with TestEZ and Jest-Lua]]).

---

## 6. Reading analytics without fooling yourself

The same mistakes recur in every live game's dashboards.

**Means lie on skewed data.** Spend, playtime, currency balance and session length are heavily skewed: a few players are far above everyone else. A mean session length of 25 minutes can sit next to a median of 8. Report medians and percentiles (p25, p50, p75, p90) for anything skewed, and treat the mean as "total divided by players", useful for revenue sums and nothing else ([[Analytics and Funnels]]).

**Compare like with like.** After an update, average session length rose. But the update also brought a marketing push that pulled in new players, whose sessions are shorter, and an exodus of casual players, whose sessions were also short. Mix changes can move an average in the opposite direction to every subgroup (Simpson's paradox). Split metrics by cohort (new versus returning, platform, region) before concluding anything.

**Differences need intervals.** Variant A converts 4.1 percent, variant B 4.5 percent. With 2,000 players per variant, the 95 percent intervals overlap heavily; that is noise. The rough sample size per variant to detect a change from `p1` to `p2` (95 percent confidence, 80 percent power) is about

`n = 7.85 * (p1(1-p1) + p2(1-p2)) / (p1 - p2)^2`

For 4.1 percent versus 4.5 percent that is about 40,000 players per variant. Small games cannot detect small effects; test big changes, or run longer. [[A-B Testing and Experiments on Roblox]] covers the platform side.

**Survivorship.** Day-30 players love the late game. Of course they do: the players who hated it left before day 30. Measure late-game satisfaction from the players who reached it and then left, as well as those who stayed.

**Peeking.** Checking an experiment every day and stopping when it "looks significant" inflates false positives several-fold. Fix the sample size or the duration before you start.

---

## 7. Making randomness feel fair

Players do not judge the distribution; they judge their own stories. Some rules of thumb that keep stories good:

- **Show the number.** Visible odds, visible pity progress, visible combined crit chance. Uncertainty about the rules feels worse than bad luck within known rules ([[Ethical Design and Player Trust]]).
- **Separate stakes from rolls.** High-variance outcomes on low-stakes rolls (cosmetic variants, bonus coins) are fun. High variance on high stakes (losing an item on a failed upgrade) feels punitive; reduce variance where the cost of losing is high.
- **Roll once, server side, and remember.** Players who reconnect and see a different outcome for the same chest assume manipulation. Decide the outcome on the server, store it, and replay the reveal ([[Server Authority and Validation]]).
- **Beware the "near miss".** Reveal animations that deliberately show the top prize just missing are manipulative and, for paid randomness, a compliance risk ([[Roblox Policies Ratings and Compliance]]).
- **Gambler's fallacy runs both ways.** Players expect a win after many losses. If you do not use pity, do not imply it; if you do, show it.

---

## Common mistakes

| Mistake | What it looks like | Fix |
|---|---|---|
| Treating 1 in N as "within N tries" | Support tickets, "rigged" reviews | Plan with the 90th and 99th percentile tries; add pity |
| Additive stacking without a cap | Players at 130% crit, wasted points | Cap and show the cap, or switch to independent stacking |
| "+20%" meaning relative | "This item does nothing" | Word as x1.2 or show final values |
| Comparing builds by average damage | Players find a "worse" build kills faster | Simulate breakpoints |
| Verifying a rare rate with a playtest | Bugged rates ship | Simulate the real roll path; Wilson interval |
| Flaky RNG unit tests | Random CI failures | Fixed seeds for logic, separate statistical jobs |
| Means on skewed metrics | Misleading dashboards | Medians and percentiles |
| Stopping experiments early | Changes that "worked" and then did not | Fix sample size before starting |
| PRD on disclosed paid odds | Disclosed chance is wrong per try | Fixed chance plus visible pity |

## Checklist

- [ ] Every chance in config has its "90 percent of players by try N" number written next to it.
- [ ] Stacking model (additive, independent, relative) is chosen per stat and stated in the UI.
- [ ] Builds with breakpoints are compared by simulation, not by expected value.
- [ ] Streak-sensitive mechanics use PRD or shuffle bags; celebrated rare drops do not.
- [ ] Rare drop rates are verified with a large simulated sample and a Wilson interval.
- [ ] Analytics reports medians and cohorts; experiments have a precomputed sample size.
- [ ] All rolls that matter happen once, on the server, and are stored.

## See also

[[Game Math Start Here]] · [[RNG Drops and Luck Systems]] · [[Rarity Ladders and Drop Pacing Math]] · [[RNG Drops and Luck Systems]] · [[Status Effects Buffs and Stacking Rules]] · [[Balancing with Spreadsheets and Data]] · [[Economy Inflation Sinks and Faucets Math]] · [[Analytics and Funnels]] · [[A-B Testing and Experiments on Roblox]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Genre Playbook - RNG and Collection Games]] · [[Simulator and RNG Genre Teardown]]

## Connected notes
<!-- auto-links:start -->
[[Variance]] · Pity Timer · Expected Value · Drop Tables Rarity and Pity Systems · Economy Design Start Here · Economy Telemetry and Balancing Live
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Drop Tables Rarity and Pity Systems]] · [[Expected Value]] · [[Pity Timer]] · [[Economy Telemetry and Balancing Live]] · [[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]] · [[Simulating an Economy Before Launch]]
<!-- related:end -->
