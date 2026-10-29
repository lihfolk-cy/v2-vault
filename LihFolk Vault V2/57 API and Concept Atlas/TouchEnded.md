---
tags: [atlas, api, type/atlas, area/gameplay, area/ui, api/TouchEnded]
---
# TouchEnded

<!-- tldr:start -->
> [!tldr] TL;DR
> - `TouchEnded` is the reverse. (from Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched)
> - Avoid: building "is in the area" on `TouchEnded`.
> - Avoid: `Touched`/`TouchEnded` on big zone parts -> Point-in-volume resolver with hysteresis.
> - `TouchEnded` is unreliable for "left the area" logic.
>
> Cost: TL;DR ~120 tok · whole note ~370 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`TouchEnded` is the reverse. (from [[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]])

API snapshot: member of `BasePart`, `UserInputService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: building "is in the area" on `TouchEnded`. ([[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]])
- Avoid: `Touched`/`TouchEnded` on big zone parts -> Point-in-volume resolver with hysteresis. ([[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]])
- `TouchEnded` is unreliable for "left the area" logic. ([[Debugging Physics and Network Ownership]])

## Mentioned in

9 notes in 7 sections. The 9 most relevant are linked:

### 05 UI and UX
[[Touch Gestures - Pinch, Pan, Swipe and Long Press]]

### 06 World Building and Art
[[Collision and Physics Geometry]]

### 09 Gameplay Systems
[[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]] · [[Physics Assemblies and Constraints]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]

### 12 Performance Testing and Debugging
[[Physics Performance]]

### 23 Debugging Deep Dives
[[Debugging Physics and Network Ownership]]

### 33 Level Design
[[Lobby and Hub Design]]

### 62 Engine Reference Cards
[[BasePart - Engine Reference Card]]

<!-- atlas:generated -->
