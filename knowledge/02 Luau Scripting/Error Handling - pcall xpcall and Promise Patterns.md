---
tags: [luau, errors, pcall, xpcall, promises, async, reliability]
---
# Error Handling - pcall xpcall and Promise Patterns

<!-- tldr:start -->
> [!tldr] TL;DR
> - `pcall` returned true but an error printed: Error in a spawned thread or handler -> Report back from the thread
> - Tracebacks point at the logging code: Trace taken after unwinding -> `xpcall` with a trace handler
> - Messages with stacked `Script:line:` prefixes: Rethrow with default level -> `error(err, 0)` or wrap in a structured error
> - Errors from spawned threads are reported back, not assumed caught.
> - `xpcall` with a small, non-yielding trace handler at every catching boundary.
> - Rethrows use level 0 or structured errors with `cause`.
>
> Cost: TL;DR ~180 tok · whole note ~5.5k tok. Read more: ## 4. Boundaries: where error handling belongs · ## 6. Promises: when they earn their place · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Error Handling and Retries]] covers the foundations: how errors propagate per thread, which Roblox APIs fail at runtime, retry with backoff, timeouts, result types and a circuit breaker. This note goes one level deeper. It covers the details of `pcall` and `xpcall` that bite in production (what they catch and what they do not, rethrowing without losing the trace, structured error values), error handling at system boundaries (module loading, remote handlers, per-entity loops), how to fingerprint errors so telemetry stays readable, and when a Promise library earns its place versus plain Luau coroutines.

Facts about the Promise library come from its published API reference (eryn.io/roblox-lua-promise, as of October 2026). Facts about Luau come from the Luau and Roblox docs. Patterns without a source are rules of thumb.

---

## 1. What `pcall` catches, and what it does not

`pcall(f, ...)` runs `f` in the **current thread** and catches any error raised while that call is on the stack, including after `f` yields (Luau's `pcall` is yieldable, so wrapping `GetAsync` or `task.wait` inside it is fine).

It does **not** catch:

| Not caught | Why | What happens |
|---|---|---|
| Errors inside `task.spawn`, `task.defer`, `task.delay` started from `f` | They run in a different thread | Printed to Output; `pcall` returns `true` |
| Errors in event handlers that `f` triggers (a `BindableEvent:Fire`, a property change) | Handlers run in their own threads | Printed separately |
| Errors in a coroutine resumed with `coroutine.resume` | `resume` returns `false, err` itself | Silent unless you check the result |
| Failures that are not errors | `FindFirstChild` returning `nil`, a remote never answering | Nothing to catch: check values |

The first row is the one that surprises people:

```lua
local ok = pcall(function()
	task.spawn(function()
		error("boom")   -- different thread
	end)
end)
print(ok) --> true, and "boom" appears in Output separately
```

If a helper starts background work and you want its failure, the helper must report it back (a callback, a result value, or a Promise rejection).

**Deferred signals.** With `Workspace.SignalBehavior = Deferred`, handlers run later in the frame rather than inside the call that fired them (Roblox docs). Code that relied on "my `pcall` around `Fire` will catch the handler's error" was already wrong in Immediate mode (separate thread) and is now also wrong about timing. Deferred is also required by the server authority model (see [[Client Prediction and Reconciliation for Combat]]).

---

## 2. `xpcall`: getting the trace at the right moment

`pcall` returns only the error value. By the time you see it, the stack that raised it has unwound, so `debug.traceback()` inside your `if not ok` branch shows **your** stack, not the failing one. `xpcall` runs a handler **at the error site**, before unwinding:

```lua
--!strict
local function withTrace(err: any): any
	-- Keep structured errors intact; add a trace only to plain strings.
	if type(err) == "table" then
		err.trace = err.trace or debug.traceback(nil, 2)
		return err
	end
	return debug.traceback(tostring(err), 2)
end

local ok, result = xpcall(loadProfile, withTrace, player) -- extra args are passed to loadProfile
```

Rules for handlers (rule of thumb, consistent with Lua semantics):

- **Keep them tiny and non-yielding.** No `task.wait`, no DataStore calls, no remotes. Capture the information and return; do the reporting after `xpcall` returns.
- **Never let the handler error.** An error inside the handler gives you a generic failure instead of your error. Wrap risky formatting (`tostring` on a table with a broken `__tostring`) defensively.
- **The level argument matters.** `debug.traceback(msg, 2)` starts the trace one frame above the handler, which is the frame that raised.

### Rethrowing without losing context

A common pattern is "catch, add context, rethrow". Done naively, each rethrow prepends a new `Script:line:` prefix and discards the original trace:

```lua
-- Bad: message becomes "Loader:40: Store:12: key too long" and the trace points at Loader
local ok, err = pcall(save, data)
if not ok then error("save failed: " .. tostring(err)) end
```

Two better options:

```lua
-- Option A: rethrow the original value unchanged (level 0 adds no prefix)
if not ok then error(err, 0) end

-- Option B: wrap in a structured error that carries the cause
if not ok then
	error({ code = "SaveFailed", cause = err, userId = player.UserId }, 0)
end
```

---

## 3. Structured errors

Strings are fine for bugs. For expected failures that callers branch on, use tables. Luau passes any value through `error` and `pcall` with its identity intact.

```lua
--!strict
export type AppError = {
	code: string,          -- stable, machine-readable: "NotEnoughCoins", "Throttled"
	message: string?,      -- human-readable detail for logs, never shown raw to players
	retryable: boolean,
	cause: any?,           -- the underlying error, if any
	trace: string?,
}

local AppErrorMeta = {
	__tostring = function(e: AppError): string
		return `[{e.code}] {e.message or ""}` .. (if e.cause then ` (cause: {tostring(e.cause)})` else "")
	end,
}

local function fail(code: string, message: string?, retryable: boolean?, cause: any?): never
	error(setmetatable({
		code = code,
		message = message,
		retryable = retryable or false,
		cause = cause,
	}, AppErrorMeta), 0)
end

local function isAppError(e: any): boolean
	return type(e) == "table" and getmetatable(e) == AppErrorMeta
end
```

Benefits: retry helpers can check `e.retryable` instead of string-matching messages; telemetry groups by `code`; the UI maps codes to friendly text.

Two limits. Structured errors that escape to `ScriptContext.Error` or Output become strings (via `__tostring` if you set one, otherwise an unhelpful `table: 0x...`), so always set `__tostring`. And they do not survive a remote or DataStore boundary as objects: metatables are dropped ([[Tables Metatables and OOP]]). Convert to `{ code = ..., message = ... }` before sending.

For domain outcomes that are not exceptional ("you cannot afford this"), a result value is still clearer than any error ([[Error Handling and Retries]] section 7). Use structured errors for failures that must unwind several layers.

---

## 4. Boundaries: where error handling belongs

Most code should not catch anything. Catch at **boundaries**, where one failure must not take down unrelated work:

| Boundary | Policy |
|---|---|
| Module loading during bootstrap | Fail fast and loud for core modules; isolate optional ones |
| Remote handlers | Validate first; let bugs error (they kill one handler thread); never echo error text to the client |
| Per-entity update loops | Catch per entity, log once per fingerprint, quarantine repeat offenders |
| Web-backed calls | Wrap the call itself; decide what failure means ([[Error Handling and Retries]]) |
| Player lifecycle (join, leave) | Each step isolated so a failed badge check does not block data loading |

### 4.1 Bootstrapping modules

When a ModuleScript errors during `require`, the requiring thread gets an error, and later `require`s of the same module error again rather than retrying the load (rule of thumb from engine behaviour; the message is typically "Requested module experienced an error while loading"). A loader that requires 40 systems in one loop stops at the first failure and leaves the rest uninitialised, which is worse than either all or nothing.

```lua
--!strict
-- Server bootstrap: core systems must load; optional ones are isolated and reported.
type SystemSpec = { module: ModuleScript, core: boolean }

local function boot(specs: { SystemSpec })
	local failures: { string } = {}
	for _, spec in specs do
		local ok, err = xpcall(function()
			local sys = require(spec.module) :: any
			if type(sys) == "table" and type(sys.init) == "function" then
				sys.init()
			end
		end, function(e) return debug.traceback(tostring(e), 2) end)

		if not ok then
			if spec.core then
				-- A server without its data or combat system should not accept players.
				error(`core system {spec.module.Name} failed: {err}`, 0)
			end
			table.insert(failures, spec.module.Name)
			warn(`[Boot] optional system {spec.module.Name} failed:\n{err}`)
		end
	end
	if #failures > 0 then
		warn(`[Boot] running without: {table.concat(failures, ", ")}`)
	end
end
```

"Core" should be a short list: data, purchases, combat. A failed cosmetic system (a seasonal decoration, a leaderboard) should never stop the server. See [[Project Structure and Bootstrapping]].

### 4.2 Remote handlers

Validation, not `pcall`, is the defence against bad payloads ([[Server Authority and Validation]]). A bug in a handler errors that handler's thread only; the connection stays connected. Two specific rules:

- **Never return error text to the client.** A RemoteFunction that errors on the server propagates an error to the invoking client. That can leak internals (module names, paths, logic). Wrap RemoteFunction handlers so they return a fixed failure code.
- **Do not log every rejected payload.** Exploit tools can fire thousands of bad requests; per-request `warn` floods logs and costs CPU. Count rejections and log aggregates ([[Remote Abuse Patterns and Rate Limiting in Practice]]).

```lua
--!strict
remoteFunction.OnServerInvoke = function(player: Player, ...: any): any
	local ok, result = pcall(handleRequest, player, ...)
	if not ok then
		reportError("RF:" .. remoteFunction.Name, result, player.UserId)
		return { ok = false, code = "ServerError" } -- never the raw error
	end
	return result
end
```

This is the one place a broad `pcall` is right: it is the outermost layer, it logs with context, and it controls what the untrusted side sees.

### 4.3 Per-entity loops with quarantine

The existing note shows "catch per item, log once". Production adds **quarantine**: an entity that errors repeatedly is removed from the loop, because an error that happens every frame costs a traceback and a log call every frame.

```lua
--!strict
local MAX_STRIKES = 3
local strikes: { [any]: number } = {}

local function updateAll(entities: { any }, dt: number)
	for i = #entities, 1, -1 do -- backwards so removal is safe
		local e = entities[i]
		local ok, err = pcall(e.update, e, dt)
		if not ok then
			local n = (strikes[e] or 0) + 1
			strikes[e] = n
			reportError("EntityUpdate", err)
			if n >= MAX_STRIKES then
				warn(`[Entities] quarantined {e.id}: {err}`)
				table.remove(entities, i)
				strikes[e] = nil
				if e.destroy then pcall(e.destroy, e) end
			end
		end
	end
end
```

---

## 5. Fingerprinting errors for telemetry

Raw error strings are almost unique: they contain player ids, positions, instance paths with numbers. Group them by a **fingerprint** so 10,000 occurrences of one bug become one row with a count ([[Crash and Error Telemetry]]).

```lua
--!strict
local function fingerprint(message: string): string
	local s = message
	s = string.gsub(s, "%d+%.?%d*", "#")         -- numbers
	s = string.gsub(s, "0x%x+", "0x?")            -- addresses
	s = string.gsub(s, "\"[^\"]*\"", "\"?\"")     -- quoted strings
	return string.sub(s, 1, 200)
end

local counts: { [string]: number } = {}
local firstSeen: { [string]: string } = {}

local function reportError(system: string, err: any, userId: number?)
	local msg = tostring(err)
	local key = system .. "|" .. fingerprint(msg)
	local n = (counts[key] or 0) + 1
	counts[key] = n
	if n == 1 then
		firstSeen[key] = msg -- keep one full example, including the trace
		warn(`[{system}] {msg}`)
	end
	-- flush `counts` periodically to your analytics or logging backend
end
```

Note that the number pattern also rewrites line numbers in the `Script:12:` prefix. That is usually what you want (the same bug across two releases groups together); if you need the line, keep it from `firstSeen`.

`ScriptContext.Error` (server side) receives every unhandled error with its message, stack trace and script (Roblox docs). Connect it once, feed it into the same `reportError`, and you have coverage of both handled and unhandled failures.

---

## 6. Promises: when they earn their place

Luau coroutines already let you write asynchronous code as straight-line code: `local data = store:GetAsync(key)` simply yields. A Promise library adds value when you need **composition**: run several things concurrently and wait for all, race against a timeout, cancel work that is no longer wanted, or attach cleanup that runs however the operation ends.

The most used Roblox implementation is the open-source `Promise` library by evaera (roblox-lua-promise). Its API, as of October 2026:

| Need | API |
|---|---|
| Wrap a yielding function | `Promise.promisify(fn)`, `Promise.try(fn, ...)` |
| Create one | `Promise.new(function(resolve, reject, onCancel) ... end)`, `Promise.defer(...)` (starts after the next Heartbeat) |
| Chain | `:andThen(onOk, onErr?)`, `:catch(onErr)`, `:tap(fn)`, `:finally(fn)` |
| Wait for many | `Promise.all`, `Promise.allSettled`, `Promise.any`, `Promise.some(list, n)`, `Promise.race` |
| Time | `Promise.delay(seconds)`, `:timeout(seconds, rejectionValue?)` |
| Retry | `Promise.retry(fn, times, ...)`, `Promise.retryWithDelay(fn, times, seconds, ...)` |
| Events | `Promise.fromEvent(signal, predicate?)` |
| Cancel | `:cancel()`, with cleanup registered through the `onCancel` argument of the executor |
| Bridge back to yielding code | `:await()` (returns success plus values), `:expect()` (returns values or throws), `:awaitStatus()` |
| Status | `Promise.Status` with `Started`, `Resolved`, `Rejected`, `Cancelled` |

### 6.1 Loading a player concurrently

```lua
--!strict
local Promise = require(ReplicatedStorage.Packages.Promise)

local getAsync = Promise.promisify(function(store: DataStore, key: string)
	return store:GetAsync(key)
end)

local function loadPlayer(player: Player)
	return Promise.all({
		getAsync(profileStore, `p_{player.UserId}`),
		getAsync(settingsStore, `s_{player.UserId}`),
		Promise.try(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_PASS_ID)
		end),
	})
		:timeout(15)
		:andThen(function(results)
			local profile, settings, isVip = results[1], results[2], results[3]
			return buildSession(player, profile, settings, isVip)
		end)
end

loadPlayer(player)
	:catch(function(err)
		-- Includes timeout. Do NOT fall back to empty data: kick or hold in a lobby state.
		reportError("LoadPlayer", err, player.UserId)
		player:Kick("Could not load your data. Please rejoin.")
	end)
```

Three calls run concurrently, so load time is the slowest call rather than the sum. Without a library you would write that with `task.spawn` and a counter, which is fine for one place and error-prone across twenty.

### 6.2 Cancellation is not abortion

`:cancel()` marks the Promise cancelled, runs `onCancel` hooks and stops downstream handlers. It **cannot stop an engine call already in progress**. If a `SetAsync` is in flight, it will complete. Design for this:

- Cancellation is for **ignoring** results (the player left, the menu closed) and **cleaning up** (disconnect a listener, destroy a preview model).
- Never use cancellation as a guarantee that a write did not happen. Writes must be idempotent ([[Rate Limiting and Abuse Prevention]], idempotency section).
- `:timeout()` is the same: the operation continues in the background after the timeout rejects.

```lua
local function waitForChoice(player: Player, ui: ScreenGui)
	local conn: RBXScriptConnection? = nil
	return Promise.new(function(resolve, _reject, _onCancel)
		conn = choiceRemote.OnServerEvent:Connect(function(p: Player, choice: unknown)
			if p == player and typeof(choice) == "string" then
				resolve(choice)
			end
		end)
	end)
		:timeout(30)
		:finally(function()
			-- runs on resolve, reject (including timeout) and cancel
			if conn then conn:Disconnect() end
			ui:Destroy()
		end)
end
```

The tempting version registers cleanup only through `onCancel`. It works when the caller cancels and leaks the connection and the UI every time the player actually answers. That is the most common Promise bug in Roblox code: cleanup only on the cancel path. Put cleanup in `finally`, which runs however the Promise settles.

### 6.3 Unhandled rejections

A rejected Promise that nobody consumes with `:catch` produces an unhandled-rejection warning on the next frame (library docs). Consequences:

- Create rejected Promises on demand; do not store a rejected Promise for later.
- End every chain that leaves your control with a `:catch`.
- Register `Promise.onUnhandledRejection(callback)` once and route to `reportError`, so a forgotten `:catch` is still visible in telemetry.

### 6.4 Pitfalls

| Pitfall | Result | Fix |
|---|---|---|
| Forgetting to `return` a Promise from `andThen` | Next step runs before the inner work finishes | Always return the inner Promise |
| `:expect()` in a remote handler | A rejection throws in the handler thread | Use `:await()` and branch, or keep the chain |
| Cleanup only in `onCancel` | Leaks on normal resolve | Clean up in `finally` |
| Promises for single sequential yields | Extra allocations and indirection for no gain | Plain yielding code |
| Mixing raw `task.spawn` inside executors | Errors in the spawned thread do not reject the Promise | Use `Promise.try` or resolve/reject explicitly |
| `Promise.all` over 200 DataStore reads | Burst exceeds DataStore budgets | Batch through a server-wide budget ([[DataStore Fundamentals]]) |

### 6.5 Without a library

If you only need "all of these, concurrently" in one or two places, a small helper avoids the dependency:

```lua
--!strict
-- Runs each function in its own thread; returns results in order, or the first error.
local function all(fns: { () -> any }): (boolean, { any } | any)
	local n = #fns
	local results = table.create(n)
	local remaining = n
	local failed: any = nil
	local caller = coroutine.running()
	local waiting = false

	if n == 0 then return true, results end
	for i, fn in fns do
		task.spawn(function()
			local ok, value = pcall(fn)
			if ok then results[i] = value elseif failed == nil then failed = value end
			remaining -= 1
			if remaining == 0 and waiting then
				task.spawn(caller) -- resume the caller only if it is actually suspended
			end
		end)
	end
	if remaining > 0 then
		waiting = true
		coroutine.yield()
	end
	if failed ~= nil then return false, failed end
	return true, results
end
```

The `remaining > 0` check and the `waiting` flag handle functions that finish without yielding: if every worker completes synchronously inside its `task.spawn`, the caller must neither yield waiting for a resume that already happened nor be resumed while it is still running (which errors with "cannot resume non-suspended coroutine"). This is exactly the kind of subtlety that makes a tested library attractive once you need more than one combinator.

---

## 7. Choosing a style per codebase

| Codebase | Recommended style |
|---|---|
| Small game, few async flows | Plain yielding code, `pcall` at boundaries, result values |
| Many concurrent loads, UI flows with cancel, timeouts everywhere | A Promise library, used consistently in those layers |
| Framework already standardised on Promises (some Knit-based projects) | Follow the framework, keep core logic synchronous ([[Frameworks - Knit Matter and Others]]) |
| Hot gameplay loops | Neither: validated synchronous code, no per-item Promises or closures |

Whatever you pick, apply it consistently per layer. Half the bugs in mixed codebases are at the seam: a function that sometimes returns a Promise and sometimes yields.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| `pcall` returned true but an error printed | Error in a spawned thread or handler | Report back from the thread |
| Tracebacks point at the logging code | Trace taken after unwinding | `xpcall` with a trace handler |
| Messages with stacked `Script:line:` prefixes | Rethrow with default level | `error(err, 0)` or wrap in a structured error |
| Telemetry dashboard has 5,000 unique errors | No fingerprinting | Normalise numbers, ids and quotes |
| Server boots half-initialised | One module failed in a shared require loop | Bootstrap with core and optional tiers |
| Client sees server internals in error text | RemoteFunction error propagated | Outer `pcall`, fixed failure codes |
| Loop errors every frame for hours | No quarantine | Strike count, then remove |
| "Promise cancelled" but data was written | Cancellation does not abort engine calls | Idempotent writes |

## Checklist

- [ ] Errors from spawned threads are reported back, not assumed caught.
- [ ] `xpcall` with a small, non-yielding trace handler at every catching boundary.
- [ ] Rethrows use level 0 or structured errors with `cause`.
- [ ] Structured errors have `code`, `retryable` and `__tostring`.
- [ ] Bootstrap separates core from optional systems.
- [ ] RemoteFunction handlers never return raw errors.
- [ ] Per-entity loops quarantine repeat offenders.
- [ ] Errors are fingerprinted and counted; `ScriptContext.Error` is connected.
- [ ] Promise chains end in `:catch`; cleanup lives in `finally`; writes are idempotent.

## See also

[[Error Handling and Retries]] · [[Task Library Coroutines and Yielding]] · [[Events Signals and Connections]] · [[Module Scripts and Requiring]] · [[Project Structure and Bootstrapping]] · [[Crash and Error Telemetry]] · [[Debugger Breakpoints and Logging]] · [[Server Authority and Validation]] · [[DataStore Fundamentals]] · [[Frameworks - Knit Matter and Others]]

## Connected notes
<!-- auto-links:start -->
[[Reading Luau Errors and Stack Traces]] · [[Custom Schedulers and Coroutine Patterns]] · [[Links - Coroutines, task library and async]] · [[Building a Signal Library]] · [[Links - Error handling and debugging]] · [[Debugging Race Conditions and Yield Order]]
<!-- auto-links:end -->
