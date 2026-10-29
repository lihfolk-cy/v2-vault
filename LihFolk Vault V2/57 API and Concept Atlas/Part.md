---
tags: [atlas, api, type/atlas, area/animation, area/modeling, api/Part]
---
# Part

<!-- tldr:start -->
> [!tldr] TL;DR
> - A Part is the cheapest thing in Roblox. (from Parts Unions and MeshParts)
> - Studio-built parts look harsher than meshes: Sharp Part edges next to bevelled meshes -> Bevelled mesh primitives for visible...
> - Avoid: One Part per cell -> Greedy merge per colour; bake to meshes.
> - Avoid: Reading `Part.CFrame` in `PreSimulation` for the chain parent (one frame behind).
>
> Cost: TL;DR ~130 tok · whole note ~690 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A Part is the cheapest thing in Roblox. (from [[Parts Unions and MeshParts]])

API snapshot: class, inherits `FormFactorPart` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Studio-built parts look harsher than meshes: Sharp Part edges next to bevelled meshes -> Bevelled mesh primitives for visible architecture. ([[Keeping a Mixed Asset Library Consistent]])
- Avoid: One Part per cell -> Greedy merge per colour; bake to meshes. ([[Voxel Art - Studs Outlines and Style Kits]])
- Avoid: Reading `Part.CFrame` in `PreSimulation` for the chain parent (one frame behind). ([[Snippets - IK]])

## Mentioned in

43 notes in 15 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[CollectionService Patterns]] · [[Instances Attributes and Tags]]

### 06 World Building and Art
[[Parts Unions and MeshParts]] · [[Voxel Art - Studs Outlines and Style Kits]] · [[Water Sky and Atmosphere Art]]

### 07 Lighting VFX and Audio
[[Beams and Trails]]

### 08 Animation
[[Importing Models and Rigs]] · [[Inverse Kinematics]] · [[Layered Clothing Cages and Animation]] · [[Motor6D Math and CFrame Composition]] · [[R15 Rig Anatomy and Attachments]] · [[Rigging in Blender]]

### 14 3D Modeling
[[Modeling Characters for R15 and Custom Rigs]] · [[Texturing and PBR Baking]] · [[Voxel and Blocky Modeling]]

### 15 AI Tools
[[AI Code Assistants for Luau]]

### 17 Pipelines
[[Blender Automation with Python]] · [[Character and Creature Pipeline]]

### 23 Debugging Deep Dives
[[Reading Luau Errors and Stack Traces]]

### 25 Physics and Vehicles
[[Destruction and Fracture]]

### 43 Genre Systems End to End
[[Arena Rounds with Teams and Spectating End to End]] · [[Tycoon Plots and Droppers End to End]]

### 44 Materials and Surfaces
[[Tiling Trim Sheets and Decal Tricks]]

### 54 Untextured Stylised Modelling
[[Keeping a Mixed Asset Library Consistent]] · [[Lighting Untextured Art in Roblox]]

Also mentioned in (not linked): Explorer Properties and Selection · Frame Order and RunService Timing · Global Leaderboards End to End · Lobby and Hub Design · Luau Type System and Strict Mode · Melee Combat System End to End · Normal Maps and Detail Baking · Obby Checkpoints and Stage Saves End to End · Pipeline Design Principles · Racing Laps and Checkpoints End to End · Round-Based Minigame Loop End to End · Slash VFX Recipes - Crescent and Ring · Snippets - IK · Snippets - Procedural Motion · Topology and Edge Flow · Tower Defense Waves and Placement End to End · Troubleshooting Table · Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver

<!-- atlas:generated -->
