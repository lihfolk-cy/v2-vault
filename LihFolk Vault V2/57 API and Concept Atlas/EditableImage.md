---
tags: [atlas, api, type/atlas, area/2d, area/studio, api/EditableImage]
---
# EditableImage

<!-- tldr:start -->
> [!tldr] TL;DR
> - `EditableImage` lets a script create an image at runtime and write pixels into it.
> - The maximum size is 1024 by 1024, and an EditableImage cannot be resized after creation.
> - `EditableImage` creation is documented to return `nil` when the budget is used up; assume the same for meshes.
> - Roblox cannot read Aseprite's palette, but keeping colours exact (no near duplicates) makes runtime recolouring with...
>
> Cost: TL;DR ~140 tok · whole note ~710 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`EditableImage` lets a script create an image at runtime and write pixels into it. (from [[EditableImage for Pixel Buffers and Procedural 2D]])

API snapshot: class, inherits `Object`, not creatable with `Instance.new` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- The maximum size is 1024 by 1024, and an EditableImage cannot be resized after creation. ([[EditableImage for Pixel Buffers and Procedural 2D]])
- `EditableImage` creation is documented to return `nil` when the budget is used up; assume the same for meshes. ([[EditableMesh - Runtime Mesh Editing, Budgets and Publishing]])
- Roblox cannot read Aseprite's palette, but keeping colours exact (no near duplicates) makes runtime recolouring with EditableImage for Pixel Buffers and Procedural 2D reliable, because you can match colours by exact RGB. ([[Pixel Art Pipeline - Aseprite to Roblox Without Blur]])
- Create one `EditableImage` per texture, and reuse it when parts share a texture id. ([[In-Experience Avatar Creation - Tokens, Editing and Prompting]])

## Mentioned in

27 notes in 13 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Git and Source Control for Roblox]] · [[Places Universes and Experience Settings]] · [[Testing Modes - Play Run and Multi-Client]]

### 05 UI and UX
[[Minimap and World Map UI - Projection, Rotation and Fog of War]]

### 06 World Building and Art
[[EditableMesh - Runtime Mesh Editing, Budgets and Publishing]] · [[Parts Unions and MeshParts]]

### 07 Lighting VFX and Audio
[[Slash VFX Recipes - Crescent and Ring]] · [[VFX Design Playbook]] · [[VFX Performance Budgets and Culling]]

### 12 Performance Testing and Debugging
[[Testing Strategies and Frameworks]]

### 15 AI Tools
[[AI Pitfalls - Assets and Import]]

### 17 Pipelines
[[Asset Upload Automation with Open Cloud]] · [[Build Test and Release Pipeline]] · [[Code Pipeline - Rojo Git and CI]]

### 33 Level Design
[[Playtest Heatmaps - Position and Death Maps]]

### 37 Avatars and UGC
[[In-Experience Avatar Creation - Tokens, Editing and Prompting]]

### 44 Materials and Surfaces
[[SurfaceAppearance PBR Workflow]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Engine and API Changes 2025-2026]]

### 51 2D Game Development
[[2D Game Development Start Here]] · [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] · [[EditableImage for Pixel Buffers and Procedural 2D]] · [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] · [[Sprite Sheets and Frame Animation with ImageRectOffset]] · [[Tilemaps Cameras and Parallax for 2D Levels]]

Also mentioned in (not linked): 00 Start Here · Open Questions - Whole Vault

<!-- atlas:generated -->
