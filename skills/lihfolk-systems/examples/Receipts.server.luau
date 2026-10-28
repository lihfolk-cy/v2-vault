--!strict
-- LihFolk Systems example: Receipts (server)
-- Install: ServerScriptService/ReceiptsExample (Script). Use this OR examples/Main.server.luau,
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

PlayerData.Configure(Config.PlayerData)
Policy.Init()
Currency.Init(Config.Currency)
Inventory.Init(Config.Inventory)
Receipts.Init({ products = {
	Gems100 = Config.Receipts.products.Gems100,
	VipTitle = { id = 0, custom = "VipTitle", limit = 1 },
} })
PlayerData.RegisterSlice("Titles", function()
	return { Vip = false }
end)

-- A custom grant validates, mutates synchronously and returns true. It runs
-- inside PlayerData.ProcessPurchaseAsync, so the PurchaseId is recorded in the
-- same write and a redelivered receipt never grants twice.
Receipts.SetCustomGrant("VipTitle", function(player: Player, profile: PlayerData.Profile): boolean
	profile.Data.Titles.Vip = true
	player:SetAttribute("VipTitle", true)
	return true
end)

-- Side effects only after the durable save, once.
Receipts.Granted:Connect(function(player: Player, productKey: string)
	print(`[ReceiptsExample] {player.Name} bought {productKey}`)
end)

Receipts.Start() -- the ONLY ProcessReceipt assignment in the game
PlayerData.Start()
