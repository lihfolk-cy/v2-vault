---
tags: [performance, memory, leaks, debugging, luau-heap, soak-test, procedure, type/guide, area/performance, level/advanced, api/LoadAnimation, area/scripting]
---
# Hunting Memory Leaks Step by Step

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Calling "memory did not drop after players left" a leak on the server.
> - Avoid: Measuring once instead of measuring a slope after warm-up.
> - Avoid: Reading client memory in Studio and treating it as the device number.
> - Workload held constant; at least three samples after warm-up.
> - Growth expressed as MB per hour or KB per repetition.
> - Time-to-ceiling estimated for server and for a low-end phone.
>
> Cost: TL;DR ~140 tok · whole note ~6.0k tok. Read more: ## 2. Find the category that grows · ## 6. Worked cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Memory Budgets and Leaks]] explains where memory goes, the leak patterns and the Luau heap tool. This note is the procedure: what to do from the first "memory feels high" report to a fix you can prove. It is written for the case that actually happens in production: a server that crashes after eight hours, or phones that start dropping after twenty minutes, and nobody knows which of forty systems is responsible.

The short version:

1. Decide whether it is a leak at all (many things that look like leaks are caches or engine behaviour).
2. Find which memory category grows.
3. Build a reproduction loop that grows it fast.
4. Bisect the systems until one remains.
5. Take heap snapshots around the loop to find who holds the memory.
6. Fix, then keep the reproduction loop as a regression test.

---

## 1. Is it really a leak?

A leak is memory that grows with *time or repetitions* under a *constant* workload and never comes back. Several normal behaviours look like that and are not.

| Looks like a leak | Why it is not (or might not be) | How to tell |
|---|---|---|
| Server memory does not fall after players leave | Roblox docs (as of October 2026) state server memory does not shrink when players leave; the allocator keeps pages | Compare memory at the same player count over time, not before and after a leave |
| Luau heap rises then drops in a sawtooth | Garbage collection runs in steps; the peaks are garbage awaiting collection | Look at the troughs. Rising troughs are a leak; rising peaks with flat troughs are allocation churn ([[Script Performance]]) |
| Texture memory jumps when entering a new zone | Textures are loaded on demand and cached | Walk back and forth between two zones ten times. A cache plateaus after the first round trip; a leak keeps stepping |
| Memory rises for the first 5 to 10 minutes | Warm-up: modules required, pools filled, assets streamed | Measure slope only after warm-up |
| Instance count climbs as the player explores | Streaming brings parts in ([[Instance Streaming]]) | Stand still for five minutes. Streaming settles; a leak does not |
| Sounds memory grows with new areas | Same as textures | Same round-trip test |

Rule of thumb: you need at least three data points after warm-up, under a repeated workload, before you call anything a leak. One reading proves nothing.

### Time to crash: decide how urgent it is

Roblox docs (as of October 2026) give a server memory total of about **6.25 GiB plus 100 MiB per player** at the peak player count, and recommend staying below 50% of it. For a 20-player server that is about 8.2 GiB total, so a comfortable ceiling of roughly 4 GiB.

If a server starts at 1.5 GiB after warm-up and grows 60 MB per hour, it reaches 4 GiB in about 42 hours. Most public servers do not live that long, so the leak is real but not urgent. The same 60 MB per hour leak on a phone client that starts at 1.1 GB is a crash in a long session on a 2 GB device. **Client leaks are usually more urgent than server leaks of the same size**, because the ceiling is lower and you do not control it.

Write the slope as "MB per hour" or "KB per repetition". Both are easier to reason about than a raw number.

---

## 2. Find the category that grows

The engine splits memory into tagged categories. `Stats:GetMemoryUsageMbForTag(tag)` reads them from a script, using `Enum.DeveloperMemoryTag` (Roblox docs, as of October 2026, list 25 values including `Instances`, `Signals`, `LuaHeap`, `Script`, `PhysicsCollision`, `BaseParts`, `GraphicsTexture`, `GraphicsMeshParts`, `GraphicsParticles`, `Sounds`, `Gui`, `Animation`, `Navigation`, `TerrainVoxels` and `GeometryCSG`). `Stats:GetTotalMemoryUsageMb()` gives the total.

The category tells you which family of bug to look for:

| Growing category | Usual cause |
|---|---|
| `LuaHeap` | Tables or closures kept by a module, upvalue or connection |
| `Signals` | Connections never disconnected; often one per respawn or per opened menu |
| `Instances` | Instances created and never destroyed, or destroyed but still referenced from Luau |
| `Animation` | Animation tracks loaded repeatedly (for example `LoadAnimation` on every attack) |
| `Gui` | UI cloned per open and never destroyed |
| `Sounds` | Sounds created per event and never destroyed |
| `GraphicsParticles` | Emitters created per hit and left parented |
| `Navigation` | Path objects created per request and kept |
| `PhysicsCollision` | Parts left behind (debris, projectiles) |

### A sampler you can leave running

This logs every category above a size threshold and computes the slope over a window. Put it in a server Script for server memory, and a LocalScript for client memory (it only reads stats, so it is cheap: one sample every 30 seconds).

```lua
--!strict
-- MemorySampler: logs per-category memory and the growth slope.
local Stats = game:GetService("Stats")

local SAMPLE_EVERY = 30 -- seconds
local WINDOW = 20 -- samples used for the slope (10 minutes)
local MIN_MB = 5 -- ignore tiny categories

type Series = { t: { number }, v: { number } }
local series: { [string]: Series } = {}

-- Least-squares slope of v over t, in units per hour.
local function slopePerHour(s: Series): number
	local n = #s.t
	if n < 3 then
		return 0
	end
	local mt, mv = 0, 0
	for i = 1, n do
		mt += s.t[i]
		mv += s.v[i]
	end
	mt /= n
	mv /= n
	local num, den = 0, 0
	for i = 1, n do
		num += (s.t[i] - mt) * (s.v[i] - mv)
		den += (s.t[i] - mt) ^ 2
	end
	if den == 0 then
		return 0
	end
	return num / den * 3600
end

local function push(name: string, now: number, value: number)
	local s = series[name]
	if not s then
		s = { t = {}, v = {} }
		series[name] = s
	end
	table.insert(s.t, now)
	table.insert(s.v, value)
	if #s.t > WINDOW then
		table.remove(s.t, 1)
		table.remove(s.v, 1)
	end
end

task.spawn(function()
	while true do
		task.wait(SAMPLE_EVERY)
		local now = os.clock()
		for _, tag in Enum.DeveloperMemoryTag:GetEnumItems() do
			local mb = Stats:GetMemoryUsageMbForTag(tag)
			if mb >= MIN_MB then
				push(tag.Name, now, mb)
			end
		end
		push("InstanceCount", now, Stats.InstanceCount)
		push("Total", now, Stats:GetTotalMemoryUsageMb())

		local lines = {}
		for name, s in series do
			local slope = slopePerHour(s)
			if math.abs(slope) > 1 then
				table.insert(lines, string.format("%s %.0f (%+.0f/h)", name, s.v[#s.v], slope))
			end
		end
		table.sort(lines)
		print("[mem] " .. table.concat(lines, " | "))
	end
end)
```

Notes on reading it:
- `InstanceCount` slope is in instances per hour; the others in MB per hour.
- Run it with a steady workload. A slope during a zone change is meaningless.
- On a live server, send the slope as an analytics custom event or to your own error pipeline instead of printing ([[Crash and Error Telemetry]]). A server that reports `Signals +40/h` overnight tells you exactly where to start.

The Developer Console's Memory tab (F9; on mobile type `/console` in chat, per Roblox docs) shows the same categories interactively ([[Developer Console and Stats]]). Use the client build, not Studio, for client numbers: Roblox docs note Studio readings include editor overhead.

---

## 3. Build a reproduction loop that grows it fast

Waiting eight hours for a crash is not debugging. You need a loop that multiplies the leak.

Good loops repeat the actions that create and remove things:

| Action | Catches |
|---|---|
| Respawn (`player:LoadCharacterAsync()` from the server) | Per-character connections, per-character tables, animation tracks |
| Equip and unequip a tool | Tool scripts that connect on equip and never disconnect |
| Open and close every menu | UI rebuilt per open, button connections |
| Enter and leave a zone | Zone setup and teardown, streamed-in handlers |
| Spawn and kill an enemy wave | NPC cleanup, hit effects, pathfinding |
| Player join and leave (multi-client test) | `PlayerRemoving` cleanup, per-player tables |

A server-side respawn loop is the single most productive one, because most leaks are per-character:

```lua
--!strict
-- Debug only: respawn one player N times and report growth per respawn.
-- Wire it to a gated developer command, never to a public remote.
local Stats = game:GetService("Stats")

local function respawnSoak(player: Player, cycles: number)
	local function sample(): (number, number, number)
		return Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap),
			Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Signals),
			Stats.InstanceCount
	end
	-- Warm up: the first few respawns load modules and fill pools.
	for _ = 1, 5 do
		player:LoadCharacterAsync()
		task.wait(1)
	end
	local h0, s0, i0 = sample()
	for _ = 1, cycles do
		if player.Parent == nil then
			return -- the player left; stop cleanly
		end
		player:LoadCharacterAsync()
		task.wait(1) -- let character scripts run their setup
	end
	local h1, s1, i1 = sample()
	print(string.format("[soak] per respawn: heap %+.3f MB, signals %+.3f MB, instances %+.1f",
		(h1 - h0) / cycles, (s1 - s0) / cycles, (i1 - i0) / cycles))
end

return respawnSoak
```

A clean game shows instance growth per respawn close to zero (rule of thumb: under 1) after warm-up. A result like "+42 instances per respawn" points straight at something that is cloned onto the character and parented elsewhere, or kept in a table.

Two things that make soak results lie:
- **Garbage not yet collected.** Luau collects incrementally. Before the final sample, wait a few seconds with no activity. `collectgarbage("collect")` is not available to game scripts in Roblox (only `collectgarbage("count")` is), so you cannot force a full cycle; waiting is the substitute.
- **Deferred events.** With deferred signal behaviour, handlers run later in the frame. A `task.wait(1)` after each action gives them time to finish.

For client-side loops, the same idea applies with menus and zones driven from a debug LocalScript, gated to developers ([[Multi-Client and Live Testing]] covers gating cheat tooling).

---

## 4. Bisect the systems

If you have 30 systems and no idea which one leaks, a binary search finds it in about five runs (2^5 = 32). It needs one thing in your architecture: **a way to switch systems off at boot**. If your bootstrapper starts services from a list ([[Project Structure and Bootstrapping]]), add a debug attribute that skips named services.

```lua
--!strict
-- Bootstrap excerpt: skip services listed in a debug attribute,
-- e.g. ServerScriptService:SetAttribute("DisabledServices", "Shop,Quests,Weather")
local ServerScriptService = game:GetService("ServerScriptService")

local disabled: { [string]: boolean } = {}
local list = ServerScriptService:GetAttribute("DisabledServices")
if typeof(list) == "string" then
	for name in string.gmatch(list, "[^,]+") do
		disabled[name] = true
	end
end

for _, module in ServerScriptService.Services:GetChildren() do
	if module:IsA("ModuleScript") and not disabled[module.Name] then
		local service = require(module) :: any
		if type(service.start) == "function" then
			task.spawn(service.start)
		end
	end
end
```

Procedure:
1. Run the soak with everything on; record the slope.
2. Disable half the systems; run again.
3. If the slope disappears, the leak is in the disabled half; otherwise in the enabled half.
4. Repeat on the guilty half.

Edge cases:
- **Two leaks.** The slope drops but does not vanish. Keep bisecting the half that still leaks, then come back for the other.
- **Dependencies.** Some systems cannot run without others. Bisect over groups that can be disabled together, and accept a few extra runs.
- **The leak is in the interaction.** Neither half alone leaks, both together do (for example system A fires an event that system B handles by creating a connection). When bisection gives contradictory answers, suspect this, and look at the cross-system events.

---

## 5. Find who holds the memory

Once you know the system, the Luau heap snapshot tells you the exact holder ([[Memory Budgets and Leaks]] describes the views). The productive way to use it:

1. Warm up, then take snapshot A.
2. Run the loop 100 times.
3. Wait 10 seconds idle, take snapshot B.
4. Compare. Look for counts that grew by about 100, or a multiple of it. A count that grew by exactly the number of repetitions is the leak; things that grew by 3 or 7 are noise.

What the views tell you:
- **Object Tags**: if `function` grew by 100, a closure is created per repetition and kept, almost always a connection handler. If `table` grew by 100, a per-use table is stored somewhere.
- **Unparented Instances**: instances no longer in the DataModel but still reachable from Luau. Each entry is a "destroyed but referenced" bug.
- **Graph**: the path from the root to the growing object. Read it bottom-up: the object, the table that holds it, the upvalue or module that holds that table.

Name your memory. `debug.setmemorycategory("Combat")` at the top of each system's threads splits the heap by system instead of by script, which turns "LuaHeap grows" into "Combat grows" without a bisection.

---

## 6. Worked cases

Each of these is a real shape of bug seen across Roblox projects. The pattern matters more than the specific system.

### Case A: a global connection per character

Symptom: `Signals` and `LuaHeap` grow per respawn. Heap snapshot shows functions growing by one per respawn, held by `RunService`.

```lua
-- Leaks: Heartbeat outlives the character, and its closure keeps the character alive.
player.CharacterAdded:Connect(function(character)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	RunService.Heartbeat:Connect(function()
		updateAura(root.Position)
	end)
end)
```

Destroying the character disconnects connections *on the character's instances*, not connections on services. The Heartbeat connection lives forever and pins `root`, and through it the whole character model.

```lua
--!strict
-- Fixed: the connection's lifetime is tied to the character.
local RunService = game:GetService("RunService")

local function onCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local conn = RunService.Heartbeat:Connect(function()
		updateAura(root.Position)
	end)
	-- AncestryChanged fires when the character is removed from the DataModel.
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			conn:Disconnect()
		end
	end)
end
```

If you have many such connections, use a cleanup object (a "maid", "janitor" or "trove": a table of things to disconnect or destroy, cleaned in one call). See [[Events Signals and Connections]].

A related engine setting: `Workspace.PlayerCharacterDestroyBehavior` (Roblox docs, as of October 2026: `Default`, `Disabled`, `Enabled`). `Enabled` makes the engine call `Destroy()` on old characters when they are replaced and on `Player` objects when players leave, which disconnects connections on those instances. The docs do not state plainly what `Default` resolves to today, and DevForum reports disagree; check it in Studio rather than assuming. Even with `Enabled`, Case A still leaks, because the connection is on `RunService`.

### Case B: the zombie entry after an async load

Symptom: a per-player table grows with total players who ever joined, even though there is a `PlayerRemoving` handler.

```lua
-- Leaks when the player leaves during the load.
Players.PlayerAdded:Connect(function(player)
	local data = loadProfileAsync(player) -- yields 0.5 to 5 s
	profiles[player] = data
end)
Players.PlayerRemoving:Connect(function(player)
	profiles[player] = nil
end)
```

If the player leaves while `loadProfileAsync` yields, `PlayerRemoving` runs first and removes nothing, then the load finishes and writes an entry nobody will ever remove. On a busy server with fast leavers (people who join, see the lobby and quit) this is hundreds of entries a day, each holding a `Player` and a profile table.

```lua
--!strict
Players.PlayerAdded:Connect(function(player: Player)
	local data = loadProfileAsync(player)
	if player.Parent == nil then
		-- Left during the load: release anything the load acquired (session lock),
		-- and do not store it.
		releaseProfile(player, data)
		return
	end
	profiles[player] = data
end)
```

The check after every yield is the rule: **any code that yields and then stores per-player state must re-check that the player is still here**. Session-locking libraries handle this for profiles ([[Session Locking and Profile Libraries]]), but your own per-player tables (cooldowns, party membership, open trades) need the same check.

### Case C: loading animation tracks per use

Symptom: `Animation` grows with attacks, not with time.

```lua
-- Creates a new AnimationTrack on every swing.
local function swing(animator: Animator, anim: Animation)
	animator:LoadAnimation(anim):Play()
end
```

Each `LoadAnimation` call creates a track the Animator keeps track of. Load once per animator and reuse:

```lua
--!strict
local trackCache: { [Animator]: { [Animation]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

local function getTrack(animator: Animator, anim: Animation): AnimationTrack
	local byAnim = trackCache[animator]
	if not byAnim then
		byAnim = {}
		trackCache[animator] = byAnim
	end
	local track = byAnim[anim]
	if not track then
		track = animator:LoadAnimation(anim)
		byAnim[anim] = track
	end
	return track
end
```

The weak keys here are a convenience, not the cleanup. Do not rely on a weak-keyed table to release an entry whose value references the key (a track references its animator); explicit cleanup when the character is removed is the safe path. Rule of thumb, because collection of weak keys with back-references depends on collector details that Roblox does not document. See [[Playback, Priorities and Blending]] for track lifetimes.

### Case D: loops that never end

Symptom: `LuaHeap` grows per spawned enemy; the `thread` count in Object Tags grows.

```lua
-- One infinite loop per enemy, alive after the enemy dies.
task.spawn(function()
	while true do
		task.wait(0.2)
		think(enemy)
	end
end)
```

The thread keeps running and keeps `enemy` alive. Give every loop an exit:

```lua
--!strict
task.spawn(function()
	while enemy.Parent ~= nil do
		task.wait(0.2)
		if enemy.Parent == nil then
			break -- re-check after the yield
		end
		think(enemy)
	end
end)
```

Better still, run one loop for all enemies over a registry, which removes the per-enemy thread entirely and is cheaper ([[Script Performance]]). If you keep per-object threads, store them and call `task.cancel(thread)` on removal.

### Case E: unbounded caches keyed by user input

Symptom: server `LuaHeap` grows slowly and forever, with no single action that reproduces it.

A cache keyed by anything players control (chat text, search strings, item filters, pet names) grows with the number of distinct inputs ever seen. Exploiters can grow it on purpose by sending random strings. Cap it: keep a count, and when it passes the cap either clear it or evict the oldest entries. A cap of a few thousand entries is usually plenty (rule of thumb). Also validate input length before it ever reaches the cache ([[Rate Limiting and Abuse Prevention]]).

### Case F: tagged-instance handlers without a removal path

```lua
-- Handles instances as they appear, never when they go.
for _, inst in CollectionService:GetTagged("Spinner") do setup(inst) end
CollectionService:GetInstanceAddedSignal("Spinner"):Connect(setup)
```

With streaming on, tagged instances leave and return constantly. Each return calls `setup` again, which creates new tweens and connections, while the old ones are kept by a table inside `setup`. Pair every added handler with `GetInstanceRemovedSignal` that tears down what `setup` built ([[CollectionService Patterns]]).

---

## 7. Fix, prove, keep

A fix is not done until the reproduction loop shows a flat line. Record the before and after in the change note: "respawn soak, 200 cycles: +42 instances, +0.18 MB heap per respawn before; +0.2 instances, +0.002 MB after". That sentence is the proof, and it also tells the next person what "normal" looks like.

Keep the loops. A soak harness that respawns 200 times and fails if growth per cycle is above a threshold is a regression test. Run it before releases that touch characters, tools, UI or enemies ([[QA Checklists Before Release]]).

From the reference project (measured): instance hygiene in the *place file* behaved like a slow leak of a different kind. Backup folders kept reappearing because people made "just in case" copies, and the instance count crept upward between cleanups. The lasting fix was a rule (no backup folders in the place; back up to disk) plus a periodic count by top-level folder. A runtime leak and a place-file creep need different tools, but the same habit: measure the trend, not the moment. See [[Case Study - Instance Cleanup and Place Size]].

---

## When not to hunt

- **The slope is tiny relative to session length.** A client growing 5 MB per hour in a game with 20-minute sessions does not need a week of hunting. Note it and move on.
- **The growth is a cache with a ceiling.** Texture and sound caches plateau. If the plateau is too high, that is a budget problem ([[Textures Decals and Texture Memory]]), not a leak.
- **You have not checked the crash rate.** Roblox docs suggest investigating when client crash rates rise above 2 to 3%. If crashes are flat and memory is within budget, your time is better spent elsewhere.

---

## Common mistakes

- Calling "memory did not drop after players left" a leak on the server.
- Measuring once instead of measuring a slope after warm-up.
- Reading client memory in Studio and treating it as the device number.
- Fixing the symptom: adding a periodic "clear everything" that hides the leak and breaks state.
- Using weak tables as the cleanup strategy instead of explicit teardown.
- Forgetting that yields create windows where the player leaves.
- Running the soak with deferred events not yet flushed, then chasing a phantom.
- Bisecting without a way to disable systems cleanly, so every run differs in more than one variable.

## Checklist

- [ ] Workload held constant; at least three samples after warm-up.
- [ ] Growth expressed as MB per hour or KB per repetition.
- [ ] Time-to-ceiling estimated for server and for a low-end phone.
- [ ] Growing category identified (`Stats:GetMemoryUsageMbForTag`).
- [ ] A reproduction loop that multiplies the leak.
- [ ] Systems bisected, or memory categories named with `debug.setmemorycategory`.
- [ ] Heap snapshots before and after N repetitions; holder found.
- [ ] Fix verified with the same loop; before and after numbers written down.
- [ ] Loop kept as a regression check.

## See also

[[Memory Budgets and Leaks]], [[Developer Console and Stats]], [[MicroProfiler Guide]], [[Events Signals and Connections]], [[Task Library Coroutines and Yielding]], [[Characters and Humanoids]], [[Session Locking and Profile Libraries]], [[CollectionService Patterns]], [[Mobile and Low-End Optimization]], [[Crash and Error Telemetry]], [[Case Study - Instance Cleanup and Place Size]]

## Connected notes
<!-- auto-links:start -->
[[Luau Garbage Collection and the Memory Model]] · Skill - Roblox Performance Audit · Links - Memory leaks and cleanup · Debugging Live Servers · Functions Closures and Upvalues · Building a Signal Library
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Load and Soak Testing Servers - Long Sessions and Many Clients]] · [[Performance Fundamentals]] · [[Debugging Live Servers]] · [[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]] · [[Performance and Memory]] · [[Debugger Breakpoints and Logging]] · [[Network Bandwidth Budgets and Measuring Them]]
<!-- related:end -->
