---
tags: [mcp, agents, world-building, terrain, workflow]
---
# MCP Workflows for Building Worlds

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Asking for a vibe ("make it lush") instead of a placement table.
> - Avoid: Placing at computed heights instead of raycast hits.
> - Avoid: Default raycast filters that hit other props.
> - Target area and owner confirmed (no other agent working there).
> - Snapshot or Version History save done; terrain region copied if terrain will change.
> - Placement table on disk; reviewed for one zone.
>
> Cost: TL;DR ~140 tok · whole note ~3.5k tok. Read more: ## 3. Placing props: grounding and overlaps · ## 4. Terrain through an agent · ## 8. Common mistakes · ## 9. Checklist for an agent world-building pass
<!-- tldr:end -->

An AI agent connected to Studio through MCP can place thousands of props, sculpt terrain, dress zones and restyle a hub in an afternoon. It can also bury half your props under the ground, flood a map with terrain water that stalls joining, mirror a model into a broken mess, or overwrite another person's terrain with one bad write. This note is the working method for world building through MCP: how to structure the work, how to verify it without trusting screenshots, and the engine traps that agents hit.

It assumes the tools from [[Roblox Studio MCP Server]] and [[Blender MCP]], and the rules in [[Safety Rules for AI Agents in Studio]]. Numbers marked **Measured** come from the reference project, which built two realms of zones, a hub and an arena largely through agents. **Rule of thumb** marks experience.

---

## 1. The loop: inspect, plan as data, build in slices, verify numerically

The single biggest improvement in agent world building is to stop asking for "a forest" and start asking for **data**.

1. **Inspect.** `search_game_tree` with filters on the target folder; `inspect_instance` on key anchors (spawn, gates, zone bounds). Record coordinates in the project notes so the next session does not rediscover them.
2. **Plan as data.** The agent writes a placement table offline (a Lua or JSON file on disk): asset name, position, yaw, scale, which folder. The table is reviewable, diffable and re-runnable.
3. **Build in slices.** Studio executes the table in budgeted chunks (under about 1.5 s per call, Measured), each call returning a short report and a resume index.
4. **Verify numerically.** Raycasts, overlap queries, counts and bounding boxes, returned as numbers. Screenshots only for the final look, and only when the human wants them.
5. **Record.** What was built, where, by which tool, and how to undo it (folder name, attribute markers).

| Step | Tool | Output |
|---|---|---|
| Inspect | `search_game_tree`, `inspect_instance`, `execute_luau` (read-only) | Coordinates, sizes, existing folders |
| Plan | Files on disk (the agent's own editor tools) | Placement table |
| Build | `execute_luau` (chunked), local HTTP loader for big data | Instances in a named folder |
| Verify | `execute_luau` returning numbers | Counts, misses, overlaps |
| Look | `screen_capture` (optional) | One image |

Why data first: an agent improvising placements inside `execute_luau` cannot be reviewed, cannot be re-run identically after a fix, and mixes "decide" with "do". A table separates them. It also lets a human say "move every rock in zone 4 up 2 studs" and get exactly that.

---

## 2. Getting big data into Studio

Placement tables for a whole zone get large. Pasting thousands of lines through a tool call is slow and bloats the model's context. The reference project served files from a local static HTTP server and pulled them in from Studio:

```lua
-- Edit mode, via execute_luau or the command bar. Requires HTTP requests allowed for this place
-- (Game Settings > Security), and a local server such as: py -m http.server 8765 --bind 127.0.0.1
local HttpService = game:GetService("HttpService")
local url = "http://127.0.0.1:8765/zone04_props.json?x=" .. os.clock() -- query string busts caches
local rows = HttpService:JSONDecode(HttpService:GetAsync(url, true))
return #rows
```

HttpService has a per-place request budget (Roblox docs list 500 requests per minute for a game server; Measured: the same limit bit in Studio, with "Number of requests exceeded limit" errors). Fetch one file per zone, not one per prop. Details and the receiver side are in [[Studio Plugins and Local HTTP Bridges]].

---

## 3. Placing props: grounding and overlaps

### 3.1 Ground with a terrain-only raycast
Props placed at a computed height float or sink, because terrain's rendered surface is not where naive maths says it is (section 4). Cast down and place on the hit:

```lua
--!strict
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain } -- terrain only: ignore other props, players, bounds

local function groundY(x: number, z: number, fromY: number): number?
	local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -2000, 0), params)
	return if hit then hit.Position.Y else nil
end

local function placeOnGround(model: Model, x: number, z: number, yawDeg: number, sink: number): boolean
	local y = groundY(x, z, 2000)
	if not y then
		return false -- report misses instead of placing in the void
	end
	-- Pivot sits at the model's base in this convention; sink a little to hide gaps on slopes.
	model:PivotTo(CFrame.new(x, y - sink, z) * CFrame.Angles(0, math.rad(yawDeg), 0))
	return true
end
```

Why terrain-only (Measured): with default filters the ray hits the tree you placed a moment ago, the invisible zone bounds, or a collider, and the next prop lands on top of them.

### 3.2 Overlap tests: the precise query, not the bounding box
To keep props from intersecting each other or blocking paths, test overlaps. Measured: `GetPartBoundsInBox` over-reports on large meshes, because it tests axis-aligned bounding boxes, and a big curved rock's box covers empty air. `GetPartsInPart` uses the part's actual geometry (within its collision fidelity) and gives far fewer false positives. Use the box query as a cheap first filter, the part query to confirm.

### 3.3 Decor defaults
The reference project's convention for every placed decor piece (Measured, a good default):
- `Anchored = true`.
- `CanTouch = false` (no touch events from scenery).
- Tiny parts `CastShadow = false`.
- MeshParts `RenderFidelity = Automatic`.
- Colliding props only outside the areas where enemies walk; decor inside those areas non-colliding, so pathing is not blocked.

An agent will not apply these unless told. Put them in the placement tool, not in each prompt. See [[Collision and Physics Geometry]] and [[Foliage Props and Scatter]].

### 3.4 Pivots and mirroring
Two traps (Measured):
- **`Model:PivotTo` with a mirrored CFrame does not mirror a composite model.** Negative scale in a CFrame is not a mirror operation for models. Build a mirrored version of the asset in Blender instead.
- For models whose `PrimaryPart` owns the pivot, **writes to `WorldPivot` are ignored**; set `PrimaryPart.PivotOffset` instead. An agent that "fixed the pivot" and saw no change was writing the wrong property.

---

## 4. Terrain through an agent

Terrain is where agents do the most damage, because terrain is one shared object, edits are large, and a bad write is not easy to undo.

### 4.1 Rules (Measured)
- **One `WriteVoxels` per call, then read it back** to verify. Big multi-region writes in one call freeze Studio and are hard to verify.
- **Snapshot before any bulk rewrite**: `Terrain:CopyRegion` into a `TerrainRegion` stored in ServerStorage (or saved to disk), and ask the human first. Other people share the terrain.
- **Never rely on undo** to recover terrain. In the reference project, an undo meant to restore terrain went about 40 waypoints back and rolled back other sessions' unrelated changes (see [[Safety Rules for AI Agents in Studio]]).
- **Never fill big areas with terrain water.** A 5,000 by 1,900 stud sea stalled joining. A flat transparent part with a water look fakes it cheaply. See [[Water Sky and Atmosphere Art]].

```lua
-- Snapshot a terrain region before editing it. Region bounds must align to the 4-stud voxel grid.
local terrain = workspace.Terrain
local min = Vector3int16.new(-512, -64, -512) -- in voxel cells (4 studs each)
local max = Vector3int16.new(511, 127, 511)
local snapshot = terrain:CopyRegion(Region3int16.new(min, max))
snapshot.Name = "TerrainSnap_Zone04"
snapshot.Parent = game:GetService("ServerStorage")
-- Restore later with: terrain:PasteRegion(snapshot, min, true)
return snapshot.Name
```

(`CopyRegion` has a maximum region size; split large areas. Check the current limit in the `Terrain` API reference.)

### 4.2 The surface is not where the maths says
Measured: computing the surface as "cell bottom + occupancy x 4" put it about 0.8 to 1.6 studs below the rendered surface. Fix: after writing, raycast the real surface and correct heights by the measured deltas ("re-grounding"). Another measured note in the same project put the rendered surface about 2 studs above the occupancy top; the exact offset depends on neighbouring cells, so **measure, do not assume**.

### 4.3 Material quirks
Measured in a place using legacy terrain materials: Brick and WoodPlanks render as 4-stud cubes, Concrete in 2-stud steps, Pavement in 1-stud steps; to keep a surface material from showing what is under it, write it about 16 studs deep. Terrain colours are set per material and are **global**: you cannot have two shades of Grass in two zones. If zones need different ground colours, use different materials (or MaterialVariants). See [[Terrain Tools and Terrain API]].

---

## 5. Big content: build offline, install in Studio

For anything more than placement, the reference project moved the work out of Studio entirely:

- **Meshes** modelled in Blender (by hand, or by an agent through [[Blender MCP]] and headless `blender -b` scripts), uploaded with the asset ids recorded in a JSON file per batch.
- **An installer module** in ServerStorage (a "DevTools" folder) with entry points like `Status()`, `Install()`, `Verify()`, `Remove()`. The agent calls one entry point per Studio call. Installers are idempotent: running twice does not duplicate.
- **Generated definitions**: zone and enemy definitions were edited as source files on disk, run through a generator script, and pushed into Studio as ModuleScripts.

This makes a zone rebuild a sequence of short, verifiable calls, and makes it re-runnable after a fix. See [[Batch Processing Tools in Studio]] and [[Environment and Level Pipeline]].

---

## 6. Seeing what you built

### 6.1 Prefer numbers
For almost every question, a number is cheaper and more reliable than an image:

| Question | Numeric check |
|---|---|
| Is anything floating? | For each prop, raycast down from its base; report gaps over 0.5 studs |
| Is the path clear? | Shapecast or `GetPartsInPart` along the path; list blockers |
| Did all props place? | Count placed vs table rows; list misses |
| Is the zone inside its bounds? | Compare bounding boxes with the bound parts |
| Did the instance count blow up? | `#folder:GetDescendants()` before and after |

### 6.2 When you do capture
- Studio must be in front, or the capture is black (Measured).
- Lighting previews (applying a zone's lighting preset for a capture) must be **restored exactly** afterwards. Measured: a client weather system read the place's `Atmosphere` as its base at Play start, so a preview left on changed the game's look.
- Restore the camera after positioned captures ([[Roblox Studio MCP Server]], section 5.4).
- Locked-zone "shadow shells" or other hiding geometry moved for inspection must be put back.

### 6.3 Human review is the art check
Agents cannot judge style reliably from screenshots. The reference project wrote a style guide (one art style for all assets, explicit forbidden elements) and the human approved a pilot zone before the agent repeated the pattern across the other zones. Pilot, approve, then scale.

---

## 7. Performance is part of world building

Agents build fast, and instance counts grow faster than anyone notices.

- Measured: the place reached about **1.07 million instances** (much of it backup copies and archived data) and Studio ran at about **15 fps**. Removing backup folders and moving archives to disk fixed it. See [[Case Study - Instance Cleanup and Place Size]] and [[Case Study - Cutting a Million Instances]].
- Measured: replicated storage went from about 392k to 107k instances by baking animation clips into compact stubs, which every client benefits from.
- Give each kit or zone an **instance budget** (the reference project used 2,500 per weapon kit folder) and have the installer report it.

See [[Art Budgets - Triangles Draw Calls Memory]] and [[Level of Detail and Model Streaming]].

---

## 8. Common mistakes

- Asking for a vibe ("make it lush") instead of a placement table.
- Placing at computed heights instead of raycast hits.
- Default raycast filters that hit other props.
- Multi-region terrain writes in one call.
- No snapshot before terrain edits.
- Using undo to fix a mistake.
- Filling a lake with terrain water.
- Mirroring with `PivotTo`.
- Leaving a lighting preview or a moved shell in place.
- Building twelve zones before the human approves one.

## 9. Checklist for an agent world-building pass

- [ ] Target area and owner confirmed (no other agent working there).
- [ ] Snapshot or Version History save done; terrain region copied if terrain will change.
- [ ] Placement table on disk; reviewed for one zone.
- [ ] Installer is idempotent and chunked under the call budget.
- [ ] Decor defaults applied by the tool.
- [ ] Numeric verification: misses, floaters, overlaps, counts, instance budget.
- [ ] Lighting, camera and hidden geometry restored.
- [ ] Notes updated with locations, folder names and how to remove.

## See also

- [[MCP Workflows for Scripting and Debugging]], [[Safety Rules for AI Agents in Studio]], [[Multiple Agents in One Studio]]
- [[Level Design for Roblox]], [[Terrain Tools and Terrain API]], [[Procedural World Generation]], [[Modular Environment Kits]]
- [[Studio Plugins and Local HTTP Bridges]], [[Environment and Level Pipeline]], [[Batch Processing Tools in Studio]]
- [[Case Study - Building a Game with AI Agents]]

## Connected notes
<!-- auto-links:start -->
[[AI Agents and Autonomous Workflows]] · [[Roblox Studio Assistant]] · [[Pipeline Design Principles]] · [[Writing Your Own MCP Server]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Safe Changes in a Shared Place]]
<!-- auto-links:end -->
