---
tags: [luau, advanced-luau, coroutines, scheduler, task, timers, time-slicing, concurrency, type/guide, area/scripting, level/advanced, area/economy]
---
# Custom Schedulers and Coroutine Patterns

<!-- tldr:start -->
> [!tldr] TL;DR
> - All timers stall for seconds: A callback yielded inside the inline `pcall` -> Callbacks never yield; spawn their slow work
> - Job runs twice through the same code, or skips: An engine-yielded thread was resumed manually -> Yield token check; never resume engine-yielded threads
> - Server freezes under load: Fixed-step loop without a step cap -> Clamp steps per frame, drop backlog
> - There is a written reason (count, pause, ordering, tests) for each custom scheduler.
> - One engine connection drives each scheduler.
> - Callbacks run by your scheduler must not yield, and the module says so.
>
> Cost: TL;DR ~190 tok · whole note ~5.7k tok. Read more: ## 2. A timer queue on a binary heap · ## 4. Cooperative jobs: coroutines as resumable work · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Task Library Coroutines and Yielding]] explains the engine's scheduler: `task.spawn`, `task.defer`, `task.delay`, `task.wait`, what yields, and how to resume threads safely. [[Luau Performance Patterns with Benchmarks]] shows a basic time-sliced loop with a millisecond budget. This note is about the cases where the engine's scheduler is not enough and you build your own on top of it: thousands of timers, pausable and time-scaled game clocks, fixed-step simulation, cooperative jobs that spread work over frames, structured cancellation, and deterministic tests. It also covers the failure modes that only appear once you mix your own resumes with the engine's.

The rule underneath all of it: **the engine owns time; you own order.** A custom scheduler is a data structure that decides which of your callbacks runs next, driven by one engine event per frame.

---

## 1. When the engine scheduler is the wrong tool

`task.delay(seconds, fn)` is right for most one-off timers. It stops being right when:

| Situation | Problem with `task.delay` / `task.wait` | What a custom scheduler gives |
|---|---|---|
| 2,000 enemies each with a cooldown timer | One thread per timer, each holding a stack and captured upvalues | One heap entry per timer, no threads |
| The game pauses (menus in single-player, cutscenes, hit-stop) | Engine timers keep running in real time | A game clock you can stop and scale |
| Ability cooldowns must match server time exactly across a slow frame | Resumption happens at the next resumption point, order unspecified | Explicit ordering by due time, then by insertion |
| You need "cancel all timers owned by this enemy" | Must track every thread handle yourself | Owner-scoped cancellation built in |
| Tests must run 10 minutes of game logic in a second | Real waits | A fake clock you advance by hand |

Rule of thumb: below a few hundred concurrent timers with no pause requirement, `task.delay` plus `task.cancel` is simpler and correct. Build a scheduler when one of the rows above applies, not before.

---

## 2. A timer queue on a binary heap

A binary min-heap keyed by due time gives `O(log n)` insert and pop, and checking whether anything is due is `O(1)`. Cancellation uses **lazy deletion**: a cancelled entry stays in the heap with a flag and is discarded when it reaches the top. That keeps cancel at `O(1)` without searching the heap.

```lua
--!strict
-- TimerQueue: one Heartbeat connection, any number of timers, a pausable scaled clock.

export type Handle = { cancelled: boolean }

type Entry = {
	due: number,
	seq: number,               -- tie-breaker: equal due times run in insertion order
	fn: (...any) -> (),
	args: { any },
	handle: Handle,
}

export type TimerQueue = {
	now: (self: TimerQueue) -> number,
	after: (self: TimerQueue, delay: number, fn: (...any) -> (), ...any) -> Handle,
	cancel: (self: TimerQueue, handle: Handle) -> (),
	setScale: (self: TimerQueue, scale: number) -> (),
	advance: (self: TimerQueue, realDt: number) -> (),
	pending: (self: TimerQueue) -> number,
}

local TimerQueue = {}
TimerQueue.__index = TimerQueue

local function less(a: Entry, b: Entry): boolean
	if a.due ~= b.due then
		return a.due < b.due
	end
	return a.seq < b.seq
end

function TimerQueue.new(): TimerQueue
	local self = setmetatable({
		heap = {} :: { Entry },
		clock = 0,          -- game time in seconds, advanced by advance()
		scale = 1,
		seq = 0,
		live = 0,           -- entries not cancelled
	}, TimerQueue)
	return self :: any
end

function TimerQueue.now(self: any): number
	return self.clock
end

local function siftUp(heap: { Entry }, i: number)
	while i > 1 do
		local parent = i // 2
		if less(heap[i], heap[parent]) then
			heap[i], heap[parent] = heap[parent], heap[i]
			i = parent
		else
			break
		end
	end
end

local function siftDown(heap: { Entry }, i: number)
	local n = #heap
	while true do
		local l, r = i * 2, i * 2 + 1
		local smallest = i
		if l <= n and less(heap[l], heap[smallest]) then smallest = l end
		if r <= n and less(heap[r], heap[smallest]) then smallest = r end
		if smallest == i then return end
		heap[i], heap[smallest] = heap[smallest], heap[i]
		i = smallest
	end
end

local function pop(heap: { Entry }): Entry
	local top = heap[1]
	local last = table.remove(heap) :: Entry
	if #heap > 0 then
		heap[1] = last
		siftDown(heap, 1)
	end
	return top
end

function TimerQueue.after(self: any, delay: number, fn: (...any) -> (), ...: any): Handle
	self.seq += 1
	local handle: Handle = { cancelled = false }
	local entry: Entry = {
		due = self.clock + math.max(delay, 0),
		seq = self.seq,
		fn = fn,
		args = table.pack(...),
		handle = handle,
	}
	table.insert(self.heap, entry)
	siftUp(self.heap, #self.heap)
	self.live += 1
	return handle
end

function TimerQueue.cancel(self: any, handle: Handle)
	if not handle.cancelled then
		handle.cancelled = true
		self.live -= 1
	end
end

function TimerQueue.setScale(self: any, scale: number)
	self.scale = math.max(scale, 0)   -- 0 pauses the clock
end

function TimerQueue.pending(self: any): number
	return self.live
end

-- Called once per frame with the real frame delta.
function TimerQueue.advance(self: any, realDt: number)
	self.clock += realDt * self.scale
	local heap = self.heap
	-- Only entries that existed before this pass may run in it. Timers scheduled by a
	-- callback during the pass (even with delay 0) wait for the next frame.
	local limit = self.clock
	local seqLimit = self.seq
	local ran = 0
	while heap[1] and heap[1].due <= limit and heap[1].seq <= seqLimit do
		local entry = pop(heap)
		if not entry.handle.cancelled then
			entry.handle.cancelled = true   -- fired; cancel() after this is a no-op
			self.live -= 1
			ran += 1
			-- Callbacks must not yield. Run directly for speed; errors propagate to advance().
			local ok, err = pcall(entry.fn, table.unpack(entry.args, 1, entry.args.n))
			if not ok then
				task.spawn(error, err, 0)   -- report without killing the loop
			end
		end
		if ran > 5000 then
			break   -- safety valve: a callback rescheduling itself at delay 0 forever
		end
	end
	-- Lazy deletion can let cancelled entries pile up; compact when they dominate.
	if #heap > 64 and self.live < #heap // 4 then
		local kept = {}
		for _, e in heap do
			if not e.handle.cancelled then
				table.insert(kept, e)
			end
		end
		table.sort(kept, less)   -- a sorted array is a valid min-heap
		self.heap = kept
	end
end

return TimerQueue
```

Wiring it to the engine:

```lua
local RunService = game:GetService("RunService")
local TimerQueue = require(script.Parent.TimerQueue)

local gameTimers = TimerQueue.new()
RunService.Heartbeat:Connect(function(dt)
	gameTimers:advance(dt)
end)

-- Pausing all gameplay timers for a cutscene:
gameTimers:setScale(0)
-- Slow motion during a finisher:
gameTimers:setScale(0.25)
```

Design decisions worth defending:

- **Callbacks run inline under `pcall`, not in new threads.** That is what makes the queue cheap. The price is that callbacks must not yield; a yield inside `pcall` from a Heartbeat handler suspends the whole `advance` call until the yield resumes, and every timer behind it waits. State the rule in the module header and keep callbacks short. If a callback needs to yield, it should `task.spawn` its own work.
- **`seq` makes ordering deterministic.** Two timers due at the same game time run in the order they were scheduled. Engine timers do not promise that.
- **The `seqLimit` check and the safety valve.** A callback that reschedules itself with delay 0 would otherwise loop forever inside one frame. Because equal due times are ordered by sequence number, every entry that existed before the pass sorts ahead of anything a callback adds for "now", so stopping at the first entry with a newer sequence number defers new work to the next frame. The 5,000 cap is a second line of defence against a pass that is simply too large.
- **`task.spawn(error, err, 0)`** reports the error in its own thread so the Output shows it, while the loop continues. The traceback is lost; if you need it, use `xpcall` with `debug.traceback` ([[Error Handling - pcall xpcall and Promise Patterns]]).

### Owner-scoped cancellation

Most "cancel" calls in games are really "this enemy died, cancel everything it scheduled." Store handles per owner and cancel them together:

```lua
local ownerHandles: { [any]: { TimerQueue.Handle } } = {}

local function afterFor(owner: any, delay: number, fn: () -> ()): TimerQueue.Handle
	local h = gameTimers:after(delay, fn)
	local list = ownerHandles[owner]
	if not list then
		list = {}
		ownerHandles[owner] = list
	end
	table.insert(list, h)
	return h
end

local function cancelOwner(owner: any)
	local list = ownerHandles[owner]
	if list then
		for _, h in list do
			gameTimers:cancel(h)
		end
		ownerHandles[owner] = nil
	end
end
```

Forgetting `cancelOwner` on death is a leak with a delay: the closures (and whatever they capture) live until the timers fire. For long cooldowns that can be minutes ([[Luau Garbage Collection and the Memory Model]]).

---

## 3. Fixed timestep simulation

Heartbeat's `dt` varies with frame rate. Simulations that integrate velocity, apply damage over time, or run projectile physics in Luau give different results at 30 and 60 frames per second if they step by `dt` directly. A [[fixed timestep]] accumulates real time and steps in constant increments.

```lua
--!strict
local RunService = game:GetService("RunService")

local STEP = 1 / 30          -- 30 Hz simulation (rule of thumb for server-side Luau sims)
local MAX_STEPS = 4          -- clamp: never more than 4 steps in one frame

local accumulator = 0

local function simulate(step: number)
	-- deterministic game logic here, always with the same step
end

RunService.Heartbeat:Connect(function(dt: number)
	accumulator += dt
	local steps = 0
	while accumulator >= STEP and steps < MAX_STEPS do
		simulate(STEP)
		accumulator -= STEP
		steps += 1
	end
	if steps == MAX_STEPS then
		accumulator = 0       -- drop the backlog instead of spiralling
	end
	-- alpha = accumulator / STEP can be used to interpolate visuals between steps
end)
```

The clamp prevents the **spiral of death**: a slow frame needs more steps, more steps make the next frame slower, and the server never catches up. Dropping time means the simulation runs slow under load, which is almost always better than a server that stops responding. The interpolation factor matters on the client, where you render between two simulated states to avoid stutter; on the server nobody sees the frames.

Do not use a fixed step for things the engine already simulates (parts, humanoids, constraints). This is for your own Luau simulation: projectiles you integrate yourself, status effect ticks, AI decisions at a fixed rate ([[Frame Order and RunService Timing]]).

---

## 4. Cooperative jobs: coroutines as resumable work

Some work is too large for one frame: generating a map, rebuilding a spatial index, scanning 50,000 instances on startup, migrating every profile in a server. The pattern is a job written as straight-line code that calls a `checkpoint()` function now and then. The scheduler resumes jobs until the frame budget is spent, and `checkpoint()` yields only if the budget is gone.

```lua
--!strict
local RunService = game:GetService("RunService")

local BUDGET = 0.002   -- 2 ms per frame for background jobs (rule of thumb; tune with the MicroProfiler)

local YIELD_TOKEN = newproxy(false)   -- unique value jobs yield; anything else is a bug

type Job = { thread: thread, name: string }

local jobs: { Job } = {}
local frameDeadline = 0

local Jobs = {}

-- Called by job code. Cheap when there is budget left.
function Jobs.checkpoint()
	if os.clock() >= frameDeadline then
		coroutine.yield(YIELD_TOKEN)
	end
end

function Jobs.start(name: string, fn: () -> ())
	table.insert(jobs, { thread = coroutine.create(fn), name = name })
end

RunService.Heartbeat:Connect(function()
	frameDeadline = os.clock() + BUDGET
	local i = 1
	while i <= #jobs and os.clock() < frameDeadline do
		local job = jobs[i]
		local ok, result = coroutine.resume(job.thread)
		if not ok then
			warn(`job {job.name} failed: {result}`)
			table.remove(jobs, i)
		elseif coroutine.status(job.thread) == "dead" then
			table.remove(jobs, i)
		elseif result ~= YIELD_TOKEN then
			-- The job yielded through the engine (task.wait, WaitForChild, a web call).
			-- The engine will resume it later; we must never resume it ourselves again.
			warn(`job {job.name} yielded through the engine; it is no longer scheduled`)
			table.remove(jobs, i)
		else
			i += 1
		end
	end
end)

return Jobs
```

A job:

```lua
Jobs.start("index trees", function()
	local index = {}
	for _, tree in workspace.Trees:GetChildren() do
		local pos = tree:GetPivot().Position
		local cell = `{pos.X // 32},{pos.Z // 32}`   -- string key: one bucket per 32-stud cell
		index[cell] = index[cell] or {}
		table.insert(index[cell], tree)
		Jobs.checkpoint()
	end
	TreeIndex.publish(index)
end)
```

The important line is the `YIELD_TOKEN` check. `coroutine.resume` returns `true` both when the job called `coroutine.yield(YIELD_TOKEN)` and when something inside the job yielded through the engine. The two cases look identical except for the returned values. If you resumed an engine-yielded thread again, you would resume it early, out of a `task.wait`, and the engine would resume it a second time later: a double resume that corrupts the job's control flow and is very hard to debug ([[Debugging Race Conditions and Yield Order]]). The token makes the case detectable; the job is then simply left to the engine, and finishes outside the budget.

`newproxy(false)` creates a unique userdata (Roblox docs list `newproxy` as a global). Any unique table also works; userdata just cannot be confused with a value a job might yield by accident.

Trade-offs of coroutine jobs versus explicit state machines:

| | Coroutine job | Explicit state machine (index and phase stored in a table) |
|---|---|---|
| Readability | Straight-line code | Manual bookkeeping |
| Memory | A thread with its stack per job | A small table |
| Persistence across server restarts | Impossible (threads cannot be saved) | Possible |
| Engine yields inside | Must be forbidden or detected | Not applicable |
| Many tiny jobs (thousands) | Thread per job adds up | Cheap |

Use coroutine jobs for a few big jobs. Use explicit state for many small ones, or for work that must survive a server shutdown ([[Server Lifecycle and Shutdown]]).

**Fairness.** The loop above runs the first job until its first checkpoint, then the next, and so on, while budget lasts. A job that checkpoints rarely starves the others. Rule of thumb: checkpoint at least every 0.1 ms of work, which for most loops means every iteration (the `os.clock` call is cheap relative to most per-item work).

---

## 5. Structured concurrency: race, all, and cancellation

Most yield bugs in Roblox code come from threads that outlive the thing that started them. A character dies while its ability coroutine is in a `task.wait(2)`, then the coroutine wakes up and touches a destroyed character. Structured concurrency means every thread you start has an owner, and when the owner ends, its threads end too.

A minimal scope object:

```lua
--!strict
export type Scope = {
	spawn: (self: Scope, fn: (...any) -> (), ...any) -> thread,
	delay: (self: Scope, seconds: number, fn: (...any) -> (), ...any) -> thread,
	close: (self: Scope) -> (),
	closed: boolean,
}

local Scope = {}
Scope.__index = Scope

function Scope.new(): Scope
	return setmetatable({ threads = {}, closed = false }, Scope) :: any
end

function Scope.spawn(self: any, fn: (...any) -> (), ...: any): thread
	assert(not self.closed, "scope closed")
	local t = task.spawn(fn, ...)
	if coroutine.status(t) ~= "dead" then
		self.threads[t] = true
	end
	return t
end

function Scope.delay(self: any, seconds: number, fn: (...any) -> (), ...: any): thread
	assert(not self.closed, "scope closed")
	local t = task.delay(seconds, fn, ...)
	self.threads[t] = true
	return t
end

function Scope.close(self: any)
	if self.closed then return end
	self.closed = true
	local current = coroutine.running()
	for t in self.threads do
		if t ~= current and coroutine.status(t) ~= "dead" then
			task.cancel(t)
		end
	end
	table.clear(self.threads)
end

return Scope
```

Per character: create a scope on spawn, close it on `Humanoid.Died` and on `CharacterRemoving`. Every ability spawns through the scope. A closed scope cancels anything still waiting, so nothing wakes up later holding a dead character.

The `t ~= current` check matters: if `close` is called from inside one of the scope's own threads (an ability that kills its own user), cancelling the running thread is not something to rely on; let it finish normally.

Note that `self.threads` only grows within a scope's life; dead threads are not removed until close. For long-lived scopes (a whole session) prune dead entries periodically, or use per-ability scopes nested under the character scope.

**Race** (first of several things) is the `waitWithTimeout` pattern in [[Task Library Coroutines and Yielding]], generalised: each branch resumes the waiter once and cancels the others. **All** (wait for several things) counts completions and resumes the waiter when the count reaches the total; it must also handle a branch that errors, or the waiter hangs forever. For anything beyond these two, a Promise library gives you composition with error propagation built in ([[Error Handling - pcall xpcall and Promise Patterns]]); the trade-off is allocation per promise and a second mental model for the team.

---

## 6. Re-entrancy and deferred limits

Schedulers that fire events can recurse: a timer callback fires a signal whose handler schedules a timer due now, whose callback fires the signal again. Three engine facts limit this.

- With **Deferred** signal behaviour, handlers are queued and run at the next resumption point (input processing, `PreRender`, `PreSimulation`, `PostSimulation`, `Heartbeat`, task library resumes, `BindToClose`) (Roblox docs, as of October 2026).
- Deferred events have a **re-entrancy limit of 10**: events that keep firing each other stop at that depth (Roblox docs).
- `task.defer` called repeatedly from deferred threads can hit a re-entrancy error as well; the exact limit is not in the current reference, so treat any "re-entrancy" error as a design bug, not something to tune around.

Your own scheduler should impose the same discipline: the `advance` loop above only runs entries that existed when the pass started (the `seqLimit` check), so a timer scheduled during the pass for "now" waits one frame, and the hard cap stops runaway loops.

---

## 7. A fake clock for tests

Everything above gets testable once time is injected. The timer queue already takes `realDt` from the caller; tests call `advance` directly:

```lua
local q = TimerQueue.new()
local fired = {}
q:after(5, function() table.insert(fired, "cooldown") end)
q:advance(4.9)
assert(#fired == 0)
q:advance(0.2)
assert(fired[1] == "cooldown")

q:setScale(0)                 -- paused
q:after(1, function() table.insert(fired, "paused") end)
q:advance(10)
assert(#fired == 1)           -- nothing ran while paused
```

Ten minutes of cooldown logic runs in microseconds, deterministically, without Studio's Play mode. Any module that reads `os.clock()` or `workspace:GetServerTimeNow()` directly cannot be tested this way; take the clock as a dependency instead ([[Module Design and Dependency Injection]], [[Automated Testing with TestEZ and Jest-Lua]]).

---

## When not to do this

- **A handful of timers.** `task.delay` and `task.cancel` are correct and need no code.
- **Anything the engine simulates.** Do not drive part physics or animation from your own fixed step.
- **Work that needs real yields.** Web calls and DataStore requests belong in ordinary `task.spawn` threads with proper retries, not inside a budgeted job.
- **Replacing the engine scheduler wholesale.** Frameworks that route every thread through a custom scheduler add a layer every new developer must learn. Keep the custom part narrow.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| All timers stall for seconds | A callback yielded inside the inline `pcall` | Callbacks never yield; spawn their slow work |
| Job runs twice through the same code, or skips | An engine-yielded thread was resumed manually | Yield token check; never resume engine-yielded threads |
| Server freezes under load | Fixed-step loop without a step cap | Clamp steps per frame, drop backlog |
| Errors after a character died | Threads outlived their owner | Scopes per character, closed on death and removal |
| Memory grows with long cooldowns | Cancelled or orphaned timers holding closures | Owner-scoped cancel; heap compaction |
| Timers fire in a different order each run | Equal due times, no tie-breaker | Sequence number in the heap key |
| Tests take as long as the game | Modules read real clocks | Inject the clock |

## Checklist

- [ ] There is a written reason (count, pause, ordering, tests) for each custom scheduler.
- [ ] One engine connection drives each scheduler.
- [ ] Callbacks run by your scheduler must not yield, and the module says so.
- [ ] Jobs yield a unique token; anything else is detected and dropped.
- [ ] Fixed-step loops clamp steps per frame.
- [ ] Every thread has an owner scope that cancels it.
- [ ] Ordering ties are broken deterministically.
- [ ] Clocks are injected so tests can advance time by hand.

## See also

[[Advanced Luau Start Here]], [[Task Library Coroutines and Yielding]], [[Frame Order and RunService Timing]], [[Debugging Race Conditions and Yield Order]], [[Luau Performance Patterns with Benchmarks]], [[Events Signals and Connections]], [[Building a Signal Library]], [[Status Effects Buffs and Stacking Rules]], [[Hit Reactions Stagger and Hit-Stop]], [[Parallel Luau and Actors]]

## Connected notes
<!-- auto-links:start -->
[[Links - Coroutines, task library and async]] · Functions Closures and Upvalues · Reading Luau Errors and Stack Traces · Error Handling and Retries · Debugger Breakpoints and Logging · Frame Budget
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Functions Closures and Upvalues]] · [[Reading Luau Errors and Stack Traces]] · [[Script Performance]] · [[Error Handling and Retries]] · [[Advanced Types - Generics and Type Functions]] · [[Serialization Formats for Saves and Networking]]
<!-- related:end -->
