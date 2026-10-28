--!strict
-- LihFolk Systems example: Currency (client)
-- Install: StarterPlayer/StarterPlayerScripts/CurrencyClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- Balances are server-owned attributes: render them, never guess locally.
local function render()
	print(`[CurrencyExample] Coins {player:GetAttribute("Coins") or 0}  Gems {player:GetAttribute("Gems") or 0}`)
end
player:GetAttributeChangedSignal("Coins"):Connect(render)
player:GetAttributeChangedSignal("Gems"):Connect(render)
render()
