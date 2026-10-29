---
tags: [teardown, high-craft, horror, co-op, character-roster, art-direction, stealth, alpha, type/case-study, area/design, level/intermediate, area/world]
verified: 2026-10-29
---
# Teardown - Dandy's World

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Many characters, many art styles -> one owner of style, one base shape, one trait each.
> - Avoid: Characters with only stat differences -> each needs an ability that changes how you play the floor.
> - Avoid: Skill checks that punish only the player who failed -> make the cost shared (noise), so the team cares and helps.
> - One base character design with a trait system.
> - Every playable character has a distinct ability.
> - Skill check failure has a readable, shared cost.
>
> Cost: TL;DR ~160 tok · whole note ~2.4k tok. Read more: ## Snapshot · ## The craft that sets it apart · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Dandy's World is a co-op cartoon-horror survival game: a team of playable "Toons" rides an elevator down through floors of a gloomy shopping-centre attraction, fills machines with Ichor while monstrous "Twisted" versions of the Toons roam, and races back to the elevator before it leaves.

Trust labels: **Roblox docs** (includes Roblox's own DevForum Creator Spotlight), **Measured**, **Rule of thumb**, **Unverified**. Not played for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | BlushCrunch Studio, led by Qwelver (primary designer and artist) | Roblox docs, DevForum Creator Spotlight, 5 May 2025 |
| Place created | 26 January 2024; alpha launch June 2024 | Measured (creation), Roblox docs (alpha month) |
| Visits | 7,814,996,186 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 4,758,538 | Measured, Roblox games API, 2026-10-29 |
| Rating | 87.9% | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 53,632 | Measured, Roblox games API, 2026-10-29 (Halloween event week) |
| Peak CCU | 875K "during the first Easter event" | Roblox docs, Creator Spotlight, 5 May 2025 |
| Tracker peak | 866,577 on 18 April 2025; 30-day peak 498,794 | Measured, Rolimons, read 2026-10-29 |
| Server size | 35 | Measured, Roblox games API |
| Roster | 33 Toons and 33 Twisteds; main setting has 19 floors | Roblox docs, Creator Spotlight, May 2025 (counts will have grown) |
| Original CCU goal | 1,000 | Roblox docs, Creator Spotlight |

A nearly 500K 30-day peak in October 2026 means this is a current leader, not a 2025 spike.

## Core loop

1. Pick a Toon in the lobby (each has stats such as speed, stealth, extraction and stamina, and an ability; Unverified, guides).
2. Ride down. The floor layout, machine positions, items and Twisted mix vary (Roblox docs, Creator Spotlight).
3. Work machines. Extraction includes a timing skill check; a miss makes noise and draws Twisteds (Unverified, guides).
4. When every machine is done, the elevator opens briefly; anyone not inside in time is lost (Unverified, guides).
5. Earn Ichor to unlock Toons, trinkets and skins. Shops appear between floors (Unverified).

## First 60 seconds

- You do not play as your Roblox avatar; you pick a character (Roblox docs, Creator Spotlight calls this a risk that paid off). The character select is the first "wow": dozens of distinct, hand-designed mascots.
- The first floor is dim and slow. The first thing you learn is the skill check, a simple timing bar, and its cost on failure (noise). **Rule of thumb:** teach the cost of a mistake before the threat arrives, so the first chase feels fair.

## The craft that sets it apart

**1. Character design as the core system.** Every Toon is built from the same flower-shopkeeper design language with one added trait (a TV head, a moon, an ammonite), and every Toon has a Twisted counterpart (Roblox docs). One design produces two assets: a playable hero and a threat. Players form attachments to characters, which drives fan art, video and cosmetic sales.

**2. A designer-artist owning all art.** Qwelver oversees all artwork to keep one visual style (Roblox docs). The shape language, palette and line weight stay coherent across 60+ characters. That consistency is why the game is recognisable from a single frame.

**3. Lighting as wayfinding.** Point lights pull players into areas; one themed floor uses fossil exhibits and soft yellow light for a sandy feel (Roblox docs). In a stealth game, light tells you where to go and where you will be seen.

**4. Co-op without griefing.** There are no rewards for harming other players; the game is designed to be collaborative (Roblox docs). Abilities support each other: distract, heal, extract faster, scout.

**5. Small skill expression in a social game.** The timing bar gives every player, including young ones, a moment of skill that matters to the team. Missing it is a shared problem, not a solo failure.

**6. Floor modifiers.** Blackouts and puddle events that slow movement and shrink skill checks (Unverified, guides) re-tune familiar floors without new art.

## Progression and economy

- **Ichor** is extracted, spent and earned in one word, which keeps the economy legible for kids.
- **Unlockable roster** is the long-term goal: a character collection where each unlock changes how you play.
- **Trinkets** add build variety without raw stat inflation (Unverified detail).

## Monetization and 2026 rules

Public passes (Measured, 2026-10-29): Queens of Mischief Cosmetic Bundle 700; Spooky-Time, Star-Time and Show-Time Cosmetic Packs 200 each; +2 Sticker Wheels 199; profile bundles 100; several seasonal skins listed but off sale.

- **Seasonal cosmetic packs** that go off sale are a time-limited offer. Keep them honest: show the end date, never fake scarcity. See [[Limited-Time Offers - Design and Ethics]].
- **No paid power in a co-op game** keeps parties welcoming.
- **Young audience.** A cartoon look attracts younger players, so check [[Policy and Age Rules 2026]], [[Marketing to Kids and Teens - Age Rules and Paid-Promo Disclosure]] and [[Age Checks and Safety Features]].

## Retention

- **Holiday events** (Easter, Christmas, Halloween) with themed floors; the Christmas floor was built from requests for larger floors (Roblox docs).
- **Visible community influence.** A character's ability was buffed after feedback, and older floors are being revised (Roblox docs). Players see their requests ship.
- **Alpha label kept on the title** sets expectations: change is normal, which makes rebalances easier to accept.

## Tech notes

- **35-player servers** with smaller teams per run (team size Unverified): lobby and run share a place or teleport; see [[Lobby and Hub Design]].
- **Floor spawn tables.** Each floor has its own spawn points for Twisteds, items and machines (Roblox docs). Author spawn sockets, then randomise which are active.
- **Stealth detection** needs a server-side radius per Twisted modified by the Toon's stealth stat and current action (crouch, run, failed check). See [[NPC AI and Behaviour]] and [[Behaviour Trees Utility AI and State Machines for NPCs]].
- **Many unique characters, one rig.** Toons share a rig and animation set where possible; unique silhouettes come from meshes and accessories. See [[Character Select and Class Systems with Different Rigs]].

## Team and cadence

Led by one designer-artist with a team that playtests every release (Roblox docs). Qwelver spent a couple of years building skills and a smaller tower defense project before this game (Roblox docs). Event-paced updates at holidays.

## Build it yourself

1. **Character roster with paired villains.** One base design language, one trait per character, a twisted variant per hero. Use [[Shape Language and Silhouette Testing]] and [[Style Bibles for Consistent Models]].
2. **Machine skill check.** A timing bar UI with a noise event on failure. See [[UI Motion Language and Timing]] and [[Feedback Timing - Sound Visual and Haptic Sync]].
3. **Noise-based detection.** Server events raise a noise value at a position; Twisteds within range investigate. [[Horror Monster Chase AI End to End]].
4. **Elevator exit timer.** A closing window after the last machine: [[Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars]].
5. **Floor modifiers** as data rows: lighting off, slow zones, smaller skill checks. [[Lighting Mood and Time of Day]].
6. **Feedback loop.** Public patch notes that name the request that drove a change: [[Patch Notes and Player Communication]].

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 875K peak CCU (first Easter event) | Roblox docs | Creator Spotlight, 5 May 2025 |
| 498,794 30-day peak | Measured | Rolimons, read 2026-10-29 |
| 33 Toons and 33 Twisteds (May 2025) | Roblox docs | Creator Spotlight |
| Goal was 1,000 CCU | Roblox docs | Creator Spotlight |

## Common mistakes when copying this style

- **Many characters, many art styles** -> one owner of style, one base shape, one trait each.
- **Characters with only stat differences** -> each needs an ability that changes how you play the floor.
- **Skill checks that punish only the player who failed** -> make the cost shared (noise), so the team cares and helps.
- **Rewarding griefing** -> no rewards for harming teammates.
- **Copying the mascots** -> design your own base character first; the roster grows from it.

## Checklist

- [ ] One base character design with a trait system.
- [ ] Every playable character has a distinct ability.
- [ ] Skill check failure has a readable, shared cost.
- [ ] Lighting guides players and signals danger zones.
- [ ] Floor modifiers are data, not new art.
- [ ] Seasonal cosmetics show honest end dates.
- [ ] Community feedback is visibly acted on in patch notes.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Teardown - Pressure]] · [[Teardown - Piggy]] · [[Case Study - Forsaken]] · [[Genre Playbook - Horror and Story]] · [[Community Building]]

<!-- related:start -->
## Related
[[Teardown - Grace]] · [[Teardown - Evade]] · [[Teardown - Anime Vanguards]] · [[Teardown - BedWars]] · [[Teardown - Jujutsu Shenanigans]] · [[Teardown - Blade Ball]] · [[Teardown - Apocalypse Rising 2]] · [[Teardown - Arsenal]]
<!-- related:end -->
