--!strict
-- LihFolk Systems: Rebirth
-- Install: ServerScriptService/LihFolk/Rebirth (ModuleScript)
--
-- Spend a currency to reset it (and others you list) for a permanent earn
-- multiplier. Cost grows geometrically: rebirth i (0-based) costs base * growth^i.
-- Bulk buys use the closed-form geometric sum, so "x5" and "max" are O(1)
-- and the price is computed only on the server.
--   total(n, k) = floor(base * growth^n * (growth^k - 1) / (growth - 1))
-- Remote: Rebirth.Request(count)  count 1..maxBulk, or 0 for "as many as affordable"
-- Attribute: Rebirths (UI only)
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local Currency = require(script.Parent.Currency)

local T = Net.T

export type Config = {
	currency: string, -- paid with and reset, e.g. "Coins"
	baseCost: number,
	growth: number, -- >= 1
	bonusPerRebirth: number, -- multiplier = 1 + rebirths * bonus
	alsoReset: { string }?, -- other currencies reset to 0
	maxBulk: number?, -- default 1000
	maxRebirths: number?, -- default 1e6
}

local Rebirth = {}

local cfg: Config? = nil
local MAX_SAFE = 2 ^ 53

local function config(): Config
	assert(cfg, "Rebirth.Init has not run")
	return cfg :: Config
end

-- Pure: total cost of k rebirths starting after n done. Returns math.huge if not representable.
function Rebirth.totalCost(n: number, k: number, base: number, growth: number): number
	if k <= 0 then
		return 0
	end
	local total
	if growth == 1 then
		total = base * k
	else
		total = base * growth ^ n * (growth ^ k - 1) / (growth - 1)
	end
	if total ~= total or total >= MAX_SAFE then
		return math.huge
	end
	return math.floor(total)
end

-- Pure: largest k <= cap with totalCost(n, k) <= coins.
function Rebirth.maxAffordable(n: number, coins: number, base: number, growth: number, cap: number): number
	if coins < Rebirth.totalCost(n, 1, base, growth) then
		return 0
	end
	local k
	if growth == 1 then
		k = math.floor(coins / base)
	else
		local first = base * growth ^ n
		k = math.floor(math.log(1 + coins * (growth - 1) / first) / math.log(growth))
	end
	k = math.clamp(k, 0, cap)
	-- Floating point can be off by one either way; correct with exact checks.
	while k > 0 and Rebirth.totalCost(n, k, base, growth) > coins do
		k -= 1
	end
	while k < cap and Rebirth.totalCost(n, k + 1, base, growth) <= coins do
		k += 1
	end
	return k
end

function Rebirth.multiplierFor(rebirths: number, bonus: number): number
	return 1 + rebirths * bonus
end

function Rebirth.Get(player: Player): number
	local profile = PlayerData.Get(player)
	return if profile then profile.Data.Rebirth.Count else 0
end

-- Cost of the next `k` rebirths for this player (for UI).
function Rebirth.Quote(player: Player, k: number): number
	local c = config()
	return Rebirth.totalCost(Rebirth.Get(player), k, c.baseCost, c.growth)
end

local function request(player: Player, count: number): Net.Result
	local c = config()
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local state = profile.Data.Rebirth
	local n = state.Count
	local coins = Currency.Get(player, c.currency) or 0
	local cap = math.min(c.maxBulk or 1000, (c.maxRebirths or 1e6) - n)
	if cap <= 0 then
		return Net.fail("MaxReached")
	end
	local k = if count == 0 then Rebirth.maxAffordable(n, coins, c.baseCost, c.growth, cap) else math.min(count, cap)
	if k <= 0 then
		return Net.fail("NotEnough")
	end
	local cost = Rebirth.totalCost(n, k, c.baseCost, c.growth)
	if cost > coins then
		return Net.fail("NotEnough")
	end
	-- Checks passed; nothing below yields. The whole balance resets (the
	-- leftover after the cost is part of the rebirth trade), then count up.
	Currency.Set(player, c.currency, 0, "rebirth")
	for _, other in c.alsoReset or {} do
		Currency.Set(player, other, 0, "rebirth")
	end
	state.Count = n + k
	PlayerData.MarkDirty(profile)
	player:SetAttribute("Rebirths", state.Count)
	return Net.ok({ rebirths = state.Count, gained = k, multiplier = Rebirth.multiplierFor(state.Count, c.bonusPerRebirth) })
end

function Rebirth.Init(newConfig: Config)
	assert(Currency.Exists(newConfig.currency), `Rebirth: unknown currency {newConfig.currency}`)
	assert(newConfig.baseCost >= 1 and newConfig.growth >= 1 and newConfig.growth < 100, "Rebirth: baseCost >= 1, growth 1..100")
	assert(newConfig.bonusPerRebirth >= 0, "Rebirth: bonusPerRebirth >= 0")
	for _, other in newConfig.alsoReset or {} do
		assert(Currency.Exists(other), `Rebirth: unknown currency {other}`)
	end
	cfg = newConfig
	local maxBulk = newConfig.maxBulk or 1000

	PlayerData.RegisterSlice("Rebirth", function()
		return { Count = 0 }
	end)
	-- Income multiplier for the reset currency. Cheap and non-yielding.
	Currency.AddMultiplier(newConfig.currency, function(player: Player): number
		return Rebirth.multiplierFor(Rebirth.Get(player), newConfig.bonusPerRebirth)
	end)

	Net.Handle("Rebirth.Request", {
		rate = { burst = 3, perSecond = 1 },
		args = { T.integer(0, maxBulk) },
		handler = request,
	})
	PlayerData.Loaded:Connect(function(player: Player, profile: PlayerData.Profile)
		player:SetAttribute("Rebirths", profile.Data.Rebirth.Count)
	end)
end

return Rebirth
