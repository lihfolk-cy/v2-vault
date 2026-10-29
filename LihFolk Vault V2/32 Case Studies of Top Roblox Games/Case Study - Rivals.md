---
tags: [case-study, top-games, fps, shooter, duels, cosmetics, weapon-skins, cross-platform, anti-cheat, type/case-study, area/design, level/intermediate]
---
# Case Study - Rivals

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Client-authoritative hits.
> - Avoid: Long queues instead of instant pads.
> - Avoid: No rematch flow.
> - Duel starts within seconds of stepping on a pad.
> - First-to-N rounds; rematch button; spectating.
> - Server-validated hits; ping shown; abuse-tested.
>
> Cost: TL;DR ~110 tok · whole note ~1.6k tok. Read more: ## Snapshot · ## The design · ## Common mistakes in duel shooters · ## Checklist
<!-- tldr:end -->

Rivals is a first-person arena shooter built around short duels: step on a pad, fight one opponent (or up to 5v5), first to five round wins takes the match. Released in May 2024 by Nosniy Games, it showed that a modern, fast FPS can be a top Roblox game across phones, PC and console. It is a study in reducing a shooter to its most replayable unit, the duel, and monetising with weapon bundles and skins.

Source labels: **Public stats** (Roblox public APIs, fetched 29 October 2026), **Observed** (store description and pass list), **Reported** (Wikipedia, read October 2026), **Rule of thumb**, **Unverified**.

## Snapshot

| Field | Value | Source |
|---|---|---|
| Creator | Nosniy Games (group) | Public stats |
| Released | 26 May 2024 | Reported, Wikipedia; matches place creation date in Public stats |
| Genre on Roblox | Shooter / Deathmatch Shooter | Public stats |
| Visits | 19,013,117,926 | Public stats, 29 Oct 2026 |
| Favourites | 96,143,846 | Public stats |
| Votes | 10,889,282 up, 738,031 down (about 94 % positive) | Public stats |
| Playing at check | 71,161 | Public stats, one moment, during a Halloween update |
| Server size | 40 | Public stats |
| Awards | "Best Shooter Game/Experience", Roblox Innovation Awards 2025 and 2026; Nosniy Games "Best Studio" 2026 | Reported, Wikipedia |

The favourites count is unusually high relative to visits compared with older games in this vault's case studies; it suggests strong use of the favourite button, possibly encouraged in-game. That is an observation, not a verified cause.

## The design

From the store description (Observed):

- **Duel pads**: "Challenge someone by stepping on a duel pad!" Matchmaking is physical: walk onto a pad in a shared lobby, and the duel starts with whoever joins the other side.
- **Formats from 1v1 to 5v5**, "first to 5 wins".
- **Keys** earned in play unlock weapons and skins; **contracts** (quests) unlock exclusive rewards.
- **Win streaks and leaderboards** for status.
- **Platforms**: desktop, phones, tablets, Xbox and PlayStation 5.
- **Anti-cheat stance in the description**: "Cheaters will be permanently banned with no second chances", with abuse of glitches and "sketchy farming methods" also called out.

Why the duel works:

1. **Short, decisive sessions.** A first-to-five duel is a few minutes, with clear stakes and a rematch button.
2. **Lobby as matchmaker.** 40 players in a lobby with many pads means you always see opponents, and spectating others' duels is free content.
3. **Skill expression with a small arsenal.** Players pick a loadout, so each duel is a matchup.
4. **Status from streaks.** Win streaks are visible and shareable.

## Monetisation (Observed, public pass list, 29 Oct 2026)

| Pass | Price (Robux) |
|---|---|
| Heavy Duty Bundle! | 1425 |
| Energy Bundle! | 975 |
| Classic Bundle! | 865 |
| Standard Weapons Bundle! | 849 |
| Exogun Bundle! | 649 |
| Medkit Bundle! | 289 |
| RPG Bundle! | 95 |
| Starter Bundle! | 59 |

"Pixel Bundle!" had no price at check. Weapon availability and keys suggest a mixed model: weapons unlockable with earned keys and also purchasable in bundles, with cosmetic skins on top. Whether bundles contain gameplay-relevant weapons not otherwise earnable was not verified here; if they do, that is a pay-to-win risk in a PvP game, so in your own design keep paid weapons earnable and balanced as side-grades.

The 59-Robux starter bundle is a classic low-friction first purchase ([[Robux Price Points and Offer Design]]).

## Technical lessons

- **Netcode matters more in duels.** In 1v1 every lost trade is blamed on the game. Server-validated hits with capped rewind, and honest ping display, are essential ([[Genre Playbook - Shooters FPS and TPS]]).
- **Cross-platform aim** (touch, controller, mouse) needs aim assist tuning per input, or input-based matchmaking for ranked.
- **Anti-cheat as a public promise.** Stating a zero-tolerance policy is a deterrent, but it must be backed by logging and review to avoid false bans ([[False Positives Lag and Fair Enforcement]]).

## What to copy

- Reduce the genre to its most replayable unit (the duel) and make it start in seconds.
- Physical matchmaking in a social lobby (pads), with spectating.
- Earned keys and contracts as free progression alongside paid bundles.
- Cheap first-purchase bundle.
- Cross-platform from launch.

## What not to copy

- **Paid weapons that win duels.** Keep gameplay items earnable and balanced.
- **Zero-tolerance bans without evidence and appeals.**
- **Favourite or like incentives** that conflict with 2026 rules (rewarding likes and favourites is not allowed; see [[Community Building]]).

## Common mistakes in duel shooters

- Client-authoritative hits.
- Long queues instead of instant pads.
- No rematch flow.
- Arsenal so large that matchups cannot be balanced.

## Checklist

- [ ] Duel starts within seconds of stepping on a pad.
- [ ] First-to-N rounds; rematch button; spectating.
- [ ] Server-validated hits; ping shown; abuse-tested.
- [ ] Earned progression (keys, contracts) plus cosmetic and bundle store; paid weapons earnable.
- [ ] Cross-platform input tuning.
- [ ] Ban system with logging and appeals.

## See also

- [[Genre Playbook - Shooters FPS and TPS]]
- [[Arena Rounds with Teams and Spectating End to End]]
- [[Weekend Build - Arena Shooter with Server-Checked Hits]]
- [[Detecting Combat Exploits - Reach Rate and Aim]]
- [[Top Games Case Studies Start Here]]

## Connected notes

[[Case Study - The Strongest Battlegrounds]] · [[Genre Playbook - Battle Royale]] · Logging Bans and Appeals · Game Passes

Sources: https://games.roblox.com/v1/games?universeIds=6035872082 ; https://games.roblox.com/v1/games/votes?universeIds=6035872082 ; https://apis.roblox.com/game-passes/v1/universes/6035872082/game-passes ; https://en.wikipedia.org/wiki/List_of_Roblox_games (read 29 October 2026).

<!-- related:start -->
## Related
[[Case Study - Tower Defense Simulator]] · [[Case Study - Forsaken]] · [[Case Study - Murder Mystery 2]] · [[Case Study - Jailbreak]] · [[Case Study - Dead Rails]] · [[Case Study - Doors]] · [[Case Study - 99 Nights in the Forest]] · [[Case Study - Steal a Brainrot]]
<!-- related:end -->
