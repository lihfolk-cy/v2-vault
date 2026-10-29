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

## Creatures: fused SDF shell (Fox v3, 2026-10-28: blind 7.0 / 6.7 / 7.0 / 7.0, below bar, not shipped)
Script: `tools/fox/build_fox3.py` (smooth-union SDF in numpy -> surface nets -> weighted Decimate -> keep +X half
-> level-set colour cuts -> mirror -> custom normals = SDF gradient). Gates were clean every round (A15 0.0, A17 0),
seams were gone, but the blind score did NOT beat the 22-shell loft build (7.7).
| Miss | Fix / lesson |
|---|---|
| Decimate vertex-group weights inverted the intent (head collapsed to shards, torso kept 53k tris) | Blender: edge cost *= 1 + (2 - w1 - w2) * factor and weight 0 = locked. Use weights 0.4 (protect) .. 1.0 (free), factor 2-5, never 0 and never `invert_vertex_group` |
| V5 = 1 every round: "lumpy back", "faceted outlines", "crumpled bib" | Workbench WORLD cavity shades the real triangle facets of a decimated mesh even with exact custom normals; at 4-5k tris the close-ups show polygon outlines on paws and ear tips. 7.5k tris did not fix it (blind 6.7, V7 lost too). Decimation is the wrong topology for a smooth creature: next try a designed quad cage + one Catmull-Clark level (even quads, no poles) |
| Star-shaped highlights on boots | High-valence poles from Decimate. `bmesh.ops.beautify_fill(method="AREA")` on the triangles + tangential relax removed them |
| Colour borders off sliver faces | Cut the mesh along the analytic level set (snap near verts tangentially, split crossing edges, split faces, re-project), then fair each border chain with a 1-D Laplacian re-projected onto the surface: borders read as smooth curves (zigzag complaints stopped) |
| Small forms (toe grooves, bib fluff points, brow ridge) at 5k tris | Read as "torn hem", "pinched toes", "lumpy brow" (V5 cap). Only add small forms where the mesh has density for them; otherwise keep the small tier to eyes, glints, nose |
| Colour shows grey/drab in renders | Workbench uses AgX by default; set `scene.view_settings.view_transform = "Standard"` before `render_review` so renders show the exact vertex-colour hexes Roblox will show |
| Reviewers disagree on style per round (head size, tufts, tail) | Proportion asks changed every review (bigger head -> "ears fennec-like"); V2/V3 stayed 1 across 7 fox reviews. Lock a reference sheet (side + front) before modelling so proportion is designed, not iterated |
## Kits (tools/kits, 2026-10-28: 26 generator types, ~90 blind reviews, 3-reviewer panels decide pass/fail)
| Miss | Fix / lesson |
|---|---|
| V5 faceted pommels / balls / rivets / collars (the #1 blind complaint) | Small round parts get their own 24-step lathe (pommel split from the 16-18-step grip), rivets as 7-pt domes; fit the rest to the class target |
| V7 = 1 silently costs 0.3 | Fit loops (`fit_hilt`: 22 -> 14 steps until under target) + ship filter: a variant over its class target is not shipped |
| V3 "realistic, lanky" hafted weapons (spear/staff 6.0-7.3) | Chunky: haft r 0.18-0.23, head ~1/3 of length, shorter haft, taper toward the head: 8.7-10.0 |
| V4/V8 razor facets on gems and faceted props | Angle-limited 0.025-0.03 bevel modifier + weighted normals (`finalize(bevel=)`) + Triangulate (bevel turns pole fans into n-gons): gem 7.7 -> 9.3, vial 8.3 -> 10.0 |
| Small round props stuck at 8.0-8.3 (potion: 16-22 steps under the 600 target) | Make the polygon a design choice: 6/8 flat sides + chamfers (vial, tokens) instead of a low-step "round" lathe |
| V2 no small tier on plain lathes (barrel 8.0) | Model detail on existing rings: stave grooves = every 3rd lathe vertex pulled in 0.035, thick chamfered hoops + ink nails: 9.3 |
| A17 after join although every part is clean | Coincident poles of two lathes (stem top = hub top) weld into one shell in cleanup; offset by 0.03 |
| glTF (Blender 5.2) exports EVERY colour attribute as COLOR_n | Keep only "Col" on the mesh while exporting each colourway |
| Reviewer types weight-1 grades as 1 (= "1/1") | Re-read grades from the evidence lines (3 of ~90 reviews) |
## Kits wave 2 (Nature / Modular / Furniture, 2026-10-29: 34 types, 3 fix rounds, 17 passed the 3-reviewer panel, 2 withdrawn by spot panels)
| Miss | Fix / lesson |
|---|---|
| Diagonal smears on flat caps (stairs sides, spandrels, shelf tops) | Headless `shade_auto_smooth` does not feed WeightedNormal keep_sharp: mark `edge.smooth = False` by face angle in bmesh, then add the WeightedNormal modifier (kitlib `style="smooth_wn"`) |
| Non-manifold welds between touching boxes (walls, frames) | lf.cleanup welds coincident corners of separate parts: pull each part in by 6e-4 studs (`finalize(inset=)`) and keep cores from sharing corners |
| Z-fighting at modular ends | Never let two parts share an end plane over the same region: split the section by depth (blocks in front of y = 0.45, core behind) |
| Modular snapping | `lf.tile_check` / `lf.grid_check` (T1) + tools/kits/snap_check.py on the shipped .blends; first/last rows must share joints for Y tiling |
| Fused puff canopies / bushes stay at 6-7 | Radial smooth-union blobs on a UV grid read as "lumpy blob, grid faceting" whatever the colour scheme (4 rounds); pine as ONE lathe passed (8.7) |
| Organic plant parts (stump skirts, grass blades, petals, dead-tree branches) stuck at 6-7.7 | Single-shell lathe skirts read as "lampshade"; plugged-in branches read as unfused. Needs real fused topology (quad cage + subsurf), not more tuning |
## Buildings and houses (log cabin blind 8.0 + stone cottage helper test, 2026-10-29)
Stats: 1 blind-scored house (first 8.0, weighted from 14/18; maker re-score 16/18 unverified), 0 at 9 first try. Builders: `roblox-blender-modeling/scripts/lihfolk_house.py`; method: vault `House Construction Method - Modular Kit Workflow`.

**Defaults that win (first draft):**
- Scale from the avatar: door 3.6-4 x 7.5-8 studs, storey 10-12 studs to the eave, walls 1-1.4 thick (logs r 0.6), sill or plinth 0.5-0.9.
- Split by Roblox need: walls / roof / chimney / trim / glow / porch-door / base. Every module's origin is the whole building's bottom centre (`lh.recentre`).
- One roof function `lh.Gable(hx, eave_z, pitch)` drives the gable courses, the roof, the chimney base and the icicle seats. For block walls put hx on the outer face line.
- Pitch 45-50, overhang 1.4-1.9 eave and 1.2-1.65 gable; real openings snapped to course lines, plus lintels and sills.
- Budget per module, measured: walls 4.7-9.2k (building), roof 1.1-2.1k, trim 0.7-2.9k (medium), chimney about 0.75k, glow under 100.

**Pre-empt (missed on the first try):**
- A4: the soft bevel turns fan caps and box corners into n-gons. `lh.finish_modules` adds Triangulate (min_vertices 5, keep custom normals).
- Floating parts inside one module (icicles, knobs, firewood): the gate cannot see them. `lh.floating_shells` must report 0.
- A1 on block walls: count tris before modelling (blocks x about 44 tris after the bevel). Use longer blocks and taller courses, or split the walls into two modules.
- A5: parts thinner than 3x the bevel width collapse into degenerate faces. Keep bevel_width <= 1/3 of the thinnest part.
- Layout: frames and shutters running past the corner. Run `lh.check_wall_layout` and keep shutters for walls with room.
- V5: centre-to-rim end grain reads as "gradients on flat faces" to blind reviewers. Use two flat rings if the style bible says flat colour.
- V7: 13.4k tris over the building target. Use 8-sided logs, plank decks as one slab, and firewood as one block for villages.

| Miss | Fix |
|---|---|
| Gable logs or courses poke through or gap under the roof | Derive each course's half-length from `Gable.half_width_at(z_top)`, never by hand |
| Logs collide at corners | Offset the gable walls half a course; block walls alternate which wall runs through the corner |
| Dark squares at block-wall corners | Mortar core strips stop gap/2 + 0.03 behind the end blocks |
| Icicles hang in the air under the snow lip | Seat them from `roof["snow_under"](x)` just inside the lip, embedded 0.45 |
| Snow reads as a white board | Rounded chevron (`lc.round_corners` 0.75-1.1) with a 0.45 lip, coloured by normal (top, side, under) |
| Glowing windows but dark snow in game | Glass in its own module with Neon, plus real Surface or Point lights |
## Stylized creatures (Puffling, 2026-10-29: blind 8.33 -> 8.67 model PASS in 4 rounds; swim clip 5.0 -> 5.33, below bar)
Builder: `roblox-blender-modeling/scripts/lihfolk_creature.py` (SDF -> surface nets -> QuadriFlow -> half + mirror). Method: vault `Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs`.
| Miss | Fix / lesson |
|---|---|
| A17/A18 thin midline fins fold after projection | Fin half-thickness >= 0.6x quad edge; retry QuadriFlow seeds until 0 self-intersections (builder does it) |
| A2 open seam after the half-mirror | Snap every boundary vertex of the half to x = 0, not only those within a tolerance |
| V5 dark disc around the eyes | AO bake sees the lens shells: fade AO by an eye-near weight (1 - 0.9 w) |
| V5 seam down a forked tail | Two overlapping fin parts: blend paint coordinates by soft-min weights, or build one fan fin with a carved notch |
| V5 block of fin colour on the body | Smart UV Project folded a cluster (spine at a fin root): count UV overlaps, remove the cause |
| V1 front view "plain disc", "rabbit ears" | Splay paired fins forward/out so they pass the head outline; median fins low, broad, swept back |
| V8 blurry painted look | Mirrored overlapping UVs (texel 168 -> 210 px/stud), 3-step banded top light, tinted AO |
| Animation P2/P3 stuck at 1 | Tail1/Tail2 inside a round body hide the wave; give a visible tail stalk (>= 25 % of length), holds at extremes; review with onion skins |
