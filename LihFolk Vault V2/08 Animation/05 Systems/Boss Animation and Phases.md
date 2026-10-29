---
tags: [systems, enemies, boss, phases, telegraph, dodge]
---
# Boss Animation and Phases

<!-- tldr:start -->
> [!tldr] TL;DR
> - Intro once per player, skippable after 2 s, untouchable, restores on every exit.
> - Phase shift clips untouchable, their hits still land; hazards start after the clip.
> - `(Hit - Tele) / speed >= 0.5` for every attack in every phase.
> - Following markers lock 0.45 s before the blow; fast shot markers last until arrival.
> - Only the last combo link gold.
> - Root motion on a child joint; orbit pieces in code.
>
> Cost: TL;DR ~140 tok · whole note ~2.6k tok. Read more: ## Intros · ## Rigs for big creatures · ## Checklist
<!-- tldr:end -->

A boss is an enemy whose animation carries the fight's structure: an intro that introduces it, telegraphs players must read and dodge, phase shifts that change its behaviour, and a death that pays off. Bosses are also physically large, so every rig, scale and camera problem gets bigger. This note covers boss intros, untouchable clips, phases, telegraphs and dodge windows, rigs for big creatures and the camera lanes they need. Numbers come from one live action game (the reference project). The general enemy protocol is in [[Enemy Animation State Protocol]].

## The boss clip set

Bosses in the reference project had about **34 clips** against about 17 for regular enemies. The extra clips:

| Group | Typical clips |
|---|---|
| Intro | Intro (often with its own camera), Spawn rise or drop |
| Phase | PhaseShift (one per transition), Enrage, phase idle variants |
| Attacks | 6 to 10 attacks, several with multiple stages (`Tele`, `Tele2`, `Tele3`, `Hit`, `Proj` marks) |
| Reactions | HeavyHit recoil (bosses are not pulled into ultimates), shorter Stagger |
| Death | Death with detach or shatter marks, held final pose |
| Layers | Loops per phase (a floating disk, an orbit), clip-tied layers |

## Intros

An intro does three jobs: shows the boss's silhouette and scale, teaches one thing (its weapon, its element), and gives players a breath before the fight.

Reference rules:

- **Once per player.** Store "seen" per player (profile flag) so the intro does not replay on every wipe. Replays on retry are the most-skipped content in any boss game.
- **Skippable after 2 s.** A skip button appears after 2 seconds. The delay stops accidental skips from a click that was meant for combat.
- **Restore on everything**: end, skip, death, respawn, an ultimate starting. The camera, UI and input locks must come back in every exit path (see [[Cameras and Cutscenes]]).
- **Triggered for players within range** (170 studs in an earlier version), sent with the boss's root CFrame and scale, so each client frames its own shots around the real boss.
- **The intro clip is untouchable**: the boss takes no damage while it plays. Otherwise players who skipped the cutscene get free hits on a boss that cannot fight back, and a boss can die during its own intro.
- **Ultimate cinematics were not reused** for boss intros, because they need a weapon's ultimate plan (anchor, climax). A boss intro got its own simpler camera module.

### Joining late

Boss clip data for a Lua keyframe player is **prefetched by zone** so the intro is ready when players arrive. If it still arrives late, the intro **joins late** at the correct time position once the kit streams in (the same late-join rule as every enemy clip), rather than restarting and desyncing from the server's fight clock.

## Phases

A phase is a state of the fight with its own behaviour, and phase changes are the moments players remember.

| Element | Reference implementation |
|---|---|
| Triggers | Health thresholds (one boss: Enrage at 50%, Desperation at 20%; a global rage at 35%) |
| Transition | A **PhaseShift clip that is untouchable**, during which its own hits still land |
| After | Speed and damage go up ("mood up") |
| Visuals | Phase loop layers, texture swaps (a cracked skin), FX |

Two nuances from production:

- **Hazards wait for the clip.** One boss floods its arena in the second phase. The flood band only starts burning **after** the shift clip ends. If the hazard activates when the threshold is crossed, players take damage during a cutscene-like moment they cannot act in.
- **Untouchable but dangerous.** The shift clip ignores damage but its own attacks hit. That makes the transition a dodge check instead of a free pause, and it stops burst damage from skipping the transition.

Make the phase visible on the body: a texture swap, a new loop layer, a changed idle. Players should know which phase it is without a UI label. See [[Enemy Animation State Protocol]] for phase layers and texture-swap attributes.

## Telegraphs

Every attack has a telegraph: a pose, a glow, a ground marker, and a colour. Reference colours:

| Colour | Meaning | Player answer |
|---|---|---|
| Red | Normal | Block or dodge |
| Gold | Unblockable | Dash out |
| Blue | Push, pull or lift | Position |
| Violet | Summon | Kill the adds |

In combo chains **only the last link may be gold**: a gold link mid-chain forces a dash, and the next link then punishes the dash recovery. The runtime enforces this at load time by turning an earlier gold link red and warning.

### Following telegraphs must lock

Many boss attacks aim at a player and track them while winding up (a ground marker that follows you). If it follows until the hit, it cannot be dodged by moving. Reference rule: **following markers lock at least 0.45 s before the blow.** From that moment the area is fixed and the player's movement matters.

### Fast projectiles

A fast shot's marker lasts **until the bolt arrives**, for any enemy, not until the shot leaves. Otherwise the warning vanishes while the danger is still in the air.

## Dodge windows

The reference rules for boss-class enemies (bosses, elite "mega" enemies, zone elites):

| Rule | Value |
|---|---|
| Dash invulnerability against boss-class blows | 0.40 s from the dash start |
| Minimum warning before any boss attack | 0.5 s |
| Minimum gap between combo links | 0.5 s |
| Following markers lock | at least 0.45 s before the blow |
| Long authored warnings (arena-wide attacks) | kept as authored (3.1 s), not capped |

The 0.40 s i-frame window is measured from the **dash start**, not from the dash animation's frames, so it is the same at every ping and every frame rate. Note that it applies only against boss-class attacks: regular enemies can be dodged by distance, and full i-frames against everything make dashes too strong.

Why 0.5 s minimum warning: human reaction time to a visual cue is roughly 0.2 to 0.3 s, plus the dash input, plus latency. At 0.5 s an attentive player at reasonable ping can react; below about 0.35 s only memorisation works (rule of thumb).

Interaction with animation: **the telegraph time is the clip's `Tele` to `Hit` distance at the attack's speed.** If a phase raises attack speed by 30%, a 0.6 s telegraph becomes 0.46 s and breaks the 0.5 s rule. Either clamp the speed per attack or check `(Hit - Tele) / speed >= 0.5` when phases change speed.

## Rigs for big creatures

Production notes on boss rigs:

- **Root motion on a child joint.** The Animator never applies the keyframe's top-level pose (the HumanoidRootPart, or the Root bone of a bone rig). One boss put its lift and travel on a "Body" bone below Root for this reason. See [[How the Animator Really Behaves]].
- **Orbiting pieces are code, not clips.** A boss with an orbit of floating pieces, a cloth hem and lanterns had those **stripped from its clips** and spun client-side. Keying orbits into 23 clips multiplies keys, and the orbit cannot stay continuous across clip changes; code can.
- **Jaw and head.** A skull built in anatomical order with a separate jaw on the real hinge, carrying bones `Head` and `Jaw`, so roars can open the mouth independently of the head.
- **An early boss** was a static model scaled to 30 with 19 Motor6Ds inserted with "body-aligned frames", animated client-side through `Motor6D.Transform`. Workable, but the joint frames had to be designed for posing (aligned to the limb), not inherited from the mesh.
- **A Blender-built boss** example: 6 meshes, 42 bones, 23 clips.
- **Mirrored root travel.** One imported boss had its root's forward/back travel mirrored by the importer; fixed by flipping the lower torso pose Z in the data. Always check root motion direction after import. See [[Pipeline - Importing Animated Enemies]].
- **Cost**: the largest boss cost 39 to 60 microseconds per frame in the Lua keyframe player, against about 22 for a 25-bone rig. Bosses are few; this is fine.

## Scale

Bosses were sized by their own formula (one reached about 50 studs), not by the global enemy scale. Big bosses need:
- clip root translations at game scale (the Animator scales root translations by `Model:GetScale()` for model-scaled rigs),
- attack shapes and telegraphs scaled with the model,
- camera framing that accounts for height (see below).

See [[Scale and Animation]].

## Reactions

- **Not pulled** into player ultimates; instead a short HeavyHit recoil on heavy beats (see [[Hit Reactions Stagger and Hit-Stop]]).
- **Shorter stagger**: 0.9 s against 1.6 s for regulars.
- Hit flashes on bosses can use real `Highlight`s (few bosses, so the instance limit is not a problem).

## Death

Boss deaths are the payoff. Useful patterns:
- **Detach many parts at once** on a death mark (one boss's body shatters: several named parts detach together).
- **Hold the last frame** and ground-fit the pose (big bodies clip into slopes visibly).
- Delay loot and UI until the death clip's impact mark, not until health hits zero.

## Arena and camera lanes

Boss intros and ultimates move the camera around the boss. Reference arena rule: **keep anything taller than 8 studs out of the camera lanes** (the paths the intro and ultimate cameras travel). A pillar in a camera lane means either a wall-avoidance pop (the camera snaps in front of it) or a shot full of pillar. Design the arena and the camera together. See [[Cameras and Cutscenes]].

## Checklist

- [ ] Intro once per player, skippable after 2 s, untouchable, restores on every exit.
- [ ] Phase shift clips untouchable, their hits still land; hazards start after the clip.
- [ ] `(Hit - Tele) / speed >= 0.5` for every attack in every phase.
- [ ] Following markers lock 0.45 s before the blow; fast shot markers last until arrival.
- [ ] Only the last combo link gold.
- [ ] Root motion on a child joint; orbit pieces in code.
- [ ] Camera lanes clear of tall props.
- [ ] Death clip held, ground-fitted, rewards on the impact mark.

See also: [[Enemy and NPC Animation]], [[Enemy Animation State Protocol]], [[Cinematic Ultimates]], [[Cameras and Cutscenes]], [[Animating Creatures and Monsters]].

## Connected notes
<!-- auto-links:start -->
[[Snippets - Enemy Client Animator]] · [[Boss Fight Design Patterns]] · [[Genre Playbook - Combat and RPG]] · [[Case Study - Enemy Roster Rebuild]] · [[Anticipation]] · [[NPC AI and Behaviour]] · [[Animation Start Here]]
<!-- auto-links:end -->
