--!nonstrict
-- LihFolk Systems spec: PlayerData. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("LihFolk")

local PlayerData = require(Server.PlayerData)

local function makeData()
	return { Currency = { Balances = { Coins = 0 }, Earned = {} }, Inventory = { Stacks = {}, Uniques = {} } }
end

local function fakeProfile()
	return {
		Data = { Coins = 0 },
		Meta = { Created = 0, Receipts = {}, ReceiptOrder = {}, PurchaseLog = {} },
		Unconfirmed = {},
		Dirty = false,
	}
end

local function entry(id)
	return { Id = id, Product = "Gems100", Robux = 99, Time = 1 }
end

return function()
	describe("PlayerData.prepare", function()
		it("treats nil and session-only records as new players", function()
			local record = PlayerData.prepare(nil, 1, {}, makeData)
			expect(record.Schema).to.equal(1)
			expect(record.Data.Currency.Balances.Coins).to.equal(0)
			local fromClaim = PlayerData.prepare({ Session = { Token = "x" } }, 1, {}, makeData)
			expect(fromClaim).to.be.ok()
		end)
		it("refuses corrupt and newer data instead of defaulting", function()
			local a, reasonA = PlayerData.prepare("garbage", 1, {}, makeData)
			expect(a).to.equal(nil)
			expect(reasonA).to.equal("corrupt")
			local b, reasonB = PlayerData.prepare({ Schema = 3, Data = {} }, 2, {}, makeData)
			expect(b).to.equal(nil)
			expect(reasonB).to.equal("newer")
		end)
		it("runs migrations in order and reconciles new fields", function()
			local log = {}
			local migrations = {
				[2] = function(data)
					table.insert(log, 2)
					data.Gold = data.OldGold
					data.OldGold = nil
				end,
				[3] = function()
					table.insert(log, 3)
				end,
			}
			local raw = { Schema = 1, Data = { OldGold = 7, Currency = { Balances = { Coins = 5 } } } }
			local record = PlayerData.prepare(raw, 3, migrations, makeData)
			expect(record.Schema).to.equal(3)
			expect(log[1]).to.equal(2)
			expect(log[2]).to.equal(3)
			expect(record.Data.Gold).to.equal(7)
			expect(record.Data.Currency.Balances.Coins).to.equal(5) -- kept
			expect(record.Data.Inventory).to.be.ok() -- added
		end)
		it("a failing migration refuses the load", function()
			local raw = { Schema = 1, Data = {} }
			local record, reason = PlayerData.prepare(raw, 2, { [2] = function()
				error("bad")
			end }, makeData)
			expect(record).to.equal(nil)
			expect(string.find(reason, "migration:2", 1, true) ~= nil).to.equal(true)
		end)
	end)

	describe("PlayerData.reconcile", function()
		it("fills missing keys, never overwrites, never recurses into empty maps", function()
			local target = { A = 1, Map = { x = 5 } }
			PlayerData.reconcile(target, { A = 2, B = 3, Map = {}, Nested = { C = 4 } })
			expect(target.A).to.equal(1)
			expect(target.B).to.equal(3)
			expect(target.Map.x).to.equal(5)
			expect(target.Nested.C).to.equal(4)
		end)
	end)

	describe("PlayerData.findUnsavable", function()
		it("catches values DataStores cannot hold", function()
			expect(PlayerData.findUnsavable({ a = 1, b = { 1, 2 } })).to.equal(nil)
			expect(PlayerData.findUnsavable({ a = 0 / 0 })).to.be.ok()
			expect(PlayerData.findUnsavable({ a = math.huge })).to.be.ok()
			expect(PlayerData.findUnsavable({ a = Vector3.zero })).to.be.ok()
			expect(PlayerData.findUnsavable({ [1] = 1, x = 2 })).to.be.ok()
			expect(PlayerData.findUnsavable({ [1] = 1, [3] = 3 })).to.be.ok()
		end)
	end)

	describe("PlayerData.recordReceipt", function()
		it("bounds the receipt list, oldest first", function()
			local meta = { Created = 0, Receipts = {}, ReceiptOrder = {}, PurchaseLog = {} }
			for i = 1, 5 do
				PlayerData.recordReceipt(meta, entry(tostring(i)), 3, 2)
			end
			expect(meta.Receipts["1"]).to.equal(nil)
			expect(meta.Receipts["2"]).to.equal(nil)
			expect(meta.Receipts["5"]).to.be.ok()
			expect(#meta.ReceiptOrder).to.equal(3)
			expect(#meta.PurchaseLog).to.equal(2)
		end)
	end)

	describe("PlayerData.purchaseCore (idempotent receipts)", function()
		local function grantCoins(profile)
			profile.Data.Coins += 100
			return true
		end
		local function okSave(profile)
			return function()
				table.clear(profile.Unconfirmed)
				return true
			end
		end

		it("grants once; a redelivered receipt is a duplicate", function()
			local p = fakeProfile()
			expect(PlayerData.purchaseCore(p, entry("A"), grantCoins, okSave(p))).to.equal("granted")
			expect(PlayerData.purchaseCore(p, entry("A"), grantCoins, okSave(p))).to.equal("duplicate")
			expect(p.Data.Coins).to.equal(100)
		end)
		it("after a failed save, redelivery saves but never grants twice", function()
			local p = fakeProfile()
			local failing = function()
				return false
			end
			expect(PlayerData.purchaseCore(p, entry("B"), grantCoins, failing)).to.equal("failed")
			expect(p.Data.Coins).to.equal(100)
			expect(PlayerData.purchaseCore(p, entry("B"), grantCoins, okSave(p))).to.equal("granted")
			expect(p.Data.Coins).to.equal(100)
		end)
		it("records nothing when the grant refuses or errors", function()
			local p = fakeProfile()
			expect(PlayerData.purchaseCore(p, entry("C"), function()
				return false
			end, okSave(p))).to.equal("failed")
			expect(PlayerData.purchaseCore(p, entry("D"), function()
				error("bug")
			end, okSave(p))).to.equal("failed")
			expect(p.Meta.Receipts.C).to.equal(nil)
			expect(p.Meta.Receipts.D).to.equal(nil)
		end)
	end)

	describe("PlayerData.isPermanentError", function()
		it("does not retry 1xx/4xx, retries throttling and server errors", function()
			expect(PlayerData.isPermanentError("105: Serialized value exceeds 4MB limit.")).to.equal(true)
			expect(PlayerData.isPermanentError("403: Cannot write to DataStore from studio")).to.equal(true)
			expect(PlayerData.isPermanentError("301: GetAsync request dropped")).to.equal(false)
			expect(PlayerData.isPermanentError("502: API Services rejected request")).to.equal(false)
			expect(PlayerData.isPermanentError("HTTP timeout")).to.equal(false)
		end)
	end)
end
