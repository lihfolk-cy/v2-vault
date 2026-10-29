---
tags: [systems, camera, cutscene, cinematics, ui, type/guide, area/animation, level/intermediate, api/UserInputService, area/ui, api/BindToRenderStep, api/Camera]
---
# Cameras and Cutscenes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Camera slowly turns after effects: Additive offset not undone, or yaw in the offset -> Undo at Camera-1; translation and roll only
> - HUD missing after a cutscene: No restore on an error path -> Watchdog and restore on every exit
> - Camera stuck Scriptable after death: Restore not hooked to Died / CharacterRemoving -> Hook both
>
> Cost: TL;DR ~120 tok · whole note ~4.3k tok. Read more: ## Cutscenes · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

The camera is part of the animation. A swing with a 3-frame camera kick reads twice as heavy; an ultimate shot from a low three-quarter angle reads twice as big. But the camera is also the player's main tool for playing the game, so every camera effect is a negotiation over who owns it. This note covers the two ownership models (additive and Scriptable), how to build a cutscene system that always gives the camera back, framing rules, and the Studio gotchas. Shake and short effects are in [[Camera Shake and Camera FX]]; ultimates in [[Cinematic Ultimates]]. Numbers come from one live action game (the reference project).

## How the default camera works (what you are negotiating with)

- The `PlayerModule` camera scripts update `workspace.CurrentCamera.CFrame` every frame in a render step bound at `Enum.RenderPriority.Camera` (value 200). Input is read at `Input` (100), the character at `Character` (300).
- With `Camera.CameraType = Enum.CameraType.Custom`, those scripts own the camera: zoom, rotation, collision (Poppercam), shift-lock, first person.
- With `CameraType = Scriptable`, they stop writing and your code owns `Camera.CFrame` and `FieldOfView` completely.

See [[Frame Order and RunService Timing]] for where these steps sit in the frame.

## Two ownership models

| | Additive | Scriptable |
|---|---|---|
| Who writes the base camera | The player's camera module | Your code |
| What you add | Offsets on top (FOV, roll, translation, a bias toward a target) | Everything |
| Player control | Kept (mouse, touch, gamepad, zoom, shift-lock) | Lost |
| Use for | Gameplay effects, onlookers, anything during play | Cutscenes, intros, menus, the caster's ultimate |
| Risk | Drift if you do not undo your offset | Never giving the camera back |

The reference project's rule for big moves: **additive for everyone, Scriptable only for the caster of an ultimate and for intros.** Taking the camera from an onlooker because someone else cast a move is never acceptable.

### Additive done right: undo and redo

An additive offset must be removed before the camera module runs again, or the module reads back a camera that already includes last frame's offset and the effect accumulates (drift).

```lua
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local applied = CFrame.identity -- the offset we added last frame

-- Before the camera module: take last frame's offset back out.
RunService:BindToRenderStep("FxUndo", Enum.RenderPriority.Camera.Value - 1, function()
	camera.CFrame = camera.CFrame * applied:Inverse()
	applied = CFrame.identity
end)

-- After the camera module: put this frame's offset on top.
RunService:BindToRenderStep("FxApply", Enum.RenderPriority.Camera.Value + 1, function()
	local offset = currentOffset() -- camera-space translation and roll only, from your effect stack
	camera.CFrame = camera.CFrame * offset
	applied = offset
end)
```

Why the undo step is needed even though the module "sets" the camera: the default module computes the next CFrame partly from the current one (for example its rotation smoothing and its focus), so leftover offsets leak in. The reference camera effects verified **zero view drift and FOV back exactly on base** after every envelope ended. The ultimate camera package applies at `Camera + 4` for the same pattern with more layers.

**Offset only in camera space, and only translation plus roll.** Do not rotate the look direction in an additive offset (pitch or yaw): the module's mouse look is relative to the current look, so a yaw offset becomes a permanent turn. Translation and roll leave the look vector untouched.

## Cutscenes

### What a cutscene system must do

1. **Lock**: set a lock attribute (the reference used `CutsceneLock = "<owner>"` on the player) so every other controller (abilities, swings, flourishes, other cameras) steps aside. Disable player controls.
2. **Hide**: every `ScreenGui` in `PlayerGui` that is enabled (remember which), the CoreGui (`StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)`), the mouse icon (`UserInputService.MouseIconEnabled = false`), proximity prompts, other players' nameplates and enemy health bars. Then slide letterbox bars in.
3. **Shoot**: `CameraType = Scriptable`, then drive `CFrame` and `FieldOfView` per shot from a render step.
4. **Restore exactly**: every hidden thing back to its previous state, the camera back to `Custom`, and the player's own zoom and look direction as before the cutscene, through a short blend (0.55 s in the reference).
5. **Survive failure**: restore on death, respawn, character removal, a weapon swap, another script taking the camera, a script error, and a **watchdog** (no frame for 0.6 s, or past the expected length plus 2 s).

The last point is what separates a cutscene system from a cutscene. Every cutscene bug players report is a restore bug: the HUD never came back, the camera stayed Scriptable, input stayed locked.

### A minimal, safe cutscene runner

```lua
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

type Shot = { dur: number, at: (u: number) -> (CFrame, number) } -- u = 0..1 through the shot -> camera CFrame, FOV

local Cutscene = {}
local running = false

function Cutscene.play(owner: string, shots: { Shot })
	if running then return false end
	running = true
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	-- 1. remember everything we will change
	local saved = { cf = camera.CFrame, fov = camera.FieldOfView, guis = {} :: { ScreenGui } }
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then g.Enabled = false; table.insert(saved.guis, g) end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
	UserInputService.MouseIconEnabled = false
	player:SetAttribute("CutsceneLock", owner)
	camera.CameraType = Enum.CameraType.Scriptable

	local total = 0
	for _, s in shots do total += s.dur end
	local t0, lastFrame = os.clock(), os.clock()
	local done = false

	local function restore()
		if done then return end
		done = true
		RunService:UnbindFromRenderStep("Cutscene")
		for _, g in saved.guis do if g.Parent then g.Enabled = true end end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
		UserInputService.MouseIconEnabled = true
		camera.FieldOfView = saved.fov
		camera.CameraType = Enum.CameraType.Custom -- the camera module resumes from its own state
		player:SetAttribute("CutsceneLock", nil)
		running = false
	end

	RunService:BindToRenderStep("Cutscene", Enum.RenderPriority.Camera.Value + 1, function()
		lastFrame = os.clock()
		local t = os.clock() - t0
		if t >= total then restore() return end
		local acc = 0
		for _, s in shots do
			if t < acc + s.dur then
				local cf, fov = s.at((t - acc) / s.dur)
				camera.CFrame, camera.FieldOfView = cf, fov
				break
			end
			acc += s.dur
		end
	end)

	-- Watchdog: restores if frames stop, or the cutscene overruns, whatever happened.
	task.spawn(function()
		while not done do
			task.wait(0.2)
			if os.clock() - lastFrame > 0.6 or os.clock() - t0 > total + 2 then restore() end
		end
	end)
	-- Death or respawn restores at once.
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Died:Once(restore) end
	player.CharacterRemoving:Once(restore)
	return true
end

return Cutscene
```

This version snaps back to the player camera; a production version blends over about 0.55 s from the last shot to where the player's camera would be, by keeping the render step alive during the blend and lerping toward the camera module's output (which it starts producing again once `CameraType` is `Custom`). Save the player's zoom too if your shots change the camera focus distance.

### Shot grammar

The reference ultimate cinema uses a fixed grammar of named shots (hero, establish, action variants, climax with slow motion, a smash cut, aftermath, return); its timing and per-tier parameters are in [[Cinematic Ultimates]]. The general rules behind it:
- **Every eye is raycast clear of walls**, pulled in toward its subject, and kept above the ground.
- **Cut on action** (on the climax frame), not between beats.
- **A wide after the big moment** (aftermath) lets players see the result.
- **Return to the player's own camera** (their zoom and look direction from before), not to a default angle.

## Framing

- **Scale offsets by character scale.** The reference cinematic offset at 1x was camera offset (14, 9, 12), look offset (0, 3.5, -6), FOV 42; at 1.6x characters every distance scales by 1.6.
- **Use real clip lengths**, read from the clips, not hard-coded shot timings. Retimed clips otherwise desync from their camera.
- **Wall avoidance**: a raycast from subject to eye; snap in immediately when blocked, ease back out when clear. Snapping out looks like a cut; easing in lets the wall cover the subject for a few frames.
- **Remember the player's base FOV** when you start (store it). A stale stored base FOV (70 when the player's was different) caused visible FOV jumps at the end of shots.
- **First person**: if the camera focus distance is under about 2.5 studs, skip framing and apply only FOV, screen and shake layers. VR: no camera or FOV changes at all.

## Other camera systems

### Death and respawn

A reference death camera: the body topples (0.55 s) and fizzles (white highlight plus sparks, 0.8 s fade); the camera glides 1.4 s to a spot in front of the respawn point looking back at it; the character fizzles in; the camera returns to `Custom`. In a later version, with a death clip, the fizzle-out is at about 1.55 s and the camera move at about 2.45 s.

### Boss intros

About 8 s, once per player, skippable after 2 s, restored on end, death, respawn or an ultimate. Players within range receive the boss's root CFrame and scale, so each client frames shots around the real boss. Keep tall props out of the camera's paths (over 8 studs). See [[Boss Animation and Phases]].

### First-time intro

A 27 s first-person wake-up for new profiles only, skippable after 3 s, flagged in the profile so it never replays.

### Previews and menus

A move-list preview holds the world: camera Scriptable, controls off, mouse wheel and right mouse button sunk (bound with `ContextActionService` returning `Sink`) so the player cannot zoom or rotate the live camera behind the menu.

### Letterbox bars

Bars drifted or scaled wrongly on phones until the bars' `ScreenGui` used `ScreenInsets = Enum.ScreenInsets.None`, `SafeAreaCompatibility = Enum.SafeAreaCompatibility.None` (the project notes call it "Off"), `ClipToDeviceSafeArea = false`, and the bars were excluded from the game's UI auto-scaler. Draw letterbox **under** the HUD when the HUD stays visible (additive ultimates), over it in cutscenes. Details in [[Camera Shake and Camera FX]].

## Studio gotchas

- Tools that take positioned screenshots in Edit can leave the Edit camera `Scriptable`. Set `CameraType = Custom` afterwards (one workflow waited 0.6 s before resetting).
- During play tests, Studio tooling can reset camera changes made from the command bar; test camera code from scripts.
- Edit-mode captures can come back black when Studio is not focused.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Camera slowly turns after effects | Additive offset not undone, or yaw in the offset | Undo at Camera-1; translation and roll only |
| HUD missing after a cutscene | No restore on an error path | Watchdog and restore on every exit |
| Camera stuck Scriptable after death | Restore not hooked to Died / CharacterRemoving | Hook both |
| FOV jumps at the end of a shot | Stale saved base FOV | Read the base at start |
| Camera inside a pillar | No wall raycast, or arena props in the lane | Raycast eyes; clear camera lanes |
| Onlookers lose control during someone's ultimate | Scriptable used for everyone | Additive for onlookers |

See also: [[Camera Shake and Camera FX]], [[Cinematic Ultimates]], [[Boss Animation and Phases]], [[UI and GUI Animation]], [[Snippets - Camera Shake and FX]].

## Nuances and edge cases

1. **Cutscenes in multiplayer are personal.** A cutscene on one client never pauses the world. Enemies keep attacking, other players keep moving, and the server keeps ticking. Before taking someone's camera for 8 seconds, decide what protects them: invulnerability while locked (server-enforced, with a cap so it cannot be abused), a safe zone, or no cutscene at all in hostile areas.
2. **Scale of shared cinematics.** A cinematic that plays for every player in range (a boss intro, a world event) multiplies the restore risk by the player count. At 50 players, a 1 percent restore bug rate is a stuck player every other event. Build the watchdog and the restore paths before the shots.
3. **Skip etiquette.** First-time players accept a short intro; returning players resent any unskippable cutscene. Skippable after 2 to 3 seconds, as in the reference project, is a good default; a profile flag that remembers "seen" is essential. For live events, let players opt out entirely in settings.
4. **Streaming.** A cinematic shot that frames a distant landmark shows an empty area if the landmark is not streamed in on that client. Request streaming around the shot positions ahead of time (`Player:RequestStreamAroundAsync` on the server for the player, Roblox docs (as of October 2026)), or mark the landmark model as persistent.
5. **Phone aspect ratios.** Shots framed on a 16:9 monitor crop differently on a 19.5:9 phone (wider) and a 4:3 tablet (taller). A subject at the edge of a 16:9 frame can be off screen on a tablet. Keep subjects within the centre 60 percent horizontally, or adjust FOV by aspect.
6. **VR.** The note already says no camera or FOV changes in VR. In practice, cutscenes in VR should be fades to a fixed viewpoint, or skipped.
7. **Console safe zones and TVs.** Some TVs overscan the edges. Subtitles and skip prompts placed at the extreme edges of the screen can be cut off; keep them inside the safe area even when the letterbox ignores it.
8. **Accessibility.** Captions for any spoken or story-critical audio during cutscenes, and a reduced-motion version (fewer camera moves, cuts instead of swoops) for motion-sensitive players.

The senior trade-off: cinematic camera work sells moments, but every second of taken control is a second of player frustration if it happens too often or at the wrong time. Spend it on firsts (first boss, first ultimate) and rare events, and give everything repeated a short or skippable form.

## Common mistakes in production

1. **Cutscene during combat with no protection.** Symptom: players die while unable to move. Fix: server-enforced invulnerability or no cutscenes in combat zones.
2. **Landmarks not streamed in.** Symptom: shots of empty space on some clients. Fix: request streaming ahead, or persistent models.
3. **Skip prompt only on keyboard.** Symptom: console and phone players cannot skip. Fix: a skip button that works with touch and gamepad.
4. **Restore that re-enables UI the player had closed.** Symptom: menus pop open after a cutscene. Fix: remember the enabled state of each ScreenGui, restore only those.
5. **Cutscene audio ignores player volume settings.** Symptom: loud cutscene music after a player turned music down. Fix: route cutscene audio through the same sound groups as the rest of the game.

## Related decisions

- [[Camera Systems]]: the gameplay camera that cutscenes must hand back to.
- [[Motion Sensitivity and Camera Comfort]]: reduced-motion versions of camera moves.
- [[Captions and Audio Accessibility]]: captioning story audio during cinematics.
- [[Instance Streaming]]: making sure shot targets exist on the client.
- [[First-Time User Experience and Onboarding]]: when an intro helps or loses new players.
- [[Boss Fight Design Patterns]]: where boss intros sit in the fight's pacing.
- [[Lore Delivery Without Walls of Text]]: using short cinematics instead of exposition.
- [[Responsive UI for Phone Tablet Console and PC]]: skip prompts and subtitles across devices.
- [[Spatial Audio and Mixing]]: keeping cutscene audio inside the game's mix.

## Connected notes
<!-- auto-links:start -->
[[Official Docs - Input and Controls]] · Safe Areas and Insets · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Modelling to the Roblox Camera and Player Scale · Safe Area · HUD Design · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Layering Camera Feedback on the Default Camera]] · [[Ability Kits Architecture]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[VFX Timing with Animation]] · [[Hit Reactions Stagger and Hit-Stop]] · [[Emotes and Social Animation]] · [[Weapon and Combat Animation]] · [[Custom Locomotion Controller Design]] · [[Enemy and NPC Animation]]
<!-- related:end -->
