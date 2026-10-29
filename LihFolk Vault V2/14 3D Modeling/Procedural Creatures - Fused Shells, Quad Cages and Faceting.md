---
tags: [modeling, blender, creatures, procedural, topology, subdivision, sdf, decimate, faceting, lihfolk, type/case-study, area/modeling, level/advanced]
verified: 2026-10-28
---
# Procedural Creatures - Fused Shells, Quad Cages and Faceting

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Stacking many shells for a creature that should read as one body.
> - Avoid: Raising the triangle count to cure faceting.
> - Avoid: Treating decimation output as final topology.
> - Reference sheet (front + side) locked before modelling
> - One fused shell; quad cage + one subdivision level planned
> - Colour borders on edge loops or level-set cuts, faired
>
> Cost: TL;DR ~130 tok · whole note ~1.4k tok. Read more: ## 1. Three methods, three plateaus · ## 2. Fused beats stacked, but topology decides smoothness · ## Common mistakes · ## Checklist
<!-- tldr:end -->

What happened when AI agents built a stylised creature (a fox) in Blender by script, and three construction methods were scored by blind reviewers. The short version: stacked shells plateau because of seams, a fused shell fixes the seams, and smooth faceting needs a designed quad cage with subdivision, not more triangles. All scores are blind rubric scores out of 10 (pass bar 8.5), **Measured** in this project.

## 1. Three methods, three plateaus

| Method | Best blind score | What held it back |
|---|---:|---|
| Voxel remesh + decimate + limited-dissolve carve | 4.7 | Random facets; colour borders crossing long sliver triangles ("sock streaks"); razor ear and ruff cards |
| 22 lofted / swept shells, colour borders on ring stations | 7.7 (3 rounds, flat) | Shell intersection seams, flat tuft "cards", stilt legs, tube torso |
| One fused SDF shell (smooth-union primitives -> surface nets -> weighted decimate -> mirror) | 7.0 (4 reviews: 7.0 / 6.67 / 7.0 / 7.0) | Decimation facets: lumpy back, faceted ear tips and paw outlines, star highlights at poles |

Lofts beat the remesh by +3.0 because every colour border sat exactly on a ring station. But three rounds of tuning on the loft build changed nothing: overlapping shells read as seams and wedges whatever the parameters.

## 2. Fused beats stacked, but topology decides smoothness

The fused SDF shell solved what it was meant to: gates were clean (symmetry error 0.0, no self-intersections), seams were gone, and colour borders became smooth curves. It still scored lower than the loft build, because:

- **Workbench cavity shading shows the real triangles** of a decimated mesh even when custom normals are exact. At 4-5k tris close-ups show polygon outlines on paws and ear tips.
- **More triangles did not fix it.** 7.5k tris scored 6.7 and lost the geometry-economy point too.
- **Decimation leaves high-valence poles**, which render as star-shaped highlights. `beautify_fill` (area method) plus a tangential relax removes the stars, not the faceting.

The lesson: a fused single shell is the right *structure*, and decimation is the wrong *topology*. A smooth creature needs a **designed quad cage plus one Catmull-Clark subdivision level** (even quads, few poles), or a remesh followed by proper retopology. Faceting comes from the edge flow of the cage, not from the triangle count.

## 3. Decimate weights are inverted from intuition

Blender's Decimate vertex-group factor multiplies edge cost by about `1 + (2 - w1 - w2) x factor`, and weight 0 locks a vertex. The first attempt got the direction backwards: the head collapsed to shards while the torso kept 53k tris. Use weights from 0.4 (protect) to 1.0 (free), a factor of 2-5, never 0, and never the invert option.

## 4. Colour borders

- On lofts, place a ring station exactly on every colour border (sock line, tail tip, bib).
- Colour by the ring's parametric sector angle, not by face normal. A sector whose normal sits on the threshold flips colour per station and stair-steps the jaw line.
- On a fused shell, cut the mesh along the analytic level set, then fair each border chain with a 1-D Laplacian re-projected to the surface. Zigzag complaints stopped.

## 5. Symmetry from the start

- Blender's icosphere is not mirror-symmetric across X; a centred icosphere nose gave 0.7 % symmetry error and failed the gate. Build centred blobs from rings with angles `(i + 0.5) / n`, `n` even: error 0.0.
- Better: build the +X half and mirror.

## 6. Small forms need density

Toe grooves, bib fluff points and a brow ridge at 5k tris read as "torn hem", "pinched toes" and "lumpy brow". Only add small forms where the mesh has density for them; otherwise keep the small tier to eyes, glints and nose.

## 7. Lock the design before modelling

Across seven fox reviews proportion requests changed every round: bigger head, then "ears look fennec", then "tail undersized". Proportion was being iterated instead of designed. Lock a front + side reference sheet first, and judge proportion against it.

## Common mistakes

- Stacking many shells for a creature that should read as one body.
- Raising the triangle count to cure faceting.
- Treating decimation output as final topology.
- Decimate weights of 0, or inverted groups.
- Colour boundaries by face normal.
- Using an icosphere for a feature that must be mirror-symmetric.

## Checklist

- [ ] Reference sheet (front + side) locked before modelling
- [ ] One fused shell; quad cage + one subdivision level planned
- [ ] Colour borders on edge loops or level-set cuts, faired
- [ ] Built as half + mirror; symmetry gate at 0
- [ ] Small forms only where density supports them
- [ ] Renders in Standard view transform; close-ups of paws, ears, tail tip

## See also

- [[Organic and Creature Modeling]]
- [[Topology and Edge Flow]]
- [[Retopology and Decimation]]
- [[Low-Poly Creature From a Flat Reference Sheet]]

## Connected notes

[[Procedural Model Kits - Lessons]] · [[Mesh Gates for Generated Models - Symmetry, Seating and Caps]] · [[Case Study - Building LihFolk V2 with AI Agents]]

<!-- related:start -->
## Related
[[Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs]] · [[Modeling Fundamentals for Games]] · [[Blender Workflow for Roblox Creators]] · [[Curve-Based Modelling in Blender for Roblox]] · [[Hard-Surface Modeling]] · [[Normal Maps and Detail Baking]] · [[Modeling Characters for R15 and Custom Rigs]] · [[UV Unwrapping]]
<!-- related:end -->
