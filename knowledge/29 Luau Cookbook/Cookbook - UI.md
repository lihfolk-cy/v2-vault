---
tags: [luau, cookbook, ui, gui, tween, recipes]
---
# Cookbook - UI

Recipes for the client-side UI jobs that come up in every game: finding your GUI, wiring buttons for every input type, opening and closing panels, binding labels to data, building lists, and keeping layouts safe on phones and consoles. Code is `--!strict` Luau in `LocalScript`s, reviewed, not run. The deep notes are [[ScreenGui Fundamentals]], [[Layout - Scale Offset and Constraints]], [[Responsive UI for Phone Tablet Console and PC]], [[UI Motion Language and Timing]] and [[Safe Areas and Insets]].

---

## 1. Get your ScreenGui reliably

**Problem.** GUIs in `StarterGui` are copied into `PlayerGui` after the script starts, and by default copied again on every respawn, so references go stale.

```lua
--!strict
-- StarterPlayerScripts/MainUI.client.lua
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local main = playerGui:WaitForChild("Main") :: ScreenGui
print("UI ready", main.Name)
```

In Studio, set `ResetOnSpawn = false` on `Main`.

**Why it works.** A `LocalScript` in `StarterPlayerScripts` runs once per session, not per respawn. With `ResetOnSpawn` off, the GUI is created once and the reference stays valid.

**Pitfall.** Leaving `ResetOnSpawn` on (the default) destroys and recreates the GUI on death. Scripts inside the GUI restart and lose their state, and scripts outside it hold dead references. For most HUD and menu UI, turn it off.

---

## 2. Handle clicks for mouse, touch and gamepad at once

**Problem.** `MouseButton1Click` works on PC but is unreliable or missing for gamepad selection.

```lua
--!strict
local function onPress(button: GuiButton, callback: () -> ())
	local cooling = false
	button.Activated:Connect(function()
		if cooling then
			return
		end
		cooling = true
		callback()
		task.delay(0.25, function()
			cooling = false
		end)
	end)
end

-- onPress(main.Shop.BuyButton, function() print("buy") end)
```

**Why it works.** `GuiButton.Activated` fires for mouse click, touch tap and gamepad confirm on the selected button (Roblox docs (as of October 2026)). The short debounce stops double taps from sending two requests.

**Pitfall.** The client debounce is for feel only. The server must still rate limit the remote the button fires ([[Cookbook - Remotes and Networking]]). Give buttons a `Selectable = true` and sensible `NextSelection*` links for gamepad ([[Gamepad and Console UX]]).

---

## 3. Open and close a panel with a tween that cannot glitch

**Problem.** Pressing "open" twice quickly, or "close" mid-open, leaves the panel half visible.

```lua
--!strict
local TweenService = game:GetService("TweenService")

local OPEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function makePanel(frame: GuiObject)
	local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = frame
	local current: Tween? = nil

	local function play(goal: number, info: TweenInfo, onDone: (() -> ())?)
		if current then
			current:Cancel()
		end
		local tween = TweenService:Create(scale, info, { Scale = goal })
		current = tween
		tween.Completed:Once(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed and onDone then
				onDone()
			end
		end)
		tween:Play()
	end

	return {
		open = function()
			frame.Visible = true
			play(1, OPEN_INFO)
		end,
		close = function()
			play(0, CLOSE_INFO, function()
				frame.Visible = false
			end)
		end,
	}
end
```

**Why it works.** Tweening a `UIScale` scales the whole panel and its children together without touching their layout. Cancelling the previous tween stops two tweens fighting. Hiding only when the close tween actually completes means a quick reopen does not get hidden by a stale callback.

**Pitfall.** `Completed` also fires when a tween is cancelled, with state `Cancelled`. Without the state check, the cancelled close tween would hide a panel you just reopened. Keep open times near 0.15 to 0.25 seconds (rule of thumb) so the UI never feels slow.

---

## 4. Bind a label to a value the server owns

**Problem.** The coin label must update whenever coins change, from any source.

```lua
--!strict
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function bindAttribute(instance: Instance, name: string, label: TextLabel, format: (any) -> string)
	local function render()
		label.Text = format(instance:GetAttribute(name))
	end
	render()
	return instance:GetAttributeChangedSignal(name):Connect(render)
end

local label = (player:WaitForChild("PlayerGui"):WaitForChild("Main") :: ScreenGui):WaitForChild("Coins") :: TextLabel
bindAttribute(player, "Coins", label, function(v)
	return if typeof(v) == "number" then tostring(math.floor(v)) else "0"
end)
```

On the server: `player:SetAttribute("Coins", coins)` whenever coins change.

**Why it works.** The server writes one attribute; it replicates to the client, and the label follows. No remote needed, and late UI scripts still get the current value from the initial `render()`.

**Pitfall.** Attributes on the `Player` replicate to every client, not only the owner. Fine for coins shown on a leaderboard, not fine for private data. For private values, use a `RemoteEvent` to the owner. For big number formatting see [[Cookbook - Tables Strings and Time]].

---

## 5. Build a list from data with a template

**Problem.** An inventory screen needs one row per item, rebuilt when the inventory changes.

```lua
--!strict
type Item = { id: string, name: string, count: number }

local function renderList(container: ScrollingFrame, template: Frame, items: { Item })
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") and child ~= template then
			child:Destroy()
		end
	end
	for index, item in items do
		local row = template:Clone()
		row.Name = item.id
		row.LayoutOrder = index
		row.Visible = true
		local nameLabel = row:FindFirstChild("Name")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = string.format("%s x%d", item.name, item.count)
		end
		row.Parent = container
	end
end
```

Set up: a `UIListLayout` (with `SortOrder = LayoutOrder`) inside the `ScrollingFrame`, `AutomaticCanvasSize = Y`, and a hidden `template` row.

**Why it works.** `LayoutOrder` controls order explicitly instead of relying on names. `AutomaticCanvasSize` grows the scroll area as rows are added, so you never compute `CanvasSize` by hand.

**Pitfall.** Destroy-and-rebuild is fine for tens of rows; for hundreds it causes hitches and loses scroll position. Then reuse rows or virtualise ([[Virtualized Lists and Large Inventories]]). Keep the template outside the container if your layout would otherwise count it.

---

## 6. Keep text readable at every screen size

**Problem.** `TextScaled` makes labels tiny on phones or giant on monitors.

```lua
--!strict
local function setupText(label: TextLabel, minSize: number, maxSize: number)
	label.TextScaled = true
	label.TextWrapped = true
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
end

-- setupText(label, 14, 36)
```

**Why it works.** `TextScaled` fits the text to the box; the constraint clamps the result so it never goes below a readable size or above a sensible one.

**Pitfall.** Labels with different string lengths scale to different sizes, so a row of buttons ends up with mismatched fonts. For uniform text, use a fixed `TextSize` with a `UIScale` for the whole screen (recipe 8) instead of per-label scaling. Minimum readable sizes are discussed in [[Accessibility]] and [[Text Fonts and Rich Text]].

---

## 7. Keep shapes square on every aspect ratio

**Problem.** An icon sized `{0.1, 0}, {0.1, 0}` is square on one screen and stretched on another.

```lua
--!strict
local function keepAspect(gui: GuiObject, ratio: number)
	local constraint = gui:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	constraint.AspectRatio = ratio -- width / height
	constraint.DominantAxis = Enum.DominantAxis.Width
	constraint.Parent = gui
end

-- keepAspect(icon, 1)
```

**Why it works.** Scale sizes are fractions of the parent, which has a different shape on each device. The constraint recomputes one axis from the other.

**Pitfall.** Inside a `UIGridLayout`, the layout controls cell size; put the aspect constraint on the layout's cells via `UIGridLayout.CellSize` or a `UIAspectRatioConstraint` parented to the layout itself. Details in [[UI Layout Objects - Lists Grids and Pages]].

---

## 8. One UIScale for the whole screen

**Problem.** UI designed at 1920 by 1080 in offset pixels is unusable on a phone.

```lua
--!strict
local DESIGN_HEIGHT = 1080
local MIN_SCALE, MAX_SCALE = 0.5, 1.25

local function attachScaler(gui: ScreenGui)
	local root = gui:WaitForChild("Root") :: GuiObject -- a full-screen Frame holding everything
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local camera = workspace.CurrentCamera
	local function update()
		local height = camera.ViewportSize.Y
		scale.Scale = math.clamp(height / DESIGN_HEIGHT, MIN_SCALE, MAX_SCALE)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end
```

**Why it works.** Designing in offset pixels and scaling everything uniformly keeps proportions, spacing and text sizes consistent. Scaling by height suits landscape games where height is the tight axis.

**Pitfall.** `ViewportSize` can be stale or a placeholder in the first frames after join and changes on rotation or window resize (rule of thumb); the changed signal fixes it a moment later, so always connect it rather than reading once. If `workspace.CurrentCamera` is replaced, re-hook the signal. The full method is in [[Responsive UI for Phone Tablet Console and PC]] and [[Case Study - Phone UI Overhaul]].

---

## 9. Keep buttons out of the notch and the core UI

**Problem.** Buttons in the top corners sit under the Roblox menu buttons or a phone's notch.

```lua
--!strict
local function useSafeArea(gui: ScreenGui, interactive: boolean)
	gui.ScreenInsets = if interactive then Enum.ScreenInsets.CoreUISafeInsets else Enum.ScreenInsets.None
end

-- useSafeArea(hudGui, true)        -- buttons, counters
-- useSafeArea(backgroundGui, false) -- full-screen fades and vignettes
```

**Why it works.** `ScreenInsets` tells the ScreenGui which area to lay out in: `CoreUISafeInsets` avoids Roblox's own buttons and the device's unsafe area, `None` covers the whole screen (Roblox docs (as of October 2026)).

**Pitfall.** Full-screen effects must use `None` or they leave visible strips at the edges. Splitting backgrounds and interactive UI into separate ScreenGuis is the clean fix. See [[Safe Areas and Insets]].

---

## 10. Only one menu open at a time

**Problem.** Shop, settings and inventory all open on top of each other.

```lua
--!strict
type Panel = { open: () -> (), close: () -> () }

local panels: { [string]: Panel } = {}
local openName: string? = nil

local function register(name: string, panel: Panel)
	panels[name] = panel
end

local function toggle(name: string)
	if openName == name then
		panels[name].close()
		openName = nil
		return
	end
	if openName then
		panels[openName].close()
	end
	panels[name].open()
	openName = name
end
```

**Why it works.** One variable holds the open panel, so there is exactly one place that can be wrong. Combine with recipe 3 for the open and close animations.

**Pitfall.** Closing a panel through its own X button must go through `toggle` too, or `openName` goes stale and the next toggle closes nothing. Archetype layouts for these menus are in [[Menu Archetypes - Shop Settings Codes Rewards]].

---

## 11. Press feedback that works on touch

**Problem.** Hover effects with `MouseEnter` never fire on phones, so buttons feel dead.

```lua
--!strict
local TweenService = game:GetService("TweenService")
local INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function addPressFeedback(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = button
	local function to(value: number)
		TweenService:Create(scale, INFO, { Scale = value }):Play()
	end
	button.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			to(0.92)
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			to(1)
		end
	end)
	button.SelectionGained:Connect(function() to(1.05) end) -- gamepad focus
	button.SelectionLost:Connect(function() to(1) end)
end
```

**Why it works.** Press and release events exist on every pointer device; selection events cover gamepad. A quick squash on press is the most universal feedback ([[Game Feel and Juice]]).

**Pitfall.** If the button already has a `UIScale` (for example from recipe 3 on a parent), scales multiply, which is usually fine. Do not stack two `UIScale`s on the same object (behaviour is not something to rely on); reuse an existing one with `FindFirstChildOfClass("UIScale")` as recipe 3 does.

---

## 12. Hide default core UI you replace

**Problem.** Your own inventory bar overlaps the default backpack.

```lua
--!strict
local StarterGui = game:GetService("StarterGui")

local ok, err = pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)
if not ok then
	warn("could not hide backpack:", err)
end
```

**Why it works.** `SetCoreGuiEnabled` hides one built-in element for this client. Other types include `PlayerList`, `Health`, `Chat` and `EmotesMenu`.

**Pitfall.** Hiding the backpack does not disable tool equipping by number keys in every setup; test it. Do not hide `Chat` or the player list without a reason: players use them for reporting and social features ([[Social Design and Multiplayer Play]]).

---

## Common mistakes

- `ResetOnSpawn` left on for menus.
- `MouseButton1Click` instead of `Activated`.
- Tweens that are never cancelled, fighting each other.
- Full-screen effects inside safe-area-inset GUIs.
- Rebuilding large lists on every change.

## Checklist

- [ ] One `LocalScript` boots the UI from `StarterPlayerScripts`.
- [ ] All buttons use `Activated` and work with gamepad selection.
- [ ] Panels open and close through one manager.
- [ ] Labels bind to server-owned values, not local guesses.
- [ ] Tested on a phone-sized emulator, a 4:3 tablet and a gamepad ([[Multi-Client and Device Playtesting Protocols]]).

## See also

[[Luau Cookbook Start Here]], [[HUD Design]], [[UI Design Systems]], [[Notification and Toast Systems]], [[Debugging UI Layout and Input]], [[Declarative UI - React-Lua and Fusion]], [[Input - UserInputService and ContextActionService]]

## Nuances and edge cases

1. **Scale is not responsive by itself.** A frame sized with Scale stretches with the screen, which keeps it on screen but distorts it: a square button on a 16:9 monitor becomes a wide bar on an ultra-wide and a tall bar on a phone held in portrait. Combine Scale for position, an aspect ratio constraint for shape, and a single UIScale (or size clamps) for overall size. Pure Offset, the opposite extreme, is crisp but tiny on high-resolution phones.
2. **`TextScaled` hides problems until translation.** Text that scales to fill its box looks fine in English, then shrinks to unreadable sizes in languages with longer words. Pair `TextScaled` with a `UITextSizeConstraint` minimum, and size labels for the longest likely translation. Below roughly 14 to 16 pixels on a phone, text is hard to read for many players (rule of thumb).
3. **Console is a different interaction model.** On a gamepad there is no pointer by default; players move a selection between buttons. Menus that work by hover, or that put the close button in a corner with nothing navigable nearby, trap console players. Set a sensible first selected button when a menu opens, make sure every button is reachable with the D-pad, and bind the B button to close. Test with a real controller, not only the emulator.
4. **Touch targets.** A button that is easy to click with a mouse can be too small for a thumb. Keep touch targets around 44 to 48 pixels or larger on phones (rule of thumb from mobile platform guidelines), and leave space around buttons near the jump button and thumbstick so players do not open the shop by accident mid-jump.
5. **Safe areas differ by device and orientation.** Notches, rounded corners, the Roblox top bar and home indicators each take space. `ScreenGui.ScreenInsets` lets a GUI respect device safe insets or core UI insets (Roblox docs, as of October 2026). Backgrounds and full-screen dims should ignore insets; buttons and text should respect them. Rotation between landscape orientations can move the notch from one side to the other.
6. **Many ScreenGuis cost little; many changing elements cost more.** The usual UI performance problem is not the number of frames but how often they change: a leaderboard rebuilt every second, labels updated every frame, or hundreds of list items each with tweens. Update on change, throttle frequent values (a currency ticking 60 times a second can update its label 10 times a second), and virtualize long lists.
7. **Server-owned values arrive late.** A label bound to a server attribute shows a default until replication arrives on join. Show a neutral placeholder (a dash, a shimmer) rather than "0", which players read as lost progress.
8. **One menu at a time across scripts.** The "only one menu open" pattern breaks when a second script opens a menu directly without the shared controller. Make the controller the only way to open a menu, and route prompts from other systems (purchases, rewards) through it.

## More common mistakes

1. **Assuming the mouse.** Symptom: hover-only tooltips and right-click actions that touch and console players never see. Fix: every action reachable by tap and by gamepad selection.
2. **No minimum text size.** Symptom: labels become a few pixels tall on small phones or in long translations. Fix: `UITextSizeConstraint` with a sensible minimum.
3. **Buttons under the thumbstick or jump button.** Symptom: accidental taps during movement. Fix: keep the lower corners clear on touch devices.
4. **Showing "0" before data loads.** Symptom: players panic about lost progress on join. Fix: placeholders until the first value arrives.
5. **No gamepad close binding.** Symptom: console players get stuck in a menu. Fix: bind the B button to close and set the selected object on open.
6. **Tweening layout-controlled children.** Symptom: items in a UIListLayout snap back after a size or position tween. Fix: tween a wrapper frame or a UIScale, not the child the layout positions.
7. **Rebuilding the whole list for one changed item.** Symptom: scroll position jumps and frame spikes on every update. Fix: update the one row, or virtualize.

## Related decisions

- [[Responsive UI for Phone Tablet Console and PC]]: the full layout strategy these recipes serve.
- [[Safe Areas and Insets]]: the inset rules behind recipe 9.
- [[Gamepad and Console UX]]: selection, focus and button prompts for controllers.
- [[Readable Text and UI Scale]]: minimum sizes and scaling for readability.
- [[Virtualized Lists and Large Inventories]]: when a template-built list gets too long.
- [[UI Motion Language and Timing]]: durations and easing for the open and close tweens.
- [[Localization-Ready Writing]]: writing labels that survive translation.
- [[Input Remapping and One-Handed Play]]: accessibility needs that affect button layout.
- [[Debugging UI Layout and Input]]: diagnosing layouts that break on one device only.

## Connected notes
<!-- auto-links:start -->
[[Safe Area]] · [[Skill - Roblox UI Builder]] · [[Links - UI elements]] · [[Check-UI Design System]] · [[Plugin UI with DockWidgets]] · [[UI and GUI Animation]]
<!-- auto-links:end -->
