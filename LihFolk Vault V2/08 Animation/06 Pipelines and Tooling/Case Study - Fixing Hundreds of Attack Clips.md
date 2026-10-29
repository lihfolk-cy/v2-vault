---
tags: [case-study, pipeline, arms, qa, ik, type/case-study, area/animation, level/advanced, api/Animator]
---
# Case Study: Fixing Hundreds of Attack Clips

<!-- tldr:start -->
> [!tldr] TL;DR
> - Per-key IK with no memory. A spec-driven baker solved each key independently with a numeric IK.
> - Targets inside the body. Specs placed the sword hand where the blade had to be at the hit, regardless of where the torso was...
> - The wrist aiming the blade. Where the arm could not reach the required blade direction, the solver bent the wrist.
> - The request was short: "arms in weird positions, especially in the Moves preview." The Moves preview plays each ability on a...
>
> Cost: TL;DR ~160 tok · whole note ~3.4k tok. Read more: ## Step 1: write the standard, then measure · ## Step 5: scale out, and what broke
<!-- tldr:end -->

How one live action game took its whole library of ability clips (several hundred moves across roughly a hundred weapon kits, built by several generations of tools) from "93% visibly broken arms" to zero criticals on everything it touched, without re-authoring the choreography. This is the story and the lessons; the workflow is [[Pipeline - Arm IK Baking and QA]], the algorithms [[Arm Baker Internals]], the metrics [[Arm QA Metrics Reference]].

## The complaint

The request was short: "arms in weird positions, especially in the Moves preview." The Moves preview plays each ability on a dummy in a slow, well-lit turntable view, so it showed everything the fast in-game camera hid:

- forearms and hands buried in the chest (mostly the sword forearm across the chest, and the free forearm tucked into it);
- the arm and blade whipping to a new place in a single frame;
- elbows that spun around the shoulder-wrist line;
- wrists bent 70-90 deg sideways to aim the blade;
- the blade passing through the body.

Nobody could say how many clips were affected, or which were worst. So step one was not fixing anything.

## Step 1: write the standard, then measure

Before touching a clip, a written standard defined "human arms" in measurable terms, each rule with a source: clinical joint ranges (adapted to what R15 joints can express), speed limits before a joint reads as a pop, arcs and smoothness, the kinetic chain of a strike (hips, chest, shoulder, elbow, wrist, blade, about one 30 fps frame per link), elbow pole directions by motion type, off-hand behaviour by context, clearance against the torso and head. Every rule was marked as either measured by QA, enforced by the baker, or both.

Then a QA scorer turned the standard into a 0-100 score with criticals, and every installed clip was **played on the real Animator** in Studio (60 Hz, joint Transforms read every frame) and scored offline.

### Baseline

| Measure | Value |
|---|---|
| moves | several hundred (about a hundred kits) |
| bad (score under 70 or any critical) | **93%** |
| median score | **31** (10th / 25th / 75th / 90th percentile: 13 / 20 / 48 / 71) |
| arm deeper than 0.6 studs in the body | about 84% of moves |
| arm pop over 50 deg in one frame | about 83% of moves |
| sword wrist past its range | about 97% of moves |
| blade through own body | about 82% of moves |
| elbow swivel flips over 70 deg | about a quarter of moves on each arm |
| median worst penetration | 1.33 studs (the forearm's half-width is 0.8) |
| median time with an arm deep in the body | 0.95 s per move |

By source framework the picture was clear: the newest, most "automated" frameworks were the worst (medians 12-23), the older hand-keyed sets were mediocre (median about 47), and two small sets of user-authored clips scored about 90. The worst move scored 0: a forearm 1.41 studs inside the chest for 2.92 s, the wrist turning 82 deg in one frame, the elbow swivelling 155 deg in one frame eight times, the free arm 82 deg behind the back.

**Lesson:** the numbers changed the conversation. "The arms look weird" became "more than four in five moves bury a forearm; fix penetration first, then pops, then wrists", and the clean user-authored kits set the realistic target (about 90).

## Step 2: diagnose why

Reading strips of the worst 40 moves showed three root causes, none of them "bad animators":

1. **Per-key IK with no memory.** A spec-driven baker solved each key independently with a numeric IK. Two nearby keys could land on different elbow branches, and the Animator then interpolated between them: the elbow spun around the arm in a frame or two.
2. **Targets inside the body.** Specs placed the sword hand where the blade had to be at the hit, regardless of where the torso was at that moment. With a 9.5-stud blade gripped 20% up, aiming at a point near the body put the forearm through the chest and the pommel into the hip.
3. **The wrist aiming the blade.** Where the arm could not reach the required blade direction, the solver bent the wrist. A blade lined up with the forearm needs about 90 deg of wrist deviation; a real wrist has about 30.

And a fourth cause found later: **the offline model of the Animator was wrong for big turns** (see step 6).

## Step 3: decide what to keep

Re-authoring several hundred moves was out. The decision that made the project tractable: **the body carries the choreography; re-derive only the arms.** Keep every hips, torso, head and leg key, every keyframe time, every marker (gameplay damage timing depends on markers: the server's hit time is the clip's marker minus 0.06 s). Re-solve the six arm joints from where the hand and blade should be, honouring the original exactly where it matters (near markers, on fast cuts, in holds) and improving it elsewhere.

## Step 4: build the baker, calibrate on six moves

The arm baker ([[Arm Baker Internals]]) solves every 60 Hz frame with exact two-bone IK over a grid of hand rolls and elbow swivels, prices each candidate (blade fidelity, wrist comfort, clearance, elbow direction), and picks one globally consistent path with Viterbi. Then it smooths in joint space, gives the free hand a hilt grip or a context behaviour, guards against flips, fits sparse Roblox keys, and respects a per-folder instance budget (2,500).

Phase-1 calibration on six representative moves (Animator truth before and after):

| Move type | Before | After | Criticals after |
|---|---|---|---|
| two-handed heavy | 40 | 73 | none |
| sparse legendary-tier clip | 13 | 72 | none |
| shared-framework move | 22 | 79 | none |
| 10 fps spec-baker move | 9 | 69 | none |
| dense two-handed move | 23 | 69 | forearm 0.78 into the chest, 0.25 s |
| ultimate | 0 | 38 | forearm 0.9 into the head, 0.05 s |

Model vs Animator on the written clips: 0.9-4.6 deg. Two moves were installed as proofs; the rest stayed in a test folder.

## Step 5: scale out, and what broke

The batch ran across six worker groups, each owning a set of kits, with a written how-to (dump, baseline, bake, look at strips, test-write, play, verify, install). Things that went wrong:

- **Studio froze for about 25 minutes.** About 18 baker processes, each with multi-threaded math libraries, plus simulations running inside Studio, pinned the CPU at 100%. New rule: at most two bakers per worker, single-threaded, no background simulations in Studio, Studio calls under 1.5 s and one at a time.
- **Near-budget kits.** Kits already near 2,500 instances forced the key tolerance up to 9x, and the coarse keys reintroduced criticals (26 criticals in one batch of near-budget spec-baker kits). Fix (baker v2): **body thinning** (drop body keys that playback reproduces within 0.75 deg / 0.03 studs) frees room for arm keys; **no-growth installs** let kits already over budget take a clip that does not grow the folder.
- **Keyed flips.** Even with a clean dense solve, key reduction occasionally produced a key-to-key arm turn over 120 deg, which the Animator plays as a flip. Fix: a dense flip guard, a continuous wrist-twist clamp, and a forced mid key for any segment over 120 deg; installs refuse `max_key_segment >= 120`.
- **Broken source poses.** Some clips had the grip inside the head or the blade through the chest exactly at a marker. The baker pushes the grip out (up to about 2 studs) and turns the blade up to 70 deg, which changes choreography at those frames. Policy: look at the strip; install only if the after strip reads right.
- **Re-posing.** For moves where the solve alone could not fix it, arm CFrames were edited in a copy of the dump over time windows, and the bake took that copy as targets (re-keyed sources, with a guard that only arm poses may differ from the live clip).
- **A second pose pass scored worse on six moves.** They were rolled back. Keeping before-dumps of every clip on disk made that a one-command operation.

### Install phase

Roughly **two thirds of the library** was installed as re-baked clips, all with **zero criticals in real Animator playback**. Skipped: bakes whose choreography changed too much, and about 14 moves still critical (two needed a redesign, not a bake).

## Step 6: the interpolation discovery

Two installed moves stubbornly scored 9-12 deg worse in the Animator than the baker's model predicted, always on the off-hand shoulder raised overhead. Not a clamp, not easing. The investigation measured the Animator directly on fresh plays and found it does **not** [[slerp]] [[quaternions]] between keys. It blends **rotation vectors** linearly (axis times angle from the joint's rest, using the pair of representations closest together). For small steps and joints near rest the two models agree; they part on big key-to-key turns of joints far from rest.

| Model | Error vs the Animator (15 fresh clips) |
|---|---|
| rotation-vector blend | at most 0.24 deg everywhere |
| quaternion slerp | up to 178 deg on big turns (146, 154, 175 deg on other moves) |

Every offline tool (sampler, key fitter, body thinner, flip guard, QA model mode) was switched to one shared interpolation setting defaulting to the rotation-vector model ([[How the Animator Really Behaves]]). Then every installed kit move was re-scored under both models. Scores shifted (one probaked move from 68.5 to 59.0, another from 68.2 to 76.2, matching the Animator's 76.3), and the re-score exposed a **backlog: a few dozen installed moves with criticals under both models that had never been probaked.**

**Lesson:** an offline model that is "almost" the engine is a liability exactly where clips look broken. Validate your model on the hard cases, not the average.

## Step 7: the backlog pass

The backlog used an improved toolchain: moves rebaked from their specs offline (no Studio baking), legs solved with analytic IK on the real 1.6x rig so planted feet stay within about 0.04 studs of the authored spot, the arm baker in-process with blade clearance extended to the pommel (the grip pushed out where the pommel would enter the torso or hips), and a polish stage scored by QA:

- **armfix:** shoulder and elbow keys turned out of the body per penetration window;
- **desnap:** body and leg pops smoothed in time, re-keyed only inside the pop windows;
- **scorefix:** local arm-key turns aimed at the worst remaining issues (blade through body, shoulder range);
- several **variants** per move (body push-out margins x1.4 or x1.8, in-body penalty x3), each polished within the kit's instance headroom, keeping the best under a fidelity guard (mean blade direction change at most 35 deg) with strips checked by eye.

Result: **every targeted move (a few dozen) at zero criticals and a score of 80 or more in the real Animator** (model vs Animator at most 0.24 deg on every clip; a fresh re-dump re-scored 80.0-97.4). Worst-first examples:

| Before | After |
|---|---|
| 1.7 | 81 |
| 3.3 | 84 |
| 6.9 | 88 |
| 9.5 | 87 |
| 10.1 | 94 |
| 10.6 | 83 |
| 20 | 87 |
| 20 | 92 |
| 22 | 85 |
| 52 | 80 |
| 59 | 88 |

All kit folders ended at or under 2,500 instances except four that were already over (they only shrank). Two user-authored moves stayed critical by policy: user-authored kits are the user's to change.

## What made it work

1. **A measurable standard before any fix.** Every argument about "looks better" became a number with a timestamp.
2. **Truth from the real Animator**, not from the model, for every reported score.
3. **Keeping the choreography** (body, timing, markers) and re-deriving only what was broken.
4. **Global consistency** (Viterbi over the whole clip) instead of per-key solves.
5. **Pricing what actually plays** (the clamped wrist, the reduced keys, the real interpolation).
6. **Hard budgets** enforced by the tool, not by review.
7. **Safe installs:** fingerprints against stale sources, a test folder, one safety copy, rollback, before-dumps on disk.
8. **Looking at strips.** Scores catch most problems; a human catches the choreography that the score cannot see.

## What it did not fix

- Legs and torso were never touched by the arm pass; their pops remain in scores.
- QA used a blocky dummy; slimmer avatars clear the body more easily, so live results are slightly better than the numbers.
- Live blending with the ability controller and replication were verified in Edit, not in a live play test.
- Authoring habits: new moves still need the pose lessons (flat wind-ups before thrusts, one-handed overheads with long pommels, a rest-like last key, no root-yaw swaps every 0.1 s). See [[Pipeline - Arm IK Baking and QA]].

## See also

[[Pipeline - Arm IK Baking and QA]], [[Arm Baker Internals]], [[Arm QA Metrics Reference]], [[How the Animator Really Behaves]], [[Animation Quality Standard]], [[Combat Animation Craft]], [[Studio Tooling Architecture]]

## Connected notes
<!-- auto-links:start -->
[[Spec-Driven Move Authoring]] · [[Elbow Poles Swivel and Joint Limits]] · [[Inverse Kinematics]] · [[Weapon Swing Design]] · [[AI Animation and Motion from Video]] · Case Study - Building a Game with AI Agents · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Animation Review Checklist]] · [[Posing and Silhouettes]] · [[LihFolk R15 Keyframe Pipeline]] · [[Pipeline - New Animated Weapon]] · [[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]] · [[Human Swing Biomechanics]] · [[Blade Grip and Wrist Limits]] · [[Keyframes, Easing and Interpolation]]
<!-- related:end -->
