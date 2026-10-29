---
tags: [mcp, agents, coordination, studio, workflow, collaboration, type/guide, area/ai, level/intermediate, area/studio]
---
# Multiple Agents in One Studio

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No ownership table; agents discover each other by collision.
> - Avoid: Agents with their own backup habits filling the place.
> - Avoid: A spawned agent briefed without its boundaries.
> - Area assigned and recorded in the ownership table.
> - WIP folder, test spot, port and log prefix assigned.
> - Rules file read; reserved names known.
>
> Cost: TL;DR ~130 tok · whole note ~3.2k tok. Read more: ## 2. Organisation: a lead and owned areas · ## 3. Shared modules: the one-insert protocol · ## 9. Common mistakes · ## 10. Checklist for adding an agent to a shared Studio
<!-- tldr:end -->

One agent working in Studio is a power tool. Several agents working in the same Studio at once (one rebuilding zones, one baking animations, one restyling UI, one fixing combat) is a small team that never sleeps, never talks unless you make it, and shares one main thread, one undo stack and one request budget. The reference project ran this way for weeks: a lead session orchestrating a dozen specialist agents, plus several independent long-running sessions, all connected to one Studio window on one place, with the human play-testing in between. This note is what made that work and what broke when it did not.

Read [[Safety Rules for AI Agents in Studio]] first; this note assumes those rules. **Measured** marks the reference project; **Rule of thumb** marks experience.

---

## 1. What is shared (and why it matters)

When several MCP clients connect to one Studio, these are shared:

| Shared thing | Consequence | Rule |
|---|---|---|
| Studio's main thread | One agent's 20 s call freezes everyone, including the human | Calls under about 1.5 s, one at a time per agent |
| Play state | One agent starting Play blocks all Edit calls; stopping Play ends the human's test | No agent touches Play |
| The undo stack | An undo can revert another agent's work | Never undo |
| The data model | Two agents can edit the same script or folder | Area ownership |
| HttpService request budget (about 500 per minute for the place; Roblox docs, Measured) | Agents' dumps compete; one chatty tool starves the others | Batch requests |
| The camera, selection, lighting | A capture by one agent moves the view another just set | Restore after use |
| Terrain | One object; any write touches everyone's zones | Snapshot and ask |
| Output log | Everyone's prints interleave | Prefix log lines with the agent tag |
| The machine's CPU | Offline solvers starve Studio | At most 2 heavy processes per agent, single-threaded maths libraries |

The `require` cache is effectively per calling context, which is its own trap (stale modules) but not a sharing problem.

The Studio MCP server's `studio_id` lets one client drive several Studio windows ([[Roblox Studio MCP Server]]). This note is about the reverse: many clients, one window.

---

## 2. Organisation: a lead and owned areas

The structure that worked (Measured):

- **A lead session** owns the project instructions file, the briefs, and orchestration. It spawns specialist agents for passes (animation, VFX, ultimate camera, combat, enemies, cleanup, polish passes P1 to P6 and so on), reviews their output, and is the only one that deletes their safety copies.
- **Independent sessions** each own named areas of the place: one owned the roll service, the Robux shop and leaderboards; another owned terrain floors, cliffs, gate fills and loot drops; another owned a polish folder of one zone and the role-traits system; a later one owned a whole zone revamp and a new boss.
- **An ownership table** in the shared notes lists each session and its areas, and the folders or snapshots it created.

| Owner | Areas (example shape) |
|---|---|
| Lead | Instructions file, briefs, orchestration, final cleanup |
| Session A | Rolling, shop, leaderboards, travel UI |
| Session B | Terrain floors and cliffs, gate gap fills, loot drops, nametags |
| Session C | Zone 7 revamp and the zone 10 boss |
| Specialist agents (spawned by lead) | One pass each, one WIP folder each |

**Rule:** announce before touching another session's area, and ask the lead or the owner. If you need a change in someone else's script, ask them to make it, or agree a single insert point.

**Unknown content.** Measured: the place contained folders no notes described (polish passes, snapshots dated by day), almost certainly from other sessions. The rule: anything not in your notes and not yours is someone else's. Do not "clean it up".

---

## 3. Shared modules: the one-insert protocol

Some files everyone touches: the central game config (items, odds, zones), the ability kits registry, shared UI themes. Measured protocol for these:

1. **Re-read** the module immediately before editing.
2. **Back up** the current source to disk.
3. Make **one insert** (one contiguous edit), not a rewrite.
4. **Gate**: compile, use-before-definition scan, clone-require.
5. **Revert** on any failure.
6. Before overwriting a script wholesale, **compare Studio's source with your local base file**: if they differ, someone else changed it; merge instead of overwrite.

```lua
-- Optimistic concurrency for a script edit: refuse if the source changed since you read it.
local function guardedReplace(script: LuaSourceContainer, expectedHash: string, newSource: string): string
	local function hash(s: string): string
		-- Cheap fingerprint: length + a sampled checksum. Good enough to detect concurrent edits.
		local sum = 0
		for i = 1, #s, 97 do
			sum = (sum * 31 + string.byte(s, i)) % 2147483647
		end
		return ("%d:%d"):format(#s, sum)
	end
	local current = hash((script :: any).Source)
	if current ~= expectedHash then
		return "REFUSED: source changed since read (" .. current .. " vs " .. expectedHash .. ")"
	end
	local fn, err = loadstring(newSource)
	if not fn then
		return "REFUSED: does not compile: " .. tostring(err)
	end
	(script :: any).Source = newSource
	return "ok " .. hash(newSource)
end
```

The agent records the hash when it reads, and passes it back when it writes. The same idea scaled up in the reference project's clip installer, which stored a fingerprint of each clip (instance count, keyframe count, weighted pose count and a checksum of pose values) when dumping it, and refused to install a baked result if the live clip no longer matched ("changed since it was dumped"). Re-dump, re-bake, retry. **Any tool that reads, computes elsewhere and writes back needs this**, because another agent may have changed the target in between.

---

## 4. Resources each agent gets

| Resource | Allocation |
|---|---|
| Area of the place | Ownership table |
| WIP folder | One per agent, for its single safety copy (for example `ServerStorage.WIP_Staging.<AGENT>`) |
| Test spot | A fixed coordinate far from gameplay where its test objects live, prefixed with its tag |
| Ports | One per local server, recorded in notes |
| CPU | At most 2 heavy offline processes, single-threaded maths |
| Log prefix | `[AGENT] ...` on every print |

Why per-agent test spots: two agents spawning test dummies at the origin will capture each other's dummies, measure each other's rigs and delete each other's leftovers.

---

## 5. Timing and waiting

Agents block each other in predictable ways. Handle them without breaking rules:

- **Studio in Play** (the human is testing): do offline work; check `get_studio_state` every few minutes. Measured: about 12 minutes of a 50-minute weapon build was spent waiting for another session's play-test.
- **Studio slow**: someone is running a long call or heavy offline jobs. Reduce your own load; do not add more.
- **Request budget exhausted**: wait 60 s, then resume from your last index.
- **Your target changed**: re-read, re-plan, retry. Never force.

A good agent also notices the human: the user may play in the same session while tests run, so odd server behaviour may be the human's activity. Check the server log before chasing a phantom bug.

---

## 6. Conflicts seen in practice

| Conflict (Measured) | What happened | Prevention |
|---|---|---|
| Shared undo | An undo went about 40 waypoints back and reverted other sessions' changes | Never undo; snapshot instead |
| Moved work | Another workflow moved one session's zone dressing into a "removed by other AI" folder | Ownership table; announce cross-area changes |
| Restored settings | A tool restored blade effect timing that a later pass changed again | Record "authored by X, respect it" in notes |
| Play cycling | A long Play-mode verification blocked all Edit work | No agent starts Play |
| CPU starvation | Many parallel solver processes plus in-Studio simulations froze Studio about 25 minutes | Per-agent process cap |
| Name collision | A new clip named like a kit's remote broke that kit | Reserved names list |

Most of these are not bugs in any one agent. They are coordination failures, fixed by rules every agent reads.

---

## 7. Communication

Agents do not share memory unless you give them a shared medium. What worked:

- **One project instructions file** (read at session start): rules, place map, ownership table, gotchas. Kept short: the reference project's owner asked for a few lines per change, with a separate history file read on demand.
- **Append-only change notes**: each pass adds a dated block naming what changed, where, how to roll back, and what is not play-tested.
- **Briefs** for spawned agents: goal, owned area, files to read, rules, what to report.
- **Pending list**: work waiting on the human (imports, publishing ids, play-tests).

When a lead spawns agents, the brief is the agent's whole world. A good brief names the area it owns, what it must not touch, its WIP folder, its test spot, its port, and the exact verification expected. See [[AI Agents and Autonomous Workflows]] and [[Documentation and Knowledge Bases]].

---

## 8. Alternatives to one shared Studio

| Setup | Pros | Cons |
|---|---|---|
| Many agents, one Studio | Everyone sees the real place; no merge step | All the sharing hazards above |
| One agent per Studio, each on a copy of the place | No interference | Merging work back is manual and error-prone |
| Code in files (Rojo + Git), agents work on branches | Real merges, reviews, CI | Only covers code; world content still lives in the place |
| Team Create with separate Studio clients per agent | Separate main threads and undo stacks per client | Script editing collaboration rules apply; more machines or instances |

For code-heavy projects, the strongest setup is files and Git for scripts ([[Git and Source Control for Roblox]]) with agents in Studio only for world content and verification. The reference project kept most code in the place and leaned on the rules in this note instead.

---

### When not to run agents in parallel

Parallel agents pay off when their areas are truly separate (a zone, a UI screen, an animation batch). They cost more than they save when:
- The work centres on one shared file (a central config rewrite): run one agent and let the others wait.
- The work is a whole-place pass (a font sweep, a cleanup, a lighting change): run it alone, announced, while other agents work offline.
- The human is about to play-test a release candidate: freeze writes until the test is done.

Rule of thumb: if two briefs mention the same script or folder, they are one job, not two.

## 9. Common mistakes

- No ownership table; agents discover each other by collision.
- Agents with their own backup habits filling the place.
- A spawned agent briefed without its boundaries.
- Overwriting a shared script from a local copy without comparing.
- Treating unexplained folders as junk.
- Every agent printing without a prefix.
- Starting a heavy batch while someone else's batch runs.

## 10. Checklist for adding an agent to a shared Studio

- [ ] Area assigned and recorded in the ownership table.
- [ ] WIP folder, test spot, port and log prefix assigned.
- [ ] Rules file read; reserved names known.
- [ ] Shared-module protocol known (re-read, one insert, gate, revert).
- [ ] Fingerprint checks in any read-compute-write tool.
- [ ] Reporting format agreed (what changed, rollback, not play-tested).

## See also

- [[Safety Rules for AI Agents in Studio]], [[Roblox Studio MCP Server]], [[Writing Your Own MCP Server]]
- [[Team Create and Collaboration]], [[Safe Changes in a Shared Place]], [[Team Roles and Workflows]]
- [[AI Agents and Autonomous Workflows]], [[Documentation and Knowledge Bases]]
- [[Case Study - Building a Game with AI Agents]]

## Connected notes
<!-- auto-links:start -->
[[Working with AI Assistants in Studio]] · [[MCP Workflows for Building Worlds]] · [[Agent Review Loops and Guardrails in Practice]] · Pipeline Design Principles · Batch Processing Tools in Studio · Roblox Studio Assistant
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Running Many AI Agents on One Roblox Place]] · [[MCP Workflows for Scripting and Debugging]] · [[Agent Handoff Notes - Project State and Resume Templates]] · [[Studio Plugins and Local HTTP Bridges]] · [[Roblox Studio Assistant]] · [[Built-In Studio MCP vs Community MCP Servers - Migration Guide]] · [[What Is MCP]] · [[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]] · [[Setting Up MCP Clients]] · [[Blender MCP]]
<!-- related:end -->
