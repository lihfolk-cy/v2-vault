---
tags: [production, safety, backups, undo, terrain, workflow, case-study]
---
# Safe Changes in a Shared Place

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Ctrl+Z after a bad scripted change. It undoes other people's work too.
> - Avoid: Backup folders in the place. They become the performance problem.
> - Avoid: Regenerating an area to fix a detail. Everything else in that area is lost.
> - No undo; originals recorded as attributes or on disk.
> - Terrain snapshot before any bulk write; owner OK for area regeneration.
> - One change at a time, verified and recorded.
>
> Cost: TL;DR ~150 tok · whole note ~4.0k tok. Read more: ## 2. Record the original before you change it · ## 3. Terrain: snapshot, then ask · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A Roblox place is a shared, mutable database with a weak undo. When several people (or several automated sessions) edit it at once, every change can break someone else's, and the obvious recovery tools (Ctrl+Z, a backup folder, "I'll just regenerate it") each have a trap. This note collects the rules for changing a shared place safely: how to make every change reversible, how to back up without bloating the place, and how to avoid the specific disasters that one production game (the reference project) actually had.

The rules in one line each:

1. Never use undo in a shared place.
2. Record the original before you change it, on the instance or on disk.
3. Snapshot terrain before any bulk write; ask before regenerating an area.
4. Make one change at a time, verify it, record it.
5. Read the current state before writing; never write from a stale copy.
6. Build new content alongside the old and swap; delete the old last.
7. Prove nothing references something before deleting it.
8. Keep backups out of the place; keep them on disk and in version history.

## 1. Never use undo in a shared place

Studio's undo history (`ChangeHistoryService`) is one stack for the whole session. In Team Create or any setup where several actors edit the same session, it records everybody's changes in one sequence.

The reference project's incident: a session overwrote terrain by mistake and used Studio undo to recover it. The undo went about 40 waypoints back and rolled back other sessions' instance changes along with the terrain (measured). Worse, every scripted edit added a waypoint, which wiped the redo stack, so the rolled-back work could not be redone.

Why this happens: waypoints are created by every recorded action, not just yours. "Undo my last change" is not an operation the engine offers in a shared session; undo only means "pop the shared stack".

What to do instead:

- **Before a risky change, record what you will change** (attributes, a terrain snapshot, a source copy on disk).
- **To revert, apply your own record**, which touches only your instances.
- **If you are writing tools**, use the recording API (`ChangeHistoryService:TryBeginRecording` / `FinishRecording` in plugins, Roblox docs) so your own operations become clean single undo steps for a solo user, but still never rely on undo as the team's recovery tool.

See [[Team Create and Collaboration]] and [[Version History and Backups]].

## 2. Record the original before you change it

The reference project's most useful convention: before a tool changes a property, it stores the original value as an attribute named `Pre<Tag>_<Property>`. Examples from the project: `PreTex_*` for a texture pass, `PreFix_*` for geometry fixes, `PreBuilderFont` for a font sweep, `PrevImage` for swapped icons, `PreLOD` for a level-of-detail change on 7,861 models, `Z0Shrink_CF` for a zone resize.

```lua
--!strict
-- Record-then-change helpers. Tag groups one operation so it can be reverted alone.
local SUPPORTED = {
	number = true, string = true, boolean = true, Vector3 = true, Vector2 = true,
	CFrame = true, Color3 = true, UDim = true, UDim2 = true, BrickColor = true,
}

local function keyFor(tag: string, prop: string): string
	return `Pre{tag}_{prop}`
end

local function setRecorded(inst: Instance, tag: string, prop: string, value: any)
	local key = keyFor(tag, prop)
	if inst:GetAttribute(key) == nil then -- first write wins: never overwrite the true original
		local old = (inst :: any)[prop]
		if typeof(old) == "EnumItem" then
			inst:SetAttribute(key, "Enum:" .. old.Name) -- store enums by name
		elseif SUPPORTED[typeof(old)] then
			inst:SetAttribute(key, old)
		else
			error(`cannot record {prop} of type {typeof(old)}`, 2)
		end
	end
	(inst :: any)[prop] = value
end

local function revertTag(root: Instance, tag: string): number
	local prefix = `Pre{tag}_`
	local count = 0
	for _, inst in root:GetDescendants() do
		for key, stored in inst:GetAttributes() do
			if string.sub(key, 1, #prefix) == prefix then
				local prop = string.sub(key, #prefix + 1)
				local current = (inst :: any)[prop]
				if typeof(stored) == "string" and string.sub(stored, 1, 5) == "Enum:" and typeof(current) == "EnumItem" then
					(inst :: any)[prop] = (current.EnumType :: any)[string.sub(stored, 6)]
				else
					(inst :: any)[prop] = stored
				end
				inst:SetAttribute(key, nil)
				count += 1
			end
		end
	end
	return count
end
```

Why attributes and not a backup copy:

- **Zero extra instances.** An attribute adds no instance; a backup folder can add hundreds of thousands.
- **The record travels with the instance.** Move it, rename it, and the undo data comes along.
- **Revert is selective.** `revertTag(root, "Tex")` reverts one operation and nothing else.

Limits: attributes hold only certain value types (Roblox docs), so store enums by name and skip properties you cannot record (or record them on disk). Attributes do not record created or destroyed instances; for those, keep a list on disk (created instance paths, or a `.rbxm` of what you destroyed).

## 3. Terrain: snapshot, then ask

Terrain is the most dangerous shared resource: it is one object, colours are global per material, and a bulk write erases whatever was there.

Incidents in the reference project:

- A full terrain regeneration overwrote other sessions' terrain work, and the undo used to recover it rolled back other changes (above).
- A "make it all a grass field so I can see" preview cleared all terrain, including another workstream's staging slab. It was snapshotted first, so the revert worked, but the other workstream's area had to be rebuilt where the snapshot did not cover it.
- Cliff placements were deleted without a backup, and the only autosave predated a layout change, so 821 rock positions were unrecoverable and the walls were rebuilt from scratch.
- Darkening grass for one zone by changing the global Grass colour changed every zone. The workaround (repainting that zone with another material overridden to look like grass) removed the 3D grass blades, because only the Grass material grows them, and was reverted.

Snapshot pattern, using `Terrain:CopyRegion` and `PasteRegion` (Roblox docs; regions are in cells of 4 studs):

```lua
--!strict
local Terrain = workspace.Terrain

-- Snapshot a world-space box into a TerrainRegion. Keep it only until the change is approved,
-- then export it to disk and delete it (see rule 8).
local function snapshot(minWorld: Vector3, maxWorld: Vector3, name: string): TerrainRegion
	local minCell = Terrain:WorldToCell(minWorld)
	local maxCell = Terrain:WorldToCell(maxWorld)
	local lo = Vector3int16.new(minCell.X, minCell.Y, minCell.Z)
	local hi = Vector3int16.new(maxCell.X, maxCell.Y, maxCell.Z)
	local region = Terrain:CopyRegion(Region3int16.new(lo, hi))
	region.Name = name
	region:SetAttribute("CornerCell", Vector3.new(lo.X, lo.Y, lo.Z))
	region.Parent = game:GetService("ServerStorage")
	return region
end

local function restore(region: TerrainRegion)
	local c = region:GetAttribute("CornerCell") :: Vector3
	-- true = paste empty cells too, so anything added since is cleared back to the snapshot
	Terrain:PasteRegion(region, Vector3int16.new(c.X, c.Y, c.Z), true)
end
```

Rules from the project for terrain writes:

- One `WriteVoxels` per call, then read back and verify the cells you meant to change.
- Never fill large areas with terrain water: a 5,000 x 1,900 stud sea stalled joining (measured). Fake water with a flat part.
- Never run a whole-area generator without a snapshot and the owner's OK. The project put that warning in the generator's own header comment.
- Record what regions you changed in the notes, with the snapshot name.

See [[Terrain Tools and Terrain API]].

## 4. One change at a time

Batching unrelated changes feels efficient and makes failures unattributable. The reference project's discipline:

- one logical change per step, verified before the next;
- one Studio call at a time, each short (about 1.5 seconds), so a hang is attributable and other users are not blocked;
- big jobs chunked and resumable.

When something breaks after one change, you know the cause. When it breaks after twelve, you bisect, and in a shared place you cannot bisect cleanly because others keep editing.

## 5. Read before you write

Two failure modes:

- **Stale source.** You edit a script from a local copy made an hour ago; someone changed the script in Studio since. Your write erases their change. Rule: compare Studio's current source with your base before writing. A guarded write that cancels when the source changed is in [[Working with AI Assistants in Studio]].
- **Stale module state.** In a command-bar context, `require` returns a cached copy; you read old config and act on it. Rule: require a clone parented beside the original.

Shared hot files deserve an explicit protocol. The reference project's main config module was edited by two workstreams; the rule for an insert was "re-read first, back up the source to disk, one insert, compile check, scan, clone-require".

## 6. Build alongside, swap, delete last

For anything larger than a tweak, build the new version next to the old one (a staging folder, a different coordinate region, or a separate place), get it approved, then swap. The swap should be one small reversible operation: a parent change, a flag, a spawn location.

The reference project did this right and wrong:

- **Right:** a hub redesign built in a staging folder at a separate position; the live hub untouched until approval.
- **Wrong:** a later hub replacement deleted the old hub (4,531 instances) at swap time. When the owner reverted the same day, the old hub had to be copied from an older place version opened in a second Studio window. Four instances in a bounds folder were missing after the paste and never explained (measured).
- **Right:** a corridor redesign listed "old map deletion" as the last step, with a delete list on disk. When the owner reverted, nothing had been deleted.

### Feature flags as swaps

For code, the equivalent is a flag. The project's ownership hand-over from an old enemy system to a new one used per-zone workspace attributes: the old system's loop skipped any zone whose flag was set, and the new system set the flag only after a successful init. Turning a zone back to the old system was clearing one attribute. See [[Case Study - Enemy Roster Rebuild]] and [[Release Process and Rollbacks]].

## 7. Prove nothing references it before deleting

The reference project's deletion policy changed twice: first "never delete, set aside", then "remove what is not needed, after proving nothing references it". Proof meant:

- grep every script source for the name, including dynamic lookups (`FindFirstChild(prefix .. id)`, string tables of names);
- check `ObjectValue` values and attributes that hold paths;
- check config tables and registries;
- remember comments too: after one cleanup, many comments pointed at deleted backups.

```lua
--!strict
-- Find script sources that mention a name (plain search, never a leading [^\n]* pattern).
local SERVICES = { "Workspace", "ReplicatedStorage", "ReplicatedFirst", "ServerStorage",
	"ServerScriptService", "StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService" }

local function mentions(needle: string): { string }
	local hits = {}
	for _, serviceName in SERVICES do
		local service = game:GetService(serviceName)
		for _, inst in service:GetDescendants() do
			if inst:IsA("LuaSourceContainer") then
				local ok, src = pcall(function() return (inst :: any).Source end)
				if ok and typeof(src) == "string" and string.find(src, needle, 1, true) then
					table.insert(hits, inst:GetFullName())
				end
			end
		end
	end
	return hits
end
```

A name that is built at runtime (`"Kit_" .. id`) will not match a grep for the full name; search for the stem and read the hits. See [[Case Study - Instance Cleanup and Place Size]].

## 8. Backups belong outside the place

The reference project started by keeping safety copies inside the place: one folder per pass in ServerStorage, plus dated backup folders. It ended with a rule against it, after the place hit about 1.07 million instances, Studio ran at about 15 fps using about 18 GB, and every in-place backup was deleted in one purge (about 1.07M to about 600K instances, measured).

| Backup kind | Cost | Use for |
|---|---|---|
| Folder copy in ServerStorage | Instances for every server and in Studio; slows saves and the Explorer | Avoid; at most one small, short-lived copy during a pass |
| `Pre*` attributes | Nothing measurable | Property changes |
| Source copies on disk | Nothing in the place | Every script you edit, before and after |
| `.rbxm` export on disk | Nothing in the place | Instances you destroy or replace |
| Roblox version history | Built in | Whole-place restore, or copying one folder from an older version |
| Studio autosave / recovery | Built in | Crashes |

Version history is the backstop, not the plan: restoring a whole place version also reverts everyone else's work since then. The safer use is opening an old version separately and copying the one folder you need. Studio crashes happened too: one crash rolled the place back to an earlier save and a day's edits were redone; another time every cloud save timed out and the place reopened at the previous day's version (measured). Save often and confirm the save succeeded.

## Size limits are safety limits

A script that is too big cannot be saved at all. In the reference project two core modules grew past the 200,000-character Source limit (201,360 and 201,561 characters), which meant any edit failed (measured). The fix was a split: move whole blocks verbatim into a child ModuleScript, require it at the same point, and verify with a deep comparison of old and new results. A third script sat at 199,919 characters with a team rule "never edit it; extend through its API module". Watch module sizes the way you watch instance counts. Another limit hit: a client script reached the 200-local-variables-per-function limit and new top-level locals stopped compiling; new code had to go inside functions. See [[Module Scripts and Requiring]].

## Common mistakes

- **Ctrl+Z after a bad scripted change.** It undoes other people's work too.
- **Backup folders in the place.** They become the performance problem.
- **Regenerating an area to fix a detail.** Everything else in that area is lost.
- **Writing from a stale copy.**
- **Deleting the old version at swap time.**
- **Deleting on a grep for the full name only.** Dynamic names are missed.
- **Changing a global (terrain colours, Lighting) for a local goal.**

## Checklist

- [ ] No undo; originals recorded as attributes or on disk.
- [ ] Terrain snapshot before any bulk write; owner OK for area regeneration.
- [ ] One change at a time, verified and recorded.
- [ ] Current source compared before every script write; modules clone-required.
- [ ] New versions built alongside; old ones deleted last.
- [ ] Deletions proven unreferenced, including dynamic names and comments.
- [ ] Backups on disk and in version history, not in the place.
- [ ] Module sizes watched against the Source limit.

## See also

- [[Version History and Backups]], [[Team Create and Collaboration]], [[Command Bar and Studio Scripting]]
- [[Working with AI Assistants in Studio]], [[Team Roles and Workflows]], [[Release Process and Rollbacks]]
- [[Case Study - Instance Cleanup and Place Size]], [[Case Study - Cutting a Million Instances]]
- [[Terrain Tools and Terrain API]], [[Engine Gotchas]]
- [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Safety Rules for AI Agents in Studio]] · [[Post-Mortem - Building a Melee Action Game]] · [[Undo and ChangeHistoryService Done Right]] · [[Batch Processing Tools in Studio]] · [[MCP Workflows for Building Worlds]] · [[Pipeline Design Principles]]
<!-- auto-links:end -->
