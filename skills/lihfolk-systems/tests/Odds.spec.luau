--!nonstrict
-- LihFolk Systems spec: Odds. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("LihFolk")

local Odds = require(Shared.Odds)

local TIERS = {
	{ name = "Common", weight = 70, items = { { id = "A", weight = 1 }, { id = "B", weight = 1 } } },
	{ name = "Rare", weight = 25, lucky = true, items = { { id = "C", weight = 1 } } },
	{ name = "Mythic", weight = 5, lucky = true, items = { { id = "D", weight = 3 }, { id = "E", weight = 1, once = true } } },
}

local function sum(finals)
	local s = 0
	for _, f in finals do
		s += f.p
	end
	return s
end

local function find(finals, id)
	for _, f in finals do
		if f.id == id then
			return f.p
		end
	end
	return nil
end

return function()
	describe("Odds.Flatten", function()
		it("flattens tiers into final outcomes summing to 1", function()
			local finals = Odds.Flatten(TIERS)
			expect(sum(finals)).to.be.near(1, 1e-12)
			expect(find(finals, "A")).to.be.near(0.35, 1e-12)
			expect(find(finals, "D")).to.be.near(0.0375, 1e-12)
		end)
		it("luck raises lucky tiers and renormalises", function()
			local finals = Odds.Flatten(TIERS, { luck = 2 })
			expect(sum(finals)).to.be.near(1, 1e-12)
			expect(find(finals, "C")).to.be.near(50 / 130, 1e-12)
		end)
		it("minRank (pity) zeroes lower tiers", function()
			local finals = Odds.Flatten(TIERS, { minRank = 3 })
			expect(find(finals, "A")).to.equal(0)
			expect(find(finals, "D")).to.be.near(0.75, 1e-12)
			expect(sum(finals)).to.be.near(1, 1e-12)
		end)
		it("excluded once-items renormalise; an emptied tier drops to zero", function()
			local finals, total = Odds.Flatten(TIERS, { excluded = { E = true } })
			expect(find(finals, "E")).to.equal(0)
			expect(sum(finals)).to.be.near(1, 1e-12)
			local _, emptyTotal = Odds.Flatten({ { name = "Only", weight = 1, items = { { id = "X", weight = 1 } } } }, { excluded = { X = true } })
			expect(emptyTotal).to.equal(0)
			expect(total > 0).to.equal(true)
		end)
	end)

	describe("Odds.PickWith", function()
		it("never returns an unreachable outcome on the float tail", function()
			local finals = Odds.Flatten(TIERS, { minRank = 1, excluded = { E = true } })
			local pick = Odds.PickWith(finals, 0.999999999999)
			expect(pick.p > 0).to.equal(true)
		end)
		it("matches the displayed odds (chi-square, 200k rolls)", function()
			local finals = Odds.Flatten(TIERS, { luck = 1.5 })
			local rng = Random.new(12345)
			local counts = {}
			local n = 200000
			for _ = 1, n do
				local id = Odds.Pick(finals, rng).id
				counts[id] = (counts[id] or 0) + 1
			end
			local chi, dof = Odds.ChiSquare(finals, counts, n)
			expect(chi / dof < 4).to.equal(true)
		end)
	end)

	describe("Odds.Format", function()
		it("formats without ever showing a non-zero chance as 0%", function()
			expect(Odds.Format(25)).to.equal("25%")
			expect(Odds.Format(33.333333)).to.equal("33.3333%")
			expect(Odds.Format(0.0012345)).to.equal("0.0012345%")
			expect(Odds.Format(0.00002)).to.equal("0.00002%")
			expect(Odds.Format(1e-12)).to.never.equal("0%")
			expect(Odds.Format(0)).to.equal("0%")
			expect(Odds.Format(100)).to.equal("100%")
		end)
		it("OneIn is a supplement", function()
			expect(Odds.OneIn(0.001)).to.equal("1 in 1,000")
			expect(Odds.OneIn(0)).to.equal("never")
		end)
		it("pity effective rate matches the vault worked example", function()
			-- p = 1%, guarantee at 90: about 1.68% per roll
			expect(Odds.PityEffectiveRate(0.01, 90)).to.be.near(0.0168, 0.0002)
			expect(Odds.AtLeastOne(0.005, 10)).to.be.near(0.0489, 0.0002)
		end)
	end)

	describe("Odds.Validate", function()
		it("rejects duplicate ids and bad weights", function()
			expect(function()
				Odds.Validate("dup", { { name = "T", weight = 1, items = { { id = "A", weight = 1 }, { id = "A", weight = 1 } } } })
			end).to.throw("appears twice")
			expect(function()
				Odds.Validate("nan", { { name = "T", weight = 0 / 0, items = { { id = "A", weight = 1 } } } })
			end).to.throw()
		end)
	end)
end
