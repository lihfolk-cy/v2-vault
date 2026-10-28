---
tags: [fundamentals, playback, priority, blending, layering]
---
# Playback, Priorities and Blending

<!-- tldr:start -->
> [!tldr] TL;DR
> - Priority works per joint. A track only competes on the joints it keys (Poses with Weight > 0).
> - The docs say equal priorities "blend by weight".
> - `Play(fadeTime)`: weight ramps linearly from its current value to the target over `fadeTime`.
> - `Play(_, _, speed)` or `AdjustSpeed(s)`: duration becomes `Length / speed`.
>
> Cost: TL;DR ~120 tok · whole note ~2.9k tok. Read more: ## How weight is distributed (measured) · ## Layering patterns that held up in production
<!-- tldr:end -->

When several tracks play on one rig, the Animator has to decide, for every joint, how much of each track to show. It does that with two numbers per track: **priority** (which layer it is on) and **weight** (how strongly it contributes within and below that layer). This note explains the exact rules (including the measured weight distribution, which the docs only hint at), the fade and speed behaviour, and the layering patterns that hold up in a real combat game.

## Priorities

`Enum.AnimationPriority`, lowest to highest:

| Priority | Enum value | Typical use |
|---|---|---|
| `Core` | 1000 | Default Animate locomotion and emotes. **Lowest**, despite the large value. |
| `Idle` | 0 | Idles; Animate's tool hold (`toolnone`) |
| `Movement` | 1 | Walk/run/sprint of a custom locomotion system |
| `Action` | 2 | Attacks, interactions, carry poses |
| `Action2` | 3 | Cosmetic overlays that must beat attacks: equip flourishes |
| `Action3` | 4 | Hit reactions, dodges |
| `Action4` | 5 | Abilities and anything that must beat everything |

**Never sort priorities by `.Value`.** `Core` has enum value 1000 but ranks below `Idle` (the docs list the order Action4, Action3, Action2, Action, Movement, Idle, Core). Code that compares `a.Priority.Value > b.Priority.Value` treats Core as the highest layer. Map it explicitly:

```lua
local function rank(p: Enum.AnimationPriority): number
	return if p == Enum.AnimationPriority.Core then -1 else p.Value
end
```

## Per-joint, not per-track

Priority works **per joint**. A track only competes on the joints it keys (Poses with Weight > 0). An attack that keys only `UpperTorso`, arms and head leaves hips and legs entirely to whatever lower layer keys them: that is how "swing while walking" works with no extra code. Conversely, an attack clip that contains leg keys (even a still "stance") takes the legs and the character skates.

That makes **what you key** a layering decision at authoring time:
- Full-body clip: owns every joint it keys while it is on top.
- Upper-body copy: the same clip with hip and leg poses removed or at Weight 0. One production game published separate `<Clip>Upper` assets and used them whenever the player was moving; the full clip only when the ability "had control" of the body.
- Single-limb layer: a right-arm-only "carry" pose for holding a weapon over any locomotion.

## How weight is distributed (measured)

The docs say equal priorities "blend by weight". The precise rule was measured in one production project by comparing hundreds of clips and a 5-track blend test against `Animator:StepAnimations` (error 0.04 degrees), and re-implemented in a Lua player that matched the Animator to under 0.1 degrees:

1. Start with **remaining weight = 1** for each joint.
2. Go from the **highest priority down**. For each priority, sum the weights `S` of its tracks that key this joint.
3. If `S` fits in what remains (`S <= rem`), each track contributes its own weight `w`, and `rem` drops by `S`.
4. Otherwise each track contributes `w * rem / min(S, 1)` and nothing remains for lower priorities.
5. All contributions go into **one weighted quaternion sum** for the joint.
6. If the total contributed weight is below 1 and nothing else drives the joint, the result's **rotation vector and offset are scaled by the total** (moving toward the rest pose).
7. Offsets are distributed the same way, but with each track's weight **capped at 1**.

### Worked examples (one joint)

| Situation | Result |
|---|---|
| Walk (Movement, w 1) + Swing (Action, w 1) | Swing takes 1, nothing left: pure swing |
| Walk (Movement, 1) + Swing (Action, 0.6) | Swing 0.6, walk gets the remaining 0.4: a 60/40 mix |
| Two Action tracks at 0.5 and 0.5 | Both fit (S = 1): 50/50 mix, nothing below shows |
| Two Action tracks at 1 and 1 | S = 2 > rem: each gets `1 * 1 / 1`; the normalised quaternion sum is a 50/50 mix |
| Two Action tracks at 0.3 and 0.3, nothing below | Total 0.6: the mixed rotation is scaled to 60% of its rotation vector, i.e. 40% toward the rest pose |
| One track at weight 0.5, nothing below | Half the rotation vector: halfway between rest and the clip pose |

Two consequences people trip over:
- **Weights within a priority are relative once they exceed 1 in total**, but absolute below 1. Fading one of two equal-priority tracks from 1 to 0 does not produce a linear mix until the sum drops below 1.
- **Weight below 1 with nothing underneath moves toward the rest pose**, not toward "nothing". On a bare rig that is the T/A-pose; in game it is usually covered by a lower idle. If a fading clip flashes toward a T-pose, nothing is playing under it on those joints.

A subtle measured detail: when a track's weight is under 1, *which* of the two equivalent rotation vectors the Animator holds for a key matters (scaling the "long way round" representation by 0.5 is a different rotation from scaling the short one). This only shows on joints rotated close to 180 degrees from rest; avoid such poses in partially weighted layers.

## Fades

- `Play(fadeTime)`: weight ramps **linearly** from its current value to the target over `fadeTime`. Default 0.1 s.
- `Stop(fadeTime)`: linear ramp to 0. Time keeps advancing during the fade-out (measured), so motion continues while it fades.
- A non-looped clip that reaches its end holds its last pose and fades out over **0.3 s** (measured), whatever fade you used to start it.
- `AdjustWeight(w, fadeTime)`: linear ramp to `w`.

Because the higher layer's weight is handed out first, a cross-fade from a lower to a higher priority is automatic: as the attack fades in from 0 to 1 over 0.1 s, the walk underneath gets `1 - w`. A cross-fade between two tracks of the **same** priority needs both ramps (one `Play(fade)`, one `Stop(fade)`); during it the sum is about 1, so the mix is linear.

### Fade times that work (rules of thumb, with production values)
| Transition | Fade |
|---|---|
| Ability start at Action4 | 0.05 s (one production game) |
| Move-list preview | 0.06 s |
| Attack chain link | 0 to 0.1 s; the next clip should start on the previous clip's pose instead of relying on a long fade |
| Locomotion gait swaps | 0.2 s (Animate and one custom system both use 0.2) |
| Idle variants, emotes | 0.2 to 0.4 s |
| Automatic end of a one-shot | 0.3 s (engine) |

Long fades hide bad poses but cost responsiveness. A 0.2 s fade on an attack means the first fifth of a second of the swing is a blend with whatever came before, which softens the anticipation pose you authored.

## Speed

- `Play(_, _, speed)` or `AdjustSpeed(s)`: duration becomes `Length / speed`. Negative plays backward, 0 pauses.
- Speed changes are immediate; there is no ramp. For a smooth slow-down (hit-stop recovery), step `AdjustSpeed` over a few frames.
- **Stretching clips to gameplay windows:** a 1.2 s stance in a 0.7 s window plays at about 1.71. Every marker time stored in data must be divided by the same speed.
- **Locomotion rate:** `rate = speed / groundSpeed` (the speed the clip's feet move at rate 1), usually clamped. A run capped at 1.5x slid its feet at sprint speed in one game: at 64 studs/s the run needed about 2.5x.
- **NPC rule from one production game:** enemy clips never play below 1x (slow motion reads as sluggish), except a stagger hit at 0.5x, which reads as weight. For scaled enemies the walk could slow to `0.85 / sqrt(scale)` so big creatures take slower, heavier steps.

## Layering patterns that held up in production

| Goal | Pattern |
|---|---|
| Attack while walking | Upper-body clip (or upper copy) at Action+; legs come from locomotion |
| Ability that roots the player | Full-body clip at Action4 while the ability "has control" (anchored root, Physics state, a `KitControl` attribute) |
| Holding a weapon over any gait | Right-arm-only carry layer at Action. Turn it off while swinging (fade back in over the swing's last 0.22 s), guarding, dashing, during flourishes. Make the carry pose equal to the swings' end pose, so hand-offs do not twist the forearm |
| Cosmetic flourish that must not block gameplay | Upper body only (UpperTorso, Head, right arm) at Action2; legs and left arm unkeyed so the run continues. Cancel it the moment any other Action2+ track starts |
| Separate leg motion for a flourish | Two clips, `<Name>` (upper) and `<Name>Legs`; fade the legs out with movement speed |
| Breathing on top of any pose | A tiny low-weight loop keying only chest and head at a high priority, or a procedural layer in PreSimulation |
| Idle variety | Fidget after 10 s still, then every 16 to 26 s at random, never the same twice in a row |
| Look-at, IK, recoil | Procedural, after the Animator (see [[Frame Order and RunService Timing]]) |

### Why the carry layer was Action and not Action2
One game tried the carry pose at Action2. Two things broke: it cancelled equip flourishes (which cancel on "any other Action2+ track"), and other controllers read any Action2+ track as "an attack is playing" and suppressed idle behaviour. Priority is also a **signal to your own code**; choose it with both meanings in mind.

## Coordinating many controllers

Real games have several systems playing tracks on one character: locomotion, combat, abilities, flourishes, emotes, hit reactions, cutscenes. Without coordination they stop each other's tracks or fight over joints.

- **Own your tracks by reference.** Keep a table of "what I am playing and why" and stop only those. Never loop over `GetPlayingAnimationTracks()` stopping everything, unless you truly mean "stop every system".
- **Use attributes as step-aside flags.** Examples: `FlourishLocal`, `GuardingLocal`, `KitControl`, `CutsceneLock`, `BladeUnheld`. Each controller checks them before playing and listens for changes to cancel.
- **Watch other systems through the Animator.** `Animator.AnimationPlayed` fires for every track started on the rig (and for replicated tracks on other clients). A flourish controller can cancel itself when it sees any Action2+ track begin.
- **Beware duplicate marker firing.** If a full-body clip and its upper-body copy ever play at once, both fire the same markers. One project's VFX layer explicitly skipped upper-body duplicates after "marks fired twice".

## Diagnosing blend problems

| What you see | Likely cause |
|---|---|
| Attack plays but legs skate | Attack clip keys the legs |
| Arm half-way between two poses | Two tracks on the same priority at similar weights |
| Fading clip flashes toward T-pose | Nothing below on those joints; weight < 1 moves toward rest |
| A layer has no effect | A higher priority track keys the same joints at weight 1; or it was loaded but never played |
| Default arm-out pose leaks through | Animate's `toolnone` at Idle on a joint your clips do not key |
| Core track wins over Idle in your own sorter | Sorting by `Priority.Value` |
| Smooth in Studio, pops live | Fades depend on frame timing and LOD; check `EvaluationThrottled` and throttling |

## See also
[[AnimationTrack Reference]] · [[How the Animator Really Behaves]] · [[The Default Animate Script]] · [[Markers and Events]] · [[Locomotion Systems]] · [[Combat Combo Systems]] · [[Equip Draw and Flourish Systems]] · [[Snippets - Animation Controller Module]]

## Connected notes
<!-- auto-links:start -->
[[Custom Locomotion Controller Design]] · [[Engine Gotchas]] · [[Snippets - Playing Animations]] · [[Weapon and Combat Animation]] · [[Links - Animation playback]] · [[AI Animation and Motion from Video]] · [[Animation Start Here]]
<!-- auto-links:end -->
