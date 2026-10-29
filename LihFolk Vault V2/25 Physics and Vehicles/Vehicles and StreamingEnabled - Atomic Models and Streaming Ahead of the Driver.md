---
tags: [physics, vehicles, streaming, streamingenabled, network-ownership, open-world, type/guide, area/physics, area/networking, level/advanced, api/ModelStreamingMode, api/RequestStreamAroundAsync, api/AddReplicationFocus, api/AddPersistentPlayer]
---
# Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Car models left Nonatomic -> `Atomic`; driver's car `PersistentPerPlayer`
> - Avoid: Every car Persistent -> Persistent per driver only
> - Avoid: Default radii for a 200 studs/s racer -> Size min radius from speed; persistent road collider
> - All vehicle templates `Atomic`; driver added as persistent player on sit, removed on exit.
> - `StreamingMinRadius` sized against top speed and tested on a low-end phone.
> - Main road network has a guaranteed collider.
>
> Cost: TL;DR ~160 tok · whole note ~2.6k tok. Read more: ## 2. Make every vehicle Atomic · ## 3. Stream far enough ahead · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Instance streaming and fast vehicles pull in opposite directions. Streaming keeps only the area near each player loaded; a car's whole job is to leave that area quickly. The result is a family of bugs specific to driving games: the driver's own car arriving without its wheels, cars falling through roads that have not streamed in yet, the world popping in at the windscreen, and other players' cars vanishing mid-race. Since Server Authority (July 2026) forces StreamingEnabled on, "just turn streaming off" is no longer an option for games that want it. General streaming is in [[Instance Streaming]]; this note is the vehicle angle.

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

## 1. What streaming does to a car

Facts from the docs (https://create.roblox.com/docs/workspace/streaming):

- Only `Workspace` descendants stream. BaseParts stream in by distance from each player's replication focus, by default the character.
- A `Model`'s `ModelStreamingMode` decides how its parts arrive: `Atomic` (all at once, out all at once), `Persistent` (always present after join), `PersistentPerPlayer` (persistent for players added with `Model:AddPersistentPlayer()`, atomic for others), `Nonatomic`/`Default` (part by part, or per the `ModelStreamingBehavior` setting).
- Client physics only simulates in streamed regions. A client-owned assembly moving into space with no streamed ground has nothing to land on.

Consequences for vehicles (Rule of thumb):

| Symptom | Cause |
|---|---|
| Driver's client errors indexing `car.Wheels.FL` | Nonatomic car streamed in part by part |
| Car falls through the road at speed | Client owns the car and has not streamed the road yet |
| World pops in ahead of the bonnet | Target radius too small for the speed |
| Other racers' cars vanish then reappear | Beyond the viewer's streaming radius, so streamed out |
| Player freezes mid-drive with a loading pause | `StreamingIntegrityMode` paused them on entering an unloaded area |

## 2. Make every vehicle Atomic

Set `ModelStreamingMode = Atomic` on vehicle templates. Every client then receives a car whole or not at all, so client code can wait for the model and index children directly. This includes seats: an Atomic car never shows up seatless, which also removes the "sat in a seat that was not there yet" class of bugs.

For the **driver's own car**, use `PersistentPerPlayer` and add the driver, so their car can never stream out from under them even if the camera or focus moves (spectate, photo mode, a cutscene):

```lua
--!strict
-- Server: keep a driven car persistent for its driver only.
local Players = game:GetService("Players")

local function onOccupantChanged(car: Model, seat: VehicleSeat, current: { player: Player? })
	local hum = seat.Occupant
	local driver = if hum then Players:GetPlayerFromCharacter(hum.Parent) else nil
	if current.player and current.player ~= driver then
		car:RemovePersistentPlayer(current.player)
	end
	if driver then
		car:AddPersistentPlayer(driver)
	end
	current.player = driver
end

local function setup(car: Model)
	car.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
	if seat == nil then return end
	local current: { player: Player? } = { player = nil }
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onOccupantChanged(car, seat, current)
	end)
end

return setup
```

Set the mode on the template in Studio where you can; setting it on a fresh clone before parenting is the scripted equivalent. Do not mark every car `Persistent`: fifty persistent cars are fifty cars every client must hold and render all match.

## 3. Stream far enough ahead

The road under a fast car must already be loaded on the driver's client. Rough sizing (Rule of thumb):

```
lead time = (StreamingMinRadius) / top speed
```

At 200 studs/s with a minimum radius of 256 studs, the guaranteed area is about 1.3 s ahead. That is thin on a phone with a slow connection. Options, cheapest first:

1. **Raise `StreamingMinRadius`** for driving games. Costs memory on every client; test on a low-end phone.
2. **Design roads as long sight lines with landmarks**, and put open ground beside fast sections so pop-in is less visible ([[Level of Detail and Model Streaming]]).
3. **A persistent road collider.** A simple, low-poly, invisible collision mesh for the main road network in a `Persistent` model guarantees there is always something to drive on, while the detailed road and scenery stream normally. Cheap in memory if the mesh is coarse. **Rule of thumb**; check the memory cost in the Developer Console.
4. **A focus ahead of the car.** `Player:AddReplicationFocus(part)` streams around an extra part (Roblox docs). Move an invisible anchored part some distance ahead of the car along its velocity. The docs warn each extra focus costs server streaming work roughly like another player, so use it only for high-speed vehicles and remove it when the player exits.
5. **Server teleports of cars** (respawn on track, fast travel): call `Player:RequestStreamAroundAsync(position, timeout)` for the driver before `PivotTo`, exactly as for characters ([[Instance Streaming]]), then grant the validator an allowance ([[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]]).

```lua
--!strict
-- Server: a look-ahead focus for one fast driver.
local RunService = game:GetService("RunService")

local LEAD_SECONDS = 2.5

local function startLookAhead(player: Player, root: BasePart): () -> ()
	local marker = Instance.new("Part")
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Transparency = 1
	marker.Size = Vector3.one
	marker.Parent = workspace
	player:AddReplicationFocus(marker)
	local conn = RunService.Heartbeat:Connect(function()
		local v = root.AssemblyLinearVelocity
		marker.Position = root.Position + Vector3.new(v.X, 0, v.Z) * LEAD_SECONDS
	end)
	return function()
		conn:Disconnect()
		player:RemoveReplicationFocus(marker)
		marker:Destroy()
	end
end

return startLookAhead
```

## 4. Integrity pauses and drivers

`StreamingIntegrityMode` decides what happens when a player moves into an unloaded area; `PauseOutsideLoadedArea` pauses them (Roblox docs). A pause mid-drive feels terrible, but falling through the world is worse. Rule of thumb: keep a pausing mode on, size radii so it almost never triggers at your top speed, and log when it does (it shows you where streaming is too slow). `PredictiveStreamingMode = Enabled` pre-fetches respawn points and keeps recently left areas briefly, which helps checkpoint respawns (Roblox docs).

Frustum streaming (`Player.FrustumStreaming`, September 2026; DevForum: https://devforum.roblox.com/t/frustum-streaming-stream-what-your-players-see/4904553) prioritises what the camera sees. **Unverified** for vehicles: how it treats the area behind a car (mirrors, reversing, chase-cam swings). Test reversing at speed before enabling it.

## 5. Other players' cars

- A viewer only has nearby cars. Race HUDs and minimaps must not read other cars' positions from the workspace; publish positions from the server (attributes on a lightweight folder, or an unreliable remote at a few hertz) so far racers still appear on the map.
- When a car streams out and back in, any client-side effects (exhaust particles, nametag, engine sound) attached to it are gone. Set them up from `CollectionService` tag added and removed signals, not once at join.
- Spectating a far racer needs `ReplicationFocus` set to their car on the server, then cleared.

## 6. Server Authority note

`Workspace.AuthorityMode = Server` forces StreamingEnabled (Roblox docs, [[Server Authority and Input Migration 2026]]). If you plan to move a vehicle game to Server Authority, fix streaming first; it is a prerequisite, not a follow-up.

## Common mistakes

| Mistake | Fix |
|---|---|
| Car models left Nonatomic | `Atomic`; driver's car `PersistentPerPlayer` |
| Every car Persistent | Persistent per driver only |
| Default radii for a 200 studs/s racer | Size min radius from speed; persistent road collider |
| Extra focus left after exit | Remove focus and destroy the marker |
| Server teleports a car without pre-streaming | `RequestStreamAroundAsync` first |
| Minimap reads far cars from workspace | Server-published positions |
| Effects set up once per car at join | Tag signals, rebuild on stream-in |

## Checklist

- [ ] All vehicle templates `Atomic`; driver added as persistent player on sit, removed on exit.
- [ ] `StreamingMinRadius` sized against top speed and tested on a low-end phone.
- [ ] Main road network has a guaranteed collider.
- [ ] Look-ahead focus only for high-speed vehicles; cleaned up on exit.
- [ ] Server car teleports pre-stream the destination.
- [ ] HUD and minimap use server-published positions.
- [ ] Integrity pauses logged with location.

## See also

[[Instance Streaming]] · [[Level of Detail and Model Streaming]] · [[Infinite and Streamed Worlds]] · [[Interest Management and Per-Player Replication]] · [[Server Authority and Input Migration 2026]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Genre Playbook - Racing and Driving]]

## Connected notes
<!-- auto-links:start -->
[[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]] · [[Network Bandwidth Budgets and Measuring Them]] · [[Physics and Vehicles Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Streaming Radius]] · [[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]] · [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]] · [[Vehicle Damage, Repair and Wreck States]] · [[Engine, Gearbox and Torque Curve Model for Arcade Cars]] · [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] · [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]]
<!-- related:end -->
