--!strict
-- LihFolk Systems: Currency
-- Install: ServerScriptService/LihFolk/Currency (ModuleScript)
--
-- Server-owned balances. Amounts are whole numbers; NaN, infinity, negatives
-- and fractions are refused. Balances are capped below 2^53 so they stay exact.
-- Clients read balances from player attributes (and optional leaderstats);
-- there is no remote that changes a balance.
-- Mark a currency `paid = true` if Robux can buy it, directly or indirectly:
-- anything random priced in it is then a paid random item (EggHatch uses this).
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Signal"))
local PlayerData = require(script.Parent.PlayerData)

export type CurrencyDef = {
	start: number?, -- starting balance, default 0
	max: number?, -- default 1e15 (exact integers stop at 2^53, about 9e15)
	paid: boolean, -- true if Robux can buy this currency in any way
	leaderstat: boolean?, -- also show in the player list
}

export type Config = {
	currencies: { [string]: CurrencyDef },
	maxMultiplier: number?, -- cap on the product of all earn multipliers, default 1000
}

local Currency = {}
Currency.Changed = Signal.new() -- (player, name, balance, delta, reason)

local MAX_SAFE = 2 ^ 53
local defs: { [string]: CurrencyDef } = {}
local multiplierProviders: { [string]: { (Player) -> number } } = {}
local maxMultiplier = 1000

---------------------------------------------------------------------------
-- Pure helpers (exported for tests)
---------------------------------------------------------------------------

local function isWhole(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and n < MAX_SAFE and math.floor(n) == n
end
Currency.isWhole = isWhole

-- New balance after adding amount, clamped at max. Returns nil for bad input.
function Currency.applyAdd(balance: number, amount: number, max: number): number?
	if not isWhole(amount) or amount < 1 then
		return nil
	end
	return math.min(balance + amount, max)
end

-- New balance after spending, or nil if the amount is bad or unaffordable.
function Currency.applySpend(balance: number, amount: number): number?
	if not isWhole(amount) or amount < 1 or amount > balance then
		return nil
	end
	return balance - amount
end

-- Product of multipliers with each factor sanitised and the total capped.
function Currency.combineMultipliers(factors: { number }, cap: number): number
	local total = 1
	for _, factor in factors do
		if type(factor) == "number" and factor == factor and factor >= 0 and factor < math.huge then
			total *= factor
		end
	end
	return math.clamp(total, 0, cap)
end

---------------------------------------------------------------------------
-- Internals
---------------------------------------------------------------------------

local function balances(profile: PlayerData.Profile): { [string]: number }
	return profile.Data.Currency.Balances
end

local function publish(player: Player, name: string, balance: number, delta: number, reason: string)
	player:SetAttribute(name, balance)
	local def = defs[name]
	if def and def.leaderstat then
		local folder = player:FindFirstChild("leaderstats")
		local value = folder and folder:FindFirstChild(name)
		if value and value:IsA("IntValue") then
			value.Value = balance
		end
	end
	Currency.Changed:Fire(player, name, balance, delta, reason)
end

local function onLoaded(player: Player, profile: PlayerData.Profile)
	local hasLeaderstats = false
	for _, def in defs do
		if def.leaderstat then
			hasLeaderstats = true
		end
	end
	if hasLeaderstats and not player:FindFirstChild("leaderstats") then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		for name, def in defs do
			if def.leaderstat then
				local value = Instance.new("IntValue") -- int64: exact for every allowed balance
				value.Name = name
				value.Parent = folder
			end
		end
		folder.Parent = player
	end
	for name, balance in balances(profile) do
		if defs[name] then
			publish(player, name, balance, 0, "load")
		end
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Currency.Init(config: Config)
	maxMultiplier = config.maxMultiplier or 1000
	for name, def in config.currencies do
		assert(string.match(name, "^%a%w*$"), `Currency: bad name '{name}'`)
		assert(type(def.paid) == "boolean", `Currency {name}: set paid = true/false explicitly`)
		local max = def.max or 1e15
		assert(isWhole(max) and max >= 1, `Currency {name}: max must be a whole number below 2^53`)
		assert(def.start == nil or (isWhole(def.start) and def.start <= max), `Currency {name}: bad start`)
		defs[name] = def
		multiplierProviders[name] = {}
	end
	PlayerData.RegisterSlice("Currency", function()
		local start: { [string]: number } = {}
		local earned: { [string]: number } = {}
		for name, def in defs do
			start[name] = def.start or 0
			earned[name] = 0
		end
		return { Balances = start, Earned = earned }
	end)
	PlayerData.Loaded:Connect(onLoaded)
end

function Currency.Exists(name: string): boolean
	return defs[name] ~= nil
end

function Currency.IsPaid(name: string): boolean
	local def = defs[name]
	return def ~= nil and def.paid
end

-- Balance, or nil while the profile is not ready.
function Currency.Get(player: Player, name: string): number?
	local profile = PlayerData.Get(player)
	if not profile or not defs[name] then
		return nil
	end
	return balances(profile)[name] or 0
end

function Currency.GetEarned(player: Player, name: string): number?
	local profile = PlayerData.Get(player)
	if not profile or not defs[name] then
		return nil
	end
	return profile.Data.Currency.Earned[name] or 0
end

function Currency.CanAfford(player: Player, name: string, amount: number): boolean
	local balance = Currency.Get(player, name)
	return balance ~= nil and isWhole(amount) and balance >= amount
end

-- Adds a whole amount. Returns true on success. Synchronous, never yields.
function Currency.Add(player: Player, name: string, amount: number, reason: string): boolean
	local profile = PlayerData.Get(player)
	local def = defs[name]
	if not profile or not def then
		return false
	end
	local map = balances(profile)
	local before = map[name] or 0
	local after = Currency.applyAdd(before, amount, def.max or 1e15)
	if not after then
		return false
	end
	map[name] = after
	local earned = profile.Data.Currency.Earned
	earned[name] = math.min((earned[name] or 0) + amount, MAX_SAFE - 1)
	PlayerData.MarkDirty(profile)
	publish(player, name, after, after - before, reason)
	return true
end

-- Spends a whole amount if affordable. Synchronous, never yields.
function Currency.Spend(player: Player, name: string, amount: number, reason: string): boolean
	local profile = PlayerData.Get(player)
	if not profile or not defs[name] then
		return false
	end
	local map = balances(profile)
	local before = map[name] or 0
	local after = Currency.applySpend(before, amount)
	if not after then
		return false
	end
	map[name] = after
	PlayerData.MarkDirty(profile)
	publish(player, name, after, after - before, reason)
	return true
end

-- Sets a balance (rebirth resets, admin fixes). Does not count as earned.
function Currency.Set(player: Player, name: string, value: number, reason: string): boolean
	local profile = PlayerData.Get(player)
	local def = defs[name]
	if not profile or not def or not isWhole(value) then
		return false
	end
	local map = balances(profile)
	local before = map[name] or 0
	local after = math.min(value, def.max or 1e15)
	map[name] = after
	PlayerData.MarkDirty(profile)
	publish(player, name, after, after - before, reason)
	return true
end

-- Registers a multiplier provider for earning (rebirths, passes, boosts).
-- The provider must be cheap and must not yield.
function Currency.AddMultiplier(name: string, provider: (Player) -> number)
	assert(multiplierProviders[name], `Currency.AddMultiplier: unknown currency {name}`)
	table.insert(multiplierProviders[name], provider)
end

function Currency.GetMultiplier(player: Player, name: string): number
	local factors = {}
	for _, provider in multiplierProviders[name] or {} do
		local ok, value = pcall(provider, player)
		if ok then
			table.insert(factors, value)
		end
	end
	return Currency.combineMultipliers(factors, maxMultiplier)
end

-- Earn from gameplay: base amount times all multipliers, rounded down.
-- Returns (success, amountAdded).
function Currency.Earn(player: Player, name: string, base: number, reason: string): (boolean, number)
	if type(base) ~= "number" or base ~= base or base <= 0 or base >= MAX_SAFE then
		return false, 0
	end
	local amount = math.floor(base * Currency.GetMultiplier(player, name))
	if amount < 1 then
		return false, 0
	end
	return Currency.Add(player, name, amount, reason), amount
end

-- Nothing per-player is cached in this module: balances live in the profile,
-- so there is no PlayerRemoving cleanup to do.

return Currency
