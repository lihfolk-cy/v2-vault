---
tags: [pipelines, config, data, spreadsheets, balancing, codegen, validation]
---
# Data and Config Pipeline - Spreadsheets to Game

Most of a game's content is numbers: item stats, drop odds, prices, enemy health, quest rewards, cooldowns. Designers want to edit them in a spreadsheet where they can sort, chart and compare; the game wants them in a ModuleScript it can `require`. The gap between the two is where balance bugs, typos and lost edits live. This note is a pipeline that closes it: **sheet, validate, generate, install safely, read back**. The balancing method itself is in [[Balancing with Spreadsheets and Data]]; schema design in [[Data Schema Design and Migrations]]; changing values on live servers without a publish in [[Global State and Live Config]].

## Config in a Roblox game: what goes where

| Data | Changes how often | Lives in | Pipeline |
|---|---|---|---|
| Item, enemy, quest definitions | per update | generated ModuleScripts | this note |
| Tuning constants (cooldowns, speeds) | per update | generated or hand-written modules | this note |
| Feature flags and kill switches | any time | a flags module + optional live override | this note + [[Global State and Live Config]] |
| Event schedules, shop rotations | weekly | live config (DataStore / MemoryStore) | [[Live Content Pipeline]] |
| Player data | per session | DataStores | [[DataStore Fundamentals]] |
| Translations | per update | localization tables | [[Localization Pipeline]] |

The rule: **static content is code-generated and shipped with the place; dynamic content is fetched at runtime.** Mixing them (hand-editing a 3,000-line config module in Studio while live overrides also patch it) makes it impossible to know what a value is.

## The stages

| # | Stage | Input | Output | Gate |
|---|---|---|---|---|
| 1 | Edit | spreadsheet (or JSON / YAML) | exported CSV per table | none (humans) |
| 2 | Validate | CSV | errors or a clean table | schema, ranges, references, uniqueness |
| 3 | Derive | clean table | computed columns (fitted stats, totals) | formulas tested |
| 4 | Generate | table | `ItemsData.luau` (GENERATED) | deterministic output, compiles |
| 5 | Install | generated module | module in the place (Rojo or a safe edit) | compile, size, clone-require |
| 6 | Read back | live place | JSON dump | diff against the sheet |
| 7 | Record | | changelog line with the table and row count | |

## Stage 1: the sheet

Design the sheet like a database table:

- **One row per thing, one column per field.** No merged cells, no colour-coded meaning (colours do not export).
- **A stable id column** (`id`, lowercase, no spaces). Display names change; ids never do. Save data, analytics and icons all key off the id.
- **Typed column names** help the validator: `power:int`, `odds:num`, `rarity:enum(Common,Rare,...)`, `icon:asset`, `tags:list`.
- **Comment columns** prefixed with `#` are for humans and are dropped on export.
- **One tab per table**, exported as CSV with UTF-8 encoding.

If the team uses Google Sheets, export with the sheet's CSV export URL or the Sheets API in a script; keep the exported CSVs in Git so every balance change has a diff.

## Stage 2: validate before anything touches the game

Validation catches the errors that are expensive to find in Play: a duplicate id that silently overwrites another item, a rarity spelled `Legendry`, a reference to an icon that was never uploaded, odds that do not sum, a stat of 0 that divides by zero later.

```python
# tools/validate.py : schema-driven CSV validation. Exit code 1 on any error.
import csv, re, sys, json

def parse_type(t):
    m = re.fullmatch(r"enum\((.*)\)", t)
    return ("enum", [s.strip() for s in m.group(1).split(",")]) if m else (t, None)

def validate(path, refs):
    errors, rows, seen = [], [], set()
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        cols = [c for c in reader.fieldnames if not c.startswith("#")]
        for n, raw in enumerate(reader, start=2):          # line 1 is the header
            row = {}
            for col in cols:
                name, _, typ = col.partition(":")
                kind, opts = parse_type(typ or "str")
                v = (raw[col] or "").strip()
                try:
                    if kind == "int": v = int(v)
                    elif kind == "num": v = float(v)
                    elif kind == "bool": v = {"true": True, "false": False}[v.lower()]
                    elif kind == "list": v = [s.strip() for s in v.split("|") if s.strip()]
                    elif kind == "enum" and v not in opts: raise ValueError(f"not in {opts}")
                    elif kind == "asset" and v and v not in refs.get("assets", {}):
                        raise ValueError("asset not in the id map")
                except (ValueError, KeyError) as e:
                    errors.append(f"{path}:{n}: {name}={raw[col]!r}: {e}")
                row[name] = v
            if row.get("id") in seen:
                errors.append(f"{path}:{n}: duplicate id {row['id']}")
            seen.add(row.get("id"))
            if not re.fullmatch(r"[a-z0-9_]+", str(row.get("id", ""))):
                errors.append(f"{path}:{n}: bad id {row.get('id')!r}")
            rows.append(row)
    return rows, errors

if __name__ == "__main__":
    refs = {"assets": json.load(open("data/asset_ids.json", encoding="utf-8"))}
    rows, errors = validate(sys.argv[1], refs)
    print("\n".join(errors) or f"ok: {len(rows)} rows")
    sys.exit(1 if errors else 0)
```

Add table-specific rules on top: odds strictly decreasing with rarity, every enemy's zone exists in the zones table, every reward item exists in the items table, no price below a floor.

## Stage 3: derive, do not invent

Some columns should be computed, not typed. The reference project's new-item tool never let anyone type a new item's stats: it took the **six highest-odds items of the same rarity**, fitted a line of each stat against the item's odds (on a log scale), and evaluated it at the new item's odds, defaulting to 1.14x the current top item when odds were not given (measured in one production game). New items therefore sat on the same curve as their neighbours.

```python
import math

def fit_stat(neighbours, stat, new_odds):
    """neighbours: list of dicts with 'odds' (1 in N) and stat values. Least squares on log10(odds)."""
    xs = [math.log10(r["odds"]) for r in neighbours]
    ys = [r[stat] for r in neighbours]
    n = len(xs); mx, my = sum(xs) / n, sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    slope = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx if sxx else 0.0
    return round(my + slope * (math.log10(new_odds) - mx))
```

Derived columns belong in the generator (or a sheet formula exported as values), with a unit test. When a designer overrides a derived value, the sheet should have an explicit `override` column so the override is visible and survives regeneration.

## Stage 4: generate Luau

The generator writes a module that is **deterministic** (same input, byte-identical output: sort keys, fixed float formatting), **marked as generated**, and **typed** so scripts get autocomplete and the type checker catches field typos.

```python
# tools/gen_luau.py : rows -> ItemsData.luau
def lua(v, indent=1):
    pad = "\t" * indent
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, int): return str(v)
    if isinstance(v, float): return repr(round(v, 6))
    if isinstance(v, str): return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(v, list): return "{ " + ", ".join(lua(x, indent) for x in v) + " }"
    if isinstance(v, dict):
        inner = ",\n".join(f"{pad}\t{k} = {lua(v[k], indent + 1)}" for k in sorted(v))
        return "{\n" + inner + f",\n{pad}}}"
    raise TypeError(type(v))

def generate(rows, out_path, source_name):
    lines = [
        "--!strict",
        f"-- GENERATED from {source_name} by tools/gen_luau.py. Do not edit by hand.",
        "export type Item = { id: string, name: string, rarity: string, odds: number, power: number, income: number, health: number, icon: string }",
        "local Items: { [string]: Item } = {",
    ]
    for r in sorted(rows, key=lambda r: r["id"]):
        lines.append(f'\t["{r["id"]}"] = {lua(r, 1)},')
    lines += ["}", "", "return table.freeze(Items)", ""]
    open(out_path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
```

`table.freeze` makes the shipped table read-only at runtime, so a stray script cannot mutate shared config (it is shallow: nested tables need freezing too if that matters to you).

Size: a ModuleScript's source has a practical cap of 200,000 characters (measured in one production game). Big tables should be **split by key** into child modules (`ItemsData.Common`, `ItemsData.Rare`...) and merged by a small parent. The reference project's main config module sat at about 199,400 characters, and every later content batch went into a child module with an `Apply` hook called from the parent (`GameConfig.Relics`, `GameConfig.Milestones`), rather than growing the parent.

## Stage 5: install

### With Rojo

The generated file is in `src/shared/`; Rojo syncs it. CI regenerates from the CSVs and fails if the committed file differs ("generated file out of date"). Done. See [[Code Pipeline - Rojo Git and CI]].

### Without Rojo: the one-insert edit

When config lives only in a shared place (several people or agents editing), a full rewrite of the module is dangerous: you overwrite whatever someone else changed since you last read it. The reference project's rule for its shared config module was **one insert**, and the install stage did all of this itself:

1. **Re-read** the module's source right before editing (never from an older copy).
2. **Back up** the current source (one copy in a work-in-progress folder, removed after verification).
3. **Insert** the new rows at one anchor (a marker comment), touching nothing else.
4. **Compile**: `loadstring(newSource)` must return a function.
5. **Scan**: the use-before-definition scanner must return no findings.
6. **Size**: under the cap.
7. **Clone-require**: clone the module beside the original (so relative requires still resolve), require the clone, check the new ids are present and well-formed, destroy the clone. A plain `require` in Edit returns the cached old copy.
8. **Write** only if all gates pass; otherwise restore nothing (nothing was written) and report.

```lua
--!strict
-- One-insert config edit for the command bar or a plugin (Script.Source is writable there).
-- Inserts `block` immediately after the line containing `anchor`.
local function oneInsert(module: ModuleScript, anchor: string, block: string, expectIds: { string }): (boolean, string)
	local src = (module :: any).Source :: string           -- 1. re-read now
	local s, e = string.find(src, anchor, 1, true)
	if not s then return false, "anchor not found" end
	local lineEnd = string.find(src, "\n", e, true) or #src
	local newSrc = string.sub(src, 1, lineEnd) .. block .. "\n" .. string.sub(src, lineEnd + 1)

	if #newSrc >= 200000 then return false, "over the source size cap" end
	local fn, err = loadstring(newSrc)                     -- 4. compile
	if not fn then return false, "compile: " .. tostring(err) end

	local probe = module:Clone()                            -- 7. clone-require beside the original
	probe.Name = module.Name .. "_Probe"
	;(probe :: any).Source = newSrc
	probe.Parent = module.Parent
	local ok, data = pcall(require, probe)
	probe:Destroy()
	if not ok then return false, "require: " .. tostring(data) end
	for _, id in expectIds do
		if type(data) ~= "table" or (data :: any).Items == nil or (data :: any).Items[id] == nil then
			return false, "missing after insert: " .. id
		end
	end

	local backup = module:Clone()                           -- 2. backup (one copy)
	backup.Name = module.Name .. "_pre_" .. os.date("!%Y%m%d%H%M")
	backup.Parent = game:GetService("ServerStorage")
	;(module :: any).Source = newSrc                        -- 8. write
	return true, ("inserted %d chars; backup %s"):format(#block, backup.Name)
end

return oneInsert
```

The scanner step (5) is project-specific and omitted here; add yours before the write. Use `ScriptEditorService:UpdateSourceAsync` from plugins if the script may be open in an editor tab, since direct `Source` writes can conflict with open editors.

### Batch rule

Make **one config edit per batch**, not one per item. The reference project uploaded all icons first, then wrote all the items of a 15-weapon batch in a single edit, which meant one backup, one compile and one review instead of fifteen.

## Stage 6: read back and diff

Close the loop. A dump script in Studio serialises the live config (via clone-require) to JSON and posts it to a local receiver or prints it; a comparison script diffs it against the sheet's generated data. The reference project dumped its config, kits and enemy data to JSON and **generated its documentation vault** (one note per item, zone and enemy) from those dumps, so the docs always matched the game. Read-back also catches the classic "someone hand-edited a value in Studio" drift.

```lua
-- Dump a config module to JSON (command bar). Clone-require to bypass the Edit cache.
local HttpService = game:GetService("HttpService")
local probe = game.ReplicatedStorage.ItemsData:Clone()
probe.Parent = game.ReplicatedStorage
local data = require(probe)
probe:Destroy()
local json = HttpService:JSONEncode(data)
print(#json, "bytes")
-- In Studio with HttpService enabled you can POST it to a local receiver:
-- HttpService:PostAsync("http://127.0.0.1:8877/dump/items.json", json)
```

`JSONEncode` cannot encode Instances, functions, CFrames or Color3 values; convert those to plain tables or strings in the dump function.

## Kill switches and flags

Every new system ships with a flag that turns it off without a code change. The reference project kept a table of them in its tooling notes (a cutscene `Enabled` value, a shared move's `Enabled`, a "mutations enabled" config flag, a "rarity locks" boolean that restored per-world caps when set back to true). Make flags:

- **data, not comments** (`C.RarityLocks = false`), read at the point of use;
- **documented** next to the feature, with the revert instruction;
- **live-overridable** for the dangerous ones, through [[Global State and Live Config]], so you can switch a broken feature off on running servers.

## Common mistakes

- **Display names as keys.** Renaming "Iron Sword" to "Iron Blade" orphans every saved inventory. Ids.
- **Hand edits in Studio to generated modules.** Overwritten on the next generation. Edit the sheet.
- **Floats formatted differently each run.** Noisy diffs hide real changes. Deterministic output.
- **One giant module.** Hits the source cap and conflicts constantly. Split by key.
- **Validating in the game.** Errors appear as nil-index crashes in Play. Validate offline.
- **Odds and stats typed by feel.** Fit to neighbours; document overrides.
- **Many small edits to a shared module.** Each is a chance to clobber someone. One insert per batch.

## Checklist

- [ ] Sheet with stable ids and typed columns, exported as UTF-8 CSV into Git
- [ ] Schema validation plus cross-table references in CI
- [ ] Derived stats computed by tested code, overrides explicit
- [ ] Generated module deterministic, typed, frozen, marked GENERATED
- [ ] Large tables split into child modules under the size cap
- [ ] Install by Rojo, or by a gated one-insert edit with backup and clone-require
- [ ] One edit per batch
- [ ] Read-back dump and diff
- [ ] Every system has a documented kill switch

## See also

[[Balancing with Spreadsheets and Data]] · [[Economies and Currencies]] · [[RNG Drops and Luck Systems]] · [[Progression Levels and Unlocks]] · [[Global State and Live Config]] · [[Module Scripts and Requiring]] · [[Code Pipeline - Rojo Git and CI]] · [[Live Content Pipeline]] · [[Pipeline Design Principles]]

## Nuances and edge cases

1. **Spreadsheets are not a database.** Sheets allow merged cells, formulas that silently change type, hidden rows, trailing spaces and two people editing the same row. The validator is the only thing standing between those habits and the game. Treat the exported CSV, not the live sheet, as the input, and keep it in source control so every change has a diff and an author.
2. **Formula drift.** A derived column (price from tier, health from level) is a formula in the sheet. Someone overwrites one cell with a typed number to "fix" an outlier, and the formula is gone for that row forever. Generate derived values in the pipeline (Stage 3) instead of in the sheet, and keep explicit overrides in their own column so they are visible.
3. **Live config versus generated modules.** Values in generated ModuleScripts change only with a publish. Values that need to change without a publish (event multipliers, prices during a sale, kill switches) belong in live config. Choosing wrong in either direction hurts: everything live makes the game depend on a remote service at startup; everything baked means a restart for every tweak.
4. **Changing a value is a migration when players own the thing.** Lowering a sword's damage changes every saved copy at once, which is usually intended. Changing an item's id, removing an item or changing what a stat means is a data migration, not a config edit. Flag removals and id changes in the validator so they cannot ship by accident.
5. **Floating-point and display.** A drop chance of 0.1 stored as a float, summed across 10 rows, may not total exactly 1. Validate sums with a tolerance and, for displayed odds, compute from the same numbers the roll uses.
6. **Large tables and memory.** A 5,000-row item table generated into one module is required by every client that needs any item. Split by category and load what each side needs; the server may need full stats while clients need names and icons.
7. **Team scale.** One designer can edit the sheet directly. Several designers need ownership of tabs or columns, or a review step for the CSV diff, or changes collide and one person's tuning overwrites another's.

## More common mistakes

1. **Locale-dependent CSV export.** Symptom: decimals arrive as "0,5" from a European machine and parse as strings. Fix: export with a fixed locale or validate number formats explicitly.
2. **Trailing spaces in ids.** Symptom: "sword_iron " is a different key and a lookup fails at runtime. Fix: trim and reject whitespace in the validator.
3. **Booleans as text.** Symptom: "FALSE" is a non-empty string and reads as true in Luau. Fix: parse booleans explicitly and reject anything else.
4. **Hidden rows exported.** Symptom: removed test items appear in the shop. Fix: an explicit "enabled" column, never hidden rows.
5. **Generated code not marked as generated.** Symptom: someone hand-edits it and loses the change on the next run. Fix: a header comment and a CI check that the file matches the generator output.
6. **No read-back.** Symptom: the game runs on stale values because an install silently failed. Fix: read back from Studio and diff, as in Stage 6.

## Related decisions

- [[Feature Flags and Staged Rollouts]]: values that should change without a publish.
- [[Simulating an Economy Before Launch]]: running the generated numbers through a model first.
- [[Pricing Curves and Upgrade Costs]]: the formulas the derive stage should encode.
- [[Drop Tables Rarity and Pity Systems]]: odds tables that must validate to a clean total.
- [[Schema Migrations - Worked Case Studies]]: when a config change becomes a data change.
- [[Code Review for Luau Teams]]: reviewing CSV diffs like code.
- [[Economy Telemetry and Balancing Live]]: feeding live data back into the sheet.
- [[Probability and Statistics for Designers]]: checking odds and expected values from the sheet.

## Connected notes
<!-- auto-links:start -->
[[Icon and Thumbnail Rendering Pipeline]] · [[Build Test and Release Pipeline]] · [[Cookbook - Tables Strings and Time]] · [[MCP Workflows for Scripting and Debugging]] · [[AI Agents and Autonomous Workflows]] · [[Studio Tooling Architecture]]
<!-- auto-links:end -->
