--!strict
-- LocalScript (StarterPlayerScripts): sword combo sounds for every character + a UI click.
-- Same KeyframeMarkers as LihFolkVFX: TrailOn (swing whoosh), Hit "1"/"2"/"3"/"heavy"/"dash"/"thrust",
-- DashStart, Impact, Deflect, Footstep. SwordHeavy opens with the ChargeUp riser, stopped if the clip is cut.
-- Your own sounds play 2D at full volume; other players' sounds play at their root part, quieter.
-- Ids: the module ships every take as "rbxassetid://REPLACE_ME" (skipped with a warning). Replace them in
-- LihFolkSFX.Defs with Roblox-licensed Creator Store ids or ids the user uploaded from a licensed premium
-- library, and set each layer's `source`. Never paste an id you did not find or were not given.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SFX = require(ReplicatedStorage:WaitForChild("LihFolkSFX"))
SFX.setupBuses()
SFX.preload()

local localPlayer = Players.LocalPlayer

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local animator = humanoid:WaitForChild("Animator", 10)
	if not animator or not animator:IsA("Animator") then
		return
	end
	local mine = player == localPlayer
	local unbind = SFX.bindAnimator(animator, SFX.Maps.Default, if mine then nil else root, {
		volume = if mine then 1 else SFX.Config.onlookerVolume,
		onPlay = { SwordHeavy = "ChargeUp" },
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

-- UI: click and hover on a menu button (2D, UI bus; hover is throttled by the def's cooldown).
local playerGui = localPlayer:WaitForChild("PlayerGui")
local menu = playerGui:WaitForChild("MainMenu", 10)
local playButton = menu and menu:FindFirstChild("PlayButton", true)
if playButton and playButton:IsA("GuiButton") then
	playButton.MouseEnter:Connect(function()
		SFX.playUI("UIHover")
	end)
	playButton.Activated:Connect(function()
		SFX.playUI("UIClick")
	end)
end

-- Settings menu sliders (0..1) call: SFX.setBusVolume("SFX", value) / ("Music", v) / ("UI", v) / ("Master", v)
