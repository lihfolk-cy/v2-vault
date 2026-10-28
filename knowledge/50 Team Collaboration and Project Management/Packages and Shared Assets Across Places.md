---
tags: [team, packages, assets, asset-privacy, multi-place, versioning, workflow, luau]
---
# Packages and Shared Assets Across Places

[[Packages and Asset Reuse]] documents the package workflow itself: creating, inserting, publishing, configuration attributes, nested packages, mass update, comparing versions, and a read-only report of package copies in one place. This note is about the team problem that sits on top of it: a game with several places (a lobby, match places, a test place), sometimes several games sharing one art kit, and several people publishing shared things. The questions are how a change travels from one person's edit to every live server, how to avoid one teammate's package publish breaking another place, how asset permissions differ from package permissions, what to do when the person who owns the packages leaves, and how to see drift across places that you cannot open at the same time.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. Three layers, three sharing models

Teams get confused because "shared asset" means three different things on Roblox, each with its own permission system and its own update path.

| Layer | Examples | How sharing is controlled | How updates travel |
|---|---|---|---|
| **Asset ids** | Meshes, images, decals, audio, animations, videos | Asset Privacy (for images, decals and meshes when enabled) and per-asset permissions | A new upload is a new id; nothing updates by itself. Code or instances must point at the new id |
| **Packages** | A lamp model, a lobby kiosk, a shared settings menu | Package permissions: Use & View, Edit | Publish to Package, then copies update on Studio open (AutoUpdate) or by Get Latest or Update All; the place must still be published |
| **Code** | Shared modules, frameworks | Whatever holds the source: packages, Rojo plus Git, Wally | Rebuild and publish each place |

Most production problems come from treating one layer as if it behaved like another: expecting a package publish to update live servers, expecting a re-uploaded mesh to replace the old one everywhere, or expecting revoking a permission to remove something already inserted.

### Asset Privacy facts that matter to teams

From the asset privacy page (Roblox docs, as of October 2026):

- Asset Privacy only affects **images, decals and meshes**, and only when the creator or group has enabled it; then it applies to **newly created** assets. Audio, models, MeshParts, animations, packages and videos are not affected by this setting.
- Access can be granted to friends (Collaborators tab), to a group (if you have Edit experiences in it), and to experiences by universe id (Experiences tab), or in bulk through the Asset Manager beta.
- If a game lacks permission, the asset does not load in Studio (a clickable error appears in Output) and is **invisible or silent at runtime**. Scripts that use it also need the game to have permission.
- **Grants to experiences are permanent and cannot be revoked.** Revoking a collaborator only stops future grants. Choosing Open Use is irreversible.
- Inserting a restricted asset into a collaborator's game also grants permission to that game's owner.
- Anyone with Edit on a game can copy a restricted asset into other places **of that same game** and reference its id there. Saving or publishing a place that contains a restricted asset requires the game itself to have permission.

The team lesson: **within one universe, restricted assets move freely between places; across universes, every grant is a permanent decision.** Plan which experiences will ever see your private art before the first grant. A sandbox experience for a contractor ([[Team Create Permissions and Workflows]]) should not receive grants to your private mesh library.

Packages have a separate warning: a package that contains restricted assets will insert into a game that has Use & View on the package, but the restricted meshes and images inside will not render unless that game also has permission to them (Roblox docs). Teams that share a kit across two group games often grant the package and forget the assets.

---

## 2. How a change actually reaches players

The single most useful thing to teach a new teammate about packages is the timeline. "I published the package, why do players still see the old lamp?" is the most common question.

| Step | Who or what | What changes | Players see it? |
|---|---|---|---|
| 1. Edit a copy | You | That copy is marked modified; auto-update is off for it | No |
| 2. Publish to Package | You | A new package version exists | No |
| 3a. Someone opens a place in Studio | Studio | Copies with AutoUpdate on, and unmodified, update in that Studio session | No |
| 3b. Or Update All | You | Chosen places are **saved**, not published; modified copies are skipped and counted | No |
| 4. Publish the place | A lead | The new version of the place is live for **new** servers | New servers only |
| 5. Restart or migrate servers | A lead | Old servers close or migrate ([[Server Lifecycle and Shutdown]]) | Everyone |

All of steps 1 to 4 are from the packages page (Roblox docs, as of October 2026); step 5 is ordinary place publishing. So a package change is never live until a place is published, and it is not universal until servers restart. For a game with five places, that is five publishes. Write it into the release checklist ([[Release Process and Rollbacks]]).

Two consequences that surprise people:

- **AutoUpdate is a Studio feature, not a runtime one.** A place nobody opens in Studio never picks up a package update until someone runs Update All or opens it.
- **Update All plus an open Studio instance can lose the update.** The docs recommend closing other Studio instances that have the target places open; an unsaved instance can overwrite the mass update.

---

## 3. Release discipline for shared packages

Packages have versions but no branches. If a builder publishes a half-finished change to a kit package, every place that opens next picks it up. On a single-place game this is annoying; on a five-place game with a live event it is an incident. A few habits make packages behave like released software (rule of thumb):

### Dev and stable package pairs

Keep two packages for anything shared by more than one place:

- `Kit_Lamp_Dev`: edited freely, AutoUpdate on, used **only** in the test place.
- `Kit_Lamp`: the stable package, used in live places.

When the dev version is approved, a lead copies its contents into a stable copy and publishes the stable package with a version note. This costs one extra package per kit and removes the "someone published mid-event" class of problem entirely. If the reported package overrides feature (section 7) ships, re-evaluate, but today packages have no channels.

### Version notes as a changelog

The packages page lets you add a description to each version in Package Details. Treat it like a commit message: what changed, why, who approved, and whether any configuration attribute was added or renamed. A renamed configuration attribute silently breaks every copy whose script reads the old name.

### Contracts inside packages

A package that contains scripts or that scripts look for has a contract: child names, attribute names, tags. [[Planning and Scoping a Roblox Game]] describes "contracts by name" for swapping content; packages need the same discipline. Write the contract into a `README` StringValue or a comment script inside the package root, and treat breaking it as a major change that needs every place's owner to agree.

### A canary place

Before Update All across live places, update and play the **test place** first, then one low-traffic live place, then the rest. If something breaks, restore the previous package version (Package Details, Versions, select the version, Submit; Roblox docs) and run Update All again. Remember restoring a version does not reset configuration attributes on copies.

---

## 4. Multi-place universes: what to package and what to build

A universe with a lobby and several match places ([[Teleporting and Multi-Place Games]]) shares a lot: UI, lighting, character setup, shared modules. Each piece has a better home.

| Shared thing | Better home | Reason |
|---|---|---|
| Game code (services, controllers) | Rojo project built into every place, or one ModuleScript package if Studio-only | Code wants review and history ([[Code Review for Luau Teams]]) |
| A ScreenGui used in every place (settings menu) | Package, or built from files | Designers can publish without a code deploy |
| Lighting and Atmosphere settings | A config module plus a small applier script | Properties of `Lighting` itself are not a package |
| Props and kit pieces | Packages with AutoUpdate | Their strong case |
| Large map regions | Not a package | Huge packages are slow to update and easy to modify by accident |
| Data constants (prices, drop tables) | Config modules or experience configs ([[Global State and Live Config]]) | Changes without republishing any place |

**Measured in the reference project:** packages worked well as a **transport** for bulk mesh uploads (39 armor sets, 889 MeshParts, in five package batches) that an installer then unpacked into plain instances owned by game code, so no runtime copy could be accidentally modified ([[Packages and Asset Reuse]]). That pattern generalises: when content is placed by code, ship it through packages but do not keep it as packages in the live place.

---

## 5. Seeing drift across places

The existing report prints package copies in one place. Across places you cannot open everything at once, so export a manifest per place and compare. The script below runs in the Command Bar of each place and prints a compact JSON line you paste into a shared file (or a spreadsheet). `HttpService:JSONEncode` works in Studio without enabling HTTP requests; only web requests need that setting.

```lua
--!strict
-- Command Bar: print a package manifest for this place as one JSON line.
-- Read-only. Run in each place, paste the output into packages_manifest.txt.
local HttpService = game:GetService("HttpService")

type Entry = { id: string, versions: { [string]: number }, modified: number, manual: number }

local byId: { [string]: Entry } = {}
local roots = { workspace, game:GetService("ReplicatedStorage"), game:GetService("ServerStorage"),
	game:GetService("StarterGui"), game:GetService("Lighting") }

for _, root in roots do
	for _, inst in root:GetDescendants() do
		if inst:IsA("PackageLink") then
			local link = inst :: PackageLink
			local id = tostring(link.PackageId)
			local e = byId[id]
			if not e then
				e = { id = id, versions = {}, modified = 0, manual = 0 }
				byId[id] = e
			end
			local v = tostring(link.VersionNumber)
			e.versions[v] = (e.versions[v] or 0) + 1
			if not link.AutoUpdate then
				e.manual += 1
			end
		end
	end
end

local list: { Entry } = {}
for _, e in byId do
	table.insert(list, e)
end
table.sort(list, function(a: Entry, b: Entry)
	return a.id < b.id
end)

print(HttpService:JSONEncode({ place = game.PlaceId, scanned = os.date("!%Y-%m-%dT%H:%M:%SZ"), packages = list }))
```

Notes on the script:

- The `Status` of a copy (modified or not) is shown in the Explorer but the packages page does not document a scriptable property for it, so the script leaves `modified` at 0 rather than guessing. Check modified copies by eye, or with the Asset Manager.
- Scanning only the listed roots avoids walking `CoreGui` and plugin trees, and keeps the scan fast on big places.
- `game.PlaceId` is 0 in an unpublished local file. That is fine; label the line by hand.

Then compare manifests. A short Python script is enough:

```python
# compare_manifests.py: read one JSON object per line, report packages whose versions differ.
import json, sys
from collections import defaultdict

seen = defaultdict(dict)  # package id -> {place: sorted versions}
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    doc = json.loads(line)
    for p in doc["packages"]:
        seen[p["id"]][str(doc["place"])] = sorted(int(v) for v in p["versions"])

for pid, places in sorted(seen.items()):
    all_versions = {v for vs in places.values() for v in vs}
    if len(all_versions) > 1:
        print(f"package {pid} differs: " + "; ".join(f"place {k}: v{vs}" for k, vs in places.items()))
```

Run it weekly during heavy production and before every multi-place release. Differences are not always wrong (a frozen variant), but every difference should have a reason written somewhere.

---

## 6. When the package owner leaves

Package ownership cannot be transferred (Roblox docs). A package created under a person's account stays theirs, and if they leave on bad terms they can stop publishing, or in the worst case change what future versions contain. Copies already in your places keep working, but you can no longer update them without that person, and revoking or losing their permission only stops future inserts and updates (Roblox docs). The fix is a migration: recreate the package under the group and replace every copy.

Steps (rule of thumb):

1. **Snapshot** the places involved (Save to Roblox with notes; export the affected folders to `.rbxm`; see [[Version History and Backups]]).
2. Insert one copy of the old package, **unlink it** by removing its `PackageLink` in a scratch place, and convert it to a new package with **Ownership set to the group**.
3. Replace copies with the script below, place by place.
4. Publish each place; record the old and new package ids in the decisions log.

```lua
--!strict
-- Command Bar: replace every copy of an old package with a copy of a new one,
-- keeping name, pivot, parent and per-copy attributes. Run after a snapshot.
-- Set OLD_ID to the old package id string (as printed by PackageLink.PackageId),
-- and put one copy of the NEW package at ServerStorage.PackageTemplate.
local ServerStorage = game:GetService("ServerStorage")

local OLD_ID = "rbxassetid://0000000000"
local template = ServerStorage:FindFirstChild("PackageTemplate")
assert(template and template:IsA("Model"), "put one copy of the new package (a Model) at ServerStorage.PackageTemplate")

local replaced, skipped = 0, 0
local targets: { Model } = {}
for _, inst in workspace:GetDescendants() do
	if inst:IsA("PackageLink") and tostring(inst.PackageId) == OLD_ID then
		local copy = inst.Parent
		if copy and copy:IsA("Model") then
			table.insert(targets, copy)
		else
			skipped += 1
		end
	end
end

for _, old in targets do
	local new = template:Clone()
	new.Name = old.Name
	new:PivotTo(old:GetPivot())
	for name, value in old:GetAttributes() do
		new:SetAttribute(name, value) -- carry per-copy configuration overrides
	end
	new.Parent = old.Parent
	old:Destroy()
	replaced += 1
end
print(`replaced {replaced} copies, skipped {skipped} non-Model copies`)
```

Cautions:

- **Test that cloning keeps the `PackageLink`** in your Studio version before running on a whole place: duplicating copies in the Explorer keeps the link, and `Clone` should too, but this was not confirmed against the docs for this note.
- The script copies **all** attributes from old to new, which turns old defaults into explicit overrides on the new copies. If you want new defaults to apply later, copy only the attributes that differ from the old package's defaults.
- `PackageId` prints as a content string; print one first and paste exactly what you see.
- Welds from outside the package to parts inside it will point at destroyed parts. Search for `WeldConstraint` references before running (the packages page notes that changing a weld's reference to an outside part is not a modification, which is a hint that such welds exist in real projects).

Prevention is cheaper: the first rule in [[Packages and Asset Reuse]] (create under the group) plus the audit in [[Team Create Permissions and Workflows]] catch personal packages before they matter.

---

## 7. Announced changes (unconfirmed)

A third-party summary of the Roblox Developers Conference keynote in September 2026 reported **package overrides** (local and global changes with auto-update and persistent local overrides) as launching later in 2026. I could not find the official announcement or a docs page, so treat it as **unconfirmed** as of October 2026. If it ships, the dev and stable package pair in section 3 may become optional, and the "editing a copy forks it forever" problem may soften. Re-read the packages page before relying on either.

---

## 8. When not to share

- **Code that changes daily** does not belong in a package if you have Git; review and history in Git are far better ([[Code Pipeline - Rojo Git and CI]]).
- **One-off set dressing** placed once does not need a package; the publish and update overhead buys nothing.
- **Content spawned by code** (enemies, pickups) is simpler as templates in `ServerStorage` cloned at runtime ([[Packages and Asset Reuse]] has the comparison table).
- **Across unrelated games owned by different groups**, sharing private assets creates permanent grants. Prefer exporting files and re-uploading under the other owner when the relationship is not permanent.

---

## Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Expecting a package publish to be live | Players see old content | Publish each place, restart servers |
| Granting a package but not its restricted meshes | Invisible parts in the other game | Grant the assets to that experience, knowing it is permanent |
| Builders publishing kit changes during an event | Live places pick up half-finished changes on next open | Dev and stable package pairs |
| Renaming a configuration attribute | Copies fall back to script defaults | Treat attribute names as a contract; version note |
| Versions drifting across places | Manifest compare shows differences | Weekly compare; canary then Update All |
| Personal ownership of team packages | Package `Creator` is a person | Migrate under the group before they leave |
| Sandbox experiences granted the private library | Experiences tab lists a sandbox | Placeholders in sandboxes; grants only to permanent experiences |

## Checklist

- [ ] Every shared thing assigned to a layer: asset id, package, or code.
- [ ] Private assets granted only to experiences the group will always own.
- [ ] Packages with restricted contents: the assets are granted to every experience that uses the package.
- [ ] Dev and stable package pair for anything used by more than one place.
- [ ] Version notes on every package publish; configuration attribute names treated as a contract.
- [ ] Release checklist: Update All, then publish each place, then restart servers.
- [ ] Manifest compare across places weekly in production and before multi-place releases.
- [ ] No package created under a personal account; migration plan for any that are.

## Connected notes
<!-- auto-links:start -->
[[Animation Asset Permissions and Groups]] · [[Team Collaboration Start Here]] · [[Places Universes and Experience Settings]] · [[Links - Models, Toolbox and Creator Store]] · [[Creator Store and Toolbox Safety]] · [[Team Create and Collaboration]]
<!-- auto-links:end -->
