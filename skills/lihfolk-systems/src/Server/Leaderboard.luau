--!strict
-- LihFolk Systems: Leaderboard
-- Install: ServerScriptService/LihFolk/Leaderboard (ModuleScript)
--
-- Global boards on OrderedDataStores (vault: Global Leaderboards End to End).
--   * The profile is the truth; the board is a rebuildable index. Never read a
--     player's own score back from the board to decide anything.
--   * Write rarely: each player, each board, every writeSeconds, only if the
--     value changed, plus once on leave. Read rarely: one page per board every
--     refreshSeconds, staggered per server.
--   * Budget-aware: skips a cycle when GetRequestBudgetForRequestType is low.
--     Ordered budgets per server per minute: writes 30 + 5 x players, list
--     pages 5 + 2 x players (Roblox docs, as of October 2026).
--   * Monotonic boards write with UpdateAsync "never lower", so a late write
--     from an old server cannot lower a newer score.
--   * Weekly boards use a new store per ISO-style week (Monday 00:00 UTC):
--     nothing is deleted, last week stays readable, no reset race.
--   * Values must be integers; huge simulator numbers use LogEncode/LogDecode.
-- Remote: Leaderboard.Get(boardId)   Push: Leaderboard.Updated(boardId, rows)
-- Status: reviewed, not run in Studio.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)

local T = Net.T

export type BoardDef = {
	storeName: string, -- e.g. "LB_CoinsEarned_v1"; a new name = a fresh board
	period: "all" | "weekly",
	-- Either a source read from the GIVEN profile (all-time boards). Do not call
	-- PlayerData.Get inside it: the final write on leave runs on a detached profile ...
	source: ((player: Player, profile: PlayerData.Profile) -> number)?,
	-- ... or nil: the board is a counter fed by Leaderboard.Add (weekly boards).
	monotonic: boolean?, -- default true: score only goes up within the period
	encode: ((number) -> number)?, -- value -> stored integer
	decode: ((number) -> number)?, -- stored integer -> display value
	topN: number?, -- default 50 (one page, max 100)
}

export type Config = {
	boards: { [string]: BoardDef },
	writeSeconds: number?, -- default 120
	refreshSeconds: number?, -- default 120
	exclude: ((userId: number) -> boolean)?, -- banned / deletion-requested users
}

export type Row = { rank: number, userId: number, name: string, displayName: string, value: number }

local Leaderboard = {}

local boards: { [string]: BoardDef } = {}
local cached: { [string]: { Row } } = {}
local lastWritten: { [Player]: { [string]: number } } = {}
local nameCache: { [number]: { name: string, displayName: string } } = {}
local updatedPush: Net.Push? = nil
local WRITE_SECONDS = 120
local REFRESH_SECONDS = 120
local excludeFn: ((number) -> boolean)? = nil
local WEEK = 604800
local MONDAY_OFFSET = 4 * 86400 -- 1970-01-01 was a Thursday; 1970-01-05 a Monday

---------------------------------------------------------------------------
-- Pure (exported for tests)
---------------------------------------------------------------------------

function Leaderboard.weekIndex(unix: number): number
	return math.floor((unix - MONDAY_OFFSET) / WEEK)
end

function Leaderboard.storeNameFor(def: BoardDef, unix: number): string
	if def.period == "weekly" then
		return `{def.storeName}_W{Leaderboard.weekIndex(unix)}`
	end
	return def.storeName
end

-- For values beyond 2^53 or simulator-scale numbers: keeps order, loses precision.
function Leaderboard.LogEncode(value: number): number
	if value <= 0 or value ~= value then
		return 0
	end
	return math.floor(math.log10(value + 1) * 1e9)
end

function Leaderboard.LogDecode(stored: number): number
	return 10 ^ (stored / 1e9) - 1
end

-- Integer to store, or nil if it must not be written.
function Leaderboard.toStored(def: BoardDef, value: number): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	local stored = if def.encode then def.encode(value) else math.floor(value)
	if stored ~= stored or stored < 0 or stored >= 2 ^ 53 then
		return nil
	end
	return math.floor(stored)
end

---------------------------------------------------------------------------
-- Values
---------------------------------------------------------------------------

local function weeklyState(profile: PlayerData.Profile): { Week: number, Values: { [string]: number } }
	local state = profile.Data.Leaderboards
	local week = Leaderboard.weekIndex(os.time())
	if state.Week ~= week then
		state.Week = week
		state.Values = {}
	end
	return state
end

-- Adds to a counter board (one without `source`): weekly boards count this
-- week only, all-time boards keep a running total. Synchronous.
function Leaderboard.Add(player: Player, boardId: string, amount: number)
	local def = boards[boardId]
	assert(def and def.source == nil, `Leaderboard.Add: {boardId} is not a counter board`)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount >= math.huge then
		return
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	local values = if def.period == "weekly" then weeklyState(profile).Values else profile.Data.Leaderboards.AllTime
	values[boardId] = math.min((values[boardId] or 0) + amount, 2 ^ 53 - 1)
	PlayerData.MarkDirty(profile)
end

local function valueOf(def: BoardDef, boardId: string, player: Player, profile: PlayerData.Profile): number?
	if def.source then
		local ok, value = pcall(def.source, player, profile)
		return if ok then value else nil
	end
	if def.period == "weekly" then
		return weeklyState(profile).Values[boardId] or 0
	end
	-- An all-time counter board keeps its total under the "AllTime" map.
	return profile.Data.Leaderboards.AllTime[boardId] or 0
end

---------------------------------------------------------------------------
-- Writing
---------------------------------------------------------------------------

-- Studio reads and writes `<name>_STUDIO`, like PlayerData, so play tests keep the live boards clean.
local IS_STUDIO = RunService:IsStudio()
local function physicalStoreName(def: BoardDef, unix: number): string
	local name = Leaderboard.storeNameFor(def, unix)
	return if IS_STUDIO then `{name}_STUDIO` else name
end

local function budget(requestType: Enum.DataStoreRequestType): number
	return DataStoreService:GetRequestBudgetForRequestType(requestType)
end

local function writeAsync(def: BoardDef, userId: number, stored: number): boolean
	local storeName = physicalStoreName(def, os.time())
	local key = tostring(userId)
	local ok, err = pcall(function()
		local store = DataStoreService:GetOrderedDataStore(storeName)
		if def.monotonic ~= false then
			store:UpdateAsync(key, function(old: any): any
				if type(old) == "number" and old >= stored then
					return nil -- cancel: the board already has this or more
				end
				return stored
			end)
		else
			store:SetAsync(key, stored)
		end
	end)
	if not ok then
		warn(`[Leaderboard] write {storeName}/{key} failed: {err}`)
	end
	return ok
end

local function writePlayer(player: Player, profile: PlayerData.Profile, force: boolean)
	local written = lastWritten[player]
	if not written then
		written = {}
		lastWritten[player] = written
	end
	for boardId, def in boards do
		local value = valueOf(def, boardId, player, profile)
		local stored = if value then Leaderboard.toStored(def, value) else nil
		if stored and stored > 0 and written[boardId] ~= stored then
			-- Keep a reserve for other systems unless this is the final write on leave.
			if force or budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) > 10 then
				if writeAsync(def, player.UserId, stored) then
					written[boardId] = stored
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Reading
---------------------------------------------------------------------------

local function resolveNames(userIds: { number })
	local missing = {}
	for _, userId in userIds do
		if not nameCache[userId] then
			table.insert(missing, userId)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok and type(infos) == "table" then
		for _, info in infos do
			nameCache[info.Id] = { name = info.Username, displayName = info.DisplayName }
		end
	end
end

local function refreshBoard(boardId: string, def: BoardDef)
	if budget(Enum.DataStoreRequestType.GetSortedAsync) < 2 then
		return
	end
	local storeName = physicalStoreName(def, os.time())
	local topN = math.clamp(def.topN or 50, 1, 100)
	local ok, page = pcall(function()
		local store = DataStoreService:GetOrderedDataStore(storeName)
		return store:GetSortedAsync(false, topN):GetCurrentPage()
	end)
	if not ok then
		warn(`[Leaderboard] read {storeName} failed: {page}`)
		return
	end
	local ids = {}
	for _, entry in page do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(ids, userId)
		end
	end
	resolveNames(ids)
	local rows: { Row } = {}
	for _, entry in page do
		local userId = tonumber(entry.key)
		if userId and not (excludeFn and excludeFn(userId)) then
			local names = nameCache[userId]
			table.insert(rows, {
				rank = #rows + 1,
				userId = userId,
				name = if names then names.name else `#{userId}`,
				displayName = if names then names.displayName else `#{userId}`,
				value = if def.decode then def.decode(entry.value) else entry.value,
			})
		end
	end
	cached[boardId] = rows
	if updatedPush then
		updatedPush:FireAll(boardId, rows)
	end
end

function Leaderboard.GetRows(boardId: string): { Row }
	return cached[boardId] or {}
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Leaderboard.Init(config: Config)
	WRITE_SECONDS = math.max(config.writeSeconds or 120, 60)
	REFRESH_SECONDS = math.max(config.refreshSeconds or 120, 60)
	excludeFn = config.exclude
	for boardId, def in config.boards do
		assert(string.match(boardId, "^[%w_]+$"), `Leaderboard: bad board id {boardId}`)
		assert(type(def.storeName) == "string" and #def.storeName <= 40, `Leaderboard {boardId}: storeName required (<= 40 chars)`)
		assert(def.period == "all" or def.period == "weekly", `Leaderboard {boardId}: period must be "all" or "weekly"`)
		assert((def.encode == nil) == (def.decode == nil), `Leaderboard {boardId}: set encode and decode together`)
		boards[boardId] = def
		cached[boardId] = {}
	end

	PlayerData.RegisterSlice("Leaderboards", function()
		return { Week = -1, Values = {}, AllTime = {} }
	end)
	updatedPush = Net.Push("Leaderboard.Updated")
	Net.Handle("Leaderboard.Get", {
		rate = { burst = 4, perSecond = 1 },
		args = { T.key(boards) },
		handler = function(_player: Player, boardId: string): Net.Result
			return Net.ok(Leaderboard.GetRows(boardId))
		end,
	})

	-- Final write on leave: read synchronously from the releasing profile. Registered as a
	-- release hook, so BindToClose waits for these writes before the server closes.
	PlayerData.OnRelease(function(player: Player, profile: PlayerData.Profile)
		writePlayer(player, profile, true)
		lastWritten[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.delay(10, function()
			lastWritten[player] = nil -- in case the profile never loaded
		end)
	end)

	-- Periodic writes, spread across the interval.
	task.spawn(function()
		while true do
			local players = Players:GetPlayers()
			local gap = WRITE_SECONDS / math.max(#players, 1)
			for _, player in players do
				local profile = PlayerData.Get(player)
				if profile then
					writePlayer(player, profile, false)
				end
				task.wait(gap)
			end
			if #players == 0 then
				task.wait(WRITE_SECONDS)
			end
		end
	end)

	-- Periodic reads, staggered so every server does not read in the same second.
	task.spawn(function()
		task.wait(math.random() * (if IS_STUDIO then 2 else 30))
		while true do
			for boardId, def in boards do
				refreshBoard(boardId, def)
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return Leaderboard
