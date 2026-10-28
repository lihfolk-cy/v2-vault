--!strict
-- LihFolk Systems example: Codes (client)
-- Install: StarterPlayer/StarterPlayerScripts/CodesClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local Feedback = require(Shared:WaitForChild("Feedback"))

-- Wire this to your TextBox's FocusLost / Redeem button.
local function redeem(text: string)
	local result = Net.Request("Codes.Redeem", text)
	if result.ok then
		Feedback.Show("Codes", `Redeemed! You got {result.data.reward}`)
	else
		Feedback.Result("Codes", result)
	end
end

redeem(" release ") -- normalised on the server: "RELEASE"
