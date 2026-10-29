--!strict
-- LihFolk Tutorial: data-driven onboarding (FTUE) for Roblox, server + client in one module.
-- Install: ReplicatedStorage/LihFolk/LihFolkTutorial (ModuleScript)
--
-- What it does
--   * A step graph: each step has an id, an objective (short, with device tokens like {INTERACT}),
--     optional prerequisites (requires), an optional trigger (contextual steps), a completion signal
--     with a goal count, an optional "already done?" check, a world target and a reward id.
--   * The SERVER owns progress. Gameplay systems call tutorial:Signal(player, "Sold", 1). The client
--     can only report UI-only signals that the active step lists in clientSignal (validated, rate limited).
--   * Progress is saved through callbacks you pass (load / save), so it plugs into LihFolk PlayerData
--     or any profile library without a hard dependency. Step ids are saved, never indices.
--   * Skip (server-applied, grants the rewards the steps would have paid), resume after rejoin,
--     finished steps never shown again, optional (non-blocking) steps such as "play with friends".
--   * Funnel analytics per step with AnalyticsService (server only, forward-only, pcall-wrapped).
--   * Client: objective banner (or your own UI callbacks), device-aware glyph text that updates when
--     the player switches device, a stuck-hint scheduler (hint only after N seconds without progress),
--     world guidance (Beam from the character to the target, Highlight, local ProximityPrompt tag),
--     reduced-motion support, and full cleanup on every step change and respawn.
--
-- Status: reviewed against the Roblox API dump (LihFolk Vault V2/_tools/roblox_api.json); not run in Studio.

local AnalyticsService = game:GetService("AnalyticsService")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local STATE_ATTRIBUTE = "LFTutorial"
local PROMPT_TAG = "LFTutorialPrompt"
local MAX_ID_LENGTH = 48

---------------------------------------------------------------------------------------------------
-- Types
---------------------------------------------------------------------------------------------------

export type Device = "Keyboard" | "Touch" | "Gamepad"

-- Where world guidance points. First match wins: instance, tag (nearest tagged), path, position.
export type Target = {
	instance: Instance?,
	tag: string?,
	path: { string }?, -- from workspace, e.g. { "Shops", "SellPad" }
	position: Vector3?,
	highlight: boolean?, -- default true when the target is an instance
	beam: boolean?, -- default true
	prompt: boolean?, -- tag the target's ProximityPrompt locally so a custom prompt style can emphasise it
}

export type HintText = { any: string?, Keyboard: string?, Touch: string?, Gamepad: string? }

export type Step = {
	id: string,
	objective: string, -- aim for 8 words or fewer; tokens like {INTERACT} become device glyphs
	signal: string?, -- server signal that advances the step
	goal: number?, -- signals needed (default 1)
	clientSignal: string?, -- UI-only signal the client may report for this step (never for rewards that matter)
	requires: { string }?, -- step ids that must be done first (graph edges)
	trigger: ((player: Player) -> boolean)?, -- server: step only becomes active when this returns true
	isComplete: ((player: Player) -> boolean)?, -- server: "already done" check on activation and Refresh
	optional: boolean?, -- does not block "finished" (social steps, extras)
	reward: string?, -- reward id passed to the reward hook, paid once
	target: Target?,
	guide: ("always" | "whenStuck" | "none")?, -- world guidance timing (default "always")
	hint: HintText?, -- extra help shown only when stuck
	hintAfter: number?, -- seconds without progress before the hint (default 8)
	reveal: { string }?, -- HUD keys to reveal when this step starts (progressive disclosure)
}

export type Saved = {
	v: number,
	done: { [string]: boolean },
	rewarded: { [string]: boolean },
	progress: { [string]: number },
	skipped: boolean,
	finished: boolean,
}

export type ServerConfig = {
	steps: { Step },
	remote: RemoteEvent,
	load: (player: Player) -> Saved?, -- may yield (e.g. PlayerData.WaitForProfile); nil = new player
	save: (player: Player, saved: Saved) -> (), -- write into the profile and mark it dirty
	reward: ((player: Player, rewardId: string, stepId: string) -> ())?, -- server-authoritative grant
	renamed: { [string]: string }?, -- old step id -> new step id, for saves made before a tutorial change
	isReturning: ((player: Player) -> boolean)?, -- true = may skip immediately (prior progress, alt, new device)
	skipAfterSteps: number?, -- new players may skip after this many done steps (default 1)
	rewardOnSkip: boolean?, -- default true: skippers get what the steps would have paid
	funnelName: string?, -- set to log a versioned funnel ("Tutorial_v2") instead of the onboarding funnel
	analytics: boolean?, -- default true
	onFinished: ((player: Player, skipped: boolean) -> ())?, -- hand off to the next-goal chain here
}

export type PublicState = {
	active: { string },
	progress: { [string]: number },
	goal: { [string]: number },
	reveal: { string },
	done: number,
	total: number,
	finished: boolean,
	canSkip: boolean,
}

export type ClientUi = {
	showObjective: (stepId: string, text: string, progress: number, goal: number) -> (),
	hideObjective: () -> (),
	showHint: (stepId: string, text: string) -> (),
	hideHint: () -> (),
	celebrate: ((stepId: string) -> ())?,
	reveal: ((key: string) -> ())?,
	setSkipVisible: ((visible: boolean) -> ())?,
}

export type ClientConfig = {
	steps: { Step },
	remote: RemoteEvent,
	ui: ClientUi?, -- default: a small safe-area banner built by this module
	glyphs: { [string]: { Keyboard: string?, Touch: string?, Gamepad: string? } }?,
	inputActions: { [string]: Instance }?, -- token -> InputAction; labels follow the player's bindings
	reducedMotion: boolean?, -- force on; otherwise GuiService.ReducedMotionEnabled
	beamColor: Color3?,
	beamTexture: string?, -- your own arrow texture asset id; none by default
}

---------------------------------------------------------------------------------------------------
-- Shared helpers
---------------------------------------------------------------------------------------------------

local function indexSteps(steps: { Step }): ({ [string]: Step }, { [string]: number })
	local byId: { [string]: Step } = {}
	local order: { [string]: number } = {}
	for i, step in steps do
		assert(type(step.id) == "string" and #step.id > 0 and #step.id <= MAX_ID_LENGTH, `LihFolkTutorial: bad id at step {i}`)
		assert(byId[step.id] == nil, `LihFolkTutorial: duplicate step id '{step.id}'`)
		byId[step.id] = step
		order[step.id] = i
	end
	for _, step in steps do
		for _, req in step.requires or {} do
			assert(byId[req] ~= nil, `LihFolkTutorial: step '{step.id}' requires unknown '{req}'`)
			assert(order[req] < order[step.id], `LihFolkTutorial: '{step.id}' requires '{req}', which must be listed earlier`)
		end
	end
	return byId, order
end

local function newSaved(): Saved
	return { v = 1, done = {}, rewarded = {}, progress = {}, skipped = false, finished = false }
end

local function analyticsFields(value: string): { [string]: string }
	return { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = value }
end

---------------------------------------------------------------------------------------------------
-- Server
---------------------------------------------------------------------------------------------------

type Session = {
	saved: Saved,
	active: { string },
	maxLogged: number,
	lastRemote: number,
	remoteCount: number,
	windowStart: number,
	hinted: { [string]: boolean },
}

export type ServerTutorial = {
	Start: (self: ServerTutorial) -> (),
	Signal: (self: ServerTutorial, player: Player, signal: string, amount: number?) -> (),
	Refresh: (self: ServerTutorial, player: Player) -> (),
	Complete: (self: ServerTutorial, player: Player, stepId: string) -> (),
	Skip: (self: ServerTutorial, player: Player) -> boolean,
	Reset: (self: ServerTutorial, player: Player) -> (),
	IsDone: (self: ServerTutorial, player: Player, stepId: string?) -> boolean,
	GetActive: (self: ServerTutorial, player: Player) -> { string },
}

local Server = {}

function Server.new(config: ServerConfig): ServerTutorial
	assert(RunService:IsServer(), "LihFolkTutorial.Server.new must run on the server")
	assert(typeof(config.remote) == "Instance" and config.remote:IsA("RemoteEvent"), "LihFolkTutorial: config.remote must be a RemoteEvent")
	local steps = config.steps
	local byId, order = indexSteps(steps)
	local sessions: { [Player]: Session } = {}
	local useAnalytics = config.analytics ~= false
	local self = {} :: any

	-- Funnel layout: 1 = "Joined", tutorial step i = i + 1, #steps + 2 = "Finished". Forward-only, once each.
	local function logFunnel(player: Player, session: Session, funnelStep: number, stepName: string)
		if not useAnalytics or funnelStep <= session.maxLogged then
			return
		end
		session.maxLogged = funnelStep
		local ok, err = pcall(function()
			if config.funnelName then
				AnalyticsService:LogFunnelStepEvent(player, config.funnelName, nil, funnelStep, stepName)
			else
				AnalyticsService:LogOnboardingFunnelStepEvent(player, funnelStep, stepName)
			end
		end)
		if not ok then
			warn("[LihFolkTutorial] analytics:", err)
		end
	end

	local function logStep(player: Player, session: Session, stepId: string)
		logFunnel(player, session, order[stepId] + 1, stepId)
	end

	local function logCustom(player: Player, eventName: string, field: string)
		if not useAnalytics then
			return
		end
		local ok, err = pcall(function()
			AnalyticsService:LogCustomEvent(player, eventName, 1, analyticsFields(field))
		end)
		if not ok then
			warn("[LihFolkTutorial] analytics:", err)
		end
	end

	local function requiredDone(saved: Saved, step: Step): boolean
		for _, req in step.requires or {} do
			if not saved.done[req] then
				return false
			end
		end
		return true
	end

	local function canSkip(player: Player, saved: Saved): boolean
		local open = false
		for _, step in steps do
			if not saved.done[step.id] then
				open = true
				break
			end
		end
		if not open then
			return false
		end
		if saved.finished then
			return true -- only optional steps remain: always dismissable
		end
		if config.isReturning then -- must not yield; read data that is already loaded
			local ok, returning = pcall(config.isReturning, player)
			if ok and returning then
				return true
			end
		end
		local count = 0
		for _ in saved.done do
			count += 1
		end
		return count >= (config.skipAfterSteps or 1)
	end

	local function payReward(player: Player, saved: Saved, step: Step)
		if step.reward == nil or saved.rewarded[step.id] or config.reward == nil then
			return
		end
		saved.rewarded[step.id] = true -- mark first: the hook is never called twice for one step
		local ok, err = pcall(config.reward, player, step.reward, step.id)
		if not ok then
			warn(`[LihFolkTutorial] reward '{step.reward}' failed:`, err)
		end
	end

	local function publish(player: Player, session: Session)
		local saved = session.saved
		local progress: { [string]: number } = {}
		local goal: { [string]: number } = {}
		local reveal: { string } = {}
		local seen: { [string]: boolean } = {}
		local doneCount = 0
		for _, step in steps do
			local isActive = table.find(session.active, step.id) ~= nil
			if saved.done[step.id] or isActive then
				for _, key in step.reveal or {} do
					if not seen[key] then
						seen[key] = true
						table.insert(reveal, key)
					end
				end
			end
			if saved.done[step.id] then
				doneCount += 1
			end
			if isActive then
				progress[step.id] = saved.progress[step.id] or 0
				goal[step.id] = step.goal or 1
			end
		end
		local state: PublicState = {
			active = session.active,
			progress = progress,
			goal = goal,
			reveal = reveal,
			done = doneCount,
			total = #steps,
			finished = saved.finished,
			canSkip = canSkip(player, saved),
		}
		player:SetAttribute(STATE_ATTRIBUTE, HttpService:JSONEncode(state))
	end

	local function save(player: Player, session: Session)
		local ok, err = pcall(config.save, player, session.saved)
		if not ok then
			warn("[LihFolkTutorial] save callback failed:", err)
		end
	end

	-- Marks a step done (no save, no publish; callers batch those).
	local function markDone(player: Player, session: Session, step: Step)
		local saved = session.saved
		if saved.done[step.id] then
			return
		end
		saved.done[step.id] = true
		saved.progress[step.id] = nil
		payReward(player, saved, step)
		logStep(player, session, step.id)
	end

	-- Recomputes the active set. Steps whose isComplete check already passes are completed on the way.
	local function evaluate(player: Player, session: Session)
		local saved = session.saved
		local changed = true
		local guard = 0
		while changed and guard <= #steps do
			changed = false
			guard += 1
			table.clear(session.active)
			for _, step in steps do
				if not saved.done[step.id] and requiredDone(saved, step) then
					local triggered = true
					if step.trigger then
						local ok, result = pcall(step.trigger, player)
						triggered = ok and result == true
					end
					if triggered then
						local already = false
						if step.isComplete then
							local ok, result = pcall(step.isComplete, player)
							already = ok and result == true
						end
						if already then
							markDone(player, session, step)
							changed = true
						else
							table.insert(session.active, step.id)
						end
					end
				end
			end
		end
		local allRequired = true
		for _, step in steps do
			if not step.optional and not saved.done[step.id] then
				allRequired = false
				break
			end
		end
		if allRequired and not saved.finished then
			saved.finished = true
			logFunnel(player, session, #steps + 2, "Finished") -- closes the funnel even when optional steps remain
			if config.onFinished then
				task.spawn(config.onFinished, player, saved.skipped)
			end
		end
	end

	local function commit(player: Player, session: Session)
		evaluate(player, session)
		save(player, session)
		publish(player, session)
	end

	local function sanitize(raw: any): Saved
		local saved = newSaved()
		if type(raw) ~= "table" then
			return saved
		end
		local renamed = config.renamed or {}
		if type(raw.done) == "table" then
			for id, value in raw.done do
				local current = if type(id) == "string" then (renamed[id] or id) else nil
				if current and byId[current] and value == true then
					saved.done[current] = true
				end
			end
		end
		if type(raw.rewarded) == "table" then
			for id, value in raw.rewarded do
				local current = if type(id) == "string" then (renamed[id] or id) else nil
				if current and byId[current] and value == true then
					saved.rewarded[current] = true
				end
			end
		end
		if type(raw.progress) == "table" then
			for id, value in raw.progress do
				local current = if type(id) == "string" then (renamed[id] or id) else nil
				if current and byId[current] and type(value) == "number" and value == value and value >= 0 then
					saved.progress[current] = math.floor(value)
				end
			end
		end
		saved.skipped = raw.skipped == true
		saved.finished = raw.finished == true
		return saved
	end

	local function attach(player: Player)
		local ok, raw = pcall(config.load, player)
		if not ok then
			warn("[LihFolkTutorial] load callback failed; tutorial paused for", player.Name, raw)
			return -- never treat a failed load as a new player
		end
		if player.Parent ~= Players then
			return
		end
		local session: Session = {
			saved = sanitize(raw),
			active = {},
			maxLogged = 0,
			lastRemote = 0,
			remoteCount = 0,
			windowStart = os.clock(),
			hinted = {},
		}
		sessions[player] = session
		if not session.saved.finished then
			logFunnel(player, session, 1, "Joined")
		end
		-- New steps added after launch become active for players who finished an older version.
		commit(player, session)
	end

	local advance: (player: Player, matches: (Step) -> boolean, amount: number?) -> () -- defined below

	local function allowRemote(session: Session): boolean
		local now = os.clock()
		if now - session.windowStart > 10 then
			session.windowStart = now
			session.remoteCount = 0
		end
		session.remoteCount += 1
		if session.remoteCount > 20 or now - session.lastRemote < 0.1 then
			return false
		end
		session.lastRemote = now
		return true
	end

	local function onRemote(player: Player, action: unknown, arg: unknown)
		local session = sessions[player]
		if session == nil or not allowRemote(session) then
			return
		end
		if type(action) ~= "string" then
			return
		end
		if action == "skip" then
			self:Skip(player)
		elseif action == "clientSignal" then
			if type(arg) ~= "string" or #arg > MAX_ID_LENGTH then
				return
			end
			-- Only a currently active step that declares this exact client signal can be advanced.
			local reported: string = arg
			advance(player, function(step: Step): boolean
				return step.clientSignal == reported
			end, 1)
		elseif action == "hint" then
			if type(arg) ~= "string" or byId[arg] == nil or session.hinted[arg] then
				return
			end
			if table.find(session.active, arg) == nil then
				return
			end
			session.hinted[arg] = true
			logCustom(player, "TutorialHintShown", arg)
		end
	end

	function self.Start(_: ServerTutorial)
		config.remote.OnServerEvent:Connect(onRemote)
		Players.PlayerAdded:Connect(function(player: Player)
			attach(player)
		end)
		for _, player in Players:GetPlayers() do
			task.spawn(attach, player)
		end
		Players.PlayerRemoving:Connect(function(player: Player)
			local session = sessions[player]
			if session then
				save(player, session)
			end
			sessions[player] = nil
		end)
	end

	-- Advances every active step that `matches`. Off-step signals are ignored.
	advance = function(player: Player, matches: (Step) -> boolean, amount: number?)
		local session = sessions[player]
		if session == nil or (session.saved.finished and #session.active == 0) then
			return
		end
		local add = math.clamp(math.floor(amount or 1), 1, 1000)
		local changed = false
		for _, id in table.clone(session.active) do
			local step = byId[id]
			if matches(step) then
				local count = (session.saved.progress[id] or 0) + add
				if count >= (step.goal or 1) then
					markDone(player, session, step)
				else
					session.saved.progress[id] = count
				end
				changed = true
			end
		end
		if changed then
			commit(player, session)
		else
			evaluate(player, session) -- a trigger may have become true
			publish(player, session)
		end
	end

	-- Called by server gameplay systems ("Collected", "Sold", "Hatched"...). Call it freely.
	function self.Signal(_: ServerTutorial, player: Player, signal: string, amount: number?)
		advance(player, function(step: Step): boolean
			return step.signal == signal
		end, amount)
	end

	-- Re-check triggers and isComplete after a state change that sends no signal (bought an item, a friend joined).
	function self.Refresh(_: ServerTutorial, player: Player)
		local session = sessions[player]
		if session then
			commit(player, session)
		end
	end

	-- Completes a step directly (server code only, e.g. a cutscene finished).
	function self.Complete(_: ServerTutorial, player: Player, stepId: string)
		local session = sessions[player]
		local step = byId[stepId]
		if session and step then
			markDone(player, session, step)
			commit(player, session)
		end
	end

	-- Applies a skip on the server: every step done, rewards paid once (unless rewardOnSkip = false).
	function self.Skip(_: ServerTutorial, player: Player): boolean
		local session = sessions[player]
		if session == nil or not canSkip(player, session.saved) then
			return false
		end
		local saved = session.saved
		local firstOpen = session.active[1] or "none"
		local wasFinished = saved.finished -- dismissing leftover optional steps pays nothing
		for _, step in steps do
			if not saved.done[step.id] then
				saved.done[step.id] = true
				saved.progress[step.id] = nil
				if config.rewardOnSkip ~= false and not wasFinished then
					payReward(player, saved, step)
				end
			end
		end
		saved.skipped = saved.skipped or not wasFinished
		logCustom(player, "TutorialSkipped", firstOpen)
		commit(player, session)
		return true
	end

	-- Replay from Settings ("Show tutorial again"). Rewards already paid stay paid and are not paid again.
	function self.Reset(_: ServerTutorial, player: Player)
		local session = sessions[player]
		if session == nil then
			return
		end
		local rewarded = session.saved.rewarded
		session.saved = newSaved()
		session.saved.rewarded = rewarded
		session.maxLogged = math.huge -- replays are not new-player funnel data
		session.hinted = {}
		commit(player, session)
	end

	function self.IsDone(_: ServerTutorial, player: Player, stepId: string?): boolean
		local session = sessions[player]
		if session == nil then
			return false
		end
		if stepId == nil then
			return session.saved.finished
		end
		return session.saved.done[stepId] == true
	end

	function self.GetActive(_: ServerTutorial, player: Player): { string }
		local session = sessions[player]
		return if session then table.clone(session.active) else {}
	end

	return self :: ServerTutorial
end

---------------------------------------------------------------------------------------------------
-- Client
---------------------------------------------------------------------------------------------------

local DEFAULT_GLYPHS: { [string]: { Keyboard: string?, Touch: string?, Gamepad: string? } } = {
	INTERACT = { Keyboard = "Press E", Touch = "Tap", Gamepad = "Press X" },
	ATTACK = { Keyboard = "Click", Touch = "Tap", Gamepad = "Press R2" },
	JUMP = { Keyboard = "Press Space", Touch = "Tap Jump", Gamepad = "Press A" },
	MOVE = { Keyboard = "Use WASD", Touch = "Drag the stick", Gamepad = "Use the left stick" },
	OPEN = { Keyboard = "Click", Touch = "Tap", Gamepad = "Select" },
}

local function currentDevice(): Device
	local ok, preferred = pcall(function(): EnumItem
		return UserInputService.PreferredInput
	end)
	if ok then
		if preferred == Enum.PreferredInput.Touch then
			return "Touch"
		elseif preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad then
			return "Gamepad"
		end
		return "Keyboard"
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.sub(last.Name, 1, 7) == "Gamepad" then
		return "Gamepad"
	end
	return "Keyboard"
end

local function isGamepadKey(code: Enum.KeyCode): boolean
	local name = code.Name
	return string.sub(name, 1, 6) == "Button" or string.sub(name, 1, 4) == "DPad" or string.sub(name, 1, 10) == "Thumbstick"
end

-- Label from an InputAction's bindings, so remapped keys show correctly.
local function labelFromAction(action: Instance, device: Device): string?
	if not action:IsA("InputAction") then
		return nil
	end
	for _, binding in action:GetChildren() do
		if binding:IsA("InputBinding") then
			local code = (binding :: any).KeyCode :: Enum.KeyCode
			if code ~= Enum.KeyCode.Unknown then
				if device == "Gamepad" and isGamepadKey(code) then
					return "Press " .. (string.gsub(code.Name, "^Button", ""))
				elseif device == "Keyboard" and not isGamepadKey(code) then
					local text = UserInputService:GetStringForKeyCode(code)
					return "Press " .. (if text ~= "" then string.upper(text) else code.Name)
				end
			end
		end
	end
	return nil
end

local function makeDefaultUi(): ClientUi
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "LihFolkTutorialUI"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 20

	local function label(name: string, y: number, size: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, y)
		l.Size = UDim2.fromOffset(0, 0)
		l.AutomaticSize = Enum.AutomaticSize.XY
		l.BackgroundColor3 = Color3.fromRGB(22, 15, 43)
		l.BackgroundTransparency = 0.15
		l.TextColor3 = color
		l.TextSize = size
		l.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
		l.TextWrapped = true
		l.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = l
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent = l
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(520, math.huge)
		limit.Parent = l
		l.Parent = gui
		return l
	end

	local objective = label("Objective", 12, 22, Color3.new(1, 1, 1))
	local hint = label("Hint", 64, 18, Color3.fromRGB(255, 210, 74))
	gui.Parent = player:WaitForChild("PlayerGui")

	return {
		showObjective = function(_stepId: string, text: string, progress: number, goal: number)
			objective.Text = if goal > 1 then `{text}  {progress}/{goal}` else text
			objective.Visible = true
		end,
		hideObjective = function()
			objective.Visible = false
		end,
		showHint = function(_stepId: string, text: string)
			hint.Text = text
			hint.Visible = true
		end,
		hideHint = function()
			hint.Visible = false
		end,
	}
end

export type ClientTutorial = {
	Start: (self: ClientTutorial) -> (),
	Report: (self: ClientTutorial, clientSignal: string) -> (),
	RequestSkip: (self: ClientTutorial) -> (),
	Format: (self: ClientTutorial, text: string) -> string,
	GetState: (self: ClientTutorial) -> PublicState?,
	Destroy: (self: ClientTutorial) -> (),
}

local Client = {}

-- The built-in banner, exported so a game can extend it (reveal, skip button) instead of rewriting it.
Client.DefaultUi = makeDefaultUi

function Client.new(config: ClientConfig): ClientTutorial
	assert(RunService:IsClient(), "LihFolkTutorial.Client.new must run on the client")
	local byId = indexSteps(config.steps)
	local player = Players.LocalPlayer
	local glyphs = config.glyphs or DEFAULT_GLYPHS
	local self = {} :: any

	local ui: ClientUi? = config.ui
	local state: PublicState? = nil
	local focusId: string? = nil
	local stepStarted = 0
	local lastProgress = -1
	local hintShown: { [string]: boolean } = {}
	local revealed: { [string]: boolean } = {}
	local guidance: { Instance } = {}
	local tweens: { Tween } = {}
	local promptsTagged: { Instance } = {}
	local connections: { RBXScriptConnection } = {}
	local hintThread: thread? = nil
	local device: Device = currentDevice()

	local function reducedMotion(): boolean
		if config.reducedMotion then
			return true
		end
		local ok, value = pcall(function(): boolean
			return GuiService.ReducedMotionEnabled
		end)
		return ok and value == true
	end

	function self.Format(_: ClientTutorial, text: string): string
		return (string.gsub(text, "{(%u+)}", function(token: string): string
			local actions = config.inputActions
			if actions and actions[token] then
				local fromBinding = labelFromAction(actions[token], device)
				if fromBinding then
					return fromBinding
				end
			end
			local set = glyphs[token] or DEFAULT_GLYPHS[token]
			if set then
				return set[device] or set.Keyboard or token
			end
			return token
		end))
	end

	local function clearGuidance()
		for _, tween in tweens do
			tween:Cancel()
		end
		table.clear(tweens)
		for _, inst in guidance do
			inst:Destroy()
		end
		table.clear(guidance)
		for _, prompt in promptsTagged do
			CollectionService:RemoveTag(prompt, PROMPT_TAG)
		end
		table.clear(promptsTagged)
	end

	local function resolveTarget(target: Target): (Instance?, Vector3?)
		if target.instance and target.instance.Parent then
			return target.instance, nil
		end
		if target.tag then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local origin = if root and root:IsA("BasePart") then root.Position else Vector3.zero
			local best: Instance? = nil
			local bestDistance = math.huge
			for _, tagged in CollectionService:GetTagged(target.tag) do
				if tagged:IsDescendantOf(workspace) then
					local pos: Vector3? = nil
					if tagged:IsA("BasePart") then
						pos = tagged.Position
					elseif tagged:IsA("Model") then
						pos = tagged:GetPivot().Position
					end
					if pos and (pos - origin).Magnitude < bestDistance then
						best = tagged
						bestDistance = (pos - origin).Magnitude
					end
				end
			end
			if best then
				return best, nil
			end
		end
		if target.path then
			local node: Instance? = workspace
			for _, name in target.path do
				node = if node then node:FindFirstChild(name) else nil
			end
			if node then
				return node, nil
			end
		end
		return nil, target.position
	end

	local function anchorPart(inst: Instance): BasePart?
		if inst:IsA("BasePart") then
			return inst
		elseif inst:IsA("Model") then
			return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
		end
		return inst:FindFirstChildWhichIsA("BasePart", true)
	end

	local function buildGuidance(step: Step)
		clearGuidance()
		local target = step.target
		if target == nil then
			return
		end
		local inst, position = resolveTarget(target)
		local calm = reducedMotion()

		if inst and target.highlight ~= false then
			local highlight = Instance.new("Highlight")
			highlight.Adornee = inst
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded -- honest: no glowing through walls
			highlight.FillColor = config.beamColor or Color3.fromRGB(255, 210, 74)
			highlight.OutlineColor = Color3.new(1, 1, 1)
			highlight.FillTransparency = 0.7
			highlight.OutlineTransparency = 0
			highlight.Parent = inst
			table.insert(guidance, highlight)
			if not calm then
				local pulse = TweenService:Create(highlight, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.45 })
				pulse:Play()
				table.insert(tweens, pulse)
			end
		end

		if inst and target.prompt then
			local prompt = if inst:IsA("ProximityPrompt") then inst else inst:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then
				CollectionService:AddTag(prompt, PROMPT_TAG)
				table.insert(promptsTagged, prompt)
			end
		end

		if target.beam == false then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return
		end
		local endAttachment = Instance.new("Attachment")
		endAttachment.Name = "LFTutorialTarget"
		local part = if inst then anchorPart(inst) else nil
		if part then
			endAttachment.Parent = part
		elseif position then
			endAttachment.Parent = workspace.Terrain
			endAttachment.WorldPosition = position
		else
			endAttachment:Destroy()
			return
		end
		table.insert(guidance, endAttachment)

		local startAttachment = Instance.new("Attachment")
		startAttachment.Name = "LFTutorialFrom"
		startAttachment.Position = Vector3.new(0, -2.6, 0) -- near the feet: reads as a path, not a laser
		startAttachment.Parent = root
		table.insert(guidance, startAttachment)

		local beam = Instance.new("Beam")
		beam.Attachment0 = startAttachment
		beam.Attachment1 = endAttachment
		beam.FaceCamera = true
		beam.Width0 = 0.8
		beam.Width1 = 0.8
		beam.Segments = 20
		beam.LightEmission = 0.6
		beam.Color = ColorSequence.new(config.beamColor or Color3.fromRGB(255, 210, 74))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.35),
			NumberSequenceKeypoint.new(0.85, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		if config.beamTexture then
			beam.Texture = config.beamTexture
			beam.TextureMode = Enum.TextureMode.Static
			beam.TextureLength = 2
			beam.TextureSpeed = if calm then 0 else 1
		end
		beam.Parent = startAttachment
		table.insert(guidance, beam)
	end

	local function hintText(step: Step): string?
		local hint = step.hint
		if hint == nil then
			return nil
		end
		local raw = hint[device] or hint.any
		return if raw then self:Format(raw) else nil
	end

	local function render()
		local current = state
		local view = ui
		if current == nil or view == nil then
			return
		end
		if view.setSkipVisible then
			view.setSkipVisible(current.canSkip and not current.finished)
		end
		for _, key in current.reveal do
			if not revealed[key] then
				revealed[key] = true
				if view.reveal then
					view.reveal(key)
				end
			end
		end
		-- Focus: the first active step (list steps in teaching order). One goal on screen at a time.
		local nextFocus = current.active[1]
		if nextFocus == nil then
			clearGuidance()
			view.hideObjective()
			view.hideHint()
			focusId = nil
			return
		end
		local step = byId[nextFocus]
		local progress = current.progress[nextFocus] or 0
		if nextFocus ~= focusId then
			if focusId and view.celebrate and not table.find(current.active, focusId) then
				view.celebrate(focusId)
			end
			focusId = nextFocus
			stepStarted = os.clock()
			lastProgress = progress
			view.hideHint()
			if (step.guide or "always") == "always" then
				buildGuidance(step)
			else
				clearGuidance()
			end
		elseif progress ~= lastProgress then
			lastProgress = progress
			stepStarted = os.clock() -- progress resets the stuck timer
			view.hideHint()
		end
		view.showObjective(nextFocus, self:Format(step.objective), progress, current.goal[nextFocus] or 1)
	end

	-- Stuck scheduler: one check per second, cheap; shows the hint (and late guidance) once per step.
	local function hintLoop()
		while true do
			task.wait(1)
			local id = focusId
			local view = ui
			if id and view and not hintShown[id] then
				local step = byId[id]
				if os.clock() - stepStarted >= (step.hintAfter or 8) then
					hintShown[id] = true
					local text = hintText(step)
					if text then
						view.showHint(id, text)
					end
					if step.guide == "whenStuck" then
						buildGuidance(step)
					end
					config.remote:FireServer("hint", id)
				end
			end
		end
	end

	local function readState()
		local raw = player:GetAttribute(STATE_ATTRIBUTE)
		if type(raw) ~= "string" then
			return
		end
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(decoded) == "table" then
			state = decoded :: PublicState
			render()
		end
	end

	function self.Start(_: ClientTutorial)
		if ui == nil then
			ui = makeDefaultUi()
		end
		table.insert(connections, player:GetAttributeChangedSignal(STATE_ATTRIBUTE):Connect(readState))
		local function onDeviceChanged()
			local nextDevice = currentDevice()
			if nextDevice ~= device then
				device = nextDevice
				render()
			end
		end
		table.insert(connections, UserInputService.LastInputTypeChanged:Connect(onDeviceChanged))
		pcall(function()
			table.insert(connections, UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(onDeviceChanged))
		end)
		table.insert(connections, player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("HumanoidRootPart", 10)
			local id = focusId
			if id then
				local step = byId[id]
				if (step.guide or "always") == "always" or hintShown[id] then
					buildGuidance(step) -- the old beam died with the old character
				end
			end
		end))
		hintThread = task.spawn(hintLoop)
		readState()
	end

	-- For UI-only steps (opened a menu, rotated the camera). The server accepts it only for the active step.
	function self.Report(_: ClientTutorial, clientSignal: string)
		config.remote:FireServer("clientSignal", clientSignal)
	end

	function self.RequestSkip(_: ClientTutorial)
		config.remote:FireServer("skip")
	end

	function self.GetState(_: ClientTutorial): PublicState?
		return state
	end

	function self.Destroy(_: ClientTutorial)
		clearGuidance()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		if hintThread then
			pcall(task.cancel, hintThread)
			hintThread = nil
		end
	end

	return self :: ClientTutorial
end

return {
	Server = Server,
	Client = Client,
	STATE_ATTRIBUTE = STATE_ATTRIBUTE,
	PROMPT_TAG = PROMPT_TAG,
}
