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
- A15 symmetry: objects that are symmetric by design (shields, badges, swords across the blade's flat, bottles,
  most props) have `lf.symmetry_error(ob, axis)` <= 1 % of size (`lf.gate(..., symmetric="X")`)
- A16 feature alignment and seating: features meant to be centred (emblems, gems, guards, blades on grips) are
  within 2 % of size of their parent's centre/axis (`lf.alignment_report`), and features meant to sit on a
  surface touch it (`lf.seated`, no floating gap)
- A17 no self-intersections inside one shell (`lf.self_intersections`: folded profiles, looped insets, sweeps
  through themselves). Separate shells pushed into each other on purpose are allowed
- A18 clean planar caps and shading: no overlapping or folded triangles in flat caps, no flipped or degenerate
  faces (`lf.planar_cap_check`, `lf.shading_artifacts`)

## Review order (blind reviewer)
1. Correctness first: symmetry (is a symmetric-by-design object lopsided?), centring (emblem, blade, gem
   off-centre?), seating (anything floating or sunk too deep?). A visible failure here caps V1, V3 and V5 at 1.
2. Surface artifacts in the close-ups (`lf.render_review(..., features=[...])`): patches, pinches, seams,
   z-fighting, stray faceting. A visible artifact caps V5 at 1.
3. Then style: silhouette, hierarchy, proportion, edges, palette.
Workbench studio light comes from one side, so a symmetric object can *look* lopsided from shading alone:
judge symmetry from the outline in the front view and silhouette, and check the A15 number.

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

Evidence: the gate report (A1-A18), the four renders (front, three-quarter, top, silhouette), the feature
close-ups (studio + flat light), and tris against `lf.BUDGETS`.
