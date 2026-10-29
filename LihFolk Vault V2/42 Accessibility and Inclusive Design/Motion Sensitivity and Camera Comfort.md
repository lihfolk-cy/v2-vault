---
tags: [accessibility, motion-sickness, reduced-motion, camera, fov, flashing, photosensitivity, comfort, type/guide, area/accessibility, level/intermediate, api/Camera]
---
# Motion Sensitivity and Camera Comfort

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Camera roll on hits, landings or dizziness effects.
> - Avoid: Head bob on by default with no off switch.
> - Avoid: Several systems tweening FOV independently.
> - One comfort module combines `ReducedMotionEnabled` with saved player overrides and fires a change signal.
> - FOV slider (about 60 to 100), one FOV owner, effect contributions scaled and clamped.
> - Camera shake scalable to zero; no gameplay roll.
>
> Cost: TL;DR ~150 tok · whole note ~5.5k tok. Read more: ## 3. A comfort settings module · ## 5. Camera motion budget · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Accessibility]] covers `GuiService.ReducedMotionEnabled` for UI tweens. [[Camera Shake and Camera FX]] covers how shake is built and how the reference project scaled it under reduced motion. [[Camera Systems]] covers the camera itself. This note is about the player's body: why some players get sick or get headaches in Roblox games, which camera and effect choices cause it, a comfort settings module that ties the platform preference to game-specific controls, a horizon-locked vehicle camera, a speed vignette, and a flash limiter that keeps [[impact frames]] and rarity reveals under the photosensitivity guideline.

Sources: **Roblox docs (as of October 2026)** for engine facts (`Camera`, `GuiService`, `UserGameSettings`), the public **WCAG 2.x** guideline for flash thresholds, and **rule of thumb** for comfort numbers (the research on simulator sickness is broad; the numbers here are design defaults, not medical limits).

---

## 1. Why players get sick

Simulator sickness comes mostly from a mismatch between what the eyes report (I am moving, turning, accelerating) and what the inner ear reports (I am sitting still). The mismatch is worst when:

- **The camera moves without the player causing it.** Shake, head bob, forced turns, cutscene swoops, being knocked back. Movement the player drives with their own input is tolerated far better.
- **The camera rotates, especially around the view axis.** Roll (tilting the horizon) is the strongest trigger; yaw and pitch the player did not ask for come next; translation is the mildest.
- **The field of view is narrow on a large, close screen.** A narrow FOV makes every turn sweep the image faster across the retina, and the mismatch between the screen's real angle and the rendered angle grows.
- **Acceleration changes abruptly.** Constant velocity is comfortable; sudden starts, stops and FOV kicks are not.
- **The frame rate is low or uneven.** Judder makes motion harder to integrate.
- **Large parts of the view move at once.** Full-screen [[parallax]], spinning backgrounds, screen-wide wobble.

Separately, **photosensitive** players can have seizures triggered by flashing, especially large-area flashes and saturated red flashes. This is a safety issue, not comfort, and it has a published threshold (section 6).

And separately again, some players (vestibular disorders, migraine, concussion recovery) find any persistent motion uncomfortable, including UI idle animations. That is the group `ReducedMotionEnabled` mostly serves.

The design goal is not to remove motion from the game. It is to keep motion **player-driven, predictable and optional where it is decoration**.

---

## 2. What Roblox gives you, and what it does not

| Need | Engine support (Roblox docs, as of October 2026) | Your job |
|---|---|---|
| Player wants less motion | `GuiService.ReducedMotionEnabled` (read-only, changes at runtime) | Read it and apply it to UI, camera FX and VFX |
| Field of view | `Camera.FieldOfView`, clamped 1 to 120, default 70; `FieldOfViewMode` chooses which axis is held constant | Expose a range; keep one owner for FOV |
| Camera sensitivity | `UserGameSettings.MouseSensitivity` and `GamepadCameraSensitivity` are Roblox's own settings | Do not override them; respect them in custom cameras |
| Invert Y | `UserGameSettings:GetCameraYInvertValue()` | Multiply your custom camera pitch input by it |
| Camera shake setting | None at platform level that we could find | Build your own |
| Flash limiting | None | Build your own |

Reading `UserGameSettings` is done through `UserSettings():GetService("UserGameSettings")` on the client. Its sensitivity and invert members carry the Input capability in docs, which suggests they are readable by game scripts; if you write a fully custom camera (see [[Custom Character Controllers]]), apply them so that players do not have to set sensitivity twice.

---

## 3. A comfort settings module

Every system that moves the camera or the screen should ask one module how much motion is allowed. The module combines the platform preference with game settings, and fires a signal when anything changes so long-running effects can stop.

```lua
--!strict
-- Comfort: single source of truth for motion-related settings (client).
local GuiService = game:GetService("GuiService")

export type Settings = {
	shakeScale: number, -- 0..1, multiplies all camera shake
	fovKickScale: number, -- 0..1, multiplies FOV punches and kicks
	headBob: boolean,
	flashes: boolean, -- full-screen flashes and impact frames
	speedVignette: boolean,
	fov: number, -- base FOV the player chose
	horizonLock: boolean, -- vehicles and boats keep the horizon level
}

local DEFAULTS: Settings = {
	shakeScale = 1,
	fovKickScale = 1,
	headBob = true,
	flashes = true,
	speedVignette = false,
	fov = 70,
	horizonLock = false,
}

-- What "reduced motion" changes when the player has not customised these values.
local REDUCED: Settings = {
	shakeScale = 0,
	fovKickScale = 0.5,
	headBob = false,
	flashes = false,
	speedVignette = true,
	fov = 70,
	horizonLock = true,
}

local Comfort = {}

local overrides: { [string]: any } = {} -- only keys the player explicitly set
local changed = Instance.new("BindableEvent")
Comfort.Changed = changed.Event

local function base(): Settings
	return if GuiService.ReducedMotionEnabled then REDUCED else DEFAULTS
end

function Comfort.get(): Settings
	local b = base()
	local result = table.clone(b)
	for key, value in overrides do
		(result :: any)[key] = value
	end
	return result
end

function Comfort.set(key: string, value: any)
	if (DEFAULTS :: any)[key] == nil then
		return
	end
	if key == "fov" then
		value = math.clamp(tonumber(value) or 70, 60, 100)
	elseif key == "shakeScale" or key == "fovKickScale" then
		value = math.clamp(tonumber(value) or 1, 0, 1)
	end
	overrides[key] = value
	changed:Fire(Comfort.get())
end

function Comfort.reset(key: string)
	overrides[key] = nil
	changed:Fire(Comfort.get())
end

function Comfort.loadOverrides(saved: { [string]: any })
	table.clear(overrides)
	for key, value in saved do
		Comfort.set(key, value)
	end
end

function Comfort.exportOverrides(): { [string]: any }
	return table.clone(overrides)
end

GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
	changed:Fire(Comfort.get())
end)

return Comfort
```

Design decisions worth copying:

- **Overrides, not copies.** Only values the player explicitly changed are saved. If they never touched shake, turning on Reduce Motion in Roblox settings later still turns shake off. If they did set shake to 40%, their choice wins. Saving a full copy of the defaults would freeze them.
- **Clamp at the boundary.** Saved values come back from a DataStore and might be from an old version; clamp on load ([[Data Schema Design and Migrations]]).
- **Reduced motion keeps information.** It halves FOV kicks rather than removing them, matching the reference project's rule that a short FOV change carries information at low cost while shake and roll are the main triggers ([[Camera Shake and Camera FX]]).
- **Speed vignette is on in reduced mode.** It reduces peripheral motion, which helps the players who asked for less motion, and players who dislike it can turn it off.

---

## 4. Field of view

### 4.1 Ranges

Roblox's default vertical FOV of 70 degrees is a sensible middle. Offering a slider helps two groups: players on large or close screens who feel sick at narrow FOV (they want wider), and players on small phones who want things bigger (they may want slightly narrower). A range of 60 to 100 is a good default (rule of thumb); beyond about 100 vertical, distortion at the edges becomes its own discomfort and gameplay readability suffers.

On ultrawide monitors, `FieldOfViewMode` matters: with the default vertical mode, the horizontal FOV grows with aspect ratio, which is usually what ultrawide players want. Do not "fix" it to a constant horizontal FOV unless you have a reason.

### 4.2 One owner, additive effects

Every effect that changes FOV (sprint, dash, zoom, ultimate) must add to the player's chosen base through one owner, as described in [[Camera Systems]]. The comfort-specific addition: scale every effect's contribution by `fovKickScale`, and clamp the total change. The reference project capped total FOV change at 12 degrees for gameplay effects and clamped ultimates to 35 to 105 overall (measured in the reference project). With a player base of 90, a +12 kick lands at 102, which is fine; with an aim-zoom of -30 it lands at 60, also fine. Test the extremes of the player range, not just 70.

### 4.3 Zoom transitions

Scope zooms that snap from 70 to 20 are less sickening than slow zooms, because a slow FOV change is a sustained vection stimulus. Rule of thumb: FOV changes the player triggers should complete in under 0.15 s or be instant.

---

## 5. Camera motion budget

Think of camera motion as a budget per effect, then let the comfort settings scale it.

| Effect | Comfortable default | Reduced motion | Notes |
|---|---|---|---|
| Hit shake (light) | Translational, under 0.15 studs, under 0.2 s | Off | High frequency and short is better than slow wobble |
| Explosion shake | Translational plus tiny pitch, decays in 0.4 s | Off, replace with UI pulse | Never roll |
| Head bob while walking | Small vertical only, or none | Off | First-person only; off by default is reasonable |
| Landing dip | Short downward offset, 0.15 s | Keep at 30% or off | Player-caused, mostly tolerated |
| Knockback camera | Camera follows the character, no extra spin | Same | Never add rotation to knockback |
| Camera roll | Avoid for gameplay | Off | Reserve for rare cinematic moments |
| Cutscene moves | Smooth constant-velocity paths, cuts preferred over whip pans | Cuts or fades only | Always skippable ([[Cameras and Cutscenes]]) |
| Screen-wide wobble or warp | Avoid | Off | Common in "drunk" or "dizzy" status effects; offer an off switch |

The alternative to shake for conveying impact, which costs nothing in comfort: **UI and local feedback**. A brief edge vignette pulse, a hit-marker on the reticle, a controller rumble ([[Captions and Audio Accessibility]] covers haptics), a sound. Under reduced motion, route impact feedback there instead of the camera.

### 5.1 Speed vignette

Darkening the periphery during fast movement reduces the peripheral optic flow that drives vection. VR games use it widely; on a flat screen it is milder but still helpful for dashes, grapples, vehicles and long falls.

```lua
--!strict
-- SpeedVignette: fades a full-screen vignette image in with camera speed (client).
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Comfort = require(script.Parent.Comfort)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local vignette = playerGui:WaitForChild("VignetteGui"):WaitForChild("Vignette") :: ImageLabel
-- The image is a radial gradient: transparent centre, black edges. ImageTransparency 1 = invisible.

local START_SPEED = 40 -- studs per second where the vignette begins
local FULL_SPEED = 120 -- studs per second where it reaches maximum strength
local MAX_STRENGTH = 0.55 -- never fully black at the edges
local RESPONSE = 6 -- per second; higher reacts faster

local enabled = Comfort.get().speedVignette
Comfort.Changed:Connect(function(s)
	enabled = s.speedVignette
end)

local lastPos: Vector3? = nil
local strength = 0

RunService.PreRender:Connect(function(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera or dt <= 0 then
		return
	end
	local pos = camera.CFrame.Position
	local speed = if lastPos then (pos - lastPos).Magnitude / dt else 0
	lastPos = pos
	-- Ignore teleports and respawns: a jump of hundreds of studs in one frame is not motion.
	if speed > 2000 then
		speed = 0
	end
	local target = 0
	if enabled then
		local t = math.clamp((speed - START_SPEED) / (FULL_SPEED - START_SPEED), 0, 1)
		target = t * MAX_STRENGTH
	end
	strength += (target - strength) * (1 - math.exp(-RESPONSE * dt))
	vignette.ImageTransparency = 1 - strength
end)
```

The exponential smoothing (`1 - exp(-k dt)`) keeps the response frame-rate independent ([[Springs Damping and Smoothing]]). Measuring camera speed rather than character speed makes it work for vehicles, cutscenes and spectating too.

### 5.2 Horizon lock for vehicles and boats

Vehicle cameras that inherit the vehicle's full orientation roll with every bump and bank with every turn. Many players are fine; some are sick within minutes. A horizon-locked option follows the vehicle's yaw (and optionally a damped pitch) but never its roll.

```lua
--!strict
-- Horizon-locked follow camera for a vehicle (client). Camera.CameraType must be Scriptable
-- while this runs; restore the previous type when the player leaves the vehicle.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HorizonCam = {}

local OFFSET_BACK, OFFSET_UP = 18, 6
local YAW_RESPONSE = 5
local PITCH_FOLLOW = 0.3 -- 0 = ignore vehicle pitch entirely, 1 = follow fully

function HorizonCam.attach(root: BasePart): () -> ()
	local camera = Workspace.CurrentCamera
	local previousType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	local yaw = select(2, root.CFrame:ToEulerAnglesYXZ())

	local conn = RunService.PreRender:Connect(function(dt: number)
		local look = root.CFrame.LookVector
		local targetYaw = math.atan2(-look.X, -look.Z)
		-- Shortest-path angle difference so yaw does not spin the long way at +-pi.
		local diff = (targetYaw - yaw + math.pi) % (2 * math.pi) - math.pi
		yaw += diff * (1 - math.exp(-YAW_RESPONSE * dt))
		local pitch = math.asin(math.clamp(look.Y, -1, 1)) * PITCH_FOLLOW
		local orientation = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0) -- roll is always zero
		local focus = root.Position + Vector3.new(0, 2, 0)
		local camPos = focus + orientation * Vector3.new(0, OFFSET_UP, OFFSET_BACK)
		camera.CFrame = CFrame.lookAt(camPos, focus)
	end)

	return function()
		conn:Disconnect()
		camera.CameraType = previousType
	end
end

return HorizonCam
```

Note that `CFrame.lookAt` with the default up vector already produces a level horizon; the orientation is used only to place the camera behind the vehicle. Return the cleanup function and call it on exit, death and respawn, or the player is stuck in a Scriptable camera ([[Camera Systems]] has the watchdog pattern).

---

## 6. Flashing and photosensitivity

The widely used guideline (WCAG 2.x success criterion 2.3.1) is: no content flashes more than three times in any one-second period, unless the flash is below the general flash and red flash thresholds. In games, the risky effects are full-screen white or black impact frames, strobing rarity reveals, lightning, muzzle flashes filling the screen, and rapidly alternating colours on large UI.

Two things make games harder than web pages: flashes come from **many systems** at once (three players using ultimates near you), and they are **not authored as a sequence**, so no one designer sees the combined result. The fix is a gate that every large flash must pass through.

```lua
--!strict
-- FlashGate: global limiter for large-area flashes on this client.
-- Allows at most MAX_PER_SECOND flash events in any rolling one-second window,
-- and none at all when the player has disabled flashes.
local Comfort = require(script.Parent.Comfort)

local FlashGate = {}

local MAX_PER_SECOND = 2 -- below the guideline's 3 to leave margin for flashes we do not control
local WINDOW = 1.0
local recent: { number } = {}

local function prune(now: number)
	local i = 1
	while i <= #recent do
		if now - recent[i] > WINDOW then
			table.remove(recent, i)
		else
			i += 1
		end
	end
end

-- Returns true if the caller may play its flash now. Callers that get false
-- should fall back to a non-flashing version (a soft vignette, a short tint at low opacity).
function FlashGate.request(): boolean
	if not Comfort.get().flashes then
		return false
	end
	local now = os.clock()
	prune(now)
	if #recent >= MAX_PER_SECOND then
		return false
	end
	table.insert(recent, now)
	return true
end

return FlashGate
```

Usage rules:

- **Anything that covers a large part of the screen with a sudden brightness change goes through the gate**: impact frames, white flashes, lightning on the sky, full-screen colour inversions, strobe reveals. Small sparks and hit flashes on a single enemy do not need it.
- **Other players' effects count.** Route remote players' ultimate flashes through the same gate; that is exactly where flashes stack.
- **Avoid saturated red full-screen flashes entirely.** The guideline treats red flashes more strictly; there is no gameplay need for them that a vignette cannot meet.
- **A "flashes" setting is separate from reduced motion.** Some players are fine with motion but not flashes, and the reverse. The comfort module defaults flashes off under reduced motion, which matches the reference project's practice of removing impact frames for reduced motion (measured in the reference project), and players can choose independently.
- **Long, slow pulses are fine.** A low-health border that pulses once per second at moderate contrast is not a flash in the guideline's sense. A full-screen red pulse at 4 Hz is.

---

## 7. UI and world motion beyond the camera

Reduced motion is not only about the camera. Large moving areas cause the same discomfort:

- Animated backgrounds behind menus (scrolling patterns, rotating sunbursts): stop them under reduced motion.
- Parallax layers in menus: flatten.
- Skyboxes with fast-moving clouds or spinning portals that fill the view: slow or stop.
- Screen-space distortion and chromatic aberration effects: off.
- Animated textures on large floors (conveyors, water flow): reduce speed, or accept them as gameplay information and keep them slow.

The motion helper in [[Accessibility]] handles UI tweens. Combine it with `Comfort.Changed` so that idle loops stop when the setting turns on mid-session; long-running effects that check the setting only at start are the most common bug here.

---

## 8. When not to do this

- **Do not strip the feel out of the default game.** Shake, FOV kicks and impact frames are part of what makes combat readable and satisfying ([[Game Feel and Juice]]). Keep them for players who want them; make them scalable.
- **Do not hide camera settings in a sub-menu three levels deep.** Players who feel sick need to find the fix in the first minute.
- **Do not reimplement Roblox's sensitivity settings.** Two sensitivity sliders that multiply each other confuse everyone.
- **Do not add a vignette that cannot be turned off.** Some players find it claustrophobic.

---

## 9. Testing

- Play 20 minutes on a large monitor at close distance with default settings, including vehicles and combat. If any tester reports discomfort, find the effect, not the person.
- Turn on Reduce Motion in Roblox settings and confirm, system by system, that shake is gone, roll is gone, idle UI loops stop, and flashes are off. Then turn it off mid-session and confirm everything returns.
- Trigger the worst case for flashes: several players using flashy abilities together. Count flashes per second on a screen recording; the gate should hold it at two.
- Check FOV extremes (60 and 100) with every FOV effect active.
- Exit a vehicle, die in a vehicle, and respawn in a vehicle with horizon lock on; the camera must always return to normal.

---

## Common mistakes

- Camera roll on hits, landings or dizziness effects.
- Head bob on by default with no off switch.
- Several systems tweening FOV independently.
- Reduced motion that only shortens tweens.
- Flashes that pass individually but stack to five or six per second in a crowded fight.
- Saving the full settings table, so later changes to Roblox's Reduce Motion no longer apply.
- A Scriptable vehicle camera that is never restored on death.
- Long-running visual loops that read the comfort setting only at start.

## Checklist

- [ ] One comfort module combines `ReducedMotionEnabled` with saved player overrides and fires a change signal.
- [ ] FOV slider (about 60 to 100), one FOV owner, effect contributions scaled and clamped.
- [ ] Camera shake scalable to zero; no gameplay roll.
- [ ] Head bob off by default or toggleable.
- [ ] Speed vignette option for fast movement.
- [ ] Horizon lock option for vehicles and boats, restored on every exit path.
- [ ] Every large flash goes through a gate (at most 2 per second), with a flashes setting.
- [ ] Idle UI and world loops stop when reduced motion turns on mid-session.
- [ ] Custom cameras respect Roblox's sensitivity and invert settings.

See also: [[Accessibility Start Here]], [[Accessibility]], [[Camera Shake and Camera FX]], [[Camera Systems]], [[Cameras and Cutscenes]], [[Game Feel and Juice]], [[UI and GUI Animation]], [[Springs Damping and Smoothing]], [[Captions and Audio Accessibility]].

## Connected notes
<!-- auto-links:start -->
[[Snippets - Camera Shake and FX]] · Game Feel Start Here · Hit-Stop and Screen Shake Tuning by Numbers · Official Docs - Input and Controls · Juice on a Budget - Mobile and Low-End · Tween vs Spring
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] · [[Chase Cameras and Speed Effects for Vehicles]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Accessibility Cross-Links for QoL Settings]] · [[Onboarding Accessibility and Cross-Device Prompts]]
<!-- related:end -->
