---
tags: [procedural, weapons, grip, spin, toss, physics, flourish, luau]
---
# Procedural Weapon Motion

<!-- tldr:start -->
> [!tldr] TL;DR
> - Blade spins about its own centre, not the grip: rotation applied without the pivot sandwich -> `CFrame.new(P) * R * CFrame.new(-P) * B`
> - Spin ends with the edge backwards: turns not an integer or ramps ignored -> solve `W` so the integral is whole turns
> - Toss rockets up and slams down: `workspace.Gravity` -> gravity scaled to the avatar
>
> Cost: TL;DR ~130 tok · whole note ~4.1k tok. Read more: ## Spins with cosine ramps · ## The toss · ## Common mistakes
<!-- tldr:end -->

Body clips can swing an arm; they cannot easily spin a blade six times around the grip, throw it into the air on a real parabola and catch it with a wrist that gives under the spin. Those motions are better computed: exact, cheap, identical on every client, and tunable by numbers instead of by re-keying. This note covers the grip joint, spins, tosses, the catch, regrips and hand roll, using the system one live action game (the reference project) shipped for its equip flourishes.

## The grip joint

A Roblox `Tool` is held by a `Weld` called `RightGrip` that the engine creates between the right hand and the tool's `Handle`, with `C0` at the hand's `RightGripAttachment` and `C1` from the tool's `Grip` property.

The reference project went through two setups:

- **Early:** drive `RightGrip.C0` on every client for premium blade motion, snapping back to the hand's rest on any swing, guard or ability. The rest came from `RightGripAttachment`.
- **Later:** destroy `RightGrip` and add a `Motor6D` (`RightHand` to `Handle`, `C0 = RightGripAttachment.CFrame`, `C1 = tool.Grip`). A Motor6D can be keyed by clips like any joint and still accepts `C0` writes for procedural motion.

Either way, the procedural blade motion lives in **`C0`, written every frame, on every client**. Why `C0` and not `Transform`: the blade's motion is a pure function of a shared clock, it must not be overwritten by whatever the Animator does with that joint, and it is written in the hand's frame where the maths is simplest. The controller writes it in `PreSimulation` (the project used the legacy alias `Stepped`) and restores the rest `C0` when it finishes or is cancelled.

### Hand-space conventions

Write them down once; every formula depends on them. The reference project's:

- Blade along the hand's `-Z` (its LookVector), cutting edge toward the hand's `-X`.
- A 9.5-stud reference blade gripped 20% up from the pommel; the grip point sits `0.19 x hand width` below the hand's centre along its Y.
- Scythes: held by the handle 1.1 studs from the butt, shaft along `-Z`, head on the hand's `+Y` side.

Its first scythe set failed because the heads were rotated 90 degrees and the off hand gripped about a stud off the shaft: conventions that were assumed, not checked.

## Rotating about a point

Every hand-held motion is "rotate the blade by `R` about the point `P` (in the hand's frame)". With `B` the blade's base `C0`:

```
C0 = CFrame.new(P) * R * CFrame.new(-P) * B
```

Read right to left: move the pivot to the origin, rotate, move it back, on top of the base grip. For a spin about the forearm, `R = CFrame.fromAxisAngle(Vector3.yAxis, theta)` (the forearm runs along the hand's Y) and `P` is the grip point.

## Spins with cosine ramps

A spin that starts and stops instantly looks mechanical and, at 6+ revolutions per second, pops. The project's spin speeds up and slows down with half-cosine ramps, so speed and acceleration are continuous at both ends:

```
up ramp (0 <= tau < up):        w(tau) = W * (1 - cos(pi tau / up)) / 2
plateau:                         w = W
down ramp (last `down` seconds): w = W * (1 + cos(pi tau' / down)) / 2
```

Integrating gives the angle. The up ramp contributes `W * up / 2`, the plateau `W * plateau`, the down ramp `W * down / 2`, so the total is `W * (T - up/2 - down/2)` for a spin of duration `T`. The spin must end on a whole number of turns (back in the grip, edge the right way), which fixes `W`:

```
W = 2 pi * turns / (T - up/2 - down/2)
angle during the up ramp: W * (tau/2 - up/(2 pi) * sin(pi tau / up))
```

The project capped each ramp at 45% of the spin's duration. Example: its "Halo" flourish spins 6 turns from 0.55 s to 2.15 s with ramps of 0.35 / 0.42 s, so `W = 2 pi * 6 / (1.6 - 0.175 - 0.21) = 31.0 rad/s`, about 4.9 revolutions per second at the plateau.

Variants it supported: a spin as a **list of segments** (each starting and ending in the grip, with its own direction); and a spin given as a **speed profile** (rev/s keys, cosine-eased between them, then scaled so the total lands on whole turns), which allows multi-stage climbs and a dead stop for a tight catch.

```lua
--!strict
-- A spin about the forearm: { t1, t2, up, down, turns, dir }. Angle in radians at time t (flourish clock).
export type Spin = { t1: number, t2: number, up: number, down: number, turns: number, dir: number }

local function spinShape(s: Spin): (number, number, number, number)
	local T = s.t2 - s.t1
	local up, down = math.min(s.up, T * 0.45), math.min(s.down, T * 0.45)
	return up, down, T, 2 * math.pi * s.turns / (T - up / 2 - down / 2)
end

local function spinAngle(s: Spin, t: number): number
	if t <= s.t1 then return 0 end
	local full = 2 * math.pi * s.turns
	if t >= s.t2 then return full * s.dir end
	local up, down, T, W = spinShape(s)
	local tau = t - s.t1
	local a
	if tau < up then
		a = W * (tau / 2 - up / (2 * math.pi) * math.sin(math.pi * tau / up))
	elseif tau < T - down then
		a = W * up / 2 + W * (tau - up)
	else
		local tt = tau - (T - down)
		a = W * up / 2 + W * (T - up - down) + W * (tt / 2 + down / (2 * math.pi) * math.sin(math.pi * tt / down))
	end
	return math.min(full, a) * s.dir
end

local function spinSpeed(s: Spin, t: number): number
	if t <= s.t1 or t >= s.t2 then return 0 end
	local up, down, T, W = spinShape(s)
	local tau = t - s.t1
	if tau < up then return W * (1 - math.cos(math.pi * tau / up)) / 2 end
	if tau < T - down then return W end
	return W * (1 + math.cos(math.pi * (tau - (T - down)) / down)) / 2
end
```

### Hand roll: let the wrist ride the spin

A blade spinning in a rigid hand looks pasted on. The project added a procedural roll of the wrist and forearm about the forearm axis, on every client, on top of the body clip:

- While spinning: `roll = dir * amp * grow * sin(spinAngle)`, one easy roll each way per turn. `amp` goes from 22 degrees when slow to 11 degrees at 9 rev/s (tighter at speed), and `grow = clamp(w / (2 pi * 1.2), 0, 1)` fades it in over the first 1.2 rev/s.
- At a dead stop (a spin that ramps down in 0.15 s or less): a give of `18 deg * u * exp(1 - u)`, `u = t / 0.07`, which peaks at exactly 18 degrees 0.07 s after the stop, faded out by 0.5 s.
- The forearm takes 45% of the roll and the wrist the rest, and **the blade is turned back by the spin roll inside the grip**, so the blade's world spin stays exact while the hand visibly works.

## The toss

In the air, a thrown blade is a free body: its centre of mass flies a parabola and it turns at a constant rate about that centre. The project's toss, between release at `t1` and catch at `t2`:

```
u = (t - t1) / (t2 - t1)
com(t) = lerp(releaseCom, catchCom, u) + up * 4 H u (1 - u)
rot(t) = Rz(2 pi * turns * u * dir) * lerp(releaseRot, catchRot, u)
```

The vertical term is the parabola. Its second derivative with respect to time is `-8 H / T^2` (with `T = t2 - t1`). Setting that equal to gravity `-G` gives the apex height above the release-to-catch line:

```
H = G T^2 / 8
```

So you choose the airtime `T` (a design decision: it must fit the music and the body clip), and gravity decides the height. Two refinements made it read correctly:

- **The flight is computed in the body's frame** (the root part's), not the world. The blade keeps the character's velocity as they run, like a ball thrown by someone on a train, and lands back in the hand even if the player keeps moving or turning.
- **The catch point is live.** `catchCom` is "where the closing hand holds it *now*", re-read every frame from the animated hand, so the blade meets the hand even though the body clip and movement change where the hand is.

### Why G = 47.6 studs/s^2

The project used `G = 9.81 x 8.74 / 1.8 = 47.6 studs/s^2`: Earth gravity at the avatar's scale, where its 1.6x-scale avatar stands about 8.74 studs tall and is treated as a 1.8 m person (4.86 studs per metre). It is **not** `workspace.Gravity`:

| Gravity | Apex for a 0.9 s toss (`G T^2 / 8`) | How it reads |
|---|---|---|
| 47.6 (Earth at the avatar's scale) | 4.8 studs: about half the body height | a real toss, the eye accepts it |
| 196.2 (default `workspace.Gravity`) | 19.9 studs: over two body heights | the blade rockets up and slams down "in a blink" |
| 35 (9.81 m/s^2 at Roblox's nominal 0.28 m per stud) | 3.5 studs | close, but the avatar here is bigger than nominal |

The general rule: **physics that the eye compares against a body should use gravity scaled to that body**, not the game's movement gravity (which is tuned for jump feel, not realism). The same reasoning applies to dropped props, thrown objects in cutscenes and falling debris near characters.

### The catch "give"

A blade caught while spinning carries angular momentum into the wrist. The project's give, about the toss axis expressed in the hand's frame at the moment of the catch:

```
give(tau) = w0 * tau * exp(-tau / Tc),   Tc = 0.11 s,  w0 = 2 pi * turns / T * dir
```

This is the response of a critically damped spring at rest to a velocity impulse `w0` (see [[Springs Damping and Smoothing]]): it starts moving at exactly the blade's spin rate (no velocity discontinuity at the catch), peaks at `tau = Tc` with value `w0 * Tc / e`, and decays. After 0.42 s it is multiplied by a half-cosine window that reaches zero at 0.6 s, so it is guaranteed to be home. Example: 2 turns in 0.9 s gives `w0 = 14.0 rad/s` and a peak of `14.0 * 0.11 / 2.718 = 0.57 rad`, about 32 degrees.

```lua
--!strict
local TOSS_G = 9.81 * 8.74 / 1.8           -- studs/s^2 at a 1.6x avatar; scale with your avatar's height

export type Toss = { t1: number, t2: number, turns: number, dir: number }

-- The handle's CFrame in the BODY frame at time t. from/to: handle CFrames (body frame) at release
-- and where the hand holds it now; com: centre of mass in the handle's frame.
local function tossFlight(k: Toss, t: number, from: CFrame, to: CFrame, com: Vector3): CFrame
	local T = k.t2 - k.t1
	local u = math.clamp((t - k.t1) / T, 0, 1)
	local H = TOSS_G * T * T / 8
	local c = (from * com):Lerp(to * com, u) + Vector3.new(0, 4 * H * u * (1 - u), 0)
	local R = CFrame.fromAxisAngle(Vector3.zAxis, 2 * math.pi * k.turns * u * k.dir) * from.Rotation:Lerp(to.Rotation, u)
	return CFrame.new(c) * R * CFrame.new(-com)   -- rotate about the centre of mass, not the handle
end

local GIVE_TC = 0.11
local function catchGive(k: Toss, t: number): number
	local tau = t - k.t2
	if tau <= 0 or tau >= 0.6 then return 0 end
	local w0 = 2 * math.pi * k.turns / (k.t2 - k.t1) * k.dir
	local win = if tau < 0.42 then 1 else (1 + math.cos(math.pi * (tau - 0.42) / 0.18)) / 2
	return w0 * tau * math.exp(-tau / GIVE_TC) * win
end
```

To write the flight into the grip joint: `world = rootCF * tossFlight(...)`, then `C0 = hand.CFrame:Inverse() * world * C1` (with `C1` the grip's handle-side frame), which places the handle at `world` while it is nominally still "held". The project also hid nothing and created nothing: the held blade simply flies on its joint.

## Regrips

Long pommels collide with the body during flourishes. The project's first fix slid the grip slowly along the hilt; it was removed in a hand-quality pass because "a fist can't open and slide along a hilt while it holds a pose". What stayed are **quick regrips**: 0.08 s smoothstep re-seats, placed on beats where the blade is already moving fast (so the eye reads them as part of the throw):

- Only for pommels more than 0.9 studs past the grip; the shift is `clamp(pommel - 0.9, 0, cap)`, `cap` 1.6 studs (0.6 for moves that plant the point or cleave low, where a long blade's tip would reach the floor).
- In as the move springs from its anticipation into the first swing or spin; out on the swing back to the rest pose.
- A katana draw held the blade nearer the guard while in the scabbard and gave it back to its own grip during the twirl ("the blade turning in the fingers re-seats it").

## Building a flourish (structure that worked)

- **About 3 s**: anticipation, the move, follow-through, a held hero pose. Picked by the server per equip, never the same twice running.
- **Body clip upper-body only** (torso, head, right arm) at `Action2`, so the run continues. Full-body flourishes were split into `<Name>` and `<Name>Legs`; the legs clip's weight fades as soon as the player moves (`split` approaches 1 at 10/s).
- **End pose**: the blade resting back over the right shoulder. The earlier end pose (blade hanging down from a relaxed arm) needed a 180-degree wrist twist into the idle.
- **Body clips baked densely with Linear easing**, no Roblox easing (PCHIP-joined keys at 0.3 degree / 1.2 rad/s tolerance), because the measured Roblox easing behaviour had reversed directions (see [[Keyframes, Easing and Interpolation]]).
- **Sound on visible beats**: one swish per revolution, with its peak placed on the revolution's half-way point (found by bisection on the spin angle; the sound starts 0.11 s early so its peak lands there), every other revolution past about 8 rev/s (a 0.12 s minimum gap); sparks off the tip once a turn above 60% of top speed.

## Replication and cancellation

- **Start**: your client starts your flourish when you can actually see it (immediately, or 0.15 s after the backpack screen closes), then tells the server; the server checks it matches the tool's stamped flourish (rate limit 1/s) and relays it to everyone, who start it on the same clock.
- **Everything else is computed per client** from the flourish name and start time: the spin angle, the toss, the give, the regrip. No CFrames are replicated.
- **Cancel instantly** on any other action that takes the arm (a swing, an ability, a dash, a guard, being downed, death, the tool leaving the hand) and restore the base `C0`. Swings were blocked while a flourish or draw played (an "equip lock") so input did not fight it.

## Other procedural weapon tricks from the same project

- **Weapon FX rigs**: shard groups and halo rings on legendary-tier weapons driven through weld `C0`s, no clips (one weapon drove 8 shard groups and 6 rings).
- **Energy blade ignition**: blade parts hidden with `LocalTransparencyModifier`, welded stand-ins grown from the base along the blade axis with a white-hot tip; growth time measured per ignition sound take (full length when half the energy of the first 0.7 s is spent: 0.18-0.40 s), divided by the voice pitch so a pitched-up sound grows faster.
- **Staff work from markers**: a welded staff cannot spin itself, so clip markers carried parameters (`StaffSpin` = turns, duration, direction, axis, ramp up, ramp down; axis F / R / U for chest axes, H for the forearm), read on every client on the track's own clock.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Blade spins about its own centre, not the grip | rotation applied without the pivot sandwich | `CFrame.new(P) * R * CFrame.new(-P) * B` |
| Spin ends with the edge backwards | turns not an integer or ramps ignored | solve `W` so the integral is whole turns |
| Toss rockets up and slams down | `workspace.Gravity` | gravity scaled to the avatar |
| Tossed blade lands behind a running player | flight in world space | flight in the body frame, catch point live |
| Catch looks like a collision | no give, or a give that starts from zero speed | impulse response starting at the spin rate |
| Others see your blade frozen in the hand | motion computed only on your client | replicate the start, compute on every client |
| Blade stays offset after an interrupted flourish | cancel path forgot to restore `C0` | one `finish()` that always restores |
| Pommel through the hip in the hero pose | long pommel, no regrip | quick regrip on a fast beat, or a pose with the hand further out |

Related: [[Equip Draw and Flourish Systems]], [[Weapon and Combat Animation]], [[Custom Rigs - Weapons and Props]], [[Springs Damping and Smoothing]], [[VFX Timing with Animation]], [[Weapon Rig Player]].

## Connected notes
<!-- auto-links:start -->
[[Weapon Swing Design]] · [[Modeling Weapons and Props]] · [[Snippets - Procedural Motion]] · [[Arm QA Metrics Reference]] · [[Rotations Angles and Quaternions]] · [[Tween vs Spring]] · [[Animation Start Here]]
<!-- auto-links:end -->
