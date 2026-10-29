---
tags: [luau, metatables, oop, architecture, composition, typing, type/guide, area/scripting, level/advanced, api/Model]
---
# Metatables and OOP - When and When Not

<!-- tldr:start -->
> [!tldr] TL;DR
> - Methods missing after a save/load or remote: Metatable dropped -> Plain data at boundaries; rebuild objects
> - Subclass explosion: Inheritance for variation -> Composition + data rows
> - Change events miss nested writes: `__newindex` proxy only sees top level -> Explicit mutation functions
> - Saved and networked state is plain data, not class instances.
> - Singletons are modules, not classes.
> - Classes are used for many-instance or resource-owning objects only.
>
> Cost: TL;DR ~160 tok · whole note ~5.0k tok. Read more: ## 1. Four ways to model a thing · ## 4. Metamethod tricks: clever, and what they cost · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Tables Metatables and OOP]] teaches the mechanics: metamethods, the class idiom, inheritance, weak tables, and what happens to tables at Roblox boundaries. This note is about judgement. It compares the four ways of modelling "things" in Luau (metatable classes, closure objects, plain data with module functions, and structure-of-arrays or [[Entity Component System|ECS]]), shows where each one wins and where it hurts, covers the metamethod tricks that look clever and cause bugs (proxies, `__newindex` tracking, operator overloading), and finishes with lifecycle, typing and serialisation, which is where most OOP pain in Roblox games really comes from.

Performance statements come from the Luau performance page (luau.org, as of October 2026). Everything else is rule of thumb from production Roblox code, including one production game referred to as the reference project.

---

## 1. Four ways to model a thing

| Style | Shape | Strengths | Weaknesses |
|---|---|---|---|
| **Metatable class** | `setmetatable({fields}, Class)`, methods on `Class` | Fast method calls, one copy of each method, familiar | Lifecycle bugs, inheritance temptation, lost across boundaries |
| **Closure object** | A function returns a table of closures over local state | True privacy, no `self`, simple | One closure per method per object (memory), no shared method table, harder to type |
| **Plain data + module functions** | `Inventory.add(inv, item)` where `inv` is a plain table | Serialisable as is, trivially testable, hot-reload friendly | No method syntax, no encapsulation |
| **Structure of arrays / ECS** | `positions[i]`, `velocities[i]` or component stores | Fastest for thousands of homogeneous entities, cache-friendly | More ceremony; awkward for few, varied objects |

None is "the right way". A healthy Roblox codebase usually uses all four: classes for a handful of service-like objects and reusable widgets, plain data for everything that is saved or sent, closures for small private helpers, and arrays for the hot entity loop.

### Closure objects in detail

```lua
--!strict
local function newCounter(start: number)
	local value = start -- private: unreachable from outside
	local self = {}
	function self.increment(by: number?)
		value += by or 1
	end
	function self.get(): number
		return value
	end
	return self
end

local c = newCounter(10)
c.increment()
print(c.get()) --> 11
```

Cost: every object allocates its own closures (here two) plus a mutable upvalue box for `value`, because `value` is reassigned after capture (luau.org: mutable upvalues need an extra object). For 20 UI controllers that is irrelevant. For 5,000 projectiles it is a lot of avoidable memory and GC work. Use closure objects for few, long-lived things where privacy helps (a session manager, a debounced saver), not for many short-lived ones.

### Plain data with module functions

```lua
--!strict
export type Inventory = { items: { [string]: number }, capacity: number }

local Inventory = {}

function Inventory.new(capacity: number): Inventory
	return { items = {}, capacity = capacity }
end

function Inventory.count(inv: Inventory): number
	local n = 0
	for _, qty in inv.items do n += qty end
	return n
end

function Inventory.add(inv: Inventory, itemId: string, qty: number): boolean
	if Inventory.count(inv) + qty > inv.capacity then return false end
	inv.items[itemId] = (inv.items[itemId] or 0) + qty
	return true
end

return Inventory
```

This inventory can be saved to a DataStore, sent through a remote, deep-copied, frozen, diffed and unit-tested with no conversion step, because it is just data. That is why the save profile and every network payload in a game should look like this, even when the server wraps it in richer objects at runtime ([[Data Schema Design and Migrations]]).

---

## 2. When a metatable class is the right tool

Use a class when **all** of these hold:

1. There are **many instances** of the thing (so one shared method table saves memory and avoids per-object closures), or the thing is a reusable library type (Signal, Maid, Timer, StateMachine).
2. The object **owns resources** that need a lifecycle: connections, instances, threads.
3. It **stays on one side** of the client-server boundary and is not saved as is.
4. Behaviour varies by **data**, not by a type hierarchy.

Good fits: a `Signal` class, a cleanup bag (Maid/Trove style), a per-enemy brain on the server, a per-widget UI controller, a projectile simulator in a game with dozens of projectiles, a state machine ([[Events Signals and Connections]]).

Poor fits:

| Thing | Why not a class | Use instead |
|---|---|---|
| Item definitions, configs | Pure data; should be frozen and shared | Frozen tables ([[Tables Metatables and OOP]] section 3) |
| Player save profile | Must serialise; metatables are dropped by DataStores | Plain data + module functions |
| Network payloads | Metatables dropped by remotes | Plain data |
| Singletons (DataService, CombatService) | One instance; `self` adds nothing | A module returning a table of functions |
| 10,000 grass blades or bullets | Per-object table overhead and pointer chasing | Structure of arrays, buffers ([[Buffers and Binary Data]]) |
| "Every NPC type is a subclass" | Deep hierarchies, fragile overrides | Composition + data ([[Entity Component Systems]]) |

---

## 3. Why composition beats inheritance in game code

The classic trap: `Enemy -> MeleeEnemy -> Boss -> FireBoss`. Then design asks for a ranged boss, a melee enemy that can fly, and an elite version of everything. Each new combination wants a new subclass or a mixin that reaches into a parent's internals.

**Measured in the reference project:** both the old and the rebuilt enemy systems were data-driven: each enemy's attacks, marker times, hits, poise and phases were data, and one shared brain ran them. Because the roster was data plus models plus clips, it moved from a deleted staging map onto the original zones in one evening, and later got an entirely new look without touching the AI ([[Case Study - Enemy Roster Rebuild]]). That is composition: the "type" is a bundle of data and components, not a class.

A composition-first enemy:

```lua
--!strict
type Health = { current: number, max: number }
type Mover = { speed: number, target: Vector3? }
type AttackDef = { name: string, range: number, cooldown: number, windup: number }

export type Enemy = {
	id: number,
	model: Model,
	health: Health,
	mover: Mover,
	attacks: { AttackDef },
	nextAttackAt: number,
	flags: { [string]: boolean }, -- "elite", "flying", "boss"
}

local function newEnemy(id: number, model: Model, def: any): Enemy
	return {
		id = id,
		model = model,
		health = { current = def.maxHealth, max = def.maxHealth },
		mover = { speed = def.speed, target = nil },
		attacks = def.attacks,          -- shared, frozen definition tables
		nextAttackAt = 0,
		flags = table.clone(def.flags), -- per-instance copy because flags can change at runtime
	}
end
```

Systems (`HealthSystem.damage(enemy, amount)`, `MoveSystem.step(enemies, dt)`, `AttackSystem.step(enemies, now)`) operate on these records. A flying elite boss is a data row with three flags, not a class. When you need polymorphism, put a function reference in data (`def.onDeath`) rather than overriding a method in a subclass.

When inheritance is acceptable: one level, for a shared base with a small, stable contract (a UI `Widget` base with `mount`, `update`, `destroy`). Two levels is a smell; three is a refactor waiting to happen. Each level also adds an `__index` hop to every inherited lookup, and luau.org advises avoiding deep `__index` chains.

---

## 4. Metamethod tricks: clever, and what they cost

### 4.1 `__index` functions

An `__index` **function** runs Luau code on every missing-key read. luau.org recommends `__index` point directly at a table, because function `__index` defeats inline caching. Use functions only where the dynamic behaviour is the point (defaults, lazy loading), and never on hot paths.

They also cannot yield: metamethods are not yieldable, so `__index` cannot call `WaitForChild` or a DataStore. Lazy "load on first access" designs fail here. Load explicitly.

### 4.2 Change tracking with `__newindex`

`__newindex` fires only when the key is **missing** from the table. To observe every write you need an empty proxy that stores data elsewhere:

```lua
--!strict
local function observable(onChange: (key: string, old: any, new: any) -> ())
	local data: { [string]: any } = {}
	local proxy = setmetatable({}, {
		__index = data,
		__newindex = function(_, key: string, value: any)
			local old = data[key]
			if old ~= value then
				data[key] = value
				onChange(key, old, value)
			end
		end,
		__iter = function()
			return next, data
		end,
	})
	return proxy, data
end
```

Hidden costs and traps:

- `#proxy` is 0 and `next(proxy)` is `nil` unless you add `__len` and route iteration through `__iter`. Library functions such as `table.insert`, `table.sort` and `table.concat` act on the empty proxy itself, not on `data` (rule of thumb: assume raw table functions bypass your metamethods).
- `table.clone(proxy)` copies an empty table with the same metatable: a second proxy sharing the same `data`.
- Nested tables are not observed: `proxy.stats.hp = 5` reads `stats` through `__index` and writes into the inner table directly. No change event.
- Every write runs a Luau function. For a profile written dozens of times per second it adds up.

**Better for most games:** explicit mutation functions (`Profile.addCoins(profile, n)`) that do the write and then mark dirty and notify. They are greppable, typed and cheap. The reference project used exactly this shape: every profile mutation calls a state push to the client mirror and a debounced save ([[Rate Limiting and Abuse Prevention]], coalescing).

### 4.3 Read-only proxies versus `table.freeze`

Before `table.freeze`, read-only tables were proxies with an erroring `__newindex`. Prefer `table.freeze` now: it is shallow but cheap, reads stay plain table reads, and writes throw immediately. A proxy adds a metamethod hop on every read and still lets `rawset` through.

### 4.4 Operator overloading

`__add`, `__eq`, `__lt` and friends make value types read nicely (`a + b`). In Roblox game code the useful cases are rare, because the engine already provides value types (`Vector3`, `CFrame`, `Color3`, `UDim2`) with fast native operators. Pitfalls when you do define them:

- Each `a + b` on your type allocates a new table. In a loop that is GC churn that `Vector3` maths avoids entirely.
- `__eq` is only consulted when **both** operands are tables (Docs), so `money == 5` is always false without error.
- Tables with `__eq` used as dictionary keys are still keyed by identity; two "equal" values are two different keys.

A typed `Money` wrapper with `__add` is a classic over-engineering example. A number field plus `math.floor` at the boundaries is simpler.

### 4.5 `__call` constructors

`setmetatable(Class, { __call = function(_, ...) return Class.new(...) end })` lets you write `Class(...)`. It saves four characters and hides allocation sites from search. Prefer explicit `Class.new`.

### 4.6 `__metatable` locking

Setting `__metatable` makes `getmetatable` return that value and `setmetatable` error. It protects library internals from accidental tampering. It is not a security feature: anything on the client can be read by an exploiter anyway, and server code is trusted by definition.

---

## 5. Lifecycle: where OOP goes wrong in Roblox

Most class bugs in Roblox games are not about methods, they are about **lifetimes**: an object outlives the instance it represents, or the instance outlives the object.

Rules that prevent most of them:

1. **Every class that connects, spawns or creates has a `Destroy`.** It disconnects, cancels threads, destroys created instances and clears references.
2. **`Destroy` is idempotent.** It can be called twice (from `Destroying` and from your own cleanup) without erroring.
3. **Tie the object to the instance.** Connect `instance.Destroying` (or the owning player's `PlayerRemoving`) to `Destroy`.
4. **Use one cleanup bag per object** instead of a list of named connection fields.

```lua
--!strict
-- Minimal cleanup bag. Libraries such as Trove or Maid do the same with more features.
export type Bag = { _items: { any }, add: (Bag, any) -> any, clean: (Bag) -> () }

local Bag = {}
Bag.__index = Bag

function Bag.new(): Bag
	return setmetatable({ _items = {} }, Bag) :: any
end

function Bag.add(self: Bag, item: any): any
	table.insert(self._items, item)
	return item
end

function Bag.clean(self: Bag)
	local items = self._items
	self._items = {} -- swap first so re-entrant clean calls see an empty bag
	for i = #items, 1, -1 do -- reverse order: undo in the opposite order of setup
		local item = items[i]
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "thread" then
			pcall(task.cancel, item) -- the thread may already be dead or running
		elseif kind == "function" then
			item()
		elseif type(item) == "table" and type(item.Destroy) == "function" then
			item:Destroy()
		end
	end
end

return Bag
```

And a class that uses it:

```lua
--!strict
local Bag = require(script.Parent.Bag)

local Turret = {}
Turret.__index = Turret

function Turret.new(model: Model)
	local self = setmetatable({
		model = model,
		destroyed = false,
		_bag = Bag.new(),
	}, Turret)
	self._bag:add(model.Destroying:Connect(function()
		self:Destroy()
	end))
	self._bag:add(task.spawn(function()
		while not self.destroyed do
			self:scan()
			task.wait(0.25)
		end
	end))
	return self
end

function Turret.scan(self: any)
	-- target logic
end

function Turret.Destroy(self: any)
	if self.destroyed then return end -- idempotent
	self.destroyed = true
	self._bag:clean()
end

return Turret
```

How to spot lifecycle bugs: memory grows on long servers ([[Memory Budgets and Leaks]]); "attempt to index nil with Position" errors long after an enemy died (a loop still running for a destroyed model); an event firing twice because a re-created object never destroyed its predecessor.

---

## 6. Typing classes in strict mode

The common strict-mode pattern from [[Tables Metatables and OOP]] (`typeof(setmetatable({} :: Fields, Class))`) works, with known friction:

- Methods defined with `function Class.method(self: Class, ...)` need the explicit `self` annotation for the checker to know the type.
- Inheritance types are awkward; casting through `any` is common and loses checking.
- Private fields are only private by convention (`_bag`).

Plain data with module functions types cleanly (`export type Inventory = {...}`), which is one more reason to prefer it for core state. Use `--!strict` and see [[Luau Type System and Strict Mode]] for the details. Avoid committing to patterns that depend on a specific type solver version; Luau's type checker has been changing, so check the current docs before adopting new class-typing syntax.

---

## 7. Serialisation and hot reload

**Serialisation.** Classes need an explicit conversion at every boundary:

```lua
function Turret.toData(self: any): { [string]: any }
	return { model = self.model.Name, kills = self.kills }
end
```

Rule of thumb: if you find yourself writing `toData`/`fromData` for a class that is mostly data, the class probably should have been data with module functions in the first place.

**Hot reload and require caching.** A required ModuleScript is cached per environment. If you re-require an edited copy (a common debugging trick), you get a **new** class table: objects created before the reload still have the old metatable, and `getmetatable(obj) == Class` is false for them. The reference project hit the related problem of stale cached modules when testing edited code from the command bar, and adopted a "clone the module, then require the clone" check ([[Module Scripts and Requiring]]). Identity checks against class tables are fragile across reloads; prefer a `kind` field when you need runtime type checks.

---

## 8. A decision walk-through

Question: "We need a cooldown tracker for abilities, per player, on the server."

1. Is it saved or sent? Cooldown end times might be sent to the client for UI. So the state should be plain data: `{ [abilityId]: number }`.
2. Does it own resources? No connections, no instances. No lifecycle needed beyond removing it on `PlayerRemoving`.
3. How many? One per player. Few.
4. Verdict: plain data in a module keyed by player, with functions `Cooldowns.ready(player, id, now)` and `Cooldowns.start(player, id, now, duration)`. No class.

Question: "We need a projectile simulator for 200 simultaneous projectiles, server side."

1. Saved or sent? No (results are sent, not objects).
2. Owns resources? Possibly a visual part on clients, none on the server.
3. How many? Hundreds, created and destroyed constantly.
4. Verdict: structure of arrays or an array of plain records updated by one loop, with swap-remove ([[Luau Performance Patterns with Benchmarks]]). A class per projectile adds allocation per spawn and per-object method dispatch for nothing.

Question: "We need a reusable dialog widget with open, close, animations and button connections."

1. Saved or sent? No.
2. Owns resources? Yes: instances, connections, tweens.
3. How many? A few at a time, many over a session.
4. Verdict: a class with a cleanup bag and an idempotent `Destroy`.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Methods missing after a save/load or remote | Metatable dropped | Plain data at boundaries; rebuild objects |
| Subclass explosion | Inheritance for variation | Composition + data rows |
| Change events miss nested writes | `__newindex` proxy only sees top level | Explicit mutation functions |
| `#t` is 0 on a proxy | Data lives in a hidden table | Add `__len`/`__iter`, or avoid proxies |
| Loops running for destroyed models | No `Destroy` tied to `Destroying` | Cleanup bag + idempotent `Destroy` |
| GC churn in maths code | Operator-overloaded table types | Native `Vector3`/numbers |
| `obj:IsA`-style checks fail after reload | Class table identity changed | `kind` field |
| Memory per object surprisingly high | Closure objects at scale | Metatable class or SoA |

## Checklist

- [ ] Saved and networked state is plain data, not class instances.
- [ ] Singletons are modules, not classes.
- [ ] Classes are used for many-instance or resource-owning objects only.
- [ ] Inheritance depth is at most one; variation comes from data and components.
- [ ] `__index` points to a table on anything hot.
- [ ] No `__newindex` proxies for core state; explicit mutation functions instead.
- [ ] Every resource-owning object has an idempotent `Destroy` tied to its instance or player.
- [ ] Hot entity loops use arrays of records or structure of arrays.

## See also

[[Tables Metatables and OOP]] · [[Entity Component Systems]] · [[Functions Closures and Upvalues]] · [[Events Signals and Connections]] · [[Luau Type System and Strict Mode]] · [[Module Scripts and Requiring]] · [[Memory Budgets and Leaks]] · [[Data Schema Design and Migrations]] · [[Luau Performance Patterns with Benchmarks]] · [[Case Study - Enemy Roster Rebuild]]

## Connected notes
<!-- auto-links:start -->
[[Links - OOP and module design]] · [[Luau Performance and Native Codegen]] · Luau Garbage Collection and the Memory Model · Links - Luau language · Advanced Luau Start Here · Advanced Types - Generics and Type Functions
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Luau Language Essentials]] · [[Instances Attributes and Tags]] · [[CollectionService Patterns]] · [[Error Handling - pcall xpcall and Promise Patterns]] · [[Script Types and Run Context]] · [[Task Library Coroutines and Yielding]] · [[Parallel Luau and Actors]] · [[Error Handling and Retries]]
<!-- related:end -->
