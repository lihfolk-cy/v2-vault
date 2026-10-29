---
tags: [gotchas, unresolved, research, type/guide, area/animation, level/intermediate, api/Animator, api/StepAnimations, api/IKControl]
---
# Open Questions

This note lists findings that conflict, were measured only once, or were never tested in production. The vault keeps them visible instead of quietly picking a winner. Each entry gives the competing claims, why it matters, the current best guess, a test that would settle it, and **which notes discuss it**. If you settle one, you have learned something most Roblox developers do not know.

The claims come from the reference project's tools and notes (one live action game), from the official docs, and from contradictions other notes in this vault flagged while they were written. "Measured" means the real `Animator` was stepped with `Animator:StepAnimations` in Edit and the joint `Transform`s were read.

Quick index:

| # | Question | Best guess today |
|---|---|---|
| A1 | Elastic/Bounce reversed? | Not reversed |
| A2 | Constant easing | In = jump now, Out = hold, InOut = midpoint |
| A3 | nlerp per sequence or per joint? | Per sequence, Linear only |
| A4 | Exact 180 keys | Ambiguous; avoid |
| A5 | What `GetScale()` multiplies | All clip offsets on `ScaleTo` rigs; nothing on body-scaled ones |
| A6 | Time edge cases | Partly measured |
| A7 | `StepAnimations(0)` | Use a tiny positive dt |
| A8 | `Transform` writes under fixed simulation | Reported broken; test |
| A9 | Retargeting | Undocumented algorithm |
| B1 to B9 | Tooling disagreements | See each |
| C1 to C7 | Never production-tested | See each |
| D1 to D14 | Docs, naming and design contradictions | See each |

---

## A. Animator behaviour

### A1. Do Elastic and Bounce easing run reversed?
- **Claim 1.** The offline baker's maths module and the weapon-rig Lua player treat `Elastic` and `Bounce` as reversed, like legacy `Cubic` (In plays as Out).
- **Claim 2.** The character Lua player's easing code cites a later, dedicated measurement: Elastic and Bounce **follow** their direction; only legacy Cubic is reversed. It also models Elastic as Penner's curve (period 0.3, InOut 0.45) and `Bounce InOut` as BounceIn's shape on both halves.
- **Wrinkle.** That player's own file header still says "legacy Cubic / Elastic / Bounce reversed", while its easing table says the opposite. The header is older than the table. The buffer format inherits the split: the general player decodes Elastic/Bounce codes unreversed, the weapon-rig player maps them back to its own reversed reading, so each round-trips its own behaviour.
- **Why it matters.** Anyone porting old clips or writing a sampler.
- **Best guess.** Claim 2 (later, more specific, backed by code that matched the Animator within 0.084 degrees on its test set). No production clip used Elastic or Bounce, so the test set may not have covered them.
- **Test.** One joint, two keys 90 degrees apart, 1 s, each style and direction. Step at 1/60 and plot the angle against the candidate curves.
- **Discussed in:** [[Keyframes, Easing and Interpolation]], [[Lua Keyframe Player Internals]], [[Clip Buffer Format]], [[Weapon Rig Player]], [[Equip Draw and Flourish Systems]], [[Snippets - Building and Sampling Clips]].

### A2. What does Constant easing do?
- **Measured (the animation standard).** `Constant In` jumps to the next key at once; `Constant Out` holds the old value until the next key; `Constant InOut` jumps at the midpoint. The character Lua player and its buffer format encode three separate codes.
- **Other tools.** The weapon-rig player treats every Constant as "step to the next pose", and its stub decoder maps all three codes to one value. The spec baker's `ease()` returns 0 (hold) for every Constant.
- **Docs.** Roblox's own pages describe Constant inconsistently (see D4 for the related direction wording).
- **Why it matters.** Snap poses (hit frames, cuts) that look right in one tool and wrong in game.
- **Best guess.** The three-way measured behaviour.
- **Test.** As A1, for the three directions.
- **Discussed in:** [[Keyframes, Easing and Interpolation]], [[Animation Editor Workflow]], [[Authoring Clips in Code]], [[Lua Keyframe Player Internals]], [[Weapon Rig Player]].

### A3. When does the Animator nlerp instead of blending rotation vectors?
- **Claim 1 (animation standard).** Rotations between keys are a linear blend of rotation vectors, choosing the closest representation pair. Measured to 0.24 degrees on 15 clips where [[slerp]] was up to 178 degrees off; an offline model matched every baked clip (several hundred) (median 0.03 degrees, 99th percentile 2 to 4).
- **Claim 2 (weapon-rig player).** [[Quaternions|Quaternion]] nlerp (shortest way) when **a joint's** keys are evenly spaced, rotation vectors otherwise. Measured within 0.001 rad on 80 rigs.
- **Claim 3 (character player, latest).** nlerp only when **all keyframes of the sequence** are evenly spaced (a marker-only keyframe off the grid counts) **and every key is Linear**; joints, rig type and key count do not matter.
- **Reconciliation.** Probably consistent: Claim 1 was measured on uneven clips, Claim 2 on weapon clips that are generated with uniform Linear keys or thinned per joint (where the two rules agree), and Claim 3 is the most specific. On arbitrary clips Claims 2 and 3 can differ.
- **Why it matters.** Dense, evenly spaced bakes and sparse hand-keyed clips interpolate differently; a thinned clip silently switches mode.
- **Test.** A sequence with one joint evenly keyed and another keyed off-grid; compare each joint with both models.
- **Discussed in:** [[How the Animator Really Behaves]], [[Lua Keyframe Player Internals]], [[Weapon Rig Player]], [[Snippets - Building and Sampling Clips]], [[Snippets - Lua Keyframe Player Core]].

### A4. Exactly 180-degree keys
Measured: the Animator "coin-flips" the direction of an exact 180-degree segment; three enemy clips showed it and were the only parity failures. A rotation-vector sequence also holds an end key of exactly 180 degrees "the other way round". No rule was found beyond "avoid exact 180s". **Test**: does the flip depend on the axis sign, the previous segment, or floating-point noise? **Discussed in:** [[How the Animator Really Behaves]], [[Lua Keyframe Player Internals]], [[Engine Gotchas]].

### A5. Which translations does scale multiply?
- One source: the Animator scales **root** translations by `Model:GetScale()`.
- Another (and the `Model` docs: the scale factor "is applied to joint offsets of animations played on an AnimationController under the model"): on a model-scaled rig all clip **offsets** are multiplied, and QA divided them back.
- The Lua players scale every animated translation.
- Agreed: characters scaled through Humanoid body scales have `GetScale() = 1` and clip translations apply literally.
- **Test.** A `ScaleTo(2)` rig with translation keys on the root child and on a limb.
- **Discussed in:** [[Scale and Animation]], [[Motor6D Math and CFrame Composition]], [[Engine Gotchas]].

### A6. Track time and float32 edge cases
Measured: track time is float32, `Stop()` keeps time running during the fade, a finished one-shot holds and fades over 0.3 s. Not measured: markers exactly at the clip's last time when a loop wraps at high speed, and whether markers can fire late on throttled remote characters (`Animator.EvaluationThrottled`). **Discussed in:** [[Animation LOD]], [[Markers and Events]].

### A7. Does `StepAnimations(0)` apply the current pose?
The measured rule is that `StepAnimations` needs `dt > 0` to advance; one of the project's own tool snippets calls `StepAnimations(0)` right after `Play(0)` to apply the first pose. Nobody checked whether the zero step does anything. Use a tiny positive step (`1e-4`) and the question does not arise. **Discussed in:** [[Animator Deep Dive]], [[Testing Animations in Studio]], [[Engine Gotchas]].

### A8. `Transform` writes under fixed simulation
Forum bug reports acknowledged by Roblox staff say that with `Workspace.UseFixedSimulation` enabled (needed for server authority), setting `Transform` on Motor6Ds and AnimationConstraints does not take effect while an animation is playing. Status as of October 2026 unverified. Every procedural layer in [[Snippets - Procedural Motion]] and [[Snippets - IK]] writes `Transform`, so test them under that setting before adopting it. **Discussed in:** [[AnimationConstraint and Physically Simulated Characters]].

### A9. Retargeting
`Workspace.Retargeting` (`AnimatorRetargetingMode`) adapts joint transforms to body proportions; community reports say enabling it changed how existing R15 clips and C0-driven code looked. The algorithm is undocumented, and the measured Animator models in this vault were taken without it. **Discussed in:** [[Animator Deep Dive]], [[Retargeting Animations Between Rigs]].

---

## B. Tooling contradictions

### B1. The spec baker checks fits with slerp
The spec baker decides whether a span's own easing reproduces its in-betweens using `CFrame:Lerp` (a slerp), not the measured rotation-vector model, so on big turns far from rest its kept keys may play slightly differently than assumed (one reason the arm re-solver runs afterwards). **Open**: how large is the error on clips that skipped the re-solve? **Discussed in:** [[Spec-Driven Move Authoring]], [[Authoring Clips in Code]].

### B2. Arm solver grid size
The arm solver's header says 16 hand rolls by 24 elbow swivels; the README and defaults say 24 by 36, and the code uses 24 and 36. The code wins. **Discussed in:** [[Arm Baker Internals]], [[Elbow Poles Swivel and Joint Limits]].

### B3. Wrist limits: several sets for one joint
Bake clamp flex 70 / deviation 30 / twist 85 degrees; QA flags at 75 / 40 / 95 (deliberately looser so clamped bakes do not flag themselves); the legacy solver's caller-supplied limits (62 / 100 by default, 82 / 118 for cuts); a "natural arm" solver at 65 / 27 / 85. A history of tightening, not a bug, but three tables for one wrist. **Discussed in:** [[Elbow Poles Swivel and Joint Limits]], [[Arm QA Metrics Reference]], [[Arm Baker Internals]], [[Snippets - IK]].

### B4. Legacy Cubic in early clip sets
Early heavy and scythe sets wrote legacy `Cubic` with directions chosen as if they were TweenService directions; since legacy Cubic plays reversed, those segments ease opposite to intent. Whether they were rewritten is not recorded. **Test**: the lint in [[Testing Animations in Studio]]. **Discussed in:** [[Authoring Clips in Code]].

### B5. Where clip originals live
The stubbing tool's header says a ServerStorage archive folder; later notes say originals moved out of the place to an on-disk archive by rule. The installed plugin version was not checked. **Discussed in:** [[Baked Clip Stubs and Archiving]], [[Clip Archive Server]].

### B6. Studio call budget
armcheck's default is 3.5 s per call, an older README says 5 s, later rules say 1.5 s (current). **Discussed in:** [[Studio Tooling Architecture]].

### B7. Re-baking a baked clip
The arm baker refuses a `ProBaked` clip unless `--force`, and its docs say not to use `--force`; the safe path is the safety copy. Whether any shipped clip was force re-baked is unknown. **Discussed in:** [[Pipeline - Arm IK Baking and QA]].

### B8. The arm-in-body critical rule
The arm QA summary table reads "critical over 0.6 for 0.05 s". The scorer's code is more specific: critical when the worst depth exceeds 0.6 **and** at least 0.05 s is spent over 0.45. The second form is the one that runs. **Discussed in:** [[Arm QA Metrics Reference]], [[Animation Review Checklist]].

### B9. Easing into versus easing leaving
Roblox applies a Pose's easing to the segment **leaving** it. Clip specs and authors think in easing **into** a key, and the reference builders shift each key's easing onto the previous pose. Tools and notes that do not say which convention they use cannot be compared directly. Not an engine question, but a frequent source of "wrong feel on every segment". **Discussed in:** [[Keyframes, Easing and Interpolation]], [[KeyframeSequence Keyframe and Pose Reference]], [[Authoring Clips in Code]], [[Snippets - Building and Sampling Clips]].

---

## C. Never tested in production

### C1. IKControl and CurveAnimation
Both are documented ([[IKControl Reference]], [[CurveAnimation and Curve Channels]]), but the reference pipelines baked everything. Unknowns: how `IKControl` composes with Lua code that writes `Transform` in `PreSimulation` (docs say [[IKControl]] overrides the animation on its chain and `Priority` orders controls, not where IK sits relative to script writes), whether a foot IKControl's result shows up in `Transform` when read in `PreSimulation`, and whether [[CurveAnimation]] interpolates like KeyframeSequences.

### C2. Live replication of Lua-played tracks
The relay (batched, throttled; speed changes sent at once past 6%, else every 0.25 s; late joiners request active tracks) was verified in Studio and by maths, not under real latency with many players. **Discussed in:** [[Lua Keyframe Player]], [[Replication and Ownership]].

### C3. Live blending of baked arms
Verified against the real Animator in Edit; never watched in Play with locomotion, carry layers and fades. **Discussed in:** [[Pipeline - Arm IK Baking and QA]].

### C4. QA dummy versus real avatars
All arm QA ran on a blocky R15 dummy. Slimmer avatars clear the body more easily than scores suggest; bulky layered clothing may clear it less. **Discussed in:** [[Animation Quality Standard]], [[Posing and Silhouettes]].

### C5. "Edit-verified" coverage
A long stretch of the reference work was never play-tested; "Edit-verified" meant stepped-Animator or maths checks. Treat "measured" numbers in this vault as Edit truth for the engine's mixer, not proof of live behaviour.

### C6. Hinge directions guessed from geometry
A rig builder for an imported flexible sword (4 ribbons of 5 chained segments) guessed hinge axes from geometry; flagged for play-testing, never confirmed. **Discussed in:** [[Weapon Design Rig Builder]].

### C7. Foot-plant layer and active ragdolls
A foot-plant layer for authored locomotion measured 0.00 to 0.01 studs/s slide between 9.6 and 120 studs/s, but shipped switched off. Force-based `AnimationConstraint` "active ragdoll" tuning was never tried. **Discussed in:** [[Procedural Gait and Footstep Planning]], [[Snippets - Ragdoll]].

---

## D. Docs, naming and design contradictions flagged across the vault

### D1. Carry layer priority: Action or Action2?
The project notes say the weapon carry layer must be at **Action**: an Action2 carry cancels equip flourishes (which cancel on any Action2+ track) and reads as an attack to controllers that watch Action2+. A later locomotion core's code comment calls it "right-arm layer, Action2". Safe rule: Action. **Discussed in:** [[Locomotion Systems]], [[Engine Gotchas]], [[Snippets - Animation Controller Module]].

### D2. Is `AnimationController` deprecated?
Recent engine API dumps tag the `AnimationController` class line itself as deprecated; the documentation still presents it as the normal Animator host for rigs without a Humanoid, and only its own `LoadAnimation`/`GetPlayingAnimationTracks`-style members are deprecated. In practice: keep it as a container, put an `Animator` under it, never call its own `LoadAnimation`. **Discussed in:** [[Animation Objects]], [[Animator Deep Dive]].

### D3. Is `KeyframeReached` deprecated?
The docs site lists it under deprecated members in some views; the API dump does not tag it. Either way, markers (`GetMarkerReachedSignal`) are strictly better. **Discussed in:** [[AnimationTrack Reference]], [[Engine Gotchas]], [[Markers and Events]].

### D4. `PoseEasingDirection` wording
The `PoseEasingDirection` enum page still describes directions in the legacy reversed sense, while `CubicV2` follows TweenService directions (measured). Read the measured behaviour, not the enum page. **Discussed in:** [[Authoring Clips in Code]], [[Keyframes, Easing and Interpolation]].

### D5. Revoking animation access
Asset privacy docs say revoking a collaborator only stops them granting new experiences (existing grants stay); an animation announcement says collaborator access "can be revoked at any time". Both can be true. Plan as if experience grants are permanent. **Discussed in:** [[Animation Asset Permissions and Groups]].

### D6. `ScaleTo` on upgraded avatars
A community thread on the avatar joint upgrade ([[AnimationConstraint]] joints) reports `Character:ScaleTo` broken on upgraded characters; body-scale values still work. Unverified; test scaling on upgraded rigs. **Discussed in:** [[AnimationConstraint and Physically Simulated Characters]], [[Scale and Animation]].

### D7. One animation per FBX versus multi-clip GLB
Roblox's modeling specification says only one animation track can be exported per mesh or model. The reference project imported creature GLBs with every Blender action as a named clip (23 for one boss), and a 2026 announcement added an "Animation Track Selection" option to the editor's import dialog. Probably the 3D Importer handles several glTF animations while the avatar path and editor import take one at a time; test with your Studio version. **Discussed in:** [[Exporting FBX vs GLB]], [[3D Importer Settings Reference]], [[Animation Data from Blender to Roblox]].

### D8. FBX axis settings
Roblox's Blender guide says export FBX with "Forward: Z Forward, Up: Y Up" and import with World Forward "Front", World Up "Top". The reference project's FBX route (an Open Cloud upload add-on) used its own settings, measured zero drift and needed no yaw fix, while its GLB route needed the 180-degree importer turn accounted for. Different routes, same destination: verify once per route. **Discussed in:** [[Blender Armature and Bone Roll Conventions]], [[Exporting FBX vs GLB]].

### D9. Clip Editor or Animation Editor?
Current Studio builds may label the Avatar-tab button **Clip Editor**; the docs call the tool the Animation Editor; the official capture guide says "click Clip Editor. The Animation Editor window displays". Same tool. The Graph Editor is a different tool (blend trees). **Discussed in:** [[Animation Editor Workflow]], [[Animation Capture and Mocap]], [[Animation Editor Advanced]].

### D10. `AnimSaves` versus `RBX_ANIMSAVES`
The Animation Editor saves under `ServerStorage.RBX_ANIMSAVES`; older editor versions and the 3D Importer leave `AnimSaves` containers on rigs; the reference project measured GLB importer clips landing in `RBX_ANIMSAVES.<model>`; an August 2026 announcement says importer animations are now saved automatically to AnimSaves. Check both places after an import, and clean both before shipping. **Discussed in:** [[Animation Objects]], [[3D Importer Settings Reference]], [[Importing Models and Rigs]], [[Performance and Memory]].

### D11. Katana draw: 35% or always?
Earlier project notes say katanas used the katana draw 35% of the time; later notes say every katana always uses it. The later rule is current; it is a design change, not an engine question. **Discussed in:** [[Equip Draw and Flourish Systems]].

### D12. `SafeAreaCompatibility` "Off"
The project notes say set `SafeAreaCompatibility` "Off" for letterbox bars. The enum has `None` and `FullscreenExtension` (Docs); "Off" means `None`. **Discussed in:** [[Camera Shake and Camera FX]], [[Cameras and Cutscenes]], [[Snippets - Camera Shake and FX]], [[Engine Gotchas]].

### D13. The `Ragdoll` Humanoid state
`Enum.HumanoidStateType.Ragdoll` is marked deprecated in the docs; older tutorials still use it. Use `Physics` for ragdolls. **Discussed in:** [[Humanoid States and Animation]], [[Snippets - Ragdoll]].

### D14. Look-at rotation order
Several look-at snippets in the wild (and an earlier version of this vault) build head rotations with `CFrame.Angles(pitch, yaw, 0)`, which is `Rx * Ry * Rz` and rolls the head when looking up and to the side at once. `CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)` (`Ry * Rx * Rz`, Docs) yaws first and does not roll. Not a contradiction in the engine, but two conventions that both "work" on single-axis tests. **Discussed in:** [[Look-At Aim and Head Tracking]], [[Snippets - Procedural Motion]].

---

## How to contribute an answer
1. Build the smallest clip that isolates the question (one joint, two or three keys).
2. Step it with `Animator:StepAnimations(1/60)` in Edit and record `Transform`s (harness in [[Testing Animations in Studio]]).
3. Compare against each candidate model; report the max difference in degrees.
4. Note your Studio version: engine behaviour changes between releases.
5. Update this note and every note listed under "Discussed in".

## See also
[[How the Animator Really Behaves]] · [[Keyframes, Easing and Interpolation]] · [[Engine Gotchas]] · [[Lua Keyframe Player Internals]] · [[Arm Baker Internals]] · [[Testing Animations in Studio]]

## Connected notes
<!-- auto-links:start -->
[[Animation Start Here]] · [[Animation Glossary]] · [[Troubleshooting Table]] · [[Moon Animator and Third-Party Tools]] · [[AI Animation and Motion from Video]] · Easing
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Debugging Animation Problems]] · [[Inverse Kinematics]] · [[Procedural Animation]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Timing Spacing and Frame Charts]] · [[Pipeline - New Animated Weapon]] · [[Rigging in Blender]] · [[Custom Rigs - Weapons and Props]]
<!-- related:end -->
