---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/LocalTransparencyModifier]
---
# LocalTransparencyModifier

<!-- tldr:start -->
> [!tldr] TL;DR
> - `LocalTransparencyModifier` is local to each client, which is exactly why every client runs the effect for every dying player...
> - Your own scripts that also write `LocalTransparencyModifier` (first-person body hiding, ghost effects) will be overwritten or...
> - `hide`: set the part's (or a list of parts') `LocalTransparencyModifier` to 1.
> - Hide them with `LocalTransparencyModifier` (per-client, does not replicate, does not fight other scripts that set `Transparency`).
>
> Cost: TL;DR ~160 tok · whole note ~520 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`LocalTransparencyModifier` is local to each client, which is exactly why every client runs the effect for every dying player (within 260 studs) from the server's replicated death attribute. (from [[Procedural Death Knockdown and Hit Reactions]])

API snapshot: member of `BasePart`, `Beam`, `Decal`, `Explosion` and 5 more (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Your own scripts that also write `LocalTransparencyModifier` (first-person body hiding, ghost effects) will be overwritten or will overwrite it. ([[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]])
- `hide`: set the part's (or a list of parts') `LocalTransparencyModifier` to 1. ([[Enemy Animation State Protocol]])
- Hide them with `LocalTransparencyModifier` (per-client, does not replicate, does not fight other scripts that set `Transparency`). ([[Equip Draw and Flourish Systems]])
- Hide other players toggle: set their characters' `LocalTransparencyModifier` locally; restore on exit. ([[Photo Mode and In-Game Screenshots with CaptureService]])

## Mentioned in

12 notes in 6 sections. The 12 most relevant are linked:

### 08 Animation
[[Accessories and Armor That Follow Animation]] · [[Enemy Animation State Protocol]] · [[Equip Draw and Flourish Systems]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[Procedural Death Knockdown and Hit Reactions]] · [[Procedural Weapon Motion]]

### 09 Gameplay Systems
[[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]]

### 12 Performance Testing and Debugging
[[Client Zone Culling for Interiors and Cities]]

### 49 Roblox Platform Features
[[Photo Mode and In-Game Screenshots with CaptureService]]

### 51 2D Game Development
[[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 62 Engine Reference Cards
[[BasePart - Engine Reference Card]] · [[ParticleEmitter - Engine Reference Card]]

<!-- atlas:generated -->
