---
tags: [procedural, springs, damping, smoothing, math, frame-rate, luau, type/guide, area/animation, level/intermediate, area/scripting]
---
# Springs Damping and Smoothing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Smoothing feels faster on high-refresh monitors: `lerp` by a constant per frame -> `1 - exp(-k dt)`
> - Spring explodes after a lag spike: explicit or semi-implicit step with a large `dt` -> clamp `dt`, substep, or exact update
> - Spring "dies" at 30 fps, lively at 144: implicit Euler's numerical damping -> exact update
>
> Cost: TL;DR ~120 tok · whole note ~3.4k tok. Read more: ## Stepping a spring: four integrators · ## First-order smoothing: the `lerp` fix · ## Common mistakes
<!-- tldr:end -->

Almost every procedural motion that feels alive is a spring underneath: a head that settles on its target, a recoil that kicks and returns, a cape that lags, a camera that eases, a wrist that "gives" when it catches a spinning blade. This note derives the damped spring, compares the ways to step it (and which ones break at low frame rates), gives an exact frame-rate-independent implementation, and covers the simpler first-order smoothing that most code should be using instead of `lerp(x, target, 0.1)`.

## The damped spring

A value `x` chasing a target `T` with velocity `v`:

```
x'' = omega^2 * (T - x) - 2 * zeta * omega * x'
```

| Parameter | Meaning | Feel |
|---|---|---|
| `omega = 2 pi f` | natural angular frequency (rad/s); `f` in Hz | higher = snappier |
| `zeta` | damping ratio | below 1: overshoots and wobbles; 1: fastest without overshoot (critical); above 1: sluggish |

Useful closed-form facts for tuning by numbers instead of by trial:

| Quantity | Formula | Examples |
|---|---|---|
| Overshoot of a step (`zeta < 1`) | `exp(-zeta * pi / sqrt(1 - zeta^2))` | zeta 0.72: 3.8%; 0.55: 12.6%; 0.5: 16.3%; 0.42: 23.4%; 0.34: 32.1% |
| Wobble frequency | `omega * sqrt(1 - zeta^2)` | slightly below `f` |
| Settling (2% band), underdamped | about `4 / (zeta * omega)` | 7 Hz, zeta 0.72: 0.13 s |
| Settling (2%), critical | `omega * t = 5.83`, so `t = 0.93 / f` | 6 Hz: 0.15 s |
| Lag behind a target moving at speed `u` | `2 * zeta * u / omega` | a 3 Hz critical spring trails a 20 studs/s target by 2.1 studs |

The reference project's enemy reaction layer chose its per-role springs exactly by these trade-offs: spines stiff and well damped (7 Hz, zeta 0.72, about 4% overshoot), tails and dangling cloth loose and bouncy (3.4 Hz / 0.42 and 2.6 Hz / 0.34, 23% and 32% overshoot) so they lag and whip. The full table is in [[Multi-Bone IK - FABRIK and CCD]].

## Stepping a spring: four integrators

### 1. Explicit Euler (do not use)

```
x += v * dt;  v += a(x, v) * dt
```

Gains energy every step; any spring eventually explodes. Listed only so you recognise it.

### 2. Semi-implicit (symplectic) Euler

```
v += a(x, v) * dt;  x += v * dt
```

Updating velocity first makes it stable for an undamped spring when `omega * dt < 2`, and it is cheap. Its accuracy degrades well before that limit (rule of thumb: keep `omega * dt` under about 0.5). The trap is frame rate: a 7 Hz spring has `omega = 44 rad/s`; at 60 fps `omega * dt = 0.73`, at 30 fps 1.47, and after a 0.05 s hitch 2.2: unstable. The fix the reference project used is **substepping**:

```lua
-- One spring per joint, as rotation vectors (radians, body frame). Substeps keep omega*h small.
local function springStep(x: Vector3, v: Vector3, target: Vector3, f: number, zeta: number, dt: number): (Vector3, Vector3)
	local w = 2 * math.pi * f
	local n = math.max(1, math.ceil(dt / (1 / 120)))   -- 120 Hz substeps
	local h = dt / n
	for _ = 1, n do
		local a = (target - x) * (w * w) - v * (2 * zeta * w)
		v += a * h
		x += v * h
	end
	return x, v
end
```

At 120 Hz the 7 Hz spring has `omega * h = 0.37`. The project also clamped `dt` to 1/20 s before stepping, so a long hitch cannot turn into dozens of substeps.

### 3. Implicit (backward) Euler

Solve the update so the *new* state satisfies the equation. For this linear spring it has a closed form:

```
v1 = (v + dt * omega^2 * (T - x)) / (1 + 2 * dt * omega + dt^2 * omega^2)
x1 = x + dt * v1
```

Derivation: write `v1 = v + dt * (omega^2 (T - x1) - 2 omega v1)` (critical damping shown) with `x1 = x + dt * v1`, substitute and collect `v1`. It is unconditionally stable: no frame rate makes it explode. The price is **numerical damping**: it always settles slower and overshoots less than the real spring, and how much depends on `dt`, so the feel changes with frame rate. The spring in older versions of the snippets notes is this integrator; it is fine for UI and cameras.

### 4. Exact (analytic) update: frame-rate independent

The spring equation has an exact solution, so you can jump any `dt` exactly. With error `e = x - T` and velocity `v` (target held constant over the step):

**Critical (`zeta = 1`):**

```
e(t) = (e0 + (v0 + omega e0) t) * exp(-omega t)
v(t) = (v0 - omega (v0 + omega e0) t) * exp(-omega t)
```

(Differentiate `e(t)` to check `v(t)`; both satisfy `e'' = -omega^2 e - 2 omega e'`.)

**Underdamped (`zeta < 1`)**, with `a = zeta omega`, `wd = omega sqrt(1 - zeta^2)`:

```
e(t) = exp(-a t) * ( e0 cos(wd t) + ((v0 + a e0) / wd) sin(wd t) )
v(t) = exp(-a t) * ( v0 cos(wd t) - ((a v0 + omega^2 e0) / wd) sin(wd t) )
```

**Overdamped (`zeta > 1`)**, roots `r1,2 = -omega (zeta -+ sqrt(zeta^2 - 1))`:

```
c2 = (v0 - r1 e0) / (r2 - r1),  c1 = e0 - c2
e(t) = c1 exp(r1 t) + c2 exp(r2 t),   v(t) = r1 c1 exp(r1 t) + r2 c2 exp(r2 t)
```

```lua
--!strict
-- Exact damped spring step. Works for numbers and Vector3s (anything with + - * by number).
-- f: frequency (Hz), zeta: damping ratio. The target is treated as constant across the step.
local Spring = {}

function Spring.step<T>(x: T, v: T, target: T, f: number, zeta: number, dt: number): (T, T)
	local X, V, Tg = x :: any, v :: any, target :: any
	local w = 2 * math.pi * f
	local e0 = X - Tg
	if math.abs(zeta - 1) < 1e-4 then
		local k = math.exp(-w * dt)
		local c = V + e0 * w
		return (Tg + (e0 + c * dt) * k) :: any, ((V - c * (w * dt)) * k) :: any
	elseif zeta < 1 then
		local a = zeta * w
		local wd = w * math.sqrt(1 - zeta * zeta)
		local k, cs, sn = math.exp(-a * dt), math.cos(wd * dt), math.sin(wd * dt)
		local e = (e0 * cs + (V + e0 * a) * (sn / wd)) * k
		local nv = (V * cs - (V * a + e0 * (w * w)) * (sn / wd)) * k
		return (Tg + e) :: any, nv :: any
	else
		local s = math.sqrt(zeta * zeta - 1)
		local r1, r2 = -w * (zeta - s), -w * (zeta + s)
		local c2 = (V - e0 * r1) * (1 / (r2 - r1))
		local c1 = e0 - c2
		local k1, k2 = math.exp(r1 * dt), math.exp(r2 * dt)
		return (Tg + c1 * k1 + c2 * k2) :: any, (c1 * (r1 * k1) + c2 * (r2 * k2)) :: any
	end
end

return Spring
```

Exact stepping means 30 fps and 144 fps produce the same curve sampled at different points. The cost is a few `exp`/`sin`/`cos` per spring per frame: trivial for dozens of springs; for thousands of identical springs (foliage), precompute the per-`dt` coefficients once per frame and apply them to all.

### Which to use

| Integrator | Stable at any dt | Same feel at any frame rate | Cost | Use |
|---|---|---|---|---|
| Explicit Euler | no | no | lowest | never |
| Semi-implicit + substeps | yes, with substeps | close | low to medium | many springs with changing targets (the project's enemy joints) |
| Implicit Euler | yes | no (numerical damping) | low | cameras, UI, anything forgiving |
| Exact | yes | yes | medium | gameplay-visible motion, anything players compare |

## First-order smoothing: the `lerp` fix

The most common smoothing line in Roblox code is frame-rate dependent:

```lua
x = x + (target - x) * 0.1   -- per frame: at 30 fps this is half as fast as at 60 fps
```

The frame-rate independent version uses an exponential:

```lua
local alpha = 1 - math.exp(-k * dt)     -- k: rate in 1/s
x = x + (target - x) * alpha
```

This is the exact solution of `x' = k (T - x)` over `dt`. Choose `k` by feel or by **half-life** (time to close half the gap): `k = ln(2) / halfLife`. A half-life of 0.1 s gives `k = 6.93`; after 0.33 s 90% of the gap is closed.

Properties:

- No velocity, so **no overshoot** and no inertia. A smoothed value starts moving instantly at full rate (a visible "snap start" on big target changes); a critically damped spring starts at zero velocity and eases in.
- It **lags** a target moving at speed `u` by `u / k`. For a look-at following a running player at 16 studs/s with `k = 8`, the gaze trails by 2 studs.
- For rotations, use the same `alpha` with `CFrame:Lerp(target, alpha)` (shortest-arc).
- For angles, interpolate the *wrapped difference*: `a += ((b - a + 180) % 360 - 180) * alpha` (degrees). The reference project's leg layers blended every angle channel like this.

The reference project's code used both forms: `x + (t - x) * (1 - exp(-rate * dt))` for gait weights and pelvis offsets, and the exponential `ease(dt, tau) = 1 - exp(-dt / tau)` (time constant `tau = 1/k`) for flight banking (`tau` 0.6 s), turn rate (0.8 s) and speed (1.1 s).

## Rotations

Springs work on vectors; rotations are not vectors. Two practical approaches:

- **Rotation-vector springs (small angles).** Represent each joint's offset as a rotation vector (axis x angle) and spring the vector. Build the rotation with `CFrame.fromAxisAngle(v.Unit, v.Magnitude)`. Accurate while the angles stay under about 60-90 degrees. The project's enemy reaction layer did exactly this: per joint, `x` and `v` are `Vector3` rotation vectors in the body frame, and the joint is written as `B^-1 * rot(x) * B * animated` (the spring rotation expressed in the joint's rest frame, applied over the clip).
- **Error-angle spring (any angle).** Compute the error rotation from current to target, take its axis-angle, spring the angle toward 0 with an angular velocity vector, and rotate the current orientation by `omega * dt`. More code, no small-angle limit.

## Impulses: kicks, jolts and gives

A hit, a catch or a landing is best modelled as a **velocity impulse** into a spring at rest: add to `v`, leave `x` alone, let the spring do the rest. The response of a critically damped spring from rest to an impulse `v0` is

```
x(t) = v0 * t * exp(-omega t)
```

It peaks at `t = 1 / omega` with value `v0 / (omega e)` and decays smoothly. The reference project used this shape directly, without a spring object:

- **Catch "give"** after a tossed blade lands in the hand: `give(tau) = w0 * tau * exp(-tau / Tc)` radians about the toss axis, with `w0` the blade's spin rate and `Tc = 0.11 s`: peaks 0.11 s after the catch, home in about 0.5 s (windowed to zero by 0.6 s). See [[Procedural Weapon Motion]].
- **Hand roll give** at a dead stop of a spin: `give * u * exp(1 - u)` with `u = t / 0.07`, which is the same curve normalised so it peaks at exactly `give` (18 degrees) at 0.07 s.
- **Hit jolts and heavy recoils** on enemies: random or directional kicks added to each joint spring's velocity, scaled by role (head 4-5.5, arm 4-5, spine 2.6-3.2, leg 0.8-2 rad/s), plus a root kick of 55 degrees/s about the push axis for heavy hits. See [[Procedural Death Knockdown and Hit Reactions]].

## Engine springs you get for free

| Where | Parameter | Meaning (official docs) |
|---|---|---|
| `IKControl.SmoothTime` | seconds, default 0.05 | approximate time to reach the target using a critically damped spring; 0 disables |
| `AnimationConstraint.AngularStrength` / `LinearStrength` | default 1 | stiffness as `f / 60`, `f` the target frequency in Hz (1 = 60 Hz); only when `IsKinematic` is false |
| `AnimationConstraint.AngularDamping` / `LinearDamping` | ratio | damping ratio: 1 is critical, 0 none |
| `TweenService` | easing curves | not springs: fixed-duration curves, no velocity carried between tweens |

## Tuning table (rules of thumb, with project values where they exist)

| Use | Frequency | Damping | Notes |
|---|---|---|---|
| Spine / body core reacting | 7 Hz | 0.72 | project enemy layer |
| Head follow-through | 6 Hz | 0.55 | project |
| Arms (upper / mid / tip) | 5.6 / 4.6 / 3.9 Hz | 0.55 / 0.5 / 0.46 | project |
| Tail | 3.4 Hz | 0.42 | project |
| Capes, tentacles | 2.6 Hz | 0.34 | project |
| Root recoil | 6 Hz | 0.5 | project |
| Look-at head | 2-4 Hz | 1.0 | critical: no wobble on a gaze |
| Weapon sway (first person) | 4-8 Hz | 0.6-0.8 | |
| Camera follow | first-order `k` 8-15 | n/a | or a critical spring at 3-6 Hz |

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Smoothing feels faster on high-refresh monitors | `lerp` by a constant per frame | `1 - exp(-k dt)` |
| Spring explodes after a lag spike | explicit or semi-implicit step with a large `dt` | clamp `dt`, substep, or exact update |
| Spring "dies" at 30 fps, lively at 144 | implicit Euler's numerical damping | exact update |
| Smoothed angle spins the long way round | lerping raw angles across +-180 | lerp the wrapped difference |
| Look-at wobbles past the target | underdamped spring on a gaze | `zeta = 1` |
| Recoil never fully returns | spring target drifted (target set to the current pose) | keep the rest target fixed; add impulses to velocity |
| Hit reaction snaps in | impulse added to position | add to velocity |

Related: [[Procedural Animation]], [[Look-At Aim and Head Tracking]], [[Camera Shake and Camera FX]], [[Idle Breathing and Secondary Motion]], [[Snippets - Procedural Motion]].

## Connected notes
<!-- auto-links:start -->
[[Tween vs Spring]] · Interpolation Easing and Curves Math · Math Vectors and CFrames · Cookbook - Math CFrame and Vectors · Rotations Angles and Quaternions · UI Motion Language and Timing · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Springs That Survive Long Frames - dt Clamps and NaN Guards]] · [[Inverse Kinematics]] · [[Two-Bone IK Math]] · [[Flight Flocks and Path Animation]] · [[Motor6D Math and CFrame Composition]] · [[Ragdolls and Physics-Based Animation]] · [[Snippets - Ragdoll]] · [[IKControl Reference]] · [[Snippets - IK]]
<!-- related:end -->
