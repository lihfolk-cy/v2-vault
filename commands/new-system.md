---
description: Install and wire a drop-in LihFolk system (shop, inventory, eggs, codes, daily rewards, rebirth, quests, leaderboard, data saving) into this Roblox project, then score it (system rubric, min 8.5)
argument-hint: <system: playerdata|currency|shop|receipts|inventory|eggs|codes|daily|rebirth|quests|leaderboard|all> [notes]
---

Install the LihFolk system "$ARGUMENTS" into this project.

1. Use the `lihfolk-systems` skill (library at `skills/lihfolk-systems/` in the LihFolk plugin) together with `roblox-system-builder`. Read the skill's layout, contracts and decisions table, the matching Worked Build note, and the system rubric hard gates in `quality-score/rubrics/system.md` before changing anything.
2. Survey the project first: grep for `ProcessReceipt`, `GetDataStore`, `UpdateAsync`, `SetAsync`, `RemoteEvent`, `RemoteFunction` and any existing data, remote or receipt module. Never create a second data writer or a second `ProcessReceipt`; adapt or migrate instead, and say which.
3. Write a short decisions table for this system (from the skill's defaults plus anything the user said) and a pre-flight plan from `quality-score/recipes/system.md` and the project ledger.
4. Copy only the modules the system needs plus their dependencies to the install paths in the skill (Rojo: merge `default.project.json`; Studio: create the ModuleScripts). Fill `LihFolkConfig` / `LihFolkSecrets` for this game. Ask for real Developer Product and Game Pass ids, or leave `id = 0` and state that those products cannot be prompted yet.
5. Wire it in the single server `Main` in the documented order (Configure -> Policy.Init -> service Init -> hooks -> Receipts.Start -> PlayerData.Start) and add the client controller from the matching `examples/<System>.client.luau`, with UI built by `roblox-ui-builder` (every purchase surface of a random item gets a labelled "Odds" control).
6. Install `tests/Runner.luau` and the matching `*.spec.luau` files. If Roblox Studio is connected, run the specs and a Play test (persistence, TestProfileKey, SimulateLoadFailure, two clients, ForceRestrictedPolicy for paid random items, remote fuzz). If it is not, list these steps for the user and keep the label "reviewed, not run".
7. Score with the `quality-score` skill using the **system** rubric. Minimum 8.5; any failed hard gate caps the score at 5.0 (an unrun test suite counts as not passed). Fix the lowest criterion, at most 3 rounds, and log the result to `.lihfolk/ledger.jsonl`.
8. Report: files added or changed with install paths, the decisions table, the exploits table, the score line, and what the user must still do (product ids, Studio API access, running the tests).
