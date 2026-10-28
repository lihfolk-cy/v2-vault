---
tags: [world-building, procedural, generation, noise, terrain, seeds, tooling]
---
# Procedural World Generation

Procedural generation on Roblox comes in two very different forms:

1. **Edit-time generation:** scripts in Studio (command bar, plugins, external tools) that build terrain, place props or assemble kits, after which the result is saved in the place and hand-edited. Most "procedural" Roblox maps are this.
2. **Runtime generation:** the server (or client) builds worlds while the game runs: infinite terrain, roguelike dungeons, per-server random maps.

Both use the same building blocks: seeded randomness, noise, rules, and careful chunking. This note covers the techniques, working Luau, and the hard lessons of one production game whose generators built a realm's terrain, kits and dressing, and occasionally destroyed hand work.

## Determinism: seeds first

A generator must produce the same output for the same input, or you cannot iterate, debug or rebuild.

- Use `Random.new(seed)` objects, never `math.random` for generation (shared global state; any other code calling it shifts your sequence).
- Use **one Random per purpose** (terrain, props, colours), so adding a prop type does not reshuffle the terrain.
- Derive sub-seeds from coordinates for chunked worlds: `Random.new(seed + cx * 73856093 + cz * 19349663)` (any well-mixed hash). Chunks then generate identically in any order.
- `math.noise(x, y, z)` is deterministic (Perlin noise). It returns 0 at integer lattice points, so always scale coordinates by a non-integer frequency and add a seed offset.

## Noise fundamentals

`math.noise` returns values roughly in -1..1, mostly within about -0.5..0.5. Layer octaves (fractal Brownian motion) for natural terrain:

```lua
--!strict
-- Fractal noise in [-1, 1]-ish. seed shifts the sample space so different seeds differ.
local function fbm(x: number, z: number, seed: number, octaves: number, frequency: number,
	lacunarity: number, gain: number): number
	local sum, amp, freq, norm = 0, 1, frequency, 0
	local ox, oz = seed * 0.6180339, seed * 0.3819660 -- irrational offsets avoid lattice zeros
	for _ = 1, octaves do
		sum += math.noise(x * freq + ox, z * freq + oz, seed * 0.1) * amp
		norm += amp
		amp *= gain
		freq *= lacunarity
		ox += 17.31
		oz += 41.73
	end
	return sum / norm
end

-- Typical terrain heights
local function height(x: number, z: number, seed: number): number
	local base = fbm(x, z, seed, 5, 1 / 512, 2.0, 0.5) -- broad hills
	local detail = fbm(x, z, seed + 99, 3, 1 / 64, 2.0, 0.5) -- small bumps
	local ridged = 1 - math.abs(fbm(x, z, seed + 7, 4, 1 / 900, 2.0, 0.5)) -- ridges for mountains
	return 40 + base * 60 + detail * 4 + (ridged ^ 3) * 90
end
```

Useful shaping tricks:
- **Ridged noise** (`1 - |n|`) for mountain ridges.
- **Domain warping** (offset x, z by another noise) for organic, less grid-aligned shapes.
- **Terracing** (`math.floor(h / step) * step` blended with h) for stylised plateaus.
- **Masks** that multiply height by a falloff, to keep playable areas flat. One production game kept enemy combat areas flat (slope 95th percentile under 0.14) and only let noise roam outside them.
- **Low amplitude near gameplay.** Its floor style used about one third of the original undulation in combat zones; dramatic shapes went to the edges.

## Biomes and materials

Pick materials from rules, not noise alone:

```lua
--!strict
-- Choose a terrain material from height, slope and a moisture noise.
local function materialFor(h: number, slope: number, moisture: number): Enum.Material
	if slope > 0.9 then
		return Enum.Material.Rock -- steep faces
	elseif h > 150 then
		return Enum.Material.Snow
	elseif h < 12 then
		return Enum.Material.Sand
	elseif moisture > 0.25 then
		return Enum.Material.LeafyGrass
	elseif moisture < -0.25 then
		return Enum.Material.Ground
	end
	return Enum.Material.Grass
end

-- Slope from finite differences (rise over run between samples 4 studs apart)
local function slopeAt(x: number, z: number, seed: number): number
	local dx = height(x + 4, z, seed) - height(x - 4, z, seed)
	local dz = height(x, z + 4, seed) - height(x, z - 4, seed)
	return math.sqrt(dx * dx + dz * dz) / 8
end
```

Remember that terrain colours and material textures are **global**: if two biomes need different-looking grass, give them different materials (see [[Terrain Tools and Terrain API]]).

Writing the heights into terrain uses chunked `WriteVoxels` (regions grid-aligned, resolution 4, under 4,194,304 voxels per call); the chunked writer is in [[Terrain Tools and Terrain API]]. Calibrate the rendered surface against a raycast once, because the rendered top sat about 2 studs above the computed voxel top in one production game.

## Layout generation

### Zones along a path

Linear progression games can generate zone layouts from a few parameters. One production game's realm was defined by formulas: zone k starts at `x = x0 + (k - 1) * 624`, its floor at `y = y0 + (k - 1) * 38`, gates at each boundary, with shared global terrace heights and edges so neighbouring zones met without seams. A shared "zone standard" module owned those numbers and every per-zone script read it.

Lesson: **put shared layout numbers in one module** that every generator, placement tool and gameplay script reads. When zone lengths changed later, everything that read the module followed.

### Dungeons and rooms (runtime)

For roguelike rooms: a grid or graph of rooms, each room a prefab model with **connector attachments** at its doors. Generation:
1. Start with an entrance room.
2. Pick an open connector; choose a prefab whose connector matches (size, type).
3. Align the new room so its connector faces the open one (`CFrame` math on attachment world frames).
4. Reject on overlap (`workspace:GetPartBoundsInBox` with the room's bounds, or a coarse occupancy grid).
5. Repeat to a target count; cap open connectors with wall prefabs.

```lua
--!strict
-- Place `room` so that its connector `b` meets world connector `a` (facing each other).
local function alignRoom(room: Model, b: Attachment, a: Attachment)
	-- Target frame for b: at a's position, facing opposite to a
	local target = a.WorldCFrame * CFrame.Angles(0, math.pi, 0)
	local offset = room:GetPivot():ToObjectSpace(b.WorldCFrame) -- b relative to room pivot
	room:PivotTo(target * offset:Inverse())
end
```

Overlap testing with the occupancy grid is cheaper and more predictable than physics queries on unparented or freshly placed geometry.

### Scatter

Props, trees and decoration use Poisson-disk sampling with grounding raycasts and keep-out zones; see [[Foliage Props and Scatter]] for a full tool.

## Edit-time generation done safely

Generators are powerful and dangerous: they can wipe hours of hand work in one run. Lessons from one production game:

- **Never regenerate a whole area to fix part of it.** Its rule after an incident: snapshot first, and never regenerate a whole area without explicit approval. A cliff generation pass was reverted the next day by another team member; floors were later rebuilt one solid colour per zone with snapshots kept.
- **Generators must respect manual decisions.** Items deleted or replaced by hand must not be recreated by the next run. Keep a manifest of "do not generate" ids or areas, and make generators read it.
- **Generated content is tagged.** Every generated instance carries an attribute (`Generated = "<generator>@<seed>"`); clearing a generator's output is a tag query, and hand-placed items are never touched.
- **Dry runs and diffs.** Generators print what they would add, move and delete before doing it.
- **Survey before you rebuild.** That project's terrain was once found wiped (`CountCells()` returned 0, cause unknown). It was rebuilt from an earlier survey that had recorded rendered height and material every 4 studs; the survey was the only reason the realm could be recovered. Curved paths, which the survey lacked, were lost and had to be repainted from their source polylines.
- **One write per call, read back.** Large terrain writes were chunked and verified (see [[Terrain Tools and Terrain API]]).
- **Chunk Studio work.** Huge single loops freeze Studio; build off-world in chunks across calls and pivot into place.

```lua
--!strict
-- Clear only what a generator made, never hand-placed content.
local function clearGenerated(root: Instance, generator: string): number
	local n = 0
	for _, d in root:GetDescendants() do
		local tag = d:GetAttribute("Generated")
		if typeof(tag) == "string" and string.sub(tag, 1, #generator + 1) == generator .. "@" then
			d:Destroy()
			n += 1
		end
	end
	return n
end
```

Destroying a parent destroys its descendants; tag only top-level generated items so the count stays meaningful.

## Runtime generation

### Server or client?

| Generate on | Pros | Cons |
|---|---|---|
| Server | Authoritative collision, enemies and pathfinding see it, replicates to all | Server cost; replication bandwidth for big worlds |
| Client (from a shared seed) | No replication of geometry; scales to huge worlds | Server has no geometry (must validate positions differently); every client pays the cost |
| Server terrain + client decoration | Collision authoritative, visuals cheap | Two systems to keep in sync |

Terrain written on the server replicates to clients. For infinite or very large worlds, generate chunks around players on demand and remove distant chunks (only if nothing persistent lives there).

### Spreading the cost

- Generate in chunks with `task.wait()` between them (or frame-budgeted loops checking `os.clock()`).
- **Parallel Luau** can compute noise and voxel arrays in Actors, with the `WriteVoxels` call made back in serial (`task.synchronize()`), since writing to the DataModel requires the serial phase. `ReadVoxels` and `GetMaterialColor` are marked safe to call in parallel in the API reference. See [[Parallel Luau and Actors]].
- Cache results by chunk key.

```lua
--!strict
-- Frame-budgeted chunk queue: generate chunks near players without long frames.
local RunService = game:GetService("RunService")

local queue: { Vector2 } = {}
local done: { [string]: boolean } = {}
local BUDGET = 0.004 -- seconds of generation per Heartbeat

local function request(cx: number, cz: number)
	local k = cx .. "," .. cz
	if not done[k] then
		done[k] = true
		table.insert(queue, Vector2.new(cx, cz))
	end
end

local function generateChunk(c: Vector2)
	-- build heights with fbm(), then WriteVoxels for this chunk's grid-aligned region
end

RunService.Heartbeat:Connect(function()
	local start = os.clock()
	while #queue > 0 and os.clock() - start < BUDGET do
		generateChunk(table.remove(queue, 1) :: Vector2)
	end
end)
```

A single `WriteVoxels` of a large chunk can itself exceed the budget; keep chunks small (for example 16 x 16 cells across the height range) for runtime use.

## Procedural modelling outside Studio

Procedural does not only mean terrain. One production game generated its gates, hub kits, stations and enemies with Python in Blender (shared primitive libraries, palettes, per-piece scripts, batch renders and contact sheets), then uploaded the results as meshes. The lesson there was aesthetic: a fully procedural hub kit looked "low detail, pixelated" next to a hand-painted one and was reverted, while procedural **systems with hand-designed rules** (real masonry logic for gates, studied style guides for voxel models) worked. See [[Modeling in Blender for Roblox]] and [[Voxel Art - Studs Outlines and Style Kits]].

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| `math.random` in generators | Unrepeatable output | `Random.new(seed)` per purpose |
| Noise sampled at integer coordinates | Flat zero output | Scale by non-integer frequency, offset by seed |
| Regenerating everything to fix one corner | Hand work lost | Regional regeneration, snapshots |
| Generator recreates deleted items | Fights with designers | Manifests of exclusions |
| Untagged generated content | Cannot clear safely | Attribute every generated root |
| One giant terrain write | Errors, freezes | Chunks + read back |
| Wild noise in combat areas | Enemies snag, players fall | Masks, low amplitude near gameplay |
| Shared numbers copied into many scripts | Drift after changes | One layout module |

## Checklist

- [ ] Seeded, per-purpose Random; chunk sub-seeds from coordinates.
- [ ] Noise layered and masked; gameplay areas flat enough.
- [ ] Materials from rules; global terrain colours respected.
- [ ] Layout numbers in one shared module.
- [ ] Generated content tagged; exclusions respected; dry run first.
- [ ] Snapshot and survey before regenerating; writes chunked and verified.
- [ ] Runtime generation frame-budgeted.

## See also

- [[Terrain Tools and Terrain API]], [[Foliage Props and Scatter]], [[Level Design for Roblox]], [[Modeling in Blender for Roblox]]
- [[Parallel Luau and Actors]], [[Math Vectors and CFrames]], [[Task Library Coroutines and Yielding]]
- [[Safe Changes in a Shared Place]], [[Genre Playbook - Simulators]], [[Level of Detail and Model Streaming]]

## Nuances and edge cases

1. **Determinism ends at the engine boundary.** A seeded generator gives the same numbers, but if generation depends on physics settling, raycasts against parts placed in the same frame, or iteration over dictionaries, the output can still differ between runs. Keep generation a pure function of the seed and your own data; place instances only after all decisions are made.
2. **Floating point differs less than order does.** Generators usually break not because of float differences but because the order of random calls changed: adding one extra `rng:NextNumber()` early in the pipeline shifts every later result. Give each subsystem its own `Random` seeded from the master seed plus a fixed salt, so adding a tree pass does not move every room.
3. **Runtime generation costs the server first.** The server builds the world and replicates it; every generated part is an instance the server holds and must send to clients. A 20,000-part generated dungeon per server is a join-time and memory problem. Generate coarse geometry on the server and decorative detail on each client from the shared seed, when the detail has no gameplay effect.
4. **Client-side decoration must not affect gameplay.** If clients scatter rocks locally, those rocks must not collide or block line of sight, or players will see different worlds. Make client decoration non-collidable and non-queryable.
5. **Scale: per-server versus shared worlds.** For a session game, a fresh seed per server is fine. For a persistent shared world with 700 players across many servers, everyone must see the same map, so the seed (and generator version) becomes part of the game's data and must never silently change. Version the generator; old seeds plus a new generator produce a different world.
6. **Phones are sensitive to generation spikes.** Building a large chunk in one frame causes a visible hitch, worse on low-end devices. Slice generation over several frames (a time budget of 2 to 4 ms per frame is a common rule of thumb), and generate ahead of the player.
7. **Procedural does not mean readable.** Noise produces plausible terrain but rarely good play spaces: no landmarks, no sightlines, no clear paths. The best results mix generated filler with hand-authored set pieces placed by rules (see [[Level Design Principles - Flow Sightlines and Landmarks]]).
8. **Edit-time generation is the safest default.** Generating in Studio and saving the result gives designers something to polish and removes runtime risk. Runtime generation is worth it only when replayability is the product (roguelikes, survival maps).

The senior trade-off: procedural content scales content volume, not content quality. Spend generator effort on the boring, large-area parts (ground, scatter, filler rooms) and keep human effort on the parts players remember.

## Common mistakes (advanced)

1. **One `Random` for the whole generator.** Symptom: adding a feature changes the entire world. Fix: one generator per subsystem, seeded with salts.
2. **Generating on the server what only looks pretty.** Symptom: slow joins and high server memory. Fix: client-side decoration from the seed.
3. **No generator version in saved seeds.** Symptom: players return to a different map after an update. Fix: store `{seed, version}` and keep old generators or migrate deliberately.
4. **Unbounded retries for placement.** Symptom: rare server freezes when a rule cannot be satisfied. Fix: cap attempts and fall back to a simpler layout.
5. **Validating generated layouts by eye only.** Symptom: one seed in a thousand produces an unreachable exit. Fix: automated reachability checks (flood fill or pathfinding) over many seeds in a test.
6. **Generating inside one frame.** Symptom: hitch on chunk boundaries. Fix: time-sliced generation with `task.wait()` between batches.

## Related decisions

- [[Seeds Determinism and Reproducible Worlds]]: the full determinism rules.
- [[Noise Functions and Terrain Generation]]: noise layering for terrain.
- [[Dungeon and Room Generation]]: room-based layouts with reachability checks.
- [[Wave Function Collapse on Roblox]]: constraint-based generation as an alternative to noise.
- [[Infinite and Streamed Worlds]]: chunked generation with streaming.
- [[Level Design Principles - Flow Sightlines and Landmarks]]: why hand-authored set pieces still matter.
- [[Terrain Deep Dive - Materials Water and Performance]]: the cost of generated terrain.
- [[Pathfinding Edge Cases and Fallbacks]]: using pathfinding to validate layouts.

## Connected notes
<!-- auto-links:start -->
[[Procedural Generation Start Here]] · [[Deterministic Simulation]] · [[Links - Terrain]] · [[Environment and Level Pipeline]] · [[Terrain Materials and Painting]] · [[MCP Workflows for Building Worlds]]
<!-- auto-links:end -->
