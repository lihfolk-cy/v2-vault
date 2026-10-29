---
name: lihfolk-vfx
description: 'LihFolk VFX: slashes, impacts, projectiles, auras, AoE telegraphs, shields, beams, heals, teleports, level-up, camera shake, hit-stop. Use for "slash effect", "ability VFX".'
---

# LihFolk VFX: slashes, impacts and auras

An original combat-VFX kit: one Luau timeline module, tintable textures, small meshes and Blender previews.

| Preset | Look | Default element | Status |
|---|---|---|---|
| `SlashSweep` | heavy wide sweep across the front: two layered crescents, white-hot rim, teal body, wide dark ink, soft cross-faded erosion, debris thrown forward, dark ground pool. `SlashRing` is an alias | `teal` | **pass, median 10.0** (3 blind reviewers: 8.5, 10, 10) |
| `CrescentDouble` | two staggered crescents, white rim, saturated body, dark smear, square sparks | `violet` | passed 10.0 in wave 1; unit 2 is now clamped to the front (yaw -14 -> 0, drift 30 -> 10), not re-scored |
| `ThrustPierce` | forward stab: dark/element/white nested cones that shoot out and collapse from the base, two converging wind lines, shockwave rings down the stab line | `ice` | draft: first review 7.7, fixes applied, final review not run |
| `OverheadCleave` | vertical crescent from above the head into the floor ahead, glowing ground crack, shockwave ring, shards, dust, sparks | `fire` | draft, not reviewed |
| `DashTrail` | afterimage ghosts of the character, dark/element/white streaks along the path, backward speed lines, launch ring and dust | `lightning` | draft, not reviewed |
| `HitSpark` | impact on a target: dark impact frame, star flash, shock rings, a small cut mark, sparks and shards along the hit direction | `holy` | draft, not reviewed |
| `ChargeUp` | anticipation: motes and dark specks converge on a core glow, two ground rings implode, aura streaks rise, ready glint at release | `teal` | draft, not reviewed |
| `IceExplosion` | radial ice burst: small white-cyan flash, frosted shockwave ring, frost-crack decal, faceted crystal cluster in an icy mound that shatters into shards, low cold mist, glitter | `ice` | one-shot by request, not scored |

Elements: `teal`, `violet`, `fire`, `ice`, `lightning`, `void` (inverted: dark body, bright rim), `holy`. Every preset takes any element.

## Rules
- **Slashes play only in front of the character.** No 360 rings or spins. An arc stays within about +-100 deg of the LookVector
  (120 to 200 deg long), starting on the weapon side and ending across the front; debris and ground marks are biased forward.
  The module enforces it: every crescent unit is clamped to 90 +- 100 deg in its own plane and its drift may carry the head
  only 10 deg further (`FRONT_LIMIT`, `FRONT_DRIFT`). Explosions, auras and dashes may be radial or path-shaped.
  The rubric scores it as X6 "reads as a frontal attack".
- Three tones in every frame: white (rim, glints), element colour (body), dark (ink, debris, ground pool). Dark only reads
  over something bright or as a deep tint of the element, never as near-black on a dark floor.
- No weapon Trail across sweeps over ~120 deg or on stabs (`trail = false` presets, `NoTrailClips`): it draws a wedge or a
  streak behind the back. The arc or cone already shows the path.
- Erosion: cross-fade baked stages (`smoothErode`) with soft-edged textures (`strip_body_soft*`, `strip_ink_wide*`); flipbook
  cards with hairline erosion band a large arc (`cards = false`).
- Client only. One Heartbeat connection for every effect, disconnected when idle; each effect is a Model destroyed at its
  life end, Debris as a safety net, and a step error cleans up. Bursts use `ParticleEmitter:Emit()`; nothing stays enabled.
  Every part: Anchored, CanCollide/CanQuery/CanTouch false, CastShadow false.
- Recolour with `Elements` or `palette = {...}`; textures stay white/greyscale. Roles: main, hot, dark, glow, spark, debris, deep.

## General rules (any element, weapon or style; from blind reviews 2026-10-29)
Apply these to every new effect, not only the presets above. Detail: vault notes "VFX Readability and Value - Lessons from
Blind Reviews" and "Escalation and Grandeur Without Clutter".
- **Value:** saturated dark ink (blue-black thinning to blue, never grey = "muddy"), element body, white only as a thin
  core, at most one contrasting accent hue. White bits on a pale floor get a thin dark outline or tint.
- **No clutter:** never repeat an identical layer per beat; each repeat bigger, brighter, faster and different; later
  layers shorter; ground rings expand while fading (no stamps); sparks short, draggy, directional, in frame.
- **Smoke:** textured puffs, lighter tops, darker cores, rolling motion; never flat soft blobs.
- **Character stays clean:** large translucent layers spawn ahead of the body; rims, not washes; glow parts and effect
  lights off the character (lights above/behind, low power; one per effect).
- **Flash:** small (~0.6x body), 1-2 frames, 1 frame after contact, at the blade or crescent head ahead of the body.
- **Beams:** hairline streaks need low Brightness (bloom fattens them); ribbons read thicker with lower body brightness and
  a thin white core. Light shafts only as additive tapered textures (falloff along and across), radial from the source; else cut.
- **Dark elements (void):** near-black body, rim only at the silhouette (shell scale ~1.02, transparency ~0.45).
- **Direction:** release bursts biased forward, away from the caster's torso. Slashes frontal; only an explicit spin move
  may wrap round the body, and its finisher still goes forward.
- **Grandeur = escalate a FEW layers, cut or shrink others as you add.** Spin attack v2.1 added vortex + rune circle +
  smoke + rings and dropped 8.1 -> 7.7: spins 2-3 cluttered and buried the silhouette (particles were only ~150; the
  limit is the screen, not the 900 PC / 360 mobile caps). Re-check the character silhouette at game distance after every
  added layer. At most one growing element (vortex or sigil). The finisher is the clear payoff: one bigger, brighter forward
  arc than the spins, on the contact frame, blade high and edge leading. Smoke puffs vary in size/drift and fade fast.
- **Previews match the game:** fix the effect, never hide a flaw with a preview-only pass; emulate effect lights.
- **Scoring:** 3 blind reviewers, median per criterion, bar 8.5; one-shot requests are fine but still panel-scored if scored.

## Files

| Path | What |
|---|---|
| `src/LihFolkVFX.luau` | the module |
| `examples/SwordVFXClient.client.luau` | wiring for our sword clips |
| `src/LihFolkVFX_Abilities.luau` | ability presets beyond slashes (section "Ability VFX" below) |
| `examples/AbilityShowcase.client.luau` | cycles every ability preset on the local character (review harness) |
| `examples/AbilityVFXReplication.server.luau` / `.client.luau` | validate on the server, one payload to nearby clients, caster predicts |
| `<LihFolk Asset Pack>\VFX\Textures\*.png` (separate local pack, not in this repo) | textures (`_textures.json` lists role and use) |
| `...\VFX\Meshes\*.glb` | meshes (`_gate_report.json`): crescents (+ `crescent_single_thick_hd`), rings, `ground_ring`, `crystal`, `ice_mound`, `shard`, `petal` |
| `...\VFX\Previews\` | one MP4 + one frame strip per preset, mesh and texture contact sheets |
| `...\Dataset\vfx\` | review renders per preset (`rN_strip.png`, `review.json`), calibration anchors, wave-1 before/after |
| `...\VFX\_src\` | `build_textures.py`, `build_textures_wave2.py`, `build_meshes.py` (`-- --only name`), `vfxtex.py`, `preview.py`, `make_sheets.py` |

Vault note (path from this skill's base directory, resolve to absolute before reading): `<base directory>/../../LihFolk Vault V2/07 Lighting VFX and Audio/Slash VFX Recipes - Crescent and Ring.md`.

## Setup (once in Studio)
1. Upload `VFX/Textures/*.png` (skip `mask_*`). Fresh uploads can fail `PreloadAsync` for 20 to 60 s.
2. File > Import 3D each `VFX/Meshes/*.glb` with Merge Meshes off; copy each `MeshId` (drawn through `SpecialMesh`).
3. Paste ids into `LihFolkVFX.Textures` / `LihFolkVFX.Meshes`. Empty string = layer skipped with one warning. Never guess an id.
4. Require from a LocalScript in ReplicatedStorage; `LihFolkVFX.preload()` on equip.
5. Check once with a test swing: `Config.meshYawOffset`, `Config.cardRotation`, `beam_edge_h` vs `beam_edge_v` (see Studio checks).

## API

```lua
local VFX = require(ReplicatedStorage.LihFolkVFX)
VFX.play("SlashSweep", root.CFrame, { element = "fire", important = true })            -- returns stop()
VFX.play("CrescentDouble", root.CFrame, { arc = { 90, -60 }, tilt = -10 })              -- arc: start/end deg from LookVector (+ = right), clamped to the front
VFX.play("IceExplosion", root.CFrame * CFrame.new(0, 0, -6), { size = 1.3, element = "void" })
VFX.play("DashTrail", root.CFrame, { distance = 11, follow = root, character = char })
VFX.hitSpark(contactPos, attackerToTarget, { element = "holy" })
VFX.bindAnimator(animator, character, { trail = VFX.attachTrail(blade, a, b), important = true })
VFX.setQuality(0.6); VFX.clear()
```
Options: `element`, `palette`, `flip`, `tilt`, `yaw`, `arc`, `scale`/`size`, `important`, `skipUnits`, `follow`, `character`, `distance`, `speed`.
`cf` is the swing frame: position = swing centre (root part), XZ plane = swing plane, -Z = forward. `arc` picks where the
slash sits and which way it sweeps; its length is the mesh's (200 deg thick, 160 deg thin).

## Marker sync

| Marker (clip) | Plays |
|---|---|
| `Hit` "1", "2" (SwordLight1/2) | `CrescentDouble` (forehand, backhand) |
| `Hit` "3" (SwordLight3, stepping overhead) | `OverheadCleave` |
| `Hit` "heavy" (SwordHeavy) | `SlashSweep`; the clip's Trail is suppressed (`NoTrailClips`) |
| `Hit` "dash" (SwordDashSlash) | `CrescentDouble` scaled 1.3, 3 studs ahead |
| `Hit` "thrust" (a stab clip) | `ThrustPierce` |
| `DashStart` value "11.0" (SwordDashSlash) | `DashTrail`, distance from the value, head follows the root, ghosts of the character |
| `Impact` (GroundSlam) | `OverheadCleave` ground layers only; value "ice" (or any preset name) -> `IceExplosion` / that preset |
| `Deflect` (SwordParry) | `HitSpark` at the blade, scale 0.7 |
| clip start, `DefaultCharges` (SwordHeavy) or Animation attribute `VFXCharge` | `ChargeUp`, retimed so its release lands on `Hit` (`speed = lead_authored / lead_clip`); stopped if the track stops first |

Tables: `DefaultHits`, `DefaultMarkers`, `DefaultCharges`, `NoTrailClips` (override per binding with `hits`, `markers`, `charges`).
`TrailOn` clears and enables the Trail, `TrailOff`/`Stopped` disable it. Tracks with the Animation attribute `KitUpper` are skipped.
Sounds start skipped forward by their `peak` so the crack lands on the marker (`ChargeUp`'s riser has peak 0).

## Layer kinds (preset tables)
- `units`: crescent arcs (body mesh with reveal/erosion textures, ink mesh, rim mesh, glow/ink cards, edge Beam, head-spawned sparks/glints/debris).
- `bursts`: `Emit` at time `t` (or over `over` s) with `dir` none/cone/back/up/sphere/disc/converge and `orient` camera/vpar/flat/flatForward.
- `rings`: `ground_ring` SpecialMesh expanding (`ease` out) or imploding (`in`), flat or facing forward.
- `beams`: ribbons whose head grows (or follows the dash path) and whose tail chases it.
- `ghosts`: Neon copies of the character's visible parts, one per `interval`.
- `spikes`: crystal cluster (centre spike, main and small spikes, mound), staggered eruption with overshoot, hold, shatter into shard particles.
Positions are `{x, y, z}` in a space: `body`, `swing`, `ground` (floor studs below), `path` (dash head).

## Budgets (quality 1, per cast; touch devices start at 0.6, live cap 360, PC 900)

| Preset | Particles | SpecialMesh parts | Beams | Lights |
|---|---|---|---|---|
| SlashSweep | 51 | 9 | 4 | 1 |
| CrescentDouble | 54 | 5 | 4 | 1 |
| ThrustPierce | 27 | 3 | 5 | 1 |
| OverheadCleave | 49 | 6 | 2 | 1 |
| DashTrail | 28 | 1 + 4 ghosts x up to 24 parts | 4 | 1 |
| HitSpark | 33 | 0 | 0 | 1 |
| ChargeUp | 69 | 2 | 0 | 1 |
| IceExplosion | 54 | 12 | 0 | 1 |

Above 75 % of the live cap or beyond 160 studs counts halve and decoration (glints, mist, ink cards, small spikes, ghosts)
drops; beyond 220 studs nothing plays; at most 8 effects (`important` casts bypass).

## Previews and QA
`blender -b --factory-startup --python VFX/_src/preview.py -- --preset SlashSweep --name SlashSweep_teal`
reads the presets and elements from the Luau file and replays the same timeline (60 Hz ticks, Emit, cross-fades, beams,
ghosts, spikes). Roblox Color3 is sRGB: the emulator linearises every tint (`lin()`). Bloom, Neon, sorting, ZOffset,
Squash, card Rotation sign and SpecialMesh lighting are approximations. Score with `quality-score/rubrics/vfx.md` (X1-X6).

## Studio checks still needed
- SpecialMesh centres a FileMesh on its bounding box: crescent arcs (bbox not centred on the arc's circle) may sit off the
  swing centre; spikes assume centring. Check one swing per mesh; fix with `meshYawOffset` or an offset if needed.
- Neon + SpecialMesh `TextureId`: confirm the strip textures show on Neon bodies (else SmoothPlastic + VertexColor gain).
- Crystal spikes use SmoothPlastic + VertexColor 1.35: check they read in dark zones.
- Ghost cloning: parts with `Archivable = false` are skipped; check accessories and layered clothing.
- `ChargeUp` retiming on SwordHeavy, `DashStart` follow distance against walls, `Impact` value routing.
- Phone at game distance, darkest and brightest zones.

## Ability VFX (LihFolkVFX_Abilities)

Standalone module (`src/LihFolkVFX_Abilities.luau`, UNTESTED IN STUDIO) for everything that is not a slash: radial, path and
attached effects, which the frontal rule allows. Same conventions as the slash module: one Heartbeat loop, Emit bursts,
quality scaling, live cap 900 PC / 360 touch (`Config.externalLive` lets several modules share one cap), cull 220 studs,
low detail 160 studs, at most one light per effect (no shadows), Debris safety net, client only.
Vault: "Projectile VFX - Muzzle, Travel and Impact", "AoE Telegraphs - Readable Ground Warnings",
"Auras, Shields and Status Effects", "Replicating VFX - Server Validates, Clients Render", "Hit-Stop and Screen Shake Tuning by Numbers".

| Call | Does | Handle |
|---|---|---|
| `Projectile(fromCF, target?, opts)` | muzzle flash + forward sparks, Neon core (hot centre, or a ForceField rim for void), tapered Trail, element + dark wake, homing (`homing` deg/s), `gravity`, wall raycast, impact flash 1 frame late, sparks, chips, surface rings, light pulse. `target` = Vector3, BasePart, Attachment or nil (`direction`) | `:Impact(pos?, normal?)`, `:Destroy()` |
| `Aura(character, opts)` | rising motes + dark specks from a feet Attachment, Highlight outline rim (no fill), breathing foot ring over a dark ring, 2 orbiting Trail wisps; sleeps beyond 160 studs | `:SetIntensity(0..1)`, `:Destroy()` |
| `Telegraph(cf, "circle"/"cone"/"line", opts)` | raycast to floor and slope; dark outline, base fill, progress fill with hot leading edge, bright rim; fills over `duration`, pops; `important` by default | `:Cancel()`, `:Destroy()` |
| `Shield(characterOrPart, opts)` | ForceField sphere + Highlight rim, grow-in overshoot, surface glints, ripple ring on the tangent plane + sparks per hit, break burst (shards, ring, light) | `:Hit(worldPos)`, `:Break()`, `:Destroy()` |
| `BeamLaser(fromAtt, to, opts)` | charge (converging motes, growing orb), dark edge + body + white core Beams with width wobble and texture scroll, wall clip, impact glow + spark stream + light at the end every frame, end burst | `:SetTarget(posOrAtt)`, `:Stop()`, `:Destroy()` |
| `Heal(character, opts)` / `Buff(...)` | rising motes; Heal: expanding ring + faint disc + gold glints; Buff: imploding ring, pop ring, upward streaks | `:Destroy()` |
| `Teleport(fromCF, toCF, opts)` | source: imploding ring, converging motes, collapsing column; destination after `delay`: flash, column burst, bright + dark rings, sparks, dust | `:Destroy()` |
| `LevelUp(character, opts)` | two escalating foot rings, scan ring rising round the body, light pillar above the head, sparkle fountain, confetti, motes, light above | `:Destroy()` |
| `CameraShake(intensity, duration, {position, near, far})` | local camera, trauma squared noise, smoothstep falloff 30 to 150 studs, off under `Config.reducedMotion`, scaled by `Config.shakeScale` | none |
| `HitStop(trackOrListOrAnimator, duration, {speed, catchUp})` | `AdjustSpeed(0)` then restore the speed from before the first overlapping stop; `catchUp` replays the lost time; capped at 0.2 s; off under reduced motion | none |
| `playPayload(caster, presetId, cf, elementIndex, seed, aux?)` | replays a server broadcast (`PresetIds`, `ElementIds`, `PayloadDefaults`, `CastRules`) | the preset's handle |

Common options: `element` (teal, violet, fire, ice, lightning, void, holy, plasma, heal), `palette`, `scale`, `important`, `seed`, `quality`.
Culled calls return a handle whose methods do nothing, so callers never need nil checks.

### Budgets (quality 1; touch 0.6)

| Preset | Particles counted | Beams / Trails | Adornments / Neon parts | Highlights | Lights |
|---|---|---|---|---|---|
| Projectile | 9 muzzle + ~19 wake alive + 25 impact | 0 / 1 | 2 / 2 | 0 | 1 (travels, pulses at impact) |
| Aura | ~15 alive | 0 / 2 | 2 / 0 | 1 | 0 (opt-in 1, above and behind) |
| Telegraph | 0 | 0 / 0 | 5 circle, 7 cone or line / 0 | 0 | 0 |
| Shield | ~3 alive, 10 per hit, 34 at break | 0 / 0 | up to 4 ripples + 1 / 0 (ForceField shell) | 1 | 1 at break only |
| BeamLaser | 15 charge + ~9 alive + 16 end | 3 (2 below quality 0.55) / 0 | 0 / 2 | 0 | 1 at the endpoint |
| Heal / Buff | 39 / 48 | 0 / 0 | 2 / 0 | 0 | 0 |
| Teleport | 49 (dust 6 needs `smoke_puff`) | 0 / 0 | 3 / 2 | 0 | 1 at the destination |
| LevelUp | 76 | 0 / 0 | 3 / 2 | 0 | 1 above the head |

### Built-in looks with empty Textures
`glow_soft`, `flash_hot`, `spark_streak`, `spark_square` fall back to the engine's default particle sprite (one warning each);
`trail_soft`, `beam_core`, `beam_outer` draw solid gradient ribbons; rings, discs and sectors are HandleAdornments, cores and
columns Neon parts, the shield a ForceField ball, rims Highlights: none of them needs an upload. Skipped until you upload
your own: `smoke_puff` (teleport dust) and `scorch_mark` (projectile ground mark).

### Replication pattern
1. Client presses a key: plays the preset at once (`important = true`) and fires `AbilityCast(presetId, aim)`. It sends
   no colour, size or CFrame for the server to trust; it mirrors `CastRules` so it predicts only accepted casts.
2. Server: type checks, preset in `CastRules`, finite aim, alive, range clamp, per-preset cooldown + token bucket
   (6 burst, 3/s), then gameplay (hits, damage) and ONE `AbilityVFX` payload
   `(caster, presetId, cf, elementIndex, seed, aux)` to each player within 250 studs, skipping the caster.
3. Other clients: `playPayload` (seeded variation); the caster ignores echoes of its own client-castable presets.
   Server-originated presets (boss telegraphs, LevelUp) go to everyone, caster included.
Persistent states (aura on, shield up) replicate as attributes on the character, and each client starts or stops its own
`Aura`/`Shield` from `GetAttributeChangedSignal`; events carry only one-shots.

### Studio checks still needed (abilities)
- Telegraph cones: `CylinderHandleAdornment.Angle` start direction; set `Config.coneSectorOffset` once if the cone is rotated.
- HandleAdornments on slopes and in dark/bright zones at game distance; ForceField shell colour per element.
- Highlight rims when the character already has a Highlight (one per object; see "Highlights and Selection Effects").
- CameraShake with custom camera scripts (bound at `RenderPriority.Camera + 1`); HitStop with clips that set their own speed.
