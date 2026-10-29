---
tags: [atlas, concept, type/atlas, area/modeling, area/world]
---
# Voxels

<!-- tldr:start -->
> [!tldr] TL;DR
> - Voxels are 4 x 4 x 4 studs; every `resolution` argument must be exactly 4.
> - Voxel edges look rounded and dark: Smooth shading or smoothed normals exported -> Shade Flat; export normals; no smoothing...
> - Voxel model colours shift at a distance: Mipmaps averaging adjacent 1-pixel palette swatches -> Expand swatches to 8 x 8...
> - MagicaVoxel glow voxels are dull in Studio: Emit material does not export -> Separate the glow colour group; give it Neon or...
>
> Cost: TL;DR ~160 tok · whole note ~1.3k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Voxels are 4 x 4 x 4 studs; every `resolution` argument must be exactly 4. (from [[Terrain - Engine Reference Card]])

## Key facts

- Voxel edges look rounded and dark: Smooth shading or smoothed normals exported -> Shade Flat; export normals; no smoothing modifier. ([[Meshing Voxels for Roblox - Greedy Meshing and Export]])
- Voxel model colours shift at a distance: Mipmaps averaging adjacent 1-pixel palette swatches -> Expand swatches to 8 x 8 blocks, or split by colour. ([[MagicaVoxel Goxel and Blockbench Workflows Compared]])
- MagicaVoxel glow voxels are dull in Studio: Emit material does not export -> Separate the glow colour group; give it Neon or an emissive... ([[MagicaVoxel Goxel and Blockbench Workflows Compared]])
- Head 40-45 % of height, face plate 8-10 voxels wide, eyes 2x2-3 with a white highlight pixel. ([[Voxel Chibi Heroes - Class Roster and Rarity Ladder]])
- Auto-placed tiles offset by half a cell: Odd cell counts with centre pivots, or overhanging voxels changing... -> Even cell counts, decoration inside the footprint... ([[Voxel Props Environments and Modular Tiles]])
- Tile size agrees with terrain and the environment voxel grain; even cell counts. ([[Voxel Props Environments and Modular Tiles]])

## Mentioned in

85 notes in 22 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Parts Unions and MeshParts]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Terrain Tools and Terrain API]] · [[Voxel Art - Studs Outlines and Style Kits]]

### 07 Lighting VFX and Audio
[[Lighting Technologies and Settings]]

### 14 3D Modeling
[[Modeling Fundamentals for Games]] · [[Organic and Creature Modeling]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Voxel and Blocky Modeling]]

### 25 Physics and Vehicles
[[Destruction and Fracture]]

### 34 Procedural Generation
[[Noise Functions and Terrain Generation]]

### 44 Materials and Surfaces
[[Terrain Materials and Painting]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Voxel Chibi Heroes - Class Roster and Rarity Ladder]] · [[Voxel Modelling Start Here]] · [[Voxel Palettes - Ramps Hue Shifting and Limits]] · [[Voxel Props Environments and Modular Tiles]] · [[Voxel Scale Grids and Stud Alignment]] · [[Voxel Shading - Baked AO Edges and Lighting]]

### 54 Untextured Stylised Modelling
[[Keeping a Mixed Asset Library Consistent]]

### 55 Modelling Nuance and Readability
[[Bevels Chamfers and Edge Highlights Without Textures]]

### 62 Engine Reference Cards
[[Terrain - Engine Reference Card]]

### Root notes
[[00 Start Here]]

Also mentioned in (not linked): 000 Home · Art Budgets - Triangles Draw Calls Memory · Art Pipeline - Concept to In-Game Asset · Art-Direction Nitpicks - The Principles Behind Them · Asset Pipelines · Baking Lighting and Detail into Textures · Blender Automation with Python · Blender Workflow for Roblox Creators · Boats Buoyancy and Water · Case Study - Instance Cleanup and Place Size · Character and Creature Pipeline · Characters and Humanoids · Clean Stylised Shading - Weighted and Custom Normals · Colour Scripts and Value Structure for Untextured Art · Creature Rig Conventions · Engine Limits, Quotas and Defaults - Cheat Sheet · Environment Art Styles · Environment and Level Pipeline · Faceted Low-Poly - Flat Normals and Facet Size · Flat Colour vs Gradient Atlas vs Vertex Colour · Genre Playbook - Survival and Crafting · Hand-Painted and Stylized Texturing · Impact Decals and Material-Aware Hit Sparks · Infinite and Streamed Worlds · Level of Detail and Model Streaming · Light Sources and Shadows · Low-Poly Creature From a Flat Reference Sheet · Low-Poly and Stylized Modeling · Materials MaterialVariants and SurfaceAppearance · Mesh Optimization for Mobile · MicroProfiler Guide · Mobile and Low-End Optimization · Modeling Weapons and Props · Modeling in Blender for Roblox · Modelling Nuance Start Here · Modular Environment Kits · Open Questions - Whole Vault · Parallel Luau and Actors · Physics and Vehicles Start Here · Pixel Art Pipeline - Aseprite to Roblox Without Blur · Post-Mortem - Building a Melee Action Game · Procedural Blender Assets Start Here · Procedural Creatures - Fused Shells, Quad Cages and Faceting · Procedural Generation Start Here · Procedural World Generation · Rendering Performance · Retopology and Decimation · Rigging in Blender · Roads, Rivers and Paths Carved Along Curves in Terrain · Snow, Sandstorm, Blizzard and Ash Recipes · Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs · Substance Painter and Texturing Tools · SurfaceAppearance PBR Workflow · Teardown - BedWars · Textures Decals and Texture Memory · Trim Sheets Atlases and Vertex Colors · UV Unwrapping · Untextured Stylised Modelling Start Here · Wave Function Collapse on Roblox · Weight Painting and Skinning for Roblox

<!-- atlas:generated -->
