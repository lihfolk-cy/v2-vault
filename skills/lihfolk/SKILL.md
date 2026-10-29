---
name: lihfolk
description: 'LihFolk: Roblox knowledge router (1,300+ notes, also answers "check the vault"). Use before non-trivial Roblox work: Luau, Studio, remotes, data, UI, building, modelling, VFX, animation, design, money, performance, security, publishing.'
---

# LihFolk Roblox Knowledge Router

LihFolk Vault V2, the knowledge base, lives in the plugin root's `LihFolk Vault V2/` folder. It contains 1,300+ notes written for AI agents.

**Resolve the vault path first.** When this skill loads, Claude Code shows its base directory (`.../skills/lihfolk`). The plugin root is two folders above it, so `VAULT` = `<base directory>/../../LihFolk Vault V2`, written out as an absolute path (for example `C:/Users/me/.claude/plugins/.../LihFolk Vault V2`). Use this absolute `VAULT` in every command and Read below; the user's project folder does not contain the vault. If the base directory is not shown, use `${CLAUDE_PLUGIN_ROOT}/LihFolk Vault V2`.

**Python launcher:** the commands below say `python`. If it is not found (or prints "Python was not found"), use `python3`, and on Windows use `py`.

## Fastest path: delegate the lookup (default)

For any Roblox question that needs the vault, spawn the `lihfolk-lookup` agent with a prompt that starts with the line `VAULT=<absolute vault path>` (resolved above), followed by the question, and use its short answer. It runs on a small model, searches the vault in its own context and returns only the facts, gotchas and note titles, so the main context stays clean and the task finishes faster and cheaper. Do the lookup yourself (steps below) only when you need to quote a long code pattern verbatim or the agent says "not in vault".
- Don't look things up for work you already know cold (plain Luau, well-known APIs): just do it.
- One lookup per topic per session; reuse the answer.
- Don't trigger `quality-score` or `council-method` for ordinary coding tasks. They're for generated assets/systems the user asked to be scored, and for decisions the user asked to have reviewed.
## How to use it (cheap by default)

Scale the lookup to the task. The goal is the few lines that change what you do, not reading notes.

| Task | Lookup |
|---|---|
| Trivial (rename, typo, one-line fix, a question you already know cold) | None |
| Normal (a feature, a bug, a review) | One `vault.py` search (prints the best notes' TL;DRs); open nothing else unless needed |
| Big or unfamiliar (new system, security, money, data, publishing) | Up to 3-4 notes; TL;DRs first, then the one full section that applies, still not whole notes |

1. **One call first:** `python "<VAULT>/_tools/vault.py" "<task or bug in plain words>"` (quote the path: it contains spaces). It prints the best 3 notes with their TL;DRs and, for bugs, matching `SYMPTOMS.md` lines (symptom | cause | fix | note). Top-3 hit rate on a held-out test set: 93%.
2. **Fallback:** if Python is unavailable or the search misses, grep `<VAULT>/INDEX_SLIM.md` (`title | path | tags`) for exact API names and `<VAULT>/SYMPTOMS.md` for the symptom. `<VAULT>/ROUTER.md` (about 5 KB) only at the start of a long multi-topic session.
3. **TL;DR first:** every prose note opens with a TL;DR block (3-6 rules from its Common mistakes and Checklist, plus `Read more: ## <sections>`). Read only that: `Grep pattern="tldr:start" path="<VAULT>" glob="**/<note title>.md" output_mode=content -A 10`, or Read the note with `limit: 20`.
4. **Sections, not files:** only when the TL;DR isn't enough, `python "<VAULT>/_tools/vault.py" --read "<title>" "<heading words>"` prints just the section it points to (or grep `^## ` and read that range). Never read whole large notes.
5. **Reuse within the session:** don't re-read a note you've already used for the same topic.
6. **Apply and cite** the note titles briefly.
7. **Trust labels:** `Roblox docs` and `Measured` beat `Rule of thumb`; check `Unverified` before relying on it. If nothing matches, say so and use the official Roblox docs. Never invent APIs or asset ids.

**Accuracy over savings (non-negotiable):** the TL;DR is a pointer, not a substitute. For high-stakes work (player data and DataStores, purchases and receipts, paid random items and policy, remotes and security, anything that ships to live players), always read the note's full `## Common mistakes` and `## Checklist` sections, and the section that holds the exact numbers or API rules you are about to use. Also read further whenever the TL;DR leaves any doubt. Never cite a number you only saw in a TL;DR without opening its section.

## Where things are

| Need | Look in `<VAULT>/` |
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
| Original asset pack (models, materials, skies, animations, VFX) | `<base directory>/../../assets/README.md` (absolute path) |

## Specialist skills in this plugin

Prefer these when the task matches: `quality-score` (every generated asset or system must score at least 8.5/10), `council-method` (objective verdicts; the user-facing command is `/lihfolk:council`), `lihfolk-ui` (house menu style), `lihfolk-assets` (original models, materials, skies, animations and VFX from the local asset pack: search its catalogues before modelling from scratch), `lihfolk-vfx`, `lihfolk-sfx` (layered, pooled combat and UI sounds synced to the same markers, sourced only from premium licensed sounds: Roblox-licensed Creator Store audio or a library the user owns), `lihfolk-systems`, `roblox-blender-modeling`, `roblox-trend-game`, `roblox-system-builder`, `roblox-ui-builder`, `roblox-secure-remotes`, `roblox-datastore-safety`, `roblox-performance-audit`, `roblox-debugging`, `roblox-anti-exploit-review`, `roblox-monetization-compliance`, `roblox-asset-import`.

## Reference images

Notes in 19 (Concept Sheets) and 45 (Procedural Blender Assets) include images. View them with the Read tool when matching a style or proportions - they are references to look at, not just files.
