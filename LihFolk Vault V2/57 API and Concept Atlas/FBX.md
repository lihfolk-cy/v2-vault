---
tags: [atlas, concept, type/atlas, area/animation, area/modeling]
---
# FBX

<!-- tldr:start -->
> [!tldr] TL;DR
> - FBX adds its own centimetre scale (Roblox's export page: Apply Scalings "FBX Unit Scale").
> - Avoid: Default FBX export, or two scale fixes stacked -> Apply Scalings: FBX Unit Scale, other scales 1.0; or GLB, which...
> - Avoid: Leaf bones left on (FBX) -> Add Leaf Bones off.
> - Avoid: Blockbench ASCII FBX into Blender -> Use glTF/GLB or OBJ.
>
> Cost: TL;DR ~130 tok · whole note ~890 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

FBX adds its own centimetre scale (Roblox's export page: Apply Scalings "FBX Unit Scale"). (from [[Modeling in Blender for Roblox]])

## Key facts

- Avoid: Default FBX export, or two scale fixes stacked -> Apply Scalings: FBX Unit Scale, other scales 1.0; or GLB, which... ([[Exporting FBX vs GLB]])
- Avoid: Leaf bones left on (FBX) -> Add Leaf Bones off. ([[Exporting FBX vs GLB]])
- Avoid: Blockbench ASCII FBX into Blender -> Use glTF/GLB or OBJ. ([[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]])
- Avoid: Mixing FBX scale methods -> One method: FBX Unit Scale, or use GLB. ([[Blender Workflow for Roblox Creators]])
- Shading fine in Blender, smeared in Studio: Modifiers not applied, or FBX Smoothing set to Face/Edge -> Apply modifiers; FBX Smoothing Normals Only. ([[Clean Stylised Shading - Weighted and Custom Normals]])

## Mentioned in

57 notes in 15 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Modeling in Blender for Roblox]] · [[Parts Unions and MeshParts]]

### 08 Animation
[[3D Importer Settings Reference]] · [[Animation Capture and Mocap]] · [[Animation Data from Blender to Roblox]] · [[Blender Armature and Bone Roll Conventions]] · [[Exporting FBX vs GLB]] · [[Free Mocap and Mixamo Licensing for Roblox]] · [[Importing Models and Rigs]] · [[LihFolk R15 Keyframe Pipeline]] · [[Moon Animator and Third-Party Tools]] · [[Open Questions]] · [[Rigging in Blender]]

### 14 3D Modeling
[[Blender Workflow for Roblox Creators]] · [[Exporting and Validating Models for Roblox]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]]

### 15 AI Tools
[[AI 3D Model Generation Outside Roblox]] · [[AI Animation and Motion from Video]] · [[AI Pitfalls - Assets and Import]]

### 17 Pipelines
[[Art Pipeline - Concept to In-Game Asset]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]]

### 54 Untextured Stylised Modelling
[[Clean Stylised Shading - Weighted and Custom Normals]] · [[Flat Colour vs Gradient Atlas vs Vertex Colour]]

### Root notes
[[00 Start Here]]

Also mentioned in (not linked): Animation Editor Advanced · Animation Start Here · Bevels Chamfers and Edge Highlights Without Textures · Blender 5 Python Gotchas for Headless Builds · Blender Automation with Python · Commissions Pricing and Contracts · Creature Rig Conventions · Evaluating AI Tools - A Practical Rubric · Faceted Low-Poly - Flat Normals and Facet Size · Facial Animation and Dynamic Heads · Hard-Surface Modeling · Layered Clothing Creation Workflow · Low-Poly Creature From a Flat Reference Sheet · Low-Poly Tree Set Worked Example · Low-Poly and Stylized Modeling · Making Thumbnails in Studio and Blender - Capture, Lighting and Posing · Meshing Voxels for Roblox - Greedy Meshing and Export · Modeling Fundamentals for Games · Open Questions - Whole Vault · Pipeline - Importing Animated Enemies · Skeleton Library · Skill - Roblox Asset Import · Skinning Weights · Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs · Substance Painter and Texturing Tools · The Gradient Palette Texture Workflow · Trim Sheets Atlases and Vertex Colors · UGC Avatar Items and Accessories · Voxel Modelling Start Here · Voxel Shading - Baked AO Edges and Lighting · Weight Painting and Skinning for Roblox · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
