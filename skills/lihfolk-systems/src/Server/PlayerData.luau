--!strict
-- LihFolk Systems: PlayerData
-- Install: ServerScriptService/LihFolk/PlayerData (ModuleScript)
--
-- Session-locked player profiles on one DataStore key per player.
--   * UpdateAsync with a lease {Token, JobId, ExpiresAt}; every save is fenced
--     by the token, so a server that lost the lease can never overwrite data.
--   * Three load outcomes: ready / locked / failed. A thrown error is never a
--     new player, and a profile that did not reach "ready" has no save path.
--   * Schema version + ordered migrations; newer schemas are refused.
--   * Additive defaults come from slices that services register, reconciled
--     on load (never one shared default table).
--   * Staggered autosave (also the lease heartbeat), save + release on leave,
--     parallel BindToClose with a deadline.
--   * Idempotent purchases: the grant and its PurchaseId are written in the
--     same document, in the same write; "granted" only after the save succeeds.
--   * Studio uses a separate store, so tests never touch live saves.
--
-- Only this module writes player data. Other services mutate profile.Data
-- synchronously (no yield between check and write) and call MarkDirty.
-- Status: reviewed, not run in Studio.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Signal = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Signal"))

local IS_STUDIO = RunService:IsStudio()
local MAX_VALUE_CHARS = 4_194_304 -- per-key value cap (Roblox docs, as of October 2026)

export type Migration = (data: { [string]: any }) -> ()

export type Config = {
	storeName: string, -- e.g. "PlayerData_v1". Never rename after launch.
	schemaVersion: number, -- bump when you add a migration
	migrations: { [number]: Migration }?, -- [n] upgrades a version n-1 document to n
	keyPrefix: string?, -- default "U_"
	leaseSeconds: number?, -- default 90 (shorter than ~30 s is unsafe: clock skew)
	autosaveSeconds: number?, -- default 30, clamped to lease / 3
	claimAttempts: number?, -- default 6
	lockedRetrySeconds: number?, -- default 1.5 (6 x 1.5 = about 7.5 s, as measured in the vault's reference project)
	saveAttempts: number?, -- default 4
	receiptsKept: number?, -- default 500 PurchaseIds remembered per player
	purchaseLogKept: number?, -- default 100 entries
}

type Session = { Token: string, JobId: string, PlaceId: number, ExpiresAt: number }

export type PurchaseEntry = { Id: string, Product: string, Robux: number, Time: number }

export type Meta = {
	Created: number,
	Receipts: { [string]: number }, -- PurchaseId -> unix time granted
	ReceiptOrder: { string }, -- oldest first, for bounding
	PurchaseLog: { PurchaseEntry },
}

export type Record = {
	Schema: number,
	Data: { [string]: any },
	Meta: Meta,
	Session: Session?,
}

export type ProfileState = "active" | "releasing" | "released" | "lost"

export type Profile = {
	Player: Player,
	UserId: number,
	Key: string,
	Token: string,
	Data: { [string]: any },
	Meta: Meta,
	State: ProfileState,
	Saving: boolean,
	Dirty: boolean,
	LastSave: number, -- os.clock()
	NextSaveAt: number, -- os.clock()
	LeaseRenewedAt: number, -- os.time()
	Unconfirmed: { [string]: boolean }, -- receipts granted in memory, not yet saved
}

export type PurchaseResult = "granted" | "duplicate" | "failed"

local PlayerData = {}

PlayerData.Loaded = Signal.new() -- (player, profile)
PlayerData.Releasing = Signal.new() -- (player, profile): read final values synchronously
PlayerData.LoadFailed = Signal.new() -- (player, reason)

local config: Config? = nil
local slices: { [string]: () -> any } = {}
local sliceOrder: { string } = {}
local started = false
local store: DataStore? = nil

local profiles: { [Player]: Profile } = {}
local releasingByUser: { [number]: Profile } = {}
local waiters: { [Player]: { thread } } = {}

local LEASE = 90
local AUTOSAVE = 30
local CLAIM_ATTEMPTS = 6
local LOCKED_RETRY = 1.5
local SAVE_ATTEMPTS = 4
local RECEIPTS_KEPT = 500
local LOG_KEPT = 100

---------------------------------------------------------------------------
-- Pure helpers (exported for tests)
---------------------------------------------------------------------------

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end
PlayerData.deepCopy = deepCopy

-- Fills missing keys from template without overwriting. Empty template tables
-- are maps of player content (Stacks, Uniques...): they are not recursed into.
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, default in template do
		local current = target[key]
		if current == nil then
			target[key] = deepCopy(default)
		elseif type(default) == "table" and type(current) == "table" and next(default) ~= nil then
			reconcile(current, default)
		end
	end
end
PlayerData.reconcile = reconcile

-- Returns a description of the first value DataStores cannot store safely, or nil.
local function findUnsavable(value: any, path: string, depth: number): string?
	if depth > 32 then
		return `{path}: nested deeper than 32`
	end
	local t = type(value)
	if t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return `{path}: NaN or infinity`
		end
		return nil
	elseif t == "string" or t == "boolean" or t == "nil" then
		return nil
	elseif t ~= "table" then
		return `{path}: {typeof(value)} cannot be saved (convert at the boundary)`
	end
	local hasNumberKeys, hasStringKeys, count = false, false, 0
	for k, v in value do
		count += 1
		local kt = type(k)
		if kt == "number" then
			hasNumberKeys = true
		elseif kt == "string" then
			hasStringKeys = true
		else
			return `{path}: key of type {kt}`
		end
		local problem = findUnsavable(v, `{path}.{tostring(k)}`, depth + 1)
		if problem then
			return problem
		end
	end
	if hasNumberKeys and hasStringKeys then
		return `{path}: mixes array and dictionary keys`
	end
	if hasNumberKeys and #value ~= count then
		return `{path}: array has holes (use string keys for sparse maps)`
	end
	return nil
end
PlayerData.findUnsavable = function(value: any): string?
	return findUnsavable(value, "Data", 0)
end

local function newMeta(): Meta
	return { Created = os.time(), Receipts = {}, ReceiptOrder = {}, PurchaseLog = {} }
end

-- Turns a raw stored record into a ready Record, or (nil, reason).
-- reason: "corrupt" | "newer" | "migration:<n>:<err>". raw == nil means a new player.
function PlayerData.prepare(raw: any, schemaVersion: number, migrations: { [number]: Migration }, makeData: () -> { [string]: any }): (Record?, string?)
	if raw == nil or (type(raw) == "table" and raw.Schema == nil and raw.Data == nil) then
		-- Never saved (a claim may have written only a Session): genuinely new.
		return { Schema = schemaVersion, Data = makeData(), Meta = newMeta(), Session = nil }, nil
	end
	if type(raw) ~= "table" or type(raw.Schema) ~= "number" or type(raw.Data) ~= "table" then
		return nil, "corrupt"
	end
	if raw.Schema > schemaVersion then
		-- Saved by a newer server build; loading and saving here would erase new fields.
		return nil, "newer"
	end
	for version = raw.Schema + 1, schemaVersion do
		local migrate = migrations[version]
		if migrate then
			local ok, err = pcall(migrate, raw.Data)
			if not ok then
				return nil, `migration:{version}:{err}`
			end
		end
		raw.Schema = version
	end
	reconcile(raw.Data, makeData())
	local meta = if type(raw.Meta) == "table" then raw.Meta else newMeta()
	reconcile(meta, newMeta())
	raw.Meta = meta
	return raw :: Record, nil
end

-- Records a PurchaseId in meta, bounded to `kept` entries (oldest dropped).
function PlayerData.recordReceipt(meta: Meta, entry: PurchaseEntry, kept: number, logKept: number)
	meta.Receipts[entry.Id] = entry.Time
	table.insert(meta.ReceiptOrder, entry.Id)
	while #meta.ReceiptOrder > kept do
		local oldest = table.remove(meta.ReceiptOrder, 1)
		if oldest then
			meta.Receipts[oldest] = nil
		end
	end
	table.insert(meta.PurchaseLog, entry)
	while #meta.PurchaseLog > logKept do
		table.remove(meta.PurchaseLog, 1)
	end
end

-- DataStore error codes: 1xx are bad requests and 4xx are access problems,
-- retrying those cannot succeed. 3xx (throttling) and 5xx are retried. Rule of thumb.
local function isPermanentError(err: any): boolean
	local code = tonumber(string.match(tostring(err), "^(%d+)"))
	if not code then
		return false
	end
	return (code >= 100 and code < 200) or (code >= 400 and code < 500)
end
PlayerData.isPermanentError = isPermanentError

---------------------------------------------------------------------------
-- Internals
---------------------------------------------------------------------------

local function makeData(): { [string]: any }
	local data = {}
	for _, name in sliceOrder do
		data[name] = slices[name]()
	end
	return data
end

local function getConfig(): Config
	assert(config, "PlayerData.Configure must be called first")
	return config :: Config
end

local function getStore(): DataStore
	assert(store, "PlayerData.Start has not run")
	return store :: DataStore
end

local function backoff(attempt: number)
	-- Exponential with jitter: about 1, 2, 4, 8 s.
	task.wait(math.min(2 ^ (attempt - 1), 8) * (0.75 + math.random() * 0.5))
end

local function waitForBudget(maxWait: number)
	local deadline = os.clock() + maxWait
	while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) < 1 and os.clock() < deadline do
		task.wait(0.5)
	end
end

local function keyFor(userId: number): string
	local prefix = getConfig().keyPrefix or "U_"
	if IS_STUDIO then
		-- ServerStorage attribute TestProfileKey = "a" gives a fresh profile; clear it to return.
		local test = ServerStorage:GetAttribute("TestProfileKey")
		if type(test) == "string" and test ~= "" and #test <= 20 then
			return `{prefix}T_{test}_{userId}`
		end
	end
	return `{prefix}{userId}`
end

type ClaimStatus = "ready" | "locked" | "failed" | "corrupt"

local function claimAsync(key: string, token: string, userId: number): (ClaimStatus, any)
	local status: ClaimStatus = "failed"
	for attempt = 1, CLAIM_ATTEMPTS do
		status = "failed"
		local captured: any = nil
		waitForBudget(5)
		local ok, err = pcall(function()
			getStore():UpdateAsync(key, function(old: any, keyInfo: DataStoreKeyInfo?): (any, { number }?, any)
				captured = nil
				if old ~= nil and type(old) ~= "table" then
					status = "corrupt"
					return nil, nil, nil -- cancel: never overwrite something we cannot read
				end
				local now = os.time()
				local record = old or {}
				local session = record.Session
				if type(session) == "table" and session.Token ~= token and type(session.ExpiresAt) == "number" and session.ExpiresAt > now then
					status = "locked"
					return nil, nil, nil -- cancel: another live server owns it
				end
				record.Session = { Token = token, JobId = game.JobId, PlaceId = game.PlaceId, ExpiresAt = now + LEASE }
				status = "ready"
				captured = record
				return record, { userId }, if keyInfo then keyInfo:GetMetadata() else nil
			end)
		end)
		if ok and status == "ready" then
			return "ready", captured
		elseif ok and status == "corrupt" then
			return "corrupt", nil
		elseif not ok then
			status = "failed"
			warn(`[PlayerData] claim {key} attempt {attempt} failed: {err}`)
			if isPermanentError(err) then
				break
			end
		end
		if attempt < CLAIM_ATTEMPTS then
			if status == "locked" then
				task.wait(LOCKED_RETRY)
			else
				backoff(attempt)
			end
		end
	end
	return status, nil
end

local function releaseUnused(key: string, token: string, userId: number)
	pcall(function()
		getStore():UpdateAsync(key, function(old: any, keyInfo: DataStoreKeyInfo?): (any, { number }?, any)
			if type(old) == "table" and type(old.Session) == "table" and old.Session.Token == token then
				old.Session = nil
				return old, { userId }, if keyInfo then keyInfo:GetMetadata() else nil
			end
			return nil, nil, nil
		end)
	end)
end

-- The only function that writes a loaded profile. Fenced by the session token.
local function writeAsync(profile: Profile, release: boolean): boolean
	local waitUntil = os.clock() + 30
	while profile.Saving and os.clock() < waitUntil do
		task.wait(0.1)
	end
	if profile.Saving or profile.State == "lost" or profile.State == "released" then
		return false
	end
	profile.Saving = true

	-- Snapshot before yielding: gameplay keeps mutating Data during the request.
	local snapshot = deepCopy(profile.Data)
	local metaSnapshot = deepCopy(profile.Meta)
	local included = table.clone(profile.Unconfirmed)
	local wasDirty = profile.Dirty
	profile.Dirty = false

	local problem = findUnsavable(snapshot, "Data", 0)
	if problem then
		-- Refuse to write damaged data; the last good save stays intact.
		warn(`[PlayerData] NOT saving {profile.Key}: {problem}`)
		profile.Dirty = true
		profile.Saving = false
		return false
	end

	local record: Record = { Schema = getConfig().schemaVersion, Data = snapshot, Meta = metaSnapshot, Session = nil }
	local okSize, encoded = pcall(HttpService.JSONEncode, HttpService, record)
	if okSize and #encoded > MAX_VALUE_CHARS * 0.75 then
		warn(`[PlayerData] {profile.Key} is {#encoded} chars, over 75% of the per-key cap; cap growing lists`)
	end

	local success = false
	for attempt = 1, SAVE_ATTEMPTS do
		local lost = false
		waitForBudget(3)
		local ok, err = pcall(function()
			getStore():UpdateAsync(profile.Key, function(old: any, keyInfo: DataStoreKeyInfo?): (any, { number }?, any)
				lost = false
				if type(old) ~= "table" or type(old.Session) ~= "table" or old.Session.Token ~= profile.Token then
					lost = true
					return nil, nil, nil
				end
				record.Session = if release
					then nil
					else { Token = profile.Token, JobId = game.JobId, PlaceId = game.PlaceId, ExpiresAt = os.time() + LEASE }
				return record, { profile.UserId }, if keyInfo then keyInfo:GetMetadata() else nil
			end)
		end)
		if ok and lost then
			profile.State = "lost"
			warn(`[PlayerData] lost the session lock for {profile.Key}; this server stops writing it`)
			if profile.Player.Parent == Players then
				profile.Player:Kick("Your data was opened on another server. Please rejoin.")
			end
			break
		elseif ok then
			success = true
			break
		end
		warn(`[PlayerData] save {profile.Key} attempt {attempt} failed: {err}`)
		if isPermanentError(err) then
			break
		end
		if attempt < SAVE_ATTEMPTS then
			backoff(attempt)
		end
	end

	if success then
		profile.LastSave = os.clock()
		profile.LeaseRenewedAt = os.time()
		for purchaseId in included do
			profile.Unconfirmed[purchaseId] = nil
		end
		if release then
			profile.State = "released"
		end
	elseif wasDirty then
		profile.Dirty = true
	end
	profile.Saving = false
	return success
end

local function resumeWaiters(player: Player, profile: Profile?)
	local list = waiters[player]
	if not list then
		return
	end
	waiters[player] = nil
	for _, thread in list do
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, profile)
		end
	end
end

local function failLoad(player: Player, reason: string)
	resumeWaiters(player, nil)
	PlayerData.LoadFailed:Fire(player, reason)
	if player.Parent ~= Players then
		return
	end
	local message = if reason == "locked"
		then "Your progress is still saving on another server. Please rejoin in a minute."
		elseif reason == "newer" then "This server is out of date. Please rejoin to get a newer server."
		elseif reason == "simulated" then "[Studio] Simulated load failure. Nothing was saved."
		else "We could not load your progress. Nothing was changed. Please rejoin."
	player:Kick(message)
end

local function onPlayerAdded(player: Player)
	local userId = player.UserId
	-- Same-server rejoin: wait for this server's own release save first (bounded).
	local waitUntil = os.clock() + 15
	while releasingByUser[userId] and os.clock() < waitUntil do
		task.wait(0.1)
	end
	if IS_STUDIO and ServerStorage:GetAttribute("SimulateLoadFailure") == true then
		failLoad(player, "simulated")
		return
	end

	local cfg = getConfig()
	local key = keyFor(userId)
	local token = HttpService:GenerateGUID(false)
	local status, raw = claimAsync(key, token, userId)

	if player.Parent ~= Players then
		if status == "ready" then
			releaseUnused(key, token, userId) -- left while loading: give the lease back
		end
		resumeWaiters(player, nil)
		return
	end
	if status ~= "ready" then
		warn(`[PlayerData] load {key}: {status}`)
		failLoad(player, status)
		return
	end

	local record, reason = PlayerData.prepare(raw, cfg.schemaVersion, cfg.migrations or {}, makeData)
	if not record then
		releaseUnused(key, token, userId)
		warn(`[PlayerData] refused {key}: {reason}`)
		failLoad(player, reason or "corrupt")
		return
	end

	local now = os.clock()
	local profile: Profile = {
		Player = player,
		UserId = userId,
		Key = key,
		Token = token,
		Data = record.Data,
		Meta = record.Meta,
		State = "active",
		Saving = false,
		Dirty = raw == nil or (raw :: any).Schema == nil, -- brand-new profiles save on the first tick
		LastSave = now,
		NextSaveAt = now + AUTOSAVE * (0.2 + 0.8 * math.random()), -- stagger
		LeaseRenewedAt = os.time(),
		Unconfirmed = {},
	}
	profiles[player] = profile
	player:SetAttribute("DataReady", true)
	resumeWaiters(player, profile)
	PlayerData.Loaded:Fire(player, profile)
end

local function release(player: Player, profile: Profile)
	profiles[player] = nil -- no service can mutate Data after the final snapshot
	profile.State = "releasing"
	releasingByUser[profile.UserId] = profile
	PlayerData.Releasing:Fire(player, profile)
	writeAsync(profile, true)
	if releasingByUser[profile.UserId] == profile then
		releasingByUser[profile.UserId] = nil
	end
end

local function onPlayerRemoving(player: Player)
	resumeWaiters(player, nil)
	local profile = profiles[player]
	if profile then
		release(player, profile)
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function PlayerData.Configure(newConfig: Config)
	assert(not started, "PlayerData.Configure after Start")
	assert(type(newConfig.storeName) == "string" and newConfig.storeName ~= "", "PlayerData: storeName required")
	assert(type(newConfig.schemaVersion) == "number" and newConfig.schemaVersion >= 1, "PlayerData: schemaVersion >= 1 required")
	config = newConfig
	LEASE = math.max(newConfig.leaseSeconds or 90, 30)
	AUTOSAVE = math.min(newConfig.autosaveSeconds or 30, LEASE / 3)
	CLAIM_ATTEMPTS = newConfig.claimAttempts or 6
	LOCKED_RETRY = newConfig.lockedRetrySeconds or 1.5
	SAVE_ATTEMPTS = newConfig.saveAttempts or 4
	RECEIPTS_KEPT = newConfig.receiptsKept or 500
	LOG_KEPT = newConfig.purchaseLogKept or 100
	for version in newConfig.migrations or {} do
		assert(version >= 2 and version <= newConfig.schemaVersion, `PlayerData: migration [{version}] outside 2..schemaVersion`)
	end
end

-- Services register their part of the profile before Start. makeDefault must
-- return a NEW table every call.
function PlayerData.RegisterSlice(name: string, makeDefault: () -> any)
	assert(not started, `PlayerData.RegisterSlice('{name}') after Start`)
	assert(slices[name] == nil, `PlayerData: slice '{name}' registered twice`)
	local a, b = makeDefault(), makeDefault()
	assert(type(a) ~= "table" or a ~= b, `PlayerData: slice '{name}' must return a fresh table each call`)
	slices[name] = makeDefault
	table.insert(sliceOrder, name)
end

-- The active profile, or nil while loading, after leaving or after a failed load.
function PlayerData.Get(player: Player): Profile?
	local profile = profiles[player]
	if profile and profile.State == "active" then
		return profile
	end
	return nil
end

-- Yields until the profile is ready, the load fails, the player leaves, or timeout.
function PlayerData.WaitForProfile(player: Player, timeout: number): Profile?
	local existing = PlayerData.Get(player)
	if existing or player.Parent ~= Players then
		return existing
	end
	local thread = coroutine.running()
	local list = waiters[player]
	if not list then
		list = {}
		waiters[player] = list
	end
	table.insert(list, thread)
	local timer = task.delay(timeout, function()
		local current = waiters[player]
		if current then
			local index = table.find(current, thread)
			if index then
				table.remove(current, index)
				task.spawn(thread, nil)
			end
		end
	end)
	local profile = coroutine.yield()
	pcall(task.cancel, timer)
	return profile
end

function PlayerData.MarkDirty(profile: Profile)
	profile.Dirty = true
end

-- Saves now (after rare grants). Returns true when the write succeeded.
function PlayerData.SaveNowAsync(player: Player): boolean
	local profile = PlayerData.Get(player)
	if not profile then
		return false
	end
	return writeAsync(profile, false)
end

-- Pure core of ProcessPurchaseAsync, exported for tests. `save` performs the
-- durable write and, on success, clears profile.Unconfirmed for what it saved.
function PlayerData.purchaseCore(profile: Profile, entry: PurchaseEntry, grant: (Profile) -> boolean, save: () -> boolean): PurchaseResult
	local purchaseId = entry.Id
	if profile.Meta.Receipts[purchaseId] ~= nil then
		if not profile.Unconfirmed[purchaseId] then
			return "duplicate"
		end
		-- Granted in memory earlier but that save failed: make it durable, do not grant again.
		if save() and not profile.Unconfirmed[purchaseId] then
			return "granted"
		end
		return "failed"
	end

	-- Check-and-record is synchronous: a concurrent redelivery sees the receipt.
	local ok, granted = pcall(grant, profile)
	if not ok then
		warn(`[PlayerData] grant for {purchaseId} errored: {granted}`)
		return "failed"
	end
	if granted ~= true then
		return "failed"
	end
	PlayerData.recordReceipt(profile.Meta, entry, RECEIPTS_KEPT, LOG_KEPT)
	profile.Unconfirmed[purchaseId] = true
	profile.Dirty = true

	if save() and not profile.Unconfirmed[purchaseId] then
		return "granted"
	end
	return "failed"
end

-- Grants a developer product exactly once.
--   grant(profile) must validate, then mutate profile.Data synchronously
--   (no yields) and return true; returning false or erroring grants nothing.
-- Returns "granted" (made durable by this call), "duplicate" (already saved
-- earlier: acknowledge it) or "failed" (return NotProcessedYet).
function PlayerData.ProcessPurchaseAsync(player: Player, entry: PurchaseEntry, grant: (Profile) -> boolean): PurchaseResult
	local profile = PlayerData.Get(player)
	if not profile then
		return "failed"
	end
	local active = profile :: Profile
	return PlayerData.purchaseCore(active, entry, grant, function(): boolean
		return writeAsync(active, false)
	end)
end

function PlayerData.Start()
	assert(not started, "PlayerData.Start called twice")
	local cfg = getConfig()
	started = true

	local storeName = if IS_STUDIO then `{cfg.storeName}_STUDIO` else cfg.storeName
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	if not ok then
		error(`[PlayerData] cannot open DataStore '{storeName}': {result}. In Studio, enable Game Settings > Security > Enable Studio Access to API Services.`)
	end
	store = result

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave and lease heartbeat. One loop, staggered per profile, dirty-gated,
	-- but the lease is renewed at least every AUTOSAVE seconds regardless.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, profile in profiles do
				if profile.State == "active" and not profile.Saving and now >= profile.NextSaveAt then
					profile.NextSaveAt = now + AUTOSAVE
					local leaseDue = os.time() - profile.LeaseRenewedAt >= AUTOSAVE
					if profile.Dirty or leaseDue then
						task.spawn(writeAsync, profile, false)
					end
				end
			end
		end
	end)

	game:BindToClose(function()
		for player, profile in profiles do
			task.spawn(release, player, profile)
		end
		-- The server waits at most 30 s for BindToClose (Roblox docs). Studio stop is
		-- not a shutdown test, so do not hold it open there.
		local deadline = os.clock() + (if IS_STUDIO then 3 else 26)
		while next(releasingByUser) ~= nil and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- Test hook: lets specs drive internals without Studio data stores.
PlayerData._internal = {
	makeData = makeData,
	slices = slices,
}

return PlayerData
