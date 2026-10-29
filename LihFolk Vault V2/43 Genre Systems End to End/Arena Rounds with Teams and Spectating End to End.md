---
tags: [genre-system, rounds, minigames, teams, spectating, worked-build, matchmaking, luau]
---
# Arena Rounds with Teams and Spectating End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One `task.delay` without a round id (section 4.1).
> - Avoid: Per-round connections never disconnected.
> - Avoid: Letting alive players leave via the menu.
> - Two arenas, four test clients: both arenas run rounds at the same time; ending one does not affect the other.
> - Leave during countdown: countdown cancels when the queue drops below the requirement.
> - Leave mid-round as the last player on a team: the other team wins; no rewards if under 20 s.
>
> Cost: TL;DR ~160 tok · whole note ~7.5k tok. Read more: ## 4. The server: ArenaService · ## 5. The client: spectating and status · ## 6. Common mistakes · ## 9. Test checklist
<!-- tldr:end -->

This note builds the round loop that comes after the single global loop: several arenas running independent rounds in one server, a queue per arena, teams balanced by a saved rating, late joiners routed into spectating or into the round, a spectator camera that follows only valid targets, leavers and AFK players handled without stalling a round, and results that update wins and rating without rewarding alt-account farming. It is the "several arenas per server" and "spectating" extension that [[Round-Based Minigame Loop End to End]] lists in its own extension section, built out in full.

**Why this title.** The section brief proposed "Round-Based Minigame Loop End to End", but that title already exists in [[Worked Builds Start Here]] and covers the single global lobby, intermission, map vote and one pluggable minigame. Rather than repeat it, this note takes the next step: per-arena runners, teams, rating and spectating. Read that note first for the basic loop, the minigame contract and the `GetServerTimeNow` countdown pattern; they are not repeated here.

> **All code is reviewed, not run.** Strict Luau against Roblox docs (as of October 2026), checked by reading. Use the checklist in section 9.

Labels used: **Roblox docs (as of October 2026)**, **rule of thumb**.

---

## 1. Why one loop per arena

A single global loop works when the whole server plays one round together. It breaks down in three common designs: duel pads (1v1 or 2v2 on small platforms around a hub), battlegrounds-style lobbies with several team arenas, and party games where a group wants to start without waiting for strangers. In all three, players are in different states at the same time, and the clean model is **one state machine per arena**, each holding its own members, timers and connections, with a thin service that routes players between them.

| Concern | Global loop | Per-arena runners |
|---|---|---|
| State | One `RoundState` attribute | One state attribute per arena model |
| Membership | "Everyone in the server" | Explicit queue and member lists; a player belongs to at most one arena |
| Teams | Roblox `Teams` service works | `Teams` is server-global, so per-arena teams are attributes |
| Failure blast radius | An error stops the server's only round | An error ends one arena's round; others continue |
| Waiting | Everyone waits for the slowest round | Only that arena's queue waits |

### When not to do this
- **Every player always plays together.** Use the global loop; it is simpler.
- **Matches need their own server** (competitive modes, long matches, maps too big to share). Queue in the lobby and teleport to reserved servers instead ([[Teleporting and Multi-Place Games]]); this note is for arenas that share a server.

---

## 2. Folder layout

```
ReplicatedStorage
  Shared (Folder)
    Net (ModuleScript)            -- from Saved Inventory End to End
    ArenaConfig (ModuleScript)
ServerScriptService
  Server (Folder)
    Main (Script)                 -- add "ArenaService" to ORDER
    PlayerData, DataTemplate, RateLimiter (ModuleScripts)
    Services (Folder)
      ArenaService (ModuleScript)
Workspace
  Arenas (Folder)
    ArenaA (Model, attributes TeamSize = 2)
      Spawns1 (Folder of anchored, non-colliding Parts)
      Spawns2 (Folder)
      Bounds (Part, anchored, invisible, CanCollide false)
    ArenaB (Model, attributes TeamSize = 1)
  Lobby (Model with a SpawnLocation)
StarterPlayer/StarterPlayerScripts/Client
  ArenaClient (LocalScript)
```

Arenas are permanent models here because they are small and reused. If arenas are large or vary per round, clone them from `ServerStorage` per round as the global loop note does, and destroy them at cleanup.

---

## 3. Data

### 3.1 ArenaConfig

```lua
--!strict
-- ReplicatedStorage/Shared/ArenaConfig (ModuleScript). Reviewed, not run.
local ArenaConfig = {}

ArenaConfig.CountdownSeconds = 8
ArenaConfig.RoundSeconds = 120
ArenaConfig.ResultsSeconds = 5
ArenaConfig.JoinInProgressSeconds = 20   -- late joiners may enter during the first 20 s
ArenaConfig.MinRoundSecondsForRewards = 20
ArenaConfig.AfkSeconds = 90
ArenaConfig.StartRating = 1000
ArenaConfig.RatingK = 24

return ArenaConfig
```

### 3.2 Profile fields

```lua
-- In DataTemplate (Saved Inventory End to End): add to the Data type
	Arena: { Wins: number, Losses: number, Played: number, Rating: number },
-- and to DataTemplate.new()
		Arena = { Wins = 0, Losses = 0, Played = 0, Rating = 1000 },
```

---

## 4. The server: ArenaService

The service holds a table of arena runners and a map from player to the runner they belong to. Each runner owns a state, a queue, two teams, a list of alive players, a list of spectators, and a list of connections it must clean up.

```lua
--!strict
-- ServerScriptService/Server/Services/ArenaService (ModuleScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local ArenaConfig = require(ReplicatedStorage.Shared.ArenaConfig)
local PlayerData = require(script.Parent.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

type State = "Idle" | "Countdown" | "Playing" | "Results"

type Arena = {
	Name: string,
	Model: Model,
	TeamSize: number,
	State: State,
	Queue: { Player },
	Teams: { { Player } },          -- Teams[1], Teams[2]
	Alive: { [Player]: number },    -- player -> team index, while alive in the round
	Spectators: { [Player]: boolean },
	StartedAt: number,
	StartingCounts: { number },
	Connections: { RBXScriptConnection },
	RoundId: number,
}

local ArenaService = {}

local arenas: { [string]: Arena } = {}
local memberOf: { [Player]: Arena } = {}
local lastMoved: { [Player]: { Position: Vector3, At: number } } = {}
local allowJoin = RateLimiter.new(3, 0.5)

-- Helpers ------------------------------------------------------------------------------

local function setPlayerState(player: Player, arena: Arena?, role: string)
	player:SetAttribute("Arena", if arena then arena.Name else "")
	player:SetAttribute("ArenaRole", role) -- "", "Queued", "Alive", "Spectating"
	player:SetAttribute("ArenaTeam", if arena and arena.Alive[player] then arena.Alive[player] else 0)
end

local function publishArena(arena: Arena, endsAt: number?)
	arena.Model:SetAttribute("State", arena.State)
	arena.Model:SetAttribute("EndsAt", endsAt or 0)
	arena.Model:SetAttribute("Queued", #arena.Queue)
	arena.Model:SetAttribute("Needed", arena.TeamSize * 2)
end

local function toLobby(player: Player)
	local character = player.Character
	local lobby = workspace:FindFirstChild("Lobby")
	local spawn = lobby and lobby:FindFirstChildWhichIsA("SpawnLocation", true)
	if character and spawn then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

local function spawnPoints(arena: Arena, team: number): { BasePart }
	local list: { BasePart } = {}
	local folder = arena.Model:FindFirstChild(`Spawns{team}`)
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(list, child)
			end
		end
	end
	return list
end

local function ratingOf(player: Player): number
	local profile = PlayerData.Get(player)
	return if profile then profile.Data.Arena.Rating else ArenaConfig.StartRating
end

local function removeFromList(list: { Player }, player: Player)
	local index = table.find(list, player)
	if index then
		table.remove(list, index)
	end
end

-- Team balancing: sort by rating, then snake draft (1,2,2,1,1,2...).
local function makeTeams(players: { Player }): { { Player } }
	table.sort(players, function(a: Player, b: Player): boolean
		return ratingOf(a) > ratingOf(b)
	end)
	local teams: { { Player } } = { {}, {} }
	for i, player in players do
		local round = (i - 1) // 2
		local first = if round % 2 == 0 then 1 else 2
		local team = if (i - 1) % 2 == 0 then first else 3 - first
		table.insert(teams[team], player)
	end
	return teams
end

-- Results ------------------------------------------------------------------------------

local function expected(ratingA: number, ratingB: number): number
	return 1 / (1 + 10 ^ ((ratingB - ratingA) / 400))
end

local function averageRating(team: { Player }): number
	if #team == 0 then
		return ArenaConfig.StartRating
	end
	local sum = 0
	for _, player in team do
		sum += ratingOf(player)
	end
	return sum / #team
end

local function applyResults(arena: Arena, winner: number?)
	local roundSeconds = os.clock() - arena.StartedAt
	-- No rewards for rounds that were never contested: a team empty at start, or a round
	-- that ended almost immediately (a common alt-account farming pattern).
	local contested = arena.StartingCounts[1] > 0 and arena.StartingCounts[2] > 0
		and roundSeconds >= ArenaConfig.MinRoundSecondsForRewards
	if not contested or winner == nil then
		return
	end
	local ratings = { averageRating(arena.Teams[1]), averageRating(arena.Teams[2]) }
	for teamIndex, team in arena.Teams do
		local score = if teamIndex == winner then 1 else 0
		local delta = ArenaConfig.RatingK * (score - expected(ratings[teamIndex], ratings[3 - teamIndex]))
		for _, player in team do
			local profile = PlayerData.Get(player) -- nil for players who left: they keep their old rating
			if profile then
				local data = profile.Data.Arena
				data.Played += 1
				data.Rating = math.max(0, math.floor(data.Rating + delta + 0.5))
				if score == 1 then
					data.Wins += 1
				else
					data.Losses += 1
				end
			end
		end
	end
end

-- Round lifecycle --------------------------------------------------------------------------

local checkEnd: (Arena) -> ()
local tryCountdown: (Arena) -> ()

local function cleanup(arena: Arena)
	for _, connection in arena.Connections do
		connection:Disconnect()
	end
	table.clear(arena.Connections)
	-- Everyone still here (survivors, the eliminated, late spectators) is queued again.
	-- Players opt out with ArenaLeave; the AFK sweep removes the ones who walked away.
	local requeue: { Player } = {}
	for player in arena.Alive do
		toLobby(player)
		table.insert(requeue, player)
	end
	for player in arena.Spectators do
		table.insert(requeue, player)
	end
	table.clear(arena.Alive)
	table.clear(arena.Spectators)
	arena.Teams = { {}, {} }
	arena.State = "Idle"
	for _, player in requeue do
		if player.Parent == Players and memberOf[player] == arena and not table.find(arena.Queue, player) then
			table.insert(arena.Queue, player)
			setPlayerState(player, arena, "Queued")
		end
	end
	publishArena(arena)
	tryCountdown(arena)
end

local function eliminate(arena: Arena, player: Player, becomeSpectator: boolean)
	if arena.Alive[player] == nil then
		return
	end
	arena.Alive[player] = nil
	if becomeSpectator and player.Parent == Players then
		arena.Spectators[player] = true
		setPlayerState(player, arena, "Spectating")
	end
	checkEnd(arena)
end

local function addToRound(arena: Arena, player: Player, team: number)
	arena.Alive[player] = team
	if not table.find(arena.Teams[team], player) then
		table.insert(arena.Teams[team], player)
	end
	memberOf[player] = arena
	setPlayerState(player, arena, "Alive")

	local points = spawnPoints(arena, team)
	local character = player.Character
	if character and #points > 0 then
		local index = (#arena.Teams[team] - 1) % #points + 1
		character:PivotTo(points[index].CFrame + Vector3.new(0, 4, 0))
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(arena.Connections, humanoid.Died:Connect(function()
			eliminate(arena, player, true)
		end))
	else
		-- No character at round start (respawning): they sit this round out.
		eliminate(arena, player, true)
	end
end

local function aliveCount(arena: Arena, team: number): number
	local n = 0
	for _, t in arena.Alive do
		if t == team then
			n += 1
		end
	end
	return n
end

checkEnd = function(arena: Arena)
	if arena.State ~= "Playing" then
		return
	end
	local one, two = aliveCount(arena, 1), aliveCount(arena, 2)
	if one > 0 and two > 0 then
		return
	end
	arena.State = "Results"
	local winner: number? = if one > 0 then 1 elseif two > 0 then 2 else nil
	applyResults(arena, winner)
	arena.Model:SetAttribute("Winner", winner or 0)
	publishArena(arena, workspace:GetServerTimeNow() + ArenaConfig.ResultsSeconds)
	local roundId = arena.RoundId
	task.delay(ArenaConfig.ResultsSeconds, function()
		if arena.RoundId == roundId then
			cleanup(arena)
		end
	end)
end

local function startRound(arena: Arena)
	local players: { Player } = {}
	for _, player in arena.Queue do
		if #players < arena.TeamSize * 2 and player.Parent == Players then
			table.insert(players, player)
		end
	end
	for _, player in players do
		removeFromList(arena.Queue, player)
	end
	arena.RoundId += 1
	arena.Teams = makeTeams(players)
	arena.State = "Playing"
	arena.StartedAt = os.clock()
	for team = 1, 2 do
		for _, player in arena.Teams[team] do
			addToRound(arena, player, team)
		end
	end
	arena.StartingCounts = { aliveCount(arena, 1), aliveCount(arena, 2) }
	publishArena(arena, workspace:GetServerTimeNow() + ArenaConfig.RoundSeconds)

	local roundId = arena.RoundId
	task.delay(ArenaConfig.RoundSeconds, function()
		if arena.RoundId ~= roundId or arena.State ~= "Playing" then
			return
		end
		-- Time up: the team with more players alive wins; a tie is a draw (no rating change).
		local one, two = aliveCount(arena, 1), aliveCount(arena, 2)
		arena.State = "Results"
		local winner: number? = if one > two then 1 elseif two > one then 2 else nil
		applyResults(arena, winner)
		arena.Model:SetAttribute("Winner", winner or 0)
		publishArena(arena, workspace:GetServerTimeNow() + ArenaConfig.ResultsSeconds)
		task.delay(ArenaConfig.ResultsSeconds, function()
			if arena.RoundId == roundId then
				cleanup(arena)
			end
		end)
	end)
	checkEnd(arena) -- a team may already be empty if someone had no character
end

tryCountdown = function(arena: Arena)
	if arena.State ~= "Idle" or #arena.Queue < arena.TeamSize * 2 then
		return
	end
	arena.State = "Countdown"
	local roundId = arena.RoundId
	publishArena(arena, workspace:GetServerTimeNow() + ArenaConfig.CountdownSeconds)
	task.delay(ArenaConfig.CountdownSeconds, function()
		if arena.RoundId ~= roundId or arena.State ~= "Countdown" then
			return
		end
		if #arena.Queue >= arena.TeamSize * 2 then
			local ok, err = pcall(startRound, arena)
			if not ok then
				warn(`[Arena] {arena.Name} failed to start: {err}`)
				cleanup(arena)
			end
		else
			arena.State = "Idle" -- someone left during the countdown
			publishArena(arena)
		end
	end)
end

-- Joining and leaving ----------------------------------------------------------------------

local function leave(player: Player)
	local arena = memberOf[player]
	if not arena then
		return
	end
	memberOf[player] = nil
	removeFromList(arena.Queue, player)
	arena.Spectators[player] = nil
	if arena.Alive[player] then
		eliminate(arena, player, false) -- a leaver counts as eliminated
	end
	if player.Parent == Players then
		setPlayerState(player, nil, "")
	end
	if arena.State == "Countdown" or arena.State == "Idle" then
		publishArena(arena)
	end
end

local function join(player: Player, arena: Arena)
	if memberOf[player] then
		leave(player)
	end
	memberOf[player] = arena
	if arena.State == "Playing" then
		local elapsed = os.clock() - arena.StartedAt
		local one, two = #arena.Teams[1], #arena.Teams[2]
		local smaller = if one <= two then 1 else 2
		if elapsed < ArenaConfig.JoinInProgressSeconds and #arena.Teams[smaller] < arena.TeamSize then
			addToRound(arena, player, smaller) -- fills a gap left by a leaver
			return
		end
		arena.Spectators[player] = true
		setPlayerState(player, arena, "Spectating")
		return
	end
	table.insert(arena.Queue, player)
	setPlayerState(player, arena, "Queued")
	publishArena(arena)
	tryCountdown(arena)
end

function ArenaService.Start()
	for _, model in workspace:WaitForChild("Arenas"):GetChildren() do
		if model:IsA("Model") then
			local teamSize = model:GetAttribute("TeamSize")
			arenas[model.Name] = {
				Name = model.Name, Model = model,
				TeamSize = if type(teamSize) == "number" then math.clamp(teamSize, 1, 8) else 1,
				State = "Idle", Queue = {}, Teams = { {}, {} }, Alive = {}, Spectators = {},
				StartedAt = 0, StartingCounts = { 0, 0 }, Connections = {}, RoundId = 0,
			}
			publishArena(arenas[model.Name])
		end
	end

	Net.Event("ArenaJoin").OnServerEvent:Connect(function(player: Player, name: unknown)
		if type(name) ~= "string" or #name > 40 or not allowJoin(player) then
			return
		end
		local arena = arenas[name]
		if arena and PlayerData.Get(player) then -- no profile, no rated play
			join(player, arena)
		end
	end)
	Net.Event("ArenaLeave").OnServerEvent:Connect(function(player: Player)
		if allowJoin(player) then
			local arena = memberOf[player]
			if arena and arena.Alive[player] then
				return -- alive players leave by dying or by leaving the game, not by menu
			end
			leave(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		leave(player)
		lastMoved[player] = nil
	end)

	-- AFK sweep: judged from server-side positions, not a client "I am active" flag.
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for player, arena in memberOf do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local record = lastMoved[player]
					if not record or (record.Position - root.Position).Magnitude > 2 then
						lastMoved[player] = { Position = root.Position, At = now }
					elseif now - record.At > ArenaConfig.AfkSeconds and arena.Alive[player] == nil then
						leave(player) -- queued or spectating AFK players are removed; alive ones are not
					end
				end
			end
		end
	end)
end

return ArenaService
```

### 4.1 The decisions that matter

**`RoundId` guards every delayed callback.** `task.delay` callbacks outlive the state that scheduled them. If round 7 ends early by elimination and round 8 starts within the timeout of round 7's time limit, round 7's timer fires during round 8. Every delayed callback captures the id it was scheduled for and does nothing if the arena has moved on. This bug shows up as "rounds randomly end early", only on busy servers, and is very hard to reproduce without the guard.

**Teams are attributes, not the `Teams` service.** `Teams` and `Player.Team` are server-wide: a player can be on one team in the whole server. With two arenas each running red versus blue, "Red" would mean two different groups. Per-arena team indices as attributes avoid that, and the client colours names from the attribute. The cost is that built-in features tied to `Player.Team` (team-coloured leaderboard, `SpawnLocation.TeamColor`) do not apply; you build those small pieces yourself ([[Spawning Teams and Rounds]]).

**Snake draft by rating.** Sorting by rating and drafting 1, 2, 2, 1 gives balanced teams for small groups without any search. For 2v2 it pairs the best with the worst. For larger teams it is close to optimal and costs nothing. It is not matchmaking across servers; for that, see the queue patterns in [[MemoryStore Service]].

**Elo on team averages, K = 24.** Simple and well understood. The expected score uses the logistic formula on the difference in team averages; each member of a team moves by the same delta. Two honest limitations: averages hide a one-strong-player team, and rating only means something with enough rounds per player. Do not show rating as a public rank until a player has played 10 or more rounds (rule of thumb).

**Uncontested rounds pay nothing.** A team empty at start, or a round shorter than 20 seconds, gives no wins and no rating. Without this, two accounts in a private server can farm wins by having one stand still. Pair it with the rule that rewards require a loaded profile (no profile, no join).

**Leavers count as eliminated, and the rating they risked stays with them unchanged.** The code only updates profiles that are still loaded. That means rage-quitting avoids a rating loss, which is a known exploit of this simple design. Two fixes: apply the loss at leave time (write into the profile in a pre-release hook, see [[Genre Systems Start Here]]), or store "abandoned round" in the profile on join and clear it at results, applying a penalty on the next load if it is still set. The second is robust even against crashes.

**Errors in one arena do not stop others.** `startRound` runs in a `pcall`; a broken spawn folder ends that arena's round and returns its players to the lobby ([[Error Handling - pcall xpcall and Promise Patterns]]).

---

## 5. The client: spectating and status

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/Client/ArenaClient (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local spectateIndex = 1

local function aliveInMyArena(): { Player }
	local myArena = player:GetAttribute("Arena")
	local list: { Player } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("Arena") == myArena and other:GetAttribute("ArenaRole") == "Alive" then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a: Player, b: Player): boolean
		return a.UserId < b.UserId -- stable order so "next" is predictable
	end)
	return list
end

local function followTarget()
	if player:GetAttribute("ArenaRole") ~= "Spectating" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		return
	end
	local targets = aliveInMyArena()
	if #targets == 0 then
		return
	end
	spectateIndex = (spectateIndex - 1) % #targets + 1
	local target = targets[spectateIndex]
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- Re-evaluate when anyone's role changes (a target died, a round ended).
local function watch(other: Player)
	other:GetAttributeChangedSignal("ArenaRole"):Connect(followTarget)
end
for _, other in Players:GetPlayers() do
	watch(other)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function()
	task.defer(followTarget)
end)
player.CharacterAdded:Connect(function()
	task.defer(followTarget)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonR1 then
		spectateIndex += 1
		followTarget()
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1 then
		spectateIndex -= 1
		followTarget()
	end
end)

-- Joining: each arena model holds a ProximityPrompt. The client sends only the arena's name;
-- the server looks the arena up itself and ignores anything it does not know.
local ProximityPromptService = game:GetService("ProximityPromptService")
local joinRemote = Net.Event("ArenaJoin")
local arenasFolder = workspace:WaitForChild("Arenas")
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	local model = prompt:FindFirstAncestorOfClass("Model")
	if model and model.Parent == arenasFolder then
		joinRemote:FireServer(model.Name)
	end
end)
```

### 5.1 Spectating details that bite
- **Streaming.** With [[Instance Streaming]] on, a spectator in the lobby may not have the target's area loaded, so the camera follows a character the client cannot fully see. Keep arenas within the streaming radius of the lobby, or have the server set the spectator's `Player.ReplicationFocus` to the target's root part while spectating and back to nil afterwards (the property exists on `Player` per Roblox docs (as of October 2026); test how it interacts with your streaming radius).
- **The spectator's own character.** A dead player respawns in the lobby after the respawn delay. If the lobby is also where queued players stand, spectators should not block the queue pad. Spectating as a camera-only state with the character parked in the lobby is the simplest arrangement.
- **Touch and gamepad.** Q and E are keyboard only. Add on-screen next and previous buttons for phones and the shoulder buttons for gamepads, as the code does ([[Gamepad and Console UX]]).
- **Information leaks.** In hide-and-seek modes, spectators can relay positions through voice or chat. Either show spectators only their own team or accept it as part of party play.

---

## 5.2 Exploits this build must resist

| Attack | What stops it |
|---|---|
| Fire `ArenaJoin` for every arena in a loop to hold places in all queues | A player belongs to one arena; joining another calls `leave` first; the join limiter allows a burst of 3 |
| Join with an arena name that does not exist, or a 10 KB string | Type and length check, then a lookup in the server's own table |
| Set `ArenaRole` to "Alive" on the client to appear in others' spectate lists | Attributes set by a client do not replicate; only the server's values reach other clients |
| Leave the queue the instant a round starts to dodge a strong team | Teams are fixed when the round starts; leaving after that is elimination |
| Farm wins with an alt account that stands still | Rounds under 20 s and rounds with an empty team pay nothing; rating gains shrink against low-rated opponents |
| Rage-quit to avoid a rating loss | Not stopped by the base code; section 4.1 gives two fixes |

The pattern behind the table is the same as everywhere in this folder: the client sends a request with the smallest possible payload (a name), the server owns every list and every number, and anything a client can see is only a copy ([[Server Authority and Validation]], [[Remote Abuse Patterns and Rate Limiting in Practice]]).

---

## 6. Common mistakes

- **One `task.delay` without a round id** (section 4.1). The most common cause of rounds ending at random.
- **Per-round connections never disconnected.** Every `Died` connection is stored in `arena.Connections` and cleared at cleanup. Without it, a player's old `Died` connection fires on a later death and eliminates them from a round they are not in.
- **Letting alive players leave via the menu.** It becomes a free escape from a losing fight with no rating cost. Alive players leave by dying or by leaving the game.
- **Using `Players:GetPlayers()` as the arena roster.** It includes everyone in the server; arenas need their own lists.
- **Rewarding draws.** A draw by time-out with equal alive counts is the easiest result to arrange between friends; it pays nothing here.

---

## 7. Numbers worth knowing

| Quantity | Value | Source |
|---|---|---|
| Rating K factor | 24 | Rule of thumb; 16 to 32 is the usual range |
| Expected score | `1 / (1 + 10^((Rb - Ra)/400))` | Standard Elo formula |
| A 200-point favourite wins | about 76 percent expected | Arithmetic from the formula |
| Countdown | 8 s | Rule of thumb: long enough to read, short enough not to leave |
| Join in progress | first 20 s, only into a short team | Rule of thumb |
| AFK removal | 90 s without moving 2 studs, queued or spectating only | Rule of thumb |

---

## 8. Extending it

- **Modes per arena.** Give each arena a `Mode` attribute and pass the runner to a mode module with `Start`, `Stop`, `Winner` functions, exactly the contract in [[Round-Based Minigame Loop End to End]], but called per arena.
- **Parties.** Queue a party as a unit and keep them on the same team when the party is smaller than a team; balance the rest around them.
- **Seasonal rating resets.** Soft reset towards 1000 at season start (`rating = 1000 + (rating - 1000) * 0.5`), see [[Economy Resets and Seasonal Wipes]].
- **Combat.** Elimination here is any death; plug in the server hitboxes from [[Melee Combat System End to End]] and make sure friendly fire checks use `ArenaTeam`, not `Player.Team`.

---

## 9. Test checklist

- [ ] Two arenas, four test clients: both arenas run rounds at the same time; ending one does not affect the other.
- [ ] Leave during countdown: countdown cancels when the queue drops below the requirement.
- [ ] Leave mid-round as the last player on a team: the other team wins; no rewards if under 20 s.
- [ ] Join during the first 20 s with a short team: you enter the round; after 20 s: you spectate, then play next round.
- [ ] Spectator cycles only through alive players in the same arena; camera returns to own character after the round.
- [ ] End a round early by elimination, start the next one immediately: the old time-limit timer does not end it.
- [ ] Fuzz `ArenaJoin` with long strings, numbers, unknown names, and rapid repeats.
- [ ] Ratings: a 2v2 between equal teams moves each player by 12 points.

## See also
- [[Round-Based Minigame Loop End to End]], [[Genre Playbook - Party and Minigame Collections]], [[Genre Playbook - Battlegrounds and Arena Fighters]]
- [[Spawning Teams and Rounds]], [[Camera Systems]], [[Social Design and Multiplayer Play]]
- [[Genre Systems Start Here]], [[Saved Inventory End to End]], [[Lobby and Hub Design]]

## Connected notes
<!-- auto-links:start -->
[[Links - Rounds and matchmaking]] · [[Genre Playbook - Sports]] · [[Spawn Points Safe Zones and Respawn Flow]] · [[Matchmaking Queues with MemoryStore]] · [[Level Design Start Here]] · [[Combat Arena and Encounter Layout]]
<!-- auto-links:end -->
