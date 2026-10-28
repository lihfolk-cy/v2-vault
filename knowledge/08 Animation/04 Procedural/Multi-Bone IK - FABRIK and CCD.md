---
tags: [procedural, ik, fabrik, ccd, tails, tentacles, spines, chains, luau]
---
# Multi-Bone IK - FABRIK and CCD

Two-bone IK has a closed form. Chains of three or more joints (tails, tentacles, necks, spines, whips, flexible blades, ropes) do not: there are infinitely many poses that reach a target and no formula picks one. The two standard iterative answers are **FABRIK** (Forward And Backward Reaching IK) and **CCD** (Cyclic Coordinate Descent). This note explains both, adds joint limits, shows how to turn a solved chain into Roblox `Transform`s without twist flips, and covers the non-IK alternatives (springs, waves, verlet) that are often the better choice for creatures.

## When you need a chain solver at all

| Goal | Best tool |
|---|---|
| Tail or tentacle *reaches* a point (grabs, stings, coils around a pole) | FABRIK or CCD |
| Tail *follows* the body with lag and overlap | spring chain or verlet (no IK) |
| Tail sways while idle, curls into turns | travelling wave + turn distribution (no IK) |
| Spine bends so the chest faces a target | aim distribution over 2-4 joints (see [[Look-At Aim and Head Tracking]]) |
| Neck reaches down to drink | FABRIK with cone limits, or IKControl with a chain |
| Rope or chain hangs from two points | verlet with distance constraints |

Most creature work is "follow", not "reach". The reference project's enemy reaction layer drove tails and dangling parts (capes, skirts, tentacles) with per-role damped springs and a travelling wave, never IK, and its flying creatures' necks and tails used waves plus a turn bias. Use IK when there is a target to touch.

## FABRIK

FABRIK works on joint *positions*, keeping each segment's length fixed. Each iteration has two passes:

1. **Forward reaching (tip to root).** Put the tip on the target. Walk toward the root: each joint moves onto the line between itself and the joint just placed, at the correct segment length.
2. **Backward reaching (root to tip).** Put the root back where it belongs. Walk toward the tip the same way.

After both passes the root is fixed, every length is exact, and the tip is closer to the target. Repeat until the tip is within tolerance or you run out of iterations.

If the target is farther than the total chain length, no iteration helps: stretch the chain straight toward it and stop.

Why animators like it: it converges in a few iterations (rule of thumb: 3-10 for 4-12 joints), the motion it produces spreads the bend along the chain naturally, and it has no angles in it, so there is no gimbal trouble.

Why it is not enough alone: it says nothing about twist (roll around each segment), and it ignores joint limits unless you add them.

### Cone limits

Add limits in the backward (root-to-tip) pass: after placing joint `i+1`, check the angle between the new segment and the previous one. If it exceeds that joint's limit, rotate the new segment back onto the cone's surface. For the first segment, use a fixed reference direction (the parent bone's axis).

Limits fight convergence: a limited chain may not reach a reachable target, and very tight limits make it oscillate between passes. Give each joint 20-40 degrees for tails (rule of thumb) and let the count of joints provide the total curl.

### FABRIK in Luau

```lua
--!strict
local function safeUnit(v: Vector3, fallback: Vector3): Vector3
	local m = v.Magnitude
	return if m > 1e-6 then v / m else fallback
end

-- Rotate dir into the cone of half-angle maxAngle around axis (all unit vectors).
local function clampCone(dir: Vector3, axis: Vector3, maxAngle: number): Vector3
	local c = math.clamp(dir:Dot(axis), -1, 1)
	if math.acos(c) <= maxAngle then
		return dir
	end
	local perp = dir - axis * c
	if perp.Magnitude < 1e-6 then
		-- dir points straight back along the axis: choose any side
		perp = (if math.abs(axis.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis):Cross(axis)
	end
	perp = perp.Unit
	return axis * math.cos(maxAngle) + perp * math.sin(maxAngle)
end

-- p: joint positions, p[1] = root ... p[n] = tip (edited in place).
-- len[i]: |p[i+1] - p[i]|, measured from the rig, never from the current pose.
-- rootDir: reference direction for the first segment's cone. cone[i]: max angle at joint i (radians), optional.
local function fabrik(p: { Vector3 }, len: { number }, target: Vector3, rootDir: Vector3,
	cone: { number }?, iterations: number, tolerance: number): number
	local n = #p
	local root = p[1]
	local total = 0
	for i = 1, n - 1 do total += len[i] end

	if (target - root).Magnitude >= total then
		-- out of reach: lay the chain straight toward the target (still respecting the root cone)
		local dir = safeUnit(target - root, rootDir)
		if cone then dir = clampCone(dir, rootDir, cone[1]) end
		for i = 1, n - 1 do p[i + 1] = p[i] + dir * len[i] end
		return (p[n] - target).Magnitude
	end

	for _ = 1, iterations do
		-- forward reaching: tip to root
		p[n] = target
		for i = n - 1, 1, -1 do
			p[i] = p[i + 1] + safeUnit(p[i] - p[i + 1], -rootDir) * len[i]
		end
		-- backward reaching: root to tip, with limits
		p[1] = root
		local prevDir = rootDir
		for i = 1, n - 1 do
			local dir = safeUnit(p[i + 1] - p[i], prevDir)
			if cone then dir = clampCone(dir, prevDir, cone[i]) end
			p[i + 1] = p[i] + dir * len[i]
			prevDir = dir
		end
		if (p[n] - target).Magnitude <= tolerance then break end
	end
	return (p[n] - target).Magnitude          -- the remaining miss: report or hide it
end
```

## CCD

CCD works on joint *rotations*. One iteration visits the joints from the one nearest the tip back to the root. At each joint it rotates the whole sub-chain below so that the tip lies on the line from that joint to the target. Then the next joint up does the same.

Properties:

- **Limits are easy**: after each joint's rotation, clamp that joint's local rotation (a hinge angle, or an axis-angle magnitude). This is why CCD is popular for hinged chains (mechanical arms, insect legs).
- **It bends the tip first.** The joints near the tip do most of the work, so a CCD tail curls at the end like a scorpion before the base moves. For a sting that is great; for a reaching neck it looks wrong. Damping helps: cap each joint's rotation per iteration (for example 10-20 degrees) so the base gets a share.
- It can converge slowly when the target is almost straight behind the chain.

### CCD in Luau (local rotations, cone limits)

```lua
--!strict
-- A chain as local rotations: frame[i] = parentFrame * off[i-1] * rot[i]; the tip is frame[n] * off[n].
-- base: world CFrame of joint 1's parent pivot (rotation included). off[i]: rest offset from joint i to joint i+1.
-- rot[i]: local rotation of joint i (edited in place). limit[i]: max total rotation from rest (radians).

local function fromTo(a: Vector3, b: Vector3): CFrame
	local axis = a:Cross(b)
	local s, c = axis.Magnitude, a:Dot(b)
	if s < 1e-8 then
		if c > 0 then return CFrame.identity end
		-- opposite: half turn about any perpendicular
		local perp = (if math.abs(a.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis):Cross(a).Unit
		return CFrame.fromAxisAngle(perp, math.pi)
	end
	return CFrame.fromAxisAngle(axis / s, math.atan2(s, c))
end

local function chainFrames(base: CFrame, off: { CFrame }, rot: { CFrame }, out: { CFrame }): Vector3
	local f = base
	for i = 1, #rot do
		f = f * rot[i]
		out[i] = f
		f = f * off[i]
	end
	return f.Position                                    -- the tip
end

local function ccd(base: CFrame, off: { CFrame }, rot: { CFrame }, limit: { number },
	target: Vector3, iterations: number, maxStep: number, tolerance: number): number
	local n = #rot
	local frames = table.create(n)
	local tip = chainFrames(base, off, rot, frames)
	for _ = 1, iterations do
		for i = n, 1, -1 do
			local pivot = frames[i].Position
			local q = fromTo((tip - pivot).Unit, (target - pivot).Unit)
			local axis, angle = q:ToAxisAngle()
			if angle > maxStep then q = CFrame.fromAxisAngle(axis, maxStep) end   -- damping: share the bend
			-- world rotation q about this pivot, expressed in the joint's parent frame
			local parentRot = (frames[i] * rot[i]:Inverse()).Rotation
			local r = parentRot:Inverse() * q * parentRot * rot[i]
			-- limit: clamp the total rotation from rest
			local ax, ang = r:ToAxisAngle()
			if ang > limit[i] then r = CFrame.fromAxisAngle(ax, limit[i]) end
			rot[i] = r
			tip = chainFrames(base, off, rot, frames)       -- O(n) refresh; fine for n <= ~16
		end
		if (tip - target).Magnitude <= tolerance then break end
	end
	return (tip - target).Magnitude
end
```

The derivation of the local update: joint `i`'s world frame is `F = Parent * rot`. A world rotation `q` about the pivot gives `F' = q * F` (rotation part; the pivot does not move), so `rot' = Parent^-1 * q * Parent * rot` (rotations only, since the pivot is the parent's own position).

## FABRIK vs CCD

| | FABRIK | CCD |
|---|---|---|
| Works on | positions | rotations |
| Iterations to converge (typical) | few | more, especially with damping |
| Natural-looking bend | spreads along the chain | curls the tip first |
| Hinge limits | awkward (project onto planes) | trivial |
| Cone limits | in the root-to-tip pass | clamp per joint |
| Twist | undefined: needs a separate step | carried by the rotations |
| Output | points: convert to Transforms | local rotations: write directly |
| Good for | necks, tentacles reaching, ropes | stings, mechanical arms, insect legs |

## Turning solved points into Transforms (no twist flips)

FABRIK gives you points. Each joint needs a rotation, and a point pair does not fix the roll about the segment. The naive fix, `CFrame.lookAt(p[i], p[i+1])` per segment, picks roll from the world up vector and flips 180 degrees when a segment passes vertical: tails corkscrew.

The fix is to use the **minimal rotation from each joint's rest direction to its new direction**, joint by joint from the root, in the joint's own frame. Minimal rotation adds no twist of its own, so roll is carried smoothly down the chain from the parent (this is the discrete version of "parallel transport").

```lua
-- joints[i]: the joint whose Part1 is segment i (Motor6D or AnimationConstraint), parents first.
-- p: solved points with p[1] at joints[1]'s pivot. rootParentCF: joints[1].Part0's CFrame this frame.
-- Writes Transforms. The rest offset from each pivot to the next is read from the rig, so lengths match.
local function pointsToTransforms(joints: { Instance }, p: { Vector3 }, rootParentCF: CFrame)
	local parentCF = rootParentCF
	for i, j in joints do
		local c0, c1 = jointFrames(j)                     -- from the Procedural Animation note
		local J = parentCF * c0                            -- this joint's frame with the solved parent
		local nextJ = joints[i + 1]
		local T = CFrame.identity
		if nextJ and p[i + 1] then
			local nc0 = jointFrames(nextJ)
			local restDir = (c1:Inverse() * nc0).Position   -- pivot to next pivot, in J space, at rest
			local newDir = J:VectorToObjectSpace(p[i + 1] - J.Position)
			T = fromTo(restDir.Unit, newDir.Unit)
		end
		(j :: any).Transform = T
		parentCF = J * T * c1:Inverse()                    -- this segment's part, solved
	end
end
```

For the last segment (the tip part has no child joint), keep the parent's orientation or aim it along the last point pair. Lengths must come from the rig (`restDir.Magnitude`), not from the current pose, or the chain slowly grows or shrinks.

## Non-IK chains: often the better choice

### Spring chain (follow with overlap)

Give each joint a target rotation (from a clip, a wave, or zero) and let a damped spring chase it. Looser springs toward the tip give overlap and follow-through for free. The reference project's enemy reaction layer used these per-role values (frequency in Hz, damping ratio):

| Role | Frequency | Damping |
|---|---|---|
| spine | 7.0 | 0.72 |
| head | 6.0 | 0.55 |
| jaw | 8 | 0.6 |
| arm (segment 1 / 2 / 3) | 5.6 / 4.6 / 3.9 | 0.55 / 0.5 / 0.46 |
| leg (segment 1 / 2 / 3) | 6.0 / 5.0 / 4.2 | 0.62 / 0.55 / 0.5 |
| wing | 4.6 | 0.5 |
| tail | 3.4 | 0.42 |
| dangle (capes, skirts, tentacles) | 2.6 | 0.34 |
| prop | 6 | 0.6 |

Stiffer near the body, looser at the tips. When the body went limp (dying), it scaled frequency by 0.55 and dropped damping to 0.3. Springs are covered in [[Springs Damping and Smoothing]].

### Travelling wave (idle sway, swimming, flying)

```
angle_i(t) = A_i * sin(omega * t - k * i + phase)
```

`k` is the phase lag per segment (the wave travels toward the tip when `k > 0`), and `A_i` usually grows toward the tip. The reference project's flying creature tails used yaw amplitude `(1.4 + 0.45 i)` degrees with `k = 0.62` rad per segment over 7 segments, plus a turn bias of `-0.36 * turnRate` per segment so the tail swings out of turns; its necks curved *into* the turn with `+0.3 * turnRate` per segment. See [[Flight Flocks and Path Animation]].

### Verlet rope (hanging chains, loose tails)

Store each point's current and previous position. Each step: `x_new = x + (x - x_prev) * damping + gravity * dt^2`, then satisfy distance constraints by moving pairs of points toward their rest length, a few iterations, with the root pinned to the body. Add a cone clamp between consecutive segments so it cannot fold through itself. Use a fixed substep (1/60 s) with an accumulator: verlet with a variable `dt` changes the effective damping. Convert to Transforms with the method above.

## Performance

- Cost is roughly `joints x iterations` per chain per frame. 10 joints x 6 iterations is trivial for one boss tail and noticeable for 40 creatures.
- Early-out when the tip is within tolerance, and when the target has not moved since last frame (cache it).
- LOD: solve every 2nd or 4th frame at distance and interpolate rotations in between, or switch distant creatures to the wave-only version.
- The reference project's enemy layer ran only while an enemy was reacting, created nothing per frame, and stopped itself when every spring had settled.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Tail corkscrews when it passes vertical | `CFrame.lookAt` with a world up vector per segment | minimal rotation from the rest direction, root first |
| Chain slowly stretches | lengths taken from the current pose, or drift from float error | lengths from the rig, re-measured on scale change |
| Chain jitters on a still target | not enough iterations, tight cone limits fighting the passes | more iterations, looser limits, early-out |
| CCD tail curls only at the tip | no per-step damping | cap rotation per joint per iteration |
| NaN parts | `.Unit` of a zero vector | safe normalise with a fallback |
| Folds through itself | no limits | cones per joint, or a minimum angle between segments |
| Snaps when target goes out of reach | sudden switch to the straight solution | blend the straight pose in over the last few percent of reach |

Related: [[Inverse Kinematics]], [[Two-Bone IK Math]], [[Springs Damping and Smoothing]], [[Animating Creatures and Monsters]], [[Creature Rig Conventions]], [[Snippets - IK]].

## Connected notes
<!-- auto-links:start -->
[[Ropes Chains and Soft Bodies]] · [[IKControl Reference]] · [[Procedural Animation]] · [[Procedural Death Knockdown and Hit Reactions]] · [[Skeleton Library]] · [[Cookbook - Math CFrame and Vectors]] · [[Animation Start Here]]
<!-- auto-links:end -->
