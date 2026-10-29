---
tags: [atlas, concept, type/atlas, area/modeling, area/world]
---
# Modular Kits

<!-- tldr:start -->
> [!tldr] TL;DR
> - A modular kit is a small set of pieces (walls, corners, floors, stairs, pillars, trims, props) designed to snap together on a...
> - Right: apply transforms before export; origin at the bottom for floor props, back for wall props, a corner for modular pieces...
> - A procedurally generated hub kit with low-resolution trim was judged "low detail / pixelated" next to the previous hub, which...
> - Modular kit pieces. A wall segment has no silhouette on its own; test the assembled building instead.
>
> Cost: TL;DR ~170 tok · whole note ~410 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A modular kit is a small set of pieces (walls, corners, floors, stairs, pillars, trims, props) designed to snap together on a grid, so a large world can be built from a few dozen meshes. (from [[Modular Environment Kits]])

## Key facts

- Right: apply transforms before export; origin at the bottom for floor props, back for wall props, a corner for modular pieces (recipe defaults). ([[AI Pitfalls - Assets and Import]])
- A procedurally generated hub kit with low-resolution trim was judged "low detail / pixelated" next to the previous hub, which used painted per-family texture sheets over 118 modular pieces. ([[Modeling in Blender for Roblox]])
- Modular kit pieces. A wall segment has no silhouette on its own; test the assembled building instead. ([[Shape Language and Silhouette Testing]])
- Modular pieces that will be placed against unknown neighbours: AO baked on a wall's base assumes a floor; if the piece is also used floating, it looks dirty. ([[Voxel Shading - Baked AO Edges and Lighting]])

## Mentioned in

7 notes in 5 sections. The 7 most relevant are linked:

### 06 World Building and Art
[[Modeling in Blender for Roblox]]

### 14 3D Modeling
[[Modeling Fundamentals for Games]] · [[Modular Environment Kits]]

### 15 AI Tools
[[AI Pitfalls - Assets and Import]]

### 53 Voxel Modelling Deep Dive
[[Voxel Props Environments and Modular Tiles]] · [[Voxel Shading - Baked AO Edges and Lighting]]

### 55 Modelling Nuance and Readability
[[Shape Language and Silhouette Testing]]

<!-- atlas:generated -->
