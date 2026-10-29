---
tags: [data, datastore, session-locking, profiles, profilestore, dupes]
---
# Session Locking and Profile Libraries

<!-- tldr:start -->
> [!tldr] TL;DR
> - Items duplicated after teleports: No lease, or saves not fenced -> Search for `SetAsync` / unfenced `UpdateAsync` on player keys
> - "Progress saved on another server" messages in normal play: Two servers both loaded the key (version-only guard) -> Add a lease
> - Players cannot rejoin for ~1 to 5 minutes after a server crash: Lease length -> Expected; shorten the lease or show a countdown
> - Lease written and checked inside the same `UpdateAsync` as the data.
> - Every save is fenced by a per-session token; "lost" stops all writes.
> - Autosave interval is shorter than the lease and renews it.
>
> Cost: TL;DR ~190 tok · whole note ~6.3k tok. Read more: ## A complete session-locked profile module · ## Exposing the profile to the rest of the game (the bridge) · ## Failure modes and diagnosis · ## Checklist
<!-- tldr:end -->

Every serious Roblox game keeps a player's data **in server memory** for the session and writes it back periodically. That design is only safe if **one server at a time** owns a given player's data. Session locking is the mechanism that guarantees it. This note explains why it is needed (with the exact failure sequences), how to build a lease-based lock on `UpdateAsync` correctly, the production lessons from one shipped game (including a 90 second lease that blocked Studio test loads), and how the common libraries (ProfileStore, ProfileService, Roblox's sample) compare.

Prerequisites: [[DataStore Fundamentals]]. Follow-ups: [[Saving Correctly - Autosave and BindToClose]], [[Data Schema Design and Migrations]], [[Purchase Data and Receipts]].

## Why "load, play, save" is not enough

Roblox only lets a client connect to one server at a time, so it is tempting to assume one player's data is only ever live in one place. It is not. Roblox's own player-data guide lists the ways a player's next session can start before the last one finished saving:

1. Server A's final save fails and is retrying while the player joins server B.
2. Server A is throttled and the final `UpdateAsync` sits in the queue (see the 30-request queues in [[DataStore Fundamentals]]).
3. Code on `PlayerRemoving` in server A yields (a remote call, an analytics post) before the save starts.
4. Server A is so loaded that the save runs late.

Teleports make all four common, because the player is on the new server within seconds. Now trace it:

```text
t=0   Server A has Coins=100 in memory. Player trades 50 coins worth of items away.
t=1   Player teleports. A starts its final save (slow).
t=2   Server B loads the key: still the OLD value (Coins=100, items present).
t=3   A's save lands: Coins=50, items gone.
t=60  B autosaves its copy: Coins=100, items present again.  -> items duplicated
```

The reverse ordering loses progress instead of duplicating it. Players discover the duplicating version deliberately: it is the classic Roblox trade dupe. `UpdateAsync` alone does not fix it, because B's autosave is a perfectly valid read-modify-write of B's stale copy.

The fix has two halves:
- **Exclusion on load**: B must not start a session while A still owns the key.
- **Fencing on save**: if A somehow lost ownership (its lease expired, someone forced a takeover), A's late writes must be refused.

## Leases, not locks

A lock that is only released by its owner is a disaster when the owner crashes: the player can never load again. So every practical scheme is a **lease**: the owner writes `{ Token, ExpiresAt }` into the key and must keep renewing it. If the owner dies, the lease expires and another server may claim it.

Lease length is a trade-off:

| Lease | Upside | Downside |
|---|---|---|
| Short (30 to 60 s) | A crashed server's players can rejoin quickly | Must renew often; a slow backend can make a healthy server lose its own lease |
| Long (90 to 300 s) | Robust through backend hiccups | After a crash, or a release that failed, the player waits that long |

Rules of thumb: renew at a third of the lease or more often; make the autosave interval shorter than the lease (Roblox's best-practices page says the same: "shorter than any session-lock expiration"); fold renewal into the autosave so it costs nothing extra.

One production game used **a 90 second lease, renewed every 30 seconds**, claim attempts 6 times with waits of 0.5, 1, 1.5, 2 and 2.5 s (7.5 s total) before giving up.

### Where to store the lease

| Option | Notes |
|---|---|
| A field in the value (`record.Session`) | Simple, visible in Data Stores Manager, one write updates data and lease together. Used by the reference project |
| Key metadata (`LockId` via `SetMetadata` / transform's third return) | What Roblox's sample does. Keeps the value clean. Metadata is capped at 300 characters, and you must pass it through on every write or it is erased |
| A MemoryStore hash map entry | Fast and expiring, but a second system that can disagree with the data store. Only worth it for very advanced setups |

Either of the first two is fine. The important part is that **the lease check and the data write happen in the same `UpdateAsync`**.

### Clocks

`ExpiresAt` uses `os.time()`. Different servers' clocks are close but not identical. With leases measured in tens of seconds, a few seconds of skew is harmless; just never use leases shorter than about 30 s, and never compare `os.clock()` values across servers (it is per-process).

## The fencing token, and why a version counter alone is not enough

The owner generates a random token (`HttpService:GenerateGUID(false)`) when it claims the key. Every save checks "is the token in the stored record still mine?" inside the transform. If not, the save aborts and the session stops writing.

The reference project's first version used a different guard: a `SaveVersion` counter. Each save required the stored counter to equal what this server last wrote, then incremented it. That does stop stale overwrites, but it has two weaknesses the team ran into:

1. **It does not stop two servers from loading the same version.** Both load v7, both play; the first save makes it v8, the second server's save is refused and its **whole session** is thrown away. No dupe, but lost progress, and the player saw "Your progress was saved on another server". The team added the lease ("makes quick teleports wait for the old server to release the key") on top.
2. **Unknown-outcome writes look like a stranger's write.** A save can error after the backend actually committed it ([[DataStore Fundamentals]]). The stored counter is now one ahead of what the server believes, and a strict "must equal" check marks the server's own data as foreign. With a token, the rule is simpler and correct: if the stored token is mine, every write since my claim was mine, whatever the counter says.

So: use the token as the authority, keep a version counter for diagnostics and for refusing writes from old code that predates tokens.

## A complete session-locked profile module

This is a self-contained server module. It claims with retries, builds or migrates the profile, saves with fencing, releases on leave, and exposes state for the rest of the game. Autosave, `BindToClose` and the retry helper live in [[Saving Correctly - Autosave and BindToClose]]; migrations in [[Data Schema Design and Migrations]].

```lua
--!strict
-- ServerScriptService/Data/ProfileManager (ModuleScript)
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Schema = require(script.Parent.Schema) -- newProfile(), migrate(data) (see the migrations note)

local STORE_NAME = "PlayerData_v1"
local LEASE_SECONDS = 90
local CLAIM_ATTEMPTS = 6

local store = DataStoreService:GetDataStore(STORE_NAME)
local IS_STUDIO = RunService:IsStudio()

export type LoadStatus = "ready" | "locked" | "failed" | "left"
export type Profile = {
	UserId: number,
	Key: string,
	Token: string,
	Data: { [string]: any },
	SaveVersion: number,
	IsNew: boolean,
	State: "active" | "lost" | "released",
	Saving: boolean,
}

type SessionRecord = { Token: string, JobId: string, PlaceId: number, ExpiresAt: number, Studio: boolean? }

local ProfileManager = {}
ProfileManager.LeaseSeconds = LEASE_SECONDS

-- Studio-only isolated key: ServerStorage attribute TestProfileKey = "fresh1" plays on a
-- separate save so tests never touch the real one. Ignored on live servers.
local function keyFor(userId: number): string
	if IS_STUDIO then
		local test = ServerStorage:GetAttribute("TestProfileKey")
		if type(test) == "string" and test ~= "" and #test <= 20 then
			return `TEST_{test}_{userId}`
		end
	end
	return `User_{userId}`
end
ProfileManager.keyFor = keyFor

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[deepCopy(k)] = deepCopy(v)
	end
	return out :: any
end
ProfileManager.deepCopy = deepCopy

local function newSession(token: string): SessionRecord
	return {
		Token = token,
		JobId = game.JobId,
		PlaceId = game.PlaceId,
		ExpiresAt = os.time() + LEASE_SECONDS,
		Studio = if IS_STUDIO then true else nil,
	}
end

-- One claim attempt. Returns outcome plus the stored record when claimed.
local function tryClaim(key: string, userId: number, token: string): (string, any, number?)
	local outcome, lockedUntil = "error", nil :: number?
	local ok, result = pcall(function()
		return store:UpdateAsync(key, function(old: any, keyInfo: DataStoreKeyInfo?)
			outcome, lockedUntil = "error", nil -- reset: the transform can run several times
			if old ~= nil and type(old) ~= "table" then
				outcome = "malformed"
				return nil
			end
			local record = old or { SaveVersion = 0 }
			local held = record.Session
			if type(held) == "table" and held.Token ~= token then
				local expires = tonumber(held.ExpiresAt) or 0
				-- A lease left by a Studio test session may be taken by another Studio session
				-- (see "the 90 second Studio trap" below). Live leases are always honoured.
				local studioTakeover = IS_STUDIO and held.Studio == true
				if expires > os.time() and not studioTakeover then
					outcome, lockedUntil = "locked", expires
					return nil
				end
			end
			record.Session = newSession(token)
			outcome = "claimed"
			local userIds = if keyInfo then keyInfo:GetUserIds() else { userId }
			local metadata = if keyInfo then keyInfo:GetMetadata() else nil
			return record, userIds, metadata
		end)
	end)
	if not ok then
		warn(`[ProfileManager] claim error for {key}: {result}`)
		return "error", nil, nil
	end
	return outcome, result, lockedUntil
end

function ProfileManager.load(player: Player): (LoadStatus, Profile?)
	local userId = player.UserId
	local key = keyFor(userId)
	local token = HttpService:GenerateGUID(false)
	local lastOutcome = "error"
	for attempt = 1, CLAIM_ATTEMPTS do
		if not player.Parent then
			return "left", nil
		end
		local outcome, record, lockedUntil = tryClaim(key, userId, token)
		lastOutcome = outcome
		if outcome == "claimed" and type(record) == "table" then
			local isNew = record.Data == nil
			local okMigrate, data = pcall(function()
				return if isNew then Schema.newProfile() else Schema.migrate(record.Data)
			end)
			if not okMigrate then
				-- Data we cannot read (corrupt, or written by a NEWER release). Never overwrite it.
				warn(`[ProfileManager] migrate failed for {key}: {data}`)
				ProfileManager.releaseUnsaved(key, token)
				return "failed", nil
			end
			local profile: Profile = {
				UserId = userId,
				Key = key,
				Token = token,
				Data = data,
				SaveVersion = tonumber(record.SaveVersion) or 0,
				IsNew = isNew,
				State = "active",
				Saving = false,
			}
			return "ready", profile
		elseif outcome == "malformed" then
			return "failed", nil
		elseif outcome == "locked" and attempt == 1 and lockedUntil then
			warn(`[ProfileManager] {key} held by another server, lease ends in {lockedUntil - os.time()} s`)
		end
		if attempt < CLAIM_ATTEMPTS then
			task.wait(math.min(8, attempt * 1.5) + math.random()) -- backoff with jitter
		end
	end
	return if lastOutcome == "locked" then "locked" else "failed", nil
end

-- Writes Data (and optionally clears the lease). Fenced by the token.
-- Returns "saved" | "lost" | "error". Callers retry "error" (see the saving note).
function ProfileManager.save(profile: Profile, release: boolean): string
	if profile.State ~= "active" then
		return "lost"
	end
	while profile.Saving do -- one write per profile at a time, in order
		task.wait(0.1)
	end
	if profile.State ~= "active" then
		return "lost"
	end
	profile.Saving = true
	local snapshot = deepCopy(profile.Data) -- the transform must not see later gameplay mutations
	local result = "error"
	local writtenVersion = profile.SaveVersion
	local ok, err = pcall(function()
		store:UpdateAsync(profile.Key, function(old: any, keyInfo: DataStoreKeyInfo?)
			result = "error"
			if type(old) ~= "table" or type(old.Session) ~= "table" or old.Session.Token ~= profile.Token then
				result = "lost" -- someone else owns this key now: never write
				return nil
			end
			-- The token is ours, so any version bump since our claim was our own unacknowledged write.
			writtenVersion = math.max(tonumber(old.SaveVersion) or 0, profile.SaveVersion) + 1
			old.Data = snapshot
			old.SaveVersion = writtenVersion
			old.SavedAt = os.time()
			old.Session = if release then nil else newSession(profile.Token)
			result = "saved"
			local userIds = if keyInfo then keyInfo:GetUserIds() else { profile.UserId }
			local metadata = if keyInfo then keyInfo:GetMetadata() else nil
			return old, userIds, metadata
		end)
	end)
	profile.Saving = false
	if not ok then
		warn(`[ProfileManager] save error for {profile.Key}: {err}`)
		return "error"
	end
	if result == "lost" then
		profile.State = "lost"
		return "lost"
	end
	if result == "saved" then
		profile.SaveVersion = writtenVersion
		if release then
			profile.State = "released"
		end
	end
	return result
end

-- Drops our lease without writing data (load refused after the claim).
function ProfileManager.releaseUnsaved(key: string, token: string)
	pcall(function()
		store:UpdateAsync(key, function(old: any, keyInfo: DataStoreKeyInfo?)
			if type(old) ~= "table" or type(old.Session) ~= "table" or old.Session.Token ~= token then
				return nil
			end
			old.Session = nil -- Data (if any) is left exactly as it was
			return old, if keyInfo then keyInfo:GetUserIds() else nil, if keyInfo then keyInfo:GetMetadata() else nil
		end)
	end)
end

return ProfileManager
```

Design notes on the module:

- **New players**: the claim writes `{ SaveVersion = 0, Session = ... }` with no `Data`. That record is the lock; the first save fills `Data`. A crash in between leaves a record with no data, which loads as a new player next time: correct.
- **Deep copy before save**: gameplay keeps mutating `profile.Data` while the save yields. Without the copy, a retried transform could serialize a half-applied change (for example, an item removed but the coins not yet added). Copying at the start makes each save a consistent snapshot as of that instant. Make every gameplay mutation synchronous (no yields between related changes), so any snapshot is consistent.
- **One save at a time**: `Saving` serializes writes per profile. Roblox's sample goes further and queues every request per key in order ("an older request that retries after a newer one succeeds can overwrite newer data"). With token fencing plus serialization this module cannot reorder its own writes.
- **"lost" is terminal**: once the token is gone, the session must stop saving and tell the player. Do not try to re-claim silently; the other owner's data is newer.
- **Expired but still ours**: the save accepts the write when the token matches even if `ExpiresAt` has passed. If the lease lapsed during a backend outage and nobody claimed it, the token is still ours and writing is safe. If someone did claim it, the token differs and we refuse. (The reference project also refused its own expired lease. That is safe but throws away a session for no reason after a long outage.)

## The 90 second Studio trap (production lesson)

Measured in one production game: after adding the 90 s lease, developers testing in Studio started getting "Your saved progress couldn't load" on the **second** Play in a row.

What happened:

1. Play session 1 claims `User_123` with token T1, expires at now + 90.
2. The developer presses Stop. Studio shuts the test server down. The project, like most, skips or shortens the `BindToClose` wait in Studio so stopping is not painful, so the releasing save never lands.
3. Within 90 s the developer presses Play again. Session 2 sees T1, unexpired, not its own token, and retries for 7.5 s, then gives up: load failed.

Fixes, from least to most effort:

| Fix | Trade-off |
|---|---|
| Wait 90 s between Play sessions | Annoying, people forget |
| A **Studio-only test-profile key** (`ServerStorage` attribute `TestProfileKey` gives key `TEST_<name>_<uid>`; new name = fresh profile) | Also isolates tests from the real save. The project used this throughout. Remember to clear it: one developer left a test key set and later "lost" their real progress, which was simply on the other key |
| Mark leases written from Studio (`Studio = true`) and let another Studio session take them over (the module above does this) | Live servers never honour or create Studio takeovers. Two developers testing the same account at once in Team Create can clobber each other; acceptable for tests |
| Let the `BindToClose` release run in Studio | Stopping waits for a save each time |

The project's related rules, worth copying: the test key is read **only** when `RunService:IsStudio()`, so it cannot leak into a live server; never set the test key before Play has actually started; the key also skips developer grants and disables the leaderboard writes, so test sessions do not pollute boards; and a second attribute, `SimulateLoadFailure`, forces the "load failed, nothing will be saved" path so it can be tested on purpose.

## Handling a load that did not succeed

| Status | Meaning | What to do |
|---|---|---|
| `ready` | Claimed and loaded | Play |
| `locked` | Another server still owns the lease after all retries | Tell the player their data is still saving elsewhere; kick with a "rejoin in a minute" message, or keep them in a no-save lobby and retry |
| `failed` | Backend errors, malformed or future-schema data | Never give them a default profile that saves. Either kick, or let them play in a clearly marked no-save mode |
| `left` | Player left during load | Release if you claimed (the module only claims on success) |

Roblox's sample recommends letting the player play with default data, marked as errored so it is never written, and showing a clear message, rather than kicking. The roblox-datastores playbook and many studios prefer a kick. Both are defensible; what is never acceptable is a default profile that can save over real data. Also block purchases while a profile is not `ready` (Roblox's sample checks `hasErrored` before prompting), or a purchase lands in a session that can never be saved ([[Purchase Data and Receipts]]).

## Exposing the profile to the rest of the game (the bridge)

Only one module should own `DataStoreService` calls for player data. Every other system goes through it. The reference project called this the **ProfileBridge**: a single entry point that other server scripts use to "touch this profile safely", with actions such as `ready` (can this profile be changed and saved right now?), `waitReady` (yield until loaded or failed, 90 s cap), `receiptSaved` (is this purchase id in the saved profile?), and combined "charge and record" operations so currency and the thing it bought are always written by the same save.

In a ModuleScript-based codebase the bridge is just the module's public API:

```lua
--!strict
-- ServerScriptService/Data/Profiles (ModuleScript): the only API gameplay code uses
local Players = game:GetService("Players")
local ProfileManager = require(script.Parent.ProfileManager)

type Profile = ProfileManager.Profile

local profiles: { [Player]: Profile } = {}
local loadState: { [Player]: string } = {}
local readyEvent = Instance.new("BindableEvent")

local Profiles = {}

function Profiles.canMutate(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and p.State == "active"
end

-- Synchronous mutation. The callback must not yield, so related changes are atomic
-- with respect to any snapshot taken by a save.
function Profiles.mutate(player: Player, fn: (data: { [string]: any }) -> ()): boolean
	local p = profiles[player]
	if not p or p.State ~= "active" then
		return false
	end
	fn(p.Data)
	return true
end

function Profiles.waitReady(player: Player, timeout: number?): string?
	local deadline = os.clock() + (timeout or 90)
	while player.Parent and os.clock() < deadline do
		local s = loadState[player]
		if s == "ready" or s == "failed" or s == "locked" then
			return s
		end
		readyEvent.Event:Wait()
	end
	return nil
end

-- used by the loader script
function Profiles._set(player: Player, status: string, profile: Profile?)
	loadState[player] = status
	profiles[player] = profile
	readyEvent:Fire(player)
end

function Profiles._get(player: Player): Profile?
	return profiles[player]
end

function Profiles._clear(player: Player)
	profiles[player] = nil
	loadState[player] = nil
	readyEvent:Fire(player)
end

return Profiles
```

`readyEvent:Wait()` wakes on any player's state change, which is fine at Roblox server sizes. If the owner is a classic `Script` (as in the reference project), a `BindableFunction` in `ServerScriptService` plays the same role; just keep the rule that callbacks never yield between a check and the change it guards. Gameplay rules for the bridge:

- Check `canMutate` before granting anything valuable. A profile in `lost` state still exists in memory; granting into it gives the player something that will never save.
- Never hand out the `Data` table for long-lived storage elsewhere; other systems keep ids, not references.
- Replicate to the client from the owner (attributes or a single remote), never let clients write ([[Server Authority and Validation]]).

## Libraries

| Library | Status (October 2026) | Locking model | Notes |
|---|---|---|---|
| **ProfileStore** (by loleris) | Maintained successor to ProfileService | Session lock in the record, auto-save, session end signals | API: `ProfileStore.New(name, template)`, `store:StartSessionAsync(key, { Cancel = fn, Steal = bool })`, `profile.Data`, `profile:Reconcile()`, `profile:AddUserId()`, `profile:EndSession()`, `profile:IsActive()`, `profile.OnSessionEnd`, `store:GetAsync` / `VersionQuery` / `MessageAsync`, and `.Mock` for tests. Timing constants (`AUTO_SAVE_PERIOD`, `ASSUME_DEAD`, `SESSION_STEAL`, ...) are settable with `SetConstant`; check the source for defaults |
| **ProfileService** (same author) | Older; superseded by ProfileStore | Session lock | Many existing games still run it; migration path documented by the author |
| **Roblox sample** (`SessionLockedDataStoreWrapper`) | Reference code, Roblox says do not ship as-is without extensive testing | Lock id in metadata, per-key ordered queue, 180 s autosave | Good to read for the ordering argument |
| **DataStore2** | Legacy | One store per player (ordered backups) | Roblox says do not use for new games; offers a migration tool |
| Hand-rolled (the module above) | Yours | Lease + token | Choose this when you need control over purchases, gifting, cross-key operations, or you want to understand every failure |

Roblox's advice before adopting any module: check ownership and maintenance, and make sure you can read and migrate your data **without** the module. A library that stores data in a private format is a lock-in risk.

## Failure modes and diagnosis

| Symptom | Likely cause | Check |
|---|---|---|
| Items duplicated after teleports | No lease, or saves not fenced | Search for `SetAsync` / unfenced `UpdateAsync` on player keys |
| "Progress saved on another server" messages in normal play | Two servers both loaded the key (version-only guard) | Add a lease |
| Players cannot rejoin for ~1 to 5 minutes after a server crash | Lease length | Expected; shorten the lease or show a countdown |
| Second Studio Play fails to load | Lease from the previous test still live | Studio takeover rule, test key, or wait |
| Real progress "gone" after testing | `TestProfileKey` still set | Clear it; data is on `User_<id>` untouched |
| Session flips to `lost` during an outage | Another server claimed after expiry | Expected and safe; longer lease if frequent |

## Checklist

- [ ] Lease written and checked inside the same `UpdateAsync` as the data.
- [ ] Every save is fenced by a per-session token; "lost" stops all writes.
- [ ] Autosave interval is shorter than the lease and renews it.
- [ ] The final save releases the lease; failure to release only delays the next join.
- [ ] Load returns distinct `ready` / `locked` / `failed`; none of them saves defaults over real data.
- [ ] Purchases and grants check `canMutate` first.
- [ ] Studio has a test-key path and a plan for leftover leases.

## See also
[[DataStore Fundamentals]] · [[Saving Correctly - Autosave and BindToClose]] · [[Data Schema Design and Migrations]] · [[Data Loss Prevention and Recovery]] · [[Purchase Data and Receipts]] · [[Teleporting and Multi-Place Games]] · [[Server Lifecycle and Shutdown]] · [[Exploits and Anti-Cheat]] · [[Testing Strategies and Frameworks]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox DataStore Safety]] · [[Debugging DataStore Problems]] · [[Saved Inventory End to End]] · [[Session Lock]] · [[Cookbook - Data and Saving]] · [[Links - Session locking and data safety]]
<!-- auto-links:end -->
