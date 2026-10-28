---
tags: [field-notes, springs, renderstepped, camera, nan, stability, game-feel, luau]
---
# Springs That Survive Long Frames - dt Clamps and NaN Guards

<!-- tldr:start -->
> [!tldr] TL;DR
> - Black screen after teleport or a big load, needs rejoin: Euler spring exploded on a long frame, `NaN` CFrame written each frame -> Clamp dt, sub-step, reset on `NaN`...
> - Springs jitter only on low-end phones: Bouncy spring past its stability limit at 25 to 30 fps -> Sub-steps of 1/120 s
> - Camera "pops" after alt-tab: Unclamped dt of several seconds integrated in one step -> `MAX_DT` clamp
> - No spring integrates more than 1/120 s per step.
> - `dt` clamped to about 0.1 s before stepping.
> - Value and velocity reset to target on `NaN` or runaway.
>
> Cost: TL;DR ~180 tok · whole note ~1.7k tok. Read more: ## A safe spring helper · ## Guard the write, not just the maths · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A spring stepped with explicit Euler in `RenderStepped` is stable at 60 fps and explodes on the first long frame, and if its output feeds the camera the result is not a glitch but a permanent black screen. This note explains why that happens, shows the numbers, and gives a spring helper that survives load hitches, alt-tabs and 25 fps phones. The maths of springs is in [[Springs Damping and Smoothing]] and [[Tween vs Spring]]; this note is about the failure mode.

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game, the reference project), **Rule of thumb**.

---

## What actually happened

**Measured.** A camera sway spring and a weapon-tilt spring were integrated with explicit Euler, one step per frame. Normal play was fine. After a teleport, a streaming burst or a big GUI build, one frame took 0.1 to 0.4 s. The spring overshot, the next frame overshot further in the other direction, and within a few frames the value was `inf`, then `NaN`. The camera script wrote `NaN` into `Camera.CFrame` every frame from then on. Every player who hit the hitch saw a black screen until they rejoined, on both phone and PC. Nothing errored: Luau arithmetic on `NaN` is silent.

## Why explicit Euler blows up

For a spring with angular frequency `w = 2 * pi * f` and damping ratio `z`, explicit Euler is only stable when each step is short compared with `1 / w`. Worked out for the two common tunings:

| Spring | Unstable when one step is longer than |
|---|---|
| 4 Hz, critically damped (`z = 1`) | `2 / w`, about 0.080 s |
| 4 Hz, bouncy (`z = 0.5`) | `1 / w`, about 0.040 s |
| 8 Hz, bouncy | about 0.020 s |

So a bouncy 4 Hz spring is already unstable on a 25 fps phone (0.040 s frames), and anything snappier dies on a single 0.1 s hitch. Semi-implicit (symplectic) Euler, where velocity is updated before position, is more forgiving but has the same kind of limit. The fix is not a better integrator alone; it is never letting one step be long.

## The four guards

1. **Clamp `dt`.** Anything over about 0.1 s is a hitch, not motion. Treat it as 0.1 s. The spring lags for one frame, which nobody notices.
2. **Fixed sub-steps.** Split the clamped `dt` into steps of at most 1/120 s. At 4 Hz that is `w * h` of about 0.21, comfortably stable even when bouncy. Twelve sub-steps on the worst frame cost microseconds.
3. **NaN and runaway reset.** After stepping, if the value or velocity is `NaN` or larger than any sane bound, snap to the target with zero velocity. `x ~= x` is the Luau test for `NaN`.
4. **Early-out at rest.** When position and velocity are both within a small epsilon of the target, set them exactly and skip the maths. Most springs are at rest most of the time, so this also saves frame time.

## A safe spring helper

```lua
-- Spring: semi-implicit Euler, fixed sub-steps, dt clamp, NaN reset, rest early-out.
local Spring = {}
Spring.__index = Spring

local MAX_DT = 0.1      -- longer frames are hitches
local MAX_STEP = 1 / 120
local REST_EPS = 1e-4
local RUNAWAY = 1e4     -- value units; anything beyond this is broken

local function broken(n: number): boolean
	return n ~= n or math.abs(n) > RUNAWAY
end

function Spring.new(initial: number, frequencyHz: number, dampingRatio: number)
	return setmetatable({
		x = initial,
		v = 0,
		target = initial,
		w = 2 * math.pi * frequencyHz,
		z = dampingRatio,
	}, Spring)
end

function Spring:setTarget(target: number)
	if not broken(target) then
		self.target = target
	end
end

function Spring:impulse(velocity: number)
	if not broken(velocity) then
		self.v += velocity
	end
end

function Spring:step(dt: number): number
	if dt ~= dt or dt <= 0 then
		return self.x
	end
	if math.abs(self.x - self.target) < REST_EPS and math.abs(self.v) < REST_EPS then
		self.x, self.v = self.target, 0
		return self.x
	end
	dt = math.min(dt, MAX_DT)
	local n = math.ceil(dt / MAX_STEP)
	local h = dt / n
	local w, z = self.w, self.z
	for _ = 1, n do
		local a = -w * w * (self.x - self.target) - 2 * z * w * self.v
		self.v += a * h
		self.x += self.v * h
	end
	if broken(self.x) or broken(self.v) then
		self.x, self.v = self.target, 0
	end
	return self.x
end

return Spring
```

Use one instance per scalar channel (roll, FOV, tilt). For vectors, run three channels or write the same helper over `Vector3` and test each component.

## Guard the write, not just the maths

A spring is one source of `NaN`. Others are `Unit` on a zero vector, `CFrame.lookAt` with identical points, and division by a zero distance. Put one check where the value leaves your code:

```lua
local function finiteCFrame(cf: CFrame): boolean
	for _, n in { cf:GetComponents() } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

-- in the camera step
if finiteCFrame(newCFrame) then
	camera.CFrame = newCFrame
end -- otherwise keep last frame's camera and let the springs reset
```

**Rule of thumb:** every per-frame writer of `Camera.CFrame`, a `Motor6D` transform or a part's `CFrame` should refuse non-finite values. A skipped frame is invisible; a `NaN` written every frame is permanent.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Black screen after teleport or a big load, needs rejoin | Euler spring exploded on a long frame, `NaN` CFrame written each frame | Clamp dt, sub-step, reset on `NaN`, guard the write |
| Springs jitter only on low-end phones | Bouncy spring past its stability limit at 25 to 30 fps | Sub-steps of 1/120 s |
| Camera "pops" after alt-tab | Unclamped dt of several seconds integrated in one step | `MAX_DT` clamp |
| Spring cost shows up in the MicroProfiler with nothing moving | Stepping springs at rest | Rest early-out |
| `NaN` reappears straight after a reset | The target itself is `NaN` (bad `Unit`, zero distance) | Validate targets in `setTarget` |

## Checklist

- [ ] No spring integrates more than 1/120 s per step.
- [ ] `dt` clamped to about 0.1 s before stepping.
- [ ] Value and velocity reset to target on `NaN` or runaway.
- [ ] Targets validated before they are accepted.
- [ ] Springs at rest skip work.
- [ ] Every per-frame CFrame write checks `finiteCFrame` first.
- [ ] Tested with an artificial 0.3 s hitch (`local t = os.clock() repeat until os.clock() - t > 0.3` in a debug key handler).

## Connected notes
<!-- auto-links:start -->
[[Springs Damping and Smoothing]] · [[Tween vs Spring]] · [[Camera Systems]] · [[Frame Order and RunService Timing]] · [[Layering Camera Feedback on the Default Camera]] · [[Field Notes Start Here]]
<!-- auto-links:end -->
