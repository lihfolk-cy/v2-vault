---
tags: [atlas, api, type/atlas, area/modeling, area/world, api/SurfaceAppearance]
---
# SurfaceAppearance

<!-- tldr:start -->
> [!tldr] TL;DR
> - SurfaceAppearance needs a MeshPart. It does nothing on a Part or Union.
> - Import checked: every SurfaceAppearance has the expected maps.
> - Blockbench pixel art looks blurry in game: Bilinear filtering on `TextureID` -> SurfaceAppearance ColorMap with `ResampleMode...
> - `SurfaceAppearance`: a child of a `MeshPart` holding UV-mapped PBR maps (Color, Normal, Roughness, Metalness, Emissive mask).
>
> Cost: TL;DR ~140 tok · whole note ~1.2k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

SurfaceAppearance needs a MeshPart. It does nothing on a Part or Union. (from [[Materials MaterialVariants and SurfaceAppearance]])

`SurfaceAppearance` has a `ResampleMode` property: `Default` smooths with bilinear filtering, while `Pixelated` "preserve[s] the sharp edges of pixels using nearest-neighbor filtering" (Roblox docs, as of October 2026). (from [[MagicaVoxel Goxel and Blockbench Workflows Compared]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Import checked: every SurfaceAppearance has the expected maps. ([[SurfaceAppearance PBR Workflow]])
- Blockbench pixel art looks blurry in game: Bilinear filtering on `TextureID` -> SurfaceAppearance ColorMap with `ResampleMode = Pixelated` ([[MagicaVoxel Goxel and Blockbench Workflows Compared]])
- `SurfaceAppearance`: a child of a `MeshPart` holding UV-mapped PBR maps (Color, Normal, Roughness, Metalness, Emissive mask). ([[Materials MaterialVariants and SurfaceAppearance]])
- Plan texture swaps as instance swaps: clone a prepared MeshPart or SurfaceAppearance from storage. ([[Texturing and PBR Baking]])

## Mentioned in

77 notes in 18 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Art Budgets - Triangles Draw Calls Memory]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Parts Unions and MeshParts]] · [[Textures Decals and Texture Memory]] · [[Voxel Art - Studs Outlines and Style Kits]]

### 14 3D Modeling
[[Low-Poly and Stylized Modeling]] · [[Mesh Optimization for Mobile]] · [[Normal Maps and Detail Baking]] · [[Substance Painter and Texturing Tools]] · [[Texturing and PBR Baking]] · [[Trim Sheets Atlases and Vertex Colors]]

### 15 AI Tools
[[AI Material and Texture Generation]]

### 17 Pipelines
[[Art Pipeline - Concept to In-Game Asset]] · [[Code Pipeline - Rojo Git and CI]]

### 44 Materials and Surfaces
[[Baking Lighting and Detail into Textures]] · [[MaterialService and Custom Materials]] · [[Stylised vs Realistic Material Pipelines]] · [[SurfaceAppearance PBR Workflow]] · [[Tiling Trim Sheets and Decal Tricks]]

### 46 Resource Library
[[Official Docs - Asset Creation]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]]

### 54 Untextured Stylised Modelling
[[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[The Gradient Palette Texture Workflow]]

### 55 Modelling Nuance and Readability
[[Bevels Chamfers and Edge Highlights Without Textures]]

### Root notes
[[Open Questions - Whole Vault]]

Also mentioned in (not linked): 00 Start Here · AI Pitfalls - Assets and Import · Asset Upload Automation with Open Cloud · Build Test and Release Pipeline · Designing VFX Textures and Flipbooks in Figma · Draw Calls · Engine and API Changes 2025-2026 · Environment Art Styles · Exporting and Validating Models for Roblox · Foliage Props and Scatter · Git and Source Control for Roblox · Glossary · Hand-Painted and Stylized Texturing · Hard-Surface Modeling · Keeping a Mixed Asset Library Consistent · Layered Clothing Cages and Animation · Level of Detail and Model Streaming · Lighting Technologies and Settings · Lighting Untextured Art in Roblox · Materials and Surfaces Start Here · Memory Budgets and Leaks · Meshing Voxels for Roblox - Greedy Meshing and Export · Modeling Fundamentals for Games · Modeling in Blender for Roblox · Modelling Nuance Start Here · Packages and Asset Reuse · Pipeline - Importing Animated Enemies · Places Universes and Experience Settings · Procedural Materials and Skies - Lessons · Rain - Camera-Local Particles, Splashes and Wet Surfaces · Rendering Performance · Roads, Rivers and Paths Carved Along Curves in Terrain · Roblox Generative AI - Cube Mesh and Texture Generation · Skill - Roblox Asset Import · Squash Stretch and Anticipation in UI and Characters · Studio Assistant and AI Tools · Style Bibles for Consistent Models · Stylised Weapons From a Concept · Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs · Terrain Deep Dive - Materials Water and Performance · Terrain Materials and Painting · Terrain Tools and Terrain API · Texel Density · UGC Avatar Items and Accessories · UV Unwrapping · Untextured Stylised Modelling Start Here · Voxel Chibi Heroes - Class Roster and Rarity Ladder · Voxel Modelling Start Here · Voxel Shading - Baked AO Edges and Lighting · Voxel and Blocky Modeling · Water Sky and Atmosphere Art · Weapon Design Rig Builder

<!-- atlas:generated -->
