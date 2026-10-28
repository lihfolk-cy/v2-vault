---
tags: [gameplay, raycast, spatial-query, overlapparams, shapecast, physics]
---
# Raycasts Shapecasts and Spatial Queries

Spatial queries answer "what is there?" without waiting for physics contact. Hit detection, ground checks, line of sight, aiming, prop placement, AI perception and zone membership all use them. Roblox has two families: **casts** (move a shape along a direction and report the first hit) and **overlaps** (list everything inside a volume right now). Choosing the right one, filtering correctly and knowing the edge cases (parts you start inside, bounding boxes on rotated meshes, terrain) is most of the work.

Source labels: **Docs** (WorldRoot, RaycastParams and OverlapParams references, checked October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. The API at a glance

All methods live on `WorldRoot` (so `workspace` or a `WorldModel`).

| Method | Shape | Returns | Limits (Docs) |
|---|---|---|---|
| `Raycast(origin, direction, params?)` | Line | First `RaycastResult` or nil | Direction length up to 15,000 studs |
| `Blockcast(cframe, size, direction, params?)` | Box | First hit or nil | Size up to 512, distance up to 1,024 |
| `Spherecast(position, radius, direction, params?)` | Sphere | First hit or nil | Radius up to 256, distance up to 1,024 |
| `Shapecast(part, direction, params?, cframeOverride?, sizeOverride?)` | The part's real geometry | First hit or nil | Distance up to 1,024; cannot be a Terrain part |
| `GetPartBoundsInBox(cframe, size, overlapParams?)` | Box vs bounding boxes | `{BasePart}` | |
| `GetPartBoundsInRadius(position, radius, overlapParams?)` | Sphere vs bounding boxes | `{BasePart}` | |
| `GetPartsInPart(part, overlapParams?)` | Exact geometry | `{BasePart}` | |
| `ArePartsTouchingOthers(parts, overlapIgnored?)` | Exact | boolean | |

`RaycastResult` gives `Instance`, `Position`, `Normal`, `Material` and `Distance`.

The old methods (`FindPartOnRay*`, `FindPartsInRegion3*`, `IsRegion3Empty*`) are deprecated (Docs). Old tutorials still use them; port on sight.

### Behaviour you must know (Docs)
- **Casts ignore parts they start inside.** Blockcast, Spherecast and Shapecast "do not detect BaseParts that initially intersect the shape". A sword sweep that begins inside an enemy misses that enemy. Combine a cast with an overlap at the start position when that matters.
- **Shapecast always excludes the part being cast** and is not thread-safe; Raycast, Blockcast, Spherecast and the three overlap methods are safe to call in parallel (Docs tags them "Write Parallel"). See [[Parallel Luau and Actors]].
- **Bounds methods use bounding boxes.** `GetPartBoundsInBox/Radius` "consider the volume of parts' bounding boxes rather than their actual occupied volume", so cylinders, spheres, unions and MeshParts may be reported when they do not really overlap. `GetPartsInPart` does a full geometric check and is slower.
- **Concave parts.** `GetPartsInPart` with a hollow part does not match things inside the hollow unless they touch the actual surface (Docs).
- **Terrain.** Raycast, Blockcast and Spherecast hit terrain cells. Water is hit unless `IgnoreWater` is true.

---

## 2. Filtering: RaycastParams and OverlapParams

### Current properties (Docs, October 2026)

| Property | RaycastParams | OverlapParams | Meaning |
|---|---|---|---|
| `ExcludeInstances` | yes | yes | These instances and descendants are skipped |
| `IncludeInstances` | yes | yes | Only these and descendants; `nil` = everything, `{}` = nothing |
| `CollisionGroup` | yes | yes | Skip parts whose group does not collide with this group; default `Default` |
| `RespectCanCollide` | yes | yes | Use `CanCollide` instead of `CanQuery` to decide inclusion |
| `BruteForceAllSlow` | yes | yes | Check everything regardless of flags; slow, not for live games |
| `IgnoreWater` | yes | | Ignore terrain water |
| `Margin` | yes | | Grow the cast shape in all directions (default 0); non-zero makes a Raycast act like a sphere cast |
| `SizeGradient` | yes | | Scale the cast shape along its length (default 0; ends at `1 + SizeGradient` times size) |
| `MaxParts` | | yes | Cap results; 0 = no limit |
| `Tolerance` | | yes | Slightly enlarge the query volume, 0 to 0.05 studs |
| `FilterDescendantsInstances`, `FilterType`, `AddToFilter` | yes | yes | Older filter API, documented as superseded by Exclude/Include |

Exclusion beats inclusion when an instance appears in both. Existing code using `FilterDescendantsInstances` with `Enum.RaycastFilterType.Exclude/Include` still works; new code should use the clearer pair. If you ship to an older Studio version or rely on plugins that read the old properties, check both exist before switching.

### Inclusion rules
A part is a candidate only if:
- its `CanQuery` is true, which only matters when `CanCollide` is false (Docs: "CanCollide must be disabled for CanQuery to take effect"), or `RespectCanCollide` is set and it has `CanCollide` true;
- its collision group collides with the params' group;
- it passes the include/exclude lists.

So: **colliding parts are always queryable.** An invisible wall that blocks players will also block your line-of-sight checks unless you filter it out (exclude list or a collision group on the query).

### Build params once
Creating params is cheap but not free, and rebuilding filter arrays every frame allocates. Keep a params object per purpose and update the arrays when the world changes:

```lua
--!strict
local CollectionService = game:GetService("CollectionService")

local Queries = {}

-- Ground: world geometry tagged as floor plus terrain.
local groundParams = RaycastParams.new()
groundParams.IgnoreWater = true

local function refreshGround()
	local list: { Instance } = { workspace.Terrain }
	for _, inst in CollectionService:GetTagged("Floor") do
		table.insert(list, inst)
	end
	groundParams.IncludeInstances = list
end
refreshGround()
CollectionService:GetInstanceAddedSignal("Floor"):Connect(refreshGround)
CollectionService:GetInstanceRemovedSignal("Floor"):Connect(refreshGround)

function Queries.groundBelow(pos: Vector3, depth: number): RaycastResult?
	return workspace:Raycast(pos, Vector3.new(0, -depth, 0), groundParams)
end

return Queries
```

**Measured.** The reference project's enemy floor check uses exactly this shape: an include list of `*Ground` slabs plus parts tagged `EnemyFloor` and terrain. When new floors were added (neon streets, an arena), forgetting the tag made enemies sink or float on them. A tag is a contract: put "tag new floors" in the level checklist.

---

## 3. Patterns

### Ground snap for props
Placing props on uneven ground: cast down from above and set the prop's bottom to the hit. Use a **terrain-only** include list if props sit on terrain. **Measured:** an exclude-list cast landed props on tree trunks and rocks instead of the ground in the reference project; switching to terrain-only fixed it. Then test for overlaps with `GetPartsInPart` rather than the bounds methods, because big mesh bounding boxes over-reported overlaps (measured). In one pass, 276 floating props were snapped down, with the amount stored in an attribute so the change was reversible.

### Line of sight

```lua
--!strict
local function hasLineOfSight(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.ExcludeInstances = ignore
	params.IgnoreWater = true
	local hit = workspace:Raycast(from, to - from, params)
	return hit == nil
end
```

Pass both characters in `ignore`. For fat targets cast to two or three points (head, chest, feet) and accept any clear one; a single ray to the root fails when the target's centre is behind a low wall but its head is visible.

### Piercing ray (collect several hits)
A ray stops at the first hit. To pierce, cast again from just past the hit with that instance excluded:

```lua
--!strict
local function pierce(origin: Vector3, direction: Vector3, maxHits: number, ignore: { Instance }): { RaycastResult }
	local params = RaycastParams.new()
	local excluded = table.clone(ignore)
	params.ExcludeInstances = excluded
	local results = {}
	local remaining = direction
	local start = origin
	for _ = 1, maxHits do
		local hit = workspace:Raycast(start, remaining, params)
		if not hit then break end
		table.insert(results, hit)
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		table.insert(excluded, model or hit.Instance)
		params.ExcludeInstances = excluded -- reassign: the params hold a copy
		local travelled = hit.Position - start
		remaining -= travelled
		start = hit.Position
		if remaining.Magnitude < 0.05 then break end
	end
	return results
end
```

Reassign the array after changing it; params copy the list when you set it (the same rule applied to `FilterDescendantsInstances`).

### Swept projectiles
A fast projectile moving 200 studs/s at 60 FPS covers 3.3 studs per frame and passes through thin targets if you only check its position. Each step, cast from the last position to the new one (a Spherecast with the projectile radius). This is how most projectile modules work, and it lets the server simulate projectiles without parts at all. See [[Hitboxes and Hit Detection]].

### Area of effect
For "everything within 12 studs", use `GetPartBoundsInRadius` with an include list of enemy models (or a collision group), then **deduplicate by model** (one enemy has many parts) and run an exact check (distance to the enemy root, or line of sight) on the shortlist. Bounds first, exact second is the standard broad-phase/narrow-phase split.

```lua
--!strict
local function enemiesInRadius(center: Vector3, radius: number, enemyFolder: Folder): { Model }
	local params = OverlapParams.new()
	params.IncludeInstances = { enemyFolder }
	local seen: { [Model]: boolean } = {}
	local out: { Model } = {}
	for _, part in workspace:GetPartBoundsInRadius(center, radius, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and model.Parent ~= enemyFolder do
			model = model:FindFirstAncestorOfClass("Model")
		end
		if model and not seen[model] then
			seen[model] = true
			local root = model.PrimaryPart
			if root and (root.Position - center).Magnitude <= radius + root.Size.Magnitude * 0.5 then
				table.insert(out, model)
			end
		end
	end
	return out
end
```

### Avoid queries entirely when maths will do
If every enemy is already in a table, "who is within 12 studs" is a loop over that table with a distance check, no physics query at all. For a few hundred entities this is faster than any spatial query and has no filtering pitfalls. The reference project's ability targeting works on its own list of combat bodies (radius plus body size plus a small lead capsule for moving casters), not on part overlaps.

---

## 4. Performance

- Raycasts are cheap: thousands per frame are fine on the server if filtered well. Shapecasts and `GetPartsInPart` are more expensive; overlaps that return hundreds of parts cost mostly in building the result array.
- Include lists are faster than exclude lists for narrow purposes (ground, enemies), because the engine skips everything else.
- Caching beats querying. **Measured:** the reference project's server spent noticeable time on ground raycasts for enemies. It added a cached 2-stud height grid (two 4-second generations, exact raycast fallback when the cell is ambiguous: terrain miss, height span over 2 studs, or parts near the cell floor). Maximum error 0.233 studs, and the exact path stays for edge cases. See [[Script Performance]].
- Spread work across frames. A brain that casts for every enemy every frame can usually cast at 10 Hz with no visible difference.
- `MaxParts` stops runaway results from overlaps in dense areas.

---

## 5. Debugging queries

- Draw them. Spawn a thin neon part along each ray for one second (client only, in a debug mode) or use `Adornment`s. Most "the ray misses" bugs are wrong direction length (passing a unit vector: a 1-stud ray) or the wrong origin.
- Print what was hit, with its full name. Most "the ray hits nothing" bugs are a filter excluding the target's parent folder, or `CanQuery` false on a non-colliding hitbox.
- Check `CanQuery` on hitbox parts: a non-colliding hitbox with `CanQuery = false` is invisible to every query.
- Remember casts skip starting overlaps; test from a clear origin.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Unit direction vector | 1-stud rays | `direction.Unit * distance` |
| Bounds query on big meshes | False overlaps | `GetPartsInPart` for exactness |
| Exclude-list ground cast | Props on rocks and trunks | Include terrain/floor only |
| Mutating the filter array in place | Filter unchanged | Reassign the property |
| Cast starting inside target | Target missed | Overlap at start + cast |
| Not deduplicating models | Damage applied 15 times | Set of models |
| Invisible walls block LOS | Enemies "can't see" through glass panes | Collision group or exclude for LOS |
| Using Shapecast in parallel | Errors | Raycast/Blockcast/Spherecast there |

## Checklist
- [ ] One params object per query purpose, updated on world change.
- [ ] New code uses `ExcludeInstances`/`IncludeInstances`.
- [ ] Broad phase (bounds) then narrow phase (exact or distance).
- [ ] Hitbox parts have `CanQuery` true and are in the expected group.
- [ ] Ground and floor tags documented in the level checklist.

## See also
[[Hitboxes and Hit Detection]] · [[Physics Assemblies and Constraints]] · [[Pathfinding]] · [[NPC AI and Behaviour]] · [[Foot Placement and Ground IK]] · [[Instances Attributes and Tags]] · [[Script Performance]] · [[Parallel Luau and Actors]]

## Connected notes
<!-- auto-links:start -->
[[Intersection and Collision Math]] · [[Links - Raycasting and spatial queries]] · [[Collision and Physics Geometry]] · [[Projectiles and Ballistics]] · [[Physics Performance]] · [[MCP Workflows for Building Worlds]]
<!-- auto-links:end -->
