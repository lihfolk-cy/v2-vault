--!nonstrict
-- LihFolk Systems spec: Quests. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("LihFolk")

local Quests = require(Server.Quests)

local Q1 = { id = "Q1", title = "", reward = {}, objectives = { { kind = "Collect", target = "Coin", amount = 10 } } }
local Q2 = { id = "Q2", title = "", reward = {}, requires = { "Q1" }, objectives = {
	{ kind = "Hatch", target = "*", amount = 2 },
	{ kind = "Defeat", target = "Slime", amount = 1 },
} }

return function()
	describe("Quests", function()
		it("activates by requirements", function()
			expect(Quests.isActive(Q1, {})).to.equal(true)
			expect(Quests.isActive(Q2, {})).to.equal(false)
			expect(Quests.isActive(Q2, { Q1 = 1 })).to.equal(true)
			expect(Quests.isActive(Q1, { Q1 = 1 })).to.equal(false)
		end)
		it("clamps progress, matches wildcards and keeps arrays dense", function()
			local progress = {}
			expect(Quests.applyProgress(Q2, progress, "Defeat", "Slime", 5)).to.equal(true)
			expect(progress[1]).to.equal(0)
			expect(progress[2]).to.equal(1)
			expect(Quests.applyProgress(Q2, progress, "Hatch", "Basic", 3)).to.equal(true)
			expect(progress[1]).to.equal(2)
			expect(Quests.applyProgress(Q2, progress, "Hatch", "Basic", 1)).to.equal(false)
			expect(Quests.isComplete(Q2, progress)).to.equal(true)
		end)
		it("is not complete without progress", function()
			expect(Quests.isComplete(Q1, nil)).to.equal(false)
		end)
	end)
end
