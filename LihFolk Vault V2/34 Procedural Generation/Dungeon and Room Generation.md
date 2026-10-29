---
tags: [procedural, generation, dungeons, roguelike, rooms, graphs, level-design, luau, type/guide, area/procedural, level/intermediate, area/scripting]
---
# Dungeon and Room Generation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Tree-only layouts -> Add 10 to 20 percent loop edges
> - Avoid: Placing content by room index -> Place by BFS depth
> - Avoid: Key behind its own lock -> Remove edge, BFS, place key in the before region
> - Method chosen for the content (graph first if progression matters).
> - Description generated separately from building.
> - Loops added; critical path measured and within targets.
>
> Cost: TL;DR ~140 tok · whole note ~4.4k tok. Read more: ## Grid scatter plus graph: a complete generator · ## Building it in Roblox · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Procedural World Generation]] shows one dungeon method: grow a layout by snapping prefab rooms together at connector attachments, rejecting overlaps. That method is a good default for hand-built room kits. This note covers the rest of the toolbox and, more importantly, what separates a generated dungeon players enjoy from a random maze: graph structure, loops, pacing by distance, locks and keys, validation, and building the result in Roblox without blowing the part budget or breaking pathfinding.

## Pick the method by what you are making

| Method | How it works | Good for | Weak at |
|---|---|---|---|
| Prefab growth (connectors) | Attach rooms at open doors until a target count | Hand-crafted room kits, interiors, space stations | Loops (it grows trees), tight packing |
| Grid scatter plus graph | Place rectangles on a grid, connect with a spanning tree plus extra edges, carve corridors | Classic roguelike floors, top-down dungeons | Organic shapes |
| BSP split | Recursively split a box, a room in each leaf, connect siblings | Dense buildings, offices, bases | Looks regular; few loops |
| Graph first (mission graph) | Generate an abstract graph of encounters (start, key, lock, boss), then embed in space | Designed progression, lock and key puzzles | More code, two stages |
| Cellular automata | Random fill, smooth by neighbour rules | Caves, organic blobs | Control, guaranteed connectivity |
| [[Wave function collapse]] | Tiles constrained by neighbours | Towns, decorated layouts | Global structure; see [[Wave Function Collapse on Roblox]] |

Most good generators **combine** them: a mission graph decides what must exist and in what order, a grid or prefab method places it, and WFC or scatter dresses it.

## Structure before space: why trees feel bad

A spanning tree (every room reachable, no cycles) is the natural output of growth methods. Players experience trees as **dead ends and backtracking**: clear a branch, walk all the way back. Real level designers add loops so players have choices and short returns ([[Level Design for Roblox]]).

Rule of thumb from roguelike practice: after building a minimum spanning tree, add back **10 to 20 percent** of the remaining candidate edges, preferring ones that connect rooms far apart in the tree but close in space. Those shortcuts create loops without turning the floor into a fully connected mesh.

## Grid scatter plus graph: a complete generator

This generator works in tile space (one tile = 8 studs, for example). It produces a **description** (rooms, corridors, a tile grid), not instances; building is a separate step. Keeping them apart lets you test layouts thousands of times per second and swap the visual kit freely.

```lua
--!strict
-- Grid dungeon description: rooms, MST + loops, L-shaped corridors.
export type Room = { x: number, z: number, w: number, h: number, cx: number, cz: number, id: number }
export type Layout = { width: number, height: number, tiles: { number }, rooms: { Room }, edges: { { number } } }

local EMPTY, FLOOR, CORRIDOR = 0, 1, 2

local function overlaps(a: Room, b: Room, pad: number): boolean
	return a.x - pad < b.x + b.w and b.x - pad < a.x + a.w
		and a.z - pad < b.z + b.h and b.z - pad < a.z + a.h
end

local function generate(rng: Random, W: number, H: number, targetRooms: number): Layout
	local rooms: { Room } = {}
	local attempts = 0
	while #rooms < targetRooms and attempts < targetRooms * 30 do
		attempts += 1
		local w, h = rng:NextInteger(4, 9), rng:NextInteger(4, 9)
		local r: Room = { x = rng:NextInteger(2, W - w - 1), z = rng:NextInteger(2, H - h - 1),
			w = w, h = h, cx = 0, cz = 0, id = #rooms + 1 }
		r.cx, r.cz = r.x + w // 2, r.z + h // 2
		local ok = true
		for _, o in rooms do
			if overlaps(r, o, 2) then ok = false break end
		end
		if ok then table.insert(rooms, r) end
	end

	-- Prim's MST on room centres (O(n^2), fine for n < 200)
	local n = #rooms
	local inTree, dist, parent = {}, {}, {}
	for i = 1, n do dist[i] = math.huge end
	dist[1] = 0
	local edges: { { number } } = {}
	for _ = 1, n do
		local best, bi = math.huge, 0
		for i = 1, n do
			if not inTree[i] and dist[i] < best then best, bi = dist[i], i end
		end
		if bi == 0 then break end
		inTree[bi] = true
		if parent[bi] then table.insert(edges, { parent[bi], bi }) end
		for j = 1, n do
			if not inTree[j] then
				local d = math.abs(rooms[bi].cx - rooms[j].cx) + math.abs(rooms[bi].cz - rooms[j].cz)
				if d < dist[j] then dist[j], parent[j] = d, bi end
			end
		end
	end

	-- Loops: add some short non-tree edges back
	local used = {}
	for _, e in edges do used[math.min(e[1], e[2]) * 1000 + math.max(e[1], e[2])] = true end
	for i = 1, n do
		for j = i + 1, n do
			local d = math.abs(rooms[i].cx - rooms[j].cx) + math.abs(rooms[i].cz - rooms[j].cz)
			if not used[i * 1000 + j] and d < 18 and rng:NextNumber() < 0.15 then
				table.insert(edges, { i, j })
				used[i * 1000 + j] = true
			end
		end
	end

	-- Rasterise
	local tiles = table.create(W * H, EMPTY)
	local function set(x: number, z: number, v: number)
		local k = (z - 1) * W + x
		if tiles[k] == EMPTY then tiles[k] = v end
	end
	for _, r in rooms do
		for z = r.z, r.z + r.h - 1 do
			for x = r.x, r.x + r.w - 1 do tiles[(z - 1) * W + x] = FLOOR end
		end
	end
	for _, e in edges do
		local a, b = rooms[e[1]], rooms[e[2]]
		local horizontalFirst = rng:NextNumber() < 0.5
		local x, z = a.cx, a.cz
		local function stepX() while x ~= b.cx do set(x, z, CORRIDOR); x += if b.cx > x then 1 else -1 end end
		local function stepZ() while z ~= b.cz do set(x, z, CORRIDOR); z += if b.cz > z then 1 else -1 end end
		if horizontalFirst then stepX(); stepZ() else stepZ(); stepX() end
		set(x, z, CORRIDOR)
	end

	return { width = W, height = H, tiles = tiles, rooms = rooms, edges = edges }
end

return { generate = generate, EMPTY = EMPTY, FLOOR = FLOOR, CORRIDOR = CORRIDOR }
```

Notes on the choices:

- **Rejection sampling with a cap.** Rooms that overlap are discarded, and the loop stops after `targetRooms * 30` attempts. On a crowded map you get fewer rooms than asked; check `#rooms` and either accept or retry with a different seed. Never loop until success: a bad parameter set hangs the server.
- **Padding of 2 tiles** keeps walls between rooms. Padding 0 makes rooms merge, which can be a style, but breaks "one room, one encounter".
- **Manhattan distance** for the MST suits L-shaped corridors. Euclidean is fine too.
- **Corridors never overwrite rooms** (`set` only writes into empty tiles), so room identity survives.
- **The pair key `i * 1000 + j`** assumes fewer than 1,000 rooms. Fine for floors, wrong for megastructures.

## Pacing: distance is your design tool

Once the layout exists, run a breadth-first search over the room graph from the start room. The **depth** of each room is how far a player must travel, and it drives almost every placement decision:

- **Boss / exit** in the deepest room (or one of the deepest, chosen by hash).
- **Treasure** in dead ends, so dead ends are rewards, not punishments.
- **Difficulty** scales with depth, not with room index.
- **Shop or rest room** around the middle depth.

```lua
--!strict
local function roomDepths(n: number, edges: { { number } }, start: number): { number }
	local adj: { { number } } = table.create(n)
	for i = 1, n do adj[i] = {} end
	for _, e in edges do
		table.insert(adj[e[1]], e[2])
		table.insert(adj[e[2]], e[1])
	end
	local depth = table.create(n, -1)
	depth[start] = 0
	local queue, head = { start }, 1
	while head <= #queue do
		local r = queue[head]; head += 1
		for _, nb in adj[r] do
			if depth[nb] < 0 then
				depth[nb] = depth[r] + 1
				table.insert(queue, nb)
			end
		end
	end
	return depth -- -1 means unreachable: a bug, reject the layout
end
```

Pick the start room as the room nearest one edge of the map, or as one end of the graph's longest shortest path (BFS from any room, take the farthest, BFS again; the two ends are roughly the diameter). That maximises the critical path length.

### Critical path versus total size

Measure two numbers for every generated floor: total rooms and **critical path length** (start to exit depth). A 20-room floor with a critical path of 4 lets players skip most content; one with 15 forces a tour. Set targets per floor (for example critical path between 40 and 60 percent of the room count) and reject layouts outside them. Rejection is cheap when generation is a pure description.

## Locks and keys from the graph

A lock and key puzzle needs one guarantee: **the key is reachable without passing the lock**. With depths and the graph, the safe recipe is:

1. Choose the locked edge: an edge on the critical path in the second half.
2. Remove it temporarily; BFS from start. Everything reached is the "before" region.
3. Place the key in a "before" room, preferably a dead end off the main path at moderate depth.
4. Restore the edge, mark it locked.

For several locks, repeat in order from the exit backward, each time restricting the key search to the region before the new lock. This is the core idea of graph-first ("mission graph") generation: the puzzle is correct by construction, not by hoping.

## Validation: generate, check, retry

Every generator should end with checks that reject bad output:

| Check | Reject when |
|---|---|
| Room count | Fewer than the minimum |
| Reachability | Any room has depth -1 |
| Critical path | Outside the target range |
| Key reachability | Key region contains the lock's far side |
| Encounter space | A combat room is smaller than the arena minimum |
| Spawn safety | Start room adjacent to a high-depth room via a loop |

Retry with a derived seed: `Hash.hash(baseSeed, attempt)`. Because the base seed plus attempt count is deterministic, the final accepted layout is still reproducible. Log the number of attempts; if the average climbs above 2 or 3, your parameters are fighting each other.

## Building it in Roblox

### Part count is the real budget

A 64 x 64 tile floor rasterised one part per tile is up to 4,096 floor parts, plus walls. That is a lot of instances to create, replicate and render. Merge before building:

- **Greedy rectangle merging.** Scan the tile grid; for each unclaimed floor tile, grow right as far as the row allows, then grow down while the whole span matches; emit one part for the rectangle. Typical reduction is 10x to 30x (rule of thumb).
- **Walls as runs.** Emit one wall part per straight run of boundary edges, not per tile.
- **Rooms as prefabs.** If rooms are prefab models, only corridors need merging.

```lua
--!strict
-- Merge tiles equal to `value` into rectangles: returns {x, z, w, h} in tile units.
local function mergeRects(tiles: { number }, W: number, H: number, value: number): { { number } }
	local claimed = table.create(W * H, false)
	local out = {}
	for z = 1, H do
		for x = 1, W do
			local k = (z - 1) * W + x
			if tiles[k] == value and not claimed[k] then
				local w = 1
				while x + w <= W and tiles[k + w] == value and not claimed[k + w] do w += 1 end
				local h = 1
				local grow = true
				while grow and z + h <= H do
					for i = 0, w - 1 do
						local kk = (z + h - 1) * W + x + i
						if tiles[kk] ~= value or claimed[kk] then grow = false break end
					end
					if grow then h += 1 end
				end
				for dz = 0, h - 1 do
					for dx = 0, w - 1 do claimed[(z + dz - 1) * W + x + dx] = true end
				end
				table.insert(out, { x, z, w, h })
			end
		end
	end
	return out
end
```

### Build off-world, then parent once

Create the whole floor under a Model that is **not yet parented** to Workspace, then parent it in one step. Each part parented individually to Workspace triggers replication and physics work separately. Parenting a finished tree replicates it as a unit. For very large floors, spread construction across frames ([[Task Library Coroutines and Yielding]]) but still parent at the end. Anchor everything; generated dungeon geometry should never be simulated.

### Streaming and dungeons

With instance streaming on, a freshly built floor streams to clients around them like any other geometry. Client code that looks up rooms by path will see `nil` for distant rooms; follow [[Instance Streaming]] patterns. For small dungeons where clients need the whole layout (a minimap), send the **description** (room rectangles, a few hundred numbers) through a remote instead of reading instances.

### Pathfinding on generated geometry

`PathfindingService` computes paths over whatever geometry exists when you ask, so generate, parent, then compute NPC paths. Generated corridors are often exactly one tile wide; keep corridor width comfortably above agent radius times two, or NPCs report no path at narrow corners. Doors that open later should use `PathfindingModifier` or be absent from geometry until opened. See [[Pathfinding]] and [[Pathfinding Edge Cases and Fallbacks]].

### Cleanup between runs

Destroy the floor model when the run ends. Anything spawned into it (enemies, drops, effects) should be parented under the floor or tracked, so one `Destroy()` cleans up. Disconnect connections to destroyed parts; see [[Hunting Memory Leaks Step by Step]]. If floors regenerate often, pool common prefabs rather than cloning fresh every time, but measure: pooling adds complexity and Roblox handles moderate clone rates well.

## Prefab growth: deeper rules

If you use the connector method from the older note, these rules prevent most bugs:

- **Typed sockets.** Each connector attachment carries attributes: `Width` (in studs), `Kind` ("Door", "Corridor", "Vent"). Only matching sockets join.
- **Coarse occupancy grid, not physics queries.** Mark each room's footprint in a grid (8 or 16 stud cells) and test new rooms against it. `GetPartBoundsInBox` on geometry you just moved is slower and order-sensitive.
- **Budgeted backtracking.** When no prefab fits an open socket, cap it with a wall prefab. When the whole layout fails its validation, restart with a new derived seed rather than backtracking deep; deep backtracking is where generators stall.
- **Required rooms first.** Place the boss room and key rooms early, at a target depth, then fill around them. Rooms placed last end up wherever there is space, which is rarely where the design wants them.
- **Rotation discipline.** Rotate prefabs only by 90 degree steps and snap pivots to the grid, or tiny float drift accumulates over 30 attachments into visible gaps.

## When not to generate dungeons

- **Short games with one run.** If players see the dungeon once, a hand-built one is better.
- **Story beats.** Scripted moments need fixed geometry. Generate between them, not through them.
- **Competitive fairness.** Ranked modes want identical maps for everyone; use a fixed rotation or a shared daily seed.

Generation pays off when replayability is the core loop ([[Genre Playbook - Combat and RPG]]): roguelikes, extraction runs, daily challenges.

## Common mistakes

| Mistake | How it shows | Fix |
|---|---|---|
| Tree-only layouts | Constant backtracking, dead-end fatigue | Add 10 to 20 percent loop edges |
| Placing content by room index | Boss next to spawn | Place by BFS depth |
| Key behind its own lock | Softlocked runs | Remove edge, BFS, place key in the before region |
| Unbounded retry loops | Server hangs on rare seeds | Cap attempts, derive retry seeds |
| One part per tile | Slow builds, heavy replication | Greedy merge, wall runs |
| Parenting parts one by one | Long hitch at build | Build unparented, parent once |
| Corridors one agent-width wide | NPCs stuck at corners | Wider corridors, validate paths |
| Prefabs picked from `GetChildren()` | Layouts change after a Studio tidy-up | Sorted, explicit prefab list |

## Checklist

- [ ] Method chosen for the content (graph first if progression matters).
- [ ] Description generated separately from building.
- [ ] Loops added; critical path measured and within targets.
- [ ] Content placed by depth; locks and keys correct by construction.
- [ ] Validation rejects bad layouts; retries capped and seeded.
- [ ] Geometry merged; built unparented and parented once; anchored.
- [ ] Paths validated for NPCs; streaming-safe client code.
- [ ] One `Destroy()` cleans the whole run.

## See also

- [[Procedural Generation Start Here]], [[Procedural World Generation]], [[Wave Function Collapse on Roblox]]
- [[Seeds Determinism and Reproducible Worlds]], [[Procedural Loot and Item Generation]]
- [[Level Design for Roblox]], [[Modular Environment Kits]], [[Grid Placement and Player Building Systems]]
- [[Pathfinding]], [[NPC AI and Behaviour]], [[Boss Fight Design Patterns]], [[Spawning Teams and Rounds]]

## Connected notes
<!-- auto-links:start -->
[[Deterministic Simulation]] · Genre Playbook - Puzzle and Escape Rooms · Combat Arena and Encounter Layout · [[Noise Functions and Terrain Generation]] · Voxel Props Environments and Modular Tiles · Tilemaps Cameras and Parallax for 2D Levels
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Infinite and Streamed Worlds]] · [[Voxel Props Environments and Modular Tiles]] · [[Combat Arena and Encounter Layout]] · [[Puzzle Dependency Charts and Hint Systems]] · [[Genre Playbook - Puzzle and Escape Rooms]] · [[Tilemaps Cameras and Parallax for 2D Levels]]
<!-- related:end -->
