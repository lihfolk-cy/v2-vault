---
tags: [studio, plugins, selection, bulk-editing, tooling, building, type/guide, area/studio, level/intermediate, api/ChangeHistoryService, api/CollectionService]
---
# Selection Editing and Bulk Tools

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No ancestor normalisation -> Normalise roots first
> - Avoid: Moving parts of a model individually -> `PivotTo` on roots
> - Avoid: Editing locked parts silently -> Skip locked; report the count
> - Selection read once per operation, filtered by class, normalised to roots and parts.
> - Locked parts skipped and counted; packages detected.
> - Models moved by pivot; operations choose roots or parts deliberately.
>
> Cost: TL;DR ~150 tok · whole note ~5.4k tok. Read more: ## 2. Normalising a selection: the step everyone skips · ## 7. Three bulk operations done properly · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

Most useful plugins are some version of "do X to everything I selected": align, distribute, randomise rotation, replace with a prefab, set a property across hundreds of parts, snap to ground, rename by pattern. The `Selection` service makes the first version of such a tool a ten-line script. Making it correct is harder, because a selection is a messy thing: it mixes models and their own children, contains locked and anchored and welded things, includes instances inside packages, can be fifty thousand items long, and changes while your tool is running.

This note covers reading the selection correctly, the normalisation every bulk tool needs, respecting the user's Studio settings (grid, rotation increment, local space), click-to-pick tools with the plugin mouse, in-viewport handles, and three complete operations. It builds on the Selection API section of [[Explorer Properties and Selection]] and the undo patterns in [[Undo and ChangeHistoryService Done Right]].

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**, **unverified**.

---

## 1. The Selection service, precisely

| Member | Behaviour (Roblox docs) |
|---|---|
| `Get()` | Array of selected instances; empty if none. Only usable in plugins or the Command Bar |
| `Set(instances)` | Replaces the selection; fires `SelectionChanged` unless the new set is identical |
| `Add(instances)`, `Remove(instances)` | Modify the selection |
| `SelectionChanged` | Fires on change; does **not** pass the new selection, call `Get()` |
| `SelectionThickness` | Read-only float, default 0.02; the outline thickness Studio draws, for matching custom overlays |

Things the docs do not promise, so do not rely on them (rule of thumb):

- **Order.** Whether `Get()` returns items in click order is not documented. Tools that need an order ("align to the first selected", "distribute from first to last") should either define order themselves (sort by position along an axis, by name) or ask the user to mark the reference explicitly, for example with a "Set as reference" button that remembers one instance.
- **Uniqueness by class.** The selection can contain anything: services, scripts, GUI objects, attachments, constraints, terrain. Filter by class at the start of every tool.
- **Stability.** Between your tool reading the selection and writing, the user may have clicked elsewhere. Read the selection once per operation, at the moment the user triggers it.

### The shared-place rule still applies

Measured in the reference project: in a shared session (several collaborators or automated tools on one Studio), the selection is whatever someone last clicked, and tools that iterated `Selection:Get()` acted on the wrong objects. The rule was "find things by name or tag, never by Selection", for anything automated. A selection-driven plugin is the legitimate exception: a human selects, looks, and presses the button within seconds. Do not build automation (agents, scheduled jobs, HTTP-triggered commands) on top of selection. See [[Safe Changes in a Shared Place]].

## 2. Normalising a selection: the step everyone skips

Users routinely select a model **and** some of its children (Ctrl-click in the Explorer, or box-select in the viewport, which picks parts inside already-selected models). A naive tool that moves every selected item moves the children twice: once with the model, once on their own. A naive tool that expands each item to its descendants processes the children twice.

Normalise first:

```lua
--!strict
-- Normalise a raw selection into a clean set of roots and a clean set of parts.

export type Normalised = {
	roots: { Instance }, -- selected items with no selected ancestor
	parts: { BasePart }, -- unique BaseParts within the roots, unlocked unless allowed
	skippedLocked: number,
}

local function isAncestorSelected(inst: Instance, set: { [Instance]: boolean }): boolean
	local p = inst.Parent
	while p do
		if set[p] then
			return true
		end
		p = p.Parent
	end
	return false
end

local function normalise(raw: { Instance }, includeLocked: boolean?): Normalised
	local set: { [Instance]: boolean } = {}
	for _, inst in raw do
		set[inst] = true
	end

	local roots: { Instance } = {}
	for _, inst in raw do
		if inst.Parent ~= nil and not isAncestorSelected(inst, set) then
			table.insert(roots, inst)
		end
	end

	local seen: { [BasePart]: boolean } = {}
	local parts: { BasePart } = {}
	local skipped = 0
	local function consider(inst: Instance)
		if inst:IsA("BasePart") and not seen[inst] then
			seen[inst] = true
			if inst.Locked and not includeLocked then
				skipped += 1
			else
				table.insert(parts, inst)
			end
		end
	end
	for _, root in roots do
		consider(root)
		for _, d in root:GetDescendants() do
			consider(d)
		end
	end
	return { roots = roots, parts = parts, skippedLocked = skipped }
end

return normalise
```

Why each rule:

- **Ancestor check** removes the double processing. It costs one walk up the tree per item, which is cheap.
- **`inst.Parent ~= nil`** drops destroyed instances that can linger in a selection briefly.
- **`Locked`** parts cannot be clicked in the viewport, and users lock things precisely so tools leave them alone. Skip them by default and **report the count** ("12 locked parts skipped"), so the user knows why the result looks incomplete.
- **Unique parts** because one part can be reached from several roots only if roots overlap, which the ancestor check already prevents, but the set is cheap insurance against odd hierarchies.

Decide per tool whether it operates on **roots** (move, rotate, replace: models move as units via their pivot) or on **parts** (material, colour, collision: every part individually). Mixing these up is the second most common bulk-tool bug.

## 3. Things inside the selection that need special care

| Inside the selection | Problem | Rule of thumb |
|---|---|---|
| Models | Moving parts individually breaks the model; `PrimaryPart` may be nil | Move roots with `PivotTo`; read with `GetPivot` |
| Welded assemblies | Setting one part's `CFrame` moves the welded assembly in physics, but in Edit welds are not simulated the same way | Move whole models by pivot; for loose welded parts, move all of them by the same delta |
| Packages | Edits to a package copy mark it modified; auto-update may overwrite or conflict | Warn when a root is inside a `PackageLink` ancestor ([[Packages and Asset Reuse]]) |
| Parts in tools or characters | Usually not what the user meant to edit | Skip by default, with a toggle |
| `Terrain` | Selecting Terrain in the Explorer selects the whole terrain object | Exclude from property tools |
| Scripts, UI, attachments | Wrong class for most tools | Filter by class at the start |
| Huge selections (tens of thousands) | `GetDescendants` and property writes take seconds | Show the count and confirm above a threshold |

The package case deserves emphasis. A bulk recolour that touches 300 parts inside 40 package instances creates 40 modified package copies. Depending on the package's settings, that is either exactly what the user wanted or a mess that breaks auto-update. Detect it and ask.

```lua
--!strict
local function packageRootOf(inst: Instance): Instance?
	local p: Instance? = inst
	while p do
		if p:FindFirstChildOfClass("PackageLink") then
			return p
		end
		p = p.Parent
	end
	return nil
end
```

## 4. Respect the user's Studio settings

Users set a grid size, a rotation increment, local or world space, and whether collisions are on, in Studio's toolbar. Tools that ignore these feel foreign. Available to plugins (Roblox docs):

| Setting | Read it from |
|---|---|
| Move grid size (studs) | `plugin.GridSize` or `StudioService.GridSize` |
| Rotation increment (degrees) | `StudioService.RotateIncrement` |
| Local or world space | `StudioService.UseLocalSpace` |
| Collisions toggle | `plugin.CollisionEnabled` |
| Join surfaces mode | `plugin:GetJoinMode()` returns `Enum.JointCreationMode` |
| Active built-in tool | `plugin:GetSelectedRibbonTool()`; switch with `plugin:SelectRibbonTool(tool, position)` |

Read them at the moment of use, not at startup: the user changes them constantly. A "nudge" action that moves by `GridSize` along the camera's nearest axis, or a "randomise rotation" that snaps to `RotateIncrement`, behaves exactly as users expect.

The docs' example reads `GetSelectedRibbonTool` after a `task.wait()` following `SelectRibbonTool`, which suggests the switch is not immediate; do not assume the tool changed in the same frame.

## 5. Click-to-pick tools with the plugin mouse

Some tools need the user to click in the viewport: "click a surface to place", "click two parts to align". The mechanism (Roblox docs):

- `plugin:Activate(exclusiveMouse)` makes your plugin the active one; there are 0 or 1 active plugins at a time, and activating yours fires `Deactivation` on the others.
- `plugin:GetMouse()` returns a `PluginMouse` usable while active: `Hit`, `Target`, `UnitRay`, `TargetFilter`, `Button1Down`, `Move`, `Icon`.
- `plugin.Deactivation` fires when you call `Deactivate()` or another plugin activates. Built-in tools switching also takes the mouse away in practice (rule of thumb).

```lua
--!strict
-- Click-to-pick: the user clicks two parts; the second is aligned to the first's top face.
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function startPickTool(p: Plugin, status: (string) -> ()): () -> ()
	local mouse = p:GetMouse()
	local first: BasePart? = nil
	local conns: { RBXScriptConnection } = {}

	local function stop()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		mouse.Icon = ""
		if p:IsActivated() then
			p:Deactivate()
		end
	end

	p:Activate(true)
	mouse.Icon = "rbxasset://SystemCursors/Cross"
	status("Click the reference part")

	table.insert(conns, mouse.Button1Down:Connect(function()
		local target = mouse.Target
		if not target or target.Locked then
			return
		end
		if not first then
			first = target
			status("Now click the part to align")
			return
		end
		local ref = first :: BasePart
		if target == ref then
			return
		end
		local topY = ref.Position.Y + ref.Size.Y / 2
		local newCf = target.CFrame + Vector3.new(0, topY + target.Size.Y / 2 - target.Position.Y, 0)
		local id = ChangeHistoryService:TryBeginRecording("PickAlign.Stack", "Stack part on reference")
		if id then
			target.CFrame = newCf
			ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Commit)
		end
		status("Done")
		stop()
	end))
	table.insert(conns, p.Deactivation:Connect(function()
		status("Cancelled")
		stop()
	end))

	return stop
end
```

Points worth copying: the tool always restores the cursor, always disconnects, handles being deactivated by someone else, and refuses locked targets. `mouse.Target` respects `TargetFilter`, which you can set to a preview model so the user's clicks pass through your own ghost objects.

For precise picking (ignore glass, ignore your previews, hit only terrain), cast your own ray from `mouse.UnitRay` with `workspace:Raycast` and a `RaycastParams` filter, as in [[Raycasts Shapecasts and Spatial Queries]].

## 6. In-viewport handles

`Handles` (arrows for moving or resizing along faces) and `ArcHandles` (rings for rotation) are GUI adornments with `MouseButton1Down`, `MouseDrag`, `MouseButton1Up`, `MouseEnter` and `MouseLeave` events (Roblox docs). Parent them to `CoreGui` and set `Adornee` to a part; they then render in the viewport without being saved into the place (rule of thumb for `CoreGui`).

The drag events report a distance (for `Handles`) or an angle (for `ArcHandles`) relative to where the drag started. Two rules from experience:

- **Store the starting state on mouse down, apply `start + delta` on every drag.** Accumulating deltas frame by frame drifts and snaps badly.
- **Snap the delta, not the result,** to `GridSize` or `RotateIncrement`, so the object moves in user-sized steps from where it started.
- **One recording per drag** (pattern A in [[Undo and ChangeHistoryService Done Right]]): begin on `MouseButton1Down`, commit on `MouseButton1Up`.

Selection boxes and highlights for your own previews work the same way: `SelectionBox` or `Highlight` parented to `CoreGui`, adorning the target. Match `SelectionThickness` if you want your overlay to look like Studio's.

## 7. Three bulk operations done properly

### 7.1 Replace with prefab

The classic "swap every placeholder for the real model" tool. What naive versions lose: the pivot alignment, attributes and tags on the placeholder, the parent, and names that other scripts reference.

```lua
--!strict
local CollectionService = game:GetService("CollectionService")
local Recorder = require(script.Parent.Recorder) -- from the undo note

export type ReplaceOptions = { keepName: boolean, copyAttributes: boolean, copyTags: boolean }

local function replaceWithPrefab(roots: { Instance }, prefab: PVInstance, opts: ReplaceOptions)
	-- Compute everything first: where each copy goes, what it inherits.
	type Plan = { old: PVInstance, pivot: CFrame, parent: Instance, name: string }
	local plans: { Plan } = {}
	for _, root in roots do
		if root:IsA("PVInstance") and root ~= prefab and not root:IsAncestorOf(prefab) and root.Parent then
			table.insert(plans, { old = root, pivot = root:GetPivot(), parent = root.Parent, name = root.Name })
		end
	end

	return Recorder.run("Replace.Prefab", ("Replace %d with %s"):format(#plans, prefab.Name), function(): string
		local newOnes: { Instance } = {}
		for _, plan in plans do
			local copy = prefab:Clone()
			copy:PivotTo(plan.pivot)
			if opts.keepName then
				copy.Name = plan.name
			end
			if opts.copyAttributes then
				for key, value in plan.old:GetAttributes() do
					copy:SetAttribute(key, value)
				end
			end
			if opts.copyTags then
				for _, tag in CollectionService:GetTags(plan.old) do
					CollectionService:AddTag(copy, tag)
				end
			end
			copy.Parent = plan.parent
			plan.old.Parent = nil -- parented out rather than Destroy so the recording can restore it
			table.insert(newOnes, copy)
		end
		game:GetService("Selection"):Set(newOnes)
		return ("replaced %d"):format(#plans)
	end)
end
```

Two choices to explain. `plan.old.Parent = nil` instead of `Destroy()`: destroying locks the instance's `Parent` property, and while recordings are documented to restore deletions made through the editor, setting the parent to nil is the conservative option for a recorded operation (rule of thumb; Studio's own delete behaves like a reparent for undo purposes, **unverified** at the API level). Selecting the new copies at the end gives the user immediate visual feedback and makes "now nudge them all" a single step.

The guard `not root:IsAncestorOf(prefab)` stops the user from replacing the prefab's own container with copies of itself, which happens when the prefab lives in the selected folder.

### 7.2 Set a property across many parts, with backups

For property edits on hundreds of parts, combine a recording with the Pre-attribute backup from [[Explorer Properties and Selection]], so the edit is undoable now and revertible later.

```lua
--!strict
local function setPropertyWithBackup(parts: { BasePart }, prop: string, value: any): number
	local attr = "Pre_" .. prop
	local changed = 0
	for _, part in parts do
		local current = (part :: any)[prop]
		if current ~= value then
			if part:GetAttribute(attr) == nil then
				-- Attributes accept a limited set of types; store only what fits.
				local t = typeof(current)
				if t == "boolean" or t == "number" or t == "string" or t == "Color3"
					or t == "Vector3" or t == "EnumItem" or t == "CFrame" then
					part:SetAttribute(attr, current)
				end
			end
			(part :: any)[prop] = value
			changed += 1
		end
	end
	return changed
end
```

Run it inside `Recorder.run`. Note the type check: not every property value can be stored as an attribute (Roblox docs list the supported attribute types; `EnumItem` and `CFrame` are supported as of October 2026, but check the list in [[Instances Attributes and Tags]] before relying on others). Skip-if-equal keeps the waypoint small and the count honest.

### 7.3 Distribute along an axis

Distribution needs an order, and the selection does not promise one, so derive it: sort roots by their pivot position along the chosen axis, keep the first and last where they are, and space the rest evenly.

```lua
--!strict
local function distribute(roots: { PVInstance }, axis: Vector3)
	if #roots < 3 then
		return 0
	end
	local items = table.clone(roots)
	table.sort(items, function(a, b)
		return a:GetPivot().Position:Dot(axis) < b:GetPivot().Position:Dot(axis)
	end)
	local first = items[1]:GetPivot().Position:Dot(axis)
	local last = items[#items]:GetPivot().Position:Dot(axis)
	local step = (last - first) / (#items - 1)
	for i = 2, #items - 1 do
		local pivot = items[i]:GetPivot()
		local along = pivot.Position:Dot(axis)
		local target = first + step * (i - 1)
		items[i]:PivotTo(pivot + axis * (target - along))
	end
	return #items - 2
end
```

This spaces pivots, not edges. For "equal gaps between bounding boxes", use `GetBoundingBox` on models and `Size` on parts, sum the extents along the axis, and divide the free space. Offer both modes; designers will ask for the second the day after you ship the first.

## 8. Performance of bulk edits

Rules of thumb for selections in the tens of thousands:

- **Read cost is small, write cost is not.** Changing `CFrame` or `Size` on 20,000 parts can take seconds, plus the recording's memory. Show the count and confirm above a threshold (say 5,000 parts).
- **Do not yield inside the write** (the recording rule). If the edit is too large to do in one frame, split it into several operations, each its own recording, with a progress label between them; tell the user it will take N undo steps.
- **Skip unchanged values.** Writing the same value still counts as work and may record a change.
- **Avoid `Selection:Set` with huge arrays** inside loops: selecting 20,000 instances makes the Properties window and Explorer do heavy work. Set the selection once, at the end, or not at all for very large results.
- **Explorer cost.** Reparenting thousands of instances under an expanded Explorer node is slow because the Explorer updates; collapsing the node first helps (rule of thumb, see [[Explorer Properties and Selection]]).

For edits too big for interactive use (whole-map passes, hundreds of thousands of instances), a plugin button is the wrong shape; use a sliced, resumable batch tool as in [[Batch Processing Tools in Studio]], with snapshots instead of undo.

## 9. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| No ancestor normalisation | Children move twice; models deform | Normalise roots first |
| Moving parts of a model individually | Model pieces drift apart | `PivotTo` on roots |
| Editing locked parts silently | Users' protected objects change | Skip locked; report the count |
| Relying on selection order | "Align to first" picks a random part | Define order or an explicit reference |
| Ignoring grid and rotation settings | Tool feels foreign | Read `GridSize`, `RotateIncrement`, `UseLocalSpace` at use time |
| Accumulating drag deltas | Drift, jitter | Start state plus total delta |
| Mouse tool without `Deactivation` handling | Cursor stuck, connections leak | Always stop on `Deactivation` |
| Bulk edit inside packages unannounced | Modified package copies | Detect `PackageLink`, ask |
| Selection-driven automation | Wrong objects in shared sessions | Names, tags, paths for automation |

## 10. Checklist

- [ ] Selection read once per operation, filtered by class, normalised to roots and parts.
- [ ] Locked parts skipped and counted; packages detected.
- [ ] Models moved by pivot; operations choose roots or parts deliberately.
- [ ] Studio grid, rotation and space settings respected.
- [ ] Mouse tools restore the cursor and handle `Deactivation`.
- [ ] Handles and previews live in `CoreGui`.
- [ ] Every operation is one recording (or a few, announced), with no yields inside.
- [ ] Large selections confirmed; unchanged values skipped.
- [ ] Bulk property edits keep Pre-attribute backups and a revert button.

## See also

- [[Plugin Development Start Here]], [[Undo and ChangeHistoryService Done Right]], [[Plugin UI with DockWidgets]]
- [[Explorer Properties and Selection]], [[Batch Processing Tools in Studio]], [[Command Bar and Studio Scripting]]
- [[Grid Placement and Player Building Systems]], [[Modular Environment Kits]], [[Raycasts Shapecasts and Spatial Queries]], [[Packages and Asset Reuse]]

## Connected notes
<!-- auto-links:start -->
[[Plugins - Using and Writing]] · [[Building a Studio Plugin End to End]] · Studio Interface Tour · Packages and Shared Assets Across Places · Studio Settings and Shortcuts · Team Create and Collaboration
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Studio Interface Tour]] · [[Plugin Security and Permissions]] · [[Studio Settings and Shortcuts]] · [[Version History and Backups]] · [[Team Create and Collaboration]] · [[Publishing Selling and Updating Plugins]]
<!-- related:end -->
