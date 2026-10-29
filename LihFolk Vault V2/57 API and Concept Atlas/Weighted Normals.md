---
tags: [atlas, concept, type/atlas, area/modeling, area/ai]
---
# Weighted Normals

<!-- tldr:start -->
> [!tldr] TL;DR
> - Weighted Normal makes custom normals weighted by face area (or angle), so big flat faces stay flat and small bevels absorb the...
> - Flat faces darken toward edges ("inflated" look): Smooth shading averaging across bevels -> Harden Normals or Weighted Normal...
> - Weighted Normal last in the stack, Face Area, Keep Sharp, Threshold 0.01.
> - Avoid: Smooth shading a low poly with no normal fix -> Weighted Normal / Harden Normals.
>
> Cost: TL;DR ~150 tok · whole note ~560 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Weighted Normal makes custom normals weighted by face area (or angle), so big flat faces stay flat and small bevels absorb the shading. (from [[Blender Workflow for Roblox Creators]])

## Key facts

- Flat faces darken toward edges ("inflated" look): Smooth shading averaging across bevels -> Harden Normals or Weighted Normal (Face Area) ([[Clean Stylised Shading - Weighted and Custom Normals]])
- Weighted Normal last in the stack, Face Area, Keep Sharp, Threshold 0.01. ([[Clean Stylised Shading - Weighted and Custom Normals]])
- Avoid: Smooth shading a low poly with no normal fix -> Weighted Normal / Harden Normals. ([[Hard-Surface Modeling]])
- Gradients across big flat faces: Smooth shading without normal fix -> Weighted Normal or Harden Normals (see Hard-Surface Modeling) ([[Bevels Chamfers and Edge Highlights Without Textures]])
- Gems: angle-limited bevel + weighted normals + triangulate. ([[Procedural Model Kits - Lessons]])

## Mentioned in

22 notes in 7 sections. The 22 most relevant are linked:

### 06 World Building and Art
[[Modeling in Blender for Roblox]]

### 14 3D Modeling
[[Bezier Curves and Splines for Modellers]] · [[Blender Workflow for Roblox Creators]] · [[Curve-Based Modelling in Blender for Roblox]] · [[Hard-Surface Modeling]] · [[Low-Poly and Stylized Modeling]] · [[Modeling Fundamentals for Games]] · [[Modeling Weapons and Props]] · [[Normal Maps and Detail Baking]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Procedural Model Kits - Lessons]] · [[Retopology and Decimation]] · [[Topology and Edge Flow]]

### 15 AI Tools
[[AI 3D Model Generation Outside Roblox]] · [[AI Pitfalls - Assets and Import]]

### 45 Procedural Blender Assets
[[Stylised Log Cabin Worked Example]]

### 54 Untextured Stylised Modelling
[[Clean Stylised Shading - Weighted and Custom Normals]] · [[Keeping a Mixed Asset Library Consistent]]

### 55 Modelling Nuance and Readability
[[Bevels Chamfers and Edge Highlights Without Textures]] · [[Modelling Nuance Start Here]] · [[Style Bibles for Consistent Models]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
