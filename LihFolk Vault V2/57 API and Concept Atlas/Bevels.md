---
tags: [atlas, concept, type/atlas, area/modeling, area/ui]
---
# Bevels

<!-- tldr:start -->
> [!tldr] TL;DR
> - A bevel between them catches the sun and draws a line, restoring the corner.
> - Bevels visible in Blender, invisible in game: Width under 2 pixels at play distance -> Size from the distance table; double...
> - Stepped strips on a faceted model: 3-segment round bevel with flat shading -> 1-segment chamfer.
> - Avoid: Bevels on unapplied scale -> Apply scale first.
>
> Cost: TL;DR ~130 tok · whole note ~930 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A bevel between them catches the sun and draws a line, restoring the corner. (from [[Bevels Chamfers and Edge Highlights Without Textures]])

## Key facts

- Bevels visible in Blender, invisible in game: Width under 2 pixels at play distance -> Size from the distance table; double for landmarks. ([[Bevels Chamfers and Edge Highlights Without Textures]])
- Stepped strips on a faceted model: 3-segment round bevel with flat shading -> 1-segment chamfer. ([[Bevels Chamfers and Edge Highlights Without Textures]])
- Avoid: Bevels on unapplied scale -> Apply scale first. ([[Hard-Surface Modeling]])
- Scale applied before bevelling; bevel width 1-6 percent of form size. ([[Hard-Surface Modeling]])
- Flat faces darken toward edges ("inflated" look): Smooth shading averaging across bevels -> Harden Normals or Weighted Normal (Face Area) ([[Clean Stylised Shading - Weighted and Custom Normals]])
- Bevels sized to at least 2 to 3 px at the usual viewing distance; Harden Normals on. ([[Clean Stylised Shading - Weighted and Custom Normals]])

## Mentioned in

54 notes in 13 sections. The 25 most relevant are linked:

### 05 UI and UX
[[UI Design Systems]]

### 06 World Building and Art
[[House Construction Method - Modular Kit Workflow]]

### 14 3D Modeling
[[Bezier Curves and Splines for Modellers]] · [[Blender Workflow for Roblox Creators]] · [[Curve-Based Modelling in Blender for Roblox]] · [[Hard-Surface Modeling]] · [[Low-Poly and Stylized Modeling]] · [[Modeling Fundamentals for Games]] · [[Modeling Weapons and Props]] · [[Normal Maps and Detail Baking]] · [[Procedural Model Kits - Lessons]] · [[Trim Sheets Atlases and Vertex Colors]]

### 15 AI Tools
[[AI Pitfalls - Assets and Import]]

### 45 Procedural Blender Assets
[[Stylised Log Cabin Worked Example]] · [[Stylised Shop Stand Worked Example]] · [[Stylised Weapons From a Concept]]

### 53 Voxel Modelling Deep Dive
[[Voxel Shading - Baked AO Edges and Lighting]]

### 54 Untextured Stylised Modelling
[[Clean Stylised Shading - Weighted and Custom Normals]] · [[Keeping a Mixed Asset Library Consistent]] · [[Untextured Stylised Modelling Start Here]]

### 55 Modelling Nuance and Readability
[[Bevels Chamfers and Edge Highlights Without Textures]] · [[Critiquing a Model - Paintovers and Iteration]] · [[Modelling Nuance Start Here]] · [[Spending Triangles Where the Camera Looks]] · [[Style Bibles for Consistent Models]]

Also mentioned in (not linked): 00 Start Here · AI 3D Model Generation Outside Roblox · Art-Direction Nitpicks - The Principles Behind Them · Baking Lighting and Detail into Textures · Blender Automation with Python · Dash VFX Presentation on an R15 Rig · Declarative UI - React-Lua and Fusion · Designing Roblox UI in Figma - Frames, Safe Areas and Tokens · Environment Art Styles · Exporting FBX vs GLB · Exporting and Validating Models for Roblox · Faceted Low-Poly - Flat Normals and Facet Size · Hand-Painted and Stylized Texturing · Lighting Untextured Art in Roblox · Mesh Gates for Generated Models - Symmetry, Seating and Caps · Meshing Voxels for Roblox - Greedy Meshing and Export · Modeling in Blender for Roblox · Modular Environment Kits · Organic and Creature Modeling · Parts Unions and MeshParts · Procedural Blender Assets Start Here · Proportion Exaggeration and Gameplay Distance · Stylised vs Realistic Material Pipelines · Stylized Lighting Recipes · SurfaceAppearance PBR Workflow · UI Asset Pipeline · UI Style Directions - A Visual Vocabulary for Briefs · Voxel Chibi Heroes - Class Roster and Rarity Ladder · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
