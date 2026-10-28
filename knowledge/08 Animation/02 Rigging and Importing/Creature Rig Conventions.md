---
tags: [rigging, blender, enemies, creatures, conventions, families]
---
# Creature Rig Conventions (Blender to Roblox)

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: A member's roll differs from the family -> Rebuild roll by the family script
> - Avoid: Deleting unused family bones -> Keep them unweighted; Keep Zero Influence Bones on import
> - Avoid: Root translation not retargeted -> Scale translation by the height ratio
> - Build the family armature at its reference height with the names above; save one rig file with a proxy mesh.
> - Author the shared clips on the proxy (12-13 clips, markers included); export a test GLB, import it into a scratch place, and...
> - For each enemy: duplicate the armature, edit rest bone lengths only, model at true stud height, bind, paint the atlas...
>
> Cost: TL;DR ~200 tok · whole note ~3.6k tok. Read more: ## 2. Conventions shared by all families · ## 3. The five families · ## 9. Blender start checklist (per family) · ## Common mistakes
<!-- tldr:end -->

A convention sheet for building a **roster** of creature rigs that share clips, import cleanly and can be driven by generic code. It is distilled from one production game that planned its enemies as five rig families: every regular in a family uses the same bone names and hierarchy, the family's locomotion and reaction clips are shared, and each enemy only adds its own mesh, rest proportions and attack clips. The plan cut a realm's clip count from about 300 one-off clips to roughly 150 (about 61 shared, 66 own, 22 boss).

## 1. Why families pay off

| Without families | With families |
|---|---|
| Every enemy needs Idle, Walk, Run, Spawn, Taunt, three directional hits, Stagger, Stun, Knockup and Death of its own (12 clips) | Those 12 exist once per family; each enemy authors only 3-4 attack clips (bosses 8-12) |
| Procedural code (hit reactions, "caught in an ultimate" motion, death ground-fit) needs per-enemy bone tables | Code classifies bones by name and works on every member |
| Reskins mean new clips | Reskins keep bones and pivots; zero clip edits (a 49-model blocky roster was re-modelled this way) |
| Retiming a reaction touches 20 files | One family clip, re-exported for every member |

The cost is discipline: names, hierarchy and **roll** must never drift between members (see [[Blender Armature and Bone Roll Conventions]]).

## 2. Conventions shared by all families

| Item | Rule (project) | Why |
|---|---|---|
| Units and axes | 1 Blender unit = 1 stud, Z up, creature faces **-Y**, authored at final stud height | No scale objects; root translations are studs; imports face `LookVector` (measured importer turn) |
| Export | GLB, transforms applied, +Y up, armature at origin, **one armature per file**; import with Scale Unit "Stud" | See [[Exporting FBX vs GLB]] |
| Root | Bone `Root` on the ground under the centre of mass, at (0, 0, 0) | Ground reference for fitting and spawning |
| Mover | On import, an invisible non-colliding `HumanoidRootPart` box (body radius x height) at the hips, driven by the server | Server moves one part; clips never need root travel for locomotion |
| Controller | `AnimationController` + `Animator`, **no Humanoid** | Cheaper; nothing fights the server's movement |
| Skin | One skinned MeshPart per body, max 4 influences, normalised, no zero-weight vertices. Swarm units: rigid binding (one bone per vertex) | See [[Weight Painting and Skinning for Roblox]] |
| Rigid props | Weapons, shields, back-mounted props, shackles, pistons: separate MeshParts on a `RigidConstraint` to a Bone; breakable props released at runtime | Props never bend; can detach |
| Bone count | Regulars at most 40 deforming bones, bosses 60. Unused family bones **stay in the rig** with no weights | Keeps clips shared; enable "Keep Zero Influence Bones" on import or they vanish |
| Rest pose | Biped A-pose (arms 40 degrees down); quadrupeds standing square; flyers wings spread flat; floaters arms 30 degrees down | One rest per family; clips are offsets from it |
| Roll | Local X = creature right; +X lifts a limb forward; wing bones: +X flaps tips up | Same meaning of "pitch" everywhere; matches R15 |
| Names | ASCII, no spaces, side suffix `L` / `R`; chosen for the runtime classifier (section 4) | Generic code by name |
| Shared clips | **Rotations only**, plus Root/Hips translation authored at the family reference height | Rotations transfer between proportions; translations do not |
| Markers | `Tele`, `Hit`, `Hit2..`, `Proj`, `Summon`, `MoveStart`, `MoveEnd`, `Step`, `FX_<name>` | Exported into the enemy definition so the server never needs the clip |
| Texel density | Swarm 512, regulars 1K, minibosses 2K, bosses 2K + 1K; about 20 px per stud | Consistent look across a roster |

The top-level root pose of a KeyframeSequence is never applied (measured), so lifts, drops and leaps go on the **first child** of `Root` (`Hips`, `LowerTorso`, `Body`, `Core`).

## 3. The five families

### Biped (B): reference height 12 studs

R15 names (editor-friendly, already understood by R15 tooling) plus extras:

```
Root
 LowerTorso                 (hips)
  UpperTorso
   Neck (optional) -> Head
                       Jaw (opt), HeadProp (opt: hat, canopy, helm)
   LeftUpperArm -> LeftLowerArm -> LeftHand -> ShieldL / PropL (opt)
   RightUpperArm -> RightLowerArm -> RightHand -> Weapon (opt)
   Back (opt: back-prop socket)
   Cape1 -> Cape2 -> Cape3 (opt)
  LeftUpperLeg -> LeftLowerLeg -> LeftFoot
  RightUpperLeg -> RightLowerLeg -> RightFoot
  Tail1 -> Tail2 (opt)
```

16 core bones plus up to 10 extras. R15 parents `Head` directly under `UpperTorso`; the optional `Neck` breaks strict R15 compatibility, so only add it where the design needs a long neck.

| Variant | Proportions | Notes |
|---|---|---|
| Standard | legs 45% of height | most humanoid enemies |
| Knuckle-walker | legs 30%, arms reach the ground | own Walk/Run, shares the rest |
| Heavy | wide, legs 35% | own Walk/Run; a forearm piston as a sliding prop bone |
| Heavy miniboss | heavy plus hat, lamp, beard, chains, hammer | extras as optional bones |
| Boss | standard plus horns, pauldrons, a sliding chest plate, chains, a 4-bone cape | up to 60 bones |

Shared clips: Idle, Walk, Run, Spawn (rise from the ground), Taunt, HitFront, HitLeft, HitRight, Stagger, Stun, Knockup, Death.

### Quadruped (Q): reference height 8 studs to the head

```
Root
 Hips
  Spine -> Chest
            Neck -> Head -> Jaw
                            EarL, EarR (dangles; or HornL / HornR rigid)
            LegFrontL1 -> LegFrontL2 -> FootFrontL
            LegFrontR1 -> LegFrontR2 -> FootFrontR
  LegBackL1 -> LegBackL2 -> LegBackL3 -> FootBackL
  LegBackR1 -> LegBackR2 -> LegBackR3 -> FootBackR
  Tail1 -> Tail2 -> Tail3
```

26 bones. The hind leg has **three** segments for the digitigrade hock; a two-segment hind leg cannot make a dog or goat silhouette. A hopper variant replaces Walk/Run with Hop/HopFast.

### Flyer (F): reference body 5 studs

One superset rig for insects and birds; each mesh weights only the bones it has.

```
Root
 Body                          (thorax or bird chest)
  Neck -> Head -> Jaw          (mandibles or beak); AntennaL, AntennaR (opt)
  WingL1 -> WingL2 -> WingL3   (fore wing, or bird arm-hand-tip)
  WingR1 -> WingR2 -> WingR3
  WingL4 -> WingL5             (hind wing, insects only)
  WingR4 -> WingR5
  Abdomen -> Abdomen2 -> Sting (insects)  /  Tail1 -> Tail2 (bird tail fan)
  LegL1 -> FootL1, LegR1 -> FootR1
  LegL2, LegR2, LegL3, LegR3   (insect dangling legs, one bone each)
```

28 bones at most. Wings are single-sided alpha cards with double-sided rendering, or thin solid shells for chunky birds. Shared clips: Hover (= Idle), HoverMove (= Walk), FlyFast (= Run), Spawn, Taunt, three hits, Stagger (falls to the ground), StaggerGround (loop), Stun, Knockup, Death (falls). The **wing flap is a separate layer** keying only wing bones, so attacks keep flapping; make sure that layer does not key the body (see the partial-clip note in [[Exporting FBX vs GLB]]).

### Crawler (C): reference height 7 studs, body low

```
Root
 Body
  Head -> Jaw (or MandibleL / MandibleR); EyeStalk (opt)
  L1_1 -> L1_2 -> L1_3   R1_1 -> R1_2 -> R1_3     (front)
  L2_1 -> L2_2 -> L2_3   R2_1 -> R2_2 -> R2_3     (middle)
  L3_1 -> L3_2 -> L3_3   R3_1 -> R3_2 -> R3_3     (rear)
  Shell (opt, rigid)
  Tail1 -> Tail2 (opt)
```

24 bones at most; up to 6 legs of 3 segments, named so a pattern like `^[LR]%d` finds legs. A four-legged member keeps the middle pair **unweighted** rather than deleting it, so the six-legged clips still apply.

### Floater (L): reference height 7 studs, hover 1-4 studs

```
Root
 Core
  Head (or Mask) -> Jaw (opt)
  ArmL1 -> ArmL2 -> HandL      ArmR1 -> ArmR2 -> HandR   (opt)
  Shroud1 -> Shroud2 -> Shroud3                          (cloak, dangle)
  TL1 -> TL2 -> TL3            TR1 -> TR2 -> TR3         (ribbons, tentacles)
  Orbit1, Orbit2, Orbit3       (rigid props spun in code)
  Rotor (opt, spun in code)
  PropL, PropR (opt)
```

22 bones at most. No legs: death ground-folding does not apply (it drops first). A rigid drone variant used rigid binding and no smooth skinning at all.

## 4. Name-driven runtime classification

The project's creature motion code lowercased bone names and matched keywords to give every bone a role:

| Role | Keywords |
|---|---|
| core | torso, spine, chest, hips, body, core, shell, carapace |
| head | neck, head, skull, mask |
| jaw | jaw |
| arm | arm, fore, hand, claw |
| leg | leg, thigh, shin, foot, or `L1..` patterns |
| wing | wing |
| tail | tail, sting, abdomen |
| dangle | cape, shroud, skirt, `T[LRB]n`, tent |
| prop | axe, shield, weapon, staff, lantern |

Side came from the bone's X position, not its name. Family detection: two or more wings = flyer; no legs = floater; four or more legs (or low with claws) = crawler; else biped. Quadrupeds were classified as crawlers, which was accepted ("same spring feel").

With roles known, generic code can add secondary motion to dangles and tails, aim heads, flinch cores on hits, and fold legs on death without per-enemy tables. Name collisions are the risk: "forearm" and "fore wing" both contain "fore". Choose names with the classifier in mind, and log the role table on every import.

## 5. Sharing clips across sizes

- **Rotations transfer; translations do not.** A clip authored on a 12-stud reference biped plays on a 16-stud member with correct poses, but its hip bob and root lift are too small. The project re-baked root translation per enemy in Blender: `translation x (enemyHeight / referenceHeight)`. See [[Retargeting Animations Between Rigs]].
- **Rest proportions may differ, roll may not.** Members edit rest bone lengths only, keeping names, hierarchy and roll.
- **Playback rate for scaled enemies:** bigger creatures should move slower. The project slowed walk clips to `0.85 / sqrt(scale)` for scaled enemies (pendulum scaling: stride frequency falls with the square root of leg length).
- **Do not force clip speed to match move speed when strides disagree.** Measured strides were 2-4 times slower than the definitions' move speeds; syncing playback rate to speed "would play frantic". Either author strides to match speed or accept some slide.

## 6. Part rigs and skinned rigs share clips by name

KeyframeSequences match joints by the child's name. A rigid construct can ship as a Motor6D **part** rig with the family's bone names, and the same clips play on it. The project's motion code and death ground-fit originally read Motor6Ds only; skinned rigs needed a small **Bone adapter**: write `Bone.Transform` instead of `Motor6D.Transform`, read `Bone.TransformedWorldCFrame` / `WorldPosition` instead of part CFrames, and sample ground under a 3x3 grid, lifting the Root by the deepest bone minus a skin pad. See [[Bones and Skinned Meshes]] and [[Ground Fitting Pipeline]].

## 7. Markers and the server

Put timing in markers, export marker times into data, and let the server read data, never clips:

- `Tele` at the start of the readable wind-up, `Hit` at the damage frame. The gap (`Hit - Tele`) is a design number; the project's exporter computed it for every clip and checked it against the design tables. Boss warnings and combo links were at least 0.5 s, and markers locked at least 0.45 s before the blow.
- `MoveStart` / `MoveEnd` bracket root travel the server must replicate (lunges, leaps).
- `FX_<name>`, `Step` and `Release` drive client effects and sounds.

The server writes animation state as replicated attributes and plays nothing; see [[Enemy Animation State Protocol]].

## 8. Part-based reskins

For blocky or voxel styles, keep bones and pivots identical between old and new models and every clip still fits. Exaggerate features for readability (fists 1.4x, forearms 1.25x) **around the existing pivots**: scale meshes about their joint points, never move the joints.

## 9. Blender start checklist (per family)

1. Build the family armature at its reference height with the names above; save one rig file with a proxy mesh.
2. Author the shared clips on the proxy (12-13 clips, markers included); export a test GLB, import it into a **scratch place**, and check Animator playback and that the runtime classifies every bone (log the roles).
3. For each enemy: duplicate the armature, edit rest bone lengths only, model at true stud height, bind, paint the atlas, retarget the shared clips (root translation x height ratio).
4. Author attack clips with `Tele` to `Hit` spacing from the design tables; run the marker exporter to produce the definition table.
5. Export GLB and clip tables; publish clips or ship them through a Lua player.

## Common mistakes

| Mistake | On screen | Fix |
|---|---|---|
| A member's roll differs from the family | Shared clip bends one limb sideways on that member only | Rebuild roll by the family script |
| Deleting unused family bones | Clips error or skip; sockets missing | Keep them unweighted; Keep Zero Influence Bones on import |
| Root translation not retargeted | Big creature's hips barely bob; small one bounces | Scale translation by the height ratio |
| Lift keyed on `Root` | Spawn rise does nothing | Key the first child |
| Wing layer keys the whole body | Attacks freeze the body while wings flap | Partial clips key only wing bones |
| Names that fool the classifier | Wing treated as arm, tail as leg | Check the logged role table on import |

## See also

[[Rigging in Blender]] · [[Blender Armature and Bone Roll Conventions]] · [[Weight Painting and Skinning for Roblox]] · [[Pipeline - Importing Animated Enemies]] · [[Enemy Import Axis Fix]] · [[Animating Creatures and Monsters]] · [[Enemy and NPC Animation]] · [[Retargeting Animations Between Rigs]] · [[Boss Animation and Phases]]

## Connected notes
<!-- auto-links:start -->
[[Modeling Characters for R15 and Custom Rigs]] · [[Skeleton Library]] · [[Animation Data from Blender to Roblox]] · [[Procedural Death Knockdown and Hit Reactions]] · [[Case Study - Enemy Roster Rebuild]] · [[Organic and Creature Modeling]] · [[Animation Start Here]]
<!-- auto-links:end -->
