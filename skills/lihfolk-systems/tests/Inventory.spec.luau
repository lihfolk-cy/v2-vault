--!nonstrict
-- LihFolk Systems spec: Inventory. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("LihFolk")

local Inventory = require(Server.Inventory)
local Pure = Inventory.Pure

local CATALOG = {
	Potion = { name = "Potion", stackable = true, maxStack = 5 },
	Dog = { name = "Dog", stackable = false, equippable = true },
}

local function newInv()
	return { Stacks = {}, Uniques = {}, Equipped = {} }
end

local n = 0
local function uid()
	n += 1
	return "uid" .. n
end

return function()
	describe("Inventory.Pure", function()
		it("checks everything before changing anything", function()
			local inv = newInv()
			expect((Pure.canAdd(inv, CATALOG, 2, { Dog = 2 }))).to.equal(true)
			local ok, code = Pure.canAdd(inv, CATALOG, 2, { Dog = 3 })
			expect(ok).to.equal(false)
			expect(code).to.equal("BagFull")
			expect(select(2, Pure.canAdd(inv, CATALOG, 2, { Potion = 6 }))).to.equal("StackFull")
			expect(select(2, Pure.canAdd(inv, CATALOG, 2, { Nope = 1 }))).to.equal("UnknownItem")
			expect(select(2, Pure.canAdd(inv, CATALOG, 2, { Dog = 0 / 0 }))).to.equal("BadCount")
			expect(select(2, Pure.canAdd(inv, CATALOG, 2, { Dog = 1.5 }))).to.equal("BadCount")
		end)
		it("adds uniques with stable ids and provenance", function()
			local inv = newInv()
			local uids = Pure.add(inv, CATALOG.Dog, "Dog", 2, true, 100, uid)
			expect(#uids).to.equal(2)
			expect(inv.Uniques[uids[1]].Paid).to.equal(true)
			expect(Pure.uniqueCount(inv)).to.equal(2)
		end)
		it("removes stacks exactly and uniques with their equip flag", function()
			local inv = newInv()
			Pure.add(inv, CATALOG.Potion, "Potion", 3, false, 0, uid)
			expect(Pure.removeStack(inv, "Potion", 4)).to.equal(false)
			expect(Pure.removeStack(inv, "Potion", 3)).to.equal(true)
			expect(inv.Stacks.Potion).to.equal(nil)
			local ids = Pure.add(inv, CATALOG.Dog, "Dog", 1, false, 0, uid)
			inv.Equipped[ids[1]] = true
			expect(Pure.removeUnique(inv, ids[1])).to.be.ok()
			expect(inv.Equipped[ids[1]]).to.equal(nil)
		end)
		it("snapshots as plain arrays", function()
			local inv = newInv()
			Pure.add(inv, CATALOG.Dog, "Dog", 1, false, 0, uid)
			local snap = Pure.snapshot(inv)
			expect(#snap.uniques).to.equal(1)
			expect(snap.uniques[1].item).to.equal("Dog")
		end)
	end)
end
