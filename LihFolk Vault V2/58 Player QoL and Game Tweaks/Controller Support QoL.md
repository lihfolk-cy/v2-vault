---
tags: [qol, gamepad, controller, console, xbox, playstation, haptics, selection, deadzone, type/guide, area/input, level/intermediate, api/GuiService, api/HapticService, api/UserInputService]
---
# Controller Support QoL

<!-- tldr:start -->
> [!tldr] TL;DR
> - Controller stuck on menu open: Nothing selected -> Set `SelectedObject`
> - Keyboard letters shown to pad players: Glyph chosen at startup -> Follow `PreferredInput` live
> - PlayStation players see Xbox glyphs: Custom glyph sheet -> `GetImageForKeyCode`
> - Every menu selects on open; B closes; selection contained.
> - Glyphs follow `PreferredInput` and use engine images.
> - Every HUD action reachable by controller.
>
> Cost: TL;DR ~150 tok · whole note ~1.9k tok. Read more: ## 2. Follow the active device, live · ## 3. Haptics with a setting · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Console and controller players are a real share of Roblox traffic, and they leave fast when a game was clearly only tested with a mouse: menus they cannot navigate, prompts that show keyboard keys, no way to close a panel. [[Gamepad and Console UX]] covers navigation fundamentals in depth. This note is the QoL list on top: what to fix first, glyphs, haptics with a setting, stick tuning, and a handful of gotchas from shipped games.

Sources: **Roblox docs** for `GuiService.SelectedObject` (https://create.roblox.com/docs/reference/engine/classes/GuiService), `HapticService` (https://create.roblox.com/docs/reference/engine/classes/HapticService), `UserInputService.PreferredInput` and `GetImageForKeyCode` (https://create.roblox.com/docs/reference/engine/classes/UserInputService). Numbers are **Rule of thumb**.

## 1. The ten-minute fixes

In order of player impact (**Rule of thumb**):

1. **Every menu selects something when it opens.** Set `GuiService.SelectedObject` to the primary button; otherwise the player is stuck ([[Debugging UI Layout and Input]]).
2. **B closes the top panel.** Always. See [[Shift-Lock Sprint and Gamepad B for Menus]].
3. **Selection stays in the panel.** Set `SelectionGroup = true` on the menu frame (`AddSelectionParent` is deprecated) so selection does not escape into the HUD.
4. **Prompts show controller glyphs** when a gamepad is the active input.
5. **Every HUD button has a controller path**: a bumper/d-pad shortcut or a radial menu.
6. **Text is readable from a sofa**: larger minimum text size on `GuiService:IsTenFootInterface()` devices.

## 2. Follow the active device, live

Players switch between controller and keyboard mid-session, and console players may plug in a keyboard. Use `UserInputService.PreferredInput` (an `Enum.PreferredInput`: `KeyboardAndMouse`, `Touch`, `Gamepad`, ...) and listen for changes, rather than deciding once at startup (**Roblox docs**).

```lua
--!strict
local UserInputService = game:GetService("UserInputService")

local listeners: { (Enum.PreferredInput) -> () } = {}

local function onPreferred(fn: (Enum.PreferredInput) -> ())
	table.insert(listeners, fn)
	fn(UserInputService.PreferredInput)
end

UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
	for _, fn in listeners do
		task.spawn(fn, UserInputService.PreferredInput)
	end
end)

-- Example: swap a prompt's glyph.
onPreferred(function(mode)
	local isPad = mode == Enum.PreferredInput.Gamepad
	-- promptIcon.Image = if isPad then UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonX) else ""
	-- promptText.Text = if isPad then "" else "E"
end)
```

`GetImageForKeyCode` returns an image appropriate to the connected controller type, so PlayStation players see PlayStation glyphs (**Roblox docs**). Do not ship your own Xbox-only glyph sheet.

## 3. Haptics with a setting

Vibration adds weight to hits and landings, and some players hate it. Offer **Vibration: Off / Low / High**, and also respect Roblox's own `UserGameSettings.HapticStrength` if you read it (treat it as an upper bound; behaviour **Unverified** across platforms).

```lua
--!strict
local HapticService = game:GetService("HapticService")
local ClientSettings = require(script.Parent.ClientSettings)

local LEVEL: { [string]: number } = { off = 0, low = 0.4, high = 1 }

local function pulse(strength: number, duration: number)
	local pad = Enum.UserInputType.Gamepad1
	if not HapticService:IsVibrationSupported(pad) then return end
	local scale = LEVEL[ClientSettings.get("vibration") :: string] or 0
	local v = math.clamp(strength * scale, 0, 1)
	if v <= 0 then return end
	if HapticService:IsMotorSupported(pad, Enum.VibrationMotor.Large) then
		HapticService:SetMotor(pad, Enum.VibrationMotor.Large, v)
		task.delay(duration, function()
			HapticService:SetMotor(pad, Enum.VibrationMotor.Large, 0)
		end)
	end
end
```

Gotcha: overlapping pulses where the first one's `task.delay` stops the second early. Track a token per motor and only stop if no newer pulse started. Always stop motors when the player opens the Roblox menu or the character dies; a controller buzzing in a menu feels broken. Timing with sound and visuals is in [[Feedback Timing - Sound Visual and Haptic Sync]].

## 4. Stick feel

- **Deadzone**: a radial deadzone around 0.15-0.2 avoids drift on worn sticks (**Rule of thumb**). The Input Action System exposes `InputBinding.Deadzone` and `ResponseCurve` for analogue bindings (**Roblox docs**).
- **Response curve**: slight exponent on camera stick input gives fine aim near centre and fast turns at full tilt.
- **Camera stick sensitivity** respects `UserGameSettings.GamepadCameraSensitivity` ([[Camera Settings - FOV Shake Sensitivity and Shift-Lock]]).
- **Aim assist** for controller in shooters: see [[Aim Assist and Generous Hitboxes]].

## 5. Console-specific traps

- **No text chat by default on some consoles** and no keyboard: never require typing (codes boxes need an on-screen keyboard path, which Roblox provides when a `TextBox` is focused).
- **ProximityPrompt keys** default to a gamepad key you might also bind; see [[ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab]].
- **Virtual cursor**: Roblox has a virtual cursor mode for gamepads (`StarterGui.VirtualCursorMode`, **Roblox docs**). It helps with mouse-designed menus but is a fallback, not a substitute for selection navigation.
- **Overscan/safe zone** on TVs: keep important UI away from screen edges.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Controller stuck on menu open | Nothing selected | Set `SelectedObject` |
| Keyboard letters shown to pad players | Glyph chosen at startup | Follow `PreferredInput` live |
| PlayStation players see Xbox glyphs | Custom glyph sheet | `GetImageForKeyCode` |
| Vibration continues in menus | Motor never stopped | Stop on menu, death, focus loss |
| Camera drifts | No deadzone | 0.15-0.2 radial deadzone |
| Codes unusable on console | Required typing without focus path | Focusable `TextBox` |

## Checklist

- [ ] Every menu selects on open; B closes; selection contained.
- [ ] Glyphs follow `PreferredInput` and use engine images.
- [ ] Every HUD action reachable by controller.
- [ ] Vibration setting; motors stopped on menu and death.
- [ ] Deadzone and response curve tuned; Roblox camera sensitivity respected.
- [ ] Tested on a TV at sofa distance.

## See also

- [[Gamepad and Console UX]]
- [[Shift-Lock Sprint and Gamepad B for Menus]]
- [[Rebinding Controls with the Input Action System]]
- [[Haptics]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Mobile Button Layout Editor]] · [[Debugging UI Layout and Input]] · Feedback Timing - Sound Visual and Haptic Sync
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Console and VR Release Checklists]] · [[Onboarding Accessibility and Cross-Device Prompts]] · [[Accessibility Cross-Links for QoL Settings]] · [[QoL Audit Checklist]] · [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]] · [[Settings Menu Essentials and Persistence]] · [[Top 25 QoL Wins by Effort]] · [[Colourblind Palettes Text Size and Tooltips]] · [[UI Scale HUD Hide and Compact Mode]] · [[Skippable Tutorials and Replayable Tips]]
<!-- related:end -->
