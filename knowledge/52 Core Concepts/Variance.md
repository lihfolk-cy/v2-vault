---
tags: [core-concept, math, rng, game-design, analytics]
---
# Variance

<!-- tldr:start -->
> [!tldr] TL;DR
> - Players experience variance, not averages.
> - Streaks are more common than people think.
> - Variance shrinks with repetition. Over N independent rolls the average's standard deviation falls with the square root of N.
> - Variance is a tool for pacing. Low variance for the core income (players can plan), high variance for bonus moments (players...
>
> Read more (3 KB note): ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Variance** measures how spread out random outcomes are around their average. Its square root, the **standard deviation**, is in the same units as the outcome. Two drop tables can have the same [[Expected Value]] and wildly different variance: one pays 50 coins every time, the other pays 0 most of the time and 5,000 rarely.

## Why it matters on Roblox

Players experience variance, not averages. High variance creates excitement (the big drop, the clip-worthy moment) and frustration (the long dry streak). Low variance feels fair and dull. Choosing variance on purpose, per system, is a core design skill for RNG-heavy Roblox genres. Variance also matters for reading data: noisy metrics on small samples mislead.

## The nuance most people miss

1. **Streaks are more common than people think.** With a 1 percent chance per roll, about 37 percent of players will not hit in 100 rolls (0.99^100), and about 13 percent will not hit in 200. Plan for those players.
2. **Variance shrinks with repetition.** Over N independent rolls the average's standard deviation falls with the square root of N. That is why economies are predictable while individual players are not.
3. **Variance is a tool for pacing.** Low variance for the core income (players can plan), high variance for bonus moments (players can hope). Mixing both in one system confuses players.
4. **Social games amplify high variance.** A rare drop shown to the whole server is advertising; it is only good design if the rest of the server feels they have a chance too.
5. **Variance in metrics is a trap.** A conversion rate on 200 players can swing several points by chance. Before calling an A/B test, check whether the difference is bigger than the noise.
6. **Pity cuts the tail, not the variance in general.** A pity timer removes the worst streaks while keeping the excitement of early hits.

## Tiny example

| Table | Outcomes | EV | Feel |
|---|---|---|---|
| A | 50 coins always | 50 | Reliable, plannable |
| B | 0 (95%) or 1,000 (5%) | 50 | Exciting, streaky |

Same income per roll for the economy. Very different evenings for the player.

## Where this shows up

- [[Probability and Statistics for Designers]]: variance and sample size.
- [[Rarity Ladders and Drop Pacing Math]]: streaks on a ladder.
- [[Drop Tables Rarity and Pity Systems]]: cutting tails.
- [[A-B Testing and Experiments on Roblox]]: noise in experiments.
- [[Genre Playbook - RNG and Collection Games]]: variance as the genre's heart.
- [[Reward Moments and Celebrations]]: celebrating high-variance wins.
- [[Simulating an Economy Before Launch]]: seeing the spread, not only the mean.
- [[Procedural Loot and Item Generation]]: variance in rolled stats.
- [[Case Study - Steal a Brainrot]]: visible rare items in a social game.
- [[Seeds Determinism and Reproducible Worlds]]: reproducible randomness for testing.
- [[Economy Telemetry and Balancing Live]]: reading noisy live data.

Related concepts: [[Expected Value]], [[Pity Timer]], [[Retention Cohorts]].

## Connected notes
<!-- auto-links:start -->
[[Economy Design Start Here]] · [[Core Concepts Start Here]] · [[Deterministic Simulation]] · [[RNG Drops and Luck Systems]] · [[Balancing with Spreadsheets and Data]] · [[Procedural Generation Start Here]]
<!-- auto-links:end -->
