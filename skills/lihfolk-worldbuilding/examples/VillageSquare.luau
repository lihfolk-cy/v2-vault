--!strict
-- Example: block out and dress a small village square with LihFolkWorld (edit time, command bar or
-- Studio MCP execute_luau). Run pass 1, look and walk it, then run pass 2 (it consumes the guide blocks;
-- re-run pass 1 to lay out again).
--
-- Setup: LihFolkWorld.luau as a ModuleScript in ServerStorage. Kit models from the LihFolk Asset Pack
-- (lihfolk-assets skill) or roblox-blender-modeling houses in ServerStorage.WorldKit, each with its pivot
-- at the bottom centre and its front facing -Z: House_A, House_B, Well, Lantern, Crate, Barrel,
-- Flowers_A, Flowers_B, Rock_A. Pass 1 needs none of them.
--
-- Layout (R15 ~5 studs tall, walk 16 studs/s):
--   plaza radius 40 (feels busy with ~5 players), well = hero landmark in the centre, spawn 60 studs
--   south facing the well, main road 20 wide running north, side lane 12 wide to the east,
--   4 houses on a 62-stud ring facing the centre, door clearance 8 studs kept free.

local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local W = require(ServerStorage:WaitForChild("LihFolkWorld")) :: any

local ORIGIN = Vector3.new(0, 0, 0)
local PASS = 1 -- set to 2 after the blockout reads well

local function folder(name: string, parent: Instance): Folder
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function block(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local root = workspace:FindFirstChild("VillageSquare") or (function(): Instance
	local m = Instance.new("Folder")
	m.Name = "VillageSquare"
	m.Parent = workspace
	return m
end)()

-- ---------------------------------------------------------------- pass 1: layout and blockout
if PASS == 1 then
	local layout = folder("01_Layout", root)
	-- ground and walkable surfaces: paths lighter and smoother than the play space, edges darker
	local ground = block("Ground", Vector3.new(240, 2, 240), CFrame.new(ORIGIN - Vector3.new(0, 1, 0)), Color3.fromRGB(104, 140, 78), layout, Enum.Material.Grass)
	local plaza = block("Plaza", Vector3.new(80, 0.4, 80), CFrame.new(ORIGIN + Vector3.new(0, 0.2, 0)), Color3.fromRGB(178, 164, 140), layout, Enum.Material.Cobblestone)
	local road = block("MainRoad", Vector3.new(20, 0.3, 80), CFrame.new(ORIGIN + Vector3.new(0, 0.15, -80)), Color3.fromRGB(160, 132, 100), layout, Enum.Material.Ground)
	local lane = block("SideLane", Vector3.new(80, 0.3, 12), CFrame.new(ORIGIN + Vector3.new(80, 0.15, 0)), Color3.fromRGB(160, 132, 100), layout, Enum.Material.Ground)
	for _, p in { ground, plaza, road, lane } do
		CollectionService:AddTag(p, "LF_Ground")
	end
	for _, p in { plaza, road, lane } do
		CollectionService:AddTag(p, "LF_NoScatter") -- scatter keeps off walkable routes
	end

	-- hero landmark stand-in: tallest thing in the square (>= 1.5x anything else), on the main axis
	block("Hero_Well", Vector3.new(10, 22, 10), CFrame.new(ORIGIN + Vector3.new(0, 11, 0)), Color3.fromRGB(230, 230, 230), layout)
	-- house footprints on a ring, doors facing the well; door clearance boxes are keep-outs too
	for i, angle in { 45, 135, 225, 315 } do
		local a = math.rad(angle)
		local pos = ORIGIN + Vector3.new(math.sin(a) * 62, 7, math.cos(a) * 62)
		local house = block("House_" .. i, Vector3.new(20, 14, 16), CFrame.lookAt(pos, Vector3.new(ORIGIN.X, pos.Y, ORIGIN.Z)), Color3.fromRGB(150, 150, 150), layout)
		local door = block("DoorClear_" .. i, Vector3.new(8, 0.2, 8), house.CFrame * CFrame.new(0, -7, -12), Color3.fromRGB(255, 200, 80), layout)
		door.Transparency = 0.6
		door.CanCollide = false
		door.CanQuery = false
		CollectionService:AddTag(door, "LF_NoScatter")
	end
	-- spawn faces the hero landmark
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.lookAt(ORIGIN + Vector3.new(0, 0.5, 60), ORIGIN + Vector3.new(0, 0.5, 0))
	spawn.Parent = layout
	print("Pass 1 done: screen_capture from the spawn and walk spawn -> well -> road end before pass 2.")
end

-- ---------------------------------------------------------------- pass 2: swap in the kit and dress
if PASS == 2 then
	local kit = ServerStorage:WaitForChild("WorldKit")
	local layout = root:WaitForChild("01_Layout")
	local primary = folder("02_Primary", root)
	local medium = folder("03_Medium", root)
	-- read the blockout guides, then remove them so rays and audits see only the real kit
	local guides: { [string]: CFrame } = {}
	for _, name in { "Hero_Well", "House_1", "House_2", "House_3", "House_4" } do
		local g = layout:WaitForChild(name) :: BasePart
		guides[name] = g.CFrame
		g:Destroy()
	end

	-- primary forms: the hero well, then houses facing it
	local well = kit:WaitForChild("Well"):Clone() :: Model
	well.Parent = primary
	W.placeOnGround(well, ORIGIN.X, ORIGIN.Z, { yaw = 0 })
	for i = 1, 4 do
		local at = guides["House_" .. i].Position
		local house = kit:WaitForChild(if i % 2 == 0 then "House_B" else "House_A"):Clone() :: Model
		house.Parent = primary
		W.placeOnGround(house, at.X, at.Z, {})
		W.faceToward(house, well) -- door side (-Z) toward the hero
	end

	-- medium props: grouped by story, not sprinkled. A market corner by house 1, lanterns guiding the road.
	local h1 = guides.House_1
	for n, name in { "Crate", "Crate", "Barrel" } do
		local prop = kit:WaitForChild(name):Clone() :: Model
		prop.Parent = medium
		local side = h1 * CFrame.new(12 + n * 2.5, 0, -4 - (n % 2) * 2)
		W.placeOnGround(prop, side.X, side.Z, { yaw = n * 23 })
	end
	for k = 0, 3 do -- lanterns every 20 studs along both road edges: leading lines to the square
		for _, x in { -12, 12 } do
			local lantern = kit:WaitForChild("Lantern"):Clone() :: Model
			lantern.Parent = medium
			W.placeOnGround(lantern, ORIGIN.X + x, ORIGIN.Z - 50 - k * 20, { yaw = 0 })
		end
	end

	-- small detail: flowers in clumps and a few rocks, off paths and door clearances
	local region = block("ScatterRegion", Vector3.new(200, 1, 200), CFrame.new(ORIGIN), Color3.new(1, 1, 1), root)
	region.Transparency = 1
	region.CanCollide = false
	region.CanQuery = false
	local detail = folder("04_Detail", root)
	W.scatter(region, {
		templates = { kit:WaitForChild("Flowers_A") :: Model, kit:WaitForChild("Flowers_B") :: Model },
		spacing = 6, seed = 11, clusters = 7, clusterRadius = 14, clusterFloor = 0.02,
		alignToNormal = true, sink = 0.15, materials = { Enum.Material.Grass }, maxCount = 120, parent = detail,
	})
	W.scatter(region, {
		templates = { kit:WaitForChild("Rock_A") :: Model },
		spacing = 22, seed = 12, scaleMin = 0.7, scaleMax = 2.2, scaleCurve = 3,
		alignToNormal = true, sink = 0.3, maxCount = 14, parent = detail,
	})
	region:Destroy()

	-- verify: budget and audit, then capture spawn, road and overview shots and walk the route
	W.budgetReport(root, "mobile")
	W.auditWorld(root)
end
