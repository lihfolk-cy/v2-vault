---
tags: [case-study, performance, memory, instances, baking, type/case-study, area/animation, level/intermediate, area/performance]
---
# Case Study: Cutting a Million Instances

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Deleting before measuring by folder. Symptom: weeks of work on small folders while one huge folder remains.
> - Avoid: Cleaning without a reader audit. Symptom: features silently break because a script walked the deleted Poses.
> - Avoid: Assuming streaming solves ReplicatedStorage bloat.
>
> Cost: TL;DR ~110 tok · whole note ~3.7k tok. Read more: ## Step 5: stubs and buffers · ## Nuances and edge cases · ## Common mistakes in production
<!-- tldr:end -->

One live action game's place grew to about **2.36 million instances**, most of them animation data, and Studio crawled at about 15 fps. Over a few weeks a series of passes took it below a million, cut ReplicatedStorage (what every client downloads) by hundreds of thousands of instances, and did it without losing a single clip. This is the order of operations, the techniques, the numbers, and the rules that kept it safe. Mechanisms: [[Baked Clip Stubs and Archiving]], [[Clip Buffer Format]], [[Clip Archive Server]].

## Why instances, specifically

Every instance costs, in every context that loads it:

| Where it lives | Who pays |
|---|---|
| ReplicatedStorage, Workspace | every client on join (download, deserialise, memory), every server, Studio |
| ServerStorage, ServerScriptService | every server and Studio (not clients) |
| anywhere in the place | Studio's Explorer, saves, publishes, version history |

Animation data is uniquely instance-heavy. A KeyframeSequence is one instance per keyframe plus one per Pose (including placeholder Poses for the hierarchy) plus markers. A dense clip keyed at 20 fps on 15 joints for 2 s is around 40 keyframes x (15 poses + placeholders): roughly 700 instances for two seconds of motion. The same motion as a binary buffer is a few kilobytes in one attribute.

## Step 0: measure by folder

You cannot cut what you have not located. A command-bar script that prints instance counts per top-level folder, recursively for the biggest ones:

```lua
local function count(root: Instance): number
	return #root:GetDescendants() + 1
end
local function report(root: Instance, depth: number, minShare: number)
	local total = count(root)
	local rows = {}
	for _, c in root:GetChildren() do
		local n = count(c)
		if n >= total * minShare then table.insert(rows, { c, n }) end
	end
	table.sort(rows, function(a, b) return a[2] > b[2] end)
	for _, r in rows do
		print(string.rep("  ", depth) .. r[1]:GetFullName(), r[2])
		if depth < 3 and r[2] > 20000 then report(r[1], depth + 1, minShare) end   -- drill into the big ones
	end
end
for _, svc in { workspace, game:GetService("ReplicatedStorage"), game:GetService("ServerStorage") } do
	print(svc.Name, count(svc))
	report(svc, 1, 0.02)
end
```

(Run it in pieces on a very large place; `GetDescendants` on millions of instances takes a while.)

What the first measurement found, roughly:

| Bucket | Instances |
|---|---|
| imported source models kept "for reference" | 735k |
| Animation Editor saves (`RBX_ANIMSAVES`) | 642k |
| old dated backups, test leftovers | the rest of about 1.5M archivable |
| enemy clips in ReplicatedStorage, every joint keyed at 16-25 fps | 323k |
| ReplicatedStorage total | about 600k |

## Step 1: archive what nothing uses (biggest, safest first)

Imported sources, editor saves, every backup older than a cutoff and test leftovers (about 1.5M instances) were gathered into one folder, **exported to an `.rbxm` by a human and confirmed**, then removed from the place.

**Place: about 2.36M -> about 955k instances.** ServerStorage dropped to 277k.

Rules applied:

- Export first, confirm the export opens, then delete.
- Note in the project's documentation where every archived path now lives, so tools and people that referenced them know to re-insert first.
- Tools that read archived data (one read editor saves to rebuild animation definitions) must be updated or documented as "needs the archive inserted".

## Step 2: stop making backups inside the place

The project's own safety habit (one backup folder per risky change) had quietly rebuilt the problem: ServerStorage backup folders reached about a million instances again, with Studio back at about 15 fps. A rule change deleted them all (**1.07M -> about 600k**) and banned backup folders in the place: back up to disk (source files, `.rbxm` per asset) and rely on Roblox version history.

**Lesson:** a safety habit that costs instances needs a retention policy, or it becomes the problem.

## Step 3: delete dead weight with evidence

Targeted cleanups, each found by asking "what reads this?":

| Dead weight | Instances | Why it was dead |
|---|---|---|
| animation copies inside enemy models | 207k | the spawner destroyed them on every clone anyway; clip sources were moved out of the models |
| clips for a dozen or so enemies no longer in the game | 69k | no definition referenced them |
| retired reaction clips replaced by procedural motion | about 20k | moved out, later deleted |
| one general cleanup | about 190k | unreferenced models and folders |

Before deleting: search every script for the name and the path, check definition tables, export to disk.

## Step 4: thin what must stay

Before going binary, simply keying less helped:

- per-joint key thinning where interpolation reproduces the motion (0.75 deg / 0.03 studs in the arm baker's body thinning; 0.004 rad for weapon hinges; 0.03 deg in the buffer encoder);
- spacing weapon-part clips at 0.12-0.19 s instead of 0.05 s;
- dropping secondary clips that nothing plays.

Thinning has a floor: the Pose tree overhead remains. The big win needed a different representation.

## Step 5: stubs and buffers

Three bakers converted clips to **stubs**: KeyframeSequences with no Poses, only the keyframes something can observe (first, last, named, with markers), the motion stored as a base64 binary buffer in an attribute, read by a Lua keyframe player. Originals went to a disk archive through a local server, each read back and compared before deletion.

| Pass | Scope | Before | After |
|---|---|---|---|
| player clips | several hundred ability clips, equip flourishes, default animation copies | ReplicatedStorage 392k | **107k** (about 285k fewer on every client) |
| enemy clips | well over a thousand clips in dozens of kits (server-side, streamed to clients) | ServerStorage 1.96M | **712k** |
| archive moved to disk | the in-place archive of player originals (291k) | ServerStorage 712k | **420k** |
| weapon-part clips, batch 1 | over a hundred clips in a few dozen kits | ReplicatedStorage about 108k | about 83k |
| weapon-part clips, batch 2 | about two hundred clips in dozens of kits (after switching them off a Studio-only playback path) | about 83k | **about 69k** |

Each bake was verified: the stub read back through the runtime sampler within 0.25 (degrees, with 0.01 studs counting as 1) of the original at 30 Hz, typically far better (weapon-part stubs within 0.04 deg; end to end on real rigs 0.049-0.056 deg). One kit's handful of clips failed the bar on position quantisation (0.28-0.31) and stayed unbaked.

## Step 6: stream instead of replicate

Enemy clips never needed to be in ReplicatedStorage at all. They moved to ServerStorage; the server compiles each kit into buffers (19-235 KB per kit, about 1.6 MB for the roster, built in 0.23 s from stubs) and **streams a kit to a client the first time that client needs it**. Clients that never meet a boss never download its clips. While a kit is in flight, rigs hold a procedural pose instead of T-posing.

## Counter-pressure: things that added instances

Not every change shrank the place. Ground-fitting a couple of hundred enemy clips added about 26k instances (keys only where the ground needed them); the arm re-bake grew some clips by up to 15% + 30 instances each under a 2,500-per-folder cap. Budgets per folder, enforced by tools, kept growth bounded while the big cuts happened elsewhere.

## Results

| Measure | Start | End |
|---|---|---|
| whole place (archive pass) | about 2.36M | about 955k |
| backup folders (rule change) | about 1.07M | about 600k |
| ReplicatedStorage | about 600k | about 69k at the last measurement (after the player-clip and weapon-part bakes) |
| ServerStorage after the content grew again (new enemy roster) | 1.96M | 420k |
| Studio | about 15 fps at over 1M instances | responsive |
| clips lost | | none: every original on disk, every stub verified |

Figures come from different days and different folders, and new content kept arriving between passes (a whole new enemy roster pushed ServerStorage back to 1.96M before the enemy bake), so they are not one consistent ledger. The pattern is the point: each pass removed hundreds of thousands of instances, and the tools kept them from coming back.

## The rules that kept it safe

1. **Export, read back, compare, then delete.** Never delete on the strength of a write succeeding.
2. **Verify against the reader that will be used.** Stubs were compared through the runtime sampler, not just byte-compared.
3. **Restore, work, rebake.** Any tool that edits Poses restores its kit from the archive first and the bake runs again after.
4. **No backups in the place.** Disk and version history.
5. **Budgets in tools.** A 2,500-instance cap per ability kit folder, refused by installers, kept new content from undoing the work.
6. **Find the readers first.** Code that walks Poses (or plays through Studio-only paths) cannot consume stubs. Dozens of kits had to be switched to the Lua player before their clips could be baked ([[Case Study - Abilities That Only Worked in Studio]]).
7. **Write down where things went.** Every archived path documented, so the next person does not hunt for a folder that is now a file.

## What to do in your game

1. Measure by folder. Sort by size.
2. Archive anything not referenced (editor saves, imports, backups). Export first.
3. Move server-only data out of ReplicatedStorage.
4. Stop per-clone copies (clip sources inside spawned models).
5. Thin keys where interpolation reproduces motion.
6. If you still have hundreds of thousands of Poses and a Lua player is acceptable, bake to stubs and stream.
7. Put budgets into the tools that create content.

## See also

[[Baked Clip Stubs and Archiving]], [[Clip Buffer Format]], [[Clip Archive Server]], [[Lua Keyframe Player]], [[Performance and Memory]], [[Animation LOD]], [[Studio Tooling Architecture]]

## Nuances and edge cases

1. **Instance count is a proxy, not the goal.** What players feel is join time, client memory and frame time; what developers feel is Studio responsiveness and publish time. A million tiny `Pose` instances in ServerStorage hurt Studio and servers but not clients; 50,000 instances of detailed meshes in Workspace hurt clients far more. Measure the outcome you care about (join time on a mid phone, client memory in the developer console, Studio frame rate) before and after each pass, not just the count.
2. **Where the count sits changes who pays.** The table above is the key insight: moving data from ReplicatedStorage to ServerStorage removes it from every client's download, which matters more at 700 joins per hour than one fewer instance in Studio. At small player counts, Studio responsiveness may be the main win; at scale, client download is.
3. **StreamingEnabled does not stream ReplicatedStorage.** Streaming covers Workspace. Everything in ReplicatedStorage is sent to every client at join regardless (Roblox docs (as of October 2026) describe streaming for Workspace content). That is why moving animation data out of ReplicatedStorage paid off so much more than turning on streaming would have.
4. **Team Create sync cost.** In Team Create, very large places also slow collaborative editing: every change syncs, and opening the place downloads it all. A team of four on a 2 million instance place loses minutes per person per day to load times alone.
5. **Version history and place file size limits.** Very large places take longer to save and publish, and auto-saves stall Studio. There are also hard limits on place size; this vault did not confirm the current number, so check the docs if you are near hundreds of megabytes.
6. **Counter-pressure is permanent.** Every new feature wants instances. Budgets in tools (the 2,500 per kit cap) are what keep a cleanup from being undone in three months. Without them, expect the count to return to its old level within a few release cycles.
7. **When not to do this.** If Studio is responsive, join time is acceptable on phones and memory is within budget, a million-instance cleanup is wasted effort. The trigger should be a measured problem, not a number that sounds large.

## Common mistakes in production

1. **Deleting before measuring by folder.** Symptom: weeks of work on small folders while one huge folder remains. Fix: sort folders by descendant count first.
2. **Cleaning without a reader audit.** Symptom: features silently break because a script walked the deleted Poses. Fix: search code for every reader of the data before baking it away.
3. **Assuming streaming solves ReplicatedStorage bloat.** Symptom: streaming enabled, join time unchanged. Fix: move server-only data to ServerStorage and send on demand.
4. **One-time cleanup with no budget.** Symptom: count creeps back. Fix: tool-enforced caps and a periodic report.
5. **Measuring only on a high-end PC.** Symptom: "join is fast" on desktop, slow on phones. Fix: time joins on a low-end phone over mobile data.

## Related decisions

- [[Case Study - Instance Cleanup and Place Size]]: the general version of this cleanup beyond animation data.
- [[Case Study - Fast Join and Deferred Loading]]: the join time outcome this work feeds.
- [[Memory Budgets and Leaks]]: client memory budgets to measure against.
- [[Instance Streaming]]: what streaming covers and what it does not.
- [[Developer Console and Stats]]: measuring memory and instance counts in live servers.
- [[Team Create and Collaboration]]: why very large places hurt collaborative editing.
- [[Batch Processing Tools in Studio]]: running large archive and delete passes safely.
- [[Version History and Backups]]: the safety net during destructive cleanups.
- [[Pipeline Design Principles]]: putting budgets into tools rather than relying on discipline.

## Connected notes
<!-- auto-links:start -->
[[Post-Mortem - Building a Melee Action Game]] · [[Animation Data from Blender to Roblox]] · [[Snippets - Building and Sampling Clips]] · Safe Changes in a Shared Place · Lessons Learned Index · Case Study - Building a Game with AI Agents · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Authoring Clips in Code]] · [[Weapon Rig Player]] · [[Publishing Animations]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Pipeline - Arm IK Baking and QA]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Pipeline - Importing Animated Enemies]] · [[Pipeline - New Animated Weapon]]
<!-- related:end -->
