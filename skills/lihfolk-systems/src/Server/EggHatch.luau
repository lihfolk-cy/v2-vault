--!strict
-- LihFolk Systems: EggHatch
-- Install: ServerScriptService/LihFolk/EggHatch (ModuleScript)
--
-- Weighted egg hatching with hard pity, luck boosts, once-per-player outcomes,
-- LIVE odds disclosure and PolicyService gating. Built to the vault note
-- "Paid Random Items and Odds Disclosure in Practice" (policy as of October 2026).
--
--   * One function, computeFinals(), builds the odds for (player, egg) from the
--     player's effective luck, pity counter and obtained once-items. The roll
--     AND the odds the player sees both call it, so they cannot diverge.
--   * An egg is a paid random item if its price currency can be bought with
--     Robux (Currency paid = true) or it is flagged paid. Paid luck sources make
--     even a free egg's roll paid-modified: disclosure covers every egg.
--   * Restricted players (ArePaidRandomItemsRestricted not exactly false, or
--     the lookup failed): paid eggs return "Restricted" in the SERVER path, and
--     paid luck sources are excluded from their luck, so their displayed odds
--     and their rolls both use base luck. Fail closed.
--   * Effective luck is published as the EffectiveLuck attribute and every
--     change fires Eggs.OddsChanged so open odds panels refetch live.
--   * Pity counters are saved and survive rejoin (a pity that resets is not pity).
--   * Hatched uniques are marked Paid when money reached the roll, for the
--     separate trading gate (Inventory.CanTrade / Policy.CanTradePaid).
-- Remotes: Eggs.Hatch(eggId, count), Eggs.GetOdds(eggId), Eggs.PreviewBoost(eggId, multiplier)
-- Push:    Eggs.OddsChanged(eggId?)
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local Odds = require(Shared:WaitForChild("Odds"))
local Signal = require(Shared:WaitForChild("Signal"))
local PlayerData = require(script.Parent.PlayerData)
local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)
local Policy = require(script.Parent.Policy)

local T = Net.T

export type EggDef = {
	name: string,
	price: { currency: string, amount: number },
	tiers: { Odds.Tier }, -- ascending rarity; rarest last
	pity: { tier: string, rolls: number }?, -- roll number `rolls` without `tier`-or-better is guaranteed
	hatchCounts: { number }?, -- allowed multi-hatch sizes, default { 1 }
	paid: boolean?, -- force paid status (e.g. sold for Robux elsewhere)
	restrictedNote: string?, -- what restricted players get instead (shown by UI)
}

export type Config = {
	eggs: { [string]: EggDef },
	maxLuck: number, -- luck cap (display and roll)
}

type LuckSource = { name: string, paid: boolean, get: (Player) -> number }
type Boost = { Mult: number, Expires: number, Paid: boolean }

local EggHatch = {}
EggHatch.Hatched = Signal.new() -- (player, eggId, results): feed quests, boards, announcements

local eggs: { [string]: EggDef } = {}
local maxLuck = 10
local luckSources: { LuckSource } = {}
local serverLuck: Boost? = nil
local rng = Random.new()
local oddsChanged: Net.Push? = nil
local lastLuck: { [Player]: number } = {}

---------------------------------------------------------------------------
-- Luck: ONE function, used by roll, display, preview and the attribute
---------------------------------------------------------------------------

local function activeBoosts(profile: PlayerData.Profile, now: number): { Boost }
	local list: { Boost } = profile.Data.Eggs.Boosts
	-- Drop expired entries in place so the saved list stays bounded.
	for i = #list, 1, -1 do
		if list[i].Expires <= now then
			table.remove(list, i)
		end
	end
	return list
end

-- Pure: combine factors with the cap. Exported for tests.
function EggHatch.combineLuck(factors: { number }, cap: number): number
	local luck = 1
	for _, f in factors do
		if type(f) == "number" and f == f and f >= 1 and f < math.huge then
			luck *= f
		end
	end
	return math.clamp(luck, 1, cap)
end

-- Returns (effectiveLuck, paidContributed). extraMultiplier is used only by the boost preview.
function EggHatch.GetEffectiveLuck(player: Player, extraMultiplier: number?, extraPaid: boolean?): (number, boolean)
	local allowPaid = Policy.CanBuyPaidRandom(player)
	local factors: { number } = {}
	local paidUsed = false
	local function consider(mult: number, paid: boolean)
		if paid and not allowPaid then
			return
		end
		if mult > 1 then
			table.insert(factors, mult)
			if paid then
				paidUsed = true
			end
		end
	end
	for _, source in luckSources do
		local ok, mult = pcall(source.get, player)
		if ok and type(mult) == "number" then
			consider(mult, source.paid)
		end
	end
	local now = os.time()
	local profile = PlayerData.Get(player)
	if profile then
		for _, boost in activeBoosts(profile, now) do
			consider(boost.Mult, boost.Paid)
		end
	end
	if serverLuck and serverLuck.Expires > now then
		consider(serverLuck.Mult, serverLuck.Paid)
	end
	if extraMultiplier then
		consider(extraMultiplier, extraPaid == true)
	end
	return EggHatch.combineLuck(factors, maxLuck), paidUsed
end

---------------------------------------------------------------------------
-- Odds for (player, egg): the single source of truth
---------------------------------------------------------------------------

local function tierRank(egg: EggDef, tierName: string): number?
	for rank, tier in egg.tiers do
		if tier.name == tierName then
			return rank
		end
	end
	return nil
end

local function isPaidEgg(egg: EggDef): boolean
	return egg.paid == true or Currency.IsPaid(egg.price.currency)
end

-- Pure core, exported for tests: tiers + luck + pity counter + obtained once-items.
function EggHatch.finalsFor(egg: EggDef, luck: number, pityCount: number, obtained: { [string]: boolean }): ({ Odds.Final }, boolean)
	local excluded: { [string]: boolean } = {}
	for _, tier in egg.tiers do
		for _, item in tier.items do
			if item.once and obtained[item.id] then
				excluded[item.id] = true
			end
		end
	end
	local pityActive = false
	local minRank = 1
	if egg.pity then
		local rank = tierRank(egg, egg.pity.tier) :: number
		if pityCount >= egg.pity.rolls - 1 then
			pityActive = true
			minRank = rank
		end
	end
	local finals, total = Odds.Flatten(egg.tiers, { luck = luck, minRank = minRank, excluded = excluded })
	if total <= 0 and pityActive then
		-- Every pity-tier outcome is already obtained: the guarantee cannot apply.
		pityActive = false
		finals, total = Odds.Flatten(egg.tiers, { luck = luck, minRank = 1, excluded = excluded })
	end
	if total <= 0 then
		return {}, false
	end
	return finals, pityActive
end

local function eggState(profile: PlayerData.Profile)
	return profile.Data.Eggs
end

local function computeFinals(player: Player, profile: PlayerData.Profile, eggId: string, egg: EggDef, extraMultiplier: number?, extraPaid: boolean?)
	local luck, paidLuck = EggHatch.GetEffectiveLuck(player, extraMultiplier, extraPaid)
	local state = eggState(profile)
	local finals, pityActive = EggHatch.finalsFor(egg, luck, state.Pity[eggId] or 0, state.Obtained)
	return finals, pityActive, luck, paidLuck
end

---------------------------------------------------------------------------
-- Display data (what the odds panel shows; same inputs as the roll)
---------------------------------------------------------------------------

function EggHatch.GetDisplayOdds(player: Player, eggId: string): { [string]: any }?
	local egg = eggs[eggId]
	local profile = PlayerData.Get(player)
	if not egg or not profile then
		return nil
	end
	local finals, pityActive, luck, paidLuck = computeFinals(player, profile, eggId, egg)
	local paid = isPaidEgg(egg)
	local allowed = (not paid) or Policy.CanBuyPaidRandom(player)
	local pityInfo: { [string]: any }? = nil
	if egg.pity then
		local rank = tierRank(egg, egg.pity.tier) :: number
		local base = Odds.Flatten(egg.tiers, { luck = luck, excluded = nil })
		local p = Odds.ChanceAtOrAbove(base, rank)
		pityInfo = {
			tier = egg.pity.tier,
			rolls = egg.pity.rolls,
			count = eggState(profile).Pity[eggId] or 0,
			guaranteedNext = pityActive,
			rule = `{egg.pity.tier} or better is guaranteed within {egg.pity.rolls} hatches`,
			baseChance = Odds.Format(p * 100),
			effectiveChance = Odds.Format(Odds.PityEffectiveRate(p, egg.pity.rolls) * 100),
		}
	end
	return {
		eggId = eggId,
		name = egg.name,
		price = egg.price,
		paid = paid,
		allowed = allowed,
		restrictedNote = if allowed then nil else (egg.restrictedNote or "This egg is not available on your account."),
		luck = luck,
		maxLuck = maxLuck,
		paidLuckActive = paidLuck,
		pity = pityInfo,
		rows = Odds.Shown(finals),
		disclaimer = Odds.Disclaimer,
	}
end

-- Before/after for a luck boost on the rarest tier, with the cap applied.
function EggHatch.PreviewBoost(player: Player, eggId: string, multiplier: number, paid: boolean): { [string]: any }?
	local egg = eggs[eggId]
	local profile = PlayerData.Get(player)
	if not egg or not profile then
		return nil
	end
	local rarest = #egg.tiers
	local before, _, luckBefore = computeFinals(player, profile, eggId, egg)
	local after, _, luckAfter = computeFinals(player, profile, eggId, egg, multiplier, paid)
	return {
		tier = egg.tiers[rarest].name,
		before = Odds.Format(Odds.ChanceAtOrAbove(before, rarest) * 100),
		after = Odds.Format(Odds.ChanceAtOrAbove(after, rarest) * 100),
		luckBefore = luckBefore,
		luckAfter = luckAfter,
		atCap = luckAfter <= luckBefore, -- the boost would do nothing: disable the button
	}
end

---------------------------------------------------------------------------
-- Hatching
---------------------------------------------------------------------------

local function notifyOdds(player: Player, eggId: string?)
	if oddsChanged then
		oddsChanged:Fire(player, eggId)
	end
end

-- Rolls `count` eggs into the inventory. Caller has already charged or been
-- paid. Synchronous: no yields. Returns the results for the reveal animation.
local function rollInto(player: Player, profile: PlayerData.Profile, eggId: string, egg: EggDef, count: number, paidMoney: boolean, force: boolean): { { [string]: any } }
	local state = eggState(profile)
	local results = {}
	local pityRank = if egg.pity then tierRank(egg, egg.pity.tier) else nil
	for _ = 1, count do
		local finals, _, _, paidLuck = computeFinals(player, profile, eggId, egg)
		local pick = Odds.Pick(finals, rng)
		if egg.pity and pityRank then
			state.Pity[eggId] = if pick.rank >= pityRank then 0 else (state.Pity[eggId] or 0) + 1
		end
		for _, tier in egg.tiers do
			for _, item in tier.items do
				if item.id == pick.id and item.once then
					state.Obtained[pick.id] = true
				end
			end
		end
		local _, _, uids = Inventory.Add(player, pick.id, 1, { paid = paidMoney or paidLuck, force = force })
		table.insert(results, { item = pick.id, tier = pick.tier, uid = if uids then uids[1] else nil })
	end
	state.Hatched += count
	PlayerData.MarkDirty(profile)
	notifyOdds(player, eggId)
	EggHatch.Hatched:Fire(player, eggId, results)
	return results
end

local function hatch(player: Player, eggId: string, count: number?): Net.Result
	local egg = eggs[eggId]
	local n = count or 1
	if not table.find(egg.hatchCounts or { 1 }, n) then
		return Net.fail("Invalid")
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local paid = isPaidEgg(egg)
	if paid and not Policy.CanBuyPaidRandom(player) then
		return Net.fail("Restricted", egg.restrictedNote)
	end
	local total = egg.price.amount * n
	if not Currency.CanAfford(player, egg.price.currency, total) then
		return Net.fail("NotEnough")
	end
	-- Every outcome is a unique item (asserted at Init), so n free slots are needed.
	local probe = egg.tiers[1].items[1].id
	local fits, code = Inventory.CanAdd(player, probe, n)
	if not fits then
		return Net.fail(code or "BagFull")
	end
	local finals = computeFinals(player, profile, eggId, egg)
	if #finals == 0 then
		return Net.fail("EggEmpty")
	end
	-- Checks passed; nothing below yields.
	if not Currency.Spend(player, egg.price.currency, total, `egg:{eggId}`) then
		return Net.fail("NotEnough")
	end
	return Net.ok(rollInto(player, profile, eggId, egg, n, paid, false))
end

---------------------------------------------------------------------------
-- Boosts and luck sources
---------------------------------------------------------------------------

-- Permanent or situational luck (passes, rebirths, friends). Must not yield.
function EggHatch.AddLuckSource(name: string, paid: boolean, get: (Player) -> number)
	table.insert(luckSources, { name = name, paid = paid, get = get })
end

-- Timed personal boost, saved in the profile (expires in real time, also offline).
-- Use from a Receipts custom grant. Synchronous.
function EggHatch.GrantTimedBoost(player: Player, multiplier: number, seconds: number, paid: boolean): boolean
	local profile = PlayerData.Get(player)
	if not profile or multiplier <= 1 or seconds <= 0 or multiplier ~= multiplier then
		return false
	end
	local list: { Boost } = eggState(profile).Boosts
	if #list >= 20 then
		return false
	end
	table.insert(list, { Mult = multiplier, Expires = os.time() + math.floor(seconds), Paid = paid })
	PlayerData.MarkDirty(profile)
	return true
end

-- For Receipts.SetPromptCheck on luck products: never sell a boost that does nothing.
function EggHatch.IsAtMaxLuck(player: Player): boolean
	local luck = EggHatch.GetEffectiveLuck(player)
	return luck >= maxLuck
end

-- Server-wide boost (e.g. bought by one player for everyone). Paid server luck
-- is excluded for restricted players by GetEffectiveLuck.
function EggHatch.SetServerLuck(multiplier: number, seconds: number, paid: boolean)
	serverLuck = { Mult = multiplier, Expires = os.time() + math.floor(seconds), Paid = paid }
end

-- Paid hatch from a Developer Product (Receipts custom grant): no currency
-- charge, bag capacity forced because the player already paid.
function EggHatch.GrantPaidHatch(player: Player, eggId: string, count: number): boolean
	local egg = eggs[eggId]
	local profile = PlayerData.Get(player)
	if not egg or not profile then
		return false
	end
	if #computeFinals(player, profile, eggId, egg) == 0 then
		return false
	end
	rollInto(player, profile, eggId, egg, count, true, true)
	return true
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

local function refreshLuck(player: Player)
	if not PlayerData.Get(player) then
		return
	end
	local luck = EggHatch.GetEffectiveLuck(player)
	if lastLuck[player] ~= luck then
		lastLuck[player] = luck
		player:SetAttribute("EffectiveLuck", luck)
		notifyOdds(player, nil)
	end
end

function EggHatch.Init(config: Config)
	assert(config.maxLuck >= 1 and config.maxLuck < math.huge, "EggHatch: maxLuck must be >= 1")
	maxLuck = config.maxLuck
	for eggId, egg in config.eggs do
		Odds.Validate(`Egg {eggId}`, egg.tiers)
		assert(Currency.Exists(egg.price.currency), `Egg {eggId}: unknown currency {egg.price.currency}`)
		assert(Currency.isWhole(egg.price.amount) and egg.price.amount >= 1, `Egg {eggId}: bad price`)
		for _, tier in egg.tiers do
			for _, item in tier.items do
				local def = Inventory.GetDef(item.id)
				assert(def, `Egg {eggId}: item {item.id} is not in the Inventory catalog`)
				assert(not (def :: Inventory.ItemDef).stackable, `Egg {eggId}: item {item.id} must be a unique (non-stackable) item`)
			end
		end
		if egg.pity then
			assert(tierRank(egg, egg.pity.tier), `Egg {eggId}: pity tier {egg.pity.tier} not found`)
			assert(egg.pity.rolls >= 2 and math.floor(egg.pity.rolls) == egg.pity.rolls, `Egg {eggId}: pity rolls must be a whole number >= 2`)
		end
		for _, n in egg.hatchCounts or { 1 } do
			assert(n >= 1 and n <= 10 and math.floor(n) == n, `Egg {eggId}: hatch counts 1..10`)
		end
		-- The flattened odds must sum to 100% (allowing float error).
		local finals = Odds.Flatten(egg.tiers)
		local sum = 0
		for _, f in finals do
			sum += f.p
		end
		assert(math.abs(sum - 1) < 1e-9, `Egg {eggId}: odds sum to {sum * 100}%`)
		eggs[eggId] = egg
	end

	PlayerData.RegisterSlice("Eggs", function()
		return { Pity = {}, Obtained = {}, Boosts = {}, Hatched = 0 }
	end)

	oddsChanged = Net.Push("Eggs.OddsChanged")
	Net.Handle("Eggs.Hatch", {
		rate = { burst = 4, perSecond = 2 },
		args = { T.key(eggs), T.optional(T.integer(1, 10)) },
		handler = hatch,
	})
	Net.Handle("Eggs.GetOdds", {
		rate = { burst = 6, perSecond = 2 },
		args = { T.key(eggs) },
		handler = function(player: Player, eggId: string): Net.Result
			local odds = EggHatch.GetDisplayOdds(player, eggId)
			return if odds then Net.ok(odds) else Net.fail("NotReady")
		end,
	})
	Net.Handle("Eggs.PreviewBoost", {
		rate = { burst = 4, perSecond = 1 },
		args = { T.key(eggs), T.number(1, 1000) },
		handler = function(player: Player, eggId: string, multiplier: number): Net.Result
			local preview = EggHatch.PreviewBoost(player, eggId, multiplier, true)
			return if preview then Net.ok(preview) else Net.fail("NotReady")
		end,
	})

	PlayerData.Loaded:Connect(refreshLuck)
	Policy.Changed:Connect(refreshLuck)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastLuck[player] = nil
	end)
	-- Boost expiry and server luck changes: re-check once a second (cheap, bounded by player count).
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				refreshLuck(player)
			end
		end
	end)
end

return EggHatch
