---
tags: [atlas, api, type/atlas, area/animation, api/WeightCurrent]
---
# WeightCurrent

<!-- tldr:start -->
> [!tldr] TL;DR
> - `WeightCurrent` moves at a constant rate: `|target - current| / fadeTime` per second.
> - Track state: `TimePosition`, `Speed`, `Length`, `Looped`, `Priority` (and a numeric rank), `IsPlaying`, `WeightCurrent`...
> - Weight vs WeightCurrent vs WeightTarget.
>
> Cost: TL;DR ~100 tok · whole note ~320 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`WeightCurrent` moves at a constant rate: `|target - current| / fadeTime` per second. (from [[AnimationTrack Reference]])

API snapshot: member of `AnimationStreamTrack`, `AnimationTrack` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Track state: `TimePosition`, `Speed`, `Length`, `Looped`, `Priority` (and a numeric rank), `IsPlaying`, `WeightCurrent`... ([[Lua Keyframe Player Internals]])
- Weight vs WeightCurrent vs WeightTarget. Roblox docs (as of October 2026) list `WeightCurrent` and `WeightTarget` on `AnimationTrack` as not replicated, and `WeightTarget` as read only. ([[Animation Glossary]])
- WeightCurrent stuck below 1. A fade that was overridden, or `AdjustWeight` after `Stop`. ([[Debugging Animation Problems]])

## Mentioned in

9 notes in 2 sections. The 9 most relevant are linked:

### 08 Animation
[[Animation Glossary]] · [[AnimationTrack Reference]] · [[Debugging Animation Problems]] · [[Engine Gotchas]] · [[Lua Keyframe Player]] · [[Lua Keyframe Player Internals]] · [[Snippets - Lua Keyframe Player Core]] · [[Weapon Rig Player]]

### 62 Engine Reference Cards
[[Animator - Engine Reference Card]]

<!-- atlas:generated -->
