--!strict
-- LihFolk Systems example: Net (client)
-- Install: StarterPlayer/StarterPlayerScripts/NetClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local Feedback = require(Shared:WaitForChild("Feedback"))

Net.On("Example.ColorChanged", function(userId: number, colorName: string, slot: number)
	print(`[NetExample] {userId} picked {colorName} for slot {slot}`)
end)

local result = Net.Request("Example.PickColor", "Red", 1)
Feedback.Result("Colors", result, "Color saved")

-- An invalid call is rejected server-side before the handler runs:
local rejected = Net.Request("Example.PickColor", "Purple", 99)
print("[NetExample] invalid call ->", rejected.code) -- "Invalid"
