---
tags: [atlas, concept, type/atlas, area/animation, area/modeling]
---
# glTF and GLB

<!-- tldr:start -->
> [!tldr] TL;DR
> - GLB is the reference project's default for static and hinged assets; FBX remains the safer choice for skinned characters with...
> - Avoid: Optimize Animation Size on (glTF) -> Turn it off, or key all bones explicitly.
> - Avoid: Blockbench ASCII FBX into Blender -> Use glTF/GLB or OBJ.
> - Avoid: Mixing FBX scale methods -> One method: FBX Unit Scale, or use GLB.
>
> Cost: TL;DR ~130 tok · whole note ~1.0k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

GLB is the reference project's default for static and hinged assets; FBX remains the safer choice for skinned characters with animation. (from [[Art Pipeline - Concept to In-Game Asset]])

## Key facts

- Avoid: Optimize Animation Size on (glTF) -> Turn it off, or key all bones explicitly. ([[Exporting FBX vs GLB]])
- Avoid: Blockbench ASCII FBX into Blender -> Use glTF/GLB or OBJ. ([[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]])
- Avoid: Mixing FBX scale methods -> One method: FBX Unit Scale, or use GLB. ([[Blender Workflow for Roblox Creators]])
- Avoid: Assuming glTF +Z front means Roblox +Z front -> Know the measured importer turn; test with the calibration clip. ([[Blender Armature and Bone Roll Conventions]])
- GLB exported with modifiers applied (static) or applied manually (rigs). ([[AI Pitfalls - Assets and Import]])

## Mentioned in

75 notes in 15 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Modeling in Blender for Roblox]]

### 08 Animation
[[Animation Data from Blender to Roblox]] · [[Blender Armature and Bone Roll Conventions]] · [[Creature Rig Conventions]] · [[Enemy Import Axis Fix]] · [[Engine Gotchas]] · [[Exporting FBX vs GLB]] · [[Importing Models and Rigs]] · [[Open Questions]] · [[Pipeline - Importing Animated Enemies]] · [[Pipeline - New Animated Weapon]] · [[Rigging in Blender]]

### 13 Production and Case Studies
[[Asset Pipelines]]

### 14 3D Modeling
[[Blender Workflow for Roblox Creators]] · [[Exporting and Validating Models for Roblox]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Modeling Weapons and Props]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]]

### 15 AI Tools
[[AI 3D Model Generation Outside Roblox]] · [[AI Pitfalls - Assets and Import]]

### 16 MCP and Agents
[[Case Study - Building a Game with AI Agents]]

### 17 Pipelines
[[Icon and Thumbnail Rendering Pipeline]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]]

### 54 Untextured Stylised Modelling
[[Flat Colour vs Gradient Atlas vs Vertex Colour]]

Also mentioned in (not linked): 00 Start Here · 3D Importer Settings Reference · AI Animation and Motion from Video · AI Image Generation for Icons Thumbnails and Concepts · Animating Creatures and Monsters · Animation Editor Advanced · Animation Review Checklist · Animation Start Here · Art Pipeline - Concept to In-Game Asset · Batch Processing Tools in Studio · Benchmark - Does a Knowledge Vault Make AI Better at Roblox · Bevels Chamfers and Edge Highlights Without Textures · Blender 5 Python Gotchas for Headless Builds · Blender Automation with Python · Blender MCP · Bones and Skinned Meshes · Clean Stylised Shading - Weighted and Custom Normals · Commissions Pricing and Contracts · Custom Rigs - Weapons and Props · Evaluating AI Tools - A Practical Rubric · Faceted Low-Poly - Flat Normals and Facet Size · Facial Animation and Dynamic Heads · Hard-Surface Modeling · House Construction Method - Modular Kit Workflow · Low-Poly Creature From a Flat Reference Sheet · Low-Poly and Stylized Modeling · Modeling Fundamentals for Games · Modular Environment Kits · Moon Animator and Third-Party Tools · Open Questions - Whole Vault · Parts Unions and MeshParts · Procedural Model Kits - Lessons · Roblox Studio MCP Server · Rotations Angles and Quaternions · Skill - Roblox Asset Import · Skinning Weights · Stylised Log Cabin Worked Example · Stylised Shop Stand Worked Example · Substance Painter and Texturing Tools · The Gradient Palette Texture Workflow · Trim Sheets Atlases and Vertex Colors · UGC Avatar Items and Accessories · Voxel Characters - Proportions Joints and Rigging · Voxel Modelling Start Here · Voxel Props Environments and Modular Tiles · Voxel Scale Grids and Stud Alignment · Voxel Shading - Baked AO Edges and Lighting · Weapon Design Rig Builder · Weight Painting and Skinning for Roblox · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
