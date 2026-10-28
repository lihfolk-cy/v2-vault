---
tags: [data, memorystore, matchmaking, queues, sorted-map, hash-map, cross-server]
---
# MemoryStore Service

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Treating it as durable (Data vanishes at TTL or on flush)
> - Avoid: Long TTLs "just in case" (Memory quota exhausted; every write that adds data fails, possibly...)
> - Avoid: Reading big ranges often from every server (Request quota gone in seconds)
> - Every write has the shortest sensible expiration.
> - Processed items are explicitly removed.
> - Reads are cached per server and staggered.
>
> Read more (14 KB note): ## Quotas and request units (Roblox docs, October 2026) · ## Patterns · ## Common mistakes · ## Checklist
<!-- tldr:end -->

`MemoryStoreService` is Roblox's shared, fast, **expiring** storage: every server of an experience can read and write the same queues, sorted maps and hash maps with low latency, and every item disappears after its time to live (at most 45 days). It is the right tool for matchmaking, cross-server auctions and trading boards, live event leaderboards, server registries, and as a cache in front of data stores. It is the wrong tool for anything that must survive. This note lists the three structures, their exact quotas (October 2026), how request units are counted, sharding, failure codes, and working patterns.

Prerequisites: [[DataStore Fundamentals]]. Related: [[Cross-Server Messaging]], [[OrderedDataStores and Leaderboards]].

## Data stores vs memory stores vs messaging

| Need | Use |
|---|---|
| Survive forever, versioned, per-player | Data store |
| Shared state many servers read and write within seconds, OK to lose on expiry | Memory store |
| Push a notification to all servers now, best effort | MessagingService |
| Read-only tuning values for every server | Experience configs ([[Global State and Live Config]]) |

Roblox's own comparison adds a nuance: for quickly **reading** a small number of values across all servers, configs outperform memory stores, which are "not as performant as configs when frequently accessing a single key or partition".

## The three structures

| | Queue | Sorted map | Hash map |
|---|---|---|---|
| Get one | `MemoryStoreService:GetQueue(name, invisibilityTimeout?)` | `GetSortedMap(name)` | `GetHashMap(name)` |
| Order | Priority, then insertion (FIFO) | By sort key, then key | None |
| Key size | n/a | 128 characters | 128 characters |
| Value size | 32 KB (status `ItemValueSizeTooLarge`) | 32 KB | 32 KB |
| Sort key | n/a | Number or string, up to 128 characters | n/a |
| Capacity per structure | 1,000,000 items, 100 MB | 1,000,000 items, 100 MB (keys included) | No per-structure limit (spread over partitions) |
| Partitions | One | One | Many (automatic) |
| Expiration | Required on add, max 3,888,000 s (45 days) | Required on set, max 45 days | Required on set, max 45 days |
| Atomic update | Read + remove pattern | `UpdateAsync(key, fn, expiration)` | `UpdateAsync(key, fn, expiration)` |

Names are global within the experience: the same name in any place is the same structure.

### Choosing

Roblox's decision tree: if the data must be sorted, use a sorted map. If not, and you need to scan everything, use a sorted map when you expect fewer than about 1,000 keys and a hash map otherwise. If you just access by key, use a hash map. If you need to process items in order, use a queue. Hash maps scale best because they spread across partitions.

## Quotas and request units (Roblox docs, October 2026)

### Memory

**64 KB + 1.2 KB x users** for the whole experience. When users join, quota grows immediately; when they leave, it shrinks only after an **eight-day** look-back. Once you hit it, every request that would **increase** memory fails (`TotalMemoryOverLimit`); requests that shrink or keep memory constant still work.

At 1,000 CCU that is about 1.2 MB. That is small. A queue of matchmaking tickets at 300 bytes each is fine; caching full player profiles in a hash map is not.

### Requests

**1,000 + 120 x CCU request units per minute**, experience-wide (any server may use any share). Most calls cost 1 unit, except:

| Call | Units |
|---|---|
| `MemoryStoreSortedMap:GetRangeAsync` | Number of items returned (1 if empty) |
| `MemoryStoreQueue:ReadAsync` | Items returned, plus 1 for every 2 seconds spent waiting |
| `MemoryStoreHashMap:UpdateAsync` | At least 2 |
| `MemoryStoreHashMap:ListItemsAsync` | Partitions scanned + items returned |

Exceeding it returns `TotalRequestsOverLimit`.

### Per-partition and per-key safeguards

On top of the quota, Roblox throttles hot partitions. The docs give **estimates** that "can change, so don't design against them as fixed numbers":

- About **30,000 request units per minute** for one partition. A sorted map or queue is one partition, so this is effectively the ceiling for any single queue or sorted map.
- Hash map items: about **5,000 write units and 15,000 read units per minute per key**.
- A data-structure-level limit of 100,000 request units per minute (`DataStructureRequestsOverLimit`).

Throttling shows up as `PartitionRequestsOverLimit`.

### Extended Services

If legitimate use exceeds the free quotas, Extended Services bills memory store requests at $0.003 per 1M and storage at $0.10 per GB per hour (October 2026 pricing; requires an ID-verified 18+ account owner). Reduce, expire and shard first.

## Patterns

### 1. Matchmaking queue

```lua
--!strict
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")

-- Items read are invisible to other readers for 30 s (the default) until removed.
local queue = MemoryStoreService:GetQueue("Matchmaking_Ranked", 30)

type Ticket = { userId: number, rating: number, at: number }

local function enqueue(player: Player, rating: number): boolean
	local ticket: Ticket = { userId = player.UserId, rating = rating, at = os.time() }
	local ok, err = pcall(function()
		queue:AddAsync(HttpService:JSONEncode(ticket), 120) -- expire after 2 minutes
	end)
	if not ok then
		warn(`enqueue failed: {err}`)
	end
	return ok
end

-- Runs on lobby servers only. Pulls a batch, forms matches, removes what it used.
local MATCH_SIZE = 8
local function matchLoop()
	while true do
		local ok, items, readId = pcall(function()
			-- all-or-nothing read of exactly MATCH_SIZE tickets, waiting up to 5 s
			return queue:ReadAsync(MATCH_SIZE, true, 5)
		end)
		if ok and items and #items == MATCH_SIZE then
			local tickets = {}
			for _, raw in items do
				table.insert(tickets, HttpService:JSONDecode(raw))
			end
			local reserved = true -- reserve a server, teleport (see the teleporting note)
			if reserved then
				pcall(function()
					queue:RemoveAsync(readId) -- must happen before the 30 s invisibility ends
				end)
			end
			-- if we did not remove, the tickets reappear after the timeout for another lobby
		elseif not ok then
			task.wait(2 + math.random() * 2)
		end
		task.wait(0.5)
	end
end
```

Points that matter:

- `ReadAsync(count, allOrNothing, waitTimeout)`: `count` max **100**. `waitTimeout = -1` or omitted waits forever; `0` returns immediately. While waiting it polls every 2 s and costs a unit each time.
- Read items are **not** deleted. They become invisible for the invisibility timeout. If your process crashes before `RemoveAsync(id)`, they come back. That is a feature (at-least-once delivery), but it means a ticket can be processed twice: make the downstream step idempotent (check the player is not already in a match).
- `RemoveAsync` after the timeout has no effect, and another reader may already have the items.
- Expire tickets aggressively. A player who leaves the lobby should not be matched two minutes later; also remove their ticket explicitly when possible.
- Check whether Roblox's built-in matchmaking options fit before building a full system on queues (not verified for this note); see [[Teleporting and Multi-Place Games]] and [[Spawning Teams and Rounds]].

### 2. Live leaderboard / auction with a sorted map

```lua
--!strict
local MemoryStoreService = game:GetService("MemoryStoreService")
local map = MemoryStoreService:GetSortedMap("EventScores_Halloween")
local TTL = 3 * 86400

-- Keep the highest score only; UpdateAsync retries on conflicts, so the callback must be pure.
local function submit(userId: number, score: number)
	pcall(function()
		map:UpdateAsync(tostring(userId), function(old: any, oldSortKey: any)
			local best = tonumber(oldSortKey) or 0
			if score <= best then
				return nil -- abort: no write, no conflict loop
			end
			return { s = score, t = os.time() }, score -- value, sortKey
		end, TTL)
	end)
end

local function top(n: number): { { key: string, value: any, sortKey: any } }?
	local ok, items = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Descending, math.clamp(n, 1, 200))
	end)
	return if ok then items else nil
end
```

- `GetRangeAsync(direction, count, exclusiveLowerBound?, exclusiveUpperBound?)`: `count` max **200**; bounds are tables `{ key = ..., sortKey = ... }`. Each returned item costs a unit, so `top(200)` from 500 servers every 10 s is 600,000 units per minute: far over budget. Cache, read less often, read fewer rows.
- Sort order (docs): numeric sort keys first, then string sort keys, then items with no sort key; ties broken by key.
- An auction is the same shape: one key per lot, `UpdateAsync` keeps only the highest bid. The docs' advice: keep only what you need (the highest bid, not all bids).

### 3. Server registry with a hash map

A "list of live servers" for a server browser, or "which server is player X in":

```lua
--!strict
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local servers = MemoryStoreService:GetHashMap("LiveServers")

local HEARTBEAT = 30
task.spawn(function()
	task.wait(math.random() * HEARTBEAT)
	while true do
		pcall(function()
			servers:SetAsync(game.JobId, {
				placeId = game.PlaceId,
				players = #Players:GetPlayers(),
				at = os.time(),
			}, HEARTBEAT * 3) -- dies on its own if this server crashes
		end)
		task.wait(HEARTBEAT)
	end
end)

game:BindToClose(function()
	pcall(function()
		servers:RemoveAsync(game.JobId)
	end)
end)
```

Reading the whole registry with `ListItemsAsync(count)` (count 1 to 200 per page) costs partitions scanned plus items, so a browser that every server refreshes every few seconds gets expensive; refresh every 30 to 60 s and cache. Do not put everything in one key ("metadata"): a single hash map key is one partition, which defeats automatic sharding. Store each independently read field as its own key.

### 4. Cache in front of a data store

Roblox suggests hash maps as a cache for persistent data. Be careful: the memory quota is small, and you now have two copies that can disagree. Good uses: caching expensive shared data (a guild's roster, a global event config computed by one server) with a TTL of minutes. Bad use: caching player profiles (session-locked data must have one owner; see [[Session Locking and Profile Libraries]]).

## Sharding

When one structure or key is hot:

- **Sorted maps**: split by a stable hash of the key into N maps (`Scores_0` ... `Scores_3`), user id modulo N. Top-N queries then read the top of each shard and merge.
- **Queues**: harder, because adds and reads happen at the ends. Roblox's pattern keeps a list of queues and two rotating pointers, one for adding and one for reading.
- **Hash maps**: already partitioned; shard only hot keys by making copies (`Weather_1..3`) and routing each server to one copy by `JobId` hash, updating all copies on change.

## Failure handling

All calls yield and can throw. Common statuses (observability dashboard and client errors):

| Status | Meaning | Response |
|---|---|---|
| `TotalRequestsOverLimit` | Experience request quota | Back off, cache, read less |
| `PartitionRequestsOverLimit` / `DataStructureRequestsOverLimit` | Hot partition, key or structure | Shard, batch, cache |
| `TotalMemoryOverLimit` / `DataStructureMemoryOverLimit` (100 MB) | Memory full | Delete, shorten TTL, shrink values; flush if acceptable |
| `DataStructureItemsOverLimit` | 1M items | Remove processed items |
| `ItemValueSizeTooLarge` | Over 32 KB | Split or compress |
| `DataUpdateConflict` / `UpdateConflict` | Concurrent updates exceeded retries | Backoff; abort early in the transform |
| `NoItemFound` | Empty queue read, or missing key in sorted map update | Normal |
| `InvalidExpirationTime` | Expiration outside 0 to 3,888,000 | Fix the constant |
| `UnpublishedPlace` | Place never published | Publish once |
| `InvalidClientAccess` | Called from a client | Server only |

Backoff: Roblox's example is 2, 4, 8 seconds after `DataUpdateConflict`. Add jitter.

If memory fills with data you do not need, Open Cloud can **flush** all memory stores of a scope: `POST https://apis.roblox.com/cloud/v2/universes/{universeId}/memory-store:flush` with `scope=LIVE` (default) or `TEST`. It clears every queue, sorted map and hash map in that scope, including live matchmaking. Use it as a last resort ([[Open Cloud APIs]]).

## Studio and testing

Memory store data is **isolated between Studio and production**: Studio sessions never see live data (unlike data stores). Studio has the same quotas, which, being computed from user counts, can be tiny when you are the only user; expect throttling sooner and slightly higher latency. The Developer Console has memory store views for debugging live servers ([[Developer Console and Stats]]).

## Common mistakes

| Mistake | Consequence |
|---|---|
| Treating it as durable | Data vanishes at TTL or on flush |
| Long TTLs "just in case" | Memory quota exhausted; every write that adds data fails, possibly breaking matchmaking for the whole game |
| Reading big ranges often from every server | Request quota gone in seconds |
| One giant hash map key | All traffic on one partition |
| Forgetting `RemoveAsync` after a queue read | Items reappear and get processed twice |
| Side effects inside `UpdateAsync` callbacks | Run several times under contention |
| Using it for session locks without understanding expiry | Locks evaporate mid-session |

## Checklist

- [ ] Every write has the shortest sensible expiration.
- [ ] Processed items are explicitly removed.
- [ ] Reads are cached per server and staggered.
- [ ] Hot structures are sharded; hot hash map keys copied.
- [ ] Downstream processing is idempotent (at-least-once delivery).
- [ ] Throttling and memory errors handled with backoff.
- [ ] Observability dashboard checked after launch.

## See also
[[DataStore Fundamentals]] · [[Cross-Server Messaging]] · [[OrderedDataStores and Leaderboards]] · [[Global State and Live Config]] · [[Teleporting and Multi-Place Games]] · [[Open Cloud APIs]] · [[Network Performance]] · [[Live Ops Events and Updates]]

## Connected notes
<!-- auto-links:start -->
[[Matchmaking Queues with MemoryStore]] · [[Links - MemoryStore]] · [[Server Browsers and Server Lists]] · [[Multiplayer Services Start Here]] · [[Cookbook - Data and Saving]] · [[Debugging DataStore Problems]]
<!-- auto-links:end -->
