---
tags: [studio, plugins, tooling, luau, workflow, architecture]
---
# Building a Studio Plugin End to End

[[Plugins - Using and Writing]] shows the anatomy of a plugin and one small example. This note is the next step: how to build a plugin you will still be happy to maintain a year from now. It covers the plugin lifecycle (when your code runs, how many copies run, and in which data models), a project layout that survives growth, a disciplined cleanup pattern, settings with a schema version, actions and shortcuts, error handling, and a complete worked plugin, a **Duplicate Name Linter**, that ties all of it together.

Labels used: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**. Things that could not be confirmed are marked **unverified**.

The deep dives that follow in this section are: [[Plugin UI with DockWidgets]], [[Undo and ChangeHistoryService Done Right]], [[Selection Editing and Bulk Tools]], [[Plugin Security and Permissions]] and [[Publishing Selling and Updating Plugins]]. The hub is [[Plugin Development Start Here]].

---

## 1. When is a plugin the right tool at all

The older notes give the decision table (snippet, loaded file, plugin, CI job). The nuance is in the cost of ownership. A plugin is a small desktop application: it has state that persists between sessions, a UI that must survive two themes and every dock position, a user who will click buttons in an order you did not imagine, and copies of itself running in places you never opened. A Command Bar file loaded over HTTP ([[Command Bar and Studio Scripting]]) has none of that. Rule of thumb: build a plugin only when at least one of these is true.

- Someone other than the author will use it regularly.
- It must react live to selection, edits or the mouse.
- It needs a persistent panel, a context menu or a keyboard shortcut.
- It must be distributed and updated (a team tool or a Creator Store product).

If none holds, keep it a file in the repo. A surprising number of "plugins" in teams are three Command Bar snippets wearing a toolbar button, and they rot because nobody owns them.

## 2. The lifecycle: when and where your code runs

The single most common source of plugin bugs is a wrong mental model of when the script runs.

| Fact | Source |
|---|---|
| Plugins load when Studio opens a place, and again in each place window | Roblox docs describe several instances running at once "if multiple Studio windows are open" |
| `plugin.Unloading` fires before the plugin stops: when disabled, uninstalled, about to be updated, or when the place closes | Roblox docs |
| Toolbar buttons, `DockWidgetPluginGui`s and `PluginGui`s are cleaned up automatically on unload; instances you put into the data model are not | Roblox docs |
| With **LoadUserPluginsInRunModes** on, plugins also load into the test data models (server and clients) | Roblox docs setting (see [[Plugins - Using and Writing]]) |
| `ChangeHistoryService` is disabled at runtime, and `TryBeginRecording` returns `nil` during a solo playtest | Roblox docs |
| Only one plugin can be "activated" (owning the mouse) at a time; activating one fires `Deactivation` on the others | Roblox docs |

Consequences that are easy to miss:

1. **Your script may run several times at once.** Two place windows means two copies, each with its own module state but sharing one settings file. Anything stored with `SetSetting` can be changed by the other copy at any moment, and the docs warn that both `GetSetting` and `SetSetting` can silently fail under contention.
2. **Your script may run in a data model where it makes no sense.** A tool that edits the map must not run inside a test server. Guard at the very top with `RunService:IsEdit()`, and return early (creating nothing) outside Edit. A plugin that creates its toolbar before the guard will show a dead button in test windows.
3. **Reload is not restart.** Reloading through `PluginDebugService` runs your script fresh, but anything you left in the data model (adornments, folders, attributes, an open recording) is still there. The docs specifically warn that an open recording survives a reload. Write startup code that tolerates leftovers from a previous run of itself.
4. **Unloading is the only goodbye you get.** If Studio crashes, `Unloading` never fires. Anything you create in the data model should be either harmless if orphaned (and clearly named so a user can delete it) or kept out of the saved place entirely (see section 4).

## 3. Project layout that survives growth

The `plugin` global exists only in the top-level plugin script (Roblox docs). Everything else should be a ModuleScript that receives what it needs as arguments. That one rule makes the rest of the plugin testable and keeps modules from reaching for a global that is not there.

A layout that has held up (rule of thumb):

```text
DuplicateNameLinter (Script, RunContext = Plugin when built by Rojo)
  Main (ModuleScript)       -- builds everything, owns the Janitor
  Janitor (ModuleScript)    -- cleanup helper
  Settings (ModuleScript)   -- schema, defaults, migration, read-back
  Linter (ModuleScript)     -- pure logic: no plugin, no UI, no services it can avoid
  Ui (ModuleScript)         -- widget construction and theme
  Version (ModuleScript)    -- returns "1.4.0"
```

The top-level script is three lines:

```lua
--!strict
local RunService = game:GetService("RunService")
if not RunService:IsEdit() then
	return -- do nothing in test data models
end
require(script.Main)(plugin)
```

Why the split pays off:

- **Pure logic is testable.** `Linter` takes instances and returns findings. You can run it from the Command Bar with clone-require, or from a TestEZ or Jest-Lua spec ([[Automated Testing with TestEZ and Jest-Lua]]), without a widget in sight.
- **UI churn does not touch logic.** Restyling a panel never risks breaking the scan.
- **Rojo friendly.** With Rojo you build straight into your local plugins folder and keep the source in Git ([[External Tooling - Rojo Wally Selene StyLua]], [[Git and Source Control for Roblox]]).

### The require cache trap inside plugins

Modules inside a plugin are cached for the lifetime of that plugin instance like any other `require`. Measured in the reference project: a plugin's require cache once served an old version of a shared ModuleScript from the place, with an old default value, and the tool silently used it. If your plugin requires modules that live in the **place** (a game's config table, say) rather than inside the plugin, read them with the clone-require pattern from [[Command Bar and Studio Scripting]], or pass explicit values rather than trusting defaults.

## 4. Cleanup: one Janitor, everything registered

Leaks in plugins are worse than in games, because a Studio session can last all day and every reload stacks another copy of your connections. Use one object that owns every connection and every instance you create, and clean it on `Unloading`.

```lua
--!strict
-- Janitor: owns connections, instances and callbacks; Cleanup() releases all of them once.
export type Janitor = {
	Add: (self: Janitor, item: any) -> any,
	Cleanup: (self: Janitor) -> (),
}

local Janitor = {}
Janitor.__index = Janitor

function Janitor.new(): Janitor
	return (setmetatable({ _items = {} }, Janitor) :: any) :: Janitor
end

function Janitor:Add(item: any): any
	table.insert(self._items, item)
	return item
end

function Janitor:Cleanup()
	local items = self._items
	self._items = {}
	-- Release in reverse order: things created last often depend on things created first.
	for i = #items, 1, -1 do
		local item = items[i]
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "function" then
			item()
		end
	end
end

return Janitor
```

Where to put instances your plugin needs in the 3D view (selection boxes, previews, handles): not in `Workspace`, where they get saved into the place and replicated to collaborators in Team Create. Rule of thumb: parent purely visual helpers to `CoreGui`, which plugins can access and which is not saved with the place. If you must put something into the data model, give it an obvious name (`__LinterPreview`), tag it, and on startup delete any leftovers carrying that tag from a previous crashed session.

## 5. Settings with a schema

`SetSetting` stores JSON per plugin, persists across Studio restarts, and has documented restrictions: no backslashes in keys or values, no newlines, quotes or periods in keys (Roblox docs). Treat the settings store as an untrusted, possibly stale file:

- Store one table under one key, with a `schema` number.
- Migrate on read, fill defaults for missing fields, ignore unknown fields.
- After an important write, read back to confirm it took (the docs suggest this for contention).
- Never store secrets: it is a plain file on the user's disk (see [[Plugin Security and Permissions]]).

```lua
--!strict
-- Settings: one versioned table under one key, migrated on read.
local KEY = "DuplicateNameLinter_Settings"
local SCHEMA = 2

export type Settings = {
	schema: number,
	ignoreClasses: { string },
	scanWorkspaceOnly: boolean,
	lastSeenVersion: string,
}

local DEFAULTS: Settings = {
	schema = SCHEMA,
	ignoreClasses = { "Attachment", "Weld", "WeldConstraint" },
	scanWorkspaceOnly = true,
	lastSeenVersion = "0.0.0",
}

local function copyDefaults(): Settings
	return {
		schema = DEFAULTS.schema,
		ignoreClasses = table.clone(DEFAULTS.ignoreClasses),
		scanWorkspaceOnly = DEFAULTS.scanWorkspaceOnly,
		lastSeenVersion = DEFAULTS.lastSeenVersion,
	}
end

local function migrate(raw: any): Settings
	local out = copyDefaults()
	if type(raw) ~= "table" then
		return out
	end
	-- schema 1 stored a single comma-separated string; schema 2 stores an array
	if raw.schema == 1 and type(raw.ignore) == "string" then
		out.ignoreClasses = string.split(raw.ignore, ",")
	elseif type(raw.ignoreClasses) == "table" then
		out.ignoreClasses = raw.ignoreClasses
	end
	if type(raw.scanWorkspaceOnly) == "boolean" then
		out.scanWorkspaceOnly = raw.scanWorkspaceOnly
	end
	if type(raw.lastSeenVersion) == "string" then
		out.lastSeenVersion = raw.lastSeenVersion
	end
	return out
end

local Settings = {}

function Settings.load(p: Plugin): Settings
	local ok, raw = pcall(function()
		return p:GetSetting(KEY)
	end)
	return migrate(if ok then raw else nil)
end

function Settings.save(p: Plugin, s: Settings): boolean
	local ok = pcall(function()
		p:SetSetting(KEY, s)
	end)
	if not ok then
		return false
	end
	local back = p:GetSetting(KEY)
	return type(back) == "table" and back.schema == s.schema
end

return Settings
```

`lastSeenVersion` is what lets you show a "what changed" note once after an update. That flow is covered in [[Publishing Selling and Updating Plugins]].

## 6. Buttons, actions and shortcuts

Three entry points exist, and each has a job (Roblox docs for the APIs, rule of thumb for the split):

| Entry | API | Use it for |
|---|---|---|
| Toolbar button | `toolbar:CreateButton(id, tooltip, icon)`, `Click`, `SetActive` | Toggling the main panel; one or two primary verbs |
| Plugin action | `plugin:CreatePluginAction(actionId, text, statusTip, icon, allowBinding)`, `Triggered` | Anything a power user wants on a keyboard shortcut |
| Plugin menu | `plugin:CreatePluginMenu(id, title, icon)`, `AddAction`, `ShowAsync` | Right-click menus inside your widget |

Details that matter:

- **The action id is a persistence key.** The docs say `ActionId` is "the key used when saving and loading the action's state", which includes a user's shortcut binding. Rename it and every user loses their binding. Prefix it with the plugin name and never change it.
- **`ClickableWhenViewportHidden`.** Default false: the button greys out while a script tab is focused. Set it true for anything that makes sense while editing code.
- **`SetActive` mirrors state.** If the button toggles a widget, keep the button's active look in sync with `widget.Enabled`, including when the user closes the widget with its own close button. [[Plugin UI with DockWidgets]] shows the pattern.
- **Do not create toolbars conditionally.** Creating the toolbar only after some async check makes the button appear late or not at all, and users report "the plugin disappeared".

## 7. Errors and logging

An error thrown inside a connection prints to Output with the plugin script's path and kills only that handler invocation, not the plugin. That is forgiving and dangerous: a half-finished bulk edit can leave the place in a mixed state and the user may not notice the red line. Rules of thumb:

- Every user-triggered operation runs inside `pcall` (or `xpcall` with `debug.traceback` while developing), and every failure is shown **in your widget**, not only in Output. See [[Error Handling - pcall xpcall and Promise Patterns]].
- Every write runs inside a ChangeHistoryService recording that is cancelled on failure, so a failed operation reverts itself. [[Undo and ChangeHistoryService Done Right]] covers why `Cancel` is the right failure path.
- Prefix log lines with the plugin name (`[DupLinter]`) so users can tell your messages from the twenty other plugins writing to Output.
- Keep a debug flag in settings that turns on verbose logging, rather than shipping prints you later forget.

## 8. Worked example: Duplicate Name Linter

The job: find sibling instances with the same name (a frequent cause of `FindFirstChild` bugs, see [[Explorer Properties and Selection]]), list them in a panel, select a group on click, and fix a group by appending `_2`, `_3` to the duplicates, with undo. It scans Workspace by default and ignores classes where duplicates are normal.

The pure logic module:

```lua
--!strict
-- Linter: pure scan. Returns groups of same-named siblings. Yields every `sliceSize` parents
-- so a 200k-instance place does not freeze Studio.
export type Group = { parent: Instance, name: string, members: { Instance } }

local Linter = {}

function Linter.scan(root: Instance, ignore: { [string]: boolean }, sliceSize: number?): { Group }
	local groups: { Group } = {}
	local visited = 0
	local slice = sliceSize or 2000
	local function visit(parent: Instance)
		local byName: { [string]: { Instance } } = {}
		for _, child in parent:GetChildren() do
			if not ignore[child.ClassName] then
				local list = byName[child.Name]
				if list then
					table.insert(list, child)
				else
					byName[child.Name] = { child }
				end
			end
		end
		for name, list in byName do
			if #list > 1 then
				table.insert(groups, { parent = parent, name = name, members = list })
			end
		end
		visited += 1
		if visited % slice == 0 then
			task.wait() -- let Studio repaint; this is a read-only pass so yielding is safe
		end
		for _, child in parent:GetChildren() do
			visit(child)
		end
	end
	visit(root)
	return groups
end

-- Rename all but the first member so names are unique among siblings.
function Linter.fixGroup(group: Group): number
	local taken: { [string]: boolean } = {}
	for _, sibling in group.parent:GetChildren() do
		taken[sibling.Name] = true
	end
	local renamed = 0
	for i = 2, #group.members do
		local inst = group.members[i]
		if inst.Parent == group.parent and inst.Name == group.name then
			local n = i
			local candidate = ("%s_%d"):format(group.name, n)
			while taken[candidate] do
				n += 1
				candidate = ("%s_%d"):format(group.name, n)
			end
			inst.Name = candidate
			taken[candidate] = true
			renamed += 1
		end
	end
	return renamed
end

return Linter
```

Two deliberate choices. First, the scan yields because it is **read only**; a write pass must not yield inside a recording (explained in the undo note). Second, `fixGroup` re-checks `inst.Parent` and `inst.Name` before renaming, because between the scan and the click the user may have moved or renamed things. Stale scan results are the norm in plugins, not the exception.

The main module:

```lua
--!strict
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Janitor = require(script.Parent.Janitor)
local Settings = require(script.Parent.Settings)
local Linter = require(script.Parent.Linter)

return function(p: Plugin)
	local jan = Janitor.new()
	local settings = Settings.load(p)

	local toolbar = p:CreateToolbar("Duplicate Name Linter")
	local toggle = toolbar:CreateButton("DupLinter_Toggle", "Show the duplicate name panel", "rbxassetid://0000000000")
	toggle.ClickableWhenViewportHidden = true

	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 320, 400, 240, 200)
	local widget = p:CreateDockWidgetPluginGuiAsync("DupLinter_Main", info)
	widget.Title = "Duplicate Names"

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 1, -36)
	list.Position = UDim2.fromOffset(0, 36)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = widget
	local layout = Instance.new("UIListLayout")
	layout.Parent = list

	local scanButton = Instance.new("TextButton")
	scanButton.Size = UDim2.new(1, 0, 0, 32)
	scanButton.Text = "Scan"
	scanButton.Parent = widget

	local ignore: { [string]: boolean } = {}
	for _, className in settings.ignoreClasses do
		ignore[className] = true
	end

	local scanning = false
	local function rebuild(groups: { Linter.Group })
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for i, group in groups do
			if i > 500 then
				break -- cap rows; a virtualized list is the real fix (see Plugin UI with DockWidgets)
			end
			local row = Instance.new("TextButton")
			row.Size = UDim2.new(1, 0, 0, 24)
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Text = ("%d x %s  in %s"):format(#group.members, group.name, group.parent:GetFullName())
			row.Parent = list
			row.Activated:Connect(function()
				Selection:Set(group.members)
			end)
			row.MouseButton2Click:Connect(function()
				local id = ChangeHistoryService:TryBeginRecording("DupLinterFix", "Fix duplicate names")
				if not id then
					warn("[DupLinter] another recording is open; try again")
					return
				end
				local ok, result = pcall(Linter.fixGroup, group)
				if ok then
					ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Commit)
					row.Text = ("fixed %d"):format(result)
				else
					ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Cancel)
					row.Text = "failed: " .. tostring(result)
				end
			end)
		end
	end

	jan:Add(scanButton.Activated:Connect(function()
		if scanning then
			return
		end
		scanning = true
		scanButton.Text = "Scanning..."
		local root: Instance = if settings.scanWorkspaceOnly then workspace else game
		local ok, groups = pcall(Linter.scan, root, ignore)
		scanning = false
		scanButton.Text = "Scan"
		if ok then
			rebuild(groups)
		else
			warn("[DupLinter] scan failed: " .. tostring(groups))
		end
	end))

	jan:Add(toggle.Click:Connect(function()
		widget.Enabled = not widget.Enabled
	end))
	jan:Add(widget:GetPropertyChangedSignal("Enabled"):Connect(function()
		toggle:SetActive(widget.Enabled)
	end))
	toggle:SetActive(widget.Enabled)

	jan:Add(p.Unloading:Connect(function()
		jan:Cleanup()
		Settings.save(p, settings)
	end))
end
```

What this example deliberately leaves for the deep dives: theme colours and a proper list ([[Plugin UI with DockWidgets]]), a crash-safe recording helper and undo resync ([[Undo and ChangeHistoryService Done Right]]), deduplicating selected roots ([[Selection Editing and Bulk Tools]]). The row connections are destroyed with the rows, which is why only long-lived connections go into the Janitor.

Scanning `game` instead of `workspace` will hit services that throw on access. If you allow it, wrap each `GetChildren` in `pcall`, as the audit snippets in [[Command Bar and Studio Scripting]] do.

## 9. The development loop, sharpened

The docs give the loop (Plugin Debugging Enabled, Save as Local Plugin, edit inside `PluginDebugService`, Save and Reload, `Ctrl Shift L`). Three refinements (rule of thumb):

- **Keep a test place** with deliberate edge cases: a model with 5,000 children, duplicate names, locked parts, a package, a part inside a tool. Run every release against it.
- **Test with two place windows open** to catch settings races and duplicated state.
- **Test in both themes and in a docked and floating widget.** The bugs differ.

When you use Rojo, set **ReloadLocalPluginsOnChange** so a rebuild reloads the plugin, and keep breakpoints working by building with debug info (the `PluginDebugService` path is what exposes the plugin to the debugger, see [[Debugger Breakpoints and Logging]]).

## 10. Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| No `IsEdit` guard | Dead toolbar buttons or errors in test windows | Return before creating anything outside Edit |
| Helpers parented to Workspace | Teammates see your preview parts; they get saved | `CoreGui` for visuals; tagged and cleaned otherwise |
| Connections not cleaned | Actions fire twice after a reload | One Janitor, cleaned on `Unloading` |
| Settings read once and trusted | Other window's changes overwritten | Read at use time for shared values; read back after writes |
| Renamed action id | Users lose shortcut bindings | Ids are permanent |
| Acting on stale scan results | Wrong instances renamed | Re-validate parent, name, existence before writing |
| Errors only in Output | Users think the tool worked | Show failures in the widget; Cancel the recording |

## 11. Checklist

- [ ] Top-level script is a guard plus one `require`; logic in modules that receive `plugin`.
- [ ] `RunService:IsEdit()` guard before any UI is created.
- [ ] One Janitor owns every long-lived connection and instance; cleaned on `Unloading`.
- [ ] Startup removes leftovers from a crashed previous session.
- [ ] Settings: one key, schema number, migration, read-back, no secrets.
- [ ] Permanent, prefixed ids for widgets, buttons and actions.
- [ ] Every write in a recording, cancelled on failure; every failure shown in the UI.
- [ ] Read-only scans may yield; writes do not.
- [ ] Tested with two windows, both themes, docked and floating.

## See also

- [[Plugin Development Start Here]], [[Plugins - Using and Writing]], [[Command Bar and Studio Scripting]]
- [[Studio Plugins and Local HTTP Bridges]], [[Batch Processing Tools in Studio]], [[Studio Tooling Architecture]]
- [[Module Scripts and Requiring]], [[Events Signals and Connections]], [[Luau Type System and Strict Mode]]

## Connected notes
<!-- auto-links:start -->
[[Studio Settings and Shortcuts]] · [[Links - Plugins and custom tools]] · [[Studio Interface Tour]] · [[Links - Roblox Studio]] · [[Writing Your Own MCP Server]] · [[Script Types and Run Context]]
<!-- auto-links:end -->
