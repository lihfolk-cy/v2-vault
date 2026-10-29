---
tags: [data, ordereddatastore, leaderboards, memorystore, ranking, type/guide, area/data, level/intermediate, api/IncrementAsync, area/performance, api/DataStore, api/UpdateAsync]
---
# OrderedDataStores and Leaderboards

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Writing on every score change. Symptom: throttling warnings and dropped writes at peak.
> - Avoid: Using the board as the source of truth. Symptom: scores cannot be corrected after an exploit or rollback.
> - Avoid: Storing huge numbers directly. Symptom: errors or wrong ordering for big values.
> - Ordered stores are indexes; the profile is the truth.
> - Writes on an interval and on leave, only for loaded profiles, only when changed.
> - Reads cached per server, staggered, with a fallback display.
>
> Cost: TL;DR ~170 tok · whole note ~4.6k tok. Read more: ## Writing scores · ## Nuances and edge cases · ## Checklist · ## Common mistakes
<!-- tldr:end -->

A global leaderboard looks trivial ("sort everyone by coins") and is one of the easiest ways to throttle your whole experience. This note covers `OrderedDataStore` exactly as it behaves in October 2026 (integers only, no versioning, small per-server write budgets, 100-entry pages), the read and write patterns that scale, periodic boards (daily, weekly), when a MemoryStore sorted map is the better tool, how to show a player's own rank, big-number scores for simulators, and what one production game's hub leaderboards did.

Prerequisite: [[DataStore Fundamentals]].

## What an OrderedDataStore is

`DataStoreService:GetOrderedDataStore(name, scope?)` returns a store whose values must be **integers**, and which can return keys **sorted by value**:

- `SetAsync`, `IncrementAsync`, `UpdateAsync`, `GetAsync`, `RemoveAsync` work as on a normal store, on integer values.
- `GetSortedAsync(ascending: boolean, pageSize: number, minValue: number?, maxValue: number?)` returns a `DataStorePages`. Page size must be **1 to 100**; min and max must be integers with `max >= min` (errors 106/107 otherwise).
- `BatchGetAsync(keys)` reads many keys in one call. It is **only supported on ordered stores** (calling it on a standard store throws). Default maximum 100 keys; missing keys are omitted from the result; **each key counts as one read** against the ordered read budget.
- **No versioning, no metadata**: `DataStoreKeyInfo` is always `nil`. `SetAsync`/`IncrementAsync` overwrite the previous value with no backup; `RemoveAsync` deletes permanently.

Treat an ordered store as an **index**, never as the source of truth. The real value lives in the player's profile, which is versioned and session-locked. If a board is corrupted or reset, you rebuild it from profiles.

### Budgets that matter (Roblox docs, October 2026)

| Operation | Per server per minute (default) | Experience per minute |
|---|---|---|
| Ordered read (`GetAsync`, `BatchGetAsync` per key, `UpdateAsync`) | 60 + 40 x players | 300 + 40 x CCU |
| Ordered write (`SetAsync`, `IncrementAsync`, `UpdateAsync`) | **30 + 5 x players** | 300 + 20 x CCU |
| Ordered list (`GetSortedAsync`, each page) | **5 + 2 x players** | 300 + 2 x CCU |
| Ordered remove | 30 + 5 x players | 300 + 40 x CCU |

The two bold numbers are the trap. A 10-player server may write ordered entries only 80 times a minute in total across **all** your boards, and list pages only 25 times a minute. Each `AdvanceToNextPageAsync` is another list request.

## Writing scores

Rules:

1. **Write from the profile, not from events.** Kill counters, coin totals and time played change constantly. Write the current value on an interval and on leave, not per change.
2. **Only write for players whose profile loaded.** One production game's rule: "never write a profile we failed to read, or we would wipe their history". A player whose load failed has a value of zero in memory; writing it removes them from the board.
3. **Skip unchanged values.** Keep the last written value per player per board.
4. **Spread boards and players over time.** With four boards and a 120 s interval, a 30-player server writes up to 120 values per cycle, which is 60 per minute against a budget of 180: fine, but only because it is spread.
5. **Use `SetAsync`, not `UpdateAsync`, for an index.** The profile already serialized the truth; the board just mirrors it. `UpdateAsync` costs a read too.
6. **Do not write from Studio test sessions.** The reference project disabled board writes whenever its Studio-only test profile key was set, so test runs never polluted public boards.

```lua
--!strict
-- ServerScriptService/Data/BoardWriter (ModuleScript)
local DataStoreService = game:GetService("DataStoreService")

export type BoardDef = { name: string, store: OrderedDataStore, valueOf: (Player) -> number? }

local BoardWriter = {}
local lastWritten: { [Player]: { [string]: number } } = {}

function BoardWriter.define(storeName: string, valueOf: (Player) -> number?): BoardDef
	return { name = storeName, store = DataStoreService:GetOrderedDataStore(storeName), valueOf = valueOf }
end

-- valueOf returns nil when the player's profile is not loaded: then nothing is written.
function BoardWriter.write(player: Player, boards: { BoardDef })
	local mine = lastWritten[player]
	if not mine then
		mine = {}
		lastWritten[player] = mine
	end
	for _, board in boards do
		local raw = board.valueOf(player)
		if raw == nil then
			continue
		end
		local value = math.floor(raw)
		if value <= 0 or mine[board.name] == value then
			continue
		end
		local ok, err = pcall(function()
			-- no userIds/metadata: ordered stores do not support metadata
			board.store:SetAsync(`u_{player.UserId}`, value)
		end)
		if ok then
			mine[board.name] = value
		else
			warn(`[Boards] {board.name} write failed for {player.UserId}: {err}`)
		end
	end
end

function BoardWriter.forget(player: Player)
	lastWritten[player] = nil
end

return BoardWriter
```

(Key format `u_<userId>`: matches what the reference project used, and is a static `{UserId}` pattern, which matters for automated right-to-be-forgotten templates; see [[Player Privacy and Data Deletion]].)

## Reading the top N

One `GetSortedAsync(false, 10)` per board per server per minute is plenty. Every server reads independently, so at 500 servers and 4 boards that is 2,000 list requests per minute against an experience budget of `300 + 2 x CCU` (with 10,000 CCU: 20,300). Fine. With 30 boards it is not.

```lua
--!strict
-- ServerScriptService/Data/BoardReader (ModuleScript)
local UserService = game:GetService("UserService")

export type Row = { rank: number, userId: number, value: number, name: string? }

local BoardReader = {}
local nameCache: { [number]: string } = {}

local function fillNames(rows: { Row })
	local missing = {}
	for _, row in rows do
		local cached = nameCache[row.userId]
		if cached then
			row.name = cached
		else
			table.insert(missing, row.userId)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and type(infos) == "table" then
		for _, info in infos do
			nameCache[info.Id] = info.DisplayName
		end
		for _, row in rows do
			row.name = row.name or nameCache[row.userId]
		end
	end
end

function BoardReader.top(store: OrderedDataStore, count: number): { Row }?
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, math.clamp(count, 1, 100))
	end)
	if not ok or not pages then
		return nil -- caller keeps showing its last good result
	end
	local okPage, page = pcall(function()
		return (pages :: DataStorePages):GetCurrentPage()
	end)
	if not okPage then
		return nil
	end
	local rows: { Row } = {}
	for i, entry in page do
		local userId = tonumber(string.match(entry.key, "^u_(%d+)$"))
		if userId then
			table.insert(rows, { rank = i, userId = userId, value = entry.value })
		end
	end
	fillNames(rows)
	return rows
end

return BoardReader
```

Refresh it on a loop with a random initial delay (servers that boot together should not all read together) and keep the last good result on failure. The reference project refreshed its hub boards every 60 s, showed 10 rows, saved values every 120 s, and **fell back to ranking the players in the current server** when the ordered store was unavailable, "so the boards always show something rather than sitting blank". Its rows showed a headshot thumbnail (`rbxthumb://type=AvatarHeadShot&id=<userId>&w=150&h=150`), medal badges for ranks 1 to 3 and a value chip; see [[World-Space UI - BillboardGui and SurfaceGui]].

## "What is my rank?"

There is no rank lookup API. Options:

| Approach | Cost | Result |
|---|---|---|
| Read the top 100 once per interval per server, look players up in it | 1 list request | Exact rank inside the top 100, "100+" outside |
| `GetSortedAsync(false, 100, nil, myValue)` and page | Many list requests | Exact but expensive; never per player per refresh |
| MemoryStore sorted map with your own counting | Request units | Needed for exact live ranks at scale |
| Percentile buckets (precomputed) | An Open Cloud job | "Top 5%" style messaging |

The production game used the first: one `GetSortedAsync(100)` per board per 120 s per server, publishing a player attribute with the rank (or `-1` = past 100, `-2` = not on the board yet). Cheap, and players outside the top 100 rarely care about the exact number.

## Periodic boards (daily, weekly, seasonal)

Ordered stores cannot expire entries. The standard trick is a **new store per period**, named by the period index:

```lua
--!strict
local DAY = 86400
local WEEK = 7 * DAY
-- 1 Jan 1970 was a Thursday; shifting by 4 days aligns weeks to Monday 00:00 UTC.
local MONDAY_OFFSET = 4 * DAY

local function weekIndex(t: number): number
	return (t - MONDAY_OFFSET) // WEEK
end

local function weeklyStoreName(base: string): string
	return `{base}_W{weekIndex(os.time())}`
end
```

The reference project used exactly this for a weekly PvP board, plus a read of **last week's** top 10 once per server to award a cosmetic aura to the previous winners. Points to get right:

- Use UTC `os.time()`, never local time.
- Servers that span the boundary must switch stores mid-session: compute the name at write time, not at boot.
- Old period stores keep their data and their storage until you delete them (Open Cloud or the Data Stores Manager). Schedule cleanup; old stores also contain user ids subject to deletion requests.
- Resetting an all-time board the same way (bump the name, `LB_Totals_v5` to `_v6`) leaves the old one recoverable.

## Big numbers (simulators and idle games)

Ordered values are integers, and Luau numbers are doubles: integers above 2^53 (about 9.007e15) lose precision, and values beyond the backend's integer range are not documented (unverified). Simulators routinely exceed both. Store a monotonic encoding instead (rule of thumb):

```lua
--!strict
-- Order-preserving encoding of a positive number into an integer with ~6 significant digits.
local SCALE = 1e6
local function encodeScore(x: number): number
	if x <= 1 then
		return 0
	end
	return math.floor(math.log10(x) * SCALE)
end
local function decodeScore(n: number): number
	return 10 ^ (n / SCALE)
end
```

The board sorts correctly; display the decoded value with your number formatter ([[Strings Patterns and Formatting]]). Keep the exact value in the profile.

## MemoryStore sorted maps for live boards

A MemoryStore sorted map ([[MemoryStore Service]]) is the better fit when:

- the board changes every few seconds (live event, current round, "top this hour");
- you want entries to expire on their own (TTL up to 45 days);
- you need ranges by score (`GetRangeAsync` with bounds) or real-time ordering.

Costs and limits: one sorted map holds at most 1,000,000 items and 100 MB, lives on a single partition (throttling starts around 30,000 request units per minute per partition, an estimate Roblox says may change), and `GetRangeAsync` costs one request unit per returned item. For an all-time board, ordered data stores remain the durable choice; the docs' comparison: ordered data store leaderboards are permanent, memory store leaderboards suit daily and monthly boards.

A hybrid that scales well: servers write scores to a sharded sorted map during the period; one elected server (or an Open Cloud job) copies the final standings into an ordered data store at period end.

## Feeding a "top spenders" board safely

The reference project ran a Robux board. The value was **never self-reported by clients**: the receipt handler reported spend once per completed `PurchaseId` (`CurrencySpent` from the receipt, the first time the receipt was marked done), and game-pass purchases were counted from `MarketplaceService` events. Count spend at the point of idempotent completion, or retries count it twice ([[Purchase Data and Receipts]]). Think twice about publishing spend rankings at all; see [[Ethical Design and Player Trust]].

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Board empty in Studio | Studio API access off (403), or test key disables writes | Expected; show local fallback |
| Board shows stale values for minutes | Read interval plus write interval | Expected; say "updates every few minutes" |
| `GetSortedThrottle` (305) errors | Too many boards or pages per server | Fewer refreshes, fewer pages, shared cache |
| Players vanish from a board | Zero written after a failed load | Only write for loaded profiles, skip `<= 0` |
| Weird order near the top | Precision loss above 2^53 | Log encoding |
| Board writes failing at shutdown | Write budget 30 + 5n consumed by many boards | Write boards on leave only if changed; never block `BindToClose` on them |

## Checklist

- [ ] Ordered stores are indexes; the profile is the truth.
- [ ] Writes on an interval and on leave, only for loaded profiles, only when changed.
- [ ] Reads cached per server, staggered, with a fallback display.
- [ ] Page sizes 1 to 100; pages counted against the 5 + 2n list budget.
- [ ] Period boards named by UTC period index; old ones cleaned up.
- [ ] Large scores encoded monotonically.
- [ ] Board keys follow a static `u_{UserId}` pattern covered by deletion templates.

## See also
[[DataStore Fundamentals]] · [[MemoryStore Service]] · [[Saving Correctly - Autosave and BindToClose]] · [[Player Privacy and Data Deletion]] · [[World-Space UI - BillboardGui and SurfaceGui]] · [[Retention and Return Hooks]] · [[Live Ops Events and Updates]] · [[Economies and Currencies]]

## Nuances and edge cases

1. **A leaderboard is two systems.** The OrderedDataStore holds the ranking; the player's real data (in their profile) holds the truth. Write the score to the board from the profile, never the other way around, and treat the board as a cache that can be rebuilt. A board that is the only place a value lives cannot be corrected after an exploit.
2. **Writes scale with players, budgets scale with servers.** Writing a player's score on every change works at 10 players and hits throttling at 50 per server across hundreds of servers. Write on a timer (every few minutes), on leave, and on significant milestones only.
3. **Integers only.** OrderedDataStore values must be integers (Roblox docs, as of October 2026). Simulator-scale numbers beyond what fits exactly need a transform, such as storing a scaled logarithm, which sorts correctly but loses exact values; show exact values from the profile, not from the board.
4. **Top boards are slow-moving by design.** Reading the top 100 every few seconds from every server wastes budget and shows no new information. Cache the top list per server and refresh every one to five minutes, with a small random offset per server.
5. **Rank for one player is hard.** Ordered stores return pages from the top; finding the rank of a player at position 2,000,000 is not practical. Show "top N" plus the player's own score, or approximate ranks in bands, rather than exact rank for everyone.
6. **Exploited scores pollute public boards.** A board is a public trophy shelf, so exploiters target it. Validate increases on the server (maximum gain per minute), and have an admin tool that removes a user from the board and marks their profile so the score is not rewritten on next join.
7. **Seasonal boards need a key strategy.** Use a separate store or key prefix per period (week number, season id), never reset by deleting thousands of entries. Old boards remain readable for history and rewards.
8. **Privacy and display names.** Boards store user ids; display names should be fetched for display and can change. Do not store names in the board key, and respect deletion requests by removing the user's entries (see [[Player Privacy and Data Deletion]]).

The senior trade-off: global leaderboards drive competition and attract exploiters, and they cost budget. For many games, a friends or server-local board gives most of the motivation with less risk; add global boards when the competition is a core part of the game.

## Common mistakes

1. **Writing on every score change.** Symptom: throttling warnings and dropped writes at peak. Fix: timed and on-leave writes.
2. **Using the board as the source of truth.** Symptom: scores cannot be corrected after an exploit or rollback. Fix: profile is truth; board is rebuilt from it.
3. **Storing huge numbers directly.** Symptom: errors or wrong ordering for big values. Fix: a monotonic transform such as a scaled logarithm.
4. **Reading the top list too often.** Symptom: read budget exhausted. Fix: per-server cache with jittered refresh.
5. **No removal tool.** Symptom: an exploiter's impossible score sits at the top for weeks. Fix: admin removal plus a profile flag.
6. **Resetting seasons by deleting entries.** Symptom: slow, throttled resets and lost history. Fix: new key per season.

## Related decisions

- [[Global Leaderboards End to End]]: a full board implementation.
- [[Big Numbers Precision and Formatting]]: transforms for very large scores.
- [[Battle Pass and Season Design]]: seasonal boards and rewards.
- [[Economy Exploits - Dupes Races and Purchase Abuse]]: protecting public scores.
- [[Logging Bans and Appeals]]: removing exploiters with an audit trail.
- [[MemoryStore Service]]: live boards with sorted maps.
- [[Session Locking and Profile Libraries]]: the profile that holds the truth.
- [[Retention and Return Hooks]]: how boards motivate players to return.

## Connected notes
<!-- auto-links:start -->
[[Cookbook - Data and Saving]] · Links - Leaderboards · Economy Resets and Seasonal Wipes · Debugging DataStore Problems · Session Lock · Cross-Server Messaging
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Resetting One Player's Data Safely]] · [[Serial-Numbered Limited Items - Atomic Counters]] · [[Global State and Live Config]] · [[Data Schema Design and Migrations]] · [[Open Cloud APIs]] · [[Schema Migrations - Worked Case Studies]] · [[Data Loss Prevention and Recovery]] · [[HttpService and External APIs]] · [[Trading Systems Without Duplication]]
<!-- related:end -->
