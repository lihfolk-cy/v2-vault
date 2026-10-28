--!strict
-- LihFolk Systems example: PlayerData (server)
-- Install: ServerScriptService/PlayerDataExample (Script). Use this OR examples/Main.server.luau,
-- never both: every remote is declared once and a second Init errors on purpose.
-- Status: reviewed, not run in Studio.

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("LihFolk")
local PlayerData = require(Server.PlayerData)

-- A service owns a slice of the profile; defaults are reconciled on load.
PlayerData.Configure({
	storeName = "PlayerData_v1",
	schemaVersion = 2,
	migrations = {
		-- Version 1 stored Settings.Volume as 0..100; version 2 stores 0..1.
		[2] = function(data)
			if data.Settings and type(data.Settings.Volume) == "number" then
				data.Settings.Volume = math.clamp(data.Settings.Volume / 100, 0, 1)
			end
		end,
	},
})
PlayerData.RegisterSlice("Settings", function()
	return { Volume = 0.8, Music = true }
end)

PlayerData.Loaded:Connect(function(player: Player, profile: PlayerData.Profile)
	player:SetAttribute("Volume", profile.Data.Settings.Volume)
end)
PlayerData.LoadFailed:Connect(function(player: Player, reason: string)
	warn(`[PlayerDataExample] {player.UserId} failed to load: {reason}`)
end)

PlayerData.Start()

-- Studio test switches (ServerStorage attributes):
--   TestProfileKey = "a"        -> a fresh profile on a separate key
--   SimulateLoadFailure = true  -> you must be kicked and your save untouched
