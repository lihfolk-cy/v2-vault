---
tags: [pipeline, tooling, studio, http, architecture]
---
# Studio Tooling Architecture

<!-- tldr:start -->
> [!tldr] TL;DR
> - Studio side does only dump, play or write.
> - Every loop has a time budget and returns a resume index.
> - One POST per batch; HttpService budget respected.
> - Shared modules read with clone-require.
> - Writes are idempotent, size-checked, compiled, scanned, verified by clone-require, with one safety copy.
> - Writes derived from a dump verify a fingerprint.
>
> Read more (18 KB note): ## The split · ## Measuring truth: playing a clip on the real Animator · ## Checklist for a new tool
<!-- tldr:end -->

How to build heavy animation tooling (IK baking, QA scoring, clip compression, archiving) around Roblox Studio without freezing it, corrupting shared scripts, or trusting stale data. Everything here was run in production on one live action game with several hundred attack clips, well over a thousand enemy clips and several hundred weapon-part clips, and most rules exist because the obvious approach broke first.

The short version: **Studio is an I/O device and a ground-truth oracle. The maths lives outside it.**

## Why not just do it all in Studio?

You can run surprisingly heavy Luau in the command bar or a plugin. The reasons the reference project moved the work out anyway:

| Problem in Studio | What it looked like | Consequence |
|---|---|---|
| Long synchronous calls | The Studio UI stops repainting; with several tools sharing one Studio, one long call blocks everyone | A rule: every Studio call stays short (see budgets below) |
| CPU-heavy maths in Luau | A coordinate-descent IK solve took about 0.5 s per baked frame; an unreachable target could take over 1 s per frame | Offline numpy solves the same problem for a whole clip in 10-40 s while costing Studio about 0.1 s |
| No real vector maths library | Every Viterbi, Gaussian filter and grid search is hand-written | Python + numpy vectorises over all frames and all candidates at once |
| Shared undo stack | One undo rolls back another tool's (or person's) edit | Tools never rely on undo: they keep one explicit safety copy instead |
| Stale `require` cache | Tools read an old copy of a module you just edited | Clone-and-require pattern (below) |

The one thing Studio is uniquely good at: **it runs the real Animator**. `Animator:StepAnimations(dt)` plays a clip exactly as the engine will, so Studio is where you measure truth. The offline model is only trusted after it has been checked against that truth (in the reference project, a median of 0.03 deg over several hundred clips, see [[How the Animator Really Behaves]]).

## The split

```
          +-------------------------- Studio (Edit mode only) ---------------------------+
          |  dump clips / rig / idle  -->  POST JSON                                      |
          |  play clips on the real Animator (StepAnimations) --> POST joint Transforms   |
          |  write results into KeyframeSequences (test folder, install, rollback)        |
          +---------------------------------^----------------------------+---------------+
                                            | GET tool source / payload  | POST results
          +---------------------------------+----------------------------v---------------+
          |  local static file server (serves .lua tools and bake JSON)                  |
          |  local receiver (writes POST bodies to data/, clips/, truth/, out/)           |
          +---------------------------------^----------------------------+---------------+
                                            | files                      |
          +---------------------------------+----------------------------v---------------+
          |  offline: Python + numpy                                                      |
          |  Animator model, FK, QA metrics, IK solver, key fitting, filmstrip renderer   |
          +------------------------------------------------------------------------------+
```

Three kinds of Studio call exist, and only three:

1. **Dump.** Read instances (rig attachments, part sizes, every Pose of every clip, the idle) and POST them as JSON.
2. **Play.** Clone a dummy, play a clip on the real Animator frame by frame, read every joint's `Transform`, POST the frames.
3. **Write.** Fetch a payload computed offline and build KeyframeSequences from it, with safety checks.

Everything in between (solving, scoring, deciding) happens offline and can be rerun without touching Studio.

## Getting code into Studio: the loadstring loader

Tools are plain `.lua` files on disk served by a local static HTTP server. The command bar fetches and runs them:

```lua
-- Command bar / plugin context (loadstring is available there; in live servers it needs LoadStringEnabled)
local HttpService = game:GetService("HttpService")
local src = HttpService:GetAsync("http://127.0.0.1:8765/tools/armcheck.lua?x=" .. os.clock(), true)
local tool = loadstring(src)              -- compile; returns nil + error on a syntax error
assert(tool, "tool did not compile")
return tool({ mode = "clips", only = { "kitA" }, budget = 1.5 })
```

Details that matter:

- **Cache busting.** The `?x=` query string with `os.clock()` makes every fetch a new URL, so you never run yesterday's tool after editing it. The second argument `true` to `GetAsync` is `nocache`, but the query string is the belt to that pair of braces.
- **Tools take one table of arguments** and return a string report. A report string is the only thing you need to read back; keep it short.
- **The tool file is the only copy that matters.** Nothing is installed into the place unless a write mode says so. That keeps the place clean and makes tools versionable on disk.

## Getting data out: the receiver

A tiny HTTP server on localhost accepts `POST /<sub>/<name>` and writes the body to `<root>/<sub>/<name>`. The reference receiver is about 15 lines of Python:

- `sub` is restricted to a whitelist (`data`, `clips`, `out`, `truth`).
- `name` must match `[A-Za-z0-9_.-]+`. Anything else is a 400. This is the entire security model, and it is enough for localhost: no path can escape the root.
- It is a threaded server, so a slow write never blocks the next POST.

Studio side:

```lua
local function post(path: string, tbl: {[any]: any}): (boolean, string?, number)
	local body = HttpService:JSONEncode(tbl)
	local ok, r = pcall(function()
		return HttpService:PostAsync("http://127.0.0.1:8833/" .. path, body, Enum.HttpContentType.ApplicationJson)
	end)
	return ok, r, #body
end
```

Round every number before encoding (the reference dump rounds CFrame components to 1e-5). JSON of raw doubles is two to three times larger, and the extra digits are noise that later makes checksums disagree.

### The HttpService budget

HttpService allows about **500 requests per minute for the whole place** (Roblox limit). Two consequences:

- **One POST per kit, not per clip.** A dump of several hundred clips as one request each eats most of a minute's budget; the reference dump groups clips by kit (one JSON per kit, `{ kitId, moves = {...} }`).
- **Pace archive traffic.** The clip archive tools wait 0.13 s between requests. On the error `Number of requests exceeded limit`, stop and wait a full 60 s.

## Budgeted loops: never block, always resumable

Every Studio-side loop carries a time budget and a resume index:

```lua
local BUDGET = args.budget or 1.5
local t0 = os.clock()
for i = args.i0 or 1, #ids do
	if os.clock() - t0 > BUDGET then
		return ("stopped early, call again with i0=%d"):format(i)   -- the caller resumes from here
	end
	-- ... one unit of work (one kit) ...
end
return "done"
```

The caller just calls again with `i0`. For work that is a single long computation rather than a list (a sliced bake of one clip), split it into `begin(state)` and `step(state, budget)`:

```lua
_G.Bake = _G.Bake or {}
local st = _G.Bake[key]
if not st then st = { b = Rig.bakeBegin(spec) }; _G.Bake[key] = st; return "loaded, call again" end
local done = Rig.bakeStep(st.b, 0.9)            -- does frames until 0.9 s have passed
if not done then return ("frame %d/%d"):format(st.b.fi, #st.b.times) end
```

State lives in `_G` between calls because each `loadstring` run is a fresh chunk. Clear the entry when finished, and provide a `restart` flag for when a stuck state needs throwing away.

**What budget?** The reference project changed its rule over time: one tool defaulted to 3.5 s, its README said 5 s, and the later rule was **1.5 s per call, one call at a time**, after a long Studio hang that was suspected (not proven) to come from long calls. Treat 1.5 s as the safe number. Measured examples that fit: writing two baked clips (about 0.3 s), playing four clips through the Animator at 60 Hz (about 0.9 s).

## Stale `require` in Edit mode, and the clone-require pattern

In Edit mode `require()` caches a module's return value for the session. Edit the ModuleScript, require it again from the command bar, and you get the old table. Tools that read shared configuration (a kit registry, a game config, a player module) would silently use stale data.

The fix used by every tool in the reference project:

```lua
local function fresh(mod: ModuleScript): any
	local c = mod:Clone()
	c.Parent = mod.Parent       -- same parent so relative requires inside it still resolve
	local ok, r = pcall(require, c)
	c:Destroy()
	if not ok then error(r) end
	return r
end
```

Gotchas:

- **Parent the clone beside the original.** A module that does `script.Parent:WaitForChild(...)` or requires siblings breaks if the clone sits elsewhere.
- **Children are cloned too,** so data submodules come along.
- **A destroyed clone that `WaitForChild`s its own children later hangs.** If the module defers work (`task.defer`) that touches `script`, the clone is gone by then. Prefer modules that do their lookups at require time.
- When you must patch a dependency for a check (for example, point a module at a cloned config), clone both and rewrite the clone's Source string, then destroy both. The weapon pipeline's hold check does exactly this.

## Safe edits to shared scripts

Several tools (and people) edit the same registry modules: kit tables, icon tables, config. The reference procedure, implemented once as a `patch(module, alreadyMarker, editFn, tag)` helper:

1. **Idempotency check.** If the source already contains the line you would add, return "already there". Rerunning a stage is then harmless.
2. **Re-read the source immediately before editing,** compute the new source with a single anchored insert.
3. **Size check.** A Script `Source` over 200,000 characters fails to save ("Unable to assign property Source"). Refuse before trying. Real near misses in the project: 195,812 and 192,059 characters.
4. **Compile** the new source with `loadstring`.
5. **Static scan.** A use-before-definition scanner catches locals referenced above their declaration, which compile fine and fail at runtime.
6. **One safety copy** of the module before the first edit (source only, children stripped), never overwritten afterwards.
7. **Changed-underneath check.** If `mod.Source` differs from what you read in step 2, someone edited it meanwhile: abort.
8. **Write, then clone-require the result.** If the edited module does not load, write the old source back.

A related limit: a single Luau function scope allows 200 local variables. Generated code that declares a local per item hits it; use tables.

## Fingerprints: refuse stale data

The offline bake is computed from a dump. If anyone changes the clip in Studio between dump and install, installing would silently overwrite their change. The arm baker therefore ships a **fingerprint** of the clip it was computed from (instance count, keyframe count, weighted-pose count, and a checksum of every weighted Pose CFrame). The installer recomputes it on the live clip and refuses on mismatch with a clear "re-dump and bake again" message. See [[Arm Baker Internals]] for the exact checksum.

General rule: **any write derived from a read must verify the read is still current.**

## Safety copies, test folders and rollback

- **Test before install.** Every writer has a `test` mode that builds into a separate folder and never touches the live asset, so it can be played and measured.
- **One safety copy, kept once.** `install` keeps the first original. A later reinstall does not overwrite it, so rollback always returns to the true original, not to bake N-1.
- **Never bake a baked clip.** Baked clips are stamped (an attribute with the tool version). The offline side refuses a stamped dump; the Studio side rebuilds from the safety copy.
- **Backups do not live in the place forever.** In the reference project, backup folders inside the place grew to hundreds of thousands of instances and slowed Studio to about 15 fps at over a million instances. The later rule: back up to disk (an `.rbxm` per asset through an archive server, see [[Clip Archive Server]]) and rely on Roblox version history.

## Measuring truth: playing a clip on the real Animator

This is the most reused Studio routine in the whole toolchain:

```lua
local KSP = game:GetService("KeyframeSequenceProvider")

local function playOne(dummyTemplate: Model, ks: KeyframeSequence, rate: number)
	local rig = dummyTemplate:Clone()
	rig:PivotTo(CFrame.new(0, 500, 0))              -- far from the map
	rig.HumanoidRootPart.Anchored = true
	rig.Parent = workspace
	local scale = rig:GetScale()
	local joints = {}
	for _, c in rig:GetDescendants() do
		if c:IsA("AnimationConstraint") and c.Attachment1 then joints[c.Attachment1.Parent.Name] = c end
	end
	local animator = rig.Humanoid:FindFirstChildOfClass("Animator")
	local a = Instance.new("Animation")
	a.AnimationId = KSP:RegisterKeyframeSequence(ks)  -- fine for Studio measurement (see note below)
	local tr = animator:LoadAnimation(a)
	tr.Priority = Enum.AnimationPriority.Action4
	tr.Looped = false
	local w0 = os.clock()
	while tr.Length <= 0 and os.clock() - w0 < 2 do task.wait() end   -- a fresh registration loads asynchronously
	local loaded = tr.Length > 0
	tr:Play(0)                                          -- fade 0: measure the clip, not the blend
	animator:StepAnimations(0)
	local frames, len = {}, 0
	for _, kf in ks:GetKeyframes() do len = math.max(len, kf.Time) end
	for i = 0, math.floor(len * rate + 0.5) do
		local row = {}
		for name, c in joints do
			local T = c.Transform
			row[name] = T.Rotation + T.Position / scale  -- model-scaled dummy: divide offsets back
		end
		frames[#frames + 1] = row
		animator:StepAnimations(1 / rate)
	end
	tr:Stop(0); rig:Destroy(); a:Destroy()
	return frames, loaded
end
```

Notes:

- **Always report `loaded`.** A result showing about 117 deg of error and `loaded = false` was simply a freshly registered clip whose track still had `Length = 0`. Waiting for `Length > 0` fixed it.
- `RegisterKeyframeSequence` is used here only to measure in Studio. Its ids did not play in live servers in the reference project (see [[Case Study - Abilities That Only Worked in Studio]]). Never ship it.
- **Character rigs may use AnimationConstraint, not Motor6D.** Read whichever joint type the rig has; the dummy here uses AnimationConstraint, whose `Transform` the Animator writes.
- **Scale.** On a model-scaled dummy (`Model:GetScale() = 1.6`) the Animator multiplies clip offsets by the scale; on a body-scaled character it does not. Divide back so dumps are in clip units. See [[Scale and Animation]].
- **Edit-mode limits.** No physics runs in Edit; `StepAnimations` needs `dt > 0` to advance; `Motor6D.Transform` written by your own code does not move parts until something steps them (see [[Weapon Rig Player]] for the manual-step hook).

## Filmstrips and screenshots

Numbers are not enough; every bake is also rendered. The reference toolchain renders box-figure filmstrips offline (eight frames per clip, before and after) from the same FK that QA uses, so no Studio time is spent. When Studio screenshots are needed: a positioned capture leaves the Edit camera `Scriptable`, so restore `CameraType = Custom` (after a short delay); captures come back black when Studio is not the focused window.

## Running many offline jobs

- Offline bakes are CPU only and run in parallel, but numpy's math libraries spawn a thread per core by default. With about 18 bakers running at once plus simulations inside Studio, the machine pinned at 100% CPU and Studio froze for about 25 minutes. The rule became: **at most two baker processes per worker, each single-threaded** (`OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`, `MKL_NUM_THREADS=1`), and no background simulations inside Studio.
- On Windows, some native executables (Python launcher, Blender) reject very long working paths. Keep tool folders short or use short (8.3) paths, and start long-running local servers detached so a terminal closing does not kill them.

## Shared Studio etiquette

- **Edit mode only.** Tools never start or stop Play; if Studio is in Play, work offline and check again later.
- **One call at a time.** Two tools racing on the same instances produce exactly the class of bug fingerprints exist to catch.
- **Re-dump before baking** if anyone could have touched the clips.
- **Find things by name, never by Selection.** Several imports or test rigs can coexist; a tool that uses `game.Selection` acts on whatever happens to be selected.
- **Search top-level children** of large containers rather than `GetDescendants()` of Workspace, which took seconds in a large place.

## Checklist for a new tool

- [ ] Studio side does only dump, play or write.
- [ ] Every loop has a time budget and returns a resume index.
- [ ] One POST per batch; HttpService budget respected.
- [ ] Shared modules read with clone-require.
- [ ] Writes are idempotent, size-checked, compiled, scanned, verified by clone-require, with one safety copy.
- [ ] Writes derived from a dump verify a fingerprint.
- [ ] A `test` mode that never touches live assets, plus `install`, `rollback`, `status`.
- [ ] Results checked against the real Animator, with `loaded` reported.

## See also

- [[Pipeline - Arm IK Baking and QA]], [[Arm Baker Internals]], [[Arm QA Metrics Reference]]
- [[Baked Clip Stubs and Archiving]], [[Clip Archive Server]]
- [[How the Animator Really Behaves]], [[Testing Animations in Studio]], [[Engine Gotchas]], [[Open Questions]]

## Connected notes
<!-- auto-links:start -->
[[Batch Processing Tools in Studio]] · [[Command Bar and Studio Scripting]] · [[Studio Plugins and Local HTTP Bridges]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[AI Agents and Autonomous Workflows]] · [[Safety Rules for AI Agents in Studio]] · [[Animation Start Here]]
<!-- auto-links:end -->
