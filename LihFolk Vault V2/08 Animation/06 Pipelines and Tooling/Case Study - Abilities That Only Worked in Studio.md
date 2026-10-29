---
tags: [case-study, debugging, keyframesequenceprovider, publishing, runtime]
---
# Case Study: Abilities That Only Worked in Studio

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No live private server in the release process.
> - Avoid: Telemetry only for errors. Symptom: silent failures never show up on dashboards.
> - Avoid: Testing with the developer's own account only.
> - No `RegisterKeyframeSequence` in any shipped script (lint).
> - Every clip either has a published id or plays through a Lua player.
> - Studio and live share one playback path.
>
> Cost: TL;DR ~140 tok · whole note ~3.8k tok. Read more: ## Act 2: "abilities don't work in server" · ## Nuances and edge cases · ## Checklist · ## Common mistakes in production
<!-- tldr:end -->

Every ability in one live action game looked perfect in Studio play tests and did nothing in live servers. No errors, no warnings: characters simply did not animate their abilities, weapon parts stood still, and marker-driven effects never fired. The cause was one engine call, `KeyframeSequenceProvider:RegisterKeyframeSequence`, used at runtime as a substitute for publishing. The fix grew into a full Lua animation runtime. This note tells the story in order, because the way the bug hid is the useful part.

## The setup

Clips in this game were generated in code (spec-driven bakers, IK passes, procedural weapon-part clips) and stored as KeyframeSequences in the place. Publishing them as Animation assets was on the to-do list ("publish animation ids; until then clips are registered at runtime"). In the meantime, code did this:

```lua
-- The pattern that only works in Studio (do not ship this)
local KSP = game:GetService("KeyframeSequenceProvider")
local anim = Instance.new("Animation")
anim.AnimationId = KSP:RegisterKeyframeSequence(clipKeyframeSequence)
local track = animator:LoadAnimation(anim)
track:Play()
```

`RegisterKeyframeSequence` returns a temporary content id for a KeyframeSequence. The official reference documents only its signature (it takes a KeyframeSequence and returns a ContentId); it does not promise the id works in a running game. In this project, measured repeatedly, the ids loaded in Studio (Edit and Play-in-Studio) and **did not load in live servers**: tracks were created, `Play` succeeded, and nothing moved. Treat it as a Studio testing tool.

## Why it hid for so long

1. **Every test was a Studio test.** Play-in-Studio uses the same code path that works. Nothing in the test loop exercised a live server.
2. **Failure was silent.** No exception, no warning in the output. `LoadAnimation` returned a track; `Play` returned normally. The track's `Length` stayed 0, but nothing checked it.
3. **"Nothing happens" is hard to notice.** A missing animation looks like a design choice (stiff characters, static weapons) unless you already know what should be there. Players reported it as "abilities don't work in server", not as an animation bug.
4. **Gameplay mostly kept working.** Damage was timed from data (marker times copied into tables), so hits landed even though the swing never played. Only marker-driven effects (spins, special effects) broke outright.
5. **Templates spread it.** New weapons were built from kit templates, and the template contained the registration call.

A related, smaller trap made the same call look flaky even in Studio: **a freshly registered clip plays nothing until its track's `Length > 0`**, because it loads asynchronously. A measuring tool once reported about 117 deg of error with `loaded = false`; the clip simply had not loaded yet. Tools wait for `Length > 0` (up to 2 s) before stepping.

## Act 1: weapon parts stood still

The first symptom found was on weapons. Moving accessory parts (rings, hinged pieces, spinning parts) animated in Studio and stood still in the published game; older weapons whose specials were triggered by keyframe markers never fired them at all.

Fix: a small Lua player for weapon rigs ([[Weapon Rig Player]]) that reads the clip's Poses itself and writes `Motor6D.Transform` every frame, reproducing the Animator's measured behaviour. Verified against `Animator:StepAnimations` on every animated weapon rig (several dozen): every joint within 0.001 rad through idle, a special's fade-in, the special and its fade-out. A published id in a `<Clip>Id` attribute still wins, so publishing later stays possible.

## Act 2: "abilities don't work in server"

The weapon fix did not touch characters. The report "abilities don't work in server" was the same bug on every player clip: abilities and their upper-body copies, stance clips, movement clips, the inspect animation.

The response was a design decision rather than a patch: **every player-character clip loads through one module** (`Id`, `Load`, `LoadUpper`, `LoadKit`) **into Lua keyframe player tracks** ([[Lua Keyframe Player]]), and **Studio runs the same path as live servers.** That last point is the real fix: the class of "works in Studio only" bugs disappears when there is no Studio-only path.

It required:

- **Composition.** A custom procedural character animator already owned the player's joints. Each frame it now asks the Lua player to compose the active tracks over its own pose (`Compose`), in "upper" or "full" modes, and writes the result itself.
- **Replication.** Lua tracks do not replicate. The local character's tracks are sent (batched, throttled) to a server relay and replayed on every other client, with selected `Animation` attributes (move name, upper-body flag, stance clip) riding along.
- **Listeners.** Everything that listened to Animator signals (effect juice keyed to markers, stance effects, marker-driven weapon spins, the equip flourish controller, the ultimate camera) was moved to the Lua player's `OnPlayed` / `PlayingTracks` helpers.
- **A rule:** never add `RegisterKeyframeSequence` for a player clip.

Enemies went through the same transition at about the same time: their clips were also registered at runtime ("Studio only until animation ids are published"), and moving them onto the Lua player made publishing unnecessary for well over a thousand enemy clips.

## Act 3: the regression from templates

Days later, an audit while baking weapon-part clips found **dozens of kits** (every kit built from the newer template batches) still playing their weapon-part clips through `RegisterKeyframeSequence` in a `partTrack` helper. In the live game, their weapon parts did not animate during moves. They had been built after Act 1 from a template that predated the fix.

Fix: one identical replacement block (tagged, so it can be grepped) in every affected kit's move modules, switching `partTrack` to the weapon rig player while keeping "a published id wins". Checks in Edit: every patched kit compiled and passed the use-before-definition scan; every weapon-part clip (about two hundred) loaded and moved their real weapon models through the rig player. Two weapons turned out to key parts that had no Motor6D at all (a chain of segments on one, a couple of loose pieces on another): those keys were inert under the Animator too, so nothing changed for them.

A later weapon added after that fix again shipped with the old registration path. **Template code is a regression vector.** The durable defence is a check, not a memory.

## The defences that stuck

### 1. A lint in the build

Any shipped Source containing `RegisterKeyframeSequence` fails the build check. In the reference project the kit builder already refused oversized sources, reserved move names and forbidden sound ids; this is one more pattern.

### 2. A runtime tripwire

```lua
-- Warn when a track never gets a length in a running game: the clip never loaded.
local RunService = game:GetService("RunService")
local function watchTrack(track: AnimationTrack, label: string)
	if RunService:IsStudio() then return end            -- Studio is not where this bug lives
	task.delay(3, function()
		if track.Length <= 0 then
			warn(("[anim] %s never loaded (Length 0 after 3 s): unpublished or Studio-only id?"):format(label))
		end
	end)
end
```

Pair it with your analytics: a count of never-loaded tracks per server makes this class of bug visible within minutes of a release.

### 3. Test in a live server before release

A private live server catches everything in this note in one session. Studio play tests, however thorough, cannot.

### 4. One code path

The strongest defence was architectural: Studio and live run identical playback code. Where a debug switch exists (play through the real Animator in Studio for A/B checks), it defaults to off.

## Choosing a fix for your game

| Option | Pros | Cons |
|---|---|---|
| **Publish every clip** and use asset ids | the engine plays it; no runtime cost; standard | every clip is an upload; ids must be kept in sync with clips; assets belong to a user or group ([[Animation Asset Permissions and Groups]]); regenerating clips means re-uploading |
| **Lua keyframe player** | no ids; Studio equals live; full control (LOD, streaming, compression) | you own correctness, replication and CPU cost ([[Lua Keyframe Player]]) |
| **Hybrid: Lua player, published id wins** | migrate gradually; publish only what benefits | two paths to test; never mix both on one rig's clips |

The reference project chose the hybrid, then effectively ran everything through the Lua player because nothing was ever published.

If you do publish: publish **all** of a rig's clips together. With some joints driven by published tracks on the Animator and others by a Lua player, two writers fight over the same joints.

## Related symptom: abilities that start late

A different bug looked similar ("the strike happens 5 s late"): the data timing was instant, but the first play of each clip waited for it to load. The fix was preloading: create the tracks (and preload assets) when the kit loads, not on first use. The general lesson for both bugs: **know when your clip is actually ready**, and check `Length` instead of assuming.

## Timeline summary

| Stage | Scope | Fix | Verified by |
|---|---|---|---|
| weapon parts static live | weapon rigs' idle / special | Lua rig player | every rig within 0.001 rad vs the Animator |
| "abilities don't work in server" | every player clip | all player clips through the Lua player; composition; replication; listeners | Edit A/B against `StepAnimations`; marker counts |
| enemies | well over a thousand enemy clips | Lua player plus server-streamed compiled clips | 60 enemy clips within 0.056 deg |
| template regression | dozens of kits' weapon-part clips during moves | one tagged replacement block, then baking | all clips load and move; baked within 0.04 deg |

None of it was live play-tested at the time of writing; the Edit checks prove the playback math, not the live replication.

## Checklist

- [ ] No `RegisterKeyframeSequence` in any shipped script (lint).
- [ ] Every clip either has a published id or plays through a Lua player.
- [ ] Studio and live share one playback path.
- [ ] A tripwire warns on tracks that never get a length.
- [ ] Clips preloaded before first use.
- [ ] A live-server test before every release that touches animation.

## See also

[[Lua Keyframe Player]], [[Weapon Rig Player]], [[Publishing Animations]], [[Animation Asset Permissions and Groups]], [[Replication and Ownership]], [[Testing Animations in Studio]], [[Engine Gotchas]], [[Debugging Animation Problems]]

## Nuances and edge cases

The specific trap here is one engine call, but the general lesson is "Studio is not production". These are the other ways that gap shows up, and the trade-offs around closing it.

1. **Studio differs from live in more than animation.** Other Studio-only behaviours that produce the same "worked in testing" pattern: DataStores using Studio access settings, HTTP enabled in Studio but not for the live experience, assets you can load because you own them personally (but the experience owner does not), and timing differences because Studio's local server has zero latency. A release check that runs in a live private server catches all of these at once.
2. **Zero latency hides ordering bugs.** In Studio's Play mode, client and server share a machine; remotes arrive almost instantly. Code that assumes a server attribute is set before the client reads it works in Studio and fails live at 150 ms ping. Studio's network emulation settings (incoming replication lag) help reproduce this; use them for any feature that crosses the boundary.
3. **Device differences.** A live server test from a PC still misses phone-only problems: slow asset loads on mobile data, touch input paths, lower frame rates that change marker timing. For animation-heavy releases, include at least one mid-range phone in the live test.
4. **Scale differences.** Studio tests usually have one to four players. Problems that appear only with 30 or more (replication load from many characters animating, relay throttling, memory from cached tracks) need a load test or a soft launch to a small audience.
5. **Silent failures need explicit checks.** The deepest lesson is that a track with `Length` 0 is not an error. Anywhere the platform fails quietly (assets not loading, sounds with no length, images not loading), add your own tripwire that logs to telemetry, so the first report comes from your dashboard and not from players.
6. **Templates propagate everything.** Templates are a force multiplier for good and bad patterns. Lint templates as strictly as shipped code, and when a template changes, list every kit built from the old version.
7. **The cost of "one code path".** Running a custom player in Studio and live means giving up some Studio conveniences (instant preview of unpublished clips through the engine). Most teams find that trade worth it once they have shipped one invisible bug; smaller teams with few clips may prefer to publish everything and keep the engine path.

## Common mistakes in production

1. **No live private server in the release process.** Symptom: features that only fail live. Fix: a live test session for every release that touches animation, data or assets.
2. **Telemetry only for errors.** Symptom: silent failures never show up on dashboards. Fix: log "expected thing did not happen" events, such as tracks that never load.
3. **Testing with the developer's own account only.** Symptom: assets the developer owns load; players see nothing. Fix: test with an account that owns nothing.
4. **Network emulation never used.** Symptom: race conditions appear only at real latency. Fix: test boundary-crossing features with replication lag enabled.
5. **Fixing the symptom per kit.** Symptom: the bug returns with each new weapon. Fix: lint plus template fix plus tripwire, all three.

## Related decisions

- [[Testing Modes - Play Run and Multi-Client]]: what each Studio test mode does and does not simulate.
- [[Multi-Client and Device Playtesting Protocols]]: structured live and device testing.
- [[QA Checklists Before Release]]: where the live animation check belongs.
- [[Crash and Error Telemetry]]: logging silent failures, not only errors.
- [[Debugging Live Servers]]: investigating failures that do not reproduce in Studio.
- [[Debugging Client-Server Desync]]: the latency-dependent bugs Studio hides.
- [[Code Review for Luau Teams]]: catching Studio-only calls before they ship.
- [[Live Incident Response and Post-Mortems]]: handling it when this kind of bug reaches players.

## Connected notes
<!-- auto-links:start -->
[[Ability Kits Architecture]] · [[Animation Objects]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Custom Locomotion Controller Design]] · [[Post-Mortem - Building a Melee Action Game]] · [[The Debugging Method - Reproduce Isolate Bisect]] · [[Animation Start Here]]
<!-- auto-links:end -->
