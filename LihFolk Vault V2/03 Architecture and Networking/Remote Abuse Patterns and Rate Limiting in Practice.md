---
tags: [security, remotes, rate-limiting, validation, exploits, networking, type/guide, area/networking, level/intermediate, api/DataStore, area/security, api/RemoteFunction]
---
# Remote Abuse Patterns and Rate Limiting in Practice

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Expensive lookup before the rate limit -> Rate limit first
> - Avoid: Range check without a finite check -> `math.isfinite(x)` (or `x == x`) first
> - Avoid: Payload `userId` used as identity -> Use the injected sender
> - Every remote goes through one guard: rate, shape, bounds, lock, act, score.
> - Numbers: finite, integral where needed, ranged.
> - Strings: length cap, valid UTF-8, membership in fixed sets for keys.
>
> Cost: TL;DR ~150 tok · whole note ~5.4k tok. Read more: ## 2. Abuse patterns by payload · ## 3. Abuse patterns by behaviour · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Rate Limiting and Abuse Prevention]] gives the algorithms (token bucket, sliding window, budgets) and production limits. [[Exploits and Anti-Cheat]] gives the threat model and the consequence ladder. [[Server Authority and Validation]] gives the validation layers. This note is the field guide that sits between them: the concrete shapes remote abuse takes, payload by payload, and a single guard layer that handles them in the right order. It also covers cost-weighted limits, re-entrancy (the race that validated code still loses), amplification, log flooding, shadow-mode tuning, and how to fuzz your own remotes before someone else does.

Engine facts are from the Roblox docs (as of October 2026). Everything marked rule of thumb is production practice.

---

## 1. The order of operations

Every remote handler should do these steps, in this order, before any game logic:

1. **Rate limit** (cheapest check, stops floods early).
2. **Shape check** (argument count and types, with no deep work).
3. **Bounds check** (NaN, infinity, ranges, string lengths, table sizes).
4. **Ownership and state** (does this player own this item, are they alive, in range, not stunned).
5. **Re-entrancy lock** for anything that yields or mutates value.
6. **Act**, then **respond**.
7. **Score** violations (counts, not logs) for the suspicion system.

Putting expensive work before step 1 is the most common mistake: a handler that looks up a profile or raycasts before rate limiting turns a flood into server CPU load.

One thing no handler can protect: **deserialisation**. The engine decodes the arguments before your handler runs. A client can send large tables, and that decoding cost is paid regardless of what you do next. The engine's own throttle (about 500 requests per second per client, shared across remotes of the same type, Roblox docs) bounds the rate; your design should keep payloads small so that legitimate decoding is cheap and huge payloads stand out.

---

## 2. Abuse patterns by payload

### 2.1 Type confusion

The client controls every argument after `player`. Anything sendable can arrive: `nil`, a table where you expect a number, an Instance where you expect a string, a deeply nested table where you expect a flat list. (Functions and threads cannot be sent, so at least those are off the list.)

```lua
-- Vulnerable: assumes amount is a number
remote.OnServerEvent:Connect(function(player, amount)
	if amount > 0 then ... end -- a table errors here; a string compares oddly or errors
end)
```

Errors in handlers are not a crash risk for the server (they kill only that handler thread), but they are a **log flood** risk and a sign the next step might be exploitable. Check types with `typeof`, not `type`, because `typeof` distinguishes Roblox types (`Vector3`, `Instance`, `CFrame`).

### 2.2 Numeric edge cases

| Value | How it breaks naive code | Check |
|---|---|---|
| `NaN` | Every comparison is false: `nan > max` and `nan < min` both false, so it passes range checks | `x ~= x` |
| `math.huge`, `-math.huge` | Passes `> 0`; multiplies into infinite currency | `math.abs(x) ~= math.huge` |
| Negative quantities | "Buy -10 swords" refunds money | `x >= 1` |
| Fractions | "Buy 0.5 of an item" for half price, rounding exploits | `x % 1 == 0` |
| Values beyond 2^53 | Integers stop being exact; `x + 1 == x` | Explicit maximum |
| `Vector3` with NaN or infinite components | Teleports parts to NaN, breaks physics for everyone near | Check each component (below) |

```lua
--!strict
local function isFiniteNumber(x: unknown): boolean
	return typeof(x) == "number" and x == x and math.abs(x) ~= math.huge
end

local function isCount(x: unknown, max: number): boolean
	return isFiniteNumber(x) and (x :: number) >= 1 and (x :: number) <= max and (x :: number) % 1 == 0
end

local function isFiniteVector(v: unknown, maxMagnitude: number): boolean
	if typeof(v) ~= "Vector3" then return false end
	local vec = v :: Vector3
	return isFiniteNumber(vec.X) and isFiniteNumber(vec.Y) and isFiniteNumber(vec.Z)
		and vec.Magnitude <= maxMagnitude
end
```

### 2.3 Strings

- **Length.** Cap every string. Item ids are short; chat-like text has a policy limit you choose. A 100 KB string sent to a handler that stores it in a profile becomes a DataStore problem later.
- **Encoding.** `utf8.len(s)` returns `nil` (plus a position) for invalid UTF-8. Reject invalid text before it reaches `TextService` filtering or a DataStore.
- **Lookup keys.** A client-chosen string used as a table key (`shop[itemId]`) is safe to read; it is dangerous to **write** (`stats[statName] = value` lets the client create any key, including ones your code later trusts). Always check membership in a fixed set.
- **User text must be filtered** on the server before other players see it ([[Roblox Policies Ratings and Compliance]]).

### 2.4 Tables

- **Size.** Count keys with an early exit; reject past a small limit.
- **Depth.** Nested tables cost recursion; reject past depth 2 or 3 for anything you walk.
- **Mixed keys.** Remote serialisation has rules (mixed array/dictionary tables lose data, non-string keys become strings, see [[Tables Metatables and OOP]]), so validate the shape you actually received, not the shape the honest client sends.

```lua
--!strict
-- Bounded shape check: refuses big or deep tables without walking all of them.
local function isSmallTable(t: unknown, maxKeys: number, maxDepth: number): boolean
	if typeof(t) ~= "table" then return false end
	if maxDepth <= 0 then return false end
	local n = 0
	for _, v in t :: { [any]: any } do
		n += 1
		if n > maxKeys then return false end
		if typeof(v) == "table" and not isSmallTable(v, maxKeys, maxDepth - 1) then
			return false
		end
	end
	return true
end
```

### 2.5 Instances as arguments

An Instance argument is a reference to something that exists on the server (an Instance created only on the client arrives as `nil`). The client can send **any** server-replicated instance: another player's tool, a part in a different zone, a part of your map.

Checks: `typeof(x) == "Instance"`, the expected class (`x:IsA("Model")`), and **membership** (`x:IsDescendantOf(expectedFolder)`, or better, look it up in your own registry by id). Prefer sending ids and resolving them on the server; it removes a whole class of "pass a different instance" exploits ([[Server Authority and Validation]]).

### 2.6 The fake player field

The first argument of `OnServerEvent` is always the real sender. Any "player" or "userId" inside the payload is client-written. Code that does `remote.OnServerEvent:Connect(function(_, targetPlayer, amount) giveCoins(targetPlayer, amount) end)` lets anyone pay anyone. Use the injected sender for identity; treat payload players only as targets that must pass permission checks.

---

## 3. Abuse patterns by behaviour

### 3.1 Races and re-entrancy

A handler that **yields** between check and write can be entered again by a second request in between:

```lua
-- Vulnerable: two requests both pass the check before either writes
remote.OnServerEvent:Connect(function(player, itemId)
	if not owns(player, itemId) then return end
	local price = getMarketPrice(itemId) -- yields (DataStore, HTTP, MemoryStore)
	removeItem(player, itemId)
	addCoins(player, price)
end)
```

Two requests in the same frame both pass `owns`, both yield, both remove (the second removal fails silently) and both pay: a duplication exploit. Fixes:

- **Do not yield between check and write.** Fetch prices before, or from a cache.
- **Lock per player per action** for flows that must yield:

```lua
--!strict
local busy: { [Player]: { [string]: boolean } } = {}

local function withLock(player: Player, key: string, fn: () -> ()): boolean
	local mine = busy[player]
	if not mine then
		mine = {}
		busy[player] = mine
	end
	if mine[key] then return false end
	mine[key] = true
	local ok, err = pcall(fn)
	mine[key] = nil -- always release, even on error
	if not ok then warn(`[Lock] {key}: {err}`) end
	return ok
end

Players.PlayerRemoving:Connect(function(p) busy[p] = nil end)
```

- **Mutate first, then do slow work.** Remove the item, then compute and grant; if granting fails, restore. The window becomes "item gone and not yet paid", which is recoverable, instead of "paid twice", which is not.

See [[Trading Systems Without Duplication]] for the multi-player version of this problem.

### 3.2 Amplification

One client request that causes the server to `FireAllClients` is an **amplifier**: 10 requests per second with 30 players becomes 300 outgoing messages per second. Emotes, effect relays, ping markers and chat-like features are typical.

- Rate-limit amplifying remotes much more tightly than private ones.
- Fire only to clients that can see the effect ([[Interest Management and Per-Player Replication]]).
- Coalesce: one broadcast per tick containing all relays, not one per request.
- Cap per area on the receiving side: clients ignore more than N of the same effect per second.

### 3.3 Expensive requests

Some requests are legitimate but expensive: pathfinding requests, DataStore reads (leaderboard page for a user), raycasts against complex geometry, inventory sorting of thousands of items. A plain "requests per second" limit treats a cheap ping and an expensive search the same. Use **cost-weighted** buckets: each request spends tokens proportional to its cost.

```lua
--!strict
-- Cost-weighted token bucket per player. Costs are in arbitrary "work units".
type Bucket = { tokens: number, last: number }
local CAPACITY, REFILL = 20, 10 -- burst 20 units, 10 units per second
local buckets: { [Player]: Bucket } = {}

local COST = {
	ping = 1,
	equip = 2,
	sortInventory = 5,
	findPath = 8,
	fetchLeaderboardPage = 10,
}

local function spend(player: Player, action: string): boolean
	local cost = COST[action]
	if not cost then return false end -- unknown actions are rejected, not free
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = CAPACITY, last = now }
		buckets[player] = b
	end
	b.tokens = math.min(CAPACITY, b.tokens + (now - b.last) * REFILL)
	b.last = now
	if b.tokens < cost then return false end
	b.tokens -= cost
	return true
end

Players.PlayerRemoving:Connect(function(p) buckets[p] = nil end)
```

Combine with server-wide budgets for backend services ([[Rate Limiting and Abuse Prevention]]): per-player limits stop one player; server budgets stop 30 players each staying just under their limit.

### 3.4 State exhaustion

Any per-request state you keep is memory an attacker can make you allocate. Watch for:

- Rate limiters keyed by a **client-supplied** string (`limiter:allow(player, itemId)` with arbitrary `itemId`): each new string creates a bucket. Key only by fixed, server-known action names.
- Idempotency token caches without expiry or size caps.
- "Pending request" tables that are only cleared on a response the client never sends.

Cap every per-player table size and clear on `PlayerRemoving`.

### 3.5 Log and telemetry flooding

`warn` on every rejected request lets an attacker fill your logs, hide real errors and spend server time formatting strings. Count rejections per player and reason; log a summary at most once per interval; report aggregates to telemetry ([[Error Handling - pcall xpcall and Promise Patterns]], fingerprinting).

### 3.6 Remote enumeration and probing

Exploit tools list every remote and fire each with guessed arguments. Assume every remote is known. Consequences:

- **Studio-only or debug remotes must not exist in live servers**, or must check `RunService:IsStudio()` and an allowlist on the server ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]).
- **[[Honeypots|Honeypot]] remotes** (a remote no honest client ever fires) detect probing. A hit is a strong signal for the suspicion score ([[Exploits and Anti-Cheat]]).
- Names do not matter for security. Obfuscated names only slow you down.

### 3.7 RemoteFunction abuse

- **Client to server invoke**: an exploiter can invoke as fast as the throttle allows, and each invoke may hold server work open. Rate limit as with events.
- **Server to client invoke** (`InvokeClient`): the client can never answer, answer garbage, or error. The server thread waits indefinitely. Never use it with untrusted clients; use an event pair with a timeout instead ([[Error Handling and Retries]]).

### 3.8 Physics-side "remotes"

`Touched`, `ProximityPrompt.Triggered` and `ClickDetector.MouseClick` are also client-driven entry points. A client-owned character can touch any part it can reach, at any rate, and teleport-touch parts far away. Apply the same guard: rate limit per player, distance check against the server's view, state check ([[Network Ownership]]).

---

## 4. One guard layer for every remote

Handlers forget checks. A wrapper that every remote goes through cannot forget. A compact version:

```lua
--!strict
-- ServerScriptService/Net/Guard.luau
local Players = game:GetService("Players")

export type Spec = {
	name: string,
	rate: number,            -- sustained per second
	burst: number,
	check: (...any) -> boolean, -- shape and bounds; no yields, no side effects
	handler: (Player, ...any) -> (),
	lockKey: string?,        -- set for handlers that yield or move value
}

type Bucket = { tokens: number, last: number }

local buckets: { [Player]: { [string]: Bucket } } = {}
local busy: { [Player]: { [string]: boolean } } = {}
local violations: { [Player]: { [string]: number } } = {}

local function note(player: Player, reason: string)
	local v = violations[player]
	if not v then
		v = {}
		violations[player] = v
	end
	v[reason] = (v[reason] or 0) + 1
end

local function allow(player: Player, spec: Spec): boolean
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local now = os.clock()
	local b = mine[spec.name]
	if not b then
		b = { tokens = spec.burst, last = now }
		mine[spec.name] = b
	else
		b.tokens = math.min(spec.burst, b.tokens + (now - b.last) * spec.rate)
		b.last = now
	end
	if b.tokens < 1 then return false end
	b.tokens -= 1
	return true
end

local Guard = {}

function Guard.bind(remote: RemoteEvent, spec: Spec)
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if not allow(player, spec) then
			note(player, spec.name .. ":rate")
			return
		end
		if select("#", ...) > 8 or not spec.check(...) then
			note(player, spec.name .. ":shape")
			return
		end
		local key = spec.lockKey
		if key then
			local mine = busy[player]
			if not mine then
				mine = {}
				busy[player] = mine
			end
			if mine[key] then
				note(player, spec.name .. ":reentry")
				return
			end
			mine[key] = true
			local ok, err = pcall(spec.handler, player, ...)
			mine[key] = nil
			if not ok then warn(`[Guard] {spec.name}: {err}`) end
		else
			spec.handler(player, ...)
		end
	end)
end

function Guard.violations(player: Player): { [string]: number }
	return violations[player] or {}
end

Players.PlayerRemoving:Connect(function(p)
	buckets[p] = nil
	busy[p] = nil
	violations[p] = nil
end)

return Guard
```

Usage:

```lua
Guard.bind(Remotes.SellItem, {
	name = "SellItem",
	rate = 2, burst = 4,
	lockKey = "inventory", -- shared with other inventory-moving remotes
	check = function(itemId: unknown, count: unknown)
		return typeof(itemId) == "string" and #itemId <= 32 and isCount(count, 99)
	end,
	handler = function(player: Player, itemId: string, count: number)
		Inventory.sell(player, itemId, count) -- ownership and state checks inside
	end,
})
```

Design points:

- **`check` is pure.** No yields and no side effects, so it can run before the lock and cannot be raced.
- **Lock keys are shared** by remotes that touch the same value (sell, trade, craft all use `"inventory"`), so they cannot interleave.
- **Violations are counts**, readable by the anti-cheat system on its own schedule. The guard never kicks.
- **Unknown argument counts** are rejected (`select("#", ...) > 8`), which stops some fuzzing noise cheaply.

---

## 5. Tuning limits without hurting players: shadow mode

Limits set by guesswork either let abuse through or reject honest players on bad connections. Tune with data:

1. **Ship in shadow mode.** The guard computes "would reject" but lets the request through, and records per remote the rate distribution per player.
2. **Collect a week** across devices. Look at the 99th and 99.9th percentile of honest players' per-second rates per remote.
3. **Set limits** at roughly 1.5x to 2x the 99.9th percentile (rule of thumb, consistent with [[Rate Limiting and Abuse Prevention]]), with bursts sized to the largest honest burst (reconnect flushes after a lag spike are the usual maximum).
4. **Enforce**, keep recording, and alert when the honest rejection rate exceeds about 0.1% of requests (rule of thumb).

Mobile is where honest players look like attackers: a stalled connection delivers several seconds of queued inputs in one burst. Size bursts for that, or make actions idempotent so bursts are harmless.

---

## 6. Fuzz your own remotes

Before release, run a gated test script in a private test server or Studio that fires every remote with hostile inputs, then check the server is healthy:

```lua
--!strict
-- Client-side fuzzer for TEST builds only. Never ship it in a live place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local nan = 0 / 0
-- nil cannot live in an array, so missing arguments are covered by the zero-argument fire below
local samples: { any } = {
	true, 0, -1, 0.5, nan, math.huge, -math.huge, 2 ^ 60,
	"", string.rep("x", 10000), "\255\254",
	{}, { 1, 2, 3 }, { a = { b = { c = { d = {} } } } },
	Vector3.new(nan, 0, 0), Vector3.new(1e9, 1e9, 1e9), CFrame.new(),
	workspace, game:GetService("Players").LocalPlayer,
}

for _, remote in ReplicatedStorage:GetDescendants() do
	if remote:IsA("RemoteEvent") then
		remote:FireServer() -- no arguments at all
		for _, a in samples do
			for _, b in samples do
				remote:FireServer(a, b)
			end
			task.wait() -- stay well inside the engine throttle
		end
	end
end
print("fuzz done")
```

What to look for on the server afterwards: errors in Output (each one is a missing check), value changes on the test profile (currency, items), parts moved to NaN or huge positions, memory growth in the Developer Console, and log volume. The goal is zero server errors and zero state change from garbage.

---

## Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Expensive lookup before the rate limit | Floods become CPU load | Rate limit first |
| Range check without a finite check | NaN is a `number` and fails every comparison, so it passes range checks | `math.isfinite(x)` (or `x == x`) first |
| Payload `userId` used as identity | Pay or harm any player | Use the injected sender |
| Yield between check and write | Duplication | Lock, or mutate first |
| Broadcasting relays per request | Amplification to all clients | Interest filter, coalesce, tight limit |
| Limiter keyed by client strings | Memory exhaustion | Fixed action keys |
| `warn` per rejected request | Log flooding | Counted violations, periodic summary |
| Kicking on a single violation | False positives on bad connections | Scores and the consequence ladder |
| Debug remotes in live servers | Free admin powers | Studio gate + allowlist, or remove |

## Checklist

- [ ] Every remote goes through one guard: rate, shape, bounds, lock, act, score.
- [ ] Numbers: finite, integral where needed, ranged. Vectors: finite components, magnitude cap.
- [ ] Strings: length cap, valid UTF-8, membership in fixed sets for keys.
- [ ] Tables: key count and depth caps. Instances: class plus membership, or ids instead.
- [ ] No yields between check and write on value-moving handlers; shared lock keys.
- [ ] Amplifying remotes tightly limited and interest-filtered.
- [ ] Expensive actions use cost-weighted limits plus server-wide budgets.
- [ ] All per-player tables capped and cleared on leave.
- [ ] Limits tuned from shadow-mode data; honest rejection rate monitored.
- [ ] Fuzzed before release with zero server errors and zero state change.

## See also

[[Rate Limiting and Abuse Prevention]] · [[Exploits and Anti-Cheat]] · [[Server Authority and Validation]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Network Ownership]] · [[Trading Systems Without Duplication]] · [[Interest Management and Per-Player Replication]] · [[Error Handling - pcall xpcall and Promise Patterns]] · [[Multi-Client and Live Testing]] · [[QA Checklists Before Release]]

## Connected notes
<!-- auto-links:start -->
[[Cookbook - Remotes and Networking]] · Skill - Roblox Secure Remotes · Testing Your Own Remotes - Fuzzing and Abuse Tests · Rate Limiting · How Exploits Work - The Client Boundary · Anti-Exploit Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[AI Pitfalls - Networking and Security]] · [[Testing Your Own Remotes - Fuzzing and Abuse Tests]] · [[Client-Server Model]] · [[Client Prediction and Reconciliation for Combat]] · [[Replication Rules]] · [[Snapshot Interpolation for Custom Replication]] · [[Cross-Server Messaging]]
<!-- related:end -->
