--!nonstrict
-- LihFolk Systems spec: Policy. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("LihFolk")

local Policy = require(Server.Policy)

return function()
	describe("Policy.interpret (fail closed)", function()
		it("restricts on nil, errors and missing keys", function()
			local none = Policy.interpret(nil)
			expect(none.paidRandomAllowed).to.equal(false)
			expect(none.paidTradingAllowed).to.equal(false)
			local missing = Policy.interpret({})
			expect(missing.paidRandomAllowed).to.equal(false)
			expect(missing.paidTradingAllowed).to.equal(false)
		end)
		it("allows only on exact booleans", function()
			local open = Policy.interpret({ ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true })
			expect(open.paidRandomAllowed).to.equal(true)
			expect(open.paidTradingAllowed).to.equal(true)
			local stringy = Policy.interpret({ ArePaidRandomItemsRestricted = "false", IsPaidItemTradingAllowed = "true" })
			expect(stringy.paidRandomAllowed).to.equal(false)
			expect(stringy.paidTradingAllowed).to.equal(false)
		end)
		it("keeps the two gates separate", function()
			local mixed = Policy.interpret({ ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = false })
			expect(mixed.paidRandomAllowed).to.equal(true)
			expect(mixed.paidTradingAllowed).to.equal(false)
		end)
	end)
end
