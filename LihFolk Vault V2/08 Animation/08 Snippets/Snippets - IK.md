---
tags: [snippets, luau, ik, procedural, type/reference, area/animation, level/advanced, api/IKControl, area/scripting, api/Humanoid, api/AnimationConstraint]
---
# Snippets: IK

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Reading `Part.CFrame` in `PreSimulation` for the chain parent (one frame behind).
> - Avoid: Targets past full reach (snaps and flips at the singular straight pose).
> - Avoid: A pole on the limb line (undefined bend plane).
>
> Cost: TL;DR ~100 tok · whole note ~7.1k tok. Read more: ## 1. IKControl setups · ## 5. Foot IK during locomotion (pelvis drop, ground normal, blend) · ## Common mistakes
<!-- tldr:end -->

Two ways to do inverse kinematics on Roblox rigs, with working code for each:

1. **The engine's `IKControl`**: declarative, solved by the engine, smoothing built in. Best for look-at, a hand reaching for a handle, an off-hand on a two-handed grip, and feet on uneven ground while standing.
2. **Your own analytic two-bone solver** writing joint `Transform`s: full control over elbow and knee direction, hinge limits, blending and timing. Best for foot planting during locomotion, aim offsets, and anything you also need offline (bakers, QA).

The maths is derived in [[Two-Bone IK Math]]; pole and limit design in [[Elbow Poles Swivel and Joint Limits]]; ground work in [[Foot Placement and Ground IK]]; the API in [[IKControl Reference]].

---

## 1. IKControl setups

Facts from the docs that matter here:
- An `IKControl` must be a child of a `Humanoid` or `AnimationController` that has an `Animator`, and needs `Type`, `EndEffector`, `Target` and `ChainRoot` set before it does anything.
- It overrides the animation for every part between `ChainRoot` and `EndEffector`.
- `Type`: `Transform` (position and rotation), `Position`, `Rotation`, `LookAt`.
- `Pole` is optional; when nil, the solver picks a bend for recognised arm (upper arm to hand) and leg (upper leg to foot) chains. Other chains may bend unexpectedly without one.
- `Weight` 0..1 blends with the animation (default 1), but even at 0 `SmoothTime` and `Pole` can still affect the pose: use `Enabled = false` to turn it off fully.
- `SmoothTime` (default 0.05 s) is a critically damped approach to the target; 0 disables smoothing.
- `Priority`: higher values are solved later and can override earlier controls.
- `ChainRoot` should not be the character's actual root.

### Hand to a point (door handle, lever, wall touch)
```lua
--!strict
local function reachFor(character: Model, side: "Left" | "Right", targetAttachment: Attachment): IKControl
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local ik = Instance.new("IKControl")
	ik.Name = side .. "HandReach"
	ik.Type = Enum.IKControlType.Transform               -- position AND rotation of the hand
	ik.ChainRoot = character:FindFirstChild(side .. "UpperArm") :: BasePart
	ik.EndEffector = character:FindFirstChild(side .. "Hand") :: BasePart
	ik.Target = targetAttachment                         -- an Attachment on the handle, oriented like the palm
	ik.SmoothTime = 0.08
	ik.Weight = 0
	ik.Parent = humanoid
	return ik
end

-- Fade in and out instead of popping
local TweenService = game:GetService("TweenService")
local ik = reachFor(character, "Right", door.Handle.GripAttachment)
TweenService:Create(ik, TweenInfo.new(0.25, Enum.EasingStyle.Sine), { Weight = 1 }):Play()
-- later
TweenService:Create(ik, TweenInfo.new(0.2, Enum.EasingStyle.Sine), { Weight = 0 }):Play()
```
To make a specific point of the hand reach the target (fingertips, palm centre) set `EndEffector` to an `Attachment` on the hand, or use `EndEffectorOffset`.

### Off-hand on a two-handed weapon
```lua
-- The weapon is held by the right hand; the left hand follows a grip attachment on the weapon.
local leftGrip = Instance.new("IKControl")
leftGrip.Type = Enum.IKControlType.Transform
leftGrip.ChainRoot = character.LeftUpperArm
leftGrip.EndEffector = character.LeftHand
leftGrip.Target = weapon.Handle:FindFirstChild("OffHandGrip") :: Attachment
leftGrip.Pole = character.UpperTorso:FindFirstChild("LeftElbowPole") :: Attachment   -- behind and below the elbow
leftGrip.SmoothTime = 0                             -- the hand must stay ON the hilt, no lag
leftGrip.Priority = 1                               -- solved after other controls
leftGrip.Parent = character.Humanoid
```
Design notes from the reference project (which baked this instead of solving at runtime): the off hand sat 1.15 studs below the sword hand along the blade, rolled 180 degrees about it, and **let go of the hilt wherever holding it would bury the arm in the body**. A runtime [[IKControl]] cannot know that, so fade its `Weight` to 0 during moves that turn the blade across the chest, or the forearm will clip through the torso. See [[Weapon and Combat Animation]].

### Head look-at
```lua
local look = Instance.new("IKControl")
look.Type = Enum.IKControlType.LookAt
look.ChainRoot = character.UpperTorso                -- torso + neck share the turn
look.EndEffector = character.Head
look.Target = lookTargetAttachment                   -- move this attachment to what the character looks at
look.Weight = 0.7                                    -- partial: keeps some of the animated head motion
look.SmoothTime = 0.15                               -- heads lag a little; feels alive
look.Parent = character.Humanoid
```
Clamp the target yourself (keep it within about 70 degrees of the torso's forward) by moving the attachment, since the control will happily twist past anatomical limits.

### Feet on uneven ground while standing
```lua
--!strict
-- Standing foot planting with IKControl: raycast under each hip, put a world-space attachment on the
-- ground, fade the control in only while the character is (nearly) still and grounded.
local RunService = game:GetService("RunService")

local function footIK(character: Model, side: "Left" | "Right")
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hipAtt = (character:FindFirstChild("LowerTorso") :: BasePart):FindFirstChild(side .. "HipRigAttachment") :: Attachment
	local foot = character:FindFirstChild(side .. "Foot") :: BasePart

	local target = Instance.new("Attachment")              -- under Terrain = world space
	target.Name = character.Name .. side .. "FootTarget"
	target.Parent = workspace.Terrain

	local ik = Instance.new("IKControl")
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = character:FindFirstChild(side .. "UpperLeg") :: BasePart
	ik.EndEffector = foot
	ik.Target = target
	ik.SmoothTime = 0.06
	ik.Weight = 0
	ik.Parent = humanoid

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local conn = RunService.PreSimulation:Connect(function(dt)
		local hip = hipAtt.WorldPosition
		local hit = workspace:Raycast(hip, Vector3.new(0, -6, 0), params)
		local speed = (humanoid.RootPart :: BasePart).AssemblyLinearVelocity.Magnitude
		local want = (hit and speed < 1 and humanoid.FloorMaterial ~= Enum.Material.Air) and 1 or 0
		if hit then
			target.WorldPosition = hit.Position + Vector3.new(0, foot.Size.Y * 0.5, 0)   -- ankle above the contact
		end
		ik.Weight += (want - ik.Weight) * (1 - math.exp(-10 * dt))
	end)
	character.Destroying:Once(function() conn:Disconnect(); target:Destroy() end)
end
```
Limits of this simple version: it keeps the hips where the animation put them, so a foot on a lower step cannot reach (the leg straightens and stops short). Real foot IK also lowers the pelvis by the lowest foot's drop; the manual solver in section 3 does this.

---

## 2. Analytic two-bone solver (positions)

Given the root joint position `S` (shoulder or hip), bone lengths `a` (upper) and `b` (lower), a target `T` for the end joint (wrist or ankle) and a pole point `P` that says which way the middle joint should point, find the middle joint `E`:

```lua
--!strict
-- Returns middle joint position E, end position W (T clamped into reach), and the bend-plane normal.
local function solveTwoBone(S: Vector3, T: Vector3, a: number, b: number, P: Vector3, fallbackAxis: Vector3)
	local d = T - S
	local dist = d.Magnitude
	local dir = dist > 1e-6 and d / dist or -Vector3.yAxis
	-- keep the target strictly inside reach: straight-arm (a+b) and fully-folded |a-b| are singular
	dist = math.clamp(dist, math.abs(a - b) + 1e-3, a + b - 1e-3)
	local W = S + dir * dist

	-- law of cosines: distance along the S->W line to the foot of the middle joint, and its height
	local along = (a * a - b * b + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(a * a - along * along, 0))

	-- pole direction: the part of (P - S) perpendicular to the limb line
	local toPole = P - S
	local perp = toPole - dir * toPole:Dot(dir)
	if perp.Magnitude < 1e-4 then                           -- pole on the line: use a fixed fallback
		perp = fallbackAxis - dir * fallbackAxis:Dot(dir)
	end
	local poleDir = perp.Unit

	local E = S + dir * along + poleDir * h
	local normal = poleDir:Cross(dir).Unit                 -- bend-plane normal, stable even when straight
	return E, W, normal
end
```

Why `normal = poleDir:Cross(dir)`: the exact plane normal is `(E - S):Cross(W - E)`, which simplifies to `h * dist * poleDir:Cross(dir)`. Using the simplified form keeps the normal well defined as the limb straightens (`h` goes to 0), which is exactly where naive solvers flip.

---

## 3. From positions to joint Transforms (R15 arm or leg)

The robust way to turn `E` and `W` into rotations: build an orthonormal frame from "bone direction + hinge axis" in the part's **rest** space and in **world** space, and rotate one onto the other. This works on slanted R15 bones, with Motor6D or [[AnimationConstraint]] joints, and never inverts the elbow, because the hinge axis is pinned to the bend-plane normal.

```lua
--!strict
type JointInfo = { joint: any, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame }

local function info(j: any): JointInfo
	if j:IsA("Motor6D") then
		return { joint = j, part0 = j.Part0, part1 = j.Part1, c0 = j.C0, c1 = j.C1 }
	end
	-- AnimationConstraint: frames are its attachments
	return { joint = j, part0 = j.Attachment0.Parent, part1 = j.Attachment1.Parent,
		c0 = j.Attachment0.CFrame, c1 = j.Attachment1.CFrame }
end

local function transformFor(j: JointInfo, part0CF: CFrame, part1CF: CFrame): CFrame
	return (part0CF * j.c0):Inverse() * part1CF * j.c1
end

-- rotation-only frame with Y along `bone` and X as close to `normal` as possible
local function frameOf(bone: Vector3, normal: Vector3): CFrame
	local y = bone.Unit
	local x = (normal - y * normal:Dot(y)).Unit
	return CFrame.fromMatrix(Vector3.zero, x, y)          -- Z = X cross Y (right-handed)
end

export type Limb = {
	upper: JointInfo, lower: JointInfo, tip: JointInfo,
	hinge: Vector3,               -- hinge axis in the limb parts' own space: +X for R15 arms, -X for R15 legs
	a: number, b: number,
	sU: Vector3, eU: Vector3,     -- root and middle pivots, in the upper part's space
	eL: Vector3, wL: Vector3,     -- middle and end pivots, in the lower part's space
	tipC1: Vector3,               -- end pivot in the tip part's space
}

local function makeLimb(upperJoint: any, lowerJoint: any, tipJoint: any, hinge: Vector3): Limb
	local u, l, t = info(upperJoint), info(lowerJoint), info(tipJoint)
	local sU, eU = u.c1.Position, l.c0.Position           -- C1 = pivot seen from Part1, C0 = pivot seen from Part0
	local eL, wL = l.c1.Position, t.c0.Position
	return { upper = u, lower = l, tip = t, hinge = hinge,
		a = (eU - sU).Magnitude, b = (wL - eL).Magnitude,
		sU = sU, eU = eU, eL = eL, wL = wL, tipC1 = t.c1.Position }
end

-- parentCF: world CFrame of the upper joint's Part0 THIS frame (UpperTorso for arms, LowerTorso for legs).
-- target: where the end pivot (wrist/ankle) should go. pole: a world point the elbow/knee should point toward.
-- tipRot: optional world rotation for the hand/foot; nil leaves its animated Transform alone.
-- Returns the three Transforms (or nil for the tip).
local function solveLimb(limb: Limb, parentCF: CFrame, target: Vector3, pole: Vector3, tipRot: CFrame?)
	local S = (parentCF * limb.upper.c0).Position          -- root pivot (shoulder/hip)
	local E, W, n = solveTwoBone(S, target, limb.a, limb.b, pole, parentCF.LookVector)

	local upperRot = frameOf(E - S, n) * frameOf(limb.eU - limb.sU, limb.hinge):Inverse()
	local upperCF = CFrame.new(S) * upperRot * CFrame.new(-limb.sU)       -- keeps the root pivot at S
	local lowerRot = frameOf(W - E, n) * frameOf(limb.wL - limb.eL, limb.hinge):Inverse()
	local lowerCF = CFrame.new(E) * lowerRot * CFrame.new(-limb.eL)       -- middle pivot at E, end pivot at W

	local tUpper = transformFor(limb.upper, parentCF, upperCF)
	local tLower = transformFor(limb.lower, upperCF, lowerCF)
	local tTip: CFrame? = nil
	if tipRot then
		local tipCF = CFrame.new(W) * tipRot.Rotation * CFrame.new(-limb.tipC1)
		tTip = transformFor(limb.tip, lowerCF, tipCF)
	end
	return tUpper, tLower, tTip
end
```

Hinge sign, worked out (for R15 rigs whose rig attachments are aligned with their parts):
- **Arm**, hanging down (`dir = -Y`) with the pole behind (`+Z`): `poleDir:Cross(dir) = (0,0,1) x (0,-1,0) = (1,0,0)`. So `hinge = +X` maps the arm's rest X onto world X with no twist, and the elbow bends the forearm forward.
- **Leg**, with the pole in front of the knee (`-Z`): `(0,0,-1) x (0,-1,0) = (-1,0,0)`. So `hinge = -X`.
If your rig's elbow inverts, flip that limb's hinge sign; do not flip the pole.

Using it on a character arm:

```lua
local char = player.Character
local rightArm = makeLimb(char.RightUpperArm.RightShoulder, char.RightLowerArm.RightElbow,
	char.RightHand.RightWrist, Vector3.xAxis)
-- AnimationConstraint rigs: find the joints with FindFirstChildWhichIsA("AnimationConstraint") per part.

RunService.PreSimulation:Connect(function()
	local torsoCF = upperTorsoWorldCF()                  -- see section 4: FK from the root, this frame
	local pole = (torsoCF * CFrame.new(1.5, -1, 1.5)).Position   -- behind, below and outside the right elbow
	local tU, tL, tT = solveLimb(rightArm, torsoCF, aimPoint, pole, nil)
	rightArm.upper.joint.Transform = tU
	rightArm.lower.joint.Transform = tL
end)
```
Pole choice is most of the art: the reference project's arm baker preferred elbows "down 1.0, out 0.45, back 0.35" by default, more outward with the hand above the shoulder, more forward with the hand across the body, and penalised "chicken wings" (elbow high while the hand hangs below it). See [[Elbow Poles Swivel and Joint Limits]].

---

## 4. Getting this frame's parent CFrame

In `PreSimulation` the Animator has already written this frame's `Transform`s, but the parts have not moved yet: `UpperTorso.CFrame` still holds last frame's physics result. An IK hand computed from it lags one frame behind the body, which shows as a hand sliding off a target during fast turns. Compute the chain by FK instead:

```lua
-- World CFrame of a part this frame, walking joints from the HumanoidRootPart using current Transforms.
-- path: joints from the root outward, e.g. { Root, Waist } for UpperTorso.
local function chainCF(rootCF: CFrame, path: { any }): CFrame
	local cf = rootCF
	for _, j in path do
		local ji = info(j)
		cf = cf * ji.c0 * j.Transform * ji.c1:Inverse()
	end
	return cf
end

local function upperTorsoWorldCF(): CFrame
	local hrp = char.HumanoidRootPart
	-- predict the root to where physics will put it this frame (reduces foot/hand slide at speed)
	local dt = 1 / 60
	local rootCF = hrp.CFrame + hrp.AssemblyLinearVelocity * dt
	return chainCF(rootCF, { char.LowerTorso.Root, char.UpperTorso.Waist })
end
```
The velocity prediction is a rule of thumb: the Humanoid moves the root during the physics step that follows. At 16 studs/s and 60 fps the root moves about 0.27 studs per frame, which is visible as foot slide if ignored.

---

## 5. Foot IK during locomotion (pelvis drop, ground normal, blend)

```lua
--!strict
-- Runs after the Animator. Keeps each foot on the ground under where the animation put it,
-- lowers the pelvis for the lower foot, tilts feet to the ground normal, and fades out in the air.
local RunService = game:GetService("RunService")

local MAX_DROP = 1.2                -- studs the pelvis may drop (rule of thumb: about a third of leg length)
local MAX_TILT = math.rad(30)
local RAY_UP, RAY_DOWN = 2.0, 3.0

local function setupFootIK(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
	local rootJ = (char:FindFirstChild("LowerTorso") :: BasePart):FindFirstChild("Root") :: any
	local legs = {}
	for _, side in { "Left", "Right" } do
		local upperLeg = char:FindFirstChild(side .. "UpperLeg") :: BasePart
		local lowerLeg = char:FindFirstChild(side .. "LowerLeg") :: BasePart
		local foot = char:FindFirstChild(side .. "Foot") :: BasePart
		table.insert(legs, makeLimb(
			upperLeg:FindFirstChild(side .. "Hip"), lowerLeg:FindFirstChild(side .. "Knee"),
			foot:FindFirstChild(side .. "Ankle"), -Vector3.xAxis))
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	local weight, drop, dropV = 0, 0, 0

	return RunService.PreSimulation:Connect(function(dt)
		-- 1. animated pose this frame (Transforms just written by the Animator)
		local rootCF = hrp.CFrame + hrp.AssemblyLinearVelocity * dt
		local rootBase = rootJ.Transform
		local lowerTorsoCF = chainCF(rootCF, { rootJ })

		-- 2. ground under each animated ankle
		local plans = {}
		local lowest = 0
		for i, leg in legs do
			local hipCF = lowerTorsoCF
			local upperCF = hipCF * leg.upper.c0 * leg.upper.joint.Transform * leg.upper.c1:Inverse()
			local lowerCF = upperCF * leg.lower.c0 * leg.lower.joint.Transform * leg.lower.c1:Inverse()
			local ankle = (lowerCF * CFrame.new(leg.wL)).Position       -- end pivot (wL) in world space
			local footCF = lowerCF * leg.tip.c0 * leg.tip.joint.Transform * leg.tip.c1:Inverse()
			-- animated ankle height above the floor the Humanoid stands on
			local floorY = rootCF.Position.Y - hum.HipHeight - hrp.Size.Y / 2
			local lift = ankle.Y - floorY
			local hit = workspace:Raycast(ankle + Vector3.new(0, RAY_UP, 0), Vector3.new(0, -(RAY_UP + RAY_DOWN), 0), params)
			if hit then
				local want = hit.Position.Y + lift
				lowest = math.min(lowest, want - ankle.Y)
				plans[i] = { leg = leg, target = Vector3.new(ankle.X, want, ankle.Z), normal = hit.Normal, footRot = footCF.Rotation }
			end
		end

		-- 3. blend weight: on in contact, off in the air
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		weight += ((grounded and 1 or 0) - weight) * (1 - math.exp(-12 * dt))
		if weight < 1e-3 then return end

		-- 4. pelvis drop (springed so steps do not pop), applied through the Root joint
		local wantDrop = math.max(lowest, -MAX_DROP)
		drop, dropV = springCritical(drop, dropV, wantDrop, 18, dt)
		rootJ.Transform = CFrame.new(0, drop * weight, 0) * rootBase
		lowerTorsoCF = chainCF(rootCF, { rootJ })

		-- 5. solve each leg, knee pole in front of the knee
		for _, plan in plans do
			local leg = plan.leg
			local pole = (lowerTorsoCF * CFrame.new(0, -1.5, -3)).Position
			local tilt = Vector3.yAxis:Cross(plan.normal)
			local ang = math.min(math.asin(math.clamp(tilt.Magnitude, 0, 1)), MAX_TILT)
			local footRot = (tilt.Magnitude > 1e-4 and CFrame.fromAxisAngle(tilt.Unit, ang) or CFrame.identity) * plan.footRot
			local tU, tL, tT = solveLimb(leg, lowerTorsoCF, plan.target, pole, footRot)
			-- blend from the animated pose by weight (CFrame:Lerp is fine for blending small corrections)
			leg.upper.joint.Transform = leg.upper.joint.Transform:Lerp(tU, weight)
			leg.lower.joint.Transform = leg.lower.joint.Transform:Lerp(tL, weight)
			if tT then leg.tip.joint.Transform = leg.tip.joint.Transform:Lerp(tT, weight) end
		end
	end)
end
```

This uses `makeLimb`, `solveLimb` and `chainCF` from sections 3 and 4, and `springCritical` from [[Snippets - Procedural Motion]].

Caveats and design notes:
- **Compounding.** This reads `Transform` as the animated base. If no track keys the legs on some frame (or the Animator is throttled), the base is last frame's IK result and the correction compounds. Use the base-tracking layer from [[Snippets - Procedural Motion]] when that can happen.
- **Swing feet.** Only plant feet that the animation has near the ground. A simple test: apply the full correction when the animated ankle is within about 0.3 studs of the floor, fade it toward zero as the foot lifts.
- **Slopes and stairs.** The pelvis drop handles stepping down. Stepping up needs no drop; the leg simply bends more.
- **Network.** Run foot IK on every client for every visible character, at a reduced LOD for distant ones ([[Animation LOD]]). It is cosmetic; never replicate it.
- **Reference data.** A procedural gait in the reference project solved legs with 3D two-bone IK on the joints' own attachments and measured near-zero foot slide from 12 to 120 studs/s; a later foot-plant layer for authored clips measured 0.00 to 0.01 studs/s slide (but shipped switched off). See [[Procedural Gait and Footstep Planning]].

---

## 6. Joint limits after solving

An analytic two-bone solve never inverts the middle joint, but it can still produce impossible wrists, shoulders far behind the back, or knees that hyperextend when the target is too close. Clamp after solving, by splitting the rotation into **twist** (about the bone's own axis) and **swing** (everything else, `rot = swing * twist`):

```lua
local function quat(cf: CFrame): (number, number, number, number)
	local axis, angle = cf:ToAxisAngle()
	local s = math.sin(angle / 2)
	return axis.X * s, axis.Y * s, axis.Z * s, math.cos(angle / 2)
end
local function fromQuat(x: number, y: number, z: number, w: number): CFrame
	local len = math.sqrt(x * x + y * y + z * z + w * w)
	if len < 1e-9 then return CFrame.identity end
	return CFrame.new(0, 0, 0, x / len, y / len, z / len, w / len)
end

-- Limit `rot` (a joint Transform rotation): swing within maxSwing radians, twist about `axis` within [minTwist, maxTwist].
local function clampJoint(rot: CFrame, axis: Vector3, maxSwing: number, minTwist: number, maxTwist: number): CFrame
	local x, y, z, w = quat(rot)
	local proj = axis * (x * axis.X + y * axis.Y + z * axis.Z)          -- vector part projected on the twist axis
	local twist = fromQuat(proj.X, proj.Y, proj.Z, w)
	local swing = rot * twist:Inverse()
	local tAxis, tAngle = twist:ToAxisAngle()
	if tAxis:Dot(axis) < 0 then tAngle = -tAngle end                  -- signed twist about `axis`
	if tAngle > math.pi then tAngle -= 2 * math.pi end
	tAngle = math.clamp(tAngle, minTwist, maxTwist)
	local sAxis, sAngle = swing:ToAxisAngle()
	sAngle = math.min(sAngle, maxSwing)
	return CFrame.fromAxisAngle(sAxis, sAngle) * CFrame.fromAxisAngle(axis, tAngle)
end
```
Limits used by the reference project's wrist: flex 70, deviation 30, twist 85 degrees in bakes (QA flags at 75 / 40 / 95). Clamp twist **continuously**: unwrap it against last frame's value first, so a twist past the limit holds at the limit instead of flipping to the other side (+85 to -85 in one frame reads as a pop).
---

## Common mistakes
- Reading `Part.CFrame` in `PreSimulation` for the chain parent (one frame behind).
- Targets past full reach (snaps and flips at the singular straight pose). Clamp just short.
- A pole on the limb line (undefined bend plane). Always have a fallback axis.
- Flipping pole signs to fix an inverted elbow; fix the hinge axis sign.
- IKControl `Weight = 0` expecting it to be off (use `Enabled`).
- Off-hand IK that holds a hilt through the chest during cross-body swings.
- Runtime IK for things that could be baked: if the target is fixed relative to the body (a weapon grip), bake it into the clip and keep runtime IK for world contact.

## See also
[[Inverse Kinematics]] · [[IKControl Reference]] · [[Two-Bone IK Math]] · [[Multi-Bone IK - FABRIK and CCD]] · [[Elbow Poles Swivel and Joint Limits]] · [[Foot Placement and Ground IK]] · [[Arm Baker Internals]] · [[Snippets - Procedural Motion]]

## Nuances and edge cases

1. **IKControl replication.** An `IKControl` created and driven on a client affects only that client's view unless every viewer has the same IKControl with the same target. For a player's own character, the usual pattern is to create IKControls on every client for every visible character and replicate only the target (a position or an attribute naming a part). The engine solves locally on each machine; you replicate intent, not results.
2. **Cost scales with rigs, not with IK nodes per rig.** One IKControl on one rig is cheap. Foot IK on every character in a 50-player server means 100 leg solves plus 50 to 100 raycasts per frame on each client. That is affordable on desktop; on low-end phones, disable foot IK beyond a short distance (rule of thumb: 30 to 50 studs) and for characters off screen.
3. **Raycasts against other characters.** Foot rays that hit another player's limbs make feet climb onto heads in crowded spaces. Use a `RaycastParams` filter that excludes characters (a collision group or a filter list updated on join and leave).
4. **Moving platforms.** A planted-foot lock stored in world space slides when the floor moves. Store locks in the floor part's local space (`floor.CFrame:PointToObjectSpace`) and convert back each frame.
5. **Avatar proportions.** Leg lengths vary with avatar body type and scale. A pelvis-drop limit tuned on the default rig (for example 1 stud) is too much for a short avatar and too little for a tall one. Express limits as a fraction of leg length measured at runtime from the joint offsets.
6. **Hip height and the Humanoid.** The Humanoid holds the root at `HipHeight` above ground. Dropping the pelvis for foot IK changes the visible hip, not the physical root; large drops make the character look like it is sinking into slopes while its collision stays put. Keep drops small and accept some floating on steep terrain.
7. **Layered clothing and accessories.** IK that bends knees or elbows past authored poses can show cage clipping on layered clothing. Clamp joint angles (section 6) to ranges that the clothing was tested with.
8. **Server-side IK.** Server IK is rarely needed. If hit detection depends on arm positions (a grab move that reaches toward a target), compute the reach from data and geometry, not from a solved arm, so the server does not depend on client-side poses.

## Common mistakes in production

1. **IKControl created only on the owner's client.** Symptom: other players see the hand floating instead of on the handle. Fix: create the same IKControl on every client, replicate the target.
2. **Foot IK running while airborne.** Symptom: legs stretch toward the ground during jumps. Fix: blend IK weight to 0 when the Humanoid state is Freefall or Jumping, over about 0.1 s.
3. **Snapping IK weight on and off.** Symptom: a visible pop when a hand grabs or releases. Fix: tween `Weight` (or your blend factor) over 0.1 to 0.2 s, and use `Enabled` only once weight is 0.
4. **Rays from the foot bone rather than from above the foot.** Symptom: feet fall through thin floors and step edges. Fix: cast from about knee height down past the sole.
5. **No distance LOD.** Symptom: frame time grows linearly with player count in crowded hubs. Fix: disable IK beyond a distance and off screen.

## Related decisions

- [[Raycasts Shapecasts and Spatial Queries]]: building the foot rays and their filters.
- [[Avatar Body Types and Scale in Gameplay]]: why IK limits must adapt to avatar proportions.
- [[Collision and Physics Geometry]]: which surfaces feet should and should not plant on.
- [[Mover Constraints and Physics Controllers]]: moving platforms that foot locks must follow.
- [[Mobile and Low-End Optimization]]: setting IK distance cutoffs per device.
- [[Characters and Humanoids]]: hip height and Humanoid states that IK must respect.
- [[Hitboxes and Hit Detection]]: keeping server hits independent of client-solved limbs.
- [[Layered Clothing Creation Workflow]]: where joint angle limits for clothing come from.

## Connected notes
<!-- auto-links:start -->
[[Troubleshooting Table]] · [[Animation Glossary]] · [[Spec-Driven Move Authoring]] · [[Animation Quality Standard]] · [[Official Docs - Characters and Animation]] · Voxel Characters - Proportions Joints and Rigging · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Procedural Animation]] · [[Snippets - Ragdoll]] · [[R15 Run Cycle Key Poses]] · [[Look-At Aim and Head Tracking]] · [[LihFolk R15 Keyframe Pipeline]] · [[Posing and Silhouettes]] · [[Arm QA Metrics Reference]] · [[Snippets - Lua Keyframe Player Core]]
<!-- related:end -->
