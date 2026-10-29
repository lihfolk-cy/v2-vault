---
tags: [physics, vehicles, cars, engine, gearbox, torque, audio, hud, type/guide, area/physics, level/intermediate, api/HingeConstraint, api/VectorForce]
---
# Engine, Gearbox and Torque Curve Model for Arcade Cars

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Engine integrates its own RPM and drives the wheels -> Derive RPM from road speed, clamp at idle
> - Avoid: No shift hysteresis -> Downshift threshold well below upshift
> - Avoid: `MotorMaxTorque` set to a huge number -> Torque from the curve, scaled per chassis mass
> - Engine spec is a data module per car; top speed of top gear equals design top speed.
> - RPM derived from forward speed and clamped to idle and redline.
> - Auto gearbox has hysteresis and a short torque cut on shift.
>
> Cost: TL;DR ~160 tok · whole note ~2.5k tok. Read more: ## 4. Gearbox: ratios, hysteresis and shift cut · ## 5. Feeding the wheels · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A `VehicleSeat` with `MaxSpeed` and `Torque` gives you a car that accelerates like an electric scooter: flat torque, no gears, no engine note worth hearing. Players read speed through sound and shift points more than through the speedometer, so a small RPM/gear/torque model pays for itself even in an arcade game. This note covers the minimal model that stays stable: derive RPM from road speed, look torque up on a curve, multiply through the gearbox, and feed the result into wheel motors (constraint car) or a drive force (raycast car), then reuse the same numbers for audio and HUD. It does not cover chassis layout; that is [[Cars with Constraints - Suspension Steering and Drive]].

Source labels: **Roblox docs** (create.roblox.com, checked October 2026), **Rule of thumb** (tuning experience), **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. Run the model on the driver's client

The engine model is input-driven and must react within a frame, so it runs where the car is simulated: the driver's client after the server hands it network ownership ([[Network Ownership]], Roblox docs: https://create.roblox.com/docs/physics/network-ownership). The server never trusts the RPM or gear; it keeps its own speed limit check from the car's config (see [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]). The client publishes `Rpm` and `Gear` as attributes on the car only if other players need to hear the engine; attribute changes made by a client do **not** replicate (Roblox docs, attributes replicate server to client only), so for remote cars derive RPM on each listening client from the replicated chassis velocity instead. That is cheaper anyway.

## 2. RPM from road speed, not the other way round

The stable arcade approach is "wheels drive the engine": compute RPM from the car's forward speed, then decide how much torque the engine may give. The opposite (integrate an engine flywheel and push the wheels with it) needs clutch simulation and oscillates at the solver's mercy.

```
wheelOmega = forwardSpeed / wheelRadius            -- rad/s
rpm        = wheelOmega * gearRatio * finalDrive * 60 / (2*pi)
rpm        = clamp(rpm, idleRpm, redlineRpm)
```

Clamping at idle gives you a free "clutch slip" at launch: at 0 speed the engine sits at idle and still delivers idle torque. Add a launch boost (let RPM float toward 0.6 x redline while throttle is held below ~5 studs/s) if starts feel limp. Rule of thumb.

Use `chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)` for forward speed. It works for both car families and ignores sideways slide, so drifting does not make the engine scream.

## 3. Torque curve as a small table

A real dyno curve has dozens of points; four to six are enough. Keep it data, not code, in a `ModuleScript` per car:

```lua
--!strict
export type EngineSpec = {
	IdleRpm: number, RedlineRpm: number,
	Curve: { { number } },          -- { rpm, torqueFactor 0..1 }
	PeakTorque: number,             -- your units, tuned per chassis mass
	Gears: { number }, FinalDrive: number, ReverseRatio: number,
	UpshiftAt: number, DownshiftAt: number, ShiftTime: number,
}

local function sampleCurve(curve: { { number } }, rpm: number): number
	if rpm <= curve[1][1] then return curve[1][2] end
	for i = 2, #curve do
		local a, b = curve[i - 1], curve[i]
		if rpm <= b[1] then
			local t = (rpm - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * t
		end
	end
	return curve[#curve][2]
end
```

Shape the curve for feel, not realism: a broad plateau (factor 0.9 to 1.0 from 40% to 85% of redline) makes the car forgiving; a peaky curve rewards shifting. The final point at redline should drop to around 0.6 so the rev limiter is audible rather than a wall. Rule of thumb.

## 4. Gearbox: ratios, hysteresis and shift cut

Wheel torque = `PeakTorque * curveFactor * gearRatio * FinalDrive * throttle`. Each gear's top speed is where RPM hits redline:

```
topSpeed(gear) = redlineRpm * 2*pi/60 * wheelRadius / (gearRatio * finalDrive)
```

Pick the final drive so top gear's top speed equals your design top speed, then space the other gears geometrically (each ratio about 0.7 to 0.75 of the previous). Rule of thumb.

Automatic shifting needs **hysteresis** or it hunts between two gears on every bump:

```lua
local function chooseGear(spec: EngineSpec, gear: number, rpm: number, throttle: number): number
	local norm = rpm / spec.RedlineRpm
	if norm >= spec.UpshiftAt and gear < #spec.Gears and throttle > 0.1 then
		return gear + 1
	elseif norm <= spec.DownshiftAt and gear > 1 then
		return gear - 1
	end
	return gear
end
```

Upshift around 0.9 and downshift around 0.45 of redline (the downshift must land the RPM *below* the upshift point in the lower gear, otherwise you get an instant re-upshift). During `ShiftTime` (0.1 to 0.2 s) multiply torque by 0 to 0.3: that tiny cut is what sells a shift to the ear and the camera. Rule of thumb.

## 5. Feeding the wheels

**Constraint car** (motor `HingeConstraint`s, Roblox docs: https://create.roblox.com/docs/reference/engine/classes/HingeConstraint). Set `ActuatorType = Enum.ActuatorType.Motor`, set `AngularVelocity` to the current gear's top wheel speed times the sign of throttle, and set `MotorMaxTorque` to the wheel torque split across driven wheels. The motor then accelerates the wheel with at most that torque until it reaches the target, which is exactly a torque-limited engine with a redline. Zero throttle: target 0 with a small `MotorMaxTorque` as engine braking.

**Raycast car**: per grounded driven wheel, drive force = wheelTorque / wheelRadius along the contact's forward direction, applied with a `VectorForce` per wheel or summed into one at the rear axle (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/VectorForce). Cap it by the tyre's grip (normal load x friction coefficient) or the car does burnouts in fifth gear.

```lua
local function driveTorque(spec: EngineSpec, gear: number, rpm: number, throttle: number, shifting: boolean): number
	local ratio = if gear == 0 then spec.ReverseRatio else spec.Gears[gear]
	local t = spec.PeakTorque * sampleCurve(spec.Curve, rpm) * ratio * spec.FinalDrive * throttle
	if shifting then t *= 0.2 end
	if rpm >= spec.RedlineRpm then t *= 0.3 end -- limiter, keeps a little push
	return t
end
```

Reverse: treat it as gear 0 with its own ratio, entered only when speed is under ~2 studs/s and brake is held, so braking hard does not flip you straight into reverse. Rule of thumb.

## 6. Audio and HUD from the same numbers

- Map RPM to `Sound.PlaybackSpeed` on a looped engine sample: `PlaybackSpeed = baseSpeed * rpm / sampleRpm`. Keep the range within about 0.5 to 2.0; outside it the pitch shift sounds synthetic. For range, crossfade two loops (low and high) by RPM. Rule of thumb.
- Add load: throttle on raises volume and a slight "on-load" layer; throttle off drops volume and adds a crackle on the downshift.
- Remote cars: each listening client computes RPM from the replicated chassis velocity with the same spec module and assumes full throttle above a speed delta. Nobody notices.
- The HUD reads the local model directly (tachometer, gear) - see [[Race HUD - Position, Laps, Splits, Speedometer and Minimap]].

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Engine integrates its own RPM and drives the wheels | Wheel spin oscillation, jitter at standstill | Derive RPM from road speed, clamp at idle |
| No shift hysteresis | Gear hunts on bumps and hills | Downshift threshold well below upshift |
| `MotorMaxTorque` set to a huge number | Instant top speed, wheelies, flips | Torque from the curve, scaled per chassis mass |
| RPM from wheel spin including slide | Engine screams while drifting | Use forward speed only |
| Engine attributes set on the client | Other players hear nothing | Derive remote RPM locally from velocity |
| Server trusts reported gear or RPM | Speed hacks hidden as "sixth gear" | Server checks speed against the spec's top speed |

## Checklist

- [ ] Engine spec is a data module per car; top speed of top gear equals design top speed.
- [ ] RPM derived from forward speed and clamped to idle and redline.
- [ ] Auto gearbox has hysteresis and a short torque cut on shift.
- [ ] Wheel torque goes to motor `MotorMaxTorque` (or drive force capped by grip).
- [ ] Engine sound pitch and crossfade driven by RPM; remote cars derive RPM locally.
- [ ] Server speed check uses the same spec, with tolerance.

## See also

[[Cars with Constraints - Suspension Steering and Drive]] · [[Physics and Vehicles Start Here]] · [[Genre Playbook - Racing and Driving]] · [[Sound Fundamentals]] · [[Spatial Audio and Mixing]] · [[Interpolation Easing and Curves Math]] · [[Network Ownership]]

## Connected notes
<!-- auto-links:start -->
[[Racing Laps and Checkpoints End to End]] · Mover Constraints and Physics Controllers · Feedback Timing - Sound Visual and Haptic Sync
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Engine and Tyre Audio Driven by RPM and Slip]] · [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]] · [[Centre of Mass, Anti-Flip and Self-Righting]] · [[Vehicle Damage, Repair and Wreck States]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] · [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]]
<!-- related:end -->
