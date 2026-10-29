---
tags: [core-concept, animation, ui, math, game-feel, type/reference, area/ui, level/beginner, api/TweenService, area/animation]
---
# Easing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Real objects do not start or stop instantly, so linear motion reads as mechanical.
> - "Out" means the slow part is at the end.
> - Entrances and exits should not mirror. Exits are usually shorter (rule of thumb: about 70 to 80 percent of the entrance...
> - Strong curves need shorter durations. Exponential and Quint Out spend most of the time in a tiny tail; at 0.5 s they feel...
>
> Cost: TL;DR ~140 tok · whole note ~970 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Easing** is the shape of change over time: a function that maps linear progress `t` (0 to 1) to eased progress. Linear motion moves at constant speed; eased motion speeds up, slows down, overshoots or bounces. Roblox exposes this as `Enum.EasingStyle` (Linear, Sine, Quad, Cubic, Quart, Quint, Exponential, Circular, Back, Bounce, Elastic) combined with `Enum.EasingDirection` (In, Out, InOut) (Roblox docs, as of October 2026).

## Why it matters on Roblox

Real objects do not start or stop instantly, so linear motion reads as mechanical. Easing is the cheapest polish in the engine: the same 0.3 s panel slide feels clumsy with Linear and crisp with Quad Out, at no cost.

## The nuance most people miss

1. **"Out" means the slow part is at the end.** EasingDirection names where the easing happens, which confuses everyone at least once. `Out` starts fast and settles: right for things arriving (panels opening, items landing). `In` starts slow and leaves fast: right for things departing.
2. **Entrances and exits should not mirror.** Exits are usually shorter (rule of thumb: about 70 to 80 percent of the entrance duration) and use In, because the player has already decided to move on.
3. **Strong curves need shorter durations.** Exponential and Quint Out spend most of the time in a tiny tail; at 0.5 s they feel sluggish because the last 40 percent of the time changes almost nothing visible.
4. **Back and Elastic overshoot.** That is charming on a reward pop and wrong on anything precise (a health bar, a cursor). Overshoot on a scale can also briefly clip outside a `CanvasGroup` or scrolling frame.
5. **Easing is not only for motion.** Ease colour, transparency, volume and FOV too. A linear volume fade sounds abrupt at the end because loudness is perceived roughly logarithmically.
6. **Keep one motion language.** Pick two or three curves and durations for the whole game; random easing per menu feels like several games glued together.

## Tiny example

```lua
local TweenService = game:GetService("TweenService")
local open = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local close = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
TweenService:Create(panel, open, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
```

For custom code, `TweenService:GetValue(alpha, style, direction)` returns the eased value without creating a tween.

## Where this shows up

- [[Interpolation Easing and Curves Math]]: the formulas behind each style.
- [[Keyframes, Easing and Interpolation]]: easing between animation keys.
- [[UI Motion Language and Timing]]: a house style for UI motion.
- [[Timing Spacing and Frame Charts]]: spacing as hand-drawn easing.
- [[Tween and CFrame Animation of Objects]]: easing on parts.
- [[Reward Moments and Celebrations]]: overshoot used on purpose.
- [[Music and Adaptive Audio]]: eased crossfades.
- [[Camera Systems]]: eased FOV and zoom.
- [[Principles of Animation for Games]]: slow in and slow out.
- [[UI Design Systems]]: motion tokens as part of the system.
- [[Motion Sensitivity and Camera Comfort]]: gentler curves for comfort settings.

Related concepts: [[Tween vs Spring]], [[Anticipation]], [[Hit-Stop]].

## Connected notes
<!-- auto-links:start -->
[[CurveAnimation and Curve Channels]] · Official Docs - UI · Game Feel Start Here · UI and GUI Animation · KeyframeSequence Keyframe and Pose Reference · Animation Editor Workflow · [[Core Concepts Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Power Curve]] · [[Variance]] · [[Accessibility Contrast]] · [[Input Buffering]] · [[Core Loop]] · [[Expected Value]] · [[Skinning Weights]] · [[Thumbnail Contrast]]
<!-- related:end -->
