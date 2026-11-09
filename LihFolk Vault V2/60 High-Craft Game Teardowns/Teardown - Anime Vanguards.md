---
tags: [teardown, high-craft, tower-defense, strategy, anime, gacha, units, live-ops, type/case-study, area/design, level/intermediate, area/liveops]
verified: 2026-10-29
---
# Teardown - Anime Vanguards

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Summons without numeric odds -> show every outcome's odds before purchase, including modifiers.
> - Avoid: A luck pass that hides its effect -> show the resulting odds while it is active.
> - Avoid: Physics-driven enemies -> path interpolation is cheaper and deterministic.
> - Odds shown for every paid random roll, with modifiers applied.
> - Restricted players get non-random alternatives.
> - Enemies move along data paths.
>
> Cost: TL;DR ~150 tok · whole note ~2.1k tok. Read more: ## Snapshot · ## The craft that sets it apart · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Anime Vanguards is an anime-themed tower defense game: you collect units (characters with attack patterns), place and upgrade them along a path to stop waves of enemies, and progress through story stages, challenges and raids alone or with others.

Trust labels: **Roblox docs**, **Measured**, **Rule of thumb**, **Unverified**. Not played for this note. For tower defense basics see [[Case Study - Tower Defense Simulator]]; this note covers what Vanguards adds.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | Kitawari (group) | Measured, Roblox games API, 2026-10-29 |
| Place created | 28 January 2024 | Measured, Roblox games API |
| Release | 8 September 2024 | Unverified, community wiki (vanguards.gg) |
| Visits | 2,098,739,417 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 2,009,557 | Measured, Roblox games API, 2026-10-29 |
| Rating | 96.7% (2,598,726 up / 88,184 down) | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 13,560 | Measured, Roblox games API, 2026-10-29 |
| All-time peak CCU | 340,167 on 14 September 2024 (launch week) | Measured, Rolimons, read 2026-10-29 |
| 30-day peak | 84,510 | Measured, Rolimons |
| Average session | about 48.2 minutes | Measured, Rolimons, read 2026-10-29 |
| Server size | 24 | Measured, Roblox games API |
| Units | over 200 | Unverified, fan encyclopedia, 2026 |
| Anniversary | a 2nd Anniversary event ran 9-12 October 2026; the larger anniversary update had no official date at check | Unverified, AllThingsHow, Oct 2026 |

A 96.7% rating on 2.7 million votes is the highest in this section, and a 48-minute average session is the longest.

## Core loop

1. Summon or earn units; build a team of six or so (team size Unverified).
2. Pick a stage or mode; place units on the map, upgrade them as money flows in during the match.
3. Beat waves and bosses; earn currency, items and materials.
4. Upgrade, evolve and trait-roll units; push harder stages.

## First 60 seconds

- A guided first summon gives a playable team immediately.
- The first stage is easy and teaches placement, upgrading and selling.
- **Rule of thumb:** in a collection strategy game, the first minute must deliver one unit you love and one win; depth comes later.

## The craft that sets it apart

**1. Polish of unit presentation.** Units have strong attack animations and effects that read on a crowded path. Area shapes (circles, cones, lines) are shown on placement so players can plan. See [[VFX Readability and Value - Lessons from Blind Reviews]].

**2. Information-rich UI.** Damage, range, attack speed, upgrade costs and enemy health are visible without clutter. Strategy games live or die on information design. See [[Readable Text and UI Scale]] and [[Responsive UI for Phone Tablet Console and PC]].

**3. Mode ladder.** Story, challenges, raids, events and infinite modes reuse units and maps with new rules.

**4. Rapid response to players.** The very high rating suggests a team that listens and ships fixes (Rule of thumb, no direct source). Developer code drops nearly every day during an anniversary week (Unverified) show tight community contact.

**5. Long sessions by design.** Matches are longer than in action games; idle stretches while waves run are filled with planning and upgrades.

## Progression and economy

- **Unit collection** with rarities up to a top tier (Unverified naming).
- **Traits, evolutions and shiny variants** add chase layers (a "Shiny Hunter" pass exists, Measured).
- **Materials from modes** feed upgrades, which pulls players through every mode.
- See [[Drop Tables Rarity and Pity Systems]] and [[Rarity Ladders and Drop Pacing Math]].

## Monetization and 2026 rules

Public passes (Measured, 2026-10-29): Shiny Hunter 1,299, Cosmetic Recolor 799, Display All Units 599, VIP 299, Extra Unit Storage 149.

- **Summons are paid random items** when bought with Robux or with currency that can be bought with Robux. Roblox's rules (clarified May 2026) require numeric odds for every outcome before purchase and alternatives for restricted users. A pass that changes shiny chances must show the resulting odds. Read [[Paid Random Items and Odds Disclosure in Practice]], [[Regional Compliance - Paid Random Items and Country Rules]] and [[Policy and Age Rules 2026]], and run the `lihfolk:roblox-monetization-compliance` skill.
- **Pity systems** must be disclosed as a moving target: see the pity section of the odds note.
- **Storage and display passes** sell convenience.

## Retention

- **Large numbered updates** with new units, maps and modes, plus events between (an "Update 15" tier list exists, Unverified).
- **Anniversary events** and code drops.
- **Meta shifts** from new units keep collectors and strategists engaged.

## Tech notes

- **Enemy movement along a path** as data, not physics: interpolate along waypoints on the server, replicate compactly to clients. See [[Tower Defense Waves and Placement End to End]].
- **Many units firing** needs server-side targeting with spatial queries and client-side effects: [[Raycasts Shapecasts and Spatial Queries]].
- **Effect budgets.** 24-player servers with co-op matches; cap concurrent VFX and cut layers on low-end devices: [[Juice on a Budget - Mobile and Low-End]].
- **Roll logic on the server only,** with odds from the same table the UI displays: [[Paid Random Items and Odds Disclosure in Practice]].
- **Unit inventory saves** with versioning and trade safety: [[Saved Inventory End to End]] and [[Trading Systems Without Duplication]].

## Team and cadence

Kitawari group; owner and former owner named on a fan wiki (Unverified). Major updates roughly every few months with events between (Unverified).

## Build it yourself

1. **Path and waves:** [[Tower Defense Waves and Placement End to End]] and [[Genre Playbook - Tower Defense]].
2. **Unit data sheet** (damage, range, cooldown, upgrade path): [[Balancing with Spreadsheets and Data]].
3. **Placement preview** with range shapes and valid-spot highlighting: [[Grid Placement and Player Building Systems]].
4. **Summon with disclosed odds and pity:** [[Drop Tables Rarity and Pity Systems]].
5. **Unit attack VFX** with readable shapes: the `lihfolk:lihfolk-vfx` skill and [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]].
6. **Mode ladder** reusing units: [[Progression and Pacing Design]].

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 96.7% rating | Measured | Roblox votes API, 2026-10-29 |
| 48.2-minute average session | Measured | Rolimons, read 2026-10-29 |
| 340,167 peak CCU, 14 Sep 2024 | Measured | Rolimons, read 2026-10-29 |
| Shiny Hunter pass 1,299 Robux | Measured | Roblox game-passes API, 2026-10-29 |

## Common mistakes when copying this style

- **Summons without numeric odds** -> show every outcome's odds before purchase, including modifiers.
- **A luck pass that hides its effect** -> show the resulting odds while it is active.
- **Physics-driven enemies** -> path interpolation is cheaper and deterministic.
- **Effects that hide the path** -> the enemy and its health must always be readable.
- **Using real anime characters** -> design original characters; anime is a style, not a licence.

## Checklist

- [ ] Odds shown for every paid random roll, with modifiers applied.
- [ ] Restricted players get non-random alternatives.
- [ ] Enemies move along data paths.
- [ ] Unit stats live in one sheet.
- [ ] Placement shows range and valid spots.
- [ ] VFX capped per server and per device tier.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Case Study - Tower Defense Simulator]] · [[Teardown - Jujutsu Shenanigans]] · [[Genre Playbook - RNG and Collection Games]] · [[Paid Random Items]]

<!-- related:start -->
## Related
[[Teardown - Blade Ball]] · [[Teardown - Apocalypse Rising 2]] · [[Teardown - Piggy]] · [[Teardown - Plants vs Brainrots]] · [[Teardown - Grace]] · [[Teardown - Phantom Forces]] · [[Teardown - BedWars]] · [[Teardown - Deepwoken]] · [[Teardown - Welcome to Bloxburg]]
<!-- related:end -->
