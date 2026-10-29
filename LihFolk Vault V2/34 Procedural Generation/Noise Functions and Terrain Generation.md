---
tags: [procedural, generation, noise, terrain, biomes, voxels, luau, type/guide, area/procedural, level/intermediate, api/Terrain, area/modeling]
---
# Noise Functions and Terrain Generation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Thresholds on raw noise values -> Calibrate thresholds by percentile
> - Avoid: Huge seed offsets -> Hash to moderate offsets
> - Avoid: Per-biome height functions with no blending -> Shared base, border fade or weighted blend
> - Noise sampled off-lattice with hashed, moderate offsets.
> - Thresholds expressed as percentages and calibrated.
> - Height shaped by a designer-editable curve.
>
> Cost: TL;DR ~140 tok · whole note ~4.6k tok. Read more: ## Shaping: from noise to designed terrain · ## Cellular noise for biomes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Procedural World Generation]] shows the standard fractal noise (fbm) height function, ridged noise, terracing and a rule-based material picker. This note goes underneath that: what `math.noise` actually returns and why raw thresholds go wrong, how to shape noise into terrain designers can control, cellular (Voronoi) noise for biomes and how to blend biome borders without seams, caves from 3D noise, writing smooth terrain with fractional occupancy, and what all of this costs. Code here uses the `Hash` module from [[Seeds Determinism and Reproducible Worlds]].

## What math.noise gives you

`math.noise(x, y, z)` is Perlin gradient noise. Roblox docs say the result is "most often" between -1 and 1 but may sometimes fall outside. Practical facts (rule of thumb, measure on your own setup):

- **It is zero on the integer lattice.** Sample at `(3, 0, 7)` and you get 0. Scale coordinates by a non-integer frequency and add a non-integer offset.
- **The distribution is bell-shaped, not uniform.** Most values sit well inside -0.5 to 0.5. Summing octaves (fbm) narrows it further, because independent layers average out.
- **It has no seed parameter.** Different worlds come from offsetting the sample space. Use offsets derived from a hash, and keep them moderate (thousands, not billions): large coordinates lose float precision and the noise turns blocky.
- **It is smooth but has a grid character.** Perlin noise has faint alignment to its lattice axes. At one octave this can show as ridges running north-south or east-west. Rotating the sample coordinates per octave hides it.

### The distribution problem

Because fbm output clusters around zero, a rule like "water below -0.3" might cover 4 percent of the map with one octave count and 1 percent with another. Designers think in **percentages** ("about 20 percent water"), not raw values. The fix is to calibrate thresholds from samples:

```lua
--!strict
-- Find the value below which `fraction` of samples fall (an empirical percentile).
-- Run once per generator version, offline or at server start, and cache.
local function percentile(sample: (number, number) -> number, fraction: number, count: number, rng: Random): number
	local values = table.create(count)
	for i = 1, count do
		values[i] = sample(rng:NextNumber(-20000, 20000), rng:NextNumber(-20000, 20000))
	end
	table.sort(values)
	return values[math.clamp(math.floor(fraction * count), 1, count)]
end

-- "20 percent of the world is water":
-- local waterLevel = percentile(heightNoise, 0.20, 20000, Random.new(1))
```

Twenty thousand samples gives a percentile accurate to well under one percent. Recompute whenever you change octaves, gain or shaping. Now "20 percent water" survives tuning.

## Shaping: from noise to designed terrain

Raw noise is landscape with no intent. Real terrain generators are mostly **shaping functions** layered on top.

### Remap curves

Pass normalised noise (0 to 1) through a curve before scaling to height:

| Curve | Formula (t in 0..1) | Effect |
|---|---|---|
| Power > 1 | `t ^ 2.5` | Wide lowlands, rare peaks |
| Power < 1 | `t ^ 0.5` | Plateaus, few valleys |
| Smoothstep | `t * t * (3 - 2 * t)` | Flattens extremes, steepens middle |
| Terrace blend | `lerp(t, floor(t * n) / n, k)` | Stepped hills, k sets crispness |
| Piecewise table | interpolate a designer-authored list of points | Full artistic control |

The piecewise curve is the most useful in production, because a designer can edit five numbers in a config module and see the result, instead of asking a programmer to change exponents.

```lua
--!strict
-- Designer-editable height curve: pairs of {input, output}, inputs ascending in 0..1.
type Curve = { { number } }

local function evalCurve(curve: Curve, t: number): number
	if t <= curve[1][1] then return curve[1][2] end
	for i = 2, #curve do
		local a, b = curve[i - 1], curve[i]
		if t <= b[1] then
			local u = (t - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * u
		end
	end
	return curve[#curve][2]
end

local HEIGHT_CURVE: Curve = {
	{ 0.00, 0 },   -- sea floor
	{ 0.30, 18 },  -- shoreline
	{ 0.38, 22 },  -- flat beach band (playable)
	{ 0.70, 40 },  -- rolling hills
	{ 0.90, 110 }, -- foothills rise fast
	{ 1.00, 180 }, -- peaks
}
```

### Domain warping

Warping offsets the sample position by another noise before sampling. One level of warp turns blobby hills into flowing, eroded-looking shapes. It is the single cheapest upgrade to noise terrain.

```lua
--!strict
local function warped(x: number, z: number, ox: number, oz: number, freq: number, strength: number): number
	-- two independent noises push the sample point around
	local wx = math.noise(x * freq * 0.5 + ox + 31.7, z * freq * 0.5 + oz) * strength
	local wz = math.noise(x * freq * 0.5 + ox, z * freq * 0.5 + oz + 47.3) * strength
	return math.noise((x + wx) * freq + ox, (z + wz) * freq + oz)
end
```

Trade-off: each level of warp costs two extra noise calls per sample and makes the terrain harder to predict. Strength above about one wavelength produces swirly, unnatural shapes. Rule of thumb: strength between 0.3 and 1 times the base wavelength (`1 / freq`).

### Masks: putting gameplay first

Noise does not know where the spawn, the boss arena or the river crossing are. Masks do. A mask is a 0..1 field computed from authored data: distance to a path polyline, distance to points of interest, inside or outside a play area.

```lua
--!strict
-- Flatten terrain near authored points of interest.
type POI = { pos: Vector2, radius: number, height: number }

local function applyPOIs(x: number, z: number, h: number, pois: { POI }): number
	for _, p in pois do
		local d = (Vector2.new(x, z) - p.pos).Magnitude
		if d < p.radius * 1.6 then
			-- 1 inside the radius, easing to 0 at 1.6x radius
			local t = math.clamp((d - p.radius) / (p.radius * 0.6), 0, 1)
			local k = 1 - t * t * (3 - 2 * t)
			h = h + (p.height - h) * k
		end
	end
	return h
end
```

Pull the height **toward** a target rather than clamping it, so the blend reads as terrain, not as a stamped disc. For many POIs, put them in a spatial grid first; looping all POIs for every sample is the classic hidden cost.

Rivers work the same way: compute distance to a river polyline, carve with a curve (deep in the middle, banks shallow), and force the river bed below water level. Generating rivers from the noise itself (following the gradient downhill) is possible but produces rivers that end in pits; authored or graph-generated river paths with masked carving are far easier to control.

### Slope-aware detail

Fine detail noise should be **weaker on flat ground and stronger on slopes**, which mimics erosion exposing rock. Multiply the detail amplitude by a slope factor computed from the base height (finite differences, as in the older note). This one change makes terrain look much less "noisy" while keeping cliffs rugged.

## Cellular noise for biomes

Smooth noise is poor at regions: thresholding it gives blobby, stringy biomes. Cellular (Worley or Voronoi) noise scatters one feature point per grid cell and assigns each sample to its nearest point. Each point is a biome region with crisp, convex-ish borders, and you can choose the biome per region from a hash, from a second noise (temperature, moisture), or from authored rules.

```lua
--!strict
local Hash = require(script.Parent.Hash)

export type Cell = { id: number, cx: number, cz: number, d1: number, d2: number }

-- Nearest and second-nearest feature points. cellSize in studs.
local function voronoi(seed: number, x: number, z: number, cellSize: number): Cell
	local gx, gz = math.floor(x / cellSize), math.floor(z / cellSize)
	local best, second = math.huge, math.huge
	local bestId, bcx, bcz = 0, gx, gz
	for dz = -1, 1 do
		for dx = -1, 1 do
			local cx, cz = gx + dx, gz + dz
			-- jittered feature point inside cell (cx, cz)
			local px = (cx + 0.1 + 0.8 * Hash.float(seed, cx, cz, 1)) * cellSize
			local pz = (cz + 0.1 + 0.8 * Hash.float(seed, cx, cz, 2)) * cellSize
			local d = (px - x) ^ 2 + (pz - z) ^ 2
			if d < best then
				second = best
				best, bestId, bcx, bcz = d, Hash.hash(seed, cx, cz), cx, cz
			elseif d < second then
				second = d
			end
		end
	end
	return { id = bestId, cx = bcx, cz = bcz, d1 = math.sqrt(best), d2 = math.sqrt(second) }
end
```

Jitter is kept to 0.1..0.9 of the cell so the 3 x 3 search is always enough. `d2 - d1` is the distance to the border, which is what you need for blending.

### Blending biome borders

The classic failure: each biome has its own height function, and at the border the terrain jumps by 30 studs in one voxel. Three ways out, from cheapest to best:

1. **Shared base, biome detail.** All biomes share one base height; biomes only change detail amplitude and materials. Seams are invisible because the heights agree. Limitation: no biome can be "a plateau" if its neighbour is "a lowland".
2. **Border fade.** Near a border (`d2 - d1 < blendWidth`), compute both biomes' heights and interpolate by `(d2 - d1) / blendWidth`, weighted 0.5 at the border. Costs two height evaluations in the band.
3. **Weighted sum over neighbours.** Compute a weight for every nearby region (for example `max(0, 1 - d / radius)^2`), normalise, and blend all their heights. Smooth everywhere, handles triple points, costs N evaluations per sample. Best for strongly different biome heights.

Materials should **not** be blended by averaging; pick the dominant biome's material, and dither near borders using a hash so the transition reads as scattered patches instead of a straight line.

## Caves and overhangs: 3D noise

A heightfield cannot make overhangs, arches or caves. 3D noise can: decide each voxel solid or air from `density(x, y, z)`. A common formula is "height gradient plus noise": density is positive below the surface and negative above, with 3D noise added so the surface bends into overhangs.

```lua
--!strict
local function density(x: number, y: number, z: number, surface: number, ox: number): number
	local d = (surface - y) / 24          -- solid below the surface, fading over 24 studs
	d += math.noise(x / 60 + ox, y / 40, z / 60) * 0.8
	-- tunnels: thin bands where |noise| is near zero ("worm" caves)
	local worm = math.abs(math.noise(x / 90 + ox, y / 90 + 13.1, z / 90))
	if y < surface - 8 and worm < 0.04 then
		d -= 2 -- carve
	end
	return d
end
```

Warnings that matter in a Roblox game:

- **Cost scales with volume.** A heightfield samples once per column; 3D density samples once per voxel. A 64 x 64 stud chunk at 4-stud voxels is 256 columns, but with 64 studs of height it is 4,096 voxels. Restrict 3D noise to a band around the surface and below, and use the heightfield elsewhere.
- **Floating islands and disconnected blobs.** 3D noise happily makes chunks of rock floating in air. Either accept them as a style, or run a flood fill from the bottom per chunk and remove disconnected solids (cheap at chunk scale).
- **Navigation.** `PathfindingService` handles terrain, but caves with ceilings close to agent height and steep tunnels create unreachable spots. Validate spawn points against computed paths ([[Pathfinding Edge Cases and Fallbacks]]).
- **Players get lost.** Underground space needs lighting and landmarks; generated caves without them feel like punishment.

## Writing terrain smoothly

Writing material Air or a solid with occupancy 1 makes stair-stepped terrain at 4-stud resolution. **Fractional occupancy** lets the engine build a smooth surface inside a voxel. For a heightfield, each voxel in a column gets occupancy equal to how much of its 4-stud height is below the surface.

```lua
--!strict
-- Build material and occupancy arrays for a column-based chunk, ready for WriteVoxels.
-- region must be aligned to the 4-stud grid. heightAt and materialAt are your functions.
local VOXEL = 4

local function buildChunk(region: Region3,
	heightAt: (number, number) -> number,
	materialAt: (number, number, number) -> Enum.Material)
	local size = region.Size / VOXEL
	local nx, ny, nz = math.round(size.X), math.round(size.Y), math.round(size.Z)
	local minC = region.CFrame.Position - region.Size / 2

	local materials, occupancy = table.create(nx), table.create(nx)
	for ix = 1, nx do
		local mx, ox = table.create(ny), table.create(ny)
		for iy = 1, ny do
			mx[iy], ox[iy] = table.create(nz), table.create(nz)
		end
		materials[ix], occupancy[ix] = mx, ox
		local wx = minC.X + (ix - 0.5) * VOXEL
		for iz = 1, nz do
			local wz = minC.Z + (iz - 0.5) * VOXEL
			local h = heightAt(wx, wz)
			for iy = 1, ny do
				local bottom = minC.Y + (iy - 1) * VOXEL
				local occ = math.clamp((h - bottom) / VOXEL, 0, 1)
				if occ > 0 then
					mx[iy][iz] = materialAt(wx, bottom, wz)
					ox[iy][iz] = occ
				else
					mx[iy][iz] = Enum.Material.Air
					ox[iy][iz] = 0
				end
			end
		end
	end
	return materials, occupancy
end

-- workspace.Terrain:WriteVoxels(region, 4, materials, occupancy)
```

Rules from [[Terrain Tools and Terrain API]] apply: resolution 4, grid-aligned regions (use `Region3:ExpandToGrid(4)`), and a voxel cap per call. Two extra notes:

- **Very small occupancies** (under about 0.1, rule of thumb) can render as nothing or as specks; clamp tiny values to 0.
- **Neighbouring chunks must agree on edge heights.** They do automatically if `heightAt` is a pure function of world coordinates. They do not if any part of the height depends on chunk-local state (a per-chunk random offset, a mask computed only from POIs inside the chunk). Masks must look at POIs near the chunk, not just in it.

For many materials per chunk with water, `WriteVoxelChannels` (Roblox docs lists it with a channels dictionary) can write water alongside solids; check the reference for the channel names before relying on it.

## Cost and budgets

Noise is cheap per call and expensive per world. A rough way to reason about it (rule of thumb, measure your own):

| Choice | Noise calls per column |
|---|---|
| Base fbm, 5 octaves | 5 |
| + detail, 3 octaves | 8 |
| + one-level domain warp | 10 |
| + biome blend in border bands (2 biomes) | up to 20 |
| + 3D caves in a 32-stud band (8 voxels, 2 calls each) | up to 36 |

A 256 x 256 stud chunk at 4-stud spacing is 4,096 columns, so even the simple version is 20,000 to 40,000 calls before materials. Measure rather than guess:

```lua
local t0 = os.clock()
for i = 1, 100000 do
	math.noise(i * 0.137, 0.5, 0.25)
end
print(("%.3f us per call"):format((os.clock() - t0) / 100000 * 1e6))
```

Then reduce:

- **Sample coarse, interpolate fine.** Compute base height on an 8-stud or 16-stud grid and bilinearly interpolate to 4 studs. Low-frequency octaves gain nothing from dense sampling.
- **Skip work the mask kills.** If a POI flattens the area to a fixed height, do not compute detail octaves there.
- **Cache per column.** `materialAt` often needs height and slope again; compute them once per column.
- **Use Parallel Luau.** Noise and array building are pure and parallel-safe; only the write needs serial. See [[Infinite and Streamed Worlds]] and [[Parallel Luau and Actors]].
- **Native code generation** (`--!native`) can speed up tight numeric loops; see [[Luau Performance and Native Codegen]] and [[Luau Performance Patterns with Benchmarks]].

## Edit-time first

Most games that "use procedural terrain" do not need it at runtime. Generating once in Studio and then hand-finishing gives the variety of noise with the polish of a person. Generate at runtime only when the world must differ per server, per run or per player, or when it is too large to store. The terrain itself is also stored efficiently in the place file; a generated-and-saved world loads faster than one computed on join. [[Terrain Deep Dive - Materials Water and Performance]] covers the render and memory side.

## Common mistakes

| Mistake | How it shows | Fix |
|---|---|---|
| Thresholds on raw noise values | Water percentage swings when octaves change | Calibrate thresholds by percentile |
| Huge seed offsets | Blocky, quantized terrain | Hash to moderate offsets |
| Per-biome height functions with no blending | Cliffs along biome borders | Shared base, border fade or weighted blend |
| Masks that only see POIs inside the chunk | Seams at chunk edges near POIs | Query POIs by distance, not by chunk membership |
| 3D noise for the whole column | Generation takes seconds per chunk | Heightfield plus a 3D band |
| Occupancy always 1 | Stair-stepped terrain | Fractional occupancy from height |
| Averaging materials at borders | Muddy mixed patches | Dominant material plus hashed dither |
| Warping too strong | Swirls and spaghetti terrain | Strength under one base wavelength |

## Checklist

- [ ] Noise sampled off-lattice with hashed, moderate offsets.
- [ ] Thresholds expressed as percentages and calibrated.
- [ ] Height shaped by a designer-editable curve.
- [ ] Gameplay areas protected by masks that blend toward targets.
- [ ] Biomes from cellular noise with an explicit border strategy.
- [ ] 3D noise only where overhangs or caves are wanted; disconnected blobs handled.
- [ ] Fractional occupancy; tiny values clamped.
- [ ] Height is a pure function of world position (seams agree).
- [ ] Cost measured per chunk and budgeted.

## See also

- [[Procedural Generation Start Here]], [[Procedural World Generation]]
- [[Terrain Tools and Terrain API]], [[Terrain Deep Dive - Materials Water and Performance]], [[Zone and Biome Art Direction]]
- [[Seeds Determinism and Reproducible Worlds]], [[Infinite and Streamed Worlds]]
- [[Foliage Props and Scatter]], [[Pathfinding]], [[Water Sky and Atmosphere Art]]

## Connected notes
<!-- auto-links:start -->
[[Links - Terrain]] · Terrain Materials and Painting · Voxel Props Environments and Modular Tiles · [[Wave Function Collapse on Roblox]] · Deterministic Simulation · Meshing Voxels for Roblox - Greedy Meshing and Export
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Roads, Rivers and Paths Carved Along Curves in Terrain]] · [[Terrain Materials and Painting]] · [[Dungeon and Room Generation]] · [[Voxel Props Environments and Modular Tiles]] · [[Procedural Loot and Item Generation]] · [[Environment and Level Pipeline]]
<!-- related:end -->
