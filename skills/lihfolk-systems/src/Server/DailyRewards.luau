--!strict
-- LihFolk Systems: DailyRewards
-- Install: ServerScriptService/LihFolk/DailyRewards (ModuleScript)
--
-- Decisions (vault: Daily Rewards System End to End):
--   day        fixed reset at 00:00 UTC + resetOffsetHours, from server os.time()
--   missed day streak resets to day 1 (graceDays lets 1+ missed days through)
--   track      N rewards that loop; day N can be a bigger prize
--   full bag   claim refused, nothing marked ("everything happened or nothing did")
-- The client never sends a time. The countdown is computed on the server and
-- the client counts down from it.
-- Remotes: Daily.Status() -> status table, Daily.Claim() -> { reward, status }
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)

export type Config = {
	track: { Rewards.Reward }, -- reward for streak day 1..N
	resetOffsetHours: number?, -- default 0 (00:00 UTC)
	graceDays: number?, -- default 0
}

local DailyRewards = {}

local track: { Rewards.Reward } = {}
local offsetSeconds = 0
local graceDays = 0
local DAY = 86400

-- Pure: day index for a unix time with the reset offset applied.
function DailyRewards.dayIndex(unix: number, offsetHours: number): number
	return math.floor((unix - offsetHours * 3600) / DAY)
end

-- Pure: (canClaim, streakAfterClaim, rewardIndex 1..trackLength).
-- lastDay = -1 means never claimed.
function DailyRewards.evaluate(lastDay: number, streak: number, today: number, grace: number, trackLength: number): (boolean, number, number)
	if lastDay >= 0 and today <= lastDay then
		-- Already claimed today (or the clock moved back): show the current reward.
		local current = math.max(streak, 1)
		return false, current, ((current - 1) % trackLength) + 1
	end
	local continues = lastDay >= 0 and today - lastDay <= 1 + grace
	local nextStreak = if continues then streak + 1 else 1
	return true, nextStreak, ((nextStreak - 1) % trackLength) + 1
end

-- Pure: seconds until the next reset.
function DailyRewards.secondsUntilReset(unix: number, offsetHours: number): number
	local today = DailyRewards.dayIndex(unix, offsetHours)
	return (today + 1) * DAY + offsetHours * 3600 - unix
end

local function status(player: Player): { [string]: any }?
	local profile = PlayerData.Get(player)
	if not profile then
		return nil
	end
	local state = profile.Data.Daily
	local now = os.time()
	local today = DailyRewards.dayIndex(now, offsetSeconds / 3600)
	local canClaim, nextStreak, index = DailyRewards.evaluate(state.LastDay, state.Streak, today, graceDays, #track)
	return {
		canClaim = canClaim,
		streak = state.Streak,
		nextStreak = nextStreak,
		rewardIndex = index,
		reward = Rewards.Describe(track[index]),
		willReset = canClaim and nextStreak == 1 and state.Streak > 0,
		secondsUntilReset = DailyRewards.secondsUntilReset(now, offsetSeconds / 3600),
		trackLength = #track,
	}
end

local function claim(player: Player): Net.Result
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local state = profile.Data.Daily
	local now = os.time()
	local today = DailyRewards.dayIndex(now, offsetSeconds / 3600)
	local canClaim, nextStreak, index = DailyRewards.evaluate(state.LastDay, state.Streak, today, graceDays, #track)
	if not canClaim then
		return Net.fail("AlreadyClaimed", status(player))
	end
	local reward = track[index]
	local fits, code = Rewards.CanGrant(player, reward)
	if not fits then
		return Net.fail(code or "BagFull", status(player))
	end
	-- Mark and grant together, no yield in between.
	state.LastDay = today
	state.Streak = nextStreak
	Rewards.Grant(player, reward, `daily:{index}`, false, false)
	PlayerData.MarkDirty(profile)
	return Net.ok({ reward = Rewards.Describe(reward), status = status(player) })
end

function DailyRewards.Init(config: Config)
	assert(#config.track >= 1, "DailyRewards: track needs at least one reward")
	for i, reward in config.track do
		Rewards.Validate(`Daily day {i}`, reward)
	end
	track = config.track
	local offsetHours = config.resetOffsetHours or 0
	assert(offsetHours >= -12 and offsetHours <= 14, "DailyRewards: resetOffsetHours -12..14")
	offsetSeconds = offsetHours * 3600
	graceDays = config.graceDays or 0
	assert(graceDays >= 0 and graceDays <= 3, "DailyRewards: graceDays 0..3")

	PlayerData.RegisterSlice("Daily", function()
		return { LastDay = -1, Streak = 0 }
	end)
	Net.Handle("Daily.Status", {
		rate = { burst = 4, perSecond = 1 },
		args = {},
		handler = function(player: Player): Net.Result
			local s = status(player)
			return if s then Net.ok(s) else Net.fail("NotReady")
		end,
	})
	Net.Handle("Daily.Claim", {
		rate = { burst = 3, perSecond = 0.5 },
		args = {},
		handler = claim,
	})
end

return DailyRewards
