--!strict
-- LihFolk Systems: Policy
-- Install: ServerScriptService/LihFolk/Policy (ModuleScript)
--
-- Server-side PolicyService cache with two SEPARATE gates:
--   CanBuyPaidRandom(player)  ArePaidRandomItemsRestricted must be exactly false
--   CanTradePaid(player)      IsPaidItemTradingAllowed must be exactly true
-- Fail closed: until a successful fetch, after an error, or when a key is
-- missing, the player is treated as restricted. Failed fetches are retried in
-- the background so a transient error does not lock a player out for good.
-- Results are mirrored to attributes for UI only; the server never reads them back.
-- Policy facts: Roblox docs, as of October 2026. Recheck before shipping.
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Signal = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Signal"))

export type Info = {
	fetched: boolean,
	paidRandomAllowed: boolean,
	paidTradingAllowed: boolean,
}

local Policy = {}
Policy.Changed = Signal.new() -- (player, info)

local cache: { [Player]: Info } = {}
local FETCH_ATTEMPTS = 4
local BACKGROUND_RETRY_SECONDS = 30
local BACKGROUND_RETRIES = 10

local RESTRICTED: Info = table.freeze({ fetched = false, paidRandomAllowed = false, paidTradingAllowed = false })

-- Pure: interprets a raw PolicyService table, failing closed on anything unexpected.
function Policy.interpret(raw: any): Info
	if type(raw) ~= "table" then
		return RESTRICTED
	end
	return {
		fetched = true,
		paidRandomAllowed = raw.ArePaidRandomItemsRestricted == false,
		paidTradingAllowed = raw.IsPaidItemTradingAllowed == true,
	}
end

local function studioOverride(info: Info): Info
	-- Set ServerStorage attribute ForceRestrictedPolicy = true in Studio to walk the restricted path.
	if RunService:IsStudio() and ServerStorage:GetAttribute("ForceRestrictedPolicy") == true then
		return { fetched = true, paidRandomAllowed = false, paidTradingAllowed = false }
	end
	return info
end

local function publish(player: Player, info: Info)
	cache[player] = info
	player:SetAttribute("PaidRandomAllowed", info.paidRandomAllowed)
	player:SetAttribute("PaidTradingAllowed", info.paidTradingAllowed)
	Policy.Changed:Fire(player, info)
end

local function fetchAsync(player: Player): boolean
	for attempt = 1, FETCH_ATTEMPTS do
		local ok, raw = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if player.Parent ~= Players then
			return true
		end
		if ok then
			publish(player, studioOverride(Policy.interpret(raw)))
			return true
		end
		if attempt < FETCH_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false
end

local function onPlayerAdded(player: Player)
	publish(player, RESTRICTED) -- closed until proven otherwise
	if fetchAsync(player) then
		return
	end
	warn(`[Policy] could not fetch policy for {player.UserId}; treating as restricted and retrying`)
	for _ = 1, BACKGROUND_RETRIES do
		task.wait(BACKGROUND_RETRY_SECONDS)
		if player.Parent ~= Players or fetchAsync(player) then
			return
		end
	end
end

function Policy.Get(player: Player): Info
	return cache[player] or RESTRICTED
end

function Policy.CanBuyPaidRandom(player: Player): boolean
	return Policy.Get(player).paidRandomAllowed
end

function Policy.CanTradePaid(player: Player): boolean
	return Policy.Get(player).paidTradingAllowed
end

local initialised = false
function Policy.Init()
	if initialised then
		return
	end
	initialised = true
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		cache[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return Policy
