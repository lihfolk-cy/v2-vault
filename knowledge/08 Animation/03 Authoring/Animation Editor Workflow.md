---
tags: [authoring, animation-editor, studio, workflow]
---
# Animation Editor Workflow

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Keys inserted off by a frame -> insert at the scrubber position you want, check with frame stepping
> - Avoid: Legacy Cubic easing in an old clip -> convert to CubicV2 with the direction flipped
> - Avoid: Only some tracks keyed on a key pose -> key all tracks on key poses during blocking
> - Rig: correct assembly root, only the root anchored, game proportions, weapon on a Motor6D
> - Planned beats with times; gameplay hit time known
> - Blocked in Constant; poses read in silhouette from the game camera
>
> Cost: TL;DR ~170 tok · whole note ~5.0k tok. Read more: ## Preparing the rig · ## A blocking-to-polish workflow · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The built-in Animation Editor is the default way to hand-key clips in Roblox Studio. It is good enough for most character work, it writes exactly the data the engine plays (`KeyframeSequence`, or `CurveAnimation` if you use the curve editor), and it is the tool every other pipeline eventually has to agree with. This note is the day-to-day workflow: setting up a rig, blocking, splining, saving, looping and exporting, plus the traps that cost real projects time. Advanced features (curve editor, IK, events, keyframe optimisation, capture) are in [[Animation Editor Advanced]].

Facts marked "Roblox docs" were checked against the official Animation Editor page (last updated October 2026). Facts marked "measured" come from one live action game (the reference project). Everything else is labelled as a rule of thumb.

## Opening the editor

- Roblox docs: the editor is reached from Studio's **Avatar** tab, or **Window > Avatar**. In current Studio builds the Avatar-tab button may be labelled **Clip Editor** (the official capture guide says "click Clip Editor. The Animation Editor window displays"). It is the same tool.
- The Avatar tab also holds the **Character** button (the Rig Generator, for inserting test rigs) and, in recent builds, the **Graph Editor** (the node-based Animation Graph Editor for blend trees, not a clip editor; see [[Animation Editor Advanced]]).
- Select a rig in the viewport or Explorer. The editor asks for an animation name and creates a new clip, or lets you load one of the rig's saved clips.

## Preparing the rig

The editor only animates **rigs**: models whose parts are connected by `Motor6D` joints (or `Bone`s on skinned meshes). Getting this right first saves hours.

| Check | Why | What goes wrong otherwise |
|---|---|---|
| The rig is in Workspace | the editor poses live instances | nothing selects |
| The root part (HumanoidRootPart, or your custom root) is the **assembly root** | Roblox docs: for a custom Motor6D rig, `BasePart.AssemblyRootPart` must be the part you want to stay still; `Model.PrimaryPart` does **not** set it | the "wrong" part stays put and the root swings around a limb |
| Only the root is anchored, everything else unanchored and jointed | anchored limbs cannot be driven by joints | a limb refuses to move, or the whole rig moves as one |
| Joint names match the game's rig | clips bind by the Pose names (Part1 names) under the hierarchy | a clip made on a renamed dummy plays nothing on the real character |
| The test rig has the same proportions and scale as the game character | translation keys are stored in studs | crouches leave feet hovering or sunk on the real character (see [[Scale and Animation]]) |
| Held weapons are attached by a `Motor6D`, not a `Weld` | a weld cannot be keyed | the blade cannot rotate in the hand; you end up faking it with the wrist |

Rig sources:
- **Rig Generator** (Avatar > Character): R15 and R6 block rigs, plus your own avatar. Fine for prototypes.
- **Your game's real character**, cloned into Workspace while not playing. Best for anything that has to line up with gameplay (weapon reach, camera, hit boxes).
- **Imported rigs** from Blender (see [[Importing Models and Rigs]] and [[Custom Characters and StarterCharacter]]).

A trap measured in the reference project: `Players:CreateHumanoidModelFromDescriptionAsync` in Edit mode returned a rig **without Motor6Ds**, and `Humanoid:BuildRigFromAttachments` failed quietly. Build test dummies from the R15 `*RigAttachment` pairs, or clone a known good rig. Also, live characters in that project used `AnimationConstraint` joints rather than Motor6D (see [[AnimationConstraint and Physically Simulated Characters]]); the editor still works on a Motor6D dummy of the same proportions, and the clip plays on both because clips bind by part names.

## The interface in one minute

Roblox docs describe three regions:

1. **Media / playback controls**: the clip name, the play/loop buttons, the **⋯** menu (Save, Save As, Import, Export / Publish to Roblox, Set Animation Priority, Optimize Keyframes), and the position indicator in **seconds:frames**.
2. **Track list**: one track per animated part or bone. The top row has the rig name, a **Manage IK** button, a menu to add tracks, and a menu with Add Keyframe / Delete Track. Clicking or right-clicking the **upper region** applies an operation to all tracks.
3. **Timeline**: the scrubber, time or frame units, a settings menu (Timeline Unit, Frame Rate, show/hide Animation Events), and draggers to zoom the time axis.

Default timing (Roblox docs): clips run at **30 frames per second** in the editor's display, so `0:15` means half a second, and the timeline shows 1 second until you type a longer length into the right-hand box of the position indicator. The frame rate setting changes the grid you snap to, not how the engine plays the clip: keyframe times are stored as seconds (`Keyframe.Time`) and the Animator interpolates between them at whatever frame rate the client runs. See [[Timing Spacing and Frame Charts]].

## Posing

Roblox docs: select a part or bone, move the scrubber, then move or rotate. A track and a keyframe appear automatically. Press **R** to toggle Move and Rotate; both obey the toolbar's snap settings and increments.

Practical habits:
- **Turn rotation snapping off** (or set it to 1 to 5 degrees) for organic posing. Fifteen-degree snaps produce poses that look mechanical and make every joint land on the same angles.
- **Turn move snapping off** for root translation, or use a small increment (0.05 to 0.1 studs). Coarse snapping is how crouches end up 0.5 studs too deep.
- **Rotate, do not translate, limbs.** An R15 arm joint keyed with translation reads as a detached shoulder. The reference project's QA flags any arm translation over 0.05 studs (see [[Animation Quality Standard]]).
- **Pose from the root out.** Hips first (they carry the weight), then the spine, head, arms, hands, weapon. Posing hands first and fixing the body later almost always produces arms that fight the torso.
- **Pose in the game camera's view**, not only from the side. Most players see your character from behind and slightly above, at 10 to 20 studs. See [[Posing and Silhouettes]].

## Keyframe operations (Roblox docs)

| Operation | How |
|---|---|
| Insert | Right-click > **Add Keyframe Here**. It lands at the time nearest the click, **not** at the scrubber. |
| Move | Select one or more keyframes and drag. |
| Duplicate | Select, Ctrl+C / Cmd+C, move the scrubber, Ctrl+V / Cmd+V. |
| Delete | Select, then Delete or Backspace. |
| Operate on every track | Use the upper region of the track list. |

The insert gotcha matters more than it looks: if you right-click slightly off the scrubber you get a key one frame early, and a one-frame-early key on a contact pose is exactly the kind of error that makes a foot pop.

## Easing

Each key carries an easing style and direction. Roblox docs list the editor's styles as **Linear** (the default), **Constant**, **CubicV2**, **Elastic** and **Bounce**, and directions **In**, **Out**, **InOut**.

What you need to know beyond the docs:

- **The easing belongs to the segment leaving the key.** The Pose property docs say EasingStyle is "the easing style to use to reach the next Pose's value". So the easing you set on key A shapes the motion from A to B. If you want the strike to slow into the contact pose, put `Out` on the key *before* contact. See [[Keyframes, Easing and Interpolation]].
- **CubicV2 follows TweenService directions** (In = slow start, Out = slow end). Measured in the reference project.
- **Legacy `Cubic` runs backwards** ("In" eases out). It is deprecated in the API (`PoseEasingStyle.Cubic` is marked "Deprecated - Use CubicV2"), but old clips and old plugins still write it. Never use it in new work, and treat any old clip with Cubic keys as suspect.
- **Constant**: measured in the reference project, In jumps to the next value at once, Out holds the old value until the next key, InOut jumps at the midpoint. The docs are not consistent on this; see [[Open Questions]].
- **Elastic and Bounce**: avoid for character joints. They overshoot in joint space, which looks like a rubber limb, and their direction semantics are disputed (one measurement found them reversed, a later one found them correct). Use them for props or UI-like motion, if at all.

A useful mental model: Linear segments give constant speed and a visible corner at every key; CubicV2 InOut everywhere gives a stop at every key (robotic). Real motion mixes them: In on wind-ups, Out on strikes and landings, InOut on settles, Linear inside long fast arcs. The reference project's QA flags Linear arm segments longer than 0.12 s that turn more than 20 degrees, because they read as constant-speed robot motion.

## A blocking-to-polish workflow

This is the classic pose-to-pose process adapted to the editor's tools. Timings are typical for a single player attack clip.

### 1. Plan (5 to 15 minutes)
- Write the beats with times: wind-up starts, contact (Hit), recovery ends, cancel window opens. If gameplay already fixed the hit time (for example a light attack that must hit at 0.20 s), start from that number.
- Shoot or find reference. Count frames in it (see [[Animation Capture and Mocap]] for using video).
- Thumbnail the 3 to 5 key poses: anticipation, contact, follow-through, recovery.

### 2. Block with Constant easing
- Key **every body part on every key pose** (use the upper track-list region to key all tracks). Partial keys at this stage cause the in-between to drift in ways you cannot see while stepped.
- Set all keys to **Constant** so the clip pops pose to pose. Judge poses and timing only: does each pose read in silhouette, is the hit on the right frame, is the recovery long enough?
- Fix timing by dragging whole columns of keys, not individual tracks.

### 3. Breakdowns
- Add the in-between poses that define the arc: the passing position of the weapon, the moment the hips reach their furthest turn, the overshoot after contact.
- Still mostly Constant, or switch to Linear to see the arcs.

### 4. Spline
- Switch segments to their real easing (CubicV2 In / Out / InOut, Linear where needed).
- Offset timing between body parts for overlap: hips lead, the chest follows about one frame later at 30 fps, then the shoulder, elbow, wrist and weapon. The reference project's standard is 2 to 4 frames from hips to hand (see [[Principles of Animation for Games]]).
- Look for floaty in-betweens (two keys too far apart with InOut) and corners (Linear into a hard stop).

### 5. Polish
- Fix arcs: step through and watch the hand and weapon tip trace a curve, not a zig-zag.
- Add secondary motion: head settle, off-hand reaction, slight overshoot. See [[Idle Breathing and Secondary Motion]].
- Check the first and last frames against the idle the clip will blend into (see "Entry and exit" below).
- Add markers for gameplay moments ([[Markers and Events]]).

### 6. Review
Run through [[Animation Review Checklist]] before you publish.

## Looping

Roblox docs: the **Looping** button marks the clip as a loop, but "a looping animation doesn't interpolate between the final keyframes and first keyframes". So:

- Duplicate the first keyframe column to the last frame. The last key **is** the first pose, and the loop seam is then invisible.
- Put the easing you want across the seam on the second-to-last key. A Linear key there with an InOut first key produces a tiny hitch at the seam.
- Check speed continuity: if the hips are moving fast at the end and slow at the start, the seam pops even though the poses match.
- Cycle length matters for locomotion: the reference project tuned walk and run cycles so that each foot's ground contact moves back at exactly the clip's ground speed (11 studs/s walk, 22 jog, 64 run on a 1.6x character). See [[Locomotion Systems]].

## Priority

Roblox docs: **⋯ > Set Animation Priority**. The seven levels, highest first, are Action4, Action3, Action2, Action, Movement, Idle and Core. The priority saved in the clip is only a default: code can override it with `AnimationTrack.Priority`. Pick the saved value to match how the clip will normally be used, so a clip played by a careless script still layers sensibly:

| Clip type | Typical priority |
|---|---|
| Idle, breathing loops | Idle |
| Walk / run / jump | Movement |
| Weapon carry poses (one arm) | Action |
| Attacks, abilities | Action2 to Action4 (the reference project played kit moves at Action4) |
| Emotes | Action |

Full rules for how priorities and weights mix are in [[Playback, Priorities and Blending]].

## Saving: where the data actually goes

Roblox docs: **⋯ > Save / Save As** stores the clip as a `KeyframeSequence` in **ServerStorage** and adds a reference to the rig. The docs describe the reference as an `ObjectValue` in the rig's **AnimSaves** folder, and give this pattern for the rare case a game reads the local data:

```lua
-- Roblox docs pattern: follow the rig's AnimSaves reference, never hard-code the ServerStorage path
local rig = workspace.Rig
local animSaves = rig:FindFirstChild("AnimSaves")
```

In practice Studio keeps the saved sequences in a ServerStorage folder historically named **RBX_ANIMSAVES**, with a sub-folder per rig. The reference project found sequences in `RBX_ANIMSAVES` and also in an imported model's own "AnimSaves" folder. Whatever the exact layout in your Studio version, three facts hold:

1. **Saved is not published.** A saved clip has no asset id. Live servers cannot play it through the Animator. See [[Publishing Animations]].
2. **ServerStorage does not replicate.** Roblox docs warn that clients cannot see this data; move the `KeyframeSequence` (or `CurveAnimation`) to ReplicatedStorage if clients must read it (for example a custom Lua player, see [[Lua Keyframe Player]]).
3. **It grows without limit.** Every Save As, every capture import and every imported model's clips land there. Each `Pose` is an instance.

### Case study: the 642,000-instance save folder
In the reference project, `RBX_ANIMSAVES` reached **642k instances**, alongside other backup folders of 512k, about 385k and 112k. Place size and Studio responsiveness suffered, and every copy that had been moved into ReplicatedStorage was downloaded by every client. Archiving the save folders and imports to disk took the place from about **2.36 million to 955k** instances. Rules that came out of it:
- Treat RBX_ANIMSAVES as a scratch area. Move finished sources into a deliberate, named folder.
- Export sources you want to keep to `.rbxm` files on disk (right-click > Save to File) or a separate archive place, then delete them from the game place.
- Never copy whole save folders into ReplicatedStorage "just in case".
See [[Baked Clip Stubs and Archiving]] and [[Performance and Memory]].

## Exporting (publishing)

Roblox docs, condensed:
1. If the clip will replace a **default character animation** (run, jump and so on), right-click the final keyframe in the upper bar, choose **Rename Key Keyframe**, and name it `End` (case-sensitive).
2. **⋯ > Publish to Roblox**.
3. In **Asset Configuration**, give a title and optional description.
4. For a **group-owned** game, choose the group in the **Creator** field.
5. **Submit**, then copy the asset id from the Toolbox.

Publishing under the wrong creator is the classic cause of "the animation plays in Studio but not in game". Details, permissions and bulk options are in [[Publishing Animations]] and [[Animation Asset Permissions and Groups]].

## Entry and exit: the part people forget

A clip is never seen alone. It blends in from whatever was playing and hands back to whatever plays next (usually the idle).

- **Fades are short in combat.** The reference project faded kit moves in over 0.05 s. A first frame far from the idle pose then reads as a snap. Its QA requires the first frame to be within **90 degrees** per arm joint of the idle and the last frame within **75 degrees**.
- **A one-shot that ends holds its last pose and fades out over 0.3 s** (measured), and the next layer takes over. If your last pose is a dramatic follow-through, the character slides from it to idle in a third of a second, which looks like a puppet being dropped. End on a recovery pose close to the idle.
- **The last key should usually be the rest or ready pose** the game idles in. In the reference project, re-keying clip end frames alone fixed blade-through-body problems in 22 of 22 moves, because a "ready" end pose put the long pommel into the hip.

## Weapons and props in the editor

- Attach the weapon with a `Motor6D` from the hand (Part0 = RightHand, Part1 = the weapon's handle). The reference project used a Motor6D named for the job, with `C0` from the hand's `RightGripAttachment` and `C1` from the tool's grip, and destroyed the default `RightGrip` weld.
- Key the weapon joint only when the weapon must move *in the hand* (spins, regrips, tosses). For a normal sword, aim the blade with the arm, not the weapon joint: a gameplay script cannot know about a hand-relative twist that exists only in one clip.
- A wrist cannot aim a blade by itself. Lining a blade up with the forearm needs about 90 degrees of wrist deviation, far past the human 30. The arm must aim; the wrist only refines. See [[Weapon Swing Design]].
- Long weapons collide with the body. Step the clip at 60 Hz and watch the pommel and blade against the torso and legs.

## Common mistakes

| Mistake | How it looks | Fix |
|---|---|---|
| Keys inserted off by a frame | a pop or a foot slip on one frame | insert at the scrubber position you want, check with frame stepping |
| Legacy Cubic easing in an old clip | eases backwards: slow where you wanted fast | convert to CubicV2 with the direction flipped |
| Only some tracks keyed on a key pose | parts drift between poses in ways that change when you edit a neighbour | key all tracks on key poses during blocking |
| Rotation snapping at 15 or 45 degrees | stiff, symmetrical poses | snapping off or 1 to 5 degrees |
| Arms keyed with translation | shoulders look dislocated | rotation only on limbs |
| Saved but never published | works in Studio, nothing in live servers | publish; see [[Publishing Animations]] |
| Looping clip without a duplicated first key | a hitch at the loop point | copy the first column to the end |
| Ending on a dramatic pose | a 0.3 s slide to idle | end near the idle pose |
| Test rig different from the game character | feet float or sink, reach wrong | animate on a clone of the real character |
| Exactly 180-degree key-to-key turns | the joint spins the wrong way at random | split into two keys under 120 degrees each |

## Checklist

- [ ] Rig: correct assembly root, only the root anchored, game proportions, weapon on a Motor6D
- [ ] Planned beats with times; gameplay hit time known
- [ ] Blocked in Constant; poses read in silhouette from the game camera
- [ ] Splined with CubicV2 / Linear; no legacy Cubic
- [ ] Overlap: hips lead, hand 2 to 4 frames later
- [ ] Arcs checked frame by frame
- [ ] First frame near the idle (90 degrees), last frame near the idle (75 degrees)
- [ ] Markers for hit, trails, footsteps
- [ ] Priority set; looping set and seam checked if a loop
- [ ] Saved source archived; published under the game's owner; id stored as data

## See also
[[Animation Editor Advanced]], [[Keyframes, Easing and Interpolation]], [[Markers and Events]], [[Publishing Animations]], [[Moon Animator and Third-Party Tools]], [[Principles of Animation for Games]], [[Animation Review Checklist]], [[How the Animator Really Behaves]], [[Rigging in Blender]], [[Authoring Clips in Code]].

## Connected notes
<!-- auto-links:start -->
[[Engine Gotchas]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Animation Glossary]] · [[Weapon Rig Player]] · [[AI Animation and Motion from Video]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Animation Start Here]]
<!-- auto-links:end -->
