---
tags: [luau, advanced-luau, memory, garbage-collection, gc, weak-tables, performance]
---
# Luau Garbage Collection and the Memory Model

<!-- tldr:start -->
> [!tldr] TL;DR
> - Memory bottoms rise each round: References held after objects end -> Remove entries on end-of-life events
> - Weak cache never empties: Value references key (no ephemerons) -> Store ids, pass keys in
> - Leak disappears after a fixed delay: Timers or delayed threads holding closures -> Owner-scoped cancellation
> - Hot loops avoid creating tables, closures, strings and CFrames per item.
> - Every module-level table keyed by players or instances has a removal path.
> - No weak-table value references its key.
>
> Cost: TL;DR ~170 tok · whole note ~4.8k tok. Read more: ## 1. What lives on the heap · ## 4. What Luau leaves out, and why it matters · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The vault already says what leaks look like and how to hunt them ([[Memory Budgets and Leaks]], [[Hunting Memory Leaks Step by Step]]) and that allocation churn costs frame time ([[Luau Performance and Native Codegen]], [[Luau Performance Patterns with Benchmarks]]). This note explains the machinery underneath: which Luau values live on the heap and which do not, how the collector decides when to run and what it does in each phase, what Luau deliberately leaves out compared with other Lua versions, how Roblox Instances add a second lifetime on top, and how those facts turn into concrete rules. If you understand this model, most memory advice stops being folklore.

Facts about the collector are from luau.org (performance and compatibility pages, as of October 2026). Roblox-specific behaviour is labelled either Roblox docs or rule of thumb.

---

## 1. What lives on the heap

Every Luau value is either stored inline in the slot that holds it (a register, a table field, an upvalue) or is a reference to a garbage-collected object.

| Type | Stored as | Allocates when created | Notes |
|---|---|---|---|
| `nil`, `boolean`, `number` | Inline value | No | Numbers are 64-bit doubles |
| `vector` (Roblox `Vector3`) | Inline value | No | Luau has a native vector value type, which Roblox uses for `Vector3` |
| `string` | Reference | Yes, unless an identical string already exists | Strings are interned (rule of thumb from Lua 5.1 lineage), so equal strings share one object |
| `table` | Reference | Yes | Array part plus hash part, both separately sized |
| `function` (closure) | Reference | Usually; see closure caching below | Each closure holds references to its upvalues |
| `thread` (coroutine) | Reference | Yes, including its own stack | Suspended threads keep everything on their stack alive |
| `buffer` | Reference | Yes, fixed size | Contents are raw bytes, not traced by the collector |
| `userdata` (Instance, CFrame, Color3, RBXScriptConnection...) | Reference to a wrapper | Yes, for the wrapper | Most engine types are userdata; `CFrame` math allocates a new userdata per result |

Two consequences you can use immediately.

**`Vector3` arithmetic does not allocate; `CFrame` arithmetic does.** A loop that computes `a + b * t` with vectors produces no garbage. The same loop with `cf * CFrame.new(...)` produces a userdata per operation. In per-frame code on many objects, prefer vector maths and build the `CFrame` once at the end ([[Math Vectors and CFrames]]).

**String building allocates per intermediate.** `s = s .. x` in a loop creates a new string each iteration, and every one of them is garbage except the last. `table.concat` on a list of parts, or writing into a `buffer`, creates one final string ([[Strings Patterns and Formatting]]).

### Closure caching

luau.org describes closure caching: when a function expression captures no upvalues, or captures only upvalues that are never reassigned, the VM may reuse one closure object instead of allocating a new one each time the expression runs. In practice:

```lua
-- Allocates a new closure per call: captures 'target', which differs every time.
local function makeFilter(target)
	return function(x) return x == target end
end

-- Can be cached: captures nothing that changes.
local function sortByLevel(list)
	table.sort(list, function(a, b) return a.level < b.level end)
end
```

You do not need to contort code for this, but it explains why a benchmark of an inline comparator often shows no allocation while a "factory" closure does.

---

## 2. Tables: capacity is sticky

A table has an array part (for keys `1..n`) and a hash part (everything else). Both grow by reallocation when full, typically doubling, which is why building a 10,000-element array by appending costs about 14 reallocations rather than 10,000. `table.create(n)` pre-sizes the array part when you know `n` ([[Luau Performance Patterns with Benchmarks]]).

The part people miss is the other direction. **Removing entries does not shrink a table.** Setting keys to `nil` leaves the slots allocated; the table is resized only when an insertion triggers a rehash. A cache that once held 100,000 entries and was then cleared with `table.clear` keeps its capacity (rule of thumb, consistent with `table.clear` being documented as a way to reuse a table's memory). That is exactly what you want for a per-frame scratch table and exactly what you do not want for a one-off spike.

```lua
-- Scratch table reused every frame: keep capacity, avoid reallocations.
local scratch = {}
local function collectTargets(...)
	table.clear(scratch)
	-- fill scratch
	return scratch
end

-- One-off spike (a giant scan at startup): drop the table instead of clearing it.
local bigIndex = buildIndex()
useIndex(bigIndex)
bigIndex = nil   -- the whole table, capacity included, becomes garbage
```

Weak tables have a related option. Adding `s` to the `__mode` string (`__mode = "ks"`) marks a weak table as **shrinkable**: the collector may resize it to its optimal capacity during collection. luau.org warns this can make iteration miss keys if a resize happens mid-iteration, so use it only for weak caches you never iterate while yielding.

---

## 3. How the collector runs

Luau's collector is **incremental**: "a little bit of work every so often", and never a stop-the-world traversal of the whole heap (luau.org). It is not generational. A collection cycle has three phases:

1. **Mark.** Starting from roots (the registry, running threads, globals), it marks reachable objects, a slice at a time, interleaved with your code.
2. **Atomic.** A short non-incremental step that finishes marking things that changed while marking ran. luau.org notes this step could historically cause pauses of tens of milliseconds, and that Luau reduces it with a "remark" step and by marking coroutines incrementally, so only active coroutines are traversed atomically.
3. **Sweep.** Unmarked objects are freed. Luau's sweeper is **paged**: same-sized objects sit in 16 KB pages swept one page at a time, which luau.org reports as 2 to 3 times faster than list-based sweeping, and saves 16 bytes per object on 64-bit platforms.

**Who pays for collection.** Work happens in two ways. Allocation triggers **assists**: when you allocate, you may be charged a slice of GC work right there, inside your script. And the host (Roblox) can request collection steps every frame, outside script execution. luau.org explains that the pacing controller estimates allocation rate so per-frame steps can do most of the work outside scripts. In MicroProfiler terms: a script that allocates heavily shows GC work inside its own timing, and the per-frame GC step shows separately ([[MicroProfiler Guide]]).

**When collection runs.** Pacing is driven by a target heap size expressed as a percentage of live data, tuned by a controller (luau.org). The practical reading:

- Heap size oscillates. After a cycle, heap is roughly live data; it then grows with garbage until the next cycle frees it. The Developer Console shows this as a sawtooth ([[Developer Console and Stats]]).
- The **bottom** of the sawtooth is your live data. If the bottoms rise over time, you have a leak. If the bottoms are flat but the teeth are tall and fast, you have churn.
- You cannot force a full collection from Roblox scripts. `collectgarbage` is listed as deprecated in the Roblox globals reference, and Luau's `collectgarbage("count")` returns only one result (luau.org compatibility). Use `gcinfo()` or `collectgarbage("count")` to read heap size in KB, and measure trends over time, not before and after one call ([[Memory Budgets and Leaks]]).

---

## 4. What Luau leaves out, and why it matters

From the Luau compatibility page (as of October 2026):

| Feature from other Lua versions | In Luau | Consequence |
|---|---|---|
| `__gc` finalizers on tables | Not supported ("due to sandboxing and performance/complexity") | You cannot run code when an object is collected. Cleanup must be explicit |
| Ephemeron tables | Not supported | A weak-keyed table whose value references its own key keeps both alive forever |
| Full `collectgarbage` options | Only `"count"` meaningful on Roblox | No manual full collection, no tuning from scripts |

The first row means every resource cleanup in Roblox code is a deliberate call: `Disconnect`, `Destroy`, `task.cancel`, removing a table entry. No "destructor" will save you. This is why cleanup bags (Maid, Trove) are a pattern in Roblox and not in languages with finalizers ([[Events Signals and Connections]]).

The second row is the subtle one.

### The ephemeron trap

```lua
-- Intended: extra data per object, collected when the object is collected.
local extra = setmetatable({}, { __mode = "k" })

local function attach(obj)
	extra[obj] = {
		owner = obj,                 -- value references its key
		onDone = function() print(obj) end,  -- closure captures the key too
	}
end
```

In a language with ephemerons, the entry would be collected once nothing outside the table references `obj`. In Luau, the value is strongly held by the weak-keyed table, the value references the key, and so the key is always reachable: **the entry never goes away.** The weak table silently becomes a strong one.

Fixes: never let a value in a weak-keyed table reference its key, directly or through a closure. Pass the key in when you need it (`extra[obj].onDone(obj)`), or store an id instead of the object. Better still, use explicit removal on the object's end-of-life event and treat weakness as a safety net ([[Memory Budgets and Leaks]]).

### Weak tables and Instances

Weak tables interact with Instances in ways the official reference does not specify. An Instance has two lifetimes: the engine object, and the Luau userdata wrapper your scripts hold. The engine keeps objects in the DataModel alive regardless of Luau. Community reports on the DevForum describe weak tables "not working" with Instances, in both directions: entries that never disappear (because the engine or a connection still references the wrapper) and, in older reports, entries that disappear while the instance still exists (because the wrapper was collected and a new one created on next access). Neither behaviour is documented, so this note does not state one as fact.

The robust rule: **do not use weak tables as the cleanup mechanism for Instance-keyed data.** Key by the instance, and remove the entry on `Destroying`, `AncestryChanged` to nil, `PlayerRemoving`, or the tagged-instance removed signal ([[CollectionService Patterns]]). A weak mode on top is harmless as a belt-and-braces measure.

---

## 5. Instances: Destroy, references, and zombies

The engine frees an Instance's memory when it is out of the DataModel **and** nothing references it, including Luau references. `Destroy()` (Roblox docs) sets `Parent` to nil, locks it, disconnects all connections on the instance and its descendants, and does the same for descendants. What it cannot do is clear your references.

A **zombie** is a destroyed instance still referenced from Luau. The engine object stays allocated, together with its descendants if they are reachable through it. Typical holders:

| Holder | Example | How to spot |
|---|---|---|
| Module-level table | `activeEnemies[model] = state`, never removed | Count of entries grows across rounds |
| Closure in a connection elsewhere | A global `Heartbeat` handler capturing `model` | Handler count grows; `model.Parent == nil` inside it |
| Suspended thread | `task.delay(60, function() model:... end)` | Zombies vanish 60 seconds after death |
| Timer or scheduler entry | Custom scheduler holding callbacks ([[Custom Schedulers and Coroutine Patterns]]) | Pending timer count grows |
| UI references | A frame referencing a destroyed character's humanoid | Client memory grows per respawn |

A useful diagnostic is to tag suspicious tables with a size check in a debug build: every N seconds, count entries whose key has `Parent == nil`. A non-zero count that grows is a leak with a name ([[Hunting Memory Leaks Step by Step]]).

Parenting to nil without destroying is legitimate (pooling, temporary removal), but then you own the lifetime: connections on the instance are **not** disconnected, so any handler connected to it keeps running and keeps its closure alive.

---

## 6. Threads and closures: the hidden roots

A suspended thread is a root for everything on its stack and every upvalue of every function on that stack. That makes threads the most expensive leak per line of code.

```lua
-- Leaks the whole character model for as long as the event never fires.
local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	task.spawn(function()
		SomeGlobalSignal:Wait()        -- may never fire for this character
		humanoid.WalkSpeed = 30
	end)
end
```

Each respawn adds a thread suspended forever on `SomeGlobalSignal`, holding its `humanoid` and through it the character. The fix is the same as for timers: give the thread an owner and cancel it when the owner ends (a scope, see [[Custom Schedulers and Coroutine Patterns]]), or wait with a timeout.

Closures capture **variables, not values**. A closure that captures a local captures the variable cell, shared with every other closure that captures it. Setting the variable to `nil` after use releases the referenced object even if the closure stays alive:

```lua
local bigData = loadEverything()
button.Activated:Connect(function()
	if bigData then
		apply(bigData)
		bigData = nil      -- releases the table; the connection no longer pins it
	end
end)
```

---

## 7. Measuring allocation honestly

Because collection runs during measurement, a naive "heap before, heap after" can even go negative. Three techniques that work:

**Many iterations, KB per iteration.** Run the function thousands of times and divide the heap growth by the count. Collection in the middle adds noise but the average is meaningful when the per-call allocation is large relative to noise.

```lua
--!strict
local function allocPerCall(fn: () -> (), iterations: number): number
	-- warm-up so one-time allocations (caches, interned strings) are not counted
	for _ = 1, 100 do fn() end
	local before = gcinfo()
	for _ = 1, iterations do fn() end
	local after = gcinfo()
	return (after - before) * 1024 / iterations   -- bytes per call, approximate
end
```

If the result is near zero or negative, the function either does not allocate or a cycle ran during the loop; repeat a few times and take the maximum. This is a relative tool: compare two versions of a function, do not quote absolute bytes.

**Memory categories.** `debug.setmemorycategory(name)` attributes allocations from the current thread to a named category in the Developer Console memory view; `debug.resetmemorycategory()` restores the default ([[Luau Performance and Native Codegen]]). Set a category at the top of each system's threads and long-running loops, and the console tells you which system owns the growth.

**Soak tests.** Leaks show up over time, not in a single measurement. Run the suspicious loop (respawn 200 times, open and close a menu 500 times) and read the sawtooth bottoms ([[Hunting Memory Leaks Step by Step]]).

---

## 8. Parallel Luau: separate heaps

Actors can run in separate Luau VMs, each with its own heap and collector. Data sent between Actors with messages is copied, buffers cannot be shared between Actor scripts (Roblox docs), and a module required in two Actors is two copies with two sets of state ([[Parallel Luau and Actors]]). Memory consequences:

- Large read-only data (a navigation grid, an item catalogue) required by every Actor exists once per VM. With eight Actors, that is eight copies.
- `SharedTable` exists to share data between Actors without copying it into every heap; check its access costs before using it for hot data.
- A leak in Actor code shows up in that Actor's VM; memory categories still help attribute it.

---

## 9. Turning the model into rules

| Rule | Why (from the model) |
|---|---|
| Prefer `Vector3` maths in hot loops; build `CFrame` once | Vectors are values; CFrames allocate |
| Reuse scratch tables with `table.clear`; drop one-off giants by reference | Capacity is sticky |
| Avoid `s = s .. x` in loops | Every intermediate string is garbage |
| Never let a weak table value reference its key | No ephemerons |
| Never rely on weakness for Instance cleanup | Undocumented two-lifetime behaviour |
| Every thread and timer has an owner that cancels it | Suspended threads are roots |
| Explicit cleanup for everything | No finalizers |
| Watch sawtooth bottoms for leaks, tooth height for churn | Pacing targets a percentage of live data |

## When not to worry

- **Startup and loading code.** Allocation during a one-time load is fine; the collector catches up.
- **Low-frequency events.** A purchase handler that allocates 10 tables per call is irrelevant.
- **Before you see it.** If the MicroProfiler shows no GC pressure and memory bottoms are flat, allocation-hunting is wasted time.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Memory bottoms rise each round | References held after objects end | Remove entries on end-of-life events |
| Weak cache never empties | Value references key (no ephemerons) | Store ids, pass keys in |
| Leak disappears after a fixed delay | Timers or delayed threads holding closures | Owner-scoped cancellation |
| Frame spikes when many enemies are active | Per-frame allocation, especially CFrames and strings | Vectors, scratch tables, buffers |
| Memory high after a one-time scan | Giant table cleared but kept | Drop the reference |
| "Measured" negative allocation | GC ran mid-measurement | Many iterations, repeated, compare versions |
| Destroyed parts still in memory | Zombie references from Luau | Find holders; nil references |

## Checklist

- [ ] Hot loops avoid creating tables, closures, strings and CFrames per item.
- [ ] Every module-level table keyed by players or instances has a removal path.
- [ ] No weak-table value references its key.
- [ ] Every spawned thread and scheduled timer has an owner that cancels it.
- [ ] Systems set `debug.setmemorycategory` in their long-running threads.
- [ ] Soak tests read sawtooth bottoms, not single samples.
- [ ] Actor code does not duplicate large data per VM without a reason.

## See also

[[Advanced Luau Start Here]], [[Memory Budgets and Leaks]], [[Hunting Memory Leaks Step by Step]], [[Luau Performance and Native Codegen]], [[Luau Performance Patterns with Benchmarks]], [[Functions Closures and Upvalues]], [[Events Signals and Connections]], [[Custom Schedulers and Coroutine Patterns]], [[Building a Signal Library]], [[Parallel Luau and Actors]], [[Developer Console and Stats]], [[MicroProfiler Guide]]

## Connected notes
<!-- auto-links:start -->
[[Task Library Coroutines and Yielding]] · [[Luau Language Essentials]] · [[Metatables and OOP - When and When Not]] · [[Links - Memory leaks and cleanup]] · [[Tables Metatables and OOP]] · [[Script Performance]]
<!-- auto-links:end -->
