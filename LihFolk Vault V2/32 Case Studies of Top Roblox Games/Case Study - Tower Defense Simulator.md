---
tags: [case-study, top-games, tower-defense, co-op, units, waves, game-passes, battle-pass, crates, live-ops, type/case-study, area/design, area/monetization]
---
# Case Study - Tower Defense Simulator

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Humanoid enemies at scale without simulation shortcuts.
> - Avoid: Tower placement validated on the client.
> - Avoid: Paid units with no free counterpart at similar power.
> - Lobby place and match places with group teleports.
> - Units with upgrade paths; free roster can clear standard content.
> - Paid units are side-grades or niche; sandbox and cosmetics for whales.
>
> Cost: TL;DR ~140 tok · whole note ~1.6k tok. Read more: ## Snapshot · ## Monetisation (Observed, public pass list, 29 Oct 2026) · ## Common mistakes in TD clones · ## Checklist
<!-- tldr:end -->

Tower Defense Simulator (TDS) is one of Roblox's long-running co-op tower defense games: up to four players place units along a path to stop zombie waves and bosses, earning currency to unlock more units. It is a useful study because its store is unusually tower-centric: many towers are sold directly as game passes. That is a clear case of monetising the roster itself, with the balance questions that follow.

Source labels: **Public stats** (Roblox public APIs, fetched 29 October 2026), **Observed** (store description and pass list), **Reported**, **Rule of thumb**, **Unverified**.

## Snapshot

| Field | Value | Source |
|---|---|---|
| Creator | Paradoxum Games (group) | Public stats |
| Place created | 5 June 2019 | Public stats |
| Genre on Roblox | Strategy / Tower Defense | Public stats |
| Visits | 5,045,087,928 | Public stats, 29 Oct 2026 |
| Favourites | 3,534,243 | Public stats |
| Votes | 2,086,080 up, 129,861 down (about 94 % positive) | Public stats |
| Playing at check | 9,595 | Public stats, one moment |
| Lobby server size | 50 | Public stats |
| Title at check | "[🌙 NIGHT 3] Tower Defense Simulator" | Public stats |

The 50-player figure is the lobby place; matches run in separate servers. Peak concurrency is not stated here.

## The structure

- **Lobby place plus match places.** Players gather in a 50-player lobby, form groups via elevators or queues, and teleport into match servers ([[Lobby and Hub Design]], [[Parties and Group Teleports]]).
- **Waves and bosses** per map and mode, harder modes unlocking with progress.
- **Units (towers)** with upgrade paths, unlocked with soft currency or bought.
- **Live ops** through episodic content. At check time the title and description advertised "Solar Requiem Night III", with Night I and II in earlier versions, alongside a battle pass and themed crates (Observed: version notes 2.14.0 to 2.16.0 in the description).

## Monetisation (Observed, public pass list, 29 Oct 2026)

Priced passes at check time included:

| Pass | Price (Robux) |
|---|---|
| Sandbox Plus+ | 7999 |
| Hacker | 2249 |
| [FPS MODE] Gatling Gun! | 1949 |
| Engineer | 1690 |
| Pursuit | 1500 |
| Mercenary Base | 1350 |
| Harvester [LIMITED TIME] | 799 |
| [LIMITED] Executioner | 799 |
| Slasher [LIMITED TIME] | 499 |
| Warden | 450 |
| Saboteur Tower | 449 |
| VIP | 375 |
| Cowboy, Turret | 340 each |
| Mortar | 300 |
| Vigilante Skin Bundle | 300 |
| Crook Boss | 225 |
| Custom Music [DJ Booth] | 85 |
| Resize Your Player! | 70 |
| Meme Emotes | 55 |

Many other passes (retired limited towers and seasonal skins) were listed with no price, meaning they were off sale. The description also offered "+$100 starting cash" for joining the group and a code for a free skin (Observed).

Lessons from the store's shape:

- **Towers are the product.** Many paid passes are units. This converts well because a new unit is a new strategy, but it creates pay-to-win perception in co-op: a team with paid towers carries one without.
- **Limited-time towers** create urgency and collector value, and also FOMO pressure on a young audience ([[Limited-Time Offers - Design and Ethics]]).
- **A very high-priced sandbox pass** sells a creative mode rather than power; it is a whale offer that does not affect other players.
- **Crates and a battle pass** add recurring revenue; any paid crate needs disclosed odds and `PolicyService` gating ([[Paid Random Items and Odds Disclosure in Practice]]).

## What to copy

- Lobby plus match places with group teleports.
- Episodic content ("Night I, II, III") that gives the title and thumbnails a reason to change on a schedule.
- Group-join reward that helps new players' first match (starting cash), rather than a permanent power boost.
- Upgrade paths that make each unit a small decision tree.
- Sandbox or creative modes as premium content that does not affect co-op balance.

## What not to copy (or copy carefully)

- **Paid towers that dominate free ones.** In co-op, paid power is less toxic than in PvP, but if the best strategy needs paid units, free players feel like passengers. Keep paid units side-grades or niche.
- **Heavy limited-time pressure** on a young audience. Bring limited items back on a predictable cycle, or sell them as cosmetics.
- **Ever-growing pass lists.** Dozens of retired passes make the store hard to read; consolidate.

## Technical lessons

Late waves mean many enemies and many firing towers in one server. Server-simulated, client-rendered enemies, pooled projectiles and capped effects are the standard approach ([[Genre Playbook - Tower Defense]], [[Tower Defense Waves and Placement End to End]]). AFK farming with idle towers is a known genre problem; reward active play and cap idle rewards.

## Common mistakes in TD clones

- Humanoid enemies at scale without simulation shortcuts.
- Tower placement validated on the client.
- Paid units with no free counterpart at similar power.
- Matches that need four players to be winnable.

## Checklist

- [ ] Lobby place and match places with group teleports.
- [ ] Units with upgrade paths; free roster can clear standard content.
- [ ] Paid units are side-grades or niche; sandbox and cosmetics for whales.
- [ ] Limited items return on a known cycle or are cosmetic.
- [ ] Episodic content updates reflected in title and thumbnails.
- [ ] Enemy simulation measured at the late-wave cap.

## See also

- [[Genre Playbook - Tower Defense]]
- [[Tower Defense Waves and Placement End to End]]
- [[Battle Pass and Season Design]]
- [[Game Passes]]
- [[Top Games Case Studies Start Here]]

## Connected notes

[[Genre Playbook - Zombie and Wave Survival Co-op]] · Limited-Time Offers - Design and Ethics · Teleporting and Multi-Place Games · Robux Price Points and Offer Design

Sources: https://games.roblox.com/v1/games?universeIds=1176784616 ; https://games.roblox.com/v1/games/votes?universeIds=1176784616 ; https://apis.roblox.com/game-passes/v1/universes/1176784616/game-passes (read 29 October 2026).

<!-- related:start -->
## Related
[[Case Study - Dead Rails]] · [[Case Study - Rivals]] · [[Case Study - Forsaken]] · [[Case Study - The Strongest Battlegrounds]] · [[Case Study - Murder Mystery 2]] · [[Case Study - Jailbreak]] · [[Case Study - Doors]] · [[Case Study - 99 Nights in the Forest]]
<!-- related:end -->
