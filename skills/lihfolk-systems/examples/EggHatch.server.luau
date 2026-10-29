--!strict
-- LihFolk Systems example: EggHatch (server)
-- Install: ServerScriptService/EggHatchExample (Script). Use this OR examples/Main.server.luau,
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
local EggHatch = require(Server.EggHatch)

PlayerData.Configure(Config.PlayerData)
Policy.Init()
Currency.Init(Config.Currency)
Inventory.Init(Config.Inventory)
Receipts.Init({ products = {
	LuckBoost2x = Config.Receipts.products.LuckBoost2x,
	RoyalHatch = Config.Receipts.products.RoyalHatch,
} })
EggHatch.Init(Config.Eggs)

-- Free luck source (not paid): applies to everyone, including restricted players.
EggHatch.AddLuckSource("Weekend", false, function(): number
	local weekday = os.date("!*t").wday -- 1 = Sunday, 7 = Saturday (UTC)
	return if weekday == 1 or weekday == 7 then 1.25 else 1
end)

-- Paid modifiers and paid hatches go through Receipts; the prompt path
-- (Shop.PromptProduct) checks PolicyService and the luck cap first.
Receipts.SetCustomGrant("LuckBoost2x", function(player: Player): boolean
	return EggHatch.GrantTimedBoost(player, 2, 15 * 60, true)
end)
Receipts.SetPromptCheck("LuckBoost2x", function(player: Player): (boolean, string?)
	if EggHatch.IsAtMaxLuck(player) then
		return false, "AtMaxLuck"
	end
	if not EggHatch.CanAddTimedBoost(player) then
		return false, "BoostLimit" -- room check first, so the paid grant never has to merge
	end
	return true, nil
end)
Receipts.SetCustomGrant("RoyalHatch", function(player: Player): boolean
	return EggHatch.GrantPaidHatch(player, "Royal", 1)
end)

Receipts.Start()
PlayerData.Start()
-- Studio: set ServerStorage attribute ForceRestrictedPolicy = true to walk the restricted path.
