---
tags: [gotchas, debugging, animator, engine]
---
# Engine Gotchas

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Treating "works in Studio" as "works". It means "works with Studio-only ids and Studio-only timing".
> - Avoid: Calling `LoadAnimation` per use.
> - Avoid: Using `Stopped` for cleanup of things that are still visible.
>
> Cost: TL;DR ~100 tok · whole note ~5.9k tok. Read more: ## 1. Loading, assets and ids · ## 3. Interpolation and easing · ## Common mistakes (short list)
<!-- tldr:end -->

This note collects the Roblox engine behaviours that surprise people who already know animation. Each entry says what you see, why the engine does it, and what to do instead. Most of these cost the reference project (one live action game) hours or days. Where a fact was measured in that project rather than documented, it says so. Where docs and measurements disagree, both are given, and the conflict is tracked in [[Open Questions]].

For a quick lookup by symptom, use the [[Troubleshooting Table]]. For a method to find causes you have not seen before, use [[Debugging Animation Problems]].

Source labels used below:
- **Docs**: the official Roblox engine reference or guides.
- **Measured**: measured in the reference project, usually by stepping the real `Animator` with `Animator:StepAnimations` in Edit and reading joint `Transform`s.
- **Rule of thumb**: experience, not a hard limit.

---

## 1. Loading, assets and ids

### 1.1 `RegisterKeyframeSequence` ids only work in Studio
**What you see.** Abilities, weapon hinges and marker-driven specials all work in Studio play tests. In a live server they do nothing. No error.

**Why.** `KeyframeSequenceProvider:RegisterKeyframeSequence(ks)` returns a temporary hash id for local playback. Docs say the id "cannot be used outside of Studio". The whole `KeyframeSequenceProvider` service is now marked deprecated in favour of `AnimationClipProvider` (Docs). On a live server `Animator:LoadAnimation` accepts the id, returns a track, and the track simply never has content.

**Reference project.** Dozens of weapon kits played their weapon-part clips this way; every blade part stood still live. Templated kit code later reintroduced the same call in a new weapon. This is a recurring regression, not a one-time bug. See [[Case Study - Abilities That Only Worked in Studio]].

**Fix.** Either publish the clip and use a real asset id ([[Publishing Animations]]), or play the `KeyframeSequence` data yourself with a Lua player ([[Lua Keyframe Player]]). Add a lint rule: grep your codebase for `RegisterKeyframeSequence` and `RegisterActiveKeyframeSequence` before every release.

### 1.2 A published id the game cannot use
**What you see.** The clip plays in your own test place but not in the game, or only for you.

**Why.** An animation asset can only be played by experiences owned by the same user or group that owns the asset (Docs, see [[Animation Asset Permissions and Groups]]). A clip uploaded to a personal account will not play in a group game, and the reverse. Nothing errors on the server; the client logs a failed load.

**Fix.** Upload to the owner of the experience. When moving a game between owners, re-upload every clip and rewrite every id.

### 1.3 `Length` is 0 until the clip has loaded
Docs: `AnimationTrack.Length` "returns 0 until the animation has fully loaded". Anything computed from it on the first frame is wrong:
- `track:AdjustSpeed(track.Length / desired)` divides 0 by something, giving speed 0. The clip freezes.
- `GetTimeOfKeyframe` errors if the animation is not loaded (Docs: check `Length > 0` first).
- Your own timers that use `Length` end at once.

**Measured extra case.** A clip freshly registered with `RegisterKeyframeSequence` plays nothing until its track's `Length > 0`, even in Studio. A verify run that reported `loaded false` with about 117 degrees of error was exactly this. Wait for `Length > 0` (with a timeout) before stepping it.

### 1.4 The first use of a clip is late
**What you see.** The first time a player uses an ability the animation starts 0.5 to 5 seconds late. Later uses are instant.

**Why.** The asset is fetched on first `LoadAnimation`/`Play`. Until it arrives the track has no keys.

**Reference project.** A stance-and-strike ability was "about 5 s late" on first use. The data timing was instant; the clips were not loaded. The fix was to load the tracks and call `ContentProvider:PreloadAsync` on the `Animation` objects when the kit loads, not when the move is pressed.

**Fix.** Preload every clip a kit can play when the kit is equipped. See [[Snippets - Playing Animations]].

### 1.5 `LoadAnimation` creates a new track every call
Docs: "Loads an Animation and returns a new AnimationTrack every time it's called", with an explicit warning not to use it to fetch an existing track. A pattern like `animator:LoadAnimation(anim):Play()` inside an input handler creates a new track per click.

Consequences:
- Memory and per-frame cost grow with every press.
- The engine warns once an Animator holds 256 tracks ("AnimationTrack limit of 256 tracks for one animator exceeded"); new animations stop playing past it. This limit is not on the reference page; it is the engine's warning text as widely reported.
- Stopping a track does not unload it.

**Fix.** Load once per Animator and cache, or look up with `Animator:GetTrackByAnimationId(id)` (Docs). Destroy tracks you will never use again.

### 1.6 `LoadAnimation` errors outside Workspace
Docs: the Animator must be a descendant of Workspace when you call `LoadAnimation`, or it errors while fetching the clip provider. Preview rigs in ReplicatedStorage, ServerStorage or a ViewportFrame's own `WorldModel`-less tree hit this. Parent the rig into Workspace (or a `WorldModel`) first.

### 1.7 Reserved names inside your own folders
Not an engine rule, but an engine-shaped trap: `FindFirstChild(name)` returns the first child with that name, whatever its class. In the reference project a clip named `Origin` was added to a kit folder that also held a `RemoteEvent` named `Origin`. The code found the clip, so the whole kit's server side stopped doing damage. Keep clips in their own subfolder, or check `IsA` on every lookup.

---

## 2. Track lifecycle

### 2.1 `Play` on a playing track restarts it
Docs note that calling `Play` on a playing track restarts it. Measured: it restarts at time 0. If you call `Play` every frame "to make sure it plays", it never gets past frame 0. Check `IsPlaying` first, or keep your own state.

### 2.2 `TimePosition` only sets while playing
Docs: setting `TimePosition` jumps to that time "only while the track is playing; call Play first". So to start a loop at a phase, call `track:Play(fade)` then set `track.TimePosition`. Setting it before `Play` is silently ignored, then `Play` resets to 0.

### 2.3 `Stopped` is not the end
Docs: `Stopped` fires when the track stops (on its own or by `Stop`), but the track may still move the rig during its fade-out. `Ended` fires once the fade is finished and the track no longer affects the rig. Use `Ended` for cleanup (destroying a welded prop, restoring a joint). Use `Stopped` for gameplay ("the swing is over, accept input").

**Measured details.**
- A one-shot that reaches its end holds its last pose and fades out over 0.3 s by itself. So a clip that ends far from the idle visibly "slides" back to the idle over 0.3 s.
- A track stopped early with `Stop(fade)` keeps its time running during the fade. A clip stopped mid-swing keeps swinging while fading.

### 2.4 `Looped` changes apply at the next loop
Docs: a change to `Looped` takes effect after the current run ends. Turning off `Looped` on an 8 s idle can take up to 8 s to matter. Stop the track instead.

### 2.5 `Stop` then `AdjustWeight` does nothing
Docs: after `Stop`, later `Stop` or `AdjustWeight` calls do not behave as expected until `Play` is called again. To fade a layer out and back in, keep it playing and use `AdjustWeight(0, fade)` then `AdjustWeight(1, fade)`.

### 2.6 Float comparisons on weights and time
Docs say not to compare `WeightCurrent` with `==`; check that the difference is small. Measured: track time is stored as float32. A Lua mirror that keeps time in float64 ends a clip a frame later than the Animator. Compare with a tolerance.

### 2.7 Priority set after `Play`
`Priority` is a property of the track (default from the clip). Setting it while the track is playing does change the mix, but code that sets it after `Play` is fragile: one frame plays at the clip's own priority. Set it before `Play`.

### 2.8 `KeyframeReached` is deprecated
The docs site lists `KeyframeReached` as deprecated in favour of `GetMarkerReachedSignal` (the API dump does not tag it; [[Open Questions]] D3). It still fires for keyframes whose `Name` is not the default `"Keyframe"`. Use `KeyframeMarker`s: they carry a `Value` string and do not need a keyframe of their own. See [[Markers and Events]].

---

## 3. Interpolation and easing

### 3.1 Rotations are not slerped
**Measured.** Between two keys the Animator does **not** slerp quaternions. For most clips it linearly blends **rotation vectors** (axis times angle of each key's Pose CFrame, measured from the joint's rest), choosing the pair of representations (`v` or `v - 2*pi*axis`) that are closest. It uses quaternion nlerp (shortest way) only when every keyframe in the sequence is evenly spaced (a marker-only keyframe off the grid counts) and every key is Linear.

**What you see.** Small turns look the same either way. Big key-to-key turns on joints far from rest take a different path from what Blender, Moon Animator previews or a slerp-based tool showed. Measured examples: an off-hand shoulder going overhead was 9 to 12 degrees off a slerp prediction; a slerp model was up to 178 degrees off on some shoulders, while a rotation-vector model matched within 0.24 degrees.

**Fix.** Keep key-to-key turns under about 120 degrees (the reference pipeline's hard rule), and if you predict poses offline, use the Animator's model. See [[How the Animator Really Behaves]] and [[Snippets - Building and Sampling Clips]].

### 3.2 Exactly 180 degree keys are ambiguous
**Measured.** A key segment of exactly 180 degrees makes the Animator itself "coin-flip" the direction. Three enemy clips showed this, and they were the only failures in a parity test of hundreds of clips. Never author an exact 180; split it into two keys of 90 or add 0.5 degrees.

### 3.3 Easing belongs to the first pose of a segment
A Pose's `EasingStyle`/`EasingDirection` describe how to travel **from this pose to the next** (Docs describe it as "the easing style to use to reach the next Pose's value"). Animators who think "this key eases in" put the easing on the destination key, which eases the wrong segment. Tools that write clips should put the easing of span i to i+1 on key i.

### 3.4 Legacy `Cubic` runs backwards
**Measured.** `Enum.PoseEasingStyle.Cubic` with direction `In` eases out, and vice versa. `CubicV2` exists to fix this and follows TweenService's directions (In = slow start). Never author legacy Cubic. If you import old clips with it, swap In and Out or convert to CubicV2.

### 3.5 Constant easing has three meanings
**Measured.** `Constant` + `In` jumps to the next key at once, `Out` holds the old value until the next key, `InOut` jumps at the midpoint. Docs are inconsistent here, and some tools treat all three as "hold". Pick one and test it. See [[Open Questions]].

### 3.6 Elastic and Bounce
The reference project has two conflicting measurements (reversed like legacy Cubic, or not reversed). The later, more careful measurement says they follow their direction and that `Bounce InOut` uses BounceIn's shape on both halves. The pipeline never used them. Bake overshoot into keys instead.

### 3.7 Weight-0 poses are not keys
A `Pose` with `Weight = 0` is a hierarchy placeholder: it exists so a child pose has a parent. It does not hold the joint. A joint holding still through a keyframe needs either a weighted key or no key at all (interpolation passes straight through). Tools that "clean up" clips by deleting placeholders break the hierarchy; tools that set every placeholder's weight to 1 add identity keys that snap joints to rest.

### 3.8 The top-level root pose is never applied
**Measured.** A keyframe's top-level Pose (HumanoidRootPart on characters, the `Root` bone on bone rigs) is never applied. Root lift and travel must be keyed on its first child (LowerTorso, or a body bone). A boss rig whose lift was keyed on `Root` did not rise; moving the key to a child bone fixed it.

### 3.9 Scale and clip translations
**Measured.**
- On a rig scaled with `Model:ScaleTo` (so `Model:GetScale()` is, say, 1.6), clip translations are multiplied by that scale.
- On a character scaled through Humanoid body-scale values, `GetScale()` stays 1 and clip translations are applied literally. A crouch authored at scale 1 leaves the feet hovering on a 1.6x character.

The reference project stores root offsets at game scale (x1.6) for that reason. See [[Scale and Animation]].

---

## 4. Blending and priorities

### 4.1 Higher priority wins per joint, not per clip
A track at `Action` overrides `Movement` only on the joints it keys. A swing that keys only the right arm leaves the legs walking. This is the basis of upper-body layering, and the cause of "my attack plays but the legs still run": the attack clip did not key the legs, or keyed them at weight 0.

### 4.2 Same-priority tracks average
Docs: tracks of equal priority blend by a weighted average of `WeightCurrent`. Measured: when their weights sum past 1 they are normalised. Two loops at the same priority at weight 1 each give a 50/50 pose that matches neither. Give layers distinct priorities, or crossfade weights so they sum to 1.

### 4.3 A partial weight blends toward what is below, or toward rest
**Measured.** A priority's total weight blends it over the priorities below it. If nothing below keys the joint, the lowest layer's rotation vector is scaled by its weight, which means it blends toward the **rest pose**, not toward "whatever was there". An idle at weight 0.5 with nothing under it shows a half-T-pose.

### 4.4 The default Animate script is always playing something
The default `Animate` LocalScript plays idle, walk, run, jump, fall, climb and the tool-hold `toolnone` clip. `toolnone` holds the right arm straight out whenever a `Tool` is equipped. If your weapon system holds the weapon differently, fade that track to about 0 (the reference project used weight 0.001) or replace its id. See [[The Default Animate Script]].

### 4.5 Many priority levels, few that are safe
`Enum.AnimationPriority` has Core, Idle, Movement, Action, Action2, Action3 and Action4. Pick a convention and write it down. Reference project conventions:
- Locomotion: Movement (over Animate, under everything else).
- Carry layer (weapon held): Action, right arm only. At Action2 it would cancel equip flourishes and read as an "attack" to other systems. (One later code comment says Action2; see [[Open Questions]] D1.)
- Equip flourishes: Action2.
- Weapon-part clips: Action2 with a 0.06 s fade.
- Ability clips: Action4 with a 0.05 s fade-in.

See [[Playback, Priorities and Blending]].

---

## 5. Joints

### 5.1 Your rig may not use Motor6D
Docs: `AnimationConstraint` is the default joint for R15 avatar rigs when the avatar joint upgrade is enabled, and `IsA("Motor6D")` is false on it. Its `C0`, `C1`, `Part0` and `Part1` exist as read-only aliases of its attachments. Code that does `for _, m in rig:GetDescendants() do if m:IsA("Motor6D")` finds nothing on an upgraded character.

**Fix.** Accept both everywhere: `j:IsA("Motor6D") or j:IsA("AnimationConstraint")`, and for skinned rigs also `Bone`. Read frames through a helper. Do not write `C0` on an `AnimationConstraint` (read-only); Docs recommend not editing `RigAttachment.CFrame` directly either.

### 5.2 Keys for missing joints are silently ignored
Clips bind by Pose name to the joint whose `Part1` (or Bone) has that name. A key for a part that has no joint on this rig does nothing. No warning. This is how one clip can play on several related rigs, and also why a renamed part makes a limb stop animating.

### 5.3 `Transform` is overwritten every frame
The Animator writes each animated joint's `Transform` every frame, in the animation step between `PreAnimation` and `PreSimulation` (Docs frame order). Writing `Transform` from `Heartbeat` or `PreRender` loses to the next animation step. Write procedural offsets in `PreSimulation`, after the Animator, so they reach physics. See [[Frame Order and RunService Timing]].

Caveat: forum bug reports acknowledged by Roblox staff say that with `Workspace.UseFixedSimulation` on (needed for server authority), `Transform` writes do not take effect while an animation is playing. Unverified as of October 2026; test procedural layers under that setting ([[Open Questions]] A8).

### 5.4 Throttled Animators do not rewrite `Transform`
Docs: `Animator.EvaluationThrottled` is true when evaluation was skipped this frame and the previous pose is reused, and the docs advise skipping procedural offsets in that case. Code like `joint.Transform = joint.Transform * offset` in `PreSimulation` then **compounds**: the offset is applied to last frame's already-offset value, and the joint spins away. Either check `EvaluationThrottled`, or keep your own base and write `base * offset`. Engine throttling is on by default for remote characters (`PreferLodEnabled` defaults to true).

### 5.5 Unjointed parts do not follow
Accessories and armour pieces with no weld to a body part do not follow animation. The reference project hit this with hoods and skull pieces on a cursor-following head: they had to be welded to the part they sit on first. See [[Accessories and Armor That Follow Animation]].

---

## 6. Replication

### 6.1 Who must play the track
Docs:
- On a player's character, tracks played by that client replicate to the server and other clients.
- On anything else (NPCs), tracks must be loaded and played on the **server** to replicate.
- The Animator must be created on the server. Tracks loaded through an Animator created locally do not replicate.

**Trap.** Playing an NPC clip from a LocalScript works perfectly for you and is invisible to everyone else. Sometimes that is what you want (client-driven enemies, see [[Enemy Animation State Protocol]]), but it must be a choice.

### 6.2 Markers fire per client, on that client's clock
Marker signals fire on whichever machine is playing (or receiving) the track, at its own time. A server that waits for a client's `Hit` marker is trusting the client. The reference project's server never plays clips: it uses marker times exported into data, with the server hit time set to the marker minus 0.06 s. See [[Markers and Events]].

### 6.3 Lua-driven joints do not replicate
Writing `Motor6D.Transform` from a script changes only that machine. If you play clips in Lua (or do procedural motion), every client must run the same logic from shared state (attributes, a relay). See [[Replication and Ownership]].

---

## 7. Edit mode versus Play

| Thing | Edit mode | Play |
|---|---|---|
| Physics | none | runs |
| `Motor6D.Transform` moves parts | no | yes |
| `Animator:StepAnimations(dt)` | yes, from the command bar or a plugin | not from game scripts |
| ViewportFrame animation | does not advance (measured) | advances |
| `require` of an edited module | may return a stale cached copy (measured, plugin context) | fresh per session |
| `Players:CreateHumanoidModelFromDescriptionAsync` | returns a rig without Motor6Ds (measured) | normal rig |
| ParticleEmitter `Rate` | does not emit in captures (measured) | emits |

Notes:
- Docs: `StepAnimations` requires plugin-level security, so normal Scripts and LocalScripts cannot call it. It is a preview tool. After playback stops you must reset the joints yourself.
- Measured: `StepAnimations(dt)` needs `dt > 0` to advance. One of the same project's tool snippets still calls `StepAnimations(0)` right after `Play(0)`, and whether a zero step applies the first pose was never settled ([[Open Questions]]). Use a tiny positive step such as `1e-4` to apply the start pose.
- Measured: `Humanoid:BuildRigFromAttachments` fails quietly on those Edit-mode rigs. Build test joints from the `*RigAttachment` pairs yourself. See [[Testing Animations in Studio]].

---

## 8. Importing

**Measured in one production game, 3D Importer from GLB:**
- Each GLB is turned 180 degrees about Y. glTF x/z land on Roblox -x/-z. A model authored in Blender facing -Y lands facing the Roblox LookVector, so a "yaw fix" of 180 is wrong; 0 is right.
- Imported clips can play with the whole body turned 180 degrees from the HumanoidRootPart, because the importer wrote the root correction onto the top-level root pose, which is never applied (3.8). Enemies "attacked from behind". The data fix is in [[Enemy Import Axis Fix]].
- One boss's root forward travel came in mirrored.
- The importer drops GLB base colours.
- Every import becomes a top-level model named `Scene`; with two imports present, `FindFirstChild("Scene")` picks the wrong one. Find imports by content.
- Imported clips land in `RBX_ANIMSAVES`, which is never cleaned up and can grow to hundreds of thousands of instances.

See [[Importing Models and Rigs]] and [[3D Importer Settings Reference]].

---

## 9. Limits that bite animation code

| Limit | Value | Source | What happens |
|---|---|---|---|
| Script `Source` length | 200,000 characters | Measured (save fails with "Unable to assign property Source") | Big generated animation modules fail to save. Split into child ModuleScripts. |
| Locals per function scope | 200 | Luau compiler | Generated code with one local per clip fails to compile. Use tables. |
| Tracks per Animator | 256 | Engine warning text | New tracks stop playing. Cache tracks. |
| Simultaneous Highlights | 255 (was 31 in older docs) | Docs, October 2026 | Extra Highlights do not render. Pool them (the reference project capped hit flashes at 8). |
| HttpService | about 500 requests per minute per server | Docs | Tooling that posts per clip stalls. Batch. |
| Kit folder | 2,500 instances | Project budget, not engine | See [[Performance and Memory]]. |

---

## 10. Cameras and UI near animation
- Tools that take positioned screenshots can leave `Camera.CameraType` as `Scriptable` in Edit. Reset it to `Custom` (measured).
- During play tests, Studio may reset camera changes made by scripts.
- Letterbox bars that sit inset or scaled wrongly on phones: set `ScreenGui.ScreenInsets` to `None`, turn off `ClipToDeviceSafeArea`, set `SafeAreaCompatibility` to `None`, and keep any auto-scaler away from the bars.
- Camera effects that write `Camera.CFrame` additively without removing their contribution next frame make the camera drift. See [[Snippets - Camera Shake and FX]].

---

## Common mistakes (short list)
- Treating "works in Studio" as "works". It means "works with Studio-only ids and Studio-only timing".
- Calling `LoadAnimation` per use.
- Using `Stopped` for cleanup of things that are still visible.
- Authoring with legacy Cubic, exact 180 degree turns, or 150+ degree key gaps.
- Keying root travel on the top-level root pose.
- Assuming `Motor6D` in code that touches joints.
- Compounding offsets on `Transform` without a base.
- Playing NPC tracks on a client by accident.

## See also
[[Troubleshooting Table]] · [[Debugging Animation Problems]] · [[How the Animator Really Behaves]] · [[AnimationTrack Reference]] · [[Animator Deep Dive]] · [[Performance and Memory]] · [[Testing Animations in Studio]] · [[Open Questions]]

## Connected notes
<!-- auto-links:start -->
[[Snippets - Lua Keyframe Player Core]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Animation Objects]] · [[Weapon Rig Player]] · [[Links - Animation playback]] · [[AI Animation and Motion from Video]] · [[Animation Start Here]]
<!-- auto-links:end -->
