---
tags: [authoring, review, checklist, qa]
---
# Animation Review Checklist

<!-- tldr:start -->
> [!tldr] TL;DR
> - Watch it in context first. On the real character, with the real weapon, at the real speed and priority, over the real idle and...
> - Hit frames land when design says. `Hit` markers sit on the contact frame; data tables (server hit times) match the markers.
> - Something moves on the input frame for player actions.
> - Secondary motion on dangling parts and the free hand.
>
> Cost: TL;DR ~130 tok · whole note ~2.9k tok. Read more: ## 3. Craft (should-fix) · ## 4. Technical safety (blockers)
<!-- tldr:end -->

A review pass catches problems before players do. This checklist collects every check from the authoring notes into one place, ordered the way a review actually goes: first "does it work in the game", then "does it read", then "is it well made", then "is it technically safe", then "is it shippable". Thresholds come from the reference project (one live action game) where marked; adjust distances if your character is a different size.

Use it as a gate. A clip with any **blocker** does not ship; **should-fix** items need a reason to stay; **polish** items are judgement.

## How to review

1. **Watch it in context first.** On the real character, with the real weapon, at the real speed and priority, over the real idle and locomotion. Not on a bare dummy in the editor.
2. **Watch from three views**: the player's camera (behind and above, 10 to 20 studs), a bystander's view (side, 30 to 60 studs), and the target's view (front).
3. **Watch at 1x, then at 0.25x, then step at 60 Hz.** 1x for feel, slow motion for arcs and contacts, single frames for pops.
4. **Look at a filmstrip** (key frames side by side). The reference project generated filmstrips for every baked clip; problems that hide in motion are obvious in a row of stills.
5. **Run the automatic checks** if you have them (see [[Animation Quality Standard]]). Numbers find what eyes miss; eyes find what numbers cannot score.
6. **Have someone else watch.** The author has seen the clip a hundred times and no longer sees it.

## 1. Gameplay (blockers)

- [ ] **Hit frames** land when design says. `Hit` markers sit on the contact frame; data tables (server hit times) match the markers. Reference project: server hits at marker time minus 0.06 s.
- [ ] **All markers present and named correctly** (`Hit`, `Hit2`, `TrailOn` / `TrailOff`, `Step`, `Tele`, cast markers, `CancelOpen` or your equivalents). Marker-driven effects fire once, not twice (full and upper-body copies both playing).
- [ ] **Cancel windows** are where design wants them; input buffering feels right.
- [ ] **Length** matches what balance assumed (clip length can feed damage and cooldown formulas).
- [ ] **Speed range**: if the clip plays faster or slower (attack-speed stats, `AdjustSpeed`), check it at the extremes.
- [ ] **Enemy telegraphs** are readable: at least about 0.45 s from telegraph to blow, 0.5 s or more for bosses (reference project).
- [ ] **Root motion** behaves: travel and lift are on the first child joint (the top-level root pose is never applied); gameplay-owned movement is not duplicated in the clip.
- [ ] **Loops** loop: the looping flag is set, and the seam is invisible at 60 Hz.

## 2. Readability (blockers for combat, should-fix otherwise)

- [ ] **Something moves on the input frame** for player actions.
- [ ] **Anticipation** reads and is the right length: about 2 to 6 frames at 30 fps for light player attacks, 6 to 15 for heavy (reference standard); longer and clearer for enemies.
- [ ] **Each key pose reads in silhouette** from behind and at small size (about 100 pixels tall).
- [ ] **The weapon and the off hand are outside the body's silhouette** at key poses.
- [ ] **The cut plane and direction are clear** from the player's camera and a bystander's.
- [ ] **Unique wind-ups** for different attacks of the same character or creature.
- [ ] **Effects line up**: trails only during the strike, impact effects and sound on the hit frame.

## 3. Craft (should-fix)

### Timing and spacing
- [ ] Strikes arrive at speed and decelerate **after** contact (the wind-up key carries In, the strike key carries Out).
- [ ] Not every key is InOut (no stop-start robot motion).
- [ ] No long Linear spans with big turns (reference QA: Linear arm segments over 0.12 s turning over 20 degrees, flagged at 3 or more).
- [ ] **Contact moving hold** of about 2 to 4 frames, then 4 to 8 frames of settle (reference standard).
- [ ] No **dead holds**: every joint under about 4 degrees/s for over 0.3 s, except at the end (reference QA).
- [ ] Weight reads through timing ratios (longer anticipation and recovery for heavy), not slow playback.

### Body mechanics
- [ ] **Kinetic chain**: hips lead, chest about 1 frame later, hand 2 to 4 frames after the hips (30 fps).
- [ ] **Balance**: the centre of mass over the support, unless deliberately falling.
- [ ] **No twinning**: arms and legs not mirror images (reference QA flags mirrored arm motion with r > 0.9 over 0.4 s).
- [ ] **The off hand has a job**: counter-swing, chamber, reach or guard (reference QA flags a left arm still for over 35% of hard-moving time).
- [ ] **Arcs**: hand and weapon tip trace curves; no corners outside contact (reference QA: velocity turning over 50 degrees, or speed changing over 75%, in one 60 Hz frame above 12 studs/s).
- [ ] **Overlap**: the head, free arm and dangling parts settle after the body stops.
- [ ] **Two-handed grips** behave: rear hand powers, hands stay on the hilt where it makes sense and let go where holding would bury an arm.

### Poses
- [ ] Line of action in every key pose.
- [ ] The head leads intent and stays fairly level through big motion.
- [ ] The blade is aimed by the **arm**, not by a bent wrist.

## 4. Technical safety (blockers)

### Joint ranges (reference standard, R15)
- [ ] **Elbows** are hinges: bend only about their own X, within 3 to 146 degrees; no hyperextension over 8 degrees (15 is critical); no sideways bend over 20.
- [ ] **Wrists** within flex 75, deviation 40, twist 95 (the bake target is 70 / 30 / 85).
- [ ] **Shoulders** not more than 48 degrees behind the frontal plane when raised (62 when low); never behind the back across the body.
- [ ] **No translation on limb joints** (over 0.05 studs reads as a detached shoulder).
- [ ] **Chicken wing**: the elbow not more than 0.55 studs above the shoulder while the hand hangs below it for 0.15 s.

### Collisions
- [ ] **Arms out of the body**: no forearm sunk more than 0.45 studs (bad) and never more than 0.6 for 0.05 s (critical), with the reference capsule and box sizes.
- [ ] **Blade out of the body**: including the pommel; no more than 0.25 studs into torso, hips, head, legs or the free arm.
- [ ] **Feet on the floor**: no foot through the ground in idles, crouches, drives or kneels at game scale; planted feet do not slide.
- [ ] **Death and lying poses** fitted to the ground (and to slopes at runtime if needed).

### Motion integrity
- [ ] **No pops**: no one-frame (60 Hz) turn of 30 degrees or more that is 3x its neighbours; no arm joint over 50 degrees in a frame (critical).
- [ ] **No wrist snaps**: under 30 degrees per 60 Hz frame relative to the forearm.
- [ ] **No elbow flips**: swivel jumps over 30 degrees in a frame (over 70 is critical).
- [ ] **No rest flash**: arms do not pass near rest (within 8 degrees) between poses far from it within 0.2 s.
- [ ] **No key-to-key turn over 120 degrees** on any joint, and **no exactly 180-degree turns** (ambiguous in the Animator).
- [ ] **Speed limits** respected outside strike frames (degrees/s: root 1,500, chest 1,100, head 1,000, upper arm 2,400, forearm 2,600, hand 2,200).

### Data correctness
- [ ] **No legacy `Cubic` easing** anywhere (it runs reversed).
- [ ] **Easing on the right keys** (a key's easing shapes the segment leaving it).
- [ ] **Root pose** at weight 0; travel and lift on LowerTorso (or the first child bone).
- [ ] **Root offsets at the game's character scale** (for characters scaled through body-scale values; on model-scaled rigs the Animator scales them for you).
- [ ] **Only intended joints keyed**: upper-body clips do not key hips or legs (even at rest); unused tracks deleted.
- [ ] **Pose names match the game rig** (typos are silently ignored).
- [ ] **Imported clips** have had any axis fix your importer needs (in the reference project: GLB enemy clips played turned 180 degrees until fixed).

### Entry and exit
- [ ] **First frame** within about 90 degrees per arm joint of the pose it blends from (usually the idle or the previous combo link).
- [ ] **Last frame** within about 75 degrees of the idle. Prefer ending on rest; a one-shot holds its last pose and fades over 0.3 s.
- [ ] **Combo links**: each swing starts on the pose the previous swing holds at its link.
- [ ] **Carry layer** hand-off: the carry pose equals the swing's end pose.

## 5. Shippable (blockers)

### Priority and layering
- [ ] **Priority** is right for the clip type (Idle / Movement / Action to Action4), and the lowest that works.
- [ ] **Upper-body copy** exists if the move is used while moving.
- [ ] **Fades**: short for combat (the reference project used 0.05 s), longer for locomotion (0.2 s).

### Publishing and loading
- [ ] **Published** under the experience's owner (user or group), or permission granted. No `RegisterKeyframeSequence` ids in shipped code.
- [ ] **Id stored as data** (attribute or table), not hard-coded in several scripts.
- [ ] **Upper-body copies and all clips of a rig published together.**
- [ ] **Default-animation replacements** have an `End` keyframe.
- [ ] **Preloaded** before first use (create tracks and call `ContentProvider:PreloadAsync` on equip or load).
- [ ] **Verified in a live server**, with `track.Length > 0` and a second player watching.

### Budget
- [ ] **Key density** reasonable (reference project: about 22 to 30 keys/s for normal moves, about 16 for long ultimates).
- [ ] **Folder instance budget** respected (reference project: 2,500 instances per ability kit folder).
- [ ] **Sources archived** outside the place; stubs left only where code needs metadata.
- [ ] **Generated scripts** under 200,000 characters per Source.

## 6. Polish (judgement)

- [ ] Secondary motion on dangling parts and the free hand.
- [ ] Breathing and weight shift in holds and idles; desynchronised between characters.
- [ ] Personality: does this move feel like *this* character or weapon?
- [ ] Consistency with the rest of the set (same READY pose, same timing language).
- [ ] Hit-stop, camera shake and effects tuned on top (runtime, not baked).

## Review notes template

Copy into your task tracker per clip:

```
Clip: <name>          Reviewer: <name>       Date: <date>
Context tested: character / weapon / speed / priority / over idle / over run
Blockers:
  - [time] <issue>    (category: gameplay / readability / technical / ship)
Should-fix:
  - [time] <issue>
Polish:
  - [time] <note>
Automatic QA: score __ / criticals __ / worst issues __
Verdict: ship / fix and re-review / rework
```

Always give **times** (in seconds or 30 fps frames) with notes. "The arm looks weird" costs the animator ten minutes of searching; "0.42 s, right forearm inside the chest from the back view" costs ten seconds.

## Most common findings (reference project's first audit)

Out of several hundred attack clips: wrist problems in **97%**, arms in body in **84%**, pops in **83%**, blade through body in **82%**; median score **31/100**. If you only have time for four checks, check those four.

## See also
[[Animation Quality Standard]], [[Principles of Animation for Games]], [[Combat Animation Craft]], [[Weapon Swing Design]], [[Posing and Silhouettes]], [[Publishing Animations]], [[Testing Animations in Studio]], [[Debugging Animation Problems]], [[Troubleshooting Table]].

## Connected notes
<!-- auto-links:start -->
[[Arm QA Metrics Reference]] · [[Animation Editor Workflow]] · [[Timing Spacing and Frame Charts]] · [[Spec-Driven Move Authoring]] · [[AI Animation and Motion from Video]] · [[Anticipation]] · [[Animation Start Here]]
<!-- auto-links:end -->
