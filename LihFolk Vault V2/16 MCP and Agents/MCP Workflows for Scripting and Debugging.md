---
tags: [mcp, agents, scripting, debugging, luau, workflow, type/guide, area/ai, level/intermediate, area/scripting, api/Script]
---
# MCP Workflows for Scripting and Debugging

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Editing from memory instead of a fresh `script_read`.
> - Avoid: Saving without compiling.
> - Avoid: "Testing" with a cached `require`.
> - Fresh read of the target and its callers.
> - One focused edit.
> - Gate: compile, use-before-definition, size, clone-require.
>
> Cost: TL;DR ~110 tok · whole note ~4.7k tok. Read more: ## 2. The save gate · ## Nuances and edge cases · ## 8. Common mistakes · ## 9. Checklist for an agent scripting change
<!-- tldr:end -->

Writing Luau is the part of game development AI agents do best, and the part where an agent connected to Studio has the biggest advantage over one that only sees text: it can grep every script in the place, read the real current source before editing, compile its edit, run checks in Edit mode, and read the Output. It can also confidently overwrite another person's change, save a script that compiles but crashes on load, or "verify" a fix against a stale cached module. This note is the method for agent scripting through MCP that kept a large production codebase working.

Tools are from [[Roblox Studio MCP Server]]. **Measured** marks facts from the reference project (a game of several hundred scripts, some near the 200,000-character limit, written almost entirely by agents). **Rule of thumb** marks experience.

---

## 1. Read before you write, every time

The rule that prevents most damage: **re-read the current source immediately before editing**, even if you read it ten minutes ago.

Why: in a shared place the human, other agents, Team Create collaborators or a sync tool (Rojo) can change a script at any time. An agent that edits from memory reintroduces old code or deletes someone's fix. The reference project made it a rule for shared modules: re-read right before editing, make **one** insert, compare Studio's source with the local base file before overwriting ([[Multiple Agents in One Studio]]).

Tools:
- `script_search` to find the script by name.
- `script_read` with a line range around the area you will change.
- `script_grep` to find every caller of the function you are about to change.

```text
script_grep  pattern: "GetDamageMultiplier("     -> 7 call sites in 4 scripts
script_read  path: ServerScriptService.CombatCore  lines 180-240
multi_edit   path: ServerScriptService.CombatCore  (one exact-match replacement)
script_read  path: ServerScriptService.CombatCore  lines 180-240   (confirm)
```

---

## 2. The save gate

Before any script edit is considered done, it passes a gate. The reference project's gate (Measured), which caught real crashes:

1. **It compiles.** `loadstring(src)` returns a function. A syntax error returns `nil` plus a message.
2. **No use-before-definition.** Luau compiles a call to a `local function` that is defined further down, but at runtime the name is `nil` at the time of the call. The project ran a scanner over every saved script.
3. **Under the size limit.** Script `Source` is limited to 200,000 characters (Measured). Near the limit, extend through a new module instead of growing the script.
4. **Modules load.** Clone-require the edited module to prove it runs its top level without error ([[Roblox Studio MCP Server]], section 5.2).

A minimal gate you can run through `execute_luau` (a sketch: the scanner is a heuristic, not a parser):

```lua
--!strict
-- Returns a list of problems; an empty list means the source passes the gate.
local MAX_SOURCE = 200000

local function useBeforeDefinition(src: string): {string}
	local problems = {}
	-- Record the line of each "local function name" definition.
	local defLine: {[string]: number} = {}
	local lineNo = 0
	for line in (src .. "\n"):gmatch("(.-)\n") do
		lineNo += 1
		local name = line:match("^%s*local%s+function%s+([%w_]+)")
		if name and not defLine[name] then
			defLine[name] = lineNo
		end
	end
	-- Flag top-level-looking calls that appear before the definition line.
	-- Heuristic: calls inside earlier function bodies are fine at runtime if the
	-- body runs later, so only flag lines with no indentation.
	lineNo = 0
	for line in (src .. "\n"):gmatch("(.-)\n") do
		lineNo += 1
		if not line:match("^%s") then
			for name, defAt in defLine do
				if lineNo < defAt and line:find(name .. "%(") and not line:find("function%s+" .. name) then
					table.insert(problems, ("line %d calls %s before its definition at line %d"):format(lineNo, name, defAt))
				end
			end
		end
	end
	return problems
end

local function gate(src: string): {string}
	local problems = {}
	if #src > MAX_SOURCE then
		table.insert(problems, ("source is %d chars (limit %d)"):format(#src, MAX_SOURCE))
	end
	local fn, err = loadstring(src)
	if not fn then
		table.insert(problems, "compile: " .. tostring(err))
	end
	for _, p in useBeforeDefinition(src) do
		table.insert(problems, p)
	end
	return problems
end

local target = game.ServerScriptService.CombatCore :: Script
return table.concat(gate(target.Source), "\n")
```

The real scanner should be smarter (it should understand nested scopes), but even this crude version catches the classic agent mistake of adding a helper at the bottom of a file and calling it from the top-level setup code. Put the gate in a ModuleScript in ServerStorage so every agent and human runs the same one.

---

## 3. Choosing edit tools

| Situation | Tool | Why |
|---|---|---|
| Small change to an existing script | `multi_edit` | Exact-match replacements; fails loudly if the text changed |
| New script | `multi_edit` on a new path (it creates it) | One call |
| Large generated source (tens of KB) | Write to disk, serve over localhost, set `Source` from `HttpService:GetAsync` in a short call | Keeps the model context small; see [[Studio Plugins and Local HTTP Bridges]] |
| Same edit across 50 scripts | A batch tool in `execute_luau` that edits `Source` with `string.gsub`, dry-run first | One reviewed transformation instead of 50 edits |
| A Rojo project | Edit the files on disk; let Rojo sync | Files are the source of truth; editing in Studio fights the sync |

A note on Rojo: if your project syncs from files, an agent editing scripts in Studio will have its changes overwritten at the next sync (or will overwrite files if two-way sync is on). Decide which side owns the code and tell the agent. See [[External Tooling - Rojo Wally Selene StyLua]] and [[Code Pipeline - Rojo Git and CI]].

---

## 4. Testing without Play

In a shared Studio, agents should not start Play (it ends everyone's test, and Edit tools stop working while it runs; see [[Safety Rules for AI Agents in Studio]]). The reference project tested almost everything in Edit mode. Techniques:

### 4.1 Pure logic in modules
Damage formulas, odds tables, quest selection, price curves: put them in ModuleScripts with no service dependencies, then call them from `execute_luau` with test inputs. This is the single most valuable architecture choice for agent testing. See [[Testing Strategies and Frameworks]].

```lua
-- Edit-mode test of a pure module, using a fresh copy (not the cached require).
local function freshRequire(m: ModuleScript): any
	local c = m:Clone(); c.Parent = m.Parent
	local ok, r = pcall(require, c); c:Destroy()
	assert(ok, r); return r
end

local Odds = freshRequire(game.ReplicatedStorage.Odds)
local counts = {}
local rng = Random.new(42)
for _ = 1, 100000 do
	local tier = Odds.Roll(rng, 1.0)
	counts[tier] = (counts[tier] or 0) + 1
end
local out = {}
for tier, n in counts do
	table.insert(out, ("%s=%.3f%%"):format(tier, n / 1000))
end
table.sort(out)
return table.concat(out, " ")
```

Keep loops like this under the call budget (100,000 iterations of simple maths is usually well under a second, but measure).

### 4.2 Harnesses with stubs
For code that touches services, an offline harness loads the module's source with `loadstring`, injects stub services (a fake DataStore table, a fake Players list), and runs scenarios. The reference project had harnesses for its quest pool and other systems that ran entirely in Edit.

### 4.3 Client previews in Edit
UI and VFX modules often expose a `Preview` or `Play(..., {Screen = true})` entry that renders in Edit without a running game. In Edit, `RunService:IsClient()` can behave unexpectedly for plugin-context code (Measured with a VFX library: it reported client, and burst `:Emit()` worked while rate-based emission did not run). Know what your preview path really exercises.

### 4.4 Virtual time
Systems driven by time (cooldowns, spawn waves, event schedules) can be tested by injecting a clock function, then stepping it in a loop. A "virtual-time sandbox" in the reference project ran several minutes of VFX timelines in a fraction of a second.

### 4.5 What Edit cannot test
Edit has no physics simulation, no real players, no replication, does not advance animations in ViewportFrames, and runs no server/client split (Measured). Anything relying on those is **not tested** until someone plays. Say so.

---

## 5. When you can use Play

In a Studio that only you (or only this agent) use, the play-test tools are powerful:

1. `start_stop_play` to start.
2. `get_studio_state` to confirm which datamodels exist (Server, Client).
3. `execute_luau` in the **Server** or **Client** datamodel to inspect live state.
4. `character_navigation`, `user_keyboard_input`, `user_mouse_input` to drive the character and UI.
5. `get_console_output` to read errors and warnings.
6. `screen_capture` for what the player sees.
7. `start_stop_play` to stop.

The `subagent` tool can run a `playtest` subagent for a multi-step scenario and return a summary, which keeps the main agent's context clean. For multi-client issues (replication, ownership), see [[Multi-Client and Live Testing]].

Test hooks help. The reference project used ServerStorage attributes read at server start, for example an isolated test profile key (saves go to a test key instead of the real one), forced events, and a dev teleport. The rule: set them only after Play has actually started when they affect saving, and clear them after. See [[Debugger Breakpoints and Logging]].

---

## 6. Debugging with an agent

### 6.1 Start from the log, not the code
`get_console_output` first. The error, the script path and the line number narrow the search from hundreds of scripts to one. Ask the agent to quote the exact error before theorising.

### 6.2 Reproduce in the smallest context
Can the bug be shown by calling one module function in Edit with specific inputs? If yes, that call is your regression test.

### 6.3 Check the stale-module trap first
"I fixed it but it still does the old thing" in Edit is very often the `require` cache ([[Roblox Studio MCP Server]] 5.2), not a wrong fix.

### 6.4 Grep for the pattern, not the instance
When a bug comes from a pattern (a deprecated API, an unsafe remote handler, a reserved name), fix every occurrence. Examples from the reference project:

| Pattern | Problem | Grep |
|---|---|---|
| `RegisterKeyframeSequence` | Temporary ids only play in Studio; abilities did nothing live ([[Case Study - Abilities That Only Worked in Studio]]) | `script_grep "RegisterKeyframeSequence"` before every release |
| Children named like kit remotes (`Origin`, `Attack`, `FX`) | `FindFirstChild` found a clip named `Origin` instead of the RemoteEvent `Origin`; a whole weapon stopped dealing damage | Check names when installing; reserve them |
| `GetAsync` immediately after `SetAsync` | DataStore reads are cached for about 4 s (Measured); a "verify save" read old data | Use `DataStoreGetOptions` with `UseCache = false` for verification reads |

### 6.5 Know what a "fix" needs to prove
- Compiles and passes the gate: necessary, not sufficient.
- Edit-mode test passes: shows the logic is right.
- Play-tested by a human: shows the feature works.

---

## 7. Honest reporting: "not play-tested"

The reference project's most important cultural rule: **an agent reports exactly how a change was verified**. "Compiled, scanned, module test passed, NOT play-tested" is a useful report. "Done, works" is not, because the agent did not see it work. The project's notes carried the line "nothing since (a date) is play-tested: assume every system needs a playtest", and each change listed what the human should check in Play.

A good change report:

```text
Change: quest reroll now refunds gems when the pool is empty.
Files: ServerScriptService.QuestService (one insert near line 410).
Checks: compile OK, use-before-definition scan clean, clone-require OK,
        Edit harness: 3 scenarios pass (empty pool, one left, normal).
Not tested: live UI refresh after refund (needs Play).
Please check in Play: open quests, reroll with an empty pool, gems go back up.
```

See [[Prompting and Verifying AI Output]].

---

## 8. Common mistakes

- Editing from memory instead of a fresh `script_read`.
- Saving without compiling.
- "Testing" with a cached `require`.
- Growing a script past the size limit instead of splitting it.
- Fixing one instance of a pattern instead of grepping for all.
- Starting Play in a Studio someone else is using.
- Reporting "works" for something only compiled.
- Writing in Studio while Rojo owns the files.

## 9. Checklist for an agent scripting change

- [ ] Fresh read of the target and its callers.
- [ ] One focused edit.
- [ ] Gate: compile, use-before-definition, size, clone-require.
- [ ] Edit-mode test of the logic, if possible.
- [ ] Pattern grep for the same bug elsewhere.
- [ ] Report: what changed, how verified, what is not tested, what to check in Play.

## See also

- [[Roblox Studio MCP Server]], [[MCP Workflows for Building Worlds]], [[Safety Rules for AI Agents in Studio]]
- [[Module Scripts and Requiring]], [[Error Handling and Retries]], [[Testing Strategies and Frameworks]]
- [[Debugger Breakpoints and Logging]], [[Multi-Client and Live Testing]], [[AI Code Assistants for Luau]]
- [[Prompting and Verifying AI Output]], [[Case Study - Building a Game with AI Agents]]

## Nuances and edge cases

1. **Compiling is not running.** A script that compiles can still fail on require (a missing dependency, a wrong path, a nil index at the top level), and a script that runs on require can fail only when a specific remote fires. Rank the evidence an agent can produce: compiled, required without error, function called with test inputs in Edit mode, play-tested, tested with several clients. Reports should say which level was reached, as section 7 asks.
2. **Edit-mode tests miss the runtime world.** In Edit mode there are no players, characters, network ownership, replication or real time passing. Logic that depends on those (damage on a moving target, remote validation, saving on leave) cannot be proven without Play. Pure logic modules (maths, config, inventory rules) test well in Edit; design code so more of it is pure and testable that way.
3. **Large scripts and the read window.** An agent reading a 5,000-line script in small windows can miss a second definition of the same function further down, or an early return that makes its edit dead code. Grep for the function name and for every assignment to the variable before editing, not only the lines around the change.
4. **Agents and Team Create.** In Team Create, scripts can be edited by others at the same time, and draft and collaborative editing settings change when edits become visible. An agent's edit can land on top of a human's unsaved work, or the human's later commit can overwrite the agent's. Agree on who owns which scripts during a session, and re-read immediately before each write.
5. **Debugging with logs at scale.** Adding print statements is the agent's default debugging tool. In a busy server loop, one print per frame floods the Output and hides the real error, and console output is limited, so earlier lines scroll away. Log only on state changes, include a short tag, and remove debug prints in the same session.
6. **Fix scope.** An agent asked to fix one bug will often fix it at the call site where it was found. If the root cause is in a shared module, the same bug exists at every other caller. Grep for the pattern and decide deliberately between a local fix and a shared one; a shared fix changes behaviour for every caller and needs wider testing.
7. **Script size limits.** Very large scripts approach the source size limit and become slow to read and risky to edit. Agents tend to append rather than restructure. Set a soft limit well below the hard one and split modules when it is reached.
8. **Human review load.** An agent can produce more diffs per hour than a person can review well. Batch related changes, keep each change small, and make the summary say what was changed, what was checked and what was not.

## More common mistakes

1. **Trusting the agent's memory of an API.** Symptom: code calls a method that does not exist or was renamed. Fix: check the API reference before using unfamiliar members.
2. **Tests that pass because they test nothing.** Symptom: a check reports success even when the function is broken. Fix: make the test fail first (break the code on purpose once) to prove the test can catch it.
3. **Silent pcall wrappers added "for safety".** Symptom: errors disappear and features stop working with nothing in Output. Fix: pcall only where failure is expected, and always log the error.
4. **Leaving debug toggles on.** Symptom: test-only cheats or verbose logs ship to players. Fix: one debug flag, checked in a single place, defaulted off and asserted off in release checks.
5. **Editing generated or synced files.** Symptom: changes vanish on the next sync or generation. Fix: find the source of truth first (Rojo files, generator, sheet).
6. **Fixing the symptom.** Symptom: the same bug returns in a new form. Fix: write the cause in the report, not only the change.

## Related decisions

- [[The Debugging Method - Reproduce Isolate Bisect]]: the method agents should follow instead of guessing.
- [[Reading Luau Errors and Stack Traces]]: turning Output errors into the right file and line.
- [[Automated Testing with TestEZ and Jest-Lua]]: real tests agents can run instead of ad hoc checks.
- [[Code Review for Luau Teams]]: reviewing agent diffs like any other contribution.
- [[Team Create Permissions and Workflows]]: avoiding collisions with human editors.
- [[Debugging Race Conditions and Yield Order]]: bugs Edit-mode tests cannot show.
- [[Module Design and Dependency Injection]]: making code testable without Play.
- [[Prompting and Verifying AI Output]]: asking for the evidence level, not just a fix.

## Connected notes
<!-- auto-links:start -->
[[Roblox Studio Assistant]] · [[Agent Review Loops and Guardrails in Practice]] · AI Agents and Autonomous Workflows · Skill - Roblox Debugging · Pipeline Design Principles · Batch Processing Tools in Studio
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[AI Agents and Autonomous Workflows]] · [[Built-In Studio MCP vs Community MCP Servers - Migration Guide]] · [[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]] · [[Writing Your Own MCP Server]] · [[What Is MCP]] · [[Setting Up MCP Clients]] · [[Agent Handoff Notes - Project State and Resume Templates]] · [[Blender MCP]]
<!-- related:end -->
