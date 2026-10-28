--!strict
--[[
	LihFolkUIController
	Owns the LihFolk UI screen layers and every registered window:
	  - two ScreenGuis: a full-screen backdrop (ScreenInsets.None) and a safe-area
	    layer (ScreenInsets.CoreUISafeInsets) for everything a finger can touch
	  - responsive scaling: device base x player preference, clamped to fit the safe
	    area, with a touch floor so tap targets never draw under 44 px
	  - open / close: centre-anchored scale pop driven by state, interrupt-safe
	    (proportional retargeting, Completed checked before hiding)
	  - one menu at a time, dimmer behind it, tap-outside to close
	  - gamepad: focus moves into the window on open and back on close; ButtonB closes
	  - HUD launcher column with badges
	Run from ONE LocalScript (or any number; start() is idempotent).

	License: LihFolk. Free to use and modify in your games.
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.LihFolkUITheme)
local Components = require(script.Parent.LihFolkUIComponents)

type Window = Components.Window
type HudButton = Components.HudButton
type ThemeName = Theme.ThemeName

export type DeviceKind = "phone" | "tablet" | "desktop" | "console"

export type StartOptions = {
	displayOrder: number?, -- main layer order; the backdrop sits one below (default 41)
	closeOnBackdrop: boolean?, -- tap outside a window closes it (default true)
	closeKeys: { Enum.KeyCode }?, -- default { ButtonB }. Escape is reserved by Roblox.
}

export type HudButtonOptions = {
	window: string, -- registered window name to toggle
	label: string,
	icon: string,
	theme: ThemeName,
	layoutOrder: number?,
}

type Entry = {
	window: Window,
	open: boolean,
	tween: Tween?,
}

local Controller = {}

local M = Theme.Motion
local S = Theme.Size

local CLOSE_ACTION = "LihFolkUI_Close"
local PHONE_SHORT_SIDE = 520 -- safe-area short side (px) below which a touch device is a phone
local PLAYER_SCALE_MIN, PLAYER_SCALE_MAX = 0.8, 1.3

local started = false
local mainGui: ScreenGui? = nil
local dim: TextButton? = nil
local dimTween: Tween? = nil
local hud: Frame? = nil
local hudScale: UIScale? = nil
local entries: { [string]: Entry } = {}
local current: string? = nil
local returnFocus: GuiObject? = nil
local playerScale = 1
local closeOnBackdrop = true
local closeKeys: { Enum.KeyCode } = { Enum.KeyCode.ButtonB }
local closeBound = false
local listeners: { (name: string, isOpen: boolean) -> () } = {}

-- Forward declaration: closing is needed by the backdrop and the ButtonB action,
-- which are set up before the public close function below.
local closeWindow: (name: string?) -> ()

---------------------------------------------------------------------------
-- Device and input
---------------------------------------------------------------------------
-- "Touch", "Gamepad", "KeyboardAndMouse" (uses PreferredInput when the engine has it).
function Controller.preferredInput(): string
	local ok, value = pcall(function(): any
		return (UserInputService :: any).PreferredInput
	end)
	if ok and typeof(value) == "EnumItem" then
		return (value :: any).Name
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.sub(last.Name, 1, 7) == "Gamepad" then
		return "Gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "KeyboardAndMouse"
end

function Controller.deviceKind(): DeviceKind
	local gui = mainGui
	local area = if gui then gui.AbsoluteSize else Vector2.new(1920, 1080)
	local short = math.min(area.X, area.Y)
	local ok, display = pcall(function(): any
		return (GuiService :: any).ViewportDisplaySize
	end)
	if ok and typeof(display) == "EnumItem" and (display :: any).Name == "Large" then
		return "console"
	end
	local tenFoot = false
	pcall(function()
		tenFoot = GuiService:IsTenFootInterface()
	end)
	if tenFoot then
		return "console"
	end
	if UserInputService.TouchEnabled then
		return if short < PHONE_SHORT_SIDE then "phone" else "tablet"
	end
	return "desktop"
end

-- Base scale before the fit clamp and touch floor.
local function baseScale(kind: DeviceKind, area: Vector2): number
	if kind == "console" then
		return 1.35 -- read from a sofa
	elseif kind == "phone" then
		return 1 -- the fit clamp and the touch floor decide on phones
	end
	return math.clamp(area.Y / 1000, 0.85, 1.4)
end

---------------------------------------------------------------------------
-- Layout: fit every window into the safe area
---------------------------------------------------------------------------
local function applyLayout()
	local gui = mainGui
	if not gui then
		return
	end
	local area = gui.AbsoluteSize
	if area.X <= 0 or area.Y <= 0 then
		return
	end
	local kind = Controller.deviceKind()
	local touch = kind == "phone" or kind == "tablet" or Controller.preferredInput() == "Touch"
	local floor = if touch then S.touchDrawnMin / S.touchMin else 0
	local margin = S.screenMargin * 2
	local wanted = baseScale(kind, area) * playerScale

	for _, entry in entries do
		local design = entry.window.designSize
		local fit = math.min((area.X - margin) / design.X, (area.Y - margin) / design.Y)
		local scale = math.max(math.min(wanted, fit), floor)
		-- When the touch floor beats the fit, shrink the slot instead; the body scrolls.
		local w = math.min(design.X, (area.X - margin) / scale)
		local h = math.min(design.Y, (area.Y - margin) / scale)
		entry.window.root.Size = UDim2.fromOffset(math.floor(w), math.floor(h))
		entry.window.fitScale.Scale = scale
	end

	local hs = hudScale
	if hs then
		hs.Scale = math.max(math.min(wanted, 1.3), floor)
	end
end

---------------------------------------------------------------------------
-- Motion
---------------------------------------------------------------------------
-- Fraction of the way from `from` to `to` still left, given the current value.
local function remainingFraction(value: number, from: number, to: number): number
	if from == to then
		return 0
	end
	return math.clamp((to - value) / (to - from), 0, 1)
end

local function setDim(visible: boolean)
	local d = dim
	if not d then
		return
	end
	local previous = dimTween
	if previous then
		previous:Cancel()
	end
	dimTween = nil
	if visible then
		d.Visible = true
		if Theme.isReducedMotion() then
			d.BackgroundTransparency = M.dimTransparency
			return
		end
		local t = TweenService:Create(d, TweenInfo.new(M.dimTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = M.dimTransparency,
		})
		dimTween = t
		t:Play()
	else
		if Theme.isReducedMotion() then
			d.BackgroundTransparency = 1
			d.Visible = false
			return
		end
		local t = TweenService:Create(d, TweenInfo.new(M.closeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})
		t.Completed:Connect(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed and current == nil then
				d.Visible = false
			end
		end)
		dimTween = t
		t:Play()
	end
end

local function animate(entry: Entry, wantOpen: boolean)
	local window = entry.window
	local motion = window.motionScale
	local previous = entry.tween
	if previous then
		previous:Cancel() -- leaves Scale where it is; we retarget from there
	end
	entry.tween = nil
	local reduced = Theme.isReducedMotion()

	if wantOpen then
		if not window.root.Visible then
			motion.Scale = if reduced then 1 else M.openFrom
			window.root.Visible = true
		end
		for _, loop in window.loops do
			loop:Play()
		end
		if reduced then
			motion.Scale = 1
			return
		end
		local remaining = remainingFraction(motion.Scale, M.openFrom, 1)
		local t = TweenService:Create(
			motion,
			TweenInfo.new(math.max(M.openTime * remaining, 0.05), M.openStyle, M.openDirection),
			{ Scale = 1 }
		)
		entry.tween = t
		t:Play()
	else
		local function finish()
			window.root.Visible = false
			for _, loop in window.loops do
				loop:Pause()
			end
		end
		if reduced or not window.root.Visible then
			finish()
			return
		end
		local remaining = remainingFraction(motion.Scale, 1, M.closeTo)
		local t = TweenService:Create(
			motion,
			TweenInfo.new(math.max(M.closeTime * remaining, 0.03), M.closeStyle, M.closeDirection),
			{ Scale = M.closeTo }
		)
		-- Rule: never hide on a cancelled tween (a reopen interrupted this close).
		t.Completed:Connect(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed and not entry.open then
				finish()
			end
		end)
		entry.tween = t
		t:Play()
	end
end

---------------------------------------------------------------------------
-- Gamepad close action (bound only while a window is open)
---------------------------------------------------------------------------
local function onCloseAction(_action: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin and current ~= nil then
		closeWindow(nil)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function bindClose()
	if closeBound or #closeKeys == 0 then
		return
	end
	closeBound = true
	ContextActionService:BindActionAtPriority(
		CLOSE_ACTION,
		onCloseAction,
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(closeKeys)
	)
end

local function unbindClose()
	if closeBound then
		closeBound = false
		ContextActionService:UnbindAction(CLOSE_ACTION)
	end
end

local function notify(name: string, isOpen: boolean)
	for _, fn in listeners do
		task.spawn(fn, name, isOpen)
	end
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
local function makeLayer(parent: Instance, name: string, insets: Enum.ScreenInsets, order: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = insets
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None -- no automatic stretching
	gui.DisplayOrder = order
	gui.Parent = parent
	return gui
end

function Controller.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	local o: StartOptions = options or {}
	closeOnBackdrop = o.closeOnBackdrop ~= false
	if o.closeKeys then
		closeKeys = o.closeKeys
	end
	local order = o.displayOrder or 41

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Backdrop: edge to edge, never scaled, holds only the dimmer.
	local back = makeLayer(playerGui, "LihFolkUI_Backdrop", Enum.ScreenInsets.None, order - 1)
	local d = Instance.new("TextButton")
	d.Name = "Dimmer"
	d.Text = ""
	d.AutoButtonColor = false
	d.Selectable = false
	d.Size = UDim2.fromScale(1, 1)
	d.BackgroundColor3 = Theme.Palette.backdrop
	d.BackgroundTransparency = 1
	d.BorderSizePixel = 0
	d.Visible = false
	d.Parent = back
	d.Activated:Connect(function()
		if closeOnBackdrop and current ~= nil then
			closeWindow(nil)
		end
	end)
	dim = d

	-- Main layer: everything interactive, inside the core UI safe area.
	local gui = makeLayer(playerGui, "LihFolkUI", Enum.ScreenInsets.CoreUISafeInsets, order)
	mainGui = gui

	-- HUD launcher column: left edge, vertically centred (clear of the top bar,
	-- the thumbstick and the jump button).
	local column = Instance.new("Frame")
	column.Name = "Launcher"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, S.screenMargin, 0.5, 0)
	column.Size = UDim2.fromOffset(S.hudButton + 16, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	local columnList = Instance.new("UIListLayout")
	columnList.FillDirection = Enum.FillDirection.Vertical
	columnList.Padding = UDim.new(0, Theme.Space.md)
	columnList.SortOrder = Enum.SortOrder.LayoutOrder
	columnList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	columnList.Parent = column
	local cs = Instance.new("UIScale")
	cs.Parent = column
	column.Parent = gui
	hud = column
	hudScale = cs

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
	pcall(function()
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(applyLayout)
	end)
	pcall(function()
		GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(applyLayout)
	end)
	UserInputService.LastInputTypeChanged:Connect(function()
		applyLayout()
	end)
	applyLayout()
end

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------
function Controller.register(window: Window)
	Controller.start()
	assert(entries[window.name] == nil, `[LihFolkUI] a window named "{window.name}" is already registered`)
	local entry: Entry = { window = window, open = false, tween = nil }
	entries[window.name] = entry
	window.requestClose = function()
		closeWindow(window.name)
	end
	window.root.Visible = false
	window.root.Parent = mainGui
	applyLayout()
end

function Controller.isOpen(name: string): boolean
	local entry = entries[name]
	return entry ~= nil and entry.open
end

function Controller.getCurrent(): string?
	return current
end

function Controller.open(name: string)
	local entry = entries[name]
	if not entry then
		warn(`[LihFolkUI] open("{name}"): no window registered with that name`)
		return
	end
	if entry.open then
		return
	end
	local previousName = current
	if previousName and previousName ~= name then
		local other = entries[previousName]
		if other and other.open then
			other.open = false
			animate(other, false)
			notify(previousName, false)
		end
	else
		returnFocus = GuiService.SelectedObject -- opened from the HUD / world
	end

	entry.open = true
	current = name
	setDim(true)
	bindClose()
	animate(entry, true)
	Components.playSound("open")

	if Controller.preferredInput() == "Gamepad" then
		GuiService.SelectedObject = entry.window.defaultSelection or entry.window.closeButton.hit
	end
	notify(name, true)
end

closeWindow = function(name: string?)
	local target = name or current
	if target == nil then
		return
	end
	local entry = entries[target]
	if not entry or not entry.open then
		return
	end
	entry.open = false
	animate(entry, false)
	Components.playSound("close")

	if current == target then
		current = nil
		setDim(false)
		unbindClose()
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(entry.window.root) then
			local back = returnFocus
			if back and back:IsDescendantOf(game) and back.Visible then
				GuiService.SelectedObject = back
			else
				GuiService.SelectedObject = nil
			end
		end
		returnFocus = nil
	end
	notify(target, false)
end
Controller.close = closeWindow

function Controller.toggle(name: string)
	if Controller.isOpen(name) then
		Controller.close(name)
	else
		Controller.open(name)
	end
end

function Controller.closeAll()
	if current then
		Controller.close(current)
	end
end

-- Toggle a registered window from any GuiButton you made yourself.
function Controller.bindOpener(button: GuiButton, name: string): RBXScriptConnection
	return button.Activated:Connect(function()
		Controller.toggle(name)
	end)
end

-- Adds a themed launcher to the HUD column. Returns it so you can setBadge(true).
function Controller.addHudButton(options: HudButtonOptions): HudButton
	Controller.start()
	return Components.HudButton({
		label = options.label,
		icon = options.icon,
		theme = options.theme,
		layoutOrder = options.layoutOrder,
		parent = hud,
		onActivated = function()
			Controller.toggle(options.window)
		end,
	})
end

---------------------------------------------------------------------------
-- Preferences and events
---------------------------------------------------------------------------
-- Player UI size (0.8 to 1.3). The fit clamp still wins so a window never leaves the screen.
function Controller.setPlayerScale(value: number)
	playerScale = math.clamp(value, PLAYER_SCALE_MIN, PLAYER_SCALE_MAX)
	applyLayout()
end

function Controller.getPlayerScale(): number
	return playerScale
end

-- true / false forces Reduced Motion; nil follows the platform setting.
function Controller.setReducedMotion(value: boolean?)
	Theme.setReducedMotion(value)
end

-- Listen for open / close. Returns a function that removes the listener.
function Controller.onChanged(callback: (name: string, isOpen: boolean) -> ()): () -> ()
	table.insert(listeners, callback)
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

-- The safe-area ScreenGui, for your own HUD pieces that should share the scaling rules.
function Controller.getGui(): ScreenGui?
	return mainGui
end

function Controller.refresh()
	applyLayout()
end

return Controller
