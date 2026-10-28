---
tags: [worked-build, rebirth, prestige, progression, economy, datastore, ui, luau, simulators]
---
# Rebirth and Prestige System End to End

This note builds a two-layer reset system from an empty place: coins you earn, **rebirths** that reset coins for a permanent income multiplier (with single, x5 and "max" bulk buys computed in closed form), and **prestige**, which resets rebirths for a bigger multiplier and a token currency. It includes shared math used by both client and server, number formatting that never lies about affordability, a confirmation dialog, safe saving at the moments that matter, and a pacing worked example that shows why most rebirth curves hit a wall.

Design background: [[Progression Levels and Unlocks]], [[Progression and Pacing Design]], [[Economy Inflation Sinks and Faucets Math]], [[Genre Playbook - Simulators]], [[Balancing with Spreadsheets and Data]]. Other builds: [[Worked Builds Start Here]].

> **All code in this note is reviewed, not run.** Written against Roblox docs (as of October 2026) and checked by reading. Use section 8 to test it.

Labels: **Roblox docs (as of October 2026)**, **rule of thumb**.

---

## 1. Design decisions

| Question | Choice | Why |
|---|---|---|
| What a rebirth costs | `Base * Growth ^ rebirths` coins, spent, then all coins reset to 0 | Exponential cost against a linear multiplier is the classic shape; section 3 shows how to tune it |
| Bulk rebirths | Buy n at once for the sum of their costs; "Max" computes n in closed form | One at a time, the leftover after each reset is lost; bulk lets a big pile convert fully |
| Multiplier | `(1 + 0.5 * rebirths) * (1 + 1.0 * prestige)` | Rebirth adds, prestige multiplies, so prestige is always worth it once unlocked |
| Prestige requirement | 25 rebirths | Long enough to feel like a milestone, short enough to reach in a first week (rule of thumb) |
| Where the formulas live | `RebirthMath` in `ReplicatedStorage` | The button shows the same cost the server charges; no drift |
| How the client asks | `RemoteFunction`s that return `(ok, message)` | Client-to-server invokes are safe; the client wants a direct answer for the dialog |
| When to save | Immediately after every rebirth and prestige, plus autosave | These are the moments a lost save hurts most |

A note on `RemoteFunction`: invoking the **server** from the client is fine. The dangerous direction is the server invoking a client, which can hang forever or error if the client misbehaves (Roblox docs; see [[RemoteEvents RemoteFunctions and Unreliable Remotes]]).

**When not to build rebirths:** if your game's long-term goal is collection, story or skill, a reset loop feels like punishment. Rebirths suit number-goes-up games where the reset itself is satisfying because the next run is visibly faster (see [[Simulator and RNG Genre Teardown]]).

---

## 2. Folder layout

```
ReplicatedStorage
  Shared (Folder)
    RebirthMath (ModuleScript)
  RebirthRemotes (Folder, created by the server)
    Click (RemoteEvent)
    RequestRebirth (RemoteFunction)
    RequestPrestige (RemoteFunction)

ServerScriptService
  Modules (Folder)
    PlayerStore (ModuleScript)
    RateLimit (ModuleScript)
  RebirthService (Script)

StarterGui
  RebirthGui (ScreenGui, ResetOnSpawn = false)
    Stats (TextLabel)
    ClickButton (TextButton)
    RebirthButton (TextButton)
    BulkToggle (TextButton)
    PrestigeButton (TextButton, Visible = false)
    Confirm (Frame, Visible = false)
      Message (TextLabel)
      Yes (TextButton)
      No (TextButton)
    Toast (TextLabel, Visible = false)

StarterPlayer
  StarterPlayerScripts
    RebirthClient (LocalScript)
```

Enable **Game Settings > Security > Enable Studio Access to API Services** for save tests.

---

## 3. The math (shared)

```lua
--!strict
-- ReplicatedStorage/Shared/RebirthMath (ModuleScript). Reviewed, not run.
-- Used by the server to charge and by the client to display. One source of truth.
local RebirthMath = {
	BaseCost = 1000,
	Growth = 1.25,          -- cost multiplier per rebirth (see the pacing table below)
	MultPerRebirth = 0.5,   -- +0.5x income per rebirth
	MultPerPrestige = 1.0,  -- each prestige multiplies income by (1 + 1.0 * prestige)
	PrestigeRequirement = 25,
	MaxBulk = 1000,
	MaxCoins = 1e300,       -- hard cap so arithmetic never reaches infinity
}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end
RebirthMath.IsFinite = finite

-- Total cost of buying `count` rebirths starting from `rebirths` already owned.
-- Geometric series: B * g^r * (g^n - 1) / (g - 1).
function RebirthMath.CostOf(rebirths: number, count: number): number
	local b, g = RebirthMath.BaseCost, RebirthMath.Growth
	local cost = b * g ^ rebirths * (g ^ count - 1) / (g - 1)
	return if finite(cost) then cost else math.huge
end

-- Largest n with CostOf(rebirths, n) <= coins, capped at `cap`.
function RebirthMath.MaxAffordable(rebirths: number, coins: number, cap: number): number
	local b, g = RebirthMath.BaseCost, RebirthMath.Growth
	if coins < RebirthMath.CostOf(rebirths, 1) then
		return 0
	end
	local n = math.floor(math.log(1 + coins * (g - 1) / (b * g ^ rebirths)) / math.log(g))
	n = math.clamp(n, 0, cap)
	-- Floating point can be off by one either way; nudge to the exact answer.
	while n > 0 and RebirthMath.CostOf(rebirths, n) > coins do
		n -= 1
	end
	while n < cap and RebirthMath.CostOf(rebirths, n + 1) <= coins do
		n += 1
	end
	return n
end

function RebirthMath.Multiplier(rebirths: number, prestige: number): number
	return (1 + rebirths * RebirthMath.MultPerRebirth) * (1 + prestige * RebirthMath.MultPerPrestige)
end

function RebirthMath.PrestigeTokensFor(rebirths: number): number
	if rebirths < RebirthMath.PrestigeRequirement then
		return 0
	end
	return 1 + math.floor((rebirths - RebirthMath.PrestigeRequirement) / 10)
end

-- Short number format: 1.23K, 45.6M, 789B ... Truncates instead of rounding so the
-- label never shows "1.00M" for 999,999 (players read that as "I can afford it").
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
function RebirthMath.Format(n: number): string
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "inf"
	end
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local tier = math.floor(math.log10(n) / 3)
	if tier >= #SUFFIXES then
		return string.format("%.2e", n)
	end
	local scaled = n / 10 ^ (tier * 3)
	local digits = if scaled < 10 then 2 elseif scaled < 100 then 1 else 0
	local factor = 10 ^ digits
	scaled = math.floor(scaled * factor) / factor
	return string.format("%." .. digits .. "f%s", scaled, SUFFIXES[tier + 1])
end

return RebirthMath
```

### Pacing: the worked example

Assume a player earns `9 * multiplier` coins per second (1 passive plus about 8 clicks). Time to afford the *next* rebirth at rebirth count r:

| r | Cost, Growth 1.5 | Time at 1.5 | Cost, Growth 1.25 | Time at 1.25 | Multiplier |
|---|---|---|---|---|---|
| 0 | 1,000 | 1.9 min | 1,000 | 1.9 min | 1x |
| 10 | 57,665 | 18 min | 9,313 | 2.9 min | 6x |
| 20 | 3,325,257 | 9.3 h | 86,736 | 14.6 min | 11x |
| 25 | 25,251,169 | 2.4 days | 264,698 | 36 min | 13.5x |

(Computed from the formulas above; rounded.) With Growth 1.5 the curve walls at around rebirth 15: cost grows exponentially, the multiplier only linearly, so each rebirth takes 1.5 / (1 + 0.5 / mult) times longer than the last. Summed over all 25 steps, reaching the prestige gate takes about 3.2 hours of play with Growth 1.25 and about 130 hours with Growth 1.5 (same assumptions). Prestige then doubles income and resets the curve, which is the whole point of a second layer: it rescues the exponential wall instead of hiding it.

Rules of thumb for tuning:
- Pick a target time for the prestige gate (for example 4 to 8 hours of play) and solve Growth for it in a spreadsheet; see [[Balancing with Spreadsheets and Data]].
- Make every rebirth at least 2x income relative to what was lost, or the first rebirth feels like a mistake. Here, rebirth 1 takes you from 1x to 1.5x; consider a bigger first step (for example +1x for the first rebirth only).
- Watch inflation: anything priced in coins should scale with the multiplier, or late players buy everything instantly (see [[Economy Inflation Sinks and Faucets Math]]).

### Precision, NaN and infinity

Luau numbers are doubles. Whole numbers are exact only up to 2^53 (about 9.007e15). Above that, `coins + 1` can equal `coins`, and costs can compare equal when they are not (rule of thumb; standard IEEE 754 behaviour). Two consequences:
- If your economy will pass about 1e15, either accept approximate numbers (most simulators do, and players never notice at "4.5Qa") or store a mantissa and exponent pair. Do not use `IntValue` for display; this build uses attributes and formats them.
- **Never let NaN or infinity into saved data.** A `0/0` somewhere becomes NaN, NaN compares false with everything (so `coins < cost` is false and the purchase goes through), and saving it can fail or corrupt the record (rule of thumb). The server clamps every addition through `addCoins` below.

---

## 4. Server modules: PlayerStore and RateLimit

The same `PlayerStore` as every saving build in this folder (reasoning in [[Round-Based Minigame Loop End to End]] section 4):

```lua
--!strict
-- ServerScriptService/Modules/PlayerStore (ModuleScript). Reviewed, not run.
-- One record per player, simple session lock, autosave, save on leave and shutdown.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type Data = { [string]: any }

-- A separate store in Studio so tests never touch live player data.
local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio_v1" else "PlayerData_v1"
local AUTOSAVE_SECONDS = 120
local LOCK_STALE_SECONDS = 300 -- a lock older than this is treated as abandoned (crashed server)

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles: { [Player]: Data } = {}
local template: Data = {}
local started = false
local loadedCallbacks: { (Player) -> () } = {}

local PlayerStore = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function keyFor(player: Player): string
	return "u_" .. tostring(player.UserId)
end

-- Reads the record and claims the lock in one UpdateAsync.
local function loadAsync(player: Player): Data?
	for attempt = 1, 5 do
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return store:UpdateAsync(keyFor(player), function(old: any)
				lockedElsewhere = false
				local record = if type(old) == "table" then old else {}
				local lock = record._lock
				if type(lock) == "table" and lock.job ~= game.JobId
					and os.time() - (tonumber(lock.time) or 0) < LOCK_STALE_SECONDS then
					lockedElsewhere = true
					return nil -- cancel the write: another live server still owns this record
				end
				record._lock = { job = game.JobId, time = os.time() }
				return record
			end)
		end)
		if ok and not lockedElsewhere and type(result) == "table" then
			return result :: Data
		end
		if not ok then
			warn(`PlayerStore load failed for {player.UserId} (attempt {attempt}): {result}`)
		end
		if not player.Parent then
			return nil
		end
		task.wait(attempt * 3)
	end
	return nil
end

local function saveAsync(player: Player, release: boolean): boolean
	local data = profiles[player]
	if not data then
		return true
	end
	local snapshot = deepCopy(data)
	snapshot._lock = if release then nil else { job = game.JobId, time = os.time() }
	for attempt = 1, 4 do
		local stolen = false
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old: any)
				stolen = false
				if type(old) == "table" and type(old._lock) == "table" and old._lock.job ~= game.JobId then
					stolen = true
					return nil -- another server took over; never overwrite its newer data
				end
				return snapshot
			end)
		end)
		if ok then
			if stolen then
				warn(`PlayerStore: record for {player.UserId} is locked elsewhere, save skipped`)
			end
			return not stolen
		end
		warn(`PlayerStore save failed for {player.UserId} (attempt {attempt}): {err}`)
		task.wait(attempt * 2)
	end
	return false
end

local function onPlayerAdded(player: Player)
	local record = loadAsync(player)
	if not record then
		if player.Parent then
			player:Kick("Your data could not be loaded. Please rejoin in a minute.")
		end
		return
	end
	for key, value in template do
		if record[key] == nil then
			record[key] = deepCopy(value)
		end
	end
	profiles[player] = record
	if not player.Parent then
		-- Left while we were loading: release the lock we just took.
		saveAsync(player, true)
		profiles[player] = nil
		return
	end
	player:SetAttribute("DataLoaded", true)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		saveAsync(player, true)
		profiles[player] = nil
	end
end

function PlayerStore.Start(newTemplate: Data)
	assert(not started, "PlayerStore.Start called twice")
	started = true
	template = newTemplate
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveAsync(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25 -- BindToClose gets about 30 s in total (Roblox docs)
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in profiles do
				task.spawn(saveAsync, player, false)
				task.wait(1) -- spread requests so one autosave tick does not burst the budget
			end
		end
	end)
end

-- Callbacks get the Player only; read the live table with Get.
function PlayerStore.OnLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in profiles do
		task.spawn(callback, player)
	end
end

function PlayerStore.Get(player: Player): Data?
	return profiles[player]
end

-- For high-value moments (a rebirth, a rare hatch). Do not call every frame.
function PlayerStore.SaveNow(player: Player)
	task.spawn(saveAsync, player, false)
end

return PlayerStore
```

And the per-player token bucket:

```lua
--!strict
-- ServerScriptService/Modules/RateLimit (ModuleScript). Reviewed, not run.
-- newLimiter(capacity, refillPerSecond) returns allow(player) -> boolean.
local Players = game:GetService("Players")

local function newLimiter(capacity: number, refillPerSecond: number): (Player) -> boolean
	local buckets: { [Player]: { tokens: number, at: number } } = {}
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
	return function(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player] or { tokens = capacity, at = now }
		buckets[player] = bucket
		bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.at) * refillPerSecond)
		bucket.at = now
		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end
end

return newLimiter
```

---

## 5. RebirthService (server)

```lua
--!strict
-- ServerScriptService/RebirthService (Script). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local PlayerStore = require(ServerScriptService.Modules.PlayerStore)
local newLimiter = require(ServerScriptService.Modules.RateLimit)

-- Fields reset by each layer. Put upgrades bought with coins in RESET_ON_REBIRTH.
local RESET_ON_REBIRTH: { [string]: any } = { Coins = 0 }
local RESET_ON_PRESTIGE: { [string]: any } = { Coins = 0, Rebirths = 0 }

PlayerStore.Start({
	Coins = 0,
	LifetimeCoins = 0, -- never reset; good for leaderboards and analytics
	Rebirths = 0,
	Prestige = 0,
	PrestigeTokens = 0,
})

---------------------------------------------------------------- remotes
local remotes = Instance.new("Folder")
remotes.Name = "RebirthRemotes"
local clickRemote = Instance.new("RemoteEvent")
clickRemote.Name = "Click"
clickRemote.Parent = remotes
local rebirthFunction = Instance.new("RemoteFunction")
rebirthFunction.Name = "RequestRebirth"
rebirthFunction.Parent = remotes
local prestigeFunction = Instance.new("RemoteFunction")
prestigeFunction.Name = "RequestPrestige"
prestigeFunction.Parent = remotes
remotes.Parent = ReplicatedStorage

local clickAllowed = newLimiter(15, 12)   -- about the ceiling of fast human clicking
local rebirthAllowed = newLimiter(3, 1)
local prestigeAllowed = newLimiter(2, 0.5)

---------------------------------------------------------------- state publishing
local function publish(player: Player, data: PlayerStore.Data)
	-- Attributes hold doubles, so big numbers survive; the client formats them.
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("Prestige", data.Prestige)
	player:SetAttribute("PrestigeTokens", data.PrestigeTokens)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins") :: StringValue?
		local rebirths = leaderstats:FindFirstChild("Rebirths") :: IntValue?
		if coins then
			coins.Value = RebirthMath.Format(data.Coins)
		end
		if rebirths then
			rebirths.Value = data.Rebirths
		end
	end
end

local function addCoins(data: PlayerStore.Data, amount: number)
	if not RebirthMath.IsFinite(amount) or amount <= 0 then
		return
	end
	data.Coins = math.min(RebirthMath.MaxCoins, data.Coins + amount)
	data.LifetimeCoins = math.min(RebirthMath.MaxCoins, data.LifetimeCoins + amount)
end

local function applyReset(data: PlayerStore.Data, resets: { [string]: any })
	for key, value in resets do
		data[key] = value
	end
end

PlayerStore.OnLoaded(function(player: Player)
	local data = PlayerStore.Get(player)
	if not data then
		return
	end
	-- Repair anything a past bug may have saved.
	for _, key in { "Coins", "LifetimeCoins", "Rebirths", "Prestige", "PrestigeTokens" } do
		local value = data[key]
		if typeof(value) ~= "number" or not RebirthMath.IsFinite(value) or value < 0 then
			warn(`Repairing {key} for {player.UserId}: {value}`)
			data[key] = 0
		end
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	-- Rebirths first: the player list sorts by the first stat, and a StringValue sorts as text.
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	leaderstats.Parent = player
	publish(player, data)
end)

---------------------------------------------------------------- income
clickRemote.OnServerEvent:Connect(function(player: Player)
	if not clickAllowed(player) then
		return
	end
	local data = PlayerStore.Get(player)
	if data then
		addCoins(data, RebirthMath.Multiplier(data.Rebirths, data.Prestige))
		publish(player, data)
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local data = PlayerStore.Get(player)
			if data then
				addCoins(data, RebirthMath.Multiplier(data.Rebirths, data.Prestige))
				publish(player, data)
			end
		end
	end
end)

---------------------------------------------------------------- rebirth
local function parseCount(raw: unknown, data: PlayerStore.Data): number?
	if raw == "max" then
		local n = RebirthMath.MaxAffordable(data.Rebirths, data.Coins, RebirthMath.MaxBulk)
		return if n >= 1 then n else nil
	end
	if typeof(raw) ~= "number" then
		return nil
	end
	-- NaN fails raw == raw; fractions fail the modulo; bounds stop huge or negative counts.
	if raw ~= raw or raw % 1 ~= 0 or raw < 1 or raw > RebirthMath.MaxBulk then
		return nil
	end
	return raw
end

rebirthFunction.OnServerInvoke = function(player: Player, rawCount: unknown): (boolean, string)
	if not rebirthAllowed(player) then
		return false, "Slow down"
	end
	local data = PlayerStore.Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local count = parseCount(rawCount, data)
	if not count then
		return false, "Not enough coins"
	end
	local cost = RebirthMath.CostOf(data.Rebirths, count)
	if not RebirthMath.IsFinite(cost) or data.Coins < cost then
		return false, `Need {RebirthMath.Format(cost)} coins`
	end

	-- Check and apply with no yield in between: a duplicate request queued behind
	-- this one sees the reset coins and fails the check above.
	local before = RebirthMath.Multiplier(data.Rebirths, data.Prestige)
	data.Rebirths += count
	applyReset(data, RESET_ON_REBIRTH)
	local after = RebirthMath.Multiplier(data.Rebirths, data.Prestige)

	publish(player, data)
	PlayerStore.SaveNow(player)
	return true, `Rebirth x{count}! Income {before}x -> {after}x`
end

---------------------------------------------------------------- prestige
prestigeFunction.OnServerInvoke = function(player: Player): (boolean, string)
	if not prestigeAllowed(player) then
		return false, "Slow down"
	end
	local data = PlayerStore.Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local tokens = RebirthMath.PrestigeTokensFor(data.Rebirths)
	if tokens < 1 then
		return false, `Reach {RebirthMath.PrestigeRequirement} rebirths first`
	end

	data.Prestige += 1
	data.PrestigeTokens += tokens
	applyReset(data, RESET_ON_PRESTIGE)

	publish(player, data)
	PlayerStore.SaveNow(player)
	return true, `Prestige {data.Prestige}! +{tokens} tokens`
end
```

Points worth slowing down for:
- **`parseCount` treats the client's number as hostile.** `0/0` (NaN), `-5`, `2.5`, `1e308` and `"10"` are all rejected. NaN is the sneaky one: every comparison with NaN is false, so a naive `if data.Coins < cost then return end` with a NaN cost lets the purchase through.
- **"Max" is computed on the server.** The client sends the word, not a number it calculated. If the client's view of coins is a second stale, the server's answer is still right.
- **The cost is spent and the remainder reset.** That is a design choice. The alternative ("cost is a threshold, you keep nothing anyway") is identical for single rebirths but makes bulk buys meaningless. If you want players to keep leftover coins, change `RESET_ON_REBIRTH` to subtract `cost` instead of zeroing.
- **`SaveNow` after each reset.** A player who rebirths 20 times and then loses the session to a server crash before autosave is the angriest player you will meet. `PlayerStore.SaveNow` is fire-and-forget; DataStore request budgets are per server and scale with player count (Roblox docs), and the per-key write cooldown is short, so occasional extra saves are fine. Do not call it on every click.

---

## 6. Client and UI wiring

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/RebirthClient (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RebirthMath"))
local remotes = ReplicatedStorage:WaitForChild("RebirthRemotes")
local clickRemote = remotes:WaitForChild("Click") :: RemoteEvent
local rebirthFunction = remotes:WaitForChild("RequestRebirth") :: RemoteFunction
local prestigeFunction = remotes:WaitForChild("RequestPrestige") :: RemoteFunction

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("RebirthGui") :: ScreenGui
local stats = gui:WaitForChild("Stats") :: TextLabel
local clickButton = gui:WaitForChild("ClickButton") :: TextButton
local rebirthButton = gui:WaitForChild("RebirthButton") :: TextButton
local bulkToggle = gui:WaitForChild("BulkToggle") :: TextButton
local prestigeButton = gui:WaitForChild("PrestigeButton") :: TextButton
local confirm = gui:WaitForChild("Confirm") :: Frame
local confirmMessage = confirm:WaitForChild("Message") :: TextLabel
local yesButton = confirm:WaitForChild("Yes") :: TextButton
local noButton = confirm:WaitForChild("No") :: TextButton
local toast = gui:WaitForChild("Toast") :: TextLabel

local BULK_MODES: { number | string } = { 1, 5, "max" }
local bulkIndex = 1
local pending = false
local confirmAction: (() -> ())? = nil

local function num(name: string): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function showToast(text: string)
	toast.Text = text
	toast.Visible = true
	task.delay(2.5, function()
		if toast.Text == text then
			toast.Visible = false
		end
	end)
end

-- What the current bulk mode would buy right now (display only; the server decides).
local function plannedCount(): number
	local mode = BULK_MODES[bulkIndex]
	if mode == "max" then
		return RebirthMath.MaxAffordable(num("Rebirths"), num("Coins"), RebirthMath.MaxBulk)
	end
	return mode :: number
end

local function refresh()
	local coins, rebirths, prestige = num("Coins"), num("Rebirths"), num("Prestige")
	local mult = RebirthMath.Multiplier(rebirths, prestige)
	stats.Text = `Coins {RebirthMath.Format(coins)}   x{mult} income   Rebirths {rebirths}   Prestige {prestige}`

	local mode = BULK_MODES[bulkIndex]
	bulkToggle.Text = if mode == "max" then "Bulk: Max" else `Bulk: x{mode}`

	local count = plannedCount()
	if count >= 1 then
		local cost = RebirthMath.CostOf(rebirths, count)
		rebirthButton.Text = `Rebirth x{count} ({RebirthMath.Format(cost)})`
		rebirthButton.AutoButtonColor = coins >= cost
		rebirthButton.BackgroundTransparency = if coins >= cost then 0 else 0.5
	else
		rebirthButton.Text = `Rebirth ({RebirthMath.Format(RebirthMath.CostOf(rebirths, 1))})`
		rebirthButton.BackgroundTransparency = 0.5
	end

	local tokens = RebirthMath.PrestigeTokensFor(rebirths)
	prestigeButton.Visible = tokens >= 1
	prestigeButton.Text = `Prestige (+{tokens} tokens)`
end

for _, name in { "Coins", "Rebirths", "Prestige" } do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()

local function ask(message: string, action: () -> ())
	confirmMessage.Text = message
	confirmAction = action
	confirm.Visible = true
end

yesButton.Activated:Connect(function()
	confirm.Visible = false
	local action = confirmAction
	confirmAction = nil
	if action then
		action()
	end
end)
noButton.Activated:Connect(function()
	confirm.Visible = false
	confirmAction = nil
end)

local function invoke(fn: RemoteFunction, arg: any?)
	if pending then
		return
	end
	pending = true
	local ok, _success, message = pcall(function()
		return fn:InvokeServer(arg)
	end)
	pending = false
	if not ok then
		showToast("Something went wrong, try again")
	elseif typeof(message) == "string" then
		showToast(message)
	end
end

clickButton.Activated:Connect(function()
	clickRemote:FireServer()
end)

bulkToggle.Activated:Connect(function()
	bulkIndex = bulkIndex % #BULK_MODES + 1
	refresh()
end)

rebirthButton.Activated:Connect(function()
	local count = plannedCount()
	if count < 1 then
		showToast("Not enough coins yet")
		return
	end
	local rebirths, prestige = num("Rebirths"), num("Prestige")
	local now = RebirthMath.Multiplier(rebirths, prestige)
	local after = RebirthMath.Multiplier(rebirths + count, prestige)
	ask(`Reset your coins for {count} rebirth(s)? Income {now}x -> {after}x`, function()
		invoke(rebirthFunction, BULK_MODES[bulkIndex])
	end)
end)

prestigeButton.Activated:Connect(function()
	local tokens = RebirthMath.PrestigeTokensFor(num("Rebirths"))
	ask(`Prestige resets coins AND rebirths. You get +{tokens} tokens and a permanent boost. Continue?`, function()
		invoke(prestigeFunction, nil)
	end)
end)
```

UI notes:
- **Always confirm a reset.** One mis-tap on a phone that wipes an evening of coins is a top reason for negative reviews in this genre (rule of thumb). Make the prestige dialog say exactly what is lost.
- **The button never lies.** It shows the cost from the same `RebirthMath` the server uses, formatted with truncation.
- **Click button** is here to make income testable. In a real game it is your core action (swing, mine, collect).
- Layout and phone sizing: [[Menu Archetypes - Shop Settings Codes Rewards]], [[Responsive UI for Phone Tablet Console and PC]], [[UI Motion Language and Timing]] for the reset celebration.

---

## 7. Leaderstats and leaderboards

The player list sorts by the first stat in `leaderstats` (rule of thumb, long-standing behaviour). `Rebirths` is an `IntValue` and comes first, so sorting is numeric and meaningful. `Coins` is a formatted `StringValue` for readability; a `StringValue` sorts as text ("9K" above "10M"), which is why it must not be first.

For a global board, rank by `Rebirths` or `LifetimeCoins` in an ordered store. Ordered data stores hold integers, so for huge `LifetimeCoins` store a log-scaled value (for example `math.floor(math.log10(coins) * 1000)`) and convert back for display. See [[Global Leaderboards End to End]] and [[OrderedDataStores and Leaderboards]].

---

## 8. Testing in Studio

1. **Basics.** Play. Coins tick up by 1 per second; clicking adds 1 per click. At 1,000 coins, the rebirth button lights up. Rebirth: coins go to 0, the multiplier shows 1.5x, and income becomes 1.5 per tick and per click.
2. **Bulk math.** In the server command bar, give coins:
   ```lua
   local p = game.Players:GetPlayers()[1]
   local store = require(game.ServerScriptService.Modules.PlayerStore)
   store.Get(p).Coins = 1e6
   ```
   Switch to Bulk: Max. The button should show the count `RebirthMath.MaxAffordable(0, 1e6, 1000)` returns (with Growth 1.25 and Base 1000, that is 24: 24 rebirths cost about 843K, 25 would cost about 1.05M). Rebirth; you get exactly that many.
3. **Formatting edges.** In the command bar: `print(require(game.ReplicatedStorage.Shared.RebirthMath).Format(999999))` must print `999K`, not `1000K` or `1.00M`. Also try `1e15`, `1e40`, `0/0`.
4. **Abuse** (client command bar):
   - `game.ReplicatedStorage.RebirthRemotes.RequestRebirth:InvokeServer(0/0)` returns false.
   - `...:InvokeServer(-5)`, `(2.5)`, `(1e308)`, `("10")`, `({})`: all false.
   - `for i = 1, 50 do task.spawn(function() print(game.ReplicatedStorage.RebirthRemotes.RequestRebirth:InvokeServer(1)) end) end` with enough coins for exactly one rebirth: exactly one `true`.
   - `for i = 1, 1000 do game.ReplicatedStorage.RebirthRemotes.Click:FireServer() end`: coins rise by about 15, not 1,000.
5. **Prestige.** Give yourself 25 rebirths via the command bar (`store.Get(p).Rebirths = 25`), wait one second for the income tick to publish it, then prestige. Coins and rebirths are 0, prestige 1, multiplier 2x.
6. **Persistence.** Rebirth, then stop immediately (within 2 seconds). Play again: the rebirth must be there (that is `SaveNow` plus `BindToClose`).
7. **Corrupt data repair.** Set `store.Get(p).Coins = 0/0`, stop, play: a "Repairing Coins" warning and coins at 0.

---

## 9. Exploits it must resist

| Attack | Defence |
|---|---|
| Rebirth without enough coins | Server computes cost from server data |
| NaN, negative, fractional, huge or string counts | `parseCount` rejects them |
| Many parallel requests to get several rebirths for one price | No yield between check and reset; the second sees 0 coins |
| Autoclicker or click remote loop | Token bucket at human-fast rates |
| Faked multiplier | Multiplier is derived from saved counts on the server; the client never sends it |
| Prestige without meeting the requirement | Server check |
| Server-hop duplication | PlayerStore session lock |
| Infinite coins via overflow to infinity | `MaxCoins` clamp and finite checks |

More: [[Economy Exploits - Dupes Races and Purchase Abuse]], [[Remote Abuse Patterns and Rate Limiting in Practice]].

---

## 10. Common mistakes

- **Formulas typed twice**, once in the GUI and once on the server. They drift after the first balance patch, and players see one price and pay another.
- **Rounding up in labels.** "1.00M" for 999,999 coins makes players press a button that then refuses.
- **Rebirth cost growth with no second layer.** The curve walls (section 3), players quit around the wall, and the fix is either retuning (which changes everyone's numbers) or adding prestige late.
- **Resetting things players paid Robux for.** Never put game pass or product rewards in a reset list (see [[Ethical Design and Player Trust]]).
- **Saving on every click.** Burns the DataStore budget; autosave plus save-on-reset is enough.
- **Trusting `IsFinite` only on input.** Check results too: a multiplier formula that divides can produce NaN from valid inputs.

---

## 11. Extending it

- **Upgrades that reset.** Add `ClickLevel` to data and to `RESET_ON_REBIRTH`; price upgrades with the multiplier in mind.
- **Prestige shop.** Spend `PrestigeTokens` on permanent perks (auto-clicker, offline earnings). Perks live outside both reset lists.
- **Rebirth rewards.** Pets from [[Pet Hatching and Following End to End]] or items from [[Saved Inventory End to End]] at milestones (5, 10, 25 rebirths).
- **Game pass multipliers.** Multiply in `RebirthMath.Multiplier` with a flag the server sets from ownership; never trust the client's claim (see [[Shop with Game Passes and Developer Products End to End]]).
- **A third layer** (ascension) follows the same pattern: requirement on prestige count, resets prestige and below.
- **Quests** that reward rebirth progress: [[Quest Chain System End to End]].
- **Analytics.** Log the time between rebirths per player to find the wall in live data (see [[Analytics and Funnels]]).

---

## 12. Checklist

- [ ] One `RebirthMath` module used by both client and server
- [ ] Bulk "max" computed on the server; counts validated for NaN, fractions, bounds and type
- [ ] No yield between affordability check and reset
- [ ] All coin additions clamped and finite-checked; load repairs bad values
- [ ] `SaveNow` after rebirth and prestige; autosave and BindToClose in place
- [ ] Confirmation dialogs for both resets
- [ ] Leaderstats: numeric stat first
- [ ] Pacing table filled in for your real income rates

## See also
[[Worked Builds Start Here]] · [[Progression Levels and Unlocks]] · [[Progression and Pacing Design]] · [[Economy Inflation Sinks and Faucets Math]] · [[Genre Playbook - Simulators]] · [[Global Leaderboards End to End]] · [[Pet Hatching and Following End to End]]

## Connected notes
<!-- auto-links:start -->
[[Pricing Curves and Upgrade Costs]] · [[Big Numbers Precision and Formatting]] · [[Power Curve]] · [[Faucets and Sinks]] · [[Economies and Currencies]] · [[Currency Architecture - Soft Hard and Event Currencies]]
<!-- auto-links:end -->
