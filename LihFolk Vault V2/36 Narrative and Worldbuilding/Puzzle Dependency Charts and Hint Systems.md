---
tags: [narrative, puzzles, escape-rooms, dependency-chart, hints, level-design, validation, co-op, type/guide, area/narrative, level/advanced, server-authority]
---
# Puzzle Dependency Charts and Hint Systems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Chart only on paper -> One data module drives both
> - Avoid: No soft-lock check -> Validator simulates consumables
> - Avoid: Hints by puzzle order -> Frontier-based hint selection
> - Rooms authored as dependency charts in data with AND/OR nodes.
> - Validator checks reachability, cycles, consumables, areas and hint completeness in CI.
> - Interactables check requirements on the server; answers server-only.
>
> Cost: TL;DR ~150 tok · whole note ~2.2k tok. Read more: ## 2. Encode it as data · ## 3. Automatic validation · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Genre Playbook - Puzzle and Escape Rooms]] says every puzzle needs three hint tiers and that hints are the genre's most important retention feature. This note goes one level down: how to **model** an escape room or adventure as a puzzle dependency chart (what unlocks what), how to validate that chart automatically for soft-locks and dead ends, and how to drive **context-aware hints** from the same graph so the hint always addresses what the group is actually stuck on. The same structure works for horror games with key items, adventure quests and metroidvania gating.

Source labels: **Rule of thumb** (puzzle-design practice; dependency charts are a long-standing adventure-game design tool), **Roblox docs** where engine behaviour matters.

---

## 1. The chart

A puzzle dependency chart is a directed acyclic graph:
- **Nodes** are goals or states: "find the brass key", "open the cellar", "learn the clock code", "power restored".
- **Edges** mean "requires": `open cellar` requires `brass key`; `brass key` requires `solve the bookshelf`.
- **AND** nodes require all parents (the generator needs fuel and the switch); **OR** nodes any parent (the window can be broken or unlocked).

Shape matters more than count (**Rule of thumb**):
- **Linear chains** are easy to hint and boring for groups (one player solves, others watch).
- **Parallel branches** that merge (three independent puzzles each give one digit of a code) give groups something to split up on. Aim for 2 to 3 open branches at most times for group play.
- **Bottlenecks** (a node everything depends on) are where groups get stuck; give them the best hints and the most playtesting.

## 2. Encode it as data

```lua
--!strict
export type Node = {
	id: string,
	requires: { string },          -- parent ids
	mode: "All" | "Any",
	area: string,                  -- where its puzzle lives
	hints: { string },             -- tiered: nudge, direction, answer
	solvedFlag: string,            -- server-side state flag set when solved
}

local Room: { [string]: Node } = {
	Bookshelf = { id = "Bookshelf", requires = {}, mode = "All", area = "Study",
		hints = { "Some books look newer than others.", "The red spines spell something.", "Pull the books spelling EXIT." },
		solvedFlag = "BookshelfSolved" },
	BrassKey = { id = "BrassKey", requires = { "Bookshelf" }, mode = "All", area = "Study",
		hints = { "The shelf moved for a reason.", "Look behind the shelf.", "The key is on the hook behind the shelf." },
		solvedFlag = "HasBrassKey" },
	Cellar = { id = "Cellar", requires = { "BrassKey" }, mode = "All", area = "Hall",
		hints = { "A door downstairs is locked.", "Your key fits something in the hall.", "Use the brass key on the cellar door." },
		solvedFlag = "CellarOpen" },
}

return Room
```

The same data drives the game (interactables check `requires` on the server), the validator and the hint system. Puzzle answers live **server-side only** (ServerStorage or server modules); the hint text for the answer tier is sent only when requested ([[Genre Playbook - Puzzle and Escape Rooms]] section 5).

## 3. Automatic validation

Run a validator in Studio (command bar or plugin) and in CI on every change ([[Build Test and Release Pipeline]]):

1. **Every node reachable**: starting from nodes with no requirements, propagate solvable states; any node never reached is a dead puzzle.
2. **No cycles**: a cycle means two puzzles each require the other.
3. **Goal reachable**: the exit node is solvable.
4. **Consumables and soft-locks**: if an item is consumed (a single fuse used in one of two machines), simulate both choices and check the goal stays reachable. If a choice can make the goal unreachable, either remove it, add a respawn for the item, or make it intentional with a reset.
5. **Area check**: a node's puzzle area must be accessible once its requirements are met (no puzzle placed behind a door that the puzzle itself opens).
6. **Hint completeness**: three hints per node, none empty, answer tier actually contains the answer.

```lua
--!strict
local function reachable(room: { [string]: { requires: { string }, mode: "All" | "Any" } }): { [string]: boolean }
	local solved: { [string]: boolean } = {}
	local changed = true
	while changed do
		changed = false
		for id, n in room do
			if not solved[id] then
				local ok: boolean
				if #n.requires == 0 then
					ok = true
				elseif n.mode == "All" then
					ok = true
					for _, r in n.requires do if not solved[r] then ok = false break end end
				else
					ok = false
					for _, r in n.requires do if solved[r] then ok = true break end end
				end
				if ok then solved[id] = true changed = true end
			end
		end
	end
	return solved
end
```

Anything in `room` but not in the result is unreachable. Cycles show up as unreachable nodes too; a separate DFS names the cycle.

## 4. Context-aware hints from the chart

A hint button that gives "the next hint for puzzle 3" is wrong when the group is stuck on puzzle 5. With the chart, the server knows the **frontier**: nodes whose requirements are met but which are not yet solved.

1. Compute the frontier from the group's solved flags.
2. Pick the frontier node the group is most likely stuck on: longest time on the frontier, the one in the area where most players are standing, or a bottleneck that blocks the most downstream nodes.
3. Serve the **next unused tier** for that node; remember per node which tiers the group has seen.
4. If several frontier nodes exist, the first tier can be a meta-nudge: "There are two things you can work on: the clock and the cellar."

**Timing**: tier 1 becomes free after the group spends N minutes on the frontier without progress (2 to 4 minutes for small rooms), tier 2 after more time or for soft currency, tier 3 always available for a price or vote. Reset the timer on any solve. Do not let timers count while all players are idle or in menus.

**Co-op**: hint requests are group actions. Show who requested and what tier; in public lobbies require a vote or let the requester see it privately first, so one player cannot spoil the answer for strangers ([[Social Design and Multiplayer Play]]).

## 5. Analytics from the chart

Log per node: time on frontier per group, hint tiers used, wrong attempts, and abandon rate while the node was on the frontier. A node where most groups use the answer tier or many groups quit is broken: change the puzzle, not the hint ([[Analytics and Funnels]]).

## 6. Rate limits and answer safety

- Guess remotes rate-limited per player and checked for distance to the puzzle object ([[Rate Limiting and Abuse Prevention]]).
- Randomise answers per server where the puzzle allows (codes generated per run and shown through clues), so leaked videos do not solve your room.
- Late joiners receive the current solved set and the frontier; replicate it as attributes on a room state folder ([[Replication Rules]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Chart only on paper | Code and design diverge | One data module drives both |
| No soft-lock check | Groups stuck after using an item wrongly | Validator simulates consumables |
| Hints by puzzle order | Hint for the wrong puzzle | Frontier-based hint selection |
| Timers count while idle | Free answers for AFK groups | Count only active play time |
| One player spoils the answer for all | Ruined public lobbies | Votes or private-first reveal |
| Fixed answers | Video walkthroughs solve the room | Per-server randomised answers |

## Checklist
- [ ] Rooms authored as dependency charts in data with AND/OR nodes.
- [ ] Validator checks reachability, cycles, consumables, areas and hint completeness in CI.
- [ ] Interactables check requirements on the server; answers server-only.
- [ ] Hints chosen from the frontier with tiered timers and group rules.
- [ ] Per-node analytics reviewed after launch.
- [ ] Guesses rate-limited; answers randomised where possible.

## See also
[[Genre Playbook - Puzzle and Escape Rooms]] · [[Story State Flags and Chapter Saves]] · [[Quests and Objectives]] · [[Level Design for Roblox]] · [[Difficulty Options and Cognitive Load]] · [[Narrative Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Genre Playbook - Horror and Story]] · Quest Chain System End to End · Testing Strategies and Frameworks
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Dialogue System End to End]] · [[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]] · [[Lore Delivery Without Walls of Text]] · [[Writing Dialogue for Roblox Players]] · [[Quest Writing and Hooks]] · [[Naming Items Zones and Abilities]]
<!-- related:end -->
