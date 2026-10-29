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

## Known limitations (please weigh these)

- **Self-made benchmark.** We wrote the questions, and Claude models graded the answers (blind, with an answer key). On held-out set B the gain over plain Claude is small (94.8% against 91.7%). The large gain is on recent Roblox platform changes. See `benchmark/README.md` for all caveats.
- **Luau not run in Studio.** The systems library, VFX and SFX modules compile and pass the checker, but they have not been run in a live Roblox game. Treat them as reviewed drafts.
- **Asset ids are placeholders.** Every texture, sound and animation id in the modules is `rbxassetid://REPLACE_ME` until the user uploads their own.
- **Reviewer scores are noisy.** Single blind reviewers ran about 1 point high, and panels can differ by about 1 point. The catalogues use the latest 3-reviewer panel.

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
