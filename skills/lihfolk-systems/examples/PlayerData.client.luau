--!strict
-- LihFolk Systems example: PlayerData (client)
-- Install: StarterPlayer/StarterPlayerScripts/PlayerDataClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- Wait for the server to say the profile is ready before showing data UI.
if player:GetAttribute("DataReady") ~= true then
	player:GetAttributeChangedSignal("DataReady"):Wait()
end
print("[PlayerDataExample] volume", player:GetAttribute("Volume"))
