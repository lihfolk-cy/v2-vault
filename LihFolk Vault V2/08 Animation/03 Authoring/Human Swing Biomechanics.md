---
tags: [animation, authoring, combat, sword, biomechanics, kinematic-chain, pronation, twist, qa, type/guide, area/animation, level/intermediate]
---
# Human Swing Biomechanics

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Solving each key's wrist and elbow independently.
> - Avoid: Measuring "twist" with swing-twist decomposition.
> - Avoid: Putting all the rotation into the arm with the hips square.
> - Hips lead the chest by ~1 frame and the arm by ~2 frames
> - 35-60 deg hip-shoulder separation at the top of the windup
> - `Clip.cut()` declared for every swing
>
> Cost: TL;DR ~130 tok · whole note ~1.5k tok. Read more: ## 2. Rules at 30 fps · ## 3. QA in the pipeline · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Measured strikes (kendo, batting, tennis, golf) agree on one pattern: a swing is a proximal-to-distal wave. The hips turn first, then the trunk, upper arm, elbow, wrist, and last the forearm twist. Each segment twists **once, in one direction**. Keyed swings that re-twist the arm between poses read as "the arm randomly twisting", even when every single pose looks fine. This note turns the published numbers into keyframe rules and QA gates. Full citations are in `D:\LihFolk Build\research\animation-references.md`.

## 1. What the data says

| Finding | Number | Label |
|---|---|---|
| Kendo men strike, start of body movement to hit | ~0.76-0.78 s; the arm downswing itself is only 0.06-0.14 s | Source-backed (Murase 2017, figure-read) |
| Kendo arm sequence | Right elbow flexes from 50 to 75% of the strike, then extends to the hit; wrists cock from 60 to 80% and uncock in the last 20%; the lower (left) elbow barely moves | Source-backed |
| Batting kinematic sequence | Pelvis peaks 608 deg/s ~90 ms before contact, torso 984 deg/s ~71 ms before; the pelvis turns into the swing ~79 ms before the torso | Source-backed |
| Hip-shoulder separation | 35-60 deg at the top of the windup; golf X-factor 44-62 deg | Source-backed |
| Tennis serve | Shoulder internal rotation is the last and fastest segment (~2400 deg/s), after elbow extension and wrist flexion | Source-backed |
| Forearm pronation | Peaks at or after contact; small before contact; in pitching the peak comes after release | Source-backed |
| Golf lead wrist | ~25 deg radial at the top to ~25 deg ulnar at impact; forearm twist changes only ~2 deg | Source-backed |

## 2. Rules at 30 fps

1. **Lead with the hips.** Pelvis peak about 3 frames before contact, trunk about 2, then the arm. In the LihFolk pipeline, `_sword.lead(c)` offsets the chest +1 and the sword arm +2 frames, and shifts the Hit/Trail markers to match.
2. **Separation.** 35-60 deg between hips and shoulders at the top of the windup. It is largest about 4 frames before contact and drops to 10-15 deg at contact.
3. **One twist per cut.** Through windup, contact and follow-through, the forearm twists in **one direction**: at most ~15 deg before contact, then the burst from 1 frame before to 2 frames after. The upper-arm roll (shoulder rotation) also runs one way. `Clip.cut(f0, f1)` plans both as monotonic curves (fitted to the solved keys by isotonic regression) and re-solves every key on those curves.
4. **Speed caps.** Real peaks reach 45-70 deg per frame for pronation and 80+ for shoulder rotation at contact. On a block rig, more than ~25-30 deg per frame **outside** the contact frames reads as a glitch, not power.
5. **Wrist.** Radial deviation in the windup (blade cocked), ulnar through contact, mostly in the last 2 frames.
6. **Elbow.** The sword elbow extends over the last ~6 frames and is not locked at contact. The off elbow stays quiet.

## 3. QA in the pipeline

`qa.arm_twist` in each clip's JSON (from the exported Motor6D transforms, so it is what Roblox plays):
- `right_arm_twist_max_deg_per_frame`: the largest roll rate about any sword-arm segment's own long axis (intrinsic angular velocity).
- `right_arm_reversals_in_swing`: sign changes of that roll rate between `TrailOn - 3` and `TrailOff`, counting only steps faster than 3 deg/frame.
- The full per-joint table, both arms, is in `qa_arm_twist`.

**Measured on the LihFolk sword set.**
- The first rebuild had 42-73 deg per frame of roll and 4-7 reversals per swing.
- After the continuity + planned-curve solver: Heavy 12.6, Parry 16, Light1 33 deg per frame.
- Reversals were 0 on Parry but still 1-6 on the cuts: interpolating between keys with large swings re-introduced small counter-rolls.
- **Fixed in v4** by `lihanim/twist_dp.py`. After baking, it keeps each frame's wrist position and blade direction and re-plans the elbow swivel and forearm pronation per frame. It uses a Viterbi path with one roll direction per segment, wrist deviation and flexion in closed form, and keys every frame. All five cuts now have 0 reversals in the swing and 1-2 right-arm reversals in total (previously 6-9), with a max of 11-20 deg per frame outside contact.

## Common mistakes

- Solving each key's wrist and elbow independently. Every key picks its own twist branch, so the arm re-twists between poses.
- Measuring "twist" with swing-twist decomposition. It reports roll whenever the arm swings far, even with no real roll; use the intrinsic angular velocity about the bone axis.
- Putting all the rotation into the arm with the hips square. Real strikes get most of their speed from the hips and trunk first.
- Too many arm keys inside the 3-5 frame strike. Each key is another chance for a counter-roll; use one wind-up, one contact and one follow-through key.

## Checklist

- [ ] Hips lead the chest by ~1 frame and the arm by ~2 frames
- [ ] 35-60 deg hip-shoulder separation at the top of the windup
- [ ] `Clip.cut()` declared for every swing
- [ ] `right_arm_reversals_in_swing` = 0
- [ ] `right_arm_twist_max_deg_per_frame` 25 or under outside the contact frames

## See also

- [[Blade Grip and Wrist Limits]]
- [[Locomotion and Melee Reference Numbers]]
- [[Weapon Swing Design]]
- [[LihFolk R15 Keyframe Pipeline]]

## Connected notes

[[Animation Start Here]] · [[Combat Animation Craft]] · [[Weapon Swing Design]]

<!-- related:start -->
## Related
[[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]] · [[Animation Quality Standard]] · [[Elbow Poles Swivel and Joint Limits]] · [[Animation Review Checklist]] · [[Arm QA Metrics Reference]] · [[Locomotion Readability - Lessons from Blind Panels]] · [[Posing and Silhouettes]] · [[Case Study - Fixing Hundreds of Attack Clips]]
<!-- related:end -->
