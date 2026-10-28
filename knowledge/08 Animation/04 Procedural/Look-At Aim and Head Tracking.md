---
tags: [procedural, look-at, aim, head, neck, turret, axes, luau]
---
# Look-At Aim and Head Tracking

A head that turns toward the player who just walked up is the cheapest "this character is alive" trick in the book. Aim (a torso and arms pointing a weapon, a turret swinging onto a target) is the same maths with stricter accuracy. Neither is really IK: you are not reaching a point with an end effector, you are *rotating* one or more joints so an axis points somewhere. That makes it simpler, more stable and easier to clamp than IK, but it has its own traps, nearly all of them about axes and angle order.

## The core maths

Work in the frame of the joint you will rotate: for a neck, `J = UpperTorso.CFrame * Neck.C0` (or the attachment frame on an `AnimationConstraint`), computed from this frame's pose (see the FK note in [[Procedural Animation]]: in `PreSimulation`, part CFrames are still last frame's).

1. Bring the target into that frame: `d = J:PointToObjectSpace(target)`.
2. Read yaw and pitch, with R15's forward being `-Z`:

```
yaw   = atan2(-d.X, -d.Z)                 -- + = turn left (rotation about +Y)
pitch = atan2(d.Y, sqrt(d.X^2 + d.Z^2))   -- + = look up
```

3. Build the rotation **yaw first, then pitch about the turned right axis**:

```
R = Ry(yaw) * Rx(pitch) = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
```

Check: `Ry(yaw) * Rx(pitch)` applied to `(0, 0, -1)` gives `(-cos(p) sin(y), sin(p), -cos(p) cos(y))`, which inverts back to exactly the two `atan2` formulas above.

### The axis-order gotcha

`CFrame.Angles(rx, ry, rz)` is `fromEulerAnglesXYZ`, which the docs define as the product `Rx * Ry * Rz` (`fromEulerAnglesYXZ` and `fromOrientation` are `Ry * Rx * Rz`). So `CFrame.Angles(pitch, yaw, 0)` pitches about the *parent's* X first and then yaws about the *pitched* Y axis. Looking up and to the side with it tilts the head: the yaw axis leans back with the pitch and the face rolls. For small angles nobody sees it; at 40 degrees pitch and 60 degrees yaw it reads as a cocked, puzzled head. Use `CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)` (equivalently `CFrame.fromOrientation`), which is `Ry * Rx * Rz`.

### More axis traps

| Trap | Symptom | Fix |
|---|---|---|
| Forward is `-Z` on Roblox parts, `+Y` along bones imported from Blender | head looks at the ceiling or sideways | measure the rest forward of the joint frame once, build `d` relative to it |
| `atan2(x, z)` instead of `atan2(-x, -z)` | head turns away from the target | test with a target directly left: yaw must be about +90 degrees |
| Reading the target in `Head.CFrame` space | feedback loop: the head chases its own rotation | use the joint's *parent* frame (`Part0 * C0`) |
| Pivot is not the eyes | near targets: the eyes aim above or beside them | aim from the eye position: compute once, then correct by the eye offset (only matters within about 5 eye-offsets) |
| Mirrored rigs | left and right swap signs | measure, do not assume |
| Imported creature joints with rolled frames | yaw turns into a tilt | use `EndEffectorOffset`-style correction: a fixed rotation from the joint frame to a "look frame" |

## Limits, and what to do behind the character

Rule-of-thumb comfortable ranges for a human head relative to the chest: yaw about plus or minus 70 degrees, pitch about plus or minus 40 degrees. Real necks reach further, but a head at its anatomical limit looks strained; most of a big turn should come from the chest and eyes.

Three behaviours at the limit, pick per character:

| Behaviour | When | How |
|---|---|---|
| Clamp and hold | the target is just past the edge | clamp yaw and pitch |
| Elliptical clamp | diagonal looks feel strained | clamp `(yaw / yawMax, pitch / pitchMax)` to the unit circle |
| Lose interest | the target is behind the character | if `abs(yaw)` exceeds the limit plus a margin (say 30 degrees), fade the weight to 0 and look forward; re-acquire only when it comes back inside the limit (hysteresis) |

Without hysteresis, a target directly behind flips the yaw from +180 to -180 and the head whips from one shoulder to the other. Unwrap yaw against last frame's value, or stop tracking behind.

## Spreading the turn over several joints

A turn done by the neck alone looks robotic. Spread it: chest takes some, neck the rest, eyes lead.

| Joint | Share of yaw | Share of pitch | Notes (rule of thumb) |
|---|---|---|---|
| Waist / chest | 25-40% | 10-20% | slower spring |
| Neck / head | the remainder | the remainder | the main motion |
| Eyes (if any) | lead by 50-100 ms, then re-centre as the head arrives | | saccade: a snap of 30-50 ms, no spring |

Two ways to split:

- **Split the angles** (`waist = share * yaw`, `neck = (1 - share) * yaw`). Rotations do not add exactly when yaw and pitch combine, so the head ends slightly off target at large angles. Fine for heads.
- **Sequential recompute.** Rotate the waist by its share, recompute the neck frame with the waist's new rotation, measure the remaining yaw and pitch there, apply them. Exact. Use it for aim, where the gun must land on the crosshair.

The reference project drove head and waist toward the cursor by setting `Neck.C0` and `Waist.C0`. One gotcha it recorded: any unjointed accessory parts that sit on the head or torso (a hood, a skull mask, an arm piece) must first be welded to the body part they sit in, or they stay behind when the part turns. Its shopkeeper NPC turned its head toward players within 26 studs, waved within 15, and slept (no updates) beyond 280, all through `Motor6D.Transform` on top of its idle.

## A head tracker

```lua
--!strict
-- Head and chest look-at on R15, layered over whatever clip is playing. Call track() from PreSimulation.
local Spring = require(script.Parent.Spring)          -- the exact spring from Springs Damping and Smoothing

local YAW_MAX, PITCH_MAX = math.rad(70), math.rad(40)   -- head relative to chest (rule of thumb)
local WAIST_SHARE = 0.35

export type Tracker = {
	waist: any, neck: any,              -- Motor6D or AnimationConstraint
	yaw: number, pitch: number, vy: number, vp: number, weight: number, wv: number,
}

local function yawPitch(J: CFrame, target: Vector3): (number, number)
	local d = J:PointToObjectSpace(target)
	return math.atan2(-d.X, -d.Z), math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z))
end

local function look(yaw: number, pitch: number): CFrame
	return CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)    -- yaw about up, then pitch about the turned right axis
end

-- chestCF: the UpperTorso's CFrame for THIS frame (your FK), target: world point or nil.
local function track(t: Tracker, chestCF: CFrame, neckC0: CFrame, target: Vector3?, dt: number)
	local wantW, wantY, wantP = 0, 0, 0
	if target then
		local y, p = yawPitch(chestCF * neckC0, target)   -- relative to the chest, at the neck pivot
		if math.abs(y) < YAW_MAX + math.rad(30) then      -- behind: lose interest (hysteresis band)
			wantW = 1
			-- elliptical clamp
			local e = math.sqrt((y / YAW_MAX) ^ 2 + (p / PITCH_MAX) ^ 2)
			if e > 1 then y, p = y / e, p / e end
			wantY, wantP = y, p
		end
	end
	-- critically damped smoothing of the angles and the weight (frame-rate independent)
	t.yaw, t.vy = Spring.step(t.yaw, t.vy, wantY, 2.5, 1, dt)
	t.pitch, t.vp = Spring.step(t.pitch, t.vp, wantP, 2.5, 1, dt)
	t.weight, t.wv = Spring.step(t.weight, t.wv, wantW, 2, 1, dt)
	local w = math.clamp(t.weight, 0, 1)
	-- additive over the clip, in each joint's parent frame (R * animated)
	t.waist.Transform = look(t.yaw * WAIST_SHARE * w, t.pitch * 0.15 * w) * t.waist.Transform
	t.neck.Transform = look(t.yaw * (1 - WAIST_SHARE) * w, t.pitch * 0.85 * w) * t.neck.Transform
end
```

Points worth noticing:

- **The yaw and pitch are smoothed, not the Transforms.** Smoothing parameters gives an arc; smoothing CFrames of a flipping solution gives a smear.
- **The weight is smoothed too**, so losing interest fades rather than snaps.
- **Additive** (`look * animated`): the clip's own head bob and idle look-arounds survive. If the clip itself turns the head a lot (an idle "look left" variant), the sum can exceed the limits; either clamp against the clip's current angle or override instead (`animated:Lerp(look, w)`).
- `chestCF` must include this frame's waist rotation for the neck measurement to be exact; for a head tracker the small error from using the pre-waist chest is invisible.

## Aim offsets for weapons

For a held weapon the requirement is stricter: the barrel or blade line must pass through the target.

- **Procedural aim:** sequential recompute over waist, chest and the shoulder of the aiming arm. Do the yaw mostly at the waist (the body turns), the pitch mostly at the chest and shoulder.
- **Aim-offset clips:** author three or five poses (aim up, centre, down; optionally left and right) and blend them by pitch and yaw. This is how most shooters do it: the poses keep the arms, shoulders and weapon in a natural relationship that a single rotation cannot. Blend weights from the measured pitch: `up = clamp(pitch / 60deg, 0, 1)`, `down = clamp(-pitch / 60deg, 0, 1)`, `centre = 1 - up - down`, played at a priority above locomotion. See [[Playback, Priorities and Blending]].
- **Recoil** on top: an impulse into a spring on the aim angles (see [[Springs Damping and Smoothing]]).

## Turrets and leading a moving target

A turret is a two-joint look-at: a yaw part and a pitch part (`Motor6D` driven by `Transform`, or a `HingeConstraint` servo for physical turrets). For projectiles, aim where the target *will* be. With relative position `r` (target minus muzzle), target velocity `u` and projectile speed `s` (no gravity), the hit time `t` solves `|r + u t| = s t`:

```
(u.u - s^2) t^2 + 2 (r.u) t + r.r = 0
```

```lua
-- Time to intercept, or nil if the projectile can never catch the target.
local function interceptTime(r: Vector3, u: Vector3, s: number): number?
	local a = u:Dot(u) - s * s
	local b = 2 * r:Dot(u)
	local c = r:Dot(r)
	if math.abs(a) < 1e-6 then                  -- target as fast as the shot: linear case
		return if b < 0 then -c / b else nil
	end
	local disc = b * b - 4 * a * c
	if disc < 0 then return nil end
	local sq = math.sqrt(disc)
	local t1, t2 = (-b - sq) / (2 * a), (-b + sq) / (2 * a)
	local t = math.huge
	if t1 > 0 then t = t1 end
	if t2 > 0 and t2 < t then t = t2 end
	return if t < math.huge then t else nil
end
-- aim point = target + u * t; then yaw/pitch toward it as above
```

Rate-limit the turret's yaw and pitch (degrees per second) instead of springing them: real turrets slew at a constant speed, and players read a constant slew as "mechanical".

## Replication

Look-at is local. A `C0` or `Transform` written on a client stays on that client.

- **Your own character:** compute locally every frame from your camera or mouse.
- **Other players:** replicate the *target* (a world point or a look direction), throttled, for example only when it changes by more than 2-3 degrees and at most every 0.1-0.2 s (rule of thumb), and let each client smooth toward it with the same spring. The smoothing hides the low update rate.
- **NPCs:** every client can compute the same look-at from replicated positions (the nearest player), with no network traffic at all.

## IKControl LookAt

`IKControl` with `Type = LookAt` does the rotation for you, with `SmoothTime` as a built-in critically damped smoother and `EndEffectorOffset` to pick the axis. It has no angle limits: clamp the target position into a cone yourself. See [[IKControl Reference]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Head rolls when looking up and sideways | `CFrame.Angles(pitch, yaw, 0)` (X then Y) | `CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)` |
| Head whips shoulder to shoulder | target crossing directly behind | lose interest behind; hysteresis; unwrap |
| Head jitters while the character runs | measuring in last frame's part CFrames | FK this frame, or measure in the root's frame |
| Accessory stays put while the head turns | unjointed accessory parts | weld them to the body part |
| Look-at works in Studio test, nothing on new avatars | code edits `Neck.C0` on a Motor6D that is now an AnimationConstraint | write `Transform` in `PreSimulation` |
| Others never see your character look around | client-side only | replicate the target, compute on each client |
| Aim lands above near targets | aiming from the neck pivot | correct for the eye or muzzle offset |

Related: [[Springs Damping and Smoothing]], [[IKControl Reference]], [[Procedural Animation]], [[Idle Breathing and Secondary Motion]], [[Facial Animation and Dynamic Heads]], [[Snippets - Procedural Motion]].

## Connected notes
<!-- auto-links:start -->
[[Motor6D Math and CFrame Composition]] · [[Cookbook - Math CFrame and Vectors]] · [[Rotations Angles and Quaternions]] · [[Snippets - IK]] · [[Math Vectors and CFrames]] · [[Links - Inverse kinematics]] · [[Animation Start Here]]
<!-- auto-links:end -->
