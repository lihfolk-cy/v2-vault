---
tags: [reference, glossary]
---
# Animation Glossary

| Term | Meaning | Read more |
|---|---|---|
| **A/B (Animator vs model)** | Playing the same clip through the real Animator and an offline or Lua model and diffing joint rotations | [[Testing Animations in Studio]] |
| **Action, Action2-4** | The four highest animation priorities; abilities typically at Action4 | [[Playback, Priorities and Blending]] |
| **Anchor (ultimate)** | Where the enemy's body centre must be at an ultimate's climax; enemies are pulled there before damage | [[Cinematic Ultimates]] |
| **Animate script** | The default LocalScript that plays idle, walk, run, jump and so on for player characters | [[The Default Animate Script]] |
| **AnimationClipProvider** | The documented replacement for KeyframeSequenceProvider | [[Animator Deep Dive]] |
| **AnimationConstraint** | The joint type for R15 characters under the Avatar Joint Upgrade; animated through its `Transform` like a Motor6D | [[AnimationConstraint and Physically Simulated Characters]] |
| **AnimationController** | The Animator host for rigs without a Humanoid (weapons, props, creatures) | [[Animation Objects]] |
| **AnimationTrack** | One loaded clip on one Animator | [[AnimationTrack Reference]] |
| **Animator** | Plays tracks on a rig, mixes them and writes joint transforms | [[Animator Deep Dive]] |
| **Anticipation** | The wind-up before an action; sells weight and telegraphs attacks | [[Principles of Animation for Games]] |
| **Avatar Joint Upgrade (AJU)** | Roblox's move of character joints from Motor6D to AnimationConstraint | [[AnimationConstraint and Physically Simulated Characters]] |
| **Bake** | Sample motion (IK, physics, procedural) into keys, usually then thinned | [[Authoring Clips in Code]] |
| **Bone** | A joint inside a skinned mesh, animated through `Bone.Transform` | [[Bones and Skinned Meshes]] |
| **Bone roll** | Rotation of a Blender bone about its own axis; decides which way "pitch" bends a limb | [[Blender Armature and Bone Roll Conventions]] |
| **C0 / C1** | A Motor6D's rest offsets in Part0 and Part1 space | [[Motor6D Math and CFrame Composition]] |
| **Cage** | The inner and outer meshes that let layered clothing wrap any body | [[Layered Clothing Cages and Animation]] |
| **Carry layer** | An arm-only clip over locomotion that holds a weapon | [[Locomotion Systems]] |
| **CCD / FABRIK** | Iterative IK solvers for chains longer than two bones | [[Multi-Bone IK - FABRIK and CCD]] |
| **Chicken wing** | Elbow raised above the shoulder while the hand hangs low; reads as broken | [[Elbow Poles Swivel and Joint Limits]] |
| **Critical (QA)** | A failure severe enough to block installing a clip | [[Arm QA Metrics Reference]] |
| **CubicV2** | The correct smooth easing; legacy `Cubic` plays reversed | [[Keyframes, Easing and Interpolation]] |
| **CurveAnimation** | The curve-based clip format (per-channel curves) | [[CurveAnimation and Curve Channels]] |
| **Design rig** | A weapon model rebuilt as Handle root + one Motor6D per hinge + AnimationController | [[Weapon Design Rig Builder]] |
| **Dynamic head** | A skinned head driven by FACS controls through FaceControls | [[Facial Animation and Dynamic Heads]] |
| **FACS** | Facial Action Coding System: the standard set of face poses dynamic heads use | [[Facial Animation and Dynamic Heads]] |
| **FK / IK** | Forward kinematics (angles to positions) / inverse kinematics (target to angles) | [[Inverse Kinematics]] |
| **Flip** | A joint rotating the wrong way between keys because the turn is too big (or exactly 180 degrees) | [[How the Animator Really Behaves]] |
| **Frame order** | The order RunService events, the Animator and physics run in each frame | [[Frame Order and RunService Timing]] |
| **GroundSpeed** | The speed at which a gait clip's planted foot moves; playback rate = speed / GroundSpeed | [[Procedural Gait and Footstep Planning]] |
| **Ground fit** | Offsetting clips so the lowest point touches the floor | [[Ground Fitting Pipeline]] |
| **Hit-stop** | A brief slow or freeze of attacker and target on impact | [[Hit Reactions Stagger and Hit-Stop]] |
| **Quickdraw / stance move** | Hold a stance to charge, release into a fast strike | [[Stance and Charge Moves]] |
| **IKControl** | Roblox's built-in runtime IK component | [[IKControl Reference]] |
| **Join late** | A client starting a clip part-way so it matches the server's start time | [[Enemy Animation State Protocol]] |
| **Kinetic chain** | Hips, chest, shoulder, elbow, wrist, weapon, each about one frame later | [[Animation Quality Standard]] |
| **KeyframeMarker** | A named event inside a clip, fired by `GetMarkerReachedSignal` | [[Markers and Events]] |
| **KeyframeSequence (KS)** | The classic clip data: Keyframes containing Poses | [[KeyframeSequence Keyframe and Pose Reference]] |
| **KSP** | KeyframeSequenceProvider; `RegisterKeyframeSequence` ids work only in Studio | [[Case Study - Abilities That Only Worked in Studio]] |
| **LOD** | Updating distant or off-screen rigs less often | [[Animation LOD]] |
| **Lua keyframe player** | Lua code that plays KS data by writing joint transforms, so clips need no publishing | [[Lua Keyframe Player]] |
| **Motor6D** | A joint between two parts: `Part1 = Part0 * C0 * Transform * C1:Inverse()` | [[Motor6D Math and CFrame Composition]] |
| **nlerp** | Normalised linear quaternion blend; the Animator uses it only for evenly spaced all-Linear clips | [[How the Animator Really Behaves]] |
| **Placeholder pose** | A Pose with Weight 0 that only holds the hierarchy | [[KeyframeSequence Keyframe and Pose Reference]] |
| **Pole** | The direction an elbow or knee points in an IK solve | [[Elbow Poles Swivel and Joint Limits]] |
| **Pop** | A joint turning far in a single frame; reads as a glitch | [[Arm QA Metrics Reference]] |
| **Priority** | Core < Idle < Movement < Action < Action2 < Action3 < Action4 (Core has value 1000 but ranks lowest) | [[Playback, Priorities and Blending]] |
| **Rest flash** | Arms snapping through rest mid-move | [[Arm QA Metrics Reference]] |
| **Retargeting** | Making a clip from one rig play correctly on another | [[Retargeting Animations Between Rigs]] |
| **Root pose** | The top-level Pose of a keyframe; never applied, so key lifts on its first child | [[How the Animator Really Behaves]] |
| **Rotation vector** | Axis × angle; the Animator blends these for most clips | [[Keyframes, Easing and Interpolation]] |
| **Smallest-three** | Quaternion packing that stores three components plus the index of the dropped one | [[Clip Buffer Format]] |
| **Spec (move spec)** | A move described as key poses of what matters (hand, blade, root), baked by IK | [[Spec-Driven Move Authoring]] |
| **Spring (critically damped)** | A smoothing model that settles fastest without overshoot | [[Springs Damping and Smoothing]] |
| **Stub** | A KeyframeSequence with its Poses removed and motion stored in a binary attribute | [[Baked Clip Stubs and Archiving]] |
| **Swivel** | Rotation of the elbow around the shoulder-wrist line | [[Elbow Poles Swivel and Joint Limits]] |
| **Telegraph (Tele)** | A readable wind-up warning before an enemy attack | [[Animating Creatures and Monsters]] |
| **Thinning** | Removing keys that interpolation already reproduces within a tolerance | [[Authoring Clips in Code]] |
| **Trauma (shake)** | Camera-shake amount that decays; shake strength = trauma² | [[Camera Shake and Camera FX]] |
| **Upper-body copy** | The same clip with hips and legs at weight 0, so the legs keep walking | [[Playback, Priorities and Blending]] |
| **Viterbi** | Dynamic programming that picks the smoothest sequence of per-frame IK solutions | [[Arm Baker Internals]] |
| **Weight** | How strongly a track contributes within and below its priority | [[Playback, Priorities and Blending]] |

See [[Animation Start Here]].

## Nuances and edge cases

A glossary flattens terms into one line each. These are the places where that flattening misleads, and where two terms that sound alike behave differently.

1. **Priority vs Weight.** Priority decides who gets weight first; weight decides how much a track takes within what is left. A weight 1 track at Action fully hides a weight 1 track at Movement on every joint the Action clip keys, and hides nothing on joints it does not key. "Turn the weight down" does not make a high-priority clip blend with a lower one unless total weight at the top is under 1.
2. **Weight vs WeightCurrent vs WeightTarget.** Roblox docs (as of October 2026) list `WeightCurrent` and `WeightTarget` on `AnimationTrack` as not replicated, and `WeightTarget` as read only. Weight you set is a target reached over the fade time; reading `WeightCurrent` mid fade gives the blended value.
3. **Stopped vs Ended.** Roblox docs (as of October 2026) mark `Stopped` as deprecated; `Ended` fires once the track has finished affecting the rig, after the fade. Older vault notes and older community code use `Stopped`; read it as "stop requested", not "pose gone".
4. **KeyframeSequence vs published Animation vs CurveAnimation.** A `KeyframeSequence` is data in the place; an `Animation` with an asset id is the published clip the engine plays live; a `CurveAnimation` is a different data format for the same purpose. Only the published form plays in live games through the engine Animator; the other two need Studio, publishing or your own player.
5. **Motor6D vs AnimationConstraint vs Bone.** All three take a `Transform` written by the Animator, but they differ in physics: Motor6D is rigid, AnimationConstraint can be driven with force limits (physically simulated characters), Bones deform a skinned mesh and have no physics of their own. Code that assumes "every joint is a Motor6D" breaks on upgraded avatars.
6. **LOD here vs LOD in art.** Animation LOD skips evaluation or writes on far rigs; mesh LOD swaps geometry detail. A rig can be at full mesh detail and throttled animation, or the reverse.
7. **Hit-stop vs slow motion.** Hit-stop is a few frames of freeze on contact, local to attacker and target; slow motion is a time scale for everything. Applying hit-stop by slowing all tracks globally on a multiplayer server is a common misuse.
8. **Bake means two things.** In this section, "bake" means sampling motion into keyframes. In art notes it means rendering lighting or detail into textures. Search results for "bake" mix both.

## Common mistakes

1. **Reading "Core" as the top priority.** Symptom: sorting priorities by enum value puts Core last. Fix: Core blends lowest despite its large value; use a rank table.
2. **Calling a stub an animation.** Symptom: a stub plays nothing through the engine. Fix: a stub is a marker-only KeyframeSequence; it needs a player that reads its packed data.
3. **Confusing IKControl with a baked IK clip.** Symptom: expecting IKControl results to appear in an exported clip. Fix: IKControl runs at runtime only; bake if you need keys.
4. **Assuming "telegraph" is cosmetic.** Symptom: unfair-feeling enemies. Fix: telegraph durations are gameplay timing and belong in data the server uses.

## Related decisions

- [[Glossary]]: the whole-vault glossary for terms outside animation.
- [[Rotations Angles and Quaternions]]: background for nlerp, rotation vectors and flips.
- [[Interpolation Easing and Curves Math]]: background for easing styles and CubicV2.
- [[Hit-Stop and Screen Shake Tuning by Numbers]]: how long hit-stop should actually last.
- [[Level of Detail and Model Streaming]]: the art meaning of LOD, compared with the animation one.
- [[Baking Lighting and Detail into Textures]]: the other meaning of "bake".
- [[Squash Stretch and Anticipation in UI and Characters]]: anticipation as a design principle across UI and characters.
- [[Documentation and Knowledge Bases]]: keeping a team glossary accurate as terms drift.

## Connected notes
<!-- auto-links:start -->
[[Engine Gotchas]] · [[Troubleshooting Table]] · [[Snippets - Building and Sampling Clips]] · [[Animation Editor Advanced]] · [[AI Animation and Motion from Video]] · [[Skinning Weights]]
<!-- auto-links:end -->
