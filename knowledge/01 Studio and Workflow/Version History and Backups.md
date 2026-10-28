---
tags: [studio, version-history, backups, recovery, rbxm, workflow]
---
# Version History and Backups

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Backup folders inside the place -> Disk exports; one temporary safety copy max
> - Avoid: Restoring during a live Team Create session -> Disable Team Create first
> - Avoid: Restoring and expecting players to see it -> Publish and restart servers
> - Named save with notes before every risky change.
> - Surgical snapshot (attributes, JSON, TerrainRegion, `.lua`) for the specific change.
> - Removed content exported to disk, verified, listed in a manifest.
>
> Cost: TL;DR ~160 tok · whole note ~3.2k tok. Read more: ## 1. Version History · ## 6. Exporting `.rbxm` safely · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Roblox keeps every saved and published version of every place in the cloud, which makes it tempting to think backups are solved. They are not. Version History restores a **whole place** to a point in time, which also throws away everything else that happened since; it does not cover player data, packages' other copies, configs or assets; and in a busy shared place the version you want is buried among auto-saves. A working backup strategy has layers: cloud versions for disasters, targeted snapshots for individual changes, local exports for anything you remove, and source control for code. This note covers the official tools (as of October 2026) and the layered strategy, including why backups must not live inside the place.

Labels: **Docs**, **Measured** (reference project), **Rule of thumb**.

---

## 1. Version History

**Window > Version History** opens a dockable widget (Docs). It provides:
- **Version notes** on saves and publishes, searchable.
- **Filters** by date range, save type (auto or manual), published saves, collaborator, and whether notes exist.
- **Who** was in the edit session and who saved.

Older versions created before the feature have no metadata; add notes to them if you need to find them (Docs).

### Saving with notes

**File > Save to Roblox with Notes** (`Ctrl Alt S`, `⌘ ⌥ S`) saves a version with a name and notes (Docs). Publishing requires notes. Studio can **generate publish notes** by summarising the version notes written since the previous publish; if nobody wrote notes, there is nothing to summarise (Docs).

Make notes useful (Rule of thumb):

```text
Name:  "Shop rework: before price table swap"
Notes: Owner: UI. Changed: ShopConfig, ShopController, StarterGui.Shop.
       Undo: restore this version OR revert ShopConfig from Script History.
       Not tested: gamepad navigation.
```

A note that says *before* a risky change is worth ten that say "update".

### Restoring

Through Studio (Docs):
1. **Window > Version History**, ⋮ next to the version, **Open Local Copy** (opens in a new Studio session).
2. In that session, **File > Save to Roblox As**, choose the same game and place, confirm the overwrite.

Through the Creator Dashboard: **Creations**, the game, **Configurations > Places**, the place, **Version History**, **Restore** (Docs).

Facts that matter (Docs):
- Restoring **creates a new version**. History is not rewritten, so you can restore the restore.
- Restoring **does not publish**. To make it live: open, publish, and restart servers (see [[Release Process and Rollbacks]]).
- In a collaborative session, someone still editing can auto-save over your restore. **Disable Team Create first.**

### What Version History does not cover

| Not covered | Why it matters | Covered by |
|---|---|---|
| Player data in DataStores | Restoring a place never rolls back saves | DataStore versioning ([[Data Loss Prevention and Recovery]]) |
| Package versions and other places' copies | A place restore does not restore a package | Package version history ([[Packages and Asset Reuse]]) |
| Other places in the universe | Each place has its own history | Restore each place |
| Configs, game settings, products | Live outside the place | Activity History shows who changed them; Configs have their own history |
| Uploaded assets (meshes, images, sounds, animations) | Separate assets with their own versions | Asset versions; keep sources on disk |
| Your local drafts | On your machine | Commit them |

## 2. Script History

Right-click a script, **View Script History**: every saved, auto-saved or committed version with date and author, compare with previous, compare two versions, open old versions, open a whole auto-save batch (Docs). For a broken script this is far better than restoring the place, because nothing else is touched. Copy the good version's text back into the script (with the safe-edit checks in [[Command Bar and Studio Scripting]]).

## 3. Auto-recovery files

Local recovery files save you when Studio crashes before a cloud save (Docs):
- With collaboration on, a failed save keeps the last three attempts as recovery files.
- With collaboration off, the **Auto-Recovery Enabled** and **Auto-Recovery Interval (Minutes)** settings apply.
- Windows: the `RobloxStudio\AutoSaves` folder under `%LOCALAPPDATA%\Roblox`; Mac: `~/Library/Application Support/Roblox/RobloxStudio/AutoSaves/`.

**Measured.** In the reference project Studio closed in the middle of a large revert. The work was finished on the recovered autosave copy, then checked against the snapshot taken before the change (every one of 4,697 moved units matched its original transform). Without that independent snapshot nobody could have known whether the recovered file was complete.

## 4. The layered strategy

| Layer | Scope | Lifetime | Restore cost | Tool |
|---|---|---|---|---|
| 1. Pre-attributes | Properties of specific instances | Until the pass is accepted | Seconds, surgical | [[Explorer Properties and Selection]] |
| 2. Change snapshots on disk | Positions, terrain, script sources for one change | Days to weeks | Minutes, surgical | JSON, TerrainRegion, `.lua` copies |
| 3. `.rbxm` exports | Whole models, folders, anything you delete | Permanent archive | Minutes, insert back | Save to File, plugins, archive server |
| 4. Named cloud versions | Whole place | Permanent | Whole-place rollback | Save to Roblox with Notes |
| 5. Script History | One script | Permanent | Seconds | View Script History |
| 6. Git | All code, configs, tooling | Permanent, reviewable | Seconds, diffable | [[Git and Source Control for Roblox]] |
| 7. Local `.rbxl` exports | Whole place offline | As kept | Open file | Save to File / Download a Copy |

Choose the cheapest layer that fully covers the change before you make it. A sensible default for any risky operation: **layer 2 or 3 plus layer 4** (a surgical snapshot and a named version).

## 5. Backups must not live in the place

The natural instinct is to duplicate a folder into `ServerStorage` as `Backup_Shop_0412` before changing it. Do this a hundred times across a team and the place fills with copies.

**Measured.** In the reference project:
- Backup and archive folders inside the place pushed it past about 1.07 million instances; Studio ran at about 15 fps.
- ServerStorage alone went from 1.96 million instances to about 712k after archiving one category of content, and to about 420k after a second; ReplicatedStorage went from about 392k to about 107k, cutting what every client downloads.
- An earlier clean-up moved 735k + 642k instances of imported sources and old animation saves out of the place: the place went from about 2.36M to about 955k.

Backups in `ServerStorage` do not reach clients, but they slow Studio, saves, publishes and every Explorer search, and they inflate the 100 MB place size limit (Docs). Anything in `ReplicatedStorage` or `Workspace` is worse: it is downloaded by every player.

The rule that replaced it: **back up to disk, rely on Version History for the rest.** One safety copy may live in the place while a change is being verified, in one agreed folder, and is removed when the change is accepted.

## 6. Exporting `.rbxm` safely

Ways to get an instance tree onto disk:

| Method | Notes |
|---|---|
| Right-click, **Save to File** in the Explorer | Manual, reliable, one at a time |
| `plugin:PromptSaveSelectionAsync(name)` | Plugin prompts a save dialog for the selection (Docs; the non-Async version is deprecated) |
| `SerializationService:SerializeInstancesAsync({...})` | Returns `.rbxm` content as a `buffer`; callable from plugins or Open Cloud Luau Execution (Docs). No stability promise on the format |
| An archive server | A local HTTP receiver that stores what a tool POSTs (pattern from [[Clip Archive Server]]) |

Example: a plugin-context exporter that posts each top-level child of a folder as a base64 `.rbxm` to a localhost receiver, then reads it back to verify before anything is deleted.

```lua
--!strict
-- Plugin or plugin-security context. Requires a localhost receiver that stores POST bodies.
local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")
local EncodingService = game:GetService("EncodingService")

local RECEIVER = "http://127.0.0.1:8784/archive/"

local function exportOne(inst: Instance, key: string): boolean
	local content: buffer = SerializationService:SerializeInstancesAsync({ inst })
	local b64 = buffer.tostring(EncodingService:Base64Encode(content))
	local ok, err = pcall(function()
		HttpService:PostAsync(RECEIVER .. key, b64, Enum.HttpContentType.TextPlain)
	end)
	if not ok then
		warn("export failed", key, err)
		return false
	end
	-- Verify: fetch it back and compare before trusting the archive.
	local okGet, back = pcall(function()
		return HttpService:GetAsync(RECEIVER .. key .. "?x=" .. os.clock(), true)
	end)
	return okGet and back == b64
end

local folder = game:GetService("ServerStorage"):FindFirstChild("OldContent")
assert(folder, "no ServerStorage.OldContent")
local okCount, total = 0, 0
for _, child in folder:GetChildren() do
	total += 1
	if exportOne(child, (child.Name:gsub("[^%w_%-%.]", "_")) .. ".rbxm.b64") then
		okCount += 1
	end
	task.wait(0.13) -- stay well under the 500 requests/minute HttpService limit (Docs)
end
print(("archived and verified %d/%d"):format(okCount, total))
-- Only delete the originals when okCount == total.
```

Notes:
- The reference project's deletions of large backup sets were done only after a **round-trip verification** (25 of 25 archives re-imported identically) (Measured).
- Pace requests: the archive tools waited 0.13 s between requests, and on "Number of requests exceeded limit" stopped for a full minute (Measured).
- Keep a manifest file (key, original path, date, reason) next to the archives; a pile of anonymous `.rbxm` files is not a backup anyone can use.

## 7. Restoring from snapshots, by example

| Situation | Best restore |
|---|---|
| Bulk property pass looks wrong | Revert from Pre-attributes |
| A system script was broken by a bad edit | Script History, or the `.lua` copy from your snapshot |
| A world area was rebuilt and the client hates it | Insert the `.rbxm` export, swap folders |
| Terrain region damaged | `Terrain:PasteRegion` from the TerrainRegion snapshot |
| Someone deleted an area yesterday | Open Local Copy of an older version, copy that area out, paste into the live place (do not restore the whole place) |
| The whole place is broken after a bad publish | Restore the last good version, publish, restart servers |

The "copy from an old version" technique is underused: open the old version as a local copy, select what you need, copy, switch to the live place, **Paste Into At Original Location**. Everything else in the live place survives.

## 8. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Backup folders inside the place | Slow Studio, bloated place | Disk exports; one temporary safety copy max |
| Restoring during a live Team Create session | Overwritten by collaborators' auto-save | Disable Team Create first |
| Restoring and expecting players to see it | Restore is not publish | Publish and restart servers |
| Whole-place restore for a local problem | Throws away everyone's other work | Copy the area out of an old version |
| Relying on undo as a backup | Interleaved history rolls back others' work | Snapshots |
| No notes on saves | The right version cannot be found | Save with Notes before risky work |
| Deleting after export without verifying | Corrupt or empty archives discovered later | Round-trip check |

## 9. Checklist

- [ ] Named save with notes before every risky change.
- [ ] Surgical snapshot (attributes, JSON, TerrainRegion, `.lua`) for the specific change.
- [ ] Removed content exported to disk, verified, listed in a manifest.
- [ ] No permanent backup folders in the place.
- [ ] Auto-recovery on and the folder checked.
- [ ] Restore procedure written down: disable Team Create, restore, publish, restart.
- [ ] Code in Git, independent of place versions.

## See also

- [[Team Create and Collaboration]], [[Command Bar and Studio Scripting]], [[Explorer Properties and Selection]]
- [[Release Process and Rollbacks]], [[Case Study - Instance Cleanup and Place Size]], [[Data Loss Prevention and Recovery]]
- [[Git and Source Control for Roblox]]
- Animation section: [[Clip Archive Server]], [[Baked Clip Stubs and Archiving]], [[Case Study - Cutting a Million Instances]]

## Connected notes
<!-- auto-links:start -->
[[Safe Changes in a Shared Place]] · [[Studio Interface Tour]] · [[Batch Processing Tools in Studio]] · [[Studio Settings and Shortcuts]] · [[Packages and Shared Assets Across Places]] · [[Team Create Permissions and Workflows]]
<!-- auto-links:end -->
