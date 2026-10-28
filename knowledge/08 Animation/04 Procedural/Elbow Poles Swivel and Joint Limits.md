---
tags: [procedural, ik, arms, wrist, swing-twist, viterbi, limits, quality]
---
# Elbow Poles Swivel and Joint Limits

<!-- tldr:start -->
> [!tldr] TL;DR
> - Elbow flips sides between frames: per-frame best candidate -> continuity cost, search near last frame, Viterbi offline
> - Wrist flips 170 degrees in one frame: twist wrapped at +-180 then clamped -> unwrap twist against last frame before clamping
> - Thrust looks like a broken wrist: wrist asked to aim the blade -> aim with the arm; wrist limits force it
>
> Read more (16 KB note): ## Swing/twist decomposition · ## Continuity: Viterbi over the whole clip · ## Common mistakes
<!-- tldr:end -->

A two-bone solver puts the hand on the target. It does not make the arm look human. That depends on three choices the solver leaves open: **which way the elbow points** (the pole or swivel), **how much the wrist is allowed to do** (limits on flex, deviation and twist), and **how those choices change from frame to frame** (continuity). This note covers all three with the numbers one live action game (the reference project) arrived at after baking and scoring a few hundred attack clips.

## Pole vs swivel

- A **pole** is a point the elbow bends toward. Simple, intuitive, and fine when the hand moves in a small region.
- A **swivel angle** `psi` is the elbow's rotation around the shoulder-wrist axis, measured from a reference direction (for example "straight down, projected perpendicular to the arm line"). It is the same degree of freedom as a pole, expressed as one number, which makes it easy to search, smooth and score.

A pole breaks when the hand passes near it: the projection of the pole onto the plane perpendicular to the arm shrinks to nothing and its direction flips. A swivel angle has no such singularity as long as its reference direction is not parallel to the arm line, and you can unwrap and smooth it like any angle.

[[Two-Bone IK Math]] shows how `psi` enters the solve.

## Which way should the elbow point?

The reference project's arm baker expressed preferred elbow directions in the chest frame (for the right arm, "out" = +X) and blended them by motion type. These are soft preferences: wrist comfort and body clearance can override them.

| Motion | Preferred elbow direction (weights) |
|---|---|
| default | down 1.0, out 0.45, back 0.35 |
| hand above the shoulder | out 0.8, down 0.25, forward 0.25 |
| hand across the body | down 1.0, forward 0.55, out 0.15 |
| two-handed | down 1.0, out 0.25, back 0.1 |

The preference cost was `1.4 * (1 - cos(psi))`, with `psi` measured from the preferred direction: zero when the elbow points the preferred way, 2.8 when it points the opposite way, gentle near the preference (a cosine is flat at its peak).

What the wrong choice looks like:

| Read on screen | Geometry | Project's QA rule |
|---|---|---|
| **Chicken wing** (broken-looking, elbow cocked up and out) | elbow above the shoulder while the hand hangs below it | flagged when the elbow is more than 0.55 studs above the shoulder for 0.15 s; the solver's cost: `3 * ((elbowUp - 0.35) / 0.4)^2` while the hand is below the elbow |
| **Arm behind the back** | upper arm swung far behind the frontal plane | flagged past 48 degrees behind the plane when raised, 62 when low; solver cost `((back - 42 deg) / 8 deg)^2` |
| **Elbow in the ribs** | elbow swivelled into the torso | capsule-vs-box penetration, cost `220 * (depth - 0.08)^2` |
| **Elbow flip** | swivel jumps between two equally good sides | flagged over 30 degrees per 60 Hz frame while the elbow is bent over 40 degrees and more than 0.45 studs off the arm line; critical over 70 |

## Joint limits

### The numbers in one place

| Joint | Value | Source and purpose |
|---|---|---|
| Elbow hinge range | 0.06 to 2.55 rad (about 3 to 146 deg) | offline arm solver (never fully straight: a straight arm has no defined swivel) |
| Elbow flexion bound | 0 to 150 deg | spec baker's coordinate-descent bounds; QA "flexion max 150" |
| Elbow hyperextension | flagged over 8 deg, critical over 15 | QA |
| Elbow sideways | flagged over 20 deg | QA (only possible with a non-hinge solve) |
| Shoulder (sx, sy, sz) | -110..215, -120..120, -70..170 deg | spec baker's bounds (degrees, its own Euler convention) |
| Wrist (bake clamp) | flex 70, deviation 30, twist 85 deg | arm baker, "natural range" |
| Wrist (QA flags) | flex 75, deviation 40, twist 95 deg | deliberately looser than the bake so clamped bakes do not flag themselves |
| Wrist (natural-arm solver) | flex 65, deviation 27, twist 85 deg | the earlier in-Studio solver |
| Wrist (legacy solver `wristLim`) | bend 62, twist 100 deg by default; 82 / 118 for cuts, guards and cleaves | the first IK toolkit |
| Wrist snap | over 30 deg per 60 Hz frame relative to the forearm | QA |

The different wrist sets are not a contradiction so much as a history (see [[Open Questions]]): the limits tightened as the scoring got better, and QA sits deliberately above the bake.

### Why flex and deviation differ

A human wrist bends much further palm-ward and back-ward (flexion/extension) than side to side (radial/ulnar deviation). A single cone (like a `BallSocketConstraint` with one `UpperAngle`) treats them the same. A good limit model splits the wrist rotation into **swing** (the bend, split into flex and deviation components) and **twist** (roll about the forearm), and limits each separately.

The project's single most useful rule came out of this: **a wrist cannot aim a blade.** Lining a blade up with the forearm (as in a thrust) needs about 90 degrees of deviation, three times the comfortable range. The arm must aim the blade; the wrist only refines it.

## Swing/twist decomposition

Take the wrist's local rotation `q` (the hand relative to the forearm, as a unit quaternion `(w, x, y, z)`), with the forearm along the hand's Y axis. Split it as `q = swing * twist`, where `twist` is a rotation about Y and `swing` has no Y component.

```
twist angle:  tw = 2 * atan2(y, w)         (wrapped to [-pi, pi])
twist quat:   t  = (cos(tw/2), 0, sin(tw/2), 0)
swing quat:   s  = q * conj(t)
            = (w c + y s', x c + z s', y c - w s', z c - x s')   with c = cos(tw/2), s' = sin(tw/2)
```

The Y component `y c - w s'` is zero by construction, so the swing axis lies in the hand's XZ plane. Write the swing as angle `a` about unit axis `(ax, 0, az)`. Then

```
flex       = a * az      (bend about the hand's Z)
deviation  = a * ax      (bend about the hand's X)
```

Rebuild with `swing = rotation of sqrt(flex^2 + dev^2) about (dev, 0, flex).Unit`, then `q = swing * twist`.

```lua
--!strict
-- Swing/twist split of a wrist rotation, forearm along the hand's Y axis.
-- Returns flex (about Z), deviation (about X), twist (about Y), radians.
local function wristParts(r: CFrame): (number, number, number)
	local axis, angle = r:ToAxisAngle()
	local sh = math.sin(angle / 2)
	local w, x, y, z = math.cos(angle / 2), axis.X * sh, axis.Y * sh, axis.Z * sh
	local tw = 2 * math.atan2(y, w)
	tw = (tw + math.pi) % (2 * math.pi) - math.pi
	local c, s = math.cos(tw / 2), math.sin(tw / 2)
	local sw, sx, sz = w * c + y * s, x * c + z * s, z * c - x * s     -- swing (its y part is 0)
	if sw < 0 then sw, sx, sz = -sw, -sx, -sz end                      -- shortest form
	local vn = math.sqrt(sx * sx + sz * sz)
	if vn < 1e-9 then return 0, 0, tw end
	local a = 2 * math.atan2(vn, sw)
	return a * sz / vn, a * sx / vn, tw
end

local function wristMake(flex: number, dev: number, tw: number): CFrame
	local a = math.sqrt(flex * flex + dev * dev)
	local swing = if a > 1e-9 then CFrame.fromAxisAngle(Vector3.new(dev, 0, flex) / a, a) else CFrame.identity
	return swing * CFrame.fromAxisAngle(Vector3.yAxis, tw)
end

-- Clamp to limits. prevTwist (optional): last frame's unclamped twist, used to unwrap so the twist
-- holds at its limit instead of jumping from +limit to -limit when the real twist passes 180 degrees.
local function clampWrist(r: CFrame, lim: { flex: number, dev: number, twist: number }, prevTwist: number?)
	local f, d, t = wristParts(r)
	if prevTwist then
		t = prevTwist + ((t - prevTwist + math.pi) % (2 * math.pi) - math.pi)   -- continuous twist
	end
	local excess = math.max(0, math.abs(f) - lim.flex) + math.max(0, math.abs(d) - lim.dev)
		+ math.max(0, math.abs(t) - lim.twist)
	local clamped = wristMake(math.clamp(f, -lim.flex, lim.flex), math.clamp(d, -lim.dev, lim.dev),
		math.clamp(t, -lim.twist, lim.twist))
	return clamped, excess, t
end
```

`excess` is what the clamp cost you, in radians. Price it (the project used `(excess / 12 deg)^2`) instead of silently discarding it. The **continuous clamp** matters: without unwrapping, a hand whose true twist drifts past 180 degrees jumps from +85 to -85 in one frame, the classic "wrist flips over" pop. The project's flip guard also spread any limit-to-limit twist jump over plus or minus 4 frames.

Independent clamps make a rectangle in the (flex, deviation) plane; real wrists are closer to an ellipse. If corners look strained, clamp `(f / lim.flex, d / lim.dev)` to the unit circle instead.

## The swivel search

Because the solve is exact for any `psi`, you can afford to try many and score them. The project's offline baker, per 60 Hz frame:

- **Candidates**: 24 hand rolls about the blade x 36 elbow swivels (10-degree steps). (An older header says 16 x 24; the code and defaults use 24 x 36. See [[Open Questions]].)
- **Each candidate**: exact two-bone solve on the slanted R15 bones with a pure-hinge elbow, then the wrist clamped to 70 / 30 / 85 with the continuous clamp.
- **Unary costs** (per candidate):
  - blade and grip, held hand: `imp * ((dirDev / 6 deg)^2 + (miss / 0.12)^2) + (1 - imp) * 0.25 * ((dirDev / 14)^2 + (miss / 0.3)^2)`, where `imp` (importance) is 1 near markers, on fast cuts and in holds, 0.25 elsewhere
  - roll away from the original edge: `0.6 * imp * (roll / 70 deg)^2`
  - wrist excess `(ex / 12 deg)^2` plus comfort `0.25 * ((flex / 70)^2 + (dev / 30)^2 + (twist / 85)^2)`
  - elbow direction `1.4 * (1 - cos(psi))`; elbow near its ends (under 0.18 or over 2.35 rad)
  - arm capsules in the torso and head boxes `220 * (depth - 0.08)^2`; behind the back; across behind the body +4; chicken wing

The weights encode taste: a 6-degree blade-direction error where it matters costs the same as a 0.12-stud grip miss, and both cost much more than an unusual elbow. Change them and the style changes.

## Continuity: Viterbi over the whole clip

Picking the cheapest candidate independently per frame flickers: two swivels 120 degrees apart can score within a hair of each other, and the winner alternates. The fix is to choose the **sequence** of candidates with the lowest total of unary costs plus **transition costs**, which is a shortest-path problem solved exactly by dynamic programming (the Viterbi algorithm).

The project's transition cost between consecutive frames:

```
0.5 * (dSwivel / 10 deg)^2 + 0.35 * (dRoll / 12 deg)^2
+ 30 if dSwivel > 25 deg      + 20 if dRoll > 50 deg
+ 1.2 * (clamped-wrist change / 10 deg)^2 + 0.8 * (elbow travel / 0.15 studs)^2
```

The quadratic terms prefer smooth change; the flat +30 / +20 penalties make a big jump cost the same however it happens, so the path only jumps when staying would be far worse.

```lua
--!strict
-- Viterbi: the lowest-cost path through per-frame candidates.
-- unary[f][k]: cost of candidate k at frame f. trans(f, a, b): cost of going a (frame f-1) -> b (frame f).
local function viterbi(unary: { { number } }, trans: (number, number, number) -> number): { number }
	local nF, nK = #unary, #unary[1]
	local cost = table.clone(unary[1])
	local back: { { number } } = {}
	for f = 2, nF do
		local nextCost = table.create(nK, 0)
		local bk = table.create(nK, 1)
		for b = 1, nK do
			local best, arg = math.huge, 1
			for a = 1, nK do
				local c = cost[a] + trans(f, a, b)
				if c < best then best, arg = c, a end
			end
			nextCost[b] = best + unary[f][b]
			bk[b] = arg
		end
		back[f] = bk
		cost = nextCost
	end
	local path = table.create(nF, 1)
	local best = math.huge
	for k = 1, nK do
		if cost[k] < best then best, path[nF] = cost[k], k end
	end
	for f = nF, 2, -1 do
		path[f - 1] = back[f][path[f]]
	end
	return path
end
```

Cost is `frames x K^2`. With K = 864 (24 x 36) that is about 750,000 transitions per frame: fine offline in vectorised numpy (the project's bakes took 40 s to 3 min per move including repair rounds), far too slow in Luau at runtime. For runtime, restrict transitions to neighbours (only candidates within a few steps of each other), which makes it nearly linear in K.

After Viterbi, the project **unwrapped** the chosen roll and swivel curves, **Gaussian-smoothed** them (sigma 1 frame) and **solved again exactly** on the smoothed curves, so the final arm moves continuously rather than in 10-degree steps. Then it smoothed in joint space (sigma 0.8 frames where the blade mattered, 3.5 elsewhere; "blending two natural joint poses traces an arc"), and ran a flip guard: any joint turning more than 45 degrees in one 60 Hz frame was re-routed by a smoothstep slerp over plus or minus 4 frames (growing to 12 if needed).

## A runtime version

At runtime you have one frame, not a clip. Keep the spirit:

```lua
-- Choose a swivel near last frame's: a handful of candidates, unary cost + continuity.
-- solveAt(psi) -> (wristRotation: CFrame, miss: number, elbowWorld: Vector3); prefer: preferred psi (radians).
local function chooseSwivel(prevPsi: number, prefer: number, solveAt: (number) -> (CFrame, number, Vector3),
	lim: { flex: number, dev: number, twist: number }): number
	local bestPsi, bestCost = prevPsi, math.huge
	for k = -6, 6 do
		local psi = prevPsi + math.rad(10) * k                 -- +-60 degrees around last frame
		local wristR, miss = solveAt(psi)
		local _, excess = clampWrist(wristR, lim)
		local cost = (excess / math.rad(12)) ^ 2              -- wrist strain
			+ 1.4 * (1 - math.cos(psi - prefer))              -- elbow direction preference
			+ 0.5 * k * k                                     -- continuity: 0.5 * (dPsi / 10 deg)^2
			+ (miss / 0.12) ^ 2                               -- reach
		if cost < bestCost then bestPsi, bestCost = psi, cost end
	end
	return bestPsi
end
```

Then smooth `psi` with a critically damped spring (see [[Springs Damping and Smoothing]]) before the final solve. The search window around last frame's value is itself a continuity constraint: the arm cannot jump to the far side in one frame.

## Lessons from the bakes (pose rules)

These were written down after the scoring showed where criticals came from. They apply to hand-keyed and IK'd arms alike.

- Arms go behind the body in sprint, surf and "load" poses. Sprint-to-thrust and sprint-to-cross-cut lead-ins drive the forearm into the torso: use a flat wind-up before thrusts and cuts.
- Backhand winds and two-handed low guards put the forearm across the chest.
- Long pommels: make overheads, drives and kneels one-handed with the off hand out to the side; keep hands further from the body; carry the blade over the front before every drive (the "chop" key).
- Big root-yaw swaps every 0.1 s pop. Halve the root yaw in flurries and turn the waist more.
- The last key should be the rest pose (arms hanging like the idle). The idle takes over the instant a one-shot ends: last frame within 75 degrees of the idle, first within 90.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Elbow flips sides between frames | per-frame best candidate | continuity cost, search near last frame, Viterbi offline |
| Wrist flips 170 degrees in one frame | twist wrapped at +-180 then clamped | unwrap twist against last frame before clamping |
| Thrust looks like a broken wrist | wrist asked to aim the blade | aim with the arm; wrist limits force it |
| Chicken wings on low guards | pole fixed "out" for all motions | pole per motion type |
| Clamped arm misses the target and nobody notices | clamp result discarded | return and price the excess and the miss |
| Smooth swivel, still jittery arm | smoothing the output Transforms, not the parameters | smooth `psi` and roll, then solve exactly |

Related: [[Two-Bone IK Math]], [[Inverse Kinematics]], [[Arm Baker Internals]], [[Arm QA Metrics Reference]], [[Pipeline - Arm IK Baking and QA]], [[Weapon Swing Design]].

## Connected notes
<!-- auto-links:start -->
[[Animation Quality Standard]] · [[Snippets - IK]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[IKControl Reference]] · [[Skinning Weights]] · [[Topology and Edge Flow]] · [[Animation Start Here]]
<!-- auto-links:end -->
