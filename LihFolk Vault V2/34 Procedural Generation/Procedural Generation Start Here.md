---
cssclasses: [vault-hub]
tags: [procedural, generation, hub, start-here, type/hub, area/procedural, level/beginner, api/Terrain]
---
# Procedural Generation Start Here

This section goes deeper than the overview note [[Procedural World Generation]], which covers the basics: seeded `Random`, fractal noise, rule-based materials, the connector method for rooms, safe edit-time generation and a frame-budgeted chunk queue. Read that first. The six notes here pick up where it stops: the edge cases, the maths, complete strict Luau, and the failure modes that only show up once a generator is in a live game.

## The notes

| Note | Read it when |
|---|---|
| [[Seeds Determinism and Reproducible Worlds]] | Always first. It defines the `Hash` module the other notes use, and explains why the same seed sometimes gives a different world |
| [[Noise Functions and Terrain Generation]] | You are shaping terrain: percentiles, curves, domain warping, masks, Voronoi biomes, caves, smooth voxel writes |
| [[Dungeon and Room Generation]] | You need runs, floors or buildings: graph structure, loops, pacing by depth, locks and keys, part budgets |
| [[Wave Function Collapse on Roblox]] | Every edge must connect (roads, towns, coastlines): a complete bitmask solver and how to give it global structure |
| [[Procedural Loot and Item Generation]] | Items roll stats and affixes: power budgets, perfect-roll odds, storage, migrations, dupes |
| [[Infinite and Streamed Worlds]] | The world is generated around players at runtime: chunk managers, streaming, Parallel Luau, deltas, float precision |

## How the pieces fit

Most real generators stack several techniques. A typical roguelike survival game might use:

1. **Seeds** to name every random decision by purpose and coordinates.
2. **Noise** for the terrain and biome regions.
3. **A graph** for the critical path between landmarks.
4. **WFC** to dress settlements along that path.
5. **Scatter** for props ([[Foliage Props and Scatter]]).
6. **Item generation** for what players find.
7. **Chunk streaming** to build it all around players.

Two principles run through every note:

- **Describe, then build.** Generators produce a plain Luau table (heights, rooms, tiles, item stats). A separate step turns it into instances. Descriptions are cheap to test, simulate, validate, retry, hash and send to clients; instances are not.
- **Generate at edit time unless you must not.** Runtime generation is justified when the world must differ per server, per run or per player, or is too big to store. Otherwise generate in Studio, review, hand-finish and save.

## Where to start by goal

- **"I want a different map every round."** Seeds, then Dungeon or WFC, then [[Round-Based Minigame Loop End to End]].
- **"I want a big natural world."** Noise, then the terrain notes ([[Terrain Tools and Terrain API]], [[Terrain Deep Dive - Materials Water and Performance]]); add Infinite only if players truly travel far.
- **"I want Diablo-style loot."** Item generation, with [[RNG Drops and Luck Systems]] and [[Rarity Ladders and Drop Pacing Math]] for the drop side.
- **"My generator gives different results each time."** Seeds, the debugging section.

## Related notes elsewhere in the vault

- World building: [[Level Design for Roblox]], [[Zone and Biome Art Direction]], [[Modular Environment Kits]], [[Grid Placement and Player Building Systems]], [[Water Sky and Atmosphere Art]]
- Engine and performance: [[Parallel Luau and Actors]], [[Instance Streaming]], [[Level of Detail and Model Streaming]], [[Luau Performance Patterns with Benchmarks]], [[Memory Budgets and Leaks]]
- Data: [[Buffers and Binary Data]], [[Data Schema Design and Migrations]], [[Saved Inventory End to End]], [[Trading Systems Without Duplication]]
- Gameplay: [[Pathfinding]], [[Pathfinding Edge Cases and Fallbacks]], [[NPC AI and Behaviour]], [[Economy Inflation Sinks and Faucets Math]]
- Genres: [[Genre Playbook - Survival and Crafting]], [[Genre Playbook - Combat and RPG]], [[Genre Playbook - RNG and Collection Games]]
- Safety in shared places: [[Safe Changes in a Shared Place]], [[Batch Processing Tools in Studio]]

## Sourcing in this section

Engine facts are labelled "Roblox docs (as of October 2026)". Several behaviours are explicitly marked **unverified**: whether `math.noise` is bit-identical across platforms, whether `Random` sequences are guaranteed stable across engine updates, and exact distances at which far-from-origin precision problems appear. The notes are written so your design does not depend on those answers. Budgets and percentages without a source are rules of thumb; measure your own game.

## Connected notes
<!-- auto-links:start -->
[[Deterministic Simulation]] · Links - Terrain · Level Design Start Here · Economy Design Start Here · Variance · Math Vectors and CFrames
<!-- auto-links:end -->
