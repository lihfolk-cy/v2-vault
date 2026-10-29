---
tags: [pipelines, environment, level-design, terrain, manifests, map, type/guide, area/pipelines, level/intermediate, api/Terrain, area/design, api/Atmosphere]
---
# Environment and Level Pipeline

<!-- tldr:start -->
> [!tldr] TL;DR
> - Resize means rebuild: hand-placed macro layout -> layout formulas
> - Restyle means re-placing every prop: no placement manifest -> export manifest, re-seat
> - Players stuck at gates: art colliders, no walk test -> collision layer first, walk-box gate
> - Layers separated: layout, collision, terrain, kit, props, markers, FX
> - Macro layout in formulas or a table
> - Collision built first; art non-colliding
>
> Cost: TL;DR ~140 tok · whole note ~4.0k tok. Read more: ## Stage 2: collision first, art second · ## Stage 3: terrain by script, with snapshots · ## Failure modes · ## Checklist
<!-- tldr:end -->

Levels are where pipelines and hand craft meet. A zone needs a designer's eye (sight lines, pacing, where the fight happens), but it also needs hundreds of props placed consistently, terrain that matches the meshes, colliders players can trust, and the ability to restyle or resize the whole thing later without starting over. This note is a recipe for building zones that can be rebuilt. Level design theory is in [[Level Design for Roblox]], kits in [[Modular Environment Kits]], terrain tools in [[Terrain Tools and Terrain API]], streaming in [[Level of Detail and Model Streaming]] and [[Instance Streaming]].

## The layers of a level

Treat a level as layers with different owners and different pipelines. Mixing them in one folder is the root of most map bugs.

| Layer | Contents | Source of truth | Who edits | Pipeline |
|---|---|---|---|---|
| **Layout** | zone bounds, floor heights, gate positions, spawn points | a layout table (code or JSON) | designer | formulas, then generated |
| **Collision** | invisible floors, walls, ramps, kill planes | generated from layout | tool | install script |
| **Terrain** | voxel ground, cliffs, paths | layout + painted detail | tool + artist | scripted writes, snapshots |
| **Kit geometry** | walls, cliffs, gates as meshes | Blender scripts | artist | [[Art Pipeline - Concept to In-Game Asset]] |
| **Props** | trees, rocks, crates, lamps | a placement manifest | artist / tool | manifest install |
| **Gameplay markers** | enemy spawns, walk boxes, prompts, triggers | data module | designer | config |
| **FX and audio** | ambient emitters, beds, lights | per-zone config | VFX / audio | [[Audio Pipeline]] |

The reference project kept these as separate folders per zone (`Terrain`, `Collision`, `Bounds`, `Props`, plus gameplay folders elsewhere) and that separation is what let it later restyle a whole realm's art without touching collision, gates or spawns (measured in one production game).

## Stage 1: layout as formulas

Put the macro layout in a table or formula, not in hand-placed parts. One production game laid out a ten-zone volcano climb like this:

```text
zone k (11..20):
  x origin   = 8900 + (k - 11) * 624     (studs)
  floor y    = 20 + (k - 11) * 38
  gate k     = at the zone's west edge
  arena      = zone 20 summit, centre measured
```

Everything else (gate frames, ramps, spawn points, the enemy walk box) is derived from those numbers. When the owner later asked to "make zones 60% smaller, players run too long", the first realm was squashed along x with one formula (`x' = anchor + 0.4 * (x - anchor)`), and every dependent position could be recomputed. The pass moved 4,643 units (models moved rigidly by their bounding-box centre, small folders rigidly, long loose parts remapped end to end), resampled terrain west to east in 18 writes with a read-back after each, and cut terrain cells from 1,941,500 to 1,040,414 (measured in one production game). Without formula layout that change would have been a rebuild.

**Nuance:** formulas are for the macro grid. Inside a zone, hand placement wins; just record it (stage 4).

## Stage 2: collision first, art second

Build the walkable surfaces and walls as plain invisible parts before any art. They are cheap, predictable and testable. Art meshes then sit on top with `CanCollide = false` (or keep collision only where a mesh is the floor and simple).

Rules that came out of real failures:

- **Gates must be walkable.** In one realm, gates 12 to 20 were blocked because each gate frame sat on top of the previous zone's ramp and its step colliders stood about 20 studs above the ramp surface at one end. The fix lowered every gate frame and re-cut the ramps, and the lesson was a gate: a **walk box test** that drops a test box on the floor at each zone's entry and exit and reports whether it can pass.
- **Hide what players should not see yet.** Shadow shells over locked zones and `GapFill` meshes beside gates stopped players seeing the next zone through the gap (0 sight-line leaks was the gate).
- **Keep queries off decor.** Paths and thin decor had `CanQuery = false` so raycasts for footsteps, enemy ground checks and camera did not hit them.
- **Tag the real floors.** Enemy navigation and ground checks looked for parts tagged as enemy floor; new floors that were not tagged produced enemies falling through. Tag at install, always.

```lua
--!strict
-- Walk-box verification: can a player-sized box stand at each probe point?
-- Run in Edit after any layout or collision change. Prints failures, changes nothing.
local PROBE_SIZE = Vector3.new(4, 9, 4) -- player footprint at this game's character scale
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function check(probes: { { name: string, pos: Vector3 } }, collision: Folder): number
	rayParams.FilterDescendantsInstances = { collision, workspace.Terrain }
	local fails = 0
	for _, p in probes do
		local hit = workspace:Raycast(p.pos + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), rayParams)
		if not hit then
			warn("no floor under", p.name)
			fails += 1
			continue
		end
		local centre = hit.Position + Vector3.new(0, PROBE_SIZE.Y / 2 + 0.1, 0)
		local blockers = workspace:GetPartBoundsInBox(CFrame.new(centre), PROBE_SIZE, params)
		local solid = 0
		for _, b in blockers do
			if b.CanCollide then solid += 1 end
		end
		if solid > 0 then
			warn(p.name, "blocked by", solid, "colliding parts")
			fails += 1
		end
	end
	print(("walk boxes: %d probes, %d fails"):format(#probes, fails))
	return fails
end

return check
```

## Stage 3: terrain by script, with snapshots

Terrain is the riskiest layer: edits are large, slow, and Studio undo is shared in team sessions. The reference project's rules (measured in one production game):

- **Snapshot before any terrain write.** `Terrain:CopyRegion(region)` returns a `TerrainRegion`; store it in ServerStorage (or save to disk as `.rbxm`). Restore with `Terrain:PasteRegion`. Never rely on undo; one undo in a shared place rolled back about 40 waypoints of other people's work.
- **Never regenerate a whole area without sign-off.** Scripted terrain generators are great for first passes and terrible for areas someone has hand-painted since.
- **Do not fill large areas with terrain water.** A 5,000 x 1,900 stud sea stalled players while joining. Fake large water with a flat part and a texture; keep terrain water for small pools.
- **Know the offset.** Terrain renders its surface about 2 studs above the voxel occupancy top in that place; align meshes to the rendered surface, not the voxel math.
- **Write in slices.** Big `WriteVoxels` or `FillBlock` jobs run in chunks under the Studio call budget, with a read-back after each to confirm.
- **One colour per floor** when the art style needs clean reads; the project painted each zone's floor one solid material colour and used flat walk boxes.

```lua
--!strict
-- Snapshot and restore a terrain box. Keep the snapshot until the change is verified.
local Terrain = workspace.Terrain
local ServerStorage = game:GetService("ServerStorage")

local function snapshot(name: string, min: Vector3, max: Vector3): TerrainRegion
	local region = Region3int16.new(
		Vector3int16.new(math.floor(min.X / 4), math.floor(min.Y / 4), math.floor(min.Z / 4)),
		Vector3int16.new(math.ceil(max.X / 4), math.ceil(max.Y / 4), math.ceil(max.Z / 4))
	) -- CopyRegion takes voxel coordinates (4-stud cells)
	local copy = Terrain:CopyRegion(region)
	copy.Name = name
	copy:SetAttribute("Corner", Vector3.new(region.Min.X, region.Min.Y, region.Min.Z))
	copy.Parent = ServerStorage
	return copy
end

local function restore(copy: TerrainRegion)
	local c = copy:GetAttribute("Corner") :: Vector3
	Terrain:PasteRegion(copy, Vector3int16.new(c.X, c.Y, c.Z), true) -- true = paste empty cells too
end

return { snapshot = snapshot, restore = restore }
```

## Stage 4: props by manifest

Props are where levels get their richness, and where hand placement creates debt: a restyle means re-placing hundreds of objects by hand. The fix is a **placement manifest**: a JSON or module listing each prop's kit id, CFrame, scale and any per-instance attributes, in a stable order.

```json
{
  "zone": "zone12",
  "kit": "R2Kit12",
  "props": [
    { "i": 1, "kit": "BasaltPillar_A", "cf": [8930.0, 62.0, 40.0, 0, 0, 0], "s": 1.15 },
    { "i": 2, "kit": "LavaCrack_Flat", "cf": [8952.5, 58.1, -12.0, 0, 35, 0], "s": 1.0 }
  ]
}
```

The pipeline:

1. **Export** the current placement from Studio to a manifest (a small exporter walks the zone's Props folder and writes kit name, pivot, scale).
2. **Rebuild the kit** in Blender with the new style (same kit names).
3. **Re-seat** the manifest with the new kit: same index order, same positions, new meshes. Index order matters: it keeps per-prop attributes and any scripts that refer to "the third pillar" stable.
4. **Verify** with the walk boxes (stage 2) and a sight-line check.

The reference project restyled ten zones this way in a day: the new art framework (`zone_std.py` for shared terrace fronts and ledge heights so zones met without seams, `props_lib.py`, `place.py` to re-seat the live layout from the manifests) reused the existing voxel colliders, and **kept restore data** (the old terrain packages and voxel prop ids) so each zone could be reverted with one call. Collision, bounds, level folders, gates, spawns and the arena were untouched (measured in one production game).

## Stage 5: kit geometry and the hidden costs

Walls, cliffs and big rocks are kit meshes built in Blender ([[Modular Environment Kits]]). Two environment-specific traps:

- **Baked vertex colours.** Wall meshes once carried 400 to 900 noisy orange and tan vertex shades per mesh. Vertex colour multiplies with `Color`, and the meshes had no UVs, so no Material or Color change could fix the streaks. They were rebuilt in background Blender with white vertex colours and world box-projected UVs (10 studs per tile), split into grass and rock meshes. If a surface "won't take" a colour, check vertex colours first.
- **Instance counts.** Every prop is instances (part, mesh, maybe attachments, emitters). A cozy decoration pass in that project added 374 instances; fine. A pass that adds 30,000 is a performance problem on phones. Budget instances per zone ([[Art Budgets - Triangles Draw Calls Memory]]) and prefer fewer, merged meshes for static scenery.

Conventions applied to every scenery install: anchored, `CanTouch = false`, tiny parts no shadows, `RenderFidelity = Automatic`, decor lights tagged so a performance pass can disable rather than delete them.

## Stage 6: gameplay markers as data

Spawn points, enemy walk boxes (centre and half size), prompt positions and trigger volumes belong in a data module keyed by zone, not as loose parts with magic names. Data can be diffed, validated (is every spawn inside its walk box? is every walk box clear of wall geometry?) and moved with the layout formula. The reference project's open items included "enemy walk boxes overlap gate-shoulder rock in two zones": exactly the kind of check a validator catches.

## Stage 7: zone dressing passes, named and numbered

Over time a map accumulates passes: scenery, polish, lamps, flowers, revamp. The reference project numbered its top-level map folders by pass (`05_Levels`, `51_CanyonWalls`, `62_Flowers`, `74_SceneryPass`, `82_GrovePolish`...). Numbered, named folders answer "which pass added this?" in Explorer, make a pass easy to hide for comparison, and give the changelog something to point at. Add an attribute with the pass tag and date to each folder as well.

The weakness it exposed: several numbered folders were created by other sessions and never documented. A pass without a changelog entry is clutter waiting to be deleted by someone who does not know it matters. Record every pass ([[Documentation and Knowledge Bases]]).

## Stage 8: previews that must be switched off

Edit-mode previews of lighting or weather (setting Atmosphere, Lighting or a zone's look to inspect it) are dangerous in a shared place: in the reference project the weather controller read the place's Atmosphere as its base when Play started, so a preview left on changed the live game's air. Every preview script had an `off` mode and the rule was to call it right after captures. Treat any preview that writes to global services as a change that needs a rollback. See [[Lighting Mood and Time of Day]].

## Verification gates for levels

| Gate | Method | Typical failure |
|---|---|---|
| Walkable gates and paths | walk-box probes at entries, exits, ramps | blocked gate, step too high |
| No sight-line leaks | camera rays from gate positions to the next zone | players see unbuilt areas |
| Floors tagged | count untagged collision floors | enemies fall through |
| Terrain alignment | sample terrain surface under mesh edges | floating rocks, holes |
| Instance budget per zone | count descendants per zone folder | phone frame drops |
| Lights budget | count lights per zone, shadows on | GPU cost |
| Markers inside bounds | spawns inside walk boxes, walk boxes clear | enemies stuck in rock |
| Previews off | check global services against saved baseline | live game looks wrong |

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Resize means rebuild | hand-placed macro layout | layout formulas |
| Restyle means re-placing every prop | no placement manifest | export manifest, re-seat |
| Players stuck at gates | art colliders, no walk test | collision layer first, walk-box gate |
| Join stalls | huge terrain water or terrain volume | fake water, trim terrain |
| Lost terrain work | undo or regenerate in a shared place | snapshot regions first |
| Colours will not change | baked vertex colours | rebuild with white vertex colours and UVs |
| Mystery folders | undocumented passes | numbered pass folders and changelog |

## Checklist

- [ ] Layers separated: layout, collision, terrain, kit, props, markers, FX
- [ ] Macro layout in formulas or a table
- [ ] Collision built first; art non-colliding
- [ ] Walk-box and sight-line checks after every change
- [ ] Terrain snapshot before writes; writes sliced with read-back
- [ ] Props placed from a manifest with stable index order
- [ ] Restore data kept until the pass is verified
- [ ] Floors tagged; decor `CanQuery` off where appropriate
- [ ] Pass folders numbered, tagged and in the changelog
- [ ] Global previews switched off after captures

## See also

[[Level Design for Roblox]] · [[Terrain Tools and Terrain API]] · [[Procedural World Generation]] · [[Foliage Props and Scatter]] · [[Collision and Physics Geometry]] · [[Water Sky and Atmosphere Art]] · [[Art Pipeline - Concept to In-Game Asset]] · [[Batch Processing Tools in Studio]] · [[MCP Workflows for Building Worlds]] · [[Pipeline Design Principles]]

## Connected notes
<!-- auto-links:start -->
[[Asset Pipelines]] · Voxel Props Environments and Modular Tiles · Zone and Biome Art Direction · [[Character and Creature Pipeline]] · Voxel Modelling Start Here · Parts Unions and MeshParts
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Blender Automation with Python]] · [[UI Asset Pipeline]] · [[Asset Upload Automation with Open Cloud]] · [[Icon and Thumbnail Rendering Pipeline]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Build Test and Release Pipeline]] · [[Live Content Pipeline]] · [[Code Pipeline - Rojo Git and CI]]
<!-- related:end -->
