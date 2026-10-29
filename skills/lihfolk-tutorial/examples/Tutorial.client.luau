--!strict
-- LihFolk Tutorial example (client): banner, hints, world guidance, HUD reveal, skip and invite.
-- Install: StarterPlayer/StarterPlayerScripts/TutorialExample (LocalScript)
-- Expects a ScreenGui "HUD" whose buttons are named like the step reveal keys
-- (Coins, Cash, UpgradeButton, PetsButton, InviteButton). Missing ones are skipped quietly.
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Tutorial = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("LihFolkTutorial"))
local Steps = require(ReplicatedStorage:WaitForChild("TutorialSteps")) :: { any }
local remote = ReplicatedStorage:WaitForChild("TutorialRemote") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("HUD", 10)

-- Progressive disclosure: HUD buttons start hidden and appear when their step begins.
local REVEAL_KEYS = { "Coins", "Cash", "UpgradeButton", "PetsButton", "InviteButton" }
local function hudItem(key: string): GuiObject?
	if hud == nil then
		return nil
	end
	local item = hud:FindFirstChild(key, true)
	return if item and item:IsA("GuiObject") then item else nil
end
for _, key in REVEAL_KEYS do
	local item = hudItem(key)
	if item then
		item.Visible = false
	end
end

-- Start from the built-in banner and add reveal + a skip button.
local ui = Tutorial.Client.DefaultUi()

local skipButton = Instance.new("TextButton")
skipButton.Name = "TutorialSkip"
skipButton.AnchorPoint = Vector2.new(1, 0)
skipButton.Position = UDim2.new(1, -12, 0, 12)
skipButton.Size = UDim2.fromOffset(96, 44) -- 44 px: comfortable touch target
skipButton.Text = "Skip"
skipButton.TextSize = 18
skipButton.Visible = false
skipButton.Parent = playerGui:WaitForChild("LihFolkTutorialUI")

local tutorial: any = nil

ui.reveal = function(key: string)
	local item = hudItem(key)
	if item then
		item.Visible = true -- add your own pop-in tween here (skip it under Reduced Motion)
	end
end
ui.setSkipVisible = function(visible: boolean)
	skipButton.Visible = visible
end
ui.celebrate = function(_stepId: string)
	-- Hook your reward moment here: sound, "+N" pop, confetti. Keep it under about a second.
end

local confirming = false
skipButton.Activated:Connect(function()
	if not confirming then
		confirming = true
		skipButton.Text = "Sure?"
		task.delay(3, function()
			confirming = false
			skipButton.Text = "Skip"
		end)
		return
	end
	tutorial:RequestSkip()
end)

tutorial = Tutorial.Client.new({
	steps = Steps,
	remote = remote,
	ui = ui,
})
tutorial:Start()

-- Social step: inviting is a UI action, so the client reports it; the server only accepts it while
-- the "friends" step is active, and it pays nothing. A friend actually joining completes it on the server.
local invite = hudItem("InviteButton")
if invite and invite:IsA("GuiButton") then
	invite.Activated:Connect(function()
		local ok, canInvite = pcall(function(): boolean
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and canInvite then
			SocialService:PromptGameInvite(player)
			tutorial:Report("InviteOpened")
		end
	end)
end
