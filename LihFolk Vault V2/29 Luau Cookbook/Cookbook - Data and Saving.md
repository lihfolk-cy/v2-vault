---
tags: [luau, cookbook, datastore, saving, persistence, recipes, type/reference, area/scripting, level/intermediate, api/DataStoreService, area/data, api/UpdateAsync]
---
# Cookbook - Data and Saving

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `SetAsync` for player saves.
> - Avoid: Treating `nil` from `GetAsync` as a load failure, or a thrown error as a new player.
> - Avoid: Saving after a failed load.
> - Every DataStore call is in `pcall` with bounded retries.
> - Data carries a `version` and a migration chain.
> - Saves use `UpdateAsync` and respect ownership.
>
> Cost: TL;DR ~120 tok · whole note ~5.2k tok. Read more: ## 3. Save with UpdateAsync, not SetAsync · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Recipes for loading and saving player data with `DataStoreService` without losing or duplicating it. They are small on purpose: a real game should combine them into one data module or use a session-locking library ([[Session Locking and Profile Libraries]]). Read [[DataStore Fundamentals]], [[Saving Correctly - Autosave and BindToClose]] and [[Data Loss Prevention and Recovery]] for the reasoning. Code is `--!strict` Luau, reviewed, not run.

To test DataStores in Studio you must enable "Enable Studio Access to API Services" in Game Settings, and the place must be published (Roblox docs (as of October 2026)). Studio then reads and writes the live data of that experience, which is why recipe 11 exists.

---

## 1. Call a DataStore with retries and backoff

**Problem.** DataStore calls fail occasionally (throttling, service hiccups). One failed `GetAsync` must not wipe a player's progress.

```lua
--!strict
local function retry<T>(attempts: number, fn: () -> T): (boolean, T | string)
	local lastError = ""
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		if attempt < attempts then
			task.wait(2 ^ attempt) -- 2, 4, 8 seconds
		end
	end
	return false, lastError
end

-- local ok, data = retry(4, function() return store:GetAsync(key) end)
```

**Why it works.** Every DataStore call can throw, so each is wrapped in `pcall`. Exponential backoff gives the service time to recover instead of hammering it inside the same throttle window.

**Pitfall.** Do not retry forever while the player waits: after a few attempts, either kick with a friendly message or let them play in a "not saving" state (recipe 6). Retrying inside `BindToClose` must respect its time limit (recipe 5).

---

## 2. Start from a template and fill in missing keys

**Problem.** You add `gems` to the data in an update. Old saves do not have it, and `data.gems += 1` errors on `nil`.

```lua
--!strict
local TEMPLATE = {
	version = 2,
	coins = 0,
	gems = 0,
	inventory = {} :: { string },
	settings = { music = true, sfx = true },
}

local function deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[k] = deepCopy(v)
	end
	return out :: any
end

local function reconcile(data: { [string]: any }, template: { [string]: any })
	for key, default in template do
		if data[key] == nil then
			data[key] = deepCopy(default)
		elseif typeof(default) == "table" and typeof(data[key]) == "table" and next(default) ~= nil then
			reconcile(data[key], default)
		end
	end
end
```

**Why it works.** New players get a fresh copy of the template; returning players get any missing keys added. `deepCopy` matters: without it every new player would share the same `inventory` table.

**Pitfall.** The `next(default) ~= nil` check skips recursing into empty template tables such as `inventory`, which are lists the player fills, not shapes to enforce. Reconcile does not remove keys you deleted from the template; that is a migration's job (recipe 8).

---

## 3. Save with UpdateAsync, not SetAsync

**Problem.** `SetAsync` overwrites blindly. If two servers hold the same player briefly (fast server hop), the older one can overwrite newer progress.

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerData_v1")

local function save(userId: number, data: { [string]: any }, sessionId: string): boolean
	local ok, err = pcall(function()
		store:UpdateAsync(tostring(userId), function(old: any)
			if typeof(old) == "table" and old.sessionId ~= nil and old.sessionId ~= sessionId then
				return nil -- another server owns this profile: cancel the write
			end
			data.sessionId = sessionId
			return data
		end)
	end)
	if not ok then
		warn("save failed for", userId, err)
	end
	return ok
end
```

**Why it works.** `UpdateAsync` gives you the current stored value before you write, and returning `nil` cancels the write (Roblox docs (as of October 2026)). Comparing an owner id lets a server refuse to overwrite data it no longer owns.

**Pitfall.** The transform function can run more than once if there is contention, so it must not yield or have side effects (no `print` spam, no incrementing counters outside it). This recipe is a minimal guard, not full session locking: a real lock also needs a timestamp so a crashed server's lock expires. Use a profile library unless you have a reason not to.

---

## 4. Autosave on a staggered timer

**Problem.** Servers crash. If you only save on leave, a crash loses the whole session.

```lua
--!strict
local Players = game:GetService("Players")
local AUTOSAVE_INTERVAL = 120 -- seconds (rule of thumb: 60 to 300)

local function startAutosave(player: Player, saveFn: (Player) -> ())
	-- Random first delay spreads players across the interval.
	local offset = math.random() * AUTOSAVE_INTERVAL
	task.delay(offset, function()
		while player.Parent == Players do
			saveFn(player)
			task.wait(AUTOSAVE_INTERVAL)
		end
	end)
end
```

**Why it works.** Without the random offset, every player who joined at server start saves at the same instant, which spikes your request budget. The loop ends by itself when the player leaves.

**Pitfall.** Skip the save if nothing changed (keep a `dirty` flag) to save budget. Each key accepts a write only about once every six seconds (Roblox docs (as of October 2026)), so never autosave the same key more often than that, and do not autosave in the same second you save on leave.

---

## 5. Save everyone on shutdown

**Problem.** When a server closes, `PlayerRemoving` may not finish its saves before the process ends.

```lua
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function saveAll(saveFn: (Player) -> ())
	local remaining = 0
	for _, player in Players:GetPlayers() do
		remaining += 1
		task.spawn(function()
			saveFn(player)
			remaining -= 1
		end)
	end
	local deadline = os.clock() + 25
	while remaining > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

game:BindToClose(function()
	if RunService:IsStudio() then
		return -- optional: skip saves when stopping a Studio test
	end
	saveAll(function(player) print("save", player.UserId) end)
end)
```

**Why it works.** `BindToClose` callbacks get up to 30 seconds before the server is forced to close (Roblox docs (as of October 2026)). Saving all players in parallel fits far more saves in that window than a sequential loop, and the deadline leaves a margin.

**Pitfall.** `PlayerRemoving` also fires during shutdown, so a player can be saved twice. Track "save in progress" per player and have one path skip if the other is running. For Studio, decide deliberately whether stopping a test should save (recipe 11).

---

## 6. Never save data that failed to load

**Problem.** Load fails, the code falls back to the template, the player plays, and the autosave overwrites their real 200-hour save with a fresh one.

```lua
--!strict
type Profile = { data: { [string]: any }, loaded: boolean }
local profiles: { [Player]: Profile } = {}

local function onLoadFailed(player: Player)
	profiles[player] = { data = {}, loaded = false }
	player:Kick("Could not load your data. Please rejoin in a minute.")
end

local function canSave(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.loaded
end
```

**Why it works.** A `loaded` flag set only after a successful read makes every save path check one boolean. Kicking is the safest default; some games let the player continue with saving disabled and a clear on-screen warning.

**Pitfall.** `GetAsync` returning `nil` is not a failure: it means a new player. Only a thrown error (caught by `pcall`) is a failure. Mixing these up either wipes new players' first sessions or treats returning players as new.

---

## 7. Check the request budget before non-urgent calls

**Problem.** A leaderboard refresh or analytics write competes with player saves for the same budget.

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")

local function hasBudget(requestType: Enum.DataStoreRequestType, reserve: number): boolean
	return DataStoreService:GetRequestBudgetForRequestType(requestType) > reserve
end

if hasBudget(Enum.DataStoreRequestType.UpdateAsync, 10) then
	-- do the optional write
end
```

**Why it works.** `GetRequestBudgetForRequestType` returns how many requests of that type the server can make right now. Keeping a reserve means low-priority work never starves saves.

**Pitfall.** Budgets scale with player count (a base plus a per-player amount per minute; check the current numbers in the docs). A quiet server has less budget than a full one, so test optional writes with two players, not just a full server.

---

## 8. Version your data and migrate step by step

**Problem.** You renamed `gold` to `coins` and changed `inventory` from a list to a dictionary of counts.

```lua
--!strict
local CURRENT_VERSION = 3

local MIGRATIONS: { [number]: (data: { [string]: any }) -> () } = {
	[1] = function(data) -- 1 -> 2
		data.coins = data.gold or 0
		data.gold = nil
	end,
	[2] = function(data) -- 2 -> 3
		local counts: { [string]: number } = {}
		for _, item in data.inventory or {} do
			counts[item] = (counts[item] or 0) + 1
		end
		data.inventory = counts
	end,
}

local function migrate(data: { [string]: any })
	local version = data.version or 1
	while version < CURRENT_VERSION do
		local step = MIGRATIONS[version]
		assert(step, "missing migration from version " .. version)
		step(data)
		version += 1
		data.version = version
	end
end
```

**Why it works.** Each migration only knows how to go one step, so a save from version 1 runs both steps in order. Old code paths never need to understand new data.

**Pitfall.** If a newer server wrote version 4 and an old server (still running before an update) loads it, the old server must refuse to save, or it will overwrite fields it does not understand. Check `data.version > CURRENT_VERSION` on load and treat it like a failed load. Worked examples are in [[Schema Migrations - Worked Case Studies]].

---

## 9. Check the size before saving

**Problem.** An inventory grows without limit and eventually exceeds the per-key size limit, so saves start failing.

```lua
--!strict
local HttpService = game:GetService("HttpService")
local MAX_CHARS = 4_194_304 -- 4 MB per key, Roblox docs (as of October 2026)

local function sizeCheck(data: { [string]: any }): (boolean, number)
	local encoded = HttpService:JSONEncode(data)
	return #encoded < MAX_CHARS * 0.8, #encoded
end
```

**Why it works.** DataStores store values as JSON, so the encoded length is a good estimate of the stored size. Warning at 80 percent gives time to fix the cause before saves fail.

**Pitfall.** Encoding a large table every autosave costs CPU; check it occasionally or only when the inventory grows. `JSONEncode` errors on mixed tables, non-string dictionary keys that are not sequential integers, and values like `Vector3` or `Instance`. Convert those to plain numbers and strings before saving ([[Data Schema Design and Migrations]]).

---

## 10. Read a global leaderboard

**Problem.** Show the top 50 players by total wins.

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local winsStore = DataStoreService:GetOrderedDataStore("Wins_v1")

local function getTop(count: number): { { key: string, value: number } }
	local ok, pages = pcall(function()
		return winsStore:GetSortedAsync(false, count) -- false = descending
	end)
	if not ok then
		return {}
	end
	local results = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		table.insert(results, { key = entry.key, value = entry.value })
	end
	return results
end

-- Writing: winsStore:SetAsync(tostring(userId), totalWins) inside pcall,
-- at most every few minutes per player.
```

**Why it works.** An `OrderedDataStore` keeps integer values sorted, so the top entries come back in one call. The page size (up to 100 per page per the docs) covers a typical board.

**Pitfall.** Values must be integers; store `math.floor(score)`. Refresh the board on a slow timer (every one to five minutes) and cache it for all players instead of fetching per player. Turning `key` (a user id string) into a display name needs `Players:GetNameFromUserIdAsync`, which also yields and can fail. Full treatment in [[OrderedDataStores and Leaderboards]].

---

## 11. Keep Studio tests away from live data

**Problem.** A test in Studio with API access overwrites a real player's save or your own production profile.

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local STORE_NAME = if RunService:IsStudio() then "PlayerData_v1_STUDIO" else "PlayerData_v1"
local store = DataStoreService:GetDataStore(STORE_NAME)
```

**Why it works.** Studio and live servers then write to different stores, so a broken migration in a test cannot touch real data.

**Pitfall.** This also means you cannot reproduce a live player's bug in Studio with their real data. For that, copy their record into the Studio store with a one-off script, read only. A cleaner option is a separate test place in the same experience, or a separate experience for staging.

---

## 12. Remove a player's data on a deletion request

**Problem.** Roblox sends right-to-erasure requests; you must delete stored personal data for that user id.

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")

local function erase(userId: number): boolean
	local stores = {
		DataStoreService:GetDataStore("PlayerData_v1"),
		DataStoreService:GetOrderedDataStore("Wins_v1"),
	}
	local allOk = true
	for _, store in stores do
		local ok = pcall(function()
			store:RemoveAsync(tostring(userId))
		end)
		allOk = allOk and ok
	end
	return allOk
end
```

**Why it works.** `RemoveAsync` deletes the key. Listing every store that uses the user id as a key makes sure none is forgotten.

**Pitfall.** Keys that contain the user id inside another key (for example `"trade_" .. userId`) and data in external services are easy to miss. Keep a written list of where user ids are stored. The process and its time limits are covered in [[Player Privacy and Data Deletion]].

---

## Common mistakes

- `SetAsync` for player saves.
- Treating `nil` from `GetAsync` as a load failure, or a thrown error as a new player.
- Saving after a failed load.
- Shared template tables between players.
- Testing in Studio against the live store.

## Checklist

- [ ] Every DataStore call is in `pcall` with bounded retries.
- [ ] Data carries a `version` and a migration chain.
- [ ] Saves use `UpdateAsync` and respect ownership.
- [ ] Autosave staggered, dirty-flag gated, at least six seconds apart per key.
- [ ] `BindToClose` saves in parallel with a deadline.
- [ ] Size warning in place for growing data.

## See also

[[Luau Cookbook Start Here]], [[Session Locking and Profile Libraries]], [[Debugging DataStore Problems]], [[Trading Systems Without Duplication]], [[Purchase Data and Receipts]], [[Cookbook - Tables Strings and Time]], [[Saved Inventory End to End]]

## Nuances and edge cases

1. **Request budgets are per server and per experience.** Standard reads and writes each get 60 + 40 per player per minute per server, ordered-store writes 30 + 5 per player, and list calls 5 + 2 per player, with experience-wide caps on top (Roblox docs, as of October 2026). The numbers are generous for a normal save loop, but a busy server that autosaves every player every 30 seconds, updates an ordered leaderboard on every coin and reads a global config often can still exhaust the ordered budget long before the standard one. Leaderboard writes are usually the first budget to run out.
2. **Per-key throughput.** Each key is limited to about 4 MB of writes and 25 MB of reads per minute (Roblox docs, as of October 2026). A single shared key that every server writes (a global counter, a shared config edited from game servers) hits this far sooner than per-player keys. Shard shared data across several keys, or move it to MemoryStore.
3. **Size limits and growth.** A key can hold about 4 MB of serialized data (Roblox docs, as of October 2026). Most profiles are tiny, but logs, history arrays and per-item metadata grow without bound. A player who has played for two years can hit the limit while new players never do, so the bug only shows up for your most loyal players. Cap every list, and check the encoded size before saving.
4. **Storage limits per experience.** Total storage for the latest versions is capped at 500 MB plus 1 MB per lifetime user (Roblox docs, as of October 2026). That is plenty for normal profiles, but per-player keys that are never cleaned up (abandoned test keys, per-session logs) count against it.
5. **BindToClose time.** On shutdown, the server has a limited time (about 30 seconds) to save everyone. With 50 players and some throttled requests, sequential saves may not finish. Save in parallel with a cap on concurrency, and skip players whose data has not changed since the last save.
6. **Studio versus live.** Studio can reach live DataStores when API access is enabled. Testing a migration in Studio against the live store has wiped or corrupted real data in many games. Use a separate store name or a separate place for Studio, as the recipe says, and make it the default rather than something to remember.
7. **Migrations run on load, forever.** A player who last joined three years ago loads with schema version 1. Migrations must chain from every old version, and old migration code cannot be deleted unless you have moved every key forward with a batch job.
8. **UpdateAsync is not a lock.** UpdateAsync makes one read-modify-write atomic for that key, but two servers can still both load a player and both save. Only session locking prevents that. UpdateAsync also counts against the read budget as well as the write budget.

## More common mistakes

1. **One leaderboard write per stat change.** Symptom: ordered-store throttling warnings, then leaderboard values that stop updating. Fix: update ordered stores on a timer and only when the value changed.
2. **Unbounded history arrays.** Symptom: saves fail for long-time players only. Fix: cap lists and trim old entries on save.
3. **A global key every server writes.** Symptom: throttling on that key as the game grows. Fix: shard or move to MemoryStore.
4. **Retrying forever.** Symptom: a server stuck retrying during an outage blocks other saves. Fix: limited retries with backoff, then keep data in memory and retry later.
5. **Saving on every change.** Symptom: budget exhaustion during busy moments. Fix: mark dirty and let autosave handle it.
6. **Deleting migration code.** Symptom: returning players load with missing fields or errors. Fix: keep migrations, or run a batch upgrade first.
7. **No logging of save failures.** Symptom: data loss reports with no evidence. Fix: log failures with player id and reason.

## Related decisions

- [[Session Locking and Profile Libraries]]: what UpdateAsync alone does not protect against.
- [[Schema Migrations - Worked Case Studies]]: chaining migrations from very old versions.
- [[MemoryStore Service]]: where shared, fast-changing data should live instead.
- [[Global Leaderboards End to End]]: a build that keeps ordered-store writes within budget.
- [[Server Shutdowns Soft Updates and Migration]]: saving reliably when servers close for updates.
- [[Player Privacy and Data Deletion]]: deletion requests and what must be removed.
- [[Crash and Error Telemetry]]: logging save failures so data loss is visible.
- [[Economy Resets and Seasonal Wipes]]: planned resets versus accidental loss.
- [[Data Loss Prevention and Recovery]]: backups and restores when something still goes wrong.

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox DataStore Safety]] · Session Lock · Data Schema Versioning · Error Handling and Retries · Links - DataStoreService · Server Lifecycle and Shutdown
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[AI Pitfalls - Data and Monetization]] · [[Session Lock]] · [[Cookbook - Remotes and Networking]] · [[Cookbook - Players and Characters]] · [[Cookbook - UI]] · [[Cookbook - Math CFrame and Vectors]]
<!-- related:end -->
