---
tags: [modeling, blender, procedural, qa, gates, symmetry, topology, bmesh, triangulation, lihfolk, type/guide, area/modeling, level/advanced]
verified: 2026-10-28
---
# Mesh Gates for Generated Models - Symmetry, Seating and Caps

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Eyeballing a centred emblem.
> - Avoid: Sweeping an accent separately along the parent's curve.
> - Avoid: Insetting an outline that is already rounded.
> - Symmetric objects built half + mirror; A15 <= 1 %
> - Centred features within 2 %; seated features touch (A16)
> - Accents built from parent vertices, nudged 0.02
>
> Cost: TL;DR ~120 tok · whole note ~1.4k tok. Read more: ## 1. A15 - symmetry · ## 2. A16 - alignment and seating · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Four automatic checks that catch the defects AI-generated and scripted meshes produce most often, and that humans and reviewers notice instantly: lopsided "symmetric" objects (A15), off-centre or floating features (A16), shells folding through themselves (A17), and broken flat caps (A18). They extend the usual export gates (tri ceiling, watertight, normals, no n-gons, transforms applied, one UV map, one material). Every example here is **Measured** in the LihFolk V2 model kit.

## 1. A15 - symmetry

**Rule:** objects that are symmetric by design (shields, badges, swords across the blade's flat, bottles, most props) must have a symmetry error of 1 % of their size or less across the mirror axis.

- Measure it: for each vertex, the distance from its mirror image to the nearest vertex, as a fraction of the bounding-box size.
- **Author half and mirror.** Build the outline for one side and mirror it; don't trust free-form placement to land symmetric.
- Primitives can fail on their own: a centred Blender icosphere is not X-mirror-symmetric (0.7 % error). Ring-built blobs with angles `(i + 0.5) / n`, `n` even, measure 0.0.
- **Lighting fools eyes.** Workbench light comes from one side. A badge measured symmetric to 1e-7 was called "leaning" by a reviewer because of one-sided shading on a pick-shaped outline. Judge symmetry from the outline and the number.

## 2. A16 - alignment and seating

**Rule:** features meant to be centred (emblems, gems, guards, blades on grips) sit within 2 % of size of their parent's centre or axis; features meant to sit on a surface touch it, with no gap and no deep burial.

- **Centre by maths, not by eye.** Use the bounding-box centre or the polygon's area centroid. A star on a heater shield goes at the field's area centroid, not its bbox centre.
- A blade's base midpoint must sit on the grip axis. Offset the sweep path, not the grip.
- **Build accents from the parent's own vertices.** A gold bead path swept a second time along the same curve floated 0.045 studs off the band, because its rotation-minimising frame started differently. Reading the path from the band's rim vertices fixed it. Nudge 0.02 so cleanup does not weld the two shells.
- A floating accent that pokes through its band caps silhouette, proportion and shading at 1 in review. Run the seating check on every accent.

## 3. A17 - no self-intersections inside a shell

**Rule:** no shell intersects itself. Separate shells pushed into each other on purpose are allowed.

Common causes:

- **Folded sweep profiles.** A fuller wider than its flat folded a blade into a dark crease with 83 self-intersections. Keep inner features inside their flat: `fw = 0.6 x min(fc - flatL, flatR - fc)`.
- **Insetting a rounded outline.** The inset loops back at corners tighter than the inset distance. Inset the sharp outline first, then round both.
- **Coincident poles.** Two lathes sharing a pole position weld into one shell during cleanup. Offset by 0.03.

## 4. A18 - clean planar caps

**Rule:** flat caps have no overlapping, folded or degenerate triangles, and shading shows no artefacts.

- **Concave caps need ear clipping.** Stars, crosses and gears have concave outlines. bmesh's BEAUTY n-gon fill put triangles outside the outline on a star, which rendered as a visible "square patch". An ear-clipping fill keeps every triangle inside the polygon.
- Bevelling pole fans creates n-gons; triangulate after the bevel.
- **Review with close-ups.** Small cap artefacts are invisible in four whole-object views. Render 512 px close-ups centred on each feature (emblem, cap, pommel), in studio light and flat light.

## 5. Running the gates

- Run all gates after `finish()` (transforms applied, modifiers evaluated) and before any reviewer sees the asset.
- Any gate failure caps the score at 5.0 and drops the item from shipping.
- Feed gate numbers to the reviewer with the renders, so they can check claims ("symmetric" with A15 = 0.0).
- Tell reviewers to look for correctness first (symmetry, centring, seating), then surface artefacts, then style.

## Common mistakes

- Eyeballing a centred emblem.
- Sweeping an accent separately along the parent's curve.
- Insetting an outline that is already rounded.
- Beauty-filling a concave cap.
- Reviewing only whole-object renders.
- Calling a symmetric mesh lopsided because of directional light.

## Checklist

- [ ] Symmetric objects built half + mirror; A15 <= 1 %
- [ ] Centred features within 2 %; seated features touch (A16)
- [ ] Accents built from parent vertices, nudged 0.02
- [ ] Sweep profiles ordered; insets on sharp outlines (A17)
- [ ] Concave caps ear-clipped; triangulate after bevel (A18)
- [ ] Feature close-ups rendered for review

## See also

- [[Procedural Model Kits - Lessons]]
- [[Exporting and Validating Models for Roblox]]
- [[Curve-Based Modelling in Blender for Roblox]]
- [[Blender Automation with Python]]

## Connected notes

[[Procedural Creatures - Fused Shells, Quad Cages and Faceting]] · [[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · [[Topology and Edge Flow]]

<!-- related:start -->
## Related
[[Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs]] · [[Blender Workflow for Roblox Creators]] · [[Retopology and Decimation]] · [[Hard-Surface Modeling]] · [[Modeling Fundamentals for Games]] · [[Normal Maps and Detail Baking]] · [[Organic and Creature Modeling]] · [[UV Unwrapping]]
<!-- related:end -->
