---
tags: [luau, cookbook, math, cframe, vector3, recipes]
---
# Cookbook - Math CFrame and Vectors

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `.Unit` on a zero vector, `acos` without clamping: NaN that spreads.
> - Avoid: Positive Z used as forward.
> - Avoid: Fixed lerp alphas per frame.
> - Every function guards zero-length vectors.
> - Smoothing uses `1 - exp(-k * dt)` or a spring.
> - Field of view checks compare against a precomputed cosine.
>
> Read more (18 KB note): ## 10. Launch a projectile to hit a point in a given time · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Recipes for the geometry questions that come up weekly: facing things, measuring angles, checking cones, smoothing motion, orbiting, random points, projectile arcs and grid snapping. Each recipe is a small pure function you can drop into a shared `MathUtil` module. Code is `--!strict` Luau, reviewed, not run. The theory (spaces, composition order, Euler angles, float precision) is in [[Math Vectors and CFrames]] and [[Motor6D Math and CFrame Composition]]; motion smoothing in depth is in [[Springs Damping and Smoothing]].

Conventions used below: Roblox is Y-up, and a `CFrame`'s `LookVector` is its negative Z axis (Roblox docs (as of October 2026)).

---

## 1. Face a target

**Problem.** Point a turret, NPC or camera at a position.

```lua
--!strict
local function facing(from: Vector3, target: Vector3): CFrame
	if (target - from).Magnitude < 1e-4 then
		return CFrame.new(from)
	end
	return CFrame.lookAt(from, target)
end
```

**Why it works.** `CFrame.lookAt(position, target)` builds a frame at `position` whose `LookVector` points at `target`, using world up to fix the roll.

**Pitfall.** If `from` and `target` are the same point the direction is undefined and you get NaN, hence the guard. If the target is straight above or below, the up vector is parallel to the look direction and the roll is unstable; pass a different third argument (`upVector`) for top-down cases.

---

## 2. Turn only around the vertical axis

**Problem.** An NPC facing a player on a hill tilts backwards. You want yaw only.

```lua
--!strict
local function facingFlat(from: Vector3, target: Vector3): CFrame
	local flatTarget = Vector3.new(target.X, from.Y, target.Z)
	if (flatTarget - from).Magnitude < 1e-4 then
		return CFrame.new(from)
	end
	return CFrame.lookAt(from, flatTarget)
end
```

**Why it works.** Copying `from.Y` into the target removes the vertical difference, so the look direction is horizontal and the model stays upright.

**Pitfall.** For characters, setting the root's `CFrame` every frame fights the `Humanoid`, which also rotates the root (`AutoRotate`). Turn `AutoRotate` off or use an `AlignOrientation` constraint instead ([[Mover Constraints and Physics Controllers]]).

---

## 3. Angle between two directions

**Problem.** How far does the player need to turn to face the enemy, in degrees?

```lua
--!strict
local function angleBetween(a: Vector3, b: Vector3): number
	if a.Magnitude < 1e-6 or b.Magnitude < 1e-6 then
		return 0
	end
	local d = math.clamp(a.Unit:Dot(b.Unit), -1, 1)
	return math.deg(math.acos(d))
end

local function signedYaw(forward: Vector3, toTarget: Vector3): number
	-- Positive = target is to the left (counter-clockwise seen from above)
	local f = Vector3.new(forward.X, 0, forward.Z)
	local t = Vector3.new(toTarget.X, 0, toTarget.Z)
	return math.deg(math.atan2(f:Cross(t).Y, f:Dot(t)))
end
```

**Why it works.** The dot product of two unit vectors is the cosine of the angle between them. For a signed angle on the ground plane, `atan2(cross.Y, dot)` gives the direction too.

**Pitfall.** Floating point can make the dot product of unit vectors slightly greater than 1, and `math.acos(1.0000001)` is NaN. The `clamp` prevents that. Always guard zero-length vectors before `.Unit`.

---

## 4. Is the target inside a view cone?

**Problem.** Can this guard see the player, given a 90 degree field of view and 60 stud range?

```lua
--!strict
local function inCone(origin: CFrame, target: Vector3, halfAngleDeg: number, range: number): boolean
	local offset = target - origin.Position
	local distance = offset.Magnitude
	if distance > range then
		return false
	end
	if distance < 1e-4 then
		return true
	end
	return origin.LookVector:Dot(offset / distance) >= math.cos(math.rad(halfAngleDeg))
end

-- inCone(guardHead.CFrame, playerRoot.Position, 45, 60)
```

**Why it works.** Comparing the dot product to the cosine of the half-angle avoids `acos` entirely, and the cheap distance check runs first. Precompute `math.cos(...)` once if you call this a lot.

**Pitfall.** A cone check ignores walls. Follow a positive result with a raycast for line of sight ([[Raycasts Shapecasts and Spatial Queries]]). Note that the half angle is used: a 90 degree field of view is 45 degrees each side.

---

## 5. Smooth movement that does not depend on frame rate

**Problem.** `current = current:Lerp(goal, 0.1)` every frame is snappy at 240 fps and sluggish at 30 fps.

```lua
--!strict
local function damp(sharpness: number, dt: number): number
	return 1 - math.exp(-sharpness * dt)
end

-- Usage in RenderStepped/PreRender:
-- part.CFrame = part.CFrame:Lerp(goalCFrame, damp(12, dt))
-- value = value + (goal - value) * damp(8, dt)
```

**Why it works.** `1 - exp(-k * dt)` is the fraction of the remaining distance an exponential decay closes in `dt` seconds. Two half-frames give exactly the same result as one full frame, so the motion looks the same at any frame rate. Higher `sharpness` is snappier; 8 to 20 is a common range (rule of thumb).

**Pitfall.** This approaches the goal but never overshoots, so it cannot produce bouncy motion; use a spring for that. A huge `dt` after a hitch makes the alpha close to 1, which simply snaps: that is the correct behaviour. See [[Frame Order and RunService Timing]] for which event to use.

---

## 6. Orbit a point

**Problem.** Pets circling a player, or a camera rotating around a model.

```lua
--!strict
local function orbit(center: Vector3, radius: number, height: number, angle: number): CFrame
	local offset = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
	local position = center + offset
	return CFrame.lookAt(position, center)
end

-- Spread n pets evenly:
-- for i = 1, n do
--     local a = time * 0.8 + (i / n) * 2 * math.pi
--     pets[i]:PivotTo(orbit(root.Position, 6, 1, a))
-- end
```

**Why it works.** Cosine and sine of one angle give a point on a circle. Adding an index-based offset of a full turn divided by `n` spreads objects evenly.

**Pitfall.** Driving many anchored models with `PivotTo` every frame on the server floods replication. Animate cosmetic followers on the client, each client for everyone, from replicated owner positions ([[Network Performance]]).

---

## 7. Convert between world and local space

**Problem.** "Is the enemy to my left or right?" or "place this 3 studs in front of my hand, whatever way I face".

```lua
--!strict
local function localOffset(frame: CFrame, worldPoint: Vector3): Vector3
	return frame:PointToObjectSpace(worldPoint)
	-- X > 0: right of frame, Y > 0: above, Z < 0: in front
end

local function inFrontOf(frame: CFrame, studs: number): Vector3
	return frame:PointToWorldSpace(Vector3.new(0, 0, -studs))
	-- same as (frame * CFrame.new(0, 0, -studs)).Position
end

local function relative(a: CFrame, b: CFrame): CFrame
	return a:ToObjectSpace(b) -- b expressed in a's space; a * result == b
end
```

**Why it works.** Object space is the frame's own axes. `PointToObjectSpace` answers questions relative to a part, and `PointToWorldSpace` turns a local offset into a world position.

**Pitfall.** Forward is negative Z. Writing `Vector3.new(0, 0, studs)` puts the point behind. For directions (not points) use `VectorToObjectSpace` / `VectorToWorldSpace`, which ignore position.

---

## 8. Uniform random point in a circle or on a sphere

**Problem.** Scatter loot around a chest, or pick a random spawn inside a radius.

```lua
--!strict
local rng = Random.new()

local function randomInCircle(center: Vector3, radius: number): Vector3
	local angle = rng:NextNumber(0, 2 * math.pi)
	local r = radius * math.sqrt(rng:NextNumber())
	return center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
end

local function randomOnSphere(center: Vector3, radius: number): Vector3
	return center + rng:NextUnitVector() * radius
end
```

**Why it works.** Taking the square root of a uniform number corrects for the outer rings of a circle having more area; without it points cluster in the middle. `Random:NextUnitVector()` returns a uniformly random direction (Roblox docs (as of October 2026)).

**Pitfall.** Points generated on flat maths are not on the ground. Raycast down from above each point to find the floor, and reject points that land inside walls.

---

## 9. Random spread inside a cone

**Problem.** Shotgun pellets or a sloppy aim within 5 degrees of a direction.

```lua
--!strict
local rng = Random.new()

local function spread(direction: Vector3, maxAngleDeg: number): Vector3
	local base = CFrame.lookAt(Vector3.zero, direction)
	local cosMax = math.cos(math.rad(maxAngleDeg))
	local z = rng:NextNumber(cosMax, 1) -- uniform over the cone's cap
	local phi = rng:NextNumber(0, 2 * math.pi)
	local r = math.sqrt(1 - z * z)
	local localDir = Vector3.new(r * math.cos(phi), r * math.sin(phi), -z)
	return base:VectorToWorldSpace(localDir)
end
```

**Why it works.** Choosing the cosine of the angle uniformly between `cos(max)` and 1 spreads directions evenly over the cone's cap, then `phi` spins around the axis. The local direction uses negative Z as forward to match `LookVector`.

**Pitfall.** The naive version (random pitch and yaw in degrees) clusters shots near the edges and corners. For server-validated weapons, generate spread on the server or from a shared seed so the client cannot choose a perfect zero-spread shot ([[Detecting Combat Exploits - Reach Rate and Aim]]).

---

## 10. Launch a projectile to hit a point in a given time

**Problem.** Throw a grenade from `origin` so it lands on `target` after `T` seconds under game gravity.

```lua
--!strict
local function launchVelocity(origin: Vector3, target: Vector3, timeToHit: number): Vector3
	local g = Vector3.new(0, -workspace.Gravity, 0)
	return (target - origin) / timeToHit - g * (timeToHit / 2)
end

local function positionAt(origin: Vector3, velocity: Vector3, t: number): Vector3
	local g = Vector3.new(0, -workspace.Gravity, 0)
	return origin + velocity * t + g * (0.5 * t * t)
end
```

**Why it works.** From `p(t) = p0 + v t + g t^2 / 2`, solving for `v` with `p(T) = target` gives `v = (target - p0)/T - g T / 2`. `positionAt` lets you simulate or draw the arc and raycast between samples for hits.

**Pitfall.** `workspace.Gravity` defaults to 196.2 studs per second squared (Roblox docs (as of October 2026)), much stronger than people expect, so arcs need high speeds. A fixed time gives faster throws at long range; for a fixed speed you must solve a quadratic instead. Unanchored physics parts drift from this ideal arc through collisions, network ownership hand-offs and any air resistance you add; for gameplay-critical projectiles, simulate the path yourself with raycasts and render a cosmetic copy on clients.

---

## 11. Snap positions and rotations to a grid

**Problem.** Building systems need positions on a 4-stud grid and rotations in 90 degree steps.

```lua
--!strict
local function snap(value: number, step: number): number
	return math.round(value / step) * step
end

local function snapPosition(p: Vector3, step: number): Vector3
	return Vector3.new(snap(p.X, step), snap(p.Y, step), snap(p.Z, step))
end

local function snapYaw(cf: CFrame, stepDeg: number): CFrame
	local _, yaw, _ = cf:ToOrientation()
	local snapped = math.rad(snap(math.deg(yaw), stepDeg))
	return CFrame.new(cf.Position) * CFrame.fromOrientation(0, snapped, 0)
end
```

**Why it works.** Divide, round, multiply snaps any value to the nearest multiple of the step. `ToOrientation` extracts yaw (Y rotation) so you can snap just that axis.

**Pitfall.** Objects whose size is an odd multiple of the grid need a half-step offset or they straddle cells. Snapping on the client is for preview only; the server re-snaps and validates placement ([[Grid Placement and Player Building Systems]], [[Modular Environment Kits]]).

---

## 12. Closest point on a segment, and distance to it

**Problem.** Did a laser beam pass within 2 studs of a player? Is a player close to a rail?

```lua
--!strict
local function closestOnSegment(a: Vector3, b: Vector3, p: Vector3): Vector3
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	if lengthSq < 1e-8 then
		return a
	end
	local t = math.clamp((p - a):Dot(ab) / lengthSq, 0, 1)
	return a + ab * t
end

local function distanceToSegment(a: Vector3, b: Vector3, p: Vector3): number
	return (p - closestOnSegment(a, b, p)).Magnitude
end
```

**Why it works.** Projecting `p - a` onto the segment direction gives how far along the segment the nearest point is; clamping to 0..1 keeps it on the segment rather than the infinite line.

**Pitfall.** This tests the centre of the target, not its body. Add the target's radius to the threshold. For lag-compensated hit checks on fast beams, test against where targets were a ping ago, not where they are now ([[Client Prediction and Reconciliation for Combat]]).

---

## Common mistakes

- `.Unit` on a zero vector, `acos` without clamping: NaN that spreads.
- Positive Z used as forward.
- Fixed lerp alphas per frame.
- Random angles that are not uniform (circle without `sqrt`, cones from raw pitch and yaw).
- Server-side per-frame `PivotTo` on cosmetic objects.

## Checklist

- [ ] Every function guards zero-length vectors.
- [ ] Smoothing uses `1 - exp(-k * dt)` or a spring.
- [ ] Field of view checks compare against a precomputed cosine.
- [ ] Projectile maths reads `workspace.Gravity` rather than assuming a value.
- [ ] Client snapping and spread are re-done on the server where they matter.

## See also

[[Luau Cookbook Start Here]], [[Tween and CFrame Animation of Objects]], [[Camera Systems]], [[Procedural Animation]], [[Look-At Aim and Head Tracking]], [[Cookbook - Players and Characters]]

## Nuances and edge cases

1. **"Face a target" fails straight up and straight down.** `CFrame.lookAt` needs an up vector. When the look direction is parallel to it (a turret aiming straight up, a camera looking straight down), the result is undefined or flips suddenly. Clamp pitch to a few degrees short of vertical, or pass a different up vector when the direction is nearly vertical.
2. **Far from the origin, precision drops.** Positions are stored as 32-bit floats in many engine paths. Thousands of studs from the origin, small offsets and slow movement start to jitter (rule of thumb: visible problems are commonly reported beyond roughly 10,000 to 100,000 studs, depending on what is moving). Keep playable areas reasonably close to the origin, and for very large worlds, consider moving content rather than the player.
3. **Frame-rate independent smoothing on a 240 Hz monitor and a 30 fps phone.** The exponential form `alpha = 1 - math.exp(-speed * dt)` gives the same feel at any frame rate; a fixed `lerp(a, b, 0.1)` does not. But even the correct form behaves differently when `dt` spikes (a hitch of 0.5 s jumps almost all the way). Clamp `dt` for visuals so a hitch does not teleport the camera.
4. **Euler angles have an order.** `CFrame.Angles` and `CFrame.fromEulerAnglesYXZ` apply rotations in different orders. Yaw, then pitch, then roll (YXZ) is what cameras and characters usually want. Mixing orders gives rotations that look right for small angles and go wrong at large ones, which is why bugs show up only at extreme aim.
5. **Server and client see different CFrames.** An unanchored part owned by a client is simulated there; the server sees it a network round trip late, interpolated. Maths done on the server for "where is the player aiming" uses a position that lags behind what the player sees. Validate with tolerances, not exact equality, and allow more tolerance for higher-ping players.
6. **Projectile maths and gravity.** The "hit a point in a given time" recipe uses `workspace.Gravity`. If a game changes gravity per zone or uses a custom force, the solution is off. Read gravity at the moment of firing, and for drag or custom forces simulate the path instead of solving it in closed form.
7. **Grid snapping and rotation.** Snapping position to a grid is easy; snapping rotated objects so they still align is not, because a 1 by 3 part rotated 90 degrees has a different footprint. Snap the object's footprint (its rotated size), not only its pivot, or rotated pieces overlap by half a cell.
8. **Many players, many queries.** A view-cone or distance check for one NPC against 50 players is trivial; 200 NPCs each checking 50 players every frame is 10,000 checks per frame. Use squared distances (no square root), check less often for far NPCs, and pre-filter with a spatial query or a coarse grid.

## More common mistakes

1. **Comparing floats with `==`.** Symptom: "is the door closed" never becomes true. Fix: compare with a small tolerance or snap the value.
2. **Using `.Magnitude` where squared distance would do.** Symptom: extra cost in hot loops. Fix: compare `(a - b):Dot(a - b)` with the radius squared.
3. **Setting CFrame on a player-owned part from the server.** Symptom: the part jumps back because the client keeps simulating it. Fix: change it on the owner, or take ownership first.
4. **Mixing degrees and radians.** Symptom: rotations of 57 times what was expected. Fix: `math.rad` at the edge where designers enter degrees, radians everywhere else.
5. **Composing CFrames in the wrong order.** Symptom: an offset is applied in world space instead of local space. Fix: `cf * offset` for local, `offset * cf` for world.
6. **Not clamping `dt`.** Symptom: cameras and followers jump after a hitch. Fix: clamp `dt` for cosmetic smoothing.
7. **Pivot versus position.** Symptom: models rotate around a corner. Fix: use `PivotTo` and set the model's pivot deliberately.

## Related decisions

- [[Dot and Cross Products in Gameplay]]: the maths behind view cones and facing checks.
- [[Rotations Angles and Quaternions]]: why Euler orders and gimbal problems happen.
- [[Interpolation Easing and Curves Math]]: the theory behind frame-rate independent smoothing.
- [[Projectiles and Ballistics]]: full projectile systems beyond the closed-form launch.
- [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]: tolerances for validating client positions.
- [[Network Ownership]]: why server-set CFrames can be overwritten.
- [[Grid Placement and Player Building Systems]]: snapping rotated footprints.
- [[Infinite and Streamed Worlds]]: handling very large coordinates.
- [[Raycasts Shapecasts and Spatial Queries]]: pre-filtering targets before per-target maths.

## Connected notes
<!-- auto-links:start -->
[[Game Math Start Here]] · [[Intersection and Collision Math]] · [[Two-Bone IK Math]] · [[Cookbook - Remotes and Networking]] · [[Multi-Bone IK - FABRIK and CCD]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]
<!-- auto-links:end -->
