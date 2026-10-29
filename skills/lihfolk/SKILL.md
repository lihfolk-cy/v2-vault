---
name: lihfolk
description: 'LihFolk: Roblox knowledge router for LihFolk Vault V2 (800+ expert notes). Use for non-trivial Roblox work - Luau, Studio, remotes, DataStores, UI, worldbuilding, modeling, VFX, animation, game design, economy, monetization, performance, security, publishing - before writing, reviewing or debugging it.'
---

# LihFolk Roblox Knowledge Router

LihFolk Vault V2, the knowledge base, lives in `../../knowledge/` relative to this file (the plugin root's `knowledge/` folder). It contains 800+ notes written for AI agents.

## How to use it (cheap by default)

Scale the lookup to the task. The goal is the few lines that change what you do, not reading notes.

| Task | Lookup |
|---|---|
| Trivial (rename, typo, one-line fix, a question you already know cold) | None |
| Normal (a feature, a bug, a review) | One `vault.py` search (prints the best notes' TL;DRs); open nothing else unless needed |
| Big or unfamiliar (new system, security, money, data, publishing) | Up to 3-4 notes; TL;DRs first, then the one full section that applies, still not whole notes |

1. **One call first:** `python <plugin root>/knowledge/_tools/vault.py "<task or bug in plain words>"` (the plugin root is two folders above this file). It prints the best 3 notes with their TL;DRs and, for bugs, matching `SYMPTOMS.md` lines (symptom | cause | fix | note). Top-3 hit rate on a held-out test set: 93%.
2. **Fallback:** if Python is unavailable or the search misses, grep `../../knowledge/INDEX_SLIM.md` (`title | path | tags`) for exact API names and `../../knowledge/SYMPTOMS.md` for the symptom. `../../knowledge/ROUTER.md` (about 5 KB) only at the start of a long multi-topic session.
3. **TL;DR first:** every prose note opens with a TL;DR block (3-6 rules from its Common mistakes and Checklist, plus `Read more: ## <sections>`). Read only that: `Grep pattern="tldr:start" glob="**/<note title>.md" output_mode=content -A 10`, or Read the note with `limit: 20`.
4. **Sections, not files:** only when the TL;DR isn't enough, `vault.py --read "<title>" "<heading words>"` prints just the section it points to (or grep `^## ` and read that range). Never read whole large notes.
5. **Reuse within the session:** don't re-read a note you've already used for the same topic.
6. **Apply and cite** the note titles briefly.
7. **Trust labels:** `Roblox docs` and `Measured` beat `Rule of thumb`; check `Unverified` before relying on it. If nothing matches, say so and use the official Roblox docs. Never invent APIs or asset ids.

## Where things are

| Need | Look in `knowledge/` |
|---|---|
| Studio, tooling, Rojo, plugins | 01, 39 |
| Luau language, patterns, cookbook | 02, 29, 35, 40 |
| Client/server, remotes, architecture | 03, 41 |
| Saving, DataStores, sessions | 04 |
| UI / UX (house cartoon/simulator menu style: the `lihfolk-ui` skill) | 05, 42 |
| Worldbuilding, level design, terrain | 06, 33, 34, 36 |
| Lighting, VFX, audio | 07 |
| Animation, rigs | 08, 18 |
| Gameplay systems, genre systems | 09, 43, 25 |
| Game design, economy, game feel | 10, 47, 48 |
| Monetization, publishing, live ops | 11, 38, 27, 49 |
| Performance, debugging, testing | 12, 23 |
| Case studies of top games | 13, 32 |
| 3D modeling, materials, styles | 14, 44, 45, 53, 54, 55, 19 |
| AI tools, MCP, pipelines | 15, 16, 17 |
| Security, anti-exploit | 22 |
| End-to-end worked builds | 24 |
| Avatars, UGC | 37 |
| Original asset pack (models, materials, skies, animations, VFX) | `../../assets/README.md` |

## Specialist skills in this plugin

Prefer these when the task matches: `quality-score` (every generated asset or system must score 9/10), `council` (objective verdicts), `lihfolk-ui` (house menu style), `roblox-blender-modeling`, `roblox-trend-game`, `roblox-system-builder`, `roblox-ui-builder`, `roblox-secure-remotes`, `roblox-datastore-safety`, `roblox-performance-audit`, `roblox-debugging`, `roblox-anti-exploit-review`, `roblox-monetization-compliance`, `roblox-asset-import`, `roblox-vault-research`.

## Reference images

Notes in 19 (Concept Sheets) and 45 (Procedural Blender Assets) include images. View them with the Read tool when matching a style or proportions - they are references to look at, not just files.
