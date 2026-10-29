---
tags: [2d, 2.5d, side-scroller, camera, movement, platformer, physics, constraints, input, luau, type/guide, area/2d]
---
# Side-Scroller in 3D - Locking Camera and Movement to a Plane

<!-- tldr:start -->
> [!tldr] TL;DR
> - Player slowly ends up behind the level after bumping into others: No body lock, only camera and input locks -> Add `PlaneConstraint` on the root
> - Character turns to face the screen and walks into a wall when the...: Default camera relative controls still active -> Disable default controls, drive `Move` with...
> - Camera judders while running: Camera updated in `Heartbeat` or with frame dependent lerp -> Bind at `RenderPriority.Camera`, use `1 - exp(-k * dt)`
> - One plane constant (`PLANE_Z`) in shared config, used by server, client and level tools.
> - Camera is `Scriptable`, re-asserted after respawn, updated at `RenderPriority.Camera`, and sets `Focus`.
> - FOV chosen deliberately; distance computed from the visible height; a 4:3 safe column respected.
>
> Cost: TL;DR ~230 tok · whole note ~7.5k tok. Read more: ## 2. The camera lock · ## 5. Complete setup · ## 9. Common mistakes and how to spot them · ## 10. Checklist
<!-- tldr:end -->

A 2.5D side-scroller is a normal Roblox 3D place in which the camera looks at the world from the side and every moving thing is kept on one flat slice of the world. You keep almost everything the engine gives you for free: Humanoid physics and animation, avatars, lighting, particles, sound, streaming, replication, and Studio's level editing tools. You give up the guarantee that "nothing moves in depth", and the whole craft of this style is putting that guarantee back. This note covers the three locks you need (camera, input, body), how to choose each one, how they fail, and a complete working setup.

If you have not yet decided between a GUI-rendered 2D game and this approach, read [[Choosing GUI 2D or Locked-Camera 2.5D]] first. For a pure GUI playfield see [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]; for tile layouts and [[parallax]] in both styles see [[Tilemaps Cameras and Parallax for 2D Levels]].

---

## 1. The three locks, and why you need all of them

A side-scroller "feels 2D" only when three separate things agree.

| Lock | What it stops | What happens if you skip it |
|---|---|---|
| Camera lock | The player rotating or zooming the view | The illusion breaks instantly; players orbit the level and see that it is a thin strip |
| Input lock | Controls producing movement into or out of the screen | "Up" on a thumbstick walks the character into the background; jumping while holding diagonal drifts in depth |
| Body lock | Physics pushing anything off the plane | Collisions with slopes, other players, explosions, and moving platforms slowly drift characters in depth until they fall off a ledge that looks solid from the side |

Beginners usually build the camera lock, notice drift, and then try to fix drift by clamping input. Input clamping cannot fix drift because the drift comes from physics contacts, not from the controls. Equally, a body lock without an input lock makes the character press against an invisible wall whenever the stick points up, which feels sticky and wastes half the stick. Build all three.

**Convention used in this note.** Gameplay happens in the world X (horizontal) and Y (vertical) axes. The gameplay plane is `Z = PLANE_Z`. The camera sits at a larger Z and looks along negative Z, so screen right is world +X. Roblox is Y up and right handed, and a CFrame's `LookVector` is its negative Z axis (Roblox docs (as of October 2026)), so a camera built with `CFrame.lookAt(eye, target)` where `eye.Z > target.Z` has `RightVector` equal to +X. Picking this convention once and writing it at the top of your shared config avoids a whole family of "left is right on this level" bugs.

---

## 2. The camera lock

### 2.1 Scriptable camera, updated at render priority

Set `Camera.CameraType` to `Enum.CameraType.Scriptable`. The docs say the default camera scripts will not move or update the camera in that mode, and that when the default scripts are not running you should update the camera every frame with `RunService:BindToRenderStep()` at `Enum.RenderPriority.Camera` (Roblox docs (as of October 2026)). Binding at that priority matters: if you update the camera in `Heartbeat` instead, it runs after the frame's physics but the view has already been decided for some frames, and you get a one frame lag that reads as judder on a fast moving character.

The default camera scripts also reset `CameraType` when the character respawns in some setups (rule of thumb: re-assert `Scriptable` on `CharacterAdded` and on the first render step rather than trusting a single assignment at startup).

### 2.2 Field of view and distance: how "flat" should it look?

Roblox has no orthographic camera mode; the Camera page lists no orthographic projection and clamps `FieldOfView` to 1 through 120 degrees, default 70, measured vertically by default (`FieldOfViewMode`) (Roblox docs (as of October 2026)). You approximate orthographic projection by using a low field of view and placing the camera far away.

To frame a world height `H` studs at the gameplay plane:

```
distance = (H / 2) / tan(FOV / 2)
visibleWidth = H * aspectRatio
```

Worked example: you want 40 studs of vertical world on screen.

| FOV | Distance needed | Feel |
|---|---|---|
| 70 | 28.6 studs | Strong perspective: platforms in front of the plane look huge, depth layers slide a lot |
| 40 | 54.9 studs | Mild perspective: readable depth, some free parallax |
| 20 | 113.4 studs | Nearly flat: almost orthographic, very little parallax |
| 10 | 228.6 studs | Effectively flat, but see the costs below |

The trade-off is real, not cosmetic:

- **Low FOV makes the gameplay readable.** A jump looks the same length on both sides of the screen, and edges of platforms line up with where collision actually is. Precision platformers want 15 to 30 degrees (rule of thumb).
- **Low FOV loses free parallax.** With perspective, background mountains move slower than the foreground automatically. Flatten the camera and you have to fake parallax yourself (see [[Tilemaps Cameras and Parallax for 2D Levels]]).
- **A far camera has side effects.** Shadows are computed for a larger view, distant geometry must be loaded, and anything between the camera and the plane (foreground decoration) can block the view. The camera is also the default sound listener in many setups, so a camera 200 studs away makes positional sounds near the player quiet. Fix the listener rather than the volume: with the legacy sound system, `SoundService:SetListener` can follow a part such as the root part; with the newer Audio API, put the `AudioListener` on the character instead of the camera (see [[The Audio API - Players Emitters Wires and Effects]]).
- **Streaming follows the character, not the camera.** With `StreamingEnabled`, content near the player's replication focus streams in. A wide side view can show areas further from the character than the streaming radius on wide screens. Either keep `StreamingMinRadius` larger than half your visible width, or set the level as persistent model groups (see [[Instance Streaming]]).

### 2.3 Aspect ratio: phones see more, tall tablets see less

Because the vertical FOV is fixed, a 21:9 phone in landscape shows far more level horizontally than a 4:3 tablet. In a platformer this is a fairness and design issue: wide screen players see enemies earlier. Two answers:

1. **Design for the narrowest common aspect** (4:3 is a safe floor, rule of thumb) and treat extra width as bonus scenery. Keep threats inside the 4:3 safe column.
2. **Fix the horizontal span instead.** Compute the FOV each frame from the viewport so the horizontal span stays constant, accepting that tall screens see more height. Platformers usually prefer the first option; shoot-em-ups that scroll horizontally often prefer the second.

### 2.4 Following the player: dead zone, look-ahead, smoothing, bounds

A camera bolted to the root part makes every small hop shake the whole world. The standard side-scroller camera has four parts:

- **Dead zone (window).** The camera only moves horizontally when the player leaves a box around the screen centre. 2 to 4 studs wide is typical.
- **Look-ahead.** Offset the target in the direction the player faces or moves, so they see what is coming. Ease it in; snapping it when the player turns is the main source of camera sickness in 2D (see [[Motion Sensitivity and Camera Comfort]]).
- **Vertical platform snap.** Do not follow every jump vertically. Follow the Y of the last ground the player stood on, and only follow the actual Y when they fall below the screen or rise above a threshold. This keeps the horizon stable during normal jumping.
- **Bounds.** Clamp the camera target so it never shows outside the level. Clamping after smoothing causes a visible bump at the edges; clamp the target, then smooth toward it.

Use frame rate independent smoothing: `alpha = 1 - math.exp(-sharpness * dt)`. A plain `lerp(current, target, 0.1)` every frame moves twice as fast at 120 FPS as at 60 FPS, which players on high refresh devices notice as a "snappier" camera.

---

## 3. The input lock

### 3.1 Two ways to own movement

The default player scripts (the `PlayerModule` copied into each player's `PlayerScripts`) read keyboard, gamepad and touch input and call `Move` on the character each frame relative to the camera. With the camera looking along negative Z, "forward" on the stick means negative Z, straight into the level. You have two options.

| Option | How | Pros | Cons |
|---|---|---|---|
| A. Keep default controls, rely on the body lock | Leave `PlayerModule` running; the plane constraint cancels depth motion | Free touch thumbstick, jump button, gamepad support | Up and down on the stick waste input; diagonals feel slow because only the X component survives; the character briefly turns to face the screen |
| B. Disable default controls and drive the Humanoid yourself | `require(PlayerModule):GetControls():Disable()`, then call `Humanoid:Move(Vector3.new(x, 0, 0), false)` | Full control: digital left and right, analogue dead zones, coyote time, jump buffering | You must build touch buttons yourself and bind gamepad and keyboard |

Option B is the right one for anything that wants to feel like a platformer. Note that `PlayerModule` and `GetControls` belong to the default player scripts that Roblox ships, not to the documented engine API, so pin your assumptions with a check at startup and fail loudly if the module shape changes.

`Humanoid:Move(moveDirection, relativeToCamera)` takes a world direction when the second argument is `false` (Roblox docs (as of October 2026)). Always pass `false` here: camera relative movement with a side camera is exactly the depth leak you are trying to remove.

### 3.2 Touch controls for a side-scroller

A floating thumbstick is a poor fit for a 2D platformer. Two large left and right buttons on the left thumb and a jump button on the right thumb are easier to hit and never produce accidental depth or diagonal input. Size them to at least 60 to 80 offset pixels and respect safe areas (see [[Safe Areas and Insets]] and [[Responsive UI for Phone Tablet Console and PC]]). Bind them with `ContextActionService:BindAction(..., createTouchButton = false, ...)` driven from your own ImageButtons, or by reading `InputBegan` and `InputEnded` on the buttons; the controller below exposes simple `setHeld` hooks for that.

### 3.3 Facing direction

Leave `Humanoid.AutoRotate` on. With movement restricted to plus or minus X, AutoRotate turns the character to face left or right, which is what you want, and the walk animation plays naturally. Turn it off only if you want instant turning (set the root orientation yourself) or if a mechanic needs the character to face the camera, such as a victory pose. The docs note that with AutoRotate off the model keeps its rotation unless something rotates the root part (Roblox docs (as of October 2026)).

---

## 4. The body lock

### 4.1 PlaneConstraint (preferred)

`PlaneConstraint` "moves its attachments into a position/orientation along a plane whose normal vector is the primary axis of Attachment0" (Roblox docs (as of October 2026)). The primary axis of an attachment is its X axis (`Attachment.Axis`). So you put `Attachment0` in the world with its X axis pointing along world Z, and `Attachment1` on the moving part. The constraint then removes motion along world Z while leaving X and Y free. The docs describe the constraint in terms of "position/orientation" and do not spell out what it does to rotation, so test that the character still turns left and right freely with your rig before relying on it (unverified detail as of October 2026).

Practical points:

- Put the world attachment under `workspace.Terrain`. Attachments parented to Terrain are world attachments and never move.
- Create the constraint on the server when the character spawns. It replicates, and because the client owns its character's physics (see [[Network Ownership]]), the constraint is solved on the client where the movement actually happens.
- Use the same constraint for physics props, enemies driven by physics, and loose debris. Anchored or tweened objects do not need it; just never give them a Z.
- A constraint can be fought. A very strong impulse (an explosion pushing in Z) can produce a visible wobble for a frame. The cure is to never apply depth forces in the first place: build knockback vectors with `Z = 0`.

### 4.2 Per-frame Z clamp (fallback)

The older approach: every `PreSimulation` step on the client, read the root part's position, set its Z back to the plane and zero the Z component of `AssemblyLinearVelocity`. It works, but it teleports the assembly every step, which can wake up contacts, jitter on slopes, and interact badly with Humanoid ground detection. Keep it as a safety net only (for example, only correcting when drift exceeds 0.5 studs).

### 4.3 Thick geometry and invisible walls

Make every walkable surface much deeper than it looks: 8 to 16 studs in Z, centred on the plane (rule of thumb). Then a small drift never drops a player off a ledge, and from a side camera the depth is invisible anyway. Add invisible walls in front of and behind the lane on levels with physics props as a last line of defence, set `CanQuery = false` on them so they do not catch your raycasts, and use collision groups so they only block players and props (see [[Collision and Physics Geometry]]).

### 4.4 Server side validation

The client owns its character and can therefore move it anywhere, including off the plane. That is an exploit vector in competitive modes (walking behind walls, skipping sections). The server should check `math.abs(root.Position.Z - PLANE_Z)` on a slow loop (a few times a second is enough) and treat persistent drift beyond a tolerance as a fault: snap the character back, and log it. Do not treat it as proof of cheating; a single frame of deep drift can come from an honest physics glitch. See [[Server Authority and Validation]].

---

## 5. Complete setup

Shared config, a server script that adds the plane lock to every character, and a client controller that owns the camera and the input.

### 5.1 Shared config (ReplicatedStorage.SideScrollConfig)

```lua
--!strict
-- ModuleScript: ReplicatedStorage.SideScrollConfig
export type Config = {
	PLANE_Z: number,
	CAMERA_FOV: number,
	VIEW_HEIGHT: number,
	DEAD_ZONE_HALF_WIDTH: number,
	LOOK_AHEAD: number,
	CAMERA_SHARPNESS: number,
	LEVEL_MIN_X: number,
	LEVEL_MAX_X: number,
	LEVEL_MIN_Y: number,
	LEVEL_MAX_Y: number,
	MAX_Z_DRIFT: number,
}

local config: Config = {
	PLANE_Z = 0,
	CAMERA_FOV = 25, -- degrees, vertical
	VIEW_HEIGHT = 40, -- studs of world visible vertically at the plane
	DEAD_ZONE_HALF_WIDTH = 1.5,
	LOOK_AHEAD = 4,
	CAMERA_SHARPNESS = 8, -- higher = snappier
	LEVEL_MIN_X = -50,
	LEVEL_MAX_X = 950,
	LEVEL_MIN_Y = 0,
	LEVEL_MAX_Y = 120,
	MAX_Z_DRIFT = 2,
}

return table.freeze(config)
```

### 5.2 Server: lock every character to the plane

```lua
--!strict
-- Script: ServerScriptService.PlaneLockServer
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("SideScrollConfig") :: ModuleScript)

-- One world attachment shared by every constraint. Its X axis (the primary
-- axis) points along world Z, so the constraint removes motion along Z.
local planeAttachment = Instance.new("Attachment")
planeAttachment.Name = "SideScrollPlane"
planeAttachment.CFrame = CFrame.fromMatrix(
	Vector3.new(0, 0, Config.PLANE_Z),
	Vector3.zAxis, -- X axis of the attachment = plane normal
	Vector3.yAxis
)
planeAttachment.Parent = workspace.Terrain

local function lockCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") then
		return
	end

	-- Start exactly on the plane so the constraint does not yank the spawn.
	local p = root.Position
	character:PivotTo(CFrame.new(p.X, p.Y, Config.PLANE_Z) * root.CFrame.Rotation)

	local a1 = Instance.new("Attachment")
	a1.Name = "PlaneLockAttachment"
	a1.Parent = root

	local constraint = Instance.new("PlaneConstraint")
	constraint.Name = "PlaneLock"
	constraint.Attachment0 = planeAttachment
	constraint.Attachment1 = a1
	constraint.Parent = root
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(lockCharacter)
	if player.Character then
		lockCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end

-- Slow drift watchdog. Honest physics can drift briefly; only correct
-- persistent large drift, and log it instead of punishing it.
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if character and root and root:IsA("BasePart") then
				local drift = math.abs(root.Position.Z - Config.PLANE_Z)
				if drift > Config.MAX_Z_DRIFT then
					local p = root.Position
					character:PivotTo(CFrame.new(p.X, p.Y, Config.PLANE_Z) * root.CFrame.Rotation)
					warn(`[PlaneLock] corrected {player.UserId} drift {math.floor(drift * 10) / 10}`)
				end
			end
		end
	end
end)
```

### 5.3 Client: camera and input

```lua
--!strict
-- LocalScript: StarterPlayer.StarterPlayerScripts.SideScrollClient
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("SideScrollConfig") :: ModuleScript)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Disable the default movement controls (they are camera relative).
-- PlayerModule ships with the default player scripts; check its shape.
local playerScripts = player:WaitForChild("PlayerScripts")
local playerModule = require(playerScripts:WaitForChild("PlayerModule") :: ModuleScript) :: any
local controls = playerModule:GetControls()
assert(controls and controls.Disable, "PlayerModule shape changed: GetControls():Disable() missing")
controls:Disable()

-- Input state. Touch buttons can call SideScrollInput:setHeld(...) via a BindableEvent
-- or a shared module; here keyboard and gamepad are read directly.
local touchLeft = false
local touchRight = false
local touchJump = false

local DEAD_ZONE = 0.25
local gamepadX = 0

UserInputService.InputChanged:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		local x = input.Position.X
		gamepadX = if math.abs(x) < DEAD_ZONE then 0 else x
	end
end)

local function readMoveX(): number
	local x = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) or touchLeft then
		x -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) or touchRight then
		x += 1
	end
	if x == 0 then
		x = gamepadX
	end
	return math.clamp(x, -1, 1)
end

local function readJump(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
		or touchJump
end

-- Camera state.
local camTarget = Vector3.new(0, 0, Config.PLANE_Z)
local lookAhead = 0
local groundY = 0
local facing = 1

local function cameraDistance(): number
	local halfFov = math.rad(Config.CAMERA_FOV) / 2
	return (Config.VIEW_HEIGHT / 2) / math.tan(halfFov)
end

local function clampToLevel(target: Vector3): Vector3
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	local halfH = Config.VIEW_HEIGHT / 2
	local halfW = halfH * aspect
	local minX, maxX = Config.LEVEL_MIN_X + halfW, Config.LEVEL_MAX_X - halfW
	local minY, maxY = Config.LEVEL_MIN_Y + halfH, Config.LEVEL_MAX_Y - halfH
	-- If the level is narrower than the view, centre it instead of clamping.
	local x = if minX > maxX then (Config.LEVEL_MIN_X + Config.LEVEL_MAX_X) / 2 else math.clamp(target.X, minX, maxX)
	local y = if minY > maxY then (Config.LEVEL_MIN_Y + Config.LEVEL_MAX_Y) / 2 else math.clamp(target.Y, minY, maxY)
	return Vector3.new(x, y, Config.PLANE_Z)
end

local function onRenderStep(dt: number)
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	camera.FieldOfView = Config.CAMERA_FOV

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) then
		return
	end

	-- Input: world space X only, never camera relative.
	local moveX = readMoveX()
	humanoid:Move(Vector3.new(moveX, 0, 0), false)
	if readJump() then
		humanoid.Jump = true
	end
	if moveX ~= 0 then
		facing = if moveX > 0 then 1 else -1
	end

	-- Vertical snap: follow the last ground height, unless far off screen.
	local pos = root.Position
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		groundY = pos.Y
	end
	local followY = groundY
	if pos.Y < groundY - 4 or pos.Y > groundY + Config.VIEW_HEIGHT * 0.3 then
		followY = pos.Y
	end

	-- Dead zone horizontally, eased look-ahead.
	local desiredX = camTarget.X
	local dx = pos.X - camTarget.X
	if dx > Config.DEAD_ZONE_HALF_WIDTH then
		desiredX = pos.X - Config.DEAD_ZONE_HALF_WIDTH
	elseif dx < -Config.DEAD_ZONE_HALF_WIDTH then
		desiredX = pos.X + Config.DEAD_ZONE_HALF_WIDTH
	end
	local alpha = 1 - math.exp(-Config.CAMERA_SHARPNESS * dt)
	lookAhead += (facing * Config.LOOK_AHEAD - lookAhead) * (1 - math.exp(-2 * dt))

	local goal = clampToLevel(Vector3.new(desiredX + lookAhead, followY + 4, Config.PLANE_Z))
	camTarget = camTarget:Lerp(goal, alpha)

	local eye = camTarget + Vector3.new(0, 0, cameraDistance())
	camera.CFrame = CFrame.lookAt(eye, camTarget)
	camera.Focus = CFrame.new(camTarget)
end

RunService:BindToRenderStep("SideScrollCamera", Enum.RenderPriority.Camera.Value, onRenderStep)

player.CharacterAdded:Connect(function(character: Model)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	camTarget = Vector3.new(root.Position.X, root.Position.Y, Config.PLANE_Z)
	groundY = root.Position.Y
	lookAhead = 0
end)
```

The camera here sets `Focus` every frame as the Camera docs recommend for Scriptable cameras; `Focus` drives level of detail and some lighting decisions, so a stale Focus far from the action can make nearby detail pop.

Movement is applied inside the render step because input and camera are tied to the frame. That is fine for Humanoid movement, which is a velocity request the physics step carries out. If you replace the Humanoid with your own physics controller, move the physics part into `RunService.PreSimulation` and keep only the camera in the render step (see [[Custom Character Controllers]] and [[2D Collision Physics and Platformer Movement]]).

---

## 6. Level building for a locked plane

- **Build in a strip, decorate in depth.** Everything the player can touch sits within the thick lane around `PLANE_Z`. Backgrounds go behind (lower Z), foreground silhouettes in front (higher Z) but never at the camera's height band where they would hide the player. A simple rule: foreground objects only along the bottom fifth and top fifth of the screen.
- **Fade occluders.** If foreground pieces may cover the player, raycast from the camera to the root part each frame and set `LocalTransparencyModifier` on hits, restoring it after. It is cheaper than hand-tuning every scene.
- **Mind backface surprises.** Players never see the back of the level, so you can skip modelling it, but shadows still come from the back faces. Turn off `CastShadow` on paper-thin background flats to avoid shadow lines across the play lane.
- **Use Studio from the game's angle.** Put a camera bookmark (a Part named "EditorView") at the gameplay camera's angle and snap the Studio camera to it when placing platforms. Platform edges that look aligned from a perspective editor camera are often misaligned from the low FOV gameplay camera.
- **Keep the plane at a round number.** `Z = 0` makes it trivial to spot stray parts with a quick command bar scan for anything collidable whose Z range does not include zero.

For platform spacing and jump arcs, the rules in [[Obby and Platforming Level Design]] and [[Genre Playbook - Obbies and Platformers]] apply unchanged; the side view only changes how the player reads distance (much more accurately).

---

## 7. Multiplayer in a locked plane

Several players on one plane overlap visually. Options:

- **Disable player to player collision** with collision groups so players do not block each other in narrow corridors. Almost always correct for co-op platformers.
- **Offset each player slightly in depth for drawing only.** Keep one physics plane, but apply a tiny cosmetic Z offset per player (a few tenths of a stud) on the visible body, not the root, so overlapping avatars do not z-fight. Never move the collision plane per player; then they would stand on different geometry.
- **Camera for co-op.** A shared screen does not exist on Roblox (every player has their own screen), so each player's camera follows themselves. If your design needs players to stay together, tether them with gameplay (respawn the straggler at the leader) rather than with the camera.

The networking side (who owns what, how enemies replicate) is the same as any Roblox game; see [[Replication Rules]] and [[2D Multiplayer - Server Authority and Replicating GUI Worlds]] for the lean snapshot approach if you render enemies yourself.

---

## 8. When not to do this

- **You need pixel exact, retro collision.** Humanoid physics is floaty, has step-up behaviour and slopes that a classic platformer does not. You can tune it (see [[Characters and Humanoids]]) but if your design depends on exact, frame-precise jump arcs, a custom controller or a GUI engine is less work than fighting Humanoid.
- **The art style is flat sprites.** Sprites on parts in 3D get perspective distortion, lighting and filtering you will spend weeks undoing. A GUI-rendered game is cheaper; see [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]].
- **You want hundreds of moving entities.** Each physics body costs simulation and replication. 2D logic in plain tables, drawn in a GUI, scales further.

---

## 9. Common mistakes and how to spot them

| Symptom | Cause | Fix |
|---|---|---|
| Player slowly ends up behind the level after bumping into others | No body lock, only camera and input locks | Add `PlaneConstraint` on the root |
| Character turns to face the screen and walks into a wall when the stick is pushed up | Default camera relative controls still active | Disable default controls, drive `Move` with `relativeToCamera = false` |
| Camera judders while running | Camera updated in `Heartbeat` or with frame dependent lerp | Bind at `RenderPriority.Camera`, use `1 - exp(-k * dt)` |
| Sounds near the player are inaudible | Listener is the far away camera | Put the listener on the character |
| Platforms pop in at the screen edges on wide phones | Streaming radius smaller than half the visible width | Raise `StreamingMinRadius` or make the level persistent |
| Camera bumps at level edges | Clamping after smoothing | Clamp the target, then smooth |
| Wide screen players see enemies earlier | Fixed vertical FOV | Design for a 4:3 safe column or fix the horizontal span |
| Jump distances look different from how they play | Editing from a different angle than the game camera | Use an editor camera bookmark at the gameplay angle |

---

## 10. Checklist

- [ ] One plane constant (`PLANE_Z`) in shared config, used by server, client and level tools.
- [ ] Camera is `Scriptable`, re-asserted after respawn, updated at `RenderPriority.Camera`, and sets `Focus`.
- [ ] FOV chosen deliberately; distance computed from the visible height; a 4:3 safe column respected.
- [ ] Dead zone, eased look-ahead, vertical platform snap, bounds clamped before smoothing.
- [ ] Default controls disabled; `Humanoid:Move` called with world X only and `relativeToCamera = false`.
- [ ] Custom touch buttons for left, right and jump inside safe areas.
- [ ] `PlaneConstraint` on every character and physics prop; world attachment under Terrain with X axis along Z.
- [ ] Walkable geometry at least 8 studs deep; invisible lane walls only where props can be launched.
- [ ] Server drift watchdog that corrects and logs, without punishing single events.
- [ ] Sound listener and streaming radius checked with the far camera.

## See also

[[Camera Systems]], [[Custom Character Controllers]], [[Mover Constraints and Physics Controllers]], [[Input - UserInputService and ContextActionService]], [[Game Feel and Juice]], [[Choosing GUI 2D or Locked-Camera 2.5D]], [[Tilemaps Cameras and Parallax for 2D Levels]].

## Connected notes
<!-- auto-links:start -->
[[2D Game Development Start Here]] · [[Cameras and Cutscenes]] · Cookbook - Math CFrame and Vectors · Modelling to the Roblox Camera and Player Scale · Input Buffering · Dot and Cross Products in Gameplay
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Chase Cameras and Speed Effects for Vehicles]] · [[Layering Camera Feedback on the Default Camera]] · [[Modelling to the Roblox Camera and Player Scale]] · [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] · [[Sprite Sheets and Frame Animation with ImageRectOffset]] · [[EditableImage for Pixel Buffers and Procedural 2D]]
<!-- related:end -->
