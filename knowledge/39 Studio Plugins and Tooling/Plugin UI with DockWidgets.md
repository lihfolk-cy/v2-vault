---
tags: [studio, plugins, ui, dockwidget, theme, tooling]
---
# Plugin UI with DockWidgets

Almost every plugin that outlives its first week grows a panel. A `DockWidgetPluginGui` is that panel: a Studio window you fill with ordinary `GuiObject`s, which users can dock beside the Explorer, float, resize and close. Building one is easy. Building one that opens where the user left it, reads well in both themes, stays responsive with ten thousand rows, never fights the user for keyboard focus, and costs nothing when hidden takes knowledge the basic examples skip. This note covers that knowledge.

It assumes the lifecycle and project layout from [[Building a Studio Plugin End to End]]. Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. What a dock widget is, mechanically

- `plugin:CreateDockWidgetPluginGuiAsync(pluginGuiId, info)` creates the widget and **yields** (Roblox docs). The non-Async `CreateDockWidgetPluginGui` is deprecated; the docs' own widget guide still shows the old name in examples, so do not copy those lines verbatim.
- The widget is a `LayerCollector` (it inherits from `PluginGui`), so you parent `GuiObject`s directly to it, exactly as you would to a `ScreenGui` (Roblox docs).
- `PluginGui` adds `Title`, `BindToClose`, `GetRelativeMousePosition`, the four `PluginDrag*` events, `WindowFocused` and `WindowFocusReleased`. `DockWidgetPluginGui` adds one read-only property, `HostWidgetWasRestored` (Roblox docs).
- Widgets are cleaned up automatically when the plugin unloads (Roblox docs). You do not destroy them in `Unloading`.

### The info object and persistence

`DockWidgetPluginGuiInfo.new(initialDockState, initialEnabled, initialEnabledShouldOverrideRestore, floatingXSize, floatingYSize, minWidth, minHeight)`, in that order (Roblox docs). `initialDockState` is one of `Top`, `Bottom`, `Left`, `Right`, `Float` (Roblox docs, `Enum.InitialDockState`).

The part people get wrong is persistence. The docs say the `pluginGuiId` "should be a unique and consistent string. It is used to save the state of the widget's dock state and other internal details." So:

| You want | Set |
|---|---|
| The panel to reopen where and as the user left it | `initialEnabledShouldOverrideRestore = false` and never change the id |
| The panel to always start hidden (a tool opened on demand) | `initialEnabled = false`, override `true` |
| The panel to always start visible (a status panel) | `initialEnabled = true`, override `true`; use sparingly, it annoys people |
| To reset a broken layout for everyone after an update | Change the id once (users lose their saved dock position), and note it in the changelog |

`HostWidgetWasRestored` tells you whether saved state was applied. Use it for one thing: showing a short first-run hint only when the widget had no saved state, which is a decent proxy for "first time this user opened the panel" (rule of thumb; the docs describe the property only in one line).

Minimum sizes are honoured "with some platform-specific variations" (Roblox docs). Do not rely on the minimum to protect your layout; design for a 200 by 150 pixel panel anyway, because users dock widgets into narrow columns.

## 2. Syncing the toolbar button with the widget

The widget's built-in close button sets `Enabled = false` without consulting you. `BindToClose` runs a function on close, but per the docs "the widget closes and its Enabled property becomes false even when a function is bound, so the function can't prevent or delay closing." It is a hook for saving, not a confirmation dialog.

Keep the button honest by listening to the property, not to your own clicks:

```lua
--!strict
local function bindToggle(button: PluginToolbarButton, widget: DockWidgetPluginGui): RBXScriptConnection
	button:SetActive(widget.Enabled)
	button.Click:Connect(function()
		widget.Enabled = not widget.Enabled
	end)
	return widget:GetPropertyChangedSignal("Enabled"):Connect(function()
		button:SetActive(widget.Enabled)
	end)
end
```

If your panel holds unsaved edits (a form, a text field), save drafts on `BindToClose` and on `WindowFocusReleased` into `plugin:SetSetting`, and restore them when the widget opens. You cannot block the close, so make closing lossless.

## 3. Theming that actually works

Studio has a light and a dark theme, and users switch. A widget with hard-coded colours is unreadable in one of them. The API (Roblox docs):

- `settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.X, Enum.StudioStyleGuideModifier.Y)`, where the modifier is `Default`, `Selected`, `Pressed`, `Disabled` or `Hover`.
- `settings().Studio.ThemeChanged` fires on switch.
- `StudioStyleGuideColor` has about 130 entries as of October 2026, including `MainBackground`, `MainText`, `SubText`, `DimmedText`, `Button`, `ButtonText`, `ButtonBorder`, `InputFieldBackground`, `InputFieldBorder`, `Border`, `Item`, `TableItem`, `ErrorText`, `WarningText`, `LinkText`, `Separator`, `ScrollBar` and `ScrollBarBackground`.

The trap is re-theming. The basic example connects `ThemeChanged` once per object group; a widget that rebuilds rows on every refresh then leaks a connection per rebuild, or new rows are created with no theme at all. The fix is to make theme a **property of the role**, not of the instance: tag each object with a role when you create it, and have one function that themes any object from its role, called both at creation and on theme change.

```lua
--!strict
-- Theme: roles map to style guide colours. Objects store their role in an attribute.
local Theme = {}

type Role = "panel" | "text" | "subtext" | "button" | "input" | "row" | "error"

local ROLE_COLORS: { [Role]: { bg: Enum.StudioStyleGuideColor?, fg: Enum.StudioStyleGuideColor? } } = {
	panel = { bg = Enum.StudioStyleGuideColor.MainBackground },
	text = { fg = Enum.StudioStyleGuideColor.MainText },
	subtext = { fg = Enum.StudioStyleGuideColor.SubText },
	button = { bg = Enum.StudioStyleGuideColor.Button, fg = Enum.StudioStyleGuideColor.ButtonText },
	input = { bg = Enum.StudioStyleGuideColor.InputFieldBackground, fg = Enum.StudioStyleGuideColor.MainText },
	row = { bg = Enum.StudioStyleGuideColor.TableItem, fg = Enum.StudioStyleGuideColor.MainText },
	error = { fg = Enum.StudioStyleGuideColor.ErrorText },
}

function Theme.apply(obj: GuiObject, modifier: Enum.StudioStyleGuideModifier?)
	local role = obj:GetAttribute("ThemeRole") :: Role?
	if not role then
		return
	end
	local spec = ROLE_COLORS[role]
	local theme = settings().Studio.Theme
	local mod = modifier or Enum.StudioStyleGuideModifier.Default
	if spec.bg then
		obj.BackgroundColor3 = theme:GetColor(spec.bg, mod)
	end
	if spec.fg and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
		(obj :: any).TextColor3 = theme:GetColor(spec.fg, mod)
	end
end

function Theme.make(className: string, role: Role, parent: Instance?): GuiObject
	local obj = Instance.new(className) :: GuiObject
	obj:SetAttribute("ThemeRole", role)
	obj.BorderSizePixel = 0
	Theme.apply(obj)
	obj.Parent = parent
	return obj
end

-- One connection for the whole widget: re-theme every descendant that has a role.
function Theme.watch(root: Instance): RBXScriptConnection
	return settings().Studio.ThemeChanged:Connect(function()
		for _, d in root:GetDescendants() do
			if d:IsA("GuiObject") then
				Theme.apply(d)
			end
		end
	end)
end

-- Hover feedback using the style guide's own modifiers.
function Theme.hover(button: GuiButton): ()
	button.MouseEnter:Connect(function()
		Theme.apply(button, Enum.StudioStyleGuideModifier.Hover)
	end)
	button.MouseLeave:Connect(function()
		Theme.apply(button)
	end)
end

return Theme
```

Why an attribute: rows are destroyed and rebuilt all the time, and a role stored on the instance survives any rebuild order. The watcher holds one connection for the widget's life. Hover connections die with the button.

Fonts: Studio itself uses a sans font at small sizes. Rule of thumb: `TextSize` 14 for body, 12 for secondary, `Font = Enum.Font.SourceSans` or a `FontFace` built from `Font.fromEnum`, and never `TextScaled` in a widget. Scaled text in a resizable panel jumps size every time the user drags the splitter.

Roblox publishes a repository of Studio-styled components ("StudioWidgets" on GitHub, linked from the docs) with checkboxes, radio buttons and inputs that support the dark theme. It is old but readable; borrow ideas, not necessarily code.

## 4. Layout for panels that get resized constantly

Game UI targets known screen ratios. Panels target any rectangle from a 200 pixel sliver to a second monitor. Rules of thumb:

- **Offset for heights, scale for widths.** Rows are a fixed pixel height (24 to 28 is Studio-like); widths are `UDim2.new(1, -padding, 0, height)`.
- **A header that never scrolls** plus a `ScrollingFrame` that fills the rest: `Size = UDim2.new(1, 0, 1, -headerHeight)`.
- **`AutomaticCanvasSize = Y`** with `CanvasSize = UDim2.new()` on the scrolling frame, and a `UIListLayout`. Manual canvas maths breaks on the first resize.
- **`TextTruncate = AtEnd`** on every label that shows a path or a name. Full paths go in a tooltip-like status line, not the row.
- **Test at 200 pixels wide.** If a button label wraps or clips there, shorten it.

See [[Layout - Scale Offset and Constraints]] and [[UI Layout Objects - Lists Grids and Pages]] for the general mechanics; the difference here is that the aspect ratio is chosen by the user, live.

## 5. Big lists: virtualize or cap

A plugin that lists "every part with a missing texture" in a large place may produce 50,000 rows. Creating 50,000 `TextButton`s takes seconds, freezes Studio, and the widget then lags on every scroll. Two acceptable answers:

1. **Cap and summarise** (simplest): show the first 500, a count of the rest, and filters to narrow down. Good enough for most audits.
2. **Virtualize**: create only enough row objects to fill the visible area plus a small buffer, and rebind them to data as the user scrolls. [[Virtualized Lists and Large Inventories]] covers the technique for game UI; it applies unchanged inside a widget.

```lua
--!strict
-- Minimal fixed-height virtual list for a widget. Rows are pooled and rebound on scroll.
local ROW_H = 24

local function virtualList(scroller: ScrollingFrame, render: (row: TextButton, index: number) -> ())
	local count = 0
	local pool: { TextButton } = {}
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.None

	local function refresh()
		scroller.CanvasSize = UDim2.fromOffset(0, count * ROW_H)
		local first = math.floor(scroller.CanvasPosition.Y / ROW_H) + 1
		local visible = math.ceil(scroller.AbsoluteWindowSize.Y / ROW_H) + 2
		for i = 1, visible do
			local row = pool[i]
			if not row then
				row = Instance.new("TextButton")
				row.Size = UDim2.new(1, 0, 0, ROW_H)
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.TextTruncate = Enum.TextTruncate.AtEnd
				row.Parent = scroller
				pool[i] = row
			end
			local index = first + i - 1
			if index <= count then
				row.Visible = true
				row.Position = UDim2.fromOffset(0, (index - 1) * ROW_H)
				render(row, index)
			else
				row.Visible = false
			end
		end
	end

	local c1 = scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(refresh)
	local c2 = scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(refresh)

	return {
		setCount = function(n: number)
			count = n
			refresh()
		end,
		destroy = function()
			c1:Disconnect()
			c2:Disconnect()
		end,
	}
end
```

The render callback must not connect events on the row (it runs on every scroll). Connect `Activated` once when the row is created, and have it read the current index from an attribute that `render` sets. Forgetting this is the classic virtual list leak.

## 6. Refreshing without burning Studio

The usual panel shows something about the current selection or the place. The naive version rebuilds on `Selection.SelectionChanged`, `DescendantAdded` and property signals. Three things go wrong:

- **Burst events.** Dragging a selection box across 2,000 parts fires `SelectionChanged` many times. Pasting a model fires `DescendantAdded` thousands of times.
- **Hidden panels still work.** A widget with `Enabled = false` still runs every connected handler.
- **Feedback loops.** A panel that calls `Selection:Set` inside a `SelectionChanged` handler triggers itself (the docs note `Set` fires the event unless the new selection is identical).

The pattern that fixes all three (rule of thumb): mark the panel dirty on any event, and refresh at most once per frame, only while visible.

```lua
--!strict
local RunService = game:GetService("RunService")

local function makeRefresher(widget: DockWidgetPluginGui, refresh: () -> ())
	local dirty = true
	local busy = false
	local function markDirty()
		dirty = true
	end
	local conn = RunService.Heartbeat:Connect(function()
		if not dirty or busy or not widget.Enabled then
			return
		end
		dirty = false
		busy = true
		local ok, err = pcall(refresh)
		busy = false
		if not ok then
			warn("[MyPlugin] refresh failed: " .. tostring(err))
		end
	end)
	return markDirty, conn
end
```

`Heartbeat` runs in Edit in Studio, which is why this works without a running game (rule of thumb, widely relied on by plugins). If your refresh is expensive (a full scan), throttle harder: refresh at most every 0.25 s, and show a "stale, click to rescan" hint rather than scanning on every change. When the widget opens (`Enabled` becomes true), mark dirty so the user never sees stale content from before it was hidden. `WindowFocused` is another good moment to mark dirty.

## 7. Input inside a widget

Per the docs, `UserInputService` "doesn't work since these services expect the main game window to be in focus". What works:

- `TextBox`, `TextButton`, `ImageButton` behave normally.
- For raw keys, a transparent full-size `Frame` with `InputBegan` captures keyboard input while the widget is focused (the docs' workaround).
- For shortcuts, prefer `PluginAction`s: they show in Studio's shortcut customisation, users can rebind them, and they work when your widget is not focused. A key handler inside a widget only works while the widget has focus, which surprises users.
- Cursor feedback: `plugin:GetMouse().Icon = "rbxasset://SystemCursors/PointingHand"` on `MouseEnter`, and `""` on leave (Roblox docs list the `SystemCursors` names: `Arrow`, `PointingHand`, `OpenHand`, `ClosedHand`, `IBeam`, `SizeNS`, `SizeEW`, `SizeNESW`, `SizeNWSE`, `SizeAll`, `SplitNS`, `SplitEW`, `Forbidden`, `Wait`, `Busy`, `Cross`).

TextBox nuance: while a TextBox in your widget has focus, Studio shortcuts like Delete go to the TextBox, not the viewport. That is correct; the bug is the reverse, where a user presses Delete thinking the text field is focused and deletes their selection in the viewport. Release focus explicitly (`textBox:ReleaseFocus()`) after a submit, and make the focused state visible with a border colour from `InputFieldBorder` with the `Selected` modifier.

## 8. Context menus and drag and drop

**Menus.** `plugin:CreatePluginMenu(id, title, icon)` returns a `PluginMenu`; add `PluginAction`s with `AddAction`, temporary items with `AddNewAction` (hidden from the shortcuts window), separators with `AddSeparator`, submenus with `AddMenu`, then `ShowAsync()` yields until the user picks an item or dismisses the menu (Roblox docs). Create the menu once at startup and reuse it; creating a menu per right-click leaks. If items depend on context, `Clear()` and rebuild with `AddNewAction` before showing.

**Drag and drop.** `plugin:StartDrag({ Sender, MimeType, Data, MouseIcon, DragIcon, HotSpot })` starts a drag; target widgets receive `PluginDragEntered`, `PluginDragMoved`, `PluginDragLeft` and `PluginDragDropped` (Roblox docs). `Data` is a string, so serialise structured payloads with `HttpService:JSONEncode`, and set a specific `MimeType` such as `application/x-mytool-preset` so your drop handler can ignore drags from other plugins. Validate everything in the drop handler: another plugin can send any string with your MIME type.

## 9. Declarative UI in plugins

React-Lua and Fusion both run inside plugins, and for panels with real state (filters, forms, tabs) they remove most of the rebuild bugs above. The trade-offs ([[Declarative UI - React-Lua and Fusion]]):

| Concern | Imperative | Declarative |
|---|---|---|
| Panel with three buttons | Simpler | Overkill |
| Panel with filters, tabs, forms | Rebuild bugs, leaks | State drives UI; far fewer bugs |
| Bundle size and load time | None extra | Library ships inside your plugin |
| Theming | Role attributes (above) | A theme context or state value |
| Big lists | Hand-written virtualization | Still need virtualization |

Whatever you choose, keep scan logic out of components. A component that calls `GetDescendants()` on every render will freeze Studio the first time a user opens your panel in a large place.

## 10. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Changing the widget id between versions | Users' docked layout resets | Keep ids permanent; change once on purpose |
| Override flag true with `initialEnabled = true` | Panel pops open on every Studio start | Respect restore unless you have a reason |
| Hard-coded colours | Unreadable in one theme | Style guide colours, role attributes, one watcher |
| `ThemeChanged` connected per rebuild | Slow leak; duplicate work | One watcher per widget |
| `TextScaled` in panels | Text size jumps on resize | Fixed `TextSize`, truncation |
| Rebuilding on every event | Studio stutters on box-select or paste | Dirty flag, one refresh per frame, only when visible |
| Connecting events in a virtual row's render | Handlers multiply on scroll | Connect once at row creation |
| Using `BindToClose` as a confirmation | Widget closes anyway | Save drafts; make closing lossless |
| Shortcut handled only in the widget | Works only when the panel is focused | `PluginAction` |

## 11. Checklist

- [ ] `CreateDockWidgetPluginGuiAsync`, permanent prefixed id, restore respected.
- [ ] Toolbar button synced to `Enabled` through the property signal.
- [ ] Every object themed by role; one `ThemeChanged` connection.
- [ ] Usable at 200 by 150 pixels; truncation on long text.
- [ ] Lists capped or virtualized; no per-render connections.
- [ ] Refresh is dirty-flagged, at most once per frame, skipped when hidden.
- [ ] Shortcuts are `PluginAction`s; text focus released after submit.
- [ ] Menus created once; drag payloads have a specific MIME type and are validated.
- [ ] Drafts saved on close and focus loss.

## See also

- [[Plugin Development Start Here]], [[Building a Studio Plugin End to End]], [[Selection Editing and Bulk Tools]]
- [[Plugins - Using and Writing]], [[Explorer Properties and Selection]]
- [[UI Design Systems]], [[Virtualized Lists and Large Inventories]], [[Declarative UI - React-Lua and Fusion]], [[Layout - Scale Offset and Constraints]]

## Connected notes
<!-- auto-links:start -->
[[Links - Plugins and custom tools]] · [[Cookbook - UI]] · [[Studio Settings and Shortcuts]] · [[Links - UI elements]] · [[Studio Interface Tour]] · [[Debugging UI Layout and Input]]
<!-- auto-links:end -->
