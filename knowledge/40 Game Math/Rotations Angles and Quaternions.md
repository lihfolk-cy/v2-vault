---
tags: [math, game-math, rotations, quaternions, euler-angles, cframe, turrets, networking, luau]
---
# Rotations Angles and Quaternions

<!-- tldr:start -->
> [!tldr] TL;DR
> - Turret spins the long way round: Raw difference of angles -> `deltaAngle` with wrapping
> - Turret flickers between limits: Target on the wrap boundary -> Hysteresis at limits
> - Camera flips looking straight up: Pitch reaching 90 degrees, readback from CFrame -> Scalar yaw and pitch, clamp under 90
> - Angles stored as scalars are wrapped on write; differences use `deltaAngle`.
> - Camera state is scalar yaw and pitch; pitch is clamped below 90 degrees.
> - Rate-limited turning uses axis-angle with the correct world or local order.
>
> Cost: TL;DR ~180 tok · whole note ~6.0k tok. Read more: ## 6. A small quaternion toolkit in Luau · ## 9. Compressing rotations for the network and for saves · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Rotations cause more confusing bugs than any other part of game maths: turrets that spin the long way round, cameras that flip at the top of a look, held items that drift and skew, thrown objects that tumble wrong, and animations that interpolate through an impossible pose. [[Math Vectors and CFrames]] covers building rotations (`CFrame.Angles`, `fromAxisAngle`, `lookAt`), Euler orders, composition order and `Orthonormalize`. [[Motor6D Math and CFrame Composition]] covers joints. This note goes deeper into the representations themselves and the gameplay jobs that need them: wrapping and limiting angles, turning at a fixed rate in 3D, splitting a rotation into swing and twist for turret and head limits, angular velocity for throws, averaging orientations, quaternion maths you can run in Luau, and compressing rotations for the network.

Conventions: Roblox is right-handed and Y up, `LookVector` is negative Z, and angles in code are radians (Roblox docs (as of October 2026)). A positive rotation about +Y turns the forward vector toward -X, which is to the player's left; a positive rotation about +X tips the forward vector upward. The reference project documented the same convention for body poses: positive X rotation leans back, positive Y rotation turns left (measured in the reference project).

---

## 1. Four representations and what each is good at

| Representation | Stored as | Good for | Bad at |
|---|---|---|---|
| Euler angles | 3 numbers + an order | Designer input, UI, one-axis state (yaw, pitch) | Interpolation, composition, anything near 90 degree pitch |
| Axis-angle / rotation vector | Unit axis + angle (or axis times angle) | Angular velocity, "turn by N degrees about X", small deltas | Composing several rotations |
| Rotation matrix | 3 orthonormal axes (what a `CFrame` holds) | Transforming points, composition, extracting axes | Interpolation, storage (9 numbers), drift |
| Quaternion | 4 numbers `(x, y, z, w)` | Interpolation, averaging, compact storage, networking | Human readability |

You rarely need to pick only one. A camera keeps **Euler** yaw and pitch as its state, builds a **matrix** (`CFrame`) each frame to render, and nothing else. A turret takes a **matrix** target from `lookAt`, converts to **axis-angle** to limit its turn rate, and applies the result as a matrix. A replay system stores **quaternions** and interpolates them. The skill is converting at the boundaries and not doing the wrong operation in the wrong form.

### Converting between them in Roblox

- Euler to matrix: `CFrame.Angles` (XYZ order), `CFrame.fromOrientation` (YXZ, the `Orientation` property's order), `CFrame.fromEulerAngles(rx, ry, rz, order)`.
- Matrix to Euler: `cf:ToEulerAnglesXYZ()`, `cf:ToOrientation()`, `cf:ToEulerAngles(order)`.
- Axis-angle to matrix: `CFrame.fromAxisAngle(axis, angle)`; back with `cf:ToAxisAngle()`, which returns a `Vector3` axis and a number angle.
- Quaternion to matrix: `CFrame.new(x, y, z, qX, qY, qZ, qW)` (Roblox docs (as of October 2026)). There is no built-in getter for a quaternion, so the conversion back is section 6.

---

## 2. Angles as numbers: wrapping and limits

Any system that stores an angle as a single number (camera yaw, a turret's heading, a steering wheel, a compass UI) needs two helpers:

```lua
--!strict
local TAU = 2 * math.pi

-- Wrap any angle to [-pi, pi)
local function wrapAngle(a: number): number
	return (a + math.pi) % TAU - math.pi
end

-- Shortest signed difference from a to b, in [-pi, pi)
local function deltaAngle(a: number, b: number): number
	return wrapAngle(b - a)
end

-- Move angle a toward b by at most maxStep, the short way round
local function moveTowardAngle(a: number, b: number, maxStep: number): number
	local d = deltaAngle(a, b)
	if math.abs(d) <= maxStep then
		return b
	end
	return a + math.sign(d) * maxStep
end
```

**Accumulated yaw grows without bound.** A camera that adds mouse delta to yaw forever reaches large values after hours of spinning. That is harmless for doubles in Luau, but if you ever store or replicate it as a smaller number type, or compare it with a wrapped angle, it breaks. Wrap on write.

**Limits on wrapped angles are not a simple clamp.** A turret allowed to aim from -60 to +60 degrees relative to its base handles a target at 170 degrees by clamping to +60. A target at -170 degrees clamps to -60. A target at exactly 180 degrees sits on the wrap boundary and can flick between the two limits on alternate frames as rounding moves it either side. Add hysteresis: once the turret is pinned at one limit, keep it there until the target comes back inside the arc.

**Camera pitch.** Clamp pitch inside plus or minus 80 to 89 degrees (rule of thumb), never to exactly 90. At 90 degrees the look direction is parallel to world up, `lookAt` is undefined, and Euler yaw and roll collapse onto the same axis (gimbal lock). Keeping yaw and pitch as separate scalars and building the CFrame as `CFrame.fromOrientation(pitch, yaw, 0)` (or `CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)`) avoids every flip a CFrame-readback camera suffers ([[Camera Systems]]).

---

## 3. Turning at a fixed rate in 3D

A homing missile, a flying NPC or a ship turret needs to rotate from its current orientation toward a target orientation at no more than N degrees per second, through the shortest rotation, in any axis. Axis-angle does it directly:

```lua
--!strict
-- Rotate `current` toward `target` by at most maxRadians, keeping current's position.
local function rotateToward(current: CFrame, target: CFrame, maxRadians: number): CFrame
	-- World-space rotation that takes current's orientation to target's
	local delta = target.Rotation * current.Rotation:Inverse()
	local axis, angle = delta:ToAxisAngle()
	if angle > math.pi then
		-- Normalise to the short way round, in case the angle comes back above pi
		angle = 2 * math.pi - angle
		axis = -axis
	end
	if angle <= maxRadians or angle < 1e-6 then
		return CFrame.new(current.Position) * target.Rotation
	end
	local step = CFrame.fromAxisAngle(axis, maxRadians)
	return CFrame.new(current.Position) * step * current.Rotation
end

-- Per frame: missile.CFrame = rotateToward(missile.CFrame, CFrame.lookAt(pos, targetPos), math.rad(180) * dt)
```

The order matters. `target * current:Inverse()` is the rotation expressed in **world** space, so it is applied on the left (`step * current`). The local-space version is `current:Inverse() * target`, applied on the right (`current * step`). Mixing them (world delta applied on the right) turns about the wrong axis, which looks like a corkscrew.

Gameplay notes:

- **Turn rate and speed define a turning circle** of radius `speed / turnRate` (turn rate in radians per second). A missile at 120 studs per second turning 180 degrees per second has a radius of about 38 studs: it cannot hit a target that steps 20 studs sideways at close range. That is often what you want (dodgeable missiles); tune rate and speed together, not separately.
- **Roll is free in this function.** Rotating toward a `lookAt` target also corrects roll toward world up. For aircraft that should bank, build the target with an up vector tilted by turn amount ([[Aircraft and Flight Models]]).
- **Physics bodies.** For unanchored assemblies, rotate with an `AlignOrientation` constraint and let its `MaxAngularVelocity` do the limiting, rather than setting CFrames every frame ([[Mover Constraints and Physics Controllers]]).

---

## 4. Angular velocity from two orientations

Throwing a held object so it keeps spinning the way the hand was turning, matching a moving platform's spin, or measuring whether a player's camera is turning faster than any human can (an aimbot signal) all need angular velocity from two orientations a frame apart:

```lua
--!strict
-- World-space angular velocity (radians per second) taking `a` to `b` over dt.
local function angularVelocity(a: CFrame, b: CFrame, dt: number): Vector3
	if dt <= 0 then
		return Vector3.zero
	end
	local delta = b.Rotation * a.Rotation:Inverse()
	local axis, angle = delta:ToAxisAngle()
	if angle > math.pi then
		angle -= 2 * math.pi
	end
	if math.abs(angle) < 1e-7 then
		return Vector3.zero
	end
	return axis * (angle / dt)
end

-- On release: part.AssemblyAngularVelocity = angularVelocity(prevHandCF, handCF, dt)
```

`AssemblyAngularVelocity` is in world space, radians per second, which matches this function. Averaging the last three or four frames removes the noise of a single frame. One subtlety: if the object rotates more than 180 degrees between samples (a very fast spin, or a long frame), the shortest-path delta reverses direction and the object spins the wrong way. Sample at the physics rate, or cap the spin speed you believe.

For the aimbot use, see [[Detecting Combat Exploits - Reach Rate and Aim]]: snap rates are a signal, not proof, because mouse users can legitimately flick very fast.

---

## 5. Swing and twist: limits for turrets, heads and held items

Many limits are about **one axis** of a rotation, not the whole thing. A tank turret yaws freely about its mount but has limited pitch. A head can turn 70 degrees left or right but only tilt 40. A held sword may swing anywhere but must not roll in the hand. Euler angles seem to fit, until the mount itself is tilted (a turret on a vehicle on a slope) and the angles mix.

The clean tool is the **swing-twist decomposition**: any rotation `q` splits into a twist about a chosen axis `d` and a swing perpendicular to it, `q = swing * twist`. You then limit each part separately. It is easiest with quaternions, so first a minimal quaternion toolkit.

---

## 6. A small quaternion toolkit in Luau

A unit quaternion `(x, y, z, w)` represents a rotation by angle `theta` about unit axis `u` as `(u * sin(theta/2), cos(theta/2))`. Two facts drive everything below:

- **Double cover.** `q` and `-q` are the same rotation. Interpolation and averaging must first make the two quaternions point into the same half (dot product non-negative), or they go the long way round.
- **Multiplication composes** like CFrames: `a * b` applies `b` then `a` (Hamilton convention, matching CFrame order).

```lua
--!strict
export type Quat = { x: number, y: number, z: number, w: number }

local Quat = {}

function Quat.fromCFrame(cf: CFrame): Quat
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local trace = r00 + r11 + r22
	if trace > 0 then
		local s = math.sqrt(trace + 1) * 2
		return { w = 0.25 * s, x = (r21 - r12) / s, y = (r02 - r20) / s, z = (r10 - r01) / s }
	elseif r00 > r11 and r00 > r22 then
		local s = math.sqrt(1 + r00 - r11 - r22) * 2
		return { w = (r21 - r12) / s, x = 0.25 * s, y = (r01 + r10) / s, z = (r02 + r20) / s }
	elseif r11 > r22 then
		local s = math.sqrt(1 + r11 - r00 - r22) * 2
		return { w = (r02 - r20) / s, x = (r01 + r10) / s, y = 0.25 * s, z = (r12 + r21) / s }
	else
		local s = math.sqrt(1 + r22 - r00 - r11) * 2
		return { w = (r10 - r01) / s, x = (r02 + r20) / s, y = (r12 + r21) / s, z = 0.25 * s }
	end
end

function Quat.toCFrame(q: Quat, pos: Vector3?): CFrame
	local p = pos or Vector3.zero
	return CFrame.new(p.X, p.Y, p.Z, q.x, q.y, q.z, q.w)
end

function Quat.mul(a: Quat, b: Quat): Quat
	return {
		w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
		x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
		y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
		z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
	}
end

function Quat.conj(q: Quat): Quat
	return { x = -q.x, y = -q.y, z = -q.z, w = q.w }
end

function Quat.dot(a: Quat, b: Quat): number
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
end

function Quat.normalize(q: Quat): Quat
	local m = math.sqrt(Quat.dot(q, q))
	if m < 1e-12 then
		return { x = 0, y = 0, z = 0, w = 1 }
	end
	return { x = q.x / m, y = q.y / m, z = q.z / m, w = q.w / m }
end

-- Normalised linear interpolation along the short path. Cheap; speed varies slightly.
function Quat.nlerp(a: Quat, b: Quat, t: number): Quat
	local s = if Quat.dot(a, b) < 0 then -1 else 1
	return Quat.normalize({
		x = a.x + (s * b.x - a.x) * t,
		y = a.y + (s * b.y - a.y) * t,
		z = a.z + (s * b.z - a.z) * t,
		w = a.w + (s * b.w - a.w) * t,
	})
end

-- Spherical interpolation: constant angular speed along the short path.
function Quat.slerp(a: Quat, b: Quat, t: number): Quat
	local d = Quat.dot(a, b)
	local bx, by, bz, bw = b.x, b.y, b.z, b.w
	if d < 0 then
		d, bx, by, bz, bw = -d, -bx, -by, -bz, -bw
	end
	if d > 0.9995 then
		return Quat.nlerp(a, { x = bx, y = by, z = bz, w = bw }, t)
	end
	local theta0 = math.acos(math.clamp(d, -1, 1))
	local theta = theta0 * t
	-- c = b minus its component along a, normalised: orthogonal to a in 4D
	local c = Quat.normalize({ x = bx - a.x * d, y = by - a.y * d, z = bz - a.z * d, w = bw - a.w * d })
	local cs, sn = math.cos(theta), math.sin(theta)
	return { x = a.x * cs + c.x * sn, y = a.y * cs + c.y * sn, z = a.z * cs + c.z * sn, w = a.w * cs + c.w * sn }
end

return Quat
```

`fromCFrame` uses the standard trace method on the matrix from `GetComponents` (`r00, r10, r20` is the `RightVector`). Branching on the largest diagonal term keeps the square root away from zero for half-turns, where the naive formula divides by almost nothing.

### Swing-twist with the toolkit

```lua
--!strict
-- Split q into swing * twist, where twist is the rotation about unit axis d.
local function swingTwist(q: Quat, d: Vector3): (Quat, Quat)
	local proj = d * (q.x * d.X + q.y * d.Y + q.z * d.Z)
	local twist = { x = proj.X, y = proj.Y, z = proj.Z, w = q.w }
	if Quat.dot(twist, twist) < 1e-12 then
		-- 180 degree swing exactly perpendicular to d: twist is undefined, use identity
		twist = { x = 0, y = 0, z = 0, w = 1 }
	else
		twist = Quat.normalize(twist)
	end
	local swing = Quat.mul(q, Quat.conj(twist))
	return swing, twist
end

-- Signed twist angle about d, in (-pi, pi]
local function twistAngle(twist: Quat, d: Vector3): number
	local s = twist.x * d.X + twist.y * d.Y + twist.z * d.Z
	local a = 2 * math.atan2(s, twist.w)
	return if a > math.pi then a - 2 * math.pi elseif a <= -math.pi then a + 2 * math.pi else a
end
```

**Worked example: a turret on a tilting boat.** Express the desired aim in the mount's local space (`mount.CFrame:ToObjectSpace(CFrame.lookAt(...))`). Take the twist about the mount's local up (`Vector3.yAxis`): that is the yaw, which you rate-limit (section 3) but allow freely. The swing is the pitch part; measure its angle (`2 * acos(|swing.w|)`) and, if it exceeds the elevation limit, scale it back with `Quat.slerp(identity, swing, limit / angle)`. Recombine `swing * twist`, convert back to a CFrame, and multiply by the mount's CFrame. The turret now behaves correctly however the boat rolls, which Euler angles on the world frame cannot do.

The same decomposition limits head tracking (twist about the neck is "turn", swing is "nod and tilt": see [[Look-At Aim and Head Tracking]]) and removes unwanted roll from a held item (keep the swing, discard the twist about the blade axis).

---

## 7. Averaging orientations

Several hit normals under a vehicle, several bones' facings, several clients' reported orientations for a shared object: you want "the average rotation". Averaging Euler angles is wrong (the average of 350 and 10 degrees is 180). Averaging matrices produces a non-orthonormal matrix. For rotations that are reasonably close together, averaging quaternions works:

1. Pick the first as a reference.
2. For each other quaternion, negate it if its dot with the reference is negative (double cover).
3. Sum the components, then normalise.

This is a good approximation when the inputs are within a few tens of degrees of each other (rule of thumb), which covers all the gameplay cases above. For widely spread inputs there is no meaningful "average" anyway; pick a representative instead. For averaging surface normals under a vehicle, average the normal vectors and build the frame with `fromRotationBetweenVectors` instead; it is simpler and exact for that case.

---

## 8. Interpolation: slerp, nlerp and what the Animator actually does

- **Slerp** moves at constant angular speed along the shortest arc.
- **Nlerp** (lerp the four numbers, then normalise) follows the same path but speeds up slightly in the middle; for angles under about 30 degrees the difference is negligible (rule of thumb). It is cheaper and, unlike slerp, it is commutative when blending several rotations with weights, which is why animation blending uses it.
- **Long turns.** Both pick the short way. If a designer wants a 270 degree spin, a single interpolation will go 90 degrees the other way. Split long turns into steps under 180 degrees, or interpolate an angle about a fixed axis with `fromAxisAngle`.

The engine's own animation interpolation is not always quaternion slerp. The reference project measured the Animator interpolating joint rotations as a quaternion nlerp only when all keyframes are evenly spaced and Linear; otherwise it blends **rotation vectors** (axis times angle, measured from the joint's rest pose). A rotation-vector model matched fresh Animator playback to within 0.24 degrees across 15 clips, while a slerp model was up to 178 degrees off on large turns of joints far from rest (measured in the reference project). The practical rules that came out of it: key big turns densely, and keep any key-to-key segment under about 120 degrees, since segments beyond that were treated as flip risks and re-keyed (measured in the reference project). Details in [[Keyframes, Easing and Interpolation]] and [[How the Animator Really Behaves]].

`CFrame:Lerp` interpolates rotation along the short arc (rule of thumb; the docs list only the signature). It shares the double-cover ambiguity near 180 degrees: the chosen direction can flip between frames when the two orientations are almost exactly opposite.

---

## 9. Compressing rotations for the network and for saves

A full CFrame sent through a remote is 12 numbers. For replicating many objects (a crowd of NPCs on a custom replication system, a replay recording, a ghost racer), rotations dominate bandwidth. Options, from smallest to most general:

| Encoding | Size | Precision | Use when |
|---|---|---|---|
| Yaw only, `u16` | 2 bytes | 360 / 65,536 = 0.0055 degrees | Upright characters and NPCs |
| Yaw + pitch, 2 x `u16` | 4 bytes | same per axis | Turrets, cameras, aim |
| Smallest three, 3 x `i16` + index | 7 bytes | well under 0.01 degrees (rule of thumb) | Anything that tumbles |
| Full quaternion, 4 x `f32` | 16 bytes | float precision | Rarely worth it |

**Smallest three** stores a unit quaternion by dropping its largest component (it can be rebuilt from the other three, since the sum of squares is 1) and flipping signs so the dropped one is positive (double cover makes that free). The remaining three are each at most `1/sqrt(2)` in size, so they fit an `i16` scaled by `32767 * sqrt(2)`. The reference project packed clip keyframes this way for compact storage (measured in the reference project). With the [[Buffers and Binary Data]] API:

```lua
--!strict
local SCALE = 32767 * math.sqrt(2)

local function writeQuat(b: buffer, offset: number, q: { x: number, y: number, z: number, w: number }): number
	local c = { q.x, q.y, q.z, q.w }
	local big = 1
	for i = 2, 4 do
		if math.abs(c[i]) > math.abs(c[big]) then
			big = i
		end
	end
	local sign = if c[big] < 0 then -1 else 1
	buffer.writeu8(b, offset, big - 1)
	local o = offset + 1
	for i = 1, 4 do
		if i ~= big then
			local v = math.clamp(math.round(c[i] * sign * SCALE), -32767, 32767)
			buffer.writei16(b, o, v)
			o += 2
		end
	end
	return o -- next free offset (7 bytes written)
end

local function readQuat(b: buffer, offset: number): ({ x: number, y: number, z: number, w: number }, number)
	local big = buffer.readu8(b, offset) + 1
	local c = table.create(4, 0)
	local o = offset + 1
	local sumSq = 0
	for i = 1, 4 do
		if i ~= big then
			local v = buffer.readi16(b, o) / SCALE
			c[i] = v
			sumSq += v * v
			o += 2
		end
	end
	c[big] = math.sqrt(math.max(0, 1 - sumSq))
	return { x = c[1], y = c[2], z = c[3], w = c[4] }, o
end
```

Normalise the quaternion before writing; `fromCFrame` output is unit length to within float error, which is fine. Before compressing anything, check whether you need to send it at all: rotations that can be derived on the client (an NPC faces its movement direction) cost zero bytes ([[Network Bandwidth Budgets and Measuring Them]], [[Interest Management and Per-Player Replication]]).

---

## 10. Imported models and axis surprises

Not every rotation bug is maths. Assets arrive with their own conventions: Blender is Z up, glTF is Y up with +Z forward, Roblox is Y up with -Z forward. The reference project measured Studio's 3D importer turning each GLB 180 degrees about Y, so glTF +X and +Z land on Roblox -X and -Z (measured in the reference project). When a model faces backwards, fix it once at import (rotate the mesh or the pivot) rather than adding `CFrame.Angles(0, math.pi, 0)` to gameplay code in five places ([[Importing Models and Rigs]], [[Enemy Import Axis Fix]]).

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Turret spins the long way round | Raw difference of angles | `deltaAngle` with wrapping |
| Turret flickers between limits | Target on the wrap boundary | Hysteresis at limits |
| Camera flips looking straight up | Pitch reaching 90 degrees, readback from CFrame | Scalar yaw and pitch, clamp under 90 |
| Corkscrew turning | World delta applied on the right | `target * cur:Inverse()` goes on the left |
| Thrown object spins backwards | Delta over 180 degrees between samples | Sample faster, cap spin, wrap angle |
| Turret limits break on slopes | Euler limits in world space | Swing-twist in the mount's space |
| Average rotation is nonsense | Averaging Euler angles, or no sign alignment | Sign-align quaternions, sum, normalise |
| Interpolation goes "the other way" | Double cover, or turns near 180 degrees | Dot check; split long turns |
| Animation path differs from your preview | Engine interpolates rotation vectors, not slerp | Dense keys, segments under about 120 degrees |
| Model faces backwards after import | Axis conventions | Fix at import, not in code |

## Checklist

- [ ] Angles stored as scalars are wrapped on write; differences use `deltaAngle`.
- [ ] Camera state is scalar yaw and pitch; pitch is clamped below 90 degrees.
- [ ] Rate-limited turning uses axis-angle with the correct world or local order.
- [ ] Per-axis limits on tilted mounts use swing-twist in the mount's space.
- [ ] Quaternion interpolation and averaging align signs first.
- [ ] Long turns are split or driven by angle about a fixed axis.
- [ ] Replicated rotations use the smallest encoding that fits, or are derived client-side.
- [ ] Import axis fixes live in the asset, not in gameplay code.

## See also

[[Game Math Start Here]] · [[Math Vectors and CFrames]] · [[Cookbook - Math CFrame and Vectors]] · [[Motor6D Math and CFrame Composition]] · [[Dot and Cross Products in Gameplay]] · [[Interpolation Easing and Curves Math]] · [[Camera Systems]] · [[Look-At Aim and Head Tracking]] · [[Two-Bone IK Math]] · [[Clip Buffer Format]] · [[Buffers and Binary Data]] · [[Aircraft and Flight Models]]

## Connected notes
<!-- auto-links:start -->
[[Snippets - Building and Sampling Clips]] · [[Blender Armature and Bone Roll Conventions]] · [[Animation Data from Blender to Roblox]] · [[Animation Editor Advanced]] · [[CurveAnimation and Curve Channels]] · [[Springs Damping and Smoothing]]
<!-- auto-links:end -->
