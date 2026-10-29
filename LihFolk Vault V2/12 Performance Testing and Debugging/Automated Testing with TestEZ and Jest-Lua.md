---
tags: [testing, testez, jest-lua, ci, open-cloud, test-doubles, automation, type/guide, area/performance, level/intermediate, api/DataStore]
---
# Automated Testing with TestEZ and Jest-Lua

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Testing glue code and UI instead of economy, odds and data.
> - Avoid: Calling `os.clock()`, `tick()` or `math.random` inside logic that tests need to control.
> - Avoid: Mocking everything, so tests break on refactors and prove nothing.
> - Economy formulas, odds, migrations, remote validators and config invariants have specs.
> - Clock and randomness injected; no waits in unit tests.
> - Fakes for DataStore and other services, able to simulate failures.
>
> Cost: TL;DR ~160 tok · whole note ~4.9k tok. Read more: ## 3. Test patterns that pay off · ## 4. Where tests run · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Testing Strategies and Frameworks]] introduces both frameworks, shows a first spec in each and compares them. This note is the next step: how to make a Roblox codebase testable, which tests actually pay for themselves in a game, how to write test doubles for engine services, and how to run the suite automatically, including on Roblox's own servers through Open Cloud. If you have never written a spec, read that note first.

---

## 1. What to test in a game (and what not to)

Automated tests are expensive to write and cheap to run. They pay off where a bug is costly and the logic is stable. In a Roblox game that ranking looks like this (rule of thumb, from what tends to break in live games):

| Test it | Why |
|---|---|
| Economy maths: prices, rewards, multipliers, rebirth formulas | A wrong number is a live economy incident ([[Economies and Currencies]]) |
| Random drops and odds | Odds bugs are invisible in play and cause player trust incidents |
| Data schema migrations | A bad migration corrupts saves for everyone ([[Data Schema Design and Migrations]]) |
| Remote validation | The server's guard against exploiters ([[Server Authority and Validation]]) |
| Config tables: every item complete and consistent | Catches the "added an item, forgot a field" class |
| Purchase granting logic | Money ([[Developer Products and ProcessReceipt]]) |
| Pure utilities (formatting, maths, timers) | Cheap and used everywhere |

| Do not automate (or not first) | Why |
|---|---|
| Visual layout, VFX, feel | Changes weekly; a human sees problems in seconds |
| Animation timing | Better covered by targeted harnesses ([[Testing Animations in Studio]]) |
| Physics outcomes | Non-deterministic; Open Cloud execution does not run physics at all |
| Thin glue code (connect a button to a remote) | The test is longer than the code and breaks on every UI change |

A measured example of the value: in the reference project, a player report led to finding a weighted-pick bug where an item meant to roll "1 in 3" was rolling about "1 in 370" (measured, fixed the same day). A ten-line statistical test on the roll function would have caught it before release. Odds code is the single best place to start testing in a collection game.

---

## 2. Make the code testable first

Tests need a pure core: functions that take inputs and return outputs without touching `game`, `Players`, `DataStoreService` or the clock. The engine-facing shell stays thin. [[Testing Strategies and Frameworks]] names the pattern; here is how to apply it to the parts that usually resist it.

### Inject the clock and the random source

```lua
--!strict
-- Cooldowns.luau: no os.clock() inside, the caller passes "now".
local Cooldowns = {}
Cooldowns.__index = Cooldowns

export type Cooldowns = typeof(setmetatable({} :: { ready: { [string]: number } }, Cooldowns))

function Cooldowns.new(): Cooldowns
	return setmetatable({ ready = {} }, Cooldowns)
end

function Cooldowns.tryUse(self: Cooldowns, key: string, now: number, duration: number): boolean
	local readyAt = self.ready[key]
	if readyAt and now < readyAt then
		return false
	end
	self.ready[key] = now + duration
	return true
end

return Cooldowns
```

The live service calls `cooldowns:tryUse(key, os.clock(), 2)`. The test calls it with `now = 0`, `1.9`, `2.0` and checks the boundary, in microseconds, with no waiting. Every `task.wait` in a test is a test that is slow and flaky.

The same goes for randomness: pass a `Random` object (or a function returning a number) into anything that rolls. A seeded `Random.new(42)` makes the test repeatable; a stub that returns fixed values tests boundaries exactly.

### Inject services through a small interface

A DataStore-facing module that calls `DataStoreService:GetDataStore` directly cannot be unit tested. Give it a store interface instead:

```lua
--!strict
-- StoreTypes.luau
export type Store = {
	get: (self: Store, key: string) -> any,
	update: (self: Store, key: string, fn: (old: any) -> any) -> any,
}

-- FakeStore.luau: an in-memory Store for tests. It can also simulate failures.
local FakeStore = {}
FakeStore.__index = FakeStore

function FakeStore.new()
	return setmetatable({ data = {} :: { [string]: any }, failNext = 0, calls = 0 }, FakeStore)
end

function FakeStore:get(key: string): any
	self.calls += 1
	if self.failNext > 0 then
		self.failNext -= 1
		error("FakeStore: simulated request failure")
	end
	return self.data[key]
end

function FakeStore:update(key: string, fn: (any) -> any): any
	self.calls += 1
	if self.failNext > 0 then
		self.failNext -= 1
		error("FakeStore: simulated request failure")
	end
	local new = fn(self.data[key])
	if new ~= nil then
		self.data[key] = new
	end
	return new
end

return FakeStore
```

The production adapter wraps a real `DataStore` with the same two methods. Now your retry logic, migration and default-filling can all be tested, including "the first two requests fail, the third succeeds", which is the case that matters and the one you can never reproduce on demand in Studio ([[Error Handling and Retries]]).

### Extract the validation from the remote handler

```lua
--!strict
-- The handler is a one-line shell; validate() is pure and testable.
local function validateBuy(itemId: unknown, quantity: unknown, catalog: { [string]: { price: number } }): (boolean, string?)
	if typeof(itemId) ~= "string" or catalog[itemId] == nil then
		return false, "unknown item"
	end
	if typeof(quantity) ~= "number" or quantity ~= quantity -- NaN check
		or quantity < 1 or quantity > 99 or quantity % 1 ~= 0 then
		return false, "bad quantity"
	end
	return true
end
```

Tests then throw exploiter inputs at it: `nil`, tables, negative numbers, `0/0`, `math.huge`, 1.5, strings of 10,000 characters. That list is the test suite for [[Exploits and Anti-Cheat]].

---

## 3. Test patterns that pay off

### Table-driven tests

One test body, many cases. Easy to extend when a bug report arrives (add a row).

```lua
-- TestEZ style
return function()
	local Pricing = require(script.Parent.Pricing)

	local cases = {
		{ name = "base", level = 1, rebirths = 0, expect = 100 },
		{ name = "level scaling", level = 10, rebirths = 0, expect = 1000 },
		{ name = "rebirth discount", level = 10, rebirths = 2, expect = 800 },
		{ name = "floor at 1", level = 0, rebirths = 50, expect = 1 },
	}

	describe("Pricing.upgradeCost", function()
		for _, c in cases do
			it(c.name, function()
				expect(Pricing.upgradeCost(c.level, c.rebirths)).to.equal(c.expect)
			end)
		end
	end)
end
```

### Statistical tests for odds

Odds tests must be tight enough to catch real bugs and loose enough not to fail by chance. With N rolls and true probability p, the standard deviation of the observed rate is `sqrt(p * (1 - p) / N)`. Allow about 4 standard deviations, and the false-failure rate is roughly 1 in 16,000 runs.

| p | N | Std dev | 4-sigma tolerance |
|---|---|---|---|
| 0.33 | 20,000 | 0.0033 | 0.013 |
| 0.01 | 100,000 | 0.00031 | 0.0013 |
| 0.001 | 1,000,000 | 0.00003 | 0.00013 |

Use a seeded generator anyway, so a failure is reproducible. For very rare items, test the *weight table* arithmetic (each item's share of the total) exactly, and test the sampler on a simpler distribution statistically. A million rolls in Luau is fast (well under a second on a desktop for a simple weighted pick; rule of thumb), but a hundred such tests add up.

### Invariant tests over config

The highest return per line in most games. Walk every item in the config and assert what must always be true:

```lua
-- Jest-Lua style
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Items = require(ReplicatedStorage.Shared.Config.Items)
local RARITIES = { Common = true, Rare = true, Epic = true, Legendary = true, Mythic = true }

describe("Items config", function()
	it("every item is complete", function()
		for id, item in Items do
			expect(type(item.displayName)).toBe("string")
			expect(RARITIES[item.rarity]).toBe(true)
			expect(item.price >= 0).toBe(true)
			expect(type(item.icon)).toBe("string")
		end
	end)

	it("display names are unique", function()
		local seen = {}
		for id, item in Items do
			expect(seen[item.displayName]).toBeNil()
			seen[item.displayName] = id
		end
	end)
end)
```

When a loop assertion fails, the message does not say which item. Include the id in a custom failure, or collect bad ids into a list and assert the list is empty: `expect(bad).toEqual({})` prints the offending ids.

### Migration tests with fixtures

Keep a folder of real (anonymised) save fixtures, one per schema version you have ever shipped. The test loads each, runs the migration chain, and asserts the result passes the current schema validator. When you add version N+1, you add a fixture for version N. This is the cheapest insurance against the most expensive class of bug ([[Data Loss Prevention and Recovery]]).

### Mocks: prefer fakes

Jest-Lua offers `jest.fn()` for spies (call counts and arguments) and module mocking. Mocks are tempting and brittle: a test that asserts "save was called with exactly these arguments" breaks on every refactor. Prefer a fake (like `FakeStore` above) and assert on the resulting state. Use `jest.fn()` where the call itself is the behaviour, such as "the analytics event fired once" or "the retry waited three times".

---

## 4. Where tests run

There are four places a Roblox test can run. Each has a different reach.

| Runner | Engine APIs | Speed | Set-up | Good for |
|---|---|---|---|---|
| [[Lune]] (standalone Luau runtime) | None (pure Luau only) | Fastest | Small | Pure modules on every push |
| Studio, from a plugin or the command bar | All, Edit mode | Fast | None | Developer loop while coding |
| `run-in-roblox` on a CI machine | All, in a Studio instance | Medium | Studio installed on a Windows or macOS runner | Engine-dependent specs |
| Open Cloud Luau Execution | Most, headless on a Roblox server | Slow (queued) | API key, a test place | Engine-dependent specs without a Studio machine |

### Lune

Lune runs Luau outside Roblox. Pure modules (no `game`, no Roblox types like `Vector3` unless you provide them) run unmodified. It is the right tool for the inner loop of CI: seconds per run, any Linux runner. The catch is that every module the test imports must also be pure, which is a good architectural pressure.

### Jest-Lua specifics that trip people up

From the library documentation (as of October 2026):
- Install with Wally as dev dependencies `jsdotlua/jest` and `jsdotlua/jest-globals` (3.10.0 at the time of writing; pin the current version).
- **Nothing is global**: require `describe`, `it`, `expect`, `jest` from JestGlobals in every spec.
- A `jest.config` module returns the configuration, for example `testMatch = { "**/*.spec" }`.
- Running needs the `FFlagEnableLoadModule` flag set to true in `ClientAppSettings.json` to enable `debug.loadmodule`. On a CI machine running Studio this file has to be placed by the job. On Open Cloud you cannot set fast flags, so whether Jest-Lua runs there is **unverified**; TestEZ, which needs no flag, or a small runner of your own, is the safer choice for Open Cloud jobs.
- `runCLI(root, options, projects):awaitStatus()` returns a status and a result with `results.numFailedTestSuites` and `results.numFailedTests`.

### TestEZ specifics

TestEZ needs no flags and no Wally (a copy of the module works). `TestEZ.TestBootstrap:run({ roots })` returns a results object with `failureCount`. It is the lowest-friction choice for engine-dependent tests and for Open Cloud execution. Its matchers are fewer and it has no mocking; with fakes (section 2) you rarely miss it.

### Open Cloud Luau Execution

Roblox docs (as of October 2026) describe an Open Cloud API that loads a place (or a specific place version) on a Roblox server, runs a Luau script, and returns its return value and logs. The facts that shape a CI design:

| Fact (Docs) | Consequence |
|---|---|
| Task creation is asynchronous; you poll the task until `COMPLETE` or `FAILED` | CI needs a polling loop with a timeout |
| Create calls are rate-limited to 5 per minute per API key owner | Run the whole suite in **one** task, not one task per spec |
| At most 10 incomplete tasks per place (HTTP 429 beyond) | Parallel CI jobs must share or queue |
| Default execution limit 5 minutes; a `timeout` field can be set | Keep the engine suite short; slow tests go elsewhere |
| Script up to 4 MB; return value up to 4 MB after JSON serialisation; logs keep 450 KB | Return a compact summary table, not every assertion message |
| Physics does not run; server and local scripts in the place do not run automatically | Your test runner must `require` and start what it needs |
| Data model changes are local to the task and not saved | Tests can create and destroy freely |
| DataStore and other cloud APIs can be called, with caution | Point tests at a test experience, never production data |
| API key in the `x-api-key` header; scope `universe.place.luau-execution-session:write` to create | Store the key as a CI secret; never print it |

A runner script that returns a CI-friendly summary:

```lua
-- Submitted as the task's script. TestEZ lives in the test place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)

local results = TestEZ.TestBootstrap:run({ ReplicatedStorage.Shared }, TestEZ.Reporters.TextReporterQuiet)

local failures = {}
for _, err in results.errors do
	table.insert(failures, tostring(err):sub(1, 500)) -- keep the return value small
end

return {
	success = results.failureCount == 0,
	failureCount = results.failureCount,
	successCount = results.successCount,
	failures = failures,
}
```

(The reporter name and the `errors` field follow TestEZ's source; check them against the version you vendor.)

The CI job then: builds the place with Rojo, publishes it to a **separate test place** (never the live one), creates the task against that place version, polls, and fails the build if `success` is false. Roblox publishes a sample repository demonstrating a place CI/CD flow with Rojo and this API; start from it ([[Code Pipeline - Rojo Git and CI]], [[Open Cloud APIs]]).

### Multiplayer tests from a plugin

Roblox docs (as of October 2026) list a `StudioTestService` with `ExecuteMultiplayerTestAsync(numPlayers, args)` (plugin security, yields), plus `GetTestArgs()` and `EndTest(value)` for the test side, and a sample that runs a 4-player test and checks the returned value. That makes scripted multi-client tests possible from a plugin: start N players, let a server script read the arguments, run a scenario such as "both players claim the same reward", and end the test with a result. The reference pages have little prose, so treat the details as **unverified** until you have run it yourself. See [[Multi-Client and Device Playtesting Protocols]].

---

## 5. Flaky tests and how to kill them

A test that fails one run in twenty trains everyone to ignore red builds. Common sources in Roblox:

| Source | Fix |
|---|---|
| `task.wait` and real time | Inject the clock |
| Unseeded randomness | Pass a seeded `Random` |
| Iteration order of dictionaries | Sort keys before comparing ordered output |
| Shared module state between specs | Give modules a `reset()` for tests, or construct fresh objects per test |
| `require` cache returning a module mutated by an earlier spec | Jest-Lua's module loading isolates specs (this is what `debug.loadmodule` is for); in TestEZ, avoid mutating shared modules |
| DataStore and HTTP calls | Fakes in unit tests; real calls only in a small, separately-labelled integration suite |
| Statistical tests too tight | Use the 4-sigma rule above |

Quarantine rather than delete: move a flaky test to a "known flaky" list that runs but does not fail the build, with an owner and a date. Then fix it.

---

## 6. A suite that stays alive

- **Put tests next to the code** (`Pricing.luau` and `Pricing.spec.luau` in the same folder) so moving or deleting a module moves its test.
- **Run the fast suite on every push**, the engine suite nightly and before every release ([[Build Test and Release Pipeline]]).
- **Turn every live bug into a test** first, then fix it. The test proves the fix and stops the regression.
- **Count tests, not coverage.** Roblox has no standard coverage tool for Luau in Studio (as of October 2026, not confirmed otherwise). Track instead: does every economy formula, odds table, migration and remote validator have at least one spec?
- **Keep the suite under a few minutes.** A suite nobody waits for is a suite nobody runs.

---

## When not to automate

- Prototype phase: the code will be thrown away. Test the odds and the data format; nothing else.
- Solo developer on a small game: a config invariant test and a migration test give most of the value. Do not build a CI pipeline before you have something to protect.
- Anything you change weekly for feel. Write a harness you run by hand instead.

---

## Common mistakes

- Testing glue code and UI instead of economy, odds and data.
- Calling `os.clock()`, `tick()` or `math.random` inside logic that tests need to control.
- Mocking everything, so tests break on refactors and prove nothing.
- Statistical tests with tolerances picked by feel.
- One Open Cloud task per spec, hitting the 5-per-minute create limit.
- Running Open Cloud tests against the live place or live data stores.
- Assuming Jest-Lua works on Open Cloud without checking the fast-flag requirement.
- Letting flaky tests stay red, so real failures are ignored.

## Checklist

- [ ] Economy formulas, odds, migrations, remote validators and config invariants have specs.
- [ ] Clock and randomness injected; no waits in unit tests.
- [ ] Fakes for DataStore and other services, able to simulate failures.
- [ ] Save fixtures for every shipped schema version.
- [ ] Pure suite runs on every push (Lune or equivalent).
- [ ] Engine suite runs nightly or pre-release against a test place.
- [ ] Open Cloud key stored as a secret with the minimum scope.
- [ ] Flaky tests quarantined with an owner.
- [ ] Every live bug becomes a test before the fix.

## See also

[[Testing Strategies and Frameworks]], [[Multi-Client and Live Testing]], [[Code Pipeline - Rojo Git and CI]], [[Build Test and Release Pipeline]], [[Open Cloud APIs]], [[External Tooling - Rojo Wally Selene StyLua]], [[Data Schema Design and Migrations]], [[RNG Drops and Luck Systems]], [[Server Authority and Validation]], [[Error Handling and Retries]], [[QA Checklists Before Release]]

## Connected notes
<!-- auto-links:start -->
[[Dependency Injection in Luau]] · Module Design and Dependency Injection · Official Docs - Studio and Tooling · Testing Your Own Remotes - Fuzzing and Abuse Tests · Git and Source Control for Roblox · Data Schema Versioning
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Save Migration Tests - Fixture Saves and Golden Files]] · [[UI Automation with VirtualInput and StudioTestService]] · [[Automated Luau Checks - LihFolk Hook and Audit]] · [[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]] · [[Genre QA Passes - Test Checklists per Game Type]] · [[Testing Time-Based Features with a Controllable Clock]] · [[Debugger Breakpoints and Logging]]
<!-- related:end -->
