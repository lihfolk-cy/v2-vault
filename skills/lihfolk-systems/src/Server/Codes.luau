--!strict
-- LihFolk Systems: Codes
-- Install: ServerScriptService/LihFolk/Codes (ModuleScript)
-- Code list: ServerStorage/LihFolkSecrets (never ReplicatedStorage: clients could read it).
--
--   * Input normalised (length checked BEFORE gsub, uppercase, letters/digits only)
--   * Expiry and start time checked against server os.time() (UTC)
--   * One use per player, recorded in the profile in the same synchronous block
--     as the grant; refused (nothing marked) if the reward does not fit
--   * Brute force: tight rate limit plus a lockout after repeated misses,
--     tracked by UserId so rejoining the same server does not reset it
-- Remote: Codes.Redeem(text) -> { ok, code, data = { reward = "100 Coins" } }
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)

local T = Net.T

export type CodeDef = {
	reward: Rewards.Reward,
	startsAt: number?, -- unix seconds (UTC)
	expiresAt: number?, -- unix seconds (UTC)
	eligible: ((Player) -> (boolean, string?))?, -- optional extra rule, must not yield
}

export type Config = {
	codes: { [string]: CodeDef },
	maxMisses: number?, -- default 5 wrong codes...
	missWindowSeconds: number?, -- ...within 120 s...
	lockoutSeconds: number?, -- ...locks redemption for 300 s
}

local Codes = {}

local codes: { [string]: CodeDef } = {}
local MAX_MISSES = 5
local MISS_WINDOW = 120
local LOCKOUT = 300
local misses: { [number]: { count: number, windowStart: number, lockedUntil: number } } = {}

-- Pure: returns the normalised code or nil. Exported for tests.
function Codes.normalise(raw: any): string?
	if type(raw) ~= "string" or #raw > 64 then
		return nil
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	if #code < 3 or #code > 24 or not string.match(code, "^%w+$") then
		return nil
	end
	return code
end

-- Pure: why a code cannot be redeemed now, or nil if it can.
function Codes.check(def: CodeDef?, redeemedAt: number?, now: number): string?
	if not def then
		return "NotFound"
	end
	if def.startsAt and now < def.startsAt then
		return "NotFound" -- do not leak upcoming codes
	end
	if def.expiresAt and now >= def.expiresAt then
		return "Expired"
	end
	if redeemedAt then
		return "AlreadyRedeemed"
	end
	return nil
end

local function isLocked(userId: number, now: number): boolean
	local entry = misses[userId]
	return entry ~= nil and entry.lockedUntil > now
end

local function recordMiss(userId: number, now: number)
	local entry = misses[userId]
	if not entry or now - entry.windowStart > MISS_WINDOW then
		entry = { count = 0, windowStart = now, lockedUntil = 0 }
		misses[userId] = entry
	end
	entry.count += 1
	if entry.count >= MAX_MISSES then
		entry.lockedUntil = now + LOCKOUT
		entry.count = 0
		entry.windowStart = now
	end
end

local function redeem(player: Player, raw: string): Net.Result
	local now = os.time()
	if isLocked(player.UserId, now) then
		return Net.fail("Locked")
	end
	local code = Codes.normalise(raw)
	if not code then
		recordMiss(player.UserId, now)
		return Net.fail("NotFound")
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local redeemed: { [string]: number } = profile.Data.Codes.Redeemed
	local def = codes[code]
	local problem = Codes.check(def, redeemed[code], now)
	if problem then
		if problem == "NotFound" then
			recordMiss(player.UserId, now)
		end
		return Net.fail(problem)
	end
	local codeDef = def :: CodeDef
	if codeDef.eligible then
		local ok, reason = codeDef.eligible(player)
		if not ok then
			return Net.fail(reason or "NotEligible")
		end
	end
	local fits, why = Rewards.CanGrant(player, codeDef.reward)
	if not fits then
		return Net.fail(why or "BagFull")
	end
	-- Mark and grant together, no yield in between.
	redeemed[code] = now
	Rewards.Grant(player, codeDef.reward, `code:{code}`, false, false)
	PlayerData.MarkDirty(profile)
	misses[player.UserId] = nil
	return Net.ok({ reward = Rewards.Describe(codeDef.reward) })
end

function Codes.Init(config: Config)
	MAX_MISSES = config.maxMisses or 5
	MISS_WINDOW = config.missWindowSeconds or 120
	LOCKOUT = config.lockoutSeconds or 300
	for key, def in config.codes do
		assert(Codes.normalise(key) == key, `Codes: '{key}' must be written normalised (A-Z, 0-9, 3-24 chars)`)
		Rewards.Validate(`Code {key}`, def.reward)
		if def.startsAt and def.expiresAt then
			assert(def.startsAt < def.expiresAt, `Code {key}: starts after it expires`)
		end
		codes[key] = def
	end
	PlayerData.RegisterSlice("Codes", function()
		return { Redeemed = {} }
	end)
	Net.Handle("Codes.Redeem", {
		rate = { burst = 3, perSecond = 0.3 },
		args = { T.string(64) },
		handler = redeem,
	})
	-- Lockouts are kept by UserId after leaving (so rejoining does not reset
	-- them) and pruned once expired.
	task.spawn(function()
		while true do
			task.wait(60)
			local now = os.time()
			for userId, entry in misses do
				if entry.lockedUntil <= now and now - entry.windowStart > MISS_WINDOW then
					misses[userId] = nil
				end
			end
		end
	end)
end

return Codes
