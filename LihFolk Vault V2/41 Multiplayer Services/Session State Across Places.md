---
tags: [multiplayer, teleport, session, memorystore, datastore, session-locking, multi-place, luau, strict, type/guide, area/networking, level/intermediate]
---
# Session State Across Places

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Carrying rewards or currency in teleport data -> Write them to the profile before leaving
> - Avoid: Teleporting before the save committed -> `saveAndRelease` must succeed first
> - Avoid: No reclaim path -> A failed teleport leaves the player with no profile loaded
> - Every piece of carried state assigned to durable, transit or hint, in writing.
> - Teleport data carries only a nonce and harmless hints.
> - Source writes the envelope, saves and releases, then teleports.
>
> Cost: TL;DR ~160 tok · whole note ~6.6k tok. Read more: ## 4. Source side · ## 5. Destination bootstrap · ## Common mistakes · ## Checklist
<!-- tldr:end -->

When a player teleports, their server-side world ends. Their character, their in-memory tables, the round they were in and the buff they just drank exist only on the server they left. The destination starts from nothing and has to rebuild "who is this player and what were they doing" from three sources of very different trust: the durable profile, a short-lived transit record, and the teleport data the client carried. Most multi-place bugs are a piece of state in the wrong one of those three, or a hop that half failed. This note gives a complete, server-authoritative handoff protocol in strict Luau: what goes where, how the source hands over, how the destination claims, and what happens on every failure path.

Prerequisites: [[Teleporting and Multi-Place Games]] (trust levels of teleport data, `GetJoinData`, the save race), [[Session Locking and Profile Libraries]] (one owner per profile), [[MemoryStore Service]]. Related in this section: [[Parties and Group Teleports]], [[Matchmaking Queues with MemoryStore]], [[Server Shutdowns Soft Updates and Migration]] (versioned payloads).

## 1. Three tiers of state

| Tier | Store | Lives | Trust | Holds |
|---|---|---|---|---|
| Durable | Data store profile, session-locked | Forever | Full | Currency, inventory, levels, quest progress, purchases, rewards from a run |
| Transit | MemoryStore hash map, one key per user, short TTL | Seconds to minutes | Full (never touched the client) | What the player is doing right now: the run they are entering, carried health, chosen loadout for this activity, party id, return point, session id |
| Hint | Teleport data | One hop | Partial at best | A pointer to the transit record (a nonce), loading-screen theme, spawn preference |

The Roblox docs are blunt about the third tier: teleport data is transmitted by the client, `GetLocalPlayerTeleportData` on the client can be spoofed, and `GetJoinData().TeleportData` on the server is sent by a Roblox server within the past 48 hours with the right player but "can still potentially be abused" (as of October 2026). The teleport guide says not to pass secure data this way because it is "visible to the client and unencrypted". So the hint tier carries **one opaque nonce** and nothing of value.

### Deciding the tier for a piece of state

Ask three questions:

1. **Would losing it cost the player something they earned or bought?** Durable. A dungeon's loot is written to the profile on the dungeon server before anyone leaves, never carried back.
2. **Does it only make sense for the next few minutes?** Transit. "Entering run 7f3a with hard difficulty and these four abilities" is meaningless an hour later.
3. **Would a forged value matter?** If yes, it cannot be a hint.

Examples that people get wrong:

| State | Wrong tier | Right tier | Why |
|---|---|---|---|
| Health and mana carried into a boss arena | Hint | Transit | A forged full-health value is a cheat |
| "Which spawn to use in the hub" | Transit | Hint | Harmless if forged; not worth a store write |
| Temporary 30 minute XP boost | Transit | Durable (with `expiresAt`) | It was bought; it must survive crashes and rejoins |
| Match result for the lobby's victory screen | Durable | Transit | The rewards are durable already; the screen is cosmetic and short-lived |
| Party membership | Hint | Platform (`PartyId`) or transit | The platform knows it; never trust a client list |
| Session id for analytics | Durable | Transit | Stitches one play session across places; meaningless tomorrow |

## 2. The protocol

The handoff has two halves and one rule: **exactly one server owns the player's durable profile at a time, and the transit record is consumed at most once.**

**Source server**

1. Validate the travel request on the server (the client asked through a remote; check eligibility, cooldowns, party rules).
2. Write a transit **envelope** to `Handoff[userId]` with a fresh nonce, the destination place, the purpose, a small payload, `issuedAt`, and a version. TTL 120 s.
3. **Save and release** the profile. If that fails, abort: cancel the envelope and keep the player here.
4. Teleport with teleport data `{ h = nonce }`.
5. If the teleport throws, or `TeleportInitFailed` fires and retries run out, **reclaim**: cancel the envelope, re-acquire the profile, tell the player. If the profile cannot be re-acquired, kick with a clear message rather than letting them play unsaved.

**Destination server**

1. Check `GetJoinData().SourcePlaceId` against the places allowed to send players here.
2. Acquire the profile (the session lock may take a few seconds while the source finishes releasing).
3. **Consume** the envelope with `MemoryStoreHashMap:UpdateAsync`: succeed only if the stored nonce matches the hint, it was not consumed or cancelled, it targets this place, and it is not too old; then mark it consumed by this `JobId`.
4. Validate the payload for its purpose and apply it.
5. If there is no valid envelope, apply the documented default for this place: a hub spawns at the default point, a dungeon sends the player back to the lobby.

Why the consume step is atomic: `UpdateAsync` runs the transform as a single read-modify-write and returning `nil` cancels the write (Roblox docs). Two servers cannot both consume the same envelope, so a duplicate arrival (a retried teleport that landed twice, a player who reused a cached join) gets the default, not a second copy of carried state.

Why the source writes the envelope **before** releasing the profile: if the write fails and the purpose requires transit state (a dungeon run), you can still abort cleanly while the player is safe in the source with their profile held. Doing it the other way round means a failed write after release forces a reclaim.

## 3. Shared types and the profile gateway

The handoff should not care which profile library you use. It needs three operations, so it takes them as a small interface. Wire it to [[ProfileStore]] or your own session-locked loader ([[Session Locking and Profile Libraries]]).

```lua
--!strict
-- ServerScriptService/Session/SessionTypes.luau
export type Purpose = "EnterDungeon" | "ReturnToLobby" | "JoinEvent"

export type Envelope = {
	v: number,                  -- payload contract version
	nonce: string,
	userId: number,
	sessionId: string,          -- stitches one play session across places
	fromPlace: number,
	toPlace: number,
	purpose: Purpose,
	payload: { [string]: any },
	issuedAt: number,
	consumedBy: string?,
	cancelled: boolean?,
}

export type ProfileGateway = {
	-- Acquire the session lock and load. Yields. Returns false if the profile could not be
	-- acquired (locked elsewhere past the timeout, data store down).
	load: (player: Player) -> boolean,
	-- Save, then release the lock. Yields. Returns false if the save did not commit; in that
	-- case the lock must still be held by this server.
	saveAndRelease: (player: Player) -> boolean,
	-- Tells the gateway's own PlayerRemoving handler not to save a profile already released.
	markTravelling: (player: Player, travelling: boolean) -> (),
}

return nil
```

The `saveAndRelease` contract matters: "false means the lock is still ours". A library that releases the lock even when the final save failed would let the destination load stale data; check your library's behaviour and wrap it if needed.

## 4. Source side

```lua
--!strict
-- ServerScriptService/Session/SessionHandoff.luau (shared by every place)
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local SessionTypes = require(script.Parent.SessionTypes)
type Envelope = SessionTypes.Envelope
type Purpose = SessionTypes.Purpose
type ProfileGateway = SessionTypes.ProfileGateway

local CONTRACT = 1
local ENVELOPE_TTL = 120   -- seconds an unconsumed envelope lives
local CONSUMED_TTL = 600   -- keep consumed envelopes briefly for debugging and duplicate detection
local MAX_AGE = 90         -- destination refuses envelopes older than this
local MAX_TELEPORT_RETRIES = 2

-- Purposes that make no sense without transit state: abort travel if the envelope cannot be written.
local REQUIRES_ENVELOPE: { [Purpose]: boolean } = {
	EnterDungeon = true,
	ReturnToLobby = false,
	JoinEvent = false,
}

local handoffs = MemoryStoreService:GetHashMap("SessionHandoff")

local SessionHandoff = {}

local gateway: ProfileGateway? = nil
local sessionIds: { [number]: string } = {}
local travelling: { [number]: { nonce: string, retries: number } } = {}

------------------------------------------------------------------ helpers

local function withRetry<T>(label: string, fn: () -> T): (boolean, T?)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[Session] {label} failed (attempt {attempt}): {result}`)
		if attempt < 3 then
			task.wait(attempt + math.random())
		end
	end
	return false, nil
end

local function cancelEnvelope(userId: number, nonce: string)
	pcall(function()
		handoffs:UpdateAsync(tostring(userId), function(old: any)
			if type(old) == "table" and old.nonce == nonce and old.consumedBy == nil then
				local env = table.clone(old)
				env.cancelled = true
				return env
			end
			return nil
		end, 60)
	end)
end

local function getGateway(): ProfileGateway
	local g = gateway
	assert(g, "SessionHandoff.init must be called first")
	return g
end

------------------------------------------------------------------ reclaim (failure path)

local function reclaim(player: Player, nonce: string, reason: string)
	warn(`[Session] reclaiming {player.UserId}: {reason}`)
	cancelEnvelope(player.UserId, nonce)
	travelling[player.UserId] = nil
	local g = getGateway()
	g.markTravelling(player, false)
	if player.Parent == nil then
		return -- they left anyway; nothing to restore here
	end
	for attempt = 1, 3 do
		if g.load(player) then
			player:SetAttribute("SessionNotice", "Travel failed. You are still here and your progress is safe.")
			return
		end
		task.wait(attempt * 2)
	end
	-- Never let someone play on without a loaded, locked profile.
	player:Kick("We could not restore your session safely. Please rejoin; your progress was saved.")
end

------------------------------------------------------------------ send

export type SendResult = "Sent" | "Busy" | "StoreUnavailable" | "SaveFailed" | "TeleportFailed"

-- Server only. `options` may carry ReservedServerId or ServerInstanceId; teleport data is set here.
function SessionHandoff.send(
	player: Player,
	toPlace: number,
	purpose: Purpose,
	payload: { [string]: any },
	options: TeleportOptions?
): SendResult
	if travelling[player.UserId] then
		return "Busy"
	end
	local g = getGateway()
	local nonce = HttpService:GenerateGUID(false)
	travelling[player.UserId] = { nonce = nonce, retries = 0 }

	local envelope: Envelope = {
		v = CONTRACT,
		nonce = nonce,
		userId = player.UserId,
		sessionId = sessionIds[player.UserId] or HttpService:GenerateGUID(false),
		fromPlace = game.PlaceId,
		toPlace = toPlace,
		purpose = purpose,
		payload = payload,
		issuedAt = os.time(),
	}

	-- 1. Transit record first, while the profile is still safely ours.
	local wrote = withRetry("write envelope", function()
		handoffs:SetAsync(tostring(player.UserId), envelope, ENVELOPE_TTL)
		return true
	end)
	if not wrote and REQUIRES_ENVELOPE[purpose] then
		travelling[player.UserId] = nil
		return "StoreUnavailable"
	end

	-- 2. Save and release. On failure the lock is still ours: abort and stay.
	g.markTravelling(player, true)
	if not g.saveAndRelease(player) then
		g.markTravelling(player, false)
		cancelEnvelope(player.UserId, nonce)
		travelling[player.UserId] = nil
		return "SaveFailed"
	end

	-- 3. Teleport with only the nonce as a hint.
	local teleportOptions = options or Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData({ h = nonce, v = CONTRACT })
	local ok, err = pcall(function()
		return TeleportService:TeleportAsync(toPlace, { player }, teleportOptions)
	end)
	if not ok then
		task.spawn(reclaim, player, nonce, `TeleportAsync threw: {err}`)
		return "TeleportFailed"
	end
	return "Sent"
end

------------------------------------------------------------------ receive

export type Validator = (payload: any) -> { [string]: any }?

local validators: { [Purpose]: Validator } = {}
local allowedSources: { [number]: boolean } = {}

function SessionHandoff.setValidator(purpose: Purpose, validator: Validator)
	validators[purpose] = validator
end

function SessionHandoff.allowSource(placeId: number)
	allowedSources[placeId] = true
end

-- Call AFTER the profile has been loaded on this server. Returns a validated envelope or nil.
function SessionHandoff.receive(player: Player): Envelope?
	local join = player:GetJoinData()
	local source = tonumber(join.SourcePlaceId) or 0
	local data = join.TeleportData
	local nonce = if type(data) == "table" then data.h else nil

	if type(nonce) ~= "string" or #nonce > 64 or not allowedSources[source] then
		sessionIds[player.UserId] = HttpService:GenerateGUID(false) -- a fresh session
		return nil
	end

	local now = os.time()
	local here = game.PlaceId
	local me = game.JobId
	local ok, result = withRetry("consume envelope", function()
		return handoffs:UpdateAsync(tostring(player.UserId), function(old: any)
			if type(old) ~= "table" then
				return nil
			end
			if old.nonce ~= nonce or old.consumedBy ~= nil or old.cancelled == true then
				return nil
			end
			if old.toPlace ~= here or now - (tonumber(old.issuedAt) or 0) > MAX_AGE then
				return nil
			end
			local env = table.clone(old)
			env.consumedBy = me
			return env
		end, CONSUMED_TTL)
	end)
	if not ok or type(result) ~= "table" then
		sessionIds[player.UserId] = HttpService:GenerateGUID(false)
		return nil
	end

	local env = result :: Envelope
	if (tonumber(env.v) or 0) > CONTRACT then
		return nil -- written by a newer build; see the update note
	end
	local validate = validators[env.purpose]
	if not validate then
		return nil
	end
	local clean = validate(env.payload)
	if not clean then
		warn(`[Session] payload for {player.UserId} failed validation ({env.purpose})`)
		return nil
	end
	env.payload = clean
	sessionIds[player.UserId] = if type(env.sessionId) == "string" then env.sessionId else HttpService:GenerateGUID(false)
	return env
end

function SessionHandoff.sessionId(player: Player): string?
	return sessionIds[player.UserId]
end

------------------------------------------------------------------ init

function SessionHandoff.init(profileGateway: ProfileGateway)
	gateway = profileGateway

	TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
		local t = travelling[player.UserId]
		if not t then
			return -- not a handoff teleport; another system handles it
		end
		local retryable = result == Enum.TeleportResult.Failure or result == Enum.TeleportResult.Flooded
		if retryable and t.retries < MAX_TELEPORT_RETRIES and player.Parent then
			t.retries += 1
			task.wait(if result == Enum.TeleportResult.Flooded then 10 else 2)
			-- Re-set the hint on the options Roblox handed back, to be safe.
			local retryOptions = options :: TeleportOptions
			retryOptions:SetTeleportData({ h = t.nonce, v = CONTRACT })
			local ok = pcall(function()
				return TeleportService:TeleportAsync(placeId, { player }, retryOptions)
			end)
			if ok then
				return
			end
		end
		reclaim(player, t.nonce, `TeleportInitFailed {result.Name}: {message}`)
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- A successful teleport ends here. The profile was already released by send().
		travelling[player.UserId] = nil
		sessionIds[player.UserId] = nil
	end)
end

return SessionHandoff
```

Things the code relies on and why:

- `travelling` makes `send` idempotent per player: a double-clicked "Enter" cannot start two handoffs.
- `markTravelling` lets the profile gateway's own `PlayerRemoving` save skip a profile it no longer owns. Without it, a successful teleport triggers a save on the source after release, which a correct session lock refuses (good) or, with a naive loader, overwrites the destination's newer data (bad).
- The destination consumes with `CONSUMED_TTL` rather than deleting. A consumed envelope that lingers for 10 minutes lets you answer "did this player's handoff arrive?" in a support case, and it blocks reuse of the same nonce.
- `withRetry` on consume treats throttling as transient. If the store stays down, `receive` returns `nil` and the place's default applies. Decide per place whether that default is acceptable (next section).

## 5. Destination bootstrap

```lua
--!strict
-- ServerScriptService/Dungeon/Bootstrap.server.luau (dungeon place)
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local SessionHandoff = require(ServerScriptService.Session.SessionHandoff)
local Profiles = require(ServerScriptService.Data.Profiles) -- your ProfileGateway implementation

local LOBBY_PLACE_ID = 0
local ALLOWED_DIFFICULTY = { Normal = true, Hard = true, Nightmare = true }
local MAX_ABILITIES = 4

SessionHandoff.allowSource(LOBBY_PLACE_ID)
SessionHandoff.setValidator("EnterDungeon", function(payload: any)
	if type(payload) ~= "table" then
		return nil
	end
	local difficulty = payload.difficulty
	if type(difficulty) ~= "string" or not ALLOWED_DIFFICULTY[difficulty] then
		return nil
	end
	local abilities = {}
	if type(payload.abilities) == "table" then
		for i, id in payload.abilities do
			if i > MAX_ABILITIES then
				break
			end
			if type(id) == "string" and #id <= 32 then
				table.insert(abilities, id)
			end
		end
	end
	local hp = tonumber(payload.healthFraction)
	return {
		difficulty = difficulty,
		abilities = abilities,
		healthFraction = if hp and hp == hp then math.clamp(hp, 0.1, 1) else 1,
		runId = if type(payload.runId) == "string" and #payload.runId <= 64 then payload.runId else nil,
	}
end)
SessionHandoff.init(Profiles)

local function sendBack(player: Player, why: string)
	player:SetAttribute("SessionNotice", why)
	local result = SessionHandoff.send(player, LOBBY_PLACE_ID, "ReturnToLobby", { reason = why })
	if result ~= "Sent" then
		player:Kick(why .. " Please rejoin from the lobby.")
	end
end

local function onPlayerAdded(player: Player)
	if not Profiles.load(player) then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end
	local env = SessionHandoff.receive(player)
	if not env or env.purpose ~= "EnterDungeon" then
		-- A dungeon without a valid entry ticket: send them home, never improvise a run.
		sendBack(player, "This dungeon session is no longer available.")
		return
	end
	-- Also check that the ticket matches this server's run (see the party and reserved-server notes):
	-- env.payload.runId must equal the run record bound to game.PrivateServerId.
	player:SetAttribute("Difficulty", env.payload.difficulty)
	player:SetAttribute("CarriedHealth", env.payload.healthFraction)
	-- Apply abilities only if the profile actually owns them; the payload is a selection, not a grant.
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end
```

The comment about abilities is the core of server authority across places. The envelope says **which** owned abilities the player selected; the destination checks ownership in the profile it just loaded. A transit record written by your own server is trustworthy as a record of what the source decided, but the destination should still re-derive anything it can derive from durable data. Belt and braces cost one table lookup.

## 6. The return trip

The dungeon's rewards are written to the profile **on the dungeon server**, during play or at the end, through the normal save path. The trip back carries only presentation:

```lua
-- At the end of a run (dungeon server):
-- 1. Grant rewards into the loaded profile (durable).
-- 2. SessionHandoff.send(player, LOBBY_PLACE_ID, "ReturnToLobby", { runId = runId, summary = { kills = 31, timeSec = 412 } })
-- The lobby validator accepts a small summary for the victory screen and nothing else.
```

If the return teleport fails and the reclaim cannot restore the profile, the player is kicked, but nothing is lost: rewards were saved before `saveAndRelease`. That is the property to test for.

## 7. Failure paths, end to end

| Where it fails | State after failure | Player sees |
|---|---|---|
| Envelope write fails, purpose needs it | Nothing changed | "Could not start, try again" |
| Envelope write fails, purpose does not need it | Travel continues; destination uses defaults | Default spawn |
| Save before release fails | Lock still held, envelope cancelled | "Could not save, try again" |
| `TeleportAsync` throws | Reclaim: envelope cancelled, profile reloaded | "Travel failed, you are still here" |
| Teleport fails late, retries exhausted | Reclaim as above | Same |
| Reclaim cannot reload the profile | Kick | "Please rejoin; your progress was saved" |
| Destination cannot acquire the lock (source slow to release) | Gateway waits and retries within its timeout; then kick | Longer loading, rarely a kick |
| Envelope expired before arrival (slow device, 90 s) | Defaults | Dungeon: sent back; hub: default spawn |
| Duplicate arrival with same nonce | Consume fails (already consumed) | Defaults |
| Envelope from a newer build | Refused | Sent to a server on the new version |
| MemoryStore down at the destination | Consume fails after retries | Defaults or sent back |
| Player reaches the place directly (no teleport) | No hint, no envelope | Defaults; dungeon sends them to the lobby |

Two numbers to tune: `ENVELOPE_TTL` must exceed the slowest realistic teleport plus profile acquisition (rule of thumb: 60 to 120 s; slow mobile devices on large places can take a minute), and `MAX_AGE` should be a little under the TTL so the destination rejects envelopes near expiry deterministically.

## 8. Budget

Per hop: one `SetAsync` (1 unit) on the source, one `UpdateAsync` (at least 2 units for hash maps, Roblox docs) on the destination, plus occasional cancels. A game where 2,000 players hop once every 5 minutes uses about 1,200 units per minute against a quota of 241,000 (`1,000 + 120 x CCU`, Roblox docs). Memory: an envelope of 300 to 500 bytes times players in transit at once is tiny. The handoff is cheap; the expensive part of a hop is the profile save and load, which is why hops should be purposeful, not decorative.

## 9. Testing

- Teleports do not work in Studio playtests (Roblox docs). Unit-test `receive` by injecting join data and a fake hash map, and test validators with hostile payloads (wrong types, NaN, huge arrays, unknown purposes) ([[Testing Strategies and Frameworks]]).
- In a published test universe: force each failure row in section 7 with a debug flag on a test server (make `saveAndRelease` return false, make the envelope write throw, teleport to a bogus place id) and confirm the player always ends up either at the destination with a loaded profile or at the source with a loaded profile, never in between.
- Log every handoff with the session id, purpose, result and time to consume. A rising "consume failed" rate is the first sign of throttling or a version mismatch ([[Crash and Error Telemetry]]).

## When not to do this

A single-place game needs none of it. A multi-place game where places share nothing but the profile (a lobby and an independent minigame with no carried state) only needs session locking and a default spawn. The transit tier earns its place when the destination's behaviour depends on a decision made at the source.

## Common mistakes

| Mistake | Fix |
|---|---|
| Carrying rewards or currency in teleport data | Write them to the profile before leaving |
| Teleporting before the save committed | `saveAndRelease` must succeed first |
| No reclaim path | A failed teleport leaves the player with no profile loaded |
| Deleting the envelope on read instead of consuming atomically | Two arrivals both apply it |
| Destination trusting a payload's grants | Treat payload as a selection, verify against the profile |
| Saving on `PlayerRemoving` after release | `markTravelling` so the gateway skips it |
| Unversioned payloads | `v` field, refuse newer |
| Same default for every place | Hubs can improvise, instances should send players home |

## Checklist

- [ ] Every piece of carried state assigned to durable, transit or hint, in writing.
- [ ] Teleport data carries only a nonce and harmless hints.
- [ ] Source writes the envelope, saves and releases, then teleports.
- [ ] Reclaim path re-acquires the profile or kicks; never plays unsaved.
- [ ] Destination checks source place, consumes atomically, validates per purpose.
- [ ] Rewards written durably before any hop.
- [ ] Payloads versioned; newer refused.
- [ ] Every failure row forced once in a published test universe.

## See also
[[Multiplayer Services Start Here]] · [[Teleporting and Multi-Place Games]] · [[Session Locking and Profile Libraries]] · [[MemoryStore Service]] · [[Saving Correctly - Autosave and BindToClose]] · [[Parties and Group Teleports]] · [[Matchmaking Queues with MemoryStore]] · [[Server Shutdowns Soft Updates and Migration]] · [[Server Authority and Validation]] · [[Data Loss Prevention and Recovery]]

## Connected notes
<!-- auto-links:start -->
[[Session Lock]] · [[Reserved and Private Servers in Practice]] · Debugging DataStore Problems · Trading Systems Without Duplication · Cookbook - Data and Saving · Official Docs - Networking and Multiplayer
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Server Hop Rejoin and Server Lists with Ping]] · [[Server Browsers and Server Lists]] · [[Cookbook - Data and Saving]] · [[AI Pitfalls - Data and Monetization]] · [[LihFolk Systems - Data and Purchase Guarantees]] · [[Debugging DataStore Problems]]
<!-- related:end -->
