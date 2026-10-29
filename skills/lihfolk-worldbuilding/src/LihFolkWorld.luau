--!strict
-- LihFolkWorld: a small Studio-side placement and audit toolkit for building worlds.
-- Use it from the command bar or Studio MCP execute_luau (edit time). It never runs in a live game loop.
--
--   local W = require(path.to.LihFolkWorld)
--   W.placeOnGround(model, x, z, { yaw = 30, alignToNormal = true })   -- grounded on terrain or ground parts
--   W.isAreaClear(cframe, size, { model })                            -- true, {} when nothing is in the box
--   W.scatter(regionPart, { templates = {...}, spacing = 8, seed = 7 }) -- Poisson-disk dressing
--   W.faceToward(model, targetPosition)                               -- yaw a model's front (-Z) at a target
--   W.budgetReport(workspace.Map, "mobile")                           -- counts against the budgets.md numbers
--   W.auditWorld(workspace.Map)                                       -- floating / buried / overlap / pivot list
--
-- Conventions (CollectionService tags and attributes, all optional):
--   tag  LF_Ground       parts that count as walkable ground (Terrain always counts)
--   tag  LF_NoScatter    parts whose box is a keep-out zone for scatter (paths, plazas, gameplay spaces)
--   attr LF_AllowFloat   true on hanging or flying things (lanterns on hooks, birds, banners)
--   attr LF_AllowBury    true on things meant to sink deep (boulders, ruins)
--   attr LF_AllowOverlap true on deliberate intersections (rock clusters, roots through walls)
--   attr LF_Collide      true on small parts that need collision for gameplay
-- Models face -Z (LookVector) unless `frontYaw` says otherwise.

local CollectionService = game:GetService("CollectionService")

local LihFolkWorld = {}

export type Bounds = { cframe: CFrame, size: Vector3, minY: number, maxY: number, center: Vector3 }

export type PlaceOptions = {
	yaw: number?, -- degrees around world Y
	alignToNormal: boolean?, -- tilt to the ground normal (natural props only; never buildings)
	maxTilt: number?, -- degrees, cap on alignToNormal tilt (default 20)
	maxSlope: number?, -- degrees, refuse placement on steeper ground (default 60)
	sink: number?, -- studs pushed into the ground (default 0; grass and rocks 0.1-0.3)
	ignore: { Instance }?, -- extra instances the ground ray ignores
	rayTop: number?, -- ray start height (default 1000)
	rayLength: number?, -- default 2000
}

export type PlaceResult = {
	position: Vector3,
	normal: Vector3,
	slope: number,
	instance: Instance,
	material: Enum.Material,
}

export type ScatterOptions = {
	templates: { PVInstance }, -- models or parts to clone (originals stay where they are)
	spacing: number, -- minimum distance between placements in studs
	seed: number?, -- default 1; always seed so a pass is reproducible
	maxCount: number?, -- default 500
	attempts: number?, -- Bridson candidates per active point (default 30)
	scaleMin: number?, -- default 0.85
	scaleMax: number?, -- default 1.25
	scaleCurve: number?, -- exponent on the random number; 3 gives a long tail of rare big ones (default 2)
	yawRange: number?, -- degrees either side of 0 (default 180 = any yaw)
	alignToNormal: boolean?,
	maxTilt: number?,
	maxSlope: number?, -- default 30
	sink: number?,
	clusters: number?, -- number of clump centres; 0 = even spread (default 0)
	clusterRadius: number?, -- default 4 x spacing
	clusterFloor: number?, -- acceptance far from clumps, 0..1 (default 0.1)
	excludeTag: string?, -- default "LF_NoScatter"
	excludeMargin: number?, -- studs added around keep-out parts (default 2)
	materials: { Enum.Material }?, -- only place on these ground materials
	footprint: number?, -- clear-box size checked at each point (default spacing * 0.5)
	parent: Instance?, -- default: a Folder "Scatter_<seed>" under the region's parent
}

export type Issue = { kind: string, instance: Instance, detail: string }

local DEFAULT_TOL = 0.25

-- ---------------------------------------------------------------- helpers

local function rad(deg: number): number
	return math.rad(deg)
end

local function boundsOf(inst: PVInstance): Bounds
	local cf: CFrame, size: Vector3
	if inst:IsA("Model") then
		cf, size = (inst :: Model):GetBoundingBox()
	elseif inst:IsA("BasePart") then
		cf, size = (inst :: BasePart).CFrame, (inst :: BasePart).Size
	else
		cf, size = inst:GetPivot(), Vector3.zero
	end
	-- world-space AABB of the oriented box, from its 8 corners
	local h = size / 2
	local minY, maxY = math.huge, -math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
				minY = math.min(minY, p.Y)
				maxY = math.max(maxY, p.Y)
			end
		end
	end
	return { cframe = cf, size = size, minY = minY, maxY = maxY, center = cf.Position }
end
LihFolkWorld.boundsOf = boundsOf

local function isGround(inst: Instance): boolean
	return inst:IsA("Terrain") or CollectionService:HasTag(inst, "LF_Ground")
end

local function groundList(): { Instance }
	local list: { Instance } = { workspace.Terrain }
	for _, p in CollectionService:GetTagged("LF_Ground") do
		table.insert(list, p)
	end
	return list
end

local function castDown(origin: Vector3, length: number, params: RaycastParams): RaycastResult?
	return workspace:Raycast(origin, Vector3.new(0, -length, 0), params)
end

local function excludeParams(list: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = list
	params.IgnoreWater = false
	return params
end

-- Tilt that turns world up into `normal`, capped at maxTilt degrees.
local function tiltTo(normal: Vector3, maxTilt: number): CFrame
	local up = Vector3.yAxis
	local angle = math.acos(math.clamp(up:Dot(normal), -1, 1))
	if angle < 1e-4 then
		return CFrame.identity
	end
	local axis = up:Cross(normal).Unit
	return CFrame.fromAxisAngle(axis, math.min(angle, rad(maxTilt)))
end

-- The top-level unit (prop) a part belongs to under `root`: the highest Model whose parent is not a Model.
local function unitOf(part: Instance, root: Instance): Instance
	local unit: Instance = part
	local node: Instance? = part.Parent
	while node and node ~= root do
		if node:IsA("Model") then
			unit = node
		end
		node = node.Parent
	end
	return unit
end

local function units(root: Instance): { PVInstance }
	local seen: { [Instance]: boolean } = {}
	local out: { PVInstance } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and not d:IsA("Terrain") then
			local u = unitOf(d, root)
			if not seen[u] and u:IsA("PVInstance") then
				seen[u] = true
				table.insert(out, u :: PVInstance)
			end
		end
	end
	return out
end

local function attr(inst: Instance, name: string): boolean
	return inst:GetAttribute(name) == true
end

-- ---------------------------------------------------------------- placeOnGround

-- Puts the footprint centre of `inst` at (x, z) on the ground below, bottom of its bounding box on the
-- surface. Without alignToNormal it samples the centre and four footprint corners and rests on the
-- lowest hit, so no corner hangs in the air and on a slope the uphill side tucks in (put buildings on
-- flat pads). Returns the centre hit, or nil and a reason (the instance is left where it was).
function LihFolkWorld.placeOnGround(inst: PVInstance, x: number, z: number, opts: PlaceOptions?): (PlaceResult?, string?)
	local o: PlaceOptions = opts or {}
	local yaw = CFrame.Angles(0, rad(o.yaw or 0), 0)
	local rayTop = o.rayTop or 1000
	local rayLength = o.rayLength or 2000

	-- orient first, then measure where the bottom-centre sits relative to the pivot
	local start = inst:GetPivot()
	inst:PivotTo(CFrame.new(start.Position) * yaw)
	local b = boundsOf(inst)
	local pivot = inst:GetPivot()
	local bottomWorld = Vector3.new(b.center.X, b.minY, b.center.Z)
	local localBottom = pivot:PointToObjectSpace(bottomWorld)

	local ignore: { Instance } = { inst }
	for _, i in o.ignore or {} do
		table.insert(ignore, i)
	end
	local params = excludeParams(ignore)

	local centreHit = castDown(Vector3.new(x, rayTop, z), rayLength, params)
	if not centreHit then
		inst:PivotTo(start)
		return nil, "no ground under point"
	end
	local slope = math.deg(math.acos(math.clamp(centreHit.Normal.Y, -1, 1)))
	if slope > (o.maxSlope or 60) then
		inst:PivotTo(start)
		return nil, string.format("slope %.0f deg", slope)
	end

	local targetY = centreHit.Position.Y
	local rot = yaw
	if o.alignToNormal then
		rot = tiltTo(centreHit.Normal, o.maxTilt or 20) * yaw
	else
		-- footprint corners (90% inset): rest on the lowest so no corner hangs in the air
		local hx, hz = b.size.X * 0.45, b.size.Z * 0.45
		for _, c in { Vector3.new(hx, 0, hz), Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, -hz), Vector3.new(-hx, 0, -hz) } do
			local w = yaw:VectorToWorldSpace(c)
			local hit = castDown(Vector3.new(x + w.X, rayTop, z + w.Z), rayLength, params)
			if hit then
				targetY = math.min(targetY, hit.Position.Y)
			end
		end
	end

	local target = Vector3.new(x, targetY - (o.sink or 0), z)
	inst:PivotTo(CFrame.new(target) * rot * CFrame.new(-localBottom))
	return {
		position = centreHit.Position,
		normal = centreHit.Normal,
		slope = slope,
		instance = centreHit.Instance,
		material = centreHit.Material,
	}, nil
end

-- ---------------------------------------------------------------- isAreaClear

-- True when no prop part overlaps the box. Terrain and LF_Ground parts do not count as blockers.
function LihFolkWorld.isAreaClear(cf: CFrame, size: Vector3, ignore: { Instance }?): (boolean, { BasePart })
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local blockers: { BasePart } = {}
	for _, p in workspace:GetPartBoundsInBox(cf, size, params) do
		if not isGround(p) then
			table.insert(blockers, p)
		end
	end
	return #blockers == 0, blockers
end

-- ---------------------------------------------------------------- faceToward

-- Yaws a model so its front (-Z, or -Z rotated by frontYaw degrees) points at a target. Keeps position.
function LihFolkWorld.faceToward(inst: PVInstance, target: Vector3 | PVInstance, frontYaw: number?)
	local pivot = inst:GetPivot()
	local goal: Vector3 = if typeof(target) == "Vector3" then target else (target :: PVInstance):GetPivot().Position
	local flat = Vector3.new(goal.X - pivot.X, 0, goal.Z - pivot.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local look = CFrame.lookAt(pivot.Position, pivot.Position + flat)
	inst:PivotTo(look * CFrame.Angles(0, rad(frontYaw or 0), 0))
end

-- ---------------------------------------------------------------- scatter (Poisson disk, Bridson)

local function inKeepOut(p: Vector3, keepOuts: { BasePart }, margin: number): boolean
	for _, k in keepOuts do
		local lp = k.CFrame:PointToObjectSpace(p)
		local h = k.Size / 2
		if math.abs(lp.X) <= h.X + margin and math.abs(lp.Z) <= h.Z + margin then
			return true
		end
	end
	return false
end

-- Dresses the top face of `region` (a flat BasePart used as a guide; keep it CanCollide/CanQuery off and
-- Transparency 1) with clones of the templates. Even spread or clumps, keep-outs respected, every
-- point grounded with placeOnGround and checked clear. Returns the placed instances.
function LihFolkWorld.scatter(region: BasePart, opts: ScatterOptions): { PVInstance }
	assert(#opts.templates > 0, "scatter: templates is empty")
	assert(opts.spacing > 0, "scatter: spacing must be > 0")
	local rng = Random.new(opts.seed or 1)
	local r = opts.spacing
	local cell = r / math.sqrt(2)
	local w, d = region.Size.X, region.Size.Z
	local cols, rows = math.max(1, math.ceil(w / cell)), math.max(1, math.ceil(d / cell))
	local grid: { [number]: Vector2 } = {}
	local samples: { Vector2 } = {}
	local active: { Vector2 } = {}
	local maxCount = opts.maxCount or 500
	local attempts = opts.attempts or 30

	local clusterCentres: { Vector2 } = {}
	for _ = 1, opts.clusters or 0 do
		table.insert(clusterCentres, Vector2.new(rng:NextNumber(0, w), rng:NextNumber(0, d)))
	end
	local clusterRadius = opts.clusterRadius or r * 4
	local floor = opts.clusterFloor or 0.1

	local function density(p: Vector2): number
		if #clusterCentres == 0 then
			return 1
		end
		local best = 0
		for _, c in clusterCentres do
			local t = (p - c).Magnitude / clusterRadius
			best = math.max(best, math.exp(-t * t))
		end
		return floor + (1 - floor) * best
	end

	local function fits(p: Vector2): boolean
		if p.X < 0 or p.Y < 0 or p.X >= w or p.Y >= d then
			return false
		end
		local gx, gy = math.floor(p.X / cell), math.floor(p.Y / cell)
		for i = math.max(0, gx - 2), math.min(cols - 1, gx + 2) do
			for j = math.max(0, gy - 2), math.min(rows - 1, gy + 2) do
				local q = grid[j * cols + i]
				if q and (q - p).Magnitude < r then
					return false
				end
			end
		end
		return true
	end

	local function add(p: Vector2)
		grid[math.floor(p.Y / cell) * cols + math.floor(p.X / cell)] = p
		table.insert(samples, p)
		table.insert(active, p)
	end

	add(Vector2.new(rng:NextNumber(0, w), rng:NextNumber(0, d)))
	while #active > 0 and #samples < maxCount * 3 do
		local idx = rng:NextInteger(1, #active)
		local base = active[idx]
		local found = false
		for _ = 1, attempts do
			local a = rng:NextNumber(0, 2 * math.pi)
			local dist = rng:NextNumber(r, 2 * r)
			local p = base + Vector2.new(math.cos(a), math.sin(a)) * dist
			if fits(p) then
				add(p)
				found = true
				break
			end
		end
		if not found then
			active[idx] = active[#active]
			active[#active] = nil
		end
	end

	-- keep-outs and target folder
	local keepOuts: { BasePart } = {}
	for _, k in CollectionService:GetTagged(opts.excludeTag or "LF_NoScatter") do
		if k:IsA("BasePart") then
			table.insert(keepOuts, k)
		end
	end
	local margin = opts.excludeMargin or 2
	local parent: Instance = opts.parent or (function(): Instance
		local f = Instance.new("Folder")
		f.Name = "Scatter_" .. tostring(opts.seed or 1)
		f.Parent = region.Parent
		return f
	end)()

	local allowed: { [Enum.Material]: boolean }? = nil
	if opts.materials then
		local set: { [Enum.Material]: boolean } = {}
		for _, m in opts.materials do
			set[m] = true
		end
		allowed = set
	end

	local placed: { PVInstance } = {}
	local footprint = opts.footprint or r * 0.5
	local scaleMin, scaleMax = opts.scaleMin or 0.85, opts.scaleMax or 1.25
	local curve = opts.scaleCurve or 2
	local yawRange = opts.yawRange or 180
	local top = region.CFrame * CFrame.new(-w / 2, region.Size.Y / 2, -d / 2)

	for _, s in samples do
		if #placed >= maxCount then
			break
		end
		if rng:NextNumber() <= density(s) then
			local world = top:PointToWorldSpace(Vector3.new(s.X, 0, s.Y))
			if not inKeepOut(world, keepOuts, margin) then
				local template = opts.templates[rng:NextInteger(1, #opts.templates)]
				local clone = template:Clone()
				local scale = scaleMin + (scaleMax - scaleMin) * rng:NextNumber() ^ curve
				if clone:IsA("Model") then
					local m = clone :: Model
					m:ScaleTo(m:GetScale() * scale)
				elseif clone:IsA("BasePart") then
					local bp = clone :: BasePart
					bp.Size *= scale
				end
				clone.Parent = parent
				local hit = LihFolkWorld.placeOnGround(clone, world.X, world.Z, {
					yaw = rng:NextNumber(-yawRange, yawRange),
					alignToNormal = opts.alignToNormal,
					maxTilt = opts.maxTilt,
					maxSlope = opts.maxSlope or 30,
					sink = opts.sink,
					ignore = { region, parent },
				})
				local ok = hit ~= nil and (allowed == nil or (allowed :: { [Enum.Material]: boolean })[hit.material] == true)
				if ok then
					local b = boundsOf(clone)
					local box = Vector3.new(footprint, math.max(1, b.size.Y * 0.5), footprint)
					local clear = LihFolkWorld.isAreaClear(CFrame.new(b.center), box, { clone, region, parent })
					ok = clear
				end
				if ok then
					table.insert(placed, clone)
				else
					clone:Destroy()
				end
			end
		end
	end
	return placed
end

-- ---------------------------------------------------------------- budgetReport

export type Budget = {
	instances: number,
	parts: number,
	meshParts: number,
	uniqueMeshes: number,
	unions: number,
	estPrimitiveTris: number, -- triangles of plain parts only; read MeshPart triangles in the Studio stats or the asset catalogue
	lights: number,
	shadowLights: number,
	emitters: number,
	beams: number,
	decalsTextures: number,
	unanchored: number,
	collidingDecor: number,
	smallShadowCasters: number,
	preciseFidelity: number,
	warnings: { string },
}

-- Budgets per zone (references/budgets.md): rule-of-thumb starting points, measure on a real phone.
local TARGETS = {
	mobile = { instances = 10000, lights = 12, shadowLights = 3, emitters = 40 },
	pc = { instances = 20000, lights = 24, shadowLights = 8, emitters = 80 },
}

-- Rough render-triangle estimates for primitive shapes (orders of magnitude, not measured values).
local PRIMITIVE_TRIS: { [string]: number } = { Block = 12, Wedge = 8, CornerWedge = 6, Cylinder = 96, Ball = 360 }

function LihFolkWorld.budgetReport(root: Instance, target: ("mobile" | "pc")?): Budget
	local t = TARGETS[target or "mobile"]
	local r: Budget = {
		instances = 0, parts = 0, meshParts = 0, uniqueMeshes = 0, unions = 0, estPrimitiveTris = 0,
		lights = 0, shadowLights = 0, emitters = 0, beams = 0, decalsTextures = 0, unanchored = 0,
		collidingDecor = 0, smallShadowCasters = 0, preciseFidelity = 0, warnings = {},
	}
	local meshIds: { [string]: boolean } = {}
	for _, d in root:GetDescendants() do
		r.instances += 1
		if d:IsA("BasePart") then
			local p = d :: BasePart
			r.parts += 1
			local maxAxis = math.max(p.Size.X, p.Size.Y, p.Size.Z)
			if not p.Anchored then
				r.unanchored += 1
			end
			if p.CanCollide and maxAxis < 3 and not attr(p, "LF_Collide") then
				r.collidingDecor += 1
			end
			if p.CastShadow and maxAxis < 2 then
				r.smallShadowCasters += 1
			end
			if p:IsA("MeshPart") then
				local mp = p :: MeshPart
				r.meshParts += 1
				if not meshIds[mp.MeshId] then
					meshIds[mp.MeshId] = true
					r.uniqueMeshes += 1
				end
				if mp.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition then
					r.preciseFidelity += 1
				end
			elseif p:IsA("UnionOperation") then
				r.unions += 1
			elseif p:IsA("Part") then
				r.estPrimitiveTris += PRIMITIVE_TRIS[(p :: Part).Shape.Name] or 12
			elseif p:IsA("WedgePart") then
				r.estPrimitiveTris += 8
			elseif p:IsA("CornerWedgePart") then
				r.estPrimitiveTris += 6
			end
		elseif d:IsA("Light") then
			r.lights += 1
			if (d :: Light).Shadows then
				r.shadowLights += 1
			end
		elseif d:IsA("ParticleEmitter") then
			r.emitters += 1
		elseif d:IsA("Beam") then
			r.beams += 1
		elseif d:IsA("Decal") then -- Texture is a subclass of Decal
			r.decalsTextures += 1
		end
	end
	local w = r.warnings
	if r.instances > t.instances then
		table.insert(w, string.format("instances %d > %d: merge, instance meshes, stream or split the zone", r.instances, t.instances))
	end
	if r.lights > t.lights then
		table.insert(w, string.format("lights %d > %d: bake glow into Neon/colour, keep real lights at focal points", r.lights, t.lights))
	end
	if r.shadowLights > t.shadowLights then
		table.insert(w, string.format("shadowed lights %d > %d: set Shadows = false on fill lights", r.shadowLights, t.shadowLights))
	end
	if r.emitters > t.emitters then
		table.insert(w, string.format("emitters %d > %d: keep ambience emitters near focal points", r.emitters, t.emitters))
	end
	if r.unanchored > 0 then
		table.insert(w, string.format("%d unanchored parts: anchor static scenery", r.unanchored))
	end
	if r.collidingDecor > 0 then
		table.insert(w, string.format("%d small parts collide: CanCollide/CanTouch/CanQuery off on decor (attr LF_Collide to keep)", r.collidingDecor))
	end
	if r.smallShadowCasters > 0 then
		table.insert(w, string.format("%d parts under 2 studs cast shadows: CastShadow = false", r.smallShadowCasters))
	end
	if r.preciseFidelity > 0 then
		table.insert(w, string.format("%d MeshParts use PreciseConvexDecomposition: Box or Hull unless players stand on them", r.preciseFidelity))
	end
	if r.meshParts > 0 and r.uniqueMeshes > r.meshParts * 0.5 then
		table.insert(w, string.format("%d unique meshes for %d MeshParts: reuse 3-5 base meshes per prop type", r.uniqueMeshes, r.meshParts))
	end
	print(string.format(
		"[LihFolkWorld] %s | inst %d, parts %d (mesh %d, unique %d, unions %d), ~%d primitive tris, lights %d (%d shadowed), emitters %d, beams %d, decals %d",
		root:GetFullName(), r.instances, r.parts, r.meshParts, r.uniqueMeshes, r.unions, r.estPrimitiveTris,
		r.lights, r.shadowLights, r.emitters, r.beams, r.decalsTextures
	))
	for _, line in w do
		print("  - " .. line)
	end
	return r
end

-- ---------------------------------------------------------------- auditWorld

export type AuditOptions = {
	floatTol: number?, -- studs of air under a prop before it counts as floating (default 0.25)
	buryMax: number?, -- fraction of height below ground before it counts as buried (default 0.35)
	overlapTol: number?, -- studs of interpenetration allowed (default 0.25)
	maxUnits: number?, -- cap on props checked (default 3000)
	pivotCheck: boolean?, -- report pivots far from the footprint (default true)
}

-- Lists floating, buried, overlapping and badly pivoted props under `root`. Each top-level Model (or a
-- loose part) is one prop. Hanging/flying, sunken and deliberately intersecting props opt out with the
-- LF_AllowFloat, LF_AllowBury and LF_AllowOverlap attributes. Bounds-based: confirm hits by eye.
function LihFolkWorld.auditWorld(root: Instance, opts: AuditOptions?): { Issue }
	local o: AuditOptions = opts or {}
	local floatTol = o.floatTol or DEFAULT_TOL
	local buryMax = o.buryMax or 0.35
	local overlapTol = o.overlapTol or DEFAULT_TOL
	local issues: { Issue } = {}
	local list = units(root)
	local checked = 0

	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	groundParams.FilterDescendantsInstances = groundList()

	local pairSeen: { [string]: boolean } = {}

	for _, u in list do
		checked += 1
		if checked > (o.maxUnits or 3000) then
			table.insert(issues, { kind = "info", instance = root, detail = "unit cap reached; audit a smaller folder" })
			break
		end
		if isGround(u) then
			continue
		end
		local b = boundsOf(u)
		local height = math.max(b.maxY - b.minY, 0.01)
		local selfParams = excludeParams({ u })

		-- floating: air under the centre and four inset corners, and not touching anything else
		if not attr(u, "LF_AllowFloat") then
			local minGap = math.huge
			local hx, hz = b.size.X * 0.4, b.size.Z * 0.4
			for _, c in { Vector3.zero, Vector3.new(hx, 0, hz), Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, -hz), Vector3.new(-hx, 0, -hz) } do
				local w = b.cframe:VectorToWorldSpace(c)
				local origin = Vector3.new(b.center.X + w.X, b.minY + 0.05, b.center.Z + w.Z)
				local hit = castDown(origin, 500, selfParams)
				local gap = if hit then origin.Y - hit.Position.Y - 0.05 else math.huge
				minGap = math.min(minGap, gap)
			end
			if minGap > floatTol then
				local touching = not LihFolkWorld.isAreaClear(b.cframe, b.size + Vector3.one * (floatTol * 2), { u })
				if not touching then
					local detail = if minGap == math.huge then "nothing below" else string.format("%.2f studs above support", minGap)
					table.insert(issues, { kind = "floating", instance = u, detail = detail })
				end
			end
		end

		-- buried: too much of the height under the ground surface at the centre
		if not attr(u, "LF_AllowBury") then
			local hit = castDown(Vector3.new(b.center.X, b.maxY + 200, b.center.Z), b.maxY - b.minY + 400, groundParams)
			if hit then
				local frac = (hit.Position.Y - b.minY) / height
				if frac > buryMax then
					table.insert(issues, { kind = "buried", instance = u, detail = string.format("%.0f%% below ground", frac * 100) })
				end
			end
		end

		-- overlaps with other props beyond the tolerance (shrunken part boxes)
		if not attr(u, "LF_AllowOverlap") then
			local parts: { BasePart } = {}
			if u:IsA("BasePart") then
				table.insert(parts, u :: BasePart)
			end
			for _, d in u:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(parts, d)
				end
			end
			for _, p in parts do
				local shrunk = p.Size - Vector3.one * (overlapTol * 2)
				if shrunk.X > 0 and shrunk.Y > 0 and shrunk.Z > 0 and p.Transparency < 1 then
					local _, blockers = LihFolkWorld.isAreaClear(p.CFrame, shrunk, { u })
					for _, other in blockers do
						if other.Transparency < 1 and other:IsDescendantOf(root) then
							local ou = unitOf(other, root)
							if not attr(ou, "LF_AllowOverlap") then
								local a, c = u:GetFullName(), ou:GetFullName()
								local key = if a < c then a .. "|" .. c else c .. "|" .. a
								if not pairSeen[key] then
									pairSeen[key] = true
									table.insert(issues, { kind = "overlap", instance = u, detail = "intersects " .. c })
								end
							end
						end
					end
				end
			end
		end

		-- pivots: a model's pivot should sit at its bottom centre so placement and scaling behave
		if o.pivotCheck ~= false and u:IsA("Model") then
			local pivot = u:GetPivot().Position
			local off = Vector3.new(pivot.X - b.center.X, 0, pivot.Z - b.center.Z).Magnitude
			local footprint = math.max(b.size.X, b.size.Z, 0.01)
			if off > footprint * 0.25 or math.abs(pivot.Y - b.minY) > height * 0.25 then
				table.insert(issues, { kind = "pivot", instance = u, detail = "pivot away from bottom centre" })
			end
		end
	end

	local counts: { [string]: number } = {}
	for _, i in issues do
		counts[i.kind] = (counts[i.kind] or 0) + 1
	end
	print(string.format(
		"[LihFolkWorld] audit %s: %d props | floating %d, buried %d, overlap %d, pivot %d",
		root:GetFullName(), #list, counts.floating or 0, counts.buried or 0, counts.overlap or 0, counts.pivot or 0
	))
	for n, i in issues do
		if n > 40 then
			print(string.format("  ... %d more (see the returned table)", #issues - 40))
			break
		end
		print(string.format("  %-8s %s: %s", i.kind, i.instance:GetFullName(), i.detail))
	end
	return issues
end

return LihFolkWorld
