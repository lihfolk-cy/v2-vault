---
tags: [production, post-mortem, case-study, combat, rng, retrospective]
---
# Post-Mortem: Building a Melee Action Game

<!-- tldr:start -->
> [!tldr] TL;DR
> - Obtain weapons of rising rarity, with luck multipliers stacking from several sources.
> - Week 1: a vertical slice and a play-test cadence.
> - The reference project shipped an enormous amount of content quickly because its pipelines were good and its verification was...
>
> Read more (12 KB note): ## What went right · ## What went wrong
<!-- tldr:end -->

This is a post-mortem in the classic format (what went right, what went wrong, the numbers) for one live action game on Roblox: a melee game with collectible weapons of rising rarity, zones of enemies, crafting and bosses. The project is anonymised; it is called "the reference project" elsewhere in this vault. All figures are measured from the project's own notes unless marked otherwise.

The project is unusual in one way: it was built very fast, by an owner directing several parallel workstreams (most of them AI-assisted) in one shared Studio place. That speed makes it a good case study, because a few weeks contained the kind of scope swings, technical debt and recoveries that usually take a year.

## The game in one paragraph

Obtain weapons of rising rarity, with luck multipliers stacking from several sources. Equip one: a flourish plays. Fight in zones with a combo, dash, block and parry, and a handful of abilities (more for rarer weapons, with a cinematic ultimate). Collect currency and crafting materials. Craft and upgrade gear, do daily and weekly quests. Unlock new zones and beat bosses to progress to later content.

## Project at a glance

| Metric | Value |
|---|---|
| Calendar time covered | a few weeks |
| Parallel workstreams at peak | about 5, plus many short-lived helper sessions |
| Weapons | well over a hundred, across a long rarity ladder, all rebuilt to a new art standard |
| Ability kits | about a hundred kits / several hundred moves, still growing |
| Kit move clips | several hundred (all later baked to compact stubs) |
| Enemy clips | well over a thousand across dozens of enemy kits |
| Enemy creatures (first area) | about fifty slots, every model redesigned in one day near the end |
| Zones | a full first area live, a second area in progress |
| Place size peak | about 2.36 million instances (first week) |
| ReplicatedStorage (downloaded by every client) | 392k to 107k instances, later about 70k |
| Script at the Source limit | 3 core scripts between 192k and 201k characters |
| Data resets | 3 store-version bumps |

## What went right

### 1. Pipelines turned content into a repeatable process

By week 3, adding a fully animated weapon (rig, effects, icon, voice, config, lore, a multi-move kit with arm-animation baking and QA) took about 1 to 1.5 hours, most of it creative design (measured). Enemy imports, armour sets and map kits had similar pipelines: a source script in Blender, an upload with an id map, a Studio installer with dry run and undo, and a numeric verifier. The proof of the investment came at the end: about fifty enemy looks were replaced in one day while every slot kept its id, skeleton, clips, AI and attacks, with a fit error of 0.000 on every rig. See [[Asset Pipelines]].

### 2. Numbers-first verification

Because the owner did all play-testing, the builders verified with numbers: raycast grids for wall holes ("0 leaks on every gate"), arm-QA scores per animation (minimum 80 with zero criticals), overlap counts for UI at five viewport sizes, deep-equal comparisons for refactors, instance counts for cleanups. These checks caught real problems (a phone layout skipped because of an `ipairs` stop at a nil, zero-triangle meshes, a grip moved down a chain) before a player could. See [[Working with AI Assistants in Studio]].

### 3. Data-driven systems survived redesigns

Enemies were data (attacks, timings, telegraphs, phases) plus models plus clips. When a whole staging map was deleted, its enemies and bosses moved onto the original zones in one evening with a new spawn table, because nothing about them depended on the map. Ability kits followed a shared framework (tiered damage multipliers, a shared slot-1 ability, an ultimate contract with pull-before-damage and a camera anchor), which let around a hundred kits be upgraded in waves.

### 4. The strangler hand-over from old combat to new

The old enemy system lived in one script at 199.6k of 200k characters. Instead of rewriting it, the new enemy service took zones over one at a time: the old loop skipped any zone whose workspace flag was set, and the new service set the flag only after a successful init. Rewards still went through the old payload format, so economy and quests needed no change. See [[Case Study - Enemy Roster Rebuild]].

### 5. Instance discipline, eventually

The place went from about 2.36 million instances to well under a million through archiving, evidence-based deletion, and replacing keyframe-heavy animation data with compact binary stubs. ReplicatedStorage, which every client downloads before the game is loaded, dropped from 392k to 107k and then to about 70k instances (measured). See [[Case Study - Instance Cleanup and Place Size]] and [[Case Study - Cutting a Million Instances]].

### 6. Phones were treated as first-class, late but properly

A phone layout framework (one scale rule, minimum tap and text sizes, a harness that lays out every screen off-screen at two phone resolutions and counts problems) took the UI from "zoom the desktop panel and let players pan" to real phone layouts for about two dozen screens with zero overlaps. See [[Case Study - Phone UI Overhaul]].

## What went wrong

### 1. Scope churn on the map

The map direction changed at least six times in a few weeks: one themed area built twice then deleted (about 19k instances and about 21 million terrain cells of voxels removed); a much longer zone ladder planned; a large multi-area staging map built, rebuilt shorter, then deleted; a lobby replaced and reverted the same day; a linear stage-corridor redesign built in a day and reverted; zones shrunk to 40% length and restored. Each idea had a reason (players running too long, players quitting at bosses). Together they consumed perhaps a third of map effort for no shipped result. **Lesson:** settle pacing targets in player minutes and test one zone against them before redesigning the world. See [[Planning and Scoping a Roblox Game]].

### 2. Verification debt: "Edit only, not play-tested"

By the end of the period the project notes carried a standing line: nothing since a date about halfway through was play-tested. Hundreds of entries said "Edit only". Some bugs only a play-test would find did ship into the Studio build for days: enemies doing almost no damage (player health scaled with weapon rarity, enemy damage did not, so 40 to 100+ hits to die), a menu click that froze the client (an unbounded `while true` loop waiting for a parent that had been destroyed), sprint blocked after closing a menu. **Lesson:** play-testing is a scheduled role, not a favour. See [[Multi-Client and Live Testing]].

### 3. Studio-only features looked finished

Weapon-part animations in dozens of kits used runtime-registered keyframe sequences, which only work in Studio. In a live server those parts would have stood still. Hundreds of other clips stayed unpublished for weeks, listed as "publish before live". The fix was a Lua keyframe player that reads baked data, making publishing unnecessary for those clips. **Lesson:** grep for Studio-only calls in every release check. See [[Case Study - Abilities That Only Worked in Studio]].

### 4. Backups inside the place became the performance problem

Early rules said "never delete, set aside in a storage folder" and "keep one safety copy per pass". By week 3 the place was 1.07 million instances and Studio ran at about 15 fps using about 18 GB; one backup folder alone held about half a million instances. Every in-place backup was purged in one pass (about 1.07M to about 600K). Afterwards, script comments still pointed at deleted backups, and some reverts had no path left. **Lesson:** record undo data as attributes and on disk; rely on version history for the rest. See [[Safe Changes in a Shared Place]].

### 5. Shared undo and shared terrain

A session used Studio undo to recover a terrain mistake; the undo went about 40 waypoints back and rolled back other sessions' work. A full terrain regeneration overwrote other work. Cliff positions were deleted without a backup and the only autosave predated the layout, so hundreds of rock placements were rebuilt from scratch. **Lesson:** never undo in a shared place; snapshot before terrain writes.

### 6. God scripts at the size limit

The original combat script hit 199.9k of the 200k Source limit and became untouchable ("never edit it; extend through the API module"). Later the main config module and the UI theme module (each just over 201k) crossed the limit, which meant they could not be saved at all until split into child modules. A tutorial controller hit the 200-local-variable limit. **Lesson:** budget module size; split by responsibility early. See [[Module Scripts and Requiring]].

### 7. Tuning by feel without a model

Enemy size went 2.3x, then 30% smaller, then a new base scale 1.0 to 1.6 to 2.1, with mega and boss multipliers changed alongside; spawn density was cut to 0.55 of its previous value; weapons' power bands were rebuilt so tiers did not overlap (about 2.5x per tier); progression was made about 2x slower with a data wipe; the reward reveal time went from a couple of seconds to about four times longer. Several of these were reasonable responses to feedback, but they were not derived from shared targets, so each change created the next. **Lesson:** write targets (time to kill, time per zone, minutes of income per upgrade) and derive the numbers. See [[Balancing with Spreadsheets and Data]].

### 8. Join time was discovered late

ReplicatedStorage replicates in full before `game.Loaded`. At over 100k instances (character models about a third, kit folders about 40%) joins were slow, and a new main menu only hid the wait. Fixes came late: baking, deferring non-essential kits out of ReplicatedStorage, tighter streaming, and join-time telemetry. **Lesson:** measure join time from week 1. See [[Case Study - Fast Join and Deferred Loading]].

## Technical lessons in brief

| Lesson | Detail |
|---|---|
| `require` in the command bar is cached | Clone-require to see edits |
| Keyframe instances dominate instance counts | Bake to binary buffers in attributes |
| Terrain colours are global per material | Repaint with another material, but only Grass grows grass blades |
| Edit mode cannot run physics, rate emitters or ViewportFrame animation | Verify those in Play |
| Forbidden names | A clip named like a sibling RemoteEvent replaced it in lookups and broke a kit's damage |
| Sandboxed toolbox scripts | A copied nametag script could not require the config module |
| Weighted picks | A first-hit walk over a sorted list made a "1 in 3" item drop at about 1 in 370 |
| `ipairs` stops at the first nil | A list built with `FindFirstChild` results silently dropped later pages |

## What we would do differently

1. **Week 1: a vertical slice and a play-test cadence.** One zone, one enemy per role, one weapon of each rarity band, played by the owner twice a week.
2. **Pacing targets in minutes before any map work.**
3. **No backups in the place, ever.** Attributes and disk from day 1.
4. **A module size budget** (rule of thumb: split at 100k characters) and a responsibility per module.
5. **A release every few days behind flags**, with a pre-release grep for Studio-only calls.
6. **Join-time telemetry from the first publish.**
7. **One owner per hot file**, with a written insert protocol.

## Conclusion

The reference project shipped an enormous amount of content quickly because its pipelines were good and its verification was numeric. It lost time to scope churn, to verification debt, and to treating the place as its own backup system. The transferable lesson is that speed of building is no longer the bottleneck on Roblox; deciding, testing and releasing are. Plan those with the same care as the code.

## See also

- [[Planning and Scoping a Roblox Game]], [[Team Roles and Workflows]], [[Release Process and Rollbacks]]
- [[Case Study - Phone UI Overhaul]], [[Case Study - Instance Cleanup and Place Size]], [[Case Study - Fast Join and Deferred Loading]], [[Case Study - Enemy Roster Rebuild]]
- [[Case Study - Fixing Hundreds of Attack Clips]], [[Case Study - Cutting a Million Instances]] (Animation section)
- [[Genre Playbook - Combat and RPG]], [[Genre Playbook - RNG and Collection Games]]
- [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Case Study - Building a Game with AI Agents]] · [[Baked Clip Stubs and Archiving]] · [[Documentation and Knowledge Bases]] · [[Version History and Backups]] · [[AI Agents and Autonomous Workflows]] · [[Pipeline Design Principles]]
<!-- auto-links:end -->
