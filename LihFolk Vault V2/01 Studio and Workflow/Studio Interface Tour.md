---
tags: [studio, interface, workflow, beginner, layout]
---
# Studio Interface Tour

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Tuning values during a test -> Copy, Stop, paste; or tune attributes in Edit
> - Avoid: Running a command with the wrong Client/Server toggle -> Check the viewport border colour first: blue client, green server
> - Avoid: Leaving an edit-time preview on -> Every preview tool has an explicit `off` path, used straight after
> - Studio installed and signed in; check for the Update button.
> - Team custom tab JSON copied into `CustomRibbonTabs`; Reload custom tabs.
> - Output: Show Context and Show Source on.
>
> Cost: TL;DR ~170 tok · whole note ~4.5k tok. Read more: ## 2. The top of the window: mezzanine and toolbar · ## 4. The windows you will use every day · ## 9. Common mistakes · ## 10. Checklist: a new machine, ready in fifteen minutes
<!-- tldr:end -->

Roblox Studio is an editor, a test harness, a collaboration client, an asset browser and a script IDE in one window. This note walks the interface the way a senior developer uses it: what each region is for, which data model you are looking at, how to lay it out for different jobs, and the traps that make experienced people lose work. Menu paths and shortcuts were checked against the official Studio docs as of October 2026. Studio updates weekly, so labels drift; where a feature is beta it says so.

Source labels used below:
- **Docs**: create.roblox.com Studio guides and engine reference.
- **Measured**: observed in the reference project (one production game with a large, heavily tooled place).
- **Rule of thumb**: experience, not a documented rule.

---

## 1. One engine, always the latest

Unlike Unity or Unreal, you never pick an engine version. Every live game runs on the current Roblox engine, and Studio should match it (Docs). When Studio is out of date an **Update** button appears in the upper-right corner; clicking it asks you to save and close, then restarts Studio.

Consequences that matter in practice:
- An API you test today is the API your players get today. There is no "lock the engine for release" option. Behaviour changes ship to live games without your involvement, which is why you should read release notes and keep a smoke test (see [[QA Checklists Before Release]]).
- Beta features live under **File > Beta Features**. Enabling one needs **Save** and a Studio restart. A beta can change or disappear; never build a release-critical workflow on one without a fallback.
- Studio's own settings, custom toolbar tabs, saved commands and instance defaults are **per machine**, not per place or per account (Docs for tabs and defaults). A new team member does not inherit your setup unless you share the files (see [[Studio Settings and Shortcuts]]).

## 2. The top of the window: mezzanine and toolbar

The strip at the top is two layers (Docs):

| Region | What lives there |
|---|---|
| **Mezzanine, left** | Testing controls: the mode dropdown (Test, Test Here, Run, Server & Clients, Team Test), the Play button, and during a test Pause, Step, Stop and the Client/Server toggle. See [[Testing Modes - Play Run and Multi-Client]]. |
| **Mezzanine, centre** | The tool tabs. Defaults: **Home**, **Model**, **Avatar**, **UI**, **Script**, **Plugins**, plus any custom tabs. |
| **Mezzanine, right** | Collaboration (the **Collaborate** button and collaborator avatars), sharing, **Assistant**, creator notifications, account. |
| **Toolbar** | The tools of the selected tab. |

What each default tab holds (Docs):

| Tab | Main contents |
|---|---|
| Home | Transform tools, part inserter, Color and Material widgets, Group, Lock, Anchor, Terrain Editor |
| Model | Transform tools, Pivot and Align tools, effect and constraint inserters, solid modeling |
| Avatar | Rig builder, Avatar Setup, animation tools, accessory fitting |
| UI | UI object inserters, the Style Editor |
| Script | Script tools, debugger controls, Command Bar, Output |
| Plugins | Your installed and local plugins (see [[Plugins - Using and Writing]]) |

Right-click an empty area of the mezzanine or toolbar for appearance options: **Manage tabs** (show/hide, reorder, delete custom tabs, centre or left alignment), **Collapse toolbar** (toolbar only appears while hovering a tab), **Compact toolbar** (smaller icons, good on laptops) and **Show labels** (Docs).

### Custom tabs are worth the five minutes

Custom tabs let a team put the twenty tools it actually uses on one strip. Create one with the `+` beside the default tabs, or right-click a default tab and choose **Duplicate tab**, then **Add tools** (Docs). Tabs are stored as JSON on each machine:

- Windows: `%LOCALAPPDATA%\Roblox\<userID>\CustomRibbonTabs`
- Mac: `~/Documents/Roblox/<userID>/CustomRibbonTabs`

`RibbonLayout.json` controls order and visibility; every other `.json` file is one tab whose `Name` is the label. After editing the files, right-click the toolbar, **Manage tabs**, then the options menu in that popup, **Reload custom tabs** (Docs). A minimal tab that adds a plugin button looks like this (structure from the docs; replace the ids with your own plugin's):

```json
{
  "Name": "Team",
  "Controls": [
    {
      "Id": "Select",
      "Type": "IconButton",
      "Action": { "Category": "Actions", "DataModel": "Standalone", "ItemId": "Select", "PluginId": "BuilderTools" }
    },
    { "Type": "Separator", "Size": "Large" },
    {
      "Id": "MyStudio_SnapshotTool",
      "Type": "IconButton",
      "Action": { "Category": "Actions", "DataModel": "Edit", "ItemId": "MyStudio_SnapshotTool", "PluginId": "0000000000", "PluginType": "Cloud" }
    }
  ]
}
```

**Rule of thumb.** Commit your team tab JSON to the repository (see [[Git and Source Control for Roblox]]) and copy it into place in your onboarding script. Some windows, such as the **Drafts** window for script drafts, are not on any default tab and must be added to a custom tab to be reachable (Docs, see [[Team Create and Collaboration]]).

## 3. The 3D viewport

The viewport shows `Workspace`. Camera controls (Docs):

| Input | Action |
|---|---|
| `W` `A` `S` `D` | Move forward, left, back, right |
| `Q` `E` | Down, up |
| `Shift` + movement | Change camera speed |
| `F` | Focus the selection |
| Right mouse drag | Look around |
| Middle mouse drag | Pan |
| Wheel, `Ctrl =`, `Ctrl -` (or `O`) | Zoom |
| `,` `.` | Rotate left/right, or orbit the focused object after `F` |
| Right mouse + wheel | Change camera scroll speed (beta: **New Studio Camera Controls**) |

Selection in the viewport (Docs): hover outlines, click selects, `Shift`/`Ctrl` adds, and **`Alt`-click cycles** to the next object behind the current one. Alt-cycling is the fastest way to grab a part hidden behind a decorative mesh without hunting in the Explorer.

The **Visualization Options** button in the viewport's upper-right corner toggles overlays for on-screen UI, light guides, physics, pathfinding and more, and shows the camera speed (Docs). Two worth knowing early:
- **UI overlay off** when building the world, so a HUD in `StarterGui` does not hide the scene. In the reference project, tools that capture screenshots stored and restored `StarterGui.ShowDevelopmentGui` for the same reason (Measured).
- **Physics and constraint visualisation** when debugging assemblies (see [[Physics Assemblies and Constraints]]).

**Measured gotcha.** Code that positions the edit camera (`workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable` plus a CFrame) leaves the camera stuck in Scriptable mode, and the viewport no longer responds to WASD. Restore `CameraType = Enum.CameraType.Custom` when the tool finishes. In the reference project an immediate restore was sometimes overridden by other Studio tooling, so the reliable form was a short `task.delay(0.6, ...)` followed by a check.

## 4. The windows you will use every day

All of these open from the **Window** menu; the most common also sit on the Home or Script tab (Docs).

| Window | Purpose | Deeper note |
|---|---|---|
| **Explorer** | The data model tree: services, instances, search | [[Explorer Properties and Selection]] |
| **Properties** | Properties, Tags and Attributes of the selection | [[Explorer Properties and Selection]] |
| **Toolbox** | Creator Store, Inventory, Recent, Creations | [[Creator Store and Toolbox Safety]] |
| **Asset Manager** | The game's places, images, meshes, audio, packages; bulk import | [[Packages and Asset Reuse]] |
| **Output** | Errors, `print`, `warn`, engine messages; filter by type and context (Client, Server, User Plugin); `Ctrl K` clears | [[Debugger Breakpoints and Logging]] |
| **Command Bar** | Run Luau against the current data model; `Ctrl 9` focuses it | [[Command Bar and Studio Scripting]] |
| **Script Editor** | Tabs for open scripts; autocomplete, type checking, find all | [[Luau Type System and Strict Mode]] |
| **Version History** | Saved and published versions with notes | [[Version History and Backups]] |
| **Activity History** | Log of settings, publishes, permission changes, draft commits | [[Version History and Backups]] |
| **Comments**, **Live Collaborators**, **Drafts** | Team features | [[Team Create and Collaboration]] |
| **Device Simulator**, **Network Simulator** | Device and network emulation in tests | [[Testing Modes - Play Run and Multi-Client]] |
| **Script Profiler**, **MicroProfiler**, **Developer Console** (`F9` in a test) | Performance and runtime diagnostics | [[MicroProfiler Guide]], [[Developer Console and Stats]] |
| **Material Generator**, Texture Generator | AI-assisted materials and textures | [[Studio Assistant and AI Tools]] |

Output details that save time (Docs): **Show Context** labels each line Client or Server, **Show Source** gives script and line, and Output colours client lines blue and server lines green during a solo test. Turn on Show Context permanently; half of all "why did this not run" questions are answered by which side printed.

## 5. Which data model am I looking at?

This is the single most important concept in the interface, and the one beginners never get told.

| Situation | Data models that exist | What the Explorer shows |
|---|---|---|
| Editing (no test running) | **Edit** | The place as it will be saved |
| Test / Test Here | **Server** and **Client** (separate simulations) | Whichever the Client/Server toggle selects. Client view: blue viewport border. Server view: green border (Docs) |
| Run | **Server** only, no player | The running server |
| Server & Clients | A separate Studio window per client plus one for the server | Each window shows its own data model |

Rules that follow from this:
1. **Changes made during a test are thrown away on Stop.** Stop "resets all objects and instances to how they were before the playtest" (Docs). Tuning a light for ten minutes during a test and pressing Stop loses all of it. To keep a runtime change, copy the instance during the test, Stop, then paste it in Edit (paste at original location if position matters, see [[Explorer Properties and Selection]]).
2. **Script edits are the exception you should not rely on.** The setting **Always Save Script Changes** makes Studio "attempt to transfer" script changes made during a test back to the place (Docs). Attempt is the key word. Edit scripts in Edit mode.
3. **The Command Bar runs against the data model you are viewing.** During a solo test, flip the Client/Server toggle before running a command, or you will inspect the wrong side.
4. **Edit-time previews are real edits.** A tool that changes `Lighting` or `Atmosphere` in Edit to preview a look has changed the place. In the reference project a weather controller read the place's Atmosphere as its base when Play started, so a preview left on silently became the game's default air (Measured). Switch previews off immediately after use, and in a shared place remember everyone sees them (see [[Team Create and Collaboration]]).

## 6. Arranging windows

Studio's docking (Docs):
- **Move** a window by dragging its header; drop targets appear.
- **Group** windows as tabs by dropping on the centre of a populated region's position selector.
- **Pin** a window or group to an edge with its collapse button; it then opens on click and collapses when you click elsewhere.
- **Float** a window by dropping it without choosing a target.

Layouts that work (Rule of thumb):

| Role | Layout |
|---|---|
| Builder | Viewport as large as possible; Explorer and Properties grouped and pinned right; Toolbox pinned left; Output pinned bottom |
| Scripter | Script tabs in the main area, viewport as a small docked pane, Explorer left, Output and Command Bar bottom, Properties pinned |
| UI | Viewport plus Device Simulator open, Explorer showing `StarterGui`, Properties always visible, Style Editor floating |
| Technical artist / tools | Two monitors: viewport and Output on one, Explorer, Properties, Command Bar and Script Editor on the other |

A second monitor is the biggest single productivity upgrade for Studio work. Floating windows on the second screen keep their position between sessions.

## 7. The File menu, decoded

| Item | What it does | Note |
|---|---|---|
| **Save to Roblox** | Uploads the place to the cloud as a new place version | Not published: players still get the last published version |
| **Save to Roblox with Notes** (`Ctrl Alt S`) | Same, with a version name and notes | Use it for every meaningful checkpoint (see [[Version History and Backups]]) |
| **Publish** | Makes this version the live one; version notes are required | Live servers keep the old version until restarted (see [[Release Process and Rollbacks]]) |
| **Publish As / Save to Roblox As** | Target another game or place | How you add a place to a game or overwrite one (see [[Places Universes and Experience Settings]]) |
| **Save to File / Download a Copy** | Local `.rbxl` (binary) or `.rbxlx` (XML) | Local backups and external tooling (Docs) |
| **Experience Settings** | Game-wide settings dialog | See [[Places Universes and Experience Settings]] |
| **Beta Features** | Opt-in features, restart required | |
| **Customize Shortcuts** | Rebind actions | See [[Studio Settings and Shortcuts]] |
| **Studio Settings** (`Alt S`) | Per-machine preferences | See [[Studio Settings and Shortcuts]] |

Note the place size limit: Roblox supports places up to 100 MB (104,857,600 bytes); beyond that Save and Publish can fail (Docs). Export to `.rbxl` to estimate size.

## 8. When Studio itself gets slow

Studio performance is not game performance, but a slow editor slows the whole team. The main causes, in the order the reference project met them:

| Cause | Symptom | Measured in the reference project | Fix |
|---|---|---|---|
| Instance count | Viewport and Explorer lag even when nothing moves | A place at about 1.07 million instances ran Studio at roughly 15 fps. Removing backup folders and archives took ServerStorage from 1.96M to about 420k instances | Do not keep backups inside the place; export to `.rbxm` and rely on version history. See [[Version History and Backups]] and [[Case Study - Instance Cleanup and Place Size]] |
| Huge flat folders | Expanding a folder freezes the Explorer | Folders with tens of thousands of children | Nest by category; keep any one folder in the low thousands (Rule of thumb) |
| Whole-world scans in tools | A command takes seconds | `workspace:GetDescendants()` took seconds in a large place | Search the top-level children you need, or use tags (see [[CollectionService Patterns]]) |
| Long synchronous commands | UI stops repainting; with several people or tools on one Studio, everyone waits | A rule of at most about 1.5 s per tool call, one call at a time | Budgeted, resumable loops (see [[Command Bar and Studio Scripting]]) |
| CPU contention from outside | Studio freezes for minutes | Around 18 heavy background processes pinned the CPU and froze Studio for about 25 minutes | Cap parallel external jobs and their thread counts |
| Terrain writes | Viewport re-meshes for seconds after a big write | Screenshots taken right after a big terrain write showed half-built terrain | Move the camera and wait a few seconds before judging terrain |

## 9. Common mistakes

| Mistake | What happens | Instead |
|---|---|---|
| Tuning values during a test | Work lost on Stop | Copy, Stop, paste; or tune attributes in Edit |
| Running a command with the wrong Client/Server toggle | Inspecting or changing the wrong side | Check the viewport border colour first: blue client, green server |
| Leaving an edit-time preview on | The preview ships as the default | Every preview tool has an explicit `off` path, used straight after |
| Treating Save as Publish | Players never see the change | Publish, then restart servers when needed |
| Building on a beta feature | Feature changes under you | Keep a non-beta fallback |
| One giant `Workspace` with backups in `ServerStorage` | Studio crawls | Export old content, delete it, rely on version history |
| Hunting objects in a 3D clutter | Slow, error-prone selection | `Alt`-click cycling, or Explorer search (`is:`, `tag:`) |

## 10. Checklist: a new machine, ready in fifteen minutes

- [ ] Studio installed and signed in; check for the Update button.
- [ ] Team custom tab JSON copied into `CustomRibbonTabs`; **Reload custom tabs**.
- [ ] Output: **Show Context** and **Show Source** on.
- [ ] Studio Settings reviewed (auto-recovery, script analysis, theme): see [[Studio Settings and Shortcuts]].
- [ ] Explorer shows the hidden services you need (right-click, **Show Services...**).
- [ ] Shared `DefaultInstances.rbxm` installed if the team uses configurable defaults.
- [ ] Required plugins installed from the team list (see [[Plugins - Using and Writing]]).
- [ ] External tooling installed if the project uses it (see [[External Tooling - Rojo Wally Selene StyLua]]).
- [ ] Layout arranged for your role; second monitor used.
- [ ] You know where Version History is (**Window > Version History**) before you need it.

## See also

- [[Explorer Properties and Selection]], [[Studio Settings and Shortcuts]], [[Command Bar and Studio Scripting]]
- [[Testing Modes - Play Run and Multi-Client]], [[Team Create and Collaboration]], [[Version History and Backups]]
- [[Places Universes and Experience Settings]], [[Studio Assistant and AI Tools]]
- [[Safe Changes in a Shared Place]], [[Team Roles and Workflows]]
- Animation section: [[Testing Animations in Studio]], [[Studio Tooling Architecture]]

## Connected notes
<!-- auto-links:start -->
[[Links - Roblox Studio]] · [[Building a Studio Plugin End to End]] · [[Selection Editing and Bulk Tools]] · [[Team Create Permissions and Workflows]] · [[Links - Team Create]] · [[Roblox Studio Assistant]]
<!-- auto-links:end -->
