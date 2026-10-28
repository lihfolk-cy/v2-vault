--!strict
-- LihFolk Systems example: Receipts (client)
-- Install: StarterPlayer/StarterPlayerScripts/ReceiptsClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Feedback = require(Shared:WaitForChild("Feedback"))
local player = Players.LocalPlayer
local MarketplaceService = game:GetService("MarketplaceService")

-- PromptProductPurchaseFinished is UI-only. Never grant from it: the grant
-- arrives through ProcessReceipt and shows up as server state.
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _productId: number, purchased: boolean)
	if userId == player.UserId and purchased then
		Feedback.Show("Store", "Thanks! Your purchase is being delivered.")
	end
end)
player:GetAttributeChangedSignal("Gems"):Connect(function()
	Feedback.Show("Store", `You now have {player:GetAttribute("Gems")} Gems`)
end)
