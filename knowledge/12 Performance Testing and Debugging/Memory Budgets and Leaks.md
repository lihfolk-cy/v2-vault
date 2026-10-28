---
tags: [performance, memory, leaks, luau-heap, pooling, instances]
---
# Memory Budgets and Leaks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Trusting `Destroy()` to clean up connections made on other objects.
> - Avoid: Per-player tables with no `PlayerRemoving` cleanup.
> - Avoid: Spawning infinite loops per object.
> - Client and server memory baselines recorded per release, by category.
> - Soak tests exist for respawn, zone change, menu open/close, equip/unequip.
> - Every system with connections has a cleanup owner and uses `Destroying`/`PlayerRemoving`.
>
> Read more (19 KB note): ## 6. The cleanup discipline · ## 7. Pooling · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Memory problems on Roblox look like nothing for a long time and then like everything at once: phones crash after twenty minutes, servers bloat over a six-hour session, the garbage collector starts eating frames. This note covers where memory goes (instances, assets, the Luau heap), what a budget looks like, the leak patterns that cause almost every real-world leak, how to find a leak with the Luau heap tool and a soak test, and the cleanup and pooling patterns that prevent them.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. Where memory goes

| Bucket | Lives in | Who pays | Biggest drivers |
|---|---|---|---|
| **Instances** | DataModel | everyone who has a copy | parts, models, UI trees, animation data stored as instances |
| **Assets** | engine caches | clients (rendering), servers (collision) | textures, meshes, sounds |
| **Luau heap** | each script VM | the side running the script | tables, closures, strings, buffers, threads |
| **Engine internals** | engine | mostly not you | avatars, networking, core UI |

The Developer Console Memory tool shows these as categories ([[Developer Console and Stats]]). The key distinction:

- **Instance and asset memory** is mostly a **budget** problem: you put too much in the world.
- **Luau heap and steadily growing instance counts** are mostly **leak** problems: you keep things alive by accident.

### Which container costs whom

| Container | Replicates to clients? | Cost |
|---|---|---|
| Workspace | yes (streamed if streaming is on) | clients, servers, Studio |
| ReplicatedStorage, ReplicatedFirst | yes, fully, before the player can interact (Docs) | every client on every join |
| ServerStorage, ServerScriptService | no | every server and every Studio session |
| StarterGui | copied into each player's PlayerGui | every client, per player per respawn if `ResetOnSpawn` |

**Measured.** In the reference project, ReplicatedStorage held about 600k instances at its worst, about 323k of them enemy animation clips with every joint keyed at 16 to 25 fps. Every join downloaded and deserialised all of it. Meanwhile ServerStorage held over a million instances of archives and backups, which no client ever saw but which pushed Studio to about 15 fps. Two different problems, two different victims. See [[Case Study - Cutting a Million Instances]].

---

## 2. Budgets

### Client (rule of thumb)
Roblox does not publish a per-device client budget. What Docs do give:
- The Performance dashboard shows memory usage **as a percentage of device memory** by platform; a line approaching 100% means most devices on that platform risk out-of-memory crashes.
- High usage alone is not a bug; investigate when crash rates exceed 2 to 3%, especially after an update.

Working targets that have held up for mid-sized games (rule of thumb):
| Target device | Total client memory goal |
|---|---|
| Low-end phone | stay well under 1 GB in heavy areas |
| Mid phone, tablet | 1 to 1.5 GB |
| PC, console | larger, but do not design for it |

### Server (Docs)
About **6.25 GiB + 100 MiB per player** at the server's peak player count, and keep usage below 50% of that. Docs also suggest staying under about 3 GB as a guideline on the Performance dashboard page. Server memory climbs as players join and does not fall back when they leave.

### Content budgets (Measured)
- A weapon kit folder: under 2,500 instances.
- Clip density for ultimates: 15 to 19 keys per second, not every frame.
- Archives and backups: zero in the place. Export to `.rbxm` on disk and rely on Version History ([[Version History and Backups]]).

---

## 3. Assets: textures, meshes, sounds

Docs facts worth memorising:
- **Texture memory depends on pixel count, not file size.** A 1024x1024 texture uses four times the memory of a 512x512. Changing format or dropping alpha does not reduce it.
- Keep most images at 512x512 or smaller, minor images under 256x256.
- **Uploading the same image twice makes two asset ids and loads it twice.** Upload once, reuse the id. Tint with `SurfaceAppearance.Color` instead of uploading coloured variants. Use sprite sheets with `ImageRectOffset`/`ImageRectSize` for UI.
- The 3D importer does not deduplicate meshes; importing a whole scene can give identical meshes different ids. Import pieces individually and duplicate in Studio.
- Audio can use a lot of memory if everything loads at once.

Asset memory shows in PlaceMemory as `GraphicsTexture`, `GraphicsMeshParts` and `Sounds`. See [[Textures Decals and Texture Memory]] and [[Art Budgets - Triangles Draw Calls Memory]].

---

## 4. The Luau heap and the garbage collector

Luau frees memory automatically once nothing references it. A **leak** in a garbage-collected language is therefore always a **reference you forgot**: a table entry, a closure captured by a connection, a thread still waiting.

The GC is incremental: it does its work in steps during frames. More allocation means more GC work, which shows as the `GC` label in the MicroProfiler. So even without a leak, **churn** (allocating and discarding many short-lived tables and strings per frame) costs frame time. See [[Script Performance]].

You can read the heap size from a script with `collectgarbage("count")` (kilobytes; in Roblox only the `"count"` option is available) or `gcinfo()`. You cannot force a full collection, so leak tests must wait and observe trends rather than "collect and compare" (rule of thumb).

---

## 5. The leak patterns

Almost every real leak is one of these.

### 5.1 Connections that outlive their object

```lua
--!strict
-- LEAK: the Heartbeat connection holds `enemy` (and its whole model) forever,
-- even after the enemy is destroyed.
local RunService = game:GetService("RunService")

local function startHealthbar(enemy: Model, bar: Frame)
	RunService.Heartbeat:Connect(function()
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if humanoid then
			bar.Size = UDim2.fromScale(humanoid.Health / humanoid.MaxHealth, 1)
		end
	end)
end
```

`Destroy()` disconnects the destroyed instance's **own** signals. It does not disconnect connections you made on **other** objects (RunService, Players, a shared module's signal) on its behalf. Docs list the three ways a connection is released: `Disconnect()`, destroying the instance that owns the signal, or destroying the script the connection traces to.

### 5.2 Tables keyed by Player or Instance with no removal path

```lua
--!strict
local Players = game:GetService("Players")
local cooldowns: { [Player]: number } = {}
-- LEAK unless this exists:
Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)
```

Docs: Player objects are not destroyed automatically when the player leaves; tables keyed by them keep the Player and everything it references alive. Enable `Workspace.PlayerCharacterDestroyBehavior` or clean up yourself on `PlayerRemoving` and `CharacterRemoving` (Docs suggest `task.defer` for the cleanup).

### 5.3 Destroyed but referenced
A destroyed instance is parented to nil and locked, but if a table or upvalue still points at it, it stays in memory with its whole subtree. The Luau heap tool's **Unique References** and **Unparented Instances** views exist precisely to find these (Docs).

### 5.4 Threads that never finish
A `task.spawn` loop with `while true do task.wait(1) ... end` lives forever and keeps every upvalue alive. Every per-object loop needs an exit condition (`while enemy.Parent do` or a cleanup flag).

### 5.5 Caches without limits
Memoising "computed path per target", "rendered icon per item", "track per animation id" without eviction grows with play time. Give caches a cap or key them by something that goes away.

### 5.6 Per-use creation
`Animator:LoadAnimation` in an input handler creates a new track per press ([[Engine Gotchas]]); `Instance.new("Sound")` per hit; cloning a VFX template per swing and relying on a destroy that an error skips. These grow `Animation`, `Instances`, `Sounds`.

### 5.7 UI rebuilt, not reused
Opening a menu clones a 300-element tree; closing it sets `Visible = false`; opening it again clones another one. Build once, show and hide; or destroy on close.

---

## 6. The cleanup discipline

Every object that makes connections or spawns threads owns a cleanup list, executed exactly once. Libraries such as Trove, Janitor and Maid implement this; the discipline matters more than the library.

```lua
--!strict
-- A minimal cleanup bag.
export type Cleaner = {
	add: <T>(self: Cleaner, item: T) -> T,
	clean: (self: Cleaner) -> (),
}

local Cleaner = {}
Cleaner.__index = Cleaner

function Cleaner.new(): Cleaner
	return setmetatable({ _items = {} :: { any } }, Cleaner) :: any
end

function Cleaner:add<T>(item: T): T
	table.insert(self._items, item)
	return item
end

function Cleaner:clean()
	local items = self._items
	-- Clean in reverse order of creation.
	for i = #items, 1, -1 do
		local item = items[i]
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "thread" then
			pcall(task.cancel, item) -- may already be dead
		elseif kind == "function" then
			item()
		elseif kind == "table" and type(item.Destroy) == "function" then
			item:Destroy()
		end
	end
	table.clear(items)
end

return Cleaner
```

Usage with an enemy healthbar, fixed:

```lua
--!strict
local RunService = game:GetService("RunService")
local Cleaner = require(script.Parent.Cleaner)

local function startHealthbar(enemy: Model, bar: Frame)
	local cleaner = Cleaner.new()
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	-- Event-driven: update only when health changes, not every frame.
	cleaner:add(humanoid.HealthChanged:Connect(function(health: number)
		bar.Size = UDim2.fromScale(health / humanoid.MaxHealth, 1)
	end))
	cleaner:add(bar)
	-- Tear everything down when the enemy goes away.
	cleaner:add(enemy.Destroying:Connect(function()
		cleaner:clean()
	end))
end
```

Rules that follow:
- **Write the cleanup in the same edit as the connection.** Cleanup added "later" is a leak shipped now.
- `Players.PlayerRemoving` clears every table keyed by that player, in every system.
- Character-scoped connections are cleaned on `CharacterRemoving` or by the cleaner of the character.
- `Destroying` is the hook for "this instance is going away"; use it.

### Weak tables, carefully
`setmetatable({}, { __mode = "k" })` makes keys weak, so entries vanish when nothing else references the key. Useful for "extra data about an instance". Caveat (rule of thumb): an instance that is still parented in the DataModel is referenced by the engine, so a weak-keyed entry for it will not disappear until it is destroyed and unreferenced. Weak tables are a safety net, not a replacement for explicit cleanup. The reference project used a module-level weak table to make UI motion wiring idempotent (attach once per button) without holding destroyed buttons alive.

---

## 7. Pooling

Creating and destroying instances costs CPU (and on the server, replication). For effects that happen often, reuse.

**Measured.** The reference project's enemy hit flash used a pool of **8 white Highlights** with a 0.1 s fade, and ran its fade loop only while at least one flash was live. A previous version created a fresh Highlight per flash and destroyed it after; worse, an earlier version left a *disabled* Highlight on the character, which blocked another outline effect on that model. Highlights have a global cap (see [[Rendering Performance]]), so a pool also enforces a budget.

```lua
--!strict
-- Client: pooled hit flash. At most POOL_SIZE flashes at once; the loop runs only while one is live.
local RunService = game:GetService("RunService")

local POOL_SIZE = 8
local FADE = 0.1

type Flash = { highlight: Highlight, t: number, live: boolean }
local pool: { Flash } = {}
local liveCount = 0
local conn: RBXScriptConnection? = nil

for i = 1, POOL_SIZE do
	local h = Instance.new("Highlight")
	h.Name = "HitFlash"
	h.FillColor = Color3.new(1, 1, 1)
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Enabled = false
	h.Parent = workspace -- parent once; we only change Adornee
	pool[i] = { highlight = h, t = 0, live = false }
end

local function step(dt: number)
	for _, f in pool do
		if f.live then
			f.t += dt
			local a = math.clamp(f.t / FADE, 0, 1)
			f.highlight.FillTransparency = a
			if a >= 1 then
				f.live = false
				f.highlight.Enabled = false
				f.highlight.Adornee = nil
				liveCount -= 1
			end
		end
	end
	if liveCount == 0 and conn then
		conn:Disconnect()
		conn = nil -- no per-frame work while idle
	end
end

local function flash(target: Model)
	local chosen: Flash? = nil
	for _, f in pool do
		if not f.live then
			chosen = f
			break
		end
	end
	if not chosen then
		return -- pool exhausted: drop the effect rather than create more
	end
	chosen.live = true
	chosen.t = 0
	chosen.highlight.Adornee = target
	chosen.highlight.FillTransparency = 0
	chosen.highlight.Enabled = true
	liveCount += 1
	if not conn then
		conn = RunService.PreRender:Connect(step)
	end
end

return flash
```

One cost to know: Docs say a **disabled Highlight still occupies one of the global Highlight slots**, so a parked pool of 8 permanently uses 8 slots. Keep Highlight pools small, or create the pool lazily.

Design choices worth copying: **drop when exhausted** (a missing flash is invisible in a crowd; an unbounded pool is a budget breach), **park instead of destroy**, and **the loop exists only while there is work**.

Other things worth pooling: damage numbers (the reference project capped them at 12 with same-kind merging within 0.55 s), projectiles, loot icons, particle emitters for repeated bursts (call `:Emit(n)` on a parked emitter rather than cloning). Things not worth pooling: rare, large, one-off effects.

---

## 8. Finding a leak

### Step 1: confirm it is a leak
Soak test. Play a repeating loop of the suspect activity (enter and leave a zone, open and close a menu, equip and unequip, respawn) for 10 to 20 minutes. Watch `LuaHeap`, `Instances`, `Signals` in the console. A sawtooth that returns to a baseline is GC working; a staircase or a line is a leak.

An automated version, run in a play test:

```lua
--!strict
-- Soak harness: repeat an action, sample memory, report the trend.
local Stats = game:GetService("Stats")

local function soak(label: string, cycles: number, action: () -> ())
	local samples: { { heapKb: number, instances: number } } = {}
	for cycle = 1, cycles do
		action()
		task.wait(0.5) -- let deferred cleanup and GC steps run
		if cycle % 10 == 0 then
			table.insert(samples, {
				heapKb = collectgarbage("count"),
				instances = Stats.InstanceCount,
			})
		end
	end
	local first, last = samples[1], samples[#samples]
	print(string.format("[soak %s] heap %+.0f KB, instances %+d over %d cycles",
		label, last.heapKb - first.heapKb, last.instances - first.instances, cycles))
end

-- Example: open and close a menu 200 times through its public API.
-- soak("ShopMenu", 200, function() ShopMenu.open(); task.wait(0.1); ShopMenu.close() end)
```

Heap noise of a few hundred KB is normal; instance growth proportional to cycles is not.

### Step 2: find what holds it
Use the Luau heap tool (Docs):
1. Developer Console, LuauHeap, Client or Server, **Create Snapshot**.
2. Repeat the suspect action many times.
3. Create another snapshot; compare.
4. Views:
   - **Graph**: aggregated reference tree from the `registry` root; shows the shortest path holding each object. Entries such as `Module @Path.To.Module`, `upvalue`, `[key]` tell you *who* holds it. Nodes under 2 KB are grouped into `...`.
   - **Object Tags**: by Luau type (table, function, thread). A growing `function` count means closures are piling up, usually connections.
   - **Memory Categories**: by category, which defaults to the script name. Use `debug.setmemorycategory("ShopUI")` at the top of a thread to split a big script's memory into named buckets; `debug.resetmemorycategory()` restores the default.
   - **Object Classes**: engine classes your scripts hold (CFrame, Animation, EnumItem).
   - **Unique References / Unparented Instances**: instances with no parent that Luau still reaches. These are your destroyed-but-referenced leaks.

### Step 3: fix and re-run the soak
The soak test is the regression test. Keep it.

---

## 9. Instance hygiene in the place

Memory work is not only runtime. The place file itself accumulates weight.

**Measured** (reference project timeline, anonymised):
- 2.36M instances at peak; first pass archived imported source models (735k) and Animation Editor saves (642k), exported to disk, then removed: about 955k.
- A second pass removed about 312k of dead weight (duplicate animation copies inside enemy models, clips of removed enemies, unused models, dated backups): about 599k.
- A later cleanup deleted 191,089 more instances from a written inventory of what references what, with a "risky" list held back for a human decision.
- Backup folders kept creeping back as people made "just in case" copies; a rule was adopted: **no backup folders in the place**, back up to disk.

Techniques that kept it safe:
- **Dry run first.** The cleanup script printed what it would delete by default and only deleted with an explicit flag.
- **Prove unreferenced.** Search scripts for names and paths before deleting.
- **Disable, do not delete, when unsure.** Lights thinned for performance were disabled and tagged (`ThinnedForPerf`) so they could be restored.
- **Record reversal data on the instance.** When `LevelOfDetail` was changed on 7,861 models, each root got an attribute with the previous value so a script could revert it.

See [[Case Study - Instance Cleanup and Place Size]] and [[Safe Changes in a Shared Place]].

---

## Common mistakes

- Trusting `Destroy()` to clean up connections made on other objects.
- Per-player tables with no `PlayerRemoving` cleanup.
- Spawning infinite loops per object.
- Unlimited caches and pools.
- Uploading the same texture several times, or tinted copies of it.
- Treating ServerStorage as free storage for archives.
- Measuring memory once instead of watching the trend.
- Using `Visible = false` as "close" for a menu that is cloned again on open.

## Checklist

- [ ] Client and server memory baselines recorded per release, by category.
- [ ] Soak tests exist for respawn, zone change, menu open/close, equip/unequip.
- [ ] Every system with connections has a cleanup owner and uses `Destroying`/`PlayerRemoving`.
- [ ] Frequent effects are pooled with a hard cap and drop-when-exhausted.
- [ ] Caches have caps or die with their key.
- [ ] Big scripts set memory categories so the heap tool is readable.
- [ ] No archives or backups inside the place; exports on disk plus Version History.
- [ ] Textures sized to their on-screen use and uploaded once.

## See also

[[Developer Console and Stats]] · [[Script Performance]] · [[Events Signals and Connections]] · [[Instance Streaming]] · [[Performance and Memory]] · [[Case Study - Cutting a Million Instances]] · [[Case Study - Instance Cleanup and Place Size]] · [[Highlights and Selection Effects]] · [[Mobile and Low-End Optimization]]

## Connected notes
<!-- auto-links:start -->
[[Hunting Memory Leaks Step by Step]] · [[Luau Garbage Collection and the Memory Model]] · [[Links - Memory leaks and cleanup]] · [[Performance Fundamentals]] · [[Functions Closures and Upvalues]] · [[Instance Count]]
<!-- auto-links:end -->
