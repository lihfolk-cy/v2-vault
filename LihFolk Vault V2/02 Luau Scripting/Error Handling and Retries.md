---
tags: [luau, errors, pcall, retries, reliability, logging, type/guide, area/scripting, level/intermediate, api/DataStore, area/gameplay, api/BindToClose]
---
# Error Handling and Retries

<!-- tldr:start -->
> [!tldr] TL;DR
> - Player data wiped after an outage: Load failure treated as "new player" -> Distinguish failure from empty; kick or retry
> - Bugs never appear in logs: Broad `pcall` around logic -> Wrap only fallible calls; log failures
> - DataStore throttling cascades: Immediate retries in a loop -> Backoff with jitter; attempt cap
> - Every web-backed call is wrapped and its failure has a defined outcome.
> - Retries: capped, exponential, jittered, idempotent, re-validated after waits.
> - No broad `pcall` around game logic; bugs fail loudly.
>
> Cost: TL;DR ~170 tok · whole note ~4.0k tok. Read more: ## 5. Retry with exponential backoff and jitter · ## 10. Failure policy by situation · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox code fails in two very different ways. **Bugs** (indexing `nil`, wrong types, missing instances) should fail loudly and early so you find them. **Expected failures** (DataStore throttling, HTTP timeouts, a player leaving mid-teleport, a purchase prompt failing) must be caught, retried or handled, because they will happen in production every day. This note covers how errors propagate in Roblox's threaded model, `error`/`pcall`/`xpcall`/`assert`, tracebacks, retry with backoff and jitter, timeouts, result types, and the pre-save checks that keep whole classes of bugs out of live servers.

---

## 1. How errors propagate

- An error unwinds the current **thread** to the nearest `pcall`/`xpcall`. If there is none, the thread dies and the error is printed to Output (and the Developer Console in live games).
- Every event handler, `task.spawn`, `task.defer` and `task.delay` callback runs in its own thread. An error there kills only that thread; the script that connected it keeps running, and the connection stays connected.
- An error at a script's **top level** stops the rest of that script (its existing connections remain).
- An error inside a `require`d module's top level makes that `require` throw in the requiring thread.
- `coroutine.resume` catches errors and returns `false, err` instead of throwing, so ignored return values hide errors ([[Task Library Coroutines and Yielding]]).

Server errors are logged; nothing shows to players unless you build it. Unhandled errors in handlers are easy to miss in production, so route them to telemetry ([[Crash and Error Telemetry]]):

```lua
local ScriptContext = game:GetService("ScriptContext")
ScriptContext.Error:Connect(function(message: string, trace: string, script: Instance?)
	-- aggregate and rate-limit; do not log every repeat
end)
```

---

## 2. Raising errors

```lua
error("inventory full")             -- message gets "Script:line: " prefixed (level 1)
error("bad argument #1", 2)         -- blame the caller's line
error("no position info", 0)        -- no prefix
error({ code = "NotEnoughCoins", need = 50 })   -- any value; tables keep structure through pcall
```

Error objects (tables) are useful for expected failures you want to branch on. Strings are fine for bugs.

`assert(value, message)` returns `value` if truthy, otherwise errors with `message` (default "assertion failed!"). Use it for invariants, and note it also narrows types ([[Luau Type System and Strict Mode]]):

```lua
local spawnFolder = assert(workspace:FindFirstChild("Spawns"), "map is missing Spawns")
```

The message argument is always evaluated, so `assert(x, expensiveDescription())` costs even on success; build messages lazily in hot paths.

---

## 3. pcall and xpcall

```lua
local ok, result = pcall(function()
	return dataStore:GetAsync(key)
end)
if not ok then
	warn("GetAsync failed:", result)
end

-- Method form avoids creating a closure: pcall(fn, self, args...)
local ok2, value = pcall(dataStore.GetAsync, dataStore, key)

-- xpcall adds a handler that runs at the error site, so the traceback is still available
local ok3, err = xpcall(riskyThing, function(e)
	return debug.traceback(tostring(e), 2)
end)
```

`pcall` and `xpcall` are yieldable in Luau (Docs), so wrapping DataStore or HTTP calls is fine.

### Do not swallow bugs

```lua
-- Anti-pattern: hides real bugs and leaves state half-updated
pcall(function()
	giveReward(player)
	updateQuest(player)
	saveProfile(player)
end)
```

Wrap only the **operation that can legitimately fail**, handle that failure explicitly, and let bugs surface. If you must protect a loop of independent items (one broken enemy should not stop all enemies from thinking), catch per item and **log** the failure with context:

```lua
for _, enemy in enemies do
	local ok, err = pcall(enemy.think, enemy, dt)
	if not ok then
		reportOnce(`enemy {enemy.id}: {err}`)   -- rate-limited log
	end
end
```

Note `pcall` per item per frame has a cost; in very hot loops prefer correctness through validation and leave `pcall` to the boundary.

---

## 4. Which APIs fail at runtime

These call Roblox web services or other systems and can fail even when your code is correct (Rule of thumb, consistent with Docs warnings on each API):

| API | Typical failures |
|---|---|
| `DataStoreService` (`GetAsync`, `SetAsync`, `UpdateAsync`, ...) | Throttling (budget), service outage, key size, value size |
| `MemoryStoreService` | Quota, throttling |
| `HttpService:RequestAsync/GetAsync/PostAsync` | HTTP disabled, timeouts, 4xx/5xx, rate limits |
| `MarketplaceService` (`GetProductInfo`, `UserOwnsGamePassAsync`, ...) | Web errors |
| `Players:GetUserIdFromNameAsync`, `GetNameFromUserIdAsync`, `GetFriendsAsync` | Web errors, unknown users |
| `TeleportService` | Teleport failures (handled through `TeleportInitFailed`) |
| `BadgeService`, `GroupService`, `PolicyService`, `TextService:FilterStringAsync` | Web errors |
| `ContentProvider:PreloadAsync`, `InsertService:LoadAsset` | Asset failures, moderation |
| `RemoteFunction:InvokeClient` | Client errors, never returns, or player leaves (never use on untrusted clients) |

All of these: wrap in `pcall`, decide what failure means for the player, and retry only when retrying can help.

---

## 5. Retry with exponential backoff and jitter

Retries handle transient failures. Naive retries (immediately, forever, all servers in lockstep) make outages worse. A reusable helper:

```lua
--!strict
export type RetryOptions = {
	attempts: number?,      -- total tries, default 5
	baseDelay: number?,     -- seconds, default 0.5
	maxDelay: number?,      -- seconds, default 8
	retryIf: ((err: any) -> boolean)?,   -- return false for non-retryable errors
}

local rng = Random.new()

local function retry<T...>(opts: RetryOptions, fn: () -> T...): (boolean, ...any)
	local attempts = opts.attempts or 5
	local base = opts.baseDelay or 0.5
	local maxDelay = opts.maxDelay or 8
	local lastErr: any = nil

	for attempt = 1, attempts do
		local result = table.pack(pcall(fn))
		if result[1] then
			return true, table.unpack(result, 2, result.n)
		end
		lastErr = result[2]
		if opts.retryIf and not opts.retryIf(lastErr) then
			break
		end
		if attempt < attempts then
			-- full jitter: random delay in [0, min(maxDelay, base * 2^(attempt-1))]
			local cap = math.min(maxDelay, base * 2 ^ (attempt - 1))
			task.wait(rng:NextNumber(0, cap))
		end
	end
	return false, lastErr
end

return retry
```

Usage:

```lua
local ok, data = retry({ attempts = 4 }, function()
	return profileStore:GetAsync(`player_{player.UserId}`)
end)
if not ok then
	-- Do NOT treat this as "new player with empty data": that overwrites real data on the next save.
	player:Kick("Could not load your data. Please rejoin.")
	return
end
```

Design rules:
- **Cap attempts and total time.** A save in `BindToClose` has about 30 seconds in total (Rule of thumb from engine shutdown behaviour; see [[Saving Correctly - Autosave and BindToClose]]); retries must fit.
- **Jitter** spreads retries from many servers so they do not hammer a recovering service at the same instant.
- **Do not retry non-transient errors**: invalid arguments, value too large, permission denied. Retrying them wastes budget.
- **Re-check preconditions after each wait**: the player may have left.
- **Idempotency.** Retrying a write that may have succeeded (timeout after the server applied it) must be safe. `UpdateAsync` with a transform that checks a version or a receipt ID is safe; "add 100 coins" blindly is not ([[Purchase Data and Receipts]]).
- **Budgets.** DataStore request budgets are per server and per request type. Exponential backoff respects them; tight loops exhaust them ([[DataStore Fundamentals]]).

---

## 6. Timeouts

Some yields have no timeout (a `RemoteFunction` invoke, a signal `Wait`). Bound them yourself:

A version built on manual coroutine resumption is easy to get wrong (if `fn` finishes without yielding, it tries to resume the caller before the caller has yielded). A simple, robust version for occasional calls:


```lua
local function withTimeout(seconds: number, fn: () -> any): (boolean, any)
	local result: { any }? = nil
	task.spawn(function()
		result = table.pack(pcall(fn))
	end)
	local deadline = os.clock() + seconds
	while not result and os.clock() < deadline do
		task.wait()
	end
	if not result then
		return false, "timeout"
	end
	return result[1], result[2]
end
```

It polls once per frame, which is negligible for occasional calls. Note the worker keeps running after a timeout; you cannot abort an engine call in progress, you can only stop waiting for it.

---

## 7. Result types for expected failures

For domain logic ("can this player buy this item?") return values communicate better than errors:

```lua
--!strict
export type BuyResult =
	{ ok: true, newBalance: number }
	| { ok: false, reason: "NotEnoughCoins" | "SoldOut" | "Cooldown" | "InvalidItem" }

local function tryBuy(profile: Profile, itemId: string): BuyResult
	local item = Items[itemId]
	if not item then return { ok = false, reason = "InvalidItem" } end
	if profile.coins < item.price then return { ok = false, reason = "NotEnoughCoins" } end
	profile.coins -= item.price
	table.insert(profile.items, itemId)
	return { ok = true, newBalance = profile.coins }
end
```

The type checker forces callers to handle each case, and the reason maps to a UI message. Errors remain for bugs and infrastructure failures.

**Validate untrusted input instead of pcalling it.** A remote handler that does `pcall(process, payload)` to survive garbage payloads also hides bugs. Validate types and ranges at the boundary ([[Server Authority and Validation]]), then process without `pcall`.

---

## 8. Logging that helps

- Include context: player UserId (not username in public logs), item IDs, the operation, attempt number.
- `warn` for recoverable issues, `error` for bugs, `print` sparingly (Output and the Developer Console are rate limited and noisy).
- Rate-limit repeated errors (once per key per minute) or one broken loop floods logs and hides everything else.
- `debug.traceback()` gives a stack; `debug.info(level, "sl")` gives source and line cheaply.
- Avoid logging inside per-frame code paths except behind a debug flag.

---

## 9. Pre-flight checks: stopping bugs before they ship

Many "runtime errors" are preventable before a script is ever saved. The reference project adopted a mandatory checklist before saving any script, after real crashes on rare branches (Measured):

1. **It compiles** (load the source with the compiler; syntax errors and compiler limits such as the 200-local limit show up here).
2. **No use-before-definition reads** (a scanner reports identifiers read before their local declaration; see [[Luau Language Essentials]]).
3. **Source under 200,000 characters** ([[Module Scripts and Requiring]]).
4. **Clone-require check** for modules (the module loads and returns what callers expect).

A static sweep of 1,084 scripts with these checks plus a scan of remotes, `WaitForChild` paths, requires and attribute names found broken config text, a UI builder returning undefined globals, and dozens of readers of an attribute that nothing set any more (Measured). Add `--!strict` and Selene or luau-lsp in CI and most of this is automatic ([[External Tooling - Rojo Wally Selene StyLua]]).

---

## 10. Failure policy by situation

Deciding what a failure *means* is harder than catching it. A table to agree on as a team:

| Situation | On failure | Why |
|---|---|---|
| Loading player data | Retry with backoff; if still failing, kick with a friendly message (or hold the player in a lobby state) and never save | Saving defaults would overwrite real data |
| Autosave | Log, keep the dirty flag, retry next cycle | Next save carries the change |
| Final save on leave / shutdown | Time-boxed retries, then log loudly | Limited time; data loss risk is real, measure it ([[Data Loss Prevention and Recovery]]) |
| Granting a purchase in `ProcessReceipt` | Return `NotProcessedYet` so Roblox retries later | Never grant without a durable record ([[Developer Products and ProcessReceipt]]) |
| Leaderboard read | Show cached or empty board, retry later | Cosmetic |
| Badge award | Retry a few times, then queue for next session | Low stakes |
| Teleport | Listen to `TeleportInitFailed`, retry with backoff, then return the player to a safe state | Players otherwise get stuck ([[Teleporting and Multi-Place Games]]) |
| HTTP to your own backend | Circuit breaker: after N failures, stop calling for a while | Protects both sides |
| A remote payload fails validation | Drop silently (optionally count for anti-cheat) | Do not give exploiters error details |
| A bug in one entity's update | Log once, skip that entity, keep the loop running | One bad enemy should not freeze all enemies |

### Circuit breaker sketch

```lua
--!strict
local Breaker = {}
Breaker.__index = Breaker

function Breaker.new(threshold: number, cooldown: number)
	return setmetatable({ failures = 0, openUntil = 0, threshold = threshold, cooldown = cooldown }, Breaker)
end

function Breaker.call(self: any, fn: () -> any): (boolean, any)
	if os.clock() < self.openUntil then
		return false, "circuit open"
	end
	local ok, result = pcall(fn)
	if ok then
		self.failures = 0
	else
		self.failures += 1
		if self.failures >= self.threshold then
			self.openUntil = os.clock() + self.cooldown
			self.failures = 0
		end
	end
	return ok, result
end

return Breaker
```

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Player data wiped after an outage | Load failure treated as "new player" | Distinguish failure from empty; kick or retry |
| Bugs never appear in logs | Broad `pcall` around logic | Wrap only fallible calls; log failures |
| DataStore throttling cascades | Immediate retries in a loop | Backoff with jitter; attempt cap |
| Double rewards after retry | Non-idempotent write retried | `UpdateAsync` with receipt/version checks |
| Server hangs on shutdown | Unbounded retries in `BindToClose` | Time-boxed retries |
| A remote handler errors on bad input | No validation | Validate at the boundary |
| Errors invisible after `coroutine.resume` | Return value ignored | `task.spawn` or check results |

## Checklist

- [ ] Every web-backed call is wrapped and its failure has a defined outcome.
- [ ] Retries: capped, exponential, jittered, idempotent, re-validated after waits.
- [ ] No broad `pcall` around game logic; bugs fail loudly.
- [ ] Load failure is never treated as empty data.
- [ ] Errors are reported to telemetry with context and rate limits.
- [ ] Scripts pass compile, use-before-definition, size and require checks before saving.

## See also

[[Task Library Coroutines and Yielding]] · [[DataStore Fundamentals]] · [[Saving Correctly - Autosave and BindToClose]] · [[Data Loss Prevention and Recovery]] · [[HttpService and External APIs]] · [[Server Authority and Validation]] · [[Crash and Error Telemetry]] · [[Debugger Breakpoints and Logging]]

## Connected notes
<!-- auto-links:start -->
[[Error Handling - pcall xpcall and Promise Patterns]] · [[Cookbook - Data and Saving]] · Official Docs - Scripting and Luau · Reading Luau Errors and Stack Traces · Debugging DataStore Problems · Skill - Roblox DataStore Safety
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Reading Luau Errors and Stack Traces]] · [[Functions Closures and Upvalues]] · [[Events Signals and Connections]] · [[Tables Metatables and OOP]] · [[Text Filtering - TextService for Names, Signs and Messages]] · [[Script Types and Run Context]] · [[Luau Performance Patterns with Benchmarks]] · [[Parallel Luau and Actors]] · [[Metatables and OOP - When and When Not]]
<!-- related:end -->
