# Reviewer guide (humans and AI)

This page lists what LihFolk Vault V2 claims and how to check each claim yourself. Everything here runs from a fresh clone with Python 3.10+ and, for the plugin checks, Claude Code. Nothing needs Roblox Studio.

## What it is

- A Roblox game-development knowledge vault (`LihFolk Vault V2/`, 1,290+ original notes) that opens in Obsidian.
- A Claude Code plugin (`.claude-plugin/`, `skills/`, `agents/`, `commands/`, `hooks/`) that routes Roblox tasks to the right notes, checks Luau as it is written, and adds specialist skills (systems, UI, VFX, SFX, assets, quality scoring, council review).
- An optional, separately downloaded asset pack of original models, materials, skies, animations and VFX previews (GitHub Releases). A small sample pack is attached to each release.

## Claims and how to verify them

| Claim | How to check |
|---|---|
| The plugin manifest is valid | `claude plugin validate .` |
| Luau code checks catch common Roblox mistakes | Run `hooks/scripts/lihfolk-check.sh <file.luau>` (or the `.ps1` engine on Windows) on any file under `skills/`; all shipped Luau passes (the checker prints nothing and exits 0 when a file is clean, and prints each finding otherwise). Feed it a file with `wait()` or an unvalidated `RemoteEvent` handler to see it fire. |
| Vault search finds the right note | `python "LihFolk Vault V2/_tools/eval.py"`: held-out test split hit@3 is 93% (search eval tasks are in `_tools/eval/`). |
| Notes don't contradict each other on tracked facts | `python "LihFolk Vault V2/_tools/consistency.py"` |
| API names in notes exist in the Roblox API | `python "LihFolk Vault V2/_tools/api_check.py"`. Deprecated APIs it flags appear in notes that list them as deprecated, on purpose. |
| The vault improves Claude's Roblox answers | `benchmark/`: 48 tasks (set A plus a held-out set B), 3 runs per setup, scored blind by 3 graders. Re-run the aggregation with `python benchmark/v2_aggregate.py report`; it reproduces `benchmark/RESULTS_v2.md` exactly. |
| Assets in the pack were blind-reviewed | Each catalogue row (`CATALOG.csv` per section in the pack) carries its score and status. Only `shipped` (median of 3 blind reviewers at least 8.5/10) and `approved` (owner-accepted) rows ship. |

## How the results were produced

- **Benchmark design.** The LihFolk team wrote the questions, and three Claude models graded every answer blind against an answer key. Set A targets Roblox knowledge from 2025-2026; set B is a held-out general set (94.8% with the vault, 91.7% without). The biggest lift is on recent platform changes: 22.8/23 against 8.2/23. `benchmark/README.md` has the full method.
- **Luau modules.** The systems library and the VFX and SFX modules compile and pass the LihFolk checker. As with any drop-in code, play-test them in Studio inside your own game before you publish.
- **Your own asset ids.** Upload your textures, sounds and animations, then paste the ids where the modules show `rbxassetid://REPLACE_ME`. That keeps every asset in your game owned by you.
- **Scoring method.** Each catalogue score is the median of a 3-reviewer blind panel, and the latest panel is the one recorded. Single-reviewer scores were used only for iteration.

## What to look at first

1. `README.md`, then `LihFolk Vault V2/000 Home.md` and `00 Start Here.md`.
2. `skills/lihfolk/SKILL.md`: the router that every Roblox task goes through.
3. One deep note per area: `04 Data and Persistence`, `22 Anti-Exploit and Security`, `49 Roblox Platform Features`.
4. `skills/quality-score/`: the rubrics and the learning ledger format (`examples/ledger.sample.jsonl`).

## Licences

- The plugin and the vault notes are under `LICENSE.md`.
- The asset pack: free to use in your own games, no resale or redistribution (`LICENSE.md`).
- The bundled Everforest base theme is MIT (`LihFolk Vault V2/.obsidian/themes/Everforest/LICENSE.md`). The LihFolk Graph plugin is our own (CC BY 4.0).
- No third-party scraped assets are included. The sound skill points to licensed sources and never ships sound files.

Found a problem? Open an issue with the note title or file path and what is wrong.
