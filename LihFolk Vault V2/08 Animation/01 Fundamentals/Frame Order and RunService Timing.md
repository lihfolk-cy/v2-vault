---
tags: [fundamentals, runservice, timing, frame-order, procedural]
---
# Frame Order and RunService Timing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Procedural `Transform` write in `PreRender` / `RenderStepped` -> PreSimulation
> - Avoid: Writing in `Heartbeat` -> PreSimulation
> - Avoid: Composing onto unkeyed joints -> Assign from your own base
>
> Cost: TL;DR ~90 tok · whole note ~3.9k tok. Read more: ## What to do where · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

Procedural animation in Roblox is a race against the Animator: it overwrites joint transforms every frame, so where in the frame your code runs decides whether your layer sticks, flickers, lags a frame, or accumulates. This note lays out the frame pipeline as documented, says what to do in each slot, and covers the less obvious parts: one-frame latency, reading part positions mid-frame, deferred events, Edit mode, the server, and fixed-rate simulation.

## The frame

From the `RunService` documentation (client; the server has no render steps):

```
1. PreRender            (replaces RenderStepped)   BindToRenderStep callbacks, in priority order
2. Render               the frame is drawn from the current part CFrames
3. PreAnimation         last moment to change tracks before this frame's evaluation
4. Animation step       every Animator: advance time, sample, mix, write Transform
5. PreSimulation        (replaces Stepped)         read and modify animated Transforms here
   Transform batch      joint Transforms applied to parts in a parallel job, just before physics
6. Physics simulation   may run several substeps
7. PostSimulation       after physics
8. Heartbeat            end of frame; task.wait / task.delay resume here; then replication sends
```

| Event | Parameters | Status |
|---|---|---|
| `PreRender(deltaTimeRender)` | | current (client only) |
| `RenderStepped(deltaTime)` | | superseded by PreRender (not tagged deprecated in the API) |
| `PreAnimation(deltaTimeSim)` | | current |
| `PreSimulation(deltaTimeSim)` | | current |
| `Stepped(time, deltaTime)` | | superseded by PreSimulation |
| `PostSimulation(deltaTimeSim)` | | current |
| `Heartbeat(deltaTime)` | | current |

`BindToRenderStep(name, priority, fn)` runs inside the render-step stage in priority order (lower first). `Enum.RenderPriority`: `First` 0, `Input` 100, `Camera` 200, `Character` 300, `Last` 2000. Pass `Enum.RenderPriority.Camera.Value + 1`, not the enum item.

## What to do where

| Slot | Animation work |
|---|---|
| Input handlers, `PreRender` / render step | Read input; decide what to play; camera (BindToRenderStep around Camera priority); UI animation. Calling `Play()` here is picked up by this frame's animation step. |
| `PreAnimation` | Change tracks, weights, speeds, `TimePosition` so they apply this frame. Set up per-frame blend weights (locomotion blend by speed). |
| (Animator) | Writes `Transform` for every joint any playing track keys. |
| `PreSimulation` | **Procedural layers**: look-at, IK, recoil, foot locking, additive breathing. Read the animated `Transform` and compose. Custom Lua players that write `Transform` run here too. |
| `PostSimulation` / `Heartbeat` | Read final physics results; ground checks; spawn effects at bone positions; your own timers. Writing `Transform` here is too late for this frame (applied before next frame's physics, after the Animator has overwritten it again for keyed joints). |

### Why PreSimulation for procedural layers
- The Animator has already written this frame's pose, so you can **compose** with it (`Transform * extra` or `extra * Transform`).
- The `Transform` batch is applied after PreSimulation, so your write is what reaches the parts this frame.
- Next frame the Animator overwrites keyed joints again, so you must write **every frame**; nothing accumulates on keyed joints.
- Joints no track keys are **not** rewritten. Composing onto their current value accumulates. For those, keep your own base and assign it.
- On frames where `Animator.EvaluationThrottled` is true, the Animator did not rewrite even keyed joints. Skip the layer (Roblox's recommendation) or compose from a cached base. Details in [[Animator Deep Dive]].

```lua
--!strict
-- One dispatcher for all procedural layers on a rig, so their order is explicit.
-- (Multiple PreSimulation connections have no guaranteed order between them.)
local RunService = game:GetService("RunService")

type Layer = { name: string, order: number, apply: (dt: number) -> () }
local layers: {Layer} = {}

local function addLayer(layer: Layer)
	table.insert(layers, layer)
	table.sort(layers, function(a, b) return a.order < b.order end)
end

RunService.PreSimulation:Connect(function(dt: number)
	if animator.EvaluationThrottled then return end
	for _, layer in layers do
		layer.apply(dt) -- e.g. 10 spine lean, 20 look-at, 30 arm IK, 40 foot lock, 50 recoil
	end
end)
```

Order matters: IK must run after anything that moves its chain's parents (lean, look), and foot locking last among leg edits.

## Reading positions mid-frame

During `PreSimulation`, `BasePart.CFrame` still holds **last frame's** physics result: the new `Transform`s are applied in the batch after PreSimulation. `Bone.TransformedWorldCFrame` reflects bone transforms when read. So:
- A look-at that reads `Head.CFrame` in PreSimulation aims from last frame's head. Harmless one-frame lag.
- Foot IK that reads `Foot.CFrame` in PreSimulation to lock a planted foot will slip by one frame of motion. Compute the leg chain yourself with forward kinematics from the root and this frame's Transforms (see [[Motor6D Math and CFrame Composition]]).
- Effects that must sit exactly on a limb as rendered (trails, muzzle flashes) are best positioned in `PreRender` of the next frame, or attached with Attachments/constraints so the engine moves them.

## Latency: input to pixels

A typical button-to-motion chain:
1. Input arrives at the start of frame N; your handler calls `track:Play(0.05)`.
2. The animation step of frame N evaluates the track at its first instant (weight near 0 if it fades in).
3. Physics of frame N moves the parts.
4. Render of frame N+1 shows it.

So at least one frame between input and visible motion, plus the fade. A 0.1 s default fade adds 6 frames of half-visible motion at 60 fps; for responsive attacks use short fades (one production game used 0.05 s for abilities) and strong first poses.

Code that resumes from `task.wait()` runs at Heartbeat, after physics. A `Play()` there takes effect at the next frame's animation step: one extra frame compared with calling it from an input handler or PreAnimation.

## Deferred events and markers

With `Workspace.SignalBehavior` set to Deferred, signal handlers (including marker and `Stopped` handlers) do not run inside the Animator step. They resume at the engine's invocation points, which include PreAnimation. Practical effect: a marker handler that starts a VFX or plays the next track runs a little later than the marker's frame, typically at the next resumption point. Do not chain tight combo timing purely on handler callbacks; schedule from data and track time.

## Camera work around the character

- Default camera scripts run in the render step at `Camera` priority (200), after `Input` (100).
- A camera effect layered **on** the default camera (shake, FOV punch, roll) should apply after the camera script and remove itself before the next camera update, so the camera script never sees your offset and nothing drifts. One production camera FX module removed its offset at `Camera - 1` and applied it at `Camera + 1`, offsetting only camera-space translation and roll (never the look direction), summing all active envelopes and capping them (FOV 12, offset 1.6 studs, roll 4 degrees).
- Cameras that follow an animated part (head-cam, cinematic follow) read the part in the render step, which shows exactly what is about to be drawn. See [[Camera Shake and Camera FX]].

## The server

The server runs the same simulation steps without rendering: PreAnimation, animation step, PreSimulation, physics, PostSimulation, Heartbeat, at the server's frame rate (normally about 60 Hz). Server Animators evaluate server-played tracks so server-side parts are in pose for physics and hit detection. Procedural layers on the server only matter for the server's own physics and queries; they do not replicate visually (see [[Replication and Ownership]]).

## Edit mode

- Nothing simulates in Edit: `PreSimulation` and `PreAnimation` do not drive a running world, and `Transform` writes do not move parts. One production player ran on `PreSimulation` in play and on `Heartbeat` in Edit, where it also had to pose parts itself.
- `Animator:StepAnimations(dt)` is the way to run the Animator in Edit (plugins and command bar only).
- See [[Testing Animations in Studio]].

## Fixed-rate simulation

`Workspace.UseFixedSimulation` (a rollout setting, required for Server Authority) changes the picture:
- Character controller updates and joint transforms run at a **fixed frequency** instead of once per rendered frame.
- `RunService:BindToSimulation(fn, frequency = Hz30, priority = 2000)` runs at the fixed rate for physics controllers and prediction.
- `RunService:BindToAnimation(fn, frequency = Hz30, priority = 2000)` is the fixed-rate counterpart to PreAnimation: with fixed simulation it runs before Animators update; without it, it runs just before BindToSimulation callbacks, so do not assume pre-animation ordering in that case.
- Both are called again during server-authority **resimulation**; reading or writing unsynchronised properties there errors. `RunService:IsResimulating()` lets you skip side effects (sounds, remote calls) during replays.
- `Enum.StepFrequency`: `Hz60`, `Hz30`, `Hz15`, `Hz10`, `Hz5`, `Hz1`.
- Known issue reported by developers and acknowledged by Roblox staff: with fixed simulation, setting `Transform` on Motor6Ds or AnimationConstraints may not take effect while an animation is playing. Test procedural layers before adopting Server Authority.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Procedural `Transform` write in `PreRender` / `RenderStepped` | Overwritten by the Animator: flicker or no effect | PreSimulation |
| Writing in `Heartbeat` | Effect one frame late, or none on keyed joints | PreSimulation |
| Composing onto unkeyed joints | Spins or drifts endlessly | Assign from your own base |
| Ignoring throttled frames | Offsets stack on distant rigs | Check `EvaluationThrottled` |
| Several independent PreSimulation layers | Order changes between runs; IK fights look-at | One ordered dispatcher |
| Reading `Part.CFrame` for foot locks in PreSimulation | One-frame foot slip | FK from Transforms |
| Camera shake applied without removal | Camera drifts away over time | Remove before the camera script, apply after |

## See also
[[Animator Deep Dive]] · [[Motor6D Math and CFrame Composition]] · [[Procedural Animation]] · [[Springs Damping and Smoothing]] · [[Camera Shake and Camera FX]] · [[Testing Animations in Studio]] · [[Performance and Memory]]

## Nuances and edge cases

1. **Clients are not fixed at 60 FPS any more.** Players can raise the frame rate cap in settings (desktop up to 240 in recent clients; check the current options before quoting a number to players), and phones commonly run at 30 to 60. Anything counted in frames ("hold for 3 frames") means 12 ms on one machine and 100 ms on another. Count in seconds, and use `dt` from the event for every integration.
2. **Server frame rate drops under load.** The server targets about 60 Hz but slows when scripts or physics overrun. A server at 30 Hz delivers Heartbeat half as often, so server-side timers built on Heartbeat counts drift, and server hit checks sampled per step see fewer positions. Use `os.clock()` deltas or `workspace:GetServerTimeNow()` for server timing, never step counts. Watch server heartbeat in the developer console during load tests with 50 or more players.
3. **Backgrounded apps.** On mobile, when the app is backgrounded, frames stop. On return, the first frame can have a `dt` of many seconds. Clamp `dt` for springs, procedural motion and anything integrated; skip a frame of effects if `dt` is absurd.
4. **Parallel phases.** `ConnectParallel` handlers on these events run in a parallel phase before the serial one. They can read and compute but cannot write most instance properties. A pattern that fits frame order: compute IK or look-at targets in parallel during `PreSimulation`, then write `Transform`s in a serial handler on the same event. The ordering between your parallel and serial handlers on the same event is well defined (parallel first), but between different scripts' serial handlers it is not; keep one dispatcher.
5. **BindToRenderStep priorities are shared.** `Enum.RenderPriority` values (First 0, Input 100, Camera 200, Character 300, Last 2000) are conventions, and every script binding at the same value runs in an unspecified order. Pick priorities with gaps (Camera + 1, Camera + 2) and document them; never rely on two binds at the same priority running in a given order.
6. **Deferred signals move work, not cost.** With deferred signal behaviour, many handlers queue and run at resumption points. A burst of 200 marker events on one frame (a crowded wave fight) still costs the same total time, now concentrated at the resumption point. MicroProfiler will show it under a different label than you expect.
7. **Server Authority changes everything here.** Under fixed simulation and resimulation, code in the simulation binds can run several times per rendered frame during a correction. Side effects such as playing sounds, firing remotes, or incrementing counters must be guarded with `RunService:IsResimulating()`. This area is new and still changing; re-read the docs before adopting it.

The senior trade-off: putting all per-frame work into one ordered dispatcher (one connection per event, systems registered with explicit order) costs a little upfront structure but removes a whole class of "works on my machine" ordering bugs that only appear when script load order changes.

## Common mistakes in production

1. **Frame-count timers.** Symptom: effects last twice as long on phones as on PC. Fix: time in seconds.
2. **Heartbeat-count cooldowns on the server.** Symptom: cooldowns stretch under load. Fix: compare against a stored timestamp.
3. **No `dt` clamp.** Symptom: springs fling and props teleport after the app resumes from background. Fix: clamp `dt` to a ceiling like 1/20 s.
4. **Two systems bound at the same render priority.** Symptom: an ordering bug that appears after an unrelated script is added. Fix: unique priorities with documented gaps.
5. **Remotes fired from a simulation bind under Server Authority.** Symptom: duplicate requests during corrections. Fix: guard with `IsResimulating`.

## Related decisions

- [[Task Library Coroutines and Yielding]]: where `task.wait` resumes in the frame and why it costs a frame.
- [[Parallel Luau and Actors]]: the parallel phase rules for compute versus writes.
- [[Custom Schedulers and Coroutine Patterns]]: building the single ordered dispatcher.
- [[MicroProfiler Guide]]: reading where each phase spends its time.
- [[Debugging Race Conditions and Yield Order]]: diagnosing order bugs between handlers.
- [[Client Prediction and Reconciliation for Combat]]: why resimulation guards matter for combat.
- [[Input Responsiveness Buffering and Coyote Time]]: shaving the input to pixel latency described above.
- [[Developer Console and Stats]]: watching server heartbeat rate under load.

## Connected notes
<!-- auto-links:start -->
[[Script Performance]] · [[Engine Gotchas]] · [[Snippets - Procedural Motion]] · [[Events Signals and Connections]] · [[Camera Systems]] · [[Building a Signal Library]] · [[Animation Start Here]]
<!-- auto-links:end -->
