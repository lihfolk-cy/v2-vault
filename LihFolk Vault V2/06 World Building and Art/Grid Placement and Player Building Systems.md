---
tags: [world-building, building, placement, grid, snapping, tycoon, housing, validation, datastore, luau]
---
# Grid Placement and Player Building Systems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Storing world positions -> Plot-local cells
> - Avoid: Anchor corner follows the cursor -> Centre the footprint on the cursor
> - Avoid: Footprint not swapped on rotation -> `rotatedSize` everywhere
> - Studio kits audited for off-grid pivots and yaw.
> - Placements stored as (itemId, x, y, z, r) in plot-local cells with a format version.
> - Footprints rotate correctly; centre follows the cursor.
>
> Cost: TL;DR ~140 tok · whole note ~5.8k tok. Read more: ## 4. The client: ghost, input, feedback · ## 5. The server: validation and the occupancy grid · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Grids show up twice in Roblox development. Builders use them in Studio to assemble kits cleanly, and many games hand a grid to the **player**: tycoon plots, housing, base building, farm layouts, furniture placement. The two share the maths, but the runtime version adds everything that makes it hard: a ghost preview that follows a mouse, a finger or a thumbstick, rotation of non-square items, server validation against exploits, saving and loading hundreds of placed items per player, and keeping 20 players' builds inside an instance budget.

[[Modular Environment Kits]] covers the Studio side in depth: choosing the grid unit, pivot rules, the piece list and scripted placement of kit pieces. This note adds a short section on keeping Studio-built kits on grid, then spends the rest on player building systems.

(Title note: the brief proposed "Modular Building Kits and Grid Snapping"; that overlapped heavily with [[Modular Environment Kits]], so this note takes the runtime placement angle.)

---

## 1. Studio side: keeping a kit on the grid

Studio snapping only helps if the pieces start on grid. Things that knock them off:

- **Moves with snapping off**, or with a different increment (1 stud while the kit uses 4).
- **Rotations at non-90 increments** that are later "rotated back" by eye.
- **Accumulated floating-point error**: many rotations by script (`CFrame * CFrame.Angles(0, math.pi / 2, 0)` applied repeatedly) leave positions like `127.99999` and rotations a hair off 90 degrees. Invisible in the viewport; visible as hairline seams under some lighting, and fatal for any script that rounds positions to find cells.
- **Pivot edits** after placement: changing a model's pivot moves the snap point, so the next snapped move puts it off grid.

A periodic audit catches all four. Run it from the command bar on the kit folder:

```lua
--!strict
-- Report models whose pivot is not on the grid or whose yaw is not a multiple of 90 degrees.
local GRID = 4
local EPS = 0.01

local function offGrid(v: number): boolean
	local r = v / GRID
	return math.abs(r - math.round(r)) * GRID > EPS
end

local function audit(root: Instance)
	local bad = 0
	for _, m in root:GetDescendants() do
		if m:IsA("Model") and m.Parent and not m.Parent:IsA("Model") then -- top-level pieces only
			local cf = m:GetPivot()
			local p = cf.Position
			local _, yaw, _ = cf:ToOrientation()
			local quarter = yaw / (math.pi / 2)
			local yawOff = math.abs(quarter - math.round(quarter)) > 0.001
			if offGrid(p.X) or offGrid(p.Z) or offGrid(p.Y) or yawOff then
				bad += 1
				print(("%s at (%.3f, %.3f, %.3f) yaw %.2f deg"):format(m:GetFullName(), p.X, p.Y, p.Z, math.deg(yaw)))
			end
		end
	end
	print(("audit done: %d off-grid pieces"):format(bad))
end

audit(workspace.Kit)
```

The fix script is the same loop writing `m:PivotTo(CFrame.new(rounded) * CFrame.Angles(0, roundedYaw, 0))`. Snapshot before running any fix in a shared place, and remember the measured gotcha from [[Modular Environment Kits]]: on models with a `PrimaryPart`, set `PrimaryPart.PivotOffset` rather than `WorldPivot`. Studio's own Move and Rotate increments, the Collisions toggle, and pivot tools are covered in [[Studio Settings and Shortcuts]] and [[Explorer Properties and Selection]].

---

## 2. Player building: the moving parts

```
client: input -> ghost preview -> local validity tint -> request(itemId, cell, rotation)
server: validate -> occupancy grid -> spawn model -> update inventory -> mark save dirty
save:   compact list of (itemId, x, y, z, r) in plot-local cells
load:   validate each entry against current item definitions -> spawn in chunks
```

The design decision that shapes everything else: **placements are stored and validated in plot-local cell coordinates, never in world space.** A player's plot is at a different place in every server (plot 3 today, plot 7 tomorrow), may be rotated, and may move if you rearrange the map. Cells relative to the plot origin survive all of that.

---

## 3. The grid maths

### Definitions

- **Plot origin**: a `CFrame` at the plot's minimum corner on the floor, X and Z along the plot's edges. Plots can be rotated in the world; all maths happens in plot space.
- **Cell size** `C` (for example 4 studs) and **layer height** `H` (for example 4 studs for stackable items, or a single layer for flat building).
- **Footprint** of an item in cells: width `w` (along X), depth `d` (along Z), height `h` in layers.
- **Rotation** `r` in quarter turns: 0, 1, 2, 3. Never store degrees; never allow anything else.
- **Anchor cell**: the minimum (x, z) corner cell the item occupies after rotation.

### Rotation swaps the footprint

A 2 x 1 bench rotated by 90 degrees is a 1 x 2 bench. The anchor stays the minimum corner, and the model's pivot (bottom centre, see [[Modular Environment Kits]]) goes to the centre of the rotated footprint:

```lua
--!strict
-- ReplicatedStorage/Shared/GridMath.lua
local GridMath = {}

GridMath.CELL = 4
GridMath.LAYER = 4

export type Footprint = { w: number, d: number, h: number }

function GridMath.rotatedSize(fp: Footprint, r: number): (number, number)
	if r % 2 == 1 then
		return fp.d, fp.w
	end
	return fp.w, fp.d
end

-- Plot-local CFrame of the item's pivot (bottom centre of the rotated footprint).
function GridMath.localPivot(x: number, y: number, z: number, fp: Footprint, r: number): CFrame
	local w, d = GridMath.rotatedSize(fp, r)
	local C = GridMath.CELL
	local centre = Vector3.new((x + w / 2) * C, y * GridMath.LAYER, (z + d / 2) * C)
	return CFrame.new(centre) * CFrame.Angles(0, r * math.pi / 2, 0)
end

-- Anchor cell for an item whose centre should sit as close as possible to a plot-local point.
function GridMath.anchorNear(localPoint: Vector3, fp: Footprint, r: number): (number, number)
	local w, d = GridMath.rotatedSize(fp, r)
	local C = GridMath.CELL
	local x = math.floor(localPoint.X / C - w / 2 + 0.5)
	local z = math.floor(localPoint.Z / C - d / 2 + 0.5)
	return x, z
end

-- Pack a cell into one integer key (each axis 0..1023).
function GridMath.key(x: number, y: number, z: number): number
	return x + z * 1024 + y * 1048576
end

return GridMath
```

Why `anchorNear` subtracts half the footprint: the player expects the **item's centre** to follow the cursor. Snapping the anchor corner to the cursor makes large items hang off to one side, which feels wrong immediately. Even-sized items centre on a grid line; odd-sized items centre on a cell centre; the `+ 0.5` then `floor` handles both.

### World and plot space

```lua
local localPoint = plotOrigin:PointToObjectSpace(worldHitPosition)
local x, z = GridMath.anchorNear(localPoint, fp, r)
local worldPivot = plotOrigin * GridMath.localPivot(x, y, z, fp, r)
```

That is the whole transform. If you find yourself subtracting plot positions by hand, you will break the day a plot is rotated.

### Cell grid versus edge grid

Floors, furniture and machines live in cells. **Walls and fences live on edges** between cells. Mixing them in one occupancy grid causes the classic bug where a wall "occupies" both neighbouring cells and nothing can be placed against it. Keep two grids:

| Grid | Key | Holds |
|---|---|---|
| Cell grid | (x, y, z) | Floors, furniture, machines |
| Edge grid | (x, y, z, side) with side 0 for the -X edge, 1 for the -Z edge of each cell | Walls, fences, doors, railings |

Each cell owns its -X and -Z edges; the +X edge of cell x is the -X edge of cell x + 1. With that convention every edge has exactly one key.

---

## 4. The client: ghost, input, feedback

### The ghost

The preview is a clone of the item with every part set to `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `Anchored = true`, and a transparency around 0.4 to 0.5. Tint validity with a single `Highlight` on the ghost model (green fill for valid, red for invalid) rather than recolouring every part: it is one instance and does not destroy the item's real colours ([[Highlights and Selection Effects]]).

`CanQuery = false` is the important one. Without it, the mouse raycast hits the ghost itself, the ghost moves to the hit point, the next raycast hits it again, and the ghost crawls toward the camera.

### Input per device

| Device | Move | Rotate | Place | Cancel |
|---|---|---|---|---|
| Mouse and keyboard | Ghost follows the cursor ray every frame | R (and Shift+R for reverse) | Left click | Right click or Escape |
| Touch | Ghost appears at screen centre (or where tapped) and is dragged with one finger | On-screen rotate button | On-screen confirm button | On-screen cancel |
| Gamepad | A screen-centre reticle; the stick steps the ghost cell by cell with repeat delay | Shoulder buttons | A | B |

Touch is where most building systems fail. Placing on finger-up is wrong because the finger covers the ghost; the player cannot see what they are placing. Drag to position, then confirm with a button, every time. Bind the actions with `ContextActionService` so mobile buttons and gamepad bindings come from the same code ([[Input - UserInputService and ContextActionService]], [[Gamepad and Console UX]]).

### Client-side validity is a hint

The client checks bounds and its local copy of occupancy to tint the ghost, but the server decides. If the client's occupancy copy is stale (another player on a shared plot just built there), the server rejects and the client shows a brief error and keeps the ghost. Never remove the item from the client's inventory until the server confirms.

```lua
--!strict
-- Client: per-frame ghost update for mouse input (simplified).
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GridMath = require(game:GetService("ReplicatedStorage").Shared.GridMath)

local function makeGhostUpdater(ghost: Model, plotOrigin: CFrame, plotFloor: BasePart, fp: GridMath.Footprint, isFree: (number, number, number, number) -> boolean)
	local rotation = 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plotFloor } -- only the plot floor: ghosts and props are ignored
	local highlight = ghost:FindFirstChildOfClass("Highlight") or Instance.new("Highlight")
	highlight.Parent = ghost
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = 0.5

	local current = { x = 0, z = 0, valid = false }

	local conn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		local m = UserInputService:GetMouseLocation()
		local ray = cam:ViewportPointToRay(m.X, m.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		if not hit then
			return
		end
		local localPoint = plotOrigin:PointToObjectSpace(hit.Position)
		local x, z = GridMath.anchorNear(localPoint, fp, rotation)
		current.x, current.z = x, z
		current.valid = isFree(x, 0, z, rotation)
		ghost:PivotTo(plotOrigin * GridMath.localPivot(x, 0, z, fp, rotation))
		highlight.FillColor = if current.valid then Color3.fromRGB(80, 255, 120) else Color3.fromRGB(255, 70, 70)
	end)

	return {
		rotate = function(dir: number)
			rotation = (rotation + dir) % 4
		end,
		get = function()
			return current.x, current.z, rotation, current.valid
		end,
		stop = function()
			conn:Disconnect()
		end,
	}
end

return makeGhostUpdater
```

`GetMouseLocation` with `ViewportPointToRay` is the correct pairing: both include the top bar inset. Mixing `ScreenPointToRay` with `GetMouseLocation` offsets the ray by the top bar inset height, so the ghost sits visibly below or above the cursor (the inset varies by device; see [[Safe Areas and Insets]]).

Smoothing: snapping the ghost between cells reads as jittery at high frame rates. Lerp the ghost's visual pivot toward the snapped target over about 0.05 to 0.08 s, and keep the logical cell snapped. Players see smooth motion; validity stays exact.

---

## 5. The server: validation and the occupancy grid

The server holds, per plot, an occupancy table (`key -> placement id`) and a list of placements. A placement request is the most exploited remote in any building game ([[Exploits and Anti-Cheat]]). Validate everything:

```lua
--!strict
-- Server: PlacementService.tryPlace (core validation).
local GridMath = require(game:GetService("ReplicatedStorage").Shared.GridMath)
local ItemDefs = require(game:GetService("ReplicatedStorage").Shared.ItemDefs) -- { [string]: { footprint: GridMath.Footprint, model: Model } }

type Placement = { id: number, itemId: string, x: number, y: number, z: number, r: number, model: Model? }
type Plot = {
	owner: Player,
	origin: CFrame,
	sizeX: number, sizeZ: number, layers: number, -- in cells
	occupied: { [number]: number },               -- cell key -> placement id
	placements: { [number]: Placement },
	nextId: number,
	count: number,
	folder: Folder,
}

local MAX_ITEMS_PER_PLOT = 400
local MIN_INTERVAL = 0.08 -- seconds between placements per player

local lastPlace: { [Player]: number } = {}

local function isInt(v: any): boolean
	return typeof(v) == "number" and v == v and math.floor(v) == v and math.abs(v) < 1e6
end

local function tryPlace(plot: Plot, player: Player, itemId: any, x: any, y: any, z: any, r: any, hasItem: (Player, string) -> boolean): (boolean, string?)
	if plot.owner ~= player then
		return false, "not your plot"
	end
	if typeof(itemId) ~= "string" or not ItemDefs[itemId] then
		return false, "unknown item"
	end
	if not (isInt(x) and isInt(y) and isInt(z) and isInt(r)) or r < 0 or r > 3 then
		return false, "bad coordinates"
	end
	local now = os.clock()
	if lastPlace[player] and now - lastPlace[player] < MIN_INTERVAL then
		return false, "too fast"
	end
	if plot.count >= MAX_ITEMS_PER_PLOT then
		return false, "plot full"
	end
	if not hasItem(player, itemId) then
		return false, "not owned"
	end

	local fp = ItemDefs[itemId].footprint
	local w, d = GridMath.rotatedSize(fp, r)
	if x < 0 or z < 0 or y < 0 or x + w > plot.sizeX or z + d > plot.sizeZ or y + fp.h > plot.layers then
		return false, "out of bounds"
	end

	-- every covered cell must be free
	local keys: { number } = {}
	for cx = x, x + w - 1 do
		for cz = z, z + d - 1 do
			for cy = y, y + fp.h - 1 do
				local k = GridMath.key(cx, cy, cz)
				if plot.occupied[k] then
					return false, "blocked"
				end
				table.insert(keys, k)
			end
		end
	end

	-- commit
	lastPlace[player] = now
	local id = plot.nextId
	plot.nextId += 1
	for _, k in keys do
		plot.occupied[k] = id
	end
	local model = ItemDefs[itemId].model:Clone()
	model:PivotTo(plot.origin * GridMath.localPivot(x, y, z, fp, r))
	model:SetAttribute("PlacementId", id)
	model.Parent = plot.folder
	plot.placements[id] = { id = id, itemId = itemId, x = x, y = y, z = z, r = r, model = model }
	plot.count += 1
	return true, nil
end

return tryPlace
```

What each check prevents:

| Check | Exploit or bug it stops |
|---|---|
| Owner | Building on other players' plots |
| `isInt` including `v == v` | `NaN` (fails every comparison, so naive bounds checks pass it), fractional cells, huge numbers |
| Rotation 0..3 | Arbitrary angles that break the footprint maths |
| Rate limit | Placement spam that floods replication ([[Rate Limiting and Abuse Prevention]]) |
| Item cap | Instance bombs that crash other clients |
| Ownership of the item | Placing items never bought |
| Bounds, then occupancy | Building outside the plot, overlapping |

Because the server processes remote events one at a time, two requests for the same cell in the same frame cannot both succeed: the second sees the first's occupancy. That only holds if nothing yields between the occupancy check and the commit. Do not put a DataStore call or `task.wait` between them.

### Grid occupancy versus physical overlap

The occupancy grid is the rule. A physics overlap test (`workspace:GetPartBoundsInBox`) is useful only for items that are not on the grid (free placement, decorations on walls) or to stop building inside world geometry that is not in the grid (a tree on the plot). When you use it, **shrink the test box by a small margin (0.05 to 0.1 studs per side)**. Items placed exactly edge to edge touch, and an unshrunk test reports neighbours as overlapping ([[Raycasts Shapecasts and Spatial Queries]]).

### Support and stacking

If items can stack (a lamp on a table, a second floor on walls), add a support rule: every cell at `y > 0` needs something below that allows stacking (a `supportsStacking` flag on the definition). Removing an item must then check what it supports: either block the removal ("something is on top") or remove dependents too. Blocking is simpler and avoids accidental mass deletion.

---

## 6. Saving and loading builds

### Format

Store each placement as five small integers plus an item id:

```lua
-- in the profile: plot = { v = 2, items = { { "bench_wood", 3, 0, 7, 1 }, { "lamp_iron", 4, 1, 7, 0 }, ... } }
```

At roughly 25 to 35 characters of JSON per placement, 400 items is around 12 KB, well inside a DataStore value (4 MB, Roblox docs as of October 2026). Do not store world positions, model names or `CFrame`s; they are larger and break when anything moves. For very large builds, pack into a `buffer` with a short-id table ([[Buffers and Binary Data]]).

### Loading must revalidate

Item definitions change between updates: a footprint grows from 1 x 1 to 2 x 1, an item is removed, the plot shrinks. Saved data that was valid last week may overlap or fall out of bounds today. On load:

1. Run every saved placement through the same validation as a live placement (skipping rate limit and ownership of the inventory item, since placed items are already "spent").
2. Placements that fail go back to the player's inventory with a one-time message ("3 items were returned to your inventory after an update").
3. Bump the format version `v` when the save shape changes, and migrate ([[Data Schema Design and Migrations]]).

Never silently delete failed placements. Players notice a missing item they paid for long before they notice anything else.

### Spawning without a hitch

Spawning 400 models in one frame on join causes a server hitch and a large replication burst to every client. Spawn in batches (20 to 50 per `task.wait()`), nearest to the plot entrance first so the player sees their build assemble from the front. If players can teleport into a busy server, everyone's plot loads at once; stagger plot loads by a few seconds per player.

---

## 7. Budgets and streaming

A building game's instance count is decided by its players. Do the arithmetic before launch:

```
players per server x item cap per plot x average parts per item = worst-case parts
20 x 400 x 12 = 96,000 parts
```

That worst case is too many for phones (rule of thumb; measure in your game with [[Developer Console and Stats]]). Levers, in order of effectiveness:

- **Fewer parts per item.** A bench made of 12 parts can be one `MeshPart`. Building items should be single meshes or very small models ([[Parts Unions and MeshParts]], [[Art Budgets - Triangles Draw Calls Memory]]).
- **A plot item cap** with clear UI, and a cap on expensive categories (lights, emitters, moving machines).
- **Streaming** with plots as models streamed by distance. With `StreamingEnabled`, set each placed item's `ModelStreamingMode` to `Atomic` so it streams in whole rather than part by part ([[Instance Streaming]], [[Level of Detail and Model Streaming]]). Your own plot can be kept loaded around the player with `RequestStreamAroundAsync` when they enter build mode.
- **Lights and effects** on placed items disabled beyond a distance on the client; 400 lamps with `PointLight`s across 20 plots will cost more than the geometry ([[Light Sources and Shadows]]).

---

## 8. When not to use a grid

- **Decoration and personal expression** (posters, plushies, clutter) feel better with free placement on surfaces: raycast the cursor, align to the hit normal, snap rotation to 15 or 45 degrees, validate with a shrunk overlap test. Many housing games mix: grid for furniture, free for decor.
- **Organic layouts** (gardens, paths) fit a finer sub-grid (1 stud) or curve tools better than a 4-stud grid.
- **Physics toys** that players drop and push around should not be in the occupancy grid at all.

Roblox's `DragDetector` instances offer built-in runtime dragging with several drag styles and server or client authority. They suit free-form object manipulation; for grid building with footprints, rotation rules and occupancy, a custom controller like the one above stays simpler to validate.

---

## Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Storing world positions | Builds land in the wrong place on another plot | Plot-local cells |
| Anchor corner follows the cursor | Large items hang off one side | Centre the footprint on the cursor |
| Footprint not swapped on rotation | Rotated items overlap or leave gaps | `rotatedSize` everywhere |
| Ghost hit by its own raycast | Ghost crawls toward the camera | `CanQuery = false`; include-list raycast |
| Place on touch release | Players misplace items under their finger | Drag then confirm button |
| Bounds check without `NaN` check | Exploiters place items anywhere | `v == v` and integer checks |
| Yield between check and commit | Rare overlapping items | Keep validation and commit synchronous |
| Unshrunk overlap boxes | Valid edge-to-edge placements rejected | Shrink by 0.05 to 0.1 studs |
| Silent deletion of invalid saves | Support tickets about missing items | Refund to inventory with a message |
| Walls in the cell grid | Nothing fits next to walls | Separate edge grid |
| Whole plot spawned in one frame | Join hitch | Batched spawning |

---

## Checklist

- [ ] Studio kits audited for off-grid pivots and yaw.
- [ ] Placements stored as (itemId, x, y, z, r) in plot-local cells with a format version.
- [ ] Footprints rotate correctly; centre follows the cursor.
- [ ] Separate cell and edge grids if walls exist.
- [ ] Ghost is non-queryable and tinted with one Highlight; smooth visual, snapped logic.
- [ ] Mouse, touch (drag then confirm) and gamepad (cell stepping) all supported.
- [ ] Server validates owner, types, NaN, rotation, rate, cap, item ownership, bounds and occupancy, with no yield before commit.
- [ ] Removal respects stacking support.
- [ ] Loading revalidates and refunds failures with a message.
- [ ] Plot spawning batched; worst-case part count computed; streaming configured.

## See also

[[Modular Environment Kits]], [[Genre Playbook - Tycoons]], [[Server Authority and Validation]], [[Exploits and Anti-Cheat]], [[Rate Limiting and Abuse Prevention]], [[Data Schema Design and Migrations]], [[Raycasts Shapecasts and Spatial Queries]], [[Instance Streaming]], [[Input - UserInputService and ContextActionService]], [[Gamepad and Console UX]], [[Highlights and Selection Effects]], [[Tools and Inventory Systems]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Scale Grids and Stud Alignment]] · [[Voxel Props Environments and Modular Tiles]] · [[Cookbook - Math CFrame and Vectors]] · [[Tycoon Plots and Droppers End to End]] · [[MCP Workflows for Building Worlds]] · [[Intersection and Collision Math]]
<!-- auto-links:end -->
