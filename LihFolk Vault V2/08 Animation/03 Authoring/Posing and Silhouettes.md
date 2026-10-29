---
tags: [authoring, craft, posing, silhouette, r15]
---
# Posing and Silhouettes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Posing only in the side view -> check every key pose from the gameplay camera
> - Avoid: Symmetric arms and legs -> break symmetry everywhere
> - Avoid: Weapon inside the silhouette -> move the weapon outside the body outline
> - Clear line of action in every key pose
> - Centre of mass over the base of support (unless falling)
> - No twinning
>
> Cost: TL;DR ~130 tok · whole note ~3.2k tok. Read more: ## What makes a pose read · ## Proportions and the R15 rig · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A pose is the unit of readability. Players read your animation as a sequence of shapes, mostly from behind, mostly small, often half hidden by effects. If the key poses read as clear silhouettes, the motion between them almost takes care of itself; if they do not, no amount of polish saves the clip.

This note covers line of action, balance, asymmetry, silhouette testing in Studio, and the limits of the R15 rig that turn good drawings into bad poses. Numbers are from the reference project (one live action game) where marked, otherwise rules of thumb.

## What makes a pose read

### 1. Line of action
One dominant curve runs through the pose, from the support foot up through the spine to the head or the weapon. A clear C or S curve reads as intent; a vertical stack of parts reads as standing around.
- Anticipation poses curve **away** from the action (coiled).
- Strike poses curve **into** it (the line extends through the arm and weapon).
- Recovery poses straighten toward neutral.

### 2. Weight and balance
The centre of mass must sit over the base of support (the feet, or between them) unless the character is falling or being thrown.
- Wide stances read as stable and heavy; narrow stances as light or unstable.
- When one leg carries the weight, the hip on that side rises and the shoulders tilt the other way (contrapposto). This one change turns a mannequin into a person.
- Leaning forward without stepping is only believable if the hips go back.

### 3. Asymmetry (no twinning)
Twinning means the left and right sides mirror each other: both arms at the same angle, both knees bent equally. It reads as robotic. Break symmetry in every pose:
- Different elbow bends.
- One foot ahead, one turned out.
- Head tilted, not level.
- Shoulders at different heights.

The reference project's QA flags **mirrored arms**: the left arm's mirrored motion correlating above 0.9 with the right over 0.4 s while both move.

### 4. Negative space
Light between the limbs and the body is what makes a silhouette legible. An arm across the chest disappears; the same arm held 20 cm out reads. For weapons: the blade must be clearly outside the body's outline at every key pose, or the player cannot see the attack direction.

### 5. Contrast between poses
Successive key poses should be **different in shape**, not only in position: coiled vs extended, low vs high, closed vs open. Two similar poses with a fast move between them read as a twitch.

## The camera you are posing for

On Roblox the default camera sits behind and above the character, typically 10 to 20 studs away, and players orbit freely. Rules of thumb:
- Check every key pose from **behind**, from **three-quarter behind**, and from the **side**. The behind view is the one most players see.
- A swing in the plane containing the camera's view direction collapses into a line. Tilt cut planes diagonally, or make the body turn show the direction.
- Arms forward of the torso are hidden from behind. Open the elbows out and let the weapon pass outside the shoulder line.
- Other players see you from any angle and from further away (30 to 60 studs in a crowd fight). Big shapes survive distance; wrist subtleties do not.

### Testing silhouettes in Studio
- Give the test rig a flat colour and turn off shadows, or put a `Highlight` on it with `FillTransparency = 0` and `OutlineTransparency = 1`, against a plain background. You now see only the shape.
- Pause on each key pose and orbit.
- Take screenshots of all key poses in a row (a filmstrip). The reference project generated filmstrips automatically for every baked clip and reviewed them before installing.
- Shrink the viewport or zoom out until the character is about 100 pixels tall. If the action still reads, it works.

## Proportions and the R15 rig

R15 is a blocky, short-legged character with 15 parts. Poses that work on a realistic human often fail on it.

### Proportions (reference project measurements on its 1.6x scaled R15, about 9 studs tall)
- Arm parts are about 1.6 studs wide; upper arm (shoulder pivot to elbow pivot) 1.48 studs; forearm (elbow pivot to wrist pivot) 1.29 studs.
- Hip height about 3.5 studs above ground: **short legs**. Running needs flight phases and walking has double support at the speeds a short-legged rig can manage.
- Wide, boxy torso: arms crossing in front of the chest sink into it far sooner than on a slim human.

Slimmer avatars and custom bodies clear the torso more easily than the block dummy. The reference project's QA ran on a blocky dummy, so its clearance scores are conservative (see [[Open Questions]]).

### Missing joints and what to do about them

| Real anatomy | R15 | Posing consequence |
|---|---|---|
| Clavicle / scapula lift the shoulder over 90 degrees of arm elevation (about 40 degrees of shrug available) | no clavicle joint; shoulder pivot is fixed | overhead arms look short and pinned. Keep overhead poses brief, lean the torso back, and avoid translating the shoulder (it reads as dislocation) |
| Forearm rotates (pronation about 80, supination about 85 degrees) | no forearm twist joint; all roll is on the wrist | big hand rolls twist the hand on the arm like a doorknob. Spread roll between the shoulder's rotation and the wrist |
| Elbow is a hinge | elbow joint accepts any rotation | nothing stops sideways or backwards elbows. Rotate elbows about their own X only, 3 to 146 degrees (reference project limit) |
| Wrist flex 60 to 80, radial 20, ulnar 30 degrees | any rotation accepted | aim weapons with the arm; the wrist only refines. The reference project limits wrist flex 70, deviation 30, twist 85 |
| Spine of 24 vertebrae | waist + neck | put most torso twist in the waist; most human twist is thoracic (above the pelvis) |
| Fingers | one hand part | grips are implied by the weapon attachment; open-hand gestures read only by hand orientation |

### Arm translation
Never pose an R15 limb by moving it. Rotation only. Translation over about 0.05 studs on an arm joint reads as a detached shoulder and is flagged by the reference project's QA. Translate only the root's first child (LowerTorso) for crouches and lunges.

### Root height and the floor
Crouching lowers LowerTorso; legs must bend to keep the feet on the floor. Two traps:
- **Scale**: the reference project's clips stored root offsets at the game's 1.6x character scale because the Animator applies clip translations literally on characters sized through body-scale values. A crouch authored on a scale-1 dummy left the feet hovering on the real character. See [[Scale and Animation]].
- **Depth**: drops below about -1.0 stud (at scale 1, before the 1.6x factor) pushed feet 1 to 2.5 studs through the floor in that project's leg solver. See [[Spec-Driven Move Authoring]].

## Pose catalogue: shapes that read for melee combat

The reference project built a shared library of named poses that every move reused. Their intent generalises to any melee character:

| Pose | Shape | Reads as |
|---|---|---|
| READY | slight forward lean, weapon forward and up, off hand loose, feet staggered | alert, about to act |
| Wind (flat cut) | torso turned away from the cut (about 24 degrees root yaw), blade back on one side, weight on the back foot | a cut is coming from that side |
| Cut | torso turned through (about -22 degrees), blade out on the far side, weight forward, off hand counter-swung | the cut happened |
| Overhead | blade back over the head, both hands on the hilt, chest open, hips not dropped | big downward blow coming |
| Chop / drive | hips drop, blade over the front, then driven down ahead | the blow landed in front |
| Chamber | blade drawn back at the hip, point forward, off hand reaching out | thrust coming |
| Thrust | body behind the arm, blade straight out, off hand pulled back | the thrust landed |
| Low / rising | blade low and back on one side, crouched | rising cut coming |
| High / falling | blade high on one side, upright | falling diagonal coming |
| Cast | off hand reaching forward and open, blade held back | magic / release from the off hand |
| Salute | blade vertical before the face | ceremony / channelling |

Full values and the code that builds them are in [[Spec-Driven Move Authoring]].

## Poses that break (lessons from QA)

The reference project scored every attack clip automatically. Its first audit found arm-in-body issues in **about 84%** of clips and blade-through-body in **about 82%**. The pose patterns that caused most critical failures:

- **Arms behind the body**: sprint, surf and "load" poses with the sword arm swept back. R15 shoulders cannot go far behind the frontal plane (QA limit: about 48 degrees behind when raised, 62 when low) without reading as broken.
- **Sprint into thrust or cross-cut lead-ins** drive the forearm into the torso. Use a **flat wind-up** before thrusts and cuts instead.
- **Backhand winds and two-handed low guards** put the forearm across the chest, inside the box torso.
- **Long pommels**: a blade gripped 20% from its butt has 1.9 studs of pommel behind a 9.5-stud blade. A blade pointing away from the body with the hand close drives that pommel into the torso or hip. Keep the hand further out (the project's "2" pose variants).
- **Ready end pose**: ending a clip on a "ready" pose with the hand near the hip put the pommel into the hip; re-keying end poses fixed 22 of 22 affected moves.
- **High to falling deep openers and salute-aloft ultimates** baked badly through IK; overhead, chop and falling variants were used instead.
- **Big root yaw swaps every 0.1 s** in flurries pop. Halve the root yaw and turn the waist more.

More in [[Weapon Swing Design]] and [[Animation Quality Standard]].

## Hands, head and eyes

- **The head leads intent.** It turns toward the target a few frames before the body commits. It also lags slightly behind fast torso turns (the reference project's baker lags the neck by 0.035 s).
- **The head stays fairly level** through big body motion (a vestibular reflex in real people). Keep the chin from bobbing with every swing.
- **The off hand is a second focal point.** Give it a job in every pose: guard, counter-swing, reach, chamber. A hanging off hand reads as dead. See [[Combat Animation Craft]].
- **Fists vs open hands**: R15 cannot close fingers. Imply a fist by turning the hand so the knuckle face shows; imply an open hand by flattening the wrist and turning the palm toward the camera.

## Posing creatures

Silhouette matters even more for creatures because players learn attacks by shape. Keep:
- A **unique wind-up silhouette per attack** so players can tell which one is coming.
- **Clear weapon limbs**: the claw, tail or head that will hit must be clearly separated from the body at the wind-up.
- **Readable at distance**: monster attacks are watched from 20 to 60 studs.
See [[Animating Creatures and Monsters]].

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Posing only in the side view | attack invisible from behind | check every key pose from the gameplay camera |
| Symmetric arms and legs | robotic | break symmetry everywhere |
| Weapon inside the silhouette | attack direction unreadable | move the weapon outside the body outline |
| Arms crossing the chest | forearm buried in the box torso | open the elbow out, move the hand forward |
| Overhead with straight arms | shoulders look pinned | lean back, bend elbows, keep it brief |
| Wrist doing the aiming | broken wrist | aim with the arm |
| Translation on limbs | dislocated shoulders | rotation only |
| Deep crouch authored at wrong scale | floating or sunk feet | author at game scale; shallow root drops |

## Checklist

- [ ] Clear line of action in every key pose
- [ ] Centre of mass over the base of support (unless falling)
- [ ] No twinning
- [ ] Weapon and off hand outside the body silhouette at key poses
- [ ] Reads from behind and at about 100 pixels tall
- [ ] Elbows hinge only, within range; wrists within range; arms not behind the back
- [ ] No limb translation
- [ ] Feet on the floor at game scale

## See also
[[Principles of Animation for Games]], [[Combat Animation Craft]], [[Weapon Swing Design]], [[Animation Quality Standard]], [[R15 Rig Anatomy and Attachments]], [[Elbow Poles Swivel and Joint Limits]], [[Spec-Driven Move Authoring]], [[Animation Review Checklist]].

## Connected notes
<!-- auto-links:start -->
[[Pipeline - Arm IK Baking and QA]] · [[Arm QA Metrics Reference]] · [[Weapon and Combat Animation]] · [[Snippets - IK]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Animation Start Here]]
<!-- auto-links:end -->
