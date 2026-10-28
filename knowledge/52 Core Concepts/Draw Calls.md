---
tags: [core-concept, performance, rendering, art]
---
# Draw Calls

A **draw call** is one request from the engine to the GPU to draw a batch of geometry with one set of material and texture state. The cost of a scene often depends more on how many draw calls it needs than on how many triangles it has, because each call carries CPU overhead on the render thread.

## Why it matters on Roblox

Phones are the bottleneck. A mid-range phone that draws a million triangles comfortably can stall at a few hundred unbatched draw calls (rule of thumb). Roblox batches automatically where it can: copies of the same mesh with the same material and textures can be drawn together through instancing (Roblox docs, "Improve performance", as of October 2026, describes this in general terms; exact batching rules are not documented in detail). Your job is to give the engine things it can batch.

## The nuance most people miss

1. **Unique meshes and unique textures break batching.** Fifty slightly different rock meshes, each with its own texture, can cost fifty times more calls than fifty copies of one rock. A kit of five rocks rotated and scaled reads as variety and batches well.
2. **Colour changes are usually cheap; texture changes are not.** Varying `Color` on copies of a part or MeshPart tends to keep them batchable; giving each copy its own `SurfaceAppearance` or Decal does not (rule of thumb, measure on your target device).
3. **Transparency costs extra.** Transparent and semi-transparent surfaces are sorted and drawn separately, often unbatched, and overdraw multiplies fill cost. Glass walls, many particles, and stacked UI frames all count.
4. **Shadows and UI draw too.** Shadow-casting geometry may be drawn again for shadows. Every visible GUI element with its own image adds calls; texture atlases (one sheet for many icons) help UI as much as meshes.
5. **Triangles still matter on low-end devices**, just usually second. Optimise calls first, then triangles.

## Tiny example

A market stall built from 40 unique MeshParts, each with its own SurfaceAppearance: roughly 40 calls per stall, times 20 stalls. The same stall built from a trim sheet (one texture shared by all pieces) and 6 reused meshes: a handful of batches for the whole market. The look is the same; the phone frame time is not.

## Where this shows up

- [[Art Budgets - Triangles Draw Calls Memory]]: the budgets this concept feeds.
- [[Rendering Performance]]: measuring render cost.
- [[Trim Sheets Atlases and Vertex Colors]]: the main art technique to share textures.
- [[Tiling Trim Sheets and Decal Tricks]]: more ways to reuse one texture.
- [[Modular Environment Kits]]: reuse that batches.
- [[Mesh Optimization for Mobile]]: mesh-side savings.
- [[Particle Emitters In Depth]]: transparent overdraw from particles.
- [[VFX Performance Budgets and Culling]]: limiting effect draws.
- [[Foliage Props and Scatter]]: thousands of copies that must batch.
- [[Light Sources and Shadows]]: shadow casting adds draws.
- [[UI Asset Pipeline]]: atlases for icons.
- [[Low-Poly Tree Set Worked Example]]: a small kit designed for reuse.
- [[Mobile and Low-End Optimization]]: where call counts hurt most.

Related concepts: [[Frame Budget]], [[Triangle Budget]], [[Texel Density]], [[Instance Count]].

## Connected notes
<!-- auto-links:start -->
[[Materials and Surfaces Start Here]] · [[Textures Decals and Texture Memory]] · [[Modeling in Blender for Roblox]] · [[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Stylised vs Realistic Material Pipelines]] · [[Skill - Roblox Asset Import]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
