--!strict
-- LihFolk Systems: Shop
-- Install: ServerScriptService/LihFolk/Shop (ModuleScript)
--
-- Three purchase paths, all server-authoritative:
--   1. Soft-currency items: Shop.Buy(itemKey, quantity). Price and reward come
--      from server config; the client sends only intent. Affordability and
--      bag space are checked, then spend + grant happen with no yield between.
--   2. Developer products: Shop.PromptProduct(productKey). The prompt path is
--      where per-player limits, PolicyService gating for paid random items and
--      custom checks run. Grants happen only in Receipts (ProcessReceipt).
--   3. Game passes: Shop.PromptPass(passKey). Ownership is a server cache
--      filled with UserOwnsGamePassAsync on join (errors are retried and never
--      cached as "not owned") and updated by PromptGamePassPurchaseFinished.
-- Prices shown in UI must come from GetProductInfoAsync at runtime (regional
-- pricing). The server never trusts a client price.
-- Status: reviewed, not run in Studio.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local PlayerData = require(script.Parent.PlayerData)
local Currency = require(script.Parent.Currency)
local Rewards = require(script.Parent.Rewards)
local Receipts = require(script.Parent.Receipts)
local Policy = require(script.Parent.Policy)

local T = Net.T

export type ShopItem = {
	price: { currency: string, amount: number },
	reward: Rewards.Reward,
	maxQuantity: number?, -- per request, default 1
	limit: number?, -- lifetime per player
}

export type PassDef = { id: number, paidModifier: boolean? }

export type Config = {
	items: { [string]: ShopItem },
	passes: { [string]: PassDef },
}

type PassState = "owned" | "notOwned" | "unknown"

local Shop = {}
Shop.PassChanged = Signal.new() -- (player, passKey, owned)

local items: { [string]: ShopItem } = {}
local passes: { [string]: PassDef } = {}
local passById: { [number]: string } = {}
local passCache: { [Player]: { [string]: PassState } } = {}
local PASS_RETRY_SECONDS = 60

---------------------------------------------------------------------------
-- Pure (exported for tests)
---------------------------------------------------------------------------

-- Total price for quantity, or nil if it would not be an exact whole number.
function Shop.totalPrice(unit: number, quantity: number): number?
	local total = unit * quantity
	if total ~= total or total >= 2 ^ 53 or math.floor(total) ~= total then
		return nil
	end
	return total
end

-- Multiplies every amount/count in a reward by quantity (returns a new table).
function Shop.scaleReward(reward: Rewards.Reward, quantity: number): Rewards.Reward
	local out = table.clone(reward)
	if reward.kind == "currency" then
		out.amount = (reward.amount :: number) * quantity
	elseif reward.kind == "item" then
		out.count = (reward.count :: number) * quantity
	elseif reward.kind == "bundle" then
		local inner = {}
		for i, r in reward.rewards :: { Rewards.Reward } do
			inner[i] = Shop.scaleReward(r, quantity)
		end
		out.rewards = inner
	end
	return out
end

---------------------------------------------------------------------------
-- Soft-currency purchases
---------------------------------------------------------------------------

local function buy(player: Player, itemKey: string, quantity: number?): Net.Result
	local item = items[itemKey]
	local qty = quantity or 1
	if qty > (item.maxQuantity or 1) then
		return Net.fail("Invalid")
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local bought = profile.Data.ShopBought
	if item.limit and (bought[itemKey] or 0) + qty > item.limit then
		return Net.fail("LimitReached")
	end
	local total = Shop.totalPrice(item.price.amount, qty)
	if not total then
		return Net.fail("Invalid")
	end
	local reward = Shop.scaleReward(item.reward, qty)
	if not Currency.CanAfford(player, item.price.currency, total) then
		return Net.fail("NotEnough")
	end
	local fits, code = Rewards.CanGrant(player, reward)
	if not fits then
		return Net.fail(code or "BagFull")
	end
	-- Checks passed; from here to the end nothing yields.
	if not Currency.Spend(player, item.price.currency, total, `shop:{itemKey}`) then
		return Net.fail("NotEnough")
	end
	Rewards.Grant(player, reward, `shop:{itemKey}`, Currency.IsPaid(item.price.currency), false)
	bought[itemKey] = (bought[itemKey] or 0) + qty
	PlayerData.MarkDirty(profile)
	return Net.ok({ item = itemKey, quantity = qty })
end

---------------------------------------------------------------------------
-- Developer product prompts
---------------------------------------------------------------------------

local function promptProduct(player: Player, productKey: string): Net.Result
	local def = Receipts.GetProduct(productKey)
	if not def or def.retired or def.id <= 0 then
		return Net.fail("Unavailable")
	end
	-- Purchases are blocked until data loads, so the receipt can always be saved.
	if not PlayerData.Get(player) then
		return Net.fail("NotReady")
	end
	if def.paidRandom and not Policy.CanBuyPaidRandom(player) then
		return Net.fail("Restricted")
	end
	if def.limit then
		local count = Receipts.PurchaseCount(player, productKey) or 0
		if count >= def.limit then
			return Net.fail("LimitReached")
		end
	end
	local check = Receipts.GetPromptCheck(productKey)
	if check then
		local ok, code = check(player)
		if not ok then
			return Net.fail(code or "Unavailable")
		end
	end
	MarketplaceService:PromptProductPurchase(player, def.id)
	return Net.ok()
end

---------------------------------------------------------------------------
-- Game passes
---------------------------------------------------------------------------

local function setPass(player: Player, passKey: string, state: PassState)
	local states = passCache[player]
	if not states then
		return
	end
	local before = states[passKey]
	states[passKey] = state
	player:SetAttribute(`Pass_{passKey}`, state == "owned")
	if before ~= state and state ~= "unknown" then
		Shop.PassChanged:Fire(player, passKey, state == "owned")
	end
end

local function checkPassAsync(player: Player, passKey: string): PassState
	local def = passes[passKey]
	for attempt = 1, 3 do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, def.id)
		if ok then
			return if owns then "owned" else "notOwned"
		end
		if player.Parent ~= Players then
			break
		end
		task.wait(attempt)
	end
	return "unknown" -- never cache "not owned" from an error
end

local function loadPasses(player: Player)
	passCache[player] = {}
	for passKey, def in passes do
		if def.id > 0 then
			task.spawn(function()
				local state = checkPassAsync(player, passKey)
				setPass(player, passKey, state)
				-- Keep retrying unknowns in the background while the player stays.
				while state == "unknown" and player.Parent == Players do
					task.wait(PASS_RETRY_SECONDS)
					state = checkPassAsync(player, passKey)
					setPass(player, passKey, state)
				end
			end)
		end
	end
end

-- Server-side ownership. Unknown (lookup failing) counts as not owned for
-- benefits, but is retried, and is never saved anywhere.
function Shop.OwnsPass(player: Player, passKey: string): boolean
	local states = passCache[player]
	return states ~= nil and states[passKey] == "owned"
end

function Shop.IsPaidModifierPass(passKey: string): boolean
	local def = passes[passKey]
	return def ~= nil and def.paidModifier == true
end

local function promptPass(player: Player, passKey: string): Net.Result
	local def = passes[passKey]
	if def.id <= 0 then
		return Net.fail("Unavailable")
	end
	if Shop.OwnsPass(player, passKey) then
		return Net.fail("AlreadyOwned")
	end
	if def.paidModifier and not Policy.CanBuyPaidRandom(player) then
		return Net.fail("Restricted")
	end
	MarketplaceService:PromptGamePassPurchase(player, def.id)
	return Net.ok()
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Shop.Init(config: Config)
	for key, item in config.items do
		assert(Currency.Exists(item.price.currency), `Shop {key}: unknown currency {item.price.currency}`)
		assert(Currency.isWhole(item.price.amount) and item.price.amount >= 1, `Shop {key}: price must be a whole number >= 1`)
		local maxQ = item.maxQuantity or 1
		assert(maxQ >= 1 and maxQ <= 100 and math.floor(maxQ) == maxQ, `Shop {key}: maxQuantity 1..100`)
		Rewards.Validate(`Shop {key}`, item.reward)
		Rewards.Validate(`Shop {key} x{maxQ}`, Shop.scaleReward(item.reward, maxQ))
		assert(Shop.totalPrice(item.price.amount, maxQ), `Shop {key}: price x maxQuantity overflows`)
		items[key] = item
	end
	for key, def in config.passes do
		assert(type(def.id) == "number" and def.id >= 0, `Shop pass {key}: bad id`)
		if def.id > 0 then
			passById[def.id] = key
		end
		passes[key] = def
	end

	PlayerData.RegisterSlice("ShopBought", function()
		return {} :: { [string]: number }
	end)

	Net.Handle("Shop.Buy", {
		rate = { burst = 5, perSecond = 2 },
		args = { T.key(items), T.optional(T.integer(1, 100)) },
		handler = buy,
	})
	Net.Handle("Shop.PromptProduct", {
		rate = { burst = 3, perSecond = 0.5 },
		args = { T.string(48, "^[%w_]+$") },
		handler = promptProduct,
	})
	Net.Handle("Shop.PromptPass", {
		rate = { burst = 3, perSecond = 0.5 },
		args = { T.key(passes) },
		handler = promptPass,
	})

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, wasPurchased: boolean)
		local passKey = passById[passId]
		if not passKey or not passCache[player] then
			return
		end
		if wasPurchased then
			setPass(player, passKey, "owned")
		end
	end)

	Players.PlayerAdded:Connect(loadPasses)
	Players.PlayerRemoving:Connect(function(player: Player)
		passCache[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if not passCache[player] then
			loadPasses(player)
		end
	end
end

return Shop
