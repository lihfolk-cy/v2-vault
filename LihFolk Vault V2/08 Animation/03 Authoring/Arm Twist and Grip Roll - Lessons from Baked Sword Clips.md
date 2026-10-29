---
tags: [animation, r15, sword, arm-twist, pronation, wrist, wrist-pop, edge-lead, tool-grip, blender, baking, lihfolk, type/guide, area/animation, level/advanced]
verified: 2026-10-29
---
# Arm Twist and Grip Roll - Lessons from Baked Sword Clips

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Measuring roll with swing-twist angles.
> - Avoid: Solving each key independently and trusting interpolation.
> - Avoid: Windups that roll against the strike.
> - Roll measured as angular velocity about the bone axis
> - Per-frame pronation and swivel plan after baking; one direction per segment
> - Windup posed so the strike rolls one way
>
> Cost: TL;DR ~130 tok · whole note ~2.5k tok. Read more: ## 3. The fix: one planned pronation curve per swing · ## 4. Edge lead is a grip problem, not a wrist problem · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Two problems decided whether scripted R15 sword clips looked human: the forearm "randomly twisting" during a swing, and the blade's true edge not leading the cut. Both were solved during the LihFolk V2 animation work, and neither fix was where we first looked. Numbers marked **Measured** come from the clip QA and the blind 3-reviewer panels.

## 1. The symptom

The user's report was simple: "the arm does a lot of random twists". The QA measured it: the sword arm's roll about its own axis ran at 42-73 degrees per frame with 4-7 direction reversals inside one swing (**Measured**). A real arm pronates or supinates one way through a cut.

Measure roll as the **angular velocity about the bone's own axis** per frame, not as swing-twist decomposition angles, which jump when the swing part passes a singularity.

## 2. Why per-key solving fails

The first fixes solved the wrist and elbow independently at every key, then with continuity costs between keys. Reversals dropped but did not vanish.

The reason: Blender interpolates **each joint's [[Quaternions|quaternion]] separately**. Even when every key is a good pose, the in-betweens of shoulder, elbow and wrist combine into counter-rolls *between* keys. Per-key planning cannot see them.

## 3. The fix: one planned pronation curve per swing

Plan the roll **per frame, after baking**:

1. Keep each frame's wrist path and blade direction exactly as authored.
2. Re-plan only two things: the elbow swivel (a rigid rotation about the shoulder-wrist line) and forearm pronation.
3. Solve each as a shortest path (Viterbi / dynamic programming) over discrete states with **one roll direction per segment**: windup -> contact -> follow-through, then recovery.
4. Derive wrist deviation and flexion in closed form from the chosen pronation, and key the arm on every frame.

**Measured:** 0 reversals inside the swing on all five cuts (previously 1-6), right-arm reversals total 1-2 (previously 6-9), and every twist gate passing. Gate values: sword-arm roll 25 degrees per frame or less outside the contact frames, zero reversals in the swing.

Authoring rules that make the plan possible:

- **Pose the windup so the strike rolls one way.** A windup that cocks the forearm against the strike cannot pass. A forehand cut that pronates needs a high raise (hand forward of the shoulder), not a supinated cock behind the shoulder.
- **Fewer arm keys inside the 3-5-frame strike.** Each extra key is a chance for a counter-roll.
- **Give the strike two frames, not one.** A one-frame blade flip (about 120 degrees) read as a wrist pop. Spreading it over two frames cut hand roll from 74.5 to 54 degrees per frame; a pre-roll key alone did nothing (**Measured**).
- When the body leans (a dash crouch of -20 to -28 degrees), rotate the authored blade direction by the same pitch, or the wrist leaves its range.

## 4. Edge lead is a grip problem, not a wrist problem

With a neutral grip the true edge did not lead at contact: edge error stayed at 50-68 degrees inside the wrist's anatomical limits (**Measured**). Forcing the edge with heavier edge weights broke every windup.

The fix was to **roll the handle in the hand by +45 degrees** about its own axis. The blade direction is unchanged; the true edge rotates to face the cut. In Roblox this is a `Tool.Grip` value:

```luau
local tool = script.Parent :: Tool
tool.Grip = CFrame.fromEulerAnglesYXZ(math.rad(30), math.rad(-45), 0)
```

(The rig applies Handle = Hand x RightGripAttachment x Grip inverse; the 30-degree tilt is the base handshake angle.)

**Measured** with +45: Light1 edge error 51 -> 17 on fast frames, Heavy 38 -> 22-28, Light3 37 -> 18; all wrist and twist gates passing. Light1 went from a 7.7 panel to a 9.0 panel pass with the roll plus the two-frame strike.

Caveats:

- The per-clip optimum differs: +45-65 for forehand cuts across the body, about 0 for the dash, -10 to -45 for a falling backhand. No single roll fits all. Pick one grip for the weapon and re-author the clips that fight it.
- Under +45 a falling backhand cannot lead with either edge; it needs a redesign. A pure vertical chop needs supination past the limit; re-author it as a steep forehand diagonal.
- With a rolled grip, lower the default edge weight (the grip presents the edge) and raise the strike key's pronation band.

## 5. Pre-pronation: hide the roll where nobody looks (v7)

Even with one planned roll direction, a clip can still show a **wrist pop**: a single frame where most of the roll happens. **Cause:** each authored key pins the forearm roll close to what that key's blade needs, so when the windup key and the contact key need very different rolls, all of the difference is forced into the frames between them, often one frame.

**Fix (Measured, SwordLight3 7.7 -> 8.7 panel, peak hand roll 54.8 -> 21.1 deg/frame, 0 reversals):**

1. **Pronate early, during the windup and the hang**, where the arm is slow and the roll is invisible. Give the windup keys a pronation band already part-way to the contact roll.
2. **Remove the separate strike key** between the hang and contact. Hang -> contact -> follow-through is enough; the extra key was the one forcing the burst.
3. **Lay the contact blade so contact sits mid-roll**, not at the end of the roll.
4. **Finish the roll after contact**, in the follow-through, where real pronation peaks anyway ([[Human Swing Biomechanics]]).

General rule, any weapon: if a joint needs to rotate a lot, spread the rotation over the slow frames on either side of the fast frame, instead of letting the keys force it into the fast frame.

## 6. Per-clip grip roll

The shared +45 deg grip suits forehand cuts but can **block** others: on the dash slash the wrist hit its ulnar limit before the edge could lead. Use a **per-clip grip roll** instead of bending the clip around the shared grip.

- In the LihFolk pipeline a clip module declares `GRIP_ROLL = <deg>` (PIPELINE.md section 2E). Clips without it keep the shared default. The clip JSON then records `tool_grip_roll_deg`.
- **Game code must set the matching `Tool.Grip` while that track plays** and restore the shared grip when it stops; otherwise the game shows a different blade angle from the one that was authored and scored.
- A per-clip roll is a tool for reachability, not a goal in itself; see section 7 before chasing a perfect edge lead.

## 7. Blade readability depends on the gameplay camera

**Measured (counter-example):** a SwordDashSlash redesign with a level wide cut, the edge leading perfectly and a 20 deg grip roll scored **worse** (5.7 panel, down from 7.7). A level cut with the edge leading turns the blade's **thin edge toward a slightly raised three-quarter camera**, so the blade vanishes exactly at Hit, and a follow-through pointing at the camera read as dropping the blade to the floor.

- Choose contact angles that show the **flat of the blade to the gameplay camera**. Readability at the game camera beats geometric correctness.
- **Accept about 15-30 deg of edge-lead error** when that is what it takes to keep the flat visible.
- After contact, **do not let the sword arm cross the torso in the front view**; it hides both.
- **Pull the off arm clearly back** so it separates from the torso and balances the cut.
- Check every cut from the real game camera (raised three-quarter) as well as the review side camera.

## 8. Reviewers and evidence

- Side camera on the side the cut finishes, so the follow-through blade is visible.
- Single reviewers over-scored sword clips by about 0.7 against the panel. Only the median of three decides.
- Keep copies of every previous sheet and module, so a regression can be compared directly.

## Common mistakes

- Measuring roll with swing-twist angles.
- Solving each key independently and trusting interpolation.
- Windups that roll against the strike.
- One-frame blade flips at contact.
- Forcing edge lead at the wrist instead of rolling the grip.
- Expecting one grip roll to suit every clip.
- A separate strike key between hang and contact forcing all the roll into one frame (wrist pop).
- Chasing a perfect edge lead that turns the blade's thin edge to the game camera.
- Setting a per-clip `GRIP_ROLL` without setting the matching `Tool.Grip` in game.

## Checklist

- [ ] Roll measured as angular velocity about the bone axis
- [ ] Per-frame pronation and swivel plan after baking; one direction per segment
- [ ] Windup posed so the strike rolls one way
- [ ] Strike spread over 2 frames
- [ ] Grip rolled (+45 for forehand-heavy sets); conflicting clips re-authored
- [ ] Panel median, side camera on the finishing side
- [ ] Pronation started in the windup/hang; no separate strike key; contact mid-roll; roll finished after contact
- [ ] Blade flat visible from the gameplay camera at Hit (edge error up to 15-30 deg accepted)
- [ ] Per-clip `GRIP_ROLL` mirrored by `Tool.Grip` in game code while the track plays

## See also

- [[Spin and Whole-Body Rotation Moves]]
- [[Blind Review Scores - Noise, Panels and Shipping the Best Version]]
- [[Blade Grip and Wrist Limits]]
- [[Human Swing Biomechanics]]
- [[Weapon Swing Design]]
- [[Pipeline - Arm IK Baking and QA]]
- [[Held Weapons on Motor6D - Locking the Grip During Attacks]]

## Connected notes

[[Locomotion Readability - Lessons from Blind Panels]] · [[LihFolk R15 Keyframe Pipeline]] · [[Arm QA Metrics Reference]]

<!-- related:start -->
## Related
[[Elbow Poles Swivel and Joint Limits]] · [[Animation Quality Standard]] · [[Locomotion Clip Lessons - Jump, Sprint, Idle]] · [[Posing and Silhouettes]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Locomotion and Melee Reference Numbers]] · [[Spec-Driven Move Authoring]] · [[Animation Review Checklist]]
<!-- related:end -->
