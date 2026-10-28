--!strict
--[[
	LihFolk UI example: DAILY REWARDS (7-day track, wide day-7 big-reward card)
	LocalScript in StarterPlayer > StarterPlayerScripts.

	Layout: days 1-4 on the top row, days 5-6 plus a double-width day 7 below.
	Server contract (you write it; the server owns the clock and the streak):
	  ReplicatedStorage > Remotes > DailyState (RemoteFunction) -> { day: number, claimedToday: boolean }
	  ReplicatedStorage > Remotes > ClaimDaily (RemoteFunction) -> { ok: boolean, message: string? }
	Without those remotes the menu runs in a demo state so you can see every card state.
	Reset is a fixed UTC midnight; the countdown below is display only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("LihFolkUI")
local Theme = require(UI:WaitForChild("LihFolkUITheme"))
local C = require(UI:WaitForChild("LihFolkUIComponents"))
local Controller = require(UI:WaitForChild("LihFolkUIController"))

type Reward = { amount: string, icon: string }
local REWARDS: { Reward } = {
	{ amount = "x500", icon = "coin" },
	{ amount = "x1,000", icon = "coin" },
	{ amount = "x10", icon = "gem" },
	{ amount = "x2,500", icon = "coin" },
	{ amount = "x25", icon = "gem" },
	{ amount = "2x Cash 15m", icon = "boost" },
	{ amount = "Rare Pet + x100 Gems", icon = "pet" },
}

local CARD = Vector2.new(156, 196)
local GAP = Theme.Space.md

Controller.start()

local window = C.Window({
	name = "DailyRewards",
	title = "Daily Rewards",
	theme = "daily",
	icon = "daily",
	size = Vector2.new(760, 620),
	bodyGap = GAP,
})

local timerLabel = C.Text("small", "", { color = Theme.Palette.textMid, layoutOrder = 1, parent = window.body })
C.Text("caption", "Come back every day. Miss a day and the streak starts again at Day 1.", {
	color = Theme.Palette.textLow,
	layoutOrder = 2,
	parent = window.body,
})

local rowTop = C.Row({ height = CARD.Y, gap = GAP, layoutOrder = 3, parent = window.body })
local rowBottom = C.Row({ height = CARD.Y, gap = GAP, layoutOrder = 4, parent = window.body })

local hudButton = Controller.addHudButton({
	window = "DailyRewards",
	label = "Daily",
	icon = "daily",
	theme = "daily",
	layoutOrder = 3,
})

local cards: { any } = {}
local state = { day = 1, claimedToday = true }

local function remote(name: string): RemoteFunction?
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local found = folder and folder:FindFirstChild(name)
	if found and found:IsA("RemoteFunction") then
		return found
	end
	return nil
end

local function render()
	for index, card in cards do
		local cardState = if index < state.day then "claimed"
			elseif index == state.day then (if state.claimedToday then "claimed" else "claim")
			else "locked"
		card.setState(cardState)
	end
	hudButton.setBadge(not state.claimedToday)
	window.defaultSelection = cards[state.day].button.button.hit
end

local function load()
	local fn = remote("DailyState")
	if not fn then
		state = { day = 3, claimedToday = false } -- demo
		render()
		return
	end
	local ok, reply = pcall(fn.InvokeServer, fn)
	if ok and type(reply) == "table" and type(reply.day) == "number" then
		state = { day = math.clamp(reply.day, 1, 7), claimedToday = reply.claimedToday == true }
	end
	render()
end

local function claim(dayIndex: number)
	if dayIndex ~= state.day or state.claimedToday then
		return
	end
	cards[dayIndex].setState("pending")
	local fn = remote("ClaimDaily")
	if not fn then
		state.claimedToday = true -- demo
		C.playSound("success")
		render()
		return
	end
	local ok, reply = pcall(fn.InvokeServer, fn)
	if ok and type(reply) == "table" and reply.ok == true then
		state.claimedToday = true
		C.playSound("success")
	else
		C.playSound("error")
	end
	render()
end

for index, reward in REWARDS do
	local featured = index == 7
	local card = C.RewardCard({
		title = `DAY {index}`,
		amount = reward.amount,
		icon = reward.icon,
		state = "locked",
		featured = featured,
		size = if featured then UDim2.fromOffset(CARD.X * 2 + GAP, CARD.Y) else UDim2.fromOffset(CARD.X, CARD.Y),
		layoutOrder = index,
		window = window,
		parent = if index <= 4 then rowTop else rowBottom,
		onActivated = function(buttonState)
			if buttonState == "claim" then
				claim(index)
			end
		end,
	})
	cards[index] = card
end

-- Countdown to the next UTC midnight, ticking only while the menu is open.
local ticking = false
local function formatClock(seconds: number): string
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function startTimer()
	if ticking then
		return
	end
	ticking = true
	task.spawn(function()
		while Controller.isOpen("DailyRewards") do
			local now = os.time()
			local nextReset = (now // 86400 + 1) * 86400
			timerLabel.Text = if state.claimedToday
				then "Next reward in " .. formatClock(nextReset - now)
				else "Your Day " .. state.day .. " reward is ready!"
			task.wait(1)
		end
		ticking = false
	end)
end

Controller.register(window)
Controller.onChanged(function(name: string, isOpen: boolean)
	if name == "DailyRewards" and isOpen then
		startTimer()
		load()
	end
end)
load()
