---
tags: [multiplayer, server-browser, memorystore, teleport, lobby, text-filtering, luau, strict, type/guide, area/networking, level/intermediate, api/TeleportService]
---
# Server Browsers and Server Lists

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Every server lists the registry -> One builder, everyone else reads a snapshot
> - Avoid: Trusting a client-supplied `JobId` -> Join only what the server listed
> - Avoid: Player names in the public listing -> Friends-only presence, counts not names
> - A written reason for having a browser at all; Quick Join stays primary.
> - Registry entries small, TTL 90 s, heartbeat 30 s, early write near full.
> - One snapshot builder under a lease; compact rows under 30 KB; copies for hot reads.
>
> Cost: TL;DR ~160 tok · whole note ~5.5k tok. Read more: ## 5. Building the snapshot · ## 6. Serving and joining · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A server browser is a list of live servers a player can pick from: "EU Roleplay, 18/24, night cycle", "Trading hub 3, 40/50", "Your friend is here". Some genres expect it (roleplay, hangouts, competitive communities that want specific rules); most games are better off without one. When you do build it, the engine gives you no list of your own public servers, so you build a registry out of MemoryStore, and the hard parts are not the list itself but its cost at scale, the 32 KB value limit, stale entries, joining a server that filled a second ago, showing friends without leaking privacy, and user-named servers that must pass text filtering. This note goes deeper than the registry sketches in [[MemoryStore Service]] and [[Cross-Server Messaging]].

Related: [[Reserved and Private Servers in Practice]] (custom rooms that also appear in lists), [[Matchmaking Queues with MemoryStore]] (the alternative to choosing), [[Virtualized Lists and Large Inventories]] (the UI), [[Lobby and Hub Design]].

## 1. Should you have one?

| Have a browser | Skip it |
|---|---|
| Servers differ in ways players care about: rules, map, language, role-play theme, event running | All servers are the same |
| Long sessions, players return to "their" server community | Short sessions, drop in and out |
| Mature audience that organises itself (communities, clans) | Young or new audience that just wants to play |
| CCU high enough that most listed servers are healthy | Low CCU: a browser shows ten servers with two players each |

The hidden cost is **fragmentation**. Built-in matchmaking packs players into healthy servers using signals like Occupancy and Friends (Roblox docs, as of October 2026). A browser lets players scatter, and a game of 30 half-empty servers feels dead. If you build one, make **Quick Join** (built-in matchmaking or your best-fit pick) the big button and the list the secondary option.

The Roblox website and app already show a server list for public servers of a place with a join option (rule of thumb; the exact presentation varies by platform and is not part of the engine API). An in-game browser earns its place only when it shows things the platform cannot: your server names, rules, modes and friend counts.

## 2. Where the data comes from

There is no engine call that returns your experience's list of public servers (not found in the TeleportService, Players or DataModel references as of October 2026). Web endpoints used by the website are not reachable from game servers through `HttpService` (rule of thumb: requests to Roblox's own web domains are blocked from game servers; unverified for every domain). So each server **announces itself** in a shared registry, and listings are read from that registry.

The pieces:

1. **Registry**: one MemoryStore hash map key per live server, written by that server every 30 s with a 90 s expiration. A crashed server disappears on its own.
2. **Snapshot builder**: one elected server reads the whole registry every 15 s and writes a compact, sorted **snapshot** into a few copies of one key.
3. **Lobby servers**: read one snapshot copy every 15 s, cache it, and serve it to clients from memory.
4. **Join**: the client asks to join a listed server; the server validates and teleports with `TeleportOptions.ServerInstanceId`.

Why the snapshot layer: without it, every lobby server lists the whole registry. `MemoryStoreHashMap:ListItemsAsync` costs partitions scanned plus items returned (Roblox docs). With 500 game servers and 100 lobby servers each listing every 15 s, that is at least 100 x 4 x 500 = 200,000 units per minute, close to the entire quota at 1,600 CCU (`1,000 + 120 x CCU`, Roblox docs). One builder listing plus 100 single-key reads is about 2,000 + 400 units.

## 3. The registry entry

Keep it small and only include what the list shows or filters on.

| Field | Source | Notes |
|---|---|---|
| `job` | `game.JobId` | Key and join target; a UUID unique to the server instance |
| `place` | `game.PlaceId` | Multi-place games list several places |
| `ver` | `game.PlaceVersion` | Hide old versions during update bleed-off |
| `n` / `max` | `#Players:GetPlayers()` / `Players.MaxPlayers` | |
| `name` | Filtered server name, if you allow naming | Filtered once, stored filtered |
| `mode` | Your server attribute (map, ruleset) | |
| `lang` | Majority `Player.LocaleId` prefix | A hint, not a region |
| `t` | `os.time()` | Freshness |

Region is the field people ask for and you cannot honestly fill. The engine does not expose a server's datacenter location on the reference pages checked (unverified). Built-in matchmaking already weighs latency for joins; a hand-rolled "region" label would be guesswork. Show language instead.

Do **not** put player names or UserIds in the registry entry. A list of who is where, visible to everyone, is a stalking tool. Friend presence is handled separately (section 7).

## 4. Writing the registry

```lua
--!strict
-- ServerScriptService/ServerList/RegistryWriter.luau (every public server)
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HEARTBEAT = 30
local TTL = 90

local registry = MemoryStoreService:GetHashMap("ServerRegistry")

export type Entry = {
	job: string,
	place: number,
	ver: number,
	n: number,
	max: number,
	name: string?,
	mode: string?,
	lang: string?,
	t: number,
}

local RegistryWriter = {}
local serverName: string? = nil
local closing = false
local lastWrittenCount = -1

local function majorityLanguage(): string?
	local counts: { [string]: number } = {}
	local best, bestCount = nil, 0
	for _, p in Players:GetPlayers() do
		local lang = string.sub(p.LocaleId, 1, 2)
		local c = (counts[lang] or 0) + 1
		counts[lang] = c
		if c > bestCount then
			best, bestCount = lang, c
		end
	end
	return best
end

local function write()
	if closing or game.PrivateServerId ~= "" then
		return -- private and reserved servers are listed by their own room directory, not here
	end
	local entry: Entry = {
		job = game.JobId,
		place = game.PlaceId,
		ver = game.PlaceVersion,
		n = #Players:GetPlayers(),
		max = Players.MaxPlayers,
		name = serverName,
		mode = workspace:GetAttribute("Mode") :: string?,
		lang = majorityLanguage(),
		t = os.time(),
	}
	local ok, err = pcall(function()
		registry:SetAsync(game.JobId, entry, TTL)
	end)
	if ok then
		lastWrittenCount = entry.n
	else
		warn(`[ServerList] registry write failed: {err}`) -- next heartbeat retries; TTL gives 2 misses of slack
	end
end

function RegistryWriter.setName(filteredName: string?)
	serverName = filteredName
	task.spawn(write)
end

function RegistryWriter.start()
	if RunService:IsStudio() then
		return -- keep Studio sessions out of the listing logic (memory stores are separate in Studio anyway)
	end
	task.spawn(function()
		task.wait(math.random() * HEARTBEAT) -- stagger servers
		while not closing do
			write()
			task.wait(HEARTBEAT)
		end
	end)
	-- Big changes (empty to busy, nearly full) are worth an early write, debounced.
	local pending = false
	local function onCountChanged()
		local n = #Players:GetPlayers()
		local max = Players.MaxPlayers
		local crossed = (lastWrittenCount < max - 1 and n >= max - 1) or (lastWrittenCount >= max - 1 and n < max - 1)
		if crossed and not pending then
			pending = true
			task.delay(3, function()
				pending = false
				write()
			end)
		end
	end
	Players.PlayerAdded:Connect(onCountChanged)
	Players.PlayerRemoving:Connect(onCountChanged)

	game:BindToClose(function()
		closing = true
		pcall(function()
			registry:RemoveAsync(game.JobId)
		end)
	end)
end

return RegistryWriter
```

`Players.MaxPlayers` is the configured server size. Treat a server as full one slot early: two people clicking at once is common.

## 5. Building the snapshot

One server holds a lease (the same `UpdateAsync` compare-and-set pattern as the matchmaker in [[Matchmaking Queues with MemoryStore]]) and runs this every 15 s:

1. `ListItemsAsync(200)` and page through with the returned pages object until done. Each page costs partitions scanned plus items.
2. Drop entries older than 90 s by `t` (expiry handles most, this catches clock drift), entries from older place versions when a newer version exists, and full servers.
3. Sort: "best fit" first (most players but not full), then the rest.
4. Encode compactly and write to `Snapshot_1` ... `Snapshot_K`.

### The 32 KB wall

MemoryStore values are capped at 32 KB (Roblox docs). A naive JSON snapshot of 500 entries with field names and a 36-character `JobId` each is around 60 KB. Options, from cheapest:

- **Array of arrays** instead of objects: `{"<job>",place,ver,n,max,"name","mode","lang"}` saves the field names. About 70 to 90 bytes per entry with a short name.
- **Cap the list**: nobody scrolls past the first 150 servers. Keep the best 150 by fit, plus every server with a custom name or non-default mode.
- **Page it**: `Snapshot_p1`, `Snapshot_p2`, written together, read on demand when the player scrolls.
- **Compress** with a `buffer`-based encoding ([[Buffers and Binary Data]]): a JobId UUID is 16 bytes in binary instead of 36 characters. Values must still be JSON-encodable, so base64 the buffer; that gives back a third, still a large win. Usually not worth it below 1,000 servers.

### Hot key and copies

Every lobby reads the snapshot. A single hash map key has an estimated limit of about 15,000 read units per minute (Roblox docs, an estimate that can change). 100 lobbies reading every 15 s is 400 reads per minute, fine. At 2,000 lobby-type servers reading every 5 s you would hit it; then write K copies (`Snapshot_1..K`) and have each server read the copy `hash(JobId) % K`, which is exactly the hot-key sharding the MemoryStore best-practices guide describes.

```lua
--!strict
-- ServerScriptService/ServerList/SnapshotBuilder.luau (lease holder only)
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local registry = MemoryStoreService:GetHashMap("ServerRegistry")
local snapshots = MemoryStoreService:GetHashMap("ServerSnapshots")

local COPIES = 2
local MAX_LISTED = 150
local SNAPSHOT_TTL = 60
local STALE_AFTER = 90
local MAX_BYTES = 30_000 -- headroom under the 32 KB value limit

type Row = { any } -- { job, place, ver, n, max, name, mode, lang }

local SnapshotBuilder = {}

local function collect(): { { [string]: any } }?
	local ok, pages = pcall(function()
		return registry:ListItemsAsync(200)
	end)
	if not ok or pages == nil then
		warn(`[ServerList] ListItemsAsync failed: {pages}`)
		return nil
	end
	local out = {}
	while true do
		for _, item in pages:GetCurrentPage() do
			if type(item.value) == "table" then
				table.insert(out, item.value)
			end
		end
		if pages.IsFinished then
			break
		end
		local advanced = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not advanced then
			break -- partial list is better than none
		end
	end
	return out
end

function SnapshotBuilder.buildOnce()
	local entries = collect()
	if not entries then
		return -- keep the previous snapshot; its TTL covers a few failed rounds
	end
	local now = os.time()
	local newestVersion: { [number]: number } = {}
	for _, e in entries do
		local place, ver = tonumber(e.place), tonumber(e.ver)
		if place and ver and ver > (newestVersion[place] or 0) then
			newestVersion[place] = ver
		end
	end
	local rows: { Row } = {}
	for _, e in entries do
		local n, max, t = tonumber(e.n), tonumber(e.max), tonumber(e.t)
		local place, ver = tonumber(e.place), tonumber(e.ver)
		if n and max and t and place and ver and type(e.job) == "string"
			and now - t <= STALE_AFTER
			and ver == newestVersion[place]
			and n < max - 1 then
			table.insert(rows, { e.job, place, ver, n, max, e.name or "", e.mode or "", e.lang or "" })
		end
	end
	-- Best fit first: fuller servers ahead of emptier ones.
	table.sort(rows, function(a, b)
		return (a[4] / a[5]) > (b[4] / b[5])
	end)
	while #rows > MAX_LISTED do
		table.remove(rows)
	end
	local encoded = HttpService:JSONEncode({ t = now, rows = rows })
	while #encoded > MAX_BYTES and #rows > 10 do
		for _ = 1, 10 do
			table.remove(rows)
		end
		encoded = HttpService:JSONEncode({ t = now, rows = rows })
	end
	for i = 1, COPIES do
		pcall(function()
			snapshots:SetAsync("Snapshot_" .. i, encoded, SNAPSHOT_TTL)
		end)
	end
end

function SnapshotBuilder.copyIndexFor(jobId: string): number
	local h = 0
	for i = 1, #jobId do
		h = (h * 31 + string.byte(jobId, i)) % 2147483647
	end
	return (h % COPIES) + 1
end

return SnapshotBuilder
```

The lease loop around `buildOnce` is the same shape as the matchmaker's: try the lease every few seconds, build while holding it.

## 6. Serving and joining

Lobby servers keep the decoded snapshot in memory and answer clients from it. A client request never touches MemoryStore.

```lua
--!strict
-- ServerScriptService/ServerList/BrowserService.luau (lobby servers)
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local SnapshotBuilder = require(script.Parent.SnapshotBuilder)

local snapshots = MemoryStoreService:GetHashMap("ServerSnapshots")
local getList = ReplicatedStorage.Remotes.GetServerList :: RemoteFunction
local joinServer = ReplicatedStorage.Remotes.JoinServer :: RemoteEvent

local REFRESH = 15
local cached: { rows: { { any } }, t: number } = { rows = {}, t = 0 }
local byJob: { [string]: { any } } = {}
local lastRequest: { [number]: number } = {}

local function refresh()
	local key = "Snapshot_" .. SnapshotBuilder.copyIndexFor(game.JobId)
	local ok, raw = pcall(function()
		return snapshots:GetAsync(key)
	end)
	if not ok or type(raw) ~= "string" then
		return -- keep showing the last good list
	end
	local decoded, value = pcall(HttpService.JSONDecode, HttpService, raw)
	if decoded and type(value) == "table" and type(value.rows) == "table" then
		cached = { rows = value.rows, t = tonumber(value.t) or 0 }
		byJob = {}
		for _, row in cached.rows do
			if type(row[1]) == "string" then
				byJob[row[1]] = row
			end
		end
	end
end

local function rateLimited(player: Player, seconds: number): boolean
	local now = os.clock()
	if now - (lastRequest[player.UserId] or 0) < seconds then
		return true
	end
	lastRequest[player.UserId] = now
	return false
end

getList.OnServerInvoke = function(player: Player)
	if rateLimited(player, 2) then
		return nil
	end
	return cached -- display data only; contains no player identities
end

joinServer.OnServerEvent:Connect(function(player: Player, jobId: unknown)
	if rateLimited(player, 3) or type(jobId) ~= "string" or #jobId > 64 then
		return
	end
	local row = byJob[jobId]
	if not row then
		player:SetAttribute("JoinError", "That server is no longer available.")
		return
	end
	local placeId = tonumber(row[2])
	if not placeId then
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ServerInstanceId = jobId
	local ok = pcall(function()
		return TeleportService:TeleportAsync(placeId, { player }, options)
	end)
	if not ok then
		player:SetAttribute("JoinError", "Could not join. Try another server.")
	end
end)

TeleportService.TeleportInitFailed:Connect(function(player, result)
	if result == Enum.TeleportResult.GameFull then
		player:SetAttribute("JoinError", "That server just filled up.")
	elseif result == Enum.TeleportResult.GameEnded or result == Enum.TeleportResult.GameNotFound then
		player:SetAttribute("JoinError", "That server has closed.")
	end
end)

task.spawn(function()
	while true do
		refresh()
		task.wait(REFRESH + math.random() * 3)
	end
end)
```

Validation rule: the client may only pick from what the server listed. A `JobId` not in the current snapshot is refused, which also blocks clients from using the browser to target arbitrary servers. Do not cache the failure state too long: clear `JoinError` on the next request. If a project already has a single `TeleportInitFailed` handler (the retry helper from [[Teleporting and Multi-Place Games]]), add these messages there rather than connecting twice.

## 7. Friends in the list

"3 friends are here" is the most useful thing a browser can show, and the easiest to get wrong.

Approach: a separate **presence** hash map, `Presence_<userId> -> jobId`, written by each server for its own players with a TTL of 120 s, refreshed every 60 s, removed on leave. When a player opens the browser, their lobby server:

1. Fetches their friends once per session with `Players:GetFriendsAsync(userId)` (paged), keeping at most the first 200.
2. Looks up presence keys for friends, at most 50 per open and cached for 60 s.
3. Counts friends per `JobId` and annotates matching rows, for this viewer only.

Costs one read per looked-up friend; at 50 friends per open, a player opening the browser every minute costs 50 units per minute, so cap opens per player (once per 30 s) and cache.

Privacy: friend presence is shown only to friends, never in the shared snapshot. Roblox's own join and visibility privacy settings are not exposed to your code on the pages checked (unverified), so be conservative: show a count ("2 friends") rather than names unless both players opted in through your own setting, and never show non-friends.

## 8. User-named servers

If players name servers (private server owners, room hosts), the name is user-generated text displayed to other users and must be filtered. Use `TextService:FilterStringAsync(text, fromUserId)` on the server and display the result of `GetNonChatStringForBroadcastAsync()` to everyone. Filter once when the name is set, store the filtered string in the registry, and refilter if your listing outlives the session of the author (rule of thumb: filter results should be treated as display-time decisions; refiltering on each set is the safe minimum). If filtering errors, show a default name, never the raw input. See [[Roblox Policies Ratings and Compliance]] and [[Localization]] for the wider rules.

Cap name length (24 characters is plenty) and strip rich text tags before filtering if your UI uses RichText ([[Text Fonts and Rich Text]]).

## 9. Lists of private rooms and reserved servers

Reserved and private servers do not belong in the public registry: you cannot join them with `ServerInstanceId`, only with an access code (reserved) or an invite and the game page (private). List **rooms** instead, from the room directory in [[Reserved and Private Servers in Practice]]: the listed id is a room id, and the join handler resolves it to an access code server-side after checking the room's visibility (public, friends, invite-only). Room servers write their own small presence entry (players, name) keyed by room id so the list can show which rooms are live.

## 10. Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| List shows ghosts that cannot be joined | TTL too long or builder down, snapshot not refreshed | TTL 90 s; builder lease takeover; staleness filter by `t` |
| Lists differ between lobbies | Different snapshot copies at different times | Accept it; show "updated 10 s ago" |
| Join fails often with `GameFull` | Listing counts lag by up to 30 s | Hide servers within 1 to 2 slots of full; early write on threshold crossing |
| Empty list during update bleed-off | All servers on old version filtered | Filter old versions only when a newer version has at least some servers |
| `ItemValueSizeTooLarge` | Snapshot over 32 KB | Compact rows, cap, page |
| `PartitionRequestsOverLimit` on snapshot key | Many lobbies reading one key | Copies plus stable routing |
| Quota warnings at peak | Every server listing the registry | Only the lease holder lists |

## Common mistakes

| Mistake | Fix |
|---|---|
| Every server lists the registry | One builder, everyone else reads a snapshot |
| Trusting a client-supplied `JobId` | Join only what the server listed |
| Player names in the public listing | Friends-only presence, counts not names |
| Raw user server names | Filter on the server, store the filtered string |
| Promising a "region" column | Show language; let matchmaking handle latency |
| A browser as the only way in | Quick Join as the main button |

## Checklist

- [ ] A written reason for having a browser at all; Quick Join stays primary.
- [ ] Registry entries small, TTL 90 s, heartbeat 30 s, early write near full.
- [ ] One snapshot builder under a lease; compact rows under 30 KB; copies for hot reads.
- [ ] Clients served from memory; joins validated against the snapshot.
- [ ] `GameFull` and closed-server failures give clear messages.
- [ ] Friend presence private, capped and cached.
- [ ] User names filtered server-side before listing.
- [ ] Budget estimated at peak server count.

## See also
[[Multiplayer Services Start Here]] · [[MemoryStore Service]] · [[Cross-Server Messaging]] · [[Teleporting and Multi-Place Games]] · [[Reserved and Private Servers in Practice]] · [[Matchmaking Queues with MemoryStore]] · [[Virtualized Lists and Large Inventories]] · [[Lobby and Hub Design]] · [[Social Design and Multiplayer Play]]

## Connected notes
<!-- auto-links:start -->
[[Parties and Group Teleports]] · [[Links - Reserved and private servers]] · [[Server Shutdowns Soft Updates and Migration]] · Open Cloud APIs · OrderedDataStores and Leaderboards · Debugging DataStore Problems
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Server Hop Rejoin and Server Lists with Ping]] · [[Session State Across Places]] · [[Joining Friends Parties and Private Servers]] · [[Genre Playbook - Battle Royale]] · [[OrderedDataStores and Leaderboards]] · [[Debugging Live Servers]]
<!-- related:end -->
