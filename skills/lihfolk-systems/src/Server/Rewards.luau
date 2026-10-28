--!strict
-- LihFolk Systems: Rewards
-- Install: ServerScriptService/LihFolk/Rewards (ModuleScript)
--
-- One reward format shared by Shop, Receipts, Codes, DailyRewards and Quests:
--   { kind = "currency", currency = "Coins", amount = 100 }
--   { kind = "item", item = "SpeedPotion", count = 1 }
--   { kind = "bundle", rewards = { <reward>, ... } }
-- Validate at startup, CanGrant before marking anything claimed, then Grant in
-- the same synchronous block, so "either everything happened or nothing did".
-- Status: reviewed, not run in Studio.

local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)

export type Reward = {
	kind: string,
	currency: string?,
	amount: number?,
	item: string?,
	count: number?,
	rewards: { Reward }?,
}

local Rewards = {}

local function isPositiveWhole(n: any): boolean
	return type(n) == "number" and n == n and n >= 1 and n < 2 ^ 53 and math.floor(n) == n
end

-- Errors with a clear message if the reward is malformed. Call at startup.
function Rewards.Validate(label: string, reward: Reward, depth: number?)
	local d = depth or 0
	assert(d <= 3, `{label}: bundles nested too deep`)
	assert(type(reward) == "table", `{label}: reward must be a table`)
	if reward.kind == "currency" then
		assert(type(reward.currency) == "string" and Currency.Exists(reward.currency :: string), `{label}: unknown currency {reward.currency}`)
		assert(isPositiveWhole(reward.amount), `{label}: currency amount must be a whole number >= 1`)
	elseif reward.kind == "item" then
		assert(type(reward.item) == "string" and Inventory.Exists(reward.item :: string), `{label}: unknown item {reward.item}`)
		assert(isPositiveWhole(reward.count), `{label}: item count must be a whole number >= 1`)
	elseif reward.kind == "bundle" then
		assert(type(reward.rewards) == "table" and #(reward.rewards :: { Reward }) > 0, `{label}: empty bundle`)
		for i, inner in reward.rewards :: { Reward } do
			Rewards.Validate(`{label}[{i}]`, inner, d + 1)
		end
	else
		error(`{label}: unknown reward kind {reward.kind}`)
	end
end

-- Totals item counts across a reward (bundles flattened).
local function collectItems(reward: Reward, into: { [string]: number })
	if reward.kind == "item" then
		local item = reward.item :: string
		into[item] = (into[item] or 0) + (reward.count :: number)
	elseif reward.kind == "bundle" then
		for _, inner in reward.rewards :: { Reward } do
			collectItems(inner, into)
		end
	end
end
Rewards.collectItems = collectItems

-- True if the whole reward fits right now (currencies always fit; they clamp at max).
function Rewards.CanGrant(player: Player, reward: Reward): (boolean, string?)
	local itemsNeeded: { [string]: number } = {}
	collectItems(reward, itemsNeeded)
	if next(itemsNeeded) == nil then
		return true, nil
	end
	return Inventory.CanAddMany(player, itemsNeeded)
end

-- Grants the reward. Call CanGrant first in the same synchronous block.
-- paid marks unique items with Paid provenance (trading policy).
-- force skips inventory capacity (paid receipts only).
function Rewards.Grant(player: Player, reward: Reward, reason: string, paid: boolean?, force: boolean?): boolean
	if reward.kind == "currency" then
		return Currency.Add(player, reward.currency :: string, reward.amount :: number, reason)
	elseif reward.kind == "item" then
		local ok = Inventory.Add(player, reward.item :: string, reward.count :: number, { paid = paid, force = force })
		return ok
	elseif reward.kind == "bundle" then
		local all = true
		for _, inner in reward.rewards :: { Reward } do
			all = Rewards.Grant(player, inner, reason, paid, force) and all
		end
		return all
	end
	return false
end

-- Short text for UI ("100 Coins + 1 Speed Potion").
function Rewards.Describe(reward: Reward): string
	if reward.kind == "currency" then
		return `{reward.amount} {reward.currency}`
	elseif reward.kind == "item" then
		local def = Inventory.GetDef(reward.item :: string)
		local name = if def then def.name else (reward.item :: string)
		return if (reward.count :: number) > 1 then `{reward.count} x {name}` else name
	elseif reward.kind == "bundle" then
		local parts = {}
		for _, inner in reward.rewards :: { Reward } do
			table.insert(parts, Rewards.Describe(inner))
		end
		return table.concat(parts, " + ")
	end
	return "?"
end

return Rewards
