---
tags: [mcp, studio, ai, agents, tooling, type/guide, area/ai, level/intermediate, area/studio]
---
# Roblox Studio MCP Server

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Using a cached `studio_id` after a Studio restart.
> - Avoid: Calling `start_stop_play` in a Studio someone else is testing in.
> - Avoid: One huge `execute_luau` that builds a whole level in a single call.
> - Studio updated; Assistant > ... > Manage MCP Servers > Enable Studio as MCP server (local, stdio); green indicator shows the...
> - `list_roblox_studios` called; correct place id chosen.
> - `get_studio_state` says Edit.
>
> Cost: TL;DR ~150 tok · whole note ~4.6k tok. Read more: ## 1. History: from a plugin bridge to a built-in server · ## 3. The tool set · ## 7. Common mistakes · ## 8. Checklist before an agent session in Studio
<!-- tldr:end -->

Roblox Studio ships with a built-in MCP server. Turn it on, point an MCP client at it, and an AI agent can explore your data model, read and edit scripts, run Luau in Edit, Server or Client contexts, start and stop play tests, read the Output, take screenshots, simulate player input, search and insert Creator Store assets, upload images and call Roblox's generative tools. This note covers how to enable it, what each tool does, how it behaves in practice, and the gotchas the reference project hit while building a whole game through it.

For the protocol itself see [[What Is MCP]]. For client configuration see [[Setting Up MCP Clients]]. For working rules see [[Safety Rules for AI Agents in Studio]].

Facts are **as of October 2026**. The tool list changes between Studio releases. Source labels: **Roblox docs** (create.roblox.com/docs/studio/mcp), **Measured** (the reference project), **Rule of thumb**.

---

## 1. History: from a plugin bridge to a built-in server

Two generations exist, and old tutorials describe the first:

| | Open-source reference server (2025) | Built-in Studio MCP server (current) |
|---|---|---|
| Where | GitHub repo `Roblox/studio-rust-mcp-server` | Inside Roblox Studio |
| Status | **Archived on 3 April 2026**, read-only; Roblox says it moved its engineering investment to the built-in server | Maintained, updated with Studio |
| Architecture | A Rust binary: an `rmcp` stdio server for the client, plus an `axum` web server that a Studio plugin **long-polls** over HTTP | Built into Studio; the client runs a small launcher over stdio |
| Tools | 6: `run_code`, `insert_model`, `get_console_output`, `start_stop_play`, `run_script_in_play_mode`, `get_studio_mode` | About 25 (table below) |
| Install | Download the release binary, run it; it configures Claude Desktop or Cursor and installs the plugin | Toggle in Assistant settings |

The old design is still worth understanding because it is exactly the pattern you use to write your own bridge: an MCP server on one side, a Studio plugin polling localhost on the other. See [[Studio Plugins and Local HTTP Bridges]] and [[Writing Your Own MCP Server]].

Community servers also exist (several "roblox studio mcp" projects with their own plugins). They are not official; read their source before connecting them to a place you care about ([[Creator Store and Toolbox Safety]] applies to tools too).

---

## 2. Enabling it

From the Roblox docs:

1. Install the latest Studio and your MCP client.
2. In Studio, open **Assistant**, click the **...** menu, choose **Manage MCP Servers**.
3. Turn on **Enable Studio as MCP server**. A green indicator shows how many clients are connected.
4. Connect a client by **Quick connect** (Assistant Settings > MCP Servers > Quick connect; listed clients include Antigravity, Codex CLI, Claude Code, Claude Desktop, Cursor, Gemini CLI and Visual Studio Code), by a JSON entry, or by a CLI command.
5. Restart the client after adding the configuration.

The JSON entry the docs give for Windows:

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "cmd.exe",
      "args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
    }
  }
}
```

and for macOS:

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"
    }
  }
}
```

The server name `Roblox_Studio` is why tools show up in hosts as `mcp__Roblox_Studio__execute_luau` and similar: hosts prefix tool names with the server name. Per-client details (Claude Code's `claude mcp add`, Cursor's `mcp.json`, VS Code's different key name) are in [[Setting Up MCP Clients]].

**Verify it works:** the green indicator in Manage MCP Servers shows a connected client; in the client, ask for `list_roblox_studios` and check your place appears.

---

## 3. The tool set

The docs group the tools as below. Descriptions are paraphrased from the docs plus behaviour measured in the reference project. Two tools present in recent builds (`generate_texture`, `segment_mesh`) were visible in the reference project's tool list but are **not on the docs page** as of October 2026: treat their behaviour as unverified.

### 3.1 Session

| Tool | What it does | Notes |
|---|---|---|
| `list_roblox_studios` | Lists connected Studio windows with name, instance id and place id | **Every other tool takes a `studio_id`.** The id changes every time Studio restarts (Measured). Call this first in every session. Use the place id to pick the right window when names collide |

### 3.2 Data model exploration

| Tool | What it does | Notes |
|---|---|---|
| `search_game_tree` | Returns the instance hierarchy as a flat JSON array, with filters and depth limits | Always filter (path, class, name, depth). Unfiltered dumps of a large place are huge |
| `inspect_instance` | Returns one instance's properties, attributes and a child summary | Cheap, exact; ideal for checking an edit landed |
| `subagent` | Launches an `explore` or `playtest` subagent for multi-step tasks | Delegates a chain of calls; the main agent gets the summary. Good for "find every place X is used" |

### 3.3 Scripts

| Tool | What it does | Notes |
|---|---|---|
| `script_read` | Reads a script by dot-notation path, whole or by line range | Read ranges of big scripts; a 190k-character script in one result is wasteful |
| `script_search` | Fuzzy search of scripts by name (up to 10 results) | Finding "the shop controller" when you do not know its path |
| `script_grep` | Searches all script sources for a pattern (up to 50 matches) | The single most useful audit tool: "every `RegisterKeyframeSequence`", "every `:Connect(` in this module" |
| `multi_edit` | Applies several edits to one script in one operation; creates the script if the path does not exist | Exact-match find/replace style. Re-read before editing: another agent or the user may have changed the source |

### 3.4 Luau execution

| Tool | What it does | Notes |
|---|---|---|
| `execute_luau` | Runs Luau in the Edit, Server or Client datamodel and returns output | The workhorse. In Edit it is like the command bar with a return channel. See gotchas: `require` caching, call length, camera resets |

### 3.5 Playtesting and observation

| Tool | What it does | Notes |
|---|---|---|
| `get_studio_state` | Returns play state and which datamodels are available | Check before editing: Edit calls fail while Studio is in Play |
| `start_stop_play` | Starts or stops a play test | In a shared Studio this ends **everyone's** test, including the human's (see [[Multiple Agents in One Studio]]) |
| `get_console_output` | Returns the Output log | Read after a play test or after running code that warns |
| `screen_capture` | Captures the viewport, optionally from a camera position toward a target | Several gotchas below |
| `character_navigation` | Moves the player character to a position or instance at a chosen speed | Play mode only |
| `user_keyboard_input` | Sends ordered key, text or wait actions | For testing input handlers, menus, abilities |
| `user_mouse_input` | Sends ordered move, click, button, scroll or wait actions | For clicking UI during play tests |

### 3.6 Assets and generation

| Tool | What it does | Notes |
|---|---|---|
| `search_asset` | Searches the Creator Store and your Creator Inventory with filters | Same safety concerns as the Toolbox |
| `insert_asset` | Inserts an asset by numeric id | Inserts whatever that id is; verify ownership and contents |
| `upload_image` | Uploads images from **HTTP URLs** and returns a map of path to asset id | Needs a URL, not a file path. Serve local files from a localhost HTTP server (Measured; see [[Studio Plugins and Local HTTP Bridges]]) |
| `store_image` | Loads a local image and returns a URI other tools can use | |
| `generate_mesh` | Creates a textured mesh from a text prompt | Roblox generative AI; see [[Roblox Generative AI - Cube Mesh and Texture Generation]] |
| `generate_material` | Creates a custom MaterialVariant | Measured: failed almost every job in the reference project. Unverified whether that is general |
| `generate_procedural_model` | Builds an object from primitive parts, with attributes, reference images and custom schemas | Runs as a job |
| `wait_job_finished` | Waits for a generation job and returns its status | Pair with the generate tools |
| `generate_texture`, `segment_mesh` | Present in recent builds; not documented on the MCP page | Unverified |

### 3.7 Documentation

| Tool | What it does | Notes |
|---|---|---|
| `http_get` | Fetches allowed Roblox documentation pages, with keyword search | Lets the agent check an API instead of guessing. It is not a general web fetch |
| `skill` | Retrieves reference material for skills such as debugging and device simulation | Roblox-authored guidance the agent can pull in |

---

## 4. Multiple Studio windows

One client can drive several Studio windows at once (Roblox docs). Each call carries a `studio_id`. Practical consequences:

- After every Studio restart the id changes. An agent that cached yesterday's id gets errors or, worse, talks to a different open place. Rule from the reference project: **always call `list_roblox_studios` at the start and pick by place id**, not by window title (titles can be stale or duplicated).
- Keep a scratch test place open beside the real one for experiments. The `studio_id` makes it explicit which one you are touching.
- Several **agents** sharing **one** Studio is a different and harder problem: see [[Multiple Agents in One Studio]].

---

## 5. Gotchas measured in the reference project

These cost real time. Each says what you see and what to do.

### 5.1 Edit calls fail during Play
**What you see.** Edit-mode calls error with a message that the Edit datamodel is not available in Play mode.
**Why.** While a play test runs, the Edit datamodel is not available to the tools.
**Do.** Check `get_studio_state` first. If someone else is testing, do offline work (write code to disk, render in Blender) and check again in a few minutes (the reference project used about 3 minutes). Do **not** stop their test.

### 5.2 `require` returns a stale copy
**What you see.** You edit a ModuleScript, then `require` it from `execute_luau`, and the old values come back.
**Why.** `require` caches the result per ModuleScript instance; the tool's context keeps that cache across calls. Also, a module required from the tool context is a separate copy from the one running services use.
**Do.** Clone-require: clone the ModuleScript, parent the clone beside the original (so relative `script.Parent` lookups still work), require the clone, destroy it.

```lua
-- Read the CURRENT state of a module edited in this session.
local function freshRequire(module: ModuleScript): any
	local clone = module:Clone()
	clone.Parent = module.Parent -- keep relative requires and script.Parent lookups working
	local ok, result = pcall(require, clone)
	clone:Destroy()
	if not ok then
		error("fresh require failed: " .. tostring(result))
	end
	return result
end

local Config = freshRequire(game.ReplicatedStorage.GameConfig)
return Config.Version
```

One measured trap: if the module itself waits on children of the clone (`WaitForChild`) after you destroyed it, the call hangs. Keep the clone parented until the work is done when the module does lazy lookups.

### 5.3 Long calls freeze Studio for everyone
**What you see.** Studio stops repainting; other agents' calls queue; the human's Studio feels dead.
**Why.** A tool call runs on Studio's main thread. A 20-second loop blocks everything.
**Do.** Keep each call short. The reference project's rule was **under about 1.5 s per call, one call at a time** after Studio froze for about 25 minutes while around 18 offline solver processes ran alongside in-Studio simulations (Measured). Break loops into budgeted chunks that return a resume index:

```lua
-- Budgeted batch: processes items until the time budget is spent, then reports where to resume.
local BUDGET = 1.2 -- seconds; leave headroom under the 1.5 s rule
local function processFrom(items: {Instance}, startIndex: number): string
	local t0 = os.clock()
	for i = startIndex, #items do
		local item = items[i]
		item:SetAttribute("Checked", true) -- the real work goes here
		if os.clock() - t0 > BUDGET then
			return ("stopped early i0=%d of %d"):format(i + 1, #items)
		end
	end
	return ("done %d"):format(#items)
end
```

### 5.4 `screen_capture` surprises
- **Black image or timeout** when Studio is not the foreground window (Measured). Ask the user to bring Studio to the front, retry once, then verify numerically and say you did.
- **[[AlwaysOnTop]] BillboardGuis are not drawn** (health bars, name tags). Their absence in a capture is not a bug in your game.
- **Capturing with a camera position leaves the Edit camera `Scriptable`**, and camera changes made inside `execute_luau` can be reverted by the tooling. Fix in one call with a delayed reset, then confirm in a second call:

```lua
task.delay(0.6, function()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end)
return "camera reset scheduled"
```

- **Particles in Edit** only step when Studio renders, so captures of short bursts often show nothing. Emit bursts with `:Emit(n)` right before capture, or verify by counting instead.
- **After a large terrain write**, move the camera and wait about 3 seconds before capturing, or you photograph stale terrain (Measured).

### 5.5 The tool cannot import local files
`execute_luau` cannot read your disk, and the importer is not exposed. In the reference project every GLB import was a manual step for the human (File > Import 3D), and the agent took over once the model was in the place. Images go through `upload_image` from an HTTP URL. Large Luau sources (setup scripts of 100 to 370 KB) did not fit through tool calls comfortably: either the human pasted them into the command bar, or Studio fetched them from a local HTTP server with `HttpService:GetAsync` and `loadstring` ([[Studio Plugins and Local HTTP Bridges]]).

### 5.6 Script size and compile checks
- Script `Source` has a hard limit of 200,000 characters (Measured). One combat service sat at about 199,600 characters; the rule became "never grow it, extend through a separate module".
- Before saving any edit, compile it: `loadstring(src)` must return a function. The reference project also ran a custom "use before definition" scan (calling a local function before its `local function` line compiles fine but crashes at runtime). See [[MCP Workflows for Scripting and Debugging]].

### 5.7 Some properties are not readable
In the reference project, `Workspace` settings such as the 2022 materials toggle and `Terrain.Decoration` could not be read through the tools, and `CollisionFidelity` cannot be changed on an existing MeshPart (it needs `AssetService:CreateMeshPartAsync`). When a property read fails, check the API reference: some properties are not scriptable at the security level the tool runs at.

### 5.8 Host permission classifiers can block calls
Hosts with automatic permission modes may refuse some calls (in the reference project: some script writes, chunked simulations, a deletion). When a call is denied, stop and report rather than finding a workaround; the human can add an allow rule if they agree.

---

## 6. What the server is good and bad at

| Good at | Weak at |
|---|---|
| Reading and auditing a whole codebase (`script_grep`) | Anything that needs your disk (imports, large files) |
| Small, exact edits with immediate verification | Long computations (freeze risk) |
| Numeric checks of the world (positions, counts, sizes) | Judging how something looks (screenshots are unreliable) |
| Driving play tests with simulated input | Play tests in a Studio other people are using |
| Placing and configuring many instances from data | Art direction without a human looking |

The pattern that worked: **Studio is an I/O device and a ground-truth oracle; heavy logic lives outside** (offline Python, Blender, your own tools), connected by short calls. The Animation section describes the same split for clip baking in [[Studio Tooling Architecture]].

---

## 7. Common mistakes

- Using a cached `studio_id` after a Studio restart.
- Calling `start_stop_play` in a Studio someone else is testing in.
- One huge `execute_luau` that builds a whole level in a single call.
- Trusting `require` in the tool context to show edited module values.
- Accepting a black screenshot as evidence of anything.
- Inserting Creator Store assets without checking their scripts.
- Letting the agent call ChangeHistory undo in a shared place (see [[Safety Rules for AI Agents in Studio]]).

## 8. Checklist before an agent session in Studio

- [ ] Studio updated; Assistant > ... > Manage MCP Servers > Enable Studio as MCP server (local, stdio); green indicator shows the client.
- [ ] `list_roblox_studios` called; correct place id chosen.
- [ ] `get_studio_state` says Edit.
- [ ] Version History has a recent save (publish or save to Roblox before big changes).
- [ ] Agent has the working rules (short calls, no Play, no undo, snapshot first).
- [ ] A local HTTP server is ready if large files or images must move in.

## See also

- [[What Is MCP]], [[Setting Up MCP Clients]], [[Blender MCP]]
- [[MCP Workflows for Building Worlds]], [[MCP Workflows for Scripting and Debugging]]
- [[Safety Rules for AI Agents in Studio]], [[Multiple Agents in One Studio]]
- [[Studio Assistant and AI Tools]], [[Roblox Studio Assistant]], [[Command Bar and Studio Scripting]]
- [[Case Study - Building a Game with AI Agents]]

## Connected notes
<!-- auto-links:start -->
[[AI Agents and Autonomous Workflows]] · Batch Processing Tools in Studio · AI Code Assistants for Luau · Working with AI Assistants in Studio · AI in Roblox Development Overview · Plugin Security and Permissions
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Built-In Studio MCP vs Community MCP Servers - Migration Guide]] · [[Agent Review Loops and Guardrails in Practice]] · [[Batch Processing Tools in Studio]] · [[Agent Handoff Notes - Project State and Resume Templates]] · [[AI in Roblox Development Overview]] · [[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]]
<!-- related:end -->
