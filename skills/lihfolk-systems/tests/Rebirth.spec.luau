--!nonstrict
-- LihFolk Systems spec: Rebirth. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("LihFolk")

local Rebirth = require(Server.Rebirth)

local function bruteMax(n, coins, base, growth, cap)
	local k = 0
	while k < cap and Rebirth.totalCost(n, k + 1, base, growth) <= coins do
		k += 1
	end
	return k
end

return function()
	describe("Rebirth costs", function()
		it("single cost is base * growth^n", function()
			expect(Rebirth.totalCost(0, 1, 100, 1.5)).to.equal(100)
			expect(Rebirth.totalCost(2, 1, 100, 1.5)).to.equal(225)
			expect(Rebirth.totalCost(3, 4, 100, 1)).to.equal(400)
		end)
		it("bulk max agrees with a brute-force search", function()
			local rng = Random.new(3)
			for _ = 1, 200 do
				local n = rng:NextInteger(0, 40)
				local coins = rng:NextInteger(0, 10 ^ 9)
				local growth = rng:NextNumber(1, 2)
				local fast = Rebirth.maxAffordable(n, coins, 1000, growth, 1000)
				expect(fast).to.equal(bruteMax(n, coins, 1000, growth, 1000))
				expect(Rebirth.totalCost(n, fast, 1000, growth) <= coins).to.equal(true)
			end
		end)
		it("respects the cap and overflow", function()
			expect(Rebirth.maxAffordable(0, 10 ^ 12, 1, 1, 50)).to.equal(50)
			expect(Rebirth.totalCost(10000, 1, 100, 2)).to.equal(math.huge)
		end)
	end)
end
