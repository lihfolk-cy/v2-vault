---
tags: [physics, vehicles, moving-platforms, characters, elevators, trains, network-ownership, type/guide, area/physics, area/networking, level/intermediate, api/PrismaticConstraint, api/AlignPosition, api/AssemblyLinearVelocity]
---
# Standing on Moving Vehicles and Platforms - Keeping Players Glued

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Tweening an anchored platform players stand on -> Constraint-driven unanchored platform, or relative carry
> - Avoid: Elevator on automatic ownership -> `SetNetworkOwner(nil)`
> - Avoid: Fast descent -> Cap speed and ramp; keep acceleration well below gravity
> - Each platform classified by speed and built with the matching mover.
> - No anchored CFrame-animated surfaces under walking players (or relative carry is in place).
> - Platforms server-owned; servo force sized for a full load.
>
> Cost: TL;DR ~160 tok · whole note ~2.7k tok. Read more: ## 1. Why characters fall off · ## 3. A physically driven elevator · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Players walking on a moving train, an elevator, a ferry deck or a lift platform slide off, jitter, get left behind or are launched into the air. The cause is always one of three things: the platform has no physical velocity for the character to inherit, the platform and the character are simulated by different machines, or the platform accelerates faster than the character can follow. [[Boats Buoyancy and Water]] section 5 has the client-side "carry the character with the deck" code for ships. This note is the wider decision: which kind of mover to build so characters stay on it, and which fix applies to which platform.

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

## 1. Why characters fall off

A character is a physics assembly simulated by its own player's client (Roblox docs, network ownership: https://create.roblox.com/docs/physics/network-ownership). Its `Humanoid` moves it with internal forces and friction against whatever it stands on.

| Platform type | What the character feels | Result |
|---|---|---|
| **Anchored, moved by `CFrame`/`PivotTo`/`TweenService`** | A surface that teleports a little each frame with zero physical velocity | Character stays where it was; the floor slides away underneath. Upward moves push it; downward moves drop it |
| **Unanchored, moved by constraints or forces, server-owned** | A real moving surface, but replicated to the client late and interpolated | Rides along, with small jitter that grows with speed and ping |
| **Unanchored, owned by another player's client** (a captain, a driver) | A surface arriving through two replication hops | Noticeable jitter and sliding at speed |
| **Same machine owns both** (the player's own vehicle they stand in) | Consistent | Works, but ownership of a vehicle full of passengers can only be one player |

So the first fix is almost always: **never animate a platform players stand on by setting CFrame on an anchored part**. Drive it physically.

## 2. Pick the mover by speed

| Platform | Recommended build (Rule of thumb) |
|---|---|
| Elevator, lift, slow moving block in an obby | Unanchored platform on a `PrismaticConstraint` in servo mode, or `AlignPosition`, server-owned |
| Slow train or tram you can walk around in (under about 30 studs/s) | Unanchored carriages on constraints or `LinearVelocity`, server-owned; accept small jitter |
| Ship or airship with a walkable deck | Physical hull plus client-side relative carry ([[Boats Buoyancy and Water]]) |
| Fast train, roller coaster, cable car, bus | Seats. Players sit while moving; walking is allowed only when stopped |
| Cutscene or on-rails ride | Seat players or anchor their root and move them with the ride; no walking |

The breakpoint between "walk on it" and "sit in it" is around the speed where jitter becomes visible on a 150 ms connection. Test with a throttled network, not in Studio play solo.

## 3. A physically driven elevator

```lua
--!strict
-- Server: an elevator car on a PrismaticConstraint servo. The car part is unanchored;
-- the base part is anchored. Attachment axes point up along the shaft.
local Elevator = {}

export type Elevator = {
	car: BasePart,
	slider: PrismaticConstraint,
	floors: { number }, -- slider positions in studs from the base attachment
}

function Elevator.new(car: BasePart, slider: PrismaticConstraint, floors: { number }): Elevator
	slider.ActuatorType = Enum.ActuatorType.Servo
	slider.Speed = 12 -- studs/s; keep downward speed gentle
	slider.ServoMaxForce = car.AssemblyMass * workspace.Gravity * 3 -- lifts car plus riders
	slider.LimitsEnabled = true
	slider.LowerLimit = floors[1]
	slider.UpperLimit = floors[#floors]
	car:SetNetworkOwner(nil) -- server owns, so no client can shove it
	return { car = car, slider = slider, floors = floors }
end

function Elevator.goTo(e: Elevator, index: number)
	local target = e.floors[index]
	if target then
		e.slider.TargetPosition = target
	end
end

return Elevator
```

Why these settings (Rule of thumb):

- **Servo with a speed cap** gives constant velocity between floors, which characters ride smoothly. Instant position changes do not.
- **`ServoMaxForce` scaled to mass times gravity** with headroom for a full car of players. Too low and a crowd stalls the lift.
- **Server ownership.** If ownership were automatic, the nearest client might own the elevator and every other rider would see it through an extra hop. `SetNetworkOwner` needs the part unanchored and in the workspace.
- **Gentle descent.** If the floor drops faster than the character falls, the character floats and lands with a bump. Keep downward acceleration far below `workspace.Gravity`; ramp speed rather than starting at full.
- **Walls and a ceiling** on fast lifts stop characters being pushed off sideways by replication corrections.

For a horizontal platform, the same approach works with a prismatic on a horizontal axis, or `AlignPosition` with `MaxVelocity` set, or `LinearVelocity` for constant-speed conveyors ([[Mover Constraints and Physics Controllers]]).

## 4. When you must move something kinematically

Sometimes a platform has to follow an exact path (a curve, an animation) and physics is overkill. Options:

1. **Give the anchored part a matching velocity.** An anchored part with a non-zero `AssemblyLinearVelocity` acts as a moving surface for things touching it (the classic conveyor-belt behaviour). If you move an anchored platform by CFrame each frame and also set its `AssemblyLinearVelocity` to the motion per second, characters standing on it are dragged along by friction. **Rule of thumb:** works for slow, mostly linear motion; rotation and fast changes still slip, and the CFrame updates replicate separately from the velocity, so clients can see a mismatch.
2. **Client-side relative carry.** Each client detects that its own character stands on a tagged platform and applies the platform's frame-to-frame CFrame delta to its root in `PreSimulation`. This is the Boats note's technique and works for any mover, including anchored ones, because it does not rely on physics at all.
3. **Seats.** Nothing slides if nobody stands.

## 5. Welding players to platforms: usually wrong

Welding a character's root to a platform with a `WeldConstraint` makes the character part of the platform assembly. One assembly has one network owner, so either the player loses control of their own character or the platform is owned by a client. It also breaks humanoid movement. Seats are a weld the engine manages properly, with sitting animation, `Occupant` tracking and clean exit. Use a weld only for cutscenes where the player should have no control, and remove it on a server-decided end.

## 6. Anti-cheat and platforms

Movement validators see a rider on a 60 studs/s train as a speed hacker. Measure character speed **relative to the floor**: raycast down from the root, and if the hit belongs to a moving platform, subtract that part's `AssemblyLinearVelocity` (or the platform's known speed, for kinematic movers) before comparing against walk speed ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]). Apply the same rule to cars on ferries ([[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]]).

```lua
--!strict
-- Server helper: character speed relative to what it stands on.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function relativeSpeed(character: Model, root: BasePart): number
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
	local floorVel = Vector3.zero
	if hit and hit.Instance:HasTag("MovingPlatform") then
		floorVel = hit.Instance.AssemblyLinearVelocity
	end
	local rel = root.AssemblyLinearVelocity - floorVel
	return Vector3.new(rel.X, 0, rel.Z).Magnitude
end

return relativeSpeed
```

## 7. 2026 notes

- The June 2026 physics replication rewrite (DevForum: https://devforum.roblox.com/t/upcoming-improvements-to-physics-replication/4675512) had **reported** bug threads about relative physics desync, which is exactly the platform case. If riders started jittering after mid-June 2026, test with `Workspace.ImprovedPhysicsReplication = Disabled` before rewriting your platform code, and report it ([[Server Authority and Input Migration 2026]]).
- **Unverified:** whether Server Authority's prediction removes platform jitter for riders. It predicts whole assemblies, so a server-owned platform the character is not part of may still be seen late. Test before relying on it.

## Common mistakes

| Mistake | Fix |
|---|---|
| Tweening an anchored platform players stand on | Constraint-driven unanchored platform, or relative carry |
| Elevator on automatic ownership | `SetNetworkOwner(nil)` |
| Fast descent | Cap speed and ramp; keep acceleration well below gravity |
| Welding players to a train | Seats |
| Walkable deck on a 100 studs/s vehicle | Seat while moving, walk when stopped |
| Validator flags riders | Speed relative to the floor |

## Checklist

- [ ] Each platform classified by speed and built with the matching mover.
- [ ] No anchored CFrame-animated surfaces under walking players (or relative carry is in place).
- [ ] Platforms server-owned; servo force sized for a full load.
- [ ] Downward motion gentle; fast vehicles use seats.
- [ ] Anti-cheat measures speed relative to the floor.
- [ ] Tested with two clients on a throttled connection.

## See also

[[Boats Buoyancy and Water]] · [[Mover Constraints and Physics Controllers]] · [[Physics Assemblies and Constraints]] · [[Network Ownership]] · [[Characters and Humanoids]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] · [[Debugging Physics and Network Ownership]] · [[Obby and Platforming Level Design]]

## Connected notes
<!-- auto-links:start -->
[[Cars with Constraints - Suspension Steering and Drive]] · [[Custom Character Controllers]] · [[Physics and Vehicles Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars]] · [[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Centre of Mass, Anti-Flip and Self-Righting]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] · [[Aircraft and Flight Models]] · [[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]] · [[Vehicle Damage, Repair and Wreck States]]
<!-- related:end -->
