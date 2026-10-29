---
tags: [core-concept, art, 3d-modeling, performance, type/reference, area/performance, level/beginner, area/modeling]
---
# Triangle Budget

<!-- tldr:start -->
> [!tldr] TL;DR
> - Roblox enforces hard limits per mesh: a MeshPart import is limited to 20,000 triangles, and UGC avatar items have their own...
> - Budget the scene, then split it. Decide what the slowest target device can draw at once, subtract UI, characters and effects...
> - Copies multiply. A 2,000-triangle bush placed 400 times is 800,000 triangles if all are visible.
> - Silhouette needs triangles; flat faces do not.
>
> Cost: TL;DR ~140 tok · whole note ~990 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

A **triangle budget** is the agreed maximum number of triangles for an asset or a scene: "a common enemy is 3,000 triangles", "a weapon is 1,500", "the whole visible scene stays under 300,000 on phones". Budgets turn "is this too heavy?" into a check anyone can run.

## Why it matters on Roblox

Roblox enforces hard limits per mesh: a MeshPart import is limited to 20,000 triangles, and UGC avatar items have their own lower limits (Roblox docs, mesh and UGC requirements, as of October 2026). Below the hard limit, the real constraint is the scene on a low-end phone, where many copies of moderately heavy meshes add up fast. Roblox also generates lower levels of detail for meshes automatically, which helps at distance but not up close.

## The nuance most people miss

1. **Budget the scene, then split it.** Decide what the slowest target device can draw at once, subtract UI, characters and effects, and divide the rest among environment assets. Per-asset numbers without a scene total are arbitrary.
2. **Copies multiply.** A 2,000-triangle bush placed 400 times is 800,000 triangles if all are visible. Foliage and props, not hero assets, usually break the budget.
3. **Silhouette needs triangles; flat faces do not.** Spend triangles on outlines and curves the player sees, and take them out of flat areas and hidden undersides. Normal maps carry surface detail more cheaply than geometry.
4. **Collision is separate.** A mesh's collision fidelity can cost far more than its render triangles. Set `CollisionFidelity` to Box or Hull for props players do not need precise contact with, and turn collisions off on pure decoration.
5. **Draw calls usually matter more.** A scene of 300 unique low-poly meshes can run worse than 30 batched medium-poly meshes. Check [[Draw Calls]] before cutting triangles.
6. **Characters are seen up close.** Players stare at their own avatar and pets; give them a larger share than background props.

## Tiny example

| Asset class | Budget (rule of thumb, mobile-first) | Copies on screen |
|---|---|---|
| Hero weapon | 1,000 to 3,000 | 1 to 10 |
| Common enemy | 2,000 to 5,000 | 5 to 20 |
| Small prop | 100 to 800 | 50 to 200 |
| Tree or bush | 300 to 1,500 | 100 to 400 |

Multiply budget by copies for each row and compare the total with the scene budget before modelling starts.

## Where this shows up

- [[Art Budgets - Triangles Draw Calls Memory]]: the full budget note.
- [[Mesh Optimization for Mobile]]: cutting triangles where it counts.
- [[Retopology and Decimation]]: reducing existing meshes.
- [[Low-Poly and Stylized Modeling]]: styles built on few triangles.
- [[Topology and Edge Flow]]: placing triangles well.
- [[Exporting and Validating Models for Roblox]]: checking limits before upload.
- [[Collision and Physics Geometry]]: collision cost versus render cost.
- [[Level of Detail and Model Streaming]]: fewer triangles at distance.
- [[UGC Avatar Items and Accessories]]: UGC limits.
- [[Low-Poly Tree Set Worked Example]]: budgets applied to a tree set.
- [[Foliage Props and Scatter]]: the multiplier problem.
- [[Skill - Roblox Asset Import]]: an import checklist with budgets.

Related concepts: [[Draw Calls]], [[Texel Density]], [[Skinning Weights]], [[Instance Count]].

## Connected notes
<!-- auto-links:start -->
[[Spending Triangles Where the Camera Looks]] · Modelling Nuance Start Here · Modeling in Blender for Roblox · AI 3D Model Generation Outside Roblox · Modeling Fundamentals for Games · Roblox Generative AI - Cube Mesh and Texture Generation · [[Core Concepts Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Frame Budget]] · [[Streaming Radius]] · [[Thumbnail Contrast]] · [[Object Pooling]] · [[Accessibility Contrast]] · [[Hit-Stop]] · [[Replication Boundary]] · [[Safe Area]]
<!-- related:end -->
