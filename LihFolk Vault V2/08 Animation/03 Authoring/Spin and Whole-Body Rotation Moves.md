---
tags: [animation, r15, spin, spin-attack, whirlwind, backflip, twist, flip, rotation, root, humanoidrootpart, acrobatics, overlap, lihfolk, type/guide, area/animation, level/advanced]
verified: 2026-10-29
---
# Spin and Whole-Body Rotation Moves

<!-- tldr:start -->
> [!tldr] TL;DR
> - Spin reverses or skips a turn: Rotation keyed sparsely; interpolation takes the short way -> Key the Root joint every frame
> - Character over-spins in game: Game code also rotates the HRP -> AutoRotate off during the clip; no HRP turns
> - Spin reads as a loop: Equal frames per turn -> Accelerate (8, 7, 6 frames per turn)
> - Whole-body rotation on the Root joint, every frame, fixed composition order
> - Gameplay code does not rotate the HRP during the clip
> - Turns accelerate; hips over the support foot; weapon arm extended
>
> Cost: TL;DR ~170 tok · whole note ~2.1k tok. Read more: ## 2. Readable spins · ## 3. Flips and twists · ## Common mistakes · ## Checklist
<!-- tldr:end -->

How to author moves where the whole character rotates: spin attacks and whirlwinds, turning slashes, backflips, twisting flips, cartwheels. Distilled from the LihFolk V2 3-spin sword attack (v1 anim 7.0 on a blind 3-reviewer panel) and a twisting backflip (panels 6.3 then 5.7, never passed). The same rules apply to any weapon or no weapon. The matching VFX rules are in [[Escalation and Grandeur Without Clutter]]. **Measured** marks panel and QA results; **Rule of thumb** marks judgement.

## 1. Rotation lives on the Root joint, every frame

- **Key the whole-body rotation on the Root joint** (`LowerTorso` Root Motor6D) **on every frame**, not on a few keys. Sparse keys let [[Quaternions|quaternion]] interpolation take the short way round, so a 360 deg turn collapses or reverses between keys. A flip that combines somersault, tilt and twist should compose them in a fixed order every frame (the backflip used somersault x tilt x twist) and solve the centre of mass on an exact parabola.
- **The game must not rotate the HumanoidRootPart** during the clip. If gameplay code also turns the HRP (auto-rotate, face-the-target), the two rotations add and the character over-spins. Turn off `Humanoid.AutoRotate` for the clip and restore it on `Stopped`.
- Root translation for flips (rise and travel) also goes on the Root joint; see [[Animation Data Hygiene - Euler Wrap Joint Holes and Easing]] for shortest-path angle traps.

## 2. Readable spins

- **Accelerating turns beat metronomic ones.** Three turns at 8, 7 and 6 frames read as building power; three equal turns read as a loop (**Measured**). This pairs with escalating VFX per turn.
- **Hips over the support foot.** The pelvis must sit over the pivot foot through each turn, or the spin reads as falling. Pivot on the ball of the foot; feet still plant and do not slide ([[Foot Placement and Ground IK]]).
- **Snap and hold on each contact.** Repeated hits inside a spin need a short snap into contact and a brief hold, or the turns blur into one motion (**Measured**, reviewer note; the spin attack's animation stayed at 7.0 across both rounds).
- **The finisher pose is high, edge leading**, on the contact frame, bigger than the spins; a low finisher with the blade pointing down reads as a weak ending.
- **Extend the weapon arm.** An extended sword arm separates the silhouette from the torso and shows the turn; an arm tucked against the body makes every frame of the spin the same blob.
- **Spin VFX may go round the body** for an explicit spin move only; ordinary slashes stay frontal ([[Slash VFX Recipes - Crescent and Ring]]).

## 3. Flips and twists

- **Backflips drift backward.** A real backflip travels backward; an in-place flip with the landing on the take-off spot looks wrong, and a centre of mass that drifts forward in flight (**Measured**: 0.73 studs forward) reads as broken physics. Let the root travel back and land behind the take-off.
- **Slow start to the somersault**, straight legs in flight, a chest held neutral through the twist and a pike only at the end were all applied to the backflip (somersault rate ramping 8 to 24 deg/frame, then 3 on landing). They removed specific complaints but did not lift the panel past about 7 on their own (**Measured**); the blocker was twist readability (below).
- **The twist must be readable from the game camera.** On 1-stud R15 block rigs a mid-air twist reads as a clump of boxes in three-quarter and front views (**Measured**: every reviewer, panels 6.3 then 5.7). Favour silhouettes with the limbs clearly **extended and separated**, use a camera facing the twist plane, and key a **slowed beat at the half-twist** so one clear pose is held.
- **Flight length.** A 22-frame flight with a 4.8-stud rise read as floaty (**Measured**); try about 18 frames at about 4 studs.
- **Check pose readability in the views, not only the numbers.** With the chest pitched forward, reviewers read arms that are numerically behind the body as reaching forward. Look at each view before trusting joint angles.
- **Travelling clips need an end offset.** When a clip ends away from where it started (the backflip lands about 1.4 studs behind), record it (`end_offset_studs` in the LihFolk clip JSON) and have game code move the HRP by that offset when the clip ends, or the character pops back to the start.

## 4. R15 overlap limits for arm wraps

- **An R15 block forearm cannot cross the chest without overlapping the torso.** A real twist wraps the arms tight across the chest; on R15 boxes the cleanest legal wrap is fists at the chest, which reads as T- or cross-arms side-on.
- The LihFolk pipeline therefore allows a **clip-scoped `c.overlap_exempt`** (PIPELINE.md section 4) for airborne arm wraps: the overlap gate is relaxed for the arms only, during the flight frames of that one clip, not globally. Grounded frames and every other clip keep the full gate.
- `c.preview_only_objects` (same section) adds helpers such as a centre-of-mass floor shadow to the preview without exporting them into the clip. Helpers are fine; anything that changes how the move itself looks is not ([[VFX Previews in Blender for Roblox - Colour and Framing]], "previews must match the game").

## 5. Evidence for reviewers

- Put the turn timings (frames per turn), the Root rotation per frame and the centre-of-mass path in the clip JSON.
- Show a floor shadow of the centre of mass in previews so travel and drift are visible.
- Scores come from the 3-reviewer panel median ([[Blind Review Scores - Noise, Panels and Shipping the Best Version]]).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Spin reverses or skips a turn | Rotation keyed sparsely; interpolation takes the short way | Key the Root joint every frame |
| Character over-spins in game | Game code also rotates the HRP | AutoRotate off during the clip; no HRP turns |
| Spin reads as a loop | Equal frames per turn | Accelerate (8, 7, 6 frames per turn) |
| Spin looks like falling | Hips not over the pivot foot | Pelvis over the support foot each turn |
| Spin is a blob | Weapon arm tucked in | Extend the weapon arm |
| Backflip looks fake | Lands in place or drifts forward | Travel backward, land behind take-off |
| Twist unreadable | Boxes clump in three-quarter view | Extended, separated limbs; camera facing the twist plane; slowed half-twist beat |
| Flip looks floaty | Flight too long and high (22 f, 4.8 studs) | About 18 frames at about 4 studs |
| Character pops back after a flip | Clip travels but the HRP stays | Record `end_offset_studs`; shift the HRP when the clip ends |
| Arms read forward though they are behind | Chest pitched forward | Judge the pose in each view, not by angles |
| Arm wrap fails the overlap gate | R15 forearm cannot cross the chest | Clip-scoped `overlap_exempt` for airborne frames only |

## Checklist

- [ ] Whole-body rotation on the Root joint, every frame, fixed composition order
- [ ] Gameplay code does not rotate the HRP during the clip
- [ ] Turns accelerate; hips over the support foot; weapon arm extended
- [ ] Flips travel in their natural direction; centre of mass on a parabola
- [ ] Twist frames readable from the review camera; limbs separated; half-twist beat held
- [ ] Travelling clips record their end offset and the game shifts the HRP after the clip
- [ ] Any overlap exemption scoped to one clip and its airborne frames
- [ ] Spin VFX escalate per turn and finish forward

## See also

- [[Escalation and Grandeur Without Clutter]]
- [[Human Swing Biomechanics]]
- [[Weapon Swing Design]]
- [[Combat Animation Craft]]
- [[Posing and Silhouettes]]
- [[Locomotion Clip Lessons - Jump, Sprint, Idle]]
- [[LihFolk R15 Keyframe Pipeline]]

<!-- related:start -->
## Related
[[Locomotion Readability - Lessons from Blind Panels]] · [[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]] · [[Locomotion and Melee Reference Numbers]] · [[R15 Run Cycle Key Poses]] · [[Blade Grip and Wrist Limits]] · [[Animation Review Checklist]] · [[Animation Quality Standard]] · [[Authoring Clips in Code]]
<!-- related:end -->
