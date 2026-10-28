---
tags: [gameplay, camera, cutscene, aiming, renderstep]
---
# Camera Systems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Shake written into `CFrame` without removal -> Apply at Camera+1, remove at Camera-1
> - Avoid: Several systems tween FOV -> One FOV owner summing effects
> - Avoid: Server tries to set the camera -> Remote to the client
> - Camera code only on the client; bound at the right RenderStep priority.
> - Additive effects never drift and end at zero.
> - Cutscenes save and restore type, subject, FOV and GUI, with a watchdog.
>
> Read more (14 KB note): ## 2. The frame: where camera code must run · ## 5. Cinematic takeovers · ## 8. Common mistakes · ## Checklist
<!-- tldr:end -->

The camera is the player's eyes and the system most likely to make a game feel cheap or nauseating. Roblox gives you a capable default (the `CameraModule` inside `PlayerModule`) and a raw `Camera` object you can take over completely. This note explains how the camera is updated each frame, the API that matters, how to layer effects on the default camera without breaking it, how to build custom cameras (over-the-shoulder, top-down, lock-on) and cinematic takeovers, and the comfort rules.

Shake and cinematic craft in depth: [[Camera Shake and Camera FX]], [[Cameras and Cutscenes]], [[Cinematic Ultimates]]. Frame order: [[Frame Order and RunService Timing]].

Source labels: **Docs** (checked October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. Basics

- Each client has its own camera: `workspace.CurrentCamera` (Docs). The server has no view of it. **Any camera behaviour is client code**; the server can only ask (a RemoteEvent, an attribute) and the client decides.
- `Camera.CFrame` is where the camera is; `Camera.Focus` tells the engine where to prioritise detail such as lighting, and does not move the camera (Docs). If you run a custom camera without the default scripts, update `Focus` every frame too.
- `FieldOfView` is the vertical FOV in degrees, clamped 1 to 120, default 70 (Docs). `FieldOfViewMode` can hold the diagonal or max-axis FOV constant instead.
- `ViewportSize` is in UI offset units for the safe area, not native pixels (Docs).
- `CameraSubject` defaults to the local Humanoid and cannot be set to nil (it reverts) (Docs). Setting it to a BasePart makes the default camera follow the part.

### CameraType
| Type | Behaviour |
|---|---|
| `Custom` | Default: the CameraModule follows `CameraSubject` with player-controlled orbit and zoom |
| `Scriptable` | Default scripts stop updating the camera; you own `CFrame` (Docs) |
| `Follow`, `Track`, `Watch`, `Attach`, `Fixed`, `Orbital` | Older built-in modes; rarely used in modern games |

### Player-level settings (on `StarterPlayer`, copied to `Player`)
| Setting | Use |
|---|---|
| `CameraMaxZoomDistance`, `CameraMinZoomDistance` | Zoom range. Equal values lock zoom |
| `CameraMode` | `Classic` or `LockFirstPerson` |
| `DevCameraOcclusionMode` | `Zoom` (move in front of walls) or `Invisicam` (fade walls) |
| `DevComputerCameraMovementMode`, `DevTouchCameraMovementMode` | Classic, Follow, Orbital and others |
| `EnableMouseLockOption` | Shift-lock toggle |

**Measured.** The reference project disabled `EnableMouseLockOption` because Shift was its sprint key and shift-lock toggled at the same time. Check every built-in binding against your own.

---

## 2. The frame: where camera code must run

On the client each frame, roughly: input, then `RenderStepped`/`BindToRenderStep` callbacks in priority order (the camera module binds at `Enum.RenderPriority.Camera`), then physics, then rendering. The rule:

| Your code | Bind at |
|---|---|
| Reads input that the camera uses | Before `Camera` (`Input` priority) |
| Replaces the camera | `Camera` priority, with `Scriptable` type |
| Adds an offset on top of the default camera (shake, kick, lean) | `Camera + 1` |
| Removes that offset before the default camera runs again | `Camera - 1` |
| Places things in front of the camera (viewmodels, aim reticle in world) | After `Camera` (`Character` priority or later) |

The apply-then-remove pair is the important pattern. The default CameraModule computes the next frame's camera from the *current* `Camera.CFrame` in some modes. If you leave a shake offset in `CFrame`, it accumulates and the camera drifts. **Measured.** The reference project's camera FX layer applies its offset (camera-space translation plus roll, never touching the look direction) at `Camera + 1` and takes it off at `Camera - 1`; its test harness checked "0 view drift" and that FOV returns exactly to base.

```lua
--!strict
-- Additive camera offset that never drifts.
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera

local CamOffset = {}
local applied = CFrame.identity
local current = CFrame.identity -- set by your shake/kick code each frame

function CamOffset.set(offset: CFrame)
	current = offset
end

RunService:BindToRenderStep("CamOffsetRemove", Enum.RenderPriority.Camera.Value - 1, function()
	camera.CFrame = camera.CFrame * applied:Inverse()
	applied = CFrame.identity
end)

RunService:BindToRenderStep("CamOffsetApply", Enum.RenderPriority.Camera.Value + 1, function()
	if camera.CameraType ~= Enum.CameraType.Custom then
		return -- cutscenes own the camera
	end
	applied = current
	camera.CFrame = camera.CFrame * applied
end)

return CamOffset
```

FOV effects are simpler: keep a base FOV and write `base + sum(effects)` every frame from one owner. Two systems tweening FOV independently will fight and leave the FOV wrong when one finishes.

---

## 3. Converting between world and screen

| Method | Use | Inset |
|---|---|---|
| `WorldToScreenPoint(pos)` | Place GUI over a world point | Accounts for the GUI inset (Docs) |
| `WorldToViewportPoint(pos)` | Viewport maths, ViewportFrames | Does not account for the inset |
| `ScreenPointToRay(x, y, depth?)` | Mouse or touch aim | Accounts for the inset; returns a 1-stud unit ray (Docs) |
| `ViewportPointToRay(x, y, depth?)` | Centre-of-screen aim | No inset |

Both return a `Vector3` whose Z is depth and a boolean "on screen". Z below zero means behind the camera; off-screen indicators must flip the direction in that case.

Aiming from the screen centre (third-person shooter, ability targeting):

```lua
--!strict
local camera = workspace.CurrentCamera

local function aimPoint(maxDist: number, params: RaycastParams): Vector3
	local size = camera.ViewportSize
	local ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * maxDist, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * maxDist
end
```

Then fire from the character's weapon toward that point, not from the camera. The client sends the aim point; the server re-validates line of sight from the character (the camera can see over walls the character cannot). See [[Raycasts Shapecasts and Spatial Queries]].

`GetPartsObscuringTarget(castPoints, ignoreList)` returns parts blocking the view of points with no hit details; use `Raycast` when you need positions or normals (Docs).

---

## 4. Custom cameras

### Over-the-shoulder
Keep the default camera's orbit and zoom and add a horizontal offset: set `Humanoid.CameraOffset` (a local-space offset the default camera applies) or use the offset layer above. `CameraOffset` is simplest, but it also shifts the occlusion test, so the camera can clip into walls on the offset side. A full custom shoulder camera does its own collision: cast a sphere from the pivot toward the desired camera position and stop at the hit minus a margin.

```lua
--!strict
-- Scriptable shoulder camera core (call at Camera priority).
local camera = workspace.CurrentCamera

local function shoulderCFrame(root: BasePart, yaw: number, pitch: number, params: RaycastParams): CFrame
	local pivot = root.Position + Vector3.new(0, 2.5, 0)
	local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local desired = pivot + rot:VectorToWorldSpace(Vector3.new(2, 0.5, 9))
	local dir = desired - pivot
	local hit = workspace:Spherecast(pivot, 0.5, dir, params)
	local pos = if hit then pivot + dir.Unit * math.max(hit.Distance - 0.2, 0.5) else desired
	return CFrame.lookAt(pos, pos + rot.LookVector)
end
```

`Spherecast` does not report parts it starts inside (Docs), so keep the pivot inside the character's own capsule (excluded) rather than near walls.

### Top-down and isometric
`Scriptable`, a fixed angle, follow the root with smoothing. Smooth with an exponential approach that is frame-rate independent: `pos = pos:Lerp(target, 1 - math.exp(-k * dt))`. A fixed `Lerp(target, 0.1)` per frame is twice as stiff at 120 FPS as at 60. See [[Springs Damping and Smoothing]].

### Lock-on
Lock-on rotates the character and camera toward a target. Rules of thumb:
- Keep both the player and the target in view: aim at a point between them weighted toward the target, and pull the camera back when they are far apart.
- Break the lock when the target dies, leaves a range, or is occluded for more than about a second.
- Never let lock-on rotate the camera faster than about 360 degrees per second; snapping is disorienting.
- On gamepad, lock-on or aim assist matters more than on mouse ([[Gamepad and Console UX]]).

---

## 5. Cinematic takeovers

The pattern: save state, switch to `Scriptable`, animate, restore.

```lua
--!strict
local TweenService = game:GetService("TweenService")
local camera = workspace.CurrentCamera

local function playShot(from: CFrame, to: CFrame, duration: number)
	local prevType = camera.CameraType
	local prevSubject = camera.CameraSubject
	local prevFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = from

	local tween = TweenService:Create(camera, TweenInfo.new(duration, Enum.EasingStyle.Sine), { CFrame = to })
	tween:Play()
	tween.Completed:Wait()

	camera.CameraType = prevType
	camera.CameraSubject = prevSubject
	camera.FieldOfView = prevFov
end
```

`Camera:Interpolate` is deprecated; use TweenService (Docs).

**Measured.** The reference project's ultimate cutscenes run a caster-only multi-shot sequence (hero, establishing, action shots such as tracking, shoulder, crane, low orbit, top-down, a climax with slow motion, aftermath, then a 0.55 s blend back to the gameplay camera). During it: all ScreenGuis, CoreGui, cursor, prompts, nameplates and enemy health bars hide; a `CutsceneLock` attribute tells every other controller to step aside; a watchdog restores everything if the sequence errors. Lessons:
- **Always have a watchdog.** A cutscene that errors mid-way and leaves the camera Scriptable soft-locks the player. Use `pcall` or `task.delay` a forced restore at the cutscene's maximum length.
- **Blend back, do not cut back**, unless the cut is the point. A short blend from the last shot to where the default camera would be avoids a jarring jump.
- **Lock gameplay during the shot** with an attribute that combat, movement and UI all respect.
- **Letterbox bars must ignore safe-area scaling.** The reference project's bars were inset and scaled until `ScreenInsets`, `SafeAreaCompatibility` and `ClipToDeviceSafeArea` were set to none/off on that ScreenGui and the UI scaler skipped it ([[Safe Areas and Insets]]).

**Studio gotcha (measured).** Tools that capture the viewport with a custom camera position can leave the Edit camera `Scriptable`; set it back to `Custom` afterwards or Studio's navigation stops working. During a play test, Studio's tooling can also reset camera changes made by command-bar code.

---

## 6. Camera feel and comfort

| Effect | Typical | Comfort guard |
|---|---|---|
| Hit shake | 0.1 to 0.3 s, small amplitude, decays to exactly 0 | Off or halved with reduced motion |
| Dash FOV kick | +6 to +10 degrees, fast in, slower out | Cap total FOV change (12 degrees in the reference project) |
| Landing dip | Scaled by fall height | Skip for small falls |
| Roll | 2 to 4 degrees max | Roll is the most nauseating axis; keep tiny |
| Slow motion zoom | Only in cutscenes | Never during free control |

Give players a "Camera Effects" toggle and honour a reduced-motion preference ([[Accessibility]]). Camera FX should also stop during cutscenes, when dead or downed, and when the camera is not following the local player.

---

## 7. Touch, gamepad and scale

- **Touch.** The default camera rotates with a drag anywhere not covered by UI. Large touch buttons and joysticks eat that area; leave a clear region for camera drags and test one-thumb play.
- **Gamepad.** The right stick rotates; add light auto-rotation behind the character when moving and no manual input, and consider lock-on or aim assist for combat.
- **Character scale.** Bigger characters need the camera further out and higher. The reference project scaled characters 1.6x and had to adjust camera offsets, zoom limits and occlusion margins to match.
- **Zoom limits.** Very far max zoom reveals map edges and unloaded streaming areas; very close min zoom puts the camera inside large weapons. Set both deliberately per game.

## 8. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Shake written into `CFrame` without removal | Camera drifts or spins | Apply at Camera+1, remove at Camera-1 |
| Several systems tween FOV | FOV stuck wrong | One FOV owner summing effects |
| Server tries to set the camera | Nothing happens | Remote to the client |
| Cutscene without restore | Player stuck in Scriptable | Watchdog |
| Per-frame `Lerp(x, 0.1)` | Feel changes with FPS | Exponential with `dt` |
| `WorldToViewportPoint` for GUI | Labels offset by the top bar | `WorldToScreenPoint` |
| Aim validated from the camera on the server | Shots through walls | Re-check from the character |

## Checklist
- [ ] Camera code only on the client; bound at the right RenderStep priority.
- [ ] Additive effects never drift and end at zero.
- [ ] Cutscenes save and restore type, subject, FOV and GUI, with a watchdog.
- [ ] Settings toggle and reduced motion respected.
- [ ] Aiming re-validated on the server from the character.

## See also
[[Camera Shake and Camera FX]] · [[Cameras and Cutscenes]] · [[Cinematic Ultimates]] · [[Frame Order and RunService Timing]] · [[Custom Character Controllers]] · [[Game Feel and Juice]] · [[Accessibility]] · [[Snippets - Camera Shake and FX]]

## Connected notes
<!-- auto-links:start -->
[[Links - Cameras]] · [[Motion Sensitivity and Camera Comfort]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]] · [[Game Feel Start Here]] · [[Modelling to the Roblox Camera and Player Scale]] · [[Safe Area]]
<!-- auto-links:end -->
