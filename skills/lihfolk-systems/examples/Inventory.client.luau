--!strict
-- LihFolk Systems example: Inventory (client)
-- Install: StarterPlayer/StarterPlayerScripts/InventoryClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local Feedback = require(Shared:WaitForChild("Feedback"))

local snapshot: { [string]: any }? = nil

local function render()
	if not snapshot then
		return
	end
	for _, unique in snapshot.uniques do
		print(`[InventoryExample] {unique.item} {unique.uid} equipped={unique.equipped}`)
	end
end

Net.On("Inventory.Changed", function(newSnapshot: { [string]: any })
	snapshot = newSnapshot
	render()
end)

local result = Net.Request("Inventory.Snapshot")
if result.ok then
	snapshot = result.data
	render()
	-- Equip the first pet by its uid (never by array index).
	local first = snapshot and snapshot.uniques[1]
	if first then
		Feedback.Result("Pets", Net.Request("Inventory.Equip", first.uid), "Equipped!")
	end
end
