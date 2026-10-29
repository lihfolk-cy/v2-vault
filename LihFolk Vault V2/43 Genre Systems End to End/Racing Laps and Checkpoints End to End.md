---
tags: [genre-system, racing, vehicles, checkpoints, worked-build, anti-cheat, timing, luau, type/guide, area/gameplay, level/intermediate, api/ProximityPrompt]
---
# Racing Laps and Checkpoints End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Client-reported lap times. Never.
> - Touch-based gates at high speed (section 1).
> - Gates facing backwards. The start-up assert catches it.
> - Solo race: countdown, car cannot move before GO, three laps counted, finish time shown, best lap saved.
> - Drive backwards over the start line: no lap.
> - Drive at full speed through a tight chicane: no missed gates (lower `TickHz` to 10 to stress it).
>
> Cost: TL;DR ~140 tok · whole note ~7.7k tok. Read more: ## 4. The server: RaceService · ## 5. The client: RaceClient · ## 6. Edge cases and failure modes · ## 9. Test checklist
<!-- tldr:end -->

This note builds the race layer around a car: a grid, a countdown that cannot be jumped, gate crossing detected by swept segments so cars at 200 studs per second never tunnel through a checkpoint, crossing times interpolated between server frames, laps and finish order, live race positions, wrong-way detection, resets to the last gate, plausibility checks against the car's real top speed, ghost collisions between racers, a DNF timer, and best laps saved only for clean laps. The car itself is out of scope; build it with [[Cars with Constraints - Suspension Steering and Drive]]. [[Genre Playbook - Racing and Driving]] explains network ownership and why lap times must not come from the client; this note implements the server-side timing it describes and covers the geometry and timing details that decide whether close finishes are fair.

> **All code is reviewed, not run.** Strict Luau against Roblox docs (as of October 2026), checked by reading. Use the checklist in section 9.

Labels used: **Roblox docs (as of October 2026)**, **rule of thumb**.

---

## 1. Why touch volumes are not enough

The common first attempt is a big invisible part per checkpoint with a `Touched` handler. It fails in three ways at racing speeds:

| Problem | Cause | Effect |
|---|---|---|
| Missed checkpoints | A car moving 150 studs/s covers 2.5 studs per 60 Hz frame and more per network update; a 2-stud-thick gate can fall between two replicated positions | Lap not counted, players furious |
| Imprecise times | `Touched` fires at the frame the server noticed overlap, not when the nose crossed the line | Two cars that finished 0.05 s apart can be ranked wrong |
| Direction-blind | A touch is a touch, forwards or backwards | Driving back and forth over a gate can count it |

The server instead keeps each racer's previous chassis position, and every tick tests the segment from previous to current position against the **plane** of the next gate, bounded by the gate's width and height. That test cannot be skipped by speed, gives the exact fraction of the tick at which the line was crossed, and knows the direction. It is the same segment-plane intersection described in [[Intersection and Collision Math]].

### When not to use this design
- **Open-world driving with no laps.** Use trigger zones for missions; precision does not matter.
- **Physics-heavy demolition racing** where cars flip and get stuck constantly: the gate logic still works, but your reset rules dominate and you need much more generous plausibility checks.

---

## 2. Folder layout

```
ReplicatedStorage
  Shared (Folder)
    Net (ModuleScript)               -- from Saved Inventory End to End
    RaceConfig (ModuleScript)
ServerScriptService
  Server (Folder)
    Main (Script)                    -- add "RaceService" to ORDER
    PlayerData, DataTemplate, RateLimiter (ModuleScripts)
    Services (Folder)
      RaceService (ModuleScript)
ServerStorage
  Cars (Folder)
    Default (Model: PrimaryPart = Chassis, a VehicleSeat named DriverSeat)
Workspace
  Track (Model, attributes TrackId = "harbour", Laps = 3)
    Gates (Folder of Parts named 1..N; gate 1 is the start/finish line)
    Grid (Folder of Parts named 1..8, front of the car along each part's LookVector)
  Lobby (Model with a SpawnLocation and a "Join race" ProximityPrompt)
StarterPlayer/StarterPlayerScripts/Client
  RaceClient (LocalScript)
```

**Gate authoring rule.** Each gate is an anchored, invisible, `CanCollide = false`, `CanQuery = false` part whose front face (`LookVector`) points in the racing direction and whose X and Y size cover the road plus a margin. The server reads only its `CFrame` and `Size`; it is never touched. A gate that is rotated backwards makes the track impossible to lap, so the service asserts that consecutive gates face roughly the same way as the vector between them. Put the grid just behind gate 1: racers start with gate 2 as their next gate, so the first pass over the start line is ignored and lap 1 completes on the second.

**Collision group for ghost racing.** Create a collision group `Cars` in Studio's Collision Groups editor and set it not to collide with itself. The service sets `BasePart.CollisionGroup = "Cars"` on every part of a spawned car. (Roblox docs (as of October 2026) list `PhysicsService:RegisterCollisionGroup` and `CollisionGroupSetCollidable` for doing this at runtime and the `BasePart.CollisionGroup` property for assignment; the older part-assignment methods are deprecated.) Ghost racing is the playbook's fix for ramming and phantom hits between client-owned cars.

---

## 3. Data

### 3.1 RaceConfig

```lua
--!strict
-- ReplicatedStorage/Shared/RaceConfig (ModuleScript). Reviewed, not run.
local RaceConfig = {}

RaceConfig.MinRacers = 1            -- 1 for testing; 2 or more live
RaceConfig.MaxRacers = 8
RaceConfig.JoinWindowSeconds = 15
RaceConfig.CountdownSeconds = 4
RaceConfig.DnfSeconds = 30          -- after the winner finishes
RaceConfig.MaxSpeed = 160           -- the fastest car's top speed in studs/s, from your car tuning
RaceConfig.SpeedMargin = 1.25       -- allowed above MaxSpeed before a tick is flagged
RaceConfig.TeleportSlack = 8        -- studs per tick on top of speed * dt
RaceConfig.WrongWaySeconds = 2
RaceConfig.ResetCooldown = 3
RaceConfig.TickHz = 30

return RaceConfig
```

`MaxSpeed` is the most important number here. It must come from the car's real tuning, including downhill and boost, measured in play. If it is too low, honest fast players get flagged; too high and speed hacks pass.

### 3.2 Profile fields

```lua
-- In DataTemplate (Saved Inventory End to End): add to the Data type
	Racing: { Races: number, Wins: number, BestLaps: { [string]: number } },
-- and to DataTemplate.new()
		Racing = { Races = 0, Wins = 0, BestLaps = {} },
```

`BestLaps` is keyed by `TrackId`, a stable string. Never key it by track name shown to players (you will rename tracks) or by a numeric index (you will reorder them).

---

## 4. The server: RaceService

```lua
--!strict
-- ServerScriptService/Server/Services/RaceService (ModuleScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)
local PlayerData = require(script.Parent.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

type Gate = { CFrame: CFrame, Half: Vector3 }
type Racer = {
	Player: Player,
	Car: Model,
	Chassis: BasePart,
	PrevPosition: Vector3,
	PrevTime: number,
	NextGate: number,       -- index of the gate to cross next
	Lap: number,            -- completed laps
	LapStartedAt: number,   -- server time
	LapClean: boolean,
	Flags: number,
	FinishedAt: number?,
	WrongWayFor: number,
	LastReset: number,
}

local RaceService = {}

local gates: { Gate } = {}
local gridSlots: { CFrame } = {}
local trackId = ""
local laps = 3
local state: "Idle" | "Joining" | "Countdown" | "Racing" | "Finished" = "Idle"
local racers: { [Player]: Racer } = {}
local finishOrder: { Player } = {}
local raceStartedAt = 0
local allowJoin = RateLimiter.new(2, 0.5)
local allowReset = RateLimiter.new(2, 0.3)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setState(newState: "Idle" | "Joining" | "Countdown" | "Racing" | "Finished", endsAt: number?)
	state = newState
	workspace:SetAttribute("RaceState", newState)
	workspace:SetAttribute("RaceEndsAt", endsAt or 0)
end

-- Gate crossing ---------------------------------------------------------------------------
-- Returns the fraction (0..1) of the segment at which it crosses the gate forwards, or nil.
local function crossFraction(gate: Gate, from: Vector3, to: Vector3): number?
	local a = gate.CFrame:PointToObjectSpace(from)
	local b = gate.CFrame:PointToObjectSpace(to)
	-- Object space: -Z is the gate's LookVector (forward). Forward crossing goes from z > 0 to z <= 0.
	if not (a.Z > 0 and b.Z <= 0) then
		return nil
	end
	local t = a.Z / (a.Z - b.Z)
	local hit = a:Lerp(b, t)
	if math.abs(hit.X) > gate.Half.X or math.abs(hit.Y) > gate.Half.Y then
		return nil -- crossed the plane outside the gate (a shortcut through the grass)
	end
	return t
end

-- Car handling ----------------------------------------------------------------------------
local function spawnCar(player: Player, slot: CFrame): Racer?
	local cars = ServerStorage:FindFirstChild("Cars")
	local template = cars and cars:FindFirstChild("Default")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not template or not template:IsA("Model") or not humanoid then
		return nil
	end
	local car = template:Clone()
	car.Name = `Car_{player.UserId}`
	car:PivotTo(slot + Vector3.new(0, 3, 0))
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Cars"
		end
	end
	car.Parent = workspace
	local chassis = car.PrimaryPart :: BasePart
	local seat = car:FindFirstChild("DriverSeat", true)
	-- Anchored until GO: the client cannot move an anchored part, so the start cannot be jumped.
	chassis.Anchored = true
	if seat and seat:IsA("VehicleSeat") then
		seat:Sit(humanoid)
	end
	local t = now()
	return {
		Player = player, Car = car, Chassis = chassis,
		PrevPosition = chassis.Position, PrevTime = t,
		NextGate = 2, Lap = 0, LapStartedAt = 0, LapClean = true, Flags = 0,
		FinishedAt = nil, WrongWayFor = 0, LastReset = -math.huge,
	}
end

local function removeRacer(player: Player)
	local racer = racers[player]
	if racer then
		racers[player] = nil
		racer.Car:Destroy()
	end
	player:SetAttribute("RaceLap", nil)
	player:SetAttribute("RacePosition", nil)
	player:SetAttribute("RaceNextGate", nil)
end

local function resetToGate(racer: Racer)
	local previous = racer.NextGate - 1
	if previous < 1 then
		previous = #gates
	end
	local gate = gates[previous]
	racer.Car:PivotTo(gate.CFrame + Vector3.new(0, 3, 0))
	racer.Chassis.AssemblyLinearVelocity = Vector3.zero
	racer.Chassis.AssemblyAngularVelocity = Vector3.zero
	racer.PrevPosition = racer.Chassis.Position
	racer.PrevTime = now()
end

-- Results ---------------------------------------------------------------------------------
local function recordLap(racer: Racer, lapSeconds: number)
	if not racer.LapClean then
		return
	end
	local profile = PlayerData.Get(racer.Player)
	if not profile then
		return
	end
	local best = profile.Data.Racing.BestLaps[trackId]
	if best == nil or lapSeconds < best then
		profile.Data.Racing.BestLaps[trackId] = lapSeconds
		racer.Player:SetAttribute("BestLap", lapSeconds)
		-- Leaderboard hook: submit here (Global Leaderboards End to End), lower is better.
	end
end

local function finishRace()
	setState("Finished", now() + 8)
	local field = 0
	for _ in racers do
		field += 1
	end
	for index, player in finishOrder do
		local profile = PlayerData.Get(player)
		if profile then
			profile.Data.Racing.Races += 1
			if index == 1 and field >= 2 then -- a solo race is practice, not a win
				profile.Data.Racing.Wins += 1
			end
		end
	end
	for player, racer in racers do
		if not racer.FinishedAt then
			local profile = PlayerData.Get(player)
			if profile then
				profile.Data.Racing.Races += 1 -- a DNF still counts as a race played
			end
		end
	end
	task.delay(8, function()
		for player in racers do
			removeRacer(player)
		end
		table.clear(finishOrder)
		setState("Idle")
	end)
end

-- The tick --------------------------------------------------------------------------------
local accumulator = 0

local function tick()
	local t = now()
	for player, racer in racers do
		if racer.FinishedAt or not racer.Car.Parent then
			continue
		end
		local position = racer.Chassis.Position
		local dt = math.max(t - racer.PrevTime, 1e-3)
		local moved = (position - racer.PrevPosition).Magnitude

		-- Plausibility: faster than the fastest car can go, or a jump in position.
		if moved > RaceConfig.MaxSpeed * RaceConfig.SpeedMargin * dt + RaceConfig.TeleportSlack then
			racer.Flags += 1
			racer.LapClean = false
			warn(`[Race] {player.UserId} moved {math.floor(moved)} studs in {dt}s`)
			resetToGate(racer) -- respond with a reset, not a ban: physics glitches look the same
			continue
		end

		-- Gate crossing. Allow two gates per tick at most (very short gate spacing at high speed).
		for _ = 1, 2 do
			local gate = gates[racer.NextGate]
			local fraction = crossFraction(gate, racer.PrevPosition, position)
			if not fraction then
				break
			end
			local crossedAt = racer.PrevTime + fraction * dt
			if racer.NextGate == 1 then
				-- Start/finish line: a lap is complete.
				racer.Lap += 1
				local lapSeconds = crossedAt - racer.LapStartedAt
				recordLap(racer, lapSeconds)
				racer.LapStartedAt = crossedAt
				racer.LapClean = true
				player:SetAttribute("RaceLap", racer.Lap)
				player:SetAttribute("RaceLapStartedAt", crossedAt)
				if racer.Lap >= laps then
					racer.FinishedAt = crossedAt
					table.insert(finishOrder, player)
					player:SetAttribute("RaceFinishSeconds", crossedAt - raceStartedAt)
					if #finishOrder == 1 then
						workspace:SetAttribute("RaceEndsAt", t + RaceConfig.DnfSeconds)
						task.delay(RaceConfig.DnfSeconds, function()
							if state == "Racing" then
								finishRace()
							end
						end)
					end
					break
				end
			end
			racer.NextGate = racer.NextGate % #gates + 1
			player:SetAttribute("RaceNextGate", racer.NextGate)
		end

		-- Wrong way: moving away from the next gate for a while.
		local toGate = gates[racer.NextGate].CFrame.Position - position
		local velocity = racer.Chassis.AssemblyLinearVelocity
		if velocity.Magnitude > 10 and velocity.Unit:Dot(toGate.Unit) < -0.5 then
			racer.WrongWayFor += dt
		else
			racer.WrongWayFor = 0
		end
		player:SetAttribute("RaceWrongWay", racer.WrongWayFor > RaceConfig.WrongWaySeconds)

		racer.PrevPosition = position
		racer.PrevTime = t
	end

	-- Everyone finished: end early.
	local anyRacing = false
	for _, racer in racers do
		if not racer.FinishedAt then
			anyRacing = true
			break
		end
	end
	if not anyRacing and state == "Racing" then
		finishRace()
	end
end

local positionAccumulator = 0
local function updatePositions()
	-- Rank by laps, then gates passed, then distance to the next gate. Finished racers by time.
	local list: { Racer } = {}
	for _, racer in racers do
		table.insert(list, racer)
	end
	local function progress(racer: Racer): number
		local passed = (racer.NextGate - 2) % #gates -- gates crossed this lap
		local distance = (gates[racer.NextGate].CFrame.Position - racer.Chassis.Position).Magnitude
		return racer.Lap * 100000 + passed * 1000 - math.min(distance, 999)
	end
	table.sort(list, function(a: Racer, b: Racer): boolean
		if a.FinishedAt and b.FinishedAt then
			return a.FinishedAt < b.FinishedAt
		elseif a.FinishedAt or b.FinishedAt then
			return a.FinishedAt ~= nil
		end
		return progress(a) > progress(b)
	end)
	for index, racer in list do
		racer.Player:SetAttribute("RacePosition", index)
	end
end

-- Flow ------------------------------------------------------------------------------------
local function startRace()
	local slot = 1
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("RaceJoined") == true and slot <= #gridSlots and slot <= RaceConfig.MaxRacers then
			local racer = spawnCar(player, gridSlots[slot])
			if racer then
				racers[player] = racer
				slot += 1
			end
		end
		player:SetAttribute("RaceJoined", nil)
	end
	if slot - 1 < RaceConfig.MinRacers then
		for player in racers do
			removeRacer(player)
		end
		setState("Idle")
		return
	end
	local goAt = now() + RaceConfig.CountdownSeconds
	setState("Countdown", goAt)
	task.wait(RaceConfig.CountdownSeconds)
	raceStartedAt = now()
	for player, racer in racers do
		racer.LapStartedAt = raceStartedAt
		racer.PrevPosition = racer.Chassis.Position
		racer.PrevTime = raceStartedAt
		racer.Chassis.Anchored = false
		-- The driver's client simulates its own car (Network ownership in the playbook).
		if racer.Chassis:CanSetNetworkOwnership() then
			racer.Chassis:SetNetworkOwner(player)
		end
		player:SetAttribute("RaceLap", 0)
		player:SetAttribute("RaceLapStartedAt", raceStartedAt)
		player:SetAttribute("RaceNextGate", racer.NextGate)
	end
	setState("Racing")
end

function RaceService.Start()
	local track = workspace:WaitForChild("Track")
	trackId = tostring(track:GetAttribute("TrackId") or "track")
	local lapsAttribute = track:GetAttribute("Laps")
	laps = if type(lapsAttribute) == "number" then math.clamp(lapsAttribute, 1, 20) else 3

	local gateFolder = track:WaitForChild("Gates")
	for i = 1, #gateFolder:GetChildren() do
		local part = gateFolder:FindFirstChild(tostring(i))
		assert(part and part:IsA("BasePart"), `gate {i} missing`)
		table.insert(gates, { CFrame = part.CFrame, Half = part.Size / 2 })
	end
	assert(#gates >= 3, "a lap needs at least three gates")
	for i, gate in gates do
		local nextGate = gates[i % #gates + 1]
		local along = (nextGate.CFrame.Position - gate.CFrame.Position).Unit
		assert(gate.CFrame.LookVector:Dot(along) > 0, `gate {i} faces backwards`)
	end
	local gridFolder = track:WaitForChild("Grid")
	for i = 1, #gridFolder:GetChildren() do
		local part = gridFolder:FindFirstChild(tostring(i))
		if part and part:IsA("BasePart") then
			table.insert(gridSlots, part.CFrame)
		end
	end

	Net.Event("RaceJoin").OnServerEvent:Connect(function(player: Player)
		if not allowJoin(player) or not PlayerData.Get(player) then
			return
		end
		if state == "Idle" then
			setState("Joining", now() + RaceConfig.JoinWindowSeconds)
			player:SetAttribute("RaceJoined", true)
			task.delay(RaceConfig.JoinWindowSeconds, startRace)
		elseif state == "Joining" then
			player:SetAttribute("RaceJoined", true)
		end
	end)

	Net.Event("RaceReset").OnServerEvent:Connect(function(player: Player)
		local racer = racers[player]
		if not racer or state ~= "Racing" or racer.FinishedAt or not allowReset(player) then
			return
		end
		if os.clock() - racer.LastReset < RaceConfig.ResetCooldown then
			return
		end
		racer.LastReset = os.clock()
		resetToGate(racer) -- resets are allowed on a clean lap: they cost time, not cleanliness
	end)

	Players.PlayerRemoving:Connect(removeRacer)

	RunService.Heartbeat:Connect(function(dt: number)
		if state ~= "Racing" then
			return
		end
		accumulator += dt
		if accumulator >= 1 / RaceConfig.TickHz then
			accumulator = 0
			tick()
		end
		positionAccumulator += dt
		if positionAccumulator >= 0.25 then
			positionAccumulator = 0
			updatePositions()
		end
	end)
end

return RaceService
```

### 4.1 The decisions that matter

**Interpolated crossing times.** `crossedAt = PrevTime + fraction * dt` estimates when the chassis crossed the line between two server samples. At 30 Hz and 150 studs per second, samples are 5 studs apart; without interpolation every lap time has up to 33 ms of random error, enough to swap two places in a photo finish. With it, the remaining error comes from the replicated position itself.

**The server sees cars late, and that is mostly fine.** A driver's car is simulated on its owner's client; the server receives positions after the owner's latency plus buffering. Every car is late by its own driver's ping. For finish order between two players with 60 ms and 180 ms ping, the high-ping player's crossing is observed later, so the server's order slightly favours low-ping players in a dead heat. The playbook's suggestion (accept the client's own crossing time when it is within a small window of the server's, and log it) reduces that bias; it also opens a small window for a cheater to shave time. A practical compromise: use server times for ordering, and only use client times as a tie-breaker when the server times are within 50 ms (rule of thumb), never to change a gap larger than that.

**Anchored until GO.** The client cannot move anchored parts, and anchoring the chassis during the countdown makes a false start impossible without any detection code. At GO the server un-anchors and hands ownership to the driver. Checking `CanSetNetworkOwnership()` first avoids an error if the assembly is still anchored or welded to something anchored (Roblox docs (as of October 2026), `BasePart:CanSetNetworkOwnership`).

**Speed plausibility resets, it does not ban.** A car launched by a physics glitch at 400 studs per second looks exactly like a speed hack. The response is the same as for a cheater who is not sure he is being watched: reset to the last gate and mark the lap unclean. Persistent flags across races can feed a review queue ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]).

**Clean laps only for best times.** A lap with any flag does not update `BestLaps`. Resets do not make a lap unclean, because a reset costs time already. Skipping a gate is impossible by construction: the next gate must be crossed, inside its bounds, forwards.

**Two gates per tick.** On a tight chicane with gates 6 studs apart, a fast car can cross two gates between samples. The inner loop allows two; more than that means your gates are too close for your tick rate.

**Positions at 4 Hz.** Sorting eight racers four times a second is nothing; doing it every frame and replicating attributes every frame is wasted bandwidth.

---

## 5. The client: RaceClient

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/Client/RaceClient (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local resetRemote = Net.Event("RaceReset")
local joinRemote = Net.Event("RaceJoin")

local gui = Instance.new("ScreenGui")
gui.Name = "RaceHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(y: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(0.3, 0.06)
	l.Position = UDim2.fromScale(0.35, y)
	l.BackgroundTransparency = 0.4
	l.TextScaled = true
	l.Parent = gui
	return l
end

local status = label(0.02)
local lapLabel = label(0.09)
local wrongWay = label(0.4)
wrongWay.Text = "WRONG WAY"
wrongWay.TextColor3 = Color3.fromRGB(255, 80, 80)

local gates: { BasePart } = {}
local gateFolder = workspace:WaitForChild("Track"):WaitForChild("Gates")
for i = 1, #gateFolder:GetChildren() do
	table.insert(gates, gateFolder:WaitForChild(tostring(i)) :: BasePart)
end

-- A beam-free arrow: a small part that floats over the next gate.
local marker = Instance.new("Part")
marker.Anchored = true
marker.CanCollide = false
marker.CanQuery = false
marker.CanTouch = false
marker.Size = Vector3.new(2, 2, 2)
marker.Shape = Enum.PartType.Ball
marker.Material = Enum.Material.Neon
marker.Parent = workspace

RunService.PreRender:Connect(function()
	local raceState = workspace:GetAttribute("RaceState")
	local endsAt = (workspace:GetAttribute("RaceEndsAt") :: number?) or 0
	local t = workspace:GetServerTimeNow()
	if raceState == "Countdown" then
		status.Text = tostring(math.max(1, math.ceil(endsAt - t)))
	elseif raceState == "Joining" then
		status.Text = `Race starts in {math.max(0, math.ceil(endsAt - t))}`
	elseif raceState == "Racing" then
		local position = player:GetAttribute("RacePosition")
		status.Text = if position then `P{position}` else "Spectating"
	else
		status.Text = ""
	end

	local lap = player:GetAttribute("RaceLap")
	local lapStart = player:GetAttribute("RaceLapStartedAt")
	if type(lap) == "number" and type(lapStart) == "number" and raceState == "Racing" then
		lapLabel.Visible = true
		lapLabel.Text = string.format("Lap %d  %.2f s", lap + 1, t - lapStart)
	else
		lapLabel.Visible = false
	end

	wrongWay.Visible = player:GetAttribute("RaceWrongWay") == true
	local nextGate = player:GetAttribute("RaceNextGate")
	if type(nextGate) == "number" and gates[nextGate] then
		marker.Transparency = 0.2
		marker.Position = gates[nextGate].Position + Vector3.new(0, gates[nextGate].Size.Y / 2 + 3, 0)
	else
		marker.Transparency = 1
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonY then
		resetRemote:FireServer()
	end
end)

-- The lobby's ProximityPrompt (or a UI button) joins the next race.
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == "JoinRace" then
		joinRemote:FireServer()
	end
end)
```

The lap timer on screen counts from `RaceLapStartedAt`, a server time, using the client's `GetServerTimeNow()`, so it matches the time the server will record to within the clock sync error. The countdown display rounds up and never shows 0; the server un-anchors at the end of the countdown, so "GO" appears as the car becomes drivable. Add an on-screen reset button for touch players ([[Responsive UI for Phone Tablet Console and PC]]).

---

## 6. Edge cases and failure modes

### 6.1 The driver leaves the seat
A player who jumps out mid-race leaves a car that the server still tracks. Either re-seat on a key press, or treat an empty seat for 10 seconds as a DNF. The server must also take network ownership back (`SetNetworkOwner(nil)`) when the seat empties, so nobody else's client can fling the abandoned car, as the playbook's `bindSeat` shows.

### 6.2 Car destroyed or fallen into the void
`FallenPartsDestroyHeight` deletes parts that fall too far. The tick skips racers whose car has no parent; add a respawn: if `racer.Car.Parent == nil`, spawn a new car at the last gate and keep the racer's progress. Test it by driving off the map.

### 6.3 Shortcut through a gate's edge
`crossFraction` rejects crossings outside the gate rectangle. A gate that is narrower than the road lets a legitimate wide line miss the gate, and that player can never complete the lap. Make gates wider than the road plus the barriers, and taller than any jump.

### 6.4 Streaming
With [[Instance Streaming]], gates far from a client may not exist on it; the client marker waits on gates with `WaitForChild`, which could stall on a huge track. Mark the `Gates` folder's parts persistent, or drive the marker from positions the server publishes once as attributes. The server always has every gate.

### 6.5 What an exploiter can still do
The driver owns the car, so a cheater can still drive slightly better than physics allows: a little extra grip in corners, a top speed just under `MaxSpeed * SpeedMargin` on every straight. The per-tick check does not catch that, and no server check catches it cleanly, because honest cars also vary. Two cheap layers help. First, keep a per-track minimum plausible lap (your own best clean lap minus 10 percent, rule of thumb) and hold any lap below it out of leaderboards until reviewed. Second, log each racer's average speed per sector; a player who is at the car's exact limit on every straight of every lap is statistically unlike real drivers. Neither should ban automatically ([[Exploits and Anti-Cheat]]).

### 6.6 Common mistakes
- **Client-reported lap times.** Never. The server records crossings.
- **Touch-based gates at high speed** (section 1).
- **Gates facing backwards.** The start-up assert catches it.
- **No DNF timer.** One AFK player holds the whole lobby hostage forever.
- **`MaxSpeed` guessed instead of measured.** Your fastest honest players get reset on the best straight.

---

## 7. Numbers worth knowing

| Quantity | Value | Source |
|---|---|---|
| Server tick for gates | 30 Hz | Rule of thumb; 20 is fine for slower cars |
| Distance per tick at 150 studs/s | 5 studs | Arithmetic |
| Timing error without interpolation | up to 1 / TickHz (33 ms at 30 Hz) | Arithmetic |
| Position ranking | 4 Hz | Rule of thumb |
| DNF timer | 30 s after the winner | Rule of thumb |
| Client tie-breaker window | 50 ms | Rule of thumb |

---

## 8. Extending it

- **Ghost replays of a best lap.** Sample the chassis CFrame at 10 Hz during a clean best lap on the server and store a compressed track in a separate data store key (a few kilobytes per lap with `buffer` packing, see [[Buffers and Binary Data]]); play it back on the client as a translucent car.
- **Sector times.** Gates are already sectors: store split times at chosen gates and show green and purple splits like a real timing screen.
- **Car classes.** Give each car its own `MaxSpeed`, read from the car's attributes instead of the config, so a slow class is not judged by the fastest car's limit.
- **Leaderboards per track.** Submit best laps as integer milliseconds to an ordered store per `TrackId` ([[Global Leaderboards End to End]]).

---

## 9. Test checklist

- [ ] Solo race: countdown, car cannot move before GO, three laps counted, finish time shown, best lap saved.
- [ ] Drive backwards over the start line: no lap. Drive around a gate: next gate never advances.
- [ ] Drive at full speed through a tight chicane: no missed gates (lower `TickHz` to 10 to stress it).
- [ ] Teleport the car forward from the client's command bar: reset to last gate, lap marked unclean, warning logged.
- [ ] Two clients with different emulated latencies: finish order matches crossing order in a clear finish.
- [ ] One racer finishes, another idles: DNF after 30 s, both race counts saved.
- [ ] Leave mid-race: car removed, positions update for others.
- [ ] Fuzz `RaceJoin` and `RaceReset` with rapid repeats and extra arguments.

## See also
- [[Genre Playbook - Racing and Driving]], [[Cars with Constraints - Suspension Steering and Drive]], [[Physics and Vehicles Start Here]]
- [[Network Ownership]], [[Debugging Physics and Network Ownership]], [[Intersection and Collision Math]]
- [[Genre Systems Start Here]], [[Global Leaderboards End to End]], [[Saved Inventory End to End]]

## Connected notes
<!-- auto-links:start -->
[[Obby Checkpoints and Stage Saves End to End]] · [[Dot and Cross Products in Gameplay]] · Links - Constraints · Boats Buoyancy and Water · Game Math Start Here · Genre Playbook - Obbies and Platformers
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Race HUD - Position, Laps, Splits, Speedometer and Minimap]] · [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]] · [[Tower Defense Waves and Placement End to End]] · [[Tycoon Plots and Droppers End to End]] · [[Arena Rounds with Teams and Spectating End to End]] · [[Horror Monster Chase AI End to End]]
<!-- related:end -->
