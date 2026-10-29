---
tags: [luau, tables, metatables, oop, data-structures]
---
# Tables Metatables and OOP

<!-- tldr:start -->
> [!tldr] TL;DR
> - `#list` wrong after removal: `list[i] = nil` created a hole -> `table.remove` or swap-remove
> - `invalid order function for sorting` live only: Comparator uses `<=` or no tie-break -> Strict comparator with tie-breaker
> - Config values change mid-game: Shared table mutated through a reference -> Freeze config; clone before modifying
> - Arrays have no holes; dictionaries are iterated, not measured.
> - Sort comparators are strict with explicit tie-breaks.
> - Shared config is deep-frozen.
>
> Cost: TL;DR ~160 tok · whole note ~4.6k tok. Read more: ## 5. Classes · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Tables are Luau's only built-in data structure. Arrays, dictionaries, sets, objects, classes, modules and configuration are all tables. Metatables let a table customize indexing, arithmetic, comparison, calling and iteration, which is how classes are built. This note covers how tables behave (including the length operator and holes), the `table` library, copying and freezing, metatables, class patterns with inheritance and composition, weak tables, and what happens to tables when they cross Roblox boundaries.

---

## 1. Arrays and dictionaries are one structure

Internally a table has an **array part** (keys `1..n`) and a **hash part** (everything else). You choose the access pattern; Luau chooses the storage.

```lua
local list = { "Sword", "Bow", "Staff" }        -- array: keys 1, 2, 3
local stats = { hp = 100, armor = 5 }           -- dictionary: string keys
local set = { [workspace.Baseplate] = true }    -- Instances (any value except nil and NaN) can be keys
local mixed = { "a", "b", kind = "letters" }    -- legal, but see section 7 before sending it anywhere

print(list[1])          --> Sword (arrays start at 1)
print(stats.hp)         --> 100   (stats.hp is sugar for stats["hp"])
print(stats.missing)    --> nil   (reading a missing key is not an error)
```

### The length operator and holes

`#t` returns a **border**: an index `n` where `t[n]` is non-nil and `t[n + 1]` is nil. For a proper sequence (no `nil` between 1 and the end) that is the count. With holes it can be any border.

```lua
local t = { 1, 2, 3 }
t[2] = nil
print(#t)    --> 3 or 1: unspecified. Never create holes in arrays you measure.
```

Consequences:
- Removing from the middle with `t[i] = nil` breaks `#`, `ipairs` (stops at the hole) and `table.insert`. Use `table.remove(t, i)` (shifts, O(n)) or swap-remove (O(1), order not kept):

```lua
local function swapRemove<T>(t: { T }, i: number)
	local n = #t
	t[i] = t[n]
	t[n] = nil
end
```

- To count a dictionary you must iterate; there is no O(1) size. Keep a counter beside it if you need one often.
- Luau caches the length, so `#t` is effectively O(1) on proper arrays (Docs: luau.org performance).

---

## 2. The `table` library

| Function | Notes |
|---|---|
| `table.insert(t, v)` / `table.insert(t, i, v)` | Append / insert with shift |
| `table.remove(t, i?)` | Removes and returns; default last element |
| `table.create(n, v?)` | Preallocates the array part (Docs); fill value optional |
| `table.find(t, v, init?)` | Linear search, returns index or `nil` |
| `table.clear(t)` | Empties in place, **keeps capacity**; good for reused per-frame buffers |
| `table.clone(t)` | Shallow copy; same metatable; result is never frozen (Docs) |
| `table.freeze(t)` / `table.isfrozen(t)` | Shallow read-only; writes throw |
| `table.move(src, a, b, t, dst?)` | Range copy; overlap-safe |
| `table.sort(t, comp?)` | In place, not stable; introsort, N log N worst case (Docs) |
| `table.concat(t, sep?, i?, j?)` | Strings and numbers only |
| `table.pack(...)` / `table.unpack(t, i?, j?)` | `pack` sets `n` (counts nils) |

Deprecated: `table.foreach`, `table.foreachi`, `table.getn` (Docs).

**`table.sort` comparator rule.** It must be a strict ordering: `comp(a, a)` must be `false`, and never both `comp(a, b)` and `comp(b, a)`. Using `<=` breaks this, and Luau may throw `invalid order function for sorting` (Docs). It is data-dependent, so it can pass in testing and fail live when two items tie. Break ties explicitly:

```lua
table.sort(entries, function(a, b)
	if a.score ~= b.score then
		return a.score > b.score
	end
	return a.userId < b.userId   -- deterministic tie-break
end)
```

**`table.sort` is not stable.** Equal elements may reorder between calls, which makes leaderboards flicker. Same fix: a tie-breaker.

---

## 3. References, copies and freezing

Tables are passed by reference. Assigning or passing a table never copies it.

```lua
local defaults = { volume = 0.5 }
local mine = defaults
mine.volume = 1
print(defaults.volume)  --> 1  (same table)
```

`table.clone` copies one level. Nested tables are still shared. A deep copy:

```lua
local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[deepCopy(k)] = deepCopy(v)
	end
	return setmetatable(out, getmetatable(value :: any)) :: any
end
```

(Cycles would recurse forever; add a `seen` map if your data can be cyclic.)

**Freezing config.** A shared config module is mutated by accident more often than you think (`local cfg = Config.Items.Sword; cfg.Damage *= 2` in one system changes it for every system). Freeze it:

```lua
local function deepFreeze<T>(t: T): T
	if type(t) == "table" and not table.isfrozen(t) then
		table.freeze(t)
		for _, v in t :: any do
			deepFreeze(v)
		end
	end
	return t
end

return deepFreeze({
	Sword = { Damage = 10, Cooldown = 0.6 },
	Bow = { Damage = 7, Cooldown = 0.9 },
})
```

A write to a frozen table errors immediately ("attempt to modify a readonly table"), so the bug surfaces at the line that caused it. Frozen tables also replicate their intent to readers: this data is not state.

---

## 4. Metatables and metamethods

`setmetatable(t, mt)` attaches `mt`; the engine consults its fields ("metamethods") for operations the table does not handle itself.

| Metamethod | Triggered by | Notes |
|---|---|---|
| `__index` | Reading a missing key | A table (fast, recommended) or a function `(t, k)` |
| `__newindex` | Writing a **missing** key | Not called for existing keys |
| `__call` | `t(...)` | |
| `__tostring` | `tostring(t)`, `print(t)` | |
| `__eq` | `==` between two tables | Only called when both operands are tables |
| `__lt`, `__le` | `<`, `<=` (and `>`, `>=` swapped) | |
| `__add __sub __mul __div __idiv __mod __pow __unm` | Arithmetic | `__idiv` is for `//` |
| `__concat` | `..` | |
| `__len` | `#t` | |
| `__iter` | `for k, v in t` | Luau addition (Docs) |
| `__mode` | Weak keys/values | `"k"`, `"v"`, `"kv"` |
| `__metatable` | `getmetatable` returns this value; `setmetatable` errors | Locks the metatable |

Not supported: `__gc` (Docs). Metamethods cannot yield (Docs: "yieldable metamethods" are not supported), so a `__index` function must not call `WaitForChild` or `task.wait`.

`rawget`, `rawset`, `rawequal` and `rawlen` bypass metamethods.

### Default values and read-only proxies

```lua
local withDefault = setmetatable({}, {
	__index = function(_, _key)
		return 0
	end,
})
withDefault.kills += 1    -- reads 0 through __index, writes 1 as a real key
```

### Custom iteration with `__iter`

```lua
local Inventory = {}
Inventory.__index = Inventory
Inventory.__iter = function(self)
	return next, self._items     -- iterate the internal table, not the wrapper
end

local inv = setmetatable({ _items = { Sword = 1, Potion = 3 } }, Inventory)
for name, count in inv do
	print(name, count)
end
```

---

## 5. Classes

The standard idiom: a class table that is also the metatable of its instances, with `__index` pointing at itself.

```lua
--!strict
local Enemy = {}
Enemy.__index = Enemy

export type Enemy = typeof(setmetatable({} :: {
	model: Model,
	health: number,
	maxHealth: number,
	_connections: { RBXScriptConnection },
}, Enemy))

function Enemy.new(model: Model, maxHealth: number): Enemy
	local self = setmetatable({
		model = model,
		health = maxHealth,
		maxHealth = maxHealth,
		_connections = {},
	}, Enemy)
	table.insert(self._connections, model.Destroying:Connect(function()
		self:Destroy()
	end))
	return self
end

function Enemy.takeDamage(self: Enemy, amount: number): boolean
	self.health = math.max(self.health - amount, 0)
	return self.health == 0
end

function Enemy.Destroy(self: Enemy)
	for _, c in self._connections do
		c:Disconnect()
	end
	table.clear(self._connections)
end

return Enemy
```

Why `__index = Enemy` as a **table** rather than a function: Luau's inline caching and fast method calls work best when `__index` is a table and fields live directly on the object (Docs: luau.org performance: "store fields directly inside the table"; avoid `__index` functions and deep chains).

**`:` vs `.`**: `obj:method(x)` is `obj.method(obj, x)`. Mixing them up gives "attempt to index nil" on `self` or shifts every argument by one. Lint and the type checker catch most cases in strict mode.

### Inheritance

```lua
local Boss = setmetatable({}, { __index = Enemy })
Boss.__index = Boss

function Boss.new(model: Model, maxHealth: number, phases: number)
	local self = Enemy.new(model, maxHealth) :: any
	setmetatable(self, Boss)
	self.phases = phases
	return self
end

function Boss.takeDamage(self, amount: number): boolean
	local died = Enemy.takeDamage(self, amount * 0.5)   -- call the parent explicitly
	return died
end
```

Each level of inheritance adds an `__index` hop on every inherited method lookup, and typing inheritance in Luau is awkward. **Prefer composition** for game objects: an enemy *has* a health component, a movement component, an animation controller. Components are plain tables or small classes; the owner forwards calls. This is the same idea that [[Entity Component Systems]] takes further.

### When not to use classes

- Pure data (configs, save profiles, network payloads) should stay plain tables. Metatables are lost on `DataStore` saves and remote sends (section 7) and complicate serialization.
- One-off singletons are just modules returning a table of functions.
- Hot paths with thousands of objects may be better as **structure of arrays** (`positions[i]`, `velocities[i]`) than arrays of objects, see [[Luau Performance and Native Codegen]].

---

## 6. Weak tables and caches

`__mode = "k"` makes keys weak: an entry disappears when nothing else references the key. Useful for per-object metadata without leaks:

```lua
local lastHitTime = setmetatable({} :: { [Model]: number }, { __mode = "k" })
```

**Roblox nuance.** An Instance stays referenced while it is in the DataModel, and a destroyed Instance can still be referenced by Luau objects (connections, closures, your own tables). Weak keys only help once *all* strong references are gone, and collection timing is not deterministic. For Instances, prefer explicit cleanup on `Destroying` or `AncestryChanged`, or CollectionService instance-removed signals ([[CollectionService Patterns]]). Do not rely on weak tables for gameplay correctness, only as a leak safety net. See [[Memory Budgets and Leaks]].

---

## 7. Tables crossing Roblox boundaries

RemoteEvents, RemoteFunctions, BindableEvents, `Actor:SendMessage`, DataStores and `HttpService:JSONEncode` all **copy** tables and apply rules (Docs: remote and bindable argument limitations):

- **Metatables are dropped.** A class instance arrives as a plain table without methods.
- **Mixed tables lose data.** Do not mix array and string keys; send pure arrays or pure dictionaries.
- **Non-string keys are converted to strings** (Instance keys become their string form) for bindables and remotes. A table keyed by Instance does not survive.
- **`nil` holes** in arrays truncate them. Avoid `nil` values.
- **Functions and threads cannot be sent.**
- **Identity is not preserved**: the receiver gets a new table each time.

Design payloads as plain, array-or-dictionary, string-keyed data. Convert at the edge:

```lua
-- Server: { [Player]: number } is not sendable; convert to { [string]: number } with UserIds
local wire = {}
for player, dmg in damageBy do
	wire[tostring(player.UserId)] = dmg
end
remote:FireAllClients(wire)
```

See [[RemoteEvents RemoteFunctions and Unreliable Remotes]] and [[Data Schema Design and Migrations]].

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| `#list` wrong after removal | `list[i] = nil` created a hole | `table.remove` or swap-remove |
| `invalid order function for sorting` live only | Comparator uses `<=` or no tie-break | Strict comparator with tie-breaker |
| Config values change mid-game | Shared table mutated through a reference | Freeze config; clone before modifying |
| Methods missing on client | Object sent through a remote | Send plain data; rebuild objects client-side |
| Two clicks, two objects reacting to one event | Class created twice; old one never destroyed | `Destroy` method disconnecting everything |
| Infinite recursion in `__index` | Function reads `self.x` which triggers `__index` | `rawget(self, "x")` |
| Leak through a cache of Instances | Strong table keys | Clean up on destroy; weak keys as safety net |

## Checklist

- [ ] Arrays have no holes; dictionaries are iterated, not measured.
- [ ] Sort comparators are strict with explicit tie-breaks.
- [ ] Shared config is deep-frozen.
- [ ] Classes use `__index = Class` (table), fields directly on objects, and a `Destroy` that disconnects.
- [ ] Composition before inheritance.
- [ ] Network and save payloads are plain, homogeneous, string-keyed tables.

## See also

[[Luau Language Essentials]] · [[Luau Type System and Strict Mode]] · [[Functions Closures and Upvalues]] · [[Events Signals and Connections]] · [[Module Scripts and Requiring]] · [[Entity Component Systems]] · [[Memory Budgets and Leaks]] · [[Data Schema Design and Migrations]]

## Nuances and edge cases

1. **Dictionaries have no reliable order.** `pairs` over a dictionary does not return keys in insertion order, and the order can differ between server and client or between runs. Anything that must be stable (UI lists, save output, deterministic simulation) needs an explicit array of keys or a sort.
2. **Freezing is shallow.** `table.freeze` stops changes to the top-level table only; nested tables are still mutable. A frozen config with nested weapon stats can still be edited through `Config.Weapons.Sword.Damage = 999`. Freeze recursively at load time if config must be immutable.
3. **Tables crossing the network lose structure.** Remotes drop metatables and functions, convert some key types, and mixed tables (array part plus string keys) can lose entries. Non-string dictionary keys such as numbers that are not a contiguous array arrive as strings or vanish. Send arrays of records with explicit fields, not dictionaries keyed by numbers.
4. **Large tables have a memory and GC cost on low-end devices.** A table of 100,000 small records costs megabytes plus collector time; on a low-end phone that shows as frame spikes when the collector runs. Structure-of-arrays (one array per field) uses fewer tables than array-of-structures and can be gentler on memory for very large data sets (rule of thumb; measure).
5. **OOP depth hurts more than it helps in Roblox games.** One level of inheritance (a base enemy and variants) is easy to follow. Three levels plus mixins make it hard to find which method runs. Most game objects are better as plain data plus functions, or composition, with classes only for things that own resources and need a `Destroy`.
6. **`__index` chains are slower than direct fields.** Every method lookup through a metatable chain costs a little. For 10 objects it is invisible; for 10,000 projectiles updated every frame, cache the method in a local outside the loop, or use plain functions over plain tables.
7. **Shared references cause "action at a distance".** Handing the same table to two systems means a change in one appears in the other. That is a feature for live config and a bug for per-player inventories created from a template. Deep-copy templates when creating per-player state.
8. **Scale effects on saved tables.** One player's save might be 5 KB at launch and 300 KB after a year of inventory growth. The DataStore value limit is large (4 MB per key, Roblox docs as of October 2026) but load times and session-lock writes grow with size. Prune and compact old data in migrations.

The senior trade-off: tables are the only data structure, so the question is never "table or not" but "who owns this table and who may mutate it". Make ownership explicit: one module creates and mutates, everyone else reads a frozen view or receives copies.

## Common mistakes (advanced)

1. **Using a dictionary keyed by `UserId` numbers in a save, then reading it as an array.** Symptom: `#t` is 0 even though data exists. Fix: iterate with `pairs`, or key by string.
2. **Template tables shared across players.** Symptom: one player's purchase shows up in another player's inventory. Fix: deep copy on profile creation.
3. **Comparing tables with `==`.** Symptom: equality checks fail for identical content. Fix: compare fields or a serialised form; `==` checks identity unless `__eq` is defined.
4. **`table.insert(t, pos, v)` with `pos` beyond the end.** Symptom: an error or a hole. Fix: clamp positions or append.
5. **Classes with `Destroy` that forget to clear connections.** Symptom: destroyed objects keep reacting. Fix: give each instance a cleanup object and empty it in `Destroy`.
6. **Relying on `next(t) == nil` while modifying the table.** Symptom: unpredictable behaviour when adding keys during `pairs`. Fix: collect changes and apply after iteration; assigning existing keys or clearing them is fine, adding new ones is not.

## Related decisions

- [[Metatables and OOP - When and When Not]]: the deeper argument on when classes pay off.
- [[Luau Garbage Collection and the Memory Model]]: why many small tables cost more on phones.
- [[Data Schema Design and Migrations]]: keeping saved table shapes stable.
- [[Serialization Formats for Saves and Networking]]: what survives a remote or a DataStore.
- [[Entity Component Systems]]: the data-oriented alternative to class hierarchies.
- [[Advanced Types - Generics and Type Functions]]: typing tables and classes in strict mode.
- [[Trading Systems Without Duplication]]: why shared references are dangerous in item systems.
- [[Data and Config Pipeline - Spreadsheets to Game]]: frozen config tables generated from data.

## Connected notes
<!-- auto-links:start -->
[[Links - OOP and module design]] · [[Cookbook - Tables Strings and Time]] · [[Links - Luau language]] · [[Luau Performance Patterns with Benchmarks]] · [[Reading Luau Errors and Stack Traces]] · [[Advanced Luau Start Here]]
<!-- auto-links:end -->
