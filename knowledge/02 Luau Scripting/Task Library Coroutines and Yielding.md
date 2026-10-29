---
tags: [luau, task, coroutines, scheduler, yielding, threads]
---
# Task Library Coroutines and Yielding

<!-- tldr:start -->
> [!tldr] TL;DR
> - Client freezes on an action: Unbounded loop without yield -> Cap attempts; yield; check targets exist
> - Errors vanish: `coroutine.resume` result ignored -> Use `task.spawn`, or check `ok, err`
> - Timer drifts or fires late: Deprecated `wait`/`delay` throttling -> `task.*`
> - No `wait`, `spawn`, `delay`, `tick` in the codebase.
> - Every loop is bounded or yields each iteration.
> - Per-frame work uses the correct RunService event and is disconnectable.
>
> Cost: TL;DR ~160 tok · whole note ~3.7k tok. Read more: ## 3. Coroutines · ## 5. Loops that run forever · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox runs all Luau on one main thread per VM, cooperatively. A script runs until it **yields** (waits for something) or returns; then the engine's task scheduler resumes some other thread. There is no preemption: a loop that never yields freezes the whole client or server. The `task` library is how you talk to the scheduler; the `coroutine` library is the lower-level primitive underneath. This note explains both, how they interact with the frame, the deprecated globals they replace, how to cancel work, and the freeze and leak failure modes.

Parallel execution across cores is a different model, covered in [[Parallel Luau and Actors]]. The frame order (when `PreSimulation`, `Heartbeat` and friends run) is in [[Frame Order and RunService Timing]].

---

## 1. The task library (Docs)

| Function | What it does |
|---|---|
| `task.spawn(fnOrThread, ...)` | Calls/resumes **immediately** through the scheduler; returns the thread |
| `task.defer(fnOrThread, ...)` | Calls/resumes at the **end of the current resumption cycle** (later this frame); returns the thread |
| `task.delay(seconds, fnOrThread, ...)` | Calls/resumes on the first `Heartbeat` after `seconds` have elapsed; returns the thread |
| `task.wait(seconds?)` | Yields until `seconds` (default 0) have elapsed, resumes on the next `Heartbeat`, returns actual elapsed time |
| `task.cancel(thread)` | Closes a thread so it is never resumed |
| `task.desynchronize()` / `task.synchronize()` | Switch between parallel and serial phases (Actors only) |

Key documented guarantees:
- `task.wait` and `task.delay` do **not throttle**: the thread resumes on the first Heartbeat at which it is due. `task.wait()` with no argument equals `RunService.Heartbeat:Wait()`.
- `task.delay(0, f)` runs `f` on the very next Heartbeat.
- `task.spawn` from a serial phase resumes in the serial phase; from a parallel phase, in the parallel phase. Same for `defer`, `delay` and `wait`.
- `task.cancel` can fail on threads in certain states: the currently running thread, and threads that have resumed another coroutine, cannot be cancelled and it errors. Docs warn not to rely on these failure conditions; they may be lifted.

### Resolution

`task.wait(0.01)` cannot wait less than one frame. At 60 FPS a Heartbeat is about 16.7 ms, so `task.wait(0.01)` returns about 0.0167 (Rule of thumb; at lower frame rates, longer). Server Heartbeat runs at about 60 Hz. Anything timing-sensitive should measure elapsed time (`os.clock()`, or the returned value) instead of assuming the requested duration:

```lua
local elapsed = task.wait(0.25)   -- actually 0.25 to 0.27 at 60 FPS
```

### Deprecated globals

`wait()`, `spawn()` and `delay()` are deprecated. The old `wait` throttles (it can resume much later than requested under load, and it historically had a ~0.03 s minimum), and `spawn` does not run immediately. Replace them all; lint `DeprecatedGlobal` finds them.

| Old | New | Behaviour change |
|---|---|---|
| `wait(n)` | `task.wait(n)` | No throttling; returns only elapsed time |
| `spawn(f)` | `task.spawn(f)` or `task.defer(f)` | `spawn` started later; `task.spawn` runs now. If code relied on the delay, use `task.defer` |
| `delay(n, f)` | `task.delay(n, f)` | No throttling |

---

## 2. spawn vs defer: which one

```lua
print("A")
task.spawn(function() print("B") end)
task.defer(function() print("C") end)
print("D")
--> A, B, D, C
```

- **`task.spawn`**: the function runs **now**, up to its first yield, before the caller continues. Use it to start background work that should begin immediately, or to call a callback that might yield without blocking the caller.
- **`task.defer`**: the function runs after the current code (and the current batch of resumptions) finishes. Use it to avoid re-entrancy ("fire this after I finish updating my state"), to coalesce many changes into one update, or to break a deep call chain.

```lua
-- Coalesce: many property changes in one frame cause one rebuild
local dirty = false
local function markDirty()
	if dirty then return end
	dirty = true
	task.defer(function()
		dirty = false
		rebuildInventoryUI()
	end)
end
```

**Deferred engine events** ([[Events Signals and Connections]]) behave like `task.defer` for signal handlers when `Workspace.SignalBehavior` is `Deferred`.

---

## 3. Coroutines

The `coroutine` library (Docs: `create`, `resume`, `yield`, `wrap`, `status`, `running`, `isyieldable`, `close`, and on Roblox `finally`) is the primitive. A coroutine is a thread with its own stack that you resume manually.

```lua
local gen = coroutine.create(function(n: number)
	for i = 1, n do
		coroutine.yield(i * i)
	end
	return "done"
end)

print(coroutine.resume(gen, 3))   --> true 1
print(coroutine.resume(gen))      --> true 4
print(coroutine.resume(gen))      --> true 9
print(coroutine.resume(gen))      --> true done
print(coroutine.status(gen))      --> dead
print(coroutine.resume(gen))      --> false cannot resume dead coroutine
```

Status values: `"suspended"`, `"running"`, `"normal"` (it resumed another coroutine), `"dead"`.

**Errors are swallowed by `coroutine.resume`.** It returns `false, err` instead of throwing. Code that ignores the return value hides errors completely. `coroutine.wrap` rethrows, but the traceback points at the wrap call. `task.spawn` reports the error to the Output with a proper trace, which is usually what you want.

**`coroutine.finally(co, callback)`** (Roblox Docs, 2026) registers a callback run when `co` reaches a terminal state: `callback("finished", ...results)`, `callback("error", err)` or `callback("cancelled")` (after `coroutine.close` or `task.cancel`). Callbacks run at most once, last-registered first; registering on a dead coroutine errors; a coroutine with finalizers that ends inside a `coroutine.wrap` resume raises "cannot run finalizers from a wrapped coroutine". Useful for cleanup that must run however a task ends. Check that your Studio version has it before relying on it.

### Mixing coroutines with the engine

Rule of thumb: once a thread has been yielded **by the engine** (it is inside `task.wait`, `WaitForChild`, a web call), do not resume it yourself with `coroutine.resume`; the engine will also resume it later and you get a double resume or a confusing error. Use `task.spawn(thread, ...)` to resume threads you yielded with `coroutine.yield`, and leave engine-yielded threads alone.

A clean "wait for one of several things" helper uses a manually yielded thread:

```lua
--!strict
-- Yields until the signal fires or the timeout passes. Returns true if fired.
local function waitWithTimeout(signal: RBXScriptSignal, timeout: number): boolean
	local thread = coroutine.running()
	local fired = false
	local timeoutThread: thread? = nil
	local conn: RBXScriptConnection? = nil

	conn = signal:Once(function()
		fired = true
		if timeoutThread then task.cancel(timeoutThread) end
		task.spawn(thread)
	end)

	timeoutThread = task.delay(timeout, function()
		if conn then conn:Disconnect() end
		task.spawn(thread)
	end)

	coroutine.yield()
	return fired
end
```

Each path cancels the other before resuming, so the waiting thread is resumed exactly once.

---

## 4. What yields

Calls that yield include: `task.wait`, `RBXScriptSignal:Wait`, `Instance:WaitForChild`, `RemoteFunction:InvokeServer`/`InvokeClient`, `BindableFunction:Invoke` (if the handler yields), all `DataStore`/`MemoryStore` calls, `HttpService:RequestAsync`/`GetAsync`/`PostAsync`, `MarketplaceService` and `Players` async lookups, `TeleportService`, `ContentProvider:PreloadAsync`, `InsertService:LoadAsset`, `Player:LoadCharacterAsync` (in practice), and `require` of a module that yields. Most methods ending in `Async` yield.

`coroutine.isyieldable()` tells you whether the current context may yield. Contexts where yielding is not allowed include metamethods, `table.sort` comparators and `string.gsub` callbacks; yielding there errors ("attempt to yield across metamethod/C-call boundary" style messages).

`pcall` and `xpcall` are yieldable in Luau (Docs), so `pcall(dataStore.GetAsync, dataStore, key)` is fine.

---

## 5. Loops that run forever

### The freeze

A loop that never yields blocks the VM. On the client, the game freezes; on the server, every player lags. Studio may eventually stop it with a script timeout error. A real case from the reference project: a UI effect helper retried `while true do` until a decorative frame parented successfully. After a click destroyed the layer it parented into, every attempt failed instantly, the loop never yielded, and the client froze on every click for some item rarities (Measured). The fix: bounded attempts (max 4), return `nil` when the parent is gone, and have callers skip `nil`.

Rules:
- Every `while` and `repeat` loop either has a provable bound or yields every iteration.
- A retry loop checks that its target still exists (`instance.Parent ~= nil`) and has an attempt cap.
- Long CPU work (generation, pathfinding over many nodes) yields periodically: `if os.clock() - start > 0.005 then task.wait() start = os.clock() end`.

### Per-frame work: Heartbeat, not `while task.wait()`

```lua
-- Acceptable for coarse timers (once per second)
task.spawn(function()
	while true do
		task.wait(1)
		regenerateStamina()
	end
end)

-- Per-frame logic: connect to the RunService event that matches your phase
local conn = RunService.Heartbeat:Connect(function(dt: number)
	updateProjectiles(dt)
end)
```

`while true do task.wait() ... end` works but ties you to a thread that is awkward to stop. A connection can be disconnected. Choose the event by phase: `PreSimulation` to drive physics inputs, `PreRender` (client) for camera and visuals, `Heartbeat` for general post-physics logic ([[Frame Order and RunService Timing]]).

### Stopping loops cleanly

Every background loop needs an owner and a stop condition:

```lua
--!strict
local Spawner = {}
Spawner.__index = Spawner

function Spawner.new(interval: number)
	local self = setmetatable({ running = true, thread = nil :: thread? }, Spawner)
	self.thread = task.spawn(function()
		while self.running do
			spawnWave()
			task.wait(interval)
		end
	end)
	return self
end

function Spawner.Destroy(self: any)
	self.running = false
	if self.thread and coroutine.status(self.thread) == "suspended" then
		task.cancel(self.thread)   -- stop it mid-wait instead of after the next wave
	end
end
```

**Thread leaks.** A thread waiting on a signal that never fires (for example `player.CharacterAdded:Wait()` after the player left) stays suspended forever, holding its upvalues. Prefer `Once` connections that you disconnect on cleanup, or timeouts.

**Disabled or destroyed scripts.** Setting `Enabled = false` or destroying a script drops its threads: yielded threads are never resumed (Docs: BaseScript). But a thread currently running continues until it yields. Connections made by that script are disconnected when the script is destroyed or disabled (Rule of thumb: verify for connections to signals on objects outside the script if you depend on it; explicit cleanup is safer).

---

## 6. Timing patterns

```lua
-- Elapsed time for durations: os.clock() (high resolution, monotonic within a session)
local start = os.clock()
doWork()
print(("took %.2f ms"):format((os.clock() - start) * 1000))

-- Wall clock for timestamps saved to DataStores: os.time() (UTC seconds) or DateTime.now()
local nextReward = os.time() + 24 * 3600

-- Server-synchronized time shared by server and clients: workspace:GetServerTimeNow()
```

Do not use `tick()` (deprecated, timezone-dependent on some platforms). Do not use frame counts as time; frame rates vary from 20 to 240 FPS across devices.

**Fixed-step accumulation** for logic that must be frame-rate independent:

```lua
local STEP = 1 / 30
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += math.min(dt, 0.25)      -- clamp to avoid a spiral after a hitch
	while acc >= STEP do
		simulate(STEP)
		acc -= STEP
	end
end)
```

---

## 7. Yielding in event handlers and ordering

Each connected handler runs in its own thread, so one handler yielding does not block others. But it means handler code after a yield runs in a later frame, interleaved with everything else. Classic bug: a `PlayerAdded` handler loads data (yields 0.2 to 2 s), then sets up leaderstats; meanwhile another system already read the missing leaderstats. Fix by making dependents wait for an explicit "ready" signal or attribute, not by adding `task.wait(1)`.

`task.wait(n)` to "let things load" is never a fix; it is a race with a longer fuse. Wait for the actual condition (`WaitForChild`, an attribute, a signal).

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Client freezes on an action | Unbounded loop without yield | Cap attempts; yield; check targets exist |
| Errors vanish | `coroutine.resume` result ignored | Use `task.spawn`, or check `ok, err` |
| Timer drifts or fires late | Deprecated `wait`/`delay` throttling | `task.*` |
| "cannot resume non-suspended coroutine" | Resuming an engine-yielded or running thread | Only resume threads you yielded yourself; resume once |
| Code after `task.spawn` runs before the spawned function's later half | Expected: spawn runs until first yield | Use signals or explicit sequencing |
| Loops keep running after round end | No owner/stop flag | Owner object with `Destroy` and `task.cancel` |
| `task.cancel` errors | Cancelling the running thread | Set a flag and return instead |

## Checklist

- [ ] No `wait`, `spawn`, `delay`, `tick` in the codebase.
- [ ] Every loop is bounded or yields each iteration.
- [ ] Per-frame work uses the correct RunService event and is disconnectable.
- [ ] Background threads are owned and cancellable.
- [ ] Code re-validates state after every yield.
- [ ] Durations use `os.clock`, timestamps `os.time`/`DateTime`, cross-machine time `GetServerTimeNow`.

## See also

[[Events Signals and Connections]] · [[Frame Order and RunService Timing]] · [[Parallel Luau and Actors]] · [[Error Handling and Retries]] · [[Functions Closures and Upvalues]] · [[Script Performance]] · [[Server Lifecycle and Shutdown]]

## Connected notes
<!-- auto-links:start -->
[[Custom Schedulers and Coroutine Patterns]] · [[Building a Signal Library]] · [[Error Handling - pcall xpcall and Promise Patterns]] · [[Links - Coroutines, task library and async]] · [[Debugging Race Conditions and Yield Order]] · [[Reading Luau Errors and Stack Traces]]
<!-- auto-links:end -->
