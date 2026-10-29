---
tags: [field-notes, luau, ipairs, tables, cleanup, memory-leaks, sound, type/guide, area/audio, level/intermediate, area/performance, api/Sound]
---
# ipairs Stops at the First nil - Cleanup Tables That Leak

<!-- tldr:start -->
> [!tldr] TL;DR
> - Looping sound never stops, gets louder: `ipairs` over a cleanup list with a `nil` before it -> `track()` that skips `nil`, or `table.pack(...).n`
> - Works on most weapons, leaks on one: That weapon's optional layer is missing -> Same; add a test weapon with every optional part missing
> - `#t` gives different answers after refactor: Table with holes; border is ambiguous -> Do not store `nil` in arrays
> - No array is built from values that can be `nil`.
> - Cleanup helpers have an `add` that ignores `nil`.
> - Varargs with possible holes use `select("#", ...)` or `table.pack`.
>
> Cost: TL;DR ~190 tok · whole note ~1.6k tok. Read more: ## Fixes that cannot skip · ## Where this hides in Roblox code · ## Common mistakes · ## Checklist
<!-- tldr:end -->

`ipairs` walks `t[1]`, `t[2]`, `t[3]` and stops at the first `nil`. Everyone knows that, and it still causes leaks, because the `nil` usually arrives later, from an optional value that was never `nil` when the code was written. This note shows the pattern that bit a shipped game, why the length operator does not save you, and the cleanup shapes that cannot skip items. Table basics are in [[Tables Metatables and OOP]]; leak hunting in [[Hunting Memory Leaks Step by Step]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## The bug

**Measured.** Each weapon played a set of looping sounds while swinging: a hum, an optional low layer, an optional high layer, and a guard loop. Cleanup was written like this:

```lua
-- BUG: if lo is nil, hi and guard are never stopped
local hum, lo, hi, guard = startSwingLoops(weapon)
local toStop = { hum, lo, hi, guard }

local function stopAll()
	for _, sound in ipairs(toStop) do
		sound:Stop()
		sound:Destroy()
	end
end
```

When a later weapon had no low layer, `lo` was `nil`, `ipairs` stopped after `hum`, and the high and guard loops kept playing forever. They stacked with every swing. Players heard an ever-louder whine that only went away on rejoin, and each orphaned `Sound` stayed in memory. No error was raised anywhere.

## Why `#` does not help

A table constructor with a `nil` in the middle, such as `{ hum, nil, hi, guard }`, has a "border" problem: the Luau length operator returns *some* index `n` where `t[n] ~= nil` and `t[n + 1] == nil`. For a table with a hole, both 1 and 4 are valid answers, and which one you get depends on how the table was built (Luau reference behaviour, rule of thumb: never rely on it). So `for i = 1, #t` is not a fix either; it may work in testing and fail after an unrelated change.

## Fixes that cannot skip

**1. Never put possibly-nil values in an array.** Collect only what exists:

```lua
local toStop = {}
local function track(item: Instance?)
	if item then
		table.insert(toStop, item)
	end
end

local hum, lo, hi, guard = startSwingLoops(weapon)
track(hum); track(lo); track(hi); track(guard)
```

This is the shape most cleanup helpers (maids, janitors, trove-style classes) use: an `add` method that ignores `nil`.

**2. When you really do have a variable argument list with holes, count with `select("#", ...)`,** which counts trailing and middle `nil` values, or use `table.pack`, which stores that count in `n`:

```lua
local function stopEach(...: Sound?)
	local args = table.pack(...)
	for i = 1, args.n do
		local s = args[i]
		if s then
			s:Stop()
			s:Destroy()
		end
	end
end

stopEach(startSwingLoops(weapon)) -- safe even if the second value is nil
```

**3. Use a keyed table when the items have names.** `{ hum = hum, lo = lo, hi = hi, guard = guard }` iterated with generalised iteration (`for _, s in t do`) visits every non-nil value regardless of holes. Order is not guaranteed, which does not matter for cleanup.

## Where this hides in Roblox code

- **Return values from optional lookups.** `FindFirstChild` returns `nil`; packing several results into an array is the classic setup.
- **Config tables edited by hand.** `Layers = { "Hum", nil, "High" }` after someone "temporarily removes" an entry by setting it to `nil`.
- **`table.remove` versus assignment.** `t[i] = nil` in the middle of an array makes a hole; `table.remove(t, i)` shifts the rest down. Removing during an `ipairs` loop with `table.remove` skips the next element; iterate backwards instead.
- **Connections lists.** A cleanup list of `RBXScriptConnection` values where one connect was conditional.
- **Function results in table constructors.** `{ a(), b() }` keeps all of `b()`'s results but only the first of `a()`'s, and a `nil` first result from `a()` makes `[1]` a hole.

A quick audit: search the codebase for `ipairs({` and for `in ipairs(` on tables built from more than one function call or `FindFirstChild`. Each hit is either provably dense or a bug waiting for content.

## Looping sounds are the worst case

Most leaked instances are invisible. A leaked looping `Sound` is audible and grows: every missed stop adds another voice. If you see a "sound gets louder over a session" report, look for skipped cleanup first, then for loops started on every swing without stopping the previous one. Cap concurrent instances per sound key as a safety net ([[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]]).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Looping sound never stops, gets louder | `ipairs` over a cleanup list with a `nil` before it | `track()` that skips `nil`, or `table.pack(...).n` |
| Works on most weapons, leaks on one | That weapon's optional layer is missing | Same; add a test weapon with every optional part missing |
| `#t` gives different answers after refactor | Table with holes; border is ambiguous | Do not store `nil` in arrays |
| Every other item skipped when clearing | `table.remove` inside a forward loop | Iterate from `#t` down to 1 |

## Checklist

- [ ] No array is built from values that can be `nil`.
- [ ] Cleanup helpers have an `add` that ignores `nil`.
- [ ] Varargs with possible holes use `select("#", ...)` or `table.pack`.
- [ ] Looping sounds have a per-key instance cap.
- [ ] A test content item with every optional part missing exists and is played in QA.

## Connected notes
<!-- auto-links:start -->
[[Tables Metatables and OOP]] · Cookbook - Tables Strings and Time · Memory Budgets and Leaks · Hunting Memory Leaks Step by Step · [[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]] · [[Field Notes Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Streaming Joins - Frozen Players and Loading Screen Teardown]] · [[Animation Data Hygiene - Euler Wrap Joint Holes and Easing]] · [[Springs That Survive Long Frames - dt Clamps and NaN Guards]] · [[Client Hit Prediction for Melee Feedback]] · [[Running Many AI Agents on One Roblox Place]] · [[Resetting One Player's Data Safely]] · [[Layering Camera Feedback on the Default Camera]] · [[Hold-to-Attack Input That Never Sticks]]
<!-- related:end -->
