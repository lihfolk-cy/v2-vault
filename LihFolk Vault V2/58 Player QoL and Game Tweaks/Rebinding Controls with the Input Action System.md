---
tags: [qol, rebinding, keybinds, input-action-system, inputaction, inputbinding, inputcontext, controls, settings, type/guide, area/input, level/advanced, api/InputAction, api/InputBinding, api/InputContext]
---
# Rebinding Controls with the Input Action System

<!-- tldr:start -->
> [!tldr] TL;DR
> - Capturing a key also performs the action: Context still enabled -> Disable Gameplay context during capture
> - Player bound Esc and cannot open menus: No reserved list -> Reserved keys rejected
> - Two actions fire on one key: No conflict check -> Offer a swap
> - Contexts per mode; actions and bindings named stably.
> - Capture flow disables gameplay, cancels with Esc/B, times out.
> - Reserved keys rejected; conflicts offer swap.
>
> Cost: TL;DR ~150 tok · whole note ~1.9k tok. Read more: ## 2. Capture flow · ## 3. Conflicts: swap, do not block · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Players expect to rebind keys on PC and buttons on controller. The Input Action System (`InputContext`, `InputAction`, `InputBinding`) makes this far easier than ContextActionService, because the binding is data you can change at runtime. [[Input Remapping and One-Handed Play]] already has a full remap controller and the accessibility reasoning; [[Input - UserInputService and ContextActionService]] explains the system. This note is the QoL wrapper: the rebind screen flow, conflict handling, defaults and reset, and persistence through the shared settings service.

Sources: **Roblox docs** for `InputContext` (https://create.roblox.com/docs/reference/engine/classes/InputContext), `InputAction` (https://create.roblox.com/docs/reference/engine/classes/InputAction) and `InputBinding` (https://create.roblox.com/docs/reference/engine/classes/InputBinding). Flow is **Rule of thumb**.

## 1. Structure that makes rebinding easy

- One `InputContext` per mode (Gameplay, Vehicle, Menu), each with `Priority` and `Sink` set.
- One `InputAction` per mechanic, named stably (`Sprint`, `Dash`, `UseQuickSlot1`). The **name is the save key**, so never rename after launch.
- One `InputBinding` per device family per action: give each a stable name like `KBM`, `Gamepad`, `Touch`. Rebinding edits the binding's `KeyCode`; adding a secondary key adds a second binding named `KBM2`.

Built in Studio as instances, defaults are visible and editable by designers; at runtime you only change `KeyCode`.

## 2. Capture flow

1. Player selects an action row and presses "Rebind" (or A on gamepad).
2. Disable the Gameplay context (`Enabled = false`) so the captured key does not also fire the action.
3. Show "Press a key (Esc to cancel)". Capture the next `InputBegan` of the matching device family.
4. Validate: reserved keys, device family, conflicts.
5. Apply, re-enable the context, show the new glyph.

```lua
--!strict
local UserInputService = game:GetService("UserInputService")

local RESERVED: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.Escape] = true, -- Roblox menu
	[Enum.KeyCode.ButtonStart] = true, -- console menu
	[Enum.KeyCode.F9] = true, -- developer console
}

local function familyOf(input: InputObject): string?
	if input.UserInputType == Enum.UserInputType.Keyboard then return "KBM" end
	if input.UserInputType.Name:sub(1, 7) == "Gamepad" then return "Gamepad" end
	return nil
end

-- Resolves with the captured KeyCode, or nil if cancelled or timed out.
local function captureKey(family: string, timeout: number): Enum.KeyCode?
	local result: Enum.KeyCode? = nil
	local done = false
	local conn
	conn = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			done = true
			return
		end
		if familyOf(input) == family and not RESERVED[input.KeyCode] then
			result = input.KeyCode
			done = true
		end
	end)
	local start = os.clock()
	while not done and os.clock() - start < timeout do task.wait() end
	conn:Disconnect()
	return result
end
```

Mouse buttons arrive as `UserInputType.MouseButton1` etc. with `KeyCode.Unknown`; decide whether you support binding mouse buttons, and if so store the input type instead of a key code. Gamepad B cancels here, so B itself can only be bound outside this screen; that is acceptable for most games.

## 3. Conflicts: swap, do not block

When the new key is already used by another action in the **same context**, offer a swap: "Q is used by Dash. Swap?" Silent duplicates make two actions fire; refusing outright frustrates players. Keys used in different contexts (Vehicle vs Gameplay) do not conflict, because only one is enabled at a time.

```lua
--!strict
local function findConflict(context: InputContext, family: string, key: Enum.KeyCode, except: InputAction): InputBinding?
	for _, action in context:GetChildren() do
		if action:IsA("InputAction") and action ~= except then
			for _, b in action:GetChildren() do
				if b:IsA("InputBinding") and b.Name:sub(1, #family) == family and b.KeyCode == key then
					return b
				end
			end
		end
	end
	return nil
end
```

## 4. Saving

Save only changed bindings as `{ [actionName.."/"..bindingName] = keyCode.Name }`. On the server, validate each entry: the action name exists in your allow list, the key name is a real `Enum.KeyCode` member (look up with a `pcall` around `Enum.KeyCode[name]` or a prebuilt name set), and it is not reserved. Store under `settings.input` in the profile. The full server example is in [[Input Remapping and One-Handed Play]] section 4.

Load order gotcha: apply saved bindings **before** enabling the Gameplay context on spawn, or the first second of play uses defaults.

## 5. Showing the right glyph everywhere

After a rebind, every prompt must show the new key: tutorial hints, tooltips, the quick-slot bar. Read from the action (`InputAction.PreferredBinding` or your own binding lookup) instead of hard-coding "Press Q". `UserInputService:GetStringForKeyCode` and `GetImageForKeyCode` produce labels that respect keyboard layout and gamepad type (**Roblox docs**). Hard-coded strings are the most common rebind bug players report.

## 6. Defaults and presets

- **Reset to defaults** per device family.
- **Presets**: "Default", "Left-handed", "One-handed" (see section 42).
- Show the default key in grey next to a changed one so players remember.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Capturing a key also performs the action | Context still enabled | Disable Gameplay context during capture |
| Player bound Esc and cannot open menus | No reserved list | Reserved keys rejected |
| Two actions fire on one key | No conflict check | Offer a swap |
| Prompts still say the old key | Hard-coded text | Glyph from the binding |
| Rebinds lost after an update | Actions renamed | Names are save keys; never rename |
| Defaults for the first second | Bindings loaded after context enabled | Apply first, then enable |

## Checklist

- [ ] Contexts per mode; actions and bindings named stably.
- [ ] Capture flow disables gameplay, cancels with Esc/B, times out.
- [ ] Reserved keys rejected; conflicts offer swap.
- [ ] Only changes saved; server validates names and keys.
- [ ] Glyphs read from bindings everywhere.
- [ ] Per-family reset and presets.

## See also

- [[Input Remapping and One-Handed Play]]
- [[Input - UserInputService and ContextActionService]]
- [[Server Authority and Input Migration 2026]]
- [[Controller Support QoL]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Mobile Button Layout Editor]] · [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]] · [[Settings Menu Essentials and Persistence]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Accessibility Cross-Links for QoL Settings]] · [[QoL Audit Checklist]] · [[Colourblind Palettes Text Size and Tooltips]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Top 25 QoL Wins by Effort]] · [[Skippable Tutorials and Replayable Tips]] · [[Graphics and Performance Toggles for Low-End Devices]] · [[UI Scale HUD Hide and Compact Mode]]
<!-- related:end -->
