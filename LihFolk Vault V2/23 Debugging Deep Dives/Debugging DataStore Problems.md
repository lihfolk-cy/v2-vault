---
tags: [debugging, datastores, persistence, throttling, session-locking, open-cloud, type/guide, area/debugging, level/advanced, api/DataStore, area/data, api/DataStoreService]
---
# Debugging DataStore Problems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Verifying a save with a cached `GetAsync`.
> - Avoid: Debugging on the real key, or testing migrations in Studio against live stores.
> - Avoid: Retrying throttled requests immediately in a loop (makes throttling worse).
> - Symptom classified; uncached read done before anything else.
> - Budget logged periodically and before bursts.
> - Autosaves staggered; leaderboards and counters batched.
>
> Cost: TL;DR ~140 tok · whole note ~4.8k tok. Read more: ## 2. Throttling and budgets · ## 3. Stuck session locks · ## Common mistakes · ## Checklist
<!-- tldr:end -->

DataStore bugs are the most expensive bugs in a Roblox game: they lose progress, duplicate items, and generate support tickets you cannot answer. They are also hard to debug because the evidence (what is actually stored) lives in a cloud service, the failure often happened on a server that no longer exists, and Studio behaves differently from live. This note is a diagnostic guide: how to read throttling and budget problems, how to tell a stuck session lock from a real outage, how to look at the actual saved data safely, and how Studio access changes what you see.

The limits, error codes and caching rules are in [[DataStore Fundamentals]]; leases and fencing in [[Session Locking and Profile Libraries]]; correct save flow in [[Saving Correctly - Autosave and BindToClose]]; recovery in [[Data Loss Prevention and Recovery]]. This note links to them rather than repeating the tables.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. Classify the symptom first

| Symptom | Most likely family | First check |
|---|---|---|
| Saves take 10 to 30 s, then errors 301 to 306 | throttling, queue full | budget logging (section 2) |
| "Data failed to load" for some players at peak times | experience-wide budget, or backend incident | budget logging, Roblox status page |
| Player cannot load after a server crash; works after a few minutes | stuck lease | read the lease (section 3) |
| Progress rolled back by minutes or hours | save not reaching the store, or stale overwrite | version history of that key (section 4) |
| Items duplicated | missing lease or fencing, or a trade race | version history, audit log ([[Trading Systems Without Duplication]]) |
| Works in live, fails in Studio (or the reverse) | Studio API access, Studio limits, test keys | section 5 |
| Value "did not save" when you verify right after | the 4 second `GetAsync` cache | re-read with `UseCache = false` ([[DataStore Fundamentals]]) |
| `105 ValueTooLarge` or `104 CantStoreValue` | data shape | section 6 |

The single biggest time-waster (measured in the reference project, also described in [[DataStore Fundamentals]]): concluding "the save failed" because a verification `GetAsync` returned the cached old value. Always verify with an uncached read before debugging anything else.

---

## 2. Throttling and budgets

### 2.1 What throttling looks like

When a server exceeds its request budget, requests go into a queue and the calling thread yields longer. When the queue (30 requests per type, per [[DataStore Fundamentals]]) is full, new requests fail with a `30x` throttle error. Output usually shows a warning that a request was added to the queue before the errors start (exact wording unverified; it mentions the queue and the key).

The sequence in logs:
1. Normal saves at 0.1 to 0.5 s.
2. A burst event (everyone saves at once, a leaderboard refresh, a migration loop).
3. Queue warnings, saves taking seconds.
4. Throttle errors; saves dropped.

### 2.2 Measure the budget, do not guess

`DataStoreService:GetRequestBudgetForRequestType(requestType)` returns the current budget (Docs). Log it around your heavy operations and every minute:

```lua
--!strict
-- Server: periodic DataStore budget log (keep at warn only when low).
local DataStoreService = game:GetService("DataStoreService")

local TYPES = {
	Enum.DataStoreRequestType.GetAsync,
	Enum.DataStoreRequestType.SetIncrementAsync,
	Enum.DataStoreRequestType.UpdateAsync,
	Enum.DataStoreRequestType.GetSortedAsync,
}
local LOW = 10

task.spawn(function()
	while true do
		task.wait(60)
		for _, t in TYPES do
			local budget = DataStoreService:GetRequestBudgetForRequestType(t)
			if budget < LOW then
				warn(("[ds budget] %s low: %d"):format(t.Name, budget))
			end
		end
	end
end)
```

The newer request type members (`StandardRead`, `StandardWrite` and so on) are listed in [[DataStore Fundamentals]]; use whichever set matches your engine version (both exist as of October 2026 per that note).

Before a burst operation (a migration, a bulk leaderboard write), check the budget and pace yourself:

```lua
--!strict
local function waitForBudget(t: Enum.DataStoreRequestType, need: number, maxWait: number): boolean
	local start = os.clock()
	while DataStoreService:GetRequestBudgetForRequestType(t) < need do
		if os.clock() - start > maxWait then
			return false
		end
		task.wait(1)
	end
	return true
end
```

### 2.3 Find the burst

Throttling is almost always a burst, not a steady overload. Common culprits (rule of thumb, all seen in production games):

| Culprit | Fix |
|---|---|
| Autosave timer started at the same moment for all players (server start) | stagger: each player's autosave starts at a random offset |
| Leaderboard refresh with `GetSortedAsync` every few seconds in every server | refresh every 60 s or more, cache, or use MemoryStore ([[OrderedDataStores and Leaderboards]]) |
| `IncrementAsync` per kill for global stats | batch per server per minute |
| Saving on every inventory change | mark dirty, save on a timer and on leave |
| A migration or cleanup loop in game code | run it through Open Cloud at a controlled rate, or pace it with budget checks |
| Retries without backoff | exponential backoff with jitter ([[Error Handling and Retries]]) |

Remember the experience-wide budget is shared by **all servers and Open Cloud** ([[DataStore Fundamentals]]). A support tool or migration script running from outside can throttle every live server. When throttling starts at a time nobody shipped anything, ask who ran a script.

### 2.4 Per-key limits

A single hot key (a global counter, a shared guild record) hits per-key throughput long before the experience budget. Symptoms: only operations on that key throttle, and server-wide budgets look fine. Fix: shard the key (N keys, sum when reading), batch writes, or move the hot value to MemoryStore and persist periodically ([[MemoryStore Service]]).

---

## 3. Stuck session locks

A session lock (lease) prevents two servers from owning one profile. When a server dies without releasing, the lease stays until it expires. [[Session Locking and Profile Libraries]] has the full design; here is how to debug one.

### 3.1 Is it stuck, or is another server really using it?

Read the lease. In a lease-based design the profile key (or a separate lock key) contains the owning server's `JobId` and an expiry time. From Studio with API access (on a copy of the data, section 4.3) or through a support tool:

```lua
-- Command bar (Studio, API access on): read the lease without changing anything.
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerData")
local options = Instance.new("DataStoreGetOptions")
options.UseCache = false
local value, keyInfo = store:GetAsync("User_0000000000", options)
if value and value.lease then
	print("owner job", value.lease.jobId, "expires in", value.lease.expiresAt - os.time(), "s")
end
print("version", keyInfo and keyInfo.Version, "updated", keyInfo and keyInfo.UpdatedTime)
```

(Field names depend on your schema; `lease.jobId` and `lease.expiresAt` are examples.)

Interpretation:
- **Expiry in the future, owner job id is a live server**: the player really is in another server (or their old server is still shutting down). Not a bug; show "your data is in use, retrying".
- **Expiry in the future, owner is gone**: a crashed server. Expected to clear at expiry. If this happens often, your servers are crashing (check the Performance dashboard, [[Crash and Error Telemetry]]) or your leases are too long.
- **Expiry in the past and loads still fail**: a bug in your claim logic (clock assumptions, comparison direction, or the claim `UpdateAsync` returning nil without retry).
- **Owner job id equals the current server**: the same server is trying to claim twice, often a rejoin before `PlayerRemoving` finished. Allow reclaim by the same job id.

### 3.2 The Studio lease trap

In Studio every play test is a new "server". If a play test ends abruptly, the lease from that session stays until expiry, so the next test cannot load. The reference project measured this at about 90 seconds of "cannot load" after each stop until it added a Studio takeover rule ([[Session Locking and Profile Libraries]] covers the fix). If loading fails only in Studio, only on the second test, think lease first.

### 3.3 Never "fix" a lock by hand in production

Clearing a lease on a live key while its owner server is still alive creates exactly the two-owner situation the lock exists to prevent. If you must force-release, do it only after confirming the owner server is gone (its job id not in your server registry, or the lease well past expiry), and log it.

---

## 4. Reading the actual saved data

When a player reports loss, the stored data is the only ground truth. Look at it before touching code.

### 4.1 Tools

| Tool | Good for | Notes |
|---|---|---|
| Creator Dashboard **Data Stores Manager** | browsing keys and values, quick checks | Docs; read-only browsing is safe; check what edit actions your version offers before clicking anything |
| Studio command bar with API access | `GetAsync`, `ListVersionsAsync`, `GetVersionAsync` in Luau | runs against the **live** stores of the published experience (see 5.1) |
| Open Cloud DataStore API | scripted support tools, bulk reads | shares the experience budget ([[Open Cloud APIs]]) |
| Open Cloud Luau Execution | running Luau (including DataStore calls) in a headless server for a place version | section 4.4 |

### 4.2 Version history is your time machine

Each write creates a version (Docs; versions are kept for a limited time, see [[DataStore Fundamentals]]). To investigate a rollback:

```lua
-- Command bar: list recent versions of one key, newest first.
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerData")
local pages = store:ListVersionsAsync("User_0000000000", Enum.SortDirection.Descending)
local page = pages:GetCurrentPage()
for i, info in page do
	if i > 20 then break end
	print(info.Version, DateTime.fromUnixTimestampMillis(info.CreatedTime):ToIsoDate(), info.IsDeleted)
end
```

Then fetch specific versions with `GetVersionAsync(key, version)` and compare a few fields (level, currency, item count). Patterns:
- **A sudden drop between two versions written by different servers**: a stale overwrite (no lease, or unfenced save). If your saves record the writing `JobId` and a session counter in the value, this is immediately visible. Record them; it costs a few bytes.
- **No versions at all during the period the player played**: saves never reached the store (errors swallowed, budget exhaustion, server crash before autosave).
- **Many versions seconds apart**: you are saving too often (and burning per-key throughput).

### 4.3 Never debug on the real key

Copy the value to a test key, then experiment on the copy. Reading is safe; any write while investigating risks making the loss permanent. A small support module that does "copy key X version V to key `Debug_X`" is worth writing once ([[Data Loss Prevention and Recovery]]).

### 4.4 Open Cloud Luau Execution (as of October 2026)

The Open Cloud Luau Execution API (Docs, endpoints marked stable) runs a Luau script in a headless server: a server launches, loads the place (or a specific place version), and runs your script. Documented properties:
- Server and local scripts in the place **do not** run automatically; physics does not run.
- Scripts up to 4 MB, running up to 5 minutes; returned values up to 4 MB after JSON encoding; logs keep at most about 450 KB.
- At most ten incomplete tasks per place; task results are retained for 24 hours.
- Data model changes are local to the task unless saved explicitly, but **DataStore calls are real** (the docs warn to take care).
- Rate limits (Roblox docs, as of October 2026): 5 task creations per minute, 200 task reads per minute and 45 log reads per minute, all per API key owner. Recheck the reference page, as these change.

What this means for debugging: it is **not** a way to attach to a live game server. It is a way to run your own modules (for example, your profile loader and migration code) against real stored data without opening Studio, from a CI job or a support tool. Use it to answer "does this player's stored profile load with the current migration code?" against a copy of their data. Treat it as production access: the API key that can run it can read and write every data store.

---

## 5. Studio versus live

### 5.1 Studio API access

DataStores in Studio require **Enable Studio Access to API Services** in Game Settings, Security (Docs). Without it, calls fail with error 403. With it, **Studio reads and writes the real live data stores** of that experience. There is no separate Studio database.

Consequences:
- A play test can overwrite your own real profile with test data. Use test keys or a separate store name in Studio (for example a `"PlayerData_Studio"` store chosen when `RunService:IsStudio()`), or a separate test experience.
- A bug in a migration tested in Studio can damage live data. Test migrations against a copy.
- Turning access off in Studio is a safe default for people who do not need it.

### 5.2 Studio limits differ

Studio uses its own request limits (Docs mention static limits for Studio; [[DataStore Fundamentals]]). Throttling in Studio does not prove throttling live, and the reverse. Test budget behaviour with several clients in a live test server ([[Multi-Client and Live Testing]]).

### 5.3 BindToClose in Studio

When you stop a play test, Studio closes the server and runs `BindToClose` callbacks, but the time available and the order relative to `PlayerRemoving` differ from a live shutdown (rule of thumb; the precise Studio timing is not documented). Saves that work live can fail in Studio and the reverse. Do not treat "it saved when I stopped the test" as proof of correct shutdown saving. Test shutdown in a live test server with a soft shutdown ([[Server Lifecycle and Shutdown]]).

---

## 6. Data shape errors

| Error | Usual cause | How to find it |
|---|---|---|
| `104 CantStoreValue` | an Instance, function, mixed table, NaN or invalid UTF-8 in the value | walk the table before saving (below) |
| `105 ValueTooLarge` | profile over the size limit, usually an unbounded log or history | measure `#HttpService:JSONEncode(value)` per top-level field |
| Silent loss of fields | sparse arrays or mixed keys get mangled by serialisation | same walker; keep arrays dense and dictionaries string-keyed |
| Numbers changed slightly | floats round-trip, huge integers beyond 2^53 lose precision | store large ids as strings |

A Studio-only validator that walks the profile before each save:

```lua
--!strict
local function validate(value: any, path: string, problems: { string })
	local t = typeof(value)
	if t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			table.insert(problems, path .. ": NaN or inf")
		end
	elseif t == "string" then
		if utf8.len(value) == nil then
			table.insert(problems, path .. ": invalid UTF-8")
		end
	elseif t == "table" then
		local hasNumber, hasString = false, false
		for k, v in value do
			if type(k) == "number" then hasNumber = true
			elseif type(k) == "string" then hasString = true
			else table.insert(problems, path .. ": key of type " .. type(k)) end
			validate(v, path .. "." .. tostring(k), problems)
		end
		if hasNumber and hasString then
			table.insert(problems, path .. ": mixed keys")
		end
	elseif t ~= "boolean" and t ~= "nil" then
		table.insert(problems, path .. ": unsupported " .. t)
	end
end
```

Run it in Studio on every save and log problems; in live, run it on a sample, or only after a `104` error.

---

## 7. A worked example

**Report:** several players say they lost about an hour of progress after an update.

1. **Classify.** Rollback by about an hour. Version history family.
2. **Versions.** For three affected players: normal versions every few minutes, then a version at the update time with values from an hour earlier. The rollback version was written by a server whose session counter was lower than the one before it.
3. **Explain.** During the update, servers were shutting down. Old servers saved on shutdown; one old server had a stale copy of the profile because the player had moved to a new server an hour earlier, and the old server's copy was never released (a leak of profile references after `PlayerRemoving` failed). On shutdown it saved everything it held.
4. **Fix.** Fence saves with the lease (a server that no longer owns the lease cannot save), and remove profiles from the server's table when release completes or fails.
5. **Recover.** For affected keys, restore the last good version with a reviewed support script, after copying current values to a backup key.
6. **Guard.** Count "save rejected: not owner" events. A non-zero count now proves the fence works and shows how often the old bug would have struck.

---

## Common mistakes

- Verifying a save with a cached `GetAsync`.
- Debugging on the real key, or testing migrations in Studio against live stores.
- Retrying throttled requests immediately in a loop (makes throttling worse).
- Clearing leases by hand while the owner might be alive.
- Saving the whole profile on every change.
- No writer identity in saved data, so stale overwrites cannot be proven.
- Treating Studio stop as a test of shutdown saving.

## Checklist

- [ ] Symptom classified; uncached read done before anything else.
- [ ] Budget logged periodically and before bursts.
- [ ] Autosaves staggered; leaderboards and counters batched.
- [ ] Lease contents readable by a support tool; same-server reclaim allowed.
- [ ] Saved values include writer job id and session counter.
- [ ] Version history checked for every loss report.
- [ ] Studio uses test keys or a separate store; API access only for those who need it.
- [ ] Profile validator runs in Studio before saves.
- [ ] Open Cloud keys that can run Luau or touch data stores are treated as production credentials.

## See also

[[Debugging Start Here]] · [[DataStore Fundamentals]] · [[Session Locking and Profile Libraries]] · [[Saving Correctly - Autosave and BindToClose]] · [[Data Loss Prevention and Recovery]] · [[Data Schema Design and Migrations]] · [[Open Cloud APIs]] · [[MemoryStore Service]] · [[Trading Systems Without Duplication]] · [[Debugging Live Servers]]

## Connected notes
<!-- auto-links:start -->
[[Cookbook - Data and Saving]] · Skill - Roblox DataStore Safety · Session Lock · Saved Inventory End to End · Data Schema Versioning · Multiplayer Services Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Session Lock]] · [[AI Pitfalls - Data and Monetization]] · [[Data and Cloud Changes 2025-2026]] · [[The Debugging Method - Reproduce Isolate Bisect]] · [[Debugging Race Conditions and Yield Order]] · [[Reading Luau Errors and Stack Traces]]
<!-- related:end -->
