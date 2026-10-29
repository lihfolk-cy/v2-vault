---
tags: [atlas, api, type/atlas, area/vfx, area/world, api/Clouds]
---
# Clouds

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Clouds` render volumetric-looking clouds that drift with global wind.
> - Clouds under Terrain, moved by `GlobalWind`.
> - Clouds for scale. A few slow clouds make a sky feel big; heavy cover flattens lighting.
> - Ease, and order the channels. Clouds should lead, then haze, then precipitation, then sound.
>
> Cost: TL;DR ~120 tok · whole note ~350 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Clouds` render volumetric-looking clouds that drift with global wind. (from [[Atmosphere Sky Clouds and Post-Processing]])

`Clouds` (a child of `Terrain`) adds dynamic clouds with `Cover`, `Density` and `Color`. (from [[Water Sky and Atmosphere Art]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Clouds under Terrain, moved by `GlobalWind`. ([[Atmosphere Sky Clouds and Post-Processing]])
- Clouds for scale. A few slow clouds make a sky feel big; heavy cover flattens lighting. ([[Water Sky and Atmosphere Art]])
- Ease, and order the channels. Clouds should lead, then haze, then precipitation, then sound. ([[Weather System Architecture - State Machine, Transitions and Replication]])
- `Clouds` must be a child of `Terrain`; `Cover` and `Density` are the two controls that matter (Roblox docs). ([[Snow, Sandstorm, Blizzard and Ash Recipes]])

## Mentioned in

4 notes in 2 sections. The 4 most relevant are linked:

### 06 World Building and Art
[[Water Sky and Atmosphere Art]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Weather System Architecture - State Machine, Transitions and Replication]]

<!-- atlas:generated -->
