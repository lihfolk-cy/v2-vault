---
tags: [modeling, hard-surface, blender, bevel, booleans, normals, props, type/guide, area/modeling, level/intermediate]
---
# Hard-Surface Modeling

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Bevels on unapplied scale -> Apply scale first
> - Avoid: Bevelling every edge with 3+ segments -> Limit by angle or weight; 1-2 segments
> - Avoid: Smooth shading a low poly with no normal fix -> Weighted Normal / Harden Normals
> - Workflow chosen (A, B or C) for a reason written in the brief.
> - Scale applied before bevelling; bevel width 1-6 percent of form size.
> - Bevel segments 1-2 except silhouette curves.
>
> Cost: TL;DR ~150 tok · whole note ~4.6k tok. Read more: ## 2. Workflow A: mid-poly with bevels, step by step · ## 5. Hard-surface shape design · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Hard-surface means man-made, rigid things: armour, weapons, machines, crates, buildings, vehicles, sci-fi panels. The craft is making flat faces look flat, edges look manufactured, and curves look intentional, at a triangle count a phone can draw. Most hard-surface failures in Roblox are not modelling failures but **shading** failures: a good shape with bad normals reads as cheap plastic. This note covers the three workflows that ship, how to choose between them, the shading recipe that makes low-poly look expensive, booleans without the mess, and the measured numbers from one production game's armour, weapons and hub props.

For general setup and modifier details see [[Blender Workflow for Roblox Creators]]. For baking details see [[Normal Maps and Detail Baking]].

---

## 1. Three workflows, one decision

| Workflow | How | Triangles | Texture memory | Best for |
|---|---|---|---|---|
| **A. Mid-poly with bevels** ("bevel and [[weighted normals]]") | Model the low poly directly, bevel the edges with 1-3 segments, fix shading with custom normals | Medium (bevels cost 2-6x on bevelled edges) | None needed; flat colours or a shared trim sheet | Roblox's default case: stylised props, armour, hub pieces, kits |
| **B. High-to-low bake** | Build a subdivided high poly with support loops, a clean low poly, bake normals | Low in game | One normal map per asset (or per atlas) | Hero weapons, detailed sci-fi panels, realistic styles |
| **C. Boolean-driven** | Block shapes, cut and join with booleans, bevel the result, clean up | Medium; messy topology | None or trim sheet | Fast concepting, mechanical props that do not deform |

**Why A is usually right on Roblox.** Every unique normal map is texture memory, and texture memory runs out first on low-end phones (see [[Textures Decals and Texture Memory]]). Bevelled edges catch real highlights from Roblox's lighting at any distance, with zero texture cost, and they survive LOD better than baked detail. The reference project's 156 armour meshes were all workflow A: "thick softly bevelled plates (bevel 0.035)", oversized flared pauldrons, "few bold features", glowing rune strips, **max 3,140 triangles per mesh** and 15.0k to 20.3k per 13-piece set (Measured). They shared one tinted trim texture rather than per-piece bakes.

**When B pays off.** Detail that matters close up but must stay cheap in triangles: panel seams, vents, engraved runes on a hero sword seen in an inspect view, or a weapon held in first person. B also suits a realistic art direction where bevels alone look toy-like.

**C is a means, not an end.** Booleans are a fast way to get a shape; the result is then cleaned and treated as A or as the high poly for B.

---

## 2. Workflow A: mid-poly with bevels, step by step

Worked example: a sci-fi supply crate, 4 x 3 x 3 studs, about 600 triangles.

1. **Block the volume.** Add a cube, scale it to 4 x 3 x 3 (type the values in the N panel), apply scale (Ctrl+A). Origin at the bottom centre (see [[Blender Workflow for Roblox Creators]] section 5).
2. **Primary forms.** Loop-cut the long sides (Ctrl+R) to create a band 0.4 studs from each end. Extrude the band faces outward 0.1 studs (E, then type 0.1) to form reinforcing ribs. Inset (I) the lid face 0.25 studs and extrude it down 0.08 to make a recessed panel.
3. **Secondary forms.** Inset and extrude a handle recess on the two short sides. Model the handle bar as a separate object (a cylinder with 8 sides is plenty at this scale).
4. **Mark what to bevel.** Either use *Limit Method: Angle* (30 degrees bevels every corner sharper than 150 degrees, i.e. all the box corners) or select edges and set bevel weight (Shift+E, 1.0) and use *Limit Method: Weight* for control.
5. **Bevel modifier.** Width 0.04 to 0.06 studs (about 1-2 percent of the crate's size), 2 segments, *Clamp Overlap* on, *Harden Normals* on.
6. **Shading.** Shade Smooth, then add *Weighted Normal* after the Bevel, *Keep Sharp* on, *Face Influence* on if you used Bevel's *Face Strength*. Big flat faces now stay perfectly flat; the bevels carry the gradient.
7. **Check.** Statistics overlay: a 6-sided crate with ribs, a recessed lid and two 2-segment bevelled handles lands around 500-900 triangles. Look at it under a strong light from three angles: no gradients across flat faces, every corner catches a line of light.
8. **Finish.** Apply modifiers, triangulate (optional), UV with a trim sheet or atlas (see [[Trim Sheets Atlases and Vertex Colors]]), export.

### Bevel width: how big?

| Bevel relative to object size | Reads as | Use |
|---|---|---|
| Under 0.5 percent | Invisible at game distance; only adds triangles | Avoid |
| 1-2 percent | Crisp manufactured edge | Machines, crates, metal |
| 3-6 percent | Soft, chunky, toy-like | Stylised armour, cartoon props |
| Over 8 percent | Pillow shape | Inflated or cushion styles only |

These are rules of thumb. The armour's 0.035-stud bevel was on plates around 1-2 studs across, so roughly 2-3 percent, which gave the "soft chunky" look.

### Segments: what they cost

Each bevelled edge with `s` segments adds about `2s` triangles per edge length segment, and every corner where three bevelled edges meet adds a patch of roughly `s^2` faces. One segment (a chamfer) catches light nearly as well as three at game distance, at a third of the cost. Use 1 segment for small or distant parts, 2 for most hero pieces, 3 only where the curve shows in silhouette.

### The shading recipe, explained

Smooth shading averages normals at each vertex. On a box with small bevels, the big faces' vertices sit next to the bevel faces, so the averaged normals tilt, and the big faces show a gradient ("smoothing errors"). Three tools fix that:

- **Sharp edges** (Mark Sharp, or Smooth by Angle): split the normals so the big face keeps its own. Fast, but costs GPU vertex splits on every sharp edge and makes edges look hard again.
- **Weighted Normal** (manual: weight by face area, corner angle, or both; *Weight 50* is uniform, higher favours larger faces): the big face dominates the averaged normal, so it stays flat; the little bevel faces take the bend.
- **Bevel > Harden Normals**: the bevel modifier itself writes custom normals that match the surrounding faces.

Use Harden Normals or Weighted Normal, not both fighting each other. Custom normals survive FBX and GLB export and Roblox uses them, so what you see in Blender's solid view with a matcap is close to what Studio shows.

---

## 3. Workflow B: high poly and bake

### Support loops

A subdivided cube becomes a blob. To keep a corner sharp under Subdivision Surface you add **support (holding) loops**: extra edge loops close to the edge. The closer the loop, the tighter the corner.

| Loop distance from edge | Corner after subdivision level 2 |
|---|---|
| 25 percent of face width | Very soft |
| 10 percent | Soft industrial |
| 2-3 percent | Crisp machined |

Fast ways to add them: a Bevel modifier with 2-3 segments and *Profile* 1.0 before the Subdivision modifier (the "bevel as support loops" trick), or edge creases (Shift+E in edge mode with Subdivision; crease 1.0 = sharp). Creases are quicker, bevel-as-support gives better highlights.

### Rules for the high poly

- **Silhouette must match the low poly.** If the high poly sticks out further than the low poly's cage, bakes clip.
- **Floating detail is allowed.** Bolts, vents and panels can be separate floating meshes hovering on the surface; the bake projects them into the normal map. Saves hours of topology.
- **Exaggerate slightly.** Bevels and seams that are physically correct often vanish after baking and texture compression. Make bake details about 1.5x what looks right in the high poly.

### Rules for the low poly

- Follow the high poly's silhouette with as few edges as possible. Flat panels need no loops; curves need enough segments that the outline does not facet (8-12 around a hand-held cylinder, 16-24 for a big visible round shape).
- Hard edges (sharp) **only where there is a UV seam**, and UV seams on every hard edge. The baked normal map then has room to correct shading across the split.
- Triangulate before baking and export with the same triangulation, or the bake's tangent space will not match the engine's.

Baking itself is in [[Normal Maps and Detail Baking]].

---

## 4. Workflow C: booleans without the mess

### Non-destructive setup

1. Keep the base object clean and simple.
2. Make each cutter a separate object (a cylinder for a bolt hole, a rounded box for a vent) in a **"Cutters" collection**, displayed as *Wire* or *Bounds* and disabled for render and export.
3. Add a Boolean modifier per cutter (or one with *Operand Type: Collection* pointing at the Cutters collection). Solver *Exact* for final results; *Float* for speed while blocking (it does not support overlapping geometry, per the manual); *Manifold* in newer versions when both shapes are closed manifold meshes.
4. Add Bevel **after** the boolean with *Limit Method: Angle* so the cut edges get bevelled too.
5. Add Weighted Normal last.

Everything stays editable: move a cutter, the hole moves.

### Cleanup after applying

Booleans leave n-gons and long thin triangles fanning out from the cut. On a static, flat-shaded or weighted-normal prop that is often acceptable. When it is not:

- **Route edges**: with the knife (K), connect the cut's vertices to the nearest corners of the face, so faces become quads and short triangles.
- **Dissolve** (*Delete > Dissolve Vertices/Edges*) stray vertices in the middle of flat faces.
- **Add a loop** around the cut (an inset on the base face before cutting) so the cut sits in its own patch and does not pull shading across the whole face.
- **Check shading** under a moving light. Thin triangles produce streaks with smooth shading; use flat or weighted normals on those areas.

### When not to use booleans

- On meshes that will deform (character armour on joints, cloth). The topology will pinch.
- On meshes that will be subdivided. Subdivision exaggerates every n-gon.
- For small repeated details that can be a texture (vents, rivets): a trim sheet strip is cheaper than geometry.

---

## 5. Hard-surface shape design

Shape language matters more than technique:

- **Big-medium-small.** Vary the size of forms: one big mass, a few medium features, many small ones. Even spacing and even sizes look procedural and dull.
- **Rest areas.** Leave some plain surfaces. Detail everywhere is noise at game distance.
- **Functional logic.** Panels need seams where they could come apart; hinges need a pin; vents need a reason. Players do not analyse it, but they feel when it is wrong.
- **Chunky over thin.** A Roblox camera is far and screens are small. Thicken plates, enlarge bolts, exaggerate rims. The reference project rebuilt its whole armour line from a detailed first pass into "chunky stylised armour: thick softly bevelled plates, oversized flared pauldrons, few bold features", to match the simulator-style references the owner wanted; the same fit envelope and set list were kept.
- **Tapers and flares.** Plates that flare out (pauldrons, greaves, gun barrels with a muzzle lip) catch light on two sides and read as solid.

### Procedural hard-surface (the reference project's approach)

Most of the project's hard-surface art was generated by Python in Blender rather than by hand: armour as "superellipse plate bands lofted around each body part, layered lames, dark trim lips, glow strips glued to the plate skins", built per set in each body part's local space and checked against every R15 part box for intrusions (0 intrusions shipped). The advantage is that a design change ("thicker plates") is a parameter, and fit checks are automatic. See [[Blender Automation with Python]] and [[Accessories and Armor That Follow Animation]].

A superellipse cross-section is a handy primitive for rounded-rectangle plates. A minimal generator:

```python
# Blender: a lofted superellipse plate band (rounded-rect cross-section) around the Z axis.
import bpy, bmesh, math

def superellipse(a, b, n, segs):
    """Points on |x/a|^n + |y/b|^n = 1. n=2 ellipse, n=4+ rounded rectangle."""
    pts = []
    for i in range(segs):
        t = 2 * math.pi * i / segs
        c, s = math.cos(t), math.sin(t)
        x = a * math.copysign(abs(c) ** (2 / n), c)
        y = b * math.copysign(abs(s) ** (2 / n), s)
        pts.append((x, y))
    return pts

def plate_band(name, a, b, n=4.0, height=0.6, thickness=0.08, segs=32):
    bm = bmesh.new()
    rings = []
    for z, grow in ((0.0, 0.0), (height, 0.0)):
        ring = [bm.verts.new((x, y, z)) for x, y in superellipse(a + grow, b + grow, n, segs)]
        rings.append(ring)
    for i in range(segs):                                   # side wall between the two rings
        j = (i + 1) % segs
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    sol = obj.modifiers.new("Thickness", 'SOLIDIFY')       # closed volume: no zero thickness
    sol.thickness, sol.offset, sol.use_even_offset = thickness, 1.0, True
    bev = obj.modifiers.new("Bevel", 'BEVEL')
    bev.width, bev.segments, bev.limit_method = 0.02, 2, 'ANGLE'
    bev.harden_normals = True
    return obj

plate_band("ChestBand", a=1.05, b=0.6, n=4.5)               # sized around an R15 UpperTorso (1.94 x 1.0)
```

Shade smooth after running it; *Harden Normals* writes custom normals. The face winding depends on the order the rings are built; if Face Orientation shows red outside, recalc normals.

---

## 6. Normals and shading troubleshooting

| What you see | Cause | Fix |
|---|---|---|
| Gradient across a flat face | Smooth shading averaged with neighbouring bevels | Weighted Normal or Harden Normals |
| Black or very dark faces in Studio, fine in Blender | Flipped normals, or Blender's back-face rendering hiding them | Face Orientation overlay; Recalculate Outside |
| Hard faceted look on a cylinder | Flat shading, or too few segments | Shade smooth with Smooth by Angle around 30-40 degrees; more segments only if the silhouette facets |
| Streaks radiating from a hole | Long thin boolean triangles with smooth shading | Route edges, add a surrounding loop, or flat-shade that area |
| Bevel looks dull, no highlight | Bevel too small or one segment on a big edge | Wider bevel; 2 segments on hero edges |
| Seams visible on a baked normal map | Hard edge without a UV seam, or tangent mismatch | Seam on every hard edge; triangulate before bake |
| Shading differs between Blender and Studio | Custom normals lost (modifier converted without them), or different triangulation | Apply modifiers one by one; triangulate yourself |

---

## 7. Budgets and numbers from production

| Asset (reference project) | Workflow | Triangles |
|---|---|---|
| 13-piece armour set | A, procedural | 15.0k to 20.3k per set, max 3,140 per mesh |
| Hub roll altar (marble tiers, gold trim, gems, claws, swords) | A | 7.3k over 9 meshes |
| Hub prize wheel with 36 bulbs and slice icons | A | 7.2k over 7 meshes |
| Daily reward chest (planks, gold straps, rivets, domed lid) | A | 8k |
| Shop kiosk with lanterns, canopy, sign, NPC outfit | A | 43.5k over 20 meshes |
| Hand-modelled swords (32 parts each, glowing cores, orbiting pieces) | A with emissive parts | 26.8k and 29.5k |
| Canyon wall segment with neon magma seams | A | about 3.5k |

The pattern: props that appear once can run 7-10k; anything worn or repeated stays under about 3.5k per mesh.

---

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Bevels on unapplied scale | Uneven bevel widths | Apply scale first |
| Bevelling every edge with 3+ segments | Triangle count triples for no visible gain | Limit by angle or weight; 1-2 segments |
| Smooth shading a low poly with no normal fix | Plastic-looking gradients | Weighted Normal / Harden Normals |
| Booleans on deforming meshes | Pinching at joints | Model the cut into the topology |
| High-poly detail sticking outside the low poly | Clipped, broken bakes | Match silhouettes; use a cage |
| Thin realistic plates | Paper look on phones | Thicken and exaggerate |
| Per-asset normal maps for everything | Texture memory blowout | Mid-poly bevels or shared trim sheets |

## Checklist

- [ ] Workflow chosen (A, B or C) for a reason written in the brief.
- [ ] Scale applied before bevelling; bevel width 1-6 percent of form size.
- [ ] Bevel segments 1-2 except silhouette curves.
- [ ] Weighted Normal or Harden Normals; no gradients on flat faces under a moving light.
- [ ] Boolean cutters kept as hidden objects until final; cut areas cleaned.
- [ ] Hard edges on UV seams (B), triangulated before baking.
- [ ] Per-mesh triangles within budget; worn or repeated pieces under ~3.5k.

## See also

[[Blender Workflow for Roblox Creators]] · [[Modeling Fundamentals for Games]] · [[Low-Poly and Stylized Modeling]] · [[Modeling Weapons and Props]] · [[Normal Maps and Detail Baking]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Accessories and Armor That Follow Animation]] · [[Modular Environment Kits]]

## Connected notes
<!-- auto-links:start -->
[[Clean Stylised Shading - Weighted and Custom Normals]] · Bevels Chamfers and Edge Highlights Without Textures · [[Topology and Edge Flow]] · Untextured Stylised Modelling Start Here · Faceted Low-Poly - Flat Normals and Facet Size · Voxel Shading - Baked AO Edges and Lighting
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Bevels Chamfers and Edge Highlights Without Textures]] · [[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Retopology and Decimation]] · [[UV Unwrapping]] · [[Hand-Painted and Stylized Texturing]] · [[Procedural Model Kits - Lessons]] · [[Organic and Creature Modeling]] · [[Curve-Based Modelling in Blender for Roblox]] · [[Voxel and Blocky Modeling]] · [[Texturing and PBR Baking]]
<!-- related:end -->
