---
tags: [animation, pipeline, blender, r15, keyframe, export, qa, lihfolk, type/guide, area/animation, level/intermediate, area/modeling]
---
# LihFolk R15 Keyframe Pipeline

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Linear interpolation or every key on the same ease: robotic timing.
> - Avoid: Keying every joint on the same frame: no overlap, so the motion looks stiff.
> - Avoid: Animating feet with FK: foot sliding.
> - Clip built from strong key poses with mixed eases
> - Overlap offsets on head, off-arm and forearm
> - Feet on `FootTrack`; slide under 0.02 studs
>
> Cost: TL;DR ~130 tok · whole note ~2.1k tok. Read more: ## 2. Authoring · ## 3. Automatic QA (written into each clip's JSON) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

How LihFolk authors original R15 animations in Blender by script, checks them automatically, and exports them for Roblox. It exists because hand-wired AI keyframing tends to produce stiff, clipping "slop". Every guard below catches a specific failure seen in real test clips.

## 1. The rig

- **Built from measurements, not downloads.** The default R15 block rig at scale 1 was measured read-only in Studio (joint attachment positions, part sizes; hip height 2.1924 studs), and the joint names and hierarchy follow the Creator Docs character spec (**Measured**; **Roblox docs**).
- **Axes.** Roblox (x, y, z) maps to Blender (-x, z, y). One matrix `A` handles both directions because it is its own inverse.
- **Rotation convention.** Pose values are degrees, R = Rx · Ry · Rz in the **parent part's frame**, exactly like a `Motor6D.Transform` written with `CFrame.Angles`. `rx > 0` swings a hanging limb forward, `ry > 0` turns left, `rz > 0` raises the right side.
- File: `Animations/_rig/LihFolk_R15.blend`, with `rig_spec.json` (sizes, joints, grip).

## 2. Authoring

- Clips are Python modules (`tools/anim/clips/<name>.py`) that build a `Clip` from **key poses**: dictionaries per joint, plus an ease per key (`smooth`, `snap`, `launch`, `flat`, `linear`, `hold`). Keys become [[Bezier Curves|Bezier]] F-curves with real handles, never linear interpolation.
- **Limbs aim, not rotate.** `aim(direction, twist)` swings an upper arm or leg to point along a direction in its parent's frame, which is far easier to pose well than raw Euler angles.
- **Overlap.** `offset(joints, n)` delays the head, off-arm or forearm by 1-3 frames so the motion leads from the torso.
- **Feet.** `FootTrack` keys ankle targets with heel and toe roll and lift arcs. An analytic two-bone IK bakes the legs per frame, so planted feet don't slide.
- **Arms by target.** `body(..., rh=/rhl=, lh=/lhl=)` solves each arm with two-bone IK to a wrist target in character space or torso space (`arm_ik`). Torso-space targets keep the arm shape when the hips drop or the chest turns.
- **Swords.** `skey(frame, ease, torso pose, hand target, blade=, edge=)` hands the whole sword arm to `lihanim/sword.py`, which:
  - searches the elbow swivel and small hand nudges;
  - solves an anatomical wrist (forearm twist, deviation, flexion inside measured limits);
  - points the edge along the cut;
  - rejects arm, blade and pommel positions inside the torso or head;
  - inserts breakdown keys where an in-between would pass through the body.
  
  The grip is `Tool.Grip = CFrame.Angles(math.rad(30), 0, 0)`, blade on Handle +Y, true edge on Handle -Z. See [[Blade Grip and Wrist Limits]].
- **Locomotion.** `clips/_loco.py` + `lihanim/gait.py` build in-place cycles whose planted foot moves back at exactly the ground speed. See [[Locomotion and Melee Reference Numbers]].
- **Markers.** `marker(frame, name, value)` becomes real `KeyframeMarker`s (`Hit`, `ComboWindow`, `TrailOn`, `TrailOff`, `Footstep`).

## 3. Automatic QA (written into each clip's JSON)

| Check | Catches | Pass |
|---|---|---|
| `foot_slide_studs` | Skating feet on planted frames | under 0.02 (Measured walk 0.0001, run 0.000) |
| `lowest_body_point_studs` | Body parts sinking through the floor | above -0.05. Many clips still read -0.1 to -0.4 on the shin; **Unverified** whether that is the block preview's box corner or real penetration |
| `ik_unreachable_max_studs` | Foot targets the leg can't reach (hyper-extension) | 0 |
| `wrist.blade_err_max_deg` | Blade keys the anatomical wrist can't reach (the wrist is never forced) | under 5 on authored keys |
| `body_overlap.body_max_studs` | Limb boxes through the torso, head or other limbs (oriented-box test, every frame, non-adjacent pairs, beyond the rest-pose contact + 0.02) | under 0.05 |
| `body_overlap.blade_max_studs` | Preview blade or pommel through the body | under 0.05 |
| `body_overlap.hip_region_max_studs` | Thigh top corners in the chest / crotch (joint region of the block rig, hidden) | report only |
| `motor6d_fk_check_max_err_studs` | Export mismatch between Blender and Roblox joint maths | 0 |

**Overlap check details (Measured).**
- Leg boxes are checked between their joint pivots. The thigh's 0.21 studs above the hip and the shin's 0.24 above the knee sit inside the neighbouring part.
- The two thighs are compared on their lower 60%.
- `worst_pairs` lists the deepest pairs as `depth@frame`, so you know which key to fix.

## 4. Exports per clip

- `.rbxmx`: a Roblox `KeyframeSequence` with exact joint transforms, `Loop`, `Priority` and `KeyframeMarker`s. This is the **lowest-risk** import path.
- `.fbx`: armature only, FBX unit scale, forward -Z / up Y, no leaf bones, baked at 30 fps. Axis and root-bone naming still need a one-time Studio test (**Unverified**).
- `.json`: name, fps, frames, loop, priority, markers (frame and time), and the QA block above.
- `.mp4` preview and `_sheet.png` key-pose sheet (three-quarter and side views) so a person or AI can judge the motion before using it.
- Size: about 1 MB per clip with previews and source, about 0.5 MB for the game files alone (**Measured**).

## 5. Getting it into a game

1. Studio: insert the `.rbxmx` (or import the FBX onto an R15 rig in the Animation Editor).
2. Publish it to Roblox to get an `AnimationId`. That is a user step; never invent ids.
3. Load it on `Humanoid.Animator`, set priority from the JSON, and connect markers with `track:GetMarkerReachedSignal("Hit")` for hitboxes and VFX.

## 6. Quality bar

A clip ships only when:
- every QA number passes;
- the key-pose sheet shows clear silhouettes with no limbs through the body;
- it reads correctly from three-quarter and side views;
- for anything shipped publicly, the council grades it A.

Previews show three views for sword clips: three-quarter from the front-left (the side cuts finish toward), front, and side. The block hand is swapped for a preview-only fist around the handle; the exported rig stays standard R15.

**Status (2026-10-28).** The rebuilt set passes every automated gate: Idle, Walk, Run (16 studs/s), Sprint (26), Jump, SwordIdle, SwordLight1-3, SwordHeavy, SwordDashSlash and SwordParry. Their judged scores are in the quality ledger (`Animations/.lihfolk/ledger.jsonl`). The older SwordSlash, SwordCombo3, GroundSlam, DodgeRoll, Death, HitReact and DanceGroove predate the overlap check and the new grip, so treat them as drafts.

## Common mistakes

- Linear interpolation or every key on the same ease: robotic timing.
- Keying every joint on the same frame: no overlap, so the motion looks stiff.
- Animating feet with FK: foot sliding.
- Solving weapon hands with unconstrained rotations: wrist flips.
- Judging a clip from one camera angle.
- Assuming an FBX import worked without checking it on the rig in Studio.
- Forgetting that dropping the hips lowers the shoulders. A hand target written in character space then ends up above the shoulder line. Use torso-space targets (`rhl`).
- Hands closer than about 1 stud to their own shoulder. The 1-stud R15 boxes fold into each other.
- Pitching the pelvis forward for lean. Lean with the chest; a pitched pelvis drops onto the swing knee.

## Checklist

- [ ] Clip built from strong key poses with mixed eases
- [ ] Overlap offsets on head, off-arm and forearm
- [ ] Feet on `FootTrack`; slide under 0.02 studs
- [ ] `wrist.blade_err_max_deg` under 5; `body_overlap` body and blade under 0.05
- [ ] `.rbxmx` + `.json` + preview exported; markers present
- [ ] Imported and played once in Studio before calling it done

## See also

- [[Blade Grip and Wrist Limits]]
- [[Weapon Swing Design]]
- [[Custom Rigs - Weapons and Props]]
- [[Locomotion and Melee Reference Numbers]]

## Connected notes

[[Animation Start Here]] · [[Blade Grip and Wrist Limits]]

<!-- related:start -->
## Related
[[Human Swing Biomechanics]] · [[R15 Run Cycle Key Poses]] · [[Locomotion Readability - Lessons from Blind Panels]] · [[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]] · [[Pipeline - Arm IK Baking and QA]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Arm QA Metrics Reference]] · [[Snippets - IK]]
<!-- related:end -->
