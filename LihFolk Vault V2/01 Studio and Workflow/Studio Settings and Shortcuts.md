---
tags: [studio, settings, shortcuts, workflow, productivity, type/guide, area/studio, level/intermediate, area/monetization]
---
# Studio Settings and Shortcuts

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Auto-recovery never checked -> Verify the AutoSaves folder fills during a session
> - Avoid: Editor formatting fighting StyLua -> One formatter only
> - Avoid: Plugins load during tests -> `LoadUserPluginsInRunModes` off
> - Auto-recovery on and the folder verified.
> - Output context and source on.
> - One formatter, matching indent settings.
>
> Cost: TL;DR ~130 tok · whole note ~3.4k tok. Read more: ## 2. Settings that actually matter · ## 3. Shortcuts worth memorising · ## 5. Common mistakes · ## 6. Checklist
<!-- tldr:end -->

Studio has hundreds of settings and a long shortcut list. Most can stay at their defaults. A handful decide whether you lose work after a crash, whether plugins can reach the network, whether your edits during a test survive, and whether a long command freezes the editor. This note picks those out, gives the exact setting names (from the `Studio` settings class reference as of October 2026), and collects the shortcuts worth memorising, grouped by job. It ends with how to standardise a team's setup, because settings are per machine.

Source labels: **Docs**, **Measured** (reference project), **Rule of thumb**.

---

## 1. Where settings live

- Open **Studio Settings** with `Alt S` (`⌥ S` on Mac) or **File > Studio Settings** (Docs). Type in the search box at the top ("theme", "recovery", "http") instead of browsing tabs.
- Settings are stored **locally per machine**. So are custom toolbar tabs (`CustomRibbonTabs` JSON), saved Command Bar commands, plugin settings (`plugin:SetSetting`) and configurable instance defaults (`DefaultInstances.rbxm`) (Docs). Nothing here follows you to a new PC or to a teammate.
- Plugins and the Command Bar can read many settings through `settings().Studio`, for example `settings().Studio["Auto-Recovery Interval (Minutes)"]`. Most are plugin-security and several are documented as "must be set in Studio Settings" (Docs), so treat code access as read-mostly.
- Shortcuts are rebound in **File > Customize Shortcuts**, which also lists actions that have no default binding (Docs).

## 2. Settings that actually matter

Exact names are the property names in the `Studio` class reference; the dialog label can differ slightly.

### Safety and recovery

| Setting | What it does (Docs) | Recommendation |
|---|---|---|
| **Auto-Recovery Enabled** | Saves recovery files at an interval | On. It is your only net for an unsaved local file |
| **Auto-Recovery Interval (Minutes)** | Interval for recovery files | 5 is the commonly reported default (DevForum, unverified in docs). Keep it short on big edit sessions |
| **Always Save Script Changes** | Tries to carry script edits made during a test back to the place | Do not depend on it; edit scripts in Edit mode |
| **RuntimeUndoBehavior** | How undo behaves during runtime playback | Leave default; never use undo as a backup anyway |

How recovery actually works (Docs): with collaboration (Team Create) on, a failed Save to Roblox keeps the last three save attempts as recovery files; with it off, the Auto-Recovery settings apply. Files land in `%LOCALAPPDATA%\Roblox\RobloxStudio\AutoSaves` on Windows (the docs show the path under a sample user folder) and `~/Library/Application Support/Roblox/RobloxStudio/AutoSaves/` on Mac. DevForum reports in 2025 and 2026 describe the folder sometimes being nearly empty; check yours exists before you need it (unverified, user reports).

**Measured.** In the reference project Studio closed in the middle of a large multi-step revert. The revert was finished on the recovered autosave copy and then verified instance by instance against a saved snapshot (all 4,697 moved units matched). The recovery file saved the day only because the snapshot existed to verify against. Recovery is a starting point, not proof.

### Plugins and networking

| Setting | What it does (Docs) | Recommendation |
|---|---|---|
| **PluginDebuggingEnabled** | Exposes `PluginDebugService` for live plugin debugging | On if you write plugins (see [[Plugins - Using and Writing]]) |
| **Enable Http Sandboxing** | Sandboxes HTTP requests from plugins | Leave on; grant domains per plugin |
| **LoadUserPluginsInRunModes** | Loads your plugins during Test/Run | Off unless a plugin must run in tests; plugins in tests add noise and cost |
| **ReloadLocalPluginsOnChange** | Reloads local plugins when their files change | On when developing plugins built by an external tool |
| **PluginsDir** | Local plugins folder | Know where it is (your `rojo build -o` target) |

Game-level HTTP is not a Studio setting: **Allow HTTP Requests** lives in Experience Settings, or `HttpService.HttpEnabled` set from the Command Bar for unpublished places (Docs, see [[Places Universes and Experience Settings]]).

### Command Bar and scripts

| Setting | What it does (Docs) |
|---|---|
| **CommandBarEnterExec** | Whether Enter runs the command immediately (multi-line bar uses `Ctrl Enter`) |
| **CommandBarLocalState** | Whether the bar keeps its input between sessions |
| **ScriptTimeoutLength** | Seconds a script may wait to be resumed before timing out |
| **Enable Script Analysis**, **Enable Autocomplete**, **Enable Signature Help**, **Enable Type Hover** | Script Editor intelligence; keep on |
| **Format On Type**, **Format On Paste** | Editor auto-formatting; turn **off** if the team formats with StyLua to avoid churn (Rule of thumb) |
| **Indent Using Spaces**, **Tab Width** | Match your StyLua config (Tabs by default) |
| **Clear Output On Start** | Clears Output when sessions switch; on keeps test logs readable |
| **Maximum Output Lines** | Cap on Output history; raise it when debugging floods |

### Script Sync and external editors

| Setting | What it does (Docs) |
|---|---|
| **AutoResumeSyncOnPlaceOpen** | Resume Script Sync when the place opens |
| Resume conflicted sync on place open | Default **Do not resume**: forces you to resolve conflicts, avoiding data loss |
| **ActionOnStopSync** | Keep or delete local files after Stop Sync |
| **DefaultScriptSyncFileType** | File extension used on disk |
| **ExternalEditorMode**, **UseDefaultExternalEditor** | Open scripts in an external editor |

See [[External Tooling - Rojo Wally Selene StyLua]] for when Script Sync is enough and when Rojo is needed.

### Editor feel

| Setting | Notes |
|---|---|
| **Theme** | Dark or light; plugins should follow it (see [[Plugins - Using and Writing]]) |
| **Camera Speed**, **Camera Shift Speed**, **Camera Mouse Wheel Speed**, **Camera Zoom to Mouse Position** | Large maps need higher speed; zoom-to-mouse is a big quality of life win |
| **Show Hidden Objects in Explorer**, **DeprecatedObjectsShown** | Show more of the tree; useful for audits |
| **Respect Studio shortcuts when game has focus** | When on, Studio shortcuts win over game input during tests. Turn **off** if your game binds keys Studio also uses, or your test inputs vanish |
| **Only Play Audio from Window in Focus** | Stops multi-client test windows from all playing sound |
| **EnableStudioStreaming** | Studio streaming mode for large places (Docs list it; test with your own place) |

### Network emulation

The **Network** tab of Studio Settings holds the emulation values that the beta **Network Simulator** edits (Docs). Leaving emulation on by accident makes every test feel laggy. See [[Testing Modes - Play Run and Multi-Client]].

## 3. Shortcuts worth memorising

All from the Studio docs. Windows shown; on Mac use `⌘` for `Ctrl` and `⌥` for `Alt`.

### Global

| Shortcut | Action |
|---|---|
| `Alt S` | Studio Settings |
| `Ctrl Alt S` | Save to Roblox with Notes |
| `Ctrl 9` | Focus the Command Bar |
| `C` | New comment in the viewport (Team Create) |
| `F9` (in a test) | Developer Console |

### Testing and debugging

| Shortcut | Action |
|---|---|
| `F5` | Test (solo test, spawns your character) |
| `F8` | Run (simulate without a character) |
| `F7` | Start Server & Clients test (when that mode is selected) |
| `Shift F5` | Stop |
| `F10` / `F11` / `Shift F11` | Step Over / Step Into / Step Out in the debugger |

### Viewport and building

| Shortcut | Action |
|---|---|
| `2` / `3` / `4` | Move / Scale / Rotate tool (docs list these as the default shortcuts) |
| `Ctrl L` | Toggle world and local orientation for transform tools |
| Hold `Shift` while dragging | Temporarily toggle snapping |
| `Shift 2` / `Alt R` | Jump to the move/scale increment / rotate increment input |
| `Ctrl R` / `Ctrl T` | Rotate selection 90 degrees about Y / X |
| `Ctrl G`, `Ctrl Alt G`, `Ctrl U` | Group as Model, Group as Folder, Ungroup |
| `Alt A`, `Alt L` | Anchor toggle, Lock toggle |
| `F` | Focus selection |
| `Alt`-click | Cycle selection to the object behind |

### Explorer and Properties

| Shortcut | Action |
|---|---|
| `Ctrl I` | Insert object |
| `Ctrl D` | Duplicate |
| `Ctrl V` / `Ctrl Shift V` | Paste into Workspace / Paste Into selection |
| `Ctrl Shift X` | Explorer search |
| `Ctrl Shift P` | Property filter |
| `Ctrl K` | Clear Output |

### Script Editor

| Shortcut | Action |
|---|---|
| `Ctrl P` | Quick open a script by name |
| `Ctrl Shift F` | Find All / Replace All across scripts |
| `Ctrl F` | Find / Replace in the current script |
| `Alt F` | Script Function Filter (jump to a function) |
| `Ctrl`-click | Go to declaration |
| `Ctrl Alt K` | Show the current script in the Explorer |
| `Ctrl W` / `Ctrl Shift T` | Close script / reopen last closed |
| `Ctrl /` | Toggle comment |
| `Ctrl ]` / `Ctrl [` | Indent / unindent |
| `Ctrl E` / `Ctrl Shift E` | Expand all folds / collapse all folds |
| `Ctrl D` | Add a cursor at the next match |
| `Shift Alt L` | Cursor at every match |
| `Alt`-click, `Ctrl U` | Add cursor / remove last cursor |
| `Shift Alt` drag | Column (block) select |
| `Alt \` | Request a Code Assist suggestion |

### Plugin development

| Shortcut | Action |
|---|---|
| `Ctrl Shift L` | Save and Reload All Plugins in Debugger (with plugin debugging on) |

### Context collisions to know

The same keys mean different things depending on focus (Docs, both pages):
- `Ctrl D`: duplicate in the Explorer or viewport, add next-match cursor in the Script Editor.
- `Ctrl U`: ungroup in the viewport or Explorer, remove last cursor in the Script Editor.
- `Ctrl =` / `Ctrl -`: zoom the camera in the viewport, zoom text in the Script Editor.

When a shortcut "does something weird", check which panel has focus.

## 4. Settings and shortcuts for teams

Because everything is per machine, a team drifts unless you make the setup a file in the repo (Rule of thumb):

```text
tools/studio-setup/
  CustomRibbonTabs/        # team tab JSON, copy to %LOCALAPPDATA%\Roblox\<userID>\CustomRibbonTabs
  DefaultInstances.rbxm    # shared configurable defaults
  SETTINGS.md              # the 10 settings everyone must set, with values
  plugins.md               # required plugins and versions
```

A short `SETTINGS.md` beats a long one. Suggested contents:
1. Auto-Recovery Enabled: on, Interval 5.
2. Output Show Context and Show Source: on.
3. Format On Type/Paste: off if StyLua is the formatter.
4. Indent: Tabs, width 4 (match `stylua.toml`).
5. LoadUserPluginsInRunModes: off.
6. Respect Studio shortcuts when game has focus: decide per project and write it down.
7. Instance Defaults Dir: the repo folder.
8. Script Sync auto-resume: on, conflicted sync: Do not resume.
9. Network emulation: zero.
10. Theme: anything, but plugins must handle both.

A one-time Command Bar check that prints the values that matter (read-only, so it is safe):

```lua
-- Command Bar: print selected Studio settings. Reading is allowed; most are set in the dialog.
local s = settings().Studio
for _, name in {
	"Auto-Recovery Enabled",
	"Auto-Recovery Interval (Minutes)",
	"LoadUserPluginsInRunModes",
	"Format On Type",
	"Format On Paste",
	"Indent Using Spaces",
	"Tab Width",
	"Respect Studio shortcuts when game has focus",
} do
	local ok, value = pcall(function()
		return (s :: any)[name]
	end)
	print(name, ok and value or "(not readable)")
end
```

## 5. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Auto-recovery never checked | Crash loses a day of local work | Verify the AutoSaves folder fills during a session |
| Editor formatting fighting StyLua | Every save produces whitespace diffs | One formatter only |
| Plugins load during tests | Slower tests, confusing output from plugin code | `LoadUserPluginsInRunModes` off |
| Studio shortcuts swallow game keys | "My `F` key does nothing in test" | Adjust **Respect Studio shortcuts when game has focus** or rebind |
| Network emulation left on | Every test feels laggy; bugs blamed on code | Zero it after network tests |
| Assuming a teammate has the same settings | "Works on my machine" for tooling and new instances | Settings file in the repo |

## 6. Checklist

- [ ] Auto-recovery on and the folder verified.
- [ ] Output context and source on.
- [ ] One formatter, matching indent settings.
- [ ] Plugin debugging on only for plugin authors.
- [ ] Team setup folder in the repo, applied on every new machine.
- [ ] Shortcut list above printed or pinned for new team members.

## See also

- [[Studio Interface Tour]], [[Explorer Properties and Selection]], [[Command Bar and Studio Scripting]]
- [[Plugins - Using and Writing]], [[External Tooling - Rojo Wally Selene StyLua]]
- [[Version History and Backups]], [[Debugger Breakpoints and Logging]]

## Connected notes
<!-- auto-links:start -->
[[Building a Studio Plugin End to End]] · Links - Roblox Studio · [[Team Create and Collaboration]] · Plugin Development Start Here · Code Pipeline - Rojo Git and CI · Undo and ChangeHistoryService Done Right
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Git and Source Control for Roblox]] · [[Packages and Asset Reuse]] · [[Studio Assistant and AI Tools]] · [[Undo and ChangeHistoryService Done Right]] · [[Code Pipeline - Rojo Git and CI]] · [[Creator Store and Toolbox Safety]]
<!-- related:end -->
