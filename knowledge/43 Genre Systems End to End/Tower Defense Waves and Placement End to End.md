---
tags: [genre-system, tower-defense, worked-build, waves, placement, networking, server-authority, luau]
---
# Tower Defense Waves and Placement End to End

This note builds the match half of a tower defense game: a wave scheduler driven by data, enemies that exist on the server only as numbers, a batched event stream that lets every client draw the same enemies without CFrame replication, server-side targeting at a fixed rate, a placement remote that checks eight things in a fixed order, upgrades and selling, a skip-wave vote, and a match result written into the player's profile exactly once. [[Genre Playbook - Tower Defense]] explains why the data-driven enemy pattern is necessary and gives the `PathMath` module; this note builds the full system around that module and covers the parts the playbook leaves as bullet points: tick ordering, what to batch, how corrections work in practice, and how placement validation fails.

> **All code is reviewed, not run.** Strict Luau against Roblox docs (as of October 2026), checked by reading. Run section 8 before you trust it.

Labels used: **Roblox docs (as of October 2026)**, **rule of thumb**.

---

## 1. Shape of the system

```
Server (authoritative)                       Client (presentation)
---------------------                        ---------------------
WaveRunner   -> spawns enemy records          EnemyRenderer: pooled models placed by
Simulation   -> advances distance per tick       PathMath.positionAt(distance), extrapolated
Targeting    -> 10 Hz, picks "first" enemy        from server time
Damage/Death -> cash, lives, events          PlacementController: ghost, raycast, fire
Placement    -> 8 checks, then spawn tower      remote; never decides validity
Events out   -> one reliable batch per tick  TowerFx: muzzle flash per "fired" message
Corrections  -> unreliable, only on change
```

The one-match-per-server assumption matches the playbook's advice that lobby and match are different places: the lobby teleports a party into a reserved server, and this match server runs exactly one game. If you want several matches per server (rare, and only for tiny maps), wrap `MatchService` state in a `Match.new()` object the way [[Arena Rounds with Teams and Spectating End to End]] does for arenas.

### When not to build it this way
- **Fewer than about 30 enemies alive, ever.** A slow, boss-heavy "defense" game with a dozen Humanoid enemies can use real NPCs and [[Pathfinding]]; the data pattern is extra complexity you do not need (rule of thumb: measure before choosing).
- **Enemies that leave the path** (flanking, flying anywhere, physics knockback into pits). Then position is no longer a function of distance, and you need real agents with a budget, as in [[Behaviour Trees Utility AI and State Machines for NPCs]].

---

## 2. Folder layout

```
ReplicatedStorage
  Shared (Folder)
    Net (ModuleScript)          -- from Saved Inventory End to End
    PathMath (ModuleScript)     -- from Genre Playbook - Tower Defense, plus distanceToPath below
    TDConfig (ModuleScript)
  EnemyModels (Folder)          -- client-only visuals, one Model per enemy type, PrimaryPart set
  TowerModels (Folder)          -- one Model per tower type, PrimaryPart set
ServerScriptService
  Server (Folder)
    Main (Script)               -- add "MatchService" to ORDER
    PlayerData, DataTemplate, RateLimiter (ModuleScripts)
    Services (Folder)
      MatchService (ModuleScript)
Workspace
  Map (Model)
    Path (Folder)               -- Parts named 1, 2, 3 ... marking waypoints
    Bounds (Part, anchored, invisible, CanCollide false): placement must be inside it
    Ground parts tagged "Placeable"
  Towers (Folder)               -- created by the server
StarterPlayer/StarterPlayerScripts/Client
  TDClient (LocalScript)
```

`EnemyModels` lives in `ReplicatedStorage` on purpose: these models are visual only, the server never parents them to `Workspace`, and every client needs them. Towers, by contrast, are created by the server in `Workspace.Towers` because their existence is game state everyone must agree on, and there are at most a few dozen of them.

---

## 3. Data

### 3.1 TDConfig

```lua
--!strict
-- ReplicatedStorage/Shared/TDConfig (ModuleScript). Reviewed, not run.
export type TowerLevel = { Damage: number, Range: number, FireRate: number, Cost: number, Slow: number? }
export type TowerDef = { Footprint: number, Levels: { TowerLevel } }
export type EnemyDef = { Health: number, Speed: number, Reward: number }
export type WaveGroup = { Enemy: string, Count: number, Interval: number, Delay: number }

local TDConfig = {}

TDConfig.StartCash = 600
TDConfig.Lives = 20
TDConfig.MaxTowersPerPlayer = 20
TDConfig.PathClearance = 2.5     -- studs between the path centre line and a tower footprint
TDConfig.TargetHz = 10           -- targeting passes per second
TDConfig.SellRefund = 0.6
TDConfig.BetweenWaves = 12       -- seconds, unless the skip vote passes

TDConfig.Towers = {
	Scout = { Footprint = 1.5, Levels = {
		{ Damage = 6, Range = 14, FireRate = 1.5, Cost = 200 },
		{ Damage = 10, Range = 15, FireRate = 1.8, Cost = 250 },
		{ Damage = 18, Range = 17, FireRate = 2.0, Cost = 600 },
	} },
	Frost = { Footprint = 1.5, Levels = {
		{ Damage = 2, Range = 12, FireRate = 1.0, Cost = 350, Slow = 0.5 },
		{ Damage = 4, Range = 13, FireRate = 1.2, Cost = 400, Slow = 0.4 },
	} },
} :: { [string]: TowerDef }

TDConfig.Enemies = {
	Runner = { Health = 20, Speed = 8, Reward = 6 },
	Brute = { Health = 160, Speed = 4, Reward = 20 },
	Swarm = { Health = 8, Speed = 10, Reward = 2 },
} :: { [string]: EnemyDef }

TDConfig.Waves = {
	{ { Enemy = "Runner", Count = 8, Interval = 1.0, Delay = 0 } },
	{ { Enemy = "Runner", Count = 12, Interval = 0.8, Delay = 0 }, { Enemy = "Brute", Count = 2, Interval = 3, Delay = 6 } },
	{ { Enemy = "Swarm", Count = 30, Interval = 0.25, Delay = 0 }, { Enemy = "Brute", Count = 4, Interval = 2, Delay = 4 } },
} :: { { WaveGroup } }

-- Health scales per wave so the table above can be reused for long modes.
function TDConfig.healthScale(wave: number): number
	return 1.12 ^ (wave - 1)
end

return TDConfig
```

### 3.2 One addition to PathMath

Placement needs "how far is this point from the path". Add this to the playbook's `PathMath` module; it uses the same `Path` type.

```lua
-- Add to ReplicatedStorage/Shared/PathMath. Reviewed, not run.
-- Shortest horizontal distance from a point to the path polyline (Y ignored: towers sit beside, not above).
function PathMath.distanceToPath(path: Path, point: Vector3): number
	local best = math.huge
	local p = Vector3.new(point.X, 0, point.Z)
	for i = 1, #path.points - 1 do
		local a = path.points[i] * Vector3.new(1, 0, 1)
		local b = path.points[i + 1] * Vector3.new(1, 0, 1)
		local ab = b - a
		local lengthSquared = ab:Dot(ab)
		local t = if lengthSquared > 0 then math.clamp((p - a):Dot(ab) / lengthSquared, 0, 1) else 0
		best = math.min(best, (p - (a + ab * t)).Magnitude)
	end
	return best
end
```

For a path of 40 points this is 40 dot products per placement request. Placement is rare (a few per minute per player), so no spatial index is needed. See [[Intersection and Collision Math]] for the derivation.

### 3.3 Profile fields

```lua
-- In DataTemplate (Saved Inventory End to End): add to the Data type
	TD: { Gems: number, XP: number, BestWave: number, Matches: number, Loadout: { string } },
-- and to DataTemplate.new()
		TD = { Gems = 0, XP = 0, BestWave = 0, Matches = 0, Loadout = { "Scout", "Frost" } },
```

`Loadout` is an array in the template with content in it. `reconcile` recurses into non-empty template tables, which for an array means it fills missing indices from the default; a player who saved a loadout of one tower would get "Frost" added at index 2. If that matters for your design, store the loadout as a map (`{ [slot]: towerName }` with string keys) or exclude it in `reconcile`. This is the kind of quiet behaviour worth knowing before launch ([[Data Schema Design and Migrations]]).

---

## 4. The server: MatchService

```lua
--!strict
-- ServerScriptService/Server/Services/MatchService (ModuleScript). Reviewed, not run.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local PathMath = require(ReplicatedStorage.Shared.PathMath)
local TDConfig = require(ReplicatedStorage.Shared.TDConfig)
local PlayerData = require(script.Parent.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

type Enemy = {
	Id: number, Type: string, Health: number, MaxHealth: number,
	Distance: number, Speed: number, SlowFactor: number, SlowUntil: number,
}
type Tower = {
	Uid: number, Owner: Player, Type: string, Level: number,
	Position: Vector3, NextShot: number, Spent: number, Model: Model,
}
type Event = { K: string, Id: number, Ty: string?, T: number?, D: number?, V: number? }

local MatchService = {}

local path: PathMath.Path
local boundsCFrame: CFrame
local boundsSize: Vector3
local enemies: { Enemy } = {}
local towers: { [number]: Tower } = {}
local nextEnemyId = 0
local nextTowerUid = 0
local lives = TDConfig.Lives
local wave = 0
local state: "Waiting" | "Wave" | "Between" | "Ended" = "Waiting"
local skipVotes: { [Player]: boolean } = {}
local rewarded: { [Player]: boolean } = {}
local pending: { Event } = {}

local eventsRemote: RemoteEvent
local correctRemote: UnreliableRemoteEvent
local firedRemote: UnreliableRemoteEvent

local allowPlace = RateLimiter.new(4, 2)
local allowManage = RateLimiter.new(6, 3)

-- Cash -------------------------------------------------------------------------------
local function cashOf(player: Player): number
	return (player:GetAttribute("Cash") :: number?) or 0
end
local function addCash(player: Player, amount: number)
	player:SetAttribute("Cash", cashOf(player) + amount)
end

-- Events -------------------------------------------------------------------------------
local function queue(event: Event)
	table.insert(pending, event)
end

local function setState(newState: "Waiting" | "Wave" | "Between" | "Ended", endsAt: number?)
	state = newState
	workspace:SetAttribute("TDState", newState)
	workspace:SetAttribute("TDWave", wave)
	workspace:SetAttribute("TDLives", lives)
	workspace:SetAttribute("TDEndsAt", endsAt or 0)
end

-- Enemies ------------------------------------------------------------------------------
local function spawnEnemy(typeName: string)
	local def = TDConfig.Enemies[typeName]
	if not def then
		return
	end
	nextEnemyId += 1
	local health = def.Health * TDConfig.healthScale(wave)
	local enemy: Enemy = {
		Id = nextEnemyId, Type = typeName, Health = health, MaxHealth = health,
		Distance = 0, Speed = def.Speed, SlowFactor = 1, SlowUntil = 0,
	}
	table.insert(enemies, enemy)
	queue({ K = "S", Id = enemy.Id, Ty = typeName, T = workspace:GetServerTimeNow(), D = 0, V = def.Speed })
end

local function sendCorrection(enemy: Enemy)
	-- Unreliable: a lost correction is replaced by the next one. Small payload, well under 1,000 bytes.
	correctRemote:FireAllClients(enemy.Id, enemy.Distance, enemy.Speed * enemy.SlowFactor, workspace:GetServerTimeNow())
end

local function killEnemy(index: number, leaked: boolean)
	local enemy = enemies[index]
	-- Swap-remove: order does not matter, O(1) instead of shifting the array.
	enemies[index] = enemies[#enemies]
	enemies[#enemies] = nil
	queue({ K = if leaked then "L" else "D", Id = enemy.Id })
	if leaked then
		lives = math.max(0, lives - 1)
		workspace:SetAttribute("TDLives", lives)
	else
		local reward = TDConfig.Enemies[enemy.Type].Reward
		for _, player in Players:GetPlayers() do
			addCash(player, reward) -- shared rewards: nobody steals kills from teammates
		end
	end
end

-- Simulation: called every Heartbeat -----------------------------------------------------
local targetAccumulator = 0

local function step(dt: number)
	if state ~= "Wave" and state ~= "Between" then
		return
	end
	local now = os.clock()

	-- 1. Move. Iterate backwards because killEnemy swap-removes.
	for i = #enemies, 1, -1 do
		local enemy = enemies[i]
		if enemy.SlowFactor < 1 and now >= enemy.SlowUntil then
			enemy.SlowFactor = 1
			sendCorrection(enemy)
		end
		enemy.Distance += enemy.Speed * enemy.SlowFactor * dt
		if enemy.Distance >= path.length then
			killEnemy(i, true)
		end
	end

	-- 2. Target and shoot at a fixed rate, not every frame.
	targetAccumulator += dt
	local interval = 1 / TDConfig.TargetHz
	if targetAccumulator >= interval then
		targetAccumulator -= interval
		for _, tower in towers do
			if now < tower.NextShot then
				continue
			end
			local stats = TDConfig.Towers[tower.Type].Levels[tower.Level]
			local rangeSquared = stats.Range * stats.Range
			local bestIndex: number? = nil
			local bestDistance = -1
			for i, enemy in enemies do
				local offset = PathMath.positionAt(path, enemy.Distance) - tower.Position
				-- "First" targeting: the enemy furthest along the path within range.
				if offset:Dot(offset) <= rangeSquared and enemy.Distance > bestDistance then
					bestIndex, bestDistance = i, enemy.Distance
				end
			end
			if bestIndex then
				local enemy = enemies[bestIndex]
				tower.NextShot = now + 1 / stats.FireRate
				firedRemote:FireAllClients(tower.Uid, enemy.Id)
				if stats.Slow and enemy.SlowFactor > stats.Slow then
					enemy.SlowFactor = stats.Slow
					enemy.SlowUntil = now + 2
					sendCorrection(enemy)
				end
				enemy.Health -= stats.Damage
				if enemy.Health <= 0 then
					killEnemy(bestIndex, false)
				end
			end
		end
	end

	-- 3. Flush one reliable batch per tick.
	if #pending > 0 then
		eventsRemote:FireAllClients(pending)
		pending = {}
	end
end

-- Placement ------------------------------------------------------------------------------
local function insideBounds(position: Vector3): boolean
	local localPoint = boundsCFrame:PointToObjectSpace(position)
	local half = boundsSize / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z
end

local function towerCount(player: Player): number
	local n = 0
	for _, tower in towers do
		if tower.Owner == player then
			n += 1
		end
	end
	return n
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function place(player: Player, typeName: unknown, position: unknown, yaw: unknown): string
	-- 1. Types, before anything touches the values.
	if type(typeName) ~= "string" or typeof(position) ~= "Vector3" or type(yaw) ~= "number" then
		return "bad args"
	end
	-- 2. NaN and infinity: NaN fails every comparison, so it slips past range checks unless caught.
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z or yaw ~= yaw then
		return "bad number"
	end
	-- 3. Match state.
	if state ~= "Wave" and state ~= "Between" then
		return "not running"
	end
	-- 4. Tower exists and is in this player's saved loadout.
	local def = TDConfig.Towers[typeName]
	local profile = PlayerData.Get(player)
	if not def or not profile or not table.find(profile.Data.TD.Loadout, typeName) then
		return "not equipped"
	end
	-- 5. Cash and cap.
	local cost = def.Levels[1].Cost
	if cashOf(player) < cost then
		return "poor"
	end
	if towerCount(player) >= TDConfig.MaxTowersPerPlayer then
		return "cap"
	end
	-- 6. Bounds.
	if not insideBounds(position) then
		return "out of bounds"
	end
	-- 7. Clear of the path and of other towers.
	if PathMath.distanceToPath(path, position) < TDConfig.PathClearance + def.Footprint then
		return "on path"
	end
	for _, other in towers do
		local otherFootprint = TDConfig.Towers[other.Type].Footprint
		local flat = (other.Position - position) * Vector3.new(1, 0, 1)
		if flat.Magnitude < def.Footprint + otherFootprint then
			return "overlap"
		end
	end
	-- 8. Ground: the server casts its own ray; the client's Y is only a hint.
	groundParams.FilterDescendantsInstances = { workspace:FindFirstChild("Towers") :: Instance }
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), groundParams)
	if not hit or not CollectionService:HasTag(hit.Instance, "Placeable") then
		return "not placeable"
	end

	-- All checks passed: charge, then create.
	addCash(player, -cost)
	nextTowerUid += 1
	local template = ReplicatedStorage:FindFirstChild("TowerModels")
	local source = if template then template:FindFirstChild(typeName) else nil
	local model = if source and source:IsA("Model") then source:Clone() else Instance.new("Model")
	local snapped = math.round(yaw / 15) * 15 -- 15 degree steps; arbitrary angles look messy
	model:PivotTo(CFrame.new(hit.Position) * CFrame.Angles(0, math.rad(snapped), 0))
	model.Name = tostring(nextTowerUid)
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Type", typeName)
	model:SetAttribute("Level", 1)
	model.Parent = workspace:FindFirstChild("Towers")
	towers[nextTowerUid] = {
		Uid = nextTowerUid, Owner = player, Type = typeName, Level = 1,
		Position = hit.Position, NextShot = 0, Spent = cost, Model = model,
	}
	return "ok"
end

local function upgrade(player: Player, uid: unknown)
	if type(uid) ~= "number" then return end
	local tower = towers[uid]
	if not tower or tower.Owner ~= player then return end
	local levels = TDConfig.Towers[tower.Type].Levels
	local nextLevel = levels[tower.Level + 1]
	if not nextLevel or cashOf(player) < nextLevel.Cost then return end
	addCash(player, -nextLevel.Cost)
	tower.Level += 1
	tower.Spent += nextLevel.Cost
	tower.Model:SetAttribute("Level", tower.Level)
end

local function sell(player: Player, uid: unknown)
	if type(uid) ~= "number" then return end
	local tower = towers[uid]
	if not tower or tower.Owner ~= player then return end
	towers[uid] = nil
	tower.Model:Destroy()
	addCash(player, math.floor(tower.Spent * TDConfig.SellRefund))
end

-- Results ---------------------------------------------------------------------------------
local function reward(player: Player, wavesCleared: number, won: boolean)
	if rewarded[player] then
		return -- exactly once per player per match, even if this runs from two paths
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	rewarded[player] = true
	local td = profile.Data.TD
	td.Gems += wavesCleared * 5 + (if won then 50 else 0)
	td.XP += wavesCleared * 20
	td.Matches += 1
	td.BestWave = math.max(td.BestWave, wavesCleared)
	task.spawn(PlayerData.SaveNowAsync, player)
end

local function endMatch(won: boolean)
	setState("Ended")
	local cleared = if won then wave else wave - 1
	for _, player in Players:GetPlayers() do
		reward(player, cleared, won)
	end
	-- Next step in a real game: teleport everyone back to the lobby place (Teleporting and Multi-Place Games).
end

-- Wave runner -----------------------------------------------------------------------------
local function runWaves()
	for index, groups in TDConfig.Waves do
		wave = index
		setState("Wave")
		local spawners = 0
		for _, group in groups do
			spawners += 1
			task.spawn(function()
				task.wait(group.Delay)
				for _ = 1, group.Count do
					if state == "Ended" then break end
					spawnEnemy(group.Enemy)
					task.wait(group.Interval)
				end
				spawners -= 1
			end)
		end
		-- The wave ends when every group finished spawning and every enemy is gone.
		while state ~= "Ended" and (spawners > 0 or #enemies > 0) do
			if lives <= 0 then
				endMatch(false)
				return
			end
			task.wait(0.25)
		end
		if state == "Ended" then return end
		if index == #TDConfig.Waves then
			endMatch(true)
			return
		end
		table.clear(skipVotes)
		local endsAt = workspace:GetServerTimeNow() + TDConfig.BetweenWaves
		setState("Between", endsAt)
		while workspace:GetServerTimeNow() < endsAt do
			local votes, total = 0, #Players:GetPlayers()
			for _ in skipVotes do votes += 1 end
			if total > 0 and votes * 2 > total then break end -- strict majority
			task.wait(0.25)
		end
	end
end

function MatchService.Start()
	local map = workspace:WaitForChild("Map")
	local points: { Vector3 } = {}
	local pathFolder = map:WaitForChild("Path")
	for i = 1, #pathFolder:GetChildren() do
		local node = pathFolder:FindFirstChild(tostring(i))
		assert(node and node:IsA("BasePart"), `Path node {i} missing`)
		table.insert(points, node.Position)
	end
	path = PathMath.build(points)
	local bounds = map:WaitForChild("Bounds") :: BasePart
	boundsCFrame, boundsSize = bounds.CFrame, bounds.Size

	local towersFolder = Instance.new("Folder")
	towersFolder.Name = "Towers"
	towersFolder.Parent = workspace

	eventsRemote = Net.Event("TDEvents")
	-- Net in Saved Inventory makes RemoteEvents only; create the unreliable ones here.
	local function unreliable(name: string): UnreliableRemoteEvent
		local remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = name
		remote.Parent = eventsRemote.Parent
		return remote
	end
	correctRemote = unreliable("TDCorrect")
	firedRemote = unreliable("TDFired")

	local placeResult = Net.Event("TDPlaceResult")
	Net.Event("TDPlace").OnServerEvent:Connect(function(player: Player, typeName: unknown, position: unknown, yaw: unknown)
		if allowPlace(player) then
			placeResult:FireClient(player, place(player, typeName, position, yaw))
		end
	end)
	Net.Event("TDUpgrade").OnServerEvent:Connect(function(player: Player, uid: unknown)
		if allowManage(player) then upgrade(player, uid) end
	end)
	Net.Event("TDSell").OnServerEvent:Connect(function(player: Player, uid: unknown)
		if allowManage(player) then sell(player, uid) end
	end)
	Net.Event("TDSkip").OnServerEvent:Connect(function(player: Player)
		if state == "Between" then skipVotes[player] = true end
	end)

	PlayerData.OnLoaded(function(profile)
		profile.Player:SetAttribute("Cash", TDConfig.StartCash)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		skipVotes[player] = nil
		-- Partial reward for the waves they saw; written into the profile before it saves.
		if state ~= "Waiting" and state ~= "Ended" then
			reward(player, math.max(0, wave - 1), false)
		end
		for uid, tower in towers do
			if tower.Owner == player then
				towers[uid] = nil
				tower.Model:Destroy()
			end
		end
	end)

	RunService.Heartbeat:Connect(step)

	task.spawn(function()
		-- Wait for the party: everyone the lobby sent, or 20 s, whichever comes first.
		local deadline = os.clock() + 20
		while #Players:GetPlayers() == 0 or (os.clock() < deadline and workspace:GetAttribute("ExpectedPlayers") ~= #Players:GetPlayers()) do
			task.wait(0.5)
		end
		runWaves()
	end)
end

return MatchService
```

### 4.1 The decisions that matter

**Who sets `ExpectedPlayers`.** The lobby knows the party size when it teleports. Pass it in the teleport data, and have the first arriving player's join handler copy it onto `workspace` (server side, validated as a small integer). Without it, the match waits the full 20 seconds, which is acceptable as a fallback but feels slow for a solo player.

**Tick order is move, then target, then flush.** Targeting after movement means a tower never shoots at a position the enemy left this frame. Flushing last means a spawn and a death in the same tick arrive in the same batch in the right order; the client processes the array in order, so it never receives "died" for an id it has not seen.

**Swap-remove inside a backwards loop.** `killEnemy` moves the last element into the hole. Iterating from the end means the moved element was already processed this tick. In the targeting pass the loop is forward but at most one kill happens per tower per pass and the loop over enemies has already finished by then, so the swap is safe.

**`PathMath.positionAt` per enemy per tower per pass.** With 20 towers, 300 enemies and 10 passes per second that is 60,000 position lookups per second, each a short binary search. That is affordable in Luau but it is the first thing to optimise: compute every enemy's position once per targeting pass into an array, then let all towers read it. Measure with the [[MicroProfiler Guide]] before and after; the playbook's 4 ms Heartbeat target is the budget (rule of thumb).

**The leaked-player reward.** `PlayerRemoving` writes the partial reward into the profile, but the profile module saves on the same signal, and the engine does not promise which connection runs first. If the profile handler runs first, it removes the profile (so `PlayerData.Get` returns nil and the reward is skipped) or serialises before the write. The save call yields, so a write that lands before the `UpdateAsync` callback serialises often makes it in. "Often" is not good enough for currency; if the partial reward matters, have `PlayerData` expose a `BeforeRelease(callback)` hook that runs synchronously before it serialises, and grant there. This is the general rule from [[Genre Systems Start Here]]: write into the profile at the moment of change, and for leave-time writes, use a hook the save path calls.

**Reliable versus unreliable.** Spawns, deaths and leaks are reliable (losing one creates a ghost). Corrections and "tower fired" are unreliable: the next correction replaces a lost one, and a missed muzzle flash is invisible. Roblox docs (as of October 2026) say unreliable messages give no ordering guarantee and may be dropped when the payload exceeds 1,000 bytes, which is why each correction carries its own server time and is sent per enemy rather than batched into one large array.

**Batch size.** A wave of 30 swarm enemies at 0.25 s intervals spawns about one enemy per 15 frames, so batches are tiny. A boss that splits into 40 children in one frame produces one batch of 40 small dictionaries, a few kilobytes. If your design does that often, pack the batch into a `buffer` ([[Buffers and Binary Data]]).

---

## 5. The client: TDClient

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/Client/TDClient (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local PathMath = require(ReplicatedStorage.Shared.PathMath)

local player = Players.LocalPlayer
local remotesFolder = Net.Event("TDEvents").Parent :: Instance
local correctRemote = remotesFolder:WaitForChild("TDCorrect") :: UnreliableRemoteEvent
local placeRemote = Net.Event("TDPlace")

local map = workspace:WaitForChild("Map")
local pathFolder = map:WaitForChild("Path")
local points: { Vector3 } = {}
for i = 1, #pathFolder:GetChildren() do
	table.insert(points, (pathFolder:WaitForChild(tostring(i)) :: BasePart).Position)
end
local path = PathMath.build(points)

type Rendered = { Model: Model, Type: string, Distance: number, Speed: number }
local rendered: { [number]: Rendered } = {}
local pools: { [string]: { Model } } = {}
local visuals = Instance.new("Folder")
visuals.Name = "EnemyVisuals"
visuals.Parent = workspace

local function take(typeName: string): Model?
	local pool = pools[typeName]
	local model = pool and table.remove(pool)
	if model then
		return model
	end
	local source = ReplicatedStorage.EnemyModels:FindFirstChild(typeName)
	return if source and source:IsA("Model") then source:Clone() else nil
end

local function give(entry: Rendered)
	entry.Model.Parent = nil
	pools[entry.Type] = pools[entry.Type] or {}
	table.insert(pools[entry.Type], entry.Model)
end

Net.Event("TDEvents").OnClientEvent:Connect(function(batch: { any })
	local now = workspace:GetServerTimeNow()
	for _, event in batch do
		if event.K == "S" then
			local model = take(event.Ty)
			if model then
				-- Extrapolate: the spawn happened (now - T) seconds ago on the server.
				local distance = event.D + (now - event.T) * event.V
				rendered[event.Id] = { Model = model, Type = event.Ty, Distance = distance, Speed = event.V }
				model.Parent = visuals
			end
		else -- "D" died or "L" leaked
			local entry = rendered[event.Id]
			if entry then
				rendered[event.Id] = nil
				give(entry)
			end
		end
	end
end)

correctRemote.OnClientEvent:Connect(function(id: number, distance: number, speed: number, at: number)
	local entry = rendered[id]
	if entry then
		entry.Distance = distance + (workspace:GetServerTimeNow() - at) * speed
		entry.Speed = speed
	end
end)

RunService.PreRender:Connect(function(dt: number)
	for _, entry in rendered do
		entry.Distance += entry.Speed * dt
		local position = PathMath.positionAt(path, entry.Distance)
		local ahead = PathMath.positionAt(path, entry.Distance + 0.5)
		if (ahead - position).Magnitude > 1e-3 then
			entry.Model:PivotTo(CFrame.lookAt(position, ahead))
		end
	end
end)

-- Placement: click to place the first loadout tower. A real game adds a ghost preview
-- coloured by a client-side copy of checks 6 to 8, purely as a hint.
local selectedTower = "Scout"
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { visuals }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if hit then
		placeRemote:FireServer(selectedTower, hit.Position, 0)
	end
end)

Net.Event("TDPlaceResult").OnClientEvent:Connect(function(result: string)
	if result ~= "ok" then
		print("Cannot place:", result) -- show a toast instead (Notification and Toast Systems)
	end
end)
```

Two subtleties. First, the raycast filter is rebuilt on every click because the character can be nil (between death and respawn) and a stale character reference filters nothing. Second, the client never removes an enemy because its own distance passed the end of the path: it waits for the server's "L". Otherwise a slightly fast client hides an enemy that the server is about to kill just short of the exit, and players see a leak that did not happen.

For tower visuals, listen to `TDFired` and play a muzzle flash and a projectile that homes onto the client's rendered model, as the playbook says. Keep a per-client VFX budget ([[VFX Performance Budgets and Culling]]).

---

## 5.1 Checking the numbers before the first playtest

Because every enemy and tower is data, you can test balance with arithmetic before you build a single map. Two numbers per wave decide most outcomes (rule of thumb, the same framing the playbook uses):

- **Incoming health per second** for a wave: for each group, `Count * Health * healthScale(wave) / (Count * Interval)` while that group is spawning. Wave 3 above has a swarm group of 30 enemies at 8 health (about 10 after the wave 3 scale of 1.25) every 0.25 s, which is 40 health per second, plus brutes at 160 x 1.25 = 200 health every 2 s, about 100 per second. Peak incoming is roughly 140 health per second while both groups overlap.
- **Achievable damage per second** at a cash level: a level 1 Scout does 6 x 1.5 = 9 DPS for 200 cash, so 0.045 DPS per cash. A level 3 Scout has cost 1,050 in total and does 36 DPS, about 0.034 DPS per cash. Upgrades are worse value than new towers here, which is a deliberate choice only if tower slots (the cap of 20) are the real constraint. If you want upgrades to feel good, make the late levels better value per cash, not worse.

Then account for **time in range**. An enemy walking at speed 8 past a Scout with range 14 spends at most `2 * 14 / 8 = 3.5` seconds in range if the path passes straight through the tower's centre, far less if it clips the edge. A tower's effective damage on one enemy is DPS times time in range, which is why corners (where the path wraps around a tower) are worth more than straights and why slows multiply the value of every other tower: a 0.5 slow doubles time in range for everything nearby.

A wave is beatable at a given cash level when achievable DPS times average time in range exceeds the health that must pass each tower cluster. Put these columns in a sheet ([[Balancing with Spreadsheets and Data]]) and the wave where a new player with starting cash and kill income first fails becomes a number you choose, not a surprise you discover in reviews. Then playtest anyway: placement skill moves the result a lot, and swarm waves punish single-target towers in ways a DPS sum hides.

Two traps the arithmetic catches early. First, **health scaling against reward**: with `healthScale = 1.12^(wave-1)` and flat rewards, wave 20 enemies have 8.6 times the health and pay the same, so the economy tightens steadily, which is usually what you want for a finite mode and a disaster for an endless one (scale rewards by a slower curve there). Second, **overkill**: a tower that does 18 damage to 8-health swarm enemies wastes over half its output, so mixed waves need a splash or multi-target tower in the roster or they become unwinnable at a DPS total that looks sufficient.

---

## 6. Common mistakes

- **Trusting the client's ground position.** Without check 8, an exploiter places a tower floating over the path at Y = 1000 with a range that reaches everything. The server raycast replaces the client's Y.
- **No NaN check.** `NaN < limit` is false and `NaN > limit` is false, so a NaN position passes many naive "is it too far" checks. Check 2 exists for that.
- **Rewarding in the wave loop and in `PlayerRemoving` without a guard.** A player who leaves during the final wave's last tick gets paid twice. The `rewarded` set prevents it.
- **Giving every player per-player cash from kills by "last hit".** It turns cooperative players into rivals and encourages tower spam on the exit. Shared rewards are the genre norm.
- **Running targeting every Heartbeat.** 60 passes per second for towers that fire once a second triples cost for nothing.
- **Forgetting enemies can die from damage and leak in the same tick.** The ordering above (move and leak first, then target) means a leaked enemy is gone before towers look; reverse it and a tower can shoot an enemy that already cost a life.

---

## 7. Extending it

- **Speed toggle (2x).** Multiply `dt` in `step` by a match time scale and send the scale as a workspace attribute; clients multiply their own `dt`. Wave timers must use the same scale.
- **Status effects beyond slow.** Burns, stuns and armour shred follow the same pattern: change state on the server, send a correction when movement speed changes. Stacking rules are in [[Status Effects Buffs and Stacking Rules]].
- **Targeting modes** (first, last, strongest, closest) are a per-tower attribute and a different comparison in the inner loop.
- **Bosses with abilities** that disable towers: model as a server event the client renders, same as a death. See [[Boss Fight Design Patterns]].

---

## 8. Test checklist

- [ ] Solo match: three waves run, cash increases on kills, lives drop on leaks, match ends with a reward saved once.
- [ ] Place on the path, outside bounds, on an untagged roof, overlapping another tower, with no cash, past the cap: each returns its reason.
- [ ] Fire `TDPlace` with NaN, a huge vector, a number instead of a string, and a tower not in the loadout.
- [ ] Two clients: enemies line up on both screens within a stud or so; slowed enemies stay aligned after the slow ends.
- [ ] Network emulation at 300 ms latency ([[Multi-Client and Device Playtesting Protocols]]): enemies still move smoothly; no ghosts after deaths.
- [ ] Leave mid-wave: towers removed, partial reward saved, no double reward at match end.
- [ ] Worst wave on a full server: server Heartbeat time and incoming bandwidth per client recorded ([[Network Bandwidth Budgets and Measuring Them]]).

## See also
- [[Genre Playbook - Tower Defense]], [[Genre Systems Start Here]], [[Worked Builds Start Here]]
- [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Server Authority and Validation]], [[Remote Abuse Patterns and Rate Limiting in Practice]]
- [[Grid Placement and Player Building Systems]], [[Teleporting and Multi-Place Games]], [[Saved Inventory End to End]]

## Connected notes
<!-- auto-links:start -->
[[Genre Playbook - Combat and RPG]] · [[Power Curve]] · [[Tycoon Plots and Droppers End to End]] · [[Interest Management and Per-Player Replication]] · [[Round-Based Minigame Loop End to End]] · [[Genre Playbook - Shooters FPS and TPS]]
<!-- auto-links:end -->
