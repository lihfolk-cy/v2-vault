---
tags: [pipeline, ik, arms, qa, baking, advanced, type/guide, area/animation, level/advanced, api/Animator]
---
# Pipeline: Arm IK Baking and QA

<!-- tldr:start -->
> [!tldr] TL;DR
> - These came out of reading hundreds of failing strips.
> - At most two baker processes per worker, single-threaded math libraries; no background simulations in Studio (a pile-up of...
> - Studio calls under 1.5 s: two moves per write call, four clips per play call.
> - `--all` on kits with an appended shared move that has no clip stops at that slot; bake per move instead.
>
> Cost: TL;DR ~130 tok · whole note ~3.7k tok. Read more: ## The pipeline · ## Pose lessons (what makes criticals, and how authors avoid them)
<!-- tldr:end -->

The end-to-end workflow one live action game used to repair the arms of several hundred ability clips: measure every clip on the real Animator, re-solve only the arms offline with exact IK, fit the result back into sparse Roblox keys within an instance budget, verify the written clip on the Animator again, and install it with a rollback path.

This note is the **workflow** (what to run, in what order, what to look at, when to stop). The algorithms are in [[Arm Baker Internals]]; every QA metric and threshold is in [[Arm QA Metrics Reference]]; the before-and-after story is [[Case Study - Fixing Hundreds of Attack Clips]].

## Why a dedicated arm pass

Ability clips in the reference project were authored by several generations of tools: hand-keyed sets, a spec-and-IK baker that sampled at about 10 fps, and later frameworks. The bodies (hips, torso, legs) mostly read well. The arms did not:

- forearms buried in the chest, free hands tucked into the ribs;
- elbows that spun around the shoulder-wrist line in one frame because a per-key IK picked the other branch;
- wrists bent 70-90 deg sideways to aim the blade;
- the blade passing through the body;
- one-frame pops of 50-250 deg.

The baseline measurement found **93% of moves "bad"** with a median score of 31/100. Fixing them by hand was not realistic, and re-authoring would lose the choreography. The insight: **the body carries the choreography; the arms can be re-derived from where the hand and blade should be.** So the pass keeps every body key, all timing and all markers, and re-solves only the six arm joints.

## The architecture in one paragraph

Studio does I/O only: dump clips, play them on the real Animator, write results. Python does the maths. One clip costs 10-40 s of offline CPU (40 s to 3 min with repair rounds) and about 0.1 s of Studio time. See [[Studio Tooling Architecture]] for the transport (local file server + receiver) and the call-budget rules.

## Reference conventions

All numbers in this pipeline assume:

| Item | Value |
|---|---|
| Rig | R15 dummy scaled 1.6x, about 9 studs tall |
| Arm part width | 1.6 studs |
| Upper arm (shoulder pivot to elbow pivot) | 1.48 studs |
| Forearm (elbow pivot to wrist pivot) | 1.29 studs |
| Space | HumanoidRootPart space: +X right, +Y up, -Z forward |
| QA sample rate | 60 Hz (authoring talks in 30 fps frames) |
| Held blade | along the hand's -Z, edge toward the hand's -X, 9.5 studs long, gripped 20% up from the pommel |
| Grip point | 0.19 hand-widths below the hand centre along its Y |
| Joints | [[AnimationConstraint]] on R15 rig attachments (FK: `parent * a0 * Transform * a1:Inverse()`) |

The 20% of blade behind the hand (the pommel) matters more than it sounds: about 1.9 studs of steel that can hit your own hip or chest. A pose that looks fine with a short-hilted sword buries the pommel with a long one.

## The pipeline

```
 1. index + dump        Studio: kit list, every clip's Poses, the rig, the idle        (once per session / after changes)
 2. play (truth)        Studio: every clip on the real Animator at 60 Hz               ("before" truth)
 3. baseline            offline: QA every clip -> score, criticals, worst timestamps
 4. bake                offline: re-solve arms, thin body, fit keys, budget, repair
 5. look                offline: filmstrip before / after, report fields
 6. test-write          Studio: build into a test folder; instance count must equal the prediction
 7. play test (truth)   Studio: the test clip on the real Animator
 8. verify              offline: model vs Animator (< 3 deg), QA of the real playback
 9. install             Studio: swap in, keep one safety copy (or rollback)
```

### 1. Dump

Three dump modes, each one POST per kit:

- `rig`: joints (attachment frames a0 / a1), part sizes, the grip attachment, every keyframe of the game's idle.
- `index`: kits, moves, folder instance counts, kit attributes (for example `TwoHanded`), a framework hint.
- `clips`: every KeyframeSequence exactly as stored: keyframe times and names, markers, and every Pose with name, weight, CFrame (rounded to 1e-5) and easing.

Re-dump a kit whenever anything else may have touched its clips. The installer refuses a bake whose source changed (fingerprint check), so a stale dump costs you a rebake, not a corrupted clip.

### 2-3. Truth and baseline

`play` runs each clip on a cloned, anchored dummy: `Animator:StepAnimations(1/60)`, fade 0, priority Action4, reading every joint's `Transform` each step (offsets divided by the rig scale). It also returns `loaded` and the track length. The offline QA then scores the **real playback**, not the model. That distinction matters: the model is only an approximation of the Animator, and a QA that scores the model can be fooled by the model's own errors.

A second QA mode scores clips through the offline Animator model without any Studio time. Use it for fast iteration; use truth for anything you report.

### 4. Bake

```
bake <kit> <Move> [--two-handed] [--tol 1.0] [--budget 2500] [--target N] [--repair-rounds 4]
                  [--no-thin] [--thin-rot 0.75] [--thin-pos 0.03] [--no-growth] [--src dir] [--interp rotvec|slerp] [--film]
bake <kit> --all  (share the kit's instance headroom across moves by length)
```

What the bake does, at a glance (details in [[Arm Baker Internals]]):

1. Derives targets from the original clip: grip point, blade direction, edge, and an **importance** curve (high near markers, on fast cuts, in holds).
2. Pushes targets out of the torso, hips and head; turns blades that pass through the body.
3. Solves a grid of 24 hand rolls x 36 elbow swivels per 60 Hz frame with exact analytic two-bone IK, prices each candidate, and picks the cheapest smooth path through the whole clip with Viterbi.
4. Smooths in joint space (arcs), gives the free hand a hilt grip or a context behaviour, guards against flips.
5. Thins body keys, fits arm keys with Roblox easings, enforces an instance budget, and runs repair rounds on frames that still sink into the body.

Outputs per move: the installer payload, a report (before / after scores, fidelity, budget split), the clip exactly as it will be written (`after_dump`), and optionally a filmstrip.

### 5. Look before you install

Read these report fields every time:

| Field | Meaning | Worry when |
|---|---|---|
| `before.score` / `after.score` | QA score (0-100) | after < before + 15 |
| `after.critical` | list of critical issues | not empty |
| `fidelity.dev_mean` / `dev_max` | blade direction change (deg) where it mattered | mean > 15 or max > 60 |
| `fidelity.grip_mean` / `grip_max` | grip movement (studs) where it mattered | mean > 1.2 |
| `blade_dev_imp_max` | worst blade deviation in important frames | > 40: look at the strip |
| `grip_targets_pushed_out` | frames whose grip target was inside the body | large: the source pose was broken |
| `two_handed_frac` | share of the clip with both hands on the hilt | changed a lot from the source |
| `max_key_segment` | largest key-to-key turn of any arm joint (deg) | >= 120: never install |
| `split_before` / `split_after` | keyframes / arm poses / body poses / placeholders | instance growth where you did not expect it |

Then look at the filmstrip. Large `grip_targets_pushed_out` or `blade_dev_imp_max` usually means the **source** had a broken pose (the hand inside the head, the blade through the chest at a marker), and the baker had to change the choreography there. That is often the right call, but a human should see it.

### 6. Test-write

The Studio writer builds the clip into a test folder from the live clip (or its safety copy if the live one is already baked) and prints `baked N instances; python predicted N`. **The two numbers must match.** A mismatch means the offline simulation of the write and the real write disagree, which would make every budget calculation wrong.

### 7-8. Verify on the real Animator

Play the test clip through the Animator (four clips or fewer per call), then compare offline:

- `model_vs_animator_maxdeg`: the baker's own after-dump sampled through the offline model vs the Animator's playback, max over arm joints.
- The QA score of the real playback.

**Pass rules** (all must hold):

| Rule | Threshold |
|---|---|
| Model vs Animator | under 3 deg (up to about 5 on segments near 180 deg; check the strip) |
| Loaded | `loaded` is true |
| Criticals | zero |
| Score gain | after >= before + 15 |
| Fidelity | `dev_mean` <= 15 deg and `dev_max` <= 60 deg |

**Never install** when `max_key_segment` >= 120, when a new critical appears, or when the score went down.

If Animator playback is not available in your setup (permissions, a locked Studio), you can still ship carefully: the after-dump is scored by the baker itself, the Studio writer's instance count matches the prediction, and you label the result "verified on the model, Animator check pending".

### 9. Install and rollback

- `install` swaps the clip in by name and keeps **one** safety copy of the first original.
- It refuses if the kit folder would exceed 2,500 instances, unless the folder does not grow ("no-growth install" for kits already over budget).
- `rollback` restores the safety copy. `status` lists installed, test and safety clips.
- Baked clips carry `ProBaked = <version>`, `ProBakedFromInstances`, `KitId`, and `ProBakedRekey` for re-keyed sources.

**Re-baking an installed clip:** rollback, re-dump, bake, test, install. Never bake from a baked clip.

## Calibration numbers

The first install batch, played by the Animator (before = installed clip, after = test bake):

| Move type | Before | After | Criticals after |
|---|---|---|---|
| two-handed heavy | 40 | 73 | none |
| legendary-tier sparse clip | 13 | 72 | none |
| shared-framework move | 22 | 79 | none |
| 10 fps spec-baker move | 9 | 69 | none |
| dense two-handed move | 23 | 69 | right forearm 0.78 into the chest for 0.25 s |
| ultimate | 0 | 38 | right forearm 0.9 into the head for 0.05 s |

Model vs Animator on the written clips: 0.9-4.6 deg max. Later waves held a stricter bar: zero criticals with a score of 80 or more for one batch; 65+ (stretch 75+) for the broad pass. A later, better baker that also solved legs on the real game scale reached scores of 81-86 on moves that started at 1.7-10.6.

## Framework-specific expectations

| Source style | What it looks like | What to expect |
|---|---|---|
| 10 fps spec-baker clips (CubicV2 / Linear per joint, 300-700 instances) | arms often buried, elbows flip | big gains (baseline median about 20); folders near 2,000-2,400 so watch the budget |
| dense mocap-like clips (15-25 keys/s), often two-handed | many two-handed holds | auto-detect handles the hilt; check `two_handed_frac` |
| sparse hand-keyed clips (9-12 keys per clip) | long Linear spans | bake adds keys: +50-100% instances, still small |
| user-authored kits scoring about 89 | already good | leave them alone |
| kits already over the folder budget | | no-growth mode: body thinning usually makes room |

Body thinning yield also depends on the source: clips already reduced at 5 deg by their own baker gain 0-7%; dense older clips gain 25-45%.

## Pose lessons (what makes criticals, and how authors avoid them)

These came out of reading hundreds of failing strips. They are authoring rules as much as baking rules; see [[Combat Animation Craft]] and [[Weapon Swing Design]].

- **Arms behind the body**: sprint, surf and "load" poses.
- **Sprint into a thrust or cross-cut** drives the forearm into the torso. Use a flat wind-up first.
- **Backhand winds and two-handed low guards** put the forearm across the chest.
- **Root yaw swapping every 0.1 s** pops. In flurries, halve the root yaw and turn the waist more.
- **Long pommels**: make overhead, drive and kneel poses one-handed with the off hand out to the side; keep hands further from the body; carry the blade over the front with a "chop" key before every drive (a near-180 deg swing otherwise takes the short way back over the head).
- **Overhead, then chop, then drive into the floor** buries the arms. Use a shallow drive or two hands.
- **Salute-aloft ultimates and high-to-falling deep openers** bake badly; prefer overhead / chop / falling variants.
- **The last key should be rest** (arms like the idle). A "ready" end pose put the pommel in the hip; re-keying the end frames brought 22 of 22 moves to 0.08 s or less of blade-through-body.
- **Timing**: no grounded stance change faster than 0.12 s; sub-0.1 s segments that move hips or feet go Linear.
- **A wrist cannot aim a blade.** Lining the blade up with the forearm needs 90 deg of deviation; the wrist has 30. The arm must aim the blade.
- **No identity keys in a solve.** They flash a T-pose.

## Operating rules

- At most two baker processes per worker, single-threaded math libraries; no background simulations in Studio (a pile-up of about 18 multi-threaded bakers froze Studio for about 25 minutes).
- Studio calls under 1.5 s: two moves per write call, four clips per play call.
- `--all` on kits with an appended shared move that has no clip stops at that slot; bake per move instead.
- Keep before-dumps of every clip on disk for rollback, outside the place.

## Known limits

- QA runs on a blocky dummy. Avatars with slimmer arms clear the body more easily than QA says.
- Legs and torso are not touched, so pops there remain (they still count in the score).
- Live blending with the game's ability controller (Action4, 0.05 s fade-in) was not watched in Play.
- Some sources are broken enough that the hand misses its target by up to about 1.3 studs in a few poses.
- At tolerance 5.5-9x (tight budgets) the shoulder may drift 5-9 deg from the dense solve. QA still scores the written keys, because it plays them.

## See also

[[Arm Baker Internals]], [[Arm QA Metrics Reference]], [[Case Study - Fixing Hundreds of Attack Clips]], [[Studio Tooling Architecture]], [[Two-Bone IK Math]], [[Elbow Poles Swivel and Joint Limits]], [[Animation Quality Standard]], [[Spec-Driven Move Authoring]], [[How the Animator Really Behaves]], [[Open Questions]]

## Connected notes
<!-- auto-links:start -->
[[Posing and Silhouettes]] · [[Weapon and Combat Animation]] · [[Inverse Kinematics]] · [[Animation Review Checklist]] · [[AI Animation and Motion from Video]] · Voxel Characters - Proportions Joints and Rigging · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Pipeline - New Animated Weapon]] · [[LihFolk R15 Keyframe Pipeline]] · [[Authoring Clips in Code]] · [[Testing Animations in Studio]] · [[Keyframes, Easing and Interpolation]] · [[Animation Data from Blender to Roblox]] · [[Baked Clip Stubs and Archiving]] · [[Blade Grip and Wrist Limits]]
<!-- related:end -->
