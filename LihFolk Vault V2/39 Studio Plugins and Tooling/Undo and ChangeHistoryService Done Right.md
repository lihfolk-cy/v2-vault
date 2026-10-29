---
tags: [studio, plugins, undo, changehistoryservice, tooling, safety, type/guide, area/studio, level/intermediate, api/ChangeHistoryService]
---
# Undo and ChangeHistoryService Done Right

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Using `SetWaypoint` in new code -> Recordings
> - Avoid: Returning early on error without finishing -> `Cancel` on every failure path
> - Avoid: Yielding (HTTP, `task.wait`, `WaitForChild`) inside a recording -> Compute first, then a synchronous write block
> - All writes go through one helper that begins, commits, and cancels on error.
> - `recoverStale` runs at startup.
> - No yields inside recordings; computation happens first.
>
> Cost: TL;DR ~150 tok · whole note ~5.1k tok. Read more: ## 3. The recording helper every plugin should have · ## 4. Live edits: drags, sliders and brushes · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

Users judge a Studio tool by one test before any other: press `Ctrl Z` after using it. If the change comes back cleanly in one step, the tool feels native. If undo takes forty presses, or reverts half the change, or reverts something the user did before the tool ran, the tool is uninstalled. `ChangeHistoryService` is the API behind that test. The docs are short, and the parts they leave out are where plugins go wrong.

This note covers the recording model, every member and what it really does, crash-safe recordings, live drags with `Append`, resyncing your UI on undo and redo, what recordings do not capture, and why a good team tool also needs a revert path that does not depend on undo at all. It builds on the short treatment in [[Plugins - Using and Writing]] and the shared-place warning in [[Command Bar and Studio Scripting]].

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**, **unverified**.

---

## 1. The model: a stream of changes cut into waypoints

The docs describe the history as "a stream of property changes" that waypoints cut into undoable steps. Modern plugins do not cut the stream by hand; they **record**:

1. `TryBeginRecording(name, displayName?)` returns an identifier string, or `nil` on failure.
2. The plugin makes its changes.
3. `FinishRecording(identifier, operation, finalOptions?)` closes the recording.

The docs say plugin developers **must** use recordings, and that you must begin a recording before making changes "to avoid future warnings or errors". The older `SetWaypoint(name)` is marked "deprecated soon".

Every member, with what the docs actually promise:

| Member | Behaviour (Roblox docs) |
|---|---|
| `TryBeginRecording(name, displayName?) -> string?` | Returns `nil` if this plugin already has a recording in progress, or if the user is in a solo playtest |
| `FinishRecording(id, op, finalOptions?)` | `Commit` adds a waypoint; `Cancel` discards and **reverts** the captured changes and **ignores the identifier**; `Append` merges into the waypoint immediately before. Errors if no recording is in progress, or if the op is not `Cancel` and the id does not match. No effect while disabled or during an undo or redo |
| `IsRecordingInProgress(id?) -> boolean` | Without an id: any recording by this plugin; with an id: only that one |
| `GetCanUndo() / GetCanRedo()` | A boolean, plus the waypoint name when true; false when the service is disabled (always at runtime) |
| `Undo() / Redo()` | Step the history; fire `OnUndo` / `OnRedo` with the waypoint name; error if nothing to undo/redo, if a play is in progress, or if disabled |
| `ResetWaypoints()` | Collapses all history into a single `base` waypoint: nothing left to undo or redo |
| `SetEnabled(state)` | `false` clears the undo/redo list; turning it back on does not restore it |
| `OnRecordingStarted(name, displayName?)` | Fires when a recording starts |
| `OnRecordingFinished(name, displayName?, id?, op, finalOptions?)` | Fires on finish, with the operation and your `finalOptions` table |
| `OnUndo(waypoint) / OnRedo(waypoint)` | Fire after the step, whether the user or code triggered it |

And one global fact: `ChangeHistoryService` is not enabled at runtime, so calling it in a running experience does nothing (Roblox docs).

## 2. Names: `name` versus `displayName`

`name` is "suitable for logging and coding purposes"; `displayName` is what users see (Roblox docs, `OnRecordingFinished` parameters). Use a stable machine name with a prefix (`"TerrainBrush.Paint"`) and a human display name (`"Paint terrain"`). The machine name is what you match in `OnUndo` to know whether the step being undone was yours. If you only pass a display name and later localise it, your matching breaks.

## 3. The recording helper every plugin should have

The basic example in the docs commits on success and simply returns if a recording could not start. Real plugins need three more things: cancel on error, refuse to yield, and recover from a recording left open by a previous load of the plugin.

```lua
--!strict
-- Recorder: the only way this plugin writes to the data model.
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Recorder = {}

-- Call once at startup. A reload does not cancel an open recording (Roblox docs), and Cancel
-- ignores the identifier, so we can close whatever our previous load left open.
function Recorder.recoverStale(): boolean
	if ChangeHistoryService:IsRecordingInProgress() then
		ChangeHistoryService:FinishRecording("", Enum.FinishRecordingOperation.Cancel)
		return true
	end
	return false
end

export type Result = { ok: boolean, message: string }

-- Runs fn inside one recording. fn must not yield: if it does, we treat it as a bug and cancel.
function Recorder.run(name: string, displayName: string, fn: () -> string): Result
	local id = ChangeHistoryService:TryBeginRecording(name, displayName)
	if not id then
		return { ok = false, message = "could not start a recording (playtest running, or one already open)" }
	end

	local thread = coroutine.create(fn)
	local resumed, result = coroutine.resume(thread)
	local finishedWithoutYield = coroutine.status(thread) == "dead"

	if resumed and finishedWithoutYield then
		ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Commit)
		return { ok = true, message = tostring(result) }
	end

	-- Error, or fn yielded. Either way, revert everything this recording captured.
	ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Cancel)
	if not resumed then
		return { ok = false, message = "failed and reverted: " .. tostring(result) }
	end
	-- The yielded thread will resume later and write outside any recording. Stop it from
	-- doing harm: close it so it never resumes.
	coroutine.close(thread)
	return { ok = false, message = "operation yielded inside a recording; reverted" }
end

return Recorder
```

Why each part exists:

- **`recoverStale` at startup.** The docs' own suggestion is to store the last recording id in an attribute so a reloaded plugin can cancel it. Because `Cancel` ignores the identifier, the simpler approach above works too: if this plugin has a recording open at startup, it can only be a leftover. Run it before creating any UI.
- **Why the no-yield rule.** A recording captures changes to the data model between begin and finish. It is not documented whether changes made by the **user** or other plugins during an open recording are captured into yours (**unverified**), but the safe assumption is that they can be, or that they interleave with yours in ways that make your waypoint revert more or less than you meant. Rule of thumb: compute everything first (raycasts, scans, maths, HTTP), then open the recording, apply the writes synchronously, and close it in the same frame.
- **Cancel on error.** A half-applied bulk edit is worse than none. Cancel reverts the captured changes, so a failing tool leaves the place exactly as it was. This is the main reason to prefer recordings over hand-written cleanup.

`coroutine.close` on a suspended coroutine is standard Luau. If `fn` yielded through `task.wait`, the task scheduler holds a reference and would resume it; closing it first makes that resume a no-op (rule of thumb; test it in your Studio version).

### Compute, then record

```lua
--!strict
-- Example: snap selected parts to the ground. All raycasts happen before the recording.
local Selection = game:GetService("Selection")
local Recorder = require(script.Parent.Recorder)

local function snapToGround(): Recorder.Result
	local targets: { { part: BasePart, cf: CFrame } } = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local selected = Selection:Get()
	params.FilterDescendantsInstances = selected

	for _, inst in selected do
		if inst:IsA("BasePart") and not inst.Locked then
			local origin = inst.Position
			local hit = workspace:Raycast(origin, Vector3.new(0, -500, 0), params)
			if hit then
				local lift = inst.Size.Y / 2
				local newPos = Vector3.new(origin.X, hit.Position.Y + lift, origin.Z)
				table.insert(targets, { part = inst, cf = inst.CFrame - origin + newPos })
			end
		end
	end

	return Recorder.run("GroundSnap.Snap", ("Snap %d parts to ground"):format(#targets), function(): string
		for _, t in targets do
			t.part.CFrame = t.cf
		end
		return ("snapped %d"):format(#targets)
	end)
end
```

The display name includes the count, so the user can see in Studio's undo history what one press will revert. That is a small kindness that makes bulk tools feel safe. (The lift ignores rotation: correct for upright parts, approximate for rotated ones. [[Selection Editing and Bulk Tools]] handles bounding boxes properly.)

## 4. Live edits: drags, sliders and brushes

Interactive tools change the place continuously: a gizmo drag, a slider in your panel, a terrain brush stroke. Committing one waypoint per frame gives the user 200 undo steps for one gesture. Three patterns, in order of preference (rule of thumb):

**A. One recording per gesture, writes only on frames.** Begin on mouse down, apply changes as the mouse moves, finish with `Commit` on mouse up. This gives exactly one undo step per gesture. The risk is the open recording during the gesture; it is acceptable because the user is busy with your tool, and short (a second or two). Always finish on every exit path: mouse up, `Deactivation`, widget close, `Unloading`.

**B. Commit, then Append.** On the first change of a gesture, record and `Commit`. On each later change, record a tiny recording and finish with `Append`, which "merges the recording into the waypoint that immediately precedes it" (Roblox docs). No recording stays open between frames. The catch: if anything else commits a waypoint mid-gesture, your next `Append` merges into **that** waypoint, not yours. Check `GetCanUndo()` returns your waypoint name before appending, and start a new `Commit` if it does not.

**C. Preview outside history, commit once.** Show the change on a preview copy (parented to `CoreGui` so it is not saved), and only apply to the real instances on release, in one recording. Best for expensive or destructive changes, and the only safe option when a gesture could last long.

```lua
--!strict
-- Pattern A: one waypoint per slider drag. Every exit path finishes the recording.
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local DragSession = {}
DragSession.__index = DragSession

export type DragSession = typeof(setmetatable({} :: { id: string? }, DragSession))

function DragSession.new(): DragSession
	return setmetatable({ id = nil }, DragSession)
end

function DragSession.begin(self: DragSession, name: string, displayName: string): boolean
	if self.id then
		return true
	end
	self.id = ChangeHistoryService:TryBeginRecording(name, displayName)
	return self.id ~= nil
end

function DragSession.finish(self: DragSession, commit: boolean)
	local id = self.id
	if not id then
		return
	end
	self.id = nil
	if ChangeHistoryService:IsRecordingInProgress(id) then
		ChangeHistoryService:FinishRecording(
			id,
			if commit then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	end
end

return DragSession
```

Wire `finish(true)` to mouse up and `finish(false)` to Escape, `plugin.Deactivation`, `BindToClose` and `Unloading`. If you forget one exit path, the next `TryBeginRecording` returns `nil` and your plugin looks broken until reloaded, which is exactly the "plugin stopped working" bug users report.

## 5. Keeping your UI in sync with undo and redo

Your panel often shows state derived from the place: a list of fixed items, a slider showing a property, a "3 issues left" counter. When the user presses `Ctrl Z`, the place changes under your panel. Two approaches:

- **Derive, do not store.** Read the state from the instances on refresh, using the dirty-flag refresher from [[Plugin UI with DockWidgets]]. Then undo just marks the panel dirty. This is the robust default.
- **Listen to `OnUndo` / `OnRedo`.** They fire with the waypoint name after the step, whoever triggered it (Roblox docs). Match your machine-name prefix and mark dirty. Useful when refreshing is expensive and you only want to refresh after your own steps are undone.

```lua
--!strict
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local PREFIX = "GroundSnap."

local function watchHistory(markDirty: () -> ()): { RBXScriptConnection }
	local function onStep(waypoint: string)
		if string.sub(waypoint, 1, #PREFIX) == PREFIX then
			markDirty()
		end
	end
	return {
		ChangeHistoryService.OnUndo:Connect(onStep),
		ChangeHistoryService.OnRedo:Connect(onStep),
	}
end
```

Whether `OnUndo` passes the machine name or the display name is not stated beyond "the name of the action that was undone, matching the name that was recorded for that waypoint" (Roblox docs). Test it once in your Studio version and match accordingly; matching both is cheap.

Never cache instance references across an undo without checking them: undoing an insert removes the instance (its `Parent` becomes `nil`), and redo brings it back. A list that holds stale references will act on detached instances.

## 6. What undo does not cover

Recordings capture changes to the data model. Everything else your tool does is outside history, and users do not know that. Rule of thumb list:

| Side effect | Undone by Ctrl Z? | What to do |
|---|---|---|
| Property, parent, name, attribute and tag changes on instances | Yes, if inside a recording | Normal case |
| Instances created or destroyed | Yes, if inside a recording | Normal case |
| `plugin:SetSetting` | No | Treat settings as preferences, not data |
| Files written through a local HTTP bridge | No | Make them additive, versioned ([[Studio Plugins and Local HTTP Bridges]]) |
| Assets uploaded, packages published | No | Confirm before; never inside a "preview" |
| Script edits through `ScriptEditorService:UpdateSourceAsync` on an open document | Goes through the editor (**unverified** how it interacts with the history) | Test; keep source edits separate from instance edits |
| Terrain writes | Recorded by Studio's own terrain tools; for API writes, **unverified** | Snapshot with `Terrain:CopyRegion` before |

For script edits in particular, the safe procedure in [[Command Bar and Studio Scripting]] (size check, compile check, safety copy, changed-underneath check) remains the real protection, not undo.

## 7. Destructive members: almost never call them

- **`Undo()` / `Redo()` from code.** A plugin that calls `Undo()` undoes the last waypoint in the history, which may belong to the user or another plugin. Measured in the reference project: in a shared Studio session, one undo issued to recover a terrain change walked about 40 waypoints back and rolled back other people's changes; new commands then wiped the redo history. The rule became "never call undo in a shared place". For a plugin, the equivalent rule is: to revert your own operation, use `Cancel` while the recording is open, or a stored-data revert afterwards, never `Undo()`.
- **`ResetWaypoints()`.** Wipes the user's entire undo history. No plugin has the right to do that silently.
- **`SetEnabled(false)`.** Clears the list, and turning it back on does not restore it (Roblox docs). Some old plugins disabled history around huge operations "for speed". Do not: the user loses every step they had.

## 8. Shared places and the revert-from-data pattern

The history is a linear list, and in a session where several actors write (several tools driving one Studio, or a human plus an automated agent) "undo the last step" means "undo whoever wrote last". In Team Create each person has their own Studio; whether undo histories are strictly per user is not documented (**unverified**), and undoing your step still restores old values on instances a teammate may have changed since. See [[Safe Changes in a Shared Place]] and [[Team Create and Collaboration]].

So a team-grade bulk tool offers two ways back:

1. **Undo** (recordings), for the solo user who wants `Ctrl Z` to work.
2. **Revert from stored data**, which works hours later and after interleaved edits: store the original values in attributes (the Pre-attribute pattern in [[Explorer Properties and Selection]]), or in a snapshot folder or file, and provide a "Revert" button that restores from them. Put the revert inside its own recording too, so it is itself undoable.

The cost of option 2 is clutter: attributes left on thousands of instances. Give users a "Accept and clear backups" button that removes them once they are happy, inside a recording.

## 9. Diagnosing undo bugs

| Symptom | Likely cause | Check |
|---|---|---|
| Plugin "stops working" until reload | Recording left open on some exit path | `IsRecordingInProgress()` from the Command Bar is not your plugin's context; add a debug button that prints it |
| One undo reverts only part of an operation | Writes happened after `FinishRecording` (a deferred callback, a yield) | Move all writes inside the synchronous block |
| One undo reverts the user's earlier work too | Your recording was open while the user edited, or you used `Append` onto their waypoint | Shorten recordings; verify the previous waypoint name before `Append` |
| Nothing to undo after using the tool | Wrote outside any recording, or during a playtest | Route all writes through the Recorder; check `TryBeginRecording` result |
| Warnings about changes outside recordings | Writes before `TryBeginRecording` | Same |
| Undo works for you, not for teammates' edits you reverted | Expected: history is local to a session | Revert from stored data |

`OnRecordingStarted` and `OnRecordingFinished` are useful during development: log them to see every recording in the session, including other plugins', and spot one that never finishes.

## 10. Common mistakes

| Mistake | Fix |
|---|---|
| Using `SetWaypoint` in new code | Recordings |
| Returning early on error without finishing | `Cancel` on every failure path |
| Yielding (HTTP, `task.wait`, `WaitForChild`) inside a recording | Compute first, then a synchronous write block |
| One waypoint per frame during a drag | One recording per gesture, or Commit then Append |
| Calling `Undo()` to revert your own change | `Cancel` while open; stored-data revert after |
| Disabling history for speed | Never; slice the work into several recordings instead |
| Caching instances across undo | Re-validate `Parent` before acting |

## 11. Checklist

- [ ] All writes go through one helper that begins, commits, and cancels on error.
- [ ] `recoverStale` runs at startup.
- [ ] No yields inside recordings; computation happens first.
- [ ] Machine `name` with a prefix, human `displayName` with counts.
- [ ] Every interactive gesture produces exactly one undo step; every exit path finishes it.
- [ ] Panels derive state from instances, or refresh on `OnUndo`/`OnRedo` for your prefix.
- [ ] No calls to `Undo`, `Redo`, `ResetWaypoints` or `SetEnabled`.
- [ ] Bulk tools also offer a revert from stored data, itself recorded.
- [ ] Side effects outside the data model are documented in the UI.

## See also

- [[Plugin Development Start Here]], [[Building a Studio Plugin End to End]], [[Selection Editing and Bulk Tools]]
- [[Plugins - Using and Writing]], [[Command Bar and Studio Scripting]], [[Explorer Properties and Selection]]
- [[Safe Changes in a Shared Place]], [[Version History and Backups]], [[Safety Rules for AI Agents in Studio]]

## Connected notes
<!-- auto-links:start -->
[[Studio Settings and Shortcuts]] · Batch Processing Tools in Studio · Official Docs - Asset Creation · Studio Interface Tour · Working with AI Assistants in Studio · Roblox Studio Assistant
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Batch Processing Tools in Studio]] · [[Plugin Security and Permissions]] · [[Writing Your Own MCP Server]] · [[Studio Interface Tour]] · [[Roblox Studio MCP Server]] · [[Publishing Selling and Updating Plugins]]
<!-- related:end -->
