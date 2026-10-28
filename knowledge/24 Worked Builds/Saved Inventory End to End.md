---
tags: [worked-build, inventory, datastore, session-locking, remotes, ui, luau, strict]
---
# Saved Inventory End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Granting with `PlayerData.Get(player)` returning nil and not checking it: the grant silently does nothing.
> - Avoid: Yielding (a `task.wait`, a data store call, `GetProductInfoAsync`) between "check the player owns it" and "remove it".
> - Avoid: Saving inside every action. Writes are budgeted; save on the autosave and after purchases only.
> - Studio API access on, Studio keys separate from live keys
> - Only `PlayerData` touches the player data store
> - Every remote payload type-checked, length-capped, rate-limited
>
> Read more (42 KB note): ## 4. The data layer · ## 5. The inventory itself · ## Common mistakes · ## Checklist
<!-- tldr:end -->

This build starts from an empty place and ends with a saved, session-locked inventory: stackable items (potions, ores) and unique items (a sword with its own level), a coin balance, equip and sell actions over a validated remote, a grid UI, and a tool that appears in the player's hand when they equip a weapon. It is also the **foundation build** for this folder: the data layer, the remote helper and the rate limiter written here are reused by [[Daily Rewards System End to End]], [[Shop with Game Passes and Developer Products End to End]], [[Codes Redemption System End to End]] and [[Global Leaderboards End to End]]. Build this one first.

All code below is **reviewed, not run**. It is written in strict Luau against the APIs as documented on create.roblox.com (as of October 2026), but nobody has pressed Play on this exact text. Expect a typo-level fix or two, and test it the way the testing section describes before trusting it with real players.

The deep reasoning behind each choice lives in other notes. This note is the assembled version: [[DataStore Fundamentals]], [[Session Locking and Profile Libraries]], [[Saving Correctly - Autosave and BindToClose]], [[Data Schema Design and Migrations]], [[Tools and Inventory Systems]], [[Server Authority and Validation]].

---

## 1. What you are building, and what you are not

| In scope | Out of scope (and where it lives) |
|---|---|
| One saved profile per player, session-locked | Trading between players: [[Trading Systems Without Duplication]] |
| Stackable items with a max stack, unique items with per-item data | Thousands of items in one list: [[Virtualized Lists and Large Inventories]] |
| Equip (gives a Tool), sell (gives coins) | Crafting, drops: build on `InventoryService.Add` |
| Server-pushed snapshot to the client | Fancy UI animation: [[UI Motion Language and Timing]] |
| Studio test key so tests never touch real saves | Profile libraries: [[Session Locking and Profile Libraries]] compares them |

Why write your own data layer rather than drop in a library? You do not have to. A mature profile library is a fine choice. The module here is about 250 lines so that every behaviour is visible: when it claims, when it saves, what happens on a failed load. If you swap in a library later, the services only touch four functions (`Get`, `WaitForProfile`, `OnLoaded`, `SaveNowAsync`), so the swap is small.

---

## 2. Folder layout

Create these instances in Studio (or map them with Rojo, see [[External Tooling - Rojo Wally Selene StyLua]]):

```
ReplicatedStorage
  Shared (Folder)
    Net (ModuleScript)
    ItemCatalog (ModuleScript)
ServerScriptService
  Server (Folder)
    Main (Script)
    PlayerData (ModuleScript)
    DataTemplate (ModuleScript)
    RateLimiter (ModuleScript)
    Services (Folder)
      InventoryService (ModuleScript)
ServerStorage
  ItemTools (Folder)
    IronSword (Tool)        -- one Tool per equippable item, named by ItemId
StarterPlayer
  StarterPlayerScripts
    Client (Folder)
      InventoryController (LocalScript)
```

The rule behind the layout (see [[Project Structure and Bootstrapping]]): one `Script` on the server (`Main`) and one `LocalScript` per client feature; everything else is a `ModuleScript` required in a known order. Item definitions live in `ReplicatedStorage` because the client needs names and icons. Tools live in `ServerStorage` because the client must never be able to clone them itself.

Turn on **Game Settings, Security, Enable Studio Access to API Services** (Roblox docs) or every data store call in Studio fails with an error.

---

## 3. Shared plumbing

### 3.1 Net: one place that creates remotes

The server creates remotes on demand; the client waits for them. No remote is placed by hand, so a typo in a name fails loudly at one place.

```lua
--!strict
-- ReplicatedStorage/Shared/Net (ModuleScript). Reviewed, not run.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"

local Net = {}

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

function Net.Event(name: string): RemoteEvent
	local folder = getFolder()
	if IS_SERVER then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	local folder = getFolder()
	if IS_SERVER then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteFunction") then
			return existing
		end
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
```

`RemoteFunction` is used only client to server. The server never calls `InvokeClient`: a client that never answers would hang the server thread forever ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]).

### 3.2 RateLimiter: a token bucket per player

```lua
--!strict
-- ServerScriptService/Server/RateLimiter (ModuleScript). Reviewed, not run.
-- RateLimiter.new(capacity, refillPerSecond) returns allow(player): boolean.
local Players = game:GetService("Players")

type Bucket = { Tokens: number, Updated: number }

local RateLimiter = {}
local allBuckets: { { [Player]: Bucket } } = {}

function RateLimiter.new(capacity: number, refillPerSecond: number): (Player) -> boolean
	local buckets: { [Player]: Bucket } = {}
	table.insert(allBuckets, buckets)
	return function(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket then
			bucket = { Tokens = capacity, Updated = now }
			buckets[player] = bucket
		end
		bucket.Tokens = math.min(capacity, bucket.Tokens + (now - bucket.Updated) * refillPerSecond)
		bucket.Updated = now
		if bucket.Tokens < 1 then
			return false
		end
		bucket.Tokens -= 1
		return true
	end
end

-- One cleanup for every limiter, so leaving players do not leak buckets.
Players.PlayerRemoving:Connect(function(player: Player)
	for _, buckets in allBuckets do
		buckets[player] = nil
	end
end)

return RateLimiter
```

A bucket of capacity 8 refilling 4 per second allows a burst of 8 clicks, then 4 per second sustained. That is generous for a human and useless for a spam loop. Numbers are a rule of thumb; [[Remote Abuse Patterns and Rate Limiting in Practice]] explains how to pick them per remote.

---

## 4. The data layer

### 4.1 DataTemplate: shape, defaults, migration

Every field any build in this folder needs lives here, so a profile has one shape. New fields added later are filled in by `reconcile` without a migration; renames and type changes go through `migrations` ([[Schema Migrations - Worked Case Studies]]).

```lua
--!strict
-- ServerScriptService/Server/DataTemplate (ModuleScript). Reviewed, not run.
local CURRENT_VERSION = 1

export type UniqueItem = { ItemId: string, Level: number, CreatedAt: number }
export type Inventory = {
	Stacks: { [string]: number }, -- ItemId -> count
	Uniques: { [string]: UniqueItem }, -- uid -> item
	Equipped: string, -- uid of the equipped unique, "" for none
}
export type Data = {
	SchemaVersion: number,
	Coins: number,
	Inventory: Inventory,
	Daily: { LastClaimDay: number, Streak: number },
	RedeemedCodes: { [string]: number }, -- code -> unix time redeemed
	Receipts: { [string]: number }, -- PurchaseId -> unix time granted
	Stats: { CoinsEarned: number },
	Weekly: { WeekIndex: number, CoinsEarned: number },
}

local DataTemplate = {}
DataTemplate.CurrentVersion = CURRENT_VERSION

function DataTemplate.new(): Data
	return {
		SchemaVersion = CURRENT_VERSION,
		Coins = 0,
		Inventory = { Stacks = {}, Uniques = {}, Equipped = "" },
		Daily = { LastClaimDay = -1, Streak = 0 },
		RedeemedCodes = {},
		Receipts = {},
		Stats = { CoinsEarned = 0 },
		Weekly = { WeekIndex = -1, CoinsEarned = 0 },
	}
end

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
DataTemplate.deepCopy = deepCopy

-- Fill fields that are missing; never overwrite existing ones.
-- Empty template tables (Stacks, Uniques...) are maps of player content: do not recurse into them.
local function reconcile(target: { [string]: any }, template: { [string]: any })
	for key, defaultValue in template do
		local current = target[key]
		if current == nil then
			target[key] = deepCopy(defaultValue)
		elseif type(defaultValue) == "table" and type(current) == "table" and next(defaultValue) ~= nil then
			reconcile(current, defaultValue)
		end
	end
end

-- migrations[n] upgrades a version n-1 document to version n.
local migrations: { [number]: (data: { [string]: any }) -> () } = {
	-- [2] = function(data) data.Gems = data.Diamonds or 0; data.Diamonds = nil end,
}

-- Returns ready-to-use data, or nil and a reason. Never returns defaults for corrupt data.
function DataTemplate.prepare(raw: any): (Data?, string?)
	if raw == nil then
		return DataTemplate.new(), nil
	end
	if type(raw) ~= "table" then
		return nil, "corrupt"
	end
	local version = if type(raw.SchemaVersion) == "number" then raw.SchemaVersion else 0
	if version > CURRENT_VERSION then
		-- Saved by a newer server build. Loading it here and saving later would erase new fields.
		return nil, "newer"
	end
	for v = version + 1, CURRENT_VERSION do
		local migrate = migrations[v]
		if migrate then
			migrate(raw)
		end
		raw.SchemaVersion = v
	end
	reconcile(raw, DataTemplate.new() :: any)
	if type(raw.Coins) ~= "number" or raw.Coins ~= raw.Coins then
		return nil, "corrupt"
	end
	return raw :: Data, nil
end

return DataTemplate
```

Two non-obvious decisions:

- **"newer" refuses to load.** During a rolling update, old and new servers run side by side. A player who played on a new server and then lands on an old one would otherwise have their new fields silently stripped on the next save ([[Release Process and Rollbacks]]). Kicking with "please rejoin" is far cheaper than a data loss ticket.
- **Corrupt data never becomes defaults.** A default profile that saves over a real one is the most common way games destroy progress ([[Data Loss Prevention and Recovery]]).

### 4.2 PlayerData: claim, save, release

The record stored under each key is `{ Data = ..., Session = { Token, JobId, ExpiresAt } }`. A server owns a profile while its token is in the record and the lease has not expired. Every save checks the token inside `UpdateAsync`, so a server that has lost ownership can never overwrite newer data. The full reasoning is in [[Session Locking and Profile Libraries]]; this is a compact version.

```lua
--!strict
-- ServerScriptService/Server/PlayerData (ModuleScript). Reviewed, not run.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataTemplate = require(script.Parent.DataTemplate)

local STORE_NAME = "PlayerData_v1"
local LEASE_SECONDS = 120
local AUTOSAVE_SECONDS = 60
local CLAIM_ATTEMPTS = 5
local SAVE_ATTEMPTS = 3
local MIN_SAVE_SPACING = 6 -- seconds between writes to one key (rule of thumb)
local IS_STUDIO = RunService:IsStudio()

local store = DataStoreService:GetDataStore(STORE_NAME)

type Session = { Token: string, JobId: string, ExpiresAt: number }
type Record = { Data: any?, Session: Session? }
type ClaimStatus = "ready" | "locked" | "failed"

export type Profile = {
	Player: Player,
	Key: string,
	Token: string,
	Data: DataTemplate.Data,
	State: "active" | "lost" | "released",
	Saving: boolean,
	LastSave: number,
}

local PlayerData = {}

local profiles: { [Player]: Profile } = {}
local releasing: { [Profile]: boolean } = {}
local loadedCallbacks: { (Profile) -> () } = {}

local function keyFor(userId: number): string
	if IS_STUDIO then
		-- Studio never touches live saves. Set ServerStorage attribute TestProfileKey
		-- to a short word to get a fresh profile; clear it to return to your Studio save.
		local test = ServerStorage:GetAttribute("TestProfileKey")
		if type(test) == "string" and test ~= "" and #test <= 20 then
			return `STUDIO_{test}_{userId}`
		end
		return `STUDIO_{userId}`
	end
	return `U_{userId}`
end

local function claimAsync(key: string, token: string): (ClaimStatus, any)
	local status: ClaimStatus = "failed"
	local data: any = nil
	for attempt = 1, CLAIM_ATTEMPTS do
		status = "failed"
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old: Record?): Record?
				local now = os.time()
				local record: Record = old or {}
				local session = record.Session
				if session and session.Token ~= token and session.ExpiresAt > now then
					status = "locked"
					return nil -- cancel the write: someone else owns it
				end
				record.Session = { Token = token, JobId = game.JobId, ExpiresAt = now + LEASE_SECONDS }
				status = "ready"
				data = record.Data
				return record
			end)
		end)
		if not ok then
			status = "failed"
			warn(`[PlayerData] claim {key} attempt {attempt} failed: {err}`)
		elseif status == "ready" then
			return "ready", data
		end
		if attempt < CLAIM_ATTEMPTS then
			task.wait(if status == "locked" then 5 else 2 ^ attempt)
		end
	end
	return status, nil
end

local function releaseUnused(key: string, token: string)
	pcall(function()
		store:UpdateAsync(key, function(old: Record?): Record?
			if old and old.Session and old.Session.Token == token then
				old.Session = nil
				return old
			end
			return nil
		end)
	end)
end

local function saveAsync(profile: Profile, release: boolean): boolean
	while profile.Saving do
		task.wait(0.1)
	end
	if profile.State ~= "active" then
		return false
	end
	profile.Saving = true
	-- Snapshot now: gameplay keeps mutating Data while the request yields.
	local snapshot = DataTemplate.deepCopy(profile.Data)
	local success = false
	for attempt = 1, SAVE_ATTEMPTS do
		local lost = false
		local ok, err = pcall(function()
			store:UpdateAsync(profile.Key, function(old: Record?): Record?
				local session = if old then old.Session else nil
				if old == nil or session == nil or session.Token ~= profile.Token then
					lost = true
					return nil
				end
				old.Data = snapshot
				old.Session = if release
					then nil
					else { Token = profile.Token, JobId = game.JobId, ExpiresAt = os.time() + LEASE_SECONDS }
				return old
			end)
		end)
		if ok and lost then
			profile.State = "lost"
			warn(`[PlayerData] lost session for {profile.Key}`)
			if profile.Player.Parent == Players then
				profile.Player:Kick("Your data was opened on another server. Please rejoin.")
			end
			break
		elseif ok then
			success = true
			break
		end
		warn(`[PlayerData] save {profile.Key} attempt {attempt} failed: {err}`)
		if attempt < SAVE_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
	profile.LastSave = os.clock()
	if release and success then
		profile.State = "released"
	end
	profile.Saving = false
	return success
end

local function onPlayerAdded(player: Player)
	local key = keyFor(player.UserId)
	if IS_STUDIO and ServerStorage:GetAttribute("SimulateLoadFailure") == true then
		player:Kick("[Studio] Simulated load failure. Nothing was saved.")
		return
	end
	local token = HttpService:GenerateGUID(false)
	local status, raw = claimAsync(key, token)

	if player.Parent ~= Players then
		if status == "ready" then
			releaseUnused(key, token) -- left while loading; give the lease back
		end
		return
	end
	if status ~= "ready" then
		player:Kick(if status == "locked"
			then "Your progress is still saving on another server. Please rejoin in a minute."
			else "We could not load your progress. Nothing was changed. Please rejoin.")
		return
	end

	local data, reason = DataTemplate.prepare(raw)
	if not data then
		releaseUnused(key, token)
		warn(`[PlayerData] refused {key}: {reason}`)
		player:Kick(if reason == "newer"
			then "This server is out of date. Please rejoin to get a newer server."
			else "Your save could not be read. Nothing was changed. Please contact support.")
		return
	end

	local profile: Profile = {
		Player = player,
		Key = key,
		Token = token,
		Data = data,
		State = "active",
		Saving = false,
		LastSave = os.clock(),
	}
	profiles[player] = profile
	player:SetAttribute("DataReady", true)
	for _, callback in loadedCallbacks do
		task.spawn(callback, profile)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	-- Remove first so no service mutates Data after the final snapshot.
	profiles[player] = nil
	releasing[profile] = true
	saveAsync(profile, true)
	releasing[profile] = nil
end

-- Public API -------------------------------------------------------------

-- The active profile, or nil while loading, after leaving, or after a failed load.
function PlayerData.Get(player: Player): Profile?
	local profile = profiles[player]
	if profile and profile.State == "active" then
		return profile
	end
	return nil
end

function PlayerData.WaitForProfile(player: Player, timeout: number): Profile?
	local deadline = os.clock() + timeout
	while player.Parent == Players and os.clock() < deadline do
		local profile = PlayerData.Get(player)
		if profile then
			return profile
		end
		task.wait(0.25)
	end
	return PlayerData.Get(player)
end

-- Runs for every profile that loads, including ones that loaded before the call.
function PlayerData.OnLoaded(callback: (Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for _, profile in profiles do
		if profile.State == "active" then
			task.spawn(callback, profile)
		end
	end
end

-- Write now (after purchases, rare grants). Respects MIN_SAVE_SPACING.
function PlayerData.SaveNowAsync(player: Player): boolean
	local profile = PlayerData.Get(player)
	if not profile then
		return false
	end
	local waitFor = MIN_SAVE_SPACING - (os.clock() - profile.LastSave)
	if waitFor > 0 then
		task.wait(waitFor)
	end
	return saveAsync(profile, false)
end

function PlayerData.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, profile in profiles do
				if profile.State == "active" then
					task.spawn(saveAsync, profile, false)
					task.wait(0.5) -- spread writes so a full server is not one burst
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			profiles[player] = nil
			pending += 1
			task.spawn(function()
				saveAsync(profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25 -- BindToClose has about 30 s in total (Roblox docs)
		while (pending > 0 or next(releasing) ~= nil) and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return PlayerData
```

Choices worth defending:

- **Lease 120 s, autosave 60 s.** Every autosave renews the lease, so an active profile never expires. If a server crashes, the lease frees itself within two minutes. Shorter leases recover faster but risk a slow autosave letting a lease lapse (rule of thumb).
- **Locked means kick, not wait forever.** Five attempts five seconds apart is about 20 seconds. A player arriving from a server that is still saving them almost always succeeds within that. A crashed server's lease needs up to two minutes; the kick message tells the player to rejoin in a minute.
- **The snapshot is a deep copy.** Without it, a save that yields while gameplay removes an item and adds coins could serialize half of that change.
- **Studio keys are separate.** Testing cannot damage your live save, and `TestProfileKey` gives a brand-new profile instantly. The trap: forgetting the attribute is set and "losing" progress that is simply on another key ([[Session Locking and Profile Libraries]] has the production story).

### 4.3 Main: the only server Script

```lua
--!strict
-- ServerScriptService/Server/Main (Script). Reviewed, not run.
local PlayerData = require(script.Parent.PlayerData)

-- Remotes must exist before clients look for them, so services Start (create remotes) first.
local ORDER = { "InventoryService", "DailyRewardService", "ShopService", "CodeService", "LeaderboardService" }

local services = script.Parent:WaitForChild("Services")
for _, name in ORDER do
	local module = services:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local service = require(module) :: any
		service.Start()
	end
end

PlayerData.Start()
```

Services that are not built yet are skipped, so this file does not change as you add the other builds. Services register `OnLoaded` callbacks in `Start`; `PlayerData.Start` runs last, so no profile can load before every service is listening (and `OnLoaded` replays already-loaded profiles anyway).

---

## 5. The inventory itself

### 5.1 ItemCatalog

```lua
--!strict
-- ReplicatedStorage/Shared/ItemCatalog (ModuleScript). Reviewed, not run.
export type ItemDef = {
	Id: string,
	Name: string,
	Kind: "Stack" | "Unique",
	MaxStack: number, -- Stack items only
	SellPrice: number,
	Equippable: boolean,
	Icon: string,
}

local Items: { [string]: ItemDef } = {
	Apple = { Id = "Apple", Name = "Apple", Kind = "Stack", MaxStack = 999, SellPrice = 1, Equippable = false, Icon = "rbxassetid://0000000000" },
	IronOre = { Id = "IronOre", Name = "Iron Ore", Kind = "Stack", MaxStack = 999, SellPrice = 5, Equippable = false, Icon = "rbxassetid://0000000000" },
	IronSword = { Id = "IronSword", Name = "Iron Sword", Kind = "Unique", MaxStack = 1, SellPrice = 50, Equippable = true, Icon = "rbxassetid://0000000000" },
}

local ItemCatalog = {}
ItemCatalog.MaxUniques = 200

function ItemCatalog.Get(itemId: string): ItemDef?
	return Items[itemId]
end

return ItemCatalog
```

The catalog is shared, so exploiters can read it. That is fine: it holds nothing secret, and the server never trusts the client's copy, only its own.

### 5.2 InventoryService

```lua
--!strict
-- ServerScriptService/Server/Services/InventoryService (ModuleScript). Reviewed, not run.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local PlayerData = require(script.Parent.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local MAX_COUNT_PER_CALL = 10_000
local MAX_COINS = 1e15 -- far below 2^53, so integer math stays exact

local InventoryService = {}

local syncEvent: RemoteEvent
local requestFunction: RemoteFunction
local allowRequest = RateLimiter.new(8, 4)
local pendingSync: { [Player]: boolean } = {}

local function isPositiveInteger(n: any, max: number): boolean
	return type(n) == "number" and n == n and n >= 1 and n <= max and math.floor(n) == n
end

local function countUniques(uniques: { [string]: any }): number
	local n = 0
	for _ in uniques do
		n += 1
	end
	return n
end

-- Batch every change in one frame into a single snapshot.
local function queueSync(player: Player)
	if pendingSync[player] then
		return
	end
	pendingSync[player] = true
	task.defer(function()
		pendingSync[player] = nil
		local profile = PlayerData.Get(player)
		if not profile then
			return
		end
		local data = profile.Data
		syncEvent:FireClient(player, {
			Coins = data.Coins,
			Stacks = data.Inventory.Stacks,
			Uniques = data.Inventory.Uniques,
			Equipped = data.Inventory.Equipped,
		})
	end)
end
InventoryService.Sync = queueSync

-- Coins -------------------------------------------------------------------

function InventoryService.AddCoins(player: Player, amount: number): boolean
	local profile = PlayerData.Get(player)
	if not profile or not isPositiveInteger(amount, MAX_COINS) then
		return false
	end
	local data = profile.Data
	data.Coins = math.min(MAX_COINS, data.Coins + amount)
	data.Stats.CoinsEarned = math.min(MAX_COINS, data.Stats.CoinsEarned + amount)
	local week = math.floor(os.time() / 604800) -- UTC weeks since the epoch (Thursdays)
	if data.Weekly.WeekIndex ~= week then
		data.Weekly.WeekIndex = week
		data.Weekly.CoinsEarned = 0
	end
	data.Weekly.CoinsEarned = math.min(MAX_COINS, data.Weekly.CoinsEarned + amount)
	queueSync(player)
	return true
end

function InventoryService.SpendCoins(player: Player, amount: number): boolean
	local profile = PlayerData.Get(player)
	if not profile or not isPositiveInteger(amount, MAX_COINS) then
		return false
	end
	if profile.Data.Coins < amount then
		return false
	end
	profile.Data.Coins -= amount
	queueSync(player)
	return true
end

-- Items -------------------------------------------------------------------

-- All-or-nothing: either every item fits or nothing changes.
function InventoryService.Add(player: Player, itemId: string, count: number, level: number?): (boolean, string?)
	local profile = PlayerData.Get(player)
	if not profile then
		return false, "NotReady"
	end
	local def = ItemCatalog.Get(itemId)
	if not def then
		return false, "UnknownItem"
	end
	if not isPositiveInteger(count, MAX_COUNT_PER_CALL) then
		return false, "BadCount"
	end
	local inv = profile.Data.Inventory
	if def.Kind == "Stack" then
		local newCount = (inv.Stacks[itemId] or 0) + count
		if newCount > def.MaxStack then
			return false, "StackFull"
		end
		inv.Stacks[itemId] = newCount
	else
		if countUniques(inv.Uniques) + count > ItemCatalog.MaxUniques then
			return false, "InventoryFull"
		end
		for _ = 1, count do
			local uid = HttpService:GenerateGUID(false)
			inv.Uniques[uid] = { ItemId = itemId, Level = level or 1, CreatedAt = os.time() }
		end
	end
	queueSync(player)
	return true, nil
end

function InventoryService.Has(player: Player, itemId: string, count: number): boolean
	local profile = PlayerData.Get(player)
	if not profile then
		return false
	end
	local inv = profile.Data.Inventory
	local def = ItemCatalog.Get(itemId)
	if not def then
		return false
	end
	if def.Kind == "Stack" then
		return (inv.Stacks[itemId] or 0) >= count
	end
	local owned = 0
	for _, item in inv.Uniques do
		if item.ItemId == itemId then
			owned += 1
		end
	end
	return owned >= count
end

-- Equipping -----------------------------------------------------------------

local function removeEquippedTools(player: Player)
	local containers: { Instance? } = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("InventoryUid") ~= nil then
					child:Destroy()
				end
			end
		end
	end
end

local function giveEquippedTool(player: Player)
	removeEquippedTools(player)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	local inv = profile.Data.Inventory
	local item = inv.Uniques[inv.Equipped]
	if not item then
		return
	end
	local toolFolder = ServerStorage:FindFirstChild("ItemTools")
	local template = if toolFolder then toolFolder:FindFirstChild(item.ItemId) else nil
	local backpack = player:FindFirstChildOfClass("Backpack")
	if template and template:IsA("Tool") and backpack then
		local tool = template:Clone()
		tool:SetAttribute("InventoryUid", inv.Equipped)
		tool:SetAttribute("Level", item.Level)
		tool.Parent = backpack
	end
end

-- Request handling ----------------------------------------------------------

type Result = { Ok: boolean, Error: string? }

local function handleRequest(player: Player, payload: any): Result
	if not allowRequest(player) then
		return { Ok = false, Error = "TooFast" }
	end
	if type(payload) ~= "table" or type(payload.Action) ~= "string" then
		return { Ok = false, Error = "BadRequest" }
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return { Ok = false, Error = "NotReady" }
	end
	local inv = profile.Data.Inventory
	local action = payload.Action

	if action == "Equip" or action == "SellUnique" then
		local uid = payload.Uid
		if type(uid) ~= "string" or #uid > 64 then
			return { Ok = false, Error = "BadRequest" }
		end
		local item = inv.Uniques[uid]
		if not item then
			return { Ok = false, Error = "NotOwned" }
		end
		local def = ItemCatalog.Get(item.ItemId)
		if not def then
			return { Ok = false, Error = "UnknownItem" }
		end
		if action == "Equip" then
			if not def.Equippable then
				return { Ok = false, Error = "NotEquippable" }
			end
			inv.Equipped = if inv.Equipped == uid then "" else uid -- toggle
			giveEquippedTool(player)
		else
			-- Remove and pay in one synchronous block: no yield between them.
			if inv.Equipped == uid then
				inv.Equipped = ""
				removeEquippedTools(player)
			end
			inv.Uniques[uid] = nil
			InventoryService.AddCoins(player, def.SellPrice)
		end
		queueSync(player)
		return { Ok = true }
	elseif action == "SellStack" then
		local itemId, count = payload.ItemId, payload.Count
		if type(itemId) ~= "string" or #itemId > 64 or not isPositiveInteger(count, MAX_COUNT_PER_CALL) then
			return { Ok = false, Error = "BadRequest" }
		end
		local def = ItemCatalog.Get(itemId)
		local have = inv.Stacks[itemId] or 0
		if not def or def.Kind ~= "Stack" or have < count then
			return { Ok = false, Error = "NotOwned" }
		end
		inv.Stacks[itemId] = if have == count then nil else have - count
		if def.SellPrice > 0 then
			InventoryService.AddCoins(player, def.SellPrice * count)
		end
		queueSync(player)
		return { Ok = true }
	end
	return { Ok = false, Error = "BadRequest" }
end

function InventoryService.Start()
	syncEvent = Net.Event("InventorySync")
	requestFunction = Net.Function("InventoryRequest")

	requestFunction.OnServerInvoke = function(player: Player, payload: any): Result
		local ok, result = pcall(handleRequest, player, payload)
		if not ok then
			warn(`[Inventory] request error for {player.UserId}: {result}`)
			return { Ok = false, Error = "ServerError" }
		end
		return result
	end

	-- The client asks for its first snapshot when its UI is ready.
	Net.Event("InventoryHello").OnServerEvent:Connect(function(player: Player)
		queueSync(player)
	end)

	PlayerData.OnLoaded(function(profile)
		local player = profile.Player
		queueSync(player)
		player.CharacterAdded:Connect(function()
			task.defer(giveEquippedTool, player) -- Backpack is recreated on respawn
		end)
		if player.Character then
			giveEquippedTool(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		pendingSync[player] = nil
	end)
end

return InventoryService
```

Points that are easy to get wrong:

- **Stacks remove the key at zero** (`nil`, not `0`), so the profile does not grow a dead entry for every item the player ever touched.
- **`Add` is all-or-nothing.** Partial grants ("you got 3 of your 5") are where reward bugs and support tickets come from. Callers that want overflow handling (send the rest to a mailbox) do it explicitly.
- **The handler never yields between check and mutation.** `GenerateGUID` and every table write are synchronous, so two requests from the same player cannot interleave inside one sell. This, not a lock, is what prevents "sell the same sword twice" ([[Economy Exploits - Dupes Races and Purchase Abuse]]).
- **Tools are rebuilt from data.** The Tool in the Backpack is a view of the profile, never the source of truth. Deleting it, dropping it or duplicating it client-side changes nothing that saves.
- **Snapshots, not deltas.** With at most 200 uniques and a handful of stacks, a full snapshot is a few KB and cannot drift. Deltas only pay off for huge inventories ([[Network Bandwidth Budgets and Measuring Them]]).

---

## 6. The client and UI

The UI is built in code so the note is complete. You can design it in Studio instead and keep only the wiring.

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/Client/InventoryController (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)

local player = Players.LocalPlayer
local syncEvent = Net.Event("InventorySync")
local requestFunction = Net.Function("InventoryRequest")

type Snapshot = {
	Coins: number,
	Stacks: { [string]: number },
	Uniques: { [string]: { ItemId: string, Level: number } },
	Equipped: string,
}

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

-- Build -------------------------------------------------------------------
local gui = make("ScreenGui", { Name = "Inventory", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))
local openButton = make("TextButton", {
	Text = "Bag", Size = UDim2.fromOffset(80, 40), Position = UDim2.new(0, 12, 0.5, -20),
}, gui)
local coinsLabel = make("TextLabel", {
	Text = "0 coins", Size = UDim2.fromOffset(160, 30), Position = UDim2.new(0, 12, 0.5, 26),
	BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
}, gui)
local window = make("Frame", {
	Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.6, 0.6),
}, gui)
make("UIAspectRatioConstraint", { AspectRatio = 1.5 }, window)
local grid = make("ScrollingFrame", {
	Size = UDim2.new(1, -16, 1, -64), Position = UDim2.fromOffset(8, 8),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6,
}, window)
make("UIGridLayout", { CellSize = UDim2.fromOffset(88, 88), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
local actionButton = make("TextButton", { Text = "Select an item", Size = UDim2.new(0.5, -12, 0, 40), Position = UDim2.new(0, 8, 1, -48) }, window)
local sellButton = make("TextButton", { Text = "Sell", Size = UDim2.new(0.5, -12, 0, 40), Position = UDim2.new(0.5, 4, 1, -48) }, window)

-- State -------------------------------------------------------------------
local current: Snapshot? = nil
local selected: { Kind: "Stack" | "Unique", Key: string }? = nil
local busy = false

local function render()
	local snap = current
	if not snap then
		return
	end
	coinsLabel.Text = `{snap.Coins} coins`
	for _, child in grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local order = 0
	local function tile(key: string, kind: "Stack" | "Unique", itemId: string, caption: string)
		local def = ItemCatalog.Get(itemId)
		order += 1
		local button = make("TextButton", {
			LayoutOrder = order,
			Text = `{if def then def.Name else itemId}\n{caption}`,
			TextWrapped = true,
			BorderSizePixel = if selected and selected.Key == key then 3 else 0,
		}, grid)
		button.Activated:Connect(function()
			selected = { Kind = kind, Key = key }
			render()
		end)
	end
	for itemId, count in snap.Stacks do
		tile(itemId, "Stack", itemId, `x{count}`)
	end
	for uid, item in snap.Uniques do
		tile(uid, "Unique", item.ItemId, `Lv {item.Level}{if snap.Equipped == uid then " (E)" else ""}`)
	end
	-- Clear a selection that no longer exists (sold elsewhere, for example).
	if selected and not (snap.Stacks[selected.Key] or snap.Uniques[selected.Key]) then
		selected = nil
	end
	actionButton.Text = if selected and selected.Kind == "Unique"
		then (if snap.Equipped == selected.Key then "Unequip" else "Equip")
		else "Select an item"
end

local function send(payload: { [string]: any })
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return requestFunction:InvokeServer(payload)
	end)
	busy = false
	if not ok or type(result) ~= "table" or not result.Ok then
		warn(`[Inventory] {if ok and type(result) == "table" then result.Error else "network error"}`)
	end
	-- No local mutation: the server's snapshot arrives through InventorySync.
end

actionButton.Activated:Connect(function()
	if selected and selected.Kind == "Unique" then
		send({ Action = "Equip", Uid = selected.Key })
	end
end)
sellButton.Activated:Connect(function()
	local snap = current
	if not selected or not snap then
		return
	end
	if selected.Kind == "Unique" then
		send({ Action = "SellUnique", Uid = selected.Key })
	else
		send({ Action = "SellStack", ItemId = selected.Key, Count = snap.Stacks[selected.Key] or 0 })
	end
end)
openButton.Activated:Connect(function()
	window.Visible = not window.Visible
end)

syncEvent.OnClientEvent:Connect(function(snapshot: Snapshot)
	current = snapshot
	render()
end)
Net.Event("InventoryHello"):FireServer()
```

Destroying and rebuilding every tile on each snapshot is fine at this size (a few hundred buttons at most, and snapshots arrive only after actions). If the bag grows past a few hundred entries, switch to pooled tiles as in [[Virtualized Lists and Large Inventories]]. "Sell" sells the whole stack here; a real game adds a count picker and a confirm step for rare items ([[Menu Archetypes - Shop Settings Codes Rewards]] on the button state triad).

---

## 7. Testing it in Studio

1. **API access.** Enable Studio Access to API Services. Without it every claim fails and you are kicked with "could not load" (which is itself a useful test of the failure path).
2. **Give yourself items.** In the command bar while playing (server view), run: `require(game.ServerScriptService.Server.Services.InventoryService).Add(game.Players:GetPlayers()[1], "IronSword", 1, 3)`. The tile appears within a frame. See [[Command Bar and Studio Scripting]].
3. **Persistence.** Add items, Stop, Play again. They must still be there. If not, check the Output for `[PlayerData]` warnings.
4. **Fresh profile.** Set `ServerStorage` attribute `TestProfileKey` to `a`, Play: empty bag. Set it to `b`: a different empty bag. Clear it: your normal Studio save.
5. **Load failure.** Set `SimulateLoadFailure` to true. You must be kicked and your save must be untouched afterwards.
6. **Lock contention.** Play, Stop and immediately Play again. The release in `BindToClose` normally lands first; if Studio kills the server before it does, you will see the locked kick for up to two minutes. That is the system working. Use a fresh `TestProfileKey` to skip the wait.
7. **Multi-client.** Test, Clients and Servers, 2 players. Sell on one, confirm the other client sees nothing of it (snapshots are per player). See [[Testing Modes - Play Run and Multi-Client]].
8. **Spam.** In a client, fire the sell request in a tight loop (a local test script, never shipped). Most return `TooFast`, and coins rise only for items really owned. [[Testing Your Own Remotes - Fuzzing and Abuse Tests]] has a fuller harness.

---

## 8. Exploits this build must resist

| Attack | What stops it |
|---|---|
| Sell an item id the player does not own | Ownership checked against server data, never client state |
| Negative, fractional, NaN or huge counts | `isPositiveInteger` with an upper bound; NaN fails `n == n` |
| Very long strings to bloat memory or logs | Length caps before any lookup |
| Sell the same unique twice in quick succession | Synchronous check-and-remove; the second request finds no item |
| Duplicate by joining a second server before the first saves | Session lease: the second server cannot claim until the first releases |
| Clone the Tool locally to "own" it | Tools are given from `ServerStorage` and rebuilt from data; client clones are invisible to the server |
| Flood requests to lag the server | Token bucket per player; handler errors are caught so a bad payload cannot kill the remote |
| Edit the client's catalog prices | The server uses its own `require` of the catalog; the client copy is display only |

What it does not stop on its own: dupes through a future trading feature, and economy abuse through other systems that call `Add` without validation. Every new caller of `Add` is a new attack surface ([[Threat Modeling a Roblox Game]]).

---

## 9. Extending it

- **More item data.** Add fields to `UniqueItem` (rolled stats, enchantments). Old items lack them, so read with defaults or add a migration.
- **Hotbar.** Store an ordered array of up to 9 uids in `Inventory.Hotbar`; validate on the server that each uid is owned and equippable.
- **Mailbox overflow.** When `Add` returns `InventoryFull`, put the grant into `Data.Mailbox` instead of dropping it, and let the player claim it later.
- **Trading.** Do not bolt it on. Read [[Trading Systems Without Duplication]] first; it needs both profiles changed atomically, which this layer does not do across two players.
- **Large bags.** Switch the client to pooled tiles and send deltas with a sequence number.
- **Profile size.** Every unique costs about 80 to 120 bytes of JSON (rule of thumb). 200 uniques is about 25 KB, far below the 4 MB value limit and fine for the per-key write budget ([[DataStore Fundamentals]]).

---

## Common mistakes

- Granting with `PlayerData.Get(player)` returning nil and not checking it: the grant silently does nothing. Always check and surface `NotReady`.
- Yielding (a `task.wait`, a data store call, `GetProductInfoAsync`) between "check the player owns it" and "remove it".
- Saving inside every action. Writes are budgeted; save on the autosave and after purchases only.
- Two scripts calling `GetDataStore` on the player store. Only `PlayerData` may.
- Storing Instances or Vector3 values in `Data`. They do not serialize; store plain numbers and strings.

## Checklist

- [ ] Studio API access on, Studio keys separate from live keys
- [ ] Only `PlayerData` touches the player data store
- [ ] Every remote payload type-checked, length-capped, rate-limited
- [ ] Check and mutate with no yield in between
- [ ] `Add` is all-or-nothing and respects caps
- [ ] Failed or newer-schema loads kick and never save defaults
- [ ] Tested: persistence, fresh key, simulated failure, multi-client, spam

## See also

[[Worked Builds Start Here]] | [[Session Locking and Profile Libraries]] | [[Saving Correctly - Autosave and BindToClose]] | [[Tools and Inventory Systems]] | [[Economy Exploits - Dupes Races and Purchase Abuse]] | [[Daily Rewards System End to End]] | [[Shop with Game Passes and Developer Products End to End]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox DataStore Safety]] · [[Debugging DataStore Problems]] · [[Cookbook - Data and Saving]] · [[Genre Systems Start Here]] · [[Skill - Roblox System Builder]] · [[Session Lock]]
<!-- auto-links:end -->
