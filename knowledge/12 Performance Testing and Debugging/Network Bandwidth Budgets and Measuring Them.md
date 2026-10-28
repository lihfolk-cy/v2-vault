---
tags: [performance, networking, bandwidth, budgets, remotes, replication, measurement]
---
# Network Bandwidth Budgets and Measuring Them

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Trusting the "50 KB/s per client" folklore as a hard limit.
> - Avoid: Measuring with 2 clients and shipping to 30-player servers.
> - Avoid: Looking for per-remote stats in the Developer Console Network tab (it shows web calls).
> - A per-player budget per category, each row with an owner.
> - Fan-out arithmetic done for every broadcast at full server size.
> - Top talkers measured (A/B or instrumented remotes).
>
> Read more (18 KB note): ## 3. The fan-out arithmetic · ## 4. Measuring per system · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Network Performance]] lists the tools and the traffic-cutting patterns. This note is about numbers: how to set a bandwidth budget per player, how to find out what each system actually costs, and how to keep the total inside the budget as the game grows. The theme is that you cannot manage what you only feel. "The game is laggy on phones" becomes fixable when you can say "combat sends 38 kbps per player at 20 players, and the budget is 25".

---

## 1. What Roblox gives you, and what it does not

Facts (Roblox docs, as of October 2026):
- `Stats.DataSendKbps` and `Stats.DataReceiveKbps` give live data rates on the side that reads them. `Stats.PhysicsSendKbps` and `Stats.PhysicsReceiveKbps` give physics replication rates.
- The Performance Stats bar shows network data sent and received and ping; Shift+F3 shows per-client data ping; the Developer Console Server Stats tab shows average data ping.
- The Developer Console's **Network** tab is about web calls (`HttpService`, DataStore requests), not remotes. It does not show per-remote traffic.
- Studio Settings, Network, **Print Join Size Breakdown** lists the top 20 instances by size in the join payload.
- `RemoteEvent` and `UnreliableRemoteEvent` client-to-server calls are throttled at roughly **500 requests per second per client**, shared across all remotes of the same type.
- `UnreliableRemoteEvent` payloads over **1000 bytes are dropped**.

What Roblox does **not** publish:
- A per-player bandwidth cap. A "50 KB/s per client" figure circulates on the DevForum; its own authors say they could not find documentation for it. Treat it as folklore.
- The exact wire encoding and per-type byte cost of remote arguments. Any byte table you see (including the estimates below) is an approximation. Measure.
- Per-remote statistics. You have to build them (section 4).

---

## 2. Setting a budget

A budget is a ceiling per player for each direction, split across categories. Start from the weakest connection you want to support and work backwards.

Rule of thumb for the target: a phone on a congested mobile connection should not need more than a few dozen kbps of steady game data, and bursts on common actions should stay in the tens of KB, not hundreds. Players on good connections never notice a budget; players on bad ones notice every overshoot as rubber-banding and delayed hits.

A worked budget for a 20-player action game, server to each client:

| Category | Budget (kbps per player) | Notes |
|---|---|---|
| Character movement (engine) | 8 to 12 | Engine-managed; grows with nearby moving players |
| Physics of unanchored world objects | 0 to 4 | Zero is achievable if props are anchored |
| Combat remotes (hits, effects, damage numbers) | 6 | The main thing you control |
| Enemy state (attributes, position updates) | 5 | Scales with enemies near the player |
| UI and economy updates | 1 | Currency, quests, notifications |
| Headroom | 6 | For bursts and growth |
| **Total** | **about 30** | |

And the one-time costs, separately:

| One-time | Budget | Notes |
|---|---|---|
| Join payload | as small as you can; measure with Print Join Size Breakdown | See [[Case Study - Fast Join and Deferred Loading]] |
| Zone or content load | spread over seconds, not one burst | Stream it, or send in chunks |

The numbers above are a starting point, not a standard. The value of the table is that each row has an owner and a number, so a new feature has to say which row it comes out of.

Client to server matters less for bandwidth (clients send mostly input) but matters a lot for the **request rate** limit. A client firing a remote every frame at 60 fps uses 60 of the roughly 500 requests per second. Three systems doing that leave little room, and the throttle drops requests without telling you which system lost.

---

## 3. The fan-out arithmetic

Most bandwidth disasters are multiplication errors. Three shapes to recognise:

**Broadcast of per-player events.** Each of N players causes an event that goes to all N players. Server outbound is N x N messages. At 10 players and 5 events per second each, that is 500 messages per second. At 30 players, 4,500. Per player it grows linearly (each client receives N x 5), so it looks fine in a 4-player test and breaks at full servers.

**Server-side property animation.** Tweening a replicated property on the server sends an update every frame to every client that has the instance. One tweened door is nothing; a hundred spinning coins tweened on the server at 60 Hz is a steady stream for no gameplay reason. Animate on the client ([[Network Performance]]).

**Per-frame attribute writes.** Writing an attribute or a `ValueBase` every Heartbeat on the server replicates on every write that changes the value. A health value that regenerates by 0.1 per frame on 30 enemies is 1,800 replicated changes per second. Quantise and rate-limit: replicate when the value changes by a meaningful step, or at most a few times per second.

Do the arithmetic at design time:

```
messages per second to one client = (sources visible to that client) x (rate per source)
bytes per second to one client     = messages per second x (payload + per-message overhead)
```

Per-message overhead is unpublished. Rule of thumb: many tiny messages cost more than one batched message with the same content, so batching wins even before compression.

### Worked example: enemy positions

Suppose the server sends custom position updates for enemies near each player (because the enemies are server-moved, anchored models, not physics).

- 40 enemies within range, 10 updates per second each = 400 updates per second per client.
- Naive payload: an id string of 8 characters plus a `Vector3` plus a yaw number. Call it about 30 bytes before overhead (estimate).
- 400 x 30 bytes = 12,000 bytes per second = **96 kbps** per client. Far over the 5 kbps row.

Fixes, applied in order:
1. **Interest tiers**: full rate within 60 studs, a quarter of the rate within 150, nothing beyond. Typical distribution (rule of thumb): 8 close, 12 mid, 20 far. Updates per second: 8 x 10 + 12 x 2.5 = 110.
2. **Send on change**: idle enemies do not move. If half are idle, 55 updates per second.
3. **Batch into one message per tick** with integer ids and quantised values in a `buffer` (below): about 8 bytes per enemy.
4. Result: 55 x 8 = 440 bytes per second = **3.5 kbps**. Inside the budget, with a single remote call per tick instead of 55.

The reference project used the same family of ideas for character animation replication (measured): local animation tracks were batched and throttled through one remote to a server relay; speed changes were sent at once when they changed by 6% or more, otherwise at most every 0.25 seconds. Enemy animation state went over replicated attributes (a handful of short values per enemy), and the heavy data, compiled animation clips of 19 to 235 KB per enemy kit and about 1.6 MB in total, was streamed **once per client** over a dedicated remote and prefetched by zone. That last point is the important budget lesson: big data is fine as a one-time, spread-out cost; it is never fine as a steady stream.

---

## 4. Measuring per system

### Method 1: controlled A/B on the rate counters

`Stats.DataSendKbps` is a total. You can still attribute it by switching one thing at a time.

1. Start a Server & Clients test with the number of clients you care about ([[Testing Modes - Play Run and Multi-Client]]).
2. Hold the game in a fixed state (everyone standing in the same place).
3. Read the server's `DataSendKbps` for 30 seconds: that is the baseline.
4. Turn on one system (or trigger one action at a fixed rate) and read again.
5. The difference, divided by the clients and the rate, is that system's cost per player per action.

```lua
--!strict
-- Server: average the send rate over a window. Call before and after a change.
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")

local function averageSendKbps(seconds: number): (number, number)
	local total, n = 0, 0
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		task.wait(0.5)
		total += Stats.DataSendKbps
		n += 1
	end
	local avg = total / math.max(n, 1)
	return avg, avg / math.max(#Players:GetPlayers(), 1)
end

local base, basePer = averageSendKbps(30)
-- ... enable the system under test here ...
local with, withPer = averageSendKbps(30)
print(string.format("system adds %.1f kbps total, %.2f kbps per player", with - base, withPer - basePer))
```

Caveats: Studio clients on the same machine share a loopback connection, so absolute numbers are cleaner than real life but the *differences* are what you want. Run long enough to smooth noise (30 seconds or more per reading). Use the Network Simulator for latency and loss, not for bandwidth measurement.

### Method 2: an instrumented remote layer

If every remote in your game goes through one module ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]), you can count calls and estimate bytes per remote name. The byte estimate is approximate, but ranking is what matters: it finds the top talker immediately.

```lua
--!strict
-- NetStats: wraps server-to-client sends and keeps per-remote counters.
-- Byte sizes are ESTIMATES for ranking, not wire-exact numbers.
local NetStats = {}

type Counter = { calls: number, bytes: number }
local counters: { [string]: Counter } = {}

local function estimate(value: any, depth: number): number
	if depth > 8 then
		return 0
	end
	local t = typeof(value)
	if t == "nil" or t == "boolean" then
		return 1
	elseif t == "number" then
		return 8
	elseif t == "string" then
		return #value + 2
	elseif t == "buffer" then
		return buffer.len(value) + 2
	elseif t == "Vector3" then
		return 12
	elseif t == "CFrame" then
		return 24 -- position plus a compact rotation, rough
	elseif t == "Instance" then
		return 4 -- sent as a reference, rough
	elseif t == "table" then
		local n = 2
		for k, v in value do
			n += estimate(k, depth + 1) + estimate(v, depth + 1)
		end
		return n
	end
	return 8
end

local function record(name: string, recipients: number, ...: any)
	local size = 0
	for i = 1, select("#", ...) do
		size += estimate((select(i, ...)), 0)
	end
	local c = counters[name]
	if not c then
		c = { calls = 0, bytes = 0 }
		counters[name] = c
	end
	c.calls += recipients
	c.bytes += size * recipients
end

function NetStats.fireClient(remote: RemoteEvent | UnreliableRemoteEvent, player: Player, ...: any)
	record(remote.Name, 1, ...)
	(remote :: any):FireClient(player, ...) -- both remote types share this method
end

function NetStats.fireAll(remote: RemoteEvent | UnreliableRemoteEvent, playerCount: number, ...: any)
	record(remote.Name, playerCount, ...)
	(remote :: any):FireAllClients(...)
end

-- Print the top talkers every interval, then reset.
function NetStats.report(interval: number)
	task.spawn(function()
		while true do
			task.wait(interval)
			local rows = {}
			for name, c in counters do
				table.insert(rows, { name = name, kbps = c.bytes * 8 / 1000 / interval, calls = c.calls / interval })
			end
			table.sort(rows, function(a, b)
				return a.kbps > b.kbps
			end)
			for i = 1, math.min(5, #rows) do
				local r = rows[i]
				print(string.format("[net] %-24s %6.1f kbps est, %6.1f msgs/s", r.name, r.kbps, r.calls))
			end
			table.clear(counters)
		end
	end)
end

return NetStats
```

Use it in development and in a test place; leave it off (or sampling 1 in 100 calls) in production, since the size walk costs CPU.

### Method 3: the MicroProfiler

When data ping is far above network ping, open a server MicroProfiler dump and look at the outgoing replication labels ([[MicroProfiler Guide]]). This shows *that* the server is struggling to send, and when; methods 1 and 2 tell you *what* it is sending.

### Method 4: join payload

Studio's Print Join Size Breakdown names the 20 largest instances in the join snapshot. Typical offenders: big folders of templates in ReplicatedStorage that clients only need later, archive folders that should not be in the place at all, and unanchored models. The reference project's measured case: ReplicatedStorage held about 600,000 instances at one point, dominated by animation data that every client downloaded on join; after earlier cleanups, baking that data into compact buffers took it from about 392,000 to about 107,000, and later under 70,000 ([[Case Study - Cutting a Million Instances]]).

---

## 5. Making messages small

Once you know the top talker, shrink it. In order of payoff:

1. **Do not send it.** Can the client compute it? Cosmetic effects should be derived on the client from one "this happened" event, not described in detail by the server.
2. **Send less often.** Change thresholds and rate caps.
3. **Send to fewer people.** `FireClient` to players in range instead of `FireAllClients`.
4. **Batch.** One message per tick containing every update.
5. **Pack.** Replace tables of strings and floats with a `buffer` of fixed-size fields ([[Buffers and Binary Data]]).

A packed batch of enemy positions:

```lua
--!strict
-- Pack (id, position, yaw) for many enemies into one buffer.
-- Layout per enemy: u16 id, i16 x, i16 y, i16 z (quarter-stud precision), u8 yaw = 9 bytes.
local SCALE = 4 -- quarter-stud steps: range about +-8191 studs

local function packEnemies(list: { { id: number, pos: Vector3, yaw: number } }): buffer
	local b = buffer.create(#list * 9)
	local o = 0
	for _, e in list do
		buffer.writeu16(b, o, e.id)
		buffer.writei16(b, o + 2, math.clamp(math.round(e.pos.X * SCALE), -32768, 32767))
		buffer.writei16(b, o + 4, math.clamp(math.round(e.pos.Y * SCALE), -32768, 32767))
		buffer.writei16(b, o + 6, math.clamp(math.round(e.pos.Z * SCALE), -32768, 32767))
		-- yaw in radians to 0..255
		buffer.writeu8(b, o + 8, math.round((e.yaw % (2 * math.pi)) / (2 * math.pi) * 255))
		o += 9
	end
	return b
end

local function unpackEnemies(b: buffer, onEnemy: (id: number, pos: Vector3, yaw: number) -> ())
	for o = 0, buffer.len(b) - 9, 9 do
		local id = buffer.readu16(b, o)
		local pos = Vector3.new(
			buffer.readi16(b, o + 2) / SCALE,
			buffer.readi16(b, o + 4) / SCALE,
			buffer.readi16(b, o + 6) / SCALE
		)
		local yaw = buffer.readu8(b, o + 8) / 255 * 2 * math.pi
		onEnemy(id, pos, yaw)
	end
end
```

Edge cases:
- **Range.** Quarter-stud precision in an `i16` covers about plus or minus 8,191 studs. Large maps need a coarser scale, a region offset, or 24-bit fields. Check your world's extents before choosing.
- **The 1000-byte unreliable limit.** At 9 bytes per enemy, about 110 enemies fit in one unreliable message. Split larger batches into several messages, each under about 900 bytes to leave room for any overhead (rule of thumb; the docs give the limit, not the overhead).
- **Reliable or unreliable.** Position streams that are replaced by the next update belong on `UnreliableRemoteEvent`: a lost packet is corrected 100 ms later. State changes that must arrive (death, loot, currency) belong on reliable remotes.
- **Quantisation shows.** Quarter-stud steps are invisible on a moving enemy if the client interpolates; they are visible on a slowly creeping one. Interpolate on the client between updates.

---

## 6. Physics replication

Physics traffic (`PhysicsSendKbps`) comes from unanchored parts the server owns or relays. Patterns that blow the budget:

- Hundreds of loose props that players knock around. Each moving assembly replicates.
- Debris from explosions left unanchored for many seconds.
- Server-owned NPCs built from physics assemblies when an anchored, script-moved model would do.

Measure with the same A/B method, reading the physics counters. Fixes: anchor props that do not need physics, make debris client-only, shorten debris lifetimes, and choose network ownership deliberately ([[Network Ownership]], [[Physics Performance]]).

---

## 7. Keep the budget alive

A budget measured once is out of date after the next update. Three habits keep it real:

1. **A budget table in the docs** with an owner per row ([[Documentation and Knowledge Bases]]).
2. **A per-release measurement.** Run the A/B probe with 8 Studio clients and record total kbps per player in the release notes. A jump from 22 to 35 between releases is caught before players feel it.
3. **Live sampling.** Log `DataSendKbps` divided by player count once a minute on a small fraction of servers, as an analytics custom event. Plot the median and the 95th percentile by player count. If the 95th percentile at full servers climbs, something scales badly.

---

## When not to optimise

- Below about 10 kbps per player for a system, packing and batching rarely pay for the code complexity (rule of thumb).
- Rare events (a purchase, a level up) can use readable tables. Clarity beats bytes there.
- If data ping equals network ping and players do not complain, your budget is fine. Do not shave bytes for their own sake.

---

## Common mistakes

- Trusting the "50 KB/s per client" folklore as a hard limit.
- Measuring with 2 clients and shipping to 30-player servers.
- Looking for per-remote stats in the Developer Console Network tab (it shows web calls).
- Batching unreliable data past 1000 bytes, so every batch is silently dropped.
- Using `FireAllClients` for things only nearby players can see.
- Replicating server-side tweens and per-frame attribute writes.
- Sending the same large data on every zone entry instead of once per session.
- Treating estimated byte counts as exact.

## Checklist

- [ ] A per-player budget per category, each row with an owner.
- [ ] Fan-out arithmetic done for every broadcast at full server size.
- [ ] Top talkers measured (A/B or instrumented remotes).
- [ ] Position-like streams on unreliable remotes, batched under 1000 bytes.
- [ ] Interest tiers by distance for anything per-entity.
- [ ] Join payload checked with Print Join Size Breakdown.
- [ ] Physics props anchored unless they need to move.
- [ ] Total kbps per player recorded per release.

## See also

[[Network Performance]], [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Buffers and Binary Data]], [[Replication Rules]], [[Network Ownership]], [[Instance Streaming]], [[Physics Performance]], [[MicroProfiler Guide]], [[Developer Console and Stats]], [[Case Study - Fast Join and Deferred Loading]], [[Mobile and Low-End Optimization]], [[Rate Limiting and Abuse Prevention]]

## Connected notes
<!-- auto-links:start -->
[[Interest Management and Per-Player Replication]] · [[Cookbook - Remotes and Networking]] · [[Skill - Roblox Performance Audit]] · [[Replication Boundary]] · [[2D Multiplayer - Server Authority and Replicating GUI Worlds]] · [[Serialization Formats for Saves and Networking]]
<!-- auto-links:end -->
