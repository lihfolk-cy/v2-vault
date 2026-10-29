# Recipes: animation (shipped defaults; the project ledger refines these)

## First-pass defaults
- Pose **key poses first** (windup, contact, follow-through), each with a clear silhouette in three-quarter **and** side view, before adding in-betweens.
- Mix eases: `launch` into the action, `snap` on contact, `flat` on holds, `smooth` on recoveries. Never all `smooth`, never linear.
- Overlap: head and off-arm +2 frames, forearm and hand +1 frame behind the upper arm. Locomotion: shoulder +1, elbow +2, hand +3.
- Feet on `FootTrack` with IK; plant feet, never FK-animate them.
- Weapon clips: author with `Clip.skey` (torso pose + wrist target + blade direction). Rotate the **torso** into the swing so the arm never crosses the chest.
- Arm targets in **torso space** (`rhl`/`lhl`) so hip drops and chest turns don't push hands above the shoulder line.
- Sword preview: 3/4 camera on the side the cut finishes toward (`3qL` for right-handed forehand cuts) + front + side.

## Pre-empt (measured first-draft misses)
- Blade keys the wrist can't reach: the blade must sit 25-75 deg off the shoulder-to-hand line on the thumb side (60 deg grip, ulnar 38 / radial 20). In-line blades (thrust or contact along the arm) fail. Check `qa.wrist.blade_err_max_deg`.
- Hands closer than ~1 stud to their own shoulder (wind-ups): the 1-stud R15 hand box enters the upper arm. Keep wind-up hands 1.2+ studs out.
- In-betweens through the chest on recoveries and backhands: the solver inserts breakdowns, but check `worst_pairs` (depth@frame) and add a hand-out-front key if needed.
- Pelvis pitched forward for lean (lunges, runs): the front or swing knee jams into the pelvis. Lean with the chest; pelvis pitch 8 deg or less.
- Running swing-foot lift above ~0.45 studs: shin into the pelvis. Use 0.3-0.45 and `z_bias` 1.8.
- Head yaw over ~40 deg relative to the chest: head corner into the shoulder cap.
- Arms raised past ~100 deg abduction (jump, celebration): upper-arm cap into the head.
- Locomotion at WalkSpeed 16 authored as a walk: it slides. 16 studs/s = a run for R15 legs (8 f/step).
- Edge not leading on backhands and holds (`edge_err` 60-120): give contact and hold keys explicit `edge=` with `edge_w=0.8`.
- Weight shift / breath too subtle to read on a sheet (idle): pelvis shift 0.2 studs, roll 6 deg.

## Proven fixes
| Miss | Fix |
|---|---|
| Wrist flips or blade through the head | `skey` + `lihanim/sword.py` (swivel + anatomical wrist + collision search) |
| Floaty | Lower the hips on contact, add a 2-3 frame hold, snap the ease into contact |
| Stiff | Add offsets (head and off-arm +2) and arcs on the hands |
| IK unreachable on gait contact | Shorter stance travel (stride x duty under ~2.6 studs) or lower the pelvis 0.04 studs on contact |
| Foot skate on dash/jump | Feet airborne until the root stops; `root_in_measure = True`; take off with a toe pivot |
| Thighs crossing in a staggered stance | Widen foot x to about +-0.75 |
| Arm re-twists inside a swing (gate) | `Clip.cut()` + `twist_dp` per-frame replan; windup posed so the roll is one-way (proven on Heavy, Light1, Light2, Light3, Dash: reversals to 0) |
| Head into the off shoulder at contact | Head yaw no more than 36 deg from the chest (Dash: Head/LeftUpperArm 0.058 -> 0.012) |

## Rubric note
The rubric gate "`wrist_clamped_deg` under 5" is now `qa.wrist.blade_err_max_deg` under 5 on authored keys. The solver never forces the wrist; this is how far the blade lands from the request. Auto-breakdown keys are reported separately (`breakdown_blade_err_max_deg`).

## Twist (added 2026-10-28, user: "the arm does a lot of random twists")
- Per-key independent wrist/elbow solves re-twist the arm between keys (measured 42-73 deg/frame, 4-7 reversals per swing). Use continuity costs + `Clip.cut()` planned monotonic forearm twist and upper-arm roll, and `_sword.lead(c)` (chest +1, arm +2 frames).
- Measure roll as the intrinsic angular velocity about the bone axis (`qa.arm_twist`), not swing-twist angles.
- Fewer arm keys inside the 3-5 frame strike: each extra key is a chance for a counter-roll.
- Keep a copy of every previous sheet/MP4/module before rebuilding (`Animations/_compare/_vN/`) so before/after comparisons stay possible.

## Twist, solved (2026-10-28, v4): plan the roll per frame, not per key
- Per-key planning is not enough: Blender interpolates each joint's quaternion separately, so counter-rolls appear BETWEEN keys. `lihanim/twist_dp.py` runs after baking (automatic when the clip declares `Clip.cut()`). It keeps the wrist path and blade direction of every frame and re-plans only the elbow swivel (rigid rotation about the shoulder-wrist line) and the forearm pronation. Each is a Viterbi path over states, one roll direction per segment (windup->contact->follow-through, then recovery). Wrist dev/flex come in closed form from the pronation, and the arm is keyed on every frame. Result: 0 reversals in swing on all 5 cuts (were 1-6) and right-arm reversals total 1-2 (were 6-9).
- A windup that rolls the forearm against the strike can't pass the gate. Pose the windup like SwordHeavy (hand forward of the shoulder, `rhl=(1.95,4.4,-0.9)`, `rpole=(1,-0.4,-0.2)`, blade `(0.2,0.6,0.77)`) so the swing pronates or supinates one way.
- Blade directions are in character space. When the body leans (dash crouch -20..-28 deg), rotate the authored blade by the same pitch or the wrist leaves its cone (Dash key 4: blade_err 10.7 -> 4.2).
- Contact blades that cross the body or point down (`y < -0.1` at chest height) hit the dev -38 / pro -85 limits (blade_err 7-10). Keep contact blades within about 20 deg of forward and get the diagonal from the hand path and the torso turn.
- Diagnose with the per-key line `blade_err0 + replan_blade_dev / pro, dev, flex`: a key at a limit (pro -85, dev -38/+20, flex -60) is the one to re-pose. Tuning knobs: `clip.twist_w_swivel` (0.004 = let the elbow swing more; 0.03 default), `clip.twist_dirs`.
- `qa.lowest_body_point` of -0.2..-0.4 on staggered stances is the rear shin box's ankle-end corner, not the knee (`qa.knee_min_height_studs` >= 0.8). Reviewers read it as a knee in the floor, so point them at the knee field.
- Blind reviewers (sheet + JSON only) score about 2 points below the earlier maker-assisted scores. All 11 v4 clips land 5.3-7.0. Recurring misses: contact pose not extended at chest height (sword), the follow-through not continuing the arc, locomotion too subtle (no lateral hip shift, no visible flight frame), and arms covering the torso in side view.

## v5 (2026-10-28): readable locomotion + extended sword contact (3-reviewer panel scores)
- Evidence the reviewer can use: `qa_motion` in every Locomotion JSON (pelvis lateral/bob, pelvis vs chest yaw, flight frames, elbow bend, shoulder swing; `measure.motion_metrics`), `c.sheet_labels` (pose names on the sheet) and `c.plumb = True` (red centreline behind the character in the front view). Write the intent with the measured numbers; reviewers check them and penalise any claim the JSON contradicts.
- Run/Sprint flight (proven: Run 5.3 -> 8.3, Sprint 5.3 -> 7.7): `gait.locomotion_track(..., rise_power=0.6, drop_power=0.3, kick_z, kick_y, kick_peak)`. The foot leaves fast, stays up and lands late, so both feet are 0.3+ studs up for 3 frames. Run duty 0.30 (toe pushes until f4), heel kick `kick_z=0.72`; Sprint `kick_y=0.6, kick_z=0.3, kick_peak=0.22` folds the heel up. `reach_z` above ~0.15 jams the shin into the pelvis.
- Pitched chest + yaw tilts the shoulder line (Sprint chest roll 15 deg): add an opposite chest roll of ~sin(pitch) x yaw per key (15 -> 6 deg).
- Arm swing on a leaned torso: forward lean shifts the swing backward in world space by about the lean, so author forward +40..56 / back -40..-48. Elbow opens behind (55-60) and closes in front (100-105) so the forearm whips.
- Walk: pelvis 0.2 lateral + 5 deg hip drop + chest counter-tilt. Keep head lateral below pelvis lateral or reviewers call it a waddle. Still 7.3: passing/up silhouettes and even spacing remain.
- Idle (6.3 -> 8.3): pelvis 0.25 + roll 7, breath 8 deg chest + arms out 10, a 0.1 anticipation sink, a 0.06 overshoot, a 3-frame snap glance held about 14 frames, and the two arms on different offsets (5-9 vs 9-14 f).
- Sword contact extended at chest height (Light1: contact blocker fixed, 7.0 -> 7.7): the forehand cut must PRONATE (`c.cut(0, 15, 1)`), so the windup is a high raise (blade ~(0.15, 0.92, 0.25), reachable near neutral pronation), not a supinated cock behind the shoulder. Contact hand in front of the right shoulder (`rhl=(0.95, 4.15, -1.55)`, `move=0.15` so the solver can't drag it down). Blade carried across (`(-0.95, -0.12, -0.28)`) with `pro=(44, 70)`. Follow-through: turn the torso to ~57 deg and keep the hand in front of the right chest (`(0.9, 3.25, -1.5)`, `pro=(50, 80)`); a hand crossing the body always clips the forearm into the chest. Needs `c.twist_cap = 60` and `c.twist_contact_cap = 60` (the burst lands inside Hit-1..Hit+1, so the gate allows it).
- Pick reachable blades before authoring: `_work/v5/reach.py` maps blade_err over azimuth/elevation for a pose, hand and `pro` band. `skey` now takes `pro=(lo, hi)`, `move=` and `edge_w=`.
- (Solved in v6 for forehands, see below.) The true edge did not lead at contact under the wrist cone (edge_err 50-68).
- Scoring: single reviewers swing 1.5-2.3 points (Walk 6.0/7.0/8.0, Sprint 6.0-8.3). Only the 3-reviewer median decides.

## v6 (2026-10-28): grip roll, side-view arms, classic walk (3-reviewer panel medians)
- **Edge lead is solved at the grip, not the wrist.** `rig.TOOL_GRIP_ROLL_Y = 45` rolls the handle 45 deg about its own axis (blade unchanged, true edge rotated). In-game: `Tool.Grip = CFrame.Angles(0, math.rad(-45), 0) * CFrame.Angles(math.rad(30), 0, 0)` (= `CFrame.fromEulerAnglesYXZ(math.rad(30), math.rad(-45), 0)`; Handle = Hand * RightGripAttachment * Grip:Inverse()). Measure with `qa.edge_lead` (angle between the true edge and the blade's travel on the baked motion; signed_deg says which way to roll). Sweep (`LIH_GRIP_ROLL`, `LIH_TEST_OUT=1`): per-clip optimum roll is +45..65 for forehand across-the-body contacts (Light1, Heavy), about 0 for Dash, and -10..-45 for the falling backhand (Light2) and a vertical chop. No single roll fits all; +45 + re-authored cuts: Light1 edge 51 -> 17 (fast-frame mean), Heavy 38 -> 22-28, Light3 37 -> 18, Dash 23 -> 29, all wrist/twist gates pass.
- With a rolled grip, set `c.edge_w_default = 0.1` (blade first; the grip presents the edge) and move the strike key's `pro` band up (Light1 f6: (0,15) -> (30,60)). Forcing `edge_w` on the guard (0.3) breaks every cut's windup (blade_err 5-8, reversals).
- Under +45 the falling backhand cannot lead with either edge (pro pins at +80, lead 54-70): Light2 needs a redesign (rising backhand or forehand variant). A vertical chop needs supination past -85: re-author it as a steep forehand diagonal (Light3 v6).
- One-frame blade flips (strike key -> contact key 1 frame apart, ~120 deg of blade rotation) read as a wrist pop (P5) and leave the fast frames with the flat leading. Give the strike 2 frames (Light1 contact key 7 -> 8): hand roll 74.5 -> 54 deg/f, edge 23.5 -> 17. A pre-roll key alone did nothing.
- Side camera on the side the cut finishes (`views = ["3qL","front","sideL"]`) shows the follow-through blade; the contact blade still foreshortens end-on (P1 note in every panel).
- Run side view (8.3 -> 9.0): the cheapest lever is shoulder counter-yaw, not arm angles. Chest yaw +-12 -> +-20 raised visible side-view torso by ~60% (pixel count), arms -68/+62 with elbows 65 back / 92 front and abduction 20 added the rest. Mid-swing frames (flight) still stack the arms: P1 stays 1 in a pure side view.
- Walk (7.3 -> 8.7): classic keys contact f0 / down f2 (flat) / passing f6 / up f10 (flat) per 12-frame step: the pelvis rises 8 frames and falls 4 (not a sine). Heel peel at the up key: `s_rise=0.4, toe_pitch=-52`. The chest roll must lean TOWARD the swing side (+2 local at passing with the pelvis +5): the opposite sign doubled head sway (0.48 -> 0.78); right sign 0.48 -> 0.11. P7 is always 1 at native 5.5 studs/s (ship AdjustSpeed(WalkSpeed/5.5)).
- Idle (stuck at 8.3 after 3 rounds): heel peel on the free leg and a hand-on-hip beat (keyed AFTER the overlap offsets, with an outward drop key on the way back, or the hand passes through the ribs, 0.14) made two keys read, but the 3/4 game camera still sees f0/f34/f50/f56 as one shape. Breath-driven arm abduction makes the hands LEAD the weight shift (hand_lateral peak before the pelvis): couple arm roll to pelvis roll at 0.2, not 0.6, and key the trail explicitly. Panels want 0.3-0.4 studs of hand trail and a hand that touches the hip (abduct the arm, wrist at the pelvis side).
- QA additions: `qa_motion.summary.hand_lateral_rel_shoulder_studs` (range + peak frames per hand, vs `pelvis_lateral_max/min_at_frame`), `qa.edge_lead`, `qa.wrist.edge_err_strike_keys_max_deg` + `edge_note` (guard keys ask for edge-down at low weight; reviewers misread the all-keys max).
- Single reviewers over-score by ~0.7 on sword clips (Light1 8.7 single -> 7.7 panel; Idle 9.0/9.0 singles -> 8.3 panels). Only the panel median decides.

## v7-v8 (2026-10-29): general lessons (vault: "Locomotion Clip Lessons - Jump, Sprint, Idle", "Spin and Whole-Body Rotation Moves", "Arm Twist and Grip Roll", field note "Blind Review Scores")
- **Triage first.** Quick fixes work only for local flaws with a working example elsewhere (Sprint 7.7 -> 9.0 by porting Run's arm extremes back -70/front +66, elbows 62/95, abduction 18, chest counter-yaw -20..16). Global flaws (idle silhouettes, jump arm design) need re-authored keys; two fix rounds with delta 0 on a criterion = stop tweaking.
- **Wrist pop = roll forced into one frame** because each key pins roll near its own blade need. Pre-pronate in the windup/hang (invisible there), remove the separate strike key, lay the contact blade mid-roll, finish the roll after contact (SwordLight3 7.7 -> 8.7, hand roll 54.8 -> 21.1 deg/f, 0 reversals).
- **Per-clip grip roll** when the shared +45 blocks a cut (dash: wrist at its ulnar limit): `GRIP_ROLL = <deg>` in the clip module (PIPELINE.md 2E); JSON gets `tool_grip_roll_deg`; game code must set the matching `Tool.Grip` while the track plays and restore it after.
- **Blade readability beats edge accuracy.** Dash redesign (level cut, perfect edge lead, roll 20) scored 5.7 (was 7.7): the thin edge faced the raised 3/4 camera and vanished at Hit; a follow-through pointing at the camera read as dropping to the floor. Show the flat to the game camera, accept 15-30 deg edge error, keep the sword arm from crossing the torso in front view after contact, pull the off arm clearly back.
- **Jump (8.3, owner-approved):** arms lead the push-off (back f2, down f3, forward f4, forward-up at takeoff f5); air arms forward -> forward-down, never wide/overhead; bent elbows in air read as hands by the head (v5 7.3, reverted); pelvis held up until contact or feet sink; landing recovery ~13 f for Action priority.
- **Idle:** breath in chest/shoulders (arms in torso space), not arms; distinct key silhouettes from the 3/4 camera (glance 35-45 deg + chest ~10, deeper hip drop); sword guard blade off the centre line in front view; no big low blade drops (attack tell); 4-5 s for two big beats (3.2 s too short).
- **Whole-body rotation (spins, flips):** key the Root joint every frame (fixed composition order); the game must not rotate the HRP (AutoRotate off). Accelerating turns (8/7/6 f per turn); hips over the support foot; extended weapon arm. Mid-air twists clump into boxes in 3/4: extended, separated limbs, camera facing the twist plane, slowed half-twist beat. Flight 22 f / 4.8 studs = floaty, try ~18 f / ~4. Judge poses in the views (pitched chest makes rear arms read forward). Backflips travel back: record `end_offset_studs`, game shifts the HRP after the clip. R15 forearm cannot cross the chest: `c.overlap_exempt` (arms only, airborne frames, PIPELINE.md 4); `c.preview_only_objects` for preview helpers.
- **Scoring:** singles run ~1 point high; two panels can differ by ~1. Back up every scored version, ship the best panel score, catalogue shows the latest panel score of the shipped version.
