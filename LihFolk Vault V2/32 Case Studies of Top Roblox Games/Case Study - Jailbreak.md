---
tags: [case-study, top-games, cops-and-robbers, open-world, vehicles, heists, anti-cheat, longevity, game-passes, type/case-study, area/design, level/intermediate]
---
# Case Study - Jailbreak

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Team imbalance with no cap or rebalance.
> - Avoid: Robberies completed by a single client event.
> - Avoid: No streaming plan for high-speed driving.
> - Two sides with different verbs in one space.
> - Timed, server-wide objectives that bring players together.
> - Visible possession as progression; store sells flavour and capacity, not wins.
>
> Cost: TL;DR ~130 tok · whole note ~1.8k tok. Read more: ## Snapshot · ## Longevity and its costs · ## Common mistakes when building a Jailbreak-like · ## Checklist
<!-- tldr:end -->

Jailbreak is the reference design for cops-versus-criminals on Roblox: an open city where prisoners escape, rob locations on timers, and buy faster cars, while police chase and arrest them. It launched in 2017 and is still updated in 2026, which makes it one of the longest-lived top games on the platform and a useful study in what keeps a systems game alive and what wears it down. This teardown uses only public information; nothing was played or logged into for it.

Source labels: **Public stats** (Roblox public games, votes and game-pass APIs, fetched 29 October 2026), **Observed** (the public store description and pass list from those APIs), **Reported** (Wikipedia or press, with date), **Rule of thumb**, **Unverified**.

## Snapshot

| Field | Value | Source |
|---|---|---|
| Creator | Badimo (group) | Public stats |
| Released | April 2017; co-created by Alex Balfanz | Reported, Wikipedia "List of Roblox games", read October 2026 |
| Genre on Roblox | Town and City / Open World Action | Public stats |
| Visits | 8,082,065,851 | Public stats, 29 Oct 2026 |
| Favourites | 18,690,457 | Public stats |
| Votes | 5,808,486 up, 812,193 down (about 88 % positive) | Public stats |
| Playing at check | 3,283 | Public stats, one moment (04:00 UTC) |
| Server size | 30 | Public stats |

The 3,283 snapshot is one early-morning UTC moment and should not be read as a daily average. The store description at check time said the team is "now focused on cheating before rolling out any remaining updates" (Observed). Wikipedia reports that Jailbreak earned over US$1 million in its first year and that a film based on the game was announced in November 2025 (Reported). No revenue figures for later years are known here.

## The design in one paragraph

Two teams with different verbs share one map. Criminals choose when and where to commit crimes; robbery locations open and close on server-wide timers; police get alerts and must physically catch criminals. Money from both sides goes into vehicles, the main progression and the main store. Server size 30 keeps a city of this scale populated without crowding robberies.

## What made it work

1. **Asymmetry with shared space.** Cops and criminals do different things in the same streets. Each side generates content for the other.
2. **Timed locations as meeting points.** A store opening is a reason to drive somewhere now, and the place police will go. Timers create encounters without matchmaking.
3. **Vehicles as identity and progression.** Cars are what players buy, show off and talk about; the store is built around them (see pass list below).
4. **Readable first minute.** "Escape the prison" is a tutorial that is also the fantasy.
5. **Big, rare updates with map changes.** New locations and vehicles you can see on the map, rather than numbers in a menu.
6. **Platform event participation** over the years kept it in front of new players (Reported via Wikipedia's mention of a Ready Player One event).

## Monetisation (Observed, public pass list, 29 Oct 2026)

| Pass | Price (Robux) |
|---|---|
| VIP Lifetime | 750 |
| Pro Garage | 450 |
| Crime Boss | 400 |
| SWAT Team | 400 |
| VIP Trading | 350 |
| Duffel Bag | 345 |
| Car Stereo | 200 |

Two passes (XP Boost, Extra Storage marked "Retiring Soon") had no price listed at check time. The pattern: **team-flavoured perks** (Crime Boss, SWAT), **capacity** (Duffel Bag, Pro Garage), **social** (VIP Trading, Car Stereo). Developer products and in-game vehicle prices are not visible through the public API and are not covered here.

## Longevity and its costs

- **Exploit pressure grows with age and fame.** A nine-year-old open-world game with client-owned vehicles is a long-term target for speed, teleport and auto-rob cheats. The current description's anti-cheat focus is the visible cost. If you build in this genre, server checks on vehicles and robbery progress are day-one work ([[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]], [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]).
- **Economy inflation.** Long-lived economies with trading accumulate wealth; new players face a gap to veterans. Seasonal content and cosmetic-only prestige help ([[Economy Inflation Sinks and Faucets Math]]).
- **Concurrency now well below past highs** at least at the observed moment; long-lived games depend on events and updates to bring players back ([[Update Cadence and Hype Cycles]]).

## What to copy

- Asymmetric teams sharing one space, with information tools for the chasing side.
- Server-wide timed objectives as encounter generators.
- Vehicles (or another visible possession) as the main progression and store.
- Team-flavoured passes that change *how* you play a side, not whether you win.
- A tutorial that is the fantasy.

## What not to copy

- **Client-trusted vehicles or robbery progress.** The genre attracts cheats; validate on the server from launch.
- **Selling raw speed.** If the fastest car is bought, chases end and the police side dies.
- **A map so large it is empty** at your real server size; Jailbreak's 30-player servers suit its map, not every map.
- **Copying the IP.** Dozens of "jailbreak-like" games exist; the asymmetric structure is free to use, the names and art are not.

## Common mistakes when building a Jailbreak-like

- Team imbalance with no cap or rebalance.
- Robberies completed by a single client event.
- No streaming plan for high-speed driving.
- Police with perfect information (exact markers), which kills chases.

## Checklist

- [ ] Two sides with different verbs in one space.
- [ ] Timed, server-wide objectives that bring players together.
- [ ] Visible possession as progression; store sells flavour and capacity, not wins.
- [ ] Vehicle and robbery validation on the server from day one.
- [ ] Team caps and rebalancing.
- [ ] Update plan with map-visible additions.

## See also

- [[Genre Playbook - Open-World City and Crime Roleplay]]
- [[Genre Playbook - Racing and Driving]]
- [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]]
- [[Top Games Case Studies Start Here]]
- [[Case Study - Brookhaven RP]]

## Connected notes

[[Case Study - Blox Fruits]] · [[Economy Exploits - Dupes Races and Purchase Abuse]] · Live Ops Events and Updates · [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]]

Sources: https://games.roblox.com/v1/games?universeIds=245662005 ; https://games.roblox.com/v1/games/votes?universeIds=245662005 ; https://apis.roblox.com/game-passes/v1/universes/245662005/game-passes ; https://en.wikipedia.org/wiki/List_of_Roblox_games (all read 29 October 2026).

<!-- related:start -->
## Related
[[Police Chases and Wanted Levels]] · [[Case Study - Dead Rails]] · [[Case Study - Rivals]] · [[Case Study - Forsaken]] · [[Case Study - Murder Mystery 2]] · [[Case Study - Tower Defense Simulator]] · [[Case Study - The Strongest Battlegrounds]] · [[Case Study - Adopt Me]] · [[Case Study - Pet Simulator 99]]
<!-- related:end -->
