---
tags: [luau, advanced-luau, signals, events, coroutines, library-design, testing, type/guide, area/scripting, level/advanced, area/design]
---
# Building a Signal Library

<!-- tldr:start -->
> [!tldr] TL;DR
> - Handler runs after `Disconnect`: Deferred call queued before disconnect, not re-checked -> Check `Connected` when the deferred call runs
> - New listener fires in the same event that created it: In-place append during iteration -> Copy-on-write or snapshot
> - One erroring handler stops all others: Inline dispatch -> Runner thread or `task.spawn`
> - Handler order is guaranteed and documented.
> - Disconnect and connect during fire have defined, tested behaviour.
> - Handlers run isolated from each other's errors and yields without allocating per call in the common case.
>
> Cost: TL;DR ~180 tok · whole note ~5.3k tok. Read more: ## 2. Where handlers run: pooled runner threads · ## 4. The library · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Events Signals and Connections]] explains engine signals, Immediate versus Deferred handlers, connection leaks, and gives a compact pure-Luau signal that spawns a thread per handler. That signal is correct and fine for most uses. This note builds a production-grade one from first principles, and more importantly explains each design decision a signal library has to make, because those decisions are where custom signals cause bugs: what happens when a handler disconnects during a fire, connects during a fire, errors, or yields; what order handlers run in; how much each fire allocates; and how deferred mode differs. By the end you will have a typed library, a test list for it, and an observable value built on top.

Community signal libraries and the signals bundled with frameworks answer the same questions, each in its own way. Comparing one with this note after reading it is a good exercise in spotting which decisions each library made.

---

## 1. The decisions

Every signal library answers these questions, explicitly or by accident.

| Decision | Options | This library |
|---|---|---|
| Where does a handler run? | Inline in the firing thread; a new thread per handler; a reused thread | A small pool of reused "runner" threads, new one only when needed |
| Handler order | Unspecified; connect order; reverse order | Connect order, guaranteed |
| Disconnect during fire | Still called this fire; not called | Not called if disconnected before its turn |
| Connect during fire | Called this fire; not called | Not called until the next fire |
| Handler errors | Stop the fire; isolate and continue | Isolated, reported with a traceback, fire continues |
| Handler yields | Blocks the fire; isolated | Isolated, later handlers run immediately |
| Immediate or deferred | Run now; queue for the next resumption point | Immediate by default, deferred as an option |
| Arguments | By reference; copied | By reference (unlike BindableEvent) |
| Storage | Dictionary; linked list; array | Copy-on-write array |

The engine's own promise on order is weaker: handler order for engine signals is not something to depend on ([[Events Signals and Connections]]). A Luau signal can do better, and connect-order is worth guaranteeing because systems that layer behaviour (base damage, then modifiers, then UI) start depending on it whether you promise it or not.

---

## 2. Where handlers run: pooled runner threads

Three options, with costs:

- **Inline** (`fn(...)` directly in `Fire`): no allocation, fastest. But one handler that errors stops the rest, and one that yields (a `task.wait` buried in a helper) stalls the firing code. Every handler author must know the rules. Acceptable for a private signal inside one module; dangerous in a shared library.
- **New thread per handler** (`task.spawn(fn, ...)`): isolation for errors and yields, but a new coroutine per handler per fire. For a signal fired every frame with ten listeners, that is 600 threads per second of garbage ([[Luau Garbage Collection and the Memory Model]]).
- **Pooled runner threads**: keep a small stack of idle coroutines. To call a handler, pop an idle one (or create one if the stack is empty) and start it with the handler and its arguments. A runner that finishes its handler normally pushes itself back on the stack and parks. A runner whose handler yields or errors never reaches that push, so it simply drops out of the pool. You pay for a new thread only in the cases that need isolation.

The mechanism in a few lines:

```lua
local idleRunners: { thread } = {}
local MAX_IDLE_RUNNERS = 16

local function serve(fn: (...any) -> (), ...: any)
	fn(...)
end

local function runnerBody(...: any)
	serve(...) -- the first job arrives as the coroutine's start arguments
	while #idleRunners < MAX_IDLE_RUNNERS do
		table.insert(idleRunners, coroutine.running()) -- only reached after a clean return
		serve(coroutine.yield()) -- later jobs arrive as resume arguments
	end
end
```

To dispatch: `local runner = table.remove(idleRunners) or coroutine.create(runnerBody)`, then `task.spawn(runner, fn, ...)`. A fresh coroutine receives `fn, ...` as its start arguments; a parked one receives them as the results of `coroutine.yield()`. Both paths end in `serve`, so no priming resume is needed.

Walk through the cases:

- **Handler returns.** `serve` returns, the runner pushes itself onto `idleRunners` and parks in `coroutine.yield()`. The next dispatch pops it. No allocation.
- **Handler yields** (for example `task.wait(1)`). The runner is suspended inside `fn` and is not on the stack, so the next dispatch pops another idle runner or creates one. When the old runner wakes and finishes, it pushes itself back, so the pool refills on its own.
- **Handler errors.** The runner dies with the error before it can push itself back. `task.spawn` reports the error to the Output with a traceback, which is the behaviour developers expect from engine signals.
- **Pool full.** A runner that finishes while the stack already holds `MAX_IDLE_RUNNERS` threads returns from `runnerBody` and is collected, so a burst of yielding handlers cannot leave hundreds of parked threads behind.

The `task.spawn` call matters: resuming the runner through the task library (rather than `coroutine.resume`) is what gives proper error reporting and keeps the thread in the engine's scheduler if the handler yields ([[Task Library Coroutines and Yielding]]).

---

## 3. Storage and the fire-time snapshot

Disconnecting or connecting while a fire is in progress is common: a `Once` handler disconnects itself, a quest step completes and connects the next step's listener, a death handler disconnects the whole character's connections. The storage design decides what happens.

**Copy-on-write array.** Handlers live in an array. `Fire` reads the array reference once and iterates it. `Connect` and `Disconnect` never modify the array in place; they build a new array and replace the reference. So a fire in progress keeps iterating the old array, unaffected by changes, and the next fire sees the new one.

- Connect during fire: the new handler is in the new array only, so it is not called this fire. Correct by construction.
- Disconnect during fire: the old array still contains the connection. Check `conn.Connected` before calling each handler, so a handler disconnected earlier in the same fire is skipped.
- `Fire` allocates nothing for the iteration.
- `Connect` and `Disconnect` cost O(n) because they copy the array.

**Linked list**: connections form a list; connect prepends at the head, disconnect unlinks. A fire walks the list from the head it saw at the start; a node that is unlinked during the fire keeps its `next` pointer so iteration can continue past it. Connect and disconnect are O(1), but with prepend the handlers run in reverse connect order, and the iteration rules are subtler to get right.

The trade-off is about churn. Signals with a few to a few dozen long-lived connections (most game signals) favour the array: ordered, simple, no per-fire cost. A signal with thousands of short-lived connections (one per projectile, connected and disconnected constantly) favours the linked list. If you are in the second case, reconsider whether every projectile should hold a connection at all; a central system that iterates projectiles is usually better ([[Entity Component Systems]]).

---

## 4. The library

```lua
--!strict
-- Signal.lua: typed, ordered, reuses pooled runner threads, optional deferred mode.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	WaitFor: (self: Signal<T...>, timeout: number) -> (boolean, T...),
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

-- Runner pool (shared by all signals in this VM)
local idleRunners: { thread } = {}
local MAX_IDLE_RUNNERS = 16

local function serve(fn: (...any) -> (), ...: any)
	fn(...)
end

local function runnerBody(...: any)
	serve(...)
	while #idleRunners < MAX_IDLE_RUNNERS do
		table.insert(idleRunners, coroutine.running())
		serve(coroutine.yield())
	end
end

local function dispatch(fn: (...any) -> (), ...: any)
	local runner = table.remove(idleRunners) or coroutine.create(runnerBody)
	task.spawn(runner, fn, ...)
end

-- Connection
local ConnectionClass = {}
ConnectionClass.__index = ConnectionClass

function ConnectionClass.Disconnect(self: any)
	if not self.Connected then
		return
	end
	self.Connected = false
	local signal = self._signal
	local old = signal._handlers
	local new = table.create(math.max(#old - 1, 0))
	for _, c in old do
		if c ~= self then
			table.insert(new, c)
		end
	end
	signal._handlers = new
end

-- Signal
local SignalClass = {}
SignalClass.__index = SignalClass

local Signal = {}

function Signal.new<T...>(options: { deferred: boolean? }?): Signal<T...>
	local self = setmetatable({
		_handlers = {},
		_deferred = if options and options.deferred then true else false,
		_destroyed = false,
	}, SignalClass)
	return self :: any
end

function SignalClass.Connect(self: any, fn: (...any) -> ()): Connection
	local conn = setmetatable({ Connected = true, _signal = self, _fn = fn }, ConnectionClass)
	if self._destroyed then
		conn.Connected = false
		warn("Connect called on a destroyed signal")
		return conn :: any
	end
	local new = table.clone(self._handlers)
	table.insert(new, conn)
	self._handlers = new
	return conn :: any
end

function SignalClass.Once(self: any, fn: (...any) -> ()): Connection
	local conn: any
	conn = self:Connect(function(...)
		if conn.Connected then
			conn:Disconnect()
			fn(...)
		end
	end)
	return conn
end

function SignalClass.Fire(self: any, ...: any)
	local handlers = self._handlers        -- snapshot: copy-on-write keeps it stable
	if self._deferred then
		for _, conn in handlers do
			if conn.Connected then
				-- Re-check at run time: a disconnect between Fire and the resumption point wins.
				task.defer(function(...)
					if conn.Connected then
						conn._fn(...)
					end
				end, ...)
			end
		end
	else
		for _, conn in handlers do
			if conn.Connected then
				dispatch(conn._fn, ...)
			end
		end
	end
end

function SignalClass.Wait(self: any): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function SignalClass.WaitFor(self: any, timeout: number): (boolean, ...any)
	local thread = coroutine.running()
	local finished = false
	local conn: any
	local timer: thread

	conn = self:Connect(function(...)
		if finished then return end
		finished = true
		conn:Disconnect()
		task.cancel(timer)
		task.spawn(thread, true, ...)
	end)

	timer = task.delay(timeout, function()
		if finished then return end
		finished = true
		conn:Disconnect()
		task.spawn(thread, false)
	end)

	return coroutine.yield()
end

function SignalClass.DisconnectAll(self: any)
	for _, conn in self._handlers do
		conn.Connected = false
	end
	self._handlers = {}
end

function SignalClass.Destroy(self: any)
	self:DisconnectAll()
	self._destroyed = true
end

return Signal
```

Usage with types:

```lua
local Signal = require(ReplicatedStorage.Shared.Signal)

local Damaged: Signal.Signal<Model, number> = Signal.new()

local conn = Damaged:Connect(function(target, amount)
	-- target: Model, amount: number
end)

Damaged:Fire(enemyModel, 25)
local ok, target, amount = Damaged:WaitFor(5)   -- ok: boolean
```

### Notes on the implementation

- **The `Once` wrapper checks `Connected` first.** If two fires happen in quick succession and the first handler call yields before disconnecting (it does not here, but a variant might), the check stops a double call. Disconnecting before calling `fn` also means that if `fn` errors, the connection is already gone, matching what users expect from "once".
- **`Wait` uses `Once`, then `task.spawn(thread, ...)`.** The waiting thread was suspended by `coroutine.yield` in our own code, so resuming it with `task.spawn` is safe. Never resume a thread suspended by the engine ([[Custom Schedulers and Coroutine Patterns]]).
- **`WaitFor`** guards both paths with `finished`, cancels the other path, and resumes exactly once. Its first return value distinguishes a timeout from a fire that carried no arguments, which a plain `nil` check cannot.
- **Deferred mode allocates a closure per handler per fire**, because the connection must be re-checked when the deferred call runs. That is the price of correct "disconnect wins" behaviour. If you do not need it, pass `conn._fn` directly to `task.defer` and document that a handler disconnected after the fire may still run once.
- **`Destroy` does not clear `_fn` on connections.** Callers might still hold connections; clearing `_signal` and `_fn` on each connection in `Destroy` releases closures sooner if callers keep stale connection objects around. Add it if your profiling shows retained closures.

---

## 5. Semantics worth testing

These are the tests that catch the real bugs. Each is a few lines with a counter table ([[Automated Testing with TestEZ and Jest-Lua]]).

1. **Order.** Connect A, B, C; fire; the call log is `A, B, C`.
2. **Disconnect self during fire.** A disconnects itself; fire twice; A is called once, B and C twice.
3. **Disconnect another during fire.** A disconnects C; first fire calls A and B only.
4. **Connect during fire.** A connects D; first fire does not call D; second fire does.
5. **Error isolation.** B errors; A and C still run; the Output shows B's error with a traceback.
6. **Yield isolation.** B calls `task.wait(0.1)`; C runs before B resumes; after B resumes, a later fire still works (runner recovered).
7. **Runner reuse.** Fire 1,000 times with three non-yielding handlers; heap growth per fire is near zero ([[Luau Garbage Collection and the Memory Model]] has the measuring helper).
8. **Once.** Fire twice; called once. Fire with a yielding handler twice quickly; still called once.
9. **Wait and WaitFor.** Wait returns the fired arguments; WaitFor returns `false` after the timeout and does not resume later when the signal finally fires.
10. **Deferred mode.** Handlers run after `Fire` returns; a handler disconnected between `Fire` and the resumption point does not run.
11. **Destroy.** Fire after destroy calls nothing; connect after destroy returns a disconnected connection.
12. **Nested fire.** A handler fires the same signal once (guarded); order and counts are as expected; no runner is lost.

Run test 6 and test 7 before trusting any signal library, including community ones; they check the two properties that matter most and are easiest to break.

---

## 6. Pitfalls that are not the library's fault

**Shared mutable payloads.** Arguments are passed by reference. If the first handler modifies a table payload (`hit.damage *= 2`), every later handler sees the modified value, in connect order. Sometimes that is the design (a modifier pipeline). Usually it is a bug. Freeze payloads that are meant to be read-only (`table.freeze(hit)` before firing), or give modifiers an explicit pipeline API instead of a signal ([[Combat Systems Architecture]]).

**Recursive fires.** A handler that fires the same signal recurses. With immediate dispatch, an unguarded recursion overflows the stack; with deferred dispatch, it becomes a loop that runs forever, one resumption point at a time. Guard with a depth counter or a "firing" flag in the code that fires.

**Signals as hidden control flow.** A chain `PurchaseCompleted -> GrantItem -> InventoryChanged -> QuestProgress -> RewardGranted` is five indirections for one action. When it breaks, nobody can see the path. Use signals for one-to-many notification where the sender should not know the receivers. Use direct calls where one module needs another to do something ([[Module Design and Dependency Injection]]).

**Leaks through connections.** A connection holds its handler, and the handler holds its upvalues. A signal that lives for the whole server, with handlers connected per character and never disconnected, is the classic leak. Put connections in a per-owner cleanup bag and disconnect them when the owner ends ([[Memory Budgets and Leaks]]).

**Crossing boundaries.** A Luau signal works within one VM. It does not cross client and server (use remotes), and it does not cross Actors (use Actor messages). A module containing a signal, required in two Actors, is two separate signals ([[Parallel Luau and Actors]]).

---

## 7. Building on it: an observable value

UI code often needs "a value, and an event when it changes". A thin wrapper turns the signal into a state container:

```lua
--!strict
local Signal = require(script.Parent.Signal)

export type Value<T> = {
	get: (self: Value<T>) -> T,
	set: (self: Value<T>, newValue: T) -> (),
	Changed: Signal.Signal<T, T>,     -- (new, old)
}

local ValueClass = {}
ValueClass.__index = ValueClass

local Value = {}

function Value.new<T>(initial: T): Value<T>
	return setmetatable({ _v = initial, Changed = Signal.new() }, ValueClass) :: any
end

function ValueClass.get(self: any)
	return self._v
end

function ValueClass.set(self: any, newValue: any)
	local old = self._v
	-- NaN ~= NaN would fire on every set; treat NaN as equal to NaN
	if newValue == old or (newValue ~= newValue and old ~= old) then
		return
	end
	self._v = newValue
	self.Changed:Fire(newValue, old)
end

return Value
```

Two nuances are in the comment and the type. NaN never equals itself, so a naive equality check fires on every `set(0/0)`. And for table values, equality is by reference: mutating a table in place and calling `set` with the same table fires nothing. Either replace the table (`set(table.clone(t))` after the change) or treat table values as immutable. Declarative UI libraries build exactly this concept with dependency tracking on top ([[Declarative UI - React-Lua and Fusion]]); if you need more than a few values, use one of them instead of growing this.

---

## When not to build your own

- **One module, one listener.** A callback field or a direct call is simpler than a signal.
- **A team already using a framework** with its own signal type. Two signal libraries in one codebase is worse than either.
- **Cross-boundary events.** Use remotes, bindables or Actor messages; a Luau signal cannot help.
- **When a maintained community library already fits.** Writing your own is worth it when you need a specific semantic (ordering, deferred re-check) or want zero dependencies. Otherwise, vendor a well-known one, read it, and run the tests above against it.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Handler runs after `Disconnect` | Deferred call queued before disconnect, not re-checked | Check `Connected` when the deferred call runs |
| New listener fires in the same event that created it | In-place append during iteration | Copy-on-write or snapshot |
| One erroring handler stops all others | Inline dispatch | Runner thread or `task.spawn` |
| Heap grows per fire | Thread per handler per fire | Reuse a runner thread |
| `WaitFor` resumes twice | Timeout and fire both resume | One `finished` flag, cancel the other path |
| Later handlers see modified data | Shared mutable payload | Freeze payloads or use a pipeline |
| Signal works in one script, not another | Different VMs (Actors) or client versus server | Use the right channel |

## Checklist

- [ ] Handler order is guaranteed and documented.
- [ ] Disconnect and connect during fire have defined, tested behaviour.
- [ ] Handlers run isolated from each other's errors and yields without allocating per call in the common case.
- [ ] Deferred mode re-checks `Connected` at run time.
- [ ] `Wait` and `WaitFor` resume exactly once, through `task.spawn`.
- [ ] Payloads meant to be read-only are frozen.
- [ ] Connections are owned by a cleanup bag tied to the listener's lifetime.
- [ ] The twelve semantic tests pass, including runner recovery after a yield.

## See also

[[Advanced Luau Start Here]], [[Events Signals and Connections]], [[Task Library Coroutines and Yielding]], [[Custom Schedulers and Coroutine Patterns]], [[Luau Garbage Collection and the Memory Model]], [[Module Design and Dependency Injection]], [[Advanced Types - Generics and Type Functions]], [[Declarative UI - React-Lua and Fusion]], [[Debugging Race Conditions and Yield Order]], [[Memory Budgets and Leaks]]

## Connected notes
<!-- auto-links:start -->
[[Functions Closures and Upvalues]] · Error Handling - pcall xpcall and Promise Patterns · Reading Luau Errors and Stack Traces · Event Bus · Official Docs - Scripting and Luau
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Error Handling - pcall xpcall and Promise Patterns]] · [[Event Bus]] · [[Reading Luau Errors and Stack Traces]] · [[Tables Metatables and OOP]] · [[Luau Performance Patterns with Benchmarks]] · [[Serialization Formats for Saves and Networking]]
<!-- related:end -->
