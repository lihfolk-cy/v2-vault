--!strict
-- Script (ServerScriptService): validates ability casts and broadcasts ONE compact VFX payload to the
-- players near the cast. The server renders nothing; clients build every effect locally.
--
--   client -> server   AbilityCast:FireServer(presetId, aim)                 (the client never sends colour,
--                                                                             size or a CFrame to trust)
--   server -> clients  AbilityVFX:FireClient(p, caster, presetId, cf, elementIndex, seed, aux)
--
-- The caster already played its own effect (prediction) and is skipped here. Hit detection and damage
-- stay on the server: put them where the comment says.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local A = require(ReplicatedStorage:WaitForChild("LihFolkVFX_Abilities")) -- only its id tables and CastRules are used here

local BROADCAST_RADIUS = 250 -- studs: players farther away would cull the effect anyway
local BUCKET_SIZE = 6 -- casts a player may burst
local BUCKET_REFILL = 3 -- casts per second

local function remote(name: string): RemoteEvent
	local r = ReplicatedStorage:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		return r
	end
	local n = Instance.new("RemoteEvent")
	n.Name = name
	n.Parent = ReplicatedStorage
	return n
end
local castRemote = remote("AbilityCast")
local vfxRemote = remote("AbilityVFX")

type Limit = { tokens: number, last: number, cooldowns: { [string]: number } }
local limits: { [Player]: Limit } = {}
local rng = Random.new()

local function allow(player: Player, preset: string, cooldown: number): boolean
	local now = os.clock()
	local l = limits[player]
	if not l then
		l = { tokens = BUCKET_SIZE, last = now, cooldowns = {} }
		limits[player] = l
	end
	l.tokens = math.min(BUCKET_SIZE, l.tokens + (now - l.last) * BUCKET_REFILL)
	l.last = now
	if l.tokens < 1 or now < (l.cooldowns[preset] or 0) then
		return false
	end
	l.tokens -= 1
	-- 0.05 s grace for latency jitter between the client's and the server's clocks
	l.cooldowns[preset] = now + cooldown - 0.05
	return true
end

local function finite(v: Vector3): boolean
	return v == v and v.Magnitude < 1e6 -- NaN fails v == v
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if hum and hum.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- One payload to every player near `cf`, except `skip` (the predicting caster).
local function broadcast(caster: Player?, presetId: number, cf: CFrame, elementIndex: number, aux: Vector3?, skip: Player?)
	local seed = rng:NextInteger(1, 2147483646)
	for _, p in Players:GetPlayers() do
		if p ~= skip then
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (root.Position - cf.Position).Magnitude <= BROADCAST_RADIUS then
				vfxRemote:FireClient(p, caster, presetId, cf, elementIndex, seed, aux)
			end
		end
	end
end

-- The element comes from server state (an attribute you set when the player equips a kit), never from the client.
local function elementOf(player: Player): number
	local name = player:GetAttribute("VFXElement")
	return (if type(name) == "string" then A.elementIndex(name) else nil) or 1
end

castRemote.OnServerEvent:Connect(function(player: Player, presetId: unknown, aim: unknown)
	-- 1. shape of the request
	if type(presetId) ~= "number" or typeof(aim) ~= "Vector3" then
		return
	end
	local name = A.PresetIds[presetId]
	local rule = name and A.CastRules[name]
	if not name or not rule then
		return -- not a client-castable preset
	end
	local aimPos = aim :: Vector3
	if not finite(aimPos) then
		return
	end
	-- 2. state: alive, in range, off cooldown
	local root = aliveRoot(player)
	if not root then
		return
	end
	local origin = root.Position
	local offset = aimPos - origin
	if rule.range > 0 and offset.Magnitude > rule.range then
		aimPos = origin + offset.Unit * rule.range -- clamp instead of reject: the caster already saw it
	end
	if not allow(player, name, rule.cooldown) then
		return
	end
	-- 3. gameplay (server authority): hit detection, damage, movement, healing go here.

	-- 4. one compact payload to everyone nearby except the caster
	local look = Vector3.new(offset.X, 0, offset.Z)
	local facing = if look.Magnitude > 0.1 then CFrame.lookAt(origin, origin + look) else root.CFrame
	if name == "Projectile" then
		local muzzle = facing * CFrame.new(1, 0.5, -2)
		broadcast(player, presetId, CFrame.lookAt(muzzle.Position, aimPos), elementOf(player), aimPos, player)
	elseif name == "Teleport" then
		broadcast(player, presetId, facing, elementOf(player), aimPos, player)
	else
		broadcast(player, presetId, facing, elementOf(player), nil, player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	limits[player] = nil
end)

-- Server-originated effects (boss telegraphs, level-ups) use the same remote with no skipped player.
-- Move `broadcast` into a server ModuleScript when other systems need it:
--   broadcast(nil, A.presetIndex("TelegraphCircle") :: number, bossRoot.CFrame, A.elementIndex("fire") :: number, nil, nil)
--   broadcast(player, A.presetIndex("LevelUp") :: number, root.CFrame, elementOf(player), nil, nil) -- the caster sees it too
