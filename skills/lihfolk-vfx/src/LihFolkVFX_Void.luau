--!strict
--[[
	LihFolkVFX_Void: void hit burst + void orb charge/release (client only). UNTESTED IN STUDIO.

	Separate module next to LihFolkVFX.luau (same helpers and conventions, no shared state).

	  Void.VoidImpact(cf, opts)            radial hit burst at cf (cf.UpVector = surface normal, cf.Position = contact)
	  local h = Void.VoidOrbCharge(att, opts) black void orb held at an Attachment (loops until released)
	  h:Release(targetCF?)                 implode (0.14 s) then pop into a small VoidImpact (at targetCF, else at the orb)
	  h:Cancel()                           shrink out quietly, no burst

	VoidImpact layers (t = seconds after the call)
	  flash      white-blue star + core blob, 0-0.09 (2-3 frames), Brightness 6, ZOffset above everything
	  rim        blue soft glow between core and ink, 0-0.2
	  streaks    10-16 long thin white Beams shooting out radially (4-6 frames), varied length/reach, some
	             leave the screen; head eases out, tail catches up so each streak shrinks to nothing
	  ink        dark navy flat splatter on the ground (VelocityPerpendicular) + ragged ink puffs pushed out
	             radially, LightEmission 0 so they darken bright snow; linger and dissipate 0.55-0.85
	  flakes     white feathered shards flung up and out, tumbling, light gravity
	  debris     small black square flecks, heavier gravity
	  light      PointLight 3 -> 0 over 0.18
	VoidOrb layers
	  body       Neon black Ball (pure black), ForceField shell tinted rim colour (animated fresnel),
	             BillboardGui ring (void_rim_ring) for the bright indigo-to-white rim from every angle
	  ribbons    7 crescent ribbons orbiting at different tilts/speeds; each = 3 Trails: body (void_ribbon,
	             white-hot head -> lavender -> deep indigo tail, WidthScale taper), thin white-hot core,
	             dark ink wisp (void_ink_wisp, LightEmission 0, longer life) trailing behind
	  sparks     hot-pink glints popping off the surface
	  pull-in    lavender motes + ink wisps from a 2.6R sphere shell moving inward (ShapeInOut Inward)
	  release    orb + ribbons implode to 15 % over 0.14 s (ribbons speed up), pull burst, then the orb
	             vanishes and a VoidImpact (scale 0.55) pops: at targetCF (ground burst) or, with no
	             target, at the orb as an airburst (no ground splat, spherical spray)

	Budget (quality 1; counts scale with quality, mobile default 0.6)
	  VoidImpact: 1 Part, 1 PointLight, 7 ParticleEmitters, 31 Attachments, 14 Beams;
	              ~53 particles (2 flash + 1 core + 2 rim + 2 splat + 14 puffs + 14 flakes + 18 flecks),
	              Heartbeat for 0.24 s, everything gone by 1.0 s (Debris 1.3 s safety).
	  VoidOrb hold: 3 Parts (orb, shell, pull shell), 1 BillboardGui, 1 PointLight, 21 Trails,
	              42 Attachments, 3 emitters (~16 live particles), one Heartbeat while alive.
	  Release adds one VoidImpact at scale 0.55.

	Element tint: opts.tint = Color3 rebuilds the whole palette around that hue (default = indigo/blue void);
	opts.palette = a full VoidPalette overrides everything.

	Textures: upload VFX/Textures/*.png (void_* from tools/void/build_textures_void.py, plus the shared
	flash_hot, glow_soft, glint_star4, spark_square) and replace "rbxassetid://REPLACE_ME".
	A layer whose id is still REPLACE_ME is skipped with one warning (Beams and Parts need no texture).
]]

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Void = {}

Void.Textures = {
	void_ink_splat = "rbxassetid://REPLACE_ME",
	void_ink_puff = "rbxassetid://REPLACE_ME",
	void_flake = "rbxassetid://REPLACE_ME",
	void_ribbon = "rbxassetid://REPLACE_ME",
	void_ink_wisp = "rbxassetid://REPLACE_ME",
	void_rim_ring = "rbxassetid://REPLACE_ME",
	flash_hot = "rbxassetid://REPLACE_ME",
	glow_soft = "rbxassetid://REPLACE_ME",
	glint_star4 = "rbxassetid://REPLACE_ME",
	spark_square = "rbxassetid://REPLACE_ME",
}

Void.Config = {
	quality = 1, -- 0..1, scales every Emit count / Rate
}
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	Void.Config.quality = 0.6
end

export type VoidPalette = {
	core: Color3, -- blown-out flash / ribbon head
	rim: Color3, -- blue rim glow
	body: Color3, -- ribbon body (lavender)
	edge: Color3, -- ribbon edge / tail (deep indigo)
	ink: Color3, -- dark ink smoke
	inkLight: Color3, -- ink as it thins out
	spark: Color3, -- hot-pink glints
	flake: Color3, -- white feathered shards
	debris: Color3, -- black flecks
}

local rgb = Color3.fromRGB
Void.DefaultPalette = {
	core = rgb(236, 243, 255),
	rim = rgb(88, 122, 255),
	body = rgb(176, 150, 255),
	edge = rgb(56, 38, 168),
	ink = rgb(4, 6, 26),
	inkLight = rgb(44, 78, 215),
	spark = rgb(255, 82, 192),
	flake = rgb(205, 222, 255),
	debris = rgb(6, 6, 14),
} :: VoidPalette

-- one Color3 -> full palette around its hue (keeps the void value structure: black ink, hot core)
function Void.paletteFromTint(tint: Color3): VoidPalette
	local h, s, _v = tint:ToHSV()
	local hsv = Color3.fromHSV
	return {
		core = Color3.new(1, 1, 1):Lerp(tint, 0.08),
		rim = hsv(h, math.min(1, s * 0.7 + 0.1), 1),
		body = hsv((h + 0.04) % 1, math.clamp(s * 0.42, 0.15, 0.5), 1),
		edge = hsv((h + 0.03) % 1, math.min(1, s * 0.9 + 0.1), 0.66),
		ink = hsv(h, 0.85, 0.1),
		inkLight = hsv(h, 0.82, 0.66),
		spark = Void.DefaultPalette.spark,
		flake = Color3.new(1, 1, 1):Lerp(tint, 0.2),
		debris = hsv(h, 0.5, 0.055),
	}
end

-------------------------------------------------------------------------------
-- helpers (same shapes as LihFolkVFX.luau)
-------------------------------------------------------------------------------
local warned: { [string]: boolean } = {}
local function warnOnce(key: string, msg: string)
	if not warned[key] then
		warned[key] = true
		warn("[LihFolkVFX_Void] " .. msg)
	end
end

local function tex(key: string): string?
	local id = (Void.Textures :: any)[key]
	if type(id) == "string" and id ~= "" and not string.find(id, "REPLACE_ME", 1, true) then
		return id
	end
	warnOnce("tex:" .. key, "texture '" .. key .. "' has no id yet; that layer is skipped")
	return nil
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function easeOut(x: number, p: number): number
	return 1 - (1 - clamp01(x)) ^ p
end

local function easeIn(x: number, p: number): number
	return clamp01(x) ^ p
end

local function easeOutBack(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	local u = clamp01(x) - 1
	return 1 + c3 * u ^ 3 + c1 * u ^ 2
end

local function ns(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end

local function cs(points: { { any } }): ColorSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, ColorSequenceKeypoint.new(p[1] :: number, p[2] :: Color3))
	end
	return ColorSequence.new(kps)
end

local function newPart(name: string, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function newAttachment(name: string, pos: Vector3, parent: Instance): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = parent
	return a
end

-- emitter with a texture key; returns nil (layer skipped) while the id is not uploaded
local function newEmitter(parent: Instance, texKey: string, props: { [string]: any }): ParticleEmitter?
	local id = tex(texKey)
	if not id then
		return nil
	end
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.LightInfluence = 0
	e.LockedToPart = false
	e.VelocityInheritance = 0
	e.Texture = id
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function emit(e: ParticleEmitter?, n: number, q: number)
	if e then
		e:Emit(math.max(1, math.round(n * q)))
	end
end

local container: Folder? = nil
local function getContainer(): Folder
	local c = container
	if c and c.Parent then
		return c
	end
	local f = Instance.new("Folder")
	f.Name = "LihFolkVoidFX"
	f.Parent = Workspace
	container = f
	return f
end

local function resolvePalette(tint: Color3?, palette: VoidPalette?): VoidPalette
	if palette then
		return palette
	elseif tint then
		return Void.paletteFromTint(tint)
	end
	return Void.DefaultPalette
end

-------------------------------------------------------------------------------
-- VoidImpact
-------------------------------------------------------------------------------
export type ImpactOptions = {
	scale: number?, -- 1 = ~12 stud ink cloud, streaks reach 12-30 studs
	tint: Color3?,
	palette: VoidPalette?,
	quality: number?, -- overrides Void.Config.quality
	streaks: number?, -- default 14
	light: boolean?, -- default true
	airburst: boolean?, -- mid-air pop (orb release): no ground splat; cf.UpVector = burst direction, ink biased along it
	parent: Instance?,
}

Void.Impact = {
	flashLife = 0.085, -- 2-3 frames at 30 fps
	rimLife = 0.2,
	streakLife = { 0.13, 0.2 }, -- 4-6 frames
	streakLen = { 6, 16 },
	streakExtra = { 6, 15 }, -- reach beyond the length
	streakElev = { 4, 48 }, -- degrees above the surface plane
	inkLife = { 0.6, 0.85 },
	splatSize = { 6, 16, 18 }, -- start, at 12 % life, end
	puffSpeed = { 14, 26 },
	flakeSpeed = { 18, 34 },
	debrisSpeed = { 16, 40 },
}

local function streakDir(elevMin: number, elevMax: number, pow: number): Vector3
	local az = math.random() * 2 * math.pi
	local el = math.rad(elevMin + (elevMax - elevMin) * math.random() ^ pow)
	return Vector3.new(math.cos(el) * math.cos(az), math.sin(el), math.cos(el) * math.sin(az))
end

type Streak = { a0: Attachment, a1: Attachment, beam: Beam, dir: Vector3, len: number, reach: number, life: number }

function Void.VoidImpact(cf: CFrame, opts: ImpactOptions?)
	local o: ImpactOptions = opts or {}
	local s = o.scale or 1
	local q = clamp01(o.quality or Void.Config.quality)
	local pal = resolvePalette(o.tint, o.palette)
	local cfgI = Void.Impact
	local air = o.airburst == true
	local spread = if air then 70 else 84
	local holder = newPart("VoidImpact", cf, o.parent or getContainer())
	local up = cf.UpVector
	local center = newAttachment("Center", Vector3.new(0, (if air then 1.4 else 0.6) * s, 0), holder)
	local floor = newAttachment("Floor", Vector3.new(0, 0.06, 0), holder)

	-- flash (star + blown-out core blob), drawn above everything
	local flash = newEmitter(center, "flash_hot", {
		Color = ColorSequence.new(pal.core),
		LightEmission = 1,
		Brightness = 4,
		Size = ns({ { 0, 4 * s }, { 0.5, 6 * s }, { 1, 3.5 * s } }),
		Transparency = ns({ { 0, 0 }, { 0.6, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(cfgI.flashLife),
		Rotation = NumberRange.new(0, 360),
		Speed = NumberRange.new(0),
		ZOffset = 3,
	})
	local core = newEmitter(center, "glow_soft", {
		Color = ColorSequence.new(pal.core),
		LightEmission = 1,
		Brightness = 4,
		Size = ns({ { 0, 3 * s }, { 1, 4 * s } }),
		Transparency = ns({ { 0, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(cfgI.flashLife * 1.2),
		Speed = NumberRange.new(0),
		ZOffset = 2.5,
	})
	-- blue rim glow between the core and the ink
	local rim = newEmitter(center, "glow_soft", {
		Color = ColorSequence.new(pal.rim),
		LightEmission = 1,
		Brightness = 2,
		Size = ns({ { 0, 3 * s }, { 0.3, 5.5 * s }, { 1, 6.5 * s } }),
		Transparency = ns({ { 0, 0.05 }, { 1, 1 } }),
		Lifetime = NumberRange.new(cfgI.rimLife),
		Speed = NumberRange.new(0),
		ZOffset = 1.5,
	})
	-- ink: flat splatter on the ground + ragged puffs; LightEmission 0 so they darken the snow
	local splat = newEmitter(floor, "void_ink_splat", {
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01),
		Color = cs({ { 0, pal.ink }, { 0.7, pal.ink }, { 1, pal.ink:Lerp(pal.inkLight, 0.55) } }),
		LightEmission = 0,
		Size = ns({ { 0, cfgI.splatSize[1] * s }, { 0.12, cfgI.splatSize[2] * s }, { 1, cfgI.splatSize[3] * s } }),
		Transparency = ns({ { 0, 0 }, { 0.55, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(cfgI.inkLife[1], cfgI.inkLife[2]),
		Rotation = NumberRange.new(0, 360),
		ZOffset = -1,
	})
	local puffs = newEmitter(center, "void_ink_puff", {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(spread, spread),
		Speed = NumberRange.new(cfgI.puffSpeed[1] * s, cfgI.puffSpeed[2] * s),
		Drag = 5,
		Acceleration = up * 2 * s,
		Color = cs({ { 0, pal.ink:Lerp(pal.inkLight, 0.2) }, { 0.45, pal.ink:Lerp(pal.inkLight, 0.45) }, { 1, pal.inkLight } }),
		LightEmission = 0,
		Size = ns({ { 0, 2.6 * s }, { 0.35, 5.4 * s }, { 1, 6.6 * s } }),
		Transparency = ns({ { 0, 0.2 }, { 0.6, 0.35 }, { 1, 1 } }),
		Lifetime = if air then NumberRange.new(0.45, 0.65) else NumberRange.new(cfgI.inkLife[1] - 0.05, cfgI.inkLife[2]),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		ZOffset = -0.5,
	})
	-- white feathered flakes + black flecks
	local flakes = newEmitter(center, "void_flake", {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = if air then Vector2.new(180, 180) else Vector2.new(72, 72),
		Speed = NumberRange.new(cfgI.flakeSpeed[1] * s, cfgI.flakeSpeed[2] * s),
		Drag = 3,
		Acceleration = Vector3.new(0, -30 * s, 0),
		Color = ColorSequence.new(pal.flake),
		LightEmission = 0,
		Brightness = 1.2,
		Size = ns({ { 0, 1.3 * s }, { 1, 0.6 * s } }),
		Transparency = ns({ { 0, 0 }, { 0.7, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.45, 0.75),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-360, 360),
		ZOffset = 1,
	})
	local flecks = newEmitter(center, "spark_square", {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = if air then Vector2.new(180, 180) else Vector2.new(70, 70),
		Speed = NumberRange.new(cfgI.debrisSpeed[1] * s, cfgI.debrisSpeed[2] * s),
		Drag = 1,
		Acceleration = Vector3.new(0, -50 * s, 0),
		Color = ColorSequence.new(pal.debris),
		LightEmission = 0,
		Size = ns({ { 0, 0.28 * s }, { 1, 0.12 * s } }),
		Transparency = ns({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-300, 300),
		ZOffset = 0.5,
	})

	emit(flash, 2, 1)
	emit(core, 1, 1)
	emit(rim, 2, 1)
	if not air then
		emit(splat, 2, 1)
	end
	emit(puffs, 14, q)
	emit(flakes, 14, q)
	emit(flecks, 18, q)

	-- streak Beams: tail (Attachment0, wide) chases the head (Attachment1, thin)
	local streaks: { Streak } = {}
	local n = math.max(6, math.round((o.streaks or 14) * q))
	for i = 1, n do
		local dir = if air then streakDir(-55, 55, 1) else streakDir(cfgI.streakElev[1], cfgI.streakElev[2], 1.6)
		local a0 = newAttachment("S0", Vector3.zero, holder)
		local a1 = newAttachment("S1", Vector3.zero, holder)
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.FaceCamera = true
		b.Segments = 1
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 1.6
		b.Color = ColorSequence.new(pal.core:Lerp(pal.rim, 0.45), pal.core)
		b.Transparency = ns({ { 0, 0.55 }, { 0.35, 0 }, { 1, 0.1 } })
		local w = (0.07 + 0.05 * math.random()) * s -- hairline
		b.Width0 = w
		b.Width1 = w * 0.1
		b.Enabled = false
		b.Parent = holder
		local len = (cfgI.streakLen[1] + (cfgI.streakLen[2] - cfgI.streakLen[1]) * math.random()) * s
		local extra = (cfgI.streakExtra[1] + (cfgI.streakExtra[2] - cfgI.streakExtra[1]) * math.random()) * s
		streaks[i] = {
			a0 = a0,
			a1 = a1,
			beam = b,
			dir = dir,
			len = len,
			reach = len + extra,
			life = cfgI.streakLife[1] + (cfgI.streakLife[2] - cfgI.streakLife[1]) * math.random(),
		}
	end

	local light: PointLight? = nil
	if o.light ~= false then
		local l = Instance.new("PointLight")
		l.Color = pal.rim
		l.Range = 18 * s
		l.Brightness = 3
		l.Shadows = false
		l.Parent = center
		light = l
	end

	local r0 = 0.6 * s
	local lift = Vector3.new(0, 0.6 * s, 0)
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	local function step()
		local t = os.clock() - t0
		for _, st in streaks do
			local u = t / st.life
			if u >= 1 then
				st.beam.Enabled = false
			else
				local head = r0 + st.reach * easeOut(u, 3)
				local tail = r0 + st.reach * easeOut((u - 0.35) / 0.65, 2.2)
				tail = math.min(tail, head)
				tail = math.max(tail, head - st.len)
				st.a1.Position = lift + st.dir * head
				st.a0.Position = lift + st.dir * tail
				st.beam.Enabled = true
			end
		end
		if light then
			light.Brightness = 3 * (1 - easeOut(t / 0.18, 1.6))
		end
		if t > 0.24 then
			for _, st in streaks do
				st.beam:Destroy()
			end
			table.clear(streaks)
			if light then
				light:Destroy()
				light = nil
			end
			local c = conn
			if c then
				c:Disconnect()
				conn = nil
			end
		end
	end
	conn = RunService.Heartbeat:Connect(step)
	step()
	Debris:AddItem(holder, 1.3)
end

-------------------------------------------------------------------------------
-- VoidOrb
-------------------------------------------------------------------------------
export type OrbOptions = {
	radius: number?, -- studs, default 2
	tint: Color3?,
	palette: VoidPalette?,
	quality: number?,
	ribbons: number?, -- default 7
	offset: Vector3?, -- added to the attachment's world position (world space)
	releaseScale: number?, -- VoidImpact scale on release, default 0.55
	releaseDirection: Vector3?, -- airburst direction; default = character HumanoidRootPart LookVector tilted up
	parent: Instance?,
}

export type OrbHandle = {
	Orb: Part,
	Release: (self: OrbHandle, targetCF: CFrame?) -> (),
	Cancel: (self: OrbHandle) -> (),
	IsAlive: (self: OrbHandle) -> boolean,
}

Void.Orb = {
	grow = 0.3, -- seconds, ease-out-back
	implode = 0.14,
	implodeTo = 0.15, -- fraction of the radius at the pop
	ribbonRadius = { 1.08, 1.34 }, -- x R
	ribbonWidth = { 0.75, 1.1 }, -- x R
	ribbonSpeed = { 320, 560 }, -- deg/s
	ribbonLife = { 0.3, 0.42 }, -- s (arc = speed * life = 95-235 deg crescents)
	pullShell = 2.6, -- x R
}

type Ribbon = {
	tilt: CFrame,
	r: number,
	w: number,
	speed: number,
	phase: number,
	wob: number,
	a0: Attachment,
	a1: Attachment,
	c0: Attachment,
	c1: Attachment,
	k0: Attachment,
	k1: Attachment,
	trails: { Trail },
}

local function newTrail(parent: Instance, a0: Attachment, a1: Attachment, texKey: string?, props: { [string]: any }): Trail
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.FaceCamera = false
	t.LightInfluence = 0
	t.MinLength = 0.05
	t.TextureMode = Enum.TextureMode.Stretch
	if texKey then
		t.Texture = tex(texKey) or ""
	end
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

function Void.VoidOrbCharge(attachment: Attachment, opts: OrbOptions?): OrbHandle
	local o: OrbOptions = opts or {}
	local R = o.radius or 2
	local q = clamp01(o.quality or Void.Config.quality)
	local pal = resolvePalette(o.tint, o.palette)
	local cfgO = Void.Orb
	local offset = o.offset or Vector3.zero
	local function anchorPos(): Vector3
		return attachment.WorldPosition + offset
	end

	-- body: pure black Neon ball + ForceField fresnel shell + camera-facing rim ring
	local orb = newPart("VoidOrb", CFrame.new(anchorPos()), o.parent or getContainer())
	orb.Shape = Enum.PartType.Ball
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.new(0, 0, 0)
	orb.Transparency = 0
	orb.Size = Vector3.one * 0.05
	local shell = newPart("Shell", orb.CFrame, orb)
	shell.Shape = Enum.PartType.Ball
	shell.Material = Enum.Material.ForceField
	shell.Color = pal.rim
	shell.Transparency = 0.45 -- keep the face near-black; the billboard ring carries the silhouette rim
	shell.Size = Vector3.one * 0.06
	local ring: ImageLabel? = nil
	local bb = Instance.new("BillboardGui")
	bb.Name = "Rim"
	bb.Adornee = orb
	bb.LightInfluence = 0
	bb.Brightness = 2.5
	bb.Size = UDim2.new(0, 0, 0, 0)
	bb.Parent = orb
	local ringId = tex("void_rim_ring")
	if ringId then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = ringId
		img.ImageColor3 = pal.rim:Lerp(pal.core, 0.4)
		img.Size = UDim2.fromScale(1, 1)
		img.Parent = bb
		ring = img
	end
	local light = Instance.new("PointLight")
	light.Color = pal.rim
	light.Range = 7 * R
	light.Brightness = 0
	light.Shadows = false
	light.Parent = orb

	-- hot-pink glints off the surface (Shape uses the orb's size)
	local sparks = newEmitter(orb, "glint_star4", {
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Speed = NumberRange.new(0.8, 2.5),
		Color = ColorSequence.new(pal.spark),
		LightEmission = 1,
		Brightness = 6,
		Size = ns({ { 0, 0 }, { 0.25, 0.45 * R }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.25, 0.45),
		Rotation = NumberRange.new(0, 90),
		Rate = 14 * q,
		ZOffset = 1,
	})
	-- pull-in: motes + ink wisps from a big sphere shell moving inward
	local pull = newPart("PullShell", orb.CFrame, orb)
	pull.Shape = Enum.PartType.Ball
	pull.Size = Vector3.one * 2 * R * cfgO.pullShell
	local pullLife = (cfgO.pullShell - 1) * R / (5 * R)
	local motes = newEmitter(pull, "spark_square", {
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Speed = NumberRange.new(5 * R),
		Color = ColorSequence.new(pal.body, pal.core),
		LightEmission = 1,
		Brightness = 2,
		Size = ns({ { 0, 0 }, { 0.3, 0.09 * R }, { 1, 0.04 * R } }),
		Transparency = ns({ { 0, 1 }, { 0.3, 0 }, { 1, 0.2 } }),
		Lifetime = NumberRange.new(pullLife * 0.9, pullLife),
		Rate = 24 * q,
	})
	local wisps = newEmitter(pull, "void_ink_puff", {
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Speed = NumberRange.new(5 * R),
		Color = ColorSequence.new(pal.ink, pal.inkLight),
		LightEmission = 0,
		Size = ns({ { 0, 0.5 * R }, { 1, 0.15 * R } }),
		Transparency = ns({ { 0, 1 }, { 0.35, 0.35 }, { 1, 0.6 } }),
		Lifetime = NumberRange.new(pullLife * 0.85, pullLife),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		Rate = 10 * q,
	})
	for _, e in { sparks, motes, wisps } do
		if e then
			e.Enabled = true
		end
	end

	-- ribbons
	local ribbons: { Ribbon } = {}
	local nRib = math.max(3, math.round((o.ribbons or 7) * math.max(q, 0.6)))
	for i = 1, nRib do
		local tiltX = (math.random() * 2 - 1) * 62
		local tiltZ = (math.random() * 2 - 1) * 38
		local r = (cfgO.ribbonRadius[1] + (cfgO.ribbonRadius[2] - cfgO.ribbonRadius[1]) * math.random()) * R
		local w = (cfgO.ribbonWidth[1] + (cfgO.ribbonWidth[2] - cfgO.ribbonWidth[1]) * math.random()) * R
		local dirSign = if i == nRib then -1 else 1 -- one counter-rotating ribbon breaks the pattern
		local speed = (cfgO.ribbonSpeed[1] + (cfgO.ribbonSpeed[2] - cfgO.ribbonSpeed[1]) * math.random()) * dirSign
		local life = cfgO.ribbonLife[1] + (cfgO.ribbonLife[2] - cfgO.ribbonLife[1]) * math.random()
		local a0 = newAttachment("R" .. i .. "a0", Vector3.zero, orb)
		local a1 = newAttachment("R" .. i .. "a1", Vector3.zero, orb)
		local c0 = newAttachment("R" .. i .. "c0", Vector3.zero, orb)
		local c1 = newAttachment("R" .. i .. "c1", Vector3.zero, orb)
		local k0 = newAttachment("R" .. i .. "k0", Vector3.zero, orb)
		local k1 = newAttachment("R" .. i .. "k1", Vector3.zero, orb)
		local ink = newTrail(orb, k0, k1, "void_ink_wisp", {
			Color = ColorSequence.new(pal.ink, pal.inkLight),
			LightEmission = 0,
			Transparency = ns({ { 0, 0.45 }, { 0.6, 0.65 }, { 1, 1 } }),
			WidthScale = ns({ { 0, 0.6 }, { 0.5, 1 }, { 1, 0.3 } }),
			Lifetime = life * 1.8,
		})
		local body = newTrail(orb, a0, a1, "void_ribbon", {
			Color = cs({ { 0, pal.body:Lerp(pal.core, 0.35) }, { 0.12, pal.body }, { 0.55, pal.edge }, { 1, pal.edge } }),
			LightEmission = 1,
			Brightness = 1.8,
			Transparency = ns({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
			WidthScale = ns({ { 0, 1 }, { 0.6, 0.75 }, { 1, 0 } }),
			Lifetime = life,
		})
		local coreT = newTrail(orb, c0, c1, nil, {
			Color = ColorSequence.new(pal.core),
			LightEmission = 1,
			Brightness = 3,
			Transparency = ns({ { 0, 0 }, { 0.5, 0.35 }, { 1, 1 } }),
			WidthScale = ns({ { 0, 1 }, { 1, 0 } }),
			Lifetime = life * 0.6,
		})
		ribbons[i] = {
			tilt = CFrame.Angles(math.rad(tiltX), math.random() * 2 * math.pi, math.rad(tiltZ)),
			r = r,
			w = w,
			speed = speed,
			phase = math.random() * 360,
			wob = math.random() * 6,
			a0 = a0,
			a1 = a1,
			c0 = c0,
			c1 = c1,
			k0 = k0,
			k1 = k1,
			trails = { ink, body, coreT },
		}
	end

	-- state
	local t0 = os.clock()
	local state = "hold" -- "hold" | "implode" | "cancel" | "dead"
	local tState = 0
	local spin = 0
	local last = t0
	local conn: RBXScriptConnection? = nil

	local function destroyAll(after: number)
		state = "dead"
		local c = conn
		if c then
			c:Disconnect()
			conn = nil
		end
		for _, rb in ribbons do
			for _, tr in rb.trails do
				tr.Enabled = false
			end
		end
		for _, e in { sparks, motes, wisps } do
			if e then
				e.Enabled = false
			end
		end
		orb.Transparency = 1
		shell.Transparency = 1
		bb.Enabled = false
		light.Enabled = false
		Debris:AddItem(orb, after)
	end

	local function place(scale: number, speedMul: number, dt: number)
		local pos = anchorPos()
		orb.CFrame = CFrame.new(pos)
		local d = 2 * R * scale
		orb.Size = Vector3.one * math.max(d, 0.05)
		shell.Size = Vector3.one * math.max(d * (1.02 + 0.01 * math.sin(spin * 0.05)), 0.06)
		shell.CFrame = orb.CFrame
		pull.CFrame = orb.CFrame
		bb.Size = UDim2.new(d / 0.78, 0, d / 0.78, 0)
		spin += dt * speedMul
		local tt = os.clock() - t0
		for _, rb in ribbons do
			local ang = math.rad(rb.phase + rb.speed * spin)
			local radial = rb.tilt:VectorToWorldSpace(Vector3.new(math.cos(ang), 0, math.sin(ang)))
			local r = rb.r * scale * (1 + 0.04 * math.sin(3 * tt + rb.wob))
			local w = rb.w * scale
			rb.a0.Position = radial * (r - w * 0.5)
			rb.a1.Position = radial * (r + w * 0.5)
			rb.c0.Position = radial * (r + w * 0.04)
			rb.c1.Position = radial * (r + w * 0.1)
			rb.k0.Position = radial * (r + w * 0.1)
			rb.k1.Position = radial * (r + w * 1.2)
		end
	end

	local function step()
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		if state == "dead" then
			return
		end
		if not attachment.Parent and state ~= "cancel" then
			state = "cancel"
			tState = now
		end
		local t = now - t0
		local grow = easeOutBack(t / cfgO.grow)
		if state == "hold" then
			place(grow, 1, dt)
			light.Brightness = 2.5 + 0.6 * math.sin(t * 7)
		elseif state == "implode" then
			local u = (now - tState) / cfgO.implode
			local k = 1 - (1 - cfgO.implodeTo) * easeIn(u, 2)
			place(grow * k, 1 + 1.8 * clamp01(u), dt)
			light.Brightness = 2.5 + 4 * clamp01(u)
			if ring then
				ring.ImageTransparency = 0
			end
			bb.Brightness = 2.5 + 3 * clamp01(u)
		elseif state == "cancel" then
			local u = (now - tState) / 0.12
			place(grow * (1 - easeIn(u, 1.5)), 1, dt)
			if u >= 1 then
				destroyAll(1)
			end
		end
	end

	local handle: OrbHandle
	handle = {
		Orb = orb,
		IsAlive = function(_self: OrbHandle): boolean
			return state == "hold" or state == "implode"
		end,
		Release = function(_self: OrbHandle, targetCF: CFrame?)
			if state ~= "hold" then
				return
			end
			state = "implode"
			tState = os.clock()
			emit(motes, 16, q)
			emit(wisps, 8, q)
			task.delay(cfgO.implode, function()
				if state ~= "implode" then
					return
				end
				local at = targetCF
				if not at then
					local dir = o.releaseDirection
					if not dir then
						local model = attachment:FindFirstAncestorOfClass("Model")
						local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
						local look = if root and root:IsA("BasePart") then root.CFrame.LookVector else Vector3.new(0, 0, -1)
						dir = look + Vector3.new(0, 0.35, 0)
					end
					local d = (dir :: Vector3).Unit
					-- UpVector = d, so the airburst ink sprays away from the holder's torso
					at = CFrame.lookAt(orb.Position, orb.Position + d) * CFrame.Angles(-math.pi / 2, 0, 0)
				end
				destroyAll(0.8)
				Void.VoidImpact(at :: CFrame, {
					scale = o.releaseScale or 0.55,
					palette = pal,
					quality = q,
					parent = o.parent,
					airburst = targetCF == nil,
				})
			end)
		end,
		Cancel = function(_self: OrbHandle)
			if state == "hold" or state == "implode" then
				state = "cancel"
				tState = os.clock()
			end
		end,
	}

	place(0, 1, 0)
	conn = RunService.Heartbeat:Connect(step)
	return handle
end

return Void
