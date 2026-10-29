---
tags: [data, datastore, data-loss, recovery, rollback, versioning, incident, type/guide, area/data, level/intermediate, api/DataStore, area/liveops]
---
# Data Loss Prevention and Recovery

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Assuming every write is a version (Only the first write per key per UTC hour is kept as a backup)
> - Avoid: Restoring with `SetAsync` while the player is online (Their session overwrites the restore on the next autosave, or the...)
> - Avoid: Restoring ordered stores from version history (They have none; rebuild from profiles)
> - Outside tools use an Open Cloud key scoped to this experience and store (entry list/read/update), ideally IP-restricted.
> - Failed load never leads to a save; "new" only when the read succeeded and returned nil.
> - Studio access is off on the live game or fully guarded (test key, simulator, side systems obey).
>
> Cost: TL;DR ~200 tok · whole note ~4.2k tok. Read more: ## Guard 3: validate before you write · ## Recovery tool 1: per-key version history · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Players forgive bugs. They rarely forgive losing a week of progress. This note is the defensive layer around everything else in this folder: where loss really comes from (most of it is self-inflicted), the guards that stop it before it happens, how to see it happening in production, and how to restore a player or a whole population from Roblox's built-in version history and snapshots. It ends with an incident runbook.

Prerequisites: [[DataStore Fundamentals]], [[Session Locking and Profile Libraries]], [[Saving Correctly - Autosave and BindToClose]].

## Where data loss comes from

Ranked roughly by how often they hurt real games (rule of thumb, consistent with the reference project's history):

| Source | Mechanism | Guard |
|---|---|---|
| **Defaults saved over real data** | Load failed (or timed out) and the session played on a default profile that saved | Separate "failed" from "new"; no save path without a successful load |
| **Developer mistakes in Studio** | Studio API access on the live game; a test resets or edits the real save | Test experience, or a Studio-only test key; "never reset the real save" rule |
| **Bad release** | New code corrupts or drops fields; migration bug | Snapshot before release, refusal of newer schemas, validation on save |
| **Session overlap** | Two servers own one profile (teleports) | Session locking + fencing |
| **Shutdown** | `BindToClose` missing or too slow | Parallel saves, wait for leave-saves |
| **Throttling** | Saves dropped by full queues | Fewer writes, staggering, monitoring |
| **State outside the profile** | Paid or earned state kept in attributes or another store | Everything that matters lives in the profile |
| **Platform incidents** | Backend errors for minutes | Retries, keep playing in memory, save when it recovers |

Notice how few of these are Roblox's fault. Most loss is code that wrote something it should not have.

## Guard 1: "new player" and "load failed" are different

```lua
--!strict
-- A GetAsync-based loader that gets this right (the session-locked module does the same via UpdateAsync).
local function loadProfile(store: DataStore, key: string): (string, any)
	for attempt = 1, 4 do
		local ok, value = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			if value == nil then
				return "new", nil      -- the call SUCCEEDED and the key is empty
			end
			return "loaded", value
		end
		task.wait(attempt)          -- the call FAILED: retry, never fall through to defaults
	end
	return "failed", nil            -- caller must not save anything for this player
end
```

The reference project's version of the rule: "A profile is written back only once it has been read successfully (or the player is confirmed brand new)... A failed read leaves the session unsaved instead of letting a blank profile overwrite real progress." On a failed load the player got an attribute (`DataLoadFailed`), a message ("Your saved progress couldn't load. Nothing will save this session, please rejoin"), and the session lease was released so the rejoin could load.

Every other path that writes defaults needs the same check. The same project had an admin convenience that reset an allowlisted account's progress on every join; it was explicitly written to reset only "after a successful read, so a DataStore outage can never turn into a blank overwrite".

## Guard 2: Studio cannot touch real saves by accident

Data stores are **not** isolated between Studio and live (memory stores are). With Studio API access enabled, a play test reads and writes the real keys. Roblox recommends enabling it only on a separate test experience. If you must test against the live experience (the reference project did, for convenience), build guards:

- **Test-profile key**: a `ServerStorage` attribute (`TestProfileKey = "fresh1"`) switches the key to `TEST_fresh1_<userId>`, read only when `RunService:IsStudio()` is true. New name = fresh profile.
- **Load-failure simulator**: `SimulateLoadFailure = true` forces the failed-load path so it can be tested.
- **Side systems obey the test key**: leaderboards and secondary stores do not write; developer grants are skipped; owned game passes are ignored so a "fresh" profile is fresh.
- **Clear the flags after testing.** The project recorded both a test key accidentally left set (the developer's own Play sessions then silently used the test profile, which looks exactly like data loss) and a rule "never set the test key before Play has actually started".
- **A written rule**: "never reset the real save". The owner's real profile was a valuable regression fixture (83 items and $4.5M of in-game cash at one point) precisely because it was old and messy.

## Guard 3: validate before you write

A save should refuse data that is obviously broken, keep the last good copy, and alert. Cheap checks catch whole classes of bugs:

```lua
--!strict
-- Returns nil if OK, or a reason string. Run on the snapshot inside ProfileManager.save
-- (before UpdateAsync); on failure skip the write, keep the session, and report.
local function validateProfile(data: { [string]: any }, lastSaved: { [string]: any }?): string?
	local function badNumber(n: any): boolean
		return type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge or n < 0
	end
	if badNumber(data.Coins) or badNumber(data.Gems) then
		return "currency is not a finite non-negative number"
	end
	if type(data.Items) ~= "table" then
		return "items missing"
	end
	if lastSaved and type(lastSaved.Items) == "table" then
		local before, after = #lastSaved.Items, #data.Items
		-- losing most of an inventory in one autosave interval is almost always a bug
		if before >= 20 and after < before * 0.2 then
			return `items dropped from {before} to {after}`
		end
	end
	return nil
end
```

Tune the heuristics to your game (a "sell all" button legitimately empties inventories; record that action in the profile so the validator can allow it). When validation fails, the session keeps its in-memory state, nothing is written, and the incident is logged ([[Crash and Error Telemetry]]). That turns a silent corruption into a visible alert while the good copy is still the latest version.

Also keep **audit trails inside the profile** for anything a migration or system takes away (the reference project stored `{ time, ids, paid }` when it stripped developer-only items from normal players). Support can then explain and reverse it.

## Guard 4: tell the player

Silent failure is the worst kind. The reference project published save health to the client through player attributes (`SaveBlocked = "stale"` when the session lost ownership, `DataLoadFailed` on load failure) and a banner UI that stayed up while either was set, plus notifications such as "Your progress was saved on another server. Rejoin to keep playing safely." Players who see a warning rejoin; players who do not keep playing for an hour in a session that can never save.

Also block monetization when data is not healthy: no purchase prompts while a profile is not saveable ([[Purchase Data and Receipts]]).

## Seeing problems in production

- **Data Stores observability dashboard** (Creator Hub > your experience > Monitoring > Data Stores): Storage Usage, Request Count by API, Request Count by Status, quota usage per category (read, write, list, remove), 30 days of history; the most recent three minutes may be incomplete. Spikes in throttle or error statuses after a release are the first sign of trouble.
- **Custom alerts** on those metrics, so a sustained failure pages someone (Roblox's best-practices page recommends it).
- **Your own telemetry**: count load results (`new`, `loaded`, `failed`, `locked`) and save results (`saved`, `error`, `lost`, `invalid`) per server and send aggregates through `AnalyticsService` custom events or an external endpoint ([[Analytics and Funnels]], [[HttpService and External APIs]]). A rising `locked` rate means sessions are not releasing; a rising `invalid` rate means a bug is producing bad data.
- **Support channel**: player reports with user id and approximate time are exactly what version restore needs.

## Recovery tool 1: per-key version history

Standard data stores keep a backup on the first write to each key in each UTC hour, for 30 days after it is superseded ([[DataStore Fundamentals]]). Restoring one player:

```lua
--!strict
-- Run from a server-side admin tool (never exposed to clients). Restores a key to the
-- version current at `whenMs`, but only if no live session holds it, and keeps the result
-- lease-free so the player's next join loads it normally.
local DataStoreService = game:GetService("DataStoreService")

local function restoreToTime(storeName: string, key: string, whenMs: number): (boolean, string)
	local store = DataStoreService:GetDataStore(storeName)
	local okOld, oldValue, oldInfo = pcall(function()
		return store:GetVersionAtTimeAsync(key, whenMs)
	end)
	if not okOld then
		return false, `read failed: {oldValue}`
	end
	if type(oldValue) ~= "table" then
		return false, "no restorable version at that time"
	end
	local result = "error"
	local okWrite, err = pcall(function()
		store:UpdateAsync(key, function(current: any, keyInfo: DataStoreKeyInfo?)
			result = "error"
			local held = if type(current) == "table" then current.Session else nil
			if type(held) == "table" and (tonumber(held.ExpiresAt) or 0) > os.time() then
				result = "player is online (live lease); kick them or wait"
				return nil
			end
			local restored = table.clone(oldValue)
			restored.Session = nil
			-- keep the version counter moving forward so no stale server can win
			restored.SaveVersion = math.max(
				tonumber(restored.SaveVersion) or 0,
				if type(current) == "table" then tonumber(current.SaveVersion) or 0 else 0
			) + 1
			restored.RestoredFrom = { at = os.time(), versionTime = whenMs }
			result = "restored"
			local userIds = if keyInfo then keyInfo:GetUserIds() elseif oldInfo then oldInfo:GetUserIds() else nil
			local metadata = if keyInfo then keyInfo:GetMetadata() elseif oldInfo then oldInfo:GetMetadata() else nil
			return restored, userIds, metadata
		end)
	end)
	if not okWrite then
		return false, `write failed: {err}`
	end
	return result == "restored", result
end
```

To browse rather than jump to a time, `ListVersionsAsync(key, Enum.SortDirection.Descending, minDateMs, maxDateMs, pageSize)` returns `DataStoreVersionPages`; each entry is a `DataStoreObjectVersionInfo` with `Version`, `CreatedTime` and `IsDeleted` (property names per the engine reference; verify in your Studio version), and `GetVersionAsync(key, version)` reads one.

Without code: the **Data Stores Manager** in Creator Hub lets you open a key, compare the current version with an earlier one, and **revert**, which writes a new version containing the old value (requires edit permission on data stores). It does not know about your lease field, so revert only offline players, and remember the reverted value may contain an old `Session` record; the module in [[Session Locking and Profile Libraries]] tolerates that (an expired lease is claimable).

Limits of version history:

- Roughly **one restore point per hour of activity**. If corruption happened at 14:10 and the player saved again at 14:40, the 14:00 version already contains the corruption only if the hour's first write was after 14:10. Pick a time before the bug's release.
- **30 days** after being superseded. Act fast.
- Ordered data stores have **no** versions; rebuild them from profiles.

For a support tool outside Roblox, use the Open Cloud data stores API with an API key limited to this experience and data store, granting only the entry list, read and update permissions it needs, with an IP allowlist and expiry where possible.

## Recovery tool 2: snapshots

The Open Cloud **Snapshot Data Stores** API takes a snapshot of all of an experience's data stores, available **once per day**. Roblox's guidance: take one right before publishing any update that changes data logic. Why it matters, in their example: release at 3:30 UTC corrupts data; without a snapshot, writes in 3:00 to 3:30 are lost because that hour's backup gets overwritten by corrupted writes; with a snapshot at 3:29 the latest good value of every key is preserved. Put the snapshot call in your release checklist or deployment script ([[Open Cloud APIs]], [[Release Process and Rollbacks]]).

## Recovery tool 3: bulk restore

For a bad release that hit many players:

1. **Stop the bleeding**: roll back the place version or ship a hotfix that refuses to save (validation), then migrate servers.
2. **Find affected keys**: your telemetry (users who loaded during the bad window), or list keys and compare `UpdatedTime` with the release window.
3. **Restore** each key to a time before the release with Open Cloud (list entry revisions, read the chosen revision, write it back), rate-limited because Open Cloud shares the live experience budget, and skipping keys with live leases (retry them later).
4. **Compensate** for progress legitimately earned after the restore point, if you can identify it, and communicate clearly.

Roblox's open-source Data Stores Batch Processor is designed for large jobs like this.

## Incident runbook

| Step | Action |
|---|---|
| 1 | Confirm: reports, dashboard error/throttle spikes, telemetry `failed`/`invalid` counts |
| 2 | Decide if saving is harmful. If yes, publish a hotfix that disables saves (keep load working) or roll back the place version, then migrate servers |
| 3 | Snapshot now (if not taken in the last day), so the current state is preserved before any repair |
| 4 | Identify the window and affected keys |
| 5 | Test the restore on a copy (or a test experience) with real exported data |
| 6 | Restore offline players first; for online players, kick with a message, then restore |
| 7 | Verify with `UseCache = false` reads and in-game |
| 8 | Post-mortem: which guard was missing ([[Lessons Learned Index]]) |

## Common mistakes

| Mistake | Consequence |
|---|---|
| Assuming every write is a version | Only the first write per key per UTC hour is kept as a backup |
| Restoring with `SetAsync` while the player is online | Their session overwrites the restore on the next autosave, or the restore overwrites their session |
| Restoring ordered stores from version history | They have none; rebuild from profiles |
| Waiting weeks to restore | Versions older than 30 days after supersession are gone |
| No snapshot before a data-logic release | The corrupted hour cannot be recovered |
| Validation that blocks legitimate actions | Players lose progress because saves are refused; log and allowlist known actions |
| Fixing data by hand in the manager during peak | Concurrent sessions overwrite your edit |

## Checklist

- [ ] Outside tools use an Open Cloud key scoped to this experience and store (entry list/read/update), ideally IP-restricted.
- [ ] Failed load never leads to a save; "new" only when the read succeeded and returned nil.
- [ ] Studio access is off on the live game or fully guarded (test key, simulator, side systems obey).
- [ ] Saves validated; failures alert and keep the last good copy.
- [ ] Players see save problems; purchases blocked while unhealthy.
- [ ] Dashboard alerts configured; load/save outcomes in telemetry.
- [ ] Restore tool tested; respects leases.
- [ ] Snapshot step in every release that touches data code.

## See also
[[DataStore Fundamentals]] · [[Session Locking and Profile Libraries]] · [[Saving Correctly - Autosave and BindToClose]] · [[Data Schema Design and Migrations]] · [[Open Cloud APIs]] · [[Release Process and Rollbacks]] · [[Crash and Error Telemetry]] · [[Safe Changes in a Shared Place]] · [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Debugging DataStore Problems]] · Live Incident Response and Post-Mortems · Skill - Roblox DataStore Safety · Cookbook - Data and Saving · Saved Inventory End to End · Session Lock
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Schema Migrations - Worked Case Studies]] · [[Cookbook - Data and Saving]] · [[Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts]] · [[Global State and Live Config]] · [[Player Privacy and Data Deletion]] · [[Trading Systems Without Duplication]] · [[OrderedDataStores and Leaderboards]] · [[Serial-Numbered Limited Items - Atomic Counters]] · [[MemoryStore Service]]
<!-- related:end -->
