--!nonstrict
-- LihFolk Systems spec: EggHatch. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Server = ServerScriptService:WaitForChild("LihFolk")

local EggHatch = require(Server.EggHatch)
local Odds = require(Shared.Odds)

local EGG = {
	name = "Test",
	price = { currency = "Coins", amount = 1 },
	tiers = {
		{ name = "Common", weight = 90, items = { { id = "A", weight = 1 } } },
		{ name = "Legendary", weight = 9, lucky = true, items = { { id = "L", weight = 1 } } },
		{ name = "Mythic", weight = 1, lucky = true, items = { { id = "M", weight = 1, once = true } } },
	},
	pity = { tier = "Legendary", rolls = 10 },
}

local function p(finals, id)
	for _, f in finals do
		if f.id == id then
			return f.p
		end
	end
	return nil
end

return function()
	describe("EggHatch.finalsFor (the one source for roll and display)", function()
		it("uses base odds before the pity threshold", function()
			local finals, pity = EggHatch.finalsFor(EGG, 1, 0, {})
			expect(pity).to.equal(false)
			expect(p(finals, "A")).to.be.near(0.9, 1e-12)
		end)
		it("guarantees Legendary-or-better on roll number `rolls`", function()
			local finals, pity = EggHatch.finalsFor(EGG, 1, 9, {})
			expect(pity).to.equal(true)
			expect(p(finals, "A")).to.equal(0)
			expect(Odds.ChanceAtOrAbove(finals, 2)).to.be.near(1, 1e-12)
		end)
		it("removes obtained once-items and renormalises", function()
			local finals = EggHatch.finalsFor(EGG, 1, 0, { M = true })
			expect(p(finals, "M")).to.equal(0)
			expect(p(finals, "A")).to.be.near(90 / 99, 1e-12)
		end)
		it("luck changes the displayed AND rolled odds identically", function()
			local finals = EggHatch.finalsFor(EGG, 2, 0, {})
			expect(p(finals, "L")).to.be.near(18 / 110, 1e-12)
			local rng = Random.new(7)
			local counts = {}
			for _ = 1, 100000 do
				local id = Odds.Pick(finals, rng).id
				counts[id] = (counts[id] or 0) + 1
			end
			local chi, dof = Odds.ChiSquare(finals, counts, 100000)
			expect(chi / dof < 4).to.equal(true)
		end)
	end)

	describe("EggHatch.combineLuck", function()
		it("multiplies valid factors and respects the cap", function()
			expect(EggHatch.combineLuck({ 2, 1.5 }, 10)).to.equal(3)
			expect(EggHatch.combineLuck({ 4, 4 }, 10)).to.equal(10)
			expect(EggHatch.combineLuck({ 0.5, 0 / 0 }, 10)).to.equal(1)
		end)
	end)
end
