---
tags: [pipeline, runtime, keyframesequence, architecture, advanced, type/guide, area/animation, level/advanced, api/Animator, api/KeyframeSequence, api/LoadAnimation]
---
# Lua Keyframe Player

<!-- tldr:start -->
> [!tldr] TL;DR
> - It is not free. You take on correctness (every Animator behaviour you rely on must be re-implemented and tested), CPU cost...
> - Enemies and other non-player rigs first (the initial goal: no published ids for 1,500 enemy clips).
> - AnimationTrack-compatible tracks. Tracks expose `Play(fade, weight, speed)`, `Stop(fade)`, `AdjustSpeed`...
> - Measured in Edit against `Animator:StepAnimations` (details and numbers in How the Animator Really Behaves and Lua Keyframe...
>
> Cost: TL;DR ~160 tok · whole note ~3.6k tok. Read more: ## Architecture · ## The Animator model it reproduces
<!-- tldr:end -->

An advanced pattern with a big payoff: instead of publishing every clip as an Animation asset and letting the Animator play it, a Lua module **reads KeyframeSequence data and writes joint `Transform`s itself**, every frame, reproducing the Animator's measured behaviour. One production game moved all of its animation (players, about 1,500 enemy clips, several hundred weapon-part clips) onto two such players: a general one ("KeyframePlayer", this note) and a small one for weapon rigs ("PoseDriver", [[Weapon Rig Player]]). The mechanism in full detail: [[Lua Keyframe Player Internals]]. Copyable core: [[Snippets - Lua Keyframe Player Core]].

## Why you would ever do this

| Pain with the Animator + assets | What the Lua player gives you |
|---|---|
| Every clip must be uploaded and its id kept in sync; assets belong to one owner or group ([[Animation Asset Permissions and Groups]]) | Clips are data in the place. No ids. |
| `KeyframeSequenceProvider:RegisterKeyframeSequence` ids played in Studio and **did nothing in live servers** (measured in the reference project) | Studio and live run **the same code path**, so "works in Studio, broken live" disappears ([[Case Study - Abilities That Only Worked in Studio]]) |
| Hundreds of thousands of Pose instances in replicated storage | Clips compiled to compact buffers, streamed on demand, Poses removed ([[Baked Clip Stubs and Archiving]]) |
| No control over update rate | Per-rig level of detail by distance and visibility |
| You cannot read what the Animator computed | You own every intermediate value: sample a clip at any time without a track |

It is not free. You take on correctness (every Animator behaviour you rely on must be re-implemented and tested), CPU cost scales with rig count, and features built on the real Animator pipeline (published asset playback, `IKControl`) still need the Animator.

## Scope in the reference project

- **Enemies and other non-player rigs** first (the initial goal: no published ids for 1,500 enemy clips).
- **Player characters** next, after the "abilities don't work in live servers" bug: every game clip on a player (abilities and their upper-body copies, the dash stance, a strike ability's stance and draw, the inspect) became a Lua track. A custom procedural character animator owns the player's joints and composes the tracks into its pose each frame.
- **Weapon rigs** run on the smaller sibling player with the same Animator model.
- **Published ids still win.** If a clip has a real asset id, the shim hands it to the real Animator. That keeps the door open to publishing later.

## Architecture

```
            ┌──────────── data ─────────────┐        ┌──────────────── runtime (every client) ────────────────┐
KeyframeSequence (Poses) ──parse──► clip table ──────► Track (AnimationTrack-like) ──► rig step (PreSimulation)
baked stub (KSB attr) ──decode──►     │                    Play/Stop/AdjustSpeed/...      per joint: sample, mix by
server kit ──EncodeKS──► buffer ──────┘                    markers, fades, signals        priority and weight,
     (streamed once per client)                                                           write .Transform
                                                                                                  │
                         custom character animator ──► Compose(model, basePose) ◄────────────────┘
                                                        (returns composed CFrames, writer applies them)
local character tracks ──► net module ──► server relay ──► other clients replay the same track
```

Key design decisions:

1. **AnimationTrack-compatible tracks.** Tracks expose `Play(fade, weight, speed)`, `Stop(fade)`, `AdjustSpeed`, `AdjustWeight(weight, fade)`, `GetMarkerReachedSignal`, `GetTimeOfKeyframe`, `Destroy`, `IsA("AnimationTrack")`, fields `Looped`, `Priority`, `Speed`, `Length`, `TimePosition` (settable), `IsPlaying`, `WeightCurrent`, `WeightTarget`, `Name`, `Animation`, and signals `Stopped`, `Ended`, `DidLoop`, `KeyframeReached`. Existing code that expects an AnimationTrack keeps working.
2. **An Animator shim.** `Register(ks)` returns a token string (`ksp://<n>`) that you put in `Animation.AnimationId`. `LoadAnimation(animator, animation)` returns a Lua track for tokens (or for an empty id plus an attribute naming the clip) and forwards anything else to `animator:LoadAnimation`. Migrating a codebase is mostly a find-and-replace of `animator:LoadAnimation(a)` with `KeyframePlayer.LoadAnimation(animator, a)` and of `RegisterKeyframeSequence` with `Register`.
3. **Writes `Transform` on Motor6D, [[AnimationConstraint]] or Bone joints**, matched by name (Part1 name, Attachment1's part name, or the bone name). Joints of nested rigs (a held weapon with its own Animator) are skipped.
4. **Runs in `RunService.PreSimulation`**, after the real Animator has applied its poses for the frame and before physics (in Edit, where nothing simulates, on Heartbeat). A joint the real Animator or another writer set this frame is used as the base under the Lua tracks, so both can coexist.
5. **One clip cache** per KeyframeSequence instance and per network key, so a clip is parsed once no matter how many rigs play it.

## The Animator model it reproduces

Measured in Edit against `Animator:StepAnimations` (details and numbers in [[How the Animator Really Behaves]] and [[Lua Keyframe Player Internals]]):

- Per joint, only poses with `Weight > 0` are keys; weight-0 poses are hierarchy placeholders.
- The keyframe's top-level pose (HumanoidRootPart, or a bone rig's Root bone holder) is never applied.
- A segment eases by its **first** pose's style. CubicV2 follows TweenService directions; legacy Cubic runs reversed; Constant has three behaviours by direction.
- Rotation between keys: **[[Quaternions|quaternion]] nlerp only when every keyframe of the sequence is evenly spaced and every key is Linear**; otherwise a linear blend of rotation vectors (axis times angle from rest), choosing the closest pair of representations. Offsets lerp.
- Fades are linear. A one-shot that reaches its end holds its last pose and fades out over 0.3 s. `Stop` keeps time running during its fade. `Play` restarts at 0. Track time is float32.
- Weights are handed out from the highest priority down; tracks of one priority normalise when they sum past 1; an under-weighted result scales its rotation vector toward rest.
- Translations scale with `Model:GetScale()` (characters sized through Humanoid body scales have scale 1, so clip offsets must already be at game scale; see [[Scale and Animation]]).

## Measured accuracy and cost

| Test | Max error vs the real Animator |
|---|---|
| 10 R15 clips | <= 0.084 deg |
| 60 enemy clips (all 20 kits, baked buffers) | <= 0.056 deg / 0.002 studs, except 3 clips with keys at exactly 180 deg (where the Animator itself flips direction between runs) |
| 5-track blend | 0.04 deg |
| Markers fired | 319 / 319 |
| Weapon rigs (sibling player, 80 rigs) | every joint within 0.001 rad through idle, a special's fade-in, the special and its fade-out |

**Cost:** about **22 microseconds per 25-bone rig per frame** (39-60 microseconds on the largest boss). An A/B switch (`AnimatorInStudio = true`) makes Studio hand clips to the real Animator instead, for side-by-side comparison.

## Level of detail

| Distance from the camera | Update |
|---|---|
| the local character | every frame |
| within 60 studs (NearRange) | every frame |
| within 150 (MidRange) | every 2nd frame |
| within 300 (AnimRange) | every 4th frame |
| beyond 300, or off screen | time only: tracks advance, markers fire, nothing is written |

Refinements that came from play feedback:

- **Big bodies count from their surface.** A 30-54 stud boss fought face to face sat past 60 studs measured to its root and was posed every 2nd or 4th frame, which read as "robotic, sluggish, stop-motion". Distance now subtracts 1.5x the model's height attribute, and bosses, elites and similar rigs within 300 studs are always posed every frame.
- **Off-screen rigs** (checked every 3 frames with a padded frustum test) advance time only.
- Rate decisions are re-evaluated every 15 frames, with a random phase per rig so rigs on the same rate do not all update on the same frame.
- Rigs in a `ViewportFrame` / `WorldModel` keep playing; rigs parked in storage do not.

## Data: compile, compress, stream

Client-visible Pose trees are expensive (every Pose is an instance every client downloads). The player reads three sources, all into the same internal clip table:

1. **A live KeyframeSequence** with Poses (authoring, Studio, small sets).
2. **A baked stub:** a KeyframeSequence with no Poses whose motion is a base64 binary buffer in an attribute (`KSB`). Markers and named keyframes remain as instances so other code can still read them.
3. **A server-side kit:** enemy clip sources live in server storage (clients cannot see them). The server compiles each kit once into buffers (or ships a stub's buffer as is) and **streams a kit to a client the first time that client asks**. Until it arrives the rig holds a procedural root pose; a boss intro joins late once its kit lands; boss kits are prefetched by zone. Measured: 19-235 KB per kit, about 1.6 MB for the whole roster; the whole server build takes 0.23 s from stubs.

Buffer layout: [[Clip Buffer Format]]. Stubs and the archive: [[Baked Clip Stubs and Archiving]], [[Clip Archive Server]].

## Replication

Lua tracks do not replicate by themselves. Two strategies are used:

- **Players:** the local character's tracks are sent (batched, throttled) through a RemoteEvent to a server relay that forwards them to every other client, which plays its own copy on that player's character. A clip is identified by its replicated-storage path, `@Kit/Clip` for baked server kits, or `path|-Joint,Joint` for runtime copies with some joints switched off (an upper-body copy). Selected `Animation` attributes ride along so listeners on other clients see the same metadata. Late joiners request the tracks already playing.
- **Enemies:** the server writes **state attributes only** (current clip, start time, speed, loop, hurt direction, layer, phase); every client plays the clips itself. See [[Enemy Animation State Protocol]].

See [[Replication and Ownership]] for the general trade-offs.

## Living with a custom character animator: Compose

When another module owns the character's joints (a procedural locomotion animator writing every joint each frame), the Lua player must not fight it. `Compose(model, basePose, out)` steps the rig's tracks (time, fades, markers) and returns the composed CFrame of each joint the tracks key, mixed over the writer's own pose for whatever weight the tracks leave. The writer then applies the result. While `Compose` keeps being called the shared loop leaves the rig alone; after 0.25 s without a call (out of the writer's range) the rig steps itself again. Clips at or below Movement priority are left to the writer entirely (its locomotion), and Action-and-above clips play over its pose.

## Listeners

Everything that used to listen to Animator signals must listen to the Lua player instead: effect "juice" keyed to markers, stance effects, marker-driven weapon spins, the equip flourish controller, the ultimate camera. Helpers: `PlayingTracks(animatorOrModel)` (the Animator's tracks plus Lua tracks) and `OnPlayed(animatorOrModel, fn)` (both `Animator.AnimationPlayed` and Lua plays). **Beware double marker firing** when a full-body clip and its upper-body copy both play: one juice module had to skip the upper copy because "marks fired twice".

## Sampling without a track

`ClipOf(ks)` and `SampleCFrame(clip, joint, t)` sample any clip at any time with the same interpolation. The reference project used this for locomotion (the procedural animator samples idle / walk / run clips directly, no tracks, no ids), for death ground-fitting, for QA and previews, and for "AfterStep" hooks that run right after each frame's writes.

## Migration plan (what worked)

1. Build the player with the shim and the A/B switch. Verify against `StepAnimations` on a test set: errors under 0.1 deg, markers all firing.
2. Move non-player rigs (enemies, NPCs, props) first. They have no replication complexity.
3. Move weapon rigs (a smaller player is fine).
4. Move player clips with replication and `Compose`, and port every listener.
5. Bake clips to stubs once everything reads through the player.
6. Grep the codebase for `RegisterKeyframeSequence` and `animator:LoadAnimation` regularly. Templates reintroduce them.

## Trade-offs and when not to

- **Do not** build this for a small game with a handful of published clips. The Animator is free CPU you do not maintain.
- **Do** consider it when you have hundreds or thousands of clips, generate clips in code, need Studio and live to be identical, or need precise control of what plays where.
- Everything was verified in Edit with `StepAnimations`; live replication was the least tested part in the reference project. Budget play-test time for it.

## See also

[[Lua Keyframe Player Internals]], [[Weapon Rig Player]], [[Clip Buffer Format]], [[Baked Clip Stubs and Archiving]], [[How the Animator Really Behaves]], [[Playback, Priorities and Blending]], [[Animation LOD]], [[Performance and Memory]], [[Snippets - Lua Keyframe Player Core]], [[Open Questions]]

## Connected notes
<!-- auto-links:start -->
[[Engine Gotchas]] · [[AnimationTrack Reference]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Animation Objects]] · [[Links - Animation playback]] · AI Animation and Motion from Video · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Authoring Clips in Code]] · [[Publishing Animations]] · [[Animation Glossary]] · [[Animator Deep Dive]] · [[Animation Data from Blender to Roblox]] · [[Debugging Animation Problems]] · [[Snippets - Building and Sampling Clips]] · [[Troubleshooting Table]]
<!-- related:end -->
