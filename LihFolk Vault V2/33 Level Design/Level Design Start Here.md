---
cssclasses: [vault-hub]
tags: [index, start, level-design, type/hub, area/world, level/beginner, api/Terrain, area/design]
---
# Level Design Start Here

This section goes deeper into level design than the broad overview in [[Level Design for Roblox]], which you should read first. The six notes here each take one part of that ground and go past the basics: the maths behind a jump or a telegraph, the edge cases of a safe zone, the order in which players read a space, and scripts that measure or check a level instead of trusting a feeling.

Facts are labelled "Roblox docs (as of October 2026)", "measured in the reference project" (one live action game with a hub, multi-zone realms, a PvP colosseum and event arenas), "computed" (worked from documented defaults) or "rule of thumb". Code is strict Luau, reviewed but not run in that exact form.

## The notes

1. [[Level Design Principles - Flow Sightlines and Landmarks]]: the order in which players read a space, Lynch's five elements as a level checklist, compression and release, thresholds, field of view by device, how big a landmark looks at a distance (with a pixel calculator), landmarks across streaming, and a position heatmap for measuring flow.
2. [[Lobby and Hub Design]]: ranking a hub's jobs, time budgets from spawn, drawing first-time, return and loiter flows, sizing for the typical player count, prompt line of sight and spacing, queue pads polled with spatial queries and teleported in groups, portals that stream first, returning-player options, and the hub's performance budget.
3. [[Obby and Platforming Level Design]]: the jump arc worked out for both jump modes, reach tables for jumping up and down, difficulty as separate dials, success-rate maths for chains, an obstacle vocabulary, hazards driven by a shared clock, camera and depth problems, modular stages with entry and exit attachments, and a stage validator.
4. [[Combat Arena and Encounter Layout]]: sizing arenas from the dodge test, cover heights against the third-person camera, cover and pathfinding, enemy entry and a spawn picker that avoids players' view, waves, containment and safe arena seals, telegraph readability, and fair PvP layouts with spawn alcoves.
5. [[Teaching Through Level Design]]: a visual language with an audit script, the show-try-test-combine sequence, gating with geometry instead of UI, direction without arrows, stuck detection with escalating hints, device-aware teaching, and a spatial onboarding funnel built on trigger volumes.
6. [[Spawn Points Safe Zones and Respawn Flow]]: respawn as a timed pipeline, owning character loading, choosing spots by context and safety, spawn protection abuse rules, safe zones with hysteresis and combat tags, three layers of fall recovery with per-zone thresholds, streaming during the death presentation, and a complete respawn service with a watchdog.

## Suggested reading order

- **Building a hub or lobby:** 1, 2, then 6.
- **Building an obby or platformer:** 3, then 5 and 6.
- **Building a combat game:** 1, 4, 6, then 5 for teaching new enemies and abilities.
- **Fixing a tutorial that loses players:** 5, then [[First-Time User Experience and Onboarding]].

## Related notes elsewhere in the vault

- Overview and production lessons: [[Level Design for Roblox]], [[Environment and Level Pipeline]], [[Modular Environment Kits]], [[Zone and Biome Art Direction]], [[Environment Art Styles]].
- Case studies from the reference project: [[Lobby and Hub Design]], [[Boss Fight Design Patterns]], [[Progression and Pacing Design]], [[Roadmaps Milestones and Scope Control]].
- Genres: [[Genre Playbook - Obbies and Platformers]], [[Genre Playbook - Battlegrounds and Arena Fighters]], [[Genre Playbook - Horror and Story]], [[Genre Playbook - Roleplay and Social Hangouts]].
- Systems the levels depend on: [[Spawning Teams and Rounds]], [[Camera Systems]], [[Instance Streaming]], [[Level of Detail and Model Streaming]], [[Pathfinding Edge Cases and Fallbacks]], [[Boss Fight Design Patterns]], [[Teleporting and Multi-Place Games]].
- Measuring and testing: [[Analytics and Funnels]], [[First-Time User Experience and Onboarding]], [[Multi-Client and Device Playtesting Protocols]], [[Mobile and Low-End Optimization]].

## What this section does not cover

Terrain, foliage and art budgets: [[Terrain Tools and Terrain API]], [[Foliage Props and Scatter]], [[Art Budgets - Triangles Draw Calls Memory]]. Generated levels: [[Procedural World Generation]]. Lighting: [[Lighting Mood and Time of Day]].

## Connected notes
<!-- auto-links:start -->
[[Procedural Generation Start Here]] · Genre Systems Start Here · Onboarding Funnel · Genre Playbook - Combat and RPG · Obby Checkpoints and Stage Saves End to End · Anticipation
<!-- auto-links:end -->
