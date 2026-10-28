---
tags: [procedural, generation, wfc, wave-function-collapse, tiles, constraints, luau]
---
# Wave Function Collapse on Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Missing filler tile for a socket -> Add a straight-through or filler tile
> - Avoid: Duplicate rotations kept -> Dedupe rotations by socket signature
> - Avoid: Asymmetric sockets matched as equal -> Directed socket pairs
> - Sockets named by what crosses the edge; asymmetric ones directed.
> - Every socket has a filler tile; tile count fits the solver.
> - Rotations generated and deduplicated.
>
> Read more (19 KB note): ## Designing a tile set · ## A complete solver in strict Luau · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Wave function collapse (WFC) is a constraint solver dressed up with a physics name. You give it a set of tiles and rules about which tiles may sit next to which; it fills a grid so every rule holds. It is excellent at **local coherence** (roads connect, walls meet, rivers flow into rivers) and poor at **global structure** (a town with a centre, a dungeon with a boss at the end). This note explains the algorithm, gives a complete strict Luau implementation with bitmask domains, and covers the Roblox-specific parts: tile kits, rotations, performance, combining it with other generators, and when it is the wrong tool. It assumes the seed discipline of [[Seeds Determinism and Reproducible Worlds]].

## The algorithm in plain terms

Every grid cell starts with a **domain**: the set of tiles it could still be. Then repeat:

1. **Observe.** Pick the undecided cell with the fewest options (lowest entropy). Ties broken randomly.
2. **Collapse.** Choose one tile for it, randomly, weighted by tile weights.
3. **Propagate.** That choice removes options from its neighbours (only tiles compatible with it remain). Any neighbour that lost options may remove options from its own neighbours, and so on until nothing changes.
4. If some cell's domain becomes **empty**, that is a **contradiction**: this attempt failed.

Stop when every cell has exactly one tile. Picking the most constrained cell first is what makes WFC work well: it resolves the hard spots while there is still freedom elsewhere.

There are two flavours:

- **Simple tiled model**: you author tiles and adjacency rules (sockets). This is what most games use and what this note implements.
- **Overlapping model**: the rules are learned from an example image by sliding an N x N window. Powerful for 2D textures, rarely worth it for 3D Roblox kits.

## Designing a tile set

The tile set is 90 percent of the work. Each tile has four **sockets**, one per side, and two tiles may be neighbours when their facing sockets match.

```
          N: "road"
        +-----------+
W:"grass"|  road    |E:"grass"
        |  straight |
        +-----------+
          S: "road"
```

Socket design rules:

- **Name sockets by what crosses the edge**, not by tile: `grass`, `road`, `wall`, `water`, `cliffTop`. Every tile that shows a road leaving its north edge uses `road` on its north socket.
- **Asymmetric edges need direction.** A cliff edge with high ground on the left differs from one with high ground on the right. Encode as `cliff_a` and `cliff_b`, and make `cliff_a` match `cliff_b` (not itself). The simple version below matches equal strings; for asymmetric sockets, add an explicit compatibility table.
- **Every socket type needs at least one filler tile.** If no tile has `grass` on all four sides, a grass region cannot grow, and contradictions explode.
- **Keep the tile count small.** Under 32 tiles after rotation fits a single 32-bit mask, which keeps the solver fast. Big kits can be split into layers (ground layer, then props layer).

### Weights decide the look

Weights are how often a tile is chosen when it is allowed. Grass at 20, road straight at 3, road corner at 2, crossroads at 0.3 gives a mostly green map with occasional long roads. The same rules with grass at 1 give a dense maze of streets. Tune weights before you touch rules.

### Rotations

Author one tile and generate its 90, 180 and 270 degree rotations automatically. Rotating clockwise by 90 degrees moves sockets: new north = old west, new east = old north, new south = old east, new west = old south. Skip duplicate rotations (a crossroads is the same at every angle, a straight road has only two distinct rotations), or the duplicates silently multiply that tile's weight.

## A complete solver in strict Luau

Domains are bitmasks (one bit per tile), so "remove incompatible options" is a single `bit32.band`. This limits the set to 32 tiles; for more, use arrays of masks.

```lua
--!strict
-- Simple tiled WFC on a W x H grid with bitmask domains (max 32 tiles).
export type Tile = { name: string, weight: number, sockets: { string }, rotation: number }

local WFC = {}

-- Directions: 1 = north (-Z), 2 = east (+X), 3 = south (+Z), 4 = west (-X)
local DX = { 0, 1, 0, -1 }
local DZ = { -1, 0, 1, 0 }
local function opposite(d: number): number
	return (d + 1) % 4 + 1
end

-- Expand base tiles into their distinct rotations.
function WFC.withRotations(base: { Tile }): { Tile }
	local out: { Tile } = {}
	for _, t in base do
		local seen: { [string]: boolean } = {}
		local s = t.sockets
		for r = 0, 3 do
			local key = table.concat(s, "|")
			if not seen[key] then
				seen[key] = true
				table.insert(out, { name = t.name, weight = t.weight, sockets = s, rotation = r })
			end
			s = { s[4], s[1], s[2], s[3] } -- rotate 90 degrees clockwise
		end
	end
	assert(#out <= 32, "bitmask solver supports at most 32 tiles")
	return out
end

local function popcount(m: number): number
	local c = 0
	while m ~= 0 do
		m = bit32.band(m, m - 1)
		c += 1
	end
	return c
end

-- compat[d][t] = mask of tiles allowed in direction d of tile t
local function buildCompat(tiles: { Tile }): { { number } }
	local compat = {}
	for d = 1, 4 do
		compat[d] = {}
		for t = 1, #tiles do
			local m = 0
			for u = 1, #tiles do
				if tiles[t].sockets[d] == tiles[u].sockets[opposite(d)] then
					m = bit32.bor(m, bit32.lshift(1, u - 1))
				end
			end
			compat[d][t] = m
		end
	end
	return compat
end

-- One attempt. `fixed` pre-collapses cells: { [cellIndex] = mask }.
-- Returns an array of tile indices, or nil on contradiction.
local function attempt(tiles: { Tile }, compat: { { number } }, W: number, H: number,
	rng: Random, fixed: { [number]: number }?): { number }?
	local n = #tiles
	local all = if n == 32 then 0xFFFFFFFF else bit32.lshift(1, n) - 1
	local domain = table.create(W * H, all)
	local stack: { number } = {}

	local function propagate(): boolean
		while #stack > 0 do
			local c = table.remove(stack) :: number
			local cx, cz = (c - 1) % W + 1, (c - 1) // W + 1
			local dom = domain[c]
			for d = 1, 4 do
				local nx, nz = cx + DX[d], cz + DZ[d]
				if nx >= 1 and nx <= W and nz >= 1 and nz <= H then
					-- union of everything any remaining tile in c allows on side d
					local allowed = 0
					local m = dom
					while m ~= 0 do
						local low = bit32.band(m, -m % 4294967296) -- lowest set bit
						local t = bit32.countrz(low) + 1
						allowed = bit32.bor(allowed, compat[d][t])
						m = bit32.bxor(m, low)
					end
					local ni = (nz - 1) * W + nx
					local nd = bit32.band(domain[ni], allowed)
					if nd ~= domain[ni] then
						if nd == 0 then return false end
						domain[ni] = nd
						table.insert(stack, ni)
					end
				end
			end
		end
		return true
	end

	if fixed then
		for idx, mask in fixed do
			domain[idx] = bit32.band(domain[idx], mask)
			if domain[idx] == 0 then return nil end
			table.insert(stack, idx)
		end
		if not propagate() then return nil end
	end

	while true do
		-- observe: lowest option count, random tie-break
		local bestCell, bestScore = 0, math.huge
		for i = 1, W * H do
			local c = popcount(domain[i])
			if c > 1 then
				local score = c + rng:NextNumber() * 0.5
				if score < bestScore then bestCell, bestScore = i, score end
			end
		end
		if bestCell == 0 then break end -- everything collapsed

		-- collapse: weighted pick among remaining tiles
		local dom, total = domain[bestCell], 0
		for t = 1, n do
			if bit32.btest(dom, bit32.lshift(1, t - 1)) then total += tiles[t].weight end
		end
		local roll, pick = rng:NextNumber() * total, 0
		for t = 1, n do
			if bit32.btest(dom, bit32.lshift(1, t - 1)) then
				pick = t
				roll -= tiles[t].weight
				if roll <= 0 then break end
			end
		end
		domain[bestCell] = bit32.lshift(1, pick - 1)
		table.insert(stack, bestCell)
		if not propagate() then return nil end
	end

	local result = table.create(W * H, 0)
	for i = 1, W * H do
		result[i] = bit32.countrz(domain[i]) + 1
	end
	return result
end

function WFC.solve(tiles: { Tile }, W: number, H: number, seed: number, maxAttempts: number,
	fixed: { [number]: number }?): ({ number }?, number)
	local compat = buildCompat(tiles)
	for a = 1, maxAttempts do
		local result = attempt(tiles, compat, W, H, Random.new(seed + a * 7919), fixed)
		if result then return result, a end
	end
	return nil, maxAttempts
end

return WFC
```

Implementation notes:

- **`bit32.countrz`** returns the number of trailing zero bits, which turns a single-bit mask into a tile index. `bit32.band(m, -m % 2^32)` isolates the lowest set bit (two's complement trick, made unsigned with modulo).
- **`bit32.btest`** returns true if the AND of its arguments is non-zero.
- **Observation is O(cells) per step**, so the whole solve is O(cells squared) in the worst case. For grids up to about 40 x 40 that is fine. For larger grids, keep undecided cells in buckets by option count, or solve in chunks (below).
- **Count-based entropy** is a simplification. True Shannon entropy with weights (`log(sum w) - sum(w log w) / sum w`) picks better cells when weights are very uneven. Count plus small noise is good enough for most kits.
- **Retry seeds are derived**, so the accepted result is reproducible from `seed`.

### A minimal tile set to test with

```lua
local base = {
	{ name = "Grass",    weight = 12, sockets = { "g", "g", "g", "g" }, rotation = 0 },
	{ name = "Straight", weight = 3,  sockets = { "r", "g", "r", "g" }, rotation = 0 },
	{ name = "Corner",   weight = 2,  sockets = { "r", "r", "g", "g" }, rotation = 0 },
	{ name = "T",        weight = 0.6, sockets = { "r", "r", "g", "r" }, rotation = 0 },
	{ name = "Cross",    weight = 0.2, sockets = { "r", "r", "r", "r" }, rotation = 0 },
	{ name = "DeadEnd",  weight = 0.4, sockets = { "r", "g", "g", "g" }, rotation = 0 },
}
local tiles = WFC.withRotations(base) -- 1 + 2 + 4 + 4 + 1 + 4 = 16 tiles
local grid, attempts = WFC.solve(tiles, 24, 24, 9001, 20)
```

This kit should rarely if ever contradict (grass fits next to grass anywhere and every road end has a dead end to close it), which makes it a good first test; if it contradicts often, suspect a bug in your sockets or rotation code. Real kits with cliffs, water and elevation will contradict sometimes; that is normal.

## Contradictions: why they happen and what to do

Contradictions mean the solver painted itself into a corner. They become frequent when:

- A socket type has **too few tiles** (especially no "straight through" or "filler" for that socket).
- **Fixed cells** constrain incompatibly (two pre-placed roads that cannot be joined within the gap).
- **Tiles encode long-range structure** (a 3-tile-wide building made of edge pieces) that local rules cannot plan for.

Responses, from simplest:

1. **Restart** with a derived seed. Fine when the contradiction rate is under about 10 to 20 percent (rule of thumb). Log the rate.
2. **Add tiles.** A contradiction rate that will not go down usually means a missing transition tile. Look at where contradictions happen (record the cell) and design the tile that would have fitted.
3. **Backtrack.** Save domain snapshots before each collapse and roll back on failure. Correct but memory-heavy and slow on big grids; rarely needed if the kit is good.
4. **Solve in chunks with local restarts.** Solve 16 x 16 blocks; if one fails, reset only that block (and maybe a 1-cell ring) and retry it. This is also the way to make WFC scale to large or infinite maps (see [[Infinite and Streamed Worlds]]): the boundary cells of already-solved neighbours become fixed cells for the new block.

## Global structure: constrain, do not hope

WFC alone makes "everywhere looks plausible, nowhere looks designed". Fix it by deciding structure first and handing it to WFC as fixed cells:

- **Paths first.** Generate a main road with a graph or random walk ([[Dungeon and Room Generation]]), stamp road tiles along it as fixed cells, let WFC fill the rest. Now there is always a through route.
- **Borders.** Fix the outer ring to "edge" or "wall" tiles so the map closes cleanly.
- **Landmarks.** Reserve a 3 x 3 area for a hand-built plaza by fixing its cells to a special "reserved" tile whose sockets match the plaza's surroundings.
- **Masks from noise.** A low-frequency noise decides "water region" versus "land region"; cells in water are restricted to water and shore tiles before solving. This is how to get large lakes instead of WFC's natural tendency toward many small ponds.
- **Weight fields.** Vary tile weights by position (more buildings near the centre). The solver above uses global weights; making `weight` a function of cell index is a small change.

## Debugging a tile set

When the output looks wrong but never contradicts, the solver is usually fine and the kit is not. Three quick tools:

- **Render the grid as coloured cells first.** Before building prefabs, draw each tile as a flat part coloured by tile name with a small arrow for rotation. Socket mistakes are obvious in seconds, and you avoid blaming the 3D kit for a rules problem.
- **Print the compatibility table.** For each tile and direction, list the tiles allowed next to it. A tile with an empty list in any direction can only exist at the map border; a tile allowed next to everything usually has a typo in a socket name.
- **Histogram the result.** Count tiles over a hundred solves and compare with what the weights suggest. Propagation skews frequencies (heavily constrained tiles appear less than their weight implies), so expect differences; large ones point to a tile that is rarely legal and probably needs a companion piece.

## Going 3D

Voxel WFC (towers, multi-level structures) adds up and down sockets: six directions instead of four. The solver generalises directly (six offsets, six compat tables). Two warnings:

- **Rotations only around the vertical axis** for most kits; up and down sockets rotate with the tile's horizontal symmetry.
- **The cell count grows fast.** 20 x 20 x 8 is 3,200 cells; with the naive observation loop, solve time grows with the square. Use buckets and chunked solving.

## Building the result in Roblox

The solver outputs tile indices. Building means placing prefab models at grid positions with the right rotation:

```lua
--!strict
local TILE = 16 -- studs per tile

local function build(grid: { number }, tiles: { { name: string, rotation: number } },
	W: number, H: number, kit: Folder, origin: CFrame): Model
	local root = Instance.new("Model")
	root.Name = "WFCMap"
	for z = 1, H do
		for x = 1, W do
			local t = tiles[grid[(z - 1) * W + x]]
			local prefab = kit:FindFirstChild(t.name)
			if prefab and prefab:IsA("Model") then
				local m = prefab:Clone()
				local pos = Vector3.new((x - 1) * TILE, 0, (z - 1) * TILE)
				-- clockwise when viewed from above = negative rotation about +Y
				m:PivotTo(origin * CFrame.new(pos) * CFrame.Angles(0, -t.rotation * math.pi / 2, 0))
				m.Parent = root
			end
		end
	end
	return root -- parent once, after it is complete
end
```

Kit authoring rules that save hours:

- **Pivot at the tile centre**, floor at Y = 0, every prefab exactly `TILE` studs wide. A prefab off by 0.1 studs leaves visible seams over 30 tiles.
- **Author the unrotated version facing the convention** (north = -Z). Test the rotation sign once with an asymmetric tile (the corner) before building the whole kit; a wrong sign mirrors every corner and the roads no longer connect visually even though the solver is happy.
- **Merge or package.** Hundreds of cloned prefabs is fine; tens of thousands is not. Keep prefabs light, use [[Packages and Asset Reuse]] for the kit, and consider merging static ground tiles as in the dungeon note.
- **Collision.** Use simple collision on tile geometry ([[Collision and Physics Geometry]]); WFC maps cover large areas, and precise collision on every piece adds up.

## Performance notes

- Solve at **edit time** when possible: generate in Studio from the command bar or a plugin, review, hand-fix, save. The runtime cost is then zero ([[Command Bar and Studio Scripting]]).
- At runtime, a 32 x 32 solve with the solver above is light work for a server, but yield between attempts (`task.wait()`) and cap attempts. Measure on your kit; contradiction-heavy kits cost many attempts.
- The solver is pure computation with no Instance access, so it can run in an Actor with Parallel Luau ([[Parallel Luau and Actors]]); build instances back in serial.

## When WFC is the wrong tool

| Want | Better tool |
|---|---|
| A guaranteed path from A to B | Graph or random walk first, WFC to decorate |
| Rooms of specific sizes | Grid scatter or BSP ([[Dungeon and Room Generation]]) |
| Natural terrain | Noise ([[Noise Functions and Terrain Generation]]) |
| Even prop distribution | Poisson scatter ([[Foliage Props and Scatter]]) |
| Few large, distinctive set pieces | Hand placement |

WFC shines for towns, road networks, coastlines, interior decoration, dungeon dressing, pipe and cable layouts, and anywhere "every edge must connect" is the main rule.

## Common mistakes

| Mistake | How it shows | Fix |
|---|---|---|
| Missing filler tile for a socket | High contradiction rate in one area type | Add a straight-through or filler tile |
| Duplicate rotations kept | One symmetric tile dominates | Dedupe rotations by socket signature |
| Asymmetric sockets matched as equal | Cliffs face the wrong way | Directed socket pairs |
| Wrong rotation sign in the builder | Roads visually disconnected at corners | Test with the corner tile first |
| No global constraints | Pleasant noise with no structure | Fix paths, borders, landmarks first |
| Unbounded restarts | Rare seeds hang generation | Cap attempts; log contradiction rate |
| O(cells^2) observe on huge grids | Solve time explodes with size | Buckets or chunked solving |

## Checklist

- [ ] Sockets named by what crosses the edge; asymmetric ones directed.
- [ ] Every socket has a filler tile; tile count fits the solver.
- [ ] Rotations generated and deduplicated.
- [ ] Weights tuned before rules.
- [ ] Global structure fixed before solving.
- [ ] Contradiction rate measured; attempts capped and seeded.
- [ ] Prefabs pivoted at centre, exact size, rotation sign tested.
- [ ] Built unparented, parented once; solved at edit time where possible.

## See also

- [[Procedural Generation Start Here]], [[Procedural World Generation]]
- [[Dungeon and Room Generation]], [[Infinite and Streamed Worlds]], [[Seeds Determinism and Reproducible Worlds]]
- [[Modular Environment Kits]], [[Grid Placement and Player Building Systems]], [[Level Design for Roblox]]
- [[Luau Performance Patterns with Benchmarks]], [[Batch Processing Tools in Studio]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Props Environments and Modular Tiles]] · [[Deterministic Simulation]] · [[Voxel Scale Grids and Stud Alignment]] · [[Level Design Principles - Flow Sightlines and Landmarks]] · [[Tilemaps Cameras and Parallax for 2D Levels]] · [[Terrain Tools and Terrain API]]
<!-- auto-links:end -->
