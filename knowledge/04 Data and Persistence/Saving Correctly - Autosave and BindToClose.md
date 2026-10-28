---
tags: [data, datastore, autosave, bindtoclose, retries, shutdown]
---
# Saving Correctly - Autosave and BindToClose

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No `BindToClose` (Every update or shutdown loses up to one autosave interval for...)
> - Avoid: Saving players one by one in `BindToClose` (Large servers time out; the last players lose data)
> - Avoid: Not waiting for `PlayerRemoving` saves in `BindToClose` (Last player in an emptying server loses progress)
> - Save on: autosave (staggered), leave (with release), shutdown (parallel, with a deadline), purchases.
> - Autosave interval below the lease.
> - No save path exists for a profile that failed to load.
>
> Read more (17 KB note): ## When to write · ## The loader: wiring it all together · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Loading is one call at the start of a session. Saving is where data actually gets lost: on a server crash, during a shutdown with 30 players, in a throttled minute, or because a save ran before the load finished. This note gives the timing rules (with official numbers and the values one production game settled on), a retry helper that knows which errors are worth retrying, and a complete loader script that wires load, autosave, "save soon", leave-saves and `BindToClose` together on top of the module from [[Session Locking and Profile Libraries]].

## When to write

Roblox's player-data guide names exactly four moments to touch the store:

1. **Initial read** at the start of the session.
2. **Final write** when the player leaves (and releases the session lock).
3. **Periodic writes** so a crash loses minutes, not the whole session. These also renew the lease.
4. **Writes at critical checkpoints**, above all while processing a purchase ([[Purchase Data and Receipts]]).

Everything else (coin pickups, kills, equips) only changes the in-memory profile.

### Timing values

| Value | Roblox sample | One production game | Rule of thumb |
|---|---|---|---|
| Autosave interval | 180 s (with a random first offset per player, added in the October 2026 guide) | 120 s, one loop for all players | 60 to 180 s, below the lease, staggered |
| Lease | (configurable) | 90 s, renewed by every save and every 30 s | 2 to 3 autosave periods |
| "Save soon" after something valuable | n/a | 2 s minimum, normally waits until 8 s since the last save | 2 to 10 s debounce |
| Retry after a failed autosave | queue-based backoff | re-queue after 15 s | exponential with jitter, capped |
| `BindToClose` window | 30 s (engine) | waits up to 25 s for in-flight saves | finish by ~25 s |

Why stagger: if every server starts its autosave loop on boot, and many servers boot together after an update, they all save on the same tick, forever. Roblox's best-practices page says assign a random initial offset per server or player and add bounded jitter. A single loop that saves all players back to back also bursts the server's write budget; spreading each player on their own offset keeps it smooth.

Why not save more often: each save costs one read and one write from both the server budget (60 + 40 per player per minute) and the experience budget (300 + 20 x CCU writes per minute), and counts against the per-key 4 MB/min throughput. At 120 s per player you use under 1 write per player per minute, leaving lots of headroom for purchases and other stores.

## The retry helper

Retry only what can succeed on retry, back off exponentially with jitter, cap attempts, and keep retries for one key in order (the module serializes saves per profile).

```lua
--!strict
-- ServerScriptService/Data/Retry (ModuleScript)
local Retry = {}

-- Data store errors usually begin with their numeric code, e.g. "104: Cannot store ..."
-- (observed format; the codes themselves are listed on the Roblox limits page).
local PERMANENT: { [number]: boolean } = {
	[101] = true, [102] = true, [103] = true, [104] = true, [105] = true,
	[106] = true, [107] = true, [403] = true, [509] = true,
	[511] = true, [512] = true, [513] = true,
}

function Retry.isPermanent(err: any): boolean
	local code = tonumber(string.match(tostring(err), "^(%d%d%d)"))
	return code ~= nil and PERMANENT[code] == true
end

-- Calls fn until it returns without erroring, or attempts run out.
-- Returns ok, ...results  (ok = false, lastError on failure)
function Retry.call<T...>(attempts: number, fn: () -> T...): (boolean, ...any)
	local delay = 1
	local lastErr: any = nil
	for attempt = 1, attempts do
		local results = table.pack(pcall(fn))
		if results[1] then
			return true, table.unpack(results, 2, results.n)
		end
		lastErr = results[2]
		if Retry.isPermanent(lastErr) then
			break
		end
		if attempt < attempts then
			task.wait(delay * (0.5 + math.random())) -- jitter: 0.5x to 1.5x
			delay = math.min(delay * 2, 16)
		end
	end
	return false, lastErr
end

return Retry
```

Note the module from [[Session Locking and Profile Libraries]] already wraps `UpdateAsync` in `pcall` and returns `"error"`; the loader below decides how many times to call it again, because the right number depends on context (autosave can wait for the next cycle, a final save cannot).

## Never save before the load succeeded

The single most destructive bug in Roblox persistence is: load fails, the code falls back to a default profile, and the leave-save writes that default over the player's real data. The reference project's rule, stated at the top of its persistence code: a profile is written back only once it has been read successfully (or the player is confirmed brand new). A failed read leaves the session **unsaved** rather than letting a blank profile overwrite real progress. The module enforces this structurally: there is no profile object to save unless the claim succeeded.

A second, quieter version of the same bug: values that live outside the profile (leaderstats values, attributes) and are copied into it on save. If the save runs before those were restored from the profile, it writes zeros. The reference project only marks a profile ready once its Cash/Gems/Rolls are back in leaderstats. Better still: make the profile the single source of truth and drive leaderstats from it, never the other way round.

## The loader: wiring it all together

```lua
--!strict
-- ServerScriptService/Data/PlayerDataLoader (Script)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ProfileManager = require(script.Parent.ProfileManager)
local Profiles = require(script.Parent.Profiles)

local AUTOSAVE_INTERVAL = 120     -- desired interval; clamped below so each save renews the lease in time
local FINAL_SAVE_ATTEMPTS = 4
local SHUTDOWN_BUDGET = 25         -- seconds of the 30 s BindToClose window we allow ourselves

-- A 90 s lease needs saves (renewals) more often than every 90 s.
AUTOSAVE_INTERVAL = math.min(AUTOSAVE_INTERVAL, math.floor(ProfileManager.LeaseSeconds / 3))

local inFlight = 0
local saveQueued: { [Player]: boolean } = {}
local lastSaveAt: { [Player]: number } = {}

local function notify(player: Player, text: string)
	-- hook into your UI; an attribute keeps the example self-contained
	player:SetAttribute("DataNotice", text)
end

local function saveWithRetries(player: Player, release: boolean, attempts: number): boolean
	local profile = Profiles._get(player)
	if not profile or profile.State ~= "active" then
		return false
	end
	inFlight += 1
	local result = "error"
	local delay = 1
	for attempt = 1, attempts do
		result = ProfileManager.save(profile, release)
		if result ~= "error" then
			break
		end
		if attempt < attempts then
			task.wait(delay * (0.5 + math.random()))
			delay = math.min(delay * 2, 8)
		end
	end
	inFlight -= 1
	lastSaveAt[player] = os.clock()
	if result == "lost" and player.Parent then
		notify(player, "Your data was opened on another server. Rejoin to keep playing safely.")
	end
	return result == "saved"
end

-- Debounced save after something valuable (a big purchase, a rare drop, a trade).
local function saveSoon(player: Player)
	if saveQueued[player] then
		return
	end
	saveQueued[player] = true
	local since = os.clock() - (lastSaveAt[player] or -math.huge)
	local delay = math.max(2, 8 - since) -- at least 2 s, and about 8 s between writes to one key
	task.delay(delay, function()
		saveQueued[player] = nil
		if player.Parent then
			saveWithRetries(player, false, 2)
		end
	end)
end

-- gameplay code calls Profiles.saveSoon(player) after valuable changes
(Profiles :: any).saveSoon = saveSoon

local function startAutosave(player: Player)
	task.spawn(function()
		task.wait(math.random() * AUTOSAVE_INTERVAL) -- per-player offset: no synchronized bursts
		while player.Parent do
			local profile = Profiles._get(player)
			if not profile or profile.State ~= "active" then
				break
			end
			-- a failed autosave just waits for the next cycle (or the leave-save)
			saveWithRetries(player, false, 1)
			task.wait(AUTOSAVE_INTERVAL + math.random() * 5) -- small jitter each cycle
		end
	end)
end

local function onPlayerAdded(player: Player)
	Profiles._set(player, "loading", nil)
	local status, profile = ProfileManager.load(player)
	if status == "left" then
		return
	end
	if not player.Parent then
		-- left after we claimed: release immediately so their next server can load
		if profile then
			ProfileManager.save(profile, true)
		end
		return
	end
	if status ~= "ready" or not profile then
		Profiles._set(player, status, nil)
		if status == "locked" then
			player:Kick("Your data is still saving from your last server. Please rejoin in a minute.")
		else
			player:Kick("Your data couldn't load. Nothing was changed; please rejoin.")
		end
		return
	end
	Profiles._set(player, "ready", profile)
	startAutosave(player)
end

local function onPlayerRemoving(player: Player)
	saveQueued[player] = nil
	saveWithRetries(player, true, FINAL_SAVE_ATTEMPTS) -- final write + release the lease
	Profiles._clear(player)
	lastSaveAt[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p) -- players who joined before this script ran
end

game:BindToClose(function(reason: Enum.CloseReason)
	if RunService:IsStudio() then
		-- Studio: save but do not hold the window open (stopping Play stays fast). Leases left
		-- behind are handled by the Studio takeover rule / test key in the locking note.
		for _, p in Players:GetPlayers() do
			task.spawn(saveWithRetries, p, true, 1)
		end
		task.wait(1)
		return
	end
	-- Live: save everyone in PARALLEL (sequential saves of 30 players will not fit in 30 s).
	for _, p in Players:GetPlayers() do
		task.spawn(saveWithRetries, p, true, 3)
	end
	local started = os.clock()
	task.wait(0.5) -- let the spawned saves (and PlayerRemoving saves) register as in flight
	while inFlight > 0 and os.clock() - started < SHUTDOWN_BUDGET do
		task.wait(0.1)
	end
	if inFlight > 0 then
		warn(`[Data] shutdown ({reason.Name}) ended with {inFlight} saves still running`)
	end
end)
```

Notes on the loader:

- **The autosave interval and the lease must agree.** The production game paired a 90 s lease with a 120 s autosave, which only worked because it had a separate 30 s renewal loop. The loader above folds renewal into the autosave by clamping the interval to a third of the lease. If you want 120 to 180 s autosaves, use a 300 s or longer lease.
- **Kick on `locked` and `failed`.** This is the conservative choice. The alternative (play in a no-save mode with a banner) is described in [[Session Locking and Profile Libraries]]; if you choose it, also block purchases.
- **`saveSoon` is for value, not for frequency.** Call it after a purchase grant (the receipt flow saves synchronously anyway), a trade, a rare drop, a rebirth. Do not call it on every currency tick.
- **PlayerRemoving during shutdown.** When a server closes, players are removed and `PlayerRemoving` fires while `BindToClose` runs. Both paths call `saveWithRetries`; the module's per-profile serialization makes the second call wait, then it sees `State = "released"` and returns. No double write races.
- **`inFlight` covers both paths**, so `BindToClose` waits for leave-saves started by `PlayerRemoving`, which the production game called out explicitly ("these and the leave-saves PlayerRemoving is running").

## BindToClose, precisely

From the `DataModel:BindToClose` reference (October 2026):

- You can bind several functions; **they run in parallel**.
- The server waits **30 seconds** for all of them, then shuts down regardless.
- If the bound function takes a parameter it receives an `Enum.CloseReason`: `Unknown`, `RobloxMaintenance`, `DeveloperShutdown`, `DeveloperUpdate`, `ServerEmpty`, `OutOfMemory`, `Moderation`. Useful for logging and for skipping non-essential work; save on every reason.
- Use `RunService:IsStudio()` to avoid making Studio wait.
- Data store calls made too late fail with 401/402 (DataModel or web services unavailable during shutdown).

What eats the 30 seconds:

| Cost | Typical | Mitigation |
|---|---|---|
| One `UpdateAsync` | 0.1 to 1 s, much longer when throttled | Parallel saves |
| 30 players saved one after another | Can exceed 30 s under load | `task.spawn` each |
| Other stores (leaderboards, analytics) | Adds requests to the same queues | Write critical player data first; skip non-critical stores or give them a short budget |
| Retries | Exponential waits | Fewer attempts in shutdown (3, short delays) |
| Write queue already full (30 requests) | New requests fail with 30x | Stop non-critical writers when shutdown begins |

`ServerEmpty` shutdowns are the common case: the last player left, `PlayerRemoving` already started their save, and `BindToClose` just needs to wait for it. Forgetting to wait is the classic "last player's progress is lost" bug.

Roblox's sample adds one more trick: on shutdown, drop queued stale requests and send only the latest state per key. With per-profile serialization plus snapshots there is never more than one queued save per profile, so this is automatic.

## Saving other stores

Not every store needs the profile's guarantees:

| Store | Pattern |
|---|---|
| Player profile | Session-locked, fenced `UpdateAsync` (this note) |
| Receipts ledger | `UpdateAsync` claim per `PurchaseId` ([[Purchase Data and Receipts]]) |
| Leaderboard (ordered) | `SetAsync` of the current value on leave and on a slow loop, only if the profile loaded; skipped in Studio test sessions ([[OrderedDataStores and Leaderboards]]) |
| Settings | Separate key, `UpdateAsync` on change with a debounce |
| Analytics, reports | Best effort; never block shutdown on them |

The reference project's leaderboard service applied the most important rule here: "never write a profile we failed to read, or we would wipe their history". Its totals were only written for players whose leaderboard state had loaded, and never while a Studio test key was active.

## Verifying that saves work

- In Studio with API access on a **test experience** (or with the test key), play, change data, stop, and read the key back with `UseCache = false` ([[DataStore Fundamentals]]): a plain `GetAsync` may serve a value up to 4 s old.
- Simulate failure: a flag that forces the load to fail (the reference project's `SimulateLoadFailure` attribute) proves the no-save path works. Also simulate save errors (a flag that makes `ProfileManager.save` return `"error"`) to see the retry and the "will retry" UI.
- Watch the Data Stores observability dashboard after a release: Request Count by Status for throttling and errors, Write Request Type Quota Usage for headroom ([[Data Loss Prevention and Recovery]]).
- Test a shutdown with players in the server (a live test server, "Shut Down All Servers"), then confirm every player's `SavedAt` is after the shutdown time.

## Common mistakes

| Mistake | What happens |
|---|---|
| No `BindToClose` | Every update or shutdown loses up to one autosave interval for every player |
| Saving players one by one in `BindToClose` | Large servers time out; the last players lose data |
| Not waiting for `PlayerRemoving` saves in `BindToClose` | Last player in an emptying server loses progress |
| Yielding in `PlayerRemoving` before the save | Delays the save; widens the session-overlap window |
| Saving defaults after a failed load | Real data overwritten |
| Autosave interval longer than the lease | Healthy servers lose their own lease and sessions turn `lost` |
| Same-tick autosave in every server | Throttling at the same moment every few minutes |
| Saving on every change | 30x throttle errors; per-key throughput exceeded |
| Holding `BindToClose` open in Studio | Every Stop takes 25 s |

## Checklist

- [ ] Save on: autosave (staggered), leave (with release), shutdown (parallel, with a deadline), purchases.
- [ ] Autosave interval below the lease.
- [ ] No save path exists for a profile that failed to load.
- [ ] `BindToClose` waits for in-flight leave-saves.
- [ ] Studio does not wait in `BindToClose`.
- [ ] Retries back off with jitter and stop on permanent errors.
- [ ] Non-critical stores never block shutdown.

## See also
[[Session Locking and Profile Libraries]] · [[DataStore Fundamentals]] · [[Data Loss Prevention and Recovery]] · [[Purchase Data and Receipts]] · [[Server Lifecycle and Shutdown]] · [[Error Handling and Retries]] · [[Task Library Coroutines and Yielding]] · [[QA Checklists Before Release]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox DataStore Safety]] · [[Debugging DataStore Problems]] · [[Cookbook - Data and Saving]] · [[Session Lock]] · [[Links - DataStoreService]] · [[Saved Inventory End to End]]
<!-- auto-links:end -->
