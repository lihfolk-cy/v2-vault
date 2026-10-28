---
tags: [gameplay, physics, movers, linearvelocity, alignposition, controllermanager]
---
# Mover Constraints and Physics Controllers

Mover constraints are how you push, pull, steer and hold assemblies without fighting the solver. Dashes, knockback, grabs, hover, homing projectiles and server-driven NPC movement are all built from the same seven constraints. The physics character controller (`ControllerManager`) is the same idea packaged for characters. This note covers what each mover does, the properties that matter, the patterns that held up in a production combat game, and the traps.

Background on assemblies and ownership: [[Physics Assemblies and Constraints]]. Character-specific behaviour: [[Characters and Humanoids]] and [[Custom Character Controllers]].

Source labels: **Docs** (official reference, checked October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. The seven movers

| Constraint | Does | Replaces legacy (Docs) |
|---|---|---|
| `LinearVelocity` | Holds a velocity along a vector, a line or a plane | `BodyVelocity` |
| `AngularVelocity` | Holds an angular velocity | `BodyAngularVelocity` |
| `AlignPosition` | Drives an attachment to a position or to another attachment | `BodyPosition` |
| `AlignOrientation` | Drives an attachment to an orientation, axis or look-at point | `BodyGyro` |
| `VectorForce` | Applies a constant force | `BodyForce`, `BodyThrust` |
| `LineForce` | Force along the line between two attachments | `RocketPropulsion` (with AlignOrientation) |
| `Torque` | Constant torque from the centre of mass | |

The legacy `Body*` movers are deprecated (Docs). They still run in old models, but new code should use the constraints: they share attachments, force limits and visualisation with the rest of the constraint system.

All movers need **Attachment0** (the attachment on the assembly being moved). Two-attachment modes also use **Attachment1**. A mover whose attachment is missing or not in the world silently does nothing; that is the first thing to check when "the dash does nothing".

### Force limits: the single most important setting
Every mover answers "how hard may I push?". If the answer is "infinitely", the mover wins every fight: against walls (it pushes through thin geometry or jitters), against other movers, and against characters it touches.

- `LinearVelocity`: `ForceLimitsEnabled` true plus `ForceLimitMode` (`Magnitude` with `MaxForce`, or `PerAxis` with `MaxAxesForce` / `MaxPlanarAxesForce`). With limits disabled, "the solver applies whatever force is needed" (Docs).
- `AlignPosition`: `RigidityEnabled` true ignores `MaxForce`, `MaxVelocity` and `Responsiveness` and aligns "as quickly as possible" (Docs). False uses the limits.
- `AlignOrientation`: same idea with `MaxTorque`, `MaxAngularVelocity`, `Responsiveness`, `RigidityEnabled`.

Rule of thumb: start with a force limit scaled by mass, `MaxForce = AssemblyMass * acceleration`, where acceleration is how fast you want to reach the target (studs/s^2). A value around `mass * 2000` reaches a dash speed within a frame or two without punching through walls.

---

## 2. LinearVelocity

| Property | Notes (Docs) |
|---|---|
| `VelocityConstraintMode` | `Vector` (default), `Line`, `Plane` |
| `VectorVelocity` | Target in Vector mode |
| `LineDirection`, `LineVelocity` | Line mode: only that axis is constrained |
| `PlaneVelocity`, `PrimaryTangentAxis`, `SecondaryTangentAxis` | Plane mode: two axes constrained, the third free |
| `RelativeTo` | `World` (default), `Attachment0`, `Attachment1` |
| `ForceLimitsEnabled`, `ForceLimitMode`, `MaxForce`, `MaxAxesForce`, `MaxPlanarAxesForce` | Force limits |
| `ReactionForceEnabled` | Default true; meaningful with `RelativeTo = Attachment1` |

**Plane mode is the dash mode.** A horizontal dash should not fight gravity. Constrain X and Z, leave Y free, and the character still falls off ledges and lands on slopes naturally:

```lua
--!strict
-- Client (the character's owner). Returns a stop function.
local function dash(root: BasePart, direction: Vector3, speed: number, duration: number): () -> ()
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	flat = flat.Unit

	local att = Instance.new("Attachment")
	att.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(flat.X, flat.Z) * speed
	lv.ForceLimitsEnabled = true
	lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	lv.MaxForce = root.AssemblyMass * 2000
	lv.Parent = root

	local stopped = false
	local function stop()
		if stopped then return end
		stopped = true
		lv:Destroy()
		att:Destroy()
	end
	task.delay(duration, stop)
	return stop
end
```

**Measured.** In the reference project a dash from a standstill kept stalling: the Humanoid's own controller was braking toward zero because the player had no move input. The fix was to call `humanoid:Move(direction)` every render frame for the dash's length so the Humanoid wants to go the same way as the LinearVelocity. If you drive a Humanoid with a mover, make the Humanoid agree with it or switch it off (section 6).

**Line mode** is for rails, ziplines and lunges that must stay on a line while other axes stay free. **Vector mode** with `RelativeTo = Attachment0` is for projectiles that fly "forward" in their own frame while an `AlignOrientation` turns them.

---

## 3. AlignPosition

| Property | Notes (Docs) |
|---|---|
| `Mode` | `TwoAttachment` (default) or `OneAttachment` |
| `Position` | Goal in OneAttachment mode |
| `MaxForce` / `MaxAxesForce`, `ForceLimitMode`, `ForceRelativeTo` | Force limits |
| `MaxVelocity` | Speed cap while converging |
| `Responsiveness` | 5 to 200 |
| `RigidityEnabled` | Ignore limits, snap |
| `ApplyAtCenterOfMass` | Default false; true avoids torque from an off-centre attachment |
| `ReactionForceEnabled` | Default false |

**`MaxVelocity` is a walk speed.** For an NPC, OneAttachment mode with `MaxVelocity = walkSpeed` and a high `MaxForce` gives you "go to this point at this speed" with physics doing the integration. Update `Position` from your AI at 5 to 10 Hz and the motion is still smooth, because the solver interpolates at physics rate.

**Measured.** The reference project's enemy runtime uses server-owned `AlignPosition` movers for every enemy. The brain thinks at 10 Hz within 200 studs of a player and sets a goal; chase, wander, return-home, kit pulls and knockback are all "place a goal, let the mover take it there". Offline dry runs modelled it as "the root moves toward the goal at MaxVelocity", which matched live behaviour well enough to test thousands of navigation cases in Edit (where there is no physics).

### Pull / grab pattern
A "caught" pull (an ultimate drags enemies into a slot, holds them, releases) is AlignPosition with a moderate `MaxVelocity` (the glide speed) and `Responsiveness` around 30 to 60, then raising `MaxVelocity` or enabling rigidity for the hold. Disable or destroy the mover before releasing, or the target snaps back when you think you let go. Rule from the reference project: **pull before damage**, so the hit lands where the animation expects the body.

### Hover pattern
AlignPosition on Y only (`ForceLimitMode = PerAxis`, `MaxAxesForce = Vector3.new(0, big, 0)`) holds hover height while other movers or the Humanoid handle horizontal motion.

---

## 4. AlignOrientation

| Property | Notes (Docs) |
|---|---|
| `Mode` | `TwoAttachment` (default) or `OneAttachment` |
| `CFrame` | Goal orientation in OneAttachment mode (translation ignored) |
| `PrimaryAxis`, `SecondaryAxis` | Goal axes in OneAttachment mode |
| `AlignType` | `AllAxes`, `PrimaryAxisParallel`, `PrimaryAxisPerpendicular`, `PrimaryAxisLookAt` |
| `LookAtPosition` | Used with `PrimaryAxisLookAt` in OneAttachment mode |
| `MaxTorque`, `MaxAngularVelocity`, `Responsiveness`, `RigidityEnabled` | Limits |
| `ReactionTorqueEnabled` | Default false |

Uses:
- **NPC facing.** OneAttachment, `AllAxes`, set `CFrame = CFrame.lookAt(Vector3.zero, flatDirection)` each think. Flatten the direction (Y = 0) or the NPC tilts toward targets above it.
- **Keep a prop upright.** `PrimaryAxisParallel` with the attachment's up axis keeps a floating object level while letting it spin around Y.
- **Homing projectile.** `PrimaryAxisLookAt` with `LookAtPosition` set to the target, plus a `LinearVelocity` in Vector mode `RelativeTo = Attachment0` pushing along the attachment's forward axis. Lower `MaxAngularVelocity` = wider turning circle = dodgeable missile.

**Attachment axes matter.** The "primary axis" of an attachment is its X axis (`Attachment.Axis`) and the secondary is Y (`SecondaryAxis`). A homing missile that flies sideways usually has an attachment whose X axis is not the model's forward. Rotate the attachment, not the mesh.

---

## 5. VectorForce, LineForce, Torque

- `VectorForce`: constant force; `RelativeTo` defaults to Attachment0 and the force is applied at Attachment0 unless `ApplyAtCenterOfMass` is true (Docs). Constant force means unbounded speed; the docs suggest `LinearVelocity` for steady speed. Good for wind zones, anti-gravity, thrusters.
- `LineForce`: pulls along the line between two attachments (magnets, tractor beams, black-hole abilities). An inverse-square option exists on its reference page.
- `Torque`: constant spin force. Pair with `AngularVelocity` if you need a speed cap.

Wind zone sketch (server-owned props only; for players apply on their client):

```lua
--!strict
local function applyWind(root: BasePart, windPerMass: Vector3): VectorForce
	local att = root:FindFirstChild("WindAttachment") :: Attachment?
	if not att then
		local a = Instance.new("Attachment")
		a.Name = "WindAttachment"
		a.Parent = root
		att = a
	end
	local vf = Instance.new("VectorForce")
	vf.Attachment0 = att
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.ApplyAtCenterOfMass = true
	vf.Force = windPerMass * root.AssemblyMass
	vf.Parent = root
	return vf
end
```

---

## 6. Movers on Humanoid characters

A Humanoid is itself a controller: every frame it applies forces to reach `WalkSpeed` in `MoveDirection`, stands the character up at `HipHeight`, applies friction and handles slopes. Your mover and the Humanoid now share the root. Three ways to resolve the fight:

| Approach | When | Cost |
|---|---|---|
| Make the Humanoid agree (feed `Move(dir)` in the same direction) | Short dashes, lunges | Cheap; Humanoid still handles ground and slopes |
| Change state (`Physics` or `PlatformStanding`) for the duration | Ragdolls, launches, grabs, being carried | Humanoid stops standing up; you must restore state |
| `EvaluateStateMachine = false` with a ControllerManager | A full custom controller | Biggest change; section 7 |

**Physics state gotcha.** Setting `HumanoidStateType.Physics` on a player stops the Humanoid driving the body, but `ChangeState` only works on the machine that owns the character (Docs: a LocalScript if the client owns it, a server Script if the server does). A server calling `ChangeState(Physics)` on a player's Humanoid does nothing useful. Again: server decides, client applies.

**Launch upward.** A Humanoid in the `Running` state presses the character into the ground. For a knock-up, change to `Freefall` or `Physics` (on the owner), then apply the impulse or LinearVelocity; otherwise the first few frames of upward velocity are eaten.

---

## 7. ControllerManager: the physics character controller

`ControllerManager` "manages simulated motion control for its assigned RootPart and can be used to build a physics-based character controller" (Docs). It replaces the Humanoid's internal movement forces with explicit, tunable controllers.

### Structure

| Instance | Role | Key properties (Docs) |
|---|---|---|
| `ControllerManager` | The brain that applies forces | `RootPart`, `ActiveController`, `BaseMoveSpeed`, `BaseTurnSpeed`, `MovingDirection` (0 to 1 magnitude), `FacingDirection`, `UpDirection` (default up), `GroundSensor`, `ClimbSensor` |
| `GroundController` | Walking | `GroundOffset` (height above sensed ground), `AccelerationTime`, `DecelerationTime`, `Friction`, `FrictionWeight`, `TurnSpeedFactor`, `BalanceSpeed`, `BalanceMaxTorque` |
| `AirController` | Falling, gliding | `MoveMaxForce`, `TurnMaxTorque`, `MaintainLinearMomentum`, `MaintainAngularMomentum`, `BalanceSpeed`, `TurnSpeedFactor` |
| `ClimbController`, `SwimController` | Ladders, water | See their reference pages |
| `ControllerPartSensor` | Finds floor or ladder | `SensorMode` (`Floor` looks down the world's negative up; `Ladder` looks along the part's forward), `SearchDistance`, outputs `SensedPart`, `HitFrame`, `HitNormal`, `SensedMaterial` |
| `BuoyancySensor` | Detects water | Used to switch to swimming |

All controllers inherit `MoveSpeedFactor` (multiplies `BaseMoveSpeed`), `BalanceRigidityEnabled` and `Active` from `ControllerBase`.

### Minimal setup

```lua
--!strict
-- Runs on the machine that owns the character (the player's client for players,
-- the server for NPCs). Builds a ControllerManager next to the Humanoid.
local function buildController(character: Model): ControllerManager
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = humanoid.RootPart :: BasePart

	-- Stop the Humanoid applying its own movement forces and state changes.
	-- State events, appearance and Move() input still work (Docs).
	humanoid.EvaluateStateMachine = false

	local manager = Instance.new("ControllerManager")
	manager.RootPart = root
	manager.BaseMoveSpeed = humanoid.WalkSpeed
	manager.BaseTurnSpeed = 8

	local ground = Instance.new("GroundController")
	ground.GroundOffset = humanoid.HipHeight
	ground.AccelerationTime = 0.12
	ground.DecelerationTime = 0.08
	ground.Parent = manager

	local air = Instance.new("AirController")
	air.MaintainLinearMomentum = true
	air.Parent = manager

	local floorSensor = Instance.new("ControllerPartSensor")
	floorSensor.Name = "GroundSensor"
	floorSensor.SensorMode = Enum.SensorMode.Floor
	floorSensor.SearchDistance = humanoid.HipHeight + 2
	floorSensor.Parent = root

	manager.GroundSensor = floorSensor
	manager.ActiveController = ground
	manager.Parent = character
	return manager
end
```

Then each frame (bound with `RunService:BindToRenderStep` or `PreSimulation` on the owner):

```lua
--!strict
local function step(manager: ControllerManager, humanoid: Humanoid)
	manager.MovingDirection = humanoid.MoveDirection -- from the default control scripts
	if humanoid.MoveDirection.Magnitude > 0.01 then
		manager.FacingDirection = humanoid.MoveDirection
	end

	local sensor = manager.GroundSensor :: ControllerPartSensor
	local grounded = sensor.SensedPart ~= nil
	local want: ControllerBase? = if grounded
		then manager:FindFirstChildOfClass("GroundController")
		else manager:FindFirstChildOfClass("AirController")
	if want and manager.ActiveController ~= want then
		manager.ActiveController = want
	end
end
```

Notes from the docs that cause silent failures:
- An `ActiveController` "may not be active", for example if the character is outside its WorldRoot or a GroundController finds no floor part; it stays set and activation is retried every frame. A GroundController on a character in mid-air does nothing; switch to the AirController.
- Setting `ActiveController = nil` disables the controller entirely.
- `UpDirection` ignores zero, NaN or infinite values. Wall-walking or planet gravity is done by setting it.

**Animation does not come for free.** With `EvaluateStateMachine = false` the Humanoid no longer transitions states itself, so the default Animate script (which listens to Humanoid state events) shows the wrong clips unless you call `ChangeState` yourself to mirror what your controller is doing. See [[Humanoid States and Animation]] and [[Custom Locomotion Controller Design]].

### Character Controller Library (beta)
As of October 2026 the docs describe a beta **Character Controller Library** (CCL, `require("@rbx/AvatarAbilities")`) that builds on this: movement is split into "abilities" (Running, Jumping, Climbing, Falling Down, and your own, such as Dash or Glide) with start conditions on sensors, conflict rules and callbacks (`OnStart`, `OnUpdate`, `OnStop`) that must be deterministic because they run on both the predicting client and the authoritative server. It is opt-in via Beta Features and Avatar Settings. Treat it as beta: verify the API on the current docs page before building on it.

---

## 8. Choosing a movement technology

| Need | Use |
|---|---|
| Standard platformer or simulator | Default Humanoid. Tune WalkSpeed, JumpHeight |
| Dashes, lunges, knockback on a normal character | Humanoid + short-lived LinearVelocity / impulse on the owning client |
| Server-driven NPCs that must not be client-influenced | Server-owned assembly + AlignPosition/AlignOrientation (Humanoid optional) |
| Wall-running, variable gravity, custom slopes, vehicles-as-characters | ControllerManager |
| Many cheap NPCs (100+) | Anchored roots moved by CFrame on the server or client-side visuals; physics optional |

**Measured.** The reference project kept the standard Humanoid for players (with a custom procedural animator and a dash built from LinearVelocity plus `Move`) and gave enemies server-owned AlignPosition movers. It never needed ControllerManager. That is the common case: reach for ControllerManager when the Humanoid's movement model is the problem, not when one move needs a push.

---

## 9. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| No force limit | Pushes through thin walls, launches other players | `ForceLimitsEnabled` + mass-scaled `MaxForce` |
| Vector-mode dash | Character floats over ledges during the dash | Plane mode, Y free |
| Mover without attachment | Nothing happens, no error | Assert `Attachment0` exists and is parented |
| Mover added on the server to a player | Late or ignored motion | Create on the owning client |
| Forgetting to destroy | Character slides forever after a dash | `task.delay` cleanup plus cleanup on death |
| AlignOrientation unflattened | NPC leans toward targets on ledges | Zero the Y of the look direction |
| `RigidityEnabled` on a grab | Target teleports, can clip through walls | Limited `MaxVelocity` glide |
| Humanoid fights the mover | Dash stalls from a standstill | `Move(dir)` alongside, or state change |
| EvaluateStateMachine false, Animate unchanged | Character runs in the falling pose | Drive states/animations yourself |

## Checklist
- [ ] Every mover has an attachment, a force limit and a guaranteed cleanup path (timer, death, unequip).
- [ ] Player movers run on the player's client; NPC movers on the server with server ownership.
- [ ] Dashes use Plane mode and agree with the Humanoid.
- [ ] Homing and facing use flattened directions unless 3D is intended.
- [ ] ControllerManager setups switch controllers based on sensors and mirror Humanoid states for animation.

## See also
[[Physics Assemblies and Constraints]] · [[Characters and Humanoids]] · [[Custom Character Controllers]] · [[NPC AI and Behaviour]] · [[Combat Systems Architecture]] · [[Locomotion Systems]] · [[Custom Locomotion Controller Design]] · [[Ragdolls and Physics-Based Animation]] · [[Network Ownership]]

## Connected notes
<!-- auto-links:start -->
[[Aircraft and Flight Models]] · [[Links - Forces and movers]] · [[Boats Buoyancy and Water]] · [[Debugging Physics and Network Ownership]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Snippets - Ragdoll]]
<!-- auto-links:end -->
