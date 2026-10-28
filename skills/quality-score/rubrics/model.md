# Rubric: 3D model (Roblox)

Source: `../../roblox-blender-modeling/references/quality-research.md` (sections 2, 5). Run `lf.gate()` and `lf.render_review()` from the Blender skill.

## Hard gates (any fail caps the score at 5.0)
- A1 tris within the class ceiling (hard limit 20,000)
- A2 watertight (unless a foliage card)
- A3 no flipped or inconsistent normals
- A4 no n-gons
- A5 no loose or degenerate geometry
- A6 transforms applied
- A8 one UV map, inside 0-1
- A10 one material per object
- A7 sane size in studs
- A12 origin at the documented placement point

## Criteria (0 / 1 / 2)
| # | Criterion | W | 0 | 1 | 2 |
|---|---|---|---|---|---|
| V1 | Silhouette at 64 px, all angles | 3 | unrecognisable | readable from one angle | readable from all |
| V2 | Big / medium / small hierarchy | 2 | uniform noise | some | clear |
| V3 | Proportion fits style | 2 | stiff primitives | partly exaggerated | confident stylised |
| V4 | Edge treatment | 2 | razor or blobby | inconsistent bevels | consistent bevels catch light |
| V5 | Clean shading | 2 | artifacts | minor | clean |
| V6 | Palette (2-3 colours + value contrast) | 1 | noisy | too many hues | disciplined |
| V7 | Geometry economy (tris vs class target) | 1 | over ceiling or wasteful | over target | at or under target |
| V8 | Matches kit (texel, bevel, palette) | 1 | clashes | minor mismatch | indistinguishable |
| V9 | Studio-ready (collision, flags, colour white for vertex colours) | 1 | wrong | one issue | correct |

Evidence: the gate report, the four renders (front, three-quarter, top, silhouette), and tris against `lf.BUDGETS`.
