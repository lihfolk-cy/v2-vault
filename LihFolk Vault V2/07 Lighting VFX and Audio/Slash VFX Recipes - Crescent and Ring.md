---
tags: [vfx, slash, crescent, sweep, thrust, cleave, dash, afterimage, impact, charge, ice, explosion, beams, particles, flipbooks, meshes, timing, markers, recipes, type/guide]
---
# Slash VFX Recipes - Crescent and Ring

<!-- tldr:start -->
> [!tldr] TL;DR
> - The ring reads as a flat glowing plate: Hold with no motion; extra concentric ground rings -> Keep it drifting (about 110 deg over the erode); one faint ground...
> - Dark smear invisible: The smear sits inside the body's inner edge or under the body, so... -> Overlap it with the body's inner half (scale about 1.0) and draw...
> - Hot edge disappears after the sweep: The edge ribbon sits below a mesh with a raised outer lip -> Lift the ribbon onto the lip (about 0.15 x radius for a dished ring)
> - Slash arcs stay in front (+-100 deg of the LookVector); no rings or spins
> - Three tones present in every frame: white edge, element body, dark smear
> - Sweep 3 to 5 frames, hold 1 to 2, erode 10 to 15 (at 30 fps)
>
> Cost: TL;DR ~220 tok · whole note ~4.4k tok. Read more: ## 1. The layer recipe · ## 5. Wave 2 presets (same layer approach) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A stylised sword slash is not one shape. It is a short stack of layers that each do one job: a bright rim that says *where the blade went*, a coloured body that says *what element this is*, a dark smear that gives the bright parts something to stand against, and small debris that says *how hard it hit*. This note gives the layer recipe with numbers for two slash looks (a crescent and a full spin ring), how to build them in Roblox, and what went wrong while building the LihFolk versions. The implementation is the `lihfolk-vfx` skill (`skills/lihfolk-vfx/src/LihFolkVFX.luau`); textures, meshes and previews are in the LihFolk Asset Pack under `VFX/`.

Source labels: **Measured** (LihFolk build and its blind reviews, October 2026), **Docs** (Roblox reference), **Rule of thumb**.

---

## 0. The frontal rule

A slash plays **only in front of the character**. Keep every arc inside about +-100 deg of the LookVector (120 to 200 deg
long), starting on the weapon side and ending across the front; bias debris and ground marks forward. A full ring around the
caster reads as an aura, hides the character and seems to hit behind the back, which players read as a wrong hitbox. The
wave-1 350 deg `SlashRing` reached a 10.0 median after its fixes and was still retired for this reason; the heavy is now
`SlashSweep` (two layered crescents across the front). The LihFolk module clamps every arc to the front, and the VFX rubric
scores it as X6 "reads as a frontal attack". Explosions, auras and dashes may be radial or path-shaped.

The one exception is a move that is **explicitly a spin** (the character turns 360 deg or more, such as a whirlwind or a
3-spin attack): there the effect follows the blade around the body. Even then, make each turn's layer distinct and
escalating rather than stacking identical rings, keep large layers off the body, and send the finisher forward
([[Escalation and Grandeur Without Clutter]], [[Spin and Whole-Body Rotation Moves]]).

## 1. The layer recipe

Seven layers, listed from most to least important. Drop from the bottom when a phone or a crowded fight needs a cheaper version.

| # | Layer | Job | Build | Key numbers (Measured) |
|---|---|---|---|---|
| 1 | **Crescent body** | the shape that reads | mesh arc (thick middle, tapered tips) with a strip texture, or a flat flipbook card | outer radius 6.5 to 8 studs (character scale 1), span 200 deg for a crescent and 350 deg for a ring; thickness profile `sin(pi * u^1.36)^0.7`, so it peaks just past the middle toward the head |
| 2 | **Hot leading edge** | where the blade is now | additive ribbon riding the head of the arc | white to element colour along its length; 90 to 100 deg long; width 1.1 to 2 studs, shrinking to 0 over 0.34 to 0.45 s |
| 3 | **Brush erosion** | how the shape dies | swap 5 pre-baked erosion textures (or flipbook frames) | erosion order: the tail first, the inner side before the rim, along the brush strokes; front-loaded schedule (`stage = floor(5 * sqrt(x))`) |
| 4 | **Dark contrast smear** | gives the bright layers an edge | ink-tinted copy of the arc over the body's inner half, lagging behind the head | colour about 10 % of the element value; 0.12 transparency; 18 to 20 deg behind the body; three erosion stages of its own |
| 5 | **Glow** | soft light around the shape | additive flipbook card in the swing plane | brightness 1.0 to 1.2, transparency 0.45 to 0.7 |
| 6 | **Debris, sparks and glints** | impact and direction | `Emit` bursts from the moving head, aimed along the swing (tangent plus 35 to 55 % outward) | sparks 16 (speed 34 to 58, drag 6, life 0.2 to 0.38 s); petals 24 (speed 30 to 62, drag 3.2, gravity -14, life 0.55 to 0.95 s); glints 3 to 6; square sparks 13 per crescent, floating up |
| 7 | **Ground** | anchors the effect to the floor | flat disc or ring card under the swing | faint: transparency 0.65 to 0.8, life 0.45 to 0.5 s |

### Value hierarchy

Read every frame as three tones: **white** (the edge and glints), **element colour** (the body and glow), **dark** (the ink smear and debris). If any one of the three is missing, the effect flattens. The two reference looks the recipe was built from had the same structure. The teal ring had a white edge, teal body, near-black ink inside and black petals. The violet crescent had a white rim, saturated violet and deep violet smear.

### Timing (frames at 30 fps, after the Hit marker)

| Phase | Frames | Seconds | What happens |
|---|---|---|---|
| Flash | 0 to 2 | 0 to 0.07 | star flash, size 0 to 6-7 to 40 % |
| Sweep-in | 3 to 4 | 0.11 to 0.13 | the arc grows from its tail to the blade, quad or cubic ease-out (exponent 2.2) |
| Hold | 1 to 2 | 0.03 to 0.05 | full shape; keep it moving (drift), never a frozen plate |
| Erode | 10 to 12 | 0.34 to 0.40 | brush break-up, then fade over the last 60 % |
| Linger | to frame 33 to 39 | to 1.1 to 1.3 s | debris and sparks fall and fade |

The sweep is drawn by turning the arc about its centre while a mask reveals it. The mesh yaws from `-span * (1 - r)` to 0 while the reveal fraction `r` rises, so the tail end stays put and the head travels with the blade. Then it keeps drifting on (110 deg for a spin ring, 30 deg for a crescent) through the erode, decelerating.

---

## 2. Textures (all white or greyscale with alpha, tinted in Roblox)

| Texture | Size | Purpose |
|---|---|---|
| Arc strips (body, reveal 1-3, erode 1-5, ink, ink erode 1-3, edge, glow) | 1024 x 256 | mesh UVs: u along the arc (0 = tail, 1 = head), v across (0 = inner, 1 = outer rim) |
| Erosion masks | 1024 x 256 | threshold maps the erode stages were cut from; keep them to regenerate stages |
| 4x4 flipbooks (crescent, ring, and their ink versions) | 1024 | frames 0-3 sweep-in, 4-5 hold, 6-15 erode, matching the timing table |
| 8x8 petal and shard sheet | 1024 | 64 static random shapes (`FlipbookStartRandom`, framerate 0.001) |
| Sprites (flash, glow, glint, spark streak, square spark, ground disc and ring, beam band, trail) | 512 to 1024 | singles |

Author **flipbooks at exactly 1024 x 1024** ([[Particle Emitters In Depth]]). Keep the value range in the greyscale (a 0.36 to 0.66 body ramp with a white rim band at v 0.82 to 0.9) so a single tint still gives three tones. Bake erosion as **separate textures** rather than trying to animate a mask at runtime. Roblox has no per-pixel alpha threshold for meshes, and `EditableImage` is off in published games by default ([[VFX Design Playbook]]).

---

## 3. Roblox implementation

### Which instance does which layer

| Layer | Instance | Why |
|---|---|---|
| Body, ink, ground ring | `Part` + `SpecialMesh` (FileMesh) | `MeshId` and `TextureId` are settable from scripts, `VertexColor` tints the texture, `Scale` animates cheaply. Body Material Neon, ink SmoothPlastic |
| Hot edge | `Beam` ([[FaceCamera]], 24 segments, LightEmission 1) on two attachments whose X axes follow the arc tangent, `CurveSize = 4/3 * tan(band/4) * r` | exact arc, additive, re-placed each frame to ride the head ([[Beams and Trails]]) |
| Glow card, ink card, ground disc | `ParticleEmitter`, `VelocityPerpendicular`, Speed 0.001, `EmissionDirection` Top, `Emit(1)` | a flat card in the swing plane |
| Sparks, glints, petals, squares | `ParticleEmitter`, `Emit(k)` while the attachment is moved to the head | world-space bursts along the swing |
| Light | `PointLight`, shadows off, 0.3 to 0.35 s | colour spill on the floor |

### One clock

Run every live effect from **one** Heartbeat connection that disconnects when nothing is alive. Each effect is a table of step functions `step(t)` that set every animated property from `t`, so there are no tweens to cancel and nothing drifts. Wrap the steps in `pcall`: on error the effect is destroyed instead of leaking. Add `Debris:AddItem(root, life + 3)` as a safety net.

### Markers

Fire the effect from the clip's `Hit` marker, not from the click. Our sword clips carry `TrailOn`, `Hit` (value `"1"`, `"2"`, `"3"`, `"heavy"`, `"dash"`) and `TrailOff`. The marker value picks the preset and the swing plane (flip for backhands, tilt about 70 deg for an overhead). `TrailOn` calls `Trail:Clear()` before enabling. Skip upper-body copies of a clip (attribute `KitUpper`) so nothing fires twice ([[VFX Timing with Animation]]). Start the swing sound skipped forward by its peak so the crack lands on the hit.

### Budget

Measured per cast: 27 to 69 particles, 0 to 12 SpecialMesh parts (plus up to 4 ghost copies for a dash), 0 to 5 beams, 1 light. `Emit` ignores Roblox's own quality thinning, so scale every count yourself. The module uses quality 0.6 on touch-only devices, a live-particle cap (900 on PC, 360 on mobile) with decoration dropped above 75 % of it, half detail beyond 160 studs, nothing beyond 220 studs, and at most 8 effects at once ([[VFX Performance Budgets and Culling]]).

---

## 4. Previewing in Blender (and where it lies)

The LihFolk previews replay the module's own preset tables in Blender EEVEE. A small emulator runs 60 Hz ticks, `Emit` bursts, drag as halving per second, beam Béziers, flipbook cells and texture swaps. Blend modes are reproduced with *Transparent BSDF + Emission* added together: background times `1 - a * (1 - LightEmission)`, plus `colour * a`. This is good enough to judge timing and layering. It is not Roblox:

- Roblox `Color3` values are **sRGB**. Feeding them to Blender as linear made every dark tint a visible mid-tone and every colour pastel. Two blind review rounds were wasted on that before it was found. Convert with the sRGB curve before use.
- Bloom, Neon, transparent sorting, `ZOffset`, `Squash` and the sign of particle `Rotation` are approximations. Judge the final look in Studio at game camera distance, on a phone, in the darkest and brightest zones.

---

## 5. Wave 2 presets (same layer approach)

| Preset | Flash | Main shape | Secondary | Dark layer | Timing (s) |
|---|---|---|---|---|---|
| SlashSweep | star at the contact | 9-stud 200 deg crescent + 7.2-stud 160 deg filament 0.04 s later | white-hot rim mesh along the whole arc, debris thrown forward (`fwd` 0.7) | wide-stroke ink, dark ground pool pushed 4 studs forward | sweep 0.12, hold 0.04, erode 0.36 (cross-faded) |
| ThrustPierce | star at the blade tip | three nested cones (deep ink 4.2 wide, element 3.0, white needle 0.9) growing in 0.05-0.07 s, then collapsing from the base | two wind lines converging on the tip; shockwave rings facing forward at 6 and 10.5 studs | the deep-blue ink cone (near-black vanished on a dark floor) | cones 0.24-0.44, rings 0.22-0.38 |
| OverheadCleave | star where the arc meets the floor (t 0.07) | vertical crescent (tilt 90) from behind the head into the floor about 5.5 studs ahead | ground crack (dark + additive copy), shockwave ring, shards, dust, sparks | dark crack card, dust ring | sweep 0.1, crack 1.1 |
| DashTrail | small star at the start | streaks along the path (ink, element, white core) whose tail chases the head after 0.15-0.22 s | 4 Neon afterimages every 0.06 s, backward speed lines, launch ring | ink streak under the element streak | dash 0.27, ease-out 2.4 |
| HitSpark | star, 8 studs | expanding shock ring cards and a small crescent cut mark | 18 sparks in an 80 deg cone along the hit, shards, glints | dark impact frame behind the flash (0.14 s) | 0.14-0.32 |
| ChargeUp | ready glint at release | motes converging (speed about radius / life), two imploding ground rings | rising aura streaks, core glow growing | dark specks converging, dark ground disc | lead 0.75, retimed to the clip |

Lessons from the blind reviews (Measured):
- **Stepped erosion** came from three things: texture swaps (fix: cross-fade stage k into k+1 with a second mesh), hard 0.035
  thresholds and hairline brush gaps (fix: soft stage textures, broad strokes), and flipbook cards whose own erosion banded
  across a large arc (fix: drop the cards on big arcs). A 44-segment ring also showed facets at 7.5 studs (112 segments fixed it).
- **Flat inner colour**: one tint per mesh cannot make a gradient. Add a white-hot rim mesh (`strip_edge`, VertexColor 2.2)
  over the body and a dark ground pool, so every frame has white, element and dark.
- **Weapon Trails**: off for spins, wide sweeps and stabs (a stab's Trail drags a streak from behind the back).
- **Preview floor**: decals at the floor plane vanish when the preview root is lower than the module's floor distance (3 studs).

## 6. IceExplosion (radial burst)

Built one-shot from the recipe, then revised once from user feedback (not scored). Layers and timing at 30 fps:

| Layer | Build | Timing |
|---|---|---|
| Flash | small white-cyan star (5 studs, 0.06 s) and a faint blue glow (9 studs, 0.1 s); keep it small so the caster stays readable | 0-2 f |
| Frosted shockwave | flat `frost_ring` card: broken bright rim, fern-like frost fringe outside, crackled see-through inside; 2 to 19.5 studs on an ease-out curve | 0-9 f |
| Frost-crack decal | `ground_frost` card: a dark copy (LightEmission 0) under an additive copy; spreads in the first fifth of its life, then holds | 1-38 f |
| Crystal cluster | `crystal` hex prisms with the `crystal_facets` texture (white facet edges, pale body, deep base): a centre spike, 5 main spikes leaning 20-48 deg, 4 small ones at the base, bedded in an `ice_mound`; staggered 1 frame apart with a back-ease overshoot | erupt 1-6 f, hold about 10 f |
| Shatter | each main spike collapses in 0.1 s and throws 3 shard particles (gravity -40) | about 16-20 f |
| Cold mist | 9 pale `glow_soft` puffs, nearly normal blend (LightEmission 0.15), low and slow, lingering | 3-40 f |
| Glitter | twinkles around the cluster, square sparkles drifting down | 3-35 f |

What the revision fixed: thin needle shards read as glass splinters (use wide faceted prisms in a cluster); a flat white mesh
ring read as a solid pool (use a frosted, broken, fringed ring card); a 9-stud flash hid the caster.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| The ring reads as a flat glowing plate | Hold with no motion; extra concentric ground rings | Keep it drifting (about 110 deg over the erode); one faint ground disc only |
| Dark smear invisible | The smear sits inside the body's inner edge or under the body, so it is dark on a dark floor | Overlap it with the body's inner half (scale about 1.0) and draw it over the body |
| Hot edge disappears after the sweep | The edge ribbon sits below a mesh with a raised outer lip | Lift the ribbon onto the lip (about 0.15 x radius for a dished ring) |
| White wedge cuts through a spin slash | Weapon Trail enabled across a 350 deg sweep | No Trail on spins; trails only for sweeps under about 120 deg |
| Slash reads as an aura or hits behind the back | 360 ring, or an arc spilling past about 110 deg | Frontal sweep within +-100 deg of the LookVector; bias debris forward |
| Erosion shows bands or stair-steps | Texture swaps, hard thresholds, hairline gaps, banded flipbook cards | Cross-fade soft stages on a second mesh; drop cards on big arcs |
| Dark layer invisible | Near-black ink over a dark floor | Overlap something bright, or use a deep tint of the element |
| Erosion looks like a clean wipe | Erosion threshold based on position only | Add the brush-stroke noise to the threshold, so it breaks along strokes |
| Erosion starts late, so the shape holds | Linear stage schedule | Front-load it (square root of progress) |
| Previews look washed out | sRGB colours used as linear | Linearise tints in the preview |
| Blank layer on first use | Texture not preloaded, or uploaded seconds ago | `preload()` on equip; wait out fresh uploads |

## Checklist

- [ ] Slash arcs stay in front (+-100 deg of the LookVector); no rings or spins
- [ ] Three tones present in every frame: white edge, element body, dark smear
- [ ] Sweep 3 to 5 frames, hold 1 to 2, erode 10 to 15 (at 30 fps)
- [ ] Shape keeps moving through hold and erode
- [ ] Dark layer overlaps something bright
- [ ] Debris and sparks fly along the swing, not radially
- [ ] One Heartbeat clock, `Emit` only, Debris safety net
- [ ] Counts scaled by quality and distance; mobile cap stated
- [ ] Fired from the `Hit` marker; trail window from `TrailOn` / `TrailOff`; no trail on spins
- [ ] Texture and mesh ids are uploads you own (empty until uploaded, never guessed)
- [ ] Judged in Studio at game distance, not only in a preview render

See also: [[VFX Readability and Value - Lessons from Blind Reviews]] (general value, clutter, flash and light rules), [[Escalation and Grandeur Without Clutter]] (multi-beat and spin moves), [[VFX Design Playbook]], [[Beams and Trails]], [[Particle Emitters In Depth]], [[VFX Timing with Animation]], [[VFX Performance Budgets and Culling]], [[Mesh VFX Packs Built in Blender]], [[Dash VFX Presentation on an R15 Rig]].

<!-- related:start -->
## Related
[[VFX Previews in Blender for Roblox - Colour and Framing]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Designing VFX Textures and Flipbooks in Figma]] · [[Ice Ball Cast to Explosion - Approved Recipe]] · [[Projectile VFX - Muzzle, Travel and Impact]] · [[Auras, Shields and Status Effects]] · [[AoE Telegraphs - Readable Ground Warnings]] · [[Light Sources and Shadows]]
<!-- related:end -->
