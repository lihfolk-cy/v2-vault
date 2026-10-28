---
cssclasses: [vault-hub]
tags: [index, start, economy, design, balancing]
---
# Economy Design Start Here

The vault already explains what faucets and sinks are ([[Economies and Currencies]]), the arithmetic of inflation and payer gaps ([[Economy Inflation Sinks and Faucets Math]]), how to make trades correct ([[Trading Systems Without Duplication]]), how economies get exploited ([[Economy Exploits - Dupes Races and Purchase Abuse]]) and the probability every designer needs ([[Probability and Statistics for Designers]]). This section is the layer between those notes and a shipped game: the structural decisions about currencies, curves, drop tables and markets, and the practice of measuring, simulating and changing an economy once players are in it.

Read the older notes first if the words faucet, sink, time to afford or effective rate are new. The notes here assume them.

## The notes

| Note | The question it answers |
|---|---|
| [[Currency Architecture - Soft Hard and Event Currencies]] | How many currencies, what each one is for, paid and free buckets, event currency lifecycles, conversion loops that print money |
| [[Pricing Curves and Upgrade Costs]] | Which curve for which upgrade track, payback periods, competing tracks, buy-max on the server, rounding without breaking the curve |
| [[Drop Tables Rarity and Pity Systems]] | Drop tables as data, expected drops through nested tables, alias sampling, exact effective rates for pity ramps, featured guarantees, duplicate protection |
| [[Player-Driven Trading Economies]] | What trading does to value, trade formats, manipulation-resistant prices, fees as sinks, item supply, real-money trading, a cross-server listing board |
| [[Economy Telemetry and Balancing Live]] | Metrics that catch problems, cohort segmentation, sharded aggregates, robust alerts, the balancing loop with configs and experiments |
| [[Simulating an Economy Before Launch]] | A runnable agent-based simulation in Python, what it reveals about walls and endgame sinks, calibration and CI |

## Suggested order

1. **Designing a new game:** currency architecture, then pricing curves, then drop tables. Run the simulation as soon as you have numbers for all three.
2. **Adding trading:** read [[Trading Systems Without Duplication]] for correctness, then [[Player-Driven Trading Economies]] for the market, then model item supply with [[Drop Tables Rarity and Pity Systems]].
3. **Running a live game:** telemetry first, then use the simulation to test each balance change before it reaches players.

## Ideas that run through every note

- **Price everything from one model.** Gates, upgrade tracks, rolls and rewards derive from income per minute at the point where they matter. A price set by hand drifts ([[Balancing with Spreadsheets and Data]]).
- **Every sink is connected to something.** A sink that removes coins may mint items; a conversion may form a loop; a luck event is a supply shock in a trading game.
- **Measure within cohorts.** Whole-population medians in a progression game measure who is playing, not how the economy is doing.
- **Paid value is never reduced.** Paid currency does not expire, purchases survive resets, and provenance is recorded at grant time ([[Economy Resets and Seasonal Wipes]], [[Paid Random Items and Odds Disclosure in Practice]]).
- **Simulate for comparisons, not predictions.** Same seeds, two configs, a difference you can explain.

## Sourcing

Platform facts (AnalyticsService economy events, ConfigService and experiments, MemoryStore limits, PolicyService and regional price levels) were checked against create.roblox.com and are labelled "Roblox docs (as of October 2026)". Production lessons from one live game are labelled "measured in the reference project". Everything else is labelled "rule of thumb" or, in the simulation note, "simulated". Luau code is strict and reviewed by reading, not run. The Python simulation was run, and its numbers are quoted from those runs.

## Related sections

- [[Game Math Start Here]] for curves, big numbers and probability.
- [[Live Ops Deep Dive Start Here]] for seasons, resets and limited-time offers.
- [[Anti-Exploit Start Here]] for the attacks economies attract.
- [[Monetization Overview]], [[Robux Price Points and Offer Design]] and [[Analytics and Funnels]] for the Robux side.
- [[Rarity Ladders and Drop Pacing Math]] and [[RNG Drops and Luck Systems]] for drop pacing basics.
- [[Genre Playbook - Simulators]] and [[Genre Playbook - RNG and Collection Games]] for the genres where economy design matters most.

## Connected notes
<!-- auto-links:start -->
[[Faucets and Sinks]] · [[Expected Value]] · [[Pity Timer]] · [[Variance]] · [[Progression Levels and Unlocks]] · [[Telemetry Events]]
<!-- auto-links:end -->
