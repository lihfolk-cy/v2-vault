--!nonstrict
-- LihFolk Systems spec: Rewards. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("LihFolk")

local Rewards = require(Server.Rewards)

return function()
	describe("Rewards.collectItems", function()
		it("totals items across nested bundles", function()
			local totals = {}
			Rewards.collectItems({ kind = "bundle", rewards = {
				{ kind = "item", item = "Potion", count = 2 },
				{ kind = "currency", currency = "Coins", amount = 5 },
				{ kind = "bundle", rewards = { { kind = "item", item = "Potion", count = 3 } } },
			} }, totals)
			expect(totals.Potion).to.equal(5)
			expect(totals.Coins).to.equal(nil)
		end)
	end)
end
