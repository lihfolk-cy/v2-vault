---
tags: [luau, advanced-luau, types, generics, type-functions, strict-mode, validation]
---
# Advanced Types - Generics and Type Functions

<!-- tldr:start -->
> [!tldr] TL;DR
> - "Type is too wide" after filling an empty table: Unannotated `{}` literal -> Annotate at creation
> - `{ Sword }` rejected where `{ Item }` expected: Mutable containers are invariant -> Generic parameter plus projection, or read-only contract
> - Generic result is `unknown`: Nothing to infer `T` from -> Annotate the argument, or pass an explicit typed value
> - Empty tables that will be filled are annotated at creation.
> - Generic helpers take capabilities (callbacks) instead of needing bounds.
> - Generic containers have a public method type and a private field type, with one audited cast.
>
> Read more (20 KB note): ## 5. Runtime validators that produce typed values · ## 6. Type functions for real game types · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Luau Type System and Strict Mode]] covers the daily syntax: annotations, refinements, a first generic `map`, the `Result<T>` tagged union, `keyof`, and a `Partial` type function. This note goes past that, into the places where generic code either pays off or turns into a fight with the checker: how inference picks type arguments, variance, typing classes and containers generically, exhaustive unions, runtime validators that produce typed values, and type functions that compute real game types. It also says when to stop.

A caution that applies to everything here. As of October 2026 Luau has two type solvers. The new solver is what type functions, read-only properties and most of the precise behaviour in this note depend on, and the Roblox release notes show it still receiving fixes release by release. Where behaviour differs between solvers, this note says so; where it could not be confirmed, it says that too. Check which solver your Studio uses before debugging a surprising error.

---

## 1. How generic inference actually works

When you call a generic function, the checker has to choose the type arguments. It does so from the arguments you pass, unifying each parameter's type against each argument's type.

```lua
--!strict
local function first<T>(list: { T }): T?
	return list[1]
end

local a = first({ 1, 2, 3 })        -- T = number, a: number?
local b = first({ "x", 1 })         -- T = string | number (new solver), b: (string | number)?
```

Three consequences matter in practice.

**Inference flows from arguments, not from where the result goes.** `local n: number = first(names)` does not make `T` a number; it reports that `string?` is not `number`. If you want a specific instantiation, annotate the argument, not the result.

**Empty literals are the weak point.** `first({})` gives the checker nothing. Depending on solver and context you get `unknown`, `never`, or a free type that later unifies with whatever touches it. An empty table literal stored and filled later is the most common source of "type is too wide" complaints:

```lua
local queue = {}                   -- unsealed, element type unknown yet
table.insert(queue, 5)
table.insert(queue, "oops")        -- may be accepted, widening the element type

local typedQueue: { number } = {}  -- fix: annotate at creation
```

**Generic functions passed as values lose their generality in older code paths.** Passing `first` as a callback to another generic function sometimes forces an instantiation the moment it is passed. If a higher-order helper loses the type, wrap the call in a lambda with explicit parameter types; the lambda is easier for the checker to instantiate.

Luau also supports **default type parameters** on type aliases (`type Box<T = number> = { value: T }`). They are useful for library types where most users want one instantiation, such as a signal with no arguments.

### What Luau generics cannot express (as of October 2026)

There is no bound syntax like `<T: Instance>` or `<T extends Foo>`. If a generic function needs its `T` to have a field, you cannot state that on `T`. Three workarounds, in order of preference:

1. **Ask for the capability, not the constraint.** Instead of `<T: { Name: string }>`, take a function `getName: (T) -> string`. The caller supplies it; the function stays fully generic.
2. **Drop the generic.** If every caller passes a `Model`, the parameter is `Model`. Generics for one concrete type are noise.
3. **Intersection on the parameter.** `item: T & { Name: string }` works in some cases with the new solver, but the result type is the intersection, which may not be what you want to return. Use sparingly.

---

## 2. Variance: why `{ Sword }` is not a `{ Item }`

This surprises everyone once. Suppose `Sword` is a record with every field of `Item` plus `sharpness`. A function that accepts `{ Item }` will reject a `{ Sword }` under the new solver. The reason is mutation: the function could insert a plain `Item` into the array, and now your `{ Sword }` contains something without `sharpness`. Mutable containers are **invariant** in their element type.

The fix is to promise not to write. The new solver supports read-only properties (`read`), and Luau's types library exposes read-only indexers (the `types` library has `setreadindexer` and `readindexer`, per luau.org), which is how the checker models "this container is only read". For daily code, the simpler route is to make the function's contract obviously read-only by taking a callback or an iterator, or to make the parameter generic:

```lua
--!strict
type Item = { id: string, value: number }

-- Rejected for { Sword } under the new solver: the array could be written to.
local function totalValueStrict(items: { Item }): number
	local sum = 0
	for _, it in items do sum += it.value end
	return sum
end

-- Accepted for any array of records with a numeric 'value': generic plus a projection.
local function totalValue<T>(items: { T }, valueOf: (T) -> number): number
	local sum = 0
	for _, it in items do sum += valueOf(it) end
	return sum
end
```

Function types have the usual rules: a function that accepts a wider parameter can stand in for one that accepts a narrower one, and one that returns a narrower result can stand in for one that returns a wider one. When a callback is rejected, check the parameter direction first.

---

## 3. Generic classes that the checker understands

The standard class pattern (`typeof(setmetatable({} :: Fields, Class))`) does not take type parameters directly, because `typeof` captures one concrete type. For a generic container (a pool, a ring buffer, a typed cache) declare the type explicitly and cast the constructor result once.

```lua
--!strict
-- RingBuffer<T>: fixed capacity, overwrites the oldest entry.
local RingBuffer = {}
RingBuffer.__index = RingBuffer

export type RingBuffer<T> = {
	push: (self: RingBuffer<T>, value: T) -> (),
	get: (self: RingBuffer<T>, age: number) -> T?,   -- 0 = newest
	size: (self: RingBuffer<T>) -> number,
}

type Internal<T> = {
	items: { T },
	head: number,
	count: number,
	capacity: number,
}

function RingBuffer.new<T>(capacity: number): RingBuffer<T>
	local self: Internal<T> = {
		items = table.create(capacity),
		head = 0,
		count = 0,
		capacity = capacity,
	}
	return (setmetatable(self, RingBuffer) :: any) :: RingBuffer<T>
end

function RingBuffer.push<T>(self: Internal<T>, value: T)
	self.head = self.head % self.capacity + 1
	self.items[self.head] = value
	self.count = math.min(self.count + 1, self.capacity)
end

function RingBuffer.get<T>(self: Internal<T>, age: number): T?
	if age < 0 or age >= self.count then
		return nil
	end
	local index = (self.head - 1 - age) % self.capacity + 1
	return self.items[index]
end

function RingBuffer.size<T>(self: Internal<T>): number
	return self.count
end

return RingBuffer
```

The public type lists only methods; the internal type lists fields. The single `:: any` cast lives in the constructor, where it is easy to audit, and every caller gets precise types: `RingBuffer.new(32) :: RingBuffer<CFrame>` or `local history: RingBuffer.RingBuffer<CFrame> = RingBuffer.new(32)`. Splitting public and internal types also stops callers from poking at `head`.

The cost is that the method implementations are checked against `Internal<T>`, not against the public type, so the checker will not notice if `push` in the public type and the implementation drift apart. Keep them adjacent and short.

---

## 4. Exhaustive unions with `never`

Tagged unions shine when the checker can prove you handled every case. The trick is a final branch that assigns the refined value to `never`:

```lua
--!strict
type Effect =
	{ kind: "damage", amount: number }
	| { kind: "heal", amount: number }
	| { kind: "stun", seconds: number }

local function describe(e: Effect): string
	if e.kind == "damage" then
		return `-{e.amount}`
	elseif e.kind == "heal" then
		return `+{e.amount}`
	elseif e.kind == "stun" then
		return `stun {e.seconds}s`
	else
		local unreachable: never = e   -- error here if a new kind is added and not handled
		return unreachable
	end
end
```

Add `{ kind: "burn", perSecond: number }` to `Effect` and the `never` line becomes a type error at every `describe`-style function that forgot it. That is exactly the review you want when status effects multiply ([[Status Effects Buffs and Stacking Rules]]). This relies on the new solver's refinement of singleton fields; under the old solver the error may not appear, so test it once by adding a fake case.

Two rules keep unions useful:

- **One discriminant field, string singletons, same name everywhere** (`kind` or `type`). Mixing `kind` in some variants and `tag` in others defeats refinement.
- **Do not refine through a helper function.** `if isDamage(e) then` does not narrow `e` unless the checker can see through the function, which it generally cannot. Compare the field inline.

---

## 5. Runtime validators that produce typed values

Types are erased at runtime. Remote arguments, DataStore loads and config pulled from MemoryStore arrive as `unknown`, and a type annotation on them is a lie the checker will happily believe. [[Server Authority and Validation]] explains what to check; this section shows how to make the checks and the types one thing, so a validator cannot accept something its type does not describe.

The idea: a `Check<T>` is a function from `unknown` to either a `T` or `nil` plus an error. Combinators build bigger checks from smaller ones, and the type of the result is computed by the generics.

```lua
--!strict
export type Check<T> = (value: unknown) -> (T?, string?)

local V = {}

function V.number(min: number, max: number): Check<number>
	return function(value)
		if typeof(value) ~= "number" then return nil, "expected number" end
		if value ~= value then return nil, "NaN" end
		if value < min or value > max then return nil, `out of range {min}..{max}` end
		return value, nil
	end
end

function V.integer(min: number, max: number): Check<number>
	local base = V.number(min, max)
	return function(value)
		local n, err = base(value)
		if n == nil then return nil, err end
		if n % 1 ~= 0 then return nil, "expected integer" end
		return n, nil
	end
end

function V.stringOf(maxLength: number): Check<string>
	return function(value)
		if typeof(value) ~= "string" then return nil, "expected string" end
		if #value > maxLength then return nil, "string too long" end
		if not utf8.len(value) then return nil, "invalid utf8" end
		return value, nil
	end
end

function V.oneOf<T>(allowed: { T }): Check<T>
	local set = {}
	for _, v in allowed do set[v] = true end
	return function(value)
		if set[value :: any] then return value :: any, nil end
		return nil, "not an allowed value"
	end
end

function V.instanceOf(className: string): Check<Instance>
	return function(value)
		if typeof(value) ~= "Instance" then return nil, "expected Instance" end
		if not (value :: Instance):IsA(className) then return nil, `expected {className}` end
		return value :: Instance, nil
	end
end

function V.array<T>(item: Check<T>, maxCount: number): Check<{ T }>
	return function(value)
		if typeof(value) ~= "table" then return nil, "expected array" end
		local t = value :: { [any]: any }
		local n = #t
		if n > maxCount then return nil, "array too long" end
		local count = 0
		for _ in t do count += 1 end
		if count ~= n then return nil, "not a dense array" end
		local out = table.create(n)
		for i = 1, n do
			local v, err = item(t[i])
			if v == nil then return nil, `[{i}] {err}` end
			out[i] = v
		end
		return out, nil
	end
end

return V
```

Using it at a remote boundary:

```lua
--!strict
local V = require(ReplicatedStorage.Shared.V)

local checkSlot = V.integer(1, 60)
local checkMode = V.oneOf({ "equip", "unequip" })

EquipRemote.OnServerEvent:Connect(function(player: Player, rawSlot: unknown, rawMode: unknown)
	local slot, slotErr = checkSlot(rawSlot)
	local mode, modeErr = checkMode(rawMode)
	if slot == nil or mode == nil then
		-- log at low verbosity: exploiters send junk constantly
		return
	end
	-- slot: number, mode: string, both proven at runtime
end)
```

Notes on the design:

- **Validators return copies for containers.** `V.array` builds a new table from checked elements. That means nothing the client sent (extra keys, a metatable stripped in transit) leaks past the boundary.
- **Literal unions are where this is weakest.** `V.oneOf({ "equip", "unequip" })` is typed `Check<string>`, not `Check<"equip" | "unequip">`, because the array literal's element type widens to `string`. If you need the singleton union, annotate the result: `local checkMode: V.Check<"equip" | "unequip"> = V.oneOf(...) :: any`. The cast is honest only because the runtime set matches; keep them on the same line.
- **Records.** A `V.record` combinator that takes `{ [string]: Check<any> }` loses per-field types, because Luau cannot map over a table type's fields at the value level. This is a place where a type function (section 6) can help, or where a hand-written record validator with a declared return type is clearer. Community libraries such as `t` follow the same combinator idea; read their source before writing your own.

---

## 6. Type functions for real game types

Type functions run during analysis and compute types from types (luau.org). The existing note shows `keyof` and a `Partial`. Here are three that solve problems game code actually has, plus the limits that decide whether to use them.

The `types` library (luau.org, as of October 2026) provides `types.singleton`, `types.negationof`, `types.optional`, `types.unionof`, `types.intersectionof`, `types.newtable`, `types.newfunction`, `types.copy` and `types.generic`, primitive properties like `types.number` and `types.string`, and methods on type objects including `tag`, `is`, `issubtypeof`, `properties`, `readproperty`, `writeproperty`, `setproperty`, `setreadproperty`, `indexer`, `setindexer`, `components`, `parameters`, `returns` and `value` (for singletons).

### 6.1 Readonly: config that cannot be assigned to

Frozen config tables (`table.freeze`) fail at runtime when written. A `Readonly<T>` type moves that failure to analysis:

```lua
--!strict
type function Readonly(t)
	if not t:is("table") then
		error("Readonly expects a table type")
	end
	local out = types.newtable()
	for key, prop in t:properties() do
		if prop.read then
			out:setreadproperty(key, prop.read)
		end
	end
	return out
end

type ZoneConfig = { Name: string, Price: number, RequiredLevel: number }
local ZONE_A: Readonly<ZoneConfig> = table.freeze({ Name = "Meadow", Price = 0, RequiredLevel = 1 })
-- ZONE_A.Price = 5   -- type error: property is read-only
```

This is shallow, like `table.freeze`. A recursive version calls itself on nested table types; recursion in type functions works, but deep recursion over large config types slows analysis noticeably (rule of thumb), so keep config types shallow.

### 6.2 Pick: a view of a record

```lua
--!strict
type function Pick(t, keys)
	if not t:is("table") then
		error("Pick expects a table type")
	end
	local wanted = {}
	if keys:is("singleton") then
		wanted[keys:value()] = true
	elseif keys:is("union") then
		for _, part in keys:components() do
			if not part:is("singleton") then
				error("Pick keys must be string singletons")
			end
			wanted[part:value()] = true
		end
	else
		error("Pick keys must be a singleton or a union of singletons")
	end
	local out = types.newtable()
	for key, prop in t:properties() do
		-- property keys arrive as singleton types; compare by value
		if key:is("singleton") and wanted[key:value()] and prop.read then
			out:setproperty(key, prop.read)
		end
	end
	return out
end

type Profile = { Coins: number, Gems: number, Settings: { Music: number }, Inventory: { string } }
type CurrencyView = Pick<Profile, "Coins" | "Gems">   -- { Coins: number, Gems: number }
```

Useful for remote payload types derived from the server profile: the replicated slice is defined in terms of the source of truth, so renaming `Coins` breaks the build instead of silently desyncing.

A detail worth knowing: in the `properties()` iteration the keys are type objects (singletons), not plain strings, which is why the comparison goes through `key:value()`. If this differs in your Studio version, `print` inside the type function shows what you received; output appears in the analysis results, not at runtime.

### 6.3 Payload types from a remote registry

A common architecture has one module listing every remote and its argument types. Type functions can turn a registry type into per-remote handler signatures, but this is the point where most teams should stop: the gain over writing the handler types by hand is small, and the error messages when the registry is wrong are poor. Prefer explicit types per remote ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]) plus runtime validators from section 5.

### Limits of type functions

- **No runtime values, no Roblox APIs.** The environment is the `types` library plus a small set of globals and the `math`, `table`, `string`, `bit32`, `utf8` and `buffer` libraries (luau.org). You cannot read a ModuleScript's actual config table to build a type.
- **Errors surface at every use site.** A bug in a type function used in 200 places produces 200 errors. Test a new type function against a few hand-checked inputs in a scratch module first.
- **Analysis cost.** Every use re-runs the function. Heavy type functions in a large codebase make Studio's script analysis lag (rule of thumb).
- **Sharing across modules.** Whether user-defined type functions can be exported from a module and used from another could not be confirmed against current documentation for this note. If you need to share one, test `export type function` in your Studio, and fall back to exporting the resulting type aliases instead.

---

## 7. When not to be clever

Advanced types are a cost paid by every reader. A rough budget (rule of thumb):

| Code | Typing level |
|---|---|
| Shared libraries used by many systems (signals, pools, codecs, validators) | Full generics, careful public types |
| Network boundary modules | `unknown` in, validators, precise types out |
| Game systems (combat, shop, quests) | Plain annotations, tagged unions, few generics |
| One-off scripts, tools, command bar code | `--!nonstrict` or minimal annotations |

Signs you went too far: a type alias needs a comment longer than the function it types; the team writes `:: any` to get past your types; type errors cite type function names nobody remembers writing. Simplify, even if that means a slightly wider type.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| "Type is too wide" after filling an empty table | Unannotated `{}` literal | Annotate at creation |
| `{ Sword }` rejected where `{ Item }` expected | Mutable containers are invariant | Generic parameter plus projection, or read-only contract |
| Generic result is `unknown` | Nothing to infer `T` from | Annotate the argument, or pass an explicit typed value |
| Union not narrowing | Discriminant compared through a helper | Compare `e.kind` inline |
| New union case compiles but is unhandled | No exhaustiveness check | `local _: never = e` in the final branch |
| Validator accepts what the type rejects | Type written separately from the check | Derive the type from `Check<T>` combinators |
| Type function errors everywhere | One bug in the function | Test it in isolation; keep it small |

## Checklist

- [ ] Empty tables that will be filled are annotated at creation.
- [ ] Generic helpers take capabilities (callbacks) instead of needing bounds.
- [ ] Generic containers have a public method type and a private field type, with one audited cast.
- [ ] Tagged unions use one discriminant name and end with a `never` check.
- [ ] Every network and storage boundary turns `unknown` into typed values through validators.
- [ ] Type functions are few, small, tested, and only used where they remove real duplication.
- [ ] You know which solver your Studio is running, and surprising errors are checked against it.

## See also

[[Advanced Luau Start Here]], [[Luau Type System and Strict Mode]], [[Metatables and OOP - When and When Not]], [[Server Authority and Validation]], [[Building a Signal Library]], [[Module Design and Dependency Injection]], [[Serialization Formats for Saves and Networking]], [[Status Effects Buffs and Stacking Rules]], [[Global State and Live Config]]

## Connected notes
<!-- auto-links:start -->
[[Links - Luau language]] · [[Tables Metatables and OOP]] · [[Dependency Injection in Luau]] · [[Functions Closures and Upvalues]] · [[Luau Performance and Native Codegen]] · [[Testing Your Own Remotes - Fuzzing and Abuse Tests]]
<!-- auto-links:end -->
