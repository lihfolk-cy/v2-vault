---
tags: [testing, qa, datastore, migrations, fixtures, golden-files, persistence, type/guide, area/testing, area/data, level/advanced, area/performance]
---
# Save Migration Tests - Fixture Saves and Golden Files

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Only testing a "new player" profile per version.
> - Avoid: Fixtures with real user names or chat content committed to the repo.
> - Avoid: Goldens regenerated blindly whenever a test fails.
> - At least one fixture per historical schema version.
> - Pathological fixtures (missing tables, wrong types, NaN, unknown ids).
> - Runner checks golden equality, idempotence and paid-value invariant.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## 1. Why fixtures beat hand-written cases · ## 3. The runner · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Schema Migrations - Worked Case Studies]] shows how to write migration steps that are pure, total and leave an audit trail. This note is about proving they stay correct over years: a folder of **fixture saves** (real-shaped profiles from every schema version, including the ugly ones) and **golden files** (the exact expected output of migrating each fixture to the current version). Every change to the migration chain reruns all fixtures and diffs against the goldens. A migration bug then shows up as a failing diff in CI, not as a wave of "my pets are gone" reports.

Labels: **Rule of thumb** unless stated.

---

## 1. Why fixtures beat hand-written cases

Hand-written test profiles contain the shapes you remember. Real profiles contain shapes you forgot: a field from a feature removed two years ago, an inventory saved as an array by a bug in version 4, a currency stored as a string by an admin command, a half-written profile from a crash. Migration step rule 2 ("total over every historical shape") can only be checked against those shapes.

So fixtures come from three sources:

1. **Snapshots at each release.** When you bump the schema version, save a few representative profiles of the old version to the fixture folder before shipping.
2. **Anonymised production samples.** Read a handful of real keys (new players, veterans, whales, banned players) from the live store, strip anything personal, and save them. Do this with Open Cloud DataStore access or a server script in a private server, never from a client.
3. **Pathological fixtures written by hand.** Missing parent tables, `nil` everywhere, NaN, negative counts, huge arrays, unknown item ids.

Strip personal data. A profile keyed by user id can contain names or chat-derived content; fixtures in a Git repo are effectively public to everyone with repo access.

---

## 2. Folder layout

```
tests/
  migrations/
    fixtures/
      v03_new_player.json
      v03_veteran_array_inventory.json
      v05_admin_string_coins.json
      v07_missing_stats.json
      v09_current.json
    golden/
      v03_new_player.json        -- expected output at CURRENT version
      v03_veteran_array_inventory.json
      ...
    run_migrations.spec.luau
```

Fixture names start with the schema version they were saved at, so you can see coverage per version at a glance. **Every historical version needs at least one fixture.** A version with no fixture is a version whose migration path is untested.

---

## 3. The runner

Migrations must be pure for this to work: input table in, output table out, no services. The runner loads each fixture, migrates to the current version and compares with the golden.

```lua
--!strict
-- run_migrations.spec.luau (shape for Jest-Lua or TestEZ; adapt the loader to your runtime)
local Migrations = require(path.to.Migrations) -- exposes migrate(data) -> data and CURRENT
local Fixtures = require(path.to.FixtureLoader) -- returns { [name]: { input = table, golden = table? } }

-- Deterministic deep compare that reports the first differing path.
local function diff(a: any, b: any, path: string): string?
	if type(a) ~= type(b) then
		return ("%s: type %s vs %s"):format(path, type(a), type(b))
	end
	if type(a) ~= "table" then
		if a ~= b and not (a ~= a and b ~= b) then -- treat NaN == NaN for comparison
			return ("%s: %s vs %s"):format(path, tostring(a), tostring(b))
		end
		return nil
	end
	for k, v in a do
		local d = diff(v, b[k], path .. "." .. tostring(k))
		if d then return d end
	end
	for k in b do
		if a[k] == nil then
			return ("%s.%s: missing in output"):format(path, tostring(k))
		end
	end
	return nil
end

for name, fx in Fixtures do
	it("migrates " .. name, function()
		local out = Migrations.migrate(table.clone(fx.input))
		expect(out.Schema).toBe(Migrations.CURRENT)
		-- idempotent: migrating again changes nothing
		local again = Migrations.migrate(table.clone(out))
		expect(diff(out, again, "root")).toBe(nil)
		if fx.golden then
			expect(diff(out, fx.golden, "root")).toBe(nil)
		end
	end)
end
```

Notes on the details:

- `table.clone` is shallow. If a step mutates nested tables in place, deep-copy the input, or a fixture can be changed by the first test and corrupt the next.
- **Idempotence check:** migrating an already-current profile must be a no-op. This catches steps that are not gated on the schema number.
- **Timestamps:** `MigrateUtil.audit` writes `os.time()`. Either inject the clock ([[Testing Time-Based Features with a Controllable Clock]]) or strip the `t` field before diffing, or the goldens break every second.

Where it runs: pure migration modules run fine outside Roblox in [[Lune]], which makes this suite fast in CI. If migrations touch engine types, run them in a test place via Open Cloud Luau execution ([[Code Pipeline - Rojo Git and CI]]).

---

## 4. Golden file discipline

Goldens are only useful if changing them is a deliberate act.

- **Generate, then review.** A small script writes current outputs to `golden/` when you pass a flag (for example `UPDATE_GOLDEN=1`). Never edit goldens by hand.
- **Review the diff like code.** When a golden changes, the Git diff shows exactly what happens to every historical player shape. A reviewer asks: did anyone lose paid value? Did a count drop? Is there a `MigrationLog` entry for every removal?
- **Paid value never shrinks.** Add an explicit assertion per fixture: total premium currency and paid items after migration are greater than or equal to before ([[Schema Migrations - Worked Case Studies]] states the rule).
- **Never delete a fixture** because it fails. A failing fixture is a real player who would have broken.

```lua
-- Invariant per fixture, alongside the golden compare
local function paidTotal(d: any): number
	return (tonumber(d.Gems) or 0) + #(d.PaidItems or {})
end
expect(paidTotal(out) >= paidTotal(fx.input)).toBe(true)
```

---

## 5. Rollback fixtures

A release can be rolled back after some players already saved in the new format. Keep fixtures saved **by the new version** and run them through the **previous** release's loader in a separate job: it must load without crashing and without discarding unknown fields. That is the forward-compatibility half of migration safety, and it is the one teams skip.

---

## 6. When to add fixtures

- Every schema bump: at least one fixture of the version being replaced.
- Every data bug in production: a fixture reproducing the broken shape, plus the repair step's golden.
- Every exploit repair ([[Data Loss Prevention and Recovery]]): the pre-repair shape and the expected repaired shape.

---

## Common mistakes

- Only testing a "new player" profile per version.
- Fixtures with real user names or chat content committed to the repo.
- Goldens regenerated blindly whenever a test fails.
- No idempotence check, so a step reruns on already-migrated data.
- Audit timestamps in goldens, so tests are flaky.
- No rollback fixtures; the previous build chokes on new saves.

## Checklist

- [ ] At least one fixture per historical schema version.
- [ ] Pathological fixtures (missing tables, wrong types, NaN, unknown ids).
- [ ] Runner checks golden equality, idempotence and paid-value invariant.
- [ ] Goldens regenerated only via flag and reviewed in the diff.
- [ ] Rollback fixtures run through the previous loader.
- [ ] Suite runs in CI on every change to the data layer.

## See also

- [[Schema Migrations - Worked Case Studies]], [[Data Loss Prevention and Recovery]]
- [[Automated Testing with TestEZ and Jest-Lua]], [[Code Pipeline - Rojo Git and CI]], [[Lune]]
- [[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]]

## Connected notes

[[Session Locking and Profile Libraries]] · Debugging DataStore Problems · Cookbook - Data and Saving · [[Testing Strategies and Frameworks]]

<!-- related:start -->
## Related
[[Data Schema Versioning]] · [[QA Checklists Before Release]] · [[Gated Tester Commands and Debug Panels]] · [[Genre QA Passes - Test Checklists per Game Type]] · [[UI Automation with VirtualInput and StudioTestService]] · [[Automated Luau Checks - LihFolk Hook and Audit]] · [[Multi-Client and Live Testing]]
<!-- related:end -->
