---
tags: [teardown, high-craft, survival, open-world, zombies, loot, pvp, large-servers, streaming, type/case-study, area/design, level/advanced]
verified: 2026-10-29
---
# Teardown - Apocalypse Rising 2

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No loss on death -> survival loot means nothing without risk.
> - Avoid: Big map without streaming -> phones run out of memory; stream from day one.
> - Avoid: Zombies everywhere at once -> spawn them around players with a budget.
> - Inventory drops on death and is server-owned.
> - Gunfire and vehicles are audible at long range.
> - Streaming on, with persistent landmarks.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## Snapshot · ## Tech notes · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Apocalypse Rising 2 is a hardcore open-world zombie survival game: you spawn with almost nothing on a large map, scavenge food, medicine, ammunition and weapons, and decide whether the next player you meet is a friend or a threat.

Trust labels: **Roblox docs**, **Measured**, **Rule of thumb**, **Unverified**. Not played for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | Dualpoint Interactive (group) | Measured, Roblox games API, 2026-10-29 |
| Place created | 11 June 2017 | Measured, Roblox games API |
| Visits | 200,710,183 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 1,025,492 | Measured, Roblox games API, 2026-10-29 |
| Rating | 85.8% | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 1,196 | Measured, Roblox games API, 2026-10-29 |
| All-time peak CCU | 43,831 on 18 September 2026 | Measured, Rolimons, read 2026-10-29 |
| Average session | about 17.1 minutes | Measured, Rolimons, read 2026-10-29 |
| Max players (root place) | 120 | Measured, Roblox games API (older community listings say 30 per server; Unverified which applies to main servers today) |
| Price | free; a 1,000 Robux paid-access price was removed on 1 July 2022 | Measured (no price now) + Unverified (date, developer's DevForum announcement) |
| Genre labels | Action, Open World Action | Measured, Roblox games API |

A record peak in September 2026, nine years after the place was created, shows a craft-driven survival game can still find its biggest moment late.

## Core loop

1. Spawn with basic gear.
2. Loot buildings for food, water, medicine, ammo and weapons; manage hunger and thirst (Unverified details, guides).
3. Avoid or fight zombies; hear gunfire and decide whether to approach.
4. Meet players: trade, group (up to a small party size), or fight.
5. Die and lose what you carried; respawn and start again (Unverified, community guides; the starter-kit passes below only make sense with this rule).

## First 60 seconds

- You arrive with very little and no map marker telling you where loot is. The first decision is a direction.
- The first zombie teaches noise: shots draw more of them. **Rule of thumb:** hardcore games can skip tutorials if the first threat teaches the main rule (sound is dangerous) on its own.
- Free VIP servers let new players learn the map without other players (Unverified, community wiki).

## The craft that sets it apart

**1. Loss makes loot meaningful.** Dying drops what you carried. Every found item feels valuable because it can be lost. This is the core emotional engine of the genre.

**2. Sound as information.** Gunfire, footsteps and vehicle engines carry far. In a big map, audio tells you where players are, which makes every shot a decision.

**3. Weapon handling with weight.** Realistic firearms with recoil, attachments and limited ammo make fights short and costly. See [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]].

**4. A large, hand-built world on Roblox's engine.** A big map means streaming, level-of-detail and a strict art budget. The craft is in making distance readable (landmarks, roads, distinct towns) without loading everything.

**5. Player stories.** Betrayal, rescue and trading moments are unscripted. The design job is to create situations, not scripts.

## Progression and economy

- **Gear is the progression,** and it resets on death. Long-term progress is knowledge and optional starter kits.
- **Infected loot drops** (a pass doubles them, Measured) give zombies a reward beyond survival.

## Monetization and 2026 rules

Public passes (Measured, 2026-10-29): 2x Infected Loot Drops 500, Starter Kit Veteran 500, Starter Kit Hunter 500, Starter Kit Survivalist 400, Starter Kit Bandit 250, Premium Hair Colors 75.

- **Starter kits** sell a head start in a game where gear resets on death. That is power, but bounded: the kit is lost when you die. **Rule of thumb:** sell starting comfort, never top-tier loot, in a PvP survival game.
- **Loot multipliers** affect a random drop. If a pass changes the odds of a random outcome, show the resulting odds; see [[Paid Random Items and Odds Disclosure in Practice]] and [[Regional Compliance - Paid Random Items and Country Rules]].
- **Moving from paid access to free** (2022, Unverified date) widened the funnel; see [[Monetization Overview]].

## Retention

- **Emergent stories** and friend groups.
- **Map and system updates** over many years (place since 2017).
- **Late growth:** a record peak in September 2026 (Measured). The cause is not confirmed here (Unverified); treat it as a sign that discovery can reward long-lived games after a strong update.

## Tech notes

- **Large servers and a large map need streaming.** Use `Workspace.StreamingEnabled` with persistent models for landmarks; see [[Instance Streaming]], [[StreamingEnabled]], [[Level of Detail and Model Streaming]] and [[Streaming Joins - Frozen Players and Loading Screen Teardown]].
- **Zombie budget.** Many zombies across a map need a per-region director that spawns near players and despawns far away: [[Spawn Director - Credit Budgets and Player-Count Scaling]].
- **Replication budget.** Players and zombies far away do not need full-rate updates: [[Interest Management and Per-Player Replication]] and [[Network Bandwidth Budgets and Measuring Them]].
- **Server-checked inventory** to stop duplication on death drops: [[Economy Exploits - Dupes Races and Purchase Abuse]] and [[Trading Systems Without Duplication]].
- **Gun hits validated on the server:** [[Weekend Build - Arena Shooter with Server-Checked Hits]] and [[Detecting Combat Exploits - Reach Rate and Aim]].

## Team and cadence

Dualpoint Interactive; current developers named on a community wiki (Unverified). Long development, alpha labels and big system updates rather than weekly drops.

## Build it yourself

1. **Loot tables per building type** with rarity tiers: [[Procedural Loot and Item Generation]] and [[Drop Tables Rarity and Pity Systems]].
2. **Hunger, thirst and health** as server stats with slow decay: [[Genre Playbook - Survival and Crafting]].
3. **Death drop container** that holds the player's inventory for a time: [[Saved Inventory End to End]].
4. **Noise events** that pull zombies: a server function that records sound position and radius; zombies within range investigate. [[NPC AI and Behaviour]].
5. **Streaming-first world** with landmark models that never stream out: [[Instance Streaming]].
6. **Gun system** from [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] and [[Time-to-Kill Math and a Weapon Balance Sheet]].

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 43,831 peak CCU, 18 Sep 2026 | Measured | Rolimons, read 2026-10-29 |
| 17.1-minute average session | Measured | Rolimons, read 2026-10-29 |
| Root place max players 120 | Measured | Roblox games API, 2026-10-29 |
| Sell starting comfort, not top-tier loot | Rule of thumb | This note |

## Common mistakes when copying this style

- **No loss on death** -> survival loot means nothing without risk.
- **Big map without streaming** -> phones run out of memory; stream from day one.
- **Zombies everywhere at once** -> spawn them around players with a budget.
- **Selling end-game guns** -> sell kits that are lost on death, or cosmetics.
- **Silent gunfire** -> sound must carry so fights create stories.

## Checklist

- [ ] Inventory drops on death and is server-owned.
- [ ] Gunfire and vehicles are audible at long range.
- [ ] Streaming on, with persistent landmarks.
- [ ] Zombie director spawns near players with a cap.
- [ ] Paid items are bounded (lost on death) or cosmetic.
- [ ] Any pass that changes random drops shows the resulting odds.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Teardown - Phantom Forces]] · [[Case Study - 99 Nights in the Forest]] · [[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Mobile and Low-End Optimization]]

<!-- related:start -->
## Related
[[Teardown - Anime Vanguards]] · [[Teardown - Deepwoken]] · [[Teardown - Piggy]] · [[Teardown - Blade Ball]] · [[Teardown - Driving Empire]] · [[Teardown - Evade]] · [[Teardown - Grace]] · [[Teardown - Welcome to Bloxburg]]
<!-- related:end -->
