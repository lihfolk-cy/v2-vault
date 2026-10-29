---
tags: [data, datastore, persistence, limits, fundamentals, type/guide, area/data, level/beginner, api/UpdateAsync, api/IncrementAsync, api/DataStoreService]
---
# DataStore Fundamentals

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `GetAsync` then `SetAsync` for player data -> `UpdateAsync` plus session locking
> - Avoid: Treating a `nil` load result after an error as "new player" -> Distinguish "no data" from "call failed" (Data Loss Prevention and...
> - Avoid: Yielding inside the transform -> Compute everything before calling `UpdateAsync`
> - Every data store call is in `pcall`, with transient-error retry and backoff.
> - Player data is written only through one module, with `UpdateAsync` and a session lock.
> - Load failure and "new player" are different code paths.
>
> Cost: TL;DR ~180 tok · whole note ~5.5k tok. Read more: ## UpdateAsync, precisely · ## Limits (Roblox docs, as of October 2026) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

`DataStoreService` is the only durable, cross-server storage built into the engine. Everything a player expects to still exist tomorrow (currency, inventory, settings, purchase history) ends up in a data store. This note explains what a data store actually is, the exact limits and budgets it enforces (as of October 2026), how the 4 second read cache works and bites, how versioning gives you free backups, and which API to call for which job. The rest of this folder builds on it: [[Session Locking and Profile Libraries]], [[Saving Correctly - Autosave and BindToClose]], [[Data Schema Design and Migrations]].

## The mental model

A data store is a remote key-value table:

- **Data store name** (up to 50 characters) picks the table, for example `PlayerData`.
- **Scope** (up to 50 characters, default `global`) is a legacy prefix glued onto every key. Roblox docs now say: new games should use key **prefixes** instead of scopes.
- **Key** (up to 50 characters) picks the row, for example `User_123456`.
- **Value**: anything that serializes to JSON (numbers, strings, booleans, tables with either array or string keys). Up to **4,194,304 characters per key** after serialization (Roblox docs).

Every call is a web request from the game server to Roblox's storage backend. That has three consequences that shape every design decision in this folder:

1. **Calls yield** (tens to hundreds of milliseconds, sometimes seconds under throttling).
2. **Calls fail.** Network errors, throttling, backend incidents and shutdown all throw. Every call goes in `pcall`.
3. **A failed write may still have happened.** The docs are explicit: an error means the server did not receive a success response, not that the backend did nothing. Design writes to be safe to repeat (see [[Purchase Data and Receipts]]).

Data stores are **per experience (universe)**, not per place. Every place in the universe reads and writes the same stores. Only server `Script`s can call the API; a `LocalScript` call errors.

### Studio access

By default, Studio play sessions cannot touch data stores (error `403 StudioAccessToApisNotAllowed`). Enabling **File > Experience Settings > Security > Enable Studio Access to API Services** makes Studio read and write the **same live data** your players use. Roblox recommends enabling it only on a separate test experience. The reference project did enable it on the live place and paid for that with a set of safety rules (a Studio-only test-profile key, a load-failure simulator, a "never reset the real save" rule); see [[Data Loss Prevention and Recovery]].

Contrast: MemoryStoreService data is isolated between Studio and production automatically ([[MemoryStore Service]]). Data stores are not.

## Choosing the API

| Need | Call | Notes |
|---|---|---|
| Read a value | `GetAsync(key, options?)` | Cached 4 s (see below). Returns `value, DataStoreKeyInfo` |
| Read-modify-write, or anything another server might also write | `UpdateAsync(key, transform)` | Reads latest, retries your transform on conflict. Costs one read **and** one write |
| Overwrite with a value that does not depend on the old one | `SetAsync(key, value, userIds?, options?)` | Write budget only. Races with other servers |
| Add to an integer | `IncrementAsync(key, delta, userIds?, options?)` | Atomic add; value must be an integer |
| Delete | `RemoveAsync(key)` | Writes a tombstone version; old versions stay reachable until they expire |
| See history | `ListVersionsAsync`, `GetVersionAsync`, `GetVersionAtTimeAsync` | Standard (non-ordered) stores only |
| Enumerate | `DataStoreService:ListDataStoresAsync(prefix?, pageSize?, cursor?)`, `DataStore:ListKeysAsync(prefix?, pageSize?, cursor?, excludeDeleted?)` | Lists only stores that contain at least one object |
| Ranked numbers | `GetOrderedDataStore` + `GetSortedAsync` | Integers only. See [[OrderedDataStores and Leaderboards]] |

`GetDataStore(name, scope?, options?)` returns the same object for the same name and scope, so caching the object in a module is fine but not required. `GetGlobalDataStore()` returns the default store (scope `u`); do not use it for new work, a named store is clearer.

`OnUpdate` is deprecated (it polled once a minute). Use MessagingService for change notification ([[Cross-Server Messaging]]).

## UpdateAsync, precisely

`UpdateAsync` is the workhorse. Its exact contract (Roblox docs):

- The transform receives `(currentValue, keyInfo)`. `keyInfo` is `nil` for a key that does not exist yet.
- It returns up to three values: `newValue, userIds, metadata`.
- **If you return only a value, existing user ids and metadata are cleared.** If you use either, pass them through: `return newValue, keyInfo:GetUserIds(), keyInfo:GetMetadata()`.
- If another server wrote the key between the read and the write, the engine **calls your transform again** with the newer value and discards the previous result. It repeats until the write lands or you return `nil`.
- Returning `nil` cancels the write. The call still succeeds and returns.
- **The transform cannot yield.** No `task.wait`, no other `*Async` calls, no `RemoteFunction` invokes.

Two consequences people miss:

1. **Side effects inside the transform can run several times.** Do not grant items, fire remotes, increment counters in outer scope, or log "saved" inside it. Set plain flags (`claimed = true`) and reset them at the top of the transform, because the last invocation is the one that counts. The reference project's lease code does exactly that: every flag is reset on entry.
2. **Your transform must be a pure function of its input** plus captured constants. If it captures a live in-memory profile table and mutates it, a retried call sees the mutation from the first attempt.

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerData")

-- Atomically add coins without clobbering anything another server wrote.
local function addCoins(userId: number, amount: number): (boolean, number?)
	local newTotal: number? = nil
	local ok, err = pcall(function()
		store:UpdateAsync(`User_{userId}`, function(old: any, keyInfo: DataStoreKeyInfo?)
			newTotal = nil -- reset: this function may run more than once
			local data = if type(old) == "table" then old else { Coins = 0 }
			data.Coins = (tonumber(data.Coins) or 0) + amount
			newTotal = data.Coins
			if keyInfo then
				-- preserve user ids and metadata, or they are wiped
				return data, keyInfo:GetUserIds(), keyInfo:GetMetadata()
			end
			return data, { userId }
		end)
	end)
	if not ok then
		warn(`addCoins failed for {userId}: {err}`)
		return false, nil
	end
	return true, newTotal
end
```

This is a teaching example. Live player data should not be written like this from arbitrary code while the player is in a session; it goes through the session-locked profile ([[Session Locking and Profile Libraries]]).

## Limits (Roblox docs, as of October 2026)

### Size limits

| Item | Maximum |
|---|---|
| Data store name | 50 characters |
| Scope | 50 characters |
| Key name | 50 characters |
| Value | 4,194,304 characters per key (serialized) |
| Metadata key name | 50 characters |
| Metadata value | 250 characters |
| Metadata total | 300 characters |

Strings must be valid UTF-8. A single byte above 127 that is not part of a valid multi-byte sequence makes the write fail. This bites people who store raw `buffer` or `string.pack` output as a string: base64 it first, or use `buffer` through `HttpService:JSONEncode`-safe encoding (see [[Buffers and Binary Data]]).

### Per-key throughput

Each key, across all servers and Open Cloud, is measured over a rolling 60 seconds:

| Kind | Calls | Limit |
|---|---|---|
| Read | `GetAsync`, `GetVersionAsync`, `GetVersionAtTimeAsync`, `ListVersionsAsync`, `UpdateAsync` | 25 MB per minute |
| Write | `SetAsync`, `IncrementAsync`, `UpdateAsync`, `RemoveAsync` | 4 MB per minute |

Each request is rounded **up** to the next KB. Writing an 800-byte value and a 1.2 KB value counts as 3 KB. So a 400 KB profile can be written at most about 10 times per minute before that key throttles. Heavy profiles and frequent saves collide here first.

> Older guides (and some skills) state a "one write per key every 6 seconds" rule. The current limits page does not contain it; the per-key limit is now expressed as throughput. Spacing writes to one key by several seconds is still a good rule of thumb: the reference project never saves a profile more often than every 2 s and normally waits about 8 s since the last save before a "save soon".

### Experience-wide budgets (shared by all servers **and** Open Cloud)

Requests per minute, CCU = concurrent users:

| Type | Standard stores | Ordered stores |
|---|---|---|
| Read | 300 + CCU x 40 | 300 + CCU x 40 |
| Write | 300 + CCU x 20 | 300 + CCU x 20 |
| List | 300 + CCU x 2 | 300 + CCU x 2 |
| Remove | 300 + CCU x 40 | 300 + CCU x 40 |

`UpdateAsync` spends one read and one write. Open Cloud scripts (support tools, migrations, RTBF bots) draw from the same pool, so a careless bulk script can throttle live servers. See [[Open Cloud APIs]].

> Contradiction in the docs: the Extended Services pricing table lists default data store limits as 250 + CCU x 40 (get) and 250 + CCU x 20 (set). The limits page says 300. Design for the lower figure.

### Per-server defaults (configurable)

| Type | Standard | Ordered |
|---|---|---|
| Read | 60 + players x 40 | 60 + players x 40 |
| Write | 60 + players x 40 | 30 + players x 5 |
| List | 5 + players x 2 | 5 + players x 2 |
| Remove | 60 + players x 40 | 30 + players x 5 |

New servers get a one-time startup burst on top (size not documented). `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.X)` returns the current budget; `SetRateLimitForRequestType(requestType, baseLimit, perPlayerLimit)` overrides the defaults per server (call once at startup; `UpdateAsync` and `OnUpdate` cannot be configured). The newer enum members are `StandardRead`, `StandardWrite`, `StandardList`, `StandardRemove`, `OrderedRead`, `OrderedWrite`, `OrderedList`, `OrderedRemove`; the legacy ones (`GetAsync`, `SetIncrementAsync`, `UpdateAsync`, `GetSortedAsync`, `SetIncrementSortedAsync`, `ListAsync`, ...) still exist.

Studio Run mode uses its own static limits, which can be lower. Test rate-limit behaviour in a Team Create session or a live test server, not solo Play.

### Queues and the 30-request cliff

When over budget, requests wait in one of four queues (Set, Ordered set, Get, Ordered get). Each queue holds **30** requests. The calling thread just yields longer while queued. Once a queue is full, new requests fail immediately with errors 301 to 306 (`GetAsyncThrottle`, `SetAsyncThrottle`, `IncreAsyncThrottle`, `UpdateAsyncThrottle`, `GetSortedThrottle`, `RemoveAsyncThrottle`).

What it looks like: saves that normally take 0.2 s take 10 to 30 s, then a burst of `30x` errors in the console, usually right after a server-wide event (everyone saving on the same tick, a leaderboard refresh loop in every server, a migration loop).

### Storage

Per experience: **500 MB + 1 MB x lifetime users** of the latest version of every key, measured **compressed**. Old versions and deleted keys do not count. Roblox compresses for you; do not pre-compress (it wastes CPU and hurts their compression). Going over shows estimated monthly costs in the Data Stores Manager and is billable through Extended Services ($0.12 per GB per month as listed in October 2026; the same pricing page quotes the free allowance as 100 MB + 1 MB per lifetime player, another doc contradiction).

## The 4 second cache

`GetAsync` caches each key **locally on the server for 4 seconds** after a backend read (Roblox docs):

- A `GetAsync` within those 4 seconds returns the cached value without a request. Cache hits do not count against any budget.
- `SetAsync` and `UpdateAsync` on that key **apply to the cache immediately** and restart the timer.
- The cache belongs to the data store object instance. Two objects for the same store but different scope settings (for example one with `AllScopes`) have separate caches and can disagree.
- `GetVersionAsync`, `ListVersionsAsync`, `ListKeysAsync`, `ListDataStoresAsync` never use the cache.
- To bypass it, pass a `DataStoreGetOptions` with `UseCache = false`. Such reads always count against budgets.

```lua
--!strict
local function readFresh(store: DataStore, key: string): (boolean, any)
	local options = Instance.new("DataStoreGetOptions")
	options.UseCache = false
	return pcall(function()
		return store:GetAsync(key, options)
	end)
end
```

The trap, measured in one production game: you save from one script (or one server), then immediately "verify" with a plain `GetAsync` from a tool or another server that read the key a moment earlier, and you see the **old** value for up to about 4 seconds. Developers then conclude "the save failed" and start debugging the wrong thing. The reference project's rule: every verification read uses `UseCache = false`. The cache also explains a second symptom: a server that polls a shared key with `GetAsync` every second really only reaches the backend every 4 seconds.

The cache does not make `GetAsync` safe for read-modify-write. Another server can write the key the instant after your read. Use `UpdateAsync`.

## Versioning: the backups you already have

Standard data stores keep history automatically (Roblox docs):

- `SetAsync`, `UpdateAsync` and `IncrementAsync` create a **versioned backup on the first write to each key in each UTC hour**. Later writes in the same hour overwrite the current version in place. So you get roughly one restore point per key per hour of activity.
- A backup **expires 30 days after a newer write supersedes it**. The latest version never expires.
- `RemoveAsync` writes a tombstone: `GetAsync` returns `nil` afterwards, but earlier versions stay readable through the version APIs until they expire. Removed objects are deleted permanently after 30 days.
- `RemoveVersionAsync` is deprecated.
- `GetVersionAtTimeAsync(key, timestampMs)` returns the version current at that time. Timestamps are milliseconds since the epoch and may not be more than ten minutes in the future.
- Ordered data stores have **no** versioning.

This is the basis of every rollback tool in [[Data Loss Prevention and Recovery]]. It also has a sharp edge: if a bug corrupts a profile and the player keeps playing for an hour, the "hourly" backup can itself be corrupt. For that reason Roblox recommends taking an Open Cloud **snapshot** (available once a day per experience) right before publishing any update that changes data logic ([[Open Cloud APIs]]).

## Metadata and user ids

Each key in a standard store carries:

- **Service metadata** (read-only through `DataStoreKeyInfo`): `Version`, `CreatedTime`, `UpdatedTime` (ms since epoch).
- **User-defined metadata**: set with `DataStoreSetOptions:SetMetadata({...})` or returned as the third value from an `UpdateAsync` transform. Max 300 characters total.
- **User ids**: an array passed to `SetAsync`/`IncrementAsync` or returned from the transform. Roblox calls them "highly recommended to assist with GDPR tracking/removal". The upper count is reported only as an error (`512 UserIdLimitExceeded`) with no published number.

Rule from the docs: when you write with `SetAsync`, `IncrementAsync` or `UpdateAsync`, always supply the metadata again, even if it did not change, or it is lost. Metadata is a good home for small, query-free facts like a schema version or a lock id (Roblox's own sample stores its session lock there).

## Keys and stores: how to lay them out

Roblox's best-practices page (October 2026) recommends:

- **Few data stores, organised by key.** One `PlayerData` store with `User_{UserId}` keys, not a store per player or per feature per player.
- **One key per player** when it fits under 4 MB: atomic updates across all fields, one read on join, easy rollback. Split into a few deterministic keys only when parts have different access patterns or approach the size/throughput limits, and keep anything that must change together in the same key.
- **Static key patterns** built from stable ids (`User_{UserId}`), never display names. Static patterns are what make automated right-to-be-forgotten deletion possible ([[Player Privacy and Data Deletion]]).
- **Prefixes** for grouping, for example `User_123/Profile/Warrior`, then `ListKeysAsync("User_123/Profile")`.

The reference project's layout, as a real example: one profile store (key `P_<userId>`), a skills store keyed `..._S_<userId>`, a receipts store keyed by `PurchaseId`, a gift-intent store keyed by buyer id, a settings store, a support-report store and several ordered stores for boards. Its one regret worth copying: skills lived in a separate key from the currency that bought them, so a crash could persist one without the other. They later moved the skill list into the main profile write ("charge and record in one step"). Keep coupled data in one key.

## Errors you will actually see

| Code | Name | Usual cause |
|---|---|---|
| 101 / 102 | KeyNameEmpty / KeyNameLimit | Empty or over-50-character key (usually a bug building the key) |
| 103 / 104 | ValueNotAllowed / CantStoreValue | Transform returned an Instance, function, mixed table or invalid UTF-8 |
| 105 | ValueTooLarge | Over 4 MB serialized |
| 106 / 107 | Ordered paging errors | Page size outside 1 to 100, non-integer min/max, max < min |
| 301 to 306 | `*Throttle` | Queue full, request dropped |
| 401 / 402 | DataModelNoAccess / LuaWebSrvsNoAccess | Called too late during shutdown |
| 403 | StudioAccessToApisNotAllowed | Studio API access off |
| 502 | RequestRejected | Backend rejected (often transient) |
| 509 | OperationNotAllowed | Writes blocked on a personal RCC |
| 511 / 512 / 513 | Metadata too large / too many user ids / bad metadata type | |

Distinguish **permanent** errors (1xx, 403, 511 to 513: retrying cannot help) from **transient** ones (3xx, 5xx: retry with backoff). The retry helper in [[Saving Correctly - Autosave and BindToClose]] does this.

## What does not belong in a data store

| Data | Better home |
|---|---|
| Matchmaking queues, live auction prices, "who is online" | [[MemoryStore Service]] |
| Feature flags, tuning values, event start times | Experience configs ([[Global State and Live Config]]) |
| API keys, webhook URLs | Secrets store ([[HttpService and External APIs]]) |
| Per-round state, cooldowns, buffs that end with the session | Plain Luau tables on the server |
| Anything the client sent you, unvalidated | Nowhere until validated ([[Server Authority and Validation]]) |

## Common mistakes

| Mistake | What it looks like | Fix |
|---|---|---|
| `GetAsync` then `SetAsync` for player data | Occasional rollbacks, duplicated items after server hops | `UpdateAsync` plus session locking |
| Treating a `nil` load result after an error as "new player" | A player's whole save replaced by defaults | Distinguish "no data" from "call failed" ([[Data Loss Prevention and Recovery]]) |
| Yielding inside the transform | Error "Callbacks cannot yield" or a silently failed save | Compute everything before calling `UpdateAsync` |
| Returning only the value from a transform | User ids and metadata vanish | Pass `keyInfo:GetUserIds()`, `keyInfo:GetMetadata()` through |
| Verifying a save with plain `GetAsync` | "Save failed" false alarms | `UseCache = false` |
| Studio API access enabled on the live game with no guard | Test sessions overwrite real saves | Separate test experience, or a Studio-only test key ([[Data Loss Prevention and Recovery]]) |
| Saving every coin pickup | 30x throttle errors at peak | Buffer in memory, autosave ([[Saving Correctly - Autosave and BindToClose]]) |
| Unbounded arrays (logs, history) in the profile | Profile grows until writes throttle or hit 4 MB | Cap and rotate |
| Sparse arrays | Data saved with string keys or truncated at the first hole | Keep arrays dense, or store maps with string keys deliberately |
| Storing `inf`/`nan` | Open Cloud tools receive tagged objects instead of numbers | Clamp numbers before saving |

## Checklist

- [ ] Every data store call is in `pcall`, with transient-error retry and backoff.
- [ ] Player data is written only through one module, with `UpdateAsync` and a session lock.
- [ ] Load failure and "new player" are different code paths.
- [ ] Keys follow `Prefix_{UserId}`; user ids passed on write.
- [ ] Profile size is measured (`#HttpService:JSONEncode(profile)`) and bounded.
- [ ] Verification reads use `UseCache = false`.
- [ ] Studio access is either off on the live game or guarded by a test-key scheme.
- [ ] A snapshot is taken before any release that touches data code.

## See also
[[Session Locking and Profile Libraries]] · [[Data Schema Design and Migrations]] · [[Saving Correctly - Autosave and BindToClose]] · [[Data Loss Prevention and Recovery]] · [[OrderedDataStores and Leaderboards]] · [[MemoryStore Service]] · [[Open Cloud APIs]] · [[Error Handling and Retries]] · [[Server Lifecycle and Shutdown]] · [[Case Study - Abilities That Only Worked in Studio]]

## Connected notes
<!-- auto-links:start -->
[[Debugging DataStore Problems]] · Cookbook - Data and Saving · Skill - Roblox DataStore Safety · Session Lock · Links - DataStoreService · Global Leaderboards End to End
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Cookbook - Data and Saving]] · [[AI Pitfalls - Data and Monetization]] · [[Session Lock]] · [[Serial-Numbered Limited Items - Atomic Counters]] · [[Schema Migrations - Worked Case Studies]] · [[Trading Systems Without Duplication]]
<!-- related:end -->
