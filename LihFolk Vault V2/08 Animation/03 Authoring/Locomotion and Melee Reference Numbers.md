---
tags: [animation, authoring, locomotion, gait, combat, melee, timing, hit-stop, parry, r15, reference, type/reference]
---
# Locomotion and Melee Reference Numbers

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Authoring the default-speed locomotion as a walk: it slides at 16 studs/s.
> - Avoid: Copying real running knee angles onto R15 boxes: the shin enters the pelvis.
> - Avoid: Light attacks shorter than 8 f of startup in PvP: nobody can react to them.
> - Ground speed in the clip JSON matches the `WalkSpeed` it's played at (foot slide 0)
> - Run lift 0.3-0.45 studs; pelvis pitch 8° or less; lean in the chest
> - Light attack: hit on f6-8, ComboWindow ~f15 of 24
>
> Cost: TL;DR ~160 tok · whole note ~1.6k tok. Read more: ## 2. Locomotion targets · ## 3. Melee timing (30 fps) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The numbers to start from when keying a walk, run, sprint, jump or sword attack for a default-scale R15 character, and what they become at 30 fps. Gait biomechanics and fighting-game frame data say what real bodies and good games do. The R15 conversion covers what changes on a 5.5-stud character with short legs. Full citations are kept in the maintainer's research notes, outside this vault.

## 1. R15 proportions change the gaits

- **Units.** 1 stud = 0.28 m (**Roblox docs**). Default `WalkSpeed` is 16, `JumpHeight` 7.2, gravity 196.2 studs/s².
- **Short legs.** The hip joint sits 2.19 studs up: leg length is 0.40 of body height, against about 0.53 in adults.
- **16 studs/s is a run for this body.** It works out to 7.3 leg lengths per second, the proportion of a human fast run (**Rule of thumb**, derived). A walk can't fill 16 studs/s without foot slide.
  - Walk: author it at its own speed (LihFolk Walk: 5.5 studs/s) and either set `WalkSpeed` to that or `AdjustSpeed(WalkSpeed / 5.5)`.
  - Run: the default 16 studs/s gets a run, which is also what the default R15 Animate script plays there.
- **No foot slide.** A planted foot must move back exactly `WalkSpeed / 30` studs per frame: 0.533 at 16 studs/s, 0.867 at 26.

## 2. Locomotion targets

| Gait | Human data | LihFolk R15 at 30 fps |
|---|---|---|
| Walk | 100-115 steps/min, stance 60-62%, hip 30° flexion at contact, knee 15-18° in loading and 60° in swing, ankle 20° plantarflexion at toe-off, pelvis ±4° rotation/drop, ~5 cm bob, shoulder swing ~25-30° total (**Source-backed**) | 12 f/step, 4.4-stud stride, stance 55%, pelvis bob 0.23 studs, pelvis yaw ±7°, chest counter-yaw ±11°, shoulder -24/+26° |
| Run (jog) | 160-180 steps/min, stance ~31%, hip 44-61° peak flexion, swing knee 94-119°, 6-10 cm bob (**Source-backed**, Fukuchi; Mann 1980) | 8 f/step at exactly 16 studs/s (8.53-stud stride), stance 26%, bob 0.36 studs, ~15° total lean, elbows 72-92° |
| Sprint | ~276 steps/min, contact 0.10 s against 0.11 s flight, stance ~22%, thigh lift ~70° (**Source-backed**) | 6 f/step at 26 studs/s (10.4-stud stride), stance 22%, ~24° total lean, shoulder -55/+65°, elbows 85-100° |
| Jump | Landing knee flexion 59° (stiff) to 88° (soft); load peaks ~0.07 s after touchdown (**Source-backed**) | Takeoff on f5, 16 f airborne (apex at 8 f), 3 f absorb to ~80° knees, 2 f hold, recover by f33 |

**R15 block-rig limits found by the overlap check (Measured).**
- **Knee lift.** Swing-foot lift above ~0.45 studs at run cadence folds the shin into the pelvis box. Keep running lift at 0.3-0.45 studs and the foot behind the hips longer (`z_bias` 1.8).
- **Lean.** Lean with the **chest**, not the pelvis. A pelvis pitched more than ~8° drops its front edge onto the swing knee.
- **Stance travel.** Keep stance travel (stride x stance fraction) under ~2.6 studs, or the IK can't reach the heel strike.

## 3. Melee timing (30 fps)

| | Wind-up | Strike | Active | Follow-through | Recovery | Total |
|---|---|---|---|---|---|---|
| Light, research (**Expert practice**) | 3-5 | 2 | 2-3 | 3-4 | 6-10 | 18-24 |
| LihFolk SwordLight1/2 | 0-4 (+breakdown f2) | 4-7 | hit f7 | 7-13 (hold to 13) | 13-24 | 24 |
| Heavy, research | 10-16 | 2-3 | 3-5 | 6-8 | 15-25 | 40-55 |
| LihFolk SwordHeavy | 0-16 (6 f held coil) | 16-21 | hit f21 | 21-33 | 33-52 | 52 |

- **Reaction time** is about 0.25 s, so give 8 frames of telegraph or more on anything meant to be blocked or dodged.
- **Combo windows** open at ~70% of recovery, with a 6-10 f [[Input Buffering|input buffer]]. LihFolk lights put `ComboWindow` on f15.
- **Hit-stop** (**Expert practice**): Smash Melee's formula is floor(damage/3 + 3) frames at 60 fps, capped at 20. LihFolk recommends, on both attacker and victim, light 2-3 f, heavy 5-6 f, finisher 7-9 f. The clip JSON stores `hitstop_frames_recommended`.
- **Parry windows**: Sekiro-style 12 f at 60 fps (0.2 s). LihFolk uses 0.20-0.30 s server-side (`ParryStart` f2 to `ParryEnd` f9), a 2 f snap into the pose, and a 10-15 f whiff recovery.
- **Dash attacks** move the root in code between `DashStart` and `DashEnd`. Keep the feet airborne until the root stops, or they skate.

## 4. Poses that sell a cut (12 principles applied)

- **Anticipation.** Coil the hips and chest away from the cut, move the weight to the rear leg, and send the off hand forward to "aim".
- **Arcs.** Put a breakdown key on the far side of the arc so the blade never takes the short way through the body. The pipeline inserts these automatically when an in-between would collide.
- **Slow in, fast out.** `launch` leaving the coil, `linear` through the strike, `snap` on contact, `flat` on the hold.
- **Follow-through and overlap.** Head and off arm 1-2 frames behind. Hips lead the chest, the chest leads the arm.
- **Staging.** The 3/4 preview camera goes on the side the cut finishes toward, or the follow-through faces away from it.

## Common mistakes

- Authoring the default-speed locomotion as a walk: it slides at 16 studs/s.
- Copying real running knee angles onto R15 boxes: the shin enters the pelvis.
- Light attacks shorter than 8 f of startup in PvP: nobody can react to them.
- Deep lunges with the pelvis pitched forward: the front knee jams into the belly.
- Hit-stop on the attacker only: it reads as lag.

## Checklist

- [ ] Ground speed in the clip JSON matches the `WalkSpeed` it's played at (foot slide 0)
- [ ] Run lift 0.3-0.45 studs; pelvis pitch 8° or less; lean in the chest
- [ ] Light attack: hit on f6-8, ComboWindow ~f15 of 24
- [ ] Heavy attack: held coil of 6+ frames, hit f18-22
- [ ] Parry window markers and a whiff recovery

## See also

- [[Blade Grip and Wrist Limits]]
- [[Weapon Swing Design]]
- [[LihFolk R15 Keyframe Pipeline]]
- [[Hit Reactions Stagger and Hit-Stop]]
- [[Procedural Gait and Footstep Planning]]

## Connected notes

[[Animation Start Here]] · [[Combat Animation Craft]] · [[Locomotion Systems]]

<!-- related:start -->
## Related
[[Locomotion Readability - Lessons from Blind Panels]] · [[R15 Run Cycle Key Poses]] · [[Human Swing Biomechanics]] · [[Timing Spacing and Frame Charts]] · [[Locomotion Clip Lessons - Jump, Sprint, Idle]] · [[Spin and Whole-Body Rotation Moves]] · [[Posing and Silhouettes]] · [[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]]
<!-- related:end -->
