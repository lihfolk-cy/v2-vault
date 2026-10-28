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

## Rubric note
The rubric gate "`wrist_clamped_deg` under 5" is now `qa.wrist.blade_err_max_deg` under 5 on authored keys. The solver never forces the wrist; this is how far the blade lands from the request. Auto-breakdown keys are reported separately (`breakdown_blade_err_max_deg`).

## Twist (added 2026-10-28, user: "the arm does a lot of random twists")
- Per-key independent wrist/elbow solves re-twist the arm between keys (measured 42-73 deg/frame, 4-7 reversals per swing). Use continuity costs + `Clip.cut()` planned monotonic forearm twist and upper-arm roll, and `_sword.lead(c)` (chest +1, arm +2 frames).
- Measure roll as the intrinsic angular velocity about the bone axis (`qa.arm_twist`), not swing-twist angles.
- Fewer arm keys inside the 3-5 frame strike: each extra key is a chance for a counter-roll. Open problem: Light1/Light2/Light3/Dash still show 1-6 reversals after planning.
- Keep a copy of every previous sheet/MP4/module before rebuilding (`Animations/_compare/_vN/`) so before/after comparisons stay possible.
