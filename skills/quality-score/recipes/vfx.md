# Recipes: vfx (shipped defaults; the project ledger refines these)

## First-pass defaults
- Read the matching specialist skill and the hard gates in `../rubrics/vfx.md` before generating; design to pass every gate on the first draft.

## Pre-empt
- Slashes stay in front (+-100 deg of the LookVector): no rings or spins (X6), unless the move is explicitly a spin attack.
- Preview with sRGB-linearised tints, at the module's real floor height (3 studs under the root).
- No weapon Trail on spins, wide sweeps or stabs.

- Every frame: saturated dark ink (never grey), element body, thin white core, at most one accent hue.
- Repeats (spins, combo hits) distinct and escalating; later layers shorter; add a layer only by cutting or shrinking another; silhouette checked at game distance after each.
- Nothing large and translucent in front of the body; effect lights above/behind at low power; flash small, 1-2 frames, 1 frame after contact, at the blade head.
- Release bursts biased forward, away from the caster. Previews never get preview-only fixes.

## Proven fixes
| Miss | Fix |
|---|---|
| X4 stepped erosion | cross-fade baked stages on a 2nd mesh, soft-threshold textures, drop flipbook cards on big arcs, hi-seg mesh |
| X3 flat body | white-hot rim mesh over the body + dark ground pool / deep-tint ink |
| X3 dark layer invisible | dark only over something bright, or use a deep element tint |
| Near-monochrome palette (spin attack v1, 8.1) | deep navy ink layer + white-hot core + one contrasting accent hue |
| Clutter: stacked identical rings | each repeat distinct and escalating, thinner stack, later layers shorter |
| Flat smoke blobs | textured puffs, lighter tops / darker cores, rolling motion |
| Ground rings "stamp" | expand from small while fading, eased out |
| Stray sparks off-frame | short life, high drag, directional |
| Character tinted by the effect | spawn large layers ahead of the body, rims not washes, glow parts off the body (fix the effect, not the preview) |
| Flash too big / on the body | ~0.6x, 1-2 frames, 1 frame after contact, at the crescent head |
| Light shafts read as panels | additive tapered textures, falloff along length and both edges, radial; else cut |
| Shins tinted by effect light | light above/behind the effect, low power |
| Hairline streaks look like bars | lower Beam brightness (bloom fattens) |
| Dark ink reads muddy | saturated blue-black thinning to blue, not grey |
| White bits vanish on white ground | thin dark outline or element tint |
| Black orb unreadable | near-black body, rim only at the silhouette (shell 1.02, transparency ~0.45) |
| Release burst sprays over caster | bias the burst forward |

## Grandeur without clutter (spin attack v1 8.1 -> v2.1 7.7, 2026-10-29)
- v2.1 ADDED vortex + rune circle + smoke + stacked rings and scored lower (9.2/7.7/7.7): spins 2-3 cluttered, silhouette buried. Peak was only ~150 particles: the limit is screen and silhouette, not the 900 PC / 360 mobile caps.
- Escalate a FEW layers per repeat (bigger, brighter, faster); cut or shrink one layer for each one added; check the silhouette at game distance after every added layer. At most one growing element (vortex or sigil).
- Finisher = clear payoff: one bigger, brighter forward arc than the spins, on the contact frame, blade high, edge leading (not low / pointing down). Snap + hold on each contact.
- Smoke: identical static puffs lingering ~1 s read as flat discs; vary size and drift, fade fast.
- Preview camera: push in, shake on the finisher, pull back.
- Vault: "Escalation and Grandeur Without Clutter", "VFX Readability and Value - Lessons from Blind Reviews".

## Approved reference: Ice Ball Cast to Explosion (2026-10-29, owner-approved)
- Template for cast-and-throw abilities: see vault note "Ice Ball Cast to Explosion - Approved Recipe".
- Camera follows the beat (tight charge ~45% frame height, pull back for flight, settle on impact).
- Readable projectile: white core, faceted body, rim + glints; motes spiral tightly into the hand.
- Whip throw (hips lead, wrist snap), planted foot flat through release.
- Impact: ball visible until contact; flash 1 frame later at 0.6x; shards/mist toward camera.
- Ice: chunky faceted crystal clusters + crackled frost ring (not glass shards or a flat disc).
