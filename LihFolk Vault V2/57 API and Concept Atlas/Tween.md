---
tags: [atlas, api, type/atlas, area/ui, area/vfx, api/Tween]
---
# Tween

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Tween.PlaybackState` is NotReplicated, so each side tracks its own tween state.
> - A Tween's configuration is fixed once created.
> - Do not create Tween objects per frame. Create on events.
> - `Tween:Cancel()` stops the tween and leaves the property wherever it was; it does not snap back.
>
> Cost: TL;DR ~110 tok · whole note ~330 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Tween.PlaybackState` is NotReplicated, so each side tracks its own tween state. (from [[TweenService - Engine Reference Card]])

API snapshot: class, inherits `TweenBase` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- A Tween's configuration is fixed once created. ([[TweenService - Engine Reference Card]])
- Do not create Tween objects per frame. Create on events. ([[UI and GUI Animation]])
- `Tween:Cancel()` stops the tween and leaves the property wherever it was; it does not snap back. ([[UI Motion Language and Timing]])
- Tween `Size` from 0 to 12 to 20 (rule of thumb) rather than snapping, and pop it on close. ([[Atmosphere Sky Clouds and Post-Processing]])

## Mentioned in

9 notes in 6 sections. The 9 most relevant are linked:

### 05 UI and UX
[[Accessibility]] · [[Declarative UI - React-Lua and Fusion]] · [[UI Motion Language and Timing]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Stylized Lighting Recipes]]

### 08 Animation
[[UI and GUI Animation]]

### 29 Luau Cookbook
[[Cookbook - UI]]

### 40 Game Math
[[Interpolation Easing and Curves Math]]

### 62 Engine Reference Cards
[[TweenService - Engine Reference Card]]

<!-- atlas:generated -->
