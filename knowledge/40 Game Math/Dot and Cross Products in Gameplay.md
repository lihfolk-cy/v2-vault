---
tags: [math, game-math, vectors, dot-product, cross-product, gameplay, combat, movement, luau]
---
# Dot and Cross Products in Gameplay

Two small operations answer a surprising share of gameplay questions. The dot product answers "how much of this points along that?", and the cross product answers "which way is perpendicular, and which side am I on?". The basics (the cone check, signed yaw, projection onto a plane, reflection) are already in [[Math Vectors and CFrames]] and [[Cookbook - Math CFrame and Vectors]]. This note goes further: backstabs and flanking, steering without jitter, closing speed for homing and aggro, lap progress and gate crossing, wall-running tangents, building stable frames, bounce pads with friction, and aim assist scoring. Each section shows the gameplay first, then the maths, then the way it breaks.

Conventions: Roblox is Y up, right-handed, and a `CFrame`'s `LookVector` is its negative Z axis (Roblox docs (as of October 2026)). `Vector3.xAxis:Cross(Vector3.yAxis)` is `Vector3.zAxis`, the usual right-handed rule.

---

## 1. What the numbers actually mean

**Dot.** `a:Dot(b) = |a| |b| cos(angle)`. If `b` is a unit vector, `a:Dot(b)` is the signed length of `a` measured along `b`: positive means "with", negative means "against", zero means "across". That second reading (a signed length, not an angle) is the one gameplay uses most. It is how much of a velocity goes toward a target, how far along a track a player is, how deep a point sits behind a plane.

**Cross.** `a:Cross(b)` is perpendicular to both, with length `|a| |b| sin(angle)`. Its direction follows the right-hand rule, so swapping the arguments flips it. Its length is the area of the parallelogram spanned by `a` and `b`, which makes it zero when the two are parallel. Gameplay uses the direction (normals, sideways vectors, building frames) and the sign of one component (left or right of a line).

**What neither tells you.** A dot product of two unnormalised vectors mixes angle and length. A result of `0.5` could mean "60 degrees apart, both unit length", but it could just as well mean "pointing the same way, lengths 0.5 and 1". Almost every dot product bug in combat code is a missing normalisation on one side or an unexpected vertical component on the other.

| Question | Operation | Needs unit vectors? |
|---|---|---|
| Is B in front of A? | `A.LookVector:Dot(B - A.Position) > 0` | No: only the sign matters |
| Within N degrees? | `dirA:Dot(dirB) >= cos(N)` | Yes, both |
| How fast toward the target? | `velocity:Dot(toTarget.Unit)` | Only the direction |
| How far along a track segment? | `(p - start):Dot(segmentDir)` | Only `segmentDir` |
| Left or right of my facing? | `forward:Cross(toTarget).Y` sign | No |
| Normal of a surface from 3 points | `(b - a):Cross(c - a).Unit` | Normalise the result |
| Are two directions parallel? | `a:Cross(b).Magnitude < eps * |a||b|` | Scale the tolerance |

---

## 2. Backstabs, flanks and front-only blocks

A stealth game wants double damage from behind. A fighting game wants blocks to stop only frontal hits. A shield NPC wants to be vulnerable from the sides. All three are the same test, done from the **victim's** point of view.

```lua
--!strict
export type Facing = "Front" | "Side" | "Back"

-- Thresholds as cosines, computed once. Front: within 60 degrees of the
-- victim's forward. Back: within 50 degrees of the victim's backward.
local FRONT_COS = math.cos(math.rad(60))
local BACK_COS = math.cos(math.rad(180 - 50)) -- negative: about -0.643

local function classifyHit(victim: CFrame, attackerPos: Vector3): Facing
	-- Flatten: height difference must not turn a back hit into a side hit
	local to = attackerPos - victim.Position
	to = Vector3.new(to.X, 0, to.Z)
	local look = victim.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	local toLen, lookLen = to.Magnitude, look.Magnitude
	if toLen < 1e-4 or lookLen < 1e-4 then
		return "Side" -- overlapping or victim looking straight up/down: pick the neutral answer
	end
	local d = (look / lookLen):Dot(to / toLen)
	if d >= FRONT_COS then
		return "Front"
	elseif d <= BACK_COS then
		return "Back"
	end
	return "Side"
end
```

The design choices hide in the details.

**Use the victim's facing, not the attacker's.** "The attacker is looking at the victim's back" is a different test, and it passes when two players face the same way side by side. What you mean is "the attacker stands in the region behind the victim".

**Flatten both vectors.** An attacker jumping down from a ledge directly behind someone has a large negative Y offset. Unflattened, the dot shrinks toward zero and the hit becomes "Side". Flatten for ground combat, keep 3D for flying or swimming games.

**Choose asymmetric zones on purpose.** A 60 degree front half-angle and a 50 degree back half-angle leave 70 degree side bands. If back zones are too wide, backstabs become trivial because players circle; too narrow and they feel random under lag. Rule of thumb: back half-angle 40 to 60 degrees for melee, smaller for ranged.

**Lag makes this test unfair in one direction.** The server sees the victim's facing up to one round trip late. Victims turning to face an attacker get backstabbed after they visibly turned. Two fixes: compute the classification on the server using the victim's facing from a short history buffer at the attacker's view time (the lag compensation idea in [[Client Prediction and Reconciliation for Combat]]), or add hysteresis: once a victim has been "Front" for the attacker in the last 150 ms (rule of thumb), count borderline hits as "Front". The second is cheaper and players rarely notice.

**Characters with `AutoRotate` turn to their movement direction.** A player who strafes backwards with the default controller has their root facing away from where they look. If blocks should follow the camera, test against a replicated aim direction instead of `HumanoidRootPart.CFrame.LookVector` ([[Custom Character Controllers]]).

---

## 3. Steering left or right without jitter

An NPC or homing missile needs to know which way to turn. The sign of the Y component of a cross product gives it:

```lua
local turnSign = forward:Cross(toTarget).Y   -- > 0: target is to the left (counter-clockwise from above)
```

Check the sign with the axes: forward is `-Z`, left is `-X`. `(-Z):Cross(-X)` equals `Z:Cross(X)`, which is `+Y`. So positive means left, as stated.

The naive controller ("if positive turn left at full speed, else turn right") oscillates: near zero the sign flips every frame and the NPC shivers. Two fixes work together. First, scale the turn by the angle, not just its sign, and cap it by a turn rate. Second, never let one step overshoot.

```lua
--!strict
-- Rotate a flat forward vector toward a flat desired vector by at most maxRadians.
local function turnToward(forward: Vector3, desired: Vector3, maxRadians: number): Vector3
	local f = Vector3.new(forward.X, 0, forward.Z)
	local d = Vector3.new(desired.X, 0, desired.Z)
	if f.Magnitude < 1e-6 or d.Magnitude < 1e-6 then
		return forward
	end
	f, d = f.Unit, d.Unit
	-- Signed angle from f to d around +Y: atan2(cross.Y, dot) is exact and stable
	local angle = math.atan2(f:Cross(d).Y, f:Dot(d))
	local step = math.clamp(angle, -maxRadians, maxRadians) -- never overshoots
	return CFrame.fromAxisAngle(Vector3.yAxis, step):VectorToWorldSpace(f)
end

-- Per frame: forward = turnToward(forward, target - pos, math.rad(240) * dt)
```

`atan2(cross, dot)` is worth memorising. Using `acos(dot)` loses the sign, and `asin(cross)` loses precision near 90 degrees and cannot tell 30 from 150. The pair `(dot, cross)` is the cosine and sine of the same angle (scaled by the same lengths), so `atan2` recovers the full signed angle without normalising first.

A 180 degree case exists: target exactly behind. The cross is zero, the dot is -1, `atan2(0, -1)` returns pi, and the NPC turns left. That is fine, but in a crowd of NPCs all chasing a player who walks through them, they all turn the same way and look robotic. Add a per-NPC bias (a tiny random sign chosen at spawn) for exact ties.

---

## 4. Closing speed: homing, aggro and "is it getting away?"

The component of relative velocity along the line between two things is the rate at which their distance changes. It is negative when they approach.

```lua
--!strict
-- Rate of change of distance between a and b, in studs per second.
-- Negative: approaching. Positive: separating.
local function rangeRate(posA: Vector3, velA: Vector3, posB: Vector3, velB: Vector3): number
	local offset = posB - posA
	local dist = offset.Magnitude
	if dist < 1e-4 then
		return 0
	end
	return (velB - velA):Dot(offset / dist)
end
```

Uses:

- **Aggro leash.** An NPC chasing a player gives up when the player is beyond the leash **and** `rangeRate > 0` for a second. Players who stop at the edge to fight do not trigger the reset, players who kite away do.
- **Homing missiles that miss gracefully.** If `rangeRate` turns positive, the missile has passed the target. Stop steering and let it fly on, instead of letting it orbit the target forever (a classic bug when the turn rate is too low for the speed: the turning circle radius is `speed / turnRate`, and any target inside that circle cannot be hit).
- **Projectile damage by impact speed.** Falling rocks or rams that hurt in proportion to how hard they hit should use the normal component of relative velocity, `(vRock - vVictim):Dot(normal)`, not the speed. Grazing hits then do little, head-on hits do a lot.
- **Anti-cheat sanity.** A client claiming it closed 40 studs in 0.2 seconds implies a range rate of 200 studs per second; compare it to your movement caps with slack for latency ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]).

The lateral part of the relative velocity, the rest after removing the along-line part, is just as useful: a large lateral speed at short range means a dodge in progress, which is exactly when melee AI should hold its attack.

```lua
local rel = velB - velA
local along = dir * rel:Dot(dir)   -- dir is the unit offset from A to B
local lateral = rel - along
```

---

## 5. Lap progress and gate crossing

Racing and obby checkpoints want two numbers: how far along the course each player is (for positions on the leaderboard) and whether a player really passed through a gate.

**Progress along a segment** is the dot product with the segment direction, divided by its length:

```lua
--!strict
-- Returns t in [0, 1] along a segment from a to b, and the sideways distance from it.
local function segmentProgress(a: Vector3, b: Vector3, p: Vector3): (number, number)
	local ab = b - a
	local lenSq = ab:Dot(ab)
	if lenSq < 1e-8 then
		return 0, (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / lenSq, 0, 1)
	local closest = a + ab * t
	return t, (p - closest).Magnitude
end
```

For a whole track, store the checkpoint path as a polyline, keep each player's current segment index, and only search that segment and the next two each tick (rule of thumb). Searching every segment lets a player who crosses near a hairpin jump forward by a lap. Race position is then `lap * segmentCount + segmentIndex + t`.

**Gate crossing.** A gate is a plane: a point `g` and a normal `n` pointing in the race direction. The signed distance of a point `p` is `(p - g):Dot(n)`. Track the sign each tick. A change from negative to positive is a forward crossing, positive to negative a backward one. Then check that the crossing point lies inside the gate's width, because the plane is infinite:

```lua
--!strict
local function crossedGate(prev: Vector3, curr: Vector3, gate: CFrame, halfWidth: number, halfHeight: number): boolean
	-- Gate faces along its LookVector; its local X is width, Y is height
	local n = gate.LookVector
	local d0 = (prev - gate.Position):Dot(n)
	local d1 = (curr - gate.Position):Dot(n)
	if not (d0 < 0 and d1 >= 0) then
		return false
	end
	local t = d0 / (d0 - d1) -- fraction of the move where the plane is crossed
	local hit = prev + (curr - prev) * t
	local localHit = gate:PointToObjectSpace(hit)
	return math.abs(localHit.X) <= halfWidth and math.abs(localHit.Y) <= halfHeight
end
```

Testing "is the player inside a checkpoint part now?" fails at speed: a car at 150 studs per second moves 2.5 studs per 60 Hz frame and can skip a thin trigger, and server checks at lower rates skip more. The plane test with the previous and current position cannot be skipped. The same idea extends to the full swept tests in [[Intersection and Collision Math]].

---

## 6. Projections: slopes, walls and knockback

Every velocity can be split into a part along a normal and a part in the plane:

```lua
local intoSurface = n * v:Dot(n)     -- n is the unit surface normal
local alongSurface = v - intoSurface
```

Gameplay uses this split constantly:

- **Slope movement.** Custom controllers move along the ground by projecting the desired horizontal velocity onto the ground plane, then rescaling to the original speed. Without the rescale, players walk slower uphill and downhill in a way that feels like friction, which may be what you want. Decide on purpose.
- **Wall sliding.** When a character runs into a wall at an angle, remove only the into-wall component and keep the rest. If you zero the whole velocity, players "stick" to walls on contact. If you keep the full speed along the wall (rescale), they slide faster than they ran at it, which reads as a bug at shallow angles. Keeping `alongSurface` unscaled is usually right.
- **Knockback on uneven ground.** A knockback direction computed from attacker to victim has a vertical component when they stand at different heights, which sends victims into the floor (no effect) or the sky. Flatten it, apply your own vertical lift, and only then scale.
- **Ground clamping.** If `v:Dot(groundNormal) > 0` the character is leaving the ground. A small positive value on a ramp crest is when controllers detach and "ski jump". Clamping that component to zero while grounded keeps characters glued over crests.

Projection is order sensitive when you project onto two planes (floor and wall in a corner). Projecting onto the wall then the floor can reintroduce motion into the wall. The robust approach for two contacts is to move along their crease, the cross product of the two normals:

```lua
local crease = nFloor:Cross(nWall)
if crease.Magnitude > 1e-4 then
	crease = crease.Unit
	velocity = crease * velocity:Dot(crease)
end
```

---

## 7. Wall running and frames built from cross products

A wall run needs a direction along the wall, horizontal, matching where the player was heading. The wall normal comes from a raycast ([[Raycasts Shapecasts and Spatial Queries]]):

```lua
--!strict
local function wallRunDirection(wallNormal: Vector3, velocity: Vector3): Vector3?
	local along = wallNormal:Cross(Vector3.yAxis)
	if along.Magnitude < 1e-3 then
		return nil -- the "wall" is a floor or ceiling
	end
	along = along.Unit
	-- Two candidate directions along the wall; pick the one matching motion
	if along:Dot(velocity) < 0 then
		along = -along
	end
	return along
end
```

The `nil` case matters. A normal close to vertical is a floor or a ceiling, and its cross with world up is near zero, so normalising it would give NaN.

More generally, cross products build orthonormal frames from two loose directions. You often have a forward you care about and an up that is only roughly right (a surface normal, a camera up). Gram-Schmidt with cross products produces a clean frame:

```lua
--!strict
local function frameFromForwardUp(pos: Vector3, forward: Vector3, roughUp: Vector3): CFrame
	local back = -forward.Unit                   -- CFrame Z axis points backward
	local right = roughUp:Cross(back)
	if right.Magnitude < 1e-4 then
		-- forward parallel to roughUp: pick any other up
		right = Vector3.xAxis:Cross(back)
		if right.Magnitude < 1e-4 then
			right = Vector3.zAxis:Cross(back)
		end
	end
	right = right.Unit
	local up = back:Cross(right)                 -- exact, already unit
	return CFrame.fromMatrix(pos, right, up, back)
end
```

`CFrame.fromMatrix(pos, vX, vY, vZ)` takes the three axes (Roblox docs (as of October 2026)). Getting the order wrong produces a mirrored frame (a reflection, determinant -1), which the engine does not expect. The quick test: `right:Cross(up)` must equal `back` (that is, `+Z`), not `-back`.

This is what `CFrame.lookAt` does internally with world up, and why it is unstable looking straight up. Writing it yourself lets you choose the fallback, which is exactly what surface-aligned vehicles, spiders walking on walls and gravity-flipping obbies need.

---

## 8. Bounce pads and ricochets with friction

The reflection formula `v - 2 n (v . n)` gives a perfect mirror bounce. Real gameplay wants control over each part separately:

```lua
--!strict
-- restitution: 0 = no bounce, 1 = full bounce. friction: 0 = keep sliding speed, 1 = stop sliding.
local function bounce(v: Vector3, n: Vector3, restitution: number, friction: number): Vector3
	local vn = n * v:Dot(n)
	local vt = v - vn
	return vt * (1 - friction) - vn * restitution
end
```

Design traps:

- **Only bounce when moving into the surface.** If `v:Dot(n) >= 0` the object is already leaving. Bouncing it again on the next frame (because it is still overlapping) flips it back into the surface, and you get the "stuck vibrating" bug. Guard with the sign.
- **Bounce pads should usually not use reflection at all.** Players expect the same jump height however they land. Set the normal component to a fixed launch speed and keep the tangential part: `vt + n * launchSpeed`. Reflection makes pad height depend on fall height, which turns a pad into an unreliable puzzle.
- **Ricochet chance from angle.** `abs(v.Unit:Dot(n))` is the cosine of the incidence angle. Grazing hits (small value) ricochet, square hits (near 1) penetrate or stop. A threshold of about 0.3 (roughly 72 degrees from the normal) is a common starting point (rule of thumb).

---

## 9. Aim assist and target selection

Soft lock-on and controller aim assist pick "the target the player meant". The naive choice, the nearest enemy, picks the one behind you. Pure alignment, the largest dot product, picks a far enemy at the edge of the map that happens to be under the crosshair. A score that blends both is standard:

```lua
--!strict
type Candidate = { position: Vector3, id: number }

local MAX_RANGE = 80
local CONE_COS = math.cos(math.rad(25))

local function pickTarget(view: CFrame, candidates: { Candidate }): Candidate?
	local best: Candidate? = nil
	local bestScore = -math.huge
	for _, c in candidates do
		local offset = c.position - view.Position
		local dist = offset.Magnitude
		if dist > 1e-3 and dist <= MAX_RANGE then
			local align = view.LookVector:Dot(offset / dist)
			if align >= CONE_COS then
				-- Normalise each term to 0..1, then weight. Alignment dominates.
				local alignScore = (align - CONE_COS) / (1 - CONE_COS)
				local distScore = 1 - dist / MAX_RANGE
				local score = alignScore * 0.7 + distScore * 0.3
				if score > bestScore then
					bestScore, best = score, c
				end
			end
		end
	end
	return best
end
```

Remapping the dot from `[CONE_COS, 1]` to `[0, 1]` before weighting matters. Raw dot values inside a 25 degree cone only range from about 0.906 to 1, so unremapped they barely move the score and distance takes over.

Add **stickiness**: give the current target a bonus (for example +0.15) so selection does not flicker between two enemies standing side by side. Do line of sight last, only for the winner and maybe the runner-up, because raycasts cost far more than dot products. For PvP, aim assist decisions belong to the client for feel, but anything that grants damage is still validated on the server ([[Hitboxes and Hit Detection]]).

---

## 10. Edge cases and failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Backstabs register as side hits on slopes or jumps | Vertical component in the offset | Flatten before the dot |
| NPC shivers when facing its target | Turning by sign only, overshooting | `atan2(cross, dot)` and clamp the step |
| Missile circles the target forever | Turning circle larger than the miss distance | Stop steering when range rate turns positive, or raise turn rate |
| Checkpoint skipped at high speed | Overlap test instead of a swept plane test | Sign change of signed distance between ticks |
| Player sticks to walls on contact | Zeroing full velocity | Remove only the into-wall component |
| NaN after wall-run start on a floor | Normalising a near-zero cross product | Check magnitude, return `nil` |
| Mirrored model or inside-out lighting | Left-handed axes passed to `fromMatrix` | `right:Cross(up)` must equal +Z axis |
| Pad launches vary wildly | Reflection on bounce pads | Fixed normal launch speed |
| Aim assist ignores alignment | Unremapped dot values clustered near 1 | Remap within the cone first |
| Parallel test fails for long vectors | Absolute tolerance on an unnormalised cross | Scale the tolerance by both lengths |

Float notes. A dot product of two unit vectors can come out at `1.0000001`; feed that to `math.acos` and you get NaN. Clamp to `[-1, 1]` before `acos`, or avoid `acos` entirely by comparing against precomputed cosines. Cross products of nearly parallel vectors lose relative precision quickly, so `.Unit` on them amplifies noise into a wildly wrong direction even when it does not produce NaN: always pick a fallback below a threshold like `1e-3` rather than `1e-9`.

**Performance.** A dot product is three multiplies and two adds. It is never your bottleneck. `.Magnitude` costs a square root, `.Unit` a square root and a divide; they are still cheap, but in loops over hundreds of targets per frame compare squared distances (`offset:Dot(offset) < r * r`) and normalise only the survivors ([[Luau Performance Patterns with Benchmarks]]). Precompute cosines of fixed angles at module load.

## When not to use these tricks

- When the engine already answers the question with collision. A sword hitbox against a complex mesh is a spatial query, not a dot product.
- When designers need to tune shapes visually. A view cone in code is invisible; a wedge-shaped debug part, or a visualiser that draws the cone, saves hours of "why didn't it see me".
- When the answer must be robust to animation. "In front" by root facing ignores a character who is visibly twisted. For precise parries, use the weapon's own frame.

## Checklist

- [ ] Facing tests are done from the victim's frame and flattened for ground combat.
- [ ] Angle thresholds are precomputed cosines; no `acos` in hot paths.
- [ ] Signed angles use `atan2(cross, dot)`.
- [ ] Turn steps are clamped so they cannot overshoot.
- [ ] Every normalisation of a cross product has a fallback.
- [ ] Gates and checkpoints use previous and current positions, not overlap.
- [ ] Bounce code only acts when moving into the surface.
- [ ] Scores that mix dot and distance remap both to 0..1 first.
- [ ] Server-side facing checks account for latency.

## See also

[[Game Math Start Here]] · [[Math Vectors and CFrames]] · [[Cookbook - Math CFrame and Vectors]] · [[Rotations Angles and Quaternions]] · [[Intersection and Collision Math]] · [[Custom Character Controllers]] · [[Hitboxes and Hit Detection]] · [[Combat Systems Architecture]] · [[Projectiles and Ballistics]] · [[NPC AI and Behaviour]] · [[Look-At Aim and Head Tracking]] · [[Genre Playbook - Racing and Driving]]

## Connected notes
<!-- auto-links:start -->
[[Two-Bone IK Math]] · [[Racing Laps and Checkpoints End to End]] · [[Motor6D Math and CFrame Composition]] · [[Mover Constraints and Physics Controllers]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]] · [[Elbow Poles Swivel and Joint Limits]]
<!-- auto-links:end -->
