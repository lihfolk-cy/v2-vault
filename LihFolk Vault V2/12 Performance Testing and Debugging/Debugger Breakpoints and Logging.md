---
tags: [debugging, debugger, breakpoints, logging, logservice, traceback]
---
# Debugger Breakpoints and Logging

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Print-driven debugging with prints that never get removed (or that get removed and re-added weekly).
> - Avoid: Breakpoints without a context, stopping the wrong side.
> - Avoid: `pcall` everywhere, swallowing errors and their stacks.
> - Team knows conditional breakpoints, logpoints and Trigger At.
> - A shared logger with tags, levels and rate limiting.
> - System boundaries use `xpcall` with traceback, and log failures.
>
> Cost: TL;DR ~150 tok · whole note ~3.6k tok. Read more: ## 1. The Studio debugger · ## 3. A logger worth keeping · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most Roblox debugging is done with `print`, and most of it is done badly: a print added, the game run, the print removed, the bug back next week. Studio has a real debugger (breakpoints, conditional breakpoints, logpoints, watches, call stacks, stepping) that most developers never open, and Luau has structured tools (`debug.traceback`, `debug.info`, `xpcall`) that make logs useful. This note covers the debugger, a logging approach that survives into production, error handling that keeps stack traces, and a method for bugs you cannot reproduce on demand, including client freezes.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. The Studio debugger

### Breakpoint types (Docs)
| Type | How | Use for |
|---|---|---|
| **Standard** | click the gutter right of the line number, or right-click, Insert Breakpoint | pause at a line |
| **Conditional** | edit the breakpoint, set a Condition such as `enemy.Name == "Boss"` | pause only in the interesting case (the 400th enemy, the bad item id) |
| **Logpoint** | edit, set a Log Message; prints to Output like `print()`; continues by default | add logging without editing the script |
| **Temporary** | enable Remove Breakpoint on Hit | one-shot investigation |

**Trigger At** sets the context a breakpoint applies to: Client, Server, Edit, or a custom context (Docs). This matters in play tests, where the same ModuleScript runs on both sides: a breakpoint you meant for the server can otherwise stop the client.

Managing (Docs): click the icon to disable, middle-click or right-click to delete, right-click Edit Breakpoint for options. Edits persist across play tests; changes to a breakpoint that is currently paused take effect next session. The **Breakpoints window** (Script tab or Window, Debug, Breakpoints) lists every breakpoint in every script, and during a session lets you enable or disable a breakpoint per context.

### Stepping (Docs)
| Action | Key |
|---|---|
| Step Into | F11 |
| Step Over | F10 |
| Step Out | Shift+F11 |
| Resume | Resume button |
| Stop | Stop button |

### Inspection (Docs)
- **Call Stack** window: the next line to run and the chain of calls that led there.
- **Watch** window: Variables tab (in-scope variables; expand tables and instances), plus your own watches. Add a watch by selecting a variable in the editor, right-click, Add Watch.
- Hovering a variable while paused shows its value.

### When the debugger beats prints
- **State-dependent bugs**: a conditional breakpoint on the bad case, then walk the call stack to see who passed the bad value.
- **"How did we get here?"**: the call stack answers it directly.
- **Tables**: expanding a table in Watch beats printing `HttpService:JSONEncode` of it.
- **Logpoints in shared code**: no edit, so no risk of committing a stray print or breaking a script someone else is editing.

### When it does not help
- **Timing bugs.** Pausing changes timing; network and physics continue on other machines or contexts. Use logging with timestamps.
- **Live servers.** No breakpoints there. Use logs and telemetry ([[Crash and Error Telemetry]]).
- **Freezes.** A frozen script never reaches your breakpoint's line if the loop is elsewhere; see section 6.

---

## 2. The Output window

- Client messages show in blue and server messages in green during play tests (Docs, testing modes page).
- Filter by message type and by context; search.
- `print` (output), `warn` (warning, yellow), `error` (throws; red with stack trace if uncaught).
- Repeated identical messages are often collapsed; a count tells you how many.
- Log files: `%LOCALAPPDATA%\Roblox\logs` on Windows, `~/Library/Logs/Roblox` on Mac (Docs). Useful after a Studio crash.

---

## 3. A logger worth keeping

Ad hoc prints are noise. A tiny logger with tags and levels gives you logs you can leave in the code, switch on per system, and route to telemetry.

```lua
--!strict
-- ReplicatedStorage/Shared/Log.luau
local RunService = game:GetService("RunService")

export type Level = "debug" | "info" | "warn" | "error"
local ORDER: { [Level]: number } = { debug = 1, info = 2, warn = 3, error = 4 }

local Log = {}

-- Global minimum level, and per-tag overrides (turn one system up to "debug").
local minLevel: Level = if RunService:IsStudio() then "info" else "warn"
local tagLevels: { [string]: Level } = {}

-- Per-message rate limit so a bug firing every frame cannot flood output.
local lastAt: { [string]: number } = {}
local RATE_SECONDS = 1

local side = if RunService:IsServer() then "S" else "C"

local function enabled(tag: string, level: Level): boolean
	local threshold = tagLevels[tag] or minLevel
	return ORDER[level] >= ORDER[threshold]
end

local function emit(level: Level, tag: string, fmt: string, ...: any)
	if not enabled(tag, level) then
		return
	end
	local ok, text = pcall(string.format, fmt, ...)
	if not ok then
		text = fmt .. " [format error]"
	end
	local key = tag .. "|" .. fmt
	local now = os.clock()
	if level ~= "error" and lastAt[key] and now - lastAt[key] < RATE_SECONDS then
		return -- suppress repeats; errors always pass
	end
	lastAt[key] = now
	local line = string.format("[%s][%s][%s] %s", side, tag, level, text)
	if level == "warn" or level == "error" then
		warn(line)
	else
		print(line)
	end
end

function Log.setLevel(level: Level)
	minLevel = level
end

function Log.setTagLevel(tag: string, level: Level?)
	tagLevels[tag] = level
end

function Log.debug(tag: string, fmt: string, ...: any) emit("debug", tag, fmt, ...) end
function Log.info(tag: string, fmt: string, ...: any) emit("info", tag, fmt, ...) end
function Log.warn(tag: string, fmt: string, ...: any) emit("warn", tag, fmt, ...) end
function Log.error(tag: string, fmt: string, ...: any)
	-- Logs with a traceback but does not throw; callers decide whether to continue.
	-- `...` must be last in an argument list or it is cut to one value,
	-- so format first, then append the traceback.
	local ok, text = pcall(string.format, fmt, ...)
	emit("error", tag, "%s\n%s", if ok then text else fmt, debug.traceback("", 2))
end

return Log
```

Usage: `Log.info("Shop", "purchase %s by %d", itemId, player.UserId)`.

Why each piece exists:
- **Tags** let you turn on `debug` for one system while chasing a bug, without a flood from everything else.
- **Rate limiting** protects against the classic "error inside Heartbeat" that prints 60 times a second, hides every other message and costs frame time itself.
- **Side prefix** (`[S]`/`[C]`) matters in play tests where both outputs interleave.
- **Errors carry a traceback** but do not throw, so a logging call never changes control flow.
- **Production default is `warn`**: info logs in a live server cost time and fill the console.

Note: `debug.traceback`'s format is not guaranteed and should not be parsed (Docs). For structured data (script, line, function name), use `debug.info(level, "sln")`, which guarantees its format (Docs).

### LogService
`LogService.MessageOut(message, messageType, ...)` fires for every output message; `LogService:GetLogHistory()` returns recent history. These let you build an in-game log viewer for testers or forward warnings to telemetry ([[Crash and Error Telemetry]]). As of October 2026 the LogService reference also lists newer methods (`Info`, `Warn`, `Error`, `Log`, `GetLogger`, `ClearOutput`) and a `context` dictionary parameter on `MessageOut`; the reference page gives signatures without descriptions, so check current behaviour before relying on them (unverified).

---

## 4. Errors that keep their stack

### `error` levels
`error(message, level)`: level 1 (default) blames the line that called `error`; level 2 blames the caller, which is right for argument validation in a library; level 0 adds no position.

```lua
--!strict
local function setSpeed(humanoid: Humanoid, speed: number)
	if speed < 0 or speed ~= speed then -- NaN check
		error(("invalid speed %s"):format(tostring(speed)), 2) -- blame the caller
	end
	humanoid.WalkSpeed = speed
end
```

### `pcall` loses the stack; `xpcall` keeps it
When you catch an error with `pcall`, you get the message but the stack is gone. Use `xpcall` with a handler that captures the traceback **at the point of error**:

```lua
--!strict
local function withTrace(err: any): string
	return tostring(err) .. "\n" .. debug.traceback("", 2)
end

local ok, result = xpcall(function()
	return riskyThing()
end, withTrace)

if not ok then
	warn("[Quest] update failed:\n" .. result)
end
```

Use this at system boundaries (one failing quest handler should not kill the quest loop). Do not wrap every call: swallowed errors are worse than crashes because nobody sees them. More in [[Error Handling and Retries]].

### Errors in spawned threads
Errors inside `task.spawn`/`task.defer` threads print to output but do not propagate to the spawner. A loop that dies from an error simply stops, silently from the caller's point of view. Long-lived loops should catch per iteration and log:

```lua
--!strict
task.spawn(function()
	while true do
		local ok, err = xpcall(tick, withTrace)
		if not ok then
			Log.error("Spawner", "tick failed: %s", tostring(err))
		end
		task.wait(1)
	end
end)
```

---

## 5. A method for bugs

1. **Reproduce** reliably. Use cheat tooling to reach the state (level, items, zone) in seconds ([[Multi-Client and Live Testing]]). Write the steps down.
2. **Locate** the boundary: which system first sees a wrong value? Logpoints or tagged debug logs at system boundaries; a conditional breakpoint on the wrong value.
3. **Explain** before fixing. If you cannot say why it happens, a fix is a guess.
4. **Fix** the cause, then add the cheapest permanent guard: an assertion, a validation, a spec for pure logic, a lint rule.
5. **Verify** with the original repro steps, in the original context (play test, multi-client, phone).

**Measured caution for shared sessions.** In a team or tool-assisted environment, someone else may be playing or editing in the same place while you test. In the reference project, odd server behaviour during tests was more than once someone else's play session. Check the server log for activity you did not cause before chasing a phantom bug ([[Safe Changes in a Shared Place]]).

---

## 6. Freezes and hangs

A client or Studio "freeze" is usually a script that never yields.

**Measured case.** Clicking an item in an inventory froze the client. A helper that attached decorative particles to a card looped `while true do` until its new frame successfully parented. When the card had been rebuilt by the click, the old layer was destroyed and parenting kept failing, so the loop never ended and the frame never finished. Only rare items had that decoration, which made the bug look random. The fix capped the loop at 4 attempts and returned nil for a gone parent; the per-frame updater also retired entries whose layer was gone.

How to find a freeze:
- Studio may report a script timeout for a script that runs too long without yielding (exact timeout and message unverified); the reported script and line are your lead.
- Search the codebase for `while true do` and `repeat ... until` without a wait or a bounded counter; every retry loop needs a cap.
- Bisect: disable systems by tag or flag until the freeze stops.
- If Studio itself hangs (not a game script), suspect tooling: huge `GetDescendants()` over millions of instances, plugins doing heavy work on selection change, or many heavy external processes competing for CPU. The reference project once froze Studio for about 25 minutes that way ([[Performance Fundamentals]]).

Infinite-loop guard pattern:

```lua
--!strict
local function tryParent(child: Instance, parent: Instance?): boolean
	for _ = 1, 4 do -- bounded: never loop forever on a dead parent
		if not parent or not parent.Parent then
			return false
		end
		local ok = pcall(function()
			child.Parent = parent
		end)
		if ok then
			return true
		end
		task.wait()
	end
	return false
end
```

---

## 7. Logging in production

- Keep `warn` and `error` on; keep `info` and `debug` off by default; enable per tag for authorised developers (a gated remote that calls `Log.setTagLevel` on the server).
- Never log personal data beyond what you need: UserIds are fine for debugging, chat text and other personal content are not ([[Player Privacy and Data Deletion]]).
- Make messages stable: put variable data at the end, or group them, so the Error Report does not explode into thousands of unique entries (it tracks a limited number of unique errors; see [[Crash and Error Telemetry]]).

---

## Common mistakes

- Print-driven debugging with prints that never get removed (or that get removed and re-added weekly).
- Breakpoints without a context, stopping the wrong side.
- `pcall` everywhere, swallowing errors and their stacks.
- Errors inside `Heartbeat` handlers logging 60 times a second.
- Retry loops without a cap.
- Parsing `debug.traceback` output.
- Assuming the bug is yours in a place where others are also testing.

## Checklist

- [ ] Team knows conditional breakpoints, logpoints and Trigger At.
- [ ] A shared logger with tags, levels and rate limiting.
- [ ] System boundaries use `xpcall` with traceback, and log failures.
- [ ] Long-lived loops catch per iteration.
- [ ] Every retry or wait-until loop is bounded.
- [ ] Production log level is warn; debug enabled per tag only for developers.
- [ ] Each fixed bug leaves a guard (assertion, validation, spec, lint).

## See also

[[Error Handling and Retries]] · [[Crash and Error Telemetry]] · [[Testing Strategies and Frameworks]] · [[Multi-Client and Live Testing]] · [[Developer Console and Stats]] · [[Debugging Animation Problems]] · [[Task Library Coroutines and Yielding]] · [[Command Bar and Studio Scripting]]

## Connected notes
<!-- auto-links:start -->
[[Debugging Live Servers]] · [[Links - Error handling and debugging]] · [[Debugging Start Here]] · [[Reading Luau Errors and Stack Traces]] · [[The Debugging Method - Reproduce Isolate Bisect]] · [[Error Handling - pcall xpcall and Promise Patterns]]
<!-- auto-links:end -->
