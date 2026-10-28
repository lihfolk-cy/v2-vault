--!nonstrict
-- LihFolk Systems spec: RateLimit. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("LihFolk")

local RateLimit = require(Shared.RateLimit)

return function()
	describe("RateLimit", function()
		it("allows a burst, then refills at the sustained rate", function()
			local now = 0
			local limiter = RateLimit.new(3, 2, function()
				return now
			end)
			expect(limiter:Allow("k")).to.equal(true)
			expect(limiter:Allow("k")).to.equal(true)
			expect(limiter:Allow("k")).to.equal(true)
			expect(limiter:Allow("k")).to.equal(false)
			now = 0.5 -- +1 token
			expect(limiter:Allow("k")).to.equal(true)
			expect(limiter:Allow("k")).to.equal(false)
			now = 100 -- refill caps at burst
			expect(limiter:Peek("k")).to.equal(3)
		end)
		it("keeps keys independent", function()
			local now = 0
			local limiter = RateLimit.new(1, 1, function()
				return now
			end)
			expect(limiter:Allow("a")).to.equal(true)
			expect(limiter:Allow("a")).to.equal(false)
			expect(limiter:Allow("b")).to.equal(true)
		end)
		it("ignores a clock that goes backwards", function()
			local bucket = { tokens = 0, updated = 10 }
			expect(RateLimit.step(bucket, 5, 3, 1)).to.equal(false)
		end)
		it("rejects bad construction", function()
			expect(function()
				RateLimit.new(0, 1)
			end).to.throw()
			expect(function()
				RateLimit.new(2, 0)
			end).to.throw()
		end)
	end)
end
