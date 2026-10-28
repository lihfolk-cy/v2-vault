# Recipes: 3D model (shipped defaults; the project ledger refines these)

## First-pass defaults
- `lf.setup_scene()`: 1 Blender unit = 1 stud. Size against an R15 avatar (about 5 studs tall; doors 7-8).
- Block out big, then medium, then small; check `_silhouette.png` **before** any detail.
- Edge treatment `lf.finish(ob, "soft")`: 1-segment bevel, harden normals, weighted normals, bevel width about 2-5% of the object's smallest dimension (crate 3 studs = 0.15).
- Palette: 2-3 colours plus 1 accent, with clear value contrast.
- Origin: `bottom` for floor props, `back` for wall props, `corner` for modular pieces.
- Export only with `lf.export_glb` (applies modifiers, keeps vertex colours, 1:1 scale).

## Pre-empt (most common first-draft misses)
- A6 transforms not applied: `lf.finish` applies them, so call it before the gate.
- V4 inconsistent bevels: one bevel width per kit.
- V1 silhouette reads only from the front: exaggerate depth and side profile.
- Over-bevelling: more than 2 segments on small props multiplies tris 9x or more (Measured).
- A15/A16: author symmetric objects as half + mirror (`lc.mirror_outline`); centre features via bbox or
  area-centroid maths (`polygon centroid`, `lf.alignment_report`), never by eye. Run `lf.gate(..., symmetric=,
  align=, seats=)`. A blade's base midpoint must sit on the grip axis (offset the sweep path, not the grip).
- A17/A18: never inset an already-rounded outline (the inset loops at corners tighter than the inset); inset
  the sharp outline, then round it. Concave caps (stars, crosses, gears) need ear-clip fill
  (`lc.extrude_outline` does this; bmesh BEAUTY ngon fill put triangles outside the outline = the "square
  patch" on the star). Sweep profiles must stay in order (a fuller wider than its flat folds the blade).
- Review with close-ups: `lf.render_review(ob, dir, features=[(name, centre, radius)])`; small cap artifacts
  are invisible in the four whole-object views.
- V6 grey: paint vertex colours (`lc.paint` + `lc.vertex_color_material`): one hue in 2-3 values + kit gold
  accent + ink dark; colour boundaries on edge loops (stations/rings), so they stay crisp.

## Proven fixes
| Miss | Fix |
|---|---|
| Shading gradients on flat faces | Weighted Normal (keep sharp) after the bevel |
| Bevels missing in Studio | `export_apply=True` (the GLB default drops modifiers) |
| Model imports 100x too big | GLB, or FBX with `FBX_SCALE_UNITS` |
| Grey mesh in Studio | Export vertex colours as ACTIVE; MeshPart.Color white |
| V6 flat grey (blind 4-6) | `lc.paint` + `lc.vertex_color_material`: one hue in 2-3 values + kit gold accent + ink dark; colour borders on rings/stations. Blind +1.7 to +3.7 on all 7 curve samples |
| V8 "off-kit" hue (brown grip, brown cork, cool-grey cream) | Use only kit colours (gold, ink, cream) besides the asset's own hue; warm the cream (mix 30% gold) so Workbench does not render it grey |
| V6 stepped bands on a gradient | `lc.paint(..., per="corner")` and blend on the corner's UV v; per-face colour steps at every ring |
| V4 razor blade / ribbon rim | Give the sweep profile a flat rounded edge (two points, half-thickness max(0.012, 0.3 t)) instead of one sharp point. Sword 6.6 -> 9.3 with the flare below |
| V3 blade reads stiff | Flare the edge side toward the tip (x 1 + 0.85 s) and clip late (s 0.70) so the point is broad then short |
| V1 thin tip vanishes at 64 px | No min-width clamp near tips (it cuts them flat); end sweeps with a sqrt dome over the last 3-4 % |
| V1 spiral unreadable from top | Tilt the curl plane ~35 deg about X (horn top view went from "grub" to a curl) |
| A17 folded sweep profile | Keep profile points in order: inner features (fuller) must stay inside their flat: `fw = 0.6 * min(fc - flatL, flatR - fc)` |
| A16 accent floats / pokes through | Build accents from the parent's own vertices (e.g. the band's rim vertices), not a second sweep along the same curve: its rotation-minimising frame starts differently and landed 0.045 studs off. Nudge 0.02 so cleanup does not weld the shells |
| V5 faceting (blind reviewers cap it at 1 in 512 px close-ups) | Recurring blocker at <= 18 radial steps / ~20 deg per ring. Budget 20-24 radial steps or ~10 deg rings for hero curves, even over a small target, or accept V5 = 1 and get every other criterion to 2 |
| Blind reviewer arithmetic | Ask for a grades array that matches the evidence lines and re-add the weights yourself: 2 of 30 reviews typed a misaligned array |

## Creatures (Fox, 2026-10-28: blind 4.7 -> 7.7 in 3 rounds, below bar)
| Miss | Fix / lesson |
|---|---|
| V4/V5 = 0: voxel remesh + decimate + dissolve_limit carve (wolf_v3 method) | Random facets and colour borders crossing long sliver facets (sock streaks). Build from lofts/sweeps instead, with a ring station exactly on every colour border (sock line, tail tip): blind +3.0 |
| A15 0.7 % from one centred icosphere (nose) | `create_icosphere` is not X-mirror-symmetric. Build centred blobs from rings (superellipse rings with angles (i+0.5)/n, n even): error 0.0 |
| Eye raycast lands on the wrong part / zero normal | BVH from a fresh bmesh needs `recalc_face_normals` + `normal_update()` first; cast eyes mostly sideways (0.8, -0.56, 0.12), not forward, or the ray hits the snout |
| Stair-stepped jaw/muzzle border | Colour by the ring's parametric sector angle, not by face normal: a sector whose normal equals the threshold flips per station |
| "soft" bevel on lofted creatures | Bevel on poles, thin cone tips and fan caps broke A2/A4/A17 and cost +3k tris; use "smooth" with ONE angle for the whole creature (60 deg); 35 deg left ears hard-faceted next to a soft head (V4) |
| Plateau at 7.7 (3 blind reviews, V3/V4/V5/V8 = 1) | 20+ overlapping shells read as seams, flat tuft "cards" and stilt legs. For >= 8.5 plan a fused single shell with designed topology (quad cage + subsurf, or remesh -> retopo) from the start; tufts as thick rounded lobes, legs with thigh mass blended into the body |
