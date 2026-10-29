---
tags: [atlas, api, type/atlas, area/ui, area/gameplay, api/ViewportSize]
---
# ViewportSize

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ViewportSize` is in UI offset units for the safe area, not native pixels (Docs).
> - Cameras other than CurrentCamera (for example in a ViewportFrame) start with ViewportSize (1, 1).
> - Use `Player:GetCameraState()` (returns `CFrame`, `FieldOfView`, `ViewportSize`, synced client to server).
>
> Cost: TL;DR ~110 tok · whole note ~320 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ViewportSize` is in UI offset units for the safe area, not native pixels (Docs). (from [[Camera Systems]])

API snapshot: member of `Camera` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Cameras other than CurrentCamera (for example in a ViewportFrame) start with ViewportSize (1, 1). ([[Camera - Engine Reference Card]])
- Use `Player:GetCameraState()` (returns `CFrame`, `FieldOfView`, `ViewportSize`, synced client to server). ([[Server Authority and Input Migration 2026]])

## Mentioned in

9 notes in 8 sections. The 9 most relevant are linked:

### 05 UI and UX
[[Layout - Scale Offset and Constraints]] · [[Responsive UI for Phone Tablet Console and PC]]

### 09 Gameplay Systems
[[Camera Systems]]

### 12 Performance Testing and Debugging
[[In-Game Bug Report Button with Automatic Context]]

### 29 Luau Cookbook
[[Cookbook - UI]]

### 42 Accessibility and Inclusive Design
[[Readable Text and UI Scale]]

### 49 Roblox Platform Features
[[Server Authority and Input Migration 2026]]

### 58 Player QoL and Game Tweaks
[[UI Scale HUD Hide and Compact Mode]]

### 62 Engine Reference Cards
[[Camera - Engine Reference Card]]

<!-- atlas:generated -->
