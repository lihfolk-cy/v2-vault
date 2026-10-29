# LihFolk vault map and specialist skills

Loaded on demand by the `lihfolk` router. `<VAULT>` is the absolute vault path the router resolved; `<base directory>` is the router skill's folder.

## Where things are

| Need | Look in `<VAULT>/` |
|---|---|
| Studio, tooling, Rojo, plugins | 01, 39 |
| Luau language, patterns, cookbook | 02, 29, 35, 40 |
| Client/server, remotes, architecture | 03, 41 |
| Saving, DataStores, sessions | 04 |
| UI / UX (house cartoon/simulator menu style: the `lihfolk-ui` skill); tutorials and onboarding (the `lihfolk-tutorial` skill) | 05, 42 |
| Worldbuilding, level design, terrain (the `lihfolk-worldbuilding` skill) | 06, 33, 34, 36 |
| Lighting, VFX, audio | 07 |
| Animation, rigs | 08, 18 |
| Gameplay systems, genre systems | 09, 43, 25 |
| Game design, economy, game feel | 10, 47, 48 |
| Monetization, publishing, live ops | 11, 38, 27, 49 |
| Performance, debugging, testing | 12, 23 |
| Case studies and teardowns of top games (viral/trend, high-craft) | 13, 32, 59, 60 |
| 3D modeling, materials, styles | 14, 44, 45, 53, 54, 55, 19 |
| AI tools, MCP, pipelines | 15, 16, 17 |
| Security, anti-exploit | 22 |
| End-to-end worked builds | 24 |
| Avatars, UGC | 37 |
| Original asset pack (models, materials, skies, animations, VFX) | `<base directory>/../../assets/README.md` (absolute path) |

## Specialist skills in this plugin

Prefer these when the task matches: `quality-score` (every generated asset or system must score at least 8.5/10), `council-method` (objective verdicts; the user-facing command is `/lihfolk:council`), `lihfolk-ui` (house menu style), `lihfolk-assets` (original models, materials, skies, animations and VFX from the local asset pack: search its catalogues before modelling from scratch), `lihfolk-vfx`, `lihfolk-sfx` (layered, pooled combat and UI sounds synced to the same markers, sourced only from premium licensed sounds: Roblox-licensed Creator Store audio or a library the user owns), `lihfolk-systems`, `lihfolk-worldbuilding` (maps, levels, biomes, towns, dungeons, lobbies, obby areas, terrain: layout, composition and dressing with a placement and audit toolkit), `lihfolk-tutorial` (tutorials, onboarding and FTUE that keep first-time players), `roblox-blender-modeling`, `roblox-trend-game`, `roblox-system-builder`, `roblox-ui-builder`, `roblox-secure-remotes`, `roblox-datastore-safety`, `roblox-performance-audit`, `roblox-debugging`, `roblox-anti-exploit-review`, `roblox-monetization-compliance`, `roblox-asset-import`.

## Reference images

Notes in 19 (Concept Sheets) and 45 (Procedural Blender Assets) include images. View them with the Read tool when matching a style or proportions - they are references to look at, not just files.

## More lookup tools

- `<VAULT>/ROUTER.md` (about 5 KB): read once at the start of a long multi-topic session.
- Every prose note opens with a TL;DR block between `<!-- tldr:start -->` and `<!-- tldr:end -->`. To read only that: `Grep pattern="tldr:start" path="<VAULT>" glob="**/<note title>.md" output_mode=content -A 10`, or Read the note with `limit: 20`.
