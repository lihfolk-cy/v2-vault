---
name: lihfolk-worldbuilding
description: 'LihFolk: build Roblox maps, levels, biomes, towns, dungeons, lobbies, obby areas and terrain that read as designed. Use for "build a map", "make the map look better", "map feels empty/cluttered", floating props.'
---

# LihFolk Worldbuilding: places that read as designed

Goal: a world that has a clear path, one focal point per view, a cohesive look and a budget a phone can run, and
scores at least 8.5 on the `quality-score` world rubric. Order beats detail: layout and primary forms decide the score;
props only finish it.

Not this skill: modelling a single prop or building (`roblox-blender-modeling`), effects (`lihfolk-vfx`), sounds
(`lihfolk-sfx`), finding assets (`lihfolk-assets`), gameplay systems (`lihfolk-systems`). This skill calls them.

Files: `src/LihFolkWorld.luau` (placement and audit toolkit), `examples/VillageSquare.luau` (two-pass village square),
`references/world-brief-template.md`, `references/budgets.md` (every number with its source label). Vault note:
`<base directory>/../../LihFolk Vault V2/06 World Building and Art/World Composition and Set Dressing - Designed, Not Scattered.md`
(resolve to absolute before reading). Search more with `py "<vault>/_tools/vault.py" "<query>"`.

## 0. Rules
- Original assets only: the LihFolk Asset Pack, models made with `roblox-blender-modeling`, or parts built here. No
  scraped, Toolbox or third-party packs. Never invent asset ids: leave `rbxassetid://REPLACE_ME` and list uploads.
- Inspect before building, verify after every pass. Never guess a coordinate you can measure.
- Every number below is a starting point with a label in `budgets.md`; measured project numbers beat them.

## 1. Brief and world pillars (before placing anything)
Fill `references/world-brief-template.md`: fantasy, play pattern, target device, scale vs R15, one style family, one
mood preset, palette of 3-5 base colours plus 1-2 accents, the hero landmark, districts, paths, a "not this" list,
2-3 story moments, the budget. Then do the quality-score pre-flight (recipes and ledger, 3-6 line plan).

Palette discipline: each zone has one dominant hue plus neutrals and one accent no other zone uses; saturation goes on
the hero, interactables and rewards, never on the ground; pickups use one game-wide colour. Sample colours under the
game's lighting, not in a picker.

## 2. Inspect the place (Studio MCP when connected)
- `mcp__Roblox_Studio__get_studio_state`, `search_game_tree` and `inspect_instance`: existing folders, Terrain,
  Lighting, Atmosphere, Sky, spawn, scale of the avatar (custom rigs change every distance), StreamingEnabled.
- `execute_luau` with `LihFolkWorld.budgetReport(workspace.<Map>)` and `auditWorld` to get a baseline.
- `screen_capture` from the spawn before changing anything.
Without MCP, ask for these facts or write the same checks as a command-bar script for the user to run.

## 3. Build macro to micro (one folder per pass: `01_Layout`, `02_Primary`, `03_Medium`, `04_Detail`)
1. **Layout / blockout** in grey parts: ground, paths, gameplay spaces, spawn, hero stand-in, district blocks.
   - Main path 20-34 studs wide (measured), side lanes narrower; paths lighter and smoother than the play space.
   - Spawn faces the hero; spawn area 12-20 studs per simultaneous spawn; hub plaza radius ~40-70.
   - Hero: >= 1.5x taller than anything else, >= 3-5 deg of view where players need it (50 studs tall reads
     at ~500 studs); visible from the spawn and every gate; within ~1000 studs or `Persistent`.
   - Time the walk at 16 studs/s: hub first station < 15 s, station to station < 10 s, encounters every 150-300 studs.
   - Compression then release before a reveal (tight space < 5 s, ceiling >= 3 character heights).
   - Door 3.6-4 x 7.5-8; storey 10-12; interiors 2-3 avatar heights tall; clear arena height >= 30.
   - Tag walkable ground `LF_Ground` and paths, plazas, door fronts and prompt approaches `LF_NoScatter`.
   **Gate:** walk spawn to goal (`character_navigation` or play mode); the route is obvious with no UI.
2. **Primary forms**: buildings (via `roblox-blender-modeling` and `scripts/lihfolk_house.py`, kit pieces on a
   2-stud grid), cliffs, big trees, the real hero. Place with `placeOnGround`; buildings on flat pads, never tilted.
3. **Composition pass** from the player camera at close (~10 studs), mid (~50) and far (spawn and max zoom), in
   16:9 and phone aspect. Move masses, not props. Check:
   - focal hierarchy: one hero, 2-4 primary forms framing it, secondary story groups, quiet tertiary detail;
   - leading lines (paths, fences, lantern rows, roof lines) point at the hero or the next goal;
   - height variation in steps; skyline broken by the hero; edges (cliffs, walls, water) contain the space;
   - negative space on paths, plazas, door fronts and around interactables;
   - three reads: silhouette, colour (blurred), light (props hidden); at least two work.
4. **Medium props** in story groups of odd numbers (one big, two mid, a few small), placed on the path or at nodes.
   Made things align to walls and paths (90-deg steps plus a few degrees, `faceToward` for use direction); natural
   things vary. Each group answers "what happened here?" (a cold fire, one bedroll, an unfinished note).
5. **Small detail** last, with `scatter`: clumps (`clusters`) not sprinkle, denser at edges and seams, long-tail scale,
   `alignToNormal` and `sink` 0.1-0.3 for plants and rocks, `materials` to keep flowers on grass. Always seed.

Prop density guide (rule of thumb): play spaces mostly clear; path edges one story group per node or bend; edges and
corners densest; ground cover hides seams and tiling, not the floor. A dressed zone stays within 3k-10k instances.

## 4. Look: lighting, materials, terrain
- **Lighting presets** (Stylized Lighting Recipes; set `Lighting.LightingStyle` and `PrioritizeLightingQuality`,
  `Technology` is deprecated). Atmosphere is the fog (Fog properties are ignored while one exists).

| Mood | ClockTime | Brightness | Ambient / OutdoorAmbient | Atmosphere Density / Offset / Haze | Grade |
|---|---|---|---|---|---|
| Bright cartoon (hub, sim) | 13.5 | 2.5 | 110,110,125 / 150,150,160 | 0.25 / 0.1 / 0.5 | Contrast 0.08, Sat 0.15, Bloom 0.5 |
| Golden hour | 17.6 | 2.2 | 90,70,70 / 130,100,90 | 0.35 / 0.2 / 1.5 | Contrast 0.1, Sat 0.1, SunRays 0.06 |
| Readable night | 0 | 0.6 | 60,70,110 / 80,95,140 | 0.3 / 0 / 0.5 | Contrast 0.1, Sat -0.1, Exposure 0.2 |
| Fog horror | 20.5 | 0.5 | 35,35,40 / 55,55,60 | 0.55 / 0 / 2.5 | Contrast 0.05, Sat -0.45 |
| Neon city | 22 | 0.4 | 40,30,60 / 60,45,90 | 0.4 / 0 / 2 | Contrast 0.15, Sat 0.2, Bloom 1.2 |

  Ambient <= OutdoorAmbient per channel; night is tinted, never black. Phones below quality 4 have no shadows, so
  value and colour carry the look: run a no-shadow check. Real lights only at focal points (8-12 local, 2-3 shadowed
  on mobile); glow elsewhere is Neon or colour. Full presets and zone blends: `07 Lighting VFX and Audio/Stylized
  Lighting Recipes.md`, `Lighting Mood and Time of Day.md`, `Atmosphere Sky Clouds and Post-Processing.md`.
- **Materials:** one style family; 15-30 MaterialVariants for the whole game, named `<Base><Surface><Variant>`
  (`SlateCliffMossy`), overrides planned up front because they are global. Break tiling at three scales (Organic
  pattern, per-part colour and rotation shifts, edge decals and props). Background props colour only.
- **Terrain** for hills, caves, cliffs and shorelines; parts or meshes for flat stylised floors. 3-5 terrain
  materials per view, a different material per zone (colours are global), no Brick/WoodPlanks on slopes, terrain
  water only where players swim. Snapshot (`CopyRegion`) before edits; wobble paint edges (none straight > ~20 studs).

## 5. Performance and streaming
- Static scenery `Anchored`; decor `CanCollide`, `CanTouch`, `CanQuery` off; `CastShadow` off on small, distant and
  Neon parts; `CollisionFidelity` Box for small props, Hull for medium (set in Studio).
- Reuse 3-5 base meshes per prop type and vary transforms; clone in Studio so meshes batch.
- `StreamingEnabled` with Opportunistic stream-out, Improved model streaming, PauseOutsideLoadedArea; Atomic for
  props that must arrive whole, `LevelOfDetail` StreamingMesh for far models, Persistent only for far landmarks.
- Budgets: phone 300k-600k visible triangles, PC 1M+, 20k per mesh; leave 20-30% headroom for VFX and UI
  (`references/budgets.md`). Run `budgetReport(root, "mobile")` after each pass.

## 6. Accessibility and readability
Path and interactables separate from the ground in greyscale (ColorCorrection Saturation -1); gameplay objects keep a
contrast ratio >= 3 with their background; danger is shown by shape and edge as well as colour; signs are 3-8 words
built into the art; landmarks, light and openings guide before text does.

## 7. Verify (mirrors the world rubric)
Run in Studio (`execute_luau`), then look (`screen_capture`) and walk (`character_navigation` / play mode):
- [ ] `auditWorld(root)`: 0 floating, 0 buried, 0 unintended overlaps; pivots at bottom centre, fronts facing use
      (exceptions carry `LF_AllowFloat`, `LF_AllowBury`, `LF_AllowOverlap` and are deliberate)
- [ ] main path walkable spawn to goal with no invisible blockers or steps over 1 stud; spawn safe
- [ ] `budgetReport(root, "mobile")`: no warnings, or each one justified; static parts anchored; decor non-colliding
- [ ] scale against an R15 dummy at doors, stairs, props and the hero
- [ ] composition from the spawn, the main path and an overview shot, at close, mid and far distance and phone aspect:
      one clear focal point, readable path, landmarks visible
- [ ] no clutter: paths and interactables clear, story groups instead of sprinkle, one style and palette
- [ ] lighting tuned to the brief's mood; greyscale and no-shadow checks pass

Score with `quality-score` (`rubrics/world.md`): evidence = spawn, path and overview captures plus the audit and
budget output. Three blind reviewers for the pass decision, median per criterion, bar 8.5; fix the lowest
high-weight criterion first (W1 composition, W2 navigation weigh 3), max 3 rounds, log to the ledger.

## 8. Toolkit (`src/LihFolkWorld.luau`, edit time only)
Put it in ServerStorage as a ModuleScript (or paste it into one `execute_luau` call) and require it.
| Function | Use |
|---|---|
| `placeOnGround(inst, x, z, {yaw, alignToNormal, maxTilt, maxSlope, sink, ignore})` | footprint centre on the ground; corners never float; tilt only for natural props |
| `isAreaClear(cframe, size, ignore)` | true when no prop is in the box (ground and Terrain ignored) |
| `scatter(regionPart, {templates, spacing, seed, clusters, scaleMin/Max, scaleCurve, materials, ...})` | Poisson-disk dressing, keep-outs from `LF_NoScatter`, grounded and clear-checked |
| `faceToward(inst, target, frontYaw?)` | yaw the front (-Z) at a point or model |
| `budgetReport(root, "mobile"/"pc")` | counts and warnings: instances, meshes, lights, shadows, emitters, unanchored, colliding decor |
| `auditWorld(root, opts)` | floating, buried, overlapping and pivot issues, printed and returned |

## 9. Other skills
`lihfolk-assets` for kit props, MaterialVariants and skies from the LihFolk Asset Pack (shippable rows only);
`roblox-blender-modeling` with `lihfolk_house.py` for houses and buildings (2-stud kit grid, bottom-centre origins);
`lihfolk-vfx` conventions for ambient effects (client-only, budgeted, at focal points, asleep when far);
`lihfolk-sfx` for licensed sounds, layered per district (vault: Ambient Soundscapes - Layer Stacks, Overlapping Zones
and Voice Pools); `roblox-performance-audit` for a deeper frame-time check;
`quality-score` to score.
