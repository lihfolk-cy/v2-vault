---
tags: [world-building, collision, physics, collisionfidelity, colliders, collision-groups, type/guide, area/world, level/intermediate, api/CollectionService, area/physics, api/Touched]
---
# Collision and Physics Geometry

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Visual mesh used as floor -> Primitive colliders
> - Avoid: PCD on every mesh -> PCD only where walkable detail matters
> - Avoid: Trying to set CollisionFidelity in game code -> Studio, or CreateMeshPartAsync + ApplyMesh
> - Visual art non-colliding; colliders are simple invisible Parts.
> - Decoration CanTouch / CanQuery off.
> - Mesh fidelity: Box for small, Hull for convex, PCD only where needed.
>
> Cost: TL;DR ~140 tok · whole note ~4.7k tok. Read more: ## Mesh CollisionFidelity · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

What players see and what they collide with should be two different problems. Visual geometry is detailed, irregular and full of tiny parts; good collision geometry is simple, smooth, predictable and cheap. This note covers the collision flags every part has, mesh `CollisionFidelity`, the visual/collider split, collision groups, invisible floors for AI, and how to test collision after an art pass. Physics simulation itself (assemblies, constraints, ownership) is in [[Physics Assemblies and Constraints]] and [[Physics Performance]].

## The four flags

| Property | Controls | Default | Set false when |
|---|---|---|---|
| `CanCollide` | Physical collision (characters and parts stop against it) | true | Decoration, canopies, VFX, visual meshes with separate colliders |
| `CanTouch` | `Touched` / `TouchEnded` events (fire even if CanCollide is false) | true | Anything no script listens to; saves work (Roblox docs recommend it) |
| `CanQuery` | Raycasts, shapecasts, overlap queries | true | Decoration that should not block raycasts (paths, foliage, VFX). Only settable to false when CanCollide is false |
| `Anchored` | Not simulated | false | Everything static |

The Roblox docs: for parts that need no collisions, set `CanCollide`, `CanTouch` and `CanQuery` all to false. One production game's decoration convention was anchored, `CanTouch = false`, small parts without shadows; path decals and paving overlays were `CanQuery = false` so they never intercepted ground raycasts.

Mistakes these flags cause:
- **Raycasts hitting decoration.** A grounding ray, a hitbox ray or a camera occlusion ray stops on a flower. Fix with `CanQuery = false` on decoration or an Include-list raycast.
- **Touched firing on decoration**, then scripts doing work for nothing. `CanTouch = false`.
- **Invisible parts still colliding.** `Transparency = 1` does not disable collision; that is a feature for colliders and a bug for leftovers. One project's gate veils were transparent but still collided until fixed.

## Mesh CollisionFidelity

MeshParts and unions choose their collision shape (Roblox docs, lowest to highest fidelity and cost):

| Value | Shape | Use |
|---|---|---|
| `Box` | Bounding box | Small or non-interactive objects; lowest memory. "Setting small anchored parts to Box is generally safe" (docs) |
| `Hull` | One convex hull | Objects without big cavities: rocks, crates, statues |
| `Default` | Approximate, supports concavity | General props with some concavity |
| `PreciseConvexDecomposition` | Many convex pieces, most precise | Walkable complex shapes (arches, stairs in a mesh), "most expensive performance cost and takes longer for the engine to compute" (docs) |

Even PCD is "not a 1:1 representation of the visual" (docs). Turn on the **Collision fidelity** visualisation (Visualization Options in the viewport) to see the real shapes.

### You cannot change it from a normal script

`CollisionFidelity` cannot be set on an already loaded MeshPart from game scripts; collision geometry is computed when the part is created. Options (verified in one production game, which found "CollisionFidelity not script-settable"):
- Set it in Studio's Properties.
- Create the part with `AssetService:CreateMeshPartAsync(content, options)` passing the fidelity, then `ApplyMesh` it onto an existing part to keep children.

```lua
--!strict
local AssetService = game:GetService("AssetService")

-- Give an existing MeshPart precise collision while keeping its children and properties.
-- Run from the command bar or a plugin (Studio), not at runtime per frame.
local function makePrecise(part: MeshPart)
	local source = AssetService:CreateMeshPartAsync(Content.fromUri(part.MeshId), {
		CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
		RenderFidelity = part.RenderFidelity,
	})
	part:ApplyMesh(source) -- copies mesh, collision geometry and fidelity settings
	source:Destroy()
end
```

The project above built its large zone-kit colliders this way (templates stored with PCD in a library) and used PCD only on a few big station, gate, terrace and pylon meshes; everything else in the hub was `CanCollide = false`.

## The visual / collider split

The most robust pattern for detailed art:

1. **Visual meshes:** `CanCollide = false`, `CanQuery = false`, `CanTouch = false`. They can be as detailed as you like.
2. **Colliders:** a small set of invisible, anchored primitive Parts (Blocks, Wedges, Cylinders), `Transparency = 1`, `CastShadow = false`, in a `Colliders` folder or model.

Why it wins:
- **Smooth movement.** A floor that is one Block has no seams to snag on, no tiny step-ups, no jitter.
- **Predictable gameplay.** Designers can see and edit collision by toggling transparency.
- **Art can change freely.** One production game swapped a hub's cliffs from textured meshes to flat parts while the original meshes stayed as invisible colliders; a **1,620-ray grid test came back identical** before and after.
- **Cheaper physics.** Primitive collision is the cheapest there is.

Typical collider sets from that project's hub: the ground as one cylinder, the dais tiers as cylinders, four stair wedges; fountains with a plinth step, 8 rim walls and a basin floor; stations with a few blocks. A rebuilt station kept a `VoxCollide` model of invisible colliders next to its `Voxel` art model.

### Stairs and ramps

Stairs as geometry make characters bob and catch. Use a **wedge collider** over visual stairs so the character glides up, unless the game wants step-by-step movement. Keep visual step heights at about 1 stud so the visual and the ramp agree.

### Walls players should not climb

Characters can jump onto small ledges in rough mesh collision. A smooth, slightly overhanging or tall invisible wall stops wall-climbing exploits. Bounds walls go well beyond the visual edge (see [[Level Design for Roblox]]).

## Floors for AI and gameplay

Visual ground is a poor floor for enemies: terrain bumps, mesh seams and decorative paving confuse ground checks and pathfinding. Patterns from one production game:
- An **invisible, `CanQuery = true` ground part** per area served as the combat floor; enemy grounding raycast against it.
- The enemy grounding code accepted parts carrying a **CollectionService tag** (`EnemyFloor`) as valid ground: plaza pavements, medallions and arena dais stones. Anything untagged was ignored, so decoration never lifted an enemy.
- Enemy areas were boxes stored as attributes on zone folders; colliding props stayed outside them.

```lua
--!strict
-- Ground probe that only accepts Terrain and parts tagged "EnemyFloor".
local CollectionService = game:GetService("CollectionService")

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local function refresh()
	local list: { Instance } = { workspace.Terrain }
	for _, p in CollectionService:GetTagged("EnemyFloor") do
		table.insert(list, p)
	end
	params.FilterDescendantsInstances = list
end
refresh()
CollectionService:GetInstanceAddedSignal("EnemyFloor"):Connect(refresh)
CollectionService:GetInstanceRemovedSignal("EnemyFloor"):Connect(refresh)

local function groundY(x: number, z: number, fromY: number): number?
	local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position.Y else nil
end
```

For many enemies, cache ground heights on a grid. That project later added a cached 2-stud height grid with fallbacks to an exact raycast where the grid was ambiguous, after server profiling flagged per-enemy raycasts. See [[NPC AI and Behaviour]] and [[Pathfinding]].

Pathfinding uses collision geometry: decorative non-colliding props do not block paths, colliders do. `PathfindingModifier` and `PathfindingLink` mark areas and jumps.

## Collision groups

Collision groups decide which groups collide with which. Facts (Roblox docs):
- One `Default` group always exists and cannot be renamed or deleted.
- All groups collide with each other until you disable pairs.
- A part belongs to exactly one group.
- `PhysicsService:GetMaxCollisionGroups()` returns the limit (32 at the time of writing).

```lua
--!strict
local PhysicsService = game:GetService("PhysicsService")

local GROUPS = { "Players", "Enemies", "EnemyWalls" }
for _, g in GROUPS do
	if not PhysicsService:IsCollisionGroupRegistered(g) then
		PhysicsService:RegisterCollisionGroup(g)
	end
end
-- Players pass through each other; invisible enemy-only walls stop enemies but not players.
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
PhysicsService:CollisionGroupSetCollidable("Players", "EnemyWalls", false)
PhysicsService:CollisionGroupSetCollidable("Enemies", "EnemyWalls", true)

local function setGroup(model: Instance, group: string)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = group
		end
	end
end
```

Uses in level design: enemy-only walls that keep AI inside arenas, player-only barriers, projectiles that pass through allies, debris that does not collide with characters.

## Physics cost of geometry

- **Anchor everything static.** Unanchored parts join simulation.
- **Fewer, bigger colliders** beat many small ones.
- **Box fidelity has the lowest memory overhead**; Default and PCD are "generally more expensive" (docs).
- **Do not use mesh collision on large terrain-like meshes** when a few blocks or Terrain would do.
- **Unions and meshes with PCD** take time to compute; avoid creating them at runtime.

## Testing collision after an art pass

1. **Toggle collision visualisation** and look at every walkable area.
2. **Ray grids:** cast a grid of down-rays over walkable areas before and after the change and compare hit heights (one project used 1,620 rays per area).
3. **Walk-off tests:** rays or a test character along every edge to find holes in bounds. One dressing pass ran 466 rays above the tallest new prop per zone to confirm 0 leaks.
4. **Gate and doorway checks:** a gate frame's step collider once sat about 20 studs above the ramp surface, blocking every gate in a realm until moved. Walk through every gate after moving floors.
5. **Enemy areas:** spawn enemies and watch them for a minute; snagging and floating show immediately.

```lua
--!strict
-- Snapshot floor heights over an area; compare two snapshots to catch collision changes.
local function floorGrid(minX: number, maxX: number, minZ: number, maxZ: number, step: number, topY: number): { [string]: number }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true -- ignore non-colliding visuals
	local out: { [string]: number } = {}
	for x = minX, maxX, step do
		for z = minZ, maxZ, step do
			local hit = workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -topY - 500, 0), params)
			out[x .. "," .. z] = if hit then math.floor(hit.Position.Y * 100 + 0.5) / 100 else -math.huge
		end
	end
	return out
end

local function diff(a: { [string]: number }, b: { [string]: number }, tolerance: number): number
	local changed = 0
	for k, v in a do
		if math.abs((b[k] or -math.huge) - v) > tolerance then
			changed += 1
			if changed <= 20 then
				print("changed at", k, v, "->", b[k])
			end
		end
	end
	return changed
end
```

`RespectCanCollide = true` makes the ray behave like a character: it ignores non-colliding parts.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Visual mesh used as floor | Snagging, jitter, enemies floating | Primitive colliders |
| PCD on every mesh | Slow loads, physics cost | PCD only where walkable detail matters |
| Trying to set CollisionFidelity in game code | Nothing changes or error | Studio, or CreateMeshPartAsync + ApplyMesh |
| Transparent leftovers still colliding | Invisible walls | Audit transparent CanCollide parts |
| Decoration blocking raycasts | Wrong ground, blocked hits | CanQuery false or Include lists |
| Collider not moved with art | Walking on air | Move them as one model |
| No regression test | Silent collision changes | Ray-grid snapshots |

## Checklist

- [ ] Visual art non-colliding; colliders are simple invisible Parts.
- [ ] Decoration CanTouch / CanQuery off.
- [ ] Mesh fidelity: Box for small, Hull for convex, PCD only where needed.
- [ ] AI floors invisible and tagged; enemy boxes clear of colliders.
- [ ] Collision groups registered once, documented.
- [ ] Ray-grid before/after test on every art pass; every gate walked.

## See also

- [[Parts Unions and MeshParts]], [[Level Design for Roblox]], [[Terrain Tools and Terrain API]], [[Foliage Props and Scatter]]
- [[Physics Assemblies and Constraints]], [[Physics Performance]], [[Raycasts Shapecasts and Spatial Queries]]
- [[NPC AI and Behaviour]], [[Pathfinding]], [[Hitboxes and Hit Detection]], [[Characters and Humanoids]]

## Nuances and edge cases

1. **The flags answer different questions.** `CanCollide` affects physical contact, `CanTouch` affects `Touched` events, `CanQuery` affects raycasts and spatial queries. Roblox docs (as of October 2026) state that a part with `CanCollide` off still fires `Touched` unless `CanTouch` is off, and it still blocks raycasts unless `CanQuery` is off too. Many "invisible wall" and "raycast hits nothing visible" bugs are one of these left at its default.
2. **Thin geometry and fast objects.** Physics checks contacts each step, so a fast projectile or a falling character can pass through a wall thinner than the distance it travels in one step. Characters at high speeds and thin floors (under about 1 stud, rule of thumb) are the common case. Thicken colliders under the visual mesh, or raycast between positions for projectiles.
3. **Collision geometry is a server cost.** Every collidable part participates in the server's broad phase. A detailed city with thousands of small collidable props costs physics time on the server even when no one is near them. Turn collision off on anything players cannot meaningfully touch (small props, decoration above head height).
4. **Network ownership changes who resolves contacts.** An unanchored crate owned by a player's client is simulated there; collisions with it feel perfect to that player and laggy to others. Anchored geometry does not have this problem. For gameplay-critical physics, keep ownership on the server and accept some latency (see [[Network Ownership]]).
5. **Characters and stairs.** Humanoid characters step up small ledges, but a staircase built from exact visual steps produces bouncy movement and odd camera motion, worse on phones at low frame rates. A smooth invisible ramp collider over the visual stairs is almost always better.
6. **Collision groups have a hard limit and a design cost.** Collision groups are limited in number (the commonly cited cap is 32 groups; unverified, the collisions guide does not state it as of October 2026, so check `PhysicsService:GetMaxCollisionGroups()` in your place). Each new group multiplies the pairs you have to reason about. Group by role (Players, Enemies, Projectiles, Debris), not by individual object type.
7. **Scale changes contact counts.** One player standing on a floor is a few contacts. A round with 50 players and 200 physics debris pieces in a small arena can produce thousands of contact pairs. Debris that should be decorative belongs in a collision group that does not collide with players or with itself.
8. **Mesh collision fidelity on big meshes.** A single large terrain-like mesh with precise collision is expensive and can still give imperfect contact; splitting into tiles or using primitive colliders keeps physics predictable.

The senior trade-off: accurate collision costs authoring time and physics time; approximate collision costs feel. Players notice snagging and invisible walls far more than they notice that a wall collider is a box instead of the carved stone shape.

## Common mistakes (advanced)

1. **Turning off `CanCollide` but leaving `CanQuery` on for decoration.** Symptom: weapons and placement raycasts hit grass or particles' host parts. Fix: `CanQuery = false` on purely visual parts.
2. **Thin glass panes as the only collider.** Symptom: fast players or thrown objects pass through. Fix: a thicker invisible collider.
3. **Debris colliding with everything.** Symptom: server physics time spikes after explosions, players trip on fragments. Fix: a debris collision group and a cleanup timer.
4. **Using `Touched` for precise hit detection.** Symptom: missed or doubled hits, especially for fast weapons. Fix: spatial queries on a schedule ([[Hitboxes and Hit Detection]]).
5. **Hand-built stairs with step colliders.** Symptom: jittery camera and bouncing on phones. Fix: an invisible ramp.
6. **Kill bricks with `CanTouch` disabled by a later art pass.** Symptom: hazards stop working silently after a visual update. Fix: keep gameplay volumes as separate parts owned by the gameplay layer, and test them in a regression check.

## Related decisions

- [[Physics Performance]]: measuring what collision costs on the server.
- [[Debugging Physics and Network Ownership]]: diagnosing contacts that behave differently per client.
- [[Intersection and Collision Math]]: the math behind custom collision checks.
- [[Projectiles and Ballistics]]: raycast-based movement for fast objects.
- [[Destruction and Fracture]]: debris collision groups and cleanup.
- [[Obby and Platforming Level Design]]: collider shapes that make jumps feel fair.
- [[Mesh Optimization for Mobile]]: separating visual meshes from simple colliders.
- [[Raycasts Shapecasts and Spatial Queries]]: how `CanQuery` and filters shape queries.

## Connected notes
<!-- auto-links:start -->
[[Links - Collisions]] · Exporting and Validating Models for Roblox · Skill - Roblox Asset Import · Environment and Level Pipeline · Avatar Body Types and Scale in Gameplay · Modular Environment Kits
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Exporting and Validating Models for Roblox]] · [[Level of Detail and Model Streaming]] · [[Procedural World Generation]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Voxel Art - Studs Outlines and Style Kits]] · [[Grid Placement and Player Building Systems]] · [[World Composition and Set Dressing - Designed, Not Scattered]] · [[Modeling in Blender for Roblox]] · [[Materials MaterialVariants and SurfaceAppearance]]
<!-- related:end -->
