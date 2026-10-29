---
tags: [animation, r15, locomotion, walk, run, sprint, idle, review, lihfolk, type/guide, area/animation, level/advanced]
---
# Locomotion Readability - Lessons from Blind Panels

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Authoring a walk for WalkSpeed 16.
> - Avoid: Sine-wave bobs and even spacing.
> - Avoid: Leaning the pelvis instead of the chest.
> - Walk at native speed with an AdjustSpeed plan; 16 studs/s = run
> - Contact / down / passing / up with uneven spacing and flat holds
> - Hip shift + drop; chest roll toward the swing side; head lateral < pelvis lateral
>
> Cost: TL;DR ~130 tok · whole note ~1.4k tok. Read more: ## 3. Run and sprint (5.3 -> 9.0 and 7.7) · ## 4. Idle (6.3 -> 8.3, never passed) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

verified: 2026-10-28

What made scripted R15 walk, run, sprint and idle clips readable to blind reviewers looking at a contact sheet and a QA JSON. These clips went through six versions in the LihFolk V2 build; each row below records a change and its effect on the 3-reviewer panel median (**Measured**).

## 1. 16 studs/s is a run

Roblox's default `Humanoid.WalkSpeed` is 16. R15 legs cannot walk at 16 studs/s without sliding: at that speed the stride needs a running gait (about 8 frames per step at 30 fps). Author the walk at its natural speed (about 5.5 studs/s in this rig) and scale playback with `AdjustSpeed(WalkSpeed / 5.5)`, or treat 16 as a run. Reviewers marked "fits gameplay" down every time a walk shipped at native 5.5 without a speed plan.

## 2. Walk (5.7 -> 8.7)

- **Classic keys, uneven spacing.** Contact f0, down f2 (flat hold), passing f6, up f10 (flat hold) in a 12-frame step. The pelvis rises for 8 frames and falls for 4. A sine bob reads as "even spacing".
- **Heel peel at the up key** so the up pose has a readable silhouette.
- **Lateral hip shift** (about 0.2 studs) and a 5-degree hip drop over the support foot, with a chest counter-tilt.
- **Chest roll toward the swing side.** The opposite sign doubled head sway (0.48 -> 0.78 studs); the right sign cut it to 0.11. Keep the head's lateral motion smaller than the pelvis's, or reviewers call it a waddle.
- Reviewers flip between "shift unreadable" and "waddle" around 0.2 studs; put the measured numbers in the evidence and add a centreline plumb in the front view.

## 3. Run and sprint (5.3 -> 9.0 and 7.7)

- **Visible flight.** Both feet 0.3+ studs off the ground for 3 frames: feet leave fast, stay up, land late (asymmetric rise and drop curves) plus a heel kick. Run 5.3 -> 8.3.
- **Shoulder counter-yaw is the cheapest side-view lever.** Chest yaw from +-12 to +-20 degrees raised the visible torso in side view by about 60 % (pixel count) and took the run from 8.3 to 9.0.
- **Elbows open behind, close in front** (about 55-60 degrees behind, 92-105 in front) so the forearm whips.
- On a forward-leaned torso, the arm swing shifts backward in world space by about the lean. Author forward +40..56, back -40..-48.
- **Lean with the chest, not the pelvis.** Pelvis pitch over about 8 degrees jams the front knee into the pelvis box; swing-foot lift over about 0.45 studs jams the shin.
- Pitching the chest while yawing it tilts the shoulder line; add an opposite chest roll of about sin(pitch) x yaw.
- A pure side view always shows R15 arm boxes over the torso mid-swing. Accept a 1 on silhouettes in that view, or pick a camera angle that shows the swing.

## 4. Idle (6.3 -> 8.3, never passed)

What helped:

- Weight shift big enough to read on a sheet: pelvis 0.25 studs and 7 degrees roll; breath at 8 degrees of chest.
- A small anticipation sink (0.1 studs), a 0.06 overshoot, a snap glance held about 14 frames.
- Arms on different offsets (5-9 frames vs 9-14).

What blocked it:

- In the three-quarter game camera, the key poses looked alike.
- **Breath-driven arm abduction made the hands lead the weight shift.** Couple arm roll to pelvis roll weakly (0.2, not 0.6) and key the trail explicitly; panels want 0.3-0.4 studs of hand trail.
- A hand-on-hip beat must abduct the arm with the wrist at the pelvis side, or the hand floats in front of the belly.

Idle is subtle by nature. If three rounds don't pass, add a clearly separate secondary action instead of amplifying the same motion.

## 5. Evidence for the reviewer

- Put measured motion numbers in the JSON (pelvis lateral and bob, flight frames, elbow bend, hand trail) and pose names on the sheet.
- Reviewers check claims against the JSON and penalise contradictions, including a hit frame off by one between the intent text and the data.
- Blind reviewers scored about 2 points below the earlier maker-assisted reviews; single reviewers swing 1.5-2.3 points (Walk 6.0 / 7.0 / 8.0). Only the panel median decides.

## Common mistakes

- Authoring a walk for WalkSpeed 16.
- Sine-wave bobs and even spacing.
- Leaning the pelvis instead of the chest.
- Head swaying more than the pelvis.
- Arm swing authored for an upright torso on a leaned run.
- Amplifying an idle that already fails on pose variety.

## Checklist

- [ ] Walk at native speed with an [[AdjustSpeed]] plan; 16 studs/s = run
- [ ] Contact / down / passing / up with uneven spacing and flat holds
- [ ] Hip shift + drop; chest roll toward the swing side; head lateral < pelvis lateral
- [ ] Run: 3 flight frames, heel kick, chest counter-yaw ~20
- [ ] Pelvis pitch <= 8; swing-foot lift 0.3-0.45
- [ ] Measured motion numbers in the evidence; panel median decides

## See also

- [[R15 Run Cycle Key Poses]]
- [[Locomotion and Melee Reference Numbers]]
- [[Locomotion Systems]]
- [[Idle Breathing and Secondary Motion]]

## Connected notes

[[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]] · [[Animation Review Checklist]] · [[LihFolk R15 Keyframe Pipeline]]

<!-- related:start -->
## Related
[[Blade Grip and Wrist Limits]] · [[Human Swing Biomechanics]] · [[Posing and Silhouettes]] · [[Procedural Gait and Footstep Planning]] · [[Timing Spacing and Frame Charts]] · [[Animation Quality Standard]] · [[Foot Placement and Ground IK]] · [[Snippets - IK]]
<!-- related:end -->
