---
tags: [math, game-math, curves, bezier, catmull-rom, splines, beams, path2d, rails, cables, projectiles, ui, luau]
---
# Curves in Luau - Paths Beams and Motion

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Uniform Catmull-Rom on uneven points -> Centripetal (`ALPHA = 0.5`)
> - Avoid: One piece per `t` step -> `sampleEven` by arc length
> - Avoid: `CFrame.lookAt` with world up on a 3D track -> Rotation-minimising up vectors
> - Designer paths use centripetal Catmull-Rom converted to Bezier segments.
> - Anything placed along a path is spaced by arc length.
> - Orientations along 3D paths come from rotation-minimising frames, banking added on purpose.
>
> Cost: TL;DR ~160 tok · whole note ~5.4k tok. Read more: ## 2. Centripetal Catmull-Rom, as Bezier segments · ## 5. Beams are cubic Beziers: driving them from paths · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Interpolation Easing and Curves Math]] already gives the basic Luau building blocks: a cubic Bezier with its tangent, uniform Catmull-Rom, an arc-length table for constant speed, and Hermite retargeting. This note is what you build on top of them: a centripetal Catmull-Rom path that converts straight into Roblox `Beam` segments, rails and fences laid out with evenly spaced pieces that never flip upside down, a hanging cable as a single Beam, a beam that draws itself along its own curve, curved projectile paths the server can check, and the UI side through `Path2D`. The modelling theory behind all of it (handles, continuity, curvature) is in [[Bezier Curves and Splines for Modellers]].

Trust labels: **Roblox docs** (create.roblox.com, October 2026), **API dump** (robloxapi.github.io reference generated from the engine), **Derived** (worked out in this note; the algebra is shown), **Rule of thumb**, **Unverified**. The Luau snippets were written for this note and checked against the same maths that `lihfolk_curves.py` tests in Blender; they have not been run in a live Studio session, so test them in your place before shipping.

---

## 1. Which curve for which job

| Job | Curve | Why |
|---|---|---|
| Designer places points, path must pass through them (rails, patrol routes, camera rails, races) | Centripetal Catmull-Rom | Through every point; no loops or cusps inside a segment |
| A single shaped arc between two known ends (homing missile, collectible flying to the HUD, a slash) | Cubic Bezier | Two handles give full control of the bend |
| A shape that must look smooth more than hit exact points (decorative swoops, tentacle motion) | Uniform cubic B-spline | Curvature continuous, so no visible "corners" in motion or shading |
| Motion that must start with the current velocity | Hermite | See the retargeting section of [[Interpolation Easing and Curves Math]] |
| UI element following a drawn path | `Path2D` | Native, editable in Studio, has arc-length sampling |
| Visible curved ribbon in the world | `Beam` | The engine draws a cubic Bezier for you |

---

## 2. Centripetal Catmull-Rom, as Bezier segments

The uniform Catmull-Rom in the interpolation note overshoots and can loop when points are unevenly spaced. Centripetal parameterisation (knot spacing by the square root of the distance between points) is proven free of cusps and self-intersections within each segment (Source: Yuksel, Schaefer and Keyser 2011). Converting each segment to a cubic Bezier is the most useful form in Roblox: Bezier segments evaluate cheaply, split exactly, bound easily, and map directly onto Beams.

For a segment from `b` to `c` with neighbours `a` and `d`, and knot intervals `d0, d1, d2` (distances raised to `alpha`), the tangent at `b` with respect to the curve's own parameter is `(b - a)/d0 - (c - a)/(d0 + d1) + (c - b)/d1`. Multiplying by `d1` rescales it to the segment's 0-to-1 parameter, and a Bezier handle is one third of that (Derived; with `alpha = 0` it reduces to the familiar `(c - a) / 6`).

```lua
--!strict
export type Seg = { p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3 }

local ALPHA = 0.5 -- 0 uniform, 0.5 centripetal (recommended), 1 chordal

local function knot(a: Vector3, b: Vector3): number
	return math.max((b - a).Magnitude, 1e-4) ^ ALPHA
end

local function tangentAt(a: Vector3, b: Vector3, c: Vector3, dPrev: number, dNext: number): Vector3
	return (b - a) / dPrev - (c - a) / (dPrev + dNext) + (c - b) / dNext
end

-- Points the path must pass through -> one cubic Bezier per gap.
local function catmullToBezier(points: { Vector3 }): { Seg }
	local n = #points
	assert(n >= 2, "need at least two points")
	local pts = table.clone(points)
	table.insert(pts, 1, 2 * points[1] - points[2]) -- mirrored phantom ends
	table.insert(pts, 2 * points[n] - points[n - 1])
	local segs: { Seg } = {}
	for i = 2, n do -- segment from pts[i] to pts[i + 1]
		local a, b, c, d = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
		local d0, d1, d2 = knot(a, b), knot(b, c), knot(c, d)
		local m1 = tangentAt(a, b, c, d0, d1) * d1
		local m2 = tangentAt(b, c, d, d1, d2) * d1
		table.insert(segs, { p0 = b, p1 = b + m1 / 3, p2 = c - m2 / 3, p3 = c })
	end
	return segs
end

local function bez(s: Seg, t: number): Vector3
	local u = 1 - t
	return s.p0 * (u * u * u) + s.p1 * (3 * u * u * t) + s.p2 * (3 * u * t * t) + s.p3 * (t * t * t)
end
```

Two properties you get for free (Derived from the formula): consecutive segments share the same tangent direction at the shared point, so the path is smooth there; and the handle lengths on each side differ when the gaps differ, so speed along `t` changes at the point. That is why constant-speed motion needs the arc-length step below. Catmull-Rom is smooth in direction but not in curvature (it is C1), so very uneven point spacing can still show a visible change of bend at a point; add points to even it out.

---

## 3. Even spacing along a path

Fences, rail sleepers, lamp posts, coins on a track and stepping stones all need one piece every N studs along the curve, not one per `t` step. Sample densely, then walk the polyline:

```lua
--!strict
-- Points every `spacing` studs along a chain of Bezier segments.
local function sampleEven(segs: { Seg }, spacing: number, perSeg: number?): { Vector3 }
	local steps = perSeg or 32
	local dense: { Vector3 } = { segs[1].p0 }
	for _, s in segs do
		for k = 1, steps do
			table.insert(dense, bez(s, k / steps))
		end
	end
	local out = { dense[1] }
	local carry = 0 -- distance walked since the last emitted point
	for i = 2, #dense do
		local a, b = dense[i - 1], dense[i]
		local len = (b - a).Magnitude
		local walked = 0
		while carry + (len - walked) >= spacing do
			walked += spacing - carry
			table.insert(out, a:Lerp(b, walked / len))
			carry = 0
		end
		carry += len - walked
	end
	return out
end
```

32 samples per segment is plenty for placement; error is far below a stud on normal tracks (rule of thumb). Build once when the track loads. For moving along a path at constant speed, use the arc-length table from [[Interpolation Easing and Curves Math]] instead, which maps distance to `t` directly.

---

## 4. Frames that never flip: rails, roads, coasters, cables

Placing a sleeper or a road tile needs a full orientation, not just a position. The common shortcut `CFrame.lookAt(pos, pos + tangent)` uses world up and breaks in two ways: it spins wildly when the path goes vertical (a loop), and it banks nothing on corners. The Frenet frame (built from the curve's bend) is no better: it flips sideways wherever the curve straightens.

Rotation-minimising frames carry an "up" vector along the path with no unnecessary roll. The double-reflection method computes each frame from the previous one with two mirror reflections and is accurate and cheap (Source: Wang, Juttler, Zheng and Liu 2008).

```lua
--!strict
-- Rotation-minimising up vectors along sampled points (double reflection).
local function rmfUps(points: { Vector3 }, tangents: { Vector3 }, up0: Vector3): { Vector3 }
	local t0 = tangents[1]
	local r = (up0 - t0 * up0:Dot(t0)).Unit
	local ups = { r }
	for i = 1, #points - 1 do
		local v1 = points[i + 1] - points[i]
		local c1 = v1:Dot(v1)
		if c1 < 1e-12 then
			table.insert(ups, r)
			continue
		end
		local rL = r - v1 * (2 / c1 * v1:Dot(r))
		local tL = tangents[i] - v1 * (2 / c1 * v1:Dot(tangents[i]))
		local v2 = tangents[i + 1] - tL
		local c2 = v2:Dot(v2)
		r = if c2 < 1e-12 then rL else rL - v2 * (2 / c2 * v2:Dot(rL))
		table.insert(ups, r)
	end
	return ups
end

-- Lay sleepers every 2 studs along a designer path.
local function laySleepers(points: { Vector3 }, template: BasePart, parent: Instance)
	local pos = sampleEven(catmullToBezier(points), 2)
	local tans = {}
	for i = 1, #pos do
		local a, b = pos[math.max(i - 1, 1)], pos[math.min(i + 1, #pos)]
		tans[i] = (b - a).Unit
	end
	local ups = rmfUps(pos, tans, Vector3.yAxis)
	for i, p in pos do
		local sleeper = template:Clone()
		sleeper.CFrame = CFrame.lookAt(p, p + tans[i], ups[i]) -- up from the frame, never world up
		sleeper.Parent = parent
	end
end
```

Add banking on top as a deliberate roll angle about the tangent (`CFrame.fromAxisAngle(tangent, bank)`), driven by a designer value or by curvature, rather than letting it fall out of the maths. On a closed loop the frame will not quite meet itself after one lap; spread the leftover roll evenly over the lap so the seam matches. The same frames orient swept meshes in Blender; see [[Curve-Based Modelling in Blender for Roblox]].

---

## 5. Beams are cubic Beziers: driving them from paths

A Beam draws a cubic Bezier between its two attachments: P1 is `CurveSize0` studs along `Attachment0`'s right (X) axis, P2 is `CurveSize1` studs back along `Attachment1`'s right axis (Roblox docs; details in [[Beams and Trails]]). So any Bezier segment becomes a Beam by pointing the attachments along the handles and setting the handle lengths.

### A smooth chain of beams through points

Because each Catmull-Rom point has one tangent direction shared by both neighbouring segments (section 2), one attachment per point serves both beams: it is `Attachment1` of the beam arriving and `Attachment0` of the beam leaving, and the chain is smooth at every joint (Derived).

```lua
--!strict
local function orientRight(att: Attachment, pos: Vector3, dir: Vector3)
	local right = if dir.Magnitude > 1e-6 then dir.Unit else Vector3.xAxis
	local ref = if math.abs(right.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local up = (ref - right * ref:Dot(right)).Unit
	att.WorldCFrame = CFrame.fromMatrix(pos, right, up) -- X axis = curve tangent
end

local function beamsThrough(points: { Vector3 }, holder: BasePart, template: Beam): { Beam }
	local segs = catmullToBezier(points)
	local atts: { Attachment } = {}
	for i = 1, #segs + 1 do
		local a = Instance.new("Attachment")
		a.Parent = holder
		local s = segs[math.min(i, #segs)]
		if i <= #segs then
			orientRight(a, s.p0, s.p1 - s.p0)
		else
			orientRight(a, s.p3, s.p3 - s.p2)
		end
		atts[i] = a
	end
	local beams = {}
	for i, s in segs do
		local b = template:Clone()
		b.Attachment0, b.Attachment1 = atts[i], atts[i + 1]
		b.CurveSize0 = (s.p1 - s.p0).Magnitude
		b.CurveSize1 = (s.p3 - s.p2).Magnitude
		b.Parent = holder
		beams[i] = b
	end
	return beams
end
```

`Attachment.WorldCFrame` is writable in the API reference (no ReadOnly tag; API dump). If a segment has a zero-length handle (two identical points), skip that point rather than feeding a zero vector into the orientation. Ribbon width follows the attachments' orientation unless `FaceCamera` is on; for guide lines and cables, turn `FaceCamera` on so the ribbon never shows its thin edge.

### A hanging cable as one Beam

A power line, a vine or a rope bridge rail between two posts needs a sag, not a physics simulation ([[Ropes Chains and Soft Bodies]]). For a cubic Bezier with both inner points dropped by the same amount `h`, the midpoint drops by `0.75 h` (Derived: the midpoint is `(P0 + 3 P1 + 3 P2 + P3) / 8`). So to sag by `s` studs at the middle, drop the handles by `4/3 s`:

```lua
--!strict
-- Sag `sag` studs at the middle. Handles start one third of the way along, dropped by 4/3 sag.
local function hangCable(beam: Beam, sag: number)
	local a0, a1 = beam.Attachment0 :: Attachment, beam.Attachment1 :: Attachment
	local p0, p3 = a0.WorldPosition, a1.WorldPosition
	local third = (p3 - p0) / 3
	local drop = Vector3.new(0, -4 / 3 * sag, 0)
	local h0 = third + drop -- P1 - P0
	local h1 = third - drop -- P3 - P2
	orientRight(a0, p0, h0)
	orientRight(a1, p3, h1)
	beam.CurveSize0 = h0.Magnitude
	beam.CurveSize1 = h1.Magnitude
end
```

A cubic with equal drops is not a true catenary, but for sags under about a quarter of the span the difference is invisible at game distances (rule of thumb). Animate `sag` with a small sine for wind. Re-orienting attachments also rotates anything else parented to them, so give cables their own attachments.

### A beam that draws itself along its own curve

Splitting a Bezier at `t` gives the exact first part of the curve (de Casteljau). Applying the left half to the beam each frame makes it grow along the final shape instead of stretching: good for lightning that crawls, a lasso being thrown, a tutorial line drawing itself.

```lua
--!strict
local function splitLeft(s: Seg, t: number): Seg
	local a, b, c = s.p0:Lerp(s.p1, t), s.p1:Lerp(s.p2, t), s.p2:Lerp(s.p3, t)
	local d, e = a:Lerp(b, t), b:Lerp(c, t)
	return { p0 = s.p0, p1 = a, p2 = d, p3 = d:Lerp(e, t) }
end

-- Call every frame with t going 0 -> 1. tip is an attachment you move; start stays put.
local function growBeam(beam: Beam, tip: Attachment, full: Seg, t: number)
	local part = splitLeft(full, math.clamp(t, 0.001, 1))
	beam.CurveSize0 = (part.p1 - part.p0).Magnitude
	orientRight(tip, part.p3, part.p3 - part.p2)
	beam.CurveSize1 = (part.p3 - part.p2).Magnitude
end
```

The start attachment's direction does not change during the split (the first handle keeps its direction and only shortens), so only the tip attachment moves (Derived).

### Bounds for free

A Bezier lies inside the box of its four control points. That loose box is a cheap culling or region test for curved effects and paths: skip work for a beam whose control-point box is outside a player's range. For an exact box, solve the derivative for zero per axis; the modeller note shows how.

---

## 6. Projectiles and motion on curves

A curved projectile (a lobbed potion, a homing orb, a boomerang) is a visual path. The rules from [[Projectiles and Ballistics]] still apply:

- **Deterministic.** Server and clients evaluate the same curve from the same points and the same start time (`workspace:GetServerTimeNow()`), so nobody streams positions.
- **Hit-test the segment travelled.** Each step, raycast from the previous sample to the current one. A projectile that moves 6 studs per frame along a curve has to test those 6 studs, not just its new position.
- **The server decides hits.** Clients draw; the server samples the same curve at the same times and validates.

```lua
--!strict
-- Lobbed throw: quadratic arc with the apex `height` studs above the midpoint.
-- A quadratic's middle control point sits 2x the apex height above the chord midpoint (Derived: B(0.5) = (P0 + 2C + P2) / 4).
local function lobPoint(from: Vector3, to: Vector3, height: number, t: number): Vector3
	local c = (from + to) / 2 + Vector3.new(0, 2 * height, 0)
	local u = 1 - t
	return from * (u * u) + c * (2 * u * t) + to * (t * t)
end
```

**TweenService versus a custom curve.** TweenService interpolates a property from its current value to a goal with an easing style (Roblox docs); it cannot follow a path. Two good patterns:

1. **One loop, many movers.** A single `Heartbeat` connection computes `t` from a start timestamp, eases it (`TweenService:GetValue` returns the engine's easing for any alpha; Roblox docs), converts eased distance to a curve point with an arc-length table, and writes CFrames for every mover at once ([[Tween and CFrame Animation of Objects]]).
2. **Ease in distance, not in `t`.** Easing the curve parameter directly mixes the easing with the curve's own uneven speed. Ease the distance travelled, then look it up.

Tweening a `NumberValue` and sampling the curve in its `Changed` event also works for a handful of objects, but costs an instance and a connection each.

---

## 7. UI paths: Path2D

`Path2D` is a UI object that draws a cubic Bezier spline under a `ScreenGui` or `SurfaceGui`; each control point has a position and left and right tangents, mirrored by default, and you edit them in Studio (Roblox docs). The API reference lists `GetPositionOnCurve(t)`, `GetPositionOnCurveArcLength(t)` (returns a `UDim2`), the matching tangent functions, `GetLength`, `GetBoundingRect`, `SetControlPoints`, `InsertControlPoint`, `RemoveControlPoint`, `UpdateControlPoint`, a `Closed` property and a `ControlPointChanged` event (Roblox docs). Control points are `Path2DControlPoint.new(position, leftTangent, rightTangent)` with `UDim2` values (Roblox docs).

The arc-length variants are the ones you want: they space points evenly along the path, which is what makes items spread evenly and motion run at a steady speed (Roblox docs announcement).

```lua
--!strict
-- Spread reward icons evenly along a designer-drawn Path2D, then fly one along it.
local RunService = game:GetService("RunService")

local function spreadAlongPath(path: Path2D, items: { GuiObject })
	for i, item in items do
		item.Position = path:GetPositionOnCurveArcLength(i / (#items + 1))
	end
end

local function flyAlong(path: Path2D, item: GuiObject, duration: number)
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / duration, 0, 1)
		local eased = 1 - (1 - a) * (1 - a) -- quad out
		item.Position = path:GetPositionOnCurveArcLength(math.min(eased, 0.999))
		local tan = path:GetTangentOnCurveArcLength(math.min(eased, 0.999))
		item.Rotation = math.deg(math.atan2(tan.Y, tan.X))
		if a >= 1 then
			conn:Disconnect()
		end
	end)
end
```

The `0.999` clamp is a defensive habit: a developer forum report described `GetPositionOnCurveArcLength(1)` returning a wrong position near the first point (unverified whether it has been fixed; test in your build). Path positions are relative to the path's parent container, so keep the moving item in the same container.

**Path3D.** The API reference lists a `Path3D` class added in engine version 731 (July 2026) with the same family of methods returning `Vector3`, but every member is marked `RobloxScriptSecurity` (API dump). Treat it as unavailable to game scripts until Roblox documents it; build 3D paths with the code above (unverified beyond the dump).

---

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Uniform Catmull-Rom on uneven points | Path loops or overshoots at tight corners | Centripetal (`ALPHA = 0.5`) |
| One piece per `t` step | Fence posts bunch on bends, gap on straights | `sampleEven` by arc length |
| `CFrame.lookAt` with world up on a 3D track | Sleepers spin at loops; road tiles flip | Rotation-minimising up vectors |
| Separate attachments per beam at a joint | Visible kink where beams meet | Share one attachment per point, oriented along the tangent |
| CurveSize set but attachments unrotated | Beam bends the wrong way | The handle direction is the attachment's X axis |
| Sag by moving handles down by `sag` | Cable sags only three quarters as much | Drop handles by `4/3 * sag` |
| Easing the curve parameter | Motion speeds up and slows down oddly | Ease distance, convert with an arc-length table |
| Checking only the projectile's new position | Fast curved shots pass through walls | Raycast each travelled segment |
| `GetPositionOnCurveArcLength(1)` | Item jumps at the end (reported) | Clamp to 0.999, test your build |
| Relying on `Path3D` from game scripts | Permission error | Script-security-only in the API dump; use your own curves |

## Checklist

- [ ] Designer paths use centripetal Catmull-Rom converted to Bezier segments.
- [ ] Anything placed along a path is spaced by arc length.
- [ ] Orientations along 3D paths come from rotation-minimising frames, banking added on purpose.
- [ ] Beam chains share one attachment per point; `FaceCamera` on for lines and cables.
- [ ] Cable sag uses the `4/3` rule; each cable owns its attachments.
- [ ] Curved projectiles are deterministic, raycast per segment, server-validated.
- [ ] UI motion along `Path2D` uses the arc-length methods and clamps `t` below 1.
- [ ] Paths and arc tables are built once at load, not every frame.

## Sources

- Roblox `Path2D` reference: https://create.roblox.com/docs/reference/engine/classes/Path2D
- Roblox 2D paths guide: https://create.roblox.com/docs/ui/2D-paths
- `Path2DControlPoint`: https://create.roblox.com/docs/reference/engine/datatypes/Path2DControlPoint
- Path2D full release announcement: https://devforum.roblox.com/t/path2d-full-release/3027288 ; arc-length bug report: https://devforum.roblox.com/t/2d-path-problem-getpositiononcurvearclength-with-t-1-is-returning-wrong-values/3155772
- `Path3D` in the API dump: https://robloxapi.github.io/ref/class/Path3D.html
- Roblox `Beam` reference: https://create.roblox.com/docs/reference/engine/classes/Beam ; `Attachment`: https://robloxapi.github.io/ref/class/Attachment.html
- Centripetal Catmull-Rom: https://www.sciencedirect.com/science/article/abs/pii/S0010448510001533
- Rotation-minimising frames: https://www.microsoft.com/en-us/research/wp-content/uploads/2016/12/Computation-of-rotation-minimizing-frames.pdf

## See also

[[Interpolation Easing and Curves Math]] · [[Bezier Curves and Splines for Modellers]] · [[Curve-Based Modelling in Blender for Roblox]] · [[Beams and Trails]] · [[Ropes Chains and Soft Bodies]] · [[Projectiles and Ballistics]] · [[Tween and CFrame Animation of Objects]] · [[UI Motion Language and Timing]] · [[Cameras and Cutscenes]] · [[Rotations Angles and Quaternions]] · [[Math Vectors and CFrames]]

## Connected notes
<!-- auto-links:start -->
[[Flight Flocks and Path Animation]] · [[UI and GUI Animation]] · [[Game Math Start Here]] · [[VFX Design Playbook]] · [[Tween vs Spring]] · [[Procedural World Generation]]
<!-- auto-links:end -->
