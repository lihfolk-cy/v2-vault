---
tags: [fundamentals, keyframes, easing, interpolation]
---
# Keyframes, Easing and Interpolation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Easing set on the arriving key -> Put it on the leaving key
> - Avoid: Legacy `Cubic` -> `CubicV2`
> - Avoid: Key-to-key turns near 180 deg -> Mid keys; stay under 120
>
> Read more (12 KB note): ## Easing styles and their real shapes · ## Rotation interpolation: not slerp · ## Common mistakes
<!-- tldr:end -->

Between two keys, the Animator has to invent every frame. How it does that (which key's easing applies, what shape each easing has, how rotations are blended) decides whether your clip plays the way you authored it. Most of this is undocumented or documented wrongly, and one of the rules (rotation interpolation) changes depending on how your keyframes are spaced. This note is the practical guide; the raw measurements and the model code are in [[How the Animator Really Behaves]].

## The segment rule

For each joint, its keys are the Poses with `Weight > 0`, sorted by time. Between key k and key k+1:

```
u      = (t - t_k) / (t_{k+1} - t_k)        -- 0..1 through the segment
a      = ease_k(u)                          -- key k's EasingStyle + EasingDirection
offset = lerp(p_k, p_{k+1}, a)              -- positions: plain lerp with the eased alpha
rot    = interpolate(R_k, R_{k+1}, a)       -- rotations: see "Rotation interpolation"
```

- **The easing comes from the segment's first key.** The easing you set on the last key of a joint never does anything. The docs phrase it as "the easing style to use to reach the next Pose's value".
- A joint with no Pose at a keyframe simply has no key there: it interpolates across that keyframe between its own neighbouring keys.
- Before the first key the joint holds the first key; after the last key it holds the last.

If you think in "how does the motion arrive at this key" (most animators do), you must write each key's easing onto the **previous** key. One production clip builder did exactly that, with the comment: "a key's easing is the shape of the move INTO it, so the leaving pose carries it".

## Easing styles and their real shapes

`Enum.PoseEasingStyle`: `Linear` (0), `Constant` (1), `Elastic` (2), `Cubic` (3), `Bounce` (4), `CubicV2` (5). `Enum.PoseEasingDirection`: `In`, `Out`, `InOut`.

Measured shapes (one production project, playing test clips on the real Animator and fitting the curves), with `u` in 0..1:

| Style | In | Out | InOut |
|---|---|---|---|
| `Linear` | `u` | `u` | `u` |
| `CubicV2` | `u^3` (slow start) | `1 - (1 - u)^3` (slow end) | `4u^3` below 0.5, else `1 - (2 - 2u)^3 / 2` |
| `Cubic` (legacy) | **plays as Out** | **plays as In** | InOut |
| `Elastic` | Penner elastic-in, period 0.3 | elastic-out | Penner InOut, period 0.45 |
| `Bounce` | bounce-in | bounce-out (the standard 7.5625 / 2.75 bounce) | **BounceIn's shape on both halves** |
| `Constant` | **jumps to the next key immediately** | **holds this key until the next** | jumps at the midpoint |

### Legacy Cubic is reversed
`PoseEasingStyle.Cubic` with direction `In` eases **out** (fast start, slow end), and `Out` eases in. `CubicV2` exists to fix this and follows the same directions as TweenService. Never write legacy `Cubic` from code. If you have old clips with it, convert: `Cubic In -> CubicV2 Out`, `Cubic Out -> CubicV2 In`, `InOut` unchanged. One project found that its early weapon sets had written legacy Cubic with directions chosen as if they were TweenService directions, so those segments played with the opposite feel from what the author intended.

### Elastic and Bounce: an open contradiction
The most recent measurement (above) found Elastic and Bounce follow their stated direction (not reversed). An earlier offline tool and a weapon-rig player in the same project assumed they were reversed like legacy Cubic. The production pipeline never used them, so this was never settled by a shipped clip. Test on your own rig before relying on them, and see [[Open Questions]].

### Constant: three behaviours, contradictory docs
Measured: `In` jumps to the next value at the start of the segment, `Out` holds the old value until the next key, `InOut` jumps at the midpoint. The official docs contradict each other on Constant. Two tools in the same project also disagreed (one treated every Constant as "step to the next pose", another as "hold"), which is listed in [[Open Questions]]. For hold-then-snap anime timing, `Constant Out` on the key **before** the snap is the one that matches intuition.

## Rotation interpolation: not slerp

Measured on the real Animator with `StepAnimations`:

- **Quaternion nlerp (shortest way)** when **all keyframes in the sequence are evenly spaced** (marker-only keyframes count toward spacing) **and every key is Linear**.
- Otherwise, a **linear blend of rotation vectors**: each key's rotation is turned into axis x angle relative to the joint's rest; of each key's two equivalent vectors (`v` and `v - 2*pi*axis`) the pair closest together is chosen; the vectors are lerped with the eased alpha and turned back into a rotation.
- Even inside an evenly spaced sequence, an **eased** segment blends rotation vectors.

### Why it matters
For small steps the two models are indistinguishable. For big turns of joints already far from rest they are not:
- An off-hand shoulder swinging overhead differed by 9 to 12 degrees from slerp mid-segment.
- On 15 freshly played clips a rotation-vector model matched within 0.24 degrees everywhere, while a slerp model was up to 178 degrees off (a shoulder at 178; other moves at 146, 154, 175).

Intuition: lerping rotation vectors traces a straight line in "axis x angle space" from rest, which is not the shortest arc between the two orientations unless one of them is the rest pose or both share an axis. The further both keys are from rest and the more their axes differ, the more the path bows.

**Practical rules:**
- Any tool that predicts playback (samplers, IK bakers, key thinners, QA) must use the same model, or its "verified" clip will play differently. Give the tool one switch for the interpolation model and default it to rotation vectors.
- Keep every key-to-key turn **under about 120 degrees**. Add a mid key otherwise; one IK baker inserted a mid key on any segment over 120 degrees.
- **Never key exactly 180 degrees** between neighbours. Both directions are equally short and the Animator effectively picks one at random; three enemy clips that did this were the only parity failures in a 350-clip test. Use 179, or add an in-between key that commits to a direction.
- Watch overhead-to-floor swings: near 180 degrees the blade can "take the short way back over the head" and arrive pointing up on the impact frame. One team's fix was an explicit "chop" key bringing the blade over the front before the drive.

### Even spacing is fragile
The nlerp case needs **every** keyframe evenly spaced. If you bake at 30 fps and round keyframe times to 1 ms (as one builder did), the gaps become 0.033, 0.034, 0.033 s: in a strict test that is uneven, and one marker keyframe off the grid also breaks it. One Lua re-implementation used a 0.1 ms tolerance for "even". The real Animator's tolerance is unknown, so do not design anything that depends on getting the nlerp mode; just make your tools model rotation vectors for real-world clips and nlerp for strictly regular bakes.

## Easing choices for game animation

| Purpose | Easing (on the key that starts the segment) | Notes |
|---|---|---|
| Wind-up / anticipation | `CubicV2 In` | Slow start, accelerating into the strike |
| Strike | `CubicV2 Out`, denser in-betweens | One spec framework used 0.045 s in-between spacing on strike spans versus 0.1 s elsewhere |
| Settle / recovery | `CubicV2 InOut` | |
| Spins, constant motion | `Linear` | |
| Baked data (IK, physics, mocap) | `Linear` | Every frame or adaptively keyed |
| Snap poses, smear-free hits | `Constant` | Know which direction you are getting |
| Cartoony settle | Prefer authored overshoot keys (or a dense Linear bake) over `Elastic`/`Bounce` | Their direction behaviour is disputed |

Timing rules from one production pass on sword clips:
- No grounded stance change faster than 0.12 s.
- Segments shorter than 0.1 s that move hips or feet go Linear, with the first one easing In.

## The dense Linear bake: when Roblox easing is not enough

For complex motion (equip flourishes with blade spins and tosses), one game gave up on Roblox easing entirely:
1. Interpolate the authored keys itself, per channel, with a monotone cubic (PCHIP) on joint quaternions and offsets: smooth, no overshoot. "Stop" keys were dead stops.
2. Bake to **Linear** keys adaptively: add a key wherever the Linear segment would deviate by more than **0.3 degrees** or the turn rate changes by more than **1.2 rad/s**.
3. Result: about 130 to 205 keys per clip, about 6.5k instances per set of flourishes.

What you preview is exactly what plays, on any interpolation mode, because Linear segments between close keys barely differ between models. The cost is instances; see [[Performance and Memory]].

## Keyed versus baked clips

| | Keyed (few keys + easing) | Baked (dense keys) |
|---|---|---|
| Size | Small | Large; needs thinning |
| Editable by hand | Yes | Painful |
| Faithful to an IK/physics/mocap source | Approximate | Exact within tolerance |
| Sensitive to the interpolation model | Very (big segments) | Barely |
| Typical | Hand animation | IK bakes, retargets, procedural captures |

### Thinning a baked clip
Drop keys whose removal changes playback by less than a tolerance, checked against **the Animator's own interpolation** at a fine rate (60 Hz):

| Use | Rotation tolerance | Position tolerance | Source |
|---|---|---|---|
| Runtime-encoded clips (near lossless) | 0.03 deg | 0.002 studs | One production encoder |
| Body joints in an IK rebake | 0.75 deg (hips 0.5) | 0.03 studs; planted feet 0.05, airborne 0.12 | One production baker |
| Weapon hinge clips | 0.004 rad (about 0.23 deg) | 0.003 units, max 0.5 s between keys | One production thinner |
| Keyed-span fit | 5 deg | 0.09 studs | One spec baker, then the arms re-solved |

Always keep: first and last keys, keys within a frame of a marker, and keys bounding very large turns (one tool kept any segment over 150 degrees). Re-fit kept spans by trying easings in order: Linear, CubicV2 InOut, CubicV2 Out, CubicV2 In; take the first that reproduces the in-betweens within tolerance, else split the span at its worst sample.

A warning from the same project: one baker checked "does this easing reproduce the in-betweens" with `CFrame:Lerp` (a slerp) instead of the rotation-vector model. On big turns far from rest the kept keys then played slightly differently than the baker assumed; a later re-solve was needed for the arms.

## Frame rates

- Author at 30 fps for most motion; 60 for fast weapon work. The Animator itself is continuous: keys can sit at any time.
- Check motion at 60 Hz for pops (one-frame jumps) even if you author at 30, because the game renders at 60+ and interpolates your keys (see [[Animation Quality Standard]]).
- Track time is float32 and a clip's end is detected in float32 (see [[AnimationTrack Reference]]).

## Common mistakes

| Mistake | Effect | Fix |
|---|---|---|
| Easing set on the arriving key | Wrong feel on every segment | Put it on the leaving key |
| Legacy `Cubic` | Ease directions reversed | `CubicV2` |
| Key-to-key turns near 180 deg | Random direction, wrong-way swings | Mid keys; stay under 120 |
| Tools assume slerp | "Verified" clips play 10+ degrees off | Rotation-vector model |
| Long Linear spans on arms | Robotic motion (one QA flagged Linear arm spans > 0.12 s turning > 20 deg) | CubicV2 or more keys |
| Thinning against slerp | Kept keys diverge on playback | Thin against the Animator's model |

## See also
[[How the Animator Really Behaves]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Timing Spacing and Frame Charts]] · [[Authoring Clips in Code]] · [[Spec-Driven Move Authoring]] · [[Open Questions]]

## Connected notes
<!-- auto-links:start -->
[[Snippets - Building and Sampling Clips]] · [[Weapon Rig Player]] · [[Animation Data from Blender to Roblox]] · [[Clip Buffer Format]] · [[Easing]] · [[Interpolation Easing and Curves Math]] · [[Animation Start Here]]
<!-- auto-links:end -->
