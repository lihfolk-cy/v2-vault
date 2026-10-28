---
tags: [core-concept, progression, economy, balancing, math]
---
# Power Curve

<!-- tldr:start -->
> [!tldr] TL;DR
> - Roblox games, especially simulators, RPGs and tycoons, are built on visible numbers going up.
> - Time to next step is the real number. Cost divided by income gives seconds to the next upgrade.
> - Exponential income demands exponential costs.
> - Walls are a design choice. A deliberate steepening before a rebirth or a new zone tells the player "change strategy".
>
> Read more (4 KB note): ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

A **power curve** describes how a player's strength (damage, income, speed) grows as they progress, usually plotted against level, time played or currency spent. It is always paired with a **cost curve**: how much each next step costs. The relationship between the two decides pacing.

## Why it matters on Roblox

Roblox games, especially simulators, RPGs and tycoons, are built on visible numbers going up. If power grows faster than costs, players outgrow content and finish the game in a week. If costs grow much faster than power, progress stalls and players quit at the wall. The curves also decide what a purchase or a rebirth is worth.

## Common shapes

| Shape | Formula sketch | Feels like |
|---|---|---|
| Linear | `a * n` | Steady, quickly boring |
| Polynomial | `a * n^k` (k around 1.5 to 3) | Slowly steepening, the usual RPG choice |
| Exponential | `a * r^n` (r around 1.1 to 1.5) | Fast growth; needs prestige resets or huge-number formatting |

## The nuance most people miss

1. **Time to next step is the real number.** Cost divided by income gives seconds to the next upgrade. Plot that, not cost alone. A good curve keeps the next step within reach of one session for most of the game.
2. **Exponential income demands exponential costs.** Multipliers stack multiplicatively (pets x rebirth x boosts), so income is usually exponential even if each piece looks linear. Costs must keep up or the economy breaks.
3. **Walls are a design choice.** A deliberate steepening before a rebirth or a new zone tells the player "change strategy". An accidental wall just tells them to quit.
4. **Paid boosts shift the whole curve.** A permanent 2x income pass halves every time-to-next. Check that buyers still meet content at a sane pace.
5. **New players and veterans share servers.** Huge power gaps in a shared world can make veterans trivialise content for others or make new players feel useless. Scale enemies per player or separate zones.
6. **Big numbers need care.** Values beyond about 2^53 lose integer precision in Luau's doubles; very fast curves need special number handling.

## Tiny example

```lua
-- Cost grows 15% per level; income grows 10% per level.
local function cost(level) return 100 * 1.15 ^ level end
local function income(level) return 5 * 1.10 ^ level end
for _, l in { 1, 10, 30, 50 } do
	print(l, math.floor(cost(l) / income(l)), "seconds to next")
end
-- About 20, 31, 75 and 184 seconds: a gentle steepening.
```

## Where this shows up

- [[Pricing Curves and Upgrade Costs]]: the deep dive on cost curves.
- [[Progression and Pacing Design]]: pacing across a whole game.
- [[Progression Levels and Unlocks]]: level systems.
- [[Rebirth and Prestige System End to End]]: resetting the curve.
- [[Big Numbers Precision and Formatting]]: when curves outgrow doubles.
- [[Genre Playbook - Simulators]]: exponential genres.
- [[Balancing with Spreadsheets and Data]]: curves in spreadsheets.
- [[Game Passes]]: passes that shift the curve.
- [[Status Effects Buffs and Stacking Rules]]: multiplier stacking.
- [[Battle Pass and Season Design]]: a time-gated curve.
- [[Case Study - Blox Fruits]]: a long level curve.
- [[Tower Defense Waves and Placement End to End]]: enemy power curves per wave.

Related concepts: [[Faucets and Sinks]], [[Expected Value]], [[Core Loop]].

## Connected notes
<!-- auto-links:start -->
[[Economy Inflation Sinks and Faucets Math]] · [[Economies and Currencies]] · [[Genre Playbook - Tycoons]] · [[Economy Design Start Here]] · [[Simulating an Economy Before Launch]] · [[Simulator and RNG Genre Teardown]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
