---
tags: [authoring, quality, arms, standard, qa, metrics]
---
# Animation Quality Standard

A measurable standard for character attack animation: arms that read as human, blades that stay out of the body, motion without pops. Every rule here can be checked by a script, which means a whole library can be scored, sorted and repaired automatically. It was built for one live action game (the reference project) and is reproduced here with all its thresholds, because the numbers are the useful part.

How it performed: at the first audit, **about 93%** of attack clips were "bad", with a median score of **31/100** (issues: arms in body in about 84% of clips, pops in 83%, wrist problems in 97%, blade through body in 82%). After re-solving the arms of about two thirds of the clips with an IK baker (see [[Pipeline - Arm IK Baking and QA]]), the targeted clips passed with **zero criticals**; typical moves went from scores of 1.7 to 81, 3.3 to 84, 10.6 to 83 and 7 to 86.

## Assumptions behind the numbers

- R15, scaled **1.6x**, about **9 studs** tall.
- Arm parts **1.6 studs** wide; upper arm (shoulder pivot to elbow pivot) **1.48 studs**; forearm (elbow pivot to wrist pivot) **1.29 studs**.
- Positions in HumanoidRootPart space: +X right, +Y up, -Z forward.
- Frames are 30 fps unless they say 60 Hz. QA samples at **60 Hz**.
- The generic held blade: **9.5 studs**, gripped **20%** up from the pommel.
- Measured on a **blocky dummy**. Slimmer avatars clear the body more easily than the scores say (see [[Open Questions]]).

Scale the distances if your character differs. Angles and speeds transfer as they are.

Rules are tagged **[QA]** (measured by the scorer) and **[BAKE]** (enforced by the baker).

## 0. What "human" means in a strike

- **Kinetic chain**: hips turn, then chest, shoulder, elbow, wrist, blade. Measured biomechanics: pelvis to trunk about 18 to 40 ms; trunk to elbow about 55 to 65 ms; each link 1.3 to 1.5x faster than the one before. In frames: **1 frame per link at 30 fps; 2 to 4 frames from hips to hand**. The QA checks the chain order of strikes with a **35 ms** tolerance per link.
- **Two-handed swords**: the rear hand at the pommel powers, the front hand guides; the arms push and pull against each other.
- **Finishing a cut**: arms extend in order (shoulders, elbows, wrists); elbows closed, not flared; wrists slightly flexed at contact.
- **Heavier blades are driven from more proximal joints** (sabre from elbow and wrist; longsword from shoulders and hips).
- **The free hand is part of the strike**: counter-rotate, chamber, guard or reach.

## 1. Joint ranges [QA][BAKE]

| R15 joint | Human range (clinical) | Game limit | Notes |
|---|---|---|---|
| Waist (UpperTorso) | spine rotation about 30 lumbar + thoracic (thoracic about 50 per side), flex 45 to 50, extension 25, side 25 | as authored | almost all twist above the pelvis is thoracic |
| Neck (Head) | rotation 60 to 80, flex 45 to 58, extension 45 to 60, side 42 to 45 | as authored | |
| Shoulder (UpperArm) | flex 180, ext 50 to 60, abduction 180, horizontal abd 45 / add 135, rotation 70 to 90 | arm no more than **48 degrees behind the frontal plane when raised, 62 when low**; never behind the back across the body | above 90 degrees elevation a real scapula rotates up; R15 cannot, so keep overhead arms short |
| Shoulder shrug | about 40 degrees of clavicle elevation | **no translation on arm joints** (over 0.05 studs = detached shoulder) | R15 has no clavicle |
| Elbow (LowerArm) | flex 0 to 145/150; hyperextension 0 to 5 (10 = hypermobile) | **pure hinge about X: 3 to 146 degrees** (0.06 to 2.55 rad); hyperextension over **8 flagged, over 15 critical**; sideways bend (Z) over **20 flagged** | the baker writes elbows as `Rx(theta)` only |
| Forearm roll | pronation 78 to 82, supination 85 to 88 | **twist within 85** (QA flags 95) | no forearm joint: the roll lives in the wrist's twist |
| Wrist (Hand) | flex 60 to 80, ext 60 to 70, radial 20, ulnar 30 | **flex 70, deviation 30** (QA flags **75 / 40**) | lining a blade up with the forearm needs 90 degrees of deviation: the arm must aim the blade |
| Hip / knee / ankle | hip flex 120, ext 30; knee 0 to 135/142 | as authored | out of scope for the arm pass |

The bake clamps are deliberately tighter than the QA flags (70/30/85 vs 75/40/95) so clamped bakes do not flag themselves.

## 2. Speed, acceleration and pops [QA][BAKE]

- **Pop**: a single-frame turn (60 Hz) of **30 degrees or more** that is also **3x larger** than the frames two either side. **Any arm joint over 50 degrees in one frame** (3,000 degrees/s) is always a pop, and **critical**.
- **Sustained speed limits** (degrees/s), above which motion is "smear territory", allowed only on a cut's active frames:

| Joint | Limit |
|---|---|
| LowerTorso (root turn) | 1,500 |
| UpperTorso | 1,100 |
| Head | 1,000 |
| UpperArm | 2,400 |
| LowerArm | 2,600 |
| Hand | 2,200 |

  For reference: measured elbow extension about 2,250 degrees/s; shoulder internal rotation 7,000 to 9,000 degrees/s for about 50 ms in pitching; a sword blade 1,000 to 2,000 degrees/s at impact.
- **Acceleration snap**: an arm joint's angular velocity changes by more than **2.5 x 120,000 degrees/s^2** in one 60 Hz frame (over about 8,300 degrees/s in a frame). For scale: peak trunk acceleration is about 11,600 degrees/s^2; a sword reaching 1,500 degrees/s over 35 degrees averages about 32,000.
- **Wrist snap**: the hand turns more than **30 degrees in one 60 Hz frame** relative to the forearm.
- **Flips [BAKE]**: no arm segment between keys turns more than **120 degrees**. Big key-to-key turns can play the wrong way (the Animator blends rotation vectors, not always the short arc; exactly 180 is ambiguous). See [[How the Animator Really Behaves]].

## 3. Arcs and smoothness [QA][BAKE]

- Hands and blade tips travel on **arcs**: curved strokes follow the two-thirds power law (speed rises where curvature falls); point-to-point reaches follow minimum-jerk, bell-shaped speed profiles; viewers judge constant speed along a curve as unnatural.
- **Corner [QA]**: the grip's velocity turns more than **50 degrees**, or its speed changes more than **75%**, in one 60 Hz frame while moving faster than **12 studs/s**. Target: **0 corners outside contact frames**; more than 1 per second is flagged.
- **Smoothness [QA]**: log dimensionless jerk (LDLJ) of the grip and the tip, reported only (relative; no absolute bar).
- **[BAKE] Arcs come from the joints**: the solve keeps the hand on its path, then each arm joint's rotation sequence is Gaussian-smoothed (sigma **0.8 frames** at 60 Hz where the blade matters, **3.5** elsewhere). Isolated one-frame blade snaps and grip teleports are smoothed out, except within **90 ms** of a marker.
- **Keys and easing**:
  - CubicV2 InOut on every key means zero velocity at every key: stop-start robot motion.
  - Linear on sparse keys means constant speed and a corner at each key. **[QA] linear spans**: Linear arm segments longer than **0.12 s** turning more than **20 degrees**; flagged at 3 or more.
  - **[BAKE]** keys are fitted to the dense solve with an error-bounded split: tolerance shoulder **1.0**, elbow **1.2**, wrist **1.5** degrees x tol (tol stepped from 1 to 9 only as far as the instance budget needs). Each segment takes the first easing that reproduces the in-betweens: Linear, CubicV2 InOut, Out, In.
  - **Never legacy Cubic** (reversed directions). **Constant** only for deliberate snaps.

## 4. Elbow direction (pole) [BAKE][QA]

The baker searches the elbow's whole swivel about the shoulder-wrist line for every frame (a grid of 24 hand rolls x 36 swivels) and softly prefers:

| Motion | Preferred elbow direction (chest frame; "out" = +X for the right arm) | Why |
|---|---|---|
| Default (hand below the shoulder, own side) | down 1.0, out 0.45, back 0.35 | relaxed arm |
| Hand above the shoulder | out 0.8, down 0.25, forward 0.25 | elbow opens out and forward, never straight up |
| Hand across the body | down 1.0, forward 0.55, out 0.15 | elbow leads in front of the chest instead of digging into it |
| Two-handed | down 1.0, out 0.25, back 0.1 | elbows down and close |

Continuity: in the whole-clip choice (a Viterbi pass), swivel changes up to about 15 degrees per 60 Hz frame are nearly free; more than 25 degrees in one frame costs heavily; elbow travel is priced in units of 0.15 studs per frame.
- **[QA] elbow flip**: swivel changes more than **30 degrees** in one 60 Hz frame while the elbow is bent more than **40 degrees** and sits more than **0.45 studs** off the shoulder-wrist line. Over **70 degrees** is **critical**.
- **[QA] chicken wing / shrug**: the elbow more than **0.55 studs above the shoulder pivot** while the hand hangs below the elbow, for **0.15 s** or longer.

## 5. The off hand [BAKE][QA]

Anchors are left-hand centres in the chest frame (UpperTorso centre, 1.6x rig), blended by context; the result trails the chest by **2 frames** (60 Hz) as overlap.

| Context | Detection | Behaviour | Anchor (x, y, z) |
|---|---|---|---|
| Two-handed grip | original left hand within **1.3 studs** of the hilt line for **0.15 s** or longer, or a `TwoHanded` attribute | left hand **1.15 studs** below the right along the blade, rolled 180 degrees; let go wherever holding would bury the arm | on the hilt |
| Cross-body cut | sword-grip velocity in chest -X above 6 studs/s | counter-swing (arm opens out and back) | (-3.5, 0.05, 0.85) |
| Downward cut / thrust | grip velocity -Y or -Z above 6 to 8 studs/s | chamber: fist back to the hip | (-1.95, -1.75, 0.25) |
| Cast / release | a marker whose name contains cast, release, burst, fire, open, pull, erupt, detonate, charge, summon, call, beam, rupture, scatter, shock, spawn, seal, invoke, conjure, orb or ignite (sigma 0.16 s) | open reach, arm about 85% extended | (-0.85, 0.45, -2.75) |
| Anything else | | ready guard in front of the solar plexus | (-0.7, -0.7, -1.9) |

Used only where the original left arm is **dead** (under 45 degrees/s summed while the body works hard: root or chest over 170 degrees/s, sword shoulder over 320 degrees/s, or root over 12 studs/s) or **buried** (more than 0.55 studs in the body). Fades in over the first 0.1 s and out over the last 0.15 s; relaxed wrist (flex 16 degrees, 7 degrees ulnar).
- **[QA] dead off hand**: the left arm still for more than **35%** of the hard-moving time.
- **[QA] mirrored arms**: mirrored joint motion correlates **r > 0.9** over **0.4 s** while both arms move (twinning).

## 6. Holds, entry and exit [QA]

- **Contact**: **2 to 4 frames** of near-zero velocity at 30 fps (a moving hold), then **4 to 8 frames** of settle. Hit-stop is added at runtime, not baked.
- **Dead hold**: every joint under about **4 degrees/s** for more than **0.3 s**, except at the clip's end.
- **Exit**: the last frame's arm joints within **75 degrees** of the idle. The ability player faded clips in over only 0.05 s, and a track that ends hands the arms straight back to the idle.
- **Entry**: the first frame within **90 degrees** of the idle.
- **Anticipation**: **2 to 6 frames** for light player attacks, **6 to 15** for heavy ones (30 fps); ultimates may hold longer. Not baked: the baker keeps all timing.
- **Rest flash (critical)**: both arm joints pass within **8 degrees of rest** between poses at least **40 degrees** from it, within **0.2 s**. It is a T-pose flash, usually from identity keys. **[BAKE]** no identity keys in a solve.

## 7. Clearance [QA][BAKE]

- **Arm capsules**: each arm part's centre axis with radius **0.85 x half its width** (0.68 studs for upper arm and forearm, 0.63 for the hand); the top **0.6 studs** of the upper arm (inside the shoulder) is ignored.
- **Body boxes**: UpperTorso and LowerTorso at **94%** of their size; Head at **86%**.
- **Depth** = radius minus the distance from the axis to the box:
  - **0.15** = contact (allowed, for example a fist at the chest);
  - **0.45** = bad;
  - **over 0.6 for 0.05 s = critical** (the forearm sunk more than half its thickness).
- **Blade**: the 9.5-stud blade at radius **0.12** must not enter the torso, hips, head, legs or the free arm by more than **0.25 studs**. About **20% of the blade is behind the grip** (the pommel), so long pommels matter.
- **[BAKE] targets**: grip targets are pushed out of the chest, hips and head boxes expanded by **1.2 / 0.95 / 1.3 studs**, through the front, the hand's own side or up (Y costs x2.5); never out the far side of the head, never through the back unless already in the back half; an exit that leaves the blade through the body costs +6; the push is smoothed over 3 frames. Blades through the body are turned the least angle that clears them, up to **70 degrees** (30% strength where the blade matters).
- **[BAKE] solve**: capsule depth costs `220 x (depth - 0.08)^2` per candidate; arms behind the back cost `((back - 42 degrees) / 8)^2`; crossing behind the body +4; chicken wing `3 x ((elbowUp - 0.35) / 0.4)^2`.
- **Feet**: planted feet may drift **0.05 studs** in HRP space, airborne feet 0.12 (body thinning bounds). Root drops for drive and kneel poses stay at -1.0 stud or higher at scale 1 (see [[Spec-Driven Move Authoring]]).

## 8. Scoring

**Score = max(0, 100 - sum(weight x severity))**. Weights:

| Issue | Weight |
|---|---|
| arm_in_body | 20 |
| pops | 12 |
| R_elbow_inverted | 10 |
| R_elbow_flip | 10 |
| blade_through_body | 8 |
| R_wrist_range | 8 |
| dead_offhand | 8 |
| rest_flash | 8 |
| R_wrist_snap | 6 |
| R_elbow_sideways | 6 |
| R_shoulder_range | 6 |
| hand_path_corners | 5 |
| linear_spans | 4 |
| exit_snap | 4 |
| chicken_wing | 4 (right) / 3 (left) |
| joint_offset | 4 |
| dead_hold | 3 |
| others | 3 |

Left-side weights are slightly lower. A clip is **bad** if the score is **under 70** or it has **any critical**.

### Bars used over time
- **Pro pass**: 65 or more, stretch 75+.
- **Later waves**: **80 or more with zero criticals, measured in the real Animator**. This is the standard that stuck.
- Some user-authored kits were left with arm criticals by explicit decision; the standard is a tool, not a religion.

## 9. Verification and install criteria

The scorer runs in two modes: **model** (an offline prediction of playback) and **play** (the real Animator stepping the clip on a dummy with `Animator:StepAnimations(1/60)`, reading every joint's `Transform`). Install only when:
- model vs real Animator **under 3 degrees** max on the arm joints (up to about 5 on near-180-degree segments, checked by eye on the filmstrip);
- the clip **loaded** (a just-registered Studio clip plays nothing until `Length > 0`; a false "117 degrees error" was exactly that);
- **zero criticals**;
- a **score gain of 15 or more**;
- **fidelity to the original choreography**: blade direction deviation mean **15 degrees or less** and max **60 or less** (a later polish stage used a mean of 35 degrees as its guard);
- never when `max_key_segment` is **120 or more**, a new critical appeared, or the score went down.

Calibration examples (before > after): 40 > 73, 13 > 72, 22 > 79, 9 > 69, 23 > 69 (still a critical), 0 > 38; model vs Animator 0.9 to 4.6 degrees max at that stage. Later, the offline model matched `Animator:StepAnimations` on every clip (several hundred) with a median error of **0.03 degrees** (99th percentile 2 to 4).

## 10. What "weird" looks like: the catalogue

| # | Look | QA key | How the baker fixes it |
|---|---|---|---|
| 1 | forearm half inside the chest; free forearm in the ribs; hand inside the face | arm_in_body | targets pushed out; swivel search avoids boxes; buried free arm replaced by a context behaviour |
| 2 | forearm bending backwards | elbow_inverted | pure hinge 3 to 146 degrees |
| 3 | elbow bent sideways | elbow_sideways | pure hinge |
| 4 | elbow jumps to the other side in a frame | elbow_flip | whole-clip Viterbi with continuity, then smoothing |
| 5 | elbow hiked over the shoulder; translated arm joints | chicken_wing, joint_offset | chicken-wing cost; rotation-only arms |
| 6 | blade aimed by a wrist bent 70 to 90 degrees; hand spinning 100+ degrees in a frame | wrist_range, wrist_snap | continuous clamp 70/30/85 (twist unwrapped so it holds at the limit instead of flipping); the arm aims |
| 7 | arm frozen straight while the body spins | frozen_arm_spin | drag: in chest turns over 150 degrees/s the hand target trails by up to 3 frames |
| 8 | T-pose flash between poses | rest_flash | every frame solved; no identity keys |
| 9 | off hand hanging dead | dead_offhand | context behaviour |
| 10 | arms mirrored | mirrored_arms | context-driven free hand |
| 11 | joint jumps 30 to 200 degrees in a frame | pops | snap windows smoothed; segments under 120 degrees |
| 12 | corners in the hand path | hand_path_corners | joint-space smoothing; fitted easing |
| 13 | blade through own body | blade_through_body | blade clearance turn |
| 14 | snap into or out of the clip | exit_snap, entry_snap | ends kept; off-hand behaviour fades out at the ends |
| 15 | sparse linear spans, statue holds | linear_spans, dead_hold | fitted easing |

## 11. Pose lessons that cause criticals

The scorer exposed patterns in authored choreography that no solver can fully rescue. Fix them in the poses (see [[Spec-Driven Move Authoring]] and [[Weapon Swing Design]]):
- **Arms behind the body**: sprint, surf and "load" poses.
- **Sprint into thrust or cross-cut** lead-ins drive the forearm into the torso; use a flat wind-up.
- **Backhand winds and two-handed low guards** put the forearm across the chest.
- **Big root-yaw swaps every 0.1 s** pop.
- **Long pommels**: overhead, drive and kneel one-handed with the off hand out to the side; chop over the front before every drive; halve root yaw in flurries; keep hands further from the body; **the last key should be rest**.
- **Timing rules**: no grounded stance change faster than **0.12 s**; sub-0.1 s segments that move hips or feet go Linear and the first one eases In; overhead keeps the hips down while chop drops the hips first; shallower load (root y about **-0.55**); thrust hand about **0.7** out.
- **End frames**: a "ready" end pose put the pommel in the hip; re-keying end frames brought **22 of 22** moves to 0.08 s or less of blade-through-body.
- **Overhead > chop > deep drive into the floor** buries the arms: use a shallow drive or two hands.
- **Salute-aloft ultimates and high > falling deep openers** bake badly: use overhead, chop and falling variants.
- One re-pose pass scored worse on 6 moves and was rolled back: **keep before-dumps of every clip**.

## 12. Known limits

- The dummy is blocky; real avatars are often slimmer.
- Legs and torso are not re-solved by the arm pass, so pops there remain (the locomotion set scored 100 except a run at 92.2 from a toe-off pop).
- IK hand misses up to about 1.3 studs remained in a few poses.
- Blended live playback (several tracks at once, network replication) was never watched in Play by the scorer.

## See also
[[Pipeline - Arm IK Baking and QA]], [[Arm QA Metrics Reference]], [[Arm Baker Internals]], [[Weapon Swing Design]], [[Spec-Driven Move Authoring]], [[Animation Review Checklist]], [[Elbow Poles Swivel and Joint Limits]], [[How the Animator Really Behaves]], [[Open Questions]].

## Connected notes
<!-- auto-links:start -->
[[Posing and Silhouettes]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Inverse Kinematics]] · [[Two-Bone IK Math]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[AI Animation and Motion from Video]] · [[Animation Start Here]]
<!-- auto-links:end -->
