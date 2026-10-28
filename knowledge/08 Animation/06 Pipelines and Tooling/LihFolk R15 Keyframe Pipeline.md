---
tags: [animation, pipeline, blender, r15, keyframe, export, qa, lihfolk]
---
# LihFolk R15 Keyframe Pipeline

How LihFolk authors original R15 animations in Blender by script, checks them automatically, and exports them for Roblox. It exists because hand-wired AI keyframing tends to produce stiff, clipping "slop". Every guard below catches a specific failure seen in real test clips.

## 1. The rig

- **Built from measurements, not downloads.** The default R15 block rig at scale 1 was measured read-only in Studio (joint attachment positions, part sizes; hip height 2.1924 studs), and the joint names and hierarchy follow the Creator Docs character spec (**Measured**; **Roblox docs**).
- **Axes.** Roblox (x, y, z) maps to Blender (-x, z, y). One matrix `A` handles both directions because it is its own inverse.
- **Rotation convention.** Pose values are degrees, R = Rx · Ry · Rz in the **parent part's frame**, exactly like a `Motor6D.Transform` written with `CFrame.Angles`. `rx > 0` swings a hanging limb forward, `ry > 0` turns left, `rz > 0` raises the right side.
- File: `Animations/_rig/LihFolk_R15.blend`, with `rig_spec.json` (sizes, joints, grip).

## 2. Authoring

- Clips are Python modules (`tools/anim/clips/<name>.py`) that build a `Clip` from **key poses**: dictionaries per joint, plus an ease per key (`smooth`, `snap`, `launch`, `flat`, `linear`, `hold`). Keys become Bezier F-curves with real handles, never linear interpolation.
- **Limbs aim, not rotate.** `aim(direction, twist)` swings an upper arm or leg to point along a direction in its parent's frame, which is far easier to pose well than raw Euler angles.
- **Overlap.** `offset(joints, n)` delays the head, off-arm or forearm by 1-3 frames so the motion leads from the torso.
- **Feet.** `FootTrack` keys ankle targets with heel and toe roll and lift arcs. An analytic two-bone IK bakes the legs per frame, so planted feet don't slide.
- **Blades.** `blade_aim({frame: direction})` solves the hand with forearm twist plus a wrist bend capped at +-50 degrees (see [[Blade Grip and Wrist Limits]]).
- **Markers.** `marker(frame, name, value)` becomes real `KeyframeMarker`s (`Hit`, `ComboWindow`, `TrailOn`, `TrailOff`, `Footstep`).

## 3. Automatic QA (written into each clip's JSON)

| Check | Catches | Pass |
|---|---|---|
| `foot_slide_studs` | Skating feet on planted frames | under 0.02 (Measured walk 0.0001, run 0.000) |
| `lowest_body_point_studs` | Body parts sinking through the floor | above -0.05. Many clips still read -0.1 to -0.4 on the shin; **Unverified** whether that is the block preview's box corner or real penetration |
| `ik_unreachable_max_studs` | Foot targets the leg can't reach (hyper-extension) | 0 |
| `wrist_clamped_deg` | Blade targets beyond anatomical wrist range | under 5 per key |
| `motor6d_fk_check_max_err_studs` | Export mismatch between Blender and Roblox joint maths | 0 |

Planned, not built yet: a **body-overlap check** (limb boxes through the torso or head). It is the main remaining cause of "broken" poses.

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

Honest status: walk, jump, hit react and SwordSlash are near the bar. Run, idle, slam, death and the 3-hit combo need another pass.

## Common mistakes

- Linear interpolation or every key on the same ease: robotic timing.
- Keying every joint on the same frame: no overlap, so the motion looks stiff.
- Animating feet with FK: foot sliding.
- Solving weapon hands with unconstrained rotations: wrist flips.
- Judging a clip from one camera angle.
- Assuming an FBX import worked without checking it on the rig in Studio.

## Checklist

- [ ] Clip built from strong key poses with mixed eases
- [ ] Overlap offsets on head, off-arm and forearm
- [ ] Feet on `FootTrack`; slide under 0.02 studs
- [ ] `wrist_clamped_deg` under 5; no limbs through the body on the sheet
- [ ] `.rbxmx` + `.json` + preview exported; markers present
- [ ] Imported and played once in Studio before calling it done

## See also

- [[Blade Grip and Wrist Limits]]
- [[Weapon Swing Design]]
- [[Custom Rigs - Weapons and Props]]

## Connected notes

[[Animation Start Here]] · [[Blade Grip and Wrist Limits]]
