---
tags: [atlas, api, type/atlas, area/ui, area/vfx, api/CurrentCamera]
---
# CurrentCamera

<!-- tldr:start -->
> [!tldr] TL;DR
> - CurrentCamera is local to each client and Not Replicated.
> - Cameras other than CurrentCamera (for example in a ViewportFrame) start with ViewportSize (1, 1).
> - The listener is parented to the current camera; if your game replaces `CurrentCamera`, re-parent listeners on...
> - Caching `CurrentCamera` at module load. Symptom: effects stop working after a camera swap or a teleport arrival.
>
> Cost: TL;DR ~140 tok · whole note ~390 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

CurrentCamera is local to each client and Not Replicated. (from [[Workspace - Engine Reference Card]])

API snapshot: member of `ViewportFrame`, `Workspace` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Cameras other than CurrentCamera (for example in a ViewportFrame) start with ViewportSize (1, 1). ([[Camera - Engine Reference Card]])
- The listener is parented to the current camera; if your game replaces `CurrentCamera`, re-parent listeners on `Workspace:GetPropertyChangedSignal("CurrentCamera")`. ([[The Audio API - Players Emitters Wires and Effects]])
- Caching `CurrentCamera` at module load. Symptom: effects stop working after a camera swap or a teleport arrival. ([[Snippets - Camera Shake and FX]])

## Mentioned in

10 notes in 5 sections. The 10 most relevant are linked:

### 05 UI and UX
[[Layout - Scale Offset and Constraints]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[The Audio API - Players Emitters Wires and Effects]]

### 08 Animation
[[Snippets - Camera Shake and FX]]

### 42 Accessibility and Inclusive Design
[[Readable Text and UI Scale]]

### 62 Engine Reference Cards
[[Camera - Engine Reference Card]] · [[Workspace - Engine Reference Card]]

<!-- atlas:generated -->
