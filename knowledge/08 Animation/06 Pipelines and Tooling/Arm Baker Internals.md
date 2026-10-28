---
tags: [pipeline, ik, arms, baking, algorithms, advanced]
---
# Arm Baker Internals

<!-- tldr:start -->
> [!tldr] TL;DR
> - One shared set of key times per arm (all three joints of a side keyed together: each key costs 3 Poses, and separate times...
> - Tolerance: shoulder 1.0, elbow 1.2, wrist 1.5 deg, times a tolerance scale.
> - Spans are at most 0.4 s long and must turn less than 120 deg (the Animator's interpolation becomes ambiguous for big turns).
> - Sometimes the best fix is to steer the solve: edit arm CFrames over time windows in a copy of the clip dump, then bake with...
>
> Read more (30 KB note): ## Stage 2: target shaping · ## Stage 3: the candidate grid
<!-- tldr:end -->

The algorithms inside the offline arm baker ("posebaker") of one live action game, at the level of detail you need to rebuild it: how targets are derived, how importance is computed, how the body clearance push works, the candidate grid, every unary and transition cost, the Viterbi pass, smoothing, the off-hand contexts, the flip guard, key fitting, body thinning, instance budgets, repair rounds, re-keyed sources and outputs. Workflow and pass rules: [[Pipeline - Arm IK Baking and QA]]. The metrics it optimises for: [[Arm QA Metrics Reference]].

All constants are the production values. Space is HumanoidRootPart space of a 1.6x R15 rig (+X right, +Y up, -Z forward); the solve runs on a dense **60 Hz** grid of `F = round(length * 60) + 1` frames.

## Contract: what is kept, what is re-solved

| Kept exactly | Re-solved |
|---|---|
| every hips (LowerTorso: root path and turn), torso, head and leg key | RightUpperArm, RightLowerArm, RightHand |
| all keyframe times | LeftUpperArm, LeftLowerArm, LeftHand |
| every marker and the keyframes carrying them | |
| timing and length | |

The body is optionally **thinned** (fewer keys, same playback within tolerance) to make room for arm keys, but never changed beyond that tolerance. The output is deterministic: the same dump and options give the same clip.

## Stage 0: sample the original as the Animator plays it

The source clip is sampled at 60 Hz through the offline Animator model (rotation-vector blend between keys, easing from the segment's first pose, legacy Cubic reversed; see [[How the Animator Really Behaves]]). Joints the clip does not key take the idle's first-keyframe pose, because in game the idle shows through there. FK gives every part's world frame per frame. From the right hand:

- `g0`: the grip point (0.19 hand-widths below the hand centre along its Y);
- `d0`: blade direction (the hand's -Z);
- `e0`: edge direction (the hand's -X);
- tip = grip + d0 x 7.6 (the 80% of the 9.5-stud blade in front of the hand), and the tip speed per frame.

## Stage 1: importance

Importance (0..1 per frame) decides where the original blade must be honoured exactly and where the solver may improve the motion.

```
imp = 0.25                                               -- baseline
imp = max(imp, exp(-0.5 * ((t - markerT) / 0.07)^2))     -- every marker: about 1 within +-0.05 s, 0.5 at +-0.08
cut = clamp((gauss(tipSpeed, 2) - 18) / 20, 0, 1)        -- ramps in from 18 to 38 studs/s of tip speed
imp = max(imp, cut)
hold = 0.8 on runs where gauss(tipSpeed, 3) < 4 studs/s for 0.15 s or more
imp = max(imp, hold)
snap frames away from markers (> 0.09 s): imp = 0.15;  near markers: imp = min(imp, 0.5)
imp = clamp(gauss(imp, 2 frames), 0, 1)
```

**Snap detection** (frames marked +-2 around the event):

- blade snap: blade direction turns more than 25 deg in one frame **and** more than 3x the larger of the turns two frames before and after (floor 2 deg);
- grip teleport: the grip moves more than 0.45 studs in one frame **and** more than 2.5x the local median step (frames 2-6 away on each side; floor 0.08).

Isolated snaps in the source are usually authoring accidents (a flipped key, a wrong-way interpolation), so the solver is told not to follow them, except near markers where a snap may be an intended impact.

## Stage 2: target shaping

### Drag (successive breaking)

Where the chest turns fast, the hand should trail it a little. With `chestW` = chest angular speed (deg/s, smoothed sigma 3 frames):

```
lag = clamp((chestW - 150) / 350, 0, 1) * 3 * (1 - imp)     -- 0 frames below 150 deg/s, 3 frames (50 ms) at 500+
```

Grip, direction and edge are resampled at `frame - lag` (fractional, linear interpolation), then lightly smoothed (sigma 1 frame). Heavier arcs are made later in joint space, where blending two natural poses stays natural; smoothing positions here would cut corners through the body.

### Body clearance push

Grip targets inside the torso, hips or head are pushed out of the box, expanded by a margin (boxes at 94% of the part size):

| Box | First pass margin (smoothed) | Repair margin (level 2+) | Final hard margin |
|---|---|---|---|
| UpperTorso (chest) | 1.2 | 1.7 | 0.7 |
| LowerTorso (hips) | 0.95 | 1.4 | 0.6 |
| Head | 1.3 | 1.7 | 0.6 |

For each point inside an expanded box, candidate exits and their costs (the distance to travel to the face):

| Exit | Allowed | Cost |
|---|---|---|
| front (-Z) | always | distance |
| left / right (X) | always (head: only the hand's own side) | distance |
| up (+Y) | always | distance x 2.5 |
| down (-Y) | not for the head | distance x 2.5 |
| back (+Z) | only if the point is already in the back 35% of the box | distance |

Vertical exits cost 2.5x because a hand thrown over the head reads worse than a hand moved forward. Then the blade decides: for each candidate exit, 12 points along the blade from 0.6 to 7 studs are tested against the box (expanded 0.15); **an exit that would leave the blade through this body part costs +6**. The cheapest exit wins.

The displacement is smoothed over time (sigma 3 frames) so a target sliding past a box corner never jumps from one face to another. On repair frames (level 2+) a larger unsmoothed push (sigma 1.5) is blended in by the repair weight. Finally a hard pass with the small margins guarantees the target itself is clear.

### Blade clearance turn

If the blade line (10 points from 1.3 studs to the tip) runs through the chest, hips or head (boxes at 90% plus 0.12), the blade direction is turned by the **least** angle that clears it: angles 10, 20 ... 70 deg about 8 axes square to the blade (45 deg apart). The clearing direction is blended in with weight `1 - 0.7 * imp` (so 30% strength where the blade matters most), then smoothed (sigma 2 frames). That is how a choreography that stabbed its own chest becomes one that stabs just past it.

### Two-handed detection

The hilt line runs from 2.2 studs behind the grip to 0.6 ahead along the blade. The original left hand is "on the hilt" when it is within **1.3 studs** of that line; runs of **0.15 s or longer** count, dilated by 3 frames (0.05 s). A kit attribute `TwoHanded` (or the `--two-handed` flag) forces the whole clip. The mask is smoothed (sigma 3) into a 0..1 weight `two`.

## Stage 3: the candidate grid

Per frame and per arm: **24 hand rolls** (15 deg steps) about the blade **x 36 elbow swivels** (10 deg steps) about the shoulder-wrist line = 864 candidates. (One source file's header says 16 x 24; the code and defaults use 24 x 36. See [[Open Questions]].)

### Roll

Roll 0 is the original edge: the base hand rotation is built with the blade along -Z and the edge toward -X:

```lua
local function handRot(dir: Vector3, edge: Vector3): CFrame
	local z = -dir.Unit
	local x = -(edge - z * edge:Dot(z)).Unit     -- edge made square to the blade
	local y = z:Cross(x)
	return CFrame.fromMatrix(Vector3.zero, x, y, z)
end
```

Each candidate rotates that frame about the blade by its roll. The grip point fixes where the hand is; the hand rotation then fixes where the wrist pivot must be.

### Exact two-bone IK on slanted R15 bones

R15 bones are not straight lines between pivots (the attachment frames are offset and rotated), so the textbook law-of-cosines solution does not apply directly. The baker uses a table instead:

- In the shoulder joint's frame, the elbow pivot sits at `Ru * b1` and the wrist pivot at `Ru * (b1 + MR * Rx(theta) * wl)`, where `Ru` is the shoulder rotation and `theta` the elbow angle.
- The shoulder-to-wrist **distance depends only on theta**, so it is tabulated once (2,000 samples over 0.02-2.75 rad, checked monotone).
- For a target, theta comes from inverting the table (clamped to 0.06-2.55 rad, about 3-146 deg).
- The elbow then lies on a circle around the shoulder-wrist line. The swivel angle `psi` picks the point on that circle, measured from the preferred elbow direction projected off the line.
- `Ru` is the rotation that carries the rest triad (wrist vector, elbow vector) onto the target triad.

The elbow is written as a pure hinge, `Rx(theta)`, so the solution can never bend backwards or sideways. A Luau version of the same solve:

```lua
-- One-time setup from the rig's attachments (right arm shown)
local a1U = RightUpperArm.RightShoulderRigAttachment.CFrame   -- shoulder pivot, in the upper arm
local a0L = RightUpperArm.RightElbowRigAttachment.CFrame      -- elbow pivot, in the upper arm
local a1L = RightLowerArm.RightElbowRigAttachment.CFrame      -- elbow pivot, in the forearm
local a0H = RightLowerArm.RightWristRigAttachment.CFrame      -- wrist pivot, in the forearm
local b1 = a1U:PointToObjectSpace(a0L.Position)               -- elbow pivot in the shoulder joint frame
local MR = (a1U:Inverse() * a0L).Rotation                     -- elbow joint frame relative to the shoulder joint frame
local wl = a1L:PointToObjectSpace(a0H.Position)               -- wrist pivot in the elbow joint frame

local N = 2000
local thetaTab, distTab = table.create(N), table.create(N)
for i = 1, N do
	local th = 0.02 + (2.75 - 0.02) * (i - 1) / (N - 1)
	thetaTab[i] = th
	distTab[i] = (b1 + MR:VectorToWorldSpace(CFrame.Angles(th, 0, 0):VectorToWorldSpace(wl))).Magnitude
end

local function thetaFor(d: number): number
	-- distTab falls as theta grows: binary search, then interpolate
	if d >= distTab[1] then return 0.06 end
	if d <= distTab[N] then return 2.55 end
	local lo, hi = 1, N
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if distTab[mid] > d then lo = mid else hi = mid end
	end
	local u = (distTab[lo] - d) / (distTab[lo] - distTab[hi])
	return math.clamp(thetaTab[lo] + (thetaTab[hi] - thetaTab[lo]) * u, 0.06, 2.55)
end

local function frameOf(a: Vector3, b: Vector3): CFrame        -- right-handed triad from two vectors
	local x = a.Unit
	local n = a:Cross(b).Unit
	return CFrame.fromMatrix(Vector3.zero, x, n, x:Cross(n))
end

-- jointFrame = UpperTorso.CFrame * RightShoulderRigAttachment(on UpperTorso).CFrame (before the Transform)
-- wristTarget: world wrist pivot; poleDir: world direction psi = 0 points the elbow toward; psi: swivel (rad)
local function solveArm(jointFrame: CFrame, wristTarget: Vector3, poleDir: Vector3, psi: number): (CFrame, number)
	local u = jointFrame:PointToObjectSpace(wristTarget)
	local th = thetaFor(u.Magnitude)
	local v = b1 + MR:VectorToWorldSpace(CFrame.Angles(th, 0, 0):VectorToWorldSpace(wl))
	local uh = u.Unit
	local cosA = v.Unit:Dot(b1.Unit)
	local sinA = math.sqrt(math.max(0, 1 - cosA * cosA))
	local ref = jointFrame:VectorToObjectSpace(poleDir)
	ref = (ref - uh * ref:Dot(uh)).Unit
	local r2 = uh:Cross(ref)
	local lb = b1.Magnitude
	local e = uh * (lb * cosA) + (ref * math.cos(psi) + r2 * math.sin(psi)) * (lb * sinA)
	local Ru = frameOf(uh * v.Magnitude, e) * frameOf(v, b1):Inverse()
	return Ru, th          -- shoulder Transform = Ru (rotation only); elbow Transform = CFrame.Angles(th, 0, 0)
end
```

### Wrist clamp

The wrist Transform needed to put the hand at the candidate rotation is computed, split by swing-twist about the hand's Y into flexion (about Z), deviation (about X) and twist (about Y), and clamped to the natural range **flex 70, deviation 30, twist 85 deg**. Whatever the clamp removes shows up as blade direction error and grip miss, which the costs then price. The clamped hand's actual grip and blade direction are recomputed from FK.

## Stage 4: unary costs (per candidate, per frame)

`hold = 1 - free` (a free hand is the off hand with no blade to aim). Angles in degrees unless shown.

| Term | Formula |
|---|---|
| blade and grip (held hand) | `hold * ( imp * ((dirDev/6)^2 + (miss/0.12)^2) + (1-imp) * 0.25 * ((dirDev/14)^2 + (miss/0.3)^2) )` |
| free hand position | `free * (miss/0.25)^2` |
| roll away from the original edge | `hold * imp * (roll / 70)^2 * rollW` (rollW 0.6 sword hand, 0.2 off hand) |
| wrist excess past the clamp | `hold * (excessDeg / 12)^2` |
| wrist comfort | `0.25 * ((flex/70)^2 + (dev/30)^2 + (twist/85)^2)` |
| elbow direction preference | `1.4 * (1 - cos(psi))` |
| elbow near its ends | `200 * max(0, 0.18 - theta)^2 + 200 * max(0, theta - 2.35)^2` (radians: a locked-straight or folded-shut elbow) |
| arm capsules in torso / hips / head | `220 * penMul * max(0, depth - 0.08)^2` |
| arm behind the back | `(max(0, backDeg - 42) / 8)^2` |
| arm across behind the body | `+4` when the arm direction has x < -0.25 and z > 0.2 (chest frame, mirrored for the left) |
| chicken wing | `3 * (max(0, elbowUp - 0.35) / 0.4)^2` while the wrist hangs more than 0.3 below the elbow |

Capsules here match QA exactly: upper arm on its own axis from 0.6 below the top to 0.35 above the bottom (4 points), forearm 0.3 inside each end (4 points), both radius 0.85 x half width; the hand radius 0.8 x half width; boxes at 94% (torso, hips) and 86% (head). `penMul` is 1 normally and 1 + 10 x repair weight on repair frames (x11).

### The preferred elbow direction (pole)

Soft preferences in the chest frame (x = out for the right arm, -x for the left; +y up; +z back):

| Motion | Vector (out, up, back) | Reads as |
|---|---|---|
| default | (0.45, -1.0, 0.35) | down, a little out and back |
| hand above the shoulder | (0.8, -0.25, -0.25) | out, slightly down and forward (never straight up) |
| hand across the body | (0.15, -1.0, -0.55) | down and forward, leading in front of the chest |
| two-handed | (0.25, -1.0, 0.1) | down and close |

Blending: `wHigh = clamp((handY - (shoulderY + 0.3)) / 1.5, 0, 1)`, `wAcross = clamp(-out * handX / 1.2, 0, 1) * (1 - wHigh)`, then `pole = base * (1 - wHigh - wAcross) + high * wHigh + across * wAcross`, replaced by the two-handed vector where `two > 0.5`. Swivel 0 points the elbow along this pole, so the `1 - cos(psi)` term pulls toward it. Wrist comfort and clearance override it freely.

## Stage 5: Viterbi over the whole clip

A per-frame argmin flips between nearly equal candidates. Instead, the baker finds the cheapest path through all frames with dynamic programming. With `dSwivel` and `dRoll` the wrapped grid distances in degrees between two candidates:

```
transition = 0.5 * (dSwivel / 10)^2 + 0.35 * (dRoll / 12)^2
           + (dSwivel > 25 and 30 or 0) + (dRoll > 50 and 20 or 0)
           + 1.2 * |clampedWrist(f) - clampedWrist(f-1)|^2 / (10 deg)^2      -- 3-vector of flex, dev, twist
           + 0.8 * (|elbowPos(f) - elbowPos(f-1)| / 0.15 studs)^2
```

So a swivel change of about 10-15 deg per frame is nearly free, more than 25 deg is expensive, and any jump is also priced by how far the elbow actually travels and how much the **clamped** wrist (the wrist as it will really move) changes. Accumulated cost is `acc[f] = min over previous (acc[f-1] + transition) + unary[f]` across 864 x 864 transitions per frame; the path is recovered by backtracking.

### Continuous refinement

The chosen roll and swivel sequences are unwrapped, Gaussian-smoothed (sigma 1 frame) and solved again exactly (`finalize`). The wrist twist goes through a **continuous clamp**:

1. For each frame, pick the representation of the wanted twist (`t`, `t + 2pi`, `t - 2pi`) minimising `|clamped - previousClamped| + 6 * |t - clamped| + 0.01 * |k|`. A wanted twist passing +-180 deg therefore holds at its limit instead of flipping to the opposite limit, and returns once holding costs more than turning.
2. Any remaining limit-to-limit jump over 60 deg in one frame is replaced by a smoothstep from 4 frames before to 5 after (up to 20 passes). This removed the 166-229 deg one-frame wrist snaps seen in near-budget bakes.

Free hands blend their wrist toward a relaxed pose (flex 16 deg toward the palm, 7 deg ulnar deviation, no twist) by the free weight.

## Stage 6: the off hand

The left arm is solved after the right, with the same grid machinery (`rollW` 0.2), from one of three kinds of target, blended per frame:

1. **On the hilt** (weight `two`): 1.15 studs below the solved right hand along the solved blade, rolled 180 deg about the blade so both palms wrap the handle from the same side. Its direction is the right blade; its edge reference is the right hand's +X. Pushed out of the body (margins 0.9 / 0.8 / 1.0, smoothed).
2. **Its own path** (default): the original left hand centre, pushed out of the body (0.95 / 0.8 / 0.75 smoothed, then 0.7 / 0.6 / 0.6 hard).
3. **A context behaviour** where the original is dead or buried (weight `deadw`).

### Dead or buried

- **Hard-moving body:** root or chest turning over 170 deg/s, sword shoulder over 320 deg/s, or root travel over 12 studs/s (each smoothed, sigma 6 frames).
- **Dead:** hard-moving while the left arm's summed joint speed is under 45 deg/s.
- **Buried:** the original left forearm midpoint, wrist or hand more than 0.55 studs inside the body (radius 0.7), or its upper arm through the chest.
- **Behind the back:** the original left arm more than 50 deg behind the frontal plane.

`deadw = gauss(dead or buried or behind, 5) * (1 - two) * ends`, where `ends` ramps from 0 to 1 over the first 0.1 s and back to 0 over the last 0.15 s, so the clip still starts and ends where it did.

### Context anchors (left hand centre, chest frame)

| Context | Weight per frame | Anchor (x, y, z) |
|---|---|---|
| ready guard | constant 0.35 | (-0.7, -0.7, -1.9): in front of the solar plexus |
| counter-swing | `clamp((-vx - 6) / 14, 0, 1)` with vx the grip velocity along chest X (cross-body cut, right to left) | (-3.5, 0.05, 0.85): out and back for balance |
| chamber to the hip | `clamp((-vy - 6) / 14 + (-vz - 8) / 16, 0, 1)` (downward cut or thrust) | (-1.95, -1.75, 0.25): fist pulled back to the hip |
| open reach | `1.5 * exp(-0.5 * ((t - markerT) / 0.16)^2)` for markers whose name contains a cast word | (-0.85, 0.45, -2.75): arm about 85% extended toward the target |

Cast words: cast, release, burst, fire, open, pull, erupt, detonate, charge, summon, call, beam, rupture, scatter, shock, spawn, grip, seal, invoke, conjure, orb, ignite. Weights are smoothed (sigma 5 frames) and normalised; the anchor is placed in the chest frame **two frames back** (overlap) and smoothed again (sigma 2).

### Letting go of the hilt

After the first left solve, frames where a two-handed hold would bury the left arm (depth over 0.45) or miss the hilt by more than 0.5 studs are released: `two` is set to 0 there (smoothed), the context behaviour takes over, and the left arm is solved again.

## Stage 7: joint-space smoothing

Each arm joint's rotation sequence is smoothed as hemisphere-aligned quaternions with a per-frame blend between a light Gaussian (sigma **0.8 frames**) and a heavy one (sigma **3.5 frames**):

- right arm heavy weight: `max(1 - imp, popRepair)`;
- left arm heavy weight: `max(1 - impL + 0.5 * deadw, popRepair)` where `impL = two + 0.3 * (1 - two)`.

Blending two natural joint poses traces an arc, so this is where hand paths become curves. A guard follows: the clip is smoothed once with light smoothing only and once with the weights; wherever the heavy version sinks an arm more than 0.08 studs deeper than the light one (ramping over 0.2), the weight is reduced there and the smoothing redone. Wrists are re-clamped afterwards.

## Stage 8: flip guard (dense)

For every arm joint (up to 8 passes): find the largest one-frame turn. If it exceeds **45 deg**, replace the frames from `i - 4` to `i + 5` with a smoothstep interpolation between the end frames on the short arc, widening the window by 2 frames at a time (up to 12) until the average per-frame turn is 45 deg or less. The report's `dense_flips_repaired` counts these.

## Stage 9: key fitting

The dense 60 Hz solve becomes sparse Roblox keys:

- **One shared set of key times per arm** (all three joints of a side keyed together: each key costs 3 Poses, and separate times would multiply keyframes).
- **Tolerance:** shoulder 1.0, elbow 1.2, wrist 1.5 deg, times a tolerance scale.
- **Spans** are at most 0.4 s long and must turn less than 120 deg (the Animator's interpolation becomes ambiguous for big turns).
- **Fit test:** for a span, each joint takes the first easing in **Linear, CubicV2 InOut, CubicV2 Out, CubicV2 In** whose eased interpolation (through the Animator model) reproduces every dense sample within tolerance.
- **Split:** if any joint fails, split at the worst sample (largest linear-interpolation error relative to tolerance), recursively.
- **Snap to existing keyframes:** if an existing keyframe time is within 3 frames of the split, split there instead. A new time costs a Keyframe plus three placeholder Poses (HumanoidRootPart, LowerTorso, UpperTorso); an existing one costs nothing extra.
- The left arm prefers the right arm's key times (and both prefer keyframes the body keeps, and marker times).

The easing is written on the segment's **first** key, because the Animator eases a segment by its first pose ([[Keyframes, Easing and Interpolation]]). Arm poses are written rotation-only: any translation on an arm joint over 0.05 studs reads as a detached shoulder.

## Stage 10: body thinning (v2, on by default)

The hips, torso, head and legs keep only those of **their own** keys needed to reproduce the original playback (never new keys), checked at 60 Hz plus at every key time:

- bounds **0.75 deg** rotation (hips 0.5, that is x0.67) and **0.03 studs** offset;
- each kept segment takes the first easing that fits: its own, then Linear, CubicV2 InOut, Out, In;
- always kept: first and last keys, keys within one frame (1/60 s) of a marker;
- never merged across a segment turning more than 150 deg (split at its middle key);
- **feet are checked in HRP space**: a foot is "planted" when it is within 0.25 studs of its lowest height and moving under 3 studs/s. Planted feet may drift at most 0.05 studs, airborne feet 0.12. Where they drift more, the keys either side of the worst drift (hips and that leg) are put back, up to 6 rounds.

Unkept body poses become weight 0 and are pruned when nothing weighted hangs from them. The freed instances go to the arms. Yield: clips already reduced at 5 deg by their own baker gained 0-7%; denser older clips gained 25-45% (one move went from 333 to 194 body keys).

## Stage 11: writing and counting instances

The baker simulates the Studio writer exactly, so it can predict the instance count:

1. Remove every arm Pose from every keyframe.
2. Thinned body poses not kept become weight 0; kept ones get their easing.
3. Arm keys go under the keyframe at that time (a keyframe within 0.5 ms counts as the same time), creating it if needed with weight-0 identity placeholders HumanoidRootPart > LowerTorso > UpperTorso.
4. Weight-0 poses with no weighted descendant are pruned.
5. Keyframes left with only placeholders are dropped, except the first, the last and any with markers.

`instances = 1 + keyframes + sum(poses + markers)`. The Studio writer must print the same number.

## Stage 12: budgets

| Cap | Value |
|---|---|
| growth cap per clip | `0.15 * instancesBefore + 30` |
| explicit target (`--target N`) | at most N instances |
| kit folder | 2,500 instances; `--all` shares the kit's headroom across moves in proportion to their length, and what one move leaves flows to the next |
| no-growth | automatic when the folder is already over 2,500: every move must end no bigger than it started |

The tolerance scale steps through **1, 1.5, 2, 2.5, 3, 4, 5.5, 7, 9** until the clip fits. Past 5.5 the ladder continues only for the kit budget or an explicit target, not for the 15% growth cap. If it still does not fit a hard cap, a bisection between the last scale and **30x** runs 7 steps, also lengthening the maximum key gap to `max(0.4, min(1.0, 0.4 * scale / 5.5))` seconds. If even 30x fails: `cannot fit in the budget ... leave the original`. Example: a move given a 300-instance target went from 226 to 300 instances at tolerance 13 and scored 68 (from 23).

### Repair keys after reduction

Reduction can reintroduce problems the dense solve did not have. Up to 3 rounds: play the reduced clip; wherever an arm sinks more than 0.3 studs **and** 0.15 deeper than in the dense solve, or pops where the dense solve did not, force keys at the frame and 2 frames either side. **Any key-to-key segment over 120 deg gets a forced mid key**, even if that breaks the budget (a keyed flip is never acceptable). Other forced keys never break the budget.

## Stage 13: repair rounds (whole-solve escalation)

The whole bake runs up to 4 times (`--repair-rounds`, 1 = about 4x faster first look). After each round, frames are found where an arm still sinks over 0.3 studs (dilated) or pops, and their repair weights grow (`max(previous, gauss(bad, 3) * 1.4)`, pops x1.5). Escalation by level:

| Level | Effect on repair frames |
|---|---|
| 1 | collision cost x11 |
| 2 | + grip targets pushed further out (larger margins, unsmoothed) |
| 3 | + blade freer (importance cut by up to 75%, never below 0.6 within 0.1 s of a marker), hilt released, free hand on its behaviour |

In the first two rounds a buried left arm on the hilt moves the **whole grip** out (both hands) rather than letting go; letting go waits for level 3.

**Choosing the round to keep:** lowest `(criticals + lostTwoHand, -(score - penalty))`, where `lostTwoHand` is 1 when less than 60% of the original two-handed time is kept, and

```
penalty = 2 * max(0, devMean - 10) + 0.5 * max(0, devMax - 50) + 15 * max(0, gripMean - 1.0)
```

measured where the original importance was over 0.6. Rounds stop early once there are no criticals and the worst penetration is under 0.45.

### Fidelity report

On frames with original importance over 0.6: blade direction change (`dev_max`, `dev_mean`, deg) and grip movement (`grip_max`, `grip_mean`, studs) against the original; `two_kept` = kept two-handed time / original. Its `bad` flag (dev max over 45, mean over 15, grip mean over 1.2, grip max over 2.6, or two kept under 0.6) is informational: some sources bury the hand, and fixing that has to move it.

## Re-keyed sources

Sometimes the best fix is to steer the solve: edit arm CFrames over time windows in a **copy** of the clip dump, then bake with `--src <folder>`.

- The live clip's own dump stays the base. The copy may differ from it **only in arm poses**: body keys (time, joint, CFrame rounded to 1e-4, easing) and markers must match exactly, or the bake stops with "differs from the live clip outside the arms".
- What gets written is the **live** clip with its arms replaced by the solve; the edited arms only produced the targets.
- The payload carries the live clip's fingerprint plus `rekeyed = { dump_hash (first 16 hex of SHA-1 of the edited keyframes), src_dir, base_fingerprint }`, and the installed clip is stamped `ProBakedRekey = dump_hash`.

## The fingerprint (stale-source protection)

```
fingerprint = { instances, keyframes, len, poses (weighted only),
                csum = sum over weighted poses of ( sum_{k=1..12} component_k * k  +  keyframeTime ) }
```

The Studio writer recomputes it on the live clip (or its safety copy) and refuses if instances, keyframes or poses differ, or if `|csum - csum0| > 0.002 * poses + 0.01`. Weighting components by their index makes swapped values detectable; adding the keyframe time catches retimed keys.

## Outputs

| File | Content |
|---|---|
| `<kit>__<Move>.json` | the payload: `{ kit, move, version, strip = six arm joint names, keys = { { t, p = { { n, cf = 12 numbers, s = style, d = direction } } } }, thin = { joint = { { t, style, dir } } }, len, instances_before, instances_after, src = fingerprint, rekeyed }` |
| `.report.json` | before / after scores and issues, `dense_score`, tolerance used, `split_before` / `split_after`, keys per arm, `grip_miss_max`, `grip_miss_imp`, `blade_dev_imp_max`, `two_handed_frac`, `offhand_behaviour_frac`, `grip_targets_pushed_out`, `blade_snaps_removed`, `repair_round_kept`, `fidelity`, `dense_flips_repaired`, `max_key_segment` |
| `.after_dump.json` | the clip exactly as it will be written (what verify samples) |
| filmstrip (optional) | 8 frames before and after, box renderer |

The Studio writer reads `strip`, `keys` and `thin`, builds the clip with parents before children (UpperArm, then LowerArm, then Hand), and stamps `ProBaked`, `ProBakedFromInstances`, `KitId`.

## Performance

40 s to 3 min per move with repair rounds on one core; the full library of several hundred moves took about 8-12 CPU hours spread over several workers. The heavy parts are the 864 x 864 Viterbi transition per frame per arm and repeated FK for penetration; everything is vectorised over frames and candidates.

## Design notes and trade-offs

- **Why a grid plus Viterbi instead of gradient IK?** Gradient solvers find a local minimum per frame and happily jump branches between frames. A discrete grid sees every elbow branch at once, and Viterbi makes the choice globally consistent. The continuous refinement removes the grid's quantisation.
- **Why price the clamped wrist?** Because the clamped value is what plays. Pricing the wanted wrist made the solver prefer paths that look smooth on paper and snap at the clamp.
- **Why keep body keys?** The body carries timing and weight. Re-solving it would need foot contacts, balance and a different QA; and authors notice when their hips change.
- **When not to use it:** clips that already score about 90 (user-authored, carefully keyed); clips whose choreography deliberately passes the blade near the body (a sheathing move) unless you lower importance there by hand.

## See also

[[Pipeline - Arm IK Baking and QA]], [[Arm QA Metrics Reference]], [[Two-Bone IK Math]], [[Elbow Poles Swivel and Joint Limits]], [[Springs Damping and Smoothing]], [[Inverse Kinematics]], [[Motor6D Math and CFrame Composition]], [[Case Study - Fixing Hundreds of Attack Clips]]

## Connected notes
<!-- auto-links:start -->
[[Animation Quality Standard]] · [[Spec-Driven Move Authoring]] · [[Weapon Swing Design]] · [[Authoring Clips in Code]] · [[AI Animation and Motion from Video]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Animation Start Here]]
<!-- auto-links:end -->
