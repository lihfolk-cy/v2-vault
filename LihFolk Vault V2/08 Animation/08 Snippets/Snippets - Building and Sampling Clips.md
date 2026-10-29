---
tags: [snippets, luau, keyframesequence, fk, sampling, easing, type/reference, area/animation, level/intermediate, api/KeyframeSequence, area/scripting, api/Animator]
---
# Snippets: Building and Sampling Clips

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Sampling with `CFrame:Lerp` and trusting it on big turns.
> - Avoid: Putting easing on the destination key.
> - Avoid: Keying the top-level root pose.
>
> Cost: TL;DR ~80 tok · whole note ~8.0k tok. Read more: ## 4. Building a KeyframeSequence from a table · ## 6. Sampling a KeyframeSequence like the Animator · ## Common mistakes
<!-- tldr:end -->

Code for working with clip data directly: forward kinematics over any rig, pose helpers, building a `KeyframeSequence` from a table, sampling a `KeyframeSequence` at any time **the way the Animator does** (rotation vectors or nlerp, the measured easing curves including reversed legacy Cubic), posing an anchored mannequin for filmstrips, Studio stepping, and the compact binary encoding used for clip stubs.

The measured behaviour these samplers reproduce is described in [[How the Animator Really Behaves]] and [[Keyframes, Easing and Interpolation]]; conflicts between measurements are in [[Open Questions]]. Where code follows one production game's measurements (the reference project), comments say "measured".

---

## 1. Joint frames for Motor6D and AnimationConstraint

```lua
--!strict
-- Part1 = Part0 * C0 * Transform * C1:Inverse()          (Motor6D)
-- Part1 = Part0 * A0.CFrame * Transform * A1.CFrame:Inverse()  (AnimationConstraint; C0/C1 are read-only aliases)
export type JointInfo = {
	joint: Instance,
	part0: BasePart,
	part1: BasePart,
	c0: CFrame,
	c1: CFrame,
	name: string,        -- Part1's name: what clip Poses are named after
	depth: number,       -- distance from the root, for parents-first ordering
}

local function jointFrames(j: Instance): (BasePart?, BasePart?, CFrame, CFrame)
	if j:IsA("Motor6D") then
		return j.Part0, j.Part1, j.C0, j.C1
	elseif j:IsA("AnimationConstraint") then
		local a0, a1 = j.Attachment0, j.Attachment1
		if not (a0 and a1) then return nil, nil, CFrame.identity, CFrame.identity end
		local p0 = a0.Parent
		local p1 = a1.Parent
		return (p0 and p0:IsA("BasePart")) and p0 or nil, (p1 and p1:IsA("BasePart")) and p1 or nil, a0.CFrame, a1.CFrame
	end
	return nil, nil, CFrame.identity, CFrame.identity
end

-- All joints of a rig, parents before children.
local function collectJoints(model: Model): ({ JointInfo }, string?)
	local byPart1: { [BasePart]: JointInfo } = {}
	local list: { JointInfo } = {}
	for _, d in model:GetDescendants() do
		local p0, p1, c0, c1 = jointFrames(d)
		if p0 and p1 then
			local info: JointInfo = { joint = d, part0 = p0, part1 = p1, c0 = c0, c1 = c1, name = p1.Name, depth = 0 }
			byPart1[p1] = info
			table.insert(list, info)
		end
	end
	local rootName: string? = nil
	for _, info in list do
		local depth, p = 0, info.part0
		while byPart1[p] do depth += 1; p = byPart1[p].part0 end
		info.depth = depth
		if depth == 0 then rootName = info.part0.Name end   -- the part nothing drives (HumanoidRootPart)
	end
	table.sort(list, function(a, b) return a.depth < b.depth end)
	return list, rootName
end
```

## 2. Forward kinematics

```lua
-- poses: joint name -> Transform (the clip's Pose CFrame). Missing joints use identity (rest).
local function fk(joints: { JointInfo }, rootName: string, rootCF: CFrame, poses: { [string]: CFrame }): { [string]: CFrame }
	local cf: { [string]: CFrame } = { [rootName] = rootCF }
	for _, j in joints do
		local parent = cf[j.part0.Name]
		if parent then
			cf[j.name] = parent * j.c0 * (poses[j.name] or CFrame.identity) * j.c1:Inverse()
		end
	end
	return cf
end

-- The Transform that puts Part1 at a desired world CFrame, given where Part0 is.
local function transformFor(j: JointInfo, part0CF: CFrame, desiredPart1CF: CFrame): CFrame
	return (part0CF * j.c0):Inverse() * desiredPart1CF * j.c1
end
```

`transformFor` is the inverse of the FK line and the basis of every IK snippet: solve where you want a part in world space, then convert to the joint's `Transform`. Use the parent's FK result for `part0CF`, not `Part0.CFrame` read from the scene: in `PreSimulation` the scene still holds last frame's physics result.

## 3. Pose helpers

```lua
-- {rx, ry, rz [, px, py, pz]} in DEGREES and studs, the format the reference project's spec files used
local function poseCF(t: { number }): CFrame
	return CFrame.new(t[4] or 0, t[5] or 0, t[6] or 0)
		* CFrame.Angles(math.rad(t[1]), math.rad(t[2]), math.rad(t[3]))
end

-- Hand rotation from a blade direction and the cutting edge direction.
-- Convention: blade along the hand's -Z (LookVector), edge toward the hand's -X.
local function handRot(dir: Vector3, edge: Vector3): CFrame
	local z = -dir.Unit
	local x = -(edge - z * edge:Dot(z)).Unit      -- edge made perpendicular to the blade
	local y = z:Cross(x)
	return CFrame.fromMatrix(Vector3.zero, x, y, z)
end
```
`CFrame.Angles(rx, ry, rz)` applies Z, then Y, then X in the parent frame (equivalently X, Y, Z in the local frame). Keep that order everywhere: a spec written in degrees and converted with a different order produces poses that look right for single-axis turns and wrong for combined ones.

---

## 4. Building a KeyframeSequence from a table

```lua
--!strict
export type EaseSpec = { style: Enum.PoseEasingStyle, dir: Enum.PoseEasingDirection }
export type KeySpec = {
	t: number,
	poses: { [string]: CFrame },                 -- joint (Part1) name -> Pose CFrame
	ease: EaseSpec?,                             -- the shape of the move INTO this key
	markers: { [string]: string }?,              -- marker name -> value
	name: string?,                               -- a named keyframe also fires KeyframeReached
}
export type ClipSpec = { name: string, loop: boolean, priority: Enum.AnimationPriority, keys: { KeySpec } }

-- parentOf: Part1 name -> Part0 name (from collectJoints). rootName: the top-level pose (never applied).
local function buildKS(spec: ClipSpec, parentOf: { [string]: string }, rootName: string): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = spec.name
	ks.Loop = spec.loop
	ks.Priority = spec.priority

	local keys = table.clone(spec.keys)
	table.sort(keys, function(a, b) return a.t < b.t end)

	-- Roblox eases a segment by its FIRST pose. Authors think "this key eases in", so the easing given
	-- on a joint's NEXT key is written onto this pose.
	local function easeLeaving(i: number, joint: string): EaseSpec?
		for k = i + 1, #keys do
			if keys[k].poses[joint] then return keys[k].ease end
		end
		return nil
	end

	for i, key in keys do
		local kf = Instance.new("Keyframe")
		kf.Time = math.round(key.t * 1000) / 1000        -- 1 ms grid: avoids near-duplicate times
		if key.name then kf.Name = key.name end

		local made: { [string]: Pose } = {}
		local function poseFor(name: string): Pose
			local existing = made[name]
			if existing then return existing end
			local p = Instance.new("Pose")
			p.Name = name
			p.Weight = 0                                 -- placeholder until keyed below
			p.CFrame = CFrame.identity
			made[name] = p
			local parentName = parentOf[name]
			if parentName then
				p.Parent = poseFor(parentName)           -- parents first, child Pose under parent Pose
			else
				p.Parent = kf                            -- top-level root pose
			end
			return p
		end

		poseFor(rootName)
		for joint, cf in key.poses do
			if joint == rootName then
				warn(spec.name .. ": the top-level root pose is never applied; key its first child instead")
				continue
			end
			local p = poseFor(joint)
			p.Weight = 1
			p.CFrame = cf
			local e = easeLeaving(i, joint)
			p.EasingStyle = e and e.style or Enum.PoseEasingStyle.Linear
			p.EasingDirection = e and e.dir or Enum.PoseEasingDirection.In
		end

		if key.markers then
			for markerName, value in key.markers do
				local m = Instance.new("KeyframeMarker")
				m.Name = markerName
				m.Value = value
				kf:AddMarker(m)
			end
		end
		kf.Parent = ks
	end
	return ks
end
```

Rules this builder enforces, and why:
- **Easing on the leaving pose.** See [[Engine Gotchas]] 3.3.
- **Never legacy `Cubic`.** Pass `CubicV2`; legacy Cubic plays reversed (measured).
- **Top-level root pose stays a weight-0 placeholder.** It is never applied (measured).
- **Arm joints rotation-only.** Translations over 0.05 studs on arms read as a detached shoulder. Root travel goes on LowerTorso (the root's first child), at game scale for body-scaled characters.
- **Keys at most about 120 degrees apart per joint.** Larger turns interpolate unpredictably; exactly 180 is ambiguous.
- **Markers keep their keyframe.** Any thinning step must keep keyframes that carry markers or names.

Example: a two-key swing for the right arm.

```lua
local joints, rootName = collectJoints(rig)
local parentOf = {}
for _, j in joints do parentOf[j.name] = j.part0.Name end

local slash = buildKS({
	name = "Slash1", loop = false, priority = Enum.AnimationPriority.Action4,
	keys = {
		{ t = 0,    poses = { RightUpperArm = poseCF({ 160, 0, 30 }) } },
		{ t = 0.12, poses = { RightUpperArm = poseCF({ 175, 0, 40 }) },
		  ease = { style = Enum.PoseEasingStyle.CubicV2, dir = Enum.PoseEasingDirection.In } },   -- wind-up: slow start
		{ t = 0.24, poses = { RightUpperArm = poseCF({ 60, 0, -50 }) },
		  ease = { style = Enum.PoseEasingStyle.CubicV2, dir = Enum.PoseEasingDirection.Out },   -- strike: fast start
		  markers = { Hit = "" } },
		{ t = 0.42, poses = { RightUpperArm = poseCF({ 20, 0, -10 }) },
		  ease = { style = Enum.PoseEasingStyle.CubicV2, dir = Enum.PoseEasingDirection.InOut } },-- settle
	},
}, parentOf, rootName :: string)
```
Euler differences are not rotation angles: check the real key-to-key angle of the strike segment (`(a:Inverse() * b):ToAxisAngle()`, or the lint in [[Testing Animations in Studio]]) against the 120-degree cap rather than subtracting degrees per axis. The convention (wind-ups `CubicV2 In`, strikes `CubicV2 Out` with denser in-betweens, settles `InOut`) is the reference project's; see [[Authoring Clips in Code]].

---

## 5. Easing curves as the Animator plays them

```lua
--!strict
local PS, PD = Enum.PoseEasingStyle, Enum.PoseEasingDirection

local function cubicIn(u: number) return u * u * u end
local function cubicOut(u: number) return 1 - (1 - u) ^ 3 end
local function cubicInOut(u: number)
	if u < 0.5 then return 4 * u * u * u end
	return 1 - (-2 * u + 2) ^ 3 / 2
end
local function bounceOut(u: number): number
	if u < 1 / 2.75 then return 7.5625 * u * u
	elseif u < 2 / 2.75 then u -= 1.5 / 2.75; return 7.5625 * u * u + 0.75
	elseif u < 2.5 / 2.75 then u -= 2.25 / 2.75; return 7.5625 * u * u + 0.9375 end
	u -= 2.625 / 2.75
	return 7.5625 * u * u + 0.984375
end
local function elasticIn(u: number): number                  -- Penner, period 0.3
	if u <= 0 then return 0 elseif u >= 1 then return 1 end
	return -(2 ^ (10 * (u - 1))) * math.sin((u - 1 - 0.075) * 2 * math.pi / 0.3)
end

-- u: 0..1 through the segment. Returns the blend factor toward the next key.
local function easeAlpha(style: Enum.PoseEasingStyle, dir: Enum.PoseEasingDirection, u: number): number
	if style == PS.Linear then
		return u
	elseif style == PS.Constant then
		-- measured: In jumps at once, Out holds until the next key, InOut jumps at the midpoint
		if dir == PD.In then return u > 0 and 1 or 0
		elseif dir == PD.Out then return 0
		else return u >= 0.5 and 1 or 0 end
	elseif style == PS.CubicV2 then
		-- TweenService directions: In = slow start
		if dir == PD.In then return cubicIn(u) elseif dir == PD.Out then return cubicOut(u) end
		return cubicInOut(u)
	elseif style == PS.Cubic then
		-- legacy Cubic runs REVERSED (measured): In plays as Out and vice versa
		if dir == PD.In then return cubicOut(u) elseif dir == PD.Out then return cubicIn(u) end
		return cubicInOut(u)
	elseif style == PS.Elastic then
		-- later measurement: follows its direction (an earlier one said reversed; see Open Questions)
		if dir == PD.In then return elasticIn(u)
		elseif dir == PD.Out then return 1 - elasticIn(1 - u) end
		if u <= 0 then return 0 elseif u >= 1 then return 1 end
		local v = 2 * u - 1
		if v < 0 then return -0.5 * 2 ^ (10 * v) * math.sin((v - 0.1125) * 2 * math.pi / 0.45) end
		return 0.5 * 2 ^ (-10 * v) * math.sin((v - 0.1125) * 2 * math.pi / 0.45) + 1
	elseif style == PS.Bounce then
		if dir == PD.In then return 1 - bounceOut(1 - u)
		elseif dir == PD.Out then return bounceOut(u) end
		-- measured: InOut uses BounceIn's shape on both halves
		if u < 0.5 then return (1 - bounceOut(1 - 2 * u)) / 2 end
		return 1 - bounceOut(2 - 2 * u) / 2
	end
	return u
end
```

---

## 6. Sampling a KeyframeSequence like the Animator

Measured model (see [[How the Animator Really Behaves]]):
- Per joint, only `Weight > 0` poses are keys; the top-level root pose is ignored.
- A segment eases by its first pose's style.
- Rotations: if **every keyframe** is evenly spaced (marker-only keyframes count) **and every key is Linear**, [[Quaternions|quaternion]] nlerp along the shortest way. Otherwise a linear blend of **rotation vectors**, using, per segment, whichever of each key's two representations (`v` or `v - 2*pi*axis`) are closest.
- Offsets lerp linearly. Before the first key and after the last, the joint holds.
- Translations scale with `Model:GetScale()` on model-scaled rigs.

```lua
--!strict
local TWO_PI = 2 * math.pi

local function logR(cf: CFrame): Vector3                 -- rotation vector (axis * angle) of a CFrame
	local axis, angle = cf:ToAxisAngle()
	if angle ~= angle then return Vector3.zero end       -- NaN guard for identity
	if angle > math.pi then                              -- keep the canonical representation
		angle = TWO_PI - angle
		axis = -axis
	end
	return axis * angle
end
local function flipR(v: Vector3): Vector3                -- the other representation of the same rotation
	local a = v.Magnitude
	if a < 1e-12 then return v end
	return -(v / a) * (TWO_PI - a)
end
-- Of the four combinations of representations, the pair closest together (ties keep the stored ones)
local function pairOf(a: Vector3, b: Vector3): (Vector3, Vector3)
	local TIE = 1e-5
	local fa, fb = flipR(a), flipR(b)
	local best, pa, pb = (a - b).Magnitude, a, b
	local d = (fa - b).Magnitude; if d < best - TIE then best, pa, pb = d, fa, b end
	d = (a - fb).Magnitude;       if d < best - TIE then best, pa, pb = d, a, fb end
	d = (fa - fb).Magnitude;      if d < best - TIE then pa, pb = fa, fb end
	return pa, pb
end
local function cfOfRV(rv: Vector3, p: Vector3): CFrame
	local a = rv.Magnitude
	if a < 1e-12 then return CFrame.new(p) end
	return CFrame.fromAxisAngle(rv / a, a) + p
end
local function quatOf(rv: Vector3): (number, number, number, number)   -- x, y, z, w
	local a = rv.Magnitude
	if a < 1e-12 then return 0, 0, 0, 1 end
	local s = math.sin(a / 2) / a
	return rv.X * s, rv.Y * s, rv.Z * s, math.cos(a / 2)
end

export type JointKeys = {
	n: number, t: { number }, rv: { Vector3 }, p: { Vector3 },
	style: { Enum.PoseEasingStyle }, dir: { Enum.PoseEasingDirection },
	va: { Vector3 }, vb: { Vector3 },                    -- per-segment rotation-vector pairs
}
export type Clip = {
	length: number, loop: boolean, nlerp: boolean,
	joints: { [string]: JointKeys },
	events: { { t: number, name: string, value: string?, marker: boolean } },
}

local function parseKS(ks: KeyframeSequence): Clip
	local kfs = ks:GetKeyframes() :: { Keyframe }
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	local joints: { [string]: JointKeys } = {}
	local events = {}
	local length = 0
	local allLinear = true

	local function walk(parent: Instance, t: number)
		for _, child in parent:GetChildren() do
			if not child:IsA("Pose") then continue end
			local pose = child :: Pose
			if pose.Weight > 0 then
				local j = joints[pose.Name]
				if not j then
					j = { n = 0, t = {}, rv = {}, p = {}, style = {}, dir = {}, va = {}, vb = {} }
					joints[pose.Name] = j
				end
				local jk = j :: JointKeys
				jk.n += 1
				jk.t[jk.n] = t
				jk.rv[jk.n] = logR(pose.CFrame)
				jk.p[jk.n] = pose.CFrame.Position
				jk.style[jk.n] = pose.EasingStyle
				jk.dir[jk.n] = pose.EasingDirection
			end
			walk(pose, t)
		end
	end

	for _, kf in kfs do
		length = math.max(length, kf.Time)
		if kf.Name ~= "Keyframe" then table.insert(events, { t = kf.Time, name = kf.Name, marker = false }) end
		for _, m in kf:GetMarkers() do
			local km = m :: KeyframeMarker
			table.insert(events, { t = kf.Time, name = km.Name, value = km.Value, marker = true })
		end
		for _, top in kf:GetChildren() do
			if top:IsA("Pose") then walk(top, kf.Time) end   -- skip the top-level pose itself (never applied)
		end
	end

	for _, j in joints do
		for i = 1, j.n - 1 do
			if j.style[i] ~= Enum.PoseEasingStyle.Linear then allLinear = false end
			j.va[i], j.vb[i] = pairOf(j.rv[i], j.rv[i + 1])
		end
	end

	-- even spacing is judged over ALL keyframes of the sequence (measured)
	local even = true
	if #kfs > 2 then
		local step = kfs[2].Time - kfs[1].Time
		for i = 3, #kfs do
			if math.abs((kfs[i].Time - kfs[i - 1].Time) - step) > 1e-4 then even = false; break end
		end
	end
	table.sort(events, function(a, b) return a.t < b.t end)
	return { length = length, loop = ks.Loop, nlerp = even and allLinear, joints = joints, events = events }
end

-- Sample one joint at time t. scale = Model:GetScale() for model-scaled rigs, else 1.
local function sampleJoint(clip: Clip, j: JointKeys, t: number, scale: number): CFrame
	local n = j.n
	local rv: Vector3, p: Vector3
	if n == 1 or t <= j.t[1] then
		rv, p = (n > 1 and not clip.nlerp) and j.va[1] or j.rv[1], j.p[1]
	elseif t >= j.t[n] then
		rv, p = (not clip.nlerp) and j.vb[n - 1] or j.rv[n], j.p[n]   -- measured: holds the paired vector
	else
		local lo, hi = 1, n                                          -- binary search for the segment
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if j.t[mid] <= t then lo = mid else hi = mid end
		end
		local u = (t - j.t[lo]) / (j.t[hi] - j.t[lo])
		local a = easeAlpha(j.style[lo], j.dir[lo], u)
		if clip.nlerp then
			local ax, ay, az, aw = quatOf(j.rv[lo])
			local bx, by, bz, bw = quatOf(j.rv[hi])
			if ax * bx + ay * by + az * bz + aw * bw < 0 then bx, by, bz, bw = -bx, -by, -bz, -bw end   -- shortest way
			local x, y, z, w = ax + (bx - ax) * a, ay + (by - ay) * a, az + (bz - az) * a, aw + (bw - aw) * a
			local len = math.sqrt(x * x + y * y + z * z + w * w)
			p = j.p[lo]:Lerp(j.p[hi], a)
			if p.Magnitude > 0 and scale ~= 1 then p *= scale end
			return CFrame.new(p.X, p.Y, p.Z, x / len, y / len, z / len, w / len)
		end
		rv = j.va[lo]:Lerp(j.vb[lo], a)
		p = j.p[lo]:Lerp(j.p[hi], a)
	end
	if scale ~= 1 then p *= scale end
	return cfOfRV(rv, p)
end

-- Whole-rig pose at time t: joint name -> Transform
local function samplePose(clip: Clip, t: number, scale: number?): { [string]: CFrame }
	if clip.loop and clip.length > 0 then t %= clip.length end
	local out = {}
	for name, j in clip.joints do out[name] = sampleJoint(clip, j, t, scale or 1) end
	return out
end
```

Why bother: a [[slerp]] sampler (`CFrame:Lerp`) predicts the Animator within a fraction of a degree on small turns but was measured up to 178 degrees off on big key-to-key turns far from rest; this model matched within 0.24 degrees. If your tools (QA, bakers, filmstrips, a Lua player) predict poses, they need this, or they will pass clips that look wrong in game.

Known edge: segments of exactly 180 degrees are ambiguous in the Animator itself. This sampler picks deterministically; the Animator may not.

---

## 7. Posing an anchored mannequin (filmstrips, previews in Edit)

```lua
-- Clone a rig's parts as anchored copies posed at time t. Works in Edit (no simulation needed).
local function mannequin(rig: Model, clip: Clip, t: number, offset: CFrame): Model
	local joints, rootName = collectJoints(rig)
	local root = rig:FindFirstChild(rootName :: string) :: BasePart
	local scale = rig:GetScale()
	local cfs = fk(joints, rootName :: string, offset * root.CFrame, samplePose(clip, t, scale))
	local out = Instance.new("Model")
	out.Name = ("%s@%.2f"):format(rig.Name, t)
	for name, cf in cfs do
		local src = rig:FindFirstChild(name, true)
		if src and src:IsA("BasePart") and name ~= rootName then
			local c = src:Clone()
			c:ClearAllChildren()                 -- drop joints/attachments from the copy (keeps mesh data)
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
			c.CFrame = cf
			c.Parent = out
		end
	end
	out.Parent = workspace
	return out
end

-- A filmstrip: one mannequin every 0.06 s, 5 studs apart sideways.
for i = 0, math.floor(clip.length / 0.06) do
	mannequin(rig, clip, i * 0.06, CFrame.new(5 * (i + 1), 0, 0))
end
```
`ClearAllChildren` on a MeshPart keeps its mesh (mesh data is a property, not a child); on a Part with a `SpecialMesh` child it removes the mesh, so keep `SpecialMesh` children if your rig uses them. Add the held weapon by applying the grip offset to the hand's CFrame.

---

## 8. Register, wait, step (Studio test of a fresh clip)

```lua
local KSP = game:GetService("KeyframeSequenceProvider")   -- Studio-only ids: tests, never shipping code
local a = Instance.new("Animation")
a.AnimationId = KSP:RegisterKeyframeSequence(ks)
local tr = animator:LoadAnimation(a)
tr.Priority = Enum.AnimationPriority.Action4
tr.Looped = false
local w0 = os.clock()
while tr.Length <= 0 and os.clock() - w0 < 2 do task.wait() end   -- a fresh registration needs this (measured)
tr:Play(0)
animator:StepAnimations(1e-4)     -- command bar / plugin only; a tiny step applies the start pose
-- then animator:StepAnimations(1/60) per frame: dt must be > 0 to advance
```
Full harness in [[Testing Animations in Studio]].

---

## 9. Thinning dense samples into keys

Baked or captured clips have a key every frame. Keep only the keys the Animator needs to reproduce the motion. Because a thinned clip is unevenly spaced, the Animator will blend rotation vectors, so the check must use rotation vectors too.

```lua
-- times[i], cfs[i]: dense samples of ONE joint. Returns indices of keys to keep (Linear easing).
local function angDiff(a: CFrame, b: CFrame): number
	local _, ang = (a:Inverse() * b):ToAxisAngle()
	ang = math.abs(ang)
	return ang > math.pi and TWO_PI - ang or ang
end

local function thinJoint(times: { number }, cfs: { CFrame }, tolDeg: number, tolPos: number, maxGap: number): { number }
	local keep = { 1 }
	local i = 1
	local n = #times
	local tolR = math.rad(tolDeg)
	while i < n do
		local best = i + 1
		for k = i + 2, n do
			if times[k] - times[i] > maxGap then break end
			local va, vb = pairOf(logR(cfs[i]), logR(cfs[k]))
			local ok = true
			for m = i + 1, k - 1 do                       -- every dense sample in between must be reproduced
				local u = (times[m] - times[i]) / (times[k] - times[i])
				local guess = cfOfRV(va:Lerp(vb, u), cfs[i].Position:Lerp(cfs[k].Position, u))
				if angDiff(guess, cfs[m]) > tolR or (guess.Position - cfs[m].Position).Magnitude > tolPos then
					ok = false; break
				end
			end
			if ok then best = k else break end
		end
		table.insert(keep, best)
		i = best
	end
	return keep
end
```
Tolerances used in production: 0.75 degrees and 0.03 studs for body re-bakes (0.5 degrees on hips), 0.03 degrees and 0.002 studs for lossless-looking buffer encoding, at most 0.4 to 0.5 s between kept keys. Then share key times across joints where you can: every new keyframe time costs a Keyframe plus placeholder Poses (see [[Performance and Memory]]). Always keep keyframes that carry markers or names.

---

## 10. Compact binary clips (stubs)

Clip data can live in a `buffer` instead of thousands of Pose instances. One working layout (v2) is documented in [[Clip Buffer Format]]; the key trick is the rotation encoding.

### Smallest-three quaternion packing (6 bytes + 2 bits)
A unit quaternion's largest component can be rebuilt from the other three. Store the three smaller ones as int16, scaled by `32767 / sqrt(0.5)` (none of them can exceed `sqrt(0.5)` in magnitude), and the index of the dropped one in 2 bits.

```lua
local Q_SCALE = 32767 / math.sqrt(0.5)

-- q = {x, y, z, w}, unit length. Returns dropped index (0..3) and three int16 values.
local function packQuat(q: { number }): (number, number, number, number)
	local big, bi = -1, 1
	for i = 1, 4 do
		local a = math.abs(q[i])
		if a > big then big, bi = a, i end
	end
	local sign = q[bi] < 0 and -1 or 1                 -- q and -q are the same rotation: make the dropped one positive
	local out = {}
	for i = 1, 4 do
		if i ~= bi then
			table.insert(out, math.clamp(math.floor(q[i] * sign * Q_SCALE + 0.5), -32767, 32767))
		end
	end
	return bi - 1, out[1], out[2], out[3]
end

local function unpackQuat(dropped: number, a: number, b: number, c: number): { number }
	local s = { a / Q_SCALE, b / Q_SCALE, c / Q_SCALE }
	local rest = math.sqrt(math.max(0, 1 - s[1] * s[1] - s[2] * s[2] - s[3] * s[3]))
	local q, k = {}, 1
	for i = 1, 4 do
		if i == dropped + 1 then q[i] = rest else q[i] = s[k]; k += 1 end
	end
	return q
end

-- Writing one key: u16 = timeIndex | dropped << 14 (so at most 16,383 distinct key times), then 3 x i16.
local function writeKey(b: buffer, o: number, timeIndex: number, q: { number }): number
	local dropped, x, y, z = packQuat(q)
	buffer.writeu16(b, o, bit32.bor(timeIndex, bit32.lshift(dropped, 14)))
	buffer.writei16(b, o + 2, x)
	buffer.writei16(b, o + 4, y)
	buffer.writei16(b, o + 6, z)
	return o + 8
end
```
Precision: the int16 step is about `sqrt(0.5) / 32767`, roughly 0.0025 degrees per component, far below anything visible. The measured round trip of whole clips through this format was within 0.04 degrees, with position rounding the larger source of error on big moves (one kit stayed unbaked at 0.28 to 0.31 degrees for that reason).

### Storing the buffer
```lua
local EncodingService = game:GetService("EncodingService")
-- EncodingService:Base64Encode takes and returns a buffer (Docs)
local b64 = buffer.tostring(EncodingService:Base64Encode(clipBuffer))
ks:SetAttribute("KSB", b64)

-- reading it back
local raw = EncodingService:Base64Decode(buffer.fromstring(ks:GetAttribute("KSB") :: string))
```
A stub keeps the `KeyframeSequence` itself (name, loop, priority, attributes, named and marker keyframes, first and last keyframes) so code that reads lengths, markers and keyframe names keeps working, while all Poses are removed. See [[Baked Clip Stubs and Archiving]].

---

## Common mistakes
- Sampling with `CFrame:Lerp` and trusting it on big turns.
- Putting easing on the destination key.
- Keying the top-level root pose.
- Forgetting that a thinned (uneven) clip switches the Animator from nlerp to rotation vectors.
- Reading `Part0.CFrame` from the scene for FK in `PreSimulation` (last frame's value).
- Dropping marker keyframes while thinning.
- Using `AnimationConstraint.C0`-style writes (read-only).

## See also
[[Authoring Clips in Code]] · [[How the Animator Really Behaves]] · [[Keyframes, Easing and Interpolation]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Motor6D Math and CFrame Composition]] · [[Lua Keyframe Player Internals]] · [[Clip Buffer Format]] · [[Snippets - Lua Keyframe Player Core]] · [[Testing Animations in Studio]]

## Nuances and edge cases

1. **Pose instance counts explode quietly.** A 2 second clip sampled at 30 keys per second over 25 joints is 60 keyframes times 25 poses, about 1,500 `Pose` instances. A library of 400 such clips stored in the place is 600,000 instances, which slows place open, Team Create sync and save. Thinning to only the keys that matter, or storing clips as packed buffers, is the difference between a 40 MB and a 4 MB place (rule of thumb from the reference project's experience, see [[Case Study - Cutting a Million Instances]]).
2. **Thinning tolerance is per joint, not global.** 0.03 degrees on a finger is invisible; 0.03 degrees on the root at the end of a long chain becomes a few millimetres of drift at the hand, still fine. But thinning translation on the root by the same tolerance as rotations can make feet slide. Use a separate positional tolerance (around 0.002 studs) for joints that translate.
3. **Uneven keys switch interpolation modes.** As the existing list notes, a thinned clip leaves nlerp. The visible consequence is that big rotations (over 180 degrees between keys) can take the long way round. Keep a key at least every 90 degrees of rotation on spinning joints, even if thinning would drop it.
4. **Runtime-built clips cannot be published at runtime.** A `KeyframeSequence` built in a live server cannot become an asset id. On a live server it can only be played by your own Lua player or turned into a `CurveAnimation`-style procedural path. Plan your pipeline knowing that runtime generation means a custom player.
5. **Sampling at 60 vs 30 keys per second.** Animators in Blender often export at 30 or 24 frames per second. Resampling to 60 doubles data for little gain; the Animator interpolates between keys anyway. Keep source rate unless a motion has sharp contacts that need a key exactly on a frame.
6. **Floating point and `Weight`.** `Pose.Weight` of 0 means "not keyed". A converter that writes `Weight = 1e-6` for "almost nothing" produces a key that pulls the joint to the pose; treat weights as a boolean flag in builders.
7. **Big teams and edit conflicts.** Clips generated by a tool and committed to the place are binary-ish blobs to most review tools. Store the source table or buffer in source control (Rojo or a package) so diffs mean something.

The senior trade-off here is fidelity against weight: every extra key adds instance count, load time and memory; every dropped key risks a visible pop. Decide the tolerance once, measure it on your worst clip, and lock it into the build tool rather than tuning per clip.

## Common mistakes in production

1. **Building clips on every server start.** Symptom: slow server boot, a spike of several seconds. Fix: build once in a tool, store the result, load it.
2. **Leaving filmstrip mannequins in the place.** Symptom: hidden anchored rigs inflate instance count and appear in streaming. Fix: build previews in a temporary folder and destroy them, or keep them in `ServerStorage` only in a tooling place.
3. **Mixing degrees and radians in table formats.** Symptom: clips with limbs spinning dozens of times. Fix: one unit in the table format, asserted on load.
4. **Packing quaternions without normalizing first.** Symptom: smallest-three decoding drifts, slight scale on limbs. Fix: normalize before packing and after unpacking.
5. **Not versioning the binary format.** Symptom: an encoder change breaks every stored clip. Fix: a version byte at the start of every buffer.

## Related decisions

- [[Buffers and Binary Data]]: the buffer API used for packed clips.
- [[Serialization Formats for Saves and Networking]]: choosing between tables, JSON and buffers for stored clips.
- [[Rotations Angles and Quaternions]]: the maths behind nlerp, rotation vectors and smallest-three.
- [[Interpolation Easing and Curves Math]]: easing curves the sampler reproduces.
- [[Case Study - Instance Cleanup and Place Size]]: why Pose counts matter for place size.
- [[Code Pipeline - Rojo Git and CI]]: storing clip sources where diffs are readable.
- [[Blender Automation with Python]]: generating the source tables from Blender exports.
- [[Data Schema Design and Migrations]]: versioning a stored format the same way you version save data.

## Connected notes
<!-- auto-links:start -->
[[Animation Data from Blender to Roblox]] · [[Weapon Rig Player]] · [[Animation Editor Advanced]] · [[Animation Glossary]] · [[AI Animation and Motion from Video]] · Game Math Start Here · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Lua Keyframe Player]] · [[Debugging Animation Problems]] · [[Animation Data Hygiene - Euler Wrap Joint Holes and Easing]] · [[Animation Editor Workflow]] · [[CurveAnimation and Curve Channels]] · [[Moon Animator and Third-Party Tools]] · [[Weapon Design Rig Builder]] · [[Timing Spacing and Frame Charts]] · [[Snippets - Procedural Motion]]
<!-- related:end -->
