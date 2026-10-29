---
tags: [physics, vehicles, damage, health, repair, wreck, respawn, state-machine, type/guide, area/physics, area/gameplay, level/intermediate, api/ProximityPrompt, api/WeldConstraint]
---
# Vehicle Damage, Repair and Wreck States

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Damage from client Touched -> Server delta-v sampling
> - Avoid: No immunity after server teleports -> `DamageImmuneUntil` attribute
> - Avoid: Unlimited detached parts -> Per-car and global debris caps
> - Health, State and zones are server-written attributes; clients render effects from them.
> - Collision damage from server-side velocity deltas, with immunity after server moves.
> - Panel detachment capped and cleaned up.
>
> Cost: TL;DR ~150 tok · whole note ~2.4k tok. Read more: ## 2. Collision damage without trusting the driver · ## 5. Wrecked: hand back physics and clear the seats · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Car health looks like player health with a different icon, but three things make it harder: the car is usually simulated by a client, collision damage has no "attacker" to validate, and a wreck has to hand physics back to the server while people are still sitting in it. This note gives a server-owned health model with explicit states, collision damage estimated on the server from replicated velocity, cosmetic part detachment, repair stations, and wreck/respawn timers that do not leak instances. For mesh fracture and debris physics see [[Destruction and Fracture]].

Source labels: **Roblox docs** (create.roblox.com, checked October 2026), **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. States, not just a number

| State | Entered when | Effects |
|---|---|---|
| `Healthy` | Health > 60% | None |
| `Damaged` | 25% < Health <= 60% | Smoke emitter, small engine power cut |
| `Critical` | 0 < Health <= 25% | Fire, power cut to ~50%, steering wobble |
| `Wrecked` | Health = 0 | Occupants ejected, seats disabled, server owns physics, wreck timer |
| `Despawned` | Wreck timer done or owner left | Model destroyed, garage slot freed |

Store `Health`, `MaxHealth` and `State` as attributes on the car model, written only by the server. Clients render smoke and fire from `State` via `GetAttributeChangedSignal`, so effects are free for the server and consistent for everyone. The driver's local engine model ([[Engine, Gearbox and Torque Curve Model for Arcade Cars]]) multiplies torque by a factor derived from `State`; the server's speed check uses the same factor so a hacked client cannot ignore the power cut for long.

## 2. Collision damage without trusting the driver

Touched events on a client-owned assembly are not a reliable damage source: the hits are resolved on the driver's machine and an exploiter can simply not collide. Rule of thumb: estimate impacts on the server from the replicated chassis velocity.

```lua
--!strict
-- Server. One loop for all live cars, sampled at ~10 Hz.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local SAMPLE = 0.1
local MIN_DELTA_V = 25        -- studs/s lost in one sample before it counts as a crash
local DAMAGE_PER_DV2 = 0.02    -- tune per car class

local lastVel: { [Model]: Vector3 } = {}
local acc = 0

local function applyDamage(car: Model, amount: number)
	local hp = (car:GetAttribute("Health") :: number?) or 0
	if hp <= 0 then return end
	car:SetAttribute("Health", math.max(0, hp - amount))
end

RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < SAMPLE then return end
	acc = 0
	for _, inst in CollectionService:GetTagged("Vehicle") do
		local car = inst :: Model
		local root = car.PrimaryPart
		if not root then continue end
		local v = root.AssemblyLinearVelocity
		local prev = lastVel[car]
		lastVel[car] = v
		if prev then
			local dv = (prev - v).Magnitude
			if dv > MIN_DELTA_V then
				applyDamage(car, (dv - MIN_DELTA_V) ^ 2 * DAMAGE_PER_DV2)
			end
		end
	end
end)

CollectionService:GetInstanceRemovedSignal("Vehicle"):Connect(function(inst)
	lastVel[inst :: Model] = nil
end)
```

Notes:
- Squared delta-v keeps fender benders cheap and head-ons lethal.
- A respawn, flip or server pivot also produces a velocity jump. Set a `DamageImmuneUntil` attribute (server time) whenever the server moves a car and skip damage before it.
- An exploiter can still smooth their own replicated velocity to avoid crash damage. That only matters in combat-car games; there, make weapon damage (server raycasts, explosions) the main source and collision damage secondary.
- Weapon and explosion damage goes through the same `applyDamage`, after your normal hit validation ([[Detecting Combat Exploits - Reach Rate and Aim]]).

Direction: transform the impact into the chassis frame (`root.CFrame:VectorToObjectSpace(prev - v)`) and keep four zone attributes (front, rear, left, right). Zones drive which panels fall off.

## 3. Detaching panels

Panels are massless visuals welded to the chassis ([[Cars with Constraints - Suspension Steering and Drive]]). When a zone crosses a threshold, the server:

1. Picks a panel tagged for that zone.
2. Destroys its `WeldConstraint` (or sets `Enabled = false`), sets `Massless = false`, `CanCollide = true`, puts it in a `Debris` collision group that does not collide with players.
3. Parents it to a debris folder and schedules removal with `Debris:AddItem(part, 10)` or a `task.delay` destroy (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/Debris).

Detached parts become separate server-owned assemblies, so cap them: at most two or three loose parts per car and a global debris cap with oldest-first removal. Rule of thumb. Changing panels never changes the car's CoM much because panels were massless; do not add mass to them while still welded.

## 4. Repair stations

- A `ProximityPrompt` on the station (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt). `Triggered` fires on the server with the player, so the server knows who pressed it.
- Validate: the player is the car's owner (or driver), the car's root is within the station's radius, the car is nearly stopped, state is not `Wrecked`, the player can pay.
- Charge, then restore `Health`, zones and panels. Replace detached panels by cloning from the car's template in `ServerStorage` and re-welding at the stored offset (store each panel's `CFrame` relative to the chassis when the car spawns).
- Optional repair-over-time: increase health in steps while the player stays in range; cancel if they drive off. Players read "progress" better than an instant refill.

## 5. Wrecked: hand back physics and clear the seats

```lua
--!strict
local function wreck(car: Model)
	car:SetAttribute("State", "Wrecked")
	for _, d in car:GetDescendants() do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			local hum = d.Occupant
			if hum then hum.Sit = false end
			d.Disabled = true
		end
	end
	local root = car.PrimaryPart
	if root then root:SetNetworkOwner(nil) end
	task.delay(20, function()
		if car.Parent then car:Destroy() end
	end)
end
```

- Ejecting before disabling avoids characters stuck welded to a disabled seat. After `Sit = false`, move each character to a clear exit point ([[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]]).
- `Seat.Disabled` stops anyone sitting again (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/Seat).
- Server ownership stops the former driver from dragging the wreck around.
- Free the owner's garage slot when the wreck is destroyed, not when it wrecks, so they cannot spawn a second car while the first still blocks the road. Pair it with the spawner's respawn cooldown ([[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]]).

Persist only what matters: a damaged car usually respawns at full health. If your game has "insurance" or repair costs, save a `WreckedAt` timestamp, not the health number.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Damage from client Touched | Hackers never take crash damage | Server delta-v sampling |
| No immunity after server teleports | Respawned cars spawn damaged | `DamageImmuneUntil` attribute |
| Unlimited detached parts | Physics cost climbs in crash-heavy servers | Per-car and global debris caps |
| Disabling seats before ejecting | Players stuck sitting in wrecks | Eject, then disable |
| Wreck still client-owned | Former driver drags the wreck | `SetNetworkOwner(nil)` on wreck |
| Slot freed on wreck | Players spawn duplicates | Free slot when the model is destroyed |

## Checklist

- [ ] Health, State and zones are server-written attributes; clients render effects from them.
- [ ] Collision damage from server-side velocity deltas, with immunity after server moves.
- [ ] Panel detachment capped and cleaned up.
- [ ] Repair prompt validates owner, distance, speed and payment on the server.
- [ ] Wreck ejects, disables seats, takes ownership and starts a timer.
- [ ] Engine power and server speed check both read State.

## See also

[[Destruction and Fracture]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Network Ownership]] · [[ProximityPrompt]] · [[CollectionService Patterns]] · [[Particle Emitters In Depth]] · [[Physics Performance]]

## Connected notes
<!-- auto-links:start -->
[[Centre of Mass, Anti-Flip and Self-Righting]] · [[Spawn Points Safe Zones and Respawn Flow]] · Instances Attributes and Tags
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] · [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]] · [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]] · [[Boats Buoyancy and Water]] · [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] · [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]]
<!-- related:end -->
