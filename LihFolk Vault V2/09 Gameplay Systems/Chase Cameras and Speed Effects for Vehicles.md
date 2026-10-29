---
tags: [gameplay, camera, vehicles, chase-camera, fov, speed-lines, springs, comfort, type/guide, area/gameplay, level/advanced, api/Camera, api/RunService]
---
# Chase Cameras and Speed Effects for Vehicles

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Following full chassis rotation -> Follow yaw only
> - Avoid: Per-frame `Lerp(x, 0.1)` -> `1 - exp(-dt * k)` smoothing
> - Avoid: Several scripts tween FOV -> One FOV owner sums layers
> - Chase camera binds on seat, unbinds on every exit path.
> - Yaw-only follow with dt-correct smoothing; drift blend toward velocity.
> - One normalised speed value drives FOV, distance, shake, lines and wind.
>
> Cost: TL;DR ~140 tok · whole note ~2.5k tok. Read more: ## 2. The rig: target, look-ahead, damping · ## 3. Selling speed · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The default camera follows the `CameraSubject`; when a player sits in a `VehicleSeat` the default camera module already switches to a vehicle mode that follows the seat. That is fine for a prototype and wrong for a driving game: it lags in corners, it has no sense of speed, and it fights any shake you add. This note covers a custom chase camera that owns the camera only while driving, a speed model for FOV, shake and speed lines, and the comfort limits that keep it playable on phones. Generic camera ownership, RenderStep priorities and cutscene takeovers are in [[Camera Systems]]; this note is only the driving-specific angle.

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**.

---

## 1. Ownership: when the chase camera runs

- Run only on the client, only for the local driver. Passengers can keep the default camera or use the same rig with a looser spring.
- Enter on `Humanoid.Seated` (the seat is a `VehicleSeat` you recognise by tag), exit on unseat, on character removal and on vehicle destruction. A watchdog that restores `CameraType = Custom` when the subject disappears saves you from a black-screen bug.
- Set `Camera.CameraType = Enum.CameraType.Scriptable` while active and write `Camera.CFrame` and `Camera.FieldOfView` every frame from `RunService:BindToRenderStep` at `Enum.RenderPriority.Camera.Value + 1` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/enums/RenderPriority). Unbind on exit.
- Read the car from its client-side physics (the driver owns the assembly, so the local simulation is the freshest state). Never ask the server for camera data.

## 2. The rig: target, look-ahead, damping

A good chase camera is three springs, not one:

| Component | What it follows | Damping |
|---|---|---|
| Position | A point behind and above the chassis, in the chassis' *yaw* frame only | Stiff (half-life 0.08 to 0.15 s) |
| Yaw | The chassis' heading, blended toward the velocity direction when sliding | Medium (0.15 to 0.3 s) |
| Look target | A point ahead of the car, pushed further ahead with speed | Medium |

**Rule of thumb.** Follow yaw only; ignore chassis pitch and roll, or every bump tilts the horizon. Blend heading toward the velocity direction above a slip angle, so drifts show the car sideways instead of swinging the camera wide.

Use frame-rate independent smoothing: `alpha = 1 - math.exp(-dt * ln2 / halfLife)`. A fixed `Lerp(x, 0.1)` per frame is twice as stiff at 120 FPS as at 60 ([[Springs That Survive Long Frames - dt Clamps and NaN Guards]], [[Springs Damping and Smoothing]]).

```lua
--!strict
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local camera = Workspace.CurrentCamera
local BIND = "ChaseCamera"

local BASE_FOV, MAX_FOV = 70, 88
local FOV_SPEED_START, FOV_SPEED_FULL = 40, 160 -- studs/s
local BACK, UP, LOOK_AHEAD = 14, 4.5, 8

local function damp(halfLife: number, dt: number): number
	return 1 - math.exp(-math.min(dt, 0.1) * 0.693 / halfLife)
end

local function start(chassis: BasePart)
	local pos = camera.CFrame.Position
	local yawLook = chassis.CFrame.LookVector * Vector3.new(1, 0, 1)
	local fov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable

	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if not chassis:IsDescendantOf(Workspace) then return end
		local vel = chassis.AssemblyLinearVelocity
		local flatVel = vel * Vector3.new(1, 0, 1)
		local speed = flatVel.Magnitude

		local heading = chassis.CFrame.LookVector * Vector3.new(1, 0, 1)
		if speed > 8 then
			heading = heading:Lerp(flatVel.Unit, 0.35) -- show drifts
		end
		if heading.Magnitude > 1e-3 then
			yawLook = yawLook:Lerp(heading.Unit, damp(0.2, dt))
		end
		local flat = if yawLook.Magnitude > 1e-3 then yawLook.Unit else Vector3.zAxis

		local desired = chassis.Position - flat * BACK + Vector3.yAxis * UP
		pos = pos:Lerp(desired, damp(0.1, dt))
		local target = chassis.Position + flat * (LOOK_AHEAD + speed * 0.05)

		local t = math.clamp((speed - FOV_SPEED_START) / (FOV_SPEED_FULL - FOV_SPEED_START), 0, 1)
		local maxFov = if GuiService.ReducedMotionEnabled then BASE_FOV + 6 else MAX_FOV
		fov += (BASE_FOV + (maxFov - BASE_FOV) * t * t - fov) * damp(0.3, dt)

		camera.CFrame = CFrame.lookAt(pos, target)
		camera.FieldOfView = fov
	end)
end

local function stop()
	RunService:UnbindFromRenderStep(BIND)
	camera.CameraType = Enum.CameraType.Custom
end
```

Add obstruction handling (a spherecast from the car's roof to `desired`) before shipping; see [[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]].

## 3. Selling speed

Speed is perceived from optic flow, not from the number on the HUD. Stack cheap cues, each tied to one normalised speed value `s` in 0..1:

| Cue | Mapping | Notes |
|---|---|---|
| FOV | Base 70 to about 85-90 at top speed, eased (`s*s`) | **Rule of thumb.** Above roughly +20 degrees reads as fish-eye on wide screens |
| Camera distance | Pull back 1 to 3 studs with `s` | Combined with FOV it reads as acceleration |
| Shake | Low-amplitude noise, amplitude grows with `s`, frequency 8 to 15 Hz | Add on top, remove before the next frame ([[Camera Shake and Camera FX]]) |
| Speed lines | Screen-space streaks or a particle tube around the camera, rate grows above `s = 0.6` | Hide below the threshold so they mean something |
| Motion blur | No dedicated per-object motion blur post-effect in Roblox (**Unverified** for future releases); fake with streaks | |
| Audio | Wind layer volume and engine pitch | [[Engine and Tyre Audio Driven by RPM and Slip]] |

Boost and nitro: kick FOV by a fixed amount on activation with a fast attack (0.1 s) and slow release (0.6 s). One FOV owner sums base + speed + boost; never let two systems tween `FieldOfView` ([[Camera Systems]]).

### Speed lines that do not tank phones
- Screen-space version: a `ScreenGui` with 10 to 20 thin `Frame`s or `ImageLabel`s radiating from centre, transparency driven by `s`. No particles, no physics, predictable cost.
- World version: a `ParticleEmitter` on an attachment in a non-colliding, anchored part you move to the camera each frame, emitting backwards. Cap `Rate` and `Lifetime`; particles are billed per emitter and per particle ([[VFX Performance Budgets and Culling]]).

## 4. Collisions, landings and resets

- **Impacts.** On a large drop in speed between frames (a crash), add a short shake impulse scaled by the speed lost, and freeze look-ahead for 0.2 s so the camera does not whip.
- **Airborne.** Raise position damping half-life while airborne so jumps feel floaty, then snap back on landing.
- **Respawn and flips.** When the car is reset or teleported, snap the camera (`pos = desired`) instead of smoothing across the map.
- **Reverse.** Above a small reverse speed, either keep the camera behind (most arcade games) or offer a look-back button; never auto-flip the camera, it disorients.

## 5. Comfort and devices

- Honour `GuiService.ReducedMotionEnabled` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/GuiService): cap FOV change, drop shake and speed lines ([[Motion Sensitivity and Camera Comfort]]).
- Offer a camera distance setting and a "fixed FOV" toggle.
- On touch, leave a free-look gesture (drag on the right half) that decays back to centre after release; on gamepad, the right stick.
- In first-person or hood cam, keep FOV changes under half of the chase-cam range.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Following full chassis rotation | Horizon tilts on every bump | Follow yaw only |
| Per-frame `Lerp(x, 0.1)` | Feel changes with frame rate | `1 - exp(-dt * k)` smoothing |
| Several scripts tween FOV | Boost and speed FOV fight | One FOV owner sums layers |
| Smoothing across a teleport | Camera flies across the map | Snap on reset |
| Linear FOV with speed | Constant fish-eye on highways | Ease in, cap the range |
| Camera not restored on exit | Stuck Scriptable camera | Watchdog restores `Custom` |

## Checklist
- [ ] Chase camera binds on seat, unbinds on every exit path.
- [ ] Yaw-only follow with dt-correct smoothing; drift blend toward velocity.
- [ ] One normalised speed value drives FOV, distance, shake, lines and wind.
- [ ] Obstruction handled with a spherecast.
- [ ] Reduced-motion path tested; distance and FOV settings exposed.
- [ ] Tested at 30 and 120 FPS and on a low-end phone.

## See also
[[Camera Systems]] · [[Camera Shake and Camera FX]] · [[Genre Playbook - Racing and Driving]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Motion Sensitivity and Camera Comfort]] · [[Springs Damping and Smoothing]] · [[Hit-Stop and Screen Shake Tuning by Numbers]]

## Connected notes
<!-- auto-links:start -->
[[Layering Camera Feedback on the Default Camera]] · Engine and Tyre Audio Driven by RPM and Slip · [[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]] · Juice on a Budget - Mobile and Low-End
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Custom Character Controllers]] · [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] · [[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Grabs, Carries and Throws - Moving Players Safely]] · [[Police Chases and Wanted Levels]]
<!-- related:end -->
