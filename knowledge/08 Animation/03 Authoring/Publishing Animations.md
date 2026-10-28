---
tags: [authoring, publishing, release, assets, permissions]
---
# Publishing Animations

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Publishing to your account for a group game -> publish under the group, or grant the experience permission
> - Avoid: Shipping Studio-only ids -> publish, or a Lua player
> - Avoid: Ids hard-coded in many scripts -> one data table or attributes
> - No shipped code path uses `RegisterKeyframeSequence` / `RegisterActiveKeyframeSequence`
> - Every clip slot has a published id (scan for empty `*Id` attributes and placeholder ids)
> - Assets owned by the experience's owner (user or group), or permission granted
>
> Cost: TL;DR ~170 tok · whole note ~3.5k tok. Read more: ## 3. Ownership and permissions · ## 5. Keep ids as data, not in code · ## 10. Release checklist · ## Common mistakes
<!-- tldr:end -->

A clip in your place is just data. For the engine's Animator to play it in a live server, it must be **published as an animation asset** owned by (or shared with) the experience, and referenced by its asset id. This note covers why, the current publishing flow, ownership and permissions, bulk publishing, how to store and load ids, preloading, verification in live servers, and the alternative of not publishing at all.

Labels: "Roblox docs" = official pages (Animation Editor, KeyframeSequenceProvider, Asset privacy, Open Cloud Assets usage), checked October 2026. "Reference project" = one live action game.

## 1. Why publishing is not optional

- Roblox docs (`KeyframeSequenceProvider:RegisterActiveKeyframeSequence`, same for `RegisterKeyframeSequence`): the generated id "is temporary and cannot be used outside of Studio. Developers wishing to generate an asset ID that can be used online should upload the KeyframeSequence to Roblox."
- Saved clips (Animation Editor **Save**) are `KeyframeSequence`s in ServerStorage: no id at all.

What it looked like in the reference project: abilities worked perfectly in Studio and did nothing in live servers. Every clip registered at runtime silently failed: weapon hinge parts on dozens of kits never moved, marker-driven effects never fired, ability clips played nothing. Worse, new kits generated from a template kept reintroducing the register call. Rule adopted: **never add RegisterKeyframeSequence for a shipped clip**, and grep for it in every release. See [[Case Study - Abilities That Only Worked in Studio]].

## 2. The publishing flow (Roblox docs)

From the Animation Editor:
1. **Only if the clip replaces a default character animation** (run, walk, jump, idle and so on): right-click the final keyframe in the upper bar > **Rename Key Keyframe** > type `End` (case-sensitive) > Save.
2. **⋯ > Publish to Roblox**.
3. In **Asset Configuration**, enter a title and optional description.
4. **For a group-owned game, select the group in the Creator field.** This is the step people miss.
5. **Submit**. Copy the asset id from the **Toolbox** (your creations), and use it as `rbxassetid://<id>`.

From Explorer: a `KeyframeSequence` can also be uploaded from its right-click menu (commonly labelled **Save to Roblox**; check your Studio version). It opens the same asset configuration flow, which is handy for clips built in code that you never opened in the editor.

### Naming
Use titles that sort and search well: `<System>_<Character or Kit>_<Clip>` (for example `Sword_Combo_Slash2`, `Enemy_Hopper_Death`). You will be finding these in a list of hundreds.

## 3. Ownership and permissions

The engine only loads an animation in an experience if the experience is allowed to use it.
- **Publish under the same owner as the experience.** A user-owned game: your account. A group-owned game: the group (the Creator field). An animation published to your personal account usually will not play in your group's game.
- **Granting access instead of re-publishing.** Roblox docs (Asset privacy) list **Animations** among the asset types whose Creator Dashboard **Permissions** page can grant use to collaborators (friends, or groups where you have the permission) and to specific experiences (by universe id). If a creator has permission but the game does not, the Output error is clickable and offers to grant the game permission for the restricted asset.
- **The Asset Privacy setting does not change animations' defaults.** Roblox docs: Asset Privacy controls only the default privacy of Images, Decals and Meshes; "Audio, Video, Models, MeshParts, Animations, and Packages ... have their own creation defaults".
- **Catalog animations** (the ones in the avatar shop, like the default animation packs) are usable everywhere.

Details and edge cases (team members publishing, moving games between owners): [[Animation Asset Permissions and Groups]].

### Diagnosing permission failures
- Studio Output shows a load error for the animation (with restricted assets, a clickable message as above).
- `AnimationTrack.Length` stays **0**: Roblox docs say `AnimationClip.Length` "returns 0 until the animation has fully loaded", and a track that cannot load never gets a length.
- It works for you in Studio and not for others: check which account or group owns the asset.

## 4. Bulk publishing

Large projects publish hundreds of clips. Options:
- **By hand from Explorer**, one asset configuration per clip. Tedious but no tooling. The reference project's tools prepared everything (empty id slots, a list of clips to publish) and left the uploads to a person.
- **Open Cloud Assets API.** Roblox docs list **Animation** as a supported asset type for the Create Asset endpoint, with `.rbxm` / `.rbxmx` files (content type `model/x-rbxm`), with the caveat that "`.rbxm` or `.rbxmx` files edited outside of Roblox Studio might not upload or function". Animation is not listed among the types "not available for updating", so the Update Asset endpoint can push a new version to an existing id (verify before relying on it). This enables scripted batch uploads and CI. Produce the files from Studio itself, for example with `SerializationService:SerializeInstancesAsync({ks})` (which the reference project used to archive clips as normal binary `.rbxm`) or Explorer's Save to File. The reference project did not use Open Cloud for animations; treat this route as documented but untested here.
- **Never print or commit API keys.** Keep Open Cloud keys in a secret store, scoped to the minimum permissions.

### Updating a published animation
Re-publishing usually creates a **new** asset id, which means updating every reference. Alternatives: use the Update Asset endpoint (above), or keep ids in one data table so a new id is a one-line change. Whether the editor's publish dialog can overwrite an existing animation asset in your Studio version is worth checking; do not assume it.

## 5. Keep ids as data, not in code

Pick one place per system and read it everywhere. Patterns from the reference project:
- **Attributes on the clip's folder**: `<Clip>Id` (for example on locomotion, sword, katana and staff sets, a stance-animations folder, kit folders as `<Move>Id`, weapon rigs as `IdleId` / `SpecialId`).
- **A table in a data module** (for example an `AnimIds` table for equip flourishes).
- **On enemy models**: `ClipId_*` attributes.
- **Installers create the empty slots** so it is obvious what still needs publishing.
- **Placeholder values** must be obviously fake (`rbxassetid://0000000000`) or empty. Never invent plausible-looking ids.

Rules:
- **A published id always wins** over any fallback.
- **Upper-body copies are separate assets.** Publish `<Clip>Upper` (hips and legs at weight 0) and set `<Clip>UpperId`, or moving attacks fall back to the full-body clip.
- **Publish all clips of a rig together.** If half a weapon rig's clips play through the Animator (published) and half through a fallback player, the two writers fight over the same joints.

### A loader with fallbacks

```lua
--!strict
local RunService = game:GetService("RunService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

-- Returns an Animation for clip `name` stored in `folder`, preferring a published id.
-- In Studio only, falls back to a temporary id so the game runs from sources during development.
local function animationFor(folder: Instance, name: string): Animation?
	local anim = Instance.new("Animation")
	anim.Name = name
	local id = folder:GetAttribute(name .. "Id")
	if typeof(id) == "string" and id ~= "" then
		anim.AnimationId = id -- published: works everywhere
		return anim
	end
	if RunService:IsStudio() then
		local ks = folder:FindFirstChild(name)
		if ks and ks:IsA("KeyframeSequence") then
			anim.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(ks) -- Studio only!
			warn(("[anim] %s.%s is unpublished (Studio-only id)"):format(folder.Name, name))
			return anim
		end
	end
	warn(("[anim] %s.%s has no published id"):format(folder.Name, name)) -- loud in live servers
	return nil
end
```

The warning matters: unpublished clips should be noisy in testing, never silent. If you run a Lua keyframe player (next section), its branch replaces the Studio-only fallback.

## 6. Not publishing at all: playing the data yourself

The reference project eventually avoided publishing for most clips by playing the `KeyframeSequence` data with its own Lua player, which writes joint `Transform`s every frame and reproduces the Animator's measured behaviour (rotation-vector interpolation, reversed legacy Cubic, ignored root pose, root scale, layer weights, fades). Published ids still won when present.

| | Published Animator clips | Lua keyframe player |
|---|---|---|
| Publishing work | every clip, every change | none |
| Ownership problems | yes | none (data ships with the place) |
| CPU | engine, near free | about 22 microseconds per 25-joint rig-frame measured, plus distance LOD |
| Replication | built in for player characters | must be built (a relay remote) |
| Data in the place | none needed at runtime | clip data must reach clients (instances or compressed buffers) |
| Exact engine features (IK, curves, retargeting) | yes | only what you implement |

See [[Lua Keyframe Player]], [[Lua Keyframe Player Internals]], [[Baked Clip Stubs and Archiving]] and [[Clip Buffer Format]].

## 7. Preloading

A track that loads its asset on first play starts late. In the reference project an ability that "fired about 5 s late" turned out to be unloaded stance clips; the fix was creating the tracks and calling `ContentProvider:PreloadAsync` with the `Animation` instances when the kit loaded.

```lua
--!strict
local ContentProvider = game:GetService("ContentProvider")

local function preloadClips(animator: Animator, anims: { Animation }): { [string]: AnimationTrack }
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(anims) -- yields until fetched (or failed)
	end)
	if not ok then warn("[anim] preload failed:", err) end
	local tracks: { [string]: AnimationTrack } = {}
	for _, a in anims do
		tracks[a.Name] = animator:LoadAnimation(a) -- create tracks up front; reuse them per play
	end
	return tracks
end
```

Preload on equip, on kit load, or on entering an area, not at the moment of use.

## 8. Verifying in a live server

Studio is not proof. Before a release:
- [ ] Join a **live** test server (a private server or a test place under the same owner), not Studio.
- [ ] For each clip system, check `track.Length > 0` after loading (log any zero).
- [ ] Watch Output and the developer console for animation load errors.
- [ ] Play every move once; watch markers fire (effects, sounds, damage).
- [ ] Have a second player watch: replication and other-player views often differ.

A scan that lists every empty `*Id` attribute and every remaining `RegisterKeyframeSequence` call in scripts catches most problems before they ship.

## 9. Sources after publishing

Published assets are not convenient to edit. Keep the sources:
- Archive the `KeyframeSequence`s (or your specs and bake scripts) outside the game place: `.rbxm` files on disk, a separate archive place, or version control. `KeyframeSequenceProvider:GetKeyframeSequenceAsync(assetId)` can recover a sequence from an asset you can access (Roblox docs), but treat that as recovery, not a workflow.
- Remove sources from the shipped place once published. In the reference project the animation save folders and imports were a large part of a place that went from about **2.36 million to 955k instances** after archiving.
- If code still needs the clip's length, markers or named keyframes at runtime, keep a **stub**: the sequence with its poses removed but its first, last, named and marker keyframes kept. See [[Baked Clip Stubs and Archiving]].

## 10. Release checklist

- [ ] No shipped code path uses `RegisterKeyframeSequence` / `RegisterActiveKeyframeSequence`
- [ ] Every clip slot has a published id (scan for empty `*Id` attributes and placeholder ids)
- [ ] Assets owned by the experience's owner (user or group), or permission granted
- [ ] Default-animation replacements have an `End` keyframe
- [ ] Upper-body copies published and their ids set
- [ ] All clips of each rig published together
- [ ] Clips preloaded before first use
- [ ] Verified in a live server, with a second player watching
- [ ] Sources archived outside the place; stubs left where code needs metadata

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Publishing to your account for a group game | works for you in Studio, nothing in game | publish under the group, or grant the experience permission |
| Shipping Studio-only ids | abilities "don't work in server" | publish, or a Lua player |
| Ids hard-coded in many scripts | missed updates after re-publishing | one data table or attributes |
| No upper-body id | swings on the move freeze the legs | publish and set the upper copy |
| Half a rig published | joints fight | publish together |
| No preload | first use late | preload on equip / kit load |
| Silent fallbacks | missing clips go unnoticed | warn loudly when an id is missing |

## See also
[[Animation Editor Workflow]], [[Animation Asset Permissions and Groups]], [[Authoring Clips in Code]], [[Lua Keyframe Player]], [[Baked Clip Stubs and Archiving]], [[The Default Animate Script]], [[Replication and Ownership]], [[Animation Review Checklist]].

## Connected notes
<!-- auto-links:start -->
[[KeyframeSequence Keyframe and Pose Reference]] · [[Animation Objects]] · [[Ability Kits Architecture]] · [[Snippets - Playing Animations]] · [[Asset Upload Automation with Open Cloud]] · [[Packages and Shared Assets Across Places]] · [[Animation Start Here]]
<!-- auto-links:end -->
