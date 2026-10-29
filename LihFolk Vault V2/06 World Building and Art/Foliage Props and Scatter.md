---
tags: [world-building, foliage, trees, props, scatter, placement, wind]
---
# Foliage Props and Scatter

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Uniform random placement -> Poisson disk
> - Avoid: One scale for all trees -> Long-tail scale
> - Avoid: Grounding with a ray that hits props -> Ground-only raycast
> - Foliage approach chosen (modelled vs cards) and consistent.
> - Tree pivots at trunk base; canopies non-colliding.
> - Scatter seeded, Poisson-spaced, long-tail scaled, layered.
>
> Cost: TL;DR ~130 tok · whole note ~4.8k tok. Read more: ## Scatter: placing many props naturally · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Foliage and props are most of what makes a world feel inhabited, and most of its instance count. This note covers how to build trees and plants for Roblox, how to place hundreds of props so they look natural instead of stamped, how to ground them reliably, how to animate wind cheaply, and how to keep it all inside performance budgets. The production numbers come from one production game that dressed a ten-zone realm and a hub with several thousand props.

## Building foliage

### Modelled leaves versus alpha cards

| Approach | Look | Cost | Notes |
|---|---|---|---|
| Modelled leaf clumps (chunky geometry, flat colour) | Stylised, crisp at any distance | More triangles, no transparency | Best for stylised games; no overdraw; works on low graphics |
| Alpha cards (quads with a leaf texture) | Realistic, soft | Few triangles, transparency overdraw | Needs `SurfaceAppearance` with `AlphaMode = Transparency` and part `Transparency = 0` for hard cut-outs; `DoubleSided` |
| Terrain grass (`Decoration`) | Animated blades on Grass material | Engine-managed | Global on/off; only on the Grass material |
| Grass tuft meshes | Clumps placed as props | One instance each | Control density per area |

One production game's style rule was **modelled leaf geometry only**: flat colours, chunky stylised shapes, SmoothPlastic, no textures or alpha cards on props, wood trunks, and canopies non-colliding. That avoided overdraw on phones (stacked transparent cards are one of the most expensive things to draw) and kept foliage consistent with the rest of the flat style.

If you use cards:
- Use `AlphaMode = Transparency` with `MeshPart.Transparency = 0` for hard cut-outs; the docs warn values like 0.01 may still behave opaque, and at 0.02+ you get soft blending (and sorting problems).
- Keep card counts low per tree; overlapping cards multiply overdraw.
- `DoubleSided` on leaf meshes only.

### Tree anatomy for games

- **Trunk** collides (a simple cylinder or box collider); **canopy** never collides. A collidable canopy catches jumping players and projectiles.
- **Pivot at the trunk base**, so grounding and random rotation work.
- **Leaves as separate meshes** from trunks, so a script can sway them and recolour them per season or zone.
- **Two or three variants per species**, plus random scale and yaw at placement, is enough to hide repetition.

### Ground litter

Big "litter" meshes (one mesh holding hundreds of fallen leaves) look stamped and cannot follow terrain. One production game replaced two such mega-meshes with **948 single leaf meshes** scattered on the terrain. More instances, but each follows the ground and they instance as one mesh.

## Scatter: placing many props naturally

### Why uniform random looks wrong

`Random` positions clump in some places and leave holes in others, and identical scale makes forests look planted. Natural distributions have:
- **Minimum spacing** (no two trunks overlapping): Poisson-disk sampling.
- **A long-tail scale distribution**: many small, fewer medium, a handful of giants.
- **Layers**: dense walls at the edges, a sparse middle, a few hero trees.
- **Variety in rotation and slight tilt.**

One production game turned a zone of 24 trees into a forest of 128 using exactly this: species mix (40 / 54 / 18 / 11 / 5 of five species), a scale long tail (57 under 0.9x, 37 between 0.9 and 1.4x, 18 between 1.4 and 2x, 8 between 2 and 2.8x, and 8 giants above 2.8x), per-tree crown rotation of 14 to 22 degrees, leaf jitter, tilt up to 4 degrees, and each tree tagged with a layer (wall, mid, box, edge).

### Thinning and evening out

The opposite problem is clumps. The same project ran two passes:
- **Thinning:** clumped trees and props on zone sides were thinned "to look natural".
- **Evening out:** 469 grass kits and 79 wildflower kits that had been placed in clumps were spread evenly over the walkable hub grass. A spot was accepted only if **5 down-rays (centre and four corners) all hit grass**, so nothing landed on paving, water, boulders, trees or buildings. Each kit was sunk 0.15 studs into the grass with a random yaw.

### A scatter tool

```lua
--!strict
-- Poisson-disk scatter of templates over a rectangle, grounded on allowed surfaces.
-- templates: list of Models with PrimaryPart (pivot at the base).
-- allowed(hit): returns true if the ray hit is an acceptable surface (e.g. Grass terrain).
type Options = {
	minX: number, maxX: number, minZ: number, maxZ: number, topY: number,
	spacing: number, -- minimum distance between props
	attempts: number, -- candidates to try per placed prop (Bridson uses 30)
	scale: (rng: Random) -> number,
	sink: number,
	seed: number,
	keepOut: { { centre: Vector3, radius: number } },
}

local function footprintOk(x: number, z: number, r: number, topY: number,
	params: RaycastParams, allowed: (RaycastResult) -> boolean): RaycastResult?
	local offsets = { Vector2.zero, Vector2.new(r, 0), Vector2.new(-r, 0), Vector2.new(0, r), Vector2.new(0, -r) }
	local centreHit: RaycastResult? = nil
	for i, o in offsets do
		local hit = workspace:Raycast(Vector3.new(x + o.X, topY, z + o.Y), Vector3.new(0, -2000, 0), params)
		if not hit or not allowed(hit) then
			return nil
		end
		if i == 1 then
			centreHit = hit
		end
	end
	return centreHit
end

local function scatter(templates: { Model }, parent: Instance, opts: Options,
	params: RaycastParams, allowed: (RaycastResult) -> boolean): number
	local rng = Random.new(opts.seed)
	local cell = opts.spacing / math.sqrt(2)
	local grid: { [string]: Vector2 } = {}
	local function key(p: Vector2): string
		return math.floor(p.X / cell) .. "," .. math.floor(p.Y / cell)
	end
	local function farEnough(p: Vector2): boolean
		local gx, gz = math.floor(p.X / cell), math.floor(p.Y / cell)
		for dx = -2, 2 do
			for dz = -2, 2 do
				local q = grid[(gx + dx) .. "," .. (gz + dz)]
				if q and (q - p).Magnitude < opts.spacing then
					return false
				end
			end
		end
		for _, k in opts.keepOut do
			if (Vector2.new(k.centre.X, k.centre.Z) - p).Magnitude < k.radius then
				return false
			end
		end
		return true
	end

	local active: { Vector2 } = {}
	local first = Vector2.new(rng:NextNumber(opts.minX, opts.maxX), rng:NextNumber(opts.minZ, opts.maxZ))
	table.insert(active, first)
	grid[key(first)] = first
	local placed, steps = 0, 0

	while #active > 0 do
		local i = rng:NextInteger(1, #active)
		local base = active[i]
		local found = false
		for _ = 1, opts.attempts do
			local a = rng:NextNumber(0, 2 * math.pi)
			local d = rng:NextNumber(opts.spacing, 2 * opts.spacing)
			local p = base + Vector2.new(math.cos(a), math.sin(a)) * d
			if p.X >= opts.minX and p.X <= opts.maxX and p.Y >= opts.minZ and p.Y <= opts.maxZ and farEnough(p) then
				grid[key(p)] = p
				table.insert(active, p)
				found = true
				local hit = footprintOk(p.X, p.Y, opts.spacing * 0.25, opts.topY, params, allowed)
				if hit then
					local template = templates[rng:NextInteger(1, #templates)]
					local m = template:Clone()
					m:ScaleTo(opts.scale(rng))
					local yaw = CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
					m:PivotTo(CFrame.new(hit.Position - Vector3.new(0, opts.sink, 0)) * yaw)
					m:SetAttribute("Scattered", opts.seed)
					m.Parent = parent
					placed += 1
				end
				break
			end
		end
		if not found then
			table.remove(active, i)
		end
		steps += 1
		if steps % 200 == 0 then
			task.wait() -- keep Studio responsive on big areas
		end
	end
	return placed
end
```

Notes on the tool:
- It is **seeded**: the same seed reproduces the same layout, so you can tweak parameters and rerun after deleting everything tagged with that seed.
- The raycast params should **include only the ground** (Terrain plus your floor parts) so props do not land on each other.
- The long-tail scale comes from the `scale` callback, for example `function(r) return 0.7 + 2.3 * r:NextNumber() ^ 3 end` (cubing a uniform number skews toward small values with a tail of giants).
- `ScaleTo` scales the model around its pivot; with the pivot at the trunk base, grounding stays correct.

### Placement rules from production

- **Ground with terrain-only (or floor-only) raycasts.** A cast that only excludes the prop itself lands on other props.
- **Overlap-test with `GetPartsInPart`** on the placed model's parts. `GetPartBoundsInBox` over-reports against large mesh bounding boxes (measured).
- **Keep-outs**: gate mouths, station prompts and signs (a 46-stud tree keep-clear radius around hub stations), boss arenas, enemy walk boxes, paths.
- **Distance from gates**: trees kept at least 45 studs plus their canopy radius from gates so gate frames stayed readable.
- **Colliding props only outside combat areas.** Inside enemy walk boxes, decoration is non-colliding (see [[Level Design for Roblox]]).
- **Record what you did.** Attributes for the old pivot, the scatter seed, the layer. Reverting is then a loop.
- **Check for floaters after any terrain edit.** That project found 276 floating ground props after terrain changes and snapped them down, storing the amount lowered in an attribute and skipping props that float on purpose.

## Wind and sway

### Engine wind

`Workspace.GlobalWind` drives terrain grass decoration and can affect particles (`ParticleEmitter.WindAffectsDrag`). It does not move your tree meshes.

### Scripted sway (client)

Sway is purely visual: run it on the **client**, only for nearby trees, and only on canopies.

```lua
--!strict
-- LocalScript: gentle sway for Models tagged "SwayTree". Each tree's canopy parts are those
-- with attribute Foliage = true. Rotates canopies around the tree pivot; trunks stay still.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RADIUS = 180 -- only animate trees this close to the camera
local AMP = math.rad(2.5) -- max tilt
local camera = workspace.CurrentCamera

type Entry = { pivot: CFrame, parts: { { part: BasePart, rel: CFrame } }, phase: number, freq: number }
local entries: { [Model]: Entry } = {}

local function register(tree: Instance)
	if not tree:IsA("Model") then return end
	local pivot = tree:GetPivot()
	local parts = {}
	for _, p in tree:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Foliage") == true and p.Anchored then
			table.insert(parts, { part = p, rel = pivot:ToObjectSpace(p.CFrame) })
		end
	end
	if #parts > 0 then
		entries[tree] = { pivot = pivot, parts = parts, phase = math.random() * 6.28, freq = 0.25 + math.random() * 0.15 }
	end
end

for _, t in CollectionService:GetTagged("SwayTree") do register(t) end
CollectionService:GetInstanceAddedSignal("SwayTree"):Connect(register)
CollectionService:GetInstanceRemovedSignal("SwayTree"):Connect(function(t)
	entries[t :: Model] = nil
end)

local t = 0
RunService.PreRender:Connect(function(dt: number)
	t += dt
	local camPos = camera.CFrame.Position
	for _, e in entries do
		if (e.pivot.Position - camPos).Magnitude < RADIUS then
			local a = math.sin(t * e.freq * 2 * math.pi + e.phase) * AMP
			local sway = e.pivot * CFrame.Angles(a * 0.6, 0, a)
			for _, item in e.parts do
				item.part.CFrame = sway * item.rel
			end
		end
	end
end)
```

Moving anchored parts every frame is fine for tens of trees, not thousands; the radius cap matters. The trees in that project carried a `SwayTree` tag and `Foliage` attribute exactly so a client script could find them, and a separate client script blew a few leaves around. See [[Tween and CFrame Animation of Objects]] for the general technique.

Note that moving parts on the client changes their position only for that client; collision and server raycasts still see the original. That is fine for canopies that do not collide.

## Props in general

- **Kits over one-offs.** A zone kit of 50 to 90 models (lamps, rocks, fences, crates, ruins) placed by cloning gives consistency and instancing. One production game finished a realm with 617 placed models from an 87-model kit of 439 meshes.
- **Templates with a known pivot** (bottom centre, named `Origin`) in a `ServerStorage` library.
- **Animate props by name or tag**, not by individual scripts: one client controller animated props by name prefix per biome (grass, lava, frost, neon, crystal, void), keeping jointed animated props unanchored where needed.
- **Decor defaults:** anchored, `CanTouch = false`, small parts `CastShadow = false`, `RenderFidelity = Automatic`.

## Performance

| Lever | Effect |
|---|---|
| Reuse meshes (few species, many copies) | Instancing keeps draw calls low |
| Small props `CastShadow = false` | Shadows are expensive with many small casters (Roblox docs) |
| Canopies non-colliding, trunks simple colliders | Physics broadphase stays small |
| No alpha cards (or few) | Avoid overdraw on phones |
| Client sway with a radius | No per-frame work for far trees |
| Streaming radius and LOD | Far props are not loaded or are cheap ([[Level of Detail and Model Streaming]]) |
| Density by importance | Dense at path edges, sparse in backgrounds |

Count everything: a forest pass that adds 1,000 trees of 8 parts each adds 8,000 instances. In that project trees were about 970 of the hub's 1,231 parts at one stage.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Uniform random placement | Clumps and holes | Poisson disk |
| One scale for all trees | Planted look | Long-tail scale |
| Grounding with a ray that hits props | Props stacked on props | Ground-only raycast |
| Collidable canopies | Players catch on leaves | Canopy CanCollide off |
| Stacked alpha cards | Phone frame drops | Modelled clumps or fewer cards |
| Server-side sway | Network and server cost | Client only |
| Props in gate mouths and over prompts | Blocked signs, stuck players | Keep-out radii |
| Scatter without a seed | Cannot reproduce or tweak | Seeded scatter |

## Checklist

- [ ] Foliage approach chosen (modelled vs cards) and consistent.
- [ ] Tree pivots at trunk base; canopies non-colliding.
- [ ] Scatter seeded, Poisson-spaced, long-tail scaled, layered.
- [ ] Ground-only raycasts with multi-point footprint tests.
- [ ] Keep-outs for gates, stations, paths, arenas, enemy boxes.
- [ ] Sway on the client with a radius cap.
- [ ] Floater check after terrain edits.

## See also

- [[Terrain Tools and Terrain API]], [[Level Design for Roblox]], [[Procedural World Generation]], [[Environment Art Styles]]
- [[Art Budgets - Triangles Draw Calls Memory]], [[Level of Detail and Model Streaming]], [[Collision and Physics Geometry]]
- [[CollectionService Patterns]], [[Raycasts Shapecasts and Spatial Queries]], [[Tween and CFrame Animation of Objects]]

## Nuances and edge cases

1. **Instance count beats triangle count for scatter.** Ten thousand small grass clumps as separate MeshParts cost more in instance overhead, memory and streaming than the same triangles merged into fewer, larger clumps. Rule of thumb: merge ground litter into patch meshes of several square studs, and keep individual instances for things players interact with.
2. **Repeated meshes are cheaper than unique ones.** Using the same few tree meshes many times lets the engine reuse geometry and textures; dozens of slightly different unique meshes multiply memory. Get variety from scale, rotation and colour, not from unique geometry.
3. **Scatter density per device.** A forest dense enough to look lush on PC can halve frame rate on a low-end phone. Tag scatter by importance (hero, mid, filler) and let low-end clients remove filler locally, keeping hero props that matter for navigation and landmarks.
4. **Collision on scatter is a server cost too.** Every collidable rock and trunk is in the server's physics world. Give trunks simple collision and leave branches, leaves and small rocks non-collidable and non-queryable.
5. **Scatter versus gameplay space.** Natural-looking scatter fills spaces where players need to move, fight or read signs. Keep clear paths and arenas free of scatter with keep-out masks drawn from the gameplay layout, not by hand after the fact.
6. **Wind sway at scale.** Swaying a few trees with client scripts is cheap; updating thousands of CFrames per frame is not. Use engine wind where it applies, sway only near the camera, and freeze far props (see [[Procedural Animation]] for the cost of per-frame motion).
7. **Seeded scatter and later edits.** If designers hand-edit scattered props and the scatter is re-run, their edits vanish. Store exclusions and manual overrides separately so regeneration respects them.
8. **Shadows from foliage.** Thousands of leaf cards and small props casting shadows are a large GPU cost on phones, and the shadows add little at a distance. Turn off `CastShadow` on ground litter and small props, and keep shadows on trunks and large rocks where they ground the scene.
9. **Streaming and scatter.** Thousands of scattered instances stream in and out as players move, which can cause hitches when entering dense areas. Group scatter into models per area so it streams as chunks, and avoid making scatter persistent.

The senior trade-off: dense foliage is the cheapest way to make a world look rich in screenshots and the easiest way to wreck mobile performance. Decide a per-area prop budget, measure it on a low-end phone, and spend density where the camera spends time.

## Common mistakes (advanced)

1. **Thousands of separate grass meshes.** Symptom: high instance counts and slow joins. Fix: merged patches.
2. **Unique meshes for every tree.** Symptom: memory far above budget. Fix: three to five base meshes with varied transforms.
3. **Collidable leaves and small rocks.** Symptom: players snag and the server spends physics time on decoration. Fix: collision only on trunks and large rocks.
4. **Scatter in combat spaces.** Symptom: enemies get stuck, players lose sight lines. Fix: keep-out masks from the layout.
5. **Sway on every prop in the map.** Symptom: client script time grows with map size. Fix: distance-limited sway.
6. **Re-running scatter over hand edits.** Symptom: designer work lost. Fix: separate override data.

## Related decisions

- [[Art Budgets - Triangles Draw Calls Memory]]: the budget scatter must fit.
- [[Modular Environment Kits]]: building props for reuse.
- [[Mesh Optimization for Mobile]]: making each prop cheap.
- [[Combat Arena and Encounter Layout]]: where scatter must not go.
- [[Noise Functions and Terrain Generation]]: density maps for scatter.
- [[Low-Poly Tree Set Worked Example]]: a worked set of reusable tree meshes.
- [[Case Study - Cutting a Million Instances]]: instance count as the hidden cost.
- [[Instance Streaming]]: chunking scatter for streaming.

## Connected notes
<!-- auto-links:start -->
[[Voxel Props Environments and Modular Tiles]] · [[Draw Calls]] · [[Triangle Budget]] · [[MCP Workflows for Building Worlds]] · [[Environment and Level Pipeline]] · [[Exporting and Validating Models for Roblox]]
<!-- auto-links:end -->
