---
tags: [core-concept, economy, game-design, balancing, type/reference, area/economy, level/beginner, area/design]
---
# Faucets and Sinks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Roblox games run for months or years with players who play many hours a day.
> - Measure per player-hour, not in total. Total coins in the world always grows with the player count.
> - Faucets scale with progress unless you stop them.
> - Good sinks feel like rewards. Spending on a cosmetic, an upgrade or a gamble the player chose feels good.
>
> Cost: TL;DR ~130 tok · whole note ~960 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

A **faucet** is any way currency or items enter the economy (enemy drops, quest rewards, daily chests, purchases). A **sink** is any way they leave (shop purchases, upgrade costs, repair fees, trading taxes, consumables). The balance between them over time decides whether prices hold, rise or collapse.

## Why it matters on Roblox

Roblox games run for months or years with players who play many hours a day. If faucets exceed sinks, currency piles up, everything becomes affordable, rewards feel worthless and new players face a world priced for veterans. In trading games the same imbalance makes item values inflate or crash. Roblox also adds faucets you do not fully control: Robux purchases of currency, codes, and events.

## The nuance most people miss

1. **Measure per player-hour, not in total.** Total coins in the world always grows with the player count. The useful number is how many coins an active player earns and spends per hour, and how that changes with progress.
2. **Faucets scale with progress unless you stop them.** Multipliers, pets and rebirths raise income exponentially. Sinks must scale too, usually through costs that grow faster than income (see [[Power Curve]]).
3. **Good sinks feel like rewards.** Spending on a cosmetic, an upgrade or a gamble the player chose feels good. Fees and decay feel like taxes and drive players away.
4. **Items are economies too.** Every item drop is a faucet of that item. If nothing ever consumes items (crafting, fusing, trading taxes), rare items stop being rare.
5. **Purchased currency is a faucet with consequences.** Selling large amounts of soft currency for Robux can undercut the progression it shortcuts. Many games keep a separate premium currency for this reason.
6. **Events are temporary faucets.** A double-coins weekend permanently adds currency. Plan a sink to go with it (an event shop) so the extra coins leave again.

## Tiny example

| Per active hour at level 20 | Coins |
|---|---|
| Faucets: enemies 4,000, quests 1,500, daily 500 | +6,000 |
| Sinks: upgrades 4,200, potions 800, rerolls 600 | -5,600 |
| Net | +400 |

A small positive net feels like saving up. If the level 40 row shows +40,000 net, sinks did not scale and inflation is coming.

## Where this shows up

- [[Economy Inflation Sinks and Faucets Math]]: the full maths.
- [[Economies and Currencies]]: currency design basics.
- [[Currency Architecture - Soft Hard and Event Currencies]]: separating currencies.
- [[Simulating an Economy Before Launch]]: modelling flows in advance.
- [[Economy Telemetry and Balancing Live]]: measuring flows after launch.
- [[Player-Driven Trading Economies]]: item inflation and trade taxes.
- [[Economy Resets and Seasonal Wipes]]: the last-resort sink.
- [[Pricing Curves and Upgrade Costs]]: costs that scale.
- [[Rebirth and Prestige System End to End]]: rebirth as a giant sink.
- [[Balancing with Spreadsheets and Data]]: the spreadsheet behind the table.
- [[Case Study - Pet Simulator 99]]: a large live economy.
- [[Limited-Time Offers - Design and Ethics]]: offers that add currency.

Related concepts: [[Power Curve]], [[Expected Value]], [[Telemetry Events]], [[Core Loop]].

## Connected notes
<!-- auto-links:start -->
[[Economy Design Start Here]] · Progression Levels and Unlocks · Progression and Pacing Design · Genre Playbook - Simulators · Core Loops and Session Design · Live Ops Deep Dive Start Here · [[Core Concepts Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Expected Value]] · [[Pity Timer]] · [[Data Schema Versioning]] · [[Session Length]] · [[Variance]] · [[Onboarding Funnel]] · [[Server Authority]] · [[Event Bus]]
<!-- related:end -->
