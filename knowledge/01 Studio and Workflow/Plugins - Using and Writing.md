---
tags: [studio, plugins, tooling, security, workflow]
---
# Plugins - Using and Writing

A plugin is Luau that runs inside Studio with access to the editor: the selection, the undo history, script sources, the file pickers, widgets docked beside the Explorer. Community plugins cover building, animation, UI and terrain; your own plugins turn repeated Command Bar snippets into buttons the whole team can use. Plugins also have enough power to rewrite every script in your place, which makes installing one a security decision. This note covers choosing and managing plugins safely, then writing them properly with the current APIs (as of October 2026: `CreateDockWidgetPluginGuiAsync`, `ChangeHistoryService` recordings, `ScriptEditorService`).

Labels: **Docs**, **Measured** (reference project), **Rule of thumb**.

---

## 1. Using plugins

### Where they come from

- **Creator Store / Toolbox**: search the Plugins category, open the details page, click **Install**; it appears on the **Plugins** tab (Docs). Plugins can be free or sold for USD; sellers keep 100% of net proceeds after taxes and payment fees (Docs, see [[Creator Store and Toolbox Safety]]).
- **Local plugins**: `.rbxm`/`.rbxmx`/`.lua` files in your local Plugins folder (setting **PluginsDir**), for example built by Rojo.
- **Your inventory**: plugins you published appear under the Toolbox **Inventory** and **Creations** tabs (Docs).

### What a plugin can do

Plugins run with plugin security: they can read and write the data model, read and write script sources, record undo waypoints, open files you pick, and make HTTP requests. Two controls exist (Rule of thumb, based on Studio's plugin management UI):
- **Script injection**: Studio asks before a plugin is allowed to modify scripts. Grant it only to plugins whose job is editing code.
- **HTTP**: with **Enable Http Sandboxing** on (Docs setting), plugin requests are sandboxed and Studio asks per domain. A building plugin that wants to talk to an unknown domain is a red flag.

### Choosing plugins

| Signal | Good | Bad |
|---|---|---|
| Creator | Known author, many assets, verified | New account, single asset |
| Reviews and installs | Many, recent | Few, or suspiciously uniform |
| Permissions requested | Matches its job | A part aligner wanting script injection or HTTP |
| Updates | Changelog | Silent updates that change behaviour |
| Source | Open source repository you can read | Obfuscated |

Plugins update themselves. A plugin that was safe last month can push an update. For a team, keep a short **approved plugins list** with versions, and treat plugins with script injection like dependencies in code review (Rule of thumb).

### Plugins in tests

**LoadUserPluginsInRunModes** controls whether your plugins load during Test and Run (Docs setting). Leave it off unless a plugin must run in tests; otherwise plugin code adds output noise and frame cost to every test.

## 2. When to write a plugin

| You have | Make it |
|---|---|
| A one-off fix | Command Bar snippet |
| A tool you run weekly with arguments | A `.luau` file loaded from the Command Bar ([[Command Bar and Studio Scripting]]) |
| A tool others click, with UI, settings, undo | A plugin |
| A tool that must react to selection or edits live | A plugin |
| A tool for CI with no desktop | Open Cloud Luau Execution or the Studio CLI, not a plugin |

## 3. The development loop

1. Enable **Plugin Debugging Enabled** in Studio Settings (Studio tab). This exposes `PluginDebugService` for live debugging (Docs).
2. Write a `Script` in `ServerStorage`, select it, **Plugins > Save as Local Plugin** (Docs).
3. The plugin appears under `PluginDebugService` and runs. **Delete the original script** and edit the copy in `PluginDebugService`, or you will edit the wrong one (Docs, marked important).
4. Right-click it: **Save and Reload Plugin**, or **Reload Plugin** to rerun without saving; `Ctrl Shift L` saves and reloads all (Docs).
5. Ship: select the plugin script, **Plugins > Publish as Plugin**, add a 512x512 thumbnail, name, description and creator (Docs).

With Rojo, build straight into the plugins folder (`rojo build -o "<PluginsDir>/MyTool.rbxm"`) and turn on **ReloadLocalPluginsOnChange**. Rojo 7.5+ maps `*.plugin.luau` to a Script with `RunContext = Plugin` (Rojo changelog). See [[External Tooling - Rojo Wally Selene StyLua]].

## 4. Anatomy of a correct plugin

The `plugin` global exists only in the top-level plugin script; pass it to modules explicitly (Docs).

| Need | API (Docs) |
|---|---|
| Toolbar button | `plugin:CreateToolbar(name)`, `toolbar:CreateButton(id, tooltip, icon)`, `button.Click`; set `ClickableWhenViewportHidden = true` for script-focused tools |
| Docked window | `plugin:CreateDockWidgetPluginGuiAsync(id, DockWidgetPluginGuiInfo.new(...))` (the non-Async version is deprecated) |
| Menus and bindable actions | `plugin:CreatePluginMenu`, `plugin:CreatePluginAction` (actions can be bound to shortcuts) |
| Persistent settings | `plugin:GetSetting(key)`, `plugin:SetSetting(key, value)` |
| Undo support | `ChangeHistoryService:TryBeginRecording(name)` then `FinishRecording(id, Enum.FinishRecordingOperation.Commit)` |
| Selection | `Selection:Get()`, `Selection.SelectionChanged` |
| Editing code | `ScriptEditorService:UpdateSourceAsync`, `OpenScriptDocumentAsync` |
| Current script, user | `StudioService.ActiveScript`, `plugin:GetStudioUserId()` |
| Cleanup | `plugin.Unloading` |
| Theme | `settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)` and `settings().Studio.ThemeChanged` |

### DockWidgetPluginGuiInfo argument order

`DockWidgetPluginGuiInfo.new(initialDockState, initialEnabled, initialEnabledShouldOverrideRestore, floatingXSize, floatingYSize, minWidth, minHeight)` (Docs). Getting the third argument wrong is why a widget "opens every time Studio starts" or "never opens".

### Settings caveats

`SetSetting` persists JSON across Studio restarts. Keys must not contain backslashes, newlines, quotes or periods, values must be JSON-serialisable, and both calls can **silently fail** when several instances of the plugin run at once (several Studio windows, Team Create, multi-client tests) (Docs). Read back after writing anything important and never store secrets there.

### Recordings and undo

Rules from the docs:
- One recording per plugin at a time; `TryBeginRecording` returns `nil` if one is already open.
- `FinishRecording` with `Commit` adds a waypoint, `Cancel` discards and **reverts** the recorded changes, `Append` merges into the previous waypoint.
- Reloading a plugin does not cancel an open recording; store the id (for example in an attribute) so the reloaded plugin can cancel it.
- `SetWaypoint` is "deprecated soon" in favour of recordings.
- `ChangeHistoryService` does nothing in a running experience.

Supporting undo is still correct for a plugin: it is how a solo user expects Studio to behave. But in a shared place, users should not rely on it (see [[Command Bar and Studio Scripting]]). A good team plugin also offers its own **revert from data** (Pre-attributes or a snapshot), which survives interleaved edits.

## 5. A complete example: Reversible Bulk Anchor

A widget with two buttons: anchor every unanchored BasePart in the selection (recording undo and storing originals), and revert from the stored data. It handles theme changes, cleans up, and never leaves a recording open.

```lua
--!strict
-- Plugin script (Save as Local Plugin). Uses only documented plugin APIs.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local ATTR = "PreBulkAnchor_Anchored"

local toolbar = plugin:CreateToolbar("Team Tools")
local button = toolbar:CreateButton("BulkAnchor", "Reversible bulk anchor", "rbxassetid://0000000000")
button.ClickableWhenViewportHidden = true

local info = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float, -- start floating
	false, -- hidden at first
	false, -- respect the previously saved enabled state
	260, 120, -- floating size
	200, 100 -- minimum size
)
local widget = plugin:CreateDockWidgetPluginGuiAsync("TeamTools_BulkAnchor", info)
widget.Title = "Bulk Anchor"

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = widget

local function makeButton(text: string): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -12, 0, 32)
	b.Text = text
	b.Parent = widget
	return b
end

local anchorButton = makeButton("Anchor selection (store originals)")
local revertButton = makeButton("Revert selection from stored data")
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 24)
status.Text = ""
status.Parent = widget

local function applyTheme()
	local theme = settings().Studio.Theme
	for _, child in widget:GetChildren() do
		if child:IsA("TextButton") or child:IsA("TextLabel") then
			child.BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Button)
			child.TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		end
	end
end
applyTheme()
local themeConn = settings().Studio.ThemeChanged:Connect(applyTheme)

local function partsInSelection(): { BasePart }
	local out: { BasePart } = {}
	for _, root in Selection:Get() do
		if root:IsA("BasePart") then
			table.insert(out, root)
		end
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function withRecording(name: string, fn: () -> number): number?
	local id = ChangeHistoryService:TryBeginRecording(name)
	if not id then
		status.Text = "another recording is open"
		return nil
	end
	local ok, result = pcall(fn)
	if ok then
		ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Commit)
		return result
	end
	ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Cancel)
	status.Text = "failed: " .. tostring(result)
	return nil
end

anchorButton.Activated:Connect(function()
	local n = withRecording("Bulk anchor", function(): number
		local count = 0
		for _, part in partsInSelection() do
			if not part.Anchored then
				if part:GetAttribute(ATTR) == nil then
					part:SetAttribute(ATTR, false) -- original value, stored once
				end
				part.Anchored = true
				count += 1
			end
		end
		return count
	end)
	if n then
		status.Text = ("anchored %d parts"):format(n)
	end
end)

revertButton.Activated:Connect(function()
	local n = withRecording("Bulk anchor revert", function(): number
		local count = 0
		for _, part in partsInSelection() do
			local original = part:GetAttribute(ATTR)
			if original ~= nil then
				part.Anchored = original :: boolean
				part:SetAttribute(ATTR, nil)
				count += 1
			end
		end
		return count
	end)
	if n then
		status.Text = ("reverted %d parts"):format(n)
	end
end)

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

plugin.Unloading:Connect(function()
	-- Toolbar buttons and widgets are cleaned up automatically (Docs); disconnect our own connections.
	themeConn:Disconnect()
end)
```

Notes on the design:
- The plugin acts on **Selection** because a human clicks the button right after selecting; that is the legitimate case. Automated tools should not (see [[Explorer Properties and Selection]]).
- `withRecording` always finishes the recording, even on error, so the plugin never blocks itself.
- The revert works from stored data, so it still works after other edits made the undo history useless.

## 6. Plugins and the rest of Studio

- **Multiple instances.** One plugin can run in several Studio windows at once (multi-client tests, several places). Settings may race; widget ids must be unique per plugin.
- **Data models.** A plugin can run in Edit, and in Server/Client data models during tests; check `RunService:IsEdit()` or `RunService:IsRunning()` and do nothing where it makes no sense.
- **Team Create.** Your plugin's edits replicate to every collaborator. A plugin that previews by changing Lighting changes it for everyone.
- **Instances the plugin creates.** Clean them up on `Unloading`; otherwise users must reopen the place (Docs).
- **User input.** `UserInputService` does not work inside widgets; use GUI events such as `InputBegan` on a transparent frame (Docs).
- **Drag and drop.** `plugin:StartDrag(info)` and `PluginGui.PluginDragDropped` move data between widgets (Docs).

## 7. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Using deprecated `CreateDockWidgetPluginGui` | Works today, warnings tomorrow | `CreateDockWidgetPluginGuiAsync` |
| Recording never finished on error | Plugin cannot record again until reload | Finish with Cancel in the error path |
| Editing the original script after Save as Local Plugin | Changes never reach the running plugin | Delete it, edit in `PluginDebugService` |
| Storing data in `SetSetting` without verifying | Silent loss with several Studio windows | Read back; tolerate `nil` |
| Hard-coded colours | Unreadable in the other theme | Theme colours plus `ThemeChanged` |
| Granting script injection to everything | Supply-chain risk | Approved list; inject only for code tools |
| Plugin loads during tests by default | Noise, cost | Check the run mode; setting off |

## 8. Checklist

- [ ] Plugin debugging on; dev loop through `PluginDebugService`.
- [ ] Async widget API, correct `DockWidgetPluginGuiInfo` order.
- [ ] Every change in a recording that always finishes.
- [ ] Revert path from stored data for bulk changes.
- [ ] Theme-aware UI; cleanup on `Unloading`.
- [ ] Settings read back; no secrets.
- [ ] Team approved-plugins list with permissions noted.

## See also

- [[Command Bar and Studio Scripting]], [[Studio Settings and Shortcuts]], [[Creator Store and Toolbox Safety]]
- [[External Tooling - Rojo Wally Selene StyLua]], [[Asset Pipelines]]
- Animation section: [[Studio Tooling Architecture]], [[Moon Animator and Third-Party Tools]]

## Nuances and edge cases

1. **A plugin runs with your permissions in every place you open.** It can read and edit any script, insert assets and, with permission, make HTTP requests. A plugin that is safe today can change behaviour in an update you did not review. For a team, keep a short list of approved plugins and pin versions where the source allows it (see [[Plugin Security and Permissions]]).
2. **Plugins see Edit mode and Play mode differently.** During a play test the plugin keeps running in the edit data model, while the game runs in separate data models for server and client. Code that assumes `workspace` is the running game will be looking at the wrong copy. Check `RunService:IsEdit()` and decide explicitly what the plugin does during tests.
3. **Undo is a contract with the user.** Every change a plugin makes should be wrapped in a ChangeHistoryService recording, so one Ctrl+Z reverts one logical action. A bulk tool that edits 3,000 parts without a recording leaves the designer with no undo, or with 3,000 separate undo steps (see [[Undo and ChangeHistoryService Done Right]]).
4. **Large selections need batching.** A tool that processes 50 parts instantly can freeze Studio for many seconds on 50,000. Yield every few hundred items with `task.wait()` and show progress, or Studio looks hung and the user force-quits mid-operation, leaving the place half-edited.
5. **Team Create changes the risk.** In a shared place, a plugin edit replicates to collaborators immediately, and another person's undo history does not cover your change. Bulk tools should write a snapshot or a report of what they changed so someone can reverse it by hand if needed.
6. **Plugin settings are per user, not per place.** `plugin:SetSetting` stores data for that user on that machine, so a team does not share settings through it. Put shared configuration in the place itself (a configuration folder with attributes) or in the repository.
7. **Local plugins versus published plugins.** Local plugin files update the moment you save them and are invisible to teammates; published plugins update for everyone who installed them. Develop locally, publish only stable versions, and tell the team when an update changes behaviour.
8. **Studio versions change APIs.** Plugin-facing APIs and widget behaviour shift between Studio releases; a plugin that worked last month may warn or break. Keep plugins small, avoid undocumented behaviour, and test after Studio updates.

The senior trade-off: writing a plugin pays off when the same manual task happens weekly, or when doing it by hand is error-prone. A one-off cleanup is often faster and safer as a reviewed command bar script with a snapshot taken first.

## Common mistakes (advanced)

1. **No ChangeHistoryService recording.** Symptom: designers lose work they cannot undo. Fix: begin and finish a recording around every edit.
2. **Processing huge selections in one frame.** Symptom: Studio freezes, sometimes crashes. Fix: batch with yields and a progress label.
3. **Connections left alive after the widget closes.** Symptom: Studio slows over a long session; selection changes feel laggy. Fix: disconnect on widget close and on `plugin.Unloading`.
4. **Installing a plugin because it is popular.** Symptom: unexpected scripts appear in the place, sometimes obfuscated. Fix: check the author and source, test in an empty place, and scan for new scripts after installing.
5. **Assuming the plugin runs in play tests.** Symptom: tool buttons do nothing or edit the wrong copy during play. Fix: disable actions while a test runs, or handle the play data model on purpose.
6. **Hard-coding paths to objects.** Symptom: the tool breaks when a folder is renamed. Fix: find targets by tag or by selection.

## Related decisions

- [[Building a Studio Plugin End to End]]: a full plugin built step by step.
- [[Plugin UI with DockWidgets]]: widget layout and lifecycle details.
- [[Selection Editing and Bulk Tools]]: patterns for safe bulk edits.
- [[Publishing Selling and Updating Plugins]]: distribution and update discipline.
- [[Links - Backdoors and malicious assets]]: what malicious plugins look like.
- [[Batch Processing Tools in Studio]]: batching and progress for large edits.
- [[Studio Plugins and Local HTTP Bridges]]: plugins that talk to external tools.
- [[Safe Changes in a Shared Place]]: plugin edits in Team Create.

## Connected notes
<!-- auto-links:start -->
[[Plugin Development Start Here]] · [[Links - Plugins and custom tools]] · [[Studio Interface Tour]] · [[Team Create and Collaboration]] · [[Resource Library - Safety (free models and plugins)]] · [[Writing Your Own MCP Server]]
<!-- auto-links:end -->
