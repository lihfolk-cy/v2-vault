--!nonstrict
-- LihFolk Systems spec: Currency. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("LihFolk")

local Currency = require(Server.Currency)

return function()
	describe("Currency pure helpers", function()
		it("adds whole amounts and clamps at max", function()
			expect(Currency.applyAdd(10, 5, 100)).to.equal(15)
			expect(Currency.applyAdd(98, 5, 100)).to.equal(100)
		end)
		it("refuses NaN, infinity, negatives, zero and fractions", function()
			expect(Currency.applyAdd(10, 0 / 0, 100)).to.equal(nil)
			expect(Currency.applyAdd(10, math.huge, 100)).to.equal(nil)
			expect(Currency.applyAdd(10, -5, 100)).to.equal(nil)
			expect(Currency.applyAdd(10, 0, 100)).to.equal(nil)
			expect(Currency.applyAdd(10, 1.5, 100)).to.equal(nil)
		end)
		it("spends only what is affordable", function()
			expect(Currency.applySpend(10, 10)).to.equal(0)
			expect(Currency.applySpend(10, 11)).to.equal(nil)
			expect(Currency.applySpend(10, -1)).to.equal(nil)
		end)
		it("combines multipliers safely with a cap", function()
			expect(Currency.combineMultipliers({ 2, 1.5 }, 1000)).to.equal(3)
			expect(Currency.combineMultipliers({ 2, 0 / 0, math.huge }, 1000)).to.equal(2)
			expect(Currency.combineMultipliers({ 100, 100 }, 1000)).to.equal(1000)
		end)
	end)
end
