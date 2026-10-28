---
tags: [genre-system, horror, npc-ai, pathfinding, worked-build, server-authority, luau]
---
# Horror Monster Chase AI End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Entering a locker while the monster watches.
> - Two players, one locker. The `Occupied` attribute prevents it.
> - Leaving the game while hiding. The attribute signal does not run for a player who has left, so the `Occupied` flag would stay...
> - Solo: monster patrols in order; walking past behind it is safe; sprinting nearby draws it to investigate.
> - Enter its sight cone: chase starts; break line of sight and wait: it goes to your last position, searches, returns.
> - Hide in a locker out of sight: safe. Hide while being chased in view: refused.
>
> Cost: TL;DR ~180 tok · whole note ~8.1k tok. Read more: ## 4. The server: MonsterService · ## 5. The client: MonsterClient · ## 6. Edge cases and failure modes · ## 9. Test checklist
<!-- tldr:end -->

This note builds a complete horror monster: a server-owned NPC with a five-state machine (patrol, investigate, chase, search, return), sight and hearing that the server computes from its own view of the world, a memory that lets players escape, pathfinding that recomputes on a budget and recovers when stuck, hiding spots that are fair in both directions, a catch that cannot chain-kill a group, client-side dread cues (music, heartbeat, an accessible screen-edge warning, a jumpscare), and save hooks for deaths and escapes. [[Genre Playbook - Horror and Story]] gives the design principles (fair senses, memory that decays, speed at or below sprint) and a tension director sketch; this note turns those principles into a working system and adds the failure modes that make monsters feel broken in practice.

> **All code is reviewed, not run.** Strict Luau against Roblox docs (as of October 2026), checked by reading. Run section 9 before you trust it.

Labels used: **Roblox docs (as of October 2026)**, **rule of thumb**.

---

## 1. The state machine

```
            hears noise                  sees player
  Patrol ---------------> Investigate ---------------> Chase
    ^                         |                          |
    |  reached patrol         | nothing found            | lost sight for LoseSeconds
    |                         v                          v
  Return <--------------- Search <-----------------------+
            search timer done        (goes to last known position, looks around)
```

| State | Goal | Speed (studs/s) | Exits |
|---|---|---|---|
| Patrol | Walk patrol points in order | 8 | Sees a player: Chase. Hears a noise: Investigate |
| Investigate | Walk to the noise position | 11 | Sees: Chase. Arrives: Search |
| Chase | Reach the target | 15 | Catch. Lost sight for 4 s: Search |
| Search | Walk to last known position, then pause and turn | 9 | Sees: Chase. Timer (8 s): Return |
| Return | Walk to the nearest patrol point | 8 | Arrives: Patrol. Sees: Chase |

These speeds assume a player walk speed of 12 and sprint of 18 with limited stamina (rule of thumb; tune in group playtests). The monster is faster than walking and slower than sprinting, so escapes are about stamina and route choices, which is the fairness rule from the playbook. A monster at 20 against a sprint of 18 catches everyone eventually and stops being scary within two deaths.

### When not to use this design
- **Scripted chase sequences** (a corridor where the monster always appears behind you) are animations and triggers, not AI. Use a path and a tween; AI adds randomness where you want choreography ([[Cameras and Cutscenes]]).
- **Many monsters** (a swarm of 30 zombies) need cheaper agents: shared paths, flow fields, or the data-driven approach in [[Tower Defense Waves and Placement End to End]]. This build is for one to three serious hunters.

---

## 2. Folder layout

```
ReplicatedStorage
  Shared (Folder)
    Net (ModuleScript)               -- from Saved Inventory End to End
    MonsterConfig (ModuleScript)
ServerScriptService
  Server (Folder)
    Main (Script)                    -- add "MonsterService" to ORDER
    PlayerData, DataTemplate, RateLimiter (ModuleScripts)
    Services (Folder)
      MonsterService (ModuleScript)
ServerStorage
  Monster (Model: Humanoid, HumanoidRootPart, Head, Animator)
Workspace
  PatrolPoints (Folder of Parts named 1, 2, 3 ...)
  Hiding spots: Models tagged "HideSpot", each with an Inside part and a ProximityPrompt
  Doors: parts with a PathfindingModifier (Label "Door", PassThrough true)
StarterPlayer/StarterPlayerScripts/Client
  MonsterClient (LocalScript)
```

Doors use a `PathfindingModifier` with `PassThrough` enabled so paths go through closed doors (Roblox docs (as of October 2026), "Character pathfinding": PassThrough lets paths route through a solid obstacle such as a door). The monster then opens doors as it reaches them; section 6.3 covers how.

---

## 3. Config and profile fields

```lua
--!strict
-- ReplicatedStorage/Shared/MonsterConfig (ModuleScript). Reviewed, not run.
local MonsterConfig = {}

MonsterConfig.Speeds = { Patrol = 8, Investigate = 11, Chase = 15, Search = 9, Return = 8 }
MonsterConfig.SenseHz = 5
MonsterConfig.SightRange = 70
MonsterConfig.SightCos = math.cos(math.rad(60))  -- 120 degree cone
MonsterConfig.CloseSenseRange = 8               -- "feels" players this close regardless of facing
MonsterConfig.HearWalk = 0                      -- walking makes no noise
MonsterConfig.HearSprintRange = 45              -- sprinting is heard this far
MonsterConfig.SprintSpeedThreshold = 15         -- server-observed speed that counts as sprinting
MonsterConfig.LoseSeconds = 4
MonsterConfig.SearchSeconds = 8
MonsterConfig.CatchRange = 4.5
MonsterConfig.CatchCooldown = 6                 -- seconds after a catch before the next can happen
MonsterConfig.SpawnGrace = 20                   -- no catches in the first 20 s of a round
MonsterConfig.SawHideSeconds = 2                -- seen entering a hiding spot this recently: caught
MonsterConfig.RepathSeconds = 0.5
MonsterConfig.DirectChaseRange = 20             -- with line of sight and this close, skip pathfinding

return MonsterConfig
```

```lua
-- In DataTemplate (Saved Inventory End to End): add to the Data type
	Horror: { Deaths: number, Escapes: number, Chapter: number },
-- and to DataTemplate.new()
		Horror = { Deaths = 0, Escapes = 0, Chapter = 1 },
```

---

## 4. The server: MonsterService

```lua
--!strict
-- ServerScriptService/Server/Services/MonsterService (ModuleScript). Reviewed, not run.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local MonsterConfig = require(ReplicatedStorage.Shared.MonsterConfig)
local PlayerData = require(script.Parent.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

type State = "Patrol" | "Investigate" | "Chase" | "Search" | "Return"

local MonsterService = {}

local monster: Model
local humanoid: Humanoid
local root: BasePart
local head: BasePart
local state: State = "Patrol"
local stateSince = 0
local target: Player? = nil
local lastKnown: Vector3? = nil
local lastSeenAt = 0
local goal: Vector3? = nil
local patrolPoints: { Vector3 } = {}
local patrolIndex = 1
local spawnedAt = 0
local lastCatchAt = -math.huge
local hiddenSince: { [Player]: number } = {}
local seenAt: { [Player]: number } = {}
local spotOf: { [Player]: Model } = {}
local catchRemote: RemoteEvent
local allowHide = RateLimiter.new(2, 0.5)

local path = PathfindingService:CreatePath({
	AgentRadius = 2.5,
	AgentHeight = 6,
	AgentCanJump = false,     -- a monster that hops over railings looks silly and breaks hiding fairness
	Costs = { Door = 2 },     -- doors are allowed but slightly avoided
})
local waypoints: { PathWaypoint } = {}
local waypointIndex = 0
local lastPathAt = -math.huge
local lastPathGoal: Vector3? = nil

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

-- State ---------------------------------------------------------------------------------

local function setState(newState: State)
	if newState == state then
		return
	end
	-- Escapes: a chase that ends without a catch counts for the target.
	if state == "Chase" and newState ~= "Chase" and target then
		local profile = PlayerData.Get(target)
		if profile then
			profile.Data.Horror.Escapes += 1
		end
	end
	state = newState
	stateSince = os.clock()
	humanoid.WalkSpeed = MonsterConfig.Speeds[newState]
	monster:SetAttribute("State", newState)
	monster:SetAttribute("TargetUserId", if target then target.UserId else 0)
	waypoints = {}
	waypointIndex = 0
	lastPathGoal = nil
end

-- Senses --------------------------------------------------------------------------------

local function characterParts(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local playerRoot = character:FindFirstChild("HumanoidRootPart")
	local playerHumanoid = character:FindFirstChildOfClass("Humanoid")
	if not playerRoot or not playerRoot:IsA("BasePart") or not playerHumanoid or playerHumanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, playerRoot, playerHumanoid
end

local function canSee(player: Player): boolean
	if player:GetAttribute("Hiding") == true then
		return false
	end
	local character, playerRoot = characterParts(player)
	if not character or not playerRoot then
		return false
	end
	local offset = playerRoot.Position - head.Position
	local distance = offset.Magnitude
	if distance > MonsterConfig.SightRange then
		return false
	end
	if distance > MonsterConfig.CloseSenseRange then
		local facing = head.CFrame.LookVector
		if facing:Dot(offset.Unit) < MonsterConfig.SightCos then
			return false
		end
	end
	sightParams.FilterDescendantsInstances = { monster, character }
	local hit = workspace:Raycast(head.Position, offset, sightParams)
	-- Nothing in between (the character itself is excluded): visible.
	-- Glass and thin fences should be tagged and filtered too, or the monster is blind through windows.
	return hit == nil
end

local function bestVisible(): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		if canSee(player) then
			local _, playerRoot = characterParts(player)
			if playerRoot then
				local d = (playerRoot.Position - root.Position).Magnitude
				seenAt[player] = os.clock()
				-- Stickiness: keep the current target unless another is much closer.
				if player == target then
					d *= 0.6
				end
				if d < bestDistance then
					best, bestDistance = player, d
				end
			end
		end
	end
	return best
end

local function loudestNoise(): Vector3?
	-- Hearing is inferred on the server from replicated velocity. No client "I made noise" remote.
	local best: Vector3? = nil
	local bestScore = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Hiding") ~= true then
			local _, playerRoot = characterParts(player)
			if playerRoot then
				local speed = (playerRoot.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
				local distance = (playerRoot.Position - root.Position).Magnitude
				if speed >= MonsterConfig.SprintSpeedThreshold and distance <= MonsterConfig.HearSprintRange then
					local score = 1 - distance / MonsterConfig.HearSprintRange
					if score > bestScore then
						best, bestScore = playerRoot.Position, score
					end
				end
			end
		end
	end
	return best
end

-- Movement ------------------------------------------------------------------------------

local function moveDirect(position: Vector3)
	waypoints = {}
	waypointIndex = 0
	humanoid:MoveTo(position)
end

local function moveVia(position: Vector3)
	local now = os.clock()
	local goalMoved = lastPathGoal == nil or (lastPathGoal - position).Magnitude > 4
	if now - lastPathAt < MonsterConfig.RepathSeconds or (not goalMoved and waypointIndex > 0) then
		return
	end
	lastPathAt = now
	lastPathGoal = position
	local ok = pcall(function()
		path:ComputeAsync(root.Position, position)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		waypoints = path:GetWaypoints()
		waypointIndex = math.min(2, #waypoints) -- index 1 is where we stand
		if waypointIndex > 0 then
			humanoid:MoveTo(waypoints[waypointIndex].Position)
		end
	else
		-- No path (target on a ledge, inside geometry). Walk straight and let stuck recovery handle it.
		moveDirect(position)
	end
end

local function advanceWaypoint()
	if waypointIndex > 0 and waypointIndex < #waypoints then
		waypointIndex += 1
		humanoid:MoveTo(waypoints[waypointIndex].Position)
	else
		waypoints = {}
		waypointIndex = 0
	end
end

local function nearestPatrolIndex(): number
	local best, bestDistance = 1, math.huge
	for i, point in patrolPoints do
		local d = (point - root.Position).Magnitude
		if d < bestDistance then
			best, bestDistance = i, d
		end
	end
	return best
end

-- Stuck recovery ------------------------------------------------------------------------
local lastProgressPosition = Vector3.zero
local lastProgressAt = 0

local function checkStuck()
	if (root.Position - lastProgressPosition).Magnitude > 1.5 then
		lastProgressPosition = root.Position
		lastProgressAt = os.clock()
		return
	end
	local stuckFor = os.clock() - lastProgressAt
	if stuckFor > 1.5 and stuckFor <= 4 then
		lastPathAt = -math.huge -- force a repath next tick
		lastPathGoal = nil
	elseif stuckFor > 4 and state ~= "Chase" then
		-- Last resort, only when no player can see it: blink to the nearest patrol point.
		for _, player in Players:GetPlayers() do
			if canSee(player) then
				return
			end
		end
		monster:PivotTo(CFrame.new(patrolPoints[nearestPatrolIndex()] + Vector3.new(0, 3, 0)))
		lastProgressAt = os.clock()
		setState("Patrol")
	end
end

-- Catch ---------------------------------------------------------------------------------

local function tryCatch(player: Player)
	local now = os.clock()
	if now - spawnedAt < MonsterConfig.SpawnGrace or now - lastCatchAt < MonsterConfig.CatchCooldown then
		return
	end
	local _, playerRoot, playerHumanoid = characterParts(player)
	if not playerRoot or not playerHumanoid then
		return
	end
	if (playerRoot.Position - root.Position).Magnitude > MonsterConfig.CatchRange then
		return
	end
	lastCatchAt = now
	catchRemote:FireClient(player) -- jumpscare first, so the death reads as a catch
	task.delay(0.6, function()
		if playerHumanoid.Parent then
			playerHumanoid.Health = 0
		end
	end)
	local profile = PlayerData.Get(player)
	if profile then
		profile.Data.Horror.Deaths += 1
	end
	target = nil
	setState("Return") -- walk away; no chain kills in a group
end

-- Hiding --------------------------------------------------------------------------------

local function onHidePrompt(spot: Model, player: Player)
	if not allowHide(player) then
		return
	end
	local inside = spot:FindFirstChild("Inside")
	local character, playerRoot = characterParts(player)
	if not inside or not inside:IsA("BasePart") or not character or not playerRoot then
		return
	end
	if player:GetAttribute("Hiding") == true then
		player:SetAttribute("Hiding", false)
		hiddenSince[player] = nil
		playerRoot.Anchored = false
		character:PivotTo(inside.CFrame * CFrame.new(0, 0, -4))
		return
	end
	if spot:GetAttribute("Occupied") == true then
		return
	end
	-- Fairness both ways: hiding in view of the monster does not work.
	if os.clock() - (seenAt[player] or -math.huge) < MonsterConfig.SawHideSeconds and state == "Chase" and target == player then
		return
	end
	spot:SetAttribute("Occupied", true)
	player:SetAttribute("Hiding", true)
	hiddenSince[player] = os.clock()
	spotOf[player] = spot
	character:PivotTo(inside.CFrame)
	playerRoot.Anchored = true
	local connection: RBXScriptConnection
	connection = player:GetAttributeChangedSignal("Hiding"):Connect(function()
		if player:GetAttribute("Hiding") ~= true then
			spot:SetAttribute("Occupied", false)
			spotOf[player] = nil
			connection:Disconnect()
		end
	end)
end

-- Brain ---------------------------------------------------------------------------------

local function think()
	local now = os.clock()
	local seen = bestVisible()

	if seen then
		target = seen
		local _, playerRoot = characterParts(seen)
		if playerRoot then
			lastKnown = playerRoot.Position
			lastSeenAt = now
		end
		if state ~= "Chase" then
			setState("Chase")
		end
	end

	if state == "Patrol" or state == "Return" then
		local noise = loudestNoise()
		if noise then
			goal = noise
			setState("Investigate")
		elseif state == "Return" then
			local point = patrolPoints[patrolIndex]
			if (point - root.Position).Magnitude < 4 then
				setState("Patrol")
			else
				moveVia(point)
			end
		else
			local point = patrolPoints[patrolIndex]
			if (point - root.Position).Magnitude < 4 then
				patrolIndex = patrolIndex % #patrolPoints + 1
				point = patrolPoints[patrolIndex]
			end
			moveVia(point)
		end
	elseif state == "Investigate" then
		local noise = loudestNoise()
		if noise then
			goal = noise -- follow the latest noise, not the first one
		end
		if goal and (goal - root.Position).Magnitude < 5 then
			lastKnown = goal
			setState("Search")
		elseif goal then
			moveVia(goal)
		end
	elseif state == "Chase" then
		if target and seen == target then
			local _, playerRoot = characterParts(target)
			if playerRoot then
				local d = (playerRoot.Position - root.Position).Magnitude
				if d < MonsterConfig.DirectChaseRange then
					moveDirect(playerRoot.Position)
				else
					moveVia(playerRoot.Position)
				end
				tryCatch(target)
			end
		elseif now - lastSeenAt > MonsterConfig.LoseSeconds then
			setState("Search")
		elseif lastKnown then
			moveVia(lastKnown) -- keep going to where they were last seen
		end
	elseif state == "Search" then
		if lastKnown and (lastKnown - root.Position).Magnitude > 5 then
			moveVia(lastKnown)
		else
			-- Look around: turn a little each tick. A visible "search" sells the escape.
			root.CFrame *= CFrame.Angles(0, math.rad(25), 0)
		end
		if now - stateSince > MonsterConfig.SearchSeconds then
			target = nil
			patrolIndex = nearestPatrolIndex()
			setState("Return")
		end
	end

	checkStuck()
end

function MonsterService.Start()
	catchRemote = Net.Event("MonsterCatch")

	local folder = workspace:WaitForChild("PatrolPoints")
	for i = 1, #folder:GetChildren() do
		local part = folder:FindFirstChild(tostring(i))
		assert(part and part:IsA("BasePart"), `patrol point {i} missing`)
		table.insert(patrolPoints, part.Position)
	end

	monster = (ServerStorage:WaitForChild("Monster") :: Model):Clone()
	humanoid = monster:FindFirstChildOfClass("Humanoid") :: Humanoid
	root = monster:FindFirstChild("HumanoidRootPart") :: BasePart
	head = monster:FindFirstChild("Head") :: BasePart
	monster:PivotTo(CFrame.new(patrolPoints[1] + Vector3.new(0, 3, 0)))
	monster.Parent = workspace
	root:SetNetworkOwner(nil) -- the server simulates it: no client can drive or fling the monster
	spawnedAt = os.clock()
	humanoid.WalkSpeed = MonsterConfig.Speeds.Patrol
	monster:SetAttribute("State", "Patrol")

	humanoid.MoveToFinished:Connect(function(reached: boolean)
		if reached then
			advanceWaypoint()
		else
			lastPathAt = -math.huge -- timed out: repath on the next tick
		end
	end)
	path.Blocked:Connect(function(blockedIndex: number)
		if blockedIndex >= waypointIndex then
			lastPathAt = -math.huge
			lastPathGoal = nil
		end
	end)

	for _, spot in CollectionService:GetTagged("HideSpot") do
		local prompt = spot:FindFirstChildWhichIsA("ProximityPrompt", true)
		if spot:IsA("Model") and prompt then
			prompt.Triggered:Connect(function(player: Player)
				onHidePrompt(spot, player)
			end)
		end
	end

	-- A new character is never hidden; clearing the attribute also frees the spot.
	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Hiding", false)
		end)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	Players.PlayerRemoving:Connect(function(player: Player)
		-- The attribute signal will not fire for a leaving player, so free the spot here.
		local spot = spotOf[player]
		if spot then
			spot:SetAttribute("Occupied", false)
			spotOf[player] = nil
		end
		hiddenSince[player] = nil
		seenAt[player] = nil
		if target == player then
			target = nil
			setState("Search")
		end
	end)

	task.spawn(function()
		while monster.Parent do
			local ok, err = pcall(think)
			if not ok then
				warn("[Monster] think failed:", err)
			end
			task.wait(1 / MonsterConfig.SenseHz)
		end
	end)
end

return MonsterService
```

### 4.1 Why it is built this way

**Server ownership of the monster.** `root:SetNetworkOwner(nil)` keeps physics for the monster on the server (Roblox docs (as of October 2026), "Network ownership"). If the engine hands ownership to the nearest player, which it does automatically for unanchored assemblies, the monster stutters each time ownership moves between players, and an exploiter close to it can move it. For a single important NPC the server cost is small. See [[Network Ownership]].

**Senses at 5 Hz, not every frame.** Five sight checks per second per player is 40 raycasts per second for eight players: trivial. Running them every Heartbeat would be 480 for no visible gain, because the human reaction the monster imitates is slower than 200 ms anyway.

**Hearing is inferred on the server.** A "I sprinted" remote from the client is a remote an exploiter simply never fires. Reading the replicated `AssemblyLinearVelocity` of each player's root gives the server its own evidence. The cost is that crouch-walking or quiet footsteps must be expressed as speed: a player moving below the threshold is silent. That is usually the design you want.

**Target stickiness.** Without the 0.6 multiplier, a monster between two equidistant players flips targets every tick and runs in place. Stickiness is the cheapest fix for oscillation in any target-selection loop ([[Behaviour Trees Utility AI and State Machines for NPCs]]).

**Direct chase when close and visible.** Pathfinding introduces a delay (compute time) and waypoints spaced about 4 studs apart by default (Roblox docs (as of October 2026): `WaypointSpacing` default 4). Within 20 studs and in line of sight, `MoveTo` straight at the player is more responsive and more frightening. Further away or out of sight, paths are needed to go around walls.

**Repath on a budget.** `ComputeAsync` yields and costs real time on big maps. The monster repaths at most twice a second, and only if the goal moved more than 4 studs or the old path ran out. Blocked paths and `MoveToFinished(false)` force an early repath. `MoveTo` times out after about 8 seconds if the goal is not reached (long-standing behaviour; the current reference page shows a sample that refreshes `MoveTo` to avoid the timeout but does not state the number), and the timeout is treated as a reason to repath.

**Catch is delayed 0.6 s after the jumpscare event.** The client starts the jumpscare first, so the player sees what caught them before the death screen. Killing on the same frame makes deaths feel like lag. The `Health = 0` happens on the server, which is authoritative for the outcome.

**Catch cooldown and Return.** In a group of four, a monster that catches one player and immediately catches the next three in the same corridor ends the round in five seconds, and three players had no chance to react. After a catch, the monster walks away for at least `CatchCooldown` seconds. Groups find this fair; solo players barely notice.

---

## 5. The client: MonsterClient

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/Client/MonsterClient (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "MonsterFx"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Screen-edge warning: a visual equivalent of the heartbeat for players without audio.
local edge = Instance.new("ImageLabel")
edge.Size = UDim2.fromScale(1, 1)
edge.BackgroundTransparency = 1
edge.Image = "rbxassetid://0000000000" -- a soft red vignette texture
edge.ImageTransparency = 1
edge.Parent = gui

local heartbeat = Instance.new("Sound")
heartbeat.SoundId = "rbxassetid://0000000000"
heartbeat.Looped = true
heartbeat.Volume = 0
heartbeat.Parent = gui
heartbeat:Play()

local scare = Instance.new("ImageLabel")
scare.Size = UDim2.fromScale(1, 1)
scare.BackgroundTransparency = 1
scare.Image = "rbxassetid://0000000000"
scare.Visible = false
scare.Parent = gui

local DANGER_RANGE = 50

RunService.PreRender:Connect(function()
	local monster = workspace:FindFirstChild("Monster")
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	local monsterRoot = monster and monster:FindFirstChild("HumanoidRootPart")
	if not myRoot or not monsterRoot or not myRoot:IsA("BasePart") or not monsterRoot:IsA("BasePart") then
		heartbeat.Volume = 0
		edge.ImageTransparency = 1
		return
	end
	local distance = (myRoot.Position - monsterRoot.Position).Magnitude
	local danger = math.clamp(1 - distance / DANGER_RANGE, 0, 1)
	local chasingMe = monster:GetAttribute("State") == "Chase" and monster:GetAttribute("TargetUserId") == player.UserId
	if chasingMe then
		danger = math.max(danger, 0.6)
	end
	heartbeat.Volume = danger * 0.8
	heartbeat.PlaybackSpeed = 1 + danger * 0.6
	-- Respect a reduced-effects setting: no pulsing, a steady tint instead.
	local reduced = player:GetAttribute("ReducedEffects") == true
	local pulse = if reduced then 1 else 0.75 + 0.25 * math.sin(os.clock() * (4 + danger * 6))
	edge.ImageTransparency = 1 - danger * 0.7 * pulse
end)

Net.Event("MonsterCatch").OnClientEvent:Connect(function()
	scare.Visible = true
	scare.ImageTransparency = 0
	TweenService:Create(scare, TweenInfo.new(0.8), { ImageTransparency = 1 }):Play()
	task.delay(0.9, function()
		scare.Visible = false
	end)
end)
```

The heartbeat and the vignette are driven by distance and the replicated `State` and `TargetUserId` attributes, so they are always consistent with what the server decided. Music changes per state work the same way: listen to `monster:GetAttributeChangedSignal("State")` and crossfade ([[Music and Adaptive Audio]]). The model itself replicates normally, and its walk and run animations should be chosen from `WalkSpeed` on the server's `Animator` so all clients see the same gait ([[Animating Creatures and Monsters]]).

Keep the jumpscare short, never strobing, and behind the same reduced-effects setting as the pulse; the playbook's photosensitivity warning applies here directly ([[Accessibility]]).

---

## 6. Edge cases and failure modes

### 6.1 The monster sees through things it should not, and not through things it should
The raycast excludes only the monster and the target. Every other part blocks sight, including invisible collision boxes, trigger volumes and glass. Put non-blocking parts (triggers, glass, fences you want to see through) in a folder or tag and add them to the filter list, or set `CanQuery = false` on them so raycasts ignore them. The reverse problem: thin decorative parts (railings, chains) block sight entirely. A monster that cannot see a player behind a chain-link fence looks blind. Test sight lines in every room with a debug beam.

### 6.2 Hiding spot problems
- **Entering a locker while the monster watches.** The `SawHideSeconds` rule refuses the hide if the monster saw that player within the last 2 seconds while chasing them. Without it, lockers are invincibility buttons.
- **Two players, one locker.** The `Occupied` attribute prevents it.
- **Leaving the game while hiding.** The attribute signal does not run for a player who has left, so the `Occupied` flag would stay set forever and the locker would be dead for the rest of the server. The `spotOf` map exists only to clear it in `PlayerRemoving`. Without it, this is the first bug players find.
- **Dying or resetting while hidden.** Anchoring stops the hiding player from walking out; the exit path un-anchors. If the character is replaced instead (reset, death by another hazard), the new character is not anchored but `Hiding` would still be true, making the player invisible to the monster forever. The `CharacterAdded` handler resets `Hiding` to false, which also frees the spot through the attribute signal.

### 6.3 Doors
With `PassThrough` doors, paths go through closed doors. The monster must open them: tag door parts, and in `think`, if a door is within 4 studs ahead of the monster, call the same server door function players trigger (with a short delay so the opening is audible). If doors can be locked by players, the path must treat locked doors as blocked: switch the door's `PathfindingModifier` label to one with cost `math.huge` while locked (Roblox docs (as of October 2026): a cost of `math.huge` makes a labelled region non-traversable). Remember to repath when a door locks; the `Blocked` event only fires for obstacles that appear on the computed path ([[Pathfinding Edge Cases and Fallbacks]]).

### 6.4 Stuck recovery honesty
The blink to a patrol point only happens when no player can see the monster and it is not chasing. A visible teleport ruins the illusion; an invisible one is how every shipped horror NPC recovers. Log every blink with its position: clusters show you where your navigation mesh has holes.

### 6.5 Common mistakes
- **Letting the monster target the nearest player only.** It punishes the bravest; mixing hearing with sight rewards stealth instead (playbook, section 4).
- **Monster faster than sprint.** The scariest-sounding tuning and the worst-feeling one.
- **Pathfinding every frame.** A server-time spike every time the target moves.
- **A client "noise" remote.** Exploiters stay silent forever and can lure the monster with fake noises.
- **Forgetting `SetNetworkOwner(nil)`.** Stutter near players and an exploitable monster.

---

## 7. Numbers worth knowing

| Quantity | Value | Source |
|---|---|---|
| Path agent defaults | AgentRadius 2, AgentHeight 5, WaypointSpacing 4, AgentCanJump true | Roblox docs (as of October 2026) |
| Sense rate | 5 Hz | Rule of thumb |
| Raycasts per second | Players x SenseHz (40 for 8 players) | Arithmetic |
| Repath limit | 2 per second | Rule of thumb |
| Speeds | Monster 15 chase versus 18 sprint and 12 walk | Rule of thumb; tune in group playtests |
| Catch cooldown | 6 s | Rule of thumb |

---

## 8. Extending it

- **A director.** Feed the monster's state into the tension director from [[Genre Playbook - Horror and Story]]: the director decides when the monster is allowed to hunt (Spike) and forces it back to a far patrol during Release.
- **Several monsters.** Turn the module's locals into a `Monster.new(model)` object and share one sense pass: compute visibility of each player once per tick per monster, not per monster per state.
- **Behaviour variety.** Stalkers that only move when unseen, listeners that are blind, light-sensitive monsters: each is a different `canSee` or a different speed rule, not a new state machine.
- **Chapters.** The `Chapter` field in the profile is set when a group reaches an exit zone with objectives complete; see [[Quests and Objectives]] and [[Quest Chain System End to End]].

---

## 9. Test checklist

- [ ] Solo: monster patrols in order; walking past behind it is safe; sprinting nearby draws it to investigate.
- [ ] Enter its sight cone: chase starts; break line of sight and wait: it goes to your last position, searches, returns.
- [ ] Hide in a locker out of sight: safe. Hide while being chased in view: refused.
- [ ] Get caught: jumpscare, then death, death count saved; monster walks away; a second player next to you is not caught instantly.
- [ ] Two players equidistant: no target flicker.
- [ ] Block its path with a door locked mid-route: it repaths or searches; it does not walk into the door forever.
- [ ] Leave the game while hiding, and reset while hiding: the locker becomes usable again in both cases.
- [ ] MicroProfiler with 8 players: the think loop is a small, steady cost; no `ComputeAsync` spikes every frame.

## See also
- [[Genre Playbook - Horror and Story]], [[Genre Systems Start Here]], [[Worked Builds Start Here]]
- [[NPC AI and Behaviour]], [[Pathfinding]], [[Pathfinding Edge Cases and Fallbacks]], [[Behaviour Trees Utility AI and State Machines for NPCs]]
- [[Raycasts Shapecasts and Spatial Queries]], [[Network Ownership]], [[Spatial Audio and Mixing]], [[Accessibility]]

## Connected notes
<!-- auto-links:start -->
[[Links - Horror game mechanics]] · [[Links - Music and ambience]] · [[Links - NPCs and AI]] · [[Combat Arena and Encounter Layout]] · [[Anticipation]] · [[Level Design Start Here]]
<!-- auto-links:end -->
