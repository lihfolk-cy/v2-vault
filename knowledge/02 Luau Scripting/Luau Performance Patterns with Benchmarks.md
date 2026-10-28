---
tags: [luau, performance, benchmarking, optimization, profiling, gc]
---
# Luau Performance Patterns with Benchmarks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Benchmark shows 0 ns/op: Work optimised away -> Store results in a sink; use the index as input
> - Results flip between runs: Noise; single run -> Median of several rounds; alternate order
> - "Optimised" code slower in game than in bench: Bench ignored GC; ran on desktop -> Check heap delta; profile on device
> - Hot spot found in the MicroProfiler before touching code.
> - Benchmarks use warm-up, several rounds, a median, a sink and a heap delta.
> - Per-frame cost computed as cost x count x rate, on the target device.
>
> Cost: TL;DR ~170 tok · whole note ~5.5k tok. Read more: ## 3. Micro patterns: what to expect · ## 4. Structural patterns that actually move the needle · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Luau Performance and Native Codegen]] explains how the Luau VM makes code fast and when to reach for `@native`. This note is the practical companion: how to write a benchmark that does not lie, how to turn microseconds into a frame budget, and a catalogue of the patterns people argue about (iteration styles, appends, string building, method caching, property reads, `pcall` in loops, closures) with the result you should expect and why. It ends with the structural patterns (time slicing, spatial hashing, ring buffers) that matter far more than any of the micro ones.

A note on the numbers. Statements about what the VM does come from the official Luau performance page (luau.org, as of October 2026). Numbers labelled "measured in the reference project" come from one production game. Relative results in the pattern tables are **expected directions**, not figures run for this note: run the harness below on your own hardware and Studio version before quoting a ratio to your team. Hardware, Studio version, server versus client and native codegen all move the ratios.

---

## 1. A benchmark harness that does not lie

The naive benchmark (`local t = os.clock(); for i = 1, 1e6 do f() end; print(os.clock() - t)`) has five problems:

1. **One run.** A GC step, a background thread, or the Studio UI repainting lands inside it and doubles the time.
2. **No warm-up.** The first calls pay for table growth, string interning and cache misses.
3. **Dead code.** If `f` computes something nobody reads, you may be measuring an empty loop (Luau at optimization level 2 can fold constants and inline small local functions, per luau.org).
4. **Hidden GC.** Allocation-heavy code looks cheap during the loop and pays later, in somebody else's frame.
5. **Wrong context.** A breakpoint anywhere in the function disables native execution for it (Roblox docs), the Script Profiler adds overhead, and the client and server run on different machines.

A harness that addresses all five:

```lua
--!strict
-- Run in a server Script in an empty place (Run mode, not Play, so no character or UI noise).
local Bench = {}

local sink: any = nil -- results are written here so work cannot be optimised away

local function median(xs: { number }): number
	table.sort(xs)
	local n = #xs
	if n % 2 == 1 then
		return xs[(n + 1) // 2]
	end
	return (xs[n // 2] + xs[n // 2 + 1]) / 2
end

-- fn receives the iteration index and returns a value that is kept in `sink`.
function Bench.run(name: string, fn: (number) -> any, rounds: number?)
	rounds = rounds or 7

	-- Calibrate: grow the iteration count until one round takes about 20 ms.
	local iterations = 1000
	while true do
		local t0 = os.clock()
		for i = 1, iterations do
			sink = fn(i)
		end
		if os.clock() - t0 >= 0.02 or iterations >= 1e8 then
			break
		end
		iterations *= 2
	end

	local times: { number } = {}
	local kbBefore = gcinfo()
	for _ = 1, rounds :: number do
		local t0 = os.clock()
		for i = 1, iterations do
			sink = fn(i)
		end
		table.insert(times, (os.clock() - t0) / iterations * 1e9) -- ns per op
		task.wait() -- let GC and the scheduler breathe between rounds
	end
	local kbAfter = gcinfo()

	print(string.format("%-28s median %8.1f ns/op  (min %.1f, max %.1f)  heap %+d KB",
		name, median(times), times[1], times[#times], kbAfter - kbBefore))
end

return Bench
```

Notes on reading the output:

- **Median, not mean.** One spike should not decide the result. If min and max differ by more than about 30%, the environment is noisy; close other Studio windows and rerun.
- **`gcinfo()`** returns the Luau heap size in KB. A large positive delta means the function allocates; the true cost of that shows up later as GC work. Two implementations with the same ns/op but different heap deltas are not equal.
- **Compare like with like.** Benchmark both versions in the same run, alternate their order, and repeat the whole script twice. If the winner changes between runs, the difference is noise.
- **Native on and off.** Put the candidate functions in two ModuleScripts, one with `--!native`, and run both. The Script Profiler marks native functions `<native>` (Roblox docs).

The final judge is never the harness. It is the MicroProfiler with real content, because a 3x win on a function that takes 0.02 ms of a 16.7 ms frame is worth nothing ([[MicroProfiler Guide]], [[Script Performance]]).

---

## 2. From nanoseconds to a frame budget

At 60 FPS a frame is 16.67 ms. Rendering, physics, animation and replication need most of it. A useful planning budget for **all of your game scripts combined** is a few milliseconds per frame on the device you care about most, which is usually a mid-range phone (rule of thumb). The arithmetic that decides whether something matters:

`cost per frame = cost per item x items x times per second / frames per second`

| Item | Cost per item | Count | Rate | Per-frame cost at 60 FPS |
|---|---|---|---|---|
| Lua-driven rig pose (25 bones) | about 22 us (measured in the reference project) | 30 rigs | every frame | 0.66 ms |
| Same rigs with distance LOD (half at 30 Hz, a third at 10 Hz) | 22 us | 30 | mixed | about 0.36 ms |
| Target search, naive | 1 us per enemy-player pair | 200 enemies x 20 players | every frame | 4 ms |
| Target search, staggered at 4 Hz | 1 us | 4,000 pairs | 4 per second | about 0.27 ms |
| UI text refresh | 30 us | 40 labels | every frame | 1.2 ms (should be on change: about 0) |

Two lessons hide in that table. First, frequency and count dominate: the target search did not get faster per pair, it ran less. Second, a "slow" function that runs once per event is almost never your problem; a "fast" one that runs per item per frame often is.

When you profile on PC, scale the result before deciding. Low-end phones can be several times slower per Luau operation than a desktop CPU (rule of thumb; measure on a real device through the Developer Console, see [[Mobile and Low-End Optimization]]).

---

## 3. Micro patterns: what to expect

Each row says what the VM does (from luau.org unless marked), the result you should expect, and whether it is worth changing existing code for.

### Iteration

| Style | Expected | Why |
|---|---|---|
| `for k, v in t do` (generalized iteration) | Fastest or tied | Compiler special-cases it; no call to `pairs` at loop start |
| `for k, v in pairs(t)` / `ipairs(t)` | Tied with generalized | Also special-cased |
| `for i = 1, #t do local v = t[i]` | Slightly slower | Reading elements by index costs more (luau.org) |
| `for k, v in next, t` | Tied | Special-cased |

Verdict: write whichever is clearest. Use `ipairs` only when you want "stop at the first nil" semantics. Never rewrite working loops for speed.

### Appending and building arrays

| Style | Expected |
|---|---|
| `table.insert(t, v)` | Fastest general append when size is unknown (luau.org) |
| `t[#t + 1] = v` | Close to `table.insert`; not compared directly on luau.org |
| `local t = table.create(n); for i = 1, n do t[i] = v end` | Fastest when `n` is known: preallocated, sequential known index |
| Growing a table from `{}` with 100k inserts | Several reallocations; fine once, bad per frame |

Verdict: when you know the size (copying an array, building a result of fixed length), use `table.create(n)` and indexed writes. Otherwise use `table.insert`.

### Object construction

Luau has a "table templates" optimisation when an object-like table is built with **one literal that sets all fields** (luau.org).

```lua
-- Good: one literal with every field, shape known at compile time
local p = { position = pos, velocity = vel, life = 2, owner = player }

-- Slower: empty table, fields added one by one, shape grows each time
local q = {}
q.position = pos
q.velocity = vel
q.life = 2
q.owner = player
```

Verdict: worth adopting as a style in constructors. Also keep every object of a "type" with the same field set (do not add `p.extra` to some objects only), because uniform shapes help inline caching.

### Method calls and caching

| Style | Expected |
|---|---|
| `obj:Method(x)` | Fast path for method calls (luau.org) |
| `local m = obj.Method; m(obj, x)` | Not faster; luau.org explicitly does not recommend caching methods in locals |
| `local floor = math.floor` | Unnecessary; library chains are resolved at load time ("imports") |
| `string.byte(s, i)` vs `s:byte(i)` | `string.byte` wins: builtins are only fast-called when called directly, not as methods |

Verdict: remove `local floor = math.floor` boilerplate if it hurts readability; it does nothing. In genuinely hot string-parsing loops, prefer `string.byte(s, i)` over `s:byte(i)`.

### Strings

| Style | Expected |
|---|---|
| `s = s .. piece` in a loop of N pieces | Quadratic: each step copies the whole string |
| `table.insert(parts, piece)` then `table.concat(parts)` | Linear; the standard fix |
| `buffer` writes then `buffer.tostring` | Linear, no intermediate strings; best for binary or very large outputs ([[Buffers and Binary Data]]) |
| `string.format` / interpolation for one short string | Fine; not a hot-path concern unless per item per frame |

Verdict: the concatenation-in-a-loop fix is the only string change that routinely matters. Building log strings per frame is the other one; guard them behind a debug flag.

### Closures

Immutable upvalues are captured by value; a variable that is reassigned after capture needs an extra heap object. Closures with no upvalues, or only immutable module-level upvalues, may be cached and reused instead of allocated (luau.org).

```lua
-- Allocates a new closure per enemy per frame (captures the loop variable `enemy`)
for _, enemy in enemies do
	task.defer(function() enemy:think() end)
end

-- No closure: pass arguments instead
for _, enemy in enemies do
	task.defer(enemy.think, enemy)
end
```

Verdict: in per-frame loops, pass a function plus arguments to `task.spawn`, `task.defer`, `pcall` and `table.sort` instead of building a wrapper closure. Elsewhere, closures are cheap enough not to think about.

Watch for one side effect of closure caching: function identity. Two evaluations of the same closure expression may return the same function value, which matters if you use functions as table keys (luau.org).

### Instance access

Instance property reads and writes cross from Luau into the engine. They are much slower than a table field read (rule of thumb: an order of magnitude or more; measure with the harness). Patterns:

| Instead of | Do | Typical win |
|---|---|---|
| `part.Position` read three times in one function | Read once into a local | Removes two engine calls |
| `model:FindFirstChild("Root")` every frame | Cache the reference, refresh on `ChildAdded`/`Destroying` | Removes a name search per frame |
| `instance:GetAttribute("Speed")` per frame | Mirror to a Lua table, update on `GetAttributeChangedSignal` | Removes an engine call per read |
| `part.CFrame = cf` every frame when unchanged | Compare first, write only on change | Avoids replication and physics work, not only the call |
| Setting `.CFrame` on 300 parts | `workspace:BulkMoveTo(parts, cframes, mode)` | One engine call ([[Physics Performance]]) |
| `x:IsA("BasePart")` in an inner loop over known parts | Filter once when building the list | `IsA` walks the class hierarchy |

### `pcall` in hot loops

`pcall` itself is a fast builtin, but wrapping with a closure (`pcall(function() ... end)`) allocates per call. Use `pcall(fn, arg1, arg2)` with no wrapper. Better, keep `pcall` at the boundary (one per system tick) and validate inputs so the inner loop does not need it. See [[Error Handling - pcall xpcall and Promise Patterns]].

### Maths

- `Vector3` is a native value type in Luau: arithmetic on it does not allocate GC objects (luau.org). Prefer `Vector3` maths over three separate number tables.
- `CFrame` operations produce new userdata values; they are heavier than `Vector3` maths (rule of thumb). In a per-entity inner loop, work in `Vector3` (positions and directions) and build a `CFrame` once at the end.
- Use squared distance: `local d = a - b; if d:Dot(d) < r * r then`. It skips a square root, but the bigger win is usually that it avoids creating a magnitude you then compare against a radius you also square.
- `math.floor(x)` and `x // 1` are both fast; pick one for readability.

---

## 4. Structural patterns that actually move the needle

### 4.1 Time slicing with a millisecond budget

Spreading work over frames by count ("10 per frame") breaks when item cost varies. Slice by elapsed time instead:

```lua
--!strict
local RunService = game:GetService("RunService")

local BUDGET = 0.001 -- 1 ms of this system's work per frame
local queue: { [number]: () -> () } = {}
local head = 1 -- index of the next job to run
local tail = 0 -- index of the last job queued

RunService.Heartbeat:Connect(function()
	local deadline = os.clock() + BUDGET
	while head <= tail and os.clock() < deadline do
		local job = queue[head]
		queue[head] = nil -- release the reference
		head += 1
		job()
	end
	if head > tail then
		-- drained: reset the indices instead of shifting anything
		head, tail = 1, 0
	end
end)

return function(job: () -> ())
	tail += 1
	queue[tail] = job
end
```

Why `head` and `tail` instead of `table.remove(queue, 1)`: removing from the front shifts the whole array, O(n) per removal. With 5,000 queued jobs that is about 12.5 million element moves to drain the queue. Why explicit indices instead of `#queue`: once the front slots are `nil`, `#queue` may legally return 0 (any border is valid, see [[Tables Metatables and OOP]]), so the loop could stop early. Track the ends yourself. If a job errors, the Heartbeat thread for that frame dies and the rest wait until the next frame; wrap `job()` in `pcall` if jobs come from many systems. For a fixed-capacity queue, use the ring buffer below.

A real example of the cost of not slicing: the reference project used deferred loading on join so the first seconds after spawn stayed smooth ([[Case Study - Fast Join and Deferred Loading]]).

### 4.2 Ring buffers for histories

Position histories for lag compensation, damage-per-second windows and input buffers all need "append new, drop oldest". A fixed-size ring does it with zero allocation after setup:

```lua
--!strict
export type Ring<T> = { items: { T }, times: { number }, size: number, head: number, count: number }

local Ring = {}

function Ring.new<T>(size: number, fill: T): Ring<T>
	return {
		items = table.create(size, fill),
		times = table.create(size, 0),
		size = size,
		head = 0,
		count = 0,
	}
end

function Ring.push<T>(r: Ring<T>, t: number, item: T)
	r.head = r.head % r.size + 1
	r.items[r.head] = item
	r.times[r.head] = t
	r.count = math.min(r.count + 1, r.size)
end

-- Newest sample at or before time t (nil if none). Walks backwards from the head.
function Ring.at<T>(r: Ring<T>, t: number): T?
	local idx = r.head
	for _ = 1, r.count do
		if r.times[idx] <= t then
			return r.items[idx]
		end
		idx = if idx == 1 then r.size else idx - 1
	end
	return nil
end

return Ring
```

Storing `Vector3` items costs no GC allocation per push. At 60 Hz, one second of history is 60 slots per character. [[Hitboxes and Hit Detection]] shows the rewind use case; [[Client Prediction and Reconciliation for Combat]] uses the same structure.

### 4.3 Spatial hashing

"Who is near X?" asked by many X against many Y is the classic O(n x m) trap. Bucket Y into grid cells once per tick, then each query checks only nearby cells:

```lua
--!strict
local CELL = 32 -- studs; roughly the largest query radius you use often

local cells: { [Vector3]: { any } } = {}

local function key(p: Vector3): Vector3
	-- Luau vectors are value types, so equal cell vectors index the same table slot
	-- (rule of thumb; if in doubt, use a string or integer key such as cx * 65536 + cz)
	return Vector3.new(p.X // CELL, 0, p.Z // CELL)
end

local function rebuild(entities: { { position: Vector3 } })
	for _, bucket in cells do
		table.clear(bucket) -- keep bucket tables to avoid reallocating every tick
	end
	for _, e in entities do
		local k = key(e.position)
		local bucket = cells[k]
		if not bucket then
			bucket = {}
			cells[k] = bucket
		end
		table.insert(bucket, e)
	end
end

local function queryRadius(center: Vector3, radius: number, out: { any }): { any }
	table.clear(out)
	local r2 = radius * radius
	local reach = math.ceil(radius / CELL)
	local c = key(center)
	for dx = -reach, reach do
		for dz = -reach, reach do
			local bucket = cells[c + Vector3.new(dx, 0, dz)]
			if bucket then
				for _, e in bucket do
					local d = e.position - center
					if d:Dot(d) <= r2 then
						table.insert(out, e)
					end
				end
			end
		end
	end
	return out
end

return { rebuild = rebuild, queryRadius = queryRadius }
```

Two caveats. Empty buckets accumulate if entities roam a huge map; prune buckets that stayed empty for a few rebuilds. And for queries against parts (not your own entity list), the engine's `GetPartBoundsInRadius` with a collision group or an include list may already be faster than any Luau grid ([[Raycasts Shapecasts and Spatial Queries]]).

### 4.4 Dirty flags and change detection

Recomputing derived values every frame (total stats from equipment, UI layouts, path costs) is a common hidden cost. Mark a flag when an input changes and recompute lazily on the next read. The win is unbounded: a value that changes twice a minute and is recomputed 60 times a second wastes 99.9% of its work.

---

## 5. GC: the cost you do not see in the loop

The Luau collector is incremental, paced to keep the heap at a target relative to live data, and can do much of its work outside script execution when the host requests per-frame collection steps (luau.org). That is good news, but allocation still costs: every temporary table, closure, thread or string becomes GC work later.

How to spot allocation trouble:

- The harness heap delta is large for a function that "should not allocate".
- The Developer Console memory view shows the Luau heap rising quickly in a sawtooth during gameplay ([[Developer Console and Stats]]).
- The MicroProfiler shows periodic GC work that grows with the number of active entities.

Fixes in order: stop allocating per item per frame (reuse scratch tables with `table.clear`, pass arguments instead of closures), then reduce per-event allocations in high-frequency events, then tag systems with `debug.setmemorycategory` to find which one is responsible ([[Memory Budgets and Leaks]]).

**The scratch-table aliasing bug.** Reusing a returned scratch table is fast and dangerous:

```lua
local a = nearbyEnemies(posA) -- returns the shared scratch table
local b = nearbyEnemies(posB) -- clears and refills the SAME table
print(#a == #b)               -- always true: a and b are the same table
```

Either document "caller must not keep this" in the function name (`nearbyEnemiesTemp`) or take an `out` table parameter, as `queryRadius` above does, so the caller owns the storage.

---

## 6. When not to optimise

- **Run-once code.** Module initialisation, a shop opening, a level loading. Make it correct and readable.
- **Engine-bound code.** If the MicroProfiler shows the time in physics, rendering or a single engine call, Luau changes will not help; reduce the calls instead.
- **Code that is about to change.** Optimised code is harder to modify. Optimise systems that have stabilised.
- **When the win is under about 0.1 ms per frame on your target device** (rule of thumb), unless it is a pattern repeated across many systems.
- **Readability trades.** Manual loop unrolling, inlining helper functions by hand and localising globals are usually worse than nothing in Luau, because the compiler already does inlining at optimisation level 2 and imports resolve globals at load (luau.org).

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Benchmark shows 0 ns/op | Work optimised away | Store results in a sink; use the index as input |
| Results flip between runs | Noise; single run | Median of several rounds; alternate order |
| "Optimised" code slower in game than in bench | Bench ignored GC; ran on desktop | Check heap delta; profile on device |
| Queue drain stutters with many jobs | `table.remove(t, 1)` | Head index or ring buffer |
| Two query results always equal | Shared scratch table aliasing | `out` parameter |
| `local x = math.x` everywhere, no gain | Imports already resolve it | Remove for clarity |
| `@native` function shows no gain | Engine-call bound, or a breakpoint is set | Profile; remove breakpoints; type parameters |

## Checklist

- [ ] Hot spot found in the MicroProfiler before touching code.
- [ ] Benchmarks use warm-up, several rounds, a median, a sink and a heap delta.
- [ ] Per-frame cost computed as cost x count x rate, on the target device.
- [ ] Frequency and count reduced before per-item cost.
- [ ] No per-item allocations (tables, closures, strings) in per-frame loops.
- [ ] Engine property reads cached; writes only on change.
- [ ] Long queues use a head index or ring buffer, not `table.remove(t, 1)`.
- [ ] Spatial questions use a grid or engine spatial query, not all-pairs loops.

## See also

[[Luau Performance and Native Codegen]] · [[Script Performance]] · [[MicroProfiler Guide]] · [[Performance Fundamentals]] · [[Memory Budgets and Leaks]] · [[Buffers and Binary Data]] · [[Functions Closures and Upvalues]] · [[Tables Metatables and OOP]] · [[Metatables and OOP - When and When Not]] · [[Parallel Luau and Actors]] · [[Mobile and Low-End Optimization]]

## Connected notes
<!-- auto-links:start -->
[[Luau Garbage Collection and the Memory Model]] · [[Luau Language Essentials]] · [[Advanced Luau Start Here]] · [[Links - Luau language]] · [[Entity Component Systems]] · [[Building a Signal Library]]
<!-- auto-links:end -->
