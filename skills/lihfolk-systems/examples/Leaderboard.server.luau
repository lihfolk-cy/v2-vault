--!strict
-- LihFolk Systems example: Leaderboard (server)
-- Install: ServerScriptService/LeaderboardExample (Script). Use this OR examples/Main.server.luau,
-- never both: every remote is declared once and a second Init errors on purpose.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("LihFolk")
local Config = require(ReplicatedStorage:WaitForChild("LihFolkConfig")) :: any
local PlayerData = require(Server.PlayerData)
local Currency = require(Server.Currency)
local Leaderboard = require(Server.Leaderboard)

PlayerData.Configure(Config.PlayerData)
Currency.Init(Config.Currency)
Leaderboard.Init({
	boards = {
		-- Source board: reads lifetime earned coins from the profile.
		CoinsEarned = {
			storeName = "LB_CoinsEarned_v1",
			period = "all",
			-- Read the profile passed in (it is detached during the final write on leave).
			source = function(_player: Player, profile: PlayerData.Profile): number
				return profile.Data.Currency.Earned.Coins or 0
			end,
		},
		-- Counter board: fed by Leaderboard.Add, new store every Monday 00:00 UTC.
		WeeklyCoins = { storeName = "LB_WeeklyCoins_v1", period = "weekly" },
	},
	exclude = function(_userId: number): boolean
		return false -- return true for banned or deletion-requested users
	end,
})
Currency.Changed:Connect(function(player: Player, name: string, _balance: number, delta: number)
	if name == "Coins" and delta > 0 then
		Leaderboard.Add(player, "WeeklyCoins", delta)
	end
end)
PlayerData.Start()
