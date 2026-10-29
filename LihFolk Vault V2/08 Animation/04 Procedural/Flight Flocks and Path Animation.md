---
tags: [procedural, flight, splines, b-spline, banking, flocks, boids, creatures, luau, type/guide, area/animation, level/intermediate]
---
# Flight Flocks and Path Animation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Creature turns flat like a cursor: no bank -> `atan(v * yawRate / g)`, lagged and clamped
> - Bank snaps at every control point: C1 curve (Catmull-Rom, arcs) -> uniform cubic B-spline
> - Speeds up and slows down for no reason: moving `u` at a constant rate -> arc-length table
>
> Cost: TL;DR ~110 tok · whole note ~4.2k tok. Read more: ## The maths · ## Flocks · ## Common mistakes
<!-- tldr:end -->

Flying creatures are judged on two things: the path (does it move like something with mass and wings?) and the attitude along it (does it bank into turns, pitch into dives, flap when it climbs?). A dragon that slides along straight segments, turning flat like a cursor, reads as broken no matter how good its wing clip is. This note builds flight from the path up, using the system one production game (the reference project) wrote after its owner said its sky creatures' flying "looked really bad": closed cubic B-spline paths, arc-length speed control, physically motivated banking, and dt-based flap-and-glide wing motion. Then flocks.

## Why B-splines

| Curve | Passes through its points | Continuity | Overshoot | Good for |
|---|---|---|---|---|
| Straight segments | yes | position only (C0): heading jumps at corners | none | never, for flight |
| Catmull-Rom | yes | C1: heading continuous, curvature (and so bank) jumps at points | can loop and overshoot | camera paths through exact spots |
| **Uniform cubic B-spline** | no (passes near) | **C2: heading, curvature, bank and pitch never jump** | **never: stays inside the convex hull of its control points** | flight, smooth patrols |
| [[Bezier Curves\|Bezier]] chains | at segment ends | C1 unless constrained | handles can be wild | authored curves in editors |

Two properties make the uniform cubic B-spline ideal for creatures:

- **C2 continuity.** Bank angle depends on curvature. A curve whose curvature jumps (Catmull-Rom, joined arcs) makes the creature snap from one bank angle to another at each control point.
- **The convex-hull property.** Each segment lies inside the hull of its four control points. If the control polygon clears the buildings, the creature clears the buildings. You check clearance on a dozen points instead of on the curve.

## The maths

A closed loop with `n` control points `p[0..n-1]` has `n` segments. Segment `i` uses four consecutive points `a, b, c, d = p[i], p[i+1], p[i+2], p[i+3]` (indices wrapping), with local parameter `u` in [0, 1]:

```
P(u)   = ( (1-u)^3 a + (3u^3 - 6u^2 + 4) b + (-3u^3 + 3u^2 + 3u + 1) c + u^3 d ) / 6
P'(u)  = -0.5 (1-u)^2 a + (1.5u^2 - 2u) b + (-1.5u^2 + u + 0.5) c + 0.5 u^2 d
P''(u) = (1-u) a + (3u - 2) b + (1 - 3u) c + u d
```

The four weights sum to 1 for every `u` and are never negative, which is where the convex-hull property comes from. At `u = 1` of one segment and `u = 0` of the next, position, first and second derivatives all match: C2.

### Arc-length parametrisation

`u` does not advance at constant speed along the curve: segments with spread-out control points are longer. Moving `u` at a constant rate makes the creature speed up and slow down for no visible reason. Fix it once at build time:

1. Sample each segment at `SUB` points (the project used 24) and accumulate chord lengths into a table `L[k]`.
2. At runtime keep a distance `s` along the path, advance it by `speed * dt`, and find the table interval containing `s`. Because `s` only increases (modulo the loop length), keep a cursor and walk forward from last frame's index: constant time per frame.
3. Interpolate within the interval to get the global parameter, then split it into segment index and local `u`.

```lua
--!strict
local SUB = 24

local function evalSeg(pts: { Vector3 }, n: number, i: number, u: number): (Vector3, Vector3, Vector3)
	local a, b, c, d = pts[i % n + 1], pts[(i + 1) % n + 1], pts[(i + 2) % n + 1], pts[(i + 3) % n + 1]
	local u2, v = u * u, 1 - u
	local u3 = u2 * u
	local pos = (a * (v * v * v) + b * (3 * u3 - 6 * u2 + 4) + c * (-3 * u3 + 3 * u2 + 3 * u + 1) + d * u3) / 6
	local d1 = a * (-0.5 * v * v) + b * (1.5 * u2 - 2 * u) + c * (-1.5 * u2 + u + 0.5) + d * (0.5 * u2)
	local d2 = a * v + b * (3 * u - 2) + c * (1 - 3 * u) + d * u
	return pos, d1, d2
end

export type Path = { pts: { Vector3 }, n: number, L: { number }, len: number, K: number }

local function buildPath(pts: { Vector3 }): Path
	local n = #pts
	local L = { 0 }
	local prev = evalSeg(pts, n, 0, 0)
	local acc = 0
	for k = 1, n * SUB do
		local i = (k - 1) // SUB
		local p = evalSeg(pts, n, i, (k - i * SUB) / SUB)
		acc += (p - prev).Magnitude
		L[k + 1] = acc
		prev = p
	end
	return { pts = pts, n = n, L = L, len = acc, K = n * SUB }
end

-- st.s: distance along the path; st.k: cursor into L (kept between calls).
local function locate(path: Path, st: { s: number, k: number }): (Vector3, Vector3, Vector3)
	local L, K = path.L, path.K
	local k = st.k
	if st.s < L[k + 1] then k = 0 end                       -- wrapped around the loop
	while k < K - 1 and L[k + 2] <= st.s do k += 1 end
	st.k = k
	local a, b = L[k + 1], L[k + 2]
	local g = (k + math.clamp((st.s - a) / math.max(b - a, 1e-6), 0, 1)) / SUB
	local i = math.min(math.floor(g), path.n - 1)
	return evalSeg(path.pts, path.n, i, g - i)
end
```

## Attitude: facing, pitch and bank

### Facing and pitch

Face the velocity: `CFrame.lookAt(pos, pos + velocity, Vector3.yAxis)`. Pitch then comes for free from the climb. Use the *true* velocity, including any bob from the wings (see below), or the body looks like it is sliding up and down a pole.

`CFrame.lookAt` is undefined when the velocity is vertical. Keep paths from going straight up or down (the convex hull makes that easy to check), or fall back to the previous up vector.

### Turn rate from curvature

With unit tangent `T = P'/|P'|`, the curvature vector (which points toward the centre of the turn, with magnitude 1/radius) is

```
kN = (P'' - T (P''.T)) / |P'|^2
```

The heading's rate of turn about `+Y` at speed `v`, using only the horizontal components, is

```
yawRate = v * (T.z kN.x - T.x kN.z) / (T.x^2 + T.z^2)        -- rad/s, positive = turning left
```

### Bank angle

An aircraft or a bird in a coordinated turn banks so that lift balances gravity plus the centripetal force. The lateral acceleration is `v * yawRate`, so

```
tan(bank) = v * yawRate / g
```

The project used exactly that form with an art-directed "gravity" instead of the real one:

```
roll = clamp(atan(v * yawRate / BANK_G), -35 deg, 35 deg),   BANK_G = 15 studs/s^2
```

then **lagged** it with a first-order filter (time constant 0.6 s), so the bank builds into a turn instead of snapping to it. A smaller `BANK_G` than real gravity at the creature's scale exaggerates the bank, which reads better at a distance; the 35-degree cap stops tight corners from flipping it on its side.

Sign check: positive `yawRate` is a left turn; `CFrame.lookAt(...) * CFrame.Angles(0, 0, roll)` with positive `roll` rotates the right side up (about the backward `+Z` axis), so the left wing dips into a left turn. Correct.

### Speed with climb

Creatures slow in climbs and speed up in dives. The project eased speed toward `cruise * (1 - 0.5 * climb)`, where `climb = T.y` (the sine of the pitch), with a 1.1 s time constant. A 30-degree climb (`climb = 0.5`) settles at 75% of cruise.

```lua
-- One step of the flight state. st: { s, k, v, roll, turn } ; cruise in studs/s.
local function ease(dt: number, tau: number): number
	return if dt > 0 then 1 - math.exp(-dt / tau) else 1
end

local function flightStep(path: Path, st: any, cruise: number, dt: number): CFrame
	st.s = (st.s + st.v * dt) % path.len
	local pos, d1, d2 = locate(path, st)
	local m = d1.Magnitude
	local T = d1 / m
	local kN = (d2 - T * d2:Dot(T)) / (m * m)
	local h2 = math.max(T.X * T.X + T.Z * T.Z, 1e-4)
	local yawRate = st.v * (T.Z * kN.X - T.X * kN.Z) / h2
	st.v += (cruise * (1 - 0.5 * T.Y) - st.v) * ease(dt, 1.1)
	local wantRoll = math.clamp(math.atan(st.v * yawRate / 15), -math.rad(35), math.rad(35))
	st.roll += (wantRoll - st.roll) * ease(dt, 0.6)
	st.turn += (yawRate - st.turn) * ease(dt, 0.8)            -- smoothed, for neck and tail
	return CFrame.lookAt(pos, pos + T, Vector3.yAxis) * CFrame.Angles(0, 0, st.roll)
end
```

## Wings: flap bursts and glides

Continuous flapping looks like a toy. Big flyers alternate **bursts** of a few beats with **glides**. The project's model, everything dt-based so it is frame-rate independent:

| Element | Value |
|---|---|
| Beat frequency | 0.8 Hz, varied +-8% per creature; up to +30% when climbing |
| Downstroke share | 42% of a beat (fast, powerful) ; upstroke 58% (slower) |
| Burst length | 2-5 beats; +2 when climbing, -2 when diving (minimum 2); cut to 1 beat in a dive |
| Glide length | 2.5-5.5 s, x1.6 when diving; cut to 0.4 s when climbing; at least 1.8 s |
| Burst ends | mid-downstroke, wings level, so the glide pose is reached smoothly |
| Glide ends | restarts at the bottom of the stroke, upstroke first |
| Flap weight | eased between flapping (1) and gliding (0) with a 0.35 s time constant |
| Body bob | 1.3 studs, rising on the downstroke |
| Surge | speed +-3.5% with the stroke |

The stroke shape with an asymmetric beat (`D = 0.42`): position `+1` with wings up, `-1` with wings down,

```
p in [0, D):  stroke = cos(pi p / D)                  -- fast downstroke
p in [D, 1):  stroke = -cos(pi (p - D) / (1 - D))     -- slower upstroke
```

Both pieces meet with zero slope at the top and bottom, so there is no kink. Secondary motion on top: the outer wing panel **folds back and down over the upstroke** (a `sin^2` bump), the leading edge **twists down on the downstroke**, and the wingtip **lags** the shoulder by 12% of a beat. In glides the wings hold a slight dihedral with tiny tremble sines (frequencies 9.7 to 26.7 Hz, amplitudes under 1.5 degrees) so they never freeze.

The body bob is applied to position, and its rate is added to the velocity used for facing, so the body pitches slightly with each stroke instead of translating stiffly.

## Neck, tail and head

- **Neck and tail curve into and out of the turn**: each of the 4 neck segments yaws `+0.3 x turn` (into the turn), each of the 7 tail segments `-0.36 x turn` (swinging out), with the turn rate clamped to +-0.35 rad/s.
- **Travelling waves** down the tail: segment `i` yaws `(1.4 + 0.45 i) * sin(1.15 t - 0.62 i + seed)` degrees, and pitches with the wingbeat, `1.6 * w * sin(P - 1.4 - 0.65 i)`, so the beat ripples to the tip.
- **The head looks into the turn and stays level**: yaw toward the turn (clamped to +-12 degrees) and a counter-roll of `-0.45 x bank`, so the creature keeps its eyes on the horizon like a real bird.

All of these are pure functions of the state, which is what made the module testable.

## Designing the paths

- Generate control points from a formula (a ring with radius and height modulated by low sines), not by hand: `r(a) = R + A sin(3a + phase)`, `y(a) = H + B sin(2a + phase)`. The project used rings of 10-12 points for three paths: a slow high loop (cruise 50 studs/s), a figure-eight passing over the central structure (60) and a wide eye-level loop (56).
- **Clearance by the hull**: the project kept low legs at least 300 studs outside the hub's footprint, and only the figure-eight crossed over it, at least 160 studs above its top.
- Start each creature at a random distance along its path and a random clock (seeded `Random.new(seed)`), so several creatures on one path are not in lockstep.
- Keep the module **pure maths, no instances**. The project's flight module could be loaded from source in Edit mode and simulated offline to check clearance, speed and bank ranges before anything was placed in the world.

## Flocks

### Option 1: path followers (cheap, deterministic)

Each bird follows the leader's path at a fixed offset in the leader's frame (a formation), plus a small noise wobble (two sines with random phases). Because it is a pure function of time, every client shows the same flock with zero networking. This is the right default for ambient birds.

### Option 2: boids (emergent)

Each bird steers by three rules over neighbours within a radius:

- **Separation**: away from neighbours that are too close (weighted by `1 / distance`).
- **Alignment**: toward the neighbours' average velocity.
- **Cohesion**: toward the neighbours' centre.

Plus **goal seeking** (toward a waypoint or path point) and **avoidance** (away from obstacles, via a raycast ahead). Weights are taste; a starting point (rule of thumb): separation 1.5, alignment 1.0, cohesion 0.8, goal 0.6, with speed clamped between 0.7 and 1.3 times cruise.

```lua
--!strict
-- One boids step. birds: { pos, vel }. Uses a spatial hash so neighbour search is near O(n).
local CELL = 20
-- integer cell coordinates packed into one number (valid within about +-10,000 studs of the origin)
local function cellOf(p: Vector3): (number, number, number) return p.X // CELL, p.Y // CELL, p.Z // CELL end
local function key(x: number, y: number, z: number): number
	return (x + 512) + (y + 512) * 1024 + (z + 512) * 1048576
end
local function safeUnit(v: Vector3): Vector3
	local m = v.Magnitude
	return if m > 1e-6 then v / m else Vector3.zero
end

local function boidsStep(birds: { { pos: Vector3, vel: Vector3 } }, goal: Vector3, cruise: number, dt: number)
	local grid: { [number]: { number } } = {}
	for i, b in birds do
		local k = key(cellOf(b.pos))
		local cell = grid[k]
		if not cell then cell = {}; grid[k] = cell end
		table.insert(cell, i)
	end
	local R2 = CELL * CELL
	for i, b in birds do
		local sep, ali, coh, n = Vector3.zero, Vector3.zero, Vector3.zero, 0
		local cx, cy, cz = cellOf(b.pos)
		for dx = -1, 1 do for dy = -1, 1 do for dz = -1, 1 do
			local cell = grid[key(cx + dx, cy + dy, cz + dz)]
			if cell then
				for _, j in cell do
					if j ~= i then
						local o = birds[j]
						local d = b.pos - o.pos
						local d2 = d:Dot(d)
						if d2 < R2 and d2 > 1e-6 then
							sep += d / d2                     -- stronger when closer
							ali += o.vel
							coh += o.pos
							n += 1
						end
					end
				end
			end
		end end end
		local steer = safeUnit(goal - b.pos) * 0.6
		if n > 0 then
			steer += sep * 1.5 * CELL + (safeUnit(ali / n) - safeUnit(b.vel)) * 1.0 + safeUnit((coh / n) - b.pos) * 0.8
		end
		local v = b.vel + steer * cruise * dt
		local s = math.clamp(v.Magnitude, 0.7 * cruise, 1.3 * cruise)
		b.vel = (if v.Magnitude > 1e-6 then v.Unit else Vector3.zAxis) * s
		b.pos += b.vel * dt
	end
end
```

Orient each bird with the same bank formula as above, using the change in its velocity direction for the turn rate. Boids are non-deterministic across clients; for ambient flocks nobody notices, for gameplay-relevant flocks run them on the server at a low rate and interpolate on clients, or use option 1.

## Performance

- **Cull**: skip creatures off-screen (`camera:WorldToViewportPoint` reports whether a point is on screen) and far away. The project culled its flyers off-screen and **unparented flocks beyond 900 studs** (a model outside the workspace costs no rendering).
- **Batch**: many birds as anchored parts moved with one `workspace:BulkMoveTo` call per frame (see [[Tween and CFrame Animation of Objects]]).
- **Lower rates at distance**: update boids at 10-20 Hz and interpolate positions every frame.
- **Rigged creatures** (wings and tails as joints) cost more per creature than rigid birds: reserve them for the few big flyers near the player.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Creature turns flat like a cursor | no bank | `atan(v * yawRate / g)`, lagged and clamped |
| Bank snaps at every control point | C1 curve (Catmull-Rom, arcs) | uniform cubic B-spline |
| Speeds up and slows down for no reason | moving `u` at a constant rate | arc-length table |
| Flies through a building | curve checked by eye | keep the control polygon clear (convex hull) |
| Constant flapping reads as a toy | no glides | bursts and glides, more flapping in climbs |
| Body slides up and down with the wingbeat | bob not in the facing velocity | add the bob rate to the velocity |
| Flock costs milliseconds | O(n^2) neighbour search, per-bird property sets | spatial hash, `BulkMoveTo`, cull |
| Several dragons in lockstep | same start and seed | random distance, clock and frequency per creature |

Related: [[Animating Creatures and Monsters]], [[Multi-Bone IK - FABRIK and CCD]], [[Springs Damping and Smoothing]], [[Tween and CFrame Animation of Objects]], [[Enemy and NPC Animation]], [[Procedural Animation]].

## Connected notes
<!-- auto-links:start -->
[[Aircraft and Flight Models]] · Interpolation Easing and Curves Math · [[Creature Rig Conventions]] · [[Look-At Aim and Head Tracking]] · Cookbook - Math CFrame and Vectors · Pathfinding · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Procedural Gait and Footstep Planning]] · [[Procedural Death Knockdown and Hit Reactions]] · [[Procedural Weapon Motion]] · [[Inverse Kinematics]] · [[Two-Bone IK Math]] · [[Snippets - Procedural Motion]] · [[Ground Fitting Pipeline]] · [[Foot Placement and Ground IK]]
<!-- related:end -->
