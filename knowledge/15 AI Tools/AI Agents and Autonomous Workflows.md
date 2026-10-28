---
tags: [ai, agents, mcp, automation, workflow, production]
---
# AI Agents and Autonomous Workflows

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Running agents in a shared place without written rules.
> - Avoid: Letting agents start Play or use undo in a place others use.
> - Avoid: One huge Studio call instead of sliced short ones.
> - Rules file with Studio, offline and verification rules.
> - Ownership map for every agent session.
> - Snapshot and rollback path for every risky change.
>
> Read more (15 KB note): ## 3. The working rules that made it safe · ## 4. Moving work out of Studio: the bridge pattern · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An AI agent is a model in a loop with tools: it reads, acts, checks the result, and decides what to do next, for many steps without a person approving each one. In Roblox development, agents can now read and edit your place through Studio's built-in MCP server, run Blender through a Blender MCP connection, run Python and shell commands on your machine, and play-test through Roblox's playtest subagent. That is enough to build large parts of a game. The reference project did exactly that: most of its code, tooling, animation data, icons and generated sounds were produced by AI coding agents connected to Studio and Blender, coordinated by a lead session, under a strict set of working rules.

This note is about the workflow level: how agent setups are structured, what jobs suit them, the rules that keep them from damaging a shared place, and a real end-to-end agent pipeline. The protocol and setup side is in the MCP section: [[What Is MCP]], [[Roblox Studio MCP Server]], [[Blender MCP]], [[Setting Up MCP Clients]], [[Safety Rules for AI Agents in Studio]], [[Multiple Agents in One Studio]], and the full story in [[Case Study - Building a Game with AI Agents]].

Products as of October 2026.

---

## 1. Anatomy of an agent setup

| Part | What it is | Roblox examples |
|---|---|---|
| Model | The LLM making decisions | Whatever your client uses; Roblox Assistant can use Roblox's default or your own keys |
| Tools | Functions the model can call | Studio MCP tools (`execute_luau`, `script_read`, `multi_edit`, `screen_capture`...), Blender MCP, shell, file edit, web fetch |
| Memory | What persists between steps and sessions | A project notes file, a scratch folder, structured JSON outputs, the place itself |
| Orchestration | Who starts what | One agent; a lead with subagents; several parallel sessions |
| Guard rails | What it may not do, and what stops it | Written rules, permission prompts, tool allowlists, fingerprint checks, budgets |

### Shapes

- **Single agent**: one session does a task end to end. Simple, good for focused work.
- **Lead and subagents**: a lead plans and delegates bounded subtasks (search the place, bake one kit, render icons) to subagents with their own context, then integrates. Roblox Assistant uses this internally (explore, screen capture and playtest subagents). Roblox has said it is developing multiple agents running in parallel on separate tasks.
- **Parallel sessions**: several independent agent sessions on one project, each owning an area. Highest throughput, highest collision risk.

The reference project used all three. Its lead session owned the project notes and briefs and launched specialist passes (animation, VFX, combat, enemies, cleanup, UI). Other sessions owned other areas (economy and shop services, terrain and small fixes, map polish). A table of who owned what lived in the shared notes, with one rule: do not touch another session's area; ask the lead.

---

## 2. What agents are good at, and what they are not

| Good fit | Why |
|---|---|
| Multi-file refactors with a grep-able before and after | Checkable |
| Building tools: loaders, converters, solvers, scanners | The output is code you can read and re-run |
| Batch operations over hundreds of instances, sliced into short calls | Patient and consistent |
| Pipelines with numeric verification (bake, score, install only if the score passes) | The agent can loop until the check passes |
| Investigations ("why does this kit do no damage live?") | Fast reading across many scripts |
| Data plumbing (config tables, registries, ids into config) | Mechanical |

| Poor fit | Why |
|---|---|
| Final taste calls (art, feel, difficulty) | No eyes on the real experience; the reference project's owner rejected a whole batch of agent-designed weapons on taste |
| Anything verified only by "it looks right" from a capture | Captures can be black or misleading |
| Live-server behaviour | Agents in Studio see Studio |
| Work that needs Play mode in a shared place | Starting Play interrupts everyone |
| Manual steps outside the tools | Importing local files in some setups, publishing animations, Creator Dashboard actions |

---

## 3. The working rules that made it safe

These rules come from the reference project's notes. Each was added after an incident.

### Studio rules

1. **Edit mode only. Never start or stop Play.** The owner and other sessions play-test. If Studio is in Play, Edit calls fail ("Edit datamodel is not available in Play mode"): work offline and re-check every few minutes.
2. **One Studio call at a time, each under about 1.5 seconds.** Studio froze for about 25 minutes when roughly 18 heavy offline processes ran alongside in-Studio simulations. Long jobs are sliced (section 4). The budget tightened over time (earlier tools used 5 s and 3.5 s).
3. **Never use undo in a shared place.** The undo history is shared. An undo to recover terrain went about 40 waypoints back and rolled back other sessions' changes; each `execute_luau` call adds a waypoint that wipes redo. Snapshot first instead.
4. **Snapshot before risky edits.** Terrain: copy the region to a `TerrainRegion` first. Scripts: keep the pre-change source on disk. Objects: one safety copy, never several.
5. **Backups go to disk, not into the place.** Backup folders accumulated until the place reached about 1.07 million instances and Studio ran at 15 fps; all were deleted and the rule became: rely on version history or save `.rbxm` files to disk.
6. **Clone-require stale modules.** `require` returns a cached copy in Edit; read current module state by requiring a clone placed beside the original.
7. **Shared modules: re-read right before editing, make one insert, then compile, scan and clone-require; revert on failure.** A central config module edited by two sessions was the most dangerous file in the project.
8. **Compare before overwrite.** Before replacing a script, compare Studio's current source with your local base; someone else may have changed it.
9. **Restore what you change for tooling.** After positioned captures, restore the camera to `Custom`. Turn off lighting previews right after use (a weather system read the place's lighting as its base when Play started).
10. **Never invent asset ids.** Use placeholders and upload real files.
11. **Verify numerically when screenshots fail.** Positions, counts, distances, angles.
12. **Say "not play-tested".** Every report states how far verification went and what the human must check in Play.
13. **If a permission check denies an action, stop and report.** Do not route around the guard rail.

### Offline rules

- Limit parallel offline processes per agent (the project used at most 2, 1 during installs) and force single-threaded maths libraries, so agents do not starve each other or Studio.
- `HttpService` allows about 500 requests per minute per place: post one result per batch, not one per item; on "Number of requests exceeded limit", wait 60 seconds.

---

## 4. Moving work out of Studio: the bridge pattern

Agents work best when Studio does only input and output, and heavy computation runs offline. The reference project's pattern:

1. A tiny local static file server on `127.0.0.1` serves Lua tool files.
2. Studio loads a tool with `loadstring(HttpService:GetAsync(url .. "?x=" .. os.clock(), true))()`. The query string defeats caching so edits take effect immediately.
3. The tool dumps data (clips, rig joints, positions) and posts it back with `HttpService:PostAsync` to a small local receiver that writes files.
4. Python does the maths offline (seconds to minutes per item) with no Studio cost.
5. Studio fetches the result and writes it, in short sliced calls.

Measured: one animation clip baked in 10-40 seconds offline and cost about 0.1 s of Studio time.

```lua
-- Studio side (command bar / plugin context). Requires HTTP requests enabled for the place,
-- and loadstring available in this context.
local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8765/" -- local tool server
local RECV = "http://127.0.0.1:8833/" -- local result receiver

local function loadTool(path: string)
	local src = HttpService:GetAsync(BASE .. path .. "?x=" .. os.clock(), true)
	local fn, err = loadstring(src)
	assert(fn, err)
	return fn()
end

local function postResult(name: string, data: any)
	-- one POST per batch: HttpService is limited to about 500 requests per minute
	HttpService:PostAsync(RECV .. "data/" .. name, HttpService:JSONEncode(data))
end
```

```python
# Minimal local receiver: writes POST bodies to ./inbox/<name>. Local use only.
import http.server, os, re

ROOT = os.path.abspath("inbox")
NAME = re.compile(r"^[A-Za-z0-9_.-]{1,80}$")

class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        parts = self.path.strip("/").split("/")
        if len(parts) != 2 or parts[0] != "data" or not NAME.match(parts[1]) or ".." in parts[1]:
            self.send_response(400); self.end_headers(); return
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        os.makedirs(ROOT, exist_ok=True)
        with open(os.path.join(ROOT, parts[1]), "wb") as f:
            f.write(body)
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")

http.server.HTTPServer(("127.0.0.1", 8833), H).serve_forever()
```

Bind to `127.0.0.1` only and validate names, so nothing outside your machine can write files. More in [[Studio Plugins and Local HTTP Bridges]].

### Sliced jobs

Every long Studio-side loop checks its time budget and returns early with a resume index; the agent calls it again until it reports completion. A stuck job (repeating the same "frames done" result) is resolved by stepping it once by hand. See the sliced-job example in [[Roblox Studio Assistant]].

---

## 5. A real agent pipeline: adding a weapon

The reference project packaged its "add a new weapon" process as a skill (a written procedure an agent loads and follows). Anonymised, the steps and measured times were:

| Step | What the agent does | Time |
|---|---|---|
| 1. Parse | Read the artist's setup file and model file; generate rig, effects and kit scaffolds offline | 0.1 s |
| 2. Rig and FX | Load the installer over HTTP; build the weapon rig and effects module in Studio | ~1 min |
| 3. Icon | Render the icon in Blender from the real model; look at it; upload it | ~2-3 min (about 20 s per icon in batches) |
| 4. Config | One edit to the shared config module (with backup, compile, scan, clone-require) | ~1 min |
| 5. Kit design | Write the moves: key-pose specs, effects, server hit data | 30-45 min (the creative step) |
| 6. Build | Generate kit code; check reserved names and size limits | 2 s |
| 7. Install | Bake each move in sliced calls (about 0.5 s per baked frame), install the kit folder under its 2,500 instance budget | 5-8 min of short calls |
| 8. Register | Upload move icons; register the kit in shared registries | ~1 min |
| 9. Test and arms | Edit-mode dev test of each move; offline arm re-solve with numeric QA; install only moves with zero criticals and engine match under 3 degrees | ~10 min |
| 10. Verify and clean | Verify grip, hinges, effects, registry; remove test objects | ~1 min |
| 11. Notes | Update project notes and changelog | ~5 min |

Whole run: about 15 minutes of tool time plus the kit design and offline bakes. **Manual steps stayed manual:** importing the model file into Studio, publishing animation ids, and the play-test. Batches of 15 and 22 weapons ran through the same pipeline with one shared-config edit per batch.

What made it work:
- **Every step had a check** that could stop it (compile, scan, size, instance budget, QA score, registry check).
- **Idempotent stages**: re-running a stage repairs rather than duplicates.
- **Findable test objects** with a fixed prefix at a fixed test location, removed by a cleanup stage.
- **One safety copy** of anything replaced, named for the pass.

---

## 6. Failure modes of agents

| Failure | What it looks like | Prevention |
|---|---|---|
| False done | "Implemented and verified" with no evidence | Require the verification rung and artefacts ([[Prompting and Verifying AI Output]]) |
| Runaway loop | The same tool call repeated, or a fix that breaks another thing, forever | Step limits; loop detection (Roblox's playtest agent ends tests after repeated identical calls and aborts at 50 turns) |
| Scope creep | Asked to fix a button, rewrites the HUD | Explicit scope and a list of files it may touch |
| Stale context | Edits based on what a script looked like an hour ago | Re-read before every edit; fingerprints before writes |
| Collisions between agents | Two sessions edit the same module; one wins | Area ownership, single-insert edits, compare-before-overwrite |
| Shared-state damage | Undo, Play toggles, lighting left in preview mode | The Studio rules above |
| Resource starvation | Studio freezes; offline jobs crawl | Call budgets, process limits |
| Silent permission workarounds | A denied action retried a different way | Rule: stop and report |
| Hallucinated assets | Invented ids in config | Placeholders; ids only from upload results |

---

## 7. Starting with agents: a staged plan

1. **Read-only.** Let an agent answer questions about your place and codebase. Learn what it gets wrong.
2. **Edits in a copy.** Work on a copy of the place or a branch of the file project. Review diffs.
3. **Write the rules file.** Turn every mistake from steps 1-2 into a rule.
4. **Small scoped tasks in the real project**, with snapshots and checks.
5. **Pipelines.** When a task repeats (new item, new enemy, new icon), write it down as a procedure with checks at each step, and let the agent run it.
6. **Parallel agents** only after ownership rules exist.

Keep a human on: taste, play-testing, publishing, and anything irreversible.

## Common mistakes

- Running agents in a shared place without written rules.
- Letting agents start Play or use undo in a place others use.
- One huge Studio call instead of sliced short ones.
- No ownership map with several agents.
- Accepting summaries without artefacts.
- Automating a step before it has worked by hand.

## Checklist

- [ ] Rules file with Studio, offline and verification rules.
- [ ] Ownership map for every agent session.
- [ ] Snapshot and rollback path for every risky change.
- [ ] Heavy work offline; Studio calls short; HTTP batched.
- [ ] Pipelines with a blocking check at every step.
- [ ] Manual steps listed in every report; "not play-tested" where true.

## See also
[[What Is MCP]] · [[Roblox Studio MCP Server]] · [[Blender MCP]] · [[Safety Rules for AI Agents in Studio]] · [[Multiple Agents in One Studio]] · [[Studio Plugins and Local HTTP Bridges]] · [[Case Study - Building a Game with AI Agents]] · [[Working with AI Assistants in Studio]] · [[Pipeline - New Animated Weapon]] · [[Pipeline Design Principles]]

## Connected notes
<!-- auto-links:start -->
[[Batch Processing Tools in Studio]] · [[AI in Roblox Development Overview]] · [[MCP Workflows for Building Worlds]] · [[MCP Workflows for Scripting and Debugging]] · [[Studio Tooling Architecture]] · [[Writing Your Own MCP Server]]
<!-- auto-links:end -->
