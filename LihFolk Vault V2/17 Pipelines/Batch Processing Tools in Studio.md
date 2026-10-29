---
tags: [pipelines, studio, tooling, batch, plugins, command-bar, http, automation, type/guide, area/pipelines, level/intermediate, api/HttpService]
---
# Batch Processing Tools in Studio

<!-- tldr:start -->
> [!tldr] TL;DR
> - Studio freezes for minutes: unsliced loop, background work, too many offline processes -> slice under budget; no background loops; cap processes
> - Tool sees old module code: `require` cache in Edit -> clone-require
> - `HttpError` mid-pipeline: local server died, wrong port -> watchdog, port map
> - Tools in a DevTools folder or served from disk; consistent Status / Run / Verify / Restore
> - Return data, not prints
> - Sliced work under about 1 s per call; no background loops
>
> Cost: TL;DR ~160 tok · whole note ~4.3k tok. Read more: ## Rule 2: slice long work under the call budget · ## Moving data: local HTTP servers · ## Failure modes · ## Checklist
<!-- tldr:end -->

Sooner or later every game needs to change thousands of things at once: re-texture every rock, re-level every sound, re-bake every clip, delete every leftover backup, audit every screen. Doing that by hand is impossible; doing it with one giant command-bar script freezes Studio, cannot be undone safely and leaves no record. This note is how to build **batch tools that run inside Studio in Edit mode**: where they live, how they slice work so Studio stays responsive, how they move data in and out through local HTTP, how they stay reversible, and the gates they run. It is drawn from one production game that ran dozens of such tools, several at once, with people and AI agents sharing the same place. Background: [[Command Bar and Studio Scripting]], [[Plugins - Using and Writing]], [[Studio Plugins and Local HTTP Bridges]], [[Studio Tooling Architecture]].

## Where batch tools live

| Home | Pros | Cons | Use for |
|---|---|---|---|
| Command bar snippet | instant | no reuse, no record, easy to mistype | one-off queries |
| **ModuleScript in a DevTools folder** (ServerStorage) | shared with the team, versioned with the place, callable from the command bar, plugins and agents | ships in the place file (not to clients, ServerStorage is server-only) | the team's standard tools |
| Plugin | toolbar UI, own settings, file pickers, `ChangeHistoryService` integration | per-user install, separate update path | tools artists use daily |
| Files loaded over local HTTP | edit in an IDE, no place bloat, version in Git | needs HttpService enabled and a local server | big or fast-changing tools |
| MCP `execute_luau` from an agent | automation, agents can run pipelines | same freeze risks; one call at a time | agent-driven pipelines ([[Roblox Studio MCP Server]]) |

The reference project kept a `ServerStorage.DevTools` folder of modules with small, consistent APIs (measured in one production game; names illustrative of its style):

| Tool | API | Job |
|---|---|---|
| use-before-definition scanner | `.Scan(src) -> findings` | gate before saving any script |
| re-texture pass | `.Revert(root)` | undoes a texture pass from stored attributes |
| materials setup | `.Run(nil, opts)` | builds drop models from an imported GLB |
| clip bake | `.Status()`, `.Run({kits})`, `.Verify()`, `.Restore(list)` | bakes animation clips to compact stubs, archives originals ([[Baked Clip Stubs and Archiving]]) |
| GUI audit / phone check | `.Run(only?, mode?)` | scores every screen ([[UI Asset Pipeline]]) |
| ray align | `.Align()` | re-seats beacon beams after a station moves |

Call them from the command bar with a fresh copy, because `require` caches modules in Edit:

```lua
print(require(game.ServerStorage.DevTools.GuiAudit:Clone()).Run())
```

## Rule 1: every tool has the same shape

Consistency makes tools safe to call, by people and by agents.

```text
Tool.Status()            -> read-only summary: what would be done, counts
Tool.Run(opts)           -> does the work; opts.dryRun defaults to true for destructive tools
Tool.Verify()            -> checks the result, returns problems (empty = good)
Tool.Restore(opts)       -> undoes Run from stored data
returns a table or a short string, never only prints
```

Returning data rather than printing lets an agent or another tool read the result; the reference project's MCP guidance was "return structured data from executed code, not print output".

## Rule 2: slice long work under the call budget

Studio runs your Edit scripts on its main thread. A loop over 200,000 instances that takes 20 seconds freezes Studio for 20 seconds, for everyone in Team Create. The reference project's budget was **one call at a time, each under about 1.5 seconds** (measured in one production game, after Studio froze for about 25 minutes under heavy concurrent load).

The slicing pattern: keep a cursor in a persistent table, do as much as fits in a time budget, return progress, call again until done.

```lua
--!strict
-- Sliced batch runner. Call Step() repeatedly (command bar, plugin button or agent) until done.
-- State lives in _G so it survives between command-bar calls (each call is a fresh chunk).
type Job = {
	name: string,
	items: { Instance },
	i: number,
	done: number,
	failed: { string },
	work: (Instance) -> (),
}

local Batch = {}

function Batch.Start(name: string, items: { Instance }, work: (Instance) -> ())
	(_G :: any).BatchJob = { name = name, items = items, i = 1, done = 0, failed = {}, work = work } :: Job
	return ("%s: %d items queued"):format(name, #items)
end

function Batch.Step(budget: number?): string
	local job = (_G :: any).BatchJob :: Job?
	if not job then return "no job" end
	local limit = os.clock() + (budget or 0.9)       -- well under the 1.5 s call budget
	while job.i <= #job.items and os.clock() < limit do
		local item = job.items[job.i]
		job.i += 1
		if item.Parent == nil then continue end        -- deleted since queued
		local ok, err = pcall(job.work, item)
		if ok then job.done += 1 else table.insert(job.failed, item:GetFullName() .. ": " .. tostring(err)) end
	end
	local left = #job.items - job.i + 1
	if left == 0 then
		(_G :: any).BatchJob = nil
		return ("%s DONE: %d ok, %d failed%s"):format(job.name, job.done, #job.failed,
			#job.failed > 0 and ("\n" .. table.concat(job.failed, "\n", 1, math.min(#job.failed, 20))) or "")
	end
	return ("%s: %d ok, %d failed, %d left"):format(job.name, job.done, #job.failed, left)
end

return Batch
```

Usage:

```lua
local B = require(game.ServerStorage.DevTools.Batch:Clone())
local parts = {}
for _, d in workspace.MapRevamp:GetDescendants() do
	if d:IsA("BasePart") and d.Size.Magnitude < 2 then table.insert(parts, d) end
end
print(B.Start("tiny-no-shadow", parts, function(p) (p :: BasePart).CastShadow = false end))
print(B.Step()) -- repeat until DONE
```

Even collecting the item list can be too slow on a huge place; collect per top-level folder in separate calls. Do not run "background" loops inside Studio (a `task.spawn` that keeps working between calls): the reference project banned them after they contributed to a freeze, and they compete with every other tool and person.

## Rule 3: heavy computation goes offline

Studio is the wrong place for maths: an IK solve per frame, an image filter, an audio analysis, a mesh decimation. Move data out, compute in Python (or Node, or [[Lune]]), move results back. The reference project's split (measured in one production game):

- Studio does I/O only: read clips, write keyframes, read waveforms, write attributes;
- Python does the maths, at most two processes per agent (one during installs), with `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS` and `MKL_NUM_THREADS` set to 1 so numpy does not take every core;
- results come back as one JSON per batch.

## Moving data: local HTTP servers

Studio cannot read or write your disk from a script. HttpService can, however, talk to a server on your own machine while you are in Studio (HttpService must be enabled in Game Settings > Security). That gives you two directions:

| Direction | Mechanism | Example |
|---|---|---|
| disk to Studio | a static file server; Studio `GetAsync` | load a tool's source, a bake result, an id map |
| Studio to disk | a small receiver; Studio `PostAsync` | dump config to JSON, post a model's look for icon rendering, export a manifest |

Rules from the reference project:

- **Bind to 127.0.0.1 only**, never 0.0.0.0, and accept writes only under one folder.
- **Defeat caching** with a changing query string (`?x=` .. `os.clock()`) and the `nocache` argument of `GetAsync`.
- **HttpService allows about 500 requests per minute** (Roblox docs). Post one JSON per batch, not one per item.
- **Run each server as its own process** (on Windows, `Start-Process` with a hidden window) and keep a watchdog that restarts it; a dead server shows up as confusing `HttpError` messages mid-pipeline.
- Use **one port per purpose** and write the port map down (static files, icon receiver, animation receiver, clip archive, dump receiver were all separate ports in that project).

A minimal receiver and static server in one Python file:

```python
# tools/bridge.py : py -I tools/bridge.py <root_dir> <port>
# GET  /<path>        -> serves files under root (read)
# POST /<path>        -> writes the body to root/<path> (write), creates folders
import http.server, pathlib, sys

ROOT = pathlib.Path(sys.argv[1]).resolve()
PORT = int(sys.argv[2])
MAX_BODY = 50 * 1024 * 1024

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(ROOT), **kw)

    def _target(self):
        rel = self.path.split("?", 1)[0].lstrip("/")
        p = (ROOT / rel).resolve()
        if ROOT not in p.parents and p != ROOT:
            raise PermissionError(rel)          # no escaping the root with ../
        return p

    def do_POST(self):
        try:
            p = self._target()
            n = int(self.headers.get("Content-Length", 0))
            if n > MAX_BODY:
                self.send_error(413); return
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(self.rfile.read(n))
            self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
        except PermissionError:
            self.send_error(403)

    def log_message(self, fmt, *args):
        pass                                    # keep the console quiet

http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
```

Studio side:

```lua
local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8765/"

-- load and run a tool kept on disk (edit it in your IDE, no paste)
local tool = loadstring(HttpService:GetAsync(BASE .. "tools/retex.lua?x=" .. os.clock(), true))()

-- post a dump to disk
HttpService:PostAsync(BASE .. "dumps/items.json", HttpService:JSONEncode({ count = 3 }),
	Enum.HttpContentType.ApplicationJson)
```

`loadstring` works in the command bar and plugin contexts; it is disabled for game scripts unless `ServerScriptService.LoadStringEnabled` is on, which you should not turn on for a live game. Keep these loaders in Edit tooling only.

## Big tools that cannot go through a tool call

Some setup scripts are hundreds of kilobytes (the reference project had setup scripts of 100 to 370 KB). They are too big to send through an agent tool call and awkward to paste. Options: serve them over the local bridge and `loadstring` them, or as a last resort have a person paste them into the command bar and let the tooling adapt what they create.

## Rule 4: reversibility built in

Every destructive or mass-edit tool:

1. **Defaults to dry run** and reports counts and a sample of targets.
2. **Stores originals** before the first write (`Pre<Pass>_<Prop>` attributes, or a JSON on disk through the bridge for very large passes).
3. **Writes a log** (what changed, where the backup is) to disk.
4. **Has a Restore**, tested once on a small folder before the real run.

What not to rely on: **undo in a shared place**. The undo stack is per place session and shared; an undo to recover one thing can roll back other people's changes, and every scripted change adds a waypoint that wipes redo (measured in one production game). In a single-user plugin, recording your change properly is still good manners:

```lua
-- Plugin context: group a batch change into one undo step (single-user sessions).
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local id = ChangeHistoryService:TryBeginRecording("RetexturePass", "Retexture rocks")
if id then
	local ok, err = pcall(function()
		-- ... the change ...
	end)
	ChangeHistoryService:FinishRecording(id, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	if not ok then warn(err) end
end
```

## Rule 5: deletion is a pipeline too

Deleting old content is where batch tools do the most good and the most harm. The reference project's cleanup history (measured in one production game):

| Pass | Effect |
|---|---|
| archive of imported sources, old animation saves and backups, exported to `.rbxm` first | place from about 2.36 million to about 955,000 instances |
| dead weight (duplicate animation copies, removed enemies, dated backups) | to about 599,000 |
| cleanup pass with inventory and log | 191,089 instances deleted |
| baking clips to stubs, originals archived to disk | ReplicatedStorage 392k to 107k instances on every client; ServerStorage 1.96M to 712k, then 420k |

The deletion pipeline that made those safe:

1. **Inventory**: what exists, how big, what references it. Search all scripts, including **dynamic string lookups** (`FindFirstChild(name .. "Kit")`), config tables and attribute values, not just direct paths.
2. **Classify**: safe, risky (ask), keep.
3. **Export** what will be deleted to `.rbxm` or JSON on disk.
4. **Dry run**, then delete in slices, logging every path.
5. **Verify** the game still compiles and the checks pass.

And a rule about backups themselves: in-place backup folders are not free. At about 1.07 million instances Studio ran at 15 fps; the owner then deleted all backup folders and the rule became "one small safety copy per pass, deleted after verification; everything else on disk or in version history". See [[Case Study - Instance Cleanup and Place Size]] and [[Case Study - Cutting a Million Instances]].

## Rule 6: tools gate themselves

Tools that write scripts or modules run the standard gates before saving: compile (`loadstring`), use-before-definition scan, source size under 200,000 characters, clone-require. Tools that write assets check their invariants (no forbidden ids, names follow the grammar, counts match). A tool that can produce a broken place will, eventually, at 2 a.m.

## Working alongside others

In a shared place (Team Create, or several agents on one Studio):

- **Own your area.** Tools touch only the folders their pass owns; test objects are named with your prefix and placed at your own test spot, then removed.
- **Compare before overwrite.** Before replacing a script, compare Studio's current source with the base you read.
- **Never start or stop Play from a tool** while others may be testing; Edit calls fail while Studio is in Play ("Edit datamodel is not available"), so tools should detect that and wait.
- **Switch previews off.** Tools that preview lighting, weather or cameras must restore them; one project's weather controller read the place's Atmosphere at Play start, so a forgotten preview changed the live look. After positioned viewport captures, reset the camera to Custom.

See [[Multiple Agents in One Studio]] and [[Safety Rules for AI Agents in Studio]].

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Studio freezes for minutes | unsliced loop, background work, too many offline processes | slice under budget; no background loops; cap processes |
| Tool sees old module code | `require` cache in Edit | clone-require |
| `HttpError` mid-pipeline | local server died, wrong port | watchdog, port map |
| Throttled HTTP | one request per item | one JSON per batch |
| Deleted something still used | reference search missed dynamic lookups | inventory includes string patterns and config |
| Cannot undo a pass | relied on undo; no stored originals | `Pre*` attributes, disk backups, Restore |
| Place slows down over weeks | backup folders accumulating | one safety copy, delete after verify |

## Checklist

- [ ] Tools in a DevTools folder or served from disk; consistent Status / Run / Verify / Restore
- [ ] Return data, not prints
- [ ] Sliced work under about 1 s per call; no background loops
- [ ] Heavy maths offline; limited processes and threads
- [ ] Local bridge bound to 127.0.0.1, root-restricted, one JSON per batch
- [ ] Dry run default; originals stored; log written; Restore tested
- [ ] Deletion with inventory, export, dry run and verify
- [ ] Gates before any script write
- [ ] Shared-place etiquette: own area, compare before overwrite, never toggle Play

## See also

[[Command Bar and Studio Scripting]] · [[Plugins - Using and Writing]] · [[Studio Plugins and Local HTTP Bridges]] · [[Studio Tooling Architecture]] · [[Clip Archive Server]] · [[Safe Changes in a Shared Place]] · [[Memory Budgets and Leaks]] · [[Blender Automation with Python]] · [[Pipeline Design Principles]]

## Connected notes
<!-- auto-links:start -->
[[AI Agents and Autonomous Workflows]] · Writing Your Own MCP Server · MCP Workflows for Building Worlds · Version History and Backups · Case Study - Building a Game with AI Agents · Plugin Development Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - Building a Game with AI Agents]] · [[Writing Your Own MCP Server]] · [[Code Pipeline - Rojo Git and CI]] · [[Icon and Thumbnail Rendering Pipeline]] · [[Build Test and Release Pipeline]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Environment and Level Pipeline]] · [[Asset Upload Automation with Open Cloud]] · [[Character and Creature Pipeline]] · [[Art Pipeline - Concept to In-Game Asset]]
<!-- related:end -->
