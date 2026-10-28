---
tags: [math, game-math, interpolation, easing, curves, bezier, splines, tweening, ui, camera, luau]
---
# Interpolation Easing and Curves Math

Interpolation is how a game turns "from here to there" into motion, colour, damage falloff and difficulty ramps. [[Math Vectors and CFrames]] covers `math.lerp`, `math.map`, `CFrame:Lerp` and frame-rate independent exponential smoothing; [[Springs Damping and Smoothing]] covers springs; [[Keyframes, Easing and Interpolation]] covers how the Animator eases between poses, including its measured quirks. This note is the maths underneath and the gameplay uses on top: the three building blocks (lerp, inverse lerp, remap), easing functions as formulas you can reason about, overshoot budgets, envelopes, Bezier and Catmull-Rom curves, constant-speed travel along a curve, retargeting a motion mid-flight without a jolt, and interpolating things that are not plain numbers (angles, colours, scales).

---

## 1. Three building blocks

Every curve in this note is built from three functions.

```lua
--!strict
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Where does x sit between a and b? 0 at a, 1 at b. Not clamped.
local function invLerp(a: number, b: number, x: number): number
	if a == b then
		return 0
	end
	return (x - a) / (b - a)
end

-- Map x from [inA, inB] to [outA, outB], clamped, with an optional shaping curve.
local function remap(x: number, inA: number, inB: number, outA: number, outB: number, shape: ((number) -> number)?): number
	local t = math.clamp(invLerp(inA, inB, x), 0, 1)
	if shape then
		t = shape(t)
	end
	return lerp(outA, outB, t)
end
```

The pattern "inverse lerp to get a normalised `t`, clamp, shape `t`, lerp to the output" covers an enormous range of gameplay. Damage falloff, volume by distance, screen shake by explosion distance, UI bar fill, a difficulty multiplier by wave, a spawn rate by player count, a camera FOV by speed. Writing them all as `remap` calls with a named shape keeps them tunable from one config table ([[Data and Config Pipeline - Spreadsheets to Game]]).

`math.map` exists in current Luau (Roblox docs (as of October 2026)) and does the linear part, but it does not clamp. Unclamped remaps are the source of "damage went negative at long range" and "the bar overflowed its frame" bugs. Clamp unless you specifically want extrapolation.

**Worked example: falloff that designers can read.** A grenade does 100 damage within 4 studs, falling to 10 at 20 studs, nothing beyond:

```lua
local function grenadeDamage(dist: number): number
	if dist > 20 then
		return 0
	end
	return remap(dist, 4, 20, 100, 10, function(t) return t * t end)
end
```

With `t * t` (an ease-in on the falloff), damage stays high for longer and drops near the edge: at 12 studs (halfway) it is `100 - 90 * 0.25 = 77.5`. With linear it would be 55. That one shape choice changes how lethal near misses feel more than any number tweak, and it is visible in a single line.

---

## 2. Easing functions are just shapes of t

An easing function takes `t` in `[0, 1]` and returns a shaped value, with `f(0) = 0` and `f(1) = 1`. Thinking about them as formulas, not names, answers most design questions.

| Family | In (formula) | Out | Character |
|---|---|---|---|
| Linear | `t` | `t` | Mechanical, constant speed |
| Quad | `t^2` | `1 - (1-t)^2` | Gentle; good default for UI |
| Cubic | `t^3` | `1 - (1-t)^3` | Snappier start or stop |
| Quart / Quint | `t^4`, `t^5` | mirrored | Very fast in the middle, long tails |
| Sine | `1 - cos(t * pi/2)` | `sin(t * pi/2)` | Softer than Quad |
| Exponential | `2^(10t - 10)` | `1 - 2^(-10t)` | Almost a snap, long settle |
| Circular | `1 - sqrt(1 - t^2)` | `sqrt(1 - (1-t)^2)` | Hard edge at one end |
| Back | `c3 t^3 - c1 t^2` | `1 + c3 (t-1)^3 + c1 (t-1)^2` | Overshoots (Out) or winds up (In) |

These are the widely used Penner-style forms (rule of thumb; `c1 = 1.70158`, `c3 = c1 + 1`). Roblox exposes the same family names through `Enum.EasingStyle`. Rather than trusting that the engine's constants match the textbook (the Animator section found surprises: [[Keyframes, Easing and Interpolation]]), sample the engine directly. `TweenService:GetValue(alpha, easingStyle, easingDirection)` returns the eased value for any alpha (Roblox docs (as of October 2026)), which gives you three things:

1. **A way to inspect a curve.** Print 11 samples and you know its shape, including any overshoot.
2. **Engine easing for things TweenService cannot tween**: values inside your own data, server-side simulations, attributes, numbers you then format.
3. **One loop for many objects.** Instead of 300 `Tween` instances, a single `Heartbeat` loop computes `t` from elapsed time, calls `GetValue`, and writes CFrames in bulk. That is the pattern used for decorative motion in [[Tween and CFrame Animation of Objects]].

```lua
--!strict
local TweenService = game:GetService("TweenService")

local function sampleEasing(style: Enum.EasingStyle, dir: Enum.EasingDirection)
	local out = {}
	for i = 0, 10 do
		table.insert(out, string.format("%.3f", TweenService:GetValue(i / 10, style, dir)))
	end
	print(style.Name, dir.Name, table.concat(out, " "))
end

sampleEasing(Enum.EasingStyle.Back, Enum.EasingDirection.Out)
```

### Derivatives tell you how it feels

The slope of the easing function is the speed of the motion. That is why:

- **Out curves feel responsive.** Their slope is highest at `t = 0`, so the object moves the instant the player acts. Quad Out starts at twice the average speed; Cubic Out at three times; Exponential Out much higher. Responses to player input (buttons, panels, hits) should almost always ease Out ([[UI Motion Language and Timing]]).
- **In curves feel like wind-ups and departures.** Slope zero at the start: nothing seems to happen for the first part. Good for things leaving the screen, bad for anything the player just triggered, where it reads as input lag. A 0.3 s Quad In panel covers only about 5 percent of its distance in the first 70 ms.
- **InOut curves have zero speed at both ends.** Smooth for cameras and cutscenes, but chaining two InOut moves back to back produces a visible stop in the middle. Chain Out into In, or use a spline (section 5) through all the points.

### Overshoot budgets

Back and Elastic leave the `[0, 1]` range. Back Out with the standard constant peaks at about 1.10 (10 percent overshoot) near 58 percent of the duration: setting the derivative of `1 + c3 u^3 + c1 u^2` (with `u = t - 1`) to zero gives `u = -2 c1 / (3 c3)`, about -0.42, and the value there is about 1.0999. Two consequences:

- **The overshoot scales with the distance travelled.** A panel sliding 600 pixels overshoots by 60; one sliding 20 overshoots by 2. If large moves look sloppy and small ones look fine, this is why. Use a smaller overshoot for long moves or use a spring with a fixed overshoot in studs or pixels.
- **Overshoot can intersect geometry.** In the reference project, a chest lid opened with Back Out to 72 degrees and the full swing range was checked so the lid never dipped into its base (measured in the reference project). Do the same for doors, drawbridges and anything with a hinge near other parts: compute `min` and `max` of the eased value over the curve and test both extremes.

Clamping overshoot away defeats the purpose. Budget it instead.

---

## 3. Envelopes: effects that start, peak and end exactly at zero

Camera shake, FOV kicks, hit-stop flashes, screen tints and rumble are all envelopes: a value that rises, holds and falls. The maths is two easing curves glued at a peak:

```lua
--!strict
-- Attack-hold-release envelope. Returns 0..1. Ends at exactly 0 at attack+hold+release.
local function envelope(t: number, attack: number, hold: number, release: number): number
	if t <= 0 then
		return 0
	elseif t < attack then
		local x = t / attack
		return 1 - (1 - x) * (1 - x)            -- Quad Out: fast rise
	elseif t < attack + hold then
		return 1
	elseif t < attack + hold + release then
		local x = (t - attack - hold) / release
		return (1 - x) * (1 - x)                -- Quad In on the way down: lingers then settles
	end
	return 0
end
```

The reference project ran its gameplay camera effects as timed envelopes of this kind, each ending at exactly 0, summed, then capped per channel: FOV at +12, camera offset at 1.6 studs, roll at 4 degrees. A dash, for example, added 9 FOV over 0.06 s in and 0.25 s out with 2.5 degrees of roll (measured in the reference project). Three lessons from that design:

1. **Ending at exactly zero matters.** Envelopes built from exponential decay never reach zero, and a hundred of them leave a permanent tiny offset that grows as effects stack. Explicit end times also let you delete the effect.
2. **Sum, then cap.** Two explosions should feel stronger than one, ten should not break the camera. Summing then capping (or summing then passing through a soft limiter like `cap * (1 - exp(-sum / cap))`) gives both.
3. **Fast attack, slower release.** Rises of 40 to 80 ms and releases of 150 to 400 ms read as impact (rule of thumb). Symmetric envelopes read as wobble.

For the overall shake language and when to use it, see [[Camera Shake and Camera FX]] and [[Game Feel and Juice]].

---

## 4. Smoothstep and its relatives

`smoothstep(t) = 3t^2 - 2t^3` has zero slope at both ends; `smootherstep(t) = 6t^5 - 15t^4 + 10t^3` also has zero curvature at both ends. Gameplay uses them for blends that must not have a visible kink when they start or stop:

- **Fog, music or lighting blends between zones.** Remap the player's distance across a 20-stud border to `[0, 1]`, smoothstep it, blend the two settings. A linear blend has a visible "edge" where the change starts.
- **Crossfading two looping animations by speed** (walk to run). The weights come from smoothstep of normalised speed, so there is no pop at the threshold ([[Playback, Priorities and Blending]]).
- **Soft UI cutoffs**, like fading nameplates by distance.

Smoothstep is not an easing curve for objects that move under player control: zero slope at the start reads as lag, as with every In curve.

---

## 5. Curves through space: Bezier and Catmull-Rom

### Bezier

A cubic Bezier has four points: start `P0`, two handles `P1` and `P2`, end `P3`. It passes through `P0` and `P3`, not the handles. Evaluate it with nested lerps (De Casteljau), which is numerically stable and easy to read:

```lua
--!strict
local function bezier3(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local a = p0:Lerp(p1, t)
	local b = p1:Lerp(p2, t)
	local c = p2:Lerp(p3, t)
	local d = a:Lerp(b, t)
	local e = b:Lerp(c, t)
	return d:Lerp(e, t)
end

-- Tangent (derivative), for facing along the curve
local function bezier3Tangent(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local u = 1 - t
	return (p1 - p0) * (3 * u * u) + (p2 - p1) * (6 * u * t) + (p3 - p2) * (3 * t * t)
end
```

Gameplay uses: a homing missile's visual path from launcher to target with a sideways handle for a curved arc, a collectible flying from the world into a UI counter, a dash with a curve, a cinematic camera move. The tangent is what you feed into `CFrame.lookAt(pos, pos + tangent)` to face along the path. The tangent is zero if a handle sits exactly on its endpoint, so guard it like any other direction.

**Gameplay vs visual paths.** A Bezier arc is a visual path. If a projectile flies a Bezier and you also want physics-accurate hits, raycast between consecutive samples of the curve as it advances ([[Projectiles and Ballistics]]), and let the server decide hits from the same deterministic curve (same points, same `t` from a shared start time).

### Catmull-Rom: a curve through every point

Designers place points; they want a smooth path **through** all of them (camera rails, patrol routes, minecart tracks, a pet's wander path). Catmull-Rom does that. For the segment between `P1` and `P2`, using neighbours `P0` and `P3`:

```lua
--!strict
local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * (
		(2 * p1)
		+ (p2 - p0) * t
		+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
		+ (3 * p1 - p0 - 3 * p2 + p3) * t3
	)
end

-- Evaluate a whole path of points at global parameter u in [0, #points - 1]
local function catmullPath(points: { Vector3 }, u: number): Vector3
	local n = #points
	local i = math.clamp(math.floor(u), 0, n - 2)    -- segment index, 0-based
	local t = u - i
	local p1 = points[i + 1]
	local p2 = points[i + 2]
	local p0 = points[i] or (2 * p1 - p2)           -- mirror at the ends
	local p3 = points[i + 3] or (2 * p2 - p1)
	return catmullRom(p0, p1, p2, p3, t)
end
```

The uniform version above is simple and fine for evenly spaced points. With uneven spacing (a long straight then a tight corner) it can overshoot and even loop at the corner. The centripetal variant (parameter spacing by the square root of the distance between points) avoids loops and cusps; implement it if designers complain that a rail "wobbles" around tight bends (rule of thumb). The cheap workaround is to place an extra point before and after each tight corner.

---

## 6. Constant speed along a curve

Neither Bezier nor Catmull-Rom moves at constant speed when you step `t` evenly: points bunch up where handles are close and spread out on long stretches. A camera on a rail speeds up and slows down for no visible reason; a minecart crawls through corners. The fix is an arc-length table built once:

```lua
--!strict
type ArcTable = { us: { number }, lengths: { number }, total: number }

-- Sample the curve finely and record cumulative length at each sample.
local function buildArcTable(curve: (number) -> Vector3, uMax: number, samples: number): ArcTable
	local us, lengths = { 0 }, { 0 }
	local prev = curve(0)
	local total = 0
	for i = 1, samples do
		local u = uMax * i / samples
		local p = curve(u)
		total += (p - prev).Magnitude
		table.insert(us, u)
		table.insert(lengths, total)
		prev = p
	end
	return { us = us, lengths = lengths, total = total }
end

-- Distance along the curve -> curve parameter u (binary search, then lerp).
local function uAtDistance(arc: ArcTable, s: number): number
	s = math.clamp(s, 0, arc.total)
	local lo, hi = 1, #arc.lengths
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if arc.lengths[mid] < s then
			lo = mid
		else
			hi = mid
		end
	end
	local l0, l1 = arc.lengths[lo], arc.lengths[hi]
	local f = if l1 > l0 then (s - l0) / (l1 - l0) else 0
	return arc.us[lo] + (arc.us[hi] - arc.us[lo]) * f
end

-- Usage: a cart moving at 30 studs/s along a designer path
-- local arc = buildArcTable(function(u) return catmullPath(points, u) end, #points - 1, 400)
-- distance += 30 * dt
-- cart:PivotTo(CFrame.new(catmullPath(points, uAtDistance(arc, distance))))
```

Sample count is a trade-off: about 20 to 50 samples per segment is accurate to well under a stud for typical rails (rule of thumb). The table is static, so build it once when the path loads, not every frame. Once you have distance as the input, you can also ease along the path in distance (accelerate out of a station, brake into it) without the curve's own uneven parameter fighting you.

---

## 7. Retargeting without a jolt

A tween from A to B is running; halfway through, the target moves to C. Starting a new tween from the current position to C resets speed to the start of the new curve. With Out easing that is a sudden speed jump; with In easing it is a sudden stop. Players see both as a hitch.

Three remedies, in order of effort:

1. **Exponential smoothing toward a moving target.** Already covered in [[Math Vectors and CFrames]]; it has no memory of velocity, so retargets are smooth in position but the speed changes instantly.
2. **A spring or smooth-damp.** Springs carry velocity across retargets, which is exactly what you want for cameras, cursors and followers ([[Springs Damping and Smoothing]]). `TweenService:SmoothDamp(current, target, velocity, smoothTime, maxSpeed?, dt?)` appears in the engine reference and is documented as returning a tuple (Roblox docs (as of October 2026)). The docs page gives no description of its behaviour, so test what it returns in your Studio build before relying on it (unverified beyond the signature).
3. **A cubic Hermite blend that starts with the current velocity.** When the new motion must still arrive at a fixed time (a UI card that must land in 0.25 s), build a Hermite curve from the current position and velocity to the target with zero end velocity:

```lua
--!strict
-- Cubic Hermite from p0 (velocity v0) to p1 (velocity v1) over duration T.
local function hermite(p0: Vector3, v0: Vector3, p1: Vector3, v1: Vector3, T: number, t: number): Vector3
	local s = math.clamp(t / T, 0, 1)
	local s2, s3 = s * s, s * s * s
	local h00 = 2 * s3 - 3 * s2 + 1
	local h10 = s3 - 2 * s2 + s
	local h01 = -2 * s3 + 3 * s2
	local h11 = s3 - s2
	-- Velocities are scaled by T because the basis uses normalised time
	return p0 * h00 + v0 * (T * h10) + p1 * h01 + v1 * (T * h11)
end
```

The current velocity can be estimated from the last two frames' positions divided by `dt`. A large incoming velocity with a short `T` overshoots, which is physically honest; clamp `v0` if that looks wrong.

---

## 8. Interpolating things that are not plain numbers

**Angles.** Lerping 350 degrees to 10 degrees goes the long way, through 180. Interpolate the wrapped difference instead:

```lua
local function lerpAngle(a: number, b: number, t: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi   -- shortest signed difference, in [-pi, pi)
	return a + d * t
end
```

Luau's `%` takes the sign of the divisor, so this works for negative differences too. Full rotations belong in [[Rotations Angles and Quaternions]].

**Colours.** `Color3:Lerp` interpolates the stored components (Roblox docs (as of October 2026)), which are gamma-encoded. Red to green through that space passes through a dark, muddy olive at the midpoint because the encoded values are not proportional to light. Two better options:

- **Through HSV**, for hue sweeps such as a health bar going green to yellow to red: convert with `Color3:ToHSV()`, lerp hue along the shortest way round the wheel (hue wraps at 1), and rebuild with `Color3.fromHSV`.
- **Through approximately linear light**, for blends that should keep brightness: square each component (a rough gamma 2 approximation), lerp, then take the square root.

```lua
local function lerpColorLinear(a: Color3, b: Color3, t: number): Color3
	local function ch(x: number, y: number): number
		return math.sqrt(x * x + (y * y - x * x) * t)
	end
	return Color3.new(ch(a.R, b.R), ch(a.G, b.G), ch(a.B, b.B))
end
```

**Scale-like quantities.** Zoom distance, a value that ranges over several orders of magnitude, sound volume in perceived loudness, a counter going from 1,000 to 1,000,000,000. Linear interpolation spends almost all its time near the large end: a counter animating linearly from 1e3 to 1e9 shows "1.0M" after only 0.1 percent of the time. Interpolate the logarithm instead: `exp(lerp(log(a), log(b), t))`. Zooms then feel even and counters tick through every magnitude ([[Big Numbers Precision and Formatting]]).

**CFrames.** `CFrame:Lerp` interpolates position linearly and rotation along the shortest arc (rule of thumb; the docs page lists only the signature). For two CFrames that differ by a half-turn, the "shortest arc" is ambiguous and the path can flip from one frame to the next as rounding shifts it. Avoid single lerps over turns near 180 degrees; split them into two steps.

---

## 9. Time, not frames

All of the above takes a `t`. Where `t` comes from is the second half of getting interpolation right:

- **Compute `t` from a start timestamp**, `(now - startTime) / duration`, rather than adding `dt` to a counter. Accumulated `dt` drifts and makes two clients disagree; a timestamp is exact and can be shared over the network so every client evaluates the same motion ([[Network Performance]]).
- **Clamp `t` to `[0, 1]`** at the boundary of the curve and fire the "completed" logic once, by edge-detecting the crossing, not by testing `t == 1`.
- **Use the same clock everywhere a timeline is shared.** `workspace:GetServerTimeNow()` on clients approximates the server's clock; a mix of `os.clock()` on one side and server time on the other produces offsets equal to the clock difference ([[Frame Order and RunService Timing]]).
- **Pause by freezing elapsed time**, not by stopping the loop. Store `elapsedAtPause` and resume with `startTime = now - elapsedAtPause`.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Damage negative past max range | Unclamped remap | Clamp `t` before shaping |
| Button press feels laggy | In or InOut easing on a response | Out easing for player-triggered motion |
| Long slides overshoot badly | Back overshoot scales with distance | Smaller overshoot or a spring |
| Lid or door clips into geometry | Overshoot not budgeted | Check min and max of the eased range |
| Camera speeds up and slows on a rail | Even `t` steps on a curve | Arc-length table |
| Rail loops at a tight corner | Uniform Catmull-Rom with uneven spacing | Centripetal variant or extra points |
| Hitch when target changes | Restarting a tween | Spring, smooth-damp or Hermite from current velocity |
| Colour blend goes muddy | Lerp in gamma space | HSV or approximate linear blend |
| Counter stuck at "1.0M" | Linear lerp across magnitudes | Interpolate logarithms |
| Rotation flips mid-lerp | Interpolating near 180 degrees | Split into two steps |
| Effects never quite end | Exponential decay envelopes | Explicit end times, ending at 0 |

## Checklist

- [ ] Every tunable curve is `invLerp, clamp, shape, lerp`, with its shape named in config.
- [ ] Engine easing is sampled with `TweenService:GetValue` before you rely on its exact shape.
- [ ] Out easing for responses, In for exits, InOut only for unchained moves.
- [ ] Overshoot is computed and checked against nearby geometry.
- [ ] Envelopes end at exactly zero, are summed, then capped.
- [ ] Constant-speed motion along curves uses an arc-length table built once.
- [ ] Retargets keep velocity (spring, smooth-damp or Hermite).
- [ ] Angles, colours and magnitudes use the matching interpolation space.
- [ ] `t` is computed from a shared start time, never accumulated.

## See also

[[Game Math Start Here]] · [[Math Vectors and CFrames]] · [[Springs Damping and Smoothing]] · [[Keyframes, Easing and Interpolation]] · [[Tween and CFrame Animation of Objects]] · [[UI Motion Language and Timing]] · [[UI and GUI Animation]] · [[Camera Shake and Camera FX]] · [[Cameras and Cutscenes]] · [[Game Feel and Juice]] · [[Rotations Angles and Quaternions]] · [[Big Numbers Precision and Formatting]]

## Connected notes
<!-- auto-links:start -->
[[Easing]] · [[Tween vs Spring]] · [[CurveAnimation and Curve Channels]] · [[Flight Flocks and Path Animation]] · [[Cookbook - Math CFrame and Vectors]] · [[Timing Spacing and Frame Charts]]
<!-- auto-links:end -->
