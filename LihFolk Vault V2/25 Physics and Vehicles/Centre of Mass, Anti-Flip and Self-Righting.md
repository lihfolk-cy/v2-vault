---
tags: [physics, vehicles, cars, center-of-mass, stability, anti-roll, flip-recovery, type/guide, area/physics, level/intermediate, api/AlignOrientation, api/SetNetworkOwner]
---
# Centre of Mass, Anti-Flip and Self-Righting

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Raising friction to stop sliding -> Cap lateral grip at high slip; widen track
> - Avoid: Always-on strong AlignOrientation -> Gentle on ground, stronger only in air
> - Avoid: Airborne helper left on at landing -> Disable once two wheels are grounded
> - CoM debug sphere checked after every model change.
> - Anti-roll per axle, stiffness tuned below spring rate.
> - Airborne stabiliser only while no wheels are grounded; air control on input.
>
> Cost: TL;DR ~150 tok · whole note ~2.4k tok. Read more: ## 2. Anti-roll bar · ## 5. Self-righting flow (server validated) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Cars with Constraints - Suspension Steering and Drive]] section 5 covers the basics: read `AssemblyCenterOfMass`, make panels massless, add low ballast, use a gentle `AlignOrientation`. This note goes further on the three things that note leaves open: an **anti-roll bar** for raycast and constraint cars, **in-air stabilisation** so jumps land wheels-down, and a **self-righting flow** that is server-validated, works whoever owns the car, and cannot be abused as a teleport. Experienced devs usually get the physics right and the recovery button wrong.

Source labels: **Roblox docs** (create.roblox.com, checked October 2026), **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. Why cars flip that already have a low centre of mass

- **Grip too high for track width.** Rollover happens when lateral tyre force times CoM height exceeds weight times half the track width. If you raised friction to stop sliding, you moved the car from "slides" to "trips". Lower lateral grip at high slip angles before you add more stabilisers. Rule of thumb.
- **Wheel catches a seam or kerb edge.** Constraint wheels with sharp collision shapes hook on part edges. Ball-shaped or chamfered colliders and a `NoCollisionConstraint` against kerb meshes fix more flips than any torque.
- **Assembly root moved.** Welding a heavy accessory (a trailer hitch, a big spoiler with mass) changes CoM silently. `AssemblyCenterOfMass` is read-only (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/BasePart), so you can only move it with mass. Audit with a debug sphere every time the model changes.
- **Ramp nose-dive.** A CoM forward of the wheelbase centre pitches the car nose-down in the air. Put the ballast between the axles, not under the engine.

## 2. Anti-roll bar

A real anti-roll bar pushes down the outer wheel and up the inner wheel in proportion to the difference in suspension compression across an axle. On a raycast car you already have the compressions, so it is three lines per axle:

```lua
--!strict
-- Per axle, called each physics step on the simulating machine. compressionL/R in 0..1.
-- forceL/forceR: VectorForce with RelativeTo = World, Attachment0 on the chassis above each wheel.
local function antiRoll(chassis: BasePart, compressionL: number, compressionR: number,
	stiffness: number, forceL: VectorForce, forceR: VectorForce)
	local up = chassis.CFrame.UpVector
	local f = (compressionL - compressionR) * stiffness
	-- push the chassis up on the compressed (outer) side and down on the extended side
	forceL.Force = up * f
	forceR.Force = up * -f
end
```

Put each `VectorForce`'s attachment on the chassis directly above its wheel and use `RelativeTo = World` so the world-space vector can be passed straight in. Start with `stiffness` at about half the per-wheel spring rate; more makes the car twitchy on single-wheel bumps. Rule of thumb.

On a constraint car, emulate it the same way: read each corner's spring `CurrentLength` (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/SpringConstraint) and apply the forces to the chassis above each wheel.

## 3. In-air stabilisation

When no wheel is grounded (raycast car: all rays miss; constraint car: track a grounded flag per wheel from a short downward ray), the car's pitch and roll are whatever the take-off gave it. Two rules of thumb:

- **Damp, do not snap.** Enable an `AlignOrientation` (or raise its `MaxTorque`) only while airborne, aligning the chassis up vector with world up while keeping yaw free (`AlignType = PrimaryAxisParallel`, Roblox docs: https://create.roblox.com/docs/reference/engine/classes/AlignOrientation). Use a low `Responsiveness` so the car visibly rotates toward level over roughly 0.5 s.
- **Give the player air control.** Steer input in the air adds a small yaw torque, throttle/brake a small pitch torque. Players forgive a lot if they caused it.

Disable the airborne helper the frame two wheels touch down, or it fights the suspension on landing and the car bounces.

## 4. Detecting "flipped", not "steep"

A car on a banked turn or a ramp is tilted, not flipped. Detect flipped as all of:

- `chassis.CFrame.UpVector:Dot(Vector3.yAxis) < 0.3` (more than about 72 degrees off upright),
- forward speed under ~4 studs/s,
- for at least 1.5 to 2 s continuously.

Then show the "Flip" prompt, or auto-right after 3 to 4 s in casual games. Rule of thumb.

## 5. Self-righting flow (server validated)

The flip is a teleport, so it belongs on the server. The client only asks.

```lua
--!strict
-- Server. FlipRequest is a RemoteEvent; cars carry an Owner attribute (UserId).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Remotes.FlipRequest :: RemoteEvent

local COOLDOWN = 5
local lastFlip: { [Player]: number } = {}

local function groundBelow(pos: Vector3, ignore: Instance): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	return workspace:Raycast(pos + Vector3.new(0, 10, 0), Vector3.new(0, -60, 0), params)
end

remote.OnServerEvent:Connect(function(player: Player, car: unknown)
	if typeof(car) ~= "Instance" or not (car :: Instance):IsA("Model") then return end
	local model = car :: Model
	if model:GetAttribute("Owner") ~= player.UserId then return end
	local now = os.clock()
	if now - (lastFlip[player] or 0) < COOLDOWN then return end
	local root = model.PrimaryPart
	if not root then return end
	if root.AssemblyLinearVelocity.Magnitude > 6 then return end      -- must be nearly stopped
	if root.CFrame.UpVector:Dot(Vector3.yAxis) > 0.3 then return end -- must actually be flipped
	local hit = groundBelow(root.Position, model)
	if not hit then return end
	lastFlip[player] = now

	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then flat = Vector3.zAxis end
	local target = CFrame.lookAt(hit.Position + Vector3.new(0, 4, 0), hit.Position + Vector3.new(0, 4, 0) + flat.Unit)

	local driverOwner = root:GetNetworkOwner()
	root:SetNetworkOwner(nil)                -- take the car so the owner's sim cannot overwrite the move
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	model:PivotTo(target)
	task.delay(0.25, function()
		if root.Parent and driverOwner and driverOwner.Parent then
			root:SetNetworkOwner(driverOwner)
		end
	end)
end)
```

Why each guard matters:

- **Speed gate and flipped gate**: without them "flip" is a free unstuck-anywhere and a mid-air reset.
- **Raycast to ground at the car's own XZ**: never trust a client-supplied position.
- **Take ownership briefly**: when a client owns the assembly, its simulation keeps sending the old pose. The short server-owned window makes the pivot stick. The 0.25 s value is a Rule of thumb; check with two clients.
- **Preserve yaw**: players hate being turned round.
- Reset velocities so the car does not keep its tumbling spin. Setting `AssemblyLinearVelocity` and `AssemblyAngularVelocity` is supported on the assembly (Roblox docs, BasePart).

Count flips per minute per player in your movement-exploit logging; legitimate players rarely exceed a few.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Raising friction to stop sliding | Car trips and rolls in corners | Cap lateral grip at high slip; widen track |
| Always-on strong AlignOrientation | Car cannot climb hills, feels glued | Gentle on ground, stronger only in air |
| Airborne helper left on at landing | Bounce and wobble on touchdown | Disable once two wheels are grounded |
| Flip detection by angle alone | Prompt on banked turns | Angle + low speed + time |
| Client pivots its own car | Teleport exploit via "flip" | Server-validated request with cooldown |
| Server pivots a client-owned car | Car snaps back to the flipped pose | Take ownership for a moment, then restore |

## Checklist

- [ ] CoM debug sphere checked after every model change.
- [ ] Anti-roll per axle, stiffness tuned below spring rate.
- [ ] Airborne stabiliser only while no wheels are grounded; air control on input.
- [ ] Flipped = angle + low speed + time.
- [ ] Flip is a server request: owner, cooldown, speed, angle and ground raycast checked.
- [ ] Tested on banked turns, ramps and with two clients.

## See also

[[Cars with Constraints - Suspension Steering and Drive]] · [[Physics Assemblies and Constraints]] · [[Mover Constraints and Physics Controllers]] · [[Network Ownership]] · [[Debugging Physics and Network Ownership]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]

## Connected notes
<!-- auto-links:start -->
[[Engine, Gearbox and Torque Curve Model for Arcade Cars]] · [[Aircraft and Flight Models]] · [[Physics Performance]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]] · [[Boats Buoyancy and Water]] · [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Vehicle Damage, Repair and Wreck States]] · [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]] · [[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]]
<!-- related:end -->
