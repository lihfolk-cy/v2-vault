---
tags: [testing, qa, time, daily-rewards, streaks, live-ops, luau, type/guide, area/testing, level/intermediate, area/performance, area/scripting]
---
# Testing Time-Based Features with a Controllable Clock

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Calling `os.time()` directly in five systems, so time travel only half works.
> - Avoid: Using the client's clock for claims.
> - Avoid: Testing by waiting real time, so boundary cases never get tested.
> - One Clock module; no stray `os.time(` or `DateTime.now(` elsewhere.
> - Pure functions take `now`; boundary specs exist for each time feature.
> - Negative durations clamped; caps on long absences.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## 2. The clock service · ## 3. Boundary cases every time feature must pass · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Daily rewards, login streaks, limited-time events, offline earnings, cooldowns that span sessions and weekly resets all depend on the wall clock. Testing them by waiting is useless (a streak needs seven real days) and testing them by editing saved timestamps by hand is error-prone. The fix is an **injectable clock**: one module every time-based system asks for "now", which tests and gated QA commands can shift, freeze or fast-forward without touching the systems themselves.

[[Automated Testing with TestEZ and Jest-Lua]] introduces clock injection for unit tests. This note goes further: a shared clock service for the running game, the boundary cases every time feature must survive, and how QA uses it in a live test server.

---

## 1. Which clock for what

| Need | Use | Why |
|---|---|---|
| Calendar logic: "new day", streaks, event start and end | `os.time()` or `DateTime.now().UnixTimestamp` on the **server** | Unix seconds, UTC; the same on every server (Roblox docs: [os](https://create.roblox.com/docs/reference/engine/libraries/os), [DateTime](https://create.roblox.com/docs/reference/engine/datatypes/DateTime)) |
| Countdown shown to the client that must match the server | `workspace:GetServerTimeNow()` | Server-synchronised time readable on the client (Roblox docs: [Workspace](https://create.roblox.com/docs/reference/engine/classes/Workspace)) |
| Short durations inside one server (cooldowns, tweens) | `os.clock()` | Monotonic, high resolution, not wall time |

Never trust a client's time for anything that grants value. A player can change their device clock.

---

## 2. The clock service

```lua
--!strict
-- ReplicatedStorage/Shared/Clock (ModuleScript)
-- Single source of "now" (Unix seconds) for every time-based system.
local RunService = game:GetService("RunService")

local Clock = {}

local offset = 0          -- seconds added to real time
local frozenAt: number? = nil

local function real(): number
	if RunService:IsServer() then
		return os.time()
	end
	return workspace:GetServerTimeNow()
end

function Clock.now(): number
	if frozenAt then
		return frozenAt
	end
	return real() + offset
end

-- UTC day index; the "day" every daily system agrees on.
function Clock.day(t: number?): number
	return (t or Clock.now()) // 86400
end

-- QA controls. Call only from gated server code (see section 4).
function Clock.advance(seconds: number)
	if frozenAt then
		frozenAt += seconds
	else
		offset += seconds
	end
end

function Clock.freeze(at: number?)
	frozenAt = at or Clock.now()
end

function Clock.unfreeze()
	frozenAt = nil
end

function Clock.offset(): number
	return offset
end

return Clock
```

Rules for systems that use it:

- **Every** time-based system calls `Clock.now()` or `Clock.day()`. A single stray `os.time()` makes QA time travel inconsistent: the streak thinks it is Thursday and the shop thinks it is Monday.
- Pure logic takes `now` as a parameter (`DailyReward.canClaim(data, now)`), so unit tests do not need the service at all.
- If the client shows countdowns, replicate the offset (an attribute on `ReplicatedStorage` set by the server) and add it on the client. The module above leaves that wiring to you.

A LihFolk audit habit: `script_grep` (Studio MCP) or `rg` for `os.time(` and `DateTime.now(` outside the Clock module. Each hit is a system QA cannot time-travel.

---

## 3. Boundary cases every time feature must pass

Write these as unit tests against the pure functions, with explicit timestamps:

| Case | Example | Expected |
|---|---|---|
| Exactly at the boundary | claim at `day * 86400` | Counts as the new day |
| One second before | `day * 86400 - 1` | Still the old day |
| Two claims in one day | claim, `advance(3600)`, claim | Second claim rejected |
| Skipped a day | claim, `advance(2 * 86400)`, claim | Streak resets or uses grace, per design |
| Long absence | `advance(400 * 86400)` | No overflow, no giant offline payout beyond the cap ([[Offline Earnings]]) |
| Clock went backwards | saved `lastClaim` is in the future (server clock skew or corrupted data) | Treated safely: no negative durations, no infinite rewards |
| Event window | `now` before start, inside, after end, exactly at end | Feature on only inside; end is exclusive or inclusive, written down |
| First ever claim | `lastClaim == nil` | Works, does not crash on nil arithmetic |
| Daylight saving and time zones | none if you use UTC day indices | Pick UTC; document the reset hour for players |

```lua
-- Example spec shape (TestEZ / Jest-Lua style)
local DAY = 86400
it("resets streak after a missed day", function()
	local data = { streak = 3, lastClaimDay = 100 }
	local result = DailyReward.claim(data, 102 * DAY + 10) -- day 102: day 101 was missed
	expect(result.streak).toBe(1)
end)
```

The "clock went backwards" row matters: the saved timestamp is data, and data can be wrong. Clamp `math.max(0, now - last)` before any duration math.

---

## 4. QA time travel in a running server

For playtests, expose the clock through gated commands ([[Gated Tester Commands and Debug Panels]]): `/time +1d`, `/time +6h`, `/time freeze`, `/time reset`. The handler runs on the server, checks the caller's permission, calls `Clock.advance`, and re-evaluates time-dependent state (refresh the daily reward UI, re-check event windows).

Important consequences:

- **Saved data written while time-shifted carries future timestamps.** Use test accounts and a test universe, or the tester's real save ends up "in the future" and a real-time claim fails tomorrow. A safe pattern: refuse to enable time travel unless the place id is a known test place.
- The offset is per server. Two testers in different servers see different "nows"; that is fine, but write it in the test notes.
- Reset the offset on server start. Never persist it.

---

## 5. What to test end to end

- **Daily reward:** claim, `+1d`, claim; `+2d`, claim (streak rule); rejoin between claims ([[Daily Rewards System End to End]]).
- **Streaks:** reach the milestone day, check the bonus, miss one day, check the reset or grace ([[Login Streaks]]).
- **Events:** freeze at one second before start, then advance one second; the event should open without a server restart ([[Live Ops Events and Updates]]).
- **Offline earnings:** leave, `advance` on the server you rejoin (or edit the saved timestamp in the test universe), check the payout against the cap.
- **Weekly resets and leaderboards:** cross the week boundary in a frozen clock and check the board key changes once.

---

## Common mistakes

- Calling `os.time()` directly in five systems, so time travel only half works.
- Using the client's clock for claims.
- Testing by waiting real time, so boundary cases never get tested.
- No guard for saved timestamps in the future.
- Time travel enabled in the live game, or offsets saved to data.
- Local-time "midnight" resets that drift with daylight saving.

## Checklist

- [ ] One Clock module; no stray `os.time(` or `DateTime.now(` elsewhere.
- [ ] Pure functions take `now`; boundary specs exist for each time feature.
- [ ] Negative durations clamped; caps on long absences.
- [ ] QA time commands gated to test places and permitted users.
- [ ] Offset never saved; reset on server start.
- [ ] Reset hour (UTC) documented for players.

## See also

- [[Automated Testing with TestEZ and Jest-Lua]], [[Testing Strategies and Frameworks]]
- [[Daily Rewards System End to End]], [[Login Streaks]], [[Offline Earnings]], [[Event Calendars and Content Planning]]
- [[Gated Tester Commands and Debug Panels]]

## Connected notes

[[Retention and Return Hooks]] · Live Ops Events and Updates · Feature Flags and Staged Rollouts · [[Genre QA Passes - Test Checklists per Game Type]]

<!-- related:start -->
## Related
[[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]] · [[Save Migration Tests - Fixture Saves and Golden Files]] · [[Automated Luau Checks - LihFolk Hook and Audit]] · [[QA Checklists Before Release]] · [[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]] · [[In-Game Bug Report Button with Automatic Context]] · [[Multi-Client and Device Playtesting Protocols]] · [[UI Automation with VirtualInput and StudioTestService]]
<!-- related:end -->
