---
tags: [systems, combat, weapons, abilities, hub, type/hub, area/animation, level/intermediate, api/Motor6D, area/gameplay, api/Animator]
---
# Weapon and Combat Animation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Weapon clip has no effect: Weld grip, or keys for joints with no Motor6D -> Motor6D grip; check joint names
> - Weapon parts animate in Studio only: Runtime-registered clip ids -> Publish, or play through a Lua player
> - Arm sticks straight out over custom poses: Animate's tool-hold -> Fade it to 0.001
>
> Cost: TL;DR ~120 tok · whole note ~3.5k tok. Read more: ## How the weapon is held · ## Arm quality: what makes swings look broken · ## Common mistakes
<!-- tldr:end -->

This is the hub for everything a weapon does on a character: how it is held, how classes of weapon differ, how swings, guards, abilities, flourishes and deaths fit together, and which priorities and attributes keep them from fighting. Each big topic has its own note; this one gives the system map, the rules that span all of them, and the measured numbers from one live action game (the reference project).

| Topic | Note |
|---|---|
| Click combos, buffering, server hit timing | [[Combat Combo Systems]] |
| Ability kits (registry, priorities, upper copies, beats) | [[Ability Kits Architecture]] |
| Flinch, stagger, hit-stop, parry | [[Hit Reactions Stagger and Hit-Stop]] |
| Equip flourishes, draws, ignition | [[Equip Draw and Flourish Systems]] |
| Stance and charge (iai) moves | [[Stance and Charge Moves]] |
| Ultimate cinematics | [[Cinematic Ultimates]] |
| Slash trails and impact timing | [[VFX Timing with Animation]] |
| Swing posing and timing craft | [[Weapon Swing Design]], [[Combat Animation Craft]] |
| Procedural weapon sway and recoil | [[Procedural Weapon Motion]] |

## How the weapon is held

### The grip joint

The stock Roblox `Tool` attaches with a `Weld` named `RightGrip` between the right hand and the tool's `Handle`, built from `Tool.Grip`. A weld cannot be animated by clips. Two production approaches:

1. **Motor6D grip (current in the reference project).** A `Motor6D` named `SwordMotor` from `RightHand` to `Handle`, with `C0 = RightGripAttachment.CFrame` and `C1 = tool.Grip`. The default `RightGrip` weld is destroyed. Clips can now key the weapon joint like any other, and the Animator writes its `Transform`. See [[Custom Rigs - Weapons and Props]].
2. **Driving the weld's C0 from code.** An earlier "premium motion" system moved the blade by writing `RightGrip.C0` every frame **on every client for every holder**, snapping back to the hand for swings, guard and abilities. The equip flourishes still use this approach for spins and tosses (see [[Equip Draw and Flourish Systems]]).

The trade-off: a Motor6D is animated by clips and replicates through the Animator for free; a code-driven C0 costs a script per client per holder but can do things clips cannot (free-body tosses under gravity, spins about an arbitrary axis, physics catches). Many games end up with both.

### Hand-space conventions

Consistent conventions are what let one IK toolkit pose hundreds of weapons:

- Blade along the hand's **-Z** (LookVector), edge toward the hand's **-X**. (Some kits used "edge faces the hand's -Y"; pick one per project and write it down.)
- Reference blade: 9.5 studs long, **gripped 20% up from the pommel**. About 20% of the blade sits behind the grip, and the arm QA models that part, because long pommels are what stab into torsos and hips.
- Scythe: held by its handle 1.1 studs from the butt, shaft along hand -Z, head on the hand's +Y side; the off hand grips forward on the shaft.
- Staff (double-ended): held at the centre of its grip parts, trail attachments on both ends, halves tagged `StaffHalf = "A" / "B"` for split moves.
- A model attribute `GripExact = true` skips the automatic 28% grip rule for models whose authored grip is already right.

**Case study: the orbit bug.** A grip finder scanned part names for "bit" (as in the blade's bit). It matched "Orbit_*" decorations and moved the grip to 18% from the butt on 11 weapons. Name-based scans need exclusion lists; the fix was to skip names containing "orbit".

**Case study: the first scythe set.** The first scythe animations failed QA because the heads were rotated 90 degrees from the convention and the left hand gripped about 1 stud off the shaft. The animation was fine; the hand-space contract was wrong. Check conventions on one weapon before authoring a set.

## Weapon classes

A class decides the idle, the carry layer and the click combo. In the reference project a class is chosen by a lookup with an attribute override (`WeaponClass` on the weapon model or tool):

| Class | Clips | Status in the reference project |
|---|---|---|
| Sword | combo swings, sword idle | Default for everything |
| Katana | own 4-hit chain | Shares the universal locomotion |
| Heavy | Swing1-3, carry, own idle | Paused (kept in data) |
| Scythe | Swing1-3, carry | Paused |
| Staff | Idle, Carry, Swing1-3 | Live, opt in by `WeaponClass = "Staff"` |

Classes **do not get their own locomotion**. One universal set serves everyone; the class contributes only its right-arm carry layer and, when standing still, optionally its own idle. The reasons are in [[Locomotion Systems]].

Making a new class opt-in by one attribute (instead of an id list in code) meant a designer could add a staff by tagging a model, and the dev proxy could test it in Studio by setting a "hold this weapon" attribute on the player.

## The priority map

Priority decides blending, but other systems also read it to infer intent, so it is a contract:

| Layer | Priority | Notes |
|---|---|---|
| Locomotion | Movement | Above Animate, below everything else |
| Carry | Action | Not Action2: flourishes cancel on Action2+, and Action2 "reads as an attack" |
| Swings, guard | Action | Guard keys the upper body only |
| Equip flourish body | Action2 | Upper body only, legs keep running |
| Weapon-part clips (blade unfold, rings) | Action2 on the weapon's own controller | 0.06 s fade |
| Stance clips (older dash stance) | Action3 | |
| Abilities | Action4, 0.05 s fade | Full body or upper copy |
| Enemy one-shots / hurt / layers / death | Action / Action2 / Action3 / Action4 | See [[Enemy Animation State Protocol]] |

How the Animator splits weight between these is in [[Playback, Priorities and Blending]].

## The life of a swing

Phases of a well-built swing: **rest, wind-up, coil, strike, follow-through, settle, rest.** When the reference project rebuilt its swings in phases, they came out 1.4x longer (0.42 / 0.42 / 0.47 s) than the originals and felt better, because the old ones had no settle. Then they were replaced again with the horizontal-slice set (durations 0.42 / 0.42 / 0.47 / 0.62, hits 0.20 / 0.20 / 0.23 / 0.30). Numbers and the combo logic are in [[Combat Combo Systems]].

Markers on every swing:
- `Hit`: drives damage timing (and the server's copy of it).
- `TrailOn` / `TrailOff`: gate the slash trail to just the cut, so the wind-up and follow-through do not draw a sheet of trail under the blade.
- Audio: the swing sound's crack peak lands on the hit (sound files are cut so their peak, not their start, aligns).

VFX and audio key off the swing's hit time. See [[VFX Timing with Animation]].

## Arm quality: what makes swings look broken

The reference project ran an arm/blade QA scorer over several hundred attack clips (see [[Arm QA Metrics Reference]]). At first audit 353 were "bad", median score 31/100, with arms inside the body in 318, pops in 314, wrist problems in 369 and the blade through the body in 312. The fixes taught pose rules that apply to any weapon game:

- **Arms behind the body** come from sprint, surf and "load" poses. A sprint into a thrust or cross-cut drives the forearm into the torso. Use a flat wind-up before thrusts and cuts.
- **Backhand winds and a two-handed low guard** put the forearm across the chest.
- **Big root-yaw swaps every 0.1 s pop.** In flurries, halve the root yaw and turn the waist more.
- **Long pommels:** make overhead, drive and kneel poses one-handed with the off hand out to the side; keep hands further from the body; a "chop" key carries the blade over the front before every drive (an overhead-to-drive swing near 180 degrees otherwise takes the short way back over the head).
- **The last key should be rest** (arms hanging like the game idle).
- **A wrist cannot aim a blade.** Lining the blade up with the forearm needs about 90 degrees of wrist deviation, so the arm must aim the blade.
- **Timing rules from the third pass:** no grounded stance change faster than 0.12 s; sub-0.1 s segments that move hips or feet go Linear, the first one easing In; overhead keeps the hips down, chop drops the hips first.
- **Re-key the end frames too.** A "ready" end pose put the pommel in the hip; fixing end frames brought 22 of 22 moves to at most 0.08 s of blade-through-body.

The tooling side is in [[Pipeline - Arm IK Baking and QA]]; the craft side in [[Weapon Swing Design]].

## Guard and parry

From the reference project's guard service:

| Parameter | Value |
|---|---|
| Parry window after raising guard | 0.26 s (no damage, enemy stunned 2.2 s) |
| Held block | damage x0.25 |
| Re-arm time | 0.55 s |
| Movement while guarding | speed halved |

The guard clip plays at Action and keys the upper body only, so the player can back-pedal with the guard up. Parry has its own clip. Guard sets `GuardingLocal`, which turns off the carry layer, blocks swings, and cancels equip flourishes. Details in [[Hit Reactions Stagger and Hit-Stop]].

## Weapon-part clips

Some weapons are rigs themselves: hinged blades that unfold, rings that spin, chains. They play their own clips on the weapon's own `AnimationController` while the body clip plays.

- In the kit framework, weapon-part ("ItemRig") clips play on the held model's controller at **Action2 with a 0.06 s fade**, registered once per clip and preloaded on equip; a Lua hinge player drives the weapon's idle.
- A rarity rule used for weapon design: Legendary and above must be animated, either with a controller plus clips on jointed parts, or with a procedural FX rig (one weapon drives 8 shard groups and 6 halo rings through weld C0). A weapon with a controller and clips but no Motor6Ds counts one tier down, because nothing moves.
- Joints with no Motor6D on the model are never animated. The Animator matches poses to joints by name, so keys for missing joints are silently inert. That is a common "my weapon clip does nothing" cause.

**Case study: weapon clips that only worked in Studio.** Dozens of kits played their weapon-part clips through `KeyframeSequenceProvider:RegisterKeyframeSequence`. Those ids only load in Studio, so in the live game the blades never moved. They were moved to a Lua hinge player; a published `<Clip>Id` attribute still wins when present. A weapon added later from an old template reintroduced the bug, so treat "registered at runtime" as a lint error. See [[Case Study - Abilities That Only Worked in Studio]] and [[Weapon Rig Player]].

## Weapon tricks through markers

A welded weapon cannot spin itself, and a clip cannot throw a weapon into the air as a free body. The reference project solved both with markers that trigger code on every client, on the track's own clock:

| Marker | Value | Effect |
|---|---|---|
| `StaffSpin` | `"turns,dur,dir,axis,up,down"` | Spin the staff (axis F / R / U = chest axes, H = forearm, or `x:y:z`) |
| `StaffSplit` / `StaffJoin` | `"dur"` | Split a double staff into two blades (half B to the left fist) and rejoin |
| `StaffFlip` | `"dur,state"` | End-for-end flip about the chest's right axis |
| `StaffThrow` / `StaffCatch` | none | Hide the held staff, fly a free copy, catch it |

Two rules make this safe: the handler **skips upper-body duplicates** of a clip (or every trick fires twice), and it **stands aside during flourishes**. A marker with a value string is a cheap, data-driven command channel from animators to code; see [[Markers and Events]].

## Movement while attacking

Attack move speed scales the current target speed (walk or sprint) while swinging; tuning went 0.55, 0.6, then 0.9. Swings on the move play their upper-body copy so the legs keep running; lunging finishers keep full body. Swings are blocked while the equip flourish or draw plays.

## Death

A death clip (hit recoil, kneel, fall onto the back, hold) is played via a character attribute so every client starts it. The character fizzles out at about 1.55 s and the death camera moves at about 2.45 s. The old side-topple is kept as a fallback for when the clip fails to load. Enemy death and ground fitting are in [[Enemy and NPC Animation]].

## Balance hooks that come from animation

- **Clip length feeds balance.** An ability's damage floor used `max(0.45 x cooldown, 1.2 x clip length)` per swing pace, so a long, cinematic move is not automatically weaker per second than a short one.
- **Enemy attack tempo is mostly clip length.** Shortening AI timers barely sped enemies up; the clips were most of the cycle. Only the follow-through after the last blow was sped up (x1/0.7). To make enemies faster, author faster blows.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Weapon clip has no effect | Weld grip, or keys for joints with no Motor6D | Motor6D grip; check joint names |
| Weapon parts animate in Studio only | Runtime-registered clip ids | Publish, or play through a Lua player |
| Arm sticks straight out over custom poses | Animate's tool-hold | Fade it to 0.001 |
| Flourish keeps getting cancelled | Some layer at Action2+ (often the carry) | Carry at Action |
| Pommel through the hip | Hand too close with blade pointing away | Hands further out; re-key end frames |
| Tricks fire twice | Upper-body copy fires the same markers | Tag copies and skip them |

See also: [[Combat Combo Systems]], [[Ability Kits Architecture]], [[Animation Quality Standard]], [[Markers and Events]], [[Cameras and Cutscenes]], [[Enemy and NPC Animation]].

## Connected notes
<!-- auto-links:start -->
[[Spec-Driven Move Authoring]] · [[Modeling Weapons and Props]] · [[Posing and Silhouettes]] · [[Custom Locomotion Controller Design]] · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Pipeline - New Animated Weapon]] · [[Animation Review Checklist]] · [[Blade Grip and Wrist Limits]] · [[Boss Animation and Phases]] · [[Animation Editor Workflow]] · [[Weapon Design Rig Builder]] · [[Animation Glossary]] · [[Troubleshooting Table]]
<!-- related:end -->
