---
tags: [authoring, craft, principles, game-animation]
---
# Principles of Animation for Games

The twelve principles of animation (Thomas and Johnston, *The Illusion of Life*) were written for film, where the animator controls every frame the audience sees. In a game the player controls timing, the camera moves, clips blend into each other, and the same attack is seen by the attacker, the target and bystanders at different distances and with network delay. Every principle still applies, but several change meaning.

This note goes through the twelve with their game translation and the Roblox-specific consequences, then adds the principles that only exist in games. Numbers are labelled: "reference project" means measured or standardised in one live action game; "rule of thumb" means common practice, not a law.

## The core tension: responsiveness vs readability

Almost every decision below is a trade between two things:
- **Responsiveness**: the time from the player's input to the result. Players feel delays of a few frames on attacks and movement.
- **Readability**: other players (and the attacker) understand what happened: what was swung, where, when it landed, and what it hit.

Film animation buys readability with time (long anticipation, long holds). Games cannot always afford time, so they buy readability with **pose clarity, contrast and effects** instead. Keep this in mind for every principle.

## 1. Squash and stretch

**Film:** volumes deform to show speed, impact and flexibility.

**Games and Roblox:** R15 and most Roblox rigs are rigid parts joined by joints. Parts cannot squash. You get squash and stretch from:
- **Pose**: compress the whole body (bent knees, curled spine) on landing and anticipation, extend it fully on the strike or jump apex.
- **Joint chains**: a spine bend and a neck lag read as squash at game distance.
- **Effects**: slash trails, smear meshes, motion blur and impact flashes stretch the *motion* rather than the body. See [[VFX Timing with Animation]].
- **Skinned meshes**: a bone rig with a soft body can genuinely squash by scaling bones, but scaled bones in Roblox clips are not standard Pose data; test before relying on it.

Rule of thumb: a landing that compresses the hips by 10 to 20% of leg length for 2 to 4 frames reads as weight; less reads as weightless.

## 2. Anticipation

**Film:** a preparatory move tells the audience something is coming.

**Games:** anticipation is **input delay** for the player's own character and **a warning** for everyone else. That changes it per role:
- **Player light attacks**: short. The reference project's standard uses **2 to 6 frames at 30 fps** for light attacks and **6 to 15** for heavy ones (practice values from game animation literature). Its light combo hit times were 0.20 to 0.217 s from input.
- **Enemy and boss attacks**: long and clear, because they are the player's cue to dodge. The reference project kept boss warnings and combo links at **0.5 s or more** and locked attack markers at least **0.45 s** before the blow.
- **Hiding anticipation inside the previous action**: in a combo, the follow-through of swing 1 *is* the anticipation of swing 2. The reference project's chain rule: every swing starts on the pose the previous one holds at its link.
- **Anticipation by pose, not time**: a deep, clearly shaped wind-up held for 3 frames reads better than a shallow one held for 8.

When not to add it: locomotion starts (players hate a delay before moving), menu animations, and anything triggered by the server where the client already saw the input lag.

## 3. Staging

**Film:** present the idea so it is unmistakable from the camera.

**Games:** you do not own the camera. Stage for the **gameplay camera**: on Roblox typically behind and above the character at 10 to 20 studs, with the player free to orbit. Practical consequences:
- Big actions should read from **behind**, not only from the side. A sword swing in a plane perpendicular to the camera's view vanishes into a line.
- Keep weapons and hands **out of the torso's silhouette** at key poses (see [[Posing and Silhouettes]]).
- Cinematic moves that take camera control (ultimates, cutscenes) can stage properly: the reference project used scripted multi-shot cameras for top-tier ultimates (see [[Cinematic Ultimates]]).
- Effects stage the action when the body cannot: a trail shows the arc that the camera could not.

## 4. Straight ahead and pose to pose

**Film:** two ways of working; pose to pose for planned acting, straight ahead for chaotic motion.

**Games:** pose to pose dominates because gameplay fixes key times (hit frames, link frames, end poses). Straight ahead survives in:
- **Procedural and physics motion** (ragdolls, cloth, springs), which is "straight ahead" by simulation. See [[Ragdolls and Physics-Based Animation]] and [[Springs Damping and Smoothing]].
- **Secondary layers** added after the main poses (hair, capes, the off hand's small reactions).

Spec-driven authoring (see [[Spec-Driven Move Authoring]]) is pose to pose taken to the extreme: the author writes only key poses and gameplay beats, and a baker generates the in-betweens.

## 5. Follow-through and overlapping action

**Film:** parts keep moving after the main body stops; different parts move at different rates.

**Games:** this is where most "stiff" game animation fails, and the most measurable principle:
- **Kinetic chain.** In a strike, motion travels hips > chest > shoulder > elbow > wrist > weapon. Biomechanics studies cited in the reference project's standard put pelvis-to-trunk lag at about 18 to 40 ms and trunk-to-elbow at about 55 to 65 ms, with each link 1.3 to 1.5x faster than the one before. In frames: **about 1 frame per link at 30 fps, 2 to 4 frames from hips to hand**.
- **Successive breaking** in code: the reference project's baker samples the waist, neck and free arm slightly in the past (lags of 0.015, 0.035 and 0.05 s) so they trail the root.
- **Follow-through in combat** must not lock the player. Keep the visual follow-through but allow cancels from it (see [[Combat Animation Craft]]).
- **Overlap at the end of a clip** is limited by blending: a non-looped track that ends holds its last pose and fades over 0.3 s (measured), so a long overlapping settle at the very end gets cut short. Put the settle before the final frames.

## 6. Slow in and slow out

**Film:** motion accelerates from and decelerates into poses.

**Games:** mostly yes, but with two important exceptions:
- **Strikes should not slow in to contact.** A cut that eases into the target looks like it stops before hitting. Strikes accelerate into contact and arrive at full speed, then decelerate *after* contact. In Roblox terms the easing stored on a key shapes the segment *leaving* it, so: the **wind-up key carries CubicV2 In** (the swing from wind-up to strike starts slow and arrives fast), and the **strike key carries CubicV2 Out** (the follow-through leaves fast and settles slowly). The hit marker sits on the strike key itself, the moment of peak speed. This is exactly the reference project's pose-library convention (wind-ups In, strikes Out, settles InOut). See [[Spec-Driven Move Authoring]].
- **Easing every key InOut makes robots.** Zero velocity at every key is stop-start motion. The reference project's QA calls this out explicitly and its key fitter chooses per segment among Linear, CubicV2 InOut, Out and In.

Remember the Roblox convention: the easing stored on a pose shapes the segment **leaving** that pose. See [[Keyframes, Easing and Interpolation]].

## 7. Arcs

**Film:** natural motion follows arcs.

**Games:** arcs are what make weapons and limbs read as driven by joints. Two specifics:
- **Hands and weapon tips must trace curves**, not straight lines with corners. The reference project's QA flags a "corner" when the grip's velocity turns more than 50 degrees (or its speed changes more than 75%) in one 60 Hz frame while moving faster than 12 studs/s, outside contact frames.
- **Arcs come from joint rotation, not from keys.** Interpolating joint rotations between two natural poses already produces an arc for the hand. Straight-line hand motion appears when you interpolate *positions* (for example with IK targets lerped in space) or when keys are too sparse with Linear easing.

## 8. Secondary action

**Film:** extra actions that support the main one (a character whistles while walking).

**Games:** secondary actions carry **personality** and **state** cheaply: a free hand flexing, a head turn toward a threat, a weapon twirl in an idle. Rules:
- They must never obscure the primary action's readability (no twirl during the active frames of an attack).
- The off hand is the most important secondary actor in weapon combat. A dead, hanging off hand is the most common giveaway of amateur sword animation. The reference project's QA flags a left arm still for more than 35% of the time the body is working hard, and its baker gives the free hand a context behaviour (counter-swing, chamber to the hip, reach, or guard).
- Layer secondary actions procedurally where possible so they vary (see [[Idle Breathing and Secondary Motion]]).

## 9. Timing

**Film:** the number of frames given to an action defines its weight and mood.

**Games:** timing is **gameplay data**. Hit frames, cancel windows, cooldowns and damage-per-second all depend on clip timing. In the reference project, an ability's damage floor was computed from `max(0.45 x cooldown, 1.2 x animation length)`, so making a clip longer changed balance. Consequences:
- Agree hit times with design before polishing. Retiming a hit means updating every table that stores it.
- Prefer to fix "feels slow" by changing **spacing** (more motion early, faster strike) before changing **timing** (moving the hit).
- Weight comes from timing ratios: a heavy weapon has a longer wind-up and recovery relative to its strike, not necessarily a slower strike. See [[Timing Spacing and Frame Charts]].

## 10. Exaggeration

**Film:** push poses and motion beyond reality for clarity.

**Games:** exaggerate **more** than film, because the character is small on screen, often seen from behind, partially hidden by effects, and blended with other clips (which averages poses toward neutral). Practical targets (rules of thumb):
- Wind-ups and follow-throughs with the weapon clearly past the body's silhouette.
- Spine twist and hip drop bigger than feels natural in the editor's close-up.
- Faster strikes (fewer frames) with bigger arcs.

Limits: exaggeration must stay inside joint ranges that the rig can show without breaking (see [[Animation Quality Standard]] for the R15 limits used: elbow 3 to 146 degrees, wrist flex 70, deviation 30, twist 85 degrees).

## 11. Solid drawing

**Film:** forms read as three-dimensional with weight and balance.

**Games:** the equivalents are **balance**, **weight distribution** and **no interpenetration**:
- The centre of mass sits over the support foot or between the feet, unless the character is deliberately falling.
- Limbs do not pass through the body. The reference project's first audit found arms inside the body in **about 84%** of attack clips and blades through the body in **about 82%**; these were the biggest single source of "looks wrong".
- Avoid **twinning** (left and right sides doing mirror-identical motion). It reads as robotic. The reference QA flags mirrored arms correlating above 0.9 over 0.4 s.

## 12. Appeal

**Film:** characters are pleasing and interesting to watch.

**Games:** appeal is **clarity plus character**: strong silhouettes, a consistent movement style per class or creature, and feedback that feels good (the "juice" of hit-stop, shake and effects timed to the animation). Appeal also means **consistency**: in a game with hundreds of moves, a shared pose library and shared rules (see [[Spec-Driven Move Authoring]]) keep every move feeling like the same character.

## Game-only principles

These do not appear in the classic twelve but decide whether game animation works. Jonathan Cooper's *Game Anim* frames the game-specific fundamentals as feel, fluidity, readability, context and elegance; the list below is in that spirit.

### Feel (input to response)
The first frames after input matter most. Move the weapon or body *immediately* on input, even if the "real" wind-up comes later. A 1 to 2 frame immediate reaction followed by anticipation feels responsive and still reads.

### Fluidity (blending and transitions)
Clips must start and end where other clips can take over:
- First frame within reach of the idle; last frame close to the idle (the reference project QA: within 90 and 75 degrees per arm joint).
- Combo links: each swing starts on the pose the previous swing holds at its link.
- Short fades for combat (0.05 s in the reference project), longer for locomotion (0.2 s).
See [[Playback, Priorities and Blending]].

### Readability for others (multiplayer)
Other players see your animation late (network delay) and from any angle. Make attacks readable without context: a clear wind-up shape, a clear strike plane, a trail, a sound on the hit. See [[Combat Animation Craft]].

### Context
The same action differs by state: an attack while running uses an upper-body copy so the legs keep running (the reference project published "Upper" variants of every attack). Hit reactions depend on direction. Idles depend on the weapon held.

### Elegance (systems, not clips)
Fewer, better clips reused through blending and procedural layers beat many one-off clips. A locomotion set driven by speed with one shared stride phase (as in the reference project) is more fluid than separate start, loop and stop clips for every case.

### Budget
Every keyframe costs instances on Roblox, every clip costs memory and load time, and every running track costs CPU. A beautiful clip that pushes a folder over budget is not finished. See [[Performance and Memory]].

## How the principles fail on Roblox specifically

| Failure | Principle broken | Roblox cause |
|---|---|---|
| Strike looks like it stops short | slow in/out misapplied | easing placed on the wrong pose (it shapes the segment leaving the pose) |
| Ease runs backwards | timing | legacy `Cubic` easing |
| Limb spins the wrong way on a big turn | arcs | Animator blends rotation vectors between unevenly spaced keys; turns over about 120 degrees or exactly 180 are unsafe |
| Character "drops" at clip end | follow-through | one-shot holds the last pose and fades 0.3 s to the layer below |
| Crouch has floating feet | solid drawing | root translation authored at the wrong character scale |
| Upper-body attack kills the walk | context | the clip keys hip or leg joints (even at rest) |

## See also
[[Timing Spacing and Frame Charts]], [[Posing and Silhouettes]], [[Combat Animation Craft]], [[Weapon Swing Design]], [[Animating Creatures and Monsters]], [[Idle Breathing and Secondary Motion]], [[Animation Quality Standard]], [[Animation Review Checklist]].

## Connected notes
<!-- auto-links:start -->
[[Animation Editor Workflow]] · [[Animation Start Here]] · [[AI Animation and Motion from Video]] · [[Squash Stretch and Anticipation in UI and Characters]] · [[Anticipation]] · [[Game Feel Start Here]]
<!-- auto-links:end -->
