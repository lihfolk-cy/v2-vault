--!strict
-- LihFolk Systems: Net
-- Install: ReplicatedStorage/LihFolk/Net (ModuleScript)
--
-- The one place that creates remotes. Every client-to-server entry point is
-- declared with a rate limit and one validator per argument; the handler only
-- runs after both pass, so services never see hostile input.
--
-- Server:
--   Net.Handle(name, spec)   request/response (RemoteFunction, client -> server only)
--   Net.Listen(name, spec)   fire-and-forget  (RemoteEvent, client -> server)
--   Net.Push(name)           server -> client (RemoteEvent); returns :Fire/:FireAll
-- Client:
--   Net.Request(name, ...) -> Result     Net.Send(name, ...)     Net.On(name, fn)
--
-- Handler order (roblox-secure-remotes): rate limit -> arg count and types ->
-- value ranges -> (service does context checks) -> lock -> act.
-- The server never calls InvokeClient.
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RateLimit = require(script.Parent:WaitForChild("RateLimit"))
local Signal = require(script.Parent:WaitForChild("Signal"))

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "LihFolkRemotes"
local MAX_NAME_LENGTH = 48

export type Result = { ok: boolean, code: string, data: any? }
export type Validator = (value: any) -> boolean
export type Rate = { burst: number, perSecond: number }

export type HandleSpec = {
	rate: Rate,
	args: { Validator },
	handler: (Player, ...any) -> Result,
	-- Default true: one in-flight request per player for this remote ("Busy" otherwise).
	exclusive: boolean?,
}

export type ListenSpec = {
	rate: Rate,
	args: { Validator },
	handler: (Player, ...any) -> (),
}

export type Push = {
	Fire: (self: Push, player: Player, ...any) -> (),
	FireAll: (self: Push, ...any) -> (),
	FireList: (self: Push, players: { Player }, ...any) -> (),
}

local Net = {}

-- Fired on the server for every rejected call: (player, remoteName, code, detail).
-- Score these; do not kick on one (bad connections look like cheaters).
Net.Violation = Signal.new()

local registered: { [string]: boolean } = {}
local violationScore: { [Player]: { score: number, updated: number } } = {}
local lastWarn: { [Player]: number } = {}
local VIOLATION_DECAY_PER_SECOND = 0.2
local WARN_INTERVAL = 30

---------------------------------------------------------------------------
-- Validators (pure; usable on both sides and in tests)
---------------------------------------------------------------------------

local T = {}
Net.T = T

local function isFinite(n: number): boolean
	return n == n and n > -math.huge and n < math.huge
end

-- Whole number in [min, max]. Rejects NaN, infinity and fractions.
function T.integer(min: number, max: number): Validator
	assert(isFinite(min) and isFinite(max) and min <= max, "T.integer: bad range")
	return function(v: any): boolean
		return type(v) == "number" and v == v and v >= min and v <= max and math.floor(v) == v
	end
end

-- Any finite number in [min, max].
function T.number(min: number, max: number): Validator
	assert(isFinite(min) and isFinite(max) and min <= max, "T.number: bad range")
	return function(v: any): boolean
		return type(v) == "number" and v == v and v >= min and v <= max
	end
end

-- Valid UTF-8 string of at most maxBytes bytes, optionally matching a Lua pattern.
function T.string(maxBytes: number, pattern: string?): Validator
	assert(maxBytes >= 0 and maxBytes <= 10000, "T.string: bad length cap")
	return function(v: any): boolean
		if type(v) ~= "string" or #v > maxBytes or utf8.len(v) == nil then
			return false
		end
		return pattern == nil or string.match(v, pattern) ~= nil
	end
end

-- A string that is a key of `map` (an item id, egg id, quest id...).
-- The map must be a plain table built by your config, never client data.
function T.key(map: { [string]: any }): Validator
	return function(v: any): boolean
		return type(v) == "string" and #v <= 64 and rawget(map, v) ~= nil
	end
end

-- One of a fixed list of values (numbers, strings or booleans).
function T.oneOf(values: { any }): Validator
	return function(v: any): boolean
		local t = type(v)
		if t ~= "number" and t ~= "string" and t ~= "boolean" then
			return false
		end
		if t == "number" and v ~= v then
			return false
		end
		return table.find(values, v) ~= nil
	end
end

function T.boolean(v: any): boolean
	return type(v) == "boolean"
end

-- A GUID as produced by HttpService:GenerateGUID(false) (inventory uids).
function T.guid(v: any): boolean
	return type(v) == "string"
		and #v == 36
		and string.match(v, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

function T.optional(validator: Validator): Validator
	return function(v: any): boolean
		return v == nil or validator(v)
	end
end

-- Vector3 with finite components and magnitude <= maxMagnitude.
function T.vector3(maxMagnitude: number): Validator
	return function(v: any): boolean
		if typeof(v) ~= "Vector3" then
			return false
		end
		local vec = v :: Vector3
		return isFinite(vec.X) and isFinite(vec.Y) and isFinite(vec.Z) and vec.Magnitude <= maxMagnitude
	end
end

-- Dense array of at most maxLength items, each passing `item`.
function T.array(item: Validator, maxLength: number): Validator
	return function(v: any): boolean
		if type(v) ~= "table" then
			return false
		end
		local count = 0
		for key, value in v do
			count += 1
			if count > maxLength or type(key) ~= "number" or not item(value) then
				return false
			end
		end
		for i = 1, count do
			if v[i] == nil then
				return false
			end
		end
		return true
	end
end

-- An Instance of className that is a descendant of ancestor. Prefer sending ids.
function T.instance(className: string, ancestor: Instance): Validator
	return function(v: any): boolean
		return typeof(v) == "Instance" and (v :: Instance):IsA(className) and (v :: Instance):IsDescendantOf(ancestor)
	end
end

-- Checks a vararg list against validators. Extra arguments are rejected.
function Net.checkArgs(validators: { Validator }, ...: any): (boolean, string?)
	local count = select("#", ...)
	if count > #validators then
		return false, `expected at most {#validators} args, got {count}`
	end
	for i, validate in validators do
		local value = if i <= count then (select(i, ...)) else nil
		if not validate(value) then
			return false, `arg {i} rejected`
		end
	end
	return true, nil
end

function Net.ok(data: any?): Result
	return { ok = true, code = "Ok", data = data }
end

function Net.fail(code: string, data: any?): Result
	return { ok = false, code = code, data = data }
end

---------------------------------------------------------------------------
-- Server
---------------------------------------------------------------------------

local function getFolder(): Folder
	if IS_SERVER then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function createRemote(name: string, className: string): Instance
	assert(IS_SERVER, "Net: remotes are created by the server only")
	assert(type(name) == "string" and #name > 0 and #name <= MAX_NAME_LENGTH, "Net: bad remote name")
	assert(not registered[name], `Net: remote '{name}' declared twice`)
	registered[name] = true
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		existing:Destroy() -- never reuse an instance something else may have placed
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function checkRate(rate: Rate)
	assert(type(rate) == "table" and type(rate.burst) == "number" and type(rate.perSecond) == "number", "Net: spec.rate = { burst, perSecond } is required")
end

local function recordViolation(player: Player, name: string, code: string, detail: string?)
	local now = os.clock()
	local entry = violationScore[player]
	if not entry then
		entry = { score = 0, updated = now }
		violationScore[player] = entry
	end
	entry.score = math.max(0, entry.score - (now - entry.updated) * VIOLATION_DECAY_PER_SECOND)
	entry.updated = now
	entry.score += if code == "Invalid" then 1 else 0.25
	-- One log line per player per WARN_INTERVAL, never one per request.
	if code == "Invalid" and now - (lastWarn[player] or -math.huge) >= WARN_INTERVAL then
		lastWarn[player] = now
		warn(`[Net] {player.UserId} sent invalid '{name}' ({detail or "?"}); score {math.floor(entry.score)}`)
	end
	Net.Violation:Fire(player, name, code, detail)
end

-- Current decayed violation score for a player (server only).
function Net.GetViolationScore(player: Player): number
	local entry = violationScore[player]
	if not entry then
		return 0
	end
	return math.max(0, entry.score - (os.clock() - entry.updated) * VIOLATION_DECAY_PER_SECOND)
end

function Net.Handle(name: string, spec: HandleSpec)
	checkRate(spec.rate)
	assert(type(spec.args) == "table" and type(spec.handler) == "function", "Net.Handle: args and handler required")
	local remote = createRemote(name, "RemoteFunction") :: RemoteFunction
	local limiter = RateLimit.new(spec.rate.burst, spec.rate.perSecond)
	local exclusive = spec.exclusive ~= false
	local busy: { [Player]: boolean } = {}
	Players.PlayerRemoving:Connect(function(player: Player)
		busy[player] = nil
	end)

	remote.OnServerInvoke = function(player: Player, ...: any): Result
		if not limiter:Allow(player) then
			recordViolation(player, name, "TooFast", nil)
			return Net.fail("TooFast")
		end
		local valid, detail = Net.checkArgs(spec.args, ...)
		if not valid then
			recordViolation(player, name, "Invalid", detail)
			return Net.fail("Invalid")
		end
		if exclusive then
			if busy[player] then
				return Net.fail("Busy")
			end
			busy[player] = true
		end
		local success, result = pcall(spec.handler, player, ...)
		if exclusive then
			busy[player] = nil
		end
		if not success then
			warn(`[Net] handler '{name}' errored: {result}`)
			return Net.fail("Error")
		end
		if type(result) ~= "table" or type(result.ok) ~= "boolean" or type(result.code) ~= "string" then
			warn(`[Net] handler '{name}' returned a non-Result value`)
			return Net.fail("Error")
		end
		return result
	end
end

function Net.Listen(name: string, spec: ListenSpec)
	checkRate(spec.rate)
	assert(type(spec.args) == "table" and type(spec.handler) == "function", "Net.Listen: args and handler required")
	local remote = createRemote(name, "RemoteEvent") :: RemoteEvent
	local limiter = RateLimit.new(spec.rate.burst, spec.rate.perSecond)
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if not limiter:Allow(player) then
			recordViolation(player, name, "TooFast", nil)
			return
		end
		local valid, detail = Net.checkArgs(spec.args, ...)
		if not valid then
			recordViolation(player, name, "Invalid", detail)
			return
		end
		local success, err = pcall(spec.handler, player, ...)
		if not success then
			warn(`[Net] listener '{name}' errored: {err}`)
		end
	end)
end

-- Server -> client channel. Always send server-built values, never a
-- client's raw arguments relayed to everyone.
function Net.Push(name: string): Push
	local remote = createRemote(name, "RemoteEvent") :: RemoteEvent
	local push = {}
	function push.Fire(_self: any, player: Player, ...: any)
		if player.Parent == Players then
			remote:FireClient(player, ...)
		end
	end
	function push.FireAll(_self: any, ...: any)
		remote:FireAllClients(...)
	end
	function push.FireList(_self: any, players: { Player }, ...: any)
		for _, player in players do
			if player.Parent == Players then
				remote:FireClient(player, ...)
			end
		end
	end
	return (push :: any) :: Push
end

if IS_SERVER then
	Players.PlayerRemoving:Connect(function(player: Player)
		violationScore[player] = nil
		lastWarn[player] = nil
	end)
end

---------------------------------------------------------------------------
-- Client
---------------------------------------------------------------------------

local clientRemotes: { [string]: Instance } = {}

local function getClientRemote(name: string): Instance
	local cached = clientRemotes[name]
	if cached then
		return cached
	end
	local remote = getFolder():WaitForChild(name)
	clientRemotes[name] = remote
	return remote
end

-- Calls a Net.Handle remote. Never throws; network failures return code "NetworkError".
function Net.Request(name: string, ...: any): Result
	assert(not IS_SERVER, "Net.Request is client-only")
	local remote = getClientRemote(name)
	if not remote:IsA("RemoteFunction") then
		return Net.fail("NetworkError")
	end
	local ok, result = pcall((remote :: RemoteFunction).InvokeServer, remote :: RemoteFunction, ...)
	if not ok or type(result) ~= "table" then
		return Net.fail("NetworkError")
	end
	return result :: Result
end

function Net.Send(name: string, ...: any)
	assert(not IS_SERVER, "Net.Send is client-only")
	local remote = getClientRemote(name)
	if remote:IsA("RemoteEvent") then
		(remote :: RemoteEvent):FireServer(...)
	end
end

function Net.On(name: string, fn: (...any) -> ()): RBXScriptConnection
	assert(not IS_SERVER, "Net.On is client-only")
	local remote = getClientRemote(name)
	assert(remote:IsA("RemoteEvent"), `Net.On: '{name}' is not a push channel`)
	return (remote :: RemoteEvent).OnClientEvent:Connect(fn)
end

return Net
