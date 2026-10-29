---
tags: [field-notes, camera, bindtorenderstep, fov, game-feel, playermodule, luau, type/guide, area/scripting, level/intermediate, api/FieldOfView, api/BindToRenderStep]
---
# Layering Camera Feedback on the Default Camera

<!-- tldr:start -->
> [!tldr] TL;DR
> - Effect never visible: Step bound before or at `Camera` priority -> Bind at `Camera.Value + 1`
> - View zooms out forever: `FieldOfView +=` every frame -> Track and replace your contribution
> - Sprint FOV snaps wrongly after a punch: Subtracting a contribution another script already overwrote -> Compare with the value you last wrote
> - Feedback step bound at `Enum.RenderPriority.Camera.Value + 1`.
> - FOV contribution tracked and replaced, never accumulated.
> - Other scripts' FOV writes detected by comparing with the last written value.
>
> Cost: TL;DR ~180 tok · whole note ~2.0k tok. Read more: ## 1. Run after the camera, every frame · ## 2. FOV is absolute, so additive punches accumulate · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roll on a dash, an FOV punch on a heavy hit, a tilt into a turn: most action games want these on top of Roblox's default follow camera, not a replacement for it. Layering them is easy to get almost right and hard to get exactly right, because you share the camera with a script that runs every frame and does not know you exist. This note gives the ordering, the bookkeeping that stops values drifting, and when to stand down. Trauma shake and kicks are in [[Camera Shake and Camera FX]]; tuning numbers in [[Hit-Stop and Screen Shake Tuning by Numbers]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Run after the camera, every frame

The default camera (the `CameraModule` inside the `PlayerModule`) updates in a render step bound at `Enum.RenderPriority.Camera` (Roblox docs). If your effect runs before it, the camera overwrites your change and nothing shows. If it runs in `RenderStepped` or `PreRender`, the order against the camera is not something you control. Bind your own step one priority later:

```lua
RunService:BindToRenderStep("CameraFeedback", Enum.RenderPriority.Camera.Value + 1, step)
```

`BindToRenderStep` takes a name, an integer priority and a function receiving `dt` (Roblox docs). Lower priorities run first, so `Camera.Value + 1` runs immediately after the default camera has written its CFrame for the frame. Unbind with `RunService:UnbindFromRenderStep("CameraFeedback")` when the effect system shuts down.

## 2. FOV is absolute, so additive punches accumulate

The default camera writes `Camera.CFrame` every frame but does not rewrite `FieldOfView` every frame. So `camera.FieldOfView += punch` in a per-frame step adds the punch again each frame and the view zooms out without limit. At 60 fps even a small punch reaches the 120 degree ceiling within a fraction of a second.

Track what you added and replace it, never stack on it. A second nuance: other scripts (sprint, aim, cutscenes) also set FOV as an absolute value. If one of them wrote the property since your last frame, the current value no longer contains your contribution, and subtracting it would undershoot. Remember what you wrote and compare:

```lua
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Spring = require(script.Parent.Spring) -- see the long-frames note

local player = Players.LocalPlayer
local fovSpring = Spring.new(0, 4, 0.8)   -- degrees of punch, rests at 0
local rollSpring = Spring.new(0, 3, 0.6)  -- degrees of roll, rests at 0

local fovAdded = 0          -- our contribution inside the current FieldOfView
local fovWritten = nil      -- the exact value we last wrote

local function shouldApply(camera: Camera): boolean
	return camera.CameraType == Enum.CameraType.Custom
		and not player:GetAttribute("InCutscene")
end

local function removeFov(camera: Camera)
	if fovAdded ~= 0 and camera.FieldOfView == fovWritten then
		camera.FieldOfView -= fovAdded
	end
	fovAdded, fovWritten = 0, nil
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local punch = fovSpring:step(dt)
	local roll = rollSpring:step(dt)

	if not shouldApply(camera) then
		removeFov(camera)
		return
	end

	-- Base FOV without us: if someone else wrote FOV since our last write, their value is the base.
	local base = if camera.FieldOfView == fovWritten then camera.FieldOfView - fovAdded else camera.FieldOfView
	local target = math.clamp(base + punch, 1, 120)
	camera.FieldOfView = target
	fovWritten = camera.FieldOfView -- read back: the property stores less precision than a Luau number
	fovAdded = fovWritten - base

	if math.abs(roll) > 1e-3 then
		camera.CFrame *= CFrame.Angles(0, 0, math.rad(roll))
	end
end

RunService:BindToRenderStep("CameraFeedback", Enum.RenderPriority.Camera.Value + 1, step)

-- Usage: fovSpring:impulse(60) on a heavy hit; rollSpring:setTarget(8) while dashing left.
```

`FieldOfView` is clamped by the engine to 1 to 120 degrees (Roblox docs); clamp yourself so your bookkeeping matches what was stored. Read the property back after writing it: `FieldOfView` is a single-precision float, so the value you get back is rarely bit-identical to the double you wrote, and an equality check against your own number would always fail (rule of thumb; it applies to most float properties).

## 3. Roll is safe; pitch and yaw offsets feed back

Roll about the camera's own look axis leaves `LookVector` unchanged. Pitch or yaw offsets do not, and the default camera can derive part of the next frame from the camera's current orientation, so an un-undone pitch kick risks drifting the view a little every frame (rule of thumb; the `CameraModule` source changes between releases, so test rather than rely on its internals). If you add pitch or yaw, undo last frame's offset in a step bound just *before* the camera (`Camera.Value - 1`) so the camera module sees a clean CFrame, then re-apply after. Roll needs no undo.

## 4. When to stand down

Skip the whole effect, and remove the FOV you added, when:

- `Camera.CameraType` is not `Custom`. `Scriptable` means a cutscene or a custom camera owns the view; writing over it fights that code.
- A cutscene flag is set (an attribute such as `InCutscene` on the player, set by whatever runs cutscenes). Some cutscenes keep `Custom` and only move the subject.
- `Workspace.CurrentCamera` changed. Cache nothing; read it each frame.
- Reduced motion is on: keep a small FOV punch, drop roll entirely ([[Motion Sensitivity and Camera Comfort]]).

Let the springs keep stepping while standing down, so that when control returns the effect is at rest rather than replaying a stale punch.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Effect never visible | Step bound before or at `Camera` priority | Bind at `Camera.Value + 1` |
| View zooms out forever | `FieldOfView +=` every frame | Track and replace your contribution |
| Sprint FOV snaps wrongly after a punch | Subtracting a contribution another script already overwrote | Compare with the value you last wrote |
| View slowly tilts up during combat | Pitch kick not undone before the camera step | Undo at `Camera.Value - 1`, re-apply after |
| Cutscene camera wobbles | Feedback applied to a `Scriptable` camera | Stand down unless `CameraType == Custom` |
| Black screen after a hitch | Unstable spring wrote `NaN` | [[Springs That Survive Long Frames - dt Clamps and NaN Guards]] |

## Checklist

- [ ] Feedback step bound at `Enum.RenderPriority.Camera.Value + 1`.
- [ ] FOV contribution tracked and replaced, never accumulated.
- [ ] Other scripts' FOV writes detected by comparing with the last written value.
- [ ] Only roll applied after the camera; pitch and yaw undone before it.
- [ ] Stands down for non-`Custom` cameras and cutscenes, removing its FOV.
- [ ] Reduced-motion setting respected.

## Connected notes
<!-- auto-links:start -->
[[Camera Shake and Camera FX]] · Camera Systems · Hit-Stop and Screen Shake Tuning by Numbers · Motion Sensitivity and Camera Comfort · [[Springs That Survive Long Frames - dt Clamps and NaN Guards]] · [[Field Notes Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Snippets - Camera Shake and FX]] · [[Chase Cameras and Speed Effects for Vehicles]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Shift-Lock Sprint and Gamepad B for Menus]] · [[Held Weapons on Motor6D - Locking the Grip During Attacks]] · [[Resetting One Player's Data Safely]]
<!-- related:end -->
