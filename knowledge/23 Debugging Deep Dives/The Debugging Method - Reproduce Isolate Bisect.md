---
tags: [debugging, method, bisect, repro, minimal-repro, process]
---
# The Debugging Method - Reproduce Isolate Bisect

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Starting to change code before having a repro.
> - Avoid: Fixing the visible wrong value instead of the first wrong value.
> - Avoid: Bisecting in a shared place and breaking other people's tests.
> - Repro written down with start state, steps, expected, actual and a rate.
> - Cheat service, test profiles and seeded RNG exist, Studio-gated.
> - Server or client answered first.
>
> Cost: TL;DR ~140 tok · whole note ~4.5k tok. Read more: ## 2. Reproduce · ## 4. Bisect · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Debugger Breakpoints and Logging]] gives a five-step outline (reproduce, locate, explain, fix, verify). This note goes deeper into the part where most time is lost: getting from "it sometimes breaks" to "this line, with this value, in this order". The core moves are the same in every engine. The Roblox-specific parts are how you get a repeatable state, how you cut a place down to the smallest thing that still breaks, and how you bisect when the bug lives in a 400-script place that several people edit.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. Why a method at all

Debugging by intuition works when the bug is near the code you just wrote. It fails badly in three situations that are common in Roblox:

- **The symptom is far from the cause.** A UI shows the wrong coin count. The cause is a DataStore migration that ran twice, three systems away.
- **The bug depends on timing.** Client and server run on different machines, replication is batched, and `SignalBehavior` defers handlers. Things that "never happen" in Play Solo happen on a phone on 4G.
- **The place is shared.** Other people edit and test the same place. Your mental model of the code is already out of date.

A method stops you guessing. Each step produces something concrete (a written repro, a smaller place, a narrowed commit range), so even a failed hour leaves you closer.

---

## 2. Reproduce

A bug you cannot reproduce on demand cannot be fixed with confidence. You can only change code and hope. So the first job is a **repro script**: written steps, from a known starting state, that show the bug at least most of the time.

### 2.1 Write the repro down

Format that works (rule of thumb):

```
Start: fresh data, Studio, 2 clients, network latency 200 ms
1. Client A equips the bow.
2. Client A opens inventory, unequips, re-equips within 1 s.
3. Client B looks at A.
Expected: B sees the bow on A's back.
Actual: B sees nothing; A sees the bow. 7 of 10 attempts.
```

The last line matters. "7 of 10" tells you the bug is timing-sensitive, and gives you a baseline: after a fix, 0 of 20 is evidence; 0 of 3 is not.

### 2.2 Get to the state fast

Most repros fail because reaching the state takes ten minutes of grinding. Build the tools once:

- A **gated cheat service** (Studio and allow-listed developers only) that sets level, grants items, teleports to zones and fires world events. The pattern is in [[Multi-Client and Live Testing]].
- **Test profiles**: a way to load a named fake profile instead of the real one ("fresh", "endgame", "legacy schema v3"). Keep test keys away from real player keys ([[Session Locking and Profile Libraries]] covers the trap of leaving a test key set).
- **Seeded randomness**: any RNG the bug depends on should accept a seed in Studio. `Random.new(seed)` makes drops, spawns and AI choices repeatable.

```lua
--!strict
-- Shared/Rng.luau: one place to make randomness repeatable in Studio.
local RunService = game:GetService("RunService")

local Rng = {}

local seedAttr = workspace:GetAttribute("DebugSeed") -- set by hand in Studio
local seed: number = if RunService:IsStudio() and typeof(seedAttr) == "number"
	then seedAttr
	else (os.time() + math.floor(os.clock() * 1000))

local generator = Random.new(seed)

function Rng.seed(): number
	return seed
end

function Rng.integer(min: number, max: number): number
	return generator:NextInteger(min, max)
end

function Rng.number(): number
	return generator:NextNumber()
end

return Rng
```

Log the seed at server start. When a tester reports "the boss dropped two legendaries", the seed lets you replay the exact rolls, as long as the order of calls is the same. (One shared generator is only repeatable if the sequence of calls is; per-system generators are more robust.)

### 2.3 Turn intermittent into reliable

If the bug shows 1 time in 30, change conditions until it shows more often. Each change that raises the rate is also a clue.

| Lever | How in Roblox | What a higher rate tells you |
|---|---|---|
| Latency | Studio network simulation (incoming replication lag) | ordering or replication timing |
| Low frame rate | a throwaway script that burns CPU each frame on the client | per-frame logic assumes a frame length |
| More clients | multi-client test with 3 to 8 players | contention, shared state, ownership |
| Spam the action | an auto-clicker loop in a debug script | missing debounce, race between requests |
| Slow storage | wrap your DataStore layer with an artificial `task.wait(2)` in Studio | load-order assumptions |
| Streaming | enable `StreamingEnabled`, shrink the target radius | client assumes an instance exists |

A good trick is the **injected delay**: put `task.wait(math.random() * 0.5)` before a suspicious step in Studio only. If the failure rate jumps, you have found the race. [[Debugging Race Conditions and Yield Order]] goes further.

### 2.4 When you cannot reproduce

Then reproduce in the logs instead. Add tagged debug logging at the boundaries of the systems involved, ship it (at `warn` level or gated per tag), and wait for the next report. Each report should come with: place version, server job id, platform, time, and the player's recent actions. [[Debugging Live Servers]] covers collecting this without flooding anything.

---

## 3. Isolate

Once you can reproduce, shrink the search space. Two ways: shrink the **code** (which system?) and shrink the **data** (which input?).

### 3.1 Find the first wrong value

Every bug is a chain: correct input, some step produces a wrong value, later steps faithfully propagate it. You are looking for the **first** wrong value, not the most visible one.

Work backward from the symptom:
1. The UI shows 0 coins. Is the attribute on the player 0? (Client/Server toggle, or print on the client.)
2. Is the server value 0? If the server says 1,500 and the client says 0, it is a replication or UI bug ([[Debugging Client-Server Desync]]). If the server says 0, keep going.
3. Was the profile loaded with 0, or did something set it to 0 later? A conditional breakpoint or a logged setter tells you.

A **tripwire** catches the moment a value goes wrong without stepping through everything:

```lua
--!strict
-- Studio-only tripwire: report the first time an attribute takes a bad value.
local RunService = game:GetService("RunService")

local function tripwire(inst: Instance, attr: string, isBad: (any) -> boolean)
	if not RunService:IsStudio() then
		return
	end
	local fired = false
	inst:GetAttributeChangedSignal(attr):Connect(function()
		local v = inst:GetAttribute(attr)
		if not fired and isBad(v) then
			fired = true
			warn(("[tripwire] %s.%s became %s\n%s"):format(
				inst:GetFullName(), attr, tostring(v), debug.traceback("", 2)))
		end
	end)
end

-- Example: coins should never drop below zero or become NaN.
tripwire(somePlayer, "Coins", function(v)
	return typeof(v) ~= "number" or v < 0 or v ~= v
end)
```

Caveat: the traceback here is the traceback of the **signal handler**, not of the code that set the attribute. Attribute signals do not tell you who wrote the value; with deferred signals the writer has already moved on. To catch the writer, funnel writes through one setter function and put the check (and a `debug.traceback()`) there. That is one more argument for a single owner of each piece of state.

### 3.2 Shrink the data

If the bug happens with one player's profile and not with a fresh one, the data is the input to isolate. Load a copy of that profile under a test key (never edit the real key while investigating, see [[Debugging DataStore Problems]]), then delete half of the fields or items and retry. Repeat. Within six or seven rounds a 100-item inventory is down to the one item whose old schema breaks the loader.

### 3.3 Ask "which side?"

In Roblox the first isolation question is almost always "server or client?". Answer it before anything else:
- Error text in Output is green for server and blue for client during play tests (Docs).
- `RunService:IsServer()` printed in the code path.
- The Client/Server toggle shows each DataModel.

Many hours are lost debugging the server copy of a ModuleScript when the failing call was on the client (or the other way round).

---

## 4. Bisect

Bisection is binary search over anything ordered: scripts, commits, place versions, data, frames. It needs only one thing: a yes/no test (the repro). With N candidates it needs about log2(N) tests. 400 scripts: 9 tests. 1,000 commits: 10 tests.

### 4.1 Bisecting by disabling scripts

When you do not know which system causes a bug (a freeze, a memory climb, a stray error at join), disable half the scripts and test.

Rules that make it work:
- **Work on a copy.** File, Save to File As, or a separate test place. Never bisect in the live shared place: disabling scripts there breaks other people's tests ([[Safe Changes in a Shared Place]]).
- **Disable, do not delete.** `Script.Enabled = false` (Docs: disabling stops the script; re-enabling runs it again). ModuleScripts cannot be disabled, so bisect the scripts that require them.
- **Respect dependencies.** If script B waits for something A creates, disabling A makes B hang. That is not the bug; it is a new failure. Bisect by system (groups of scripts that belong together), not file by file.
- **Record each step.** "Half A off: bug gone. A1 off: bug present. A2 off: bug gone..."

A command bar helper for a test copy:

```lua
-- Command bar (Edit mode, on a COPY of the place): list and toggle server scripts by folder.
local function setFolder(folder: Instance, enabled: boolean)
	local n = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("Script") then -- includes LocalScript (subclass of Script)
			d.Enabled = enabled
			n += 1
		end
	end
	print(folder:GetFullName(), enabled and "enabled" or "disabled", n)
end

setFolder(game.ServerScriptService.Systems.Combat, false)
```

Note: in current Studio, `LocalScript` inherits from `Script`, so `IsA("Script")` matches both (rule of thumb from the class hierarchy; check `ClassName` if you need to separate them). Scripts with `RunContext` set behave like their context, not their location ([[Script Types and Run Context]]).

### 4.2 Bisecting by version

"It worked last week" is a gift: the bug lives between two versions.

- **With Rojo and Git**: `git bisect start`, mark a known bad and known good commit, build and test each step, mark good or bad. Git picks the midpoint. This is the cleanest option and the main reason to keep code in Git ([[Git and Source Control for Roblox]]).
- **Without Git**: Version History (Docs: published versions of a place are listed with dates and can be restored) gives you older builds. Restore a version midway in time into a separate test place (never into the live place), test, repeat. See [[Version History and Backups]] for how to do this safely. It is slower, and data in DataStores is shared between versions, so a bug caused by stored data shows in old versions too. That itself is a useful result: if every old version shows the bug, suspect data, not code.
- **Packages and dependencies**: a package auto-update can change behaviour without a commit in your repo. Check package versions when the commit range contains nothing suspicious ([[Packages and Asset Reuse]]).

### 4.3 Bisecting in time

For bugs that appear "after a while" (memory growth, a frame-time climb, a desync that builds up), bisect in time: log a value every 30 seconds and find the first interval where it changed. The full memory version of this is in [[Hunting Memory Leaks Step by Step]].

---

## 5. Minimal repro places

A minimal repro is a small place that shows the bug with as little else as possible. It is the strongest debugging tool there is, for three reasons:

1. Building it often reveals the cause (you find which part is required).
2. It separates "my bug" from "engine bug". If a 20-line place with one part and one script shows it, it is probably not your game's architecture.
3. It is what an engine bug report on the DevForum needs. Reports with a repro file get attention; reports with a video of a full game rarely do.

How to build one:
1. New baseplate.
2. Copy only the instances the bug touches (a model, a ScreenGui), not the whole game.
3. Replace your frameworks with direct code. If the bug disappears when you remove your framework, the framework is involved.
4. Remove things one at a time until removing anything makes the bug vanish. What remains is the repro.
5. Write the expected and actual behaviour in a comment at the top of the script.

When not to: if the bug obviously depends on the interaction of many systems with real data (an economy exploit, a matchmaking stall), a minimal place costs more than it saves. Use logs and bisection in a test copy instead.

---

## 6. Explain before you fix

The rule from [[Debugger Breakpoints and Logging]] bears repeating with an example of what goes wrong without it.

**Measured case, with a counterfactual.** In the reference project, an inventory click occasionally froze the client, only for rare items, so it looked random. The cause was an unbounded retry loop that tried to parent a decoration to a frame the click had just destroyed. The fix was a cap on the loop plus a check for a gone parent. Now imagine the tempting guess: a `task.wait()` in the click handler. It would have changed the timing, the freeze would have become rarer, and the bug would have looked fixed while the unbounded loop stayed in the code.

Signs a fix is a guess:
- It adds a `task.wait` or a longer timeout.
- It wraps something in `pcall` and ignores the error.
- It works "most of the time".
- You cannot say, in one sentence, what sequence of events produced the bad value.

---

## 7. Verify, then guard

After a fix:
1. Run the original repro, under the conditions that made it frequent (latency, many clients). Use the same count: if it failed 7 of 10, run 20.
2. Remove any injected delays and debug toggles.
3. Leave a **guard** that would catch the bug or its family next time: an assertion at the boundary, a validation on the remote, a unit test for pure logic ([[Automated Testing with TestEZ and Jest-Lua]]), or a tripwire that stays on in Studio.
4. Write one line in your changelog or bug log: symptom, cause, fix. Over time this log is the most valuable debugging document you own ([[Documentation and Knowledge Bases]]).

---

## 8. Heisenbugs: when debugging changes the bug

Some bugs vanish when observed:

| You add | It changes | So |
|---|---|---|
| A breakpoint | timing; other machines keep running | use timestamped logs for races |
| A `print` with `GetFullName()` on many instances | frame time | log only on change, rate-limit |
| `WaitForChild` in a debug script | the moment the script resumes | read with `FindFirstChild` and log nil |
| A second client | network ownership and load | test with and without |

If a bug vanishes under the debugger, that itself says "timing". Move to logs with `os.clock()` timestamps and sequence numbers.

---

## 9. A worked session

Symptom report: "Sometimes after rejoining, my pet is gone."

1. **Reproduce.** Fresh test profile, equip a pet, leave, rejoin. 0 of 10. Add latency: 0 of 10. Leave and rejoin within 3 s: 4 of 10. The quick rejoin matters.
2. **Isolate.** Which side? Server profile on rejoin has no pet. So it is data. Was it saved? The save log shows the leave-save started but the new server loaded first.
3. **Explain.** On a fast rejoin, the new server read the key before the old server's leave-save landed. The new server then saved its stale copy over the good one. This is the classic missing session lock ([[Session Locking and Profile Libraries]]).
4. **Fix.** Use the lease-based profile module; the second server waits for the lease.
5. **Verify.** Fast rejoin 0 of 20, with latency.
6. **Guard.** A server counter for "load waited for lease" so you can see how often it happens live ([[Crash and Error Telemetry]]).

Total: six tests and one read of a log. Without the method, the common outcome is a `task.wait(5)` before loading and a bug that returns at peak hours.

---

## Common mistakes

- Starting to change code before having a repro.
- Fixing the visible wrong value instead of the first wrong value.
- Bisecting in a shared place and breaking other people's tests.
- Bisecting file by file through dependent scripts and chasing hangs you created.
- Declaring a timing bug fixed after three clean runs.
- Using Version History bisection for a bug that lives in stored data.
- Leaving injected delays or debug seeds enabled in a published build.

## Checklist

- [ ] Repro written down with start state, steps, expected, actual and a rate.
- [ ] Cheat service, test profiles and seeded RNG exist, Studio-gated.
- [ ] Server or client answered first.
- [ ] First wrong value found (tripwire or single setter).
- [ ] Bisection done on a copy, by system, with each step recorded.
- [ ] Cause explained in one sentence before the fix.
- [ ] Verified with at least twice the original run count under stress conditions.
- [ ] A guard left behind, and one line written in the bug log.

## See also

[[Debugging Start Here]] · [[Debugger Breakpoints and Logging]] · [[Multi-Client and Live Testing]] · [[Testing Modes - Play Run and Multi-Client]] · [[Reading Luau Errors and Stack Traces]] · [[Debugging Race Conditions and Yield Order]] · [[Git and Source Control for Roblox]] · [[Version History and Backups]] · [[Hunting Memory Leaks Step by Step]] · [[Troubleshooting Table]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Debugging]] · [[Debugging Animation Problems]] · [[MCP Workflows for Scripting and Debugging]] · [[Links - Error handling and debugging]] · [[Case Study - Abilities That Only Worked in Studio]] · [[Deterministic Simulation]]
<!-- auto-links:end -->
