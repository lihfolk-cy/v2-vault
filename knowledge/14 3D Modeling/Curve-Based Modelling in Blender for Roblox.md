---
tags: [modeling, blender, curves, bezier, sweep, lathe, geometry-nodes, python, budgets, triangles, roblox, props, weapons, vfx]
---
# Curve-Based Modelling in Blender for Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: High Resolution U on long straights -> Split segments or resample adaptively
> - Avoid: Bevel Resolution 4 "for smoothness" -> 0 to 1 for distant tubes, 2 for hand-held
> - Avoid: Frenet or Z-Up twist on a 3D path -> Minimum twist / rotation-minimising frames
> - The path is checked with `fairness()`: no unplanned kinks, jumps or extra inflections.
> - Profile point count matches viewing distance (6 / 8 / 12 / 16).
> - Rings follow curvature; straights carry one ring at each end.
>
> Cost: TL;DR ~160 tok · whole note ~5.0k tok. Read more: ## 6. The LihFolk helper module · ## 7. Worked samples (measured) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Many of the best-looking stylised props are a curve with a cross-section: a sword blade, a horn, a pipe run, a cable, a tentacle, a branch, a VFX swirl, a lathed potion bottle, a bevelled badge. Blender offers four ways to build them (curve objects, Geometry Nodes, modelling tools like Spin and Screw, and Python), and every one of them can quietly spend thousands of triangles on straight sections nobody looks at. This note covers each route, what it costs in triangles (measured), how to keep the result inside Roblox budgets, and the LihFolk helper module `lihfolk_curves.py` that builds these shapes from a script and checks them against the house gate. The underlying maths (Bezier handles, splines, continuity, curvature) is in [[Bezier Curves and Splines for Modellers]].

Trust labels: **Measured** (headless Blender 5.2, October 2026, `tools/curves/test_lihfolk_curves.py`), **Docs** (Blender 5.2 manual), **Rule of thumb**, **Unverified**.

---

## 1. Pick the route

| Route | Best for | Watch out for |
|---|---|---|
| **Curve object** with bevel | Quick cables, rails, rope, hand-tweaked tubes | Uniform resolution wastes triangles on straights; one round profile unless you use a bevel object |
| **Geometry Nodes** (Curve to Mesh and friends) | Procedural, parameterised assets, kit variations | Non-destructive until applied; check the evaluated triangle count |
| **Spin / Screw** | Lathed shapes, springs, threads, spiral stairs | Screw needs enough steps per turn; Spin duplicates the seam unless merged |
| **Python** (`lihfolk_curves`) | Repeatable builds, budget-aware sweeps, profile changes along the path, batch assets | You maintain the script |
| **Simple Deform** on a straight mesh | Bending, tapering or twisting a modelled part | Needs enough edge loops along the bend axis; origin and axis decide everything |

A good habit: draft with a curve object or Geometry Nodes to find the shape, then rebuild it as a script when it is going to be used more than once.

---

## 2. Curve objects: what each setting costs

Blender curve objects come in Bezier, NURBS and Poly types. The Geometry panel turns them into tubes (Docs):

- **Bevel Depth** with mode **Round** sweeps a circle; **Object** uses another curve as the cross-section; **Profile** uses a custom profile widget.
- **Bevel Resolution** adds points to the round profile.
- **Resolution U** sets how many evaluated points each Bezier segment gets, uniformly, whether the segment bends or not.
- **Radius** per control point (Alt+S in Edit Mode) scales the profile: taper without a taper object.
- **Taper Object** scales the profile along the length from another curve; **Taper Radius** mode decides whether it overrides, multiplies or adds to the point radius.
- **Twist Method** picks how the profile is oriented: **Z-Up**, **Minimum** (rotation-minimising, the one to use for 3D paths) or **Tangent**. **Tilt** (Ctrl+T) adds deliberate roll.
- **Fill Caps** closes the ends.

**Measured cost.** A 3-point Bezier curve (2 segments), bevel depth 0.2, fill caps on, converted to mesh:

| Bevel Resolution | Resolution U 4 | Resolution U 12 |
|---|---|---|
| 0 | 68 tris | 196 tris |
| 1 | 104 | 296 |
| 2 | 140 | 396 |
| 4 | 212 | 596 |

The numbers fit a simple rule: the round profile has `4 + 2 * bevel_resolution` points, there are `segments * resolution_u + 1` rings, and triangles are `2 * profile * (rings - 1)` plus the caps (Measured: every cell matches). Two consequences:

1. **Bevel resolution is a multiplier on the whole length.** Going from 0 to 4 triples the cost of every inch of tube. For a cable seen at gameplay distance, 6 profile points (resolution 1) is usually enough (rule of thumb).
2. **Resolution U is spent evenly.** A long straight segment gets as many rings as a tight bend. Either split the curve so straight runs are single segments with low resolution, or resample adaptively (section 5).

Convert with Object > Convert > Mesh before export, then run the gate. Curves exported directly can carry hidden settings into the triangle count.

---

## 3. Geometry Nodes curve recipe

The Geometry Nodes curve set mirrors the curve object but is non-destructive and parameterisable (Docs):

1. **Curve primitive or input curve** (Bezier Segment, Spiral, Arc, or an object's curve).
2. **Fillet Curve** rounds corners at control points with circular arcs. Bezier mode adds two points per corner; Poly mode uses a per-corner count. Turn on **Limit Radius** so neighbouring fillets cannot overlap.
3. **Resample Curve** in **Length** mode makes evenly spaced points; Count mode for a fixed number.
4. **Set Curve Radius** for taper (a Float Curve node driven by Spline Parameter > Factor gives a designable taper).
5. **Set Curve Tilt** for twist.
6. **Curve to Mesh** with a profile curve (Curve Circle with a low resolution, or any closed curve). Turn on **Fill Caps** for watertight ends; they come out as n-gons, so triangulate before export.
7. **Realize Instances**, then **Triangulate** or leave quads (Roblox triangulates on import).

Fillet Curve makes **arcs**, which are G1: fine for pipes and rails. For blade and logo outlines where you want G2 corners, build the outline in Python (section 5) or bake the fillet and adjust handles by hand.

---

## 4. Modelling tools that are secretly curves

- **Spin** (Edit Mode) revolves selected geometry around the 3D cursor: a lathe. Draw the half-profile of a vase as a vertex chain, spin 360 degrees with 12 to 20 steps, merge by distance at the seam.
- **Screw modifier** revolves with an offset along the axis: springs, screw threads, spiral staircases, drill bits. Steps per turn sets the triangle cost directly.
- **Simple Deform** bends, tapers, twists or stretches a mesh about the object's origin and a chosen axis. Model a straight blade or branch with enough edge loops along its length, then bend it. Too few loops give a polygonal bend; the loop count is your curve resolution.
- **Subdivision Surface vs bevel.** Subdivision with support loops makes very smooth curvature, but each level multiplies faces by four (Docs: one level splits each quad into four). On Roblox that cost is rarely worth it: use subdivision as a modelling step to find a shape, then apply and reduce, or use a limited bevel plus weighted normals ([[Hard-Surface Modeling]], [[Bevels Chamfers and Edge Highlights Without Textures]]).

---

## 5. Budget-aware curve meshes

A curve mesh costs `profile points x rings x 2` triangles, plus caps. Every saving comes from one of those three numbers.

**Profile points.** The biggest multiplier. Practical counts (rule of thumb, consistent with the measured assets below): 6 for cables and VFX ribbons, 8 for small tubes and stems, 12 for pipes, horns and handles in the player's hand, 16 to 18 for lathed hero pickups. A flat lens profile (6 points) is enough for leaves and ribbons because the eye reads their outline, not their roundness.

**Rings: put them on bends, not straights.** `lihfolk_curves.adaptive_stations()` walks the curve and drops a ring whenever the accumulated turning angle passes a threshold, the radius or twist changes by more than a tolerance, or the cross-section changes shape. Straights get one ring at each end. Measured on the pipe run below: 37 rings and 888 triangles. Uniform rings at the same bend quality would need about 70 rings, roughly 1,700 triangles by the formula (estimate).

**Caps and tips.** A tip that tapers to a point should end on a single pole vertex, not a tiny ring with a cap: it saves a ring and avoids slivers. Caps should be triangle fans, never n-gons (the LihFolk gate rejects n-gons).

**Hard steps need extra rings.** A flange or collar is a sudden radius change; put rings just before and after it (`features=` in `sweep`) so the step is crisp instead of a cone.

**Frames: avoid the twist flip.** A sweep needs a "which way is up" frame along the path. The textbook Frenet frame follows the curve's bend and flips when the curve straightens, which twists the mesh. Rotation-minimising frames (Blender's **Minimum** twist method; double reflection in the helper) carry the frame along with no unnecessary roll (Source: Wang, Juttler, Zheng and Liu 2008). On closed loops the frame does not quite meet itself; spread the leftover roll evenly so the seam matches.

---

## 6. The LihFolk helper module

`skills/roblox-blender-modeling/scripts/lihfolk_curves.py` sits next to `lihfolk_bpy.py` and imports its class budgets. Every builder returns a single watertight mesh object with quads and triangle-fan caps, one UV map inside 0 to 1, and normals facing out. It estimates triangles before building; with `auto_fit=True` it coarsens the ring spacing until the estimate fits the class ceiling, otherwise it raises `BudgetError`.

| Function | Does |
|---|---|
| `bezier_eval`, `bezier_deriv`, `bezier_split`, `bezier_bbox`, `bezier_path` | Bezier maths of any degree; tight bounding box for cubics |
| `catmull_rom(points, alpha=0.5)` | Through every point; centripetal by default |
| `bspline(points)` | C2 curve near the points: smoothest shading for sweeps |
| `resample(pts, count or spacing)` | Even spacing by arc length |
| `round_corners(pts, r, mode="arc" or "g2")` | Pipe-elbow arcs or curvature-continuous blends |
| `helix`, `circle`, `ellipse`, `lens`, `rounded_rect` | Paths and cross-sections |
| `fairness(pts)`, `fairness_score(report)` | Kinks, curvature jumps and inflections of a curve |
| `rmf_frames` | Rotation-minimising frames |
| `adaptive_stations`, `estimate_sweep_tris` | Ring placement and triangle estimate |
| `sweep(name, path, profile, radius, twist, ...)` | Tubes, horns, blades, leaves, ribbons; profile may change along the path |
| `lathe(name, profile_rz, steps)` | Bottles, vases, pillars, mushrooms, grips |
| `extrude_outline(name, outline, depth, bevel, bevel_segs)` | Signs, badges, guards, flat blades, logos |
| `join`, `deform`, `set_color`, `curve_object`, `measure_curve_tris` | Utilities |

A pipe, end to end:

```python
import sys; sys.path.append(r"<plugin>/skills/roblox-blender-modeling/scripts")
import lihfolk_bpy as lf, lihfolk_curves as lc
from mathutils import Vector

lf.setup_scene()
run = [Vector(p) for p in [(0, 0, 0), (0, 0, 2.5), (3.5, 0, 2.5), (3.5, 2.8, 2.5)]]
path = lc.round_corners(run, 0.7, "arc")           # real elbows are circular arcs
info = {}
pipe = lc.sweep("Pipe_Run", path, lc.circle(12), radius=0.26,
                max_turn_deg=15, cls="medium", report=info, color=(0.35, 0.55, 0.62))
print(info)                                         # tris_estimate, stations, length
lf.finish(pipe, style="smooth", smooth_angle=35)
lf.set_origin(pipe, "bottom")
print(lf.gate(pipe, "medium")[:2])                  # (True, [])
```

A cross-section that changes along the path (a blade whose fuller fades out near the tip) is a function of `s`, the normalised distance along the path, returning the same number of 2D points every time:

```python
def blade_section(s):
    width = 0.5 * (1 - s ** 3)
    half_t = 0.08 * (1 - 0.5 * s) + 0.003
    groove = half_t * 0.7 * (1 if 0.1 < s < 0.5 else 0)   # use a smoothstep in real builds
    return [(-width, 0), (0, -half_t + groove), (0.18, -half_t), (0.18, half_t), (0, half_t - groove)]

blade = lc.sweep("Blade", path_points, blade_section,
                 radius=lambda s: 0.0 if s > 0.9999 else 1.0,   # 0 at the end = pointed tip
                 up=(0, 1, 0), max_turn_deg=4, cls="weapon")
```

Check a curve before you sweep it:

```python
rep = lc.fairness(path_points)
print(rep["kinks"], rep["curvature_jumps"], rep["inflections"], lc.fairness_score(rep, expected_inflections=0))
```

---

## 7. Worked samples (measured)

Seven assets built by `tools/curves/test_lihfolk_curves.py`, each finished with smooth-by-angle shading (35 degrees), origin at the bottom, and run through `lihfolk_bpy.gate()`. All seven pass. Renders are in `tools/curves/renders/`.

| Asset | Built from | Class | Tris | Notes |
|---|---|---|---|---|
| Curved sword | Blade: Bezier spine, 15-point section with a fading fuller, pole tip. Guard: G2-rounded crescent outline, extruded with a 2-segment bevel. Grip: lathe | weapon | 1,446 | Blade alone is 510; target 2,500 |
| Ram horn | B-spline through a logarithmic spiral, 12-point ellipse, tapering radius with growth ridges | medium | 1,008 | 43 rings; ridges forced rings via the radius tolerance |
| Pipe run | Right-angle polyline, arc fillets, collar steps at couplings | medium | 888 | 37 rings, half the uniform estimate |
| Potion bottle | Centripetal Catmull-Rom body profile plus crisp lip and cork, lathed 16 steps, simplified by turning angle | small | 928 | Over the 600 target, under the 1,500 ceiling; 12 steps would land near 700 |
| Stylised leaf | Sweep along a curling midrib, folded V lens section, stem blending into the blade | small | 368 | The fold gives a midrib crease for free |
| VFX swirl | Cone helix, 6-point lens ribbon turned on edge, tapering to points at both ends | small | 672 | Watertight, so it passes the gate without the foliage-card exception |
| Badge | Shield outline with G2 corners plus a raised star, both extruded and bevelled | small | 896 | Two shells in one mesh, one material |

### Before and after

Each sample was also built the way a typical first attempt looks: primitives placed by hand, no curve work, default flat shading, default n-gon cylinder caps. Both versions went through `render_review` with identical cameras and were scored with the model rubric (`skills/quality-score/rubrics/model.md`; a hard-gate failure caps the score at 5.0). Scores are the building agent's judgement from the four review renders (rule of thumb, not a blind review). Side-by-sides are in `LihFolk Asset Pack/Models/_compare/`.

| Asset | Before: tris, gate, score | After: tris, gate, score | Delta |
|---|---|---|---|
| Curved sword | 1,114, fail (n-gons), 4.0 | 1,446, pass, 8.3 | +4.3 |
| Ram horn | 270, fail (n-gons), 2.0 | 1,008, pass, 7.3 | +5.3 |
| Pipe run | 3,376, fail (n-gons), 3.0 | 888, pass, 8.3 | +5.3 |
| Potion bottle | 1,208, fail (n-gons), 3.7 | 928, pass, 7.3 | +3.6 |
| Stylised leaf | 1,084, fail (n-gons), 3.0 | 368, pass, 8.3 | +5.3 |
| VFX swirl | 1,152, pass, 3.0 | 672, pass, 6.7 | +3.7 |
| Badge | 28, fail (n-gons), 4.7 | 896, pass, 8.7 | +4.0 |

![[Pipe_Run_before_after.png]]

The pipe shows both halves of the lesson: the primitive version spends almost four times the triangles (dense spheres jammed on the corners) and still looks worse, while the swept version puts rings only on the bends and spends the savings on collars that make it read as plumbing.

![[Horn_Ram_before_after.png]]

The horn shows the other half: a chain of cylinders cannot fake a curve. Each joint is a kink (G0) and the overlapping ends show. One sweep along a smooth spiral is cheaper to author and reads at a glance.

Measured pattern across all seven: curve work did not always reduce triangles (the badge and horn went up because the before versions were too crude to be usable), but it never needed more than the class ceiling, and every after version passed the gate the befores failed.

What made them look right, in order of impact:

1. **The path's curvature, not the triangle count.** The horn reads as a ram horn because a logarithmic spiral tightens smoothly; the first version through a coarser spiral looked like a hook. The B-spline version also scored 0 curvature jumps where Catmull-Rom scored 3.
2. **Cross-sections that are not circles.** Lens sections for leaves and ribbons, a ground-edge section for the blade, an ellipse for the horn. A round tube is the fastest thing to script and the least often right ([[Stylised Weapons From a Concept]] learned the same lesson).
3. **Thickness that tapers with width.** The first sword tip kept its thickness while the width went to zero and rendered as a needle; scaling thickness by the same tip factor fixed it.
4. **Crisp steps where real objects have them.** Pipe collars and the bottle lip are hard steps with extra rings; everything else is smooth.
5. **Review renders from more than one side.** The horn's three-quarter view looked closed and odd; the side view showed a clean spiral. `render_review` gives front, three-quarter, top and silhouette for this reason.

---

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| High Resolution U on long straights | Thousands of triangles in a plain cable | Split segments or resample adaptively |
| Bevel Resolution 4 "for smoothness" | Every tube costs triple | 0 to 1 for distant tubes, 2 for hand-held |
| Frenet or Z-Up twist on a 3D path | The tube twists or pinches where the path straightens | Minimum twist / rotation-minimising frames |
| Fill Caps exported as n-gons | Gate fails A4; odd shading on caps | Triangulate, or build fan caps |
| Pointed tip made from a tiny ring | Slivers, shading spike at the tip | End on a single pole vertex |
| Width tapers but thickness does not | Needle or square-ended tip | Taper both together |
| Fillet arcs on a hero outline | Rounded-rectangle look | G2 blend (`mode="g2"`) |
| Simple Deform bend on few loops | Polygonal bend | Add loops along the bend axis first |
| Subdivision left on for export | Four times the faces per level | Apply and reduce, or bevel instead |
| Not reading the evaluated count | Over budget after export | `measure_curve_tris`, `lf.qa_mesh` before export |

## Checklist

- [ ] The path is checked with `fairness()`: no unplanned kinks, jumps or extra inflections.
- [ ] Profile point count matches viewing distance (6 / 8 / 12 / 16).
- [ ] Rings follow curvature; straights carry one ring at each end.
- [ ] Tips end on poles; caps are triangle fans.
- [ ] Twist uses rotation-minimising frames; closed loops have a matching seam.
- [ ] Hard steps (collars, lips) have rings on both sides.
- [ ] Triangle estimate is printed before the build and fits the class.
- [ ] `lf.finish`, `lf.set_origin`, `lf.gate` pass; review renders checked from every view.

## Sources

- Blender manual, Curve to Mesh: https://docs.blender.org/manual/en/latest/modeling/geometry_nodes/curve/operations/curve_to_mesh.html
- Blender manual, Resample Curve: https://docs.blender.org/manual/en/latest/modeling/geometry_nodes/curve/operations/resample_curve.html
- Blender manual, Fillet Curve: https://docs.blender.org/manual/en/latest/modeling/geometry_nodes/curve/operations/fillet_curve.html
- Blender manual, Set Curve Radius: https://docs.blender.org/manual/en/latest/modeling/geometry_nodes/curve/write/set_curve_radius.html
- Blender Python API, Curve (bevel modes, resolution): https://docs.blender.org/api/current/bpy.types.Curve.html
- Rotation-minimising frames: https://www.microsoft.com/en-us/research/wp-content/uploads/2016/12/Computation-of-rotation-minimizing-frames.pdf

## See also

[[Bezier Curves and Splines for Modellers]] · [[Curves in Luau - Paths Beams and Motion]] · [[Blender Workflow for Roblox Creators]] · [[Modeling Weapons and Props]] · [[Hard-Surface Modeling]] · [[Mesh Optimization for Mobile]] · [[Spending Triangles Where the Camera Looks]] · [[Mesh VFX Packs Built in Blender]] · [[Stylised Weapons From a Concept]] · [[Blender 5 Python Gotchas for Headless Builds]] · [[Exporting and Validating Models for Roblox]]

## Connected notes
<!-- auto-links:start -->
[[Blender Automation with Python]] · [[Low-Poly Tree Set Worked Example]] · [[Organic and Creature Modeling]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Procedural Blender Assets Start Here]] · [[Topology and Edge Flow]]
<!-- auto-links:end -->
