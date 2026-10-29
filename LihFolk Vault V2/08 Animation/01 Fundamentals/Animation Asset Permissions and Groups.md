---
tags: [fundamentals, publishing, permissions, groups, assets, type/guide, area/animation, level/beginner, api/Animator, api/Animation]
---
# Animation Asset Permissions and Groups

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Staging universe with no grants. Symptom: everything frozen in staging while production works.
> - Avoid: Uploading clips the morning of a release.
> - Avoid: Personal uploads by contractors. Symptom: clips stop being fixable when the contract ends.
> - Every clip id in the manifest is owned by the experience owner or explicitly granted.
> - No temporary (registered) ids anywhere in scripts or data.
> - No ids copied from free models without a grant.
>
> Cost: TL;DR ~160 tok · whole note ~3.8k tok. Read more: ## How animation permissions work now · ## Nuances and edge cases · ## Checklist before a release or transfer · ## Common mistakes in production
<!-- tldr:end -->

An animation asset only plays in an experience that is **allowed** to use it. When it is not, nothing errors in a live server: the track's `Length` stays 0 and the character stands still. This is the single most common reason a working animation "stops working" after a game moves to a group, after a collaborator uploads clips, or after someone pastes an id from a free model. This note explains the current rules (verified against the docs and Roblox announcements as of October 2026), how group ownership works, how to grant access instead of re-uploading, and a pipeline that avoids the whole class of bug.

Separate topic: *replication* (whether other players see a track) is in [[Replication and Ownership]]. Temporary Studio-only ids are in [[Publishing Animations]].

## The rules in one table

| Situation | Plays in the experience? |
|---|---|
| Animation owned by the **same creator** as the experience (you and your game; group and group game) | Yes, always |
| Animation owned by Roblox (default animations, catalog animation packs players own) | Yes, through the normal avatar and Animate paths |
| Animation owned by someone else, **experience granted** on the asset's Permissions page | Yes |
| Animation owned by you, game owned by your group, **no grant** | **No** |
| Animation id copied from a free model or another game | **No**, unless its owner grants your experience |
| Temporary `RegisterKeyframeSequence` / `RegisterAnimationClip` id | Studio only, never live |

## How animation permissions work now

Animations moved into Roblox's **asset privacy and permissions** system. The relevant pieces:

### Access types
- **Restricted**: Roblox checks permission when the asset loads and when creators act on it (insert in Studio, share, list on the Creator Store).
- **Open Use**: anyone can use it; no checks. (Permanent once set.)
- Your own assets **always work in your own experiences**.
- The "Asset Privacy" experience setting that makes new uploads Restricted by default only covers Images, Decals and Meshes. Animations, Audio, Video, Models, MeshParts and Packages have their own creation defaults and are not changed by that setting. As of the August 2025 announcement, **public sharing of animations was not available** (Roblox was "exploring" the Creator Store for it), so treat animations as restricted to their owner plus explicit grants.

### Granting (Creator Hub > the animation's asset page > Permissions)
| Tab | Grants | Rules |
|---|---|---|
| **Collaborators** | A user (must be your connection/friend) or a group (you need the group's edit-experiences permission) | They can use the animation in their own or their group's experiences and can grant it to experiences they can edit. |
| **Experiences** | An experience by universe id (comma-separated for several) | You must be able to edit that experience. **Experience grants cannot be revoked.** Anyone with edit access to that experience can then use the id in its scripts. |

Sharing animations with connections and groups and the Experiences tab went live on **August 21, 2025** (Roblox announcement). At that time, animations inside shared models and packages were "planned next" and bulk permission management was acknowledged as a pain point; check the current state before relying on either.

Revocation nuance: the asset privacy docs say revoking a collaborator only stops them granting **new** experiences; experiences that already got access keep it. The animation announcement says collaborator access "can be revoked at any time". Both can be true: the collaborator loses the ability, existing experience grants stay. Plan as if any experience grant is permanent.

### What a missing permission looks like
| Where | Symptom |
|---|---|
| Studio | The asset fails to load and a clickable error appears in Output. If you have permission but the experience does not, the error offers a pop-up to grant the experience access. |
| Live server | The asset silently does not load: `track.Length` stays 0, the rig does not move, no error visible to players. |

The Studio pop-up is your friend: open the place in Studio as someone with access, play, read Output, and grant from there.

## Group games: the classic trap and the modern fix

**The trap.** A solo developer publishes 200 animations under their personal account, then transfers the game to a group for a team. Every clip stops in live servers, because the experience's owner (the group) does not own them.

**The old fix.** Re-upload every clip under the group and replace every id. Community tools exist that re-upload in bulk and produce an old-to-new id map. Works, but every id changes, and any id missed in a script or a data table becomes a silent failure.

**The current fix.** On each animation's Permissions page, **grant the group game's universe id** in the Experiences tab (you need edit access to that game, which you have as its former owner if you kept a role with edit rights). No ids change. For hundreds of clips this is tedious through the UI; that is the bulk-management pain point Roblox acknowledged.

**The best fix: publish under the right owner from day one.** If a game might ever belong to a group, create the group first and publish every animation as the group. The Animation Editor's publish dialog and the Open Cloud API both let you choose the creator (yourself or a group where you have permission to create assets).

### Team workflows
- Collaborators in Team Create who publish clips should publish **as the group**, not as themselves. A teammate's personal clip in a group game is the trap again, and their account leaving the team does not revoke what was granted, but anything not granted breaks.
- Keep a manifest of every clip id the game uses, with its owner. Audit it before transfers and releases.

## Uploading at scale

- The Animation Editor publishes one clip at a time.
- **Open Cloud Assets API** accepts animations as `.rbxm` / `.rbxmx` files (one asset per call, up to 20 MB). Roblox added this mainly for re-uploading data previously downloaded from Roblox and warns that files edited outside Studio may not upload or work correctly. The announcement planned to deprecate the older cookie-based animation upload endpoint about three months later. API keys can upload for a user or a group creator.
- Never print or commit Open Cloud API keys in tools or logs.

## A pipeline that avoids permission bugs

1. **Decide the owner** (group) before the first upload.
2. **Never hard-code ids in scripts.** Store them as attributes or in one data module: `<Clip>Id` on the clip's folder, one `IdleId` / `SpecialId` per weapon rig, and so on. Installers should create the empty attributes so it is obvious what is still unpublished.
3. **Published id wins.** Loaders use the published id when present and fall back to a development path otherwise (a Lua player in one game; a registered id in Studio).
4. **Publish a rig's clips together.** If half a rig's clips come from published assets and half from a fallback player, two systems write the same joints.
5. **Never invent ids.** Use obvious placeholders (`rbxassetid://0`) and a check that fails the build if any placeholder remains.
6. **Verify in a live test server**, not just Studio: load every id, wait, and report any whose `Length` stays 0.

```lua
--!strict
-- Run in a live test server (server Script). Reports clips that never load.
local ContentProvider = game:GetService("ContentProvider")

local function verifyClips(animator: Animator, animations: {Animation}, timeout: number)
	pcall(function() ContentProvider:PreloadAsync(animations) end)
	local failed = {}
	for _, anim in animations do
		local track = animator:LoadAnimation(anim)
		local t0 = os.clock()
		while track.Length <= 0 and os.clock() - t0 < timeout do task.wait() end
		if track.Length <= 0 then
			table.insert(failed, anim:GetFullName() .. " " .. anim.AnimationId)
		end
		track:Destroy()
	end
	if #failed > 0 then
		warn(("%d clip(s) did not load:\n%s"):format(#failed, table.concat(failed, "\n")))
	else
		print("All", #animations, "clips loaded")
	end
end
```
Run it against a server-owned test rig (a dummy with an AnimationController and server-created Animator in the Workspace). A clip that loads in this live check but not for players points at something else (wrong Animation instance, wrong rig).

## Avoiding assets entirely

One production game ended up not depending on published ids for most clips: it kept clip data in the place (as compact binary buffers in attributes on Pose-free stub clips) and played it with its own Lua keyframe player, which writes `Transform` directly. That removes publishing, permissions and group transfers from the problem, at the cost of building your own player, replication and LOD (see [[Lua Keyframe Player]] and [[Baked Clip Stubs and Archiving]]). A published id still took priority wherever one was set.

| | Published assets | Data in the place + Lua player |
|---|---|---|
| Permission bugs | Possible (ownership, grants) | None |
| Replication | Free (Animator) | Build your own relay |
| Engine features (retargeting, throttling, IK interplay) | Yes | Your responsibility |
| Iteration | Publish per change | Edit and play |
| Client download | Asset fetch per clip | Part of the place |

## Checklist before a release or transfer

- [ ] Every clip id in the manifest is owned by the experience owner or explicitly granted.
- [ ] No temporary (registered) ids anywhere in scripts or data.
- [ ] No ids copied from free models without a grant.
- [ ] Live test server load check passes with zero failures.
- [ ] Group transfer planned: grants prepared or clips published under the group.
- [ ] Collaborators publish as the group.

## See also
[[Publishing Animations]] · [[Replication and Ownership]] · [[Animation Objects]] · [[Lua Keyframe Player]] · [[Case Study - Abilities That Only Worked in Studio]] · [[Debugging Animation Problems]]

## Nuances and edge cases

1. **Grants are per universe, so places share them.** An experience grant covers the universe, which means every place inside it (lobby, match places, test places added to the same experience). A separate staging experience is a different universe and needs its own grants. Teams that run a staging copy as its own experience regularly ship "works in staging" bugs that are really "staging has a grant production lacks", or the reverse. Grant both, and run the live load check in both.
2. **Moderation delay.** Newly uploaded animations go through moderation. A clip referenced in a release immediately after upload can fail to load for a while, or permanently if rejected (unverified how long the window is; it varies). Upload clips a day before a release when you can, and run the load check on the release build, not the dev build.
3. **Account changes.** If a collaborator who owns personally uploaded clips leaves the team, existing grants stay (per the asset privacy docs quoted above), but nobody else can manage those assets, re-grant them to a new experience, or fix them. If that account is ever banned or deleted, what happens to its assets is not something this vault could confirm. The safe pattern is to own everything as the group.
4. **Scale of the manifest.** At 20 clips, a manual check before release is fine. At 500 clips across 40 kits, manual checks miss things. Automate the live load check as part of the release checklist and keep the manifest as data, not a document.
5. **Load check cost and limits.** Loading hundreds of clips in one server at once is fine for a test server but not something to do in production on every server start. Run the check in a dedicated test server, spaced with small waits, and never on player-facing servers.
6. **Platform differences.** Permissions are platform independent: a missing grant fails on PC, phone and console alike. But slow asset fetch on phones over mobile data can look like a permission failure (Length stays 0 for several seconds). Use a generous timeout in the check (10 seconds or more) before concluding a clip is blocked.
7. **Free model hazards.** Free models often contain scripts that load animations by id. Even when the animation is blocked (so nothing plays), the script itself still runs; the animation failure can hide a malicious script. Review scripts in any imported model regardless of whether its animations work.
8. **Open Use is permanent.** Setting your own animations to Open Use to "make permissions go away" also lets anyone use them, forever. For signature moves that are part of your game's identity, keep them Restricted and grant explicitly.

## Common mistakes in production

1. **Staging universe with no grants.** Symptom: everything frozen in staging while production works. Fix: grant the staging universe, or publish staging as a place in the same universe.
2. **Uploading clips the morning of a release.** Symptom: a few clips missing for the first hours. Fix: upload earlier and re-run the load check after moderation.
3. **Personal uploads by contractors.** Symptom: clips stop being fixable when the contract ends. Fix: contractors publish as the group, or hand over source files for the team to publish.
4. **Treating `Length == 0` as "not loaded yet" forever.** Symptom: code waits indefinitely on a blocked clip. Fix: time out, log the id, play a fallback pose.
5. **Turning everything Open Use.** Symptom: your signature animations appear in other games. Fix: Restricted plus grants.

## Related decisions

- [[Groups Roles and Permissions for Studios]]: setting up group ownership and roles before the first upload.
- [[Working with Contractors and Revenue Splits]]: who owns the assets a contractor creates.
- [[Legal Basics - IP Licenses and Assets]]: ownership of animation work beyond Roblox permissions.
- [[Creator Store and Toolbox Safety]]: the risks of free models that carry animation ids and scripts.
- [[Asset Upload Automation with Open Cloud]]: uploading clips in bulk under the right owner.
- [[QA Checklists Before Release]]: where the live load check belongs.
- [[Places Universes and Experience Settings]]: why grants follow the universe.
- [[Release Process and Rollbacks]]: timing uploads ahead of releases.

## Connected notes
<!-- auto-links:start -->
[[Packages and Shared Assets Across Places]] · Team Create Permissions and Workflows · Team Create and Collaboration · Packages and Asset Reuse · Team Collaboration Start Here · Plugin Security and Permissions · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Team Create Permissions and Workflows]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Animator Deep Dive]] · [[AnimationTrack Reference]] · [[How the Animator Really Behaves]] · [[Case Study - Cutting a Million Instances]] · [[Testing Animations in Studio]] · [[3D Importer Settings Reference]]
<!-- related:end -->
