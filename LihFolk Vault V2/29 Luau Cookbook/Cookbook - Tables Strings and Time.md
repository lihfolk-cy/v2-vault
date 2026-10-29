---
tags: [luau, cookbook, tables, strings, time, recipes]
---
# Cookbook - Tables Strings and Time

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Assignment instead of copy; shallow copy where a deep copy was needed.
> - Avoid: Random comparators in `table.sort`.
> - Avoid: Forward iteration with `table.remove`.
> - Config tables are deep-frozen.
> - Random picks run on the server with `Random` objects.
> - Number formatting truncates near tier boundaries.
>
> Cost: TL;DR ~120 tok · whole note ~4.9k tok. Read more: ## 11. Pick the right clock · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Recipes for the utility code every project ends up writing: copying and shuffling tables, weighted picks, safe removal while iterating, number and duration formatting, splitting and trimming text, and the clocks you should use for cooldowns, countdowns and daily resets. Code is `--!strict` Luau, reviewed, not run. The background is in [[Tables Metatables and OOP]], [[Strings Patterns and Formatting]], [[Task Library Coroutines and Yielding]] and [[Luau Performance Patterns with Benchmarks]].

---

## 1. Copy a table: shallow or deep

**Problem.** `local b = a` does not copy; both names point at one table, and editing `b` edits `a`.

```lua
--!strict
local function deepCopy<T>(value: T, seen: { [any]: any }?): T
	if typeof(value) ~= "table" then
		return value
	end
	local visited = seen or {}
	if visited[value] then
		return visited[value]
	end
	local out = {}
	visited[value] = out
	for k, v in value :: any do
		out[deepCopy(k, visited)] = deepCopy(v, visited)
	end
	return out :: any
end

local original = { name = "Sword", stats = { damage = 10 } }
local shallow = table.clone(original) -- new outer table, same `stats` table
local deep = deepCopy(original)       -- everything new
```

**Why it works.** `table.clone` copies one level (and keeps the metatable) and is fast (Roblox docs (as of October 2026)). The deep copy recurses, and the `visited` map handles cycles and shared sub-tables without infinite recursion.

**Pitfall.** People expect `table.clone` to fail on a frozen table; it does not, and the copy it returns is not frozen (per the Luau library docs; worth a quick check in your Studio build), which makes it the easy way to get an editable version of frozen config. The deep copy above does not copy metatables; add `setmetatable(out, getmetatable(value))` if your data uses them (most saved data should not).

---

## 2. Freeze configuration so nobody edits it by accident

**Problem.** A gameplay script does `Config.Items.Sword.price = 0` while testing and forgets to remove it.

```lua
--!strict
local function deepFreeze<T>(t: T): T
	if typeof(t) == "table" and not table.isfrozen(t :: any) then
		for _, v in t :: any do
			deepFreeze(v)
		end
		table.freeze(t :: any)
	end
	return t
end

local Config = deepFreeze({
	Items = {
		Sword = { price = 100 },
	},
})
return Config
```

**Why it works.** `table.freeze` makes writes to that table raise an error (Roblox docs (as of October 2026)), so mistakes fail loudly at the line that caused them. It only freezes one level, hence the recursion.

**Pitfall.** Frozen tables cannot be reconciled or migrated in place. Freeze config and constants, not player data. Code that needs a modified version should `table.clone` first.

---

## 3. Shuffle an array fairly

**Problem.** Randomise map rotation or card order without bias.

```lua
--!strict
local rng = Random.new()

local function shuffle<T>(list: { T })
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end
```

**Why it works.** Fisher-Yates swaps each position with a random earlier (or same) position once, giving every order an equal chance. `Random` also has a built-in `Shuffle` method (Roblox docs (as of October 2026)); either is fine.

**Pitfall.** Sorting with a random comparator (`table.sort(t, function() return math.random() < 0.5 end)`) is biased and can error with "invalid order function". Do not do it.

---

## 4. Weighted random pick

**Problem.** Drop table: Common 70, Rare 25, Legendary 5.

```lua
--!strict
type Entry = { id: string, weight: number }

local rng = Random.new()

local function pickWeighted(entries: { Entry }): string?
	local total = 0
	for _, e in entries do
		total += e.weight
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, e in entries do
		roll -= e.weight
		if roll < 0 then
			return e.id
		end
	end
	return entries[#entries].id -- float safety net
end
```

**Why it works.** Lay the weights end to end on a line of length `total`, drop a random point on it, and walk until you pass it. Weights need not add to 100.

**Pitfall.** Rolls that grant value must happen on the server. If you sell randomised items, the published odds must match the real weights exactly ([[Paid Random Items and Odds Disclosure in Practice]]). For luck boosts and pity systems see [[RNG Drops and Luck Systems]] and [[Rarity Ladders and Drop Pacing Math]].

---

## 5. Remove items while iterating

**Problem.** Removing from an array inside a forward `for` loop skips the element after each removal.

```lua
--!strict
-- Order matters: walk backwards.
local function removeWhere<T>(list: { T }, predicate: (T) -> boolean)
	for i = #list, 1, -1 do
		if predicate(list[i]) then
			table.remove(list, i)
		end
	end
end

-- Order does not matter: swap with last and pop, O(1) per removal.
local function swapRemove<T>(list: { T }, index: number)
	local last = #list
	list[index] = list[last]
	list[last] = nil
end
```

**Why it works.** Walking backwards means a removal only shifts elements you have already visited. Swap-remove avoids shifting at all, which matters for big lists such as projectile pools.

**Pitfall.** For dictionaries, assigning `t[k] = nil` to the current key during a generalised `for k, v in t` loop is allowed; adding new keys during the loop is not safe. Collect additions and apply them after.

---

## 6. Count, find and check tables

**Problem.** `#` only works for arrays; dictionaries always report 0.

```lua
--!strict
local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function isEmpty(t: { [any]: any }): boolean
	return next(t) == nil
end

local list = { "a", "b", "c" }
print(table.find(list, "b")) --> 2
print(table.find(list, "z")) --> nil
```

**Why it works.** Counting requires a walk because dictionaries do not store their size. `next(t) == nil` checks emptiness in constant time. `table.find` does a linear search of the array part.

**Pitfall.** `#` on an array with holes (`{1, nil, 3}`) can return either border; never put `nil` in arrays. If you call `table.find` in a hot loop over a long list, build a set (`{ [value] = true }`) once instead.

---

## 7. Abbreviate big numbers

**Problem.** Show `1234567` as `1.23M` and `950` as `950`.

```lua
--!strict
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

local function abbreviate(n: number): string
	if n ~= n then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	local tier = 1
	while n >= 1000 and tier < #SUFFIXES do
		n /= 1000
		tier += 1
	end
	if tier == 1 then
		return sign .. tostring(math.floor(n))
	end
	-- Truncate rather than round so 999,999 shows 999K, not 1000K.
	local truncated = math.floor(n * 100) / 100
	local text = string.format("%.2f", truncated):gsub("%.?0+$", "")
	return sign .. text .. SUFFIXES[tier]
end

print(abbreviate(1234567)) --> 1.23M
print(abbreviate(1500))    --> 1.5K
```

**Why it works.** Dividing by 1000 until the number is below 1000 finds the tier. Truncating avoids the "1000K" display bug that rounding produces near tier boundaries. The `gsub` strips trailing zeros and a bare decimal point.

**Pitfall.** `gsub` returns two values (the string and a count); assigning to one variable as above keeps only the string, but putting it directly inside a function call would pass both. Doubles hold integers exactly only up to 2^53 (about 9 quadrillion); simulator economies that go further need a different number representation ([[Economy Inflation Sinks and Faucets Math]]).

---

## 8. Add thousands separators

**Problem.** Show `1234567` as `1,234,567`.

```lua
--!strict
local function commas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if n < 0 then "-" else "") .. out
end

print(commas(1234567)) --> 1,234,567
```

**Why it works.** Reversing the digits lets a simple pattern insert a comma after every three, then reversing again restores the order. The check removes a leading comma when the digit count is a multiple of three.

**Pitfall.** Separator conventions differ by language (some use dots or spaces). If your game is localised, format numbers per locale rather than hard-coding commas ([[Localization]]).

---

## 9. Format a duration as a timer

**Problem.** Show 3725 seconds as `1:02:05`, and 65 as `1:05`.

```lua
--!strict
local function formatDuration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end
```

**Why it works.** Floor division `//` and modulo split total seconds into units; `%02d` pads with a leading zero.

**Pitfall.** Floor before formatting, or a countdown at 0.4 seconds shows `0:00` while the round is still running; some games use `math.ceil` for countdowns so 0:00 appears only at the end. Pick one and use it everywhere.

---

## 10. Split, trim and parse simple text

**Problem.** Parse a command like `"  /give  Sword 3 "` or a comma-separated config line.

```lua
--!strict
local function trim(s: string): string
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function words(s: string): { string }
	local out = {}
	for word in s:gmatch("%S+") do
		table.insert(out, word)
	end
	return out
end

local parts = string.split("a,b,,c", ",") --> { "a", "b", "", "c" }
local args = words(trim("  /give  Sword 3 ")) --> { "/give", "Sword", "3" }
local amount = tonumber(args[3]) --> 3 (or nil if not a number)
```

**Why it works.** `%s` matches whitespace and `%S+` a run of non-whitespace, so `gmatch` yields each word regardless of spacing. `string.split` keeps empty fields, which is what you want for CSV-like data.

**Pitfall.** `string.split` takes a plain separator, but `gsub` and `gmatch` use Lua patterns, where `.`, `%`, `-` and others are special: splitting on `"."` with `gmatch` needs `"[^%.]+"`. Text from players must be filtered with `TextService` before other players see it ([[Strings Patterns and Formatting]], [[Text Chat Customization with TextChatService]]).

---

## 11. Pick the right clock

**Problem.** Cooldowns, countdowns, daily rewards and benchmarks each need a different notion of time.

```lua
--!strict
local start = os.clock()               -- CPU time, high precision: benchmarks and server-only cooldowns
local unix = os.time()                 -- whole seconds since 1970 UTC: daily resets, saved timestamps
local now = DateTime.now()             -- UTC with milliseconds, plus formatting helpers
local shared = workspace:GetServerTimeNow() -- synchronised server time, readable on clients

print(os.clock() - start, unix, now.UnixTimestampMillis, shared)
```

| Need | Use | Why |
|---|---|---|
| Measure how long code took | `os.clock()` | Highest resolution, monotonic within a process |
| Server-only cooldown | `os.clock()` | No replication involved |
| Countdown shown on clients that matches the server | `workspace:GetServerTimeNow()` | Same clock on both sides |
| Timestamps saved in DataStores, daily or weekly resets | `os.time()` or `DateTime` | Wall-clock UTC, survives server restarts |

**Why it works.** Each clock answers a different question. `os.clock` is not tied to a calendar and resets per server; `os.time` is calendar time; `GetServerTimeNow` is synchronised so clients can compute "time left" from one replicated end time.

**Pitfall.** Never store `os.clock()` values in saved data; they mean nothing on another server. Never use a client's `os.time()` for anything the server cares about: a player can change their device clock. The vault's notes agree on this split ([[Debugging Client-Server Desync]]).

---

## 12. Daily reset and time until next reset

**Problem.** Daily rewards reset at 00:00 UTC; show "resets in 5:12:09".

```lua
--!strict
local DAY = 86400

local function dayIndex(unixSeconds: number): number
	return unixSeconds // DAY -- whole UTC days since 1970
end

local function secondsUntilNextReset(unixSeconds: number): number
	return DAY - (unixSeconds % DAY)
end

local function canClaim(lastClaimDay: number?, nowUnix: number): boolean
	return lastClaimDay == nil or dayIndex(nowUnix) > lastClaimDay
end

-- Server: if canClaim(data.lastClaimDay, os.time()) then ... data.lastClaimDay = dayIndex(os.time()) end
-- Client display: formatDuration(secondsUntilNextReset(os.time())) from recipe 9,
-- or better, send the server's os.time() once and keep an offset.
```

**Why it works.** Storing the day number instead of a timestamp makes "has a new day started" one integer comparison and avoids 24-hour rolling windows that drift later each day.

**Pitfall.** For a reset at a local time other than UTC midnight, add a fixed offset in seconds before dividing; daylight saving changes make true local time harder, which is why most games stick to UTC. Streaks need "claimed yesterday" logic: `dayIndex(now) == lastClaimDay + 1` continues a streak, anything larger breaks it. A full system is built in [[Daily Rewards System End to End]].

---

## Common mistakes

- Assignment instead of copy; shallow copy where a deep copy was needed.
- Random comparators in `table.sort`.
- Forward iteration with `table.remove`.
- `#` on dictionaries.
- Client clocks used for server decisions.

## Checklist

- [ ] Config tables are deep-frozen.
- [ ] Random picks run on the server with `Random` objects.
- [ ] Number formatting truncates near tier boundaries.
- [ ] Every timer uses the clock from the table in recipe 11.
- [ ] Daily resets store a day index, not a raw timestamp.

## See also

[[Luau Cookbook Start Here]], [[Luau Language Essentials]], [[Buffers and Binary Data]], [[Cookbook - Data and Saving]], [[Cookbook - UI]], [[Balancing with Spreadsheets and Data]]

## Nuances and edge cases

1. **`table.freeze` is shallow.** Freezing a config table stops edits to its top level only; nested tables stay writable unless you freeze them too (Roblox docs, as of October 2026). A deep-freeze helper that walks the table once at load is cheap and catches the "someone edited `Config.Weapons.Sword.Damage` at runtime" bug. When you do need a modified copy, `table.clone` returns a shallow copy that is not frozen (Luau behaviour as understood; not re-checked against the docs this round).
2. **Bytes versus characters.** `#s`, `string.len` and `string.sub` count bytes. A player name or chat text with accents or emoji uses several bytes per character, so truncating with `string.sub(s, 1, 12)` can cut a character in half and display a broken glyph. Use `utf8.len` to count and `utf8.offset` to find a safe cut point when shortening user-facing text.
3. **Number precision.** Luau numbers are 64-bit doubles. Integers are exact up to 2^53 (about 9 quadrillion). Simulator currencies that pass that point stop incrementing by small amounts: adding 1 to 2^53 does nothing. If a game's numbers can grow that far, store a mantissa and exponent or use a big-number scheme, and format from that.
4. **Abbreviation edge cases.** Rounding at boundaries produces "1000K" instead of "1M" (999,950 rounds up). Round first, then pick the suffix, or check whether the rounded value reached the next tier. Negative numbers and zero need their own branch too.
5. **Locale.** Thousands separators and decimal points differ by language: "1,234.5" in English is "1.234,5" in German. A hand-written comma formatter is fine for an English-first game but will be wrong after localization. If the game is localized, format through the localization layer or keep numbers abbreviated (which reads well in every language).
6. **Clock choice at scale.** `os.clock()` is per-process CPU-style time; fine for measuring and for server-only cooldowns. `workspace:GetServerTimeNow()` is the shared clock for countdowns seen on many clients. `os.time()` is UTC seconds for saved timestamps (Roblox docs, as of October 2026). Mixing them is the common bug: saving `os.clock()` into a DataStore produces a number that is meaningless on the next server.
7. **Daily resets and time zones.** A reset at UTC midnight is late evening in the Americas and morning in Asia. That is fine, but say it in the UI with a countdown rather than "resets at midnight", because "midnight" means local time to players. If a game wants local-midnight resets, the client's time zone is untrusted input; use it for display only and keep the server deciding in UTC.
8. **Weighted random with tiny weights.** With weights like 0.001 next to 1000, floating-point sums are fine, but designers often edit weights without re-normalising and the displayed odds drift from the real ones. Compute displayed odds from the same table the roll uses, never from a separate copy.
9. **Shuffle and RNG streams.** Use one `Random.new()` object per purpose (loot, map generation, cosmetic) so a change in one system does not shift results in another. Seeding with a fixed value makes tests reproducible; seeding live loot with a guessable value (like `os.time()`) on the client makes outcomes predictable to exploiters, so live rolls belong on the server.

## More common mistakes

1. **Deep config edited at runtime.** Symptom: one server's values drift after a buff function modifies the shared config table. Fix: deep-freeze config and copy before modifying.
2. **Emoji cut in half.** Symptom: truncated names end with a square or question mark. Fix: cut with `utf8.offset`.
3. **Saving `tick()` or `os.clock()`.** Symptom: daily rewards unlock instantly or never after a server change. Fix: save `os.time()` (UTC seconds).
4. **"1000K" display.** Symptom: wrong suffix right below a tier boundary. Fix: round, then choose the suffix.
5. **Odds shown from a separate table.** Symptom: displayed odds do not match observed drops; players report it. Fix: one source table for roll and display.
6. **Parsing user text with patterns that assume ASCII.** Symptom: `%a` rejects accented letters in a name field. Fix: validate by length and filter through the text filter instead of character classes where possible.
7. **Counting a dictionary with `#`.** Symptom: an inventory with keyed items reports 0 items. Fix: count with a loop, or keep a separate counter updated on insert and remove.

## Related decisions

- [[Big Numbers Precision and Formatting]]: what to do when currencies pass the exact-integer range.
- [[Localization]]: why hand-written number formats break in other languages.
- [[Probability and Statistics for Designers]]: the maths behind weighted picks and displayed odds.
- [[Paid Random Items and Odds Disclosure in Practice]]: why displayed odds must come from the roll table.
- [[Daily Rewards System End to End]]: a full build that uses the UTC reset logic.
- [[Seeds Determinism and Reproducible Worlds]]: separate RNG streams per system.
- [[Global State and Live Config]]: frozen config tables that update from live data.
- [[Text Fonts and Rich Text]]: displaying formatted numbers and truncated names.
- [[Serialization Formats for Saves and Networking]]: how tables and timestamps are stored.

## Connected notes
<!-- auto-links:start -->
[[Localization Pipeline]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Retention and Return Hooks]] · [[Metatables and OOP - When and When Not]] · [[Drop Tables Rarity and Pity Systems]] · [[Menu Archetypes - Shop Settings Codes Rewards]]
<!-- auto-links:end -->
