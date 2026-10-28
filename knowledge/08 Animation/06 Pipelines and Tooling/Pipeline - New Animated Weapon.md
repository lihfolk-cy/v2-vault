---
tags: [pipeline, weapons, rigging, kits, workflow]
---
# Pipeline: New Animated Weapon

<!-- tldr:start -->
> [!tldr] TL;DR
> - Import by a human: Merge Meshes OFF, Rig none; found by name.
> - Rig built: Handle root, one Motor6D per hinge, chain links welded, clips thinned, Animator present.
> - FX module compiles and runs on the rig.
> - Config, voice, sheath inserted through the safe-edit helper.
> - Kit sources pass size, reserved-name, forbidden-id and order checks.
> - Each move STAGED; kit installed; folder under 2,500.
>
> Read more (18 KB note): ## Step 1: offline generation · ## Step 5: design the kit · ## Checklist
<!-- tldr:end -->

How one live action game took a modelled weapon (a GLB plus a setup script describing its hinges, materials and effects) to a held, animated weapon with an ability kit, in about 1-1.5 hours, most of it creative work. It ran dozens of times; the steps below are the version that survived. The weapon's own rig is covered in depth in [[Weapon Design Rig Builder]], its runtime in [[Weapon Rig Player]], the arm pass in [[Pipeline - Arm IK Baking and QA]].

## What "a weapon" is in this pipeline

| Piece | What it is | Plays through |
|---|---|---|
| **Design rig** | a Model: anchored `Handle` root, one Motor6D per hinge, everything else welded; `Idle` (looping) and `Special` clips | the weapon rig player (Lua, writes `Motor6D.Transform`) |
| **FX module** | per-weapon ModuleScript + data: glow tracks, spins, emitter windows, ribbons, light, the special's trigger | runs on the held copy on every client |
| **Item data** | config line (rarity, stats), lore, voice, sheath style | game systems |
| **Ability kit** | a folder: remotes, the moves' character clips, `ItemRig` clips for the weapon's own parts during moves, the Moves module | ability controller, Lua keyframe player, rig player |
| **Registration** | kit table, move info, icons, ultimate camera anchor, beat markers, preview data | registries |

Two kinds of animation are involved and must not be confused:

1. **Weapon-part clips** animate the weapon's own hinges (a blade unfolding, rings spinning). They are tiny clips on a tiny rig.
2. **Character clips** animate the player holding it (the moves). They are full R15 clips with markers and go through the IK arm pass.

## Time budget per weapon

| # | Step | Who | Time |
|---|---|---|---|
| 0 | Import the GLB (Merge Meshes OFF, Rig none, into Workspace) | human | 1 min |
| 1 | Parse setup + GLB offline; generate rig installer, FX module, item data | tool | under 1 s |
| 2 | Build the rig and FX in Studio | tool | about 1 min |
| 3 | Render an icon (Blender, background) and upload | tool + human | about 3 min |
| 4 | Config line, voice rows, sheath measurement | tool | about 1 min |
| 5 | Design the kit (moves as key-pose specs) | designer | 30-45 min |
| 6 | Build kit sources offline (assembly + checks) | tool | seconds |
| 7 | Bake and install kit clips (sliced Studio calls) | tool | about 5 min |
| 8 | Register (kit tables, icons, camera anchors, beat markers, preview) | tool | about 1 min |
| 9 | Dev test, arm bake and QA | tool + human review | 15-25 min |
| 10 | Verify and clean up | tool | about 2 min |

Everything a tool can do is a tool; the human does the import (Studio cannot import a local file from a script), the creative kit design, publishing (if you publish), and the play test.

## Step 0: the import

- **File > Import 3D**, the `.glb`, **Merge Meshes OFF** (each mesh stays its own part, so hinges have something to move), **Rig: none** (the weapon is not a skinned rig; hinges are built afterwards), insert into Workspace.
- The setup script embeds **three reference parts** (`RbxRefA/B/C`) at known design-space positions. They are how the installer recovers the import's exact rotation and scale later (see [[Weapon Design Rig Builder]]). Their presence is also the "this is our import" fingerprint.
- **Find the import by name, never by Selection.** Several imports can sit in Workspace at once, and whatever happens to be selected is not a contract. The installer looks for a top-level Model with the expected name that contains `RbxRefA`.
- **Search top-level children only.** The setup's original search walked every Workspace descendant, which took seconds in a large place.
- Keep a pristine copy of the import: the build consumes it (parts move into the rig), and reruns rebuild from the copy when Workspace no longer has one.

## Step 1: offline generation

A Python driver reads the setup script and the GLB:

- **Setup parsing** (format v2): the hinge table (`{ name, part, pivot Vector3, CFrame }` per hinge), materials (`MAT`: material, colour, reflectance, transparency per part), owner and link tables (which part welds to which), hanging chain links, FX attachments, ribbons, and the animation data block (idle length and fps, special length and fps, per-hinge flags for "has position keys", and the raw per-frame quaternion arrays). A legacy setup format is detected and refused with a pointer to the older route.
- **GLB parsing:** the glTF JSON chunk and binary buffer are read directly (no Blender) to get each mesh node's bounds and vertices. The blade's vertex profile (17 rows of min/max X along the blade's Y span) feeds the aura/glow effect.
- **Blade colour:** the most common *saturated* neon material colour (saturation over 0.25), normalised to full brightness. White and grey neons are common on many setups and would otherwise win.
- **Weapon-part clips:** `Idle` and `Special` are built from the setup's per-frame hinge data and **thinned per joint**:
  - rotation tolerance **0.004 rad** (about 0.23 deg) checked with quaternion nlerp between kept keys;
  - position tolerance **0.003 design units** for hinges with position keys;
  - never more than **0.5 s** between kept keys;
  - joints that never leave rest are dropped;
  - a looping idle gets frame 0 appended at the clip's end so the loop closes exactly.
- **Outputs:** the rig installer (Luau), the FX module and its data module (data over about 195,000 characters is split into child modules, because a Script `Source` must stay under 200,000), an install JSON (item config line fitted to the rarity's current top items, lore line, voice row, sheath style hint), a meta file, and optionally a kit scaffold copied from a template.

Item stats are fitted, not invented: the tool takes the six highest-odds items of the same rarity, fits a line of each stat against odds, and evaluates it at the new item's odds (defaulting to 1.14x the current top). That keeps a new weapon consistent with its neighbours.

## Step 2: build the rig and FX in Studio

One call each, each well under the Studio call budget ([[Studio Tooling Architecture]]):

- **probe**: is the import present? are the rig, FX, item and kit already there? (read-only)
- **rig**: runs the generated installer: recovers the design frame from the reference parts, destroys the importer's joints, builds the Design rig under the character-models folder, writes the clips, sets attributes, parks the previous rig and the pristine import in a work folder.
- **fx**: installs the FX module plus its data (and ribbon chunks), compiles each, clone-requires the result.

The rig is described in [[Weapon Design Rig Builder]]. Key facts here:

- `Handle` is the PrimaryPart, anchored only while it sits in storage, with a `Scale` attribute and a `BladeFrame` attachment (the design frame).
- One **Motor6D per hinge**, named after the hinge. Everything else welds to its owner part or the Handle.
- **Hanging chain links are welded rigid.** In the designer's preview they swing with physics, but a held weapon is massless and replicated, and physics chains on it jitter.
- `Idle` (Loop, Idle priority) and `Special` (Action priority) KeyframeSequences in an `Animations` folder, plus an `AnimationController` with an `Animator`.
- Attributes: `FXModule`, `IdleId` and `SpecialId` (empty: published ids go here if you publish), `BladeColor`.

## Step 3: icon

A background Blender render (about 2 minutes) frames the weapon from its GLB with the game's icon lighting, using a part-look file the Studio side posts (material, colour, transparency per part, so the render matches what Studio shows). The PNG is uploaded and its asset id goes into the item line.

## Step 4: config, voice, sheath

Each is **one insert** into a shared module through the safe-edit helper (re-read, idempotency check, size check, compile, use-before-definition scan, one safety copy, changed-underneath check, write, clone-require, revert on failure).

The sheath stage measures the held weapon (blade length, widths, curvature "sag", neon share, whether it has an ignition effect) and picks a style:

| Rule (first match wins) | Style |
|---|---|
| set by hand | as given |
| heavy or scythe class | none |
| blade over 9.0 studs | none |
| over 2.2 studs across | none (too wide) |
| thinner dimension over 1.5 | none (too bulky) |
| has an ignition (turn-on) effect | energy |
| sag / length >= 0.03, across <= 1.6, neon < 0.3 | saya (curved blade) |
| otherwise | sword |

## Step 5: design the kit

The only creative step. Each move is a **spec**: a list of key poses with times, easing and markers (hand target, blade direction and edge, root, waist, neck, off hand, feet). See [[Spec-Driven Move Authoring]] and [[Authoring Clips in Code]]. Per rarity the template sets the number of moves (2 for the lowest animated tier up to 6), plus one shared move appended to every kit. Conventions that worked:

- Wind-ups `CubicV2 In`; strikes `CubicV2 Out` with denser in-betweens (`sp = 0.045 s`); settles `CubicV2 InOut`.
- Successive breaking via lag: neck 0.035 s, waist 0.015 s, free arm 0.05 s behind the root.
- A shared library of named poses (ready, overhead, drive, wind, cut, follow, low, rising, high, falling, chamber, thrust, crouch, cast, salute, kneel) with per-key overrides, and foot presets.
- Root drops no deeper than about -1.0 (deeper pushes a foot 1-2.5 studs through the floor).
- Every strike has a `Hit` marker; trails gated by `TrailOn`/`TrailOff`; beat markers mapped to a juice table.
- The ultimate is last and follows the ultimate contract (anchor and pull enemies before damage).
- **Never name a move** `Attack`, `Origin`, `FX`, `LocalCast`, `Moves` or `ItemRig`: those are reserved children of the kit folder. A clip named `Origin` once replaced the kit's `Origin` RemoteEvent and the whole kit stopped dealing damage.

Weapon-part clips for moves use a compact format (degrees per hinge):

```lua
return {
	Unfold = { len = 0.9, keys = {
		{ t = 0,   poses = { Seg1 = { 0, 0, 0 },  Ring = { 0, 0, 0 } },   e = "Linear" },
		{ t = 0.3, poses = { Seg1 = { 0, 0, 75 }, Ring = { 0, 120, 0 } }, e = "Linear" },
		{ t = 0.6, poses = { Seg1 = { 0, 0, 75 }, Ring = { 0, 240, 0 } }, e = "CubicV2", d = "Out" },
		{ t = 0.9, poses = { Seg1 = { 0, 0, 0 },  Ring = { 0, 360, 0 } } },
	} },
}
```

Written as a KeyframeSequence with a weight-0 root Pose named `Handle` and one child Pose per hinge (named after the hinge's moving part), `CFrame.Angles` in degrees, priority **Action2**, not looped, default easing Linear/In. Note the ring keys 120 deg apart: a single 0 to 360 key pair would not turn at all (identical rotations), and keys exactly 180 deg apart make the Animator pick the direction arbitrarily. Keep consecutive keys well under 180 deg apart, ideally under 120 ([[How the Animator Really Behaves]]).

## Step 6: build kit sources offline

An assembler concatenates the kit's head, the shared core library, the shared effects layer, the kit body and a footer into the Moves module, patches in the ultimate-camera gate, fills the server and client templates, and copies the specs and weapon-part clips. It sets the baker's blade length (`TIP`, grip to tip at scale 1 = held reach / 1.6) for this weapon. Checks, failing the build:

- every Source under 200,000 characters;
- no forbidden sound ids (a list of removed recordings);
- no reserved move names;
- the spec `ORDER`, the Moves functions and the server move table list the same moves.

Two patches are applied to the baker on the way:

- **Seed loop cap:** the IK baker's fallback seed loops may take over 1 s per frame on unreachable targets; they are capped at 0.3 s per solve to keep Studio calls short. (The arms are re-solved offline later anyway.)
- **Marker values:** a spec marker written `Name=value` becomes a KeyframeMarker `Name` with that `Value` (for example `StaffSpin=2,0.5,1,F,0,0`); plain names keep the clip name as their value.

## Step 7: bake and install the kit

The Studio kit tool has five modes:

- `check`: compile and scan the Moves, Server and Client sources; report sizes.
- `bake`: one slice of a move's body-clip bake per call (the in-Studio spec baker, `bakeBegin` / `bakeStep(budget 0.9 s)`), repeated until it reports `STAGED` with keyframe count, instances, markers and max errors (hand, blade direction, grip, feet, edge, left hand). Measured: about 0.5 s per baked frame; 15 / 20 / 47 frames for 1.0 / 1.3 / 3.6 s clips. A stuck "frames done, call again" resolves with one more call.
- `rig`: builds the weapon-part clips into the stage.
- `install`: writes the kit folder (remotes `Attack`, `Origin`, `FX` as RemoteEvents and `LocalCast` as a BindableEvent; the staged clips with empty `<Move>Id` attributes; the `ItemRig` folder with empty `<Clip>Id` attributes; the Moves module), the server Script and the client LocalScript. It clone-requires Moves to check every move function exists, keeps one copy of a replaced kit, and reports the folder count with "(OVER 2,500)" if over budget.
- `status`.

**Budgets:** a kit folder should stay under 2,500 instances (clips are about 300-700 instances each; an ultimate reached 719; weapon-part clips under 80). Typical density: 22-30 keys/s for normal moves, about 16 for ultimates. Weapon-part clips sampled every 0.05 s blew the cap once; thinning them to 0.12 / 0.19 s spacing fixed it.

## Step 8: register

One stage inserts the kit's rows into the shared registries: kit table and move info, the shared-move append list, move icons, the ultimate's camera anchor spec, the beat-marker table (which marker of which move triggers which screen shake or effect tier) and the travel table. A preview stage writes the move-list preview data (the ultimate's camera box plus the shared move's row).

## Step 9: dev test and arm pass

- **Dev test** each move: the spec baker's diagnostics (`minClear` should stay at about -1.3 or better, meaning no foot deeper than that through the floor).
- **Arm pass** per move, never `--all` (it stops at the appended shared move, which has no clip in this kit): dump, baseline, bake with filmstrip, look, test-write (one move per call), play the test folder on the Animator, verify, install. Gate: zero criticals and model vs Animator under 3 deg. See [[Pipeline - Arm IK Baking and QA]].

## Step 10: verify and clean up

The verify stage checks four things in one call:

1. **Hold:** builds the held weapon with a fresh copy of the config (Edit caches the old one), attaches it to the reference dummy, reports length, grip-part-to-hand distance and reach.
2. **Hinges:** clones the rig into Workspace, loads `Idle` and `Special` through a fresh copy of the rig player, takes it off the shared loop (`SetManual`), steps it by hand (`Step(rig, 1.7)`, then the special), and counts how many motors actually moved. `Motor6D.Transform` does not move parts on its own in Edit, which is why stepping by hand is needed.
3. **FX:** requires the FX module, runs it on the rig, steps the idle and triggers the special.
4. **Registry:** for every kit, every non-shared move has a clip, an info entry and a Moves function.

Cleanup removes test objects and restores the camera to `Custom` after a short delay (a positioned capture leaves it `Scriptable`).

## Special cases

| Case | What to do |
|---|---|
| **Spin-only weapon** (no keyed hinges) | Idle / Special come out empty. Author clips on the spun motors, **or** let the FX module spin them, not both: both write `Motor6D.Transform` and the last writer wins every frame. |
| **Static baked weapon** (one mesh) | Build a hand-made hinge (for example a spinning guard) so it still feels alive. |
| **Double-ended weapon** | Staff class: held at the centre of its grip parts, trail attachments on both ends, halves tagged for split moves. |
| **Own Blender model** (no setup script) | Use the parts-JSON builder route in [[Weapon Design Rig Builder]]. |
| **Higher rarities** | Always animated: jointed parts with clips, or a procedural FX rig driving pieces through weld C0. "Clips but no Motor6D" means nothing moves; treat it as a tier down. |

## The two traps that cost the most

1. **Studio-only clip ids.** Kit code that plays the weapon-part clips through `KeyframeSequenceProvider:RegisterKeyframeSequence` works perfectly in Studio and does nothing in live servers. In one project dozens of kits shipped like this from a template. Play weapon-part clips through the Lua rig player (a published `<Clip>Id` still wins when present). Full story: [[Case Study - Abilities That Only Worked in Studio]].
2. **Templates spread bugs.** Every kit built from a template inherits the template's mistakes. Grep all kits for the pattern whenever you fix one.

## Checklist

- [ ] Import by a human: Merge Meshes OFF, Rig none; found by name.
- [ ] Rig built: Handle root, one Motor6D per hinge, chain links welded, clips thinned, Animator present.
- [ ] FX module compiles and runs on the rig.
- [ ] Config, voice, sheath inserted through the safe-edit helper.
- [ ] Kit sources pass size, reserved-name, forbidden-id and order checks.
- [ ] Each move STAGED; kit installed; folder under 2,500.
- [ ] Registered; preview row written.
- [ ] Arm pass: zero criticals, model vs Animator under 3 deg.
- [ ] Verify: hold, hinges move, FX runs, registry clean.
- [ ] No `RegisterKeyframeSequence` anywhere in shipped code.
- [ ] Play-tested by a human.

## See also

[[Weapon Design Rig Builder]], [[Weapon Rig Player]], [[Custom Rigs - Weapons and Props]], [[Ability Kits Architecture]], [[Weapon and Combat Animation]], [[Equip Draw and Flourish Systems]], [[Pipeline - Arm IK Baking and QA]], [[Publishing Animations]]

## Connected notes
<!-- auto-links:start -->
[[Case Study - Building a Game with AI Agents]] · [[Asset Pipelines]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Modeling Weapons and Props]] · [[AI Agents and Autonomous Workflows]] · [[Pipeline Design Principles]] · [[Animation Start Here]]
<!-- auto-links:end -->
