---
tags: [authoring, locomotion, run, run-cycle, r15, key-poses, keyframesequence, swordsman, sprint, foot-sliding]
---
# R15 Run Cycle Key Poses

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Lean put in `LowerTorso` -> Pelvis 8° or less; lean the `UpperTorso`
> - Avoid: No head counter-rotation -> Head `rx` about equal and opposite to the chest lean
> - Avoid: Hip height set by eye -> Solve `LowerTorso` py per key so the planted foot touches the ground
> - Two steps per cycle, each with contact, down, push-off and flight.
> - Chest leans, pelvis stays within 8°, head counter-rotates.
> - Hip bob solved per key for foot contact.
>
> Cost: TL;DR ~150 tok · whole note ~2.3k tok. Read more: ## 3. The swordsman run: poses · ## 4. Matching the clip to movement speed (foot sliding) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A run is the one cycle every action game needs, and the one the rest of this vault gives rules for but no numbers. This note gives a complete, worked set of R15 key poses for a fast, hunched **swordsman run**: joint angles per key, timing, hip bob and the speed the clip implies. It then covers how to change it into other runs and how to match it to `WalkSpeed` so the feet don't slide.

**Labels:**
- **Rule of thumb:** the poses were designed with a forward-kinematics pass over the R15 joint offsets in [[R15 Rig Anatomy and Attachments]]. That pass places the planted foot on the ground at every key.
- **Unverified on a played rig:** as of October 2026 the clip has not been measured playing in Studio.

The conventions are the vault's: `CFrame.Angles(rx, ry, rz)` in degrees on the joint, with these signs:
- **`rx` on a limb:** `rx > 0` swings a hanging limb forward.
- **`rx` on the torso or head:** `rx > 0` tips it back.
- **Translation:** only on `LowerTorso` ([[Motor6D Math and CFrame Composition]], [[KeyframeSequence Keyframe and Pose Reference]]).

## 1. The shape of a run on R15

R15 legs are short: hip to knee 0.92 studs, knee to ankle 1.01, ankle to sole about 0.26. A run therefore needs a **flight phase**, a moment with both feet off the ground, to cover distance without huge leg swings ([[Locomotion and Melee Reference Numbers]]). One cycle is two steps, and each step has four beats:

| Beat | What happens | Hips (`LowerTorso` py) |
|---|---|---|
| Contact | Front foot lands slightly ahead of the hips | high (about -0.03) |
| Down | Weight lands, stance knee bends, swing knee folds tight | lowest (about -0.28) |
| Pass / push-off | Swing thigh drives forward and up, stance leg extends behind | rising (about -0.19) |
| Flight | Both feet off; the drive thigh is high | near top (about -0.01) |

A **quick-step** run (short stride, high cadence) keeps every beat but shrinks the thigh swing. That makes it look agile instead of athletic.

## 2. The swordsman run: timing

- **Keys:** 8 keys, plus a closing key equal to the first, every **0.0625 s**. The cycle is **0.5 s**: 2 steps of 0.25 s, or 240 steps per minute.
- **Easing:** all segments are **Linear**. Evenly spaced Linear keys make Studio blend rotations with quaternions, which is smooth and shortest-way. Segments under 0.1 s that move the hips or feet should stay Linear anyway ([[Keyframes, Easing and Interpolation]]).
- **Priority:** `Movement`, with `Looped` true.

## 3. The swordsman run: poses

The table below is the first half of the cycle, keys 0-3 (right foot forward). Keys 4-7 are the **mirror**:
- swap Left and Right;
- negate `ry` and `rz` on the torso, head and legs;
- keep `rx`.

The exception is the sword arm. It is not mirrored: it keeps its held pose with a small sway.

| Joint (rx, ry, rz) | Key 0 contact | Key 1 down | Key 2 push-off | Key 3 flight |
|---|---|---|---|---|
| LowerTorso (+ py) | -8, 7, 0 (py -0.032) | -8, 4.9, 2.1 (py -0.193) | -8, 0, 3 (py -0.281) | -8, -4.9, 2.1 (py -0.006) |
| UpperTorso | -29.5, -10.8, 0 | -32, -11.3, -1.4 | -34.5, -5.2, -2 | -32, 3.9, -1.4 |
| Head | 30.5, 5, 0 | 33, 3.5, 0 | 35.5, 0, 0 | 33, -3.5, 0 |
| RightUpperLeg | 38, 0, -3 | 32.8, 0, -3 | 10.2, 0, -3 | -18, 0, -3 |
| RightLowerLeg | -26, 0, 0 | -52, 0, 0 | -46, 0, 0 | -26, 0, 0 |
| RightFoot | 6, 0, 3 | 27.2, 0, 3 | 43.8, 0, 3 | 22, 0, 3 |
| LeftUpperLeg | -24, 0, 3 | -2, 0, 3 | 34, 0, 3 | 46, 0, 3 |
| LeftLowerLeg | -58, 0, 0 | -88, 0, 0 | -102, 0, 0 | -50, 0, 0 |
| LeftFoot | -15, 0, -3 | 3, 0, -3 | 54, 0, -3 | 16, 0, -3 |
| LeftUpperArm (free arm pumps) | 42.2, -6, -12 | 43.9, -6, -12 | 24.5, -6, -12 | -4.5, -6, -12 |
| LeftLowerArm | 94.6, 0, 0 | 95.2, 0, 0 | 88.1, 0, 0 | 77.4, 0, 0 |
| LeftHand | -8, 0, 0 | -8, 0, 0 | -8, 0, 0 | -8, 0, 0 |
| RightUpperArm (sword held back) | -46.3, 10, 20 | -46.6, 10, 20 | -43, 10, 20 | -37.7, 10, 20 |
| RightLowerArm | 25.6, 0, 0 | 25.8, 0, 0 | 23.7, 0, 0 | 20.7, 0, 0 |
| RightHand | -30, 0, 0 | -30, 0, 0 | -30, 0, 0 | -30, 0, 0 |

In the second half the sword arm eases from about -34 back to -46 `rx`, so it sways about ±7° over the cycle. The left arm swings from +42 to -28 `rx`.

What makes it read as a swordsman and not a sprinter:
- **The lean is in the chest, not the pelvis.** `UpperTorso` sits at -30 to -35 `rx`, while `LowerTorso` stays at -8. A pitched pelvis on R15 swings the legs backwards and breaks foot contact ([[Locomotion and Melee Reference Numbers]]).
- **The head counter-rotates** by the same amount (+30 to +35), so the eyes stay level while the body is hunched.
- **Short thigh arc:** the thighs swing within about ±46°, so the steps are short and fast.
- **Torso twist:** the chest twists against the hips (`ry` ±11 on UpperTorso, ±7 on LowerTorso) for agility.
- **Asymmetric arms:** the free arm pumps with the elbow bent 70-95°. The sword arm stays back and out (`rz` 20), so the blade trails and clears the leg.

## 4. Matching the clip to movement speed (foot sliding)

A clip has a built-in ground speed: how fast the planted foot moves backwards during contact. For this clip it is about **10 studs/s**: the stance foot travels about 2.5 studs per 0.25 s step. Play it at `WalkSpeed` 16 and the feet skate.

Choose one of these:

| Fix | How | Trade-off |
|---|---|---|
| Scale playback | `track:AdjustSpeed(humanoid.WalkSpeed / 10)`, updated as speed changes | At 16 studs/s that is 1.6x: 384 steps a minute, which looks frantic |
| Lower run speed | Set the sprint `WalkSpeed` to about 10-12 | Changes the game feel; often fine for a hunched run |
| Lengthen the stride | Widen the thigh swing to about ±55° and lengthen flight; recompute the hip bob so the planted foot still touches the ground | More work; the stride stops looking "quick" |

The general rule: **clip ground speed = stance foot travel ÷ stance time.** Measure it once per clip and store it as an attribute, for example `GroundSpeed = 9.97`, so locomotion code can compute playback speed. See [[Locomotion Systems]] and [[Procedural Gait and Footstep Planning]].

## 5. Making other runs from this one

| Variant | Change |
|---|---|
| Upright jog | Halve the chest lean (-12 to -15), head counter to match. Use 0.35 s per step and drop the twist to ±5 |
| Sprint | Thigh swing ±60°, longer flight key. Both arms pump with the elbow at 90°. Ground speed rises to about 16-18 |
| Two-handed weapon | Both arms held in front (`rx` about +20 on both upper arms); no arm pump; more chest twist |
| Injured / tired | Uneven timing: 0.3 s and 0.22 s steps, and a lower bob on one side |

Keep the hip bob solved for foot contact after any leg change. Eyeballing the hip height is how runs start floating or sinking.

## 6. Weapons and the default Animate script

If the sword is a `Tool`, the stock Animate script plays `toolnone` on the right arm. That hold overrides this clip's sword arm unless it is faded out or the run plays at a higher priority than `toolnone` (`Action`). Do this for the right arm only; it is the classic "my run's arm is frozen" bug ([[The Default Animate Script]], [[Playback, Priorities and Blending]]). The grip itself should not move during the run; see [[Held Weapons on Motor6D - Locking the Grip During Attacks]].

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Lean put in `LowerTorso` | Legs swing backwards, feet leave the ground | Pelvis 8° or less; lean the `UpperTorso` |
| No head counter-rotation | Character stares at the floor | Head `rx` about equal and opposite to the chest lean |
| Hip height set by eye | Feet float or sink at some keys | Solve `LowerTorso` py per key so the planted foot touches the ground |
| Clip played at any `WalkSpeed` | Feet skate | Store the clip's ground speed; `AdjustSpeed(speed / groundSpeed)` |
| Uneven or rounded key times | Rotation blending changes, small pops | Exact, evenly spaced times (0.0625, not 0.062) |
| Sword arm mirrored like the free arm | Blade swings through the legs | Hold the sword arm; only sway it a few degrees |
| `toolnone` left playing | Sword arm frozen in the default hold | Higher priority than `toolnone`, or stop it on the right arm |

## Checklist

- Two steps per cycle, each with contact, down, push-off and flight.
- Chest leans, pelvis stays within 8°, head counter-rotates.
- Hip bob solved per key for foot contact.
- Keys evenly spaced and Linear for fast segments.
- Ground speed measured and stored; playback scaled to movement speed.
- Sword arm held, not mirrored; `toolnone` cannot override it.

## Connected notes

- [[R15 Rig Anatomy and Attachments]]: joint offsets and axes the poses use.
- [[Locomotion and Melee Reference Numbers]]: lean, pelvis and foot-travel limits.
- [[Keyframes, Easing and Interpolation]]: why even, Linear keys blend cleanly.
- [[KeyframeSequence Keyframe and Pose Reference]]: building the clip in code.
- [[Procedural Gait and Footstep Planning]]: the no-slide condition.
- [[Locomotion Systems]]: playing run clips from movement speed.
