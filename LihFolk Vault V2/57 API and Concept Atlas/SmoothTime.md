---
tags: [atlas, api, type/atlas, area/animation, api/SmoothTime]
---
# SmoothTime

<!-- tldr:start -->
> [!tldr] TL;DR
> - `SmoothTime` (default 0.05 s) is a critically damped approach to the target; 0 disables smoothing.
> - `Weight` 0..1 blends with the animation (default 1), but even at 0 `SmoothTime` and `Pole` can still affect the pose: use...
> - For a pure look-at with no custom logic, an `IKControl` of type `LookAt` does this with `SmoothTime` built in.
>
> Cost: TL;DR ~130 tok · whole note ~230 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`SmoothTime` (default 0.05 s) is a critically damped approach to the target; 0 disables smoothing. (from [[Snippets - IK]])

API snapshot: member of `IKControl` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `Weight` 0..1 blends with the animation (default 1), but even at 0 `SmoothTime` and `Pole` can still affect the pose: use `Enabled = false` to turn it off fully. ([[Snippets - IK]])
- For a pure look-at with no custom logic, an `IKControl` of type `LookAt` does this with `SmoothTime` built in. ([[Snippets - Procedural Motion]])

## Mentioned in

5 notes in 1 sections. The 5 most relevant are linked:

### 08 Animation
[[IKControl Reference]] · [[Look-At Aim and Head Tracking]] · [[Snippets - IK]] · [[Snippets - Procedural Motion]] · [[Troubleshooting Table]]

<!-- atlas:generated -->
