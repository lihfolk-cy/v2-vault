---
tags: [ai, studio, assistant, mcp, workflow]
---
# Roblox Studio Assistant

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Starting every task in the same long chat.
> - Avoid: Accepting a plan without reading which scripts it touches.
> - Avoid: Letting Assistant insert Creator Store assets without inspecting their scripts.
> - New chat for a new task, with a conventions brief.
> - Planning Mode for anything that touches more than one script.
> - Snapshot before risky edits; no undo in shared places.
>
> Cost: TL;DR ~140 tok · whole note ~4.0k tok. Read more: ## 3. Slash commands and tools · ## 5. Using Assistant well · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox Assistant is the AI helper built into Roblox Studio. Roblox's own guide describes it as something that "helps you build games faster by answering questions, generating content, and performing actions directly in Studio". It is a large language model joined to a set of tools that act on your open place: reading and writing scripts, creating and deleting instances, inserting assets, generating meshes and materials, capturing the viewport and, in beta, play-testing.

This note covers what Assistant can do as of October 2026, how it works underneath, how to use it well, and where it fails. For the general overview of Studio's AI features see [[Studio Assistant and AI Tools]]; for using external AI clients against the same tools, see [[Roblox Studio MCP Server]].

Everything here was checked against the Roblox Creator Hub (Assistant guide, Studio MCP page, "Accelerated workflows" AI overview) and Roblox DevForum announcements in October 2026. Assistant changes often. Re-check anything you rely on.

---

## 1. What it is, mechanically

Assistant has three layers:

1. **A chat model.** By default Roblox chooses and runs the model. You can instead add your own API keys and pick models from Anthropic, OpenAI or Google (Roblox docs: Assistant, "..." menu, Manage API Keys). With your own key, usage bills to your provider account.
2. **Tools.** The same tool family that Studio exposes through its built-in MCP server: script read, search, grep and multi-edit; instance search and inspection; `execute_luau`; console output; play state; asset search and insert; mesh, material and procedural model generation; image upload; screen capture; character navigation; keyboard and mouse input. See section 3.
3. **Subagents.** Separate model runs with their own context, used for focused jobs: a screen capture subagent (answers visual questions from viewport captures in Edit and Play), an explore subagent, and a playtest subagent (beta).

A useful mental model: Assistant is a coding agent whose "file system" is your place's data model. Everything it does is a tool call you could in principle have made yourself in the command bar.

### Chats and context

From the guide:
- You can have multiple chats per place, saved to the cloud.
- "Each chat has its own context window." Long chats eventually lose early detail.
- Chats are scoped to the place, not the experience.
- There is no hard limit on chats per place; deleted chats cannot be recovered.

**Rule of thumb.** Start a new chat per task. A chat that has been through three unrelated features carries stale assumptions about code that has since changed.

---

## 2. Planning Mode

Planning Mode makes Assistant write a plan before it acts. Turn it on from the input panel dropdown (Plan) or type `/plan`.

From the guide:
- Plans are saved as editable Markdown documents.
- "Plans never auto-execute or time out into acceptance."
- "The workflow only executes when you click Build in the Assistant chat."

**When to use it.** Any change that touches more than one script, creates remotes, or changes data. Read the plan as you would read a pull request description: does it name the right scripts? Does it say where validation happens (server)? Does it create new remotes when existing ones would do? Edit the Markdown, then Build.

**What plans miss.** A plan is the model's guess about your place. It will not know about conventions you never wrote down (your reserved names, your remote naming, the one module nobody may touch). Put those in the plan yourself.

---

## 3. Slash commands and tools

### Slash commands listed in the guide (October 2026)

| Command | What it does | Limits from the guide |
|---|---|---|
| `/generate_mesh` | Generates a textured mesh from a text prompt or an image (not both) | Default maximum 10,000 triangles; you can set a lower cap for a more faceted look |
| `/generate_procedural_model` | Builds a model from primitive parts that responds to attributes | Up to 50 per rolling 24 hours; placed in a dedicated `GeneratedFolder` |
| `/insert_asset` | Searches the Creator Store and your inventories, filtered by type and price, and offers choices before inserting | You choose; nothing is placed until you pick |
| `/segment_mesh` | Splits a selected MeshPart into named parts ("early preview") | Up to 8 parts per generated model; up to 5 names per run, repeatable |
| `/plan` | Planning Mode | Never auto-executes |
| `/generate_texture` | Texture Generator on the selected mesh (listed on the Texture Generator page) | Fast 1K or Quality 4K; see [[AI Material and Texture Generation]] |

The guide also mentions "quick styling with lightweight material generation" (MaterialVariants).

### The underlying tools

The Studio MCP page lists 26 built-in tools that external clients get. Assistant uses the same family. The ones that matter most day to day:

| Tool | What it does | Notes |
|---|---|---|
| `script_read`, `script_search`, `script_grep` | Read and find scripts | Search returns up to 10 results; grep up to 50 matches |
| `multi_edit` | Several edits to one script, creating it if missing | Needs a datamodel type |
| `search_game_tree`, `inspect_instance` | Explore the hierarchy, read one instance's properties and attributes | Cheaper than dumping the tree |
| `execute_luau` | Runs Luau in Edit, Client or Server | The most powerful and most dangerous tool |
| `get_console_output` | Reads the Output window | Use after every run |
| `get_studio_state`, `start_stop_play` | Play state; start or stop a play test | Stopping Play in a shared session interrupts others |
| `screen_capture` | Viewport image, optional camera position and target | See the camera gotcha below |
| `character_navigation`, `user_keyboard_input`, `user_mouse_input` | Drive a test character | Used by play-testing |
| `search_asset`, `insert_asset` | Creator Store and inventory | Third-party code risk; see [[Creator Store and Toolbox Safety]] |
| `generate_mesh`, `generate_material`, `generate_procedural_model`, `wait_job_finished` | Generation jobs | Asynchronous; may fail or be rate limited |
| `upload_image`, `store_image` | Upload images from URLs; load a local image | Uploads go through moderation |
| `subagent` | Launch an explore or playtest subagent | Separate context |
| `http_get` | Fetch allowed Roblox documentation pages | Lets it check the docs |

---

## 4. The playtest subagent (beta)

Announced on the DevForum in April 2026 as a Studio beta ("Studio Assistant & MCP Playtest Agent"). Enable it under File > Beta Features > Playtest Agent.

What it does (from the announcement):
- Spawns a test character and runs a gameplay scenario in its own context, so the main chat's context stays clean.
- Runs on a separate model operated by Roblox, not your tokens.
- Returns Pass, Fail, Inconclusive or Error, with a structured report of actions and observations.
- Can batch several playtests, for example read from a file, as a regression suite.

Official limitations:
- **False passes**: a test can pass where a human would see a problem.
- Needs clear, experience-specific instructions; vague ones give unpredictable results or Error.
- Limited observability.
- A daily usage cap specific to the playtest agent (number not published).
- Tests abort after 50 turns; loop detection ends a test after several identical tool calls in a row.
- No real-time reflexes: steering and hard combat may fail.

Roblox itself advises against relying only on the playtest subagent to verify gameplay.

**How to use it well.** Write the test like a QA script with observable outcomes: "Equip the sword from slot 1. Attack the dummy at the arena centre three times. Pass if the dummy's Health attribute is lower than 100 and the Output shows no errors." Observable state (attributes, leaderstats, Output lines) beats "check that it looks right".

**Shared place warning.** A play test started in a session other people use takes the place out of Edit mode for everyone's tools. The reference project's top rule was "never start or stop Play; the owner play-tests". If you share a place, agree who may run play tests and when. See [[Safety Rules for AI Agents in Studio]].

---

## 5. Using Assistant well

### Give it the conventions

Assistant does not know your project's rules. Start a task with a short brief:

```
Project conventions:
- Server authority: the server validates every remote; clients only request.
- Remotes live in ReplicatedStorage.Remotes, named <System><Action>.
- Use task.wait/task.spawn/task.delay, never wait/spawn/delay.
- Typed Luau with --!strict on new modules.
- Never name a child "Attack", "Origin" or "FX" inside a kit folder (reserved).
- Do not edit ServerScriptService.CombatService (near the 200,000 character Source limit); extend CombatAPI instead.
Task: ...
```

The reference project kept rules like these in a project notes file that every agent read first. The single most valuable line in it was a list of things never to do.

### Ask for the check, not just the change

"Add a cooldown to the dash" produces code. "Add a cooldown to the dash, then show me where the server enforces it and run a compile check" produces code plus evidence. See [[Prompting and Verifying AI Output]].

### Keep calls short in Edit

`execute_luau` runs synchronously in Studio. A long loop freezes the editor for everyone in the session. The reference project measured this the hard way: with many heavy processes plus in-Studio simulations, Studio froze for about 25 minutes. Its rule became one Studio call at a time, each under about 1.5 seconds, with long jobs sliced into resumable steps:

```lua
-- A resumable sliced job: call repeatedly until it returns "DONE".
local BUDGET = 0.9 -- seconds of work per call (rule of thumb from the reference project)

local state = _G.MySlicedJob or { i = 1 }
_G.MySlicedJob = state

local items = workspace.Props:GetChildren()
local t0 = os.clock()
while state.i <= #items do
	local item = items[state.i]
	if item:IsA("BasePart") then
		item.CastShadow = item.Size.Magnitude > 4
	end
	state.i += 1
	if os.clock() - t0 > BUDGET then
		return ("stopped early at i=%d of %d"):format(state.i, #items)
	end
end
_G.MySlicedJob = nil
return "DONE"
```

### Capture gotchas

From the reference project (measured, October 2026):
- `screen_capture` returns a black 3D view when Studio is not the focused window. Retry once, then verify numerically (positions, counts, bounds) and say so.
- A capture with a camera position can leave the Edit camera as `Scriptable`. Restore it: `task.delay(0.6, function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)`, then confirm in a second call.
- Particle bursts and rate emitters do not show in Edit captures the way they do in Play.

### `require` caches in Edit

Calling `require` from Studio tooling returns a cached copy. After an edit, a plain `require` may still return the old module. The reference project read current module state by cloning the ModuleScript beside the original, requiring the clone, then destroying it:

```lua
local function freshRequire(module: ModuleScript): any
	local clone = module:Clone()
	clone.Parent = module.Parent -- same parent so relative requires inside still resolve
	local ok, result = pcall(require, clone)
	clone:Destroy()
	if not ok then
		error(("fresh require of %s failed: %s"):format(module:GetFullName(), tostring(result)))
	end
	return result
end
```

---

## 6. Where Assistant fails

| Failure | What it looks like | Why | Fix |
|---|---|---|---|
| Invented members | A property or method that does not exist, or an enum value with a plausible name | Model memory, not lookup | Ask it to check with `http_get` on the docs; read the reference page yourself |
| Deprecated patterns | `wait()`, `spawn()`, `Humanoid:LoadAnimation`, `BodyVelocity` | Training data age | Put "modern APIs only" in the brief; lint for them |
| Client/server confusion | Server code reading `Players.LocalPlayer`, client code changing currency | Missing context on where the script runs | Ask for the RunContext and the trust boundary explicitly |
| Works in Studio only | Uses Studio-only ids or timing | It tested in Studio | Require a live-server test before "done"; see [[Case Study - Abilities That Only Worked in Studio]] |
| Silent partial edits | It edited 3 of 5 scripts and stopped | Context limit or a failed tool call | Ask for a list of every file changed and re-grep |
| Overwriting others' work | A script edited by someone else minutes ago is replaced with an older version plus its change | It read the script earlier in the chat | Re-read immediately before editing; compare with your last known version |
| Toolbox inserts | A free model with hidden scripts appears | `/insert_asset` from the Creator Store | Inspect every inserted script; prefer your own inventory |
| Generated art off style | Proportions or style do not match | Generation is generic | Use for placeholders only |
| Confident "done" | It reports success after a compile check only | It cannot see live play | Make it state how it verified |

### The undo hazard

Assistant and MCP tool calls create ChangeHistory waypoints. In a session shared by several people or agents, the undo stack is shared. The reference project lost other people's work when an agent used undo to recover terrain: it went about 40 waypoints back and rolled back unrelated changes, and every later `execute_luau` call added a waypoint that wiped the redo stack. Rule: never use undo to recover in a shared place. Snapshot first (clone, `Terrain:CopyRegion`, or save a `.rbxm` to disk) and restore from the snapshot.

---

## 7. Assistant versus an external coding agent

| Need | Assistant | External agent (Claude Code, Cursor, Codex CLI, Gemini CLI and others) via MCP |
|---|---|---|
| Setup | None | Enable Studio as MCP server, connect client (see [[Setting Up MCP Clients]]) |
| Model choice | Roblox default, or your own keys for Anthropic, OpenAI or Google | Whatever your client supports |
| Files on disk, Git, offline tools | No | Yes: Python, Blender, local servers, tests |
| Long multi-step projects | Good within a chat; plans help | Better: project memory files, scripted pipelines |
| Cost | Free within unpublished daily limits, or your keys | Your subscription or API usage |
| Risk to shared place | Same tools, same risks | Same tools, plus faster at making mistakes at scale |

Many teams use both: Assistant for quick in-place questions and edits; an external agent for project-wide work with version control.

---

## Common mistakes

- Starting every task in the same long chat.
- Accepting a plan without reading which scripts it touches.
- Letting Assistant insert Creator Store assets without inspecting their scripts.
- Running long `execute_luau` loops in a shared session.
- Using undo in a shared place.
- Treating a compile check as proof that gameplay works.
- Asking for "make it better" with no measurable target.

## Checklist

- [ ] New chat for a new task, with a conventions brief.
- [ ] Planning Mode for anything that touches more than one script.
- [ ] Snapshot before risky edits; no undo in shared places.
- [ ] Each Studio call short; long jobs sliced.
- [ ] Every edited script compiled and re-read after the edit.
- [ ] Live-server or play test before "done", or an explicit "not play-tested".

## See also
[[Studio Assistant and AI Tools]] · [[Roblox Studio MCP Server]] · [[Setting Up MCP Clients]] · [[MCP Workflows for Scripting and Debugging]] · [[Safety Rules for AI Agents in Studio]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]] · [[AI Material and Texture Generation]] · [[Prompting and Verifying AI Output]] · [[Command Bar and Studio Scripting]]

## Connected notes
<!-- auto-links:start -->
[[AI Agents and Autonomous Workflows]] · [[AI in Roblox Development Overview]] · [[AI Code Assistants for Luau]] · [[MCP Workflows for Building Worlds]] · [[Working with AI Assistants in Studio]] · [[Agent Review Loops and Guardrails in Practice]]
<!-- auto-links:end -->
