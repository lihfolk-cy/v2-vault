---
tags: [physics, vehicles, seats, passengers, turrets, network-ownership, input, type/guide, area/physics, area/networking, level/intermediate, api/VehicleSeat, api/Seat, api/UnreliableRemoteEvent]
---
# Multi-Seat Vehicles - Driver, Passenger and Gunner Roles

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Two VehicleSeats -> One VehicleSeat, all others Seat
> - Avoid: Ownership by auto-assignment -> Explicit ownership to driver, server when empty
> - Avoid: Server drives the turret servo -> Client-side visual aim, server-side hits
> - One VehicleSeat; seats carry `Role`, `ExitAttachment`, optional `Locked`.
> - Ownership changes only on driver-seat occupancy.
> - Entry via prompt with server validation.
>
> Cost: TL;DR ~140 tok · whole note ~2.4k tok. Read more: ## 2. Ownership stays with the driver · ## 4. Input routing on the client · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A four-seat jeep with a roof gun is three different programs sharing one assembly: the driver simulates the physics, the gunner aims something welded to a body they do not own, and passengers only need a camera and a safe way out. Most multi-seat bugs come from forgetting which machine owns what: the passenger who becomes network owner and makes the car stutter for the driver, the turret that lags twice the ping, the exit that drops players under the chassis. This note sets roles per seat, routes input by role, keeps ownership with the driver, and handles entry, seat-switching and exit on the server.

Source labels: **Roblox docs** (create.roblox.com, checked October 2026), **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. Roles live on the seat

Give every seat a `Role` attribute: `Driver`, `Gunner`, `Passenger`. Exactly one `VehicleSeat` (the driver); everything else is a plain `Seat`. A `VehicleSeat` exposes `ThrottleFloat`/`SteerFloat` from its occupant's input (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/VehicleSeat); a second VehicleSeat on the same car means two players fighting over the same motors.

Also give seats an `ExitAttachment` child (an `Attachment` outside the car on that seat's side) and optionally `Locked` (bool) for owner-only seats.

## 2. Ownership stays with the driver

The pattern from [[Cars with Constraints - Suspension Steering and Drive]] applies, with one addition: **only the driver seat changes ownership**. Passenger seats never call `SetNetworkOwner`.

```lua
--!strict
-- Server, per car.
local function bindOwnership(car: Model, driverSeat: VehicleSeat)
	local root = car.PrimaryPart :: BasePart
	driverSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = driverSeat.Occupant
		local player = hum and game:GetService("Players"):GetPlayerFromCharacter(hum.Parent)
		if player then
			root:SetNetworkOwner(player)
		else
			driverSeat.ThrottleFloat = 0 -- stop residual input
			driverSeat.SteerFloat = 0
			root:SetNetworkOwner(nil)
		end
	end)
	root:SetNetworkOwner(nil)
end
```

Why passengers never own it: seated characters are welded into the car's assembly, and automatic ownership may pick whichever player's character Roblox considers nearest. Setting ownership explicitly turns auto-assignment off for that assembly (Roblox docs: https://create.roblox.com/docs/physics/network-ownership), which is what you want. When the driver leaves with passengers aboard, the server owns it; do not promote a passenger to owner unless they move to the driver seat.

## 3. Entry: prompts beat touch

Touch-to-sit lets anyone hijack a seat by walking into it, and lets players fall into a driver seat while trying to board the back. Rule of thumb: use a `ProximityPrompt` per seat or one "Enter" prompt per car that picks the best free seat, and seat the character from the server with `Seat:Sit(humanoid)` (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/Seat).

To stop touch-seating, set `CanTouch = false` on seat parts. Whether `Seat:Sit` still works on a seat with `Disabled = true` is **Unverified**; test it in your build before relying on `Disabled` for this, and prefer `CanTouch = false`.

Server checks on entry: seat free, `Locked` respected (owner, party or team), character alive and within ~12 studs of the seat, car not `Wrecked` ([[Vehicle Damage, Repair and Wreck States]]).

Hijack defence if you keep touch seating: watch `Occupant` on locked seats and, if the occupant is not allowed, `task.defer` then `hum.Sit = false` and move them out. Deferring avoids fighting the seat weld creation in the same frame. Rule of thumb.

## 4. Input routing on the client

One LocalScript in `StarterPlayerScripts` watches the local Humanoid's `SeatPart` and binds actions by role:

```lua
--!strict
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local function onSeat(seat: BasePart?)
	ContextActionService:UnbindAction("VehicleFire")
	ContextActionService:UnbindAction("VehicleSwitch")
	if not seat then return end
	local role = seat:GetAttribute("Role")
	if role == "Gunner" then
		ContextActionService:BindAction("VehicleFire", function(_, state)
			if state == Enum.UserInputState.Begin then
				-- send fire request; server raycasts from the turret muzzle
			end
			return Enum.ContextActionResult.Sink
		end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	end
	ContextActionService:BindAction("VehicleSwitch", function(_, state)
		if state == Enum.UserInputState.Begin then
			-- ask server to move to next free seat
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
end

local function onCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
		onSeat(hum.SeatPart)
	end)
end
Players.LocalPlayer.CharacterAdded:Connect(onCharacter)
if Players.LocalPlayer.Character then onCharacter(Players.LocalPlayer.Character) end
```

Driving input needs no binding: the VehicleSeat reads it. If you migrate to the Input Action System, map the same actions there; see [[Server Authority and Input Migration 2026]] for the 2025-26 input changes.

## 5. Gunner turrets: aim is cosmetic, hits are server

A turret welded or hinged to the car is simulated by the **driver**, so a servo `TargetAngle` written by the server travels server -> driver -> everyone, two hops. Rule of thumb that works:

- The gunner's client rotates the turret **visual** locally every frame (no physics, a `Motor6D` or a CFrame on a massless, non-colliding part).
- The gunner sends its aim direction to the server at 10 to 20 Hz on an `UnreliableRemoteEvent` (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent). The server stores it, clamps it to the turret's arc, and writes it to a replicated attribute that other clients use to rotate their copy of the turret visual with smoothing ([[Springs Damping and Smoothing]]).
- Firing: the server raycasts from the turret's muzzle position on the server using its stored, clamped aim, with fire rate checks. Never accept a client-supplied hit point without validation ([[Detecting Combat Exploits - Reach Rate and Aim]]).

## 6. Switching and exiting safely

- **Switch**: server checks the target seat is free, sets `hum.Sit = false`, then `targetSeat:Sit(hum)` on the next frame (`task.defer`). Moving to the driver seat triggers the ownership handoff in section 2.
- **Exit**: on `Occupant` becoming nil, the server moves the character to the seat's `ExitAttachment` world position, after a `workspace:Blockcast` or `GetPartBoundsInBox` check that the spot is clear and a downward raycast that finds ground. If blocked, try the other side, then the roof. Rule of thumb.
- **Moving vehicles**: only allow exit below a speed threshold, or give exiting players the car's velocity so they do not get run over by the car they just left.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Two VehicleSeats | Car jerks between two players' inputs | One VehicleSeat, all others Seat |
| Ownership by auto-assignment | Car stutters when a passenger boards | Explicit ownership to driver, server when empty |
| Server drives the turret servo | Aim lags two pings | Client-side visual aim, server-side hits |
| Touch seating on locked seats | Hijacked cars | Prompts plus server `Seat:Sit` |
| Exit at seat position | Players under or inside the chassis | Exit attachment with clearance check |
| Inputs bound but never unbound | Gun fires on foot | Rebind on every `SeatPart` change |

## Checklist

- [ ] One VehicleSeat; seats carry `Role`, `ExitAttachment`, optional `Locked`.
- [ ] Ownership changes only on driver-seat occupancy.
- [ ] Entry via prompt with server validation.
- [ ] Client binds actions by role on `SeatPart` change.
- [ ] Turret aim local + unreliable updates; fire validated on server.
- [ ] Exit points cleared with spatial queries; tested at speed with 4 players.

## See also

[[Cars with Constraints - Suspension Steering and Drive]] · [[Network Ownership]] · [[Input - UserInputService and ContextActionService]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[ProximityPrompt]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Boats Buoyancy and Water]]

## Connected notes
<!-- auto-links:start -->
[[Vehicle Damage, Repair and Wreck States]] · [[Debugging Physics and Network Ownership]] · [[Aircraft and Flight Models]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]] · [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] · [[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] · [[Centre of Mass, Anti-Flip and Self-Righting]] · [[Engine, Gearbox and Torque Curve Model for Arcade Cars]]
<!-- related:end -->
