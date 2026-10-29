---
tags: [snippets, luau, camera, fx, game-feel, type/reference, area/animation, level/intermediate, api/TweenService, area/scripting, api/BindToRenderStep, api/Camera]
---
# Snippets: Camera Shake and FX

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Writing `Camera.CFrame` additively without removing it (camera drifts).
> - Avoid: Switching to `Scriptable` for gameplay shake.
> - Avoid: Random per-frame jitter instead of noise.
>
> Cost: TL;DR ~90 tok · whole note ~5.3k tok. Read more: ## 2. The module · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

A camera effects module built from **timed envelopes** that are summed, capped, applied after the camera scripts and **removed before them** the next frame, so effects never accumulate into drift. Includes trauma-based shake with noise, FOV punches, roll, camera-space kicks, blur and colour flashes, distance falloff for world events, reduced-motion handling, presets measured in one production game, and a letterbox that sits correctly on phones.

Design discussion is in [[Camera Shake and Camera FX]], [[Cameras and Cutscenes]] and [[Cinematic Ultimates]]. Timing effects to animation markers is covered in [[VFX Timing with Animation]].

---

## 1. Principles

1. **Additive, never Scriptable.** Gameplay camera effects add to whatever the camera module produced. Switching `CameraType` to `Scriptable` for a shake breaks player control and every camera mode. Cutscenes are the exception, and they own the camera fully.
2. **Envelopes that end at exactly zero.** Every effect has attack, hold and release, and its value at the end is exactly 0, so removing it causes no pop.
3. **Sum, then cap.** Ten overlapping hits must not produce a 60-degree FOV jump. Caps used in the reference project: FOV +12 degrees, offset 1.6 studs, roll 4 degrees.
4. **Remove before the camera module runs.** The default camera computes next frame's camera from the current `Camera.CFrame`. If your offset is still in it, the camera drifts by your offset every frame. Apply at `Camera + 1`, remove at `Camera - 1`.
5. **Translation and roll only, look untouched.** Rotating pitch or yaw for shake moves the aim point; in a combat game that feels like losing control. Camera-space translation plus roll reads as shake without moving the crosshair (a reference project rule).
6. **Respect reduced motion.** `GuiService.ReducedMotionEnabled` (Docs) is true when the player asked for less motion. The reference project kept only FOV effects at half strength in that mode.
7. **Off when the camera is someone else's.** Disable during cutscenes, death cameras and spectating; let them fade out rather than cut.

---

## 2. The module

```lua
--!strict
-- CameraFX (client): envelope-based FOV / offset / roll / shake, applied after the camera module
-- and removed before it, so nothing accumulates.
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")

local CameraFX = {}

export type Effect = {
	attack: number?,          -- seconds to full strength (0 = instant)
	hold: number?,            -- seconds at full strength
	release: number?,         -- seconds back to zero
	fov: number?,             -- degrees added to FieldOfView at full strength
	offset: Vector3?,         -- camera-space studs (+Z = backward, +Y = up)
	roll: number?,            -- degrees
	trauma: number?,          -- 0..1 shake amount at full strength (shake = trauma^2)
	frequency: number?,       -- shake noise frequency (Hz-ish), default 18
	blur: number?,            -- BlurEffect.Size at full strength
}

type Live = Effect & { t0: number, seed: number, scale: number }

local CAP_FOV = 12
local CAP_OFFSET = 1.6
local CAP_ROLL = math.rad(4)
local SHAKE_OFFSET = 0.6      -- studs of translation at shake 1
local SHAKE_ROLL = math.rad(2.5)

local live: { Live } = {}
local suppressed = false
local applied = { cf = CFrame.identity, fov = 0 }

local blur = Instance.new("BlurEffect")
blur.Name = "CameraFXBlur"
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting

-- 0 -> 1 -> 1 -> 0, smooth at both ends, exactly 0 after release
local function envelope(e: Live, t: number): number
	local a, h, r = e.attack or 0, e.hold or 0, e.release or 0.2
	if t < 0 then return 0 end
	if t < a then
		local u = t / a
		return u * u * (3 - 2 * u)                          -- smoothstep in
	end
	t -= a
	if t < h then return 1 end
	t -= h
	if t >= r then return 0 end
	local u = 1 - t / r
	return u * u                                            -- quadratic out: fast drop, soft tail
end

local function lifetime(e: Effect): number
	return (e.attack or 0) + (e.hold or 0) + (e.release or 0.2)
end

-- Fire an effect. scale multiplies its strength (use for distance falloff). Returns a cancel function.
function CameraFX.play(e: Effect, scale: number?): () -> ()
	local item: Live = table.clone(e) :: any
	item.t0 = os.clock()
	item.seed = math.random() * 1000
	item.scale = scale or 1
	table.insert(live, item)
	return function()
		-- cancel = jump straight into the release from the current level (no pop)
		local now = os.clock() - item.t0
		local lvl = envelope(item, now)
		item.attack, item.hold = 0, 0
		item.release = (e.release or 0.2) * lvl
		item.t0 = os.clock()
		item.scale *= lvl
	end
end

-- World event: falloff with distance from the camera (full within inner, zero beyond outer).
function CameraFX.playAt(e: Effect, position: Vector3, inner: number, outer: number)
	local cam = workspace.CurrentCamera
	local d = (cam.CFrame.Position - position).Magnitude
	local k = 1 - math.clamp((d - inner) / math.max(outer - inner, 1e-3), 0, 1)
	if k > 0 then CameraFX.play(e, k * k) end
end

function CameraFX.setSuppressed(on: boolean)
	suppressed = on
end

-- 1. Remove last frame's contribution BEFORE the camera module reads the camera.
RunService:BindToRenderStep("CameraFXRemove", Enum.RenderPriority.Camera.Value - 1, function()
	local cam = workspace.CurrentCamera
	if applied.fov ~= 0 then cam.FieldOfView -= applied.fov end
	if applied.cf ~= CFrame.identity then cam.CFrame = cam.CFrame * applied.cf:Inverse() end
	applied.cf, applied.fov = CFrame.identity, 0
end)

-- 2. Apply this frame's sum AFTER the camera module.
RunService:BindToRenderStep("CameraFXApply", Enum.RenderPriority.Camera.Value + 1, function()
	local cam = workspace.CurrentCamera
	local now = os.clock()
	local fov, roll, shake, blurSize = 0, 0, 0, 0
	local offset = Vector3.zero
	local noiseX, noiseY, noiseR = 0, 0, 0

	local i = 1
	while i <= #live do
		local e = live[i]
		local t = now - e.t0
		if t >= lifetime(e) then
			table.remove(live, i)
		else
			local k = envelope(e, t) * e.scale
			fov += (e.fov or 0) * k
			roll += math.rad(e.roll or 0) * k
			offset += (e.offset or Vector3.zero) * k
			blurSize = math.max(blurSize, (e.blur or 0) * k)
			local tr = (e.trauma or 0) * k
			if tr > 0 then
				local s = tr * tr                                  -- trauma^2: small hits barely shake
				local f = e.frequency or 18
				-- math.noise returns roughly -1..1; different seeds give independent channels
				noiseX += s * math.noise(e.seed, t * f, 0)
				noiseY += s * math.noise(e.seed, t * f, 10)
				noiseR += s * math.noise(e.seed, t * f, 20)
				shake = math.max(shake, s)
			end
			i += 1
		end
	end

	if suppressed then return end
	local reduced = GuiService.ReducedMotionEnabled
	fov = math.clamp(fov, -CAP_FOV, CAP_FOV)
	if reduced then
		fov *= 0.5                                                -- reduced motion: half FOV, nothing else
		offset, roll, noiseX, noiseY, noiseR, blurSize = Vector3.zero, 0, 0, 0, 0, 0
	end
	offset += Vector3.new(noiseX, noiseY, 0) * SHAKE_OFFSET
	if offset.Magnitude > CAP_OFFSET then offset = offset.Unit * CAP_OFFSET end
	roll = math.clamp(roll + noiseR * SHAKE_ROLL, -CAP_ROLL, CAP_ROLL)

	local cf = CFrame.new(offset) * CFrame.Angles(0, 0, roll)    -- camera space: translation + roll only
	cam.CFrame = cam.CFrame * cf
	cam.FieldOfView += fov
	applied.cf, applied.fov = cf, fov

	blur.Size = blurSize
	blur.Enabled = blurSize > 0.05
end)

return CameraFX
```

Notes on the less obvious parts:
- **Trauma squared.** Shake intensity grows with the square of trauma, so small hits barely shake and big ones shake hard. It is the most useful single trick for readable shake.
- **Noise, not random.** `math.noise` gives smooth, continuous motion. `math.random` per frame gives a jittery buzz that depends on frame rate.
- **Cancel by releasing.** Cancelling jumps into the release phase from the current level instead of removing the effect, so there is no pop.
- **`FieldOfView` and other writers.** If another system also changes FOV (a zoom, a sprint FOV), it should do so between `Camera - 1` and `Camera + 1`, or own a separate base value. Writers that set FOV absolutely after `Camera + 1` overwrite the effect for that frame.
- **Camera-relative offset during first person.** A translation offset in first person moves the camera inside the head. Use FOV and roll only when zoomed fully in.

---

## 3. Presets (measured in one production game)

```lua
local Presets = {
	-- Dash: +9 FOV with a 0.06 s rise and 0.25 s fall, a "0.7 kick", 2.5 deg roll, blur 5 for 0.1 s.
	-- (The source gives the kick as 0.7 without a unit; it is modelled here as a 0.7-stud push back.)
	Dash = { attack = 0.06, hold = 0, release = 0.25, fov = 9, offset = Vector3.new(0, 0, 0.7), roll = 2.5 },
	DashBlur = { attack = 0, hold = 0.1, release = 0.05, blur = 5 },

	-- Jump: +3 FOV and the camera lagging 0.35 studs below for a beat
	Jump = { attack = 0.05, hold = 0.05, release = 0.3, fov = 3, offset = Vector3.new(0, -0.35, 0) },

	-- Light hit (attacker side): tiny trauma, very short
	HitLight = { attack = 0, hold = 0.02, release = 0.12, trauma = 0.35 },
	-- Heavy hit / finisher
	HitHeavy = { attack = 0, hold = 0.04, release = 0.25, trauma = 0.7, fov = -2 },
}

-- Landing dip scaled by fall speed: nothing below 45 studs/s, full at 140, quadratic in between
local function onLanded(fallSpeed: number)
	local k = math.clamp((fallSpeed - 45) / (140 - 45), 0, 1)
	if k <= 0 then return end
	k *= k
	CameraFX.play({ attack = 0.03, hold = 0, release = 0.3, offset = Vector3.new(0, -1.2, 0), trauma = 0.4 }, k)
end
```

Pair the dash's FOV punch with the clip: fire it from the dash clip's start marker, not from the input, so a dash that is refused does not punch. For hits, fire on the `Hit` marker of the attack clip on the attacker's client, and give onlookers a milder version through `playAt` with distance falloff (the reference project gave onlookers a mild shake only for ultimates).

---

## 4. Impact frames and colour flashes

```lua
-- A white "impact frame" flash and a desaturation pulse, both envelope-driven.
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "ImpactCC"
cc.Parent = Lighting

local function impactFrame(kind: "white" | "mono", duration: number?)
	local d = duration or 0.08
	if GuiService.ReducedMotionEnabled then return end      -- flashes are a reduced-motion concern too
	if kind == "white" then
		cc.Brightness, cc.Contrast = 0.6, 0.4
	else
		cc.Saturation, cc.Contrast = -1, 0.6
	end
	-- hold for the frame, then release quickly
	task.delay(d, function()
		TweenService:Create(cc, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = 0, Contrast = 0, Saturation = 0 }):Play()
	end)
end
```
A true "negative" frame (inverted colours) is not something `ColorCorrectionEffect` is documented to do; fake it with a full-screen GUI frame or a pre-made overlay. Keep flashes short (2 to 5 frames) and rare: they are the most fatiguing effect for players, and some are photosensitive. Gate them behind a setting.

---

## 5. Letterbox bars that sit right on phones

```lua
--!strict
-- Cinematic bars. Must ignore device safe areas, or they sit inset on notched phones.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local function makeLetterbox(): (number) -> ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Letterbox"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ClipToDeviceSafeArea = false
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	gui.DisplayOrder = 50                            -- under the HUD you still want visible, over the world
	gui.ResetOnSpawn = false
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	local function bar(top: boolean): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, top and 0 or 1)
		f.Position = UDim2.fromScale(0, top and 0 or 1)
		f.Size = UDim2.fromScale(1, 0)
		f.Parent = gui
		return f
	end
	local topBar, bottomBar = bar(true), bar(false)

	-- set(0.12) shows bars covering 12% of the screen each; set(0) hides them
	return function(fraction: number)
		local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(topBar, info, { Size = UDim2.fromScale(1, fraction) }):Play()
		TweenService:Create(bottomBar, info, { Size = UDim2.fromScale(1, fraction) }):Play()
	end
end
```
Exclude the bars from any automatic UI scaler. The reference project's bars sat inset and scaled wrong until all four of `ScreenInsets = None`, safe-area compatibility off, `ClipToDeviceSafeArea = false` and "skip the scaler" were applied. When bars change the visible aspect, compensate FOV if the framing matters (the reference project's ultimate camera did).

---

## 6. Wiring it to animation

```lua
-- Drive camera FX from clip markers on the local character only.
local AnimPlay = require(game.ReplicatedStorage.AnimPlay)
local CameraFX = require(game.ReplicatedStorage.CameraFX)

AnimPlay.play(animator, FINISHER_ID, {
	priority = Enum.AnimationPriority.Action4,
	markers = {
		Hit = function() CameraFX.play(Presets.HitHeavy) end,
		Slam = function() CameraFX.play({ attack = 0, hold = 0.05, release = 0.4, trauma = 0.9, fov = -3 }) end,
	},
})
```
A data table of beats per move (`[kit][move][marker] = beat kind`) scales well: the reference project mapped 349 markers across 110 moves of 45 kits to beat kinds that chose shake, VFX tier and travel behaviour, so designers tuned feel in one table instead of in 110 scripts.

---

## Common mistakes
- Writing `Camera.CFrame` additively without removing it (camera drifts).
- Switching to `Scriptable` for gameplay shake.
- Random per-frame jitter instead of noise.
- No caps: stacked hits produce huge FOV jumps.
- Rotational shake that moves the aim point.
- Ignoring `ReducedMotionEnabled`.
- Effects that keep running during cutscenes and death cameras.
- Letterbox inside the device safe area on notched phones.

## See also
[[Camera Shake and Camera FX]] · [[Cameras and Cutscenes]] · [[Cinematic Ultimates]] · [[VFX Timing with Animation]] · [[Hit Reactions Stagger and Hit-Stop]] · [[UI and GUI Animation]] · [[Snippets - Playing Animations]]

## Nuances and edge cases

1. **Frame rate changes what "0.08 s" means.** At 60 FPS a 0.08 s [[Impact Frames|impact frame]] is about 5 frames; at 30 FPS on a low-end phone it is 2 or 3; at 240 FPS with an unlocked frame rate (Roblox lets players raise the cap in settings, rule of thumb that more players do this every year) it is about 19. Envelopes keyed to `os.clock()` survive all of these, but anything counted in frames does not. Never write `for i = 1, 5 do RenderStepped:Wait() end` for a flash.
2. **Noise frequency and high refresh rates.** `math.noise` sampled at 18 "Hz" looks smooth at 60 FPS and buttery at 144, but at 30 FPS the same curve is sampled so sparsely that it reads as stepping. If your analytics show a lot of low-end phones, drop default frequency to 12 to 14 and raise amplitude slightly instead.
3. **Who else writes the camera.** The bind order trick (`Camera - 1` remove, `Camera + 1` apply) assumes only the default camera module writes `CFrame` between them. A custom over-the-shoulder camera bound at `Camera` works; one written in `Heartbeat` or `RenderStepped:Connect` without a priority does not have a guaranteed slot relative to your binds, so the remove step may undo someone else's change. Put every camera writer on `BindToRenderStep` with an explicit priority and document the order in one place.
4. **Respawn and camera replacement.** `workspace.CurrentCamera` can be replaced (rare, but it happens when scripts destroy the camera or on some teleport arrival paths). The module reads `workspace.CurrentCamera` each frame, which is correct; caching the camera at require time is the classic bug.
5. **Shift lock and mouse lock.** In shift lock the default camera offsets the subject sideways. Camera-space translation still works, but a large +X kick visually fights the shoulder offset. Keep kicks on Y and Z.
6. **Vehicles and seated players.** When a player sits, the camera subject becomes the seat or vehicle. Landing dips that read fall speed from the Humanoid stop firing, and vehicle bumps should feed `playAt` from the vehicle instead.
7. **Scale effects across a server.** The `playAt` falloff is per client, so cost scales with events seen, not players. With 50 players in an arena and every hit calling `playAt`, a client can receive 100+ shake events per second; the cap protects the camera but not your remote budget. Send world shakes only for events above a size threshold, and let small hits stay local to attacker and victim.
8. **Reduced motion is a spectrum.** `ReducedMotionEnabled` is binary, but players who need it differ. A per-game slider (0 to 100 percent shake) on top of the system flag is cheap and much appreciated; treat the system flag as "default the slider low", not as the only switch.
9. **Blur cost on low-end.** `BlurEffect` is a full-screen post-process. On weak mobile GPUs it can cost a visible frame-time spike the first time it enables. Pre-enabling at size 0 is not free either; rule of thumb is to enable for the duration and accept the hitch only on high graphics quality levels, skipping blur below a quality threshold.
10. **Console and TV distance.** On a TV viewed from a couch, roll reads much stronger than on a phone held in hand, and FOV punches read weaker. If you ship on console, test the presets on a television, not a monitor.

The senior trade-off: every camera effect costs a little player control and a little comfort in exchange for impact. Spend it on the moments that matter (finishers, landings from height, ultimates) and leave everyday actions quiet. A game where every swing shakes trains players to stop noticing shake.

## Common mistakes in production

1. **Caching `CurrentCamera` at module load.** Symptom: effects stop working after a camera swap or a teleport arrival. Fix: read `workspace.CurrentCamera` inside each bound function.
2. **Shake playing on the server.** Symptom: nothing happens, or an error about the camera. Fix: camera FX are client only; the server sends an event, the client plays it.
3. **Using the same seed for every effect.** Symptom: two overlapping shakes add into one big shake instead of mixing. Fix: random seed per effect, as above.
4. **Distance falloff measured from the character, not the camera.** Symptom: in a zoomed-out camera, explosions near the character shake too hard. Fix: measure from `Camera.CFrame.Position`, or blend both.
5. **Forgetting to unbind on teardown.** Symptom: after a character respawn with a reloaded controller, two copies run, effects double and drift appears. Fix: `UnbindFromRenderStep` in the controller's cleanup, or make the module a singleton required once.
6. **Flashes with no setting.** Symptom: complaints from photosensitive players, store reviews about headaches. Fix: a "Flashing effects" toggle that defaults on but is easy to find.

## Related decisions

- [[Motion Sensitivity and Camera Comfort]]: what limits to set for shake, FOV and roll so motion-sensitive players can still play.
- [[Hit-Stop and Screen Shake Tuning by Numbers]]: the numbers for trauma, durations and caps tuned across hit tiers.
- [[Juice on a Budget - Mobile and Low-End]]: which of these effects to drop first on weak devices.
- [[Feedback Timing - Sound Visual and Haptic Sync]]: lining shake up with sound and controller rumble on the same frame.
- [[Camera Systems]]: the camera module this one sits on top of, and its bind priorities.
- [[Safe Areas and Insets]]: why the letterbox needs the device safe area turned off.
- [[MicroProfiler Guide]]: confirming the blur and render step cost on a real device.
- [[Network Bandwidth Budgets and Measuring Them]]: keeping server-sent world shakes inside budget.
- [[Captions and Audio Accessibility]]: pairing visual impact with accessible audio cues so neither carries the moment alone.

## Connected notes
<!-- auto-links:start -->
[[Game Feel Start Here]] · Links - Cameras · Game Feel and Juice · [[Frame Order and RunService Timing]] · Hit-Stop · Accessibility · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Layering Camera Feedback on the Default Camera]] · [[Chase Cameras and Speed Effects for Vehicles]] · [[Snippets - Procedural Motion]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Animation Controller Module]] · [[Snippets - Ragdoll]]
<!-- related:end -->
