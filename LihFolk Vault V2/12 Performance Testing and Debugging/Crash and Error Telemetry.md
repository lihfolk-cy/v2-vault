---
tags: [telemetry, errors, crashes, monitoring, scriptcontext, logservice, live-ops, type/guide, area/performance, level/intermediate, api/HttpService, area/liveops]
---
# Crash and Error Telemetry

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Relying only on player reports to learn about errors.
> - Avoid: Messages with ids and numbers in them.
> - Avoid: Treating client-reported errors as trustworthy.
> - Error Report reviewed after each release, filtered to new errors.
> - Ignore and Group rules maintained.
> - Error messages stable, variable data excluded.
>
> Cost: TL;DR ~120 tok · whole note ~4.5k tok. Read more: ## 1. What Roblox gives you · ## 3. A small error pipeline · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Once a game is live, you cannot attach a debugger to it. Thousands of servers and devices run your code in combinations you never tested, and the only way to know what breaks is telemetry: the built-in Creator Dashboard reports, plus whatever your own scripts collect. This note covers what Roblox gives you (Error Report, Performance dashboard), what it does not (client crash causes), how to capture script errors yourself with `ScriptContext.Error` and `LogService`, how to aggregate and rate-limit them so telemetry does not become the outage, and how to use all of it in release triage.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. What Roblox gives you

### Error Report (Docs)
Creator Dashboard, your experience, Monitoring, **Error Report**.
- Luau errors and warnings from **server and client**, near real time, with a chart of counts over time.
- Filters: last 1 hour, 1 day, 7 days or 30 days; place; severity; platform and OS (for client errors); **new errors since a version**; version annotations on the chart.
- Table: count, severity, type (server or client), message, first seen, first seen version (with one place selected); expand a row for the **stack trace**.
- **Rules**: up to 100 per experience, exact string or regex, evaluated top to bottom; **Ignore** hides matches, **Group** merges matches under one name. Rules apply only to errors logged after they are saved. Regex restrictions: no repeaters inside repeating groups, cannot start with a wildcard such as `.*`.
- **Tracking limits**: up to 500 unique errors and 500 unique warnings by count, plus the top 100 new errors per version; counts reset every 6 hours. Messages with dynamic values (user ids, coordinates) become separate entries.

That last point drives a design rule for your own error messages: **keep the variable part out of the message text**, or group it with a rule. `"Failed to load profile for 12345678"` produces one entry per player and burns the 500-entry budget; `"Failed to load profile"` with the id logged elsewhere produces one.

Community reports (DevForum, unverified by Docs) say Roblox core script errors can flood the report after an engine update; use Ignore rules for noise you cannot fix.

### Performance dashboard (Docs)
Monitoring, Performance. Requires at least **100 DAU** for client and server charts. Client tab: frame rate, **crash rate** (crashes divided by ended sessions; a dashed line means low sample counts, check crash count instead), **unexpected out-of-memory exits**, crash count, memory by device type, memory as a percentage of device memory, client CPU time. Server tab: CPU time, frame rate (cap 60), memory (keep under 50% and under about 3 GB as a guideline), memory by server age, cores used, compute efficiency. Breakdown by place version. Roblox update annotations mark engine releases (some platforms roll out gradually).

Docs triage guidance: investigate when crash rates exceed 2 to 3%, especially after an update.

### What is missing
- **Client crash causes.** A native crash or OS kill (out of memory, thermal) gives your scripts no event. You see it only as a rate on the dashboard. Correlate with memory charts, platform, and your release version.
- **Business-level failures.** A purchase that granted nothing, a quest that never completes: these are not Luau errors. You must emit your own signals (section 5).
- **Context.** The Error Report shows message and stack; it does not know the player's zone, equipped item or what they were doing. Your own telemetry can.

---

## 2. Capturing errors yourself

### `ScriptContext.Error`
`ScriptContext.Error(message: string, stackTrace: string, script: Instance)` fires when a script error is not caught (Docs give the signature; the page does not say whether `script` can be nil, so guard it). On the server it reports server script errors; on a client, that client's errors (rule of thumb: each side sees its own).

### `LogService.MessageOut`
Fires for every output message with its `Enum.MessageType` (Output, Info, Warning, Error). Use it to capture **warnings** and errors you log yourself (which do not throw). As of October 2026 the reference page also lists a `context` dictionary argument and newer logging methods; their semantics are not described there (unverified).

### Errors you catch
Anything you `pcall`/`xpcall` never reaches `ScriptContext.Error`. Report those explicitly from the handler ([[Debugger Breakpoints and Logging]]).

---

## 3. A small error pipeline

Goals: deduplicate, rate-limit, keep personal data out, never let telemetry itself cause lag or errors.

### Server collector

```lua
--!strict
-- ServerScriptService/ErrorCollector.server.luau
local Players = game:GetService("Players")
local ScriptContext = game:GetService("ScriptContext")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VERSION = game.PlaceVersion
local WINDOW = 60 -- seconds between flushes
local MAX_KEYS = 200 -- distinct errors kept per window
local CLIENT_REPORTS_PER_MIN = 10

type Bucket = { side: string, message: string, trace: string, count: number }
local buckets: { [string]: Bucket } = {}
local keyCount = 0

-- Strip variable parts so the same bug groups together.
local function normalise(message: string): string
	local s = message:gsub("%d+%.?%d*", "#") -- numbers
	s = s:gsub("0x%x+", "#") -- addresses
	return s:sub(1, 300)
end

local function record(side: string, message: string, trace: string)
	local key = side .. "|" .. normalise(message)
	local b = buckets[key]
	if b then
		b.count += 1
		return
	end
	if keyCount >= MAX_KEYS then
		return -- full: drop rather than grow without bound
	end
	keyCount += 1
	buckets[key] = { side = side, message = normalise(message), trace = trace:sub(1, 1000), count = 1 }
end

ScriptContext.Error:Connect(function(message: string, trace: string, _script: Instance?)
	record("server", message, trace)
end)

-- Clients report their own errors through a rate-limited remote.
local Report = Instance.new("RemoteEvent")
Report.Name = "ClientErrorReport"
Report.Parent = ReplicatedStorage

local allowance: { [Player]: { n: number, reset: number } } = {}

Report.OnServerEvent:Connect(function(player: Player, message: unknown, trace: unknown)
	if type(message) ~= "string" or type(trace) ~= "string" then
		return -- untrusted input: validate types
	end
	local now = os.clock()
	local a = allowance[player]
	if not a or now > a.reset then
		a = { n = 0, reset = now + 60 }
		allowance[player] = a
	end
	if a.n >= CLIENT_REPORTS_PER_MIN then
		return
	end
	a.n += 1
	record("client", message:sub(1, 500), trace:sub(1, 2000))
end)

Players.PlayerRemoving:Connect(function(player: Player)
	allowance[player] = nil
end)

local function flush()
	if keyCount == 0 then
		return
	end
	local batch = buckets
	buckets, keyCount = {}, 0
	for _, b in batch do
		-- Replace with your sink: AnalyticsService custom events, an external
		-- endpoint via HttpService (batched; mind the per-server request limit),
		-- or a MemoryStore queue read by a tool.
		warn(("[telemetry v%d] %s x%d: %s"):format(VERSION, b.side, b.count, b.message))
	end
end

task.spawn(function()
	while true do
		task.wait(WINDOW)
		local ok, err = pcall(flush)
		if not ok then
			-- Never let telemetry errors feed back into telemetry in a loop.
			print("[telemetry] flush failed: " .. tostring(err))
		end
	end
end)

game:BindToClose(function()
	pcall(flush)
end)
```

### Client reporter

```lua
--!strict
-- StarterPlayerScripts/ErrorReporter.client.luau
local ScriptContext = game:GetService("ScriptContext")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Report = ReplicatedStorage:WaitForChild("ClientErrorReport") :: RemoteEvent
local sent: { [string]: boolean } = {}
local sentCount = 0

ScriptContext.Error:Connect(function(message: string, trace: string, _script: Instance?)
	-- Send each distinct message once per session, at most 20 in total.
	if sent[message] or sentCount >= 20 then
		return
	end
	sent[message] = true
	sentCount += 1
	Report:FireServer(message:sub(1, 500), trace:sub(1, 2000))
end)
```

Design notes:
- **Two layers of limits**: the client sends each distinct message once and caps totals; the server rate-limits per player and caps distinct keys. A bug that errors every frame on 30 clients must not become 1,800 remote calls per second ([[Rate Limiting and Abuse Prevention]]).
- **Clients can lie.** Treat client reports as hints, never as facts for gameplay or moderation. Validate types and lengths.
- **Normalise** numbers so one bug is one bucket.
- **Version** every report (`game.PlaceVersion`) so you can say "new in version N".
- **The flush is protected**; a telemetry bug must not crash or spam.
- **External sinks** (HttpService) are batched per window; HttpService has a per-server request limit (about 500 per minute), so one request per window is safe ([[HttpService and External APIs]]).
- **Privacy**: no chat text, no personal data in messages. UserIds only if you need them, and handle deletion requests for anything stored externally ([[Player Privacy and Data Deletion]]).

---

## 4. Signals beyond errors

Some failures never error. Emit counters for them:

| Signal | Why |
|---|---|
| Purchase receipt processed vs granted | catches grant bugs ([[Developer Products and ProcessReceipt]]) |
| DataStore save failures and retries | early warning for data loss ([[Data Loss Prevention and Recovery]]) |
| Session lock conflicts | rejoin bugs |
| Join time (client measured from ReplicatedFirst to first playable frame) | load regressions |
| Server heartbeat worst frame per minute | server performance regressions |
| Remote validation rejects per remote | exploit attempts or client bugs ([[Server Authority and Validation]]) |
| Watchdog: "stuck" players (no movement and no input for N minutes in a combat zone) | soft-locks |

Funnels and custom events are covered in [[Analytics and Funnels]].

---

## 5. Release triage routine

**First hour after a release** (rule of thumb):
1. Error Report: filter **new errors since this version**. Anything with a high count goes to the top.
2. Performance dashboard: crash rate and OOM exits by platform, compared with the previous version (breakdown by place version).
3. Your own counters: purchases granted, saves failing, join time.
4. Server Developer Console in one live server: memory baseline, heartbeat, log.
5. Community channels for reports that telemetry cannot see (visual bugs, confusing UI).

**Decide**: hotfix, disable by feature flag, or roll back ([[Release Process and Rollbacks]], [[Global State and Live Config]]). A feature flag that turns off a broken system is often faster and safer than a rollback, which also reverts good changes.

**Daily**: Error Report top 10 by count; add Ignore rules for noise you cannot fix; Group rules for one bug with varying messages.

**Weekly**: crash and memory trends by platform; review whether any new error persists across versions (a bug that "everyone knows about" and nobody fixes).

---

## 6. Failure modes of telemetry itself

| Problem | Symptom | Fix |
|---|---|---|
| Error inside an error handler | infinite loop of reports | handlers protected, never log through the same path |
| Per-error HTTP request | HttpService limit hit, other HTTP calls fail | batch per window |
| Unbounded buckets | server memory growth during an error storm | cap distinct keys |
| Dynamic messages | Error Report fills its 500 unique slots in minutes | normalise, group rules |
| Client spam | remote flood | per-session dedupe plus server rate limit |
| Logging personal data | privacy and policy risk | strip at source |

---

## Common mistakes

- Relying only on player reports to learn about errors.
- Messages with ids and numbers in them.
- Treating client-reported errors as trustworthy.
- No version on reports, so "is this new?" is unanswerable.
- Telemetry with no rate limits.
- Ignoring the crash-rate chart because "there are no errors": crashes are often memory, not script errors.

## Checklist

- [ ] Error Report reviewed after each release, filtered to new errors.
- [ ] Ignore and Group rules maintained.
- [ ] Error messages stable, variable data excluded.
- [ ] `ScriptContext.Error` collected on server and client, deduplicated, rate-limited, versioned.
- [ ] Counters for purchases, saves, join time, server heartbeat.
- [ ] Performance dashboard crash and OOM rates checked by platform per version.
- [ ] A feature-flag kill switch exists for risky systems.

## See also

[[Debugger Breakpoints and Logging]] · [[Developer Console and Stats]] · [[Analytics and Funnels]] · [[Release Process and Rollbacks]] · [[Live Ops Events and Updates]] · [[Error Handling and Retries]] · [[HttpService and External APIs]] · [[Rate Limiting and Abuse Prevention]] · [[QA Checklists Before Release]]

## Nuances and edge cases

1. **Error counts scale with players, not with bugs.** A bug hit once per session produces 10 reports a day at launch and 10,000 a day after a front-page feature. Rank errors by affected players or sessions, not raw count, or a noisy harmless warning will bury a rare save failure. Report "unique sessions affected" per error signature.
2. **Deduplicate on the sender, aggregate on the server.** A client stuck in a broken loop can produce the same error 60 times a second. Each client should send a given signature at most once per window (for example, once a minute with a count), and each server should batch before forwarding. Otherwise telemetry itself becomes a bandwidth and HTTP budget problem.
3. **HttpService has a request budget.** Outbound HTTP from a server is rate limited (Roblox docs, as of October 2026: 500 requests per minute per game server; going over can stall requests for about 30 seconds). A server that sends one HTTP request per error will hit the limit during an incident, which is exactly when you need data. Buffer, batch and drop with a counter of what was dropped.
4. **Client reports are hints, not facts.** Exploiters can send fake errors, flood your endpoint, or inject text. Rate-limit the reporting remote, cap message length, strip anything that looks like personal data, and never let report content drive automatic actions such as bans.
5. **Crashes leave no Luau error.** A client killed by out-of-memory on a low-end phone never reaches your reporting code. Infer crashes from session data instead: a session that started but sent no clean "leaving" marker and has no heartbeat after a certain time. Compare that rate by device type and memory tier.
6. **Platform skew.** Phones produce more memory and timing-related errors; consoles expose UI and input paths nobody tested on PC. Always tag reports with platform, device tier and build version so you can tell "a new bug" from "an old bug on a new audience".
7. **Signatures must strip variable parts.** An error message containing a player name, an instance path with a unique number or a stud position never groups. Normalise digits and quoted names out of the message before hashing.
8. **Privacy is a real constraint.** Reports should carry an anonymous session id, not usernames, and must be deletable if you store anything tied to a user (see [[Player Privacy and Data Deletion]]).

The senior trade-off: more telemetry means more cost, more noise and more privacy surface. Start with three signals that change decisions (error signatures by version, save failures, session crashes by device) and add others only when you have a question they answer.

## Common mistakes (advanced)

1. **One HTTP request per error.** Symptom: telemetry stops during incidents, HTTP errors in output. Fix: batch per server every 30 to 60 seconds.
2. **No build version on reports.** Symptom: cannot tell whether a fix worked. Fix: put a version string in a shared module and include it on every report.
3. **Logging stack traces with player names inside.** Symptom: reports never group, and personal data ends up in a third-party service. Fix: normalise and anonymise before sending.
4. **Treating "zero errors" as healthy.** Symptom: player complaints about crashes while dashboards look clean. Fix: track session ends without a clean exit.
5. **Alert thresholds in absolute numbers.** Symptom: alerts fire every evening at peak and never at night. Fix: alert on rate per thousand sessions.
6. **Reporting from inside `pcall` handlers that retry.** Symptom: one failed save produces five reports. Fix: report the final outcome of a retried operation, plus a retry count.

## Related decisions

- [[Live Incident Response and Post-Mortems]]: what to do when telemetry shows a spike.
- [[HttpService and External APIs]]: request budgets and batching for outbound reports.
- [[Debugging Live Servers]]: using telemetry to pick which server to inspect.
- [[Reading Luau Errors and Stack Traces]]: building good signatures from traces.
- [[Logging Bans and Appeals]]: keeping security logs separate from crash telemetry.
- [[Feature Flags and Staged Rollouts]]: correlating error spikes with rollouts.
- [[Release Process and Rollbacks]]: version tags that make error data actionable.
- [[Player Privacy and Data Deletion]]: what may be stored in reports.
- [[Analytics and Funnels]]: session markers shared with gameplay analytics.

## Connected notes
<!-- auto-links:start -->
[[Telemetry Events]] · Links - Error handling and debugging · Debugging Start Here · [[Mobile and Low-End Optimization]] · Rate Limiting · Error Handling - pcall xpcall and Promise Patterns
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[In-Game Bug Report Button with Automatic Context]] · [[Feature Flags]] · [[Economy Telemetry and Balancing Live]] · [[Error Handling - pcall xpcall and Promise Patterns]] · [[Economy Exploits - Dupes Races and Purchase Abuse]] · [[Multi-Client and Device Playtesting Protocols]]
<!-- related:end -->
