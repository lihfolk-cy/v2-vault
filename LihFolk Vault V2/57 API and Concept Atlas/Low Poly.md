---
tags: [atlas, concept, type/atlas, area/modeling, area/ai]
---
# Low Poly

<!-- tldr:start -->
> [!tldr] TL;DR
> - Retopology: Rebuilding a mesh with clean, low-poly topology.
> - Hard edges are UV seams; triangulated low-poly; smoothing final.
> - Avoid: Smooth shading a low poly with no normal fix -> Weighted Normal / Harden Normals.
> - On the target (low-poly) object's material, add an Image Texture node with a new image at the target resolution.
>
> Cost: TL;DR ~130 tok · whole note ~860 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Retopology: Rebuilding a mesh with clean, low-poly topology. (from [[Glossary]])

## Key facts

- Hard edges are UV seams; triangulated low-poly; smoothing final. ([[Normal Maps and Detail Baking]])
- Avoid: Smooth shading a low poly with no normal fix -> Weighted Normal / Harden Normals. ([[Hard-Surface Modeling]])
- On the target (low-poly) object's material, add an Image Texture node with a new image at the target resolution. ([[Texturing and PBR Baking]])
- Use a smooth low-poly shape with a flat colour. ([[Faceted Low-Poly - Flat Normals and Facet Size]])

## Mentioned in

61 notes in 17 sections. The 25 most relevant are linked:

### 14 3D Modeling
[[Blender Workflow for Roblox Creators]] · [[Hand-Painted and Stylized Texturing]] · [[Hard-Surface Modeling]] · [[Low-Poly and Stylized Modeling]] · [[Normal Maps and Detail Baking]] · [[Organic and Creature Modeling]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Texturing and PBR Baking]] · [[Trim Sheets Atlases and Vertex Colors]]

### 15 AI Tools
[[AI 3D Model Generation Outside Roblox]] · [[AI Image Generation for Icons Thumbnails and Concepts]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]]

### 44 Materials and Surfaces
[[Baking Lighting and Detail into Textures]]

### 45 Procedural Blender Assets
[[Chibi Character Rules in Practice]] · [[Low-Poly Creature From a Flat Reference Sheet]] · [[Stylised Shop Stand Worked Example]]

### 52 Core Concepts
[[Triangle Budget]]

### 53 Voxel Modelling Deep Dive
[[Voxel Props Environments and Modular Tiles]]

### 54 Untextured Stylised Modelling
[[Clean Stylised Shading - Weighted and Custom Normals]] · [[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Keeping a Mixed Asset Library Consistent]] · [[The Gradient Palette Texture Workflow]] · [[Untextured Stylised Modelling Start Here]]

### 55 Modelling Nuance and Readability
[[Bevels Chamfers and Edge Highlights Without Textures]] · [[Spending Triangles Where the Camera Looks]]

Also mentioned in (not linked): 00 Start Here · AI Material and Texture Generation · Blender Automation with Python · Blender MCP · Building a Portfolio as a Roblox Developer · Creator Store and Toolbox Safety · Dash VFX Presentation on an R15 Rig · Draw Calls · Environment Art Styles · Flat Colour vs Gradient Atlas vs Vertex Colour · Foliage Props and Scatter · Glossary · Hiring Freelancers and Revenue Shares · Layered Clothing Creation Workflow · Lighting Technologies and Settings · Lighting Untextured Art in Roblox · Low-Poly Tree Set Worked Example · Matching a Concept Sheet - Boss Creature Case Study · Materials and Surfaces Start Here · Mesh Optimization for Mobile · Modeling Fundamentals for Games · Modelling Nuance Start Here · Modular Environment Kits · Procedural Blender Assets Start Here · Procedural Creatures - Fused Shells, Quad Cages and Faceting · Proportion Exaggeration and Gameplay Distance · Retopology and Decimation · Shape Language and Silhouette Testing · Stylised vs Realistic Material Pipelines · Stylized Lighting Recipes · Topology and Edge Flow · UGC Avatar Items and Accessories · UV Unwrapping · Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver · Voxel Modelling Start Here · Voxel and Blocky Modeling

<!-- atlas:generated -->
