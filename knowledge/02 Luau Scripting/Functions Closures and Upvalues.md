---
tags: [luau, functions, closures, upvalues, scope]
---
# Functions Closures and Upvalues

<!-- tldr:start -->
> [!tldr] TL;DR
> - Recursive function errors "attempt to call a nil value (global ...)": `local f = function` used for recursion -> `local function f`
> - Every button prints the same name: Shared outer variable captured -> Per-iteration local
> - Input handler does nothing after respawn: Captured old character -> Read `player.Character` at call time
> - Recursive functions use `local function`.
> - Handlers read current state, not state captured at script start.
> - No closures or threads created per object per frame.
>
> Cost: TL;DR ~170 tok · whole note ~4.9k tok. Read more: ## 3. Closures and upvalues · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Functions in Luau are values. They can be stored in tables, passed to other functions, returned, and they **capture** the local variables around them (upvalues). Almost every Roblox system is built from closures: event handlers, tween callbacks, ability kits, UI bindings. Understanding exactly what a closure captures, when it is allocated, and what keeps it alive explains a large share of real bugs: stale state, handlers that fire for the wrong object, memory that never frees, and the compile-time limits on upvalues.

---

## 1. Declaring functions

```lua
local function add(a: number, b: number): number   -- local function: name visible inside its own body
	return a + b
end

local mul = function(a: number, b: number): number  -- anonymous function assigned to a local
	return a * b
end

local M = {}
function M.greet(name: string) print(`hi {name}`) end     -- field
function M:describe() return tostring(self) end            -- method: implicit self
```

**`local function f` vs `local f = function`.** `local function f` is sugar for `local f; f = function ... end`, so `f` is in scope inside its own body and recursion works. With `local f = function`, the right side is evaluated before `f` exists, so a recursive call inside refers to a **global** `f`:

```lua
local fact = function(n: number): number
	return if n <= 1 then 1 else n * fact(n - 1)   -- global 'fact': nil at runtime
end
```

Always use `local function` for recursion.

---

## 2. Arguments, varargs and returns

- Missing arguments are `nil`; extra arguments are dropped. Luau does not check arity at runtime; strict mode does at edit time.
- `...` collects extra arguments. `select("#", ...)` counts them **including trailing nils**; `#{...}` does not.
- `table.pack(...)` returns a table with field `n`, which preserves nils.

```lua
local function forward(fn: (...any) -> ...any, ...: any)
	local args = table.pack(...)
	return fn(table.unpack(args, 1, args.n))   -- correct even with nils in the middle
end
```

**Multiple returns are truncated** except in the last position of a list:

```lua
local function two() return 1, 2 end
print(two(), "x")       --> 1 x      (truncated to one value)
print("x", two())       --> x 1 2    (expanded)
local t = { two(), two() }  -- { 1, 1, 2 }
print((two()))          --> 1        (parentheses force one value)
```

This bites `pcall`: `local ok, a, b = pcall(f)` gets all values, but `return pcall(f), extra` loses all but `ok`.

---

## 3. Closures and upvalues

A closure is a function plus references to the outer locals it uses. Those captured locals are **upvalues**. They are shared, not copied: every closure that captures a variable sees later writes to it.

```lua
local function makeCounter()
	local count = 0
	return function(): number
		count += 1
		return count
	end
end

local a, b = makeCounter(), makeCounter()
print(a(), a(), b())   --> 1 2 1   (each call to makeCounter creates a new 'count')
```

### Loop variables are fresh per iteration

In Luau, a `for` loop variable is a new local each iteration, so closures created in a loop capture different values (unlike `var` in old JavaScript):

```lua
for i = 1, 3 do
	task.delay(i, function()
		print(i)     --> 1, then 2, then 3
	end)
end
```

But a variable declared **outside** the loop is shared:

```lua
local current
for _, button in buttons do
	current = button
	button.Activated:Connect(function()
		print(current.Name)   -- always the LAST button: 'current' is one shared upvalue
	end)
end
```

Fix: capture a per-iteration local (`local thisButton = button`) or just use `button`, which is already per-iteration.

### Stale captures across respawns

A classic Roblox bug: a LocalScript captures `character` once at the top, then handlers keep using it after the player respawns. The old character is destroyed; the handler indexes a dead model or does nothing.

```lua
-- Wrong: captured once
local character = player.Character or player.CharacterAdded:Wait()
UserInputService.InputBegan:Connect(function(input)
	character.Humanoid.Jump = true     -- old character after respawn
end)

-- Right: read the current value when the event fires
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Jump = true
	end
end)
```

Alternatively, put the script in `StarterCharacterScripts` so it re-runs per character ([[Script Types and Run Context]]).

---

## 4. What closures cost

- **Allocation.** Creating a closure that captures mutable upvalues allocates a new function object each time the `function` expression runs. Luau caches closures that have no upvalues or only immutable module-level upvalues (Docs: luau.org performance). Note: caching changes identity, so `function() end == function() end` may be `true` in some cases; never use fresh anonymous functions as identity tokens.
- **Upvalue mutability.** Upvalues that are never reassigned are captured by value, which is cheaper. Reassigning a captured variable makes it a mutable upvalue (Docs). Mutating a table's *contents* does not count.
- **Lifetime.** A closure keeps every upvalue alive. A connection to a long-lived signal (`RunService.Heartbeat`, `Players.PlayerAdded`, a global BindableEvent) keeps its closure alive, which keeps every captured table and Instance alive, until you `Disconnect`. This is the number one Luau memory leak. See [[Events Signals and Connections]] and [[Memory Budgets and Leaks]].

In hot loops (per frame, per enemy), define helper functions once outside the loop and pass data as arguments instead of creating closures per iteration.

```lua
-- Allocates a closure per enemy per frame
RunService.Heartbeat:Connect(function(dt)
	for _, e in enemies do
		task.spawn(function() e:think(dt) end)   -- closure + thread per enemy per frame: very expensive
	end
end)

-- Better: plain calls; no new closures or threads
RunService.Heartbeat:Connect(function(dt)
	for _, e in enemies do
		e:think(dt)
	end
end)
```

---

## 5. The upvalue limit

One closure can capture at most **200 upvalues**, and one function at most 200 active locals and 255 registers (Docs: Luau bytecode format and compiler; error text `Out of upvalue registers when trying to allocate <name>: exceeded limit 200`). You hit it when a giant controller script defines hundreds of top-level locals and a big nested function uses many of them.

The reference project split a 201,561-character UI theme module into a parent and a child module. The child's functions needed **43 upvalues** from the parent; they were passed explicitly as arguments at the same load point, which worked only because none of them were reassigned later in the parent (Measured). The lesson generalizes: when you move code out of a closure into another module, captured variables turn into parameters, and anything the parent **reassigns** later must become a field of a shared table instead, or the child keeps a stale copy.

```lua
-- Parent module
local state = { theme = "dark" }      -- shared table: child sees later changes
local palette = buildPalette()       -- never reassigned: safe to pass by value
local Part2 = require(script.Part2)
Part2.install(state, palette)
```

---

## 6. Use before definition, again

Function bodies are compiled once, top to bottom. A name not yet declared as a local when the body is compiled resolves as a global, even if a local of that name appears later. See [[Luau Language Essentials]] for the full failure mode and the forward-declaration fix, and [[Luau Type System and Strict Mode]] for its typed form.

The reference project caught real crashes this way: callbacks that called helper functions declared further down the file, which only ran on rare branches (Measured). A static scan before every save is cheap insurance.

---

## 7. Higher-order patterns you will use

### Debounce / cooldown per key

```lua
--!strict
local function perKeyCooldown<K>(seconds: number): (key: K) -> boolean
	local last: { [K]: number } = {}
	return function(key: K): boolean
		local now = os.clock()
		local t = last[key]
		if t and now - t < seconds then
			return false
		end
		last[key] = now
		return true
	end
end

local canUse = perKeyCooldown(0.5) :: (Player) -> boolean
-- canUse(player) returns true at most twice per second per player.
-- Remember to clear entries on PlayerRemoving or the table grows forever.
```

### Memoize a pure function

```lua
local function memoize<A, R>(fn: (A) -> R): (A) -> R
	local cache = {}
	return function(arg: A): R
		local hit = cache[arg]
		if hit == nil then
			hit = fn(arg)
			cache[arg] = hit
		end
		return hit
	end
end

local xpForLevel = memoize(function(level: number): number
	return math.floor(100 * level ^ 1.5)
end)
```

Only memoize pure functions with bounded inputs; an unbounded cache is a leak.

### Once

```lua
local function once(fn: () -> ()): () -> ()
	local done = false
	return function()
		if done then return end
		done = true
		fn()
	end
end
```

### Callback tables instead of if-chains

```lua
local handlers: { [string]: (player: Player, arg: unknown) -> () } = {
	equip = function(player, arg) end,
	unequip = function(player, arg) end,
}

remote.OnServerEvent:Connect(function(player, action: unknown, arg: unknown)
	if typeof(action) ~= "string" then return end
	local handler = handlers[action]
	if handler then
		handler(player, arg)
	end
end)
```

This is also a safety measure: the client can only trigger actions that exist in the table.

---

## 8. Recursion and the stack

Luau has no proper tail calls (Docs), so even `return f(n - 1)` grows the stack. Deep recursion (walking a huge tree, flood fill on a big grid) can end with `stack overflow`. Convert to an explicit stack:

```lua
local function countDescendantsOfClass(root: Instance, className: string): number
	local stack = { root }
	local count = 0
	while #stack > 0 do
		local node = table.remove(stack) :: Instance
		if node:IsA(className) then count += 1 end
		for _, child in node:GetChildren() do
			table.insert(stack, child)
		end
	end
	return count
end
```

(For this specific job, `#root:GetDescendants()` with a filter or `QueryDescendants` is simpler; the pattern matters for your own data structures.)

---

## 9. Yielding inside callbacks

A function may yield (`task.wait`, `WaitForChild`, `InvokeServer`, DataStore calls) if it is running in a thread that allows it. Event handlers run in their own threads, so yielding inside them is allowed, but:

- A yielding handler means later code in it runs **after** other handlers and other frames; state may have changed (character died, player left). Re-check after every yield.
- Some callbacks must not yield: metamethods (`__index` etc.), `table.sort` comparators, `string.gsub` replacement functions, and many engine callbacks (for example `MarketplaceService.ProcessReceipt` may yield, but a `RemoteFunction.OnClientInvoke` that yields forever hangs the server's call). Know which kind you are in.
- `coroutine.wrap` and `task.spawn` give a callback its own thread if you need to yield without blocking the caller. See [[Task Library Coroutines and Yielding]].

---

## 10. Inspecting functions at runtime

`debug.info` (Docs) answers questions about functions and the call stack cheaply, useful in logging and tooling:

```lua
local function where(level: number?): string
	local source, line, name = debug.info((level or 1) + 1, "sln")
	return `{source}:{line} in {name or "anonymous"}`
end

local function describe(fn: (...any) -> ...any): string
	local source, line, arity, variadic = debug.info(fn, "sla")
	return `{source}:{line} takes {arity}{if variadic then "+" else ""} args`
end
```

Format letters: `s` source, `l` line, `n` name, `a` arity and variadic flag, `f` the function itself. `debug.traceback()` returns a full stack string. These are read-only; there is no `debug.getupvalue`/`setupvalue` in Roblox's sandbox, so closures are truly private state.

## 11. Designing function APIs

- **Options tables over long parameter lists** once a function has more than three or four optional parameters: `spawnEnemy({ kind = "Slime", level = 3, at = cf })`. Type the options table so callers get autocomplete.
- **Return values, not out-parameters.** Multiple returns are idiomatic: `local ok, reason = canBuy(...)`.
- **Callbacks get explicit arguments** instead of reading shared state; it keeps them testable and avoids stale captures.
- **Keep yielding explicit**: name functions that yield with an `Async` suffix (`loadProfileAsync`), matching Roblox's convention, so callers know a wait (and state changes) can happen inside.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Recursive function errors "attempt to call a nil value (global ...)" | `local f = function` used for recursion | `local function f` |
| Every button prints the same name | Shared outer variable captured | Per-iteration local |
| Input handler does nothing after respawn | Captured old character | Read `player.Character` at call time |
| Memory climbs every round | Connections keep closures and their upvalues alive | Disconnect on cleanup |
| Moved code to a child module; values stale | Parent reassigns a variable it passed by value | Share through a table |
| `stack overflow` on large data | Deep recursion, no tail calls | Explicit stack |
| Return values missing | Multiple returns truncated mid-list | Put the call last or capture explicitly |

## Checklist

- [ ] Recursive functions use `local function`.
- [ ] Handlers read current state, not state captured at script start.
- [ ] No closures or threads created per object per frame.
- [ ] Every long-lived connection has an owner that disconnects it.
- [ ] Caches and per-key tables are cleared when keys go away.

## See also

[[Luau Language Essentials]] · [[Events Signals and Connections]] · [[Task Library Coroutines and Yielding]] · [[Tables Metatables and OOP]] · [[Luau Performance and Native Codegen]] · [[Memory Budgets and Leaks]] · [[Ability Kits Architecture]]

## Nuances and edge cases

1. **A closure keeps everything it captures alive.** A connection callback that mentions `character` keeps the whole character model (and every instance under it) reachable for as long as the connection exists. One leaked closure per respawn is invisible in a 10-minute test and becomes hundreds of dead characters in a server that runs for 12 hours with 50 players. When a callback outlives the thing it references, capture an id or a weak reference, not the instance.
2. **Creating closures in a hot loop is cheap until it is not.** Luau allocates a new closure only when the function captures upvalues that differ per call; a function with no upvalues can be reused. Building a fresh callback per enemy per frame (`table.sort(list, function(a, b) ... end)` inside a Heartbeat) is fine for 20 enemies and shows up as GC pressure for 500. Hoist the comparator to module level when it captures nothing that changes.
3. **Debounce keys must be cleaned up.** A per-player cooldown table keyed by `Player` grows forever if nobody removes the entry on `PlayerRemoving`. On a busy server that sees 2,000 players a day the table holds 2,000 dead player objects. Clear per-player state in one place on leave.
4. **Yielding callbacks reorder your logic.** If a callback yields (a DataStore call, `task.wait`, `WaitForChild`), any code that assumed it ran to completion before the next event will see stale state. Two rapid button presses can both pass a "not busy" check before either sets the flag. Set the guard before the first yield, not after.
5. **`task.spawn` versus direct calls inside signals.** Calling a handler directly keeps errors and ordering predictable; spawning isolates errors but loses ordering. For a list of independent listeners (a custom signal), spawn each; for a pipeline where step B needs step A, call directly.
6. **Memoization can turn into a leak.** Caching results keyed by arbitrary input (strings typed by players, positions) grows without bound. Bound the cache size or key it by a small, known set.
7. **Varargs have a cost and a limit.** `...` and `table.pack` are convenient for generic wrappers, but every forwarding layer copies arguments. Deep wrapper chains (logging, then retry, then timing) on a hot remote handler add measurable overhead at high call rates. Keep wrappers to the edges (setup, remote entry points) rather than every inner function.
8. **Native codegen prefers simple functions.** Functions marked for native compilation benefit most when they avoid closures, varargs and dynamic upvalues; heavy closure use can reduce what the compiler can optimise (see [[Luau Performance and Native Codegen]]; treat exact gains as something to measure, not assume).

The senior trade-off: closures are the clearest way to express "do this later with this context". The cost is lifetime, not speed. Every closure you hand to an event is a promise to disconnect it, so pair each `Connect` with an owner that cleans up (a maid, trove or janitor object).

## Common mistakes (advanced)

1. **Connecting inside `CharacterAdded` without disconnecting on death.** Symptom: an ability fires two, three, four times after successive respawns. Fix: store the connection on a per-character cleanup object and destroy it on `Humanoid.Died` or `CharacterRemoving`.
2. **Capturing `self` in a callback stored on a global signal.** Symptom: destroyed objects still react to events and error on `nil` fields. Fix: disconnect in `Destroy`, and check an `alive` flag at the top of callbacks that may run late.
3. **Guard set after the yield.** Symptom: double purchases or double rewards from fast clicks. Fix: set `busy[player] = true` before any yielding call; clear it in all exit paths.
4. **Removing a listener by passing a new anonymous function.** Symptom: a custom `Off(fn)` or callback-list removal does nothing, because a new function value is created each time and never equals the stored one. Fix: keep the exact function (or the returned connection) you registered and remove that.
5. **Recursive local functions declared as `local f = function()`.** Symptom: "attempt to call a nil value". Fix: use `local function f()` so the name is in scope inside the body.
6. **Hiding expensive work in a default argument pattern.** Symptom: `x = x or buildBigTable()` runs the builder every call when `x` is `false`. Fix: check `x == nil` explicitly.

## Related decisions

- [[Building a Signal Library]]: how a signal stores and calls closures, and why ordering and spawning matter.
- [[Luau Garbage Collection and the Memory Model]]: what keeps a closure alive.
- [[Hunting Memory Leaks Step by Step]]: finding the connection that holds a dead character.
- [[Debugging Race Conditions and Yield Order]]: guard-before-yield in practice.
- [[Module Design and Dependency Injection]]: passing functions in instead of capturing globals.
- [[Custom Schedulers and Coroutine Patterns]]: when callbacks should become coroutines.
- [[Economy Exploits - Dupes Races and Purchase Abuse]]: the double-click race as an exploit.
- [[Input - UserInputService and ContextActionService]]: binding and unbinding by name.

## Connected notes
<!-- auto-links:start -->
[[Reading Luau Errors and Stack Traces]] · [[Luau Performance Patterns with Benchmarks]] · [[Metatables and OOP - When and When Not]] · [[Advanced Luau Start Here]] · [[Links - Coroutines, task library and async]] · [[Script Performance]]
<!-- auto-links:end -->
