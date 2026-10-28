--!nonstrict
-- LihFolk Systems spec: Codes. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("LihFolk")

local Codes = require(Server.Codes)

return function()
	describe("Codes.normalise", function()
		it("uppercases and strips whitespace", function()
			expect(Codes.normalise(" release ")).to.equal("RELEASE")
			expect(Codes.normalise("Spooky 2026")).to.equal("SPOOKY2026")
		end)
		it("rejects junk before doing work", function()
			expect(Codes.normalise(string.rep("A", 65))).to.equal(nil)
			expect(Codes.normalise("AB")).to.equal(nil)
			expect(Codes.normalise("CODE!")).to.equal(nil)
			expect(Codes.normalise(42)).to.equal(nil)
		end)
	end)
	describe("Codes.check", function()
		local def = { reward = {}, startsAt = 100, expiresAt = 200 }
		it("hides upcoming codes and expires on time", function()
			expect(Codes.check(def, nil, 50)).to.equal("NotFound")
			expect(Codes.check(def, nil, 150)).to.equal(nil)
			expect(Codes.check(def, nil, 200)).to.equal("Expired")
		end)
		it("is one use per player", function()
			expect(Codes.check(def, 120, 150)).to.equal("AlreadyRedeemed")
			expect(Codes.check(nil, nil, 150)).to.equal("NotFound")
		end)
	end)
end
