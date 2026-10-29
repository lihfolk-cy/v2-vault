# World numbers and budgets

Every number keeps the label its vault note gives it. **Docs** = Roblox documentation (as of October 2026).
**Measured** = measured in the vault's one reference project (characters there were scaled to ~9 studs, so its
distances run large). **RoT** = rule of thumb: a starting point to test, not a limit. **Computed** = worked
from docs values. Note titles are in `LihFolk Vault V2/` (search with `_tools/vault.py`).

## Scale and movement (default R15)

| Value | Number | Label | Note |
|---|---|---|---|
| Avatar height / eye height | ~5 studs / ~5 studs above floor | Docs defaults | Level Design for Roblox; Level Design Principles |
| WalkSpeed | 16 studs/s (100 studs = 6 s) | Docs | Level Design for Roblox |
| Jump | JumpHeight 7.2 (JumpPower 50 only with CharacterUseJumpPower); flat jump travel ~8.7 studs | Docs / Computed | Obby and Platforming Level Design |
| Auto-climbed step | 1 stud | Docs | Level Design for Roblox |
| Camera FOV | 70 deg vertical; horizontal ~102 deg at 16:9, ~113 deg on a 19.5:9 phone | Docs / Computed | Level Design Principles |
| Max camera zoom | 400 studs | Docs | Level Design for Roblox |

## Layout

| Thing | Number | Label | Note |
|---|---|---|---|
| Main zone path | 20-34 studs wide | Measured | Level Design for Roblox |
| Door opening | 3.6-4 wide x 7.5-8 tall | Measured | House Construction Method |
| Storey (floor to eave) | 10-12 studs; interiors 2-3 avatar heights or the camera clips | Measured | House Construction Method |
| Window | 1.8-2.8 x 3-3.8, sill 3-4 up; reads from 40 studs | Measured | House Construction Method |
| Step rise (house) | 0.3-0.5 | Measured | House Construction Method |
| Compression space | under 5 s of walking, ceiling >= 3 character heights | RoT | Level Design Principles |
| Spawn area | 12-20 studs across per simultaneous spawn; no ceiling under ~3 character heights | RoT | Spawn Points Safe Zones and Respawn Flow |
| Hub plaza | radius ~40-70 studs (feels busy at ~5 players) | RoT | Lobby and Hub Design |
| Hub timing | first station or exit < 15 s (240 studs); station to station < 10 s | RoT | Lobby and Hub Design |
| Station clearance | 46-stud keep-clear radius; approach cone +-30 deg out to 30 studs | Measured / RoT | Lobby and Hub Design; Foliage Props and Scatter |
| ProximityPrompt | default MaxActivationDistance 10 (unconfirmed); prompts 20+ studs apart; on the object at chest height | RoT / Docs | Lobby and Hub Design |
| Encounter spacing | every 150-300 studs (a fight every 10-20 s) | RoT | Combat Arena and Encounter Layout |
| Arena clear height | >= 30 studs; cover 2.5-3.5 low, 7+ full, avoid 4-6 | RoT | Combat Arena and Encounter Layout |
| Obby landings | easy 8+ studs square; every stage starts/ends on 8x8 | RoT | Obby and Platforming Level Design |
| Critical path | ~80% of first-time players find it without UI | RoT | Level Design Principles |

## Landmarks and readability

| Thing | Number | Label | Note |
|---|---|---|---|
| Landmark angular size | >= 3-5 deg of view where players need it; < ~2 deg is a speck on a phone | RoT | Level Design Principles |
| Example | 50 studs tall at 500 studs = 5.7 deg; 100 at 2000 = 2.9 deg | Computed | Level Design Principles |
| Hero landmark | >= 1.5x taller than anything else in the zone, brightest or most saturated thing in view | RoT | Zone and Biome Art Direction |
| Keep landmarks streamed | within ~1000 studs, or the model `Persistent` | Docs-based | Level Design Principles |
| Silhouettes | read at 30-40 px; at night at 50 studs | RoT | Environment Art Styles; Lighting Mood and Time of Day |
| Gameplay object vs background | contrast ratio >= 3 | RoT | Stylized Lighting Recipes |
| Colour-blind distance (Oklab) | large patches 0.08, small signals 0.15, critical 0.20 + a non-colour cue | RoT | Colour-Blind Safe Design |
| Greyscale test | ColorCorrection Saturation = -1 | RoT | Colour-Blind Safe Design |
| Glow coverage | ~1-16% of the frame; above ~16% shapes dissolve in bloom | Measured | Environment Art Styles |
| Darkest textured surface | >= ~0.06 luminance | Measured | Environment Art Styles |

## Performance

No scene budget is published by Roblox. Measure on a real phone (15-minute soak; thermals show after 5-10 min, RoT).

| Budget | Mobile | PC | Label | Note |
|---|---|---|---|---|
| Visible triangles | 300k-600k | 1M+ | RoT | Art Budgets - Triangles Draw Calls Memory |
| Per mesh (hard limit) | 20,000 | 20,000 | Docs | Art Budgets |
| Hero prop / repeated prop / tree / landmark | 5-10k / 200-2k / 1-5k / 6-12k + LOD | same | RoT | Art Budgets |
| Instances: hub / dressed zone / one prop | 2k-10k / 3k-10k / < 50 | same, leave 20-30% headroom for VFX and UI | RoT | Art Budgets |
| Local lights on screen | 8-12, 2-3 shadowed | more; still shadow only key lights | RoT | Light Sources and Shadows |
| Light Range cap | 120 studs (brightness does not add range) | | Docs | Light Sources and Shadows |
| Shadows | none below graphics quality 4: colour and value must carry the look | | Docs | Rendering Performance |
| Textures | <= 512, minor <= 256; 1024 = 4x the memory of 512 | | Docs | Textures Decals and Texture Memory |
| Particles alive (weather tiers) | Low 300 / Medium 1000 | High 2500 | RoT | Weather Performance Budgets and Quality Tiers |
| Client memory | low phone well under 1 GB; mid 1-1.5 GB | | RoT | Memory Budgets and Leaks |

`LihFolkWorld.budgetReport` warns above these per-folder numbers (RoT, tune per project): mobile 10k instances,
12 lights, 3 shadowed, 40 emitters; PC 20k, 24, 8, 80.

### Instancing and draw calls (Docs, Art Budgets)
- Identical MeshParts batch when they share mesh + SurfaceAppearance/material. Clone in Studio; re-importing
  creates new mesh ids and breaks batching. Decals, Textures and particles batch poorly (30 decals = 30 draws).
- 3-5 base meshes per prop type, varied by transform (scale, yaw), beat many unique meshes (RoT).

### Streaming and LOD (Docs, Level of Detail and Model Streaming)
- `StreamingEnabled` on; defaults `StreamingMinRadius` 64, `StreamingTargetRadius` 1024.
- Recommended: `StreamOutBehavior` Opportunistic, `ModelStreamingBehavior` Improved,
  `StreamingIntegrityMode` PauseOutsideLoadedArea.
- `Model.ModelStreamingMode`: Atomic for props that must arrive whole, Persistent for far landmarks (sparingly).
- `Model.LevelOfDetail` StreamingMesh shows an imposter for far models. `MeshPart.RenderFidelity` Automatic
  (Highest < 250 studs, Medium 250-500, Lowest beyond); many Precise meshes are a known cost.
- Terrain at least 16 voxels thick where streaming radii are small (Docs).

### Collision and decor (Docs, Collision and Physics Geometry)
- Decor: Anchored, `CanCollide`, `CanTouch` and `CanQuery` off (CanQuery can only be off when CanCollide is off).
- `CollisionFidelity` Box for small anchored props, Hull for medium; PreciseConvexDecomposition is the most expensive.
  It cannot be changed on a loaded MeshPart from a script: set it in Studio.
- `CastShadow = false` on small, distant, Neon and litter parts (Measured convention).
- Collision only on trunks and large rocks; low-end clients may drop filler scatter (RoT, Foliage Props and Scatter).

### Scatter (Foliage Props and Scatter)
- Poisson disk (Bridson): candidates between spacing and 2x spacing, grid cell spacing/sqrt(2), 30 attempts.
- Long-tail scale `0.7 + 2.3 * r^3` for a few giants (Measured, forest); crown yaw 14-22 deg, tilt up to 4 deg.
- Grass and flowers sunk ~0.15 studs; placed only where the ground is grass. Always seed the scatter.
- A zone kit of 50-90 models covers a realm (Measured: 617 placements from 87 models).

### Terrain (Terrain Tools and Terrain API; Terrain Materials and Painting)
- 4-stud voxels. 3-5 terrain materials per view (RoT). Material colours are global: change material per zone.
- Brick and WoodPlanks off slopes (render as 4-stud cubes). Terrain water only where players swim.
- Paths lighter and smoother, play space mid and calm, edges darker or busier, hazards high contrast,
  landmark the one unusual material (RoT). No straight paint edge longer than ~20 studs.
