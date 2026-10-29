---
tags: [studio, command-bar, tooling, edit-mode, workflow, gotchas, type/guide, area/studio, level/intermediate, api/HttpService, area/scripting, api/Terrain]
---
# Command Bar and Studio Scripting

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Undo in a shared session -> Snapshots; never undo
> - Avoid: `require` from the bar after editing a module -> Clone-require
> - Avoid: Changing a required module's table to affect a running test -> Gated cheat remotes or attributes
> - Edit-only guard.
> - Reads shared modules with clone-require.
> - Resolves targets by path, tag or attribute, never Selection.
>
> Cost: TL;DR ~130 tok · whole note ~4.1k tok. Read more: ## 7. Never use undo in a shared place · ## 8. Editing script sources safely · ## 10. Common mistakes · ## 11. Checklist for a new Studio tool
<!-- tldr:end -->

The Command Bar runs Luau against the place you have open, with more permissions than game scripts. It is how senior developers do bulk edits, audits, generators, installers and one-off fixes without writing a plugin. It is also the place where a single line can damage hours of other people's work. This note covers the bar itself, the security context, and the patterns that make Studio scripting safe and repeatable: stale `require` and the clone-require fix, HTTP loaders for large tools, budgeted resumable loops, safe edits to script sources (including the 200,000 character `Source` limit), and why you never use undo in a shared place.

Most of the patterns were hardened in the reference project, a large place edited by several people and automated tools at once. Labels: **Docs**, **Measured**, **Rule of thumb**.

---

## 1. The bar

Open it from the **Script** tab or **Window > Script**; `Ctrl 9` focuses it at any time (Docs). With the beta **Multi-line Command Bar** (File > Beta Features), you get (Docs):
- Multi-line input: `Enter` inserts a line, the bar grows from 2 to 10 lines, **Run** or `Ctrl Enter` executes.
- **History**: the last 10 executed commands, also scrubbed with `Ctrl ↑/↓`.
- **Saved** commands: `Ctrl B` saves the current command for reuse.
- Script Editor features: autocomplete, linting, go to declaration, multi-cursor, Code Assist.

Settings: **CommandBarEnterExec** (Enter runs immediately) and **CommandBarLocalState** (keep input between sessions) (Docs).

Saved commands are per machine. Anything you will run more than twice belongs in a file in the repo, loaded by the pattern in section 5.

## 2. Context and permissions

| Question | Answer |
|---|---|
| Which data model does it run in? | The one you are viewing. In Edit, the Edit data model; during a solo test, the side chosen by the Client/Server toggle (Docs describe the bar as usable while the game runs) |
| What can it access? | Plugin-level APIs such as `Selection`, `ChangeHistoryService`, `ScriptEditorService`, `Studio` settings, and script `Source` (Rule of thumb, consistent with the docs' plugin examples) |
| `loadstring`? | Available in the bar. `ServerScriptService.LoadStringEnabled` governs game scripts, and docs recommend keeping it off for security |
| `HttpService`? | Requests follow the place's HTTP setting; for unpublished places the docs say to enable it from the bar: `game:GetService("HttpService").HttpEnabled = true`. Whether the bar can bypass a disabled setting is unverified; in the reference project the place had HTTP enabled |
| Can it yield? | Yes; `task.wait` works. But a long synchronous stretch freezes Studio, and **ScriptTimeoutLength** sets how long a script may wait to be resumed before timing out (Docs) |
| Undo? | The multi-line bar records its changes with `ChangeHistoryService` for undo/redo (Docs), so do not run code in the bar that keeps running forever (Docs warning) |

Also available outside Studio's UI: the Studio CLI runs a script after a place loads, at the same permission level as the Command Bar (Docs):

```text
RobloxStudioBeta.exe --task RunScript --localPlaceFile "C:\proj\game.rbxl" --runScriptFile "C:\proj\tools\audit.luau" --outputFile out.log --quitAfterExecution
```

That is how you run audits headlessly on a local file (see [[Git and Source Control for Roblox]]).

## 3. Edit-only tools

Many tools must never run during a test: they would edit the throwaway test data model, or fight the running game. Guard them.

```lua
--!strict
local RunService = game:GetService("RunService")
if RunService:IsRunning() then
	error("edit-only tool: stop the playtest first")
end
```

`RunService:IsRunning()` is true while a simulation runs (Test or Run), false in Edit. The reference project's rule was stronger: tools never start or stop a test themselves, and if Studio is in a test, work offline and check again later (Measured).

## 4. Stale `require` and the clone-require pattern

In Edit, `require()` caches a ModuleScript's return value for the session. Edit the module, require it again from the bar, and you get the **old** table (Measured). Worse, a module required from the bar is a different instance from the one the running game uses during a test, so mutating it from the bar changes nothing in the game (this is the "command-bar trap" in [[Testing Strategies and Frameworks]]).

Fix for reading current data, used by every tool in the reference project:

```lua
--!strict
-- Require a fresh copy of a module (Edit mode). Children are cloned too.
local function fresh(mod: ModuleScript): any
	local c = mod:Clone()
	c.Parent = mod.Parent -- same parent so script.Parent lookups and sibling requires still resolve
	local ok, result = pcall(require, c)
	c:Destroy()
	if not ok then
		error(result, 2)
	end
	return result
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = fresh(ReplicatedStorage:WaitForChild("GameConfig") :: ModuleScript)
print(Config.Version)
```

Gotchas (Measured):
- **Parent the clone beside the original.** Elsewhere, `script.Parent:WaitForChild(...)` inside the module breaks.
- A module that defers work (`task.defer`, `task.delay`) touching `script` will find its clone destroyed. Prefer modules that do lookups at require time.
- The clone's own requires of siblings still hit the **cached** siblings. If a sibling also changed, clone it too, or clone the whole parent folder.
- To test a patched dependency, clone both modules, rewrite the clone's `Source`, require, then destroy both.

## 5. Large tools: the HTTP loader

Pasting a 300 KB generator into the bar works (the reference project pasted setup scripts of 100 to 370 KB when nothing else was available), but it is fragile and leaves no history. Better: keep tools as `.luau` files in the repo, serve them from a local static server, and load them with one line (Measured pattern, see [[Studio Tooling Architecture]]).

```text
# in the tools folder, bound to localhost only
py -m http.server 8765 --bind 127.0.0.1
```

```lua
-- Command Bar loader. The ?x= query busts any cache so you never run yesterday's file.
local HttpService = game:GetService("HttpService")
local src = HttpService:GetAsync("http://127.0.0.1:8765/tools/audit.luau?x=" .. os.clock(), true)
local chunk, err = loadstring(src)
assert(chunk, err)
print(chunk()({ mode = "report", budget = 1.5 }))
```

Conventions that kept tools sane:
- A tool file returns **one function taking one table of arguments** and returns a short **report string**.
- **The file is the only copy that matters.** Nothing is installed into the place unless a write mode says so.
- HttpService allows 500 external requests per minute (Docs). Batch results into one POST per unit of work rather than one per item.
- Bind servers to `127.0.0.1` only. A receiver that writes POST bodies to disk must whitelist folder names and file names, or it is a hole.

## 6. Budgeted, resumable loops

A long synchronous command stops Studio repainting. With several people or tools on one Studio, one long call blocks everyone (Measured). The reference project settled on **at most about 1.5 s per call, one call at a time**, after a long freeze it suspected (not proven) came from long calls.

```lua
--!strict
-- A resumable pass: call again with the returned index until it says done.
type Args = { i0: number?, budget: number? }

return function(args: Args): string
	local budget = args.budget or 1.5
	local t0 = os.clock()
	local targets = workspace:WaitForChild("Map"):GetChildren() -- top-level units, not GetDescendants of Workspace
	for i = args.i0 or 1, #targets do
		if os.clock() - t0 > budget then
			return ("paused at %d/%d, call again with i0=%d"):format(i, #targets, i)
		end
		local unit = targets[i]
		-- ... one unit of work on `unit` ...
	end
	return "done " .. #targets
end
```

For work that is one long computation, keep state in `_G` between calls (each loaded chunk is fresh), provide a `restart` flag, and clear the state when finished.

## 7. Never use undo in a shared place

This is the most expensive lesson in this note.

**Measured.** In the reference project several tools and people edited the same Studio session. One undo, issued to recover a terrain change, walked about 40 waypoints back and rolled back other people's instance changes. Each new command also added a waypoint, which wiped the redo history, so the damage could not be redone. The rule afterwards: **never call undo** (`Ctrl Z` in the viewport or `ChangeHistoryService:Undo()`) in a shared session; take a snapshot before risky work instead.

Why it happens: the undo history is a linear list of waypoints. When several actors write into the same history (several tools on one Studio, or a bar command interleaved with a teammate's edits), "undo my last change" means "undo the last waypoint", which may be someone else's. In Team Create each person has their own Studio, and whether histories are per user is not documented (unverified); but undoing your waypoint still restores old values on instances a teammate may have changed since, so the hazard remains.

Snapshot instead:

| What you will change | Snapshot |
|---|---|
| Properties of many instances | Pre-attributes holding originals ([[Explorer Properties and Selection]]) |
| Positions of many instances | JSON file of path to CFrame, or Pre-attributes |
| A model or folder you will rebuild | Export `.rbxm` to disk ([[Version History and Backups]]) |
| Terrain region | `Terrain:CopyRegion(region)` into a `TerrainRegion` you can `PasteRegion` back |
| A script | Its old `Source` saved to disk before writing |

```lua
--!strict
-- Snapshot a terrain region before a risky write, and restore it.
local Terrain = workspace.Terrain
local ServerStorage = game:GetService("ServerStorage")

local minCell = Vector3int16.new(-64, -16, -64)
local maxCell = Vector3int16.new(64, 32, 64)
local region = Region3int16.new(minCell, maxCell)

local snap = Terrain:CopyRegion(region)
snap.Name = "TerrainSnap_Before"
snap.Parent = ServerStorage -- move to disk (.rbxm) once the pass is accepted

-- restore:
-- Terrain:PasteRegion(snap, minCell, true)
```

Also ask the owner before regenerating any whole area in a shared place (Measured rule).

## 8. Editing script sources safely

Tools that patch scripts (registries, config tables, generated code) need a procedure. The reference project's `patch` helper did this, in order (Measured):

1. **Idempotency check**: if the text you would add is already there, report "already there" and stop.
2. **Re-read the source right before editing**; compute the new source with one anchored insert.
3. **Size check**: a script `Source` over **200,000 characters** fails to save ("Unable to assign property Source"). Refuse before trying. Real near misses: 195,812 and 192,059 characters; one server script sat at about 199,600 and was frozen ("never edit it; extend through a child module").
4. **Compile** the new source with `loadstring`; reject on error.
5. **Static scan**: a use-before-definition scanner caught locals referenced above their declaration, which compile fine and fail at runtime.
6. **One safety copy** of the old source (to disk), never overwritten.
7. **Changed-underneath check**: if the live `Source` differs from what you read in step 2, someone edited it meanwhile; abort.
8. **Write, then clone-require** the module; if it fails to load, write the old source back.

Two more limits: a single Luau function may declare at most **200 local variables** (generated code that emits one local per item hits it; use tables), and very large scripts slow the editor for everyone.

If a script might be open in someone's editor, write through `ScriptEditorService:UpdateSourceAsync(script, callback)`: the callback receives the old content and returns the new; if the editor's copy is newer the callback is re-run; returning `nil` cancels (Docs).

```lua
--!strict
-- Safe append with size, compile and changed-underneath checks.
local ScriptEditorService = game:GetService("ScriptEditorService")
local MAX_SOURCE = 200_000 -- measured hard limit; keep margin

local function appendLine(mod: LuaSourceContainer, marker: string, line: string): string
	local before = (mod :: any).Source :: string
	if string.find(before, marker, 1, true) then
		return "already there"
	end
	local result = "ok"
	ScriptEditorService:UpdateSourceAsync(mod, function(old: string): string?
		if old ~= before then
			result = "changed underneath, aborted"
			return nil
		end
		local new = old .. "\n" .. line .. " -- " .. marker .. "\n"
		if #new > MAX_SOURCE - 1000 then
			result = ("too large (%d chars)"):format(#new)
			return nil
		end
		local chunk, err = loadstring(new)
		if not chunk then
			result = "compile error: " .. tostring(err)
			return nil
		end
		return new
	end)
	return result
end
```

## 9. Common recipes

```lua
-- Count instances per top-level service: find what bloats the place.
for _, service in game:GetChildren() do
	local ok, n = pcall(function()
		return #service:GetDescendants()
	end)
	if ok and n > 1000 then
		print(service.Name, n)
	end
end
```

```lua
-- Find every script containing a string (Find All does this interactively; this works headless too).
local needle = "RegisterKeyframeSequence"
for _, inst in game:GetDescendants() do
	if inst:IsA("LuaSourceContainer") then
		local ok, src = pcall(function()
			return (inst :: any).Source
		end)
		if ok and type(src) == "string" and string.find(src, needle, 1, true) then
			print(inst:GetFullName())
		end
	end
end
```

`pcall` matters: some instances (CoreGui, locked services) throw on access.

## 10. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Undo in a shared session | Others' work rolled back, redo lost | Snapshots; never undo |
| `require` from the bar after editing a module | Stale data | Clone-require |
| Changing a required module's table to affect a running test | Nothing happens | Gated cheat remotes or attributes |
| One giant synchronous loop | Studio freezes for everyone | 1.5 s budget, resume index |
| Writing a script without size and compile checks | Save fails, or a broken script ships | The 8-step patch procedure |
| Tool reads `Selection` | Edits the wrong objects | Resolve by path or tag |
| Bar command left running (connections, loops) | Interferes with undo recording and later edits | Disconnect; keep bar code short-lived |
| Pasting huge tools by hand | No history, typos | Files plus HTTP loader |

## 11. Checklist for a new Studio tool

- [ ] Edit-only guard.
- [ ] Reads shared modules with clone-require.
- [ ] Resolves targets by path, tag or attribute, never Selection.
- [ ] Time budget and resume index.
- [ ] Snapshot or Pre-attributes before writing; revert path tested.
- [ ] Script writes: idempotent, size-checked, compiled, scanned, changed-underneath check, verified.
- [ ] Returns a short report string.
- [ ] Lives in the repo; loaded by the HTTP loader.

## See also

- [[Plugins - Using and Writing]] (when a tool should become a plugin)
- [[Explorer Properties and Selection]], [[Version History and Backups]], [[Safe Changes in a Shared Place]]
- [[Module Scripts and Requiring]], [[HttpService and External APIs]]
- Animation section: [[Studio Tooling Architecture]], [[Clip Archive Server]], [[Engine Gotchas]]

## Connected notes
<!-- auto-links:start -->
[[Undo and ChangeHistoryService Done Right]] · [[Studio Settings and Shortcuts]] · Batch Processing Tools in Studio · Safety Rules for AI Agents in Studio · Studio Plugins and Local HTTP Bridges · Roblox Studio Assistant
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Batch Processing Tools in Studio]] · [[Studio Plugins and Local HTTP Bridges]] · [[Team Create and Collaboration]] · [[Studio Interface Tour]] · [[Studio Assistant and AI Tools]] · [[External Tooling - Rojo Wally Selene StyLua]] · [[Packages and Asset Reuse]] · [[Creator Store and Toolbox Safety]] · [[Places Universes and Experience Settings]] · [[Testing Modes - Play Run and Multi-Client]]
<!-- related:end -->
