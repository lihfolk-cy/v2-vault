---
tags: [teardown, high-craft, survival, movement, momentum, bunny-hop, co-op, revive, cosmetics, type/case-study, area/design, level/intermediate]
verified: 2026-10-29
---
# Teardown - Evade

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Momentum that only works with a keyboard -> give touch players at least one top-tier technique.
> - Avoid: Rubber-banding fast players -> measure legit top speed and log before you punish.
> - Avoid: Smart enemies, flat movement -> invert it: simple chasers, deep movement.
> - Movement has at least three stackable techniques.
> - One top technique is easy on touch.
> - Exploit thresholds come from measured legit speeds.
>
> Cost: TL;DR ~150 tok · whole note ~2.1k tok. Read more: ## Snapshot · ## The craft that sets it apart · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Evade is a round-based co-op survival game where fast, flat-faced chasers ("Nextbots") hunt a small team across open maps, and the whole game is about movement skill: momentum, bunny hops, slides and reviving downed friends.

Trust labels: **Roblox docs**, **Measured**, **Rule of thumb**, **Unverified**. Not played for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | Hexagon Development Community (group) | Measured, Roblox games API, 2026-10-29 |
| Place created | 10 June 2022 | Measured, Roblox games API |
| Visits | 9,398,076,500 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 8,665,697 | Measured, Roblox games API, 2026-10-29 |
| Rating | 93.9% (3,280,442 up / 212,968 down) | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 45,202 | Measured, Roblox games API, 2026-10-29 (Halloween event week) |
| All-time peak CCU | 197,261 on 28 August 2022 | Measured, Rolimons, read 2026-10-29 |
| 30-day peak | 165,296 | Measured, Rolimons, read 2026-10-29 |
| Average session | about 12.8 minutes | Measured, Rolimons, read 2026-10-29 |
| Server size | 15 | Measured, Roblox games API |
| Lead developers | OsterDog and Beefchoplets | Unverified, stats-site summaries |

A 2026 30-day peak within 85% of the 2022 launch peak (Measured) is rare: Evade has held its audience for four years.

## Core loop

Spawn on a map, survive the round while chasers hunt, revive downed teammates, earn currency and XP, vote the next map. Rounds are short and the map changes every round.

## First 60 seconds

- You are running within seconds of joining. The chaser is visible from far away (a flat image face that always turns to you), so the threat is readable instantly.
- The first lesson is "never stop moving in a straight line". Sharp turns, walls and stops cost speed; wide arcs and jumps keep it (Unverified, community guides).
- A downed teammate gives the first social decision: risk your momentum to revive, or keep running.

## The craft that sets it apart

**1. Momentum movement with a skill ceiling.** Community guides describe a set of techniques that stack (Unverified): strafing in the air to gain speed, bunny hops timed at landing, slide hops that build speed faster than plain hops and work on touch screens, emote dashes, and launching off ramps. Each technique is learnable, and a master is visibly faster than a beginner. That ceiling is why players return for years and why the game is fun to watch.

**2. Movement as the counter.** The chasers are simple: they see you and come. All the depth is in how you move. **Rule of thumb:** simple enemies plus deep movement is cheaper to build and balance than complex enemies plus simple movement.

**3. Mobile-friendly tech.** Slide hopping being the easiest trick on a touchscreen (Unverified, guides) means mobile players are not locked out of the skill ladder.

**4. Revives as the social glue.** Downed players can be carried back, so a skilled player's speed becomes a gift to the team.

**5. Open maps for routing.** Maps favour wide loops around buildings and long sightlines so players can kite a chaser in circles, and ramps for launches.

## Progression and economy

- **Cosmetics, emotes and carry animations** are the long-term chase. Emotes even feed movement (emote dash), which makes cosmetic emotes feel useful without selling power.
- **Levels and currency** unlock cosmetics; no stat upgrades.

## Monetization and 2026 rules

Public passes (Measured, 2026-10-29): themed cosmetic sets at 500-600 (Eclipse, Glorp Cat, Retro, Animal, Classic Roblox, Military, Crystalline), Music Emotes Packs 500, Music Carry Packs 350, +6 Emote Slots 300, Emote Pack 350, a boombox 300.

- **Cosmetic-only store** with sets, emotes and slots. Clean and policy-safe.
- **"Limited return" set.** Rotating stock is fine when the return is honest; see [[Limited-Time Offers - Design and Ethics]].
- **Music emotes** need licensed audio; see [[Music Licensing and Audio Upload Rules for 2026]].

## Retention

- **Skill retention** (movement mastery) plus **social retention** (revives, friend squads).
- **Seasonal events** reskin maps and add event cosmetics (October 2026 title: Halloween).
- **Map rotation** keeps rounds fresh with no progression grind.

## Tech notes

- **Client-owned movement, server-checked.** Responsive momentum movement must be simulated on the client; the server checks for impossible speed and distance and logs outliers instead of rubber-banding skilled players. See [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] and [[False Positives Lag and Fair Enforcement]]. With Roblox's 2026 Server Authority, prediction plus rollback is an option; see [[Server Authority and Input Migration 2026]].
- **Speed cap thinking.** **Rule of thumb:** set the exploit threshold from your fastest legitimate technique measured in playtests, plus a margin, never from the base walk speed.
- **Chasers are cheap NPCs.** A camera-facing image and a direct chase with pathfinding fallback around obstacles; many chasers per server is affordable. See [[Pathfinding]] and [[NPC AI and Behaviour]].
- **15-player servers** keep chase density right for the map size.

## Team and cadence

A small group (Unverified). Regular event updates and cosmetic drops; the 2026 30-day peak shows events still land.

## Build it yourself

1. **Momentum controller.** Start from [[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]], [[Mover Constraints and Physics Controllers]] and [[Input Responsiveness Buffering and Coyote Time]]. Add air-strafe gain, landing-timed hop bonus and slide friction.
2. **Movement exploit check** tuned to measured legit speeds: [[Detecting Movement Exploits - Speed Fly Noclip Teleport]].
3. **Downed and revive state.** A server state machine with carry and revive timers: [[Quick Respawn and Spawn Protection]] for the respawn side.
4. **Simple chasers.** [[Horror Monster Chase AI End to End]] with the stealth parts removed.
5. **Round loop and map vote.** [[Round-Based Minigame Loop End to End]] and [[Map Voting and Rotation for Round Games]].
6. **Speed feel.** FOV widening and wind lines at high speed: [[Camera Shake and Camera FX]] and [[Chase Cameras and Speed Effects for Vehicles]] (the same tricks work on foot).

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 93.9% rating | Measured | Roblox votes API, 2026-10-29 |
| 165,296 30-day peak vs 197,261 all-time | Measured | Rolimons, read 2026-10-29 |
| 15-player servers | Measured | Roblox games API |
| Exploit speed threshold = fastest legit technique + margin | Rule of thumb | This note |

## Common mistakes when copying this style

- **Momentum that only works with a keyboard** -> give touch players at least one top-tier technique.
- **Rubber-banding fast players** -> measure legit top speed and log before you punish.
- **Smart enemies, flat movement** -> invert it: simple chasers, deep movement.
- **Closed corridors** -> open maps with loops and ramps let skill show.
- **Copying meme faces** -> use your own chaser art; image rights matter.

## Checklist

- [ ] Movement has at least three stackable techniques.
- [ ] One top technique is easy on touch.
- [ ] Exploit thresholds come from measured legit speeds.
- [ ] Revive system rewards fast players for helping.
- [ ] Maps have loops, ramps and long sightlines.
- [ ] Store is cosmetics and emotes only.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Teardown - Grace]] · [[Teardown - Phantom Forces]] · [[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Game Feel and Juice]] · [[Motion Sensitivity and Camera Comfort]]

<!-- related:start -->
## Related
[[Teardown - Apocalypse Rising 2]] · [[Teardown - Arsenal]] · [[Teardown - Piggy]] · [[Teardown - Jujutsu Shenanigans]] · [[Teardown - Dandy's World]] · [[Teardown - Pressure]] · [[Teardown - Funky Friday]] · [[Teardown - Driving Empire]]
<!-- related:end -->
