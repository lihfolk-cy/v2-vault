---
tags: [physics, projectiles, ballistics, combat, networking, raycast, anti-cheat, type/guide, area/physics, level/intermediate, api/Touched, area/security]
---
# Projectiles and Ballistics

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Unanchored part plus `Touched` for bullets -> Simulated point with swept casts
> - Avoid: Client tells the server who it hit, no checks -> Validate origin, time, line of sight, plausibility
> - Avoid: Server-only hit decision for fast bullets -> Lag compensation with a cap, or checked client claims
> - Fast projectiles are simulated points with swept casts.
> - Closed-form motion from launch data; one shared module for client and server.
> - Shooter predicts; server validates and decides damage; others replay cosmetically.
>
> Cost: TL;DR ~170 tok · whole note ~5.1k tok. Read more: ## 2. Motion maths · ## 3. The simulation loop that never misses · ## 10. Common mistakes · ## Checklist
<!-- tldr:end -->

Every shooter, bow, fireball and thrown grenade is a projectile system, and every projectile system answers the same four questions: what moves (a physical part, or a mathematical point), who simulates it (server, shooter, everyone), who decides the hit, and how other players see it. Getting the answers wrong produces the familiar failures: bullets that pass through walls, hits that "should have landed", rockets that lag behind the launcher, and exploiters hitting everyone on the map. This note covers the motion maths (gravity drop, drag, aiming with drop, leading a moving target), the simulation loop that never misses thin walls, the standard network architecture with its trade-offs, server validation, ricochet and penetration, homing, and the budgets that keep hundreds of projectiles cheap.

Hit detection for melee and the basics of casting are in [[Hitboxes and Hit Detection]] and [[Raycasts Shapecasts and Spatial Queries]]. Latency and prediction in general are in [[Client Prediction and Reconciliation for Combat]].

Source labels: **Docs** (Roblox docs, as of October 2026), **Rule of thumb**. Code is strict Luau, **reviewed, not run**.

---

## 1. Physical parts versus simulated points

| | Physical projectile (unanchored part) | Simulated projectile (maths + casts) |
|---|---|---|
| Motion | The physics engine | Your code, each frame |
| Hit detection | `Touched` or contact | Cast from last position to new position |
| Thin walls at speed | Tunnels through | Never misses (swept casts) |
| Network | Replicates as a part, ownership issues | You send a small message; clients draw their own visual |
| Bouncing, rolling | Free | You write it |
| Cost per projectile | A physics assembly plus replication | A few casts per frame |

Rule of thumb: **bullets, arrows, spells and anything fast are simulated points.** Grenades that should roll down stairs, physics toys and debris can be physical parts, because rolling and bouncing on arbitrary geometry is what the engine is good at. Even then, decide the explosion's effect on the server, not from `Touched` ([[Physics Assemblies and Constraints]] explains why `Touched` is unreliable for gameplay).

Why physical parts fail for fast things: at 60 frames per second, a 600 studs/s bullet moves 10 studs per frame. The engine's contact detection checks overlaps at discrete steps; a thin wall between two positions is never overlapped, so the bullet goes through.

---

## 2. Motion maths

### Position at time t

With initial position `p0`, initial velocity `v0` and constant acceleration `a` (gravity, plus any constant wind):

```
p(t) = p0 + v0 * t + 0.5 * a * t^2
v(t) = v0 + a * t
```

Because this is closed form, you do not need to integrate frame by frame for drag-free projectiles. You can compute where the projectile is at any time from its launch data. That matters for networking (section 4): a client that joins the stream late, or a server checking a claimed hit, can compute the exact position at any moment.

Gravity for projectiles does not have to be `workspace.Gravity`. Most games use a per-weapon gravity (arrows drop more than sniper rounds) for feel. Store it in the weapon config.

### Drag

Linear drag (`a = -c * v`) has a closed form too:

```
v(t) = v0 * e^(-c t)                       (ignoring gravity)
p(t) = p0 + v0 * (1 - e^(-c t)) / c
```

Quadratic drag (`a = -c * |v| * v`, more realistic) does not have a simple closed form with gravity, so you integrate in small steps. Practical choice: use no drag or linear drag for gameplay projectiles; reserve quadratic drag for games where ballistics is the point.

### Aiming with drop: the launch angle

To hit a target at horizontal distance `d` and height difference `h` with launch speed `s` and gravity `g` (positive number), the launch angle satisfies:

```
tan(theta) = (s^2 +/- sqrt(s^4 - g * (g * d^2 + 2 * h * s^2))) / (g * d)
```

The minus sign gives the flat shot, the plus sign the lob. If the square root's argument is negative, the target is out of range. AI archers and turrets use this; players get it as a trajectory preview arc.

```lua
--!strict
-- Returns the launch direction to hit `target` from `origin` at speed `speed`, or nil if out of range.
local function solveBallistic(origin: Vector3, target: Vector3, speed: number,
	gravity: number, lob: boolean): Vector3?
	local delta = target - origin
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local d = flat.Magnitude
	if d < 1e-3 then
		return if delta.Y >= 0 then Vector3.yAxis else -Vector3.yAxis
	end
	local h = delta.Y
	local s2 = speed * speed
	local disc = s2 * s2 - gravity * (gravity * d * d + 2 * h * s2)
	if disc < 0 then
		return nil
	end
	local root = math.sqrt(disc)
	local tanTheta = (s2 + (if lob then root else -root)) / (gravity * d)
	local theta = math.atan(tanTheta)
	local horizontal = flat.Unit
	return (horizontal * math.cos(theta) + Vector3.yAxis * math.sin(theta)).Unit
end
```

### Leading a moving target

For a target moving at constant velocity `vt`, solve for the time `t` when a projectile of speed `s` (no drop) can meet it: `|delta + vt * t| = s * t`. That is a quadratic in `t`:

```
(vt.vt - s^2) t^2 + 2 (delta.vt) t + delta.delta = 0
```

Take the smallest positive root, then aim at `target + vt * t`. For projectiles with drop, iterate: lead, then solve the angle, then recompute flight time, two or three times. Turret and AI aim use this. For players, an aim-assist that nudges toward the lead point is enough.

---

## 3. The simulation loop that never misses

Each frame, move the projectile from its previous position to its new one and cast along that segment. Use a `Raycast` for thin bullets and a `Spherecast` (radius = projectile radius) for anything fat, like fireballs. The cast is the hit test; the visual just follows.

```lua
--!strict
-- ReplicatedStorage/Shared/Projectile.lua
-- A simulated projectile: closed-form motion, swept casts each step.
local Projectile = {}

export type State = {
	origin: Vector3,
	velocity: Vector3,
	gravity: Vector3,
	radius: number, -- 0 = raycast
	maxDistance: number,
	startTime: number,
	lastPosition: Vector3,
	travelled: number,
	params: RaycastParams,
}

function Projectile.positionAt(s: State, t: number): Vector3
	return s.origin + s.velocity * t + s.gravity * (0.5 * t * t)
end

-- Advance to time `now`. Returns the RaycastResult if it hit something, plus whether it expired.
function Projectile.step(s: State, now: number): (RaycastResult?, boolean)
	local t = now - s.startTime
	local newPos = Projectile.positionAt(s, t)
	local segment = newPos - s.lastPosition
	local len = segment.Magnitude
	if len < 1e-4 then
		return nil, false
	end
	local result: RaycastResult?
	if s.radius > 0 then
		result = workspace:Spherecast(s.lastPosition, s.radius, segment, s.params)
	else
		result = workspace:Raycast(s.lastPosition, segment, s.params)
	end
	s.travelled += len
	s.lastPosition = newPos
	return result, s.travelled >= s.maxDistance
end

return Projectile
```

Details that matter:

- **Start from the muzzle, but test from the eye.** Third-person shooters fire from the camera's aim but spawn the visual at the gun. Do a first cast from the character's head to the muzzle; if the muzzle is inside a wall, the shot should hit that wall, not start on the other side of it.
- **Filter the shooter** (and their accessories, vehicle and other projectiles) with `RaycastParams`. Build params once per shooter and reuse them; `FilterDescendantsInstances` must be reassigned, not mutated ([[Raycasts Shapecasts and Spatial Queries]]).
- **Spherecasts miss what they start inside.** If the projectile spawns overlapping a target at point blank, the first sweep will not report it. Do a `GetPartBoundsInRadius` overlap check on the first step.
- **Time, not frames.** Step with the time since launch, not a per-frame delta multiplied up. Frame-rate differences then do not change trajectories, and server and clients agree.
- **Range by distance and by time.** A lobbed grenade travels a short distance but may fly for a long time; cap both.

Public open-source projectile libraries do the same thing with more features (the long-standing FastCast module is the best-known example). Read one before writing your own; the core loop above is what they share.

---

## 4. Network architecture

### The standard model: shooter predicts, server decides, others replay

1. **Shooter's client** simulates the projectile immediately (no delay) and shows hit effects for instant feedback.
2. It sends the server a small fire message: origin, direction, a timestamp (`workspace:GetServerTimeNow()`), and a weapon id. Not the hit.
3. **Server** validates (section 5), then simulates the projectile itself, or checks the shooter's later hit claim against its own record of the shot.
4. **Server** broadcasts the shot to other clients, who simulate their own copy for visuals only. Cosmetic broadcasts can use an `UnreliableRemoteEvent` (payloads over 1,000 bytes are dropped, **Docs**), because a missing tracer is harmless.
5. Damage is applied only by the server.

Because motion is closed form, every machine can draw the projectile from `(origin, velocity, gravity, startTime)` alone. Late receivers fast-forward to the current time instead of starting at the muzzle, so everyone sees the projectile in roughly the same place.

### Who decides the hit: the latency trade-off

| Approach | Shooter experience | Victim experience | Exploit surface |
|---|---|---|---|
| Server simulates against current positions | Must lead targets by ping; feels unfair at 150 ms | Fair: you are hit where the server thinks you are | Small |
| Client claims hit, server checks plausibility | Hits land where aimed | Sometimes hit "behind cover" (you moved on your screen, not on theirs) | Larger; needs good checks |
| Server rewinds targets to the shooter's time (lag compensation) | Hits land where aimed | Same "behind cover" effect, bounded by the rewind cap | Small, if the rewind is capped |

Slow projectiles (rockets, arrows, fireballs) are usually simulated on the server with current positions: a target can see them coming and dodge, so server truth is fair. Fast bullets are usually client-claimed with server checks, or server-checked with a short history of target positions (keep 0.5 to 1 second of root CFrames per player at a fixed rate and rewind to the shot time, capped at around 250 ms; rule of thumb). Details of rewind and reconciliation are in [[Client Prediction and Reconciliation for Combat]].

### Rate and bandwidth

- Do not send one remote per bullet for a 15-shots-per-second gun. Batch shots per frame or per 50 ms into one message, and for shotguns send the seed (section 6) instead of every pellet direction.
- Clients far away do not need tracers. Filter the broadcast by distance on the server ([[Interest Management and Per-Player Replication]]).
- Budget: a few hundred bytes per second per firing player is typical; check yours with the method in [[Network Bandwidth Budgets and Measuring Them]].

---

## 5. Server validation

The fire message is untrusted input. The server checks, cheapest first:

| Check | Reject when |
|---|---|
| Weapon owned and equipped | Not equipped, or unknown weapon id |
| Fire rate | Shots arrive faster than the weapon's rate, with a small burst allowance for network bunching |
| Ammo | No ammo in the server's count |
| Origin | Origin further than a few studs from the server's view of the shooter's head or muzzle (allow for latency: speed x ping) |
| Direction | Not a unit vector, NaN, or wildly off the character's facing for weapons that require facing |
| Timestamp | In the future, or older than the rewind cap |
| Claimed hit | Target not within the projectile's possible position at that time (plus tolerance), or line of sight from origin blocked on the server |

NaN deserves its own line: a direction of `(0/0, 0, 0)` passes many naive checks because every comparison with NaN is false. Test `v.X == v.X` for each component, or check `v.Magnitude` is within `[0.99, 1.01]` (NaN fails that comparison too, so it is rejected). Patterns for safe remote handling are in [[Remote Abuse Patterns and Rate Limiting in Practice]] and [[Detecting Combat Exploits - Reach Rate and Aim]].

```lua
--!strict
-- Server: minimal fire validation.
local function isFiniteUnit(v: Vector3): boolean
	local m = v.Magnitude
	return m > 0.99 and m < 1.01 -- NaN fails both comparisons
end

local function validateFire(player: Player, origin: Vector3, dir: Vector3,
	shotTime: number, lastShot: number, minInterval: number): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if head == nil then
		return false
	end
	if not isFiniteUnit(dir) then
		return false
	end
	local now = workspace:GetServerTimeNow()
	if shotTime > now + 0.05 or now - shotTime > 0.5 then
		return false
	end
	if shotTime - lastShot < minInterval * 0.8 then
		return false
	end
	local slack = 6 + head.AssemblyLinearVelocity.Magnitude * 0.3
	if (origin - head.Position).Magnitude > slack then
		return false
	end
	return true
end
```

Never kick on a single failure. Count failures per player per minute and act on patterns.

---

## 6. Spread, determinism and shotguns

Spread should be random for the shooter but reproducible for the server and other clients. Use a seeded generator: the client picks a seed per shot (or the server issues a sequence), sends it, and every machine computes the same pellet directions with `Random.new(seed)`.

```lua
--!strict
local function spreadDirections(forward: Vector3, seed: number, pellets: number,
	coneDegrees: number): { Vector3 }
	local rng = Random.new(seed)
	local base = CFrame.lookAt(Vector3.zero, forward)
	local out = table.create(pellets) :: { Vector3 }
	local maxAngle = math.rad(coneDegrees)
	for i = 1, pellets do
		-- Uniform over the cone's area, not its angle (sqrt keeps the centre from clumping).
		local r = maxAngle * math.sqrt(rng:NextNumber())
		local phi = rng:NextNumber() * 2 * math.pi
		local dir = base * CFrame.Angles(0, 0, phi) * CFrame.Angles(r, 0, 0)
		out[i] = dir.LookVector
	end
	return out
end
```

A client-chosen seed lets an exploiter pick seeds that produce tight groupings. If that matters (competitive shooters), have the server issue seeds in advance, or validate that the seed advances in a sequence.

---

## 7. Ricochet, penetration and homing

**Ricochet.** Reflect the velocity on the hit normal: `r = v - 2 * (v . n) * n`. Multiply by a restitution under 1, and only ricochet below a grazing-angle threshold (steep hits stop). Restart the projectile from the hit point plus a small offset along the normal, with the new velocity and a new start time. Cap bounces at 2 or 3.

**Penetration.** On hit, if the material and thickness allow, continue from the far side. To find the far side, cast backward from a point beyond the hit (`hitPos + dir * maxThickness`) toward the hit; the first hit of that reverse cast is the exit point. Thickness is the distance between entry and exit. Reduce damage by thickness and material. Store penetration power per material in a table, not per part.

**Homing.** Each step, rotate the velocity toward the target by at most `turnRate * dt` radians, keeping speed constant. A limited turn rate is what makes missiles dodgeable. Homing projectiles lose the closed-form motion, so the server must simulate them (and broadcast occasional corrections), or clients must replay with the same target and the same step size. Server simulation at a fixed step with clients interpolating is the robust choice.

---

## 8. Visuals and performance

- **One visual pool.** Reuse tracer parts or beams from a pool; never create and destroy hundreds of parts per second. Move pooled parts with `workspace:BulkMoveTo` when you have many ([[Physics Performance]]).
- **Visuals can be cheap.** A `Beam` between two attachments stretched along the last frame's segment reads as a fast tracer. A short `Trail` works for slower projectiles ([[Beams and Trails]]).
- **Anchored, non-colliding, non-querying.** Visual parts must have `CanCollide`, `CanTouch` and `CanQuery` false so your own casts and the physics engine ignore them.
- **Budgets (rule of thumb):** a few hundred live simulated projectiles on a server is fine; each costs one cast per step. Thousands (bullet-hell bosses) need fewer casts: step at 30 Hz on the server, or test against a handful of player capsules mathematically instead of casting against the world ([[Raycasts Shapecasts and Spatial Queries]], "avoid queries when maths will do").
- **Parallel Luau.** Casts are allowed in parallel; large projectile counts can step in an Actor and apply effects after `task.synchronize()` ([[Parallel Luau and Actors]]).

---

## 9. When not to simulate a projectile

- **Hitscan** weapons (instant rays) are simpler and fine for short-range guns where travel time is under a frame or two. Many shooters use hitscan up close and simulated projectiles only for snipers, rockets and grenades.
- **Area spells** that land where the player clicked do not need a projectile at all. Show one, but decide the effect at the target point after the travel time.

---

## 10. Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Unanchored part plus `Touched` for bullets | Missed hits, wall tunnelling, laggy rockets | Simulated point with swept casts |
| Client tells the server who it hit, no checks | Exploiters hit anyone anywhere | Validate origin, time, line of sight, plausibility |
| Server-only hit decision for fast bullets | "My shot clearly hit" complaints at high ping | Lag compensation with a cap, or checked client claims |
| Per-frame delta integration | Different paths on 30 and 144 FPS | Closed-form motion from start time |
| No first-step overlap check | Point-blank shots pass through | Overlap at spawn |
| Muzzle inside the wall | Shoot through walls by hugging them | Cast eye to muzzle first |
| One remote per bullet | Bandwidth spikes, throttling | Batch, seeds for pellets |
| NaN direction accepted | Server errors or odd hits | Magnitude range check |
| Creating tracer parts per shot | Memory churn, GC spikes | Pool |

## Checklist

- [ ] Fast projectiles are simulated points with swept casts.
- [ ] Closed-form motion from launch data; one shared module for client and server.
- [ ] Shooter predicts; server validates and decides damage; others replay cosmetically.
- [ ] Fire-rate, ammo, origin, direction, timestamp and hit plausibility checks.
- [ ] Lag compensation (if any) capped and logged.
- [ ] Seeded spread for multi-pellet weapons.
- [ ] Visual pool, non-querying visuals, distance-filtered broadcasts.
- [ ] Tested at 200+ ms simulated latency with 2+ clients.

## See also

[[Physics and Vehicles Start Here]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Hitboxes and Hit Detection]] · [[Client Prediction and Reconciliation for Combat]] · [[Combat Systems Architecture]] · [[Detecting Combat Exploits - Reach Rate and Aim]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Beams and Trails]] · [[Parallel Luau and Actors]] · [[Destruction and Fracture]] · [[Genre Playbook - Shooters FPS and TPS]]

## Connected notes
<!-- auto-links:start -->
[[Intersection and Collision Math]] · Cookbook - Math CFrame and Vectors · Game Math Start Here · Dot and Cross Products in Gameplay · Links - Raycasting and spatial queries · Links - Latency and prediction
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Ropes Chains and Soft Bodies]] · [[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]] · [[Boats Buoyancy and Water]] · [[Vehicle Damage, Repair and Wreck States]] · [[Aircraft and Flight Models]]
<!-- related:end -->
