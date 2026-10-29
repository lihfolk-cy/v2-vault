---
tags: [math, game-math, collision, intersection, hit-detection, raycast, zones, projectiles, luau, type/guide, area/math, level/intermediate]
---
# Intersection and Collision Math

<!-- tldr:start -->
> [!tldr] TL;DR
> - Zone does not notice a player who stood still: `Touched` for zones -> Poll point-in-shape tests
> - Cursor flies to the horizon: Ray almost parallel to the plane -> Cap distance; ignore near-parallel rays
> - Rays through box faces miss randomly: `0 * inf` NaN in the slab test -> Explicit parallel branch
> - Each collision check names its shape (point, sphere, cylinder, box, capsule, polygon) and uses the matching test.
> - Zones are polled with containment tests, not `Touched`.
> - Ray tests handle parallel rays and origins inside the shape.
>
> Cost: TL;DR ~180 tok · whole note ~5.4k tok. Read more: ## 3. Rays against simple shapes · ## 4. Capsules: the right shape for characters · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox gives you a physics engine and fast spatial queries, so why do the maths yourself? Because a lot of gameplay collision is not about parts at all. A safe zone drawn as a polygon, a hitbox that exists only for one server tick, a lag-compensated capsule around where a player was 120 ms ago, a building cursor projected onto a floor plane, a turret leading a moving target, a thousand bullets in a bullet-hell mode: none of those need an `Instance`, and several cannot use one. Pure geometry is deterministic, runs in parallel Luau, costs nothing in replication and is easy to test.

[[Raycasts Shapecasts and Spatial Queries]] covers the engine's query APIs, filtering and performance. [[Cookbook - Math CFrame and Vectors]] has the closest point on a segment. This note covers the geometry itself: point containment, ray tests against planes, spheres and boxes, capsules from segment-to-segment distance, swept tests that cannot tunnel, intercept courses, a spatial hash for many objects, and the numeric traps in each.

---

## 1. Engine query or your own maths?

| Situation | Use | Why |
|---|---|---|
| Hit arbitrary map geometry, meshes, terrain | Engine (`workspace:Raycast`, `Spherecast`, `Blockcast`, `Shapecast`) | Exact collision geometry you cannot reproduce |
| "Which parts are in this region?" | Engine (`GetPartBoundsInBox`, `GetPartBoundsInRadius`, `GetPartsInPart`) | Broad phase is built in |
| Hit test against characters by simple shapes | Your maths (sphere or capsule per character) | No query cost, works on historic positions |
| Zones and regions defined by designers | Your maths (box, cylinder, polygon) | Exact rules, no parts touching |
| Cursor onto a building floor or water surface | Your maths (ray-plane) | One division, no filtering needed |
| Hundreds of projectiles against dozens of targets | Your maths plus a spatial hash | Query count would dominate the frame |
| Anything inside `task.desynchronize` | Your maths, or queries documented as parallel-safe | Pure functions are always safe ([[Parallel Luau and Actors]]) |

A common hybrid: maths decides **whom** a hit could affect (cheap shape tests against characters), and one engine raycast confirms line of sight for the few candidates that pass.

---

## 2. Is a point inside a shape?

**Sphere and cylinder.** A sphere is a squared distance check. A vertical cylinder (a capture point, a shop circle) is a flat distance check plus a height range. Comparing squared values avoids the square root:

```lua
--!strict
local function inCylinder(p: Vector3, base: Vector3, radius: number, height: number): boolean
	local dx, dz = p.X - base.X, p.Z - base.Z
	local dy = p.Y - base.Y
	return dx * dx + dz * dz <= radius * radius and dy >= 0 and dy <= height
end
```

**Oriented box.** Rotated zone parts are common (a diagonal bridge, a tilted ramp trigger). Transform the point into the box's own space and compare against half its size:

```lua
--!strict
local function inBox(p: Vector3, boxCFrame: CFrame, boxSize: Vector3): boolean
	local l = boxCFrame:PointToObjectSpace(p)
	local h = boxSize / 2
	return math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z
end
```

That one function replaces most uses of `Touched` for zones. `Touched` fires on contact events, which depend on physics, ownership and part movement; a player standing still inside a zone that appeared around them may never fire it. Polling `inBox` for each player at 5 to 10 Hz (rule of thumb) is exact, cheap and easy to reason about.

**Polygon on the ground.** Designers often want irregular zones: a lake shore, a district boundary. Store the outline as a list of XZ points and use the crossing-number test (cast a ray along +X and count edge crossings; odd means inside):

```lua
--!strict
-- poly: list of Vector3 outline points; only X and Z are used.
local function inPolygonXZ(p: Vector3, poly: { Vector3 }): boolean
	local inside = false
	local n = #poly
	local j = n
	for i = 1, n do
		local a, b = poly[i], poly[j]
		if (a.Z > p.Z) ~= (b.Z > p.Z) then
			local xCross = (b.X - a.X) * (p.Z - a.Z) / (b.Z - a.Z) + a.X
			if p.X < xCross then
				inside = not inside
			end
		end
		j = i
	end
	return inside
end
```

The strict `>` on one side and the implicit `<=` on the other makes vertices count once, so points exactly level with a vertex do not double-count. Division by zero cannot happen: the `if` only passes when `a.Z ~= b.Z`. For speed with many zones, check the polygon's bounding box first.

Concave polygons are fine. Self-intersecting ones (a figure eight) give "inside" for odd overlaps only, which surprises designers; validate outlines when you load them.

---

## 3. Rays against simple shapes

All three tests take a ray origin `o` and direction `d`, and return the distance `t` along the ray to the first hit (with `d` unit length, `t` is in studs), or `nil`.

### Ray against a plane

```lua
--!strict
-- Plane through point q with unit normal n.
local function rayPlane(o: Vector3, d: Vector3, q: Vector3, n: Vector3): number?
	local denom = d:Dot(n)
	if math.abs(denom) < 1e-8 then
		return nil -- parallel
	end
	local t = (q - o):Dot(n) / denom
	return if t >= 0 then t else nil
end
```

**Gameplay: a building cursor.** Get the mouse ray from `Camera:ViewportPointToRay(x, y)`, intersect it with the plane of the current build floor (`q = (0, floorY, 0)`, `n = Vector3.yAxis`), then snap. No raycast, no filter list, no accidental hits on the preview model or other players. The same trick projects a cursor onto a water surface, a vertical wall being painted, or a tilted slope (any plane). Only fall back to a real raycast when you need to place on top of existing geometry ([[Grid Placement and Player Building Systems]]).

Watch for grazing angles: when the camera looks almost parallel to the floor, `denom` is tiny and `t` huge; the cursor flies to the horizon. Cap `t` at a maximum build distance.

### Ray against a sphere

```lua
--!strict
-- d must be unit length. Returns distance to the first hit, or 0 if o is inside.
local function raySphere(o: Vector3, d: Vector3, c: Vector3, r: number): number?
	local m = o - c
	local b = m:Dot(d)
	local cc = m:Dot(m) - r * r
	if cc > 0 and b > 0 then
		return nil -- outside and pointing away
	end
	local disc = b * b - cc
	if disc < 0 then
		return nil
	end
	local t = -b - math.sqrt(disc)
	return if t < 0 then 0 else t
end
```

**Gameplay:** hitscan weapons against a head sphere and a body capsule, shield bubbles, "did this beam touch the orb". Returning 0 for an origin inside the sphere is a choice: for a shield bubble you may instead want the exit point (`-b + sqrt(disc)`) so shots from inside still hit the shell.

### Ray against a box (slab method)

```lua
--!strict
-- Oriented box. Returns entry distance (0 if starting inside), or nil.
local function rayBox(o: Vector3, d: Vector3, boxCFrame: CFrame, boxSize: Vector3, maxT: number): number?
	local lo = boxCFrame:PointToObjectSpace(o)
	local ld = boxCFrame:VectorToObjectSpace(d)
	local h = boxSize / 2
	local tMin, tMax = 0, maxT
	local origin = { lo.X, lo.Y, lo.Z }
	local dir = { ld.X, ld.Y, ld.Z }
	local half = { h.X, h.Y, h.Z }
	for axis = 1, 3 do
		local oA, dA, hA = origin[axis], dir[axis], half[axis]
		if math.abs(dA) < 1e-9 then
			-- Parallel to this slab: must already be inside it
			if oA < -hA or oA > hA then
				return nil
			end
		else
			local inv = 1 / dA
			local t1 = (-hA - oA) * inv
			local t2 = (hA - oA) * inv
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return nil
			end
		end
	end
	return tMin
end
```

The parallel branch is not optional. The textbook trick of dividing by zero to get infinity breaks when the origin sits exactly on a slab face: `0 * inf` is NaN, and `math.max` and `math.min` with NaN do not behave like the maths assumes. In grid-aligned Roblox maps, rays exactly parallel to box faces and origins exactly on faces are common, not rare.

---

## 4. Capsules: the right shape for characters

A sphere is too round for a standing character and a box catches on corners. A **capsule** (a segment with a radius) fits a humanoid well and is cheap: two capsules overlap when the distance between their core segments is at most the sum of their radii. That needs the closest points between two segments:

```lua
--!strict
-- Closest points between segments p1-q1 and p2-q2. Returns the two points.
local function closestSegmentSegment(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3): (Vector3, Vector3)
	local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
	local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
	local EPS = 1e-9
	local s, t
	if a <= EPS and e <= EPS then
		s, t = 0, 0
	elseif a <= EPS then
		s = 0
		t = math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e <= EPS then
			t = 0
			s = math.clamp(-c / a, 0, 1)
		else
			local b = d1:Dot(d2)
			local denom = a * e - b * b
			s = if denom > EPS then math.clamp((b * f - c * e) / denom, 0, 1) else 0
			t = (b * s + f) / e
			if t < 0 then
				t = 0
				s = math.clamp(-c / a, 0, 1)
			elseif t > 1 then
				t = 1
				s = math.clamp((b - c) / a, 0, 1)
			end
		end
	end
	return p1 + d1 * s, p2 + d2 * t
end

local function capsulesOverlap(a1: Vector3, a2: Vector3, ra: number, b1: Vector3, b2: Vector3, rb: number): boolean
	local c1, c2 = closestSegmentSegment(a1, a2, b1, b2)
	local diff = c1 - c2
	local r = ra + rb
	return diff:Dot(diff) <= r * r
end
```

This is the standard algorithm (from Ericson's *Real-Time Collision Detection*), handling degenerate segments (points) and parallel segments.

**Gameplay: lag-compensated melee.** Each tick the server records a capsule per character (feet to head, radius about 1.2 studs for a default-size character, rule of thumb). When a sword swing arrives, the server rewinds to the attacker's view time, approximates the blade sweep as a capsule from hilt to tip, and tests it against the rewound victim capsules. No parts, no physics, no dependency on what the victim's client did with its character. The blade sweep between two server ticks is itself a moving capsule; for fast swings, test the blade at several sub-steps of the swing rather than once ([[Hitboxes and Hit Detection]], [[Melee Combat System End to End]]).

Scaled characters change the radius and height. The reference project used a 1.6x character scale and had to account for it in ranges and camera offsets (measured in the reference project); derive capsule size from the character's actual scale, not constants.

---

## 5. Swept tests: no more tunnelling

A projectile at 300 studs per second moves 5 studs per 60 Hz frame. A target 2 studs thick can sit entirely between two samples, and a "check for overlap each frame" test never sees it. Swept tests check the whole motion.

**Moving sphere against a static sphere** is a ray test: shrink the moving sphere to a point and grow the target by its radius. **Two moving spheres** reduce to the same thing in relative motion: take the motion of A relative to B.

```lua
--!strict
-- Spheres A (radius ra) and B (radius rb) moving with velocities va, vb during [0, dt].
-- Returns the fraction of dt at first contact, or nil.
local function sweptSpheres(pa: Vector3, va: Vector3, ra: number, pb: Vector3, vb: Vector3, rb: number, dt: number): number?
	local m = pa - pb
	local v = (va - vb) * dt   -- relative displacement over the step
	local r = ra + rb
	local c = m:Dot(m) - r * r
	if c <= 0 then
		return 0 -- already overlapping
	end
	local a = v:Dot(v)
	if a < 1e-12 then
		return nil -- no relative motion
	end
	local b = m:Dot(v)
	if b >= 0 then
		return nil -- moving apart
	end
	local disc = b * b - a * c
	if disc < 0 then
		return nil
	end
	local t = (-b - math.sqrt(disc)) / a
	return if t <= 1 then t else nil
end
```

The returned fraction gives the exact contact point and time inside the frame, which is what you want for spawning impact effects where the hit really happened rather than where the projectile ended up.

For projectiles against map geometry, the engine equivalent is a raycast (or `Spherecast`) from the previous position to the current one each step ([[Projectiles and Ballistics]]). Use the maths version for projectile-versus-projectile (bullets hitting grenades) and projectile-versus-character-shape tests.

---

## 6. Intercept courses: leading a moving target

A turret firing a projectile of speed `s` at a target at relative position `d` with velocity `v` must aim where the target will be. Solve `|d + v t| = s t` for the time `t`:

`(v.v - s^2) t^2 + 2 (d.v) t + d.d = 0`

```lua
--!strict
-- Returns aim point and time to impact, or nil if the projectile can never catch the target.
local function interceptPoint(shooter: Vector3, target: Vector3, targetVel: Vector3, speed: number): (Vector3?, number?)
	local d = target - shooter
	local a = targetVel:Dot(targetVel) - speed * speed
	local b = 2 * d:Dot(targetVel)
	local c = d:Dot(d)
	local t: number
	if math.abs(a) < 1e-9 then
		-- Equal speeds: linear equation
		if math.abs(b) < 1e-9 then
			return nil, nil
		end
		t = -c / b
	else
		local disc = b * b - 4 * a * c
		if disc < 0 then
			return nil, nil
		end
		local sq = math.sqrt(disc)
		local t1 = (-b - sq) / (2 * a)
		local t2 = (-b + sq) / (2 * a)
		-- Smallest positive root
		if t1 > t2 then
			t1, t2 = t2, t1
		end
		t = if t1 > 0 then t1 else t2
	end
	if t <= 0 then
		return nil, nil
	end
	return target + targetVel * t, t
end
```

Design notes:

- **Perfect leads feel unfair.** An AI turret with perfect intercept maths hits every target moving in a straight line, and players learn that the only defence is constant strafing. Add aim error that grows with target speed, or lead by a fraction (70 to 90 percent) so changing direction is rewarded (rule of thumb).
- **Gravity changes the problem.** With a ballistic arc, the equation becomes quartic. In practice, iterate: estimate `t` without gravity, compute the launch velocity for that `t` with gravity ([[Cookbook - Math CFrame and Vectors]] recipe 10), recompute `t` from the new path length, repeat two or three times.
- **Player velocity is noisy.** `AssemblyLinearVelocity` of a character jitters with every input change; smooth it over a few frames before predicting. Jumping players have a velocity that changes sign within a second; predicting the full arc is usually overkill.

---

## 7. Many objects: a spatial hash

Testing every projectile against every character is `n * m` tests; every character against every other is `n(n-1)/2`. At 100 characters that is 4,950 pairs per tick, still fine for simple sphere tests. At 1,000 bullets against 100 characters it is 100,000 tests per tick, and you need a broad phase.

A uniform grid hash is the simplest one that works well when objects are similar in size:

```lua
--!strict
local CELL = 16 -- studs; about 2x the typical object size (rule of thumb)

local function cellKey(cx: number, cz: number): number
	-- Packs two cell coordinates into one number. Valid while |cx|, |cz| < 500,000.
	return (cx + 500000) * 1000000 + (cz + 500000)
end

type Grid = { [number]: { number } } -- cell -> list of object ids

local function buildGrid(positions: { Vector3 }): Grid
	local grid: Grid = {}
	for id, p in positions do
		local key = cellKey(p.X // CELL, p.Z // CELL)
		local bucket = grid[key]
		if bucket then
			table.insert(bucket, id)
		else
			grid[key] = { id }
		end
	end
	return grid
end

-- Visit candidates within `radius` of p (radius <= CELL keeps this to the 3x3 neighbourhood).
local function forNearby(grid: Grid, p: Vector3, visit: (number) -> ())
	local cx, cz = p.X // CELL, p.Z // CELL
	for dx = -1, 1 do
		for dz = -1, 1 do
			local bucket = grid[cellKey(cx + dx, cz + dz)]
			if bucket then
				for _, id in bucket do
					visit(id)
				end
			end
		end
	end
end
```

`//` on numbers is floor division, so negative coordinates land in the right cells. The numeric key avoids building strings every frame. Rebuild the grid each tick (cheap: one pass), or update only objects that changed cells. Using only X and Z is right for most ground-based games; flying games add a Y cell.

When objects vary hugely in size (a dragon and a swarm of bees), a single cell size fails: large objects span many cells. Insert large objects into every cell they overlap, or keep them in a separate small list tested against everything.

---

## 8. Rectangles on screen

UI has collisions too: drag-and-drop into slots, tooltips that must not overlap the edge, a custom cursor over buttons. GUI rectangles from `AbsolutePosition` and `AbsoluteSize` overlap when they overlap on both axes:

```lua
--!strict
local function guiOverlap(a: GuiObject, b: GuiObject): boolean
	local ap, as = a.AbsolutePosition, a.AbsoluteSize
	local bp, bs = b.AbsolutePosition, b.AbsoluteSize
	return ap.X < bp.X + bs.X and bp.X < ap.X + as.X
		and ap.Y < bp.Y + bs.Y and bp.Y < ap.Y + as.Y
end
```

This ignores `Rotation` on the GUI objects and any clipping by parents; for a drop target, also check the slot is visible. For "which slot gets the item", choose the overlap with the largest area or the slot nearest the dragged item's centre, not the first match, or items snap to the wrong neighbour when they straddle two ([[Tools and Inventory Systems]], [[Debugging UI Layout and Input]]).

---

## 9. Numeric traps

- **Epsilons depend on scale.** `1e-9` is sensible for squared lengths of a few studs, too strict for large distances. Positions are stored as 32-bit floats in the engine ([[Big Numbers Precision and Formatting]]); 10,000 studs from the origin, the spacing between representable positions is about a thousandth of a stud, so tests that need exact contact fail there. Use tolerances relative to the sizes involved.
- **Touching versus overlapping.** Decide whether `<=` or `<` counts as a hit and use it everywhere. Inconsistent choices make an item placed exactly against a wall count as "colliding" in one check and "free" in another.
- **Normalisation hidden in "unit" parameters.** `raySphere` assumes `d` is unit length; a non-unit direction returns distances in the wrong units. Assert it in development (`math.abs(d.Magnitude - 1) < 1e-4`).
- **NaN propagation.** One NaN position in a character's history (for example, a teleport to an invalid CFrame) poisons every test that touches it, and comparisons with NaN are all false, so a NaN capsule is never hit. Validate inputs from clients and reject NaN at the boundary ([[Server Authority and Validation]]).
- **Time-of-impact versus end-of-step.** Effects and damage numbers spawned at the end-of-step position appear behind thin walls the projectile passed through. Use the contact fraction.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Zone does not notice a player who stood still | `Touched` for zones | Poll point-in-shape tests |
| Cursor flies to the horizon | Ray almost parallel to the plane | Cap distance; ignore near-parallel rays |
| Rays through box faces miss randomly | `0 * inf` NaN in the slab test | Explicit parallel branch |
| Fast bullets pass through targets | Per-frame overlap tests | Swept tests or segment casts |
| Melee feels unfair at high ping | Testing current positions | Rewound capsules at the attacker's view time |
| Turret never misses | Perfect intercept | Partial lead or speed-scaled error |
| Server frame time spikes in big fights | All-pairs tests | Spatial hash broad phase |
| Items drop into the wrong UI slot | First overlap wins | Largest overlap or nearest centre |
| Odd-shaped zone includes a hole | Self-intersecting polygon | Validate outlines at load |

## Checklist

- [ ] Each collision check names its shape (point, sphere, cylinder, box, capsule, polygon) and uses the matching test.
- [ ] Zones are polled with containment tests, not `Touched`.
- [ ] Ray tests handle parallel rays and origins inside the shape.
- [ ] Fast movers use swept tests; effects spawn at the contact point.
- [ ] Character hit tests use capsules sized from the character's actual scale and, for PvP, rewound positions.
- [ ] Many-object tests use a broad phase.
- [ ] Tolerances are relative to scale; NaN inputs are rejected at the boundary.

## See also

[[Game Math Start Here]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Hitboxes and Hit Detection]] · [[Projectiles and Ballistics]] · [[Client Prediction and Reconciliation for Combat]] · [[Collision and Physics Geometry]] · [[Dot and Cross Products in Gameplay]] · [[Cookbook - Math CFrame and Vectors]] · [[Grid Placement and Player Building Systems]] · [[Parallel Luau and Actors]] · [[Detecting Combat Exploits - Reach Rate and Aim]]

## Connected notes
<!-- auto-links:start -->
[[2D Collision Physics and Platformer Movement]] · Links - Raycasting and spatial queries · Physics Performance · Voxel Scale Grids and Stud Alignment · Links - Combat · Physics Assemblies and Constraints
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Math Vectors and CFrames]] · [[Rotations Angles and Quaternions]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · [[Curves in Luau - Paths Beams and Motion]] · [[Interpolation Easing and Curves Math]] · [[Probability and Statistics for Designers]]
<!-- related:end -->
