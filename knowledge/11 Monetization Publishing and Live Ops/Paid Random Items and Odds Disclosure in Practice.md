---
tags: [monetization, policy, paid-random-items, odds, rng, compliance, luau]
---
# Paid Random Items and Odds Disclosure in Practice

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Tier odds shown instead of final outcomes -> Flatten
> - Avoid: Display table separate from roll table -> One source, roll from `Flatten`
> - Avoid: Uncapped odds shown in a capped area -> Pass the cap; show 0%
> - Every random system audited for direct, indirect and modifier money paths.
> - Odds disclosed on every random system; restricted behaviour decided per system.
> - Final-outcome odds flattened from the same tables the server rolls.
>
> Read more (19 KB note): ## 2. Audit first: draw the money paths · ## 3. One source of truth: flatten what the server rolls · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Roblox Policies Ratings and Compliance]] states the rules: what counts as a paid random item, the disclosure format, the `PolicyService` checks. This note is about implementing them in a real RNG game, where the hard parts are not the rules but the maths around them: tiered rolls whose final odds must be flattened, luck boosts that change odds live, pity counters, once-per-player outcomes, multi-roll packs, rarity caps, and the compliant alternatives for restricted players. It ends with a statistical test that proves your displayed odds match your server rolls.

Policy facts below come from the Creator Hub "Paid random items" page (Roblox docs, as of October 2026). This is a developer guide, not legal advice.

---

## 1. The rules you are implementing, in one paragraph

A paid random item is a random outcome bought directly or indirectly with Robux, including with in-game currency that can be bought with Robux. Covered types include capsules (wheels, eggs, chests), enhancements (random-success upgrades), combinations (fusing for a chance at something better) and probability modifiers (luck boosts, pity systems, enhanced drop rates). You must show all possible outcomes and their actual numerical odds before purchase, as percentages that sum to exactly 100%; long decimals may be rounded to four or more places below the first non-zero digit with a rounding disclaimer; a long list may sit in a pop-up opened by a control with a descriptive word (a bare (i) icon is not enough). Once-per-user outcomes require updated remaining odds for that user. Paid modifiers must explain their effect numerically before purchase, and while active the displayed odds must update to the user's true odds. When `ArePaidRandomItemsRestricted` is true for a player, you must give them a compliant alternative or keep them away from the paid random item. Random rewards earned without Robux or paid currency are exempt (Roblox docs, as of October 2026).

The rest of this note is how to do all of that without maintaining two sets of numbers.

---

## 2. Audit first: draw the money paths

Before any UI work, list every random system and trace whether Robux can reach it.

| System | Paid path? | Covered? |
|---|---|---|
| Free roll button, no paid boosts active | No | Exempt |
| Free roll while a paid luck boost is active | Yes, through the modifier | Disclosure of the modified odds required |
| Egg priced in gems, gems sold for Robux | Yes, indirect | Covered, even for players who only ever earned gems |
| Egg priced in soft cash, cash never sold | No | Exempt, unless a paid multiplier feeds it (check below) |
| "Next roll Legendary or better" product (measured in the reference project, 499 Robux) | Direct | Covered |
| Craft: 5 items into 1 random next-rarity item (measured in the reference project) | Only if inputs or the action involve paid currency or Robux | Check per input |
| Daily free wheel | No | Exempt |
| Daily wheel with a paid extra spin | Yes | Covered |
| Server-wide luck bought by another player | Yes, for everyone in the server | Their displayed odds must update too |

Two cases people miss:

- **Indirect through modifiers.** A completely free roll becomes a roll with paid-modified odds the moment a paid boost is active, including a server luck boost someone else bought. The display must show the true odds for that player, right now.
- **Grey zones.** Whether a cash-priced egg is covered when a Robux pass doubles cash income is not addressed by the docs page (unverified). The conservative reading is that a paid multiplier on the currency makes the currency partly paid. Disclosing odds anyway costs you nothing; the decision that matters is what restricted players can do.

The simplest compliance posture for an RNG game: **disclose odds on every random system, paid or not.** Then the only per-system decision is the restricted-player behaviour.

---

## 3. One source of truth: flatten what the server rolls

Most RNG games roll in stages: first a rarity tier, then an item within the tier, sometimes then a variant (shiny, mutation). Players do not buy tiers; they get final outcomes. The rule is about **final outcomes**, so the display must show the product of every stage, and the sum over all final outcomes must be 100%.

```lua
--!strict
-- ReplicatedStorage/Odds/Flatten (ModuleScript)
-- Tier weights -> item weights within tier -> final probability per item.
export type Tier = { name: string, weight: number, items: { { id: string, weight: number } } }
export type Final = { id: string, tier: string, p: number }

local Flatten = {}

-- luck: function that returns the adjusted tier weight (must match the server's roll exactly)
-- capRank: tiers with index > capRank are unreachable here (probability 0)
function Flatten.Compute(tiers: { Tier }, luck: ((Tier, number) -> number)?, capRank: number?): { Final }
	local tierW = table.create(#tiers, 0)
	local total = 0
	for i, t in tiers do
		local w = if capRank and i > capRank then 0 else (if luck then luck(t, i) else t.weight)
		tierW[i] = w
		total += w
	end
	assert(total > 0, "no reachable tier")
	local out: { Final } = {}
	for i, t in tiers do
		local pTier = tierW[i] / total
		local itemTotal = 0
		for _, it in t.items do
			itemTotal += it.weight
		end
		for _, it in t.items do
			local p = if itemTotal > 0 then pTier * it.weight / itemTotal else 0
			table.insert(out, { id = it.id, tier = t.name, p = p })
		end
	end
	return out
end

return Flatten
```

The server's roll must use the **same** `tiers`, the **same** `luck` function and the **same** cap. The cleanest way is to make the roll call `Flatten.Compute` and pick from the flattened list, so display and roll cannot diverge:

```lua
--!strict
local function pick(finals: { Final }, rng: Random): string
	local r = rng:NextNumber()
	local acc = 0
	for _, f in finals do
		acc += f.p
		if r < acc then
			return f.id
		end
	end
	-- Floating point tail (acc ended a hair below 1): return the last REACHABLE outcome.
	for i = #finals, 1, -1 do
		if finals[i].p > 0 then
			return finals[i].id
		end
	end
	error("no reachable outcome")
end
```

The tail loop matters: the sum of floating point probabilities can end a hair below 1, and if the last entry is an unreachable capped tier, a naive `return finals[#finals].id` would hand out an impossible item.

**Rarity caps.** The reference project limited the maximum rarity per world ("unlocks in realm II"), and its displays marked those tiers as unreachable (measured). The policy consequence is direct: where an outcome is impossible, its displayed odds are 0%, and the other odds rise to sum to 100%. A display that shows the uncapped table in a capped area is wrong in both directions.

---

## 4. Luck and other modifiers, live

A luck multiplier is usually applied to rare tier weights and then renormalised. The exact formula is yours ([[RNG Drops and Luck Systems]]); the requirement is that the display uses it.

**Before purchase**, a modifier product must state its effect numerically. Good copy (rule of thumb): the multiplier, the duration, the scope, and a concrete before and after for the tier players care about:

> x2 Luck for 15 minutes, everyone in this server. Mythic: 0.0010% now, 0.0020% with this boost.

Compute the example from the real tables: call `Flatten.Compute` once with the player's current luck and once with current luck times the boost, after applying your luck cap. If the player is already at the cap, the honest preview says the boost does nothing for them. Do not sell it to them silently; show "Your luck is already at the maximum" and disable the button.

**While active**, every odds display (roll button tooltip, index cards, egg pop-ups) must show the modified odds. Implementation pattern: the server publishes the player's effective luck as an attribute (`EffectiveLuck`) whenever any modifier starts or ends; every odds UI listens to that attribute and recomputes. Measured in the reference project: index cards, the fragment list and the backpack odds tooltip all showed the true per-roll chance at the player's current luck, including temporary dice items.

**Stacking.** If luck sources multiply, the displayed value must use the same stacking rule and the same cap as the roll. One function computes effective luck; both the server roll and the attribute come from it.

---

## 5. Pity: how to disclose a moving target

Pity is listed by the docs as a probability modifier. Two common forms:

- **Hard pity:** after `K` rolls without a rare, the next roll is guaranteed rare.
- **Soft pity:** after a threshold, the rare chance rises each roll.

Either way, the true odds of the next roll depend on the player's counter. Disclose three things:

1. **The odds of the next roll** for this player, using the counter (so on the guaranteed roll, the rare tier shows 100% for its outcomes, distributed by item weight).
2. **The rule** in words and numbers ("Guaranteed Legendary at 90 rolls without one; you are at 63").
3. Optionally, **the effective rate** over the long run, which players find much easier to compare.

For hard pity with base chance `p` and guarantee at `K`:

```
expected rolls per rare   E = (1 - (1 - p)^K) / p
effective rate            = 1 / E = p / (1 - (1 - p)^K)
```

**Worked example.** `p = 1%`, `K = 90`: `(1 - 0.99^90) ≈ 0.595`, so `E ≈ 59.5` rolls and the effective rate is about 1.68%. Without pity it is 100 rolls and 1%. Showing "base 1%, effective about 1.68% including the guarantee" is clear and true.

Pity counters must be saved in the profile and must not reset on rejoin; a pity that resets is not pity and the disclosure would be false ([[RNG Drops and Luck Systems]]).

---

## 6. Once-per-user outcomes

If an outcome can be obtained only once per user (a unique title, a one-time exclusive), the remaining odds must be updated for that user (Roblox docs). Implementation: remove owned unique outcomes before flattening, which renormalises everything else.

```lua
--!strict
local function withoutOwned(tiers: { Tier }, owned: { [string]: boolean }): { Tier }
	local out = table.create(#tiers)
	for _, t in tiers do
		local items = {}
		for _, it in t.items do
			if not owned[it.id] then
				table.insert(items, it)
			end
		end
		-- A tier with no items left must contribute weight 0, or its share would be lost.
		table.insert(out, { name = t.name, weight = if #items > 0 then t.weight else 0, items = items })
	end
	return out
end
```

The comment matters: if all unique items in a tier are owned and the tier keeps its weight, `Flatten.Compute` gives the tier probability mass with no items to receive it, and the flattened sum falls below 100%. Zero the tier so the rest renormalises. The server roll must apply the same filter, from the same profile, at roll time.

---

## 7. Multi-roll packs and guarantees

"10 rolls for 449" is ten paid random rolls. Disclose per-roll odds (the same table). If the pack adds a guarantee ("at least one Epic or better"), that is a modifier on the last roll when no Epic appeared in the first nine: show that rule numerically.

A useful number to show alongside, which players often misjudge:

```
chance of at least one hit in N rolls = 1 - (1 - p)^N
```

For `p = 0.5%` and `N = 10`: `1 - 0.995^10 ≈ 4.9%`. Showing this ("about 4.9% chance of at least one Mythic in this pack") is honest and prevents the "ten rolls at 0.5% means 5% guaranteed" misunderstanding. It is a supplement, not a replacement, for the per-outcome percentages.

Bundles that contain random items (a bundle with gems plus "3 mystery eggs") must disclose the eggs' odds on the bundle card before purchase.

---

## 8. Formatting edge cases

Percentages for rare outcomes get tiny: 1 in 5,000,000 is 0.00002%. The docs allow rounding to four or more decimal places below the first non-zero digit, plus a disclaimer that displayed values may not total 100% (Roblox docs). A formatter is in [[Roblox Policies Ratings and Compliance]]. Additional rules of thumb:

- **Never round a non-zero probability to 0%.** The rounding rule (counting from the first non-zero digit) prevents it; a naive `%.2f` does not.
- **"1 in N" is a supplement.** RNG games love "1 in 5,000,000"; show it if you like, but percentages are the required format.
- **Shared odds:** if many items share one probability, the docs allow "Odds for each item listed below: X%".
- **Label the control.** "Odds", "Details" or "Info" as text, visible before purchase, on every purchase surface: shop cards, contextual pop-ups, in-world egg prompts, and the confirmation dialog of a paid-currency spend.
- **Localise numbers carefully.** Some locales use a comma as the decimal separator; a formatter that inserts thousands separators can turn 0.0002 into something unreadable ([[Localization]]).

---

## 9. Restricted players: the alternatives in numbers

When `ArePaidRandomItemsRestricted` is true, the docs list six options: a free earnable path, a predetermined disclosed order, direct sale priced at expected value, removing or hiding the item, blocking with an error, or keeping the player out of areas with paid random items (Roblox docs, as of October 2026). Fetch the policy on the server, fail closed, and gate on the server ([[Roblox Policies Ratings and Compliance]]).

**Direct sale at expected value.** The docs' example: a 10 Robux lootbox with a 5% chance of a rare sword means the sword sells directly for 200 Robux. In general:

```
direct price of outcome i = price per roll / p_i
```

This produces absurd prices for genuinely rare outcomes. A 1 in 1,000,000 item from a 25 Robux roll is 25,000,000 Robux directly. That is not a real offer, so in practice:

| Outcome rarity | Practical alternative for restricted players |
|---|---|
| Common to rare (direct price under about 2,000 Robux) | Direct sale at expected value |
| Very rare | Free earnable path (milestones, quests), or hide |
| Cosmetic-only random items | Predetermined order (the docs' example: 5, then 10, then 20 gems) |
| Luck boosts | Block with a clear message; a modifier has no non-random equivalent |

**Test the restricted path.** Add a debug override that forces the restricted policy for a test account in Studio, and walk every purchase surface. The usual failure is a contextual pop-up (near-miss luck boost) that bypasses the shop's policy check because it calls the prompt remote directly. Gate in the prompt remote itself, not in the UI.

---

## 10. Prove the display matches the roll

The one test that matters: roll the real server function many times and compare frequencies to the displayed probabilities. A chi-square goodness-of-fit test is enough.

```lua
--!strict
-- Run in Studio (command bar or a TestEZ spec). Uses the real Flatten + pick.
local function chiSquare(finals: { Final }, n: number, seed: number): (number, number)
	local rng = Random.new(seed)
	local counts: { [string]: number } = {}
	for _ = 1, n do
		local id = pick(finals, rng)
		counts[id] = (counts[id] or 0) + 1
	end
	local chi, dof = 0, -1
	local pooledExp, pooledObs = 0, 0
	for _, f in finals do
		local expected = f.p * n
		if expected >= 5 then
			local d = (counts[f.id] or 0) - expected
			chi += d * d / expected
			dof += 1
		else
			-- pool rare outcomes so the test stays valid
			pooledExp += expected
			pooledObs += counts[f.id] or 0
		end
	end
	if pooledExp >= 5 then
		local d = pooledObs - pooledExp
		chi += d * d / pooledExp
		dof += 1
	end
	return chi, dof
end
-- Rule of thumb: chi / dof well above 2 with n = 1,000,000 means the roll and the display disagree.
```

Run it for every distinct table, with and without luck, with a capped realm, and with a pity counter near the guarantee. For the rarest outcomes, a million rolls will not produce enough hits; test those analytically by asserting that the roll code calls the same `Flatten` output, which is why section 3 matters.

Put it in CI ([[Testing Strategies and Frameworks]]). A config change that edits weights in one place but not another then fails a build instead of becoming a policy violation.

---

## 11. Operational habits

- **Change review.** Any edit to an odds table, luck formula or cap is reviewed as a policy change, not a balance tweak. Keep a changelog of odds changes with dates; it answers player disputes.
- **Announce odds changes.** Silently lowering the odds of a paid capsule is a trust failure even when the display is correct.
- **Questionnaire.** Adding the first paid random item to a game changes your Maturity & Compliance answers; resubmitting temporarily removes rewarded video ad eligibility while reviewed (Roblox docs, as of October 2026). Plan the timing.
- **Simulated gambling is a different thing.** Stake-and-multiply mechanics (coin flips, double or nothing) are not "random items with odds" and are not made acceptable by disclosure ([[Roblox Policies Ratings and Compliance]]).

---

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Tier odds shown instead of final outcomes | Sum of item odds is not 100% | Flatten |
| Display table separate from roll table | Chi-square test fails after a config edit | One source, roll from `Flatten` |
| Uncapped odds shown in a capped area | Players report "impossible" items listed | Pass the cap; show 0% |
| Boost preview ignores the luck cap | Capped players buy boosts that do nothing | Preview with cap; disable at max |
| Server luck from another player not shown | Displayed odds lower than true odds | Effective luck attribute for everyone |
| Pity not reflected in next-roll odds | Guarantee roll shows base odds | Counter-aware display |
| Owned uniques left in the table | Sum below 100% after a tier empties | Zero empty tiers |
| Odds button only in the shop | Contextual pop-ups lack disclosure | Every purchase surface |
| Restricted check in UI only | Exploit or pop-up bypass | Gate in the prompt remote |

## Checklist

- [ ] Every random system audited for direct, indirect and modifier money paths.
- [ ] Odds disclosed on every random system; restricted behaviour decided per system.
- [ ] Final-outcome odds flattened from the same tables the server rolls.
- [ ] Caps, luck, pity and owned uniques applied identically to display and roll.
- [ ] Modifier products show numeric before and after; disabled at the cap.
- [ ] Effective luck published live; all odds UIs recompute on change.
- [ ] Labelled odds control on every purchase surface, visible before purchase.
- [ ] Rounding rule and disclaimer implemented; no non-zero value shown as 0%.
- [ ] Restricted players get a tested alternative; gate lives in the server prompt path.
- [ ] Chi-square test in CI for every table and modifier state.
- [ ] Odds changes reviewed, logged and announced.

## See also
[[Roblox Policies Ratings and Compliance]] · [[RNG Drops and Luck Systems]] · [[Genre Playbook - RNG and Collection Games]] · [[Pricing and Store Design]] · [[Robux Price Points and Offer Design]] · [[Economy Inflation Sinks and Faucets Math]] · [[Developer Products and ProcessReceipt]] · [[Ethical Design and Player Trust]] · [[Testing Strategies and Frameworks]] · [[Localization]] · [[Trading Systems Without Duplication]]

## Connected notes
<!-- auto-links:start -->
[[Pity Timer]] · [[Skill - Roblox Monetization Compliance]] · [[Drop Tables Rarity and Pity Systems]] · [[Expected Value]] · [[Genre Playbook - Simulators]] · [[Rarity Ladders and Drop Pacing Math]]
<!-- auto-links:end -->
