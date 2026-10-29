---
tags: [performance, scripting, luau, script-profiler, runservice, scheduling, type/guide, area/performance, level/intermediate, api/PreRender, area/data, api/Heartbeat]
---
# Script Performance

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Heavy work in `PreRender`/`RenderStepped`.
> - Avoid: One connection per object instead of one loop over a list.
> - Avoid: Loops that keep running while their UI or object is hidden.
> - Script Profiler run on client and server under realistic load; top 5 functions known.
> - Every per-frame loop has an idle gate (hidden, off-screen, far).
> - Non-critical updates moved to a cadence scheduler with random phase.
>
> Cost: TL;DR ~150 tok · whole note ~3.9k tok. Read more: ## 1. Finding script cost · ## 3. The patterns that win · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most Roblox games that run badly are not slowed by one expensive script. They are slowed by **many cheap things that run when they do not need to**: a UI animation loop for a hidden menu, a healthbar updating every frame for an enemy 400 studs away, a quest timer rewriting the same text sixty times a second. This note covers how to find script cost (Script Profiler, MicroProfiler labels), which frame event to use, and the patterns that cut script time: gating, cadence, distance tiers, write-on-change, time-slicing, and when Parallel Luau and native codegen are worth it.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

For language-level speed (fastcalls, table access, `--!native`), see [[Luau Performance and Native Codegen]]. This note is about *what runs and when*.

---

## 1. Finding script cost

### The Script Profiler (Docs)
A sampling profiler in the Developer Console (tools dropdown, ScriptProfiler).

| Setting | Options |
|---|---|
| Environment | Client (default) or Server; server data is cleared when the session ends |
| Frequency | 1 kHz (default) or 10 kHz; higher is more precise but costs more and can still miss very frequent API calls |
| Session length | 1, 5, 10 minutes, or Manual |
| Live polling | off by default; refreshes each second |

Reading:
- **Callgraph** view (default) groups functions in a tree under frame task categories (Stepped, Heartbeat, ...). Hover for file and line.
- **Functions** view lists functions flat, sorted by time. Start here to find the top cost.
- Units: milliseconds or percentage of the session. **Average** can be set per second or per minute to normalise.
- It records only CPU-consuming calls. A thread waiting in `task.wait` is invisible, which is what you want.
- Anonymous functions appear as `<anonymous>`; hover for the source line. Naming your handlers (`local function onHeartbeat(dt)`) makes profiles readable.
- **Export** writes JSON: categories, nodes with `TotalDuration` in microseconds, functions with name, source and line, and flags (bit 0 = ran as native code, bit 1 = plugin). Keep exports from before and after a change.

### When to use which
| Need | Tool |
|---|---|
| "Which of my functions costs most over a minute of play?" | Script Profiler, Functions view |
| "Why is *this* frame slow?" | [[MicroProfiler Guide]] |
| "Is this loop worth optimising?" | `debug.profilebegin` label, then MicroProfiler Timers mode |
| "Did native codegen kick in?" | Script Profiler export flags |

---

## 2. Choosing the frame event

Docs: limit code on `PreAnimation`, `PreRender`, `PreSimulation`, `PostSimulation` and `Heartbeat` to things that need per-frame updates. Order and semantics in [[Frame Order and RunService Timing]].

| Event | Runs | Use for | Avoid |
|---|---|---|---|
| `PreRender` (`RenderStepped`) | client, before render; blocks the frame | camera, aiming, things that must match this frame's render | anything heavy; it delays the frame directly |
| `PreAnimation` | before the Animator steps | changing animation inputs | |
| `PreSimulation` (`Stepped`) | before physics | setting velocities and forces | |
| `PostSimulation` / `Heartbeat` | after physics | most game logic, visuals that read physics results | |
| `BindToRenderStep` | client, at a chosen priority | ordering relative to the camera and input | |

Server code has no render; use `Heartbeat` or `PreSimulation`.

Rule of thumb: `PreRender` is where cost hurts most, because nothing else can happen on the main thread until it returns. Put only camera and input-critical work there.

---

## 3. The patterns that win

### 3.1 Gate loops by visibility

A loop that animates something nobody can see is the most common waste on the client.

```lua
--!strict
-- A UI effect loop that runs only while its GUI is visible, and disconnects when idle.
local RunService = game:GetService("RunService")

local function bindVisibleLoop(guiObject: GuiObject, step: (dt: number) -> ()): () -> ()
	local conn: RBXScriptConnection? = nil

	local function refresh()
		-- Visible checks only this object; also stop if any ancestor ScreenGui is disabled.
		local screen = guiObject:FindFirstAncestorWhichIsA("LayerCollector")
		local shown = guiObject.Visible and screen ~= nil and screen.Enabled
		if shown and not conn then
			conn = RunService.PreRender:Connect(step)
		elseif not shown and conn then
			conn:Disconnect()
			conn = nil
		end
	end

	local c1 = guiObject:GetPropertyChangedSignal("Visible"):Connect(refresh)
	local c2 = guiObject.AncestryChanged:Connect(refresh)
	refresh()

	return function() -- cleanup
		c1:Disconnect()
		c2:Disconnect()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end
end

return bindVisibleLoop
```

This checks the object's own `Visible` and its ScreenGui; if parents in between can be hidden, watch them too or have the menu controller call `refresh` on open and close. **Measured:** the reference project audited client loops after a "lag" report and found several `RenderStepped` handlers running while idle (a tutorial pointer, card hover effects, a reveal animation). Each was cheap; together they were a steady cost on every frame of every session. The fixes were exactly this: run only while something is shown, and "one on-demand RenderStepped, none while idle" for a UI motion system.

For world objects, "visible" means on-screen and near. `Camera:WorldToViewportPoint` returns an on-screen boolean; check it every few frames, not every frame.

### 3.2 Lower the cadence

Not everything needs 60 Hz.

| Thing | Rate that looks right (rule of thumb unless noted) |
|---|---|
| Camera, aim, own character effects | every frame |
| Healthbars, nameplates | 10 Hz, or on change |
| Quest countdown text | 4 Hz, write on change (Measured) |
| Foliage sway near the camera | 30 Hz (Measured) |
| Minimap markers | 4 to 10 Hz |
| AI decisions (think) | 2 to 10 Hz, per-entity random phase |
| Leaderboards, stats panels | 1 Hz or on change |

```lua
--!strict
-- A cadence scheduler: one Heartbeat drives many jobs at their own rates.
local RunService = game:GetService("RunService")

type Job = { interval: number, acc: number, fn: (elapsed: number) -> () }
local jobs: { Job } = {}

local Scheduler = {}

function Scheduler.every(interval: number, fn: (elapsed: number) -> ()): () -> ()
	-- Random phase so jobs with the same interval do not all fire on one frame.
	local job: Job = { interval = interval, acc = math.random() * interval, fn = fn }
	table.insert(jobs, job)
	return function()
		local i = table.find(jobs, job)
		if i then
			table.remove(jobs, i)
		end
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	for i = #jobs, 1, -1 do -- reverse: a job may remove itself
		local job = jobs[i]
		if job then
			job.acc += dt
			if job.acc >= job.interval then
				local elapsed = job.acc
				job.acc = 0
				job.fn(elapsed) -- pass real elapsed time, not the interval
			end
		end
	end
end)

return Scheduler
```

Two details: **pass the real elapsed time** (otherwise lower-rate things run in slow motion when frames are long), and **randomise the phase** (otherwise every 10 Hz job spikes the same frame).

### 3.3 Distance tiers
Far things update less often or not at all. The reference project's character animation tiers: every frame within 60 studs, every 2nd frame to 150, every 4th to 300, time only beyond; off-screen time only; tiers re-evaluated every 15 frames with a random phase. Full details and other schedules in [[Animation LOD]]. The same shape applies to AI, nameplates, ambient props.

### 3.4 Write only on change
Setting a property to its current value is not free: it goes through the property system, may invalidate layout or rendering, and on the server may replicate.

```lua
--!strict
local lastText = ""
local function setTimer(label: TextLabel, secondsLeft: number)
	local s = math.max(0, math.floor(secondsLeft)) -- %d needs an integral number
	local text = string.format("%d:%02d", s // 60, s % 60)
	if text ~= lastText then -- skip identical writes
		lastText = text
		label.Text = text
	end
end
```

For UI this also avoids `UpdateUILayouts` work every frame ([[MicroProfiler Guide]]).

### 3.5 Event-driven instead of polling
`while true do task.wait(0.1) if x then ... end end` should almost always be a signal: `GetAttributeChangedSignal`, `GetPropertyChangedSignal`, `ChildAdded`, a custom signal. Poll only when no event exists, and then at low rate.

### 3.6 Cache lookups outside the loop
`FindFirstChild` chains, `GetChildren()`, `GetDescendants()` and `CollectionService:GetTagged()` each walk the tree and allocate a fresh table. Resolve references once, maintain lists with `ChildAdded`/`ChildRemoved` or tag signals, iterate your list per frame.

### 3.7 Avoid per-frame allocation
Fresh tables, closures and string concatenation inside per-frame code feed the garbage collector, which shows up as `GC` time and periodic hitches.

| Instead of | Do |
|---|---|
| `local pos = {x, y, z}` per frame | reuse a module-level table or use `Vector3` (a value type) |
| `obj:GetChildren()` per frame | cached list |
| `"Enemy_" .. id` per frame | precomputed strings |
| creating a closure per call (`task.delay(t, function() ... end)` inside a hot loop) | a shared function plus arguments: `task.delay(t, fn, a, b)` |
| `table.insert` growing an array from empty each frame | `table.clear` and refill, or `table.create(n)` |

### 3.8 Spread big work over frames (time-slicing)
Building a 2,000-entry inventory grid, spawning a wave, regenerating a region: do it in slices with a per-frame time budget.

```lua
--!strict
-- Run `items` through `work` without exceeding `budgetMs` per frame.
local RunService = game:GetService("RunService")

local function sliced<T>(items: { T }, budgetMs: number, work: (T) -> ())
	local i = 1
	while i <= #items do
		local start = os.clock()
		while i <= #items and (os.clock() - start) * 1000 < budgetMs do
			work(items[i])
			i += 1
		end
		if i <= #items then
			RunService.Heartbeat:Wait() -- yield to the next frame
		end
	end
end

return sliced
```

Docs suggest the same for server-side map loading: chunk large hierarchies and build them over several frames, because creating big trees at once is also network-heavy.

### 3.9 Server: scale with players, not players squared
Server loops that iterate all players **for each** player, or broadcast every hit to everyone, grow quadratically. **Measured** fixes from a server performance audit in the reference project:
- Per-hit broadcasts (blood VFX, hit sounds, projectile positions) are filtered by distance (320 studs, matching the enemy system's "near" radius) instead of going to every client.
- Enemy ground snapping used a raycast per enemy per think; it was replaced with a cached 2-stud height grid (rebuilt in generations every 4 s, exact raycast only on ambiguous cells), with a measured maximum error of 0.233 studs.
- A per-player state push loop now yields between players instead of doing all players in one frame; a potion resync went from every 5 s for everyone to every 30 s and only while a potion is active.

---

## 4. Parallel Luau

Parallel Luau runs code on worker threads inside Actors. It helps when you have a lot of **independent computation** per frame (many raycasts for many agents, procedural generation, pathing heuristics) and can keep data-model writes to a short serial phase. See [[Parallel Luau and Actors]].

When it does not help:
- The work is mostly writing properties (writes must happen in the serial phase).
- The work is small; the synchronisation overhead exceeds the gain.
- The bottleneck is not scripts at all (rendering, physics).

Docs (improve page): use multithreading for expensive tasks that don't need to access the data model.

## 5. Native code generation

`--!native` at the top of a script (or `@native` on a function) compiles Luau to machine code where supported. Docs mention it can help some server-side scripts. It helps arithmetic-heavy loops (math, buffers, procedural generation); it does little for code dominated by engine API calls. Use the Script Profiler export's native flag to confirm what actually ran natively, and `debug.dumpcodesize()` (Command Bar only, Docs) to see code size. Details in [[Luau Performance and Native Codegen]].

---

## 6. A worked audit (Measured, anonymised)

After a player report of "immense lag", the reference project ran a client and server audit. The ranking that came out of the profiles, biggest first:

1. **Replicated per-player JSON blobs.** Several large inventory and progress strings were stored as attributes on the Player, so every update replicated to every client. Moved to owner-only state (see [[Network Performance]]).
2. **Idle client loops** (section 3.1): gated.
3. **Kill feedback bursts**: a full blood splat per kill and a separate loot burst per kill. Capped to 3 full splats per second; kills within 0.25 s merged into one loot burst with summed cash; loot icons capped from 60 to 24; icon outlines reduced from 4 copies to 1.
4. **Server per-hit broadcasts and raycast ground snapping** (section 3.9).

None of these were "slow code". All were "code running more often, or for more recipients, than needed".

---

## Common mistakes

- Heavy work in `PreRender`/`RenderStepped`.
- One connection per object instead of one loop over a list.
- Loops that keep running while their UI or object is hidden.
- Same-rate timers all firing on the same frame.
- Lower-rate updates that advance by a fixed step instead of the real elapsed time.
- Writing unchanged values every frame.
- Polling where an event exists.
- Reaching for Parallel Luau or `--!native` before fixing what runs and how often.

## Checklist

- [ ] Script Profiler run on client and server under realistic load; top 5 functions known.
- [ ] Every per-frame loop has an idle gate (hidden, off-screen, far).
- [ ] Non-critical updates moved to a cadence scheduler with random phase.
- [ ] Text and property writes happen only on change.
- [ ] Hot loops allocate nothing per iteration.
- [ ] Large builds are time-sliced.
- [ ] Server broadcasts are distance-filtered; no O(players squared) loops.
- [ ] Handlers are named functions so profiles are readable.

## See also

[[Performance Fundamentals]] · [[MicroProfiler Guide]] · [[Memory Budgets and Leaks]] · [[Luau Performance and Native Codegen]] · [[Parallel Luau and Actors]] · [[Task Library Coroutines and Yielding]] · [[Events Signals and Connections]] · [[Frame Order and RunService Timing]] · [[Animation LOD]]

## Connected notes
<!-- auto-links:start -->
[[Luau Performance Patterns with Benchmarks]] · Luau Garbage Collection and the Memory Model · Functions Closures and Upvalues · Frame Budget · Official Docs - Scripting and Luau · Skill - Roblox Performance Audit
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Luau Garbage Collection and the Memory Model]] · [[Network Bandwidth Budgets and Measuring Them]] · [[Developer Console and Stats]] · [[Rendering Performance]] · [[Physics Performance]] · [[Mobile and Low-End Optimization]] · [[Hunting Memory Leaks Step by Step]] · [[Client Zone Culling for Interiors and Cities]] · [[Load and Soak Testing Servers - Long Sessions and Many Clients]]
<!-- related:end -->
