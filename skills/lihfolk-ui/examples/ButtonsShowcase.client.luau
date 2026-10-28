--!strict
--[[
	LihFolk UI example: BUTTONS AND CONTROLS SHOWCASE
	LocalScript in StarterPlayer > StarterPlayerScripts.
	Every role, every claim state, currency buttons, header-style buttons, toggle,
	text input, progress bar, pills and a sunburst, in one scrolling window.
	Use it to check the kit on phone, tablet and PC before building real menus.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("LihFolkUI")
local Theme = require(UI:WaitForChild("LihFolkUITheme"))
local Icons = require(UI:WaitForChild("LihFolkUIIcons"))
local C = require(UI:WaitForChild("LihFolkUIComponents"))
local Controller = require(UI:WaitForChild("LihFolkUIController"))

local SP = Theme.Space
local BUTTON = Vector2.new(200, Theme.Size.buttonH)

Controller.start()

local window = C.Window({
	name = "Showcase",
	title = "LihFolk UI",
	theme = "neutral",
	icon = "star",
	size = Vector2.new(760, 600),
	headerAction = {
		text = "HELP",
		onActivated = function()
			print("[Showcase] Header action pressed")
		end,
	},
})

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function gridBlock(cell: Vector2): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Block" .. order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.LayoutOrder = nextOrder()
	C.Grid(holder, cell, SP.md)
	holder.Parent = window.body
	return holder
end

-- ROLES -----------------------------------------------------------------
C.SectionHeader("Roles", "neutral", nextOrder(), window.body)
local roles = gridBlock(BUTTON)
local ROLE_DEMO: { { role: string, text: string, icon: string? } } = {
	{ role = "go", text = "PLAY", icon = nil },
	{ role = "neutral", text = "BACK", icon = "back" },
	{ role = "premium", text = "BOOST", icon = "boost" },
	{ role = "danger", text = "RESET", icon = nil },
	{ role = "info", text = "HELP", icon = "info" },
	{ role = "done", text = "OWNED", icon = "check" },
	{ role = "locked", text = "LOCKED", icon = "lock" },
}
for index, demo in ROLE_DEMO do
	local button = C.Button({
		text = demo.text,
		role = demo.role,
		icon = demo.icon,
		size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
		layoutOrder = index,
		parent = roles,
		onActivated = function()
			print(`[Showcase] {demo.role} pressed`)
		end,
	})
	if demo.role == "done" or demo.role == "locked" then
		button.setEnabled(false)
	end
	if index == 1 then
		window.defaultSelection = button.hit
	end
end

-- CLAIM STATES ----------------------------------------------------------
C.SectionHeader("Claim states", "daily", nextOrder(), window.body)
local states = gridBlock(BUTTON)
local STATE_ORDER = { "claim", "claimed", "locked", "skip", "pending" }
for index, name in STATE_ORDER do
	C.StateButton({
		state = name :: any,
		size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
		layoutOrder = index,
		window = window,
		parent = states,
	})
end
-- A live one: each press advances the state so you can watch the transitions.
local cycleIndex = 1
local cycler: any
cycler = C.StateButton({
	state = "claim",
	texts = { claim = "PRESS ME", skip = "PRESS AGAIN" },
	size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
	layoutOrder = 99,
	window = window,
	parent = states,
	onActivated = function()
		cycleIndex = cycleIndex % #STATE_ORDER + 1
		local nextState = STATE_ORDER[cycleIndex]
		cycler.setState(nextState)
		if nextState ~= "claim" and nextState ~= "skip" then
			task.delay(1, function()
				cycleIndex = 1
				cycler.setState("claim")
			end)
		end
	end,
})

-- CURRENCY --------------------------------------------------------------
C.SectionHeader("Prices", "shop", nextOrder(), window.body)
local prices = gridBlock(Vector2.new(160, BUTTON.Y))
C.CurrencyButton({ price = 99, currency = "robux", layoutOrder = 1, size = UDim2.fromOffset(160, BUTTON.Y), parent = prices })
C.CurrencyButton({ price = 1250, currency = "coin", role = "neutral", layoutOrder = 2, size = UDim2.fromOffset(160, BUTTON.Y), parent = prices })
C.CurrencyButton({ price = 40, currency = "gem", role = "info", layoutOrder = 3, size = UDim2.fromOffset(160, BUTTON.Y), parent = prices })
C.CurrencyButton({ price = 2500000, currency = "cash", role = "premium", layoutOrder = 4, size = UDim2.fromOffset(160, BUTTON.Y), parent = prices })

-- CONTROLS --------------------------------------------------------------
C.SectionHeader("Controls", "settings", nextOrder(), window.body)

local controlRow = C.Row({ height = 64, gap = SP.lg, layoutOrder = nextOrder(), parent = window.body })
C.Toggle({ value = true, layoutOrder = 1, parent = controlRow })
C.Toggle({ value = false, layoutOrder = 2, parent = controlRow })
local close = C.CloseButton(function()
	print("[Showcase] Close-style button pressed")
end)
close.root.LayoutOrder = 3
close.root.Parent = controlRow
local round = C.HeaderAction({ icon = "info", onActivated = function() end })
round.root.LayoutOrder = 4
round.root.Parent = controlRow
C.Pill("NEW", { role = "danger", layoutOrder = 5, parent = controlRow })
C.Pill("x2", { role = "go", layoutOrder = 6, parent = controlRow })

C.SettingRow({
	label = "Setting row",
	description = "The whole row is the tap target",
	icon = "sound",
	value = true,
	layoutOrder = nextOrder(),
	parent = window.body,
})

local input = C.TextInput({
	placeholder = "Type here, press Enter",
	maxLength = 20,
	layoutOrder = nextOrder(),
	parent = window.body,
})
input.box.FocusLost:Connect(function(enterPressed: boolean)
	if not enterPressed then
		return
	end
	local text = input.getText()
	if text == "" then
		input.setStatus("error", "Empty, try typing something")
		input.shake()
	else
		input.setStatus("ok", `You typed "{text}"`)
	end
end)

local bar = C.ProgressBar({ value = 0.35, text = "35%", layoutOrder = nextOrder(), parent = window.body })
C.Button({
	text = "+15%",
	role = "neutral",
	size = UDim2.fromOffset(160, BUTTON.Y),
	layoutOrder = nextOrder(),
	parent = window.body,
	onActivated = function()
		local value = bar.getValue() + 0.15
		if value > 1.001 then
			value = 0
		end
		bar.setValue(value)
		bar.setText(`{math.floor(value * 100 + 0.5)}%`)
	end,
})

-- TIER FLOW AND FEATURED -----------------------------------------------
C.SectionHeader("Tier flow and featured", "rebirth", nextOrder(), window.body)
C.TierCompare({
	current = { title = "Tier 1", value = "x1", caption = "Luck" },
	nextTier = { title = "Tier 2", value = "x1.25", caption = "Luck" },
	layoutOrder = nextOrder(),
	window = window,
	parent = window.body,
})

local featuredSlot = Instance.new("Frame")
featuredSlot.Name = "FeaturedSlot"
featuredSlot.BackgroundTransparency = 1
featuredSlot.Size = UDim2.new(1, 0, 0, 150)
featuredSlot.LayoutOrder = nextOrder()
featuredSlot.Parent = window.body
C.Sunburst({ size = UDim2.fromScale(1, 1), window = window, parent = featuredSlot })
local star = Icons.make("star", UDim2.fromOffset(84, 84))
star.AnchorPoint = Vector2.new(0.5, 0.5)
star.Position = UDim2.fromScale(0.5, 0.5)
star.ZIndex = 2
star.Parent = featuredSlot

Controller.register(window)
Controller.addHudButton({ window = "Showcase", label = "Kit", icon = "star", theme = "neutral", layoutOrder = 9 })
