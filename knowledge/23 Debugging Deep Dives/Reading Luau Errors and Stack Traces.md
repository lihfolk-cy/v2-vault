---
tags: [debugging, luau, errors, stack-trace, traceback, debug-info]
---
# Reading Luau Errors and Stack Traces

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Reading the top frame and fixing the line that crashed instead of the caller that passed nil.
> - Avoid: Treating "Infinite yield possible" as harmless without checking for an earlier error.
> - Avoid: Fixing the 20th consequence error instead of the first one.
> - I read the whole message and identified which expression was nil or wrong.
> - I checked the frame below the top for where the bad value came from.
> - I scrolled to the first error in the Output.
>
> Read more (19 KB note): ## 2. The common messages, decoded · ## 4. `debug.traceback` and `debug.info` as tools · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most error messages tell you exactly what went wrong, and most developers read only the first five words. This note decodes the messages you will actually see in Roblox, explains what each one usually means in practice (which is often not what it literally says), and shows how to read a stack trace, including the cases where the trace points at the wrong place. It finishes with `debug.traceback` and `debug.info` used as tools, not just for logging.

Logging, `xpcall` and the error-level argument of `error()` are already covered in [[Debugger Breakpoints and Logging]] and [[Error Handling and Retries]]; patterns for structured error handling are in [[Error Handling - pcall xpcall and Promise Patterns]]. This note is about reading.

Source labels: **Docs** (Creator Hub and Luau docs, as of October 2026), **Rule of thumb**.

---

## 1. Anatomy of an error line

```
ServerScriptService.Systems.Shop:142: attempt to index nil with 'Price'
```

| Part | Meaning |
|---|---|
| `ServerScriptService.Systems.Shop` | the script's full name **at the time it was loaded**, dot-separated |
| `142` | line number in that script |
| the rest | the runtime message |

Then, in Output, a stack trace follows (in red for errors, collapsible):

```
Stack Begin
Script 'ServerScriptService.Systems.Shop', Line 142 - function priceOf
Script 'ServerScriptService.Systems.Shop', Line 160 - function buy
Script 'ServerScriptService.Systems.ShopRemote', Line 31
Stack End
```

Read it **top to bottom as innermost to outermost**: line 142 is where it failed, inside `priceOf`, called by `buy` on line 160, called from the remote handler on line 31. The top line is where the error was raised; the bug is often one or two frames lower, where the bad value was passed in.

Two practical notes:
- Clicking the error in Output opens the script at that line.
- The exact text format of the Output stack trace is not a stable API (Docs say the same of `debug.traceback`). Read it; do not parse it.

---

## 2. The common messages, decoded

### 2.1 `attempt to index nil with 'X'`

Literal meaning: you wrote `a.X` (or `a:X()`, or `a["X"]`) and `a` was nil.

The useful question: **which expression on that line was nil?** On `local p = shop.items[id].Price`, it could be `shop`, `shop.items` or `shop.items[id]`. The message names the key being looked up (`'Price'`), so the nil is the thing just before it: `shop.items[id]`.

Usual real causes, in rough order of frequency (rule of thumb):

| Cause | Tell |
|---|---|
| Lookup by an id that does not exist (bad config, client sent a bogus id) | the key is data-driven; check the id |
| `FindFirstChild` returned nil and the next line used it | the line has a `FindFirstChild` or a variable that came from one |
| Instance not replicated or streamed in yet (client) | only on the client; works after a moment |
| Character or Humanoid gone (died, respawning) | happens around death or reset |
| A function returned nothing on an early-exit path | the value came from your own function |
| Module returned a table missing a field due to a typo | key name looks almost right |

Fix pattern: decide whether nil is **legal** here. If it is (an optional child), handle it. If it is not (a config id that must exist), fail loudly with a clear message at the boundary, so the error names the cause:

```lua
--!strict
local function priceOf(itemId: string): number
	local item = Catalog[itemId]
	if item == nil then
		error(("unknown itemId %q"):format(itemId), 2) -- blame the caller
	end
	return item.Price
end
```

Type annotations catch a share of these before running. In `--!strict`, `FindFirstChild` returns `Instance?`, and using it without a check is a type error ([[Luau Type System and Strict Mode]]).

### 2.2 `X is not a valid member of Y "Path"`

Example: `Humanoid is not a valid member of Model "Workspace.Player1"`.

You used dot syntax for a child that does not exist (or a property that does not exist on that class). Differs from 2.1: the parent exists, the child does not. Usual causes: the child has not replicated yet on the client, it was renamed, or there is a typo. For property names, check the class: `Part.Color3` is not a member; `Part.Color` is.

Dot access to children is fine on the server for things you created and know exist. On the client, for anything replicated, use `WaitForChild` (with a timeout where nil is acceptable) or read through attributes and tags.

### 2.3 `attempt to call a nil value`

You called something that is nil. With a method call the message usually names it (`attempt to call missing method 'Foo' of table`, wording varies by case, rule of thumb). Usual causes: a typo in a function name, a module that returns before defining the function, calling a method with `.` vs `:` mixups in the definition, or a function defined below its first use with `local function` ordering.

### 2.4 `attempt to perform arithmetic (add) on nil and number`

The operation name (add, sub, mul, div, mod, pow, unm, concat) and both operand types are given. One operand is nil: often a missing field in old saved data (`profile.Gems + 10` where old profiles have no `Gems`). Fix at load time with defaults and migrations, not at every use ([[Data Schema Design and Migrations]]).

Close cousin: `attempt to compare nil < number` (or `number < nil`). Same story, with comparison.

### 2.5 `invalid argument #1 to 'X' (number expected, got nil)`

A built-in or engine function received the wrong type. The argument number counts from 1 and, for methods called with `:`, may or may not count `self` depending on the function (rule of thumb: check by eye). Typical: `Vector3.new(x, y)` with a nil z, `math.floor(nil)`, `string.format` with too few arguments.

### 2.6 `Unable to cast value to Object` and other casts

You passed a Luau value where the engine expected another type: a string where an Instance was expected, a table where a `Vector3` was expected, or (common with remotes) an Instance the receiving side cannot see, which arrives as nil. If it involves a remote, check what actually arrived ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]).

### 2.7 `Infinite yield possible on 'Parent:WaitForChild("Name")'`

This is a **warning**, not an error. Docs: if `WaitForChild` runs more than 5 seconds without a timeout argument, a warning is printed that the thread may yield forever. If you pass a timeout, it returns nil when the time runs out instead of warning.

What it actually means: after 5 seconds the child still is not there. Possible reasons:
- The name is wrong (case-sensitive, trailing space, renamed in Studio).
- The child is created by a script that errored earlier: **look further up the Output for the first error**.
- The child exists only on the server (ServerStorage, ServerScriptService) and you are waiting on the client.
- Streaming: the instance is outside the streamed area and will never stream in unless the player moves closer ([[Instance Streaming]]).
- The parent you waited on is a different instance from the one that later receives the child (you cached the old character, for example).
- It will arrive, just slowly (heavy join). The warning is then harmless but tells you load is slow.

When the warning is expected (an optional child), pass a timeout and handle nil. Do not silence it by adding long timeouts everywhere: then a missing instance becomes a silent hang.

### 2.8 `Script timeout: exhausted allowed execution time`

A script ran too long without yielding. Studio has a script timeout setting (DevForum staff describe it as a length in seconds, and `ScriptContext:SetTimeout` changes it for the current session only; the exact default and menu location are not confirmed in the docs, unverified). The engine stops the offending thread.

What to look for:
- `while` or `repeat` loops whose exit condition depends on something that cannot change while the loop runs (the loop never yields, so no other code, including replication, can change it).
- Huge one-shot work: `GetDescendants()` over the whole workspace, generating a world in one go, a sort of 100,000 items.
- Accidental recursion that is wide rather than deep (each call does a lot).

Fixes: yield in long work (`task.wait()` every N items), split it across frames, or move it to an Actor ([[Parallel Luau and Actors]]). Raising the timeout is fine for one-off Studio world generation, not as a fix for game code. Freezes without this message are covered in [[Debugger Breakpoints and Logging]] (section on freezes).

### 2.9 `stack overflow`

Recursion went too deep. In Luau the usual cases are:
- A function that calls itself with no base case, or a base case that is never reached because of a bad value (a tree walk on a cyclic table).
- **Metamethod loops**: `__index` that reads `self.something` where `something` is missing, which calls `__index` again forever. Use `rawget` inside metamethods.
- **Property setters that set themselves**: a `Changed` handler that writes the same property, re-triggering itself. With deferred signals this shows instead as a re-entrancy limit (below).
- Two modules requiring each other at load (shows as a require error, not usually a stack overflow).

Luau has limits on stack depth and on nested C calls; the exact numbers are internal and can change (unverified). Messages may read `stack overflow` or mention C stack overflow for deeply nested `pcall`, metamethod or engine calls. Either way, read the stack trace: a repeating pattern of the same two or three frames is the loop.

### 2.10 Re-entrancy limits with deferred signals

With `Workspace.SignalBehavior` set to `Deferred` (what new template places use, Docs as of October 2026), handlers that keep triggering the same event are cut off after a re-entrancy limit, with an error about maximum event re-entrancy depth (Docs describe the limit; exact message text unverified). It means a handler writes something that fires the same event again. Fix the loop (compare before writing), do not just switch signal behaviour back ([[Events Signals and Connections]]).

### 2.11 Module errors

- `Requested module experienced an error while loading`: the module itself threw during its first run. The **real** error is printed separately, usually just above. Scroll up. Every later `require` of that module also fails with this message, so one bad module can produce dozens of misleading errors.
- Cyclic requires (A requires B, B requires A) fail at load with an error about recursive requiring (exact wording unverified). Fix by moving shared code into a third module or requiring lazily inside a function ([[Module Scripts and Requiring]]).
- `Attempted to call require with invalid argument(s)`: you passed something that is not a ModuleScript (nil, a Folder, a wrong path).

### 2.12 `The Parent property of X is locked`

You tried to re-parent an instance that was destroyed (`Destroy()` locks `Parent` to nil). Usual cause: you held a reference to something that was cleaned up, often in a deferred callback or after a yield. The fix is a lifetime check (`if inst.Parent == nil then return end`) or, better, cleaning up the callbacks with the instance ([[Events Signals and Connections]]).

### 2.13 Engine permission and context errors

| Message (paraphrased) | Meaning |
|---|---|
| "can only be called by the backend server" / "can only be called from the server" | client called a server-only API, for example `DataStoreService` |
| "lacking capability" or "The current thread cannot access" | security context or sandboxed script capability (plugins, Actors with capabilities, CoreGui) |
| "HTTP requests are not enabled" | HttpService disabled in Game Settings |
| "Studio access to API services is not enabled" (error 403 for DataStores) | Game Settings, Security, enable Studio access ([[Debugging DataStore Problems]]) |

Exact wording varies with engine versions; match on the meaning.

---

## 3. When the trace lies (or seems to)

| Situation | What you see | What to do |
|---|---|---|
| Error in a `task.spawn` / `task.defer` thread | trace starts at the spawned function; the spawner is not in it | log context at spawn time, or capture `debug.traceback()` when spawning in debug builds |
| Error in an event handler | trace starts at the handler | the event source is elsewhere; find who fired it |
| Error after a yield | the frames before the yield may be gone | log before yielding |
| `pcall` caught and re-raised with `error(err)` | trace points at your re-raise | use `xpcall` with a traceback handler ([[Debugger Breakpoints and Logging]]) |
| `error(msg, 2)` in a library | line points at the caller (by design) | that is correct; read one frame up if needed |
| Error message is a table (custom error object) | Output shows a table address | `error()` with a table loses text in Output; use strings or format the object in the handler |
| Code generated with `loadstring` | odd chunk names | avoid in game code; `loadstring` is off by default on the server |
| Native code generation (`--!native`) | traces are still accurate (Docs describe native codegen as not changing semantics; rule of thumb that line info is preserved) | if a trace looks wrong under `--!native`, compare without it |

The spawned-thread case is the most common source of "the trace is useless". A small helper keeps the origin:

```lua
--!strict
-- Studio-only: spawn a thread that remembers where it was spawned from.
local RunService = game:GetService("RunService")

local function spawnTraced<A...>(fn: (A...) -> (), ...: A...)
	if not RunService:IsStudio() then
		task.spawn(fn, ...)
		return
	end
	local origin = debug.traceback("spawned from:", 2)
	task.spawn(function(...)
		local ok, err = xpcall(fn, function(e)
			return tostring(e) .. "\n" .. debug.traceback("", 2)
		end, ...)
		if not ok then
			warn(err .. "\n" .. origin)
		end
	end, ...)
end
```

The cost (a traceback string per spawn) is why it is Studio-only.

---

## 4. `debug.traceback` and `debug.info` as tools

### 4.1 `debug.traceback(message?, level?)`

Returns a string with the current call stack, optionally prefixed by `message`, starting at `level` (1 is the function calling `traceback`). It can also take a thread as first argument to trace a coroutine (Docs). The format is human-readable and **not guaranteed** (Docs): never parse it.

Uses beyond error handlers:
- "Who calls this?" Put `print(debug.traceback("setCoins called"))` in a setter for one test run.
- Tracing a stuck coroutine: `debug.traceback(thread)` on a thread you stored shows where it is suspended. Useful for finding which `WaitForChild` a loading coroutine is stuck on.

```lua
--!strict
-- Find out where a long-running loader is stuck.
local loaderThread = task.spawn(loadEverything)

task.delay(10, function()
	if coroutine.status(loaderThread) ~= "dead" then
		warn("loader still running after 10 s:\n" .. debug.traceback(loaderThread))
	end
end)
```

### 4.2 `debug.info(level or function, options)`

Returns structured values instead of text, and its output is guaranteed (Docs). Options are letters:

| Letter | Returns |
|---|---|
| `s` | source (script full name) |
| `l` | current line (for a level) or definition line (for a function) |
| `n` | function name, if known |
| `a` | number of parameters and whether it is variadic (two values) |
| `f` | the function itself |

```lua
--!strict
-- A cheap "where am I" for log lines; level 2 = the caller of here()
local function here(): string
	local src, line, name = debug.info(2, "sln")
	return ("%s:%d %s"):format(src, line, name or "?")
end
```

With a function argument, `debug.info(fn, "sl")` tells you where a function was defined. That answers "which of my 40 connected handlers is this?" when you hold a callback but not its origin, for example when auditing what is connected to a signal through your own signal wrapper.

Performance: `debug.info` is much cheaper than `debug.traceback` (rule of thumb: it does not build a string), but neither belongs in per-frame hot paths in production.

### 4.3 `debug.profilebegin` / `debug.profileend`

Not an error tool, but closely related: these label regions in the MicroProfiler ([[MicroProfiler Guide]]). When the "error" is a hitch rather than a crash, label your suspect code and look there.

---

## 5. Reading Output under pressure

When a play test spews 300 lines:

1. **Scroll to the first error.** Later errors are often consequences (a module failed to load, so every requirer fails; a remote was never created, so every `WaitForChild` warns).
2. **Filter by context** (server or client) and by type (errors only).
3. **Group identical messages.** A message with a count of 600 that fires every frame is one bug, often a nil in a `Heartbeat` handler.
4. **Ignore core script noise** you cannot fix, but confirm it is core: core script errors name `CoreGui` or `CorePackages` paths.
5. **Check the context**: is this Studio-only (a plugin's error), a client-only path, or a server one?

A good habit: after each play test, the Output should have **zero** errors and zero unexpected warnings. A noisy Output hides the one new error that matters ([[QA Checklists Before Release]]).

---

## Common mistakes

- Reading the top frame and fixing the line that crashed instead of the caller that passed nil.
- Treating "Infinite yield possible" as harmless without checking for an earlier error.
- Fixing the 20th consequence error instead of the first one.
- Silencing nil errors with `if x then` everywhere, hiding the real missing data.
- Parsing `debug.traceback` text.
- Raising the script timeout instead of making long work yield.
- Losing error context by re-raising with `error(err)` after a `pcall`.

## Checklist

- [ ] I read the whole message and identified which expression was nil or wrong.
- [ ] I checked the frame below the top for where the bad value came from.
- [ ] I scrolled to the first error in the Output.
- [ ] Spawned threads in Studio carry their origin when needed.
- [ ] Optional children use `WaitForChild` with a timeout; required ones fail loudly.
- [ ] Data-driven lookups fail with a message that names the bad id.
- [ ] A clean play test produces zero errors in Output.

## See also

[[Debugging Start Here]] · [[Debugger Breakpoints and Logging]] · [[Error Handling and Retries]] · [[Error Handling - pcall xpcall and Promise Patterns]] · [[Luau Type System and Strict Mode]] · [[Module Scripts and Requiring]] · [[Task Library Coroutines and Yielding]] · [[Debugging Race Conditions and Yield Order]] · [[Crash and Error Telemetry]]

## Connected notes
<!-- auto-links:start -->
[[Links - Error handling and debugging]] · [[Functions Closures and Upvalues]] · [[Building a Signal Library]] · [[Custom Schedulers and Coroutine Patterns]] · [[Tables Metatables and OOP]] · [[Skill - Roblox Debugging]]
<!-- auto-links:end -->
