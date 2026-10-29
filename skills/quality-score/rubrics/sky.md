# Rubric: Skybox (Roblox `Sky`, six faces) + Lighting preset

Sources: `LihFolk Vault V2/07 Lighting VFX and Audio/` (Atmosphere Sky Clouds and Post-Processing, Stylized Lighting Recipes,
Lighting Mood and Time of Day) and `LihFolk Vault V2/06 World Building and Art/Water Sky and Atmosphere Art.md`.
Generator and gate code: `tools/pack/gen_skies.py`, `tools/pack/packutil.py`.
Evidence: the six `Sky*.png` faces, `preview.png` (two game-camera views at the horizon with a neutral test ground,
plus the unfolded cube cross), `lighting.json`, and the family sheet in `_sheets/`.

Face convention used by the generator (Roblox space, Y up, front = -Z): Ft -Z, Bk +Z, Rt +X, Lf -X, Up +Y, Dn -Y.
Up and Dn in-plane rotation is configurable (`--updn-rot`) and **unverified in Studio**; default = cube-cross layout
(bottom edge of Up meets the top edge of Ft, top edge of Dn meets the bottom edge of Ft).

## Hard gates (any fail caps the score at 5.0; failed items are dropped)
- S1 Six faces `SkyBk/Dn/Ft/Lf/Rt/Up.png`, each 1024 x 1024, RGB.
- S2 Seamless cube edges: for all 12 cube seams, the mean colour step across the seam (edge pixel of one face to the
  touching edge pixel of its neighbour, mapped through the face convention above) divided by the mean step between the
  two pixel rows just inside each face (+0.0015 floor). Worst of the 24 one-sided seam measurements **<= 1.6**.
  (No absolute cap: star fields have large steps everywhere; the ratio is what exposes a seam.)
- S3 No pole pinching: on Up and Dn (2x downsampled), the median angular pixel gradient on rings close to the pole
  (r = 0.04, 0.06, 0.08 of the face half-width) divided by rings further out (r = 0.2, 0.25, 0.3). Must be **<= 2.5**.
  A lat-long-mapped sky converges all round the pole (gradient ~1/r, ratio well above 3); a direction-based sky is ~1.
- S4 One sun: if a sun disc is painted, `lighting.json` sets `Sky.CelestialBodiesShown = false`; otherwise no disc is painted.
- S5 `lighting.json` present, valid, and every value inside the ranges in the Stylized Lighting Recipes note
  (Atmosphere.Density 0.2-0.7, Haze 0-3, Brightness 0-4, Ambient not near black at night).

## Review order (blind reviewer)
1. Seams/poles first on the cross: a visible seam or a pinch caps K3 and K4 at 1.
2. Mood: can you name the time of day / weather / fantasy theme from the game view alone?
3. Then colour harmony, horizon, clouds, and how usable the preset is in a Roblox game.

## Criteria (0 / 1 / 2)
| # | Criterion | W | 0 | 1 | 2 |
|---|---|---|---|---|---|
| K1 | Mood readability (time of day, weather or theme is obvious at a glance) | 3 | ambiguous | readable but generic | instantly reads, has character |
| K2 | Colour harmony (zenith-horizon gradient, complementary accents, no banding or muddy greys) | 2 | clashing or banded | ok | beautiful, controlled |
| K3 | Horizon clarity (a clear, believable horizon band the Atmosphere can melt into; Dn face not distracting) | 2 | no horizon or harsh line | acceptable | clean, game-ready |
| K4 | Cloud / feature stylisation (clouds, stars, aurora, nebula: shaped, layered, stylised, not noise) | 2 | noise | partly shaped | confident stylised shapes |
| K5 | Roblox Lighting usefulness (`lighting.json` matches the sky: Atmosphere colour from the horizon, ambient tint, sun colour) | 1 | missing or mismatched | generic | matched and ready to paste (measured: Atmosphere.Color within 25 RGB of the horizon colour) |
| K6 | Variety inside the family (sheet) | 1 | clones | palette swaps | distinct |

`score = 10 x sum(weight x points/2) / sum(weight)` (weights sum to 11).
Pass bar 8.5. Family pass/fail uses 3 independent blind reviewers, median per criterion; record spreads >= 2 points.
