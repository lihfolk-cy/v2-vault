---
tags: [authoring, craft, timing, spacing, frames, type/guide, area/animation, level/intermediate]
---
# Timing Spacing and Frame Charts

<!-- tldr:start -->
> [!tldr] TL;DR
> - Between two keys the Animator computes `alpha = easing(u)` where `u` runs 0 to 1 over the segment, then blends the two poses...
> - Mark the gameplay frames first (hit, cancel window, end).
> - Mark which segments must be fast (strike) and which slow (anticipation build, settle).
> - Note where in-betweens should be denser (fast arcs need more samples; the reference project's baker sampled strike segments...
>
> Cost: TL;DR ~140 tok · whole note ~3.4k tok. Read more: ## Spacing: what easing does between two keys · ## Frame charts for common game actions
<!-- tldr:end -->

**Timing** is how many frames an action takes. **Spacing** is how far things move from one frame to the next within that time. Two clips with identical timing (same key times) can feel completely different because of spacing (easing, breakdowns). Game animators reason in frames; Roblox stores seconds and plays at whatever frame rate the client runs. This note gives the conversions, the spacing maths of Roblox's easing styles, frame charts for typical game actions, and the Roblox-specific details that affect timing.

## Frames, seconds and what Roblox actually stores

- `Keyframe.Time` is a time in **seconds** (a float). There is no frame number in the data.
- The Animation Editor shows **seconds:frames** at **30 fps** by default (Roblox docs); the timeline's Frame Rate setting changes the grid only.
- The engine samples the clip at render time. On a 60 Hz client you see 60 samples per second; at 144 Hz, 144. Fast motion that looked fine stepped at 30 can show one-frame pops at 60.
- Track time is float32 (measured in the reference project), which only matters for very long loops.
- The reference project's code-built clips round key times to **1 ms**, and its QA samples at **60 Hz** while authoring talks in **30 fps frames**.

### Conversion table

| 30 fps frames | Seconds | 60 fps frames | Typical use |
|---|---|---|---|
| 1 | 0.033 | 2 | a smear, a one-frame accent |
| 2 | 0.067 | 4 | contact hold (short), a snap |
| 3 | 0.100 | 6 | fast transition; min. readable wind-up for a jab |
| 4 | 0.133 | 8 | contact moving hold (long) |
| 5 | 0.167 | 10 | light attack wind-up |
| 6 | 0.200 | 12 | input to hit for a fast light attack |
| 8 | 0.267 | 16 | settle after contact |
| 9 | 0.300 | 18 | dash; one-shot end fade on Roblox |
| 12 | 0.400 | 24 | heavy wind-up; boss i-frame window |
| 15 | 0.500 | 30 | minimum enemy telegraph for a boss (reference project) |
| 30 | 1.000 | 60 | a full ability |

Formula: `seconds = frames / fps`. To convert 30 fps frames to 60 fps frames, double them.

## Spacing: what easing does between two keys

Between two keys the Animator computes `alpha = easing(u)` where `u` runs 0 to 1 over the segment, then blends the two poses by alpha. The easing comes from the **first** pose of the segment (Roblox docs: "the easing style to use to reach the next Pose's value"). See [[Keyframes, Easing and Interpolation]].

The reference project measured CubicV2 as following TweenService directions: **In** = slow start, **Out** = slow end. Its formulas (cubic):
- In: `u^3`
- Out: `1 - (1 - u)^3`
- InOut: `4u^3` for u < 0.5, else `1 - (2 - 2u)^3 / 2`

### Spacing chart: one segment split into 6 frames
Percentage of the total move reached at each frame:

| Frame | u | Linear | CubicV2 In | CubicV2 Out | CubicV2 InOut |
|---|---|---|---|---|---|
| 0 | 0.000 | 0 | 0.0 | 0.0 | 0.0 |
| 1 | 0.167 | 16.7 | 0.5 | 42.1 | 1.9 |
| 2 | 0.333 | 33.3 | 3.7 | 70.4 | 14.8 |
| 3 | 0.500 | 50.0 | 12.5 | 87.5 | 50.0 |
| 4 | 0.667 | 66.7 | 29.6 | 96.3 | 85.2 |
| 5 | 0.833 | 83.3 | 57.9 | 99.5 | 98.1 |
| 6 | 1.000 | 100 | 100 | 100 | 100 |

What this tells you:
- **Cubic easing is strong.** CubicV2 Out covers 42% of the move in the first sixth of the time and then crawls; the last two frames move less than 4%. On screen that reads as "arrives early and sits". CubicV2 In barely moves for the first third.
- **Peak speed is 3x the average** for all three cubic shapes (the derivative of `u^3` at u = 1 is 3). So a 60-degree turn over 0.2 s with CubicV2 In peaks at 900 degrees/s, not 300. Keep this in mind against speed limits (the reference project's QA limits sustained arm speed to 2,200 to 2,600 degrees/s and flags any arm joint turning over 50 degrees in one 60 Hz frame).
- **InOut gives zero velocity at both ends**, so every InOut key is a full stop. Chains of InOut keys look robotic.
- **Linear gives constant speed** and a corner at each key where the speed changes abruptly.

### Getting softer easing than cubic
The enum has no "quadratic" or "sine". Options:
1. **Add a breakdown key** with Linear easing on both sides and place it to shape the spacing yourself (for example at 60% of the move at 40% of the time for a gentle ease out).
2. **Bake dense Linear keys** from any curve you like. The reference project did this for equip flourishes: keys joined by PCHIP per channel (no overshoot), then baked densely with Linear easing at a 0.3 degree tolerance, about 130 to 205 keys per clip. Expensive in instances; use only where it matters.
3. Use a **[[CurveAnimation]]** with Cubic tangents (see [[Animation Editor Advanced]]), if your runtime plays curve animations.

### A trap: the easing belongs to the leaving key
If you want the arm to *slow into* the guard pose, the Out easing goes on the key **before** the guard pose. Putting it on the guard pose itself shapes the move *after* the guard. Code generators make this mistake constantly; the reference project's early generator wrote the easing listed on frame i+1 onto frame i's poses to honour the convention "a key's easing is the shape of the move into it".

## Holds

Real bodies never freeze. A pose with zero motion for more than a few frames reads as a mannequin.
- **Moving hold**: keep a tiny drift (1 to 3 degrees on the spine and head, a settling of the hips) through the hold. The reference project's QA flags a **dead hold**: every joint under about 4 degrees/s for more than 0.3 s, except at the clip's end.
- **Contact hold**: 2 to 4 frames at 30 fps of near-zero velocity at impact, then 4 to 8 frames of settle (reference project standard, from game animation practice).
- **Hit-stop is not a hold.** Freezing both characters on impact is a runtime effect (pause or slow the tracks for a few frames), not baked into the clip. Baking it in makes the hit feel late whenever the hit misses. See [[Hit Reactions Stagger and Hit-Stop]].

## Frame charts for common game actions

All timings below are rules of thumb for a responsive third-person action game unless marked. They assume 30 fps frames.

### Light attack (player)
| Phase | Frames | Seconds | Notes |
|---|---|---|---|
| Immediate reaction to input | 1 | 0.03 | something moves at once |
| Anticipation | 2 to 5 | 0.07 to 0.17 | wind-up pose, CubicV2 In leaving it |
| Strike to contact | 1 to 3 | 0.03 to 0.10 | 1 to 2 smear frames |
| Contact (moving hold) | 2 to 3 | 0.07 to 0.10 | `Hit` marker at contact |
| Follow-through | 3 to 5 | 0.10 to 0.17 | CubicV2 Out leaving the strike key |
| Recovery to ready | 4 to 8 | 0.13 to 0.27 | cancellable |

Reference project, measured clip data: the sword and katana combos hit at **0.20 / 0.20 / 0.217 s** for the first three swings and **0.367 / 0.383 s** for the finisher lunge, with clip lengths of 0.42 / 0.42 / 0.47 / 0.62 s for one later set, and a minimum gap of 0.42 s between clicks.

### Heavy attack (player)
| Phase | Frames | Seconds |
|---|---|---|
| Anticipation | 6 to 15 | 0.2 to 0.5 |
| Strike | 2 to 4 | 0.07 to 0.13 |
| Contact | 3 to 4 | 0.10 to 0.13 |
| Recovery | 10 to 20 | 0.33 to 0.67 |

Reference project: heavy and staff chains hit at about 0.38 to 0.74 s with 0.6 to 0.7 s minimum gaps.

### Enemy attack (telegraphed)
| Phase | Seconds | Source |
|---|---|---|
| Telegraph (readable wind-up) | 0.45 s or more before the blow | reference project: markers lock at least 0.45 s before the hit |
| Boss warning / combo link | 0.5 s or more | reference project |
| Player dodge i-frames | 0.40 s (boss class) | reference project |
| Recovery (punish window) | as long as design wants | |

### Dash
Reference project: a 0.30 s dash lean clip with an extra key at 0.045 s (upper body pushed 45% further) and a settle at 0.255 s that goes 18% past upright before returning. That small overshoot made the dash read as momentum rather than a slide.

### Jump and landing
Reference project: the jump clip played 0.42 s after the Humanoid entered Jumping; a separate land clip played only after more than 0.3 s airborne (short hops skip it). Landing compression: 2 to 4 frames down, 4 to 8 frames recovery (rule of thumb).

### Locomotion cycles
Cycle timing comes from speed, not taste. With stride length `L` (distance per full cycle, two steps) and ground speed `v`, the cycle period is `T = L / v`. The reference project authored clips at fixed GroundSpeeds (Walk 11, Jog 22, Run 64 studs/s on a 1.6x R15) and played them at `rate = speed / GroundSpeed`, so the feet never slide at the authored speed. See [[Locomotion Systems]] and [[Procedural Gait and Footstep Planning]].

### Idles
Reference project: a **4 s** idle loop, with fidget variants after **10 s** of standing still and then every **16 to 26 s**, never the same variant twice running. Weapon-rig idles ran 8 s. See [[Idle Breathing and Secondary Motion]].

## Timing for weight and size

- **Heavier = longer anticipation and recovery, similar or slightly slower strike.** The strike of a greatsword is not slow; its build-up and its settle are.
- **Bigger = slower cycles.** For creatures of the same shape, natural cycle times scale roughly with the square root of size (a pendulum rule of thumb). The reference project slowed scaled enemies' walk clips by `0.85 / sqrt(scale)`.
- **Never slow a clip below what its silhouette supports.** The reference project's enemy rule: enemy animations never play below 1x speed, with one exception (a stagger hit at 0.5x). Playing a fast clip slowly shows every interpolation flaw.

## Playback speed changes timing

`AnimationTrack:AdjustSpeed(s)` and the speed argument to `Play` scale everything: hits, markers, fades inside the clip. Consequences:
- Marker times in seconds stored in data must be divided by the playback speed. The reference project read stance and draw marker times from a data table and kept clips at **0.6x or faster** so the gameplay dash fitted between "Draw" and "Cut" markers; its fast variant played clips at about **1.71x**.
- Speeding a clip up raises its joint speeds proportionally. A clip within speed limits at 1x may pop at 1.7x.
- If attack speed is a stat, author the clip at the fastest speed it will play and slow it down, or author at 1x and check the top speed against the QA limits.

## Spacing for arcs and smears

- **Even spacing along a curve looks mechanical.** Natural strokes speed up where curvature is low and slow down in tight turns (the two-thirds power law, cited in the reference project's standard). In a swing, the blade moves fastest through the straight middle of the cut and slows at the turnaround points.
- **At 1 to 2 frames per strike there is nothing to see.** The reference project's measured sword-tip speeds at impact were 1,000 to 2,000 degrees/s; at 60 Hz that is 17 to 33 degrees per frame. The eye fills the gap only if something shows the path: a trail, a smear mesh, or motion blur. Time the trail (`TrailOn` / `TrailOff` markers) to the strike frames only. See [[VFX Timing with Animation]].

## Charting a move before keying it

A frame chart on paper (or in a comment in a spec) saves rework:

```
Overhead chop, 30 fps, hit at frame 9
frame:  0    3    6   7    9   11       16        22
pose:  READY .  WIND  .  CHOP  HIT  FOLLOW    SETTLE  READY
ease:  InOut   In      In   Out       InOut
notes: hips drop first (0-6), blade over the front at 7 (chop key),
       Hit marker at 9, trail 7-10, cancel window opens at 16
```

Rules for charts:
- Mark the **gameplay frames first** (hit, cancel window, end).
- Mark which segments must be **fast** (strike) and which **slow** (anticipation build, settle).
- Note where in-betweens should be **denser** (fast arcs need more samples; the reference project's baker sampled strike segments every 0.035 to 0.045 s instead of the default 0.1 s).

## Diagnosing timing and spacing problems

| Symptom | Likely cause | Fix |
|---|---|---|
| Attack feels late | anticipation too long, or nothing moves on the input frame | shorten wind-up; add an immediate 1-frame reaction |
| Hit feels weak | strike decelerates into contact | move the deceleration after contact (Out on the strike key) |
| Motion feels robotic | InOut on every key | mix Linear and one-sided easing; add breakdowns |
| Pops at 60 fps but fine at 30 | a one-frame turn of 30+ degrees | add an in-between; spread the turn over more frames |
| Floaty | keys too far apart with InOut; no holds or contrast | add contrast: faster strikes, longer holds |
| Looks fine in editor, wrong in game | playback speed, priority or fade | check [[AdjustSpeed]], fades and the clip end |

## See also
[[Principles of Animation for Games]], [[Keyframes, Easing and Interpolation]], [[Combat Animation Craft]], [[Weapon Swing Design]], [[Animation Quality Standard]], [[Hit Reactions Stagger and Hit-Stop]], [[Locomotion Systems]], [[Spec-Driven Move Authoring]].

## Connected notes
<!-- auto-links:start -->
[[Animation Editor Workflow]] · [[Animation Review Checklist]] · [[Easing]] · [[Authoring Clips in Code]] · AI Animation and Motion from Video · Anticipation · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Locomotion and Melee Reference Numbers]] · [[Animating Creatures and Monsters]] · [[Combat Combo Systems]] · [[R15 Run Cycle Key Poses]] · [[Animation Capture and Mocap]] · [[Snippets - Building and Sampling Clips]] · [[Animation Glossary]] · [[Playback, Priorities and Blending]]
<!-- related:end -->
