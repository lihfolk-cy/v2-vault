---
tags: [systems, abilities, kits, architecture, networking, priorities, type/guide, area/animation, level/intermediate, api/RemoteEvent, area/networking, api/KeyframeSequence]
---
# Ability Kits Architecture

<!-- tldr:start -->
> [!tldr] TL;DR
> - Move names checked against the reserved list.
> - Clips installed, each with markers that survived the bake (`Hit` or beat names, `Open` and a climax marker on ultimates).
> - Upper copies for non-cinematic moves, tagged.
> - Server hit table with `t = marker - 0.06`; guard wired (three lines: create, origin clamp, cast check).
> - Registry entry (moves, labels, cooldowns) and Info descriptions; icons.
> - Beat table entries for non-standard marker names; travel list.
>
> Cost: TL;DR ~160 tok · whole note ~4.1k tok. Read more: ## The registry · ## Playing a move · ## Registering a kit (checklist)
<!-- tldr:end -->

An "ability kit" is the set of special moves bound to one weapon: two to six moves, the last one an ultimate, each with a body clip, optional weapon-part clips, client movement and VFX, and server hit data. The reference project (one live action game) shipped more than a hundred kits and over 400 moves on one shared architecture. This note describes that architecture: the registry, the per-kit folder, the reserved names, priorities and fades, upper-body copies, full-body control, beat tables, preloading and validation, with the failure stories that shaped each rule.

## The big picture

```
ReplicatedStorage
  AbilityKits (ModuleScript)          registry: which weapon has which kit and moves
  MoveBeats (ModuleScript)             marker -> juice beat kind, per kit and move
  <Name>Kit (Folder)                  one per kit
    Moves (ModuleScript)              client movement + VFX for every move
    Attack (RemoteEvent)              client -> server: cast
    Origin (RemoteEvent)              client -> server: claimed cast start
    FX (RemoteEvent)                  server -> all: relay casts and hits to onlookers
    LocalCast (BindableEvent)         ability controller -> the kit's client script
    <Move> (KeyframeSequence) x N     body clips, one per move (+ <Move>Upper copies)
    ItemRig (Folder, optional)       weapon-part clips
ServerScriptService
  <Name>Server (Script)               MOVES hit table, cooldowns, guard
  KitGuard (ModuleScript)             shared validation used by every kit server
StarterPlayerScripts
  AbilityController (LocalScript)     hotbar, input, targeting, plays clips, camera
  <Name>Client (LocalScript)          ~1.6k chars, one template: forwards casts, plays onlookers' FX
```

The split is deliberate: **one controller owns input, playback and the camera for every kit; each kit only supplies data, clips and effects.** That is what let a hundred kits share fixes. When the hit-stop, the ultimate camera or the clip loader changed, it changed in one place.

## The registry

```lua
export type MoveEntry = {
	name: string,        -- THE key: clip name, server MOVES key, Moves.MoveFns key, icon key, Info key
	label: string,       -- display name
	cd: number,          -- live cooldown (after global scaling)
	baseCd: number?,     -- the authored cooldown, kept for re-scaling
	cinematic: boolean?, -- true: cutscene ultimate; false: in-view ultimate; nil: normal move
	ultCam: { tier: string?, climax: string?, frame: string? }?,
}
export type KitEntry = {
	kit: string,         -- folder name in ReplicatedStorage, e.g. "StormKit"
	colour: Color3,
	moves: { MoveEntry }, -- slot order; the LAST entry is the ultimate
}
-- AbilityKits.Kits[weaponId] = KitEntry
-- AbilityKits.Info[weaponId][moveName] = { desc = "...", tags = { "Dash", "Area" } }
```

Design choices worth copying:

- **One name, used everywhere.** The move's `name` is simultaneously the KeyframeSequence name, the server hit table key, the client move function key, the icon key and the description key. No mapping tables to drift out of sync. The cost is that renaming a move touches five places; a registration script checks they all exist.
- **The last move is the ultimate.** The registry header once said "move 3 is the ultimate"; that went stale as move counts grew. Position-based conventions must be documented as "last", not as an index.
- **`cinematic` is tri-state.** `true` makes a cutscene ultimate (the controller anchors the root, hides UI). `false` makes an in-view ultimate that blocks other moves for `0.9 x min(clip length, 3)` s. `nil` is a normal move.
- **No ranges or animation ids in the registry.** Reach lives in the server hit tables; ids live as attributes on the kit folder (`<Move>Id`). The registry is about identity and UI.
- **Moves per rarity** (reference): Epic 2, Legendary 3, Mythic 3, Celestial 4, Divine 5, Eternal 6. The hotbar holds 6 (keys 1 to 6; gamepad X, Y, R1, L1, D-pad up, D-pad down).
- **Global cooldown scaling** lives in the registry (`normal x1.5, min 6 s; ultimates x1.25`), with `baseCd` keeping the authored value so scaling can be re-run.

## Reserved names (a real outage)

Kit folders contain both clips and the kit's remotes and modules, found by name. So **never name a move** `Attack`, `Origin`, `FX`, `LocalCast`, `Moves` or `ItemRig`.

What happened when someone did: a clip named "Origin" was installed into a kit folder. `kit:WaitForChild("Origin")` (or `FindFirstChild`) returned the KeyframeSequence instead of the RemoteEvent, the client's origin fire failed, and **the whole kit server stopped doing damage**. Nothing errored loudly.

Two defences:
1. A reserved-name check in the installer and in the move-name generator.
2. Better: put clips in their own `Clips` subfolder so they cannot collide. The reference project kept the flat layout for compatibility, which is why the rule exists.

## Playing a move

The client ability controller's cast flow (reference project):

1. **Load the kit** when the held weapon changes (polled every 0.25 s by weapon id). For each move, load a track at **Action4**, from a published id when the folder has one, otherwise from the live-safe clip loader (below). Build or load the **upper-body copy** for non-cinematic moves without their own root motion. Hook marker listeners.
2. **On key press** (`use(i)`): check the client cooldown and a `busyUntil` time; pick a target within 90 studs plus half its size and turn the root to face it; start the ultimate camera for an ultimate; play the clip with a **0.05 s fade** (the move preview uses 0.06 s).
3. **Tell the kit**: fire `LocalCast(name, aim)` so the kit's client script runs the move's movement and VFX; it fires `Origin(name, root.CFrame)` with the claimed start.
4. **0.06 s after the clip starts**, fire `Attack(name, aim, startCF)` to the server. The server schedules hits at `marker - 0.06` (see [[Combat Combo Systems]] for why the constant cancels).
5. Onlookers receive `FX:FireAllClients("Play", player, name, cf)` and run the same move function with `isLocal = false` (effects only, no movement).

### Why Action4 and a 0.05 s fade

Action4 is the top priority: abilities override swings (Action), flourishes (Action2) and stance clips (Action3) without anyone having to stop them. The fade is short because an ability is a commitment: a 0.2 s fade on a 0.3 s wind-up hides a third of the anticipation. 0.05 s (3 frames at 60 fps) is just enough to avoid a hard pop.

The equip flourish controller cancels itself on any Action2+ track, so an ability start automatically ends a flourish. This is the "priority as a signal" idea from [[Weapon and Combat Animation]].

## Upper-body copies

A move cast while walking should not freeze the legs. The fix is a second clip per move with the hips and legs at weight 0 (or not keyed), so locomotion keeps the lower body.

- **They are separate assets.** Publish `<Clip>Upper` and set `<Clip>UpperId`; if only the full clip is published, swings and casts on the move fall back to full body.
- **Tag them.** The controller sets attributes on the Animation (`KitMove = name`, `KitUpper = true`) so every listener knows what a track is.
- **Markers fire twice.** When both the full clip and its upper copy can play (or when you play both at once to split body control), every marker exists twice. A juice module once triggered hit-stop and flashes twice per hit for exactly this reason. **Rule: listeners skip tracks tagged `KitUpper`; the full clip lands the marks.**
- **When to use which:** non-cinematic moves cast while walking use the copy. Cinematic moves, moves with root motion, and "travel" moves (below) always use full body.

## Full-body control

Some moves carry the body: dashes, leaps, flips. These need the legs too, and the locomotion controller must not fight them. The rules:

- The controller keeps the **full-body** clip while the kit "has control": the Humanoid is in the `Physics` state, the root is anchored, `PlatformStand` is set, or the character has a `KitControl` attribute.
- **Travel moves** (a list per kit in the beat table, 217 moves in the reference project) take full body **from frame 0**, capped at 0.45 s, plus 0.25 s after the kit releases control. Without the frame-0 rule, the first few frames played the upper copy while the root was already flying, and the legs visibly walked in mid-air.
- Kit movement on the caster's client typically: Humanoid to `Physics` state, `AutoRotate` off, and a RenderStepped writer that sets the root CFrame plus a matching velocity (so the camera and replication see motion). Dash distances are raycast to stop 2.5 studs short of collidable geometry.

Security note from the audit: there was no server-side validation of kit movement or teleports (except in one kit). Server hits are centred on the claimed start (validated within N studs), but a client could move anywhere. If your game has PvP, validate movement. See [[Replication and Ownership]].

## Beat tables (juice as data)

Kits authored over months used inconsistent marker names (`Slash`, `CutA`, `Answer`, `Crash`, `Reboot`). Rather than rename markers in hundreds of clips, a generated data module maps them:

```lua
-- MoveBeats.Kits[weaponId][moveName][markerName] = beat kind
MoveBeats.Kits.example = {
	ThunderStep = { Dash = "Phalanx", Cut = "Strike" },
	SkyfallUlt = { Rise = "Rise", Slam = "Collapse", Finale = "Execute" },
}
-- MoveBeats.Travel[weaponId][moveName] = true  (full body from frame 0)
```

The reference table covered 45 kits, 110 moves and 349 markers. New kits skip the table by naming markers with beat names directly. The beat kinds carry a strength from 0 to 1.3 that drives shake, hit-stop and flash:

| Beat | Strength | | Beat | Strength |
|---|---|---|---|---|
| Fire | 0.2 | | Strike, Merge, Land | 0.6 |
| Slash, CutA, Flick | 0.25 | | Rupture, Verdict, Dive | 0.8 |
| CutB, Spin | 0.3 | | Shock | 0.9 |
| Scatter, Rise | 0.35 | | Erupt, Collapse | 1.0 |
| Phalanx | 0.45 | | Impact | 1.2 |
| Plant, Open, Burst, Release | 0.5 | | Detonate, Execute | 1.3 |

Thresholds: hit-stop at strength 0.45 and above, impact flash at 0.8 and above (or 0.6 on the top rarity tiers). `Charge` is never mapped: the controller uses it for a charge FOV zoom. How the beats become hit-stop is in [[Hit Reactions Stagger and Hit-Stop]]; how they become VFX in [[VFX Timing with Animation]]. Heavier shake is never cut by a lighter one arriving during it.

## Preloading (the "five seconds late" bug)

The shared iai strike once played about **5 seconds late** on first use in live servers. The data timing was instant; the clip simply was not loaded. The fix was a preload on kit load: load every move's track up front and call `ContentProvider:PreloadAsync` on the Animation instances.

```lua
local ContentProvider = game:GetService("ContentProvider")

-- Call when a kit becomes active (weapon equipped), not on first key press.
local function preloadKit(animator: Animator, kitFolder: Folder): { [string]: AnimationTrack }
	local tracks: { [string]: AnimationTrack } = {}
	local anims: { Instance } = {}
	for _, a in kitFolder:GetDescendants() do
		if a:IsA("Animation") and a.AnimationId ~= "" then
			table.insert(anims, a)
			local t = animator:LoadAnimation(a)
			t.Priority = Enum.AnimationPriority.Action4
			tracks[a.Name] = t
		end
	end
	task.spawn(function()
		-- PreloadAsync yields until the assets are fetched; never block equip on it.
		pcall(ContentProvider.PreloadAsync, ContentProvider, anims)
	end)
	return tracks
end
```

Also: when a stance clip has no published id, **cast immediately** rather than waiting for a clip that will never come. A wind-up that silently waits for a missing asset is indistinguishable from lag.

## Live-safe clips

The worst kit bug in the reference project: every kit clip was registered at runtime through `KeyframeSequenceProvider:RegisterKeyframeSequence`, and **those ids only load in Studio**. "Abilities don't work in server": every move played no body animation live. The fix routed every player-character clip through a clip loader module (`Id / Load / LoadUpper / LoadKit`) into a Lua keyframe player, with a published `<Clip>Id` always winning when present; Studio runs the same path, so Studio and live behave identically. The story is in [[Case Study - Abilities That Only Worked in Studio]] and the player in [[Lua Keyframe Player]].

## Server side: hit tables and the guard

Each kit server holds a table like:

```lua
MOVES.ThunderStep = {
	cd = 9,
	hits = {
		{ t = 0.28, fwd = 6, radius = 9, dmg = 22 },              -- t = clip marker - 0.06
		{ t = 0.54, from = 6, line = 14, radius = 7, dmg = 30 },   -- a capsule of circles along the path
	},
}
```

Hit centres are measured from the flattened cast-start CFrame; `line` is a run of circles spaced `radius x 0.8`. Shapes are flat circles (infinite vertical cylinders) including the enemy's own radius. No cones, height or line-of-sight in the base template.

The shared guard module (used by every kit server) validates:

| Check | Value |
|---|---|
| Rate limit across kit remotes | 20/s, burst 30 |
| Move belongs to this kit, aim finite | required |
| Caster alive, not downed, holding this kit's weapon | required |
| Cooldown | authored x 0.95 (survives respawn and re-equip) |
| Busy gap | the client's hold time x 0.7 |
| Claimed origin within | 12 studs of the root |
| Delayed hits | dropped if the caster dies or respawns |

The shared combat API adds hard caps: reach 200 studs, radius 240, damage multiplier 6, pull hold 0.5 to 4 s with a 0.7 s glide, bosses never pulled. Why the 0.95 cooldown factor: client and server clocks start the cooldown at different moments (the server one network trip later), so a strict server check rejects legitimate casts made the instant the client UI shows ready.

**Template regression risk.** The kit server template in the build scripts lacked the guard while every installed server had it, so re-running any old install script would have silently removed validation from that kit. Keep templates and installed code in one source of truth.

## Budgets

- **2,500 instances per kit folder** (moves plus weapon-part clips plus scripts). Normal moves run 300 to 700 instances each at about 22 to 30 keys/s; ultimates were thinned to about 15 to 19 keys/s to fit. Some legacy kits sat at 3,000 to 5,000+ and could only take no-growth installs. Stubbing clips into binary attributes removed the problem; see [[Baked Clip Stubs and Archiving]].
- **200,000 characters per script Source** (hard engine limit, saving fails above it). The shared client core was about 98k, so each kit's own code had to stay under about 95k. See [[Performance and Memory]].

## Registering a kit (checklist)

- [ ] Move names checked against the reserved list.
- [ ] Clips installed, each with markers that survived the bake (`Hit` or beat names, `Open` and a climax marker on ultimates).
- [ ] Upper copies for non-cinematic moves, tagged.
- [ ] Server hit table with `t = marker - 0.06`; guard wired (three lines: create, origin clamp, cast check).
- [ ] Registry entry (moves, labels, cooldowns) and Info descriptions; icons.
- [ ] Beat table entries for non-standard marker names; travel list.
- [ ] Ultimate: anchor spec and climax time (see [[Cinematic Ultimates]]).
- [ ] Preview data for the move list screen.
- [ ] Folder under 2,500 instances; scripts under 200k characters; compile and use-before-definition scan pass.
- [ ] Clips play in a live server, not just Studio.

See also: [[Weapon and Combat Animation]], [[Combat Combo Systems]], [[Stance and Charge Moves]], [[Cinematic Ultimates]], [[Spec-Driven Move Authoring]], [[Pipeline - New Animated Weapon]].

## Connected notes
<!-- auto-links:start -->
[[Custom Locomotion Controller Design]] · [[Playback, Priorities and Blending]] · [[Markers and Events]] · [[Snippets - Playing Animations]] · [[Hitboxes and Hit Detection]] · Genre Playbook - Combat and RPG · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Combat Animation Craft]] · [[Publishing Animations]] · [[Snippets - Animation Controller Module]] · [[Animation Glossary]] · [[Equip Draw and Flourish Systems]] · [[Enemy Animation State Protocol]] · [[Engine Gotchas]] · [[Enemy and NPC Animation]]
<!-- related:end -->
