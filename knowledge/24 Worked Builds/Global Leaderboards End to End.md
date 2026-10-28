---
tags: [worked-build, leaderboards, ordered-datastore, datastore, budgets, ui, luau, strict]
---
# Global Leaderboards End to End

Two cross-server leaderboards from an empty place: an all-time "most coins earned" board and a weekly board that resets every week without deleting anything. Scores come only from server-side profile stats, are written to ordered data stores on a budgeted schedule, read back once per board every two minutes per server, resolved to display names in batches, pushed to every client, and drawn both on a board in the world and as a player's own rank. It uses the foundation from [[Saved Inventory End to End]], whose `InventoryService.AddCoins` already maintains `Stats.CoinsEarned` and `Weekly`.

All code is **reviewed, not run**: strict Luau against the documented APIs (Roblox docs, as of October 2026), not executed in this form. Test as section 7 describes.

The deep reference is [[OrderedDataStores and Leaderboards]] (budgets, rank lookups, big-number encodings, memory store boards). This note is the assembled build.

---

## 1. Principles

1. **The profile is the truth, the board is an index.** The score lives in the session-locked profile ([[Session Locking and Profile Libraries]]). The ordered store is a copy that can be rebuilt. Never read a player's own score back from the board to decide anything.
2. **Write rarely, read rarely.** Ordered stores have small budgets. Per server, per minute (Roblox docs, as of October 2026): ordered writes **30 + 5 x players**, list pages **5 + 2 x players**. A 10-player server gets 80 writes and 25 list pages a minute across all boards.
3. **Every server reads the same board.** With 500 servers each reading 2 boards every 2 minutes, that is 500 list requests a minute against an experience budget of 300 + 2 x CCU (for 10,000 CCU, 20,300). Fine at 2 boards; reckless at 40.
4. **Leaderboards are public data about players.** Show only names Roblox gives you, remove users who ask for deletion, and remove flagged cheaters ([[Player Privacy and Data Deletion]], [[Logging Bans and Appeals]]).

### Budget for this build

| Operation | Rate | 20-player server, per minute |
|---|---|---|
| Score writes (`UpdateAsync`, 1 read + 1 write) | each player, each board, every 120 s, only if changed | at most 20 writes |
| Final write on leave | once per board per leaving player | a few |
| List (`GetSortedAsync`, 1 page of 50) | each board every 120 s | 1 |
| Name lookups (`GetUserInfosByUserIdsAsync`) | only for ids not cached | near 0 after warm-up |

Write budget: 30 + 5 x 20 = 130 per minute. The build uses about 15 percent of it, leaving room for other ordered boards and bursts (rule of thumb: stay under half).

---

## 2. Folder layout (additions)

```
ReplicatedStorage
  Shared
    LeaderboardConfig (ModuleScript)     -- new
ServerScriptService
  Server
    Services
      LeaderboardService (ModuleScript)  -- new
StarterPlayer
  StarterPlayerScripts
    Client
      LeaderboardController (LocalScript) -- new
Workspace
  LeaderboardBoard (Part)                 -- new; attribute Board = "AllTimeCoins"
    SurfaceGui
      List (ScrollingFrame)
```

Put a `SurfaceGui` with a `ScrollingFrame` named `List` on a part named `LeaderboardBoard`, and give the part a string attribute `Board`. Duplicate the part for the weekly board with `Board = "WeeklyCoins"`. The client fills the lists; see [[World-Space UI - BillboardGui and SurfaceGui]] for sizing (`PixelsPerStud`, `LightInfluence = 0` so text stays readable at night).

---

## 3. Config

```lua
--!strict
-- ReplicatedStorage/Shared/LeaderboardConfig (ModuleScript). Reviewed, not run.
export type BoardDef = {
	Key: string,
	Title: string,
	Period: "AllTime" | "Weekly",
	Stat: "CoinsEarned" | "WeeklyCoins",
}

local LeaderboardConfig = {}

LeaderboardConfig.TopN = 50 -- one page; GetSortedAsync allows 1 to 100 per page (Roblox docs)
LeaderboardConfig.RefreshSeconds = 120
LeaderboardConfig.WriteSeconds = 120
LeaderboardConfig.SecondsPerWeek = 604_800

LeaderboardConfig.Boards = {
	{ Key = "AllTimeCoins", Title = "Most Coins Earned", Period = "AllTime", Stat = "CoinsEarned" },
	{ Key = "WeeklyCoins", Title = "Top Earners This Week", Period = "Weekly", Stat = "WeeklyCoins" },
} :: { BoardDef }

-- Must match the week formula in InventoryService.AddCoins.
function LeaderboardConfig.WeekIndex(unixTime: number): number
	return math.floor(unixTime / LeaderboardConfig.SecondsPerWeek)
end

-- Unix time when the current week ends (for the client countdown).
function LeaderboardConfig.WeekEndsAt(unixTime: number): number
	return (LeaderboardConfig.WeekIndex(unixTime) + 1) * LeaderboardConfig.SecondsPerWeek
end

return LeaderboardConfig
```

A note on the week: `floor(unix / 604800)` starts weeks on Thursday 00:00 UTC, because 1 January 1970 was a Thursday. If you want Monday resets, subtract 4 days first: `floor((unix - 345600) / 604800)`. Whatever you choose, use **one** function everywhere. If the profile's weekly counter and the board's store name disagree about which week it is, scores land on the wrong week's board for a few days.

The foundation build computes the week inline in `InventoryService.AddCoins`. When you add this build, change that line to call `LeaderboardConfig.WeekIndex(os.time())` so the formula exists in one place.

---

## 4. Server

### 4.1 Store naming

- All-time: `LB_AllTimeCoins_v1`.
- Weekly: `LB_WeeklyCoins_v1_W<weekIndex>`, a new store each week.

A new store per week is the cheapest correct reset: nothing is deleted, last week's board is still readable ("last week's champions"), and there is no race between a reset job and players writing scores. Old stores cost a little storage; with one small integer per player per week this is negligible against the experience's storage allowance (rule of thumb; see [[DataStore Fundamentals]] for storage limits).

### 4.2 Writing safely

Each score write is an `UpdateAsync` that **never lowers** a monotonic score:

```lua
store:UpdateAsync(key, function(old: number?): number?
	if old and old >= score then
		return nil -- cancel: the board already has this or more
	end
	return score
end)
```

Why not `SetAsync`? Two servers can briefly hold different views of one player: an old server writing its last cached value after the player has moved on and earned more. With `SetAsync`, the old server's lower number can win. With "never lower", the order of writes stops mattering. The cost is one extra read per write, which comes out of the much larger read budget. This only works for scores that only go up within a period (coins earned, wins, best level); for a score that can fall (current coins), use `SetAsync` and accept brief staleness.

### 4.3 LeaderboardService

```lua
--!strict
-- ServerScriptService/Server/Services/LeaderboardService (ModuleScript). Reviewed, not run.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local UserService = game:GetService("UserService")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.LeaderboardConfig)
local PlayerData = require(script.Parent.Parent.PlayerData)

type BoardDef = Config.BoardDef
type Entry = { UserId: number, Name: string, Score: number, Rank: number }

local IS_STUDIO = RunService:IsStudio()
local NAME_BATCH = 100 -- ids per name lookup (the documented maximum is not stated; keep batches modest)
local MAX_SANE_GAIN_PER_MINUTE = 100_000 -- anomaly threshold for this economy (tune it)

local LeaderboardService = {}

local boardsEvent: RemoteEvent
local latest: { [string]: { Entry } } = {}
local nameCache: { [number]: string } = {}
-- Last score sampled from each player's profile, and last score written, per board.
local sampled: { [Player]: { [string]: number } } = {}
local written: { [Player]: { [string]: number } } = {}
local lastWriteTime: { [Player]: number } = {}

local function canWrite(): boolean
	-- Studio sessions do not write to live boards unless you opt in.
	return not IS_STUDIO or ServerStorage:GetAttribute("LeaderboardWritesInStudio") == true
end

local function storeFor(board: BoardDef, unixTime: number): OrderedDataStore
	if board.Period == "Weekly" then
		return DataStoreService:GetOrderedDataStore(`LB_{board.Key}_v1_W{Config.WeekIndex(unixTime)}`)
	end
	return DataStoreService:GetOrderedDataStore(`LB_{board.Key}_v1`)
end

local function readStat(player: Player, board: BoardDef): number?
	local profile = PlayerData.Get(player)
	if not profile then
		return nil
	end
	local data = profile.Data
	if board.Stat == "CoinsEarned" then
		return math.floor(data.Stats.CoinsEarned)
	end
	-- Weekly: only counts if the profile's week is the current week.
	if data.Weekly.WeekIndex ~= Config.WeekIndex(os.time()) then
		return 0
	end
	return math.floor(data.Weekly.CoinsEarned)
end

local function sample(player: Player)
	local scores = sampled[player]
	if not scores then
		scores = {}
		sampled[player] = scores
	end
	for _, board in Config.Boards do
		local value = readStat(player, board)
		if value then
			scores[board.Key] = value
		end
	end
end

local function isFlagged(userId: number): boolean
	-- Hook for your moderation system: a ServerStorage attribute list, a data store, the Ban API.
	local list = ServerStorage:GetAttribute("LeaderboardExcluded")
	return type(list) == "string" and string.find(`,{list},`, `,{userId},`, 1, true) ~= nil
end

local function writeScores(player: Player, userId: number)
	if not canWrite() or isFlagged(userId) then
		return
	end
	local scores = sampled[player]
	if not scores then
		return
	end
	local done = written[player] or {}
	written[player] = done
	local now = os.time()
	local minutes = math.max(1, (os.clock() - (lastWriteTime[player] or os.clock())) / 60)
	lastWriteTime[player] = os.clock()

	for _, board in Config.Boards do
		local score = scores[board.Key]
		if score and score > 0 and score ~= done[board.Key] then
			local previous = done[board.Key] or 0
			if previous > 0 and score - previous > MAX_SANE_GAIN_PER_MINUTE * minutes then
				-- Do not publish an implausible jump; log it for review instead.
				warn(`[Leaderboard] anomaly for {userId} on {board.Key}: +{score - previous}`)
				continue
			end
			local store = storeFor(board, now)
			local ok, err = pcall(function()
				store:UpdateAsync(tostring(userId), function(old: number?): number?
					if old and old >= score then
						return nil
					end
					return score
				end)
			end)
			if ok then
				done[board.Key] = score
			else
				warn(`[Leaderboard] write {board.Key} for {userId} failed: {err}`)
			end
		end
	end
end

local function resolveNames(userIds: { number })
	local missing: { number } = {}
	for _, id in userIds do
		if nameCache[id] == nil then
			table.insert(missing, id)
		end
	end
	for i = 1, #missing, NAME_BATCH do
		local batch = table.move(missing, i, math.min(i + NAME_BATCH - 1, #missing), 1, {})
		local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, batch)
		if ok and type(infos) == "table" then
			for _, info in infos do
				if type(info) == "table" and type(info.Id) == "number" then
					local display = if type(info.DisplayName) == "string" then info.DisplayName else "?"
					local username = if type(info.Username) == "string" then info.Username else "?"
					nameCache[info.Id] = if display == username then display else `{display} (@{username})`
				end
			end
		end
	end
end

local function refreshBoard(board: BoardDef)
	local store = storeFor(board, os.time())
	local ok, pages = pcall(store.GetSortedAsync, store, false, Config.TopN)
	if not ok then
		warn(`[Leaderboard] read {board.Key} failed: {pages}`)
		return -- keep showing the last good board
	end
	local page = (pages :: DataStorePages):GetCurrentPage()
	local ids: { number } = {}
	for _, row in page do
		local id = tonumber(row.key)
		if id then
			table.insert(ids, id)
		end
	end
	resolveNames(ids)

	local entries: { Entry } = {}
	for _, row in page do
		local id = tonumber(row.key)
		if id and not isFlagged(id) then
			table.insert(entries, {
				UserId = id,
				Name = nameCache[id] or "Unknown player", -- deleted or unresolved accounts
				Score = row.value,
				Rank = #entries + 1,
			})
		end
	end
	latest[board.Key] = entries

	-- Publish each online player's rank (or -1 if outside the top N) as an attribute.
	local rankById: { [number]: number } = {}
	for _, e in entries do
		rankById[e.UserId] = e.Rank
	end
	for _, player in Players:GetPlayers() do
		player:SetAttribute(`Rank_{board.Key}`, rankById[player.UserId] or -1)
	end
end

local function pushAll(target: Player?)
	local payload = { Boards = latest, WeekEndsAt = Config.WeekEndsAt(os.time()) }
	if target then
		boardsEvent:FireClient(target, payload)
	else
		boardsEvent:FireAllClients(payload)
	end
end

-- Right-to-be-forgotten and moderation: remove a user from every board you can name.
function LeaderboardService.ForgetUserAsync(userId: number, weeksBack: number)
	local now = os.time()
	for _, board in Config.Boards do
		if board.Period == "Weekly" then
			for w = 0, weeksBack do
				local store = DataStoreService:GetOrderedDataStore(`LB_{board.Key}_v1_W{Config.WeekIndex(now) - w}`)
				pcall(store.RemoveAsync, store, tostring(userId))
			end
		else
			local store = storeFor(board, now)
			pcall(store.RemoveAsync, store, tostring(userId))
		end
	end
end

local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats" -- the default player list shows values in this folder
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = folder
	folder.Parent = player
	task.spawn(function()
		while player.Parent == Players do
			local profile = PlayerData.Get(player)
			if profile then
				coins.Value = math.min(profile.Data.Coins, 2 ^ 53)
			end
			task.wait(2)
		end
	end)
end

function LeaderboardService.Start()
	boardsEvent = Net.Event("LeaderboardData")
	Net.Event("LeaderboardHello").OnServerEvent:Connect(function(player: Player)
		pushAll(player)
	end)

	PlayerData.OnLoaded(function(profile)
		setupLeaderstats(profile.Player)
		sample(profile.Player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		-- The profile may already be released, so use the last sample. One final write.
		local userId = player.UserId
		task.spawn(function()
			writeScores(player, userId)
			sampled[player] = nil
			written[player] = nil
			lastWriteTime[player] = nil
		end)
	end)

	-- Sample cheaply and often (memory only); write on a slow, staggered schedule.
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				sample(player)
			end
			task.wait(10)
		end
	end)
	task.spawn(function()
		while true do
			local list = Players:GetPlayers()
			local gap = Config.WriteSeconds / math.max(#list, 1)
			for _, player in list do
				if player.Parent == Players then
					sample(player)
					writeScores(player, player.UserId)
				end
				task.wait(gap) -- spread writes evenly across the interval
			end
			if #list == 0 then
				task.wait(Config.WriteSeconds)
			end
		end
	end)
	task.spawn(function()
		task.wait(math.random() * 20) -- de-synchronise servers that start together
		while true do
			for _, board in Config.Boards do
				refreshBoard(board)
			end
			pushAll(nil)
			task.wait(Config.RefreshSeconds)
		end
	end)
end

return LeaderboardService
```

Design notes:

- **Sample in memory, write from the sample.** `PlayerData` removes the profile at the start of `PlayerRemoving` ([[Saved Inventory End to End]]), and the order in which different `PlayerRemoving` handlers run is not something to rely on. The 10-second sample means the final write on leave uses a value at most 10 seconds old, without depending on handler order. Up to 10 seconds of score can be missing until the player's next session writes it; for a leaderboard that is acceptable.
- **Writes only when changed.** An idle player costs no budget.
- **Staggered writes.** Spreading writes across the interval keeps each minute's usage flat instead of spiking every two minutes, which matters on servers that also save profiles on the same budget family ([[Network Bandwidth Budgets and Measuring Them]] has the general argument for smoothing).
- **The anomaly check is not anti-cheat.** It keeps one obviously broken number off a public board while you investigate. Real detection belongs to [[Economy Exploits - Dupes Races and Purchase Abuse]] and [[False Positives Lag and Fair Enforcement]].
- **Flagged users are filtered at read time too.** Removing an entry from the store does not remove it from 500 servers' cached boards until their next refresh; filtering on read hides it immediately on servers that know the flag.
- **`leaderstats` polls every 2 seconds.** Simple and cheap for one value. If you already push inventory snapshots, update it from the same place instead.

### 4.4 Big numbers

Ordered values are integers, and Luau numbers lose integer precision above 2^53 (about 9 x 10^15). The foundation caps coins at 10^15, so this build is safe. Simulators with numbers like 10^30 must store an order-preserving encoding (for example exponent and leading digits packed into one integer) and decode for display; [[OrderedDataStores and Leaderboards]] has a worked encoder. Decide this before launch: changing encodings later means a new store and an empty board.

---

## 5. Client and UI

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/Client/LeaderboardController (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.LeaderboardConfig)

local player = Players.LocalPlayer
local boardsEvent = Net.Event("LeaderboardData")

type Entry = { UserId: number, Name: string, Score: number, Rank: number }
type Payload = { Boards: { [string]: { Entry } }, WeekEndsAt: number }

local titles: { [string]: string } = {}
for _, board in Config.Boards do
	titles[board.Key] = board.Title
end

local function abbreviate(n: number): string
	local suffixes = { "", "K", "M", "B", "T", "Qa" }
	local i = 1
	while n >= 1000 and i < #suffixes do
		n /= 1000
		i += 1
	end
	return if i == 1 then tostring(math.floor(n)) else string.format("%.1f%s", n, suffixes[i])
end

local function fillList(list: ScrollingFrame, boardKey: string, entries: { Entry }, weekEndsAt: number)
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if not list:FindFirstChildOfClass("UIListLayout") then
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
	end
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()

	local header = Instance.new("TextLabel")
	header.LayoutOrder = 0
	header.Size = UDim2.new(1, 0, 0, 60)
	header.TextScaled = true
	header.BackgroundTransparency = 1
	local title = titles[boardKey] or boardKey
	if boardKey == "WeeklyCoins" then
		local hours = math.max(0, math.floor((weekEndsAt - workspace:GetServerTimeNow()) / 3600))
		title ..= `  (resets in {hours // 24}d {hours % 24}h)`
	end
	header.Text = title
	header.Parent = list

	for _, e in entries do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = e.Rank
		row.Size = UDim2.new(1, 0, 0, 40)
		row.TextScaled = true
		row.BackgroundTransparency = if e.UserId == player.UserId then 0.6 else 1
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = `#{e.Rank}  {e.Name}  {abbreviate(e.Score)}`
		row.Parent = list
	end
end

local function render(payload: Payload)
	for _, part in workspace:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "LeaderboardBoard" then
			local boardKey = part:GetAttribute("Board")
			local gui = part:FindFirstChildOfClass("SurfaceGui")
			local list = if gui then gui:FindFirstChild("List") else nil
			if type(boardKey) == "string" and list and list:IsA("ScrollingFrame") then
				fillList(list, boardKey, payload.Boards[boardKey] or {}, payload.WeekEndsAt)
			end
		end
	end
end

boardsEvent.OnClientEvent:Connect(render)
Net.Event("LeaderboardHello"):FireServer()
```

Notes:

- **Names come from Roblox.** Display names and usernames returned by `UserService` are already moderated by Roblox; do not let players set a custom "leaderboard name" without text filtering ([[Text Fonts and Rich Text]]).
- **Searching the whole Workspace** with `GetDescendants` on each refresh is fine for a few boards every two minutes. In a big place, tag boards with CollectionService and iterate the tag instead ([[CollectionService Patterns]]). With [[Instance Streaming]] on, a far-away board may not exist on the client yet; re-render on `CollectionService:GetInstanceAddedSignal`, or keep boards in a persistent model.
- **Your own rank.** `Rank_AllTimeCoins` on the local player is the position in the top N, or `-1`. Show "#12" or "Not in top 50" in the HUD. Exact ranks beyond the top 100 are expensive; [[OrderedDataStores and Leaderboards]] compares the options.

---

## 6. Variants

| Want | Change |
|---|---|
| Daily board | Same as weekly with `floor(unix / 86400)`; more stores, same cost |
| Friends-only board | No store needed: `Players:GetFriendsAsync` and read each friend's score from your own data, never from the ordered store |
| Live "this server" board | No data store at all: sort online players' profile stats every few seconds |
| Seasonal board with prizes | Weekly pattern plus a season index; read the final board after the season ends and grant prizes into profiles via a mailbox |
| Real-time board across servers | Memory store sorted map ([[MemoryStore Service]]); ordered stores still hold the permanent record |

Prizes for top places need care: decide the cutoff time in UTC, freeze by reading the closed week's store (it no longer receives writes), exclude flagged accounts, then grant. Never grant from a board that is still being written.

---

## 7. Testing in Studio

1. By default Studio does **not** write, so your test sessions do not pollute live boards. To test writing, set `ServerStorage` attribute `LeaderboardWritesInStudio` to true. Remember Studio writes go to the live stores of this universe (Roblox docs): use a separate test place or universe for heavy testing.
2. Earn coins via the command bar (`InventoryService.AddCoins`). Within 2 minutes your row appears on the board (writes every 120 s, reads every 120 s: worst case about 4 minutes; shorten both in config while testing).
3. Leave and rejoin: your row is still there; your score did not drop.
4. **Never lower.** Lower your `Stats.CoinsEarned` in the command bar and wait for a write: the board keeps the higher value.
5. **Weekly reset.** Temporarily change `WeekIndex` to divide by 600 (ten-minute "weeks") and watch the weekly board empty and refill. Restore it.
6. **Exclusion.** Put your user id in the `LeaderboardExcluded` attribute: your row disappears at the next refresh.
7. **Budget check.** Print `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.OrderedWrite)` before and after a write cycle to see the budget move ([[Debugging DataStore Problems]]).

---

## 8. Exploits and abuse

| Threat | Defence |
|---|---|
| Client reports a score | There is no score remote; scores come from server-side profile stats |
| Duplication exploit inflates coins | The board inherits the economy's integrity. The anomaly check keeps spikes off the board; fix the root cause ([[Economy Exploits - Dupes Races and Purchase Abuse]]) |
| Stale server overwrites a newer score | `UpdateAsync` never lowers |
| Offensive names | Only Roblox-provided names are shown |
| Removed cheater still on boards | Remove from stores plus filter at read time |
| A deletion request | `ForgetUserAsync` for every board and recent week ([[Player Privacy and Data Deletion]]) |
| Budget exhaustion from too many boards | Budget table in section 1; add boards only after recomputing it |

---

## 9. Extending it

- **More stats.** Each new board is one config entry plus one profile stat; recompute the write budget.
- **Badges for top ranks.** Award from the closed weekly board, not live ranks.
- **Rank change arrows.** Keep the previous `latest` and compare ranks on the client.
- **Admin view.** A gated panel listing anomalies and exclusions ([[Logging Bans and Appeals]]).

## Common mistakes

- Writing on every coin gain: the ordered write budget is gone in seconds on a busy server.
- Resetting a weekly board by deleting keys from a single store, racing players who are still writing.
- Different week formulas in different scripts.
- `SetAsync` for monotonic scores, letting stale servers lower them.
- Calling `Players:GetNameFromUserIdAsync` once per row per refresh instead of batching and caching.
- Letting Studio sessions write to the live board.
- Showing floats: ordered values are integers; floor before writing.

## Checklist

- [ ] Scores sourced from profile stats only
- [ ] Write and list budgets computed for the worst server size
- [ ] Writes staggered, only on change, never lowering monotonic scores
- [ ] One week formula, shared
- [ ] Names batched and cached; unresolved shown neutrally
- [ ] Exclusion and deletion paths exist
- [ ] Studio writes off by default
- [ ] Big-number encoding decided before launch

## See also

[[Worked Builds Start Here]] | [[OrderedDataStores and Leaderboards]] | [[Saved Inventory End to End]] | [[DataStore Fundamentals]] | [[MemoryStore Service]] | [[World-Space UI - BillboardGui and SurfaceGui]]

## Connected notes
<!-- auto-links:start -->
[[Cookbook - Data and Saving]] · [[Links - Leaderboards]] · [[Economy Resets and Seasonal Wipes]] · [[Codes Redemption System End to End]] · [[Saving Correctly - Autosave and BindToClose]] · [[Session Lock]]
<!-- auto-links:end -->
