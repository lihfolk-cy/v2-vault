---
tags: [luau, math, vector3, cframe, random, geometry]
---
# Math Vectors and CFrames

<!-- tldr:start -->
> [!tldr] TL;DR
> - Part disappears / huge coordinates: NaN from `.Unit` of zero or divide by zero -> Guard magnitude; validate inputs
> - Rotation off by a lot: Degrees passed where radians expected -> `math.rad`
> - Object spins around the wrong axis: Multiplication order (local vs world) -> `cf * rot` local; rebuild for world
> - Angles in radians in code; degrees only at the UI/config boundary.
> - Every normalization guards against zero length.
> - Per-frame smoothing uses `dt`.
>
> Read more (20 KB note): ## 4. CFrame fundamentals · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Game code is mostly arithmetic on numbers, `Vector3`s and `CFrame`s. This note covers the `math` library (including the newer `lerp`, `map`, `isnan` family and constants), randomness with `Random`, `Vector3` and the native `vector` library, `CFrame` construction, composition and space conversion, the recipes you need every week (look-at, facing angles, projections, frame-rate independent smoothing), and the numeric traps: float precision, NaN, Euler angles and the far-from-origin problem. Character joints and CFrame composition for rigs are covered in depth in [[Motor6D Math and CFrame Composition]].

---

## 1. The math library (Docs)

| Function | Notes |
|---|---|
| `math.floor`, `math.ceil` | `math.floor(-0.5) == -1` |
| `math.round(x)` | Rounds half **away from zero**: `0.5 -> 1`, `-0.5 -> -1` |
| `math.clamp(x, min, max)` | `max` must be `>= min` or it errors |
| `math.sign(x)` | -1, 0 or 1 |
| `math.lerp(a, b, t)` | `a + (b - a) * t`; `t` outside 0..1 extrapolates |
| `math.map(x, inMin, inMax, outMin, outMax)` | Linear remap; does not clamp |
| `math.isnan`, `math.isinf`, `math.isfinite` | Use these, never `x == math.nan` |
| `math.noise(x, y?, z?)` | Perlin; mostly -1..1, sometimes outside; **0 at integer coordinates**; period 256 per axis |
| `math.random()`, `math.random(m)`, `math.random(m, n)` | 32-bit PCG; integer forms inclusive |
| `math.fmod(x, y)` | Sign of `x` (unlike `%`, which takes the sign of `y`) |
| `math.log(x, base?)`, `math.log10`, `math.exp`, `math.pow`, `math.sqrt` | |
| `math.atan2(y, x)` | Note the argument order |
| `math.modf`, `math.frexp`, `math.ldexp`, trig and hyperbolic functions | |

Constants: `math.pi`, `math.huge`, and (2026 docs) `math.tau` (2 pi), `math.e`, `math.phi`, `math.sqrt2`, `math.nan`. Check your Studio version before relying on the newer ones; `2 * math.pi` always works.

**`math.noise` nuance:** sampling at integers returns 0, so `math.noise(x)` for integer `x` is flat. Scale inputs (`x * 0.1 + 0.5`) and add a seed offset.

### Floating point

All numbers are doubles. Rules:
- Never compare computed floats with `==`. Use a tolerance: `math.abs(a - b) < 1e-6`, or `Vector3:FuzzyEq` / `CFrame:FuzzyEq`.
- Integers are exact up to 2^53. Above that, `x + 1 == x`.
- Division by zero gives `inf` or `nan`, not an error. `nan` propagates through everything and `nan ~= nan`. A single `nan` in a CFrame makes a part vanish or teleports it to nowhere; validate inputs (`x == x` is false only for NaN).
- `0.1 * 3 ~= 0.3`. Accumulating small steps drifts; recompute from a start time instead of adding `dt` forever where precision matters.

---

## 2. Randomness

```lua
local rng = Random.new()             -- seeded from entropy
local seeded = Random.new(12345)     -- deterministic sequence
print(rng:NextNumber())              -- [0, 1)
print(rng:NextNumber(5, 10))         -- [5, 10)
print(rng:NextInteger(1, 6))         -- inclusive
print(rng:NextUnitVector())          -- random direction
rng:Shuffle(array)                   -- in-place shuffle
local copy = rng:Clone()             -- same state, independent from here on
```

Use a `Random` object per system (loot, cosmetics, procedural generation) so one system consuming numbers does not change another's sequence. Deterministic seeds make procedural worlds reproducible and bugs replayable. `math.random` uses one shared generator per VM.

Weighted choice:

```lua
--!strict
local function weightedPick<T>(rng: Random, entries: { { item: T, weight: number } }): T
	local total = 0
	for _, e in entries do total += e.weight end
	local roll = rng:NextNumber(0, total)
	for _, e in entries do
		roll -= e.weight
		if roll < 0 then return e.item end
	end
	return entries[#entries].item   -- float edge case
end
```

Loot and luck mechanics, including how to present odds, are in [[RNG Drops and Luck Systems]]. Never trust a client-side roll for anything of value.

---

## 3. Vector3 and the vector library

`Vector3` values are **immutable** value types. In current Luau they are the VM's native `vector` type, so creating them does not allocate garbage-collected objects (Docs: luau.org performance on the native vector type).

```lua
local a = Vector3.new(1, 2, 3)
local b = Vector3.new(4, 5, 6)
print(a + b, a - b, a * 2, a / 2, a * b)   -- component-wise; a * b is component-wise, not dot
print(a // 2)                              -- floor division per component
print(a.X, a.Magnitude, a.Unit)
print(a:Dot(b), a:Cross(b))
print(a:Lerp(b, 0.5))
print(a:Angle(b))                          -- radians, unsigned 0..pi
print(a:Angle(b, Vector3.yAxis))           -- signed around an axis (-pi..pi) (Docs)
print(a:FuzzyEq(b, 1e-5))
print(a:Min(b), a:Max(b), a:Abs(), a:Floor(), a:Ceil(), a:Sign())
print(Vector3.zero, Vector3.one, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
```

You cannot assign `a.X = 5`; build a new vector: `Vector3.new(5, a.Y, a.Z)`.

**`Unit` of a zero vector is NaN.** Direction from a point to itself, or a velocity of zero, produces `(nan, nan, nan)`. Guard:

```lua
local function safeUnit(v: Vector3, fallback: Vector3): Vector3
	local m = v.Magnitude
	return if m > 1e-6 then v / m else fallback
end
```

The `vector` library (Docs) offers the same operations as free functions: `vector.create(x, y, z?)` (z defaults to 0), `vector.magnitude`, `vector.normalize`, `vector.dot`, `vector.cross`, `vector.angle(a, b, axis?)`, `vector.floor/ceil/abs/sign`, `vector.clamp(v, min, max)`, `vector.lerp`, `vector.min/max(...)`, `vector.zero`, `vector.one`. Components are readable as `x`/`X` etc. In Roblox these operate on the same native type as `Vector3`. They are handy in performance-sensitive or engine-agnostic code; `Vector3` methods are equally fine elsewhere.

### Recipes

```lua
-- Flat distance (ignore height)
local function flatDistance(a: Vector3, b: Vector3): number
	local d = b - a
	return Vector3.new(d.X, 0, d.Z).Magnitude
end

-- Project v onto a plane with normal n (n unit)
local function projectOnPlane(v: Vector3, n: Vector3): Vector3
	return v - n * v:Dot(n)
end

-- Reflect velocity off a surface normal
local function reflect(v: Vector3, n: Vector3): Vector3
	return v - 2 * v:Dot(n) * n
end

-- Is target within a cone in front of me?
local function inCone(origin: CFrame, target: Vector3, halfAngleDeg: number): boolean
	local to = target - origin.Position
	if to.Magnitude < 1e-6 then return true end
	return origin.LookVector:Dot(to.Unit) >= math.cos(math.rad(halfAngleDeg))
end
```

Compare squared distances to avoid `sqrt` in hot loops: `(a - b):Dot(a - b) < r * r`.

---

## 4. CFrame fundamentals

A `CFrame` is a position plus a rotation (a 3x3 orthonormal matrix). It describes where something is and which way it faces. CFrames are immutable.

```lua
local cf = CFrame.new(0, 5, 0)                                  -- position, no rotation
local look = CFrame.lookAt(Vector3.new(0, 5, 0), Vector3.new(10, 5, 0))  -- face a point
local along = CFrame.lookAlong(Vector3.zero, Vector3.xAxis)     -- face a direction (Docs)
local rot = CFrame.Angles(0, math.rad(90), 0)                   -- radians!
local fromAxis = CFrame.fromAxisAngle(Vector3.yAxis, math.pi / 2)
local between = CFrame.fromRotationBetweenVectors(Vector3.yAxis, normal)  -- shortest arc (Docs)
local m = CFrame.fromMatrix(pos, rightVector, upVector)          -- third axis derived

print(cf.Position, cf.Rotation, cf.LookVector, cf.RightVector, cf.UpVector)
print(CFrame.identity)
```

`LookVector` is **-Z** of the CFrame (Roblox faces negative Z). `RightVector` is +X, `UpVector` +Y.

`CFrame.lookAt(at, target, up)` is degenerate when the direction is parallel to `up` (looking straight up or down): the result can snap or flip. Pass a different `up` in that case.

### Composition is multiplication

`A * B` means "B expressed in A's space": apply B relative to A. Order matters; `A * B ~= B * A`.

```lua
local part = workspace.Door
-- Rotate around the part's OWN up axis (local space)
part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(15), 0)
-- Rotate around the WORLD up axis, keeping position
part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, math.rad(15), 0) * part.CFrame.Rotation
-- Move 5 studs forward in local space
part.CFrame = part.CFrame * CFrame.new(0, 0, -5)
-- Move 5 studs up in world space
part.CFrame = part.CFrame + Vector3.new(0, 5, 0)
```

`CFrame * Vector3` transforms a point from local to world space. `CFrame + Vector3` translates in world space.

### Spaces

| Method | Meaning |
|---|---|
| `a:ToWorldSpace(b)` | `a * b` |
| `a:ToObjectSpace(b)` | `a:Inverse() * b`: b relative to a |
| `a:PointToWorldSpace(p)` / `PointToObjectSpace(p)` | Points |
| `a:VectorToWorldSpace(v)` / `VectorToObjectSpace(v)` | Directions (rotation only) |
| `a:Inverse()` | Undo a |

The single most useful identity: to keep an object attached to another with a fixed offset, store `offset = parent.CFrame:ToObjectSpace(child.CFrame)` once, then each frame set `child.CFrame = parent.CFrame * offset`. This is also how welds (`C0`, `C1`) and Motor6D joints work ([[Motor6D Math and CFrame Composition]]).

### Angles

`CFrame.Angles(rx, ry, rz)` equals `CFrame.fromEulerAnglesXYZ`, which is the product `Rx * Ry * Rz` (Docs). `CFrame.fromOrientation(rx, ry, rz)` equals `fromEulerAnglesYXZ`, the order used by the `Orientation` property. `cf:ToOrientation()` and `cf:ToEulerAnglesXYZ()` convert back; `CFrame.fromEulerAngles(rx, ry, rz, order)` takes an `Enum.RotationOrder`.

Euler angles have gimbal lock and multiple representations; extracting angles, modifying one and rebuilding often produces flips near +/-90 degrees pitch. Prefer composing rotations (`*`) and axis-angle, and keep your own scalar yaw/pitch state for cameras rather than reading them back from a CFrame ([[Camera Systems]]).

`cf:AngleBetween(other)` gives the rotation difference in radians, 0..pi (Docs); use it for "is this close enough" checks on orientation.

### Interpolation and smoothing

```lua
local mid = a:Lerp(b, 0.5)   -- position lerp + rotation slerp

-- Frame-rate independent exponential smoothing: same feel at 30 and 240 FPS
local SHARPNESS = 12
RunService.PreRender:Connect(function(dt: number)
	local alpha = 1 - math.exp(-SHARPNESS * dt)
	current = current:Lerp(target, alpha)
end)
```

`current:Lerp(target, 0.1)` every frame is the classic bug: it converges faster at high frame rates. Always derive `alpha` from `dt`. Springs give more control ([[Springs Damping and Smoothing]]).

Repeated multiplication accumulates rounding error until the rotation is no longer orthonormal (skew, scaling). Call `cf:Orthonormalize()` occasionally on CFrames you update incrementally every frame, or rebuild from scalar state.

---

## 5. Common recipes

```lua
-- Yaw-only facing: turn a character toward a point without tilting
local function faceFlat(root: BasePart, target: Vector3)
	local pos = root.Position
	local flatTarget = Vector3.new(target.X, pos.Y, target.Z)
	if (flatTarget - pos).Magnitude > 1e-3 then
		root.CFrame = CFrame.lookAt(pos, flatTarget)
	end
end

-- Signed yaw angle (degrees) from forward to a target, for "left or right?"
local function signedYaw(cf: CFrame, target: Vector3): number
	local localDir = cf:PointToObjectSpace(target)
	return math.deg(math.atan2(-localDir.X, -localDir.Z))   -- 0 ahead, + left, - right
end

-- Align an object's up vector to a surface normal, keeping its facing as close as possible
local function alignToNormal(cf: CFrame, normal: Vector3): CFrame
	local rot = CFrame.fromRotationBetweenVectors(cf.UpVector, normal)
	return CFrame.new(cf.Position) * rot * cf.Rotation
end

-- Pivot whole models, never set each part
model:PivotTo(CFrame.new(0, 10, 0) * CFrame.Angles(0, math.pi, 0))
```

---

## 6. Large coordinates

Positions are stored as 32-bit floats in the engine (rule of thumb). Far from the origin (tens of thousands of studs), precision degrades: physics jitter, animated parts shimmer, and small offsets snap. Keep active play areas within a few thousand studs of the origin where you can, and do not build maps that require 100,000-stud distances. Luau numbers are doubles, but once written into a CFrame they lose that precision.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Part disappears / huge coordinates | NaN from `.Unit` of zero or divide by zero | Guard magnitude; validate inputs |
| Rotation off by a lot | Degrees passed where radians expected | `math.rad` |
| Object spins around the wrong axis | Multiplication order (local vs world) | `cf * rot` local; rebuild for world |
| Smoothing speed changes with FPS | Constant lerp alpha | `1 - exp(-k * dt)` |
| Camera flips at straight up/down | `lookAt` up vector parallel to direction; Euler gimbal lock | Alternative up; scalar yaw/pitch state |
| Noise is flat | `math.noise` at integer inputs | Fractional, scaled inputs |
| Same loot sequence affects other systems | Shared `math.random` | `Random` per system |
| `x == 0.3` false | Float precision | Tolerances, `FuzzyEq` |

## Checklist

- [ ] Angles in radians in code; degrees only at the UI/config boundary.
- [ ] Every normalization guards against zero length.
- [ ] Per-frame smoothing uses `dt`.
- [ ] Models moved with `PivotTo`.
- [ ] Randomness through `Random` objects with documented seeds where reproducibility matters.
- [ ] Float comparisons use tolerances.

## See also

[[Motor6D Math and CFrame Composition]] · [[Springs Damping and Smoothing]] · [[Tween and CFrame Animation of Objects]] · [[Two-Bone IK Math]] · [[Camera Systems]] · [[Raycasts Shapecasts and Spatial Queries]] · [[RNG Drops and Luck Systems]] · [[Luau Performance and Native Codegen]] · [[Buffers and Binary Data]]

## Nuances and edge cases

1. **Two precisions live side by side.** Luau numbers are 64-bit doubles, but `Vector3` and `CFrame` components are stored as 32-bit floats (rule of thumb; widely documented by the community, not confirmed on the reference page). A value that is exact in a local variable can lose digits the moment you put it in a vector. Float32 keeps about 7 significant digits, so at 10,000 studs from the origin the smallest step is roughly a thousandth of a stud, and at 100,000 studs it is closer to a hundredth (rule of thumb from float32 math). Accumulate in doubles (plain numbers) and build the vector at the end when precision matters, for example a long-running orbit angle or a distance odometer.
2. **Rotation orders differ between APIs.** `CFrame.Angles(rx, ry, rz)` is the same as `CFrame.fromEulerAnglesXYZ`, while `BasePart.Orientation` and `CFrame.fromOrientation` use the YXZ order (rule of thumb; the CFrame reference page names the XYZ order for `fromEulerAnglesXYZ` but does not spell out the order for `Angles` or `fromOrientation`). Copying three numbers from the Properties panel into `CFrame.Angles` gives the wrong pose whenever more than one axis is non-zero. Use `CFrame.fromOrientation(math.rad(x), math.rad(y), math.rad(z))` when the numbers came from `Orientation`.
3. **Repeated multiplication drifts.** Multiplying a CFrame by a small rotation every frame for minutes slowly breaks orthonormality: the axes stop being exactly perpendicular and the part shears or scales slightly. `CFrame:Orthonormalize()` repairs it (Roblox docs, as of October 2026: the method exists and returns a new CFrame). Better still, store the angle as a number and rebuild the CFrame each frame from that number.
4. **Lerp is not always the shortest rotation you expect.** `CFrame:Lerp` interpolates rotation along the shortest arc, which is usually right, but for a rotation of almost exactly 180 degrees the "shortest" direction is ambiguous and can flip between frames. For door swings, turrets and anything that must turn a known way, interpolate an angle number and build the CFrame, instead of lerping between two CFrames.
5. **Frame-rate independence has two halves.** The existing note covers `1 - exp(-k * dt)`. The second half is the `dt` source: `RunService.PreRender` gives a render delta on the client, `Heartbeat` gives a simulation delta. A client at 240 FPS and a phone at 30 FPS both converge at the same speed only if you use the delta of the event you are in. On the server there is no render step at all, so server-side smoothing should live on `Heartbeat`.
6. **Scale changes what "far" means.** With one player, computing a distance from every NPC to every player is free. With 50 players and 300 NPCs it is 15,000 distance checks a frame, which is fine in Luau if you compare squared magnitudes (`(a - b):Dot(a - b)` against `r * r`) and avoid `Magnitude` square roots. With 700 players in one server you need spatial partitioning (a grid keyed by `math.floor(pos / cellSize)`), not faster math.
7. **Server and client see different numbers.** A position replicated from the server to the client is not bit-identical by the time physics, interpolation and network ownership have touched it. Never use exact equality between a client-computed and a server-computed vector for validation; use a tolerance that grows with ping (see [[Server Authority and Validation]]).
8. **Randomness and determinism.** `Random.new(seed)` gives a repeatable sequence on one machine. Teams commonly rely on the same seed producing the same sequence on server and client; that is standard practice, but the exact generator is an engine detail, so treat cross-version determinism as unverified and send results rather than seeds for anything that affects rewards.
9. **NaN spreads silently.** One `NaN` component makes a CFrame invalid; setting it on a part can make the part vanish or fling. NaN is the only value where `x ~= x`, so a cheap guard `if v.X ~= v.X then return end` before writing to a part catches it. Common sources: `.Unit` of a zero vector, `math.acos` of a dot product slightly above 1 after float error (clamp to `[-1, 1]` first).

The senior trade-off is readability against cost: CFrame composition reads well and is fast enough for hundreds of objects. Only drop to component math (or the native `vector` type in hot loops, see [[Luau Performance and Native Codegen]]) after the MicroProfiler shows math is the cost.

## Common mistakes (advanced)

1. **Using `Orientation` numbers with `CFrame.Angles`.** Symptom: an object placed from script looks twisted compared to the hand-placed one. Fix: `CFrame.fromOrientation` with radians.
2. **Clamping after `acos`, not before.** Symptom: rare NaN angles, objects disappearing once in a few thousand frames. Fix: `math.acos(math.clamp(dot, -1, 1))`.
3. **Comparing `Magnitude` in hot loops.** Symptom: AI or proximity code shows up as a wide bar in the MicroProfiler. Fix: compare squared distances, cache positions once per frame.
4. **Building a world thousands of studs from the origin.** Symptom: jittering characters, shaking cameras, physics contacts that misbehave at the far end of a long map. Fix: keep play areas within a few thousand studs of the origin; for very large worlds, split into places or shift content (see [[Infinite and Streamed Worlds]]).
5. **Rotating with `CFrame.new(pos) * CFrame.Angles(...)` when you meant world axes.** Symptom: a part spins around its own tilted axis instead of the world up axis. Fix: put the world rotation on the left of the existing rotation: `CFrame.new(cf.Position) * CFrame.Angles(0, a, 0) * cf.Rotation`.
6. **Seeding `Random` with `os.time()` in many servers started in the same second.** Symptom: two servers roll identical events. Fix: mix in `game.JobId` characters or use `Random.new()` with no argument.

## Related decisions

- [[Rotations Angles and Quaternions]]: the deeper theory behind rotation order and why lerping angles beats lerping matrices for some cases.
- [[Dot and Cross Products in Gameplay]]: facing checks, cone tests and side tests that build on the vector recipes here.
- [[Interpolation Easing and Curves Math]]: easing curves to feed into the lerp alpha instead of linear motion.
- [[Big Numbers Precision and Formatting]]: the same double versus float32 precision question, applied to currency.
- [[Springs Damping and Smoothing]]: when exponential smoothing is not enough and you need overshoot.
- [[Motor6D Math and CFrame Composition]]: CFrame multiplication order as it applies to joints.
- [[Seeds Determinism and Reproducible Worlds]]: what you can and cannot rely on from seeded randomness.
- [[Hitboxes and Hit Detection]]: tolerance-based checks that must not use exact vector equality.
- [[Infinite and Streamed Worlds]]: the large-coordinate problem from the world-building side.

## Connected notes
<!-- auto-links:start -->
[[Cookbook - Math CFrame and Vectors]] · [[Game Math Start Here]] · [[Look-At Aim and Head Tracking]] · [[Snippets - Building and Sampling Clips]] · [[Deterministic Simulation]] · [[Procedural Generation Start Here]]
<!-- auto-links:end -->
