# Rubric: PBR material set (Roblox MaterialVariant / SurfaceAppearance)

Sources: `LihFolk Vault V2/44 Materials and Surfaces/` (SurfaceAppearance PBR Workflow, MaterialService and Custom Materials,
Stylised vs Realistic Material Pipelines) and `LihFolk Vault V2/14 3D Modeling/Texturing and PBR Baking.md` (value ranges).
Generator and gate code: `tools/pack/gen_materials.py`, `tools/pack/packutil.py` (`material_gates`).
Evidence: `meta.json` gate report, `preview.png` (tiled ground 3x3, sphere, cube under neutral sun + sky, plus a 2x2
colour tile and the normal map), and the family sheet in `_sheets/`.

## Hard gates (any fail caps the score at 5.0; failed items are dropped, not shipped)
- G1 Maps: `Color.png`, `Color_Neutral.png`, `Normal.png`, `Roughness.png`, `Metalness.png` as separate PNGs, all 1024 x 1024.
- G2 Seamless tiling, two checks:
  - wrap-diff: for every map, the step across the wrapped edge (last row to first row, last column to first column)
    divided by the 95th percentile of the per-row / per-column steps inside the map. Must be **<= 1.25** on both axes.
    (A tiling map scores ~1 or below: the seam is just another row.)
  - shift proof: the source shader is re-baked with UV + (0.5, 0.5); it must equal the half-rolled bake
    (mean abs difference **<= 0.004**). This proves periodicity even when a mortar or panel line happens to sit on the edge.
- G3 Normal is tangent space, OpenGL (+Y up, Roblox convention): mean XY within 0.03 of 0.5, mean Z > 0.75 (encoded).
- G4 No baked directional lighting in Color: |corr(luminance, normal X)| and |corr(luminance, normal Y)| both **< 0.25**.
  (Height-based tone, such as darker grout or lighter stone tops, is allowed; light from one side is not.)
- G5 Plausible values: dielectric albedo luminance p1 >= 28 and p99 <= 242 sRGB (decals with light content: 250);
  metalness binary (pixels between 0.15 and 0.85 <= 6 %); metal albedo luminance >= 110; roughness min >= 0.02 and
  mean inside the family's stated range.
- G6 Not degenerate: Color luminance std > 3 (sRGB units), normal not flat.

## Review order (blind reviewer)
1. Seams and repetition first: look at the 3x3 ground. A visible seam caps M4 at 0; an obvious repeating hot spot caps M4 at 1.
2. Readability at the preview distance: can you name the material without the label? If not, M1 is at most 1.
3. Then palette, normals, recolourability, variety.
Judge from the preview and the sheet only; the sun comes from one side, so a lit side is the light, not the texture.

## Criteria (0 / 1 / 2)
| # | Criterion | W | 0 | 1 | 2 |
|---|---|---|---|---|---|
| M1 | Stylised readability at game distance (names itself on sphere, cube and ground) | 3 | noise or wrong material | readable up close only | instantly readable, clear big/medium/small shapes |
| M2 | Palette discipline (2-4 related hues, value groups, no muddy or neon accidents) | 2 | noisy or muddy | too many hues or flat values | disciplined, appealing |
| M3 | Normal strength and shape (relief matches the material, not flat, not crunchy) | 2 | flat or noisy | too weak or too strong in places | chunky, clean, matches the colour shapes |
| M4 | Tiling invisibility on the 3x3 ground (no seam, no obvious repeating landmark) | 2 | seam or grid of landmarks | mild repetition | reads as one continuous surface |
| M5 | Recolourability (`Color_Neutral.png` keeps the value structure; mean 0.65-0.8; tints cleanly) | 1 | missing or crushed | usable with care | clean tint base (measured: mean, p5-p95 spread >= 0.15) |
| M6 | Variety inside the family (family sheet: themes and parameters genuinely differ) | 1 | clones | palette swaps only | distinct looks |
| M7 | PBR behaviour (metals read metallic, glossy materials glossy, matte stays matte) | 1 | wrong | mostly right | right |

`score = 10 x sum(weight x points/2) / sum(weight)` (weights sum to 12).
Pass bar 8.5. Family pass/fail uses 3 independent blind reviewers, median per criterion; spread >= 2 points on a
criterion is recorded in the ledger. M5 and the gates are measured, not judged.
