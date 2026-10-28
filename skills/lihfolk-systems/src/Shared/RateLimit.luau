--!strict
-- LihFolk Systems: RateLimit
-- Install: ReplicatedStorage/LihFolk/RateLimit (ModuleScript)
-- Token bucket per key (normally a Player). A bucket holds up to `burst` tokens
-- and refills `perSecond` tokens per second; each allowed call spends one.
-- Rule of thumb from the vault: size the limit at 1.5x to 2x the fastest
-- legitimate use. Buckets of a leaving Player are cleared automatically.
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type Bucket = { tokens: number, updated: number }

export type Limiter = {
	Allow: (self: Limiter, key: any) -> boolean,
	Reset: (self: Limiter, key: any) -> (),
	Peek: (self: Limiter, key: any) -> number,
}

type LimiterImpl = {
	_burst: number,
	_perSecond: number,
	_clock: () -> number,
	_buckets: { [any]: Bucket },
}

local RateLimit = {}
RateLimit.__index = RateLimit

local allLimiters: { LimiterImpl } = {}
local cleanupConnected = false

-- Pure step, exported for tests: refills the bucket to `now` and tries to spend one token.
function RateLimit.step(bucket: Bucket, now: number, burst: number, perSecond: number): boolean
	local elapsed = math.max(0, now - bucket.updated)
	bucket.tokens = math.min(burst, bucket.tokens + elapsed * perSecond)
	bucket.updated = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function connectCleanup()
	if cleanupConnected or not RunService:IsServer() then
		return
	end
	cleanupConnected = true
	Players.PlayerRemoving:Connect(function(player: Player)
		for _, limiter in allLimiters do
			limiter._buckets[player] = nil
		end
	end)
end

-- burst: max calls in a burst (>= 1). perSecond: sustained rate (> 0).
-- clock: optional time source for tests; defaults to os.clock.
function RateLimit.new(burst: number, perSecond: number, clock: (() -> number)?): Limiter
	assert(type(burst) == "number" and burst >= 1 and burst < math.huge, "RateLimit: burst must be >= 1")
	assert(type(perSecond) == "number" and perSecond > 0 and perSecond < math.huge, "RateLimit: perSecond must be > 0")
	local self: LimiterImpl = {
		_burst = burst,
		_perSecond = perSecond,
		_clock = clock or os.clock,
		-- Not a weak table on purpose: Roblox can drop Instance wrappers from weak
		-- tables while the Player is still in game, which would refill the bucket.
		-- PlayerRemoving clears Player keys; other keys are the caller's to Reset.
		_buckets = {},
	}
	table.insert(allLimiters, self)
	connectCleanup()
	return (setmetatable(self :: any, RateLimit) :: any) :: Limiter
end

function RateLimit.Allow(self: LimiterImpl, key: any): boolean
	local now = self._clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._burst, updated = now }
		self._buckets[key] = bucket
	end
	return RateLimit.step(bucket, now, self._burst, self._perSecond)
end

function RateLimit.Reset(self: LimiterImpl, key: any)
	self._buckets[key] = nil
end

-- Tokens currently available for key (after refill), without spending any.
function RateLimit.Peek(self: LimiterImpl, key: any): number
	local bucket = self._buckets[key]
	if not bucket then
		return self._burst
	end
	local elapsed = math.max(0, self._clock() - bucket.updated)
	return math.min(self._burst, bucket.tokens + elapsed * self._perSecond)
end

return RateLimit
