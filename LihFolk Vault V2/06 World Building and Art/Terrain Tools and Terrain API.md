---
tags: [world-building, terrain, voxels, api, materials, tools, type/reference, area/world, level/intermediate, api/Terrain, area/modeling, api/Atmosphere]
---
# Terrain Tools and Terrain API

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Recolouring a material for one area -> Use a different material
> - Avoid: Using Studio undo to recover terrain -> Snapshot with CopyRegion first
> - Avoid: Regenerating a whole area to fix a corner -> Edit the smallest region; snapshot
> - Floor material list per zone documented; no shared material recoloured.
> - Snapshot (CopyRegion) taken and named before every edit.
> - Writes chunked, read back, verified.
>
> Cost: TL;DR ~150 tok · whole note ~4.5k tok. Read more: ## The scripting API · ## Recipes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox Terrain is a voxel field: the world is divided into **4 x 4 x 4 stud cells**, each with a **material** and an **occupancy** between 0 and 1 (Roblox docs). The engine builds a smooth surface from those numbers, renders it with its own LOD, and collides against it. Terrain is the cheapest way to cover large ground areas, make caves and cliffs, and fill water bodies; it is also global, hard to undo, and full of measured quirks. This note covers the Studio tools briefly, the scripting API in depth, and the hard lessons of one production game that lost and rebuilt its terrain.

## When to use Terrain (and when not)

| Use Terrain for | Avoid Terrain for |
|---|---|
| Rolling ground, hills, mountains, valleys | Flat cartoon floors with crisp edges (Parts or meshes look cleaner) |
| Caves, overhangs, tunnels | Small, precise platforms (4-stud cells cannot be thinner) |
| Natural cliffs blended into ground | Stylised hand-painted cliffs (meshes) |
| Natural water bodies (lakes, rivers) | Huge oceans or water that must look exact (a flat part is cheaper; see [[Water Sky and Atmosphere Art]]) |
| Grass with animated blades (`Decoration`) | Areas that need per-area colour variation of one material (colours are global) |

One production game ended up with **terrain for realm floors** and **no terrain in its hub**: the hub's flat cartoon look came out better as SmoothPlastic Parts and meshes, and terrain grass under the hub's paving kept poking through.

## The model: cells, occupancy, materials

- **Cell = 4 studs.** `Terrain:WorldToCell(pos)` gives cell coordinates; `CellCornerToWorld` gives the lower corner; `CellCenterToWorld` adds (2, 2, 2) (Roblox docs).
- **Occupancy** (0..1) is how full a cell is. Partial occupancy in the top cell makes a surface between cell boundaries, which is how slopes and smooth ground are formed.
- **Material** is one `Enum.Material` per cell from the 22 terrain materials (Asphalt, Basalt, Brick, Cobblestone, Concrete, Cracked Lava, Glacier, Grass, Ground, Ice, Leafy Grass, Limestone, Mud, Pavement, Rock, Salt, Sand, Sandstone, Slate, Snow, Water, Wood Planks) plus Air.
- **Water** is no longer a solid material in the channel API: a water-only voxel is Air with `LiquidOccupancy` (Roblox docs). The older `ReadVoxels` / `WriteVoxels` still use `Enum.Material.Water`.
- **Extents:** cell coordinates -32,000 to 32,000 on each axis (about +-128,000 studs) (Roblox docs).

### Global properties

| Property | Scriptable | Notes |
|---|---|---|
| `MaterialColors` (per material via `SetMaterialColor`) | method yes | **Global per material for the whole place.** Air and Water have no colour |
| `Decoration` | No (Studio) | Animated grass on the Grass material |
| `GrassLength` | No (Studio) | 0.1 to 1 |
| `WaterColor`, `WaterReflectance`, `WaterTransparency`, `WaterWaveSize`, `WaterWaveSpeed` | Yes | Global water look |
| Material textures | via [[MaterialService]] overrides | Global; see [[Materials MaterialVariants and SurfaceAppearance]] |

"Global" is the single most important fact about terrain art. If realm 1 has green grass and realm 2 wants yellow grass, **use a different material** (Grass vs LeafyGrass) rather than recolouring. One production game assigned one floor material per zone (Grass, Mud, Limestone, Sandstone, Basalt, Snow, Pavement, Asphalt, Rock) and documented that list so nobody recoloured a material another zone used.

## Studio tools in brief

The Terrain Editor (Roblox docs):
- **Generate:** biomes (Arctic, Dunes, Canyons, Lavascape, Water, Mountains, Hills, Plains, Marsh) over a selected region, "in seconds".
- **Import:** a heightmap (1 pixel = 4 studs, up to 4096 x 4096, .png/.jpg) plus a colour map or a single material.
- **Select / Transform:** copy, cut, paste, move, rotate, scale regions.
- **Fill / Replace:** fill a region with a material, or replace one material with another.
- **Sea Level:** create or evaporate water in a region.
- **Brushes:** Draw, Sculpt, Smooth, Flatten, Paint (sphere / box / cylinder, 1 to 64 studs; Ctrl subtracts, Shift smooths).

Brushes are great for organic shaping by hand. For anything that must match gameplay geometry (walk areas, gates, arena floors), use the API so it is exact and repeatable.

## The scripting API

### Fill methods

| Method | Shape | Notes |
|---|---|---|
| `FillBlock(cframe, size, material)` | Oriented box | Overwrites existing terrain in the volume |
| `FillBall(center, radius, material)` | Sphere | |
| `FillCylinder(cframe, height, radius, material)` | Cylinder | |
| `FillWedge(cframe, size, material)` | Wedge | Ramps |
| `FillRegion(region3, 4, material)` | Axis-aligned, full occupancy | Region must be grid-aligned (`ExpandToGrid(4)`) |
| `ReplaceMaterial(region3, 4, from, to)` | Material swap | Grid-aligned region |
| `Clear()` | Everything | Irreversible without a snapshot |

Fill methods compute partial occupancy at the shape's boundary, so `FillBlock` with a rotated CFrame produces a smooth slope.

### Voxel read and write

```text
ReadVoxels(region: Region3, resolution: 4) -> materials[x][y][z], occupancies[x][y][z]
WriteVoxels(region: Region3, resolution: 4, materials, occupancies)
ReadVoxelChannels(region, 4, {"SolidMaterial","SolidOccupancy","LiquidOccupancy"}) -> {[channel] = array}
WriteVoxelChannels(region, 4, {SolidMaterial = ..., SolidOccupancy = ..., LiquidOccupancy = ...})
```

Rules (Roblox docs): the region **must be aligned to the voxel grid**, resolution **must be 4**, and a region **cannot exceed 4,194,304 voxels** (an error is thrown). Arrays are 1-based, indexed `[x][y][z]`, and expose a `Size` (Vector3) of the region in voxels.

4,194,304 voxels is, for example, 512 x 32 x 256 cells = 2,048 x 128 x 1,024 studs. Large maps must be processed in chunks.

### CopyRegion and PasteRegion: snapshots

`Terrain:CopyRegion(region: Region3int16)` returns a `TerrainRegion` (a cell-coordinate copy); `PasteRegion(terrainRegion, cornerCell: Vector3int16, pasteEmptyCells)` writes it back. A `TerrainRegion` can be parented to `ServerStorage` and saved with the place. Its data does not replicate between server and client (Roblox docs).

**Snapshot before every terrain edit.** This is the rule one production game adopted after an incident: an attempt to recover terrain with Studio's undo went about 40 waypoints back and rolled back other people's changes in the shared session. Studio's undo history is shared across everything happening in that Studio session; it is not a terrain backup. See [[Safe Changes in a Shared Place]].

```lua
--!strict
-- Command bar / plugin: snapshot a world-space box of terrain into ServerStorage.
local ServerStorage = game:GetService("ServerStorage")
local terrain = workspace.Terrain

local function cellRegion(minWorld: Vector3, maxWorld: Vector3): Region3int16
	local a = terrain:WorldToCell(minWorld)
	local b = terrain:WorldToCell(maxWorld)
	return Region3int16.new(
		Vector3int16.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)),
		Vector3int16.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	)
end

local function snapshot(name: string, minWorld: Vector3, maxWorld: Vector3): TerrainRegion
	local region = cellRegion(minWorld, maxWorld)
	local copy = terrain:CopyRegion(region)
	copy.Name = name
	copy:SetAttribute("CornerCell", Vector3.new(region.Min.X, region.Min.Y, region.Min.Z))
	local folder = ServerStorage:FindFirstChild("TerrainSnapshots") or Instance.new("Folder")
	folder.Name = "TerrainSnapshots"
	folder.Parent = ServerStorage
	copy.Parent = folder
	return copy
end

local function restore(copy: TerrainRegion)
	local c = copy:GetAttribute("CornerCell") :: Vector3
	-- pasteEmptyCells = true so Air in the snapshot clears terrain added since
	terrain:PasteRegion(copy, Vector3int16.new(c.X, c.Y, c.Z), true)
end

-- Example: snapshot one zone before editing
snapshot("Zone3_" .. os.date("!%Y%m%d_%H%M"), Vector3.new(1200, -40, -260), Vector3.new(1840, 200, 260))
```

Name snapshots with the date and the area; delete old ones once the change is verified in play (they add to place size).

## Measured quirks (one production game)

These were measured with raycasts against WriteVoxels test ramps. Treat them as "verify in your place" rather than documented behaviour.

### The rendered surface sits above the voxel top

A full cell with Air above it rendered its surface about **2 studs above the cell top**. The project's working formula: the rendered top of a column is about `cellBottom + 2 + 4 * occupancy` of the top cell. In practice:
- A 4-stud `FillBlock` surfaced about 2.0 studs above the block's top. To place a floor at height `H`, the project filled the block 1.65 studs lower (plus a 0.15 lift for grass).
- A computed surface (cell bottom + occupancy x 4) sat 0.8 to 1.6 studs below the rendered surface, so props placed from the computed height floated or sank.

The robust fix is to **never compute the surface; raycast it.** Place props with a terrain-only raycast (below), and calibrate any generator against a raycast once per material.

### Some materials render blocky

On ramps and fractional occupancy, **Brick and WoodPlanks rendered as solid 4-stud cubes** (any occupancy above 0 drew a full cell), **Concrete snapped to 2-stud steps** and **Pavement to 1-stud steps**; every other material followed occupancy smoothly. A floor painted with Brick therefore showed 3 to 4-stud terraces everywhere, which looked like a heightfield bug but was the material. Use those materials only on flat ground or where blocky is the intent.

### Surface material depth

Paint the surface material about **16 studs deep** (4 cells). Shallow paint lets the underlying material show on slopes and at cliff edges after smoothing.

### One write per call, then read back

In Studio, large terrain operations in a single command freeze the editor and occasionally partially fail. The project's rule: one `WriteVoxels` per call, chunked, followed by a `ReadVoxels` of the same region to verify. A wipe that went unnoticed (the place's `CountCells()` returned 0 one day; cause never found) was only recoverable because an earlier survey had recorded rendered height and material every 4 studs across the realm.

### Captures after terrain writes

Studio may not finish remeshing immediately. Moving the camera and waiting a few seconds before a screenshot avoids capturing half-updated terrain.

## Recipes

### Chunked heightfield write

```lua
--!strict
-- Write a heightfield over an XZ area in chunks. heightAt(x, z) returns the desired surface Y
-- in studs; materialAt(x, y, z, surfaceY) returns the material for a solid cell.
local terrain = workspace.Terrain
local CELL = 4
local CHUNK = 64 -- cells per side per write (64 x H x 64 stays far under the voxel limit)

type HeightFn = (x: number, z: number) -> number
type MaterialFn = (x: number, y: number, z: number, surfaceY: number) -> Enum.Material

local function writeHeightfield(minX: number, minZ: number, maxX: number, maxZ: number,
	minY: number, maxY: number, heightAt: HeightFn, materialAt: MaterialFn)
	for cx = minX, maxX - 1, CHUNK * CELL do
		for cz = minZ, maxZ - 1, CHUNK * CELL do
			local region = Region3.new(
				Vector3.new(cx, minY, cz),
				Vector3.new(math.min(cx + CHUNK * CELL, maxX), maxY, math.min(cz + CHUNK * CELL, maxZ))
			):ExpandToGrid(CELL)
			local size = region.Size / CELL
			local corner = region.CFrame.Position - region.Size / 2
			local mats, occs = {}, {}
			for ix = 1, size.X do
				mats[ix], occs[ix] = {}, {}
				local wx = corner.X + (ix - 0.5) * CELL
				for iy = 1, size.Y do
					mats[ix][iy], occs[ix][iy] = {}, {}
					local cellBottom = corner.Y + (iy - 1) * CELL
					for iz = 1, size.Z do
						local wz = corner.Z + (iz - 0.5) * CELL
						local h = heightAt(wx, wz)
						-- fraction of this cell below the target height
						local occ = math.clamp((h - cellBottom) / CELL, 0, 1)
						occs[ix][iy][iz] = occ
						mats[ix][iy][iz] = if occ > 0 then materialAt(wx, cellBottom, wz, h) else Enum.Material.Air
					end
				end
			end
			terrain:WriteVoxels(region, CELL, mats, occs)
			task.wait() -- let Studio breathe between chunks
		end
	end
end
```

Remember the measured surface offset: if the rendered surface sits about 2 studs above `h` in your place, subtract a calibrated bias from `h` before writing.

### Grounding props on terrain only

Ground props with a raycast that **only hits Terrain**. A cast that merely excludes the prop being placed will land on tree trunks, rocks and other props. Overlap-test the placed model with `GetPartsInPart` rather than `GetPartBoundsInBox`, which over-reports badly against large mesh bounding boxes (measured).

```lua
--!strict
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- Returns the terrain surface position and material under (x, z), or nil.
local function terrainBelow(x: number, z: number, fromY: number): (Vector3?, Enum.Material?)
	local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -fromY - 1000, 0), terrainOnly)
	if hit then
		return hit.Position, hit.Material
	end
	return nil, nil
end

-- Sink a model's bottom `sink` studs into the ground at its current XZ.
local function ground(model: Model, sink: number)
	local pivot = model:GetPivot()
	local boxCf, size = model:GetBoundingBox()
	local bottomOffset = (boxCf.Position.Y - size.Y / 2) - pivot.Position.Y
	local pos = terrainBelow(pivot.Position.X, pivot.Position.Z, pivot.Position.Y + 200)
	if pos then
		local targetPivotY = pos.Y - sink - bottomOffset
		model:PivotTo(pivot + Vector3.new(0, targetPivotY - pivot.Position.Y, 0))
	end
end
```

That project snapped 276 floating ground props this way (recording the amount lowered in an attribute) while skipping intentional floaters such as rift rocks and hanging cocoons.

### Painting paths

A path is a material-only change: keep occupancy, change the material of surface cells along a polyline. Use a **core width plus a dithered edge** (for example core +-9 studs, dithered to +-12.5) so the border looks natural. One production game lost its curved paths when terrain was rebuilt from a survey that only had an old straight strip; keep path polylines as data (a ModuleScript or JSON) so they can be repainted.

### Clearing terrain under water or paving

When terrain grass grows through a flat water part or paving, clear only the columns over that footprint (cells at or above the water/paving height) and store a backup. One project cleared 632 columns over a stream and removed 97 grass tufts that were standing in the water.

## Water

Terrain water is real: it has swimming, buoyancy, waves and refraction. It is also global in look (one `WaterColor` for the place) and expensive over large areas. One production game's rule: **never fill large areas with terrain water; a flat part fakes it.** Use terrain water for swimmable lakes and rivers; use a flat transparent part (with a scrolling texture) for decorative oceans, moats and backgrounds. See [[Water Sky and Atmosphere Art]].

## Performance

- Terrain has its own LOD and is generally cheap for its area. Its cost grows with **visible surface complexity** (caves, overhangs, many material borders) rather than volume.
- `Decoration` grass costs fill rate on low-end devices; Roblox scales it down with graphics quality.
- Terrain counts toward place size; snapshots in ServerStorage do too.
- With streaming, terrain streams like parts. See [[Level of Detail and Model Streaming]] and [[Instance Streaming]].

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Recolouring a material for one area | The whole place changes | Use a different material |
| Using Studio undo to recover terrain | Rolls back unrelated work | Snapshot with CopyRegion first |
| Regenerating a whole area to fix a corner | Lost hand edits, paths, props float | Edit the smallest region; snapshot |
| Computing surface height from voxels | Props float or sink 1 to 2 studs | Raycast terrain only |
| Brick / WoodPlanks floors on slopes | Visible 4-stud terraces | Smooth materials on slopes |
| Ungridded region in ReadVoxels | Error | `Region3:ExpandToGrid(4)` |
| One huge WriteVoxels | Error over 4,194,304 voxels, Studio freeze | Chunk and `task.wait()` |
| Huge terrain ocean | Frame drops, global water look | Flat part water |

## Checklist

- [ ] Floor material list per zone documented; no shared material recoloured.
- [ ] Snapshot (CopyRegion) taken and named before every edit.
- [ ] Writes chunked, read back, verified.
- [ ] Surface offset calibrated by raycast for your materials.
- [ ] Props grounded with terrain-only raycasts; overlaps tested with GetPartsInPart.
- [ ] Paths stored as data; repaint scripted.
- [ ] Terrain water only where players swim.

## See also

- [[Procedural World Generation]], [[Level Design for Roblox]], [[Foliage Props and Scatter]]
- [[Materials MaterialVariants and SurfaceAppearance]], [[Water Sky and Atmosphere Art]], [[Collision and Physics Geometry]]
- [[Raycasts Shapecasts and Spatial Queries]], [[Safe Changes in a Shared Place]], [[Version History and Backups]]

## Connected notes
<!-- auto-links:start -->
[[Terrain Deep Dive - Materials Water and Performance]] · [[Terrain Materials and Painting]] · Links - Terrain · MCP Workflows for Building Worlds · Noise Functions and Terrain Generation · Environment and Level Pipeline
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Roads, Rivers and Paths Carved Along Curves in Terrain]] · [[MCP Workflows for Building Worlds]] · [[Noise Functions and Terrain Generation]] · [[Parts Unions and MeshParts]] · [[Zone and Biome Art Direction]] · [[Voxel Art - Studs Outlines and Style Kits]] · [[Grid Placement and Player Building Systems]]
<!-- related:end -->
