---
tags: [snippets, luau, keyframe-player, runtime, sampling, blending]
---
# Snippets: Lua Keyframe Player Core

A self-contained Lua player for `KeyframeSequence`s: it parses a clip, samples it the way the engine Animator does, mixes several tracks by priority and weight the way the Animator does, fires markers, and writes joint `Transform`s once per frame for every rig, with distance LOD. Tracks expose the familiar `AnimationTrack` surface (`Play`, `Stop`, `AdjustSpeed`, `AdjustWeight`, `GetMarkerReachedSignal`, `Stopped`, `Ended`, `DidLoop`, `TimePosition`, `WeightCurrent`...).

Why you would want one: clips registered with `KeyframeSequenceProvider` only play in Studio (Docs: the ids "cannot be used outside of Studio"), publishing every clip is slow, and a Lua player lets Studio and live run the same code path. The reference project (one live action game) moved every player, weapon and enemy clip onto such a player. Its full version, with relays and stubs, is described in [[Lua Keyframe Player]] and [[Lua Keyframe Player Internals]]; this note is the compact core you can read in one sitting and extend.

Measured behaviour reproduced here (see [[How the Animator Really Behaves]]):
- Per joint, only `Weight > 0` poses are keys; the top-level root pose is never applied.
- A segment eases by its first pose's style; legacy `Cubic` runs reversed; `Constant` In/Out/InOut = jump now / hold / jump at the midpoint.
- Rotations: nlerp when every keyframe is evenly spaced and every key is Linear; otherwise a linear blend of rotation vectors using the closest pair of representations.
- Offsets lerp; translations scale with `Model:GetScale()`.
- Fades are linear. A one-shot that ends holds its last pose and fades out over 0.3 s. A stopped track keeps advancing time during its fade. `Play` restarts at 0. Track time is float32.
- Mixing: weight is handed out from the highest priority down; a priority whose weights fit in what is left keeps them, otherwise each track gets `w * rem / min(S, 1)`; contributions are summed as one weighted quaternion; with less than full weight in total, the rotation vector and offset scale toward rest. Offset weights are capped at 1.

The reference implementation matched the real Animator within 0.084 degrees on R15 clips, 0.056 degrees and 0.002 studs on 60 enemy clips, 0.04 degrees on a five-track blend, and fired 319 of 319 markers, at about 22 microseconds per 25-bone rig per frame. This compact version follows the same rules but has not been measured on its own; A/B it against the Animator before trusting it ([[Testing Animations in Studio]]).

---

## 1. The module

```lua
--!strict
-- KeyframePlayer: play KeyframeSequences in Lua by writing joint Transforms (Motor6D, AnimationConstraint, Bone).
local RunService = game:GetService("RunService")

local KeyframePlayer = {}

local TWO_PI = 2 * math.pi
local END_FADE = 0.3                    -- measured: a finished one-shot fades out over 0.3 s
local NEAR, MID, FAR = 60, 150, 300     -- LOD ranges (studs): every frame / every 2nd / every 4th / time only

-- ================================================================ tiny signal
type Handler = (...any) -> ()
local Signal = {}
Signal.__index = Signal
local function newSignal()
	return setmetatable({ _h = {} :: { Handler } }, Signal)
end
function Signal.Connect(self: any, fn: Handler)
	table.insert(self._h, fn)
	local conn = { Connected = true }
	function conn.Disconnect(c: any)
		c.Connected = false
		local i = table.find(self._h, fn)
		if i then table.remove(self._h, i) end
	end
	return conn
end
function Signal.Once(self: any, fn: Handler)
	local conn: any
	conn = Signal.Connect(self, function(...) conn:Disconnect(); fn(...) end)
	return conn
end
function Signal.Fire(self: any, ...: any)
	for _, fn in table.clone(self._h) do task.spawn(fn, ...) end
end

-- ================================================================ easing (as the Animator plays it)
local PS, PD = Enum.PoseEasingStyle, Enum.PoseEasingDirection
local function bounceOut(u: number): number
	if u < 1 / 2.75 then return 7.5625 * u * u
	elseif u < 2 / 2.75 then u -= 1.5 / 2.75; return 7.5625 * u * u + 0.75
	elseif u < 2.5 / 2.75 then u -= 2.25 / 2.75; return 7.5625 * u * u + 0.9375 end
	u -= 2.625 / 2.75
	return 7.5625 * u * u + 0.984375
end
local function elasticIn(u: number): number
	if u <= 0 then return 0 elseif u >= 1 then return 1 end
	return -(2 ^ (10 * (u - 1))) * math.sin((u - 1 - 0.075) * TWO_PI / 0.3)
end
local function cubic(dir: Enum.PoseEasingDirection, u: number): number
	if dir == PD.In then return u * u * u end
	if dir == PD.Out then return 1 - (1 - u) ^ 3 end
	if u < 0.5 then return 4 * u * u * u end
	return 1 - (-2 * u + 2) ^ 3 / 2
end
local REVERSE = { [PD.In] = PD.Out, [PD.Out] = PD.In, [PD.InOut] = PD.InOut }

local function ease(style: Enum.PoseEasingStyle, dir: Enum.PoseEasingDirection, u: number): number
	if style == PS.Linear then return u end
	if style == PS.Constant then
		if dir == PD.In then return u > 0 and 1 or 0 end      -- jump at once
		if dir == PD.Out then return 0 end                    -- hold until the next key
		return u >= 0.5 and 1 or 0                            -- jump at the midpoint
	end
	if style == PS.CubicV2 then return cubic(dir, u) end
	if style == PS.Cubic then return cubic(REVERSE[dir], u) end   -- legacy Cubic runs reversed (measured)
	if style == PS.Elastic then                               -- later measurement: NOT reversed (Open Questions)
		if dir == PD.In then return elasticIn(u) end
		if dir == PD.Out then return 1 - elasticIn(1 - u) end
		if u <= 0 then return 0 elseif u >= 1 then return 1 end
		local v = 2 * u - 1
		if v < 0 then return -0.5 * 2 ^ (10 * v) * math.sin((v - 0.1125) * TWO_PI / 0.45) end
		return 0.5 * 2 ^ (-10 * v) * math.sin((v - 0.1125) * TWO_PI / 0.45) + 1
	end
	if style == PS.Bounce then
		if dir == PD.In then return 1 - bounceOut(1 - u) end
		if dir == PD.Out then return bounceOut(u) end
		if u < 0.5 then return (1 - bounceOut(1 - 2 * u)) / 2 end   -- InOut: BounceIn on both halves (measured)
		return 1 - bounceOut(2 - 2 * u) / 2
	end
	return u
end

-- ================================================================ rotation helpers
local function logR(cf: CFrame): Vector3
	local axis, angle = cf:ToAxisAngle()
	if angle ~= angle then return Vector3.zero end
	if angle > math.pi then angle = TWO_PI - angle; axis = -axis end
	return axis * angle
end
local function flipR(v: Vector3): Vector3
	local a = v.Magnitude
	if a < 1e-12 then return v end
	return -(v / a) * (TWO_PI - a)
end
local function pairOf(a: Vector3, b: Vector3): (Vector3, Vector3)
	local TIE = 1e-5
	local fa, fb = flipR(a), flipR(b)
	local best, pa, pb = (a - b).Magnitude, a, b
	local d = (fa - b).Magnitude; if d < best - TIE then best, pa, pb = d, fa, b end
	d = (a - fb).Magnitude;       if d < best - TIE then best, pa, pb = d, a, fb end
	d = (fa - fb).Magnitude;      if d < best - TIE then pa, pb = fa, fb end
	return pa, pb
end
local function quatOf(v: Vector3): (number, number, number, number)
	local a = v.Magnitude
	if a < 1e-12 then return 0, 0, 0, 1 end
	local s = math.sin(a / 2) / a
	return v.X * s, v.Y * s, v.Z * s, math.cos(a / 2)
end
local function qlog(x: number, y: number, z: number, w: number): Vector3
	local s = math.sqrt(x * x + y * y + z * z)
	if s < 1e-12 then return Vector3.zero end
	return Vector3.new(x, y, z) * (2 * math.atan2(s, w) / s)
end
local function cfOfRV(rv: Vector3, p: Vector3): CFrame
	local a = rv.Magnitude
	if a < 1e-12 then return CFrame.new(p) end
	return CFrame.fromAxisAngle(rv / a, a) + p
end

-- float32 time, like the Animator (measured): a float64 clock ends some clips one frame late
local F32 = buffer.create(4)
local function f32(x: number): number
	buffer.writef32(F32, 0, x)
	return buffer.readf32(F32, 0)
end

-- ================================================================ clips
type JointKeys = {
	n: number, h: number,                                   -- key count, cached segment index
	t: { number }, rv: { Vector3 }, p: { Vector3 },
	style: { Enum.PoseEasingStyle }, dir: { Enum.PoseEasingDirection },
	va: { Vector3 }, vb: { Vector3 },                       -- per-segment closest rotation-vector pairs
}
type Event = { t: number, name: string, value: string, marker: boolean }
export type Clip = { name: string, length: number, loop: boolean, priority: Enum.AnimationPriority,
	nlerp: boolean, joints: { [string]: JointKeys }, events: { Event } }

local clipCache: { [KeyframeSequence]: Clip } = setmetatable({}, { __mode = "k" }) :: any

local function parse(ks: KeyframeSequence): Clip
	local cached = clipCache[ks]
	if cached then return cached end
	local kfs = ks:GetKeyframes() :: { Keyframe }
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	local joints: { [string]: JointKeys } = {}
	local events: { Event } = {}
	local length, allLinear = 0, true

	local function walk(parent: Instance, t: number)
		for _, c in parent:GetChildren() do
			if not c:IsA("Pose") then continue end
			local pose = c :: Pose
			if pose.Weight > 0 then
				local j = joints[pose.Name]
				if not j then
					j = { n = 0, h = 1, t = {}, rv = {}, p = {}, style = {}, dir = {}, va = {}, vb = {} }
					joints[pose.Name] = j
				end
				local jk = j :: JointKeys
				jk.n += 1
				jk.t[jk.n], jk.rv[jk.n], jk.p[jk.n] = t, logR(pose.CFrame), pose.CFrame.Position
				jk.style[jk.n], jk.dir[jk.n] = pose.EasingStyle, pose.EasingDirection
			end
			walk(pose, t)
		end
	end
	for _, kf in kfs do
		length = math.max(length, kf.Time)
		if kf.Name ~= "Keyframe" then table.insert(events, { t = kf.Time, name = kf.Name, value = "", marker = false }) end
		for _, m in kf:GetMarkers() do
			local km = m :: KeyframeMarker
			table.insert(events, { t = kf.Time, name = km.Name, value = km.Value, marker = true })
		end
		for _, top in kf:GetChildren() do
			if top:IsA("Pose") then walk(top, kf.Time) end      -- the top-level pose itself is never applied
		end
	end
	for _, j in joints do
		for i = 1, j.n - 1 do
			if j.style[i] ~= PS.Linear then allLinear = false end
			j.va[i], j.vb[i] = pairOf(j.rv[i], j.rv[i + 1])
		end
	end
	local even = true
	if #kfs > 2 then
		local step = kfs[2].Time - kfs[1].Time
		for i = 3, #kfs do
			if math.abs((kfs[i].Time - kfs[i - 1].Time) - step) > 1e-4 then even = false; break end
		end
	end
	table.sort(events, function(a, b) return a.t < b.t end)
	local clip: Clip = { name = ks.Name, length = length, loop = ks.Loop, priority = ks.Priority,
		nlerp = even and allLinear, joints = joints, events = events }
	clipCache[ks] = clip
	return clip
end

-- Returns the joint's rotation vector and offset at time t (the representation matters once a weight
-- below 1 scales the rotation vector, so we return the vector, not a CFrame).
local function sample(clip: Clip, j: JointKeys, t: number, scale: number): (Vector3, Vector3)
	local n = j.n
	local rv: Vector3, p: Vector3
	if n == 1 then
		rv, p = j.rv[1], j.p[1]
	elseif t <= j.t[1] then
		rv, p = clip.nlerp and j.rv[1] or j.va[1], j.p[1]
	elseif t >= j.t[n] then
		rv, p = clip.nlerp and j.rv[n] or j.vb[n - 1], j.p[n]
	else
		local lo = j.h
		if not (lo < n and j.t[lo] <= t and j.t[lo + 1] > t) then   -- cached segment missed: binary search
			local a, b = 1, n
			while b - a > 1 do
				local mid = (a + b) // 2
				if j.t[mid] <= t then a = mid else b = mid end
			end
			lo = a
			j.h = lo
		end
		local hi = lo + 1
		local u = (t - j.t[lo]) / (j.t[hi] - j.t[lo])
		local a = ease(j.style[lo], j.dir[lo], u)
		if clip.nlerp then
			local ax, ay, az, aw = quatOf(j.rv[lo])
			local bx, by, bz, bw = quatOf(j.rv[hi])
			if ax * bx + ay * by + az * bz + aw * bw < 0 then bx, by, bz, bw = -bx, -by, -bz, -bw end
			local x, y, z, w = ax + (bx - ax) * a, ay + (by - ay) * a, az + (bz - az) * a, aw + (bw - aw) * a
			local len = math.sqrt(x * x + y * y + z * z + w * w)
			rv = qlog(x / len, y / len, z / len, w / len)
		else
			rv = j.va[lo]:Lerp(j.vb[lo], a)
		end
		p = j.p[lo]:Lerp(j.p[hi], a)
	end
	if scale ~= 1 then p *= scale end
	return rv, p
end

-- ================================================================ rigs and tracks
type Rig = {
	model: Model,
	joints: { [string]: Instance },      -- Part1 / Bone name -> joint
	dirty: boolean,
	tracks: { any },
	written: { [Instance]: CFrame },
	conns: { RBXScriptConnection },
	rate: number, phase: number,
	important: boolean,                  -- always full rate (own character, cutscene boss)
}
local rigs: { [Model]: Rig } = {}
local seqCounter = 0
local pending: { { any } } = {}         -- events fired after the frame's writes

local function scan(r: Rig)
	table.clear(r.joints)
	for _, d in r.model:GetDescendants() do
		if d:IsA("Motor6D") then
			local p1 = d.Part1
			if p1 then r.joints[p1.Name] = d end
		elseif d:IsA("AnimationConstraint") then
			local a1 = d.Attachment1
			local p1 = a1 and a1.Parent
			if p1 then r.joints[p1.Name] = d end
		elseif d:IsA("Bone") then
			r.joints[d.Name] = d
		end
	end
	r.dirty = false
end

local function rigOf(model: Model): Rig
	local r = rigs[model]
	if r then return r end
	local nr: Rig = { model = model, joints = {}, dirty = true, tracks = {}, written = {}, conns = {},
		rate = 1, phase = math.random(0, 14), important = false }
	local function mark(d: Instance)
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") or d:IsA("Bone") then nr.dirty = true end
	end
	table.insert(nr.conns, model.DescendantAdded:Connect(mark))
	table.insert(nr.conns, model.DescendantRemoving:Connect(mark))
	table.insert(nr.conns, model.Destroying:Connect(function()
		for _, c in nr.conns do c:Disconnect() end
		rigs[model] = nil
	end))
	rigs[model] = nr
	return nr
end

local function rank(p: Enum.AnimationPriority): number
	return p == Enum.AnimationPriority.Core and -1 or p.Value   -- Core is 1000 but blends lowest
end

local Track = {}
Track.__index = Track

function Track.Play(self: any, fade: number?, weight: number?, speed: number?)
	local f = fade or 0.1
	if not self._active then
		self.WeightCurrent = 0
		self._active = true
		table.insert(self._rig.tracks, self)
	end
	seqCounter += 1
	self._seq = seqCounter                  -- later plays sit above earlier ones of the same priority
	self.TimePosition = 0                   -- Play restarts at 0 (measured)
	self._fresh = true
	self.IsPlaying = true
	self._stoppedEarly = false
	self.Speed = speed or 1
	self.WeightTarget = weight or 1
	self._fadeRate = f > 0 and math.abs(self.WeightTarget - self.WeightCurrent) / f or math.huge
end

function Track.Stop(self: any, fade: number?)
	if not self._active then return end
	local f = fade or 0.1
	if self.IsPlaying then
		self.IsPlaying = false
		self._stoppedEarly = true           -- time keeps running during this fade (measured)
		table.insert(pending, { self.Stopped })
	end
	self.WeightTarget = 0
	self._fadeRate = f > 0 and self.WeightCurrent / f or math.huge
end

function Track.AdjustSpeed(self: any, speed: number?)
	self.Speed = speed or 1
end

function Track.AdjustWeight(self: any, weight: number?, fade: number?)
	local f = fade or 0.1
	self.WeightTarget = weight or 1
	self._fadeRate = f > 0 and math.abs(self.WeightTarget - self.WeightCurrent) / f or math.huge
end

function Track.GetMarkerReachedSignal(self: any, name: string)
	local s = self._markers[name]
	if not s then s = newSignal(); self._markers[name] = s end
	return s
end

function Track.GetTimeOfKeyframe(self: any, name: string): number
	for _, e in self._clip.events do
		if not e.marker and e.name == name then return e.t end
	end
	error("no keyframe named " .. name)
end

-- Load a clip onto a model. Returns an AnimationTrack-like object.
function KeyframePlayer.Load(model: Model, ks: KeyframeSequence): any
	local clip = parse(ks)
	return setmetatable({
		Name = clip.name, Length = clip.length, Looped = clip.loop, Priority = clip.priority,
		TimePosition = 0, Speed = 1, IsPlaying = false, WeightCurrent = 0, WeightTarget = 0,
		Stopped = newSignal(), Ended = newSignal(), DidLoop = newSignal(), KeyframeReached = newSignal(),
		_clip = clip, _rig = rigOf(model), _markers = {}, _active = false, _fresh = false,
		_stoppedEarly = false, _fadeRate = 0, _seq = 0,
	}, Track)
end

-- ================================================================ time, fades, events
local function fireEvents(tr: any, a: number, b: number)
	for _, e in tr._clip.events do
		if e.t > a and e.t <= b then
			if e.marker then
				local s = tr._markers[e.name]
				if s then table.insert(pending, { s, e.value }) end
			else
				table.insert(pending, { tr.KeyframeReached, e.name })
			end
		elseif e.t > b then
			break
		end
	end
end

local function advance(tr: any, dt: number)
	-- linear fades
	if tr.WeightCurrent ~= tr.WeightTarget then
		local step = tr._fadeRate * dt
		local d = tr.WeightTarget - tr.WeightCurrent
		if step >= math.abs(d) then tr.WeightCurrent = tr.WeightTarget
		elseif d > 0 then tr.WeightCurrent += step
		else tr.WeightCurrent -= step end
	end
	local len = tr.Length
	if tr.IsPlaying then
		local t0 = tr._fresh and -1 or tr.TimePosition          -- -1: events at exactly 0 fire on the first frame
		tr._fresh = false
		local t1 = f32(math.max(tr.TimePosition, 0) + f32(dt * tr.Speed))
		if tr.Looped and len > 0 then
			if t1 >= len then
				fireEvents(tr, t0, len)
				t1 %= len
				table.insert(pending, { tr.DidLoop })
				fireEvents(tr, -1, t1)
			else
				fireEvents(tr, t0, t1)
			end
			tr.TimePosition = t1
		elseif t1 >= len then
			-- a one-shot reached its end: hold the last pose and fade out over END_FADE (measured)
			fireEvents(tr, t0, len)
			tr.TimePosition = len
			tr.IsPlaying = false
			tr.WeightTarget = 0
			tr._fadeRate = tr.WeightCurrent / END_FADE
			table.insert(pending, { tr.Stopped })
		else
			fireEvents(tr, t0, t1)
			tr.TimePosition = t1
		end
	elseif tr.WeightCurrent <= 0 and tr.WeightTarget <= 0 then
		tr._active = false
		table.insert(pending, { tr.Ended })
	elseif tr._stoppedEarly then
		local t1 = f32(math.max(tr.TimePosition, 0) + f32(dt * tr.Speed))
		tr.TimePosition = (tr.Looped and len > 0) and t1 % len or math.min(t1, len)
	end
end

-- ================================================================ the mixer
type Acc = {
	rem: number, remP: number,       -- weight left for lower priorities (rotation / offset)
	E: number, EP: number,           -- total weight taken (rotation / offset)
	n: number, rv1: Vector3,         -- first contribution, kept as a rotation vector
	qx: number, qy: number, qz: number, qw: number, hasQ: boolean,   -- weighted quaternion sum
	p: Vector3,
}
local acc: { [string]: Acc } = {}
local groupS: { [string]: number } = {}
local groupSP: { [string]: number } = {}

local function stepRig(r: Rig, dt: number, write: boolean)
	if r.dirty then scan(r) end
	local tracks = r.tracks
	local i = 1
	while i <= #tracks do
		advance(tracks[i], dt)
		if tracks[i]._active then i += 1 else table.remove(tracks, i) end
	end
	if not write then return end

	table.sort(tracks, function(a, b)
		local ra, rb = rank(a.Priority), rank(b.Priority)
		if ra ~= rb then return ra > rb end      -- highest priority first
		return a._seq > b._seq                   -- then the most recently played
	end)
	local scale = r.model:GetScale()
	table.clear(acc)

	local g = 1
	while g <= #tracks do
		-- one priority group: tracks[g .. h]
		local h = g
		local rk = rank(tracks[g].Priority)
		while h + 1 <= #tracks and rank(tracks[h + 1].Priority) == rk do h += 1 end
		table.clear(groupS); table.clear(groupSP)
		for k = g, h do
			local w = tracks[k].WeightCurrent
			if w > 0 then
				for name in tracks[k]._clip.joints do
					if r.joints[name] then
						groupS[name] = (groupS[name] or 0) + w
						groupSP[name] = (groupSP[name] or 0) + math.min(w, 1)
					end
				end
			end
		end
		for k = g, h do
			local tr = tracks[k]
			local w = tr.WeightCurrent
			if w <= 0 then continue end
			for name, keys in tr._clip.joints do
				if not r.joints[name] then continue end
				local a = acc[name]
				if not a then
					a = { rem = 1, remP = 1, E = 0, EP = 0, n = 0, rv1 = Vector3.zero,
						qx = 0, qy = 0, qz = 0, qw = 0, hasQ = false, p = Vector3.zero }
					acc[name] = a
				end
				local ac = a :: Acc
				if ac.rem <= 0 then continue end
				-- hand out what is left (measured rule)
				local S, SP = groupS[name], groupSP[name]
				local e = (S <= ac.rem) and w or w * ac.rem / math.min(S, 1)
				local wp = math.min(w, 1)
				local ep = (SP <= ac.remP) and wp or wp * ac.remP / math.min(SP, 1)
				local rv, p = sample(tr._clip, keys, tr.TimePosition, scale)
				if ac.n == 0 then
					ac.rv1 = rv
				else
					if not ac.hasQ then                    -- start the quaternion sum from the first contribution
						local x, y, z, ww = quatOf(ac.rv1)
						ac.qx, ac.qy, ac.qz, ac.qw, ac.hasQ = x * ac.E, y * ac.E, z * ac.E, ww * ac.E, true
					end
					local x, y, z, ww = quatOf(rv)
					local sg = (ac.qx * x + ac.qy * y + ac.qz * z + ac.qw * ww < 0) and -e or e   -- same hemisphere
					ac.qx += x * sg; ac.qy += y * sg; ac.qz += z * sg; ac.qw += ww * sg
				end
				ac.p += p * ep
				ac.E += e
				ac.EP += ep
				ac.n += 1
			end
		end
		for name, S in groupS do                           -- this priority has taken its share
			local a = acc[name]
			if a then
				a.rem = (S <= a.rem) and (a.rem - S) or 0
				local SP = groupSP[name]
				a.remP = (SP <= a.remP) and (a.remP - SP) or 0
			end
		end
		g = h + 1
	end

	-- write
	local touched: { [Instance]: boolean } = {}
	for name, a in acc do
		local joint = r.joints[name]
		if not joint or a.E <= 0 then continue end
		local p = a.EP > 1 and a.p / a.EP or a.p
		local rv: Vector3
		if a.hasQ then
			local len = math.sqrt(a.qx ^ 2 + a.qy ^ 2 + a.qz ^ 2 + a.qw ^ 2)
			rv = len < 1e-12 and Vector3.zero or qlog(a.qx / len, a.qy / len, a.qz / len, a.qw / len)
		else
			rv = a.rv1
		end
		if a.E < 1 then rv *= a.E end                      -- less than full weight: blend toward rest
		local cf = cfOfRV(rv, p)
		;(joint :: any).Transform = cf
		r.written[joint] = cf
		touched[joint] = true
	end
	-- hand joints we no longer drive back to rest (unless someone else wrote them since)
	for joint, cf in r.written do
		if not touched[joint] then
			local cur = (joint :: any).Transform :: CFrame
			if joint.Parent and cur:FuzzyEq(cf, 1e-4) then (joint :: any).Transform = CFrame.identity end
			r.written[joint] = nil
		end
	end
end

-- ================================================================ the loop (one connection for every rig)
local frame = 0
local function lodRate(r: Rig, camPos: Vector3): number
	if r.important then return 1 end
	local pp = r.model.PrimaryPart
	if not pp then return 1 end
	local d = (pp.Position - camPos).Magnitude
	if d <= NEAR then return 1 elseif d <= MID then return 2 elseif d <= FAR then return 4 end
	return 0                                               -- time only
end

-- PreSimulation: after the engine Animator has written its joints, before physics uses them.
-- (In Edit nothing simulates; drive KeyframePlayer.Step yourself from a plugin or the command bar.)
RunService.PreSimulation:Connect(function(dt: number)
	frame += 1
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for model, r in rigs do
		if #r.tracks == 0 and next(r.written) == nil then continue end        -- idle rig: nothing to do
		if (frame + r.phase) % 15 == 0 then r.rate = lodRate(r, camPos) end   -- re-tier, staggered
		-- with no tracks left, write once so joints we drove are handed back to rest
		local write = (r.rate ~= 0 and (frame + r.phase) % r.rate == 0) or #r.tracks == 0
		stepRig(r, dt, write)                                -- time and events ALWAYS advance
	end
	-- fire events after every write, so handlers see this frame's pose
	local list = pending
	pending = {}
	for _, ev in list do
		local sig = ev[1]
		Signal.Fire(sig, table.unpack(ev, 2))
	end
end)

-- Manual stepping (Edit-mode tests, filmstrips). Does not fire through the loop above.
function KeyframePlayer.Step(model: Model, dt: number)
	local r = rigs[model]
	if r then stepRig(r, dt, true) end
end

-- Mark a rig as always full rate (own character, boss in a cutscene).
function KeyframePlayer.SetImportant(model: Model, on: boolean)
	local r = rigOf(model)
	r.important = on
	if on then r.rate = 1 end                     -- take effect now, not at the next re-tier
end

return KeyframePlayer
```

---

## 2. Notes on the design

**Time and events always advance; LOD only skips writes.** A far rig's `Hit` still fires on time, its loops stay in phase, and when it comes back into range it is in the right pose. See [[Animation LOD]].

**Events fire after writes.** Marker handlers often read the pose (to spawn an effect at the hand). Queuing them until after the frame's writes means they see this frame's pose, and a handler that stops or starts tracks cannot disturb the mixer mid-loop.

**Why `sample` returns rotation vectors.** With full weight the representation does not matter, but a lone track at weight 0.5 scales its rotation vector toward rest, and `v` and `v - 2*pi*axis` scale to different rotations. The Animator holds a specific representation (measured), so the sampler preserves it rather than round-tripping through a CFrame.

**The mixer is per joint.** A priority that keys only the right arm takes the arm's weight and leaves the legs' weight for lower priorities. That is upper-body layering for free.

**`PreSimulation`.** It runs after the engine's animation step (Docs frame order), so tracks played by the real Animator and by this player can coexist on one rig, with this player writing last. The reference version went further: joints written by another writer this frame are used as the base for the leftover weight, instead of rest. This compact core blends toward rest, so do not split one joint between the engine Animator and this player.

**`SetImportant`.** Distance is the wrong metric for a few rigs: your own character (the camera may be far behind it in a cinematic), the boss you are fighting, anything in a cutscene. The flag forces full rate regardless of range.

**Edit mode.** `Transform` does not move parts without simulation, and `PreSimulation` behaviour in Edit is not something to rely on. For tests, call `KeyframePlayer.Step(model, 1/60)` and read the `Transform`s, or compute FK ([[Snippets - Building and Sampling Clips]]).

---

## 3. What the full version adds

The reference project's production player added, on top of this core:
- **Published-id passthrough.** `LoadAnimation(animator, anim)` returns a real `AnimationTrack` when the `Animation` has a published id, so publishing a clip later needs no code change.
- **A Studio-only token scheme** (`ksp://<n>`) so code written for `KeyframeSequenceProvider` ids keeps working.
- **Composition with a procedural animator**: clips at Movement priority and below are left to a custom locomotion system, Action and above play over its pose.
- **Replication** of local-character tracks through a batched, throttled relay; late joiners request the active tracks.
- **Baked stubs and a binary clip format** (smallest-three quaternions, per-joint thinning at 0.03 degrees), so clips cost a single attribute instead of thousands of Pose instances. See [[Clip Buffer Format]] and [[Baked Clip Stubs and Archiving]].
- **An A/B switch** to play through the real Animator in Studio for comparison.
- **Off-screen culling** (time only, re-checked every 3 frames) and an after-step hook for ground fitting.

## Checklist before trusting your own player
- [ ] A/B against `Animator:StepAnimations` on a few clips: uneven and evenly keyed, Linear and eased, big turns far from rest, two and five tracks blended. Max error well under 1 degree.
- [ ] Markers: every marker fires exactly once per pass, including at time 0 and at the clip's end, and on loop wrap.
- [ ] Stop during a fade, Play during a fade, Play while playing (restart), AdjustWeight while fading.
- [ ] Rig changes: a joint added or removed while playing.
- [ ] Cost: MicroProfiler with 50 rigs; no per-frame allocation in the mixer beyond the `touched` table.

## See also
[[Lua Keyframe Player]] · [[Lua Keyframe Player Internals]] · [[How the Animator Really Behaves]] · [[Snippets - Building and Sampling Clips]] · [[Weapon Rig Player]] · [[Animation LOD]] · [[Clip Buffer Format]] · [[Testing Animations in Studio]]

## Nuances and edge cases

1. **When not to build one.** A custom player is a long-lived maintenance commitment. If your clips can all be published to the experience's owner (user or group) and your team accepts the publish step, the engine Animator is cheaper, replicates for free and benefits from engine improvements. The custom player earns its cost when you have hundreds of clips that change weekly, generated or procedurally composed clips, or a need for identical behaviour in Studio and live without publishing.
2. **Replication is now your problem.** Engine tracks played by the owning client replicate to others; `Transform` writes from Lua do not replicate at all. Every viewer must run the player and be told what to play. At 1 player that is invisible; at 50 players with 10 tracks each changing a few times a second, a naive "send every Play" relay is easily hundreds of events per second. Batch per frame, coalesce restarts, and throttle per sender.
3. **Late joiners and streaming.** A client that joins or streams a rig in mid-clip has no history. The relay must answer "what is playing on this rig, at what time position, weight and speed" on request, or rigs pop into rest pose until the next clip starts.
4. **Float32 time.** Track time stored in float32 loses millisecond precision after roughly 2 to 3 hours of continuous accumulation on a looping track (float32 has about 7 significant digits). Wrap time modulo clip length on loop instead of accumulating forever, as the engine appears to do.
5. **Cost scales with rigs times bones, not players.** About 22 microseconds per 25-bone rig per frame (measured in the reference project) means 100 visible rigs cost 2.2 ms per frame on a desktop CPU. A low-end phone may be 3 to 5 times slower (rule of thumb), which is 7 to 11 ms, most of a 30 FPS frame. LOD that skips writes for distant rigs is not optional on mobile.
6. **Parallel Luau.** Sampling is pure math per rig and fits Actors well, but `Transform` writes must happen in serial. A split of "sample in parallel, write in serial" can halve the cost at high rig counts; below about 30 rigs, the synchronisation overhead usually eats the gain.
7. **Engine behaviour can change.** The measured rules (reversed legacy `Cubic`, linear fades, 0.3 s end fade) are observations, not documented contracts. Re-run the A/B suite after major Roblox releases; a silent engine fix turns your faithful copy into a divergence.
8. **Scale and avatar body types.** Translations scale with `Model:GetScale()`, but R15 avatars with non-default proportions (body type, height scale) shift joint offsets. Clips authored on a default rig and applied to a tall avatar still play correctly because `Transform` is relative to `C0`/`C1`, but root height and ground contact do not; foot IK or a root offset may be needed.

## Common mistakes

1. **Writing `Transform` from `RenderStepped`.** Symptom: the pose is one frame late or fights the Animator. Fix: write in `PreSimulation`, after the engine's animation step.
2. **Firing markers inside the mixer loop.** Symptom: a handler that starts a track corrupts the iteration, random missing poses. Fix: queue events and fire after writes, as above.
3. **No cleanup when a rig is destroyed.** Symptom: memory climbs per respawn, errors on parented-nil joints. Fix: listen to `Destroying` and drop the rig's state.
4. **Trusting it without A/B.** Symptom: subtle wrist flips on big rotations that only animators notice. Fix: run the checklist against `Animator:StepAnimations` before shipping and after engine updates.
5. **Treating LOD as time skip.** Symptom: far rigs desync, markers never fire, loops drift out of phase. Fix: always advance time and events; only skip writes.
6. **Per-frame table allocation.** Symptom: GC spikes every few seconds visible in the MicroProfiler. Fix: reuse scratch tables for the mixer and sample results.

## Related decisions

- [[Parallel Luau and Actors]]: splitting sampling from writes across Actors.
- [[Luau Performance Patterns with Benchmarks]]: the allocation and math patterns that keep the mixer cheap.
- [[Luau Garbage Collection and the Memory Model]]: why scratch tables beat fresh ones per frame.
- [[Network Bandwidth Budgets and Measuring Them]]: sizing the relay that replicates Lua-played tracks.
- [[Buffers and Binary Data]]: packing clip data and relay messages compactly.
- [[Interest Management and Per-Player Replication]]: only relaying tracks to clients that can see the rig.
- [[Automated Testing with TestEZ and Jest-Lua]]: running the A/B suite as automated tests.
- [[Avatar Body Types and Scale in Gameplay]]: why clips authored on one body need checks on others.

## Connected notes
<!-- auto-links:start -->
[[Engine Gotchas]] · [[AnimationTrack Reference]] · [[Debugging Animation Problems]] · [[Replication and Ownership]] · [[AI Animation and Motion from Video]] · [[Script Performance]] · [[Animation Start Here]]
<!-- auto-links:end -->
