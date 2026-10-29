---
tags: [atlas, concept, type/atlas, area/2d, area/ui]
---
# Pixel Art

<!-- tldr:start -->
> [!tldr] TL;DR
> - Pixel art is the identity of the game. Crisp, unfiltered pixels at an integer scale are straightforward in GUI with...
> - Blockbench pixel art looks blurry in game: Bilinear filtering on `TextureID` -> SurfaceAppearance ColorMap with `ResampleMode...
> - Your art is not pixel art. Painted or vector-style art should stay on the default resampling; `Pixelated` makes smooth art...
> - Competitive and real-time and pixel art: possible in GUI 2D, but you are signing up for everything in 2D Multiplayer - Server...
>
> Cost: TL;DR ~170 tok · whole note ~540 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Pixel art is the identity of the game. Crisp, unfiltered pixels at an integer scale are straightforward in GUI with `ImageLabel.ResampleMode = Enum.ResamplerMode.Pixelated` (Roblox docs (as of October 2026): "When set to Enum.ResamplerMode.Pixelated, the image preserves the sharp edges of pixels"). (from [[Choosing GUI 2D or Locked-Camera 2.5D]])

## Key facts

- Blockbench pixel art looks blurry in game: Bilinear filtering on `TextureID` -> SurfaceAppearance ColorMap with `ResampleMode = Pixelated` ([[MagicaVoxel Goxel and Blockbench Workflows Compared]])
- Your art is not pixel art. Painted or vector-style art should stay on the default resampling; `Pixelated` makes smooth art look jagged when scaled. ([[Pixel Art Pipeline - Aseprite to Roblox Without Blur]])
- Competitive and real-time and pixel art: possible in GUI 2D, but you are signing up for everything in 2D Multiplayer - Server Authority and Replicating GUI Worlds. ([[2D Game Development Start Here]])
- The pipeline is in Pixel Art Pipeline - Aseprite to Roblox Without Blur. ([[Choosing GUI 2D or Locked-Camera 2.5D]])

## Mentioned in

14 notes in 7 sections. The 14 most relevant are linked:

### 05 UI and UX
[[UI Style Directions - A Visual Vocabulary for Briefs]]

### 44 Materials and Surfaces
[[SurfaceAppearance PBR Workflow]]

### 51 2D Game Development
[[2D Game Development Start Here]] · [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] · [[Choosing GUI 2D or Locked-Camera 2.5D]] · [[EditableImage for Pixel Buffers and Procedural 2D]] · [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]] · [[Sprite Sheets and Frame Animation with ImageRectOffset]] · [[Tilemaps Cameras and Parallax for 2D Levels]]

### 52 Core Concepts
[[Texel Density]]

### 53 Voxel Modelling Deep Dive
[[MagicaVoxel Goxel and Blockbench Workflows Compared]]

### 54 Untextured Stylised Modelling
[[Colour Scripts and Value Structure for Untextured Art]]

### Root notes
[[00 Start Here]]

<!-- atlas:generated -->
