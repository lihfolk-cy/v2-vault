---
tags: [fundamentals, api, overview]
---
# Animation Objects

This is the map of every object Roblox uses to store, load and play animation, and how they connect. Each object has its own deep reference note; this note is about the relationships, the lifecycle and the choices you make between them. If you only read one fundamentals note, read this one and [[Animator Deep Dive]].

## The one-paragraph model

An **animation asset** is data on Roblox's servers (a `KeyframeSequence` or `CurveAnimation` that someone uploaded). An **`Animation`** instance is only a pointer to it (`AnimationId`). An **`Animator`** turns that pointer into a playable **`AnimationTrack`** with `Animator:LoadAnimation`. Each frame the Animator evaluates all of its playing tracks, mixes them by priority and weight, and writes one local offset per joint into the joint's `Transform` (`Motor6D.Transform`, `AnimationConstraint.Transform` or `Bone.Transform`). Physics then moves the parts from those transforms. Nothing else is "animation": everything else in this vault is either a way to produce that data, a way to choose which tracks play, or a way to write `Transform` yourself.

```
Asset on Roblox (KeyframeSequence / CurveAnimation)
        ^ AnimationId
Animation (pointer, holds no motion)
        | Animator:LoadAnimation(animation)
AnimationTrack (per Animator, per load call)
        | Play / Stop / AdjustWeight / AdjustSpeed
Animator evaluates tracks every frame (after PreAnimation, before PreSimulation)
        | writes
Motor6D.Transform  /  AnimationConstraint.Transform  /  Bone.Transform
        | physics / skinning
Parts and mesh vertices move on screen
```

## Every class, by role

### Pointers and players
| Class | Role | Key facts |
|---|---|---|
| `Animation` | Pointer to an asset | `AnimationId` (string content id) and `AnimationContent` (Content; setting either updates the other). Holds no motion, costs almost nothing. |
| `Animator` | Evaluates tracks, writes joints, replicates playback | Lives under a `Humanoid` or `AnimationController`. Must be in the Workspace to load. One per rig. See [[Animator Deep Dive]]. |
| `AnimationTrack` | A loaded, playable instance of one clip on one Animator | Not creatable. `Play / Stop / AdjustSpeed / AdjustWeight`, `TimePosition`, `Priority`, `Looped`, markers. See [[AnimationTrack Reference]]. |
| `AnimationController` | An Animator host for rigs without a Humanoid | Its own `LoadAnimation` and `GetPlayingAnimationTracks` are deprecated: put an `Animator` under it and use that. |
| `Humanoid` | An Animator host plus the character state machine | `Humanoid:LoadAnimation` is deprecated; use the child `Animator`. See [[Humanoid States and Animation]]. |

### Clip data (all are subclasses of `AnimationClip`)
`AnimationClip` is the not-creatable base class. It provides `Length` (read-only), `Loop` and `Priority`, which are the clip's defaults (a track can override `Looped` and `Priority` at runtime).

| Class | What it stores | Notes |
|---|---|---|
| `KeyframeSequence` | `Keyframe` children at times, each holding a tree of `Pose` objects | The classic format and what most tools write. See [[KeyframeSequence Keyframe and Pose Reference]]. |
| `Keyframe` | One time (`Time`) with Poses and `KeyframeMarker` children | Its Name, if not "Keyframe", is a legacy event. |
| `Pose` (and the base `PoseBase`) | One joint's local transform at that keyframe, plus `Weight`, `EasingStyle`, `EasingDirection` | Named after the joint's **Part1**; nested like the rig. |
| `NumberPose` | A scalar value at a keyframe (`Value`) | Used for numeric channels such as face controls in keyframe form. |
| `KeyframeMarker` | A named event with a `Value` string | Fires `GetMarkerReachedSignal(name)`. See [[Markers and Events]]. |
| `CurveAnimation` | One curve per channel, in `Folder`s mirroring the joint tree | `Vector3Curve` position, `RotationCurve` or `EulerRotationCurve` rotation, `FloatCurve` for scalar channels, `MarkerCurve` for events. See [[CurveAnimation and Curve Channels]]. |
| `AnimationGraphDefinition` | An animation graph (nodes, blend trees, parameters) | Newer, exposed through `AnimationTrack:SetParameter / GetParameter / GetParameterDefaults`. Not covered in depth in this vault; treat as evolving. |

### Providers (services)
| Service | Use |
|---|---|
| `KeyframeSequenceProvider` | Older service. `RegisterKeyframeSequence` returns a temporary hash id, `RegisterActiveKeyframeSequence` an `active://` URL. **Both only load inside Studio.** `GetKeyframeSequenceAsync(id)` downloads a published clip's KeyframeSequence (yields; wrap in `pcall`). |
| `AnimationClipProvider` | The documented replacement. Same register methods for any `AnimationClip` (also Studio-only), `GetAnimationClipAsync` (returns a KeyframeSequence or CurveAnimation), and `GetClipEvaluatorAsync`, which returns a `ClipEvaluator` that samples a clip without an Animator. |

### Joints (what actually moves)
| Class | Used by | What the Animator writes |
|---|---|---|
| `Motor6D` | Classic R6/R15 characters, part rigs, weapon hinges, doors | `Transform` |
| `AnimationConstraint` | R15 avatars when the Avatar Joint Upgrade is on (the default for new experiences), and any rig you build with it | `Transform` (plus physical following when `IsKinematic` is false) |
| `Bone` | Skinned meshes | `Transform` |

See [[Rigs and Joints]], [[Motor6D Math and CFrame Composition]], [[Bones and Skinned Meshes]] and [[AnimationConstraint and Physically Simulated Characters]].

### Neighbours that touch animation
- `IKControl`: runtime IK applied on top of the animated pose (see [[IKControl Reference]]).
- `FaceControls`: about 50 numeric FACS properties on dynamic heads, animated through FloatCurves or NumberPoses (see [[Facial Animation and Dynamic Heads]]).
- `HumanoidDescription`: holds the avatar's animation pack ids (`IdleAnimation`, `WalkAnimation`, `RunAnimation`, `JumpAnimation`, `FallAnimation`, `ClimbAnimation`, `SwimAnimation`, `MoodAnimation`) and body scales.
- The default `Animate` LocalScript in every character: see [[The Default Animate Script]].

## The lifecycle of a clip, end to end

1. **Author.** In the Animation Editor (saves a KeyframeSequence or CurveAnimation under `ServerStorage.RBX_ANIMSAVES`; older editor versions and the 3D importer also leave `AnimSaves` containers on rigs), in a third-party tool, or in code (see [[Authoring Clips in Code]]).
2. **Preview.** The editor plays it in Studio. Code can register it with `KeyframeSequenceProvider` or `AnimationClipProvider` to get a temporary id. That id **never works in a live server**.
3. **Publish.** Upload the clip as an Animation asset (editor "Publish to Roblox", or Open Cloud for `.rbxm` files). You get a permanent asset id. See [[Publishing Animations]].
4. **Grant.** The experience must be allowed to use the asset: same owner, or a permission grant. See [[Animation Asset Permissions and Groups]].
5. **Reference.** Put the id in an `Animation.AnimationId` (or an attribute your loader reads).
6. **Load.** `animator:LoadAnimation(animation)` returns a new track. The asset downloads asynchronously: `track.Length` reads 0 until it has loaded.
7. **Play.** `track:Play(fade, weight, speed)`. The Animator mixes it with everything else on that rig (see [[Playback, Priorities and Blending]]).
8. **Replicate.** If the Animator is set up correctly, other clients see the same track (see [[Replication and Ownership]]).
9. **Stop / end.** The track fades out; `Stopped` then `Ended` fire.

The step people skip most often is 4; the step that silently fails most often is 2 (a Studio-only id shipped to production). Both look identical in a live server: the character stands still and nothing errors.

## Humanoid or AnimationController?

| | Humanoid | AnimationController |
|---|---|---|
| What you get | Walking, jumping, climbing, swimming, seats, health, state machine, the default Animate script for players | Nothing but a place to put an Animator |
| Cost | Higher: state machine, floor raycasts, collision management | Very low |
| Use for | Player characters; NPCs that walk with `MoveTo` / pathfinding | Weapons with hinged parts, creatures you steer yourself, doors, props, bosses moved by server code, cutscene puppets |
| Animator | Player characters spawn with one under the Humanoid | You add one (create it on the server if it must replicate) |

Rule of thumb: if gameplay moves the root itself (CFrame, `LinearVelocity`, `AlignPosition`), you do not need a Humanoid. Many enemy systems use an `AnimationController` plus an invisible, non-colliding `HumanoidRootPart` box as the root, and drive locomotion clips by measured speed (see [[Enemy and NPC Animation]]).

One API-level oddity: recent engine API dumps tag the `AnimationController` class line itself as deprecated, while the documentation still presents it as the normal way to animate a rig without a Humanoid and only its three own members are deprecated. In practice: keep using `AnimationController` as a container, never call its own `LoadAnimation`.

## The modern loading pattern

```lua
--!strict
local Players = game:GetService("Players")

local function getAnimator(character: Model): Animator
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- Player characters already have an Animator created by the server. Never create
	-- one on the client for a character: a client-made Animator does not replicate.
	return humanoid:WaitForChild("Animator") :: Animator
end

local SWING = Instance.new("Animation")
SWING.AnimationId = "rbxassetid://1234567890" -- placeholder id

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local animator = getAnimator(character)

-- Load ONCE per Animator and keep the track. Every LoadAnimation call makes a new track.
local swingTrack = animator:LoadAnimation(SWING)
swingTrack.Priority = Enum.AnimationPriority.Action

local function swing()
	swingTrack:Play(0.08) -- fade in over 0.08 s, weight 1, speed 1
end
```

## Where to keep Animation instances

- Put `Animation` objects in `ReplicatedStorage` (or under the script that uses them) so both server and client can read the ids.
- Never keep **source KeyframeSequences** in `ReplicatedStorage` "just in case": every `Pose` is an instance that every client downloads. One production game measured 600k instances in ReplicatedStorage, 323k of them enemy clip Poses, before moving them out (see [[Performance and Memory]] and [[Baked Clip Stubs and Archiving]]).
- `Animation` instances inside the character (the Animate script's children) are fine: they are tiny.

## Track facts every system depends on

- `track.Length` is **0 until the asset has loaded**. Anything that times gameplay from `Length`, `GetTimeOfKeyframe` or marker times must wait for it, or better, read those times from a data table extracted when the clip was made (see [[Markers and Events]]).
- `Play()` on a playing track **restarts it** from 0. Check `IsPlaying` if you mean "make sure it's playing".
- Every `LoadAnimation` call returns a **new** track, even for the same `Animation`. Loading per swing leaks tracks. The engine warns once one Animator passes 256 loaded tracks ("AnimationTrack limit of 256 tracks for one animator exceeded, new animations will not be played"). That number comes from the engine's warning text, not the docs page.
- Defaults: `Play(fadeTime = 0.1, weight = 1, speed = 1)`, `Stop(fadeTime = 0.1)`, `AdjustWeight(weight = 1, fadeTime = 0.1)`, `AdjustSpeed(speed = 1)`. The API dump shows the default as `0.100000001`, which is 0.1 stored as a float32.
- `Stopped` fires when the track stops (at the `Stop` call or at the natural end); `Ended` fires after the fade-out has finished and the track no longer affects the rig.

## Choosing a data format

| Need | Use |
|---|---|
| Hand-keyed clips from the Animation Editor | KeyframeSequence (default) or CurveAnimation (curve editor mode) |
| Clips written by code or offline tools | KeyframeSequence: simplest to build, every tool understands it |
| Fine tangent control, face animation | CurveAnimation (FloatCurve tangents, FaceControls channels) |
| Playback without publishing at all | Your own Lua player that samples KeyframeSequence data and writes `Transform` (see [[Lua Keyframe Player]]) |
| Runtime-blended state machines | Your own controller over normal tracks today; animation graphs are newer and still evolving |

One production game used **only** KeyframeSequences and never shipped CurveAnimations: all its offline tools (samplers, IK bakers, QA) were built around the KeyframeSequence model, and the CurveAnimation path stayed untested. That is a reasonable default for code-heavy pipelines.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| `Humanoid:LoadAnimation` in new code | Works, but deprecated; hides where the Animator is | `humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(anim)` |
| Creating an Animator on the client for a character | Your clip plays for you only | Use the server-created Animator |
| Loading the same Animation every time you play it | Memory growth, eventually the 256-track warning | Cache one track per Animator per clip |
| Shipping a `RegisterKeyframeSequence` id | Works in Studio, nothing moves live | Publish, or play the data with a Lua player |
| Reading `track.Length` right after loading | `0`, so timing code divides by zero or ends instantly | Wait for `Length > 0`, preload, or use a data table |
| Pose named after the joint (`RightShoulder`) | Clip "plays", nothing moves | Name Poses after the joint's Part1 (`RightUpperArm`) |
| Keeping source KeyframeSequences in ReplicatedStorage | Huge client instance counts, slow joins | Publish or bake to buffers; store sources server-side or on disk |

## See also
[[Animator Deep Dive]] · [[AnimationTrack Reference]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[CurveAnimation and Curve Channels]] · [[Rigs and Joints]] · [[Playback, Priorities and Blending]] · [[Replication and Ownership]] · [[Animation Asset Permissions and Groups]] · [[Publishing Animations]] · [[Lua Keyframe Player]]

## Connected notes
<!-- auto-links:start -->
[[Engine Gotchas]] · [[Animation Glossary]] · [[Animation Editor Advanced]] · [[Snippets - Playing Animations]] · [[Links - Animation playback]] · [[Links - Animation creation]] · [[Animation Start Here]]
<!-- auto-links:end -->
