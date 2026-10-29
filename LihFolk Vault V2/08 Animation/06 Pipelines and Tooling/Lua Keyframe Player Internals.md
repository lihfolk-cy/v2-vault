---
tags: [pipeline, runtime, keyframesequence, internals, interpolation, advanced, type/guide, area/animation, level/advanced, api/Animator, api/Pose]
---
# Lua Keyframe Player Internals

<!-- tldr:start -->
> [!tldr] TL;DR
> - Rotations are stored as rotation vectors (`axis * angle`, from `CFrame:ToAxisAngle()`), not quaternions or CFrames, because...
> - `CubicV2`: code `4 + direction` (In 0, Out 1, InOut 2): TweenService directions.
> - `SampleCFrame(clip, joint, t, scale)` wraps this and returns a CFrame; it is how tools and procedural systems read clips...
> - Track state: `TimePosition`, `Speed`, `Length`, `Looped`, `Priority` (and a numeric rank), `IsPlaying`, `WeightCurrent`...
>
> Cost: TL;DR ~160 tok · whole note ~5.0k tok. Read more: ## 1. The clip table · ## 3. Sampling one joint
<!-- tldr:end -->

How the general Lua keyframe player ("KeyframePlayer") of one production game works inside: parsing, the interpolation dispatch, easing codes, sampling at the ends, the weight and priority mixer, fades and time, marker delivery, level of detail, replication, `Compose`, and the API. Read [[Lua Keyframe Player]] first for the why. Every behaviour below was matched against `Animator:StepAnimations` in Edit; where the code encodes a measurement, it says so. Copyable core: [[Snippets - Lua Keyframe Player Core]].

## 1. The clip table

Every source (live KeyframeSequence, baked stub, streamed buffer) becomes the same structure:

```
clip  = { name, length, loop, priority, events = { {t, kf = name} | {t, marker = name, value} }, joints = { j }, byName, key }
j     = { name, n, t = {times}, rv = {rotation vectors}, p = {offsets}, ease = {codes},
          moves (any offset != 0), quat (nlerp mode), ra, rb (quaternion pairs, nlerp mode only),
          va, vb (closest rotation-vector pairs, always) }
```

Rotations are stored as **rotation vectors** (`axis * angle`, from `CFrame:ToAxisAngle()`), not [[quaternions]] or CFrames, because the Animator's dominant interpolation mode blends rotation vectors and its weighting scales them. A NaN guard returns zero for identity (ToAxisAngle can yield a NaN angle there).

### Parsing Poses

```lua
local function walk(parent: Instance, t: number)
	for _, p in parent:GetChildren() do
		if p:IsA("Pose") then
			if p.Weight > 0 then                               -- only weighted poses are keys (measured)
				local j = byName[p.Name] or newJoint(p.Name)
				local n = j.n + 1
				j.n = n
				j.t[n] = t
				j.rv[n] = logR(p.CFrame)
				j.p[n] = p.CFrame.Position
				j.ease[n] = easeCodeOf(p.EasingStyle, p.EasingDirection)
				if p.CFrame.Position.Magnitude > 1e-6 then j.moves = true end
			end
			walk(p, t)                                         -- placeholders still carry children
		end
	end
end
for _, kf in sortedKeyframes do
	if kf.Name ~= "Keyframe" then table.insert(events, { t = kf.Time, kf = kf.Name }) end   -- named keyframes fire KeyframeReached
	for _, m in kf:GetMarkers() do table.insert(events, { t = kf.Time, marker = m.Name, value = m.Value }) end
	for _, rootPose in kf:GetChildren() do
		if rootPose:IsA("Pose") then walk(rootPose, kf.Time) end   -- the top-level pose itself is never applied (measured)
	end
end
```

Joints are matched **by pose name**. The weapon rig player instead keys joints by the pair `parentPoseName \0 poseName` = `Part0 \0 Part1` ([[Weapon Rig Player]]), which disambiguates rigs where two motors drive parts of the same name.

### The interpolation mode decision (measured)

```lua
local even = true
if #kfs > 2 then
	local step = kfs[2].Time - kfs[1].Time
	for i = 3, #kfs do
		if math.abs((kfs[i].Time - kfs[i - 1].Time) - step) > 1e-4 then even = false break end
	end
end
for _, j in joints do for i = 1, j.n - 1 do if j.ease[i] ~= 0 then even = false end end end
```

- **Quaternion nlerp** only when **all keyframes of the sequence** are evenly spaced (a marker-only keyframe off the grid counts and breaks it) **and every key is Linear**.
- **Rotation-vector blend** otherwise. Joints, rig type and key count do not matter.

This is the general player's finding. The weapon rig player decides per joint from that joint's own key spacing; both were measured, on different sets of clips, and agree on the clips each was tested with. See [[Open Questions]].

### Pairing representations

A rotation vector `v` with angle `a` represents the same rotation as `-(v / a) * (2*pi - a)`. Between two keys the Animator lerps the two vectors **closest together** among the four combinations:

```lua
local TIE = 1e-5
local function flipR(v: Vector3): Vector3
	local a = v.Magnitude
	if a < 1e-12 then return v end
	return -(v / a) * (2 * math.pi - a)
end
local function pairOf(a: Vector3, b: Vector3): (Vector3, Vector3)
	local fa, fb = flipR(a), flipR(b)
	local best, pa, pb = (a - b).Magnitude, a, b
	local d = (fa - b).Magnitude; if d < best - TIE then best, pa, pb = d, fa, b end
	d = (a - fb).Magnitude;        if d < best - TIE then best, pa, pb = d, a, fb end
	d = (fa - fb).Magnitude;       if d < best - TIE then pa, pb = fa, fb end
	return pa, pb                                                   -- a near tie keeps the plain pair
end
```

For nlerp mode, the quaternion pair of each segment is precomputed with the second negated when their dot product is negative (shortest way). Both pairs are precomputed per segment at parse time, so sampling is allocation-free.

## 2. Easing codes

| Code | Pose easing | Curve `a = f(u)` |
|---|---|---|
| 0 | Linear | `u` |
| 1 | Constant, In | `u > 0 and 1 or 0` (jumps to the next key at once) |
| 2 | Constant, Out | `0` (holds the old value until the next key) |
| 3 | Constant, InOut | `u >= 0.5 and 1 or 0` (jumps at the midpoint) |
| 4 / 5 / 6 | Cubic In / Out / InOut (as played) | `u^3`, `1 - (1-u)^3`, `u < 0.5 and 4u^3 or 1 - (2 - 2u)^3 / 2` |
| 7 / 8 / 9 | Elastic In / Out / InOut | Penner's elastic, period 0.3 (InOut 0.45) |
| 10 / 11 / 12 | Bounce In / Out / InOut | standard bounce; **InOut uses BounceIn's shape on both halves** (measured) |

Mapping from Pose properties:

- `CubicV2`: code `4 + direction` (In 0, Out 1, InOut 2): TweenService directions.
- **Legacy `Cubic`: reversed**, In -> code 5, Out -> code 4. A legacy "Cubic In" key plays as an ease-out.
- `Elastic`, `Bounce`: `7 + direction`, `10 + direction`, **not reversed** in this player (a later measurement). The weapon rig player and the offline baker still treat them as reversed; the pipeline never uses them, so this stays an open contradiction ([[Open Questions]]).

The elastic In curve, exactly as coded:

```lua
local function elasticIn(u: number): number
	if u <= 0 then return 0 elseif u >= 1 then return 1 end
	return -(2 ^ (10 * (u - 1))) * math.sin((u - 1 - 0.075) * 2 * math.pi / 0.3)
end
```

## 3. Sampling one joint

```lua
local function sample(j, t: number, scale: number): (Vector3, Vector3)
	local ts, n = j.t, j.n
	local rv, p
	if n == 1 then
		rv, p = j.rv[1], j.p[1]
	elseif t <= ts[1] then
		rv = j.quat and qlog(table.unpack(j.ra[1])) or j.va[1]        -- the first key as paired
		p = j.p[1]
	elseif t >= ts[n] then
		if j.quat then rv = j.rv[n] else rv = j.vb[n - 1] end          -- past the end: measured per mode
		if not j.quat and math.abs(rv.Magnitude - math.pi) < 1e-4 then rv = -rv end   -- an exact-180 key is held the other way (measured)
		p = j.p[n]
	else
		local lo = findSegment(j, t)                                   -- binary search, with a cached hint for the common case
		local hi = lo + 1
		local e = j.ease[lo]                                           -- a segment eases by its FIRST key
		local a = (t - ts[lo]) / (ts[hi] - ts[lo])
		if e == 1 then a = a > 0 and 1 or 0
		elseif e == 2 then a = 0
		elseif e == 3 then a = a >= 0.5 and 1 or 0
		elseif e ~= 0 then a = EASE_FN[e](a) end
		if j.quat and e == 0 then                                      -- an eased segment blends rotation vectors even here (measured)
			local qa, qb = j.ra[lo], j.rb[lo]
			rv = qlog(qa[1] + (qb[1] - qa[1]) * a, qa[2] + (qb[2] - qa[2]) * a,
			          qa[3] + (qb[3] - qa[3]) * a, qa[4] + (qb[4] - qa[4]) * a)   -- nlerp; qlog is scale-invariant
		else
			rv = j.va[lo]:Lerp(j.vb[lo], a)
		end
		p = j.p[lo]:Lerp(j.p[hi], a)
	end
	if j.moves and scale ~= 1 then p = p * scale end                   -- offsets scale with Model:GetScale()
	return rv, p
end
```

Subtleties that each cost a measurement:

- **Which representation is held at the ends matters** once a weight below 1 scales the rotation vector (a 350 deg vector and a -10 deg vector are the same rotation at weight 1, very different at weight 0.5).
- `qlog(x, y, z, w) = (x, y, z) * 2 * atan2(|xyz|, w) / |xyz|` does not need a normalised quaternion, so the nlerp's normalisation is free.
- The hint cache (`j._h`, the last segment index) makes sequential playback O(1) per joint.

`SampleCFrame(clip, joint, t, scale)` wraps this and returns a CFrame; it is how tools and procedural systems read clips without tracks.

## 4. Tracks, time and fades

Track state: `TimePosition`, `Speed`, `Length`, `Looped`, `Priority` (and a numeric rank), `IsPlaying`, `WeightCurrent`, `WeightTarget`, a fade rate, flags `fresh` and `stoppedEarly`.

- **Play(fade = 0.1, weight = 1, speed)**: time to 0, `fresh = true`, `IsPlaying = true`, target weight set, fade rate `|target - current| / fade` (instant when fade is 0). A track already playing restarts from 0 and fades from its current weight.
- **Weights move linearly** toward the target at the fade rate each step.
- **Time is float32**: `t1 = f32(max(t, 0) + f32(dt * speed))`. The Animator keeps time in float32; matching it ends a clip on the same frame.
- **Looped:** past the end, fire events up to the length, wrap, fire `DidLoop`, fire events from 0 to the new time. A looped clip played backwards (an enemy backing away on its walk) wraps to its end.
- **One-shot reaching its end:** fire remaining events, time = length, `IsPlaying = false`, target 0, fade rate = current weight / **0.3 s**, `Stopped` fires. It **holds its last pose** while fading (measured).
- **Stop(fade = 0.1)**: target 0, `Stopped` fires. A track stopped early **keeps advancing time while it fades** (measured), wrapping if looped, clamped otherwise.
- **Ended** fires when weight and target both reach 0; the track then leaves the rig.
- A fresh track starts its event window at -1 so events exactly at t = 0 fire.

### Markers and named keyframes

Events between the previous and the new time fire in order: named keyframes on `KeyframeReached(name)`, markers on the signal from `GetMarkerReachedSignal(name)` with the marker's `Value`. They are **queued and flushed after the frame's joint writes**, so a handler that reads the pose sees this frame's pose. Handlers run in `task.spawn`. Out-of-range rigs still advance time, so markers still fire for gameplay even when nothing is drawn.

## 5. The mixer (measured)

The Animator's blend, as reproduced:

1. Tracks sorted by priority rank, then by play order. **Core is ranked -1**: its enum value is numerically the largest, but it is the lowest priority.
2. Weight is handed out **from the highest priority down**. Per joint, a remaining weight `rem` starts at 1.
3. For one priority level, sum the weights of its tracks that key the joint: `S`. If `S <= rem`, each track contributes its own weight `w`. Otherwise each contributes `w * rem / min(S, 1)` and nothing is left for lower priorities. Then `rem = max(rem - S, 0)`.
4. Offsets are handed out the same way, but with each track's weight capped at 1.
5. All rotation contributions go into **one weighted quaternion sum** (each added with the sign that keeps it in the accumulator's hemisphere). A joint with a single contributor keeps its rotation vector unchanged (no quaternion round trip).
6. **Leftover weight** (`rem > 0` after all priorities): if something else wrote this joint this frame (the real Animator, a procedural writer passing a base pose, or any change to `Transform` since our last write), that pose takes the leftover weight. Otherwise the leftover goes to **rest**: the result's rotation vector and offset are scaled by the total weight (rest = identity).
7. If the total weight reaches 1, the normalised quaternion is the rotation; otherwise rotation vector times total weight.

```
Example: Movement walk (w 1) + Action swing (w 0.6) on the same shoulder
  Action:   S = 0.6 <= rem 1   -> swing contributes 0.6, rem = 0.4
  Movement: S = 1   >  rem 0.4 -> walk contributes 1 * 0.4 / 1 = 0.4, rem = 0
  result = normalise(0.6 * q_swing + 0.4 * q_walk)
```

Joints no track keys any more are handed back: if their `Transform` still equals what the player last wrote, it is reset to identity; if someone else has written since, it is left alone.

## 6. The frame loop

One connection to `PreSimulation` (Heartbeat in Edit) steps every rig:

```
for each rig:
  removed from the game        -> forget it
  manual (test hook)           -> skip (driven by Step)
  no tracks                    -> just update its clock
  driven by Compose (< 0.25 s) -> skip (the writer steps it)
  every 15 frames: rate = rateOf(rig)        -- 1 / 2 / 4 / 0 by distance, bosses 1 within 300
  every 3 frames: visible = onScreen(camera, rootPos, pad = max(8, 1.5 * FXHeight))
  if rate == 0 or not visible: advance time only (events fire, nothing written)
  elseif (frame + phase) % rate == 0: step with dt = min(now - lastStep, 1)
flush queued events, run AfterStep hooks (dt clamped to 0..0.1), send the network outbox
```

- **Joint discovery** is cached and invalidated by `DescendantAdded` / `DescendantRemoving` of joint classes; tracks rebind lazily (version counter), so a character that gains a tool mid-clip does not break.
- **dt is clamped to 1 s** so a rig waking from a long sleep does not jump through an entire clip in one frame of events (it still advances, just bounded).
- Errors in one rig are caught (`pcall`), warned once, and that rig's tracks cleared; the loop survives.
- Measured cost and per-frame step counts are exposed in a stats table.

The off-screen test transforms the root position into camera space and compares against the frustum's half-angles plus 1.5x a padding radius, so a big model whose root is just off screen but whose body is visible keeps animating.

## 7. Compose: coexisting with a procedural writer

```lua
-- in the character animator, every frame, after computing its own pose:
local out = KeyframePlayer.Compose(character, basePose, scratch)   -- basePose[partName] = this writer's CFrame
if out then
	for name, cf in out do basePose[name] = cf end            -- tracks keyed these joints
end
applyToJoints(basePose)                                       -- the writer writes, once
```

`Compose` steps the rig's tracks with `external = true`: clips at priority Movement or lower are skipped (locomotion belongs to the writer), the writer's pose fills any leftover weight, and results go into a sink table instead of joints. Calling it marks the rig as externally driven; the shared loop leaves it alone until 0.25 s pass without a call. A sibling, `Overlay(model)`, does the same for a writer that has already applied its pose to the joints. `AfterStep(fn)` registers a hook that runs after each frame's writes (used for death ground-fitting in the reference project, see [[Ground Fitting Pipeline]]).

## 8. Replication protocol

Only the local character's tracks are sent. Operations are small arrays, batched into at most 24 per `FireServer`, one batch per frame:

| Op | Payload | When |
|---|---|---|
| 1 Play | id, clip key, fade, weight, speed, rank, looped, start time, server time, attrs | every Play |
| 2 Stop | id, fade | every Stop |
| 3 Speed | id, speed, time position, server time | at once when the change exceeds 6% of `max(|last|, 0.2)` or crosses zero; otherwise at most every 0.25 s |
| 4 Weight | id, weight, fade | changes under 0.001 dropped; reaching 0 or 1 sent at once; small changes (under 0.15) at most every 0.25 s; fade at least 0.1 except at the ends |
| 5 Time | id, time position, server time | when time is set |
| 6 Props | id, looped, rank | when Looped / Priority change |

Receivers:

- Resolve the clip key (replicated-storage path, `@Kit/Clip` for streamed kits, or `path|-Joint,Joint` for a runtime copy minus some joints) and create their own track on that player's character.
- **Latency compensation:** start time = sent time + (now - sent server time) x speed. A one-shot already past its end on arrival is not played at all.
- Speed changes re-sync the clock only if it drifted more than 0.12 s, so frequent speed tweaks never pop.
- A whitelist of `Animation` attributes (short strings without `;` or `=`, or booleans) travels with Play so listeners on other clients can read the same metadata.
- A client asks for the tracks already playing when it starts (late join).

Security: the relay forwards client-authored data to other clients. Validate keys against known clips and rate-limit on the server ([[Replication and Ownership]]).

## 9. Streamed kits

`Baked(kit, name)` returns `clip, pending`. The first request for a kit fires the clip network event; the server answers with `{ name, buffer }` lists and a done flag. Clips decode lazily on first use and are cached under `@kit/name`. `pending` stays true while the kit is on its way (given up after 30 s), so callers can show a procedural pose instead of a T-pose. Server side, `BufferOf(ks)` returns a stub's stored buffer byte for byte (patching the loop and priority bytes from the stub instance, since those may have been edited after baking) or encodes a live clip. Format: [[Clip Buffer Format]].

## 10. API summary

| Function | Purpose |
|---|---|
| `Register(ks, source?)` | token `ksp://<n>` for `Animation.AnimationId`; `source` lets a runtime copy replicate by its source's path |
| `LoadAnimation(animator, animation)` | Lua track for tokens (or empty id + `KS` attribute), else the real Animator |
| `Load(animatorOrModel, clip, opts)` | track for a KeyframeSequence, clip key or clip table; opts `looped`, `priority`, `animation`, `net = false` |
| `ClipOf(ks)`, `ClipFromKey(key)`, `Resolve(src)` | clip tables |
| `SampleCFrame(clip, joint, t, scale?)` | sample without a track |
| `Baked(kit, name)` | streamed server clip |
| `EncodeKS(ks, opts)`, `BufferOf(ks)` | compile to the binary format (server / Edit) |
| `Compose(model, base, out, dt?)`, `Overlay(model)` | coexist with a procedural writer |
| `PlayingTracks(target)`, `OnPlayed(target, fn)`, `Played(model)` | listeners over Animator and Lua tracks |
| `AfterStep(fn)` | hook after each frame's writes |
| `SetManual(model, on)`, `Step(model, dt)`, `Rig`, `Rigs`, `Forget` | Edit-mode testing |
| `Config` | `UseShim`, `AnimatorInStudio` (A/B), `NearRange` 60, `MidRange` 150, `AnimRange` 300, `ExternalMaxPriority` (Movement), `Replicate`, `PlayerCharacters`, `SpeedSendStep` 0.06; each overridable by an attribute of the same name on the module |

## 11. Testing it

- **A/B against the Animator:** play the same clip on two identical rigs, one through `StepAnimations`, one through `Step`, at 60 Hz, and compare every joint's `Transform`. Expect under 0.1 deg; anything near 180 deg segments is suspect in both.
- **Markers:** count fired events against the clip's markers over a full play, including at t = 0 and t = length.
- **Fades:** sample weight curves on Play with fade, Stop with fade, and natural end (0.3 s).
- **Blends:** two and three tracks at different priorities and weights, including totals over 1.
- **Exact-180 keys:** expect run-to-run disagreement in the Animator itself; do not chase it, re-key the clip.

## See also

[[Lua Keyframe Player]], [[Weapon Rig Player]], [[Clip Buffer Format]], [[How the Animator Really Behaves]], [[Keyframes, Easing and Interpolation]], [[Playback, Priorities and Blending]], [[Frame Order and RunService Timing]], [[Markers and Events]], [[Snippets - Lua Keyframe Player Core]], [[Open Questions]]

## Connected notes
<!-- auto-links:start -->
[[Engine Gotchas]] · [[AnimationTrack Reference]] · [[Snippets - Building and Sampling Clips]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Rotations Angles and Quaternions]] · Buffers and Binary Data · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Authoring Clips in Code]] · [[Baked Clip Stubs and Archiving]] · [[Animation Data from Blender to Roblox]] · [[Animation Glossary]] · [[Debugging Animation Problems]] · [[Performance and Memory]] · [[Animation Editor Advanced]] · [[Case Study - Abilities That Only Worked in Studio]]
<!-- related:end -->
