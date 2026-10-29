---
tags: [pipeline, qa, arms, metrics, reference, type/reference, area/animation, level/intermediate, api/Animator]
---
# Arm QA Metrics Reference

<!-- tldr:start -->
> [!tldr] TL;DR
> - A verifier samples the baker's own after-dump through the offline Animator model at the truth rate and compares it, joint by...
> - "Does this swing look right?" does not scale to several hundred clips.
> - Note the deliberate gap: the baker clamps wrists to 70 / 30 / 85 deg while QA flags at 75 / 40 / 95.
> - Every issue has a severity clamped to 0..1, a worst time, and a human-readable detail.
>
> Cost: TL;DR ~140 tok · whole note ~4.8k tok. Read more: ## The metrics · ## The score
<!-- tldr:end -->

The complete metric set of the arm QA scorer ("armcheck") used in one live action game: every metric, how it is measured, its threshold, its severity formula, its score weight, which ones are critical, the score formula, and the rules a re-baked clip must pass before install. Workflow context: [[Pipeline - Arm IK Baking and QA]]. Solver that targets these metrics: [[Arm Baker Internals]].

Everything is in HumanoidRootPart space of a 1.6x R15 rig (studs), times in seconds, angles in degrees, sampled at **60 Hz**. The input is a set of joint Transforms per frame, either from the real Animator's playback ("truth") or from the offline Animator model.

## Why a scorer at all

"Does this swing look right?" does not scale to several hundred clips. A scorer that turns every failure you can see in a filmstrip into a number lets you: rank clips worst first, prove a bake improved a clip, refuse an install that made it worse, and catch regressions when someone edits a clip. The trick is choosing metrics that track what a viewer perceives. Each metric below maps to a specific "that looks wrong" moment, and each threshold was tuned so clean user-authored clips score about 89-90 and the worst clips score near 0.

**Score it on truth, not on the model.** The offline Animator model matches the real Animator to a median 0.03 deg, but its outliers (segments near 180 deg) are exactly where clips look broken. Reported numbers come from Animator playback.

## Geometry used by the metrics

| Thing | Definition |
|---|---|
| Body boxes | UpperTorso and LowerTorso at 94% of their size, Head at 86% (oriented boxes from FK) |
| Upper-arm capsule | the part's own Y axis, from 0.6 studs below its top end to 0.35 above its bottom end (the top 0.6 studs are inside the shoulder and ignored), 5 sample points, radius 0.85 x half the part width (0.68 studs on a 1.6-wide arm) |
| Forearm capsule | its Y axis from 0.3 inside each end, 5 points, radius 0.85 x half width |
| Hand | its centre point, radius 0.8 x half width (0.63) |
| Depth | radius minus the signed distance from the axis point to the box (positive = inside by that much) |
| Grip point | 0.19 hand-widths below the hand centre along the hand's Y |
| Blade | along the hand's -Z, 9.5 studs, 20% behind the grip; 9 points from 1.2 to 7.6 studs ahead of the grip plus 3 pommel points 0.9-1.9 studs behind, radius 0.12 |
| Blade targets | torso, hips, head, both upper and lower legs, the free (left) upper arm and forearm, each box at 85% |
| Swing / twist | joint rotations split into swing and twist about the part's local Y axis ([[Quaternions\|quaternion]] swing-twist decomposition) |
| Rest | identity Transform (arms at the rig's bind pose) |
| Idle | the first keyframe of the game's standing idle clip |

## Thresholds (the STD table)

| Key | Value | Used by |
|---|---|---|
| `pen_contact` | 0.15 studs | arm in body: allowed contact (a fist at the chest) |
| `pen_bad` | 0.45 studs | arm in body: "bad" time |
| `elbow_hyper` | 8 deg | elbow inverted |
| `elbow_side` | 20 deg | elbow sideways |
| `elbow_flex_max` | 150 deg | reference only (flex range reported, not scored) |
| `wrist_flex` / `wrist_dev` / `wrist_twist` | 75 / 40 / 95 deg | wrist range |
| `sh_back_high` / `sh_back_low` | 48 / 62 deg | shoulder range |
| `swivel_step` | 30 deg per frame | elbow flip |
| `pop_step` / `pop_ratio` | 30 deg per frame / 3x | pops |
| `w_lim` (deg/s) | LowerTorso 1500, UpperTorso 1100, Head 1000, UpperArm 2400, LowerArm 2600, Hand 2200 | overspeed (reported) |
| `alpha_lim` | 120,000 deg/s^2 | acceleration snap (at 2.5x) |
| `corner_deg` / `corner_speed` | 50 deg / 12 studs/s | hand-path corners |
| `dead_w` | 45 deg/s | dead off-hand |
| `flash_near` / `flash_far` | 8 / 40 deg | rest flash |
| `exit_jump` | 75 deg | exit (entry uses 90) |

Note the deliberate gap: the baker clamps wrists to 70 / 30 / 85 deg while QA flags at 75 / 40 / 95. QA is looser so clamped bakes never flag themselves, and only real excess shows.

## The metrics

Every issue has a severity clamped to 0..1, a worst time, and a human-readable detail. Formulas are exact.

### 1. `arm_in_body` (weight 20)

- **Measure:** for each arm's three capsules against each body box, the depth per frame; take the worst over both arms.
- **Fires when:** worst depth > 0.15.
- **Severity:** `0.6 * (worst - 0.15) / 0.6 + 0.4 * min(1, badTime / 0.25)`, where `badTime` = seconds with any depth over 0.45.
- **Critical** ("arm deep in body"): worst depth > 0.6 **and** at least 0.05 s spent over 0.45.
- **On screen:** a forearm across the chest half inside it; a free forearm tucked into the ribs; a hand inside the face.

### 2. `blade_through_body` (weight 8)

- **Measure:** blade points (including the pommel) against torso, hips, head, legs and the free arm; depth = 0.12 - signed distance.
- **Fires when:** worst depth > 0.25 **and** more than 0.05 s with depth over 0.25.
- **Severity:** `0.5 * min(1, (worst - 0.25) / 0.8) + 0.5 * min(1, time / 0.4)`.
- **On screen:** the sword passing through your own chest, or the pommel parked in your hip at the end of a swing.

### 3. `R_elbow_inverted` / `L_elbow_inverted` (weights 10 / 8)

- **Measure:** the forearm joint's swing about X ("flex"); hyperextension = -flex.
- **Fires when:** hyperextension > 8 deg. **Severity:** `(hyper - 8) / 30 + 0.3`.
- **Critical** ("elbow inverted"): hyperextension > 15 deg.

### 4. `R_elbow_sideways` / `L_elbow_sideways` (weights 6 / 5)

- **Measure:** the forearm's swing about Z. A real elbow is a hinge; an R15 elbow constraint can bend sideways.
- **Fires when:** |side| > 20. **Severity:** `(|side| - 20) / 40 + 0.2`.

### 5. `R_wrist_range` / `L_wrist_range` (weights 8 / 5)

- **Measure:** the hand joint's swing-twist about Y: flexion = swing about Z, deviation = swing about X, and **pronation = wrist twist + elbow twist** (R15 has no forearm roll joint, so forearm roll ends up split across both).
- **Excess** per frame = sum of each component's overshoot past 75 / 40 / 95.
- **Severity:** `excess_at_worst / 60 + min(0.4, overTime / 1.0)`.
- **On screen:** a blade aimed by a wrist bent 70-90 deg sideways. This was the most common issue at baseline (about 97% of moves).

### 6. `R_wrist_snap` / `L_wrist_snap` (weights 6 / 4)

- **Measure:** the hand joint's own per-frame turn (relative to the forearm).
- **Fires when:** > 30 deg in one 60 Hz frame. **Severity:** `(step - 30) / 60 + 0.2`.

### 7. `R_shoulder_range` / `L_shoulder_range` (weights 6 / 5)

- **Measure:** the upper-arm direction (shoulder pivot to elbow pivot) in the chest frame, mirrored for the left arm. `back` = asin(z component) = degrees behind the frontal plane.
- **Limit:** 48 deg when the arm is raised (chest-frame y > -0.3), 62 when low. **Across the back** (x < -0.25, z > 0.25, y > -0.6) counts as at least 25 deg over.
- **Severity:** `over / 40 + 0.15`.
- **On screen:** "load" and sprint poses with the arm swung far behind the torso.

### 8. `R_elbow_flip` / `L_elbow_flip` (weights 10 / 8)

- **Measure:** the elbow's swivel angle about the shoulder-wrist line, measured from "down" (chest -Y projected off the line; chest +Z when the line is near vertical, so the reference never degenerates).
- **Counts a flip frame when:** the swivel changes more than 30 deg in one frame, the elbow is bent more than 40 deg in both frames, and the elbow sits more than 0.45 studs off the line in both (a straight arm has no meaningful swivel).
- **Severity:** `0.35 + 0.25 * flipRuns + worstStep / 400`.
- **Critical** ("elbow flip"): any flip step over 70 deg.
- **On screen:** the elbow jumping to the other side of the arm in one frame, usually because a per-key IK picked the other solution branch.

### 9. `R_chicken_wing` / `L_chicken_wing` (weights 4 / 3)

- **Measure:** elbow more than 0.55 studs above the shoulder pivot (chest frame) while the wrist hangs more than 0.4 below the elbow and the elbow is bent over 40 deg.
- **Fires when** that lasts 0.15 s or more. **Severity:** `min(1, duration / 0.6) * 0.6 + 0.2`.

### 10. `R_joint_offset` / `L_joint_offset` (weights 4 / 4)

- **Measure:** the largest translation keyed on any arm joint.
- **Fires when:** > 0.05 studs. **Severity:** `min(1, offset / 0.4)`.
- **On screen:** a detached or shrugged shoulder. R15 has no clavicle, so arm joints should be rotation-only.

### 11. `pops` (weight 12)

- **Measure (velocity pops):** for every joint (all 15, legs and torso included), the per-frame turn. A frame is a pop when its turn is at least 30 deg **and** either more than 3x the turn two frames before and after (with a 1 deg floor), or more than 50 deg outright.
- **Measure (acceleration snaps, arm joints only):** the change of the body-frame angular velocity vector between frames, times the rate. A snap is over 2.5 x 120,000 = 300,000 deg/s^2 (a velocity change over about 8,300 deg/s in one frame) and over 30 deg/frame^2.
- **De-duplication:** one pop per joint per 0.1 s.
- **Severity:** `0.2 * armPops + 0.1 * otherPops + worst / 150`.
- **Critical** ("arm pop"): any arm or hand pop over 50 deg in a frame.
- **On screen:** a limb teleporting to a new place in one frame; wrong-way interpolation through a big angle.

### 12. `hand_path_corners` (weight 5)

- **Measure:** for the grip path, velocity direction change between frames (deg) and relative speed change. A corner is a frame where both neighbouring speeds exceed 12 studs/s and the turn is over 50 deg or the speed changes by more than 75%. Corners are counted as runs.
- **Severity:** `min(1, cornersPerSecond / 6) * 0.7 + 0.1` (rate over the clip length, at least 0.3 s).
- Target is zero outside contact frames. The tip path is also measured but only the grip is scored.
- **On screen:** a hand that travels in straight lines between keys and turns sharp corners: robotic, not an arc.

### 13. Smoothness (reported only)

Log dimensionless jerk (LDLJ, Hogan and Sternad) of the grip and tip: `-ln(T^3 / vPeak^2 * integral |jerk|^2 dt)`. Higher is smoother. It is relative: compare a clip with itself before and after, never across clips. No bar, no weight.

### 14. `dead_offhand` (weight 8)

- **"Hard moving" frames:** smoothed (9 frames) root turn > 170 deg/s, or chest turn > 170, or sword shoulder > 320, or root travel > 12 studs/s.
- **Dead:** hard-moving, left arm speed (sum of its three joints, smoothed over 15 frames) under 45 deg/s, and the left hand **not** on the hilt (more than 1.25 studs from the hilt line, which runs from 2.2 studs behind the grip to 0.6 ahead).
- **Fires when:** there are more than 0.25 s of hard-moving frames and more than 35% of them are dead.
- **Severity:** `(deadFrac - 0.35) / 0.5 + 0.25 + 0.3 * hangingFrac` (hanging = left elbow nearly straight and the arm pointing down).
- **On screen:** a free arm hanging like a rope while the body spins and lunges.

### 15. `frozen_arm_spin` (weight 4)

- Root plus chest turning over 360 deg/s (smoothed) while the sword arm moves under 40 deg/s and is nearly straight, for 0.2 s or more. **Severity:** `min(1, duration / 0.6)`.

### 16. `mirrored_arms` (weight 4)

- **Measure:** rotation vectors of the three right-arm joints vs the left arm's mirrored (y and z negated); correlation of their frame-to-frame changes over 0.4 s windows (stepping 0.1 s) where both arms move (each over 150 deg/s for at least 70% of the window).
- **Fires when:** the best correlation r > 0.9. **Severity:** `(r - 0.9) / 0.1 * 0.7 + 0.2`.
- **On screen:** twinning, both arms doing mirror copies of each other.

### 17. `rest_flash` (weight 8)

- **Measure:** an upper arm within 8 deg of rest (and its forearm within 16) at a local minimum, with the upper arm more than 40 deg from rest at some point in the 0.2 s before **and** in the 0.2 s after.
- **Severity:** `0.5 + 0.15 * count`.
- **Critical** ("rest flash"): any.
- **On screen:** a one-frame T-pose or bind-pose flash between two poses. Classic cause: an identity key written by a solver, or a joint that loses its key and falls back to rest.

### 18. `exit_snap` (weight 4) and `entry_snap` (weight 3)

- **Measure:** the largest angle between any arm joint and the idle's pose, on the last frame (exit) and the first frame (entry).
- **Exit fires** over 75 deg: `(angle - 75) / 90 + 0.2`. **Entry fires** over 90 deg: `(angle - 90) / 90 + 0.1`.
- **Why:** the ability controller fades clips in over only 0.05 s, and when a one-shot ends the idle takes over at once. A big gap at either end reads as a snap.

### 19. `dead_hold` (weight 3)

- Sum of all joint speeds (smoothed over 5 frames) under 4 deg/s for more than 0.3 s, not at the clip's end. **Severity:** `min(1, (duration - 0.3) / 0.6) * 0.6 + 0.15`.
- **On screen:** a statue hold. 3D poses that freeze completely read as mannequins; use a moving hold.

### 20. `linear_spans` (weight 4)

- From the clip's keys (not the playback): arm-joint segments whose first key is Linear, longer than 0.12 s, turning more than 20 deg.
- **Fires when:** 3 or more. **Severity:** `min(1, count / 12) * 0.7 + 0.1`.
- **On screen:** constant speed, then a corner at every key.

### 21. Kinetic chain order (reported only)

- Strikes are tip-speed peaks over 45 studs/s (local maxima within 6 frames, at least 0.25 s apart).
- For each strike, find the speed peak of hips, chest, upper arm and forearm in the window from 0.4 s before to 0.05 s after.
- In order if each link peaks no later than the next one plus 35 ms. Reported as `chain_order_frac`. The standard it encodes: hips, chest, shoulder, elbow, wrist, blade, about one 30 fps frame per link.

### 22. Overspeed (reported only)

Joints exceeding 1.25x their `w_lim` are listed with the time. Speeds over the limit are allowed on a cut's active frames (smear territory), so this is informational.

## The score

```
score = max(0, 100 - sum over issues of (weight * severity))       -- severity in 0..1
bad   = score < 70  or  any critical
```

Weights in one table (an issue not listed would default to 3):

| Issue | Weight | Issue | Weight |
|---|---|---|---|
| arm_in_body | 20 | pops | 12 |
| R_elbow_inverted | 10 | L_elbow_inverted | 8 |
| R_elbow_flip | 10 | L_elbow_flip | 8 |
| blade_through_body | 8 | dead_offhand | 8 |
| R_wrist_range | 8 | L_wrist_range | 5 |
| rest_flash | 8 | R_wrist_snap | 6 |
| L_wrist_snap | 4 | R_elbow_sideways | 6 |
| L_elbow_sideways | 5 | R_shoulder_range | 6 |
| L_shoulder_range | 5 | hand_path_corners | 5 |
| exit_snap | 4 | entry_snap | 3 |
| R_chicken_wing | 4 | L_chicken_wing | 3 |
| R_joint_offset | 4 | L_joint_offset | 4 |
| frozen_arm_spin | 4 | mirrored_arms | 4 |
| linear_spans | 4 | dead_hold | 3 |

The weights sum to 179, so a clip with every issue at full severity bottoms out at 0 well before the sum.

**Criticals** (any one makes the clip bad regardless of score):

1. arm deep in body: penetration over 0.6 with at least 0.05 s over 0.45;
2. elbow inverted past 15 deg (either arm);
3. elbow flip over 70 deg in one frame (either arm);
4. arm pop over 50 deg in one frame;
5. rest flash.

### Worked example

A typical baseline attack clip: forearm 1.33 studs into the chest with 0.95 s over 0.45; 17 pops, the worst 105 deg; sword wrist excess 45 deg for 0.6 s; elbow flipped twice, worst 156 deg; blade through the body.

| Issue | Severity | x weight |
|---|---|---|
| arm_in_body: `0.6*(1.33-0.15)/0.6 + 0.4*1` = 1.58, clamped | 1.0 | 20 |
| pops: many arm pops | 1.0 | 12 |
| R_wrist_range: `45/60 + 0.4` | 1.0 | 8 |
| R_elbow_flip: `0.35 + 0.5 + 0.39` | 1.0 | 10 |
| blade_through_body | 0.75 | 6 |
| others (corners, exit, shoulder) | | about 15 |

Score about 100 - 71 = 29 with three criticals, which is right at the baseline median of 31.

## Baseline distribution (several hundred moves, real Animator)

| Issue | Share of moves affected | Mean severity |
|---|---|---|
| sword wrist past its range | 97% | 0.94 |
| arm or hand inside torso or head | 92% | 0.93 |
| hand path corners | 91% | 0.47 |
| pops | 90% | 0.96 |
| blade through own body | 82% | 0.75 |
| sword wrist snaps | 71% | 0.58 |
| sword / free elbow swivel flips | 65% / 65% | 0.91 / 0.91 |
| free arm behind the back | 54% | 0.84 |
| exit snap / entry snap | 49% / 42% | 0.72 / 0.58 |
| sword arm behind the back | 40% | 0.80 |
| free wrist past its range | 30% | 0.48 |
| free / sword elbow hiked | 21% / 11% | 0.58 / 0.49 |
| sparse Linear keys | 10% | 0.36 |
| sword elbow sideways | 5% | 0.52 |
| mirrored arms | 4% | 0.57 |
| dead off-hand | under 1% | 0.34 |

Headline: 93% bad, median 31, percentiles 10 / 25 / 75 / 90 = 13 / 20 / 48 / 71. About 84% of moves had an arm deeper than 0.6; about 83% had an arm pop over 50 deg.

## Verification rules for a re-baked clip

A verifier samples the baker's own after-dump through the offline Animator model at the truth rate and compares it, joint by joint, with the real Animator's playback of the test clip (the last truth frame is dropped: it is past the end, where the track has stopped).

| Rule | Pass |
|---|---|
| `model_vs_animator_maxdeg` (max over the six arm joints) | under 3 deg; up to about 5 tolerated on segments near 180 deg after checking the strip |
| `loaded` | true (false with about 117 deg error = a fresh registration that had not loaded) |
| Criticals | zero |
| Score | after >= before + 15 |
| Fidelity | blade direction mean change <= 15 deg, max <= 60 deg, in frames that mattered |

**Never install** if: the largest key-to-key arm turn (`max_key_segment`) is 120 deg or more, a new critical appeared, or the score went down.

## Known biases of the metrics

- **Blocky dummy.** Capsules use the dummy's 1.6-stud arm width. Slimmer avatars clear the body more easily than QA says, so the arm-in-body metric is conservative.
- **Generic blade.** Every weapon is modelled as the same 9.5-stud blade. Very short daggers will be flagged for blade-through-body they do not have; very long weapons are under-flagged.
- **Legs and torso** count in pops but no arm pass fixes them.
- **Kinetic chain and LDLJ are not scored**, so a clip can score 100 with an out-of-order strike. Look at strips.

## See also

[[Pipeline - Arm IK Baking and QA]], [[Arm Baker Internals]], [[Case Study - Fixing Hundreds of Attack Clips]], [[Animation Quality Standard]], [[Animation Review Checklist]], [[Elbow Poles Swivel and Joint Limits]], [[Debugging Animation Problems]]

## Connected notes
<!-- auto-links:start -->
[[Posing and Silhouettes]] · [[Troubleshooting Table]] · [[Weapon Swing Design]] · [[Spec-Driven Move Authoring]] · [[Voxel Characters - Proportions Joints and Rigging]] · Skinning Weights · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Inverse Kinematics]] · [[LihFolk R15 Keyframe Pipeline]] · [[Human Swing Biomechanics]] · [[Two-Bone IK Math]] · [[Blade Grip and Wrist Limits]] · [[Snippets - IK]] · [[Testing Animations in Studio]] · [[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]]
<!-- related:end -->
