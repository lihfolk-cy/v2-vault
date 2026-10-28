---
tags: [debugging, live-ops, developer-console, logservice, telemetry, open-cloud]
---
# Debugging Live Servers

Some bugs only exist in live servers: they need real latency, 30 players, a server that has been up for nine hours, a device you do not own, or real purchases and teleports. You cannot put a breakpoint on a live server. What you can do is see its output, ask it questions through tools you built in advance, ship its logs somewhere you can search, and change its behaviour with flags. This note is about that toolkit and how to use it during an investigation.

What the Developer Console shows is covered in [[Developer Console and Stats]]; the Error Report, crash rates and an error pipeline in [[Crash and Error Telemetry]]; live test protocols in [[Multi-Client and Live Testing]]; incident handling in [[Live Incident Response and Post-Mortems]]. This note is the investigation layer between them.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. Why live is different

Before debugging, list what differs from Studio. The bug is usually in one of these:

| Difference | Bugs it causes |
|---|---|
| Real latency and packet loss | load-order races, desync ([[Debugging Race Conditions and Yield Order]]) |
| Many players | contention, budgets (DataStore, remotes, HTTP), ownership hand-offs |
| Long server uptime | memory growth, unbounded tables, timers drifting, counters growing ([[Hunting Memory Leaks Step by Step]]) |
| Real devices | low memory kills, slow frames, touch and gamepad input paths |
| Asset permissions | animations, sounds or meshes that load only for the owner's account in Studio |
| Teleports, private servers, reserved servers | `TeleportData`, server type assumptions, join paths that never run in Studio |
| Real purchases | receipt flow, retries, duplicate receipts ([[Developer Products and ProcessReceipt]]) |
| Streaming at real distances | missing instances on clients |
| Shutdowns for updates | `BindToClose` timing, saves under load |

A good first question for any live-only bug: **"Which of these does my repro in Studio not have?"** Then add that thing to the Studio repro (latency, eight clients, a long soak, a phone).

---

## 2. Find the right server and the right moment

A live bug report is useless without a way to find the server it happened on.

### 2.1 Make every server identifiable

- Log `game.JobId`, `game.PlaceVersion` and the server start time at startup.
- Show the job id (or a short hash of it) and the place version in a corner of a developer-only debug overlay, and in the settings menu for everyone. A player who reports a bug with a screenshot then gives you the server and the version.
- Include the job id in every error and telemetry event you ship ([[Crash and Error Telemetry]]).

```lua
--!strict
-- Server: one line that makes every log searchable by server.
local SERVER_TAG = ("%s v%d"):format(string.sub(game.JobId, 1, 8), game.PlaceVersion)
workspace:SetAttribute("ServerTag", SERVER_TAG) -- clients can read it for the settings menu
print("[server] start", SERVER_TAG, os.date("!%Y-%m-%dT%H:%M:%SZ"))
```

In Studio `game.JobId` is an empty string; the tag still works.

### 2.2 Get into that server

If the server is still running, a developer can join it: `TeleportService:TeleportToPlaceInstance(placeId, jobId, player)` from a gated admin command (Docs). Joining a friend who is in it also works. Once inside, the Developer Console's server view shows that server's output if you have edit permission (Docs, [[Developer Console and Stats]]).

### 2.3 Old servers are gone

Most live bugs are reported after the server has closed. Then everything depends on what you logged and shipped (section 4). Plan for this: the most valuable live debugging work happens **before** the incident.

---

## 3. In-server tools

### 3.1 The Developer Console, used deliberately

From [[Developer Console and Stats]]: the Log tab with a Client/Server toggle, Memory, Luau heap, Script Profiler, MicroProfiler, and for authorised users a command line. During an investigation:

1. **Server Log first**, filtered to errors and warnings. Live-only server errors (throttling, unexpected remote arguments) show here.
2. **Server Memory** and the Luau heap, if the complaint is lag after a long session.
3. **Client Log on the reporter's device**, if they can open it (`/console` in chat or the menu, Docs). Ask for a screenshot of errors.
4. **MicroProfiler** on the server for hitches ([[MicroProfiler Guide]]).

On the command line: it runs code in a production server with real data. Use read-only commands (print state, count instances) unless you have decided to change something, and never paste code from someone else that you have not read.

### 3.2 A gated admin log viewer

The console's log history is limited and only visible to people with edit permission. Most teams also want testers and moderators to see server warnings in-game. `LogService:GetLogHistory()` and `LogService.MessageOut` (Docs) make this simple:

```lua
--!strict
-- ServerScriptService/Debug/ServerLogRelay.server.luau
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ALLOWED: { [number]: boolean } = {} -- staff UserIds, or check group rank
local MAX_LINES = 200

type Line = { t: number, kind: string, text: string }
local ring: { Line } = {}

local function push(text: string, kind: Enum.MessageType)
	if kind == Enum.MessageType.MessageOutput then
		return -- keep warnings and errors only; plain prints are noise live
	end
	table.insert(ring, { t = os.time(), kind = kind.Name, text = string.sub(text, 1, 400) })
	if #ring > MAX_LINES then
		table.remove(ring, 1)
	end
end

LogService.MessageOut:Connect(push)

local Fetch = Instance.new("RemoteFunction")
Fetch.Name = "AdminFetchServerLog"
Fetch.Parent = ReplicatedStorage

local lastFetch: { [Player]: number } = {}

Fetch.OnServerInvoke = function(player: Player)
	if not ALLOWED[player.UserId] then
		return nil
	end
	local now = os.clock()
	if lastFetch[player] and now - lastFetch[player] < 2 then
		return nil -- rate limit
	end
	lastFetch[player] = now
	return ring
end

Players.PlayerRemoving:Connect(function(p: Player)
	lastFetch[p] = nil
end)
```

Notes:
- The ring buffer bounds memory; a `table.remove(ring, 1)` on a 200-item array is cheap enough at warning rates (use a head index if you keep thousands).
- Never connect a handler to `MessageOut` that itself prints or warns: it would feed itself. Keep it silent.
- Server output can contain player names and ids from your own logs; only staff see it, and you should keep personal data out of logs anyway ([[Player Privacy and Data Deletion]]).

### 3.3 On-demand state dumps

Logs show what happened; a dump shows what **is**. Give the admin panel a "dump" command that prints a compact summary of a system's state for one player or for the server:

```lua
--!strict
-- Each system registers a dump function; the admin command calls one by name.
local Dumps: { [string]: (target: Player?) -> string } = {}

local function registerDump(name: string, fn: (target: Player?) -> string)
	Dumps[name] = fn
end

-- Example registration inside the combat system:
registerDump("combat", function(target)
	local count = 0
	for _ in activeFights do
		count += 1
	end
	return ("activeFights=%d target=%s"):format(count, target and target.Name or "-")
end)

local function runDump(name: string, target: Player?): string
	local fn = Dumps[name]
	if not fn then
		return "no such dump"
	end
	local ok, result = pcall(fn, target)
	return if ok then result else ("dump failed: " .. tostring(result))
end
```

(`activeFights` stands for the system's own table.) This turns "the boss is stuck" into a readable line: phase, target, last state change time, owner of the boss assembly. Write the dump function when you write the system; it is five lines then and impossible to add during an incident.

### 3.4 Remote log level changes

The logger in [[Debugger Breakpoints and Logging]] supports per-tag levels. Expose a gated admin command that raises one tag to `debug` **in this server only**, and another that broadcasts to all servers through MessagingService (Docs; messages and rates are small, check the current MessagingService limits page before relying on numbers). Raise levels for minutes, not hours, and lower them again automatically:

```lua
--!strict
local function raiseTemporarily(tag: string, minutes: number)
	Log.setTagLevel(tag, "debug")
	task.delay(minutes * 60, function()
		Log.setTagLevel(tag, nil) -- back to the default
	end)
end
```

---

## 4. Shipping logs off the server

Logs inside a server die with it. To debug yesterday's bug you need logs stored elsewhere.

### 4.1 Options

| Sink | Good for | Limits and costs |
|---|---|---|
| Error Report (built in) | uncaught errors and warnings, stack traces, by version | 500 unique errors tracked; dynamic messages fragment ([[Crash and Error Telemetry]]) |
| AnalyticsService custom events | counts and funnels (rejects, failures, timings) | aggregated, not raw logs ([[Analytics and Funnels]]) |
| HttpService to your own endpoint | raw logs, searchable | per-server request limit (about 500 per minute, [[HttpService and External APIs]]); you run and secure the endpoint; privacy duties |
| MemoryStore queue read by a tool | short-term buffer across servers | memory quota and request limits ([[MemoryStore Service]]); short expiry |
| DataStore | rarely right for logs | budgets shared with player data; avoid |

### 4.2 Shape of a good log event

- **Stable message** plus structured fields: `{ msg = "save failed", code = 301, jobTag = ..., version = ..., userId = ... }`.
- **Sampled** where volume is high: 1% of "remote rejected" events is enough to see patterns.
- **Batched**: one HTTP request per server per 30 to 60 seconds, not one per event.
- **Bounded**: a cap on events per batch and a drop counter ("dropped 4,212 events") so you know when you are blind.
- **No secrets**: never put API keys in game scripts that ship logs (keep them in Secrets, Docs: `HttpService:GetSecret`, as of October 2026), never log chat text.

### 4.3 Correlating a report

A player says "my sword vanished around 8 pm". With shipped logs you search by `userId` and time, find the job tag, then read all events from that server in that window: the trade at 19:58, the server shutdown at 20:01, the save that failed with a throttle error. Without them, you have a guess.

---

## 5. Feature flags as a debugging tool

A live config value that can switch a system off, or switch it to a safer path, without a publish ([[Global State and Live Config]]). For debugging:

- **Bisect live**: when a new release has a server-crashing bug and the cause is unclear, turn off new systems one by one through flags and watch the crash rate. This is bisection ([[The Debugging Method - Reproduce Isolate Bisect]]) without a publish cycle.
- **Canary**: enable a risky change for 5% of servers (hash the job id) and compare error rates with the rest.
- **Kill switch**: during an incident, stop the damage first, debug second.

A flag that is never tested in its "off" state is not a kill switch. Test both states before release ([[QA Checklists Before Release]]).

---

## 6. Open Cloud Luau Execution: what it is and is not (as of October 2026)

The Open Cloud Luau Execution API (Docs, marked stable) runs a Luau script in a **headless server** that loads a place or place version. The documented facts: game scripts do not auto-run, physics does not run, a task can run up to 5 minutes, scripts can be up to 4 MB, logs keep up to about 450 KB, at most ten incomplete tasks per place, and data model changes are local to the task unless saved. DataStore and other cloud-backed APIs make real calls.

So it does **not** let you inspect or change a running live server. It is useful for:
- Running your module tests against a published place version in CI ([[Automated Testing with TestEZ and Jest-Lua]]).
- Running support scripts (read a profile, check a migration) without opening Studio ([[Debugging DataStore Problems]]).
- Reproducing a pure-logic bug (a loot table, a damage formula) with the exact code of a given version.

Treat the API key as production access to all data.

---

## 7. Reproducing live-only bugs

When logs point at a cause but you still cannot reproduce in Studio:

1. **Add the missing ingredient** from section 1 to your Studio repro: network lag, eight clients, a 2-hour soak run, streaming radius, a phone.
2. **Test in a private live server** of a test experience with the same code, using cheat tooling to reach the state fast ([[Multi-Client and Live Testing]]).
3. **Replay the input**: if your logs include the sequence of remote calls a player made (sampled, for debugging), you can replay them against a test server with a debug script.
4. **Soak test**: leave a test server running with bots or scripted NPC load overnight and watch memory and heartbeat. Many live-only bugs are age-related, and the Performance dashboard shows memory by server age (Docs, [[Crash and Error Telemetry]]).

---

## 8. A worked example

**Report:** after a recent update, some servers become laggy after a few hours. Studio is fine.

1. **What differs?** Uptime and player count. Suspect age-related growth.
2. **Dashboard.** Server memory by server age climbs steadily in the new version, flat in the previous one ([[Crash and Error Telemetry]]).
3. **Join a long-running server** with a gated teleport. Developer Console, server Memory: `LuaHeap` growing. Script Profiler: a combat damage function takes more time per call than it should.
4. **State dump** for combat: `activeFights=3,400` in a server with 20 players. The table is never pruned.
5. **Explain.** The update added a fight record per hit target for an assist system; records are removed on the target's death, but NPCs despawned by the zone cleaner never "die", so their records stay forever.
6. **Fix.** Remove records on `Destroying` of the target, and cap the table size with a warning.
7. **Verify.** Soak test in a test experience for 3 hours with NPC churn: `activeFights` stays under 50.
8. **Guard.** The dump stays; a counter ships `activeFights` peak per server per hour.

---

## Common mistakes

- No job id or version in logs, so live reports cannot be matched to a server.
- Relying only on the Error Report for bugs that are not errors.
- Debug tooling added during the incident instead of before it.
- Admin remotes without gating, rate limits or input validation.
- `MessageOut` handlers that print (feedback loop).
- One HTTP request per log line.
- Expecting Open Cloud Luau Execution to reach running servers.
- Running untested "fix" code in a production console.

## Checklist

- [ ] Job tag and version logged at start, in every event, and visible in a menu.
- [ ] Gated admin commands: teleport to job, fetch server log, dump system state, raise log level temporarily.
- [ ] Every system registers a state dump.
- [ ] Logs shipped off-server, batched, sampled, bounded, with a drop counter and no personal data.
- [ ] Feature flags for new systems, tested in both states.
- [ ] Soak tests for age-related growth before major releases.
- [ ] API keys (HTTP sinks, Open Cloud) stored as secrets and treated as production credentials.

## See also

[[Debugging Start Here]] · [[Developer Console and Stats]] · [[Crash and Error Telemetry]] · [[Debugger Breakpoints and Logging]] · [[Live Incident Response and Post-Mortems]] · [[Global State and Live Config]] · [[Cross-Server Messaging]] · [[Open Cloud APIs]] · [[Hunting Memory Leaks Step by Step]] · [[Multi-Client and Live Testing]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Debugging]] · [[Telemetry Events]] · [[Skill - Roblox Performance Audit]] · [[Links - Error handling and debugging]] · [[Feature Flags]] · [[Memory Budgets and Leaks]]
<!-- auto-links:end -->
