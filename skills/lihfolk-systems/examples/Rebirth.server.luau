--!strict
-- LihFolk Systems example: Rebirth (server)
-- Install: ServerScriptService/RebirthExample (Script). Use this OR examples/Main.server.luau,
-- never both: every remote is declared once and a second Init errors on purpose.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("LihFolk")
local Config = require(ReplicatedStorage:WaitForChild("LihFolkConfig")) :: any
local PlayerData = require(Server.PlayerData)
local Currency = require(Server.Currency)
local Rebirth = require(Server.Rebirth)

PlayerData.Configure(Config.PlayerData)
Currency.Init(Config.Currency)
Rebirth.Init(Config.Rebirth) -- also registers the Coins earn multiplier
PlayerData.Start()
