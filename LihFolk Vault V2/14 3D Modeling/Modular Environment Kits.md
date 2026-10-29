---
tags: [modeling, modular, kits, environment, grid, pivots, blender, luau, level-design]
---
# Modular Environment Kits

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No fixed grid -> Grid chosen and documented first
> - Avoid: Mixed pivot rules -> One pivot rule per kit, validated
> - Avoid: Bevels on contact edges -> Flat contact faces; detail inside the footprint
> - Grid, wall height, thickness and door size written down.
> - One pivot rule; origins on the ground; fronts toward -Y in Blender.
> - Piece list with variants; seams hidden by pillars, trims or overlaps.
>
> Cost: TL;DR ~140 tok · whole note ~4.1k tok. Read more: ## 4. Modelling pieces in Blender · ## 6. Placing pieces · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A modular kit is a small set of pieces (walls, corners, floors, stairs, pillars, trims, props) designed to snap together on a grid, so a large world can be built from a few dozen meshes. On Roblox, kits are the single biggest lever for both production speed and performance: one artist builds 40 pieces, level designers (or scripts) build 40 zones, and the engine loads 40 meshes instead of 4,000 unique ones. The reference project built its second realm's canyon walls from **3 wall meshes placed 194 times**, and one hub from a **149-mesh package** placed by data exported from Blender.

The craft is in rules that are boring to follow and expensive to break: grid size, pivot placement, dimensions, seams, texel density, naming. This note sets those rules, shows how to model and validate pieces in Blender, and how to place them in Studio by hand or by script.

---

## 1. Choose the grid first

Everything in a kit is a multiple of one grid unit. Pick it from your character and camera:

| Grid unit | Suits | Notes |
|---|---|---|
| 1 stud | Small props, trims, voxel kits | Too fine for big architecture: placement takes forever |
| 2 studs | Interiors for default-size (5.2-stud) characters | |
| **4 studs** | Most buildings and dungeons for default characters | Doors 8 wide x 12 tall fit cleanly (rule of thumb) |
| 8 studs | Buildings for scaled-up characters, large dungeons | The reference project's players were about 9 studs tall; door openings needed about 12-14 studs |
| 16-60 studs | Terrain-scale pieces (cliffs, canyon walls, city blocks) | The project's canyon walls were about 76 studs wide on a 60-stud pitch, overlapping to hide joins |

Rules:
- **Wall height** = a multiple of the grid that fits your door and the jump height of your character.
- **Wall thickness** is the one dimension that is often not a multiple: walls straddle the grid line (the grid line runs through the wall's centre), or sit entirely on one side. Pick one and keep it for every piece.
- Write the grid, wall height, wall thickness and door size on the first line of the kit's documentation.

Studio's own move snapping should match (Model tab move increments). A kit on a 4-stud grid placed with 1-stud snapping produces gaps the first time someone nudges a piece.

---

## 2. Pivot (origin) rules

The pivot is how every piece snaps. Choose one rule per kit and never mix:

| Rule | Origin at | Pros | Cons |
|---|---|---|---|
| **Corner** | One bottom corner on the grid (for example the bottom-left-front) | Pieces of any size snap to grid points with integer moves | Rotating a piece moves it off its footprint; corners must be counter-rotated |
| **Bottom centre of the grid cell** | Centre of the footprint, on the floor | Rotating in place keeps the piece on its cell | Odd sizes put origins on half-grid points |
| **Wall line** | Centre of the wall's base line | Walls and doors rotate around the line they sit on | Only for linear pieces |

The reference project used "every piece base = pivot" with each blockout's `WorldPivot` "grounded base facing the altar" for hub pieces, and "WorldPivot bottom centre, LookVector into the valley" for zone landmarks. The common thread: **pivot on the ground**, **facing a meaningful direction**. Ground pivots make it trivial to place pieces on terrain with a raycast.

### Facing

Model each piece with its "front" (the side players see, or the room's inside) toward Blender -Y, which arrives as Roblox -Z (`LookVector`) with GLB import ([[Enemy Import Axis Fix]]). A script can then face any piece toward a point with `CFrame.lookAt`.

---

## 3. The piece list

A minimal building kit (example on a 4-stud grid, 12-stud walls):

| Piece | Size (W x H x D, studs) | Notes |
|---|---|---|
| Wall_Straight_4 | 4 x 12 x 1 | The workhorse |
| Wall_Straight_8 | 8 x 12 x 1 | Fewer pieces for long runs |
| Wall_Corner_Out / In | 1 x 12 x 1 corner block, or an L | Hides the join of two walls |
| Wall_Door | 8 x 12 x 1 with an 8 x 10 opening (fits a 9-stud character only if raised: adjust to your scale) | |
| Wall_Window | 4 x 12 x 1 | |
| Wall_End | Cap for exposed wall ends | |
| Floor_4 / Floor_8 | 4 x 1 x 4 / 8 x 1 x 8 | Top surface at y = 0 or at y = 1, pick one |
| Stairs_4 | Rise one wall height over N cells | Match your character's step and jump |
| Pillar | 1 x 12 x 1 or larger | Hides corners and T-joins |
| Trim_Top / Trim_Base | 4 or 8 long | Breaks repetition, hides seams |
| Roof pieces | | |
| Props | Crates, barrels, lamps on the same grid | |

Then add **variation pieces**: the same wall with cracks, moss, a banner hook, a broken top. Three variants of the straight wall remove most visible repetition.

### Hiding seams

Every modular world has joins. Hide them by design:

- **Pillars and trims over joins.** A pillar at every corner, a trim along every wall top.
- **Overlap pieces slightly** (half a stud) where nothing will be seen inside the overlap. The project's canyon walls were 76 studs wide on a 60-stud pitch: generous overlap so irregular rock edges never showed gaps.
- **Break the silhouette** of long runs with height changes, buttresses or props every few pieces.
- **Avoid continuous patterns across joins** (a stone pattern that must line up exactly between two pieces will not, after the third rotated placement).

---

## 4. Modelling pieces in Blender

### Setup

- Units: 1 unit = 1 stud ([[Blender Workflow for Roblox Creators]]).
- Grid: set the viewport grid scale so one grid square equals your kit grid; snapping *Increment* with *Absolute Grid Snap* (manual: "snap to the viewport grid instead of moving by increments of the grid cell size").
- Vertex snapping for joins: snapping to *Vertex* lets you put a piece's corner exactly on another's.
- One collection per kit; one object per piece; each piece's origin per the pivot rule.

### Modelling rules

1. **Block every piece at exact grid dimensions first** (cubes scaled by typing sizes), with origins set.
2. **Keep the outer contact faces flat and on the grid.** Detail (bevels, cracks, stones) goes inside the footprint or on surfaces that never touch another piece. A bevel on the edge that meets the next wall makes a visible groove at every join.
3. **Consistent texel density** across the kit: the same number of texture pixels per stud on every piece, or a wall next to a floor looks blurry next to sharp. Use a trim sheet shared by the whole kit ([[Trim Sheets Atlases and Vertex Colors]]).
4. **Same materials across pieces** (one atlas or trim sheet), so the whole kit is a few textures.
5. **Collision**: plan simple colliders (boxes) per piece. Detailed meshes should not be their own colliders.

### Validating a kit with Python

```python
# Blender: validate a modular kit collection against grid rules.
import bpy
from mathutils import Vector

GRID = 4.0              # kit grid in studs
TOL = 1e-3

def on_grid(v):
    return abs(v / GRID - round(v / GRID)) < TOL

def check_kit(collection_name, pivot_rule="BOTTOM_CENTER"):
    problems = []
    for obj in bpy.data.collections[collection_name].all_objects:
        if obj.type != 'MESH':
            continue
        if any(abs(s - 1.0) > TOL for s in obj.scale) or any(abs(r) > TOL for r in obj.rotation_euler):
            problems.append(f"{obj.name}: unapplied rotation/scale")
        # bounds in the object's own space (origin = pivot)
        xs = [c[0] for c in obj.bound_box]; ys = [c[1] for c in obj.bound_box]; zs = [c[2] for c in obj.bound_box]
        w, d, h = max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)
        if not on_grid(w) and w > 1.5:          # thin dimensions (wall thickness) may be off-grid
            problems.append(f"{obj.name}: width {w:.3f} not a multiple of {GRID}")
        if not on_grid(h):
            problems.append(f"{obj.name}: height {h:.3f} not a multiple of {GRID}")
        if abs(min(zs)) > TOL:
            problems.append(f"{obj.name}: bottom at z={min(zs):.3f}, origin not on the floor")
        if pivot_rule == "BOTTOM_CENTER":
            cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
            if abs(cx) > TOL or abs(cy) > TOL:
                problems.append(f"{obj.name}: origin off footprint centre by ({cx:.3f}, {cy:.3f})")
        if not on_grid(obj.location.x) or not on_grid(obj.location.y):
            problems.append(f"{obj.name}: placed off grid at {tuple(round(c, 3) for c in obj.location)}")
    return problems

for p in check_kit("Kit_Dungeon"):
    print(p)
```

Run it before every export. A kit that passes this check snaps in Studio with no adjustment.

---

## 5. Exporting a kit

Two approaches:

- **One file per piece.** Each import is clean; pieces can be updated individually. Many files to manage.
- **One file for the whole kit.** One import, all pieces in one Model, each MeshPart keeping its own pivot (keep *Use Imported Pivot* on; Docs). The reference project uploaded whole kits from Blender as packages (one hub package of 149 MeshParts, later 150 meshes in version 3), then placed pieces from a library.

Keep pieces at their grid positions in the export if you want *Insert Using Scene Position* to reproduce a layout; keep them all at the origin if they are a library to be placed by script.

### Packages

Publishing the kit as a **Package** means every placed copy updates when the kit is republished (see [[Packages and Asset Reuse]]). The project's Blender upload add-on wrote packages directly; its rebuild path was "load the mesh library with InsertService into ServerStorage, then place pieces in chunks". Note that a placed piece must be a copy of the package content for this to work: if your placement script clones individual MeshParts out of the package, those clones do not auto-update.

---

## 6. Placing pieces

### By hand in Studio

- Set move snap to the kit grid and rotation snap to 90 degrees (or 45 for diagonal kits).
- Build with Models whose pivots are the kit pivots, so the Move tool snaps the right point.
- Group repeated assemblies (a whole corridor segment) into a Model and reuse it.

### By script

Scripted placement is how large Roblox worlds get built quickly and consistently. The reference project's canyon builder chained wall segments along front lines "z +167 / -163, pitch 60, base = max floor - 65", placing 194 segments across ten zones, with per-zone counts recorded for checking.

```lua
--!strict
-- Place kit wall segments along a line on the ground, with random variants and yaw jitter.
local Workspace = game:GetService("Workspace")

type Options = {
	pitch: number,              -- distance between segment pivots (studs)
	variants: { Model },        -- interchangeable wall models (pivot = base centre, front = -Z)
	faceToward: Vector3,        -- the side the wall fronts should face
	yawJitterDeg: number?,      -- small random turn to break repetition
	seed: number?,
}

local function groundY(x: number, z: number, params: RaycastParams): number?
	local hit = Workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -4000, 0), params)
	return if hit then hit.Position.Y else nil
end

local function placeWallLine(from: Vector3, to: Vector3, opts: Options, parent: Instance): number
	local rng = Random.new(opts.seed or 1)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { parent }
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local count = math.max(1, math.floor(delta.Magnitude / opts.pitch + 0.5))
	local dir = delta.Unit
	local placed = 0
	for i = 0, count - 1 do
		local p = from + dir * (opts.pitch * (i + 0.5))
		local y = groundY(p.X, p.Z, params)
		if not y then continue end
		local base = Vector3.new(p.X, y, p.Z)
		-- wall runs along dir; its front (-Z) must point toward faceToward
		local front = Vector3.new(opts.faceToward.X - base.X, 0, opts.faceToward.Z - base.Z)
		local side = dir:Cross(Vector3.yAxis)          -- horizontal normal of the wall line
		if side:Dot(front) < 0 then side = -side end
		local jitter = math.rad(rng:NextNumber(-1, 1) * (opts.yawJitterDeg or 0))
		local cf = CFrame.lookAt(base, base + side) * CFrame.Angles(0, jitter, 0)
		local piece = opts.variants[rng:NextInteger(1, #opts.variants)]:Clone()
		piece:PivotTo(cf)
		piece.Parent = parent
		placed += 1
	end
	return placed
end

return placeWallLine
```

Notes from production:
- **Seed the randomness** so rebuilds are identical and diffs are meaningful.
- **Record what you placed** (counts per zone, or an attribute on each piece) so you can verify and undo. The project tagged moved or placed items with attributes holding their previous pivots, and saved JSON backups before bulk placement.
- **Chunk big builds** across several calls or frames; huge loops freeze Studio.
- **Mirroring is not a rotation.** The project measured that `Model:PivotTo` with a mirrored CFrame does not mirror a composite model's layout; it needed a deep clone that mirrored each part. Model left and right variants instead of mirroring in Studio.
- **PrimaryPart owns the pivot.** On models with a PrimaryPart, set `PrimaryPart.PivotOffset`; the project found `WorldPivot` writes were ignored on such models.

---

## 7. Palette carriers: one geometry, many zones

A powerful trick for multi-zone games: model one piece, ship it with a palette texture, and recolour per zone by swapping the texture rather than the mesh. The project's realm walls shipped "palette carriers R2W_Pal_Z11..Z20 (one geometry, zone palette = TextureID swap)": ten zones, ten looks, one mesh's worth of geometry to download. This works best with the palette-atlas UV technique in [[Low-Poly and Stylized Modeling]].

Gotcha (Measured): kit MeshParts with a palette `TextureID` ignored `Material` changes until the TextureID was cleared, and near-black colours hid material textures. Decide per kit whether colour comes from the texture or from `Color` + `Material`.

---

## 8. Budgets

| Kit item | Reference project |
|---|---|
| Canyon wall segment | about 3.5k triangles, ~76 x 190-230 studs, Neon seams |
| Realm cliff ring modules | 6-12k triangles each, with `_LOD1` variants on the big ones |
| Zone props kit | 82 props in one package |
| Hub kit | 149-150 meshes in one package |
| Zone terrain set | 31 meshes, 90k triangles |

Per-zone instance budgets in the project's revamp plan: at most 6,000 instances, 40 live particle emitters, 12 lights (2 shadowed) per zone. A kit is what makes those numbers reachable.

---

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| No fixed grid | Gaps and overlaps everywhere | Grid chosen and documented first |
| Mixed pivot rules | Every piece needs manual nudging | One pivot rule per kit, validated |
| Bevels on contact edges | Grooves at every join | Flat contact faces; detail inside the footprint |
| Different texel densities | Blurry pieces next to sharp ones | Shared trim sheet, consistent density |
| Unique textures per piece | Memory and download cost | One atlas or trim sheet per kit |
| Mirroring models in Studio | Broken layouts | Model left and right variants |
| Detailed meshes as colliders | Physics cost, snagging | Simple box colliders |
| Unseeded random placement | Rebuilds differ; no undo | Seeded RNG, recorded placements |

## Checklist

- [ ] Grid, wall height, thickness and door size written down.
- [ ] One pivot rule; origins on the ground; fronts toward -Y in Blender.
- [ ] Piece list with variants; seams hidden by pillars, trims or overlaps.
- [ ] Kit passes the grid validation script.
- [ ] One trim sheet or atlas; consistent texel density.
- [ ] Simple colliders planned.
- [ ] Exported as a package or library; placement seeded and recorded.

## See also

[[Level Design for Roblox]] · [[Environment and Level Pipeline]] · [[Packages and Asset Reuse]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Low-Poly and Stylized Modeling]] · [[Collision and Physics Geometry]] · [[Procedural World Generation]] · [[Batch Processing Tools in Studio]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Modeling Weapons and Props]]

## Connected notes
<!-- auto-links:start -->
[[Modeling in Blender for Roblox]] · [[Voxel Scale Grids and Stud Alignment]] · [[Modeling Fundamentals for Games]] · [[Exporting and Validating Models for Roblox]] · [[Voxel Props Environments and Modular Tiles]] · [[Grid Placement and Player Building Systems]]
<!-- auto-links:end -->
