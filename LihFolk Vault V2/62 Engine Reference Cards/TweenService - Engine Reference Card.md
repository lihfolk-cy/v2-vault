---
tags: [reference, engine, tweenservice, api/TweenService, type/reference, area/scripting, level/intermediate, api/Tween]
---

# TweenService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: two tweens writing the same property at once.
> - Avoid: expecting `Cancel` to snap back to the start.
> - Avoid: pausing a tween during its delay.
> - Each animated property has a single owner tween at a time.
> - TweenInfo values are stated explicitly where the defaults are not the intent.
> - `Completed` handlers branch on the PlaybackState they receive.
>
> Cost: TL;DR ~130 tok · whole note ~1.2k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Builds `Tween` objects that interpolate instance properties over time, plus two math helpers for custom easing and spring-style smoothing. Topic notes: [[Tween and CFrame Animation of Objects]], [[Tween vs Spring]], [[TweenService]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| Create | method | `(instance: Instance, tweenInfo: TweenInfo, propertyTable: {[string]: any}) -> Tween` | - | One tween per instance; call again for another object | no |
| GetValue | method | `(alpha: number, easingStyle: Enum.EasingStyle, easingDirection: Enum.EasingDirection) -> number` | - | alpha clamped 0-1; errors for [[Bezier Curves\|Bezier]] and Spring styles | no |
| SmoothDamp | method | `(current, target, velocity, smoothTime: number, maxSpeed: number?, dt: number?) -> (newValue, newVelocity)` | maxSpeed = math.huge, dt = engine delta | number, Vector2, Vector3, CFrame; thread-safe | no |
| TweenInfo.new | constructor | `(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)` | 1, Quad, Out, 0, false, 0 | Read-only after creation | no |
| TweenInfo.RepeatCount | prop | number | 0 | -1 repeats forever | - |
| TweenInfo.Reverses | prop | boolean | false | Plays back toward the start | - |
| TweenInfo.DelayTime | prop | number | 0 | Seconds before start | - |
| Tween:Play | method | `()` | - | No effect while already playing | no |
| Tween:Pause | method | `()` | - | Keeps progress; only works while Playing | no |
| Tween:Cancel | method | `()` | - | Resets progress, not the properties | no |
| Tween.PlaybackState | prop | Enum.PlaybackState | - | ReadOnly, NotReplicated | - |
| Tween.Completed | event | `(playbackState: Enum.PlaybackState)` | - | Fires on finish and on Cancel | - |

## Limits and defaults

- Tweenable types: number, boolean, CFrame, Rect, Color3, UDim, UDim2, Vector2, Vector2int16, Vector3 and EnumItem.
- TweenInfo defaults: time 1 s, EasingStyle Quad, EasingDirection Out, repeatCount 0, reverses false, delayTime 0.
- One property, one tween: starting a second tween on the same property cancels the first and the newest wins. Different properties can run in parallel.
- A Tween's configuration is fixed once created. New goals need a new Tween.
- `Tween` cannot be made with `Instance.new`; use `TweenService:Create`.
- `SmoothDamp` is a critically damped spring, so it ends close to the target after `smoothTime` rather than exactly on it. Feed the returned velocity into the next call and start it at `0`, `Vector2.zero`, `Vector3.zero` or `CFrame.identity`.

## Replication and authority

- The reference pages set no server-only or client-only rule for TweenService.
- `Tween.PlaybackState` is NotReplicated, so each side tracks its own tween state.
- `SmoothDamp` is marked thread-safe and suits per-frame work in parallel code.

## Common mistakes

- Avoid: two tweens writing the same property at once. Symptom: the first tween stops partway as the newer one takes over.
- Avoid: expecting `Cancel` to snap back to the start. Symptom: the object stays wherever it was; set the original values yourself.
- Avoid: pausing a tween during its delay. Symptom: the pause is ignored and the tween plays after `DelayTime`.
- Avoid: calling `GetValue` with `EasingStyle.Spring` or `Bezier`. Symptom: an error; use `SmoothDamp` for spring motion.
- Avoid: reusing one Tween for many parts. Symptom: only the original instance moves; create one Tween per instance.
- Avoid: treating `Completed` as "reached the goal". Symptom: logic runs after a Cancel; check that the state passed is `Enum.PlaybackState.Completed`.

## Checklist

- Each animated property has a single owner tween at a time.
- TweenInfo values are stated explicitly where the defaults are not the intent.
- `Completed` handlers branch on the PlaybackState they receive.
- Per-frame follow cameras and UI use `SmoothDamp` with a persisted velocity.

Source: https://create.roblox.com/docs/reference/engine/classes/TweenService, https://create.roblox.com/docs/reference/engine/classes/TweenBase, https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo - verified 2026-10-29

<!-- related:start -->
## Related
[[UI Motion Language and Timing]] · [[Camera - Engine Reference Card]] · [[BasePart - Engine Reference Card]] · [[Animator - Engine Reference Card]] · [[ParticleEmitter - Engine Reference Card]] · [[ScrollingFrame - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]] · [[RunService - Engine Reference Card]] · [[GuiService - Engine Reference Card]]
<!-- related:end -->
