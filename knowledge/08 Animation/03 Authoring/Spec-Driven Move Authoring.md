---
tags: [authoring, code, specs, ik, baking, combat]
---
# Spec-Driven Move Authoring

Instead of keying every joint, describe each move as a handful of **key poses of what matters**: where the sword hand is, which way the blade points and its edge faces, where the off hand goes, where the feet stand, how the root leans and turns, and when the gameplay beats happen. A baker then solves the arms and legs with IK at dense in-between times and fits the result back into a compact `KeyframeSequence`.

This is how the reference project (one live action game) produced hundreds of consistent attack clips across dozens of weapon kits. This note documents its spec format, the shared pose library, the easing and lag conventions, the baker, and the hard-won choreography lessons. The output rules (placeholders, easing placement, fitting) are in [[Authoring Clips in Code]]; arm re-solving and QA are in [[Pipeline - Arm IK Baking and QA]] and [[Animation Quality Standard]].

## Why specs

| Hand-keyed clips | Spec-driven clips |
|---|---|
| each clip is unique work | moves reuse named poses; new moves are mostly composition |
| a rig change means re-keying | re-bake from the same specs |
| quality depends on each session | one solver and one QA standard for every clip |
| gameplay beats live in the clip only | markers come from the same spec as data tables |
| hard to review in bulk | specs diff like code; filmstrips are generated |

Trade-offs: specs are worse for subtle acting, the solver needs reachable targets, and choreography mistakes (like a near-180-degree swing) still need a human to spot. Use specs for systematic gameplay moves and hand-key hero moments.

## Coordinate conventions

All spec values are in **character space at scale 1**, regardless of the game's character scale:
- **x right, y up, z back** (forward is -z), relative to the root.
- The ground is about **3.19 studs below the root** at scale 1.
- The right shoulder joint sits at about **(0.97, 0.85, 0)**.
- Angles are **degrees**; distances are **studs at scale 1**.
- `root = { pitch, yaw, roll, x, y, z }`: **pitch < 0 leans forward**; yaw > 0 turns left (a positive rotation about +y swings the forward -z axis toward -x). Root offsets are multiplied by the game's character scale (**x1.6**) when written (see below).

The gameplay **motion library** (dashes, leaps, turns) moves and turns the actual HumanoidRootPart at runtime; spec clips only **pose the body on top of it**. Keeping travel out of clips lets gameplay control distance and collision.

## The spec format

A kit's spec module returns an ordered list of moves (`S.ORDER`) and one spec per move:

```lua
spec = {
	name = "MoveName", len = 1.2,          -- clip length in seconds
	sp = 0.1,                              -- default in-between spacing (s) for baked samples
	lag = { neck = 0.035, waist = 0.015, larm = 0.05 }, -- successive breaking (s)
	keys = {
		{ t = 0.00,
		  e = "CubicV2", d = "Out",          -- easing of the segment LEAVING this key
		  mk = "Hit",                        -- marker(s) at this key: "Name", {"A","B"} or "Name=value"
		  sp = 0.045,                        -- in-between spacing for the span after this key
		  root  = { rx, ry, rz, px, py, pz },  -- degrees / studs at scale 1
		  waist = { rx, ry, rz }, neck = { rx, ry, rz },
		  R = { hand = Vector3, dir = Vector3, edge = Vector3? }, -- sword hand target, blade direction, edge facing
		  L = "grip"                         -- off hand on the hilt
		    -- or { hand = Vector3, face = Vector3? }  free target (palm facing)
		    -- or { s = {..}, e = n, w = {..} }        raw shoulder / elbow / wrist angles
		  feet = { L = { x, z, yaw, lift, toe, knee = Vector3? }, R = { ... } },
		},
		-- more keys ...
	},
}
```

Field notes:
- **R.hand** is the sword hand's grip position; **R.dir** the blade direction; **R.edge** the direction the cutting edge faces (needed on cuts; optional elsewhere, faded in and out where only one neighbouring key gives it).
- **L** has three forms: on the hilt (`"grip"`, both hands), a free target point with optional palm facing, or raw angles.
- **feet**: `x, z` position on the ground, `yaw` of the foot, `lift` off the ground, `toe` pitch, optional `knee` direction hint. Feet are **planted targets**: the legs are solved to them, so the root can move without the feet sliding.
- **mk** writes `KeyframeMarker`s. `"Name=value"` writes a marker with a value (for example a staff-spin payload).

## The shared pose library (speclib)

Moves are composed from named poses by cloning a base pose and overriding fields:

```lua
local function k(t, base, overrides)
	local r = table.clone(base)          -- shallow copy of the named pose
	for key, v in overrides or {} do r[key] = v end
	r.t = t
	return r
end
```

### Feet presets (L and R as { x, z, yaw, lift, toe })

| Preset | Left | Right | Use |
|---|---|---|---|
| STANCE | (-0.6, 0.7, 16, 0.05, -10) | (0.45, -0.8, -4) | default staggered stance |
| WIDE | (-0.7, 0.95, 20, 0.08, -18) | (0.55, -1.15, -8) | cuts, sweeps |
| DEEP | (-0.6, 1.15, 16, 0.12, -30) | (0.5, -1.45, -4) | lunges, drives, thrusts |
| STRAIGHT | (-0.2, 0.15, 0, 0.1, -40) | (0.2, 0.15, 0, 0.1, -40) | rising, lifting onto the toes |
| KNEEL | (-0.5, 1.05, 10, 0, -70) | (0.5, -0.75, -4, 0, -5) | kneeling holds |

### Named poses (values at scale 1)

| Pose | Root {pitch, yaw, roll, x, y, z} | Hand / blade intent | Easing (leaving) |
|---|---|---|---|
| READY | (-2, 8, 0, 0, -0.15, 0) | hand (0.6, -0.4, -0.95), blade forward and slightly up, edge down; off hand loose at the side | |
| overhead | (8, 0, 0, 0, 0.05, 0) | both hands, blade back over the head (dir (0.05, 0.6, 0.8)) | CubicV2 In |
| chop | (-6, 0, 0, 0, -0.2, 0) | both hands high in front, blade up and **forward** (dir (0.03, 0.7, -0.71)) | CubicV2 In |
| drive | (-24, 0, 0, 0, -0.65, -0.1) | both hands low in front, blade down ahead | CubicV2 Out, sp 0.045 |
| wind (flat cut) | (-12, +/-24, 0, 0, -0.3, 0) | blade back on the cut's start side | CubicV2 In |
| cut | (-16, +/-22, 0, 0, -0.4, 0) | blade through to the far side; edge = plane axis x dir | CubicV2 Out, sp 0.045 |
| follow | (inherits the lunge base) | blade carried past the body | (base: InOut) |
| low / rising | (-14, -18, ...) / (6, 16, ...) | blade low on one side / up and across | In / Out, sp 0.045 |
| high / falling | (6, -16, ...) / (-20, 18, ...) | blade high on one side / diagonally down | In / Out, sp 0.045 |
| chamber / thrust | (-6, -20, 0, 0, -0.35, 0.15) / (-16, 14, 0, 0, -0.5, -0.2) | blade drawn back at the hip / straight out ahead (hand z -1.55) | In / Out, sp 0.045 |
| crouch / lift | (-10, 0, 0, 0, -0.7, 0) / (6, 0, 0, 0, 0, 0) | blade low / trailing behind | In / Out |
| cast | (-8, -10, 0, 0, -0.25, 0) | off hand forward and open; blade back | Out, sp 0.045 |
| salute | (4, 0, 0, 0, -0.1, 0) | blade vertical before the face | Out |
| sweep | (-10, -30, 0, 0, -0.45, 0) | blade straight out to the side, body turned | Out, sp 0.045 |
| kneelHold | (-22, 0, 0, 0, -0.95, -0.1) | both hands, blade down, KNEEL feet | Out, sp 0.045 |
| settle | READY | back to ready | CubicV2 InOut |

Waist and neck move with the root in opposite senses (the waist adds to the lean, the neck counters it so the head stays fairly level): for example drive has waist pitch -14 and neck +12.

**Flat-cut edges** are computed, not typed: with the cut's start and end directions `OUTR` and `OUTL`, the plane axis is `ax = OUTR:Cross(OUTL).Unit`, and the edge for a blade direction `dir` is `ax:Cross(dir.Unit).Unit`.

### Long-pommel variants ("2" poses)
`wind2`, `cut2`, `follow2`, `falling2`, `drive2` keep the hand further from the body (about 0.3 to 0.45 studs at scale 1) and open the blade more to the side. The held blade is 9.5 studs long with **20% behind the grip**, so a blade pointing away from the body with the hand close drives the pommel into the torso. Use the "2" variants for any long-hilted weapon.

## Easing conventions

The key's easing describes the segment **leaving** it (the engine's convention):
- **Wind-ups: CubicV2 In.** The swing from the wind-up into the strike starts slow and arrives fast.
- **Strikes: CubicV2 Out with `sp = 0.045`.** The `Hit` marker sits on the strike key (peak speed); the follow-through leaves fast and decelerates; dense in-betweens keep the arc.
- **Settles: CubicV2 InOut.**
- **Linear** for very short segments that move the hips or feet, and for chained snaps (see timing rules below).
- Never legacy Cubic; Constant only for deliberate snaps.

## Sampling and lag (successive breaking)

- Sample times are every authored key plus in-betweens every `sp` seconds (default **0.1 s**, about 10 per second; strikes ask for 0.035 to 0.045).
- Each channel is sampled with its key's easing.
- **Lag**: the waist, neck and free left arm are sampled **in the past** by their lag (defaults **waist 0.015 s, neck 0.035 s, left arm 0.05 s**): `value(t - lag)`. This produces successive breaking for free: when the root turns, the chest follows 1 frame later, the head 2, the free arm 3. Raise lags for loose, heavy characters; lower them for stiff, mechanical ones.

## The baker

### Right arm (sword hand)
Numeric IK by **coordinate descent** over 6 parameters in degrees `{ shoulder x, y, z, elbow, wrist x, wrist y }`, bounded to low `{-110, -120, -70, 0, -75, -75}` and high `{215, 120, 170, 150, 75, 75}`. Cost:

```
4 * handError^2 + 10 * dirError^2 + 0.00012 * (wx^2 + wy^2)
+ 1.6 * edgeWeight * edgeMiss^2 + 3e-5 * (distance from the previous frame's solution)
```

- If the cost stays above **0.02**, ten fixed **seed poses** are tried without the previous-frame pull; a seed wins if it is better by **0.01** or more.
- On unreachable targets the seed fallback could take over **1 s per frame**; the seed loops were patched to give up after **0.3 s**.

### Two hands
`solveBoth` keeps the blade direction and lets the sword hand give ground so the left hand can hold the pommel end (hands **0.42 apart at scale 1** for one weapon family; the later arm re-solver used **1.15 studs** at game scale with the left hand rolled 180 degrees).

### Grip transitions
When the left hand takes or leaves the hilt, the baker blends between the free left-arm pose and the grip solved **on that same frame**, so the hand lands exactly on the hilt at the grip key.

### Free left hand
A free target `{ hand, face }` is solved once at the key's own torso pose and then interpolated in angle space.

### Legs
Solved to the planted foot targets every sample. A later offline baker used analytic leg IK on the 1.6x game rig so planted feet stayed within about **0.04 studs** of the authored spot, and fitted leg keys on the ankle position rather than per joint.

### Root scale x1.6
LowerTorso offsets are written **x1.6**, the game's character scale: "the Animator does not scale clip translations for characters sized through their body scales". A crouch baked at scale 1 would leave the feet hovering on the real character. If your characters are scaled with `Model:ScaleTo` instead, the Animator **does** multiply offsets by `Model:GetScale()` (measured), so do not pre-multiply. See [[Scale and Animation]].

### Output
`toSequence` fits each joint separately (authored key alone if its easing reproduces the in-betweens within 5 degrees / 0.09 studs; otherwise split and fit Linear, CubicV2 InOut, Out, In), drops still joints and empty keyframes, and writes markers. See [[Authoring Clips in Code]].

### Diagnostics
Every bake reports the maximum hand error, blade direction error, grip error, foot error, edge error and left-hand error, plus a `worstAt` list such as `R@0.42 h0.31 d7.2` (right hand 0.31 studs off and blade 7.2 degrees off at t = 0.42). Thresholds that produced a worstAt entry: hand over 0.25 studs or direction over 6 degrees; grip over 0.15; edge over 35 degrees; foot over 0.12; free hand over 0.2.

### Cost
About **0.5 s of solve time per baked frame** inside Studio: 15 / 20 / 47 frames for 1.0 / 1.3 / 3.6 s clips. The Studio-side baker was **sliced** (`bakeBegin` / `bakeStep` with a 0.5 to 0.9 s budget per call) so Studio never froze; a stuck "frames done" loop was resolved by calling one step by hand.

## Choreography lessons (written into the library)

### The chop key
An **overhead to drive** swing turns the blade nearly 180 degrees. Interpolation takes the short way, which can be **back over the head**, so the impact frame ends with the blade pointing up. Insert a **chop** key that brings the blade **over the front** between overhead and drive. General rule: keep every joint's key-to-key turn under 120 degrees.

### Long pommels
Use the "2" variants; make overhead, drive and kneel one-handed with the off hand out to the side; **chop before every drive**; halve the root yaw in flurries (turn the waist more); keep hands further from the body; **end on rest** (arms hanging like the game idle).

### Root drop limits
Keep root drops shallow: **drive and kneel root y at -1.0 or higher** (scale 1). Deeper drops pushed a foot **1 to 2.5 studs through the floor** because the leg solver ran out of reach. The kit's test reported a `minClear` that should stay about **-1.3 or better**.

### Pass 3 timing rules
From the re-pose pass that cleared the last criticals:
- **No grounded stance change faster than 0.12 s.** Feet jumping between presets faster than that popped.
- **Sub-0.1 s segments that move hips or feet go Linear**, and the first of a run eases In.
- **Overhead keeps the hips down; chop drops the hips first.**
- **Shallower load** (root y about **-0.55**) and **thrust hand about 0.7 out**.
- **Re-key the end frames**: a READY end pose put the pommel in the hip; ending on rest fixed 22 of 22 moves.

### Poses that cause QA criticals
- Arms behind the body in sprint, surf and load poses.
- Sprint into thrust or cross-cut lead-ins (forearm into the torso): use a flat wind-up.
- Backhand winds and two-handed low guards (forearm across the chest).
- Big root yaw swaps every 0.1 s.
- Overhead > chop > deep drive into the floor (arms buried): shallow drive, or two hands.
- Salute-aloft ultimates and high-to-falling deep openers: use overhead, chop and falling variants instead.

See [[Animation Quality Standard]] for the metrics behind "critical".

## Worked example

A three-beat move: a flat cut from the right, a cut back from the left, then an overhead chop into a shallow drive. Times in seconds; poses from the library above.

```lua
-- assumes the speclib helpers: k, READY, wind2, cut2, follow2, overhead, chop, drive2, settle, WIDE, DEEP
S.ExampleTriple = { name = "ExampleTriple", len = 1.30, keys = {
	k(0.00, READY, { e = "CubicV2", d = "InOut" }),
	wind2(0.10, true),                        -- blade back on the right; In: accelerate into the cut
	cut2(0.20, "Hit", true, WIDE),            -- Hit on the strike key; Out + sp 0.045 for the follow-through
	follow2(0.32, true),
	wind2(0.42, false),                       -- the follow-through flows into the next wind-up (hidden anticipation)
	cut2(0.52, "Hit2", false, WIDE),
	overhead(0.70, nil),                      -- hips stay up
	chop(0.80, WIDE),                         -- hips drop first; blade over the FRONT
	drive2(0.88, "Hit3", DEEP),               -- shallow drive (root y -0.65 >= -1.0), hand kept out (long pommel)
	settle(1.10),
	k(1.30, READY, { e = "CubicV2", d = "InOut" }), -- end on the ready/rest pose the idle can take over from
} }
```

Checks before baking: no stance change under 0.12 s (the feet change WIDE > DEEP at 0.80 > 0.88: 0.08 s, so either keep WIDE through the drive or move the drive later; this is exactly what the pass 3 rule catches); markers on strike keys; the chop key between overhead and drive; end near rest. After baking: read `worstAt`, then run arm QA and look at the filmstrip.

## Process rules

- Never name a move `Attack`, `Origin`, `FX`, `LocalCast`, `Moves` or `ItemRig` (reserved child names of a kit folder; one collision broke a kit's damage).
- Keep **before-dumps** of every clip (as files, not backup folders in the place) so a worse re-pose can be rolled back: one pass scored worse on 6 moves and was reverted.
- After baking, re-check budgets (2,500 instances per kit folder) and the 200,000-character script source limit for generated modules.
- Markers in specs feed the gameplay data tables; regenerate those tables whenever a spec is retimed.
- If clips are later stubbed (motion moved into compressed buffers), restore before re-baking and re-stub after; never hand-edit a stub. See [[Baked Clip Stubs and Archiving]].

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Easing written as "into" | eases one segment late | the key's easing shapes the segment leaving it |
| Overhead straight to drive | blade ends up behind the head | chop key |
| Deep root drops | feet through the floor | y >= -1.0 at scale 1 |
| Root offsets not scaled | hovering feet in game | x game scale on write (body-scaled characters) |
| Unreachable hand targets | slow bakes, big worstAt errors | shoulder-relative targets; seed time cap |
| Fast stance changes | foot pops | no grounded change under 0.12 s |
| Short pommel assumptions | pommel through the hip | "2" variants, rest end pose |

## See also
[[Authoring Clips in Code]], [[Weapon Swing Design]], [[Animation Quality Standard]], [[Pipeline - Arm IK Baking and QA]], [[Arm Baker Internals]], [[Two-Bone IK Math]], [[Elbow Poles Swivel and Joint Limits]], [[Pipeline - New Animated Weapon]], [[Studio Tooling Architecture]].

## Connected notes
<!-- auto-links:start -->
[[Posing and Silhouettes]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Weapon and Combat Animation]] · [[Principles of Animation for Games]] · [[AI Animation and Motion from Video]] · [[Modeling Weapons and Props]] · [[Animation Start Here]]
<!-- auto-links:end -->
