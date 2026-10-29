---
tags: [atlas, concept, type/atlas, area/modeling, area/animation]
---
# Topology

<!-- tldr:start -->
> [!tldr] TL;DR
> - Topology is how the faces of a mesh are connected: which vertices share edges, where the loops run, where triangles and poles sit.
> - Avoid: Obsessing over topology on static props -> Shading and triangle count are what matter there.
> - Avoid: Treating decimation output as final topology.
> - Fast, automatic, keeps UVs mostly intact, makes triangle soup topology.
>
> Cost: TL;DR ~130 tok · whole note ~780 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Topology is how the faces of a mesh are connected: which vertices share edges, where the loops run, where triangles and poles sit. (from [[Topology and Edge Flow]])

Topology: How a mesh's polygons are arranged; decides how it deforms. (from [[Glossary]])

## Key facts

- Avoid: Obsessing over topology on static props -> Shading and triangle count are what matter there. ([[Topology and Edge Flow]])
- Avoid: Treating decimation output as final topology. ([[Procedural Creatures - Fused Shells, Quad Cages and Faceting]])
- Fast, automatic, keeps UVs mostly intact, makes triangle soup topology. ([[Retopology and Decimation]])
- Mouth line (the edge between lips or jaw plates) should be a clean loop so the jaw can open without the face tearing; see Topology and Edge Flow. ([[Organic and Creature Modeling]])

## Mentioned in

46 notes in 17 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Modeling in Blender for Roblox]]

### 08 Animation
[[Bones and Skinned Meshes]] · [[Weight Painting and Skinning for Roblox]]

### 13 Production and Case Studies
[[Case Study - Building LihFolk V2 with AI Agents]]

### 14 3D Modeling
[[Bezier Curves and Splines for Modellers]] · [[Blender Workflow for Roblox Creators]] · [[Hard-Surface Modeling]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Modeling Fundamentals for Games]] · [[Normal Maps and Detail Baking]] · [[Organic and Creature Modeling]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Procedural Creatures - Fused Shells, Quad Cages and Faceting]] · [[Retopology and Decimation]] · [[Topology and Edge Flow]] · [[UGC Avatar Items and Accessories]] · [[UV Unwrapping]]

### 15 AI Tools
[[AI 3D Model Generation Outside Roblox]] · [[AI in Roblox Development Overview]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]]

### 17 Pipelines
[[Art Pipeline - Concept to In-Game Asset]]

### 28 Business and Careers
[[Building a Portfolio as a Roblox Developer]]

### 37 Avatars and UGC
[[Layered Clothing Creation Workflow]]

### 54 Untextured Stylised Modelling
[[Faceted Low-Poly - Flat Normals and Facet Size]]

### 55 Modelling Nuance and Readability
[[Spending Triangles Where the Camera Looks]]

Also mentioned in (not linked): 00 Start Here · Clean Stylised Shading - Weighted and Custom Normals · Evaluating AI Tools - A Practical Rubric · Exporting and Validating Models for Roblox · Glossary · Ground Fitting Pipeline · Keeping a Mixed Asset Library Consistent · Mesh Gates for Generated Models - Symmetry, Seating and Caps · Mesh Optimization for Mobile · Pathfinding · Procedural Blender Assets Start Here · Procedural Model Kits - Lessons · Resource Library - Assets (creation) · Retargeting Animations Between Rigs · Skinning Weights · Studio Assistant and AI Tools · Texturing and PBR Baking · The Gradient Palette Texture Workflow · Triangle Budget · Untextured Stylised Modelling Start Here · Voxel Modelling Start Here

<!-- atlas:generated -->
