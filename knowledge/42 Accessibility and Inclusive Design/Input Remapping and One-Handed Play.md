---
tags: [accessibility, input, remapping, keybinds, one-handed, motor, gamepad, touch, contextactionservice, input-action-system]
---
# Input Remapping and One-Handed Play

[[Input - UserInputService and ContextActionService]] covers the three input APIs and when to use each. [[Gamepad and Console UX]] covers controller menus and selection. [[Accessibility]] lists the motor basics (big targets, no rapid tapping). This note is the motor-accessibility layer on top: a full remapping system with capture, conflict handling, reserved keys, keyboard-layout-aware labels and server-validated saving; hold-versus-toggle and repeat options; one-handed presets for keyboard, gamepad and touch; a movable touch layout; and timing assists.

Sources: **Roblox docs (as of October 2026)** for `ContextActionService`, `UserInputService`, and the Input Action System classes; **rule of thumb** for design choices and numbers.

---

## 1. Who needs this

- **Players with limited dexterity or strength** (cerebral palsy, muscular dystrophy, arthritis, repetitive strain injury). They need fewer simultaneous inputs, no rapid tapping, no long holds, and keys placed where they can reach them.
- **One-handed players**, permanently (limb difference, paralysis) or temporarily (a broken wrist, a baby in one arm, a drink in the other). They need every action reachable from one side of the keyboard, from a mouse alone, or from one half of a controller.
- **Players using adaptive hardware.** Adaptive controllers generally present themselves to the system as standard gamepads with remapped buttons (rule of thumb), so full gamepad support plus remapping covers most of them.
- **Left-handed players and players with non-QWERTY keyboards.** Not a disability, but the same system serves them.

The common thread: the player, not the designer, decides which physical input triggers which action, and whether actions need holding, tapping or repeating.

---

## 2. Which API to remap with

| Approach | How remapping works | Fit |
|---|---|---|
| `ContextActionService` | Unbind the action, bind it again with the new `KeyCode`s | Works today with any existing CAS code; you build all the UI |
| Input Action System (`InputContext`, `InputAction`, `InputBinding`) | Change `KeyCode` (and modifiers) on the action's `InputBinding`, or add another binding | Cleaner model of actions with multiple bindings; check runtime writability |
| Raw `UserInputService` | Your own table from `KeyCode` to action | Flexible, but you reimplement priorities and touch buttons |

Facts from Roblox docs (as of October 2026):

- `ContextActionService:BindAction(name, handler, createTouchButton, ...inputTypes)` binds inputs to a handler; bindings form a stack where the most recently bound handler for an input runs first. `BindActionAtPriority` overrides bind order, and `BindAction` uses priority 2000. `UnbindAction` does not error if nothing is bound. A handler that returns `Enum.ContextActionResult.Pass` lets lower bindings handle the input; any other return, including `nil`, sinks it, and a handler that yields also sinks it.
- `createTouchButton = true` creates an on-screen button on touch devices, up to 7 of them, while the action is bound; `GetButton` returns it (or `nil` on non-touch devices), and `SetPosition`, `SetImage` and `SetTitle` customise it. These setters fail silently if the action is not bound.
- `InputBinding` has `KeyCode`, `PrimaryModifier`, `SecondaryModifier`, directional keys (`Up`, `Down`, `Left`, `Right`, `Forward`, `Backward`), `UIButton`, `UIModifier`, `PressedThreshold`, `ReleasedThreshold`, `Scale`, `ResponseCurve`, `DisplayName` and `DisplayImage`, among others. `InputAction` has `Pressed`, `Released` and `StateChanged` events, `GetState()`, and a read-only `PreferredBinding`.
- The Input Action System guide mentions that the action label updates when a player rebinds a control, which implies rebinding is supported, but the reference pages I checked do not explicitly document which `InputBinding` properties are writable at runtime from a LocalScript. **Unconfirmed**: test that writing `binding.KeyCode` in a live client takes effect before you build on it. The CAS approach below works either way.
- `UserInputService:GetStringForKeyCode(keyCode)` returns the character the player should actually press for a `KeyCode`. Docs note that on non-QWERTY layouts key codes map to QWERTY positions, so `KeyCode.Q` returns "A" on AZERTY. Use it for every keyboard label in your UI.

That last point matters for remapping. `KeyCode` values are positional. If your defaults are W, A, S, D, they are in the right place on AZERTY too, but the labels must come from `GetStringForKeyCode` or French players see "W" where their key says "Z".

---

## 3. Designing the remap model

Before writing code, decide the data:

- **Actions** are named, stable ids ("Sprint", "Attack", "Ability1", "Interact", "OpenMap"). Never store bindings by display name.
- **Each action has slots per device family:** keyboard/mouse (two slots: primary and alternate), gamepad (one slot), touch (handled by layout, section 6).
- **Defaults** live in code. Saved data stores only differences from defaults, so adding a new action later gives everyone its default without a migration.
- **Reserved inputs** can never be bound: the keys the Roblox client uses for its own menus and shortcuts (for example `Escape`), and any input you reserve for opening your settings menu (so a player can never lock themselves out). Keep the reserved list conservative; I did not find an authoritative full list of engine-reserved keys in docs, so test candidate keys in a live client.
- **Conflicts** happen when a new binding is already used. Offer a swap (the other action gets the old key) rather than an error; it is the least frustrating behaviour. Some pairs can share an input safely if they are never active in the same context (a menu "Confirm" and a gameplay "Jump"); record contexts per action so the conflict check is context-aware.

### Data shape

```lua
--!strict
-- Shared/InputSchema.lua: action ids, defaults and validation shared by client and server.
local InputSchema = {}

export type Device = "Keyboard" | "Gamepad"
export type Slot = "Primary" | "Alternate"
export type Context = "Gameplay" | "Menu"

export type ActionDef = {
	context: Context,
	defaults: { Keyboard: { Primary: Enum.KeyCode, Alternate: Enum.KeyCode? }, Gamepad: Enum.KeyCode? },
	holdable: boolean, -- may be switched between hold and toggle
}

InputSchema.VERSION = 1

InputSchema.Actions = {
	Sprint = { context = "Gameplay", holdable = true, defaults = { Keyboard = { Primary = Enum.KeyCode.LeftShift }, Gamepad = Enum.KeyCode.ButtonL3 } },
	Attack = { context = "Gameplay", holdable = false, defaults = { Keyboard = { Primary = Enum.KeyCode.F }, Gamepad = Enum.KeyCode.ButtonR2 } },
	Ability1 = { context = "Gameplay", holdable = false, defaults = { Keyboard = { Primary = Enum.KeyCode.Q }, Gamepad = Enum.KeyCode.ButtonX } },
	Interact = { context = "Gameplay", holdable = false, defaults = { Keyboard = { Primary = Enum.KeyCode.E }, Gamepad = Enum.KeyCode.ButtonY } },
	Aim = { context = "Gameplay", holdable = true, defaults = { Keyboard = { Primary = Enum.KeyCode.R }, Gamepad = Enum.KeyCode.ButtonL2 } },
} :: { [string]: ActionDef }

InputSchema.Reserved = {
	[Enum.KeyCode.Escape] = true,
	[Enum.KeyCode.ButtonStart] = true,
	[Enum.KeyCode.ButtonSelect] = true,
	[Enum.KeyCode.Unknown] = true,
} :: { [Enum.KeyCode]: boolean }

local function isGamepadKey(code: Enum.KeyCode): boolean
	return string.sub(code.Name, 1, 6) == "Button" or string.sub(code.Name, 1, 5) == "DPad"
end

-- Saved form: { v = 1, kb = { [action] = { p = "KeyName", a = "KeyName"? } }, gp = { [action] = "KeyName" }, hold = { [action] = "Toggle" } }
export type Saved = {
	v: number,
	kb: { [string]: { p: string?, a: string? } }?,
	gp: { [string]: string }?,
	hold: { [string]: string }?,
}

local function keyFromName(name: unknown): Enum.KeyCode?
	if type(name) ~= "string" or #name > 32 then
		return nil
	end
	local ok, code = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	if ok and typeof(code) == "EnumItem" and (code :: EnumItem).EnumType == Enum.KeyCode then
		return code :: Enum.KeyCode
	end
	return nil
end
InputSchema.keyFromName = keyFromName

-- Returns a cleaned copy containing only valid entries. Never errors on bad input.
function InputSchema.sanitize(raw: unknown): Saved
	local out: Saved = { v = InputSchema.VERSION, kb = {}, gp = {}, hold = {} }
	if type(raw) ~= "table" then
		return out
	end
	local data = raw :: { [any]: any }
	local kbOut = out.kb :: { [string]: { p: string?, a: string? } }
	local gpOut = out.gp :: { [string]: string }
	local holdOut = out.hold :: { [string]: string }

	if type(data.kb) == "table" then
		for action, slots in data.kb do
			if InputSchema.Actions[action] and type(slots) == "table" then
				local p, a = keyFromName(slots.p), keyFromName(slots.a)
				local entry: { p: string?, a: string? } = {}
				if p and not InputSchema.Reserved[p] and not isGamepadKey(p) then entry.p = p.Name end
				if a and not InputSchema.Reserved[a] and not isGamepadKey(a) then entry.a = a.Name end
				if entry.p or entry.a then
					kbOut[action] = entry
				end
			end
		end
	end
	if type(data.gp) == "table" then
		for action, name in data.gp do
			local code = keyFromName(name)
			if InputSchema.Actions[action] and code and isGamepadKey(code) and not InputSchema.Reserved[code] then
				gpOut[action] = code.Name
			end
		end
	end
	if type(data.hold) == "table" then
		for action, mode in data.hold do
			local def = InputSchema.Actions[action]
			if def and def.holdable and (mode == "Hold" or mode == "Toggle") then
				holdOut[action] = mode
			end
		end
	end
	return out
end

return InputSchema
```

Storing `KeyCode.Name` strings rather than numeric values keeps saves readable and stable. `sanitize` is shared because the client uses it to apply data and the server uses it to validate data before saving.

---

## 4. Saving bindings safely

Bindings are client preferences, but they are saved through the server, so the server must treat them as untrusted input like any other remote payload ([[Server Authority and Validation]], [[Remote Abuse Patterns and Rate Limiting in Practice]]):

```lua
--!strict
-- Server: accept a player's input bindings, sanitise, size-check, rate-limit, store in the profile.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InputSchema = require(ReplicatedStorage.Shared.InputSchema)

local remote = ReplicatedStorage.Remotes.SaveInputBindings :: RemoteEvent
local MAX_BYTES = 4000
local MIN_INTERVAL = 2 -- seconds between saves per player

local lastSave: { [Player]: number } = {}

-- Provided by your profile system (see the data persistence notes).
local Profiles = require(script.Parent.Profiles)

remote.OnServerEvent:Connect(function(player: Player, payload: unknown)
	local now = os.clock()
	if now - (lastSave[player] or 0) < MIN_INTERVAL then
		return
	end
	lastSave[player] = now

	-- Cheap size guard before any deep inspection.
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, payload)
	if not ok or #encoded > MAX_BYTES then
		return
	end

	local clean = InputSchema.sanitize(payload)
	local profile = Profiles.get(player)
	if profile then
		profile.Data.settings.input = clean
	end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastSave[player] = nil
end)
```

The client sends the whole binding table after the player closes the remap screen, not on every key change, which keeps the remote quiet. On join, the server includes `profile.Data.settings.input` in the initial data it already sends to the client, and the client runs `sanitize` again before applying (the defaults may have changed since the save).

---

## 5. The client remap controller

The controller owns three jobs: apply bindings to CAS, capture a new key, and resolve conflicts.

```lua
--!strict
-- Client: RemapController. Applies bindings with ContextActionService and captures new keys.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InputSchema = require(ReplicatedStorage.Shared.InputSchema)

type Handler = (actionName: string, state: Enum.UserInputState, input: InputObject) -> Enum.ContextActionResult?

local RemapController = {}

local handlers: { [string]: Handler } = {}
local saved: InputSchema.Saved = InputSchema.sanitize(nil)
local toggled: { [string]: boolean } = {}

local function keyboardFor(action: string): { Enum.KeyCode }
	local def = InputSchema.Actions[action]
	local slots = saved.kb and saved.kb[action]
	local p = (slots and slots.p and InputSchema.keyFromName(slots.p)) or def.defaults.Keyboard.Primary
	local a = (slots and slots.a and InputSchema.keyFromName(slots.a)) or def.defaults.Keyboard.Alternate
	local list = { p }
	if a then
		table.insert(list, a)
	end
	return list
end

local function gamepadFor(action: string): Enum.KeyCode?
	local name = saved.gp and saved.gp[action]
	return (name and InputSchema.keyFromName(name)) or InputSchema.Actions[action].defaults.Gamepad
end

local function holdMode(action: string): string
	return (saved.hold and saved.hold[action]) or "Hold"
end

-- Wraps the game's handler so "Toggle" mode turns press-press into begin-end.
local function wrap(action: string, inner: Handler): Handler
	return function(name, state, input)
		if holdMode(action) ~= "Toggle" then
			return inner(name, state, input)
		end
		if state == Enum.UserInputState.Begin then
			toggled[action] = not toggled[action]
			local synthetic = if toggled[action] then Enum.UserInputState.Begin else Enum.UserInputState.End
			return inner(name, synthetic, input)
		elseif state == Enum.UserInputState.Cancel then
			toggled[action] = false
			return inner(name, Enum.UserInputState.Cancel, input)
		end
		return Enum.ContextActionResult.Sink -- ignore key release in toggle mode
	end
end

local function bind(action: string)
	local handler = handlers[action]
	if not handler then
		return
	end
	ContextActionService:UnbindAction(action)
	local inputs: { Enum.KeyCode } = keyboardFor(action)
	local pad = gamepadFor(action)
	if pad then
		table.insert(inputs, pad)
	end
	ContextActionService:BindAction(action, wrap(action, handler), false, table.unpack(inputs))
end

function RemapController.register(action: string, handler: Handler)
	assert(InputSchema.Actions[action], `unknown action {action}`)
	handlers[action] = handler
	bind(action)
end

function RemapController.load(data: unknown)
	saved = InputSchema.sanitize(data)
	table.clear(toggled)
	for action in handlers do
		bind(action)
	end
end

function RemapController.label(action: string): string
	local key = keyboardFor(action)[1]
	local text = UserInputService:GetStringForKeyCode(key)
	return if text ~= "" then text else key.Name
end

-- Returns the action that already uses this key in the same context, if any.
local function conflictFor(action: string, key: Enum.KeyCode): string?
	local ctx = InputSchema.Actions[action].context
	for other, def in InputSchema.Actions do
		if other ~= action and def.context == ctx then
			for _, k in keyboardFor(other) do
				if k == key then
					return other
				end
			end
			if gamepadFor(other) == key then
				return other
			end
		end
	end
	return nil
end

-- Waits for the next key press and assigns it. Escape cancels. Swaps on conflict.
-- Returns the assigned key, or nil if cancelled or timed out.
function RemapController.capture(action: string, slot: InputSchema.Slot, timeout: number): Enum.KeyCode?
	local result: Enum.KeyCode? = nil
	local done = false
	local conn: RBXScriptConnection
	conn = UserInputService.InputBegan:Connect(function(input: InputObject)
		local key = input.KeyCode
		if key == Enum.KeyCode.Escape then
			done = true
			return
		end
		if key == Enum.KeyCode.Unknown or InputSchema.Reserved[key] then
			return -- ignore mouse movement and reserved keys, keep waiting
		end
		local isPad = input.UserInputType.Name:sub(1, 7) == "Gamepad"
		local kb = saved.kb :: { [string]: { p: string?, a: string? } }
		local gp = saved.gp :: { [string]: string }
		local other = conflictFor(action, key)
		if isPad then
			local mine = gamepadFor(action)
			if other and mine then
				gp[other] = mine.Name -- swap: the other action takes our old button
			end
			gp[action] = key.Name
		else
			local current = keyboardFor(action)
			local oldKey: Enum.KeyCode? = if slot == "Primary" then current[1] else current[2]
			if other then
				-- Swap: whichever slot of the other action held this key gets our old key.
				local otherSlots = kb[other] or {}
				kb[other] = otherSlots
				local otherKeys = keyboardFor(other)
				if otherKeys[1] == key then
					otherSlots.p = if oldKey then oldKey.Name else nil
				else
					otherSlots.a = if oldKey then oldKey.Name else nil
				end
			end
			local mySlots = kb[action] or {}
			kb[action] = mySlots
			if slot == "Primary" then
				mySlots.p = key.Name
			else
				mySlots.a = key.Name
			end
		end
		result = key
		done = true
	end)
	local started = os.clock()
	while not done and os.clock() - started < timeout do
		task.wait()
	end
	conn:Disconnect()
	if result then
		RemapController.load(saved) -- re-sanitise and rebind everything, covering both sides of a swap
	end
	return result
end

function RemapController.resetAll()
	RemapController.load(nil)
end

function RemapController.export(): InputSchema.Saved
	return saved
end

return RemapController
```

Behaviour worth noting:

- **Capture ignores reserved keys and keeps waiting**, so a player who accidentally hits Start does not end up with an unusable binding. Escape cancels, so there is always a way out.
- **While capturing, gameplay input should be paused.** Open the remap screen as a menu context so gameplay actions are unbound or sunk; otherwise pressing F to bind "Attack" also attacks.
- **Toggle mode is a wrapper.** The game's sprint handler keeps receiving `Begin` and `End`; it never needs to know whether the player is holding or toggling. `Cancel` (which CAS sends when an action is unbound or taken over) clears the toggle, so a toggled sprint does not stick on after a menu opens. This kind of latched-input bug is easy to ship; [[HUD Design]] is a real example.
- **Labels come from `GetStringForKeyCode`**, so AZERTY players see their own keys.
- **Mouse buttons are not captured** in this version: a mouse click arrives with `KeyCode.Unknown` and is skipped. `BindAction` accepts `Enum.UserInputType` values such as `MouseButton1` as well as key codes, so supporting mouse bindings (needed for the mouse-only preset) means storing a "kind" alongside the name in the schema.
- **One swap edge case:** if a key is moved into an empty alternate slot and the other action held it as a default primary, the other action falls back to its default, which is the same key. Detect this after `load` by running `conflictFor` over all actions and asking the player to pick a key for the action left without one.
- **Reset to defaults** is one call, and the UI should offer it per action and for everything.

---

## 6. One-handed presets and touch layouts

Remapping lets a player build a one-handed layout, but building one from scratch is hard work for the people who need it most. Ship presets.

### Keyboard presets (rule of thumb)

| Preset | Movement | Actions | Camera |
|---|---|---|---|
| Left hand only | WASD | Q, E, R, F, Z, X, C, Shift, Space, Tab, 1 to 5 | Arrow-key camera turn as an option, or auto camera |
| Right hand only | Arrow keys or IJKL | Keys around the right side and the numpad | Numpad or auto camera |
| Mouse only | Click to move or hold a mouse button to move forward | Mouse buttons and wheel; a radial menu for abilities | Mouse |

The camera is the hard part for one-handed keyboard play. Options that help: a camera that follows behind the character automatically (Roblox's default "Follow"-style camera modes, chosen by the player in Roblox settings), a keyboard-controlled camera turn, or a lock-on that keeps the target centred.

### Gamepad

A one-sided preset puts every action on the left stick, D-pad and left shoulder/trigger, or on the right side. Use `ButtonL3`/`ButtonR3` sparingly; clicking a stick while moving it is hard for many players.

### Touch: a movable, resizable layout

Touch players with limited reach or one hand need to place buttons where their thumb lands. A layout editor is a small project with a big payoff:

- Every gameplay button is a `GuiButton` you own (not a CAS auto-button), with a stable id.
- An edit mode lets the player drag each button and change its size (for example 70% to 160%) and opacity.
- The layout is saved per device class (phone vs tablet), as `{ id, position (scale), size multiplier, opacity }`, sanitised on the server like the bindings.
- A "reset layout" and a "left-handed mirror" preset.
- Respect safe areas so a dragged button cannot be placed under a notch ([[Safe Areas and Insets]]).

If you use CAS touch buttons instead, `SetPosition` can move them, but remember that it silently does nothing if the action is not bound at that moment (Roblox docs, as of October 2026), so apply the saved positions after binding.

---

## 7. Fewer inputs, less timing

Remapping changes **where** inputs are. The next layer changes **how many** and **how fast**:

- **Hold or toggle** for every sustained action: sprint, aim, crouch, block, charge. Built into the controller above.
- **Hold to repeat** for repeated actions: clicking, rolling, mining, attacking. A held button repeats at a fixed rate (for example 5 per second). In clicker and simulator genres this is the single most important motor feature; auto-click and auto-roll features are also accessibility features ([[Accessibility]]).
- **No mashing requirements.** Replace "tap X quickly to escape" with "hold X" or a fixed timer, at least as an option.
- **Long holds shortened.** If an interaction requires holding for 2 s, allow a setting to make it a tap (with a confirmation for destructive actions).
- **Combo input buffers.** Accept the next combo input within a generous window (for example 300 to 400 ms) and queue it, rather than requiring frame-precise timing. A buffer helps everyone and changes balance very little.
- **Double-tap alternatives.** Dodge on double-tap should also have a dedicated key.
- **Aim assist and lock-on.** For players who cannot aim precisely, a lock-on toggle or stronger assist is a motor feature. In competitive modes, consider whether assist is fair against mouse players and, if needed, separate matchmaking or limit assist strength.
- **Simultaneous inputs.** Any action that needs two buttons at once (modifier plus key) should be bindable to a single key.

Every one of these must also be applied on the server where it changes gameplay. A hold-to-repeat attack still goes through the same server rate limits as manual attacks; the server should not care how the client produced the input, only that it is within limits ([[Hitboxes and Hit Detection]]).

---

## 8. When not to do this

- **Do not let players bind Escape or your settings key.** A player who locks themselves out of the menu cannot fix it.
- **Do not build a remap UI before your actions are stable.** Remapping hard-codes action ids into saves. Rename later and you need a migration.
- **Do not show raw `KeyCode.Name` to players.** "LeftShift" is acceptable, "KeypadFive" is not; use `GetStringForKeyCode` and a small table of friendly names for non-character keys.
- **Do not make assists shameful.** Labels like "Easy mode for beginners" discourage the players who need them; describe what the option does.

---

## 9. Testing

- Rebind every action, play a session, rejoin, and confirm the bindings persisted.
- Bind two actions to the same key and confirm the swap.
- Try to bind Escape and Start; confirm they are ignored.
- Switch the OS keyboard layout to AZERTY and check every label.
- Play with one hand for ten minutes, using each preset. Note every moment you had to let go of the mouse or move your hand.
- Play a touch session with the layout mirrored and buttons enlarged; check nothing overlaps.
- Toggle sprint, then open a menu; confirm sprint ends.

---

## Common mistakes

- Labels from `KeyCode.Name`, wrong on non-QWERTY keyboards.
- Saved bindings trusted by the server without sanitising.
- Saving full binding tables, so new actions never get defaults.
- Toggle states that survive menus, deaths and respawns.
- Remap capture that triggers gameplay actions while binding.
- CAS touch button positions set before the action is bound (silent no-op).
- Mashing and long holds with no alternative.
- Two-button chords with no single-key option.

## Checklist

- [ ] Stable action ids; defaults in code; saves store only differences.
- [ ] Remap screen with capture, cancel, swap on conflict, reset per action and all.
- [ ] Reserved keys cannot be bound; settings key always reachable.
- [ ] Labels from `GetStringForKeyCode`.
- [ ] Server sanitises and rate-limits binding saves.
- [ ] Hold or toggle for sustained actions; hold to repeat; no mashing.
- [ ] One-handed presets for keyboard and gamepad; movable, resizable touch layout.
- [ ] Assists applied within the same server-side limits as normal input.

See also: [[Accessibility Start Here]], [[Accessibility]], [[Input - UserInputService and ContextActionService]], [[Gamepad and Console UX]], [[Responsive UI for Phone Tablet Console and PC]], [[Safe Areas and Insets]], [[Server Authority and Validation]], [[Difficulty Options and Cognitive Load]].

## Connected notes
<!-- auto-links:start -->
[[Links - Input services]] · [[Links - Devices]] · [[Cookbook - UI]] · [[Input Responsiveness Buffering and Coyote Time]] · [[Safe Area]] · [[Input Buffering]]
<!-- auto-links:end -->
