---
tags: [luau, modulescript, require, architecture, caching, type/guide, area/scripting, level/intermediate, api/Script]
---
# Module Scripts and Requiring

<!-- tldr:start -->
> [!tldr] TL;DR
> - Edits to a module have no effect in a test: Cached require in the same VM or a separate command-bar VM -> Clone-require; restart the test
> - Server and client "share" a module table but values differ: Each side runs its own copy -> Use remotes or attributes
> - Boot hangs on the client: Module top level yields on a missing instance -> No yields at load; `start()` phase
> - One entry Script per side; modules with `init`/`start`.
> - No yields at module top level.
> - No cycles; shared dependencies extracted.
>
> Cost: TL;DR ~170 tok · whole note ~3.6k tok. Read more: ## 2. Caching: once per VM · ## 7. The Source size limit and splitting modules · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A `ModuleScript` is code that runs when something calls `require` on it and returns exactly one value, usually a table of functions. Modules are how Roblox code is shared and organized: one entry script per side requires a tree of modules. This note explains the caching rules (once per Luau VM, which is not "once per game"), require by instance and by string path, cyclic requires, yielding in modules, initialization order, the 200,000-character Source limit and how to split large modules safely, and how to test edits when `require` hands you a cached copy.

---

## 1. Basics

```lua
--!strict
-- ReplicatedStorage/Shared/MathUtil (ModuleScript)
local MathUtil = {}

function MathUtil.round(x: number, step: number): number
	return math.round(x / step) * step
end

return MathUtil
```

```lua
-- Any script on either side
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
print(MathUtil.round(7.3, 0.5))  --> 7.5
```

The return value can be any value except `nil` (Docs). Returning nothing errors when required ("Module code did not return exactly one value").

---

## 2. Caching: once per VM

Docs: modules "run once and only once per Luau environment and return the exact same value for subsequent calls". What counts as one environment:

| Context | Gets its own copy of every module |
|---|---|
| The server | Yes (one shared by all server Scripts) |
| Each client | Yes (one shared by all LocalScripts and client Scripts on that client) |
| Each **Actor** | Yes: "Each Actor runs in its own Luau VM... module-level state is isolated per Actor" (Docs) |
| Studio Command Bar / plugins | Yes: separate from the running game's scripts |

Consequences:
- A module in `ReplicatedStorage` required by the server and by a client runs **twice**, once per side, with independent state. Module tables are not a client-server channel.
- Module-level state is a singleton **within its VM**. A `Cache = {}` at the top of a module is shared by every server script that requires it. That is a feature (shared services) and a trap (accidental shared mutable state).
- Actors do not see the main VM's module state. A "global registry" module required inside Actors is a different registry per Actor ([[Parallel Luau and Actors]]).

### Testing edits: require returns the stale copy

Because of caching, requiring an edited module again in the same VM returns the old value; the new source never runs. And the command bar has its own VM, so requiring a game module there does not touch the module instance your running server uses. In the reference project this repeatedly produced confusing results: runtime overrides applied from the command bar did not affect live services, and freshly edited config modules looked unchanged (Measured).

Two techniques the reference project made standard:

```lua
-- 1. Clone-require: a clone is a different ModuleScript, so it runs fresh.
local function freshRequire(module: ModuleScript): any
	local clone = module:Clone()
	clone.Parent = module.Parent          -- keep script.Parent-relative requires working
	local ok, result = pcall(require, clone)
	clone:Destroy()
	if not ok then error(result, 2) end
	return result
end
```

```lua
-- 2. For pure-logic modules without children, compile the source directly (server/Studio only;
--    loadstring must be enabled). Modules that use `script` or children need clone-require instead.
```

Clone-require was also used to prove a refactor safe: require the old and new module side by side and deep-compare the results (zero differences before saving). Never use these tricks in shipped game code; they exist for tooling and tests ([[Command Bar and Studio Scripting]], [[Testing Strategies and Frameworks]]).

---

## 3. Require by instance, string path, or asset ID

```lua
local A = require(script.Parent.Utils)              -- by instance (classic)
local B = require("./Utils")                        -- require-by-string (Docs)
local C = require("../Shared/Types")
local D = require("@self/Child")                     -- relative to this script itself
local E = require("@game/ReplicatedStorage/Shared/Net")
```

Require-by-string rules (Docs): `./` starts at `script.Parent`, `../` at `script.Parent.Parent`, `@self/` at `script`, `@game/` at `game`; each component is a child name; `..` goes up. It is **non-blocking**: if the target does not exist yet, the call errors instead of waiting. On the client, where replicated modules may not have arrived, wait for the folder first or use instance requires with `WaitForChild`.

String paths read like file systems and work well with Rojo-style projects ([[External Tooling - Rojo Wally Selene StyLua]]). They break silently on renames just like instance paths; the type checker resolves them, so strict mode catches many path typos.

Asset-ID require (`require(1234567)`) loads a public `MainModule` asset, **server only** (Docs). It runs third-party code with full server access; treat it like any untrusted dependency ([[Creator Store and Toolbox Safety]]).

---

## 4. Cyclic requires

If A requires B and B requires A during loading, the docs disagree on the symptom: the ModuleScript reference says the thread hangs forever without an error, while the module guide says it errors with `Requested module was required recursively` (Docs, both pages as of October 2026). Either way it is a bug. Fixes:

1. **Extract the shared part** into a third module C that both require.
2. **Late require**: require inside the function that needs it, not at the top. By the time the function runs, both modules have loaded.

```lua
local Combat = {}

function Combat.kill(target: Model)
	local Loot = require(script.Parent.Loot)   -- resolved at call time, after both modules loaded
	Loot.drop(target)
end

return Combat
```

3. **Dependency injection / init phase**: modules expose `init(deps)` and the entry script wires them after all are required.

---

## 5. Do not yield at module load

A require blocks the requiring thread until the module returns. If module top-level code yields (`WaitForChild`, DataStore calls, `task.wait`), every script that requires it waits too, and on the client one missing instance can stall the whole boot. Rules:
- Module top level: define functions and constants only.
- Put side effects in an explicit `start()` or `init()` called by the entry script. Roblox's own recommendation is a single client Script and a single server Script that require modules and call `start()` (Docs: script locations).

```lua
--!strict
-- ServerScriptService/Main (Script, RunContext Server)
local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Services

local order = { "PlayerData", "Economy", "Combat", "Quests" }   -- explicit, documented order
local loaded = {}

for _, name in order do
	loaded[name] = require(Services:FindFirstChild(name) :: ModuleScript)
end
for _, name in order do
	local svc = loaded[name]
	if svc.init then svc.init(loaded) end   -- wire dependencies, no yielding
end
for _, name in order do
	local svc = loaded[name]
	if svc.start then task.spawn(svc.start) end   -- may yield; isolated so one failure does not block others
end
```

See [[Project Structure and Bootstrapping]] and [[Frameworks - Knit Matter and Others]].

---

## 6. Module patterns

| Pattern | Shape | Use |
|---|---|---|
| Utility | Table of pure functions | Math, formatting, validation |
| Service / singleton | Table with state and `init/start` | Economy, data, combat on the server |
| Class | Table with `new` and methods | Per-object behaviour ([[Tables Metatables and OOP]]) |
| Config | Frozen data table | Items, prices, zones |
| Types | `export type` only, returns `{}` | Shared payload/profile types |
| Function | Returns one function | Small single-purpose helpers |

**Config modules grow.** Item lists, zone ladders and product catalogues balloon over a game's life. Keep data separate from logic, freeze it (`table.freeze`, see [[Tables Metatables and OOP]]), and split by domain before it gets large.

---

## 7. The Source size limit and splitting modules

A script's `Source` is capped at **200,000 characters** (Measured in the reference project; assigning a larger Source fails with "Unable to assign property Source", and the script cannot be saved with edits). It is easy to reach with config tables and generated data. In the reference project, the main config module reached 201,360 characters and a UI theme module 201,561, at which point **no edit to either was possible**; another combat service sat at about 199,600 and was frozen by team rule (Measured).

How they were split without changing behaviour:
1. Move whole, self-contained blocks **verbatim** into a child ModuleScript (for example `Config.Tables`): products, zones, item descriptions. The parent assigns each at its old line: `C.Products = require(script:WaitForChild("Tables")).Products`, so evaluation order and every reader stay unchanged.
2. For logic blocks that used parent locals, pass those values in as arguments at the same load point (43 values in the theme case), only after checking none is reassigned later ([[Functions Closures and Upvalues]]).
3. Verify: clone-require old and new, deep-compare the returned tables (0 differences), run the rendering functions on cloned UI and compare trees, run the use-before-definition scan.
Result: 201,360 to 177,570 characters, and 201,561 to 175,109.

Guidelines:
- Keep modules well under the cap (rule of thumb: alarm at 150,000). Long files also hit the 200-local limit ([[Luau Language Essentials]]).
- Large static data belongs in child modules, attributes or assets, not in the logic file.
- Do not test split modules by compiling their Source in isolation if they reference `script` or children; clone-require them.

---

## 8. Security and replication

- Modules in `ReplicatedStorage` or `ReplicatedFirst` are **downloaded by clients**: exploiters can read them. Server-only logic and secrets go in `ServerScriptService` or `ServerStorage`.
- A module's code runs with the privileges of the side requiring it. Requiring a shared module from the client cannot touch server state.
- Server-only modules required from the client simply do not exist there (`ServerScriptService` does not replicate).

---

## 9. A typed service module template

```lua
--!strict
-- ServerScriptService/Services/Economy
local Players = game:GetService("Players")

export type Deps = {
	PlayerData: {
		get: (player: Player) -> { coins: number }?,
	},
}

local Economy = {}

local deps: Deps? = nil
local changed = Instance.new("BindableEvent")   -- or a pure-Luau signal
Economy.CoinsChanged = changed.Event

function Economy.init(d: Deps)
	deps = d
end

function Economy.start()
	Players.PlayerRemoving:Connect(function(player)
		-- per-player cleanup for state this module owns
	end)
end

function Economy.add(player: Player, amount: number): boolean
	assert(deps, "Economy.init was not called")
	assert(amount == amount and amount >= 0 and amount < 1e12, "invalid amount")
	local data = deps.PlayerData.get(player)
	if not data then return false end
	data.coins += amount
	changed:Fire(player, data.coins)
	return true
end

return Economy
```

Characteristics: no work at require time; dependencies injected in `init` (no hidden requires that could form cycles); background work in `start`; public functions validate their inputs with `assert` because only trusted server code calls them (remote input is validated earlier at the boundary); state owned by the module is cleaned per player.

### Module granularity

Rule of thumb: one module per system or concept, typically 100 to 1,500 lines. Many tiny modules make navigation and startup ordering harder; a few giant modules hit the local, upvalue and Source limits and merge-conflict constantly in team work ([[Team Create and Collaboration]], [[Git and Source Control for Roblox]]). Split when a file mixes unrelated responsibilities, not when it reaches a line count.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Edits to a module have no effect in a test | Cached require in the same VM or a separate command-bar VM | Clone-require; restart the test |
| Server and client "share" a module table but values differ | Each side runs its own copy | Use remotes or attributes |
| Boot hangs on the client | Module top level yields on a missing instance | No yields at load; `start()` phase |
| Hang or "required recursively" | Cyclic require | Extract shared module; late require; init phase |
| "Unable to assign property Source" | 200,000-character cap | Split into child modules |
| Exploiters read your anti-cheat thresholds | Server logic placed in ReplicatedStorage | Move to ServerScriptService |
| State bleeds between Actors unexpectedly (or does not) | Each Actor has its own module copies | SharedTable or messaging |

## Checklist

- [ ] One entry Script per side; modules with `init`/`start`.
- [ ] No yields at module top level.
- [ ] No cycles; shared dependencies extracted.
- [ ] Modules under ~150,000 characters; data split from logic.
- [ ] Server-only code outside replicated containers.
- [ ] Tests and tools clone-require edited modules.

## See also

[[Script Types and Run Context]] · [[Project Structure and Bootstrapping]] · [[Frameworks - Knit Matter and Others]] · [[Luau Language Essentials]] · [[Parallel Luau and Actors]] · [[Packages and Asset Reuse]] · [[Command Bar and Studio Scripting]] · [[Studio Tooling Architecture]]

## Connected notes
<!-- auto-links:start -->
[[Module Design and Dependency Injection]] · Dependency Injection in Luau · Links - Script types · Advanced Luau Start Here · MCP Workflows for Scripting and Debugging · Links - OOP and module design
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Dependency Injection in Luau]] · [[Luau Type System and Strict Mode]] · [[Metatables and OOP - When and When Not]] · [[Events Signals and Connections]] · [[Error Handling - pcall xpcall and Promise Patterns]] · [[Luau Performance and Native Codegen]] · [[CollectionService Patterns]] · [[Task Library Coroutines and Yielding]] · [[Error Handling and Retries]]
<!-- related:end -->
