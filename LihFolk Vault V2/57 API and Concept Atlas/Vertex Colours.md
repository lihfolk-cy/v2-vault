---
tags: [atlas, concept, type/atlas, area/modeling, area/world]
---
# Vertex Colours

<!-- tldr:start -->
> [!tldr] TL;DR
> - Vertex colours store an RGB (and optionally alpha) value per face corner on the mesh.
> - Imported mesh is plain grey though it was coloured in Blender: glTF exporter did not write the colour attribute -> Set the...
> - Patchy triangle streaks that no `Color` or `Material` change removes: Unwanted generator vertex colours multiplying -> Ignore...
> - Baked AO blotchy on big faces: AO baked to vertex colours on greedy rectangles -> Texture AO for greedy meshes, or per-cell...
>
> Cost: TL;DR ~160 tok · whole note ~980 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Vertex colours store an RGB (and optionally alpha) value per face corner on the mesh. (from [[Trim Sheets Atlases and Vertex Colors]])

## Key facts

- Imported mesh is plain grey though it was coloured in Blender: glTF exporter did not write the colour attribute -> Set the exporter's vertex colour option to write... ([[Flat Colour vs Gradient Atlas vs Vertex Colour]])
- Patchy triangle streaks that no `Color` or `Material` change removes: Unwanted generator vertex colours multiplying -> Ignore Vertex Colors on import, or paint white... ([[Flat Colour vs Gradient Atlas vs Vertex Colour]])
- Baked AO blotchy on big faces: AO baked to vertex colours on greedy rectangles -> Texture AO for greedy meshes, or per-cell quads near occluders. ([[Voxel Shading - Baked AO Edges and Lighting]])
- Colour route chosen (palette texture, per-colour meshes, vertex colours or painted texture) before picking the tool. ([[MagicaVoxel Goxel and Blockbench Workflows Compared]])
- Vertex colours ACTIVE, `MeshPart.Color` white. ([[AI Pitfalls - Assets and Import]])

## Mentioned in

61 notes in 14 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[House Construction Method - Modular Kit Workflow]] · [[Modeling in Blender for Roblox]] · [[Parts Unions and MeshParts]]

### 08 Animation
[[3D Importer Settings Reference]] · [[Exporting FBX vs GLB]]

### 14 3D Modeling
[[Exporting and Validating Models for Roblox]] · [[Hand-Painted and Stylized Texturing]] · [[Low-Poly and Stylized Modeling]] · [[Modeling Fundamentals for Games]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Texturing and PBR Baking]] · [[Trim Sheets Atlases and Vertex Colors]]

### 15 AI Tools
[[AI Pitfalls - Assets and Import]]

### 17 Pipelines
[[Art Pipeline - Concept to In-Game Asset]] · [[Environment and Level Pipeline]]

### 44 Materials and Surfaces
[[Baking Lighting and Detail into Textures]]

### 45 Procedural Blender Assets
[[Stylised Log Cabin Worked Example]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Voxel Shading - Baked AO Edges and Lighting]]

### 54 Untextured Stylised Modelling
[[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Keeping a Mixed Asset Library Consistent]] · [[The Gradient Palette Texture Workflow]] · [[Untextured Stylised Modelling Start Here]]

### 55 Modelling Nuance and Readability
[[Bevels Chamfers and Edge Highlights Without Textures]] · [[Style Bibles for Consistent Models]]

Also mentioned in (not linked): 00 Start Here · AI 3D Model Generation Outside Roblox · AI Material and Texture Generation · Blender Automation with Python · Case Study - Building LihFolk V2 with AI Agents · Draw Calls · Glossary · Hard-Surface Modeling · Importing Models and Rigs · Lighting Untextured Art in Roblox · Low-Poly Creature From a Flat Reference Sheet · Low-Poly Tree Set Worked Example · Materials and Surfaces Start Here · Mesh Optimization for Mobile · Meshing Voxels for Roblox - Greedy Meshing and Export · Modelling Nuance Start Here · Modular Environment Kits · Normal Maps and Detail Baking · Open Questions - Whole Vault · Pixel Art Pipeline - Aseprite to Roblox Without Blur · Procedural Model Kits - Lessons · Spending Triangles Where the Camera Looks · Stylised vs Realistic Material Pipelines · Substance Painter and Texturing Tools · SurfaceAppearance PBR Workflow · Texel Density · Textures Decals and Texture Memory · Tiling Trim Sheets and Decal Tricks · UGC Avatar Items and Accessories · UV Unwrapping · Voxel Art - Studs Outlines and Style Kits · Voxel Modelling Start Here · Voxel Palettes - Ramps Hue Shifting and Limits · Voxel and Blocky Modeling · Water Sky and Atmosphere Art · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
