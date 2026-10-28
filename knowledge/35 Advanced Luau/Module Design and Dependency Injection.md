---
tags: [luau, advanced-luau, architecture, modules, dependency-injection, testing, lifecycle]
---
# Module Design and Dependency Injection

[[Module Scripts and Requiring]] covers how `require` works: caching per VM, cyclic requires, not yielding at load, module shapes. [[Project Structure and Bootstrapping]] covers where modules live and the two-phase server start. [[Frameworks - Knit Matter and Others]] compares frameworks. This note is about the design question underneath all three: **how a module gets the other modules it needs**, and how to shape a module's public surface so it can be changed, tested and reasoned about. Dependency injection (DI) is the name for passing dependencies in instead of reaching out for them. In Roblox code it is usually a light pattern, not a framework, and it solves three very practical problems: cyclic requires, untestable code, and hidden initialisation order.

---

## 1. The cost of reaching out

The default style in Roblox is that every module requires what it needs at the top:

```lua
local DataService = require(ServerScriptService.Services.DataService)
local Economy = require(ServerScriptService.Services.Economy)
local Analytics = require(ServerScriptService.Services.Analytics)

local Shop = {}

function Shop.buy(player: Player, itemId: string)
	local profile = DataService.get(player)
	if Economy.spend(profile, "Coins", 100) then
		Analytics.log(player, "buy", itemId)
	end
end

return Shop
```

This is fine for small games and remains fine for leaf modules forever. It costs you in four ways as a project grows:

1. **Testing needs the real world.** To test `Shop.buy` you need a real `DataService`, which needs DataStores, which in Studio needs API access and a real player. So nobody tests `Shop`.
2. **Cycles.** `Economy` wants to award achievements, `Achievements` wants to grant coins through `Economy`. Two top-level requires form a cycle, which hangs or errors at load ([[Module Scripts and Requiring]]).
3. **Hidden order.** If `DataService` must be started before `Shop` can run, nothing in `Shop` says so. The order lives in someone's head or in the order of lines in the bootstrap script.
4. **Singletons everywhere.** Each required module is one shared instance per VM. You cannot have two `Economy` instances (one per test, one per sandboxed run) without restructuring.

DI addresses each: dependencies are parameters (testable with fakes), wiring happens once in one place after every module has loaded (no load-time cycles), the wiring code states order explicitly, and constructors can make as many instances as needed.

---

## 2. The spectrum of options

| Style | Shape | Strength | Weakness | Use for |
|---|---|---|---|---|
| Direct require | `require` at top, call functions | Zero ceremony | Hard to test, cycles, hidden order | Utilities, config, pure functions, leaf modules |
| Late require | `require` inside the function that needs it | Breaks load cycles cheaply | Hides the dependency deeper | A quick fix for one cycle |
| Init injection | `Module.init(deps)` called by the bootstrap | Simple, explicit wiring | Module still a singleton | Most game services |
| Constructor injection | `Module.new(deps)` returns an instance | Multiple instances, easiest to test | More plumbing | Systems you test heavily, per-round or per-match objects |
| Service locator | `Registry.get("Economy")` anywhere | Convenient | It is a global bag; dependencies invisible again | Rarely; tooling and debug commands |
| Framework container | Framework resolves services by name or type | Consistency across a team | Framework lock-in, magic | Teams already on a framework |

The recommendation for most Roblox projects (rule of thumb): direct requires for utilities and config, init injection for services, constructor injection for anything with per-instance state or heavy test needs. Avoid the service locator except for debug tooling, because it reintroduces every problem DI was meant to solve while looking like DI.

---

## 3. Depend on a type, not a module

DI pays off fully when the consumer depends on an interface (a type with the functions it needs) rather than a specific module. Luau's structural types make this almost free: any table with matching fields satisfies the type.

```lua
--!strict
-- ShopTypes.lua: what the shop needs, nothing more.
export type Wallet = {
	spend: (self: Wallet, player: Player, currency: string, amount: number) -> boolean,
	grant: (self: Wallet, player: Player, currency: string, amount: number) -> (),
}

export type Catalog = {
	priceOf: (self: Catalog, itemId: string) -> number?,
}

export type Inventory = {
	add: (self: Inventory, player: Player, itemId: string) -> boolean,
}

export type Log = (player: Player, event: string, data: { [string]: any }) -> ()

return {}
```

```lua
--!strict
-- Shop.lua: constructor injection.
local Types = require(script.Parent.ShopTypes)

export type ShopDeps = {
	wallet: Types.Wallet,
	catalog: Types.Catalog,
	inventory: Types.Inventory,
	log: Types.Log,
}

export type Shop = {
	buy: (self: Shop, player: Player, itemId: string) -> (boolean, string?),
}

local Shop = {}
Shop.__index = Shop

function Shop.new(deps: ShopDeps): Shop
	return setmetatable({ deps = deps }, Shop) :: any
end

function Shop.buy(self: any, player: Player, itemId: string): (boolean, string?)
	local deps: ShopDeps = self.deps
	local price = deps.catalog:priceOf(itemId)
	if price == nil then
		return false, "unknown item"
	end
	if not deps.wallet:spend(player, "Coins", price) then
		return false, "not enough coins"
	end
	if not deps.inventory:add(player, itemId) then
		deps.wallet:grant(player, "Coins", price)   -- refund: inventory full or failed
		return false, "inventory full"
	end
	deps.log(player, "shop_buy", { item = itemId, price = price })
	return true, nil
end

return Shop
```

Notice the narrowness. `Shop` does not depend on "the economy service" with its 30 functions; it depends on `spend` and `grant`. A narrow interface is easier to fake, documents exactly what the shop touches, and lets the economy service change everything else freely. This is the interface segregation idea, and it is where most of the design value lives.

### Testing with fakes

```lua
--!strict
local Shop = require(path.to.Shop)

local function fakeWallet(balance: number)
	local w = { balance = balance, spent = 0 }
	function w:spend(_player, _currency, amount)
		if self.balance < amount then return false end
		self.balance -= amount
		self.spent += amount
		return true
	end
	function w:grant(_player, _currency, amount)
		self.balance += amount
	end
	return w
end

local fakePlayer = {} :: any     -- the shop never touches player fields directly

local wallet = fakeWallet(50)
local shop = Shop.new({
	wallet = wallet,
	catalog = { priceOf = function(_, id) return if id == "hat" then 40 else nil end },
	inventory = { add = function() return false end },   -- simulate full inventory
	log = function() end,
})

local ok, err = shop:buy(fakePlayer, "hat")
assert(not ok and err == "inventory full")
assert(wallet.balance == 50, "refund must restore the balance")
```

This test runs in milliseconds, in Edit mode, with no DataStore, and checks a real edge case (the refund path) that is painful to reproduce by hand. That is the core benefit of DI in one example ([[Automated Testing with TestEZ and Jest-Lua]], [[Testing Strategies and Frameworks]]).

---

## 4. Inject the world: time, randomness, engine services

The dependencies people forget to inject are the ones that are not modules:

| Hidden dependency | Why it hurts tests | Inject as |
|---|---|---|
| `os.time()`, `os.clock()`, `workspace:GetServerTimeNow()` | Daily resets, cooldowns and streaks untestable without waiting | `now: () -> number` |
| `math.random`, `Random.new()` | Drop rates untestable; flaky tests | A `Random` object with a fixed seed in tests |
| `DataStoreService` | Needs API access; writes real data | A narrow `Store` type with `get` and `update` |
| `MarketplaceService` | Purchases cannot be simulated | A `Purchases` type |
| `Players` events | Need real joins | Call `onPlayerAdded(fakePlayer)` directly |
| `task.wait`, `task.delay` | Tests wait in real time | A scheduler or clock ([[Custom Schedulers and Coroutine Patterns]]) |

A daily reward module that takes `now` can be tested for the midnight boundary, the 48-hour streak break and the clock-skew case in one test file ([[Daily Rewards System End to End]]). One that calls `os.time()` cannot, and those boundaries are where its bugs live.

Randomness deserves a special note. Inject a `Random` object, not a function, so tests can seed it (`Random.new(42)`) and get the same sequence every run. For drop systems this turns "roughly 1 percent" into an exact, reviewable expectation for a given seed ([[RNG Drops and Luck Systems]]).

---

## 5. Wiring: a tiny container with a dependency graph

Init injection needs one place that creates every service and passes each one its dependencies, in the right order. For a dozen services, a hand-written bootstrap is clearest. Past that, a small container that sorts services by their declared dependencies removes ordering mistakes and reports cycles with a readable path.

```lua
--!strict
-- Container.lua: register factories with named dependencies, start in dependency order.

type Factory = (deps: { [string]: any }) -> any

type Registration = {
	name: string,
	needs: { string },
	factory: Factory,
}

local Container = {}
Container.__index = Container

export type Container = {
	register: (self: Container, name: string, needs: { string }, factory: Factory) -> (),
	build: (self: Container) -> { [string]: any },
}

function Container.new(): Container
	return setmetatable({ regs = {} :: { [string]: Registration }, order = {} :: { string } }, Container) :: any
end

function Container.register(self: any, name: string, needs: { string }, factory: Factory)
	assert(self.regs[name] == nil, `duplicate service {name}`)
	self.regs[name] = { name = name, needs = needs, factory = factory }
	table.insert(self.order, name)   -- registration order, for deterministic builds
end

function Container.build(self: any): { [string]: any }
	local built: { [string]: any } = {}
	local state: { [string]: "visiting" | "done" } = {}
	local stack: { string } = {}

	local function visit(name: string)
		if state[name] == "done" then return end
		if state[name] == "visiting" then
			table.insert(stack, name)
			error("dependency cycle: " .. table.concat(stack, " -> "), 0)
		end
		local reg = self.regs[name]
		if reg == nil then
			error(`unknown service {name} (needed by {stack[#stack] or "root"})`, 0)
		end
		state[name] = "visiting"
		table.insert(stack, name)
		local deps = {}
		for _, dep in reg.needs do
			visit(dep)
			deps[dep] = built[dep]
		end
		table.remove(stack)
		built[name] = reg.factory(table.freeze(deps))
		state[name] = "done"
	end

	for _, name in self.order do
		visit(name)
	end
	return built
end

return Container
```

Bootstrap:

```lua
local c = Container.new()
c:register("clock", {}, function() return { now = function() return os.time() end } end)
c:register("store", {}, function() return ProfileStoreAdapter.new() end)
c:register("wallet", { "store" }, function(d) return Wallet.new(d.store) end)
c:register("catalog", {}, function() return Catalog.new(ItemConfig) end)
c:register("inventory", { "store" }, function(d) return Inventory.new(d.store) end)
c:register("shop", { "wallet", "catalog", "inventory" }, function(d)
	return Shop.new({ wallet = d.wallet, catalog = d.catalog, inventory = d.inventory, log = Analytics.log })
end)

local services = c:build()
-- start phase: connect remotes and player events only after everything is built
```

What this buys you:

- **Order is derived, not maintained.** Add a dependency and the build order adapts.
- **Cycles fail at boot with a path**: `dependency cycle: economy -> achievements -> economy`. That is far better than a hang inside `require`.
- **Each factory sees only what it declared.** `deps` is frozen and contains only the named dependencies, so a service cannot quietly use something it did not declare.

What it does not buy you: types. The container works on `any`, so the factory signature is where you reattach types (`Wallet.new(d.store :: Store)`). Keeping registrations next to typed constructors is enough in practice. Do not try to make the container itself generic over a map of service types; Luau can express it only with heavy casts or type functions, and the result is harder to read than the problem it solves ([[Advanced Types - Generics and Type Functions]]).

### Two phases still apply

Build (construct and wire, no yields, no side effects) then start (connect events, begin loops, handle players already in the server). The container covers the build phase. Constructors must not yield or connect to engine events; if they do, the build order starts to matter at runtime, and the late-joining-player bugs described in [[Project Structure and Bootstrapping]] come back.

### Breaking a real cycle

When the container reports `economy -> achievements -> economy`, the cycle is usually a design smell, not a wiring problem. Options, best first:

1. **Events instead of calls.** `Economy` fires `CoinsEarned`; `Achievements` listens. `Achievements` calls `Economy.grant`. One direction is a call, the other is a signal ([[Building a Signal Library]]).
2. **Extract the shared piece.** Both depend on a third module (`Ledger`) that neither depends on back.
3. **Late binding.** One side receives a function `getEconomy: () -> Economy` that is resolved after build. This is a deliberate, documented escape hatch, not the default.

---

## 6. Designing the module surface

DI is half of module design. The other half is what a module exposes.

**Small public API, everything else local.** Functions not in the returned table are private for real; nothing outside can call them. Prefer `local function` for helpers and return only what consumers need.

**Return frozen tables for config and APIs.** `return table.freeze(Module)` stops other code from monkey-patching your functions at runtime. Monkey-patching is occasionally used for debugging; if you need that, inject instead.

**No side effects at require.** A module that connects to `Players.PlayerAdded` at the top level starts working the moment anything requires it, including a test or a tool. Put that in `start`. This also keeps the module cheap to require from the command bar ([[Command Bar and Studio Scripting]]).

**Do not return mutable state.** `return { players = activePlayers }` lets any consumer edit your internals. Return functions (`getPlayers()`) that return copies or read-only views when consumers need data.

**Stable names, versioned behaviour.** If many systems call `Economy.grant`, changing what it does silently is a breaking change. Add `grantWithReason` rather than changing `grant`'s meaning.

**Client modules are public.** Anything in `ReplicatedStorage` is readable by exploiters. DI does not change that: an injected client module still runs on a machine you do not control. Keep authority and secrets on the server ([[Server Authority and Validation]], [[How Exploits Work - The Client Boundary]]).

---

## 7. Hot reload and the require cache

A side benefit of constructor injection appears when testing edited code from the command bar. The command bar has its own require cache, and requiring an edited ModuleScript returns the stale copy unless you require a clone ([[Module Scripts and Requiring]]). With DI, you can require a fresh clone of one module, construct it with fakes, and exercise it, without restarting anything. With direct requires, the fresh clone still requires the stale copies of its dependencies, and what you test is a mix of old and new code. The reference project's habit of cloning a module and requiring the clone for each check works much better when the module under test takes its dependencies as arguments (rule of thumb from that experience).

---

## When not to do this

- **Small games and game jams.** A dozen modules with direct requires and a bootstrap script are perfectly maintainable.
- **Pure utilities.** A math helper module has no dependencies worth injecting; require it directly everywhere.
- **Config data.** Require frozen config directly. Injecting config tables everywhere adds noise; inject only when tests need different numbers.
- **To look architectural.** If no test or second instance will ever exist, constructor injection is ceremony.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Tests need Play mode and real DataStores | Services reach out for engine services | Inject narrow adapters |
| Daily reward bugs only appear at midnight | `os.time()` called directly | Inject `now` |
| "Requested module was required recursively" or a hang | Top-level require cycle | Container with cycle report, events, or extraction |
| A service uses something it never declared | Service locator or global access | Pass only declared deps, frozen |
| Behaviour changes after requiring a module in a tool | Side effects at require | Move connections to `start` |
| A consumer corrupts another module's state | Mutable state returned | Return functions and copies |
| Container code full of `:: any` spreading into services | Trying to type the container generically | Keep `any` inside the container; type at the factory |

## Checklist

- [ ] Utilities and config are required directly; services get dependencies injected.
- [ ] Each consumer depends on a narrow type with only the functions it calls.
- [ ] Time, randomness and engine services are injected where logic depends on them.
- [ ] Wiring happens in one place, with order derived from declared dependencies and cycles reported with a path.
- [ ] Build has no yields and no side effects; start connects events.
- [ ] Modules return small, frozen APIs and never expose mutable internal state.
- [ ] At least the money-touching services have fast fake-based tests.

## See also

[[Advanced Luau Start Here]], [[Module Scripts and Requiring]], [[Project Structure and Bootstrapping]], [[Frameworks - Knit Matter and Others]], [[Metatables and OOP - When and When Not]], [[Automated Testing with TestEZ and Jest-Lua]], [[Testing Strategies and Frameworks]], [[Building a Signal Library]], [[Custom Schedulers and Coroutine Patterns]], [[Advanced Types - Generics and Type Functions]], [[Daily Rewards System End to End]]

## Connected notes
<!-- auto-links:start -->
[[Dependency Injection in Luau]] · [[Event Bus]] · [[Luau Type System and Strict Mode]] · [[Links - OOP and module design]] · [[Skill - Roblox System Builder]] · [[Links - Script types]]
<!-- auto-links:end -->
