---
tags: [worked-build, rounds, minigames, game-loop, server-authority, datastore, ui, luau, type/guide, area/gameplay, level/intermediate, api/GetAttributeChangedSignal]
---
# Round-Based Minigame Loop End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Counting down with one remote per second.
> - Avoid: Using `wait()` and `spawn()`. Deprecated and throttled; the code uses `task.wait`, `task.spawn` (see Task Library Coroutines...
> - Avoid: Storing maps in `ReplicatedStorage`. Every client downloads every map at join.
> - `ServerStorage.Maps` children match `RoundConfig.MapNames` exactly
> - Every map has `Spawns` (enough parts) and, for Lava Rise, a `Lava` part
> - `RoundGui.ResetOnSpawn = false`
>
> Cost: TL;DR ~160 tok · whole note ~9.0k tok. Read more: ## 4. Saving wins: PlayerStore · ## 6. The round loop: RoundService · ## 10. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

This note builds a complete round loop from an empty place: a lobby, an intermission timer, a map vote, a minigame played on a cloned map, elimination tracking, winners, saved win counts, and cleanup back to the lobby. The example minigame is "Lava Rise" (survive while lava climbs), but the loop is written so each minigame is one ModuleScript that plugs into the same contract.

It is the practical companion to [[Spawning Teams and Rounds]] (which explains the built-in objects and round theory) and [[Genre Playbook - Obbies and Platformers]] / [[Social Design and Multiplayer Play]] (why short rounds work). Start at [[Worked Builds Start Here]] for the other builds in this folder.

> **All code in this note is reviewed, not run.** It was written against Roblox docs (as of October 2026) and checked by reading, not by playing it in Studio. Test it with the steps in section 7 before shipping.

Source labels used below: **Roblox docs (as of October 2026)**, **rule of thumb**.

---

## 1. What you are building

The server runs one loop forever:

```
Waiting (not enough players)
  -> Intermission (20 s)
  -> Voting (10 s, pick a map)
  -> Playing (minigame runs until time is up or <= 1 player alive)
  -> Results (6 s, winners shown, wins saved)
  -> back to Intermission
```

Design decisions, and why:

| Decision | Choice here | Why |
|---|---|---|
| How clients learn the state | Attributes on `ReplicatedStorage` (`RoundState`, `RoundEndsAt`, `RoundMessage`) | Attributes replicate automatically, late joiners get the current value for free, no "sync me" remote needed |
| How clients show a countdown | Server sends an absolute end time from `workspace:GetServerTimeNow()`; clients count down locally | One replication per phase instead of one per second; the timer stays smooth on bad connections |
| Who decides eliminations | The server only (death, leaving, falling into lava) | Anything the client decides, an exploiter decides |
| How minigames plug in | One ModuleScript per minigame with `Start`, `Stop`, `Winners` | New modes never touch the loop |
| Where maps live | `ServerStorage.Maps` | Clients cannot see or pre-load maps they are not playing; less memory on phones |

When **not** to use this design: if your game has many concurrent arenas in one server (1v1 duel pads, for example), you want one loop object per arena, not a single global loop. Section 9 shows the change.

---

## 2. Folder layout

```
ReplicatedStorage
  Shared (Folder)
    RoundConfig (ModuleScript)
  RoundRemotes (Folder, created by the server at runtime)
    Vote (RemoteEvent)

ServerScriptService
  Modules (Folder)
    PlayerStore (ModuleScript)
  Round (Folder)
    RoundService (Script)
    Minigames (Folder)
      Types (ModuleScript)
      LavaRise (ModuleScript)

ServerStorage
  Maps (Folder)
    Volcano (Model)  -- contains Spawns (Folder of Parts) and Lava (Part)
    Factory (Model)
    Island (Model)

Workspace
  Lobby (Model with a SpawnLocation)

StarterGui
  RoundGui (ScreenGui, ResetOnSpawn = false)
    Status (TextLabel)
    Timer (TextLabel)
    VoteFrame (Frame, Visible = false)
      UIListLayout
      Template (TextButton, Visible = false)

StarterPlayer
  StarterPlayerScripts
    RoundClient (LocalScript)
```

Map building rules (rule of thumb):
- Every map Model has a `PrimaryPart` or is pivoted where you want it. Build all maps at the same far-away location (for example Y = 500, away from the lobby) so only one map exists at a time and no map overlaps the lobby.
- `Spawns` holds anchored, `CanCollide = false`, `Transparency = 1` parts. Have at least as many spawns as your max server size, or players stack on top of each other.
- `Lava` is an anchored part with `CanCollide = false` at the bottom of the map. The minigame moves it up.

Enable **Game Settings > Security > Enable Studio Access to API Services** so `PlayerStore` can save in Studio (Roblox docs).

---

## 3. Shared config

```lua
--!strict
-- ReplicatedStorage/Shared/RoundConfig (ModuleScript). Reviewed, not run.
-- Shared so the client can build vote buttons from the same map list the server validates against.
local RunService = game:GetService("RunService")

local RoundConfig = {
	-- Lets one person test the loop in Studio; live servers need 2.
	MinPlayers = if RunService:IsStudio() then 1 else 2,
	IntermissionSeconds = 20,
	VoteSeconds = 10,
	ResultsSeconds = 6,
	MaxRoundSeconds = 120,
	-- Must match the children of ServerStorage.Maps exactly.
	MapNames = { "Volcano", "Factory", "Island" },
}

return RoundConfig
```

---

## 4. Saving wins: PlayerStore

Every worked build that saves data uses the same small module: load once on join with a simple session lock, reconcile against a template, autosave, save on leave and on shutdown, and kick instead of handing out empty data when loading fails. It is deliberately smaller than a full profile library; read [[Session Locking and Profile Libraries]] for when to switch to one, and [[Saving Correctly - Autosave and BindToClose]] for the reasoning behind each line.

```lua
--!strict
-- ServerScriptService/Modules/PlayerStore (ModuleScript). Reviewed, not run.
-- One record per player, simple session lock, autosave, save on leave and shutdown.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type Data = { [string]: any }

-- A separate store in Studio so tests never touch live player data.
local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio_v1" else "PlayerData_v1"
local AUTOSAVE_SECONDS = 120
local LOCK_STALE_SECONDS = 300 -- a lock older than this is treated as abandoned (crashed server)

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles: { [Player]: Data } = {}
local template: Data = {}
local started = false
local loadedCallbacks: { (Player) -> () } = {}

local PlayerStore = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function keyFor(player: Player): string
	return "u_" .. tostring(player.UserId)
end

-- Reads the record and claims the lock in one UpdateAsync.
local function loadAsync(player: Player): Data?
	for attempt = 1, 5 do
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return store:UpdateAsync(keyFor(player), function(old: any)
				lockedElsewhere = false
				local record = if type(old) == "table" then old else {}
				local lock = record._lock
				if type(lock) == "table" and lock.job ~= game.JobId
					and os.time() - (tonumber(lock.time) or 0) < LOCK_STALE_SECONDS then
					lockedElsewhere = true
					return nil -- cancel the write: another live server still owns this record
				end
				record._lock = { job = game.JobId, time = os.time() }
				return record
			end)
		end)
		if ok and not lockedElsewhere and type(result) == "table" then
			return result :: Data
		end
		if not ok then
			warn(`PlayerStore load failed for {player.UserId} (attempt {attempt}): {result}`)
		end
		if not player.Parent then
			return nil
		end
		task.wait(attempt * 3)
	end
	return nil
end

local function saveAsync(player: Player, release: boolean): boolean
	local data = profiles[player]
	if not data then
		return true
	end
	local snapshot = deepCopy(data)
	snapshot._lock = if release then nil else { job = game.JobId, time = os.time() }
	for attempt = 1, 4 do
		local stolen = false
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old: any)
				stolen = false
				if type(old) == "table" and type(old._lock) == "table" and old._lock.job ~= game.JobId then
					stolen = true
					return nil -- another server took over; never overwrite its newer data
				end
				return snapshot
			end)
		end)
		if ok then
			if stolen then
				warn(`PlayerStore: record for {player.UserId} is locked elsewhere, save skipped`)
			end
			return not stolen
		end
		warn(`PlayerStore save failed for {player.UserId} (attempt {attempt}): {err}`)
		task.wait(attempt * 2)
	end
	return false
end

local function onPlayerAdded(player: Player)
	local record = loadAsync(player)
	if not record then
		if player.Parent then
			player:Kick("Your data could not be loaded. Please rejoin in a minute.")
		end
		return
	end
	for key, value in template do
		if record[key] == nil then
			record[key] = deepCopy(value)
		end
	end
	profiles[player] = record
	if not player.Parent then
		-- Left while we were loading: release the lock we just took.
		saveAsync(player, true)
		profiles[player] = nil
		return
	end
	player:SetAttribute("DataLoaded", true)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		saveAsync(player, true)
		profiles[player] = nil
	end
end

function PlayerStore.Start(newTemplate: Data)
	assert(not started, "PlayerStore.Start called twice")
	started = true
	template = newTemplate
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveAsync(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25 -- BindToClose gets about 30 s in total (Roblox docs)
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in profiles do
				task.spawn(saveAsync, player, false)
				task.wait(1) -- spread requests so one autosave tick does not burst the budget
			end
		end
	end)
end

-- Callbacks get the Player only; read the live table with Get.
function PlayerStore.OnLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in profiles do
		task.spawn(callback, player)
	end
end

function PlayerStore.Get(player: Player): Data?
	return profiles[player]
end

-- For high-value moments (a rebirth, a rare hatch). Do not call every frame.
function PlayerStore.SaveNow(player: Player)
	task.spawn(saveAsync, player, false)
end

return PlayerStore
```

Two nuances worth knowing before you copy this:
- `OnLoaded` passes only the `Player`, never the data table. If you used a `BindableEvent` to pass the table, the listener would receive a **copy** (bindables serialize tables, Roblox docs), and every change it made would silently vanish.
- The lock is "good enough" for a worked build: it prevents the common server-hop overwrite, but it does not handle every edge (for example two servers that both think a lock is stale at the same instant). That is what mature profile libraries are for.

---

## 5. The minigame contract and Lava Rise

```lua
--!strict
-- ServerScriptService/Round/Minigames/Types (ModuleScript). Reviewed, not run.
export type Context = {
	map: Model,
	players: { Player },          -- everyone who started the round
	isAlive: (Player) -> boolean,
	eliminate: (Player, string) -> (), -- reason is shown to the player
}

export type Minigame = {
	Name: string,
	Description: string,
	Start: (Context) -> (),
	Stop: () -> (),
	-- Return nil to use the default: everyone still alive wins.
	Winners: (Context) -> { Player }?,
}

return nil
```

Why `Touched` is not used for the lava: `Touched` needs a physics contact, and an anchored part moved by setting `CFrame` every frame does not reliably produce contacts with characters standing still (rule of thumb, widely reported). Polling the height every 0.2 seconds is cheaper than it sounds (one comparison per living player) and it can never miss.

```lua
--!strict
-- ServerScriptService/Round/Minigames/LavaRise (ModuleScript). Reviewed, not run.
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)

local RISE_STUDS_PER_SECOND = 1.2
local CHECK_INTERVAL = 0.2
local CEILING_MARGIN = 120 -- studs above the map's top that count as "out of bounds"

local heartbeat: RBXScriptConnection? = nil
local running = false

local function start(ctx: Types.Context)
	local found = ctx.map:FindFirstChild("Lava")
	assert(found and found:IsA("BasePart"), "LavaRise maps need a BasePart named Lava")
	local lava = found :: BasePart -- explicit cast so closures below keep the narrowed type
	local startCFrame = lava.CFrame
	local startedAt = os.clock()
	local mapCFrame, mapSize = ctx.map:GetBoundingBox()
	local ceilingY = mapCFrame.Position.Y + mapSize.Y / 2 + CEILING_MARGIN
	running = true

	heartbeat = RunService.Heartbeat:Connect(function()
		local risen = (os.clock() - startedAt) * RISE_STUDS_PER_SECOND
		lava.CFrame = startCFrame + Vector3.new(0, risen, 0)
	end)

	task.spawn(function()
		while running do
			local lavaTop = lava.Position.Y + lava.Size.Y / 2
			for _, player in ctx.players do
				if not ctx.isAlive(player) then
					continue
				end
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root then
					continue
				end
				local y = root.Position.Y
				if y < lavaTop then
					ctx.eliminate(player, "The lava got you")
				elseif y > ceilingY then
					-- Nobody legitimately gets this high: likely flying. Eliminate, do not ban.
					ctx.eliminate(player, "Out of bounds")
				end
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

local function stop()
	running = false
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local LavaRise: Types.Minigame = {
	Name = "Lava Rise",
	Description = "Climb! The lava is rising.",
	Start = start,
	Stop = stop,
	Winners = function(_ctx: Types.Context): { Player }?
		return nil -- default: survivors win
	end,
}

return LavaRise
```

The module keeps state in upvalues (`heartbeat`, `running`), which is fine because only one round runs at a time. If you move to several arenas per server, return a constructor instead (section 9).

---

## 6. The round loop: RoundService

This is the heart of the build. Read the comments: most of them mark a bug that existed in an earlier draft.

```lua
--!strict
-- ServerScriptService/Round/RoundService (Script). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RoundConfig = require(ReplicatedStorage.Shared.RoundConfig)
local PlayerStore = require(ServerScriptService.Modules.PlayerStore)
local Types = require(script.Parent.Minigames.Types)

local MINIGAMES: { Types.Minigame } = {
	require(script.Parent.Minigames.LavaRise),
}

local mapsFolder = ServerStorage:WaitForChild("Maps")
local rng = Random.new()

---------------------------------------------------------------- data + leaderstats
PlayerStore.Start({ Wins = 0 })

PlayerStore.OnLoaded(function(player: Player)
	local data = PlayerStore.Get(player)
	if not data then
		return
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = data.Wins
	wins.Parent = leaderstats
	leaderstats.Parent = player
end)

local function addWin(player: Player)
	local data = PlayerStore.Get(player)
	if not data then
		return -- not loaded (or failed to load): never award into nothing
	end
	data.Wins += 1
	local leaderstats = player:FindFirstChild("leaderstats")
	local wins = leaderstats and leaderstats:FindFirstChild("Wins") :: IntValue?
	if wins then
		wins.Value = data.Wins
	end
end

---------------------------------------------------------------- remotes
local remotes = Instance.new("Folder")
remotes.Name = "RoundRemotes"
local voteRemote = Instance.new("RemoteEvent")
voteRemote.Name = "Vote"
voteRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------- replicated state
local function setState(state: string, seconds: number?, message: string?)
	ReplicatedStorage:SetAttribute("RoundState", state)
	ReplicatedStorage:SetAttribute("RoundEndsAt", if seconds then workspace:GetServerTimeNow() + seconds else 0)
	ReplicatedStorage:SetAttribute("RoundMessage", message or "")
end

---------------------------------------------------------------- voting
local votingOpen = false
local votes: { [Player]: string } = {}
local tallyDirty = false

voteRemote.OnServerEvent:Connect(function(player: Player, mapName: unknown)
	if not votingOpen then
		return
	end
	-- Type check first: an exploiter can send a table, a number, or a 1 MB string.
	if typeof(mapName) ~= "string" or #mapName > 50 then
		return
	end
	if not table.find(RoundConfig.MapNames, mapName) then
		return
	end
	votes[player] = mapName
	tallyDirty = true -- published at most every 0.5 s, so vote spam cannot spam replication
end)

Players.PlayerRemoving:Connect(function(player)
	if votes[player] then
		votes[player] = nil
		tallyDirty = true
	end
end)

local function publishTally()
	local counts: { [string]: number } = {}
	for _, name in RoundConfig.MapNames do
		counts[name] = 0
	end
	for _, name in votes do
		counts[name] += 1
	end
	for name, count in counts do
		remotes:SetAttribute("Votes_" .. name, count)
	end
end

local function runVote(): string
	table.clear(votes)
	publishTally()
	votingOpen = true
	setState("Voting", RoundConfig.VoteSeconds, "Vote for a map")
	local endsAt = os.clock() + RoundConfig.VoteSeconds
	while os.clock() < endsAt do
		if tallyDirty then
			tallyDirty = false
			publishTally()
		end
		task.wait(0.5)
	end
	votingOpen = false

	-- Highest count wins; ties and "nobody voted" are broken randomly.
	local best: { string } = {}
	local bestCount = -1
	for _, name in RoundConfig.MapNames do
		local count = remotes:GetAttribute("Votes_" .. name) :: number? or 0
		if count > bestCount then
			best = { name }
			bestCount = count
		elseif count == bestCount then
			table.insert(best, name)
		end
	end
	return best[rng:NextInteger(1, #best)]
end

---------------------------------------------------------------- moving characters
local function aliveCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end
	return root
end

local function placeCharacter(player: Player, target: CFrame): boolean
	local root = aliveCharacterRoot(player)
	if not root then
		return false
	end
	if workspace.StreamingEnabled then
		-- Without this the player can land before the map has streamed in and fall through it.
		pcall(function()
			player:RequestStreamAroundAsync(target.Position, 5)
		end)
	end
	local character = player.Character
	if not character or not character.Parent then
		return false
	end
	character:PivotTo(target + Vector3.new(0, 3, 0))
	return true
end

---------------------------------------------------------------- one round
local function runRound(mapName: string, minigame: Types.Minigame)
	local source = mapsFolder:FindFirstChild(mapName)
	assert(source and source:IsA("Model"), `Missing map {mapName}`)
	local map = source:Clone()
	map.Parent = workspace

	local spawnsFolder = map:FindFirstChild("Spawns")
	local spawns = if spawnsFolder then spawnsFolder:GetChildren() else {}
	assert(#spawns > 0, `Map {mapName} has no Spawns`)

	-- Snapshot participants. Late joiners stay in the lobby until the next round.
	local participants: { Player } = {}
	local alive: { [Player]: boolean } = {}
	local connections: { RBXScriptConnection } = {}
	local spawnIndex = rng:NextInteger(1, #spawns)

	for _, player in Players:GetPlayers() do
		if not player:GetAttribute("DataLoaded") then
			continue
		end
		local spawnPart = spawns[(spawnIndex % #spawns) + 1]
		spawnIndex += 1
		if spawnPart:IsA("BasePart") and placeCharacter(player, spawnPart.CFrame) then
			table.insert(participants, player)
			alive[player] = true
			player:SetAttribute("InRound", true)
		end
	end

	local startedWith = #participants

	local function eliminate(player: Player, reason: string)
		if not alive[player] then
			return -- already out; eliminate can be called from several places at once
		end
		alive[player] = nil
		player:SetAttribute("InRound", false)
		player:SetAttribute("EliminatedReason", reason)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end

	for _, player in participants do
		-- CharacterRemoving covers death, reset, LoadCharacter and leaving.
		table.insert(connections, player.CharacterRemoving:Connect(function()
			eliminate(player, "Left the arena")
		end))
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(connections, humanoid.Died:Connect(function()
				eliminate(player, "Eliminated")
			end))
		end
	end
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		eliminate(player, "Left the game")
	end))

	local ctx: Types.Context = {
		map = map,
		players = participants,
		isAlive = function(player: Player): boolean
			return alive[player] == true
		end,
		eliminate = eliminate,
	}

	setState("Playing", RoundConfig.MaxRoundSeconds, minigame.Description)
	-- A minigame that errors must not kill the loop forever.
	local ok, err = pcall(minigame.Start, ctx)
	if not ok then
		warn(`Minigame {minigame.Name} failed to start: {err}`)
	end

	-- Solo rounds (Studio) end when the one player dies; real rounds end at 1 survivor.
	local endAt = if startedWith >= 2 then 1 else 0
	local deadline = os.clock() + RoundConfig.MaxRoundSeconds
	while ok and os.clock() < deadline do
		local count = 0
		for _ in alive do
			count += 1
		end
		if count <= endAt then
			break
		end
		task.wait(0.25)
	end

	pcall(minigame.Stop)
	for _, connection in connections do
		connection:Disconnect()
	end

	-- Winners: the minigame may override, otherwise survivors.
	local winners: { Player } = {}
	local custom = if ok then minigame.Winners(ctx) else nil
	if custom then
		winners = custom
	else
		for player in alive do
			table.insert(winners, player)
		end
	end

	-- Anti-farm: a "win" against nobody is not a win on live servers.
	local countsForWins = startedWith >= RoundConfig.MinPlayers and startedWith >= 2
	local names: { string } = {}
	for _, player in winners do
		if player.Parent == Players then
			table.insert(names, player.DisplayName)
			if countsForWins then
				addWin(player)
			end
		end
	end

	local message = if #names > 0 then "Winners: " .. table.concat(names, ", ") else "Nobody survived!"
	setState("Results", RoundConfig.ResultsSeconds, message)

	-- Send survivors home. LoadCharacter yields, so do each in its own thread.
	for player in alive do
		player:SetAttribute("InRound", false)
		task.spawn(function()
			if player.Parent == Players then
				player:LoadCharacterAsync()
			end
		end)
	end

	task.wait(RoundConfig.ResultsSeconds)
	map:Destroy()
end

---------------------------------------------------------------- main loop
local function enoughPlayers(): boolean
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("DataLoaded") then
			count += 1
		end
	end
	return count >= RoundConfig.MinPlayers
end

while true do
	if not enoughPlayers() then
		setState("Waiting", nil, `Waiting for {RoundConfig.MinPlayers} players`)
		repeat
			task.wait(1)
		until enoughPlayers()
	end

	setState("Intermission", RoundConfig.IntermissionSeconds, "Next round starting soon")
	task.wait(RoundConfig.IntermissionSeconds)
	if not enoughPlayers() then
		continue -- someone left during intermission
	end

	local mapName = runVote()
	local minigame = MINIGAMES[rng:NextInteger(1, #MINIGAMES)]
	local ok, err = pcall(runRound, mapName, minigame)
	if not ok then
		-- Last-resort cleanup so a bug in one round does not freeze the server.
		warn(`Round failed: {err}`)
		for _, child in workspace:GetChildren() do
			if child:IsA("Model") and table.find(RoundConfig.MapNames, child.Name) then
				child:Destroy()
			end
		end
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("InRound") then
				player:SetAttribute("InRound", false)
				task.spawn(player.LoadCharacterAsync, player)
			end
		end
		task.wait(3)
	end
end
```

Things this loop handles that a first draft usually does not:
- **Leaving mid-round.** `PlayerRemoving` and `CharacterRemoving` both eliminate. `eliminate` is idempotent because both can fire for the same player in the same frame.
- **Resetting to escape.** Reset is a death, so it eliminates. Players cannot reset out of a losing position into the lobby and keep their "alive" flag.
- **A minigame that throws.** `pcall` around `Start` and `Stop`, and a `pcall` around the whole round with a cleanup fallback. Without that, one nil index stops rounds forever on that server and nobody notices until reviews arrive.
- **Spawns fewer than players.** Spawn index wraps (`%`), so extra players share spawns rather than erroring.
- **Players who never loaded data.** They are skipped as participants and cannot win, so no win is written into a record that will never save.

---

## 7. Client and UI wiring

`RoundGui` must have `ResetOnSpawn = false`. With the default `true`, the GUI is destroyed and recloned on every respawn, and since every round ends with `LoadCharacter`, every reference the LocalScript holds would point at a destroyed copy after round one (a classic "UI works once" bug, see [[Debugging UI Layout and Input]]). Keeping the LocalScript in `StarterPlayerScripts` means it runs once per session.

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/RoundClient (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoundConfig"))
local remotes = ReplicatedStorage:WaitForChild("RoundRemotes")
local voteRemote = remotes:WaitForChild("Vote") :: RemoteEvent

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("RoundGui") :: ScreenGui
local statusLabel = gui:WaitForChild("Status") :: TextLabel
local timerLabel = gui:WaitForChild("Timer") :: TextLabel
local voteFrame = gui:WaitForChild("VoteFrame") :: Frame
local template = voteFrame:WaitForChild("Template") :: TextButton

-- Build one button per map from the shared list.
local buttons: { [string]: TextButton } = {}
local myVote: string? = nil

local function refreshVoteButtons()
	for name, button in buttons do
		local count = remotes:GetAttribute("Votes_" .. name) :: number? or 0
		local mark = if myVote == name then "> " else ""
		button.Text = `{mark}{name} ({count})`
	end
end

for index, name in RoundConfig.MapNames do
	local button = template:Clone()
	button.Name = name
	button.LayoutOrder = index
	button.Visible = true
	button.Parent = voteFrame
	buttons[name] = button
	button.Activated:Connect(function()
		myVote = name
		voteRemote:FireServer(name)
		refreshVoteButtons()
	end)
end

remotes.AttributeChanged:Connect(function(attribute)
	if string.sub(attribute, 1, 6) == "Votes_" then
		refreshVoteButtons()
	end
end)

local function onStateChanged()
	local state = ReplicatedStorage:GetAttribute("RoundState") :: string? or "Waiting"
	local message = ReplicatedStorage:GetAttribute("RoundMessage") :: string? or ""
	statusLabel.Text = message
	voteFrame.Visible = state == "Voting"
	if state == "Voting" then
		myVote = nil
		refreshVoteButtons()
	end
end

ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(onStateChanged)
ReplicatedStorage:GetAttributeChangedSignal("RoundMessage"):Connect(onStateChanged)
onStateChanged()

-- Local countdown from the server's absolute end time.
local lastShown = -1
RunService.Heartbeat:Connect(function()
	local endsAt = ReplicatedStorage:GetAttribute("RoundEndsAt") :: number? or 0
	local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
	if remaining ~= lastShown then -- only touch the label when the number changes
		lastShown = remaining
		timerLabel.Text = if endsAt > 0 then tostring(remaining) else ""
	end
end)

-- Show why you were eliminated.
player:GetAttributeChangedSignal("EliminatedReason"):Connect(function()
	local reason = player:GetAttribute("EliminatedReason")
	if typeof(reason) == "string" then
		statusLabel.Text = reason
	end
end)
```

UI build notes (rule of thumb): anchor `Status` and `Timer` to the top centre inside the safe area (see [[Safe Areas and Insets]]), give `VoteFrame` a `UIListLayout` with `FillDirection = Horizontal`, and make the template button at least 44 px tall on phone. Vote buttons use `Activated`, not `MouseButton1Click`, so they work with touch and gamepad (see [[Gamepad and Console UX]]).

---

## 8. Testing in Studio

1. **Solo smoke test.** Play (F5). With `MinPlayers = 1` in Studio, intermission starts within a second. Vote, get placed on the map, let the lava kill you. Expect "Nobody survived!", no win (a solo round never counts), and a respawn in the lobby.
2. **Real round.** Test tab > Clients and Servers, 3 players. Kill one by walking into lava, have another reset, keep the third alive. Expect the round to end immediately when one remains, the survivor's Wins to go up by one, and everyone back in the lobby.
3. **Leave mid-round.** Close a client window during Playing. The server output must show no errors and the round must still end normally.
4. **Late joiner.** Start a 2-player test, wait until Playing, then add a third client (Clients and Servers lets you add players). The new player should see "Climb! The lava is rising." in the status bar and the timer, and stay in the lobby.
5. **Vote abuse.** In a client view, run in the command bar: `game.ReplicatedStorage.RoundRemotes.Vote:FireServer({})` then `:FireServer(string.rep("x", 1e5))` then `:FireServer("Volcano")` in a loop of 1,000. Expect no errors and the tally to change at most twice a second.
6. **Save check.** Win a round, stop the test, play again. Wins should persist. If they do not, check API access and the output for `PlayerStore` warnings (see [[Debugging DataStore Problems]]).
7. **Broken minigame.** Temporarily add `error("boom")` at the top of `start` in LavaRise. The server should warn, end the round, and keep looping.

For multi-device checks (phone layout, latency), follow [[Multi-Client and Device Playtesting Protocols]].

---

## 9. Exploits it must resist

| Attack | What stops it here |
|---|---|
| Sending junk to `Vote` (tables, huge strings, unknown maps) | Type and length check, then a whitelist lookup |
| Spamming votes to flood replication | Tallies published on a 0.5 s tick, not per vote |
| Voting after voting closed | `votingOpen` flag |
| Flying above the lava | Out-of-bounds ceiling check eliminates (does not ban; see [[False Positives Lag and Fair Enforcement]]) |
| Noclipping out of the map or teleporting to the lobby | Not fully covered: add a horizontal bounds check against `map:GetBoundingBox()` and the movement checks in [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] |
| Faking survival with a modified client | Health, death and the alive set live on the server; the client cannot mark itself alive |
| Win farming with an alt account in a private server | Wins need at least 2 starting players; for stronger protection, require that each opponent survived some minimum time, or do not award wins in private servers (`game.PrivateServerId ~= ""`) |
| Server-hop duplication of wins | PlayerStore session lock |

The general rules behind these live in [[Server Authority and Validation]], [[Remote Abuse Patterns and Rate Limiting in Practice]] and [[Testing Your Own Remotes - Fuzzing and Abuse Tests]].

---

## 10. Common mistakes

- **Counting down with one remote per second.** It wastes bandwidth and drifts. Send the end time once.
- **Using `wait()` and `spawn()`.** Deprecated and throttled; the code uses `task.wait`, `task.spawn` (see [[Task Library Coroutines and Yielding]]).
- **Storing maps in `ReplicatedStorage`.** Every client downloads every map at join. On phones that is real memory (see [[Memory Budgets and Leaks]]).
- **Forgetting to disconnect per-round connections.** Each round leaks a `Died` and a `CharacterRemoving` connection per player; after a few hours the server is slow. The `connections` list fixes it.
- **Teleporting before the map streams in** with `StreamingEnabled` on. Players fall through. `RequestStreamAroundAsync` fixes most cases (see [[Instance Streaming]]).
- **`ResetOnSpawn = true` on the round GUI.** Works for one round, breaks after the first respawn.

---

## 11. Extending it

- **More minigames.** Add a module that matches `Types.Minigame` and append it to `MINIGAMES`. For team modes, assign `Teams` in `Start` and return the winning team's players from `Winners` (see [[Spawning Teams and Rounds]]).
- **Several arenas per server.** Turn `runRound` into a `RoundRunner.new(arenaFolder)` object and have each minigame module return `new()` so its state is per instance. Run each runner in its own `task.spawn`.
- **Rewards beyond wins.** Award currency in `addWin`, and look at [[Economy Inflation Sinks and Faucets Math]] before choosing amounts.
- **Spectating.** Eliminated players get a camera that follows a living participant; the server already exposes `InRound` attributes to pick from (see [[Camera Systems]]).
- **AFK handling.** Skip players whose last input was over 2 minutes ago; the client sets an attribute, the server treats it as a hint only.
- **Leaderboards.** Push `Wins` to an ordered store; see [[Global Leaderboards End to End]].
- **Matchmaking across servers.** Move the lobby to its own place and teleport full parties (see [[Teleporting and Multi-Place Games]]).

---

## 12. Checklist

- [ ] `ServerStorage.Maps` children match `RoundConfig.MapNames` exactly
- [ ] Every map has `Spawns` (enough parts) and, for Lava Rise, a `Lava` part
- [ ] `RoundGui.ResetOnSpawn = false`
- [ ] Studio API access enabled for save tests; Studio uses the separate store name
- [ ] Solo, 3-player, leave-mid-round, late-joiner and vote-abuse tests pass
- [ ] A minigame that errors does not stop the loop
- [ ] Wins only count with 2 or more starting players
- [ ] No per-second remotes; timer driven by `GetServerTimeNow`

## See also
[[Worked Builds Start Here]] · [[Spawning Teams and Rounds]] · [[Core Loops and Session Design]] · [[Server Authority and Validation]] · [[Saving Correctly - Autosave and BindToClose]] · [[Instance Streaming]] · [[Melee Combat System End to End]] · [[Quest Chain System End to End]]

## Connected notes
<!-- auto-links:start -->
[[Genre Playbook - Party and Minigame Collections]] · Arena Rounds with Teams and Spectating End to End · Links - Rounds and matchmaking · Genre Systems Start Here · Obby Checkpoints and Stage Saves End to End · Spawn Points Safe Zones and Respawn Flow
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Arena Rounds with Teams and Spectating End to End]] · [[Saved Inventory End to End]] · [[Rebirth and Prestige System End to End]] · [[Pet Hatching and Following End to End]] · [[Weekend Build - Arena Shooter with Server-Checked Hits]] · [[Daily Rewards System End to End]] · [[Codes Redemption System End to End]]
<!-- related:end -->
