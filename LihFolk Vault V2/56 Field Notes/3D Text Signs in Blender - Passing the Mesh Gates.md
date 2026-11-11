---
tags: [field-notes, blender, modeling, text, signs, mesh-gates, import, type/guide, area/art, level/intermediate, area/modeling]
---
# 3D Text Signs in Blender - Passing the Mesh Gates

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Exporting converted text as is -> Merge by distance after converting
> - Avoid: Leaving cylinder caps and sphere poles -> Triangulate faces with more than 4 corners
> - Avoid: Thick offset outline on small or sharp glyphs -> Thinner offset (about 3.8% of size); no outline on small text
> - Text converted to mesh (a curve doesn't export).
> - `resolution_u` set (about 5) before converting.
> - Clean-up pass run on every part before the join.
>
> Cost: TL;DR ~150 tok · whole note ~1.5k tok. Read more: ## The four traps · ## The clean-up pass · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Chunky 3D letters are the quickest way to make a lobby sign, title arch or "PLAY" gate stand out, and Blender's text object makes them in one line. The converted mesh then fails most of the hard gates in [[Mesh Gates for Generated Models - Symmetry, Seating and Caps]]: open caps, n-gons, self-intersecting bevels and folded outlines. Roblox still renders it, so nobody notices until a gate or a close-up does. This note lists the four traps and a clean-up pass that made every piece of two text-heavy gates pass, then gives the numbers.

Source labels: **Measured** (a stylised title gate and "PLAY" gate built for a Roblox party game in November 2026, checked with the LihFolk gate script), **Blender docs**, **Rule of thumb**.

---

## The four traps

**1. Converted text is not welded (gate A2, watertight).** A text object with extrude and bevel converts into separate cap and side surfaces whose shared edges are duplicated, not joined. Measured: the cream front letters of "FLOCK!" reported 2,520 boundary edges; the dark outline letters 1,288. A merge-by-distance weld closed almost all of them.

**2. Primitive caps are n-gons (gate A4).** Cylinder and cone caps (posts, rope rings, bulb sockets) and UV-sphere poles come out as n-gons. Measured: 44 n-gons on one timber piece, 72 on another. Triangulating only the faces with more than four corners fixes it without touching the quads.

**3. Outlines made with the text offset fold at sharp corners (A2 again).** A dark outline behind the letters is the classic sign look: the same glyph with a positive `offset`, set behind the fill. At inner corners (the foot of an "F", the counters of "O" and "G") the grown outline crosses itself and leaves small holes that a hole-fill cannot close. Measured fixes, in order of effect:
- no bevel on the outline glyph (it is mostly hidden anyway): no change on its own;
- a thinner offset, 4.5% of the text size down to 3.8%: the big word passed;
- small text (about 1 stud tall) on a coloured ribbon: drop the outline, cream on rust reads fine without it.

**4. Small bevels fold into themselves (gate A17, self-intersections).** A bevel that is fine on 5-stud letters crosses itself on 0.6 to 1-stud letters at tight curves. Measured: 21 self-intersecting face pairs in each piece that held small words. No bevel on text under about 2 studs fixed it, and the difference cannot be seen at that size.

## The clean-up pass

Run it on every part before joining by colour and exporting (Blender Python, `bmesh`):

```python
import bmesh

def clean_parts(objects):
    """Weld, close small holes, triangulate n-gons, outward normals: gates A2, A3, A4."""
    for o in objects:
        if o.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-3)
        boundary = [e for e in bm.edges if e.is_boundary]
        if boundary:
            bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
        ngons = [f for f in bm.faces if len(f.verts) > 4]
        if ngons:
            bmesh.ops.triangulate(bm, faces=ngons)
        bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(o.data)
        bm.free()
```

Set the text's curve resolution before converting: the default `resolution_u` of 12 made each gate about 51,000 triangles; 5 kept the "O"s round at about 18,000 for the whole title gate, with every colour piece under 8,000 (**Measured**).

## Numbers (Measured)

| Step | Pieces failing (of 29) | Title gate tris |
|---|---:|---:|
| First export (resolution 12) | not gated | 51,068 |
| Resolution 5, no clean-up | 12 (A2, A3, A4) | 27,208 |
| Clean-up pass | 2 (A2 in outlines) | 27,196 |
| Thinner outline, none on small text | 0 (without surface checks) | 20,920 |
| No bevel on text under 2 studs | 0 (all gates, surface checks on) | 18,456 |

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Exporting converted text as is | A2 fails with thousands of boundary edges | Merge by distance after converting |
| Leaving cylinder caps and sphere poles | A4 n-gons on posts and bulbs | Triangulate faces with more than 4 corners |
| Thick offset outline on small or sharp glyphs | Holes at inner corners that hole-fill can't close | Thinner offset (about 3.8% of size); no outline on small text |
| Same bevel on every word | A17 self-intersections in small words | No bevel under about 2 studs |
| Default curve resolution | 50k-triangle sign | `resolution_u` about 5 |
| Hand-built flag or pennant left open | A2 and A3 on a thin prism | Weld the collapsed tip, recalculate normals |

## Checklist

- [ ] Text converted to mesh (a curve doesn't export).
- [ ] `resolution_u` set (about 5) before converting.
- [ ] Clean-up pass run on every part before the join.
- [ ] Outline offset at or under about 3.8% of size; no outline on text under about 2 studs.
- [ ] No bevel on text under about 2 studs.
- [ ] Gates run with surface checks on; every colour piece under the class ceiling.
- [ ] Two-sided signs: mirror the whole word group 180 degrees, so the back reads right instead of mirrored.

## See also

[[Mesh Gates for Generated Models - Symmetry, Seating and Caps]] · [[Curve-Based Modelling in Blender for Roblox]] · [[Stylised Shop Stand Worked Example]] · [[Blender Workflow for Roblox Creators]] · [[Field Notes Start Here]]

<!-- related:start -->
## Related
[[Procedural Model Kits - Lessons]] · [[Hard-Surface Modeling]] · [[UIStroke on Text - Glyph Counters and the Stroke Ratio]] · [[Animation Data Hygiene - Euler Wrap Joint Holes and Easing]] · [[Re-theming a Live Game - UI Theme Scripts and a Reversible World Pass]] · [[Shared Close Buttons and Headers Across Many Screens]]
<!-- related:end -->
