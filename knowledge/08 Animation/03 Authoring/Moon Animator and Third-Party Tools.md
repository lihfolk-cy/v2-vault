---
tags: [authoring, plugins, moon-animator, blender, tools]
---
# Moon Animator and Third-Party Tools

The built-in editor is not the only way to make Roblox animation. Many studios use a paid Studio plugin (Moon Animator 2 is the best known), Blender with a bridge add-on, or their own code. This note describes what each route is good for, what it hands to the engine, and where the hand-off goes wrong.

**Honesty note.** Third-party tools change without notice and most of them do not have official documentation. Everything below is labelled:
- **Verified**: from the tool's own repository or listing, or from Roblox docs.
- **Community**: from community tutorials (for example a 2020 DevForum "Getting Started with Moon Animator 2 (unofficial)" guide). Probably still right, but check your version.
- **Unverified**: widely repeated, not confirmed. Do not build a pipeline on it without testing.

## The one thing every tool must produce

Whatever the tool, the Roblox **Animator** only plays an `Animation` whose `AnimationId` points at a published animation asset (or, in Studio only, a temporary id from `KeyframeSequenceProvider`). The asset is made from a `KeyframeSequence` or a `CurveAnimation`. So every tool's real output is one of:

1. A `KeyframeSequence` / `CurveAnimation` in your place, which you then publish ([[Publishing Animations]]).
2. Scripted motion that never becomes an asset: CFrame tweens, camera paths, property animation played back by the tool's own runtime or by your code.

Route 2 is fine for cutscenes and props, but it does not replicate like an Animator track, does not blend with priorities, and cannot be loaded by `Animator:LoadAnimation`. Know which route a feature uses before you depend on it. See [[Replication and Ownership]] and [[Tween and CFrame Animation of Objects]].

## Moon Animator 2

### What it is
- **Verified (listing / community):** a paid Studio plugin by the creator known as xSIXx, sold on the Creator Store. It replaced an older "Moon Animator 1", which is no longer sold (community, 2020).
- **Caution:** "free Moon Animator" files circulate (for example modified builds on GitHub that must be installed as local plugins and patched to match Studio's version). A plugin runs with broad access to your place and, if you allow it, HTTP. Installing an unofficial modified build is a security risk to your game and your account, and it deprives the author of payment. Buy it from the official listing or do not use it.

### Components (community)
The 2020 community guide lists four launchers:

| Component | Purpose (community description) |
|---|---|
| **Moon Animator** | the timeline: tracks for rigs, parts, the camera, and object properties |
| **File Explorer** | manages Moon's own project files (`.xsixx`) and folders |
| **Character Inserter** | inserts test characters (the guide recommended R6 for the beginners' workflow) |
| **Easy Weld** | cleans up models, welds them, and creates joints so a model can be animated; used for attaching tools to hands ("select the hand, then the handle, then join") |

### Timeline features (community)
Add Item (tracks for any number of items), Animation Settings (length, looping), Edit Item, toggling tracks, grouping keyframes, **Mirror** (left/right swap, useful for walks), **Looper**, **Time Stretch**, **Wiggler** (wave-based vibration between two keys), easing per keyframe, and **markers** (a marker track enabled from Edit Item). Keys for rig joints can be set automatically when you rotate a part; camera and raw CFrame tracks need manual keys.

### What it is good at
- **Cinematics**: camera tracks with field of view, subtitles (community), several characters and props on one timeline. Moon is the common choice for trailers, intros and cutscene-style content.
- **Multi-character choreography**: two characters fighting, a character handing an object to another.
- **Animator comfort**: per-limb local rotation (users explicitly compare the default editor unfavourably on this, in a December 2025 DevForum feature request thread), richer key tools, mirroring.

### What to watch
- **Not everything becomes an Animator clip.** Community users repeatedly note that **CFrame and camera animation cannot be exported** as an animation asset; they need scripting to play in game. Rig animation (Motor6D joint motion) can be turned into a KeyframeSequence and published. Plan which parts of a cutscene are clips and which are scripted.
- **Project files vs game data.** Moon's own save files are not what the game plays. Keep the exported KeyframeSequences (and the published ids) as the source of truth for gameplay, and archive the `.xsixx` files for future edits.
- **Easing translation.** Moon offers more easing curves than the `PoseEasingStyle` enum has. When a rig track becomes a KeyframeSequence, curves the enum cannot represent must be approximated, usually by baking extra keys. Expect bigger clips and check that holds still hold. (Unverified in detail; inspect an exported clip's poses to see how your version does it.)
- **Rig mismatch.** Moon's Character Inserter rigs may not match your game's character (scale, R6 vs R15, joint names, `AnimationConstraint` vs `Motor6D`). Clips bind by joint name; translation keys are in studs. Animate on a clone of your real character.
- **Exported clip size.** Exported clips can be dense. Every Pose is an instance; thin before shipping ([[Performance and Memory]]).

### When to choose it

| Choose Moon Animator 2 when | Prefer something else when |
|---|---|
| you make cutscenes and trailers with cameras and many props | you need hundreds of consistent gameplay clips (use code, see [[Spec-Driven Move Authoring]]) |
| an animator on the team already knows it | your pipeline needs exact control of the saved easing and key placement |
| you want mirroring and time-stretch tools inside Studio | you need full IK rigs with controls, constraints and NLA layers (use Blender) |

## Blender (with or without a bridge)

Blender is the strongest free animation tool available and the right choice for creatures, complex body mechanics, facial work and anything with many bones. The full Blender side (rig conventions, roll, weights, export) is covered by [[Rigging in Blender]], [[Blender Armature and Bone Roll Conventions]], [[Exporting FBX vs GLB]] and [[Animation Data from Blender to Roblox]]. Here is only the tool choice.

### Route A: file export
Export FBX or glTF with animation, then import through Studio's 3D Importer. The importer creates the rig and `KeyframeSequence`s in the save folder. Pros: no plugins. Cons: every iteration is an export / import cycle, and importer quirks apply. The reference project found that GLB imports rotated models 180 degrees about Y and wrote clips whose root pose sat at the keyframe top level (never applied), so whole enemies played turned around until a data fix was applied. See [[Pipeline - Importing Animated Enemies]].

### Route B: a live bridge
- **Verified (its GitHub README):** the open-source **"RBXMonkey" / Blender Animations Plugin** has a Blender add-on (a sidebar tab that starts a local server, port 31337 by default) and a Studio plugin with a "Blender Sync" tab. You pick the armature, then "Import from Blender" brings the animation into Studio; animation can be sent back. Listed features: live sync, bone sync (Blender bones to Motor6Ds), bone toggles, animation scaling, camera attach, and easing transfer "losslessly between Roblox and Blender where possible". GPL-3.0 licensed.
- The reference project's standard documents cite this project's measurements of Constant easing behaviour, which is a good sign that its authors test against the engine.
- Bridges still must respect Roblox's limits: the root pose is not applied, legacy Cubic runs backwards, and the Animator's in-between interpolation is not Blender's. Check the result in Studio, not only in Blender.

### Blender gotchas specific to Roblox
- **Blender interpolates in its own way** (Bezier F-curves on Euler or quaternion channels). The Animator interpolates per joint between keys with only the enum easings. Bake to keys dense enough that Roblox's interpolation cannot wander: every 2 to 3 frames through fast motion, sparser in holds, then thin with a tolerance.
- **Scale.** Blender units should equal studs at the final character height. Translation keys are absolute studs; see [[Scale and Animation]].
- **Root motion.** Put root travel on the first child bone or joint (LowerTorso, or a "Body" bone), not the top-level root.
- **Constraints and drivers do not export.** Bake them to keys before export.

## Writing your own tools (code)

For large libraries of gameplay clips, code beats hand-keying on consistency: one pose library, one easing convention, one QA standard for every clip. The reference project built several hundred attack clips this way, with an IK baker and an automatic quality scorer. See [[Authoring Clips in Code]], [[Spec-Driven Move Authoring]], [[Pipeline - Arm IK Baking and QA]] and [[Studio Tooling Architecture]].

Code is also the only practical way to:
- re-target or re-time a whole library when the character changes;
- enforce budgets (keys per second, instances per folder);
- prove clips against the real Animator (`Animator:StepAnimations`) rather than eyeballing them.

## Other utilities worth knowing

| Tool type | Use | Notes |
|---|---|---|
| Studio's **Rig Generator** (Avatar > Character) | quick R6 / R15 test rigs | built-in |
| **Rig editing plugins** (for example RigEdit, recommended alongside Easy Weld in the community guide) | create and fix joints on custom models | many versions exist; check the publisher |
| Studio's **3D Importer** | bring rigs and clips from FBX / glTF | built-in; see [[3D Importer Settings Reference]] |
| **Animation Capture** (body from video, face from webcam) | fast reference-quality motion | built-in beta features; see [[Animation Capture and Mocap]] |
| **Animation Graph Editor** | blend trees and state machines from published clips | built-in, newer; see [[Animation Editor Advanced]] |

## Vetting any animation plugin

Plugins run inside Studio with access to the whole data model. Before installing one:
- [ ] It comes from the official Creator Store listing of a known publisher, not a re-upload or a file from a link.
- [ ] Its permissions requests make sense (an animation plugin rarely needs script injection or HTTP to unknown hosts).
- [ ] You tested its output clip in a **live** server, not only in Studio.
- [ ] You know where it stores its project data, and that data is backed up outside the place.
- [ ] It writes `CubicV2`, not legacy `Cubic`, or you know to convert.
- [ ] Its exported clips stay within your instance budget.

## Interop pitfalls between tools

| Pitfall | Symptom | Fix |
|---|---|---|
| A tool writes legacy `Cubic` with TweenService meanings | eases backwards | rewrite to CubicV2 (keep the intended direction) |
| Frame rate assumptions (24 vs 30 vs 60) | everything slightly slow or fast | Roblox stores seconds; check key times after import |
| Curves the enum cannot represent | baked-in extra keys, bloated clips | thin with a tolerance |
| Different rest pose between tools | constant offset on a limb | match the rest pose; keys are relative to the joint's rest |
| Bones vs Motor6D | clip plays on one rig type and not the other | clips match by names; skinned rigs need Bones of the same names |
| Root pose keyed on the top-level root | no lift or travel | move it to the first child |
| Exactly 180-degree turns in source data | random wrong-way spins | split big turns into keys under 120 degrees apart |

## See also
[[Animation Editor Workflow]], [[Animation Editor Advanced]], [[Rigging in Blender]], [[Retargeting Animations Between Rigs]], [[Animation Data from Blender to Roblox]], [[Cameras and Cutscenes]], [[Publishing Animations]], [[Authoring Clips in Code]].

## Connected notes
<!-- auto-links:start -->
[[Animation Start Here]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Engine Gotchas]] · [[Keyframes, Easing and Interpolation]] · [[AI Animation and Motion from Video]] · [[Links - Animation creation]]
<!-- auto-links:end -->
