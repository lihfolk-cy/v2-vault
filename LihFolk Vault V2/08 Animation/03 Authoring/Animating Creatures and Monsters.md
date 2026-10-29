---
tags: [authoring, craft, creatures, enemies, quadrupeds, flyers, telegraphs, type/guide, area/animation, level/intermediate, api/Animator]
---
# Animating Creatures and Monsters

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Making big creatures slow by playing clips slowly -> author slow; never play below 1x
> - Avoid: Lift on the top-level root -> key the first child bone
> - Avoid: Imported clips not axis-fixed -> apply the 180-degree data fix
> - Weight reads through anticipation, impact settle and follow-through, not slow playback
> - Cycle speed matches scale (about 1 / sqrt(scale) for scaled copies)
> - Every attack has a unique telegraph of 0.45 s or more (0.5 s for bosses), with `Tele` and `Hit` markers
>
> Cost: TL;DR ~170 tok · whole note ~4.3k tok. Read more: ## 3. Body plans · ## 6. Roblox traps that hit creature clips · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Enemies are animated for the *other side* of the fight: the player has to read them, predict them and punish them. A monster animation succeeds when its weight is believable, its intent is unmistakable, and its timing gives the player fair windows. This note covers weight and scale, the main body plans (bipeds, quadrupeds, crawlers, flyers, floaters), telegraphs and fairness, shared clip sets, and the Roblox-specific traps that hit creature clips hardest (root poses, import axes, ground clipping, scale).

Rig building is in [[Creature Rig Conventions]]; the runtime side is in [[Enemy and NPC Animation]], [[Enemy Animation State Protocol]] and [[Boss Animation and Phases]].

Labels: "reference project" = one live action game with a couple of dozen enemy kits, dozens of kits of baked clips and several bosses; "rule of thumb" = practice.

## 1. Weight

Weight is communicated by **timing ratios** and **follow-through**, not by slowing everything down.

| Cue | Light creature | Heavy creature |
|---|---|---|
| Anticipation | short, small | long, big, with a visible weight shift |
| Strike | fast | fast (heavy does not mean slow at the moment of impact) |
| Impact | small recoil | the whole body settles; ground shake, dust |
| Recovery | quick | long: momentum carries the body past and it must recover |
| Overshoot | on the body | on extremities (jowls, tails, armour plates) while the core is stable |
| Step contacts | soft | each footfall compresses the body, with a lag up the spine |

Rules of thumb:
- **Momentum must be paid for.** A heavy creature that turns or stops instantly breaks the illusion. Overshoot the turn and settle, or slide the stop over several frames.
- **Big things move their centre of mass little and late.** The hips of a giant barely bob; the extremities move a lot.
- **Effects multiply weight.** Camera shake, dust and a low sound on footfalls of a big creature do more than any pose. Use `Step` markers to drive them.

## 2. Scale and timing

Larger creatures of the same shape have slower natural rhythms. A pendulum's period grows with the square root of its length, and legged gaits follow a similar rule (rule of thumb, dynamic similarity).

- The reference project slowed the walk of scaled-up enemies to **0.85 / sqrt(scale)** of normal.
- It also measured that its enemy strides were 2 to 4 times slower than the movement speeds in the enemy definitions; syncing clip speed to the definitions' speeds would have made them "play frantic", so per-zone gait speeds were deliberately not added. Lesson: match gait clips to *visible* speed and scale, not to design numbers.
- **Never play enemy clips below 1x** to make something feel bigger (reference project rule; the only exception was a stagger hit at 0.5x). Slowed clips show interpolation flaws and float. Author big creatures slow instead.
- **Root translation scales with size.** Shared clips authored at a family reference height must have their root translation multiplied by `enemyHeight / referenceHeight`, or feet slide and float (see section 6).

## 3. Body plans

The reference project organised enemies into five **rig families**. Every member of a family shares bone names and hierarchy, so locomotion and reaction clips are shared and each enemy only adds its attacks. This is the single biggest saving in creature animation.

| Family | Reference height | Core bones | Shared clip set |
|---|---|---|---|
| Biped | 12 studs | R15 names plus extras (jaw, back prop, cape chain, tail) | Idle, Walk, Run, Spawn, Taunt, HitFront / HitLeft / HitRight, Stagger, Stun, Knockup, Death |
| Quadruped | 8 studs (to the head) | hips, spine, chest, neck, head, jaw; front legs 2 segments + foot; hind legs 3 segments (digitigrade hock) + foot; tail 3 | same set (taunt = head-up howl); hoppers replace Walk / Run with Hop / HopFast |
| Flyer | 5 studs body | body, neck, head, jaw, 3-bone wings, optional hind wings, abdomen or tail fan, legs | Hover, HoverMove, FlyFast, ... ; Stagger falls to the ground, StaggerGround loops; wing flap is an **additive loop** so attacks keep flapping |
| Crawler | 7 studs, low body | body, head, jaw or mandibles, up to 6 legs x 3 segments | same set; Stagger flips or tilts; Death curls the legs |
| Floater | 7 studs, hovering 1 to 4 studs | core, head or mask, optional arms, cloak and ribbon tails, orbiting props | Idle bob, Move, MoveFast, ...; Stagger drops to the ground; Death drops, then breaks up |

Variants inside a family change proportions and add a few clips (a knuckle-walking golem gets its own Walk and Run but shares everything else).

### Bipeds (monsters, not people)
- Exaggerate proportions in motion: long arms swing wider, short legs take more steps.
- Hunched bipeds lead with the head and shoulders, not the hips.
- A "knuckle" gait (arms reaching the ground) is a quadruped gait done by a biped rig: alternate arm and leg contacts.

### Quadrupeds
Gaits (rule of thumb, from animal locomotion):
- **Walk**: four-beat, one foot at a time; the hind foot on one side lands, then the front foot on the same side (a "lateral sequence"). At least two feet are always down.
- **Trot**: diagonal pairs move together (front left with hind right); two beats; little or no suspension at slow speeds.
- **Canter / lope**: three beats, asymmetric; a lead leg.
- **Gallop**: four beats with a suspension phase; the spine flexes and extends strongly.
- **Bound / hop**: both hind legs together (small animals, hoppers).

Animation tips:
- **Spine drives the gait.** Flex and extension of the spine, and the shoulders and hips rising and falling out of phase, sell it far more than the legs.
- **Head counterbalances.** The head bobs with the front legs in a walk and stays steady in a gallop.
- **Hind legs push, front legs catch.** Give hind contacts more compression and front contacts a braking shape.
- **Digitigrade hocks** (3-segment hind legs) need the middle joint to fold the opposite way to the knee. Key it explicitly; IK on a 3-bone leg needs a rule (see [[Multi-Bone IK - FABRIK and CCD]]).
- Many runtime systems treat quadrupeds as "crawlers" (the reference project's procedural motion classified any rig with four or more legs that way); that is fine as long as the clip names and bone roles are consistent.

### Crawlers (insects, spiders, multi-legged things)
- **Alternating tripods** for six legs: front and rear on one side with the middle on the other move together.
- Keep the body level and smooth while the legs do frantic work; the contrast reads as "creepy".
- Leg tips plant and hold; any slide is very visible on a low body. Plant with IK if the creature walks on uneven ground ([[Foot Placement and Ground IK]]).

### Flyers
- **Flap cycle**: a powerful downstroke (wings forward and down, body lifts) and a recovery upstroke (wings fold, body dips). The body's bob is out of phase with the wings.
- **Separate the flap into an additive loop** so attacks, hits and turns keep the wings moving. The reference project did exactly this.
- **Glides and banks**: for creatures crossing the sky, paths are better procedural. The reference project flew ambient creatures along B-spline paths with bank and pitch and time-based flap plus glide, culled off-screen. See [[Flight Flocks and Path Animation]].
- **Stagger means falling.** A hit flyer drops to the ground, loops a grounded stagger, then takes off again; it reads clearly and gives melee players a window.

### Floaters (spirits, drones, masks)
- No ground contact, so weight comes from the **hover bob** (slow, 1 to 3 s cycle, rule of thumb) and **drag** on trailing parts (cloaks, ribbons, tails).
- Death drops first, then breaks up; there is no "fold to the ground".
- **Orbiting pieces should be procedural.** The reference project stripped orbiting parts from boss clips and spun them on the client instead: cheaper, endlessly smooth, and they never fight the clip.

## 4. Telegraphs and fairness

The player must be able to see an attack coming and react. Human reaction time to a visual cue is a few hundred milliseconds, and the player also needs time to input and for the dodge to start.

Reference project numbers:
- Enemy attack markers locked at least **0.45 s** before the blow.
- Boss warnings and combo links **0.5 s or more**.
- Boss-class dodge i-frames of **0.40 s**.
- Markers convention: `Tele` (telegraph start), `Hit`, `Hit2...`, `Proj` (projectile release), `Summon`, `MoveStart` / `MoveEnd`, `Step`, `FX_<name>`. Marker times were exported into the enemy definition, so **the server never needed the clip** to time damage; the client played the clip.

How to make a telegraph readable:
1. **A unique wind-up shape per attack.** If two attacks share a wind-up, the player cannot learn them.
2. **Point at the danger zone.** The limb, head or weapon that will hit is clearly raised, drawn back or glowing.
3. **Hold the wind-up** (a moving hold of a few frames) at its extreme. That is the reaction window.
4. **Add a non-animation cue** in sync: a sound, a flash, a ground decal for area attacks. Drive it from the `Tele` marker.
5. **Fast strike after a clear wind-up.** A long, slow strike is harder to time a dodge against than a long wind-up and a sharp strike.

Things that make enemies feel unfair:
- Attacks that start from the idle pose with no wind-up.
- Wind-ups hidden by the creature's own body from the usual camera angle (attacks from behind the creature's silhouette).
- Turning to track the player during the strike. The reference project never turned enemies while they were caught or knocked up; tracking during the active frames should be limited or disabled.
- Clips sped up to make enemies harder. Speed up the follow-through instead: the reference project sped up only the follow-through after an enemy's last blow (by a factor of 1 / 0.7).

## 5. Reactions, states and the server-client split

Reference project rules for enemy animation, generalisable to most action games:
- **The server never plays clips.** It writes replicated attributes (the current clip, its start time, speed and loop flag, a hurt direction, layers, detach events), and every client's Animator plays them. Combos join the next clip part-way via a time-offset attribute; late joiners start mid-clip. See [[Enemy Animation State Protocol]].
- **Directional hurt reactions** (front, left, right, heavy) confirm hits for everyone watching.
- **Some states must not be interrupted**: the hit flinch was skipped while the enemy was caught, knocked up or stunned, and the full "caught" clip always played.
- **Detachable parts**: hide a part or drop a physical copy at the bone's *animated* pose, then fade it. A part is visible only when no key hides it.
- **Boss phase shifts** are "untouchable" clips whose hits still land; damage and speed rise after them.
- **Hit flash**: pooled white `Highlight`s (at most 8, 0.1 s fade) instead of per-hit instances.

## 6. Roblox traps that hit creature clips

### The root pose is never applied
Measured: a keyframe's top-level pose (the `HumanoidRootPart`, or the top `Root` bone on a bone rig) is ignored by the Animator. Creature clips exported from Blender usually put body lift and travel on the root. Result: a jump that never leaves the ground, a spawn rise that does not rise. Fix: put lift and travel on the first child bone (the reference project used a "Body" bone on one boss rig).

### Imported clips turned 180 degrees
In the reference project, every GLB-imported enemy clip played with the body turned 180 degrees from the root, so enemies visibly "attacked from behind" while server logic (using the root's LookVector) was correct. Cause: the importer rotated the model 180 degrees about Y and wrote non-root poses in a frame that kept that rotation. Fix applied to the data (self-inverse, so it can be undone): non-root poses `P' = Rest^-1 * C * Rest * P * C`, root `P' = P * C`, with `C` = 180 degrees about Y. Turn clips also had their root yaw stripped because the server turns the root. Rule: every new imported enemy clip must go through this fix. See [[Enemy Import Axis Fix]].

### Ground clipping on death and big moves
Creatures fall, crouch and lie down on uneven ground. In the reference project, 18 death clips penetrated up to **9.37 studs** below the floor before fitting; a wider pass fitted **205 of 304** clips, moving the worst penetration from **-7.79 to -0.17** studs while keeping loops seamless, and 17 templates had wrong [[HipHeight]]. Bone rigs used a runtime adapter: sample ground height on a 3x3 grid, lift the root bone by the deepest bone minus a skin pad, and tilt from the fall. See [[Ground Fitting Pipeline]].

### Exactly 180-degree keys
Three enemy clips with exactly 180-degree key-to-key rotations were the only parity failures between the reference project's Lua player and the real Animator, because the Animator itself picks a direction arbitrarily. Creature clips with big tail or neck swings hit this often. Split big turns.

### Rest pose and roll
Use a consistent rest pose (the reference project: A-pose bipeds with arms 40 degrees down, quadrupeds standing square, flyers with wings flat, floaters with arms 30 degrees down) and a consistent bone roll (X = right, so +X lifts a limb forward). Shared clips only transfer between rigs with the same rest and roll. See [[Blender Armature and Bone Roll Conventions]].

### Bone budget and skinning
Reference project limits: at most **40 deforming bones** for regulars and **60** for bosses, at most 4 influences per vertex. Unused family bones stay in the rig (so shared clips still match) but carry no weights. See [[Weight Painting and Skinning for Roblox]] and [[Bones and Skinned Meshes]].

### Clip data cost
Enemy clip folders reached **323k instances** in ReplicatedStorage when baked with every joint keyed at 16 to 25 fps, and enemy models carried duplicate Animation copies (207k instances) that were destroyed on every spawn anyway. Thin, publish or ship compressed buffers. See [[Case Study - Cutting a Million Instances]].

## 7. Bosses

- **Phases need readable transitions.** A phase-shift clip that is long, loud and untouchable resets the player's expectations before the new pattern starts.
- **Intro clips** are cinematic: the reference project ran a skippable boss intro camera (skip after 2 s) and made the intro clip untouchable.
- **Keep the arena camera lanes clear** of tall geometry (the reference project kept anything over 8 studs out of the camera lanes) so attacks stay visible.
- **Big bosses need procedural help**: orbiting parts, cloth-like trails and look-at are better at runtime. See [[Boss Animation and Phases]] and [[Procedural Animation]].

## 8. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Making big creatures slow by playing clips slowly | floaty, interpolation flaws visible | author slow; never play below 1x |
| Lift on the top-level root | spawn and leap stay on the ground | key the first child bone |
| Imported clips not axis-fixed | enemies face away while attacking | apply the 180-degree data fix |
| Same wind-up for different attacks | unlearnable enemy | unique wind-up silhouettes |
| Tracking the player during the strike | undodgeable | lock facing at the telegraph |
| Wing flap baked into each attack | wings freeze during attacks or pop between clips | additive flap loop |
| Death clips not ground-fitted | corpses sink into slopes | fit clips; runtime slope clamp |
| Per-enemy unique clips for everything | huge clip count, inconsistent feel | family rigs with shared clip sets |

## 9. Checklist

- [ ] Weight reads through anticipation, impact settle and follow-through, not slow playback
- [ ] Cycle speed matches scale (about 1 / sqrt(scale) for scaled copies)
- [ ] Every attack has a unique telegraph of 0.45 s or more (0.5 s for bosses), with `Tele` and `Hit` markers
- [ ] Marker times exported to data for the server
- [ ] Root lift and travel on the first child bone
- [ ] Imported clips axis-fixed; no exactly-180 keys
- [ ] Death and crouch poses ground-fitted
- [ ] Shared family clips used; only attacks are unique
- [ ] Bone and instance budgets respected

## See also
[[Creature Rig Conventions]], [[Enemy and NPC Animation]], [[Enemy Animation State Protocol]], [[Boss Animation and Phases]], [[Pipeline - Importing Animated Enemies]], [[Procedural Gait and Footstep Planning]], [[Combat Animation Craft]], [[Timing Spacing and Frame Charts]].

## Connected notes
<!-- auto-links:start -->
[[Snippets - Enemy Client Animator]] · [[Procedural Death Knockdown and Hit Reactions]] · [[Retargeting Animations Between Rigs]] · [[Hit Reactions Stagger and Hit-Stop]] · [[Skeleton Library]] · Case Study - Enemy Roster Rebuild · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Animation Review Checklist]] · [[Principles of Animation for Games]] · [[Posing and Silhouettes]] · [[Animation Capture and Mocap]] · [[Idle Breathing and Secondary Motion]] · [[Scale and Animation]] · [[Locomotion and Melee Reference Numbers]] · [[R15 Run Cycle Key Poses]]
<!-- related:end -->
