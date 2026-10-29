---
tags: [luau, performance, native-codegen, optimization, profiling, type/guide, area/scripting, level/intermediate, area/performance]
---
# Luau Performance and Native Codegen

<!-- tldr:start -->
> [!tldr] TL;DR
> - Steady frame cost grows with object count: Connection per object -> One shared loop
> - Periodic hitches: GC from per-frame allocations -> Reuse tables; fewer closures/threads
> - Whole codebase slower than expected: `getfenv`/`setfenv`/`loadstring` disable imports/inlining -> Remove them
> - Hot spots identified in the MicroProfiler/Script Profiler before optimizing.
> - Per-frame code: no new tables, closures, threads or strings per object.
> - Systems run at the lowest frequency that feels right, staggered.
>
> Cost: TL;DR ~170 tok · whole note ~4.1k tok. Read more: ## 3. Patterns that matter · ## 4. Native code generation · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most Roblox lag is not Luau's fault: it is rendering, physics, replication, or doing the wrong amount of work. When it is Luau, the cause is usually **algorithmic** (doing per-frame what should be per-event, scanning all instances, O(n^2) loops) or **allocation churn** (tables, closures, threads and strings created every frame). Micro-optimizations come last. This note explains how the Luau VM makes code fast, what defeats those optimizations, the patterns that keep per-frame work cheap, native code generation (`--!native` / `@native`), and how to measure. System-level profiling lives in [[Script Performance]] and [[MicroProfiler Guide]].

---

## 1. Measure first

| Tool | Answers |
|---|---|
| MicroProfiler (Ctrl+F6 / Developer Console) | Which frame phase is slow; where scripts sit in the frame |
| Script Profiler (Studio, Developer Console) | Which functions take CPU time; marks natively executing functions `<native>` (Docs) |
| Luau heap view (Developer Console memory) | Which scripts hold memory; native code shows as `[native]` (Docs) |
| `debug.profilebegin(label)` / `debug.profileend()` | Your own labels in the MicroProfiler |
| `os.clock()` microbenchmarks | Comparing two implementations in isolation |

```lua
RunService.Heartbeat:Connect(function(dt)
	debug.profilebegin("EnemyAI")
	updateEnemies(dt)
	debug.profileend()
end)
```

A microbenchmark harness for comparing implementations (run in Studio, server side, with nothing else going on):

```lua
local function bench(name: string, iterations: number, fn: () -> ())
	fn() -- warm up
	local start = os.clock()
	for _ = 1, iterations do fn() end
	local elapsed = os.clock() - start
	print(string.format("%-24s %8.3f us/op", name, elapsed / iterations * 1e6))
end
```

Benchmarks lie when the work is optimized away or when the real cost is GC pauses that happen elsewhere. Confirm in the MicroProfiler with real content.

---

## 2. How the VM makes code fast (Docs: luau.org performance)

- **Imports.** Global chains like `math.floor` or `Vector3.new` are resolved when the script loads, so `local floor = math.floor` is usually unnecessary. This optimization is disabled if the script uses `getfenv`, `setfenv` or `loadstring` ("`getfenv` deoptimizes the environment even if it's only used to read values").
- **Fastcalls.** Most `math`, `bit32`, and many `string`/`table` builtins have fast paths when called directly (`math.max(a, b)`), not when called through method syntax (`s:byte()` is slower than `string.byte(s)`).
- **Inline caching** for table field access by constant name (`t.field`). Keep fields directly in the object; prefer `__index` set to a table; avoid deep inheritance chains and `__index` functions.
- **Fast method calls** with `obj:Method()` syntax. Caching methods in locals is not recommended.
- **Closure caching**: closures with no upvalues, or only immutable module-level upvalues, may be reused rather than reallocated.
- **Immutable upvalues** are captured by value. Reassigning a captured variable makes it slower.
- **Native vector type**: `Vector3` math does not allocate GC objects.
- **`#t`** is effectively constant time on proper arrays.
- **Incremental GC** with pacing; avoid temporary allocations in tight loops anyway.
- **Optimization level 2** (where used) adds constant folding of builtins, inlining of local functions and loop unrolling; `getfenv`/`setfenv` disable inlining.

What this means in practice:
1. Never use `getfenv`/`setfenv`/`loadstring` in game code.
2. Write normal, idiomatic code: direct field access, `obj:Method()`, builtins called directly.
3. Spend effort on reducing work and allocations, not on caching globals.

---

## 3. Patterns that matter

### One loop, many objects

A RunService connection per object costs a signal dispatch, a thread resume and a closure each frame. One loop over an array is much cheaper and easier to profile.

```lua
--!strict
type Projectile = { part: BasePart, velocity: Vector3, life: number }
local projectiles: { Projectile } = {}

RunService.Heartbeat:Connect(function(dt: number)
	local i = 1
	while i <= #projectiles do
		local p = projectiles[i]
		p.life -= dt
		if p.life <= 0 then
			p.part:Destroy()
			projectiles[i] = projectiles[#projectiles]   -- swap-remove
			projectiles[#projectiles] = nil
		else
			p.part.CFrame += p.velocity * dt
			i += 1
		end
	end
end)
```

For many moving parts, `workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)` moves them in one engine call instead of one property write each ([[Physics Performance]], [[Rendering Performance]]).

### Do not allocate per frame

Per frame and per object, avoid: new tables (`{}` literals, `GetChildren()`, `GetDescendants()`, `table.clone`), closures, `task.spawn` threads, string building, and `Instance.new`. Reuse:

```lua
local scratch: { BasePart } = {}
local overlap = OverlapParams.new()        -- create params once, not per query

local function nearbyParts(center: Vector3, radius: number): { BasePart }
	table.clear(scratch)                    -- keeps capacity
	for _, part in workspace:GetPartBoundsInRadius(center, radius, overlap) do
		table.insert(scratch, part)
	end
	return scratch                          -- caller must not keep this table
end
```

`GetPartBoundsInRadius` itself returns a fresh table; the point is that your own code does not multiply allocations.

### Work at the right frequency

| Work | Frequency |
|---|---|
| Visual interpolation, camera | Every frame (client) |
| AI decisions | 5 to 10 times per second, staggered across NPCs |
| Target acquisition, line of sight | 2 to 10 times per second |
| UI text refresh | On change, not per frame |
| Leaderboard refresh | Every 30 to 60 seconds |
| Autosave | Minutes |

Staggering: give each NPC a phase offset so 300 NPCs think 30 per frame, not 300 every tenth frame:

```lua
local THINK_INTERVAL = 0.2
for i, npc in npcs do
	npc.nextThink = os.clock() + (i % 10) / 10 * THINK_INTERVAL
end
```

### Event-driven over polling

Replace "every frame, check whether X changed" with a changed signal or an explicit notification. Use spatial data structures (grids, buckets) instead of scanning every enemy for every player. This kind of change usually beats any micro-optimization by 10x or more (Rule of thumb).

### Engine calls are expensive relative to Luau

Property reads and writes on Instances cross into the engine and are slower than table access. Cache values you read repeatedly in a frame (`local pos = root.Position`), and avoid writing a property to the same value every frame (some writes trigger replication or physics work). Use `FindFirstChild` once and keep the reference rather than looking up by name per frame.

### Strings and tables

- Build strings with `table.concat`, not `..` in loops ([[Strings Patterns and Formatting]]).
- `table.create(n)` when you know the size ([[Tables Metatables and OOP]]).
- `table.insert(t, v)` vs `t[#t + 1] = v`: similar; with a known index in a sequential fill, `t[i] = v` is fastest (Docs).
- Structure of arrays (`xs[i]`, `ys[i]`) or buffers beats arrays of small tables for tens of thousands of numeric elements ([[Buffers and Binary Data]]).

---

## 4. Native code generation

With native codegen, Luau functions are compiled to machine code instead of bytecode interpreted by the VM (Docs). Behaviour is identical; only speed changes. Per the Creator Hub (as of October 2026), the feature is documented for **server-side scripts**; a footnote says some scripts may later be compiled natively automatically, but for now the directive is required.

```lua
--!native
-- whole script: every function (and the top level, if profitable) is compiled natively
```

```lua
@native
local function integrate(positions: { Vector3 }, velocities: { Vector3 }, dt: number)
	for i = 1, #positions do
		positions[i] += velocities[i] * dt
	end
end
```

`@native` applies only to that function, not to functions defined inside it (Docs: luau.org attributes).

### Good candidates (Docs)

- Heavy computation directly in Luau: maths on tables and especially `buffer`s, procedural generation, physics-like integration, compression, pathfinding maths, hitbox maths.
- Functions called many times (per frame, per entity), not run-once top-level code.

Poor candidates: code dominated by Roblox API calls or heavy library calls; native code does not make engine calls faster.

### Make it effective

- **Annotate types**, especially `Vector3` parameters. Without annotations, the compiler assumes tables for field access and adds checks: `local function f(v: Vector3)` generates vector-specialized code (Docs).
- **Pass correctly typed arguments.** Calling a typed native function with the wrong types forces checks or fallback.
- Avoid `getfenv`/`setfenv` and builtins called with non-numeric arguments (`math.asin("x")`), which de-optimize (Docs).
- Breakpoints in a function disable native execution for it (Docs).

### Costs and limits (Docs)

- Compile time increases server startup; native code uses extra memory; there is a **total limit** on natively compiled code per game. When reached, compilation stops and the rest runs interpreted. Do not put `--!native` on every script "just in case".
- Hard limits: a single code block over **64K instructions**, a function with more than **32K internal blocks**, or a script over **1 million instructions** fails native compilation ("exceeded single code block instruction limit" and similar messages in Output). Split large functions or move them to a non-native script.
- "Memory allocation limit reached for native code generation" means the budget is used up.
- `debug.dumpcodesize()` (run from the Command Bar in **Server** view) prints compiled scripts and functions, native memory used and the limit, with a per-script breakdown (Docs).
- Debugger views of locals/upvalues may be incomplete in native frames.

### Workflow

1. Profile; find a hot Luau function (not an engine call).
2. Add types to its parameters; benchmark.
3. Add `@native` to that function; benchmark again in the Script Profiler (look for `<native>`).
4. Keep it only if it measurably helps; check `debug.dumpcodesize()` budget.

Typical outcome (Rule of thumb): numeric loops gain substantially (often 1.5x to several times); API-heavy code gains little or nothing.

---

## 5. Memory and GC

Allocation is cheap individually; churn is what costs, through GC work spread over frames. Signs: the Luau heap sawtooths quickly, frame time spikes periodically. Reduce temporary allocations in hot paths, reuse tables, and avoid creating closures/threads per event in high-frequency systems.

`debug.setmemorycategory(name)` tags allocations from the current thread so the Developer Console memory view attributes them to your system; `debug.resetmemorycategory()` resets it. Useful for tracking which module leaks ([[Memory Budgets and Leaks]]).

Leaks (memory that never comes back) are almost always references you keep: connections, caches keyed by players or instances, module-level tables. See [[Events Signals and Connections]].

---

## 6. Parallelism

If a measured hot spot is compute- or query-bound and independent per entity, [[Parallel Luau and Actors]] can spread it across cores. It does not help instance-writing work and adds complexity. Try algorithmic fixes and native codegen first.

---

## 7. A worked optimization: target search

A common hot spot: every enemy finds the nearest player every frame.

```lua
-- Version 1: O(enemies x players) per frame, plus a property read per pair
RunService.Heartbeat:Connect(function()
	for _, enemy in enemies do
		local best, bestDist = nil, math.huge
		for _, player in Players:GetPlayers() do          -- allocates an array per enemy per frame
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local d = (root.Position - enemy.root.Position).Magnitude
				if d < bestDist then best, bestDist = player, d end
			end
		end
		enemy.target = best
	end
end)
```

Improvements, in order of impact:
1. **Frequency**: retarget 4 times per second, staggered, not every frame (about 15x less work at 60 FPS).
2. **Hoist per-frame reads**: build the list of player positions once per tick, not per enemy (removes `GetPlayers()` allocations and `FindFirstChild` calls from the inner loop).
3. **Squared distance**: skip `sqrt`.
4. **Spatial buckets** if there are hundreds of enemies and many players: only compare against players in nearby grid cells.
5. **Native** last: the remaining inner loop is pure arithmetic on `Vector3`s, a good `@native` candidate with typed parameters.

```lua
--!strict
local RETARGET_INTERVAL = 0.25
local playerPositions: { Vector3 } = {}
local playerList: { Player } = {}

@native
local function nearest(origin: Vector3, positions: { Vector3 }): (number, number)
	local bestIndex, bestSq = 0, math.huge
	for i = 1, #positions do
		local d = positions[i] - origin
		local sq = d:Dot(d)
		if sq < bestSq then bestIndex, bestSq = i, sq end
	end
	return bestIndex, bestSq
end

local cursor = 1
RunService.Heartbeat:Connect(function(dt: number)
	-- refresh player snapshot once per tick
	table.clear(playerPositions); table.clear(playerList)
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(playerPositions, root.Position)
			table.insert(playerList, player)
		end
	end
	-- process a slice of enemies so each is retargeted every RETARGET_INTERVAL
	local perFrame = math.ceil(#enemies * dt / RETARGET_INTERVAL)
	for _ = 1, math.min(perFrame, #enemies) do
		if cursor > #enemies then cursor = 1 end
		local enemy = enemies[cursor]
		local i = nearest(enemy.root.Position, playerPositions)
		enemy.target = if i > 0 then playerList[i] else nil
		cursor += 1
	end
end)
```

(The snapshot still calls `GetPlayers()` once per frame, which is fine; it could also be cached and updated on `PlayerAdded`/`PlayerRemoving`.) The structural changes do the heavy lifting; native compilation of `nearest` is the final polish.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Steady frame cost grows with object count | Connection per object | One shared loop |
| Periodic hitches | GC from per-frame allocations | Reuse tables; fewer closures/threads |
| Whole codebase slower than expected | `getfenv`/`setfenv`/`loadstring` disable imports/inlining | Remove them |
| `--!native` everywhere, slower startup, budget exhausted | Blanket native | Targeted `@native` |
| Native function not marked `<native>` | Breakpoint, untyped args, de-opt calls | Remove breakpoints; annotate; fix calls |
| AI spikes every N frames | All NPCs think on the same frame | Stagger |
| Micro-optimized code still slow | Wrong algorithm | Event-driven, spatial partitioning |

## Checklist

- [ ] Hot spots identified in the MicroProfiler/Script Profiler before optimizing.
- [ ] Per-frame code: no new tables, closures, threads or strings per object.
- [ ] Systems run at the lowest frequency that feels right, staggered.
- [ ] No `getfenv`/`setfenv`/`loadstring` in game code.
- [ ] `@native` only on measured numeric hot functions with typed parameters; budget checked.
- [ ] Memory categories set for major systems.

## See also

[[Script Performance]] · [[MicroProfiler Guide]] · [[Performance Fundamentals]] · [[Memory Budgets and Leaks]] · [[Parallel Luau and Actors]] · [[Buffers and Binary Data]] · [[Functions Closures and Upvalues]] · [[Performance and Memory]]

## Connected notes
<!-- auto-links:start -->
[[Luau Performance Patterns with Benchmarks]] · [[Luau Garbage Collection and the Memory Model]] · [[Luau Language Essentials]] · [[Metatables and OOP - When and When Not]] · Advanced Luau Start Here · Building a Signal Library
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Luau Type System and Strict Mode]] · [[Module Scripts and Requiring]] · [[Script Types and Run Context]] · [[Task Library Coroutines and Yielding]] · [[Math Vectors and CFrames]] · [[Instances Attributes and Tags]] · [[Error Handling - pcall xpcall and Promise Patterns]] · [[CollectionService Patterns]]
<!-- related:end -->
