---
tags: [fundamentals, api, animator, reference]
---
# Animator Deep Dive

The `Animator` is the engine object that owns playback for one rig: it creates tracks, evaluates them each frame, mixes them, writes joint transforms and replicates what is playing. This note is the complete member reference plus everything the reference does not tell you. For measured numerical behaviour (interpolation, weights, fades) see [[How the Animator Really Behaves]]; for track members see [[AnimationTrack Reference]].

## Where an Animator lives

- Under a `Humanoid` (characters, walking NPCs) or under an `AnimationController` (everything else).
- **One Animator per rig.** The Animator drives the joints of the model it sits in. Two Animators on one rig fight over the same `Transform` values and the last writer wins each frame.
- **Nested rigs are separate rigs.** A held weapon model with its own `AnimationController` and `Animator` is animated by that Animator, not the character's. Tools that scan a model's joints should stop at a nested `Model` that has its own Animator, or they will double-drive the weapon's hinges.
- **It must be in the Workspace to load.** `LoadAnimation` errors when the Animator is not a descendant of the Workspace. A rig in a `ViewportFrame` needs a `WorldModel` inside the viewport to animate.
- **Create it on the server** if anything must replicate. The docs are explicit: an Animator created locally does not replicate tracks. Player characters spawn with one already created by the server under the Humanoid.

## Complete member list

Taken from the engine API dump and the class page (October 2026). Members marked "internal" are RobloxScript or engine only and listed so you can recognise them, not use them.

### Properties
| Property | Type | Access | Meaning |
|---|---|---|---|
| `PreferLodEnabled` | boolean | read/write, default `true` | Lets the engine lower evaluation frequency for remotely simulated rigs based on distance, screen coverage and frame budget. Set `false` on important NPCs to force full-rate evaluation. |
| `EvaluationThrottled` | boolean | read-only, not replicated | `true` on a frame where the Animator skipped evaluation and reused the previous pose. |
| `RootMotion` | CFrame | read-only, not browsable | Undocumented. Exists in the API dump; do not build on it. |
| `RootMotionWeight` | number | read-only, not browsable | Undocumented, as above. |
| `FacsReplicationData` | internal | hidden | Engine replication of face data. |

### Methods
| Method | Returns | Notes |
|---|---|---|
| `LoadAnimation(animation: Animation)` | `AnimationTrack` | New track every call. Errors if the Animator is not in the Workspace. On a model the client owns (its own character) the clip is also loaded for the server. |
| `GetPlayingAnimationTracks()` | `{AnimationTrack}` | Active tracks **including ones still fading out** (regardless of `IsPlaying`). A fading track leaves the list once its weight reaches 0. |
| `GetTrackByAnimationId(animationId)` | `AnimationTrack?` | First existing track loaded from that id, or nil. Does not create one. Use it instead of scanning the playing list. |
| `StepAnimations(deltaTime: number)` | `()` | Advances all playing tracks and applies the pose. **Plugin and command-bar only** (PluginOrOpenCloud capability); scripts cannot call it. You must reset joints yourself afterwards. |
| `ApplyJointVelocities(motors)` | `()` | Computes relative part velocities from the playing tracks and applies them to each motor's `Part1`. For handing an animated pose to physics (ragdolls) without a velocity pop. |
| `RegisterEvaluationParallelCallback(callback)` | `()` | Present in the API dump, not documented at the time of writing. Unverified behaviour: leave it alone until it is documented. |
| `LoadAnimationCoreScript`, `GetPlayingAnimationTracksCoreScript`, `LoadStreamAnimation*`, `StepAnimationsInternal`, `SynchronizeWith` | internal | Core scripts and camera/face tracking only. |

### Events
| Event | Fires |
|---|---|
| `AnimationPlayed(track)` | Whenever `Play()` is called on a track owned by this Animator. On other clients it also fires for replicated tracks, which makes it the standard hook for "react to whatever this NPC/player starts playing". |
| `AnimationPlayedCoreScript`, `AnimationStreamTrackPlayed`, `OnCombinedUpdate`, `OnGraphParameterUpdate`, `OnStreamingUpdated2`, `StreamSyncRequest` | internal |

### Deprecated alternatives
| Old | Replacement |
|---|---|
| `Humanoid:LoadAnimation`, `Humanoid:loadAnimation` | `Animator:LoadAnimation` |
| `Humanoid:GetPlayingAnimationTracks`, `Humanoid.AnimationPlayed` | the Animator versions (the API dump tags the Humanoid ones deprecated) |
| `AnimationController:LoadAnimation`, `:GetPlayingAnimationTracks`, `.AnimationPlayed` | the Animator versions |

The deprecated `LoadAnimation` on a Humanoid or AnimationController creates an Animator if none exists and forwards the call. That convenience is exactly why it is dangerous on the client: if it creates the Animator locally, nothing replicates.

## What the Animator does each frame

```
PreRender (client)           <- camera, UI
render
PreAnimation                 <- last chance to change tracks before this frame's evaluation
Animator evaluation          <- every Animator: advance time, sample, mix, write Transform
PreSimulation                <- procedural layers go here: read the animated Transform, add to it
physics step (Transform values are applied in a batched parallel job just before it)
PostSimulation / Heartbeat
```

Details and consequences are in [[Frame Order and RunService Timing]]. The key fact: the Animator **overwrites** `Transform` on every joint it drives, every frame. Anything you write to `Transform` before the Animator runs is lost; anything you write in `PreSimulation` sticks for that frame and is overwritten next frame (so you must write it again every frame).

Joints that no playing track keys are left alone by the Animator: their `Transform` keeps whatever was last written. That is why a joint you posed procedurally and then stopped updating can stay frozen in that pose, and why tools that take over a joint should hand it back to identity when they stop.

## LOD, throttling and the "skipped frame" problem

Three layers control how often an Animator evaluates:

| Control | Scope | Values |
|---|---|---|
| `Workspace.ClientAnimatorThrottling` | All Animators on a client | `ClientAnimatorThrottlingMode`: `Default`, `Disabled`, `Enabled`. Throttling applies to animations on **remotely simulated** models; intensity depends on camera visibility, FPS and the number of active animations. |
| `Animator.PreferLodEnabled` | One Animator | `true` (default) allows LOD; `false` forces full fidelity. Disabling it on many rigs costs performance. |
| `Animator.EvaluationThrottled` | Read-only, per frame | Tells you this frame reused last frame's pose. |

**Why it matters for procedural code.** If you add a procedural offset in `PreSimulation` by multiplying onto the current `Transform` (`m.Transform = m.Transform * extra`), then on a throttled frame the Animator did not rewrite `Transform`, so you multiply onto **your own previous result** and the offset accumulates: a head that spins further every throttled frame. The docs' own sample skips the procedural write when `EvaluationThrottled` is true. Two safer patterns:

```lua
--!strict
local RunService = game:GetService("RunService")

-- Pattern A: skip on throttled frames (the documented approach)
RunService.PreSimulation:Connect(function()
	if animator.EvaluationThrottled then
		return -- Transform still holds last frame's animated pose + last frame's offset
	end
	neck.Transform = neck.Transform * lookOffset
end)

-- Pattern B: own the base yourself. Cache what the Animator wrote, compose from the cache.
local lastAnimated: CFrame = CFrame.identity
local lastWritten: CFrame? = nil
RunService.PreSimulation:Connect(function()
	local current = neck.Transform
	-- If the joint does not hold our own last write, the Animator wrote a fresh pose this frame.
	if lastWritten == nil or not current:FuzzyEq(lastWritten, 1e-4) then
		lastAnimated = current
	end
	local out = lastAnimated * lookOffset
	neck.Transform = out
	lastWritten = out
end)
```

Pattern B is what one production Lua keyframe player does to decide whether "someone else wrote this joint this frame" (a `FuzzyEq` check against its own last write, tolerance 1e-4, because a `Transform` reads back slightly re-orthonormalised).

## StepAnimations: the Edit-mode workhorse

`StepAnimations` is the only way to run the real Animator without pressing Play, so every serious offline animation tool uses it. Measured rules from one production pipeline:

- It works in Edit mode but needs **`dt > 0`** (measured). One of the same project's tool snippets calls `StepAnimations(0)` right after `Play(0)`, which contradicts that rule; the sources do not say whether a zero step applies the first pose. Use a tiny positive dt (for example `1e-4`) and you never have to know.
- The clip must have **loaded**: wait for `track.Length > 0`. A freshly registered KeyframeSequenceProvider clip plays nothing until then; one QA run that skipped the wait reported a 117 degree "error" that was just an unloaded clip.
- Edit mode has **no physics**, so `Transform` values do not move parts. Read joint `Transform`s and compute part CFrames yourself (see [[Motor6D Math and CFrame Composition]]), or pose the parts directly.
- **Reset joints afterwards** (the docs say so explicitly): set every `Transform` back to identity, or your Edit-mode rig is left posed and the pose gets saved into the place.
- ViewportFrame rigs cannot be advanced in Edit.

```lua
-- Command bar / plugin only. Samples a clip on a rig at 60 Hz and returns joint transforms.
local function sampleWithAnimator(rig: Model, anim: Animation, duration: number)
	local animator = rig:FindFirstChildWhichIsA("Animator", true) :: Animator
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = false
	local t0 = os.clock()
	while track.Length <= 0 and os.clock() - t0 < 2 do task.wait() end -- wait for the asset
	track:Play(0) -- no fade: we want the raw clip
	local frames = {}
	local dt = 1 / 60
	for i = 0, math.floor(duration / dt) do
		animator:StepAnimations(i == 0 and 1e-4 or dt) -- dt must be > 0
		local f = {}
		for _, j in rig:GetDescendants() do
			if j:IsA("Motor6D") or j:IsA("AnimationConstraint") or j:IsA("Bone") then
				f[j:GetFullName()] = (j :: any).Transform
			end
		end
		frames[i + 1] = f
	end
	track:Stop(0)
	animator:StepAnimations(1e-4)
	for _, j in rig:GetDescendants() do -- reset, as the docs require
		if j:IsA("Motor6D") or j:IsA("AnimationConstraint") or j:IsA("Bone") then
			(j :: any).Transform = CFrame.identity
		end
	end
	track:Destroy()
	return frames
end
```

Keep each Studio call short. One team that ran many such samplers in parallel froze Studio for about 25 minutes at 100% CPU; their rule became "one Studio call at a time, each under 1.5 s, a few clips per call" (see [[Studio Tooling Architecture]]).

## ApplyJointVelocities and the ragdoll hand-off

When you switch a running character to physics (ragdoll, knockback), the parts start from rest unless you give them the velocity the animation had. `ApplyJointVelocities(motors)`:
- computes each joint's relative velocity from the currently playing tracks and applies it to the motor's `Part1`;
- skips joints whose two parts are still in the same assembly, so **disable or remove the rigid joints first**, then call it;
- does not disable joints itself;
- accepts motors that are not in the DataModel.

Typical order: disable the Motor6Ds (or switch AnimationConstraints to `IsKinematic = false`), enable the ball sockets, call `ApplyJointVelocities` with the list of joints, set the Humanoid state to `Physics` or `Ragdoll`. See [[Ragdolls and Physics-Based Animation]] and [[AnimationConstraint and Physically Simulated Characters]].

## Replication in one table

| Animator location | Who must call `LoadAnimation` / `Play` for everyone to see it |
|---|---|
| Under a **player's character** (Humanoid or AnimationController in it) | That player's **client** (or the server). Client-started tracks replicate to the server and other clients. |
| Anywhere else (NPCs, props, weapons not in a character) | The **server**. Client-played tracks stay local. |
| An Animator **created on the client** | Nobody else, ever. |

What replicates is **track state** (which clip, play/stop, weight, speed, priority, time), not joint transforms. Each client evaluates the tracks itself. Procedural `Transform` writes never replicate. Full treatment, including bandwidth and late joiners, in [[Replication and Ownership]].

## Things the docs do not say (measured or observed)

- **Joints are matched by name.** A Pose (or curve folder) binds to the joint whose `Part1` has that name (for Bones, the bone's name). Keys for joints that do not exist are silently ignored. A misspelt Pose name gives a clip that "plays" and moves nothing.
- **The top-level pose is never applied.** The first Pose under each Keyframe (`HumanoidRootPart`, or a bone rig's `Root`) does nothing. Root motion must be on a child joint.
- **Translation offsets scale with `Model:GetScale()`.** Body-scaled avatars report 1, so they get no scaling. See [[Scale and Animation]].
- **Interpolation is not slerp** for most clips. See [[How the Animator Really Behaves]].
- **Missing Animator in Edit-built rigs.** `Players:CreateHumanoidModelFromDescription` (now deprecated in favour of `CreateHumanoidModelFromDescriptionAsync`) in Edit mode returned a rig with no Motor6Ds in one project; `BuildRigFromAttachments` failed quietly. Rebuild joints from the `RigAttachment` pairs for Edit-mode test dummies.
- **Retargeting.** `Workspace.Retargeting` (`AnimatorRetargetingMode`: `Default`, `Disabled`, `Enabled`) adapts joint transforms to body proportions. Community reports say turning it on changed how existing R15 clips and C0-driven code looked; if a clip that used to be exact now looks off on unusual avatars, check this property first. Exact algorithm: undocumented.

## Diagnosing "my animation doesn't play"

Work down this list; each line is a real cause seen in production.

1. `track.Length` stays 0: the asset never loaded. Wrong id, no permission, Studio-only id in a live server, or a deleted/moderated asset. See [[Animation Asset Permissions and Groups]].
2. Loads but nothing moves: Pose names do not match the rig's Part1 names; or the clip only keys the top-level root pose.
3. Moves for you, not others: Animator created on the client, or a non-character rig played from the client.
4. Plays but is invisible under other motion: lower priority than something keying the same joints (see [[Playback, Priorities and Blending]]).
5. Plays for one frame then snaps: someone calls `Play()` every frame (restarts it), or another system calls `Stop` on all playing tracks (a common "stop everything" loop over `GetPlayingAnimationTracks()`).
6. Works on R15, not on R6 (or the reverse): the clip was made for the other rig type.
7. Works in Studio Edit tests, not in Play: the test used `StepAnimations` with a registered id.

## See also
[[Animation Objects]] · [[AnimationTrack Reference]] · [[How the Animator Really Behaves]] · [[Frame Order and RunService Timing]] · [[Replication and Ownership]] · [[Lua Keyframe Player]] · [[Testing Animations in Studio]] · [[Animation LOD]] · [[Engine Gotchas]]

## Connected notes
<!-- auto-links:start -->
[[Debugging Animation Problems]] · [[Snippets - Lua Keyframe Player Core]] · [[Troubleshooting Table]] · [[Performance and Memory]] · [[Links - Animation playback]] · [[Links - Rigs]] · [[Animation Start Here]]
<!-- auto-links:end -->
