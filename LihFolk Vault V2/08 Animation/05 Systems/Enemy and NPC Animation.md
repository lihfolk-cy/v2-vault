---
tags: [systems, enemies, npc, ai, performance, hub, type/hub, area/animation, level/intermediate, api/HipHeight, area/performance, api/Animator]
---
# Enemy and NPC Animation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Enemy attacks from behind: Imported clips play turned 180 degrees -> Axis fix every imported clip
> - Root motion missing: Root keyed at the top-level pose -> Key a child joint
> - Floating or sinking: Clips not ground-fitted; wrong HipHeight -> Fit per clip; set HipHeight; runtime slope clamp
>
> Cost: TL;DR ~110 tok · whole note ~3.4k tok. Read more: ## Rig choices · ## Ground fitting (floating and sinking) · ## Common mistakes
<!-- tldr:end -->

Enemies are where animation meets scale: dozens on screen, each with 17 to 34 clips, driven by server AI, seen by every player, and expected to read clearly at a glance. NPCs are the opposite problem: one or two characters that must feel alive for minutes while doing nothing. This note is the hub for both. The precise server/client protocol is in [[Enemy Animation State Protocol]]; bosses in [[Boss Animation and Phases]]. Numbers come from one live action game (the reference project) unless marked otherwise.

## Rig choices

| Choice | Use when | Notes |
|---|---|---|
| `Humanoid` + Animator | The enemy paths with `Humanoid:MoveTo` and uses Humanoid physics | You get [[HipHeight]], states, auto-rotation; you also get Humanoid costs and quirks |
| `AnimationController` + Animator | Your AI moves the root itself (CFrame, `AlignPosition`, custom physics) | Lighter; no states; you write ground handling |
| Motor6D joints | Part-based rigs, imported or built in Studio | `Motor6D.Transform` is what the Animator writes |
| Bones (skinned mesh) | Imported creatures with deformation | Bone rigs need their own ground-fit approach (below) |

Imported creature rigs carry conventions that bite: the keyframe's **top-level pose** (the HumanoidRootPart, or the Root bone on bone rigs) is **never applied** by the Animator, so root lift or travel must be keyed on a child joint (one boss put its lift on a "Body" bone for this reason). Every imported enemy clip also had to go through an axis fix or it played turned 180 degrees. See [[Creature Rig Conventions]], [[Pipeline - Importing Animated Enemies]] and [[Enemy Import Axis Fix]].

## The clip set

A complete regular enemy in the reference project had about **17 clips**; bosses about **34**:

| Group | Clips |
|---|---|
| Locomotion | Idle, Walk, Run (flyers: Hover, HoverMove, FlyFast; legless: Idle, Move, MoveFast), optional Retreat |
| Attacks | 2 to 4 attacks, each with `Tele` (telegraph) and `Hit` markers; combo links with `Tele2`, `Tele3` |
| Reactions | HitFront, HitLeft, HitRight, HeavyHit, Stagger, Knockup, Stun (loop), StaggerGround for flyers |
| Life cycle | Spawn, Taunt, Death; bosses add Intro, PhaseShift, Enrage |
| Special | Caught (held by a player's ultimate), layer clips (a spinning rotor, a door slam) |

Store each clip's id, **duration and marker times** in the enemy's data module too. The server AI times telegraphs and hits from that data and never needs the clip loaded; the client uses the clip. If a clip is missing or still streaming, gameplay still works.

## Brain and body

The core split:

- **Server AI decides**: aggro, chase, which attack, when the telegraph starts, when the hit lands (from data marker times), damage, displacement, state (Idle, Move, Attack, Stagger, Caught, Dead).
- **Clients present**: every client plays the clips on its own copy of the rig, fires FX and sounds on markers, plays flinches, contact shadows, hit flashes.
- **The server never plays enemy clips and never waits for one.** It writes replicated state (attributes) with server timestamps; clients play from that, joining late when needed.

Why: server-side animation on many enemies costs server CPU and replication bandwidth for every joint, and it still looks worse because the client receives interpolated joint data. With attributes, the server sends a few bytes per state change and each client animates locally at full frame rate. Details in [[Enemy Animation State Protocol]].

## Families of procedural motion

Some motion is better as code than clips, because it must adapt to the situation. The reference project grouped enemies into four **families** (biped, crawler, floater, flyer) and wrote procedural motion per family for the ultimate "caught" sequence:

1. **Drag in** toward the anchor point over the pull's glide time (0.7 s default).
2. **Held** at the stack slot on the ground or hovering in the air (about 0.25 x body height for a vortex hover; 0 for slams).
3. **Jolts** for every hit that lands before the climax.
4. **Impact** at the climax time.
5. Then **survive** (blowback, stagger, back to idle) or **die** (thrown, then the enemy's own Death clip).

The AI stays locked until the climax plus about 1.65 s (1.4 to 1.8 s per family). Clips could not do this: the drag distance, hold height and climax time change per cast. See [[Cinematic Ultimates]].

## Locomotion for enemies

- Choose idle / walk / run by the root's horizontal speed: walk above 1.5 studs/s, run above 1.2 x the definition's walk speed (reference enemy client).
- Match playback rate to speed: `rate = clamp(smoothedSpeed / referenceSpeed, 0.7, 1.6)` with the speed smoothed by `smooth += (speed - smooth) * min(1, dt * 10)`.
- Fades of 0.2 s between loco clips.
- For scaled-up enemies the walk can slow to about `0.85 / sqrt(scale)`: bigger animals take slower, longer strides (a rule of thumb consistent with how stride frequency falls with leg length).
- **Do not force clip rate to match very fast AI move speeds.** Measured strides in the reference were 2 to 4x shorter than the definitions' move speeds; syncing rates would have played "frantic". Lengthen strides, lower move speeds, or accept some slide on fast chasers.

## Ground fitting (floating and sinking)

Imported and authored clips rarely put feet exactly on the ground at the game's scale. The symptoms are enemies hovering or wading, and corpses half in the floor. The fix in the reference project, as a pipeline:

1. For each clip, sample the lowest point of the feet (or the whole body for death clips) per frame.
2. Offset the root per clip (or per key) so the lowest point sits on the floor during contact frames. Keep loops seamless (first and last frame offsets equal).
3. Fix `HipHeight` on Humanoid enemies to the measured value (keep the old one in an attribute for rollback).
4. At runtime, clamp death poses to the **slope** under the body.

Results: 18 death clips went from a worst penetration of -9.37 studs to at or above 0; later 205 of 304 clips were fitted, worst -7.79 to -0.17; HipHeight fixed on 17 templates.

For **bone rigs**, a runtime "bone adapter" does the death fit: while the rig dies, sample the ground on a 3 x 3 grid under it, raise the Root bone by however far any bone (less its rest height, capped at a skin pad) dips below the ground, and tilt onto the slope as the death clip lays the body down (from an `FX_Fall` marker, else 45% in). `Bone.Transform` is restored before the Animator writes the next frame, so nothing accumulates. See [[Ground Fitting Pipeline]].

Ground raycasts need to hit real floors only. Tag walkable surfaces (for example `EnemyFloor`) and include invisible slabs that stand in for terrain; otherwise ground fits snap enemies onto decorations.

## Scale

- Scale enemies with `Model:ScaleTo(s)`. The Animator scales clip **root translations** by `Model:GetScale()`, so jumps and lunges grow with the model. Players scaled through Humanoid body scales (GetScale = 1) do **not** get this, which is a classic mismatch. See [[Scale and Animation]].
- Re-measure root height after rescaling.
- In the reference project regular enemies used a global body scale (1.61 after tuning) while bosses were sized separately by a level formula and not scaled with regulars.
- **Reskinning keeps clips.** Keep bones and pivots identical when swapping a creature's mesh and every clip keeps working. One roster of 49 models was replaced this way with a fit error of 0.000.

## Playback rules that kept fights readable

- Normal enemy motion **never below 1x**. The stagger hit at 0.5x is the only slow-down. Slowed attacks read as lag; a slowed stagger reads as weight.
- Always play the **full Caught clip**; a longer hold extends the state.
- **No turning** while Caught or knocked up.
- **Skip the flinch** during Caught, Knockup and Stun (and while Stagger or Death is the current one-shot).
- Separate **partial (upper-body) clips** for attacking while moving.
- Enemy attack tempo is mostly clip length. To make enemies faster, author faster blows; speeding only the follow-through after the last blow (x1/0.7 in the reference) helps a little.

## Telegraphs

Every attack has a `Tele` marker where its warning appears and a `Hit` marker where damage lands. Colours that read instantly (reference project):

| Colour | Meaning |
|---|---|
| Red | Normal attack (block or dodge) |
| Gold | Unblockable: dash out |
| Blue | Push, pull or lift |
| Violet | Summon |

A revamp plan in the same project set a 0.4 to 0.8 s telegraph (glow plus pose plus ground marker) for regular attacks; bosses got stricter rules (warnings and combo links at least 0.5 s). In combo chains only the **last** link may be gold. See [[Boss Animation and Phases]].

## Hit flash and detachable parts

- **Hit flash**: a pool of white `Highlight`s (max about 8), 0.1 s fade, updated only while one is live. See [[Hit Reactions Stagger and Hit-Stop]].
- **Detachable parts** (an arch chunk, armour plates, a door, a hat): on a state attribute the client hides the part, or **drops a copy at the bone's animated pose** (not its rest pose) that lies there for a while, or fades it out. If several keys can hide a part, it shows only when no key hides it.

## Sound on markers

Enemy sounds are cheapest to time from the same markers: a voice profile per enemy (beast, crab, hiss, bird, insect, ghost, glitch and so on) plus element and body weight, markers read by name (`Roar`, `Charge`, `Breath`, `Slam`, `Claw`), per-family footsteps, crowd caps so 20 enemies do not roar at once. Takes were levelled by measured loudness and started at their onset (trimmed silence), so marker-time equals sound-time. See [[VFX Timing with Animation]].

## Performance with many enemies

| Technique | Reference numbers |
|---|---|
| Load each clip once per rig; reuse tracks | |
| Distance LOD for a Lua keyframe player | Every frame within 60 studs, every 2nd within 150, every 4th within 300, beyond that time only advances |
| Cost per rig | About 22 microseconds per 25-bone rig-frame (39 to 60 on the largest boss) |
| Compile and stream clip data once per client | 19 to 235 KB per kit (about 1.6 MB total) after key thinning (0.03 degrees) and [[Quaternions\|quaternion]] packing |
| Destroy duplicated animation folders | Enemy models carried their own Animations copies (207k instances) that were destroyed on every spawn anyway |
| Delete clips of removed enemies | 69k instances for 12 enemies no longer in the game |
| Outlines | Bake into meshes for crowds; `Highlight` only for bosses and flashes |

Until a kit's clip data arrives, the rig holds a procedural root pose; boss kits are prefetched by zone so intros are ready. See [[Animation LOD]], [[Performance and Memory]] and [[Case Study - Cutting a Million Instances]].

## Static NPCs

Quest givers, shopkeepers and townsfolk need to feel alive without a full AI:

- Anchor only the root, hide the Humanoid display name if you draw your own nameplate, add a `ProximityPrompt`.
- **Procedural idle through `Motor6D.Transform`**: the reference shopkeeper (a default R15 body at scale 1.7 with a modelled outfit) polishes, looks around and flips a coin, **waves at players within 15 studs**, **turns its head toward players within 26 studs**, and **sleeps beyond 280 studs** (no updates at all).
- **Head and waist tracking**: set the Neck and Waist `C0` (or `Transform`) toward the target, clamped. Any **unjointed accessory parts** (a hood, a skull, an arm piece) must first be welded to the body part they sit on, or they stay behind when the head turns.
- A periodic flourish (every 10 to 30 s, rule of thumb) breaks the loop; never the same twice in a row.

See [[Look-At Aim and Head Tracking]] and [[Idle Breathing and Secondary Motion]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Enemy attacks from behind | Imported clips play turned 180 degrees | Axis fix every imported clip |
| Root motion missing | Root keyed at the top-level pose | Key a child joint |
| Floating or sinking | Clips not ground-fitted; wrong HipHeight | Fit per clip; set HipHeight; runtime slope clamp |
| Frantic legs on chasers | Rate forced to match fast AI speed | Longer strides or slower speed |
| Twitching while held | Flinch not skipped in higher states | Skip rules |
| Enemies frozen in T-pose on join | Clips still streaming, no fallback pose | Procedural root pose until clips arrive |
| Server CPU high with many enemies | Server playing clips | Attributes from server, clips on clients |

See also: [[Enemy Animation State Protocol]], [[Boss Animation and Phases]], [[Snippets - Enemy Client Animator]], [[Animating Creatures and Monsters]], [[Markers and Events]], [[Pipeline - Importing Animated Enemies]].

## Connected notes
<!-- auto-links:start -->
[[Procedural Death Knockdown and Hit Reactions]] · [[Case Study - Enemy Roster Rebuild]] · NPC AI and Behaviour · [[Bones and Skinned Meshes]] · Genre Playbook - Combat and RPG · Character and Creature Pipeline · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[NPC AI and Behaviour]] · [[Weapon and Combat Animation]] · [[Retargeting Animations Between Rigs]] · [[Custom Characters and StarterCharacter]] · [[Foot Placement and Ground IK]] · [[Rigging in Blender]] · [[Locomotion Systems]] · [[Animation Glossary]] · [[Importing Models and Rigs]]
<!-- related:end -->
