---
tags: [modeling, voxel, environment, props, modular, tiles, autotiling, kits, instancing, streaming, luau]
---
# Voxel Props Environments and Modular Tiles

<!-- tldr:start -->
> [!tldr] TL;DR
> - Visible seams or half-flowers at tile boundaries: Decoration on edge cells -> Keep decoration one cell inside the footprint
> - Auto-placed tiles offset by half a cell: Odd cell counts with centre pivots, or overhanging voxels changing... -> Even cell counts, decoration inside the footprint...
> - Some corners always face the wrong way: Canonical piece modelled in the wrong orientation -> Rotate the source piece once to match the canonical table
> - Tile size agrees with terrain and the environment voxel grain; even cell counts.
> - Edge profile table written before building pieces.
> - Decoration one cell inside the footprint; AO self-only.
>
> Cost: TL;DR ~200 tok · whole note ~4.2k tok. Read more: ## 3. Autotiling: picking edge and corner pieces automatically · ## 6. Cost of a tiled voxel world · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Characters get the attention, but in a blocky game most of the triangles, instances and art hours go into the world: ground, cliffs, paths, buildings, trees, fences, crates, lamps. Building that world voxel by voxel does not scale. What scales is a small set of tiles and props, built on one grid, that snap together and repeat hundreds of times without the repetition showing. [[Modular Environment Kits]] covers modular kits in general and [[Grid Placement and Player Building Systems]] covers grid placement code. This note is the voxel-specific version: tile sizes that agree with Roblox's own grids, edge rules that make tiles join seamlessly, autotiling (choosing the right edge or corner piece automatically), variation without new assets, prop design at environment scale, and the instance, memory and streaming costs of a tiled voxel world.

## 1. Tile size: agree with the grids you already have

From [[Voxel Scale Grids and Stud Alignment]]: terrain cells are 4 studs, a sensible environment voxel is 0.5 studs, and every grain should divide the largest. So the natural voxel tile sizes are:

| Tile | Cells at 0.5 studs | Use (rule of thumb) |
|---|---|---|
| 4 x 4 studs | 8 x 8 | Ground and path tiles, cliff faces, fence sections; matches terrain cells |
| 8 x 8 studs | 16 x 16 | Building floors and walls, large ground variants; fewer instances |
| 2 x 2 studs | 4 x 4 | Trim pieces, steps, small edging; avoid for ground, too many instances |
| Height step | 1 stud (2 cells) or 2 studs (4 cells) | Terrace heights; a character steps up 1-stud ledges far more smoothly than 2 |

A tile must be **exactly** its nominal size, voxel for voxel. A grass tile with three blades poking one cell over its edge is no longer 8 cells wide; its bounding box is wrong, auto-placement scripts misplace it, and the overhang z-fights with the neighbour. Keep decoration inside the footprint, or make overhangs separate props.

**Pivot**: bottom centre for tiles that are rotated by autotiling (they rotate in place); bottom corner only for tiles that never rotate. Tiles should have even cell counts so the centre sits on a grid line.

## 2. Edge rules: how tiles join seamlessly

Two tiles placed side by side join cleanly only if their touching edges agree. For voxel tiles that means:

1. **Matching edge profiles.** The column of cells along each edge (height and colour) must be one of a small number of defined profiles, for example "flat grass at height 1", "cliff top", "cliff face". Any two edges with the same profile can touch.
2. **Edge colours from the base ramp only.** Decoration (flowers, stones, cracks) stays at least one cell in from the edge. If a flower sits on the boundary, half a flower appears next to a tile that does not continue it.
3. **No AO baked across edges.** Baked ambient occlusion from [[Voxel Shading - Baked AO Edges and Lighting]] must only include self-occlusion inside the tile. Contact shadows against neighbours belong to the neighbour combination, not to the tile.
4. **Same lighting on both sides.** Palette steps in a tile (a lit edge on a cliff top, a shadow step at the base) must be the same on every tile that shares that profile.

Write the edge profiles down as a small table before building any tiles; it is the contract every artist and every script works to.

## 3. Autotiling: picking edge and corner pieces automatically

Painting a cliff top by hand, choosing an edge piece here and a corner piece there, is slow and error-prone. Autotiling computes each tile's piece from its neighbours.

**The 4-neighbour version** (often called 16-tile or marching-squares-style autotiling): for each filled grid cell, look at its four neighbours (north, east, south, west). Each neighbour is filled or not, giving a 4-bit mask from 0 to 15. Using rotation, those 16 cases reduce to **six unique pieces**:

| Piece | Neighbours filled | Canonical mask (N=1, E=2, S=4, W=8) |
|---|---|---|
| Isolated | none | 0 |
| End | one | 1 (north) |
| Corner | two adjacent | 3 (north and east) |
| Straight | two opposite | 5 (north and south) |
| Tee (edge) | three | 7 (north, east, south) |
| Fill | four | 15 |

**The 8-neighbour version** (the "blob" set) also checks diagonals, so it can draw inner corners where a plateau has a notch. It needs up to 47 unique cases, which reduce by rotation to about a dozen pieces. Use the 4-neighbour set first; add inner-corner pieces only when the art direction calls for crisp inside corners.

A Luau autotiler for the 4-neighbour set:

```lua
--!strict
-- 4-neighbour autotiler. Grid cells are keyed "x,z"; each filled cell gets a piece and a rotation.
-- Pieces are Models in a folder, built in canonical orientation (see table), pivot at bottom centre.
local TILE = 4 -- studs per tile

type Placement = { piece: string, turns: number } -- turns = 90-degree clockwise steps seen from above

-- Canonical masks: N=1, E=2, S=4, W=8. North is -Z, east is +X.
local CANONICAL: { [string]: number } = {
	Isolated = 0, End = 1, Corner = 3, Straight = 5, Tee = 7, Fill = 15,
}

local function rotateMask(m: number): number
	-- One clockwise step: N->E, E->S, S->W, W->N.
	return bit32.band(bit32.bor(bit32.lshift(m, 1), bit32.rshift(m, 3)), 15)
end

-- Build the lookup once: every mask 0..15 maps to a canonical piece and a rotation.
local LOOKUP: { [number]: Placement } = {}
for piece, mask in CANONICAL do
	local m = mask
	for turns = 0, 3 do
		if LOOKUP[m] == nil then
			LOOKUP[m] = { piece = piece, turns = turns }
		end
		m = rotateMask(m)
	end
end

local function key(x: number, z: number): string
	return `{x},{z}`
end

local function placeTiles(filled: { [string]: boolean }, cells: { Vector2 }, pieces: Folder, origin: CFrame, parent: Instance)
	for _, c in cells do
		local x, z = c.X, c.Y
		local mask = 0
		if filled[key(x, z - 1)] then mask += 1 end -- north
		if filled[key(x + 1, z)] then mask += 2 end -- east
		if filled[key(x, z + 1)] then mask += 4 end -- south
		if filled[key(x - 1, z)] then mask += 8 end -- west
		local placement = LOOKUP[mask]
		local template = pieces:FindFirstChild(placement.piece) :: Model?
		assert(template, `missing tile piece {placement.piece}`)
		local tile = template:Clone()
		-- Clockwise seen from above is a negative rotation about +Y.
		local cf = origin * CFrame.new(x * TILE, 0, z * TILE) * CFrame.Angles(0, -placement.turns * math.pi / 2, 0)
		tile:PivotTo(cf)
		tile.Parent = parent
	end
end

return { placeTiles = placeTiles, LOOKUP = LOOKUP }
```

Why the canonical masks work: rotating the Corner mask 3 (north and east) one step clockwise gives 6 (east and south), then 12 (south and west), then 9 (west and north): all four corner orientations. Straight (5) gives 10 and back to 5, so only two of its rotations are distinct, and the lookup keeps the first one found. Every mask from 0 to 15 is reached by exactly one of the six pieces.

**Build each canonical piece to the table**: the End piece's open (connected) side faces north (-Z), the Corner connects north and east, and so on. If one piece is modelled facing the wrong way, every instance of it is wrong in the same way, which is easy to spot and fix by rotating the source model once.

## 4. Variation without new assets

A field of identical 4-stud grass tiles shows its grid at once. Ways to break repetition, cheapest first:

- **Random 90-degree rotation of Fill tiles.** Only for tiles whose four edges share one profile; free.
- **Two to four Fill variants** with different decoration placement (flowers in different cells), chosen by a seeded hash of the tile's coordinates so the same map always looks the same. Use a hash, not `math.random`, so layouts are reproducible: `bit32.bxor(x * 73856093, z * 19349663) % variantCount` is enough (Luau has no `~` xor operator, so use `bit32.bxor`, and keep x and z non-negative).
- **Colour variation by tile**: shift `Color` on the grass MeshPart of each tile by one palette step on a low-frequency noise (`math.noise(x * 0.15, z * 0.15)`), giving broad patches of lighter and darker grass. Keep the shift within the ramp, or tiles stop matching at edges.
- **Props on top**: scatter rocks, flowers and grass tufts as separate small props, off grid and rotated freely ([[Foliage Props and Scatter]]). Props break the grid far more effectively than tile variants.
- **Height variation**: terraced tiles at 1-stud steps.

How many variants is enough: 3 Fill variants plus rotation gives 12 visual combinations; at 4-stud tiles a player at 40 studs sees roughly 20 to 40 tiles in view and will rarely notice the repeat if props sit on top (rule of thumb).

## 5. Props at environment scale

Environment props are seen from further away and in larger numbers than characters, so they follow coarser rules:

| Prop | Cell size | Cells | Triangles after greedy meshing (rule of thumb) |
|---|---|---|---|
| Crate, barrel, sign | 0.25 to 0.5 | 4 to 12 per side | 50 to 300 |
| Fence section (4 studs) | 0.25 | 16 long | 100 to 300 |
| Lamp post | 0.25 | 8 x 8 x 40 | 300 to 600 |
| Tree, small | 0.5 | 8 to 12 across, 16 to 24 tall | 300 to 900 |
| Tree, large landmark | 0.5 | 24 across, 40 tall | 1,000 to 3,000 |
| House | 0.5 | 24 x 20 x 24 | 1,500 to 4,000 |

Design rules for voxel props (rules of thumb):

- **Silhouette at 40 to 80 studs** matters more than surface detail. A tree's canopy should be lumpy (two or three stepped blobs), not a cube, or it reads as a block.
- **Three or four colours per prop.** Props share zone ramps from [[Voxel Palettes - Ramps Hue Shifting and Limits]]; a prop with its own unique greens never quite belongs.
- **Reuse parts across props.** One voxel trunk serves three tree canopies; one plank piece builds crates, fences and signs. Identical meshes share memory.
- **Collision separate and simple**: a box for a crate, a cylinder-ish box stack for a trunk, nothing for leaves.

The vault's [[Low-Poly Tree Set Worked Example]] builds a procedural low-poly tree set in Blender; the same scripted approach (trunk, canopy blobs, palette ramps) works for voxel trees if you voxelise the blobs instead of using icospheres.

## 6. Cost of a tiled voxel world

**Instance count.** A 256 x 256 stud area of 4-stud tiles is 64 x 64 = 4,096 tiles. At one MeshPart per colour group and three colour groups per tile, that is over 12,000 instances before props. That is heavy for mid-range phones (see [[Art Budgets - Triangles Draw Calls Memory]] for budgets). Three ways down:

1. **Bigger tiles for interiors.** Fill regions of a plateau with 8 or 16 stud Fill tiles; use 4-stud tiles only at edges. A plateau that is mostly interior drops by a factor of 4 to 16.
2. **Bake chunks.** For ground that never changes, merge each 32 x 32 stud chunk of placed tiles into a few per-colour meshes in Blender after the layout is final. You trade reuse (each chunk is unique geometry and memory) for far fewer instances. Do this late; it freezes the layout.
3. **Use Terrain for the bulk** and voxel meshes for the edges, paths and features players notice. Roblox Terrain is itself a 4-stud voxel grid, and a flat-shaded terrain material palette can sit comfortably next to blocky art ([[Terrain Tools and Terrain API]]).

**Memory and instancing.** Many copies of the same MeshPart (same mesh and material) share the mesh asset in memory, and the engine can batch identical meshes into fewer draw calls (see [[Rendering Performance]]). A tiled world with 20 unique tiles placed 4,000 times uses the mesh memory of 20 tiles. Baked unique chunks lose that. Keep tiles reusable for as long as possible.

**Streaming.** With instance streaming on, the server sends parts of the world near each player. Grouping tiles into chunk Models, with `ModelStreamingMode` set appropriately, keeps a chunk streaming in as one unit rather than tile by tile, which avoids holes in the ground while a chunk is half-loaded. See [[Instance Streaming]] and [[Level of Detail and Model Streaming]].

## 7. Worked example: a small cliff-and-path kit

Goal: a forest zone kit with grass plateaus, cliffs one tile high, and a dirt path, all autotiled.

1. **Decide grid**: 4-stud tiles, 0.5-stud cells (8 x 8 cells per tile), cliff height 4 studs (8 cells), path inset one cell below grass.
2. **Write edge profiles**: Grass-flat, Cliff-top (grass with a one-cell lit lip), Cliff-face (stone ramp, one-cell dark base), Path-flat.
3. **Build the six cliff pieces** in MagicaVoxel in canonical orientation (Isolated, End, Corner, Straight, Tee, Fill). The Fill is a plain grass top; the others show cliff faces on their unconnected sides. Build three Fill variants with flowers placed at least one cell from the edges.
4. **Build the six path pieces** the same way; paths only change the top layer, so they are thin tiles that sit on grass Fill.
5. **Mesh greedy, one mesh per colour, cell-unit UVs** ([[Meshing Voxels for Roblox - Greedy Meshing and Export]]), self-occlusion AO only, pivots at bottom centre. Export GLB, import with Scale Unit Studs.
6. **Store the pieces** in a folder in ReplicatedStorage, named exactly as the autotiler expects.
7. **Paint the layout** as a set of filled cells (from a simple editor plugin, a spreadsheet or a heightmap), run the autotiler, then run it again for the path layer on top.
8. **Scatter props**: trees, rocks, tufts, off grid, seeded by coordinates.
9. **Check counts**: instances in the zone, triangles in view from the spawn point, and walk the cliffs with a character to confirm colliders follow the tiles.
10. **Review from the gameplay camera on a phone**: if the grid reads from 60 studs, add a Fill variant or more props, not more detail on the tiles.

## 8. When not to tile

- **Hero landmarks** (a giant tree, a castle) should be unique models; tiling them makes them look generic.
- **Organic shapes at large scale** (rolling hills) look stepped and repetitive with 4-stud tiles; use Terrain or larger custom pieces.
- **Small one-off scenes** (a single shop interior) are faster to build directly than to design a kit for.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Visible seams or half-flowers at tile boundaries | Decoration on edge cells | Keep decoration one cell inside the footprint |
| Auto-placed tiles offset by half a cell | Odd cell counts with centre pivots, or overhanging voxels changing the bounding box | Even cell counts, decoration inside the footprint, pivots at bottom centre |
| Some corners always face the wrong way | Canonical piece modelled in the wrong orientation | Rotate the source piece once to match the canonical table |
| Ground grid obvious from far away | One Fill variant, no props | Three variants, seeded rotation, scattered props, broad colour patches |
| Dark smudges where tiles meet | AO baked against assumed neighbours | Self-occlusion only in tile bakes |
| Phones struggle in big open areas | Thousands of small tile instances | Bigger interior tiles, chunk baking late, Terrain for bulk |
| Holes in the ground while players move | Tiles streaming in individually | Group tiles into chunk Models with suitable streaming settings |

## Checklist

- [ ] Tile size agrees with terrain and the environment voxel grain; even cell counts.
- [ ] Edge profile table written before building pieces.
- [ ] Decoration one cell inside the footprint; AO self-only.
- [ ] Six canonical pieces per autotiled surface, built in the documented orientation.
- [ ] Variation from rotation, Fill variants, coordinate-seeded colour shifts and props.
- [ ] Instance count measured; interior tiles enlarged or chunks baked if needed.
- [ ] Tiles grouped into chunk Models for streaming.
- [ ] Collision simple and checked by walking every edge.

## Related

[[Modular Environment Kits]] · [[Grid Placement and Player Building Systems]] · [[Foliage Props and Scatter]] · [[Terrain Tools and Terrain API]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Rendering Performance]] · [[Instance Streaming]] · [[Level of Detail and Model Streaming]] · [[Low-Poly Tree Set Worked Example]] · [[Procedural World Generation]] · [[Voxel Scale Grids and Stud Alignment]] · [[Voxel Shading - Baked AO Edges and Lighting]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Modelling Start Here]] · [[Wave Function Collapse on Roblox]] · [[Noise Functions and Terrain Generation]] · [[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Voxel and Blocky Modeling]] · [[Environment and Level Pipeline]]
<!-- auto-links:end -->
