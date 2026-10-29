---
tags: [narrative, story, flags, chapters, saves, data, migrations, quests, type/guide, area/narrative, level/advanced, api/DataStoreService]
---
# Story State Flags and Chapter Saves

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Free-string flags -> Registry; unknown names error
> - Avoid: Renaming shipped flags -> Deprecate and migrate
> - Avoid: Choice stored as index -> Store string values
> - Flag registry with chapter ownership, kind and persistence; validator in the pipeline.
> - Facts saved; derived state in one module.
> - Save has version, chapter, checkpoint, flags, completions and chapter-start snapshots.
>
> Cost: TL;DR ~140 tok · whole note ~2.2k tok. Read more: ## 1. A flag registry, not free strings · ## 3. Save shape · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Story games accumulate state: met the smith, chose to spare the bandit, opened the crypt, finished chapter 2 on the "bad" path. That state is usually a pile of booleans added one at a time by whoever wrote the scene, and it breaks in the same ways every time: a renamed flag strands old saves, a flag set in one place is checked under a different name elsewhere, chapter select replays a chapter with future knowledge still set, and updates that insert a new scene mid-chapter leave existing players stuck. This note is the data model that survives a live game: a flag registry, derived state, chapter checkpoints, chapter select, and migrations. Dialogue conditions and effects that read and write flags are in [[Dialogue System End to End]]; quest chains in [[Quest Chain System End to End]].

Source labels: **Rule of thumb**, **Roblox docs** where engine behaviour matters.

---

## 1. A flag registry, not free strings

Every flag is declared once in a shared module with metadata:

```lua
--!strict
export type FlagDef = {
	chapter: number,          -- the chapter that owns it (for resets and chapter select)
	kind: "bool" | "count" | "choice",
	choices: { string }?,     -- for kind = "choice"
	persistent: boolean,      -- survives chapter replay (collectibles, codex entries)
	description: string,
}

local Flags: { [string]: FlagDef } = {
	MetSmith        = { chapter = 1, kind = "bool", persistent = false, description = "Spoke to the smith in the forge" },
	BanditFate      = { chapter = 2, kind = "choice", choices = { "Spared", "Killed", "Recruited" }, persistent = false, description = "Outcome of the ambush" },
	RelicsFound     = { chapter = 0, kind = "count", persistent = true, description = "Relics collected across chapters" },
	Ch2_CryptOpened = { chapter = 2, kind = "bool", persistent = false, description = "Crypt door unlocked" },
}

return Flags
```

- `setFlag` and `getFlag` refuse unknown names (error in Studio, log in live). This turns typos from silent story bugs into immediate failures.
- **Never rename or delete** a shipped flag. Deprecate it (keep the definition with a `deprecated` note and a migration to its replacement).
- Choice flags store **string values**, not indices: inserting a new choice must not shift old saves' meaning.
- A validator script (Studio command or CI) scans dialogue and quest data for flag names and checks each exists, is written somewhere, and is read somewhere ([[Build Test and Release Pipeline]]).

## 2. Store facts, derive the rest

Save **facts** (what happened), not **conclusions** (what should be shown). "Village is hostile" should be a function of `BanditFate == "Killed"` and `Ch3_TownHallBurned`, computed when needed. Conclusions stored as flags drift out of sync when you rebalance the story; derived state recomputes for old saves automatically.

Keep derived state in one module (`StoryState.isVillageHostile(flags)`) so dialogue, NPC placement and lighting all ask the same question.

## 3. Save shape

```lua
--!strict
export type StorySave = {
	version: number,                       -- schema version for migrations
	chapter: number,                       -- current chapter
	checkpoint: string,                    -- named checkpoint inside the chapter
	flags: { [string]: boolean | number | string },
	completed: { [number]: { ending: string, at: number } }, -- chapters finished, with outcome
	snapshots: { [number]: { [string]: boolean | number | string } }, -- flags at the START of each chapter
}
```

- Stored inside the player's profile with session locking ([[Session Locking and Profile Libraries]]); story writes are small and frequent, so mark the profile dirty and let autosave persist it, with an immediate save on chapter completion ([[Saving Correctly - Autosave and BindToClose]]).
- **Checkpoints** are named points authored in the level ("Ch2_AfterAmbush"), each with a spawn location and the set of flags that must be true there. Loading a save spawns the player at the checkpoint and **validates** that the required flags are present; if not, it falls back to the previous checkpoint rather than spawning into a broken scene.
- **Snapshots** at chapter start make chapter replay possible (section 4).

## 4. Chapter select and replay

When a player replays chapter 2 from chapter select:
1. Copy `snapshots[2]` into a working flag set (the world as it was when chapter 2 began).
2. Keep **persistent** flags (collectibles, codex entries, cosmetics) from the current save.
3. Play the chapter with the working set. On completion, record the outcome in `completed[2]` (perhaps as an additional ending achieved).
4. Decide explicitly whether replay outcomes **overwrite** the canonical story (rare; confusing) or are **side records** (common). Most games keep the canonical playthrough and let replays unlock endings and achievements only.

Never replay a chapter against the live flags; players will see future-knowledge dialogue and skipped scenes.

## 5. Multiplayer story games

- **Per-player story** in a shared server (players at different chapters) needs per-player world state on the client: doors, NPC positions and props driven by that player's flags, with the server validating interactions against the same flags. This is a large cost; budget for it or design hubs where state is personal and chapters are instanced ([[Teleporting and Multi-Place Games]], [[Interest Management and Per-Player Replication]]).
- **Party story** (one shared playthrough): the host's save drives the session; other players get "seen" flags and rewards but their own story position only advances if they were present for the scene and opted in. Make the rule visible in the lobby UI.
- Cutscenes and choices in party play need vote or host-choice rules ([[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]]).

## 6. Updating a live story

- **Inserting a scene** mid-chapter: players past that point must not be sent back. Give the new scene a flag that defaults to "done" for any save with a later checkpoint (migration), and make its content optional or replayable from a hub.
- **New chapters**: players who finished the old final chapter start the new one at its first checkpoint; saves at the old "The End" state migrate to a "Ch5_Start" checkpoint.
- **Removed content**: keep its flags (deprecated); migrate checkpoints inside removed areas to the nearest valid one.
- Migrations run on load, ordered by `version`, idempotent, and tested against real anonymised saves ([[Schema Migrations - Worked Case Studies]], [[Data Schema Design and Migrations]]).

## 7. Debugging story state

A dev panel (admin only) that shows a player's chapter, checkpoint and flags grouped by chapter, lets developers set a flag or jump to a checkpoint on a test account, and exports the save as text for bug reports ([[Admin Commands Done Safely - Permissions and Audit Logs]]). Story bugs are nearly always "flag not set" or "flag set too early"; seeing the set is most of the fix.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Free-string flags | Typos break scenes silently | Registry; unknown names error |
| Renaming shipped flags | Old saves lose progress | Deprecate and migrate |
| Choice stored as index | New option changes old outcomes | Store string values |
| Storing conclusions | Rebalanced story contradicts saves | Store facts, derive state |
| Replay with live flags | Future-knowledge dialogue | Chapter-start snapshots |
| Checkpoint loaded without validation | Spawn into broken scenes | Required flags per checkpoint, fallback |

## Checklist
- [ ] Flag registry with chapter ownership, kind and persistence; validator in the pipeline.
- [ ] Facts saved; derived state in one module.
- [ ] Save has version, chapter, checkpoint, flags, completions and chapter-start snapshots.
- [ ] Chapter select replays from snapshots with explicit outcome rules.
- [ ] Migrations for inserted, added and removed content; tested on real saves.
- [ ] Admin story debug panel.

## See also
[[Dialogue System End to End]] · [[Quest Chain System End to End]] · [[Quests and Objectives]] · [[Data Schema Design and Migrations]] · [[Genre Playbook - Horror and Story]] · [[Narrative Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Quest Writing and Hooks]] · [[Lore Delivery Without Walls of Text]] · [[Puzzle Dependency Charts and Hint Systems]] · [[Data Schema Versioning]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Writing Dialogue for Roblox Players]] · [[Skippable Tutorials and Replayable Tips]] · [[Naming Items Zones and Abilities]] · [[Cookbook - Data and Saving]] · [[Session Lock]] · [[Localization-Ready Writing]]
<!-- related:end -->
