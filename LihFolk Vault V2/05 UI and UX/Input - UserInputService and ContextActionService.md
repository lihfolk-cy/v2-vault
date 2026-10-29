---
tags: [input, userinputservice, contextactionservice, input-action-system, touch, keyboard, type/guide, area/ui, level/intermediate, api/ContextActionService, api/UserInputService, api/InputAction]
---
# Input - UserInputService and ContextActionService

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Gameplay handlers that ignore `gameProcessedEvent`.
> - Avoid: `MouseButton1Click` instead of `Activated`.
> - Avoid: CAS bindings never unbound when the context ends.
> - All UI actions use `Activated`.
> - Every `UserInputService` gameplay handler checks `gameProcessedEvent`.
> - Actions have keyboard, gamepad and touch bindings.
>
> Cost: TL;DR ~130 tok · whole note ~4.0k tok. Read more: ## 4. ContextActionService · ## 5. The Input Action System · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox has three generations of input API living side by side: `UserInputService` (raw events and device state), `ContextActionService` (named actions bound to inputs while a context is active, with automatic touch buttons), and the newer **Input Action System** (`InputContext`, `InputAction`, `InputBinding` instances configured at edit time). This note explains what each is for, how input flows between UI and the game, how to show the right prompt for the player's device, and the production traps (typing in chat triggers abilities, a held key stuck after a menu opens, touch buttons stacking on top of each other).

Sources: **Docs** (UserInputService, ContextActionService, GuiObject, GuiButton, the "Input Action System", "Input" and "Cross-platform" guides; October 2026), the **reference project** (one production game), and **rule of thumb**.

---

## 1. Which API for what

| Need | API |
|---|---|
| A button press in your UI | `GuiButton.Activated` |
| Global key/button/touch events, mouse position, device capabilities | `UserInputService` |
| "Press E to open the door while near it", with a touch button on phones | `ContextActionService` or the Input Action System |
| A full cross-platform control scheme (move, sprint, abilities) with priorities and rebinding | Input Action System |
| Which device the player is using right now | `UserInputService.PreferredInput` |
| Showing the right key/button glyph | `InputAction.PreferredBinding`, `InputActionLabel`, or `UserInputService:GetImageForKeyCode` / `GetStringForKeyCode` |

Roblox's cross-platform guidance now recommends the Input Action System for supporting all primary input types (Docs). `ContextActionService` is not deprecated (only its `BindActionToInputTypes` method is superseded) and remains common in existing code.

---

## 2. UI buttons: use Activated

`GuiButton.Activated` fires for mouse click, touch tap and gamepad A on a selected button (it passes the `InputObject` and a click count; Docs). `MouseButton1Click` is mouse-specific in name and intent. Use `Activated` for every UI action so touch and gamepad work without extra code.

Buttons have more useful members than most code uses:

- `Interactable = false` disables presses and hover states (`GuiState` becomes `NonInteractable`).
- `SecondaryActivated` for right-click or secondary input.
- `HoverHapticEffect` and `PressHapticEffect` accept `HapticEffect` instances for controller and mobile feedback (Docs).
- `InputSink` (default `Activate` on buttons) decides whether clicks continue into the 3D world ([[ScreenGui Fundamentals]]).

---

## 3. UserInputService

### Events

`InputBegan`, `InputChanged`, `InputEnded` fire with an `InputObject` and a boolean `gameProcessedEvent`. Touch-specific events (`TouchStarted`, `TouchTap`, `TouchPinch`, `TouchSwipe`, `TouchLongPress`, `TouchTapInWorld`, and more) and `GamepadConnected` exist too (Docs).

**`gameProcessedEvent` is the most important argument in Roblox input.** It is true when the engine already used the input: a `TextBox` has focus (the player is typing), a GUI button consumed the click, or core UI (chat, menus) handled it. Ignore processed input for gameplay:

```lua
--!strict
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return -- typing in chat, clicking a button, etc.
	end
	if input.KeyCode == Enum.KeyCode.Q then
		-- dash
	end
end)
```

Without this check, players typing "quest" in chat dash, open menus and fire abilities. It is the single most common input bug in Roblox games.

### State and capabilities

| Member | Use |
|---|---|
| `PreferredInput` (`KeyboardAndMouse`, `Gamepad`, `Touch`, `MicroGamepad`) | The primary input right now; changes when the player picks up a gamepad (Docs) |
| `GetLastInputType()` and `LastInputTypeChanged` | Finer-grained, flickers with every input; prefer `PreferredInput` for UI decisions |
| `TouchEnabled`, `KeyboardEnabled`, `MouseEnabled`, `GamepadEnabled` | Capabilities, not current use |
| `MouseBehavior`, `MouseIconEnabled` | Lock the mouse (first person, shift lock) or hide the cursor |
| `GetFocusedTextBox()`, `TextBoxFocused`, `TextBoxFocusReleased` | Detect typing |
| `OnScreenKeyboardVisible`, `OnScreenKeyboardSize`, `OnScreenKeyboardPosition` | Move input fields above the phone keyboard |
| `GetStringForKeyCode`, `GetImageForKeyCode` | Device-appropriate key labels and button images |

`UserInputService.ModalEnabled` (hide mobile controls) is superseded by `GuiService.TouchControlsEnabled` (Docs).

---

## 4. ContextActionService

`BindAction(name, handler, createTouchButton, ...inputs)` binds a named action while a context is active; `UnbindAction(name)` removes it (Docs). The handler receives `(actionName, inputState, inputObject)` and can return `Enum.ContextActionResult.Pass` to let lower bindings also receive the input, or `Sink` (the default when nothing is returned).

Docs' principles worth keeping:

- Name actions after **what they do**, not the key ("CarHorn", not "KeyH").
- **Most recent binding wins** for the same input; unbinding restores the previous one. `BindActionAtPriority(name, fn, touch, priority, ...)` makes order explicit.
- `Cancel` state is sent if an in-progress input is overridden by a new binding or the action is unbound. Handle it, or a held "charge" never releases.

```lua
--!strict
local ContextActionService = game:GetService("ContextActionService")

local ACTION_INTERACT = "Interact"

local function onInteract(_: string, state: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		-- open the nearby door
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function enterDoorZone()
	ContextActionService:BindActionAtPriority(
		ACTION_INTERACT,
		onInteract,
		true, -- create a touch button on mobile
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonX
	)
	ContextActionService:SetTitle(ACTION_INTERACT, "Open")
	ContextActionService:SetPosition(ACTION_INTERACT, UDim2.new(1, -170, 1, -170))
end

local function leaveDoorZone()
	ContextActionService:UnbindAction(ACTION_INTERACT)
end
```

### Touch buttons from CAS

The auto-created touch buttons live in a core container near the jump button. They are convenient for prototypes; production games usually build their own touch buttons because the defaults are small, generic and overlap each other when several actions are bound. For simple world interaction, `ProximityPrompt` gives a touch-friendly prompt with no extra code.

---

## 5. The Input Action System

Instances configured in Studio (or built in code), usually in a folder in `ReplicatedStorage` (Docs):

- **`InputContext`**: a group of actions. `Enabled`, `Priority`, and `Sink` (consume its bound key codes so lower-priority contexts do not see them). Example: `PlayContext` (gameplay) and `MenuContext` (UI navigation), enabling the menu context while a menu is open.
- **`InputAction`**: one mechanic ("Sprint", "Shoot", "CameraRotate"). `Type` is `Bool`, `Direction1D`, `Direction2D`, `Direction3D` or `ViewportPosition`. Events `Pressed` and `Released` (Bool only) and `StateChanged` (all types); `GetState()` to poll; `Fire()` to drive it from code; `DisplayName`; read-only `PreferredBinding` (the child binding matching the current device).
- **`InputBinding`**: one hardware mapping. `KeyCode`, composite directions (`Up`, `Down`, `Left`, `Right`, `Forward`, `Backward`), `UIButton` (a `GuiButton` that drives the action on touch), modifiers (`PrimaryModifier`, `SecondaryModifier`, `UIModifier`), analog thresholds (`PressedThreshold`, `ReleasedThreshold`), `Scale`, `Vector2Scale`, `ResponseCurve`, `ClampMagnitudeToOne`, `DisplayName`, `DisplayImage`.

Default player scripts can also be switched to the system with `Workspace.PlayerScriptsUseInputActionSystem` (Docs).

### Building it in code

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local inputs = ReplicatedStorage:WaitForChild("Inputs")
local play = Instance.new("InputContext")
play.Name = "PlayContext"
play.Priority = 1000
play.Parent = inputs

local dash = Instance.new("InputAction")
dash.Name = "Dash"
dash.Type = Enum.InputActionType.Bool
dash.Parent = play

local function bind(name: string, key: Enum.KeyCode?)
	local b = Instance.new("InputBinding")
	b.Name = name
	if key then
		b.KeyCode = key
	end
	b.Parent = dash
	return b
end

bind("Keyboard", Enum.KeyCode.Q)
bind("Gamepad", Enum.KeyCode.ButtonB)
local touch = bind("Touch", nil)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
touch.UIButton = playerGui:WaitForChild("TouchCombat"):WaitForChild("DashButton") :: GuiButton

dash.Pressed:Connect(function()
	-- perform dash (and tell the server; it validates cooldowns)
end)
```

For continuous analog input (camera rotation, throttle), `StateChanged` fires only when the value changes, so a thumbstick held still fires once. Poll `GetState()` each frame and multiply by delta time (Docs).

### Displaying the right prompt

- `InputActionLabel` (a `GuiObject`, beta as of October 2026): point it at an `InputAction` and it shows the correct key or button glyph for the current device, updating when the player switches (Docs).
- `InputAction.PreferredBinding` for custom hint UI: read the binding's `KeyCode`, `DisplayName` or `DisplayImage`, and refresh on change.
- Fallback for any system: `UserInputService:GetImageForKeyCode(keyCode)` gives platform-specific gamepad images, and `GetStringForKeyCode` gives keyboard strings (Docs).

---

## 6. Input and UI state

Rules that prevented the reference project's input bugs:

- **Menus own input while open.** Opening a panel should disable gameplay actions that conflict (enable a menu context with `Sink`, or unbind CAS actions), and closing should restore them. Otherwise pressing Q in a shop dashes the character behind it.
- **Release held inputs on context switch.** If a menu opens while sprint is held, the release happens inside the menu context and gameplay never sees it: the character sprints forever. Reset held states when contexts change (CAS sends `Cancel`; handle it).
- **Tutorials restrict input.** During the reference project's tutorial, the server's roll remote refused rolls except on the roll step, golden rolls and pulls were disabled, and the HUD showed only the needed button. Restricting on the server matters: a client-only restriction is bypassed by exploiters and by edge cases like a second tap arriving during an animation.
- **Touch: separate buttons, generous pads.** The reference project's combat cluster (attack, dash, throw, slide, run, block) was placed by percentages and overlapped on some phones until a final pass separated real rectangles. Small buttons got invisible 48 px tap pads. Touch players also sprint automatically when moving, removing a button entirely: fewer buttons is the best touch UX.
- **Hotkeys are documented in UI.** Every keyboard shortcut (J for quests, B for backpack) appears as a small key hint on the corresponding HUD button for keyboard players and disappears for touch players.

---

## 7. Mobile specifics

- `UserInputService.OnScreenKeyboardVisible` and its size and position let you lift a text field above the keyboard; otherwise a codes box at the bottom of a phone is hidden while the player types.
- Do not depend on hover. Tooltips need a tap-to-show path (the reference project's reward tooltips show on tap and hide after 2.5 s).
- Long-press and swipe gestures are discoverable only if taught; avoid them for core actions.
- `GuiService.TouchControlsEnabled = false` hides Roblox's touch controls (thumbstick, jump) for screens like a full-screen minigame; restore them afterwards.
- Haptics: `HapticEffect` instances (types like `UIClick` or `GameplayCollision`) work on supported gamepads and mobile (Docs); use them lightly.

---

## 8. Choosing between CAS and the Input Action System

Both solve "bind named actions to inputs per context". The trade-offs as of October 2026:

| Concern | ContextActionService | Input Action System |
|---|---|---|
| Where bindings live | In code (`BindAction` calls) | Instances, editable in Studio, or built in code |
| Priorities | `BindActionAtPriority`; most recent wins on ties | `InputContext.Priority` and `Sink` per context |
| Touch | Auto-generated generic buttons, or your own buttons calling your code | `InputBinding.UIButton` links any `GuiButton` you design |
| Analog values | Read from the `InputObject` yourself | Typed actions (`Direction1D/2D/3D`) with thresholds, scale and response curves |
| Showing glyphs | Manual (`GetImageForKeyCode`) | `PreferredBinding`, `InputActionLabel` (beta) |
| Modifiers (Shift + key) | Manual | `PrimaryModifier`, `SecondaryModifier` |
| Rebinding by players | You build it | Change `KeyCode` on bindings at runtime; still your UI |
| Maturity | Long-standing, everywhere in old code | Newer; check docs for changes |

A pragmatic migration: keep existing CAS bindings working, build new systems on the Input Action System, and move gameplay actions over context by context (menu context first, because it is where priority and sinking bugs live). Do not bind the same key to the same action in both systems at once; you will get double fires.

### Debugging input

- `ContextActionService:GetAllBoundActionInfo()` lists every CAS action with its inputs and priority (Docs): print it when "the key does nothing".
- The Input Action System exposes read-only debug state on actions (`BoolState`, `Direction2DState`, and so on) in the Properties window during play tests (Docs).
- Log `gameProcessedEvent` alongside the key when chasing "sometimes it does not fire": a focused `TextBox` somewhere (often an invisible one left focused) is the usual answer. `UserInputService:GetFocusedTextBox()` tells you which.

---

## Common mistakes

- Gameplay handlers that ignore `gameProcessedEvent`.
- `MouseButton1Click` instead of `Activated`.
- CAS bindings never unbound when the context ends.
- Not handling `Cancel` for held actions.
- Gameplay actions still live while a menu is open.
- Default CAS touch buttons stacking over each other.
- Input restrictions enforced only on the client.

## Checklist

- [ ] All UI actions use `Activated`.
- [ ] Every `UserInputService` gameplay handler checks `gameProcessedEvent`.
- [ ] Actions have keyboard, gamepad and touch bindings.
- [ ] Menus switch input context; held inputs are released on switch.
- [ ] Prompts show device-correct glyphs and update on `PreferredInput` change.
- [ ] Touch buttons are custom, separated and at least 44 px drawn.
- [ ] Server validates every action the UI requests.

See also: [[Gamepad and Console UX]], [[Responsive UI for Phone Tablet Console and PC]], [[HUD Design]], [[Custom Character Controllers]], [[Combat Systems Architecture]], [[Server Authority and Validation]], [[Accessibility]].

## Connected notes
<!-- auto-links:start -->
[[Input Remapping and One-Handed Play]] · Links - Input services · Input Responsiveness Buffering and Coyote Time · Links - Devices · Links - Cross-platform UI · Cookbook - UI
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] · [[Rebinding Controls with the Input Action System]] · [[Touch Gestures - Pinch, Pan, Swipe and Long Press]] · [[Onboarding Accessibility and Cross-Device Prompts]] · [[Drag-and-Drop Inventories and Sliders with UIDragDetector]] · [[UI Design Systems]]
<!-- related:end -->
