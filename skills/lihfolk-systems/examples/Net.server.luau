--!strict
-- LihFolk Systems example: Net (server)
-- Install: ServerScriptService/NetExample (Script)
-- Declares one request remote and one push channel with full validation.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))
local T = Net.T

local COLORS = { Red = Color3.fromRGB(220, 60, 60), Blue = Color3.fromRGB(60, 120, 220) }
local announce = Net.Push("Example.ColorChanged")

-- Handler order: Net already rate-limited and validated (key in COLORS,
-- whole number 1..3). The handler does context checks and acts.
Net.Handle("Example.PickColor", {
	rate = { burst = 4, perSecond = 2 },
	args = { T.key(COLORS), T.integer(1, 3) },
	handler = function(player: Player, colorName: string, slot: number): Net.Result
		player:SetAttribute(`Color{slot}`, colorName)
		-- Relay a SERVER-BUILT payload, never the caller's raw arguments.
		announce:FireAll(player.UserId, colorName, slot)
		return Net.ok({ color = colorName, slot = slot })
	end,
})

Net.Violation:Connect(function(player: Player, remote: string, code: string)
	-- Score, do not kick on one violation. Feed this to your moderation tooling.
	if Net.GetViolationScore(player) > 50 then
		warn(`[NetExample] {player.UserId} has a high violation score on {remote} ({code})`)
	end
end)
