---
tags: [studio, explorer, properties, selection, attributes, workflow]
---
# Explorer Properties and Selection

The Explorer and Properties windows are where you spend most of your non-coding time in Studio. Used well, they replace dozens of throwaway scripts: the Explorer search language can find "every unanchored MeshPart under the map with CastShadow on" in one query, and Properties can edit all of them at once. Used carelessly, selection-driven edits are the most common way to damage a shared place. This note covers both windows in depth, the `Selection` service for scripts, and the reversible bulk-edit pattern the reference project used for every large pass. Facts are from the Studio docs as of October 2026 unless marked.

Source labels: **Docs** (official docs), **Measured** (reference project), **Rule of thumb**.

---

## 1. The Explorer as a data model browser

The Explorer shows every instance in the place, with services at the top level (Docs). Things that are easy to miss:

- **Hidden services.** Many services are hidden to keep the tree short. Right-click, **Show Services...** to reveal one, and right-click a service, **Hide Service in Explorer** to hide it again (Docs). Studio settings **Show Hidden Objects in Explorer** and **Show Core GUI in Explorer while Playing** reveal even more.
- **Expand and collapse.** `→` / `←` expand and collapse one branch; `Shift`-click the arrow to expand or collapse everything below (Docs). `Home` and `End` jump to the top and bottom.
- **Insert anywhere.** Hover the parent and click ⊕, or press `Ctrl I` (`⌘ I`) to insert any class (Docs).
- **Insertion options** (the ⋯ beside search): **Increment names for new instances** (Part1, Part2...) and **Expand hierarchy when selecting** (Docs). Turn increment naming **off** if your code looks things up by name; auto-numbered duplicates break `FindFirstChild` assumptions quietly.

### Duplicate and paste semantics

| Action | Windows | Effect (Docs) |
|---|---|---|
| Duplicate | `Ctrl D` | Copy into the same parent |
| Paste | `Ctrl V` | Paste into top-level `Workspace` |
| Paste Into | `Ctrl Shift V` | Paste into each selected parent (one texture into many parts in one step) |
| Paste Into At Original Location | right-click, **Paste Options** | Keeps the copied CFrames |
| Group as Model | `Ctrl G` | |
| Group as Folder | `Ctrl Alt G` | |
| Ungroup | `Ctrl U` | |

**Nuance.** Plain `Ctrl V` always goes to `Workspace`, even if you copied a ModuleScript from `ReplicatedStorage`. People then "lose" the paste. Use Paste Into. When copying world objects out of a running test to keep them, use **Paste Into At Original Location** in Edit, otherwise they land at the camera.

## 2. The Explorer search language

Press `Ctrl Shift X` to jump to the search box (Docs). The query language is far stronger than most people know.

| Query type | Example | Finds |
|---|---|---|
| Name (case-insensitive substring) | `lantern` | Anything with "lantern" in its name |
| Property equality | `ClassName = Decal`, `Locked = true` | Matching instances |
| Partial enum match | `Material == plas` | Plastic and SmoothPlastic |
| Comparison | `Transparency ~= 0.5`, `Health > 50` | |
| Field of a value type | `Position.X = 1`, `Color.R > 120` | |
| Whole value | `Size > "20, 5, 20"`, `Color = "255, 0, 0"` | Every component compared |
| Class | `is:Part` | Exactly that class |
| Superclass | `is:BasePart` | Part, MeshPart, Union and so on |
| Tag | `tag:LightSource`, `tag:"Light Source"` | CollectionService tags |
| Child path | `Animals.Dog.Tail` | Named path |
| Wildcards | `Cart.*`, `Cart.*.*`, `Cart.*.Trim` | Children, grandchildren |
| All descendants | `CarModel.**` | Everything under it |
| AND | `Anchored=true CanCollide=true` (or `and`) | Both |
| OR and grouping | `(Anchored=true CanCollide=true) or (Anchored=false CanCollide=false)` | Either group |

All examples from the docs. Names with spaces must be quoted, because a space means AND (Docs).

Queries that pay for themselves on any real project (Rule of thumb):

| Task | Query |
|---|---|
| Unanchored decoration that will fall or drift | `Map.** is:BasePart Anchored=false` |
| Small parts still casting shadows | `is:BasePart CastShadow=true Size < "1, 1, 1"` |
| Meshes with precise collision (expensive) | `is:MeshPart CollisionFidelity == precise` |
| Leftover test objects | `test or temp or copy` |
| Scripts hidden inside models from the Toolbox | `Workspace.** is:LuaSourceContainer` |
| Disabled scripts you forgot | `is:Script Enabled=false` |
| Everything tagged for a system | `tag:Collectible` |

In a searched tree, `Ctrl A` and the select-all button select **only matches**, `Shift`-click ranges select only matches, and drag-select only takes matches (Docs). That turns search plus select-all plus Properties into a bulk editor.

## 3. Properties

The Properties window edits the selection, grouped into collapsible sections; collapse state is remembered per class (Docs). Key points:

- **Filter** with `Ctrl Shift P`: typing "velo" shows AssemblyLinearVelocity and AssemblyAngularVelocity (Docs).
- **Vector entry**: type `4, 1, 2` into the parent field, or expand X, Y, Z (Docs). Fields accept arithmetic in practice (for example `*2`), but treat that as a convenience, not something to document for others (Rule of thumb, behaviour unverified in docs).
- **Multi-select editing**: with several objects selected, only shared properties show, mixed values display blank, and typing a value sets it on all of them. This is the bulk editor; see the safety section below.
- **Tags** section: add or remove CollectionService tags. Tags replicate to clients and save with the place (Docs).
- **Attributes** section: add custom typed data to any instance. Supported types: string, boolean, number, UDim, UDim2, BrickColor, Color3, Vector2, Vector3, CFrame, NumberSequence, ColorSequence, NumberRange, Rect, Font (Docs). Attributes save with the place and replicate. See [[Instances Attributes and Tags]].

### Configurable defaults

Select an instance and use **Edit > Save as Default [Class]**; new instances of that class then use its properties. **Reset Default** reverts (Docs). Defaults are saved locally in `DefaultInstances.rbxm`, location set by the Studio setting **Instance Defaults Dir** (Docs). Exceptions: position properties of parts and models are not affected, and Group as Model / Group as Folder do not use the Model or Folder defaults (Docs).

Useful defaults (Rule of thumb):
- MeshPart: `Anchored = true`, `CastShadow` per your art budget, `CollisionFidelity = Box` for decoration (see [[Collision and Physics Geometry]]).
- Part used for blockout: `Anchored = true`, `Material = SmoothPlastic`.
- PointLight: `Shadows = false` with a sane `Range`, so new lights do not cost shadow maps by default.

Share the team's `DefaultInstances.rbxm` through the repo. A builder with private defaults creates places that behave differently from everyone else's, and nobody can tell why.

## 4. Selection from code: the `Selection` service

`Selection` exposes the current Studio selection: `Get()`, `Set(instances)`, `Add(instances)`, `Remove(instances)` and the `SelectionChanged` event (Docs). It works from the Command Bar and plugins.

```lua
--!strict
-- Command Bar: report the selection's class mix and total part count.
local Selection = game:GetService("Selection")

local counts: { [string]: number } = {}
local parts = 0
for _, root in Selection:Get() do
	for _, inst in root:GetDescendants() do
		counts[inst.ClassName] = (counts[inst.ClassName] or 0) + 1
		if inst:IsA("BasePart") then
			parts += 1
		end
	end
	if root:IsA("BasePart") then
		parts += 1
	end
end
print(("selection: %d roots, %d BaseParts"):format(#Selection:Get(), parts))
for className, n in counts do
	print(className, n)
end
```

And the reverse, selecting what code found so you can review it before editing:

```lua
--!strict
-- Select every MeshPart under a named map folder that still uses Precise collision.
local Selection = game:GetService("Selection")
local map = workspace:FindFirstChild("Map")
assert(map, "no Workspace.Map")
local found: { Instance } = {}
for _, inst in map:GetDescendants() do
	if inst:IsA("MeshPart") and inst.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition then
		table.insert(found, inst)
	end
end
Selection:Set(found)
print(#found, "selected; review in Properties before changing anything")
```

### The selection trap in shared places

**Measured.** The reference project's rule for every tool was "find things by name, never by Selection". In a shared place (several collaborators, or several tools driving one Studio), the selection is whatever someone last clicked. A tool that runs `for _, p in Selection:Get()` acts on the wrong objects as soon as anyone else touches the mouse, and several imports or test rigs with similar names often coexist. Selection is fine for an interactive human-driven step ("select, look, then press the button"). It is wrong for anything automated or anything you run twice.

## 5. Names are not identities

`FindFirstChild(name)` returns the **first** child with that name, whatever its class. The Explorer happily allows duplicate names.

**Measured.** In the reference project an animation clip named `Origin` was added to a folder that already held a `RemoteEvent` named `Origin`. The server code found the clip instead of the remote, and a whole weapon kit silently stopped dealing damage. The fix was a list of reserved names that content must never use, plus `IsA` checks on lookups:

```lua
--!strict
local function findChildOfClass<T>(parent: Instance, name: string, className: string): T?
	for _, child in parent:GetChildren() do
		if child.Name == name and child:IsA(className) then
			return (child :: any) :: T
		end
	end
	return nil
end

local remote = findChildOfClass(script.Parent, "Origin", "RemoteEvent") :: RemoteEvent?
```

Better still: keep data (clips, models) in a subfolder separate from wiring (remotes, scripts), and use tags or attributes for identity when objects are discovered dynamically (see [[CollectionService Patterns]]).

## 6. Safe bulk edits: the Pre-attribute pattern

Bulk edits through Properties or a Command Bar loop are fast and dangerous. Undo is not a safety net in a shared place: undo history interleaves with other people's and tools' changes, and an undo can roll back far more than you intended (see [[Command Bar and Studio Scripting]] and [[Safe Changes in a Shared Place]]).

The reference project made every large pass **reversible by data**, storing each changed instance's original value in an attribute with a pass-specific prefix (`PreTex_Material`, `PreHubFloatPivot`, `PreFlat_Transparency` and so on), so a revert function could restore exactly those values, even days later and after other edits (Measured).

```lua
--!strict
-- Reversible bulk property edit. Run in Edit from the Command Bar.
-- Stores the original value once (never overwritten) under "<tag>_<Property>".
type Value = any

local function setReversible(inst: Instance, prop: string, value: Value, tag: string)
	local key = tag .. "_" .. prop
	if inst:GetAttribute(key) == nil then
		-- Attributes cannot store every type (no EnumItem). Encode enums by name.
		local old = (inst :: any)[prop]
		if typeof(old) == "EnumItem" then
			inst:SetAttribute(key, "Enum:" .. tostring(old.Name))
		else
			inst:SetAttribute(key, old)
		end
	end
	(inst :: any)[prop] = value
end

local function revert(root: Instance, tag: string, prop: string, enumType: Enum?)
	local key = tag .. "_" .. prop
	local n = 0
	for _, inst in root:GetDescendants() do
		local saved = inst:GetAttribute(key)
		if saved ~= nil then
			if type(saved) == "string" and string.sub(saved, 1, 5) == "Enum:" and enumType then
				(inst :: any)[prop] = (enumType :: any)[string.sub(saved, 6)]
			else
				(inst :: any)[prop] = saved
			end
			inst:SetAttribute(key, nil)
			n += 1
		end
	end
	return n
end

-- Example: turn off shadows on tiny decoration, reversibly.
local map = workspace:FindFirstChild("Map")
assert(map, "no Workspace.Map")
local changed = 0
for _, inst in map:GetDescendants() do
	if inst:IsA("BasePart") and inst.CastShadow and inst.Size.Magnitude < 2 then
		setReversible(inst, "CastShadow", false, "PreShadowPass")
		changed += 1
	end
end
print("changed", changed)
-- Later, if needed: print(revert(map, "PreShadowPass", "CastShadow"))
```

Notes:
- Store the original **once**. A rerun must not overwrite the true original with the already-changed value (the same rule as "one safety copy, kept once" in [[Studio Tooling Architecture]]).
- Use a distinct prefix per pass so passes can be reverted independently.
- Remove the attributes when the pass is accepted, or they accumulate as clutter that replicates to clients. For position moves, a JSON file on disk (instance path to old CFrame) is a lighter alternative; the reference project used both.
- For huge structural changes (deleting or replacing content), attribute snapshots do not help. Export an `.rbxm` first (see [[Version History and Backups]]).

## 7. Explorer performance

- Expanding a folder with tens of thousands of children stalls the Explorer. Nest content by zone or category (Rule of thumb).
- The Explorer search walks the whole tree; in a place with around a million instances it becomes slow (Measured: the reference place at about 1.07M instances was sluggish everywhere). Fewer instances fix everything at once; see [[Case Study - Instance Cleanup and Place Size]].
- Deep scans in code (`workspace:GetDescendants()`) took seconds in the same place (Measured). Scope searches to the subtree you need.

## 8. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| `Ctrl V` expecting paste into selection | Object lands in Workspace | `Ctrl Shift V` |
| Increment naming on while code uses names | `Door2` never found by `FindFirstChild("Door")` loops that expect unique names | Turn it off, or look up by tag |
| Multi-select edit across mixed classes | Only shared properties change, others silently untouched | Search with `is:` first, then select all matches |
| Bulk edit with no record of originals | No clean revert except Version History, which reverts everything else too | Pre-attribute pattern or `.rbxm` export |
| Automated tool driven by Selection | Acts on someone else's selection | Resolve targets by path, tag or attribute |
| Duplicate names for different classes | Wrong instance found | Separate folders, `IsA` checks, reserved names |
| Private configurable defaults | Inconsistent new objects across the team | Shared `DefaultInstances.rbxm` |

## 9. Checklist

- [ ] Know `Ctrl Shift X` (search) and `Ctrl Shift P` (property filter).
- [ ] Use `is:`, `tag:` and `.**` queries before writing a script.
- [ ] Review a bulk selection in Properties before typing a value.
- [ ] Every bulk change records originals (attributes or a file) or has an export.
- [ ] No automated tool reads `Selection`.
- [ ] Reserved names list exists for content folders that share space with remotes or scripts.
- [ ] Team defaults file shared.

## See also

- [[Studio Interface Tour]], [[Command Bar and Studio Scripting]], [[Plugins - Using and Writing]]
- [[Instances Attributes and Tags]], [[CollectionService Patterns]]
- [[Safe Changes in a Shared Place]], [[Version History and Backups]]
- Animation section: [[Engine Gotchas]] (reserved names), [[Studio Tooling Architecture]]

## Connected notes
<!-- auto-links:start -->
[[Studio Settings and Shortcuts]] · [[Selection Editing and Bulk Tools]] · [[Undo and ChangeHistoryService Done Right]] · [[Batch Processing Tools in Studio]] · [[Replication Rules]] · [[Plugin Development Start Here]]
<!-- auto-links:end -->
