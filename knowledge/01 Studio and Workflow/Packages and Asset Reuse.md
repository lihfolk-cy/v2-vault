---
tags: [studio, packages, assets, reuse, workflow, versioning]
---
# Packages and Asset Reuse

Packages are Roblox's built-in way to reuse an object hierarchy across places and games while keeping every copy linked to a versioned source. Change the package once, publish, and every copy can update. They are excellent for world-building kits, shared UI pieces, and anything placed many times. They are a poor fit for code libraries that change daily, and they have sharp edges: modifying a copy silently switches off auto-update, nested packages must be published inside-out, ownership can never be transferred, and mass updates save places without publishing them. This note covers the full workflow from the docs (as of October 2026) and the decision of when to use packages versus Wally, Rojo, `ServerStorage` templates or runtime asset loading.

Labels: **Docs**, **Measured**, **Rule of thumb**.

---

## 1. What a package is

A package is a model asset plus a `PackageLink` child inside each copy. The link holds (Docs):

| Property | Meaning |
|---|---|
| `PackageId` | The package asset |
| `VersionNumber` | The revision this copy is at |
| `AutoUpdate` | Update this copy when a newer version exists, on place open |
| `Creator`, `PackageAssetName` | Ownership and name |
| `PermissionLevel` | Your permission on the package |
| `Status` (internal) | Up To Date, Changed, New Version Available, Changed + New Version Available |

**Never delete or move the `PackageLink`.** Doing so turns that copy into a normal object and it stops updating (Docs).

## 2. Workflow

### Create
Right-click an object, **Convert to Package**, fill in details; for group work set **Ownership** to the group (Docs). Wrap a single object in a `Model` first so you can add children later without breaking the package (Docs).

**Ownership transfers are not supported** (Docs). A package created under a personal account stays personal forever. In a team, always create under the group.

### Insert
First insertion comes from the Toolbox: **Inventory > My Packages** or **Creations > Group Packages** (Docs). After that, duplicate copies in the place. Inserted packages appear in the Asset Manager even if all copies are later deleted (Docs).

### Modify and publish
Edit a copy like any object. Most edits mark it **modified**, which disables auto-update on that copy until you publish or revert (Docs). Not counted as modifications (Docs):
- Renaming the root.
- Moving or rotating the root (BasePart, Model or GuiObject root).
- Toggling `Enabled` on a root ScreenGui, SurfaceGui or BillboardGui.
- Changing a Weld's reference to a part outside the package.

So you can place and name copies freely; anything inside is part of the package.

Scripts inside an unmodified package are **read-only** with a link to unlock; clicking it marks the package modified even if you change nothing (Docs).

Publish: right-click the modified copy, **Publish to Package**. Add a change description under **Package Details > Versions** (Docs). Publishing the place does not require publishing modified packages first; the modified copy is saved with the place (Docs).

### Update copies
- Copies with `AutoUpdate` pull the new version **when the place is opened** (Docs). Not live in running servers, not mid-session.
- Other copies show a download icon: **Get Latest Package**, or select many and **Get Latest For Selected Packages** (Docs).
- **Update All** (mass update) updates copies across chosen places in the game. It **saves those places but does not publish them**, and it skips modified copies, reporting how many (Docs). Close other Studio instances with those places open first, or an unsaved instance may overwrite the update (Docs recommendation).

### Configuration attributes
Attributes on the package root become **default configurations** when published. Each copy can override values (shown in bold italics), and overrides survive updates while untouched attributes take new defaults (Docs). Scripts inside the package must read them; the engine does nothing with them by itself (Docs). Changing only default values and republishing does not mark the package modified (Docs).

```lua
--!strict
-- Script inside a "Lamp" package: reads per-copy configuration from the root's attributes.
local root = script.Parent :: Model
local light = root:WaitForChild("Bulb"):WaitForChild("PointLight") :: PointLight

local function apply()
	light.Brightness = (root:GetAttribute("Brightness") :: number?) or 1
	light.Color = (root:GetAttribute("Color") :: Color3?) or Color3.new(1, 1, 1)
end
apply()
root:GetAttributeChangedSignal("Brightness"):Connect(apply)
root:GetAttributeChangedSignal("Color"):Connect(apply)
```

Better at scale: no script per copy. Tag package roots and let one system configure all of them (see [[CollectionService Patterns]]). Hundreds of package copies each running a script is a memory and startup cost (Rule of thumb).

### Nested packages
If a nested package changes, it and its parent are both modified; publish the **nested one first**, then the parent (Docs). `AutoUpdate` only applies to the top-level package (Docs).

### Revert and compare (Docs)
- **Undo Changes to Package** reverts unpublished changes on a copy (or several).
- **Package Details > Versions**: restore an older published version.
- **Compare Package Versions**: visual overview, property and attribute diffs, line-by-line script diffs.
- Restoring a version does not reset configurations; reset attributes individually.

## 3. Sharing and permissions

Grant **Use & View** or **Edit** to friends, groups, roles or games through **Package Details > Permissions**, or to games by universe id on the Creator Dashboard (Docs). Two traps (Docs):
- Revoking Use & View does not remove copies someone already inserted; it only blocks reinsertion and updates.
- Restricted assets inside a package (for example private meshes or images under Asset Privacy) do not render or play for a game that lacks permission to them, even if it can use the package. See [[Creator Store and Toolbox Safety]].

## 4. Packages and external tooling

- **Script Sync** can sync scripts inside packages, but the `PackageLink` itself is not written to disk (Docs).
- **Rojo** does not know about packages. If Rojo manages a tree that contains a package copy, a sync can modify the copy (switching off auto-update) or overwrite its contents. Keep packages outside Rojo-managed trees, or manage the content purely in files and drop packages for it (Rule of thumb).
- Code in packages is versioned by Roblox, not by Git. If your team reviews code in pull requests, shared code belongs in Wally packages or a monorepo, not in Roblox packages.

## 5. Choosing a reuse mechanism

| Need | Best tool | Why |
|---|---|---|
| A tree, rock or lamp placed 500 times, art may improve | **Package** with AutoUpdate | Update art once; positions kept |
| Greybox now, final art later | **Package** | Replace contents, copies keep placement (Docs) |
| Shared world-building kit across several games | **Package** owned by the group | Cross-game updates |
| A Luau library (signals, promises, UI framework) | **Wally** | Semver, lockfile, code review (see [[External Tooling - Rojo Wally Selene StyLua]]) |
| Game code shared between places of one game | **Rojo project** or packages | Rojo if you use Git; packages otherwise |
| Templates spawned at runtime (enemies, pickups) | **`ServerStorage` / `ReplicatedStorage` templates** cloned by code | Simple, no asset round trip |
| Content loaded on demand from an asset id | `InsertService:LoadAsset` or `AssetService:LoadAssetAsync` | Rarely needed; adds network and permission dependencies |
| Mesh kits uploaded in bulk | Packages as upload containers, unpacked by an installer | See below |

**Measured.** The reference project shipped a set of 39 armor sets (889 MeshParts) by uploading meshes in five package batches and then running an installer that unpacked them into the game's own folder structure with the right colours and atlas mapping. Packages worked well as a transport for bulk mesh uploads; the runtime copies were plain instances owned by game code, so nobody could accidentally modify a package copy.

## 6. Performance and size

- Each copy is a full set of instances. Packages save authoring time, not memory. A 300-part lamp placed 500 times is 150,000 instances (see [[Art Budgets - Triangles Draw Calls Memory]]).
- Duplicate meshes and textures across copies are cheap (assets are shared by id), but duplicated `SurfaceAppearance`, scripts and constraints are not.
- For heavy repeated props, prefer one MeshPart per prop over many parts, and consider streaming-friendly `Model.ModelStreamingMode` (see [[Level of Detail and Model Streaming]]).

## 7. Auditing packages in a place

Package drift is invisible until something breaks: a copy modified months ago, a copy stuck on version 3 while the kit is on version 9, a package owned by someone who left. A read-only Command Bar report helps (uses only properties readable from scripts per the docs: `PackageId`, `VersionNumber`, `AutoUpdate`, `Creator`):

```lua
--!strict
-- Report every package copy: id, version, auto-update, creator. Read-only.
type Row = { path: string, id: string, version: number, auto: boolean, creator: string }
local rows: { Row } = {}
for _, inst in game:GetDescendants() do
	if inst:IsA("PackageLink") then
		local link = inst :: PackageLink
		local parent = link.Parent
		table.insert(rows, {
			path = parent and parent:GetFullName() or "?",
			id = tostring(link.PackageId),
			version = link.VersionNumber,
			auto = link.AutoUpdate,
			creator = link.Creator,
		})
	end
end
table.sort(rows, function(a: Row, b: Row)
	return a.id < b.id or (a.id == b.id and a.version < b.version)
end)
local versions: { [string]: { [number]: boolean } } = {}
for _, r in rows do
	versions[r.id] = versions[r.id] or {}
	versions[r.id][r.version] = true
	print(r.id, "v" .. r.version, r.auto and "auto" or "manual", r.creator, r.path)
end
for id, set in versions do
	local n = 0
	for _ in set do
		n += 1
	end
	if n > 1 then
		warn(id, "has copies at", n, "different versions")
	end
end
```

What to do with the report (Rule of thumb):
- **Several versions of one package**: decide whether the old copies are intentional (a frozen variant should be its own package) or stale (Get Latest).
- **Manual copies of kit packages**: switch AutoUpdate on unless there is a reason.
- **Creator is a person, not the group**: plan a migration (re-create under the group, replace copies) before that person leaves; ownership cannot be transferred.
- **Modified copies** (shown with the modified icon in the Explorer): publish or undo; a modified copy left for weeks is a fork nobody knows about.

### Packages across places of one game

A common use is keeping shared pieces (a lobby kiosk, a settings menu `ScreenGui`, lighting rigs) identical across several places of a universe. Workflow: edit in one place, **Publish to Package**, then **Update All** for the chosen places, then open and **publish** each place (mass update only saves), then restart servers if the change matters live (see [[Places Universes and Experience Settings]]). For code shared across places, a package of ModuleScripts works, but you lose code review; teams with Git usually build every place from the same Rojo source instead.

## 8. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Deleting or moving `PackageLink` | Copy unlinked silently | Never touch it |
| Editing one copy "just here" | Auto-update stops for that copy, forever drifting | Use configuration attributes for per-copy differences |
| Publishing a parent before its nested package | Blocked or inconsistent | Publish inside-out |
| Personal ownership in a team game | Cannot transfer later | Create under the group |
| Mass update then assuming players see it | Saved, not published | Publish each place |
| Mass update with another Studio open on a target place | That instance overwrites the update | Close other instances |
| Script per copy for configuration | Hundreds of scripts | One tagged system |
| Expecting AutoUpdate in live servers | Copies update only on place open in Studio | Publish the place after updating |
| Rojo syncing over package copies | Modified copies, lost updates | Keep packages out of Rojo trees |

## 9. Checklist

- [ ] Packages created under the group.
- [ ] Single objects wrapped in a Model before converting.
- [ ] Per-copy differences only through root attributes.
- [ ] AutoUpdate on for kit copies; modified copies reviewed weekly (search the Explorer for modified icons).
- [ ] Nested packages published inside-out with version notes.
- [ ] After mass updates: publish places, restart servers if needed.
- [ ] No package copies inside Rojo-managed trees.

## See also

- [[Asset Pipelines]], [[Creator Store and Toolbox Safety]], [[External Tooling - Rojo Wally Selene StyLua]]
- [[Places Universes and Experience Settings]], [[Version History and Backups]]
- [[Foliage Props and Scatter]], [[Level Design for Roblox]]

## Connected notes
<!-- auto-links:start -->
[[Packages and Shared Assets Across Places]] · [[Links - Models, Toolbox and Creator Store]] · [[Git and Source Control for Roblox]] · [[Team Create and Collaboration]] · [[Code Pipeline - Rojo Git and CI]] · [[Animation Asset Permissions and Groups]]
<!-- auto-links:end -->
