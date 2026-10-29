---
tags: [atlas, concept, type/atlas, area/modeling, area/materials]
---
# Normal Maps

<!-- tldr:start -->
> [!tldr] TL;DR
> - A normal map lets a 2,000-triangle low-poly mesh shade like a 200,000-triangle sculpt by storing, per texel, which way the...
> - One suffix scheme; normal maps OpenGL; meshes exported with tangents.
> - Roblox docs: a uniform [127, 127, 255] is a flat normal map.
> - Floating detail is allowed. Bolts, vents and panels can be separate floating meshes hovering on the surface; the bake projects...
>
> Cost: TL;DR ~140 tok · whole note ~630 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A normal map lets a 2,000-triangle low-poly mesh shade like a 200,000-triangle sculpt by storing, per texel, which way the surface "really" faces. (from [[Normal Maps and Detail Baking]])

Normal map: A texture that fakes surface detail through lighting. (from [[Glossary]])

## Key facts

- One suffix scheme; normal maps OpenGL; meshes exported with tangents. ([[SurfaceAppearance PBR Workflow]])
- Roblox docs: a uniform [127, 127, 255] is a flat normal map. ([[Normal Maps and Detail Baking]])
- Floating detail is allowed. Bolts, vents and panels can be separate floating meshes hovering on the surface; the bake projects them into the normal map. ([[Hard-Surface Modeling]])
- Skip maps that carry no information. A fully non-metal prop does not need a metalness map; a flat-normal stylised prop does not need a normal map. ([[Texturing and PBR Baking]])

## Mentioned in

34 notes in 8 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Environment Art Styles]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Modeling in Blender for Roblox]] · [[Voxel Art - Studs Outlines and Style Kits]]

### 14 3D Modeling
[[Blender Workflow for Roblox Creators]] · [[Exporting and Validating Models for Roblox]] · [[Hard-Surface Modeling]] · [[Modeling Fundamentals for Games]] · [[Normal Maps and Detail Baking]] · [[Retopology and Decimation]] · [[Substance Painter and Texturing Tools]] · [[Texturing and PBR Baking]] · [[Topology and Edge Flow]] · [[Trim Sheets Atlases and Vertex Colors]] · [[UV Unwrapping]] · [[Voxel and Blocky Modeling]]

### 15 AI Tools
[[AI 3D Model Generation Outside Roblox]] · [[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · [[AI Material and Texture Generation]]

### 37 Avatars and UGC
[[Layered Clothing Creation Workflow]]

### 44 Materials and Surfaces
[[Baking Lighting and Detail into Textures]] · [[MaterialService and Custom Materials]] · [[Stylised vs Realistic Material Pipelines]] · [[SurfaceAppearance PBR Workflow]]

### 53 Voxel Modelling Deep Dive
[[Voxel Shading - Baked AO Edges and Lighting]]

Also mentioned in (not linked): 00 Start Here · Glossary · Hand-Painted and Stylized Texturing · Materials and Surfaces Start Here · Organic and Creature Modeling · Procedural Materials and Skies - Lessons · Skill - Roblox Asset Import · Tiling Trim Sheets and Decal Tricks · Triangle Budget

<!-- atlas:generated -->
