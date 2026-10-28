---
tags: [luau, events, signals, connections, deferred-events, memory]
---
# Events Signals and Connections

<!-- tldr:start -->
> [!tldr] TL;DR
> - Memory grows per round or per spawn: Short-lived object connected to a long-lived signal -> Disconnect on teardown; cleanup bag
> - Handler runs for a destroyed object: Deferred events queued before destroy -> Validate at the top of handlers
> - One-shot logic runs twice: `Connect` + self-disconnect under Deferred -> `Once`
> - The place runs with `SignalBehavior = Deferred` during development.
> - Every connection to a signal that outlives its owner is stored and disconnected.
> - Systems handle existing state, then subscribe.
>
> Cost: TL;DR ~170 tok · whole note ~5.4k tok. Read more: ## 4. Connection lifetime and leaks · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox is event driven. The engine exposes thousands of signals (`RBXScriptSignal`): `Touched`, `Changed`, `PlayerAdded`, `Heartbeat`, `ChildAdded`, `Activated`. Your code connects functions to them and gets back an `RBXScriptConnection`. Getting connections right means three things: run handlers at the right time (immediate vs deferred), avoid races, and disconnect what you connect. Leaked connections are the most common cause of memory growth and "ghost" behaviour in long-running servers.

---

## 1. The API (Docs)

```lua
local conn = part.Touched:Connect(function(otherPart: BasePart)  -- every firing
end)
part.Touched:Once(function(otherPart: BasePart)                  -- first firing only, auto-disconnects first
end)
local hit = part.Touched:Wait()                                  -- yields until the next firing, returns its args
RunService.Heartbeat:ConnectParallel(function(dt) end)            -- runs desynchronized; script must be under an Actor

print(conn.Connected)  --> true
conn:Disconnect()
print(conn.Connected)  --> false
```

Property and attribute signals:

```lua
humanoid:GetPropertyChangedSignal("Health"):Connect(function()   -- no args; read the property
	print(humanoid.Health)
end)
model:GetAttributeChangedSignal("Level"):Connect(function()
	print(model:GetAttribute("Level"))
end)
model.AttributeChanged:Connect(function(name: string) end)       -- any attribute
part.Changed:Connect(function(property: string) end)             -- any property (noisy; avoid)
```

`GetPropertyChangedSignal` and `GetAttributeChangedSignal` return the same signal object for the same name on the same instance (Docs). `Changed` on Value objects (`IntValue` etc.) passes the new value instead of the property name.

**Not every property fires.** Properties updated continuously by the engine (for example `BasePart.Position`/`CFrame` from physics simulation) do not fire `GetPropertyChangedSignal` per physics step (Rule of thumb: physics-driven movement is not reported through changed signals; poll in a RunService event instead).

---

## 2. Immediate vs deferred handlers

`Workspace.SignalBehavior` controls when handlers run (Docs):

| Value | Behaviour |
|---|---|
| `Immediate` | Handlers run synchronously inside the code that fired the event |
| `Deferred` | Handlers are queued and run at the next **resumption point** |
| `AncestryDeferred` | Deferred only for ancestry-change events |
| `Default` | Currently equals `Immediate`; Roblox states it will eventually become `Deferred`. New template places use `Deferred` (Docs, as of October 2026) |

Resumption points (Docs): input processing (once per input), `PreRender`, `PreAnimation`, `PreSimulation`, `PostSimulation`, `Heartbeat`, legacy `wait/spawn/delay` resumption, `task.wait/spawn/delay` resumption, and `BindToClose`. "Unless the engine itself changes it, the place never changes outside of a resumption point." Roblox recommends `Deferred` for performance and correctness.

### What changes under Deferred

```lua
local fired = false
bindable.Event:Connect(function() fired = true end)
bindable:Fire()
print(fired)   --> Immediate: true. Deferred: false (the handler has not run yet).
```

1. **Code after `Fire`/a property change sees the old world.** Do not set a flag in a handler and read it on the next line. Restructure so the handler does the follow-up work, or yield until it ran.
2. **Destroying and ancestry handlers run after the change.** Docs example: by the time a `Destroying` handler runs, the instance is already destroyed. Read what you need *before* destroying, or store it in your own tables.
3. **Several firings can queue before you disconnect.** Calling `Disconnect()` drops all pending invocations (Docs). But disconnecting by other means (destroying the instance) still runs handlers for already-pending events. Code defensively: check that the object is still valid at the top of the handler.
4. **"Only the first time" handlers.** With `Connect` plus a manual `Disconnect` inside the handler, several queued invocations may run. Use `Once` (Docs recommendation).
5. **Re-entrancy is capped.** Events that fire each other recursively stop after a depth limit. Docs: "The current limit for this is 10."

**Migration advice.** Develop with `Deferred` from day one. Code that works under Deferred also works under Immediate; the reverse is often false. When migrating an old place, search for patterns that read state right after firing, handlers that assume the instance still has its parent, and `Connect` + self-disconnect for one-shot logic.

---

## 3. Handler ordering and threads

- Each handler runs in **its own thread**. An error in one handler is reported to Output and does not stop other handlers or the script that connected it.
- Handler **order is not guaranteed**. Do not rely on "my module connected first".
- A handler that yields lets other code run in between. Re-check state after yields (see [[Task Library Coroutines and Yielding]]).
- `:Wait()` misses firings that happen before it starts waiting. This is a common race:

```lua
-- Race: if the character already exists, this waits for the NEXT spawn
local character = player.CharacterAdded:Wait()

-- Correct: check current state first
local character = player.Character or player.CharacterAdded:Wait()
```

The general rule: **handle the current state, then subscribe to changes.** Same for tags (`GetTagged` + added signal, [[CollectionService Patterns]]), children (`GetChildren` + `ChildAdded`), and players (`GetPlayers` + `PlayerAdded`):

```lua
local function onPlayerAdded(player: Player) end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do   -- players who joined before this script connected
	task.spawn(onPlayerAdded, player)
end
```

---

## 4. Connection lifetime and leaks

A connection keeps its handler function alive, and the handler keeps all its upvalues alive ([[Functions Closures and Upvalues]]). When the signal's owner is destroyed, its connections are disconnected (Docs: `Destroy` disconnects all connections on the instance and its descendants). The leak happens when a **short-lived** object connects to a **long-lived** signal:

```lua
-- Leak: every spawned projectile adds a Heartbeat connection that is never disconnected
local function spawnProjectile(cf: CFrame)
	local p = template:Clone()
	p.Parent = workspace
	RunService.Heartbeat:Connect(function(dt)
		p.CFrame += p.CFrame.LookVector * 100 * dt   -- keeps running on the destroyed part
	end)
	task.delay(3, function() p:Destroy() end)          -- destroying p does NOT disconnect Heartbeat
end
```

Fix: store the connection and disconnect it in the same place you destroy the object.

```lua
local function spawnProjectile(cf: CFrame)
	local p = template:Clone()
	p.CFrame = cf
	p.Parent = workspace
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		p.CFrame += p.CFrame.LookVector * 100 * dt
	end)
	task.delay(3, function()
		conn:Disconnect()
		p:Destroy()
	end)
end
```

Better still, one Heartbeat connection that updates a list of projectiles ([[Luau Performance and Native Codegen]]).

Other long-lived signals that leak: `Players.PlayerAdded/PlayerRemoving`, `UserInputService` events, `workspace.ChildAdded`, global `BindableEvent`s, `CollectionService` signals, and anything on `game` or a service.

**Setting `Parent = nil` does not disconnect.** Only `Destroy` does. Objects removed with `Parent = nil` keep their connections and can be re-parented, which is occasionally what you want and usually a leak.

### A cleanup bag (Maid / Trove pattern)

Community libraries (Maid, Janitor, Trove) package this. The idea is small enough to own:

```lua
--!strict
type Task = RBXScriptConnection | Instance | thread | (() -> ()) | { Destroy: (any) -> () }

local Bag = {}
Bag.__index = Bag

export type Bag = typeof(setmetatable({} :: { _tasks: { Task } }, Bag))

function Bag.new(): Bag
	return setmetatable({ _tasks = {} }, Bag)
end

function Bag.add<T>(self: Bag, t: T): T
	table.insert(self._tasks, t :: any)
	return t
end

function Bag.clean(self: Bag)
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do                      -- reverse order: undo in the opposite order of setup
		local t: any = tasks[i]
		local kind = typeof(t)
		if kind == "RBXScriptConnection" then
			t:Disconnect()
		elseif kind == "Instance" then
			t:Destroy()
		elseif kind == "thread" then
			if coroutine.status(t) ~= "running" then task.cancel(t) end
		elseif kind == "function" then
			t()
		elseif kind == "table" and t.Destroy then
			t:Destroy()
		end
	end
end

return Bag
```

Usage: every per-character, per-round or per-UI-screen system owns a bag, adds everything it creates, and calls `clean()` on teardown.

```lua
local bag = Bag.new()
bag:add(humanoid.Died:Connect(onDied))
bag:add(RunService.Heartbeat:Connect(update))
bag:add(highlightInstance)
bag:add(function() activeEffects[player] = nil end)
-- later
bag:clean()
```

---

## 5. Custom signals

### BindableEvent

`BindableEvent` gives you an engine signal for your own events, on one side of the client/server boundary. `Fire` does not yield (Docs). Limitations (Docs: bindable argument limitations): tables are **copied**, metatables are lost, non-string keys are converted to strings, mixed tables can lose elements, `nil` holes truncate arrays. Each handler gets a new copy, so handlers cannot share a mutable payload. For in-process events that pass rich Luau objects, a pure-Luau signal is better.

### A pure-Luau signal

Passes arguments by reference, keeps identities, and costs less than a BindableEvent. Handlers run immediately (synchronously) unless you defer them.

```lua
--!strict
export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { [Connection]: (T...) -> () } = {}
	local self = {} :: any

	function self:Connect(fn: (T...) -> ()): Connection
		local conn = { Connected = true } :: any
		function conn:Disconnect()
			conn.Connected = false
			handlers[conn] = nil
		end
		handlers[conn] = fn
		return conn
	end

	function self:Once(fn: (T...) -> ()): Connection
		local conn: Connection
		conn = self:Connect(function(...: T...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end

	function self:Fire(...: T...)
		-- snapshot so handlers can connect/disconnect while we iterate
		local snapshot = table.clone(handlers)
		for conn, fn in snapshot do
			if conn.Connected then
				task.spawn(fn, ...)   -- own thread per handler: errors and yields are isolated
			end
		end
	end

	function self:Wait(): T...
		local thread = coroutine.running()
		self:Once(function(...: T...)
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end

	function self:DisconnectAll()
		for conn in handlers do
			conn.Connected = false
		end
		table.clear(handlers)
	end

	return self
end

return Signal
```

Design notes:
- `task.spawn` per handler isolates errors and yields but allocates a thread per handler per fire. For very hot signals, call handlers directly and document that they must not yield, or reuse a free runner thread (the approach used by popular community signal libraries).
- Handler order here is unspecified (dictionary iteration), the same promise the engine gives.
- To mimic Deferred behaviour, use `task.defer(fn, ...)` instead of `task.spawn`.

---

## 6. Choosing the right channel

| Need | Use |
|---|---|
| React to engine changes | The engine signal (`Changed`, `ChildAdded`, `GetAttributeChangedSignal`) |
| In-process events between your modules | Pure-Luau signal, or a direct function call |
| Events across scripts that cannot share modules (rare) | BindableEvent |
| Server to client / client to server | RemoteEvent, UnreliableRemoteEvent ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]) |
| Between Actors | `Actor:SendMessage` ([[Parallel Luau and Actors]]) |
| State that UIs observe | Attributes on a known instance, or a state container module with a changed signal |

A direct function call is often the right answer. Events decouple, but they also hide control flow; a chain of five signals is hard to debug.

---

## 7. Per-player and per-character lifecycles

Most leaks come from forgetting that players leave and characters respawn. A reusable structure:

```lua
--!strict
local Players = game:GetService("Players")
local Bag = require(script.Parent.Bag)

local playerBags: { [Player]: any } = {}

local function onCharacterAdded(player: Player, character: Model)
	local bag = Bag.new()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	bag:add(humanoid.Died:Connect(function()
		-- death handling
	end))
	bag:add(character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then bag:clean() end           -- character removed
	end))
	playerBags[player]:add(function() bag:clean() end) -- also cleaned if the player leaves first
end

local function onPlayerAdded(player: Player)
	local bag = Bag.new()
	playerBags[player] = bag
	bag:add(player.CharacterAdded:Connect(function(char) onCharacterAdded(player, char) end))
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	local bag = playerBags[player]
	playerBags[player] = nil
	if bag then bag:clean() end
end)
for _, p in Players:GetPlayers() do task.spawn(onPlayerAdded, p) end
```

Every per-player table in your codebase (`cooldowns[player]`, `damageBy[player]`) needs the same `PlayerRemoving` cleanup; a quick audit is to search for `[player]` and check each table has a removal path. Note that the `Player` object itself is destroyed some time after leaving, so its own connections die eventually, but your tables keyed by it keep it alive until you remove the entry ([[Memory Budgets and Leaks]]).

### Debugging connection leaks

- Watch the Developer Console memory view over 20 minutes of play with rounds or respawns; a steady climb in script memory is a leak signal.
- Count active connections in your own wrappers (increment on connect, decrement on disconnect) and print per system in debug builds.
- Respawn 50 times in a test and check that per-respawn systems do not multiply (duplicate prints or sounds are the classic symptom).

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Memory grows per round or per spawn | Short-lived object connected to a long-lived signal | Disconnect on teardown; cleanup bag |
| Handler runs for a destroyed object | Deferred events queued before destroy | Validate at the top of handlers |
| One-shot logic runs twice | `Connect` + self-disconnect under Deferred | `Once` |
| Flag read right after `Fire` is stale | Deferred handlers | Do follow-up inside the handler |
| Waits forever for a character | `CharacterAdded:Wait()` after spawn | `player.Character or ...:Wait()` |
| Table metatables gone in handler | BindableEvent copies arguments | Pure-Luau signal |
| Removed UI still reacts | `Parent = nil` instead of `Destroy` | `Destroy`, or disconnect explicitly |

## Checklist

- [ ] The place runs with `SignalBehavior = Deferred` during development.
- [ ] Every connection to a signal that outlives its owner is stored and disconnected.
- [ ] Systems handle existing state, then subscribe.
- [ ] One-shot handlers use `Once`.
- [ ] No `Changed` (all properties) where a specific property signal works.
- [ ] Per-frame connections are few and shared, not one per object.

## See also

[[Task Library Coroutines and Yielding]] · [[Functions Closures and Upvalues]] · [[CollectionService Patterns]] · [[Instances Attributes and Tags]] · [[Memory Budgets and Leaks]] · [[Frame Order and RunService Timing]] · [[Markers and Events]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]]

## Nuances and edge cases

1. **Deferred events change "now" into "soon".** With deferred signal behaviour, handlers run at the next resumption point in the same frame rather than inside the call that fired them (Roblox docs, as of October 2026). Code that sets a property and then reads a value a handler was supposed to update sees the old value. The fix is not to fight the model: move follow-up work into the handler, or return values directly instead of communicating through events.
2. **Re-entrant events are limited.** A handler that fires the same event it is listening to can loop. Under deferred behaviour the engine caps how deep that chain may go and drops further events with a warning (the exact depth is an engine detail; treat it as unverified and avoid designs that rely on it). Use a flag or a queue when one event legitimately triggers another of the same kind.
3. **Property-changed events fire per change, not per frame.** Listening to `GetPropertyChangedSignal("Position")` on a moving part does not fire for physics-driven movement in the way people expect; physics updates do not fire property signals for every step (rule of thumb, widely observed; not reconfirmed on the docs page this round). For positions that physics changes, poll in `Heartbeat` instead of connecting a changed signal.
4. **Scale multiplies connection counts quietly.** One connection per player is nothing. One connection per enemy per player (for example, each client connecting to every enemy's `AttributeChanged`) at 50 players and 300 enemies is 15,000 connections across clients, each a closure in memory. Prefer one listener per system that dispatches by id, and one network message carrying many changes.
5. **Order of handlers is not a contract.** Handlers connected to the same signal run in an order you should not depend on, and under deferred mode errors in one do not stop the others. If step B depends on step A, call them in sequence from one handler.
6. **`Wait()` on events can wait forever.** `event:Wait()` on something that already happened (a character already added, a value already set) never returns. Always check current state first, then wait for the change, and add a timeout for anything that might never fire.
7. **BindableEvents copy arguments.** Tables passed through a `BindableEvent` arrive as copies without metatables, functions are dropped, and mixed keys can be lost. For in-process communication between modules, a pure-Luau signal is faster and keeps references (see [[Building a Signal Library]]).
8. **Client and server lifecycles differ.** On the client, `PlayerRemoving` for the local player may not run to completion before the client closes. Never rely on client events to save or report anything at shutdown; the server owns that ([[Server Lifecycle and Shutdown]]).

The senior trade-off: events decouple code but hide the flow. A system with 30 signals is hard to debug because no stack trace shows who fired what. Use events at boundaries (engine to game, system to system) and direct function calls inside a system.

## Common mistakes (advanced)

1. **Connecting to `Changed` on a whole instance.** Symptom: handler runs for every property, including ones you do not care about, costing time. Fix: `GetPropertyChangedSignal` for the specific property, or `AttributeChanged` for one attribute.
2. **Using events for request and response.** Symptom: spaghetti of "fire request, listen for reply, match ids". Fix: a function call, or a `RemoteFunction` only where the server returns data to a client.
3. **Firing a remote from a high-frequency event.** Symptom: network spikes from a client sending on every `InputChanged` or `RenderStepped`. Fix: throttle and send state at a fixed rate.
4. **Forgetting the initial value.** Symptom: UI shows the wrong value until the first change. Fix: read and apply the current value, then connect.
5. **Disconnecting inside a handler loop over a shared list.** Symptom: some handlers skipped on the same fire. Fix: signal libraries should iterate a snapshot; if you wrote your own, copy before iterating.
6. **Event-driven code that never handles destroy.** Symptom: errors such as "attempt to index nil" after objects are removed. Fix: check validity at the top of handlers that may run late under deferred mode.

## Related decisions

- [[Building a Signal Library]]: implementing a pure-Luau signal with correct ordering and cleanup.
- [[Debugging Race Conditions and Yield Order]]: deferred-event bugs are race conditions in disguise.
- [[Hunting Memory Leaks Step by Step]]: connection counts as the first leak suspect.
- [[Remote Abuse Patterns and Rate Limiting in Practice]]: throttling events that become network sends.
- [[Server Lifecycle and Shutdown]]: why shutdown work belongs to the server.
- [[Module Design and Dependency Injection]]: passing signals into modules for testability.
- [[Markers and Events]]: animation markers as a special case of events.
- [[UI and GUI Animation]]: initial-value-then-connect in UI bindings.

## Connected notes
<!-- auto-links:start -->
[[Links - Events, signals and connections]] · [[Event Bus]] · [[Script Performance]] · [[Links - Memory leaks and cleanup]] · [[Custom Schedulers and Coroutine Patterns]] · [[Advanced Luau Start Here]]
<!-- auto-links:end -->
