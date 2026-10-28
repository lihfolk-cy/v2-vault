--!strict
-- LihFolk Systems example: Quests (client)
-- Install: StarterPlayer/StarterPlayerScripts/QuestsClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local Feedback = require(Shared:WaitForChild("Feedback"))

local function render(list: { { [string]: any } })
	for _, quest in list do
		local parts = {}
		for _, objective in quest.objectives do
			table.insert(parts, `{objective.text} {objective.current}/{objective.amount}`)
		end
		print(`[Quests] {quest.title}: {table.concat(parts, ", ")}{if quest.complete then " (claim!)" else ""}`)
		if quest.complete then
			local claim = Net.Request("Quests.Claim", quest.id)
			if claim.ok then
				Feedback.Show("Quest complete", `You got {claim.data.reward}`)
			else
				Feedback.Result("Quests", claim)
			end
		end
	end
end

Net.On("Quests.Changed", render)
local initial = Net.Request("Quests.Get")
if initial.ok then
	render(initial.data)
end
