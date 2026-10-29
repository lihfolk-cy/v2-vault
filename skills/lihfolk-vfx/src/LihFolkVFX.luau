--!strict
--[[
	LihFolkVFX: stylised slash VFX on one Heartbeat-driven timeline (client only).

	Presets
	  SlashRing       spinning horizontal ring around the caster (teal by default)
	  CrescentDouble  two staggered crescents (violet by default)
	Elements          teal, violet, fire, ice, lightning, void, holy (palette per role)

	Layer recipe per crescent/ring unit (times in seconds after the Hit marker):
	  flash (0-0.07) -> sweep-in (0.11-0.13, reveal textures + yaw sweep) -> hold (0.05)
	  -> brush erosion (0.36-0.40, 5 texture swaps then fade) ; dark ink mesh behind the body,
	  additive flipbook glow card, hot edge Beam riding the head, sparks/glints from the head,
	  debris flung along the swing, ground ring, short light.

	Setup: upload VFX/Textures/*.png and VFX/Meshes/*.glb, paste the ids into
	LihFolkVFX.Textures / LihFolkVFX.Meshes (empty string = layer skipped, never a guessed id).
	See SKILL.md for the full layer table and the marker binding.
]]

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LihFolkVFX = {}

-------------------------------------------------------------------------------
-- Asset config: paste "rbxassetid://<id>" after uploading. "" = not uploaded yet.
-------------------------------------------------------------------------------
LihFolkVFX.Textures = {
	-- crescent / ring strips (mesh UV: u along arc tail->head, v inner->outer)
	strip_body = "",
	strip_body_reveal_1 = "",
	strip_body_reveal_2 = "",
	strip_body_reveal_3 = "",
	strip_body_erode_1 = "",
	strip_body_erode_2 = "",
	strip_body_erode_3 = "",
	strip_body_erode_4 = "",
	strip_body_erode_5 = "",
	strip_ink = "",
	strip_ink_erode_1 = "",
	strip_ink_erode_2 = "",
	strip_ink_erode_3 = "",
	strip_ground_ring = "",
	-- 1024 flipbooks (4x4: frames 0-3 sweep-in, 4-5 hold, 6-15 erode)
	flip_crescent_4x4 = "",
	flip_crescent_ink_4x4 = "",
	flip_ring_4x4 = "",
	flip_ring_ink_4x4 = "",
	flip_petals_8x8 = "",
	flip_glint_4x4 = "",
	-- sprites
	flash_hot = "",
	glow_soft = "",
	glint_star4 = "",
	spark_streak = "",
	spark_square = "",
	ground_disc_faint = "",
	beam_edge_h = "", -- leave "" for a solid hot-edge ribbon (works without any upload)
	trail_soft = "",
}

LihFolkVFX.Meshes = {
	crescent_single_thick = "",
	crescent_single_thin = "",
	crescent_double = "",
	crescent_tilted = "",
	ring_full_dish = "",
	ring_full_thin = "",
	ground_ring = "",
}

LihFolkVFX.Sounds = {
	-- { id = "rbxassetid://<id>", peak = seconds from sound start to its crack } ; id "" = silent
	slash = { id = "", peak = 0.08, volume = 0.6 },
	ring = { id = "", peak = 0.12, volume = 0.7 },
}

LihFolkVFX.Config = {
	meshYawOffset = 0, -- degrees; set once if your import faces the arc the wrong way (head must end on the swing's far side)
	cardRotation = 0, -- degrees added to flat-card Rotation; tune once so the card head matches the mesh head
	maxActive = 8, -- effects alive at once (new non-important casts are dropped beyond this)
	maxLiveParticles = 900, -- PC; mobile is set below
	cullDistance = 220, -- studs from the camera: skip entirely
	lowDetailDistance = 160, -- studs: decoration layers off, counts halved
	quality = 1, -- 0..1, scale for every Emit count; set from your settings menu
}
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	LihFolkVFX.Config.quality = 0.6
	LihFolkVFX.Config.maxLiveParticles = 360
end

-------------------------------------------------------------------------------
-- Palettes (roles: main body, hot rim, dark ink, glow, spark, debris)
-------------------------------------------------------------------------------
export type Palette = {
	main: Color3,
	hot: Color3,
	dark: Color3,
	glow: Color3,
	spark: Color3,
	debris: Color3,
	debrisLight: number?, -- LightEmission for debris (0 = solid dark petals)
}

local rgb = Color3.fromRGB
LihFolkVFX.Elements = {
	teal = { main = rgb(40, 215, 195), hot = rgb(225, 255, 250), dark = rgb(5, 20, 24), glow = rgb(60, 255, 220), spark = rgb(185, 255, 240), debris = rgb(8, 12, 14) },
	violet = { main = rgb(135, 85, 255), hot = rgb(242, 234, 255), dark = rgb(24, 8, 58), glow = rgb(150, 100, 255), spark = rgb(205, 180, 255), debris = rgb(16, 6, 34) },
	fire = { main = rgb(255, 105, 25), hot = rgb(255, 242, 205), dark = rgb(38, 8, 3), glow = rgb(255, 150, 40), spark = rgb(255, 205, 110), debris = rgb(28, 9, 5) },
	ice = { main = rgb(85, 185, 255), hot = rgb(235, 250, 255), dark = rgb(8, 24, 46), glow = rgb(135, 215, 255), spark = rgb(220, 245, 255), debris = rgb(170, 220, 245), debrisLight = 0.3 },
	lightning = { main = rgb(255, 225, 55), hot = rgb(255, 255, 238), dark = rgb(28, 22, 58), glow = rgb(255, 238, 110), spark = rgb(255, 255, 200), debris = rgb(18, 16, 38) },
	-- void: inverted treatment (dark body, bright magenta rim) so it still reads in dark zones
	void = { main = rgb(60, 18, 98), hot = rgb(255, 95, 232), dark = rgb(4, 0, 10), glow = rgb(205, 60, 255), spark = rgb(255, 140, 240), debris = rgb(3, 0, 7) },
	holy = { main = rgb(255, 212, 115), hot = rgb(255, 255, 240), dark = rgb(70, 48, 18), glow = rgb(255, 228, 150), spark = rgb(255, 246, 205), debris = rgb(255, 240, 205), debrisLight = 0.4 },
}

-------------------------------------------------------------------------------
-- Presets: the layer tables. Angles in degrees, sizes in studs, times in seconds.
-------------------------------------------------------------------------------
export type Unit = {
	shape: string, -- "ring" | "crescent"
	mesh: string, -- key in LihFolkVFX.Meshes
	card: string, -- flipbook key for the additive glow card
	inkCard: string?, -- flipbook key for the dark card
	cardROut: number, -- outer radius of the arc inside a card cell (0..1)
	radius: number,
	span: number,
	delay: number,
	lift: number,
	tilt: number,
	yaw: number,
	sweep: number,
	hold: number,
	erode: number,
	sweepEase: number, -- exponent of the ease-out on the reveal (2 = quad out)
	drift: number, -- degrees of extra rotation through the erode
	inkLag: number, -- degrees the ink smear trails behind the body
	inkDrop: number, -- studs the ink sits below the body (keeps it behind)
	bodyGain: number, -- VertexColor multiplier for the body
	cardBrightness: number,
	cardTransparency: number,
	edge: { width: number, band: number, life: number, brightness: number },
	sparks: number,
	glints: number,
	debris: number,
	squares: number,
}

export type Preset = {
	units: { Unit },
	flash: { size: number, life: number, brightness: number, forward: number },
	ground: { drop: number, radius: number, life: number, transparency: number }?,
	light: { brightness: number, range: number, life: number },
	sound: string,
	life: number, -- whole effect incl. lingering particles
}

LihFolkVFX.Presets = {
	SlashRing = {
		units = {
			{
				shape = "ring", mesh = "ring_full_dish", card = "flip_ring_4x4", inkCard = "flip_ring_ink_4x4",
				cardROut = 0.92, radius = 7.5, span = 350, delay = 0, lift = -1.3, tilt = 0, yaw = 0,
				sweep = 0.13, hold = 0.05, erode = 0.40, sweepEase = 2.2, drift = 26, inkLag = 16, inkDrop = 0.12,
				bodyGain = 1.0, cardBrightness = 1.6, cardTransparency = 0.45,
				edge = { width = 0.9, band = 120, life = 0.3, brightness = 4 },
				sparks = 16, glints = 5, debris = 24, squares = 0,
			},
		},
		flash = { size = 7, life = 0.07, brightness = 5, forward = 5 },
		ground = { drop = 1.7, radius = 8.5, life = 0.5, transparency = 0.5 },
		light = { brightness = 3, range = 16, life = 0.35 },
		sound = "ring",
		life = 1.1,
	} :: Preset,
	CrescentDouble = {
		units = {
			{
				shape = "crescent", mesh = "crescent_single_thick", card = "flip_crescent_4x4", inkCard = "flip_crescent_ink_4x4",
				cardROut = 0.9, radius = 8, span = 200, delay = 0, lift = 0.6, tilt = 10, yaw = 0,
				sweep = 0.11, hold = 0.05, erode = 0.36, sweepEase = 2.2, drift = 14, inkLag = 12, inkDrop = 0.12,
				bodyGain = 1.0, cardBrightness = 1.8, cardTransparency = 0.4,
				edge = { width = 1.0, band = 95, life = 0.26, brightness = 4 },
				sparks = 8, glints = 3, debris = 0, squares = 13,
			},
			{
				shape = "crescent", mesh = "crescent_single_thick", card = "flip_crescent_4x4", inkCard = "flip_crescent_ink_4x4",
				cardROut = 0.9, radius = 6.6, span = 200, delay = 0.06, lift = -0.7, tilt = -12, yaw = -14,
				sweep = 0.11, hold = 0.05, erode = 0.36, sweepEase = 2.2, drift = 14, inkLag = 12, inkDrop = 0.12,
				bodyGain = 0.9, cardBrightness = 1.5, cardTransparency = 0.45,
				edge = { width = 0.8, band = 90, life = 0.26, brightness = 3.5 },
				sparks = 8, glints = 3, debris = 0, squares = 13,
			},
		},
		flash = { size = 6, life = 0.06, brightness = 5, forward = 6 },
		ground = { drop = 3, radius = 7, life = 0.45, transparency = 0.65 },
		light = { brightness = 2.5, range = 16, life = 0.3 },
		sound = "slash",
		life = 1.3,
	} :: Preset,
}

-- Marker value -> what to play (values come from our clips: SwordLight1..3 "1".."3", SwordHeavy "heavy", SwordDashSlash "dash")
export type HitSpec = {
	preset: string,
	flip: boolean?,
	tilt: number?,
	yaw: number?,
	scale: number?,
	element: string?,
	offset: CFrame?,
}
LihFolkVFX.DefaultHits = {
	["1"] = { preset = "CrescentDouble", tilt = 12 },
	["2"] = { preset = "CrescentDouble", flip = true, tilt = -10 },
	["3"] = { preset = "CrescentDouble", tilt = 72, scale = 0.9 }, -- stepping overhead: near-vertical plane
	heavy = { preset = "SlashRing" },
	dash = { preset = "CrescentDouble", scale = 1.3, offset = CFrame.new(0, 0, -3) },
} :: { [string]: HitSpec }

-------------------------------------------------------------------------------
-- Small helpers
-------------------------------------------------------------------------------
local warned: { [string]: boolean } = {}
local function warnOnce(key: string, msg: string)
	if not warned[key] then
		warned[key] = true
		warn("[LihFolkVFX] " .. msg)
	end
end

local function tex(key: string): string?
	local id = (LihFolkVFX.Textures :: any)[key]
	if type(id) == "string" and id ~= "" then
		return id
	end
	warnOnce("tex:" .. key, "texture '" .. key .. "' has no id yet; that layer is skipped")
	return nil
end

local function meshId(key: string): string?
	local id = (LihFolkVFX.Meshes :: any)[key]
	if type(id) == "string" and id ~= "" then
		return id
	end
	warnOnce("mesh:" .. key, "mesh '" .. key .. "' has no id yet; mesh layers using it are skipped")
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

local function ns(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end

-- point on the arc circle in pivot space; phi in degrees, 0 = +X, 90 = forward (-Z)
local function arcPoint(phi: number, r: number, y: number): Vector3
	local a = math.rad(phi)
	return Vector3.new(math.cos(a) * r, y, -math.sin(a) * r)
end

local function arcTangent(phi: number): Vector3
	local a = math.rad(phi)
	return Vector3.new(-math.sin(a), 0, -math.cos(a))
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

local function newEmitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.LightInfluence = 0
	e.LockedToPart = false
	e.VelocityInheritance = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function meshLayer(name: string, mesh: string, texture: string, cf: CFrame, parent: Instance, neon: boolean): (Part, SpecialMesh)
	local p = newPart(name, cf, parent)
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Transparency = 1
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.FileMesh
	m.MeshId = mesh
	m.TextureId = texture
	m.Scale = Vector3.one
	m.Parent = p
	return p, m
end

local function v3(c: Color3, gain: number): Vector3
	return Vector3.new(c.R * gain, c.G * gain, c.B * gain)
end

-------------------------------------------------------------------------------
-- Timeline engine (one Heartbeat connection for every live effect)
-------------------------------------------------------------------------------
type Step = (t: number) -> ()
type Effect = {
	t0: number,
	life: number,
	steps: { Step },
	root: Instance,
	particles: number,
	stopped: boolean,
}

local active: { Effect } = {}
local heartbeat: RBXScriptConnection? = nil
local liveParticles = 0
local container: Folder? = nil

local function getContainer(): Folder
	local c = container
	if c and c.Parent then
		return c
	end
	local f = Instance.new("Folder")
	f.Name = "LihFolkVFX"
	f.Parent = Workspace
	container = f
	return f
end

local function finish(e: Effect)
	if e.stopped then
		return
	end
	e.stopped = true
	liveParticles = math.max(0, liveParticles - e.particles)
	e.root:Destroy()
end

local function tick()
	local now = os.clock()
	for i = #active, 1, -1 do
		local e = active[i]
		local t = now - e.t0
		if e.stopped or t >= e.life then
			finish(e)
			table.remove(active, i)
		else
			local ok, err = pcall(function()
				for _, step in e.steps do
					step(t)
				end
			end)
			if not ok then
				warn("[LihFolkVFX] effect step failed, cleaning up: " .. tostring(err))
				finish(e)
				table.remove(active, i)
			end
		end
	end
	if #active == 0 and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function start(e: Effect)
	table.insert(active, e)
	-- safety net: even if the loop dies, the instances go away
	Debris:AddItem(e.root, e.life + 3)
	if not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(tick)
	end
	tick()
end

-------------------------------------------------------------------------------
-- Unit builder: one crescent or ring with all its layers
-------------------------------------------------------------------------------
type BuildCtx = {
	root: Instance,
	base: CFrame, -- swing frame (XZ plane = swing plane, -Z = forward)
	pal: Palette,
	scale: number,
	detail: number, -- 0..1 count scale
	deco: boolean, -- decoration layers on
	steps: { Step },
	particles: number,
}

local function count(n: number, ctx: BuildCtx): number
	if n <= 0 then
		return 0
	end
	return math.max(1, math.floor(n * ctx.detail + 0.5))
end

local BODY_REVEAL = { "strip_body_reveal_1", "strip_body_reveal_2", "strip_body_reveal_3", "strip_body" }
local BODY_ERODE = { "strip_body_erode_1", "strip_body_erode_2", "strip_body_erode_3", "strip_body_erode_4", "strip_body_erode_5" }
local INK_ERODE = { "strip_ink", "strip_ink_erode_1", "strip_ink_erode_2", "strip_ink_erode_3" }

local function buildUnit(u: Unit, ctx: BuildCtx)
	local R = u.radius * ctx.scale
	local cf = ctx.base
		* CFrame.new(0, u.lift * ctx.scale, 0)
		* CFrame.Angles(0, 0, math.rad(u.tilt))
		* CFrame.Angles(0, math.rad(u.yaw), 0)
	local pivot = newPart("Unit", cf, ctx.root)
	local tail = 90 - u.span / 2
	local head0 = 90 + u.span / 2
	local tHold = u.sweep + u.hold
	local tEnd = tHold + u.erode

	-- shared clock of the unit: reveal r(t) and the head angle
	local function reveal(t: number): number
		return easeOut(t / u.sweep, u.sweepEase)
	end
	local function yawAt(t: number): number
		local r = reveal(t)
		local drift = u.drift * easeOut((t - u.sweep) / (tEnd - u.sweep), 2)
		return -u.span * (1 - r) + drift
	end

	local yawOffset = LihFolkVFX.Config.meshYawOffset
	local meshKey = meshId(u.mesh)

	-- 1) dark ink smear mesh (behind the body)
	local inkTex = tex("strip_ink")
	if meshKey and inkTex then
		local part, mesh = meshLayer("Ink", meshKey, inkTex, cf, ctx.root, false)
		mesh.VertexColor = v3(ctx.pal.dark, 1)
		local inkIds: { string } = {}
		for _, k in INK_ERODE do
			table.insert(inkIds, tex(k) or inkTex)
		end
		local lastStage = 0
		table.insert(ctx.steps, function(t: number)
			local lt = t - u.delay - 0.03
			if lt < 0 then
				part.Transparency = 1
				return
			end
			local inT = clamp01(lt / 0.07)
			local outT = clamp01((lt - (tHold + u.erode * 0.45)) / (u.erode * 0.6))
			part.Transparency = 1 - 0.88 * inT + 0.88 * easeIn(outT, 1.6)
			local stage = 1 + math.clamp(math.floor((lt - tHold) / (u.erode / 3.2)) + 1, 0, 3)
			if lt < tHold then
				stage = 1
			end
			if stage ~= lastStage then
				lastStage = stage
				mesh.TextureId = inkIds[stage]
			end
			local s = R * (0.95 + 0.07 * easeOut(lt / tEnd, 2))
			mesh.Scale = Vector3.new(s, s, s)
			part.CFrame = cf * CFrame.new(0, -u.inkDrop * ctx.scale, 0)
				* CFrame.Angles(0, math.rad(yawAt(lt) - u.inkLag + yawOffset), 0)
		end)
	end

	-- 2) body mesh: reveal swaps during the sweep, erosion swaps after the hold
	local bodyTex = tex("strip_body")
	if meshKey and bodyTex then
		local part, mesh = meshLayer("Body", meshKey, bodyTex, cf, ctx.root, true)
		part.Color = ctx.pal.main
		mesh.VertexColor = v3(ctx.pal.main, u.bodyGain)
		local reveals: { string } = {}
		for _, k in BODY_REVEAL do
			table.insert(reveals, tex(k) or bodyTex)
		end
		local erodes: { string } = {}
		for _, k in BODY_ERODE do
			table.insert(erodes, tex(k) or bodyTex)
		end
		local current = ""
		table.insert(ctx.steps, function(t: number)
			local lt = t - u.delay
			if lt < 0 then
				part.Transparency = 1
				return
			end
			local id: string
			if lt < u.sweep then
				local r = reveal(lt)
				id = reveals[if r < 0.42 then 1 elseif r < 0.67 then 2 elseif r < 0.9 then 3 else 4]
			elseif lt < tHold then
				id = reveals[4]
			else
				local k = math.clamp(math.floor((lt - tHold) / (u.erode / 5)) + 1, 1, 5)
				id = erodes[k]
			end
			if id ~= current then
				current = id
				mesh.TextureId = id
			end
			local fade = clamp01((lt - (tHold + u.erode * 0.55)) / (u.erode * 0.5))
			part.Transparency = easeIn(fade, 1.8)
			local grow = 0.86 + 0.14 * easeOut(lt / tHold, 2) + 0.04 * easeOut((lt - tHold) / u.erode, 2)
			local s = R * grow
			mesh.Scale = Vector3.new(s, s, s)
			part.CFrame = cf * CFrame.Angles(0, math.rad(yawAt(lt) + yawOffset), 0)
		end)
	end

	-- 3) additive flipbook glow card (+ dark card) lying in the swing plane
	local cardSize = 2 * R / u.cardROut
	local cardRot = tail + LihFolkVFX.Config.cardRotation
	local cardAtt = Instance.new("Attachment")
	cardAtt.Parent = pivot
	local cardTex = tex(u.card)
	if cardTex then
		local e = newEmitter(cardAtt, {
			Texture = cardTex,
			Color = ColorSequence.new(ctx.pal.glow),
			LightEmission = 1,
			Brightness = u.cardBrightness,
			Size = NumberSequence.new(cardSize),
			Transparency = ns({ { 0, u.cardTransparency }, { 0.8, u.cardTransparency }, { 1, 1 } }),
			Lifetime = NumberRange.new(tEnd),
			Speed = NumberRange.new(0.001),
			SpreadAngle = Vector2.zero,
			EmissionDirection = Enum.NormalId.Top,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Rotation = NumberRange.new(cardRot),
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			ZOffset = 0.5,
		})
		local fired = false
		table.insert(ctx.steps, function(t: number)
			if not fired and t >= u.delay then
				fired = true
				e:Emit(1)
			end
		end)
		ctx.particles += 1
	end
	if u.inkCard and ctx.deco then
		local inkCardTex = tex(u.inkCard)
		if inkCardTex then
			local e = newEmitter(cardAtt, {
				Texture = inkCardTex,
				Color = ColorSequence.new(ctx.pal.dark),
				LightEmission = 0,
				Brightness = 1,
				Size = NumberSequence.new(cardSize * 0.98),
				Transparency = ns({ { 0, 0.35 }, { 0.75, 0.35 }, { 1, 1 } }),
				Lifetime = NumberRange.new(tEnd * 1.1),
				Speed = NumberRange.new(0.001),
				SpreadAngle = Vector2.zero,
				EmissionDirection = Enum.NormalId.Top,
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				Rotation = NumberRange.new(cardRot - u.inkLag),
				FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
				FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				ZOffset = -0.5,
			})
			local fired = false
			table.insert(ctx.steps, function(t: number)
				if not fired and t >= u.delay then
					fired = true
					e:Emit(1)
				end
			end)
			ctx.particles += 1
		end
	end

	-- 4) hot edge: a Beam band riding the head (solid ribbon if beam_edge_h is not uploaded)
	do
		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		a0.Parent = pivot
		a1.Parent = pivot
		local beams: { Beam } = {}
		local function makeBeam(widthMul: number, transp: number, color: ColorSequence, brightness: number)
			local b = Instance.new("Beam")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.FaceCamera = true
			b.Segments = 24
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Brightness = brightness
			b.Color = color
			b.Texture = (LihFolkVFX.Textures :: any).beam_edge_h or ""
			b.TextureMode = Enum.TextureMode.Stretch
			b.TextureLength = 1
			b.TextureSpeed = 0
			b.Transparency = NumberSequence.new(1)
			b:SetAttribute("WidthMul", widthMul)
			b:SetAttribute("Base", transp)
			b.Parent = pivot
			table.insert(beams, b)
		end
		makeBeam(1, 0, ColorSequence.new(ctx.pal.glow, ctx.pal.hot), u.edge.brightness)
		if ctx.deco then
			makeBeam(3.2, 0.72, ColorSequence.new(ctx.pal.glow), 1.5)
		end
		local rEdge = R * 0.985
		table.insert(ctx.steps, function(t: number)
			local lt = t - u.delay
			local alive = lt >= 0 and lt <= u.edge.life
			if not alive then
				for _, b in beams do
					b.Transparency = NumberSequence.new(1)
				end
				return
			end
			local head = head0 + yawAt(lt)
			local band = u.edge.band * (0.35 + 0.65 * reveal(lt))
			local phiA = head - band
			local k = 4 / 3 * math.tan(math.rad(band) / 4) * rEdge
			a0.CFrame = CFrame.fromMatrix(arcPoint(phiA, rEdge, 0.05), arcTangent(phiA), Vector3.yAxis)
			a1.CFrame = CFrame.fromMatrix(arcPoint(head, rEdge, 0.05), arcTangent(head), Vector3.yAxis)
			local life = lt / u.edge.life
			local w = u.edge.width * ctx.scale * (1 - easeIn(life, 1.5))
			local fade = easeIn(life, 2)
			for _, b in beams do
				b.CurveSize0 = k
				b.CurveSize1 = k
				local wm = b:GetAttribute("WidthMul") :: number
				local base = b:GetAttribute("Base") :: number
				b.Width0 = w * wm * 0.15
				b.Width1 = w * wm
				local o = base + (1 - base) * fade
				b.Transparency = ns({ { 0, 1 }, { 0.45, math.min(1, o + 0.45) }, { 0.85, o }, { 1, math.min(1, o + 0.2) } })
			end
		end)
	end

	-- 5) head-spawned particles: sparks, glints, debris (along the swing, not radial)
	local emitAtt = Instance.new("Attachment")
	emitAtt.Parent = pivot
	local spawners: { { e: ParticleEmitter, n: number, done: number, out: number, up: number, ramp: number } } = {}
	local function spawner(e: ParticleEmitter?, n: number, outward: number, up: number, ramp: number)
		if e and n > 0 then
			table.insert(spawners, { e = e, n = n, done = 0, out = outward, up = up, ramp = ramp })
			ctx.particles += n
		end
	end
	local sparkTex = tex("spark_streak")
	spawner(sparkTex and newEmitter(emitAtt, {
		Texture = sparkTex,
		Color = ColorSequence.new(ctx.pal.spark),
		LightEmission = 1,
		Brightness = 5,
		Size = ns({ { 0, 0.55 * ctx.scale }, { 1, 0 } }),
		Transparency = ns({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.2, 0.38),
		Speed = NumberRange.new(34, 58),
		SpreadAngle = Vector2.new(14, 14),
		EmissionDirection = Enum.NormalId.Front,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Drag = 6,
		Acceleration = Vector3.new(0, -24, 0),
		ZOffset = 1,
	}) or nil, count(u.sparks, ctx), 0.35, 0.12, 1)
	local glintTex = tex("flip_glint_4x4")
	if ctx.deco then
		spawner(glintTex and newEmitter(emitAtt, {
			Texture = glintTex,
			Color = ColorSequence.new(ctx.pal.hot),
			LightEmission = 1,
			Brightness = 6,
			Size = NumberSequence.new(1.8 * ctx.scale),
			Lifetime = NumberRange.new(0.18, 0.24),
			Speed = NumberRange.new(0.5, 2),
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Front,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			ZOffset = 2,
		}) or nil, count(u.glints, ctx), 0.6, 0.1, 1)
	end
	local petalTex = tex("flip_petals_8x8")
	spawner(petalTex and newEmitter(emitAtt, {
		Texture = petalTex,
		Color = ColorSequence.new(ctx.pal.debris),
		LightEmission = ctx.pal.debrisLight or 0,
		Brightness = 1,
		Size = ns({ { 0, 0.35 * ctx.scale }, { 0.15, 0.7 * ctx.scale }, { 1, 0.45 * ctx.scale } }),
		Squash = ns({ { 0, 0 }, { 0.25, 0.6 }, { 0.5, -0.4 }, { 0.75, 0.5 }, { 1, 0 } }), -- fake tumble
		Transparency = ns({ { 0, 0 }, { 0.7, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.55, 0.95),
		Speed = NumberRange.new(30, 62),
		SpreadAngle = Vector2.new(18, 18),
		EmissionDirection = Enum.NormalId.Front,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-420, 420),
		Drag = 3.2,
		Acceleration = Vector3.new(0, -14, 0),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NumberRange.new(0.001),
		FlipbookStartRandom = true,
		ZOffset = 0.2,
	}) or nil, count(u.debris, ctx), 0.55, 0.15, 1.15)

	if #spawners > 0 then
		table.insert(ctx.steps, function(t: number)
			local lt = t - u.delay
			if lt < 0 then
				return
			end
			for _, s in spawners do
				-- spread each burst over the sweep (+ a short tail), always from the current head
				local due = math.min(s.n, math.floor(s.n * clamp01(lt / (u.sweep * s.ramp + 0.03)) + 0.5))
				local k = due - s.done
				if k > 0 then
					local head = head0 + yawAt(lt)
					local dir = (arcTangent(head) + arcPoint(head, 1, 0) * s.out + Vector3.yAxis * s.up).Unit
					local pos = arcPoint(head, R * (0.88 + 0.1 * math.random()), 0.1)
					emitAtt.CFrame = CFrame.lookAt(pos, pos + dir)
					s.e:Emit(k)
					s.done = due
				end
			end
		end)
	end

	-- 6) floating square sparks along the whole arc at the hold (violet style)
	local squareTex = tex("spark_square")
	local nSq = if ctx.deco then count(u.squares, ctx) else 0
	if squareTex and nSq > 0 then
		local sqAtt = Instance.new("Attachment")
		sqAtt.Parent = pivot
		local e = newEmitter(sqAtt, {
			Texture = squareTex,
			Color = ColorSequence.new(ctx.pal.spark),
			LightEmission = 1,
			Brightness = 4,
			Size = ns({ { 0, 0 }, { 0.15, 0.32 * ctx.scale }, { 0.35, 0.12 * ctx.scale }, { 0.55, 0.28 * ctx.scale }, { 1, 0 } }),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(3, 10),
			SpreadAngle = Vector2.new(40, 40),
			EmissionDirection = Enum.NormalId.Front,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Rotation = NumberRange.new(0, 45),
			Drag = 2,
			Acceleration = Vector3.new(0, 2.5, 0),
			ZOffset = 1,
		})
		local fired = false
		table.insert(ctx.steps, function(t: number)
			if not fired and t - u.delay >= u.sweep * 0.7 then
				fired = true
				for _ = 1, nSq do
					local phi = tail + u.span * (0.15 + 0.85 * math.random()) + yawAt(t - u.delay)
					local pos = arcPoint(phi, R * (0.75 + 0.3 * math.random()), (math.random() - 0.5) * 1.2)
					sqAtt.CFrame = CFrame.lookAt(pos, pos + (arcPoint(phi, 1, 0) + Vector3.yAxis * 0.4).Unit)
					e:Emit(1)
				end
			end
		end)
		ctx.particles += nSq
	end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------
export type PlayOptions = {
	element: string?,
	palette: Palette?,
	flip: boolean?,
	tilt: number?,
	yaw: number?,
	scale: number?,
	important: boolean?, -- own casts: ignore maxActive and keep decoration at distance
}

--[[ Play a preset. `cf` is the swing frame: its position is the swing centre (e.g. the root part),
	its XZ plane is the swing plane and -Z is forward. Returns a stop function. ]]
function LihFolkVFX.play(presetName: string, cf: CFrame, options: PlayOptions?): () -> ()
	local opts: PlayOptions = options or {}
	local preset = (LihFolkVFX.Presets :: any)[presetName] :: Preset?
	if not preset then
		warnOnce("preset:" .. presetName, "unknown preset " .. presetName)
		return function() end
	end
	local cfg = LihFolkVFX.Config
	local important = opts.important == true
	if not important and #active >= cfg.maxActive then
		return function() end
	end
	local detail = cfg.quality
	local deco = detail >= 0.55
	local cam = Workspace.CurrentCamera
	if cam and not important then
		local dist = (cam.CFrame.Position - cf.Position).Magnitude
		if dist > cfg.cullDistance then
			return function() end
		elseif dist > cfg.lowDetailDistance then
			detail *= 0.5
			deco = false
		end
	end
	if liveParticles > cfg.maxLiveParticles * 0.75 then
		detail *= 0.5
		deco = false
	end
	local pal = opts.palette or (LihFolkVFX.Elements :: any)[opts.element or (if presetName == "SlashRing" then "teal" else "violet")] :: Palette?
	if not pal then
		pal = (LihFolkVFX.Elements :: any).teal
	end
	local base = cf
	if opts.flip then
		base = base * CFrame.Angles(0, 0, math.pi)
	end
	if opts.tilt then
		base = base * CFrame.Angles(0, 0, math.rad(opts.tilt))
	end
	if opts.yaw then
		base = base * CFrame.Angles(0, math.rad(opts.yaw), 0)
	end
	local scale = opts.scale or 1

	local root = Instance.new("Model")
	root.Name = presetName
	local ctx: BuildCtx = {
		root = root,
		base = base,
		pal = pal :: Palette,
		scale = scale,
		detail = detail,
		deco = deco,
		steps = {},
		particles = 0,
	}
	local anchor = newPart("Anchor", base, root)

	-- hot flash at the contact point
	local flashTex = tex("flash_hot")
	if flashTex then
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0, 0, -preset.flash.forward * scale)
		att.Parent = anchor
		local e = newEmitter(att, {
			Texture = flashTex,
			Color = ColorSequence.new(ctx.pal.hot),
			LightEmission = 1,
			Brightness = preset.flash.brightness,
			Size = ns({ { 0, 0 }, { 0.3, preset.flash.size * scale }, { 1, preset.flash.size * 0.4 * scale } }),
			Transparency = ns({ { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }),
			Lifetime = NumberRange.new(preset.flash.life),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 90),
			ZOffset = 4,
		})
		e:Emit(1)
		ctx.particles += 1
	end

	for _, u in preset.units do
		buildUnit(u, ctx)
	end

	-- ground ring + faint disc (world up, below the swing centre)
	local g = preset.ground
	if g and ctx.deco then
		-- flat on the world floor, facing the caster's heading
		local gPos = cf.Position - Vector3.new(0, g.drop * scale, 0)
		local flat = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		if flat.Magnitude < 1e-3 then
			flat = Vector3.new(0, 0, -1)
		end
		local groundCf = CFrame.lookAt(gPos, gPos + flat.Unit)
		local gMesh = meshId("ground_ring")
		local gTex = tex("strip_ground_ring")
		if gMesh and gTex then
			local part, mesh = meshLayer("Ground", gMesh, gTex, groundCf, root, true)
			part.Color = ctx.pal.glow
			mesh.VertexColor = v3(ctx.pal.glow, 1)
			table.insert(ctx.steps, function(t: number)
				local x = clamp01(t / g.life)
				local s = g.radius * scale * (0.45 + 0.8 * easeOut(x, 3))
				mesh.Scale = Vector3.new(s, s, s)
				part.Transparency = g.transparency + (1 - g.transparency) * easeIn(x, 1.4)
			end)
		end
		local discTex = tex("ground_disc_faint")
		if discTex then
			local att = Instance.new("Attachment")
			att.Parent = anchor
			att.WorldCFrame = groundCf * CFrame.new(0, 0.05, 0)
			local e = newEmitter(att, {
				Texture = discTex,
				Color = ColorSequence.new(ctx.pal.glow),
				LightEmission = 1,
				Brightness = 0.6,
				Size = ns({ { 0, g.radius * 1.6 * scale }, { 1, g.radius * 2.6 * scale } }),
				Transparency = ns({ { 0, 0.7 }, { 1, 1 } }),
				Lifetime = NumberRange.new(g.life * 1.2),
				Speed = NumberRange.new(0.001),
				EmissionDirection = Enum.NormalId.Top,
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				ZOffset = -1,
			})
			e:Emit(1)
			ctx.particles += 1
		end
	end

	-- short light in the glow colour (no shadows)
	local light = Instance.new("PointLight")
	light.Color = ctx.pal.glow
	light.Range = preset.light.range * scale
	light.Shadows = false
	light.Brightness = 0
	light.Parent = anchor
	table.insert(ctx.steps, function(t: number)
		local x = t / preset.light.life
		light.Brightness = if x < 0.1 then preset.light.brightness * x / 0.1 else preset.light.brightness * (1 - easeOut((x - 0.1) / 0.9, 2))
	end)

	-- sound with its peak on the hit
	local snd = (LihFolkVFX.Sounds :: any)[preset.sound]
	if snd and snd.id ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = snd.id
		s.Volume = snd.volume
		-- the marker IS the hit, so skip into the sound until its crack lands now
		s.TimePosition = snd.peak
		s.Parent = anchor
		s:Play()
	end

	root.Parent = getContainer()
	liveParticles += ctx.particles
	local effect: Effect = {
		t0 = os.clock(),
		life = preset.life,
		steps = ctx.steps,
		root = root,
		particles = ctx.particles,
		stopped = false,
	}
	start(effect)
	return function()
		effect.stopped = true
	end
end

--[[ Preload every texture and mesh id a preset uses (call when the weapon is equipped, not on first swing).
	Fresh uploads can fail PreloadAsync for about a minute; that is normal. ]]
function LihFolkVFX.preload()
	local ids: { string } = {}
	for _, id in LihFolkVFX.Textures :: any do
		if type(id) == "string" and id ~= "" then
			table.insert(ids, id)
		end
	end
	for _, id in LihFolkVFX.Meshes :: any do
		if type(id) == "string" and id ~= "" then
			table.insert(ids, id)
		end
	end
	if #ids > 0 then
		task.spawn(function()
			local ok, err = pcall(function()
				ContentProvider:PreloadAsync(ids)
			end)
			if not ok then
				warn("[LihFolkVFX] preload failed: " .. tostring(err))
			end
		end)
	end
end

function LihFolkVFX.setQuality(q: number)
	LihFolkVFX.Config.quality = math.clamp(q, 0.25, 1)
end

-- Stop and remove every live effect (scene change, death, teleport).
function LihFolkVFX.clear()
	for _, e in active do
		finish(e)
	end
	table.clear(active)
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

-------------------------------------------------------------------------------
-- Weapon trail (TrailOn / TrailOff window)
-------------------------------------------------------------------------------
--[[ Creates a disabled Trail on the blade between two points (blade-local offsets). ]]
function LihFolkVFX.attachTrail(blade: BasePart, baseOffset: Vector3, tipOffset: Vector3, element: string?): Trail
	local pal = (LihFolkVFX.Elements :: any)[element or "teal"] :: Palette
	local a0 = Instance.new("Attachment")
	a0.Name = "LihFolkTrail0"
	a0.Position = baseOffset
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Name = "LihFolkTrail1"
	a1.Position = tipOffset
	a1.Parent = blade
	local tr = Instance.new("Trail")
	tr.Name = "LihFolkTrail"
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Enabled = false
	tr.Lifetime = 0.16
	tr.MinLength = 0.05
	tr.FaceCamera = false
	tr.LightEmission = 1
	tr.LightInfluence = 0
	tr.Brightness = 3
	tr.Color = ColorSequence.new(pal.hot, pal.glow)
	tr.Transparency = ns({ { 0, 0.1 }, { 0.5, 0.5 }, { 1, 1 } })
	tr.WidthScale = ns({ { 0, 1 }, { 1, 0.15 } })
	tr.Texture = LihFolkVFX.Textures.trail_soft
	tr.TextureMode = Enum.TextureMode.Stretch
	tr.Parent = blade
	return tr
end

-------------------------------------------------------------------------------
-- Animation marker binding (Hit / TrailOn / TrailOff from our clips)
-------------------------------------------------------------------------------
export type Binding = {
	hits: { [string]: HitSpec }?, -- marker value -> spec; defaults to LihFolkVFX.DefaultHits
	element: string?, -- default element (else the character's "VFXElement" attribute)
	trail: Trail?, -- weapon trail toggled by TrailOn / TrailOff
	important: boolean?, -- true for the local player's own character
}

local function rootOf(character: Model): BasePart?
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return character.PrimaryPart
end

--[[ Listen to one AnimationTrack's markers. Returns a disconnect function. ]]
function LihFolkVFX.bindTrack(track: AnimationTrack, character: Model, binding: Binding?): () -> ()
	local b: Binding = binding or {}
	-- upper-body copies carry the same markers; only the full clip fires effects
	if track.Animation and track.Animation:GetAttribute("KitUpper") then
		return function() end
	end
	local conns: { RBXScriptConnection } = {}
	local hits = b.hits or LihFolkVFX.DefaultHits
	table.insert(conns, track:GetMarkerReachedSignal("Hit"):Connect(function(param: string?)
		local spec = hits[param or ""] or hits["1"]
		local root = rootOf(character)
		if not spec or not root then
			return
		end
		local element = spec.element or b.element or character:GetAttribute("VFXElement")
		LihFolkVFX.play(spec.preset, root.CFrame * (spec.offset or CFrame.identity), {
			element = if type(element) == "string" then element else nil,
			flip = spec.flip,
			tilt = spec.tilt,
			yaw = spec.yaw,
			scale = spec.scale,
			important = b.important,
		})
	end))
	local trail = b.trail
	if trail then
		table.insert(conns, track:GetMarkerReachedSignal("TrailOn"):Connect(function()
			trail:Clear() -- otherwise it connects from where the blade was last time
			trail.Enabled = true
		end))
		table.insert(conns, track:GetMarkerReachedSignal("TrailOff"):Connect(function()
			trail.Enabled = false
		end))
		table.insert(conns, track.Stopped:Connect(function()
			trail.Enabled = false
		end))
	end
	return function()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		if trail then
			trail.Enabled = false
		end
	end
end

--[[ Bind every track this Animator plays from now on. Returns a disconnect function. ]]
function LihFolkVFX.bindAnimator(animator: Animator, character: Model, binding: Binding?): () -> ()
	local unbinds: { [AnimationTrack]: () -> () } = {}
	local played = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		if unbinds[track] then
			return
		end
		unbinds[track] = LihFolkVFX.bindTrack(track, character, binding)
		track.Ended:Once(function()
			local un = unbinds[track]
			if un then
				un()
				unbinds[track] = nil
			end
		end)
	end)
	local destroying = character.Destroying:Once(function()
		played:Disconnect()
		for _, un in unbinds do
			un()
		end
		table.clear(unbinds)
	end)
	return function()
		played:Disconnect()
		destroying:Disconnect()
		for _, un in unbinds do
			un()
		end
		table.clear(unbinds)
	end
end

return LihFolkVFX
