--!strict
-- LocalScript (StarterPlayerScripts): predict own casts, render everyone else's from the server payload.
--   Q  projectile at the mouse     E  teleport visual to the mouse (max 40 studs)
--   H  heal                        B  buff
-- Own casts play immediately (zero latency) and the server never echoes them back; the check on `caster`
-- below is a second guard. Other players' casts arrive as one compact payload and replay through
-- LihFolkVFX_Abilities.playPayload, which seeds the variation so every onlooker sees the same layout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local A = require(ReplicatedStorage:WaitForChild("LihFolkVFX_Abilities"))
local castRemote = ReplicatedStorage:WaitForChild("AbilityCast") :: RemoteEvent
local vfxRemote = ReplicatedStorage:WaitForChild("AbilityVFX") :: RemoteEvent

local player = Players.LocalPlayer
local ready: { [string]: number } = {}

local function myElement(): string
	local e = player:GetAttribute("VFXElement")
	return if type(e) == "string" then e else "teal"
end

local function rootAndCharacter(): (BasePart?, Model?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and root and root:IsA("BasePart") then
		return root, character
	end
	return nil, nil
end

local function mouseWorld(character: Model): Vector3?
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local m = UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(m.X, m.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * 300
end

-- Mirror the server's rules so we predict only casts it will accept.
local function cast(name: string, aim: Vector3)
	local rule = A.CastRules[name]
	local id = A.presetIndex(name)
	local root, character = rootAndCharacter()
	if not rule or not id or not root or not character then
		return
	end
	local now = os.clock()
	if now < (ready[name] or 0) then
		return
	end
	ready[name] = now + rule.cooldown
	local origin = root.Position
	local offset = aim - origin
	if rule.range > 0 and offset.Magnitude > rule.range then
		aim = origin + offset.Unit * rule.range
	end
	local look = Vector3.new(offset.X, 0, offset.Z)
	local facing = if look.Magnitude > 0.1 then CFrame.lookAt(origin, origin + look) else root.CFrame
	local opts = { element = myElement(), important = true }

	-- 1. predict: play now
	if name == "Projectile" then
		local muzzle = (facing * CFrame.new(1, 0.5, -2)).Position
		A.Projectile(CFrame.lookAt(muzzle, aim), aim, {
			element = opts.element,
			important = true,
			ignore = { character },
			speed = A.PayloadDefaults.Projectile.speed,
			range = A.PayloadDefaults.Projectile.range,
		})
	elseif name == "Teleport" then
		A.Teleport(facing, CFrame.new(aim) * facing.Rotation, opts)
	elseif name == "Heal" then
		A.Heal(character, opts)
	elseif name == "Buff" then
		A.Buff(character, opts)
	end
	-- 2. ask the server (it validates, applies gameplay and tells everyone else)
	castRemote:FireServer(id, aim)
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	local _, character = rootAndCharacter()
	if not character then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Q or key == Enum.KeyCode.E then
		local aim = mouseWorld(character)
		if aim then
			cast(if key == Enum.KeyCode.Q then "Projectile" else "Teleport", aim)
		end
	elseif key == Enum.KeyCode.H then
		cast("Heal", character:GetPivot().Position)
	elseif key == Enum.KeyCode.B then
		cast("Buff", character:GetPivot().Position)
	end
end)

vfxRemote.OnClientEvent:Connect(function(caster: Player?, presetId: number, cf: CFrame, elementIndex: number, seed: number, aux: Vector3?)
	-- own client-castable presets were already predicted; server-originated ones (LevelUp) still play
	local name = A.PresetIds[presetId]
	if caster == player and name and A.CastRules[name] then
		return
	end
	A.playPayload(caster, presetId, cf, elementIndex, seed, aux)
end)
