---
tags: [game-design, rng, rarity, drops, pacing, math, balancing, collection, luck]
---
# Rarity Ladders and Drop Pacing Math

A rarity ladder is a schedule disguised as a lottery. When you write "Mythic: 1 in 3,125" you are really deciding *how many hours into the game the typical player first sees a Mythic, how long the unlucky tenth waits, and how many Mythics the veteran owns by week three*. This note gives the maths to set those numbers on purpose: geometric ladders, the distribution of waiting times, how roll speed and luck change pacing over a player's life, collection completion, variance in drop-based crafting, and how luck inflation quietly collapses a ladder. Everything is ordinary probability; the value is in applying it before launch instead of discovering it in reviews.

The roll implementations (weighted versus rarest-first, pity code, disclosure) are in [[RNG Drops and Luck Systems]] and [[Genre Playbook - RNG and Collection Games]]. This note assumes them and goes into pacing.

Related: [[Progression and Pacing Design]], [[Balancing with Spreadsheets and Data]], [[Economies and Currencies]], [[Simulator and RNG Genre Teardown]], [[Ethical Design and Player Trust]].

Source labels: **Docs** (Roblox docs as of October 2026), **Measured** (the reference project: a long rarity ladder with luck sources, speed upgrades and progress caps), **Rule of thumb**, and **Maths** (derivable; you can check it).

---

## 1. The three numbers that describe any chase

For an outcome with probability `p` per attempt (write `N = 1/p`, the "1 in N"), the number of attempts until the first success follows a geometric distribution (**Maths**):

```
P(not yet after n attempts) = (1 - p)^n  ≈  e^(-n / N)   for small p
```

From that, three numbers matter more than the average:

| Quantity | Attempts | Meaning for design |
|---|---|---|
| Median | 0.69 N | Half of players are luckier than this; the "typical" experience |
| Mean | N | What spreadsheets usually show; already pessimistic for half the players |
| 90th percentile | 2.30 N | The unlucky tenth: your support tickets |
| 99th percentile | 4.61 N | The 1% who write the angry review |

Two consequences people miss:
- **The mean is not the typical player.** At "1 in 1,000", the median player has it at 693 rolls. Designing around 1,000 slightly over-estimates the typical wait and badly under-estimates the tail.
- **The tail is fixed by the shape, not by your odds.** Whatever `N` you pick, the p99 player waits 6.6 times longer than the median. Changing odds moves everyone; only pity, tokens or guarantees change the shape ([[RNG Drops and Luck Systems]] section 4).

### Hard pity changes the mean too
With a guarantee at `K` attempts, the expected attempts become `N * (1 - (1 - p)^K)` (**Maths**). Example: `N = 625`, `K = 1,000`: `(1 - 1/625)^1000 ≈ e^-1.6 ≈ 0.20`, so the expected wait drops from 625 to about **499**, and nobody waits more than 1,000. If the item is a paid random item, disclosed odds must reflect pity (Docs list pity systems as probability modifiers; see [[Genre Playbook - RNG and Collection Games]] section 9).

---

## 2. Geometric ladders

Most ladders are geometric: each tier is `r` times rarer than the one below. With nine tiers and `r = 5`:

| Tier | 1 in N (single tier) | Tier-or-better probability |
|---|---|---|
| Common | fallback | 100% |
| Uncommon | 5 | 25% |
| Rare | 25 | 5% |
| Epic | 125 | 1% |
| Legendary | 625 | 0.2% |
| Mythic | 3,125 | 0.04% |
| Celestial | 15,625 | 0.008% |
| Divine | 78,125 | 0.0016% |
| Eternal | 390,625 | 0.00032% |

**Tier or better** is the sum of a geometric series: `p_T * r / (r - 1)` (**Maths**). With `r = 5` it is 1.25 times the single-tier chance. Players think in "or better" ("when do I get *at least* a Legendary?"), so pace on that column.

### Choosing the ratio
| Ratio r | Feel | Tiers to span 1 in 1M |
|---|---|---|
| 2 to 3 | Frequent upgrades, flat prestige | 13 to 20 |
| 5 | Classic RNG game rhythm | about 9 |
| 10 | Each tier is an event | 6 |
| Mixed (small at bottom, large at top) | Fast early progress, long chase at the top | Varies |

**Mixed ratios** are usually right: an early ladder with `r` of 3 to 5 so new players climb several tiers in the first session, then `r` of 5 to 10 at the top where the chase is the product. The reference project's ladder ran from Common through several tiers above Legendary, with the top tiers in the millions at base luck (**Measured**: about 1 in 3.8 million for the top tiers once progress caps were turned off).

---

## 3. From odds to hours: pacing over a player's life

Players do not roll at a constant rate with constant luck. Roll speed upgrades, passes, potions and luck sources all grow with play time. The clean way to model this (**Maths**) is to accumulate **luck-weighted rolls**:

```
W(h) = sum over play phases of (rolls per minute * minutes in phase * luck in phase)
P(at least one of tier T by hour h)  ≈  1 - e^(-W(h) / N_T)
```

This assumes luck divides `N` (the common "1 in N / luck" definition) and that `N_T / luck` stays well above 1. Above that point the approximation breaks (section 5).

### Worked example
Assume three phases (illustrative numbers, not measured):

| Phase | Hours | Rolls / min | Luck | Luck-weighted rolls added | W at end |
|---|---|---|---|---|---|
| New | 0 to 1 | 20 | 1 | 1,200 | 1,200 |
| Settling in | 1 to 5 | 30 | 2 | 14,400 | 15,600 |
| Committed | 5 to 20 | 40 | 4 | 144,000 | 159,600 |

Chance of having at least one item of each tier (single-tier odds from section 2, so slightly conservative):

| Tier (1 in N) | By hour 1 | By hour 5 | By hour 20 |
|---|---|---|---|
| Legendary (625) | 85% | ~100% | ~100% |
| Mythic (3,125) | 32% | 99% | ~100% |
| Celestial (15,625) | 7% | 63% | ~100% |
| Divine (78,125) | 1.5% | 18% | 87% |
| Eternal (390,625) | 0.3% | 4% | 34% |

How to read it as a designer:
- **First session (hour 1):** almost everyone sees a Legendary and a third see a Mythic. That is a strong first session. If your FTUE target is "everyone sees a big moment", this ladder delivers it without a scripted guarantee ([[First-Time User Experience and Onboarding]]).
- **Hour 5:** Celestial is a coin flip. This is where most players decide whether the game has a long loop. The next visible goal (Divine at 18%) must be desirable and shown.
- **Hour 20:** a third have the top tier. That may be too many if the top tier is meant to be status. Either add a tier, slow the late phase, or reduce late luck.

Rule of thumb: the **next tier** a player has not reached should have a median wait of one to two sessions at their current rate. Further than that and the ladder above them stops feeling reachable; closer than that and the ladder runs out.

**Measured** rates that feed this model in the reference project: a base manual reveal of 3.2 s (about 19 rolls per minute, raised from 2.4 s because rolls felt too fast), auto-roll at 2.56 s, speed upgrades and a Fast Roll pass with a floor of 0.38x the base time, a Double Roll pass (two results per roll), and a 20% chance per press of a golden roll with 2x luck. The golden roll alone raises average luck by 20% (`0.8 * 1 + 0.2 * 2 = 1.2`). The speed floor means roll rate can rise about 2.6x from upgrades alone; with Double Roll, about 5x. Every one of those is a multiplier on `W`.

---

## 4. A pacing calculator in Luau

Put this in a ModuleScript used by both a Studio command and your test suite. It computes the table above from config, and a Monte Carlo check confirms the closed form against the real roll function.

```lua
--!strict
-- Pacing maths for a rarity ladder. Pure functions: no services, safe to unit test.
export type Phase = { minutes: number, rollsPerMinute: number, luck: number }

local Pacing = {}

-- Luck-weighted rolls accumulated at the end of each phase.
function Pacing.weightedRolls(phases: { Phase }): { number }
	local out = {}
	local w = 0
	for i, ph in phases do
		w += ph.minutes * ph.rollsPerMinute * ph.luck
		out[i] = w
	end
	return out
end

-- Probability of at least one success by weighted-roll total W for a "1 in N" outcome.
function Pacing.atLeastOne(w: number, oneIn: number): number
	return 1 - math.exp(-w / oneIn)
end

-- Attempts at a given percentile for a "1 in N" chance (e.g. q = 0.9 for p90).
function Pacing.percentile(oneIn: number, q: number): number
	local p = 1 / oneIn
	return math.log(1 - q) / math.log(1 - p)
end

-- Monte Carlo: attempts to first success with optional hard pity, `trials` samples.
-- Returns sorted samples so callers can read any percentile.
function Pacing.simulate(oneIn: number, trials: number, pity: number?, seed: number?): { number }
	local rng = Random.new(seed or 1)
	local p = 1 / oneIn
	local samples = table.create(trials)
	for i = 1, trials do
		local n = 0
		repeat
			n += 1
		until rng:NextNumber() < p or (pity ~= nil and n >= pity)
		samples[i] = n
	end
	table.sort(samples)
	return samples
end

return Pacing
```

Example use from the command bar:

```lua
local Pacing = require(game.ReplicatedStorage.Pacing)
local s = Pacing.simulate(625, 20000, nil, 7)
print("median", s[10000], "p90", s[18000], "p99", s[19800]) -- expect about 433 / 1438 / 2876
print("closed form p90", Pacing.percentile(625, 0.9))
```

The simulation loop costs about `trials * N` random draws; keep `N * trials` under a few tens of millions in Studio or it will stall the command bar. For very rare tiers, trust the closed form and simulate a scaled-down version.

---

## 5. Luck inflation: how ladders collapse

With "luck divides N", a luck of `L` moves every outcome down by `log_r(L)` tiers (**Maths**). On a ratio-5 ladder:

| Total luck | Tiers shifted | What it means |
|---|---|---|
| 2x | 0.43 | Noticeable but mild |
| 5x | 1 | Mythic is now as common as Legendary was |
| 25x | 2 | Celestial feels like Legendary did |
| 132x | 3.03 | Three tiers of the ladder have lost their meaning |

The 132x row is not hypothetical: multiplying five plausible sources (1.1 x 2 x 3 x 2 x 10) gives it, and the reference project had to cut a temporary charm from 20x to 100x down to 3x to 10x for exactly this reason (**Measured**, see [[RNG Drops and Luck Systems]] section 3).

Two further breakages at high luck:
- **Saturation.** In a rarest-first roll, an item's chance is `min(1, L / N)`. Once `L >= N` for the rarest item in range, every roll returns that item. Check the maximum stackable luck against the rarest item in every cap band.
- **The bottom of the ladder empties.** High luck pushes probability mass out of Commons. If Commons are crafting fodder, high-luck players run short of materials while drowning in mid-tier items. Watch the material economy, not just the top tier ([[Economies and Currencies]]).

Mitigations, in order of preference:
1. **Additive stacking within categories** and a **hard cap** on total luck per progress band.
2. **Luck that only affects some tiers** (for example only Rare and above), stated openly.
3. **Diminishing returns** on luck: effective luck `= 1 + k * ln(L)` above a threshold. Honest only if the displayed odds use the effective value.
4. **Adding tiers** at the top. This works but is the expensive fix: every new tier needs items that look better than the last ([[Genre Playbook - RNG and Collection Games]] section 6).

### Progress caps interact with all of this
A cap on the rollable tier (**Measured**: the reference project capped by the furthest world reached, Legendary in the first, then Mythic, Celestial and Eternal) truncates the ladder per band, so luck within a band piles up at the cap tier. That can be good (players hit the cap and are pushed to progress) or bad (when the next world was not ready, players sat at the cap with nothing to chase; the caps were then turned off by a flag). A cap needs content waiting above it.

---

## 6. Collection completion

Once players have one of each tier, the next chase is **completing** tiers: owning every item. With `n` equally likely items in a tier, the expected number of draws from that tier to own all of them is `n * H_n`, where `H_n = 1 + 1/2 + ... + 1/n` (the coupon collector problem, **Maths**).

| Items in tier | Expected draws from that tier | Expected duplicates on completion |
|---|---|---|
| 5 | 11.4 | 6.4 |
| 10 | 29.3 | 19.3 |
| 20 | 72.0 | 52.0 |
| 40 | 171.1 | 131.1 |

Multiply by the tier's `N` to get total rolls. Completing a 10-item Legendary tier at 1 in 625 takes about 29.3 x 625 ≈ **18,300 rolls**, roughly 15 hours at 20 rolls per minute with no luck.

What the table teaches:
- **The last item dominates.** For a 10-item tier, the last three items take about 18 of the expected 29 draws (10/3 + 10/2 + 10/1), nearly two thirds of the effort. Completion rewards that pay only at 100% concentrate frustration; reward at 50%, 75% and 100%.
- **Duplicates are the majority output.** At 20 items you get about 2.6 duplicates per new item. Duplicates must convert into something (fusion, salvage, tokens): this is the strongest argument for duplicate systems, and the numbers above are how much material they will mint ([[Economies and Currencies]]).
- **Unequal weights within a tier** make completion much slower: the expected time is dominated by the rarest item in the tier. If one Legendary is ten times rarer than the others, completion takes roughly as long as getting that one item, plus the rest.
- **Duplicate protection** (removing owned items from the pool) turns `n * H_n` into exactly `n` draws. Strong for small sets, and it changes displayed odds per player, which must then update for paid items (Docs: "if a player can only get one copy of an outcome, update their remaining odds").

---

## 7. Drop-based crafting: variance shrinks with counts

Enemy drops usually feed recipes: "20 Ember Cores to forge the weapon". The number of kills to collect `k` items with drop chance `p` per kill follows a negative binomial distribution (**Maths**):

```
mean kills = k / p
standard deviation = sqrt(k * (1 - p)) / p
relative spread (sd / mean) ≈ 1 / sqrt(k)   for small p
```

| Needed (k) | Relative spread | Feel |
|---|---|---|
| 1 | about 100% | Pure luck; some players get it first kill, some never |
| 5 | about 45% | Still swingy |
| 20 | about 22% | Predictable grind with some luck |
| 100 | about 10% | Effectively deterministic |

Example: `k = 20`, `p = 2%`: mean 1,000 kills, standard deviation about 221 kills. At 6 kills per minute, a typical player needs 2.8 hours, and most land between 2.2 and 3.4.

This is why **fragments** feel fair where single rare drops do not: splitting one 1-in-1,000 drop into twenty 1-in-50 fragments keeps the mean (1,000 kills) and cuts the spread from about 100% to about 22%. **Measured:** the reference project gave mini-bosses fragment chances toward zone-themed weapons plus a guaranteed material bundle, and bosses one material always and a rarer one at 25% (35% for a later boss). The guaranteed part is the floor; the chance part is the spike.

Drops per hour as a sanity check: `60 * kills per minute * p * drop multiplier`. **Measured** multipliers worth including: rare spawns 3x drops, elites 2.5x drop multiplier. Players farming elites move through a recipe more than twice as fast, which is intended, but it means your recipe pacing must be computed on the farming path players will actually use, not on average kills.

---

## 8. Power per tier: odds are not stats

A tier being 5x rarer does not mean it should be 5x stronger. If power scaled with odds, nine tiers would span a factor of 390,625 in power, and no enemy could be balanced for both ends.

| Power ratio per tier | Common to top over 9 tiers | Result |
|---|---|---|
| 1.2x | 4.3x | Rarity is mostly status; content balances easily |
| 1.4x | 14.8x | Clear upgrades; still tunable with zone scaling |
| 2x | 256x | Each tier invalidates the last; content must scale exponentially |

Rule of thumb: 1.25x to 1.5x per tier, plus within-tier variation from a fitted curve so rarer items within a tier are slightly better ([[Balancing with Spreadsheets and Data]]). Make the top tiers special through **presentation and mechanics** (animated, unique abilities, visible auras) rather than raw numbers. **Measured:** the reference project required every Legendary-or-higher item to be animated, and gave each rolled weapon its own ability kit, so rarity felt different, not just bigger.

---

## 9. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Pacing on the mean | Half the playerbase feels the game is stingier than the sheet | Pace on the median and the p90 |
| Ignoring the tail | 1% of players wait 4.6x the mean | Pity, tokens or fragments |
| Constant-rate pacing | Late game far faster than intended | Model luck-weighted rolls per phase |
| Multiplicative luck with no cap | Three or more tiers collapse; saturation at the cap | Additive categories, caps per band |
| Completion reward only at 100% | The last item dominates; frustration | Rewards at 50, 75 and 100% |
| No duplicate sink | Inventory floods; duplicates feel like losses | Fusion, salvage, tokens, sized from the coupon table |
| Single rare drops for recipes | Some players never see it | Fragments: same mean, a fifth of the spread |
| Power scales with rarity | Content cannot be balanced across tiers | 1.25x to 1.5x per tier; mechanics and looks for the rest |
| Caps without content above | Players stall at the cap | Content first, or lift caps |

## Checklist
- [ ] Ladder ratios chosen deliberately (smaller at the bottom, larger at the top).
- [ ] Median, p90 and p99 waits computed for every tier, in hours, per play phase.
- [ ] Next unreached tier has a median wait of one to two sessions at each stage.
- [ ] Maximum stackable luck checked against every tier and cap band; no saturation.
- [ ] Completion rewards staged; duplicate output sized and given a sink.
- [ ] Recipes use enough fragments that the spread is predictable.
- [ ] Power per tier capped; top tiers distinguished by mechanics and presentation.
- [ ] Closed-form numbers confirmed by Monte Carlo against the real roll function.

## See also
[[RNG Drops and Luck Systems]] · [[Genre Playbook - RNG and Collection Games]] · [[Simulator and RNG Genre Teardown]] · [[Progression and Pacing Design]] · [[Balancing with Spreadsheets and Data]] · [[Economies and Currencies]] · [[Progression Levels and Unlocks]] · [[Ethical Design and Player Trust]] · [[Roblox Policies Ratings and Compliance]]

## Connected notes
<!-- auto-links:start -->
[[Drop Tables Rarity and Pity Systems]] · [[Pity Timer]] · [[Expected Value]] · [[Probability and Statistics for Designers]] · [[Variance]] · [[Paid Random Items and Odds Disclosure in Practice]]
<!-- auto-links:end -->
