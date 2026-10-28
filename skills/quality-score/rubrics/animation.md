# Rubric: animation clip (R15)

Source: knowledge notes `LihFolk R15 Keyframe Pipeline`, `Blade Grip and Wrist Limits`, `Weapon Swing Design`. Read the QA block from the clip's JSON and look at its `_sheet.png` (three-quarter and side views).

## Hard gates
- Foot slide on planted frames under 0.02 studs
- `ik_unreachable_max_studs` = 0
- `motor6d_fk_check_max_err_studs` = 0 (export matches)
- No body overlap deeper than 0.05 studs (limbs through torso or head), if the overlap check exists
- `wrist_clamped_deg` under 5 on every blade key (weapon clips)
- Loop clips: first frame equals last frame; priority set
- Arm twist (weapon clips, `qa.arm_twist`): sword-arm roll rate 25 deg/frame or less outside the contact frames (Hit -1 to Hit +2), and `right_arm_reversals_in_swing` = 0 (sign changes of the roll rate about the segment's own axis inside TrailOn-3 .. TrailOff). Source: Human Swing Biomechanics.

## Criteria (0 / 1 / 2)
| # | Criterion | W | 0 | 1 | 2 |
|---|---|---|---|---|---|
| P1 | Key poses read as clear silhouettes in both views | 3 | muddy | some clear | every key reads |
| P2 | Timing and spacing (eases, holds, snaps) | 3 | linear or even | some contrast | punchy, intentional |
| P3 | Anticipation, then action, then follow-through | 2 | missing | weak | clear |
| P4 | Weight (hips over support, believable mass) | 2 | floaty or off balance | ok | grounded |
| P5 | Overlap and arcs (torso leads, limbs trail, curved paths) | 2 | everything moves at once | some | fluid arcs |
| P6 | Contact (feet plant, blade edge leads, hit frame sells impact) | 2 | none | partial | sells it |
| P7 | Fits gameplay (length, markers, readable at game camera distance) | 1 | wrong | ok | ideal |

Evidence: the JSON QA numbers, the contact sheet, and the MP4 preview.
