---
tags: [core-concept, game-design, retention, progression, type/reference, area/design, level/beginner]
---
# Core Loop

<!-- tldr:start -->
> [!tldr] TL;DR
> - Roblox players decide fast. Many leave within the first minute or two if nothing satisfying has happened, and the platform's...
> - The loop must be fun with zero upgrades.
> - Every loop needs a visible "next". The player should always see the next upgrade, zone or item and roughly how far away it is.
> - Feedback is part of the loop, not decoration.
>
> Cost: TL;DR ~130 tok · whole note ~980 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

The **core loop** is the shortest repeating cycle of actions the player performs most of the time: in a simulator, *click, earn, upgrade, click faster*; in a shooter, *find, fight, loot*; in a tycoon, *build, earn, expand*. Everything else in the game (quests, events, shops, social features) either feeds this loop or wraps around it.

## Why it matters on Roblox

Roblox players decide fast. Many leave within the first minute or two if nothing satisfying has happened, and the platform's discovery systems watch how long players stay and whether they return. A clear, fast, rewarding core loop is what those first minutes are made of. Most successful Roblox games have a loop the player completes for the first time within 30 to 60 seconds (rule of thumb from studying top games).

## Loops nest

| Loop | Length (typical) | Example in a collection game |
|---|---|---|
| Core (moment to moment) | 10 to 60 seconds | Roll, see result, equip if better |
| Session (meta) | 10 to 30 minutes | Reach the next zone, finish today's quests |
| Long-term | Days to weeks | Complete an index, rebirth, reach a season rank |

## The nuance most people miss

1. **The loop must be fun with zero upgrades.** If the first loop is only tolerable because of what it unlocks later, players leave before later arrives.
2. **Every loop needs a visible "next".** The player should always see the next upgrade, zone or item and roughly how far away it is. Hidden goals feel like no goals.
3. **Feedback is part of the loop, not decoration.** The reward moment (sound, number pop, celebration) is what turns an action into a loop the player wants to repeat. See the game feel notes.
4. **Social pressure is a loop multiplier.** On Roblox, seeing other players with better items is a strong motivator. Make progress visible to others (titles, auras, pets that follow).
5. **Loops wear out.** The same loop with bigger numbers stops working at some point; the session and long-term loops must introduce new verbs or rules, not only larger values.

## Tiny example

A fishing game: cast (2 s), wait with a small reaction minigame (5 to 15 s), catch with a rarity reveal (2 s), sell or keep (2 s). First loop complete in about 20 seconds; the shop shows a better rod at 300 coins, roughly ten catches away. That visible next step is what the session loop is built on.

## Where this shows up

- [[Core Loops and Session Design]]: the full design note.
- [[Progression and Pacing Design]]: how loops scale over time.
- [[Genre Playbook - Simulators]]: a genre built almost entirely on the core loop.
- [[Simulator and RNG Genre Teardown]]: loops in successful games.
- [[Case Study - Grow a Garden]]: a slow-burn loop with return hooks.
- [[Case Study - Fisch]]: a fishing loop at scale.
- [[Reward Moments and Celebrations]]: the payoff that closes the loop.
- [[Planning and Scoping a Roblox Game]]: scoping around the loop first.
- [[Round-Based Minigame Loop End to End]]: a round loop built end to end.
- [[Tycoon Plots and Droppers End to End]]: a tycoon loop built end to end.
- [[Teaching Through Level Design]]: teaching the loop without text.
- [[Competitor Analysis Method]]: reading other games' loops.

Related concepts: [[Session Length]], [[Power Curve]], [[Onboarding Funnel]], [[Faucets and Sinks]].

## Connected notes
<!-- auto-links:start -->
[[Top Games Case Studies Start Here]] · First-Time User Experience and Onboarding · Genre Playbook - Tycoons · [[Core Concepts Start Here]] · Genre Systems Start Here · Marketing and Growth Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Faucets and Sinks]] · [[Expected Value]] · [[Retention Cohorts]] · [[Variance]] · [[Click-Through Rate]] · [[Pity Timer]] · [[Instance Count]] · [[Telemetry Events]]
<!-- related:end -->
