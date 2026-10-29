---
tags: [gameplay, character-controller, movement, stamina, dash, input, type/guide, area/gameplay, level/intermediate, api/Humanoid]
---
# Custom Character Controllers

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Asking the server before moving -> Act on client, validate on server
> - Avoid: Forked PlayerModule -> Layer on top
> - Avoid: Direct WalkSpeed writes from many systems -> Multiplier stack
> - Controller states explicit; `Locked` absorbs external control.
> - Stamina has regen delay and exhausted lockout; bar always readable.
> - Coyote time and jump buffer present.
>
> Cost: TL;DR ~130 tok · whole note ~4.3k tok. Read more: ## 4. Sprint and stamina · ## 7. Server validation that does not punish lag · ## Common mistakes · ## Checklist
<!-- tldr:end -->

"Custom character controller" covers a wide range: a sprint key with stamina on top of the default Humanoid, a full move set (double jump, wall jump, dash, slide, ground slam), or a complete replacement of Humanoid movement with a `ControllerManager`. This note is about building the movement layer players feel every second: how to structure it, where it runs, how to keep it responsive and still cheat-resistant, and the game-feel details (coyote time, jump buffering, stamina regen delay) that separate good controllers from stiff ones.

Physics primitives: [[Mover Constraints and Physics Controllers]]. Humanoid basics: [[Characters and Humanoids]]. Animation of the result: [[Custom Locomotion Controller Design]] and [[Locomotion Systems]].

Source labels: **Docs**, **Measured** (the reference project), **Rule of thumb**.

---

## 1. Where movement code must run

The player's client owns the character's physics ([[Network Ownership]]). Movement code therefore runs on the **client**, every frame, with zero latency. The server's job is different: it **observes** the result and rejects the impossible.

| Layer | Runs on | Responsibility |
|---|---|---|
| Input | Client | Read keys, sticks, touch; map to intents |
| Controller | Client | Turn intents into Humanoid input, movers, states |
| Feedback | Client | Camera FX, sounds, VFX, animation |
| Validation | Server | Speed, position, cooldown and resource sanity checks |
| Authority over consequences | Server | Damage, pickups, zone entry, rewards |

A controller that asks the server "may I dash?" and waits for the answer feels like it has a 100 to 250 ms input delay on real connections. Do the dash at once on the client, tell the server it happened, and let the server judge (cooldown, stamina, distance). If the server disagrees it can reject the *consequences* (no i-frames, no dash damage) and, for blatant cases, correct the position.

As of October 2026 the docs also describe a server-authoritative netcode mode with client prediction and rollback (Server Authority, `RunService:BindToSimulation`). In that model movement code must be deterministic and written against simulation-safe APIs. Most games still use the classic client-owned model described here; check the current docs if you want prediction built in.

---

## 2. Default control scripts and how to take over

`StarterPlayerScripts` gets a `PlayerModule` at runtime with a `ControlModule` (reads input, calls `Humanoid:Move`) and a `CameraModule`. Options, from least to most invasive:

| Option | How | When |
|---|---|---|
| Layer on top | Your LocalScript reads `Humanoid.MoveDirection` and adds sprint, dash, jumps | Most games |
| Disable specific controls | `StarterPlayer.DevComputerMovementMode` / `DevTouchMovementMode` = `Scriptable` | Click-to-move, pathfinding-driven, cutscene-heavy games |
| Fork PlayerModule | Copy it into `StarterPlayerScripts` and edit | You need changes deep in input handling; you now own its updates |
| Replace movement | `EvaluateStateMachine = false` + ControllerManager | Non-standard physics |

Rule of thumb: **do not fork PlayerModule** unless you must. Roblox updates it (touch controls, gamepad, VR); a fork freezes you on an old version.

`Humanoid:Move()` is overwritten every frame by the default ControlModule (Docs). If your controller calls `Move` (for a dash steering or an auto-run), call it from a RenderStep binding with a priority after the control module's, or the default scripts erase your input.

---

## 3. A state machine, not a pile of flags

A move set grows: sprint, crouch, slide, dash, double jump, wall jump, slam, guard, stagger, frozen, cutscene. Booleans multiply into impossible combinations ("sliding while frozen while dashing"). Model it as states with explicit transitions:

```lua
--!strict
export type MoveState = "Ground" | "Air" | "Dash" | "Slide" | "Slam" | "Locked"

type Controller = {
	state: MoveState,
	stateT: number, -- time entered
	enter: (self: Controller, s: MoveState) -> (),
}

local Controller = {}
Controller.__index = Controller

function Controller.new(): Controller
	local self = setmetatable({ state = "Ground" :: MoveState, stateT = os.clock() }, Controller)
	return (self :: any) :: Controller
end

local ALLOWED: { [MoveState]: { [MoveState]: boolean } } = {
	Ground = { Air = true, Dash = true, Slide = true, Locked = true },
	Air = { Ground = true, Dash = true, Slam = true, Locked = true },
	Dash = { Ground = true, Air = true, Locked = true },
	Slide = { Ground = true, Air = true, Dash = true, Locked = true },
	Slam = { Ground = true, Locked = true },
	Locked = { Ground = true, Air = true },
}

function Controller.enter(self: Controller, s: MoveState)
	if s == self.state or not ALLOWED[self.state][s] then
		return
	end
	self.state = s
	self.stateT = os.clock()
end

return Controller
```

`Locked` absorbs every "something else owns the body" case: cutscene lock, freeze, being grabbed by a boss, ultimate anchor, death. Enter it from attribute listeners (`CutsceneLock`, `FrozenUntil`, `KitControl` in the reference project) so controllers never need to know about each other ([[Characters and Humanoids]] section 8).

---

## 4. Sprint and stamina

Stamina is the most common addition and the easiest to make feel bad. The parts:

| Parameter | Typical (rule of thumb) | Why |
|---|---|---|
| Max | 100 | Readable on a bar |
| Drain while sprinting | 15 to 25 per second | 4 to 7 s of sprint |
| Cost per dash | 20 to 35 | 3 to 5 dashes from full |
| Regen delay after use | 0.6 to 1.2 s | Stops "tap sprint to never run out" |
| Regen rate | 25 to 40 per second | Full in 3 to 4 s |
| Exhausted lockout | Sprint off until 25% | Prevents stutter-sprinting at 0 |

```lua
--!strict
-- Client stamina model. Pure maths, testable without a character.
export type Stamina = {
	value: number,
	max: number,
	lastSpend: number,
	exhausted: boolean,
}

local DRAIN = 20
local REGEN = 32
local REGEN_DELAY = 0.9
local RECOVER_AT = 0.25

local M = {}

function M.new(max: number): Stamina
	return { value = max, max = max, lastSpend = -math.huge, exhausted = false }
end

function M.trySpend(s: Stamina, amount: number, now: number): boolean
	if s.exhausted or s.value < amount then
		return false
	end
	s.value -= amount
	s.lastSpend = now
	return true
end

-- Returns true if sprinting may continue this frame.
function M.step(s: Stamina, dt: number, now: number, sprinting: boolean): boolean
	if sprinting and not s.exhausted then
		s.value = math.max(0, s.value - DRAIN * dt)
		s.lastSpend = now
		if s.value <= 0 then
			s.exhausted = true
		end
	elseif now - s.lastSpend >= REGEN_DELAY then
		s.value = math.min(s.max, s.value + REGEN * dt)
	end
	if s.exhausted and s.value >= s.max * RECOVER_AT then
		s.exhausted = false
	end
	return sprinting and not s.exhausted
end

return M
```

Design notes:
- **Who owns stamina?** For a single-player-feel controller, the client simulates it and the server keeps a coarser copy (refilled by elapsed time) to reject impossible dash rates. The server copy does not need to match frame for frame; it needs to catch "40 dashes in 10 seconds".
- **Show the bar always or never.** The reference project changed its stamina HUD to stay visible even when full, after testers lost track of it. A bar that fades in only when draining surprises players.
- **Phones.** Touch players have no spare finger for a sprint key. The reference project made touch players sprint as soon as they move and removed the touch RUN toggle. Give touch players auto-sprint or a smaller speed gap ([[Responsive UI for Phone Tablet Console and PC]], [[Gamepad and Console UX]]).
- **Guard and sprint interact.** Holding guard halved speed in the reference project. Encode such rules in one place (a speed multiplier stack), not in each system.

### Speed multiplier stack
Many systems want to change WalkSpeed: sprint, guard, slow debuffs, potions, carrying. If each writes WalkSpeed directly, the last writer wins and buffs "stick" after expiring. Keep a table of named multipliers and recompute:

```lua
--!strict
local mults: { [string]: number } = {}
local BASE = 16

local function apply(humanoid: Humanoid)
	local m = 1
	for _, v in mults do
		m *= v
	end
	humanoid.WalkSpeed = BASE * m
end

local function setMult(humanoid: Humanoid, key: string, value: number?)
	mults[key] = value -- nil removes it
	apply(humanoid)
end
```

---

## 5. Jumps: coyote time, buffering, double and wall jumps

- **Coyote time.** Allow a jump for about 0.1 s after walking off a ledge. Without it, players press jump "on the edge" and fall.
- **Jump buffering.** Remember a jump press for about 0.1 to 0.15 s; if the character lands within that window, jump on landing.
- **Double jump.** On a jump press in `Air` with charges left: set vertical velocity directly on the root (the client owns it), play the clip, spend a charge. Refill charges on a *verified* landing.
- **Wall jump.** Raycast sideways for a wall with a near-horizontal normal; push away along the normal plus up.

The reference project's lesson (see [[Characters and Humanoids]] section 3): refill charges only when the ground is verified by rays with `Normal.Y >= 0.55`, never on `FloorMaterial` alone, and disable native jumping while standing on a steep "floor".

```lua
--!strict
local function solidFloor(root: BasePart, hipHeight: number, exclude: { Instance }): boolean
	local params = RaycastParams.new()
	params.ExcludeInstances = exclude
	local half = root.Size * 0.5
	local offsets = {
		Vector3.zero,
		Vector3.new(half.X, 0, 0), Vector3.new(-half.X, 0, 0),
		Vector3.new(0, 0, half.Z), Vector3.new(0, 0, -half.Z),
	}
	local reach = half.Y + hipHeight + 0.6
	for _, o in offsets do
		local origin = root.CFrame:PointToWorldSpace(o)
		local hit = workspace:Raycast(origin, Vector3.new(0, -reach, 0), params)
		if hit and hit.Normal.Y >= 0.55 then
			return true
		end
	end
	return false
end
```

---

## 6. Dash, slide, slam

| Move | Build | Gotchas |
|---|---|---|
| Dash | LinearVelocity Plane mode for 0.15 to 0.3 s; `Move(dir)` alongside | Humanoid braking from standstill (measured); cleanup on death |
| Slide | Reduce friction or hold a decaying LinearVelocity; lower hip/collider if crouching | Colliders that shrink must grow back without clipping into ceilings: cast before standing |
| Slam | Set downward velocity in air; on landing, a server-validated area effect | Landing detection with rays, not `Landed` alone, for fast falls |

**Dash i-frames are a server decision.** The client dashes instantly; the server records `dashAt` when the dash message arrives and grants invulnerability for a window from that time. The reference project uses 0.40 s against boss-class attacks, and its damage function checks dash frames before guard. Because the server timestamp is later than the client's, the window effectively starts late by the player's latency; that is acceptable for a 0.4 s window but not for a 0.1 s "perfect dodge". Tight windows need server-side rewind ([[Hitboxes and Hit Detection]]).

### Camera feedback
Movement feels faster with camera support. Measured values from the reference project's camera FX layer (all envelopes end at exactly zero and are summed with caps of 12 degrees FOV, 1.6 studs offset, 4 degrees roll):
- dash: +9 FOV (0.06 s in, 0.25 s out), 0.7 stud kick along the dash, 2.5 degree roll, 0.1 s blur;
- jump: +3 FOV and a 0.35 stud lag;
- landing dip scaled by fall height (45 to 140 studs, squared curve), with a small shake past half strength.
All of it switches off with a "Camera Effects" setting and halves under reduced motion. See [[Camera Systems]] and [[Game Feel and Juice]].

---

## 7. Server validation that does not punish lag

Movement anti-cheat must tolerate lag spikes, teleports you caused, knockback, moving platforms and low frame rates. A practical server check:

```lua
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SAMPLE = 0.5         -- seconds between samples
local SLACK = 1.5          -- multiplier over the allowed speed
local FLAT_ALLOW = 8       -- studs of free movement per sample (jitter, platforms)

local last: { [Player]: { pos: Vector3, t: number, strikes: number } } = {}

local function allowedSpeed(player: Player, humanoid: Humanoid): number
	-- Include every legitimate source: walk speed, dash, launch pads.
	local dash = (player:GetAttribute("DashBudget") :: number?) or 0
	return humanoid.WalkSpeed + dash
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < SAMPLE then return end
	acc = 0
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = hum and hum.RootPart
		if not (hum and root) or hum.Health <= 0 then
			last[player] = nil
			continue
		end
		local flat = root.Position * Vector3.new(1, 0, 1)
		local rec = last[player]
		if rec and not player:GetAttribute("ServerTeleported") then
			local dist = (flat - rec.pos).Magnitude
			local budget = allowedSpeed(player, hum) * (now - rec.t) * SLACK + FLAT_ALLOW
			if dist > budget then
				rec.strikes += 1
				if rec.strikes >= 3 then
					root.CFrame = CFrame.new(rec.pos + Vector3.new(0, root.Position.Y, 0))
					rec.strikes = 0
				end
			else
				rec.strikes = math.max(0, rec.strikes - 1)
			end
		end
		player:SetAttribute("ServerTeleported", nil)
		last[player] = { pos = flat, t = now, strikes = rec and rec.strikes or 0 }
	end
end)

Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
```

Principles:
- Horizontal only; vertical speed has too many legitimate causes (falls, launches).
- Strikes, not instant punishment; decay strikes on good samples.
- Any server teleport sets a flag so the next sample is skipped.
- Correct position rather than kick. Log for review. See [[Exploits and Anti-Cheat]].

---

## 8. Input mapping

Bind intents, not keys. `ContextActionService:BindAction` handles keyboard, gamepad and touch buttons in one call and respects priorities, and newer projects can use the input action system. The reference project's control fixes are typical of what goes wrong:
- Shift-lock conflicted with Shift-to-sprint; `StarterPlayer.EnableMouseLockOption` was turned off so Shift is sprint only.
- Gamepad face buttons were claimed by proximity prompts; prompts were moved to the D-pad so X stays an ability.
- Panels bind gamepad B to close only while open, with a sinking priority, then unbind.

Details: [[Input - UserInputService and ContextActionService]], [[Gamepad and Console UX]].

---

## 9. Testing a controller

- Make the maths pure (stamina, jump windows, speed stack) and unit-test it ([[Testing Strategies and Frameworks]]).
- Test at 30 and 240 FPS: anything not scaled by `dt` changes with frame rate.
- Test with simulated latency in Studio's network settings: dashes, i-frames and server checks.
- Test on a phone: thumb reach, auto-sprint, camera FX comfort.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Asking the server before moving | Input lag | Act on client, validate on server |
| Forked PlayerModule | Breaks after Roblox updates | Layer on top |
| Direct WalkSpeed writes from many systems | Stuck buffs | Multiplier stack |
| Refill jumps on FloorMaterial | Wall climbing | Ray-verified floor |
| Frame-rate dependent drains | Faster drain at high FPS | Multiply by `dt` |
| Speed check without teleport flags | False positives after your own teleports | Flag and skip |

## Checklist
- [ ] Controller states explicit; `Locked` absorbs external control.
- [ ] Stamina has regen delay and exhausted lockout; bar always readable.
- [ ] Coyote time and jump buffer present.
- [ ] Dash uses Plane mode and server-side i-frame timing.
- [ ] Server movement check tolerant of lag and your own teleports.
- [ ] Touch and gamepad paths tested.

## See also
[[Characters and Humanoids]] · [[Mover Constraints and Physics Controllers]] · [[Camera Systems]] · [[Combat Systems Architecture]] · [[Custom Locomotion Controller Design]] · [[Foot Placement and Ground IK]] · [[Camera Shake and Camera FX]] · [[Exploits and Anti-Cheat]]

## Connected notes
<!-- auto-links:start -->
[[Links - Humanoids and character controllers]] · Input Responsiveness Buffering and Coyote Time · Humanoid States and Animation · Input Buffering · Side-Scroller in 3D - Locking Camera and Movement to a Plane · 2D Collision Physics and Platformer Movement
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]] · [[Status Effects Buffs and Stacking Rules]] · [[Chase Cameras and Speed Effects for Vehicles]] · [[Physics Assemblies and Constraints]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Grabs, Carries and Throws - Moving Players Safely]] · [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] · [[Pathfinding Edge Cases and Fallbacks]]
<!-- related:end -->
