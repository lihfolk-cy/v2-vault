---
tags: [modeling, voxel, grid, scale, studs, alignment, pivots, export, luau, blender, magicavoxel, type/guide]
---
# Voxel Scale Grids and Stud Alignment

<!-- tldr:start -->
> [!tldr] TL;DR
> - One-pixel cracks of sky between floor tiles that grow worse across...: Decimal cell size (0.3, 0.2) and positions accumulated by repeated... -> Use 0.25 or 0.5...
> - Flicker where two tiles meet: Coplanar faces overlapping by a tiny amount (z-fighting) -> Snap to exact multiples; delete the hidden face in the mesh
> - Pet hovers or sinks by a fraction of a stud on every floor: Character grain does not divide the environment grain -> Make every grain divide the largest one (0.5 and...
> - Cell size per asset class chosen from the pixels-per-cell table at real viewing distance.
> - All cell sizes are binary fractions (1, 0.5, 0.25, 0.125) and each divides the largest.
> - Module size decided (4 studs if the game uses terrain).
>
> Cost: TL;DR ~220 tok · whole note ~4.8k tok. Read more: ## 3. How many pixels does one cell cover? · ## 8. Auditing alignment with a script · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Every voxel model starts with one number: how many studs wide a single cube is. Choose it badly and nothing else in this section can save you. Cells that are too small turn into shimmering noise on a phone and multiply your triangle count; cells that are too large make every character look like a placeholder; cells that are not a clean binary fraction of a stud drift off the grid after a few hundred placements and leave hairline cracks between tiles. [[Voxel and Blocky Modeling]] gives the starting grains by object type. This note goes underneath that table: the arithmetic of picking a cell size, how the voxel grid relates to the other grids already in Roblox (the stud, terrain cells, the old voxel lighting grid, Studio's snap increments), where pivots should sit, how scale survives the trip from [[MagicaVoxel]] or Blender into Studio, and how to audit a finished model for alignment with a script.

## 1. The units you are working against

A few fixed facts set the frame.

- **One stud is 0.28 metres** (Roblox docs, units page, as of October 2026). A default R15 avatar is roughly 5 studs tall (rule of thumb; avatar body scaling changes it per player, so never assume an exact figure).
- **Terrain is a grid of 4 x 4 x 4 stud cells** (Roblox docs). If your voxel props sit on terrain, a 4-stud module lines up with terrain cells; anything else floats on top of the terrain's rendered surface, which itself sits slightly above the voxel top (see [[Terrain Tools and Terrain API]]).
- **The voxel-style lighting path samples the world in 4 x 4 x 4 stud cells** (Roblox docs, `GlobalShadows`; see [[Lighting Technologies and Settings]]). Under that path, a 0.25-stud voxel crenellation will not cast its own believable sun shadow. This matters for shading decisions in [[Voxel Shading - Baked AO Edges and Lighting]].
- **Studio's transform snapping is free by default.** The docs' modular-environment tutorial notes that Studio lets you move to any fraction of a stud and rotate to any angle until you set Move and Rotate increments in the toolbar (Roblox docs, as of October 2026). Holding Shift while dragging toggles snapping for that one action.
- **Parts and meshes store positions as 32-bit floats.** That gives about seven significant decimal digits. Near the origin this is far more precision than you need; at 10,000 studs from the origin the smallest step is around a thousandth of a stud (rule of thumb from float32 arithmetic). That is still fine for voxels, but it is why accumulated rounding, not raw precision, is the real enemy.

## 2. Pick cell sizes that are binary fractions of a stud

The most useful rule in this note: **use cell sizes of 1, 0.5, 0.25 or 0.125 studs**, and module sizes that are whole multiples of them.

The reason is floating point. Binary fractions (halves, quarters, eighths) are stored exactly. Decimal fractions like 0.1, 0.2 and 0.3 are not: 0.3 is stored as 0.29999999999999998889... in double precision and as a slightly different value in single precision. If a script places cells at `index * 0.3`, each position carries a tiny error, and if a tool places tiles by repeatedly adding an offset (`pos += 0.3`), the error accumulates. After a few hundred steps two neighbouring tiles that should share an edge are a hair apart or a hair overlapping. You see it as a one-pixel crack of sky between floor tiles, or as z-fighting flicker where two coplanar faces overlap by a few millionths of a stud.

With a 0.25 cell, `index * 0.25` is exact for every index you will ever use, and repeated addition is also exact. The same holds in Blender, in MagicaVoxel export scaling, and in Luau. The existing voxel notes in the vault quote grains like 0.3 and 0.4 studs for some studied styles; those work for a single hand-placed showpiece, but for anything tiled, scripted or repeated, round to the nearest binary fraction (0.25 or 0.5) and adjust the cell count instead.

| Cell size (studs) | Exact in binary | Cells per stud | Cells per 4-stud terrain cell | Typical use (rule of thumb) |
|---|---|---|---|---|
| 1 | Yes | 1 | 4 | Classic brick builds, large architecture, player-building grids |
| 0.5 | Yes | 2 | 8 | Large characters, buildings, tiles, most environment pieces |
| 0.25 | Yes | 4 | 16 | Avatar-scale characters, props, pets |
| 0.125 | Yes | 8 | 32 | Small held items, icons, hero detail; costly as Parts |
| 0.3, 0.4, 0.2 | No | Not whole | Not whole | Single showpieces only; avoid for tiles |

## 3. How many pixels does one cell cover?

A cell size is a readability decision, so measure it in screen pixels at the distance players actually see the object.

For a perspective camera with vertical field of view F (Roblox's `Camera.FieldOfView` defaults to 70 degrees), the height of the world visible at distance d is `2 * d * tan(F / 2)`. Divide the screen height in pixels by that and you get pixels per stud.

Worked numbers for a 720-pixel-tall phone render, F = 70 degrees (`tan 35 = 0.70`):

| Distance (studs) | Visible height (studs) | Pixels per stud | 0.5-stud cell | 0.25-stud cell | 0.125-stud cell |
|---|---|---|---|---|---|
| 10 | 14 | 51 | 26 px | 13 px | 6 px |
| 20 | 28 | 26 | 13 px | 6 px | 3 px |
| 40 | 56 | 13 | 6 px | 3 px | 1.6 px |
| 80 | 112 | 6.4 | 3 px | 1.6 px | 0.8 px |

Rules of thumb that fall out of this table:

1. **A cell must cover about 2 pixels at the distance the object matters**, or adjacent colours average into mush and, worse, shimmer as the camera moves (single-pixel features flicker in and out as they cross pixel boundaries).
2. **The face, eyes or icon of an object need 4 or more pixels per cell** at reading distance. A 0.25-stud face on a pet the player watches from 15 studs gets about 8 pixels per cell: comfortable.
3. **Environment pieces seen at 40 to 80 studs want 0.5-stud cells or larger.** A 0.125-stud mossy brick wall at 60 studs is sub-pixel noise.
4. **Phones in landscape often render below their native resolution** when the device lowers quality, so plan for the low end of your pixel budget, not a 1440p monitor.

The default third-person camera sits roughly 10 to 15 studs behind the character (rule of thumb; it varies with zoom), so the player's own character and nearby enemies are usually in the 10 to 25 stud band, and mid-ground scenery in the 30 to 100 stud band. That is why most good blocky Roblox games use finer cells on characters than on buildings, even though mixing grains on one model is a mistake: different asset classes can have different grains, a single model cannot.

## 4. One grid per model, compatible grids per game

[[Voxel and Blocky Modeling]] says "one grid per model". The game-wide version is: **every grain in the game should divide the largest one evenly.** If buildings use 0.5 and characters use 0.25, a character's feet can still stand exactly on a building's floor cell boundary, and a 0.25-stud prop can sit on a 0.5-stud shelf without floating by half a cell. If buildings use 0.5 and characters use 0.3, nothing lines up and you will see characters hovering by 0.1 stud or sunk into floors.

A practical game-wide grid:

- **Module grid: 4 studs** (matches terrain cells and makes floor tiles land on terrain).
- **Environment cell: 0.5 studs** (8 cells per module).
- **Character and prop cell: 0.25 studs** (16 cells per module).
- **Hero detail cell: 0.125 studs**, only on held items and close-up UI renders.

Studio snapping then becomes simple: Move increment 4 for placing modules, 0.5 for nudging props, Rotate increment 90 for anything that tiles. A 45-degree rotation breaks voxel alignment entirely (the cell edges no longer follow world axes), which is fine for a loose prop and wrong for a floor tile.

## 5. Where the pivot goes

Pivots decide whether pieces snap cleanly. There are three sensible choices; pick one per asset class and write it down.

| Pivot | Good for | Watch out for |
|---|---|---|
| **Bottom corner** (minimum x, minimum y, minimum z of the bounding box) | Floor tiles, wall pieces, anything placed on a grid by script | Rotating a corner-pivot piece by 90 degrees moves it to a neighbouring cell; the placer must compensate |
| **Bottom centre** (centre of the footprint at floor level) | Props, characters, trees, anything rotated freely | Pieces with an odd number of cells across put the centre on a cell centre; even counts put it on a cell edge. Both are fine, but a script that assumes one gets half-cell offsets on the other |
| **Joint centre** | Limbs of rigged characters | Covered in [[Voxel Characters - Proportions Joints and Rigging]] |

The odd/even trap is the most common alignment bug. A 5-cell-wide crate at 0.5 studs is 2.5 studs wide. With a centre pivot snapped to a 0.5 grid, its edges land at plus or minus 1.25 studs: on a quarter-stud offset from the 0.5 environment grid. A 6-cell crate (3 studs) does not have this problem. Either make tiled pieces even in cell count, or use corner pivots for anything a script places on a grid.

The docs' modular-environment tutorial uses the same idea at a larger scale: every mesh in its sample kit has a consistent pivot "at the forward-most, lower corner" and lengths divisible by 7.5 studs, with Move snapping set to 7.5 (Roblox docs, as of October 2026). The 7.5 module there is for a realistic city kit; for voxel work, choose a module that is a multiple of your cell size.

## 6. Keeping scale correct from editor to Studio

Each tool has its own idea of a unit. The safe workflow is to fix the scale once with a reference object, then never touch it again.

- **MagicaVoxel** writes one voxel as one unit in its OBJ export (tool docs and community documentation; see [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]]). Its view is Z-up.
- **Blender** works best for Roblox with 1 Blender unit = 1 stud (vault convention; see [[Blender Workflow for Roblox Creators]]). Importing a MagicaVoxel OBJ, scale it by the cell size (0.25 for 0.25-stud voxels) and apply the scale.
- **[[Blockbench]]** models in 16 units per block in many formats (tool docs); test its glTF output with a reference cube before trusting any scale.
- **The Roblox 3D Importer** has a Scale Unit option that defaults to Studs, plus World Forward and World Up options for axis fixes (Roblox docs, as of October 2026).

**Reference cube test.** Before building anything, make a cube of exactly 16 x 16 x 16 cells in your voxel tool. At 0.25-stud cells it must import as 4 x 4 x 4 studs. Put it next to a 4 x 4 x 4 Part in Studio and look along an edge: any gap or overlap means the pipeline scale is wrong. Keep this cube in every project's Blender file and re-run the test whenever you change exporter version or settings.

**Apply transforms before export.** An object with an unapplied scale of 0.25 exports correctly in some formats and incorrectly in others, and a rigged object with unapplied scale breaks joints. In Blender: Object, Apply, All Transforms, then check the dimensions panel reads whole multiples of your cell size.

**Origin offsets.** Voxel editors often export with the origin at the centre of the model's bounding box, or at a corner of the editing volume rather than of the model. After import, set the origin deliberately (Object, Set Origin, or snap the 3D cursor to a vertex and set origin to cursor) to the pivot rule from section 5.

## 7. Worked example: a stud-aligned pet and a floor tile

Goal: a small pet that follows a 5-stud avatar, and a floor tile it walks on, both perfectly on grid.

1. **Choose grains.** The pet is read at 10 to 20 studs, so 0.25-stud cells give 6 to 13 pixels per cell on a 720p phone (section 3). The floor tile is read at 10 to 60 studs: 0.5-stud cells.
2. **Size the pet.** A pet about 2 studs tall is 8 cells; make it 8 tall, 8 wide, 10 long (even counts).
3. **Size the tile.** 4 x 4 studs to match terrain cells: 8 x 8 cells at 0.5, 1 cell thick (0.5 studs).
4. **Build in MagicaVoxel** at those cell counts. Keep the pet's feet on the bottom layer of the volume.
5. **Import into Blender** (OBJ, or the .vox importer add-on). Scale the pet by 0.25 and the tile by 0.5, apply scale.
6. **Set origins.** Pet: bottom centre (the 8 x 10 footprint is even, so the centre lands on a cell edge). Tile: bottom corner.
7. **Check dimensions.** Pet 2 x 2 x 2.5 studs; tile 4 x 0.5 x 4 studs. Anything else means a stray voxel or a scale mistake.
8. **Export GLB, import with Scale Unit Studs.** Place the tile with Move snap 4. Place the pet with Move snap 0.25 on top of the tile: its feet land exactly on the tile's top face.
9. **Run the audit script below** on both.

## 8. Auditing alignment with a script

This command-bar script checks every BasePart in the selection: positions of the bounding box corners and sizes must be multiples of the chosen cell, within a tolerance. It reports offenders instead of fixing them, because silent snapping can move a part that was offset on purpose.

```lua
--!strict
-- Grid audit: run in the command bar with a model selected.
-- Reports parts whose bounding box min corner or size is not a multiple of CELL.
local Selection = game:GetService("Selection")

local CELL = 0.25          -- studs per voxel cell for this asset class
local TOL = 1e-3           -- allowed error in studs

local function offGrid(value: number): boolean
	local steps = value / CELL
	return math.abs(steps - math.round(steps)) * CELL > TOL
end

local function checkPart(p: BasePart, report: { string })
	-- Only meaningful for axis-aligned parts; flag rotated ones separately.
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
	local axisAligned = true
	for _, v in { r00, r01, r02, r10, r11, r12, r20, r21, r22 } do
		local a = math.abs(v)
		if a > TOL and math.abs(a - 1) > TOL then
			axisAligned = false
			break
		end
	end
	if not axisAligned then
		table.insert(report, `{p:GetFullName()}: rotated off the world axes`)
		return
	end
	-- World-space extents of an axis-aligned box.
	local half = p.CFrame:VectorToWorldSpace(p.Size / 2)
	local ext = Vector3.new(math.abs(half.X), math.abs(half.Y), math.abs(half.Z))
	local minCorner = p.Position - ext
	local worldSize = ext * 2
	for _, axis in { "X", "Y", "Z" } do
		local m = (minCorner :: any)[axis] :: number
		local s = (worldSize :: any)[axis] :: number
		if offGrid(m) or offGrid(s) then
			table.insert(report, string.format("%s: %s min %.4f size %.4f", p:GetFullName(), axis, m, s))
		end
	end
end

local report: { string } = {}
for _, root in Selection:Get() do
	local list = if root:IsA("BasePart") then { root } else root:GetDescendants()
	for _, d in list do
		if d:IsA("BasePart") then
			checkPart(d, report)
		end
	end
end
print(`Grid audit at {CELL} studs: {#report} problem(s)`)
for _, line in report do
	print("  " .. line)
end
```

Notes on the script: a MeshPart's `Size` is its bounding box, so a voxel mesh with one stray voxel sticking out will fail the size check, which is exactly what you want. Models built in world space far from the origin still audit correctly because the check uses world coordinates; if your kit is meant to align to a moving origin (a vehicle, a plot), audit relative to that origin's CFrame instead.

## 9. When not to follow the grid

- **Loose debris and scatter** read as more natural when rotated and offset off grid; keep the voxels inside each piece on grid, but place the pieces freely.
- **Characters in motion** leave the grid the moment they animate. Align the rest pose; nothing else.
- **Player-built content on a 1-stud or 4-stud grid** (see [[Grid Placement and Player Building Systems]]) should drive your cell choice, not the other way round: if players build in 1-stud steps, a 0.3-stud art grain on your pre-made pieces will never line up with their builds.
- **Smooth stylised games** that use a few blocky props as accents do not need any of this beyond the reference cube.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| One-pixel cracks of sky between floor tiles that grow worse across the map | Decimal cell size (0.3, 0.2) and positions accumulated by repeated addition | Use 0.25 or 0.5; compute positions as `index * cell`, not by adding |
| Flicker where two tiles meet | Coplanar faces overlapping by a tiny amount (z-fighting) | Snap to exact multiples; delete the hidden face in the mesh |
| Pet hovers or sinks by a fraction of a stud on every floor | Character grain does not divide the environment grain | Make every grain divide the largest one (0.5 and 0.25, not 0.5 and 0.3) |
| Crates land a quarter stud off the grid when snapped | Odd cell count with a centre pivot | Even cell counts for tiled pieces, or corner pivots |
| Model imports 4 times too big or small | Voxel tool unit not scaled by the cell size, or scale not applied | Reference cube test; apply transforms before export |
| Fine detail shimmers when the camera moves | Cells under about 2 pixels at viewing distance | Raise the cell size for that asset class (section 3 table) |
| Tiles rotated 45 degrees look jagged against the floor | Voxel edges no longer follow world axes | Rotate tiled pieces only in 90-degree steps |

## Checklist

- [ ] Cell size per asset class chosen from the pixels-per-cell table at real viewing distance.
- [ ] All cell sizes are binary fractions (1, 0.5, 0.25, 0.125) and each divides the largest.
- [ ] Module size decided (4 studs if the game uses terrain).
- [ ] Pivot rule written down per asset class; even cell counts on tiled pieces.
- [ ] Reference cube imported and measured against a Part in Studio.
- [ ] Transforms applied, origins set, dimensions are whole multiples of the cell.
- [ ] Studio Move and Rotate increments set for the task (module, nudge, 90 degrees).
- [ ] Grid audit script run on every new kit piece.

## Related

[[Voxel and Blocky Modeling]] · [[Voxel Art - Studs Outlines and Style Kits]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Modular Environment Kits]] · [[Grid Placement and Player Building Systems]] · [[Terrain Tools and Terrain API]] · [[Lighting Technologies and Settings]] · [[3D Importer Settings Reference]] · [[Blender Workflow for Roblox Creators]] · [[Voxel Props Environments and Modular Tiles]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Modelling Start Here]] · [[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Modeling Fundamentals for Games]] · Skill - Roblox Asset Import · Tilemaps Cameras and Parallax for 2D Levels · Exporting and Validating Models for Roblox
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Voxel Palettes - Ramps Hue Shifting and Limits]] · [[Modelling to the Roblox Camera and Player Scale]] · [[Voxel Chibi Heroes - Class Roster and Rarity Ladder]] · [[Exporting and Validating Models for Roblox]] · [[Modeling in Blender for Roblox]] · [[Bevels Chamfers and Edge Highlights Without Textures]]
<!-- related:end -->
