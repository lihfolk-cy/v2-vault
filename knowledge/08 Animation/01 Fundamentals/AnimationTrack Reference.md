---
tags: [fundamentals, api, reference, animationtrack]
---
# AnimationTrack Reference

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `Play()` every frame -> Check `IsPlaying`
> - Avoid: Setting `TimePosition` before `Play` -> Play first
> - Avoid: Using `Length` right after loading -> Wait, preload, or use data
>
> Read more (14 KB note): ## Properties · ## Behaviour you need to know · ## Common mistakes
<!-- tldr:end -->

An `AnimationTrack` is one loaded instance of a clip on one [[Animator Deep Dive|Animator]]. You never create it with `Instance.new`; `Animator:LoadAnimation(animation)` returns a fresh one every call. This note lists every member with its exact signature and default, then covers the behaviour you only learn by shipping: restart rules, time semantics, the difference between `Stopped` and `Ended`, and what to do while the asset is still loading.

Member list verified against the engine API dump and the class page (October 2026).

## Properties

| Property | Type | Writable | Meaning and nuance |
|---|---|---|---|
| `Animation` | `Animation?` | no | The Animation the track was loaded from. Handy for looking up attributes you stored on the Animation (clip metadata). |
| `IsPlaying` | boolean | no | True between `Play()` and the stop (manual `Stop()` or natural end of a non-looped clip). A track that is fading out after `Stop()` is **not** playing, but still affects the rig and still shows in `Animator:GetPlayingAnimationTracks()`. |
| `Length` | number | no | Seconds at speed 1. **0 until the clip has loaded.** For a KeyframeSequence, the time of the last Keyframe. |
| `Looped` | boolean | yes | Starts as the clip's `Loop`. Changing it during play takes effect at the end of the current pass. Works with negative speed. |
| `Priority` | `Enum.AnimationPriority` | yes | Starts as the clip's `Priority`. Highest wins per joint; equal priorities blend by weight. See [[Playback, Priorities and Blending]]. |
| `Speed` | number | no | Current rate. Set with `Play(_, _, speed)` or `AdjustSpeed`. Real duration = `Length / Speed`. |
| `TimePosition` | number | yes | Position in seconds. Can only be set while the track is playing (call `Play()` first). |
| `WeightCurrent` | number | no | The weight right now, moving linearly toward `WeightTarget` during a fade. |
| `WeightTarget` | number | no | Where the weight is heading. Set by `Play`, `Stop`, `AdjustWeight`. Compare with a tolerance (e.g. `math.abs(a - b) < 0.001`), never `==`. |

**Replication.** None of these is replicated as an ordinary property. What replicates is the track's *state* through its Animator: the engine's internal replication event carries the clip, play state, fade time, weight, speed, time position, priority and looping. So `Looped` and `Priority` changes made by the owner should reach other clients, and remote clients start the clip close to the owner's time. This is inferred from the internal event's fields, not documented; network latency still means remote copies run slightly behind. See [[Replication and Ownership]].

## Methods

| Method | Defaults | Notes |
|---|---|---|
| `Play(fadeTime: number?, weight: number?, speed: number?)` | `0.1`, `1`, `1` | Starts from time 0 and fades the weight from its current value to `weight` over `fadeTime`. **Calling it on a playing track restarts it.** |
| `Stop(fadeTime: number?)` | `0.1` | Fades the weight to 0 over `fadeTime`, whatever the start weight. After `Stop`, call `Play` again before `AdjustWeight` or another `Stop`. |
| `AdjustSpeed(speed: number?)` | `1` | Positive forward, negative backward, 0 pauses. Immediate (no ramp). |
| `AdjustWeight(weight: number?, fadeTime: number?)` | `1`, `0.1` | Changes weight with a linear fade. Only matters relative to other tracks of the same priority and to the weight left for lower priorities. |
| `GetMarkerReachedSignal(name: string)` | | Signal that fires when a `KeyframeMarker` (or marker curve entry) with that name is passed. The listener receives the marker's `Value` string. See [[Markers and Events]]. |
| `GetTimeOfKeyframe(keyframeName: string)` | | Time of the **first** Keyframe with that name. **Errors** for an unknown name or an unloaded clip; check `Length > 0` first. |
| `GetParameter(key)`, `SetParameter(key, value)`, `GetParameterDefaults()` | | For animation graph clips. `SetParameter` replaces non-finite numbers with 0 and warns; parameters set before the graph loads are applied when it is ready. `GetParameterDefaults` returns `{}` for a normal clip. |
| `GetTargetNames()`, `GetTargetInstance(name)`, `SetTargetInstance(name, target)` | | Present in the API, undocumented at the time of writing. Unverified; do not depend on them yet. |

Internal (RobloxScript only): `GetDebugData`, `ResetGraph`, `UpdateGraphNodeDefinition`, `UpdateGraphNodeProperty`, event `ParameterChanged`.

## Events

| Event | When it fires | Use it for |
|---|---|---|
| `Stopped` | When the track stops playing: at the `Stop()` call, or when a non-looped track reaches its end. | Chaining the next action, unlocking input. |
| `Ended` | After the track has **completely** stopped affecting the rig: any fade-out finished. After `Stop(3)`, `Stopped` fires at once and `Ended` about 3 s later. | Cleanup (destroying the track, removing temporary parts). |
| `DidLoop` | When a looped track completes a cycle (fired on the next update). The docs say it may also fire at the exact end of a non-looped track: do not rely on that. | Footstep counters, loop-synced effects. |
| `KeyframeReached(keyframeName)` | When playback passes a Keyframe whose Name is not "Keyframe". | Legacy. Use markers instead. The documentation site lists it under deprecated members in some views while the API dump does not tag it; either way markers are strictly better (they carry a `Value` and can be listened to by name). |

## Behaviour you need to know

### Restart semantics
`Play()` always restarts at 0, even on a playing track. Code like this restarts the walk every frame and the character appears frozen in the walk's first pose:

```lua
-- WRONG: called every frame from a movement loop
if speed > 1 then walkTrack:Play() end

-- RIGHT
if speed > 1 and not walkTrack.IsPlaying then walkTrack:Play(0.2) end
```

### Starting part-way through
`TimePosition` can only be set while playing. To start a clip at 0.4 s (joining an NPC's attack late, resuming a cutscene):

```lua
track:Play(0)            -- must be playing first
track.TimePosition = 0.4 -- now valid
```

On a remote client that joins an attack late (for example from a replicated "started at server time T" attribute), compute `TimePosition = (now - T) * speed`, clamp it below `Length`, and play with a short fade. One production enemy system used exactly this to join combo clips part-way via a time-offset attribute.

### Freezing on a pose
`AdjustSpeed(0)` pauses; combined with `TimePosition` you can hold any frame (poses for UI previews, a hit-stop freeze). Markers do not fire while paused, and they do **not** fire for the span you skip by setting `TimePosition` (see [[Markers and Events]]).

### End of a one-shot
A non-looped track that reaches its end: `IsPlaying` becomes false, `Stopped` fires, and the rig **holds the last pose while the weight fades out**. Measured in one production project: that automatic fade lasts **0.3 s** regardless of the fade you passed to `Play`. During those 0.3 s whatever plays underneath (usually the idle) fades back in. That is why the first and last poses of an action clip must be near the idle: if the last frame is 90 degrees away from the idle, the 0.3 s blend is visible as a slow drift. One team's QA rule: last frame within 75 degrees of the idle on every arm joint, first frame within 90.

### Stop keeps time running
After `Stop(fade)` the track's time **keeps advancing during the fade-out** (measured). The motion keeps going while it fades rather than freezing. If you want a freeze-then-fade, `AdjustSpeed(0)` before `Stop`.

### Fades are linear in weight
`WeightCurrent` moves at a constant rate: `|target - current| / fadeTime` per second. There is no ease on the fade. If you want an eased transition (for example a slow-in recovery), drive `AdjustWeight` yourself over several frames, or author the transition into the clip.

### Stop with fadeTime 0 on legacy motors
The docs warn: `Stop(0)` on joints whose `Motor.MaxVelocity` is 0 can leave them frozen in place. Characters built by Roblox are fine; hand-built rigs with `MaxVelocity = 0` Motor6Ds should use a small fade or a non-zero `MaxVelocity`.

### Time precision
Track time is stored as **float32** (measured). Over a very long looped track (hours of an ambient loop) the time quantisation grows, and any code that predicts the Animator's frame-exact end (for example an offline tool that must end a clip on the same frame as the Animator) must accumulate time in float32 too. The relevant step is `t = f32(t + f32(dt * speed))`.

### Negative speed
`AdjustSpeed(-1)` plays backward. `Looped` still works. A non-looped track playing backward ends at time 0. Markers fire as playback passes them; test your marker logic in reverse explicitly if you use this (for example a "rewind" ability), because many marker handlers assume time increases.

### Weight 0 tracks still cost
A playing track at weight 0 is still evaluated. If you keep a library of tracks "playing at weight 0" to blend in instantly, you pay for every one each frame. Stop tracks you do not need.

## Loading and the Length problem

`LoadAnimation` returns immediately; the asset downloads in the background. Until it arrives:
- `Length == 0`;
- `GetTimeOfKeyframe` errors;
- `Play()` is accepted and the track starts once the data arrives (typically you just see a late start).

Three ways to handle it, from weakest to strongest:

```lua
--!strict
local ContentProvider = game:GetService("ContentProvider")

-- 1. Wait for the length (bounded)
local function waitLoaded(track: AnimationTrack, timeout: number): boolean
	local t0 = os.clock()
	while track.Length <= 0 do
		if os.clock() - t0 > timeout then return false end
		task.wait()
	end
	return true
end

-- 2. Preload all of a kit's Animation objects when the kit is equipped, not on first use
local function preload(animations: {Animation})
	ContentProvider:PreloadAsync(animations) -- yields until fetched (or failed)
end

-- 3. Never read timing from the track at all: read it from data extracted at authoring time
local MoveTimes = { Slash1 = { length = 0.42, hit = 0.20 } }
```

A real case: a shared "stance then strike" ability fired about 5 seconds late the first time it was used, because its stance clip had not loaded and the state machine waited on it. The data timing was fine; the fix was loading the tracks and calling `ContentProvider:PreloadAsync` when the kit loaded. General rule: **preload ability clips before first use** and keep gameplay timing in data (see [[Markers and Events]]).

## Track lifetime and caching

- Tracks belong to the Animator. When the character respawns, the old Animator and its tracks are destroyed; load again on `CharacterAdded`.
- Cache tracks per Animator per clip:

```lua
--!strict
local cache: {[Animator]: {[string]: AnimationTrack}} = setmetatable({}, { __mode = "k" }) :: any

local function getTrack(animator: Animator, anim: Animation): AnimationTrack
	local perAnimator = cache[animator]
	if not perAnimator then
		perAnimator = {}
		cache[animator] = perAnimator
	end
	local track = perAnimator[anim.AnimationId]
	if not track then
		track = animator:LoadAnimation(anim)
		perAnimator[anim.AnimationId] = track
	end
	return track
end
```

- `Animator:GetTrackByAnimationId(id)` finds an existing track without your own cache, but returns only the first one; if two systems loaded the same id, you get one of them.
- The engine warns after 256 loaded tracks on one Animator (from the warning text; not on the docs page). If you hit it, you are loading in a loop.

## Typical recipes

### Play once and wait for the end, with a safety timeout
```lua
local function playOnce(track: AnimationTrack, fade: number?): boolean
	track.Looped = false
	track:Play(fade or 0.1)
	local done = false
	local conn = track.Stopped:Once(function() done = true end)
	local limit = os.clock() + math.max(track.Length, 0.1) / math.max(track.Speed, 0.01) + 1
	while not done and os.clock() < limit do task.wait() end
	conn:Disconnect()
	return done
end
```
The timeout matters: if the asset never loads, `Stopped` may never fire and the coroutine would hang forever.

### Speed-matched locomotion
```lua
-- 'groundSpeed' = studs/s the clip was authored for (store it as an attribute on the Animation)
local rate = math.clamp(currentSpeed / groundSpeed, 0.6, 1.8)
walkTrack:AdjustSpeed(rate)
```
Measured consequence in one game: a run clip whose rate was capped at 1.5x slid its feet at sprint speed (about 64 studs/s against a 26 studs/s authored run). Either raise the cap, author a faster run, or fix feet procedurally (see [[Locomotion Systems]]).

### Stretch a clip into a gameplay window
A 1.2 s stance clip that must fit a 0.7 s window plays at `1.2 / 0.7 ≈ 1.71`. Keep any marker-driven timing consistent: marker times in data must be divided by the same speed.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| `Play()` every frame | Frozen on frame 0 | Check `IsPlaying` |
| Setting `TimePosition` before `Play` | Ignored | Play first |
| Using `Length` right after loading | 0, instant ends, divide-by-zero | Wait, preload, or use data |
| Using `KeyframeReached` with renamed keyframes | Names lost when tools rebuild the clip | Markers |
| Assuming `Ended` fires at `Stop` | Cleanup runs late | Use `Stopped` for logic, `Ended` for cleanup |
| Comparing `WeightCurrent == 1` | Never true mid-fade, sometimes never true | Tolerance |
| Leaving zero-weight tracks playing | CPU cost per rig | Stop them |

## See also
[[Animator Deep Dive]] · [[Playback, Priorities and Blending]] · [[Markers and Events]] · [[How the Animator Really Behaves]] · [[Snippets - Playing Animations]] · [[Lua Keyframe Player]]

## Connected notes
<!-- auto-links:start -->
[[Animation Objects]] · [[Engine Gotchas]] · [[Weapon Rig Player]] · [[Snippets - Lua Keyframe Player Core]] · [[Links - Animation playback]] · [[Hit-Stop]] · [[Animation Start Here]]
<!-- auto-links:end -->
