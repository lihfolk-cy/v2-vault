--!nonstrict
-- LihFolk Systems spec: Leaderboard. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("LihFolk")

local Leaderboard = require(Server.Leaderboard)

local MONDAY = 1792972800 -- 2026-10-26 00:00:00 UTC

return function()
	describe("Leaderboard", function()
		it("weeks start Monday 00:00 UTC", function()
			expect(Leaderboard.weekIndex(MONDAY)).to.equal(2964)
			expect(Leaderboard.weekIndex(MONDAY - 1)).to.equal(2963)
			expect(Leaderboard.storeNameFor({ storeName = "LB", period = "weekly" }, MONDAY)).to.equal("LB_W2964")
			expect(Leaderboard.storeNameFor({ storeName = "LB", period = "all" }, MONDAY)).to.equal("LB")
		end)
		it("log encoding keeps order for huge values", function()
			local a = Leaderboard.LogEncode(1e20)
			local b = Leaderboard.LogEncode(2e20)
			expect(b > a).to.equal(true)
			expect(a < 2 ^ 53).to.equal(true)
			expect(Leaderboard.LogDecode(a)).to.be.near(1e20, 1e12)
		end)
		it("only stores finite non-negative integers", function()
			local def = { storeName = "LB", period = "all" }
			expect(Leaderboard.toStored(def, 12.7)).to.equal(12)
			expect(Leaderboard.toStored(def, 0 / 0)).to.equal(nil)
			expect(Leaderboard.toStored(def, -5)).to.equal(nil)
			expect(Leaderboard.toStored(def, math.huge)).to.equal(nil)
		end)
	end)
end
