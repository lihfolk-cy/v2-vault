---
tags: [procedural, ik, math, two-bone, arms, legs, luau]
---
# Two-Bone IK Math

<!-- tldr:start -->
> [!tldr] TL;DR
> - Rig parts vanish (NaN): `acos` of a value outside [-1, 1] -> clamp the distance and the cosine
> - Forearm rolls as the arm bends: bones treated as straight sticks on slanted R15 bones -> solve the hinge in the elbow's own frame (section 4)
> - Elbow bends backwards: wrong branch sign, or a ball-joint solve -> pick `s` per joint, clamp to the hinge range
>
> Read more (18 KB note): ## 2. The bend plane · ## 4. Slanted R15 bones and the pure-hinge elbow · ## Common mistakes
<!-- tldr:end -->

Two-bone IK is the workhorse: shoulder, elbow, wrist; hip, knee, ankle. It has an exact closed-form answer, runs in constant time, and (done right) can never bend an elbow backwards. This note derives it from the law of cosines, adds the bend plane (pole or swivel), shows how to turn solved geometry into Roblox joint `Transform`s, and then handles the two things textbook versions ignore: **R15 bones are slanted** (the joint pivots are not on a straight line along each part) and **an elbow is a pure hinge**, not a ball joint.

## 1. The triangle

Let `S` be the shoulder pivot, `T` the wrist target, `a` the upper bone length (shoulder pivot to elbow pivot), `b` the lower bone length (elbow pivot to wrist pivot), and `d = |T - S|`.

The three pivots form a triangle with sides `a`, `b`, `d`. The law of cosines gives both angles we need:

```
angle at the shoulder, between S->T and S->E:
    b^2 = a^2 + d^2 - 2 a d cos(alpha)
    cos(alpha) = (a^2 + d^2 - b^2) / (2 a d)

interior angle at the elbow:
    d^2 = a^2 + b^2 - 2 a b cos(gamma)

bend angle (0 = straight arm):
    theta = pi - gamma
    cos(theta) = (d^2 - a^2 - b^2) / (2 a b)
```

A triangle only exists when `|a - b| <= d <= a + b`. Outside that range `acos` receives a value beyond [-1, 1] and returns NaN, which turns your whole rig into NaN parts that vanish. Always clamp:

```lua
d = math.clamp(d, math.abs(a - b) + 1e-4, a + b - 1e-4)
```

**Worked example** (the reference project's 1.6x-scale R15 dummy, upper arm 1.48 studs pivot to pivot, forearm 1.29): maximum reach is 2.77 studs. With the elbow limited to 0.06..2.55 rad (about 3..146 degrees, the project's offline solver limits), reach runs from `sqrt(1.48^2 + 1.29^2 + 2*1.48*1.29*cos(0.06)) = 2.769` down to `sqrt(... + 2*1.48*1.29*cos(2.55)) = 0.83` studs. A target closer than 0.83 studs to the shoulder pivot cannot be reached by bending; the hand stops short.

## 2. The bend plane

The triangle fixes the elbow's distance from the shoulder-wrist line, not *which way* it points. The elbow can be anywhere on a circle around that line. One extra input picks the point:

- **A pole point `P`** ("the elbow points toward here"). The bend plane contains `S`, `T` and `P`.
- **A swivel angle `psi`** about the shoulder-wrist axis, measured from a reference direction. Same thing, parameterised as an angle, which is better for searching and smoothing (see [[Elbow Poles Swivel and Joint Limits]]).

With `u = (T - S).Unit`, project the pole direction onto the plane perpendicular to `u`:

```
p = (P - S) - u * dot(P - S, u)      -- remove the component along the arm line
p = p.Unit                            -- undefined if P lies on the line: needs a fallback

E = S + a * (cos(alpha) * u + sin(alpha) * p)
```

As a swivel: pick any reference `r` perpendicular to `u`, then `p(psi) = r cos(psi) + (u x r) sin(psi)`.

```lua
--!strict
-- The geometric core: the elbow point for a shoulder S, target T and pole point P (all world space).
-- a, b: bone lengths. Returns the elbow position and the clamped distance actually used.
local function elbowPoint(S: Vector3, T: Vector3, P: Vector3, a: number, b: number): (Vector3, number)
	local toT = T - S
	local d = math.clamp(toT.Magnitude, math.abs(a - b) + 1e-4, a + b - 1e-4)
	local u = if toT.Magnitude > 1e-6 then toT.Unit else Vector3.new(0, -1, 0)
	local cosA = math.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)
	local p = (P - S) - u * (P - S):Dot(u)
	if p.Magnitude < 1e-4 then
		-- pole on the arm line: any perpendicular works, but pick a stable one
		p = (if math.abs(u.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis):Cross(u)
	end
	p = p.Unit
	return S + (u * cosA + p * sinA) * a, d
end
```

### Degenerate cases and what they look like

| Case | On screen | Handling |
|---|---|---|
| Target out of reach | arm snaps straight, jitters at full extension | clamp; optionally "soft IK" (below) |
| Target at the shoulder | arm folds, elbow direction random | clamp to the minimum reach |
| Pole on the shoulder-target line | elbow flips between sides frame to frame | fallback perpendicular, or blend in a secondary pole as the angle shrinks |
| Pole behind the arm | elbow points backward, a "broken" read | choose poles per motion type |

### Soft IK near full extension

`acos` is infinitely steep at 1: as `d` approaches `a + b`, a tiny target movement swings the elbow a lot, so near-straight arms and legs shiver. A common fix (rule of thumb, widely used in game IK) is to remap distance smoothly before solving. With `L = a + b` and a soft zone `ds` (for example 5% of `L`), `da = L - ds`:

```
if d > da: d' = da + ds * (1 - exp(-(d - da) / ds))
```

`d'` has the same value and slope as `d` at `da` and approaches `L` without reaching it. The limb never locks straight; the end falls short by `d - d'`, which you hide (a pelvis drop for legs, a slight lean for arms). The reference project used hard clamps with a margin instead (`(L1 + L2) * 0.9995` for the solve, 0.99 and 0.995 for planted-foot reach checks).

## 3. From points to joint Transforms

Roblox joints do not take positions. Each joint needs a `Transform` such that

```
Part1 = Part0 * C0 * Transform * C1:Inverse()
```

(`Attachment0.CFrame` / `Attachment1.CFrame` in place of `C0` / `C1` for an `AnimationConstraint`). So after finding `E`, you still need rotations. The robust way to build a rotation from geometry is **triad alignment**: if you know two non-parallel vectors in the bone's own space (say, "the bone axis" and "the elbow direction") and where both must point after the solve, there is exactly one rotation that maps the first pair onto the second, provided the angle between the vectors is the same in both pairs.

```lua
-- An orthonormal frame from two vectors: x along a, z normal to the a-b plane.
local function frameOf(a: Vector3, b: Vector3): CFrame
	local x = a.Unit
	local n = a:Cross(b).Unit
	local y = n:Cross(x)                      -- (x, y, n) is right-handed: x cross y = n
	return CFrame.fromMatrix(Vector3.zero, x, y, n)
end
-- The rotation that maps (a0, b0) onto (a1, b1). Requires angle(a0, b0) == angle(a1, b1).
local function alignPair(a0: Vector3, b0: Vector3, a1: Vector3, b1: Vector3): CFrame
	return frameOf(a1, b1) * frameOf(a0, b0):Inverse()
end
```

For a toy rig where each bone lies exactly along one axis of its part, the pair is (bone direction, hinge axis): the rest pair `(-Y, X)` maps to `((E - S).Unit, bendNormal)`. Real R15 rigs are not like that, which is the next section.

## 4. Slanted R15 bones and the pure-hinge elbow

On an R15 rig, the `RightShoulderRigAttachment`, `RightElbowRigAttachment` and `RightWristRigAttachment` pivots are not collinear at rest, and the vector from one pivot to the next is not aligned with any axis of the part. Textbook two-bone IK, which treats each bone as a straight stick from pivot to pivot and then aims it, gets the hand position right but produces a forearm that is subtly rolled, and an elbow that is no longer bending about its own hinge axis. On screen: the forearm twists as the arm bends, and the elbow drifts sideways ("elbow sideways over 20 degrees" was one of the project's QA flags).

The reference project's offline arm solver solved this exactly. Its rule: **the elbow is a pure hinge `Rx(theta)` in the elbow joint's frame, so it can never bend backwards or sideways.** Everything else follows from writing the wrist pivot as a function of that one angle.

### Setting up the chain

Name the three joints shoulder `s`, elbow `e`, wrist `w`, with their `C0`/`C1` (or attachment) frames. With the shoulder `Transform` a pure rotation `Ru` and the elbow `Transform = Rx(theta)`:

```
shoulder joint frame (world):      JS = UpperTorso * C0s
elbow joint frame, in JS space:    Ru * K,          K = C1s:Inverse() * C0e      (constant)
wrist joint frame, in JS space:    Ru * K * Rx(theta) * W,   W = C1e:Inverse() * C0w  (constant)
```

Write `b1 = K.Position` (shoulder pivot to elbow pivot, in shoulder-joint space at rest), `M = K.Rotation`, `w = W.Position`. Then the wrist pivot, in `JS` space, is

```
wrist(theta) = Ru * v(theta),     v(theta) = b1 + M * Rx(theta) * w
```

### The distance is a function of theta only

`Ru` is a rotation, so it does not change lengths. The shoulder-to-wrist distance is `|v(theta)|`:

```
|v|^2 = |b1|^2 + |w|^2 + 2 * dot(b1, M Rx(theta) w)
      = |b1|^2 + |w|^2 + 2 * dot(c, Rx(theta) w),         c = M^T b1

Rx(theta) w = (wx,  wy cos(theta) - wz sin(theta),  wy sin(theta) + wz cos(theta))

dot(c, Rx(theta) w) = cx wx + cos(theta) (cy wy + cz wz) + sin(theta) (cz wy - cy wz)
```

Collect constants:

```
Pc = |b1|^2 + |w|^2 + 2 cx wx
A  = cy wy + cz wz
B  = cz wy - cy wz
|v|^2 = Pc + 2 (A cos(theta) + B sin(theta)) = Pc + 2 R cos(theta - phi),
        R = sqrt(A^2 + B^2),  phi = atan2(B, A)
```

Given a target distance `D`, the hinge angle is closed-form:

```
theta = phi + s * acos( clamp((D^2 - Pc) / (2 R), -1, 1) )
```

`s = +1` or `-1` picks the branch. On standard R15, positive rotation about the elbow attachment's X swings a hanging forearm toward `-Z` (forward), so elbows use `s = +1`; knees bend the other way and use `s = -1` (the reference project's leg solver writes the knee as `Rx(-bend)`). Verify the sign on your rig once by posing it.

Then clamp `theta` to the hinge range (the project: magnitude 0.06 to 2.55 rad), and recompute `v(theta)` from the clamped value. If the clamp was active, the wrist misses the target by `|D - |v||` along the arm line: report it.

The reference project's Python solver did the same thing by tabulating `|v(theta)|` over 2,000 angles and inverting the (monotone) table; the closed form above is equivalent and cheaper.

### Placing the elbow, then the rotation

In `JS` space, the target direction is `uh = u.Unit` with `u = JS:PointToObjectSpace(wristTarget)`. The elbow must sit at the same angle from the shoulder-wrist line as it does inside the bent chain, which is the angle `A` between `v(theta)` and `b1`:

```
cos(A) = dot(v.Unit, b1.Unit)
e = |b1| * ( uh cos(A) + (r cos(psi) + (uh x r) sin(psi)) sin(A) )      -- r: swivel reference, perpendicular to uh
```

Now align the pair `(v, b1)` (inside the chain) onto `(uh, e)` (where they must go). The angle between each pair is `A` by construction, so the alignment is exact:

```
Ru = frameOf(uh, e) * frameOf(v, b1):Inverse()
```

### The full solver in Luau

```lua
--!strict
-- Exact two-bone IK for R15-style chains with slanted bones and a pure hinge.
-- Works with Motor6D and AnimationConstraint joints.

local function jointFrames(j: Instance): (CFrame, CFrame)
	if j:IsA("Motor6D") then return j.C0, j.C1 end
	local c = j :: AnimationConstraint
	return c.Attachment0 and c.Attachment0.CFrame or CFrame.identity,
		c.Attachment1 and c.Attachment1.CFrame or CFrame.identity
end

local function frameOf(a: Vector3, b: Vector3): CFrame
	local x = a.Unit
	local n = a:Cross(b)
	if n.Magnitude < 1e-6 then
		-- a and b parallel: any normal will do (only happens for a perfectly straight chain)
		n = (if math.abs(x.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis):Cross(x)
	end
	n = n.Unit
	return CFrame.fromMatrix(Vector3.zero, x, n:Cross(x), n)
end

export type Chain = {
	upper: Instance, mid: Instance, tip: Instance,
	s: number, lo: number, hi: number,
	K: CFrame, W: CFrame, b1: Vector3, Pc: number, R: number, phi: number,
}

local TwoBone = {}

-- upper/mid/tip: shoulder/elbow/wrist (or hip/knee/ankle) joints.
-- s: +1 elbow, -1 knee (check on your rig). lo/hi: hinge range in radians, as magnitudes.
function TwoBone.chain(upper: Instance, mid: Instance, tip: Instance, s: number, lo: number, hi: number): Chain
	local _, c1u = jointFrames(upper)
	local c0m, c1m = jointFrames(mid)
	local c0t = jointFrames(tip)
	local K = c1u:Inverse() * c0m          -- mid joint frame in the upper joint's frame (Transform = identity)
	local W = c1m:Inverse() * c0t          -- tip joint frame in the mid joint's frame
	local b1, w = K.Position, W.Position
	local c = K.Rotation:VectorToObjectSpace(b1)            -- M^T b1
	local A = c.Y * w.Y + c.Z * w.Z
	local B = c.Z * w.Y - c.Y * w.Z
	return {
		upper = upper, mid = mid, tip = tip, s = s, lo = lo, hi = hi,
		K = K, W = W, b1 = b1,
		Pc = b1:Dot(b1) + w:Dot(w) + 2 * c.X * w.X,
		R = math.sqrt(A * A + B * B), phi = math.atan2(B, A),
	}
end

-- parentCF: the upper joint's Part0 world CFrame (from your own FK this frame).
-- endCF: the desired world CFrame of the tip part (the hand or foot).
-- swivelRef: world direction the mid joint points toward at psi = 0. psi: swivel angle (radians).
-- Returns the three Transforms and the miss distance (studs) at the tip pivot.
function TwoBone.solve(ch: Chain, parentCF: CFrame, endCF: CFrame, swivelRef: Vector3, psi: number)
	local c0u = jointFrames(ch.upper)
	local _, c1t = jointFrames(ch.tip)
	local JS = parentCF * c0u
	local target = (endCF * c1t).Position                 -- the tip joint's pivot when the hand is at endCF
	local u = JS:PointToObjectSpace(target)
	local D = u.Magnitude
	local uh = if D > 1e-6 then u / D else Vector3.new(0, -1, 0)

	-- hinge angle from distance, on the chosen branch, clamped to the hinge range
	local x = math.clamp((D * D - ch.Pc) / (2 * ch.R), -1, 1)
	local theta = ch.phi + ch.s * math.acos(x)
	theta = ch.s * math.clamp(theta * ch.s, ch.lo, ch.hi)
	local hinge = CFrame.Angles(theta, 0, 0)
	local v = ch.b1 + ch.K.Rotation * (hinge * ch.W.Position)   -- tip pivot in upper-joint space

	-- elbow on its circle around the shoulder-target line, at swivel psi
	local lb = ch.b1.Magnitude
	local cosA = math.clamp(v.Unit:Dot(ch.b1 / lb), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)
	local r = JS:VectorToObjectSpace(swivelRef)
	r -= uh * r:Dot(uh)
	if r.Magnitude < 1e-4 then
		r = (if math.abs(uh.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis):Cross(uh)
	end
	r = r.Unit
	local e = (uh * cosA + (r * math.cos(psi) + uh:Cross(r) * math.sin(psi)) * sinA) * lb

	local Ru = frameOf(uh, e) * frameOf(v, ch.b1):Inverse()
	-- tip: whatever rotation remains so the hand matches endCF's orientation
	local JT = JS * Ru * ch.K * hinge * ch.W                  -- tip joint frame, world
	local Tt = (JT:Inverse() * endCF * c1t).Rotation
	local miss = (JT.Position - target).Magnitude
	return Ru, hinge, Tt, miss
end

return TwoBone
```

Usage: `chain = TwoBone.chain(rightShoulder, rightElbow, rightWrist, 1, 0.06, 2.55)` once (and again when body scale changes), then each frame `Ru, He, Tw, miss = TwoBone.solve(chain, upperTorsoCF, handTargetCF, downDir, psi)` and write `rightShoulder.Transform = Ru` and so on in `PreSimulation`. `Tt` is unclamped: run it through a wrist limit (swing/twist clamp, see [[Elbow Poles Swivel and Joint Limits]]) before writing.

Two cautions that bite in practice:

- **`parentCF` must be this frame's pose.** In `PreSimulation`, `UpperTorso.CFrame` is still last frame's. Compute it by FK from the root through the waist's current `Transform` (see [[Procedural Animation]]).
- **Re-read the geometry when the body scales.** Humanoid body-scale values often land after spawn. The project's gait code re-read leg geometry once a second and rebuilt its tracks if the leg length changed by more than 0.001 studs.

## 5. Legs: the same maths, plus roll

A leg is the same chain (hip, knee, ankle) with `s = -1`. Two practical differences:

- **The target is a sole point, not the ankle.** If the foot must be pitched (toe down, heel up) by angle `pitch` about its X axis, the ankle pivot sits at `sole - Rpitch * (soleOffset - ankleOffset)`. The project's leg solver does exactly this before solving.
- **Sideways reach.** A foot placed out to the side needs hip roll. The project's runtime leg solver kept the knee hinge in the leg's own plane and split the hip into `Rx(hipPitch) * Rz(roll)` (its XYZ convention), with
  `reachY = L1 + L2 cos(bend)` and `roll = asin(clamp(dX / reachY, -0.6, 0.6))`, then
  `hipPitch = atan2(dZ, dY) - atan2(L2 sin(bend), -reachY cos(roll))`, wrapped to [-pi, pi].
  The +-0.6 clamp (about 34 degrees) stops the solver from splaying the leg when a target is absurdly wide.

That simpler hip formula assumes straight bones; it was good enough for feet, where small slant errors are hidden by the shoe. Arms holding a blade are where the exact slanted solve paid off.

## 6. Verifying a solver

1. **FK round trip.** Feed the solved Transforms through FK and measure the tip error. With the clamp inactive it should be under 0.001 studs.
2. **Hinge purity.** The elbow `Transform` should be a rotation about X only: `select(2, T:ToEulerAnglesXYZ())` and the third angle are zero.
3. **Sweep test.** Move the target around a sphere at 60 Hz; plot the swivel and elbow angles. Any jump bigger than about 30 degrees per frame on a smooth target path is a flip (the project's QA flagged elbow swivel flips over 30 degrees per frame, critical over 70).
4. **Scale test.** Repeat at body scale 1, 1.6 and with a slim avatar.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Rig parts vanish (NaN) | `acos` of a value outside [-1, 1] | clamp the distance and the cosine |
| Forearm rolls as the arm bends | bones treated as straight sticks on slanted R15 bones | solve the hinge in the elbow's own frame (section 4) |
| Elbow bends backwards | wrong branch sign, or a ball-joint solve | pick `s` per joint, clamp to the hinge range |
| Hand lands right, arm points wrong way | swivel reference undefined or flipping | stable reference direction, continuity (see the swivel note) |
| Works at scale 1, misses at 1.6 | lengths cached before body scale applied | rebuild the chain on scale change |
| Hand position correct, hand orientation off | tip rotation computed from part CFrames, not the solved chain | compute `JT` from the solved `Ru` and hinge |
| Knee locks and jitters at full stride | target at the reach limit | soft IK or a pelvis drop |

Related: [[Inverse Kinematics]], [[Elbow Poles Swivel and Joint Limits]], [[Foot Placement and Ground IK]], [[Motor6D Math and CFrame Composition]], [[R15 Rig Anatomy and Attachments]], [[Snippets - IK]].

## Connected notes
<!-- auto-links:start -->
[[IKControl Reference]] · [[Arm Baker Internals]] · [[Animation Quality Standard]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Dot and Cross Products in Gameplay]] · [[Topology and Edge Flow]] · [[Animation Start Here]]
<!-- auto-links:end -->
