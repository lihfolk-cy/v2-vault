---
tags: [architecture, networking, messagingservice, live-ops, cross-server, type/guide, area/networking, level/intermediate, api/MessagingService, area/liveops, api/DataStore, api/HttpService]
---
# Cross-Server Messaging

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Using MessagingService as a database -> Store state; message to notify
> - Avoid: One topic per player or item -> Few topics, route in payload
> - Avoid: Publishing on every small change -> Aggregate per server every 30 to 60 s
> - Message dropped
> - Message duplicated
> - Message late
>
> Cost: TL;DR ~110 tok · whole note ~4.6k tok. Read more: ## A robust wrapper · ## Nuances and edge cases · ## Reliability checklist for messages · ## Common mistakes
<!-- tldr:end -->

A popular experience runs as many independent servers. Each has its own DataModel and its own players, and by default they share nothing except DataStores. **MessagingService** lets servers of the same experience publish and subscribe to messages on named topics, typically delivered within one to two seconds (Roblox docs). It is how you build global announcements, cross-server events ("a world boss spawned somewhere"), server browsers, friend-follow notices and live-ops broadcasts. It is also **best effort, size-limited and rate-limited**, and treating it like a reliable database is the most common mistake. This note covers the exact limits, topic and payload design, reliability patterns, how it combines with MemoryStore and DataStores, and working code.

## The service in one table

| Fact | Value (Roblox docs, as of October 2026; "subject to change") |
|---|---|
| Delivery | Best effort, not guaranteed; typically within 1 to 2 seconds |
| Topic names | Developer-defined strings, 1 to 80 characters |
| Message size | 1 kB |
| Messages sent per server | 600 + 240 x (players in this server) per minute |
| Messages received per topic | (40 + 80 x number of servers) per minute |
| Messages received for the whole experience | (400 + 200 x number of servers) per minute |
| Subscriptions per server | 20 + 8 x (players in this server) |
| Subscribe requests per server | 240 per minute |
| `PublishAsync(topic, message)` | Yields until the backend receives the message |
| `SubscribeAsync(topic, callback)` | Yields until registered; returns an `RBXScriptConnection`; `Disconnect()` unsubscribes |
| Callback argument | A table with `Data` (your payload) and `Sent` (Unix time in seconds when sent) |
| Studio | Behaviour in Studio playtests is not documented on the reference page (unverified); test real cross-server behaviour on live servers |

Open Cloud can also publish to live servers from outside Roblox (a website, a Discord bot, a live-ops console) and across experiences (see [[Open Cloud APIs]]).

### Reading the limits

- **The send limit is per server and generous**: an empty server can send 600 per minute (10 per second).
- **The receive limits are what bite.** Every server subscribed to a topic receives every message on it. A topic receives at most 40 + 80 x servers messages per minute in total. With 100 servers, that is 8,040 per minute for the topic, about 80 per minute per server's worth. If every server publishes "player count changed" each time a player joins, a big game exceeds the experience-wide limit and messages are dropped.
- **The subscription limit is low for empty servers**: a fresh server with 1 player may hold 28 subscriptions. Do not subscribe one topic per player or per item; use a few shared topics and route inside the payload.

Design rule: **publish rarely, to few topics, with small payloads.** Aggregate (one message per server every 30 to 60 seconds) rather than event-per-change.

## Use cases and the right tool

| Need | Tool | Why |
|---|---|---|
| "A player found a mythic item!" banner in all servers | MessagingService | Ephemeral, loss-tolerant, low volume |
| Admin announcement from one server or a dashboard | MessagingService (or Open Cloud publish) | Same |
| Global event start ("double luck for 15 minutes from 18:00") | **DataStore or MemoryStore config** plus a MessagingService nudge | Servers that miss the message or start later must still know; the message only makes it immediate |
| Server browser / list of servers and player counts | MemoryStore sorted map with expiry, updated every 30 to 60 s | State, not events; MessagingService cannot be queried |
| Matchmaking queue | MemoryStore queue | Needs atomic pops ([[MemoryStore Service]]) |
| Cross-server trading or gifting | DataStore (durable, transactional with `UpdateAsync`) | Must never be lost or duplicated |
| Global leaderboards | OrderedDataStore or MemoryStore sorted map | Queryable state ([[OrderedDataStores and Leaderboards]]) |
| Kicking a banned player from whatever server they are in | `Players:BanAsync` | The Ban API applies universe-wide without messaging |

Rule: **MessagingService carries notifications; state lives in a store.** Any message that changes state should be repeatable from the store, so a lost message delays the change instead of losing it.

## Payload design

- 1 kB is small. Send ids and numbers, not descriptions: `{k = "drop", u = userId, i = "mythic_07", s = "a1b2"}`.
- Include a **message id** for deduplication and a **version** if the schema may change during a rollout (old and new servers run side by side during updates).
- Include the **origin JobId** if receivers should ignore their own messages (the publishing server also receives what it publishes when subscribed).
- Use the callback's `Sent` time to discard stale messages (a "boss spawns now" message that arrives 30 seconds late should be ignored).
- Never include secrets: messages are visible to every server's code, which is fine, but do not include anything you would not want in logs.
- Text written by players (announcement text, custom names) must be **filtered on the server** with `TextService` before it is shown to other players. Filter for broadcast (`FilterStringAsync` then `GetNonChatStringForBroadcastAsync`) before publishing. One production game's admin "announce" did exactly that before showing a toast to everyone.

## A robust wrapper

```lua
--!strict
-- ServerScriptService/Shared/CrossServer.luau
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")

local CrossServer = {}

local TOPIC = "global_v1"      -- one shared topic; route by `k` inside the payload
local MAX_AGE = 20             -- seconds; ignore older messages
local DEDUPE_TTL = 120

type Envelope = { k: string, id: string, from: string, v: number, d: any }
type Handler = (data: any, sentAt: number, fromJob: string) -> ()

local handlers: { [string]: Handler } = {}
local seen: { [string]: number } = {}
local outbox: { Envelope } = {}

function CrossServer.on(kind: string, handler: Handler)
	handlers[kind] = handler
end

local function deliver(env: Envelope, sentAt: number)
	local h = handlers[env.k]
	if h then
		local ok, err = pcall(h, env.d, sentAt, env.from)
		if not ok then warn(("[CrossServer] handler %s: %s"):format(env.k, tostring(err))) end
	end
end

local function onMessage(message: { Data: any, Sent: number })
	local env = message.Data
	if type(env) ~= "table" or type(env.k) ~= "string" or type(env.id) ~= "string" then return end
	if os.time() - message.Sent > MAX_AGE then return end -- stale
	if seen[env.id] then return end                         -- duplicate
	seen[env.id] = os.time()
	if env.from == game.JobId then return end               -- our own; already applied locally
	deliver(env, message.Sent)
end

-- Publish with a retry; returns false if every attempt failed.
function CrossServer.publish(kind: string, data: any, alsoLocal: boolean?): boolean
	local env: Envelope = { k = kind, id = HttpService:GenerateGUID(false), from = game.JobId, v = 1, d = data }
	-- Rough size guard: the limit is 1 kB for the encoded message.
	local encoded = HttpService:JSONEncode(env)
	if #encoded > 900 then
		warn(("[CrossServer] %s payload too large (%d bytes)"):format(kind, #encoded))
		return false
	end
	seen[env.id] = os.time()
	if alsoLocal then deliver(env, os.time()) end

	for attempt = 1, 3 do
		local ok, err = pcall(MessagingService.PublishAsync, MessagingService, TOPIC, env)
		if ok then return true end
		warn(("[CrossServer] publish %s failed (%d): %s"):format(kind, attempt, tostring(err)))
		task.wait(attempt * 2)
	end
	return false
end

function CrossServer.start()
	task.spawn(function()
		for attempt = 1, 5 do
			local ok, err = pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, onMessage)
			if ok then return end
			warn(("[CrossServer] subscribe failed (%d): %s"):format(attempt, tostring(err)))
			task.wait(attempt * 3)
		end
	end)
	-- Forget old dedupe ids.
	task.spawn(function()
		while true do
			task.wait(30)
			local cutoff = os.time() - DEDUPE_TTL
			for id, t in seen do
				if t < cutoff then seen[id] = nil end
			end
		end
	end)
end

return CrossServer
```

Notes on the code:

- `JSONEncode` length is only an approximation of the service's own encoding; keep a margin below 1 kB.
- `alsoLocal` applies the message on the sending server immediately instead of waiting for the round trip, and dedupe prevents applying it twice.
- `RunService` is imported because many games skip MessagingService in Studio tests; add `if RunService:IsStudio() then ... end` paths if you need them.

## Pattern: a global event that survives missed messages

The wrong way: publish "start double luck" and have each server flip a flag on receipt. Servers that were starting, that missed the message, or that launch later never see the boost.

The right way:

1. Write the event to a store: `{ kind = "luck", mult = 2, startsAt = t0, endsAt = t1 }` in a DataStore key (durable) or a MemoryStore hash map (fast, with expiry).
2. Publish a small nudge: `{k = "config", key = "events"}`.
3. Every server re-reads the store on the nudge **and** on start-up **and** on a slow poll (every 60 s) as a safety net.
4. Effects are scheduled by absolute times (`startsAt`, `endsAt`), so every server agrees regardless of when it heard.

See [[Global State and Live Config]].

## Pattern: server presence and a server list

Servers write a small record to a MemoryStore sorted map keyed by `JobId` with a short expiry (for example 90 seconds), refreshed every 30 seconds: player count, place version, region, whether it is a reserved server. A lobby reads the map to show a server list or to pick a server for "join a friend's world". When a server dies, its key simply expires. MessagingService is not needed for this; it would only add load. Mind the MemoryStore request budget (1,000 + 120 x concurrent users request units per minute, experience-wide, Roblox docs).

## Pattern: cross-server announcements with filtering

```lua
--!strict
-- Server: an allowlisted admin broadcasts filtered text to every server.
local TextService = game:GetService("TextService")
local CrossServer = require(game.ServerScriptService.Shared.CrossServer)
local Toasts = require(game.ServerScriptService.Systems.Toasts) -- shows a toast to all players here

CrossServer.on("announce", function(data)
	if type(data) == "table" and type(data.text) == "string" and #data.text <= 200 then
		Toasts.all(data.text)
	end
end)

local function announce(admin: Player, rawText: string)
	if #rawText == 0 or #rawText > 200 then return end
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(rawText, admin.UserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		warn("Filtering failed; not announcing: " .. tostring(result))
		return -- never broadcast unfiltered text
	end
	CrossServer.publish("announce", { text = result }, true)
end

return announce
```

## Reliability checklist for messages

| Failure | Defence |
|---|---|
| Message dropped | State in a store; message is a nudge; periodic poll |
| Message duplicated | Message ids and a dedupe table |
| Message late | `Sent` timestamp; ignore stale; absolute times in payloads |
| Old and new server versions during an update | Version field; ignore unknown kinds; additive schema changes |
| Publish fails (throttle, outage) | `pcall`, bounded retries, log; do not block gameplay on it |
| Subscribe fails at start | Retry with backoff; poll the store meanwhile |
| Topic floods at scale | Aggregate per server per interval; fewer topics; MemoryStore for state |

## Testing

- Unit-test your handlers by calling them directly with fake envelopes; only live servers show real latency, limits and multi-server behaviour. Use a private test experience with several servers (or reserved servers) for load-style tests.
- Log publish failures and receive counts per minute; compare against the limits at your peak server count.

## Common mistakes

| Mistake | Fix |
|---|---|
| Using MessagingService as a database | Store state; message to notify |
| One topic per player or item | Few topics, route in payload |
| Publishing on every small change | Aggregate per server every 30 to 60 s |
| Broadcasting unfiltered player text | `TextService` broadcast filtering first |
| Assuming the sender does not receive its own message | Ignore own `JobId` or rely on dedupe |
| Gameplay waiting on `PublishAsync` | Spawn it; never block a remote handler on it |

## Checklist

- [ ] Every cross-server state change is recoverable from a store.
- [ ] Payloads under 1 kB with id, version and origin.
- [ ] Dedupe and staleness checks on receive.
- [ ] Publish and subscribe wrapped in `pcall` with backoff.
- [ ] Message volume estimated at peak server count against the receive limits.

## See also
[[MemoryStore Service]] · [[Global State and Live Config]] · [[Open Cloud APIs]] · [[Live Ops Events and Updates]] · [[Teleporting and Multi-Place Games]] · [[Server Lifecycle and Shutdown]] · [[Rate Limiting and Abuse Prevention]] · [[DataStore Fundamentals]]

## Nuances and edge cases

1. **Delivery is best effort.** Treat MessagingService delivery and ordering as not guaranteed (rule of thumb; the reference and guide pages, as of October 2026, state no delivery or ordering guarantee either way). Design every message so that losing it is survivable: the message says "something changed, go look", and the truth lives in a DataStore or MemoryStore that a server can re-read.
2. **Limits scale with the number of servers.** Publish and subscribe budgets depend on the number of servers and players (the limits table earlier in this note lists them). With 5 servers a per-server announcement every few seconds is fine; with 500 servers the same pattern multiplies receive volume by 500 on every server, because each server receives every other server's messages. Aggregate, throttle, and avoid "every server tells every server" patterns.
3. **Fan-in is cheaper than fan-out.** Presence lists where every server broadcasts its state are fine at small scale but grow with the square of server count in total traffic. A MemoryStore sorted map that each server writes to and reads periodically scales better for "list of servers".
4. **Receivers include the sender.** A server receives its own published messages (rule of thumb from practice; the docs pages do not state it). Ignore by `JobId` when that matters, or design handlers to be idempotent so a repeat is harmless.
5. **Clocks differ between servers.** Timestamps in messages come from each server's clock, which can be off by seconds. Do not order events by sender timestamps; use version numbers from a shared store.
6. **Studio does not represent production.** Messaging in Studio tests involves very few servers; behaviour at scale (throttling, delays, missed messages) only shows in live servers. Test the "message lost" path deliberately by dropping messages in a debug mode.
7. **Payload size forces indirection.** Payloads are size-limited (see the limits table), so large data (a full leaderboard, a config file) should be stored elsewhere and referenced by a key and version in the message.
8. **Moderation applies across servers.** Player text broadcast to other servers must be filtered for broadcast before sending, and admin commands sent cross-server must be authenticated (check the sender is an admin on the originating server, and treat the message topic as public within your experience).

The senior trade-off: cross-server features (global events, shouts, live config) add excitement but also a distributed system with partial failure. Keep cross-server features few, each with a clear fallback when messaging is down.

## Common mistakes (advanced)

1. **Relying on one message for a global event start.** Symptom: some servers never start the event. Fix: store the event schedule; message only to wake servers early, and have servers poll the schedule.
2. **Every server announcing presence every few seconds.** Symptom: throttling at peak hours. Fix: MemoryStore with expiry, refreshed every 30 to 60 seconds.
3. **Ordering by message timestamp.** Symptom: an older config overwrites a newer one. Fix: monotonically increasing version numbers.
4. **Admin commands accepted from any message.** Symptom: anyone who can publish (any server script, including compromised ones) can run admin actions. Fix: validate permissions at the source and keep an audit log.
5. **Subscribing inside per-player code.** Symptom: subscription count grows with players and hits limits. Fix: one subscription per topic per server.
6. **No retry on publish errors.** Symptom: rare missing announcements. Fix: retry with backoff, then log.

## Related decisions

- [[MemoryStore Service]]: the stateful partner to messaging.
- [[Server Browsers and Server Lists]]: presence lists done with MemoryStore.
- [[Global State and Live Config]]: config updates that use messages only as a wake-up.
- [[Live Ops Events and Updates]]: global events built on schedules plus messages.
- [[Matchmaking Queues with MemoryStore]]: queues where messages notify, stores decide.
- [[Logging Bans and Appeals]]: cross-server bans with auditability.
- [[Debugging Live Servers]]: testing cross-server paths in production.
- [[Server Shutdowns Soft Updates and Migration]]: telling servers to drain.

## Connected notes
<!-- auto-links:start -->
[[Live Content Pipeline]] · Links - Cross-server messaging · Multiplayer Services Start Here · Experience Notifications and Return Prompts · Debugging DataStore Problems · Parties and Group Teleports
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · [[Client-Server Model]] · [[Interest Management and Per-Player Replication]] · [[Replication Rules]] · [[Instance Streaming]] · [[Project Structure and Bootstrapping]] · [[Server Authority and Validation]]
<!-- related:end -->
