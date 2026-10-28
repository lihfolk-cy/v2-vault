---
tags: [luau, scripting, language, fundamentals, syntax]
---
# Luau Language Essentials

<!-- tldr:start -->
> [!tldr] TL;DR
> - `attempt to call a nil value (global 'x')` on a rare path: Local function used above its declaration -> Reorder or forward-declare; run a use-before-definition scan
> - Script refuses to compile after adding one line: 200 active locals in the main chunk -> Split into modules; group in tables; wrap new code in a function
> - `if count then` always true: `0` is truthy -> Compare explicitly
> - Every file starts with `--!strict` (new code) or at least `--!nonstrict`.
> - No globals except intentional `_G`/`shared` (and prefer neither).
> - No deprecated `wait`/`spawn`/`delay`/`tick`.
>
> Cost: TL;DR ~190 tok · whole note ~4.1k tok. Read more: ## 2. Variables and scope · ## 3. Compiler limits that big scripts hit · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Luau is the language every Roblox script is written in. It started as Lua 5.1 and has grown into its own language: gradual types, a faster VM, native code generation, new syntax (compound assignment, `continue`, if-expressions, string interpolation, generalized iteration, floor division, `const`), new libraries (`buffer`, `vector`, extended `math`, `table` and `string`), and a sandbox that removes file and OS access. This note is the language foundation the rest of the section builds on. It covers values, scope, operators, control flow and the compiler limits that bite big codebases, with the cases where Lua habits or "obvious" answers are wrong.

Source labels: **Docs** = luau.org or the Roblox Creator Hub; **Measured** = observed in the reference project (one production game); **Rule of thumb** = experience.

---

## 1. Values and types

Luau has a small set of runtime types. `type(x)` returns the Luau type; `typeof(x)` (a Roblox and Luau global) also knows Roblox datatypes and returns names like `"Instance"`, `"Vector3"`, `"CFrame"`, `"EnumItem"`.

| Type | Notes |
|---|---|
| `nil` | Absence of a value. Assigning `nil` to a table key removes the key. |
| `boolean` | `true` / `false`. Only `nil` and `false` are falsy. `0`, `""` and `{}` are truthy. |
| `number` | Always a 64-bit IEEE double. Integers are exact up to 2^53 (9,007,199,254,740,992). |
| `string` | Immutable byte strings. `#s` is the byte count, not the character count. |
| `table` | The only built-in data structure: arrays, dictionaries, objects, sets. |
| `function` | First-class values with closures. See [[Functions Closures and Upvalues]]. |
| `thread` | Coroutines. See [[Task Library Coroutines and Yielding]]. |
| `buffer` | Fixed-size mutable byte block. See [[Buffers and Binary Data]]. |
| `vector` | Native 3-component float vector. In Roblox this is the `Vector3` type. See [[Math Vectors and CFrames]]. |
| `userdata` | Engine objects: Instances, CFrames, Color3s, EnumItems and so on. |

```lua
print(type(workspace))          --> userdata
print(typeof(workspace))        --> Instance
print(typeof(Vector3.zero))     --> Vector3
print(type(buffer.create(4)))   --> buffer
```

**Nuance: truthiness.** Coming from JavaScript or Python, people write `if count then` meaning "if count is non-zero". In Luau `0` is truthy, so that branch always runs once `count` is set. Compare explicitly: `if count > 0 then`.

**Nuance: number precision.** Everything is a double. `0.1 + 0.2 == 0.3` is `false`. Currency in a simulator can pass 2^53 if you multiply without care; above that, adding 1 does nothing. If a game's numbers can grow past roughly 10^15, store them as mantissa/exponent pairs or use a big-number module, and display with suffixes (see [[Strings Patterns and Formatting]]).

---

## 2. Variables and scope

```lua
local speed = 16          -- local: lexically scoped, fast (a VM register)
const MAX_SPEED = 32      -- const binding: cannot be reassigned (Docs)
gravity = 196.2           -- global: avoid; slower, leaks across the script, hides typos
```

- **`local`** variables live from the line after their declaration to the end of their block (`do ... end`, function body, loop body, `then` branch).
- **`const`** (documented on luau.org and the Creator Hub as of October 2026) is like `local` but forbids reassignment, including `+=`. It makes the *binding* immutable, not the value: a `const` table can still be mutated. Use `table.freeze` to protect contents. `const` is contextual, so old code that uses `const` as a variable name still works. `const function f() end` also exists.
- **Globals** are fields of the script's environment. In Roblox each script has its own environment, so a global in one script is invisible to others. `_G` and `shared` are tables shared between scripts on the same side (server or client); prefer ModuleScripts ([[Module Scripts and Requiring]]).

```lua
local x = 1
do
	local x = 2   -- shadows the outer x inside this block (lint: LocalShadow)
	print(x)      --> 2
end
print(x)          --> 1
```

### Use before definition: the silent nil

This is the most expensive scoping bug in large Roblox scripts. A `local` is only visible **after** its declaration. If code above it refers to the same name, the compiler treats that name as a **global**, which is `nil` at runtime.

```lua
local function onHit(target)
	applyDamage(target, 10)  -- compiles as the GLOBAL applyDamage
end

local function applyDamage(target, amount)  -- a new local, declared too late
	-- ...
end

onHit(workspace.Dummy)
--> error: attempt to call a nil value (global 'applyDamage')
```

It compiles fine. It only fails when that path runs, which may be a rare branch (a boss phase, a purchase, a tutorial step). Fixes:

```lua
-- 1. Order definitions so callees come first (simplest).
-- 2. Forward-declare for mutual recursion:
local applyDamage: (target: Instance, amount: number) -> ()

local function onHit(target: Instance)
	applyDamage(target, 10)  -- now refers to the local upvalue
end

applyDamage = function(target: Instance, amount: number)  -- assign, do NOT write "local function"
	-- ...
end
```

Writing `local function applyDamage` in the second half re-declares a **new** local, and `onHit` still sees the first (unassigned) one: the call fails with "attempt to call a nil value (upvalue 'applyDamage')". See [[Luau Type System and Strict Mode]] for the typed forward-declaration pattern.

**Detection.** Studio's Script Analysis shows `UnknownGlobal` warnings (lint 1, Docs) for names that are neither built-in nor assigned anywhere. That catches most cases, but not when the same name is *also* assigned as a global somewhere, and nobody reads a few hundred warnings in a legacy codebase. `--!strict` turns most of these into hard type errors.

**Reference project.** The team made "no use-before-definition issues" a gate before saving any script: a small scanner module parses the source and reports every identifier read before its local declaration in the same or an enclosing scope. In a static sweep of 1,084 scripts, it (plus compile checks) found a UI module whose builder returned undefined globals, alongside other real crash paths (Measured). The rule that stuck: **compile + use-before-definition scan + source-size check before every save**. See [[Error Handling and Retries]] for the pre-flight checklist.

---

## 3. Compiler limits that big scripts hit

Luau compiles each function to bytecode with fixed-size register files. These limits come from the Luau compiler and bytecode format (Docs: luau-lang source, `Bytecode.h` says registers 0-254, upvalues 0-199):

| Limit | Value | Error text |
|---|---|---|
| Active locals in one function (including the main chunk) | **200** | `Out of local registers when trying to allocate <name>: exceeded limit 200` |
| Registers in one function | **255** | `Out of registers when trying to allocate N registers: exceeded limit 255` |
| Upvalues captured by one closure | **200** | `Out of upvalue registers when trying to allocate <name>: exceeded limit 200` |
| Constants / instructions / jump distance | large | `Exceeded constant limit`, `Exceeded function instruction limit; split the function into parts` |

**The 200-local wall.** The limit counts locals alive at the same time, so it bites the top level of long controller scripts: every service, every `local function`, every cached UI element adds one. In the reference project a tutorial controller sat exactly at 200 top-level locals; adding one more line `local skipButton = ...` failed to compile (Measured). Another controller had 13 locals of headroom, the main combat service 19.

Ways out, in order of preference:

1. **Split the script** into ModuleScripts by responsibility. This also helps the source-size limit ([[Module Scripts and Requiring]]).
2. **Group related values in a table**: `local UI = { frame = ..., title = ..., closeButton = ... }`. One local instead of twenty. Field access is slightly slower than a register but irrelevant outside hot loops.
3. **Scope helpers** inside `do ... end` blocks or inside the function that uses them, so they stop counting once the block ends.
4. **Inline function** for a new feature: build it inside one `local function buildSkipButton()` whose own locals do not count against the top level (this is what the reference project did).

A related limit is the size of a script's `Source`: 200,000 characters (Measured; see [[Script Types and Run Context]]).

---

## 4. Operators

| Operator | Meaning | Gotcha |
|---|---|---|
| `+ - * / ^ %` | Arithmetic | `%` takes the sign of the divisor: `-7 % 3 == 2`. `math.fmod(-7, 3) == -1`. |
| `//` | Floor division (Docs) | `7 // 2 == 3`, `-7 // 2 == -4`. Works per component on vectors. `__idiv` metamethod. |
| `..` | Concatenation | Numbers concatenate (`1 .. 2` needs spaces). `nil` errors: guard with `tostring`. |
| `== ~=` | Equality | Different types are never equal. Tables compare by reference. |
| `< <= > >=` | Ordering | Number vs string errors (`attempt to compare number < string`). |
| `and or not` | Logic | Return operands, not booleans: `nil or 5 == 5`. |
| `#` | Length | Strings: bytes. Tables: a border of the array part (undefined with holes). |

Compound assignment (Docs): `+= -= *= /= //= %= ^= ..=`. They are statements, not expressions, and the left side is evaluated once:

```lua
counts[getKey()] += 1   -- getKey() is called once
```

**`a and b or c` is not a ternary.** If `b` is `false` or `nil`, you get `c`. Luau has real if-expressions (Docs):

```lua
local label = if isOwned then "Equip" elseif price == 0 then "Free" else `{price} R$`
local enabled = if config.Enabled ~= nil then config.Enabled else true  -- correct for false
```

`else` is mandatory and there is no `end`. Lint `MisleadingAndOr` flags the risky `and/or` form.

---

## 5. Control flow

```lua
-- Numeric for: bounds evaluated once; the loop variable is a fresh local each iteration
for i = 1, 10 do end
for i = 10, 1, -1 do end
for t = 0, 1, 0.1 do end          -- float steps accumulate error; may stop at 0.9999

-- Generalized iteration (Docs): no pairs/ipairs needed
for key, value in inventory do end

-- Explicit forms still exist
for i, v in ipairs(list) do end   -- stops at the first nil
for k, v in pairs(dict) do end

while alive do task.wait(1) end
repeat attempts += 1 until ok or attempts >= 5   -- locals in the body are visible in the until condition

for _, part in parts do
	if not part:IsA("BasePart") then
		continue              -- Luau addition; must be the last statement in its block
	end
	part.Anchored = true
end
```

**Generalized iteration order.** Docs: the array part `1..#t` is visited in order, then the rest in unspecified order. Never rely on dictionary order for gameplay (reward rolls, UI order). Sort keys first.

**Modifying a table while iterating.** Assigning to the *current* key (including setting it to `nil`) is allowed. Adding new keys during traversal is undefined. Collect first, mutate after.

**`goto` does not exist** in Luau (Docs: compatibility page). Use `continue`, early `return`, or a helper function. **Proper tail calls are not supported** either (Docs), so deep "tail-recursive" functions still grow the stack; convert them to loops.

---

## 6. Strings and interpolation

Three literal styles plus backticks:

```lua
local a = "double"
local b = 'single'
local c = [[long
string, no escapes]]
local name, coins = "Ava", 1250
print(`{name} has {coins} coins`)                   -- interpolation (Docs)
print(`Next level in {math.ceil(remaining)}s`)      -- any expression inside {}
print(`literal brace: \{ and backtick: \``)
```

Escapes include `\n`, `\t`, `\x41`, `\u{1F600}` (braces mandatory) and `\z` (skip following whitespace). Interpolation rules (Docs): `{{` is a parse error; backtick strings cannot be used as type annotations; a function call with a backtick argument needs parentheses, `print(`x`)`, not `` print`x` ``. More in [[Strings Patterns and Formatting]].

Number literals: `0xFF`, `0b1010`, `1_000_000` (digit separators), `1e6`.

---

## 7. Functions, varargs and multiple returns (short version)

```lua
local function stats(...: number): (number, number)
	local n = select("#", ...)       -- counts nils too
	local sum = 0
	for _, v in { ... } do sum += v end
	return sum, if n > 0 then sum / n else 0
end

local total, mean = stats(1, 2, 3)
local onlyTotal = stats(1, 2, 3)      -- extra returns are dropped
local t = { stats(1, 2), "end" }      -- a call not in last position is truncated to 1 value
```

Full treatment: [[Functions Closures and Upvalues]].

---

## 8. The sandbox: what is missing compared to Lua

Docs (luau.org compatibility): `io`, `package` and most of `debug` are removed; `os` is restricted to `os.clock`, `os.date`, `os.difftime`, `os.time`; `loadfile`/`dofile` are gone; there is no `__gc` metamethod; `goto` and tail calls are unsupported; `pcall`/`xpcall` are yieldable but metamethods are not.

Roblox-specific:
- `loadstring` exists but only works on the server when `ServerScriptService.LoadStringEnabled` is on. Using `loadstring`, `getfenv` or `setfenv` marks the environment impure and **disables import optimizations** (Docs: luau.org performance). Do not ship them in hot code.
- Deprecated globals: `wait`, `spawn`, `delay` (use `task.wait`, `task.spawn`, `task.delay`), `tick` (use `os.clock` for durations, `os.time` or `DateTime` for wall time), `ypcall`, `elapsedTime`, `version`, `printidentity`. Lint `DeprecatedGlobal` flags them.
- `warn(...)` prints a yellow warning; `print` is plain. Both are visible in the Developer Console in live servers ([[Developer Console and Stats]]).

---

## 9. Comment directives

The first lines of a script can set modes (Docs):

```lua
--!strict              -- full type checking (see the type system note)
--!native              -- compile functions to machine code where profitable
--!nolint LocalShadow  -- silence one lint for this file
--!nonstrict           -- (one mode directive per file: strict, nonstrict or nocheck)
```

Directives must appear before any code. Lint `CommentDirective` warns on unknown directives. Native codegen is covered in [[Luau Performance and Native Codegen]].

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| `attempt to call a nil value (global 'x')` on a rare path | Local function used above its declaration | Reorder or forward-declare; run a use-before-definition scan |
| Script refuses to compile after adding one line | 200 active locals in the main chunk | Split into modules; group in tables; wrap new code in a function |
| `if count then` always true | `0` is truthy | Compare explicitly |
| `cond and false or true` returns `true` | `and/or` is not a ternary | `if cond then false else true` |
| Gameplay order differs between servers | Iterating a dictionary | Sort keys |
| Loop `for t = 0, 1, 0.1` misses the last step | Float accumulation | Iterate integers and divide |
| `x .. y` errors | `nil` operand | `tostring(x)` or interpolation |
| Typos create silent globals | Assigning to an undeclared name | `--!strict`, read `UnknownGlobal` warnings |

## Checklist

- [ ] Every file starts with `--!strict` (new code) or at least `--!nonstrict`.
- [ ] No globals except intentional `_G`/`shared` (and prefer neither).
- [ ] No deprecated `wait`/`spawn`/`delay`/`tick`.
- [ ] Before saving a large script: it compiles, has no use-before-definition reads, has local headroom, and its Source is well under 200,000 characters.
- [ ] Conditions compare explicitly against numbers and strings.
- [ ] No reliance on dictionary iteration order.

## See also

[[Luau Type System and Strict Mode]] · [[Tables Metatables and OOP]] · [[Functions Closures and Upvalues]] · [[Task Library Coroutines and Yielding]] · [[Module Scripts and Requiring]] · [[Script Types and Run Context]] · [[Strings Patterns and Formatting]] · [[Math Vectors and CFrames]] · [[Luau Performance and Native Codegen]] · [[Error Handling and Retries]] · [[Command Bar and Studio Scripting]] · [[External Tooling - Rojo Wally Selene StyLua]]

## Connected notes
<!-- auto-links:start -->
[[Links - Luau language]] · [[Luau Performance Patterns with Benchmarks]] · [[Luau Garbage Collection and the Memory Model]] · [[AI Code Assistants for Luau]] · [[Testing Strategies and Frameworks]] · [[Cookbook - Tables Strings and Time]]
<!-- auto-links:end -->
