--!strict
-- LihFolk Systems example: Shop (client)
-- Install: StarterPlayer/StarterPlayerScripts/ShopClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local Feedback = require(Shared:WaitForChild("Feedback"))
local player = Players.LocalPlayer
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(ReplicatedStorage:WaitForChild("LihFolkConfig")) :: any

-- Prices on screen come from GetProductInfoAsync (regional pricing), never config.
local function robuxPrice(productId: number): string
	if productId <= 0 then
		return "?"
	end
	local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, productId, Enum.InfoType.Product)
	if ok and info and info.PriceInRobux then
		return tostring(info.PriceInRobux)
	end
	return "?"
end

print("[ShopExample] Gems100 costs", robuxPrice(Config.Receipts.products.Gems100.id), "Robux")

-- Soft-currency purchase: send the item key and quantity only.
Feedback.Result("Shop", Net.Request("Shop.Buy", "SpeedPotion", 2), "Bought 2 Speed Potions")

-- Robux purchase: the server checks limits and policy, then prompts.
Feedback.Result("Shop", Net.Request("Shop.PromptProduct", "Gems100"), "Opening purchase...")

-- Pass ownership is mirrored as an attribute for UI only.
print("[ShopExample] DoubleCoins owned:", player:GetAttribute("Pass_DoubleCoins") == true)
