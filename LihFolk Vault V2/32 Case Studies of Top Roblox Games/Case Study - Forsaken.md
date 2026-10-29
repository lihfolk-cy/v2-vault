---
tags: [case-study, top-games, asymmetric, horror, killer-vs-survivors, balance, rounds, skins, accessibility, type/case-study, area/design, level/intermediate]
---
# Case Study - Forsaken

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Killer abilities with no counterplay.
> - Avoid: No scaling when Survivors leave or die.
> - Avoid: Long waits between rounds with nothing to do.
> - Clear win conditions and a round timer.
> - Every Killer ability paired with a Survivor counter.
> - Killer power or objectives scale with living Survivors.
>
> Cost: TL;DR ~120 tok · whole note ~1.7k tok. Read more: ## The design · ## The balance problem · ## Common mistakes in asymmetric clones · ## Checklist
<!-- tldr:end -->

Forsaken is an asymmetric survival horror game: in small lobbies, Survivors cooperate to complete objectives and outlast a timer while one player, the Killer, hunts them. It is the clearest recent Roblox example of the killer-versus-survivors format and its balance problem: one player must be as strong as the rest of the server combined, and both sides must enjoy losing. This teardown uses public information only.

Source labels: **Public stats** (Roblox public APIs, fetched 29 October 2026), **Observed** (store description and pass list), **Reported** (trackers, with caveats), **Rule of thumb**, **Unverified**.

## Snapshot

| Field | Value | Source |
|---|---|---|
| Creator | Forsaken Dev Team (group) | Public stats |
| Place created | 28 July 2024 | Public stats |
| Genre on Roblox | Survival / 1 vs All | Public stats |
| Visits | 5,882,303,631 | Public stats, 29 Oct 2026 |
| Favourites | 3,278,410 | Public stats |
| Votes | 2,415,772 up, 445,519 down (about 84 % positive) | Public stats |
| Playing at check | 23,965 | Public stats, one moment |
| Server size | 9 | Public stats |
| Award shown in description | "RIA 2025 Best Survival Experience" | Observed |
| Status in description | "THIS GAME IS IN BETA" | Observed |

A tracker reported the game passing 86,000 concurrent players after a March 2026 update and an all-time peak above 138,000 (Reported, RoWatcher news, 2026; tracker figures, not verified against Roblox data).

## The design

From the description (Observed): Survivors "protect your teammates, complete the objectives, and survive until the timer hits 0"; Killers "kill them all". Nine-player servers imply one Killer and eight Survivors per round (a tracker describes it as 8 versus 1; consistent with the server size).

What the structure gets right:

1. **Two clear goals.** Survivors win by time and objectives; the Killer wins by eliminations. Each side knows what to do in seconds.
2. **A timer that ends rounds.** Survivors can win by not dying; rounds cannot drag.
3. **Characters with kits on both sides.** Rosters of Killers and Survivors with distinct abilities make each round a matchup and each new character an update.
4. **Small servers.** Nine players keep rounds readable and keep the Killer's job possible.
5. **Upfront content warning.** The description begins with a warning about flashing lights and loud audio and recommends epileptic players do not play. Copy the warning, and go further with settings ([[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]], [[Accessibility]]).

## The balance problem

Asymmetric games are balanced per side, per character and per player count:

- **Killer pressure versus Survivor counterplay.** Every Killer ability needs a Survivor answer (stun, escape, heal, distraction), or rounds snowball.
- **Player count changes everything.** Eight Survivors against one Killer plays differently from four against one when players leave mid-round; scale Killer power or objective count to living Survivors.
- **Role queueing.** Most players want to be the Killer some of the time. A fair rotation or a visible chance system keeps Survivors playing. If chance can be bought, disclose it and consider whether it is fair at all.
- **Snowball control.** Downed or dead Survivors need something to do (spectate, assist) so they stay for the next round.
- **Vote ratio.** About 84 % positive is lower than many top games; asymmetric PvP generates frustration on both sides (an inference, not a verified cause).

## Monetisation (Observed, public pass list, 29 Oct 2026)

| Pass | Price (Robux) |
|---|---|
| V.I.P | 599 |
| Skin Pack #4 | 349 |
| 2x Emotes | 199 |
| Emote Pack #3 | 189 |

Other passes (earlier skin and emote packs, themed packs, a special killer access pass) were listed without prices, meaning off sale. The visible store is **cosmetic and status**: skins, emotes, VIP. That fits a competitive asymmetric game where paid power would be resented by both sides.

## What to copy

- Two goals, one timer, small lobbies.
- Character kits on both sides as the update unit.
- Counterplay designed with every Killer ability.
- Killer strength scaled to living Survivors.
- Content warnings plus real accessibility settings.
- Cosmetic store.

## What not to copy

- **Paid Killer chance** without disclosure, or at all if it undermines rotation fairness.
- **"Beta" forever** as an excuse for balance problems; communicate patch plans ([[Patch Notes and Player Communication]]).
- **Flashing and loud effects with only a warning.** Add intensity and volume settings.
- **Cloning an existing horror IP's characters** (the genre on Roblox often borrows from internet horror and other games; that is a takedown risk).

## Common mistakes in asymmetric clones

- Killer abilities with no counterplay.
- No scaling when Survivors leave or die.
- Long waits between rounds with nothing to do.
- Killer role assignment that feels random and unfair.
- Hitboxes and chase validation on the client.

## Checklist

- [ ] Clear win conditions and a round timer.
- [ ] Every Killer ability paired with a Survivor counter.
- [ ] Killer power or objectives scale with living Survivors.
- [ ] Fair, visible role rotation.
- [ ] Spectate and assist for eliminated players.
- [ ] Photosensitivity and volume settings, plus the warning.
- [ ] Cosmetic-only store.

## See also

- [[Genre Playbook - Horror and Story]]
- [[Case Study - Doors]]
- [[Genre Playbook - Social Deduction and Murder Mystery]]
- [[Arena Rounds with Teams and Spectating End to End]]
- [[Top Games Case Studies Start Here]]

## Connected notes

[[Case Study - Murder Mystery 2]] · [[Horror Monster Chase AI End to End]] · Accessibility · Boss Fight Design Patterns

Sources: https://games.roblox.com/v1/games?universeIds=6331902150 ; https://games.roblox.com/v1/games/votes?universeIds=6331902150 ; https://apis.roblox.com/game-passes/v1/universes/6331902150/game-passes ; https://rowatcher.com/news/forsaken-s-floral-update-drives-the-survival-horror-hit-past-86k-players (read 29 October 2026).

<!-- related:start -->
## Related
[[Case Study - The Strongest Battlegrounds]] · [[Case Study - Rivals]] · [[Case Study - Tower Defense Simulator]] · [[Case Study - Dead Rails]] · [[Case Study - Jailbreak]] · [[Case Study - 99 Nights in the Forest]] · [[Case Study - Brookhaven RP]] · [[Case Study - Blox Fruits]]
<!-- related:end -->
