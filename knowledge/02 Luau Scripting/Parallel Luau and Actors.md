---
tags: [luau, parallel, actors, multithreading, sharedtable, performance]
---
# Parallel Luau and Actors

By default all Luau in a Roblox server or client runs on one thread, one piece at a time. **Parallel Luau** lets scripts placed under `Actor` instances run parts of their work simultaneously on several CPU cores. It is powerful for compute-heavy, mostly read-only work (raycasts, spatial queries, NPC sensing, procedural generation, pathfinding maths) and useless or harmful for work that mainly writes to Instances. This note explains the execution model, thread safety levels, communication (messages, SharedTable, the DataModel), how modules behave per Actor, a worker-pool pattern, and how to tell whether it helped.

All facts below are from the Roblox Parallel Luau guide and API reference (Docs) unless marked.

---

## 1. The model

- An **Actor** (a `Model` subclass) is a unit of execution isolation. Scripts that are descendants of an Actor belong to it (the closest ancestor Actor if nested; nesting is discouraged).
- Each frame has **serial** phases (normal, one thread) and **parallel** phases. Code under an Actor starts serial. It runs in parallel only after it **desynchronizes**:
  - `task.desynchronize()` suspends the thread and resumes it in the next parallel phase.
  - `task.synchronize()` suspends it and resumes it in the next serial phase.
  - `signal:ConnectParallel(fn)` runs the handler directly in a parallel phase (cheaper than `Connect` + `desynchronize`).
  - `actor:BindToMessageParallel(topic, fn)` runs message handlers in parallel.
- Scripts in the **same Actor** always run sequentially relative to each other. Parallelism comes from **many Actors**.
- Calling `task.desynchronize`/`synchronize` from a script that is not under an Actor errors. A ModuleScript may call them if it was required by a script under an Actor.
- `require` **cannot** be called in a parallel phase. Require everything in serial code first.

```lua
-- Script under an Actor
local RunService = game:GetService("RunService")

RunService.Heartbeat:ConnectParallel(function(dt: number)
	-- PARALLEL: read the world, compute
	local result = computeSomething(dt)
	task.synchronize()
	-- SERIAL: apply results to instances
	applyResult(result)
end)
```

---

## 2. Thread safety

Every API member has a safety level (Docs):

| Level | Properties | Functions |
|---|---|---|
| **Unsafe** | Cannot be read or written in parallel | Cannot be called in parallel |
| **Read Parallel** | Readable, not writable, in parallel | n/a |
| **Local Safe** | Usable within the same Actor; other Actors may read but not write | Callable within the same Actor only |
| **Safe** | Read and write | Callable |

Members without a documented level are **Unsafe**. The engine detects violations and blocks them (an error), so mistakes are loud.

In practice: reading most properties (positions, CFrames, attributes) and running spatial queries (`Workspace:Raycast`, `Blockcast`, `GetPartBoundsInBox` and similar are documented as safe for parallel use; check each member's tag) work in parallel. **Creating, parenting, destroying instances, and writing most properties require serial code.** That shapes every design: compute in parallel, write in serial.

---

## 3. Modules and state are per Actor

"Each Actor runs in its own Luau VM. ModuleScripts required by an Actor are not shared or cached across Actors or with the main thread" (Docs). So:

- A config module required in 64 Actors runs 64 times and uses 64 copies of memory. Keep Actor-side modules small and data-light.
- Module-level caches, registries and singletons are **per Actor**. A "global" enemy registry module does not see entities registered from another Actor.
- `script:GetActor()` returns `nil` in a ModuleScript unless the module itself is a descendant of the Actor (a module in ReplicatedStorage required by an Actor is not).
- A `buffer` object cannot be used from multiple Actor scripts (Docs: buffer library).
- Messages are **copied** across VM boundaries; functions cannot be sent.

---

## 4. Communication

### Actor messages

```lua
-- Sender (any script, serial or parallel)
workerActor:SendMessage("Generate", chunkX, chunkZ, seed)   -- asynchronous, never yields

-- Receiver (script under workerActor)
local actor = script:GetActor()
assert(actor, "must run under an Actor")
actor:BindToMessageParallel("Generate", function(x: number, z: number, seed: number)
	local voxels = generate(x, z, seed)      -- parallel
	task.synchronize()
	writeVoxels(x, z, voxels)                -- serial: WriteVoxels is not parallel-safe
end)
```

Only scripts that are descendants of an Actor can bind to its messages. Arguments are passed by copy: "Sending large tables incurs a full copy on each call" (Docs). Send IDs and small parameters, not world snapshots.

### SharedTable

`SharedTable` is a table-like structure accessible from all Actors without copying. Updates are atomic per operation and immediately visible to all Actors (Docs).

- Keys: strings, or non-negative integers below 2^32.
- Values: booleans, numbers, vectors, strings, SharedTables, or other serializable datatypes. No functions, no Instances as keys.
- Share by name through `SharedTableRegistry:GetSharedTable(name)`, or send one through `SendMessage` (no copy).
- `SharedTable.new(luauTable)` converts nested tables to SharedTables.
- `SharedTable.increment(st, key, delta)` atomically adds and returns the old value; much faster than `update` (Docs).
- `SharedTable.update(st, key, fn)` atomically replaces a value; `fn` **may be called multiple times** under contention, so it must be pure.
- `SharedTable.clone(st, deep?)` (shallow clone is an atomic snapshot), `cloneAndFreeze`, `isFrozen`, `size`, `clear`.

Read-modify-write without `update`/`increment` is a race:

```lua
-- Wrong under concurrency: another Actor can write between the read and the write
st.kills = st.kills + 1

-- Right
SharedTable.increment(st, "kills", 1)
```

SharedTable access is slower than a plain Luau table (it is synchronized). Read what you need into locals at the start of a parallel job.

### The DataModel

Actors can read shared instance state (positions, attributes) in parallel and write it in serial. This is simple but forces synchronization; use it for results, not for chatty coordination.

---

## 5. Pattern: a worker pool for spatial queries

The docs' guidance: use **more Actors than cores** for load balancing (they cite 64 Actors on a 4-core target as reasonable for raycast validation), but divide by logical units, not arbitrarily.

```lua
--!strict
-- ServerScriptService/LineOfSight (Script, not under an Actor): creates workers and dispatches jobs
local ServerScriptService = game:GetService("ServerScriptService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")

local WORKERS = 16
local workerTemplate = ServerScriptService:WaitForChild("LoSWorker") :: Script   -- disabled template script

local actors: { Actor } = {}
for i = 1, WORKERS do
	local actor = Instance.new("Actor")
	actor.Name = `LoSWorker{i}`
	local worker = workerTemplate:Clone()
	worker.Enabled = true
	worker.Parent = actor
	actor.Parent = ServerScriptService
	actors[i] = actor
end

local results = SharedTableRegistry:GetSharedTable("LoSResults")   -- npcId -> 1 if the target is visible, else 0

-- Each frame (or every few frames), split NPC ids across workers
local function dispatch(npcIds: { number })
	local per = math.ceil(#npcIds / WORKERS)
	for w = 1, WORKERS do
		local first = (w - 1) * per + 1
		local last = math.min(w * per, #npcIds)
		if first <= last then
			actors[w]:SendMessage("Check", table.move(npcIds, first, last, 1, {}))
		end
	end
end
```

```lua
--!strict
-- LoSWorker (template Script; runs under each Actor)
local Workspace = game:GetService("Workspace")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
local actor = script:GetActor() :: Actor
local results = SharedTableRegistry:GetSharedTable("LoSResults")
local NpcIndex = require(game:GetService("ServerScriptService").NpcIndex)  -- require in serial, at load

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

actor:BindToMessageParallel("Check", function(ids: { number })
	for _, id in ids do
		local npc = NpcIndex.get(id)                 -- read-only lookups
		if npc then
			local origin = npc.head.Position
			local target = npc.target
			local visible = 0
			if target then
				local dir = target.Position - origin
				local hit = Workspace:Raycast(origin, dir, params)
				if not hit or hit.Instance:IsDescendantOf(target.Parent :: Instance) then
					visible = 1
				end
			end
			results[id] = visible                    -- SharedTable write is parallel-safe
		end
	end
end)
```

Then serial code reads `results` and acts (changes AI state, plays animations). Notes: `NpcIndex` here would be a per-Actor copy, so it must be able to answer from the DataModel (for example by finding the NPC model by an ID attribute), not from a table filled by the main VM. That per-VM isolation is the single most common design error with Actors.

**Alternative layout:** one Actor per NPC with its own scripts. Simple and natural for complex agents, but each Actor's scripts and module copies cost memory; for thousands of simple agents, a pool is cheaper.

---

## 6. When Parallel Luau helps, and when it does not

| Good fit | Poor fit |
|---|---|
| Many independent raycasts / shapecasts / overlap queries | Work that mostly creates or moves Instances |
| NPC perception and decision scoring | Tiny jobs (overhead dominates) |
| Procedural generation maths (noise, voxel fields) | Code that needs `require` mid-job |
| Hit validation per player | Shared mutable state with heavy contention |
| Path smoothing, steering, flocking maths | Anything limited by one serial write phase |

Docs warnings: parallel code still has to finish within the frame; long uninterrupted parallel computations still cause lag. And the serial phases between parallel ones are where all writes happen; if your results need large serial application, the gain shrinks.

**Measure.** Use the MicroProfiler ([[MicroProfiler Guide]]): parallel work shows on worker threads; compare frame times with and without. If the serial phase grows (copying results, synchronizing), Parallel Luau may be a net loss. Start serial, optimize the algorithm ([[Luau Performance and Native Codegen]]), and parallelize only measured hot spots.

**Client devices** vary from 2 to many cores. Parallel work on the client can help desktops and hurt low-end phones less than you fear (it still runs, just with less concurrency), but test on low-end devices ([[Mobile and Low-End Optimization]]).

---

## 7. Gotchas

- Forgetting `task.synchronize()` before writing a property: error about the property not being safe in parallel. Read the message; it names the member.
- A parallel handler that `require`s lazily errors. Move requires to the top.
- `task.spawn`/`defer`/`delay`/`wait` keep the current phase (Docs), so a thread spawned from parallel code is also parallel.
- Breakpoints and some debugging views behave differently in parallel code; log with care.
- Sharing one `RaycastParams` object across threads within the same Actor is fine since the Actor's scripts run sequentially, but do not mutate shared params during a job.
- Actor messages are not RemoteEvents: they never cross the network.

---

## 8. Designing a parallel system step by step

1. **Write it serially first**, as a pure function of inputs: `computeLineOfSight(npcState, worldReads) -> result`. Unit-test it ([[Testing Strategies and Frameworks]]).
2. **Separate reads, compute and writes.** Collect all instance writes into a list of results; apply them in one place. This is good structure even if you never parallelize.
3. **Profile.** If the compute part is a meaningful share of frame time (rule of thumb: several milliseconds per frame on the server, or visible on low-end clients), continue; otherwise stop here.
4. **Choose the decomposition**: one Actor per entity (simple, more memory) or a pool of workers (efficient, more plumbing).
5. **Choose the data path**: what workers read from the DataModel (positions, attributes), what they need from the main VM (send in messages or a SharedTable), and how results come back (SharedTable, or the worker writes after `task.synchronize()`).
6. **Move the compute into `ConnectParallel` or `BindToMessageParallel`**, keep writes after `task.synchronize()`.
7. **Measure again** in the MicroProfiler, including the serial sections. Keep it only if the frame got shorter.

### Determinism and ordering

Parallel jobs finish in any order. Do not let gameplay outcomes depend on which worker wrote first (for example two workers both deciding to claim the same loot drop). Resolve conflicts in the serial phase with a deterministic rule (lowest ID wins), as the Docs example does by re-checking `hitPart.Parent` before destroying.

### Client-side uses

On the client, good candidates are visual-only computations: crowd or flock steering for decorative NPCs, foliage wind maths, procedural animation for many background creatures ([[Flight Flocks and Path Animation]]), and expensive raycast-based effects. Results are applied to local, non-replicated instances in the serial phase.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| No speed-up | All scripts in one Actor, or no `desynchronize` | Many Actors; `ConnectParallel` |
| "not safe in parallel" errors | Writing instances in a parallel phase | `task.synchronize()` first |
| Registry empty inside workers | Per-Actor module copies | DataModel lookups, SharedTable, or messages |
| Memory jumps with Actors | Big modules required per Actor | Slim worker modules |
| Counters wrong under load | Read-modify-write on SharedTable | `increment` / `update` |
| Slower overall | Large message copies, big serial apply phase | Send IDs; batch writes |

## Checklist

- [ ] Profiled first; the hot spot is compute or queries, not instance writes.
- [ ] Work split by logical unit across many Actors.
- [ ] Requires at load time; no requires in parallel.
- [ ] Parallel phase reads and computes; serial phase writes.
- [ ] Shared state via SharedTable with atomic operations, or results by message.
- [ ] Verified gains in the MicroProfiler on target devices.

## See also

[[Task Library Coroutines and Yielding]] · [[Module Scripts and Requiring]] · [[Luau Performance and Native Codegen]] · [[Raycasts Shapecasts and Spatial Queries]] · [[NPC AI and Behaviour]] · [[Procedural World Generation]] · [[Script Performance]] · [[MicroProfiler Guide]]

## Connected notes
<!-- auto-links:start -->
[[Infinite and Streamed Worlds]] · [[Luau Garbage Collection and the Memory Model]] · [[Links - Script types]] · [[Building a Signal Library]] · [[Frame Order and RunService Timing]] · [[Frame Budget]]
<!-- auto-links:end -->
