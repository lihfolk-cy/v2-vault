# LihFolk V2: turn your AI into a Roblox game studio

**A Claude Code plugin with 22 skills that makes your AI build Roblox games the way experienced developers do**, powered by a vault of **1,300+ original expert notes** you can also read yourself in Obsidian, plus an optional **asset pack** of original models, materials, skies, animations and VFX.

Most AI help for Roblox fails the same ways: outdated APIs, insecure remotes, lost player data, laggy builds and generic art. LihFolk fixes that at the source. Your AI looks up how it's really done, follows proven rules and checks its own work, while spending as few tokens as possible.

- **Plugin:** ask for anything Roblox in plain words; the right skill loads on its own
- **Vault:** 59 sections from Luau basics to live ops, current for 2025-2026
- **Token-light:** all 22 skills cost about 1,150 tokens per session; a vault search about 575
- **Proven:** 91-94% on four fresh, blind-graded test sets, up to 13 points above the same AI without it

---

## Install

### Claude Code plugin
```
/plugin marketplace add lihfolk-cy/v2-vault
/plugin install lihfolk@lihfolk
```
Already installed? `/plugin marketplace update lihfolk`. Then just ask Claude Code for Roblox work.

### Obsidian vault
1. Download this repo (**Code → Download ZIP**) or the all-in-one zip from [Releases](https://github.com/lihfolk-cy/v2-vault/releases).
2. In Obsidian: **Open folder as vault**, then pick the `LihFolk Vault V2` folder.
3. Start at **000 Home**. The Celestial look (starry theme, coloured folders, rainbow graph, moon home page) loads automatically from the CSS snippets in `.obsidian/snippets`, no community plugins needed. The small optional **LihFolk Graph** plugin colours every graph link if you turn on community plugins.

### Asset pack (optional)
Download it from [Releases](https://github.com/lihfolk-cy/v2-vault/releases) (in parts, or inside the all-in-one zip), unzip into one folder, then run `/lihfolk:assets setup` in Claude Code or set `LIHFOLK_ASSETS` to that folder.

### Coming from V1
In Obsidian: vault switcher → **Manage vaults** → remove V1 from the list → open V2, then delete the old folder. V1 was a 39 GB download; the complete V2 with the full asset pack is 1.3 GB, and the vault and plugin alone are 41 MB.

### Other AI tools (OpenCode, Codex, Cursor and others)
Open this folder in your tool. `AGENTS.md` tells any agent how to search the vault and apply the notes. From your own game project, add one line to its `AGENTS.md` or rules file: *"For Roblox work, follow `<path to this repo>/AGENTS.md` and search the vault before answering."* The skill guides in `skills/*/SKILL.md` work as plain instructions. Automatic skill loading, slash commands, the code-check hook and the council are Claude Code features.

---

## Token-light by design

| What your AI pays for | Before | Now |
|---|---:|---:|
| Always-loaded cost of all skills, per session | ~1,720 tokens (19 skills) | **~1,150 tokens (22 skills)** |
| Knowledge router, on Roblox tasks | ~1,610 tokens | **~940 tokens** |
| One vault search | ~745 tokens | **~575 tokens, 1 call** |
| Same lookup by grepping the index and reading notes | ~1,600 tokens, 3-5 calls | **~575 tokens, 1 call** |
| Main-model tokens per benchmark run, lookups delegated vs notes read directly | 67k | **49k** |

- **Loads only when needed:** each skill costs one description line until a task calls for it.
- **A small model does the reading:** vault lookups run in a separate agent on a fast, cheap model that returns only the facts, gotchas and note titles, so the main conversation stays clean.
- **One-call search:** `vault.py` ranks 1,300+ notes and prints the best three as short summaries, repeats removed.
- **Summaries first:** every note has a generated TL;DR; the AI opens one section for the exact number or rule, never a whole note.
- **Lookups where they pay:** plain Luau and long-stable APIs skip the vault; limits, defaults, prices, policy and 2025-2026 changes always get checked.
- **Fewer fix-it-again loops:** API names are checked before answering, and a hook catches 17 common Roblox mistakes as files are written.

Main-model figures exclude the small lookup model's own tokens. Details: `benchmark/RESULTS_v2.1.md` and `benchmark/RESULTS_v2.5.md`.

---

## What the plugin does

| Skill area | What you get |
|---|---|
| **Knowledge router** | Finds the right notes for each task and applies their mistakes and checklists, sized to the task; checks every API name it cites |
| **Systems library** | 19 drop-in typed Luau modules: validated remotes, session-locked data, idempotent purchases, shop, eggs with 2026 odds rules, codes, daily rewards, rebirth, quests, leaderboards (`/lihfolk:new-system`) |
| **Combat and ability VFX** | Slashes and impacts plus projectiles, auras, AoE warnings, shields, beam lasers, heals, teleports, level-up bursts, camera shake and hit-stop, with budgets and server-validated replication (`lihfolk-vfx`) |
| **Sound effects** | Layered, pooled combat and UI sounds synced to animation markers, sourced only from properly licensed audio (`lihfolk-sfx`) |
| **UI** | The LihFolk cartoon/simulator kit, responsive UI for phone, PC and console, and Figma frames to Roblox ScreenGuis (`lihfolk-ui`, `roblox-ui-builder`, `lihfolk-figma`) |
| **Worldbuilding** | Maps, towns, dungeons and lobbies that read as designed: brief, five build passes, composition, lighting and budgets, with placement and audit tools (`lihfolk-worldbuilding`) |
| **Modelling** | Blender modelling with an automatic quality gate and correct export, a stylised-creature builder, and model import (`roblox-blender-modeling`, `roblox-asset-import`) |
| **Game design** | Tutorials and onboarding that keep new players (`lihfolk-tutorial`), the trend-game playbook (`/lihfolk:trend-game`) |
| **Safety and performance** | Secure remotes, DataStore safety, anti-exploit review, monetization compliance, performance audits, debugging |
| **Quality control** | A hook checks every Luau file the AI writes for 17 common Roblox mistakes; `/lihfolk:audit` reviews a whole project; generated work must score 8.5/10 (`quality-score`, `/lihfolk:learn`); a blind multi-agent council gives objective verdicts (`/lihfolk:council`) |
| **Asset pack finder** | Searches the asset pack catalogues and gives import steps (`/lihfolk:assets`) |

---

## What the vault contains

**1,300+ original notes across 59 sections**, written for people and AI alike:

- **Scripting and systems:** Luau from basics to advanced, a cookbook, client/server, remotes, networking, DataStores, game systems, physics and vehicles, game math, procedural generation
- **Security and performance:** anti-exploit, debugging deep dives, profiling, mobile budgets
- **Art and feel:** UI/UX, worldbuilding, level design, lighting, VFX, audio, animation and rigs, modelling, Blender, voxel and stylised styles, materials, game feel
- **Design and business:** genres, economy, monetization, live ops, marketing, thumbnails and CTR, community, careers
- **Learn from the best:** case studies and 31 teardowns of viral hits and high-craft studios
- **Always current:** every 2025-2026 platform change, rename and deprecation
- **Reference:** 32 engine reference cards and a limits and defaults cheat sheet, verified against the official docs
- **Find anything:** one-call search, 250+ symptom → cause → fix lines (`SYMPTOMS.md`), an API atlas and a glossary

Every note carries **trust labels**: **Roblox docs** (official), **Measured** (tested in a real project), **Rule of thumb** (craft knowledge) or **Unverified** (awaiting confirmation). Notes end with **Common mistakes** (each with the symptom you'll see) and a **Checklist**, and dated claims say "as of".

### Search it yourself
```
python "LihFolk Vault V2/_tools/vault.py" "my sword floats away from the hand when I attack"
python "LihFolk Vault V2/_tools/vault.py" --read "DataStore Fundamentals" "UpdateAsync"
python "LihFolk Vault V2/_tools/vault.py" --api TeleportService.ReserveServerAsync
```
Python 3 only, no installs (use `python3` or `py` if that's your launcher).

---

## Checked, not just claimed

| Held-out test set | With the plugin | Same AI without it |
|---|---:|---:|
| C | 91.3% | 88.3% |
| D | 93.7% | 87.4% |
| E | 91.9% | 84.3% |
| F | 92.3% | 79.2% |

The sets were written without access to the vault, every answer key was checked against Roblox's documentation, and answers were graded blind (`benchmark/RESULTS_v2.5.md`).

- **No made-up APIs:** every API name in the notes is checked against a dated snapshot of the real Roblox API plus the newest doc deprecations.
- **Code that compiles:** all 1,800+ Luau code blocks are compiled with the official Luau compiler.
- **Notes that agree:** 39 key limits and defaults are cross-checked across every note.
- **Search that finds it:** the right note is in the top 3 for 93% of held-out tasks.
- **Checked on every push** by `.github/workflows/vault-checks.yml`; `REVIEWERS.md` lists each claim with the command that verifies it.

---

## What's in this repo
- `skills/`, `agents/`, `commands/`, `hooks/`: the Claude Code plugin
- `LihFolk Vault V2/`: the vault (59 sections, index, home page, theme, search tools in `_tools/`)
- `benchmark/`: test sets A-F with source-checked keys, answers, blind grades and the script that reproduces every result
- `AGENTS.md`: instructions for any AI agent
- `REVIEWERS.md`: every claim and how to check it
- `CHANGELOG.md`: what changed in each version

---

## Licence
**Vault, plugin and code:** free to read, to use on your projects, and to ship the code and what you learn in your own games, commercial ones included. Please don't re-upload, resell or repackage the notes, vault, plugin or skills, in whole or in substantial part, into another vault, course, kit or AI skill.

**Asset pack:** free to use and modify in your own games, commercial ones included, with no credit needed. Please don't resell or redistribute the assets themselves.

Full terms in [LICENSE.md](LICENSE.md). Not affiliated with or endorsed by Roblox Corporation.
