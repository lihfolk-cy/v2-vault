---
tags: [core-concept, architecture, luau, testing, modules]
---
# Dependency Injection in Luau

**Dependency injection (DI)** means a module receives the things it depends on (a data store wrapper, a clock, a random generator, another service) from outside, instead of fetching them itself with `require` or `game:GetService`. In Luau that usually just means passing a table of dependencies into a constructor or an `init` function.

## Why it matters on Roblox

Roblox code tends to reach straight for globals: `DataStoreService:GetDataStore(...)` inside the inventory module, `os.time()` inside the daily reward check, `math.random` inside the drop roll. That works until you want to test it (no DataStore in a unit test, no way to fake "tomorrow"), run it on a different place, or swap a dependency. DI makes those seams explicit and cheap.

## The nuance most people miss

1. **DI in Luau needs no framework.** A function parameter is enough. Containers and auto-wiring add complexity that small and medium Roblox projects rarely need.
2. **Inject what varies or what is slow.** Time, randomness, persistence, HTTP and remotes are the usual candidates. Injecting `math.floor` is ceremony.
3. **Defaults keep call sites simple.** Accept an optional dependency table and fall back to the real services, so production code stays short and tests pass fakes.
4. **It breaks require cycles.** If module A and B need each other, have a bootstrap script create both and hand each a reference, instead of requiring each other at the top.
5. **Types keep it honest.** Declare the dependency shape as a Luau type so a fake that is missing a method fails type checking, not at runtime.
6. **Too much injection is noise.** If every function takes eight dependencies, the module is doing too much; split it.

## Tiny example

```lua
--!strict
type Deps = { now: () -> number, store: { get: (string) -> any, set: (string, any) -> () } }

local RealStore = require(script.Parent.RealStore) -- your DataStore wrapper
local Daily = {}

function Daily.new(deps: Deps?)
	local d: Deps = deps or { now = os.time, store = RealStore }
	local self = {}
	function self.canClaim(userId: number): boolean
		local last = d.store.get("daily_" .. userId) or 0
		return d.now() - last >= 86400
	end
	return self
end

-- Test: fake clock and store, no DataStore needed.
local fake = { now = function() return 200000 end, store = { get = function() return 100000 end, set = function() end } }
assert(Daily.new(fake).canClaim(1))
```

## Where this shows up

- [[Module Design and Dependency Injection]]: the deep dive.
- [[Module Scripts and Requiring]]: require behaviour and cycles.
- [[Project Structure and Bootstrapping]]: wiring modules at startup.
- [[Automated Testing with TestEZ and Jest-Lua]]: tests that need fakes.
- [[Testing Strategies and Frameworks]]: what to test where.
- [[Luau Type System and Strict Mode]]: typing dependency tables.
- [[Advanced Types - Generics and Type Functions]]: generic service types.
- [[Frameworks - Knit Matter and Others]]: how frameworks wire services.
- [[Daily Rewards System End to End]]: a time-dependent system to test.
- [[Code Pipeline - Rojo Git and CI]]: running those tests in CI.
- [[Code Review for Luau Teams]]: spotting hidden dependencies in review.

Related concepts: [[Event Bus]], [[Feature Flags]], [[Deterministic Simulation]].

## Connected notes
<!-- auto-links:start -->
[[Advanced Luau Start Here]] · [[Skill - Roblox System Builder]] · [[MCP Workflows for Scripting and Debugging]] · [[Links - Testing]] · [[External Tooling - Rojo Wally Selene StyLua]] · [[Resource Library - Data and Persistence]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
