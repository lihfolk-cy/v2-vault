---
tags: [luau, strings, patterns, formatting, utf8, text, type/guide, area/scripting, level/intermediate, api/HttpService, api/DataStore]
---
# Strings Patterns and Formatting

<!-- tldr:start -->
> [!tldr] TL;DR
> - Search fails on names with `.` or `-`: Pattern magic -> `find(s, text, 1, true)`
> - Garbled last character: `sub` cut a multi-byte character -> `utf8.offset`
> - `0.30000000000000004` on screen: Raw `tostring` -> `string.format` / formatter
> - Literal searches use plain mode.
> - Length limits count code points, not bytes, where users see them.
> - Numbers shown to players go through formatters.
>
> Cost: TL;DR ~140 tok · whole note ~5.1k tok. Read more: ## 4. Patterns · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Strings in Luau are immutable sequences of **bytes**. That one fact explains most string bugs in Roblox games: `#` counts bytes, not letters; `string.sub` can cut an emoji in half; `string.upper` does not know accented letters. This note covers the string library, interpolation and `string.format`, Lua patterns (which are not regular expressions), UTF-8 handling, number and time formatting for UI, building strings efficiently, parsing, and the platform rules around user text.

---

## 1. Basics

```lua
local s = "Hello"
print(#s, s:len())          --> 5 5   (bytes)
print(s:upper(), s:lower()) --> HELLO hello
print(s:sub(2, 4))          --> ell   (1-based, inclusive; negative indices count from the end)
print(s:sub(-2))            --> lo
print(s:rep(3))             --> HelloHelloHello
print(s:reverse())          --> olleH
print(s:byte(1), string.char(72))  --> 72 H
print(("a,b,,c"):split(","))       --> { "a", "b", "", "c" }
```

Method syntax `s:upper()` works because strings share a metatable whose `__index` is the `string` library. In hot code `string.upper(s)` is slightly faster (builtin fast path, Docs: luau.org performance).

`string.split(s, sep?)` (Roblox/Luau addition): separator defaults to `","`, can be several characters, is plain text (not a pattern), keeps empty slices (`"foo,,bar"` gives `"foo", "", "bar"`), and `string.split("", ",")` returns `{ "" }` (Docs).

Comparison `<` on strings compares bytes (so `"Z" < "a"` is `true`). For user-facing sorting, compare `string.lower` forms and break ties.

---

## 2. Interpolation and string.format

```lua
local name, coins, ratio = "Ava", 1250, 0.4567
print(`{name} has {coins} coins ({ratio * 100}%)`)       -- interpolation calls tostring on each value
print(string.format("%s has %d coins (%.1f%%)", name, coins, ratio * 100))
--> Ava has 1250 coins (45.7%)
```

Interpolation is clearer for messages; `string.format` controls numeric output. Specifiers (Docs): `%d`/`%i` integer, `%u`, `%c` char code, `%o` octal, `%x`/`%X` hex, `%e`/`%E`, `%f`, `%g`/`%G`, `%q` quoted Luau string, `%s` string, `%*` any value via `tostring`, `%%` literal. Flags and width: `%5d`, `%-10s`, `%05.2f`, `%+d`.

Gotchas:
- `%d` with a non-integer number errors (Rule of thumb: Luau rejects fractional values for integer specifiers; round first with `math.floor`/`math.round`).
- `%s` requires a string or number; `%*` accepts anything.
- `%q` is for generating code or debug output, not UI.
- `tostring(1e16)` gives `1e+16`, and `tostring(0.1 + 0.2)` gives `0.30000000000000004`. Never show raw `tostring` of computed numbers to players; format them.
- Lint `FormatString` flags malformed format strings at edit time.

---

## 3. Formatting numbers and time for UI

```lua
--!strict
-- 1234567 -> "1,234,567"
local function commas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return (if n < 0 then "-" else "") .. out
end

-- 1250 -> "1.25K", 3400000 -> "3.4M"
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local function abbreviate(n: number): string
	if n ~= n then return "NaN" end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text = string.format("%.2f", scaled):gsub("%.?0+$", "")   -- trim trailing zeros
	return sign .. text .. SUFFIXES[tier + 1]
end

-- 3725 seconds -> "1:02:05", 65 -> "1:05"
local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end
```

Note in `commas` the parentheses: `gsub` returns two values (string and count); `s:reverse():gsub(...)` chained into `:reverse()` works because method calls use only the first. Wrapping a `gsub` call in parentheses when returning or concatenating avoids leaking the count into multiple returns.

Abbreviations: floating-point rounding at boundaries (999,999.5) can show "1000K"; guard by re-checking after rounding if it matters. For localized number formats, see [[Localization]].

Dates: `os.date("!%Y-%m-%d %H:%M", os.time())` formats UTC (`!` prefix); without `!`, local time of the machine (server time zone is not something to rely on). `DateTime.now():FormatLocalTime("LLL", locale)` formats in the player's locale on the client.

---

## 4. Patterns

Luau uses Lua patterns, a small matching language. They are **not** regular expressions: no alternation (`a|b`), no `{n,m}` counts, no lookahead, no non-greedy `*?` (use `-`).

### Character classes (Docs)

| Class | Matches | Upper-case form |
|---|---|---|
| `.` | any byte | |
| `%a` | letters | `%A` non-letters |
| `%d` | digits | `%D` |
| `%l` / `%u` | lower / upper case | |
| `%s` | whitespace | `%S` |
| `%w` | alphanumeric | `%W` |
| `%p` | punctuation | `%P` |
| `%c` | control characters | |
| `%x` | hex digits | |
| `%z` | the NUL byte | |
| `[abc]`, `[^abc]`, `[a-z]` | sets | |

Magic characters (Docs): `^ $ ( ) % . [ ] * + - ?`. Escape with `%` (`%.` matches a dot).

Quantifiers: `*` 0+ greedy, `+` 1+ greedy, `-` 0+ lazy, `?` optional. Anchors: `^` start, `$` end. Captures: `(...)`; `()` captures a position. `%b()` matches a balanced pair. `%1` back-references a capture. `%f[set]` (frontier) matches the transition into a set; it is in Lua 5.1 implementations and works in Luau (Rule of thumb; not in the Roblox pattern reference table).

Classes are byte-based and ASCII-only: `%a` does not match `é` or any non-Latin script.

### Functions

```lua
print(string.find("Level 12", "%d+"))               --> 7 8
print(string.find("a.b", ".", 1, true))             --> 2 2   (plain = true: no pattern magic)
print(string.match("Level 12", "%d+"))              --> 12
print(string.match("key=value", "^(%w+)=(%w+)$"))   --> key value

for word in string.gmatch("one two  three", "%S+") do print(word) end

print(string.gsub("hello world", "o", "0"))         --> hell0 w0rld 2
print((string.gsub("a-b-c", "%-", "+")))            --> a+b+c
print((string.gsub("$name won $n coins", "%$(%w+)", { name = "Ava", n = "50" })))
--> Ava won 50 coins     (table lookup; missing keys keep the original match)
print((string.gsub("abc", "%w", function(c) return c:upper() .. "." end)))
--> A.B.C.
```

Rules:
- Use `plain = true` in `find` whenever you search for literal text that may contain magic characters (player names, item names with dots or hyphens).
- To escape arbitrary text for use inside a pattern: `text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")`.
- In `gsub` replacement **strings**, `%` is special (`%1`, `%%`). A replacement string from user data must have `%` escaped as `%%`, or use a function.
- Pattern functions run in C and are fast; complex patterns on large strings in tight loops still cost.
- `gsub` callbacks must not yield.

### Parsing example: commands

```lua
--!strict
-- "/give Ava 50 sword" -> "give", { "Ava", "50", "sword" }
local function parseCommand(text: string): (string?, { string })
	local cmd, rest = string.match(text, "^/(%w+)%s*(.*)$")
	if not cmd then return nil, {} end
	local args = {}
	for token in string.gmatch(rest, "%S+") do
		table.insert(args, token)
	end
	return cmd:lower(), args
end
```

Always validate parsed values (`tonumber(args[2])` may be `nil`, `inf` or `nan`).

---

## 5. UTF-8

Roblox text is UTF-8. ASCII characters are 1 byte; accented Latin letters 2; most CJK 3; emoji 4 or more (and some "characters" are several code points joined).

```lua
local s = "héllo 😀"
print(#s)               --> 11 (bytes)
print(utf8.len(s))      --> 7  (code points); returns nil, position on invalid UTF-8
for position, codepoint in utf8.codes(s) do end      -- iterate code points (byte position, code point)
print(utf8.char(72, 233))                          --> Hé
print(utf8.offset(s, 3))                           --> byte index where the 3rd code point starts
```

Truncating safely:

```lua
local function truncate(s: string, maxChars: number): string
	if (utf8.len(s) or #s) <= maxChars then return s end
	local cut = utf8.offset(s, maxChars + 1)
	return if cut then s:sub(1, cut - 1) .. "..." else s
end
```

`string.sub(s, 1, 20)` on a display name can cut a multi-byte character and produce invalid UTF-8, which renders as a box or breaks `utf8` functions. Grapheme clusters (emoji with skin tones, flags) are several code points; `utf8.len` still over-counts what users see. For UI length limits, prefer `TextBox` constraints and server-side byte caps.

---

## 6. Building strings efficiently

Strings are immutable; each `..` creates a new string. Concatenating in a loop is O(n^2) in total copying:

```lua
-- Slow for large n
local out = ""
for i = 1, 10000 do out ..= tostring(i) .. "," end

-- Fast: collect and join once
local parts = table.create(10000)
for i = 1, 10000 do parts[i] = tostring(i) end
local joined = table.concat(parts, ",")
```

For binary output, write into a `buffer` instead ([[Buffers and Binary Data]]). For JSON, use `HttpService:JSONEncode` (it rejects mixed tables and non-string keys appropriately; see [[HttpService and External APIs]]).

`tonumber(s, base?)` parsing rules worth knowing: `tonumber("0x10")` is `16`, `tonumber("1e3")` is `1000`, `tonumber(" 5 ")` is `5` (surrounding whitespace allowed), `tonumber("5a")` is `nil`, `tonumber("inf")`/`tonumber("nan")` may parse (Rule of thumb; reject with `math.isfinite`). Validate ranges after parsing anything from a player.

---

## 7. Player-facing text: platform rules

Any text **typed by one player and shown to another** must go through Roblox's text filtering (`TextService:FilterStringAsync` and the result's `GetNonChatStringForBroadcastAsync` / `GetNonChatStringForUserAsync`, or TextChatService for chat). This includes pet names, sign text, guild names and trade notes. Showing unfiltered user text to others violates Roblox policy ([[Roblox Policies Ratings and Compliance]]). Filtering yields and can fail; handle it like any web call ([[Error Handling and Retries]]).

Rich text: if `RichText` is enabled on a label that displays user text or item names, escape `<`, `>`, `&`, `"`, `'` (as `&lt;` etc.) or players can inject markup ([[Text Fonts and Rich Text]]).

---

## 8. Validating text from clients

Every string that arrives through a remote is attacker-controlled. Before using it:

```lua
--!strict
local MAX_BYTES = 40

local function cleanPetName(raw: unknown): string?
	if typeof(raw) ~= "string" then return nil end
	if #raw == 0 or #raw > MAX_BYTES then return nil end           -- byte cap protects memory and DataStores
	if utf8.len(raw) == nil then return nil end                     -- reject invalid UTF-8
	if string.find(raw, "[%c]") then return nil end                 -- control characters, newlines
	local trimmed = string.match(raw, "^%s*(.-)%s*$") :: string     -- trim
	if trimmed == "" then return nil end
	return trimmed
end
```

Then filter it with `TextService` before showing it to anyone else, and store the **unfiltered** original only if you have a reason to (filtering is context dependent and is applied per viewer for some APIs; see [[Roblox Policies Ratings and Compliance]]).

Other validation habits:
- Item IDs, quest IDs and similar keys from clients should be looked up in a server table (`Items[id]`), never used to build instance paths or DataStore keys directly.
- Cap the length of anything you store per player; unbounded strings in a profile push you toward DataStore value limits ([[DataStore Fundamentals]]).
- Do not `loadstring` or pattern-match with client-provided patterns: a crafted pattern can be expensive to evaluate. Use `plain = true` for searches with client text.

## 9. Small utilities worth keeping

```lua
--!strict
local Text = {}

function Text.trim(s: string): string
	return (string.match(s, "^%s*(.-)%s*$") :: string)
end

function Text.startsWith(s: string, prefix: string): boolean
	return string.sub(s, 1, #prefix) == prefix
end

function Text.endsWith(s: string, suffix: string): boolean
	return suffix == "" or string.sub(s, -#suffix) == suffix
end

function Text.titleCase(s: string): string
	return (string.gsub(s, "(%a)([%w_']*)", function(first: string, rest: string)
		return first:upper() .. rest:lower()
	end))
end

function Text.plural(n: number, singular: string, plural: string?): string
	return if n == 1 then `1 {singular}` else `{n} {plural or singular .. "s"}`
end

function Text.escapeRichText(s: string): string
	return (string.gsub(s, "[<>&\"']", {
		["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;", ['"'] = "&quot;", ["'"] = "&apos;",
	}))
end

return table.freeze(Text)
```

`endsWith` guards the empty suffix because `string.sub(s, -0)` is `string.sub(s, 0)`, the whole string. `titleCase` only handles ASCII letters, consistent with the pattern classes.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Search fails on names with `.` or `-` | Pattern magic | `find(s, text, 1, true)` |
| Garbled last character | `sub` cut a multi-byte character | `utf8.offset` |
| `0.30000000000000004` on screen | Raw `tostring` | `string.format` / formatter |
| `gsub` result has an extra number | Two return values | Wrap in parentheses |
| Server hitches building a big report | Concatenation in a loop | `table.concat` |
| Replacement inserts wrong text | `%` in replacement string | Escape `%%` or use a function |
| Unfiltered player text visible to others | No filtering | `TextService` filtering |
| `string.format("%d", 2.5)` errors | Fractional value for `%d` | Round first |

## Checklist

- [ ] Literal searches use plain mode.
- [ ] Length limits count code points, not bytes, where users see them.
- [ ] Numbers shown to players go through formatters.
- [ ] Large strings are built with `table.concat` or buffers.
- [ ] All cross-player user text is filtered; rich text is escaped.

## See also

[[Luau Language Essentials]] · [[Buffers and Binary Data]] · [[Text Fonts and Rich Text]] · [[Localization]] · [[HttpService and External APIs]] · [[Roblox Policies Ratings and Compliance]] · [[Math Vectors and CFrames]]

## Nuances and edge cases

1. **Bytes are not characters.** `#s` and `string.sub` count bytes. An emoji is four bytes, an accented letter two. A name-length check of `#name <= 20` lets through 20 Latin letters but only five emoji, and `string.sub(name, 1, 20)` can cut a character in half. Use `utf8.len` for counting and `utf8.offset` to find safe cut points. Rule of thumb: count and limit in characters for player-facing rules, and in bytes only for storage budgets.
2. **Filtering is per audience and can fail.** Player-written text shown to other players must go through `TextService:FilterStringAsync`, which returns a result object you then ask for a broadcast or per-user string (Roblox docs, as of October 2026). The call yields and can error. The safe default when it errors is to show nothing (fail closed), never the raw text. Filtering is also context-dependent: the same string may be filtered differently for a younger recipient, so a "filter once, cache forever, show everyone" approach is wrong for per-user text.
3. **Rich text needs escaping.** If a label has `RichText` on and you insert a player name containing `<`, `>` or `&`, the markup breaks or a player can inject tags (colour, size) into your UI. Escape those three characters (and quotes inside attributes) before inserting any dynamic text into a rich text label.
4. **Patterns are not regular expressions.** There is no alternation (`a|b`), no `{n,m}` counts and no lookahead. Teams porting validation from other languages write patterns that silently match something else. When a rule needs alternation, run two patterns or parse by hand with `string.split` and lookups.
5. **Localization breaks concatenation.** `"You have " .. n .. " coins"` cannot be translated, because other languages reorder words and change plural forms. Build player-facing strings from keys with named parameters through the localization system (see [[Localization]]) instead of concatenating fragments in code.
6. **Number formatting is locale-flavoured.** A thousands separator of `,` reads as a decimal point in many countries. For short, universal UI numbers, suffix notation (`1.2K`, `3.4M`) avoids the problem; for exact values, accept that a single separator will look foreign to part of the audience.
7. **Scale changes the cost of string work.** One player building a string per frame is free. A server formatting a status line for 50 players at 60 Hz allocates 3,000 strings a second; the garbage collector absorbs it, but it shows in memory churn. Format only when the value changes, and send numbers over the network, not formatted strings, so the client formats in its own language.
8. **Console and phone text entry.** On console the on-screen keyboard is slow and some characters are hard to type; on phones autocorrect inserts curly quotes and trailing spaces. Trim whitespace and normalise quotes before comparing codes or commands, or players will report that a correct code "does not work".

The senior trade-off: strings are the easiest data type to get working and the easiest to get wrong for the long tail of players (non-English, younger, console). Spend the effort on the paths players see, and keep internal identifiers plain ASCII.

## Common mistakes (advanced)

1. **Comparing redemption codes case-sensitively.** Symptom: support messages saying a code is invalid. Fix: `string.lower` and trim both sides before comparing.
2. **Filtering on the client.** Symptom: exploiters bypass the filter. Fix: filtering only works on the server; do it there, then replicate the filtered result.
3. **Storing formatted strings in saves.** Symptom: a later change to formatting (adding separators, changing "K" to "k") breaks parsing of old saves. Fix: save raw numbers, format at display time.
4. **Using `string.format("%.2f")` for currency that should be whole.** Symptom: "100.00 coins" on screen and float drift in totals. Fix: keep currency as integers.
5. **Truncating names with `sub`.** Symptom: a stray replacement character at the end of non-Latin names. Fix: cut at `utf8.offset(s, maxChars + 1) - 1` when the string is longer than `maxChars`.
6. **Building chat commands with fragile patterns.** Symptom: commands fail when a player name contains a dash or a dot. Fix: split on whitespace first, then match names with plain-text `find(s, name, 1, true)`.

## Related decisions

- [[Text Fonts and Rich Text]]: where the rich text escaping rule bites in UI.
- [[Text Chat Customization with TextChatService]]: chat has its own filtering pipeline; do not duplicate it.
- [[Localization-Ready Writing]]: writing strings that survive translation.
- [[Big Numbers Precision and Formatting]]: number formatting beyond the basics.
- [[Codes Redemption System End to End]]: normalising player input for codes.
- [[Player Reports and In-Game Moderation]]: what to do with text that passes the filter but is still abusive.
- [[Serialization Formats for Saves and Networking]]: why saves should not hold display strings.
- [[Readable Text and UI Scale]]: string length limits interact with text scaling on small screens.

## Connected notes
<!-- auto-links:start -->
[[Cookbook - Tables Strings and Time]] · Localization Pipeline · Dialogue System End to End · Links - Chat and text filtering · Clip Buffer Format · Links - UI elements
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Tables Metatables and OOP]] · [[Luau Performance Patterns with Benchmarks]] · [[Functions Closures and Upvalues]] · [[Luau Performance and Native Codegen]] · [[Luau Type System and Strict Mode]] · [[Error Handling - pcall xpcall and Promise Patterns]] · [[Metatables and OOP - When and When Not]] · [[Module Scripts and Requiring]]
<!-- related:end -->
