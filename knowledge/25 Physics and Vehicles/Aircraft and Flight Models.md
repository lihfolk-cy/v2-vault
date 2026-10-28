---
tags: [physics, vehicles, aircraft, flight, aerodynamics, network-ownership]
---
# Aircraft and Flight Models

Flying is the vehicle type where "realistic" and "fun" disagree the most. A real flight model stalls, needs runways, and punishes a thumb on a phone screen. An arcade model that ignores physics feels like a floating camera. Good Roblox aircraft sit in between, and the choice of where is a design decision before it is a code decision. This note covers the three flight-model tiers (arcade, simple aerodynamic, engine fluid forces), the lift and drag maths you need for the middle tier, helicopters and hover craft, controls for keyboard, gamepad and touch, cameras, ownership, anti-cheat for things that legitimately fly, and the performance and streaming problems that only appear when players move very fast over a large map.

Prerequisites: [[Mover Constraints and Physics Controllers]] (LinearVelocity, AlignOrientation, VectorForce, Torque), [[Network Ownership]], [[Camera Systems]].

Source labels: **Docs** (Roblox docs, as of October 2026), **Rule of thumb**. Code is strict Luau, **reviewed, not run**.

---

## 1. Pick a tier first

| Tier | How it moves | Feels like | Use for |
|---|---|---|---|
| **Arcade** | A mover holds a target velocity along the nose; an orientation mover turns the nose toward input | A spaceship or a flying mount | Most games: dragons, jetpacks, flying cars, casual dogfights |
| **Simple aerodynamic** | You compute lift, drag and thrust each step and apply forces | A plane: banking turns, speed matters, stalls possible | Flight-focused games, air races, warbird combat |
| **Engine fluid forces (beta)** | The engine computes aerodynamic forces from part geometry | Whatever your geometry produces | Physics sandboxes, "build your own plane" games |

Rule of thumb: if flying is a means of travel, pick arcade. If flying is the game, pick simple aerodynamic, with assists. Pick engine fluid forces only when players build the aircraft themselves and you want the shape to matter.

---

## 2. Tier 1: arcade flight

The aircraft holds a speed along its nose, and the nose follows input. Two movers on the root:

- `LinearVelocity` in Vector mode, `RelativeTo = World`, `VectorVelocity = nose * speed`, with a force limit high enough to beat gravity and drag but finite (so collisions still matter).
- `AlignOrientation` in OneAttachment mode, driven to a target CFrame built from pitch, yaw and roll input, with `Responsiveness` setting how snappy the turn is.

Add three things that make arcade flight feel like flight:

1. **Bank into turns.** Roll the target orientation by `-yawInput * maxBank`. Visual bank makes yaw look like a real turn.
2. **Speed changes with pitch.** Climbing slows, diving speeds up: `speed += -nose.Y * gravityFeel * dt`, clamped. Costs nothing and gives energy management.
3. **Auto-level.** With no input, ease roll back to zero. Players on touch screens cannot hold a precise bank.

```lua
--!strict
-- Arcade flight controller. Runs on the pilot's client (the owner).
local RunService = game:GetService("RunService")

local Arcade = {}
Arcade.__index = Arcade

export type Input = { pitch: number, yaw: number, throttle: number } -- each -1..1

export type Flyer = typeof(setmetatable({} :: {
	root: BasePart,
	lv: LinearVelocity,
	ao: AlignOrientation,
	speed: number,
	minSpeed: number,
	maxSpeed: number,
	yaw: number,
	pitch: number,
	roll: number,
	input: Input,
	conn: RBXScriptConnection?,
}, Arcade))

function Arcade.new(root: BasePart, minSpeed: number, maxSpeed: number): Flyer
	local att = Instance.new("Attachment")
	att.Name = "FlightAttachment"
	att.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitsEnabled = true
	lv.MaxForce = root.AssemblyMass * workspace.Gravity * 4
	lv.Parent = root

	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.Responsiveness = 25
	ao.MaxTorque = math.huge -- see note below
	ao.Parent = root

	local _, yaw, _ = root.CFrame:ToEulerAnglesYXZ()
	return setmetatable({
		root = root, lv = lv, ao = ao,
		speed = minSpeed, minSpeed = minSpeed, maxSpeed = maxSpeed,
		yaw = yaw, pitch = 0, roll = 0,
		input = { pitch = 0, yaw = 0, throttle = 0 },
		conn = nil,
	}, Arcade)
end

function Arcade.start(self: Flyer)
	self.conn = RunService.PreSimulation:Connect(function(dt: number)
		self:step(dt)
	end)
end

function Arcade.step(self: Flyer, dt: number)
	local i = self.input
	local maxPitch = math.rad(60)
	local maxBank = math.rad(50)

	self.yaw -= i.yaw * math.rad(70) * dt
	self.pitch = math.clamp(self.pitch + i.pitch * math.rad(80) * dt, -maxPitch, maxPitch)
	-- Bank toward the turn; ease back to level with no input.
	local targetRoll = -i.yaw * maxBank
	self.roll += (targetRoll - self.roll) * math.min(1, 4 * dt)

	local target = CFrame.fromEulerAnglesYXZ(self.pitch, self.yaw, self.roll)
	self.ao.CFrame = target

	local nose = target.LookVector
	-- Throttle sets intent; pitch trades height for speed.
	local accel = i.throttle * 40 - nose.Y * 60
	self.speed = math.clamp(self.speed + accel * dt, self.minSpeed, self.maxSpeed)
	self.lv.VectorVelocity = nose * self.speed
end

function Arcade.destroy(self: Flyer)
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
	self.lv:Destroy()
	self.ao:Destroy()
end

return Arcade
```

Notes:

- `MaxTorque = math.huge` on the orientation mover makes the aircraft ignore collisions rotationally (it will not tumble when it clips a tree). Arcade flight usually wants that. If you want crashes to spin the aircraft, use a finite torque scaled to the assembly's moment of inertia and accept some tuning.
- Arcade flight with a velocity mover ignores gravity entirely. That is the point, but it means "engine off" needs explicit handling: switch the `LinearVelocity` off and let the aircraft fall, or blend its force limit down.
- Characters riding a dragon or a jetpack can use the same controller on the character's `HumanoidRootPart`, with the Humanoid set to a state that does not fight (for example `Physics`, or `PlatformStand`). See [[Mover Constraints and Physics Controllers]] section 6.

---

## 3. Tier 2: simple aerodynamic model

Here you compute forces each physics step from the aircraft's state. The textbook relations (rule of thumb: standard aerodynamics, simplified):

```
q    = 0.5 * rho * v^2                -- dynamic pressure
Lift = q * S * CL(alpha)              -- perpendicular to airflow, in the wing's lift plane
Drag = q * S * (CD0 + k * CL^2)       -- opposite to airflow (parasitic + induced)
```

- `v` is airspeed (velocity minus wind).
- `alpha` is the angle of attack: the angle between the nose (or wing chord) and the airflow, measured in the aircraft's pitch plane.
- `CL(alpha)` rises roughly linearly (about `2 * pi * alpha` for a thin wing, alpha in radians) up to a stall angle around 15 degrees, then drops. That drop is the stall.
- `S` and `rho` only ever appear as `rho * S`, so fold them into one tuning constant. Do not try to use real-world numbers: Roblox studs, mass units and 196.2 studs/s² gravity are not SI, and you will spend days converting for nothing.

### Calibrate from the speed you want

Choose the speed at which the aircraft should fly level (cruise) with a comfortable angle of attack, say 4 degrees. At level flight lift equals weight:

```
K = rho * S * 0.5
K * vCruise^2 * CL(4 deg) = mass * g
K = mass * g / (vCruise^2 * CL(4 deg))
```

With `K` fixed, the aircraft automatically needs more angle of attack at low speed, and stalls below `vStall = sqrt(mass * g / (K * CLmax))`. You now have a plane with a stall speed derived from one design number. That is the core of a believable flight model.

### Stability: the tail

Lift applied at the centre of mass makes no torque; the aircraft will not weathervane into the airflow and will tumble. Real planes are stable because the tail's lift acts behind the centre of mass. Two options:

- **Model the tail.** Apply a smaller lift force at a tail attachment using the same formula with a smaller area. Stability falls out automatically, and pitch control is just changing the tail's angle.
- **Fake stability.** Apply a torque that rotates the nose toward the velocity vector, proportional to `q` (so it is weak when slow, strong when fast), plus damping torques on all three axes. Easier to tune and good enough for most games.

### Controls in tier 2

Input does not set the orientation directly. It sets **control torques**: pitch, roll and yaw torques scaled by `q`, so controls go soft at low speed and stiff at high speed, as in a real aircraft. Add angular damping (torque opposing angular velocity) or the plane will spin forever after a roll input.

Assists, which most players want even in a "realistic" game:

- **Auto-coordination:** add yaw proportional to roll so turns do not skid.
- **Stall warning:** shake the camera and play a sound as alpha nears the stall angle.
- **Stall recovery:** below a height, nudge the nose down automatically.
- **Mouse-aim:** the player points the camera; a PD controller turns the aircraft toward it. This is how most successful PC flight games make realistic models controllable.

### Forces in code

The core step, for an aircraft with `VectorForce` instances at the wing and tail (both `RelativeTo = World`, `ApplyAtCenterOfMass = false`) and one thrust force:

```lua
--!strict
-- Lift and drag at one lifting surface. Returns world-space force.
local STALL = math.rad(15)

local function liftCoefficient(alpha: number): number
	local a = math.abs(alpha)
	local cl: number
	if a <= STALL then
		cl = 2 * math.pi * a
	else
		-- Linear drop after stall, to a floor.
		cl = math.max(0.4, 2 * math.pi * STALL - 3 * (a - STALL))
	end
	return if alpha < 0 then -cl else cl
end

local function surfaceForce(surface: CFrame, velocity: Vector3, wind: Vector3,
	k: number, cd0: number, induced: number): Vector3
	local air = velocity - wind
	local speed = air.Magnitude
	if speed < 1 then
		return Vector3.zero
	end
	local flowDir = air / speed
	-- Angle of attack in the surface's pitch plane.
	local fwd = surface.LookVector
	local up = surface.UpVector
	local alpha = math.atan2(-flowDir:Dot(up), flowDir:Dot(fwd))
	local cl = liftCoefficient(alpha)
	local q = k * speed * speed
	-- Lift is perpendicular to the airflow, in the plane of flow and surface up.
	local right = surface.RightVector
	-- right x flow: for level forward flight this points up (checked by hand).
	local liftDir = right:Cross(flowDir)
	if liftDir.Magnitude < 1e-3 then
		return -flowDir * q * cd0
	end
	liftDir = liftDir.Unit
	local lift = liftDir * q * cl
	local drag = -flowDir * q * (cd0 + induced * cl * cl)
	return lift + drag
end

return surfaceForce
```

Check the sign of `liftDir` in Studio with a debug arrow: with the plane flying level and nose slightly up, lift must point up. If it points down, the cross product order is reversed somewhere (with Roblox's right-handed axes and a forward of -Z, `right:Cross(flow)` points up for level flight; `flow:Cross(right)` points down). Sign errors in lift are the most common bug in hand-rolled flight models, and they show up as a plane that dives harder the more you pull up.

---

## 4. Tier 3: engine fluid forces (beta)

Roblox has an aerodynamic force model in beta (**Docs**):

- `Workspace.FluidForces` is set in Studio, not from scripts. `Default` turns aerodynamic calculations off; `Experimental` computes them for parts whose `BasePart.EnableFluidForces` is true. The Docs warn that "the behavior of the aerodynamic force model may change" during beta.
- `Workspace.AirDensity` defaults to realistic sea-level air density; `Workspace.GlobalWind` is a Vector3 for wind direction and strength (it also drives grass, clouds and particles).
- `FluidForceSensor` reports the most recent physics frame's fluid `Force`, `Torque` and `CenterOfPressure` (offset from the centre of mass) for the part it is attached to, and `EvaluateAsync(linearVelocity, angularVelocity, cframe)` yields and returns force, torque and centre of pressure for a hypothetical state.

What this means in practice:

- Forces come from geometry. A flat plate makes lift and drag; a cube mostly drag. Wings must actually be shaped and angled like wings. The good news: a player-built plane flies or fails based on what they built, which is the whole appeal of build-and-fly games.
- You lose direct control of stall speed and handling. Tune by shape, mass and centre of mass, not by numbers.
- Turn `EnableFluidForces` off on parts that should not feel air (interior props, characters' accessories), both for cost and for predictability. Check the property's default on new parts in your Studio build; this note could not confirm it.
- Because the model can change during beta, do not ship a competitive air-race whose balance depends on it without a plan to retune after engine updates.
- `FluidForceSensor:EvaluateAsync` is useful for an autopilot or an AI pilot that needs to predict forces at a different attitude without moving the aircraft. It yields, so call it from a coroutine, at a low rate.

---

## 5. Helicopters, hover craft and drones

A helicopter is a hover controller plus tilt:

- **Lift:** a `VectorForce` along the aircraft's up axis, equal to `mass * g * collective`, where collective is about 1.0 at hover. A PD loop on vertical speed (target from input) keeps hover stable without the player managing collective.
- **Movement:** tilting the aircraft tilts the lift vector, which moves it. Drive the tilt with an `AlignOrientation` toward a target built from input (pitch forward to go forward). This automatically gives the "lean into motion" look.
- **Yaw:** a `Torque` or the orientation target's yaw.
- **Drag:** a horizontal drag force, or the helicopter accelerates forever on any tilt.

Drones and hover bikes are the same model with a near-ground spring (cast down, push up harder the closer the ground, exactly like raycast suspension in [[Cars with Constraints - Suspension Steering and Drive]]).

---

## 6. Input on every platform

| Platform | Pitch / yaw | Throttle | Notes |
|---|---|---|---|
| Keyboard and mouse | W/S pitch, A/D roll or yaw, or mouse-aim | Shift / Ctrl | Mouse-aim is the friendliest for tier 2 |
| Gamepad | Left stick | Triggers (`ButtonR2`/`ButtonL2` analog) | Read trigger position from the input object's `Position.Z` |
| Touch | Dynamic thumbstick for pitch and yaw | On-screen slider or auto-throttle | Auto-throttle is almost mandatory on phones |

A `VehicleSeat` gives you `ThrottleFloat` and `SteerFloat` on all platforms for free (**Docs**), but only two axes. Aircraft need at least three, so most games bind actions with `ContextActionService` (which also creates touch buttons) and keep the seat only for sitting. Bind at a priority above the default character controls while flying, and unbind on exit. See [[Input - UserInputService and ContextActionService]] and [[Gamepad and Console UX]].

Invert-Y is a setting that flight players expect. Store it per player.

---

## 7. Camera

- **Chase camera:** behind and above, looking at a point ahead of the nose. Smooth position with a spring, rotation with a faster spring so the horizon does not lag ([[Springs Damping and Smoothing]]).
- **Do not roll the camera fully with the aircraft.** Rolling 90 degrees with every bank makes many players feel sick. Roll a fraction (30 to 50 percent), or keep the horizon level.
- **Field of view with speed:** widen it by a few degrees at high speed. It sells speed cheaply.
- **Look-around:** right stick or right mouse button orbits; release snaps back.

See [[Camera Systems]] and [[Camera Shake and Camera FX]].

---

## 8. Ownership, security and the map

### Ownership

The pilot's client owns the aircraft, set on seat `Occupant` change as in the Docs' vehicle example (same code as [[Cars with Constraints - Suspension Steering and Drive]] section 6). On exit mid-air, decide: does the aircraft crash (server takes ownership, movers off) or auto-land (server runs a simple autopilot)? Leaving a pilotless client-owned aircraft is a bug: the client that last owned it may be gone.

### Security

Flying is legitimately what fly-hackers do, so movement checks need the aircraft's own envelope:

- Speed above the model's maximum (dive speed included) plus margin.
- Altitude above a ceiling you define.
- Acceleration impossible for the model (instant reversals).
- Position inside no-fly zones (spawn, safe zones, map edges).

Run checks against the aircraft root, not the character, and switch them on only while the player is in an aircraft. Weapons on aircraft are projectiles; validate them as in [[Projectiles and Ballistics]].

### Map size, streaming and precision

- Aircraft cross a map fast. With streaming on, content ahead may not have streamed in. Set a generous streaming radius for flight games, or request areas ahead of the aircraft with `Player:RequestStreamAroundAsync` on the server ([[Instance Streaming]]).
- Far from the origin, floating-point precision drops and physics gets jittery. Rule of thumb: keep play within a few tens of thousands of studs of the origin.
- A map boundary that just stops the aircraft feels broken. Turn it around automatically or warn and then apply a gentle force back.

---

## 9. Performance

- One aircraft is one assembly with a few movers: cheap. The cost is replication: a fast client-owned assembly sends updates constantly, and every other client renders it. Twenty jets in a server is normal; two hundred is not.
- Avoid unanchored decorative parts on aircraft; weld everything, mark visuals massless and non-colliding.
- Fluid forces (tier 3) cost more per part than your own two or three force calculations. Disable `EnableFluidForces` on every part that does not need it.
- Particle trails and contrails at high speed are a hidden cost: an emitter moving fast spawns particles spread over a long distance. Cap rates, and prefer a `Trail` ([[Beams and Trails]], [[VFX Performance Budgets and Culling]]).

---

## 10. Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Realistic model with no assists | Players crash on takeoff and quit | Assists, mouse-aim, auto-throttle on touch |
| Lift at the centre of mass only | Plane tumbles, never points into the wind | Tail force or weathervane torque |
| Lift sign wrong | Pulling up makes it dive | Debug arrows, flip cross product |
| Control torques not scaled with speed | Twitchy at speed, unflyable when slow | Scale with dynamic pressure |
| No angular damping | Endless rolls | Damping torques |
| Real-world constants | Plane cannot take off, or rockets away | Calibrate `K` from cruise speed |
| Full camera roll | Motion sickness | Partial roll or level horizon |
| Pilot leaves mid-air | Ghost aircraft frozen in the sky | Server takeover on exit |
| Streaming radius too small | Flying into empty space, buildings pop | Larger radius or request ahead |
| Fly-hack checks on aircraft | Pilots flagged | Aircraft-aware envelope checks |

## Checklist

- [ ] Tier chosen for the design (travel versus core flight).
- [ ] Arcade: bank, speed-pitch trade, auto-level.
- [ ] Tier 2: `K` from cruise speed, stall speed computed, tail stability, damping, assists.
- [ ] Tier 3: FluidForces set in Studio, `EnableFluidForces` only where needed, retune plan for beta changes.
- [ ] Inputs bound for keyboard, gamepad and touch; invert-Y setting.
- [ ] Camera with partial roll and speed FOV.
- [ ] Ownership to pilot; defined behaviour when the pilot leaves.
- [ ] Aircraft-aware speed, altitude and zone checks.
- [ ] Streaming radius and map bounds tested at top speed.

## See also

[[Physics and Vehicles Start Here]] · [[Mover Constraints and Physics Controllers]] · [[Network Ownership]] · [[Camera Systems]] · [[Springs Damping and Smoothing]] · [[Instance Streaming]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Boats Buoyancy and Water]] · [[Projectiles and Ballistics]] · [[Flight Flocks and Path Animation]]

## Connected notes
<!-- auto-links:start -->
[[Genre Playbook - Racing and Driving]] · [[Links - Forces and movers]] · [[Rotations Angles and Quaternions]] · [[Physics Assemblies and Constraints]] · [[Debugging Physics and Network Ownership]] · [[Motion Sensitivity and Camera Comfort]]
<!-- auto-links:end -->
