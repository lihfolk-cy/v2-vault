--!strict
-- LihFolk Systems: Quests
-- Install: ServerScriptService/LihFolk/Quests (ModuleScript)
--
-- Quests are data. Progress is reported ONLY by server systems
-- (Quests.Report(player, "Collect", "Coin", 1) from your pickup code), never by
-- a client remote. A quest is active when every quest in `requires` has been
-- claimed and it has not been claimed itself; this covers linear chains and
-- parallel quests. Claiming checks completion and bag space, then marks and
-- grants in one synchronous block.
-- Remotes: Quests.Get() -> list, Quests.Claim(questId)
-- Push:    Quests.Changed(list), coalesced to at most one per 0.5 s per player
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)

local T = Net.T

export type Objective = { kind: string, target: string, amount: number, text: string? }

export type QuestDef = {
	id: string,
	title: string,
	objectives: { Objective },
	reward: Rewards.Reward,
	requires: { string }?,
}

export type Config = { quests: { QuestDef } }

type State = { Progress: { [string]: { number } }, Claimed: { [string]: number } }

local Quests = {}

local list: { QuestDef } = {}
local byId: { [string]: QuestDef } = {}
local changedPush: Net.Push? = nil
local pushPending: { [Player]: boolean } = {}
local PUSH_INTERVAL = 0.5

---------------------------------------------------------------------------
-- Pure (exported for tests)
---------------------------------------------------------------------------

function Quests.isActive(quest: QuestDef, claimed: { [string]: number }): boolean
	if claimed[quest.id] then
		return false
	end
	for _, required in quest.requires or {} do
		if not claimed[required] then
			return false
		end
	end
	return true
end

-- Adds amount to matching objectives (target "*" matches any). Returns true if anything changed.
function Quests.applyProgress(quest: QuestDef, progress: { number }, kind: string, target: string, amount: number): boolean
	local changed = false
	for i, objective in quest.objectives do
		if objective.kind == kind and (objective.target == target or objective.target == "*") then
			local current = progress[i] or 0
			if current < objective.amount then
				progress[i] = math.min(objective.amount, current + amount)
				changed = true
			end
		end
	end
	-- Keep the array dense for saving.
	for i = 1, #quest.objectives do
		if progress[i] == nil then
			progress[i] = 0
		end
	end
	return changed
end

function Quests.isComplete(quest: QuestDef, progress: { number }?): boolean
	for i, objective in quest.objectives do
		if not progress or (progress[i] or 0) < objective.amount then
			return false
		end
	end
	return true
end

---------------------------------------------------------------------------
-- Internals
---------------------------------------------------------------------------

local function stateOf(profile: PlayerData.Profile): State
	return profile.Data.Quests :: State
end

local function view(state: State): { { [string]: any } }
	local out = {}
	for _, quest in list do
		if Quests.isActive(quest, state.Claimed) then
			local progress = state.Progress[quest.id] or {}
			local objectives = {}
			for i, objective in quest.objectives do
				table.insert(objectives, {
					text = objective.text or `{objective.kind} {objective.amount} {objective.target}`,
					current = progress[i] or 0,
					amount = objective.amount,
				})
			end
			table.insert(out, {
				id = quest.id,
				title = quest.title,
				objectives = objectives,
				reward = Rewards.Describe(quest.reward),
				complete = Quests.isComplete(quest, progress),
			})
		end
	end
	return out
end

local function schedulePush(player: Player)
	if pushPending[player] then
		return
	end
	pushPending[player] = true
	task.delay(PUSH_INTERVAL, function()
		pushPending[player] = nil
		local profile = PlayerData.Get(player)
		if profile and changedPush then
			changedPush:Fire(player, view(stateOf(profile)))
		end
	end)
end

---------------------------------------------------------------------------
-- Public API (server systems call Report)
---------------------------------------------------------------------------

-- Reports progress from a SERVER system. kind/target are your own strings
-- ("Collect"/"Coin", "Defeat"/"Slime", "Talk"/"Guide"). Synchronous.
function Quests.Report(player: Player, kind: string, target: string, amount: number?)
	local n = amount or 1
	if type(n) ~= "number" or n ~= n or n <= 0 or n >= math.huge then
		return
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	local state = stateOf(profile)
	local changed = false
	for _, quest in list do
		if Quests.isActive(quest, state.Claimed) then
			local progress = state.Progress[quest.id]
			if not progress then
				progress = {}
				state.Progress[quest.id] = progress
			end
			if Quests.applyProgress(quest, progress, kind, target, n) then
				changed = true
			end
		end
	end
	if changed then
		PlayerData.MarkDirty(profile)
		schedulePush(player)
	end
end

local function claim(player: Player, questId: string): Net.Result
	local quest = byId[questId]
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local state = stateOf(profile)
	if not Quests.isActive(quest, state.Claimed) then
		return Net.fail(if state.Claimed[questId] then "AlreadyClaimed" else "Locked")
	end
	if not Quests.isComplete(quest, state.Progress[questId]) then
		return Net.fail("NotComplete")
	end
	local fits, code = Rewards.CanGrant(player, quest.reward)
	if not fits then
		return Net.fail(code or "BagFull")
	end
	-- Mark and grant together, no yield in between.
	state.Claimed[questId] = os.time()
	state.Progress[questId] = nil -- keep the save small
	Rewards.Grant(player, quest.reward, `quest:{questId}`, false, false)
	PlayerData.MarkDirty(profile)
	schedulePush(player)
	return Net.ok({ reward = Rewards.Describe(quest.reward) })
end

function Quests.Init(config: Config)
	for _, quest in config.quests do
		assert(type(quest.id) == "string" and string.match(quest.id, "^[%w_]+$"), `Quests: bad id {quest.id}`)
		assert(byId[quest.id] == nil, `Quests: duplicate id {quest.id}`)
		assert(#quest.objectives >= 1, `Quest {quest.id}: no objectives`)
		for i, objective in quest.objectives do
			assert(objective.amount >= 1 and objective.amount < 2 ^ 53, `Quest {quest.id} objective {i}: bad amount`)
		end
		Rewards.Validate(`Quest {quest.id}`, quest.reward)
		byId[quest.id] = quest
		table.insert(list, quest)
	end
	for _, quest in list do
		for _, required in quest.requires or {} do
			assert(byId[required], `Quest {quest.id}: requires unknown quest {required}`)
		end
	end

	PlayerData.RegisterSlice("Quests", function()
		return { Progress = {}, Claimed = {} }
	end)
	changedPush = Net.Push("Quests.Changed")
	Net.Handle("Quests.Get", {
		rate = { burst = 4, perSecond = 1 },
		args = {},
		handler = function(player: Player): Net.Result
			local profile = PlayerData.Get(player)
			return if profile then Net.ok(view(stateOf(profile))) else Net.fail("NotReady")
		end,
	})
	Net.Handle("Quests.Claim", {
		rate = { burst = 4, perSecond = 1 },
		args = { T.key(byId) },
		handler = claim,
	})
	PlayerData.Loaded:Connect(function(player: Player)
		schedulePush(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pushPending[player] = nil
	end)
end

return Quests
