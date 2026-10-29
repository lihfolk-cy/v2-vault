---
tags: [pipeline, import, enemies, blender, gltf, type/guide, area/animation, level/intermediate, api/Animator, area/modeling, api/KeyframeSequence, api/Humanoid]
---
# Pipeline: Importing Animated Enemies

<!-- tldr:start -->
> [!tldr] TL;DR
> - Blender conventions met (units, -Y facing, Root bone, influences, bone budget, names).
> - Clips table exported with durations, loop flags and marker times.
> - Imported without moving it; identified by content.
> - `Prepare` report: clips all found, markers added, no Humanoid.
> - `SetIds` (with or without ids): model stored, clip sources moved out, definition patched, Tele / Hit present on every attack.
> - Axis fix applied (clip attribute shows fixed or wrapped); facing checked against the root's LookVector in a test spawn.
>
> Cost: TL;DR ~170 tok · whole note ~3.3k tok. Read more: ## 1. Build in Blender (conventions that make import boring) · ## 3. Prepare (one idempotent function per enemy) · ## Checklist per new enemy
<!-- tldr:end -->

The route one production game used to bring a roster of Blender-built creatures (about 20 rigs and 350 clips in the first wave, later dozens of kits and well over a thousand clips) into Roblox with working markers, correct facing, ground contact and a small runtime footprint. It is a chain of small, idempotent tools around one manual step (the import). The single most important link, the axis fix, has its own note: [[Enemy Import Axis Fix]]. Ground contact: [[Ground Fitting Pipeline]]. Rig authoring conventions: [[Creature Rig Conventions]].

```
Blender build ──► GLB + clips table (marker times) ──► manual import ──► Prepare ──► (publish?) ──► SetIds
      ──► FixClipAxes (+ path normalise, strip root yaw on Turn clips) ──► ground fit ──► bake to stubs ──► runtime
```

## 1. Build in Blender (conventions that make import boring)

| Rule | Value | Why |
|---|---|---|
| Units | 1 Blender unit = 1 stud, authored at final stud height | no scale guessing on import; root motion distances are real |
| Axes | Z-up, model faces **-Y** | lands facing the root's LookVector after import (see below) |
| Export | GLB, transforms applied (scale 1, rotation 0), +Y up, armature at the origin, one armature per file | the importer's conversion is then predictable |
| Root | a bone named `Root` on the ground under the centre of mass | the import tool derives the ground and root height from it |
| Skinning | at most 4 influences per vertex, normalised, no zero-weight vertices | Roblox skinning limit; zero-weight vertices collapse to the origin |
| Bone budget | at most 40 deforming bones for regulars, 60 for bosses | performance; a 42-bone, 23-clip boss was the upper end |
| Rest pose | A-pose (arms about 40 deg down); bone roll X = right, so +X lifts a limb forward | consistent rotation conventions for shared clips |
| Names | ASCII, side suffix L / R, keywords a classifier can read (core, head, jaw, arm, leg, wing, tail, dangle, prop) | tools find roles by name (ground fitting, procedural reactions) |
| Rigid props | parented with `RigidConstraint` to a bone | no skinning cost for hard surfaces |
| Spinning pieces | orbiting rings, lanterns, hems: **strip them from the clips** and spin them in code | constant rotation in a clip costs keys forever and loops visibly |

**Clip names** must match exactly what the game asks for (`Idle`, `Walk`, `Attack1`, `Death`, `Hit`, `Turn...`). Export a **clips table** alongside the GLB: per clip its duration, loop flag and marker times (`Tele`, `Hit`, `Hit2`, `Proj`, `Summon`, `MoveStart` / `MoveEnd`, `Step`, `FX_<name>`). The server uses those times without ever touching the clip.

## 2. The manual import

- File > Import 3D, the GLB, rig and animations on, into Workspace. **Do not move or rotate the model afterwards**: the prepare step reads the bind pose as imported.
- The import arrives as a Model often named `Scene`. With two imports in Workspace there are two `Scene` models, so tools **identify imports by content** (bones, expected part names, an attribute you add), never `FindFirstChild("Scene")`.
- Imported clips land in `ServerStorage.RBX_ANIMSAVES`, in a folder per model. Kit meshes may arrive renamed with a suffix (`<Name>__exp`).
- **The importer drops GLB base colours.** Re-apply colours from a manifest, or use textures.
- Check that the import succeeded instead of assuming it: names, hierarchy, pivot, scale, orientation, and that the animations really move the rig. Distinguish three different things people call "the animation": embedded GLB animation data, Roblox `KeyframeSequence` / `CurveAnimation` objects in the place, and published Animation assets.

### Axis facts (measured)

- Studio's importer turns a GLB **180 deg about Y**: glTF x and z land on Roblox -x and -z. Every bone of the first roster had its head at -Z of `Root`.
- So a model authored facing **-Y in Blender** (glTF +Z forward after Blender's Y-up export) lands with its front on the Roblox **LookVector**. The prepare tool's yaw fix is therefore **0, not 180**.
- Position mapping for placing things by hand: Blender (x, y, z) -> Roblox (-x, z, y).
- Pass the yaw fix explicitly. A stale cached module once supplied an old default of 180 and turned a batch around.

## 3. Prepare (one idempotent function per enemy)

`Prepare(model, { Id, YawFix = 0, Markers = true })` does everything that needs the bind pose:

1. **Bounds and ground.** World AABB of all parts in the bind pose. Ground = the `Root` bone's world Y (fallback: the lowest point). Centre X/Z from the Root bone (fallback: the box centre).
2. **HumanoidRootPart.** An invisible, non-colliding, non-touching, non-queryable, anchored part, sized `2r x height x 2r` from the enemy definition (fallback radius `clamp(0.4 * min(sizeX, sizeZ), 0.5, 20)`), placed at the body centre and yawed by the yaw fix, made the PrimaryPart. Attribute **`RootHeight`** = root centre height above the ground (3 decimals), which the server uses to stand the mover on the floor.
3. **Welds.** Every other part gets a `WeldConstraint` to the root (named so a rerun replaces it) and is made non-colliding.
4. **Animator.** An `AnimationController` with an `Animator`, no Humanoid. A Humanoid that came with the import is reported for manual deletion.
5. **Alpha materials** where needed (wing cards: `SurfaceAppearance.AlphaMode = Transparency`).
6. **Clips.** Every KeyframeSequence or [[CurveAnimation]] found on the model, in the importer's save folder, or in the clip-source folder is matched to the clips table by name (case-insensitive, after stripping `<Id>_` and `Armature_` prefixes and any `|` path). For each:
   - `Loop` from the table;
   - `Priority`: `Attack*` -> Action; `Idle`, `Hover` -> Idle; names containing Walk / Run / Hop / Fly, or `HoverMove` -> Movement; anything else -> Action;
   - **markers** from the table: a `KeyframeMarker` is added to the keyframe within half a 30 fps frame (1/60 s) of the marker time, or to a new keyframe named `Marker_<name>` at that time. Existing markers of the same name are left alone, so reruns do not duplicate. CurveAnimations get a `MarkerCurve` instead.
7. **Report:** root size, root height, how the ground was found, clips found / missing / unmatched, markers added, and a ready-to-fill `SetIds(...)` line.

## 4. Publish or not

Two runtime options:

- **Published assets.** Publish each clip, then `SetIds(id, { Attack1 = <assetId>, ... })` stores them as `ClipId_<Clip>` attributes. The real Animator plays them.
- **No publishing.** A Lua keyframe player plays the KeyframeSequence data directly ([[Lua Keyframe Player]]). The reference project ended up here: "publishing ids is no longer needed for enemies (ids, when set, still win)". `SetIds(id, {})` still does all the moving and patching below.

Never use `KeyframeSequenceProvider:RegisterKeyframeSequence` ids at runtime: they did not load in live servers ([[Case Study - Abilities That Only Worked in Studio]]).

## 5. SetIds: store, move, fix, patch

`SetIds(id, ids, { DryRun, NoMove, NoDefs, NoAxisFix })`:

1. Validates ids (positive integers) and clip names against the table.
2. Stores `ClipId_<Clip>` attributes on the model.
3. Moves the model into the enemy model library.
4. **Moves every clip source out of the model** into a per-enemy clip-source folder. Spawned enemies are clones of the model; clips inside it would be copied into every live enemy. (In the reference project the server also stripped `Animations` / `AnimSaves` folders from clones, so clips had to live elsewhere anyway. Before this rule, enemy models carried 207k instances of animation copies that were destroyed on every spawn.)
5. Runs the **axis fix** on the clip sources ([[Enemy Import Axis Fix]]): corrects the pose data, re-paths poses under the part holding the Root bone, strips root yaw from `Turn*` clips.
6. **Patches the enemy definition**: rewrites its `clips = { ... }` block with `{ id, dur, loop, marks = { ... } }` per clip, sorted, then compiles and loads the patched module and checks that every attack's clip has both `Tele` and `Hit` marks. On any failure nothing is written.

The definition patch is what lets the server stay animation-free: AI timing comes from `marks` (telegraph at `Tele`, damage at `Hit`, projectiles at `Proj`), with a marker-driven path when a clip exists and a fallback of the definition's mark time + 0.3 s if a marker never fires.

## 6. Other import defects seen in production

| Symptom | Cause | Fix |
|---|---|---|
| whole roster attacks "from behind", root motion missing | importer convention: poses conjugated by a 180 deg turn, root pose at the keyframe top level | [[Enemy Import Axis Fix]] |
| one boss's forward / back root travel mirrored | a different importer quirk on that rig | flip the LowerTorso pose Z for that rig's clips |
| prop-layer clips ignored by the Animator | pose path did not follow the bone path | normalise pose paths (part > Root > ... > parent bone) |
| three clips occasionally play a limb the other way | keys at exactly 180 deg; the Animator itself flips a coin | re-key away from exactly 180 |
| standing enemy's legs 0.5-1.5 studs into the floor | wrong [[HipHeight]] on templates | fix HipHeight per template (17 were fixed; the old value kept in an attribute) |
| death clips sink limbs up to 9.4 studs into the floor | clips drop the root without folding limbs | [[Ground Fitting Pipeline]] |
| colours missing | importer drops base colours | re-apply from a manifest |

## 7. Ground fit, then bake

- **Ground fit** every clip that dips (all death clips; in the reference project 205 more clips across 18 rigs) with the offline-style tool in [[Ground Fitting Pipeline]], plus a runtime clamp for slopes and raised floors.
- **Bake to stubs** once the clips are final ([[Baked Clip Stubs and Archiving]]): the server ships each kit's clips as compact buffers, streamed once per client. Any tool that edits poses (axis fix, root-yaw strip, path normalise, frame-rate fixes, re-keys) must restore the kit's originals first and rebake afterwards; the reference tools do the restore themselves.

## 8. Runtime contract (summary)

- **Server never plays clips.** It writes replicated attributes (current clip, start time, speed, loop, hurt direction, layer, phase) and times gameplay from definition marks.
- **Clients play everything**, through the Lua player, with LOD by distance.
- **Clip lookup order:** model `ClipId_*` attribute -> definition id -> a Studio-only mirror (debug) -> a procedural Root-bone pose (so a rig never T-poses while its clips stream in).
- **Shared clips across a family:** rotations only, plus root translation at the family reference height; retarget root translation by the height ratio. Clips match by joint name, so they also play on Motor6D part rigs with the same names; skinned rigs need a bone adapter writing `Bone.Transform`.
- **Scale:** scaled enemies may slow their walk to 0.85 / sqrt(scale) so feet do not skate; never play enemy clips below 1x except a deliberate stagger (0.5x).

See [[Enemy and NPC Animation]], [[Enemy Animation State Protocol]], [[Snippets - Enemy Client Animator]].

## Checklist per new enemy

- [ ] Blender conventions met (units, -Y facing, Root bone, influences, bone budget, names).
- [ ] Clips table exported with durations, loop flags and marker times.
- [ ] Imported without moving it; identified by content.
- [ ] `Prepare` report: clips all found, markers added, no Humanoid.
- [ ] `SetIds` (with or without ids): model stored, clip sources moved out, definition patched, Tele / Hit present on every attack.
- [ ] Axis fix applied (clip attribute shows fixed or wrapped); facing checked against the root's LookVector in a test spawn.
- [ ] Root motion visible (spawn rise, leaps) after the fix.
- [ ] No keys at exactly 180 deg.
- [ ] Ground fit run; worst penetration on flat ground at or above 0.
- [ ] Baked to stubs; Verify passes.

## See also

[[Enemy Import Axis Fix]], [[Ground Fitting Pipeline]], [[Creature Rig Conventions]], [[Importing Models and Rigs]], [[3D Importer Settings Reference]], [[Exporting FBX vs GLB]], [[Animation Data from Blender to Roblox]], [[Bones and Skinned Meshes]], [[Lua Keyframe Player]], [[Baked Clip Stubs and Archiving]]

## Connected notes
<!-- auto-links:start -->
[[Rigging in Blender]] · [[Blender Armature and Bone Roll Conventions]] · [[Animation Start Here]] · [[Moon Animator and Third-Party Tools]] · [[Skeleton Library]] · Character and Creature Pipeline
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Weapon Design Rig Builder]] · [[Animating Creatures and Monsters]] · [[Weight Painting and Skinning for Roblox]] · [[Retargeting Animations Between Rigs]] · [[Animation Glossary]] · [[Pipeline - New Animated Weapon]] · [[Boss Animation and Phases]] · [[Custom Rigs - Weapons and Props]]
<!-- related:end -->
