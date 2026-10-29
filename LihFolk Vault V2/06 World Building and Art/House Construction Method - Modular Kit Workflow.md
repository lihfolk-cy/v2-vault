---
tags: [world-building, building, houses, architecture, modular, kits, roof, walls, interior, blender, lihfolk, type/guide]
verified: 2026-10-29
---
# House Construction Method - Modular Kit Workflow

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Heights typed by hand for gable courses, chimney and icicles -> One `Gable` function; derive every height from it
> - Avoid: One origin per module -> Shared bottom-centre origin for every module (`lh.recentre`)
> - Avoid: Trusting the per-module gate for small parts -> `lh.floating_shells` on the whole house, 0 required
> - Brief written: avatar proxies, door 3.6-4 x 7.5-8, storey, wall thickness, pitch, palette, seed
> - Modules split by collision, material, swap and budget; one material each
> - One Gable function drives the courses, roof, chimney and icicles
>
> Cost: TL;DR ~180 tok · whole note ~5.3k tok. Read more: ## 9. Style-swap table · ## 11. LOD, collision and Studio import · ## Common mistakes · ## Checklist
<!-- tldr:end -->

This is a repeatable way to build any small building for Roblox (a cabin, cottage, medieval house, modern house, fantasy hut or shop) as modules that pass the LihFolk gate on the first draft and drop into Studio already lined up. It turns the lessons of one finished build, [[Stylised Log Cabin Worked Example]], into rules for every house. A stone cottage built afterwards from the same builders checked them: it passed every gate, with 0 floating parts, after two changes made before any review.

The code is `skills/roblox-blender-modeling/scripts/lihfolk_house.py` (`import lihfolk_house as lh`), next to `lihfolk_bpy` and `lihfolk_curves`. Numbers marked **Measured** come from the cabin (blind review, gate) or the cottage test (gate only, Blender 5.2, October 2026). Everything else is a rule of thumb.

## 1. Brief: scale from the avatar first

Write these numbers down before modelling. Every later measurement is derived from them.

| Item | Default (studs) | Why |
|---|---|---|
| Avatar proxies | 5 (classic R15) and 6.5 (tall R15) | Check every opening against both ([[Modelling to the Roblox Camera and Player Scale]]) |
| Door opening | 3.6-4 wide x 7.5-8 tall | Cabin and cottage used 3.6 x 7.5 (**Measured**). Size for the tallest avatar you allow, plus margin ([[Proportion Exaggeration and Gameplay Distance]]) |
| Storey height (floor to eave) | 10-12 | Cabin eave about 12.4, cottage 10 above a 0.6 plinth (**Measured**). Interiors need 2-3 avatar heights or the camera clips the ceiling |
| Wall thickness | 1-1.4 | Logs of radius 0.62 give 1.24, stone blocks 1.2 (**Measured**). Keep one thickness per house so interior pieces attach |
| Window | 1.8-2.8 wide x 3-3.8 tall, sill 3-4 above the floor | Reads as a window from 40 studs and frames a head-height view inside |
| Plinth or sill | 0.5-0.9 | Lifts the walls off uneven ground and hides the terrain seam |
| Step rise | 0.3-0.5 | Cabin steps 0.31 each (**Measured**). Test the real rise with an avatar in Studio |
| Roof pitch | 40-60 degrees | Cabin 50, cottage 45 (**Measured**). Pitch is the strongest style lever (section 9) |

Also decide the **palette** (section 5), the **seed** (`random.Random(n)`, so every rebuild is identical) and the **module list** (section 2).

## 2. Split into modules by what Roblox needs

Split along the lines where collision, material, swapping or budget change, not along "what looks like one thing". This is the split that worked, generalised:

| Module | Contains | Roblox reason | lh builder |
|---|---|---|---|
| Foundation / base | Plinth, sill logs, ground plate, drifts | Optional when the map has its own ground; it is the "ground" in the floating scan | `foundation`, `plank_deck` |
| Walls | Courses with real openings, corners, gable infill | The collision mass | `log_walls`, `coursed_walls` |
| Roof | Slab or rows, ridge cap, snow, icicles | Different collision (none or Hull); swap for a summer or damaged roof | `gable_roof`, `icicle_row` |
| Chimney | Stack, crown, flue, cap | Small, sits on the roof, often reused | `chimney` |
| Trim | Frames, mullions, sills, shutters, caps | Decoration only: no collision | `window` |
| Glow | Window and lantern glass | Needs Neon or emission in Studio | `window` (glass goes to the glow builder) |
| Door / porch | Door, frame, steps, deck, posts, rails | Densest detail; the door may become an interactive part | `door`, `steps`, `plank_deck` |
| Props | Firewood, lantern, barrels, smoke | Optional, reusable, often animated or transparent | `MeshBuilder` primitives |

Rules:
- **One `MeshBuilder` per module, one material per module.** Vertex colours go on one white material (the gate's A10).
- **Corners belong to the walls.** In log and block styles the corner is woven from the two walls' courses. Only timber-frame and modern styles get separate corner posts.
- **Keep each module under its class ceiling** (section 6). If the walls go over, split them into front and back plus sides, not into random chunks.

## 3. Grid, pivots and the shared origin

Two scales of snapping, with different rules:

- **One house made of modules (hero or landmark):** every module's origin is the bottom centre of the *whole* house (`lh.recentre`, then `set_origin(..., "point", at=(0, 0, 0))` inside `lh.finish_modules`). Imported together, the modules land on each other exactly. The cabin needed this because per-module origins scattered its 8 modules (**Measured**).
- **Many houses from a kit (village, player building):** pieces with grid-corner origins on a fixed grid, validated with `lf.grid_check` and `lf.tile_check`. The LihFolk Modular kit uses a 2-stud grid with 8 x 2 x 12 wall pieces. [[Modular Environment Kits]] has the grid and pivot rules, and [[Grid Placement and Player Building Systems]] has the runtime side.

Whichever you use, build in one **house frame**: footprint centred on the origin, ridge along Y, eave walls on x = +-hx, gable walls on y = +-hy, and the front facing -Y. Rotate the finished house in Studio, never in the build.

## 4. One roof function drives the whole house

The cabin's most reusable lesson: **derive every dependent part from the same function that places the roof**, never from typed heights. `lh.Gable(hx, eave_z, pitch)` gives the roof underside `under(x) = eave_z + (hx - |x|) * tan(pitch)`. Then:

- gable courses (logs or blocks) shorten with `half_width_at(z_top)`, so their ends stay tucked under the roof boards whatever the pitch;
- the roof slab, rows, ridge cap and snow are all offsets of `under(x)`;
- the chimney starts below `under(x)` at its far edge, so it never floats above a roof that was re-pitched;
- icicles hang from `roof["snow_under"](x)`, just inside the snow lip.

For **block walls**, build the Gable on the **outer** face line (`Gable(hx + t/2, ...)`). On the centre line, the eave walls' outer top edge sits t/2 x tan(pitch) above the roof underside (0.6 studs for the cottage) and can poke through a thin roof.

**Seat from geometry, then scan.** The cabin's per-module gate passed while icicles, firewood, a door knob and a lantern bracket floated inside their own modules. The gate checks seating *between* modules, not between the 282 shells inside them (**Measured**). `lh.floating_shells(modules, base_names)` joins every module and links touching shells (BVH overlap or a 0.02-stud gap). It then floods outward from the base and the ground. Anything it does not reach is floating. It must report 0, and a deliberately floating test box was caught (**Measured**).

## 5. Silhouette, roof and colour rules

**Silhouette.** At 64 px the roof is the house. Make it 40-50% of the side view, with real overhangs: eaves 1.4-1.9 studs past the wall line and gables 1.2-1.65 (**Measured** on both builds). A chunky edge (0.9 thick, or 0.5 plus rows) reads at distance, and a thin roof reads as paper. Break symmetry with one addition: an off-centre chimney, a lean-to porch, a dormer or a side door. Check `_silhouette.png` before any detail.

**Variation that reads as built.** Identical logs or stones read as a texture. Vary each piece slightly from a seed: radius -4 to +3%, overhang +-0.12, colour +-4% (**Measured** cabin values). Stagger block joints half a block on alternate courses.

**Colour discipline.** Use three hue families plus one accent: structure (logs, stone), roof (slate, shingle, thatch) and trim (cream frames, teal or green shutters). The accent is the window glow. Keep a clear value step between roof and walls. Colour by normal where weather sits: tops get snow or moss, sides a shadow tone, undersides a darker tone. That fakes ambient occlusion in the vertex colours. Render previews with the Standard view transform so you see the hexes Roblox will show ([[Flat Colour vs Gradient Atlas vs Vertex Colour]]).

**Gradients are a style decision.** The cabin's centre-to-rim end grain on log caps was marked down by a blind reviewer as "gradients on flat faces" (V5). If the style bible says flat colour, use two flat rings instead.

## 6. Triangle budgets per module

Count the triangles **after the bevel** (on the evaluated mesh). A soft 1-segment bevel turns a 12-triangle box into about 44.

| Module | Class (`lf.BUDGETS`) | Cabin (**Measured**) | Cottage test (**Measured**) |
|---|---|---:|---:|
| Walls | building (6,000 / 10,000) | 4,960 logs | 9,152 stone blocks |
| Roof | medium or building | 1,572 with snow and icicles | 1,080 rows and ridge |
| Chimney | medium | 704 | 748 |
| Trim | medium (2,000 / 4,000) | 2,052 | 2,200 |
| Glow | small | 60 | 60 |
| Door / porch | medium | 3,310 (porch with firewood) | 548 (door and steps) |
| Whole house | | about 13,400 in 8 modules | about 13,800 in 7 modules |

Block walls go over budget fastest. The cottage's first walls were 10,956 triangles, over the 10,000 ceiling (gate A1). Courses of 1.45 instead of 1.3 and blocks 2.8-4.4 long instead of 2.4-3.8 brought them to 9,152 (**Measured**). Estimate first: blocks per course x courses x 44. For a village, also use 8-sided logs (about a fifth fewer wall triangles), merge the deck planks into one slab and turn the firewood into one block.

## 7. Interior-ready openings

The cabin's windows were overlays on solid logs. That is fine for a background prop but blocks interiors later. Build real openings from the start:

- **Plan before modelling.** `lh.opening_footprint(w, frame, shutters)` gives the real half-width of a window (frame and shutters included). `lh.check_wall_layout(face_len, items)` rejects footprints that pass the corners or leave less than 0.6 studs of wall between them. The cottage's first layout pushed a shutter 0.7 studs past the corner (**Measured**). Put shutters on the long walls, where there is room.
- **Cut, don't cover.** Pass `openings={face: [(u0, u1, z0, z1)]}`. Logs split at the opening with end grain on the cut ends. Block courses split, and the course above gets one lintel block.
- **Snap to the courses.** `coursed_walls` snaps opening tops and bottoms to course lines (`snap_openings`) and returns the snapped values. Build the windows and doors from those returned values, not from your typed numbers.
- **Recess the glass** about half the wall thickness (`recess=t/2`), so the opening shows depth from outside and leaves a sill inside.
- **Interior floor** = foundation top. The door threshold sits on it and the steps run down from it (`lh.steps`: each step is a solid block to the ground, with no floating treads).

## 8. Gate failures, generalised

| What failed | Where (**Measured**) | Rule for every house |
|---|---|---|
| A4 n-gons after `finish("soft")` | Cabin: bevelled fan caps and box corners | Add Triangulate with `min_vertices = 5` and `keep_custom_normals` straight after the bevel. `lh.finish_modules` does this |
| Floating shells inside a module | Cabin: icicles, firewood, knob, bracket | Seat from geometry, then run `lh.floating_shells` (0 required) |
| A1 over the class ceiling | Cottage walls 10,956 > 10,000 | Estimate block counts first, and use longer blocks and taller courses |
| A5 degenerate faces | Log test: 0.12-thick shutter battens under a 0.06 bevel gave 16 degenerate faces | Keep the bevel width at most 1/3 of the thinnest part |
| Dark squares at corners | Cottage: mortar core strips stuck out past the quoins | Stop core ends gap/2 + 0.03 behind the end blocks |
| Shutter past the corner | Cottage front wall | `check_wall_layout` before modelling |

## 9. Style-swap table

The method stays the same, and each module changes per style. The cabin and cottage columns were built (**Measured**). Medieval, modern and fantasy are rules of thumb: `lh` does not build timber frames, flat roofs or curved walls yet. Use `MeshBuilder.box` and `obox` for them.

| Module | Log cabin | Stone cottage | Medieval (timber frame) | Modern | Fantasy |
|---|---|---|---|---|---|
| Foundation | Thin sill log, or stone piers | Stone plinth 0.6, 0.35 margin | Rubble plinth 1-1.5, or a whole stone ground floor | Thin slab 0.3-0.5, flush and crisp | Rock or root base, oversized |
| Walls | `log_walls` r 0.6, 10-11 courses | `coursed_walls` stone 1.2 thick, courses 1.45 | Posts, beams and diagonal braces 0.6-0.8 thick, light plaster panels; upper floor jettied out 0.8-1.2 | Flat panels 0.8-1, large glazed areas | Leaning or tapered walls, exaggerated thickness |
| Corners | Log ends crossing, 1.05 overhang | Quoins, long and short alternating, proud 0.08 | Corner posts 1 x 1, darker than the panels | Sharp, bevel 0.02-0.03 or none | Chunky pillars, rounded |
| Roof | Slab 50 degrees, thick snow with a lip | Slate rows 45 degrees, ridge cap | Steep rows 55-60 degrees, tall, dormers | Flat or mono-pitch 5-15 degrees, parapet | Very steep or curved, witch-hat or mushroom cap |
| Roof trim | Plain board edge | Ridge cap prism | Bargeboards and ridge tiles | Thin parapet coping | Finials, curled eaves |
| Chimney | Brick stack, off-centre, with a snow cap | Brick or stone on the gable end | Tall stone stacks, often two | None, or a slim vent box | Crooked stack, smoke as a feature |
| Windows | 2.8 x 3.4, cross mullions, teal shutters, snow caps | 1.8-2.6, frames recessed half the wall, shutters on the long walls | Small and deep, leaded panes, heavy sills | Wide strips or floor-height glass, thin black frames | Round or odd shapes, glowing |
| Door | Plank door 3.6 x 7.5 on a porch | Plank door 3.6 x 7.5, stone lintel, 2 steps | Arched heavy door 4-4.5 x 8.5 | Slab or glass door 3.6-4 x 8 | Round or oversized door |
| Porch | Lean-to deck with posts and rails | Steps only | Stone stair or overhanging upper floor | Cantilevered slab steps, deck | Winding steps, bridges |
| Palette | Warm browns, cream, teal accent, orange glow | Grey stones, cream quoins, slate blue, green shutters | Ochre plaster, dark timber, red-brown tile | White and grey, a wood accent, black frames | One saturated accent hue plus glow |
| Budget | About 13.4k in 8 modules | About 13.8k in 7 modules | Split per storey: about 8-10k per floor | Low, 4-8k | Depends on curves; watch the sweeps |

## 10. Pipeline

```python
import random, lihfolk_bpy as lf, lihfolk_house as lh
rng = random.Random(11); lf.setup_scene()
walls = lh.MeshBuilder("House_Walls", rng)
gable = lh.Gable(hx + t / 2, eave_z, 45)                         # one roof function
faces, ops, ch = lh.coursed_walls(walls, hx, hy, thickness=t, z0=plinth, eave_z=eave_z,
                                  gable=gable, openings=openings, colours=STONE, mortar=MORTAR, quoin=QUOIN)
roof = lh.MeshBuilder("House_Roof", rng)
R = lh.gable_roof(roof, gable, hy + t / 2, style="rows", rows=dict(colours=SLATE), ridge=dict(colour=RIDGE), colour=SLATE[0])
# ... chimney, window(trim, glow, faces[key], ...), door, steps, foundation
mods = [b.to_object() for b in (base, walls, roof, chim, trim, glow, door)]
lh.recentre(mods)
lh.finish_modules(mods, FINISH, glow=("House_Glow",))
gates = lh.gate_modules(mods, CLASSES)            # every module must pass
scan = lh.floating_shells(mods, base_names=("House_Foundation",))   # floating must be 0
lh.render_preview(mods, out + "/preview.png"); lh.export_modules(mods, out, combined="House_All")
```

Then do the visual review: `lf.render_review` close-ups of a window, a corner, the chimney, the door and the eaves. Small seating and shading mistakes only show in close-ups. Score with the model rubric, using a 3-reviewer blind panel for pass or fail. A house below 8.5 is a draft and does not go into the asset pack.

## 11. LOD, collision and Studio import

- **LOD:** do not hand-author LODs for a house-sized model. Roblox reduces meshes automatically. For a whole village, use the model-level options in [[Level of Detail and Model Streaming]].
- **Collision:** a Box or Hull collider fills door openings, so the player cannot walk in. For walls with real openings, turn collision off on the wall mesh and add invisible, anchored box Parts for each wall run between openings. That is exact and cheap. Otherwise use PreciseConvexDecomposition on the walls only. Give the roof Hull if players can land on it. Turn CanCollide, CanTouch and CanQuery off on trim, glow, smoke and props ([[Collision and Physics Geometry]]).
- **Import:** import the combined GLB, keep the modules in one Model, set MeshPart.Color to white (vertex colours), Anchored on, SmoothPlastic. Give the glow module Neon, and add real lights (a [[SurfaceLight]] per window, or one PointLight inside) if the light should spill onto snow or ground. Emission does not light the world.
- **Grounding:** because the pivot is the bottom centre, a raycast puts the house on terrain. Place it at the lowest corner and sink it slightly. On a slope, the plinth must be at least as tall as the height difference, or terrain climbs the uphill walls.

```lua
--!strict
-- Ground a house Model whose pivot is its bottom centre. Returns the terrain height difference under the
-- footprint (compare it with the plinth height), or nil if no ground was hit.
local Workspace = game:GetService("Workspace")

local function groundHouse(house: Model, sink: number): number?
	local pivot = house:GetPivot()
	local size = house:GetExtentsSize()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { house }
	local lowest: number? = nil
	local highest: number? = nil
	for _, f in { Vector2.new(-0.5, -0.5), Vector2.new(0.5, -0.5), Vector2.new(-0.5, 0.5), Vector2.new(0.5, 0.5), Vector2.zero } do
		local origin = pivot:PointToWorldSpace(Vector3.new(f.X * size.X, 200, f.Y * size.Z))
		local hit = Workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
		if hit then
			local y = hit.Position.Y
			lowest = if lowest then math.min(lowest, y) else y
			highest = if highest then math.max(highest, y) else y
		end
	end
	if lowest == nil or highest == nil then
		return nil
	end
	house:PivotTo(pivot + Vector3.new(0, lowest - sink - pivot.Position.Y, 0))
	return highest - lowest
end

return groundHouse
```

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Heights typed by hand for gable courses, chimney and icicles | Ends poke through the roof, gaps open, icicles float when the pitch changes | One `Gable` function; derive every height from it |
| One origin per module | Modules do not line up on import | Shared bottom-centre origin for every module (`lh.recentre`) |
| Trusting the per-module gate for small parts | Floating icicles, knobs and firewood ship | `lh.floating_shells` on the whole house, 0 required |
| Bevel without triangulating | Gate A4 n-gons | Triangulate (min 5 vertices) right after the bevel |
| Windows overlaid on solid walls | No interior possible later | Real openings, snapped to courses, glass recessed |
| Openings planned by eye | Shutters past corners, slivers of wall | `check_wall_layout` before modelling |
| Bevel wider than thin parts | Gate A5 degenerate faces | Bevel at most 1/3 of the thinnest part |
| Block walls built without a count | Gate A1 over the ceiling | Blocks x courses x 44 estimate; longer blocks |
| Box collision on walls with doors | Players cannot enter | Invisible box colliders per wall run, mesh collision off |
| Emission expected to light the scene | Glowing windows, dark ground | Neon on the glow module plus real lights |

## Checklist

- [ ] Brief written: avatar proxies, door 3.6-4 x 7.5-8, storey, wall thickness, pitch, palette, seed
- [ ] Modules split by collision, material, swap and budget; one material each
- [ ] One Gable function drives the courses, roof, chimney and icicles
- [ ] Openings planned with check_wall_layout, cut for real, snapped to courses
- [ ] Shared bottom-centre origin on every module
- [ ] Triangulate after the bevel; every module passes lf.gate
- [ ] Whole-house floating-shell scan reports 0
- [ ] Triangles per module under the class ceiling, counted after the bevel
- [ ] Close-up review renders checked; blind panel score at least 8.5 before the asset pack
- [ ] Studio: colour white, Neon plus lights, box colliders around the openings, grounded on terrain

## See also

[[Stylised Log Cabin Worked Example]] · [[Modular Environment Kits]] · [[Grid Placement and Player Building Systems]] · [[Modeling in Blender for Roblox]] · [[Collision and Physics Geometry]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Stylised Shop Stand Worked Example]] · [[Procedural Model Kits - Lessons]] · [[Mesh Gates for Generated Models - Symmetry, Seating and Caps]] · [[Environment Art Styles]]

<!-- related:start -->
## Related
[[Parts Unions and MeshParts]] · [[Voxel Art - Studs Outlines and Style Kits]] · [[Zone and Biome Art Direction]] · [[Foliage Props and Scatter]] · [[World Composition and Set Dressing - Designed, Not Scattered]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Terrain Tools and Terrain API]] · [[Level Design for Roblox]]
<!-- related:end -->
