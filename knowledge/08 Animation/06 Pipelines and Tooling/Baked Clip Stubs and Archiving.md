---
tags: [pipeline, performance, memory, keyframesequence, baking]
---
# Baked Clip Stubs and Archiving

<!-- tldr:start -->
> [!tldr] TL;DR
> - All consumers of the clips read through the Lua player (or only read markers / names / length).
> - No `RegisterKeyframeSequence` on these clips anywhere.
> - Archive server running; `Ping` ok.
> - `Run({ dry = true })` first: skipped list reviewed (duplicates, errors over 0.25).
> - `Run`, then `Verify`: zero bad.
> - Instance counts before and after recorded.
>
> Cost: TL;DR ~130 tok · whole note ~3.1k tok. Read more: ## Anatomy of a stub · ## Three bakers, three subtleties · ## Checklist
<!-- tldr:end -->

How one live action game removed almost every Pose instance from its place without losing a single clip: each KeyframeSequence becomes a **stub** (no Poses, the motion stored as a compact binary buffer in an attribute), the original is **archived to disk** as an `.rbxm`, and a Lua player reads the buffer. Numbers and the story: [[Case Study - Cutting a Million Instances]]. Buffer layout: [[Clip Buffer Format]]. The disk archive: [[Clip Archive Server]].

## The problem: Poses are instances

A KeyframeSequence is a tree: one Keyframe per time, one Pose per joint per keyframe (plus placeholder Poses for the hierarchy), plus markers. A 1.5 s attack clip keyed densely on 15 joints is several hundred instances. Multiply by every clip in the game:

| Where | Instances (one production place) |
|---|---|
| Animation Editor saves (`RBX_ANIMSAVES`) | 642k |
| enemy clips baked with every joint keyed at 16-25 fps (replicated storage) | 323k |
| a pose-thinning backup | 512k |
| an enemy re-key backup | about 385k |
| enemy work-in-progress set | 112k |

Everything in ReplicatedStorage is downloaded by every client on join; everything in the place is loaded by Studio and every server. Studio dropped to about 15 fps at over a million instances. Pose data is also verbose as instances: a 12-number CFrame, a weight, two easing enums, a name and a parent reference per key.

## The idea

1. **Encode** the clip's motion into a binary buffer: per-joint key thinning that changes playback by at most 0.03 deg / 0.002 studs, quaternions packed "smallest three" into 6 bytes, offsets quantised to 16 bits per axis.
2. **Store** the buffer base64-encoded in a string attribute (`KSB`) on a **stub** KeyframeSequence that keeps everything other code reads (name, loop, priority, attributes, tags, markers, named keyframes, first and last keyframes) and **no Poses**.
3. **Archive** the original to disk, read it back, compare, and only then destroy it in the place.
4. **Play** stubs with a Lua keyframe player that reads the buffer ([[Lua Keyframe Player]], [[Weapon Rig Player]]).

## Anatomy of a stub

```lua
local function makeStub(ks: KeyframeSequence, b64: string): KeyframeSequence
	local s = Instance.new("KeyframeSequence")
	s.Name = ks.Name
	s.Loop = ks.Loop
	s.Priority = ks.Priority
	s.AuthoredHipHeight = ks.AuthoredHipHeight
	for k, v in ks:GetAttributes() do s:SetAttribute(k, v) end
	for _, tag in CollectionService:GetTags(ks) do CollectionService:AddTag(s, tag) end
	local kfs = ks:GetKeyframes()
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	for i, kf in kfs do
		-- keep only keyframes something can observe: first, last, named, or carrying markers
		if i == 1 or i == #kfs or kf.Name ~= "Keyframe" or #kf:GetMarkers() > 0 then
			local k = Instance.new("Keyframe")
			k.Name = kf.Name
			k.Time = kf.Time
			for a, v in kf:GetAttributes() do k:SetAttribute(a, v) end
			for _, c in kf:GetChildren() do
				if not c:IsA("Pose") then c:Clone().Parent = k end        -- markers and anything else, never Poses
			end
			k.Parent = s
		end
	end
	for _, c in ks:GetChildren() do
		if not c:IsA("Keyframe") then c:Clone().Parent = s end             -- non-keyframe children survive
	end
	s:SetAttribute("KSB", b64)                                          -- the motion
	s:SetAttribute("KSBaked", os.date("!%Y-%m-%d"))                     -- provenance
	return s
end
```

Why keep those keyframes: plenty of code reads clips without playing them. In the reference project, ability lengths, a stance system's timing, the move preview, the effect "juice" table, the ultimate camera, a weapon ignition effect and the kits' own Moves modules all called `GetKeyframes`, `GetMarkers` or computed the length from the last keyframe. A stub answers all of those identically.

Attributes used:

| Attribute | Meaning |
|---|---|
| `KSB` | base64 of the binary clip buffer |
| `KSBaked` | bake date |
| `KSOff` | comma-separated joints a runtime copy leaves out (an upper-body copy made at runtime) |
| `KSArc` | archive key (`<Kit>/<Clip>`) for clips whose archive path is not derivable from the place path |

## The bake procedure (per clip)

```
for each target KeyframeSequence (yield every 50 ms):
    skip if already a stub (has KSB)
    skip if two siblings share its full name (the archive could not tell them apart)
    buffer = Encode(original); b64 = Base64(buffer)
    stub   = makeStub(original, b64)
    worst  = compare(read(original), read(stub))          -- both read the runtime way
    if worst > 0.25: discard the stub, report, leave the original
    archive the original (serialize -> .rbxm on disk), read it back, check
    replace the original with the stub (same parent, same name); destroy the original
```

**The comparison** is what makes the bake safe:

- length equal (within 1e-4), loop and priority equal;
- the sorted event lists equal (time, keyframe name, marker name, marker value);
- the same joint set;
- every joint sampled at **30 Hz** (`ceil(length * 30)` steps, clamped to 10-240, plus **2 samples past the end** to check the held last pose) through the same sampler the runtime uses;
- worst error = max over samples of `max(angle in degrees, position error in studs x 100)`. So **0.01 studs counts as 1 deg**, and the reject threshold is **0.25**.

"The runtime way" is the point: the original is read by the player's Pose parser, the stub by its buffer decoder, both sampled identically. The check proves the stub plays like the original **in the player that will play it**.

## Three bakers, three subtleties

| Baker | Targets | Special rule |
|---|---|---|
| Player clips | every KeyframeSequence directly in each ability kit folder (several hundred move clips), the equip flourishes, the default-animation copies | archive path = the clip's replicated-storage path |
| Enemy clips | every clip in the server-side clip-source folder (well over a thousand clips in dozens of kits) | the server streams a stub's `KSB` **as is** to clients, byte for byte what the encoder made of the original, so live playback is unchanged |
| Weapon-part clips | every clip in each kit's `ItemRig` folder (a few hundred clips) | the buffer is written **from the weapon rig player's own reading** (joints keyed `Part0\0Part1`, its per-joint interpolation choice, its easing), so the rig player plays a stub exactly as it played the original |

The weapon-part baker also had a gate: **kits whose code still played weapon-part clips through `RegisterKeyframeSequence` were skipped**, because that path needs real Poses (and only worked in Studio anyway). Those kits (dozens of them) were switched to the rig player first, then baked. Unused importer `AnimSaves` folders on weapon models (a handful of clips that nothing played) were archived and removed in the same pass.

Results: weapon-part stubs verified within 0.04 deg; end to end on real rigs worst 0.049-0.056 deg. One kit's handful of clips stayed unbaked: big translations quantised to 16 bits gave 0.28-0.31, just over the bar.

## Operations every baker exposes

| Operation | What it does |
|---|---|
| `Targets()` | the list it would bake (and why kits are skipped) |
| `Status()` | per kit: baked / total, instance counts |
| `Run(opts)` | bake every unbaked target (`kits`, `list`, `dry`, `maxErr`); archives and reads back before destroying the original |
| `Verify(opts)` | every stub against its archived original: identical events and joints, sampled at 30 Hz, and for streamed kits **buffer == Encode(original)** |
| `Restore(list)` | archived originals back in place of the stubs; attributes set on the stub since the bake are copied over (except `KSB`, `KSBaked`, `KSOff`) |
| `FetchOriginal(stub)` | the archived original, unparented, read-only (for tools that only measure Poses) |
| `Ping()` | is the archive server running? |

Archive operations need the local archive server running, and they pace requests 0.13 s apart to respect the HttpService budget of about 500 requests per minute ([[Clip Archive Server]]).

## The rules

1. **Restore, work, Run.** Before editing a stub's motion in the Animation Editor, re-baking arms, fixing axes, re-keying, or anything that reads or writes Poses: `Restore` that kit, do the work, `Run` again. Tools that edit Poses (axis fix, root-yaw strip, frame-rate fixes, re-keys) restore their kit themselves.
2. **Never hand-edit a stub.** It has no Poses; the Animation Editor shows an empty clip, and saving from it would overwrite the attribute-less version.
3. **A newly built kit stays unbaked until its final verify,** then gets baked. New or swapped enemy kits arrive unbaked and stream fine until the next `Run`.
4. **A/B against the real Animator skips stubs** (the Animator cannot read them; they fall back to the Lua player). Restore a kit before A/B testing it.
5. **Nothing that needs Poses may consume stubs:** the Animator, `RegisterKeyframeSequence`, the Animation Editor, older tools that walk Poses. Find them first (grep for `GetPoses`, `GetSubPoses`, `:IsA("Pose")`, `RegisterKeyframeSequence`).
6. **No backups inside the place.** Originals live on disk. The reference project first kept them in a server-storage archive folder (291k instances) and later moved them out entirely after an explicit rule: no backup folders in the place.

## Results on record

| Set | Before | After |
|---|---|---|
| Player clips (several hundred move clips, flourishes, default copies) | ReplicatedStorage 392k | 107k |
| Enemy clips (well over a thousand) | ServerStorage 1.96M | 712k, then 420k once the in-place archive moved to disk |
| Weapon-part clips (two batches of one to two hundred) | ReplicatedStorage about 108k | about 83k, then about 69k |
| Load-time archive of editor saves, imports and old backups | place about 2.36M | about 955k |

Enemy streaming after baking: each kit 19-235 KB as buffers, about 1.6 MB for the roster, server build 0.23 s.

## Other dead weight worth hunting

- **Animation copies inside models** that a spawner destroys on every clone anyway (207k instances on enemy models in one case). Move clip sources out of models.
- **Clips for content no longer in the game** (69k for about a dozen retired enemies).
- **Importer save folders** (`RBX_ANIMSAVES`, `AnimSaves` under imported models).
- **Old clip versions kept "just in case"**: archive to disk, delete.
- Before deleting anything: export it, and search scripts for references by name and path.

## Trade-offs

- **You need a player.** The real Animator cannot play a stub. If you use published assets for everything, you do not need stubs at all: published clips do not live in the place.
- **Tooling must respect the cycle.** Every Pose-editing tool needs a restore step. Put it in the tool, not in a human checklist.
- **Precision is bounded** by 16-bit quantisation of offsets per joint (scaled to that joint's maximum offset). Big translations (a weapon part flying several studs) quantise coarser; that is the one case that failed the 0.25 bar.
- **Archive availability.** Restore needs the disk archive and its server. Back the archive folder up like source code.

## Checklist

- [ ] All consumers of the clips read through the Lua player (or only read markers / names / length).
- [ ] No `RegisterKeyframeSequence` on these clips anywhere.
- [ ] Archive server running; `Ping` ok.
- [ ] `Run({ dry = true })` first: skipped list reviewed (duplicates, errors over 0.25).
- [ ] `Run`, then `Verify`: zero bad.
- [ ] Instance counts before and after recorded.
- [ ] Pose-editing tools restore their kit themselves.

## See also

[[Clip Buffer Format]], [[Clip Archive Server]], [[Lua Keyframe Player]], [[Weapon Rig Player]], [[Case Study - Cutting a Million Instances]], [[Performance and Memory]], [[KeyframeSequence Keyframe and Pose Reference]], [[Publishing Animations]]

## Connected notes
<!-- auto-links:start -->
[[Case Study - Instance Cleanup and Place Size]] · [[Snippets - Building and Sampling Clips]] · [[Animation Data from Blender to Roblox]] · [[Authoring Clips in Code]] · [[Version History and Backups]] · [[Batch Processing Tools in Studio]] · [[Animation Start Here]]
<!-- auto-links:end -->
