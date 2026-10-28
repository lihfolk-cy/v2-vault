---
tags: [snippets, luau, procedural, springs]
---
# Snippets: Procedural Motion

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Writing joints in `PreRender`/`Heartbeat` (overwritten by the next animation step).
> - Avoid: Compounding `Transform = Transform * offset` (winds up on throttled or unkeyed frames).
> - Avoid: Per-frame smoothing with a constant factor (`x += (t - x) * 0.2`), which changes with frame rate.
>
> Read more (22 KB note): ## 3. Look-at for neck and waist, clamped and smoothed · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

Code for motion computed at runtime instead of played from clips: additive layers on top of the Animator, springs, look-at, recoil, breathing, lean, spinning and bobbing objects, a weapon toss, a hinged lid, and server-synchronised one-off motion. The theory is in [[Procedural Animation]], [[Springs Damping and Smoothing]] and [[Look-At Aim and Head Tracking]].

Two rules apply to every joint snippet here:
1. **Write joints in `RunService.PreSimulation`.** The Animator writes `Transform` in the animation step, which runs after `PreAnimation` and before `PreSimulation` (Docs frame order). A write in `PreSimulation` lands on top of this frame's animation and is used by physics. A write in `PreRender` or `Heartbeat` is overwritten by the next animation step.
2. **Never compound onto `Transform`.** `joint.Transform = joint.Transform * offset` is only correct if the Animator rewrote `Transform` this frame. It does not when it is throttled (`Animator.EvaluationThrottled`, Docs) or when no playing track keys that joint. Then your offset is applied twice, three times, and the joint winds away. Track the base yourself (section 1).

Both `Motor6D` and `AnimationConstraint` have a writable `Transform` and readable `C0`/`C1`/`Part0`/`Part1` (read-only aliases of the attachments on `AnimationConstraint`, Docs), so the joint code below accepts either. Type them as `any` or as a small union, because Luau has no common joint type.

---

## 1. Additive layer on top of the Animator (base tracking)

```lua
--!strict
-- AdditiveLayer: write offset * animatedPose on a joint every frame without compounding.
local RunService = game:GetService("RunService")

type Joint = Motor6D | AnimationConstraint

local lastWritten: { [Joint]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local lastBase: { [Joint]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

-- The Animator's pose for this frame. If Transform still equals what WE wrote last frame, the Animator
-- did not write this frame (throttled, or no track keys this joint), so reuse the base we saw last.
local function animatedBase(j: Joint): CFrame
	local cur = (j :: any).Transform :: CFrame
	local mine = lastWritten[j]
	if mine and cur:FuzzyEq(mine, 1e-4) then
		return lastBase[j] or CFrame.identity
	end
	lastBase[j] = cur
	return cur
end

-- offset is expressed in the joint's parent frame (applied after C0, before the animated pose)
local function writeAdditive(j: Joint, offset: CFrame)
	local out = offset * animatedBase(j)
	;(j :: any).Transform = out
	lastWritten[j] = out
end

return { animatedBase = animatedBase, writeAdditive = writeAdditive }
```

Why `offset * base` and not `base * offset`: `Part1 = Part0 * C0 * Transform * C1:Inverse()`. Putting the offset first rotates in the joint's parent space (the torso, for a neck), which is what "turn the head 20 degrees left" means. `base * offset` rotates in the animated child's own space, which drifts as the clip moves the joint.

The leading semicolon before `(j :: any).Transform` stops Luau from reading the line as a call on the previous line's expression.

---

## 2. Springs (frame-rate independent)

The exact critically damped spring. Stable at any `dt`, no overshoot, and works for numbers and `Vector3`s.

```lua
--!strict
-- x: current value, v: velocity, target: goal, w: angular frequency (rad/s; higher = snappier), dt: seconds.
-- Closed-form solution of x'' = -w^2 (x - target) - 2 w x' (critical damping):
--   x(t) = target + (d + (v + w d) t) e^(-w t),   d = x - target
local function springCritical<T>(x: T, v: T, target: T, w: number, dt: number): (T, T)
	local xs, vs, ts = x :: any, v :: any, target :: any
	local d = xs - ts
	local c2 = vs + d * w
	local e = math.exp(-w * dt)
	local nx = ts + (d + c2 * dt) * e
	local nv = (vs - c2 * (w * dt)) * e
	return nx :: T, nv :: T
end

-- Underdamped spring for wobble (zeta < 1). Semi-implicit Euler, sub-stepped for stability.
local function springWobble(x: number, v: number, target: number, w: number, zeta: number, dt: number): (number, number)
	local steps = math.max(1, math.ceil(dt / (1 / 240)))   -- at most 1/240 s per sub-step
	local h = dt / steps
	for _ = 1, steps do
		local a = -w * w * (x - target) - 2 * zeta * w * v
		v += a * h
		x += v * h
	end
	return x, v
end
```

Picking `w`: the critically damped spring settles to within about 1% of the target in about `6.6 / w` seconds (rule of thumb from the closed form). `w = 20` settles in about 0.33 s, `w = 8` in about 0.8 s.

The common shortcut `x += (target - x) * (1 - math.exp(-k * dt))` is a first-order filter, not a spring: it has no velocity, so it cannot carry momentum or overshoot, and it starts moving at full speed instantly. It is fine for camera smoothing; use a spring for anything physical.

---

## 3. Look-at for neck and waist, clamped and smoothed

```lua
--!strict
local RunService = game:GetService("RunService")
local Additive = require(script.Parent.AdditiveLayer)

type LookRig = {
	neck: any, waist: any,             -- Motor6D or AnimationConstraint
	yaw: number, pitch: number,        -- current smoothed angles (radians)
	target: Vector3?,
}

local MAX_YAW, MAX_PITCH = math.rad(70), math.rad(40)
local WAIST_SHARE = 0.35               -- the waist takes 35% of the turn, the neck the rest

local function updateLook(r: LookRig, dt: number)
	local wantYaw, wantPitch = 0, 0
	if r.target then
		-- target in the waist joint's parent frame (LowerTorso * C0). Part CFrames read in PreSimulation
		-- are last frame's physics result: fine for a look-at, not for precise IK.
		local frame = r.waist.Part0.CFrame * r.waist.C0
		local rel = frame:PointToObjectSpace(r.target)
		wantYaw = math.clamp(math.atan2(-rel.X, -rel.Z), -MAX_YAW, MAX_YAW)
		wantPitch = math.clamp(math.atan2(rel.Y, math.sqrt(rel.X * rel.X + rel.Z * rel.Z)), -MAX_PITCH, MAX_PITCH)
	end
	local k = 1 - math.exp(-10 * dt)   -- frame-rate independent smoothing
	r.yaw += (wantYaw - r.yaw) * k
	r.pitch += (wantPitch - r.pitch) * k

	-- fromEulerAnglesYXZ = Ry * Rx * Rz (Docs): yaw about the parent's up axis first, then pitch about the
	-- turned head's own right axis, so looking up-and-sideways never rolls the head.
	-- CFrame.Angles (Rx * Ry * Rz) would pitch first and then yaw about the tilted axis, which rolls it.
	Additive.writeAdditive(r.waist, CFrame.fromEulerAnglesYXZ(r.pitch * WAIST_SHARE, r.yaw * WAIST_SHARE, 0))
	Additive.writeAdditive(r.neck, CFrame.fromEulerAnglesYXZ(r.pitch * (1 - WAIST_SHARE), r.yaw * (1 - WAIST_SHARE), 0))
end

local rigs: { LookRig } = {}
RunService.PreSimulation:Connect(function(dt)
	for _, r in rigs do updateLook(r, dt) end
end)
```

Notes:
- The axis convention assumes the R15 rig attachments are aligned with their parts (X right, Y up, -Z forward). If the head turns the wrong way on your rig, derive axes from the joint frame rather than flipping signs blindly.
- Splitting the turn between waist and neck reads much more natural than a neck alone, and avoids 70-degree neck twists. Shoulders can take a further share for full-body aim. See [[Look-At Aim and Head Tracking]].
- Any accessory part on the head that is not welded to it will not follow (measured). Weld hoods and helmets first.
- For a pure look-at with no custom logic, an `IKControl` of type `LookAt` does this with `SmoothTime` built in. See [[Snippets - IK]].

---

## 4. Recoil and impact kicks (spring impulse)

```lua
--!strict
-- Kick a joint by an angle that springs back. Add to `vel` on each shot; the spring returns to 0.
local kick = { angle = 0, vel = 0 }

local function fireRecoil(strength: number)     -- strength in rad/s of initial angular velocity
	kick.vel += strength
end

RunService.PreSimulation:Connect(function(dt)
	kick.angle, kick.vel = springWobble(kick.angle, kick.vel, 0, 28, 0.55, dt)   -- slight overshoot
	Additive.writeAdditive(rightShoulder, CFrame.Angles(kick.angle, 0, 0))       -- pitch the arm up
end)
```
A velocity impulse (rather than setting the angle) gives a natural "snap up, ease back" with one parameter. `w = 28, zeta = 0.55` returns in about 0.25 s with one small overshoot (rule of thumb; tune to taste).

---

## 5. Breathing and idle life (additive)

```lua
-- Breathing: a small chest pitch and shoulder lift, slower and smaller at rest, faster after effort.
local exertion = 0          -- 0..1, raise after sprinting or attacking, decays over time
local t = 0
RunService.PreSimulation:Connect(function(dt)
	exertion = math.max(0, exertion - dt * 0.15)                -- about 7 s to calm down
	local rate = 0.22 + 0.35 * exertion                         -- breaths per second
	local amp = math.rad(1.2 + 2.5 * exertion)
	t += dt * rate * 2 * math.pi
	local s = math.sin(t)
	Additive.writeAdditive(waist, CFrame.Angles(-amp * 0.5 * s, 0, 0))     -- chest rises, slight lean back
	Additive.writeAdditive(neck, CFrame.Angles(amp * 0.4 * s, 0, 0))       -- head counters so eyes stay level
end)
```
Countering the head is the detail that makes this read as breathing rather than bobbing. Keep it under about 2 degrees at rest; idle clips usually already breathe, so use this only on clips that do not (see [[Idle Breathing and Secondary Motion]]).

---

## 6. Lean into turns and acceleration

```lua
-- Lean the whole body into turns (roll) and into acceleration (pitch) through the Root joint.
local lastLook: Vector3? = nil
local lastVel = Vector3.zero
local roll, rollV, pitch, pitchV = 0, 0, 0, 0
local MAX_LEAN = math.rad(9)

RunService.PreSimulation:Connect(function(dt)
	local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	local vel = hrp.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local turnRate = 0
	if lastLook and look.Magnitude > 1e-3 and lastLook.Magnitude > 1e-3 then
		local a, b = lastLook.Unit, look.Unit
		turnRate = math.atan2(a:Cross(b).Y, a:Dot(b)) / dt          -- rad/s, + = turning left
	end
	local accel = hrp.CFrame:VectorToObjectSpace((vel - lastVel) / dt)  -- local acceleration
	lastLook, lastVel = look, vel

	local speedK = math.clamp(vel.Magnitude / 22, 0, 1)                -- no lean when standing
	-- +Z roll tilts the top toward -X (left), so a left turn (turnRate > 0) leans left
	local wantRoll = math.clamp(turnRate * 0.06 * speedK, -MAX_LEAN, MAX_LEAN)
	-- +X pitch tilts the top backward; forward acceleration has accel.Z < 0, giving a forward lean
	local wantPitch = math.clamp(accel.Z * 0.004, -MAX_LEAN, MAX_LEAN)
	roll, rollV = springCritical(roll, rollV, wantRoll, 12, dt)
	pitch, pitchV = springCritical(pitch, pitchV, wantPitch, 10, dt)
	Additive.writeAdditive(rootJoint, CFrame.Angles(pitch, 0, roll))
end)
```
Lean through the Root joint (HumanoidRootPart to LowerTorso), not the HumanoidRootPart itself: rotating the root part fights the Humanoid controller. A procedural gait in the reference project used +7 to +9 degrees of forward lean at speed.

---

## 7. Many floating, bobbing, spinning objects (one loop, BulkMoveTo)

```lua
--!strict
-- Pets, crystals, pickups. Anchored parts; one loop; one BulkMoveTo call; only near the camera.
local RunService = game:GetService("RunService")

type Floater = { part: BasePart, base: CFrame, phase: number }
local floaters: { Floater } = {}
local parts: { BasePart } = {}
local cframes: { CFrame } = {}
local RANGE = 250
local acc = 0

RunService.PreRender:Connect(function(dt)
	acc += dt
	if acc < 1 / 30 then return end         -- 30 Hz is plenty for ambient motion
	acc = 0
	local t = os.clock()
	local camPos = workspace.CurrentCamera.CFrame.Position
	table.clear(parts); table.clear(cframes)
	for _, f in floaters do
		if (f.base.Position - camPos).Magnitude > RANGE then continue end
		local bob = math.sin(t * 1.6 + f.phase) * 0.35
		local tilt = math.sin(t * 0.9 + f.phase) * math.rad(6)
		table.insert(parts, f.part)
		table.insert(cframes, f.base * CFrame.new(0, bob, 0) * CFrame.Angles(tilt, t * 0.8 + f.phase, 0))
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
```
Notes: for multi-part models, move a single anchored root part and weld the rest, or put every part in the list with its own offset. `BulkMoveTo` is worth it from tens of parts upward (Docs: use it when movement is a confirmed bottleneck). Measured project choices: foliage at 30 Hz near the camera; world pieces animated only within 280 to 900 studs depending on size.

---

## 8. Spinning a hinge with no clip (in sync on every client)

```lua
-- Orbiting shards, rotors, rings on a Motor6D. Phase from server time so every client agrees.
local spins = {
	{ motor = ringMotor, speed = math.rad(180), axis = Vector3.yAxis, phase = 0 },
}
RunService.PreSimulation:Connect(function()
	local t = workspace:GetServerTimeNow()
	for _, s in spins do
		local angle = (s.speed * t + s.phase) % (2 * math.pi)        -- keep the angle small for precision
		s.motor.Transform = CFrame.fromAxisAngle(s.axis, angle)
	end
end)
```
Setting `Transform` directly (not additively) is right here because nothing else animates these joints. Orbiting pieces stripped out of clips and spun in code are cheaper than keyed rotation (a full turn needs at least 3 keys per revolution to avoid the 180-degree ambiguity).

---

## 9. Tossing a held weapon (grip C0 parabola)

```lua
--!strict
-- Toss the blade up and catch it, moving the grip joint's C0. Runs on every client from shared data.
local G = 47.6   -- studs/s^2: 9.81 m/s^2 scaled to an 8.7-stud avatar, NOT workspace.Gravity

local function toss(grip: Motor6D, height: number, spins: number, onCaught: (() -> ())?)
	local home = grip.C0
	local v0 = math.sqrt(2 * G * height)            -- launch speed that peaks at `height`
	local flight = 2 * v0 / G
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.PreSimulation:Connect(function()
		local t = os.clock() - t0
		if t >= flight then
			conn:Disconnect()
			grip.C0 = home
			if onCaught then onCaught() end
			return
		end
		local y = v0 * t - 0.5 * G * t * t
		local u = t / flight
		local spin = spins * 2 * math.pi * (u * u * (3 - 2 * u))   -- smoothstep: slow release, slow catch
		grip.C0 = home * CFrame.new(0, y, 0) * CFrame.Angles(spin, 0, 0)
	end)
end
```
Why the custom `G`: a character 8.7 studs tall represents about 1.8 m, so real gravity is about 47.6 studs/s². `workspace.Gravity` (196.2 by default) makes a toss look like it was thrown on a heavier planet at character scale. The reference project's flourishes used this value and added a damped wrist "give" after the catch. Only use `C0` like this on a `Motor6D` you created; `C0` is read-only on `AnimationConstraint`.

---

## 10. Hinged lid or door (tweened angle)

```lua
--!strict
local TweenService = game:GetService("TweenService")

-- base: anchored part with a "Hinge" Attachment on the hinge line (X axis = hinge axis). lid: anchored.
local function makeLid(base: BasePart, lid: BasePart)
	local hinge = base:FindFirstChild("Hinge") :: Attachment
	local hingeCF = base.CFrame * hinge.CFrame
	local rest = hingeCF:ToObjectSpace(lid.CFrame)            -- lid relative to the hinge, captured once
	local angle = Instance.new("NumberValue")
	angle.Changed:Connect(function(deg: number)
		lid.CFrame = hingeCF * CFrame.Angles(-math.rad(deg), 0, 0) * rest
	end)
	local function open()
		TweenService:Create(angle, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 72 }):Play()
	end
	local function close()
		TweenService:Create(angle, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 0 }):Play()
	end
	return open, close
end
```
The `Back` overshoot goes past the target. Check the whole range the tween can reach: in the reference project the lid swept from -2 to 115.5 degrees with Back easing, and the -2 had to be checked so the lid never dipped into its plinth. Add a small "thud" bounce on close as a separate short tween.

---

## 11. Server-synchronised one-off motion

```lua
-- Server: announce. Value encodes who, which effect, and a serial so the same effect can retrigger.
model:SetAttribute("SpinFx", ("%d:%d:%d"):format(userId, effectIndex, serial))
model:SetAttribute("SpinFxT0", workspace:GetServerTimeNow())

-- Client: play from the start time, so late joiners and laggy clients land on the same pose.
local function quartInOut(u: number): number
	if u < 0.5 then return 8 * u ^ 4 end
	return 1 - (-2 * u + 2) ^ 4 / 2
end

model:GetAttributeChangedSignal("SpinFx"):Connect(function()
	local t0 = model:GetAttribute("SpinFxT0") :: number
	local DURATION = 4.4
	local base = model:GetPivot()
	local conn: RBXScriptConnection
	conn = RunService.PreRender:Connect(function()
		local u = math.clamp((workspace:GetServerTimeNow() - t0) / DURATION, 0, 1)
		model:PivotTo(base * CFrame.Angles(0, 2 * math.pi * quartInOut(u), 0))
		if u >= 1 then conn:Disconnect() end
	end)
end)
```
Set `SpinFxT0` before `SpinFx` so the client reads the right start time when the change signal fires (attribute changes made together replicate together in practice, but ordering your writes costs nothing).

---

## 12. Squash and stretch on spawn

```lua
local function squashIn(part: BasePart)
	local size = part.Size
	part.Size = size * Vector3.new(1.3, 0.6, 1.3)          -- volume roughly preserved
	TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size }):Play()
end
```
For models, tween a NumberValue and call `Model:ScaleTo` on change, or scale a single mesh part. Avoid squash on rigs with joints: resizing parts moves joint pivots.

---

## Common mistakes
- Writing joints in `PreRender`/`Heartbeat` (overwritten by the next animation step).
- Compounding `Transform = Transform * offset` (winds up on throttled or unkeyed frames).
- Per-frame smoothing with a constant factor (`x += (t - x) * 0.2`), which changes with frame rate.
- One `RunService` connection per object instead of one loop over a list.
- Using `workspace.Gravity` for character-scale flourishes.
- `os.clock()` for motion that must match across clients; use `workspace:GetServerTimeNow()`.

## See also
[[Procedural Animation]] · [[Springs Damping and Smoothing]] · [[Look-At Aim and Head Tracking]] · [[Procedural Weapon Motion]] · [[Tween and CFrame Animation of Objects]] · [[Frame Order and RunService Timing]] · [[Snippets - IK]] · [[Animation LOD]]

## Nuances and edge cases

1. **Replication of procedural joints.** `Motor6D.Transform` written on a client is local to that client. For your own character, other players will not see your look-at or lean unless every viewer computes it too. The usual pattern: replicate a compact input (look direction as two angles, quantised to about 1 degree, sent at 10 to 20 Hz when it changes) and let every client run the same procedural code. At 50 players that is still small; at 700-player servers, send it only to clients within a radius.
2. **Server-side procedural motion is usually wrong.** Writing `Transform` on the server for a player's character competes with the owner's Animator and arrives late. Server writes make sense only for server-owned props (lids, doors, spinners), and even those look smoother when each client animates them from a shared start time.
3. **Springs at extreme frame rates.** An analytic or substepped spring is stable from 20 to 240 FPS. A naive semi-implicit Euler spring with high stiffness explodes when a phone hitches to a 200 ms frame. Clamp `dt` (for example to 1/20 s) before stepping, and substep if you must use high stiffness.
4. **Hitches and pauses.** When a client alt-tabs on PC or backgrounds the app on mobile, the next frame can carry a `dt` of several seconds. Unclamped bobbing jumps phase visibly; unclamped springs fly away. Clamp `dt` for all procedural motion, and resync time-based motion from `GetServerTimeNow`.
5. **BulkMoveTo and streaming.** One loop moving 500 pickups with `workspace:BulkMoveTo` is cheap, but with StreamingEnabled some of those parts may be streamed out on a given client. Iterate a list that you add to and remove from on stream in and out (CollectionService tags plus `GetInstanceAddedSignal` handle this well), rather than a list built once at start.
6. **Anchored vs physics props.** Bobbing an anchored part with CFrame does not push players standing on it; they slide off or clip. If players stand on it, use a constraint-driven platform or move the floor and carry the player explicitly.
7. **Look-at on other players and privacy of input.** Replicating the exact camera direction reveals where a player looks, which matters in hide-and-seek or horror. Replicate only when the look-at is meant to be visible, or blur it (lower rate, coarser angles).
8. **Layering with layered clothing.** Large procedural lean or spine twist can push layered clothing cages past what they were authored for. Keep added spine rotation modest (rule of thumb: under about 20 degrees on top of the clip).

## Common mistakes in production

1. **Unclamped `dt`.** Symptom: props jump or springs fling after a hitch or tab-out. Fix: clamp `dt` before any integration.
2. **Procedural motion on far characters at full rate.** Symptom: frame time grows with player count. Fix: skip or reduce updates beyond a distance and off screen.
3. **Sending look direction every frame.** Symptom: high client send rate in the network stats. Fix: quantise, send on change, cap at 10 to 20 Hz.
4. **One spring module instance per prop with its own connection.** Symptom: hundreds of connections in the MicroProfiler. Fix: a single stepper updating a list of springs.
5. **Tween-driven doors players collide with.** Symptom: players get stuck or launched. Fix: open doors toward the direction players are not standing, or switch to a hinge constraint with a servo.

## Related decisions

- [[Interpolation Easing and Curves Math]]: the maths behind easing and smoothing curves used here.
- [[Rotations Angles and Quaternions]]: clamping and blending rotations without flips.
- [[Squash Stretch and Anticipation in UI and Characters]]: the design side of the squash on spawn.
- [[Network Bandwidth Budgets and Measuring Them]]: budgeting the replicated look direction.
- [[Instance Streaming]]: keeping the bobbing list correct as parts stream in and out.
- [[CollectionService Patterns]]: tagging procedural props so one loop finds them.
- [[Mover Constraints and Physics Controllers]]: when a moving platform must carry players physically.
- [[Script Performance]]: measuring the per-frame cost of procedural loops.
- [[Genre Playbook - Horror and Story]]: where replicated look direction becomes a gameplay leak.

## Connected notes
<!-- auto-links:start -->
[[Tween vs Spring]] · [[Rigs and Joints]] · [[Motor6D Math and CFrame Composition]] · [[Custom Rigs - Weapons and Props]] · [[UI Motion Language and Timing]] · [[Cookbook - Math CFrame and Vectors]] · [[Animation Start Here]]
<!-- auto-links:end -->
