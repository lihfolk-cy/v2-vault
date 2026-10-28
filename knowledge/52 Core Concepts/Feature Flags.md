---
tags: [core-concept, live-ops, release, architecture]
---
# Feature Flags

A **feature flag** is a named switch, read at runtime, that turns a feature or behaviour on or off without publishing a new version of the game. Flags can be global ("new shop on"), per percentage of servers or players ("new shop for 10 percent"), or per group ("testers only").

## Why it matters on Roblox

Publishing a Roblox update means servers restart or migrate, and rolling back means publishing again. A flag lets you ship code dark, turn it on when ready, and turn it off within a minute if it breaks, without kicking anyone. It also makes staged rollouts and experiments possible. Flags are usually stored somewhere servers can read live: a DataStore key polled every minute or so, MemoryStore, or a config service; check current Roblox docs for any built-in live configuration features before building your own (this note did not verify their current state).

## The nuance most people miss

1. **Flags must be read by the server and pushed to clients.** Never let a client decide its own flag; an exploiter can flip it. The server reads the flag and replicates the value (an attribute on ReplicatedStorage works well).
2. **Decide the bucket deterministically.** For "10 percent of players", hash the UserId with the flag name so a player stays in the same bucket across servers and sessions. Random per join gives players a feature that appears and vanishes.
3. **Changes arrive at different times.** Servers poll separately, so for a minute some servers have the flag on and others off. Features that interact across servers (trading, cross-server events) need to tolerate that.
4. **Default to the safe value.** If the flag store fails to load, the game must still work, usually with the feature off.
5. **Flags are debt.** Every flag doubles the states your code can be in. Remove the flag, and the old path, once a feature is fully launched.
6. **A kill switch is the most valuable flag.** Every risky system (trading, purchases of new items, new drop tables) benefits from an off switch that has been tested.

## Tiny example

```lua
local function inRollout(userId: number, flag: string, percent: number): boolean
	local h = 0
	for i = 1, #flag do h = (h * 31 + string.byte(flag, i)) % 1000003 end
	local x = (h + userId % 1000003) % 1000003
	return (x * 7919) % 100 < percent
end
```

(Every intermediate value stays below about 8 billion, far under 2^53, so the integer arithmetic is exact in Luau's doubles. Multiplying a raw UserId by a large constant would not be.)

## Where this shows up

- [[Feature Flags and Staged Rollouts]]: the deep dive.
- [[Global State and Live Config]]: where flag values live.
- [[Release Process and Rollbacks]]: flags as fast rollbacks.
- [[A-B Testing and Experiments on Roblox]]: flags as experiment buckets.
- [[Live Incident Response and Post-Mortems]]: kill switches in incidents.
- [[MemoryStore Service]]: fast flag distribution.
- [[Cross-Server Messaging]]: pushing flag changes to all servers.
- [[Live Ops Events and Updates]]: timed event switches.
- [[Build Test and Release Pipeline]]: flags in the release flow.
- [[Safe Changes in a Shared Place]]: shipping dark in a shared project.
- [[Trading Systems Without Duplication]]: a system that needs a kill switch.

Related concepts: [[Telemetry Events]], [[Data Schema Versioning]], [[Dependency Injection in Luau]].

## Connected notes
<!-- auto-links:start -->
[[Live Ops Deep Dive Start Here]] · [[Live Content Pipeline]] · [[Server Shutdowns Soft Updates and Migration]] · [[Debugging Live Servers]] · [[Resource Library - Publishing and Live Ops]] · [[Crash and Error Telemetry]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
