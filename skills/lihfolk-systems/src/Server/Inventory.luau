--!strict
-- LihFolk Systems: Inventory
-- Install: ServerScriptService/LihFolk/Inventory (ModuleScript)
--
-- Stackable items (potions, ores) as counts; unique items (pets, weapons)
-- with a stable GUID each, a provenance flag (Paid) set at grant time, and
-- an equipped set. Never equip or trade by array index.
-- All mutations are synchronous and all-or-nothing: CanAdd first, then Add.
-- Remotes: Inventory.Snapshot, Inventory.Equip, Inventory.Unequip.
-- Push:    Inventory.Changed (full snapshot, coalesced to one per frame).
-- Status: reviewed, not run in Studio.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local PlayerData = require(script.Parent.PlayerData)
local Policy = require(script.Parent.Policy)

local T = Net.T

export type ItemDef = {
	name: string,
	stackable: boolean,
	maxStack: number?, -- stackable only, default 9999
	equippable: boolean?, -- unique only
	tradable: boolean?, -- default false
}

export type Config = {
	items: { [string]: ItemDef },
	uniqueCapacity: number, -- max unique items held
	maxEquipped: number, -- max uniques equipped at once
}

export type Unique = { Item: string, Paid: boolean, Created: number, Level: number }

export type Inv = {
	Stacks: { [string]: number },
	Uniques: { [string]: Unique },
	Equipped: { [string]: boolean },
}

export type AddOptions = { paid: boolean?, force: boolean? }

local Inventory = {}
Inventory.Changed = Signal.new() -- (player)

local items: { [string]: ItemDef } = {}
local capacity = 100
local maxEquipped = 3
local changedPush: Net.Push? = nil
local pendingPush: { [Player]: boolean } = {}

---------------------------------------------------------------------------
-- Pure helpers (exported for tests). They take the inventory table directly.
---------------------------------------------------------------------------

local Pure = {}
Inventory.Pure = Pure

function Pure.uniqueCount(inv: Inv): number
	local n = 0
	for _ in inv.Uniques do
		n += 1
	end
	return n
end

-- adds: itemId -> count. Checks everything before anything changes.
function Pure.canAdd(inv: Inv, catalog: { [string]: ItemDef }, cap: number, adds: { [string]: number }): (boolean, string?)
	local newUniques = 0
	for itemId, count in adds do
		local def = catalog[itemId]
		if not def then
			return false, "UnknownItem"
		end
		if type(count) ~= "number" or count ~= count or count < 1 or math.floor(count) ~= count or count > 1e6 then
			return false, "BadCount"
		end
		if def.stackable then
			if (inv.Stacks[itemId] or 0) + count > (def.maxStack or 9999) then
				return false, "StackFull"
			end
		else
			newUniques += count
		end
	end
	if newUniques > 0 and Pure.uniqueCount(inv) + newUniques > cap then
		return false, "BagFull"
	end
	return true, nil
end

-- Adds without capacity checks (call canAdd first unless force-granting a paid receipt).
-- Returns the new uids for unique items.
function Pure.add(inv: Inv, def: ItemDef, itemId: string, count: number, paid: boolean, now: number, newUid: () -> string): { string }
	local uids = {}
	if def.stackable then
		inv.Stacks[itemId] = math.min((inv.Stacks[itemId] or 0) + count, def.maxStack or 9999)
	else
		for _ = 1, count do
			local uid = newUid()
			inv.Uniques[uid] = { Item = itemId, Paid = paid, Created = now, Level = 1 }
			table.insert(uids, uid)
		end
	end
	return uids
end

function Pure.removeStack(inv: Inv, itemId: string, count: number): boolean
	local have = inv.Stacks[itemId] or 0
	if type(count) ~= "number" or count < 1 or math.floor(count) ~= count or count > have then
		return false
	end
	local left = have - count
	inv.Stacks[itemId] = if left > 0 then left else nil
	return true
end

function Pure.removeUnique(inv: Inv, uid: string): Unique?
	local unique = inv.Uniques[uid]
	if not unique then
		return nil
	end
	inv.Uniques[uid] = nil
	inv.Equipped[uid] = nil
	return unique
end

function Pure.equippedCount(inv: Inv): number
	local n = 0
	for _ in inv.Equipped do
		n += 1
	end
	return n
end

-- Client view: plain arrays, no internal tables shared.
function Pure.snapshot(inv: Inv): { [string]: any }
	local stacks = {}
	for itemId, count in inv.Stacks do
		table.insert(stacks, { item = itemId, count = count })
	end
	local uniques = {}
	for uid, unique in inv.Uniques do
		table.insert(uniques, { uid = uid, item = unique.Item, paid = unique.Paid, level = unique.Level, equipped = inv.Equipped[uid] == true })
	end
	return { stacks = stacks, uniques = uniques }
end

---------------------------------------------------------------------------
-- Internals
---------------------------------------------------------------------------

local function invOf(profile: PlayerData.Profile): Inv
	return profile.Data.Inventory :: Inv
end

local function newUid(): string
	return HttpService:GenerateGUID(false)
end

local function schedulePush(player: Player)
	Inventory.Changed:Fire(player)
	if pendingPush[player] then
		return
	end
	pendingPush[player] = true
	task.defer(function()
		pendingPush[player] = nil
		local profile = PlayerData.Get(player)
		if profile and changedPush then
			changedPush:Fire(player, Pure.snapshot(invOf(profile)))
		end
	end)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Inventory.Exists(itemId: string): boolean
	return items[itemId] ~= nil
end

function Inventory.GetDef(itemId: string): ItemDef?
	return items[itemId]
end

function Inventory.CanAddMany(player: Player, adds: { [string]: number }): (boolean, string?)
	local profile = PlayerData.Get(player)
	if not profile then
		return false, "NotReady"
	end
	return Pure.canAdd(invOf(profile), items, capacity, adds)
end

function Inventory.CanAdd(player: Player, itemId: string, count: number): (boolean, string?)
	return Inventory.CanAddMany(player, { [itemId] = count })
end

-- Adds items. Returns (ok, code, uids). With options.force the capacity check
-- is skipped: use it only for already-paid receipts, never for free rewards.
function Inventory.Add(player: Player, itemId: string, count: number, options: AddOptions?): (boolean, string?, { string }?)
	local profile = PlayerData.Get(player)
	local def = items[itemId]
	if not profile or not def then
		return false, if profile then "UnknownItem" else "NotReady", nil
	end
	local inv = invOf(profile)
	local force = options ~= nil and options.force == true
	if force then
		if type(count) ~= "number" or count < 1 or math.floor(count) ~= count or count > 1e6 then
			return false, "BadCount", nil
		end
	else
		local ok, code = Pure.canAdd(inv, items, capacity, { [itemId] = count })
		if not ok then
			return false, code, nil
		end
	end
	local paid = options ~= nil and options.paid == true
	local uids = Pure.add(inv, def, itemId, count, paid, os.time(), newUid)
	PlayerData.MarkDirty(profile)
	schedulePush(player)
	return true, "Ok", uids
end

function Inventory.RemoveStack(player: Player, itemId: string, count: number): boolean
	local profile = PlayerData.Get(player)
	if not profile then
		return false
	end
	if not Pure.removeStack(invOf(profile), itemId, count) then
		return false
	end
	PlayerData.MarkDirty(profile)
	schedulePush(player)
	return true
end

function Inventory.RemoveUnique(player: Player, uid: string): Unique?
	local profile = PlayerData.Get(player)
	if not profile then
		return nil
	end
	local removed = Pure.removeUnique(invOf(profile), uid)
	if removed then
		PlayerData.MarkDirty(profile)
		schedulePush(player)
	end
	return removed
end

function Inventory.Count(player: Player, itemId: string): number
	local profile = PlayerData.Get(player)
	if not profile then
		return 0
	end
	local inv = invOf(profile)
	local def = items[itemId]
	if def and def.stackable then
		return inv.Stacks[itemId] or 0
	end
	local n = 0
	for _, unique in inv.Uniques do
		if unique.Item == itemId then
			n += 1
		end
	end
	return n
end

function Inventory.GetUnique(player: Player, uid: string): Unique?
	local profile = PlayerData.Get(player)
	return if profile then invOf(profile).Uniques[uid] else nil
end

function Inventory.GetEquipped(player: Player): { string }
	local profile = PlayerData.Get(player)
	local out = {}
	if profile then
		for uid in invOf(profile).Equipped do
			table.insert(out, uid)
		end
	end
	return out
end

-- Trading gate, separate from the paid-random gate: item must be tradable,
-- and a Paid item needs IsPaidItemTradingAllowed for this player.
-- A trade system must also check the OTHER player and use a trade ledger
-- (vault: Trading Systems Without Duplication).
function Inventory.CanTrade(player: Player, uid: string): (boolean, string?)
	local unique = Inventory.GetUnique(player, uid)
	if not unique then
		return false, "NotOwned"
	end
	local def = items[unique.Item]
	if not def or def.tradable ~= true then
		return false, "NotTradable"
	end
	if unique.Paid and not Policy.CanTradePaid(player) then
		return false, "PolicyRestricted"
	end
	return true, nil
end

local function equip(player: Player, uid: string): Net.Result
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local inv = invOf(profile)
	local unique = inv.Uniques[uid]
	if not unique then
		return Net.fail("NotOwned")
	end
	local def = items[unique.Item]
	if not def or def.equippable ~= true then
		return Net.fail("NotEquippable")
	end
	if inv.Equipped[uid] then
		return Net.ok()
	end
	if Pure.equippedCount(inv) >= maxEquipped then
		return Net.fail("EquipFull")
	end
	inv.Equipped[uid] = true
	PlayerData.MarkDirty(profile)
	schedulePush(player)
	return Net.ok()
end

local function unequip(player: Player, uid: string): Net.Result
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local inv = invOf(profile)
	if inv.Equipped[uid] then
		inv.Equipped[uid] = nil
		PlayerData.MarkDirty(profile)
		schedulePush(player)
	end
	return Net.ok()
end

function Inventory.Init(config: Config)
	for itemId, def in config.items do
		assert(string.match(itemId, "^[%w_]+$") and #itemId <= 48, `Inventory: bad item id '{itemId}'`)
		assert(type(def.name) == "string" and type(def.stackable) == "boolean", `Inventory {itemId}: name and stackable required`)
		assert(not (def.stackable and def.equippable), `Inventory {itemId}: stackable items cannot be equippable`)
		items[itemId] = def
	end
	assert(config.uniqueCapacity >= 1 and config.maxEquipped >= 0, "Inventory: bad capacity")
	capacity = config.uniqueCapacity
	maxEquipped = config.maxEquipped

	PlayerData.RegisterSlice("Inventory", function()
		return { Stacks = {}, Uniques = {}, Equipped = {} }
	end)

	changedPush = Net.Push("Inventory.Changed")
	Net.Handle("Inventory.Snapshot", {
		rate = { burst = 3, perSecond = 1 },
		args = {},
		handler = function(player: Player): Net.Result
			local profile = PlayerData.Get(player)
			if not profile then
				return Net.fail("NotReady")
			end
			return Net.ok(Pure.snapshot(invOf(profile)))
		end,
	})
	Net.Handle("Inventory.Equip", {
		rate = { burst = 6, perSecond = 3 },
		args = { T.guid },
		handler = equip,
	})
	Net.Handle("Inventory.Unequip", {
		rate = { burst = 6, perSecond = 3 },
		args = { T.guid },
		handler = unequip,
	})

	PlayerData.Loaded:Connect(function(player: Player)
		schedulePush(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pendingPush[player] = nil
	end)
end

return Inventory
