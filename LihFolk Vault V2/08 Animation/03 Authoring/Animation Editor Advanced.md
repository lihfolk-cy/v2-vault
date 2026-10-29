---
tags: [authoring, animation-editor, curve-editor, ik, events, studio]
---
# Animation Editor Advanced

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Converting to curves when a downstream tool needs KeyframeSequences.
> - Avoid: Converting with Euler rotation type on a shoulder-heavy clip and getting gimbal wobble that cannot be undone.
> - Avoid: Running Optimize Keyframes and not re-checking contacts and big turns.
>
> Cost: TL;DR ~110 tok · whole note ~4.3k tok. Read more: ## 1. The Curve Editor · ## 2. Keyframe optimisation · ## Common mistakes
<!-- tldr:end -->

The features beyond basic posing: the Curve Editor and `CurveAnimation`, keyframe optimisation, IK inside the editor, animation events and named keyframes, imports (including video capture), partial-body clips, and how what you see in the editor differs from what the engine plays. Read [[Animation Editor Workflow]] first.

Labels: "Roblox docs" = checked against the official Animation Editor, Curve Editor, Animation events and Animation capture pages (October 2026). "Measured" = measured in the reference project (one live action game). "Unverified" = reported by the community or older docs, not confirmed on the current docs pages.

## 1. The Curve Editor

### What switching actually does
Roblox docs: clicking the **Curve Editor** icon (top-left of the timeline) asks you to confirm that your `KeyframeSequence` clip **will convert to a `CurveAnimation`** clip. This is a format change, not a view toggle:

| | KeyframeSequence | CurveAnimation |
|---|---|---|
| Storage | Keyframes holding a tree of `Pose`s (one CFrame per joint per key) | Roblox docs: a hierarchy of `Folder`s named after the joints, each holding a `Position` (`Vector3Curve`) and a `Rotation` (`EulerRotationCurve` or `RotationCurve`); other numeric channels (for example FACS face controls) as `FloatCurve`s |
| Rotation | quaternion per key (CFrame) | Euler angles **or** quaternions, chosen when you convert |
| Easing | style + direction per pose (Linear, Constant, CubicV2, Elastic, Bounce) | interpolation mode per key: Linear, Constant, Cubic (with tangents) |
| Tangent control | none | yes, on Cubic keys |
| Bounce / Elastic | native | only approximated with **Generate Curve** (extra keys) |
| Read by custom Lua players | easy (instances you can walk) | possible but different format |

The reference project never used `CurveAnimation`: its runtime player and every offline tool read KeyframeSequences, and the curve pipeline was untested. If you have a custom player or bake tools, **do not convert** without updating them. See [[CurveAnimation and Curve Channels]].

### Choose the rotation type before converting
Roblox docs: open the editor settings (gear, top-right) > **Default Rotation Type** > **Euler Angles** or **Quaternions** before you open the Curve Editor. The choice also becomes the default for future projects.
- **Quaternions**: the conversion preserves the motion exactly.
- **Euler angles**: existing quaternions are converted using the **Euler angles order** setting (XYZ, XZY, YXZ, YZX, ZXY, ZYX). The docs warn the result "might appear slightly different between keyframes, especially if any of your Euler angles approach Gimbal lock", and that once converted to Euler tracks it is "impossible to convert them back into quaternions".

When to pick which:
- **Euler** gives editable per-axis graphs, the classic animator's view. Good for joints that rotate mostly about one axis (elbows, knees, a hinge on a prop) and for overshoot shaping.
- **Quaternions** keep the motion identical and avoid gimbal problems on shoulders and hips that rotate on several axes at once. The graph then shows interpolation from 0 to 1 per segment rather than angle values.

Roblox docs on quaternion curves: each segment always runs from 0 to 1 regardless of tangents, and the two keys drawn at the same frame represent the same orientation.

### Tangents and interpolation modes
Roblox docs:
- Right-click a key > **Interpolation Mode**: **Linear** (default), **Constant** (snap), **Cubic** (eases; the only mode with tangents).
- Euler curves have a tangent before and after each key; quaternion curves have one at the start and one at the end of each segment.
- Set tangents are drawn as white circles, unset (automatic) ones as clear circles. Right-click > **Set Tangent To Zero** flattens one.
- To mimic Bounce or Elastic, select two or more keys > **Generate Curve** > Bounce or Elastic and In / Out / InOut. It replaces the intermediate keys with generated ones.

Craft uses of tangents:
- **Overshoot and settle** on one key: pull the outgoing tangent past the next value instead of adding an extra key.
- **Ease out of a hold** without the dead stop that CubicV2 InOut produces: flat incoming tangent, steep outgoing.
- **Spotting flips**: on Euler curves, a channel that jumps by about 360 degrees between keys is a wrap. On quaternion data, a segment that looks fine as numbers can still spin the long way (see "Editor preview vs runtime" below).

## 2. Keyframe optimisation

Roblox docs describe two mechanisms:
- **Automatic**: when creating facial animation and when promoting a clip to a curve animation. Three or more consecutive keys with the same value are reduced to the first and last; a track holding only default values (identity CFrame, or 0 on a curve) is removed entirely.
- **On demand**: **⋯ > Optimize Keyframes**. A slider sets how many keys to keep, removing the least impactful first. You can preview and scrub, but not edit, while the slider is open; click OK to apply.

Why it matters on Roblox specifically: every `Pose` is an instance, and instances cost load time and memory on every client that has the clip. The reference project measured enemy clip folders at **323k instances** when baked "with every joint keyed at 16 to 25 fps", and set a budget of **2,500 instances per ability kit folder**. See [[Performance and Memory]].

Optimisation risks:
- **Contacts get softened.** A foot plant or a hit pose that is held for 2 frames may be judged "low impact" and removed, so the foot slides or the impact loses its moving hold. Re-check contacts after optimising.
- **Large spans can flip.** Removing the middle key of a big turn can leave a key-to-key segment over 120 degrees, which the Animator may interpolate the wrong way round. The reference project rejects any arm segment over 120 degrees and re-inserts a mid key.
- **The editor's error metric is not the Animator's.** The reference project measured that the Animator does not slerp between keys on unevenly spaced clips (it blends rotation vectors), so thinning that "looks" lossless in a slerp model can differ by several degrees on big turns far from rest. See [[How the Animator Really Behaves]].
- **Identity-track removal can delete intent.** A joint you deliberately keyed at rest to override a lower-priority layer becomes "default values only" and is removed, and the lower layer then shows through. Key it 0.1 degree off rest, or set it in code.

Offline tools can do better thinning with explicit tolerances (the reference project used 0.75 degrees and 0.03 studs for body joints, checked at 60 Hz with feet held to 0.05 studs while planted). See [[Authoring Clips in Code]].

## 3. IK inside the editor

Roblox docs (current): the track list has a **Manage IK** button that opens the Manage IK window. The current docs page does not describe its options in detail.

Unverified (older docs and common community descriptions; check your Studio build): the editor's IK has offered a **Body Part** mode (only the dragged limb chain is solved) and a **Full Body** mode (the whole rig follows), the ability to **pin** parts so they stay in place while others are dragged, and a toggle to respect joint constraints. Treat these names as hints of what to look for, not guarantees.

How to use editor IK well, whatever the exact UI:
- **IK is a posing aid, not a runtime system.** What gets saved is still FK rotations per joint per key. The in-betweens are interpolated in joint space by the Animator, so an IK-posed hand that is on a target at two keys will drift off the target between them. For planted feet or a hand on a wall, add more keys (every 2 to 4 frames) through the contact, or solve at runtime with `IKControl` (see [[IKControl Reference]] and [[Foot Placement and Ground IK]]).
- **Watch the elbow and knee direction.** A two-bone solve has two mirror solutions. Interactive IK can choose the flipped one from one key to the next, and the interpolation then swings the elbow through the body. The reference project's offline solver picks one consistent elbow branch over the whole clip (a Viterbi pass) to avoid exactly this; by hand, check the pole every key.
- **R15 elbows are not hinges in data.** A `Motor6D` or `AnimationConstraint` elbow accepts any rotation, so an IK drag can bend it sideways or backwards. Check that the elbow only rotates about its own X axis, within 3 to 146 degrees (the reference project's limit). See [[Elbow Poles Swivel and Joint Limits]].
- **Unpin before the next pose.** A forgotten pin silently holds a hand in place through the next five keys.

## 4. Animation events and named keyframes

### Adding events (Roblox docs)
1. Timeline settings (gear) > **Show Animation Events**. An events bar appears under the playback controls.
2. Move the scrubber to the frame.
3. Click **Edit Animation Events**, then **+ Add Event**, type the event name, optionally a **Parameter**, and **Save**.
4. Copy events with right-click > **Copy Selected** and **Paste Events**; change a copy's parameter with **Edit Animation Event**.

In the data these become `KeyframeMarker` instances (Name = event name, `Value` = parameter) under a `Keyframe` at that time. Scripts listen with `AnimationTrack:GetMarkerReachedSignal(name)`, which passes the parameter string. Details and pitfalls in [[Markers and Events]].

### Named keyframes
Renaming a keyframe (right-click the key in the upper bar > **Rename Key Keyframe**) makes `AnimationTrack.KeyframeReached` fire with that name. The one name the engine itself cares about is `End`, which Roblox docs require on clips replacing default character animations. For everything else prefer markers: they carry a parameter, several can share a time, and they are what `GetMarkerReachedSignal` filters by name.

### Event conventions that scale
From the reference project:
- **`Hit`** drives damage timing. The server applied hits at the clip's marker time **minus 0.06 s**, read from data, so the server never needed the clip.
- **`TrailOn` / `TrailOff`** gate the slash trail to just the cut.
- **Parameterised markers** carry small payloads, for example a staff-spin marker with value `turns,dur,dir,axis,up,down` read on every client.
- **Export marker times to data.** The server should not have to load a clip to know when a blow lands. Keep a table of marker times per clip and regenerate it whenever a clip is retimed.
- **Beware duplicates.** A full-body clip and its upper-body copy both carry the same markers; if both play, every marker fires twice. One project's VFX module skipped upper-body copies for this reason.

## 5. Imports

The **⋯ > Import** submenu brings motion in from outside:
- Roblox docs: **Import > Live Animation Creator** (body capture from video; R15 only). See [[Animation Capture and Mocap]].
- Commonly present in the same menu (verify in your build): import from an FBX animation file and loading a published animation from Roblox. Through the API, `KeyframeSequenceProvider:GetKeyframeSequenceAsync(assetId)` returns the `KeyframeSequence` behind a published animation (Roblox docs; it is a web call, wrap it in `pcall`), which is how you recover an editable source from an asset you own.

Import hygiene (reference project):
- Imported clips land in the save folder (seen under `RBX_ANIMSAVES` with a sub-folder named after the imported model, often "Scene"). Rename and move them to a deliberate source folder at once.
- When several imports exist, two top-level models named "Scene" can coexist. Pick by content, never by `FindFirstChild("Scene")`.
- Imported clips can carry systematic errors. In the reference project, GLB-imported enemy clips played turned 180 degrees because the importer put the root's pose at the keyframe top level (where it is never applied) while the rest of the body kept a 180-degree yaw. See [[Pipeline - Importing Animated Enemies]] and [[Enemy Import Axis Fix]].

## 6. Partial-body clips and layering from the editor

Only joints that have keys (Poses with `Weight > 0`) are affected by a clip. This is how you make layers:
- An **upper-body attack** keys only the waist, spine, head and arms. The legs keep playing the walk from a lower priority. The reference project published separate "Upper" copies of every attack with hips and legs at weight 0, so casting while walking kept the legs walking.
- A **carry pose** keys only the right arm, so it layers over any locomotion.
- **Weight-0 Poses are placeholders.** The engine ignores them (a Roblox staff statement from 2018, and measured in the reference project); they exist only to keep the hierarchy intact for children that are keyed.

Gotchas:
- **The top-level root pose is never applied** (measured). Keys on `HumanoidRootPart` (or the Root bone at the top of a bone rig) do nothing; root lift or travel must go on the first child joint (LowerTorso on R15, or a "Body" bone on a creature).
- **A joint keyed only at rest still overrides lower layers.** If your upper-body clip keys the left arm at rest "because it was there", the walk's arm swing disappears. Delete tracks you do not mean to control.
- `Pose.MaskWeight` exists in the API. Its behaviour was not tested in the reference project; do not rely on it without testing.

## 7. Editor preview vs runtime: where they disagree

The editor preview is close to the engine but not a guarantee. Things measured in the reference project:

| Situation | Editor shows | Runtime does |
|---|---|---|
| Big key-to-key turns far from the rest pose | smooth turn | Animator blends **rotation vectors** (not slerp) on unevenly spaced keys; up to 9 to 12 degrees different on an overhead shoulder, and much more near 180 |
| Exactly 180-degree key-to-key turn | one direction | direction is a coin flip in the Animator itself |
| Clip end | the last pose | the last pose held, then a 0.3 s fade back to whatever is underneath |
| Root translation on a character scaled through body-scale values | your offsets | offsets applied literally; on a model scaled with `Model:ScaleTo`, offsets are multiplied by `Model:GetScale()` |
| A track on a joint the game rig does not have | animates the test rig | ignored (clips bind by name) |
| Speed | 1x | whatever `AdjustSpeed` and the playing script decide |

Defensive practice: keep key-to-key turns under 120 degrees per joint, test clips on the real character with real speed and priority, and if precision matters (weapons, contacts), step the clip in Studio with `Animator:StepAnimations(dt)` and read the joints. See [[Testing Animations in Studio]].

## 8. The Animation Graph Editor (not a clip editor)

Roblox docs: the **Animation Graph Editor** (Avatar tab > Graph Editor) is a node-based tool for blend trees and state machines. It does not author clips; it combines published clips with nodes (Clip, Add with Base/Additive ports, and others), exposes parameters, and publishes an `AnimationGraphDefinition` asset. Scripts load the published graph through an `Animation` like a clip and drive it with `AnimationTrack:SetParameter`. It is a newer feature that the reference project never used; consider it when you would otherwise hand-write blend logic, and test it against your own runtime code before committing. See [[Locomotion Systems]] and [[Custom Locomotion Controller Design]] for the hand-written alternative.

## 9. Frame rate and timeline settings

- The timeline's **Frame Rate** setting (timeline gear menu) changes the snapping grid and frame labels. The engine stores seconds. A clip authored at 60 fps grid plays the same as one at 30 if the key times are the same.
- **Author at 30, check at 60.** Most game animation timing is reasoned in 30 fps frames, but fast weapon motion should be stepped at 60 to catch one-frame pops: the reference project's QA samples at 60 Hz and defines a pop as a one-frame turn of 30 degrees or more at that rate.
- **Timeline Unit** switches between seconds:frames and frames. Use frames while timing combat, seconds when matching gameplay data.

## Common mistakes

- Converting to curves when a downstream tool needs KeyframeSequences.
- Converting with Euler rotation type on a shoulder-heavy clip and getting gimbal wobble that cannot be undone.
- Running Optimize Keyframes and not re-checking contacts and big turns.
- Trusting editor IK for contacts without enough keys through the contact.
- Using named keyframes for gameplay events instead of markers, then renaming a key and silently breaking the code.
- Leaving full-body tracks in an upper-body clip.
- Keying the root pose and wondering why the character does not lift.

## See also
[[Animation Editor Workflow]], [[CurveAnimation and Curve Channels]], [[Markers and Events]], [[Inverse Kinematics]], [[IKControl Reference]], [[How the Animator Really Behaves]], [[Keyframes, Easing and Interpolation]], [[Animation Capture and Mocap]], [[Publishing Animations]], [[Open Questions]].

## Connected notes
<!-- auto-links:start -->
[[Snippets - Building and Sampling Clips]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Animation Glossary]] · [[Animation Data from Blender to Roblox]] · [[AI Animation and Motion from Video]] · [[Rotations Angles and Quaternions]] · [[Animation Start Here]]
<!-- auto-links:end -->
