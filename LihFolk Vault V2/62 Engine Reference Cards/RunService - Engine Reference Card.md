---
tags: [reference, engine, runservice, api/RunService, type/reference, area/scripting, level/intermediate, api/PreRender, api/PreSimulation, api/BindToRenderStep]
---

# RunService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: heavy work inside PreRender or BindToRenderStep.
> - Avoid: writing new code against RenderStepped or Stepped.
> - Avoid: passing `Enum.RenderPriority.Camera` without `.Value`.
> - Each per-frame job sits in the right phase: visuals in PreRender, forces in PreSimulation, game logic in Heartbeat.
> - Every connection and render-step name is stored and cleaned up.
> - Frame-rate independent math multiplies by the passed delta time.
>
> Cost: TL;DR ~150 tok · whole note ~1.5k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The service that owns the frame loop and tells a script where it is running; see [[RunService]], [[Frame Order and RunService Timing]] and [[Heartbeat]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| PreRender | event | `(deltaTimeRender: double)` | - | Client only; runs before the frame is drawn; replaces RenderStepped | - |
| PreAnimation | event | `(deltaTimeSim: double)` | - | Both; tweak track speed or priority before Animators step | - |
| PreSimulation | event | `(deltaTimeSim: double)` | - | Both; set forces and velocities before physics; replaces Stepped | - |
| PostSimulation | event | `(deltaTimeSim: double)` | - | Both; final adjustments after physics, before Heartbeat | - |
| Heartbeat | event | `(deltaTime: double)` | - | Both; end of frame, where most periodic game logic belongs | - |
| BindToRenderStep | method | `(name: string, priority: int, function: (deltaTime) -> ())` | - | Client only; ordered by priority, lower first | no |
| UnbindFromRenderStep | method | `(name: string)` | - | Client only; pairs with BindToRenderStep by name | no |
| BindToSimulation | method | `(function, frequency: Enum.StepFrequency?, priority: int?) -> RBXScriptConnection` | Hz30, priority 2000 | Needs `Workspace.UseFixedSimulation`; synchronized properties only | no |
| BindToSimulationParallel | method | `(function, frequency?, priority?) -> RBXScriptConnection` | Hz30, priority 2000 | Caller must sit under an Actor | no |
| BindToAnimation | method | `(function, frequency?, priority?) -> RBXScriptConnection` | Hz30, priority 2000 | Fixed-rate counterpart of PreAnimation | no |
| IsClient / IsServer | method | `() -> boolean` | - | Branch shared ModuleScripts | no |
| IsStudio | method | `() -> boolean` | - | Gate debug-only tools | no |
| IsRunning / IsRunMode / IsEdit | method | `() -> boolean` | - | Plugins and edit-time tooling | no |
| GetPredictionStatus | method | `(context: Instance) -> Enum.PredictionStatus` | - | Server authority prediction debugging | no |
| Misprediction / Rollback | event | Rollback: `(time: double)` | - | Server authority model only | - |
| RenderStepped | event | `(deltaTime: double)` | - | Superseded by PreRender; keep for old code | - |
| Stepped | event | `(time: double, deltaTime: double)` | - | Superseded by PreSimulation | - |
| Run / Pause / Stop | method | `() -> ()` | - | PluginSecurity; not for game scripts | no |

Retired names and their replacements:
- `RenderStepped` -> `PreRender`; `Stepped` -> `PreSimulation`.
- `Reset` is deprecated (PluginSecurity) and has no gameplay use.

## Limits and defaults

- Frame order each frame: PreRender, then PreAnimation, PreSimulation, physics, PostSimulation, Heartbeat, then replication send.
- Physics may run several substeps between PreSimulation and PostSimulation; `deltaTimeSim` ignores physics throttling.
- `BindToSimulation`, `BindToSimulationParallel` and `BindToAnimation` default to `Enum.StepFrequency.Hz30` and priority `2000`; frequencies range from `Hz1` to `Hz60`.
- `BindToRenderStep` default control priorities: player input `100`, camera `200`; use `Enum.RenderPriority.Camera.Value - 1` style integers, always with `.Value`.
- Rendering waits for every PreRender and render-step binding to finish, so each frame of client work comes straight out of the frame budget.

## Replication and authority

- `RunService` is a NotReplicated service; every machine runs its own loop.
- PreRender and `BindToRenderStep` work only in client contexts (LocalScript, a module it requires, or a Script with `RunContext = Enum.RunContext.Client`).
- Bound simulation functions error when they touch unsynchronized properties; store such state in attributes and apply it in PostSimulation so rollback stays correct.
- In Studio edit mode `IsClient` and `IsServer` both return true, so test both branches in Play mode.

## Common mistakes

- Avoid: heavy work inside PreRender or BindToRenderStep. Symptom: choppy visuals because the frame cannot render until your code returns.
- Avoid: writing new code against RenderStepped or Stepped. Symptom: mixing superseded and current events makes ordering hard to reason about; use PreRender and PreSimulation.
- Avoid: passing `Enum.RenderPriority.Camera` without `.Value`. Symptom: the binding does not work; pass the integer value.
- Avoid: calling BindToSimulation in a place without fixed simulation. Symptom: the method is unavailable; enable `Workspace.UseFixedSimulation` first.
- Avoid: per-frame loops that never disconnect. Symptom: leaked connections keep running after the object they serve is gone.

## Checklist

- Each per-frame job sits in the right phase: visuals in PreRender, forces in PreSimulation, game logic in Heartbeat.
- Every connection and render-step name is stored and cleaned up.
- Frame-rate independent math multiplies by the passed delta time.
- Shared modules branch on `IsServer()` / `IsClient()` rather than guessing.

Source: https://create.roblox.com/docs/reference/engine/classes/RunService and https://create.roblox.com/docs/performance-optimization/microprofiler/task-scheduler - verified 2026-10-29

<!-- related:start -->
## Related
[[Animator - Engine Reference Card]] · [[MessagingService - Engine Reference Card]] · [[BadgeService - Engine Reference Card]] · [[MarketplaceService - Engine Reference Card]] · [[TweenService - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]] · [[Camera - Engine Reference Card]] · [[Instance - Engine Reference Card]]
<!-- related:end -->
