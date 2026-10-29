---
tags: [modeling, blender, procedural, kits, weapons, props, lathe, bevel, faceting, gltf, vertex-colors, lihfolk, type/guide, area/modeling, level/advanced]
verified: 2026-10-28
---
# Procedural Model Kits - Lessons

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One radial resolution for the whole object.
> - Avoid: Realistic weapon proportions in a stylised kit.
> - Avoid: Razor facets with no chamfer.
> - Small round parts have their own lathe steps (or are deliberately faceted)
> - Hafts 0.18-0.23 studs, head ~1/3 of length
> - Gems: angle-limited bevel + weighted normals + triangulate
>
> Cost: TL;DR ~130 tok · whole note ~1.5k tok. Read more: ## 1. Faceting on small round parts is the number one complaint · ## 5. Blades · ## Common mistakes · ## Checklist
<!-- tldr:end -->

What made scripted Blender generators produce Roblox props and weapons that pass a blind quality panel. The kit had 26 generator types (swords, spears, staffs, gems, potions, barrels, medals, tokens and more) and went through about 90 blind reviews (**Measured**). Scores below are blind rubric scores out of 10, pass bar 8.5, all **Measured** in this project.

## 1. Faceting on small round parts is the number one complaint

Generators usually set one radial step count for a whole object, sized for its biggest part. Small round parts then look like polygons in close-ups: pommels, balls, rivets, collars.

- **Give small round parts their own lathe resolution.** Split the pommel from the grip: a 24-step pommel next to a 16-18-step grip. Rivets as 7-point domes.
- Below about 18 radial steps (~20 degrees per ring), reviewers cap clean shading at 1 in 512 px close-ups. Hero curves need 20-24 steps or ~10-degree rings.
- **Or make the polygon a design choice.** Small "round" props stuck at 8.0-8.3 (a potion at 16-22 steps under its 600-tri target) jumped when rebuilt as 6- or 8-sided faceted shapes with chamfers: vial 8.3 -> 10.0. A deliberate hexagon reads as style; an 18-gon reads as low quality.

## 2. Chunkier hafts

Hafted weapons modelled with realistic proportions read as "lanky" in a stylised game (spear and staff 6.0-7.3). The fix:

- Haft radius 0.18-0.23 studs.
- Head about one third of total length.
- Shorter haft, tapering toward the head.

Result: 8.7-10.0. Roblox's camera distance and stylised avatars reward mass over realism.

## 3. Gems and faceted props need chamfers

Razor-sharp facets render as flickering lines and hard aliasing.

- Add an **angle-limited bevel** of 0.025-0.03 studs, then **[[weighted normals]]**, then **Triangulate** (the bevel turns pole fans into n-gons, which fail the no-n-gon gate).
- Gem 7.7 -> 9.3; vial 8.3 -> 10.0.
- Smooth shading without the weighted-normal step bleeds gradients across the chamfers.

## 4. Small tier on plain lathes

A lathe barrel with no small details scored 8.0 (no big/medium/small hierarchy). Detail modelled on existing rings lifted it to 9.3:

- Stave grooves: pull every third lathe vertex inward 0.035 studs.
- Thick chamfered hoops plus dark "ink" nails.

Use the topology you already have before adding new shells.

## 5. Blades

- A one-point sharp edge in the sweep profile reads as a razor ribbon. Use a **flat rounded edge** (two points, half-thickness `max(0.012, 0.3 t)`).
- Flare the edge side toward the tip and clip late so the point is broad then short. Sword 6.6 -> 9.3 with these two changes.
- Do not clamp a minimum width near tips; it cuts them flat. End sweeps with a short dome.
- Keep profile points in order: a fuller wider than its flat folds the blade (self-intersection gate A17).

## 6. Fit loops and ship filters

- A variant over its class tri target silently costs 0.3 on geometry economy. Fit in a loop (for example hilt steps 22 -> 14 until under target).
- Filter at ship time: any variant over target or failing a gate is not shipped.

## 7. Colour

- Paint vertex colours: one hue in 2-3 values, plus the kit's gold accent and dark ink. Put colour borders on edge loops (rings, stations) so they stay crisp. Blind +1.7 to +3.7 on every curve sample.
- Use only kit colours besides the asset's own hue. A brown grip or brown cork read as "off-kit".
- Workbench renders a neutral cream as grey; warm it (mix about 30 % gold), and set the view transform to Standard so renders show the exact hexes Roblox will show.

## 8. Blender 5.2 glTF exports every colour layer

**Measured:** Blender 5.2's glTF exporter writes every colour attribute on the mesh as `COLOR_0`, `COLOR_1`, ... When a kit stored several colourways as extra attributes, every exported colourway looked identical: each file carried all the layers, and the same one was used every time. Keep exactly one colour attribute ("Col") on the mesh while exporting each colourway; swap it in, export, swap the next.

## 9. Coincident poles weld shells

Two lathes whose poles coincide (a stem top equal to a hub top) weld into one shell during cleanup and fail the self-intersection gate even though each part is clean. Offset them by about 0.03 studs.

## Common mistakes

- One radial resolution for the whole object.
- Realistic weapon proportions in a stylised kit.
- Razor facets with no chamfer.
- Adding detail shells when existing rings could carry it.
- Several colour attributes on a mesh at export.
- Shipping variants that are over their tri target.

## Checklist

- [ ] Small round parts have their own lathe steps (or are deliberately faceted)
- [ ] Hafts 0.18-0.23 studs, head ~1/3 of length
- [ ] Gems: angle-limited bevel + weighted normals + triangulate
- [ ] Small tier modelled on existing rings
- [ ] Only one colour attribute on the mesh at export
- [ ] Fit loop to class target; ship filter on gates and tris
- [ ] Renders in Standard view transform

## See also

- [[Mesh Gates for Generated Models - Symmetry, Seating and Caps]]
- [[Procedural Creatures - Fused Shells, Quad Cages and Faceting]]
- [[Modeling Weapons and Props]]
- [[Bevels Chamfers and Edge Highlights Without Textures]]
- [[Exporting and Validating Models for Roblox]]

## Connected notes

[[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · Procedural Blender Assets Start Here · [[Trim Sheets Atlases and Vertex Colors]] · Blender 5 Python Gotchas for Headless Builds

<!-- related:start -->
## Related
[[Curve-Based Modelling in Blender for Roblox]] · [[Hard-Surface Modeling]] · [[Low-Poly and Stylized Modeling]] · [[Blender Workflow for Roblox Creators]] · [[Modeling Fundamentals for Games]] · [[Normal Maps and Detail Baking]] · [[Topology and Edge Flow]] · [[Modular Environment Kits]]
<!-- related:end -->
