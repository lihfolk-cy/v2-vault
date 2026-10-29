---
tags: [security, rate-limiting, networking, performance, abuse, type/guide, area/networking, level/intermediate, api/DataStore, area/security, api/PlayerRemoving, api/HttpService]
---
# Rate Limiting and Abuse Prevention

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Rate limit after expensive parsing or DataStore calls -> Rate limit first
> - Avoid: One global cooldown table keyed by player name -> Key by `Player` (or `UserId`), clear on leave
> - Avoid: Kicking on rate-limit hits -> Log and score; drop the request
> - Every client-triggerable entry point has a per-player limit as its first statement.
> - Limits are 1.5x to 2x the fastest legitimate use, with logged rejections.
> - Backend calls go through server-wide budgets.
>
> Cost: TL;DR ~160 tok · whole note ~4.6k tok. Read more: ## A reusable rate limiter · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Any server logic a client can trigger (remotes, Touched, ProximityPrompts, ClickDetectors, chat, trade requests) can be triggered faster than you planned: by exploiters on purpose, by auto-clickers, by a buggy client loop, or by an honest player mashing a button on a laggy connection. Rate limiting decides how often each action may run, protects the economy from timing exploits, and protects the server (and Roblox's backend services) from overload. This note covers the algorithms, how to choose limits, the engine's own limits you must stay under, coalescing and idempotency, cleanup, and production numbers.

## Why the engine's throttle is not enough

Roblox throttles client-to-server remotes at about **500 requests per second per client**, shared across all remotes of the same type (Roblox docs, `RemoteEvent` "Throttling"). Over the limit, RemoteEvents are **delayed** (queued, order kept) and UnreliableRemoteEvents are **dropped**. That protects Roblox's servers, not your game: 500 "buy" or "cast" requests a second is several hundred more than any honest player sends. Your own per-action limits sit far below it.

There is also an honest-player reason: because the budget is shared, a client loop firing a reliable remote every frame delays every other reliable remote from that client. Rate-limit your own client code too.

## Cooldown vs rate limit

They are different tools and you usually need both:

| Tool | Question | Lives in | Example |
|---|---|---|---|
| **Cooldown** | Is this game action available yet? | Game rules, saved or session state | "Fireball recharges in 6 s"; "Daily chest every 20 h" |
| **Rate limit** | Is this client sending too many requests? | Transport layer, per player per remote | "No more than 5 cast requests per second" |

A cooldown rejection is a normal outcome (show a timer). A rate-limit rejection is abnormal (drop silently, maybe log). Honest clients should almost never hit a rate limit; set limits a comfortable margin above the fastest legitimate use.

## Algorithms

| Algorithm | Behaviour | Good for |
|---|---|---|
| **Fixed minimum interval** (`now - last >= interval`) | One action per interval, no bursts | Simple actions with a natural pace: "one flourish per second" |
| **Token bucket** | Bursts up to capacity, sustained rate = refill rate | Most remotes: allows a quick double-click, blocks sustained spam (the Roblox docs' recommended example) |
| **Leaky bucket accumulator** | Accumulates "excess", leaks over time, triggers past a threshold | Measurements rather than requests: movement excess, damage-per-second plausibility |
| **Sliding window counter** | At most N in the last T seconds | Moderation-style limits: "5 trade requests per minute" |
| **Global budget** | One bucket for the whole server | Protecting shared backends: DataStore, HttpService, MessagingService |

## A reusable rate limiter

Per player, per key, token bucket, with cleanup. `os.clock()` is fine on the server (monotonic, local); the Roblox docs' example uses `time()`.

```lua
--!strict
-- ServerScriptService/Shared/RateLimiter.luau
local Players = game:GetService("Players")

export type Limiter = {
	allow: (self: Limiter, player: Player, key: string?) -> boolean,
	reset: (self: Limiter, player: Player) -> (),
}

type Bucket = { tokens: number, last: number }

local RateLimiter = {}
RateLimiter.__index = RateLimiter

local all: { any } = setmetatable({}, { __mode = "v" }) :: any -- weak list for cleanup

-- ratePerSec: sustained rate. burst: how many may be spent at once.
function RateLimiter.new(ratePerSec: number, burst: number): Limiter
	assert(ratePerSec > 0 and burst >= 1, "bad limiter config")
	local self = setmetatable({
		rate = ratePerSec,
		burst = burst,
		buckets = {} :: { [Player]: { [string]: Bucket } },
		rejected = {} :: { [Player]: number },
	}, RateLimiter)
	table.insert(all, self)
	return (self :: any) :: Limiter
end

function RateLimiter.allow(self: any, player: Player, key: string?): boolean
	local k = key or "_"
	local now = os.clock()
	local mine = self.buckets[player]
	if not mine then
		mine = {}
		self.buckets[player] = mine
	end
	local b = mine[k]
	if not b then
		b = { tokens = self.burst, last = now }
		mine[k] = b
	else
		b.tokens = math.min(self.burst, b.tokens + (now - b.last) * self.rate)
		b.last = now
	end
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	self.rejected[player] = (self.rejected[player] or 0) + 1
	return false
end

function RateLimiter.reset(self: any, player: Player)
	self.buckets[player] = nil
	self.rejected[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	for _, limiter in all do
		limiter:reset(player)
	end
end)

return RateLimiter
```

Use it as the first line of a handler, before any parsing:

```lua
local castLimiter = RateLimiter.new(4, 6)      -- 4/s sustained, burst 6
local buyLimiter = RateLimiter.new(2, 4)
local chatLimiter = RateLimiter.new(0.5, 5)    -- the docs' "5 per 10 seconds"

castRemote.OnServerEvent:Connect(function(player, slot, aim)
	if not castLimiter:allow(player) then return end
	-- validate, then act
end)
```

Or make it middleware in your remote wrapper so no handler can forget it (see [[RemoteEvents RemoteFunctions and Unreliable Remotes]]).

## Choosing limits

1. **Find the fastest legitimate use.** A combo of 4 swings at a 0.32 s pace is about 3 requests per second; a shop where a player buys in quick succession may click 5 times in a second.
2. **Set the sustained rate at 1.5x to 2x that** and the burst at the largest honest burst (a double-click, a combo string, a reconnect flush).
3. **Log rejections** for a week before tightening. Honest players hitting a limit means the limit is wrong.
4. **Never auto-ban on rate limits alone.** Mobile lag bunches inputs; retry loops resend. A player tripping limits hundreds of times is a signal for the suspicion score ([[Exploits and Anti-Cheat]]), not a verdict.

Production values from one combat and collection game (all server-side):

| Action | Limit | Notes |
|---|---|---|
| Admin panel actions | 1 per 0.08 s | Allowlisted users only; limit exists to stop accidental loops |
| Crafting and fusion requests | 1 per 0.4 s | Plus idempotent tokens |
| Hub activities (spin, fishing, chest) | 1 per 0.5 s | Plus range check, cooldown, and a "can mutate profile" check |
| Equip flourish relay | 1 per second | Cosmetic relay to other clients |
| Custom animation relay: speed changes | Immediately if the change is 6% or more, else at most every 0.25 s | Batching continuous state |
| Custom animation relay: weight changes | At most 4 per second | |
| Ability casts | Cooldown enforced at 0.95x authored value | Tolerance for latency jitter |

## Engine and backend limits you must budget for

Several Roblox services have their own limits; exceeding them makes requests fail or queue. Budget them **server-wide**, not per player, because one player's spam can starve everyone.

| Service | Limit (as of October 2026) | Source |
|---|---|---|
| Remotes (client to server) | About 500/s per client, shared per remote type | Roblox docs |
| UnreliableRemoteEvent payload | 1,000 bytes | Roblox docs |
| HttpService | About 500 requests per minute per server | Roblox docs; one production game hit it with per-clip uploads and switched to one request per batch |
| MessagingService publish | 600 + 240 x players per minute per server | Roblox docs; see [[Cross-Server Messaging]] |
| MemoryStore requests | 1,000 + 120 x concurrent users request units per minute, experience-wide | Roblox docs; see [[MemoryStore Service]] |
| DataStores | Per-server request budgets that scale with players | See [[DataStore Fundamentals]] |

A server-wide budget is just a limiter keyed on a fixed "player" slot; or a small queue that spends a fixed number of calls per second and drops or delays the rest:

```lua
--!strict
-- A server-wide budget for an expensive backend call, with a bounded queue.
local Budget = {}

local RATE = 4          -- calls per second for this service
local MAX_QUEUE = 200   -- beyond this, drop new work (log it)

local queue: { () -> () } = {}
local tokens = RATE
local last = os.clock()

function Budget.submit(job: () -> ()): boolean
	if #queue >= MAX_QUEUE then
		warn("[Budget] queue full; dropping job")
		return false
	end
	table.insert(queue, job)
	return true
end

task.spawn(function()
	while true do
		task.wait(0.05)
		local now = os.clock()
		tokens = math.min(RATE, tokens + (now - last) * RATE)
		last = now
		while tokens >= 1 and #queue > 0 do
			tokens -= 1
			local job = table.remove(queue, 1) :: () -> ()
			task.spawn(function()
				local ok, err = pcall(job)
				if not ok then warn("[Budget] job failed: " .. tostring(err)) end
			end)
		end
	end
end)

return Budget
```

## Coalescing: do less work, not just less often

Many "spam" problems are really "the same work repeated". Coalesce:

- **Save soon, not save now.** Mark the profile dirty and schedule one save a few seconds later; ten changes produce one write. One production game used a `pushState` (update the client mirror) plus `saveSoon` (debounced save) pair after every profile mutation.
- **Batch UI updates.** Send one inventory snapshot after a burst of changes rather than one remote per item.
- **Relay at a fixed rate.** Continuous state (aim, animation speed) is sampled and sent at 10 to 20 Hz, only when it changed meaningfully.

```lua
--!strict
-- Debounce helper: run `fn(key)` once, `delay` seconds after the last request for that key.
local Debounce = {}
local pending: { [any]: thread } = {}

function Debounce.soon(key: any, delay: number, fn: (any) -> ())
	local existing = pending[key]
	if existing then
		task.cancel(existing)
	end
	pending[key] = task.delay(delay, function()
		pending[key] = nil
		fn(key)
	end)
end

return Debounce
-- Usage: Debounce.soon(player, 5, saveProfile) after every mutation.
-- On PlayerRemoving and BindToClose, save immediately instead (and cancel the pending one).
```

## Idempotency: making retries harmless

Rate limits reduce volume; they do not stop a duplicated request from doing double work. Give actions that grant or consume value a client-generated token and remember recent tokens on the server (see the `Idempotency` helper in [[Server Authority and Validation]]). Purchases use the receipt's `PurchaseId` the same way ([[Purchase Data and Receipts]]).

## Abuse that is not cheating

Rate limits also protect players from each other:

| Abuse | Limit |
|---|---|
| Trade request spam | Sliding window per sender, and per sender-recipient pair |
| Friend or party invite spam | Same |
| Report spam | Per reporter per target |
| Custom chat or sign text | Token bucket plus `TextService` filtering on the server |
| Emote and effect spam near others | Per player rate; cap effects per area on receiving clients |
| Vote kick or vote skip | One vote per player per vote; cooldown per initiator |

User text must be filtered on the server with `TextService` before other players see it; never relay raw strings ([[Roblox Policies Ratings and Compliance]]).

## Client-side limiting (for honest clients)

Client debounces do not stop exploiters, but they keep honest clients well inside every limit and make the UI feel right:

- Disable a button while its request is in flight; re-enable on the server's answer or after a timeout.
- Pace continuous sends (aim, position hints) on a timer, not per frame.
- Collapse repeated presses into one request when the action is idempotent ("open shop").

## Diagnosing

| Symptom | Cause |
|---|---|
| Actions feel delayed for one player under load | Their client is saturating the shared remote budget; find the per-frame remote |
| DataStore warnings about queued requests | Unbatched saves; add `saveSoon` |
| `HttpService` errors about the request limit | Per-item requests; batch |
| Honest players report "nothing happens sometimes" | Rate limit too tight; check rejection logs |
| Memory slowly grows on long servers | Rate limiter tables not cleared on `PlayerRemoving` |

## Common mistakes

| Mistake | Fix |
|---|---|
| Rate limit after expensive parsing or DataStore calls | Rate limit first |
| One global cooldown table keyed by player name | Key by `Player` (or `UserId`), clear on leave |
| Kicking on rate-limit hits | Log and score; drop the request |
| Rate limiting only remotes | Prompts, Touched, ClickDetectors too |
| Using `tick()` | `os.clock()` on one machine; `GetServerTimeNow()` across machines |
| Saving on every change | Debounced saves plus immediate save on leave |

## Checklist

- [ ] Every client-triggerable entry point has a per-player limit as its first statement.
- [ ] Limits are 1.5x to 2x the fastest legitimate use, with logged rejections.
- [ ] Backend calls go through server-wide budgets.
- [ ] Saves and UI pushes are coalesced.
- [ ] Value-granting actions are idempotent.
- [ ] Limiter state is cleared on `PlayerRemoving`.

## See also
[[Server Authority and Validation]] · [[Exploits and Anti-Cheat]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Saving Correctly - Autosave and BindToClose]] · [[HttpService and External APIs]] · [[Cross-Server Messaging]] · [[MemoryStore Service]] · [[Network Performance]]

## Nuances and edge cases

1. **Honest players burst.** A player on a laggy connection can deliver ten queued remote calls in one packet after a stall. A strict "max 1 per 100 ms" check flags them as abusers. Token buckets with a burst allowance (for example, a capacity of 10 refilling at 5 per second) accept honest bursts while capping sustained abuse. Choose capacity from the largest honest burst you measure, not a guess.
2. **Limits depend on device and input.** Auto-clickers and fast tapping on phones look similar; a player on a high-refresh mouse can click faster than a phone player can tap. Set limits from game rules (an attack cannot happen faster than its animation) rather than from input speed.
3. **Rate limiting is per resource, not per remote.** One remote that does three things (buy, equip, sell) needs separate limits per action, because buying is expensive and equipping is cheap. Key buckets by player and action.
4. **Server cost per rejected call still exists.** Even a rejected call costs deserialisation and a table lookup. Under a flood, the cheapest possible rejection matters: check the bucket before any argument parsing, and drop silently instead of replying.
5. **Scale changes what abuse costs you.** One abuser in a 6-player server ruins five players' experience; in a 50-player server they can also degrade server performance for everyone. Track per-server totals as well as per-player, and shed load from the noisiest players first.
6. **Global resources need global limits.** Per-player limits do not protect shared budgets: 50 players each staying under their own limit can together exhaust a DataStore or HTTP budget. Put a server-wide limiter in front of anything that consumes a per-server or per-experience quota.
7. **Punishment needs evidence.** Rate-limit hits are evidence of either abuse or lag. Log and score them, combine with other signals, and act on patterns. Instant kicks for a single hit produce false positives and angry support messages (see [[False Positives Lag and Fair Enforcement]]).
8. **Client-side limits are UX, not security.** Disabling a button for half a second stops accidental double-clicks and reduces load from honest players. It does nothing against exploiters, so the server limit must exist regardless.

The senior trade-off: tight limits reduce abuse and anger honest players with bad connections; loose limits do the opposite. Measure honest traffic first (log rates for a week), then set limits a comfortable margin above the honest maximum.

## Common mistakes (advanced)

1. **Fixed-interval checks with no burst.** Symptom: laggy players report actions being ignored. Fix: token buckets with measured capacity.
2. **One limit per remote for multi-action remotes.** Symptom: cheap actions are throttled by expensive ones, or the reverse. Fix: per-action buckets.
3. **Replying to every rejected call.** Symptom: floods cost server bandwidth. Fix: drop silently; notify the client at most once per window.
4. **No server-wide limits on shared budgets.** Symptom: DataStore throttling during busy periods even though every player is within limits. Fix: a global limiter per budget.
5. **Buckets never cleaned up.** Symptom: memory growth over long server lifetimes. Fix: clear per-player buckets on leave.
6. **Limits tuned only in Studio.** Symptom: real players on phones trip limits that never triggered in testing. Fix: log live rates before enforcing.

## Related decisions

- [[Remote Abuse Patterns and Rate Limiting in Practice]]: real abuse patterns and tuned limits.
- [[False Positives Lag and Fair Enforcement]]: acting on rate-limit evidence fairly.
- [[Testing Your Own Remotes - Fuzzing and Abuse Tests]]: flood tests against your limits.
- [[Network Bandwidth Budgets and Measuring Them]]: measuring the cost of floods.
- [[Economy Exploits - Dupes Races and Purchase Abuse]]: rate limits as part of economy defence.
- [[Threat Modeling a Roblox Game]]: finding which actions need limits.
- [[DataStore Fundamentals]]: the shared budgets that need global limits.
- [[Combat Systems Architecture]]: deriving attack limits from game rules.

## Connected notes
<!-- auto-links:start -->
[[Rate Limiting]] · Cookbook - Remotes and Networking · Skill - Roblox Secure Remotes · Anti-Exploit Start Here · Detecting Combat Exploits - Reach Rate and Aim · Saved Inventory End to End
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Cookbook - Remotes and Networking]] · [[Autoclicker and Macro Detection for Combat Remotes]] · [[Client Prediction and Reconciliation for Combat]] · [[Client-Server Model]] · [[Interest Management and Per-Player Replication]] · [[Replication Rules]] · [[Network Ownership]] · [[Snapshot Interpolation for Custom Replication]] · [[Teleporting and Multi-Place Games]] · [[Frameworks - Knit Matter and Others]]
<!-- related:end -->
