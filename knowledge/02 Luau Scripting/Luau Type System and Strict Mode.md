---
tags: [luau, types, strict-mode, type-checking, generics]
---
# Luau Type System and Strict Mode

Luau has a gradual, structural type system. Types are checked by Studio's analyzer (and by external tools such as luau-lsp) **while you edit**; at runtime they are erased and do nothing, except that native code generation uses argument annotations as optimization hints ([[Luau Performance and Native Codegen]]). The value of types is catching the bug classes that dominate Roblox error logs: indexing `nil`, wrong payload shapes, typo'd properties, and calling functions that do not exist yet.

This note covers the modes, the two solvers, the syntax you use daily, refinements, generics, OOP typing, type functions, and the patterns that make `--!strict` pleasant rather than a fight. The playbook sections follow a strict-typing house style used in production Roblox codebases.

---

## 1. Modes

Set on the first line of a script (Docs):

| Directive | Behaviour |
|---|---|
| `--!nocheck` | No type checking. Use only for generated code. |
| `--!nonstrict` | Unannotated values that cannot be inferred early become `any`, so few errors are reported. The default for files without a directive. |
| `--!strict` | Types are tracked across statements; mismatches, possible `nil` access and unknown members are errors. |

`Workspace.LuauTypeCheckMode` sets the default mode for files without a directive (Docs). Errors appear as squiggles and in the Script Analysis window; they never stop a script from running. That is both a strength (gradual adoption) and a trap: strict errors are easy to ignore unless your team treats them as build failures (CI with luau-lsp or `luau-analyze`, see [[External Tooling - Rojo Wally Selene StyLua]]).

### Old solver vs new solver (as of October 2026)

Luau has two type inference engines. The **New Type Solver** (based on semantic subtyping) moved to general release in November 2025. Per the Roblox DevForum announcement it was rolled out by default to people **not** using strict mode; strict-mode users were not migrated automatically, and the Studio Beta toggle was removed on 7 January 2026. Each place can opt in or out with `Workspace.UseNewLuauTypeSolver` (a `RolloutState`; `Default` follows the engine-wide rollout) (Docs).

Practical consequences:
- Some features exist **only in the new solver**: user-defined type functions, `read`/`write` property modifiers, better refinement of complex conditions, and builtin type functions like `keyof` and `index`.
- Switching a large strict codebase to the new solver can surface many new errors (some real, some solver differences), and error messages may be longer. Do it on a branch, fix real bugs first.
- Everyone on a team should use the same solver, otherwise one person's clean file is another's red file. The Workspace property exists for that reason.

---

## 2. Annotations: the daily syntax

```lua
--!strict
local Players = game:GetService("Players")

local health: number = 100
local nickname: string? = nil                  -- optional = string | nil
local owner: Player? = Players:GetPlayers()[1]
local material: Enum.Material = Enum.Material.Plastic
local tags: { string } = { "Enemy", "Boss" }   -- array shorthand for { [number]: string }
local damageBy: { [Player]: number } = {}       -- dictionary with an indexer

type Rarity = "Common" | "Rare" | "Epic" | "Legendary"   -- singleton (literal) union

export type Item = {
	id: string,
	price: number,
	rarity: Rarity,
	stackable: boolean?,
}

local function priceOf(item: Item, quantity: number): number
	return item.price * quantity
end

local function split(s: string): (string, string?)   -- multiple returns
	local a, b = string.match(s, "^(%w+):?(%w*)$")
	return a or s, if b ~= "" then b else nil
end

type Callback = (player: Player, amount: number) -> ()   -- function type; () means "returns nothing"
type Variadic = (...number) -> number                     -- variadic in a type: ...T, not ...: T
```

Every Roblox class, datatype and enum is a type: `Part`, `BasePart`, `Model`, `Humanoid`, `CFrame`, `Vector3`, `RBXScriptConnection`, `Enum.KeyCode`.

### Special types

| Type | Meaning | Use |
|---|---|---|
| `any` | Opts out of checking in both directions | Interop with untyped code; avoid spreading it |
| `unknown` | Any value, but you must narrow before use | Remote payloads, JSON, attribute values |
| `never` | No value; appears after contradictory refinements | A `never` in a hover tooltip usually means a logic bug |
| `nil` | Only `nil` | Optional is `T?` |

`unknown` is the honest type for anything that crosses a trust boundary. `any` silently lets mistakes through.

---

## 3. Tables: sealed, unsealed and width subtyping

Luau's type system is structural: a table type is its shape, not a name (Docs).

- A table literal assigned to an unannotated local is **unsealed**: you can keep adding fields, and the type grows.
- An annotated table, or a table returned from a function, is **sealed**: adding a field that the type does not mention is an error. Sealed tables are *inexact*, so a table with extra fields can be passed where fewer are expected.

```lua
local config = {}            -- unsealed
config.walkSpeed = 16        -- fine, type becomes { walkSpeed: number }

local typed: { walkSpeed: number } = { walkSpeed = 16 }
typed.jumpPower = 50         -- error: sealed table has no field 'jumpPower'
```

Build incrementally typed tables by declaring the full type up front:

```lua
type Stats = { hp: number, armor: number, crit: number? }
local s: Stats = { hp = 100, armor = 0, crit = nil }
```

### Read-only and write-only properties (new solver)

```lua
type ReadonlyVec = { read x: number, read y: number }
local function length(v: ReadonlyVec): number
	return math.sqrt(v.x * v.x + v.y * v.y)
	-- v.x = 0 would be an error: property is read-only
end
```

This documents intent ("this function will not mutate your table") and makes the type covariant, so `{ x: number }` can flow into `{ read x: number? }`. It is a type-level promise only; use `table.freeze` for runtime protection.

---

## 4. Refinements: narrowing optionals

Strict mode makes you prove a value is not `nil` before you use it. Refinements are the checks the analyzer understands (Docs: truthiness, `type`/`typeof` equality, singleton equality, `not`, `assert`, and combinations with `and`/`or`; plus Roblox's `IsA`).

```lua
--!strict
local function getRoot(character: Model?): BasePart?
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then   -- IsA both checks and narrows to BasePart
		return root
	end
	return nil
end
```

Three idioms from the strict-typing playbook:

```lua
-- 1. Early-return guard (preferred in event handlers)
local humanoid = character:FindFirstChildOfClass("Humanoid")
if not humanoid then return end
humanoid.WalkSpeed = 20         -- humanoid: Humanoid

-- 2. assert when absence is a programmer error, not a runtime possibility
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
assert(remotes, "Remotes folder is created by the server bootstrap")

-- 3. :: cast ONLY with out-of-band certainty
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
```

Rules of thumb:
- Prefer `IsA` over `::` casts: it narrows **and** validates at runtime.
- `WaitForChild(name)` without a timeout returns `Instance`; with a timeout it returns `Instance?`. Handle the `nil`.
- `x :: any :: T` is a smell: if you need it, some type is lying.
- Casts are restricted (Docs): each side must be a subtype of the other, or one side must be `any`. `myNumber :: boolean` is an error.
- Refinement does not survive a yield or a function boundary in your head, even if it does in the checker: after `task.wait()`, the instance you narrowed may have been destroyed. Re-check `instance.Parent` after yields.

---

## 5. Generics

```lua
--!strict
local function map<T, U>(list: { T }, fn: (T) -> U): { U }
	local out: { U } = table.create(#list)
	for i, v in list do
		out[i] = fn(v)
	end
	return out
end

local names = map(game:GetService("Players"):GetPlayers(), function(p) return p.Name end)  -- { string }

type Result<T> = { ok: true, value: T } | { ok: false, err: string }   -- tagged union

local function parseLevel(raw: unknown): Result<number>
	if typeof(raw) == "number" and raw >= 1 and raw % 1 == 0 then
		return { ok = true, value = raw }
	end
	return { ok = false, err = "level must be a positive integer" }
end

local r = parseLevel(5)
if r.ok then
	print(r.value + 1)          -- refined by the singleton field 'ok'
else
	warn(r.err)
end
```

Generic **packs** (`<T...>`) type variadic arguments and returns, for example a typed signal or a `pcall` wrapper:

```lua
type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> () -> (),
	Fire: (self: Signal<T...>, T...) -> (),
}
```

Before reaching for `any`, try: a generic, an indexer (`{ [string]: number }`), a union of string literals, or `unknown` plus narrowing.

---

## 6. Typing modules and OOP

`export type` makes a type visible to requirers: `local Types = require(path); local item: Types.Item`. Put types that cross the client/server boundary (remote payloads, profile schema) in one shared module so both sides agree by construction.

The metatable class idiom, typed (from the strict-typing playbook):

```lua
--!strict
local Cooldown = {}
Cooldown.__index = Cooldown

export type Cooldown = typeof(setmetatable(
	{} :: { duration: number, lastUsed: number },
	Cooldown
))

function Cooldown.new(duration: number): Cooldown
	return setmetatable({ duration = duration, lastUsed = -math.huge }, Cooldown)
end

function Cooldown.ready(self: Cooldown): boolean
	return os.clock() - self.lastUsed >= self.duration
end

function Cooldown.use(self: Cooldown): boolean
	if not self:ready() then
		return false
	end
	self.lastUsed = os.clock()
	return true
end

return Cooldown
```

`typeof(setmetatable(...))` derives the instance type including methods. Annotating `self` explicitly (dot syntax) gives clearer errors than colon syntax with inferred `self`. More patterns in [[Tables Metatables and OOP]].

---

## 7. Forward declarations

`local function a()` cannot see `local function b()` declared later (see [[Luau Language Essentials]] on use-before-definition). In strict mode, declare the variable with its type first, then assign:

```lua
--!strict
local openMenu: (menuId: string) -> ()
local closeMenu: () -> ()

closeMenu = function()
	-- may call openMenu
end

openMenu = function(menuId: string)
	closeMenu()
	-- ...
end
```

Assign with `name = function`, never `local function name`, which creates a new shadowing local and leaves the declared one `nil` (error: "Cannot call non-function" in the checker, "attempt to call a nil value" at runtime).

---

## 8. Typed remotes: both layers, always

Types are compile-time only. They never validate network input. A remote handler must assume the client sent anything:

```lua
--!strict
-- Shared/Types
export type BuyItemRequest = { itemId: string, quantity: number }

-- Server
remote.OnServerEvent:Connect(function(player: Player, payload: unknown)
	if typeof(payload) ~= "table" then return end
	local req = payload :: { [string]: unknown }
	local itemId, quantity = req.itemId, req.quantity
	if typeof(itemId) ~= "string" or #itemId > 64 then return end
	if typeof(quantity) ~= "number" or quantity ~= quantity then return end   -- NaN check
	if quantity < 1 or quantity > 99 or quantity % 1 ~= 0 then return end
	handleBuy(player, itemId, quantity)   -- both narrowed: string, number
end)
```

The annotation documents intent; the validation enforces it. See [[Server Authority and Validation]] and [[RemoteEvents RemoteFunctions and Unreliable Remotes]].

---

## 9. Type functions (new solver)

Type functions run **during analysis** and compute types from types (Docs). Builtins include `keyof<T>` (union of a table type's property names as string singletons) and `index<T, K>`. User-defined ones use `type function` and the `types` library:

```lua
--!strict
type Config = { WalkSpeed: number, JumpPower: number, Name: string }
type ConfigKey = keyof<Config>          -- "WalkSpeed" | "JumpPower" | "Name"

local function setting(key: ConfigKey): number | string
	return CONFIG[key]      -- CONFIG: Config, defined elsewhere; typos in key are now type errors
end

-- User-defined: make every property of a table type optional
type function Partial(t)
	if not t:is("table") then
		error("Partial expects a table type")
	end
	local result = types.newtable()
	for key, prop in t:properties() do
		local read = prop.read
		if read then
			result:setproperty(key, types.optional(read))
		end
	end
	return result
end

type ConfigPatch = Partial<Config>      -- { WalkSpeed: number?, JumpPower: number?, Name: string? }
```

The `types` library (Docs) provides `types.singleton`, `types.unionof`, `types.intersectionof`, `types.optional`, `types.negationof`, `types.newtable`, `types.newfunction`, `types.copy`, `types.generic`, primitives like `types.number`, and methods on type objects (`tag`, `is`, `properties`, `readproperty`, `setproperty`, `indexer`, `components`, ...). Type functions can use a limited runtime environment (`math`, `string`, `table`, `pairs`, `error`, `print` ...) but no Roblox APIs. Keep them small: they slow analysis, and a broken one turns into confusing errors at every use site. Most game code never needs one.

---

## 10. Common strict-mode errors and fixes

| Error | Fix |
|---|---|
| `Type 'Instance' does not have key 'Humanoid'` | You indexed a generic Instance with dot syntax. Use `FindFirstChildOfClass("Humanoid")` and guard. |
| `Value of type 'X?' could be nil` | Guard, `assert`, or restructure so the value is non-optional. Do not sprinkle `::`. |
| `Cannot call non-function` on a forward-declared local | You used `local function name` for the assignment. Use `name = function`. |
| `Key 'x' not found in table` while building a table | Declare the full type up front, or build with a typed constructor. |
| Recursive type errors on self-referencing tables | Name the type first: `type Node = { value: number, next: Node? }`. |
| `never` after narrowing | Two refinements contradict, for example checking `== "string"` on a number branch. Real bug. |
| `Unknown global 'x'` | Typo, or use-before-definition. |
| `Type 'number' could not be converted into 'string'` on concatenation | Use interpolation or `tostring`. |
| Errors in code you did not change after a Studio update | Solver change. Check `UseNewLuauTypeSolver` and pin it for the team. |

## 11. Adoption path for an untyped codebase

1. New files start with `--!strict`; never big-bang a whole repository.
2. Convert shared modules first; types flow outward from them.
3. When converting a file, fix the real bugs the checker reveals before suppressing anything.
4. `--!nonstrict` is the transitional mode; `--!nocheck` is for generated code only.
5. Annotate public functions fully (parameters and returns); let inference handle locals.
6. Add CI type checking so errors cannot accumulate silently.

**When not to fight it.** Highly dynamic code (generic serializers, reflection over Instance properties, metaprogramming) produces type noise disproportionate to the bugs it catches. Isolate it in a small module with a typed facade and `unknown` at the edges.

## Checklist

- [ ] `--!strict` on every new file; team agrees on the solver per place.
- [ ] Remote handlers take `unknown` and narrow; no trust in annotations.
- [ ] `IsA` before `::`; no `:: any ::` chains.
- [ ] Shared `Types` module for cross-boundary data.
- [ ] Classes typed with `typeof(setmetatable(...))`.
- [ ] Forward declarations assign with `name = function`.

## See also

[[Luau Language Essentials]] · [[Tables Metatables and OOP]] · [[Functions Closures and Upvalues]] · [[Module Scripts and Requiring]] · [[Server Authority and Validation]] · [[Project Structure and Bootstrapping]] · [[External Tooling - Rojo Wally Selene StyLua]] · [[Luau Performance and Native Codegen]]

## Nuances and edge cases

1. **Types vanish at runtime.** Annotations are checked by the analyser and erased when the code runs. A function typed `(amount: number)` connected to a remote still receives whatever the client sends. Every remote boundary needs runtime checks (`typeof`, ranges) in addition to types; the types only protect code you call yourself.
2. **Strict mode is per file, and boundaries leak `any`.** A strict module that requires a nonstrict module gets loosely typed values back, and `any` spreads through everything it touches without warnings. Convert shared foundation modules (config, types, utilities) to strict first, so the types flowing into the rest of the code are real.
3. **Solver changes move errors.** The newer type solver accepts some code the old one rejected and rejects some the old one accepted (the existing section on solvers covers the details as of October 2026). A codebase that is clean today can show new warnings after a Studio update. Pin expectations in CI by running the same analyser version the team uses, and treat new warnings after an update as a separate clean-up task, not a blocker.
4. **Instance types are only as good as the paths.** `workspace.Map.Door` is typed as `Instance` or errors in strict mode, because the analyser cannot know the place contents. Casting with `::` silences it but also hides real mistakes when the hierarchy changes. Prefer finding instances by tag or with `FindFirstChildOfClass` plus a runtime check, then narrowing.
5. **Generic-heavy code is hard for teammates.** Advanced generics and type functions can model clever APIs, but a teammate who cannot read the type cannot fix the bug. Keep complex types in a few library modules and simple types in gameplay code.
6. **Performance is not the goal of types, but it can help.** Type annotations can help native code generation make better choices for some numeric code (rule of thumb; see [[Luau Performance and Native Codegen]] and measure). Do not add types for speed alone.
7. **Typed remotes need one shared definition.** Server and client should import the same type for each remote's payload from a shared module. Two hand-written copies drift, and the analyser cannot tell that they disagree across the network.
8. **Adoption cost scales with code size.** Turning on strict mode for a 2,000-line project takes an afternoon; for 100,000 lines it is weeks. Adopt per module, new code strict by default, and track the share of strict files as a simple metric.

The senior trade-off: types catch mistakes before play-testing and document intent, at the cost of time spent satisfying the checker. Use strict where bugs are expensive (data, economy, networking) and accept nonstrict in throwaway prototypes.

## Common mistakes

1. **Trusting typed remote handlers.** Symptom: server errors or exploits from wrong argument types despite "typed" code. Fix: runtime validation at every remote entry.
2. **Casting to silence errors.** Symptom: a renamed child breaks at runtime with no warning. Fix: runtime lookup plus narrowing, not `::` casts on paths.
3. **Strict modules on top of untyped foundations.** Symptom: no warnings anywhere, because everything is `any`. Fix: type the shared modules first.
4. **Separate type copies on client and server.** Symptom: a field renamed on one side only. Fix: one shared types module.
5. **Treating every new warning after an update as urgent.** Symptom: a release blocked by solver changes unrelated to the release. Fix: track and clean up separately.
6. **Overusing `any` in public module APIs.** Symptom: callers lose all checking. Fix: precise exported types, with `unknown` plus narrowing where data truly can be anything.

## Related decisions

- [[Advanced Types - Generics and Type Functions]]: where complex types belong.
- [[Server Authority and Validation]]: runtime checks types cannot replace.
- [[Code Pipeline - Rojo Git and CI]]: running the analyser in CI.
- [[External Tooling - Rojo Wally Selene StyLua]]: linting alongside type checking.
- [[Module Design and Dependency Injection]]: typed module interfaces.
- [[Serialization Formats for Saves and Networking]]: typed payloads across the network.
- [[AI Code Assistants for Luau]]: generated code still needs type review.
- [[Testing Your Own Remotes - Fuzzing and Abuse Tests]]: proving runtime checks exist.

## Connected notes
<!-- auto-links:start -->
[[Advanced Luau Start Here]] · [[Links - Luau language]] · [[Metatables and OOP - When and When Not]] · [[Code Review for Luau Teams]] · [[Testing Strategies and Frameworks]] · [[Dependency Injection in Luau]]
<!-- auto-links:end -->
