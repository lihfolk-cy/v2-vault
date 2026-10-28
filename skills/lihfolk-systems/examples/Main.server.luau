--!strict
-- LihFolk Systems: bootstrap (the ONLY server Script)
-- Install: ServerScriptService/Main (Script)
--
-- Order matters:
--   1. PlayerData.Configure            (store name, schema, migrations)
--   2. Policy.Init, then every service .Init(config)  (slices + remotes)
--   3. Cross-module hooks              (luck sources, custom grants, quest feeds)
--   4. Receipts.Start                  (asserts every product has a grant; sets ProcessReceipt)
--   5. PlayerData.Start                (loads players; nothing loads before slices exist)
-- Remove the services you do not use (and their config sections).
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Server = ServerScriptService:WaitForChild("LihFolk")
local Config = require(ReplicatedStorage:WaitForChild("LihFolkConfig")) :: any
local Secrets = require(ServerStorage:WaitForChild("LihFolkSecrets")) :: any

local PlayerData = require(Server.PlayerData)
local Policy = require(Server.Policy)
local Currency = require(Server.Currency)
local Inventory = require(Server.Inventory)
local Receipts = require(Server.Receipts)
local Shop = require(Server.Shop)
local EggHatch = require(Server.EggHatch)
local Codes = require(Server.Codes)
local DailyRewards = require(Server.DailyRewards)
local Rebirth = require(Server.Rebirth)
local Quests = require(Server.Quests)
local Leaderboard = require(Server.Leaderboard)

-- 1. Data layer
PlayerData.Configure(Config.PlayerData)

-- 2. Services (each registers its profile slice and remotes)
Policy.Init()
Currency.Init(Config.Currency)
Inventory.Init(Config.Inventory)
Receipts.Init(Config.Receipts)
Shop.Init(Config.Shop)
EggHatch.Init(Config.Eggs)
Codes.Init(Secrets.Codes)
DailyRewards.Init(Config.Daily)
Rebirth.Init(Config.Rebirth)
Quests.Init(Config.Quests)

local boards = table.clone(Config.Leaderboard.boards)
boards.CoinsEarned = table.clone(boards.CoinsEarned)
-- Sources read the profile they are given: on leave the profile is already
-- detached, so PlayerData.Get(player) would return nil for the final write.
boards.CoinsEarned.source = function(_player: Player, profile: PlayerData.Profile): number
	return profile.Data.Currency.Earned.Coins or 0
end
Leaderboard.Init({
	boards = boards,
	writeSeconds = Config.Leaderboard.writeSeconds,
	refreshSeconds = Config.Leaderboard.refreshSeconds,
})

-- 3. Cross-module hooks
-- Game pass benefits are derived from the server ownership cache, never saved.
Currency.AddMultiplier("Coins", function(player: Player): number
	return if Shop.OwnsPass(player, "DoubleCoins") then 2 else 1
end)
-- A paid luck pass is a probability modifier: marked paid, so restricted
-- players do not get it and their displayed odds stay at base luck.
EggHatch.AddLuckSource("LuckyPass", true, function(player: Player): number
	return if Shop.OwnsPass(player, "LuckyPass") then 1.5 else 1
end)

Receipts.SetCustomGrant("LuckBoost2x", function(player: Player): boolean
	return EggHatch.GrantTimedBoost(player, 2, 15 * 60, true)
end)
Receipts.SetPromptCheck("LuckBoost2x", function(player: Player): (boolean, string?)
	if EggHatch.IsAtMaxLuck(player) then
		return false, "AtMaxLuck" -- never sell a boost that does nothing
	end
	return true, nil
end)
Receipts.SetCustomGrant("RoyalHatch", function(player: Player): boolean
	return EggHatch.GrantPaidHatch(player, "Royal", 1)
end)

-- Quest progress comes only from server systems.
Currency.Changed:Connect(function(player: Player, name: string, _balance: number, delta: number, reason: string)
	if name == "Coins" and delta > 0 and reason == "pickup" then
		Quests.Report(player, "Collect", "Coin", delta)
	end
end)

EggHatch.Hatched:Connect(function(player: Player, eggId: string, results: { any })
	Quests.Report(player, "Hatch", eggId, #results)
	Leaderboard.Add(player, "WeeklyHatches", #results)
end)

-- 4. Purchases
Receipts.Start()

-- 5. Load players last
PlayerData.Start()
