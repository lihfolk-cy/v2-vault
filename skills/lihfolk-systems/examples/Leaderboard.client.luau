--!strict
-- LihFolk Systems example: Leaderboard (client)
-- Install: StarterPlayer/StarterPlayerScripts/LeaderboardClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))

local function render(boardId: string, rows: { { [string]: any } })
	print(`[Leaderboard] {boardId}`)
	for _, row in rows do
		print(`  #{row.rank} {row.displayName} (@{row.name}) {row.value}`)
	end
end

Net.On("Leaderboard.Updated", render)
local result = Net.Request("Leaderboard.Get", "CoinsEarned")
if result.ok then
	render("CoinsEarned", result.data)
end
