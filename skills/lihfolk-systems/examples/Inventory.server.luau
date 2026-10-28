--!strict
-- LihFolk Systems example: Inventory (server)
-- Install: ServerScriptService/InventoryExample (Script). Use this OR examples/Main.server.luau,
-- never both: every remote is declared once and a second Init errors on purpose.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("LihFolk")
local Config = require(ReplicatedStorage:WaitForChild("LihFolkConfig")) :: any
local PlayerData = require(Server.PlayerData)
local Policy = require(Server.Policy)
local Currency = require(Server.Currency)
local Inventory = require(Server.Inventory)

PlayerData.Configure(Config.PlayerData)
Policy.Init()
Currency.Init(Config.Currency)
Inventory.Init(Config.Inventory)

-- Starter gift for new profiles, all-or-nothing.
PlayerData.Loaded:Connect(function(player: Player)
	if Inventory.Count(player, "Dog") == 0 and Inventory.CanAdd(player, "Dog", 1) then
		Inventory.Add(player, "Dog", 1, { paid = false })
	end
end)

PlayerData.Start()
