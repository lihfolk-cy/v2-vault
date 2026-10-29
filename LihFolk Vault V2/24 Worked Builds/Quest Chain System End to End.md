---
tags: [worked-build, quests, objectives, progression, datastore, ui, luau, server-authority, type/guide, area/gameplay, level/intermediate, api/ProximityPrompt]
---
# Quest Chain System End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Saving the quest index. It breaks on the first content update.
> - Avoid: Client-side progress counting "because the server also checks later".
> - Avoid: One giant `if kind == ... elseif` per quest.
> - Template includes `Quests = { Completed = {}, Active = { Id = "", Count = 0 } }`
> - Every quest id is unique; ids are never renamed without an alias
> - No client remote can add progress
>
> Cost: TL;DR ~140 tok · whole note ~9.8k tok. Read more: ## 4. Server modules: PlayerStore and RateLimit · ## 5. QuestService (server module) · ## 10. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

This note builds a linear quest chain from an empty place: quests defined as data, progress reported only by server systems (collect, defeat, talk), a claim button with rewards, saved progress that survives reordering and new quests, a tracker UI with a waypoint beam, per-player collectibles, and enemies that credit the player who last hit them.

The design theory (why chains, how long each step should be, branching vs linear) is in [[Quests and Objectives]] and [[Progression and Pacing Design]]. Onboarding chains specifically are covered in [[First-Time User Experience and Onboarding]]. This note is the build. Other builds: [[Worked Builds Start Here]].

> **All code in this note is reviewed, not run.** Written against Roblox docs (as of October 2026) and checked by reading. Use section 8 to test it.

Labels: **Roblox docs (as of October 2026)**, **rule of thumb**.

---

## 1. The one rule that shapes everything

**The client never reports progress.** There is no "I collected a crystal" remote. Progress comes from server code that already knows the truth: a `ProximityPrompt.Triggered` handler on the server, an enemy's `Died` event on the server, a server-side talk prompt. The only quest remote the client may fire is "claim", and the server checks that the quest is actually complete.

This is the most common quest exploit in the wild: a `QuestProgress:FireServer("Slime", 9999)` remote that someone forgot to validate (see [[Economy Exploits - Dupes Races and Purchase Abuse]]).

Other decisions:

| Question | Choice | Why |
|---|---|---|
| How progress is saved | `Completed = { [questId] = true }` plus `Active = { Id, Count }` | Adding quests to the end, inserting quests in the middle, or reordering does not corrupt anyone's progress |
| How the current quest is found | First quest in the chain not in `Completed` | Derived, not stored, so it can never point at a deleted quest |
| How the client learns progress | Attributes `QuestId`, `QuestCount` on the Player | Replicates automatically, survives the client rejoining, no sync remote |
| Claim or auto-complete | Manual claim by default, `AutoClaim` flag in config | A claim moment is a reward beat (see [[Game Feel and Juice]]); auto is better for long chains of tiny steps |
| Shared or per-player collectibles | Per-player cooldowns | Shared nodes cause griefing and "someone took my crystal" frustration in quest areas (rule of thumb) |

When **not** to use a single linear chain: if your game needs several concurrent quests (daily quests plus a story chain plus an event), make `Active` a dictionary of chains. Section 10 sketches it.

---

## 2. Folder layout

```
ReplicatedStorage
  Shared (Folder)
    QuestConfig (ModuleScript)
  QuestRemotes (Folder, created by the server)
    Claim (RemoteEvent, client to server)
    Completed (RemoteEvent, server to client)
    CrystalCollected (RemoteEvent, server to client)

ServerScriptService
  Modules (Folder)
    PlayerStore (ModuleScript)
    RateLimit (ModuleScript)
    QuestService (ModuleScript)
  QuestWorld (Script)

ServerStorage
  Enemies (Folder)
    Slime (Model with Humanoid and HumanoidRootPart)

Workspace
  Crystals (Folder of Parts, each with a ProximityPrompt)
  SlimeSpawns (Folder of Parts)
  NPCs (Folder)
    Elder (Model with a ProximityPrompt in its head or root)
  QuestMarkers (Folder of small anchored, invisible Parts named after waypoints)
    CrystalField, SlimePit, Elder

StarterGui
  QuestGui (ScreenGui, ResetOnSpawn = false)
    Tracker (Frame)
      Title (TextLabel)
      Progress (TextLabel)
      Claim (TextButton, Visible = false)
    Toast (TextLabel, Visible = false)

StarterPlayer
  StarterPlayerScripts
    QuestClient (LocalScript)
```

Enable **Game Settings > Security > Enable Studio Access to API Services** for save tests.

---

## 3. Quest data

```lua
--!strict
-- ReplicatedStorage/Shared/QuestConfig (ModuleScript). Reviewed, not run.
export type Objective = {
	Kind: string,   -- "Collect" | "Defeat" | "Talk" (add your own)
	Target: string, -- what counts: "Crystal", "Slime", "Elder"
	Amount: number,
}

export type QuestDef = {
	Id: string,          -- never rename once shipped; see Aliases
	Title: string,
	Description: string,
	Objective: Objective,
	Reward: { Coins: number },
	Waypoint: string?,   -- name of a part in Workspace.QuestMarkers
}

local Chain: { QuestDef } = {
	{
		Id = "crystals_1", Title = "Shiny Rocks", Description = "Collect 5 crystals",
		Objective = { Kind = "Collect", Target = "Crystal", Amount = 5 },
		Reward = { Coins = 50 }, Waypoint = "CrystalField",
	},
	{
		Id = "slimes_1", Title = "Slime Trouble", Description = "Defeat 3 slimes",
		Objective = { Kind = "Defeat", Target = "Slime", Amount = 3 },
		Reward = { Coins = 120 }, Waypoint = "SlimePit",
	},
	{
		Id = "elder_1", Title = "Report Back", Description = "Talk to the Elder",
		Objective = { Kind = "Talk", Target = "Elder", Amount = 1 },
		Reward = { Coins = 200 }, Waypoint = "Elder",
	},
	{
		Id = "crystals_2", Title = "Crystal Hoarder", Description = "Collect 20 crystals",
		Objective = { Kind = "Collect", Target = "Crystal", Amount = 20 },
		Reward = { Coins = 400 }, Waypoint = "CrystalField",
	},
}

local QuestConfig = {
	Chain = Chain,
	AutoClaim = false,
	-- If you must rename an id after launch: Aliases[newId] = oldId,
	-- so players who completed the old id are not sent back to it.
	Aliases = {} :: { [string]: string },
}

function QuestConfig.Find(id: string): QuestDef?
	for _, quest in Chain do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

-- Validate at require time so a typo fails loudly in Studio, not silently live.
do
	local seen: { [string]: boolean } = {}
	for _, quest in Chain do
		assert(not seen[quest.Id], `Duplicate quest id {quest.Id}`)
		assert(quest.Objective.Amount >= 1, `Quest {quest.Id} needs Amount >= 1`)
		seen[quest.Id] = true
	end
end

return QuestConfig
```

Why ids and not positions: a save that says "player is on quest 3" breaks the day you insert a new quest 2. A save that says "completed crystals_1 and slimes_1" stays correct whatever you do to the order. The only operation that hurts is renaming an id, which is what `Aliases` is for (more in [[Schema Migrations - Worked Case Studies]]).

---

## 4. Server modules: PlayerStore and RateLimit

The same `PlayerStore` used by every saving build in this folder (reasoning in [[Round-Based Minigame Loop End to End]] section 4):

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

And the per-player token bucket:

```lua
--!strict
-- ServerScriptService/Modules/RateLimit (ModuleScript). Reviewed, not run.
-- newLimiter(capacity, refillPerSecond) returns allow(player) -> boolean.
local Players = game:GetService("Players")

local function newLimiter(capacity: number, refillPerSecond: number): (Player) -> boolean
	local buckets: { [Player]: { tokens: number, at: number } } = {}
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
	return function(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player] or { tokens = capacity, at = now }
		buckets[player] = bucket
		bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.at) * refillPerSecond)
		bucket.at = now
		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end
end

return newLimiter
```

---

## 5. QuestService (server module)

Other server scripts call `QuestService.Report(player, kind, target, amount)`. Nothing on the client can.

```lua
--!strict
-- ServerScriptService/Modules/QuestService (ModuleScript). Reviewed, not run.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local QuestConfig = require(ReplicatedStorage.Shared.QuestConfig)
local PlayerStore = require(ServerScriptService.Modules.PlayerStore)
local newLimiter = require(ServerScriptService.Modules.RateLimit)

type QuestState = {
	Completed: { [string]: boolean },
	Active: { Id: string, Count: number },
}

local QuestService = {}

local remotes = Instance.new("Folder")
remotes.Name = "QuestRemotes"
local claimRemote = Instance.new("RemoteEvent")
claimRemote.Name = "Claim"
claimRemote.Parent = remotes
local completedRemote = Instance.new("RemoteEvent")
completedRemote.Name = "Completed"
completedRemote.Parent = remotes
local crystalRemote = Instance.new("RemoteEvent")
crystalRemote.Name = "CrystalCollected"
crystalRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

QuestService.CrystalRemote = crystalRemote

local claimAllowed = newLimiter(3, 1)

local function stateOf(player: Player): (PlayerStore.Data?, QuestState?)
	local data = PlayerStore.Get(player)
	if not data then
		return nil, nil
	end
	return data, data.Quests :: QuestState
end

local function isCompleted(state: QuestState, id: string): boolean
	if state.Completed[id] then
		return true
	end
	local old = QuestConfig.Aliases[id]
	return old ~= nil and state.Completed[old] == true
end

-- Current quest = first in the chain that is not completed. Resets Count if it changed.
local function ensureActive(state: QuestState): QuestConfig.QuestDef?
	for _, quest in QuestConfig.Chain do
		if not isCompleted(state, quest.Id) then
			if state.Active.Id ~= quest.Id then
				state.Active.Id = quest.Id
				state.Active.Count = 0
			end
			return quest
		end
	end
	state.Active.Id = ""
	state.Active.Count = 0
	return nil
end

local function publish(player: Player, state: QuestState)
	local quest = ensureActive(state)
	player:SetAttribute("QuestId", if quest then quest.Id else "")
	player:SetAttribute("QuestCount", state.Active.Count)
end

local function addCoins(player: Player, data: PlayerStore.Data, amount: number)
	data.Coins += amount
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
	if coins then
		coins.Value = data.Coins
	end
end

local function claim(player: Player): boolean
	local data, state = stateOf(player)
	if not data or not state then
		return false
	end
	local quest = ensureActive(state)
	if not quest or state.Active.Count < quest.Objective.Amount then
		return false -- early claim, double claim, or chain finished
	end
	-- Mark complete before granting, all without yielding, so a second claim in
	-- the same frame finds the next quest (at Count 0) and fails.
	state.Completed[quest.Id] = true
	addCoins(player, data, quest.Reward.Coins)
	publish(player, state)
	completedRemote:FireClient(player, quest.Id)
	PlayerStore.SaveNow(player) -- quest completions are worth an early save
	return true
end

--- Called by server systems only. kind/target must match the quest's objective exactly.
function QuestService.Report(player: Player, kind: string, target: string, amount: number?)
	local _, state = stateOf(player)
	if not state then
		return
	end
	local quest = ensureActive(state)
	if not quest then
		return
	end
	local objective = quest.Objective
	if objective.Kind ~= kind or objective.Target ~= target then
		return
	end
	local add = math.floor(amount or 1)
	if add < 1 then
		return
	end
	if state.Active.Count >= objective.Amount then
		return -- already full, waiting for claim
	end
	state.Active.Count = math.min(objective.Amount, state.Active.Count + add)
	publish(player, state)
	if state.Active.Count >= objective.Amount and QuestConfig.AutoClaim then
		claim(player)
	end
end

function QuestService.Start()
	PlayerStore.OnLoaded(function(player: Player)
		local data, state = stateOf(player)
		if not data or not state then
			return
		end
		-- Schema hygiene for records saved before quests existed.
		if type(state.Completed) ~= "table" then
			state.Completed = {}
		end
		if type(state.Active) ~= "table" then
			state.Active = { Id = "", Count = 0 }
		end
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = data.Coins
		coins.Parent = leaderstats
		leaderstats.Parent = player
		publish(player, state)
	end)

	claimRemote.OnServerEvent:Connect(function(player: Player)
		if claimAllowed(player) then
			claim(player)
		end
	end)
end

return QuestService
```

Notes on the edge cases:
- **The template must contain `Quests`.** `PlayerStore` only fills missing top-level keys, so the template in section 6 includes `Quests = { Completed = {}, Active = { Id = "", Count = 0 } }`. The type checks in `Start` cover a corrupted or hand-edited record.
- **Count resets when the active quest changes.** If you insert a quest before the one a player is halfway through, they move to the new quest and their partial count is lost. That is usually right (the count belonged to a different objective). Completed quests are never lost.
- **Overflow is capped.** Progress past `Amount` is dropped, not banked. Banking ("you already have 30 crystals, so the next quest completes instantly") feels like a bug to players (rule of thumb).

---

## 6. QuestWorld (server script: crystals, enemies, NPCs)

This script is the bridge between the world and `QuestService`. Every `Report` call sits behind a server-side check.

```lua
--!strict
-- ServerScriptService/QuestWorld (Script). Reviewed, not run.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerStore = require(ServerScriptService.Modules.PlayerStore)
local QuestService = require(ServerScriptService.Modules.QuestService)

PlayerStore.Start({
	Coins = 0,
	Quests = { Completed = {}, Active = { Id = "", Count = 0 } },
})
QuestService.Start()

local PROMPT_RANGE = 12          -- server-side distance limit for any quest prompt
local CRYSTAL_COOLDOWN = 15      -- per player, per crystal
local LAST_HIT_WINDOW = 10       -- seconds a hit keeps kill credit
local SLIME_COUNT = 6

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function inRange(player: Player, position: Vector3): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - position).Magnitude <= PROMPT_RANGE
end

---------------------------------------------------------------- crystals (per-player cooldown)
local collectedAt: { [Player]: { [BasePart]: number } } = {}
Players.PlayerRemoving:Connect(function(player)
	collectedAt[player] = nil
end)

local function hookCrystal(crystal: Instance)
	if not crystal:IsA("BasePart") then
		return
	end
	local prompt = crystal:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.ActionText = "Collect"
	prompt.Triggered:Connect(function(player: Player)
		if not inRange(player, crystal.Position) then
			return
		end
		local mine = collectedAt[player] or {}
		collectedAt[player] = mine
		local now = os.clock()
		if now - (mine[crystal] or -math.huge) < CRYSTAL_COOLDOWN then
			return
		end
		mine[crystal] = now
		QuestService.Report(player, "Collect", "Crystal", 1)
		-- Tell only this client to hide the crystal for the cooldown.
		QuestService.CrystalRemote:FireClient(player, crystal, CRYSTAL_COOLDOWN)
	end)
end

local crystals = workspace:WaitForChild("Crystals")
for _, crystal in crystals:GetChildren() do
	hookCrystal(crystal)
end
crystals.ChildAdded:Connect(hookCrystal)

---------------------------------------------------------------- NPC talk
local npcs = workspace:WaitForChild("NPCs")
local function hookNpc(npc: Instance)
	if not npc:IsA("Model") then
		return
	end
	local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		return
	end
	prompt.ActionText = "Talk"
	prompt.ObjectText = npc.Name
	prompt.Triggered:Connect(function(player: Player)
		if inRange(player, npc:GetPivot().Position) then
			QuestService.Report(player, "Talk", npc.Name, 1)
		end
	end)
end
for _, npc in npcs:GetChildren() do
	hookNpc(npc)
end
npcs.ChildAdded:Connect(hookNpc)

---------------------------------------------------------------- enemies (credit the last hitter)
-- Your combat system must set two attributes on the enemy model when a player hits it:
--   LastAttackerId (number, the attacker's UserId) and LastAttackedAt (number, os.clock()).
-- The melee build in this folder does exactly that.
local template = ServerStorage:WaitForChild("Enemies"):WaitForChild("Slime") :: Model
local spawnPoints = workspace:WaitForChild("SlimeSpawns"):GetChildren()
local alive = 0

local function spawnSlime()
	local point = spawnPoints[math.random(1, #spawnPoints)]
	if not point:IsA("BasePart") then
		return
	end
	local slime = template:Clone()
	slime:SetAttribute("EnemyType", "Slime")
	slime:PivotTo(point.CFrame + Vector3.new(0, 3, 0))
	slime.Parent = workspace
	alive += 1

	local humanoid = slime:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("Slime template needs a Humanoid")
		return
	end
	humanoid.Died:Connect(function()
		alive -= 1
		local attackerId = slime:GetAttribute("LastAttackerId")
		local attackedAt = slime:GetAttribute("LastAttackedAt")
		if typeof(attackerId) == "number" and typeof(attackedAt) == "number"
			and os.clock() - attackedAt <= LAST_HIT_WINDOW then
			local killer = Players:GetPlayerByUserId(attackerId)
			if killer then
				QuestService.Report(killer, "Defeat", "Slime", 1)
			end
		end
		task.delay(3, function()
			slime:Destroy()
		end)
	end)
end

task.spawn(function()
	while true do
		while alive < SLIME_COUNT do
			spawnSlime()
		end
		task.wait(5)
	end
end)
```

Why the attributes are set by the server combat code and read here, rather than the kill being reported by the attacker's client: an exploiter could otherwise kill nothing and claim everything. Because the attributes live on a server-owned model and are written by server code, a client cannot forge them (client attribute writes do not replicate, Roblox docs).

Kill credit is a design decision, not just plumbing. "Last hit" is simple but lets a player steal kills by tapping a nearly dead slime. Alternatives: credit everyone who dealt at least 20% of max health, or credit everyone within 40 studs. For a quest step in a shared area, crediting all contributors is friendlier (rule of thumb).

---

## 7. Client: tracker, waypoint and crystals

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/QuestClient (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestConfig"))
local remotes = ReplicatedStorage:WaitForChild("QuestRemotes")
local claimRemote = remotes:WaitForChild("Claim") :: RemoteEvent
local completedRemote = remotes:WaitForChild("Completed") :: RemoteEvent
local crystalRemote = remotes:WaitForChild("CrystalCollected") :: RemoteEvent

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("QuestGui") :: ScreenGui
local tracker = gui:WaitForChild("Tracker") :: Frame
local titleLabel = tracker:WaitForChild("Title") :: TextLabel
local progressLabel = tracker:WaitForChild("Progress") :: TextLabel
local claimButton = tracker:WaitForChild("Claim") :: TextButton
local toast = gui:WaitForChild("Toast") :: TextLabel
local markers = workspace:WaitForChild("QuestMarkers")

---------------------------------------------------------------- waypoint beam
local beam: Beam? = nil
local fromAttachment: Attachment? = nil

local function clearWaypoint()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if fromAttachment then
		fromAttachment:Destroy()
		fromAttachment = nil
	end
end

local function setWaypoint(name: string?)
	clearWaypoint()
	if not name then
		return
	end
	local marker = markers:FindFirstChild(name)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not marker or not marker:IsA("BasePart") or not root then
		return
	end
	local toAttachment = marker:FindFirstChild("QuestTarget") :: Attachment?
	if not toAttachment then
		local created = Instance.new("Attachment")
		created.Name = "QuestTarget"
		created.Parent = marker
		toAttachment = created
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "QuestFrom"
	a0.Parent = root
	fromAttachment = a0
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = toAttachment
	b.Width0 = 0.4
	b.Width1 = 0.4
	b.FaceCamera = true
	b.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
	b.Transparency = NumberSequence.new(0.3)
	b.Parent = marker -- client-created, so only this player sees it
	beam = b
end

---------------------------------------------------------------- tracker
local function refresh()
	local id = player:GetAttribute("QuestId")
	local count = player:GetAttribute("QuestCount")
	local quest = if typeof(id) == "string" and id ~= "" then QuestConfig.Find(id) else nil
	if not quest then
		titleLabel.Text = "All quests complete"
		progressLabel.Text = ""
		claimButton.Visible = false
		setWaypoint(nil)
		return
	end
	local n = if typeof(count) == "number" then count else 0
	titleLabel.Text = quest.Title
	progressLabel.Text = `{quest.Description}: {n}/{quest.Objective.Amount}`
	local done = n >= quest.Objective.Amount
	claimButton.Visible = done and not QuestConfig.AutoClaim
	-- Hide the beam once the objective is done: the next step is the Claim button.
	setWaypoint(if done then nil else quest.Waypoint)
end

player:GetAttributeChangedSignal("QuestId"):Connect(refresh)
player:GetAttributeChangedSignal("QuestCount"):Connect(refresh)
player.CharacterAdded:Connect(function()
	task.wait() -- let the root part exist before attaching
	refresh()
end)
refresh()

local claimPending = false
claimButton.Activated:Connect(function()
	if claimPending then
		return
	end
	claimPending = true
	claimRemote:FireServer()
	task.delay(0.5, function()
		claimPending = false
	end)
end)

completedRemote.OnClientEvent:Connect(function(questId: string)
	local quest = QuestConfig.Find(questId)
	if not quest then
		return
	end
	toast.Text = `Quest complete: {quest.Title}  +{quest.Reward.Coins} coins`
	toast.Visible = true
	task.delay(2.5, function()
		toast.Visible = false
	end)
end)

---------------------------------------------------------------- per-player crystals
crystalRemote.OnClientEvent:Connect(function(crystal: BasePart?, seconds: number)
	if not crystal then
		return -- streamed out on this client; nothing to hide
	end
	local prompt = crystal:FindFirstChildWhichIsA("ProximityPrompt")
	local oldTransparency = crystal.Transparency
	crystal.Transparency = 0.85 -- local only; other players still see it
	if prompt then
		prompt.Enabled = false
	end
	task.delay(seconds, function()
		crystal.Transparency = oldTransparency
		if prompt then
			prompt.Enabled = true
		end
	end)
end)
```

Note that hiding the crystal on the client is presentation only. If an exploiter re-enables the prompt locally, the server still refuses because of the per-player cooldown table. The client hides; the server decides.

UI notes: keep the tracker in a corner inside the safe area (see [[Safe Areas and Insets]] and [[HUD Design]]); make `Claim` big and bright, since it is the reward moment; on phones, keep the tracker collapsible so it does not cover the thumbstick. With StreamingEnabled, a far-away marker part may not exist on the client, so the beam silently disappears; put QuestMarkers inside a Model with ModelStreamingMode = Persistent (see [[Instance Streaming]]).

---

## 8. Testing in Studio

1. **Happy path.** Play. Tracker shows "Shiny Rocks 0/5" and a beam to the crystal field. Collect five crystals (each dims for you only). Claim appears; press it. Toast, +50 coins, tracker moves to "Slime Trouble".
2. **Kill credit without combat.** If you have not built combat yet, simulate a hit in the server command bar:
   ```lua
   local p = game.Players:GetPlayers()[1]
   for _, m in workspace:GetChildren() do
   	if m:GetAttribute("EnemyType") == "Slime" then
   		m:SetAttribute("LastAttackerId", p.UserId)
   		m:SetAttribute("LastAttackedAt", os.clock())
   		m:FindFirstChildOfClass("Humanoid").Health = 0
   		break
   	end
   end
   ```
   Run it three times; the quest should fill.
3. **Persistence.** Finish two quests, stop, play. You resume at quest 3 with zero partial progress lost from completed quests.
4. **Reorder test.** Stop. Move `elder_1` to the top of the chain. Play. You should see "Report Back" (it is now the first incomplete quest). Your completed quests stay completed.
5. **Abuse.** In the client command bar, spam `game.ReplicatedStorage.QuestRemotes.Claim:FireServer()` 100 times while the quest is not complete. Nothing happens. Complete the quest, then spam again: exactly one reward.
6. **Per-player crystals.** Two clients. Player 1 collects a crystal: it dims for player 1 only; player 2 can still collect it.
7. **Prompt range.** Set a crystal's prompt `MaxActivationDistance` to 200 temporarily and trigger it from far away: no progress (server range check).

---

## 9. Exploits it must resist

| Attack | Defence |
|---|---|
| Fake progress remote | There is none; only server code calls `Report` |
| Claiming before completion, or twice | Server re-checks count; completion is marked before granting, with no yield |
| Claim spam | Rate limit plus the above |
| Collecting from across the map | Server distance check on every prompt |
| Farming one crystal | Per-player, per-crystal cooldown on the server |
| Forging kill credit | Attributes written by server combat code on server-owned enemies |
| Kill stealing | Design choice; see section 6 for contributor credit |
| Editing quest state through a remote | No remote writes quest state |

Background: [[Server Authority and Validation]], [[Testing Your Own Remotes - Fuzzing and Abuse Tests]].

---

## 10. Common mistakes

- **Saving the quest index.** It breaks on the first content update. Save ids.
- **Client-side progress counting** "because the server also checks later". If the server checks, let the server count.
- **One giant `if kind == ... elseif` per quest.** Keep objectives as data (`Kind`, `Target`, `Amount`) and the code generic; new quests should not need code.
- **Shared resource nodes in a quest area.** Ten new players fighting over five crystals is a bad first five minutes (see [[First-Time User Experience and Onboarding]]).
- **Forgetting players who finished the chain** before you added more quests. With the `Completed` set design, they automatically get the new ones. With an index design they are stuck at "complete" or skipped past.
- **Waypoint beams parented to the character only.** They vanish on respawn; the `CharacterAdded` refresh rebuilds them.

---

## 11. Extending it

- **Concurrent chains.** Change `Active` to `{ [chainName]: { Id, Count } }` and run `ensureActive` per chain. Daily quests become a chain whose `Completed` set is reset at the daily boundary (see [[Daily Rewards System End to End]] for safe day boundaries).
- **Branching.** Give each quest an optional `Requires = { "questA" }`; the active quest is the first one whose requirements are all completed.
- **Dialogue.** Fire a dialogue remote from the NPC prompt handler with lines from config; see [[Cameras and Cutscenes]] for framing.
- **Rewards beyond coins.** Items from [[Saved Inventory End to End]], pets from [[Pet Hatching and Following End to End]], rebirth tokens from [[Rebirth and Prestige System End to End]].
- **Analytics.** Log each quest completion as a funnel step to find where players quit the chain (see [[Analytics and Funnels]]). The exact `AnalyticsService` funnel method signature was not verified for this note; check the current API reference.
- **Combat credit.** The [[Melee Combat System End to End]] build sets `LastAttackerId` and `LastAttackedAt` on every hit.

---

## 12. Checklist

- [ ] Template includes `Quests = { Completed = {}, Active = { Id = "", Count = 0 } }`
- [ ] Every quest id is unique; ids are never renamed without an alias
- [ ] No client remote can add progress
- [ ] Every prompt handler re-checks distance on the server
- [ ] Claim marks complete before rewarding, with no yield in between
- [ ] Waypoint names match parts in `Workspace.QuestMarkers`
- [ ] Reorder, persistence, claim-spam and two-client tests pass

## See also
[[Worked Builds Start Here]] · [[Quests and Objectives]] · [[Progression and Pacing Design]] · [[First-Time User Experience and Onboarding]] · [[Schema Migrations - Worked Case Studies]] · [[Melee Combat System End to End]] · [[Beams and Trails]]

## Nuances and edge cases

1. **Waypoints and streaming.** With instance streaming on, the quest target (an NPC far away, a crystal in another zone) may not exist on the client. A waypoint that points at the instance fails silently. Replicate the target's position (an attribute holding a Vector3, or a small always-streamed marker part) rather than relying on the instance itself, and update it when the target moves.
2. **Group play and credit.** "Kill 10 slimes" in a crowded area turns into kill stealing; the last-hit rule frustrates players who did most of the damage. Contributor credit (everyone who dealt meaningful damage within a time window gets the count) is friendlier, but it lets groups complete quests faster. Decide which you want, and use the same rule for every kill quest.
3. **Server population changes the content.** A collect quest with five crystals is fine on a 10-player server and miserable on a 50-player server where everyone is on the same step. Per-player cooldowns (as built here) or per-player instances of collectibles scale; shared nodes do not. On very large servers, spread early quests across more locations.
4. **Places and teleports.** If quests continue across places (a hub and dungeons), progress must save before teleport and load on arrival. Reporting progress in a place where the profile is still loading, or after it has been released for teleport, loses counts. Report only while the profile is active, and save before the teleport begins.
5. **Content updates in the middle of a chain.** The `Completed` set survives adding and reordering quests, but changing an existing quest's objective (from 5 slimes to 10) while players are on it can leave someone at 7 of 5 or reset their count. Treat a changed objective as a new quest id, or clamp counts on load.
6. **Reward pacing as the chain grows.** Rewards that suited a 10-quest launch chain may be far too small or large when the chain is 60 quests long and players are much stronger. Scale rewards from the quest's position or the player's progression, not hand-typed numbers, and check the total reward of the chain against the economy.
7. **Daily and event quests.** Quest types that reset on a schedule need UTC day boundaries and must not reset progress for a quest the player is mid-way through at the boundary without telling them. Time-limited event chains need an end date in config and a plan for players who were halfway when it ended.
8. **Funnel data is the payoff.** A linear chain is the best funnel you will ever get: each quest is a step. Logging completions (AnalyticsService has funnel event methods; check the current reference for signatures) shows exactly which quest players quit on, which is usually a difficulty spike or unclear text.

## More common mistakes

1. **Waypoints pointing at streamed-out instances.** Symptom: the quest arrow disappears in large maps. Fix: replicate target positions.
2. **Last-hit credit only.** Symptom: complaints about stolen kills in busy areas. Fix: contributor credit within a time window.
3. **Changing an active quest's objective in place.** Symptom: players stuck at counts above or below the new target. Fix: new quest id, or clamp on load.
4. **Reporting progress during teleport.** Symptom: the last kill or pickup before a teleport is lost. Fix: save first, block reports while the profile is releasing.
5. **Quest text built from fragments.** Symptom: broken sentences in translated games. Fix: one key per sentence with placeholders for the target and amount.
6. **No end handling for event chains.** Symptom: event quests stay active after the event, pointing at removed content. Fix: an end date, and closing logic for unfinished quests.

## Related decisions

- [[Quest Writing and Hooks]]: what makes each step worth doing.
- [[Dialogue System End to End]]: the NPC side of quest givers.
- [[Session State Across Places]]: keeping quest progress across teleports.
- [[Instance Streaming]]: why waypoints should not depend on far instances.
- [[Teaching Through Level Design]]: using early quests to teach mechanics in the space.
- [[Retention and Return Hooks]]: daily and event chains as reasons to return.
- [[Battle Pass and Season Design]]: seasonal quest tracks built on the same engine.
- [[Localization-Ready Writing]]: quest text that translates cleanly.
- [[Progression and Pacing Design]]: tuning rewards as the chain grows.

## Connected notes
<!-- auto-links:start -->
[[Narrative Start Here]] · Official Docs - Game Systems · Menu Archetypes - Shop Settings Codes Rewards · Core Loops and Session Design · Onboarding Funnel · Skill - Roblox System Builder
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[LihFolk Systems Library]] · [[Codes Redemption System End to End]] · [[Global Leaderboards End to End]] · [[Weekend Build - Survival Gather, Craft and Place]] · [[Shop with Game Passes and Developer Products End to End]] · [[LihFolk Systems - Data and Purchase Guarantees]] · [[Weekend Build - Arena Shooter with Server-Checked Hits]] · [[Weekend Build - Roleplay Town with Jobs and Paychecks]]
<!-- related:end -->
