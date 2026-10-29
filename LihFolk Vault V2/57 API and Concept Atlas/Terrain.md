---
tags: [atlas, api, type/atlas, area/world, area/vfx, api/Terrain]
---
# Terrain

<!-- tldr:start -->
> [!tldr] TL;DR
> - Terrain is the cheapest way to cover large ground areas, make caves and cliffs, and fill water bodies; it is also global, hard...
> - Avoid: Recolouring or overriding a base material for one zone -> Different material, or an Expanded Terrain slot.
> - Terrain versus meshes decided per area and written down.
> - Terrain snapshot before any bulk write; owner OK for area regeneration.
>
> Cost: TL;DR ~140 tok · whole note ~1.2k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Terrain is the cheapest way to cover large ground areas, make caves and cliffs, and fill water bodies; it is also global, hard to undo, and full of measured quirks. (from [[Terrain Tools and Terrain API]])

Terrain is the riskiest layer: edits are large, slow, and Studio undo is shared in team sessions. (from [[Environment and Level Pipeline]])

API snapshot: class, inherits `BasePart`, not creatable with `Instance.new` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Recolouring or overriding a base material for one zone -> Different material, or an Expanded Terrain slot. ([[Terrain Deep Dive - Materials Water and Performance]])
- Terrain versus meshes decided per area and written down. ([[Terrain Deep Dive - Materials Water and Performance]])
- Terrain snapshot before any bulk write; owner OK for area regeneration. ([[Safe Changes in a Shared Place]])
- Terrain water only where players swim. ([[Water Sky and Atmosphere Art]])
- Clouds under Terrain, moved by `GlobalWind`. ([[Atmosphere Sky Clouds and Post-Processing]])

## Mentioned in

80 notes in 26 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Command Bar and Studio Scripting]]

### 06 World Building and Art
[[Foliage Props and Scatter]] · [[Level Design for Roblox]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Parts Unions and MeshParts]] · [[Procedural World Generation]] · [[Roads, Rivers and Paths Carved Along Curves in Terrain]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Terrain Tools and Terrain API]] · [[Water Sky and Atmosphere Art]]

### 07 Lighting VFX and Audio
[[Snow, Sandstorm, Blizzard and Ash Recipes]]

### 13 Production and Case Studies
[[Post-Mortem - Building a Melee Action Game]] · [[Safe Changes in a Shared Place]]

### 16 MCP and Agents
[[MCP Workflows for Building Worlds]]

### 17 Pipelines
[[Environment and Level Pipeline]]

### 25 Physics and Vehicles
[[Boats Buoyancy and Water]] · [[Destruction and Fracture]]

### 34 Procedural Generation
[[Infinite and Streamed Worlds]] · [[Noise Functions and Terrain Generation]]

### 44 Materials and Surfaces
[[Materials and Surfaces Start Here]] · [[Terrain Materials and Painting]]

### 46 Resource Library
[[Links - Terrain]]

### 51 2D Game Development
[[EditableImage for Pixel Buffers and Procedural 2D]]

### 53 Voxel Modelling Deep Dive
[[Voxel Props Environments and Modular Tiles]] · [[Voxel Scale Grids and Stud Alignment]]

Also mentioned in (not linked): 00 Start Here · AI Agents and Autonomous Workflows · Asset Pipelines · Atmosphere Sky Clouds and Post-Processing · Beams and Trails · Case Study - Instance Cleanup and Place Size · Characters and Humanoids · Collision and Physics Geometry · Combat Sound Design and Feedback · Custom Character Sounds - Replacing Default Footstep and Jump Sounds · Deterministic Simulation · Faceted Low-Poly - Flat Normals and Facet Size · Genre Playbook - Naval and Open-Sea Adventure · Genre Playbook - Survival and Crafting · Impact Decals and Material-Aware Hit Sparks · Instance Streaming · Lessons Learned Index · Level Design Start Here · Links - Materials and MaterialVariants · Low-Poly Tree Set Worked Example · Low-Poly and Stylized Modeling · MaterialService and Custom Materials · Meshing Voxels for Roblox - Greedy Meshing and Export · Modular Environment Kits · Multi-Client and Live Testing · Multiple Agents in One Studio · Music and Adaptive Audio · Open Questions - Whole Vault · Physics and Vehicles Start Here · Pipeline Design Principles · Procedural Generation Start Here · Rain - Camera-Local Particles, Splashes and Wet Surfaces · Raycasts Shapecasts and Spatial Queries · Resource Library - Building and World · Roblox Studio Assistant · Roblox Studio MCP Server · Safety Rules for AI Agents in Studio · Seeds Determinism and Reproducible Worlds · Selection Editing and Bulk Tools · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Snippets - IK · Studio Interface Tour · Stylised vs Realistic Material Pipelines · SurfaceAppearance PBR Workflow · Team Create and Collaboration · Team Roles and Workflows · Teardown - Driving Empire · Textures Decals and Texture Memory · UV Unwrapping · Undo and ChangeHistoryService Done Right · Version History and Backups · Voxel Modelling Start Here · Wave Function Collapse on Roblox · Working with AI Assistants in Studio · Zone and Biome Art Direction

<!-- atlas:generated -->
