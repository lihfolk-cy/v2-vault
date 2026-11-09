---
tags: [atlas, api, type/atlas, area/studio, area/pipelines, api/EditableMesh]
---
# EditableMesh

<!-- tldr:start -->
> [!tldr] TL;DR
> - `EditableMesh` lets a script build or change triangle geometry while the game runs: a heightfield that players dig craters...
> - An `EditableMesh` is drawn only once it is linked to a MeshPart: `AssetService:CreateMeshPartAsync(Content.fromObject(mesh))`...
> - Changing mesh geometry at runtime: EditableMesh - Runtime Mesh Editing, Budgets and Publishing.
> - Set up each body `MeshPart`. If it has a `WrapTarget`, add a `WrapDeformer` driven by a cage `EditableMesh`; otherwise put an...
>
> Cost: TL;DR ~160 tok · whole note ~620 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`EditableMesh` lets a script build or change triangle geometry while the game runs: a heightfield that players dig craters into, a road ribbon that follows a spline, a sculpting tool, a customised avatar body. (from [[EditableMesh - Runtime Mesh Editing, Budgets and Publishing]])

API snapshot: class, inherits `Object`, not creatable with `Instance.new` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- An `EditableMesh` is drawn only once it is linked to a MeshPart: `AssetService:CreateMeshPartAsync(Content.fromObject(mesh))` returns a new `MeshPart`. ([[EditableMesh - Runtime Mesh Editing, Budgets and Publishing]])
- Changing mesh geometry at runtime: EditableMesh - Runtime Mesh Editing, Budgets and Publishing. ([[Parts Unions and MeshParts]])
- Set up each body `MeshPart`. If it has a `WrapTarget`, add a `WrapDeformer` driven by a cage `EditableMesh`; otherwise put an `EditableMesh` on it directly. ([[In-Experience Avatar Creation - Tokens, Editing and Prompting]])
- `EditableMesh`/`EditableImage` creation handles `nil`. ([[Engine and API Changes 2025-2026]])

## Mentioned in

20 notes in 12 sections. The 20 most relevant are linked:

### 01 Studio and Workflow
[[Git and Source Control for Roblox]] · [[Places Universes and Experience Settings]] · [[Testing Modes - Play Run and Multi-Client]]

### 06 World Building and Art
[[EditableMesh - Runtime Mesh Editing, Budgets and Publishing]] · [[Parts Unions and MeshParts]]

### 07 Lighting VFX and Audio
[[VFX Design Playbook]] · [[VFX Performance Budgets and Culling]]

### 12 Performance Testing and Debugging
[[Testing Strategies and Frameworks]]

### 15 AI Tools
[[AI Pitfalls - Assets and Import]]

### 17 Pipelines
[[Asset Upload Automation with Open Cloud]] · [[Build Test and Release Pipeline]] · [[Code Pipeline - Rojo Git and CI]]

### 25 Physics and Vehicles
[[Boats Buoyancy and Water]]

### 37 Avatars and UGC
[[Avatars and UGC Start Here]] · [[In-Experience Avatar Creation - Tokens, Editing and Prompting]]

### 49 Roblox Platform Features
[[Engine and API Changes 2025-2026]]

### 51 2D Game Development
[[EditableImage for Pixel Buffers and Procedural 2D]]

### 54 Untextured Stylised Modelling
[[Flat Colour vs Gradient Atlas vs Vertex Colour]]

### Root notes
[[00 Start Here]] · [[Open Questions - Whole Vault]]

<!-- atlas:generated -->
