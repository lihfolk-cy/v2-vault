# Recipes: vfx (shipped defaults; the project ledger refines these)

## First-pass defaults
- Read the matching specialist skill and the hard gates in `../rubrics/vfx.md` before generating; design to pass every gate on the first draft.

## Pre-empt
- Slashes stay in front (+-100 deg of the LookVector): no rings or spins (X6).
- Preview with sRGB-linearised tints, at the module's real floor height (3 studs under the root).
- No weapon Trail on spins, wide sweeps or stabs.

## Proven fixes
| Miss | Fix |
|---|---|
| X4 stepped erosion | cross-fade baked stages on a 2nd mesh, soft-threshold textures, drop flipbook cards on big arcs, hi-seg mesh |
| X3 flat body | white-hot rim mesh over the body + dark ground pool / deep-tint ink |
| X3 dark layer invisible | dark only over something bright, or use a deep element tint |

## Approved reference: Ice Ball Cast to Explosion (2026-10-29, owner-approved)
- Template for cast-and-throw abilities: see vault note "Ice Ball Cast to Explosion - Approved Recipe".
- Camera follows the beat (tight charge ~45% frame height, pull back for flight, settle on impact).
- Readable projectile: white core, faceted body, rim + glints; motes spiral tightly into the hand.
- Whip throw (hips lead, wrist snap), planted foot flat through release.
- Impact: ball visible until contact; flash 1 frame later at 0.6x; shards/mist toward camera.
- Ice: chunky faceted crystal clusters + crackled frost ring (not glass shards or a flat disc).
