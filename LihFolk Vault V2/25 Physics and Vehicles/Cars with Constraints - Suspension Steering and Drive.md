---
tags: [physics, vehicles, constraints, cars, suspension, network-ownership, type/guide, area/physics, level/intermediate, api/SetNetworkOwner, area/networking, api/CollectionService]
---
# Cars with Constraints - Suspension Steering and Drive

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Mesh tyre with Hull collision -> Plain cylinder collider, mesh as massless visual
> - Avoid: Body panels with mass -> `Massless = true` on all visuals, mass in a low root
> - Avoid: Spring numbers guessed -> Compute from frequency and damping ratio (section 3)
> - Chosen family (constraint or raycast) for a stated reason.
> - One corner built and mirrored; constraint axes checked with visualisation.
> - Spring stiffness, damping and free length computed from mass, frequency and damping ratio.
>
> Cost: TL;DR ~170 tok · whole note ~6.6k tok. Read more: ## 3. Suspension: compute it, do not guess · ## 4. Drive and steering from player input · ## 10. Common mistakes · ## Checklist
<!-- tldr:end -->

A drivable car on Roblox can be built with almost no code: a chassis, four wheels on hinges, springs and a `VehicleSeat`. It will also flip on the first bump, slide sideways like soap, stutter for passengers and let an exploiter drive it at 900 studs per second. This note goes past "attach a HingeConstraint" into the decisions that make a car feel good and stay fair: which constraint layout to use, how to compute spring numbers instead of guessing, how to drive and steer from player input, why the centre of mass matters more than the engine, who should simulate the car, and when to throw the physical wheels away and use raycast suspension.

Read [[Physics Assemblies and Constraints]] and [[Mover Constraints and Physics Controllers]] first; this note assumes you know what an assembly is and what a force limit does. Ownership basics live in [[Network Ownership]].

Source labels: **Docs** (Roblox docs, as of October 2026), **Rule of thumb** (experience, not a hard limit). All code is strict Luau, **reviewed, not run**.

---

## 1. Two families of car

| Family | How wheels work | Good for | Costs |
|---|---|---|---|
| **Constraint car** | Real wheel parts on Hinge/Cylindrical constraints, Springs for suspension | Off-road, physics sandboxes, crash games, anything where wheels must hit things | Tuning is fiddly; high speed is unstable; wheels can tunnel or catch on seams |
| **Raycast car** | One rigid chassis; each corner casts a ray down and applies a spring force; wheels are visual only | Racing, kart games, arcade driving, high speed | You write the tyre model yourself; wheels never physically touch a wall |

Rule of thumb: if the fun is the car's body interacting with the world (rolling over rocks, losing a wheel, trailers), build a constraint car. If the fun is speed and control, build a raycast car. Most successful racing-style games use the second kind, because a solver-driven wheel at 150 studs/s is a small, fast, spinning collision shape, and that is exactly what physics engines are worst at.

Both families share sections 4 (input), 6 (ownership) and 7 (security). Section 8 covers the raycast car.

---

## 2. Constraint layout

### The chassis

- One main part, usually an invisible box, is the **root**. Weld all body panels to it with `WeldConstraint`s and set them `Massless = true` so their shapes do not shift the centre of mass in ways you did not plan ([[Physics Assemblies and Constraints]] explains the Massless rule: it only works when the part is welded to a non-massless part).
- Put the `VehicleSeat` in the same assembly (welded to the chassis).
- Give the root a `CustomPhysicalProperties` density so the total mass is a number you chose. Do not let paint-job panels decide it.

### Wheel options

| Layout per wheel | Parts and constraints | Notes |
|---|---|---|
| **A. CylindricalConstraint** | Chassis attachment, wheel attachment; one Cylindrical (slides along the suspension axis, spins about the axle) plus a SpringConstraint between the same two parts | Fewest parts. The Cylindrical's `InclinationAngle` tilts the rotation axis relative to the slide axis (Docs: property exists; check its exact meaning in Studio). Steering needs an extra part (below) |
| **B. Prismatic + Hinge** | Chassis, an invisible "hub" part on a PrismaticConstraint (vertical slide), a SpringConstraint chassis to hub, the wheel on a HingeConstraint to the hub | Easiest to reason about: each joint does one job. One extra part per wheel |
| **C. Steering knuckle** | Layout B, plus a "knuckle" part between hub and wheel on a servo HingeConstraint about the vertical axis | Use for steered wheels (front) |

The common, debuggable choice is B for rear wheels and C for front wheels. Make hubs and knuckles small, invisible, `CanCollide = false`, and give them low but **not zero** mass: a near-zero mass part between two heavy ones is the classic recipe for a vibrating joint ([[Debugging Physics and Network Ownership]], "mass mismatch").

### Axis discipline

Every constraint depends on attachment axes. The Docs warn that a hinge's two attachments' `Axis` must point the same way, or the rotation happens about the wrong axis. Rules of thumb that save hours:

1. Build one corner perfectly, then mirror it. Do not hand-place four.
2. Turn on constraint visualisation (Model tab, Constraint Details) and check that every hinge's arrow points along the axle and every prismatic's arrow points along the suspension travel.
3. On mirrored wheels, the motor direction flips: a positive `AngularVelocity` drives the left wheels forward and the right wheels backward if both attachments point outward. Either point all axle attachments the same world direction (+X of the car), or store a per-wheel sign attribute and multiply by it. The sign attribute is the more robust choice because it survives rebuilds.

### Collision

- Wheels collide with the world, not with the chassis. Use a `NoCollisionConstraint` per wheel to chassis, or a `Vehicles` collision group that does not collide with itself.
- Use a **cylinder** or **ball** shaped wheel. A `MeshPart` tyre with `CollisionFidelity = Hull` is a faceted polygon and will "tick" over flat ground at speed. If you need a mesh tyre for looks, weld it as a massless, non-colliding visual to a plain cylinder that does the physics.
- Set wheel friction high (1.5 to 2) with `FrictionWeight` high so the tyre wins against road materials, and elasticity near 0. Ice roads then still feel slippery, because friction combines the two surfaces by weight.

---

## 3. Suspension: compute it, do not guess

A `SpringConstraint` pushes attachments toward `FreeLength`, harder with higher `Stiffness`, and `Damping` removes oscillation; the Docs say damping 0 "allows the spring to oscillate endlessly". With `LimitsEnabled`, `MinLength` and `MaxLength` act as hard stops "without restitution" (Docs).

Treat it as the textbook spring-damper (rule of thumb; the Docs do not publish the exact formula):

```
force = Stiffness * (FreeLength - currentLength) - Damping * lengthRate
```

That model is good enough to tune from first principles.

### The three numbers you choose

1. **Sprung mass per corner** `m`: roughly `AssemblyMass / 4` for a four-wheeler (subtract wheel masses if they are large).
2. **Natural frequency** `f` in Hz: how bouncy the car feels. Real road cars sit around 1 to 1.5 Hz; sporty 1.5 to 2.5; karts and arcade cars 2.5 to 4 (rule of thumb).
3. **Damping ratio** `zeta`: 0.2 is floaty, 0.4 to 0.6 feels controlled, 1.0 is critically damped (no overshoot, feels dead).

Then:

```
omega     = 2 * pi * f
Stiffness = m * omega^2
Damping   = 2 * zeta * sqrt(Stiffness * m)
sag       = m * g / Stiffness          -- how far it compresses at rest
FreeLength = rideLength + sag          -- so it rests at the length you want
```

### Worked example

Car `AssemblyMass` = 400, so `m` = 100. Choose `f` = 1.8 Hz and `zeta` = 0.45. Gravity is the Workspace default, 196.2 studs/s² (Docs).

- `omega` = 11.31, `omega^2` = 127.9
- `Stiffness` = 100 x 127.9 = 12,790
- `Damping` = 2 x 0.45 x sqrt(12,790 x 100) = 0.9 x 1,131 = 1,018
- `sag` = 100 x 196.2 / 12,790 = 1.53 studs
- If you want the spring to rest at 2.5 studs, `FreeLength` = 4.03; set `MinLength` around 1.2 (bump stop) and `MaxLength` around 4.

The interesting bit is the sag. Roblox gravity is far stronger per stud than Earth gravity is per metre (one stud is roughly 0.28 m if a character is "about 5 studs tall", so real gravity would be roughly 35 studs/s²). A spring tuned to a realistic frequency therefore sags much further than a real car's. That is why many games either lower `Workspace.Gravity`, raise frequency, or accept a stiffer, slightly kart-like ride. Pick deliberately, and if you change gravity, recompute every spring.

```lua
--!strict
-- Suspension tuning helper. Pure maths, safe to unit test.
local Suspension = {}

export type Tuning = {
	stiffness: number,
	damping: number,
	freeLength: number,
	sag: number,
}

function Suspension.compute(cornerMass: number, frequencyHz: number, dampingRatio: number,
	rideLength: number, gravity: number): Tuning
	local omega = 2 * math.pi * frequencyHz
	local stiffness = cornerMass * omega * omega
	local damping = 2 * dampingRatio * math.sqrt(stiffness * cornerMass)
	local sag = cornerMass * gravity / stiffness
	return {
		stiffness = stiffness,
		damping = damping,
		freeLength = rideLength + sag,
		sag = sag,
	}
end

function Suspension.apply(spring: SpringConstraint, t: Tuning, minLength: number, maxLength: number)
	spring.Stiffness = t.stiffness
	spring.Damping = t.damping
	spring.FreeLength = t.freeLength
	spring.LimitsEnabled = true
	spring.MinLength = minLength
	spring.MaxLength = maxLength
end

return Suspension
```

Call it from a build script with the real `AssemblyMass`, not a guessed one. If the body changes, re-run it.

### Edge cases

- **Mass changes at runtime** (passengers, cargo): characters sitting in seats join the assembly. A heavy avatar on a light kart adds a noticeable share of the mass. Either make the car heavy enough that passengers do not matter, or recompute springs on `Occupant` change.
- **Front/rear balance**: if the centre of mass is not midway, front and rear corners carry different mass. Compute per axle.
- **Bottoming out**: if the car hits `MinLength` on landings, the impulse goes straight into the chassis and can flip it. Raise frequency or `MinLength` before adding damping.

---

## 4. Drive and steering from player input

### Read input from the seat, not from the keyboard

`VehicleSeat` exposes `ThrottleFloat` and `SteerFloat` (Docs; the older integer `Throttle` and `Steer` are deprecated). The engine fills them from the default controls on keyboard, gamepad and the touch thumbstick, so reading the seat gives you every platform for free. That alone is a reason to use a `VehicleSeat` even when you ignore its built-in `MaxSpeed`, `Torque` and `TurnSpeed` drive.

Read them on the **driver's client**, because that machine should own the car (section 6). The values are in the range -1 to 1.

### Motor wheels

A `HingeConstraint` with `ActuatorType = Motor` "attempts to rotate the attachments with the goal of reaching its AngularVelocity", limited by `MotorMaxTorque` and `MotorMaxAcceleration` (Docs). Angular velocity is in radians per second, so:

```
wheelAngularVelocity = targetSpeed / wheelRadius
```

Torque is what the motor may use to get there. Too little and the car cannot climb; too much and the wheels spin up instantly and the car wheelies or flips backward. Start with `MotorMaxTorque` such that `torque / wheelRadius` is around 1 to 2 times the car's weight share per driven wheel, then tune.

### Steering servos

A steering knuckle hinge with `ActuatorType = Servo` turns to `TargetAngle` at `AngularSpeed` with `ServoMaxTorque` (Docs). Make the servo torque high (it must beat the tyre's grip), and make the angle shrink with speed, or the car will snap-spin at full steering lock on the highway.

### The controller

```lua
--!strict
-- LocalScript (StarterPlayerScripts). Drives the car the local player sits in.
-- Car setup: HingeConstraints tagged "DriveHinge" (Motor) and "SteerHinge" (Servo).
-- Each drive hinge has a number attribute "Sign" (+1 or -1) for mirrored axles.
-- The car Model has attributes MaxSpeed (studs/s), WheelRadius (studs), MaxSteer (degrees).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

type Rig = {
	seat: VehicleSeat,
	drive: { HingeConstraint },
	steer: { HingeConstraint },
	maxSpeed: number,
	radius: number,
	maxSteer: number,
}

local current: Rig? = nil
local stepConn: RBXScriptConnection? = nil

local function numberAttr(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function buildRig(seat: VehicleSeat): Rig?
	local car = seat:FindFirstAncestorWhichIsA("Model")
	if car == nil then
		return nil
	end
	local drive: { HingeConstraint } = {}
	local steer: { HingeConstraint } = {}
	for _, d in car:GetDescendants() do
		if d:IsA("HingeConstraint") then
			if d:HasTag("DriveHinge") then
				table.insert(drive, d)
			elseif d:HasTag("SteerHinge") then
				table.insert(steer, d)
			end
		end
	end
	return {
		seat = seat,
		drive = drive,
		steer = steer,
		maxSpeed = numberAttr(car, "MaxSpeed", 80),
		radius = numberAttr(car, "WheelRadius", 1.5),
		maxSteer = numberAttr(car, "MaxSteer", 30),
	}
end

local function step(_dt: number)
	local rig = current
	if rig == nil then
		return
	end
	local seat = rig.seat
	local throttle = seat.ThrottleFloat
	local steerIn = seat.SteerFloat

	-- Forward speed along the car's facing.
	local forwardSpeed = seat.CFrame.LookVector:Dot(seat.AssemblyLinearVelocity)
	local speed01 = math.clamp(math.abs(forwardSpeed) / rig.maxSpeed, 0, 1)

	-- Braking: throttle opposes motion -> hold wheels still with full torque.
	local braking = throttle ~= 0 and forwardSpeed * throttle < -2
	local targetSpeed = if braking then 0 else throttle * rig.maxSpeed
	local wheelAv = targetSpeed / rig.radius

	for _, hinge in rig.drive do
		local sign = numberAttr(hinge, "Sign", 1)
		hinge.AngularVelocity = wheelAv * sign
		-- Coast with a small torque so the car rolls when the player lets go.
		hinge.MotorMaxTorque = if throttle == 0 and not braking then 200 else 30000
	end

	-- Speed-sensitive steering: full lock when slow, about a third at top speed.
	local lock = rig.maxSteer * (1 - 0.65 * speed01)
	for _, hinge in rig.steer do
		hinge.TargetAngle = steerIn * lock
	end
end

local function onSeated(active: boolean, seatPart: BasePart?)
	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
	current = nil
	if active and seatPart and seatPart:IsA("VehicleSeat") then
		current = buildRig(seatPart)
		if current then
			stepConn = RunService.PreSimulation:Connect(step)
		end
	end
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Seated:Connect(onSeated)
end

if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)
```

Notes on the code:

- `PreSimulation` runs before physics each frame, which is where control inputs belong. Setting constraint properties every frame is cheap; creating instances every frame is not.
- The torque numbers (200, 30000) are placeholders for a car of mass around 400. Scale them with mass. Put them in attributes once they are tuned.
- When the driver leaves, the last `AngularVelocity` stays on the hinges. The server should reset them (section 6), because the client that set them may have left the game.

---

## 5. Stability: the centre of mass is the real engine

Most "my car flips" reports are not suspension problems. They come from a high centre of mass relative to the track width.

- **Read it.** `chassis.AssemblyCenterOfMass` is read-only and world-space. Draw a small sphere there during tuning. If it is above the wheel tops, the car will roll in corners.
- **Lower it.** Make all body panels `Massless`, and put the mass in a flat root box near axle height or below. A dense invisible "ballast" part welded low on the chassis is a legitimate trick.
- **Widen it.** Track width beats everything else for rollover resistance. A narrow tall car needs help.
- **Help it, gently.** An `AlignOrientation` in `PrimaryAxisParallel` mode that keeps the car's up axis near world up, with a **low** `MaxTorque`, resists flips without making the car feel glued. If the torque is high, the car cannot pitch over hills and feels fake.
- **Recover.** Give players a "flip back" action with a cooldown that, on the owning client, raises the car slightly and sets it upright. Do it on the server if the car is server-owned.

Downforce: a `VectorForce` pointing down along the car's up axis, scaled with speed squared, increases grip at speed without changing low-speed handling. It is a cheap, common arcade trick.

---

## 6. Ownership: who simulates the car

The Docs use a car as the main example of why ownership matters. A vehicle with a driver's `VehicleSeat` and a passenger `Seat` is one assembly; if the passenger sits first and automatic ownership hands the car to them, the driver's input is delayed by "several network cycles". The fix in the Docs is to watch the seat's `Occupant` and call `SetNetworkOwner(player)` for the driver, then `SetNetworkOwnershipAuto()` when the seat empties. The Docs also say to give the driver ownership of any loose parts riding on the car.

```lua
--!strict
-- Script (ServerScriptService). Assigns car ownership to the driver.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local function resetMotors(car: Instance)
	for _, d in car:GetDescendants() do
		if d:IsA("HingeConstraint") and d:HasTag("DriveHinge") then
			d.AngularVelocity = 0
			d.MotorMaxTorque = 2000 -- parked: hold still
		end
	end
end

local function watchSeat(seat: VehicleSeat)
	local car = seat:FindFirstAncestorWhichIsA("Model")
	if car == nil then
		return
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local root = seat.AssemblyRootPart
		if root == nil or root.Anchored then
			return
		end
		local humanoid = seat.Occupant
		local driver = if humanoid then Players:GetPlayerFromCharacter(humanoid.Parent) else nil
		if driver then
			root:SetNetworkOwner(driver)
		else
			resetMotors(car)
			root:SetNetworkOwner(nil) -- parked cars stay on the server
		end
	end)
end

for _, seat in CollectionService:GetTagged("DriverSeat") do
	if seat:IsA("VehicleSeat") then
		watchSeat(seat)
	end
end
CollectionService:GetInstanceAddedSignal("DriverSeat"):Connect(function(seat)
	if seat:IsA("VehicleSeat") then
		watchSeat(seat)
	end
end)
```

The example parks cars on the server rather than calling `SetNetworkOwnershipAuto()`. Trade-off: server-owned parked cars cannot be shoved by a nearby client's local simulation (a common griefing and exploit path), but every parked car costs server physics while it moves. Parked cars usually sleep, so the cost is small. If you have hundreds of cars, anchor parked ones and unanchor on sit (but remember the Docs: unanchoring returns the assembly to automatic ownership and loses its previous ownership state, so set the owner again right after unanchoring).

Passengers see the car through replication, slightly behind the driver. That is normal. What is not normal is the car snapping back: that is an ownership flip, diagnosed in [[Debugging Physics and Network Ownership]].

---

## 7. Security: the driver owns the physics

Client ownership means the driver's machine is the authority on the car's position. An exploiter can set any velocity, teleport the car, or fly it. You cannot stop them sending the data; you can refuse to let it matter.

| Check (server, a few times per second) | Why |
|---|---|
| Speed along the ground above the car's `MaxSpeed` plus a margin (for downhill and ramps) | Speed hacks |
| Vertical position far above terrain for longer than any jump allows | Flying cars |
| Distance moved between checks larger than `maxSpeed x dt x 1.5` | Teleports |
| Car outside the map bounds | Loss of the car, or reaching secret areas |

On violation, take ownership back (`SetNetworkOwner(nil)`), move the car to the last good position, and log. Never kick on one sample: lag spikes and legit physics glitches produce false positives. The patterns and thresholds are covered in [[Detecting Movement Exploits - Speed Fly Noclip Teleport]].

Gameplay results that depend on the car (race finish, collision damage to others) must be decided by the server from its own replicated view and checkpoints, not reported by the client. A "lap complete" remote from the client is an invitation.

---

## 8. Raycast suspension: the arcade alternative

A raycast car is one rigid chassis with no wheel physics at all. Every physics step, for each corner:

1. Cast a ray (or a small `Spherecast` for smoother bumps) down from the wheel mount, length `restLength + wheelRadius`.
2. If it hits, compression `x = restLength - (hitDistance - wheelRadius)`.
3. Spring force along the chassis up axis: `k * x - c * v`, where `v` is the mount point's velocity along up (`root:GetVelocityAtPosition(mount)`).
4. Grip: take the mount point's velocity along the wheel's right vector and push against it, scaled by the suspension force (more load, more grip).
5. Drive: push along the wheel's forward vector from throttle.

Apply the sum with a `VectorForce` per corner, `RelativeTo = World`, `ApplyAtCenterOfMass = false`, attached at the mount. Applying forces at the corners makes pitch and roll happen naturally.

```lua
--!strict
-- One corner of a raycast car. Called from the owning client's PreSimulation.
local function stepCorner(root: BasePart, mount: Attachment, force: VectorForce,
	params: RaycastParams, rest: number, radius: number, k: number, c: number,
	grip: number, drive: number)
	local origin = mount.WorldPosition
	local up = root.CFrame.UpVector
	local result = workspace:Raycast(origin, -up * (rest + radius), params)
	if result == nil then
		force.Force = Vector3.zero -- wheel in the air
		return
	end
	local compression = rest - (result.Distance - radius)
	local pointVel = root:GetVelocityAtPosition(origin)
	local springForce = math.max(0, k * compression - c * pointVel:Dot(up))

	local right = mount.WorldCFrame.RightVector
	local forward = mount.WorldCFrame.LookVector
	local sideSlip = pointVel:Dot(right)

	local total = up * springForce
		- right * sideSlip * grip * springForce
		+ forward * drive
	force.Force = total
end
```

`math.max(0, ...)` matters: a real spring cannot pull the car down onto the road. Without it, cars stick to ceilings over crests. The grip term multiplied by `springForce` is a crude load-sensitive tyre; for drifting, lower `grip` on the rear wheels when the handbrake is held. Wheel visuals are positioned on the client at `origin - up * (result.Distance - radius)` and spun by `forwardSpeed / radius`.

Use a collision group so the rays ignore the car itself and other cars' visuals, and give the chassis a rounded collider (a ball or capsule-like union) so it slides along walls instead of catching on corners.

---

## 9. When not to use a physical car

- **On-rails rides** (a theme-park train, a cutscene vehicle): tween or `PivotTo` an anchored model along a path, and weld players in. Physics adds risk with no benefit.
- **Hundreds of AI cars** (traffic): simulate them as points along road splines on the server, render on clients near them, and only spawn a physical car when a player gets involved. See [[Interest Management and Per-Player Replication]].
- **Mobile-heavy audiences with many cars per server**: each driven car is a client-owned assembly whose updates every other client receives. Budget bandwidth ([[Network Bandwidth Budgets and Measuring Them]]).

---

## 10. Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Mesh tyre with Hull collision | Car ticks and shakes at speed | Plain cylinder collider, mesh as massless visual |
| Body panels with mass | Centre of mass high, car rolls | `Massless = true` on all visuals, mass in a low root |
| Spring numbers guessed | Car bounces forever or sits on bump stops | Compute from frequency and damping ratio (section 3) |
| Same motor sign on both sides | Car spins on the spot | Per-wheel `Sign` attribute |
| Passenger seat owns the car | Driver input lags | Assign ownership to the driver on `Occupant` change (Docs) |
| Full steering lock at top speed | Car spins out on any input | Speed-sensitive lock |
| Infinite motor torque | Wheelies, flips, launches | Torque scaled to mass |
| Lap or finish reported by client | Instant-win exploits | Server-side checkpoints |
| Changing gravity after tuning | All cars sag or bounce wrongly | Recompute springs |

## Checklist

- [ ] Chosen family (constraint or raycast) for a stated reason.
- [ ] One corner built and mirrored; constraint axes checked with visualisation.
- [ ] Spring stiffness, damping and free length computed from mass, frequency and damping ratio.
- [ ] Visual parts massless; centre of mass drawn and below wheel tops.
- [ ] Input read from `ThrottleFloat`/`SteerFloat` on the driver's client in `PreSimulation`.
- [ ] Driver given ownership on sit; motors reset and ownership reclaimed on leave.
- [ ] Server speed, height, teleport and bounds checks with tolerance.
- [ ] Tested with 2+ clients, with a passenger, on a phone, and over the worst bump in the map.

## See also

[[Physics and Vehicles Start Here]] · [[Physics Assemblies and Constraints]] · [[Mover Constraints and Physics Controllers]] · [[Network Ownership]] · [[Debugging Physics and Network Ownership]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] · [[Physics Performance]] · [[Springs Damping and Smoothing]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Boats Buoyancy and Water]] · [[Aircraft and Flight Models]] · [[Genre Playbook - Racing and Driving]]

## Connected notes
<!-- auto-links:start -->
[[Racing Laps and Checkpoints End to End]] · Links - Constraints · [[Ropes Chains and Soft Bodies]] · Rigs and Joints · Modeling Weapons and Props · Custom Rigs - Weapons and Props
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Centre of Mass, Anti-Flip and Self-Righting]] · [[Engine, Gearbox and Torque Curve Model for Arcade Cars]] · [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]] · [[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]]
<!-- related:end -->
