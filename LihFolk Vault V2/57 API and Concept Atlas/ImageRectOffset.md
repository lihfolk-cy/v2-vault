---
tags: [atlas, api, type/atlas, area/2d, area/ui, api/ImageRectOffset]
---
# ImageRectOffset

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ImageRectOffset` (`Vector2`): "the pixel offset (from the top-left) of the image area to be displayed.".
> - Pad every atlas cell with a 1 pixel extruded border (copy the edge pixels outward) and point `ImageRectOffset` at the inner...
> - Pixel Art Pipeline - Aseprite to Roblox Without Blur and Sprite Sheets and Frame Animation with ImageRectOffset: bring in the...
> - See Sprite Sheets and Frame Animation with ImageRectOffset.
>
> Cost: TL;DR ~150 tok · whole note ~480 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ImageRectOffset` (`Vector2`): "the pixel offset (from the top-left) of the image area to be displayed.". (from [[Sprite Sheets and Frame Animation with ImageRectOffset]])

API snapshot: member of `ImageButton`, `ImageLabel` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Pad every atlas cell with a 1 pixel extruded border (copy the edge pixels outward) and point `ImageRectOffset` at the inner tile, as the `padding` field does. ([[Tilemaps Cameras and Parallax for 2D Levels]])
- Pixel Art Pipeline - Aseprite to Roblox Without Blur and Sprite Sheets and Frame Animation with ImageRectOffset: bring in the art and animation. ([[2D Game Development Start Here]])
- See Sprite Sheets and Frame Animation with ImageRectOffset. ([[EditableImage for Pixel Buffers and Procedural 2D]])

## Mentioned in

15 notes in 8 sections. The 15 most relevant are linked:

### 05 UI and UX
[[Virtualized Lists and Large Inventories]]

### 06 World Building and Art
[[Textures Decals and Texture Memory]]

### 08 Animation
[[UI and GUI Animation]]

### 12 Performance Testing and Debugging
[[Memory Budgets and Leaks]]

### 17 Pipelines
[[Icon and Thumbnail Rendering Pipeline]]

### 47 Game Feel and Juice
[[Squash Stretch and Anticipation in UI and Characters]]

### 51 2D Game Development
[[2D Collision Physics and Platformer Movement]] · [[2D Game Development Start Here]] · [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] · [[Choosing GUI 2D or Locked-Camera 2.5D]] · [[EditableImage for Pixel Buffers and Procedural 2D]] · [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] · [[Sprite Sheets and Frame Animation with ImageRectOffset]] · [[Tilemaps Cameras and Parallax for 2D Levels]]

### Root notes
[[00 Start Here]]

<!-- atlas:generated -->
