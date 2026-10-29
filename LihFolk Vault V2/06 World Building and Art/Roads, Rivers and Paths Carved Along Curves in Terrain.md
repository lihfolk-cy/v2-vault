---
tags: [terrain, roads, rivers, splines, world-building, procedural, type/guide, area/world-building, level/advanced, api/Terrain, api/FillBlock, api/FillBall]
---
# Roads, Rivers and Paths Carved Along Curves in Terrain

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Sampling by `t`, not distance -> Even arc-length resampling
> - Avoid: Carving without filling below -> Solid slab under every sample
> - Avoid: No clear above -> Air block above the bed
> - Control points ordered; spline evaluated and resampled by arc length.
> - Grade smoothed and slope clamped for vehicles.
> - Clear-above, fill-below, surface and shoulder passes with overlap.
>
> Cost: TL;DR ~140 tok · whole note ~2.6k tok. Read more: ## 1. The curve · ## 2. Carving a road bed · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Hand-painting a winding road or river with the terrain brushes gives wobbly edges, uneven grade and a bed that does not match the banks. Driving the same work from a spline gives a smooth curve you can edit by moving a few control points and regenerate in seconds. This note covers sampling a curve at even spacing, carving and filling terrain along it, banks and blending, road meshes laid over terrain, river beds with water, and the Studio workflow (chunking, undo, verification). Terrain API basics are in [[Terrain Tools and Terrain API]]; curve maths in [[Curves in Luau - Paths Beams and Motion]].

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Measured** (method given), **Rule of thumb**. Code is strict Luau, runs in the command bar or a plugin, **reviewed, not run**.

---

## 1. The curve

Place control points as small anchored parts in a folder, named or attributed for order (`Index`). Use a **Catmull-Rom** spline: it passes through every control point, so builders place points exactly where the road should go.

```lua
--!strict
local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

-- Dense samples, then resample at an even arc-length step.
local function sampleEven(points: { Vector3 }, step: number): { Vector3 }
	local dense: { Vector3 } = {}
	for i = 1, #points - 1 do
		local p0 = points[math.max(i - 1, 1)]
		local p1, p2 = points[i], points[i + 1]
		local p3 = points[math.min(i + 2, #points)]
		for s = 0, 19 do
			table.insert(dense, catmullRom(p0, p1, p2, p3, s / 20))
		end
	end
	table.insert(dense, points[#points])

	local out = { dense[1] }
	local carry = 0
	for i = 2, #dense do
		local a, b = dense[i - 1], dense[i]
		local seg = (b - a).Magnitude
		local d = step - carry
		while d <= seg do
			table.insert(out, a:Lerp(b, d / seg))
			d += step
		end
		carry = seg - (d - step)
	end
	return out
end
```

Parameter `t` is not distance; equal `t` steps bunch up on tight curves and spread on long straights. Even arc-length resampling is what makes the carved width and grade consistent. Rule of thumb: step of 2 to 4 studs for terrain carving (terrain resolution is 4 studs per voxel, Roblox docs), 8 to 16 for road mesh segments.

**Grade.** Smooth the Y values separately (a moving average over a few samples) before carving, or the road follows every lump of the control-point heights. For vehicles, clamp the slope between samples; very steep steps make cars launch.

## 2. Carving a road bed

For each sample, build a frame from the tangent: `CFrame.lookAt(p, p + tangent)` with the up vector forced to world up so the road does not bank unless you want it to. Then for each sample:

1. **Clear above**: `Terrain:FillBlock(frame * CFrame.new(0, clearH / 2, 0), Vector3.new(width + 2 * shoulder, clearH, step * 1.5), Enum.Material.Air)` removes hills the road cuts through.
2. **Fill below**: `FillBlock` a slab under the road surface with a solid material (Ground or Rock) so the road never floats over a valley.
3. **Surface**: `FillBlock` a thin slab of `Enum.Material.Asphalt` (or Pavement, Cobblestone, Mud for paths) at the road width.
4. **Shoulders**: a wider, slightly lower slab of the surrounding material so the edge slopes rather than cliffs.

Roblox docs: fill methods compute partial occupancy at the boundary, so a rotated `FillBlock` produces a smooth slope. Overlap consecutive blocks (length about 1.5 times the step) so there are no gaps on curves.

```lua
--!strict
local Terrain = workspace.Terrain

local function carveRoad(samples: { Vector3 }, width: number)
	for i = 1, #samples - 1 do
		local a, b = samples[i], samples[i + 1]
		local mid = (a + b) / 2
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		if flat.Magnitude < 1e-3 then continue end
		local frame = CFrame.lookAt(mid, mid + flat) * CFrame.Angles(math.atan2(b.Y - a.Y, flat.Magnitude), 0, 0)
		local len = (b - a).Magnitude * 1.5
		Terrain:FillBlock(frame * CFrame.new(0, 12, 0), Vector3.new(width + 8, 24, len), Enum.Material.Air)
		Terrain:FillBlock(frame * CFrame.new(0, -6, 0), Vector3.new(width + 8, 12, len), Enum.Material.Ground)
		Terrain:FillBlock(frame * CFrame.new(0, -0.5, 0), Vector3.new(width, 1, len), Enum.Material.Asphalt)
	end
end
```

**Measured, not documented:** terrain surfaces do not sit exactly at the top of the block you fill; the existing terrain note records a measured offset of roughly 2 studs for a 4-stud block. Raycast down onto the result at a few samples and adjust your vertical offsets before carving a whole map.

## 3. Road meshes over terrain

Terrain roads look soft and blurry at 4-stud resolution. For crisp lane markings, lay mesh or part segments along the spline **on top of** a carved bed:

- One segment per 8 to 16 studs, each oriented to its chord; tiny gaps on curves are hidden by slightly overlapping segments or by a wedge filler.
- Lift segments 0.05 to 0.2 studs above the terrain surface to avoid z-fighting.
- Use a tiling texture (`SurfaceAppearance` or `Texture` with `StudsPerTileV`) so markings flow along the road; see [[Textures Decals and Texture Memory]].
- Collision: the segments should be the driving surface (vehicles behave better on flat parts than on voxel terrain). Set `CanCollide` on segments; terrain under them is just visual backing.
- Instance count: a long road at 8-stud segments is thousands of parts. Merge segments per chunk into meshes in Blender for shipping, or keep parts and rely on streaming ([[Level of Detail and Model Streaming]]).

## 4. Rivers

1. **Bed**: for each sample, `FillBall` or `FillCylinder` Air to carve a rounded channel, then a thin lining of Mud, Sand or Rock along the bottom.
2. **Water**: `FillBlock` with `Enum.Material.Water` from the bed up to the water line. Keep the water surface **flat per segment** and step it down only at deliberate places (rapids, falls); a river whose water follows every grade wobble shows visible seams.
3. **Banks**: blend the surrounding material outward with a wider, shallower carve so the river does not sit in a vertical trench.
4. **Flow**: terrain water has no flow direction you can author per voxel; flowing water is sold with particles, a scrolling `Texture` or Beam on a transparent surface plane, and sound. `Workspace.Terrain` has global water properties (`WaterWaveSize`, `WaterWaveSpeed`, `WaterColor`, `WaterTransparency`, Roblox docs) that apply to all water in the place.

In the newer voxel channel API, water is stored as `LiquidOccupancy` on air voxels rather than as a solid material (Roblox docs, see [[Terrain Tools and Terrain API]]); fill methods handle this for you.

Boats need enough depth and width; check against [[Boats Buoyancy and Water]].

## 5. Studio workflow

- **Chunk the work.** Carve a few hundred samples per call, yield between chunks in a plugin (`task.wait()`), and print progress. One giant command freezes Studio and, per the terrain note's experience, can partially fail.
- **Undo.** Wrap plugin operations in `ChangeHistoryService:TryBeginRecording` / `FinishRecording` (Roblox docs) so one Ctrl+Z reverts a carve. Command bar operations may not be undoable as a single step; save a copy of the place first.
- **Regenerate, do not patch.** Keep control points and parameters (width, depth, materials) in the folder as attributes. When the road changes, restore the terrain region from a saved copy (`Terrain:CopyRegion` / `PasteRegion`, Roblox docs) or recarve, rather than painting fixes by hand.
- **Verify** with raycasts down each sample: surface height within tolerance, material as expected.
- **Order matters**: carve rivers before roads (bridges go over rivers), and both before scattering foliage ([[Foliage Props and Scatter]]) so trees do not land in the road.

---

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Sampling by `t`, not distance | Road narrows and gaps on curves | Even arc-length resampling |
| Carving without filling below | Road floats over valleys | Solid slab under every sample |
| No clear above | Road tunnels into hills | Air block above the bed |
| Blocks exactly one step long | Jagged gaps on bends | Overlap 1.5x step |
| Mesh road on raw terrain | Z-fighting, bumpy driving | Carve flat bed, lift segments slightly |
| Water following every grade change | Visible water seams | Flat per segment, deliberate steps |
| One huge carve call | Studio freezes, partial terrain | Chunked, yielded, recorded for undo |
| Hand-fixing after generation | Fixes lost on the next regenerate | Parameters on control points; recarve |

## Checklist

- [ ] Control points ordered; spline evaluated and resampled by arc length.
- [ ] Grade smoothed and slope clamped for vehicles.
- [ ] Clear-above, fill-below, surface and shoulder passes with overlap.
- [ ] Measured terrain surface offset accounted for.
- [ ] Mesh road segments lifted, textured along the road, chunked or streamed.
- [ ] River bed, flat water segments, banks, flow faked with VFX.
- [ ] Carving chunked with undo recording; place backed up.

## See also

[[Terrain Tools and Terrain API]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Curves in Luau - Paths Beams and Motion]] · [[Bezier Curves and Splines for Modellers]] · [[Noise Functions and Terrain Generation]] · [[Water Sky and Atmosphere Art]] · [[Foliage Props and Scatter]] · [[Boats Buoyancy and Water]]

## Connected notes
<!-- auto-links:start -->
[[Procedural World Generation]] · [[Genre Playbook - Racing and Driving]] · [[Level of Detail and Model Streaming]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Terrain Materials and Painting]] · [[MCP Workflows for Building Worlds]] · [[Parts Unions and MeshParts]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Level Design for Roblox]] · [[Collision and Physics Geometry]] · [[Voxel Art - Studs Outlines and Style Kits]]
<!-- related:end -->
