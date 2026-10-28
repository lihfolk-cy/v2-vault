---
tags: [testing, testez, jest-lua, ci, dry-run, qa, static-analysis]
---
# Testing Strategies and Frameworks

Roblox games are stateful, networked, visual and full of engine behaviour you do not control. That makes them hard to test from the outside, and many teams respond by testing nothing except "I played it and it seemed fine". This note lays out a layered strategy that works: static checks on every script, unit tests for pure logic (with TestEZ and Jest-Lua examples), Edit-mode dry runs and harnesses for things that touch instances, play tests for runtime behaviour, and an honest vocabulary ("Edit-tested", "not play-tested") so nobody mistakes one level of proof for another.

Source labels: **Docs** (Creator Hub and library docs, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. The levels of proof

| Level | Proves | Does not prove | Cost |
|---|---|---|---|
| **Static** (compiles, type-checks, lint, use-before-definition scan) | the code can run; obvious mistakes absent | that it does the right thing | seconds, every save |
| **Unit tests** (pure logic) | formulas, tables, state machines, parsers behave | integration with the engine | seconds, every change |
| **Edit-mode dry run** (run the real code on clones or stand-ins in Edit) | code paths execute without errors on real instances; layouts compute; counts and budgets | runtime timing, replication, physics, player input, effects that need rendering | minutes |
| **Solo play test** | runtime behaviour for one player | multiplayer, latency, late joiners | minutes, manual |
| **Multi-client play test** | replication, join order, per-player isolation | real devices, real network | minutes, manual |
| **Live test** (private server, real devices) | the shipped build works for real | rare race conditions at scale | tens of minutes |

The key discipline is **saying which level was reached**. In the reference project, every change log entry ended with its proof level: "Edit only, not play-tested", "Edit dry run on a template clone passed", "Edit-tested; not play-tested". Dozens of entries carried "not play-tested", and that tag was the to-do list for the next play session. A feature reported as "done" without a level gets assumed to be fully tested, and that assumption is where shipped bugs come from.

Rule: **"done" means play-tested** for anything that runs at runtime. Edit-mode proof is real proof of something narrower.

---

## 2. Static checks

Cheap, automatic, catch a surprising share of bugs.

### What to run
| Check | Tool |
|---|---|
| Syntax / compile | Studio's Script Analysis; `luau-analyze`; or `loadstring(source)` in the command bar or a plugin |
| Types | `--!strict` plus Luau's type checker ([[Luau Type System and Strict Mode]]) |
| Lint | Selene with the Roblox standard library ([[External Tooling - Rojo Wally Selene StyLua]]) |
| Formatting | StyLua |
| Project-specific scans | your own scripts: forbidden APIs, risky patterns |

### Project-specific scans that paid off (Measured)
- **Compile before save.** Every script written by tooling was compiled with `loadstring` first; a script that does not compile is never written into the place.
- **Use-before-definition scan.** A small analyser flagged locals used above their `local` declaration (which silently read a global `nil` at runtime). It ran on every changed script and had to report zero issues.
- **A whole-codebase sweep** of about 1,084 scripts (compile, use-before-definition, remotes referenced but never created, `WaitForChild` paths that did not exist, `require` targets, attribute names) found real bugs, including a module that returned undefined globals and a config row pointing at a renamed boss.
- **Grep for known-bad APIs before release**: for example, temporary animation ids that only work in Studio ([[Engine Gotchas]] 1.1).
- **Script size.** Script `Source` has a hard limit of 200,000 characters; generated modules approaching it were split early.

```lua
--!strict
-- Command bar / plugin helper: compile-check every script under a root.
-- loadstring is available in the command bar and plugins; in game servers it needs LoadStringEnabled.
local function compileCheck(root: Instance): number
	local failures = 0
	for _, inst in root:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			local source = (inst :: any).Source :: string
			local fn, err = loadstring(source, "=" .. inst:GetFullName())
			if not fn then
				failures += 1
				warn("[compile] " .. tostring(err))
			end
		end
	end
	print(string.format("[compile] %d failure(s)", failures))
	return failures
end

compileCheck(game:GetService("ServerScriptService"))
```

(`loadstring` compiles with the Luau compiler, so it catches syntax errors, not type errors. Use the type checker for those.)

---

## 3. Design for testability: pure core, thin shell

Logic that touches no Roblox APIs can be tested anywhere, including CI, in milliseconds. Push into pure modules:
- damage and defence formulas, crit and status math,
- drop tables, pity counters, roll odds ([[RNG Drops and Luck Systems]]),
- level and price curves, economy sinks,
- data migrations ([[Data Schema Design and Migrations]]),
- validation predicates for remotes ([[Server Authority and Validation]]),
- state machines (combo windows, quest progress).

The impure shell (services, instances, remotes) stays thin and is covered by dry runs and play tests.

**Determinism rule**: randomness is injected. Pure modules take an `rng: () -> number` (or a `Random` object), so tests pass a seeded generator and gameplay passes the real one.

```lua
--!strict
-- ReplicatedStorage/Shared/DropTable.luau
export type Entry = { id: string, weight: number }

local DropTable = {}

function DropTable.roll(entries: { Entry }, rng: () -> number): string
	local total = 0
	for _, e in entries do
		assert(e.weight >= 0, "negative weight: " .. e.id)
		total += e.weight
	end
	assert(total > 0, "empty drop table")
	local pick = rng() * total
	for _, e in entries do
		pick -= e.weight
		if pick < 0 then
			return e.id
		end
	end
	return entries[#entries].id -- floating point edge: rng() returned (almost) 1
end

return DropTable
```

---

## 4. TestEZ

TestEZ is Roblox's original BDD-style test framework (`describe`/`it`/`expect`), used for years for Roblox's own libraries. It runs inside Roblox (Studio or a test place). Spec files are ModuleScripts named `*.spec` that return a function.

```lua
-- ReplicatedStorage/Shared/DropTable.spec.luau
return function()
	local DropTable = require(script.Parent.DropTable)

	local function seeded(seed: number): () -> number
		local r = Random.new(seed)
		return function()
			return r:NextNumber()
		end
	end

	describe("roll", function()
		it("only returns ids from the table", function()
			local entries = { { id = "a", weight = 1 }, { id = "b", weight = 3 } }
			local rng = seeded(1)
			for _ = 1, 1000 do
				local id = DropTable.roll(entries, rng)
				expect(id == "a" or id == "b").to.equal(true)
			end
		end)

		it("respects weights within tolerance", function()
			local entries = { { id = "common", weight = 9 }, { id = "rare", weight = 1 } }
			local rng = seeded(42)
			local rare = 0
			local N = 20000
			for _ = 1, N do
				if DropTable.roll(entries, rng) == "rare" then
					rare += 1
				end
			end
			expect(rare / N).to.be.near(0.1, 0.01)
		end)

		it("never returns a zero-weight entry", function()
			local entries = { { id = "never", weight = 0 }, { id = "always", weight = 1 } }
			local rng = seeded(7)
			for _ = 1, 1000 do
				expect(DropTable.roll(entries, rng)).to.equal("always")
			end
		end)

		it("errors on an empty table", function()
			expect(function()
				DropTable.roll({}, seeded(1))
			end).to.throw()
		end)
	end)
end
```

Runner (a Script in a test place, or run from the command bar):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)

-- Runs every *.spec module under the given roots and prints a report.
local results = TestEZ.TestBootstrap:run({ ReplicatedStorage.Shared })
if results.failureCount > 0 then
	warn(("%d test(s) failed"):format(results.failureCount))
end
```

Useful matchers: `.to.equal`, `.to.be.near(value, limit)`, `.to.throw()`, `.to.be.a("table")`, `.to.be.ok()`, and `.never` to negate. Lifecycle: `beforeEach`, `afterEach`, `beforeAll`, `afterAll`. Focus and skip: `itFOCUS`, `itSKIP`, `describeFOCUS`, `describeSKIP`.

TestEZ is stable and simple but sees little active development (rule of thumb; check its repository). Many teams now use Jest-Lua for new projects.

---

## 5. Jest-Lua

Jest-Lua is a Luau port of JavaScript's Jest (Jest 27.x API, Docs of the library). Installed with Wally as dev dependencies:

```toml
[dev-dependencies]
Jest = "jsdotlua/jest@3.10.0"
JestGlobals = "jsdotlua/jest-globals@3.10.0"
```

Version numbers as given in the library's getting-started page (as of October 2026); pin whatever is current.

Important setup facts (library Docs):
- Every function you use (`describe`, `it`, `expect`, `jest`) **must be required explicitly from JestGlobals**; there are no injected globals.
- A `jest.config` module in the project root returns configuration, for example `{ testMatch = { "**/*.spec" } }`.
- Running requires the `FFlagEnableLoadModule` fast flag set to true (in `ClientAppSettings.json`) to enable `debug.loadmodule`, which Jest uses to load test modules fresh.
- From the command line the library docs use `run-in-roblox` to execute a runner script against a place file.

A spec:

```lua
-- src/__tests__/DropTable.spec.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect
local jest = JestGlobals.jest

local DropTable = require(ReplicatedStorage.Shared.DropTable)

describe("DropTable.roll", function()
	it("uses the injected rng exactly once per roll", function()
		local rng = jest.fn(function()
			return 0.5
		end)
		DropTable.roll({ { id = "a", weight = 1 }, { id = "b", weight = 1 } }, rng)
		expect(#rng.mock.calls).toBe(1)
	end)

	it("picks by cumulative weight", function()
		local entries = { { id = "a", weight = 1 }, { id = "b", weight = 3 } }
		expect(DropTable.roll(entries, function() return 0.0 end)).toBe("a")
		expect(DropTable.roll(entries, function() return 0.26 end)).toBe("b")
		expect(DropTable.roll(entries, function() return 0.999 end)).toBe("b")
	end)

	it("throws on an empty table", function()
		expect(function()
			DropTable.roll({}, function() return 0 end)
		end).toThrow()
	end)
end)
```

Runner (library Docs pattern):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local runCLI = require(ReplicatedStorage.DevPackages.Jest).runCLI

local status, result = runCLI(ReplicatedStorage.Project, {
	verbose = false,
	ci = false,
}, { ReplicatedStorage.Project }):awaitStatus()

if status == "Resolved" then
	print(("failed suites: %d, failed tests: %d"):format(
		result.results.numFailedTestSuites, result.results.numFailedTests))
end
```

(The library's example also calls `ProcessService:ExitAsync` with 0 or 1 when running headless; the exact shape of `awaitStatus` results follows the Promise library it uses. Check the runCLI page for your version.)

### TestEZ or Jest-Lua?
| | TestEZ | Jest-Lua |
|---|---|---|
| Syntax | `expect(x).to.equal(y)` | `expect(x).toBe(y)` (Jest style) |
| Mocks | none built in | `jest.fn`, module mocks, timers |
| Snapshots | no | yes |
| Setup | drop in and run | Wally, config module, a fast flag |
| Familiar to | Roblox veterans | web developers |

Either is fine. The tests matter more than the framework.

---

## 6. Running tests in CI

Options as of October 2026:
- **Pure modules under Lune** (a standalone Luau runtime): fastest, no Roblox needed, but only for code that touches no engine APIs. Use plain assertions or a small TestEZ-compatible shim.
- **`run-in-roblox`**: opens a place in Studio on the CI machine and runs a script (needs Studio installed; Windows or macOS runners).
- **Open Cloud Luau Execution**: an Open Cloud API that runs a Luau script against a place or a specific place version and returns output (Docs). Requests use an API key in the `x-api-key` header with the `universe.place.luau-execution-session:write` scope; task creation is asynchronous, so CI polls the task state; Docs list rate limits of 5 per minute per API key owner and 45 per minute per IP. Translated pages label it Beta while the English page labels it stable; treat stability as unverified. See [[Open Cloud APIs]].

A practical pipeline: Lune for pure specs on every push; a nightly or pre-release job that publishes to a test place and runs engine-dependent specs via Open Cloud or `run-in-roblox`. See [[Git and Source Control for Roblox]].

---

## 7. Edit-mode dry runs and harnesses

Many systems cannot be unit-tested but can be exercised in Edit mode against real instances: UI builders, map tools, effect spawners, data migrations on fixture profiles.

### The dry-run pattern (Measured)
The reference project's tools and installers all supported a **dry run**:
1. Clone the target (a GUI, a model template, a map region) into a scratch location, or build stand-ins.
2. Run the real code against the clone.
3. Assert outcomes: counts, sizes, positions, no errors, budgets respected.
4. Destroy the clone.

Examples from its logs: a UI animation system dry-run on a clone in a scratch GUI checked ranges, exact reset to the rest pose, reduced-motion behaviour and that disabling the GUI stopped the loop; an arena effect was dry-run on a template clone with stand-in parts; cleanup scripts printed what they *would* delete unless an explicit flag was passed.

### Harnesses for flows
A harness drives a flow through its public API: open the backpack, select an item, salvage, close; check no errors and that state changed. The reference project's UI rebuilds each shipped with a harness and a phone layout check ([[Mobile and Low-End Optimization]]).

### Edit-mode limits (Measured)
- Particles step only while Studio renders; rate emission does not run in Edit, `:Emit()` does.
- Animations inside a ViewportFrame do not advance in Edit; `Animator:StepAnimations` needs dt > 0 ([[Testing Animations in Studio]]).
- Humanoid rigs built in Edit by some APIs lack the joints you expect.
- `require` from the command bar returns a **separate module instance** from the one running scripts use. Mutating it does not affect the running game. Use gated cheat remotes for live state ([[Multi-Client and Live Testing]]).
- Some features (for example EditableMesh/EditableImage in published games without the right settings) behave differently live than in Studio.

So a dry run says "the code runs and produces the right structure". It does not say "it looks right and feels right at runtime". That is the play test's job.

---

## 8. Play tests that count

A play test is evidence only if it is specific. Write a short test script (human steps) per feature:

```
Feature: Daily gift claim
1. Join fresh profile (reset via cheat panel).       Expect: gift 1 locked, timer 5:00.
2. Advance play time 5 min (cheat).                   Expect: gift 1 claimable, toast shown.
3. Claim.                                             Expect: reward granted once, button "Claimed".
4. Rejoin.                                            Expect: still "Claimed", reward not regranted.
5. Phone viewport 667x375.                            Expect: all buttons >= 44 px, no overlap.
```

Use cheat tooling to reach states quickly; route cheats through the same APIs players use ([[Multi-Client and Live Testing]]).

---

## Common mistakes

- Reporting Edit-mode success as "works".
- Testing pure logic through the UI by hand.
- `math.random` inside formulas under test (non-deterministic failures).
- Command-bar `require` to "test live state".
- Tests that only check one happy value instead of boundaries and properties (loop over levels, weights, edge inputs).
- No compile and lint gate, so a typo ships.
- Frameworks set up, tests never run because CI is not wired.

## Checklist

- [ ] Every changed script compiles, type-checks and passes lint.
- [ ] Pure modules for money, drops, curves, migrations and validation, with specs.
- [ ] Randomness injected and seeded in tests.
- [ ] Specs run automatically (Lune for pure, Studio or Open Cloud for engine-dependent).
- [ ] Tools and installers support dry run by default.
- [ ] Every change log entry states its proof level; "not play-tested" items tracked until tested.
- [ ] Each feature has a written play-test script.

## See also

[[QA Checklists Before Release]] · [[Multi-Client and Live Testing]] · [[Debugger Breakpoints and Logging]] · [[Testing Animations in Studio]] · [[External Tooling - Rojo Wally Selene StyLua]] · [[Luau Type System and Strict Mode]] · [[Command Bar and Studio Scripting]] · [[Open Cloud APIs]] · [[Data Schema Design and Migrations]]

## Connected notes
<!-- auto-links:start -->
[[Automated Testing with TestEZ and Jest-Lua]] · [[Code Pipeline - Rojo Git and CI]] · [[MCP Workflows for Scripting and Debugging]] · [[Build Test and Release Pipeline]] · [[Links - Testing]] · [[Dependency Injection in Luau]]
<!-- auto-links:end -->
