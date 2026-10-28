--!strict
-- LihFolk Systems example: Codes (server)
-- Install: ServerScriptService/CodesExample (Script). Use this OR examples/Main.server.luau,
-- never both: every remote is declared once and a second Init errors on purpose.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("LihFolk")
local Config = require(ReplicatedStorage:WaitForChild("LihFolkConfig")) :: any
local PlayerData = require(Server.PlayerData)
local ServerStorage = game:GetService("ServerStorage")
local Policy = require(Server.Policy)
local Currency = require(Server.Currency)
local Inventory = require(Server.Inventory)
local Codes = require(Server.Codes)
local Secrets = require(ServerStorage:WaitForChild("LihFolkSecrets")) :: any

PlayerData.Configure(Config.PlayerData)
Policy.Init()
Currency.Init(Config.Currency)
Inventory.Init(Config.Inventory)
Codes.Init(Secrets.Codes)
PlayerData.Start()
