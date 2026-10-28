---
tags: [terrain, materials, painting, materialvariant, terraindetail, procedural, world-building]
---
# Terrain Materials and Painting

The vault already covers terrain's data model and API ([[Terrain Tools and Terrain API]]), and what is global versus local about terrain materials, water, Expanded Terrain limits and performance ([[Terrain Deep Dive - Materials Water and Performance]]). This note is about **the craft of painting**: choosing a small palette of ground materials that reads well, letting `TerrainDetail` do slope painting for you, painting by hand without the result looking like a paint program, painting procedurally by slope, height and noise with a correct and chunked script, importing a colormap, and dressing terrain with the vault's own CC0 textures. The goal is ground that tells the player where to walk, not ground that shows off how many materials exist.

## 1. Paint for gameplay first

Terrain paint is a navigation tool before it is decoration. Players read ground the way they read UI: contrast says "this matters".

| Ground role | What the paint should say | Typical materials |
|---|---|---|
| Main path | "Walk here" | Lighter, smoother, lower-detail: Ground, Sand, Pavement, Cobblestone |
| Open play space | "You can be here" | Mid-value, calm: Grass, LeafyGrass, Snow |
| Edges and slopes | "Not a path" | Darker or busier: Rock, Slate, Basalt |
| Hazards | "Danger" | High contrast or warm: CrackedLava, Mud, Ice |
| Landmarks | "Look here" | The one unusual material in the area: Salt, Glacier, a custom variant |

Rules of thumb that follow:

- **Three to five materials per view.** More than that and nothing stands out. A meadow with Grass, LeafyGrass, Ground for paths and Rock for outcrops already reads as rich.
- **Value contrast beats hue contrast.** Check a screenshot in grayscale. If the path disappears, change its value, not its colour ([[Environment Art Styles]]).
- **The path is lighter than its surroundings** in almost every successful level, because lighter surfaces pull the eye ([[Level Design for Roblox]]).
- **Hazards need a rule, not just a look.** If Mud slows players, every Mud voxel must slow players; do not also use Mud as a decorative edge elsewhere.

## 2. Let the material paint slopes: TerrainDetail

The cheapest painting is painting you never do. A `MaterialVariant` used as a terrain override can hold up to three `TerrainDetail` children, one per face direction: top (+Y), bottom (-Y) and side (horizontal). Without any, every face uses the variant's own maps (Roblox docs, as of October 2026, `TerrainDetail` reference). If several details share a face under one variant, only one takes effect.

That means a single material can be **grass on top and rock on the sides**. Paint a whole hillside with one material and cliffs read as rock automatically. This is the same trick the built-in Grass uses, and the materials docs list per-face asset ids for several built-in terrain materials.

### Building one from the CC0 library

Using sets from [[CC0 Texture and HDRI Library]]:

| Face | Source set | Maps | Size | StudsPerTile (start) |
|---|---|---|---|---|
| Top | `forest_ground_04` | diff, nor_gl, rough | 512 | 8 to 12 |
| Side | `mossy_rock` | diff, nor_gl, rough | 512 | 12 to 16 |
| Bottom | (often unneeded) | reuse side maps | | |

Steps: create the variant on base Grass (or whichever base you are overriding) in the Material Manager, enable **Set as Override**, click **Create** for each face under **Terrain Details**, expand each face and assign its maps, Studs Per Tile and Pattern (Roblox docs). Use **Organic** for both faces here: ground and rock have no grid lines.

Why 512: the docs say terrain displays "512x512 across 8x8 studs". A 2048 source would cost sixteen times the memory of a 512 for detail the terrain shader is not designed to show. A side face seen from far away can often drop to 256.

Nuances:

- **Overrides are global** ([[Materials MaterialVariants and SurfaceAppearance]] has the full story). A grass-top-rock-side override on Grass also changes every *Part* whose material is Grass. If you have grass-material parts, either accept it or override a terrain material no parts use.
- **The side face changes with the voxel face direction, not the slope angle you see.** On smooth terrain, gentle slopes still show top texture and steeper ones switch to side texture; the exact angle and blend are not documented. Paint a test hill with slopes at 15, 30, 45 and 60 degrees and look before committing (rule of thumb).
- **Expanded Terrain changes the economics.** With up to 62 paintable materials (per the Deep Dive note's reading of the docs), you are no longer limited to one look per base material, so per-zone grass with its own rock sides becomes possible without fighting override slots.

## 3. Hand painting that does not look hand painted

The Paint tool (Terrain Editor, Edit tab) "paints a terrain material over an existing material or replaces one material with another". Brush shapes are sphere, box or cylinder, base size 1 to 64 studs, and holding Alt (Option on Mac) while clicking opens the material picker (Roblox docs, as of October 2026). The Fill tool's **Replace** swaps one material for another inside a region.

What separates good hand painting from obvious hand painting:

1. **Block in big, then break edges.** First pass: large brush, one material per region, straight boundaries. Second pass: a brush a third the size, wobbling along every boundary so no edge is straight for more than about 20 studs. Third pass: tiny dabs of the neighbouring material across the line, both ways. Natural transitions interleave; they do not gradient.
2. **Paint where things would collect.** Dirt where feet go (doorways, path centres, around benches), mud and darker ground in hollows, rock where water would have washed soil away (ridges, slope tops), sand and pebbles at the water line.
3. **Paint under props, not around them.** A rock mesh sitting on grass looks pasted on. Paint a ring of Ground or Rock under and slightly beyond it so the prop seems to grow out of the terrain ([[Foliage Props and Scatter]]).
4. **Respect the blocky materials.** Brick and WoodPlanks render as full 4-stud cubes, Concrete in 2-stud steps and Pavement in 1-stud steps on slopes (measured in the reference project, see [[Terrain Tools and Terrain API]]). Never paint them on slopes. For a paved slope, lay parts or a mesh on top.
5. **Do the big paint pass alone.** The docs warn terrain editing in Team Create may cause meshing or visual bugs. Snapshot first ([[Version History and Backups]]).

## 4. Procedural painting by slope, height and noise

On large maps hand painting does not scale, and it drifts in style between sessions. A paint pass script gives a consistent base that you then touch up by hand. The approach:

- Read solid material and occupancy for a chunk.
- For each solid voxel at the surface (solid, with emptier air above), estimate the surface normal from the occupancy gradient.
- Choose a material from rules: slope bands first, then height bands, then noise to break the bands.
- Write **only the material channel**, leaving occupancy and water untouched.

### API facts that shape the script

From the `Terrain` reference (Roblox docs, as of October 2026):

- `ReadVoxels`, `WriteVoxels`, `ReadVoxelChannels` and `WriteVoxelChannels` all require **resolution 4** and a **grid-aligned region** (use `Region3:ExpandToGrid(4)`).
- Each call is limited to **4,194,304 voxels**; larger regions throw.
- `ReadVoxelChannels` supports `SolidMaterial`, `SolidOccupancy` and `LiquidOccupancy`; the docs note water is represented by `LiquidOccupancy` in that API. `WriteVoxelChannels` accepts one or more channels in a single call.
- Read methods are marked thread-safe; write methods are not.

Writing only `SolidMaterial` through the channel API is the cleanest way to repaint without touching shape or water. Places that have not done the Shorelines upgrade should still accept the channel calls, but that is not stated explicitly; test on a copy first (unverified).

### The script

```lua
--!strict
-- Server or command bar: repaint the surface of a region by slope, height and noise.
-- Writes only the SolidMaterial channel, so shape and water are untouched.
local terrain = workspace.Terrain

local RES = 4
local CHUNK = 64 -- voxels per side: 64^3 = 262,144, far under the 4,194,304 limit

type Rules = {
	cliffSlopeDeg: number, -- at or above: cliff material
	steepSlopeDeg: number, -- at or above: steep material
	snowLineY: number, -- world Y above which flat ground becomes snow
	beachTopY: number, -- world Y below which flat ground becomes sand
	noiseScale: number, -- studs per noise feature
	noiseMix: number, -- 0..1, how much noise shifts the slope thresholds
}

local RULES: Rules = {
	cliffSlopeDeg = 50,
	steepSlopeDeg = 32,
	snowLineY = 220,
	beachTopY = 6,
	noiseScale = 48,
	noiseMix = 0.35,
}

-- Only these materials may be repainted. Hand-painted paths and hazards are left alone.
local REPAINTABLE: { [Enum.Material]: boolean } = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Rock] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.Snow] = true,
}

local function pick(slopeDeg: number, worldY: number, n: number): Enum.Material
	-- n is noise in -1..1; it nudges thresholds so bands are not perfect contour lines
	local shift = n * RULES.noiseMix * 15
	if slopeDeg >= RULES.cliffSlopeDeg + shift then
		return Enum.Material.Slate
	elseif slopeDeg >= RULES.steepSlopeDeg + shift then
		return Enum.Material.Rock
	elseif worldY > RULES.snowLineY + shift * 4 then
		return Enum.Material.Snow
	elseif worldY < RULES.beachTopY + shift * 0.5 then
		return Enum.Material.Sand
	elseif n > 0.25 then
		return Enum.Material.LeafyGrass
	end
	return Enum.Material.Grass
end

local function occAt(occ: { { { number } } }, size: Vector3, x: number, y: number, z: number): number
	if x < 1 or y < 1 or z < 1 or x > size.X or y > size.Y or z > size.Z then
		return 0
	end
	return occ[x][y][z]
end

local function paintChunk(minCorner: Vector3)
	local region = Region3.new(minCorner, minCorner + Vector3.one * (CHUNK * RES)):ExpandToGrid(RES)
	local ch = terrain:ReadVoxelChannels(region, RES, { "SolidMaterial", "SolidOccupancy" })
	local mats = ch.SolidMaterial :: { { { Enum.Material } } }
	local occ = ch.SolidOccupancy :: { { { number } } }
	local size = ch.Size :: Vector3
	local origin = region.CFrame.Position - region.Size / 2

	local changed = 0
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				local o = occ[x][y][z]
				-- Surface voxel: solid, with less solid above it.
				if o > 0 and occAt(occ, size, x, y + 1, z) < 1 and REPAINTABLE[mats[x][y][z]] then
					-- Normal points from full to empty: negative occupancy gradient.
					local gx = occAt(occ, size, x - 1, y, z) - occAt(occ, size, x + 1, y, z)
					local gy = occAt(occ, size, x, y - 1, z) - occAt(occ, size, x, y + 1, z)
					local gz = occAt(occ, size, x, y, z - 1) - occAt(occ, size, x, y, z + 1)
					local g = Vector3.new(gx, gy, gz)
					if g.Magnitude > 1e-3 then
						local nrm = g.Unit
						local slopeDeg = math.deg(math.acos(math.clamp(nrm.Y, -1, 1)))
						local world = origin + Vector3.new(x - 0.5, y - 0.5, z - 0.5) * RES
						local n = math.noise(world.X / RULES.noiseScale, world.Z / RULES.noiseScale, 7.31)
						local m = pick(slopeDeg, world.Y, n)
						if m ~= mats[x][y][z] then
							mats[x][y][z] = m
							changed += 1
						end
					end
				end
			end
		end
	end

	if changed > 0 then
		terrain:WriteVoxelChannels(region, RES, { SolidMaterial = mats })
	end
	return changed
end

-- Paint a whole area chunk by chunk, yielding between chunks so Studio stays responsive.
local function paintArea(minCorner: Vector3, maxCorner: Vector3)
	local step = CHUNK * RES
	local total = 0
	for x = minCorner.X, maxCorner.X - 1, step do
		for y = minCorner.Y, maxCorner.Y - 1, step do
			for z = minCorner.Z, maxCorner.Z - 1, step do
				total += paintChunk(Vector3.new(x, y, z))
				task.wait()
			end
		end
	end
	print("repainted voxels:", total)
end

paintArea(Vector3.new(-1024, -64, -1024), Vector3.new(1024, 448, 1024))
```

How it behaves, and the edge cases:

- **Chunk borders.** The gradient at a chunk's edge treats the outside as empty, so a one-voxel strip along each border can pick a steeper slope than reality. Fix by reading a region one voxel larger on each side and only writing the inner part, or accept it and let the noise hide it. For a first pass, most maps never show it; for a cliff that runs along a chunk line, you will see a seam.
- **The surface test is coarse.** "Less solid above" catches the visible surface on hills and the underside of overhangs (where the voxel above is also less solid, but the face is downward). Overhang undersides then get cliff materials, which is usually what you want.
- **Noise must be continuous across chunks.** It is sampled in world space, not chunk space, so bands line up at borders.
- **Protect hand work.** The `REPAINTABLE` set is what keeps painted paths, mud hazards and landmarks alive. Paint paths with a material the script does not touch (Ground or Cobblestone here), or run the script first and hand-paint afterwards.
- **Determinism.** The same rules and noise offset give the same result. Store `RULES` in a ModuleScript and keep it in source control so the paint pass is reproducible after a terrain sculpt ([[Procedural World Generation]], [[Noise Functions and Terrain Generation]]).
- **Parallel reads.** Reads are thread-safe, so a very large pass can compute materials in Parallel Luau and serialise the writes, but for an edit-time pass the simple loop is usually fast enough ([[Parallel Luau and Actors]]).

## 5. Importing a colormap

The Import tool can take a heightmap plus a **colormap** that assigns materials by colour: one pixel equals 4 studs, maximum 4096 x 4096, `.png` or `.jpg` (Roblox docs, as of October 2026). Colours must match the documented RGB values with hard edges; colours that do not match map to the closest material. Examples from the docs: Grass `[106, 127, 63]`, Water `[12, 84, 92]`, Snow `[195, 199, 218]`. The docs offer a `RobloxColorMapIndex` file to sample exact values from.

When the colormap route wins:

- You generated the world outside Studio (a terrain tool, Blender, a GIS heightmap) and want the splat map to come along.
- You want artists to paint material layout in an image editor at map scale.

Pitfalls:

- **Antialiasing ruins colormaps.** Soft brush edges create in-between colours that snap to whatever is nearest, often a material you did not use. Paint with hard, aliased brushes and save without smoothing.
- **JPEG artefacts do the same.** Save colormaps as PNG.
- **4 studs per pixel is coarse.** Fine features (narrow paths) should be painted by hand or by script after import.

## 6. Colour as a paint tool

`Terrain:SetMaterialColor(material, colour)` shifts a material's base colour toward the given colour, for every voxel of that material in the place; `GetMaterialColor` reads it back and errors for Air and Water. The `MaterialColors` property "cannot be edited by scripts" (Roblox docs).

Uses that work:

- **Grade the whole palette together.** Desaturate Grass, Ground and Rock by the same amount so they belong to one art direction ([[Zone and Biome Art Direction]]).
- **Season or time-of-day shifts.** A slightly warmer Grass at golden hour, applied with the lighting change ([[Lighting Mood and Time of Day]]).
- **Per-zone tint on the client.** Because the colour is global, one way to give two zones different grass is to change the colour on the client when the player crosses a hidden boundary, as the Deep Dive does for water. Whether `SetMaterialColor` called from a LocalScript changes only that client's view is not stated in the docs (unverified); test it before designing around it, and prefer separate materials (or Expanded Terrain colour variants) when you can.

`SetMaterialColor` is not a property, so `TweenService` cannot animate it. Lerp manually:

```lua
--!strict
-- Smoothly shift one terrain material's colour over `seconds`.
local RunService = game:GetService("RunService")
local terrain = workspace.Terrain

local function fadeMaterialColor(material: Enum.Material, target: Color3, seconds: number)
	local from = terrain:GetMaterialColor(material)
	local t = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		t = math.min(t + dt / seconds, 1)
		terrain:SetMaterialColor(material, from:Lerp(target, t))
		if t >= 1 then
			conn:Disconnect()
		end
	end)
end
```

Rule of thumb: keep terrain colours within a moderate value range. Very dark colours hide the material texture entirely (the reference project measured textures disappearing below about 0.06 luminance on parts; terrain behaves the same way to the eye).

## 7. Painting with costs in mind

| Choice | Cost | Note |
|---|---|---|
| Built-in terrain materials | Already loaded for all players | The cheapest option; use their colour tint |
| One override with TerrainDetail top and side | Up to 2 x (3 or 4) maps at 512 | The best value for natural terrain |
| Many Expanded Terrain custom materials | Each one with a MaterialVariant adds its maps | Count what appears in one view, not per place |
| Hand-painted micro detail (single-voxel dabs) | No texture cost | Can add to terrain data size in large quantities |
| Procedural repaint pass | Edit-time only | Zero runtime cost |

The texture costs follow [[Textures Decals and Texture Memory]]: pixels, not file size, and every unique image counts once however many voxels use it.

## When not to paint terrain

- **Small stylised maps built from parts and meshes.** If the whole game is a few islands of meshes, terrain adds a second visual language. Use it only where it saves effort (big ground planes, water).
- **Walkable surfaces that must be precise.** Obby platforms, race tracks and tower defense lanes need exact collision edges; use parts and paint them with MaterialVariants ([[MaterialService and Custom Materials]]).
- **Paths on slopes with the blocky materials.** Lay a mesh path.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Too many materials per view | Visual noise; paths lost | Three to five per view |
| Hard straight material borders | "Painted in a paint program" look | Wobble edges, interleave dabs |
| Brick or WoodPlanks on slopes | Stepped cubes | Smooth materials on slopes |
| Rock painted by hand on every cliff | Hours of work, inconsistent | TerrainDetail side face or a slope pass |
| Antialiased colormap | Random materials at borders | Hard edges, PNG |
| 2K CC0 maps on terrain details | Memory with no visible gain | 512, or 256 for distant sides |
| Repaint script overwriting hand-painted paths | Lost work | Restrict to a repaintable set |
| Writing full voxel arrays to change material | Water erased, shapes nudged | Write only `SolidMaterial` |

## Checklist

- [ ] Ground roles defined: path, play space, edges, hazards, landmarks.
- [ ] Three to five materials per view; path lighter than surroundings in grayscale.
- [ ] Natural terrain uses a TerrainDetail override (top and side) where possible.
- [ ] CC0 terrain maps at 512; Organic pattern for ground and rock.
- [ ] Blocky materials kept off slopes.
- [ ] Procedural pass rules stored in source; protected materials excluded.
- [ ] Colormaps painted hard-edged and saved as PNG.
- [ ] Terrain colours graded together; nothing near black.
- [ ] Big paint passes done alone with a snapshot.

## See also

[[Materials and Surfaces Start Here]] · [[Terrain Tools and Terrain API]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[MaterialService and Custom Materials]] · [[CC0 Texture and HDRI Library]] · [[Procedural World Generation]] · [[Noise Functions and Terrain Generation]] · [[Zone and Biome Art Direction]] · [[Level Design for Roblox]] · [[Foliage Props and Scatter]] · [[Environment Art Styles]] · [[Textures Decals and Texture Memory]]

## Connected notes
<!-- auto-links:start -->
[[Links - Terrain]] · [[AI Material and Texture Generation]] · [[Hand-Painted and Stylized Texturing]] · [[Links - Materials and MaterialVariants]] · [[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Voxel Shading - Baked AO Edges and Lighting]]
<!-- auto-links:end -->
