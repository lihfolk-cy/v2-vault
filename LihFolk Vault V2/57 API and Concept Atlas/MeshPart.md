---
tags: [atlas, api, type/atlas, area/modeling, area/animation, api/MeshPart]
---
# MeshPart

<!-- tldr:start -->
> [!tldr] TL;DR
> - A MeshPart's pivot is the centre of the mesh's bounding box unless you change `PivotOffset`.
> - TextureID wins over Material. A MeshPart with a TextureID ignores Material changes until the TextureID is cleared (measured).
> - Vertex colours ACTIVE, `MeshPart.Color` white.
> - Avoid: Relying on MeshPart collision for animated limbs -> Hitbox parts on bones, or data-driven hits.
>
> Cost: TL;DR ~140 tok · whole note ~1.3k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A MeshPart's pivot is the centre of the mesh's bounding box unless you change `PivotOffset`. (from [[Parts Unions and MeshParts]])

API snapshot: class, inherits `TriangleMeshPart` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- TextureID wins over Material. A MeshPart with a TextureID ignores Material changes until the TextureID is cleared (measured). ([[Materials MaterialVariants and SurfaceAppearance]])
- Vertex colours ACTIVE, `MeshPart.Color` white. ([[AI Pitfalls - Assets and Import]])
- Avoid: Relying on MeshPart collision for animated limbs -> Hitbox parts on bones, or data-driven hits. ([[Bones and Skinned Meshes]])
- One texture set per Roblox MeshPart. ([[Substance Painter and Texturing Tools]])
- Roblox enforces hard limits per mesh: a MeshPart import is limited to 20,000 triangles, and UGC avatar items have their own... ([[Triangle Budget]])

## Mentioned in

93 notes in 25 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Explorer Properties and Selection]]

### 06 World Building and Art
[[Collision and Physics Geometry]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Modeling in Blender for Roblox]] · [[Parts Unions and MeshParts]]

### 08 Animation
[[Bones and Skinned Meshes]] · [[Importing Models and Rigs]] · [[Rigging in Blender]]

### 13 Production and Case Studies
[[Asset Pipelines]]

### 14 3D Modeling
[[Exporting and Validating Models for Roblox]] · [[Modeling Fundamentals for Games]] · [[Substance Painter and Texturing Tools]] · [[Texturing and PBR Baking]]

### 15 AI Tools
[[AI Material and Texture Generation]] · [[AI Pitfalls - Assets and Import]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]]

### 17 Pipelines
[[Art Pipeline - Concept to In-Game Asset]]

### 44 Materials and Surfaces
[[SurfaceAppearance PBR Workflow]]

### 46 Resource Library
[[Links - Importing into Studio]]

### 47 Game Feel and Juice
[[Squash Stretch and Anticipation in UI and Characters]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]]

### 54 Untextured Stylised Modelling
[[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[The Gradient Palette Texture Workflow]]

### 55 Modelling Nuance and Readability
[[Bevels Chamfers and Edge Highlights Without Textures]]

Also mentioned in (not linked): 3D Importer Settings Reference · AI 3D Model Generation Outside Roblox · Accessories and Armor That Follow Animation · Art Budgets - Triangles Draw Calls Memory · Avatar Context Menus Profiles and Social Surfaces · Baking Lighting and Detail into Textures · Blender Automation with Python · Blender MCP · Blender Workflow for Roblox Creators · Cars with Constraints - Suspension Steering and Drive · Colour Scripts and Value Structure for Untextured Art · Creature Rig Conventions · Destruction and Fracture · Draw Calls · Engine and API Changes 2025-2026 · External Tooling - Rojo Wally Selene StyLua · Faceted Low-Poly - Flat Normals and Facet Size · Facial Animation and Dynamic Heads · Foliage Props and Scatter · Glossary · Grid Placement and Player Building Systems · House Construction Method - Modular Kit Workflow · Impact Decals and Material-Aware Hit Sparks · Keeping a Mixed Asset Library Consistent · Layered Clothing Cages and Animation · Layered Clothing Creation Workflow · Level of Detail and Model Streaming · Lighting Untextured Art in Roblox · Low-Poly Tree Set Worked Example · Low-Poly and Stylized Modeling · Melee Combat System End to End · Mesh Optimization for Mobile · Modular Environment Kits · Normal Maps and Detail Baking · Open Questions - Whole Vault · Organic and Creature Modeling · Packages and Asset Reuse · Pet Hatching and Following End to End · Physics Assemblies and Constraints · Rendering Performance · Retopology and Decimation · Roblox Changes 2025-2026 · Roblox Studio Assistant · Roblox Studio MCP Server · Ropes Chains and Soft Bodies · Skeleton Library · Snippets - Building and Sampling Clips · Spending Triangles Where the Camera Looks · Studio Assistant and AI Tools · Style Bibles for Consistent Models · Stylised Log Cabin Worked Example · Textures Decals and Texture Memory · Topology and Edge Flow · Triangle Budget · Trim Sheets Atlases and Vertex Colors · UV Unwrapping · Untextured Stylised Modelling Start Here · VFX Performance Budgets and Culling · Voxel Characters - Proportions Joints and Rigging · Voxel Modelling Start Here · Voxel Palettes - Ramps Hue Shifting and Limits · Voxel Props Environments and Modular Tiles · Voxel Scale Grids and Stud Alignment · Voxel Shading - Baked AO Edges and Lighting · Voxel and Blocky Modeling · Weapon Design Rig Builder · Weight Painting and Skinning for Roblox · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
