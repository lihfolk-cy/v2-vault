---
tags: [world-building, terrain, materials, materialvariant, water, shorelines, performance, streaming, voxels]
---
# Terrain Deep Dive - Materials Water and Performance

[[Terrain Tools and Terrain API]] covers the voxel model, the editing tools, the fill and voxel APIs, and a set of measured quirks (the rendered surface sitting about 2 studs above the voxel top, blocky materials, one write per call). This note goes one level down into the three areas where terrain decisions bite late in a project: **materials** (what is global, what can be overridden, and what Expanded Terrain changes), **water** (shorelines, the liquid channel, swimming and underwater effects, fake versus real), and **performance** (rendering, memory, place size, streaming, physics, and the hidden cost of runtime edits).

Facts are labelled: "Roblox docs (as of October 2026)", "measured in the reference project", or "rule of thumb".

---

## 1. Decide terrain versus meshes per area, not per game

The most expensive terrain mistake is choosing it for everything, or for nothing, at the start and never revisiting. The reference project ended up with no terrain at all in its first world (flat walk boxes and mesh cliffs, one solid floor colour per zone) and a single voxel heightfield for its underwater realm, because terrain materials are global and the two worlds needed different looks.

| Need | Terrain | Meshes and parts |
|---|---|---|
| Large organic ground, hills, caves | Strong: cheap per area, built-in LOD, sculptable | Many large meshes, manual LOD |
| Swimmable water | Strong: swimming and buoyancy built in | Must be scripted |
| Strong stylised art direction (flat colours, hard outlines) | Weak: materials are textured and global | Strong |
| Several zones with different "grass" | Weak without Expanded Terrain (one Grass look per place) | Strong |
| Precise flat floors at exact heights | Awkward (surface offset quirks) | Strong |
| Destructible ground (craters, digging) | Strong (voxel writes) but replicates every edit | Hard |
| Very low-end phones, huge view distance | Good LOD, but grass decoration and water cost fill rate | Depends entirely on your meshes |

A hybrid is normal: terrain for ground and water, meshes for cliffs, rocks and architecture placed on top, and flat parts for decorative water. Read [[Collision and Physics Geometry]] for how players walk on each.

---

## 2. Materials: what is global and what is not

### The default set

Default terrain materials (Roblox docs, as of October 2026): Asphalt, Basalt, Brick, Cobblestone, Concrete, Cracked Lava, Glacier, Grass, Ground, Ice, Leafy Grass, Limestone, Mud, Pavement, Rock, Salt, Sand, Sandstone, Slate, Snow, Water, Wood Planks, plus Air.

Three different "global" mechanisms change how they look:

| Mechanism | Scope | What it changes |
|---|---|---|
| `Terrain.MaterialColors` / `Terrain:SetMaterialColor(material, color)` | Every voxel of that material in the place | Tint. Water is excluded (Water uses `WaterColor`) |
| MaterialService override (a `MaterialVariant` set as the override for a base material) | Every terrain voxel **and every part** using that base material | Texture maps and, for parts and default terrain slots, physical properties |
| Expanded Terrain custom materials | Only voxels painted with that custom material | Colour and an optional MaterialVariant per slot |

The trap in the first two: they are place-wide. Recolouring Grass to autumn orange for one zone turns every Grass voxel orange. Overriding Grass with a stylised variant also changes every Part whose `Material` is Grass. This is why, before Expanded Terrain, the standard advice was "one material per look": use Leafy Grass for the forest zone and Grass for the meadow, and never share.

### Terrain face detail

A `MaterialVariant` used on terrain can carry `TerrainDetail` children that give separate texture sets for the **top, side and bottom** of voxels. That is how a cliff gets rock on its sides and grass on top from a single material. If your custom grass looks like grass on vertical cliff faces, add a side detail. See [[Materials MaterialVariants and SurfaceAppearance]] for building variants and their texture budgets.

### Expanded Terrain (custom paintable materials)

As of October 2026, per the Roblox docs:

- **Up to 62 paintable terrain materials** per place, each with a custom colour and an optional MaterialVariant, created from the Terrain Editor material picker (the "+" button) and managed in the Terrain Material Manager.
- **Off by default; enabled per place** with the Expanded Terrain property on `Workspace`. Changing it restarts the place (Studio saves and closes a new place; reopen it).
- Includes rendering, storage and delivery changes that the docs say significantly reduce terrain's share of place file size and improve streaming and load times.
- Multiple shades of the same base material are possible, which removes the "one Grass per place" problem.

Limitations the docs list, which matter in production:

| Limitation | Consequence | Workaround |
|---|---|---|
| Custom physical properties on a MaterialVariant are not yet respected by custom terrain slots | Your "slippery crystal" slot walks like its base material | Pick a base material whose physics you want; or script the effect via `Humanoid.FloorMaterial` plus a zone check |
| Deleting a custom material still in use turns that terrain bright purple | Visible breakage after a cleanup | Replace (the Replace tool works with custom materials) before deleting |
| Terrain editing in Team Create may cause meshing or visual bugs | Teammates see different results | Do big terrain passes alone; snapshot first |
| After toggling Expanded Terrain in Team Create, exit and wait about 15 s before reopening | Half-converted sessions | Coordinate the switch |
| With streaming and a small streaming radius, terrain **thinner than 16 voxels** may disappear on clients or in playtests | Holes in thin floors and bridges | Keep terrain at least 16 voxels thick where players can see it |
| Places edited with custom materials during the early-access period need the property set to Enabled | Custom materials appear as grass | Set the property |

Unverified at time of writing: exactly what `Humanoid.FloorMaterial` returns for a custom slot (the base material is the likely answer). If footstep sounds or movement rules key off floor material, test it in your place before relying on it.

### Shape behaviour depends on material

Measured in the reference project, and worth repeating because it looks like a generator bug: on ramps and fractional occupancy, **Brick and Wood Planks rendered as full 4-stud cubes**, **Concrete snapped to 2-stud steps** and **Pavement to 1-stud steps**, while the other materials followed occupancy smoothly ([[Terrain Tools and Terrain API]]). The docs say materials "affect both shape and appearance", which agrees. Choose smooth materials for slopes, and if you want paved slopes, lay a mesh or part path on top.

### Physical feel

Terrain materials have default physical properties per material (Ice is slippery, for example). For default material slots, a MaterialVariant override can change them; for Expanded Terrain custom slots, not yet (above). Do not build gameplay on fine friction differences without testing on all devices; a client's character physics runs locally and the feel is what the player experiences ([[Physics Assemblies and Constraints]]).

### Material-driven gameplay: footsteps and surfaces

```lua
--!strict
-- Client: footstep sound set chosen by what the character stands on.
local Players = game:GetService("Players")

local FOOTSTEP_SET: { [Enum.Material]: string } = {
	[Enum.Material.Grass] = "Grass",
	[Enum.Material.LeafyGrass] = "Grass",
	[Enum.Material.Sand] = "Sand",
	[Enum.Material.Snow] = "Snow",
	[Enum.Material.Water] = "Splash",
	[Enum.Material.WoodPlanks] = "Wood",
	[Enum.Material.Rock] = "Stone",
	[Enum.Material.Slate] = "Stone",
	[Enum.Material.Basalt] = "Stone",
}

local function currentSet(humanoid: Humanoid): string
	local m = humanoid.FloorMaterial -- Air when airborne
	return FOOTSTEP_SET[m] or "Default"
end

local player = Players.LocalPlayer
player.CharacterAdded:Connect(function(char)
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid
	humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		local set = currentSet(humanoid)
		-- hand `set` to your footstep player ([[Sound Design for Games]])
	end)
end)
```

`FloorMaterial` works for parts and terrain alike, which is one reason to keep part materials meaningful even under a MaterialVariant: the sound system reads the base material.

---

## 3. Water

### Global properties

All terrain water in a place shares one look (Roblox docs, as of October 2026):

| Property | Range in the docs | Notes |
|---|---|---|
| `WaterColor` | Color3 | One colour for every lake, river and ocean |
| `WaterReflectance` | 0 (none) to 1 (high) | Reflections cost more at high graphics settings |
| `WaterTransparency` | 0 (opaque) to 1 (clear) | High transparency reveals the floor: paint it |
| `WaterWaveSize` | 0 (none) to 1 (large) | Waves move the visual surface; physics floats on the voxel surface |
| `WaterWaveSpeed` | 0 (still) to 100 (turbulent) | |

Some of these only show in playtesting unless Studio's Editor Quality Level is at maximum (Roblox docs). Judge water in Play, not in the edit viewport.

The global look is the biggest constraint. A swampy green lake and a tropical blue lagoon cannot both be terrain water. Options: change `WaterColor` on the client when the player enters a zone (works because properties set on the client only affect that client, and terrain water colour is a rendering property), or make one of them fake water. The reference project's rule was simpler: never fill large areas with terrain water; use a flat part for decorative water ([[Water Sky and Atmosphere Art]]).

```lua
--!strict
-- Client: per-zone water look. Call from your zone-change handler.
local TweenService = game:GetService("TweenService")
local terrain = workspace.Terrain

type WaterLook = { color: Color3, transparency: number, reflectance: number }

local function applyWaterLook(look: WaterLook, seconds: number)
	TweenService:Create(terrain, TweenInfo.new(seconds, Enum.EasingStyle.Sine), {
		WaterColor = look.color,
		WaterTransparency = look.transparency,
		WaterReflectance = look.reflectance,
	}):Play()
end
```

Do the swap where the player cannot see two water bodies at once (behind a ridge, in a tunnel), or both will change colour together in view.

### Shorelines and the liquid channel

The **Shorelines** upgrade lets a single voxel hold both water and another material, so water meets the shore smoothly instead of being clipped to voxel vertices (DevForum announcement of the full release; Roblox docs). Facts that matter:

- New places include it. **Existing places must be upgraded manually** (Terrain Editor, Create tab, Upgrade Shorelines), the upgrade is per place, **cannot be reverted after saving**, and it can change how existing shores look. Back up first.
- Scripts see the split through the voxel channel APIs: `ReadVoxelChannels(region, resolution, channelIds)` and `WriteVoxelChannels(region, resolution, channels)` with channels `SolidMaterial`, `SolidOccupancy` and `LiquidOccupancy` (Roblox docs samples). Solids that are fully occupied cannot also contain water.
- Old scripts using `ReadVoxels`/`WriteVoxels` still work, but they see one material per voxel. A shoreline-aware generator should use the channel API, or it will erase water when it writes the sand under it.

```lua
--!strict
-- Raise a lake: add water to empty or partly solid voxels below waterLevel, leaving solids intact.
local terrain = workspace.Terrain

local function fillWaterBelow(regionMin: Vector3, regionMax: Vector3, waterLevel: number)
	local region = Region3.new(regionMin, regionMax):ExpandToGrid(4)
	local ch = terrain:ReadVoxelChannels(region, 4, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" })
	local solidMat = ch.SolidMaterial
	local solidOcc = ch.SolidOccupancy
	local liquid = ch.LiquidOccupancy
	local size = ch.Size :: Vector3

	local minY = region.CFrame.Position.Y - region.Size.Y / 2
	for x = 1, size.X do
		for y = 1, size.Y do
			local cellTop = minY + y * 4
			for z = 1, size.Z do
				if cellTop <= waterLevel and solidOcc[x][y][z] < 1 then
					liquid[x][y][z] = 1
				end
			end
		end
	end
	terrain:WriteVoxelChannels(region, 4, {
		SolidMaterial = solidMat,
		SolidOccupancy = solidOcc,
		LiquidOccupancy = liquid,
	})
end
```

Keep regions modest (chunk large lakes) and read back after writing, as with any terrain write ([[Terrain Tools and Terrain API]]). The returned tables' exact shape beyond what the docs samples show (`[x][y][z]` indexing and a `Size` entry) is from those samples; verify in your Studio version.

### Swimming and floating

- Characters enter the `Swimming` Humanoid state in terrain water automatically. Custom controllers must handle water themselves ([[Custom Character Controllers]]).
- Unanchored parts float or sink in terrain water depending on density; a light boat floats with no script. Fake water gives none of this, which is why the rule is "terrain water only where players swim or things float".
- Swimming has no stamina, no drowning and no currents by default. Rivers that push the player are scripted (a `VectorForce` or velocity nudge while `Swimming` inside a zone).

### Underwater effects

When the camera is below the surface, players expect a tint, fog and muffled audio. Detect it by sampling the liquid channel at the camera:

```lua
--!strict
-- Client: is the camera underwater? Sample a single 4-stud cell.
local RunService = game:GetService("RunService")
local terrain = workspace.Terrain

local function cameraUnderwater(cam: Camera): boolean
	local p = cam.CFrame.Position
	local region = Region3.new(p - Vector3.new(2, 2, 2), p + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local ch = terrain:ReadVoxelChannels(region, 4, { "LiquidOccupancy" })
	return ch.LiquidOccupancy[1][1][1] > 0.5
end

local wasUnder = false
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.1 then
		return -- 10 checks per second is plenty
	end
	accumulator = 0
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local under = cameraUnderwater(cam)
	if under ~= wasUnder then
		wasUnder = under
		-- toggle a ColorCorrection, Atmosphere density, and an audio low-pass here
	end
end)
```

The 4-stud cell means the switch happens up to a few studs from the visible surface, and waves move the visible surface while the voxels stay put. For a precise transition at a flat lake, compare the camera's Y to a known water level per lake instead. Lighting and audio recipes: [[Atmosphere Sky Clouds and Post-Processing]], [[Spatial Audio and Mixing]].

### Fake water, when and how

Fake water (a flat part or mesh with a transparent material, scrolling texture, and a shoreline foam strip) is right for oceans that frame the map, moats, fountains, and any water that needs a different colour from the place's terrain water. It costs one surface instead of a volume of voxels, takes any colour, and can be stylised. It cannot be swum in or float things without scripts. Build details are in [[Water Sky and Atmosphere Art]].

---

## 4. Grass decoration

- `Terrain.Decoration = true` animates grass blades on the Grass material; `GrassLength` accepts 0.1 to 1; the blades sway with the global wind (`Workspace.GlobalWind`), and the player's Reduce Motion setting slows the animation but not its direction (Roblox docs, as of October 2026).
- Cost (rule of thumb): decoration is fill-rate and vertex heavy, and Roblox scales it with graphics quality, so low-end devices see less of it. That means your art cannot depend on it: a meadow that only looks lush with decoration looks bald on a phone. Paint the ground texture to read as grass without blades.
- Decoration hides small props, pickups and dropped items. If loot lands on grass, raise it or give it a glow.
- It is place-wide; you cannot have decoration in one zone only. A zone that should feel "mown" uses a different material (Leafy Grass, or a custom slot).

---

## 5. Performance

### Rendering

Terrain renders through its own meshing and level-of-detail system, so a large terrain area is usually cheaper than the same area built from many parts. Costs grow with (rule of thumb, consistent with the reference project's experience):

- **Visible surface complexity**: caves, overhangs, thin spires and many small bumps create more triangles than flat or gently rolling ground.
- **Material boundaries**: blending between materials costs more than large single-material areas. Paint in broad regions; avoid speckled noise of three materials.
- **Water surface area** in view, especially with reflections at high settings.
- **Grass decoration** on large flat areas.

Profile with the MicroProfiler on a low-end device with the camera at the worst viewpoint (usually the highest spot looking across the map) ([[MicroProfiler Guide]], [[Rendering Performance]]).

### Memory and place size

- Terrain voxels are stored in the place file and in memory. Big flat sheets of terrain far below the play area, or solid fill hundreds of studs deep, cost storage for nothing. Fill only as deep as the surface material needs (the reference project painted surfaces about 16 studs, 4 cells, deep so slopes did not show the underlying material) plus what streaming needs (16 voxels thick with Expanded Terrain and small radii, per the docs).
- Terrain snapshots (`TerrainRegion` objects from `CopyRegion`) kept in ServerStorage also count toward place size. Keep a few named snapshots, not one per edit, and delete old ones after a release ([[Case Study - Instance Cleanup and Place Size]]).
- The docs say Expanded Terrain substantially reduces terrain's contribution to file size, but also that thinning terrain below 16 voxels saves little or no memory there. Do not hollow terrain out as an optimisation under Expanded Terrain.

### Streaming

With `StreamingEnabled`, terrain streams in regions around the player like parts ([[Instance Streaming]], [[Level of Detail and Model Streaming]]). Consequences:

- **Raycasts on the client can miss terrain that has not streamed in.** A client-side grounding check far from the player returns nothing. Do world-wide terrain queries on the server, or request streaming around the target first.
- **Thin terrain may vanish** at small radii (above).
- A teleport into an unloaded area may show the player falling before terrain arrives; standard streaming practice (`RequestStreamAroundAsync` before moving the character) applies.

### Physics

Terrain collision is generally efficient: the character collides with one large terrain object instead of hundreds of parts. Two caveats:

- Many unanchored parts resting on terrain still cost physics like on any surface; sleep behaviour matters more than the ground type ([[Physics Performance]]).
- Fast projectiles hitting thin terrain can tunnel through; use raycasts for hit detection, not touched events.

### Runtime terrain edits

Runtime edits (craters, digging, building with terrain) are powerful and easy to abuse:

- **Every server-side terrain write replicates** to all clients in range. A crater per explosion every 0.2 s in a 30-player server is a steady stream of voxel data and remeshing on every client.
- Remeshing a changed chunk is work on each client; many small edits across a wide area are worse than a few in one place.
- Rate-limit and coalesce: queue crater requests on the server, merge nearby ones, and apply at most a few writes per second. Clamp radii.
- Never let a client request arbitrary terrain writes; validate position (near the player, inside the allowed zone), size and rate on the server ([[Server Authority and Validation]], [[Rate Limiting and Abuse Prevention]]).
- Keep a way to restore: rounds that dig up the map should reset from a stored `TerrainRegion` with `PasteRegion` between rounds, not from regenerating.

```lua
--!strict
-- Server: coalesced, rate-limited craters.
local terrain = workspace.Terrain
local MAX_RADIUS = 12
local WRITES_PER_SECOND = 4

local pending: { { pos: Vector3, r: number } } = {}

local Craters = {}

function Craters.request(pos: Vector3, radius: number)
	radius = math.clamp(radius, 2, MAX_RADIUS)
	for _, c in pending do
		if (c.pos - pos).Magnitude < (c.r + radius) * 0.5 then
			c.r = math.min(MAX_RADIUS, math.max(c.r, radius) + 1) -- merge into an existing crater
			return
		end
	end
	table.insert(pending, { pos = pos, r = radius })
end

task.spawn(function()
	while true do
		task.wait(1 / WRITES_PER_SECOND)
		local c = table.remove(pending, 1)
		if c then
			terrain:FillBall(c.pos, c.r, Enum.Material.Air)
		end
	end
end)

return Craters
```

Add a cap on `#pending` (drop the oldest beyond 20 or so) so a flood of explosions cannot build an unbounded backlog.

### Parallel reads

The engine reference marks `ReadVoxels` and `ReadVoxelChannels` as safe to call in parallel (Roblox docs tag them "Write Parallel"; as of October 2026). Heavy analysis (finding flat spots for spawning, computing slope maps) can run in Actors; writes stay in serial code ([[Parallel Luau and Actors]]).

---

## 6. A materials and water plan, worked example

A small adventure map with a meadow hub, a pine forest, a desert, a snowy peak and a swamp:

| Zone | Ground | Water | Notes |
|---|---|---|---|
| Meadow hub | Grass (decoration on) | Small terrain pond (swimmable) | The only place with blades; looks fine without them on phones because the texture is grass |
| Pine forest | Leafy Grass, Ground paths, Rock outcrops | None | Different material from the meadow so it can be tinted independently |
| Desert | Sand, Sandstone cliffs | Oasis as fake water (teal) | Different colour from the place's terrain water, so not terrain |
| Snowy peak | Snow, Glacier, Slate sides | Frozen lake: Ice material | Ice is a ground material here, no water |
| Swamp | Mud, Ground, custom "Moss" slot (Expanded Terrain) | Terrain water, swimmable | `WaterColor` swapped to murky green on entering, out of sight of the hub pond |

Decisions this table forces early: whether Expanded Terrain is on (needed for the Moss slot and for a second Grass shade later), which water is real, and that `WaterColor` is a client-side zone property. Writing it down at blockout avoids discovering in month three that the swamp and the hub pond share a colour. Zone identity beyond materials is in [[Zone and Biome Art Direction]].

---

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Recolouring or overriding a base material for one zone | Every zone (and every part) using it changes | Different material, or an Expanded Terrain slot |
| Deleting a custom material still in use | Bright purple terrain | Replace first, then delete |
| Shoreline upgrade without backup | Irreversible look change | Back up the place, upgrade, review shores |
| Old ReadVoxels/WriteVoxels generator after the shorelines upgrade | Water erased where solids are written | Use the voxel channel APIs |
| Judging water in the edit viewport | Different look in game | Playtest, or max Editor Quality Level |
| Terrain water for a decorative ocean | Frame cost, global colour lock | Flat part water |
| Art that depends on grass blades | Bald ground on phones | Paint the ground texture to read as grass |
| Thin terrain bridges with streaming | Holes on clients | 16+ voxels thick |
| Unthrottled runtime craters | Network and remesh spikes | Coalesce and rate-limit on the server |
| Client terrain raycasts far from the player | Misses, floating props | Server queries or stream in first |

---

## Checklist

- [ ] Terrain versus meshes decided per area and written down.
- [ ] Material list per zone; no base material recoloured or overridden for a single zone.
- [ ] Expanded Terrain decision made before heavy painting (it restarts the place).
- [ ] Terrain face details on variants used for cliffs.
- [ ] Shorelines upgraded (with a backup) or confirmed present; generators use voxel channels.
- [ ] Each water body classified: terrain (swim, float) or fake (look only).
- [ ] Water look tuned in Play; per-zone `WaterColor` swaps happen out of sight.
- [ ] Underwater detection with tint, fog and audio low-pass.
- [ ] Ground readable without grass decoration on low settings.
- [ ] Terrain at least 16 voxels thick where streaming radii are small.
- [ ] Runtime terrain writes validated, coalesced and rate-limited; reset from a snapshot.
- [ ] Worst viewpoint profiled on a low-end device.

## See also

[[Terrain Tools and Terrain API]], [[Water Sky and Atmosphere Art]], [[Materials MaterialVariants and SurfaceAppearance]], [[Zone and Biome Art Direction]], [[Level of Detail and Model Streaming]], [[Instance Streaming]], [[Rendering Performance]], [[Physics Performance]], [[Procedural World Generation]], [[Foliage Props and Scatter]], [[Collision and Physics Geometry]]

## Connected notes
<!-- auto-links:start -->
[[Terrain Materials and Painting]] · [[Links - Terrain]] · [[MaterialService and Custom Materials]] · [[Noise Functions and Terrain Generation]] · [[AI Material and Texture Generation]] · [[Materials and Surfaces Start Here]]
<!-- auto-links:end -->
