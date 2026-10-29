---
tags: [atlas, concept, type/atlas, area/modeling, area/materials]
---
# Trim Sheets

<!-- tldr:start -->
> [!tldr] TL;DR
> - A trim sheet is one texture laid out in horizontal (or vertical) strips: a bevelled metal edge, a row of rivets, a plate with...
> - Avoid: A unique texture per prop instead of an atlas or trim sheet.
> - Kits share trim sheets or atlases; tints instead of duplicate textures.
> - Phones crash or textures go blurry: Too many unique large textures -> Shared trim sheets and palettes; 512 and under.
>
> Cost: TL;DR ~140 tok · whole note ~780 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A trim sheet is one texture laid out in horizontal (or vertical) strips: a bevelled metal edge, a row of rivets, a plate with an inset, a band of scales, a strip of trim with a gem. (from [[Trim Sheets Atlases and Vertex Colors]])

A trim sheet is one texture holding horizontal strips of reusable surface (panel, vent, frame, tread, rune band, stone course), each strip tiling horizontally. (from [[Modeling in Blender for Roblox]])

## Key facts

- Avoid: A unique texture per prop instead of an atlas or trim sheet. ([[Textures Decals and Texture Memory]])
- Kits share trim sheets or atlases; tints instead of duplicate textures. ([[Textures Decals and Texture Memory]])
- Phones crash or textures go blurry: Too many unique large textures -> Shared trim sheets and palettes; 512 and under. ([[Mesh Optimization for Mobile]])
- Avoid: Unique textures per prop -> Trim sheets, atlases, tints. ([[Art Budgets - Triangles Draw Calls Memory]])

## Mentioned in

45 notes in 12 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Art Budgets - Triangles Draw Calls Memory]] · [[Modeling in Blender for Roblox]] · [[Textures Decals and Texture Memory]]

### 14 3D Modeling
[[Hand-Painted and Stylized Texturing]] · [[Hard-Surface Modeling]] · [[Low-Poly and Stylized Modeling]] · [[Mesh Optimization for Mobile]] · [[Modeling Fundamentals for Games]] · [[Modular Environment Kits]] · [[Normal Maps and Detail Baking]] · [[Substance Painter and Texturing Tools]] · [[Texturing and PBR Baking]] · [[Trim Sheets Atlases and Vertex Colors]] · [[UV Unwrapping]]

### 44 Materials and Surfaces
[[Baking Lighting and Detail into Textures]] · [[Materials and Surfaces Start Here]] · [[Stylised vs Realistic Material Pipelines]] · [[SurfaceAppearance PBR Workflow]] · [[Tiling Trim Sheets and Decal Tricks]]

### 52 Core Concepts
[[Draw Calls]] · [[Texel Density]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Voxel Shading - Baked AO Edges and Lighting]]

### 54 Untextured Stylised Modelling
[[Flat Colour vs Gradient Atlas vs Vertex Colour]]

### 55 Modelling Nuance and Readability
[[Bevels Chamfers and Edge Highlights Without Textures]]

Also mentioned in (not linked): 00 Start Here · AI 3D Model Generation Outside Roblox · AI Material and Texture Generation · Environment Art Styles · Exporting and Validating Models for Roblox · Glossary · Impact Decals and Material-Aware Hit Sparks · Low-Poly Tree Set Worked Example · MaterialService and Custom Materials · Meshing Voxels for Roblox - Greedy Meshing and Export · Modelling Nuance Start Here · Pixel Art Pipeline - Aseprite to Roblox Without Blur · Procedural Materials and Skies - Lessons · Procedural Model Kits - Lessons · Style Bibles for Consistent Models · The Gradient Palette Texture Workflow · Untextured Stylised Modelling Start Here · Voxel Modelling Start Here · Voxel Palettes - Ramps Hue Shifting and Limits · Voxel and Blocky Modeling

<!-- atlas:generated -->
