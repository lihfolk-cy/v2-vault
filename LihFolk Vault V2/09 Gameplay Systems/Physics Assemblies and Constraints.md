---
tags: [gameplay, physics, assemblies, constraints, collision, network-ownership, type/guide, area/gameplay, level/intermediate, api/Touched, area/physics, api/RigidConstraint]
---
# Physics Assemblies and Constraints

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Anchoring two parts of a welded prop -> Anchor only the root
> - Avoid: Large welded prop on a character -> `Massless = true` on the prop or raise `RootPriority` on the root
> - Avoid: Setting `Position` on welded children -> `PivotTo` the model
> - Every moving gameplay object has a known owner, and the owner is the server when the outcome matters.
> - Props welded to characters are Massless.
> - Collision groups registered once at startup, under 32 per world, with a written group matrix.
>
> Cost: TL;DR ~170 tok · whole note ~5.3k tok. Read more: ## 4. Network ownership: who simulates what · ## 6. Collisions: CanCollide, CanTouch, CanQuery and collision groups · ## 9. Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox physics looks simple from the Properties window (tick Anchored, set Velocity, add a weld) and behaves in ways that surprise people as soon as a game has many players, moving NPCs and knockback. This note explains the unit the solver actually works on (the **assembly**), how the root part is chosen, how ownership decides *which computer* simulates an assembly, how rigid and mechanical constraints fit together, and how collision filtering works. Movers (LinearVelocity, AlignPosition and friends) and the physics character controller have their own note: [[Mover Constraints and Physics Controllers]].

Source labels: **Docs** (official engine reference and guides, checked October 2026), **Measured** (the reference project, one live action game), **Rule of thumb** (experience, not a hard limit).

---

## 1. The assembly is the unit of simulation

An assembly is "one or more parts welded by a rigid WeldConstraint or connected through movable joints" and, physically, it is a single rigid body (Docs). The solver does not see your Model, your folder or your tag; it sees assemblies, and mechanisms of assemblies joined by non-rigid constraints.

Every BasePart exposes the assembly-level properties, whichever part you read them from:

| Property | Meaning | Notes |
|---|---|---|
| `AssemblyLinearVelocity` | Linear velocity of the whole assembly | Writable, but "setting the velocity directly may lead to unrealistic motion" (Docs). Prefer a constraint or `ApplyImpulse` |
| `AssemblyAngularVelocity` | Angular velocity of the assembly | Same advice; prefer `AngularVelocity`/`Torque` or `ApplyAngularImpulse` |
| `AssemblyMass` | Sum of all parts' `Mass` | Infinite if any part is anchored (Docs) |
| `AssemblyCenterOfMass` | Read-only mass-weighted centre | A force applied here causes no rotation |
| `AssemblyRootPart` | The root the engine picked | You cannot set it directly |

### What counts as "rigid"
- `WeldConstraint`, `Weld`, `RigidConstraint`, `Motor6D` and other `JointInstance`s join parts into one assembly.
- Mechanical constraints (`HingeConstraint`, `BallSocketConstraint`, `RopeConstraint`, `SpringConstraint`, `PrismaticConstraint`, ...) join assemblies into a **mechanism**: the parts move relative to each other, so they are separate assemblies.
- A character is one assembly per rigid group. Motor6D joints are rigid for the solver (the Animator rewrites their `Transform` each frame), so a standard R15 character is a single assembly rooted at `HumanoidRootPart`. A ragdolled character, where Motor6Ds are swapped for `BallSocketConstraint`s, becomes many assemblies. See [[Ragdolls and Physics-Based Animation]].

### Why it matters
- Velocity, mass and impulses are per assembly. Applying knockback to a sword welded to a character applies it to the character.
- Anchoring is per assembly. Anchoring the root anchors everything rigidly attached to it; the docs recommend anchoring only the root because anchoring every part creates more assemblies and costs more.
- Anchoring more than one part of a welded group **splits** it: the welds between anchored parts deactivate and each anchored part becomes its own assembly (Docs). A "welded model that refuses to move" after you anchored two of its parts is this.

---

## 2. How the root part is chosen

The root decides the assembly's pivot for physics, which part ownership is attached to, and which part the engine reports. The order is (Docs):

1. An anchored part is always the root.
2. Non-massless parts beat `Massless` parts.
3. Higher `RootPriority` wins (integer from -127 to 127).
4. Largest face area, with multipliers: Seats and VehicleSeats rank highest, then parts named `HumanoidRootPart`, then parts named `Torso`.

Consequences people trip over:

- **Welding a large prop to a character can steal the root.** A huge shield or a cape welded to the hand can out-score `HumanoidRootPart` by face area. Set the prop `Massless = true` (it then never becomes root unless everything else is massless, Docs) or give `HumanoidRootPart` a higher `RootPriority`.
- **Massless only works when welded to a massed part.** A lone massless part still has mass for the solver. Massless is "don't count me in my assembly", not "weigh nothing".
- **The root's name matters.** The `HumanoidRootPart` naming multiplier is real; rigs built by hand that call the root something else can end up rooted at a limb, which breaks Humanoid physics in confusing ways.

---

## 3. Mass, density and physical properties

`Mass = density x volume`. Density, friction and elasticity come from the part's `Material` unless `CustomPhysicalProperties` is set:

```lua
-- density, friction, elasticity, frictionWeight, elasticityWeight
part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)
```

Rule of thumb for gameplay tuning:
- **Light props that players should kick around:** low density (0.1 to 0.3). They wake and move on contact.
- **Debris that must not shove players:** make it non-colliding with characters (collision groups, section 6) rather than tuning mass. Light debris still pushes characters around if it collides.
- **Gravity:** `Workspace.Gravity` defaults to 196.2 studs/s^2 (Docs). Changing it changes jump arcs, fall damage maths and every projectile. If you want floatier projectiles only, give them a `VectorForce` that cancels part of gravity instead of changing the world.

Anti-gravity for one assembly (constant upward force equal to its weight):

```lua
--!strict
local function addAntiGravity(root: BasePart, fraction: number): VectorForce
	local att = Instance.new("Attachment")
	att.Name = "AntiGravityAttachment"
	att.Parent = root

	local force = Instance.new("VectorForce")
	force.Attachment0 = att
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true -- no torque from an off-centre attachment
	force.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * fraction, 0)
	force.Parent = root
	return force
end
```

Recompute `Force` if the assembly mass changes (a player picks something up, an accessory loads late). A stale anti-gravity force on a heavier assembly sinks it; on a lighter one it floats away.

---

## 4. Network ownership: who simulates what

Every unanchored assembly is simulated by exactly one machine: the server or one client. That machine sends the results to everyone else. Full detail is in [[Network Ownership]]; the gameplay-relevant core:

| Fact | Source |
|---|---|
| Anchored parts are always server-owned; you cannot change it | Docs |
| The engine assigns unanchored parts by client capacity and proximity to that player's character | Docs |
| `SetNetworkOwner(player)` sets the owner of the part and all connected parts; `nil` means the server | Docs |
| `SetNetworkOwnershipAuto()` hands the decision back to the engine | Docs |
| A player's character is owned by that player | Docs (character control model) |
| "Roblox cannot verify physics calculations when a client has ownership" | Docs |
| Setting server ownership "may result in jittery physics interactions for clients" | Docs |

### Velocity and impulse rules per owner
For `AssemblyLinearVelocity`, `AssemblyAngularVelocity`, `ApplyImpulse`, `ApplyAngularImpulse` and `ApplyImpulseAtPosition` the docs give the same rule: on a server-owned part, call from a server Script; under automatic client ownership either side may call; a client call on a server-owned part does nothing.

**Nuance (rule of thumb, and a documented-vs-practice gap):** for a *player character* the owning client is simulating the assembly every frame. A server-side impulse has to travel to that client and be applied there, so it lands at least one round trip late, and fast local movement code (dash velocity, a custom controller writing velocity every frame) can overwrite it before it shows. The reliable pattern for knockback on players is: the server decides the knockback (direction, strength, who), then tells the victim's client, and the victim's client applies it. For server-owned NPCs the server applies it directly. See [[Combat Systems Architecture]].

### Ownership flips cause hitches
When ownership of an NPC flips between server and client (because players come and go nearby), the NPC can pause or snap for a moment. For NPCs whose movement is gameplay-critical, pin ownership to the server:

```lua
--!strict
local function pinToServer(model: Model)
	local root = model.PrimaryPart
	if root and not root.Anchored then
		local ok, why = root:CanSetNetworkOwnership()
		if ok then
			root:SetNetworkOwner(nil)
		else
			warn("Cannot set ownership on", model:GetFullName(), why)
		end
	end
end
```

**Measured.** The reference project's enemy system keeps every enemy server-owned and moves it with `AlignPosition` movers, so a hit, a knockback and a "caught" pull all run on the server's copy, never on a client that might be lagging or lying.

### Visualising ownership
Studio's viewport visualisation options include "Network owners": green means your client simulates the part, red is a buffer zone, white/grey means the server or another client owns it, black means no one owns it (Docs). Turn it on in a multi-client test before blaming lag ([[Multi-Client and Live Testing]]).

### Server Authority (newer netcode)
As of October 2026 the docs describe a **Server Authority** mode (`Workspace.AuthorityMode = Server`) in which clients only send inputs, the server is the single source of truth, and clients predict a few frames ahead with rollback on mismatch. It requires several other Workspace settings (next-generation replication, the input action system, deferred signals, fixed simulation, streaming) and simulation code bound with `RunService:BindToSimulation()`. It changes the ownership story above for predicted instances. Check the current docs for its status before building on it; [[Server Authority and Validation]] covers the general principle.

---

## 5. Rigid joints and mechanical constraints

### Rigid joints: which one?

| Joint | Use for | Notes |
|---|---|---|
| `WeldConstraint` | Gluing parts in Studio or code at their current offset | Simplest. Keeps whatever offset the parts had when enabled |
| `Weld` | Code that must set an exact offset (`C0`/`C1`) | The classic for attaching props at precise grips |
| `Motor6D` | Animated joints | The Animator drives its `Transform`; see [[Motor6D Math and CFrame Composition]] |
| `RigidConstraint` | Rigid link between two **attachments** | Can be set to break under force/torque; useful for breakable props |

To move a welded model, move it as a whole with `Model:PivotTo(cframe)` (or set the root's `CFrame`): the solver moves the rigid assembly together. Setting `Position` on child parts one by one of a welded group is a common cause of "my model tore apart" bugs.

### Mechanical constraints (one-line guide)

| Constraint | Typical gameplay use |
|---|---|
| `HingeConstraint` | Doors, wheels, turrets. `ActuatorType` Motor (spin) or Servo (go to angle) |
| `BallSocketConstraint` | Ragdoll joints, chains, hanging lamps. `LimitsEnabled` + `UpperAngle` + twist limits for ragdolls |
| `PrismaticConstraint` | Sliding doors, elevators, pistons |
| `CylindricalConstraint` | Slide plus rotate (suspension with steering) |
| `RopeConstraint` | Grapples, swinging bridges, leashes. `WinchEnabled` to reel |
| `RodConstraint` | Fixed distance with free rotation |
| `SpringConstraint` | Suspension, bouncy pads. Stiffness and damping |
| `UniversalConstraint` | Drive shafts, two-axis joints |
| `NoCollisionConstraint` | Stop exactly two parts colliding without touching collision groups |

**Rule of thumb.** Mechanical constraints are great for props and vehicles and poor for player-facing gameplay that must be identical for everyone (a puzzle door that depends on a rope swing will desync and be exploitable if a client owns it). Anything that gates progress should be either anchored and tweened on the server or server-owned.

### Breakable joints
`RigidConstraint` can be set to break when a force or torque threshold is exceeded (check its reference page for the current property names). Use it for destructible props, but remember the destruction happens on the owning machine. A client-owned crate that "breaks" is a client decision; if loot drops from it, the server must re-check (distance, cooldown, that the crate exists) before paying anything.

---

## 6. Collisions: CanCollide, CanTouch, CanQuery and collision groups

Three switches on every BasePart:

| Property | Controls | Gotcha |
|---|---|---|
| `CanCollide` | Physical contact and forces | Touch events still fire when false (Docs) |
| `CanTouch` | `Touched` / `TouchEnded` events | False = no touch events at all, saves cost on decor |
| `CanQuery` | Inclusion in raycasts and spatial queries | Only takes effect when `CanCollide` is false (Docs). A colliding part is always queryable |

Decor rule from the reference project: decor is anchored, `CanTouch = false`, tiny parts `CastShadow = false`. Invisible gameplay walls that should block movement but not raycasts are impossible with `CanQuery` alone (a colliding part is always queryable); filter them out of your casts instead (collision group on the cast, or exclude list). See [[Raycasts Shapecasts and Spatial Queries]].

### Collision groups
Collision groups are registered **per world** on `WorldRoot` (Workspace or a WorldModel) as of the current docs, and the limit is 32 groups per world ("This value is currently 32", Docs; read it with `GetMaxCollisionGroups()`):

```lua
--!strict
-- Server, at startup. Characters pass through each other but still hit the world.
local Players = game:GetService("Players")

local GROUP = "Characters"
if not workspace:IsCollisionGroupRegistered(GROUP) then
	workspace:RegisterCollisionGroup(GROUP)
end
workspace:CollisionGroupSetCollidable(GROUP, GROUP, false)

local function tag(inst: Instance)
	if inst:IsA("BasePart") then
		inst.CollisionGroup = GROUP
	end
end

local function onCharacter(character: Model)
	for _, d in character:GetDescendants() do
		tag(d)
	end
	character.DescendantAdded:Connect(tag) -- accessories and tools arrive later
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end)
```

Older code calls the same methods on `PhysicsService` (`PhysicsService:RegisterCollisionGroup`). Since September 2026 they live on `WorldRoot` (per world) and the `PhysicsService` versions are deprecated but still forward to Workspace; use `workspace:` in new code.

Typical group plan for an action game (rule of thumb):

| Group | Collides with |
|---|---|
| `Default` (world) | everything |
| `Characters` | Default, Enemies; not Characters |
| `Enemies` | Default, Characters; often not Enemies (prevents pile-ups) |
| `Debris` | Default only; never characters |
| `Projectiles` | Default only; hits are found by casts, not contact |
| `PlayerOnlyWalls` | Characters only; enemies walk through them |

Two warnings:
- `UnregisterCollisionGroup` leaves parts with the old group name and "their physical behavior is undefined" (Docs). Never unregister at runtime.
- A raycast uses the `Default` group unless `RaycastParams.CollisionGroup` says otherwise, so a group that does not collide with Default can still be hit by casts that use a different group. Set the cast's group deliberately.

### Collision fidelity
Mesh collision ranges from `Box` (cheapest) through `Hull`, `Default` to `PreciseConvexDecomposition` (most precise, "still not a 1:1 representation of the visual", Docs). CollisionFidelity cannot be changed on a MeshPart that is already loaded at runtime; it must be set in Studio or by creating the part with `AssetService:CreateMeshPartAsync` (measured in the reference project). Geometry and fidelity choices are in [[Collision and Physics Geometry]].

---

## 7. Touched: what it is and is not

`Touched` fires only from physical simulation. It does not fire when code sets `CFrame` or `Position` so two parts intersect (Docs). It can fire many times in quick succession, so debounce. It also fires on the machine that owns the part, and the docs warn that a client can fire `Touched` for parts it owns even when the server sees no contact.

For gameplay this means:
- **Do not use `Touched` for melee hit detection.** It is late, noisy, depends on frame rate and ownership, and misses fast swings entirely. Use queries at a known time ([[Hitboxes and Hit Detection]]).
- **`Touched` is fine for slow triggers** (lava floor, checkpoint pad, coin pickup), with a server-side re-check: is the character actually near, alive, and not on cooldown?
- **Zone triggers are better as queries.** A once-per-0.25 s `GetPartBoundsInBox` around each zone, or a position-in-box test against the root, is cheaper and far more predictable than thousands of touch events. The reference project's zone gate guard judges zones by the player's X coordinate alone, the cheapest possible test, because its zones are strips along X ([[Spawning Teams and Rounds]]).

---

## 8. Stepping, sleeping and performance

- The solver runs internally at a high fixed rate and can step different assemblies at different rates when adaptive stepping is on (`Workspace.PhysicsSteppingMethod`). Exact rates are a performance topic: [[Physics Performance]].
- Assemblies at rest go to sleep and wake on contact or force. Contacts between sleeping parts produce no collision summaries (Docs). A prop that "never moves when hit by a spell" may be asleep and receiving a property write, not a force; use an impulse.
- Cost scales with *awake* assemblies and contact pairs, not with part count. Thousands of anchored decor parts are cheap for physics (they still cost rendering and memory). A hundred loose debris pieces bouncing on each other is expensive.
- **Edit mode has no physics.** Tests that move NPCs with movers in Edit see nothing happen. The reference project's dry-run harnesses simulated a "kinematic mover": move the root to its `AlignPosition` goal at `MaxVelocity` per step. That made thousands of navigation cases testable offline. See [[Testing Strategies and Frameworks]].

---

## 9. Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Anchoring two parts of a welded prop | Prop splits, half floats | Anchor only the root |
| Large welded prop on a character | Character tips, walks oddly, `AssemblyRootPart` is the prop | `Massless = true` on the prop or raise `RootPriority` on the root |
| Setting `Position` on welded children | Model tears apart or snaps back | `PivotTo` the model |
| Server impulse on a player | Knockback late or missing | Server decides, owning client applies |
| `Touched` for sword hits | Missed hits, double hits, client-faked hits | Spatial query at the swing's hit time |
| Debris collides with players | Players launched by tiny bits | `Debris` collision group |
| Unregistering a group at runtime | Undefined collisions | Register at startup only |
| Ownership flip on NPCs | NPCs freeze briefly as players approach | `SetNetworkOwner(nil)` |
| Writing `AssemblyLinearVelocity` every frame on a Humanoid | Jitter, fights with the Humanoid | Use a mover or the controller ([[Mover Constraints and Physics Controllers]]) |

## Checklist
- [ ] Every moving gameplay object has a known owner, and the owner is the server when the outcome matters.
- [ ] Props welded to characters are Massless.
- [ ] Collision groups registered once at startup, under 32 per world, with a written group matrix.
- [ ] No melee or damage relies on `Touched`.
- [ ] Knockback for players runs on the owning client from a server decision.
- [ ] Network owner visualisation checked in a 2+ client test.

## See also
[[Mover Constraints and Physics Controllers]] · [[Characters and Humanoids]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Hitboxes and Hit Detection]] · [[Network Ownership]] · [[Physics Performance]] · [[Collision and Physics Geometry]] · [[Ragdolls and Physics-Based Animation]] · [[AnimationConstraint and Physically Simulated Characters]]

## Connected notes
<!-- auto-links:start -->
[[Debugging Physics and Network Ownership]] · Cars with Constraints - Suspension Steering and Drive · Ropes Chains and Soft Bodies · Official Docs - Physics · Rigs and Joints
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Cars with Constraints - Suspension Steering and Drive]] · [[Grabs, Carries and Throws - Moving Players Safely]] · [[BasePart - Engine Reference Card]] · [[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]] · [[Custom Character Controllers]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Pathfinding]]
<!-- related:end -->
