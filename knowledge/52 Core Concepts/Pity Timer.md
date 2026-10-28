---
tags: [core-concept, economy, rng, monetization, game-design]
---
# Pity Timer

A **pity timer** (or pity system) guarantees a rare outcome after a set number of failures: "a legendary within 90 rolls", or a chance that rises with each miss until it hits. It caps the worst-case bad luck without changing the average much.

## Why it matters on Roblox

Collection and RNG games live on rolls, eggs and drops. Pure randomness produces players who go hundreds of rolls without a rare item; they do not experience "unlucky", they experience "this game is rigged", and they leave or complain publicly. Pity turns that tail into a promise. For paid random items it also matters for trust: Roblox requires odds to be disclosed before purchase (Roblox docs, paid random items policy, as of October 2026), and a pity rule should be part of what you disclose.

## The nuance most people miss

1. **Pity changes the real odds.** With a hard guarantee at 90 and a base 1 percent chance, the effective rate is noticeably higher than 1 percent. If you disclose "1%", consider stating the pity rule alongside it so the disclosure stays honest.
2. **Hard pity versus soft pity.** Hard pity is a guarantee at roll N. Soft pity raises the chance gradually after some point. Soft pity hides the cliff and feels more natural; hard pity is easier to explain and to trust.
3. **The counter must be saved.** A pity counter held only in server memory resets when the player rejoins, which players notice and exploit (rejoining to "reset luck" if it ever helps them) or resent (losing progress toward pity).
4. **Decide what resets the counter.** Usually any item at or above the pity tier. Be clear whether a luck boost or a different egg shares the same counter.
5. **Pity is per tier.** A guarantee for "epic or better" every 10 and "legendary" every 90 needs two counters.
6. **Pity does not fix a bad ladder.** If the rare item is 1 in 10,000, pity at 10,000 helps nobody. Pity works when the tail is long but the average is reasonable.

## Tiny example

```lua
local BASE, PITY = 0.01, 90
local function rollLegendary(profile, rng: Random): boolean
	profile.PityCount += 1
	if profile.PityCount >= PITY or rng:NextNumber() < BASE then
		profile.PityCount = 0
		return true
	end
	return false
end
```

## Where this shows up

- [[Drop Tables Rarity and Pity Systems]]: the deep dive.
- [[Rarity Ladders and Drop Pacing Math]]: choosing the ladder pity sits on.
- [[RNG Drops and Luck Systems]]: luck boosts and their interaction with pity.
- [[Paid Random Items and Odds Disclosure in Practice]]: disclosure rules.
- [[Genre Playbook - RNG and Collection Games]]: genre expectations.
- [[Pet Hatching and Following End to End]]: a worked egg system.
- [[Probability and Statistics for Designers]]: the maths of streaks.
- [[Ethical Design and Player Trust]]: why caps on bad luck build trust.
- [[Procedural Loot and Item Generation]]: pity on generated loot.
- [[Skill - Roblox Monetization Compliance]]: compliance review for paid rolls.

Related concepts: [[Expected Value]], [[Variance]], [[Faucets and Sinks]].

## Connected notes
<!-- auto-links:start -->
[[Economy Design Start Here]] · [[Balancing with Spreadsheets and Data]] · [[Roblox Policies Ratings and Compliance]] · [[Core Concepts Start Here]] · [[Genre Playbook - Simulators]] · [[Simulator and RNG Genre Teardown]]
<!-- auto-links:end -->
