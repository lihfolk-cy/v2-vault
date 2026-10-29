---
tags: [architecture, networking, teleport, multi-place, security, matchmaking, type/guide, area/networking, level/intermediate, api/TeleportService, area/security, api/HttpService]
---
# Teleporting and Multi-Place Games

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Client-side `Teleport()` -> Remote, validate, `TeleportAsync` on the server
> - Avoid: Currency or rewards in teleport data -> Stores; teleport data for hints only
> - Avoid: Access Control left Fully open with gated places -> Secure within universe only
> - All teleports are server-initiated through one `safeTeleport` helper.
> - Teleport data contains no value; tickets live in MemoryStore or DataStore.
> - Destination servers validate `SourcePlaceId`, membership, and default-deny.
>
> Cost: TL;DR ~160 tok · whole note ~5.0k tok. Read more: ## Teleport data: what you may trust · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An experience (universe) can contain many **places**: a lobby, dungeons, arenas, a trading hub, event maps. `TeleportService` moves players between places, between servers of the same place, and into **reserved servers** that only your code can send people to. Multi-place design keeps each server's memory small, lets you build instanced content (a private dungeon run, a ranked match), and separates risky features. It also introduces failure modes that do not exist in a single place: teleports that fail halfway, data that must survive the hop, a client that tells the destination lies, and sub-places that players can enter directly if you configure access wrongly. This note covers all of it with the documented rules.

Related: [[Places Universes and Experience Settings]], [[Session Locking and Profile Libraries]], [[MemoryStore Service]], [[Cross-Server Messaging]].

## The API today

`TeleportService:TeleportAsync(placeId, players, teleportOptions?)` is the single modern teleport method (Roblox docs):

- **Server only.** Calling it from the client errors. To start a teleport from a client action, fire a RemoteEvent and teleport from the server after validation.
- **Up to 50 players** per call; groups can only be teleported within one experience.
- Without `TeleportOptions`, players go to a public server of the place, matchmade using the first player in the list.
- With `TeleportOptions` it returns a `TeleportAsyncResult` describing the destination.
- Older methods (`Teleport`, `TeleportPartyAsync`, `TeleportToPrivateServer`...) are deprecated or not recommended for new work; the client-side `Teleport()` in particular should not be used even if access is "Fully open".
- **TeleportService does not work in Studio playtests**; publish and test in the Roblox client.

### TeleportOptions

| Option | Effect |
|---|---|
| `ServerInstanceId` | Send to a specific public server (a `JobId`) |
| `ReservedServerAccessCode` | Send to a specific reserved server |
| `ShouldReserveServer = true` | Create a new reserved server and send the group there |
| `SetTeleportData(data)` | Attach non-secure data for the destination |

Conflicting combinations error with "Incompatible Parameters": `ReservedServerAccessCode` with `ServerInstanceId`, `ShouldReserveServer` with `ServerInstanceId`, and `ShouldReserveServer` with `ReservedServerAccessCode` (Roblox docs).

## Reserved servers

A reserved server is a server of a place that matchmaking never fills; only teleports carrying its access code can enter.

- `TeleportService:ReserveServerAsync(placeId)` returns an access code and the server's `PrivateServerId`; server-only. The older `ReserveServer` is deprecated (Roblox API reference, as of October 2026).
- The server **starts when the code is first used**. Access codes **stay valid indefinitely**: if no server is running for the code, a new one starts.
- `game.PrivateServerId` is the same across all server instances started for that code; `JobId` differs.
- Detect a reserved server with `game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0` (a VIP/private server has a non-zero owner).
- Players on Xbox and PlayStation with cross-play disabled arrive in a different server from cross-play players, so several servers can share one `PrivateServerId`; `DataModel.MatchmakingType` tells them apart (Roblox docs).

Uses: dungeon runs, matches, parties, tutorials, a soft-shutdown holding server (see [[Server Lifecycle and Shutdown]]).

Because codes never expire, **do not hand access codes to clients** and do not store them where players can reuse them to rejoin a finished match. Treat the code as a capability. Arrival validation (below) is still needed: a reserved server knows who it expected only if you tell it through a store.

## Teleport data: what you may trust

There are three ways data reaches the destination, with very different trust:

| Channel | Readable where | Trust |
|---|---|---|
| `TeleportService:GetLocalPlayerTeleportData()` | Client only | **None.** The docs: "Exploiters can spoof teleport data" |
| `Player:GetJoinData().TeleportData` | Server only | **Partial.** Guaranteed sent by a Roblox server in the past 48 hours, sent with this player, and `SourcePlaceId` / `SourceGameId` are the true origin. But "as this data is transmitted by the client, it can still potentially be abused by an exploiter" |
| DataStore / MemoryStore record written by the source server | Server | **Full** (it never passed through the client) |

`GetJoinData` also contains `Members` (UserIds teleported in the same group), `SourcePlaceId`, `SourceGameId`, `ReferredByPlayerId`, `LaunchData` and `GameJoinContext` (Roblox docs).

So:

- Use teleport data for **hints and cosmetics**: which spawn to use, the party's chosen difficulty for display, a loading screen theme.
- Use **stores** for anything with value: currency, inventory, match entitlement, rewards earned in a dungeon, "this player paid for the run".
- Check `SourcePlaceId` when data should only come from your own places.

The secure handoff:

```lua
--!strict
-- Source server: create a ticket in MemoryStore, then teleport with only the ticket id.
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")

local tickets = MemoryStoreService:GetHashMap("RunTickets")
local DUNGEON_PLACE_ID = 0 -- your place id
local TICKET_TTL = 300     -- seconds

local function startRun(party: { Player }, difficulty: string)
	local ticketId = HttpService:GenerateGUID(false)
	local members = {}
	for _, p in party do table.insert(members, p.UserId) end

	local ok, err = pcall(function()
		tickets:SetAsync(ticketId, { members = members, difficulty = difficulty }, TICKET_TTL)
	end)
	if not ok then
		warn("Ticket write failed: " .. tostring(err))
		return false
	end

	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData({ ticket = ticketId }) -- the id is not a secret; the record is server-side

	local success, result = pcall(function()
		return TeleportService:TeleportAsync(DUNGEON_PLACE_ID, party, options)
	end)
	if not success then
		warn("Teleport failed: " .. tostring(result))
	end
	return success
end

return startRun
```

```lua
--!strict
-- Destination (reserved) server: validate every arrival against the server-side ticket.
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")

local tickets = MemoryStoreService:GetHashMap("RunTickets")
local LOBBY_PLACE_ID = 0 -- your lobby

local run: { members: { number }, difficulty: string }? = nil

local function admit(player: Player)
	local join = player:GetJoinData()
	if join.SourcePlaceId ~= LOBBY_PLACE_ID then
		player:Kick("Please join from the lobby.")
		return
	end
	local data = join.TeleportData
	local ticketId = type(data) == "table" and data.ticket
	if type(ticketId) ~= "string" then
		player:Kick("Missing run ticket.")
		return
	end
	if not run then
		local ok, record = pcall(function()
			return tickets:GetAsync(ticketId)
		end)
		if not ok or type(record) ~= "table" then
			player:Kick("Run not found.")
			return
		end
		run = record
	end
	if not table.find((run :: any).members, player.UserId) then
		player:Kick("You are not part of this run.") -- default deny
		return
	end
	-- Admitted: load profile (session-locked) and start.
end

Players.PlayerAdded:Connect(admit)
for _, p in Players:GetPlayers() do task.spawn(admit, p) end
```

Default deny matters: if verification throws or is inconclusive, the player is not admitted (Roblox docs, access control guidance).

## Handling failures

Teleports fail: the destination is full, the network hiccups, reserved server creation fails, the player's client crashes. Two layers (Roblox docs):

1. `TeleportAsync` can **throw**. Wrap in `pcall` and retry a few times with a delay.
2. Even after a successful call, the teleport can **fail at the last moment** and leave the player on the source server. `TeleportService.TeleportInitFailed(player, teleportResult, errorMessage, placeId, teleportOptions)` fires (on both server and client). The options passed are a **new** object populated to retry to the exact same destination, including the generated access code if the original used `ShouldReserveServer`. For a group teleport it fires once per player.

```lua
--!strict
-- ServerScriptService/Shared/SafeTeleport.luau (adapted from the Roblox docs pattern)
local TeleportService = game:GetService("TeleportService")

local ATTEMPTS = 5
local RETRY_DELAY = 1
local FLOOD_DELAY = 15

local function safeTeleport(placeId: number, players: { Player }, options: TeleportOptions?): (boolean, any)
	local ok, result
	for attempt = 1, ATTEMPTS do
		ok, result = pcall(function()
			return TeleportService:TeleportAsync(placeId, players, options)
		end)
		if ok then break end
		task.wait(RETRY_DELAY * attempt)
	end
	if not ok then warn("Teleport failed after retries: " .. tostring(result)) end
	return ok, result
end

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId, options)
	if teleportResult == Enum.TeleportResult.Flooded then
		task.wait(FLOOD_DELAY)
	elseif teleportResult == Enum.TeleportResult.Failure then
		task.wait(RETRY_DELAY)
	else
		warn(("Invalid teleport [%s]: %s"):format(teleportResult.Name, errorMessage))
		return -- do not retry invalid teleports; tell the player instead
	end
	if player.Parent then
		safeTeleport(placeId, { player }, options)
	end
end)

return safeTeleport
```

Add a cap on retries per player (the docs' sample retries forever on Flooded/Failure), and show the player a message after giving up.

## Data persistence across the hop

The classic multi-place bug is a **race between saving on the source and loading on the destination**. The player leaves the source server (its `PlayerRemoving` starts a save), and arrives at the destination, which loads the profile possibly before the save lands. Without session locking, the destination loads stale data, and whichever server saves last wins: lost progress or duplicated items.

Solutions:

- **Session locking** (profile libraries such as [[ProfileStore]]): the destination waits until the source releases the lock. See [[Session Locking and Profile Libraries]].
- **Save before teleporting**: flush the profile and release the lock, then call `TeleportAsync`. Still keep locking; teleports can fail and leave the player on the source.
- **Never carry value in teleport data.** Rewards earned in a dungeon are written to the profile on the dungeon server.

One production game's `GetAsync` cached reads for about 4 seconds; verifying writes required `DataStoreGetOptions.UseCache = false`. A destination that reads with the cache immediately after a hop can see old data even when the save landed, another reason to rely on a lock protocol rather than timing.

## Access control: who can enter a sub-place

Three settings (Roblox docs, "Teleport between places"):

| Setting | Where | Controls |
|---|---|---|
| Access Control for Places | Creator Dashboard, Audience, Access Settings | Whether players can join non-start places directly |
| Direct Access Control | Creator Dashboard, per place | Overrides the above for one place |
| Allow Third Party Teleports | Studio, Experience Settings, Security | Teleports to experiences you do not own |

Access Control for Places options: **Fully open** (join any place from anywhere, including deep links and following friends), **Limited to same universe** (non-start places only via teleports within your experience, client or server), **Secure within universe only** (non-start places only via **server-initiated** teleports).

Why it matters: the security docs warn that once inside a universe a client can teleport to any place in it, that disabling Direct Access only removes the website Join button, and that content replicates as soon as the player joins, before any kick runs. A progression-gated dungeon, an admin place, or a test place in the same universe is reachable unless access is **Secure**. Keep development and test places in a **separate private universe**.

## Matchmaking sketch

1. Lobby servers push players into a MemoryStore queue (`MemoryStoreQueue:AddAsync`) with their rating and party.
2. A single coordinating server (or every lobby, with careful atomic reads) pops enough players, reserves a server, writes a match ticket and teleports the group (or each lobby teleports its own members using the shared access code from the ticket).
3. The match server validates arrivals against the ticket and starts when everyone arrived or after a timeout.
4. Results are written to profiles on the match server; players teleport back to the lobby.

Budget MemoryStore requests (1,000 + 120 x concurrent users per minute, experience-wide) and use short expiries. See [[MemoryStore Service]].

## Teleport UX

- `TeleportService:SetTeleportGui(screenGui)` on the client shows a custom loading screen during the teleport; scripts inside it do not run (Roblox docs). The destination can read it with `GetArrivingTeleportGui` and fade it out.
- Show progress and failure messages; teleports take seconds.
- On arrival, stream in around the spawn before showing gameplay ([[Instance Streaming]]).

## Common mistakes

| Mistake | Fix |
|---|---|
| Client-side `Teleport()` | Remote, validate, `TeleportAsync` on the server |
| Currency or rewards in teleport data | Stores; teleport data for hints only |
| Access Control left Fully open with gated places | Secure within universe only |
| Test places in the live universe | Separate private universe |
| No `TeleportInitFailed` handling | Retry with the provided options; message the player |
| Loading profile on arrival without a lock | Session locking; save and release before teleport |
| Testing teleports in Studio | Publish and test live (unsupported in Studio) |
| Handing access codes to clients | Keep codes server-side |

## Checklist

- [ ] All teleports are server-initiated through one `safeTeleport` helper.
- [ ] Teleport data contains no value; tickets live in MemoryStore or DataStore.
- [ ] Destination servers validate `SourcePlaceId`, membership, and default-deny.
- [ ] `TeleportInitFailed` retries with a cap.
- [ ] Profiles are session-locked across places.
- [ ] Access Control for Places reviewed; test places in another universe.

## See also
[[Places Universes and Experience Settings]] · [[Session Locking and Profile Libraries]] · [[MemoryStore Service]] · [[Cross-Server Messaging]] · [[Server Lifecycle and Shutdown]] · [[Instance Streaming]] · [[Exploits and Anti-Cheat]] · [[Spawning Teams and Rounds]]

## Nuances and edge cases

1. **The save-then-load race is the central problem.** When a player teleports, the source server saves their data while the destination server loads it. Without session locking, the destination can load stale data from before the save finished, and the player loses progress or duplicates items. Save and release the session before (or as part of) the teleport, and make the destination wait for or steal the lock correctly ([[Session Locking and Profile Libraries]]).
2. **Teleports fail more than people expect.** Destination full, server shutting down, transient errors and client-side issues all happen. At scale, a small failure rate is many players a day. Every teleport needs a retry path and a visible message, and the player must end up in a playable state (back in the lobby) if all retries fail.
3. **Group teleports are all-or-nothing in design, not in practice.** Teleporting a party of four can succeed for three and fail for one. Decide what happens: retry the one, return all four, or let three continue. Undefined, players end up separated with no way to regroup.
4. **Teleport data is client-visible and spoofable on arrival.** Data passed with a teleport that the client can influence must not be trusted for rewards or permissions. Use it for hints (which spawn, which party) and look up anything important server-side.
5. **Loading screens differ by platform.** The custom teleport loading GUI shows on the client during the hop; on slow phones the hop can take many seconds. A static, light loading screen that matches the destination's look reduces perceived wait. Heavy animated loading GUIs can themselves stutter on low-end devices.
6. **Multi-place games multiply release work.** Each place is published separately. If the lobby and the arena run different versions of shared modules, data formats can disagree. Release all places together, keep data migrations backward compatible for at least one version, and check versions on arrival.
7. **Server counts per place change with traffic.** A busy lobby feeding many reserved arenas creates many short-lived servers; each new server pays startup cost (loading the place, warming caches). Keep arena places small and fast to boot, and reuse reserved servers for several rounds when the design allows.
8. **Testing needs the live environment.** Teleports do not work fully in Studio (the existing table in this note covers it), so test in a private copy of the universe with real servers, including failure cases (destination full, closing).

The senior trade-off: splitting a game into places allows bigger worlds and separate server rules, at the cost of data races, slower transitions and multi-place releases. Stay in one place until size, player counts or server rules force a split.

## Common mistakes (advanced)

1. **Teleporting before the save completes.** Symptom: progress loss after travel. Fix: save and release, then teleport; locks on the destination.
2. **No regroup plan for partial party failures.** Symptom: friends split across servers. Fix: defined retry or return rules.
3. **Rewards based on teleport data.** Symptom: exploiters arrive with fake rewards. Fix: server lookups.
4. **Heavy animated loading screens.** Symptom: stutter and longer perceived loads on phones. Fix: light, static screens.
5. **Releasing places separately.** Symptom: data format mismatches between lobby and arena. Fix: release together and check versions.
6. **New reserved server per round.** Symptom: long waits between rounds. Fix: reuse servers where possible.

## Related decisions

- [[Session State Across Places]]: carrying state safely between places.
- [[Parties and Group Teleports]]: party handling and partial failures.
- [[Reserved and Private Servers in Practice]]: reserved server lifecycles.
- [[Matchmaking Queues with MemoryStore]]: filling destination servers.
- [[Session Locking and Profile Libraries]]: the lock that prevents travel races.
- [[Release Process and Rollbacks]]: releasing multi-place games together.
- [[Lobby and Hub Design]]: the source side of most teleports.
- [[Case Study - Fast Join and Deferred Loading]]: making arrival fast.

## Connected notes
<!-- auto-links:start -->
[[Links - Teleporting]] · Multiplayer Services Start Here · Links - Reserved and private servers · Server Shutdowns Soft Updates and Migration · Server Browsers and Server Lists · Session Lock
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Joining Friends Parties and Private Servers]] · [[Server Hop Rejoin and Server Lists with Ping]] · [[Client-Server Model]] · [[Network Ownership]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Project Structure and Bootstrapping]] · [[Rate Limiting and Abuse Prevention]] · [[Replication Rules]]
<!-- related:end -->
