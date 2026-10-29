---
tags: [testing, qa, performance, memory, soak, load, servers, type/guide, area/testing, area/performance, level/advanced, api/HttpService]
---
# Load and Soak Testing Servers - Long Sessions and Many Clients

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Soaking in Studio.
> - Avoid: A long test with no churn: nobody leaves, so per-player leaks hide.
> - Avoid: Sampling only total memory; no instance or custom counters to say where.
> - Remote handlers delegate to service functions that synthetic load can call.
> - Sampler logs memory, instances, heartbeat, bandwidth and custom counters.
> - Soak on a published private server, several hours, with join and leave churn.
>
> Cost: TL;DR ~150 tok · whole note ~2.3k tok. Read more: ## 1. Where load can come from · ## 2. What to sample · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A 10-minute playtest with three friends tells you almost nothing about a server that runs for six hours with a full lobby. **Load** problems appear when many players act at once (remote floods, physics, DataStore budgets). **Soak** problems appear only with time (leaked connections, growing tables, parts that never clean up, a memory curve that climbs until the server is slow). Both are invisible in Studio.

This note covers how to generate load you can actually get on Roblox, how to soak a server, what to sample and how to read the trend. How to find the leak once you know there is one is in [[Hunting Memory Leaks Step by Step]].

Labels as marked.

---

## 1. Where load can come from

You cannot point a fleet of bot clients at Roblox servers. Automating clients against Roblox is not something the platform supports for creators, and the Terms of Use restrict automated access (**Unverified** for any specific tool; do not use third-party multi-client bots on live servers). Real options:

| Source | Scale | Good for |
|---|---|---|
| Studio Server & Clients | A few clients on one PC | Race conditions, replication, join and leave logic |
| `StudioTestService:ExecuteMultiplayerTestAsync` | 1 to 8 clients per session, plugin-driven; `AddPlayers` adds more from the server (Roblox docs, [StudioTestService](https://create.roblox.com/docs/reference/engine/classes/StudioTestService)) | Repeatable scripted multi-client runs ([[UI Automation with VirtualInput and StudioTestService]]) |
| Team Test or private server with real testers | 10 to 50 humans | Real latency, real devices, full lobbies |
| **Synthetic server-side load** | As much as you like | Stressing systems with simulated actors on the server |
| Soft launch | Real players | The only true load test; ship behind flags ([[Feature Flags and Staged Rollouts]]) |

Synthetic load is underused. Most server cost is not "a player"; it is what a player causes: projectiles, NPC aggro, drops, remote handling, saves. You can cause those directly.

```lua
--!strict
-- ServerScriptService/QA/SyntheticLoad (test places only)
-- Drives the same server code paths players trigger, at a chosen rate, with fake actor ids.
local RunService = game:GetService("RunService")
local CombatService = require(game.ServerScriptService.Services.CombatService) -- your module

local ACTORS = 40           -- simulated players
local ACTIONS_PER_SEC = 4   -- per actor, roughly a busy real player

if not game:GetAttribute("QA_Load") then
	return -- only when explicitly enabled (set the attribute in the test place, never in live)
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt * ACTORS * ACTIONS_PER_SEC
	while acc >= 1 do
		acc -= 1
		local actor = math.random(1, ACTORS)
		-- Call the same validated entry point the remote handler calls, bypassing only the network.
		CombatService.handleAttack(-actor, { targetPos = Vector3.new(math.random(-200, 200), 5, math.random(-200, 200)) })
	end
end)
```

This only works if your remote handlers delegate to service functions that take an id and arguments ([[Server Authority and Validation]] style). If handler logic needs a real `Player` object everywhere, that is worth refactoring anyway. Negative ids keep fake actors from colliding with real user ids. Never let synthetic actors write to DataStores; stub the save layer.

---

## 2. What to sample

Sample on the server every 30 to 60 seconds (**Rule of thumb**) and keep the series. Useful members of `Stats` (Roblox docs, [Stats](https://create.roblox.com/docs/reference/engine/classes/Stats)): `GetTotalMemoryUsageMb()`, `GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.X)`, `InstanceCount`, `PrimitivesCount`, `MovingPrimitivesCount`, `ContactsCount`, `HeartbeatTime`, `PhysicsStepTime`, `DataSendKbps`, `DataReceiveKbps`. (`HeartbeatTimeMs` and `PhysicsStepTimeMs` are deprecated in favour of the non-Ms names.) Add your own counters: live connections in your signal library, entries in caches keyed by player, active NPCs, projectiles, queued saves.

```lua
--!strict
-- ServerScriptService/QA/SoakSampler
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local INTERVAL = 60
local samples = {}
local started = os.clock()

task.spawn(function()
	while true do
		task.wait(INTERVAL)
		local s = {
			t = math.floor(os.clock() - started),
			players = #Players:GetPlayers(),
			memMb = math.floor(Stats:GetTotalMemoryUsageMb()),
			scriptMb = math.floor(Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Script)),
			instances = Stats.InstanceCount,
			moving = Stats.MovingPrimitivesCount,
			heartbeat = Stats.HeartbeatTime,
			sendKbps = math.floor(Stats.DataSendKbps),
		}
		table.insert(samples, s)
		print("[Soak]", HttpService:JSONEncode(s)) -- visible in the server console (F9) and logs
	end
end)
```

Read the output from the Developer Console server log ([[Developer Console and Stats]]) or ship it to your telemetry ([[Crash and Error Telemetry]]).

---

## 3. Running a soak

1. **Private server or test place, published.** Studio servers do not behave like production servers in memory or scheduling.
2. **Realistic churn.** Players joining and leaving matters more than players staying. Ask testers to rejoin repeatedly, or schedule shifts. A leak keyed by player only shows with churn.
3. **Run long.** At least as long as your typical server lifetime; several hours is a reasonable first target (**Rule of thumb**).
4. **Do the full loop repeatedly:** rounds, shops, trades, deaths, map changes, events.
5. **Record events on the timeline** (round start, big event, mass join) so a step in the graph has an explanation.

---

## 4. Reading the curves

| Shape | Meaning |
|---|---|
| Memory rises, then flattens | Warm-up: caches filling, assets loading. Fine if the plateau is inside budget ([[Memory Budgets and Leaks]]) |
| Saw-tooth with a flat baseline | Rounds allocating and freeing. Healthy |
| Saw-tooth whose baseline climbs | Something survives each round. Classic leak |
| Steady climb proportional to joins | Per-player state not cleaned on `PlayerRemoving` |
| `InstanceCount` climbs | Parts, sounds or effects never destroyed |
| Heartbeat time climbs while memory is flat | A list that grows and is iterated every frame, or connections stacking |
| Send kbps climbs with no player change | Replicating more and more state (attributes changing on many instances, values in ReplicatedStorage growing) |

The test for "is this a leak": the same game state (an empty server between rounds, say) at hour 1 and hour 4 should have about the same memory and instance count. If not, bisect by turning systems off with flags ([[The Debugging Method - Reproduce Isolate Bisect]]).

---

## 5. Load pass criteria

Write numbers down before the test, not after:

- Heartbeat time at full lobby stays under your frame budget with headroom ([[Performance Fundamentals]]).
- No remote handler shows up as a hotspot in the server MicroProfiler ([[MicroProfiler Guide]]).
- DataStore requests stay inside budget at peak joins and at shutdown ([[Saving Correctly - Autosave and BindToClose]]).
- Memory at the end of the soak within a set margin of memory at the same state early on.

---

## Common mistakes

- Soaking in Studio.
- A long test with no churn: nobody leaves, so per-player leaks hide.
- Sampling only total memory; no instance or custom counters to say where.
- Third-party bot clients against Roblox servers.
- Synthetic actors writing to real DataStores.
- Deciding pass thresholds after seeing the graph.

## Checklist

- [ ] Remote handlers delegate to service functions that synthetic load can call.
- [ ] Sampler logs memory, instances, heartbeat, bandwidth and custom counters.
- [ ] Soak on a published private server, several hours, with join and leave churn.
- [ ] Same-state comparison early vs late shows no growth.
- [ ] Load test at a full lobby with thresholds written in advance.
- [ ] Findings fed into [[Hunting Memory Leaks Step by Step]].

## See also

- [[Hunting Memory Leaks Step by Step]], [[Memory Budgets and Leaks]], [[Debugging Live Servers]]
- [[Network Bandwidth Budgets and Measuring Them]], [[Physics Performance]]
- [[UI Automation with VirtualInput and StudioTestService]], [[Multi-Client and Live Testing]]

## Connected notes

[[Developer Console and Stats]] · [[Crash and Error Telemetry]] · [[Feature Flags and Staged Rollouts]] · [[Genre QA Passes - Test Checklists per Game Type]]

<!-- related:start -->
## Related
[[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]] · [[QA Checklists Before Release]] · [[Network Performance]] · [[Mobile and Low-End Optimization]] · [[Gated Tester Commands and Debug Panels]] · [[In-Game Bug Report Button with Automatic Context]] · [[Multi-Client and Device Playtesting Protocols]] · [[Automated Luau Checks - LihFolk Hook and Audit]]
<!-- related:end -->
