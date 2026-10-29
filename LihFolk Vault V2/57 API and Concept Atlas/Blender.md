---
tags: [atlas, concept, type/atlas, area/animation, area/modeling]
---
# Blender

<!-- tldr:start -->
> [!tldr] TL;DR
> - Blender is the default modelling tool for Roblox creators: free, scriptable, and the one Roblox's own guides are written for.
> - Every tool fails to connect: Add-on server not started, wrong port, Blender closed -> Start the server in add-on preferences...
> - Call times out: Blender busy (render, modal operator, dialog) -> Wait; cancel the modal; move heavy work to `blender -b`...
> - Avoid: Blockbench ASCII FBX into Blender -> Use glTF/GLB or OBJ.
>
> Cost: TL;DR ~150 tok · whole note ~2.3k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Blender is the default modelling tool for Roblox creators: free, scriptable, and the one Roblox's own guides are written for. (from [[Blender Workflow for Roblox Creators]])

Blender is the default modelling tool for Roblox creators: free, scriptable in Python, and supported by Roblox's own export docs and upload add-on. (from [[Modeling in Blender for Roblox]])

## Key facts

- Every tool fails to connect: Add-on server not started, wrong port, Blender closed -> Start the server in add-on preferences; restart the client. ([[Blender MCP]])
- Call times out: Blender busy (render, modal operator, dialog) -> Wait; cancel the modal; move heavy work to `blender -b` ([[Blender MCP]])
- Avoid: Blockbench ASCII FBX into Blender -> Use glTF/GLB or OBJ. ([[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]])
- Units, axes and pivots normalised (often via Blender) before the final export. ([[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]])
- Avoid: Feeding Roblox `Color3` sRGB numbers into Blender as linear values. ([[VFX Previews in Blender for Roblox - Colour and Framing]])

## Mentioned in

198 notes in 23 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Modeling in Blender for Roblox]]

### 07 Lighting VFX and Audio
[[VFX Previews in Blender for Roblox - Colour and Framing]]

### 08 Animation
[[Animation Data from Blender to Roblox]] · [[Blender Armature and Bone Roll Conventions]] · [[Exporting FBX vs GLB]] · [[Moon Animator and Third-Party Tools]] · [[Rigging in Blender]] · [[Weight Painting and Skinning for Roblox]]

### 13 Production and Case Studies
[[Asset Pipelines]]

### 14 3D Modeling
[[Bezier Curves and Splines for Modellers]] · [[Blender Workflow for Roblox Creators]] · [[Curve-Based Modelling in Blender for Roblox]] · [[Exporting and Validating Models for Roblox]] · [[Modeling Fundamentals for Games]] · [[Normal Maps and Detail Baking]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]]

### 16 MCP and Agents
[[Blender MCP]]

### 17 Pipelines
[[Art Pipeline - Concept to In-Game Asset]] · [[Blender Automation with Python]]

### 44 Materials and Surfaces
[[Baking Lighting and Detail into Textures]]

### 45 Procedural Blender Assets
[[Blender 5 Python Gotchas for Headless Builds]] · [[Procedural Blender Assets Start Here]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]]

### 61 Thumbnails and CTR
[[Making Thumbnails in Studio and Blender - Capture, Lighting and Posing]]

### Root notes
[[00 Start Here]]

Also mentioned in (not linked): 000 Home · 3D Importer Settings Reference · AI 3D Model Generation Outside Roblox · AI Agents and Autonomous Workflows · AI Animation and Motion from Video · AI Image Generation for Icons Thumbnails and Concepts · AI Pitfalls - Assets and Import · AI in Roblox Development Overview · Accessories and Armor That Follow Animation · Agent Review Loops and Guardrails in Practice · Animating Creatures and Monsters · Animation Capture and Mocap · Animation Editor Workflow · Animation Glossary · Animation Start Here · Arm Twist and Grip Roll - Lessons from Baked Sword Clips · Asset Upload Automation with Open Cloud · Avatars and UGC Start Here · Batch Processing Tools in Studio · Benchmark - Does a Knowledge Vault Make AI Better at Roblox · Bevels Chamfers and Edge Highlights Without Textures · Bones and Skinned Meshes · Boss Animation and Phases · Building a Portfolio as a Roblox Developer · Case Study - Building LihFolk V2 with AI Agents · Case Study - Building a Game with AI Agents · Case Study - Enemy Roster Rebuild · Character and Creature Pipeline · Chibi Character Rules in Practice · Clean Stylised Shading - Weighted and Custom Normals · Clip Buffer Format · Commissions Pricing and Contracts · Creator Store and Toolbox Safety · Creature Rig Conventions · Critiquing a Model - Paintovers and Iteration · CurveAnimation and Curve Channels · Curves in Luau - Paths Beams and Motion · Custom Rigs - Weapons and Props · Dash VFX Presentation on an R15 Rig · Destruction and Fracture · Dramatic Showcase Renders in Eevee · Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning · Enemy Import Axis Fix · Engine Gotchas · Environment Art Styles · Environment and Level Pipeline · Evaluating AI Tools - A Practical Rubric · Faceted Low-Poly - Flat Normals and Facet Size · Facial Animation and Dynamic Heads · Flat Colour vs Gradient Atlas vs Vertex Colour · Free Mocap and Mixamo Licensing for Roblox · Glossary · Hand-Painted and Stylized Texturing · Hard-Surface Modeling · House Construction Method - Modular Kit Workflow · Ice Ball Cast to Explosion - Approved Recipe · Icon and Thumbnail Rendering Pipeline · Importing Models and Rigs · Keeping a Mixed Asset Library Consistent · Layered Clothing Cages and Animation · Layered Clothing Creation Workflow · Level Design for Roblox · LihFolk R15 Keyframe Pipeline · Look-At Aim and Head Tracking · Low-Poly Creature From a Flat Reference Sheet · Low-Poly Tree Set Worked Example · Low-Poly and Stylized Modeling · MCP Workflows for Building Worlds · Matching a Concept Sheet - Boss Creature Case Study · MaterialService and Custom Materials · Materials MaterialVariants and SurfaceAppearance · Materials and Surfaces Start Here · Mesh Gates for Generated Models - Symmetry, Seating and Caps · Mesh Optimization for Mobile · Mesh VFX Packs Built in Blender · Meshing Voxels for Roblox - Greedy Meshing and Export · Modeling Characters for R15 and Custom Rigs · Modeling Weapons and Props · Modelling Nuance Start Here · Modelling to the Roblox Camera and Player Scale · Modular Environment Kits · Motor6D Math and CFrame Composition · Official Docs - Asset Creation · Official Docs - Audio · Official Docs - Building and World · Official Docs - Characters and Animation · Official Docs - Data and Persistence · Official Docs - Game Systems · Official Docs - Input and Controls · Official Docs - Monetization · Official Docs - Networking and Multiplayer · Official Docs - Performance · Official Docs - Physics · Official Docs - Publishing and Live Ops · Official Docs - Scripting and Luau · Official Docs - Security and Moderation · Official Docs - Studio and Tooling · Official Docs - UI · Official Docs - Visual Effects · Open Questions · Open Questions - Whole Vault · Organic and Creature Modeling · Parts Unions and MeshParts · Pipeline - Importing Animated Enemies · Pipeline - New Animated Weapon · Pipeline Design Principles · Post-Mortem - Building a Melee Action Game · Procedural Creatures - Fused Shells, Quad Cages and Faceting · Procedural Model Kits - Lessons · Procedural World Generation · Proportion Exaggeration and Gameplay Distance · R15 Rig Anatomy and Attachments · Resource Library Start Here · Retargeting Animations Between Rigs · Retopology and Decimation · Rigs and Joints · Roads, Rivers and Paths Carved Along Curves in Terrain · Roblox Generative AI - Cube Mesh and Texture Generation · Roblox Studio Assistant · Roblox Studio MCP Server · Rotations Angles and Quaternions · Safety Rules for AI Agents in Studio · Setting Up MCP Clients · Shape Language and Silhouette Testing · Skeleton Library · Skill - Roblox Asset Import · Skinning Weights · Slash VFX Recipes - Crescent and Ring · Snippets - Building and Sampling Clips · Spending Triangles Where the Camera Looks · Spin and Whole-Body Rotation Moves · Studio Plugins and Local HTTP Bridges · Studio Tooling Architecture · Style Bibles for Consistent Models · Stylised Log Cabin Worked Example · Stylised Shop Stand Worked Example · Stylised Weapons From a Concept · Stylised vs Realistic Material Pipelines · Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs · Substance Painter and Texturing Tools · SurfaceAppearance PBR Workflow · Terrain Materials and Painting · Textures Decals and Texture Memory · Texturing and PBR Baking · The Gradient Palette Texture Workflow · Thumbnail Composition for High CTR - Focal Point, Contrast and Readability · Thumbnail Contrast · Thumbnail Genre Patterns - What Top Games Show · Thumbnail Review Checklist and Scoring Rubric · Thumbnails and CTR Start Here · Tiling Trim Sheets and Decal Tricks · Token Cost Benchmarks · Topology and Edge Flow · Trim Sheets Atlases and Vertex Colors · Troubleshooting Table · UGC Avatar Items and Accessories · UV Unwrapping · Untextured Stylised Modelling Start Here · VFX Readability and Value - Lessons from Blind Reviews · Voxel Art - Studs Outlines and Style Kits · Voxel Characters - Proportions Joints and Rigging · Voxel Chibi Heroes - Class Roster and Rarity Ladder · Voxel Modelling Start Here · Voxel Palettes - Ramps Hue Shifting and Limits · Voxel Props Environments and Modular Tiles · Voxel Scale Grids and Stud Alignment · Voxel Shading - Baked AO Edges and Lighting · Voxel and Blocky Modeling · Weapon Design Rig Builder · What AI Models Get Wrong in Roblox · What Is MCP · Working with AI Assistants in Studio · Writing Your Own MCP Server

<!-- atlas:generated -->
