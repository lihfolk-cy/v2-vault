---
tags: [animation, r15, jump, jump-arms, takeoff, landing, sprint, idle, breathing, guard, silhouette, quick-fix, re-author, lihfolk, type/guide, area/animation, level/advanced]
verified: 2026-10-29
---
# Locomotion Clip Lessons - Jump, Sprint, Idle

<!-- tldr:start -->
> [!tldr] TL;DR
> - Score flat after several tweak rounds: Global flaw treated as local -> Re-author the key poses
> - Jump looks stiff: Arms swing with the legs -> Arms lead: back f2, down f3, forward f4, forward-up at take-off
> - Jump arms read as T-pose or cheer: Wide or overhead air arms -> Forward, then forward-down, hands outside the knees
> - Flaw classified as local (port a fix) or global (re-author) before fixing
> - Jump arms lead the push-off by a frame; no wide, overhead or bent-elbow air arms
> - Pelvis held up until contact; landing recovery about 13 frames
>
> Cost: TL;DR ~180 tok · whole note ~1.5k tok. Read more: ## 1. Quick fix or re-author? Diagnose first · ## 2. Jump (7.0 -> 8.3, owner-approved) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The second round of LihFolk V2 locomotion work (after [[Locomotion Readability - Lessons from Blind Panels]], which covers walk, run and the first idle and sprint passes). It adds a jump that reached 8.3 and was owner-approved, a sprint that went 7.7 -> 9.0 in one pass, and a sword idle that never passed. The rules apply to any character, armed or not. **Measured** means a blind 3-reviewer panel median; see [[Blind Review Scores - Noise, Panels and Shipping the Best Version]].

## 1. Quick fix or re-author? Diagnose first

The most useful lesson of the round: **a quick fix only works when the flaw is local.**

- **Local flaw** (one body part, one phase, and a working example exists elsewhere): port the fix. **Measured:** Sprint 7.7 -> 9.0 in one pass by porting Run's arm extremes (back -70 / front +66, elbows 62 / 95, more abduction) and widening the chest counter-twist (about -20 to +16 deg).
- **Global flaw** (the whole loop reads as one silhouette, or the design of a body part's path is wrong): tweaks move the score by tenths or nothing. **Measured:** the idle silhouettes and the jump's arm design each survived several tweak rounds at the same score and only moved after re-authoring the key poses.

Rule of thumb: if two fix rounds on the same criterion return a delta of 0, stop tweaking and re-author the keys.

## 2. Jump (7.0 -> 8.3, owner-approved)

- **Arms lead the push-off.** Key them a frame ahead of the legs: arms back at f2, down at f3, forward at f4, forward-up at take-off (f5 of a 35-frame clip). Arms that swing with the legs read as stiff.
- **In the air, avoid wide or overhead arms.** Arms flared near overhead read as a T-pose or a cheer. Path that worked: forward at chest height, forward-down over the tuck, down-out, then forward again through landing and absorb, hands outside the knees.
- **Bent elbows in the air read as hands by the head** (a wave or a huddle). **Measured:** elbows 45-55 through the air dropped the panel from 8.3 to 7.3; the straighter-arm version was restored and shipped.
- **Hold the pelvis up until contact.** If the pelvis drops early, the feet sink under the floor before landing.
- **Landing recovery about 13 frames** so the clip works at Action priority without cutting into the next state.
- Small left-right asymmetry (1-4 deg of pelvis and chest yaw or roll per key) helps against lockstep arms.

## 3. Sprint (7.7 -> 9.0)

- Port what already works: the run's arm extremes and chest counter-yaw (see section 1).
- In pure side view the forearms still stack over the chest on a few mid-swing frames; this is the R15 limit noted in [[Locomotion Readability - Lessons from Blind Panels]].
- Arm roll scaled to the cycle (about 10 deg/frame on a 12-frame cycle, 0 reversals).

## 4. Idle (stuck around 7, re-author needed)

- **Breath shows in the chest and shoulders, not the arms.** Key arms in torso space so they ride the chest; breath driven through the arms makes the hands lead the weight shift.
- **Distinct key silhouettes across the loop.** Reviewers compare key frames; if settle, sink and glance look alike from the three-quarter game camera, the idle scores as static. Bigger contrasts helped: a head glance of 35-45 deg plus about 10 deg of chest, a deeper hip drop.
- **Sword guard: keep the blade off the centre line in front view.** A blade across the face or body in front view hides the character.
- **Big, low blade drops read as attack tells.** An idle must never look like a wind-up.
- **Length: 4-5 s for two big beats.** 3.2 s was too short to stage two readable beats with holds.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Score flat after several tweak rounds | Global flaw treated as local | Re-author the key poses |
| Jump looks stiff | Arms swing with the legs | Arms lead: back f2, down f3, forward f4, forward-up at take-off |
| Jump arms read as T-pose or cheer | Wide or overhead air arms | Forward, then forward-down, hands outside the knees |
| Jump arms read as hands by the head | Bent elbows in the air | Straighter arms in flight |
| Feet sink before landing | Pelvis drops before contact | Hold the pelvis up until contact |
| Next action cuts the landing | Recovery too short or too long | About 13 frames of landing recovery |
| Idle reads static | Key silhouettes alike from the game camera | Distinct keys: bigger glance, chest turn, hip drop |
| Idle breath reads in the hands | Arms carry the breath | Breath in chest and shoulders; arms in torso space |
| Idle looks like an attack | Big low blade drop | Small blade travel, off the centre line |
| Idle feels rushed | 3.2 s for two big beats | 4-5 s |

## Checklist

- [ ] Flaw classified as local (port a fix) or global (re-author) before fixing
- [ ] Jump arms lead the push-off by a frame; no wide, overhead or bent-elbow air arms
- [ ] Pelvis held up until contact; landing recovery about 13 frames
- [ ] Sprint reuses the run's proven arm extremes and chest counter-yaw
- [ ] Idle breath in chest and shoulders; distinct key silhouettes; blade off the centre line; no attack tells; 4-5 s
- [ ] Every scored version backed up; ship the best panel score

## See also

- [[Locomotion Readability - Lessons from Blind Panels]]
- [[R15 Run Cycle Key Poses]]
- [[Idle Breathing and Secondary Motion]]
- [[Posing and Silhouettes]]
- [[Spin and Whole-Body Rotation Moves]]
- [[Humanoid States and Animation]]
- [[Blind Review Scores - Noise, Panels and Shipping the Best Version]]

<!-- related:start -->
## Related
[[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]] · [[Locomotion and Melee Reference Numbers]] · [[Human Swing Biomechanics]] · [[Animation Review Checklist]] · [[Animation Quality Standard]] · [[LihFolk R15 Keyframe Pipeline]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Blade Grip and Wrist Limits]]
<!-- related:end -->
