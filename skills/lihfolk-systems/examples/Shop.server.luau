--!strict
-- LihFolk Systems example: Shop (server)
-- Install: ServerScriptService/ShopExample (Script). Use this OR examples/Main.server.luau,
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
local Receipts = require(Server.Receipts)
local Shop = require(Server.Shop)

PlayerData.Configure(Config.PlayerData)
Policy.Init()
Currency.Init(Config.Currency)
Inventory.Init(Config.Inventory)
-- Shop prompts products registered in Receipts; keep only data-reward products here.
Receipts.Init({ products = {
	Gems100 = Config.Receipts.products.Gems100,
	StarterPack = Config.Receipts.products.StarterPack,
} })
Shop.Init(Config.Shop)

Currency.AddMultiplier("Coins", function(player: Player): number
	return if Shop.OwnsPass(player, "DoubleCoins") then 2 else 1
end)

Receipts.Start()
PlayerData.Start()
