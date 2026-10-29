--!strict
--[[
	LihFolkVFX_Abilities: ability VFX beyond slashes (client only). UNTESTED IN STUDIO.

	Standalone module next to LihFolkVFX.luau: same conventions (Textures table with "" = fallback or
	skipped layer + one warning, one shared Heartbeat loop, quality scaling, live-particle cap, Debris
	safety net, Emit bursts, CanCollide/CanQuery/CanTouch false, CastShadow false), no shared state.

	  local A = require(ReplicatedStorage.LihFolkVFX_Abilities)
	  A.Projectile(fromCF, target, opts)   muzzle flash, travelling core + Trail + particle wake, optional
	                                       homing, impact burst on arrival           -> h:Impact(pos?), h:Destroy()
	  A.Aura(character, opts)              persistent rim + motes + foot ring + orbit wisps on Attachments
	                                                                                 -> h:SetIntensity(0..1), h:Destroy()
	  A.Telegraph(cf, shape, opts)         ground AoE warning "circle" | "cone" | "line": dark outline, bright
	                                       rim, translucent fill that grows over `duration`, then a pop
	                                                                                 -> h:Cancel(), h:Destroy()
	  A.Shield(characterOrPart, opts)      ForceField bubble + Highlight rim, ripples   -> h:Hit(worldPos), h:Break(), h:Destroy()
	  A.BeamLaser(fromAtt, to, opts)       charge, core + outer (+ dark edge) Beams, impact glow per frame,
	                                       end burst                                 -> h:SetTarget(posOrAtt), h:Stop(), h:Destroy()
	  A.Heal(character, opts)              rising motes + expanding foot ring + glints  -> h:Destroy()
	  A.Buff(character, opts)              rising streaks + imploding foot ring + pop   -> h:Destroy()
	  A.Teleport(fromCF, toCF, opts)       implode at the source, burst at the destination -> h:Destroy()
	  A.LevelUp(character, opts)           rising scan ring, light pillar above the head, two foot rings,
	                                       sparkles and confetti (celebration)          -> h:Destroy()
	  A.CameraShake(intensity, duration, opts?)   local camera only, distance falloff, reducedMotion aware
	  A.HitStop(tracksOrAnimator, duration, opts?) AdjustSpeed freeze then restore (optional catch-up)
	  A.playPayload(caster, presetId, cf, elementIndex, seed, aux?)  replay a server broadcast (see
	                                       examples/AbilityVFXReplication.*.luau)
	  A.setQuality(q), A.clear(), A.preload(), A.liveParticles()

	Common options: element ("teal", "violet", "fire", "ice", "lightning", "void", "holy", "plasma", "heal"),
	palette (a full Palette), scale, important (own casts and gameplay warnings: never culled), seed, quality.

	Budget at quality 1 (see SKILL.md for the full table); counts scale with quality (touch devices 0.6),
	halve above 75 % of the live cap or beyond lowDetailDistance, decoration layers drop at quality < 0.55.
	At most one light per effect, lights never cast shadows.

	Built-in looks when Textures are empty (no upload needed):
	  glow_soft, flash_hot, spark_streak, spark_square -> the engine's default particle sprite
	  trail_soft, beam_core, beam_outer               -> solid gradient ribbons (no scroll)
	  Neon parts, ForceField material, HandleAdornments (rings, discs, sectors) and Highlights need no texture.
	Skipped when empty (one warning each): smoke_puff (teleport dust), scorch_mark (projectile ground mark).
]]

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Abilities = {}

-------------------------------------------------------------------------------
-- Asset config: paste "rbxassetid://<id>" after uploading your own textures. "" = built-in look or skipped.
-------------------------------------------------------------------------------
Abilities.Textures = {
	glow_soft = "", -- soft round glow (motes, wake, impact glow); "" = default particle sprite
	flash_hot = "", -- 4-point star flash; "" = default particle sprite
	spark_streak = "", -- thin streak, drawn VelocityParallel; "" = default particle sprite
	spark_square = "", -- small square fleck (debris, shards, confetti); "" = default particle sprite
	smoke_puff = "", -- textured dust puff; "" = dust layer skipped
	scorch_mark = "", -- projectile impact ground mark (Decal); "" = skipped
	trail_soft = "", -- projectile Trail, stretched; "" = solid gradient ribbon
	beam_core = "", -- laser core, scrolls along the beam; "" = solid core
	beam_outer = "", -- laser outer body, scrolls slower; "" = solid body
}

Abilities.Config = {
	quality = 1, -- 0.25..1, scales every Emit count and stream Rate
	maxLiveParticles = 900, -- PC; touch devices 360 (set below)
	maxActive = 10, -- one-shot effects alive at once (important casts bypass)
	cullDistance = 220, -- studs from the camera: others' one-shots are skipped
	lowDetailDistance = 160, -- studs: decoration off, counts halved; persistent effects sleep beyond this
	groundProbe = 40, -- studs a telegraph/ring raycasts down to find the floor
	coneSectorOffset = 0, -- degrees; tune once if Telegraph cones point the wrong way (Studio check)
	reducedMotion = false, -- player setting: CameraShake and HitStop do nothing
	shakeScale = 1, -- player setting 0..1 for CameraShake
	maxHitStop = 0.2, -- seconds
	-- optional: returns the live particles of other VFX modules so all of them share one cap
	externalLive = nil :: (() -> number)?,
}
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	Abilities.Config.quality = 0.6
	Abilities.Config.maxLiveParticles = 360
end

-------------------------------------------------------------------------------
-- Palettes: same roles and values as LihFolkVFX.Elements (+ heal)
-------------------------------------------------------------------------------
export type Palette = {
	main: Color3, -- element body
	hot: Color3, -- white-hot core and rims
	dark: Color3, -- saturated ink (outlines, dark wake)
	glow: Color3, -- soft glow, lights
	spark: Color3, -- accent sparks
	debris: Color3, -- flecks
	debrisLight: number?,
}

local rgb = Color3.fromRGB
Abilities.Elements = {
	teal = { main = rgb(40, 215, 195), hot = rgb(225, 255, 250), dark = rgb(5, 20, 24), glow = rgb(60, 255, 220), spark = rgb(185, 255, 240), debris = rgb(8, 12, 14) },
	violet = { main = rgb(120, 48, 255), hot = rgb(242, 234, 255), dark = rgb(40, 12, 100), glow = rgb(125, 70, 255), spark = rgb(205, 180, 255), debris = rgb(16, 6, 34) },
	fire = { main = rgb(255, 105, 25), hot = rgb(255, 242, 205), dark = rgb(38, 8, 3), glow = rgb(255, 150, 40), spark = rgb(255, 205, 110), debris = rgb(28, 9, 5) },
	ice = { main = rgb(85, 185, 255), hot = rgb(235, 250, 255), dark = rgb(8, 24, 46), glow = rgb(135, 215, 255), spark = rgb(220, 245, 255), debris = rgb(170, 220, 245), debrisLight = 0.3 },
	lightning = { main = rgb(255, 225, 55), hot = rgb(255, 255, 238), dark = rgb(28, 22, 58), glow = rgb(255, 238, 110), spark = rgb(255, 255, 200), debris = rgb(18, 16, 38) },
	-- void: inverted (dark body, bright magenta rim); cores get a rim shell instead of a hot centre
	void = { main = rgb(60, 18, 98), hot = rgb(255, 95, 232), dark = rgb(4, 0, 10), glow = rgb(205, 60, 255), spark = rgb(255, 140, 240), debris = rgb(3, 0, 7) },
	holy = { main = rgb(255, 212, 115), hot = rgb(255, 255, 240), dark = rgb(70, 48, 18), glow = rgb(255, 228, 150), spark = rgb(255, 246, 205), debris = rgb(255, 240, 205), debrisLight = 0.4 },
	plasma = { main = rgb(70, 215, 255), hot = rgb(246, 252, 255), dark = rgb(14, 8, 40), glow = rgb(150, 95, 255), spark = rgb(175, 238, 255), debris = rgb(10, 8, 26) },
	-- heal: soft green body, gold accent sparks
	heal = { main = rgb(70, 230, 120), hot = rgb(235, 255, 238), dark = rgb(6, 40, 22), glow = rgb(120, 255, 160), spark = rgb(255, 238, 150), debris = rgb(10, 30, 18), debrisLight = 0.4 },
}

-- Stable ids for network payloads (append only; never reorder a shipped list)
Abilities.ElementIds = { "teal", "violet", "fire", "ice", "lightning", "void", "holy", "plasma", "heal" }
Abilities.PresetIds = {
	"Projectile", -- cf = muzzle, aux = target position
	"TelegraphCircle", -- cf = centre (radius from Abilities.PayloadDefaults)
	"TelegraphCone", -- cf = apex, LookVector = cone direction
	"TelegraphLine", -- cf = start, LookVector = line direction
	"Teleport", -- cf = source, aux = destination position
	"Heal", -- on the caster's character
	"Buff", -- on the caster's character
	"LevelUp", -- on the caster's character
}
-- per-preset options used by playPayload (keep payloads small; put tuning here, not on the wire)
Abilities.PayloadDefaults = {
	Projectile = { speed = 90, range = 160 },
	TelegraphCircle = { radius = 10, duration = 1 },
	TelegraphCone = { radius = 14, angle = 60, duration = 0.8 },
	TelegraphLine = { length = 24, width = 4, duration = 0.7 },
} :: { [string]: { [string]: any } }
-- casts a client may request (server-only presets such as telegraphs and LevelUp are absent).
-- The server enforces these; the client mirrors them so it predicts only casts the server will accept.
Abilities.CastRules = {
	Projectile = { cooldown = 0.35, range = 160 },
	Teleport = { cooldown = 2, range = 40 },
	Heal = { cooldown = 5, range = 0 },
	Buff = { cooldown = 8, range = 0 },
} :: { [string]: { cooldown: number, range: number } }

-------------------------------------------------------------------------------
-- Small helpers (same shapes as LihFolkVFX.luau)
-------------------------------------------------------------------------------
local warned: { [string]: boolean } = {}
local function warnOnce(key: string, msg: string)
	if not warned[key] then
		warned[key] = true
		warn("[LihFolkVFX_Abilities] " .. msg)
	end
end

local function texId(key: string): string?
	local id = (Abilities.Textures :: any)[key]
	if type(id) == "string" and id ~= "" and not string.find(id, "REPLACE_ME", 1, true) then
		return id
	end
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
	local u = clamp01(x) - 1
	return 1 + (c1 + 1) * u ^ 3 + c1 * u ^ 2
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function ns(points: { { number } }): NumberSequence
	local kps: { NumberSequenceKeypoint } = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end

local function cs(points: { { any } }): ColorSequence
	local kps: { ColorSequenceKeypoint } = {}
	for _, p in points do
		table.insert(kps, ColorSequenceKeypoint.new(p[1] :: number, p[2] :: Color3))
	end
	return ColorSequence.new(kps)
end

local function aim(pos: Vector3, dir: Vector3): CFrame
	local d = if dir.Magnitude > 1e-4 then dir.Unit else Vector3.new(0, 0, -1)
	local up = if math.abs(d.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(pos, pos + d, up)
end

-- frame whose Y axis is `up` and whose -Z follows `forward` projected onto that plane
local function surfaceFrame(pos: Vector3, up: Vector3, forward: Vector3): CFrame
	local u = if up.Magnitude > 1e-4 then up.Unit else Vector3.yAxis
	local f = forward - u * forward:Dot(u)
	if f.Magnitude < 1e-3 then
		f = if math.abs(u.Y) < 0.9 then Vector3.yAxis:Cross(u) else Vector3.xAxis:Cross(u)
	end
	return CFrame.lookAt(pos, pos + f.Unit, u)
end

local function isDark(pal: Palette): boolean
	local c = pal.main
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B < 0.2
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

local function neonPart(name: string, shape: Enum.PartType, color: Color3, cf: CFrame, parent: Instance): Part
	local p = newPart(name, cf, parent)
	p.Shape = shape
	p.Material = Enum.Material.Neon
	p.Color = color
	return p
end

local function newAttachment(name: string, parent: Instance, cf: CFrame?): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	if cf then
		a.CFrame = cf
	end
	a.Parent = parent
	return a
end

-- Emitter with a texture key. An empty id keeps the engine's default sprite when `fallback` is true,
-- else the layer is skipped (nil). Emitters start disabled; bursts use Emit.
local function newEmitter(parent: Instance, key: string, props: { [string]: any }, fallback: boolean): ParticleEmitter?
	local id = texId(key)
	if not id then
		if not fallback then
			warnOnce("tex:" .. key, "texture '" .. key .. "' has no id yet; that layer is skipped")
			return nil
		end
		warnOnce("fb:" .. key, "texture '" .. key .. "' has no id yet; using the built-in particle sprite")
	end
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.LightInfluence = 0
	e.LockedToPart = false
	e.VelocityInheritance = 0
	if id then
		e.Texture = id
	end
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function newLight(parent: Instance, color: Color3, brightness: number, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

-- flat ring / disc / sector on a surface frame (Y up). CylinderHandleAdornment lies along its own Z.
local FLAT = CFrame.Angles(math.rad(90), 0, 0)
local function newDisc(parent: Instance, adornee: BasePart, cf: CFrame, outer: number, inner: number, color: Color3, transparency: number): CylinderHandleAdornment
	local a = Instance.new("CylinderHandleAdornment")
	a.Adornee = adornee
	a.CFrame = cf * FLAT
	a.Height = 0.03
	a.Radius = math.max(0.01, outer)
	a.InnerRadius = math.clamp(inner, 0, a.Radius - 0.005)
	a.Color3 = color
	a.Transparency = transparency
	a.AlwaysOnTop = false
	a.Parent = parent
	return a
end

local function setDisc(a: CylinderHandleAdornment, outer: number, width: number?)
	local r = math.max(0.01, outer)
	a.Radius = r
	a.InnerRadius = if width then math.clamp(r - width, 0, r - 0.005) else 0
end

local function newBox(parent: Instance, adornee: BasePart, cf: CFrame, size: Vector3, color: Color3, transparency: number): BoxHandleAdornment
	local b = Instance.new("BoxHandleAdornment")
	b.Adornee = adornee
	b.CFrame = cf
	b.Size = size
	b.Color3 = color
	b.Transparency = transparency
	b.AlwaysOnTop = false
	b.Parent = parent
	return b
end

local function vertical(cf: CFrame): CFrame
	-- Part cylinders run along X: stand them up
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

local function rootOf(character: Model): BasePart?
	local r = character:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		return r
	end
	return character.PrimaryPart
end

-- studs from the root part's centre down to the feet
local function feetOffset(character: Model, root: BasePart): number
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum and hum.HipHeight > 0 then
		return -(root.Size.Y * 0.5 + hum.HipHeight)
	end
	return -3
end

-------------------------------------------------------------------------------
-- Timeline engine: one Heartbeat for every live effect, disconnected when idle
-------------------------------------------------------------------------------
type Fx = {
	name: string,
	t0: number,
	life: number, -- math.huge for persistent effects
	persistent: boolean,
	root: Model,
	anchor: Part,
	particles: number,
	step: ((t: number, dt: number) -> boolean?)?, -- return true to finish early
	cleanup: { () -> () },
	finished: boolean,
	killed: boolean,
	-- build context
	pal: Palette,
	scale: number,
	detail: number,
	deco: boolean,
	important: boolean,
	rng: Random,
}

local active: { Fx } = {}
local heartbeat: RBXScriptConnection? = nil
local live = 0
local container: Folder? = nil

local function getContainer(): Folder
	local c = container
	if c and c.Parent then
		return c
	end
	local f = Instance.new("Folder")
	f.Name = "LihFolkAbilityFX"
	f.Parent = Workspace
	container = f
	return f
end

local function account(fx: Fx, n: number)
	fx.particles += n
	live += n
end

local function finish(fx: Fx)
	if fx.finished then
		return
	end
	fx.finished = true
	live = math.max(0, live - fx.particles)
	fx.particles = 0
	for _, fn in fx.cleanup do
		local ok, err = pcall(fn)
		if not ok then
			warn("[LihFolkVFX_Abilities] cleanup failed: " .. tostring(err))
		end
	end
	fx.root:Destroy()
end

local function tick(dt: number)
	local now = os.clock()
	for i = #active, 1, -1 do
		local fx = active[i]
		local t = now - fx.t0
		local done = fx.killed or t >= fx.life
		if not done and fx.step then
			local ok, res = pcall(fx.step :: any, t, dt)
			if not ok then
				warn("[LihFolkVFX_Abilities] " .. fx.name .. " step failed, cleaning up: " .. tostring(res))
				done = true
			elseif res == true then
				done = true
			end
		end
		if done then
			finish(fx)
			table.remove(active, i)
		end
	end
	if #active == 0 and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function start(fx: Fx)
	fx.root.Parent = getContainer()
	if not fx.persistent then
		Debris:AddItem(fx.root, fx.life + 3) -- safety net if the loop ever dies
	end
	table.insert(active, fx)
	if not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(tick)
	end
end

local function oneShotCount(): number
	local n = 0
	for _, fx in active do
		if not fx.persistent then
			n += 1
		end
	end
	return n
end

local function totalLive(): number
	local ext = Abilities.Config.externalLive
	return live + (if ext then ext() else 0)
end

export type CommonOptions = {
	element: string?,
	palette: Palette?,
	scale: number?,
	important: boolean?, -- own casts and gameplay warnings: never culled or capped
	seed: number?, -- deterministic variation (replication)
	quality: number?, -- overrides Config.quality for this effect
}

local function resolvePalette(opts: CommonOptions, default: string): Palette
	if opts.palette then
		return opts.palette
	end
	local p = (Abilities.Elements :: any)[opts.element or default] :: Palette?
	if p then
		return p
	end
	if opts.element then
		warnOnce("el:" .. opts.element, "unknown element " .. opts.element .. "; using " .. default)
	end
	return (Abilities.Elements :: any)[default] :: Palette
end

-- decide once per effect: skip (nil), reduced or full
local function admit(name: string, pos: Vector3, opts: CommonOptions, default: string, persistent: boolean, life: number): Fx?
	local cfg = Abilities.Config
	local important = opts.important == true
	if not persistent and not important and oneShotCount() >= cfg.maxActive then
		return nil
	end
	local detail = math.clamp(opts.quality or cfg.quality, 0.25, 1)
	local deco = detail >= 0.55
	local cam = Workspace.CurrentCamera
	if cam and not important and not persistent then
		local dist = (cam.CFrame.Position - pos).Magnitude
		if dist > cfg.cullDistance then
			return nil
		elseif dist > cfg.lowDetailDistance then
			detail *= 0.5
			deco = false
		end
	end
	local load = totalLive()
	if load >= cfg.maxLiveParticles and not important then
		return nil
	elseif load > cfg.maxLiveParticles * 0.75 then
		detail *= 0.5
		deco = false
	end
	local root = Instance.new("Model")
	root.Name = name
	local anchor = newPart("Anchor", CFrame.new(pos), root)
	return {
		name = name,
		t0 = os.clock(),
		life = life,
		persistent = persistent,
		root = root,
		anchor = anchor,
		particles = 0,
		step = nil,
		cleanup = {},
		finished = false,
		killed = false,
		pal = resolvePalette(opts, default),
		scale = opts.scale or 1,
		detail = detail,
		deco = deco,
		important = important,
		rng = Random.new(opts.seed or math.floor(os.clock() * 1e6) % 2147483647),
	}
end

-- attachment on the effect's anchor, placed in world space
local function worldAttachment(fx: Fx, name: string, worldCF: CFrame): Attachment
	local a = newAttachment(name, fx.anchor)
	a.WorldCFrame = worldCF
	return a
end

local function count(fx: Fx, n: number): number
	if n <= 0 then
		return 0
	end
	return math.max(1, math.floor(n * fx.detail + 0.5))
end

local function burst(fx: Fx, e: ParticleEmitter?, n: number)
	if e then
		local k = count(fx, n)
		e:Emit(k)
		account(fx, k)
	end
end

-- stream particles alive ~ Rate * Lifetime.Max
local function setStream(fx: Fx, e: ParticleEmitter?, rate: number, prev: number): number
	if not e then
		return 0
	end
	local r = if rate > 0 then rate * fx.detail else 0
	e.Rate = r
	e.Enabled = r > 0
	local alive = r * e.Lifetime.Max
	account(fx, alive - prev)
	return alive
end

local excludeList: { Instance } = {}
local function rayParams(extra: { Instance }?): RaycastParams
	table.clear(excludeList)
	table.insert(excludeList, getContainer())
	if extra then
		for _, inst in extra do
			table.insert(excludeList, inst)
		end
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = excludeList
	p.IgnoreWater = false
	return p
end

local function characters(): { Instance }
	local list = {}
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(list, pl.Character)
		end
	end
	return list
end

-- floor under pos (characters ignored): position and normal
local function groundAt(pos: Vector3): (Vector3, Vector3)
	local probe = Abilities.Config.groundProbe
	local hit = Workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -probe, 0), rayParams(characters()))
	if hit then
		return hit.Position, hit.Normal
	end
	return pos, Vector3.yAxis
end

-------------------------------------------------------------------------------
-- Shared layers
-------------------------------------------------------------------------------
local function flashEmitter(fx: Fx, parent: Instance, size: number, color: Color3): ParticleEmitter?
	return newEmitter(parent, "flash_hot", {
		Lifetime = NumberRange.new(0.05, 0.07), -- 2 frames
		Speed = NumberRange.new(0),
		Size = ns({ { 0, size }, { 1, size * 1.25 } }),
		Transparency = ns({ { 0, 0 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Brightness = 3,
		ZOffset = 2,
	}, true)
end

local function sparkEmitter(fx: Fx, parent: Instance, s: number, spread: number, speed: { number }): ParticleEmitter?
	local pal = fx.pal
	return newEmitter(parent, "spark_streak", {
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(spread, spread),
		Speed = NumberRange.new(speed[1] * s, speed[2] * s),
		Drag = 6,
		Lifetime = NumberRange.new(0.16, 0.3),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = ns({ { 0, 0.22 * s }, { 1, 0 } }),
		Squash = ns({ { 0, 1.2 }, { 1, 0.6 } }),
		Transparency = ns({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
		Color = cs({ { 0, pal.hot }, { 0.4, pal.spark }, { 1, pal.main } }),
		LightEmission = 1,
		Brightness = 2,
		ZOffset = 1,
	}, true)
end

local function debrisEmitter(fx: Fx, parent: Instance, s: number, spread: number): ParticleEmitter?
	local pal = fx.pal
	return newEmitter(parent, "spark_square", {
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(spread, spread),
		Speed = NumberRange.new(10 * s, 20 * s),
		Drag = 2.5,
		Acceleration = Vector3.new(0, -40, 0),
		Lifetime = NumberRange.new(0.35, 0.55),
		Size = ns({ { 0, 0.18 * s }, { 1, 0.05 * s } }),
		Transparency = ns({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-360, 360),
		Color = ColorSequence.new(pal.debris),
		LightEmission = pal.debrisLight or 0,
	}, true)
end

-- expanding ring that fades (eased out). Returns a step piece; call with the local time.
local function ringStep(a: CylinderHandleAdornment, t0: number, dur: number, r0: number, r1: number, w0: number, w1: number, tr0: number): (t: number) -> ()
	return function(t: number)
		local u = (t - t0) / dur
		if u < 0 then
			a.Visible = false
			return
		end
		a.Visible = u <= 1
		local e = easeOut(u, 3)
		setDisc(a, lerp(r0, r1, e), lerp(w0, w1, e))
		a.Transparency = lerp(tr0, 1, easeIn(u, 1.4))
	end
end

-------------------------------------------------------------------------------
-- Handles
-------------------------------------------------------------------------------
export type Handle = {
	Destroy: (self: any) -> (),
	IsAlive: (self: any) -> boolean,
}
export type ProjectileHandle = Handle & { Impact: (self: any, at: Vector3?, normal: Vector3?) -> () }
export type AuraHandle = Handle & { SetIntensity: (self: any, x: number) -> () }
export type TelegraphHandle = Handle & { Cancel: (self: any) -> () }
export type ShieldHandle = Handle & { Hit: (self: any, worldPos: Vector3) -> (), Break: (self: any) -> () }
export type LaserHandle = Handle & { SetTarget: (self: any, to: Vector3 | Attachment) -> (), Stop: (self: any) -> () }

local function baseHandle(fx: Fx?): any
	return {
		Destroy = function(_self: any)
			if fx then
				fx.killed = true
			end
		end,
		IsAlive = function(_self: any): boolean
			return fx ~= nil and not fx.finished and not fx.killed
		end,
	}
end

-- handle with no-op methods for culled effects (callers never need nil checks)
local function deadHandle(): any
	local h = baseHandle(nil)
	local noop = function() end
	h.Impact, h.SetIntensity, h.Cancel, h.Hit, h.Break, h.SetTarget, h.Stop = noop, noop, noop, noop, noop, noop, noop
	return h
end

-------------------------------------------------------------------------------
-- Projectile
-------------------------------------------------------------------------------
export type ProjectileOptions = CommonOptions & {
	speed: number?, -- studs/s (default 90)
	range: number?, -- studs before an air pop (default 160)
	direction: Vector3?, -- fly this way instead of at the target
	homing: number?, -- max turn rate in deg/s toward a BasePart/Attachment target (default 0 = straight)
	gravity: number?, -- studs/s^2 drop (default 0)
	collide: boolean?, -- raycast the world each frame and pop on walls (default true)
	ignore: { Instance }?, -- the caster's character, the weapon...
	light: boolean?, -- default true (one PointLight, travels with the core, pulses at impact)
	onImpact: ((position: Vector3, normal: Vector3) -> ())?,
}

--[[ Visual projectile. `target`: a world position, a BasePart, an Attachment, or nil (fly along
	fromCF.LookVector or opts.direction). Hit detection stays on the server; call h:Impact(pos) when the
	server confirms a hit somewhere else. ]]
function Abilities.Projectile(fromCF: CFrame, target: (Vector3 | BasePart | Attachment)?, options: ProjectileOptions?): ProjectileHandle
	local opts: ProjectileOptions = options or {}
	local speed = math.max(1, opts.speed or 90)
	local range = opts.range or 160
	local fx = admit("Projectile", fromCF.Position, opts, "fire", false, range / speed * 1.6 + 2.5)
	if not fx then
		return deadHandle()
	end
	local pal, s = fx.pal, fx.scale
	local from = fromCF.Position

	local function targetPos(): Vector3?
		if typeof(target) == "Vector3" then
			return target
		elseif typeof(target) == "Instance" then
			if target:IsA("Attachment") and target.Parent then
				return target.WorldPosition
			elseif target:IsA("BasePart") and target.Parent then
				return target.Position
			end
		end
		return nil
	end
	local tp0 = targetPos()
	local dir = opts.direction or (if tp0 and (tp0 - from).Magnitude > 0.1 then tp0 - from else fromCF.LookVector)
	dir = dir.Unit

	-- muzzle: flash + forward spark cone, both one frame
	local muzzle = newAttachment("Muzzle", fx.anchor)
	muzzle.WorldCFrame = aim(from, dir)
	burst(fx, flashEmitter(fx, muzzle, 1.8 * s, pal.hot), 1)
	burst(fx, sparkEmitter(fx, muzzle, s, 22, { 18, 34 }), 8)

	-- core: Neon ball + hot centre (light palettes) or a hot rim shell (dark palettes)
	local core = neonPart("Core", Enum.PartType.Ball, pal.main, aim(from, dir), fx.root)
	core.Size = Vector3.one * 0.9 * s
	core.Transparency = 0
	local inner: Part
	if isDark(pal) then
		inner = newPart("Rim", core.CFrame, fx.root)
		inner.Shape = Enum.PartType.Ball
		inner.Material = Enum.Material.ForceField
		inner.Color = pal.hot
		inner.Size = Vector3.one * 1.15 * s
		inner.Transparency = 0
	else
		inner = neonPart("Hot", Enum.PartType.Ball, pal.hot, core.CFrame, fx.root)
		inner.Size = Vector3.one * 0.5 * s
		inner.Transparency = 0
	end

	-- Trail: white head -> body -> deep tail, tapering
	local a0 = newAttachment("T0", core, CFrame.new(0, 0.32 * s, 0))
	local a1 = newAttachment("T1", core, CFrame.new(0, -0.32 * s, 0))
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.2
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.8
	trail.LightInfluence = 0
	trail.WidthScale = ns({ { 0, 1 }, { 1, 0 } })
	trail.Transparency = ns({ { 0, 0.05 }, { 0.6, 0.45 }, { 1, 1 } })
	trail.Color = cs({ { 0, pal.hot }, { 0.3, pal.main }, { 1, pal.main:Lerp(pal.dark, 0.5) } })
	local trailTex = texId("trail_soft")
	if trailTex then
		trail.Texture = trailTex
		trail.TextureMode = Enum.TextureMode.Stretch
	end
	trail.Parent = core

	-- wake: element motes + dark ink motes (decoration)
	local wakeAtt = newAttachment("Wake", core)
	local wake = newEmitter(wakeAtt, "glow_soft", {
		Lifetime = NumberRange.new(0.22, 0.36),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
		Size = ns({ { 0, 0.55 * s }, { 1, 0 } }),
		Transparency = ns({ { 0, 0.2 }, { 1, 1 } }),
		Color = cs({ { 0, pal.main }, { 1, pal.main:Lerp(pal.dark, 0.5) } }),
		LightEmission = 1,
	}, true)
	local ink = if fx.deco
		then newEmitter(wakeAtt, "glow_soft", {
			Lifetime = NumberRange.new(0.35, 0.5),
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 3,
			Size = ns({ { 0, 0.4 * s }, { 1, 0.9 * s } }),
			Transparency = ns({ { 0, 0.55 }, { 1, 1 } }),
			Color = ColorSequence.new(pal.dark),
			LightEmission = 0,
		}, true)
		else nil
	local wakeAlive = setStream(fx, wake, 36, 0)
	local inkAlive = setStream(fx, ink, 12, 0)

	local light = if opts.light ~= false then newLight(core, pal.glow, 1.4, 9 * s) else nil

	local params = rayParams(opts.ignore)
	local pos = from
	local vel = dir * speed
	local travelled = 0
	local homing = math.rad(opts.homing or 0)
	local gravity = opts.gravity or 0
	local impactT: number? = nil
	local impactSteps: { (t: number) -> () } = {}

	local function impact(t: number, at: Vector3, normal: Vector3)
		if impactT then
			return
		end
		impactT = t
		wakeAlive = setStream(fx, wake, 0, wakeAlive)
		inkAlive = setStream(fx, ink, 0, inkAlive)
		core.Transparency = 1
		inner.Transparency = 1
		core.CFrame = aim(at, vel)
		local n = if normal.Magnitude > 1e-3 then normal.Unit else -vel.Unit
		local hitAtt = newAttachment("Impact", fx.anchor)
		hitAtt.WorldCFrame = aim(at + n * 0.2, n)
		local flash = flashEmitter(fx, hitAtt, 2.6 * s, pal.hot)
		local sparks = sparkEmitter(fx, hitAtt, s, 65, { 22, 40 })
		local chips = if fx.deco then debrisEmitter(fx, hitAtt, s, 55) else nil
		burst(fx, sparks, 16)
		burst(fx, chips, 8)
		-- flash one frame after contact
		local flashed = false
		table.insert(impactSteps, function(lt: number)
			if not flashed and lt >= 0.016 then
				flashed = true
				burst(fx, flash, 1)
			end
		end)
		-- surface rings: bright fast ring, then a dark slower outline ring (decoration)
		local surf = surfaceFrame(at + n * 0.05, n, vel)
		local ringAnchor = newPart("RingAnchor", surf, fx.root)
		local r1 = newDisc(fx.root, ringAnchor, CFrame.identity, 0.4 * s, 0.35 * s, pal.hot:Lerp(pal.main, 0.35), 0.1)
		table.insert(impactSteps, ringStep(r1, 0, 0.3, 0.4 * s, 3.6 * s, 0.35 * s, 0.08 * s, 0.1))
		if fx.deco then
			local r2 = newDisc(fx.root, ringAnchor, CFrame.new(0, -0.01, 0), 0.6 * s, 0.4 * s, pal.dark, 0.35)
			table.insert(impactSteps, ringStep(r2, 0.03, 0.42, 0.6 * s, 4.4 * s, 0.4 * s, 0.1 * s, 0.35))
		end
		local scorch = texId("scorch_mark")
		local tail = 0.9
		if scorch then
			local plate = newPart("Scorch", surf * CFrame.new(0, -0.03, 0), fx.root)
			plate.Size = Vector3.new(3 * s, 0.05, 3 * s)
			local d = Instance.new("Decal")
			d.Face = Enum.NormalId.Top
			d.Texture = scorch
			d.Color3 = pal.dark
			d.Transparency = 0.3
			d.Parent = plate
			table.insert(impactSteps, function(lt: number)
				d.Transparency = lerp(0.3, 1, easeIn(lt / 1.6, 2))
			end)
			tail = 1.7
		else
			warnOnce("tex:scorch_mark", "texture 'scorch_mark' has no id yet; that layer is skipped")
		end
		if light then
			light.Parent = hitAtt
			table.insert(impactSteps, function(lt: number)
				light.Brightness = 3 * (1 - easeOut(lt / 0.2, 2))
				light.Enabled = lt < 0.2
			end)
		end
		fx.life = math.min(fx.life, t + tail)
		if opts.onImpact then
			task.spawn(opts.onImpact, at, n)
		end
	end

	local forced: { at: Vector3?, normal: Vector3? }? = nil

	fx.step = function(t: number, dt: number): boolean?
		local it = impactT
		if it then
			local lt = t - it
			for _, f in impactSteps do
				f(lt)
			end
			return nil
		end
		local f = forced
		if f then
			impact(t, f.at or pos, f.normal or -vel)
			return nil
		end
		if dt <= 0 then
			return nil
		end
		if t > range / speed * 1.6 + 1.4 then
			impact(t, pos, -vel) -- a homing shot that never arrives still ends with a pop
			return nil
		end
		local tp = targetPos()
		local d = vel.Unit
		if tp and homing > 0 then
			local want = tp - pos
			if want.Magnitude > 1e-3 then
				want = want.Unit
				local ang = math.acos(math.clamp(d:Dot(want), -1, 1))
				local maxTurn = homing * dt
				if ang > 1e-4 then
					d = d:Lerp(want, math.min(1, maxTurn / ang)).Unit
				end
			end
		end
		vel = d * speed + Vector3.new(0, -gravity * dt, 0)
		if gravity > 0 then
			speed = vel.Magnitude
		end
		local stepVec = vel * dt
		if tp and (tp - pos).Magnitude <= stepVec.Magnitude + 0.5 * s then
			impact(t, tp, pos - tp)
			return nil
		end
		if opts.collide ~= false then
			local hit = Workspace:Raycast(pos, stepVec, params)
			if hit then
				impact(t, hit.Position, hit.Normal)
				return nil
			end
		end
		pos += stepVec
		travelled += stepVec.Magnitude
		local cf = aim(pos, vel)
		core.CFrame = cf
		inner.CFrame = cf
		if travelled >= range then
			impact(t, pos, -vel) -- air pop at max range
		end
		return nil
	end

	start(fx)
	local h = baseHandle(fx)
	h.Impact = function(_self: any, at: Vector3?, normal: Vector3?)
		if not impactT then
			forced = { at = at, normal = normal }
		end
	end
	return h
end

-------------------------------------------------------------------------------
-- Aura (persistent, attached to the character with Attachments)
-------------------------------------------------------------------------------
export type AuraOptions = CommonOptions & {
	intensity: number?, -- 0..1 (default 1)
	rim: boolean?, -- Highlight outline rim, no fill (default true)
	ring: boolean?, -- breathing foot ring (default true)
	wisps: number?, -- orbiting Trail wisps (default 2, 0 = off)
	light: boolean?, -- small light above and behind the head (default false: lights tint the body)
}

--[[ Persistent aura. Everything lives on Attachments of the root part or on adornments: no glow parts
	welded to the body, and the rim is an outline (FillTransparency 1) so the character stays untinted.
	Sleeps beyond Config.lowDetailDistance (wakes inside 85 % of it). ]]
function Abilities.Aura(character: Model, options: AuraOptions?): AuraHandle
	local opts: AuraOptions = options or {}
	local root = rootOf(character)
	if not root then
		return deadHandle()
	end
	local fx = admit("Aura", root.Position, opts, "teal", true, math.huge)
	if not fx then
		return deadHandle()
	end
	local pal, s = fx.pal, fx.scale
	local feet = feetOffset(character, root)
	local made: { Instance } = {}
	local function own(inst: Instance): Instance
		table.insert(made, inst)
		return inst
	end
	table.insert(fx.cleanup, function()
		for _, inst in made do
			inst:Destroy()
		end
	end)

	local feetAtt = own(newAttachment("AuraFeet", root, CFrame.new(0, feet + 0.2, 0))) :: Attachment
	-- rising motes: slow, sparse, light on top
	local motes = newEmitter(feetAtt, "glow_soft", {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(70, 70),
		Speed = NumberRange.new(1.2 * s, 2.6 * s),
		Acceleration = Vector3.new(0, 2.5 * s, 0),
		Drag = 0.8,
		Lifetime = NumberRange.new(1.1, 1.6),
		Size = ns({ { 0, 0 }, { 0.25, 0.22 * s }, { 1, 0 } }),
		Transparency = ns({ { 0, 1 }, { 0.2, 0.15 }, { 1, 1 } }),
		Color = cs({ { 0, pal.main }, { 1, pal.hot } }),
		LightEmission = 1,
	}, true)
	-- dark specks for value (decoration)
	local specks = if fx.deco
		then newEmitter(feetAtt, "spark_square", {
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(60, 60),
			Speed = NumberRange.new(1 * s, 2 * s),
			Acceleration = Vector3.new(0, 1.5 * s, 0),
			Lifetime = NumberRange.new(0.9, 1.3),
			Size = ns({ { 0, 0.12 * s }, { 1, 0 } }),
			Transparency = ns({ { 0, 0.2 }, { 1, 1 } }),
			Rotation = NumberRange.new(0, 360),
			Color = ColorSequence.new(pal.dark),
			LightEmission = 0,
		}, true)
		else nil

	-- rim: outline only
	local rim: Highlight? = nil
	if opts.rim ~= false then
		local hl = Instance.new("Highlight")
		hl.Adornee = character
		hl.FillTransparency = 1
		hl.OutlineColor = pal.glow
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = fx.root
		rim = hl
	end

	-- foot ring: thin bright ring over a faint dark ring (reads on light and dark floors)
	local ringOuter: CylinderHandleAdornment? = nil
	local ringDark: CylinderHandleAdornment? = nil
	if opts.ring ~= false then
		local base = CFrame.new(0, feet + 0.06, 0)
		ringDark = newDisc(fx.root, root, base, 2.9 * s, 0.5 * s, pal.dark, 0.55)
		ringOuter = newDisc(fx.root, root, base * CFrame.new(0, 0.02, 0), 2.7 * s, 0.12 * s, pal.main:Lerp(pal.hot, 0.3), 0.25)
	end

	-- orbit wisps: two Attachments each, a short Trail between them
	type Wisp = { a: Attachment, b: Attachment, trail: Trail, phase: number, height: number, radius: number, speed: number }
	local wisps: { Wisp } = {}
	local nW = if fx.deco then (opts.wisps or 2) else 0
	for i = 1, nW do
		local a = own(newAttachment("WispA" .. i, root)) :: Attachment
		local b = own(newAttachment("WispB" .. i, root)) :: Attachment
		local tr = Instance.new("Trail")
		tr.Attachment0 = a
		tr.Attachment1 = b
		tr.Lifetime = 0.35
		tr.FaceCamera = true
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.WidthScale = ns({ { 0, 1 }, { 1, 0 } })
		tr.Color = cs({ { 0, pal.hot }, { 0.35, pal.main }, { 1, pal.main:Lerp(pal.dark, 0.5) } })
		tr.Transparency = ns({ { 0, 0.1 }, { 1, 1 } })
		tr.Parent = fx.root
		table.insert(wisps, {
			a = a,
			b = b,
			trail = tr,
			phase = fx.rng:NextNumber(0, math.pi * 2),
			height = fx.rng:NextNumber(-1.2, 1.4),
			radius = 2.1 * s,
			speed = (if i % 2 == 0 then -1 else 1) * fx.rng:NextNumber(2.4, 3.2),
		})
	end

	local light: PointLight? = nil
	if opts.light == true then
		local la = own(newAttachment("AuraLight", root, CFrame.new(0, 3.5, 1.5))) :: Attachment
		light = newLight(la, pal.glow, 0.6, 8 * s)
	end

	local intensity = clamp01(opts.intensity or 1)
	local awake = true
	local motesAlive, specksAlive = 0, 0
	local function apply()
		local k = if awake then intensity else 0
		motesAlive = setStream(fx, motes, 7 * k, motesAlive)
		specksAlive = setStream(fx, specks, 3 * k, specksAlive)
		if rim then
			rim.Enabled = k > 0.01
			rim.OutlineTransparency = lerp(1, 0.3, k)
		end
		for _, w in wisps do
			w.trail.Enabled = k > 0.05
		end
		if light then
			light.Enabled = k > 0.05
			light.Brightness = 0.6 * k
		end
	end
	apply()

	local nextSleepCheck = 0
	fx.step = function(t: number, _dt: number): boolean?
		if not character.Parent or not root.Parent then
			return true
		end
		if t >= nextSleepCheck then
			nextSleepCheck = t + 0.5
			local cam = Workspace.CurrentCamera
			if cam and not fx.important then
				local d = (cam.CFrame.Position - root.Position).Magnitude
				local lim = Abilities.Config.lowDetailDistance
				if awake and d > lim then
					awake = false
					apply()
				elseif not awake and d < lim * 0.85 then
					awake = true
					apply()
				end
			end
		end
		if not awake then
			return nil
		end
		local breathe = 0.5 + 0.5 * math.sin(t * 2.4)
		local ro = ringOuter
		if ro then
			setDisc(ro, (2.55 + 0.25 * breathe) * s, 0.12 * s)
			ro.Transparency = lerp(1, lerp(0.45, 0.2, breathe), intensity)
		end
		local rd = ringDark
		if rd then
			rd.Transparency = lerp(1, 0.55, intensity)
		end
		for _, w in wisps do
			local ang = w.phase + t * w.speed
			local y = w.height + 0.5 * math.sin(t * 1.3 + w.phase)
			local p = Vector3.new(math.cos(ang) * w.radius, y, math.sin(ang) * w.radius)
			w.a.Position = p + Vector3.new(0, 0.18 * s, 0)
			w.b.Position = p - Vector3.new(0, 0.18 * s, 0)
		end
		return nil
	end

	start(fx)
	local h = baseHandle(fx)
	h.SetIntensity = function(_self: any, x: number)
		intensity = clamp01(x)
		if not fx.finished then
			apply()
		end
	end
	return h
end

-------------------------------------------------------------------------------
-- Telegraph (ground AoE warning)
-------------------------------------------------------------------------------
export type TelegraphOptions = CommonOptions & {
	duration: number?, -- fill time in seconds (default 1)
	radius: number?, -- circle / cone (default 8 / 12)
	angle: number?, -- cone width in degrees (default 60)
	length: number?, -- line (default 20)
	width: number?, -- line (default 4)
	elapsed: number?, -- seconds already gone (late arrival: GetServerTimeNow() - startedAt); fills the remainder
	onPop: (() -> ())?, -- runs when the fill completes (visual only; damage stays on the server)
}

--[[ Ground warning. shape "circle" (cf.Position = centre), "cone" (apex at cf, opens along LookVector)
	or "line" (starts at cf, runs along LookVector). Raycasts to the floor and follows its slope.
	Layers bottom to top: dark outline (bright floors), translucent base fill, growing progress fill with
	a hot leading edge, bright rim (dark floors). Gameplay information: important by default. ]]
function Abilities.Telegraph(cf: CFrame, shape: string, options: TelegraphOptions?): TelegraphHandle
	local opts: TelegraphOptions = options or {}
	if opts.important == nil then
		opts = table.clone(opts)
		opts.important = true
	end
	local dur = math.max(0.05, opts.duration or 1)
	local fx = admit("Telegraph", cf.Position, opts, "fire", false, dur + 0.5)
	if not fx then
		return deadHandle()
	end
	fx.t0 -= math.clamp(opts.elapsed or 0, 0, dur) -- late arrival: start part-filled
	local pal, s = fx.pal, fx.scale
	local gp, gn = groundAt(cf.Position)
	local frame = surfaceFrame(gp + gn * 0.04, gn, cf.LookVector)
	fx.anchor.CFrame = frame
	local A = fx.anchor
	local P = fx.root

	local outlineC = pal.dark
	local fillC = pal.main
	local rimC = pal.main:Lerp(pal.hot, 0.45)
	local edgeC = pal.hot
	local OUT = 0.32 * s -- dark outline width
	local RIM = 0.16 * s -- bright rim width
	local y0, y1, y2, y3 = CFrame.new(0, 0, 0), CFrame.new(0, 0.012, 0), CFrame.new(0, 0.024, 0), CFrame.new(0, 0.036, 0)

	local fills: { GuiBase3d } = {}
	local rims: { GuiBase3d } = {}
	local setProgress: (p: number) -> ()

	if shape == "cone" then
		local R = (opts.radius or 12) * s
		local ang = math.clamp(opts.angle or 60, 5, 359)
		local secCF = CFrame.Angles(0, 0, math.rad(-90 - ang * 0.5 + Abilities.Config.coneSectorOffset))
		local function sector(cfo: CFrame, outer: number, inner: number, angle: number, c: Color3, tr: number): CylinderHandleAdornment
			local a = newDisc(P, A, cfo, outer, inner, c, tr)
			a.Angle = angle
			a.CFrame = cfo * FLAT * secCF
			return a
		end
		-- outline: a slightly larger dark sector pushed back so its straight sides show too
		local back = OUT / math.sin(math.rad(math.min(ang, 179) * 0.5))
		sector(y0 * CFrame.new(0, 0, back), R + OUT + back, 0, ang, outlineC, 0.2)
		table.insert(fills, sector(y1, R, 0, ang, fillC, 0.78))
		local prog = sector(y2, 0.01, 0, ang, fillC, 0.45)
		local edge = sector(y3, 0.01, 0, ang, edgeC, 0.15)
		table.insert(fills, prog)
		table.insert(rims, sector(y3, R, R - RIM, ang, rimC, 0.05))
		for _, side in { -1, 1 } do
			local yaw = math.rad(side * ang * 0.5)
			local d = CFrame.Angles(0, yaw, 0)
			table.insert(rims, newBox(P, A, y3 * d * CFrame.new(0, 0, -R * 0.5), Vector3.new(RIM, 0.03, R), rimC, 0.05))
		end
		setProgress = function(p: number)
			local r = math.max(0.02, R * p)
			setDisc(prog, r)
			setDisc(edge, r, 0.22 * s)
		end
	elseif shape == "line" then
		local L = (opts.length or 20) * s
		local W = (opts.width or 4) * s
		newBox(P, A, y0 * CFrame.new(0, 0, -L * 0.5), Vector3.new(W + OUT * 2, 0.03, L + OUT * 2), outlineC, 0.2)
		table.insert(fills, newBox(P, A, y1 * CFrame.new(0, 0, -L * 0.5), Vector3.new(W, 0.03, L), fillC, 0.78))
		local prog = newBox(P, A, y2, Vector3.new(W, 0.03, 0.01), fillC, 0.45)
		local edge = newBox(P, A, y3, Vector3.new(W, 0.03, 0.22 * s), edgeC, 0.15)
		table.insert(fills, prog)
		-- rim: two sides and the far end
		for _, side in { -1, 1 } do
			table.insert(rims, newBox(P, A, y3 * CFrame.new(side * (W - RIM) * 0.5, 0, -L * 0.5), Vector3.new(RIM, 0.03, L), rimC, 0.05))
		end
		table.insert(rims, newBox(P, A, y3 * CFrame.new(0, 0, -L + RIM * 0.5), Vector3.new(W, 0.03, RIM), rimC, 0.05))
		setProgress = function(p: number)
			local l = math.max(0.02, L * p)
			prog.Size = Vector3.new(W, 0.03, l)
			prog.CFrame = y2 * CFrame.new(0, 0, -l * 0.5)
			edge.CFrame = y3 * CFrame.new(0, 0, -math.max(0.11 * s, l - 0.11 * s))
		end
	else
		if shape ~= "circle" then
			warnOnce("shape:" .. tostring(shape), "unknown telegraph shape " .. tostring(shape) .. "; drawing a circle")
		end
		local R = (opts.radius or 8) * s
		newDisc(P, A, y0, R + OUT, 0, outlineC, 0.2)
		table.insert(fills, newDisc(P, A, y1, R, 0, fillC, 0.78))
		local prog = newDisc(P, A, y2, 0.01, 0, fillC, 0.45)
		local edge = newDisc(P, A, y3, 0.01, 0, edgeC, 0.15)
		table.insert(fills, prog)
		table.insert(rims, newDisc(P, A, y3, R, R - RIM, rimC, 0.05))
		setProgress = function(p: number)
			local r = math.max(0.02, R * p)
			setDisc(prog, r)
			setDisc(edge, r, 0.22 * s)
		end
	end
	setProgress(0)

	local popT: number? = nil
	local cancelT: number? = nil
	local all = fx.root:GetChildren()
	local base: { [Instance]: number } = {}
	for _, c in all do
		if c:IsA("GuiBase3d") then
			base[c] = c.Transparency
		end
	end
	local function fadeAll(k: number)
		for inst, tr in base do
			(inst :: GuiBase3d).Transparency = lerp(tr, 1, k)
		end
	end

	fx.step = function(t: number, _dt: number): boolean?
		local ct = cancelT
		if ct then
			local k = (t - ct) / 0.15
			fadeAll(easeOut(k, 2))
			return k >= 1
		end
		local pt = popT
		if not pt then
			-- fade in over 0.08 s, then the progress fill grows (ease in: the last third feels urgent)
			fadeAll(1 - easeOut(t / 0.08, 2))
			setProgress(easeIn(t / dur, 1.3))
			if t >= dur then
				popT = t
				for _, f in fills do
					(f :: GuiBase3d).Color3 = pal.hot:Lerp(pal.main, 0.25)
				end
				if opts.onPop then
					task.spawn(opts.onPop)
				end
			end
			return nil
		end
		-- pop: fill flashes hot, everything fades in 0.22 s
		local k = (t - pt) / 0.22
		fadeAll(easeOut(k, 1.6))
		return k >= 1
	end

	start(fx)
	local h = baseHandle(fx)
	h.Cancel = function(_self: any)
		if not popT and not cancelT and not fx.finished then
			cancelT = os.clock() - fx.t0
		end
	end
	return h
end

-------------------------------------------------------------------------------
-- Shield
-------------------------------------------------------------------------------
export type ShieldOptions = CommonOptions & {
	radius: number?, -- default from the target's size (3..8 studs)
	duration: number?, -- auto end after this many seconds (default: until Break/Destroy)
	breakOnExpire: boolean?, -- end with the break burst instead of a quiet fade
}

function Abilities.Shield(target: Model | BasePart, options: ShieldOptions?): ShieldHandle
	local opts: ShieldOptions = options or {}
	local follow: BasePart? = if target:IsA("Model") then rootOf(target) elseif target:IsA("BasePart") then target else nil
	if not follow then
		return deadHandle()
	end
	local fx = admit("Shield", follow.Position, opts, "ice", true, math.huge)
	if not fx then
		return deadHandle()
	end
	local pal, s = fx.pal, fx.scale
	local R: number
	if opts.radius then
		R = opts.radius * s
	elseif target:IsA("Model") then
		R = math.clamp(target:GetExtentsSize().Y * 0.6, 3, 8) * s
	else
		R = math.clamp(follow.Size.Magnitude * 0.6, 3, 8) * s
	end

	-- shell: ForceField material gives the animated fresnel edge; Highlight adds a crisp silhouette rim
	local shell = newPart("Shell", follow.CFrame, fx.root)
	shell.Shape = Enum.PartType.Ball
	shell.Material = Enum.Material.ForceField
	shell.Color = pal.main
	shell.Size = Vector3.one * 0.1
	shell.Transparency = 0
	local rim = Instance.new("Highlight")
	rim.Adornee = shell
	rim.FillTransparency = 1
	rim.OutlineColor = pal.glow
	rim.OutlineTransparency = 0.3
	rim.DepthMode = Enum.HighlightDepthMode.Occluded
	rim.Parent = fx.root

	local glints = if fx.deco
		then newEmitter(shell, "glow_soft", {
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Speed = NumberRange.new(0),
			Lifetime = NumberRange.new(0.4, 0.6),
			Size = ns({ { 0, 0 }, { 0.3, 0.3 * s }, { 1, 0 } }),
			Transparency = ns({ { 0, 0.2 }, { 1, 1 } }),
			Color = ColorSequence.new(pal.hot),
			LightEmission = 1,
			LockedToPart = true,
		}, true)
		else nil
	local glintsAlive = setStream(fx, glints, 4, 0)

	type Ripple = { a: CylinderHandleAdornment, t0: number, size: number }
	local ripples: { Ripple } = {}
	local hitFlash = 0
	local breakT: number? = nil
	local fadeT: number? = nil
	local light: PointLight? = nil
	local lastT = 0
	local shardAtt = newAttachment("Shards", fx.anchor)
	local breakRing: CylinderHandleAdornment? = nil

	local function doBreak(t: number)
		if breakT then
			return
		end
		breakT = t
		glintsAlive = setStream(fx, glints, 0, glintsAlive)
		local c = shell.Position
		fx.anchor.CFrame = CFrame.new(c)
		local shards = newEmitter(shardAtt, "spark_square", {
			Shape = Enum.ParticleEmitterShape.Sphere,
			SpreadAngle = Vector2.new(180, 180),
			Speed = NumberRange.new(14 * s, 26 * s),
			Drag = 2,
			Acceleration = Vector3.new(0, -30, 0),
			Lifetime = NumberRange.new(0.4, 0.7),
			Size = ns({ { 0, 0.3 * s }, { 1, 0.08 * s } }),
			Transparency = ns({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-400, 400),
			Color = cs({ { 0, pal.hot }, { 1, pal.main } }),
			LightEmission = 0.6,
		}, true)
		burst(fx, shards, 22)
		burst(fx, sparkEmitter(fx, shardAtt, s, 180, { 20, 36 }), 12)
		local ra = newPart("BreakRing", CFrame.new(c), fx.root)
		breakRing = newDisc(fx.root, ra, CFrame.identity, R, R - 0.4 * s, pal.hot, 0.1)
		light = newLight(newAttachment("BreakLight", fx.anchor, CFrame.new(0, R + 1, 0)), pal.glow, 2, 12 * s)
	end

	fx.step = function(t: number, dt: number): boolean?
		lastT = t
		if not follow.Parent then
			return true
		end
		local c = follow.CFrame
		local bt = breakT
		if bt then
			local u = (t - bt) / 0.18
			shell.Size = Vector3.one * 2 * R * lerp(1, 1.3, easeOut(u, 2))
			shell.CFrame = c
			shell.Transparency = easeOut(u, 1.5)
			rim.OutlineTransparency = lerp(0.1, 1, clamp01(u))
			local br = breakRing
			if br then
				local u2 = (t - bt) / 0.32
				setDisc(br, R * lerp(1, 2.2, easeOut(u2, 3)), 0.4 * s * (1 - u2) + 0.05)
				br.Transparency = lerp(0.1, 1, easeIn(u2, 1.3))
			end
			local l = light
			if l then
				l.Brightness = 2 * (1 - easeOut((t - bt) / 0.25, 2))
			end
			return t - bt > 0.8
		end
		local ft = fadeT
		if ft then
			local u = (t - ft) / 0.25
			shell.CFrame = c
			shell.Transparency = easeOut(u, 2)
			rim.OutlineTransparency = lerp(0.3, 1, clamp01(u))
			return u >= 1
		end
		if opts.duration and t >= opts.duration then
			if opts.breakOnExpire then
				doBreak(t)
			else
				fadeT = t
				glintsAlive = setStream(fx, glints, 0, glintsAlive)
			end
			return nil
		end
		-- grow in with a slight overshoot, then breathe
		local grow = easeOutBack(t / 0.22)
		shell.Size = Vector3.one * 2 * R * math.max(0.05, grow)
		shell.CFrame = c
		hitFlash = math.max(0, hitFlash - dt / 0.18)
		shell.Color = pal.main:Lerp(pal.hot, hitFlash * 0.7)
		shell.Transparency = clamp01(1 - t / 0.12) * 0.8
		rim.OutlineTransparency = lerp(0.3 + 0.1 * math.sin(t * 7.5), 0.05, hitFlash)
		for i = #ripples, 1, -1 do
			local r = ripples[i]
			local u = (t - r.t0) / 0.35
			if u >= 1 then
				r.a:Destroy()
				table.remove(ripples, i)
			else
				setDisc(r.a, lerp(0.2, 1.8, easeOut(u, 3)) * r.size, 0.25 * r.size)
				r.a.Transparency = lerp(0, 1, easeIn(u, 1.2))
			end
		end
		return nil
	end

	start(fx)
	local h = baseHandle(fx)
	h.Hit = function(_self: any, worldPos: Vector3)
		if fx.finished or breakT or fadeT then
			return
		end
		local c = shell.Position
		local d = worldPos - c
		local dir = if d.Magnitude > 1e-3 then d.Unit else Vector3.yAxis
		local surf = c + dir * R
		-- ripple: a ring adornment on the tangent plane, riding the shell
		local rel = shell.CFrame:ToObjectSpace(CFrame.lookAt(surf, surf + dir))
		local a = Instance.new("CylinderHandleAdornment")
		a.Adornee = shell
		a.CFrame = rel
		a.Height = 0.04
		a.Radius = 0.2
		a.InnerRadius = 0
		a.Color3 = pal.hot
		a.Transparency = 0
		a.Parent = fx.root
		table.insert(ripples, { a = a, t0 = lastT, size = s * math.clamp(R / 4, 0.8, 1.6) })
		if #ripples > 4 then
			ripples[1].a:Destroy()
			table.remove(ripples, 1)
		end
		hitFlash = 1
		local att = newAttachment("Hit", fx.anchor)
		att.WorldCFrame = aim(surf, dir)
		burst(fx, sparkEmitter(fx, att, s, 50, { 14, 26 }), 10)
		Debris:AddItem(att, 0.6)
	end
	h.Break = function(_self: any)
		if not fx.finished then
			doBreak(lastT)
		end
	end
	return h
end

-------------------------------------------------------------------------------
-- Beam laser
-------------------------------------------------------------------------------
export type LaserOptions = CommonOptions & {
	charge: number?, -- seconds of charge before the beam (default 0.35, 0 = instant)
	duration: number?, -- auto Stop after this many seconds of beam (default: until Stop)
	width: number?, -- outer width in studs (default 1.2)
	range: number?, -- max length (default 200)
	clip: boolean?, -- raycast and end the beam on walls (default true)
	ignore: { Instance }?,
	onEnd: (() -> ())?,
}

function Abilities.BeamLaser(fromAtt: Attachment, to: Vector3 | Attachment, options: LaserOptions?): LaserHandle
	local opts: LaserOptions = options or {}
	local fx = admit("BeamLaser", fromAtt.WorldPosition, opts, "plasma", true, math.huge)
	if not fx then
		return deadHandle()
	end
	local pal, s = fx.pal, fx.scale
	local W = (opts.width or 1.2) * s
	local chargeT = math.max(0, opts.charge or 0.35)
	local range = opts.range or 200
	local params = rayParams(opts.ignore)
	local goal: Vector3 | Attachment = to

	local endPart = newPart("End", CFrame.new(fromAtt.WorldPosition), fx.root)
	local endAtt = newAttachment("EndAtt", endPart)

	local function mkBeam(name: string, width: number, color: ColorSequence, tr: NumberSequence, emission: number, bright: number, key: string, speed: number): Beam
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0 = fromAtt
		b.Attachment1 = endAtt
		b.Width0 = width
		b.Width1 = width * 0.85
		b.Color = color
		b.Transparency = tr
		b.LightEmission = emission
		b.LightInfluence = 0
		b.Brightness = bright
		b.FaceCamera = true
		b.Segments = 1
		b.Enabled = false
		local id = texId(key)
		if id then
			b.Texture = id
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = 6 * s
			b.TextureSpeed = speed
		end
		b.Parent = fx.root
		return b
	end
	-- value: dark edge (decoration) under a saturated body with a thin white-hot core
	local edge = if fx.deco
		then mkBeam("Edge", W * 1.35, ColorSequence.new(pal.dark), ns({ { 0, 0.55 }, { 1, 0.7 } }), 0, 1, "beam_outer", 1)
		else nil
	local outer = mkBeam("Outer", W, cs({ { 0, pal.main }, { 1, pal.glow } }), ns({ { 0, 0.3 }, { 1, 0.45 } }), 1, 1.2, "beam_outer", 1.5)
	local core = mkBeam("Core", W * 0.28, ColorSequence.new(pal.hot), ns({ { 0, 0 }, { 1, 0.1 } }), 1, 1.6, "beam_core", 4)
	if edge then
		edge.ZOffset = -0.1
	end
	core.ZOffset = 0.1
	if not texId("beam_core") then
		warnOnce("fb:beam", "beam textures have no id yet; drawing solid ribbons")
	end

	-- charge: converging motes on a sphere shell + a growing glow ball just ahead of the source
	local chargeShell = newPart("ChargeShell", CFrame.new(fromAtt.WorldPosition), fx.root)
	chargeShell.Size = Vector3.one * 4.5 * s
	local converge = newEmitter(chargeShell, "glow_soft", {
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Speed = NumberRange.new(9 * s, 12 * s),
		Lifetime = NumberRange.new(0.2, 0.24),
		Size = ns({ { 0, 0.1 * s }, { 1, 0.3 * s } }),
		Transparency = ns({ { 0, 1 }, { 0.3, 0.1 }, { 1, 0.4 } }),
		Color = cs({ { 0, pal.main }, { 1, pal.hot } }),
		LightEmission = 1,
	}, true)
	local orb = neonPart("ChargeOrb", Enum.PartType.Ball, pal.hot, CFrame.new(fromAtt.WorldPosition), fx.root)
	orb.Size = Vector3.one * 0.05

	-- endpoint: impact glow ball, spark stream, the one light
	local glow = neonPart("ImpactGlow", Enum.PartType.Ball, pal.main:Lerp(pal.hot, 0.35), endPart.CFrame, fx.root)
	glow.Transparency = 1
	glow.Size = Vector3.one * 1.6 * W
	local hitAtt = newAttachment("Hit", endPart)
	local sparks = sparkEmitter(fx, hitAtt, s, 70, { 10, 22 })
	local light = newLight(endPart, pal.glow, 0, 10 * s)
	local sparksAlive = 0

	local pulses = 0
	local beamT: number? = nil
	local stopT: number? = nil
	local lastT = 0
	local dir = Vector3.new(0, 0, -1)

	local function goalPos(): Vector3?
		if typeof(goal) == "Vector3" then
			return goal
		elseif typeof(goal) == "Instance" and goal.Parent then
			return goal.WorldPosition
		end
		return nil
	end

	local function updateEnd()
		local from = fromAtt.WorldPosition
		local g = goalPos() or (from + dir * range)
		local v = g - from
		if v.Magnitude > 1e-3 then
			dir = v.Unit
		end
		local len = math.min(v.Magnitude, range)
		local endPos = from + dir * len
		local normal = -dir
		if opts.clip ~= false then
			local hit = Workspace:Raycast(from, dir * len, params)
			if hit then
				endPos = hit.Position
				normal = hit.Normal
			end
		end
		endPart.CFrame = CFrame.new(endPos)
		hitAtt.WorldCFrame = aim(endPos + normal * 0.1, normal)
		glow.CFrame = endPart.CFrame
	end

	local function doStop(t: number)
		if stopT then
			return
		end
		stopT = t
		sparksAlive = setStream(fx, sparks, 0, sparksAlive)
		burst(fx, sparkEmitter(fx, hitAtt, s, 80, { 16, 30 }), 14)
		burst(fx, flashEmitter(fx, hitAtt, 2.2 * W, pal.hot), 1)
		if opts.onEnd then
			task.spawn(opts.onEnd)
		end
	end

	local function setWidth(k: number, t: number)
		local wob = 1 + 0.08 * math.sin(t * 31)
		outer.Width0, outer.Width1 = W * k * wob, W * 0.85 * k * wob
		core.Width0, core.Width1 = W * 0.28 * k, W * 0.24 * k
		if edge then
			edge.Width0, edge.Width1 = W * 1.35 * k * wob, W * 1.15 * k * wob
		end
	end

	fx.step = function(t: number, _dt: number): boolean?
		lastT = t
		if not fromAtt:IsDescendantOf(Workspace) then
			return true
		end
		local from = fromAtt.WorldPosition
		updateEnd()
		local st = stopT
		if st then
			local u = (t - st) / 0.12
			setWidth(1 - easeIn(u, 1.5), t)
			glow.Transparency = lerp(0.2, 1, clamp01(u))
			light.Brightness = 2 * (1 - clamp01((t - st) / 0.2))
			if u >= 1 then
				outer.Enabled = false
				core.Enabled = false
				if edge then
					edge.Enabled = false
				end
			end
			return t - st > 0.6
		end
		if t < chargeT then
			local u = t / chargeT
			chargeShell.CFrame = CFrame.new(from)
			orb.CFrame = CFrame.new(from + dir * 0.6 * s)
			orb.Size = Vector3.one * math.max(0.05, 0.55 * W * easeIn(u, 1.6))
			orb.Transparency = lerp(0.6, 0, u)
			local want = math.floor(u * 3)
			while pulses <= want and pulses < 3 do
				pulses += 1
				burst(fx, converge, 5)
			end
			return nil
		end
		local bt: number = beamT or t
		if not beamT then
			beamT = t
			orb.Transparency = 1
			outer.Enabled = true
			core.Enabled = true
			if edge then
				edge.Enabled = true
			end
			sparksAlive = setStream(fx, sparks, 30, sparksAlive)
			burst(fx, flashEmitter(fx, worldAttachment(fx, "Muzzle", CFrame.new(from)), 1.4 * W, pal.hot), 1)
		end
		local bu = t - bt
		setWidth(easeOut(bu / 0.08, 2), t)
		local pulse = 0.5 + 0.5 * math.sin(t * 18)
		glow.Transparency = lerp(0.35, 0.15, pulse)
		glow.Size = Vector3.one * 1.6 * W * (0.9 + 0.2 * pulse)
		light.Brightness = 1.6 + 0.6 * pulse
		if opts.duration and bu >= opts.duration then
			doStop(t)
		end
		return nil
	end

	start(fx)
	local h = baseHandle(fx)
	h.SetTarget = function(_self: any, newTo: Vector3 | Attachment)
		goal = newTo
	end
	h.Stop = function(_self: any)
		if not fx.finished then
			doStop(lastT)
		end
	end
	return h
end

-------------------------------------------------------------------------------
-- Heal / Buff pickups (on a character)
-------------------------------------------------------------------------------
export type PickupOptions = CommonOptions & {
	duration: number?, -- seconds of rising motes (default 0.9)
}

local function pickup(kind: string, character: Model, opts: PickupOptions): Handle
	local root = rootOf(character)
	if not root then
		return deadHandle()
	end
	local motesFor = math.max(0.2, opts.duration or 0.9)
	local fx = admit(kind, root.Position, opts, if kind == "Heal" then "heal" else "holy", false, motesFor + 1.3)
	if not fx then
		return deadHandle()
	end
	local pal, s = fx.pal, fx.scale
	local feet = feetOffset(character, root)
	local feetAtt = newAttachment(kind .. "Feet", root, CFrame.new(0, feet + 0.2, 0))
	local chestAtt = newAttachment(kind .. "Chest", root, CFrame.new(0, 0.6, 0))
	table.insert(fx.cleanup, function()
		feetAtt:Destroy()
		chestAtt:Destroy()
	end)

	local motes = newEmitter(feetAtt, "glow_soft", {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(40, 40),
		Speed = NumberRange.new(3 * s, 6 * s),
		Acceleration = Vector3.new(0, 2 * s, 0),
		Drag = 1,
		Lifetime = NumberRange.new(0.8, 1.2),
		Size = ns({ { 0, 0 }, { 0.2, 0.32 * s }, { 1, 0 } }),
		Transparency = ns({ { 0, 0.1 }, { 0.7, 0.2 }, { 1, 1 } }),
		Color = cs({ { 0, pal.main }, { 1, pal.hot } }),
		LightEmission = 1,
		LockedToPart = true,
	}, true)
	local steps: { (t: number) -> () } = {}
	local base = CFrame.new(0, feet + 0.06, 0)

	if kind == "Heal" then
		-- ring expands out from the feet; faint ground disc under it (decoration)
		local ring = newDisc(fx.root, root, base * CFrame.new(0, 0.02, 0), 1.2 * s, 0.5 * s, pal.main:Lerp(pal.hot, 0.3), 0.15)
		table.insert(steps, ringStep(ring, 0, 0.55, 1.2 * s, 4.5 * s, 0.5 * s, 0.1 * s, 0.15))
		if fx.deco then
			local disc = newDisc(fx.root, root, base, 3.2 * s, 0, pal.main, 0.7)
			table.insert(steps, function(t: number)
				disc.Transparency = lerp(0.7, 1, easeOut(t / 0.7, 2))
			end)
		end
		local glints = newEmitter(chestAtt, "flash_hot", {
			SpreadAngle = Vector2.new(180, 180),
			Speed = NumberRange.new(2 * s, 4 * s),
			Drag = 3,
			Lifetime = NumberRange.new(0.4, 0.6),
			Size = ns({ { 0, 0 }, { 0.3, 0.45 * s }, { 1, 0 } }),
			Rotation = NumberRange.new(0, 360),
			Color = ColorSequence.new(pal.spark),
			LightEmission = 1,
			LockedToPart = true,
		}, true)
		local glinted = false
		table.insert(steps, function(t: number)
			if not glinted and t >= 0.15 then
				glinted = true
				burst(fx, glints, 6)
			end
		end)
	else
		-- Buff: ring implodes onto the feet, then a small bright pop ring; streaks shoot upward
		local ring = newDisc(fx.root, root, base * CFrame.new(0, 0.02, 0), 4.5 * s, 0.15 * s, pal.main:Lerp(pal.hot, 0.3), 0.6)
		table.insert(steps, function(t: number)
			local u = t / 0.32
			ring.Visible = u <= 1
			setDisc(ring, lerp(4.5, 1.1, easeIn(u, 2)) * s, lerp(0.15, 0.45, u) * s)
			ring.Transparency = lerp(0.6, 0.05, u)
		end)
		local pop = newDisc(fx.root, root, base * CFrame.new(0, 0.03, 0), 1 * s, 0.4 * s, pal.hot, 0)
		table.insert(steps, ringStep(pop, 0.32, 0.3, 1 * s, 2.8 * s, 0.4 * s, 0.06 * s, 0))
		local streaks = newEmitter(feetAtt, "spark_streak", {
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(18, 18),
			Speed = NumberRange.new(10 * s, 14 * s),
			Drag = 1.5,
			Lifetime = NumberRange.new(0.35, 0.5),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = ns({ { 0, 0.3 * s }, { 1, 0 } }),
			Transparency = ns({ { 0, 0 }, { 1, 1 } }),
			Color = cs({ { 0, pal.hot }, { 1, pal.main } }),
			LightEmission = 1,
			LockedToPart = true,
		}, true)
		local shots = 0
		table.insert(steps, function(t: number)
			while shots < 3 and t >= 0.32 + shots * 0.08 do
				shots += 1
				burst(fx, streaks, 5)
			end
		end)
	end

	local pulsesDone = 0
	local pulseCount = math.max(1, math.floor(motesFor / 0.08))
	fx.step = function(t: number, _dt: number): boolean?
		if not root.Parent then
			return true
		end
		while pulsesDone < pulseCount and t >= pulsesDone * 0.08 do
			pulsesDone += 1
			burst(fx, motes, 3)
		end
		for _, f in steps do
			f(t)
		end
		return nil
	end
	start(fx)
	return baseHandle(fx)
end

function Abilities.Heal(character: Model, options: PickupOptions?): Handle
	local o: PickupOptions = options or {}
	return pickup("Heal", character, o)
end

function Abilities.Buff(character: Model, options: PickupOptions?): Handle
	local o: PickupOptions = options or {}
	return pickup("Buff", character, o)
end

-------------------------------------------------------------------------------
-- Teleport
-------------------------------------------------------------------------------
export type TeleportOptions = CommonOptions & {
	delay: number?, -- seconds between the implode and the arrival burst (default 0.25)
}

function Abilities.Teleport(fromCF: CFrame, toCF: CFrame, options: TeleportOptions?): Handle
	local opts: TeleportOptions = options or {}
	local delay = math.max(0, opts.delay or 0.25)
	local fx = admit("Teleport", toCF.Position, opts, "violet", false, delay + 1.2)
	if not fx then
		return deadHandle()
	end
	local pal, s = fx.pal, fx.scale
	local steps: { (t: number) -> () } = {}

	-- source: imploding ring + converging motes + thin column that collapses
	local gpA, gnA = groundAt(fromCF.Position)
	local srcGround = newPart("SrcGround", surfaceFrame(gpA + gnA * 0.05, gnA, fromCF.LookVector), fx.root)
	local implode = newDisc(fx.root, srcGround, CFrame.identity, 4 * s, 0.2 * s, pal.main:Lerp(pal.hot, 0.3), 0.4)
	table.insert(steps, function(t: number)
		local u = t / 0.25
		implode.Visible = u <= 1
		setDisc(implode, lerp(4, 0.3, easeIn(u, 2)) * s, lerp(0.2, 0.3, u) * s)
		implode.Transparency = lerp(0.4, 0, u)
	end)
	local shellA = newPart("SrcShell", CFrame.new(fromCF.Position), fx.root)
	shellA.Size = Vector3.one * 7 * s
	local converge = newEmitter(shellA, "glow_soft", {
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Speed = NumberRange.new(13 * s, 15 * s),
		Lifetime = NumberRange.new(0.22, 0.25),
		Size = ns({ { 0, 0.15 * s }, { 1, 0.35 * s } }),
		Transparency = ns({ { 0, 1 }, { 0.3, 0.1 }, { 1, 0.3 } }),
		Color = cs({ { 0, pal.main }, { 1, pal.hot } }),
		LightEmission = 1,
	}, true)
	burst(fx, converge, 20)
	local colA = neonPart("SrcColumn", Enum.PartType.Cylinder, pal.hot, vertical(CFrame.new(fromCF.Position)), fx.root)
	table.insert(steps, function(t: number)
		local u = t / 0.25
		colA.Transparency = if u > 1 then 1 else lerp(0.5, 0.1, u)
		colA.Size = Vector3.new(7 * s, math.max(0.05, lerp(1.2, 0.08, easeIn(u, 1.5)) * s), math.max(0.05, lerp(1.2, 0.08, easeIn(u, 1.5)) * s))
	end)

	-- destination: flash, column burst, expanding ring, sparks up, dust (texture only), one light
	local gpB, gnB = groundAt(toCF.Position)
	local dstGround = newPart("DstGround", surfaceFrame(gpB + gnB * 0.05, gnB, toCF.LookVector), fx.root)
	local dstAtt = newAttachment("Dst", fx.anchor)
	dstAtt.WorldCFrame = aim(gpB + gnB * 0.3, gnB)
	local flash = flashEmitter(fx, worldAttachment(fx, "DstFlash", CFrame.new(toCF.Position + Vector3.new(0, 0.5, 0))), 3 * s, pal.hot)
	local sparks = sparkEmitter(fx, dstAtt, s, 35, { 20, 36 })
	local dust = if fx.deco
		then newEmitter(dstAtt, "smoke_puff", {
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(85, 85),
			Speed = NumberRange.new(6 * s, 10 * s),
			Drag = 4,
			Lifetime = NumberRange.new(0.5, 0.8),
			Size = ns({ { 0, 0.8 * s }, { 1, 2.2 * s } }),
			Transparency = ns({ { 0, 0.5 }, { 1, 1 } }),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-60, 60),
			Color = ColorSequence.new(pal.main:Lerp(pal.dark, 0.6)),
			LightEmission = 0,
		}, false)
		else nil
	local colB = neonPart("DstColumn", Enum.PartType.Cylinder, pal.main:Lerp(pal.hot, 0.4), vertical(CFrame.new(gpB + Vector3.new(0, 4.5 * s, 0))), fx.root)
	colB.Transparency = 1
	local ringB = newDisc(fx.root, dstGround, CFrame.identity, 0.5 * s, 0.4 * s, pal.main:Lerp(pal.hot, 0.3), 0.1)
	ringB.Visible = false
	table.insert(steps, ringStep(ringB, delay, 0.4, 0.5 * s, 6 * s, 0.45 * s, 0.08 * s, 0.1))
	local ringDark = if fx.deco then newDisc(fx.root, dstGround, CFrame.new(0, -0.01, 0), 0.7 * s, 0.5 * s, pal.dark, 0.4) else nil
	if ringDark then
		ringDark.Visible = false
		table.insert(steps, ringStep(ringDark, delay + 0.04, 0.5, 0.7 * s, 7 * s, 0.5 * s, 0.1 * s, 0.4))
	end
	local light = newLight(worldAttachment(fx, "DstLight", CFrame.new(toCF.Position + Vector3.new(0, 4, 0))), pal.glow, 0, 14 * s)
	local arrived = false
	table.insert(steps, function(t: number)
		local u = (t - delay) / 0.32
		if u < 0 then
			return
		end
		if not arrived then
			arrived = true
			burst(fx, flash, 1)
			burst(fx, sparks, 22)
			burst(fx, dust, 6)
		end
		local w = if u < 0.3 then lerp(0.2, 1.4, easeOut(u / 0.3, 2)) else lerp(1.4, 0.05, easeIn((u - 0.3) / 0.7, 1.5))
		colB.Size = Vector3.new(9 * s * lerp(0.6, 1, easeOut(u, 2)), math.max(0.05, w * s), math.max(0.05, w * s))
		colB.Transparency = if u >= 1 then 1 else lerp(0.1, 0.8, easeIn(u, 1.5))
		light.Brightness = 3 * (1 - easeOut((t - delay) / 0.3, 2))
	end)

	fx.step = function(t: number, _dt: number): boolean?
		for _, f in steps do
			f(t)
		end
		return nil
	end
	start(fx)
	return baseHandle(fx)
end

-------------------------------------------------------------------------------
-- LevelUp (celebration, not combat)
-------------------------------------------------------------------------------
export type LevelUpOptions = CommonOptions & {
	light: boolean?, -- default true (one light above the head)
}

function Abilities.LevelUp(character: Model, options: LevelUpOptions?): Handle
	local opts: LevelUpOptions = options or {}
	if opts.important == nil and Players.LocalPlayer and character == Players.LocalPlayer.Character then
		opts = table.clone(opts)
		opts.important = true
	end
	local root = rootOf(character)
	if not root then
		return deadHandle()
	end
	local fx = admit("LevelUp", root.Position, opts, "holy", false, 2.2)
	if not fx then
		return deadHandle()
	end
	local pal, s = fx.pal, fx.scale
	local feet = feetOffset(character, root)
	local head = 2.2 -- studs above the root centre to the top of the head (R15 and R6)
	local made: { Instance } = {}
	table.insert(fx.cleanup, function()
		for _, inst in made do
			inst:Destroy()
		end
	end)
	local function att(name: string, cf: CFrame): Attachment
		local a = newAttachment(name, root, cf)
		table.insert(made, a)
		return a
	end
	local feetAtt = att("LvlFeet", CFrame.new(0, feet + 0.2, 0))
	local headAtt = att("LvlHead", CFrame.new(0, head, 0))
	local steps: { (t: number) -> () } = {}
	local base = CFrame.new(0, feet + 0.06, 0)

	-- 1. two foot rings: a slower body ring, then a bigger, faster, thinner hot ring (escalation)
	local r1 = newDisc(fx.root, root, base * CFrame.new(0, 0.01, 0), 1 * s, 0.6 * s, pal.main, 0.15)
	table.insert(steps, ringStep(r1, 0, 0.6, 1 * s, 7 * s, 0.6 * s, 0.12 * s, 0.15))
	local r2 = newDisc(fx.root, root, base * CFrame.new(0, 0.02, 0), 1 * s, 0.25 * s, pal.hot, 0)
	r2.Visible = false
	table.insert(steps, ringStep(r2, 0.12, 0.45, 1 * s, 10 * s, 0.25 * s, 0.05 * s, 0))
	-- 2. scan ring: rises from the feet to above the head and widens (a rim around the body, no wash)
	local scan = newDisc(fx.root, root, base, 2 * s, 0.18 * s, pal.hot:Lerp(pal.main, 0.3), 0.1)
	table.insert(steps, function(t: number)
		local u = t / 0.55
		scan.Visible = u <= 1
		local y = lerp(feet + 0.1, head + 1.2, easeOut(u, 2))
		scan.CFrame = CFrame.new(0, y, 0) * FLAT
		setDisc(scan, lerp(2, 2.8, u) * s, 0.18 * s)
		scan.Transparency = lerp(0.1, 1, easeIn(u, 2))
	end)
	-- 3. light pillar above the head (visible from far away, leaves the character clear)
	local pillar = neonPart("Pillar", Enum.PartType.Cylinder, pal.main, CFrame.new(), fx.root)
	local pillarCore = neonPart("PillarCore", Enum.PartType.Cylinder, pal.hot, CFrame.new(), fx.root)
	table.insert(steps, function(t: number)
		local hp = root.Position + Vector3.new(0, head + 1, 0)
		local grow = easeOut(t / 0.25, 3)
		local thin = 1 - easeIn((t - 0.15) / 0.85, 1.4)
		local h = math.max(0.1, 15 * s * grow)
		pillar.CFrame = vertical(CFrame.new(hp + Vector3.new(0, h * 0.5, 0)))
		pillarCore.CFrame = pillar.CFrame
		pillar.Size = Vector3.new(h, math.max(0.05, 1.5 * s * thin), math.max(0.05, 1.5 * s * thin))
		pillarCore.Size = Vector3.new(h, math.max(0.05, 0.45 * s * thin), math.max(0.05, 0.45 * s * thin))
		pillar.Transparency = if thin <= 0 then 1 else lerp(0.45, 0.85, 1 - thin)
		pillarCore.Transparency = if thin <= 0 then 1 else lerp(0, 0.5, 1 - thin)
	end)
	-- 4. sparkles fountain up and fall; confetti flecks tumble (decoration); motes rise round the body
	local sparkles = newEmitter(headAtt, "flash_hot", {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(28, 28),
		Speed = NumberRange.new(22 * s, 36 * s),
		Acceleration = Vector3.new(0, -32, 0),
		Drag = 1.4,
		Lifetime = NumberRange.new(1.1, 1.6),
		Size = ns({ { 0, 0.5 * s }, { 0.5, 0.35 * s }, { 1, 0 } }),
		Transparency = ns({ { 0, 0 }, { 0.75, 0.1 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
		Color = cs({ { 0, pal.hot }, { 1, pal.spark } }),
		LightEmission = 1,
	}, true)
	local confetti = if fx.deco
		then newEmitter(headAtt, "spark_square", {
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(40, 40),
			Speed = NumberRange.new(18 * s, 28 * s),
			Acceleration = Vector3.new(0, -26, 0),
			Drag = 2,
			Lifetime = NumberRange.new(1.2, 1.7),
			Size = ns({ { 0, 0.22 * s }, { 1, 0.16 * s } }),
			Transparency = ns({ { 0, 0 }, { 0.85, 0 }, { 1, 1 } }),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-500, 500),
			Color = cs({ { 0, pal.main }, { 0.5, pal.spark }, { 1, pal.main:Lerp(pal.dark, 0.4) } }),
			LightEmission = 0.3,
		}, true)
		else nil
	local motes = newEmitter(feetAtt, "glow_soft", {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(55, 55),
		Speed = NumberRange.new(3 * s, 6 * s),
		Acceleration = Vector3.new(0, 2, 0),
		Drag = 1,
		Lifetime = NumberRange.new(0.9, 1.3),
		Size = ns({ { 0, 0 }, { 0.2, 0.3 * s }, { 1, 0 } }),
		Transparency = ns({ { 0, 0.1 }, { 1, 1 } }),
		Color = cs({ { 0, pal.main }, { 1, pal.hot } }),
		LightEmission = 1,
		LockedToPart = true,
	}, true)
	local fired = false
	local motePulses = 0
	table.insert(steps, function(t: number)
		if not fired and t >= 0.08 then
			fired = true
			burst(fx, sparkles, 30)
			burst(fx, confetti, 16)
		end
		while motePulses < 10 and t >= motePulses * 0.12 do
			motePulses += 1
			burst(fx, motes, 3)
		end
	end)
	-- 5. one light above the head
	if opts.light ~= false then
		local l = newLight(att("LvlLight", CFrame.new(0, head + 3, 0)), pal.glow, 0, 16 * s)
		table.insert(made, l)
		table.insert(steps, function(t: number)
			l.Brightness = 2.5 * easeOut(t / 0.08, 2) * (1 - easeOut((t - 0.1) / 0.8, 2))
		end)
	end

	fx.step = function(t: number, _dt: number): boolean?
		if not root.Parent then
			return true
		end
		for _, f in steps do
			f(t)
		end
		return nil
	end
	start(fx)
	return baseHandle(fx)
end

-------------------------------------------------------------------------------
-- Game feel: camera shake (local camera only)
-------------------------------------------------------------------------------
export type ShakeOptions = {
	position: Vector3?, -- world source: falls off with distance from the camera (smoothstep)
	near: number?, -- full strength inside this many studs (default 30)
	far: number?, -- nothing beyond this many studs (default 150)
	frequency: number?, -- Hz of the noise (default 16)
}

type Shake = { amp: number, t0: number, dur: number, freq: number, seed: number }
local shakes: { Shake } = {}
local SHAKE_BIND = "LihFolkAbilityShake"
local shakeBound = false
local MAX_PITCH = math.rad(1.6)
local MAX_YAW = math.rad(1.6)
local MAX_ROLL = math.rad(0.9)

local function shakeStep()
	local cam = Workspace.CurrentCamera
	local now = os.clock()
	local p: number = 0
	local y: number = 0
	local r: number = 0
	for i = #shakes, 1, -1 do
		local sh = shakes[i]
		local u = (now - sh.t0) / sh.dur
		if u >= 1 then
			table.remove(shakes, i)
		else
			-- trauma model: amplitude decays, felt shake = trauma squared
			local k = (sh.amp * (1 - u)) ^ 2
			local tt = (now - sh.t0) * sh.freq
			p += k * math.noise(sh.seed, tt, 0.5)
			y += k * math.noise(sh.seed + 17.3, tt, 0.5)
			r += k * math.noise(sh.seed + 41.7, tt, 0.5)
		end
	end
	if cam and #shakes > 0 then
		local pitch = math.clamp(p, -1, 1) * MAX_PITCH
		local yaw = math.clamp(y, -1, 1) * MAX_YAW
		local roll = math.clamp(r, -1, 1) * MAX_ROLL
		cam.CFrame = cam.CFrame * CFrame.Angles(pitch, yaw, roll)
	end
	if #shakes == 0 and shakeBound then
		shakeBound = false
		RunService:UnbindFromRenderStep(SHAKE_BIND)
	end
end

--[[ Shake the local camera. intensity 0..1 (0.12 medium hit, 0.35 finisher, 0.6 ultimate), duration in
	seconds (0.15-0.4). Applied after the camera scripts each frame, so it never accumulates.
	Config.reducedMotion turns it off; Config.shakeScale scales it. Only the local camera moves. ]]
function Abilities.CameraShake(intensity: number, duration: number, options: ShakeOptions?)
	local cfg = Abilities.Config
	if cfg.reducedMotion or intensity <= 0 or duration <= 0 then
		return
	end
	local opts: ShakeOptions = options or {}
	local amp = math.clamp(intensity, 0, 1) * math.clamp(cfg.shakeScale, 0, 1)
	local cam = Workspace.CurrentCamera
	if opts.position and cam then
		local near, far = opts.near or 30, opts.far or 150
		local d = (cam.CFrame.Position - opts.position).Magnitude
		local u = clamp01((d - near) / math.max(1, far - near))
		amp *= 1 - u * u * (3 - 2 * u)
	end
	if amp <= 0.01 then
		return
	end
	table.insert(shakes, { amp = amp, t0 = os.clock(), dur = duration, freq = opts.frequency or 16, seed = math.random() * 100 })
	if not shakeBound then
		shakeBound = true
		RunService:BindToRenderStep(SHAKE_BIND, Enum.RenderPriority.Camera.Value + 1, shakeStep)
	end
end

-------------------------------------------------------------------------------
-- Game feel: hit-stop (AnimationTrack freeze, then restore)
-------------------------------------------------------------------------------
export type HitStopOptions = {
	speed: number?, -- playback speed during the stop (default 0 = freeze)
	catchUp: boolean?, -- afterwards play faster for the same time so the clip ends on schedule (default false)
}

type Frozen = { speed: number, token: number }
local frozen: { [AnimationTrack]: Frozen } = setmetatable({}, { __mode = "k" }) :: any
local stopToken = 0

--[[ Freeze tracks for `duration` seconds (50-90 ms is the usual range; capped by Config.maxHitStop),
	then restore the speed each track had before the first overlapping stop. Accepts one track, a list,
	or an Animator (all playing tracks). Does nothing under Config.reducedMotion. ]]
function Abilities.HitStop(tracks: AnimationTrack | { AnimationTrack } | Animator, duration: number, options: HitStopOptions?)
	local cfg = Abilities.Config
	if cfg.reducedMotion or duration <= 0 then
		return
	end
	local opts: HitStopOptions = options or {}
	local d = math.min(duration, cfg.maxHitStop)
	local list: { AnimationTrack }
	if typeof(tracks) == "Instance" then
		if tracks:IsA("Animator") then
			list = tracks:GetPlayingAnimationTracks()
		elseif tracks:IsA("AnimationTrack") then
			list = { tracks }
		else
			return
		end
	else
		list = tracks :: { AnimationTrack }
	end
	stopToken += 1
	local token = stopToken
	local slow = math.max(0, opts.speed or 0)
	for _, tr in list do
		if tr.IsPlaying then
			local f = frozen[tr]
			if f then
				f.token = token -- overlapping stop: keep the original speed, extend the freeze
			else
				frozen[tr] = { speed = tr.Speed, token = token }
			end
			tr:AdjustSpeed(slow)
		end
	end
	task.delay(d, function()
		for _, tr in list do
			local f = frozen[tr]
			if f and f.token == token then
				frozen[tr] = nil
				if tr.IsPlaying then
					if opts.catchUp and f.speed > 0 then
						-- run fast for the same time to land the clip back on schedule
						tr:AdjustSpeed(f.speed * (2 - slow))
						task.delay(d, function()
							if tr.IsPlaying and frozen[tr] == nil then
								tr:AdjustSpeed(f.speed)
							end
						end)
					else
						tr:AdjustSpeed(f.speed)
					end
				end
			end
		end
	end)
end

-------------------------------------------------------------------------------
-- Replication: replay a compact server broadcast (presetId, cf, elementIndex, seed, aux)
-------------------------------------------------------------------------------
--[[ Clients call this from the RemoteEvent handler. The caster already played the effect locally
	(prediction) and skips its own echo. Returns the handle, or nil for a bad payload. ]]
function Abilities.playPayload(caster: Player?, presetId: number, cf: CFrame, elementIndex: number, seed: number, aux: Vector3?): Handle?
	if type(presetId) ~= "number" or typeof(cf) ~= "CFrame" then
		return nil
	end
	local name = Abilities.PresetIds[presetId]
	local element = Abilities.ElementIds[if type(elementIndex) == "number" then elementIndex else 1]
	if not name or not element then
		return nil
	end
	local base = Abilities.PayloadDefaults[name] or {}
	local opts: any = table.clone(base)
	opts.element = element
	opts.seed = if type(seed) == "number" then seed else nil
	local auxPos: Vector3? = if typeof(aux) == "Vector3" then aux else nil
	local character = caster and caster.Character
	if name == "Projectile" then
		opts.ignore = if character then { character } else nil
		return Abilities.Projectile(cf, auxPos, opts)
	elseif name == "TelegraphCircle" then
		return Abilities.Telegraph(cf, "circle", opts)
	elseif name == "TelegraphCone" then
		return Abilities.Telegraph(cf, "cone", opts)
	elseif name == "TelegraphLine" then
		return Abilities.Telegraph(cf, "line", opts)
	elseif name == "Teleport" then
		local dest = auxPos or cf.Position
		return Abilities.Teleport(cf, CFrame.new(dest) * cf.Rotation, opts)
	elseif character then
		if name == "Heal" then
			return Abilities.Heal(character, opts)
		elseif name == "Buff" then
			return Abilities.Buff(character, opts)
		elseif name == "LevelUp" then
			return Abilities.LevelUp(character, opts)
		end
	end
	return nil
end

function Abilities.presetIndex(name: string): number?
	return table.find(Abilities.PresetIds, name)
end

function Abilities.elementIndex(name: string): number?
	return table.find(Abilities.ElementIds, name)
end

-------------------------------------------------------------------------------
-- Housekeeping
-------------------------------------------------------------------------------
function Abilities.setQuality(q: number)
	Abilities.Config.quality = math.clamp(q, 0.25, 1)
end

function Abilities.liveParticles(): number
	return live
end

function Abilities.preload()
	local ids: { string } = {}
	for key in Abilities.Textures :: any do
		local id = texId(key)
		if id then
			table.insert(ids, id)
		end
	end
	if #ids > 0 then
		task.spawn(function()
			local ok, err = pcall(function()
				ContentProvider:PreloadAsync(ids)
			end)
			if not ok then
				warn("[LihFolkVFX_Abilities] preload failed: " .. tostring(err))
			end
		end)
	end
end

-- Stop and remove every live effect (scene change, death, teleport)
function Abilities.clear()
	for _, fx in active do
		finish(fx)
	end
	table.clear(active)
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	table.clear(shakes)
end

return Abilities
