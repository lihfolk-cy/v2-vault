---
tags: [modeling, curves, bezier, splines, catmull-rom, b-spline, nurbs, continuity, curvature, silhouette, blender, animation]
---
# Bezier Curves and Splines for Modellers

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Stepping `t` evenly -> Resample by arc length
> - Avoid: Uniform Catmull-Rom on uneven points -> Centripetal (`alpha = 0.5`)
> - Avoid: Catmull-Rom for a hero sweep -> B-spline (C2), or more evenly spaced points
> - Each main silhouette line has a planned number of inflections (0 or 1 for props).
> - The tightest curvature sits where the eye should go.
> - Hero curves are G2 (B-spline or G2 blends); pipes and mechanical parts may stay G1 arcs.
>
> Read more (20 KB note): ## 2. Splines: chains of curves with rules · ## 3. Continuity: G and C, and why it shows · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Curves are how a modeller says "this shape flows": a blade edge, a horn spiral, a pipe run, a logo, the S of a character's pose, the ease of a keyframe. This note is the theory a modeller actually uses: what a Bezier curve is and why its handles behave as they do, how Catmull-Rom, B-splines, NURBS and Hermite curves differ, what G0/G1/G2 continuity means and why it shows in highlights, how to read curvature and spot kinks, and how the same maths drives Blender's F-curves. The Blender build side is in [[Curve-Based Modelling in Blender for Roblox]]; the Luau side is in [[Curves in Luau - Paths Beams and Motion]]; the gameplay-maths view (easing, arc-length tables) is in [[Interpolation Easing and Curves Math]].

Trust labels: **Measured** (run in headless Blender 5.2 with `lihfolk_curves.py`, October 2026), **Docs** (Blender or Roblox documentation), **Source** (paper or reference named in Sources), **Rule of thumb**, **Unverified**.

---

## 1. Bezier curves in one page

A Bezier curve is defined by control points. It starts on the first, ends on the last, and is pulled toward (but generally does not touch) the ones in between.

| Degree | Points | Shape it can make | Where you meet it |
|---|---|---|---|
| Linear | 2 | A straight segment | Poly curves, edges |
| Quadratic | 3 | One smooth bend, no S | Fonts (TrueType), simple arcs, cable sag |
| Cubic | 4 | A bend or an S-curve | Blender Bezier curves, F-curves, Roblox `Beam`, Roblox `Path2D`, SVG, Illustrator |

**De Casteljau: lerps of lerps.** To find the point at parameter `t` (0 to 1), lerp between each neighbouring pair of control points by `t`, then lerp those results, until one point remains (Source: Pomax primer, Wikipedia). It is numerically stable and works for any degree. The same construction does two more jobs:

- **Splitting.** The first point of every row of the construction forms the control points of the left half; the last point of every row forms the right half. Two halves, same degree, identical shape (Source: Pomax primer; Measured: split halves match the original to float precision).
- **Tangent.** The last lerp's two points lie on the tangent line at `t`.

**Bernstein form** is the same curve written as a weighted sum. For a cubic: `B(t) = (1-t)^3 P0 + 3(1-t)^2 t P1 + 3(1-t) t^2 P2 + t^3 P3`. The weights are always positive and sum to 1, which gives the properties modellers rely on:

1. **Convex hull.** The curve stays inside the polygon of its control points. The control points' bounding box is therefore a safe (loose) bounding box.
2. **Ends are exact.** `B(0) = P0`, `B(1) = P3`.
3. **Handles are tangents.** The derivative at the start is `3 (P1 - P0)` (Measured). Handle direction is the tangent direction; handle length is one third of the curve's speed there. Long handles mean the curve leaves the point fast and travels further before turning.
4. **Affine invariance.** Moving, rotating or scaling the control points moves the curve exactly the same way, so you can transform the cage instead of the curve.

**Tight bounding boxes.** The loose box is the control hull. The tight box comes from solving where each coordinate's derivative is zero (a quadratic for a cubic curve), then taking min and max over those points and the two ends (Source: Pomax primer; Measured: matches a 2,000-sample brute force to 1e-4).

**Circles are not Bezier curves.** A cubic can only approximate an arc. The best handle length for an arc of angle `a` and radius `r` is `4/3 * tan(a/4) * r`, which is about `0.5523 r` for a quarter circle. Four such quarters make a circle that is visually perfect at game scale (rule of thumb). The same constant sets Roblox `Beam.CurveSize` for arcs ([[Beams and Trails]]).

### Arc length and even spacing

Stepping `t` evenly does **not** step evenly along the curve. Points bunch where handles are short and spread where they are long. For modelling that means uneven ring spacing on a sweep (visible shading bands and wasted triangles); for gameplay it means a camera that speeds up and slows down.

The fix is reparameterisation by arc length: sample the curve finely, record cumulative length, then look up the `t` for each wanted distance. Blender's Resample Curve node does this for you in Count and Length modes (Docs). `lihfolk_curves.resample()` does it in scripts (Measured: 30 resampled points vary in spacing by under 5 percent on a deliberately uneven Catmull-Rom).

---

## 2. Splines: chains of curves with rules

One cubic rarely covers a whole shape. A spline is a chain of pieces plus a rule for how the pieces meet.

| Spline | Passes through the points? | Smoothness at joins | Best for |
|---|---|---|---|
| **Bezier chain** (Blender Bezier curve) | Through anchors, not handles | Whatever the handles say (corner to G1) | Hand-drawn shapes, logos, F-curves |
| **Hermite** | Yes | You supply a tangent per point | Motion between known states, retargeting a move mid-flight |
| **Catmull-Rom** | Yes, every point | C1 (tangents match; curvature can step) | Paths through placed points: rails, cameras, patrols |
| **Uniform cubic B-spline** | No, it approximates them | C2 (curvature continuous) | Sweeps, silhouettes, anything that must shade smoothly |
| **NURBS** | Only where knots or weights force it | Set per knot (C2 by default for cubic) | Exact circles and conics, CAD-style surfaces |

### Hermite and Catmull-Rom

A cubic Hermite segment is two points plus two tangents. A Catmull-Rom spline is a Hermite spline that invents the tangents from the neighbours, so designers only place points. Converting a Catmull-Rom segment to a Bezier is mechanical: in the uniform case each handle is the neighbour-to-neighbour vector divided by 6 (Source: Pomax primer section on Catmull-Rom; Measured in the Luau note's beam builder).

The **parameterisation** matters. Knot spacing grows with the distance between points raised to `alpha`:

- `alpha = 0`, uniform: simplest, but overshoots and can form loops and cusps when points are unevenly spaced.
- `alpha = 0.5`, **centripetal**: proven to have no cusps and no self-intersections within a segment (Source: Yuksel, Schaefer and Keyser 2011). Make this your default.
- `alpha = 1`, chordal: hugs the control polygon even more, with wider swings on long segments.

Two limits worth knowing. The guarantee is per segment; separate segments can still cross each other. And Catmull-Rom is only C1: curvature can jump at every control point (Measured: a horn spiral through 12 points scored 3 curvature jumps near its tight tip with centripetal Catmull-Rom, and 0 with a B-spline through the same points).

### B-splines

A uniform cubic B-spline is built from overlapping cubic pieces whose blending functions guarantee C2 continuity everywhere: position, tangent and curvature all match at every join. The price is that it does not pass through the inner control points; it shrinks toward them (Measured: the B-spline horn curls tighter than the Catmull-Rom one through the same points). Moving one point only changes the four pieces it touches (local control). Repeat an end point three times to pin the curve to it.

Use it when the **shading** of the result matters more than hitting exact points: horns, tentacles, swept handles, hoses, leaf midribs, body silhouettes.

### NURBS: what the extra letters buy

NURBS (Non-Uniform Rational B-Splines) add two things to B-splines:

1. **Weights (the "rational" part).** Each control point can pull harder or softer. With the right weights a NURBS curve is an **exact** circle, ellipse or other conic, which polynomial splines can only approximate (Source: Blender API curve docs, Geometric Tools). The classic quarter circle is a quadratic with control points at (1,0), (1,1), (0,1) and the middle weight `sqrt(2)/2`.
2. **Knot vectors (the "non-uniform" part).** A nondecreasing list of parameter values controls where pieces start and how smoothly they join. Repeating a knot lowers continuity at that spot (a deliberate crease) and lets a NURBS curve reproduce Bezier pieces exactly.

For Roblox work NURBS are a modelling convenience. Everything leaves Blender as triangles, so "exact circle" only matters until export; what survives is the shape and how evenly you sample it.

---

## 3. Continuity: G and C, and why it shows

Two curves (or surfaces) meeting at a point can match at several levels.

| Level | Geometric (G) meaning | What you see on a smooth-shaded model |
|---|---|---|
| **G0** | Same position, any angle | A crease or corner. Reflections break |
| **G1** | Same tangent direction | No crease, but a highlight changes width suddenly: a visible "band" |
| **G2** | Same curvature too | Highlights flow across the join; it reads as one designed surface |
| **G3** | Same rate of curvature change | Removes faint highlight wobble on large glossy panels |

**C** continuity is the parametric version: C1 requires the derivative vectors to match exactly (direction **and** length), C2 the second derivatives. G is what the eye sees; C is what animation and constant-speed motion feel. A Blender Bezier node with Aligned handles of different lengths is G1 but not C1: the shape is smooth but an object moving along it changes speed at the node.

**Why G2 reads as premium.** Product and automotive "Class A" surfacing demands curvature continuity because light reflected across a G1 joint changes width abruptly where curvature differs on the two sides, and a trained eye reads that as cheap (Source: industrial-design references and McNeel forum, see Sources; this is industry convention, not a measured standard). The same effect exists in a game engine: vertex normals interpolate across faces, so a sudden change in curvature becomes a sudden change in how fast the normal turns, which is a visible shading edge.

**What survives at Roblox budgets (rule of thumb).** A 2,000-triangle prop cannot literally be G2; it is flat polygons. What carries over:

1. **Silhouette curvature.** Outlines where the radius changes gradually read as designed. Outlines that go straight, then suddenly round, then straight read as "rounded rectangle tool". This is visible at any triangle count.
2. **Ring spacing that follows curvature.** Put rings where the curve bends; few on straights. Even rings on an uneven curve give the banding you were trying to avoid.
3. **Hard-surface bevels can stay G1.** A one-segment bevel plus weighted normals ([[Clean Stylised Shading - Weighted and Custom Normals]]) is the efficient stylised answer. Spend G2 where the eye lingers: blade edges, guards, hero silhouettes, logos, vehicle bodies.

### Rounding a corner: arc fillet versus G2 blend

Rounding a polyline corner is the most common curve operation in modelling. Two ways, measured on a 90 degree corner with legs of 3 studs and radius 1 (`lihfolk_curves.round_corners`):

| Method | Continuity with the straights | Curvature jumps found | Tightest radius |
|---|---|---|---|
| Circular arc fillet (Blender Fillet Curve, bevel) | G1 | 2 (one at each join) | 0.93 (should be 1.0, sampling) |
| Cubic with both handles on the corner (A, C, C, B) | G2 | 0 | 0.27 with the same setback |
| Quintic, inner points at 1/3 and 2/3 of each leg | G2 | 0 | 0.74 with the same setback; 0.94 with a 1.35x setback |

(Measured, 400-sample curvature analysis.) Two lessons:

- **A G2 corner needs a longer run-up.** For the same setback a G2 blend is tighter at its apex than an arc, because the curvature has to start from zero. Give it about 1.35 times the arc's setback to read as the same size. The helper does this automatically.
- **The obvious cubic G2 trick pinches.** Putting both cubic handles on the corner is G2 on paper but concentrates the bend into a sharp apex. The quintic spreads it evenly. Pipe elbows should stay arcs (that is what real elbows are); blades, guards, badges and logos look better with the G2 blend.

---

## 4. Curvature, combs and fairness

**Curvature** is how fast the curve turns: 1 divided by the radius of the circle that best fits it at that point. For a planar curve it is `(x' y'' - y' x'') / (x'^2 + y'^2)^1.5` (Source: Pomax primer).

A **curvature comb** draws a spike perpendicular to the curve at many points, its length proportional to curvature (Source: Rhino CurvatureGraph documentation and tips). Reading it:

- **Even, gradually changing comb:** fair curve.
- **Comb crosses the curve:** an inflection, where the bend changes side.
- **Comb jumps in height at a join:** G1 only. Direction and height both continuous: G2.
- **Ripples or oscillation:** too many control points, or points pulling against each other. The surface will show wobbly highlights.

Fairness is loosely defined even among naval architects (Source: McNeel fairing tutorial), so treat any score as a review aid, not a law. `lihfolk_curves.fairness()` reports kinks (G0 corners), curvature jumps (G1 joins) and inflections, using three-point curvature over a window at least twice the polyline's facet length and a two-window test (a real step measures the same at both window sizes; a steep but smooth ramp halves). Measured results:

| Curve | Kinks | Curvature jumps | Inflections |
|---|---|---|---|
| Hard 90 degree corner | 1 | 0 | 0 |
| Same corner, arc fillet | 0 | 2 | 0 |
| Same corner, quintic G2 blend | 0 | 0 | 0 |
| Cubic S-curve | 0 | 0 | 1 |
| Horn spiral, centripetal Catmull-Rom | 0 | 3 | 2 |
| Horn spiral, B-spline | 0 | 0 | 0 |

### Inflections are a design decision

Designers avoid kinks they did not mean and wobbles they did not plan, but they use inflections deliberately. Character artists build poses on a **line of action** made of C-curves (compression, weight), S-curves (rhythm, twist) and straights (structure, reach), and play **straights against curves** for contrast; they also warn against compound "W or M" lines that fight the flow (Source: line-of-action and "Straights and Curves" references). The modelling translation, as rules of thumb:

- **Count the inflections on every main silhouette line.** Props: 0 or 1. A blade edge with two inflections looks bent, not designed. A character's main gesture: one S.
- **Put the tightest curvature where you want the eye**: the tip of a horn, the hook of a guard, the point of a blade. Logarithmic spirals (radius shrinks by a constant ratio per turn) are the natural shape for horns, shells and swirls because curvature rises smoothly toward the tip.
- **Pair every curve with a straight.** A scimitar reads because the spine is calmer than the edge. A leaf reads because the stem is straight. See [[Shape Language and Silhouette Testing]].

---

## 5. The same maths in the Graph Editor

Blender F-curves are 2D cubic Bezier chains with time on X and value on Y. Everything above applies (Docs, Blender manual; rule of thumb for the advice):

| Handle type | Continuity | Animation use |
|---|---|---|
| **Auto** | Smooth (like Catmull-Rom) | Quick blocking; can overshoot between keys |
| **Auto Clamped** | Smooth, flat at extremes | The safe default: no overshoot past a key's value |
| **Vector** | Corner (G0) | Hard stops, impacts, mechanical snaps |
| **Aligned** | G1 | Hand-tuned ease that stays smooth |
| **Free** | Anything | Deliberate breaks in rhythm |

- **Handle length is ease.** A long handle leaving a key means the value hangs near the key before moving: an ease out. Short handles mean a sharp start.
- **Overshoot is a handle reaching past the next key's value.** Auto handles do this; Auto Clamped prevents it at extremes. When you want overshoot (a settle, a bounce), add it as a key or use the Back easing mode with its overshoot amount, so it is visible and tunable.
- **Speed at a key is the handle slope.** G1-but-not-C1 handles at a key (aligned, different lengths on each side) change the speed of motion at that frame; on a camera move that reads as a hitch.

How Roblox's own easing differs from Blender's, and how the LihFolk pipeline bakes curves into keyframes, is covered in [[Keyframes, Easing and Interpolation]] and [[LihFolk R15 Keyframe Pipeline]]. Roblox also has a native curve-channel animation format: [[CurveAnimation and Curve Channels]].

---

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Stepping `t` evenly | Uneven ring spacing, shading bands, speed changes | Resample by arc length |
| Uniform Catmull-Rom on uneven points | Loops or cusps at tight corners | Centripetal (`alpha = 0.5`) |
| Catmull-Rom for a hero sweep | Faint highlight steps at each control point | B-spline (C2), or more evenly spaced points |
| Arc fillets on a blade or logo | Rounded-rectangle look, highlight band at each join | G2 blend with about 1.35x the setback |
| Cubic A, C, C, B as a "G2 corner" | Pinched apex, much tighter than intended | Quintic blend (inner points at 1/3 and 2/3 of each leg) |
| Too many control points | Wobbly comb, lumpy silhouette | Fewest points that hold the shape; check inflections |
| Expecting control points on the curve | B-spline or NURBS "misses" the point | Use Catmull-Rom or Bezier anchors when hits matter |
| Auto handles on extreme keys | Animation overshoots past the pose | Auto Clamped, or add the overshoot as an explicit key |

## Checklist

- [ ] Each main silhouette line has a planned number of inflections (0 or 1 for props).
- [ ] The tightest curvature sits where the eye should go.
- [ ] Hero curves are G2 (B-spline or G2 blends); pipes and mechanical parts may stay G1 arcs.
- [ ] Paths through placed points use centripetal Catmull-Rom.
- [ ] Anything sampled for geometry or motion is resampled by arc length.
- [ ] A curvature check shows no unplanned kinks or jumps (`lihfolk_curves.fairness`).
- [ ] F-curves use Auto Clamped by default; overshoot is explicit.

## Sources

- Pomax, "A Primer on Bezier Curves": https://pomax.github.io/bezierinfo/
- De Casteljau's algorithm: https://en.wikipedia.org/wiki/De_Casteljau%27s_algorithm
- Yuksel, Schaefer, Keyser, "Parameterization and applications of Catmull-Rom curves" (2011): https://www.sciencedirect.com/science/article/abs/pii/S0010448510001533 ; overview at https://en.wikipedia.org/wiki/Centripetal_Catmull%E2%80%93Rom_spline
- Wang, Juttler, Zheng, Liu, "Computation of rotation minimizing frames" (2008): https://www.microsoft.com/en-us/research/wp-content/uploads/2016/12/Computation-of-rotation-minimizing-frames.pdf
- NURBS weights and exact circles: https://www.geometrictools.com/Documentation/NURBSCircleSphere.pdf
- Continuity and Class A surfaces: https://pshdesign.com/understanding-class-a-modeling/ , https://discourse.mcneel.com/t/distinguish-between-one-surface-and-two-surface-with-g2-continuity-in-car-surface/31616
- Curvature combs and fairness: https://novedge.com/blogs/design-news/rhino-3d-tip-validate-curve-quality-with-curvaturegraph-for-g2-g3-continuity , https://docs.mcneel.com/rhino/6/usersguide/en-us/html/ch-16_boathull.htm
- Line of action and straights against curves: https://www.brianlemay.com/Drawingcourse/StraightsandCurves.html , https://poselibrary.com/csi-method-c-curves-s-curves-straight-lines

## See also

[[Curve-Based Modelling in Blender for Roblox]] · [[Curves in Luau - Paths Beams and Motion]] · [[Interpolation Easing and Curves Math]] · [[Shape Language and Silhouette Testing]] · [[Hard-Surface Modeling]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Topology and Edge Flow]] · [[Keyframes, Easing and Interpolation]] · [[Posing and Silhouettes]] · [[Beams and Trails]]

## Connected notes
<!-- auto-links:start -->
[[Modeling Weapons and Props]] · [[Organic and Creature Modeling]] · [[Low-Poly and Stylized Modeling]] · [[Stylised Weapons From a Concept]] · [[CurveAnimation and Curve Channels]] · [[Easing]]
<!-- auto-links:end -->
