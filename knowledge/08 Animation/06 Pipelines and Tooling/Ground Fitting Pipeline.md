---
tags: [pipeline, enemies, ground, ik, procedural, death]
---
# Ground Fitting Pipeline

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Lifting the whole body to fix one limb. The body floats by exactly the limb's depth.
> - Avoid: Deciding fold direction per frame. A leg folds one way, then the other: a pop.
> - Avoid: Fixing poses without smoothing the corrections.
>
> Cost: TL;DR ~100 tok · whole note ~3.6k tok. Read more: ## Part 1: the clip fitter · ## Part 2: the runtime clamp · ## Common mistakes
<!-- tldr:end -->

How one production game stopped its creatures sinking into the floor: an **offline-style clip fitter** that rewrites keyframes so nothing goes under a flat floor at any time (folding limbs, draping bodies that are down, raising the body only as a last resort), plus a **runtime clamp** that handles slopes and raised floors the fitter cannot know about. It took the worst death-clip penetration from -9.37 studs to at or above 0, then fitted 205 more clips. Related: [[Foot Placement and Ground IK]], [[Procedural Death Knockdown and Hit Reactions]], [[Pipeline - Importing Animated Enemies]].

## The problem, measured

Death clips (2.4 s for regulars, 3.0-3.4 s for bosses) drop the root to the floor without folding legs, wings or tails, so limbs go through the ground. The old runtime fix lifted the whole body so its lowest corner sat on a flat "death floor" plane. That removed penetration on flat ground but made bodies **float** by the same amount: a dead creature propped 8.8 studs up on stiff legs, another balanced on one wing. On slopes and raised visible floors it still clipped.

Worst penetration of the raw death clips on flat ground (16-stud enemy):

| Rig | Worst | Part | Rig | Worst | Part |
|---|---|---|---|---|---|
| scorpion-like | -9.37 | sting glow | winged beast | -8.85 | wing |
| root creature | -8.71 | foreleg | reef stalker | -7.69 | legs |
| eye cluster | -7.26 | tentacle | choir wraith | -7.02 | hand |
| geode brute | -6.93 | abdomen | ice warden | -7.36 | axe glow |
| mantis | -4.21 | leg glow | biped stalker | -3.87 | foot |
| fire hound | -3.45 | back leg | sentinel | -3.82 | leg |

Three independent sources of ground error showed up, and each needs its own fix:

1. **Authored clips that dip** (deaths, and later hit reactions, staggers, knockups: 1-4 studs; run cycles up to 2.6). Fix in the data: the fitter.
2. **Wrong standing height**: incorrect HipHeight on 17 enemy templates (one rig's legs 1.5 studs into the floor at idle; others 0.45-0.9). Fix in the templates: correct HipHeight (old value kept in an attribute).
3. **The visible floor is not the logical floor**: a plaza's pavement 1.46 studs above the invisible navigation floor everywhere, aprons and kerbs +0.3 to +1.0, dais stones and mounds +0.5 to +2.7, terrain slopes of 16-34 deg in some zones. Fix at runtime: raycast the visible ground; tag visible floor parts so navigation includes them.

## Part 1: the clip fitter

The fitter takes a KeyframeSequence, a rig and a ground height, and returns a fitted clip where no part corner goes below `ground + 0.08` studs at any time. The 0.08 margin absorbs the Animator's in-between interpolation.

### Rig analysis

Joints (Motor6Ds) are classified by the moving part's lowercase name:

| Role | Name contains | Treatment |
|---|---|---|
| root | Part0 is the root part | carries body lifts |
| core | hips, spine, chest, torso, thorax, body, back, core, carapace, shell, eye, halo, ring | its parts define "the body"; if they dip, raise the whole body |
| head | neck, head, skull, mask, jaw, maw, screen | folds, limit 55 deg |
| limb | everything else | folds, limit 125 deg |

A **chain** is a limb or head joint whose parent is the root or a core joint (a leg, a wing, a tail, a claw arm). Each chain's joints are listed parents first; held props (axe, shield, trident, lantern, weapon) ride along but never fold themselves. Welded detail parts count as part of the joint they are welded to. Invisible parts (`Transparency = 1`) are ignored.

"Lowest point" always means the lowest **corner of a part's box** (8 corners), not its centre, because a flat wing's centre can be well above the floor while its tip is through it.

### Fitting one moment (5 steps)

Given the original pose at time t and the folds carried from the previous moment:

**1. Core first.** If any core part is below the target height, raise the whole body by the difference (a translation on the root joint, in its own frame). Lifts are per moment, not carried.

**2. Fold chains out of the ground.** For each chain whose lowest corner is below target (two passes, because folding one chain can move another):

- Decide the chain's **mode** once per clip, from the clip's **last** pose (where deaths end up): the chain is **lying** if its root pivot is closer to the ground than 0.45 x the distance from the pivot to its lowest point. Deciding once keeps a fold from changing topology halfway through.
- **Kneeling** (not lying): bend from the far joint first (knee, then hip): a kneeling leg folds at the knee.
- **Lying**: turn the whole limb at its root first: a limb on the ground lies along it.
- For each joint in that order, until the chain clears:
  - choose an **axis**: keep the axis this joint already folds about if it still lifts (sticky preference, so a fold never flips direction); otherwise the axis that lifts the lowest point most directly (perpendicular to the pivot-to-point vector and up). If that vector is nearly vertical, fall back to a sensible direction by limb type: legs fold toward the back, arms toward the front, others away from the body centre.
  - find the **smallest angle** about that axis that lifts the point to the target: step 2 deg at a time up to the joint's remaining limit (125 deg limbs, 55 deg heads, minus what is already folded), then bisect 12 times between the last failing and first passing angle. If no angle clears, take the angle that lifts it most.
  - apply it as a rotation in the joint's own frame: `delta = B^-1 * R(axis, angle) * B`, where `B` is the joint frame's world rotation, and accumulate it onto the joint's carried fold.

**3. Relax.** A fold the ground no longer needs shrinks by a factor of 0.9 per 1/30 s, but only if the joint's parts stay above target after shrinking. Folds under 0.5 deg are dropped. This is what lets a leg unfold smoothly as the body rolls off it, instead of staying bent forever.

**4. Drape.** A body that is down should not hold its legs stiffly in the air. With `lying = clamp(1 - coreClearance / (0.3 * bodyHeight), 0, 1)`, each limb joint may turn down toward the ground by up to `80 deg x lying`, but only as far as the floor allows (7-step bisection on clearance). The drape axis is kept per joint in its own frame, and its angle changes at a limited rate (260 deg/s growing, 1.6x that shrinking). Cloth-like parts (shroud, skirt, cape) never drape; they keep their own hang.

**5. Whatever is still under: raise the body** by the remaining depth.

### Fitting a whole clip

- **Sequential.** Moments are fitted strictly in time order, each starting from the folds of the one before, so neighbours always agree.
- **Moments = every keyframe, plus inserted ones.** After a pass, each gap between fitted moments is sampled at 7 interior points (interpolated between the fitted poses); where the interpolation still dips below the floor, a new moment is inserted at the worst point. After round 5, a stubborn gap is instead filled evenly (every 6 ms, 2-6 new moments). Up to 12 rounds.
- **Loops are warm-started.** For a looping clip (idle, walk, run, stun), two warm-up passes run first so the clip starts with the folds its own end needs, and the seam matches. If the original closes the loop (first and last poses equal), the fitted last pose is set equal to the fitted first.

### Smoothing the corrections

Folds that had to appear within one frame would snap. So the **corrections**, not the poses, are smoothed in time:

- per joint and moment, the correction is `fitted * original^-1`, stored as a rotation vector plus a translation;
- each correction is replaced by a Gaussian-weighted average over neighbouring moments (sigma **0.06 s**, window 3 sigma), each weighted also by its spacing so clusters of inserted moments do not dominate; loops wrap the time difference;
- the smoothed correction is re-applied to the original pose;
- anything that now dips is fixed by a root lift.

The result: a fold starts a moment early and eases in, so no new pops. Across 205 clips, the fastest joint rotation never exceeded `max(1.6 x the original's, 700 deg/s)`.

### Writing back: key only what changed

Each joint is keyed only over the **stretch where its pose changed**, plus one unchanged moment on either side to pin the original curve. Inserted moments become new Keyframes only if some joint needs a key there. New poses are Linear (dense, so Linear between them is accurate). The clip grows only where the ground needed it.

### Checking

After writing, the clip is played densely (every 0.02 s) through the same sampler and the worst clearance reported with the time and part. Original clips are kept until the result is verified.

## Results

| Pass | Before | After |
|---|---|---|
| 18 death clips, flat floor | worst -1.95 to -9.37 (or floating up to 8.8 with the old lift) | **>= 0.00** with no lift needed |
| 205 other clips, 18 rigs | 206 of 304 clips went under the floor; worst -7.79 (an attack), -4.41, -3.82 (a stagger), -3.50 (a stun), -3.23 (a block) | worst **-0.17**; eight more between -0.11 and -0.003; everything else >= 0 |
| loops | seams | seam 0.00 |
| cost in instances | | +3k for deaths; +25,780 for the 205 clips |

Skipped on purpose: a dodge clip whose whole body sinks 9.7 studs (a "vanish" move, not clipping), and attacks that strike the ground by design. Death clips kept their timing and upper-body acting; only limbs and lifts changed. The fitter takes about 2 s per clip in short, resumable Studio slices.

## Part 2: the runtime clamp

The fitter assumes a flat floor at the root's ground height. Real floors slope and step. While an enemy is dying or being thrown around by a scripted sequence, a runtime layer keeps it above the **visible** ground:

1. **Sample the ground once** per death or catch: a **5 x 5 grid** of downward raycasts over the body's footprint (half-size = 0.75 x the largest body dimension, plus 1 stud). A hit counts if it is terrain, or a part that is visible (`Transparency < 0.9`) and collidable; anything else (water planes, effects, veils) is added to the exclusion list and the ray continues, up to 6 times. Misses fall back to the feet height.
2. **Fit a plane** to the 25 heights by least squares (`y = a x + b z + c` in grid-local coordinates); its normal is the slope. A fit steeper than 40 deg is treated as a wall or a prop edge and replaced by flat.
3. **Look up heights** by bilinear interpolation inside the grid, and from the fitted plane outside it.
4. **Tilt a body that is down** onto the slope, in proportion to how far through its death clip it is (`deathProgress` 0..1; sequences stay upright), rotating about the ground point under the body centre.
5. **Lift** by whatever still dips: `need = max(0, 0.06 - clearance)`. Rise instantly, **settle back at 6 studs/s**, so a limb swinging past a bump does not make the body flicker up and down.
6. Resample the grid only when the body moves more than 0.45 x the grid half-size from where it was sampled.

| Test (16-stud enemy) | Before (original clip + old flat lift) | After |
|---|---|---|
| 20 deg slope, facing uphill / downhill / sideways | worst -6.42; every rig -0.43 to -6.42 | +0.06 every rig, every facing |
| raised visible floor (+1.46) | -1.40 every rig | +0.06 every rig |
| scripted catch: survive / die at blast / die while held / thrown and die | the old clip slammed into the floor | >= +0.04 every rig |

Cost: the clamp runs only for reacting or dying enemies within 320 studs of the camera; 46-90 microseconds per enemy per frame including the procedural motion; no per-frame allocations (the grid is sampled once, buffers reused).

### Bone rigs: the adapter

Skinned rigs have no part boxes to test. A bone adapter samples a **3 x 3** ground-height grid, finds the deepest bone, and lifts the Root bone by `deepest bone depth - skin pad` (the pad approximates mesh thickness around bones), with a tilt taken from the clip's fall marker. It runs in the Lua player's after-step hook, right after the frame's joint writes ([[Lua Keyframe Player Internals]]).

## Part 3: floor data hygiene

- **Fix HipHeight** so idle feet sit on the floor. Measure: play the idle, find the lowest corner, compare to the ground under the root. 17 templates were corrected by -0.23 to +0.76 studs (at authored scale).
- **Tag visible floors** that differ from the navigation floor (a CollectionService tag the navigation ground query includes). On the plaza, enemies went from standing at 4.00 (sunk into the pavement) to 5.46-5.78 on the pavement and medallions.
- **Measure before building slope fits.** A sweep of 8 rigs' idles at 187 spots each against the real visible ground found zero terrain penetrations in zones with enemies (terrain within +-0.36 studs of the logical floor); every dip was a prop (mounds, craters, rocks, kerbs, pool rims). The steep terrain was only in zones without enemies yet, so a per-limb slope fitter was not needed.

## When to use which

| Situation | Tool |
|---|---|
| a clip dips on flat ground | clip fitter (offline, once) |
| a body lies on a slope or step at runtime | runtime clamp |
| idle feet sink or float | HipHeight |
| the floor you see is not the floor navigation uses | tag the visible floor |
| live foot contact while walking on uneven ground | runtime foot IK ([[Foot Placement and Ground IK]]) |

## Common mistakes

- **Lifting the whole body to fix one limb.** The body floats by exactly the limb's depth. Fold the limb.
- **Deciding fold direction per frame.** A leg folds one way, then the other: a pop. Carry folds and keep axes sticky.
- **Fixing poses without smoothing the corrections.** A fold that appears in one frame is a new pop.
- **Testing against the logical floor only.** Players see the visible one.
- **Fitting clips that touch the ground on purpose** (ground slams, vanish moves). Skip them explicitly.

## See also

[[Foot Placement and Ground IK]], [[Procedural Death Knockdown and Hit Reactions]], [[Pipeline - Importing Animated Enemies]], [[Enemy and NPC Animation]], [[Springs Damping and Smoothing]], [[Lua Keyframe Player Internals]]

## Connected notes
<!-- auto-links:start -->
[[Creature Rig Conventions]] · [[Snippets - IK]] · [[Animating Creatures and Monsters]] · [[Animation Capture and Mocap]] · [[Character and Creature Pipeline]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Animation Start Here]]
<!-- auto-links:end -->
