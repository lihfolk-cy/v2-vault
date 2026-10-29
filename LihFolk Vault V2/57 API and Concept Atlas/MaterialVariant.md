---
tags: [atlas, api, type/atlas, area/materials, area/vfx, api/MaterialVariant]
---
# MaterialVariant

<!-- tldr:start -->
> [!tldr] TL;DR
> - A MaterialVariant can have `TerrainDetail` children for the top, side and bottom faces of terrain, each with its own maps...
> - Avoid: Script sets `MaterialVariant` without setting `Material` -> Set both (registry `apply`) (MaterialService and Custom...
> - Avoid: Expecting `MaterialVariant` names from `RaycastResult.Material`.
> - `MaterialVariant`: a custom tiling material that lives in `MaterialService` and is selected by name on a part...
>
> Cost: TL;DR ~150 tok · whole note ~700 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A MaterialVariant can have `TerrainDetail` children for the top, side and bottom faces of terrain, each with its own maps, Studs Per Tile and pattern. (from [[Materials MaterialVariants and SurfaceAppearance]])

MaterialVariant: A custom material that overrides or extends built-in ones. (from [[Glossary]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Script sets `MaterialVariant` without setting `Material` -> Set both (registry `apply`) ([[MaterialService and Custom Materials]])
- Avoid: Expecting `MaterialVariant` names from `RaycastResult.Material`. ([[Impact Decals and Material-Aware Hit Sparks]])
- `MaterialVariant`: a custom tiling material that lives in `MaterialService` and is selected by name on a part (`BasePart.MaterialVariant`). ([[Materials MaterialVariants and SurfaceAppearance]])
- Up to 62 paintable terrain materials per place, each with a custom colour and an optional MaterialVariant, created from the Terrain Editor material picker (the "+" button) and managed in the Terrain Material Manager. ([[Terrain Deep Dive - Materials Water and Performance]])

## Mentioned in

26 notes in 11 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Studio Assistant and AI Tools]]

### 06 World Building and Art
[[Materials MaterialVariants and SurfaceAppearance]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Textures Decals and Texture Memory]]

### 07 Lighting VFX and Audio
[[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]]

### 14 3D Modeling
[[Substance Painter and Texturing Tools]] · [[Texturing and PBR Baking]] · [[Trim Sheets Atlases and Vertex Colors]] · [[UV Unwrapping]]

### 15 AI Tools
[[AI Material and Texture Generation]] · [[AI Pitfalls - Assets and Import]]

### 16 MCP and Agents
[[Roblox Studio MCP Server]]

### 44 Materials and Surfaces
[[MaterialService and Custom Materials]] · [[Procedural Materials and Skies - Lessons]] · [[Stylised vs Realistic Material Pipelines]] · [[SurfaceAppearance PBR Workflow]] · [[Terrain Materials and Painting]]

### 46 Resource Library
[[Links - Materials and MaterialVariants]]

### 49 Roblox Platform Features
[[Engine and API Changes 2025-2026]]

### 55 Modelling Nuance and Readability
[[Bevels Chamfers and Edge Highlights Without Textures]] · [[Style Bibles for Consistent Models]]

### Root notes
[[Glossary]]

Also mentioned in (not linked): Skill - Roblox Asset Import

<!-- atlas:generated -->
