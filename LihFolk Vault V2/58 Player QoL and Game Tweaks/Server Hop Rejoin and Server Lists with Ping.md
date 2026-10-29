---
tags: [qol, server-hop, rejoin, server-list, ping, memorystore, teleport, multiplayer, type/guide, area/multiplayer, level/advanced, api/TeleportService, api/MemoryStoreService, api/Player]
---
# Server Hop Rejoin and Server Lists with Ping

<!-- tldr:start -->
> [!tldr] TL;DR
> - Rejoin loads with "data locked": Destination loads before release -> Loader retries; save first
> - "New server" lands in the same one: Matchmaking picks it -> Hop to a listed target
> - Dead servers in the list: No expiry -> Short TTL entries, refreshed
> - Rejoin same server and new server, with cooldown and failure fallback.
> - Data saved and session released before teleports; loader retries.
> - Server registry with TTL, build version, player counts; private servers excluded.
>
> Cost: TL;DR ~160 tok · whole note ~2.1k tok. Read more: ## 1. Rejoin (same server) · ## 2. A server list · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Players want control over which server they are in: rejoin after a glitch, hop away from a laggy or empty server, find one with friends or a specific event. Roblox does not give games a built-in public server list API, so a server browser is something you build. This note is the QoL design: a Rejoin button, a "new server" button, and a server list showing player count, region-ish latency hints and status. The full engineering of server registries is in [[Server Browsers and Server Lists]]; teleport mechanics in [[Teleporting and Multi-Place Games]].

Sources: **Roblox docs** for `TeleportService:TeleportAsync` and `TeleportOptions` (https://create.roblox.com/docs/reference/engine/classes/TeleportService, https://create.roblox.com/docs/reference/engine/classes/TeleportOptions), `MemoryStoreService` (https://create.roblox.com/docs/cloud-services/memory-stores) and `Player:GetNetworkPing` (https://create.roblox.com/docs/reference/engine/classes/Player). Design is **Rule of thumb**.

## 1. Rejoin (same server)

"Rejoin" fixes stuck characters, broken UI or desynced state without losing the server the player was in (with friends, a good spot, an event).

```lua
--!strict
-- ServerScriptService/Rejoin
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local remote = ReplicatedStorage.Remotes.Rejoin :: RemoteEvent
local last: { [Player]: number } = {}

remote.OnServerEvent:Connect(function(player: Player, mode: any)
	if mode ~= "same" and mode ~= "new" then return end
	local now = os.clock()
	if now - (last[player] or 0) < 15 then return end
	last[player] = now

	local options = Instance.new("TeleportOptions")
	if mode == "same" and game.PrivateServerId == "" then
		options.ServerInstanceId = game.JobId
	end
	-- "new": no instance id, so Roblox matchmakes a server (may be the same one if few exist).
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player }, options)
	if not ok then warn("Rejoin failed", err) end
end)
```

Gotchas:
- **Save before teleporting.** The player's data must be saved and the session released, or the next server sees a locked profile. Most profile libraries handle release on leave, but the destination may load before release finishes; your loader must retry ([[Session Locking and Profile Libraries]]).
- **Full server**: rejoining the same server can fail once the player's slot is taken. Fall back to "new".
- **Private and reserved servers**: rejoining these requires the access code or reserved id; for reserved servers keep the code in your session state ([[Session State Across Places]]).
- **"New server" may land in the same server** when the experience has few servers. A true hop needs a target from a server list.

## 2. A server list

Each server registers itself in a MemoryStore sorted map with a short expiry, refreshed every 15-30 s. The list shows what players care about:

| Column | Source | Notes |
|---|---|---|
| Players | `#Players:GetPlayers()` / `Players.MaxPlayers` | Highlight nearly full |
| Friends here | Compare entries' user ids to the viewer's friends (client side) | Most useful column |
| Server age / uptime | `os.time()` at start | Old servers may be outdated after an update |
| Version | Your build number | Hide servers running old versions after a soft update |
| Event | Your state | "Boss in 2 min", "Night" |
| Ping hint | See below | Rough only |

```lua
--!strict
-- ServerScriptService/ServerRegistry (excerpt)
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local map = MemoryStoreService:GetSortedMap("Servers_v1")
local STARTED = os.time()
local BUILD = 42

local function publish()
	local userIds = {}
	for _, p in Players:GetPlayers() do table.insert(userIds, p.UserId) end
	local entry = HttpService:JSONEncode({
		job = game.JobId, place = game.PlaceId, n = #userIds, max = Players.MaxPlayers,
		started = STARTED, build = BUILD, users = userIds,
	})
	pcall(map.SetAsync, map, game.JobId, entry, 60) -- expires if the server dies
end

if game.PrivateServerId == "" then -- never list private or reserved servers
	task.spawn(function()
		while true do
			publish()
			task.wait(20)
		end
	end)
	game:BindToClose(function() pcall(map.RemoveAsync, map, game.JobId) end)
end
```

Listing user ids lets clients show "friends here", but think about privacy: show only friends' presence, not arbitrary player names, and drop the field if you do not need it. MemoryStore request and size limits apply; batch reads with `GetRangeAsync` and cache the list on each server for clients, rather than having every client query ([[Server Browsers and Server Lists]], [[Matchmaking Queues with MemoryStore]]).

## 3. Ping: what you can and cannot show

- **Current server ping** is measurable: `Player:GetNetworkPing()` on the client returns the player's network latency to their current server in seconds (**Roblox docs**). Show it in ms in a corner or the server panel ([[Feedback - Autosave Indicator Ping Display and Error Toasts]]).
- **Ping to other servers is not measurable** before joining. Do not invent numbers. You can show a **region hint** only if you have a trustworthy source; Roblox does not give game scripts a documented server-region API that we could confirm (**Unverified**). Third-party IP geolocation via `HttpService` is fragile and has privacy implications.
- A useful proxy: **average ping of players in that server**, reported by each server from its players' measurements (server-side `GetNetworkPing` on each player). It says "players here are having a good time" rather than "you will have 40 ms".

## 4. Server-hop etiquette

- **Cooldowns** on hop buttons (10-30 s) to avoid hammering teleports.
- **Don't let hopping become an exploit**: if rare spawns are per server, hopping to farm them is predictable. Decide whether that is fun or a problem ([[Economy Telemetry and Balancing Live]]).
- **After an update**, servers on old builds can show a "New version available – move to updated server" banner ([[Server Shutdowns Soft Updates and Migration]]).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Rejoin loads with "data locked" | Destination loads before release | Loader retries; save first |
| "New server" lands in the same one | Matchmaking picks it | Hop to a listed target |
| Dead servers in the list | No expiry | Short TTL entries, refreshed |
| Private servers exposed | Registered like public | Skip when `PrivateServerId ~= ""` |
| Fake ping numbers per server | No real measurement | Show current ping and average-player ping only |
| MemoryStore quota errors | Every client queries | Server caches and relays |

## Checklist

- [ ] Rejoin same server and new server, with cooldown and failure fallback.
- [ ] Data saved and session released before teleports; loader retries.
- [ ] Server registry with TTL, build version, player counts; private servers excluded.
- [ ] Friends-here column; privacy considered.
- [ ] Current ping shown; no invented cross-server ping.

## See also

- [[Server Browsers and Server Lists]]
- [[Teleporting and Multi-Place Games]]
- [[Network Performance]]
- [[Cross-Server Messaging]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Joining Friends Parties and Private Servers]] · [[Server Shutdowns Soft Updates and Migration]] · Session State Across Places
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Parties and Group Teleports]] · [[Top 25 QoL Wins by Effort]] · [[QoL Audit Checklist]] · [[Loading Screen Skip and First-Session Goals]] · [[AFK Detection Idle Kicks and AFK Reward Rules]] · [[Block and Mute Respecting Platform Rules]] · [[Notification Queues and Limits]] · [[Purchase Receipts and Purchase History in UI]] · [[Skippable Tutorials and Replayable Tips]]
<!-- related:end -->
