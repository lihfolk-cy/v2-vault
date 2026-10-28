--!strict
-- LihFolk Systems example: Currency (server)
-- Install: ServerScriptService/CurrencyExample (Script). Use this OR examples/Main.server.luau,
-- never both: every remote is declared once and a second Init errors on purpose.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("LihFolk")
local Config = require(ReplicatedStorage:WaitForChild("LihFolkConfig")) :: any
local PlayerData = require(Server.PlayerData)
local Currency = require(Server.Currency)

PlayerData.Configure(Config.PlayerData)
Currency.Init(Config.Currency)
PlayerData.Start()

-- Coins from a pickup part: the SERVER decides the amount, with multipliers.
local coinPart = workspace:FindFirstChild("CoinPart")
if coinPart and coinPart:IsA("BasePart") then
	local lastPickup: { [Player]: number } = {}
	coinPart.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and game:GetService("Players"):GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if now - (lastPickup[player] or 0) < 1 then
			return -- Touched is client-triggerable too: rate limit it
		end
		lastPickup[player] = now
		Currency.Earn(player, "Coins", 10, "pickup")
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		lastPickup[player] = nil
	end)
end
