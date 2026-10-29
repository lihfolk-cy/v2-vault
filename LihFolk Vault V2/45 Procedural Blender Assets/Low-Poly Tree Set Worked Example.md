---
tags: [blender, trees, low-poly, foliage, environment, type/guide, area/modeling, level/intermediate]
---
# Low-Poly Tree Set Worked Example

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Canopy left collidable. Symptom: players get stuck on invisible bumps when jumping near trees, and pathfinding agents route...
> - Avoid: Origin at the canopy centre. Symptom: scattered trees float or sink because the scatter tool places pivots on the ground.
> - Avoid: Washed-out greens. Symptom: in-game greens look grey compared with the reference render.
>
> Cost: TL;DR ~130 tok · whole note ~2.1k tok. Read more: ## The recipe, applied · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

![[p45_low_poly_trees.png]]

Three trees built from one script, following the tree recipe in [[Low-Poly and Stylized Modeling]]: an oak, a pine and an autumn birch. Each exports as its own FBX with the origin at the trunk base, ready to scatter ([[Foliage Props and Scatter]]).

**Measured in these builds:**

| Tree | Triangles | Parts |
|---|---|---|
| Oak | 578 | 7-sided flared trunk, two branches, five overlapping canopy clumps |
| Pine | 126 | 6-sided trunk, five stacked 8-sided cone tiers, each twisted a little |
| Autumn birch | 506 | Slim leaning white trunk, dark bark marks, a side branch, four airy clumps |

## The recipe, applied

- **Trunk:** 5-8 sides, tapered, with a root flare (alternate bottom-ring vertices pushed out). A slight lean (quadratic in height) makes it feel grown.
- **Canopy:** 3-5 overlapping displaced icospheres, flattened slightly underneath.
- **Fake light by height:** canopy faces below about a third of the canopy height, or facing down, get the dark green; top faces facing up get the light green; the rest mid. It survives any sky.
- **Flat shading** on purpose; colours by material slot (one material per palette colour).

## The trap: icosphere subdivision levels

In bmesh, `create_icosphere(subdivisions=1)` is the bare 20-face icosahedron. The first render's canopies were pointy gems. `subdivisions=2` (80 faces) gave the rounded faceted clumps the style wants. Check the face count before assuming a level.

## Other fixes from the first render

- Colours looked washed out under AgX; Standard kept the greens and oranges saturated.
- Birch bark marks were too small to see at game distance; marks of about 0.14 x 0.42 studs read.

## Using them in Roblox

- Import with File > Import 3D at stud scale; set `CollisionFidelity` to Box or Hull on the trunk only, and make the canopy non-collidable.
- Five variants of each tree with random yaw, scale 0.6 to 1.5 and small tilts read as a forest.
- At 126-578 triangles each, hundreds fit in a scene; use streaming for very large forests.

Related: [[Foliage Props and Scatter]], [[Procedural Blender Assets Start Here]].

## Nuances and edge cases

1. **Triangle count is not the real cost; instance count is.** A 126-triangle pine is nearly free to draw, but 2,000 separate pine MeshParts are 2,000 instances the engine has to stream, cull and track. Past a few hundred trees, the instance count and the number of distinct meshes matter more than triangles. Reuse the same five mesh assets everywhere so the renderer can batch identical meshes, and resist making "one more variant" for every grove (rule of thumb).
2. **One material slot per palette colour is fine in Blender, costly in Roblox.** A Roblox MeshPart carries one texture set, and the 3D importer generally splits a mesh with several materials into several MeshParts (observed behaviour, not confirmed in the docs), so a five-colour tree can arrive as five parts. The cheaper path is to keep the colours as vertex colours or a tiny palette texture on one UV atlas, so each tree imports as one or two MeshParts (trunk and canopy). Decide this before you scatter, not after.
3. **Trunk and canopy as separate meshes is a deliberate trade.** Splitting them lets the trunk collide and the canopy not, and lets you swap canopy colour per season. Merging them halves the instance count. For decorative background forests, merge; for trees players walk between, split.
4. **Flat shading and the 4-influence limit do not interact, but normals do.** Flat shading duplicates vertices along every hard edge. A 578-triangle oak can carry well over 578 vertices after export. This rarely matters for static trees but explains why the vertex count in the importer is higher than Blender's viewport suggests.
5. **"Fake light by height" breaks under strong coloured lighting.** The baked dark, mid and light greens assume a neutral sky. Under a red sunset or a purple night zone, the painted gradient fights the real light and the trees look flat or muddy. Either keep the gradient subtle (two steps of value, not hue) or bake a variant set per zone mood.
6. **Scale range 0.6 to 1.5 has a collision cost.** Scaling a MeshPart scales its collision too, and Hull or Box fidelity is recomputed per size. Very small trees (0.6) can leave a trunk collider players catch on; very large ones can leave canopy gaps a player can stand inside if the canopy is collidable by mistake.
7. **Phone vs PC.** On low-end phones the risk is draw distance, not polycount: hundreds of trees in view at once add up. Keep a distance at which far trees are removed or replaced by a cheaper impostor, and rely on streaming so a phone never holds the whole forest (rule of thumb).
8. **Server count does not change the art cost but does change join time.** A forest of 3,000 placed trees ships to every client on join. Large forests are a join-time problem before they are a frame-rate problem, so streaming or client-side spawning from a seed pays off as maps grow.
9. **Procedural trees should be seeded.** If the script uses random clump placement without a fixed seed, every rebuild produces slightly different trees, which breaks any hand-placed props that were aligned to the old shape. Fix the seed per variant and commit it with the script.

## Common mistakes

1. **Canopy left collidable.** Symptom: players get stuck on invisible bumps when jumping near trees, and pathfinding agents route around phantom walls. Fix: set CanCollide false on the canopy and use Box fidelity on the trunk only.
2. **Origin at the canopy centre.** Symptom: scattered trees float or sink because the scatter tool places pivots on the ground. Fix: put the origin at the trunk base before export, as this build does, and check it after import.
3. **Washed-out greens.** Symptom: in-game greens look grey compared with the reference render. Fix: render previews under Standard view transform so the preview matches the flat colours Roblox shows.
4. **Icosphere at subdivision 1.** Symptom: canopies look like sharp gems. Fix: use subdivision 2 and check the face count.
5. **Every tree a unique mesh.** Symptom: memory climbs and join time grows as the forest grows. Fix: a handful of variants, varied by yaw, scale and tilt at placement.
6. **Bark marks too small to read.** Symptom: birches look like plain white poles at play distance. Fix: size details for the camera distance players actually use, here about 0.14 by 0.42 studs.
7. **Scatter on slopes without tilt clamp.** Symptom: trees lean at the slope angle and look like they are falling. Fix: align only partially to the surface normal, or not at all, and clamp tilt to a few degrees.

## Related decisions

- [[Art Budgets - Triangles Draw Calls Memory]]: sets the per-scene numbers these tree counts must fit inside.
- [[Level of Detail and Model Streaming]]: how far trees can be culled or swapped before players notice.
- [[Instance Streaming]]: the engine feature that keeps a large forest off a phone's memory.
- [[Collision and Physics Geometry]]: picking Box, Hull or none for trunks and canopies.
- [[Trim Sheets Atlases and Vertex Colors]]: the alternative to one material slot per colour.
- [[Zone and Biome Art Direction]]: how a tree palette should shift between zones.
- [[Seeds Determinism and Reproducible Worlds]]: keep procedural variants stable between rebuilds.
- [[Noise Functions and Terrain Generation]]: drive tree density from noise instead of uniform scatter.
- [[Case Study - Cutting a Million Instances]]: what happens when placed props are allowed to grow unchecked.

## Connected notes
<!-- auto-links:start -->
[[The Gradient Palette Texture Workflow]] · Faceted Low-Poly - Flat Normals and Facet Size · Triangle Budget · Flat Colour vs Gradient Atlas vs Vertex Colour · Clean Stylised Shading - Weighted and Custom Normals · Voxel Props Environments and Modular Tiles
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Stylised Shop Stand Worked Example]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Stylised Log Cabin Worked Example]] · [[Dramatic Showcase Renders in Eevee]] · [[Chibi Character Rules in Practice]] · [[Low-Poly Creature From a Flat Reference Sheet]] · [[Blender 5 Python Gotchas for Headless Builds]] · [[Matching a Concept Sheet - Boss Creature Case Study]] · [[Mesh VFX Packs Built in Blender]]
<!-- related:end -->
