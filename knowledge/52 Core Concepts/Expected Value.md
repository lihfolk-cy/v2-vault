---
tags: [core-concept, math, economy, rng, balancing]
---
# Expected Value

**Expected value (EV)** is the average outcome of a random event over many repetitions: each outcome's value multiplied by its probability, summed. A chest with a 90 percent chance of 10 coins and a 10 percent chance of 200 coins has an EV of 0.9 x 10 + 0.1 x 200 = 29 coins.

## Why it matters on Roblox

Almost every reward on Roblox is random: drops, eggs, crates, spins, fishing, crits. EV is how a designer compares them on one scale. It answers "is this egg worth its price?", "how fast does a player earn per hour?" and "did the luck boost actually double anything?". Without it, balancing random systems is guesswork.

## The nuance most people miss

1. **EV is what the economy feels; variance is what the player feels.** The economy sees thousands of rolls and lands near EV. One player sees twenty and may be far from it. See [[Variance]].
2. **EV of what?** "Value" must be one unit: coins, power, or time saved. Converting rare items to a coin value is a design decision, not a fact; players may value a cosmetic far above its sell price.
3. **Luck boosts rarely double EV.** A "2x luck" that doubles the chance of the top tier only raises EV by that tier's share of the total. Compute it, and describe boosts honestly.
4. **Per-time EV beats per-roll EV.** A roll worth 30 coins that takes 2 seconds earns more than one worth 100 that takes 10. Compare rewards per minute.
5. **Paid EV should not be the selling point.** If a paid crate's EV in currency exceeds its price, players will treat it as an investment; if it is far below, trust suffers. Many teams sell certainty (a known item) alongside chance.
6. **Conditional EV matters for pity.** With a pity timer, EV depends on the player's current counter.

## Tiny example

```lua
local Chest = {
	{ value = 10,  weight = 90 },
	{ value = 200, weight = 9 },
	{ value = 2000, weight = 1 },
}
local function expectedValue(t)
	local total, ev = 0, 0
	for _, e in t do total += e.weight end
	for _, e in t do ev += e.value * e.weight / total end
	return ev -- 9 + 18 + 20 = 47
end
```

Note how the 1 percent jackpot contributes more EV than the 90 percent common.

## Where this shows up

- [[Probability and Statistics for Designers]]: EV and its relatives.
- [[Rarity Ladders and Drop Pacing Math]]: EV across a rarity ladder.
- [[Drop Tables Rarity and Pity Systems]]: weighted tables.
- [[Balancing with Spreadsheets and Data]]: EV in a spreadsheet.
- [[Economy Inflation Sinks and Faucets Math]]: EV as faucet size.
- [[Paid Random Items and Odds Disclosure in Practice]]: paid EV and trust.
- [[RNG Drops and Luck Systems]]: luck multipliers.
- [[Simulating an Economy Before Launch]]: EV under simulation.
- [[Procedural Loot and Item Generation]]: EV of generated stats.
- [[Robux Price Points and Offer Design]]: value per Robux.
- [[Big Numbers Precision and Formatting]]: EV at huge values.

Related concepts: [[Variance]], [[Pity Timer]], [[Faucets and Sinks]], [[Power Curve]].

## Connected notes
<!-- auto-links:start -->
[[Economy Design Start Here]] · [[Genre Playbook - RNG and Collection Games]] · [[Core Concepts Start Here]] · [[Roblox Policies Ratings and Compliance]] · [[Pet Hatching and Following End to End]] · [[Genre Playbook - Simulators]]
<!-- auto-links:end -->
