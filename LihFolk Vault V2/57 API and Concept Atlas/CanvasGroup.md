---
tags: [atlas, api, type/atlas, area/ui, area/animation, api/CanvasGroup]
---
# CanvasGroup

<!-- tldr:start -->
> [!tldr] TL;DR
> - CanvasGroup: A GUI container rendered as one image (fades, clipping).
> - Rotated or rounded clipping uses CanvasGroup, sparingly.
> - Avoid: Rotating a frame with `ClipsDescendants` -> `CanvasGroup` window, rotate an inner frame.
> - Rotating map uses a CanvasGroup window; upright icons counter-rotated.
>
> Cost: TL;DR ~120 tok · whole note ~430 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

CanvasGroup: A GUI container rendered as one image (fades, clipping). (from [[Glossary]])

`CanvasGroup` has a cost: texture memory per group. (from [[Debugging UI Layout and Input]])

API snapshot: class, inherits `GuiObject` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Rotated or rounded clipping uses CanvasGroup, sparingly. ([[Debugging UI Layout and Input]])
- Avoid: Rotating a frame with `ClipsDescendants` -> `CanvasGroup` window, rotate an inner frame. ([[Minimap and World Map UI - Projection, Rotation and Fog of War]])
- Rotating map uses a CanvasGroup window; upright icons counter-rotated. ([[Minimap and World Map UI - Projection, Rotation and Fog of War]])
- Avoid: `ClipsDescendants` on a frame with `UICorner` and expecting rounded clipping (use `CanvasGroup`, which costs memory). ([[AI Pitfalls - UI and Input]])

## Mentioned in

14 notes in 9 sections. The 14 most relevant are linked:

### 05 UI and UX
[[Accessibility]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[ScreenGui Fundamentals]] · [[UI Design Systems]] · [[UI Motion Language and Timing]]

### 08 Animation
[[Reference - Purple Anime Settings UI (Claude + Figma)]] · [[UI and GUI Animation]]

### 12 Performance Testing and Debugging
[[Rendering Performance]]

### 15 AI Tools
[[AI Pitfalls - UI and Input]]

### 17 Pipelines
[[UI Asset Pipeline]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 47 Game Feel and Juice
[[Juice on a Budget - Mobile and Low-End]]

### 52 Core Concepts
[[Easing]]

### Root notes
[[Glossary]]

<!-- atlas:generated -->
