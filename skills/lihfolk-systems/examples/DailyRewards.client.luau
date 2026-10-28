--!strict
-- LihFolk Systems example: DailyRewards (client)
-- Install: StarterPlayer/StarterPlayerScripts/DailyRewardsClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local Feedback = require(Shared:WaitForChild("Feedback"))

-- The server sends secondsUntilReset; count down from it with os.clock()
-- so a changed device clock cannot fake a new day.
local status = Net.Request("Daily.Status")
if status.ok then
	local s = status.data
	local receivedAt = os.clock()
	print(`[Daily] streak {s.streak}, next reward day {s.rewardIndex}: {s.reward}`)
	if s.willReset then
		print("[Daily] You missed a day; the streak restarts at day 1.")
	end
	if s.canClaim then
		local claim = Net.Request("Daily.Claim")
		if claim.ok then
			Feedback.Show("Daily reward", `You got {claim.data.reward}`)
		else
			Feedback.Result("Daily reward", claim)
		end
	else
		task.spawn(function()
			while true do
				local left = math.max(0, math.floor(s.secondsUntilReset - (os.clock() - receivedAt)))
				print(string.format("[Daily] next reward in %02d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60))
				if left <= 0 then
					break
				end
				task.wait(60)
			end
		end)
	end
end
