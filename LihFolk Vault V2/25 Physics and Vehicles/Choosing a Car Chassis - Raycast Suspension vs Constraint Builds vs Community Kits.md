---
tags: [physics, vehicles, cars, chassis, raycast-suspension, constraints, decision-guide, type/guide, area/physics, level/intermediate, api/VehicleSeat, api/VectorForce]
---
# Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Shipping the legacy hinge-surface car -> Constraint or raycast car
> - Avoid: Constraint wheels for a 200 studs/s racer -> Raycast
> - Avoid: Raycast car root with default friction -> Friction 0 on the root collider
> - Chassis type chosen with the decision guide and the reason written down.
> - Raycast car: root friction 0, rounded collider, chosen mass, massless visuals.
> - Spring numbers derived from frequency and damping ratio.
>
> Cost: TL;DR ~150 tok · whole note ~2.8k tok. Read more: ## 3. A complete minimal raycast car · ## 4. Auditing a community kit · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Before tuning a single spring you have to pick what the car is made of. There are four real options on Roblox in 2026: the legacy `VehicleSeat` hinge car, a constraint car (physical wheels on hinges and springs), a raycast car (one rigid body with your own tyre model), and a community chassis kit. Each one decides how the car handles at speed, how much code you own, how it behaves on phones, and how hard it is to secure. This note is the decision guide plus a complete minimal raycast car. Build detail for constraint cars and the single-corner raycast maths are in [[Cars with Constraints - Suspension Steering and Drive]]; this note does not repeat them.

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

## 1. The four options

| Option | What drives it | Strengths | Weaknesses |
|---|---|---|---|
| **Legacy VehicleSeat hinges** | `VehicleSeat.MaxSpeed`, `Torque`, `TurnSpeed` applied to legacy hinge surfaces | Zero code | The docs describe these properties as acting on legacy hinge surfaces; feel is fixed and poor; do not ship new games on it |
| **Constraint car** | `HingeConstraint` motors, `SpringConstraint`s, servo steering; script maps `ThrottleFloat`/`SteerFloat` | Wheels really touch the world; crashes, trailers and lost wheels are free | Unstable at high speed, wheels tunnel and catch on seams, tuning per car |
| **Raycast car** | One `VectorForce` per corner from your spring and tyre maths | Stable at any speed, cheap, predictable, easy to make arcade | You write the tyre model; wheels never collide; low-speed parking and kerbs feel fake |
| **Community kit** | Someone else's scripts, usually constraint-based with many tunables | Realistic drivetrain, gauges, sounds on day one | You inherit its bugs, remotes, update cadence and licence; often desktop-first |

`VehicleSeat` itself is still the right seat in options 2 to 4: it exposes `ThrottleFloat` and `SteerFloat` from the default control scripts, and `Occupant` for ownership (Roblox docs, https://create.roblox.com/docs/reference/engine/classes/VehicleSeat).

## 2. Decision guide

Answer in order; the first "yes" usually decides.

1. **Is the car on rails (theme-park ride, cutscene)?** Use no physics: an anchored model moved along a curve with `PivotTo` ([[Curves in Luau - Paths Beams and Motion]]).
2. **Do cars go above roughly 120 to 150 studs/s, or is this a kart/racing game?** Raycast. Solver-driven wheels are small, fast, spinning colliders and that is where physics engines fail (Rule of thumb).
3. **Is the fun the body interacting with the world** (rock crawling, crash derby, towing, losing wheels)? Constraint car.
4. **Is the team small, the game RP or city, and realism a selling point?** A community kit can save weeks, if it passes the audit in section 4.
5. **Do you need dozens of cars per server on phones?** Raycast. Four rays and four forces per car beat a dozen constraints and four rolling contacts, and it degrades better on low-end devices (Rule of thumb; measure with [[Physics Performance]]).

Hybrids work: raycast cars for the race, constraint cars for a monster-truck side mode. Keep one input layer (section 5 of the controls note) so both read the same actions.

## 3. A complete minimal raycast car

The client that owns the car runs this. It assumes a model with a `Root` part (the only collider, low friction), four `Attachment`s named `FL`, `FR`, `RL`, `RR` on the root at the wheel mounts, and the `VehicleSeat`. Spring numbers come from the frequency method in the Cars note.

```lua
--!strict
-- LocalScript-required module: drives one raycast car while the local player is the driver.
local RunService = game:GetService("RunService")

local REST, RADIUS = 1.6, 1.2 -- studs
local FREQ, ZETA = 1.8, 0.45 -- spring frequency (Hz) and damping ratio
local GRIP_FRONT, GRIP_REAR = 0.9, 0.8
local ENGINE = 1.0 -- drive force as a multiple of car weight at full throttle
local MAX_STEER = math.rad(32)

local Car = {}

function Car.drive(model: Model, seat: VehicleSeat): () -> ()
	local root = model:FindFirstChild("Root") :: BasePart
	local mass = root.AssemblyMass
	local g = workspace.Gravity
	local omega = 2 * math.pi * FREQ
	local k = (mass / 4) * omega * omega
	local c = 2 * ZETA * (mass / 4) * omega

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }

	type Corner = { a: Attachment, f: VectorForce, front: boolean }
	local corners: { Corner } = {}
	for _, name in { "FL", "FR", "RL", "RR" } do
		local a = root:FindFirstChild(name) :: Attachment
		local f = Instance.new("VectorForce")
		f.Attachment0 = a
		f.RelativeTo = Enum.ActuatorRelativeTo.World
		f.ApplyAtCenterOfMass = false
		f.Force = Vector3.zero
		f.Parent = a
		table.insert(corners, { a = a, f = f, front = name:sub(1, 1) == "F" })
	end

	local conn = RunService.PreSimulation:Connect(function()
		local up = root.CFrame.UpVector
		local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
		local speed = root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector)
		local lock = MAX_STEER / (1 + math.abs(speed) / 60) -- less lock at speed
		for _, corner in corners do
			local origin = corner.a.WorldPosition
			local hit = workspace:Raycast(origin, -up * (REST + RADIUS), params)
			if hit == nil then
				corner.f.Force = Vector3.zero
				continue
			end
			local comp = REST - (hit.Distance - RADIUS)
			local v = root:GetVelocityAtPosition(origin)
			local load = math.max(0, k * comp - c * v:Dot(up))
			local yaw = if corner.front then -steer * lock else 0
			local wheelCF = root.CFrame * CFrame.Angles(0, yaw, 0)
			local right, fwd = wheelCF.RightVector, wheelCF.LookVector
			local grip = if corner.front then GRIP_FRONT else GRIP_REAR
			local lateral = -right * v:Dot(right) * grip * (load / (mass * g / 4)) * (mass / 4) / 0.1
			local drive = if corner.front then Vector3.zero else fwd * throttle * ENGINE * mass * g / 2
			corner.f.Force = up * load + lateral + drive
		end
	end)

	return function()
		conn:Disconnect()
		for _, corner in corners do corner.f:Destroy() end
	end
end

return Car
```

What the numbers mean (Rule of thumb): the lateral term tries to cancel sideways wheel velocity within about 0.1 s, scaled by how loaded the wheel is, so a wheel in the air or barely touching has no grip. Rear-wheel drive with `ENGINE = 1.0` gives roughly 0.5 g of acceleration. Start there, then tune feel in [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]].

Physical setup that matters as much as the script:

- **Root friction near zero** (`CustomPhysicalProperties` with friction 0 and `FrictionWeight` high). The root still collides with walls and the ground if a spring bottoms out, and engine friction there fights your tyre model.
- **Rounded collider.** A box catches on wall corners; a wedge or rounded union slides.
- **Mass is your choice.** Set density on the root; visuals `Massless = true`.
- **Ownership.** The driver must own the car or forces apply on a client that is not simulating it ([[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]]).

## 4. Auditing a community kit

Community chassis are common in RP and city games; the best-known family is A-Chassis and its forks (**Unverified:** current maintainer and licence; check the source you take it from). Whatever kit you pick, audit before shipping:

| Check | Why |
|---|---|
| Source: Creator Store asset from a known creator, or a public repository | Backdoored copies of popular kits are a known problem ([[Creator Store and Toolbox Safety]]) |
| Search for `require(` with numeric ids, `loadstring`, `getfenv`, HTTP calls | Classic backdoor patterns |
| List every `RemoteEvent` the kit creates and what the server does with each | Many kits trust client remotes for lights, sirens, damage or even spawning |
| Deprecated body movers (`BodyVelocity`, `BodyGyro`, `BodyThrust`) | Still run, but are deprecated; replacement is `LinearVelocity`, `AlignOrientation`, `VectorForce` ([[Mover Constraints and Physics Controllers]]) |
| Input: does it read keyboard directly via `UserInputService`? | Breaks phones and console; plan to feed it from your own actions ([[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]]) |
| Per-frame cost with 20 cars in a test server | Kits with gauges, sounds and per-wheel scripts can be expensive |
| Does it survive `StreamingEnabled` and deferred signals? | Older kits index parts directly and break when the car streams in piecewise ([[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]]) |

If more than two rows fail, writing the raycast car above is usually less work than fixing the kit.

## Common mistakes

| Mistake | Fix |
|---|---|
| Shipping the legacy hinge-surface car | Constraint or raycast car |
| Constraint wheels for a 200 studs/s racer | Raycast |
| Raycast car root with default friction | Friction 0 on the root collider |
| Ignoring wheel load in grip | Scale lateral force by spring load |
| Dropping in a kit without reading its remotes | Audit table above |
| Two input paths, one per chassis type | One action layer feeding both |

## Checklist

- [ ] Chassis type chosen with the decision guide and the reason written down.
- [ ] Raycast car: root friction 0, rounded collider, chosen mass, massless visuals.
- [ ] Spring numbers derived from frequency and damping ratio.
- [ ] Kit audited for backdoors, remotes, deprecated movers, mobile input, streaming.
- [ ] Driver owns the car; tested with 20 cars on a phone.

## See also

[[Cars with Constraints - Suspension Steering and Drive]] · [[Genre Playbook - Racing and Driving]] · [[Physics Assemblies and Constraints]] · [[Mover Constraints and Physics Controllers]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Springs Damping and Smoothing]] · [[Creator Store and Toolbox Safety]] · [[Physics Performance]]

## Connected notes
<!-- auto-links:start -->
[[Physics and Vehicles Start Here]] · [[Boats Buoyancy and Water]] · [[Aircraft and Flight Models]] · [[Network Ownership]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Centre of Mass, Anti-Flip and Self-Righting]] · [[Engine, Gearbox and Torque Curve Model for Arcade Cars]] · [[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]] · [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]] · [[Vehicle Damage, Repair and Wreck States]] · [[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]] · [[Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars]]
<!-- related:end -->
