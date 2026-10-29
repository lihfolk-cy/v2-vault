---
tags: [core-concept, security, networking, remotes, datastore, type/reference, area/data, level/beginner, api/DataStore, area/security]
---
# Rate Limiting

<!-- tldr:start -->
> [!tldr] TL;DR
> - Inbound. Remotes have no per-game rate limit you can configure.
> - Outbound. Roblox limits you.
> - A token bucket beats a cooldown. A cooldown ("one per 0.5 s") rejects an honest double-tap.
> - Gameplay cooldowns and abuse limits are different layers.
>
> Cost: TL;DR ~100 tok · whole note ~1.1k tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Rate limiting** caps how often something may happen per unit of time: how many times a player may fire a remote, how many DataStore requests a server may make, how many messages a player may send. Requests over the cap are dropped, queued or slowed.

## Why it matters on Roblox

Two directions:

- **Inbound.** Remotes have no per-game rate limit you can configure. An exploiter can fire a remote hundreds of times a second. Each call costs server CPU, and if the handler writes data, spawns parts or sends messages, it costs much more.
- **Outbound.** Roblox limits you. DataStore request budgets scale with players, for example standard get and set requests at `60 + numPlayers * 40` per minute per server, and ordered writes far lower at `30 + numPlayers * 5` (Roblox docs, "Data stores: error codes and limits", as of October 2026; older notes and tutorials quote smaller multipliers, so always check the current page); MemoryStore, HttpService and MessagingService have their own. Exceed them and calls queue or fail.

## The nuance most people miss

1. **A token bucket beats a cooldown.** A cooldown ("one per 0.5 s") rejects an honest double-tap. A bucket (capacity 5, refill 2 per second) allows short bursts and still caps the average. Most player input is bursty.
2. **Gameplay cooldowns and abuse limits are different layers.** The ability cooldown is design (and must be server-checked). The rate limit is a ceiling far above honest play that protects the server. Keep both, with different numbers.
3. **Rate limits must not punish lag.** Packets bunch up after a network stall, so ten honest calls can arrive within one frame. Count over a window of a second or more and drop, do not kick, on the first breach. See the fairness notes below.
4. **Limit per player and globally.** Per-player limits stop one attacker; a global limit on an expensive operation (saves, HTTP calls) stops many players together from exhausting the server budget.
5. **Unreliable remotes need limits too.** They are cheaper per call but can still flood a handler.

## Tiny example

```lua
local buckets: { [Player]: { tokens: number, t: number } } = {}
local CAP, RATE = 6, 3 -- burst of 6, 3 per second sustained

local function allow(player: Player): boolean
	local b = buckets[player]
	local now = os.clock()
	if not b then b = { tokens = CAP, t = now }; buckets[player] = b end
	b.tokens = math.min(CAP, b.tokens + (now - b.t) * RATE)
	b.t = now
	if b.tokens < 1 then return false end
	b.tokens -= 1
	return true
end
-- Clear buckets[player] on PlayerRemoving to avoid a leak.
```

## Where this shows up

- [[Rate Limiting and Abuse Prevention]]: the main design note.
- [[Remote Abuse Patterns and Rate Limiting in Practice]]: real abuse shapes and limits.
- [[DataStore Fundamentals]]: the outbound budgets you must respect.
- [[False Positives Lag and Fair Enforcement]]: why a breach is not proof of cheating.
- [[Detecting Combat Exploits - Reach Rate and Aim]]: attack rate as a signal.
- [[Text Chat Customization with TextChatService]]: chat spam limits.
- [[HttpService and External APIs]]: outbound request caps.
- [[Network Performance]]: inbound floods as a performance problem.
- [[Matchmaking Queues with MemoryStore]]: MemoryStore request budgets.
- [[Skill - Roblox Secure Remotes]]: a review checklist that requires limits.
- [[Hunting Memory Leaks Step by Step]]: per-player tables not cleared on leave.
- [[Input Responsiveness Buffering and Coyote Time]]: server cooldown grace for early inputs.

Related concepts: [[Server Authority]], [[Input Buffering]], [[Telemetry Events]].

## Connected notes
<!-- auto-links:start -->
[[Cookbook - Remotes and Networking]] · Anti-Exploit Start Here · [[Core Concepts Start Here]] · Crash and Error Telemetry · Skill - Roblox Anti-Exploit Review · RemoteEvents RemoteFunctions and Unreliable Remotes
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Input Buffering]] · [[Replication Boundary]] · [[Feature Flags]] · [[Session Lock]] · [[Idempotency]] · [[Streaming Radius]] · [[Deterministic Simulation]] · [[Event Bus]]
<!-- related:end -->
