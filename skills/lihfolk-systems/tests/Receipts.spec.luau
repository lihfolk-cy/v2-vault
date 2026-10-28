--!nonstrict
-- LihFolk Systems spec: Receipts. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("LihFolk")

local Receipts = require(Server.Receipts)

return function()
	describe("Receipts router", function()
		it("leaves receipts for unknown products pending", function()
			local decision = Receipts._processReceipt({ ProductId = -12345, PlayerId = 1, PurchaseId = "x", CurrencySpent = 10 })
			expect(decision).to.equal(Enum.ProductPurchaseDecision.NotProcessedYet)
		end)
	end)
	-- Idempotency (grant once, PurchaseId in the same write, granted only after
	-- the save) is covered by PlayerData.spec > purchaseCore.
end
