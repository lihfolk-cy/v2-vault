---
tags: [core-concept, animation, ui, game-feel, math, type/reference, area/ui, level/beginner, area/animation]
---
# Tween vs Spring

<!-- tldr:start -->
> [!tldr] TL;DR
> - `TweenService` makes tweens one line, so most Roblox UI uses them for everything.
> - Springs must be stepped with `dt` and stay stable at low frame rates.
> - A spring's "duration" is a consequence. Designers think in seconds; expose frequency (how fast) and damping ratio (1 = no...
> - Tweens on the server replicate every step.
>
> Cost: TL;DR ~120 tok · whole note ~980 tok. Read more: ## The decision · ## The nuance most people miss
<!-- tldr:end -->

A **tween** moves a value from A to B over a fixed duration along an easing curve. A **spring** moves a value toward a target by simulating stiffness and damping each frame; it has no fixed duration, only a feel. Both animate the same things (UI positions, camera offsets, props), but they answer different questions.

## Why it matters on Roblox

`TweenService` makes tweens one line, so most Roblox UI uses them for everything. That works until the target changes mid-motion: a tween started toward one point has to be cancelled and restarted toward a new one, which produces a visible kink in velocity. Springs absorb target changes smoothly because they carry velocity forward. Choosing correctly is the difference between UI that feels designed and UI that feels jittery.

## The decision

| Use a tween when | Use a spring when |
|---|---|
| Duration must be exact (a 0.25 s panel open, a cutscene beat) | The target moves (camera follow, cursor-following tooltip, hover scale) |
| The motion plays once and ends | The motion may be interrupted many times |
| You want a specific curve shape | You want overshoot and settle that react to speed |
| The value is replicated or needs to finish at a known time | The value is client-only and per-frame |

## The nuance most people miss

1. **Springs must be stepped with `dt` and stay stable at low frame rates.** A naive spring integrated with large `dt` (a 30 fps phone, or a hitch) can explode. Use a closed-form critically damped spring or substep large frames.
2. **A spring's "duration" is a consequence.** Designers think in seconds; expose frequency (how fast) and damping ratio (1 = no overshoot, below 1 = bounce) so the numbers mean something.
3. **Tweens on the server replicate every step.** Tweening a part from the server sends property updates to every client; tween on the client when the motion is cosmetic.
4. **Interrupted tweens need a policy.** Restart from the current value (snappy, small kink), or ignore input until done (laggy). Either is fine if chosen on purpose; springs avoid the question.

## Tiny example

```lua
-- Critically damped spring toward target, stable for any dt.
local function springStep(x: number, v: number, target: number, freq: number, dt: number)
	local w = freq * 2 * math.pi
	local e = math.exp(-w * dt)
	local d = x - target
	local newX = target + (d + (v + w * d) * dt) * e
	local newV = (v - (v + w * d) * w * dt) * e
	return newX, newV
end
```

## Where this shows up

- [[Springs Damping and Smoothing]]: the full spring math and variants.
- [[Tween and CFrame Animation of Objects]]: tween patterns for parts.
- [[UI Motion Language and Timing]]: when UI uses which.
- [[Interpolation Easing and Curves Math]]: the curves behind tweens.
- [[Camera Systems]]: spring-follow cameras.
- [[Camera Shake and Camera FX]]: springs for recoil.
- [[Squash Stretch and Anticipation in UI and Characters]]: overshoot from underdamped springs.
- [[UI and GUI Animation]]: TweenService in UI.
- [[Procedural Weapon Motion]]: springs for sway.
- [[Declarative UI - React-Lua and Fusion]]: Fusion's built-in Spring and Tween objects.
- [[Motion Sensitivity and Camera Comfort]]: reducing bounce for comfort.

Related concepts: [[Easing]], [[Anticipation]], [[Frame Budget]].

## Connected notes
<!-- auto-links:start -->
[[Official Docs - UI]] · Snippets - Procedural Motion · Game Feel Start Here · [[Hit-Stop]] · Multi-Bone IK - FABRIK and CCD · Timing Spacing and Frame Charts · [[Core Concepts Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Accessibility Contrast]] · [[Deterministic Simulation]] · [[Expected Value]] · [[Variance]] · [[Input Buffering]] · [[Power Curve]] · [[Skinning Weights]] · [[Server Authority]]
<!-- related:end -->
