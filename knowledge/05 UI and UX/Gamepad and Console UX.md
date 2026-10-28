---
tags: [ui, gamepad, console, selection, guiservice, ten-foot]
---
# Gamepad and Console UX

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No initial selection when a menu opens.
> - Avoid: Selection escaping from a panel into the HUD behind it.
> - Avoid: Selection lost or stuck in UI after a panel closes.
> - Every panel: initial selection, trapped navigation, B closes, focus restored.
> - Shoulder buttons switch tabs; key HUD actions mapped.
> - Selection visual equals hover visual plus a strong ring.
>
> Cost: TL;DR ~130 tok · whole note ~3.6k tok. Read more: ## 3. A focus manager · ## 8. Diagnosing selection problems · ## Common mistakes · ## Checklist
<!-- tldr:end -->

On a console, or on a PC or tablet with a controller, there is no cursor. The player moves a **selection** between UI objects with the d-pad or thumbstick and presses A to activate. Roblox's selection engine does a lot automatically, but games that rely on the defaults alone end up with menus where the selection starts nowhere, jumps to the wrong button, escapes into the HUD behind the panel, or vanishes after a panel closes. This note covers the selection API, a focus manager pattern, ten-foot (TV) design rules, and the console polish the reference project added.

Sources: **Docs** (GuiService, GuiObject, GuiBase2d, UIPageLayout, the "Gamepad input" and "Cross-platform" guides; October 2026), the **reference project** (one production game), and **rule of thumb**. General input is in [[Input - UserInputService and ContextActionService]].

---

## 1. The selection engine

| Member | Purpose (Docs) |
|---|---|
| `GuiService.SelectedObject` | The object currently focused by the navigator; set it to move focus, `nil` to leave UI navigation |
| `GuiService:Select(instance)` | Selects a selectable descendant of the given instance (the `PlayerGui` or a descendant), honouring `SelectionOrder` |
| `GuiObject.Selectable` | Whether the object can be selected (buttons are selectable by default) |
| `GuiObject.SelectionOrder` | Lower values are selected first when selection starts or `Select` is called on an ancestor; does not affect directional movement; default 0 |
| `GuiObject.NextSelectionUp/Down/Left/Right` | Explicit neighbours, overriding the automatic spatial search |
| `GuiBase2d.SelectionGroup` | Treat a container as a group for navigation |
| `GuiBase2d.SelectionBehaviorUp/Down/Left/Right` | Per-direction behaviour at a group's edge (for example stop instead of escaping) |
| `GuiBase2d.SelectionChanged` | Fires when selection moves into, out of or within the object |
| `GuiObject.SelectionGained`, `SelectionLost` | Per-object focus events |
| `GuiObject.SelectionImageObject` | Replace the default selection outline with your own object |
| `GuiService.GuiNavigationEnabled` | Enable or disable default controller navigation |
| `GuiService.AutoSelectGuiEnabled` | Whether the Select button (or Backslash) automatically picks a GUI object |
| `GuiService:AddSelectionParent`, `AddSelectionTuple`, `RemoveSelectionGroup` | Older way to restrict navigation to a set |
| `UIPageLayout.GamepadInputEnabled` | Lets a page layout override `NextSelection*` to page left and right |

How automatic navigation works (rule of thumb from behaviour): when the player pushes a direction, the engine searches for the nearest visible, selectable object in that direction among on-screen UI. "Nearest" is spatial, so a menu whose buttons are not aligned in a clean grid produces surprising jumps, and an open panel's buttons compete with the HUD's buttons behind it.

---

## 2. The five rules of controller menus

1. **Select something when a menu opens.** If `SelectedObject` is nil, the player has to press Select to find the UI at all. The reference project selects the first card when a gamepad player opens the backpack.
2. **Trap selection inside the open menu.** Make the panel a selection group and stop at its edges, or the stick moves selection into the HUD behind the panel.
3. **Restore selection when the menu closes.** Return focus to what opened the menu, or clear it so the stick goes back to moving the character.
4. **B closes, always.** Bind `ButtonB` to close the top panel while a panel is open.
5. **Selection must be visible.** The default outline is thin and often invisible on busy art. Use `SelectionImageObject` or style selection like hover.

---

## 3. A focus manager

```lua
--!strict
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local FocusManager = {}

type Entry = { panel: GuiObject, returnTo: GuiObject?, onClose: () -> () }
local stack: { Entry } = {}

local function usingGamepad(): boolean
	return UserInputService.PreferredInput == Enum.PreferredInput.Gamepad
end

local function trap(panel: GuiObject, on: boolean)
	panel.SelectionGroup = on
	local stop = if on then Enum.SelectionBehavior.Stop else Enum.SelectionBehavior.Escape
	panel.SelectionBehaviorUp = stop
	panel.SelectionBehaviorDown = stop
	panel.SelectionBehaviorLeft = stop
	panel.SelectionBehaviorRight = stop
end

local function onBack(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local top = stack[#stack]
	if top then
		top.onClose()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function FocusManager.push(panel: GuiObject, onClose: () -> ())
	local entry: Entry = { panel = panel, returnTo = GuiService.SelectedObject, onClose = onClose }
	table.insert(stack, entry)
	trap(panel, true)
	if #stack == 1 then
		ContextActionService:BindActionAtPriority("UIBack", onBack, false,
			Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
	end
	if usingGamepad() then
		GuiService:Select(panel) -- lowest SelectionOrder inside the panel wins
	end
end

function FocusManager.pop(panel: GuiObject)
	for i = #stack, 1, -1 do
		local entry = stack[i]
		if entry.panel == panel then
			table.remove(stack, i)
			trap(panel, false)
			local back = entry.returnTo
			if usingGamepad() and back and back:IsDescendantOf(game) and back.Visible then
				GuiService.SelectedObject = back
			else
				GuiService.SelectedObject = nil
			end
			break
		end
	end
	if #stack == 0 then
		ContextActionService:UnbindAction("UIBack")
	end
end

-- If the player switches to a gamepad while a menu is open, give them a selection.
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
	local top = stack[#stack]
	if top and usingGamepad() and GuiService.SelectedObject == nil then
		GuiService:Select(top.panel)
	end
end)

return FocusManager
```

Give the intended first button `SelectionOrder = -1` (lower than everything else) so `Select(panel)` picks it.

---

## 4. Grids, tabs and lists

- **Grids**: automatic spatial navigation works well for `UIGridLayout` grids. It breaks when cards have different sizes or a "featured" card spans rows; set `NextSelection*` for the cards around it.
- **Tabs**: map the shoulder buttons. LB/RB switch tabs; the reference project's backpack does exactly that, and its HUD maps d-pad left to Upgrades and d-pad right to Backpack as shortcuts. Do not make players navigate up to a tab strip and back down.
- **Scrolling lists**: when selection moves to an item outside the visible area, scroll it into view with a margin (see the helper in [[UI Layout Objects - Lists Grids and Pages]]).
- **Sliders and toggles**: left/right should change the value when a slider is selected, not move selection away. Bind directional input while the slider is selected (`SelectionGained` / `SelectionLost`) and sink it.
- **Text boxes**: selecting a `TextBox` and pressing A opens the on-screen keyboard on console. Avoid text entry on console where possible (codes boxes are the exception).
- **Page layouts**: `UIPageLayout.GamepadInputEnabled` (default true) overrides `NextSelection*` for paging; turn it off if pages contain their own navigable grids and paging should be on the shoulders instead.

---

## 5. Making selection visible

The selection indicator must be obvious from three metres on a TV:

- A thick (3 to 4 px at 1080p) bright outline that contrasts with both the card and the background. The reference project uses a gold ring on every button and card for console.
- Combine with the hover treatment: in that project's motion system, gamepad selection triggers exactly the hover animation (scale 1.06 plus a 3 px lift and a white wash), so mouse and controller players get the same feedback.
- Custom indicator: set `SelectionImageObject` to an `ImageLabel` (not parented to anything visible) with your ring art; the engine draws it around the selected object.

```lua
--!strict
local TweenService = game:GetService("TweenService")

-- Use hover visuals for gamepad selection too.
local function bindSelectionLikeHover(button: GuiButton, scale: UIScale)
	local up = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	button.SelectionGained:Connect(function()
		TweenService:Create(scale, up, { Scale = 1.06 }):Play()
	end)
	button.SelectionLost:Connect(function()
		TweenService:Create(scale, up, { Scale = 1 }):Play()
	end)
end
```

---

## 6. Ten-foot UI (TVs)

When `GuiService.ViewportDisplaySize` is `Large` (Docs: "Most TVs or larger"), the player is typically on a couch. `GuiService:IsTenFootInterface()` is deprecated in favour of this property (Docs).

Rules of thumb:

| Topic | Guidance |
|---|---|
| Text | Body text about 1.25 to 1.5 times its desktop size; nothing under about 20 px at 1080p |
| Density | Fewer items per screen; bigger cards |
| Edges | Keep important UI out of the outer 5% (overscan on some TVs) |
| Pointer-only features | Hover tooltips need a selection-driven equivalent |
| Glyphs | Show controller button images, never "Click" or keyboard keys |
| Confirmation | A/B prompts on every destructive action |

Use `UserInputService:GetImageForKeyCode` for button images so Xbox and PlayStation players see the right glyphs (Docs show `ButtonA` mapping to different images per platform), or `InputActionLabel` / `PreferredBinding` with the Input Action System.

---

## 7. Controller-friendly HUD

- Every HUD action needs a button mapping or a path through selection. A rail of ten menu squares cannot each have a button; map the most-used two or three (shoulders, d-pad), and make the rest reachable with Select.
- Show button hints on the HUD squares only while `PreferredInput` is `Gamepad`.
- Leaving UI: pressing B with nothing open, or moving the stick when no menu is open, should return control to the character. Set `SelectedObject = nil` when the last panel closes.

---

## 8. Diagnosing selection problems

Selection bugs are invisible in mouse testing, so it helps to know what each symptom usually means:

| Symptom | Usual cause | Fix |
|---|---|---|
| Pressing a direction does nothing when a menu opens | `SelectedObject` is nil; nothing auto-selects unless the player presses Select | Call `GuiService:Select(panel)` on open for gamepad players |
| Selection jumps to a HUD button behind the panel | The panel is not a selection group, so the spatial search sees the whole screen | `SelectionGroup = true` and `SelectionBehavior* = Stop` on the panel |
| Selection skips a button | The button is not `Selectable`, is under a non-visible ancestor, or is a `Frame` (not selectable by default) | Make the real target a `GuiButton` or set `Selectable = true` |
| Selection lands on an invisible tap pad | Invisible helper buttons are selectable too | `Selectable = false` on tap pads and decorative buttons |
| Selection goes to the wrong neighbour in a row of uneven cards | Spatial search picks the nearest centre | Set `NextSelectionLeft/Right` explicitly |
| Selection gets stuck in UI after closing | `SelectedObject` still points at a hidden object or nothing resets it | Clear or restore selection in the close path |
| Pressing A on a selected card also makes the character jump | The action was not sunk while UI navigation is active | Bind menu actions with higher priority and return `Sink`, or switch input contexts |
| The ring is drawn but clipped | The selection image draws inside a `ClipsDescendants` container | Leave a margin inside clipped containers or use an inner highlight |

A debug overlay that prints `GuiService.SelectedObject:GetFullName()` whenever `GuiService.SelectedObject` changes (listen with `GetPropertyChangedSignal("SelectedObject")`) shortens every one of these investigations to seconds.

### Hidden helpers are the usual culprit

Production UI is full of objects that are buttons for technical reasons: invisible tap pads that enlarge touch targets, hit areas behind decorative art, full-screen "click outside to close" catchers. Every one of them is selectable by default, and the spatial search happily lands on an invisible object, which looks to the player like the selection disappeared. The reference project's invisible 48 px tap pads (added for phones) are exactly this kind of object; give such helpers `Selectable = false` when you create them, and route the gamepad to the visible button.

---

## 9. Testing

- Studio's **Controller Emulator** shows the emulated device and lights up inputs (Docs); use it for every menu.
- Test the "switch device mid-menu" case: open a menu with the mouse, pick up the gamepad, press a direction.
- Test with the HUD visible behind a panel to catch selection escaping.
- Check every screen for an initial selection, a B-to-close, and a visible indicator.
- Haptics (`HapticEffect`, also `GuiButton.HoverHapticEffect` / `PressHapticEffect`) are subtle feedback on supported controllers; test on hardware.

---

## Common mistakes

- No initial selection when a menu opens.
- Selection escaping from a panel into the HUD behind it.
- Selection lost or stuck in UI after a panel closes.
- A selection indicator invisible on the art.
- Tabs that can only be reached by navigating up.
- Sliders that lose selection on left/right.
- Keyboard glyphs shown to gamepad players.

## Checklist

- [ ] Every panel: initial selection, trapped navigation, B closes, focus restored.
- [ ] Shoulder buttons switch tabs; key HUD actions mapped.
- [ ] Selection visual equals hover visual plus a strong ring.
- [ ] TV: larger text, safe margins, controller glyphs.
- [ ] Tested with the Controller Emulator and a real controller.

See also: [[Input - UserInputService and ContextActionService]], [[Responsive UI for Phone Tablet Console and PC]], [[HUD Design]], [[UI Design Systems]], [[Accessibility]], [[Menu Archetypes - Shop Settings Codes Rewards]].

## Connected notes
<!-- auto-links:start -->
[[Debugging UI Layout and Input]] · [[Cookbook - UI]] · [[Links - Cross-platform UI]] · [[ScreenGui Fundamentals]] · [[Safe Area]] · [[Case Study - Phone UI Overhaul]]
<!-- auto-links:end -->
