--!strict
--[[
	LihFolk UI example: SETTINGS (toggle rows)
	LocalScript in StarterPlayer > StarterPlayerScripts.

	Optional pieces this script uses when present:
	  SoundService > Music (SoundGroup) and SoundService > SFX (SoundGroup)
	  ReplicatedStorage > Remotes > SaveSettings (RemoteEvent) FireServer(settings)
	    The server must validate types and keys before saving.
	Reduced Motion starts from the platform setting and can be overridden here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local UI = ReplicatedStorage:WaitForChild("LihFolkUI")
local Theme = require(UI:WaitForChild("LihFolkUITheme"))
local C = require(UI:WaitForChild("LihFolkUIComponents"))
local Controller = require(UI:WaitForChild("LihFolkUIController"))

type Settings = {
	music: boolean,
	sfx: boolean,
	reducedMotion: boolean,
	hideOthersEffects: boolean,
	largeUi: boolean,
}

local DEFAULTS: Settings = {
	music = true,
	sfx = true,
	reducedMotion = Theme.isReducedMotion(),
	hideOthersEffects = false,
	largeUi = false,
}

local settings: Settings = table.clone(DEFAULTS)

local function setGroupVolume(name: string, on: boolean)
	local group = SoundService:FindFirstChild(name)
	if group and group:IsA("SoundGroup") then
		group.Volume = if on then 0.5 else 0
	end
end

local saveQueued = false
local function save()
	-- Batch rapid toggles into one request.
	if saveQueued then
		return
	end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		local remote = folder and folder:FindFirstChild("SaveSettings")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer(table.clone(settings))
		end
	end)
end

local function apply()
	setGroupVolume("Music", settings.music)
	setGroupVolume("SFX", settings.sfx)
	Controller.setReducedMotion(settings.reducedMotion)
	Controller.setPlayerScale(if settings.largeUi then 1.15 else 1)
	-- Your VFX code reads this attribute to skip other players' effects.
	Players.LocalPlayer:SetAttribute("HideOthersEffects", settings.hideOthersEffects)
end

Controller.start()

local rows: { [string]: any } = {}

local window = C.Window({
	name = "Settings",
	title = "Settings",
	theme = "settings",
	icon = "settings",
	size = Vector2.new(640, 580),
	headerAction = {
		text = "RESET",
		role = "neutral",
		onActivated = function()
			settings = table.clone(DEFAULTS)
			local store: any = settings
			for key, row in rows do
				row.toggle.set(store[key], true)
			end
			apply()
			save()
		end,
	},
})

type RowSpec = { key: string, label: string, description: string, icon: string }
local ROWS: { RowSpec } = {
	{ key = "music", label = "Music", description = "Background music", icon = "music" },
	{ key = "sfx", label = "Sound Effects", description = "Clicks, rewards and hits", icon = "sound" },
	{ key = "reducedMotion", label = "Reduced Motion", description = "Fewer pops, no spinning rays", icon = "motion" },
	{ key = "hideOthersEffects", label = "Hide Others' Effects", description = "Smoother in busy servers", icon = "eye" },
	{ key = "largeUi", label = "Larger Menus", description = "Scales menus up where they fit", icon = "scale" },
}

for index, spec in ROWS do
	local initial: any = settings
	rows[spec.key] = C.SettingRow({
		label = spec.label,
		description = spec.description,
		icon = spec.icon,
		value = initial[spec.key],
		layoutOrder = index,
		parent = window.body,
		onChanged = function(value: boolean)
			local store: any = settings
			store[spec.key] = value
			apply()
			save()
		end,
	})
end

window.defaultSelection = rows.music.hit
Controller.register(window)
Controller.addHudButton({ window = "Settings", label = "Settings", icon = "settings", theme = "settings", layoutOrder = 5 })
apply()
