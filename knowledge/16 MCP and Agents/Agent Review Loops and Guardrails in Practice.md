---
tags: [agents, mcp, guardrails, review, hooks, permissions, verification, claude-code]
---
# Agent Review Loops and Guardrails in Practice

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: All rules in the instructions file -> Promote to permissions, hooks, gates
> - Avoid: Hook exits 1 to "block" -> Exit 2 for policy hooks
> - Avoid: Denying the dangerous tool but allowing raw code execution unchecked -> Content hook on code execution
> - Each rule placed in the strongest layer that can express it.
> - Permissions: deny banned tools, ask on broad writes, allow read-only.
> - PreToolUse hook on code execution: undo, play control, unbounded loops, bulk deletes; exits 2; logs blocks.
>
> Read more (24 KB note): ## 3. Hooks: deterministic checks on content · ## 5. Review loops that work · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Safety Rules for AI Agents in Studio]] lists the rules an agent working in Roblox Studio should follow: Edit mode only, short calls, no undo, snapshot first, the save gate, honest reporting. This note is about **making those rules hold** when nobody is watching every call. Rules written in an instructions file are requests; a tired model at hour three of a long session, or a model that has compacted its context, can drop them. The fix is layered guardrails that do not depend on the model remembering, plus review loops that catch what slips through.

It covers the guardrail layers and what each can and cannot stop, concrete permission rules and hook scripts for Claude Code with the Roblox Studio MCP server (as of October 2026), a scripted save gate, the shapes of review loops that work (and the ones that rubber-stamp), definitions of done, the reference project's incidents and the guardrail each one produced, and the metrics that tell you whether the loop is working.

Source labels: **Claude Code docs (as of October 2026)**, **Roblox docs**, **measured in the reference project** (a production Roblox game built with heavy use of AI coding agents connected to Studio and Blender through MCP), **rule of thumb**.

---

## 1. Defence in depth: the layers

No single layer is enough. Each has a different strength and a different way of failing.

| Layer | Example | Strength | Fails when |
|---|---|---|---|
| **Instructions** | Project instructions file: "never start Play", "one call under 1.5 s" | Cheap; covers everything, including judgement calls | The model forgets, misreads, or a long context pushes it out |
| **Tool scoping** | Only connect the MCP servers the task needs | Removes whole classes of risk | You need the tool for something legitimate |
| **Permissions** | Deny `start_stop_play`; ask before `multi_edit` | Enforced by the host, not the model | Rules are too broad (prompt fatigue) or too narrow (another tool does the same thing) |
| **Hooks** | A script inspects every `execute_luau` call and blocks forbidden patterns | Deterministic; can check content, not just tool names | Patterns are evadable; slow hooks slow every call |
| **Automated gates** | Compile, scan, size limit, tests before a script is saved | Catches whole categories of bugs every time | Only checks what you thought of |
| **Review** | A second agent or a human reviews the diff | Catches design and logic errors | Reviewer anchored on the author's summary; fatigue |
| **Environment** | Test place copy, version history, git, snapshots | Makes mistakes recoverable | Nobody checked the restore path works |
| **Human acceptance** | Play-test by a person before shipping | The only check of how it *feels* | Skipped under time pressure |

The rule of thumb that follows: **put each rule in the strongest layer that can express it**. "Never start Play" is a tool name: a permission deny. "Never call undo" is a code pattern: a hook. "Compile before saving" is a check: a gate. "Do not touch the other agent's area" is judgement: instructions plus review. Leaving all of them in the instructions file is how rules get broken.

---

## 2. Permissions: the cheapest hard layer

Claude Code reads permission rules from settings files (user, project, local, managed). MCP tools are named `mcp__<server>__<tool>`, where `<server>` is the name you registered the server under; check yours with `/mcp` or the tool list. With the Studio server registered as `Roblox_Studio`, a project `.claude/settings.json` might hold:

```json
{
  "permissions": {
    "deny": [
      "mcp__Roblox_Studio__start_stop_play",
      "mcp__Roblox_Studio__insert_asset",
      "mcp__Roblox_Studio__generate_mesh",
      "mcp__Roblox_Studio__generate_procedural_model",
      "mcp__Roblox_Studio__generate_material"
    ],
    "ask": [
      "mcp__Roblox_Studio__multi_edit",
      "mcp__Roblox_Studio__upload_image"
    ],
    "allow": [
      "mcp__Roblox_Studio__get_studio_state",
      "mcp__Roblox_Studio__search_game_tree",
      "mcp__Roblox_Studio__inspect_instance",
      "mcp__Roblox_Studio__script_read",
      "mcp__Roblox_Studio__script_grep",
      "mcp__Roblox_Studio__get_console_output"
    ]
  }
}
```

The tool names above are those exposed by the Studio MCP server as of October 2026 (see [[Roblox Studio MCP Server]]); they change, so list your server's tools before copying this.

Why this shape:

- **Deny** what your project has decided never to do: Play (the human playtests; starting or stopping Play while someone else is testing breaks their session), foreign assets, generation tools your art direction has banned. The reference project banned generated meshes and foreign Toolbox assets outright.
- **Ask** for broad writes. An "ask" puts a human in the loop exactly where the blast radius is large.
- **Allow** read-only tools so the agent can look around freely. Every prompt for a harmless read trains the human to click "yes" without reading, which destroys the value of the prompts that matter.

The gap in this layer: `execute_luau` can do anything any other tool can, including starting a play test from code or deleting the workspace. Denying it removes most of the agent's usefulness; allowing it blind removes most of the permission layer's value. That is what hooks are for.

One more rule from practice: **when the host blocks something, the agent stops and reports.** The reference project's agent host refused some actions (a deletion, a QA play step, some script writes). Each refusal was a moment a human needed to look; an agent that searches for another route to the same effect defeats the guardrail.

---

## 3. Hooks: deterministic checks on content

Claude Code hooks are commands that run at lifecycle events. As of October 2026 the documented events include `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, `UserPromptSubmit`, `SessionStart` and many more (Claude Code docs). The parts that matter here (Claude Code docs):

- A hook receives a JSON description of the event on standard input; for tool events that includes the tool name and its input.
- **Exit 0**: proceed (optionally with JSON output). **Exit 2**: a blocking error; for `PreToolUse` it blocks the call, and the hook's stderr is fed back to the model. **Any other exit code** is a non-blocking error: the action goes ahead. The docs warn explicitly: "If your hook is meant to enforce a policy, use `exit 2`."
- `PostToolUse` cannot undo a call (the tool already ran), but exit 2 shows stderr to the model, which is how you feed a failed check back into the loop.
- Matchers select tools by name; strings with characters other than letters, digits, `_`, `-`, spaces, `,` and `|` are treated as unanchored regular expressions, so wrap with `^...$` when you need an exact match.

### A PreToolUse guard for `execute_luau`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "^mcp__Roblox_Studio__execute_luau$",
        "hooks": [
          { "type": "command", "command": "python .claude/hooks/luau_guard.py" }
        ]
      }
    ]
  }
}
```

```python
# .claude/hooks/luau_guard.py : block risky patterns in code sent to Studio.
# Speed bump, not a sandbox: obfuscated code can evade string checks.
import json, re, sys

event = json.load(sys.stdin)
tool_input = event.get("tool_input", {})
# The Studio server's execute_luau takes "code" and "datamodel_type" (as of October 2026).
code = str(tool_input.get("code", ""))
target = tool_input.get("datamodel_type", "Edit")

RULES = [
    (r"ChangeHistoryService.*:\s*Undo", "Undo is forbidden: the undo stack is shared. Snapshot and restore instead."),
    (r"\bRunService\b.*:\s*(Run|Stop|Pause)\s*\(", "Never start or stop play from code; the human playtests."),
    (r"\bwhile\s+true\s+do\b", "Unbounded loop: Studio calls must finish quickly. Slice the work."),
    (r"workspace\s*:\s*ClearAllChildren", "Bulk delete of Workspace is not allowed."),
]

problems = []
if target != "Edit":
    problems.append("Edit mode only: do not run code in a Client or Server play datamodel.")
for pattern, message in RULES:
    if re.search(pattern, code, re.IGNORECASE | re.DOTALL):
        problems.append(message)

if len(code) > 20000:
    problems.append("Call is very large; big setup scripts should be installed by the human or sliced.")

if problems:
    print("Blocked by luau_guard:\n- " + "\n- ".join(problems), file=sys.stderr)
    sys.exit(2)
sys.exit(0)
```

Notes on this design:

- **It is a speed bump.** `game:GetService("Change" .. "HistoryService")` walks straight past it. Its job is to catch the *honest mistake*, which is what agents make, not to stop an adversary. Pair it with environment protection (snapshots, version history).
- **Messages are instructions.** The stderr text goes back to the model, so write it as the fix: "Snapshot and restore instead" teaches the right behaviour in the moment.
- **Keep hooks fast.** They run on every matching call. A hook that takes a second doubles the cost of a 1-second Studio call. Pure string checks take milliseconds.
- **Check arguments, not only code.** The `datamodel_type` check enforces "Edit mode only" from the call's own parameters, which no amount of code obfuscation can evade.
- **Avoid broad patterns.** A rule that blocks every `Destroy()` would block legitimate cleanup and train people to turn the hook off. False positives are the fastest way to lose a guardrail.
- **Log what you block.** Append blocked calls to a file; the log tells you which rules fire and whether any are noise.

### A PostToolUse check for files

When the agent edits Luau files in a file-based project (Rojo), run your linters after every edit and feed failures back:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "python .claude/hooks/lint_luau.py" }
        ]
      }
    ]
  }
}
```

The script reads the edited path from the event, runs `selene` and a strict type check on `.luau` files only, prints the errors to stderr and exits 2 when there are any. The model sees the errors immediately and fixes them in the same turn, which is far cheaper than finding them at review. See [[External Tooling - Rojo Wally Selene StyLua]] and [[Code Pipeline - Rojo Git and CI]].

### A Stop hook as the definition of done

A `Stop` hook runs when the agent is about to finish. Returning a top-level `"decision": "block"` with a `reason` tells it to keep working (Claude Code docs). Used carefully, this turns "done" into a checked state: the hook looks for a fresh gate report (for example, a file the save gate writes with a pass result and a timestamp newer than the last edit) and blocks the stop with the reason "the save gate has not passed since your last edit" if it is missing.

Two cautions. First, guard against loops: the docs provide a field indicating the hook is already active from a previous block; check it (and the current docs) and let the agent stop after one forced continuation, so a broken gate cannot trap a session. Second, a Stop hook enforces *that checks ran*, not that the work is right. It is a floor, not a review.

---

## 4. The save gate as code

The save gate is the one automated check every Studio script change should pass. In the reference project it was: compiles, use-before-definition scan returns nothing, `Source` under the 200,000 character limit, and modules clone-require without error; on failure, revert. A Studio-side module makes it one call:

```lua
--!strict
-- SaveGate: run before writing any script Source from an agent or tool.
-- Lives in ServerStorage.DevTools. Edit mode, command bar or plugin context.
export type Result = { ok: boolean, problems: { string } }

local MAX_SOURCE = 200000 -- Script Source hard limit (measured in the reference project)

-- Names that collided with existing instances in the reference project and broke lookups.
local RESERVED = { Attack = true, Origin = true, FX = true, LocalCast = true, Moves = true }

local SaveGate = {}

function SaveGate.check(source: string, newChildNames: { string }?): Result
	local problems: { string } = {}

	if #source >= MAX_SOURCE then
		table.insert(problems, ("Source is %d characters; limit is %d. Split into a module."):format(#source, MAX_SOURCE))
	end

	-- Compile only; never run the chunk here.
	local fn, err = loadstring(source)
	if not fn then
		table.insert(problems, "Does not compile: " .. tostring(err))
	end

	for _, name in newChildNames or {} do
		if RESERVED[name] then
			table.insert(problems, ("Name '%s' is reserved in this project (it shadows an existing child)."):format(name))
		end
	end

	return { ok = #problems == 0, problems = problems }
end

-- Modules: require a fresh clone, because require() in Edit returns a cached copy of the original.
function SaveGate.cloneRequire(module: ModuleScript): (boolean, any)
	local clone = module:Clone()
	clone.Parent = module.Parent
	local ok, result = pcall(require, clone)
	clone:Destroy()
	return ok, result
end

return SaveGate
```

The reserved-name list is the reference project's: an animation clip named `Origin` once replaced a kit's `Origin` RemoteEvent in a child lookup and broke all damage for that kit. Your list will differ; the point is that every incident becomes a check. A use-before-definition scanner is project tooling (a parser pass that flags locals used above their `local` line); it is worth writing because those bugs compile fine and crash at runtime.

`loadstring` availability depends on context: it works in the command bar and plugins; in game scripts it requires `ServerScriptService.LoadStringEnabled`. Run the gate from tooling, never from shipped code.

---

## 5. Review loops that work

Automated checks catch categories. Reviews catch the rest: wrong design, wrong trust boundary, wrong assumptions about the game. Four loop shapes, from cheapest to most expensive:

| Loop | How | Catches | Misses |
|---|---|---|---|
| **Self-check with tools** | The agent runs the gate, probes values in Edit, re-reads the script from Studio after writing | Syntax, stale writes, wrong paths, broken references | Anything it does not think to check |
| **Automated gate** | Hooks and the save gate | Every mechanical error it encodes | Design and logic errors |
| **Independent reviewer** | A second agent with fresh context reviews the diff against the spec | Logic errors, missed cases, security holes | Anything the spec does not describe; how it feels |
| **Human acceptance** | The owner play-tests the listed checks | Feel, fun, real-device problems | Rare edge cases nobody tried |

### Making the reviewer independent

The biggest failure of agent review is **anchoring**: the reviewer reads the author's confident summary ("implemented session locking with retries; all edge cases handled") and agrees. Rules that prevent it:

- **Give the reviewer the diff and the spec, not the author's conclusions.** Not "check that my fix works", but "here is the requirement and the change; find what is wrong".
- **Ask for failures with evidence.** "List concrete defects with the line and the input that triggers each. If you find none, say which cases you checked."
- **Give it the project's rules.** A reviewer that does not know about the 200,000 character limit or the server-authority rules cannot enforce them. Point it at [[Server Authority and Validation]] and the project instructions.
- **Bound the loop.** Two or three review rounds at most. Beyond that, author and reviewer start trading opinions; escalate to a human with both views.
- **Review what is risky, not everything.** Trust-boundary code (remotes, currency, saves, purchases), destructive operations and shared modules deserve review. A UI colour change does not.

### Making human acceptance cheap

The human's time is the scarcest resource. The agent's report should make acceptance a checklist, not an investigation:

```
Changed:   ShopService.purchase (server), ShopController (client), GameConfig.Items.Sword12
Verified:  compiles; gate passed; clone-require OK; Edit probe: price 2500 read from config;
           remote rejects unknown item id (tested by calling the handler with a fake id)
NOT verified (needs Play): purchase flow end to end; UI refresh after buying; phone layout
Risks:     touches the shared purchase path; one safety copy in ServerStorage.WIP.SHOP
Revert:    restore ServerStorage.WIP.SHOP.ShopService_pre; or version history before 14:20
Check in Play: buy Sword12 with enough coins; try with too few; rejoin and confirm it saved
```

The reference project's convention was a plain label on every change that could not be tested by the agent: "Edit-verified, not play-tested". It sounds minor; it is the difference between a human who knows what to check and one who assumes it was checked. See [[MCP Workflows for Scripting and Debugging]].

---

## 6. Verifying without Play

Agents in a shared Studio usually cannot (and should not) run Play. Verification has to happen in Edit and offline:

- **Numeric probes instead of screenshots.** Captures in the reference project returned a black 3D view when Studio was not focused and could time out; the rule was to retry once, then verify numerically (positions, counts, property values) and say so in the report.
- **Harnesses.** For systems with many variants, a harness that exercises each variant in Edit and counts failures. The reference project's effects harness ran all 113 ability kits through a stylised effect switch with 0 failures and recorded peak counts per kit (up to 18 element meshes, 28 emitters, 4 lights), while still labelling the rollout "not play-tested".
- **Know what Edit cannot do.** In Edit there is no physics, rate-emitted particles do not run, `require` returns cached modules, and animations in ViewportFrames do not advance (measured in the reference project). A check that depends on any of these proves nothing in Edit.
- **Read back after writing.** Re-read the script source or instance properties after every write. Shared places have other writers; your write may have been overwritten or may have failed silently.

---

## 7. Incidents become guardrails

Every guardrail in the reference project traces to an incident. Recording the incident with the rule is what keeps the rule from being "simplified away" later.

| Incident (reference project) | Guardrail it produced | Layer |
|---|---|---|
| An undo to recover terrain went about 40 waypoints back and rolled back other sessions' work | Never use undo; snapshot first (terrain via `CopyRegion`) | Hook (pattern) plus instructions |
| Studio froze for about 25 minutes at full CPU with about 18 offline bakers plus in-Studio simulations | One Studio call at a time, each under about 1.5 s; at most 2 offline processes per agent with thread counts pinned to 1 | Instructions plus hook (unbounded loops) plus tool design |
| An animation clip named `Origin` replaced a RemoteEvent in a lookup and broke a kit's damage | Reserved names list | Save gate |
| A combat script approached the 200,000 character limit | Size check; extend through a separate API module instead | Save gate |
| Edits to a module were invisible to tests | Clone-require before trusting module state | Save gate |
| An Edit preview left the place's Atmosphere changed, and the mood controller read it as the base at Play start | Previews restore everything they touch | Instructions plus snapshot helper |
| Camera left Scriptable after a positioned capture | Restore camera after captures, confirm in a second call | Instructions |
| Backup folders inside the place grew to hundreds of thousands of instances and slowed Studio | Backups go to disk or version history; one safety copy per pass, deleted after verification | Instructions plus review |
| Another session's code overwritten | Compare Studio source with your base before writing; stay in owned areas | Instructions plus read-back |

Most of these rules live in instructions because they need judgement. The ones that can be checked mechanically (undo, loops, size, names, compile) moved into hooks and gates. That is the general pattern: **promote a rule to a harder layer as soon as it can be expressed there.**

---

## 8. Is the loop working? Metrics

Without numbers, review loops decay into ritual. Track a few:

| Metric | How | What it tells you |
|---|---|---|
| **Gate catch count** | Count gate failures per week, by rule | Which mistakes agents keep making; candidates for better instructions or tooling |
| **Hook block log** | Blocked calls with the matching rule | False positives (rules to fix) and real saves |
| **Escape rate** | Bugs found in play tests or live per accepted change | Whether review and gates are deep enough |
| **False "done" rate** | Reports claiming verification that did not happen | Honesty of reporting; tighten the report template or the Stop hook |
| **Reverts** | Changes rolled back | Cost of mistakes that got through |
| **Human review time** | Minutes per accepted change | Whether reports make acceptance cheap |

Rule of thumb: if gate catches are rising while escapes stay flat, the gates are working. If escapes rise, add a check at the layer the escape should have been caught in, and write down the incident.

---

## 9. When guardrails hurt

- **Prompt fatigue.** If the human is asked to approve dozens of harmless calls, they stop reading. Allow read-only tools; ask only where the blast radius is real.
- **False positives.** A hook that blocks legitimate work gets disabled, and then protects nothing. Keep rules narrow and log them.
- **Slow hooks.** Every millisecond multiplies by every call. Keep hooks to string checks and fast linters.
- **Review theatre.** A reviewer that always approves is worse than none, because it creates false confidence. Check its output: if it never finds anything, the prompt or the context is wrong.
- **Guarding the wrong layer.** No hook will stop a design mistake. Architecture decisions belong to a human with the spec.
- **Solo prototypes.** A one-day jam prototype in a throwaway place does not need a Stop hook and a reviewer. Scale the guardrails to the blast radius: shared place, live game, player data.

---

## Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| All rules in the instructions file | Rules dropped in long sessions | Promote to permissions, hooks, gates |
| Hook exits 1 to "block" | Action goes ahead (non-blocking error) | Exit 2 for policy hooks |
| Denying the dangerous tool but allowing raw code execution unchecked | Same effect through `execute_luau` | Content hook on code execution |
| Reviewer given the author's summary | Anchored approval | Diff plus spec; ask for defects with evidence |
| Endless review rounds | Churn, no decision | Two or three rounds, then a human |
| "Done" without saying what was not tested | Human assumes it was checked | "Not verified" section; "not play-tested" label |
| Working around a permission denial | Guardrail defeated at the moment it mattered | Stop and report |
| Incidents fixed but not recorded | Rules later removed as "unnecessary" | Incident next to each rule |

## Checklist

- [ ] Each rule placed in the strongest layer that can express it.
- [ ] Permissions: deny banned tools, ask on broad writes, allow read-only.
- [ ] PreToolUse hook on code execution: undo, play control, unbounded loops, bulk deletes; exits 2; logs blocks.
- [ ] PostToolUse lint on file edits feeding errors back.
- [ ] Save gate: compile, scan, size, reserved names, clone-require.
- [ ] Optional Stop hook requiring a fresh gate pass, with loop protection.
- [ ] Independent reviewer for trust-boundary and shared code; bounded rounds.
- [ ] Report template: changed, verified, not verified, risks, revert, what to check in Play.
- [ ] Incidents recorded next to the rules they produced.
- [ ] Metrics: gate catches, hook blocks, escapes, false-done rate.

See also: [[Safety Rules for AI Agents in Studio]], [[Roblox Studio MCP Server]], [[Setting Up MCP Clients]], [[MCP Workflows for Scripting and Debugging]], [[Multiple Agents in One Studio]], [[Case Study - Building a Game with AI Agents]], [[AI Agents and Autonomous Workflows]], [[Prompting and Verifying AI Output]], [[Evaluating AI Tools - A Practical Rubric]], [[Safe Changes in a Shared Place]], [[Testing Strategies and Frameworks]].

## Connected notes
<!-- auto-links:start -->
[[Working with AI Assistants in Studio]] · [[Code Review for Luau Teams]] · [[What Is MCP]] · [[Roblox Studio Assistant]] · [[AI Skills Start Here]] · [[AI Code Assistants for Luau]]
<!-- auto-links:end -->
