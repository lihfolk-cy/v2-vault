--!strict
-- LihFolk Systems example: Rebirth (client)
-- Install: StarterPlayer/StarterPlayerScripts/RebirthClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local Feedback = require(Shared:WaitForChild("Feedback"))
local player = Players.LocalPlayer

local function render()
	print(`[Rebirth] rebirths {player:GetAttribute("Rebirths") or 0}`)
end
player:GetAttributeChangedSignal("Rebirths"):Connect(render)
render()

-- 1 = single, 5 = bulk, 0 = as many as affordable. The server computes the price.
local result = Net.Request("Rebirth.Request", 0)
if result.ok then
	Feedback.Show("Rebirth", `+{result.data.gained} rebirths! Earnings x{result.data.multiplier}`)
else
	Feedback.Result("Rebirth", result)
end
