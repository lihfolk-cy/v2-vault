---
tags: [math, game-math, numbers, precision, floating-point, big-numbers, formatting, simulators, leaderboards, datastores, luau, type/guide]
---
# Big Numbers Precision and Formatting

<!-- tldr:start -->
> [!tldr] TL;DR
> - Daily bonus does nothing for late-game players: Fixed reward added below precision -> Scale rewards with progress
> - Balance becomes NaN, profile will not save: Overflow to `inf`, then `inf - inf` -> Clamp and `isfinite` checks before save
> - Conveyor stops far from spawn: Per-frame step below float32 gap -> Position from start plus velocity times time; stay near origin
> - Every stored number has a known container type and that container's limit is above its design maximum.
> - No timestamps, IDs or big values pass through `Vector3`, `CFrame` or other float32 containers.
> - Moving things far from the origin compute position from time, not per-frame steps.
>
> Cost: TL;DR ~210 tok · whole note ~5.3k tok. Read more: ## 4. When doubles run out in a simulator · ## 8. Formatting for players · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Simulators and idle games push numbers to 10^30 and beyond. Open worlds push positions to tens of thousands of studs. Timers run for hours. Each of these meets a different precision limit, and each limit shows up as a gameplay bug: income that stops increasing, a conveyor that stops moving far from spawn, a countdown that jumps in 128-second steps, a leaderboard that cannot store the top player's score, a counter that shows "1000K". [[Math Vectors and CFrames]] states the basic float rules (no `==` on computed floats, NaN, integers exact to 2^53). [[Strings Patterns and Formatting]] has a basic number abbreviator. This note maps every number type you will meet in Roblox to its limits, shows which gameplay bug each limit causes, and builds the tools for big values: correct abbreviation at boundaries, a mantissa-exponent number for games that outgrow doubles, order-preserving leaderboard encodings, and integer-safe currency.

---

## 1. Which number type am I actually using?

Luau has one number type, a 64-bit double. The engine has several storage types, and a value silently changes type when you write it into one.

| Where the number lives | Type | Exact integers up to | Largest value | Source |
|---|---|---|---|---|
| Luau variable, table field | 64-bit double | 2^53 = 9,007,199,254,740,992 | about 1.8 x 10^308 | Roblox docs (as of October 2026) |
| `NumberValue.Value`, number attributes | double | 2^53 | about 1.8 x 10^308 | rule of thumb (doubles, as Luau) |
| `IntValue.Value` | 64-bit integer | 2^63 - 1 in storage, but read into Luau as a double, so exact only to 2^53 | 2^63 - 1 | Roblox docs (as of October 2026) |
| `Vector3` components, `CFrame` positions | 32-bit float | 2^24 = 16,777,216 | about 3.4 x 10^38 | rule of thumb: test below |
| Properties typed `int` | 32-bit integer | 2^31 - 1 | 2^31 - 1 | Roblox docs (as of October 2026) |
| DataStore values | Serialised as JSON text | depends on the encoder's number formatting | see section 6 | unverified detail |
| `OrderedDataStore` values | Integers | not documented for the value itself | see section 7 | Roblox docs (as of October 2026), partly unverified |

The `Vector3` row is the one that surprises people. Luau's native vector type stores single-precision floats, so a value written into a `Vector3` keeps only about 7 significant digits. Check it in your own Studio build with one line:

```lua
print(Vector3.new(16777217, 0, 0).X, 16777217) --> 16777216 16777217 if components are float32
```

Treat any value stored in a `Vector3`, a `CFrame`, a `Color3` or a `UDim2` as low precision, whatever precision it had in Luau.

---

## 2. The far-from-origin problem, with numbers

A 32-bit float has 24 bits of mantissa, so the gap between neighbouring representable values (the ulp) doubles every time the magnitude doubles:

| Distance from origin (studs) | Gap between representable positions | What breaks |
|---|---|---|
| 1,000 | about 0.00006 | Nothing visible |
| 10,000 | about 0.001 | Fine physics contacts start to jitter (rule of thumb) |
| 100,000 | about 0.008 | Animated parts shimmer; tiny per-frame moves vanish |
| 1,000,000 | about 0.06 | Characters and cameras visibly snap |

The gameplay bug that catches people is **per-frame motion smaller than the gap**. A conveyor that moves a part 0.005 studs per frame works at spawn and does nothing at 100,000 studs, because `x + 0.005` rounds back to `x`. Slow doors, sliding platforms, creeping lava and drifting clouds all stop. Two fixes:

- **Compute positions from a start position and elapsed time** (`start + velocity * t`), not by adding a small step each frame. The error then stays at one rounding per frame rather than losing every step.
- **Keep play near the origin.** Roblox has no built-in floating origin. Split huge worlds into separate places ([[Teleporting and Multi-Place Games]]) or design levels so the area players actually use sits within a few thousand studs of the origin, which keeps you in the safe rows of the table ([[Procedural World Generation]]).

Physics jitter far out is the same effect in the solver; you cannot fix it in scripts.

---

## 3. Timestamps in the wrong container

`os.time()` is about 1.7 x 10^9 today, `DateTime.now().UnixTimestampMillis` about 1.7 x 10^12, and `workspace:GetServerTimeNow()` returns seconds as a double (Roblox docs (as of October 2026)). All of these are exact in a Luau double. The bug appears when a timestamp passes through a float32 container:

- 1.7 x 10^9 lies between 2^30 and 2^31, where the float32 gap is 2^7 = **128 seconds**. A timestamp smuggled through a `Vector3` (a common hack to replicate three numbers at once) or a `NumberSequence` keypoint arrives rounded to the nearest 128 seconds. A countdown built on it jumps in two-minute steps, or ends two minutes early.
- Millisecond timestamps in a float32 are worse: the gap near 1.7 x 10^12 is about 131,072 ms.

Rules: replicate timestamps through attributes, `NumberValue`s or remote arguments, which stay doubles. If you must pack time into low-precision storage, send an offset from a recent base (`now - roundStart`), which is small and therefore precise. The same applies to any large ID-like number: user IDs belong in doubles or strings, never in vectors.

**Accumulated timers drift.** `elapsed += dt` every frame adds a rounding error each frame and drifts from the true clock over long sessions; worse, it pauses when the script is throttled or the loop yields. Store the start time and compute `now - start` whenever you need elapsed time ([[Frame Order and RunService Timing]]).

---

## 4. When doubles run out in a simulator

Doubles keep about 15 to 16 significant digits. In a currency system that means:

- **Below 2^53 (about 9 x 10^15, "9 Qa")** every integer is exact. Adding 1 coin always shows.
- **Above 2^53**, adding small amounts is lost: `1e17 + 1 == 1e17`. A player with 10^17 coins who earns 1 coin per click never sees the number change. In a simulator with multipliers that is usually fine, since income scales with balance. It is a bug when a fixed-size reward (a daily 500-coin bonus, a quest reward) is still being paid to late-game players: they literally receive nothing.
- **Above about 1.8 x 10^308** values become `inf`. `inf - inf` is NaN, NaN fails every comparison, and a NaN balance can then never afford anything, never be compared on a leaderboard, and may not save at all. One overflowing multiplier can corrupt a profile.

The fixes are design first, maths second:

1. **Scale rewards with progress.** Express fixed rewards as "N seconds of current income" or a fraction of the next unlock price. This removes the "1 coin added to 10^17" problem entirely and is better pacing anyway ([[Economy Inflation Sinks and Faucets Math]], [[Rebirth and Prestige System End to End]]).
2. **Guard the top.** Clamp balances below a ceiling well under `math.huge` (for example 10^300) and validate `math.isfinite` before every save ([[Data Loss Prevention and Recovery]]).
3. **Only if your design genuinely passes 10^308**, switch to a mantissa-exponent representation.

### A mantissa-exponent number

Represent a non-negative value as `m * 10^e` with `m` in `[1, 10)` (or zero). Addition aligns exponents; multiplication adds them. Fifteen digits of mantissa is plenty: nobody reads the 16th digit of a number with 400 digits.

```lua
--!strict
export type Big = { m: number, e: number }

local Big = {}

local function normalise(m: number, e: number): Big
	if m == 0 then
		return { m = 0, e = 0 }
	end
	local shift = math.floor(math.log10(m))
	m /= 10 ^ shift
	e += shift
	-- Guard float wobble at the boundary (for example m = 9.9999999999999998)
	if m >= 10 then
		m /= 10
		e += 1
	elseif m < 1 then
		m *= 10
		e -= 1
	end
	return { m = m, e = e }
end

function Big.from(n: number): Big
	assert(n >= 0 and n == n and n ~= math.huge, "Big.from expects a finite non-negative number")
	return normalise(n, 0)
end

function Big.mul(a: Big, b: Big): Big
	return normalise(a.m * b.m, a.e + b.e)
end

function Big.add(a: Big, b: Big): Big
	if a.m == 0 then return b end
	if b.m == 0 then return a end
	if a.e < b.e then
		a, b = b, a
	end
	local gap = a.e - b.e
	if gap > 17 then
		return a -- b is below a's precision
	end
	return normalise(a.m + b.m / 10 ^ gap, a.e)
end

-- Returns a - b, floored at zero (spending more than you have is a caller bug)
function Big.sub(a: Big, b: Big): Big
	if Big.lessThan(a, b) then
		return { m = 0, e = 0 }
	end
	local gap = a.e - b.e
	if gap > 17 then
		return a
	end
	return normalise(a.m - b.m / 10 ^ gap, a.e)
end

function Big.lessThan(a: Big, b: Big): boolean
	if a.m == 0 or b.m == 0 then
		return a.m < b.m
	end
	if a.e ~= b.e then
		return a.e < b.e
	end
	return a.m < b.m
end

-- Back to a double where possible (for UI bars, ratios)
function Big.toNumber(x: Big): number
	return x.m * 10 ^ x.e -- becomes math.huge past about 1e308
end

return Big
```

Notes on the design:

- **Store it as two numbers**, `{m, e}`, in saves. The exponent can grow far beyond 308 while each field stays an ordinary double.
- **Ratios and logs are cheap**: `log10(x) = log10(m) + e`. Progress bars between two big prices can use log progress, which also looks better ([[Interpolation Easing and Curves Math]]).
- **Subtraction of near-equal values loses everything.** Spending 99.999 percent of a balance leaves a mantissa with few accurate digits. Harmless for display, but never use `Big` to compute a remainder that matters exactly.
- **Allocation.** Each operation creates a table. A simulator that does a few thousand big-number operations per second per server is fine; one that does millions should keep the numbers in doubles while they fit.

Libraries for this exist in the community; whichever you use, test the boundary cases (`9.9999...`, adding across a huge exponent gap, zero) yourself.

---

## 5. Currency without fractions

Fractional currency causes a long list of small bugs: balances like `1049.9999999` that display as "1050" but cannot afford a 1050 item, refunds that do not match purchases, duplicated fractions in trades. Rules that avoid all of them:

- **Store currency as integers.** If you need fractions of a coin, store hundredths as the integer unit.
- **Store percentages as integers too**, for example basis points (1 percent = 100). `price * 1500 // 10000` is a 15 percent fee with no float residue for prices below about 6 x 10^12 (the product must stay below 2^53).
- **Round once, at the end, with a stated rule.** Rewards with multipliers (`100 * 1.15 * 1.3`) are computed in floats and floored once when credited. Floor rewards and ceil prices so rounding never favours farming.
- **Carry remainders if small amounts matter.** An idle game paying 0.4 coins per second floors to 0 forever. Keep the fractional remainder per player in memory and add it to the next payout.
- **Split totals so the parts sum exactly.** Splitting 100 coins three ways is 33, 33, 34, not 33.33 three times:

```lua
--!strict
local function splitEvenly(total: number, parts: number): { number }
	local base = total // parts
	local remainder = total - base * parts
	local out = table.create(parts, base)
	for i = 1, remainder do
		out[i] += 1
	end
	return out
end
```

`//` is floor division and `%` takes the sign of the divisor in Luau; `math.fmod` takes the sign of the dividend ([[Math Vectors and CFrames]]). For negative amounts (debts, refunds) decide which you mean and test it.

---

## 6. Saving numbers

DataStore values are stored as serialised text (JSON-encoded tables) (Roblox docs (as of October 2026)). Practical consequences:

- **`inf` and NaN have no JSON representation.** How the encoder treats them is not something to rely on (unverified detail); never let them reach a save. Validate with `math.isfinite` before writing and on load ([[Saving Correctly - Autosave and BindToClose]]).
- **Very large integers and long fractions** are written as decimal text. Whether every double round-trips bit-exactly through the encoder is not documented (unverified). For values where every digit matters (IDs, big-number mantissas you will compare for equality), store them as strings or as `{m, e}` pairs.
- **Size.** A number that prints as 17 digits costs 17 bytes or more in JSON. For large arrays of numbers (replays, maps), pack them into a buffer and encode it, as [[Buffers and Binary Data]] describes, rather than saving long JSON arrays.

---

## 7. Leaderboards with values beyond integer range

`OrderedDataStore` sorts integer values, and its filter bounds must be integers (Roblox docs (as of October 2026)). The documentation does not state the maximum value; community reports put the ceiling at 2^63 (unverified). Either way, a simulator's 10^40 balance does not fit. The fix is an **order-preserving encoding**: map each value to an integer such that larger values always get larger integers.

```lua
--!strict
-- Encode a positive value (double or {m, e}) as an integer that sorts in the same order.
-- 1e12 steps per decade of the logarithm: about 12 significant digits of ordering precision.
local SCALE = 1e12

local function encodeScore(m: number, e: number): number
	if m <= 0 then
		return 0
	end
	local log = e + math.log10(m)        -- log10 of the value
	return math.floor((log + 1) * SCALE) -- +1 keeps values >= 0.1 non-negative
end

local function decodeScore(key: number): (number, number)
	local log = key / SCALE - 1
	local e = math.floor(log)
	return 10 ^ (log - e), e             -- mantissa, exponent
end

-- encodeScore(1.5, 40) -> about 4.1176e13: fits easily below 2^53
```

With `SCALE = 1e12`, keys stay below 2^53 for exponents up to about 9,000, which covers any sane design. The decoded value is approximate (about 12 significant digits), which is fine for display; the true balance stays in the player's profile. Two players with values equal to 12 digits tie, which is also fine. Document the encoding next to the leaderboard code, because anyone who later writes raw values into the same store breaks the ordering ([[OrderedDataStores and Leaderboards]], [[Global Leaderboards End to End]]).

---

## 8. Formatting for players

The basic abbreviator in [[Strings Patterns and Formatting]] notes the boundary problem. Here is a version that solves it and covers the cases beyond the suffix list:

```lua
--!strict
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- Formats m * 10^e (m in [1, 10), or a plain number via e = 0) with `sig` significant digits.
local function formatShort(m: number, e: number, sig: number?): string
	local digits = sig or 3
	if m ~= m then
		return "?" -- NaN should never reach UI; make it visible but harmless
	end
	if m == 0 then
		return "0"
	end
	-- Normalise plain numbers
	local shift = math.floor(math.log10(m))
	m /= 10 ^ shift
	e += shift
	if e < 3 then
		return tostring(math.floor(m * 10 ^ e + 1e-9))
	end
	-- Round to significant digits FIRST, then choose the suffix (fixes "1000K")
	local factor = 10 ^ (digits - 1)
	m = math.round(m * factor) / factor
	if m >= 10 then
		m /= 10
		e += 1
	end
	local tier = e // 3
	local intDigits = e - tier * 3 + 1             -- digits before the decimal point: 1, 2 or 3
	local scaled = m * 10 ^ (intDigits - 1)
	local decimals = math.max(0, digits - intDigits)
	local text = string.format("%." .. decimals .. "f", scaled)
	if decimals > 0 then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	if tier + 1 <= #SUFFIXES then
		return text .. SUFFIXES[tier + 1]
	end
	-- Past the suffix list: engineering notation keeps the exponent a multiple of 3
	return text .. "e" .. tostring(tier * 3)
end

-- formatShort(999950, 0)      -> "1M"   (not "1000K")
-- formatShort(1234567, 0)     -> "1.23M"
-- formatShort(4.56, 40)       -> "45.6e39"
```

Design notes on number display:

- **Significant digits, not decimals.** "1.23K", "12.3K", "123K" all have three digits and the same visual width. Fixed decimals give "123.45K", which jitters in width as numbers change.
- **Never show a rounded value as affordable when it is not.** A price "1.5M" and a balance "1.5M" can be 1,499,000 and 1,500,000. Colour the buy button from the true comparison, not from the strings, and consider showing exact values in tooltips.
- **Beyond the suffix list**, choose one scheme and keep it: engineering notation (`45.6e39`), scientific (`4.56e40`), or letter pairs (`aa`, `ab`, ...). Letter pairs are popular in idle games but must be explained once in the UI.
- **Localisation.** Suffixes like "K" and "M", and the decimal point itself, differ by language. Keep all number formatting in one function so translators can supply suffix tables and decimal separators ([[Localization]], [[Localization Pipeline]]).
- **Animated counters across magnitudes** should tween the logarithm, not the value, or they sit on the final suffix for almost the whole animation ([[Interpolation Easing and Curves Math]]).
- **Leaderboard ties.** Two players with "1.23Qa" may differ in the 10th digit. Show rank by the true order; do not re-sort by the formatted string.

---

## 9. Comparing and rounding

- **Tolerances must scale with magnitude.** `math.abs(a - b) < 1e-6` is meaningless for values near 10^20, where adjacent doubles are 16,384 apart. Use a relative tolerance: `math.abs(a - b) <= 1e-9 * math.max(math.abs(a), math.abs(b))`.
- **`math.round` rounds half away from zero** ([[Math Vectors and CFrames]]). There is no built-in banker's rounding; if accounting rules need it, write it and test it.
- **Display rounding is not storage rounding.** Round only at the display boundary; store the true value.
- **Integers from the network are not trusted integers.** A client can send `1e309` (`inf`), `0/0`, or `2.5` where you expect a whole number. Check `math.isfinite(x) and x == math.floor(x)` and a range before using any number from a remote ([[Server Authority and Validation]], [[Economy Exploits - Dupes Races and Purchase Abuse]]).
- **Luau integer types.** A Luau RFC proposes a native 64-bit integer type; whether and when it ships in Roblox was not confirmed for this note (unverified). Do not design around it until it is in the documentation.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Daily bonus does nothing for late-game players | Fixed reward added below precision | Scale rewards with progress |
| Balance becomes NaN, profile will not save | Overflow to `inf`, then `inf - inf` | Clamp and `isfinite` checks before save |
| Conveyor stops far from spawn | Per-frame step below float32 gap | Position from start plus velocity times time; stay near origin |
| Countdown jumps in two-minute steps | Timestamp passed through a `Vector3` | Doubles via attributes or remotes; send offsets |
| "1000K" in the UI | Suffix chosen before rounding | Round to significant digits first |
| Buy button lit but purchase fails | Comparing formatted strings | Compare true values |
| `1049.9999` cannot buy a 1050 item | Fractional currency | Integer currency; round once when credited |
| Leaderboard cannot hold top scores | Values beyond integer range | Order-preserving log encoding |
| Exploiter gains `inf` coins | Unvalidated numbers from clients | Finite, integer and range checks |

## Checklist

- [ ] Every stored number has a known container type and that container's limit is above its design maximum.
- [ ] No timestamps, IDs or big values pass through `Vector3`, `CFrame` or other float32 containers.
- [ ] Moving things far from the origin compute position from time, not per-frame steps.
- [ ] Rewards scale with progress; balances are clamped below `math.huge`.
- [ ] `math.isfinite` guards every save and every number from a client.
- [ ] Currency and percentages are integers; rounding rules are written down.
- [ ] Leaderboards for huge values use a documented order-preserving encoding.
- [ ] Number formatting lives in one function: significant digits, boundary-safe, localisable.

## See also

[[Game Math Start Here]] · [[Math Vectors and CFrames]] · [[Strings Patterns and Formatting]] · [[Buffers and Binary Data]] · [[Economy Inflation Sinks and Faucets Math]] · [[Genre Playbook - Simulators]] · [[Rebirth and Prestige System End to End]] · [[OrderedDataStores and Leaderboards]] · [[Global Leaderboards End to End]] · [[DataStore Fundamentals]] · [[Interpolation Easing and Curves Math]] · [[Localization]]

## Connected notes
<!-- auto-links:start -->
[[Pricing Curves and Upgrade Costs]] · Cookbook - Tables Strings and Time · Serialization Formats for Saves and Networking · Currency Architecture - Soft Hard and Event Currencies · Power Curve · Faucets and Sinks
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Cookbook - Tables Strings and Time]] · [[Serialization Formats for Saves and Networking]] · [[Intersection and Collision Math]] · [[Rotations Angles and Quaternions]] · [[Dot and Cross Products in Gameplay]] · [[Probability and Statistics for Designers]] · [[Curves in Luau - Paths Beams and Motion]]
<!-- related:end -->
