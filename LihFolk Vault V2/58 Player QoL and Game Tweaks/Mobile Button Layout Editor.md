---
tags: [qol, mobile, touch, layout-editor, buttons, drag, persistence, controls, type/guide, area/input, area/ui, level/intermediate, api/ContextActionService, api/InputBinding, api/UserInputService]
---
# Mobile Button Layout Editor

<!-- tldr:start -->
> [!tldr] TL;DR
> - Layout wrong on another phone: Pixel positions saved -> Scale positions in a safe-area container
> - Buttons under the notch: Container covers full screen -> Safe-area container
> - Overlapping buttons after device change: No post-load check -> Overlap check and nudge
> - Own `GuiButton`s bound to actions via `UIButton` or shared handlers.
> - Edit mode disables gameplay input; save, cancel, reset pinned.
> - Positions stored as scale within the safe area; sizes clamped.
>
> Cost: TL;DR ~160 tok · whole note ~2.0k tok. Read more: ## 2. Edit mode flow · ## 3. Store scale, not pixels · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Phones vary in size, players vary in hand size and grip, and a fixed action-button cluster that suits one thumb blocks another's view. Competitive mobile games let players drag buttons, resize them and save the layout. On Roblox this is a modest feature if your touch buttons are your own `GuiButton`s. This note covers the editor flow, storing positions safely as scale, the safe area, and wiring the buttons to actions through `InputBinding.UIButton` or ContextActionService. Touch basics live in [[Input - UserInputService and ContextActionService]] section 7 and [[Responsive UI for Phone Tablet Console and PC]].

Sources: **Roblox docs** for `InputBinding.UIButton` (https://create.roblox.com/docs/reference/engine/classes/InputBinding), `ContextActionService:SetPosition` (https://create.roblox.com/docs/reference/engine/classes/ContextActionService) and `GuiService:GetGuiInset` (https://create.roblox.com/docs/reference/engine/classes/GuiService). Sizes are **Rule of thumb**.

## 1. Own your buttons

ContextActionService's auto-generated touch buttons can be moved with `SetPosition`, but their look and hit areas are limited. For an editor, build your own buttons in one `ScreenGui` ("TouchControls"), each with a stable `Name` matching the action (`Jump` is Roblox's; yours are `Attack`, `Dash`, `Skill1`). Bind them:

- **Input Action System**: set the action's touch `InputBinding.UIButton` to your `GuiButton` (**Roblox docs**), so pressing it drives the same `InputAction` as the keyboard key.
- **ContextActionService / custom**: connect the button's `InputBegan`/`InputEnded` to the same handler the keyboard uses.

The editor then only moves and resizes these frames; the binding does not change.

## 2. Edit mode flow

1. Settings → Controls → "Edit touch layout".
2. Gameplay input context is disabled; a grid overlay and a semi-transparent preview of the HUD appear.
3. Each button shows a drag handle and a size slider when selected.
4. Buttons cannot overlap each other or the joystick zone, and cannot leave the safe area.
5. "Save", "Cancel" and "Reset to default" stay pinned at the top centre.

```lua
--!strict
local UserInputService = game:GetService("UserInputService")

-- Makes a button draggable while editing; returns a cleanup function.
local function makeDraggable(button: GuiObject, container: GuiObject, onMoved: (GuiObject) -> ()): () -> ()
	local dragging: InputObject? = nil
	local startPos = Vector2.zero
	local startAbs = Vector2.zero

	local c1 = button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = input
			startPos = Vector2.new(input.Position.X, input.Position.Y)
			startAbs = button.AbsolutePosition - container.AbsolutePosition
		end
	end)
	local c2 = UserInputService.InputChanged:Connect(function(input)
		if dragging == nil then return end
		if input ~= dragging and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - startPos
		local size = container.AbsoluteSize
		local half = button.AbsoluteSize / 2
		local centre = startAbs + half + delta
		centre = Vector2.new(math.clamp(centre.X, half.X, size.X - half.X), math.clamp(centre.Y, half.Y, size.Y - half.Y))
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.fromScale(centre.X / size.X, centre.Y / size.Y)
	end)
	local c3 = UserInputService.InputEnded:Connect(function(input)
		if input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if dragging then onMoved(button) end
			dragging = nil
		end
	end)
	return function() c1:Disconnect(); c2:Disconnect(); c3:Disconnect() end
end
```

`container` should be a frame that already covers only the safe area (inset from notches and the top bar), so clamping to it keeps buttons reachable ([[Safe Areas and Insets]]). Mouse support lets you test in Studio without the device emulator.

## 3. Store scale, not pixels

Save each button as `{ x, y, size }` where `x, y` are the **scale** position of its centre inside the safe-area container (0 to 1) and `size` is a multiplier (0.75 to 1.5, **Rule of thumb**). Pixel positions break when the same account plays on a different phone or rotates; scale positions survive.

Validate on the server like any setting: known button names only, numbers finite and clamped, at most a few dozen entries. Store per device bucket (`touchLayout`) since it only matters on touch ([[Settings Menu Essentials and Persistence]] section 6).

Aspect-ratio gotcha: a layout saved on a 19.5:9 phone and loaded on a 4:3 tablet keeps relative positions but buttons may now overlap. After loading, run the same overlap check as the editor and nudge or reset overlapping buttons, telling the player once.

## 4. Sensible defaults and limits

- **Minimum touch target** around 44-48 logical pixels even at the smallest size (**Rule of thumb**, in line with platform HIG guidance).
- **Primary action** (attack) largest, nearest the resting right thumb.
- **Leave Roblox's jump button** where Roblox puts it unless you replace it; moving your own buttons over it causes mis-taps.
- **Opacity slider** (0.3 to 1) for players who want to see more of the world.
- **Left-handed mirror** preset: flip `x` to `1 - x` for every button.

## 5. Testing

Test on at least a small phone, a large phone and a tablet, in both landscape orientations; notches swap sides. Studio's device emulator helps with layout but not with thumb reach; ask a few players to try. Watch for buttons that fire when the player is dragging the camera across them: set `Active` and handle `Touch` only when it begins on the button.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Layout wrong on another phone | Pixel positions saved | Scale positions in a safe-area container |
| Buttons under the notch | Container covers full screen | Safe-area container |
| Overlapping buttons after device change | No post-load check | Overlap check and nudge |
| Action fires while editing | Gameplay context active | Disable during edit mode |
| Camera drag triggers a button | Touch started elsewhere | Only respond to touches that began on the button |
| Editor shown to PC players | No device gating | Show only when `TouchEnabled` |

## Checklist

- [ ] Own `GuiButton`s bound to actions via `UIButton` or shared handlers.
- [ ] Edit mode disables gameplay input; save, cancel, reset pinned.
- [ ] Positions stored as scale within the safe area; sizes clamped.
- [ ] Server validates; layout stored per device bucket.
- [ ] Overlap check on load; left-handed mirror; opacity slider.

## See also

- [[Responsive UI for Phone Tablet Console and PC]]
- [[Case Study - Phone UI Overhaul]]
- [[Input Remapping and One-Handed Play]]
- [[Rebinding Controls with the Input Action System]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Safe Areas and Insets]] · [[Controller Support QoL]] · [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Safe Area]] · [[UI Scale HUD Hide and Compact Mode]] · [[AI Pitfalls - UI and Input]] · [[QoL Audit Checklist]] · [[Accessibility Cross-Links for QoL Settings]] · [[Colourblind Palettes Text Size and Tooltips]] · [[Graphics and Performance Toggles for Low-End Devices]] · [[Top 25 QoL Wins by Effort]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Aim Assist and Generous Hitboxes]]
<!-- related:end -->
