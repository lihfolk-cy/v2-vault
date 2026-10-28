---
tags: [case-study, performance, instances, cleanup, place-size, studio, production]
---
# Case Study: Instance Cleanup and Place Size

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Keeping imported sources and editor saves in the place.
> - Avoid: "Set aside" folders that nobody ever empties.
> - Avoid: Deleting on a full-name grep only.
> - Per-folder instance counts recorded weekly, client-replicated folders separately.
> - No backup folders in the place; originals as attributes, copies on disk.
> - A written deletion policy with the reference-proof procedure.
>
> Read more (14 KB note): ## Timeline of cuts · ## Proving something is unreferenced · ## Common mistakes · ## Checklist
<!-- tldr:end -->

This case study is about the place as a file and a working environment: how one live action game (the reference project) grew to millions of instances, what that did to Studio, saves and joins, how the team cut it back, and the policies that decided what could be deleted. The animation-specific techniques (baking keyframe data into compact stubs, the clip archive) are covered in [[Case Study - Cutting a Million Instances]] and [[Baked Clip Stubs and Archiving]]; this note covers the process and the non-animation causes.

## Why place size matters

Instances cost in three places:

| Where | Who pays | Symptom |
|---|---|---|
| ReplicatedStorage, ReplicatedFirst, Workspace (non-streamed) | Every client, before or during join | Slow joins, memory on phones |
| ServerStorage, ServerScriptService | Every server and Studio | Server memory, server start time |
| Anywhere in the place | Studio and the cloud | Slow Explorer, slow saves, failed cloud saves, slow publish |

Teams watch the first row and forget the third. In the reference project the Studio-side cost became the crisis first: at about 1.07 million instances Studio ran at about 15 fps and used about 18 GB of memory (measured), and later, during heavy work, every cloud save in one session timed out and the place reopened at the previous day's version (measured). A slow Studio slows every person on the team for every task.

## How the place grew

The growth came from five sources, none of them gameplay content:

1. **Animation data as instances.** Keyframe sequences stored densely (every joint keyed at 16 to 25 fps) made one enemy animation folder 323k instances on its own. See [[Case Study - Cutting a Million Instances]].
2. **Imported sources kept "just in case".** Imported packs, original asset sources and editor animation saves sat in storage folders: 735k and 642k instances in two folders.
3. **Safety copies.** Each tool pass kept a copy of what it changed inside the place. One pose-thinning pass kept a backup of about half a million instances; a folder of per-pass safety copies reached 330k instances.
4. **Dead weight.** Models of removed enemies with their own animation copies, weapon models that were no longer items, test rigs and over a hundred development dummies.
5. **Terrain.** One retired area's terrain held about 21 million voxel cells; deleting the area took terrain from about 32M to about 11M cells (measured).

## Timeline of cuts

| When | Pass | Result (measured) |
|---|---|---|
| Week 1 | Load-time archive: imported sources (735k), editor animation saves (642k), old backups, development dummies moved to an archive folder, exported to disk by the owner, then removed | about 2.36M to about 955k |
| Week 1 | Dead-weight export and removal (312k: enemy models' own animation copies, removed enemies' clips, non-item weapon models, dated backups) | about 955k to about 599k |
| Week 2 | Cleanup pass with an inventory of what references what | about 190k instances deleted |
| Week 2 | Deletion of the half-million-instance backup approved, but blocked by an automated permission check; left for the owner to delete by hand | |
| Week 3 | All in-place backup folders purged (every safety copy, imported sources, export staging, all dated backups) | about 1.07M to about 600K |
| Week 3 | A retired area deleted | about 19k instances; terrain about 32M to about 11M cells |
| Week 4 | Player animation clips baked to stubs, originals archived to disk | ReplicatedStorage 392k to 107k |
| Week 4 | Enemy clips baked to stubs (well over a thousand clips, dozens of kits) | ServerStorage 1.96M to 712k, then 420k after the player-clip archive left the place |
| Week 4 | Storage cleanup (stale config copies, backup folders that had crept back) | ServerStorage about 715k to about 690k |
| Week 4 | Weapon rig clips baked and importer leftovers removed | ReplicatedStorage about 108k to about 69k |

Two patterns stand out. First, the place regrew after each cut, because the habits that grew it (safety copies, "set aside" folders) continued. Second, the biggest durable wins came from changing the *representation* (keyframes to buffers), not from deleting.

## The deletion policy, three versions

The hardest part of cleanup is not the code; it is deciding what may be deleted. The reference project's policy changed twice, and each version had a reason.

**Version 1 (the first weeks): never delete, set aside.** Anything replaced went into a storage folder. Safe for individuals, disastrous in aggregate: storage became the largest part of the place.

**Version 2 (around week 2): remove what is not needed, after proving nothing references it.** The owner's words: "I do not need to export things that we will not use again." During a pass, one safety copy per workstream in a known folder; the lead deletes it after verification.

**Version 3 (around week 3): no backup folders in the place at all.** After the 15 fps / 18 GB crisis: "backups are not necessary". Back up to disk (source copies and `.rbxm` exports), store reversible originals as attributes, and rely on Roblox version history for everything else. See [[Safe Changes in a Shared Place]].

Version 3 had a cost the team accepted knowingly: some old revert recipes in the notes now pointed at deleted folders ("no revert path"). The notes said so explicitly.

## Proving something is unreferenced

"Prove nothing references it" needs a procedure. The reference project's included:

1. **Grep all script sources** for the instance name, with a plain substring search. Patterns with a leading `[^\n]*` are quadratic on long single-line sources (base64 data modules) and froze Studio once; use `string.find(src, name, 1, true)`.
2. **Grep for dynamic lookups**: the stem of names built at runtime (`"Kit_" .. id`, tables of names in config). A grep for the full name misses these.
3. **Check `ObjectValue`s** and attributes that hold paths.
4. **Check config and registries**: item tables, ability registries, icon tables, sound tables.
5. **Check comments.** Not for safety, but so the comments do not lie afterwards.
6. **Check who owns it.** Undocumented folders from other workstreams were asked about, not deleted.

```lua
--!strict
-- Report everything that might reference `target`: script mentions of its name, and ObjectValues pointing into it.
local SERVICES = { "Workspace", "ReplicatedStorage", "ReplicatedFirst", "ServerStorage",
	"ServerScriptService", "StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService" }

local function referencesTo(target: Instance): { string }
	local found = {}
	local name = target.Name
	for _, serviceName in SERVICES do
		for _, inst in game:GetService(serviceName):GetDescendants() do
			if inst:IsDescendantOf(target) then
				continue -- references from inside the folder itself don't keep it alive
			end
			if inst:IsA("LuaSourceContainer") then
				local ok, src = pcall(function() return (inst :: any).Source end)
				if ok and typeof(src) == "string" and string.find(src, name, 1, true) then
					table.insert(found, "source: " .. inst:GetFullName())
				end
			elseif inst:IsA("ObjectValue") then
				local v = inst.Value
				if v and (v == target or v:IsDescendantOf(target)) then
					table.insert(found, "ObjectValue: " .. inst:GetFullName())
				end
			end
		end
	end
	return found
end

local candidate = game:GetService("ServerStorage"):FindFirstChild("OldBackups")
if candidate then
	local refs = referencesTo(candidate)
	print(#refs == 0 and "no references found" or table.concat(refs, "\n"))
end
```

"No references found" means "no references this script can see", not "safe". Code that reaches the folder by iterating a parent's children (`for _, x in ServerStorage:GetChildren()`) references it without naming it. Read the hits, then export to disk before deleting.

## Measure before cutting

Always produce a per-folder count first and sort by size. The reference project's counts showed that two folders held most of the place, which focused the first pass. A count script is in [[Case Study - Cutting a Million Instances]]; run it in chunks or on one service at a time in very large places, because a full `GetDescendants` walk of millions of instances in one command-bar call can stall Studio.

A second useful measurement is **what clients download**: count ReplicatedStorage and ReplicatedFirst separately from storage. In the reference project the late measurement "ReplicatedStorage = over 100k instances, all replicated before the game is loaded (character models about a third, well over a hundred kit folders about 40%)" redirected effort from storage cleanups to join time. See [[Case Study - Fast Join and Deferred Loading]].

## Scripts are part of place size

The place's scripts also had size problems, of a different kind:

- **Source limit.** A script's `Source` cannot exceed 200,000 characters (measured). Two core modules crossed it and could not be saved until split into child modules (each from just over 201k to about 175k to 178k plus a child). The split was verified by clone-requiring old and new and deep-comparing: 0 differences.
- **Module load cost.** The client required well over a hundred ability-kit modules of about 40 to 190k characters each (tens of megabytes of source) at start, through over a hundred small client scripts (measured). That costs load time and memory even if per-frame cost is low. Lazy requiring (only when the weapon is equipped) is the fix. See [[Ability Kits Architecture]].

## Things that kept adding instances

Cleanup is ongoing because content keeps arriving. Additions in the same period:

- several hundred invisible edge walls to stop players falling off the lobby, later rebuilt as a couple of hundred taller walls on the outer outline only (a better algorithm cut the count by two thirds);
- over a thousand flat wall parts plus lips, bands and chunks for a lobby restyle (a few thousand parts);
- several hundred armour MeshParts, then nearly a thousand more for a second area's sets;
- per-weapon effects and rig folders at up to 2,500 instances each (several kits ran 3,000 to 5,400).

Budgets per content unit (instances per zone, per kit, per armour set) are the only way to keep growth deliberate. See [[Planning and Scoping a Roblox Game]].

## Results

At the end of the period: ReplicatedStorage at about 70k instances (from a peak near 600k), storage at about 420k to 690k depending on archive state, every in-place backup gone, every animation clip either published-equivalent or a compact stub with its original on disk. Studio was usable again. The remaining big items were known and listed: character models (tens of thousands), and kit folders, both candidates for deferred loading.

## A weekly size routine

Rule of thumb for any team past a few hundred thousand instances: a ten-minute weekly routine prevents most crises.

1. **Record counts** for Workspace, ReplicatedStorage, ReplicatedFirst, ServerStorage and terrain cells in the notes, next to last week's numbers.
2. **List the top ten folders** by count and name an owner for each.
3. **Flag anything new and large** that nobody documented, and ask its owner.
4. **Check for backup-shaped names** (dated suffixes, "Backup", "Old", "WIP") and move them to disk.
5. **Check script sizes** against the 200,000-character limit and flag anything above about 150,000.
6. **Do one save and confirm it succeeded**, noting how long it took; a save that is getting slower is an early warning.

The reference project had most of these numbers, but only when someone went looking during a crisis. Recorded weekly, the growth from about 600k to 1.07M instances would have been visible days before Studio dropped to 15 fps.

## Lessons

1. **Studio performance is team performance.** Treat place size as a budget from day 1.
2. **Backups in the place are the most common hidden cause of bloat.** Use attributes and disk.
3. **Representation beats deletion.** Converting dense instance data to compact data gave the largest durable wins.
4. **Deletion needs a written policy and a procedure**, including dynamic names and ownership.
5. **Measure by folder, sort, cut the biggest safe thing first.**
6. **Separate client cost from Studio cost** in your measurements; they need different fixes.
7. **Expect regrowth.** Re-measure weekly and keep per-unit budgets.

## Common mistakes

- Keeping imported sources and editor saves in the place.
- "Set aside" folders that nobody ever empties.
- Deleting on a full-name grep only.
- Running one huge walk of millions of instances in a single call.
- Cleaning storage while the client download (ReplicatedStorage) stays large.

## Checklist

- [ ] Per-folder instance counts recorded weekly, client-replicated folders separately.
- [ ] No backup folders in the place; originals as attributes, copies on disk.
- [ ] A written deletion policy with the reference-proof procedure.
- [ ] Dense data converted to compact representations where possible.
- [ ] Script sizes reported; modules split before 200,000 characters.
- [ ] Per-unit instance budgets for content.

## See also

- [[Case Study - Cutting a Million Instances]], [[Baked Clip Stubs and Archiving]], [[Clip Archive Server]] (Animation section)
- [[Memory Budgets and Leaks]], [[Performance Fundamentals]], [[Developer Console and Stats]]
- [[Safe Changes in a Shared Place]], [[Version History and Backups]]
- [[Case Study - Fast Join and Deferred Loading]], [[Post-Mortem - Building a Melee Action Game]], [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Batch Processing Tools in Studio]] · [[Safety Rules for AI Agents in Studio]] · [[Performance and Memory]] · [[Documentation and Knowledge Bases]] · [[Case Study - Building a Game with AI Agents]] · [[Instance Count]]
<!-- auto-links:end -->
