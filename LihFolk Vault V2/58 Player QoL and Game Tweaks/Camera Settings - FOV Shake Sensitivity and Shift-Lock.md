---
tags: [qol, camera, fov, camera-shake, sensitivity, invert, shift-lock, first-person, settings, type/guide, area/camera, level/intermediate, api/Camera, api/UserGameSettings, api/StarterPlayer]
---
# Camera Settings - FOV Shake Sensitivity and Shift-Lock

<!-- tldr:start -->
> [!tldr] TL;DR
> - FOV resets after sprinting: Sprint writes `FieldOfView` directly -> One FOV owner with named kicks
> - Custom camera feels too fast or slow: Ignores `MouseSensitivity` -> Multiply by the Roblox value
> - Inverted players cannot play: Custom pitch ignores invert -> `GetCameraYInvertValue()`
> - FOV slider 60-100, one owner, kicks scaled by the shake setting.
> - Shake 0-100%, applied at the sum point, starts low under reduced motion.
> - Custom cameras read Roblox sensitivity and invert.
>
> Cost: TL;DR ~160 tok · whole note ~2.1k tok. Read more: ## 1. Who owns which setting · ## 2. FOV slider with one owner · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Camera settings are where players most often feel a game "fighting" them: a narrow FOV on a wide monitor, shake that never stops, a custom camera that ignores the sensitivity they already set in Roblox. This note is the QoL layer: which options to expose, which belong to Roblox, and how to wire your own camera code so the settings actually apply. The comfort reasoning (why FOV and shake cause sickness, flash limits) is in [[Motion Sensitivity and Camera Comfort]]; shake construction is in [[Camera Shake and Camera FX]] and [[Layering Camera Feedback on the Default Camera]].

Sources: **Roblox docs** for `Camera` (https://create.roblox.com/docs/reference/engine/classes/Camera), `UserGameSettings` (https://create.roblox.com/docs/reference/engine/classes/UserGameSettings), `StarterPlayer` (https://create.roblox.com/docs/reference/engine/classes/StarterPlayer) and `Player` (https://create.roblox.com/docs/reference/engine/classes/Player). Ranges are **Rule of thumb**.

## 1. Who owns which setting

| Setting | Owner | What you do |
|---|---|---|
| Mouse / gamepad sensitivity | Roblox menu (`UserGameSettings.MouseSensitivity`, `GamepadCameraSensitivity`) | Respect them in custom cameras; optionally add a game multiplier |
| Invert Y | Roblox menu (`UserGameSettings:GetCameraYInvertValue()`) | Multiply custom pitch input by it |
| Shift lock | Roblox menu, allowed by `StarterPlayer.EnableMouseLockOption` / `Player.DevEnableMouseLock` | Decide whether to allow it; never force it silently |
| Camera mode (Classic, Follow) | Roblox menu | Leave it alone unless your genre needs a fixed camera |
| FOV | You (`Camera.FieldOfView`, 1-120, default 70) | Expose a slider |
| Shake intensity | You | Expose 0-100% |
| First-person lock | You (`Player.CameraMode = Enum.CameraMode.LockFirstPerson`) | Offer as a choice if the genre allows |
| Zoom limits | You (`CameraMinZoomDistance`, `CameraMaxZoomDistance`) | Allow first person by letting min zoom reach 0.5 |

**Gotcha:** adding your own "sensitivity" slider while also respecting Roblox's makes the effective value the product of two numbers. Label yours "Camera speed multiplier (in addition to Roblox settings)" so nobody sets both to max and wonders why.

## 2. FOV slider with one owner

Range 60-100 with default 70 (**Rule of thumb**; Roblox's default is 70 per docs). Many systems want to change FOV (sprint kick, zoom scope, cutscenes). If each writes `FieldOfView` directly, the player's choice is lost the first time a sprint ends. Keep one owner that combines a base, timed contributions and a scope override.

```lua
--!strict
-- StarterPlayerScripts/FovOwner (ModuleScript)
local RunService = game:GetService("RunService")
local ClientSettings = require(script.Parent.ClientSettings)

local kicks: { [string]: number } = {} -- named additive offsets, e.g. sprint = 6
local override: number? = nil -- scopes and cutscenes set an absolute FOV
local M = {}

function M.setKick(name: string, degrees: number?)
	kicks[name] = degrees
end

function M.setOverride(fov: number?)
	override = fov
end

RunService:BindToRenderStep("FovOwner", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = workspace.CurrentCamera
	local target: number
	if override then
		target = override
	else
		local add = 0
		for _, d in kicks do add += d end
		local kickScale = ClientSettings.get("shakeScale") :: number -- kicks are motion too
		target = (ClientSettings.get("fov") :: number) + add * kickScale
	end
	target = math.clamp(target, 1, 120)
	local alpha = 1 - math.exp(-12 * math.min(dt, 0.1))
	camera.FieldOfView += (target - camera.FieldOfView) * alpha
end)

return M
```

Bind after the camera step so the default camera scripts do not overwrite the value in the same frame. Clamp `dt` so a hitch does not snap or overshoot ([[Springs That Survive Long Frames - dt Clamps and NaN Guards]]).

## 3. Shake intensity, not just on/off

A 0-100% slider is better than a toggle: some players want "a bit". Multiply every shake amplitude by the setting at the point where offsets are summed, not inside each effect, so a new effect cannot forget. When `GuiService.ReducedMotionEnabled` is true, start the slider at 0 for new players but let them raise it; the platform setting is a preference, not a lock.

## 4. Custom cameras must honour Roblox settings

If you replace the camera ([[Camera Systems]], [[Custom Character Controllers]]):

```lua
--!strict
local UserInputService = game:GetService("UserInputService")
local ClientSettings = require(script.Parent.ClientSettings)
local ugs = UserSettings():GetService("UserGameSettings")

local yaw, pitch = 0, 0
local function onMouseDelta(delta: Vector2)
	local speed = ugs.MouseSensitivity * (ClientSettings.get("cameraSpeed") or 1)
	local invert = ugs:GetCameraYInvertValue() -- 1 or -1
	yaw -= delta.X * 0.25 * speed
	pitch = math.clamp(pitch - delta.Y * 0.25 * speed * invert, -80, 80)
end

UserInputService.InputChanged:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	onMouseDelta(Vector2.new(input.Delta.X, input.Delta.Y))
end)
```

`cameraSpeed` here is an optional schema key you add. Gamepad input should use `GamepadCameraSensitivity` the same way.

## 5. Shift-lock and first-person options

- **Allow shift lock unless it breaks the game.** Players on PC expect it. If your combat needs character facing to follow the camera, consider a game-owned "lock-on / strafe" option instead of disabling shift lock outright. Shift-lock-plus-sprint conflicts on LeftShift are covered in [[Shift-Lock Sprint and Gamepad B for Menus]].
- **First-person as a choice**: offer "Camera: Third person / First person" that sets `Player.CameraMode` locally. In first person, hide the local character's accessories that block view and widen FOV slightly.
- **Zoom**: if you clamp `CameraMaxZoomDistance` low for level design reasons, say so in the settings tooltip. Players assume a broken camera otherwise.
- **Console**: right-stick sensitivity is the most-requested console option; respect `GamepadCameraSensitivity` and add deadzone tolerance ([[Controller Support QoL]]).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| FOV resets after sprinting | Sprint writes `FieldOfView` directly | One FOV owner with named kicks |
| Custom camera feels too fast or slow | Ignores `MouseSensitivity` | Multiply by the Roblox value |
| Inverted players cannot play | Custom pitch ignores invert | `GetCameraYInvertValue()` |
| Shake still on at 0% | Shake scaled per effect, one missed | Scale at the sum point |
| Shift lock silently disabled | `EnableMouseLockOption` off with no explanation | Allow it, or explain and offer an alternative |
| FOV jitters | Written before the camera step | Bind after `RenderPriority.Camera` |

## Checklist

- [ ] FOV slider 60-100, one owner, kicks scaled by the shake setting.
- [ ] Shake 0-100%, applied at the sum point, starts low under reduced motion.
- [ ] Custom cameras read Roblox sensitivity and invert.
- [ ] Shift lock allowed or replaced with an explained alternative.
- [ ] First-person choice where the genre allows.
- [ ] Zoom limits explained when restricted.

## See also

- [[Motion Sensitivity and Camera Comfort]]
- [[Camera Shake and Camera FX]]
- [[Cameras and Cutscenes]]
- [[Settings Menu Essentials and Persistence]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] · [[Layering Camera Feedback on the Default Camera]] · Camera Systems
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Accessibility Cross-Links for QoL Settings]] · [[Chase Cameras and Speed Effects for Vehicles]] · [[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[Graphics and Performance Toggles for Low-End Devices]] · [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]] · [[UI Scale HUD Hide and Compact Mode]] · [[Rebinding Controls with the Input Action System]] · [[Aim Assist and Generous Hitboxes]]
<!-- related:end -->
