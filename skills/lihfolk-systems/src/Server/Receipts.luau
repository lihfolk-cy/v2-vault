--!strict
-- LihFolk Systems: Receipts (the ProcessReceipt router)
-- Install: ServerScriptService/LihFolk/Receipts (ModuleScript)
--
-- The ONLY assignment of MarketplaceService.ProcessReceipt in the game.
-- Grep your project for "ProcessReceipt" after installing: a second assignment
-- silently replaces this one and that system's products never grant.
--
-- Rules implemented (vault: Developer Products and ProcessReceipt):
--   * dispatch by product key; startup assert that every product has a grant
--   * wait for the profile; player gone or not loaded -> NotProcessedYet
--   * grant + PurchaseId + purchase log in one document, one write
--   * PurchaseGranted only after that write succeeded
--   * one-per-player limits are enforced at PROMPT time (Shop), not here:
--     refusing a paid receipt leaves it stuck
--   * paid grants never fail on a full bag (force), the player already paid
--   * side effects (announcements, analytics) run once, after the durable save
-- Retired products keep their entry forever so late receipts still grant.
-- Status: reviewed, not run in Studio.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Signal"))
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)

export type CustomGrant = (player: Player, profile: PlayerData.Profile, receipt: { [string]: any }) -> boolean
export type PromptCheck = (player: Player) -> (boolean, string?)

export type ProductDef = {
	id: number, -- Developer Product id from the Creator Dashboard
	reward: Rewards.Reward?, -- data grant, or
	custom: string?, -- name of a grant registered with SetCustomGrant
	paidRandom: boolean?, -- outcome is random or a luck modifier: PolicyService gate at prompt
	limit: number?, -- max purchases per player (checked at prompt time)
	retired: boolean?, -- no longer sold; still granted if a late receipt arrives
}

export type Config = { products: { [string]: ProductDef } }

local Receipts = {}
-- (player, productKey, receiptInfo). Fires at most once per purchase, after the durable save:
-- not for a redelivered receipt that was already granted ("duplicate"), and not if the server
-- stops between the save and the fire. Use it for announcements and analytics; anything the
-- player must keep belongs in the grant itself (it is saved in the same write as the PurchaseId).
Receipts.Granted = Signal.new()

local products: { [string]: ProductDef } = {}
local byId: { [number]: string } = {}
local customGrants: { [string]: CustomGrant } = {}
local promptChecks: { [string]: PromptCheck } = {}
local started = false
local PROFILE_WAIT_SECONDS = 15

function Receipts.Init(config: Config)
	for key, def in config.products do
		assert(type(def.id) == "number" and def.id >= 0 and math.floor(def.id) == def.id, `Receipts {key}: id must be a whole number`)
		assert((def.reward ~= nil) ~= (def.custom ~= nil), `Receipts {key}: set exactly one of reward or custom`)
		if def.id > 0 then
			assert(byId[def.id] == nil, `Receipts: product id {def.id} used by {byId[def.id]} and {key}`)
			byId[def.id] = key
		else
			warn(`[Receipts] {key} has id 0 (placeholder); it cannot be prompted or granted`)
		end
		if def.reward then
			Rewards.Validate(`Receipts {key}`, def.reward)
		end
		products[key] = def
	end
	PlayerData.RegisterSlice("Purchases", function()
		return {} :: { [string]: number } -- productKey -> times granted
	end)
end

-- Registers the grant for products with `custom = name` (luck boosts, paid hatches...).
-- The function must validate, mutate synchronously and return true.
function Receipts.SetCustomGrant(name: string, grant: CustomGrant)
	assert(not started, "Receipts.SetCustomGrant after Start")
	customGrants[name] = grant
end

-- Extra prompt-time check for a product (e.g. luck already at the cap).
function Receipts.SetPromptCheck(productKey: string, check: PromptCheck)
	assert(products[productKey], `Receipts.SetPromptCheck: unknown product {productKey}`)
	promptChecks[productKey] = check
end

function Receipts.GetProduct(productKey: string): ProductDef?
	return products[productKey]
end

function Receipts.GetPromptCheck(productKey: string): PromptCheck?
	return promptChecks[productKey]
end

function Receipts.PurchaseCount(player: Player, productKey: string): number?
	local profile = PlayerData.Get(player)
	if not profile then
		return nil
	end
	return profile.Data.Purchases[productKey] or 0
end

local function grantFor(key: string, def: ProductDef, player: Player, receipt: { [string]: any }): (PlayerData.Profile) -> boolean
	return function(profile: PlayerData.Profile): boolean
		local granted: boolean
		if def.custom then
			granted = customGrants[def.custom :: string](player, profile, receipt) == true
		else
			-- Paid: force past a full bag; mark uniques Paid for trading policy.
			granted = Rewards.Grant(player, def.reward :: Rewards.Reward, `product:{key}`, true, true)
		end
		if granted then
			local purchases = profile.Data.Purchases
			purchases[key] = (purchases[key] or 0) + 1
		end
		return granted
	end
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local key = byId[receipt.ProductId]
	if not key then
		-- Unknown product: keep it pending until a server build that knows it.
		warn(`[Receipts] no product for id {receipt.ProductId}; leaving receipt pending`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local def = products[key]
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = PlayerData.WaitForProfile(player, PROFILE_WAIT_SECONDS)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local entry: PlayerData.PurchaseEntry = {
		Id = tostring(receipt.PurchaseId),
		Product = key,
		Robux = tonumber(receipt.CurrencySpent) or 0,
		Time = os.time(),
	}
	local result = PlayerData.ProcessPurchaseAsync(player, entry, grantFor(key, def, player, receipt))
	if result == "granted" then
		Receipts.Granted:Fire(player, key, receipt)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	elseif result == "duplicate" then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function Receipts.Start()
	assert(not started, "Receipts.Start called twice")
	for key, def in products do
		if def.custom then
			assert(customGrants[def.custom :: string], `Receipts {key}: custom grant '{def.custom}' was never registered`)
		end
	end
	started = true
	MarketplaceService.ProcessReceipt = processReceipt
end

-- Exposed for tests (call with a fake receipt in Studio, never live).
Receipts._processReceipt = processReceipt

return Receipts
