--!nonstrict
-- LihFolk Systems spec: Shop. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("LihFolk")

local Shop = require(Server.Shop)

return function()
	describe("Shop pure helpers", function()
		it("prices quantities exactly or refuses", function()
			expect(Shop.totalPrice(250, 4)).to.equal(1000)
			expect(Shop.totalPrice(2 ^ 52, 4)).to.equal(nil)
		end)
		it("scales nested rewards without mutating the config", function()
			local base = { kind = "bundle", rewards = { { kind = "item", item = "Potion", count = 1 } } }
			local scaled = Shop.scaleReward(base, 3)
			expect(scaled.rewards[1].count).to.equal(3)
			expect(base.rewards[1].count).to.equal(1)
		end)
	end)
end
