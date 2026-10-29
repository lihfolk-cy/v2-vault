---
tags: [procedural, generation, infinite-worlds, chunks, streaming, parallel-luau, terrain, performance]
---
# Infinite and Streamed Worlds

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Truncating instead of flooring chunk coords -> `math.floor`
> - Avoid: No hysteresis -> Unload radius larger than load radius
> - Avoid: FIFO generation -> Priority by distance and travel direction
> - Infinite justified over a large bounded world.
> - Chunk size a multiple of 4; floored coords; integer keys.
> - Load and unload radii with hysteresis; union over players.
>
> Cost: TL;DR ~140 tok · whole note ~5.2k tok. Read more: ## A server chunk manager · ## Interaction with instance streaming · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Procedural World Generation]] sketches runtime generation: a frame-budgeted queue that builds chunks near players. This note is the full system: chunk coordinates and keys, load and unload rings with hysteresis, prioritising what the player will see next, many players on one server, how generation interacts with Roblox instance streaming, Parallel Luau pipelines, saving player changes to an endless world, floating-point trouble far from the origin, and the budgets that decide whether "infinite" is realistic on a phone. Code uses the `Hash` module from [[Seeds Determinism and Reproducible Worlds]] and terrain functions from [[Noise Functions and Terrain Generation]].

## Do you actually need infinite?

"Infinite" is a feature players rarely use fully. Most explore a few thousand studs from spawn. Before building a streaming generator, consider:

| Option | Effort | When it is enough |
|---|---|---|
| Large fixed world, generated once in Studio | Low | Almost always; streaming handles the size |
| Per-server seeded world of fixed size | Medium | Replayable survival maps, different every server |
| Infinite generation | High | Exploration is the core loop and players travel far |

A **bounded but large** per-server world (for example 8,000 x 8,000 studs, generated progressively around players) gets 95 percent of the feeling with a fraction of the edge cases: no floating-point problems, a finite memory ceiling, a world border players understand. This note covers truly unbounded worlds too, but treat that as the expensive option.

## Chunk coordinates

Everything is keyed by integer chunk coordinates. Pick a chunk size that is a multiple of the 4-stud voxel grid and big enough that per-chunk overhead is small, small enough that one chunk builds within a few frames. Rule of thumb: 64 or 128 studs for terrain chunks.

```lua
--!strict
local CHUNK = 64 -- studs, multiple of 4

local function chunkOf(pos: Vector3): (number, number)
	return math.floor(pos.X / CHUNK), math.floor(pos.Z / CHUNK)
end

-- Integer key packing beats string keys in hot loops. Valid for |c| < 2^20.
local function key(cx: number, cz: number): number
	return (cx + 1048576) * 2097152 + (cz + 1048576)
end
```

`math.floor` (not truncation) matters at negative coordinates: position -1 belongs to chunk -1, not chunk 0. Truncating toward zero gives a double-width chunk 0 and seams along both axes.

The packed key stays below 2^42, exact in a double. String keys (`cx .. "," .. cz`) work but allocate a new string per lookup, which shows up when you check hundreds of chunks every frame.

## Rings and hysteresis

Each player has a **load radius** (chunks within it must exist) and an **unload radius** (chunks beyond it may be removed). The gap is hysteresis: without it, a player standing on a chunk boundary and wiggling causes the same chunks to load and unload repeatedly.

| Ring | Typical radius (rule of thumb) | Purpose |
|---|---|---|
| Collision ring | 1 to 2 chunks | Must exist before the player can reach it; block movement if not ready |
| Visual ring | 4 to 8 chunks | What the player sees |
| Unload ring | Visual ring + 2 | Beyond this, free memory |

On a server, the set of required chunks is the **union** over all players. Players clustered together share chunks; players spread out multiply the cost. Ten players exploring in ten directions is ten times the work of ten players in a group, which is the worst case to test.

## Priority: build what will be seen next

A simple FIFO queue builds chunks in request order. Better: sort by a score each time the player moves to a new chunk:

- **Distance** first: nearer chunks before farther.
- **Direction of travel**: chunks ahead (dot product of chunk direction with velocity) get a bonus.
- **Collision ring** always beats everything else.

```lua
--!strict
local function priority(cx: number, cz: number, pcx: number, pcz: number, vel: Vector3): number
	local dx, dz = cx - pcx, cz - pcz
	local dist = math.sqrt(dx * dx + dz * dz)
	local ahead = 0
	if vel.Magnitude > 1 and dist > 0 then
		ahead = (dx * vel.X + dz * vel.Z) / (dist * vel.Magnitude) -- -1..1
	end
	return dist - ahead * 1.5 -- lower is sooner
end
```

Re-sort only when a player crosses a chunk boundary, not every frame.

## A server chunk manager

This manager tracks which chunks are needed, builds them under a frame budget, unloads distant ones, and never builds the same chunk twice. `buildChunk` and `destroyChunk` are your functions (terrain write, prop spawning).

```lua
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CHUNK = 64
local LOAD_R, UNLOAD_R = 5, 7
local BUDGET = 0.004 -- seconds per Heartbeat for building

type ChunkState = "queued" | "built"
local state: { [number]: ChunkState } = {}
local coords: { [number]: { number } } = {}
local queue: { number } = {}
local dirty = true

local function key(cx: number, cz: number): number
	return (cx + 1048576) * 2097152 + (cz + 1048576)
end

local buildChunk: (number, number) -> () = function(cx, cz) end   -- replace
local destroyChunk: (number, number) -> () = function(cx, cz) end -- replace

local lastChunk: { [Player]: number } = {}

local function refresh()
	local needed: { [number]: number } = {} -- key -> best priority
	for _, plr in Players:GetPlayers() do
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local pcx, pcz = math.floor(root.Position.X / CHUNK), math.floor(root.Position.Z / CHUNK)
			local vel = root.AssemblyLinearVelocity
			for dz = -LOAD_R, LOAD_R do
				for dx = -LOAD_R, LOAD_R do
					if dx * dx + dz * dz <= LOAD_R * LOAD_R then
						local cx, cz = pcx + dx, pcz + dz
						local k = key(cx, cz)
						coords[k] = { cx, cz }
						local d = math.sqrt(dx * dx + dz * dz)
						local ahead = 0
						if vel.Magnitude > 1 and d > 0 then
							ahead = (dx * vel.X + dz * vel.Z) / (d * vel.Magnitude)
						end
						local p = d - ahead * 1.5
						if needed[k] == nil or p < needed[k] then needed[k] = p end
					end
				end
			end
		end
	end

	-- enqueue missing chunks, sorted by priority
	queue = {}
	for k, p in needed do
		if state[k] ~= "built" then
			state[k] = "queued"
			table.insert(queue, k)
		end
	end
	table.sort(queue, function(a, b) return needed[a] < needed[b] end)

	-- unload chunks beyond the unload radius of every player
	for k, s in state do
		if s == "built" and needed[k] == nil then
			local c = coords[k]
			local keep = false
			for _, plr in Players:GetPlayers() do
				local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local dx = c[1] - math.floor(root.Position.X / CHUNK)
					local dz = c[2] - math.floor(root.Position.Z / CHUNK)
					if dx * dx + dz * dz <= UNLOAD_R * UNLOAD_R then keep = true break end
				end
			end
			if not keep then
				destroyChunk(c[1], c[2])
				state[k] = nil
			end
		elseif s == "queued" and needed[k] == nil then
			state[k] = nil -- no longer wanted before it was built
		end
	end
end

RunService.Heartbeat:Connect(function()
	-- refresh when any player changes chunk
	for _, plr in Players:GetPlayers() do
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local k = key(math.floor(root.Position.X / CHUNK), math.floor(root.Position.Z / CHUNK))
			if lastChunk[plr] ~= k then
				lastChunk[plr] = k
				dirty = true
			end
		end
	end
	if dirty then
		dirty = false
		refresh()
	end

	local start = os.clock()
	local i = 1
	while i <= #queue and os.clock() - start < BUDGET do
		local k = queue[i]
		if state[k] == "queued" then
			local c = coords[k]
			buildChunk(c[1], c[2])
			state[k] = "built"
		end
		i += 1
	end
	-- drop processed entries in one move instead of table.remove(queue, 1) each time
	if i > 1 then
		queue = table.move(queue, i, #queue, 1, {})
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	lastChunk[plr] = nil
	dirty = true
end)
```

Design notes:

- **Removing from a dictionary while iterating it** (`state[k] = nil` inside `for k, s in state`) is allowed in Luau for the current key; adding keys during iteration is not. The code only clears.
- **`table.remove(queue, 1)` in a loop is O(n) per call.** With hundreds of queued chunks that adds up; the single `table.move` at the end is O(n) once.
- **Building a chunk may itself exceed the budget.** The budget check is between chunks, so one large chunk can still cause a long frame. Keep chunks small, or make `buildChunk` itself resumable (split the terrain write and the prop spawn across frames).
- **`coords` grows forever** in this sketch. In a long session, clear `coords[k]` when a chunk is unloaded and not needed; it is left in for clarity.
- **Never unload chunks containing persistent things** (a player's base, a dropped item that must survive). Track "pins" per chunk and skip unloading pinned chunks.

## Collision before the player arrives

If a player outruns generation, they fall through the world. Defences, in order:

1. **Generate ahead.** Priority by travel direction, as above.
2. **Cap speed by generation rate.** If your server builds about N chunks per second, a vehicle or flight ability must not cover more than about N/2 chunks per second (rule of thumb, leaving margin). Fast travel needs a loading step.
3. **Hold the player.** If the collision ring is not ready, anchor the root briefly or teleport back to the last safe position; show a short "loading terrain" hint. Prefer that over falling.
4. **Teleports pre-build.** Before moving a player far, request the destination chunks, wait until the collision ring there is built, then move them and call `Player:RequestStreamAroundAsync` for the client side.

## Interaction with instance streaming

Instance streaming and chunk generation are two separate layers and it is easy to confuse them.

- **Your generator decides what exists on the server.** Streaming then decides which of those instances each client receives. Roblox docs (as of October 2026): `StreamingMinRadius` defaults to 64 studs, `StreamingTargetRadius` to 1024, and `StreamOutBehavior` can be `LowMemory` (default) or `Opportunistic` (recommended in the docs).
- **Do not double-manage.** A common mistake is a server generator that unloads chunks at 300 studs while streaming targets 1024: clients lose geometry before streaming would have removed it, and the server rebuilds chunks that clients still see. Align the server unload radius with what clients should see, or above it.
- **Server-side building replicates.** Every part you create replicates to clients in range. Terrain writes on the server replicate too. That is the bandwidth cost of server generation ([[Network Bandwidth Budgets and Measuring Them]]).
- **Client-only cosmetic generation.** Grass tufts, pebbles and distant decoration can be generated on each client from the seed, never replicated. The server has no copy, so nothing gameplay-relevant may live there. Decide gameplay with integer hashes so client and server agree where needed ([[Seeds Determinism and Reproducible Worlds]]).
- **Model streaming modes** (`Atomic`, `Persistent`, `PersistentPerPlayer`, `Nonatomic`) apply to generated models like any other; set `Atomic` on chunk props that must arrive whole. See [[Instance Streaming]] and [[Level of Detail and Model Streaming]].

### Server or client terrain?

| Approach | Gameplay | Cost |
|---|---|---|
| Server writes terrain, streams | Authoritative collision, NPCs and pathfinding work | Server CPU, replication bandwidth |
| Each client writes its own terrain from the seed | No replication | Server has no terrain: NPC physics, server raycasts and validation do not work there |
| Server collision terrain, client decoration | Best of both | Two systems to keep consistent |

For any game with NPCs, combat or anti-cheat, the server must own collision. Client-only terrain fits single-player-feeling exploration with no server-side physics.

## Parallel Luau pipeline

Noise and array building are pure computation and the bulk of the cost. Terrain writes must happen in the serial phase. The usual pipeline uses several Actors, each with a script that binds a message handler in parallel, computes, then synchronises to write:

```lua
--!strict
-- Script inside an Actor (one of several worker Actors).
local actor = script:GetActor()
assert(actor, "must run under an Actor")

local Gen = require(game:GetService("ServerScriptService").WorldGen.Generate) -- pure functions

actor:BindToMessageParallel("Build", function(cx: number, cz: number, seed: number)
	-- parallel phase: no DataModel writes allowed here
	local region, materials, occupancy = Gen.chunkArrays(cx, cz, seed)

	task.synchronize() -- serial phase from here
	workspace.Terrain:WriteVoxels(region, 4, materials, occupancy)
end)
```

The manager distributes work: `workers[(i % #workers) + 1]:SendMessage("Build", cx, cz, seed)`. Notes:

- **Arguments are copied into the actor's VM**, so send small inputs (coordinates and seed), not big tables. Generate the big arrays inside the actor.
- **Each actor has its own copy of required modules**, so caches inside modules are per actor.
- **The write still costs serial time.** Parallel work removes the noise cost from the main thread, but `WriteVoxels` of a large region still runs serially. Small chunks keep each write short.
- **Count actors by cores, not by chunks.** A handful of workers (four to eight, rule of thumb) is enough; one actor per chunk creates overhead without speedup.

See [[Parallel Luau and Actors]] for the rules of each phase.

## Unloading

Unloading must free everything:

- **Terrain**: write the chunk region back to Air (`Terrain:FillBlock` with `Enum.Material.Air` over the chunk box, or `WriteVoxels` with Air arrays). Unloaded terrain that is left in place is not "unloaded".
- **Instances**: parent all chunk props under one Folder per chunk and `Destroy()` it.
- **Connections and tables**: any per-chunk signal connection or registry entry must be cleared in `destroyChunk`. Leaked per-chunk state is the classic slow memory climb in streaming worlds ([[Hunting Memory Leaks Step by Step]]).

Whether to unload at all is a choice. Terrain voxels are cheap compared to parts; some games keep generated terrain forever and only unload props. Measure memory over a long session with players spreading out ([[Memory Budgets and Leaks]]).

## Player changes to an endless world

If players dig, build or chop trees, a regenerated chunk must reflect their changes. The standard pattern is **seed plus deltas**:

- The world is `generate(seed)` plus a list of modifications per chunk.
- Each modification is small and explicit: `{kind = "removeTree", id = treeHash}`, `{kind = "dig", x, y, z, r}`, `{kind = "place", item, cframe}`.
- When a chunk builds, it generates from the seed, then applies its deltas in order.
- Deltas for a chunk are stored together; only chunks with changes take storage.

Storage choices:

| Scope | Where | Notes |
|---|---|---|
| One server's session world | Server memory | Lost at shutdown; fine for session-based games |
| Per-player persistent world | One DataStore key per player (or a few) | Size grows with edits; cap and compact |
| Shared persistent world | DataStore keys per region | Concurrency: several servers editing the same region need locking or ownership |

Compact deltas regularly: ten digs in one spot can be merged into the resulting voxel state for that chunk, stored as a small binary blob ([[Buffers and Binary Data]]). Keep generator versioning in mind: deltas recorded against generator v3 may not apply cleanly to v4 terrain.

## Far from the origin

Roblox positions are floating point. Community reports on the DevForum describe flickering geometry and less stable physics far from the origin (examples around 15,000 studs and beyond), and there is no official engine fix documented as of October 2026; treat exact thresholds as **unverified** and test your own content. What this means for infinite worlds:

- **Floating origin is hard in multiplayer.** Single-player engines shift the world back to zero around the player. On Roblox, all players share one coordinate space on the server, so you cannot recentre for one player without moving everyone.
- **Bound the playable radius per server.** For example, keep play within some thousands of studs of the origin, and present the rest of the "infinite" world as **regions on other servers**: a player who travels to the edge is teleported into a new server whose origin is at the new region, with the world seed and a region offset in teleport data ([[Teleporting and Multi-Place Games]]). Noise sampled with the region offset keeps the world continuous across the boundary.
- **Keep noise inputs moderate.** Even if positions are fine, large inputs to `math.noise` lose precision. Sample with region-relative coordinates plus a region offset reduced modulo a large period.

## Budgets

Rule-of-thumb starting points, to be replaced by your own measurements:

| Budget | Starting point |
|---|---|
| Server build time per frame | 2 to 5 ms |
| Collision ring ready before arrival | at least 1 second of travel ahead |
| Props per chunk | tens, not hundreds (merge, use terrain detail) |
| Loaded chunks per player at visual radius 6 (64-stud chunks) | about 113 (circle of radius 6) |
| Client memory on low-end phones | test early; see [[Mobile and Low-End Optimization]] |

Measure with the MicroProfiler (labels around generation steps via `debug.profilebegin`/`debug.profileend`) and the developer console's memory view ([[MicroProfiler Guide]], [[Developer Console and Stats]]).

## Testing streamed worlds

- **Spread test.** Ten clients (or bots) walking outward in different directions for 20 minutes. Watch server frame time and memory.
- **Return test.** Walk away and come back. The chunk must be identical (same digest) and deltas must reapply.
- **Teleport test.** Teleport far, confirm the collision ring builds before the player is released.
- **Boundary test.** Stand on a chunk corner and jitter; check that no load and unload loop happens.
- **Shutdown test.** Persisted deltas save on shutdown ([[Saving Correctly - Autosave and BindToClose]]).

See [[Multi-Client and Device Playtesting Protocols]].

## Common mistakes

| Mistake | How it shows | Fix |
|---|---|---|
| Truncating instead of flooring chunk coords | Double-size chunk at origin, seams | `math.floor` |
| No hysteresis | Chunks flicker in and out at boundaries | Unload radius larger than load radius |
| FIFO generation | Player sees holes ahead while behind builds | Priority by distance and travel direction |
| Unload radius below streaming radius | Clients lose terrain they should see | Align with streaming settings |
| Gameplay on client-only geometry | Server validation and NPCs break | Server owns collision |
| Not clearing terrain on unload | Memory never drops | Write Air over the chunk |
| Storing whole chunks for player edits | Huge saves | Seed plus compacted deltas |
| Unbounded coordinates | Jitter and precision bugs far out | Bounded servers, regions via teleport |

## Checklist

- [ ] Infinite justified over a large bounded world.
- [ ] Chunk size a multiple of 4; floored coords; integer keys.
- [ ] Load and unload radii with hysteresis; union over players.
- [ ] Priority by distance and direction; collision ring guaranteed.
- [ ] Server unload radius aligned with streaming settings.
- [ ] Parallel generation with small messages; serial writes small.
- [ ] Unloading frees terrain, instances, connections.
- [ ] Player edits stored as deltas, compacted, versioned.
- [ ] Playable radius bounded per server; regions beyond via teleport.
- [ ] Spread, return, teleport and boundary tests pass.

## See also

- [[Procedural Generation Start Here]], [[Procedural World Generation]], [[Noise Functions and Terrain Generation]]
- [[Instance Streaming]], [[Level of Detail and Model Streaming]], [[Interest Management and Per-Player Replication]]
- [[Parallel Luau and Actors]], [[Physics Performance]], [[Network Performance]]
- [[Genre Playbook - Survival and Crafting]], [[Seeds Determinism and Reproducible Worlds]]

## Connected notes
<!-- auto-links:start -->
[[Deterministic Simulation]] · [[Streaming Radius]] · [[Links - Terrain]] · [[Tilemaps Cameras and Parallax for 2D Levels]] · [[Destruction and Fracture]] · [[Math Vectors and CFrames]]
<!-- auto-links:end -->
