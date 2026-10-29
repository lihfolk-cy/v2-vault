--!strict
-- LihFolk Tutorial example (server): a 5-step simulator onboarding wired to LihFolk Systems.
-- Install: ServerScriptService/TutorialExample (Script)
-- Needs: ReplicatedStorage/LihFolk/LihFolkTutorial, ReplicatedStorage/TutorialSteps (SimulatorSteps.luau),
--        ServerScriptService/LihFolk/{PlayerData, Currency, EggHatch} from skills/lihfolk-systems.
-- Not using LihFolk PlayerData? Replace load/save with your profile library; the tutorial only needs
-- "give me the saved table" and "store this table".
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Tutorial = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("LihFolkTutorial"))
local Steps = require(ReplicatedStorage:WaitForChild("TutorialSteps")) :: { any }

local Server = ServerScriptService:WaitForChild("LihFolk")
local PlayerData = require(Server.PlayerData)
local Currency = require(Server.Currency)
local EggHatch = require(Server.EggHatch)

local UPGRADE_PRICE = 50 -- keep in step with your first upgrade's cost

-- One remote for the tutorial (skip, UI-only signals, hint analytics).
local remote = Instance.new("RemoteEvent")
remote.Name = "TutorialRemote"
remote.Parent = ReplicatedStorage

-- Profile slice: a fresh table each call (PlayerData asserts this).
PlayerData.RegisterSlice("Tutorial", function()
	return { v = 1, done = {}, rewarded = {}, progress = {}, skipped = false, finished = false }
end)

-- Server-only hooks on the shared step list.
for _, step in Steps do
	if step.id == "egg" then
		-- Already owns a pet (returning player, trade, gift): the step completes itself.
		step.isComplete = function(player: Player): boolean
			local profile = PlayerData.Get(player)
			local pets = profile and profile.Data.Pets
			return type(pets) == "table" and next(pets) ~= nil
		end
	end
end

local REWARDS: { [string]: (Player) -> () } = {
	-- Guarantee the next step is affordable: top up to exactly one upgrade, never more.
	SellBonus = function(player: Player)
		local cash = Currency.Get(player, "Cash") or 0
		if cash < UPGRADE_PRICE then
			Currency.Add(player, "Cash", UPGRADE_PRICE - cash, "tutorial")
		end
	end,
	FirstPet = function(player: Player)
		Currency.Add(player, "Gems", 25, "tutorial")
	end,
}

local tutorial = Tutorial.Server.new({
	steps = Steps,
	remote = remote,
	load = function(player: Player)
		local profile = PlayerData.WaitForProfile(player, 60)
		if profile == nil then
			error("profile not ready") -- the module pauses the tutorial instead of treating this as a new player
		end
		return profile.Data.Tutorial
	end,
	save = function(player: Player, saved)
		local profile = PlayerData.Get(player)
		if profile then
			profile.Data.Tutorial = saved
			PlayerData.MarkDirty(profile)
		end
	end,
	reward = function(player: Player, rewardId: string, _stepId: string)
		local grant = REWARDS[rewardId]
		if grant then
			grant(player)
		end
	end,
	-- Prior progress (new device, data from before the tutorial existed): offer Skip at once.
	isReturning = function(player: Player): boolean
		return (Currency.GetEarned(player, "Coins") or 0) > 500
	end,
	renamed = { pickup = "collect" }, -- an old step id from an earlier version
	onFinished = function(player: Player, skipped: boolean)
		-- Hand off to the next-goal chain or the first quest here, so the end of the tutorial is never a dead end.
		player:SetAttribute("NextGoal", if skipped then "zone2" else "zone1Gate")
	end,
})

-- Gameplay systems already know what happened; forward it. Off-step signals are ignored.
Currency.Changed:Connect(function(player: Player, name: string, _balance: number, delta: number, reason: string)
	if name == "Coins" and delta > 0 and reason == "pickup" then
		tutorial:Signal(player, "Collected", delta)
	elseif name == "Cash" and delta > 0 and reason == "sell" then
		tutorial:Signal(player, "Sold", 1)
	elseif name == "Cash" and delta < 0 and reason == "upgrade" then
		tutorial:Signal(player, "Upgraded", 1)
	end
end)

EggHatch.Hatched:Connect(function(player: Player, _eggId: string, _results: any)
	tutorial:Signal(player, "Hatched", 1)
end)

-- The social step completes for real when a friend is in the same server (checked once per join).
Players.PlayerAdded:Connect(function(newcomer: Player)
	for _, other in Players:GetPlayers() do
		if other ~= newcomer then
			local ok, friends = pcall(function(): boolean
				return newcomer:IsFriendsWithAsync(other.UserId)
			end)
			if ok and friends then
				tutorial:Complete(newcomer, "friends")
				tutorial:Complete(other, "friends")
			end
		end
	end
end)

PlayerData.Start()
tutorial:Start()
