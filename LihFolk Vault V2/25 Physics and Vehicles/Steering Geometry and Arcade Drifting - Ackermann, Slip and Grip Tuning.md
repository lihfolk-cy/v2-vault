---
tags: [physics, vehicles, cars, steering, drifting, tyre-model, handling, type/guide, area/physics, area/game-math, level/advanced, api/VectorForce, api/CustomPhysicalProperties]
---
# Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Same angle on both front wheels in a constraint car -> Ackermann with `amount` 0.6 to 1
> - Avoid: Full lock at all speeds -> Speed-sensitive lock plus steering rate limit
> - Avoid: Lateral grip as `-sideVelocity * k` with no cap -> Slip-angle curve capped by `mu * load`
> - Ackermann (or deliberate parallel) chosen per car type.
> - Lock falls with speed; steering angle rate-limited.
> - Tyre curve with peak and slide segments, scaled by load.
>
> Cost: TL;DR ~150 tok · whole note ~2.6k tok. Read more: ## 1. Ackermann steering · ## 3. A hand-tunable slip-angle tyre · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Handling is what players remember. A car that turns in crisply, slides predictably and catches a drift without spinning feels good even with a cheap model; a car that understeers into walls or snaps sideways feels broken however nice it looks. This note covers the three layers that decide that: steering geometry (Ackermann and speed-sensitive lock), a slip-angle tyre model simple enough to tune by hand, and an arcade drift mode with assists. It also covers how to keep Roblox's own contact friction from fighting your tyre model. Build basics are in [[Cars with Constraints - Suspension Steering and Drive]] and the raycast car in [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]].

Source labels: **Roblox docs**, **Rule of thumb** (tuning values from experience; tune per game), **Unverified**. The maths is standard vehicle dynamics simplified for games. Code is strict Luau, reviewed, not run.

## 1. Ackermann steering

When a car turns, the inner front wheel follows a tighter circle than the outer one. If both wheels steer the same angle, one of them scrubs sideways, which on a constraint car shows up as judder, extra drag and understeer at low speed.

For wheelbase `L`, track width `T` and a desired turn radius `R` measured to the centre of the rear axle:

```
inner = atan(L / (R - T/2))
outer = atan(L / (R + T/2))
```

In practice you start from the player's steering input as a "centre" angle `δ` and derive `R = L / tan(δ)`.

```lua
--!strict
-- Returns left and right wheel angles (radians) for a centre steering angle.
local function ackermann(delta: number, wheelbase: number, track: number, amount: number): (number, number)
	if math.abs(delta) < 1e-4 then return 0, 0 end
	local r = wheelbase / math.tan(math.abs(delta))
	local inner = math.atan(wheelbase / (r - track / 2))
	local outer = math.atan(wheelbase / (r + track / 2))
	-- amount 0..1 blends from parallel steer to full Ackermann
	inner = delta + (inner - math.abs(delta)) * amount * math.sign(delta)
	outer = delta + (outer - math.abs(delta)) * amount * math.sign(delta)
	local s = math.sign(delta)
	-- positive delta = turning right: right wheel is inner
	if s > 0 then return outer, inner else return inner, outer end
end
```

Usage (Rule of thumb):

- **Constraint cars:** feed the two angles to each front knuckle's servo `HingeConstraint.TargetAngle` (degrees, so `math.deg`). `amount` around 0.6 to 1.0.
- **Raycast cars:** Ackermann matters much less because wheels do not scrub physically; it only changes which side generates more lateral force. Many arcade games use `amount = 0` and lose nothing.
- **Racing cars** often run less than full Ackermann because at speed the slip angles dominate; drift builds sometimes run parallel or even reverse Ackermann for stable counter-steer.

## 2. Speed-sensitive lock and steering speed

Full lock at 150 studs/s spins the car on any tap. Two controls fix it:

```
lock(speed) = maxLock / (1 + speed / speedForHalfLock)
```

with `speedForHalfLock` around 50 to 80 studs/s (Rule of thumb). Then rate-limit the steering angle itself (degrees per second, faster back to centre than away from it), because keyboard steering is digital and a 0 to 32 degree jump in one frame is a yaw impulse. Gamepad sticks need less rate limiting; touch buttons need as much as keyboard ([[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]]).

## 3. A hand-tunable slip-angle tyre

The slip angle is the angle between where the wheel points and where it is actually going:

```
alpha = atan2(lateralVelocity, max(|forwardVelocity|, minSpeed))
```

`minSpeed` (around 3 studs/s) stops the angle exploding when parked. Real tyres produce lateral force that rises with slip angle up to a peak (a few degrees to around ten for road tyres), then falls off as the tyre slides. Pacejka curves model that; for games a three-segment curve is easier to tune:

```lua
--!strict
export type Tyre = {
	peakAlpha: number, -- radians where grip peaks
	peakMu: number,    -- friction coefficient at peak
	slideMu: number,   -- coefficient once fully sliding
	slideAlpha: number, -- radians where it is fully sliding
}

-- Lateral force magnitude for a given slip angle and wheel load.
local function lateralForce(t: Tyre, alpha: number, load: number): number
	local a = math.abs(alpha)
	local mu: number
	if a <= t.peakAlpha then
		mu = t.peakMu * (a / t.peakAlpha)
	elseif a >= t.slideAlpha then
		mu = t.slideMu
	else
		local u = (a - t.peakAlpha) / (t.slideAlpha - t.peakAlpha)
		mu = t.peakMu + (t.slideMu - t.peakMu) * u
	end
	return -math.sign(alpha) * mu * load
end
```

Apply it along the wheel's right vector at each corner, alongside the spring force. Starting values (Rule of thumb): road car `peakAlpha = rad(8)`, `peakMu = 1.0`, `slideMu = 0.75`, `slideAlpha = rad(20)`; arcade kart `peakMu = 1.4`, `slideMu = 1.2`, wider peak.

What each knob does:

| Knob | Up | Down |
|---|---|---|
| `peakMu` front vs rear | Front higher: more oversteer, darty | Rear higher: understeer, safe |
| `slideMu / peakMu` ratio | Near 1: easy, forgiving slides | Low: snap oversteer, hard to catch |
| `peakAlpha` | Lazy, floaty turn-in | Sharp, twitchy turn-in |
| Load sensitivity (force grows less than linearly with load) | More body roll grip loss, realistic | Simpler, more planted |

**Combined slip.** A tyre that is braking or accelerating hard has less lateral grip. The cheap approximation is a friction circle: if `sqrt(Fx^2 + Fy^2) > mu * load`, scale both down proportionally. Without it, a car can floor the throttle mid-corner with no penalty.

## 4. Arcade drifting

Players want drifts that are easy to start, easy to hold and easy to exit. A believable but forgiving recipe (Rule of thumb):

1. **Entry:** handbrake (or brake-tap while steering) drops rear `peakMu` and `slideMu` to about 50 to 60 percent for as long as it is held, and optionally cuts rear drive force slightly.
2. **Hold:** while the rear slip angle is above a threshold (say 15 degrees), raise rear `slideMu` back toward 85 percent so the slide is sustainable on throttle.
3. **Counter-steer assist:** blend extra steering toward the direction of travel, proportional to slip angle. This is what makes arcade drifting feel skilful without being hard.
4. **Yaw damping:** apply a torque opposing yaw rate beyond a cap, so a slide cannot become a spin unless the player keeps pushing.
5. **Exit:** when slip falls under about 8 degrees with steering near centre, restore normal grip over 0.2 to 0.3 s, not instantly, or the car snaps straight.

Feed drift angle and duration to the score, tyre smoke and audio; the slip angle you already compute is the single signal for all three ([[Game Feel and Juice]]).

## 5. Do not fight the solver

The engine applies its own contact friction wherever parts touch. Your tyre model and that friction will disagree.

- **Raycast cars:** set the chassis collider's `CustomPhysicalProperties` friction to 0 with a high `FrictionWeight` so the combined friction with any road stays near zero (Roblox docs describe how friction weights combine: https://create.roblox.com/docs/physics/material-physics). Your forces are then the only grip.
- **Constraint cars:** the engine is the tyre model. You tune grip through wheel friction and `FrictionWeight`, not a lateral force script. For drifting, lower the rear wheels' friction while the handbrake is held. Changing properties on the owning client affects that client's simulation (**Unverified** that this is safe on every engine version; setting it on the server and letting it replicate is the conservative choice, at the cost of latency).
- **Do not do both.** Adding scripted lateral forces on top of physical wheel friction gives a car that grips twice and then lets go all at once.
- **Surface grip** (ice, mud, rain) is a multiplier on `peakMu` and `slideMu` read from the raycast hit's `Material`, which keeps weather and terrain in one place.

## Common mistakes

| Mistake | Fix |
|---|---|
| Same angle on both front wheels in a constraint car | Ackermann with `amount` 0.6 to 1 |
| Full lock at all speeds | Speed-sensitive lock plus steering rate limit |
| Lateral grip as `-sideVelocity * k` with no cap | Slip-angle curve capped by `mu * load` |
| Unlimited combined grip | Friction circle |
| Drift exit restores grip in one frame | Blend over 0.2 to 0.3 s |
| Scripted tyre forces plus physical wheel friction | Pick one tyre model |
| Slip angle divided by tiny forward speed | Clamp forward speed with `minSpeed` |

## Checklist

- [ ] Ackermann (or deliberate parallel) chosen per car type.
- [ ] Lock falls with speed; steering angle rate-limited.
- [ ] Tyre curve with peak and slide segments, scaled by load.
- [ ] Friction circle limits combined braking and cornering.
- [ ] Drift entry, hold, assist, yaw damping and blended exit.
- [ ] Chassis friction zeroed for raycast cars; one tyre model only.
- [ ] Surface material multiplies grip.

## See also

[[Cars with Constraints - Suspension Steering and Drive]] · [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Genre Playbook - Racing and Driving]] · [[Dot and Cross Products in Gameplay]] · [[Springs Damping and Smoothing]] · [[Game Feel and Juice]] · [[Mover Constraints and Physics Controllers]]

## Connected notes
<!-- auto-links:start -->
[[Physics and Vehicles Start Here]] · [[Racing Laps and Checkpoints End to End]] · Rotations Angles and Quaternions
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Engine, Gearbox and Torque Curve Model for Arcade Cars]] · [[Centre of Mass, Anti-Flip and Self-Righting]] · [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]] · [[Aircraft and Flight Models]] · [[Boats Buoyancy and Water]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Vehicle Damage, Repair and Wreck States]]
<!-- related:end -->
