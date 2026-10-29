---
tags: [case-study, top-games, survival, co-op, train, journey, zombies, virality, 2025, game-passes, type/case-study, area/design]
---
# Case Study - Dead Rails

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Physics-heavy vehicles that throw players off.
> - Avoid: No streaming or cleanup plan for the route.
> - Avoid: Stops with no clock, so there is no tension.
> - Premise fits in one paragraph and one thumbnail.
> - Moving base doubles as progress display.
> - Stops forced by resources, with a clock.
>
> Cost: TL;DR ~120 tok · whole note ~1.6k tok. Read more: ## Snapshot · ## Why the structure works · ## Common mistakes in journey survival games · ## Checklist
<!-- tldr:end -->

Dead Rails is a 2025 co-op survival hit: a small group rides a train across a zombie-infested desert, stopping to scavenge towns for fuel, weapons and money, and tries to reach the end of the line. Its setup is a strong example of the "journey" structure, where the world scrolls past a moving base, and of how a clear premise spreads on video. This teardown uses public information only.

Source labels: **Public stats** (Roblox public APIs, fetched 29 October 2026), **Observed** (store description and pass list), **Reported** (trackers, with caveats), **Rule of thumb**, **Unverified**.

## Snapshot

| Field | Value | Source |
|---|---|---|
| Creator | RCM Games (group) | Public stats |
| Place created | 1 January 2025 | Public stats (place creation; public release date not verified) |
| Genre on Roblox | Adventure / Exploration | Public stats |
| Visits | 6,628,414,193 | Public stats, 29 Oct 2026 |
| Favourites | 6,165,233 | Public stats |
| Votes | 3,353,012 up, 269,517 down (about 93 % positive) | Public stats |
| Playing at check | 13,442 | Public stats, one moment, during an event |
| Server size | 16 | Public stats |

Peak concurrency is not stated: trackers give inconsistent figures and dates, and one tracker's "all-time peak" covers only its own recording window (Reported, RoWatcher and Profitable, October 2026). That 6.6 billion visits accrued since the start of 2025 is itself the strongest verified signal of how fast it grew.

## The premise (Observed)

The description sets the scene in 1899: a "Zombie Plague" has swept the American continent, a cure was found in Mexico, and you "gather your friends and board your trains to fight through the zombie-infested desert." One paragraph, one goal (get south), one vehicle (the train), one enemy (zombies), one social instruction (bring friends).

## Why the structure works

1. **A moving base.** The train is home, transport and progress bar in one. The distance travelled is the score; no menu is needed to show progress.
2. **Stop or go decisions.** Fuel and supplies force stops; stops are dangerous. Every stop is a risk-reward choice the whole group makes together.
3. **Day and night pressure** (Reported by guides; not verified here) adds a clock to every stop.
4. **Co-op roles emerge naturally**: someone drives and fuels, someone scavenges, someone defends.
5. **Clip-friendly premise.** "Cowboys on a zombie train" reads in a thumbnail and a five-second clip ([[Short-Form Video Marketing]]).
6. **Runs end.** A run can be lost or finished, so each session has an arc and a reason to restart.

Compare with [[Case Study - 99 Nights in the Forest]], another 2025 co-op survival hit built on a single visible progress object (a campfire) and a countdown.

## Monetisation (Observed, public pass list, 29 Oct 2026)

| Pass | Price (Robux) |
|---|---|
| Tommy Gun | 175 |
| Mauser C96 | 148 |
| Sawed-Off Shotgun | 148 |
| +5 Storage | 95 |

A short list: three weapons and storage. Developer products are not visible through the public API. Selling weapons in co-op PvE is less harmful than in PvP, because paid power helps your own team, but it still shifts difficulty for free players in mixed groups. Storage is a clean convenience item.

## Technical lessons

- **Moving platforms.** Players standing, fighting and building on a moving train is a hard physics problem: characters slipping, ownership changes, desync with fast-moving geometry. Moderate speeds, stable carriages and testing with full lobbies matter ([[Boats Buoyancy and Water]] covers the same problem for ships).
- **A world that streams past.** A long route means streaming or procedural generation of towns ahead of the train and cleanup behind it ([[Infinite and Streamed Worlds]], [[Procedural Generation Start Here]]).
- **Many zombies near a moving group** needs the enemy-count patterns from wave games ([[Genre Playbook - Zombie and Wave Survival Co-op]]).

## What to copy

- One-paragraph premise with one goal, one vehicle, one enemy.
- A moving base as progress bar.
- Forced stops as group risk-reward decisions.
- Runs with an end, so sessions have arcs.
- A tiny store: a few items and convenience.

## What not to copy

- **Pay-to-win weapons** in mixed groups without free equivalents.
- **A long route with empty stretches.** Something must happen between stops.
- **Clone art and premise.** The structure (journey with a moving base) is reusable; the cowboy-zombie-train identity is theirs.

## Common mistakes in journey survival games

- Physics-heavy vehicles that throw players off.
- No streaming or cleanup plan for the route.
- Stops with no clock, so there is no tension.
- Solo play impossible.

## Checklist

- [ ] Premise fits in one paragraph and one thumbnail.
- [ ] Moving base doubles as progress display.
- [ ] Stops forced by resources, with a clock.
- [ ] Route streams ahead and cleans up behind.
- [ ] Tested with a full lobby on the moving base.
- [ ] Store: few items, convenience first, free path to every weapon.

## See also

- [[Case Study - 99 Nights in the Forest]]
- [[Genre Playbook - Survival and Crafting]]
- [[Genre Playbook - Zombie and Wave Survival Co-op]]
- [[Infinite and Streamed Worlds]]
- [[Top Games Case Studies Start Here]]

## Connected notes

[[Case Study - Grow a Garden]] · [[Case Study - Steal a Brainrot]] · [[Retention and Return Hooks]] · [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]]

Sources: https://games.roblox.com/v1/games?universeIds=7018190066 ; https://games.roblox.com/v1/games/votes?universeIds=7018190066 ; https://apis.roblox.com/game-passes/v1/universes/7018190066/game-passes ; https://rowatcher.com/games/7018190066 (read 29 October 2026).

<!-- related:start -->
## Related
[[Case Study - Tower Defense Simulator]] · [[Case Study - Forsaken]] · [[Case Study - Jailbreak]] · [[Case Study - The Strongest Battlegrounds]] · [[Case Study - Rivals]] · [[Case Study - Murder Mystery 2]] · [[Case Study - Brookhaven RP]] · [[Case Study - Blox Fruits]]
<!-- related:end -->
