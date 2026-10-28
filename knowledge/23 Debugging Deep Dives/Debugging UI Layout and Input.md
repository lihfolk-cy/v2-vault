---
tags: [debugging, ui, layout, input, gamepad, zindex, automaticsize]
---
# Debugging UI Layout and Input

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Debugging layout in Edit mode instead of the device emulator in a play test.
> - Avoid: Raising `ZIndex` on a child when its ancestor is the problem.
> - Avoid: Trusting `ClipsDescendants` with rotated children.
> - Studio debug tools: object-at-pointer, outline toggle, absolute size chain, selection logger.
> - DisplayOrder bands written down and assigned to every ScreenGui.
> - Rotated or rounded clipping uses CanvasGroup, sparingly.
>
> Read more (19 KB note): ## 1. See what the engine sees · ## 4. AutomaticSize problems · ## Common mistakes · ## Checklist
<!-- tldr:end -->

UI bugs are reported vaguely ("the button does not work on my phone", "the shop looks broken") and caused precisely: a transparent frame on top eating clicks, a `ZIndex` that only applies among siblings, a `ClipsDescendants` that does not clip rotated children, an `AutomaticSize` that feeds back into itself, two `UIScale` objects multiplying, a gamepad selection that lands on an invisible button. This note gives the tools to see what the engine sees and a cause list for each family of symptom.

Layout fundamentals are in [[Layout - Scale Offset and Constraints]] and [[UI Layout Objects - Lists Grids and Pages]]; input APIs in [[Input - UserInputService and ContextActionService]]; gamepad design in [[Gamepad and Console UX]]; device testing in [[Responsive UI for Phone Tablet Console and PC]] and [[Multi-Client and Device Playtesting Protocols]].

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. See what the engine sees

UI is the one place where looking is cheaper than reasoning. Three tools.

### 1.1 What is under the pointer?

`PlayerGui:GetGuiObjectsAtPosition(x, y)` (Docs, on `BasePlayerGui`) returns the GUI objects at a screen point, topmost first. It answers "what is eating my click?" in one call.

```lua
--!strict
-- Client, Studio only: print what is under the mouse on middle click.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

if RunService:IsStudio() then
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton3 then
			return
		end
		local p = UserInputService:GetMouseLocation()
		local inset = GuiService:GetGuiInset()
		-- GetMouseLocation is in full-screen space; GUI positions usually exclude the top inset.
		local objects = playerGui:GetGuiObjectsAtPosition(p.X - inset.X, p.Y - inset.Y)
		print(("--- %d objects at %d,%d"):format(#objects, p.X, p.Y))
		for i, o in objects do
			print(i, o:GetFullName(), o.ClassName, "Active=" .. tostring(o.Active),
				"Visible=" .. tostring(o.Visible), "Z=" .. o.ZIndex)
		end
	end)
end
```

The inset subtraction is a common source of off-by-36-pixel confusion; whether `GetGuiObjectsAtPosition` expects coordinates with or without the inset is not stated clearly in the reference (unverified). If the list looks shifted, try without the subtraction. The first object in the list with `Active = true` (or a button) is usually the one taking input.

### 1.2 Outline everything

A Studio-only toggle that adds a thin `UIStroke` to every `GuiObject` in a ScreenGui reveals invisible frames, overlaps and zero-size containers instantly:

```lua
--!strict
local function outline(root: Instance, on: boolean)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			local s = d:FindFirstChild("_DebugStroke")
			if on and not s then
				local stroke = Instance.new("UIStroke")
				stroke.Name = "_DebugStroke"
				stroke.Thickness = 1
				stroke.Color = Color3.fromHSV((#d:GetFullName() % 12) / 12, 1, 1)
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = d
			elseif not on and s then
				s:Destroy()
			end
		end
	end
end
```

Caveats: on `TextLabel`s and `TextButton`s, a `UIStroke` with the default `ApplyStrokeMode` outlines the text, which is why the code sets `Border`. A UIStroke also affects layout slightly in some setups ([[Layout - Scale Offset and Constraints]] mentions UIStroke as layout-affecting), so turn it off before measuring sizes.

### 1.3 Print absolute values

When a layout is wrong, the authored `Size` tells you little; `AbsoluteSize`, `AbsolutePosition` and `AbsoluteRotation` tell you what the engine computed. Print them for the element and its ancestors up to the ScreenGui. The first ancestor with an unexpected absolute size is where the problem starts (the "first wrong value" rule from [[The Debugging Method - Reproduce Isolate Bisect]]).

```lua
-- Command bar or client debug: ancestor chain of absolute sizes.
local function chain(g: GuiObject)
	local cur: Instance? = g
	while cur and cur:IsA("GuiObject") do
		print(cur.Name, cur.AbsoluteSize, cur.AbsolutePosition, cur.Size)
		cur = cur.Parent
	end
end
```

In Edit mode, StarterGui content is laid out in the Studio viewport size; on a device it is different. Always check absolute values in a play test with the device emulator, not in Edit mode.

---

## 2. Draw order: ZIndex, DisplayOrder and friends

### 2.1 How order is decided

| Level | Controlled by |
|---|---|
| Between ScreenGuis | `ScreenGui.DisplayOrder` (higher on top) (Docs) |
| Within a ScreenGui, `ZIndexBehavior = Sibling` | children always draw above their parent; among siblings, `ZIndex` decides (Docs) |
| Within a ScreenGui, `ZIndexBehavior = Global` | `ZIndex` compared across the whole ScreenGui, regardless of hierarchy (Docs) |
| Equal ZIndex among siblings | order is effectively creation or child order; do not rely on it (rule of thumb) |
| World-space UI | `BillboardGui.AlwaysOnTop`, `SurfaceGui.AlwaysOnTop`; otherwise 3D depth ([[World-Space UI - BillboardGui and SurfaceGui]]) |

Sibling is the behaviour new ScreenGuis use (Docs), and it is the sane one: a popup's children stay on top of the popup.

### 2.2 Symptoms

| Symptom | Cause |
|---|---|
| Setting `ZIndex = 100` on a button does nothing | Sibling mode: the button's **ancestor** is under another branch; raise the ancestor, or move the button |
| A tooltip appears under the next card in a grid | tooltip is a child of one card; later siblings draw above it. Put tooltips in a separate top-level ScreenGui with a higher DisplayOrder |
| A modal sometimes appears under the HUD | two ScreenGuis with equal DisplayOrder; set explicit values for every ScreenGui |
| Core UI (top bar, chat) covers your button | your UI is inside the inset area; see section 6 |
| Order flips when content is rebuilt | equal ZIndex siblings relying on creation order |

A rule of thumb that prevents most of these: a written list of DisplayOrder bands (HUD 0 to 9, menus 10 to 19, modals 20 to 29, toasts 30, debug 100) and every ScreenGui assigned from it ([[UI Design Systems]], [[Notification and Toast Systems]]).

---

## 3. Clipping

| Symptom | Cause | Fix |
|---|---|---|
| Rotated child is not clipped by its `ClipsDescendants` parent | Docs: `ClipsDescendants` does not clip rotated descendants | use a `CanvasGroup` as the clipping container, or avoid rotation inside clipped areas |
| Rounded corners do not clip children | `UICorner` rounds the frame itself, not children | `CanvasGroup` with a `UICorner` clips children to the rounded shape |
| Content of a ScrollingFrame shows outside it | a descendant is in a different ScreenGui or uses a `CanvasGroup` that renders separately (rule of thumb); or `ClipsDescendants` turned off | check the ancestor chain; ScrollingFrames clip by default |
| `CanvasGroup` content looks blurry or pixelated | CanvasGroups render to a texture; resolution limits and memory apply (Docs mention texture memory considerations) | use CanvasGroups only where needed (fades, rounded clipping), not as general containers ([[Rendering Performance]]) |
| Children vanish when the parent has `Visible = false` | expected: visibility is inherited | check every ancestor's `Visible`, and `Enabled` on the ScreenGui |

`CanvasGroup` has a cost: texture memory per group. On phones, dozens of CanvasGroups in a list can cost real memory ([[Mobile and Low-End Optimization]]).

---

## 4. AutomaticSize problems

`AutomaticSize` (Docs) grows a GuiObject to fit its content. It is powerful and the source of a specific family of bugs.

### 4.1 Circular sizing

**Symptom:** a container sized with `AutomaticSize` collapses to zero, or its children appear at zero size, or the layout jumps between two states.

**Cause:** the children use **Scale** sizes relative to the auto-sized parent on the same axis. The parent's size depends on the children; the children's size depends on the parent. The engine resolves it in some order, and the result is rarely what you wanted (rule of thumb: treat it as undefined).

**Fix:** on the axis that is automatic, children use **Offset** sizes (or their own AutomaticSize, such as text labels sized by their text). Scale on the other axis is fine: a vertical list with `AutomaticSize = Y` can hold children with `Size = UDim2.new(1, 0, 0, 40)`.

### 4.2 TextScaled with AutomaticSize

**Symptom:** text in an auto-sized label is tiny or does not grow.

**Cause:** `TextScaled` fits text to the box; `AutomaticSize` fits the box to the text. Combining them on the same axis is circular (rule of thumb; the engine picks one).

**Fix:** with `AutomaticSize`, use a fixed `TextSize` (scaled globally with `UIScale`) instead of `TextScaled`. Use `TextScaled` only for fixed boxes, with a `UITextSizeConstraint` to cap the range ([[Text Fonts and Rich Text]]).

### 4.3 Lists that do not grow

**Symptom:** a ScrollingFrame does not scroll to the end, or its canvas is too small.

**Cause:** `CanvasSize` fixed while items were added, or `AutomaticCanvasSize` set on the wrong axis, or padding in a `UIListLayout` not included in a manual calculation.

**Fix:** `AutomaticCanvasSize` on the scroll axis (Docs), or set `CanvasSize` from `UIListLayout.AbsoluteContentSize` plus padding, updated on its change signal. For very large lists, virtualise ([[Virtualized Lists and Large Inventories]]).

### 4.4 Layout thrash

Changing a size inside a handler for `AbsoluteSize` changes of the same subtree can loop for several frames, visible as flicker or a layout that "settles" slowly. Under deferred signals it may stop after a re-entrancy limit ([[Reading Luau Errors and Stack Traces]]). Fix: never write sizes in response to your own subtree's size changes; compute from the parent's size instead, and coalesce with `task.defer`.

---

## 5. UIScale versus TextScaled

These solve different problems, and mixing them is a common source of "text is too small on phones".

| Approach | What scales | Good for | Trap |
|---|---|---|---|
| Design at a fixed resolution with Offset sizes, then one `UIScale` per ScreenGui | everything, uniformly, including text, strokes and corner radii | consistent look across devices | two UIScales on one branch multiply ([[Layout - Scale Offset and Constraints]]) |
| Scale sizes plus `TextScaled` | boxes by screen proportion, text to fit each box | simple screens | text sizes differ between neighbouring labels; long translations shrink text unreadably |
| Mixed | whichever wins locally | rarely right | unpredictable on new devices |

**Debugging double scaling:** search the ancestors of a wrong-sized element for `UIScale` objects. A UIScale in a reusable component plus one on the ScreenGui gives `0.8 x 0.8 = 0.64`. Print the product along the ancestor chain:

```lua
local function effectiveScale(g: Instance): number
	local s = 1
	local cur: Instance? = g
	while cur do
		local ui = cur:FindFirstChildOfClass("UIScale")
		if ui then
			s *= ui.Scale
		end
		cur = cur.Parent
	end
	return s
end
```

**Measured note.** The reference project's first phone pass put one `UIScale` on every ScreenGui so a 1920 x 1080 layout fitted the screen. It "worked" on the single mock viewport it was checked on, but a 14 px label drew at about 5 px on a 390-pixel-tall phone and a 40 px button became about 15 px. When "text is too small on phones" is the bug, compute the effective scale (above) and the resulting pixel size before touching fonts: the answer is often a layout that needs a real phone variant, not a bigger number ([[Case Study - Phone UI Overhaul]], [[LihFolk UI Design System]]).

---

## 6. Insets and safe areas

| Symptom | Cause |
|---|---|
| Top 36 to 58 pixels of the screen covered by core UI | content in the top bar area; `ScreenGui.ScreenInsets` set to `None` or legacy `IgnoreGuiInset` on |
| Buttons under a phone's notch or rounded corners | content outside device safe insets |
| Click positions off by the inset | mixing `GetMouseLocation` (full screen) with GUI positions (inset-relative) |

`ScreenGui.ScreenInsets` (Docs) chooses which inset the ScreenGui respects (`None`, `DeviceSafeInsets`, `CoreUISafeInsets`, `TopbarSafeInsets`). Full-screen backgrounds use `None`; interactive content uses `CoreUISafeInsets` or `DeviceSafeInsets`. Details in [[Safe Areas and Insets]].

---

## 7. Input that does not arrive

### 7.1 Sinking: who took the input?

| Symptom | Cause |
|---|---|
| Clicks on a button do nothing in one area | an invisible or transparent `GuiObject` with `Active = true` on top (use the tool in 1.1) |
| A button works with mouse, not with touch | a touch-specific overlay (thumbstick, jump button area) covers it; core touch controls take input in their zones |
| World clicks fire while the shop is open | your world-click handler ignores `gameProcessedEvent` (second argument of `InputBegan`, Docs) |
| World clicks never fire | a full-screen frame with `Active = true` sinks them; set `Active = false` on decorative full-screen frames |
| Keybinds stop when a TextBox has focus | expected: input goes to the TextBox; `gameProcessedEvent` is true |
| A ContextActionService action never fires | another binding with higher priority returned `Sink` ([[Input - UserInputService and ContextActionService]]) |
| A button ignores all input | `Interactable = false` (GuiObject property, Docs as of October 2026), `Visible = false` on an ancestor, ScreenGui `Enabled = false`, or the button is outside the screen |

Always respect `gameProcessedEvent` in world input handlers:

```lua
--!strict
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return -- UI, chat or a TextBox already used this input
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		-- world click / tap
	end
end)
```

### 7.2 Input logging

When the cause is unclear, log every input event with its type, state and `gameProcessedEvent` for a few seconds:

```lua
UserInputService.InputBegan:Connect(function(i, gp)
	print("began", i.UserInputType.Name, i.KeyCode.Name, "processed=" .. tostring(gp))
end)
```

If the event never appears, the platform or a core script took it. If it appears with `processed = true`, your UI or a TextBox took it. If it appears with `false` and nothing happens, the bug is in your handler.

---

## 8. Gamepad selection

Gamepad bugs are invisible to anyone testing with a mouse. Test with a controller (or Studio's controller emulation, [[Testing Modes - Play Run and Multi-Client]]) from the first build of every menu.

| Symptom | Cause | Fix |
|---|---|---|
| Opening a menu selects nothing; the player is stuck | nothing set `GuiService.SelectedObject` (Docs) | select the primary button when a menu opens |
| Selection jumps to the HUD behind the menu | selection is free to move anywhere selectable | `GuiService:AddSelectionParent` / `SelectionGroup` on the menu container to keep selection inside (Docs) |
| Selection lands on an invisible element | a hidden but `Selectable` object | set `Selectable = false` on hidden elements, or hide with `Visible = false` (not transparency) |
| D-pad navigation goes in surprising directions | automatic neighbour detection in irregular layouts | set `NextSelectionUp/Down/Left/Right` explicitly on tricky elements (Docs) |
| Selection lost after rebuilding a list | the selected object was destroyed | after rebuild, reselect the equivalent item by id |
| Selection highlight invisible against the art | default selection image does not fit the style | custom `SelectionImageObject` (Docs) |

A debug label that prints `GuiService.SelectedObject` on change helps enormously:

```lua
--!strict
local GuiService = game:GetService("GuiService")
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
	local o = GuiService.SelectedObject
	print("selected:", if o then o:GetFullName() else "nil")
end)
```

---

## 9. A worked example

**Report:** "On phones, the Claim button in daily rewards does nothing. Works on PC."

1. **Reproduce.** Device emulator, phone preset: tap does nothing 10 of 10. PC: works.
2. **What is under the tap?** Tool 1.1 at the button's position: the first object is `RewardsGui.Root.Background`, `Active = true`, then the button.
3. **Why only phones?** On phones, a responsive rule enlarges the background panel to fill the screen; the panel is a sibling **after** the button's container, so in Sibling mode it draws over it and, being `Active`, takes the tap. On PC the panel is smaller and does not overlap the button.
4. **Fix.** Background `Active = false` (it is decorative) and `ZIndex` of the background lower than the content container. Explicit DisplayOrder for the rewards ScreenGui.
5. **Verify.** Phone, tablet and PC presets, plus a real phone. Controller: opening the menu selects Claim.
6. **Guard.** UI checklist item: decorative frames are never Active ([[QA Checklists Before Release]]).

---

## Common mistakes

- Debugging layout in Edit mode instead of the device emulator in a play test.
- Raising `ZIndex` on a child when its ancestor is the problem.
- Trusting `ClipsDescendants` with rotated children.
- Scale-sized children inside an auto-sized parent on the same axis.
- `TextScaled` combined with `AutomaticSize`.
- Two `UIScale`s on one branch.
- World input handlers that ignore `gameProcessedEvent`.
- Full-screen decorative frames with `Active = true`.
- No `SelectedObject` when a menu opens; no controller testing.

## Checklist

- [ ] Studio debug tools: object-at-pointer, outline toggle, absolute size chain, selection logger.
- [ ] DisplayOrder bands written down and assigned to every ScreenGui.
- [ ] Rotated or rounded clipping uses CanvasGroup, sparingly.
- [ ] Auto-sized containers use Offset (or auto) children on the automatic axis.
- [ ] One UIScale per branch; text sizing strategy chosen per screen.
- [ ] Interactive content inside safe insets.
- [ ] World input respects `gameProcessedEvent`; decorative frames inactive.
- [ ] Every menu sets a selection on open and contains selection for gamepads.

## See also

[[Debugging Start Here]] · [[Layout - Scale Offset and Constraints]] · [[UI Layout Objects - Lists Grids and Pages]] · [[ScreenGui Fundamentals]] · [[Safe Areas and Insets]] · [[Input - UserInputService and ContextActionService]] · [[Gamepad and Console UX]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Virtualized Lists and Large Inventories]] · [[Multi-Client and Device Playtesting Protocols]]

## Connected notes
<!-- auto-links:start -->
[[Cookbook - UI]] · [[Safe Area]] · [[Skill - Roblox UI Builder]] · [[Links - Containers]] · [[Readable Text and UI Scale]] · [[Links - UI elements]]
<!-- auto-links:end -->
