---
tags: [physics, vehicles, spawning, garage, datastore, cleanup, type/guide, area/physics, area/gameplay, level/intermediate, api/OverlapParams, api/SetNetworkOwner, api/PivotTo]
---
# Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Templates in ReplicatedStorage -> ServerStorage, clone on spawn
> - Avoid: Client sends spawn position -> Server picks a clear pad
> - Avoid: Spawning inside the ground or another car -> Bounding box offset and overlap check
> - Remote takes a short string id; rate-limited; validated against the profile.
> - One active car per player and a server-wide cap.
> - Clear-pad check with `GetPartBoundsInBox`; spawn offset above the pad.
>
> Cost: TL;DR ~150 tok · whole note ~2.7k tok. Read more: ## 1. The flow · ## 2. The spawner · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Every driving game needs the same unglamorous server flow: a player picks a car, the server checks they own it, finds a clear spot, clones the car, hands it to them, and later cleans it up. Get it wrong and you get the classic bugs: forty abandoned cars lagging the server, cars spawning inside each other and exploding, players spawning cars they never bought, and garages that duplicate on rejoin. This note is that flow, with the garage saved as data rather than instances.

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

## 1. The flow

```
Client: "spawn carId" (RemoteEvent)
  -> Server: rate limit, validate carId against the player's saved garage
  -> despawn the player's existing car (cap = 1)
  -> pick a spawn pad, check it is clear (GetPartBoundsInBox)
  -> clone template from ServerStorage, apply saved cosmetics
  -> tag OwnerUserId, PivotTo the pad, parent to workspace.Vehicles
  -> server-owned while empty; driver ownership on sit
  -> track for despawn: player leaves, car abandoned, car wrecked
```

Key rules (Rule of thumb unless marked):

- **Templates live in `ServerStorage`.** Anything in `ReplicatedStorage` is downloaded by every client at join and never streams (Roblox docs, [[Instance Streaming]]). Twenty detailed car models there is real join time and memory, and exploiters can read them.
- **The client sends an id, never an instance or a CFrame.** The server chooses where it spawns.
- **Validate against data the server loaded**, not a client claim. The garage is in the player's profile ([[Session Locking and Profile Libraries]]).
- **One active car per player** unless the design needs more; enforce it on the server.

## 2. The spawner

```lua
--!strict
-- ServerScriptService/VehicleSpawner
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TEMPLATES = ServerStorage:WaitForChild("VehicleTemplates") :: Folder
local PADS = workspace:WaitForChild("VehiclePads") :: Folder -- parts marking spawn spots
local LIVE = workspace:WaitForChild("Vehicles") :: Folder
local SpawnRemote = ReplicatedStorage:WaitForChild("SpawnVehicle") :: RemoteEvent

local COOLDOWN = 3 -- seconds between spawns per player
local ABANDON_AFTER = 120 -- seconds empty and far from owner

local active: { [Player]: Model } = {}
local lastSpawn: { [Player]: number } = {}

-- Replace with your profile lookup.
local function ownsVehicle(player: Player, carId: string): boolean
	local owned = player:GetAttribute("OwnedVehicles") -- e.g. "sedan,truck"; real games read the profile table
	return typeof(owned) == "string" and table.find(string.split(owned, ","), carId) ~= nil
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function padIsClear(pad: BasePart, size: Vector3): boolean
	overlap.FilterDescendantsInstances = { LIVE, workspace:FindFirstChild("Characters") or LIVE }
	local hits = workspace:GetPartBoundsInBox(pad.CFrame + Vector3.new(0, size.Y / 2, 0), size, overlap)
	return #hits == 0
end

local function despawn(player: Player)
	local car = active[player]
	active[player] = nil
	if car then
		for _, d in car:GetDescendants() do
			if d:IsA("Seat") or d:IsA("VehicleSeat") then
				local hum = d.Occupant
				if hum then hum.Sit = false end -- eject before destroy
			end
		end
		car:Destroy()
	end
end

local function spawnFor(player: Player, carId: string)
	local now = os.clock()
	if now - (lastSpawn[player] or -math.huge) < COOLDOWN then return end
	lastSpawn[player] = now
	if typeof(carId) ~= "string" or #carId > 32 then return end
	local template = TEMPLATES:FindFirstChild(carId)
	if not (template and template:IsA("Model")) or not ownsVehicle(player, carId) then return end

	local _, size = template:GetBoundingBox()
	local pad: BasePart? = nil
	for _, p in PADS:GetChildren() do
		if p:IsA("BasePart") and padIsClear(p, size) then pad = p; break end
	end
	if pad == nil then return end -- tell the client "all pads busy" via your UI channel

	despawn(player)
	local car = template:Clone()
	car:SetAttribute("OwnerUserId", player.UserId)
	car:SetAttribute("EmptySince", time())
	car:PivotTo(pad.CFrame + Vector3.new(0, size.Y / 2 + 0.5, 0))
	car.Parent = LIVE
	local root = car.PrimaryPart
	if root and not root.Anchored then
		root:SetNetworkOwner(nil) -- server-owned while empty
	end
	active[player] = car
end

SpawnRemote.OnServerEvent:Connect(function(player, carId)
	spawnFor(player, carId)
end)

Players.PlayerRemoving:Connect(function(player)
	despawn(player)
	lastSpawn[player] = nil
end)

-- Abandonment sweep: cheap, every few seconds.
task.spawn(function()
	while true do
		task.wait(5)
		for player, car in active do
			if car.Parent == nil then active[player] = nil; continue end
			local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
			if seat and seat.Occupant then
				car:SetAttribute("EmptySince", time())
				continue
			end
			local char = player.Character
			local far = true
			if char and car.PrimaryPart then
				local pivot = char:GetPivot().Position
				far = (pivot - car.PrimaryPart.Position).Magnitude > 300
			end
			local since = car:GetAttribute("EmptySince")
			if far and typeof(since) == "number" and time() - since > ABANDON_AFTER then
				despawn(player)
			end
		end
	end
end)
```

Details that bite:

- **Spawn above, not in, the pad**, by half the bounding box height plus a margin, or the wheels start interpenetrating the ground and the solver launches the car.
- **Overlap check filter.** Include the live vehicles folder and characters. Excluding nothing means the pad itself is a hit. Use `Include` filtering so the pad, terrain and decorations are ignored.
- **Eject before destroy.** Destroying a car with someone seated leaves a character with a broken `SeatWeld` for a frame and can fling them. Set `Humanoid.Sit = false` first.
- **Set ownership after parenting.** `SetNetworkOwner` needs the part in the workspace and unanchored (Roblox docs, network ownership page). If templates are stored anchored, unanchor after `PivotTo`, then set the owner.
- **`os.clock` for rate limits, `time()` for gameplay timers** is fine on a normal server; under Server Authority, simulation code must use `time()` ([[Server Authority and Input Migration 2026]]).

## 3. Limits that protect the server

| Limit | Typical value (Rule of thumb) | Why |
|---|---|---|
| Active cars per player | 1 | Prevents spam and makes cleanup trivial |
| Server-wide cap | about 1.2 x max players | Physics and replication cost scale with moving assemblies |
| Spawn cooldown | 3 to 5 s | Remote spam and "spawn on top of you" griefing |
| Abandon timer | 1 to 3 min empty and far from owner | Clears cars left across the map |
| Wreck timer | 10 to 30 s after destroyed | Lets the crash be seen, then frees resources |

When the server cap is hit, refuse the spawn with a message, or despawn the oldest abandoned car first. Never despawn an occupied car.

## 4. The garage is data, not instances

Save what the player owns as plain data and rebuild cars from templates:

```lua
-- Profile shape (example)
-- Garage = {
--   owned = { sedan = { paint = "#C8102E", rims = "sport", plate = "LIH 01" }, truck = {...} },
--   selected = "sedan",
-- }
```

- **Ownership is granted by the server** only: a purchase handler, a quest reward, a gamepass check. Use the same receipt-safe flow as any other item ([[Saved Inventory End to End]]).
- **Cosmetic values are validated on spawn.** A saved paint string from an old version or a tampered import must be clamped to allowed options before applying.
- **No dupes from rejoin.** A car instance in the world is not inventory. Destroying it never refunds; spawning it never grants. The only source of truth is the profile, so a player who leaves mid-drive simply loses the live instance.
- **Selling a car** removes it from `owned` and despawns the live copy in the same server step.
- **Damage and fuel**, if persistent, are fields on the owned entry, written when the car despawns or on autosave, not every frame.

## 5. Showroom and preview

Previews should be client-side: clone a stripped visual copy (no scripts, no seats) into a `ViewportFrame` or a local showroom. Never spawn a server car just to show it. For paint previews, recolour the local copy and only send the final choice.

## Common mistakes

| Mistake | Fix |
|---|---|
| Templates in ReplicatedStorage | ServerStorage, clone on spawn |
| Client sends spawn position | Server picks a clear pad |
| Spawning inside the ground or another car | Bounding box offset and overlap check |
| Cars never cleaned up | Leave, abandon and wreck timers |
| Destroying an occupied car | Eject first |
| Saving car instances or refunding on despawn | Garage is data; instances are disposable |
| Ownership set before parenting or while anchored | Parent, unanchor, then `SetNetworkOwner` |

## Checklist

- [ ] Remote takes a short string id; rate-limited; validated against the profile.
- [ ] One active car per player and a server-wide cap.
- [ ] Clear-pad check with `GetPartBoundsInBox`; spawn offset above the pad.
- [ ] Empty cars server-owned; driver ownership on sit.
- [ ] Despawn on leave, abandonment and wreck; occupants ejected first.
- [ ] Garage saved as data with validated cosmetics; no refunds on despawn.

## See also

[[Cars with Constraints - Suspension Steering and Drive]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Session Locking and Profile Libraries]] · [[Saved Inventory End to End]] · [[Rate Limiting and Abuse Prevention]] · [[Spawn Points Safe Zones and Respawn Flow]] · [[Instance Streaming]] · [[Genre Playbook - Racing and Driving]]

## Connected notes
<!-- auto-links:start -->
[[Physics and Vehicles Start Here]] · [[Raycasts Shapecasts and Spatial Queries]] · DataStore Fundamentals · Network Ownership
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Vehicle Damage, Repair and Wreck States]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] · [[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]] · [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] · [[Centre of Mass, Anti-Flip and Self-Righting]] · [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]]
<!-- related:end -->
