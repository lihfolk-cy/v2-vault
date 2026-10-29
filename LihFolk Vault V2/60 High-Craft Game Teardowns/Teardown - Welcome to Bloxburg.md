---
tags: [teardown, high-craft, social-sim, roleplay, building, life-sim, jobs, classic, type/case-study, area/design, level/intermediate, api/DataStore]
verified: 2026-10-29
---
# Teardown - Welcome to Bloxburg

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: A build tool without undo -> builders quit after one mistake; add undo and confirmations.
> - Avoid: Furniture kits in mixed styles -> one palette and material set so any mix looks good.
> - Avoid: Unversioned house saves -> every format change risks breaking old houses; version from day one.
> - Build mode has snapping, previews, costs and undo.
> - House data is compact, versioned and validated.
> - Houses load progressively.
>
> Cost: TL;DR ~150 tok · whole note ~2.1k tok. Read more: ## Snapshot · ## The craft that sets it apart · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Welcome to Bloxburg is a life simulation and house-building game: you build and furnish a home on your plot with a detailed building tool, work jobs in town to earn money, look after your character's needs, and roleplay with friends and family.

Trust labels: **Roblox docs**, **Measured**, **Rule of thumb**, **Unverified**. Not played for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | Bloxburg Development (group) | Measured, Roblox games API, 2026-10-29 |
| Place created | 4 November 2014 | Measured, Roblox games API |
| Visits | 10,149,306,148 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 14,033,066 | Measured, Roblox games API, 2026-10-29 |
| Rating | 88.5% | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 7,774 | Measured, Roblox games API, 2026-10-29 |
| All-time peak CCU | 592,451 on 28 June 2025 | Measured, Rolimons, read 2026-10-29 |
| Competing claim | "over 900,000" at the June 2025 launch | Unverified, RoWatcher news; conflicts with the Rolimons figure |
| Average session | about 25.5 minutes | Measured, Rolimons |
| Server size | 12 | Measured, Roblox games API |
| Free to play | since 15 June 2024, after nearly 10 years at 25 Robux paid access | Unverified, Bloxy News on X, 15 June 2024 (no price today is Measured) |
| Ownership | studio and game acquired by Embracer Group in 2022 (publishing arm Coffee Stain); price not officially confirmed | Unverified, Pocket Tactics and Sportskeeda, 2022 |
| June 2025 update | Version 1.0.0 map revamp with a live meteor event, new neighbourhoods and a mountain area | Unverified, Sportskeeda guide and RoWatcher |

The peak arriving more than a decade after creation, on the day of a big map revamp, is the lesson: a deep, polished sandbox can be relaunched.

## Core loop

1. Build or edit your house on your plot.
2. Work a job in town (cashier, delivery, mechanic and others) through a short repeating minigame.
3. Earn money; spend it on building materials, furniture, vehicles and upgrades.
4. Manage needs (hunger, hygiene, energy, fun) that drive the life-sim rhythm.
5. Roleplay with friends, visit others' houses.

## First 60 seconds

- You spawn at your plot with a starter house and the build tool one button away.
- A first job is a short walk or drive; the first paycheck arrives within minutes.
- **Rule of thumb:** a sandbox needs one guaranteed quick win (a first paycheck) and one creative invitation (the build button) in the first minute.

## The craft that sets it apart

**1. The building tool is the product.** Wall drawing, floors, roofs, windows and doors placed into walls, paint per surface, furniture rotation and fine placement, multiple floors and basements (several are sold as passes, Measured). Each feature is precise and forgiving: snapping, undo, previews and clear costs. See [[Grid Placement and Player Building Systems]] and [[Confirmation and Undo Patterns for Destructive and Paid Actions]].

**2. A consistent, warm art direction.** Clean, slightly stylised furniture and materials that look good together whatever the player picks. **Rule of thumb:** in a building game, the art kit must make any combination look decent; ugly combinations are your fault, not the player's.

**3. Jobs as rhythm minigames.** Short, repeatable job loops with clear performance feedback teach patience and reward focus without combat.

**4. Needs that create routine.** Hunger and energy push players to use rooms they built (kitchen, bedroom), which makes the house functional, not just decorative.

**5. Long session design.** A 25.5-minute average session (Measured, the longest of the games in this section apart from tower defense) shows a sandbox players settle into.

## Progression and economy

- **Money from jobs** buys furniture and building; job levels raise pay.
- **Skills** (cooking, gardening and others) level through use.
- **Expensive houses** are the status goal. House value is visible to visitors.

## Monetization and 2026 rules

Public passes (Measured, 2026-10-29): Transform Plus 600, Multiple Floors 360, Premium 300, Excellent Employee 300, Advanced Placing 250, Large Plot 250, Marvelous Mood 180, Basements 100.

- **Feature passes for builders** (floors, basements, larger plots, advanced placement): sell creative capacity, not status over other players.
- **Removing paid access** (2024, Unverified) widened the funnel while passes carried monetization. See [[Monetization Overview]] and [[Game Passes]].
- **Roleplay and chat** are subject to age-based chat rules: [[Policy and Age Rules 2026]] and [[Age Checks and Safety Features]].

## Retention

- **Self-directed goals** (the dream house) that never end.
- **Seasonal decorations and events.**
- **A rare big relaunch** (the 2025 map revamp) that brought a peak (Measured).
- **Social visiting** and family roleplay.

## Tech notes

- **Saving complex houses.** A house can contain thousands of objects. Serialise compactly (ids, grid positions, rotations, colour indexes), version the format and keep it within DataStore limits. See [[Serialization Formats for Saves and Networking]], [[DataStore Fundamentals]] and [[Saved Inventory End to End]].
- **Loading houses on join.** Stream in the player's house progressively; prioritise exterior first: [[Instance Streaming]].
- **12-player servers** keep 12 detailed houses within memory budgets on phones: [[Memory Budgets and Leaks]] and [[Mobile and Low-End Optimization]].
- **Placement validation on the server** (plot bounds, overlap, cost): [[Grid Placement and Player Building Systems]].

## Team and cadence

Created by a solo developer, later part of a larger publisher with a dedicated team (Unverified, press). Slow, careful updates; a 1.0 milestone in 2025 after more than ten years.

## Build it yourself

1. **Wall-draw build mode** with grid snapping, previews, costs and undo: [[Grid Placement and Player Building Systems]] and [[Drag-and-Drop Inventories and Sliders with UIDragDetector]].
2. **House serialisation** with versioning: [[DataStore Fundamentals]] and the `lihfolk:roblox-datastore-safety` skill.
3. **Jobs as minigames:** [[Weekend Build - Roleplay Town with Jobs and Paychecks]].
4. **Needs system:** decaying stats that rooms restore.
5. **Instanced interiors** if many players share space: [[Instanced Interiors - Pooled House and Room Copies for Many Players]].
6. **Modular furniture kit** with one material palette: [[Modular Environment Kits]] and [[House Construction Method - Modular Kit Workflow]].

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 592,451 peak CCU, 28 Jun 2025 | Measured | Rolimons, read 2026-10-29 |
| 25.5-minute average session | Measured | Rolimons, read 2026-10-29 |
| 14,033,066 favourites | Measured | Roblox games API, 2026-10-29 |
| 900K+ June 2025 claim | Unverified | RoWatcher news |

## Common mistakes when copying this style

- **A build tool without undo** -> builders quit after one mistake; add undo and confirmations.
- **Furniture kits in mixed styles** -> one palette and material set so any mix looks good.
- **Unversioned house saves** -> every format change risks breaking old houses; version from day one.
- **Selling status** -> sell building capacity and comfort, not superiority.
- **Huge servers with detailed houses** -> keep servers small or instance interiors.

## Checklist

- [ ] Build mode has snapping, previews, costs and undo.
- [ ] House data is compact, versioned and validated.
- [ ] Houses load progressively.
- [ ] Jobs give a first paycheck within minutes.
- [ ] Art kit looks good in any combination.
- [ ] Chat and roleplay follow current age rules.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Case Study - Brookhaven RP]] · [[Case Study - Adopt Me]] · [[Genre Playbook - Roleplay and Social Hangouts]] · [[Genre Playbook - Tycoons]]

<!-- related:start -->
## Related
[[Teardown - Apocalypse Rising 2]] · [[Teardown - Driving Empire]] · [[Teardown - Anime Vanguards]] · [[Teardown - Grace]] · [[Teardown - BedWars]] · [[Teardown - Piggy]] · [[Teardown - Arsenal]] · [[Teardown - Phantom Forces]]
<!-- related:end -->
