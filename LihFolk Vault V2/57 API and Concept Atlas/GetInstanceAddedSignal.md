---
tags: [atlas, api, type/atlas, area/world, area/performance, api/GetInstanceAddedSignal]
---
# GetInstanceAddedSignal

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetInstanceAddedSignal` does not fire for instances that were already tagged before you connected.
> - Avoid: connecting only `GetInstanceAddedSignal`.
> - Use `CollectionService:GetInstanceAddedSignal(tag)` and handle removal; set `Model.ModelStreamingMode = Persistent` only for...
> - With Instance Streaming on, a far-away board may not exist on the client yet; re-render on...
>
> Cost: TL;DR ~140 tok · whole note ~700 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetInstanceAddedSignal` does not fire for instances that were already tagged before you connected. (from [[CollectionService Patterns]])

API snapshot: member of `CollectionService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: connecting only `GetInstanceAddedSignal`. ([[CollectionService - Engine Reference Card]])
- Use `CollectionService:GetInstanceAddedSignal(tag)` and handle removal; set `Model.ModelStreamingMode = Persistent` only for small, essential models. ([[AI Pitfalls - Networking and Security]])
- With Instance Streaming on, a far-away board may not exist on the client yet; re-render on `CollectionService:GetInstanceAddedSignal`, or keep boards in a persistent model. ([[Global Leaderboards End to End]])
- Content streamed in later is not tagged yet. Listen to `CollectionService:GetInstanceAddedSignal("DecoShadow")` and apply the current preset to new parts. ([[Graphics and Performance Toggles for Low-End Devices]])

## Mentioned in

28 notes in 17 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[CollectionService Patterns]]

### 03 Architecture and Networking
[[Instance Streaming]] · [[Network Ownership]]

### 05 UI and UX
[[Accessibility]]

### 06 World Building and Art
[[Collision and Physics Geometry]] · [[Foliage Props and Scatter]] · [[Level of Detail and Model Streaming]]

### 07 Lighting VFX and Audio
[[Light Sources and Shadows]]

### 08 Animation
[[Snippets - Enemy Client Animator]] · [[Snippets - Procedural Motion]]

### 09 Gameplay Systems
[[Raycasts Shapecasts and Spatial Queries]]

### 12 Performance Testing and Debugging
[[Client Zone Culling for Interiors and Cities]] · [[Hunting Memory Leaks Step by Step]]

### 15 AI Tools
[[AI Pitfalls - Networking and Security]]

### 23 Debugging Deep Dives
[[Debugging Client-Server Desync]] · [[Debugging Race Conditions and Yield Order]]

### 24 Worked Builds
[[Global Leaderboards End to End]]

### 25 Physics and Vehicles
[[Cars with Constraints - Suspension Steering and Drive]] · [[Destruction and Fracture]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]] · [[Lore Delivery Without Walls of Text]]

### 43 Genre Systems End to End
[[Obby Checkpoints and Stage Saves End to End]]

### 52 Core Concepts
[[Streaming Radius]]

### 58 Player QoL and Game Tweaks
[[Graphics and Performance Toggles for Low-End Devices]]

### 62 Engine Reference Cards
[[CollectionService - Engine Reference Card]]

Also mentioned in (not linked): StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs · UI Scale HUD Hide and Compact Mode · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
