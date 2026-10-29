--!strict
-- LocalScript (StarterPlayerScripts): slash VFX for every character's sword clips.
-- Our clips carry KeyframeMarkers: TrailOn, Hit (value "1"/"2"/"3"/"heavy"/"dash"/"thrust"), TrailOff,
-- DashStart (dash distance), Impact (GroundSlam; value "ice" -> IceExplosion), Deflect (parry). SwordHeavy opens
-- with a ChargeUp retimed to its Hit; its Trail stays off (frontal SlashSweep, see NoTrailClips).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VFX = require(ReplicatedStorage:WaitForChild("LihFolkVFX"))
VFX.preload()

local localPlayer = Players.LocalPlayer

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local animator = humanoid:WaitForChild("Animator", 10)
	if not animator or not animator:IsA("Animator") then
		return
	end
	-- optional weapon trail: a Tool with a "Blade" part (blade along its -Z axis)
	local trail: Trail? = nil
	local tool = character:FindFirstChildOfClass("Tool")
	local blade = tool and tool:FindFirstChild("Blade")
	if blade and blade:IsA("BasePart") then
		local len = blade.Size.Z
		trail = VFX.attachTrail(blade, Vector3.new(0, 0, len * 0.3), Vector3.new(0, 0, -len * 0.5), "teal")
	end
	local unbind = VFX.bindAnimator(animator, character, {
		trail = trail,
		important = player == localPlayer,
		-- element comes from the character's "VFXElement" attribute when not set here
	})
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			unbind()
		end
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(c)
		onCharacter(player, c)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayer, p)
end
